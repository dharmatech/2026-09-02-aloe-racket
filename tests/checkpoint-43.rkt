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
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(check-equal?
 (type->datum
  (typecheck-source "((x ^ 2) ^ 3)" checker-environment))
 'Pow)
(check-equal?
 (type->datum
  (typecheck-source "((x * y) ^ 2)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((x * 2) ^ 3)" checker-environment))
 'Math)
(check-equal?
 (type->datum (typecheck-source "(x ^ 0)" checker-environment))
 'Pow)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; Pow exponents multiply, including identity and represented zero powers.
(check-eq? (eval-source "(((x ^ 2) ^ 3) base)" runtime-environment)
           x-value)
(check-equal? (eval-source "(((x ^ 2) ^ 3) exp)" runtime-environment)
              6)
(check-eq? (eval-source "(((x ^ 2) ^ 1) base)" runtime-environment)
           x-value)
(check-equal? (eval-source "(((x ^ 2) ^ 1) exp)" runtime-environment)
              2)
(check-eq? (eval-source "(((x ^ 2) ^ 0) base)" runtime-environment)
           x-value)
(check-equal? (eval-source "(((x ^ 2) ^ 0) exp)" runtime-environment)
              0)
(check-eq? (eval-source "((x ^ 0) base)" runtime-environment) x-value)
(check-equal? (eval-source "((x ^ 0) exp)" runtime-environment) 0)

;; Power distributes over the factors of a flat product, not over sums.
(check-equal? (inspect "(((x * y) ^ 2) coeff)") 1)
(check-equal? (inspect "((((x * y) ^ 2) factors) len)") 2)
(check-eq? (inspect "(((((x * y) ^ 2) factors) first) base)")
           x-value)
(check-equal? (inspect "(((((x * y) ^ 2) factors) first) exp)") 2)
(check-eq?
 (inspect "((((((x * y) ^ 2) factors) rest) first) base)")
 y-value)
(check-equal?
 (inspect "((((((x * y) ^ 2) factors) rest) first) exp)")
 2)

;; The integer coefficient is exponentiated using existing Int arithmetic.
(check-equal? (inspect "(((x * 2) ^ 3) coeff)")
              8)
(check-equal? (inspect "((((x * 2) ^ 3) factors) len)")
              1)
(check-eq? (inspect "(((((x * 2) ^ 3) factors) first) base)")
           x-value)
(check-equal? (inspect "(((((x * 2) ^ 3) factors) first) exp)") 3)

;; Checkpoint 42 compound behavior remains intact.
(check-equal?
 (inspect "(((x + 2) + (y + 3)) const)")
 5)
(check-equal?
 (inspect "(((x * 2) * (y * 3)) coeff)")
 6)
(check-equal?
 (inspect "((((x * 2) * (y * 3)) factors) len)")
 2)

;; Boids remains independent of the MPL power protocol.
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

(for ([name
       (in-list '("core.aloe" "sym.aloe" "sum.aloe"
                  "prod.aloe" "pow.aloe"))])
  (check-false
   (regexp-match?
    #px"\\(0[[:space:]]+/[[:space:]]+0\\)"
    (file->string (build-path mpl-directory name)))))
