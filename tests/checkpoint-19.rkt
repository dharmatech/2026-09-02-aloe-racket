#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path boids-path "../examples/boids.aloe")
(define boids-source (file->string boids-path))

(define behind-sim-source
  (string-append
   "(define behind-sim\n"
   "  (Sim new\n"
   "    (List of\n"
   "      (Boid new (Point new 0.0 0.0) (Point new 1.0 0.0))\n"
   "      (Boid new (Point new -10.0 0.0) (Point new 0.0 0.0)))))"))

(define checker-environment (make-type-environment))
(check-equal?
 (type->datum
  (typecheck-source boids-source checker-environment
                    #:source-path boids-path))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 'Sim)
(void (typecheck-source behind-sim-source checker-environment))
(check-equal?
 (type->datum (typecheck-source "(behind-sim step)" checker-environment))
 'Sim)

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment
                   #:source-path boids-path))
(check-equal?
 (eval-source
  "((Point new 1.0 0.0) dot (Point new 0.0 1.0))"
  runtime-environment)
 0.0)
(check-equal?
 (eval-source
  "((Point new 1.0 0.0) dot (Point new 2.0 0.0))"
  runtime-environment)
 2.0)
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)

(void (eval-source behind-sim-source runtime-environment))
;; B is within the 50.0 radius but behind A's +x heading. With no
;; cohesion/alignment contribution and no separation at dist2 100.0,
;; A advances only by its existing velocity from x = 0.0 to x = 1.0.
(check-=
 (eval-source
  "(((((behind-sim step) flock) first) position) x)"
  runtime-environment)
 1.0
 0.000001)
