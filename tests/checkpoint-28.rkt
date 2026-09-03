#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define protocol-program
  #<<ALOE
(define-protocol Math)
(define-class A Math
  (fields)
  (methods
    (as-math () Math self)))
(define-class B Math
  (fields)
  (methods
    (as-math () Math self)
    (pick (which Bool) Math
      (if which (A new) (B new)))))
ALOE
  )

(define checker-environment (make-type-environment))
(void (typecheck-source protocol-program checker-environment))

(check-equal?
 (type->datum
  (typecheck-source "((A new) as-math)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((B new) pick #t)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((B new) pick #f)" checker-environment))
 'Math)

;; Protocol membership does not supply messages; lookup still uses A's class.
(check-exn
 #px"unknown message"
 (lambda ()
   (typecheck-source
    "((A new) no-such)"
    checker-environment)))

(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source
    #<<ALOE
(define-protocol Math)
(define-class C
  (fields)
  (methods
    (as-math () Math self)))
ALOE
    )))

;; Protocol declarations are checker-only; opted-in objects keep normal
;; class-based runtime behavior.
(define runtime-environment (make-top-level-env))
(check-not-exn
 (lambda () (eval-source protocol-program runtime-environment)))
