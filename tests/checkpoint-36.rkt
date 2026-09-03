#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define parsed-protocol
  (parse-datum
   '(define-protocol Math
      (math-name () String)
      (same-term? (other Math) Bool)
      (coeff-plus (other Math) Math))))

(check-true (define-protocol-expr? parsed-protocol))
(check-eq? (define-protocol-expr-name parsed-protocol) 'Math)
(check-equal?
 (map method-declaration-selector
      (define-protocol-expr-signatures parsed-protocol))
 '(math-name same-term? coeff-plus))

;; Marker protocols remain legal.
(check-equal?
 (type->datum (typecheck-source "(define-protocol Marker)"))
 'Void)

(define required-protocol-program
  #<<ALOE
(define-protocol Math
  (math-name () String)
  (same-term? (other Math) Bool)
  (coeff-plus (other Math) Math))
(define-class A Math
  (fields
    (name String))
  (methods
    (math-name () String (self name))
    (same-term? (other Math) Bool
      ((self math-name) = (other math-name)))
    (coeff-plus (other Math) A self)))
(define-class MathBox
  (fields
    (value Math))
  (methods))
(define a (A new "a"))
(define boxed (MathBox new a))
ALOE
  )

(define checker-environment (make-type-environment))
(void (typecheck-source required-protocol-program checker-environment))

;; The receiver of each send is statically Math after the field read.
(check-equal?
 (type->datum
  (typecheck-source "((boxed value) math-name)" checker-environment))
 'String)
(check-equal?
 (type->datum
  (typecheck-source "((boxed value) same-term? a)"
                    checker-environment))
 'Bool)
(check-equal?
 (type->datum
  (typecheck-source "((boxed value) coeff-plus a)"
                    checker-environment))
 'Math)

(define runtime-environment (make-top-level-env))
(void (eval-source required-protocol-program runtime-environment))
(check-true
 (eval-source "((boxed value) same-term? a)" runtime-environment))

;; Every required method must exist; this class omits math-name.
(check-exn
 #px"class Missing does not implement protocol Math method math-name"
 (lambda ()
   (typecheck-source
    #<<ALOE
(define-protocol Math
  (math-name () String)
  (same-term? (other Math) Bool)
  (coeff-plus (other Math) Math))
(define-class Missing Math
  (fields)
  (methods
    (same-term? (other Math) Bool #t)
    (coeff-plus (other Math) Math self)))
ALOE
    )))

;; A narrower implementation parameter does not satisfy the Math contract.
(check-exn
 #px"class Narrow does not implement protocol Math method same-term\\?"
 (lambda ()
   (typecheck-source
    #<<ALOE
(define-protocol Math
  (math-name () String)
  (same-term? (other Math) Bool)
  (coeff-plus (other Math) Math))
(define-class Narrow Math
  (fields)
  (methods
    (math-name () String "narrow")
    (same-term? (other Narrow) Bool #t)
    (coeff-plus (other Math) Math self)))
ALOE
    )))

;; Required protocol methods continue to support the flat Sum representation.
(define-runtime-path core-path "../examples/mpl/core.aloe")
(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"))

(define mpl-checker-environment (make-type-environment))
(void (typecheck-source mpl-setup mpl-checker-environment))
(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + 3)" mpl-checker-environment))
 'Sum)
(for ([expression
       (in-list
        '("((x + 2) + x)"
          "(((x + 2) + x) + x)"
          "((((x + 2) + x) + x) + x)"))])
  (check-equal?
   (type->datum
    (typecheck-source expression mpl-checker-environment))
   'Sum))

(define mpl-runtime-environment (make-top-level-env))
(void (eval-source mpl-setup mpl-runtime-environment))

(define (inspect-mpl source)
  (eval-expr (car (read-program source)) mpl-runtime-environment))
(check-equal?
 (eval-source "(((x + 2) + 3) const)" mpl-runtime-environment)
 5)
(check-equal?
 (inspect-mpl "((((((x + 2) + x) + x) terms) first) right)")
 3)
(check-equal?
 (inspect-mpl "(((((((x + 2) + x) + x) + x) terms) first) right)")
 4)
