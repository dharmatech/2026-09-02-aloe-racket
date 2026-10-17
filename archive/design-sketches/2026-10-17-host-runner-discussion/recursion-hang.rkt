#lang racket/base
;; Reproduction of the checker hang on a recursive method of a generic class
;; without explicit constructors. Found 2026-10-17 in the host runner
;; discussion. THIS PROGRAM DOES NOT TERMINATE: the second driver-eval!
;; never returns, because aloe/type.rkt re-checks the method body at every
;; instance send with no record of a body already being checked.
;;   timeout 10 racket recursion-hang.rkt

(require "../../../aloe/driver.rkt")

(module+ main
  (define state (make-driver))
  (driver-eval!
   state
   '(define-class (Loop H)
      (fields (h H))
      (methods
        (run (n Int) Int
          (if (n = 0) 0 (self run (n - 1)))))))
  (printf "class accepted; sending ((Loop new 1) run 3) ...\n")
  (flush-output)
  (printf "result: ~a\n" (driver-eval! state '((Loop new 1) run 3))))
