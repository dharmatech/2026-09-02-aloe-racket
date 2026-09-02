#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "(cond ((1 < 2) 10) (else 20))") 10)
(check-equal? (eval-source "(cond ((2 < 1) 10) (else 20))") 20)

;; The second test has type Bool but would divide by zero if evaluated.
(check-equal?
 (eval-source
  "(cond ((1 < 2) 10) (((1 / 0) < 1) 30) (else 20))")
 10)

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (eval-source "(cond ((1 < 2) 10) (else 20.0))")))
(check-exn exn:fail? (lambda () (eval-source "(cond)")))
(check-exn
 exn:fail?
 (lambda () (eval-source "(cond ((1 < 2) 10))")))
(check-exn
 exn:fail?
 (lambda ()
   (eval-source "(cond (else 10) ((1 < 2) 20) (else 30))")))

(define-runtime-path boids-path "../examples/boids.aloe")
(define boids-source (file->string boids-path))

(define scenario-source
  (string-append
   "(define far-sim\n"
   "  (Sim new\n"
   "    (List of\n"
   "      (Boid new (Point new 0.0 0.0) (Point new 0.0 0.0))\n"
   "      (Boid new (Point new 1000.0 0.0) (Point new 0.0 0.0)))))\n"
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
(void (typecheck-source scenario-source checker-environment))
(check-equal?
 (type->datum (typecheck-source "(far-sim step)" checker-environment))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(behind-sim step)" checker-environment))
 'Sim)

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment
                   #:source-path boids-path))
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)
(void (eval-source scenario-source runtime-environment))
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
(check-=
 (eval-source
  "(((((behind-sim step) flock) first) position) x)"
  runtime-environment)
 1.0
 0.000001)
