#lang racket/base

;; aloemacs-mode-buttons 001: a left press on ↕, ↔, or × in a mode line
;; selects that window and then sends split-below, split-right, or
;; delete-window. The session after the press equals the session that
;; sequence returns. Every other mode-line press leaves the session as it
;; was. No TTY is opened here.

(require racket/file racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/aloemacs-run.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

;; The fs double of mouse.rkt.
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
(define (at! s point) (same `(,s point) (pos point)))
(define (stores! s id point origin)
  (same `(((,s windows) tree) find-view ,id)
        `(Option Some ,(view id (ev `((,s current-buffer) id)) point origin))))
(define (selected! s id) (check-equal? (ev `((,s windows) selected)) id))
(define (leaves-of s) (ev `((((,s windows) tree) leaves) len)))
(define (single? s) (ev `(((,s windows) tree) single?)))
(define (locked? s id)
  (ev `((((,s windows) tree) find-view ,id) case (None () #f) (Some (v) (v locked)))))
(define (buffer-of s id)
  (ev `((((,s windows) tree) find-view ,id) case (None () -1) (Some (v) (v buffer-id)))))
(define (text-of s) (ev `((,s text) to-string)))
(define (echo-of s) (ev `(,s echo)))
(define (unchanged! s event) (same `(,s handle-event ,event) s))
(define (press s event) `(,s handle-event ,event))

(define contents "hello\nworld\nxyz")

;; Test-local literals, built from code points so this source holds no escape.
(define UPDOWN (string (integer->char #x2195)))
(define LEFTRIGHT (string (integer->char #x2194)))
(define TIMES (string (integer->char #xd7)))
(define GROUP (string-append " " UPDOWN " " LEFTRIGHT " " TIMES))
(define label-rx (regexp (string-append "[" UPDOWN LEFTRIGHT TIMES "]")))
(define backslash (string (integer->char 92)))
(define (occurrences s part) (length (regexp-match-positions* (regexp-quote part) s)))

(define class-list
  '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView
    AloemacsWindowTree AloemacsWindowRect AloemacsWindows AloemacsCommand
    (AloemacsKeymap B) AloemacsBinding AloemacsSearchScan AloemacsMouse (AloemacsSession H)))

;; Fixtures, each an expression on the loaded main.aloe.
(def! 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt")) ensure-visible 80 24))
(define session-type (dtype 's0))
(def! 'saved '(s0 with-echo "saved"))
(def! 'sb '(s0 split-below))
(def! 'sr '(s0 split-right))
(def! 'e16 '((((s0 split-below) other-window) toggle-window-lock) other-window))
(def! 's-two '((((s0 split-below) other-window) find-file-submitted "b.txt") other-window))
(def! 's40b '((s0 ensure-visible 40 10) split-below))
(def! 's9 '((s0 ensure-visible 9 6) split-right))
(def! 'e17 '(((s0 handle-key "ctrl-x") handle-key "find") handle-key "tab"))
(def! 'e18s '(s0 handle-key "find"))
(def! 'e18p '(s0 handle-key "ctrl-x"))
(def! 'e19q '(((((s0 set-mark) handle-event "mouse down left 4 0") handle-event "x")
               handle-event "left") handle-event "escape"))

;; 1. Types and arities.
(test-case "types, arities, declared shapes, and an ASCII source"
  (check-equal? (dtype '((AloemacsModeLine new) label-at 80 75)) 'String)
  (rejects '((AloemacsModeLine new) label-at 80))
  (rejects '((AloemacsModeLine new) label-at 80 75 1))
  (rejects '((AloemacsModeLine new) label-at "80" 75))
  (rejects '((AloemacsModeLine new) label-at 80 "75"))
  (def! 'v '(AloemacsView new 0 0 0 0 (Position new 0 0) #f (Option None)))
  (def! 'r '(AloemacsWindowRect new 0 0 80 23))
  (check-equal? (dtype '(s0 select-view v)) (list 'Option session-type))
  (rejects '(s0 select-view))
  (rejects '(s0 select-view v v))
  (rejects '(s0 select-view r))
  (check-equal? (dtype '(s0 button-send "x")) session-type)
  (rejects '(s0 button-send 1))
  (rejects '(s0 button-send))
  (rejects '(s0 button-send "x" "y"))
  (check-equal? (dtype '(s0 press-mode-line v r 75)) session-type)
  (rejects '(s0 press-mode-line v r))
  (rejects '(s0 press-mode-line v r 75 0))
  (rejects '(s0 press-mode-line r v 75))
  (check-equal? (dtype '(s0 press-at 0 0)) session-type)
  (check-equal? (dtype '(s0 handle-event "x")) session-type)
  (check-equal? (dtype '(s0 handle-mouse "x")) session-type)
  ;; Read as data: the declared shape, the class list, and the fieldless line.
  (define datums (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) datums))
  (check-equal? (map cadr classes) class-list)
  (define line (findf (lambda (d) (eq? (cadr d) 'AloemacsModeLine)) classes))
  (check-equal? (caddr line) '(fields))
  (define methods (cdr (findf (lambda (s) (and (pair? s) (eq? (car s) 'methods))) line)))
  (check-equal? (take (assq 'label-at methods) 4) '(label-at (width Int) (index Int) String))
  ;; The source stays ASCII bytes and spells the labels with escapes.
  (define source (file->string file-path))
  (check-true (for/and ([b (in-bytes (file->bytes file-path))]) (< b 128)))
  (for ([code '("u2195" "u2194" "u00d7")])
    (check-true (string-contains? source (string-append backslash code)) code))
  (check-false (regexp-match? label-rx source)))

;; 2. Label cells.
(define label-table
  `((80 75 ,UPDOWN) (80 77 ,LEFTRIGHT) (80 79 ,TIMES)
    (80 74 "") (80 76 "") (80 78 "")
    (80 0 "") (80 10 "") (80 73 "")
    (80 80 "") (80 -1 "")
    (7 2 ,UPDOWN) (7 4 ,LEFTRIGHT) (7 6 ,TIMES)
    (7 0 "") (7 1 "") (7 3 "") (7 5 "")
    (6 1 "") (6 3 "") (6 5 "")
    (40 35 ,UPDOWN) (40 37 ,LEFTRIGHT) (40 39 ,TIMES)
    (39 34 ,UPDOWN) (39 36 ,LEFTRIGHT) (39 38 ,TIMES)
    (0 0 "")))

(test-case "label-at names the three label cells and nothing else"
  (for ([entry label-table])
    (define actual (ev `((AloemacsModeLine new) label-at ,(car entry) ,(cadr entry))))
    (check-equal? actual (caddr entry) (format "~s" entry))
    (check-true (<= (string-length actual) 1) (format "~s" entry))))

;; 3. Each label, selected window.
(test-case "a label on the selected window is the bare send"
  (same (press 's0 "mouse down left 75 22") '(s0 split-below))
  (same (press 's0 "mouse down left 77 22") '(s0 split-right))
  (same (press 's0 "mouse down left 79 22") '(s0 delete-window))
  (same (press 's0 "mouse down left 79 22") '(s0 with-echo "failed"))
  (same (press 'saved "mouse down left 75 22") '(saved split-below))
  (def! 'e3 (press 's0 "mouse down left 75 22"))
  (at! 'e3 '(0 0))
  (check-equal? (leaves-of 'e3) 2)
  (selected! 'e3 0)
  (check-equal? (echo-of 'e3) "")
  (check-equal? (echo-of (press 'saved "mouse down left 75 22")) "")
  (check-equal? (echo-of (press 's0 "mouse down left 79 22")) "failed")
  (check-true (single? (press 's0 "mouse down left 79 22"))))

;; 4. Each label, another window.
(test-case "a label on another window is the handoff, then the send"
  (selected! 'sb 0)
  (same (press 'sb "mouse down left 79 22") '((sb other-window) delete-window))
  (def! 'e4d (press 'sb "mouse down left 79 22"))
  (check-true (single? 'e4d))
  (check-equal? (leaves-of 'e4d) 1)
  (selected! 'e4d 0)
  (at! 'e4d '(0 0))
  (stores! 'e4d 0 '(0 0) '(0 0))
  (same (press 'sb "mouse down left 75 22") '((sb other-window) split-below))
  (def! 'e4s (press 'sb "mouse down left 75 22"))
  (check-equal? (leaves-of 'e4s) 3)
  (selected! 'e4s 1)
  (at! 'e4s '(0 0))
  (selected! 'sr 0)
  (same (press 'sr "mouse down left 79 22") '((sr other-window) delete-window))
  (check-true (single? (press 'sr "mouse down left 79 22")))
  (selected! (press 'sr "mouse down left 79 22") 0)
  (same (press 'sr "mouse down left 39 22") '(sr delete-window))
  (check-true (single? (press 'sr "mouse down left 39 22")))
  (selected! (press 'sr "mouse down left 39 22") 1))

;; 5. Selected window in a split.
(test-case "a label on the selected upper leaf splits that leaf"
  (same (press 'sb "mouse down left 77 11") '(sb split-right))
  (def! 'e5 (press 'sb "mouse down left 77 11"))
  (check-equal? (leaves-of 'e5) 3)
  (selected! 'e5 0)
  (at! 'e5 '(0 0)))

;; 6. Refusals after selection.
(test-case "a locked window is selected first, then refuses"
  (selected! 'e16 0)
  (check-true (locked? 'e16 1))
  (for ([event '("mouse down left 79 22" "mouse down left 75 22")])
    (same (press 'e16 event) '((e16 other-window) with-echo "failed"))
    (def! 'e6 (press 'e16 event))
    (selected! 'e6 1)
    (check-true (locked? 'e6 1))
    (check-equal? (leaves-of 'e6) 2)
    (check-equal? (echo-of 'e6) "failed")))

;; 7. Another buffer.
(test-case "a delete on another buffer's window returns to the first buffer"
  (selected! 's-two 0)
  (check-equal? (ev '((s-two current-buffer) name)) "/cwd/a.txt")
  (check-equal? (ev '(((s-two buffers) before) len)) 0)
  (check-equal? (ev '(((s-two buffers) after) len)) 1)
  (check-equal? (buffer-of 's-two 1) (ev '((((s-two buffers) after) first) id)))
  (same (press 's-two "mouse down left 79 22") '((s-two other-window) delete-window))
  (def! 'e7 (press 's-two "mouse down left 79 22"))
  (check-true (single? 'e7))
  (selected! 'e7 0)
  (check-equal? (ev '((e7 current-buffer) name)) "/cwd/a.txt")
  (check-equal? (buffer-of 'e7 0) (ev '((e7 current-buffer) id)))
  (check-equal? (ev '(((e7 buffers) before) len)) 0)
  (check-equal? (ev '(((e7 buffers) after) len)) 1)
  (check-equal? (ev '((((e7 buffers) after) first) name)) "/cwd/b.txt"))

;; 8. Small screen.
(test-case "40 by 10: a label on the lower window takes the handoff"
  (same (press 's40b "mouse down left 39 8") '((s40b other-window) delete-window))
  (def! 'e8 (press 's40b "mouse down left 39 8"))
  (check-true (single? 'e8))
  (selected! 'e8 0))

;; 9. Unchanged presses.
(test-case "the name, the fill, the spaces, a release, another button, and a busy session stay"
  (for ([event '("mouse down left 0 22" "mouse down left 40 22" "mouse down left 73 22"
                 "mouse down left 74 22" "mouse down left 76 22" "mouse down left 78 22"
                 "mouse up left 75 22" "mouse up left 79 22"
                 "mouse down middle 75 22" "mouse down right 79 22")])
    (unchanged! 'saved event)
    (check-equal? (echo-of (press 'saved event)) "saved" event))
  (for ([event '("mouse down left 0 22" "mouse down left 10 22")])
    (unchanged! 'sb event)
    (selected! (press 'sb event) 0))
  (for ([event '("mouse down left 40 22" "mouse down left 41 22")])
    (unchanged! 'sr event))
  (same '(((s9 windows) tree) rect-for 0 (AloemacsWindowRect new 0 0 9 5))
        '(Option Some (AloemacsWindowRect new 0 0 4 5)))
  (same '(((s9 windows) tree) rect-for 1 (AloemacsWindowRect new 0 0 9 5))
        '(Option Some (AloemacsWindowRect new 5 0 4 5)))
  (for ([event '("mouse down left 3 4" "mouse down left 8 4")])
    (unchanged! 's9 event))
  (check-true (ev '((e17 prompt) present?)))
  (check-equal? (ev '((e17 completion-lines) len)) 2)
  (check-equal? (ev '((e17 root-rect 80 24) rows)) 21)
  (for ([event '("mouse down left 75 20" "mouse down left 79 20")])
    (unchanged! 'e17 event))
  (check-true (ev '(e18s searching)))
  (unchanged! 'e18s "mouse down left 75 22")
  (check-true (ev '((e18p pending) present?)))
  (unchanged! 'e18p "mouse down left 79 22")
  (check-true (ev '(e19q quit)))
  (unchanged! 'e19q "mouse down left 75 22"))

;; 10. Short leaf.
(test-case "a one-row leaf has no labels; the press places the point"
  (def! 'e10 '((s0 ensure-visible 80 1) handle-event "mouse down left 79 0"))
  (at! 'e10 '(0 5))
  (check-equal? (text-of 'e10) contents))

;; 11. Keys still work.
(test-case "keys still take handle-key after a label press"
  (def! 'e11 (press 's0 "mouse down left 75 22"))
  (def! 'e11x '(e11 handle-event "x"))
  (check-equal? (text-of 'e11x) "xhello\nworld\nxyz")
  (at! 'e11x '(0 1))
  (selected! 'e11x 0)
  (stores! 'e11x 1 '(0 0) '(0 0))
  (def! 'e11q '(e11x handle-event "escape"))
  (check-true (ev '(e11q quit)))
  (unchanged! 'e11q "mouse down left 79 22"))

;; 12. Runner: the scripted-term shape from mouse.rkt.
(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define size-calls (box 0))
  (define recorded '())
  (define (record! event) (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'aloemacs-mode-buttons-output
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
;; The screen rows of a split frame, 0-based, that carry the group.
(define (group-rows frame)
  (define body (substring frame (string-length "\e[?25l\e[2J\e[H")))
  (for/list ([row (string-split body "\r\n" #:trim? #f)] [i (in-naturals)]
             #:when (string-contains? row GROUP))
    i))

(test-case "runner: ctrl-x 2, a press on the lower ×, then escape"
  (define keys '("ctrl-x" "2" "mouse down left 79 22" "escape"))
  (define-values (receiver remaining events) (make-scripted-term keys))
  (run-aloemacs-with-hosts receiver (fs-double) "a.txt")
  (check-equal? (unbox remaining) '())
  (define recorded (events))
  (define frames
    (for/list ([event recorded] #:when (and (pair? event) (eq? (car event) 'write)))
      (cadr event)))
  (check-equal? (length frames) 4)
  (check-equal?
   recorded
   (append-map (lambda (frame key)
                 (list '(columns 80) '(rows 24) (list 'write frame) 'flush (list 'key key)))
               frames keys))
  (check-equal? (occurrences (list-ref frames 0) GROUP) 1)
  (check-equal? (occurrences (list-ref frames 2) GROUP) 2)
  (check-equal? (group-rows (list-ref frames 2)) '(11 22))
  (check-equal? (list-ref frames 3) (list-ref frames 0))
  (check-equal? (frame-tail (list-ref frames 3)) "\e[1;1H\e[?25h")
  (check-true (string-suffix? (list-ref frames 3) "\e[24;1H\e[1;1H\e[?25h")))
