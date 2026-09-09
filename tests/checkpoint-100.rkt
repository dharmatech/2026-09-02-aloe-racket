#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/term.rkt")

(define-runtime-path option-path "../lib/option.aloe")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(test-case "Option is loadable but absent from fresh drivers"
  (define state (make-driver))
  (for ([name (in-list '(Option term fs-host))])
    (check-false
     (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound?
      (driver-type-environment state) name)))
  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3)

  (check-true
   (void?
    (driver-eval!
     state
     `(load ,(path->string option-path)))))
  (check-true
   (env-bound? (driver-runtime-environment state) 'Option))
  (check-true
   (type-environment-bound?
    (driver-type-environment state) 'Option))
  (check-false
   (env-bound? (driver-runtime-environment state) 'Some))
  (check-false
   (type-environment-bound?
    (driver-type-environment state) 'Some))
  (check-false
   (env-bound? (driver-runtime-environment state) 'None))
  (check-false
   (type-environment-bound?
    (driver-type-environment state) 'None))

  (check-equal?
   (driver-type-datum state '(Option Some "x"))
   '(Option String))
  (check-equal?
   (driver-type-datum state '((Option Some "x") present?))
   'Bool)
  (check-equal?
   (driver-type-datum
    state
    '((if #t (Option None) (Option Some "x")) present?))
   'Bool)
  (check-equal?
   (driver-type-datum
    state
    '((Option Some "x") case
       (None () "unknown")
       (Some (name) name)))
   'String)

  (check-true
   (driver-eval! state '((Option Some "x") present?)))
  (check-false
   (driver-eval!
    state
    '((if #t (Option None) (Option Some "x")) present?)))
  (check-equal?
   (driver-eval!
    state
    '((Option Some "x") case
       (None () "unknown")
       (Some (name) name)))
   "x")

  (check-exn
   #rx"cannot infer type parameter T for Option"
   (lambda ()
     (driver-eval! state '(define n (Option None)))))
  (check-exn
   #rx"missing constructors: \\(None\\)"
   (lambda ()
     (driver-eval!
      state
      '((Option Some "x") case
         (Some (name) name)))))
  (check-exn
   #rx"selector must be a symbol|unbound symbol: Some"
   (lambda ()
     (driver-eval! state '(Some "x"))))

  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3))

(test-case "Term remains separately injected and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal?
   (driver-eval! state '(term write-line "sealed"))
   "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
