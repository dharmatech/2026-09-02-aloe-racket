#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "(1 + 2)") 3)
(check-equal? (eval-source "(5 - 3)") 2)
(check-equal? (eval-source "(4 * 3)") 12)
(check-equal? (eval-source "(7 / 2)") 3)

(check-equal? (eval-source "(1.5 + 2.5)") 4.0)
(check-equal? (eval-source "(3.0 * 4.0)") 12.0)

(check-exn #rx"expects an Int"
           (lambda () (eval-source "(1 + 2.0)")))

(check-exn #rx"expects a Float"
           (lambda () (eval-source "(1.0 + 2)")))
