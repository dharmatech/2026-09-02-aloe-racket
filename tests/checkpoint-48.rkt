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

;; Sym.* Int is value-dependent, with Math.* Int preserving chained sends.
(for ([expression
       (in-list
        '("(x * 1)"
          "(x * 0)"
          "((x * 1) * 2)"
          "(x * 2)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Math))

;; Int remains a primitive numeric type rather than a Math implementation.
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 * x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; A unit coefficient and one factor unwraps to that exact factor object.
(check-eq? (eval-source "(x * 1)" runtime-environment) x-value)
(check-equal? (inspect "((x * 1) name)") "x")
(check-equal?
 (aloe-value->string (eval-source "(x * 1)" runtime-environment))
 "#<Sym \"x\">")

;; A zero coefficient becomes a CAS Num, never a primitive Int.
(check-equal? (inspect "((x * 0) value)") 0)
(check-equal?
 (aloe-value->string (eval-source "(x * 0)" runtime-environment))
 "#<Num 0>")

;; Math.* Int finds the next multiplication after the identity unwrap.
(check-equal? (inspect "(((x * 1) * 2) coeff)") 2)
(check-equal? (inspect "((((x * 1) * 2) factors) len)") 1)
(check-eq? (inspect "((((x * 1) * 2) factors) first)") x-value)

;; Ordinary nonidentity products retain the checkpoint-41 representation.
(check-equal? (inspect "((x * 2) coeff)") 2)
(check-eq? (inspect "(((x * 2) factors) first)") x-value)

;; Recent multiplication, addition, and power goldens remain intact.
(check-equal? (inspect "(((x * y) * x) coeff)") 1)
(check-equal? (inspect "(((x * 2) + (x * 3)) coeff)") 5)
(check-equal? (inspect "(((x ^ 2) ^ 3) exp)") 6)

;; Boids remains independent of CAS identities.
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
                  "prod.aloe" "pow.aloe" "num.aloe"))])
  (check-false
   (regexp-match?
    #px"\\(0[[:space:]]+/[[:space:]]+0\\)"
    (file->string (build-path mpl-directory name)))))
