#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define point-definition
  #<<ALOE
(define-class Point
  (fields
    (x Int)
    (y Int))
  (methods))
ALOE
  )

(define environment (make-top-level-env))
(eval-source point-definition environment)

(check-equal? (eval-source "((Point new 1 2) x)" environment) 1)
(check-equal? (eval-source "((Point new 1 2) y)" environment) 2)

(check-exn #rx"arity"
           (lambda () (eval-source "(Point new 1)" environment)))

(check-exn #rx"unknown message"
           (lambda () (eval-source "((Point new 1 2) z)" environment)))

(check-exn #rx"unknown message"
           (lambda () (eval-source "(Point no-such)" environment)))
