#lang racket/base

(require rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define option-program
  #<<ALOE
(define-protocol Choice)
(define-class (Option T) Choice
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))
    (clear () (Option T)
      (Option None))
    (map (type U) (f (-> T U)) (Option U)
      (self case
        (None () (Option None))
        (Some (value) (Option Some (f call value)))))))
(define-class Point
  (fields (x Int) (y Int))
  (methods))
(define-class ChoiceBox
  (fields (choice Choice))
  (methods))
(define ok #t)
ALOE
  )

(define checker-environment (make-type-environment))
(void (typecheck-source option-program checker-environment))

(define (checked-type source [environment checker-environment])
  (type->datum (typecheck-source source environment)))

(define (check-type-error pattern source
                          [environment checker-environment])
  (check-exn
   (lambda (exception)
     (and (exn:fail:aloe-type? exception)
          (regexp-match? pattern (exn-message exception))))
   (lambda () (typecheck-source source environment))))

;; Legacy fields normalize to the singleton `new` constructor.
(check-equal?
 (checked-type "((Point new 1 2) case (new (x y) x))")
 'Int)

;; Payloads infer generic arguments, while an expected result supplies the
;; otherwise-undetermined argument for None.
(check-equal? (checked-type "(Option Some \"x\")") '(Option String))
(check-equal?
 (checked-type "(if ok (Option Some \"x\") (Option None))")
 '(Option String))
(check-equal? (checked-type "((Option Some \"x\") clear)")
              '(Option String))

;; Exhaustive and else cases bind substituted payload types and agree on one
;; result type.
(check-equal?
 (checked-type
  #<<ALOE
((Option Some "x") case
  (None () "none")
  (Some (name) (name append "!")))
ALOE
  )
 'String)
(check-equal?
 (checked-type
  #<<ALOE
((Option Some "x") case
  (Some (name) #t)
  (else #f))
ALOE
  )
 'Bool)

;; A zero-payload generic construction has no principal type without context.
(check-type-error
 #rx"cannot infer type parameter T for Option"
 "(define n (Option None))")

;; Constructor coverage is exact, and missing constructors retain declaration
;; order in diagnostics.
(check-type-error
 #rx"missing constructors: \\(None\\)"
 "((Option Some \"x\") case (Some (name) name))")
(define ordered-environment (make-type-environment))
(void
 (typecheck-source
  #<<ALOE
(define-class Ordered
  (constructors
    (First (fields))
    (Second (fields))
    (Third (fields)))
  (methods))
ALOE
  ordered-environment))
(check-type-error
 #rx"missing constructors: \\(Second Third\\)"
 "((Ordered First) case (First () 1))"
 ordered-environment)

;; Unknown, duplicate, impossible-with-else, and malformed payload coverage are
;; checker errors rather than runtime concerns.
(check-type-error
 #rx"unknown constructor Some for class Point"
 "((Point new 1 2) case (Some (value) value) (else 0))")
(check-type-error
 #rx"duplicate case constructor None"
 #<<ALOE
((Option Some "x") case
  (None () "a")
  (None () "b")
  (Some (value) value))
ALOE
  )
(check-type-error
 #rx"case with else must name at least one constructor"
 "((Option Some \"x\") case (else #f))")
(check-type-error
 #rx"case with else must leave at least one constructor unmatched"
 #<<ALOE
((Option Some "x") case
  (None () #f)
  (Some (value) #t)
  (else #f))
ALOE
  )
(check-type-error
 #rx"arity error for case constructor Some"
 #<<ALOE
((Option Some "x") case
  (None () "none")
  (Some () "some"))
ALOE
  )
(check-type-error
 #rx"case branch type mismatch|type mismatch"
 #<<ALOE
((Option Some "x") case
  (None () 0)
  (Some (value) value))
ALOE
  )
(check-type-error
 #rx"case scrutinee must be a concrete class instance"
 "(1 case (new () #t))")

;; Protocol-typed values have deliberately forgotten the constructor set.
(check-type-error
 #rx"case scrutinee must be a concrete class instance"
 #<<ALOE
(((ChoiceBox new (Option Some "x")) choice) case
  (None () #f)
  (Some (value) #t))
ALOE
  )

;; Construction selects only declared constructors and checks payload arity.
(check-type-error #rx"unknown message: Other" "(Option Other)")
(check-type-error #rx"arity error for Some" "(Option Some)")

;; Constructor selectors are reserved against methods at declaration time and
;; when methods are added later.
(check-type-error
 #rx"constructor selector Some cannot also be an instance method"
 #<<ALOE
(define-class BadCollision
  (constructors
    (Some (fields (value Int))))
  (methods
    (Some () Bool #t)))
ALOE
  (make-type-environment))
(check-type-error
 #rx"constructor selector new cannot also be an instance method"
 #<<ALOE
(define-class BadLegacyCollision
  (fields)
  (methods
    (new () Bool #t)))
ALOE
  (make-type-environment))
(define extension-environment (make-type-environment))
(void
 (typecheck-source
  #<<ALOE
(define-class Extendable
  (constructors
    (Only (fields)))
  (methods))
ALOE
  extension-environment))
(check-type-error
 #rx"constructor selector Only cannot also be an instance method"
 "(define-methods Extendable (methods (Only () Bool #t)))"
 extension-environment)

;; Generic constructor classes have their method bodies checked immediately.
(check-type-error
 #rx"missing constructors: \\(None\\)"
 #<<ALOE
(define-class (Incomplete T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (Some (value) #t)))))
ALOE
  (make-type-environment))
