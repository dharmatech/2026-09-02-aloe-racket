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

;; The Prod overload has two concrete runtime outcomes, both conforming to Math.
(for ([expression
       (in-list
        '("((x * 2) + (x * 3))"
          "((x * 2) + (y * 3))"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Math))
(check-equal?
 (type->datum
  (typecheck-source "((x * 2) + 4)" checker-environment))
 'Math)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; Like products add their coefficients and keep one factor list.
(check-equal? (inspect "(((x * 2) + (x * 3)) coeff)") 5)
(check-equal? (inspect "((((x * 2) + (x * 3)) factors) len)") 1)
(check-eq? (inspect "((((x * 2) + (x * 3)) factors) first)")
           x-value)

;; Ordered multi-factor lists also use the exact Prod same-term? overload.
(check-equal?
 (inspect "((((x * 2) * y) + ((x * 3) * y)) coeff)")
 5)
(check-equal?
 (inspect "(((((x * 2) * y) + ((x * 3) * y)) factors) len)")
 2)

;; Unlike products become two terms of a zero-constant Sum.
(check-equal?
 (inspect "((((x * 2) + (y * 3)) terms) len)")
 2)
(check-equal?
 (inspect "(((((x * 2) + (y * 3)) terms) first) coeff)")
 2)
(check-eq?
 (inspect
  "((((((x * 2) + (y * 3)) terms) first) factors) first)")
 x-value)
(check-equal?
 (inspect
  "((((((x * 2) + (y * 3)) terms) rest) first) coeff)")
 3)
(check-eq?
 (inspect
  "(((((((x * 2) + (y * 3)) terms) rest) first) factors) first)")
 y-value)
(check-equal? (inspect "(((x * 2) + (y * 3)) const)") 0)

;; Adding an Int turns the product into the sole term of a Sum.
(check-equal?
 (inspect "((((x * 2) + 4) terms) len)")
 1)
(check-equal?
 (inspect "(((((x * 2) + 4) terms) first) coeff)")
 2)
(check-eq?
 (inspect "((((((x * 2) + 4) terms) first) factors) first)")
 x-value)
(check-equal?
 (inspect "(((x * 2) + 4) const)")
 4)

(check-equal?
 (aloe-value->string
  (eval-expr
   (car (read-program "((x * 2) + (x * 3))"))
   runtime-environment))
 "#<Prod coeff=5 factors=#<List #<Sym \"x\">>>")

;; Prior compound and power goldens remain unchanged.
(check-equal?
 (inspect "(((x + 2) + (y + 3)) const)")
 5)
(check-equal?
 (inspect "(((x * 2) * (y * 3)) coeff)")
 6)
(check-equal?
 (inspect "(((x ^ 2) ^ 3) exp)")
 6)

;; Boids remains independent of MPL addition.
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
