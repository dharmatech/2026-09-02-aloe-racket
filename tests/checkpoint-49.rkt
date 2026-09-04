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

;; Power construction is value-dependent but remains available as Math.
(for ([expression
       (in-list
        '("(x ^ 0)"
          "(x ^ 1)"
          "(x ^ 2)"
          "((x ^ 1) * 2)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Math))

;; Primitive Int remains outside the Math protocol.
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 ^ x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; The two identity exponents unwrap to CAS one and the original base.
(check-equal? (inspect "((x ^ 0) value)") 1)
(check-equal?
 (aloe-value->string (eval-source "(x ^ 0)" runtime-environment))
 "#<Num 1>")
(check-eq? (eval-source "(x ^ 1)" runtime-environment) x-value)
(check-equal?
 (aloe-value->string (eval-source "(x ^ 1)" runtime-environment))
 "#<Sym \"x\">")

;; Nonidentity powers stay Pow values.
(check-eq? (inspect "((x ^ 2) base)") x-value)
(check-equal? (inspect "((x ^ 2) exp)") 2)

;; A send after the base identity resolves through Math.* Int.
(check-equal? (inspect "(((x ^ 1) * 2) coeff)") 2)
(check-equal? (inspect "((((x ^ 1) * 2) factors) len)") 1)
(check-eq? (inspect "((((x ^ 1) * 2) factors) first)") x-value)

;; Recent additive and multiplicative identities remain intact.
(check-eq? (eval-source "(x + 0)" runtime-environment) x-value)
(check-eq? (eval-source "(x * 1)" runtime-environment) x-value)
(check-equal? (inspect "((x * 0) value)") 0)

;; Boids remains independent of the CAS power identity.
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
