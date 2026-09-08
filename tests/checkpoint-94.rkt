#lang racket/base

(require rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define option-program
  #<<ALOE
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))))
ALOE
  )

(define environment (make-top-level-env))
(void (eval-source option-program environment))

;; Named construction allocates an instance with the selected constructor id.
(define some (eval-source "(Option Some \"x\")" environment))
(check-true (instance-value? some))
(check-eq? (instance-value-constructor some) 'Some)

;; Methods and case dispatch observe the constructor installed on the class.
(check-true
 (eval-source "((Option Some \"x\") present?)" environment))
(check-equal?
 (eval-source
  #<<ALOE
((Option Some "x") case
  (None () "unknown")
  (Some (name) name))
ALOE
  environment)
 "x")

;; None's type argument comes from the checked context. The evaluator may
;; leave that erased runtime argument undetermined, but construction must run.
(check-false
 (eval-source
  "((if #t (Option None) (Option Some \"x\")) present?)"
  environment))

;; Constructor payload arity and unknown selectors are runtime class-message
;; behavior too, independent of the checker in eval-source.
(check-exn
 #rx"arity error for Some: expected 1 argument"
 (lambda ()
   (eval-expr (parse-datum '(Option Some)) environment)))
(check-exn
 #rx"arity error for None: expected 0 argument"
 (lambda ()
   (eval-expr (parse-datum '(Option None "x")) environment)))
(check-exn
 #rx"unknown message: Other"
 (lambda ()
   (eval-expr (parse-datum '(Option Other)) environment)))

;; The exact bare-constructor spelling is rejected by the send grammar, and
;; the constructor name itself is not installed as a top-level binding.
(check-exn
 #rx"selector must be a symbol"
 (lambda ()
   (eval-expr (parse-datum '(Some "x")) environment)))
(check-exn
 #rx"unbound symbol: Some"
 (lambda ()
   (eval-expr (parse-datum 'Some) environment)))

;; Constructor identity participates in structural equality even when two
;; constructors have payloads with the same shape and values.
(void
 (eval-source
  #<<ALOE
(define-class Tagged
  (constructors
    (Left (fields (value Int)))
    (Right (fields (value Int))))
  (methods))
ALOE
  environment))
(define same-tag
  (eval-source "(check (Tagged Left 1) (Tagged Left 1))" environment))
(check-eq? (instance-value-constructor same-tag) 'Left)
(check-exn
 #rx"check failed"
 (lambda ()
   (eval-source "(check (Tagged Left 1) (Tagged Right 1))" environment)))

;; The existing fields form remains a singleton constructor named new.
(void
 (eval-source
  "(define-class Point (fields (x Int) (y Int)) (methods))"
  environment))
(define point (eval-source "(Point new 1 2)" environment))
(check-eq? (instance-value-constructor point) 'new)
(check-equal? (eval-source "((Point new 1 2) x)" environment) 1)

;; The checkpoint's checker rejections remain in force.
(define checker-environment (make-type-environment))
(void (typecheck-source option-program checker-environment))
(check-exn
 #rx"cannot infer type parameter T for Option"
 (lambda ()
   (typecheck-source "(define n (Option None))" checker-environment)))
(check-exn
 #rx"cannot infer type parameter T for Option"
 (lambda ()
   (typecheck-source
    "(if #t (Option None) (Option None))"
    checker-environment)))
(check-exn
 #rx"missing constructors: \\(None\\)"
 (lambda ()
   (typecheck-source
    "((Option Some \"x\") case (Some (name) name))"
    checker-environment)))
