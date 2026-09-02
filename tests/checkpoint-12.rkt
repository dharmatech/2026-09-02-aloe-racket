#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path boids-path "../examples/boids.aloe")
(define boids-source (file->string boids-path))

(define checker-environment (make-type-environment))
(check-equal?
 (type->datum
  (typecheck-source boids-source checker-environment
                    #:source-path boids-path))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "demo" checker-environment))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 'Sim)

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source
    (string-append
     "(Sim new (List of "
     "(Boid new (Point new 0 0) (Point new 1 0))))")
    checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment
                   #:source-path boids-path))
(check-equal?
  (eval-source "(((demo step) flock) len)" runtime-environment)
  3)
