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

;; Identity makes Sym.+ Int value-dependent, so its honest static type is Math.
(for ([expression
       (in-list
        '("(x + 0)"
          "((x + 0) + 2)"
          "((x + 2) + -2)"
          "((x + 2) + y)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Math))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; A one-term, zero-constant Sum unwraps to the original object.
(check-eq? (eval-source "(x + 0)" runtime-environment) x-value)
(check-equal? (inspect "((x + 0) name)") "x")
(check-equal? (aloe-value->string (eval-source "(x + 0)"
                                               runtime-environment))
              "#<Sym \"x\">")

;; Math.+ keeps the next send findable after the value-dependent result.
(check-equal?
 (inspect "(((x + 0) + 2) const)")
 2)
(check-equal?
 (inspect "((((x + 0) + 2) terms) len)")
 1)
(check-eq?
 (inspect "((((x + 0) + 2) terms) first)")
 x-value)

;; Exact negative integer literals allow the same unwrap after cancellation.
(check-eq? (eval-source "((x + 2) + -2)" runtime-environment) x-value)

;; Adding a different symbol retains both terms and the constant.
(check-equal? (inspect "((((x + 2) + y) terms) len)") 2)
(check-eq? (inspect "((((x + 2) + y) terms) first)") y-value)
(check-eq?
 (inspect "(((((x + 2) + y) terms) rest) first)")
 x-value)
(check-equal? (inspect "(((x + 2) + y) const)") 2)

;; Recent multiplication and compound addition goldens remain intact.
(check-equal? (inspect "(((x * y) * x) coeff)") 1)
(check-equal? (inspect "(((x * 2) + (x * 3)) coeff)") 5)
(check-equal? (inspect "(((x + 2) + (y + 3)) const)") 5)

;; Boids remains independent of Math.+.
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
