#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define generic-point-definition
  #<<ALOE
(define-class (Point T)
  (fields
    (x T)
    (y T))
  (methods
    (+ (other (Point T)) (Point T)
      (Point new
        ((self x) + (other x))
        ((self y) + (other y))))))
ALOE
  )

(define environment (make-top-level-env))
(eval-source generic-point-definition environment)

(check-equal? (eval-source "((Point new 1 2) x)" environment) 1)
(check-equal? (eval-source "((Point new 1.0 2.0) x)" environment) 1.0)

(check-exn #rx"inconsistent type parameter"
           (lambda () (eval-source "(Point new 1 2.0)" environment)))

(check-equal?
 (eval-source "(((Point new 1 2) + (Point new 3 4)) x)" environment)
 4)

(check-exn #rx"generic instantiation mismatch"
           (lambda ()
             (eval-source
              "((Point new 1 2) + (Point new 3.0 4.0))"
              environment)))
