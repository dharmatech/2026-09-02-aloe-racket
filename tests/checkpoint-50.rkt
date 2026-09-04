#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define-runtime-path mpl-directory "../examples/mpl")
(define-runtime-path boids-path "../examples/boids.aloe")
(define core-path (build-path mpl-directory "core.aloe"))

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(for ([expression
       (in-list
        '("((x * -3) + (x * 3))"
          "(x * 0)"
          "(x * 2)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Math))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; Equal factors combine their coefficients, then zero unwraps to CAS Num.
(check-equal? (inspect "(((x * -3) + (x * 3)) value)") 0)
(check-equal?
 (aloe-value->string
  (eval-source "((x * -3) + (x * 3))" runtime-environment))
 "#<Num 0>")

;; Multiplicative zero keeps the same representation.
(check-equal? (inspect "((x * 0) value)") 0)
(check-equal?
 (aloe-value->string (eval-source "(x * 0)" runtime-environment))
 "#<Num 0>")

;; Nonzero coefficients remain flat Prod values.
(check-equal? (inspect "((x * 2) coeff)") 2)
(check-equal? (inspect "(((x * 2) factors) len)") 1)
(check-eq? (inspect "(((x * 2) factors) first)") x-value)

;; Recent identities and ordinary like-term addition remain intact.
(check-eq? (eval-source "(x * 1)" runtime-environment) x-value)
(check-equal? (inspect "(((x * 2) + (x * 3)) coeff)") 5)
(check-equal? (inspect "((x ^ 0) value)") 1)

;; Boids remains independent of CAS coefficient normalization.
(define boids-source (file->string boids-path))
(define boids-checker-environment (make-type-environment))
(check-equal?
 (type->datum
  (typecheck-source boids-source boids-checker-environment
                    #:source-path boids-path))
 'Sim)
(check-equal?
 (type->datum
  (typecheck-source "(demo step)" boids-checker-environment))
 'Sim)
(define boids-runtime-environment (make-top-level-env))
(void (eval-source boids-source boids-runtime-environment
                   #:source-path boids-path))
(check-equal?
 (eval-source "(((demo step) flock) len)" boids-runtime-environment)
 3)
