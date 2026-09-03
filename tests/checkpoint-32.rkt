#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/parse.rkt"
         "../aloe/main.rkt")

(define-runtime-path mpl-directory "../examples/mpl")
(define core-path (build-path mpl-directory "core.aloe"))

(define overload-fixtures
  #<<ALOE
(define-class OverloadProbe
  (fields)
  (methods
    (pick (n Int) Int 1)
    (pick (s Sym) Int 2)))
(define-class SpecificityProbe
  (fields)
  (methods
    (pick (m Math) Int 10)
    (pick (s Sym) Int 20)))
(define-class AmbiguousProbe
  (fields)
  (methods
    (pick (first Sym) Int 1)
    (pick (second Sym) Int 2)))
ALOE
  )

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"
   overload-fixtures))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + 3)" checker-environment))
 'Sum)
(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + x)" checker-environment))
 'Sum)
(check-equal?
 (type->datum (typecheck-source "(x + y)" checker-environment))
 'Sum)
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

;; Same selector and arity dispatch by the exact argument class.
(check-equal?
 (type->datum
  (typecheck-source "((OverloadProbe new) pick 7)"
                    checker-environment))
 'Int)
(check-equal?
 (type->datum
  (typecheck-source "((OverloadProbe new) pick x)"
                    checker-environment))
 'Int)

;; An exact Sym parameter is more specific than a Math protocol parameter.
(check-equal?
 (type->datum
  (typecheck-source "((SpecificityProbe new) pick x)"
                    checker-environment))
 'Int)
(check-equal?
 (type->datum
  (typecheck-source
   "((SpecificityProbe new) pick (Sum new (List of x) 2))"
   checker-environment))
 'Int)
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source
    "((SpecificityProbe new) pick 2)"
    checker-environment)))
(check-exn
 #px"ambiguous message"
 (lambda ()
   (typecheck-source
    "((AmbiguousProbe new) pick x)"
    checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(check-equal?
 (eval-source "(((x + 2) + 3) const)" runtime-environment)
 5)
(check-eq?
 (inspect "((((((x + 2) + x) terms) first) factors) first)")
 x-value)
(check-equal?
 (inspect "(((((x + 2) + x) terms) first) coeff)")
 2)
(check-equal?
 (eval-source "(((x + 2) + x) const)" runtime-environment)
 2)
(check-eq? (eval-source "(((x + y) terms) first)" runtime-environment)
           x-value)
(check-eq? (eval-source "((((x + y) terms) rest) first)"
                        runtime-environment)
           y-value)

(check-equal?
 (eval-source "((OverloadProbe new) pick 7)" runtime-environment)
 1)
(check-equal?
 (eval-source "((OverloadProbe new) pick x)" runtime-environment)
 2)
(check-equal?
 (eval-source "((SpecificityProbe new) pick x)" runtime-environment)
 20)
(check-equal?
 (eval-source
  "((SpecificityProbe new) pick (Sum new (List of x) 2))"
  runtime-environment)
 10)
(check-exn
 #px"ambiguous message"
 (lambda ()
   (eval-expr
    (parse-datum '((AmbiguousProbe new) pick x))
    runtime-environment)))

;; The MPL surface no longer exposes the temporary plus selector.
(for ([name (in-list '("core.aloe" "sym.aloe" "sum.aloe" "prod.aloe"))])
  (check-false
   (regexp-match? #px"\\(plus[[:space:]]"
                  (file->string (build-path mpl-directory name)))))
