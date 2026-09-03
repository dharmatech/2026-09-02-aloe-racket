#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define-runtime-path core-path "../examples/mpl/core.aloe")

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(check-equal?
 (type->datum (typecheck-source "(x + 2)" checker-environment))
 '(Sum Sym Int))
(check-equal?
 (type->datum (typecheck-source "(x + y)" checker-environment))
 '(Sum Sym Sym))
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))
(define x-plus-two (eval-source "(x + 2)" runtime-environment))
(define x-plus-y (eval-source "(x + y)" runtime-environment))

;; Math is intentionally only a marker type and has no selectors. Inspect the
;; concrete runtime result directly rather than statically sending fields to a
;; value whose declared type is Math.
(define (runtime-eval datum)
  (eval-expr (parse-datum datum) runtime-environment))

(check-regexp-match #px"^#<Sum " (aloe-value->string x-plus-two))
(check-eq? (runtime-eval '((x + 2) left))
           x-value)
(check-equal? (runtime-eval '((x + 2) right))
              2)

(check-regexp-match #px"^#<Sum " (aloe-value->string x-plus-y))
(check-eq? (runtime-eval '((x + y) left))
           x-value)
(check-eq? (runtime-eval '((x + y) right))
           y-value)

(check-equal? (eval-source "(x name)" runtime-environment)
              "x")
