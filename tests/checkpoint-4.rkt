#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define point-definition
  #<<ALOE
(define-class Point
  (fields
    (x Int)
    (y Int))
  (methods
    (+ (other (Point Int)) (Point Int)
      (Point new
        ((self x) + (other x))
        ((self y) + (other y))))))
ALOE
  )

(define environment (make-top-level-env))
(eval-source point-definition environment)

(check-equal?
 (eval-source "(((Point new 1 2) + (Point new 3 4)) x)" environment)
 4)
(check-equal?
 (eval-source "(((Point new 1 2) + (Point new 3 4)) y)" environment)
 6)

(check-exn #rx"unbound symbol: self"
           (lambda () (eval-source "(self x)" environment)))

(check-exn #rx"arity"
           (lambda () (eval-source "((Point new 1 2) +)" environment)))

(check-exn #rx"unknown message"
           (lambda ()
             (eval-source "((Point new 1 2) no-such)" environment)))

(check-equal? (eval-source "(1 + 2)" environment) 3)
