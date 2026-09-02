#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path boids-path "../examples/boids.aloe")
(define boids-source (file->string boids-path))

(define far-sim-source
  (string-append
   "(define far-sim\n"
   "  (Sim new\n"
   "    (List of\n"
   "      (Boid new (Point new 0.0 0.0) (Point new 0.0 0.0))\n"
   "      (Boid new (Point new 1000.0 0.0) (Point new 0.0 0.0)))))"))

(define checker-environment (make-type-environment))
(check-equal?
 (type->datum (typecheck-source boids-source checker-environment))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 'Sim)
(void (typecheck-source far-sim-source checker-environment))
(check-equal?
 (type->datum (typecheck-source "(far-sim step)" checker-environment))
 'Sim)

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment))
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)
(void (eval-source far-sim-source runtime-environment))
(check-=
 (eval-source
  "(((((far-sim step) flock) first) position) x)"
  runtime-environment)
 0.0
 0.000001)
(check-=
 (eval-source
  "((((((far-sim step) flock) rest) first) position) x)"
  runtime-environment)
 1000.0
 0.000001)
