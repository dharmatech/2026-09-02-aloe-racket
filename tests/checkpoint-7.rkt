#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "(let ((a 1) (b 2)) (a + b))") 3)

(define parallel-environment (make-top-level-env))
(eval-source "(define x 10)" parallel-environment)
(check-equal?
 (eval-source "(let ((x 1) (y x)) y)" parallel-environment)
 10)

(check-equal?
 (eval-source "(let ((f (fn (n) (n + 1)))) (f call 2))")
 3)

(check-exn #rx"malformed let"
           (lambda () (eval-source "(let ((a 1)))")))
