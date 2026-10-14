#lang racket/base

;; aloemacs-split-drag 001: a mouse move reaches Aloe while a button is held,
;; and the window configuration gains the field a drag will arm. Nothing
;; arms, nothing drags, and a move leaves every session unchanged. The TTY
;; entry asks for motion while a button is held, mode 1002, inside the
;; alternate screen. No TTY is opened here.

(require racket/list racket/port racket/runtime-path racket/file rackunit
         "../../aloe/driver.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/term.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/aloemacs-run.rkt"
         (only-in tui/term/messages make-tmousemsg)
         (only-in tui/term/geometry tpoint))

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path text-path "../../lib/text.aloe")
(define-runtime-path fs-path "../../lib/fs.aloe")
(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")
(define-runtime-path term-path "../../host/racket/term.rkt")
(define-runtime-path gel-run-path "../../host/racket/gel-run.rkt")
(define-runtime-path term-run-path "../../host/racket/term-run.rkt")

;; The fs double of mouse.rkt.
(define (fs-double)
  (make-fs-double "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
    (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b")))

(define st (make-driver))
(driver-inject-host! st 'fs-host (fs-double))
(void (driver-load-file! st main-path))
(driver-eval! st `(load ,(path->string file-path)))
(driver-eval! st `(load ,(path->string editor-path)))
(driver-eval! st `(load ,(path->string text-path)))
(driver-eval! st `(load ,(path->string fs-path)))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))
(define (same actual expected)
  (check-not-exn (lambda () (ev `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (differs actual expected)
  (check-exn #rx"check failed" (lambda () (ev `(check ,actual ,expected)))
             (format "~s differs from ~s" actual expected)))
(define (dtype expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (rejects bad)
  (check-exn exn:fail:aloe-type? (lambda () (ev bad)) (format "reject ~s" bad)))
(define (unchanged! s event)
  (same `(,s handle-event ,event) s))
(define (armed? s) (ev `(((,s windows) drag) present?)))
(define (echo-of s) (ev `(,s echo)))

(define contents "hello\nworld\nxyz")

;; Fixtures. w and a, the armed configuration and the armed session, are
;; defined where item 7 first needs them.
(def! 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt")) ensure-visible 80 24))
(def! 'saved '(s0 with-echo "saved"))
(def! 'tree '((s0 windows) tree))
(def! 'b '(s0 current-buffer))
(define session-type (dtype 's0))

;; 1. Types and arities.
(test-case "types: move?, armed, disarmed, drag, the fifth field, the handlers, the declarations"
  (check-equal? (dtype '((AloemacsMouse new "x") move?)) 'Bool)
  (rejects '((AloemacsMouse new "x") move? 1))
  (check-equal? (dtype '((s0 windows) armed 7)) 'AloemacsWindows)
  (rejects '((s0 windows) armed))
  (rejects '((s0 windows) armed 7 7))
  (rejects '((s0 windows) armed "7"))
  (check-equal? (dtype '((s0 windows) disarmed)) 'AloemacsWindows)
  (rejects '((s0 windows) disarmed 7))
  (check-equal? (dtype '(s0 disarmed)) session-type)
  (rejects '(s0 disarmed 7))
  (check-equal? (dtype '((s0 windows) drag)) '(Option Int))
  (rejects '(AloemacsWindows new tree 0 80 24))
  (check-equal? (dtype '(AloemacsWindows new tree 0 80 24 (Option None))) 'AloemacsWindows)
  (check-equal? (dtype '(s0 handle-event "x")) session-type)
  (check-equal? (dtype '(s0 handle-mouse "x")) session-type)
  ;; Read as data: the configuration's payload, the session's field count,
  ;; and the ordered define-class list split-drag-weights.rkt pins.
  (define source (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) source))
  (define (decl name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (check-equal? (caddr (decl 'AloemacsWindows))
    '(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int) (drag (Option Int))))
  (check-equal? (car (caddr (decl '(AloemacsSession H)))) 'fields)
  (check-equal? (length (cdr (caddr (decl '(AloemacsSession H))))) 14)
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B)
      AloemacsBinding AloemacsSearchScan AloemacsMouse (AloemacsSession H))))

;; 2. Grammar.
(define accepted-moves '("mouse move 0 0" "mouse move 30 5"))
(define accepted-presses '("mouse down left 4 2" "mouse up middle 0 0" "mouse down right 10 12"))
(define rejected-moves
  '("mouse move left 30 5" "mouse move 30" "mouse move 030 5" "mouse move 30 5 "
    "mouse move -1 5" "mouse  move 30 5" "Mouse move 30 5"))
;; The mouse spec's rejected strings, as mouse.rkt item 2 lists them.
(define rejected-presses
  '("mouse down left 04 2" "mouse down left 4 2 " "mouse down left -1 2"
    "mouse" "Mouse down left 4 2" "mouse down left 4"
    "mouse down left 4  2" "mouse down left 4 2 1"))

(test-case "grammar: event? accepts both shapes and nothing else; the fields read on either"
  (for ([s (append accepted-moves accepted-presses)])
    (check-true (ev `((AloemacsMouse new ,s) event?)) s))
  (for ([s (append rejected-moves rejected-presses)])
    (check-false (ev `((AloemacsMouse new ,s) event?)) s))
  (define (fields s)
    (list (ev `((AloemacsMouse new ,s) move?)) (ev `((AloemacsMouse new ,s) down?))
          (ev `((AloemacsMouse new ,s) left?))
          (ev `((AloemacsMouse new ,s) column)) (ev `((AloemacsMouse new ,s) row))))
  (check-equal? (fields "mouse move 30 5") '(#t #f #f 30 5))
  (check-equal? (list (ev '((AloemacsMouse new "mouse move 0 0") column))
                      (ev '((AloemacsMouse new "mouse move 0 0") row)))
                '(0 0))
  (check-equal? (fields "mouse down left 4 2") '(#f #t #t 4 2)))

;; 3. read-event and the read-key skip.
(define (scripted-driver script)
  (define remaining (box script))
  (define state (make-driver))
  (driver-inject-host!
   state 'term
   (make-term-receiver (open-output-string)
                       (lambda ()
                         (define next (car (unbox remaining)))
                         (set-box! remaining (cdr (unbox remaining)))
                         next)))
  state)

(test-case "read-event returns the move string; read-key skips it; a leading zero is a key"
  (define move "mouse move 30 5")
  (define events (scripted-driver (list move "x")))
  (check-equal? (driver-eval! events '(term read-event)) move)
  (check-equal? (driver-eval! events '(term read-event)) "x")
  (check-equal? (driver-eval! (scripted-driver (list move "x")) '(term read-key)) "x")
  (check-equal? (driver-eval! (scripted-driver (list "mouse move 030 5" "x")) '(term read-key))
                "mouse move 030 5"))

;; 4. Formatter.
(test-case "tmousemsg->aloe-mouse formats a move; presses, releases, and refusals stay"
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'move (tpoint 30 5) #t #f #f))
                "mouse move 30 5")
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'move (tpoint 4 2) #f #f #f 'left))
                "mouse move 4 2")
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'move (tpoint -1 2) #t #f #f)))
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'wheel-up (tpoint 4 2) #f #f #f)))
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 4 2) #t #f #f 'left))
                "mouse down left 4 2")
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 4 2) #f #f #f #f))))

;; 5. Sources.
(test-case "the runner asks for motion inside the alternate screen; term and Gel stay clear"
  (define runner (file->string runner-path))
  (define term (file->string term-path))
  (define (has? source phrase) (regexp-match? (regexp (regexp-quote phrase)) source))
  (define (count source phrase)
    (length (regexp-match* (regexp (regexp-quote phrase)) source)))
  (check-equal? (count runner "[?1049h\\e[?1002h\\e[?1006h") 1)
  (check-equal? (count runner "[?1002l\\e[?1006l\\e[?1049l") 1)
  (check-equal? (count runner "(term read-event)") 1)
  (for ([phrase '("1000" "1003" "term-enable-mouse")])
    (check-false (has? runner phrase) phrase))
  (for ([phrase '("1000" "1002" "1003" "term-enable-mouse")])
    (check-false (has? term phrase) phrase))
  (for ([path (list gel-run-path term-run-path)])
    (define source (file->string path))
    (for ([phrase '("read-event" "1000" "1002" "term-enable-mouse")])
      (check-false (has? source phrase) (format "~a in ~a" phrase path)))))

;; 6. A move is inert.
(test-case "a move leaves every session unchanged, the echo included"
  (def! 'm6 '(saved handle-event "mouse move 30 5"))
  (same 'm6 'saved)
  (check-equal? (echo-of 'm6) "saved")
  (def! 'm6r '(s0 split-right))
  (def! 'm6b '(s0 split-below))
  (def! 'm6s '((s0 ensure-visible 40 10) split-below))
  (def! 'm6f '(s0 handle-key "find"))
  (def! 'm6p '(((s0 handle-key "ctrl-x") handle-key "find") handle-key "tab"))
  (def! 'm6x '(s0 handle-key "ctrl-x"))
  (def! 'm6q '(s0 handle-event "escape"))
  (check-true (ev '(m6f searching)))
  (check-true (ev '((m6p prompt) present?)))
  (check-true (ev '((m6x pending) present?)))
  (check-true (ev '(m6q quit)))
  (for ([s '(m6r m6b m6s m6f m6p m6x m6q)])
    (unchanged! s "mouse move 30 5")))

;; 7. The field survives.
(test-case "drag is None on every program-built configuration; Some 7 survives every send"
  (check-false (armed? 's0))
  (for ([s '((s0 split-below) (s0 split-right) ((s0 split-below) other-window)
             ((s0 split-below) delete-window) (s0 toggle-window-lock)
             (s0 ensure-visible 120 24) (s0 record-pictures 80 24)
             (s0 find-file-submitted "b.txt") (s0 handle-event "x")
             (s0 handle-event "mouse down left 4 0") (s0 handle-event "mouse up left 4 0"))])
    (check-false (ev `(((,s windows) drag) present?)) (format "~s" s)))
  (def! 'w '((s0 windows) armed 7))
  (same '(w drag) '(Option Some 7))
  (for ([s '((w with-size 120 24) (w with-split 0 0 (Position new 0 0) #t) (w with-toggled-lock)
             (w with-buffer b) (w without-buffer 41 b))])
    (same `(,s drag) '(Option Some 7)))
  (check-false (ev '(((w disarmed) drag) present?))))

;; 8. Events disarm. A constructed armed session; nothing in the program arms.
(test-case "a key, a press, and a release disarm and then take today's path; a move leaves a"
  (def! 'a '(s0 with (windows ((s0 windows) armed 7))))
  (differs 'a 's0)
  (check-true (armed? 'a))
  (for ([e '("x" "left" "ctrl-x" "find" "escape"
             "mouse up left 4 0" "mouse down middle 4 0" "mouse up right 4 0"
             "mouse down left 4 0")])
    (same `(a handle-event ,e) `(s0 handle-event ,e))
    (check-false (ev `((((a handle-event ,e) windows) drag) present?)) e))
  ;; 002 changes this one row.
  (same '(a handle-event "mouse move 4 0") 'a)
  (same '(s0 disarmed) 's0)
  (same '(a disarmed) 's0))

;; 9. Runner: the scripted-term shape from mouse.rkt.
(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define size-calls (box 0))
  (define recorded '())
  (define (record! event) (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'aloemacs-motion-output
     always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (record! (if (= start end)
                    'flush
                    (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
       (- end start))
     void))
  (define receiver
    (make-term-receiver
     output
     (lambda ()
       (define remaining (unbox remaining-keys))
       (unless (pair? remaining) (error 'scripted-term "key script exhausted"))
       (set-box! remaining-keys (cdr remaining))
       (record! (list 'key (car remaining)))
       (car remaining))
     (lambda ()
       (define call (unbox size-calls))
       (set-box! size-calls (add1 call))
       (record! (if (even? call) '(columns 80) '(rows 24)))
       (values 80 24))))
  (values receiver remaining-keys (lambda () (reverse recorded))))

(test-case "runner: x, a move, escape write three frames, and the third equals the second"
  (define keys '("x" "mouse move 3 3" "escape"))
  (define-values (receiver remaining events) (make-scripted-term keys))
  (run-aloemacs-with-hosts receiver (fs-double) "a.txt")
  (check-equal? (unbox remaining) '())
  (define recorded (events))
  (define frames
    (for/list ([event recorded] #:when (and (pair? event) (eq? (car event) 'write)))
      (cadr event)))
  (check-equal? (length frames) 3)
  (check-equal?
   recorded
   (append-map (lambda (frame key)
                 (list '(columns 80) '(rows 24) (list 'write frame) 'flush (list 'key key)))
               frames keys))
  (check-equal? (list-ref frames 2) (list-ref frames 1))
  (check-not-equal? (list-ref frames 1) (list-ref frames 0))
  (for ([frame frames])
    (for ([phrase '("[?1000h" "[?1002h" "[?1006h" "[?1049h")])
      (check-false (regexp-match? (regexp (regexp-quote phrase)) frame) phrase))))
