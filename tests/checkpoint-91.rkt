#lang racket/base

(require rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define point-definition
  #<<ALOE
(define-class Point
  (fields
    (x Int)
    (y Int))
  (methods
    (+ (other Point) Point
      (Point new
        ((self x) + (other x))
        ((self y) + (other y))))))
ALOE
  )

(define environment (make-top-level-env))
(void (eval-source point-definition environment))

(define point (eval-source "(Point new 1 2)" environment))
(check-true (instance-value? point))
(check-eq? (instance-value-constructor point) 'new)

;; Existing field and method sends retain their behavior, and instances
;; allocated from a method body carry the same constructor identity.
(check-equal? (eval-source "((Point new 1 2) x)" environment) 1)
(define sum
  (eval-source "((Point new 1 2) + (Point new 3 4))" environment))
(check-eq? (instance-value-constructor sum) 'new)
(check-equal? (eval-source "(((Point new 1 2) + (Point new 3 4)) y)"
                           environment)
              6)

;; Successful structural checks still return the right-hand instance.
(define checked
  (eval-source "(check (Point new 1 2) (Point new 1 2))" environment))
(check-true (instance-value? checked))
(check-eq? (instance-value-constructor checked) 'new)

;; Mirror.invoke reaches the same allocator and therefore records `new` too.
(void (eval-source "(define point-class-mirror (Mirror of Point))"
                   environment))
(define reflected
  (eval-expr
   (parse-datum
    '(point-class-mirror invoke
       ((point-class-mirror signatures) first)
       5
       6))
   environment))
(check-true (instance-value? reflected))
(check-eq? (instance-value-constructor reflected) 'new)

;; `case` remains parsed syntax with no evaluator clause in this checkpoint.
(check-exn
 exn:fail?
 (lambda ()
   (eval-expr
    (parse-datum '(point case (Anything () #t)))
    environment)))
