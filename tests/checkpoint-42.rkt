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

(for ([expression
       (in-list
        '("((x + 2) + (y + 3))"
          "((x + x) + (x + 1))"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Sum))
(check-equal?
 (type->datum
  (typecheck-source "((x * 2) * (y * 3))" checker-environment))
 'Prod)

;; The older exact Int and Sym overloads remain selected.
(for ([expression (in-list '("(x + 2)" "(x + y)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Sum))
(check-equal?
 (type->datum (typecheck-source "(x * 2)" checker-environment))
 'Prod)
(check-equal?
 (type->datum (typecheck-source "(x * y)" checker-environment))
 'Math)
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 * x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; (x + 2) + (y + 3): concatenate unlike terms and add constants.
(check-equal?
 (eval-source "((((x + 2) + (y + 3)) terms) len)"
              runtime-environment)
 2)
(check-eq?
 (eval-source "((((x + 2) + (y + 3)) terms) first)"
              runtime-environment)
 y-value)
(check-eq?
 (eval-source "(((((x + 2) + (y + 3)) terms) rest) first)"
              runtime-environment)
 x-value)
(check-equal?
 (eval-source "(((x + 2) + (y + 3)) const)" runtime-environment)
 5)

;; Duplicate terms across two sums collapse through coeff-plus.
(check-equal?
 (eval-source "((((x + x) + (x + 1)) terms) len)"
              runtime-environment)
 1)
(check-equal?
 (inspect "(((((x + x) + (x + 1)) terms) first) coeff)")
 3)
(check-eq?
 (inspect "((((((x + x) + (x + 1)) terms) first) factors) first)")
 x-value)
(check-equal?
 (eval-source "(((x + x) + (x + 1)) const)" runtime-environment)
 1)

;; Compound products multiply coefficients and retain both unlike factors.
(check-equal?
 (eval-source "(((x * 2) * (y * 3)) coeff)" runtime-environment)
 6)
(check-equal?
 (eval-source "((((x * 2) * (y * 3)) factors) len)"
              runtime-environment)
 2)
(check-eq?
 (eval-source "((((x * 2) * (y * 3)) factors) first)"
              runtime-environment)
 y-value)
(check-eq?
 (eval-source "(((((x * 2) * (y * 3)) factors) rest) first)"
              runtime-environment)
 x-value)

;; One same-base compound case exercises exponent addition through Math.
(check-equal?
 (eval-source "((((x * 2) * (x * 3)) factors) len)"
              runtime-environment)
 1)
(check-eq?
 (inspect "(((((x * 2) * (x * 3)) factors) first) base)")
 x-value)
(check-equal?
 (inspect "(((((x * 2) * (x * 3)) factors) first) exp)")
 2)

;; Boids remains independent of the MPL protocol and overloads.
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
