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

;; x * y is Math, so this outer send is checked through Math.*.
(check-equal?
 (type->datum
  (typecheck-source "((x * y) * x)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "(x * (x ^ 2))" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((x ^ 2) * (x * 2))" checker-environment))
 'Math)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; Runtime lookup sees the concrete Prod and selects its exact Sym overload.
(check-equal? (inspect "(((x * y) * x) coeff)") 1)
(check-equal? (inspect "((((x * y) * x) factors) len)") 2)
(check-eq?
 (inspect "(((((x * y) * x) factors) first) base)")
 x-value)
(check-equal?
 (inspect "(((((x * y) * x) factors) first) exp)")
 2)
(check-eq?
 (inspect "(((((x * y) * x) factors) rest) first)")
 y-value)

(check-equal?
 (aloe-value->string
  (eval-expr (car (read-program "((x * y) * x)"))
             runtime-environment))
 "#<Prod coeff=1 factors=#<List #<Pow #<Sym \"x\"> 2> #<Sym \"y\">>>")

;; The checkpoint-45 cross-shape cases remain unchanged.
(check-eq? (inspect "((x * (x ^ 2)) base)") x-value)
(check-equal? (inspect "((x * (x ^ 2)) exp)") 3)
(check-equal?
 (inspect "(((x ^ 2) * (x * 2)) coeff)")
 2)
(check-eq?
 (inspect "(((((x ^ 2) * (x * 2)) factors) first) base)")
 x-value)
(check-equal?
 (inspect "(((((x ^ 2) * (x * 2)) factors) first) exp)")
 3)

;; Exact runtime types are still required when no shared protocol exists.
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source "(List of 1 2.0)" checker-environment)))

;; Recent addition and power goldens remain intact.
(check-equal? (inspect "(((x * 2) + (x * 3)) coeff)") 5)
(check-equal?
 (inspect "(((x ^ 2) ^ 3) exp)")
 6)

;; Boids remains independent of Math.*.
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
