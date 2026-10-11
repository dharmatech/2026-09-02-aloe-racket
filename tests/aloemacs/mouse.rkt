#lang racket/base

;; aloemacs-mouse 000: a button press and release reach Aloe on the read the
;; editor already blocks on. A left press in a window's text selects that
;; window and places its point. No TTY is opened here.

(require racket/list racket/runtime-path racket/file racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/term.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/aloemacs-run.rkt"
         (only-in tui/term/messages make-tmousemsg)
         (only-in tui/term/geometry tpoint))

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")
(define-runtime-path term-path "../../host/racket/term.rkt")
(define-runtime-path gel-run-path "../../host/racket/gel-run.rkt")
(define-runtime-path term-run-path "../../host/racket/term-run.rkt")

;; Two regular files make the find-file Tab list two completion lines.
(define (fs-double)
  (make-fs-double "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
    (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b")))

(define st (make-driver))
(driver-inject-host! st 'fs-host (fs-double))
(void (driver-load-file! st main-path))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))
(define (same actual expected)
  (check-not-exn (lambda () (ev `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (dtype expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (rejects bad)
  (check-exn exn:fail:aloe-type? (lambda () (ev bad)) (format "reject ~s" bad)))

;; Expected values use raw constructors and selectors only.
(define (pos p) `(Position new ,(car p) ,(cadr p)))
(define (view id bid point origin)
  `(AloemacsView new ,id ,bid ,(car origin) ,(cadr origin) ,(pos point) #f (Option None)))
(define (at! s point)
  (same `(,s point) (pos point)))
(define (origin-of s)
  (list (ev `((,s editor) scroll-row)) (ev `((,s editor) scroll-col))))
(define (stores! s id point origin)
  (same `(((,s windows) tree) find-view ,id)
        `(Option Some ,(view id (ev `((,s current-buffer) id)) point origin))))
(define (selected! s id) (check-equal? (ev `((,s windows) selected)) id))
(define (focus-line s) (ev `(((,s editor) text) focus-line)))
(define (text-of s) (ev `((,s text) to-string)))
(define (echo-of s) (ev `(,s echo)))
(define (unchanged! s event)
  (same `(,s handle-event ,event) s))

(define contents "hello\nworld\nxyz")

;; The base session: one view, fitted once at 80 by 24, point (0, 0).
(def! 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt"))
            ensure-visible 80 24))
(define session-type (dtype 's0))

(define accepted '("mouse down left 4 2" "mouse up middle 0 0" "mouse down right 10 12"))
(define rejected '("mouse down left 04 2" "mouse down left 4 2 " "mouse down left -1 2"
                   "mouse" "Mouse down left 4 2" "mouse down left 4"
                   "mouse down left 4  2" "mouse down left 4 2 1"))

;; 1. Types and arities.
(test-case "types: AloemacsMouse, contains?, view-at, place, place-at, handle-event"
  (check-equal? (dtype '(AloemacsMouse new "x")) 'AloemacsMouse)
  (rejects '(AloemacsMouse new))
  (rejects '(AloemacsMouse new "x" "y"))
  (rejects '(AloemacsMouse new 1))
  (for ([selector '(event? down? left?)])
    (check-equal? (dtype `((AloemacsMouse new "x") ,selector)) 'Bool)
    (rejects `((AloemacsMouse new "x") ,selector 1)))
  (for ([selector '(column row)])
    (check-equal? (dtype `((AloemacsMouse new "x") ,selector)) 'Int)
    (rejects `((AloemacsMouse new "x") ,selector 1)))
  (def! 'rect '(AloemacsWindowRect new 0 0 80 23))
  (def! 'tree '((s0 windows) tree))
  (def! 'ed '(s0 editor))
  (check-equal? (dtype '(rect contains? 0 0)) 'Bool)
  (rejects '(rect contains? 0))
  (rejects '(rect contains? 0 0 0))
  (rejects '(rect contains? "a" 0))
  (check-equal? (dtype '(tree view-at 0 0 rect)) '(Option AloemacsView))
  (rejects '(tree view-at 0 0))
  (rejects '(tree view-at 0 0 rect rect))
  (rejects '(tree view-at "a" 0 rect))
  (check-equal? (dtype '(ed place 0 0)) 'AloemacsEditor)
  (rejects '(ed place 0))
  (rejects '(ed place 0 0 0))
  (rejects '(ed place "a" 0))
  (check-equal? (dtype '(s0 place-at 0 0)) session-type)
  (rejects '(s0 place-at 0))
  (rejects '(s0 place-at 0 0 0))
  (rejects '(s0 place-at 0 "a"))
  (check-equal? (dtype '(s0 handle-event "x")) session-type)
  (rejects '(s0 handle-event))
  (rejects '(s0 handle-event "x" "y"))
  (rejects '(s0 handle-event 1))
  (check-equal? (dtype '(s0 handle-mouse "x")) session-type)
  (rejects '(s0 handle-mouse))
  (rejects '(s0 handle-mouse "x" "y"))
  (rejects '(s0 handle-mouse 1)))

;; 2. Grammar.
(test-case "grammar: event? accepts exactly the mouse strings; fields read"
  (for ([s accepted])
    (check-true (ev `((AloemacsMouse new ,s) event?)) s))
  (for ([s rejected])
    (check-false (ev `((AloemacsMouse new ,s) event?)) s))
  (define (fields s)
    (list (ev `((AloemacsMouse new ,s) down?)) (ev `((AloemacsMouse new ,s) left?))
          (ev `((AloemacsMouse new ,s) column)) (ev `((AloemacsMouse new ,s) row))))
  (check-equal? (fields "mouse down left 4 2") '(#t #t 4 2))
  (check-equal? (fields "mouse up middle 0 0") '(#f #f 0 0))
  (check-equal? (list (ev '((AloemacsMouse new "mouse down right 10 12") column))
                      (ev '((AloemacsMouse new "mouse down right 10 12") row)))
                '(10 12)))

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

(test-case "read-event returns the mouse string; read-key skips it"
  (define mouse "mouse down left 4 2")
  (define events (scripted-driver (list mouse "x")))
  (check-equal? (type->datum (type-of (parse-datum '(term read-event))
                                      (driver-type-environment events)))
                'String)
  (check-equal? (driver-eval! events '(term read-event)) mouse)
  (check-equal? (driver-eval! events '(term read-event)) "x")
  (check-equal? (driver-eval! (scripted-driver (list mouse "x")) '(term read-key)) "x")
  (check-equal? (driver-eval! (scripted-driver (list mouse mouse "x")) '(term read-key)) "x")
  (check-equal? (driver-eval! (scripted-driver (list "mouse down left 04 2" "x"))
                              '(term read-key))
                "mouse down left 04 2"))

;; 4. Catalog.
(test-case "Term has the six-row production descriptor"
  (define methods (host-interface-methods term-interface))
  (check-equal? (map host-method-selector methods)
                '(read-key write-line write columns rows read-event))
  (check-equal? (map host-method-parameter-types methods)
                '(() (String) (String) () () ()))
  (check-equal? (map host-method-return-type methods)
                '(String String String Int Int String)))

;; 5. Formatter.
(test-case "tmousemsg->aloe-mouse formats presses and releases without subtracting"
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 4 2) #t #f #f 'left))
                "mouse down left 4 2")
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'button-up (tpoint 4 2) #t #f #f 'left))
                "mouse up left 4 2")
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'button-up (tpoint 0 0) #f #f #t 'middle))
                "mouse up middle 0 0")
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 4 2) #f #t #f 'right))
                "mouse down right 4 2")
  (check-equal? (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 1 2) #t #f #f 'left))
                "mouse down left 1 2")
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'move (tpoint 4 2) #f #f #f 'left)))
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'wheel-up (tpoint 4 2) #f #f #f 'left)))
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 4 2) #f #f #f #f)))
  (check-false (tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint -1 2) #t #f #f 'left))))

;; 6. Sources.
(test-case "runner enables and disables buttons only; term and Gel stay clear"
  (define runner (file->string runner-path))
  (define term (file->string term-path))
  (define (has? source phrase) (regexp-match? (regexp (regexp-quote phrase)) source))
  (define (count source phrase)
    (length (regexp-match* (regexp (regexp-quote phrase)) source)))
  (for ([phrase '("[?1000h" "[?1006h" "[?1000l" "[?1006l" "aloemacs-editor handle-event")])
    (check-true (has? runner phrase) phrase))
  (check-equal? (count runner "(term read-event)") 1)
  (for ([phrase '("1003" "term-enable-mouse" "(term read-key)")])
    (check-false (has? runner phrase) phrase))
  (for ([phrase '("1000" "1003" "term-enable-mouse")])
    (check-false (has? term phrase) phrase))
  (for ([path (list gel-run-path term-run-path)])
    (define source (file->string path))
    (for ([phrase '("read-event" "1000" "term-enable-mouse")])
      (check-false (has? source phrase) (format "~a in ~a" phrase path)))))

;; 7. Runner: the scripted-term shape from viewport-runner.rkt.
(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define size-calls (box 0))
  (define recorded '())
  (define (record! event) (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'aloemacs-mouse-output
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

(define (frame-tail frame)
  (define m (regexp-match #px"(\e\\[[0-9]+;[0-9]+H\e\\[\\?25h)$" frame))
  (and m (cadr m)))

(test-case "runner: a click selects the lower window and places its point"
  (define keys '("ctrl-x" "2" "mouse down left 1 14" "ctrl-x" "o" "escape"))
  (define-values (receiver remaining events) (make-scripted-term keys))
  (run-aloemacs-with-hosts receiver (fs-double) "a.txt")
  (check-equal? (unbox remaining) '())
  (define recorded (events))
  (define frames
    (for/list ([event recorded] #:when (and (pair? event) (eq? (car event) 'write)))
      (cadr event)))
  (check-equal? (length frames) 6)
  (check-equal?
   recorded
   (append-map (lambda (frame key)
                 (list '(columns 80) '(rows 24) (list 'write frame) 'flush (list 'key key)))
               frames keys))
  (check-equal? (frame-tail (list-ref frames 2)) "\e[1;1H\e[?25h")
  (check-equal? (frame-tail (list-ref frames 3)) "\e[15;2H\e[?25h")
  (check-equal? (frame-tail (list-ref frames 5)) "\e[1;1H\e[?25h")
  (for ([frame frames])
    (check-false (regexp-match? #rx"\\[\\?1000h" frame))
    (check-false (regexp-match? #rx"\\[\\?1006h" frame))))

;; 8. Selected window, echo, origin.
(test-case "a left press in the selected window places the point and clears the echo"
  (def! 'e8 '((s0 with-echo "saved") handle-event "mouse down left 4 0"))
  (at! 'e8 '(0 4))
  (check-equal? (echo-of 'e8) "")
  (check-equal? (origin-of 'e8) (origin-of 's0))
  (check-equal? (text-of 'e8) contents)
  (stores! 'e8 0 '(0 4) '(0 0))
  (def! 'e8b '((s0 split-below) handle-event "mouse down left 4 0"))
  (at! 'e8b '(0 4))
  (selected! 'e8b 0)
  (stores! 'e8b 1 '(0 0) '(0 0)))

;; 9. Clamp.
(test-case "a press past the line end or past the last line clamps"
  (def! 'e9a '(s0 handle-event "mouse down left 9 1"))
  (at! 'e9a '(1 5))
  (check-equal? (focus-line 'e9a) 1)
  (def! 'e9b '(s0 handle-event "mouse down left 0 5"))
  (at! 'e9b '(2 3))
  (check-equal? (focus-line 'e9b) 2))

;; 10. Other window.
(test-case "a press in the other window selects it through the handoff"
  (def! 'e10 '((s0 split-below) handle-event "mouse down left 1 14"))
  (selected! 'e10 1)
  (at! 'e10 '(2 1))
  (check-equal? (focus-line 'e10) 2)
  (stores! 'e10 0 '(0 0) '(0 0))
  (stores! 'e10 1 '(2 1) '(0 0))
  (check-equal? (text-of 'e10) contents))

;; 11. Origin.
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new "/typed-none"))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define no-prompt
  '(if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0))))
(define no-submission '(if #t (Option None) (Option Some "")))
(define no-command '(if #t (Option None) (Option Some (AloemacsCommand FindFile))))

(test-case "a press does not refit the origin"
  (def! 'raw
    `(AloemacsSession new
       (AloemacsBuffers new (List empty)
         (AloemacsBuffer new
           (AloemacsEditor new (Text from-string "hi") (Position new 0 0) #f 10 3
             (List empty) ,no-mark 0)
           ,no-path 0)
         (List empty))
       (Fs new fs-host) "" #f "" (Position new 0 0) #f #f (List empty)
       ,no-pending ,no-prompt ,no-submission ,no-command
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 0 10 3 (Position new 0 0) #f (Option None)))
         0 80 24)))
  (def! 'e11 '(raw handle-event "mouse down left 0 5"))
  (at! 'e11 '(0 2))
  (check-equal? (origin-of 'e11) '(10 3))
  (stores! 'e11 0 '(0 2) '(10 3)))

;; 12. Small screen.
(test-case "40 by 10: a press in the lower window selects it"
  (def! 'e12 '(((s0 ensure-visible 40 10) split-below) handle-event "mouse down left 1 6"))
  (selected! 'e12 1)
  (at! 'e12 '(1 1))
  (stores! 'e12 0 '(0 0) '(0 0)))

;; 13. Release and other buttons.
(test-case "a release, a middle button, and a right button change nothing"
  (def! 'e13 '(s0 with-echo "saved"))
  (for ([event '("mouse up left 4 0" "mouse down middle 4 0" "mouse down right 4 0")])
    (unchanged! 'e13 event))
  (check-equal? (echo-of 'e13) "saved"))

;; 14. Chrome.
(test-case "a left press on a mode line, the echo row, or the bar changes nothing"
  (def! 'e14 '(s0 with-echo "saved"))
  (unchanged! 'e14 "mouse down left 0 22")
  (unchanged! 'e14 "mouse down left 0 23")
  (def! 'e14r '((s0 with-echo "saved") split-right))
  (unchanged! 'e14r "mouse down left 40 0")
  (def! 'e14b '((s0 with-echo "saved") split-below))
  (unchanged! 'e14b "mouse down left 0 11"))

;; 15. One row.
(test-case "one row: no echo row and no mode line"
  (def! 'e15 '((s0 ensure-visible 80 1) handle-event "mouse down left 2 0"))
  (at! 'e15 '(0 2)))

;; 16. Locked.
(test-case "a locked window can be selected by a press"
  (def! 'e16 '((((s0 split-below) other-window) toggle-window-lock) other-window))
  (selected! 'e16 0)
  (define (locked? s id)
    (ev `((((,s windows) tree) find-view ,id) case (None () #f) (Some (v) (v locked)))))
  (check-true (locked? 'e16 1))
  (def! 'e16p '(e16 handle-event "mouse down left 1 14"))
  (selected! 'e16p 1)
  (at! 'e16p '(2 1))
  (check-true (locked? 'e16p 1)))

;; 17. Prompt.
(test-case "a press during a prompt changes nothing"
  (def! 'e17 '(((s0 handle-key "ctrl-x") handle-key "find") handle-key "tab"))
  (check-true (ev '((e17 prompt) present?)))
  (check-equal? (ev '((e17 prompt) case (None () "") (Some (p) (p text)))) "/cwd/")
  (check-equal? (ev '((e17 completion-lines) len)) 2)
  (check-equal? (ev '((e17 root-rect 80 24) rows)) 21)
  (unchanged! 'e17 "mouse down left 0 21")
  (unchanged! 'e17 "mouse down left 4 0"))

;; 18. Search and prefix.
(test-case "a press during a search or a pending prefix changes nothing"
  (def! 'e18s '(s0 handle-key "find"))
  (check-true (ev '(e18s searching)))
  (unchanged! 'e18s "mouse down left 0 0")
  (def! 'e18p '(s0 handle-key "ctrl-x"))
  (check-true (ev '((e18p pending) present?)))
  (unchanged! 'e18p "mouse down left 0 0"))

;; 19. Not inserted, then keys still work.
(test-case "a mouse string is never inserted; keys still take handle-key"
  (def! 'marked '(s0 set-mark))
  (def! 'e19 '(marked handle-event "mouse down left 4 0"))
  (check-equal? (text-of 'e19) contents)
  (same '((e19 editor) mark) '(Option Some (Position new 0 0)))
  (check-equal? (ev '(((e19 editor) history) len)) (ev '(((marked editor) history) len)))
  (def! 'e19x '(e19 handle-event "x"))
  (check-equal? (text-of 'e19x) "hellxo\nworld\nxyz")
  (at! 'e19x '(0 5))
  (def! 'e19l '(e19x handle-event "left"))
  (at! 'e19l '(0 4))
  (def! 'e19q '(e19l handle-event "escape"))
  (check-true (ev '(e19q quit)))
  (unchanged! 'e19q "mouse down left 1 1")
  (def! 'e19k '(s0 handle-event "mouse down left 04 2"))
  (at! 'e19k '(0 0))
  (check-equal? (text-of 'e19k) contents))
