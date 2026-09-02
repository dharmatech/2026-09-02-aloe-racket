#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "1") 1)
(check-equal? (eval-source "1.0") 1.0)
(check-equal? (eval-source "(define x 3)\nx") 3)

(check-exn #rx"unbound symbol"
           (lambda () (eval-source "missing")))

(check-exn #rx"empty combination"
           (lambda () (eval-source "()")))
