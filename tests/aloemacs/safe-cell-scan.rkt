#lang racket/base

(require racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt")

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(test-case "80-column editor frame stays fast and paints exact text"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))

  (define line (make-string 80 #\x))
  (define source (string-join (make-list 24 line) "\n"))
  (driver-eval!
   state
   `(define editor
      (AloemacsEditor new
        (Text from-string ,source)
        (Position new 0 0)
        #f 0 0 (List empty))))

  (define frame (driver-eval! state '(editor frame 80 24)))
  (check-equal?
   frame
   (string-append
    "\u001b[?25l\u001b[2J\u001b[H"
    (string-join (make-list 24 line) "\r\n")
    "\u001b[1;1H\u001b[?25h"))

  (define durations
    (for/list ([sample (in-range 5)])
      (define start (current-inexact-monotonic-milliseconds))
      (driver-eval! state '(editor frame 80 24))
      (- (current-inexact-monotonic-milliseconds) start)))
  (define median-ms (list-ref (sort durations <) 2))
  (check-true (< median-ms 80)
              (format "80-column frame median: ~a ms (must be under 80 ms)"
                      median-ms))
  (printf "80-column frame median: ~a ms\n" median-ms))
