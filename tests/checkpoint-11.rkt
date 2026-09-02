#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path boids-path "../boids.sexpr")
(define boids-source (file->string boids-path))

(check-equal? (eval-source "(1 float)") 1.0)
(check-exn #rx"unknown message: float"
           (lambda () (eval-source "(1.0 float)")))

(define checker-environment (make-type-environment))
(check-equal?
 (type->datum (typecheck-source boids-source checker-environment))
 '(Sim Float))
(check-equal?
 (type->datum (typecheck-source "demo" checker-environment))
 '(Sim Float))
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 '(Sim Float))

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source
    "(Boid new (Point new 1 2) (Point new 1.0 2.0))"
    checker-environment)))

(define runtime-environment (make-top-level-env))
(check-not-exn
 (lambda () (eval-source boids-source runtime-environment)))
(check-equal?
 (eval-source "((demo flock) len)" runtime-environment)
 3)
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)
