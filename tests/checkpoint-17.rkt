#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(check-equal?
 (eval-source
  "((List of 1 2 3) fold 0 (fn (acc n) (acc + n)))")
 6)
(check-equal?
 (eval-source
  "(((List of 1 2 3) map (fn (n) (n + 1))) first)")
 2)
(check-equal? (eval-source "(((List of 1 2 3) reverse) first)") 3)

;; eval-program also starts with the Aloe List library installed.
(check-equal?
 (eval-program
  '(((List of 1 2 3) fold 0 (fn (acc n) (acc + n)))))
 6)

(define-runtime-path boids-path "../examples/boids.aloe")
(define-runtime-path eval-path "../aloe/eval.rkt")
(define boids-source (file->string boids-path))

(define checker-environment (make-type-environment))
(check-equal?
 (type->datum (typecheck-source boids-source checker-environment))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 'Sim)

(define runtime-environment (make-top-level-env))
(void (eval-source boids-source runtime-environment))
(check-equal?
 (eval-source "(((demo step) flock) len)" runtime-environment)
 3)

;; A is inferred as Point Float here, not hardcoded to Int or List's T.
(check-equal?
 (eval-source
  (string-append
   "(((List of (Point new 1.0 2.0) (Point new 3.0 4.0)) "
   "fold (Point new 0.0 0.0) "
   "(fn (acc p) (acc + p))) x)")
  runtime-environment)
 4.0)

;; map and fold must not be Racket cases in List runtime dispatch.
(define eval-module-source (file->string eval-path))
(check-false (regexp-match? #px"\\[\\(map\\)" eval-module-source))
(check-false (regexp-match? #px"\\[\\(fold\\)" eval-module-source))
