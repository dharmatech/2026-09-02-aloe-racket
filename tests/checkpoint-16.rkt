#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "((List of) empty?)") #t)
(check-equal? (eval-source "((List empty) empty?)") #t)
(check-equal? (eval-source "((List of 1 2 3) empty?)") #f)
(check-equal? (eval-source "((List of 1 2 3) first)") 1)
(check-equal? (eval-source "(((List of 1 2 3) rest) first)") 2)
(check-equal?
 (eval-source "((((List empty) cons 1) cons 2) first)")
 2)
(check-equal? (eval-source "(((List of 1 2) cons 0) first)") 0)
(check-equal?
 (eval-source
  "(define xs (List of 1 2))
   (define ys (xs cons 0))
   (xs first)")
 1)

(check-exn #rx"first on empty List"
           (lambda () (eval-source "((List empty) first)")))
(check-exn #rx"rest on empty List"
           (lambda () (eval-source "((List empty) rest)")))
(check-exn exn:fail:aloe-type?
           (lambda () (eval-source "((List of 1) cons 1.0)")))

(check-equal?
 (type->datum (typecheck-source "((List empty) cons 1)"))
 '(List Int))

(define-runtime-path boids-path "../examples/boids.aloe")
(define boids-source (file->string boids-path))

(define checker-environment (make-type-environment))
(check-equal?
 (type->datum (typecheck-source boids-source checker-environment))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 'Sim)
(check-equal?
 (type->datum
  (typecheck-source "(Sim new (List empty))" checker-environment))
 'Sim)

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment))
(check-equal?
 (eval-source
  "(((Sim new (List empty)) flock) empty?)"
  runtime-environment)
 #t)
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)
