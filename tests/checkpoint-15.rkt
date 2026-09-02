#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

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
  (typecheck-source
   "((Point new 0.0 0.0) dist2 (Point new 3.0 4.0))"
   checker-environment))
 'Float)

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment))
(check-equal?
 (eval-source
  "((Point new 0.0 0.0) dist2 (Point new 3.0 4.0))"
  runtime-environment)
 25.0)
(check-equal? (eval-source "(if (1.0 < 2.0) 1.0 0.0)") 1.0)
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)
