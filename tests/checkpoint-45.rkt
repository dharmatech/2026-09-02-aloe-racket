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

(check-equal?
 (type->datum
  (typecheck-source "((x ^ 2) * x)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "(x * (x ^ 2))" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((x ^ 2) * (x * 2))" checker-environment))
 'Prod)
(check-equal?
 (type->datum
  (typecheck-source "((x * 2) * (x ^ 2))" checker-environment))
 'Prod)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; Pow * Sym adds the implicit Sym exponent of one.
(check-eq? (inspect "(((x ^ 2) * x) base)") x-value)
(check-equal? (inspect "(((x ^ 2) * x) exp)") 3)

;; Sym * Pow is the symmetric exact overload.
(check-eq? (inspect "((x * (x ^ 2)) base)") x-value)
(check-equal? (inspect "((x * (x ^ 2)) exp)") 3)

;; Pow * Prod preserves the flat coefficient and merges into its factors.
(check-equal?
 (eval-source "(((x ^ 2) * (x * 2)) coeff)" runtime-environment)
 2)
(check-equal?
 (eval-source "((((x ^ 2) * (x * 2)) factors) len)"
              runtime-environment)
 1)
(check-eq?
 (inspect "(((((x ^ 2) * (x * 2)) factors) first) base)")
 x-value)
(check-equal?
 (inspect "(((((x ^ 2) * (x * 2)) factors) first) exp)")
 3)

;; Prod * Pow follows the same insertion rule.
(check-equal?
 (eval-source "(((x * 2) * (x ^ 2)) coeff)" runtime-environment)
 2)
(check-eq?
 (inspect "(((((x * 2) * (x ^ 2)) factors) first) base)")
 x-value)
(check-equal?
 (inspect "(((((x * 2) * (x ^ 2)) factors) first) exp)")
 3)

;; Earlier equal-shape multiplication rules remain unchanged.
(check-eq? (inspect "((x * x) base)") x-value)
(check-equal? (inspect "((x * x) exp)") 2)
(check-eq? (inspect "(((x ^ 2) * (x ^ 3)) base)") x-value)
(check-equal? (inspect "(((x ^ 2) * (x ^ 3)) exp)") 5)

(check-equal?
 (aloe-value->string
  (eval-expr (car (read-program "((x ^ 2) * x)"))
             runtime-environment))
 "#<Pow #<Sym \"x\"> 3>")

;; Recent compound addition and power rules remain intact.
(check-equal?
 (inspect "(((x * 2) + (x * 3)) coeff)")
 5)
(check-equal?
 (eval-source "(((x ^ 2) ^ 3) exp)" runtime-environment)
 6)

;; Boids remains independent of MPL multiplication.
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
