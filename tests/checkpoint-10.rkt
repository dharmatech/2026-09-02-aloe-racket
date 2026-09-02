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

(define (with-point expression)
  (string-append generic-point-definition "\n" expression))

(check-equal?
 (type->datum (typecheck-source (with-point "(Point new 1 2)")))
 '(Point Int))
(check-not-exn
 (lambda () (eval-source (with-point "(Point new 1 2)"))))

(check-equal?
 (eval-source (with-point "((Point new 1 2) x)"))
 1)

(define float-point-addition
  "((Point new 1.0 2.0) + (Point new 3.0 4.0))")
(check-equal?
 (type->datum
  (typecheck-source (with-point float-point-addition)))
 '(Point Float))
(check-not-exn
 (lambda () (eval-source (with-point float-point-addition))))

(check-equal? (type->datum (typecheck-source "((List of 1 2 3) len)"))
              'Int)
(check-equal? (eval-source "((List of 1 2 3) len)") 3)

(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source (with-point "(Point new 1 2.0)"))))

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source (with-point "((Point new 1 2) position)"))))

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source (with-point "((Point new 1 2) len)"))))

(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(List of 1 2.0)")))

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source
    (with-point
     "((Point new 1 2) + (Point new 3.0 4.0))"))))
