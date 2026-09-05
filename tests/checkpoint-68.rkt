#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(check-equal?
 (type->datum
  (typecheck-source "((Mirror of 10) raw)"))
 'String)
(check-equal? (eval-source "((Mirror of 10) raw)" environment) "10")

(define point-raw
  (eval-source
   "((Mirror of (Point new 10 20)) raw)"
   environment))
(check-true (string? point-raw))
(check-regexp-match #rx"Point" point-raw)
(check-regexp-match #rx"10" point-raw)
(check-regexp-match #rx"20" point-raw)

(void
 (eval-source
  "(define stack (gel-start call (Point new 10 20)))"
  environment))
(define tos-text
  (eval-source "(gel-tos-text call stack)" environment))
(check-regexp-match #rx"^TOS:" tos-text)
(check-regexp-match #rx"Point" tos-text)

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source source environment))))

(check-type-error "(1 raw)")
(check-type-error "(Point raw)")
(check-type-error "((Point new 1 2) raw)")
