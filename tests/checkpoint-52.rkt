#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path identities-path "../examples/mpl/identities.aloe")
(define-runtime-path boids-path "../examples/boids.aloe")

;; Primitive equality and the successful result value do not depend on MPL.
(check-equal? (eval-source "(check 3 3)") 3)
(check-equal? (eval-source "(check 1.5 1.5)") 1.5)
(check-equal? (eval-source "(check #t #t)") #t)
(check-equal? (eval-source "(check \"aloe\" \"aloe\")") "aloe")

;; Equal user objects compare by class and recursively equal fields. The
;; successful result is the right-hand object, not a separate Check value.
(define object-environment (make-top-level-env))
(void
 (eval-source
  "(define-class Box (fields (value Int)) (methods))
   (define right-box (Box new 7))"
  object-environment))
(define right-box (eval-source "right-box" object-environment))
(check-eq?
 (eval-source "(check (Box new 7) right-box)" object-environment)
 right-box)

;; Mismatches expose both original source datums and both displayed values.
(check-exn
 (lambda (exception)
   (define message (exn-message exception))
   (and (exn:fail? exception)
        (regexp-match? #rx"\\(1 \\+ 2\\)" message)
        (regexp-match? #rx"\\(1 \\+ 3\\)" message)
        (regexp-match? #rx"3" message)
        (regexp-match? #rx"4" message)))
 (lambda () (eval-source "(check (1 + 2) (1 + 3))")))

;; check is reserved and requires exactly two operands.
(for ([source (in-list '("(check)" "(check 1)" "(check 1 1 1)") )])
  (check-exn exn:fail? (lambda () (eval-source source))))

;; The checker requires both sides to have one type.
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(check 1 1.0)")))

;; The Aloe workbook loads its sibling core.aloe and evaluates every check.
(define identities-environment (make-top-level-env))
(check-not-exn
 (lambda ()
   (eval-source (file->string identities-path)
                identities-environment
                #:source-path identities-path)))
(check-equal?
 (eval-source "(((x ^ 2) * (x ^ 3)) show)" identities-environment)
 "(x ^ 5)")

;; Boids remains unchanged and independent of check.
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
