#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-equal? (type->datum (typecheck-source "\"x\"")) 'String)

(define x-value (eval-source "\"x\""))
(check-true (string? x-value))
(check-equal? x-value "x")

(define environment (make-top-level-env))
(check-equal?
 (eval-source "(define name \"x\")\nname" environment)
 "x")

(check-exn
 exn:fail?
 (lambda () (eval-source "(\"x\" + \"y\")")))

;; Selectors remain literal symbols; a string cannot occupy selector position.
(check-exn
 exn:fail?
 (lambda () (eval-source "(\"x\" \"y\")")))
