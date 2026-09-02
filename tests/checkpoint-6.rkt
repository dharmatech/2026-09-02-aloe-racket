#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "((fn (x) (x + 1)) call 2)") 3)
(check-equal? (eval-source "((fn (x y) (x + y)) call 1 2)") 3)

(check-exn #rx"selector must be a symbol"
           (lambda () (eval-source "((fn (x) x) 2)")))

(check-exn #rx"arity"
           (lambda () (eval-source "((fn (x) x) call)")))

(check-exn #rx"unknown message"
           (lambda () (eval-source "((fn (x) x) no-such)")))

(define closure-environment (make-top-level-env))
(eval-source "(define n 10)" closure-environment)
(check-equal?
 (eval-source "((fn (x) (x + n)) call 1)" closure-environment)
 11)
