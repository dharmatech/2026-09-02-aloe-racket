#lang racket/base

(require rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  [make-top-level-env make-raw-top-level-env]
                  env-bound?)
         (only-in "../../aloe/eval.rkt"
                  aloe-value->string
                  eval-expr)
         "../../aloe/main.rkt"
         (only-in "../../aloe/parse.rkt"
                  parse-datum)
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?))

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

;; A raw evaluator environment: no checker, no libraries.
(define (make-raw-evaluator . datums)
  (define environment (make-raw-top-level-env))
  (define (evaluate datum)
    (eval-expr (parse-datum datum) environment))
  (for ([datum (in-list datums)])
    (evaluate datum))
  evaluate)

(define (make-identity-driver)
  (define state (make-driver))
  (for ([datum (in-list
                '((define-protocol P)
                  (define-class A P (fields) (methods))
                  (define-class Box (fields) (methods (wrap (x P) P x)))
                  (define v ((Box new) wrap (A new)))
                  (define-protocol P)
                  (define-class B P (fields) (methods))))])
    (driver-eval! state datum))
  state)

(define overloads-on-p
  '(define-class C (fields) (methods (m (x P) Int 1) (m (x Int) Int 2))))

;; Case 4's environment: P defined twice, A opted into the first.
(define (make-protocol-evaluator)
  (make-raw-evaluator
   '(define-protocol P)
   '(define-class A P (fields) (methods))
   '(define-protocol P)
   '(define-class B P (fields) (methods))
   overloads-on-p))

;; Case 5's environment: K defined twice, k1 an instance of the first.
(define (make-class-evaluator)
  (make-raw-evaluator
   '(define-class K (fields) (methods))
   '(define k1 (K new))
   '(define-class K (fields) (methods))
   '(define k2 (K new))
   '(define-class D (fields) (methods (n (x K) Int 1) (n (x Int) Int 2)))))

(test-case "define-protocol binds a value in both halves"
  (define state (make-driver))
  (check-equal? (driver-eval! state '(define-protocol P)) (void))
  (check-true (env-bound? (driver-runtime-environment state) 'P))
  (check-true (type-environment-bound? (driver-type-environment state) 'P)))

(test-case "the checker tells two protocols of one name apart"
  (define state (make-identity-driver))
  (check-equal?
   (raised (lambda ()
             (driver-eval! state '(check v ((Box new) wrap (B new))))))
   '(#t "typecheck: type mismatch: expected P, got P")))

(test-case "checker overloads select by protocol record"
  (define state (make-identity-driver))
  (driver-eval! state overloads-on-p)
  (check-equal? (raised (lambda () (driver-eval! state '((C new) m v))))
                '(#t "typecheck: unknown message: m"))
  (check-equal? (driver-eval! state '((C new) m (B new))) 1)
  (check-equal? (driver-eval! state '((C new) m 5)) 2))

(test-case "evaluator overloads select by protocol record"
  (define evaluate (make-protocol-evaluator))
  (check-equal? (evaluate '((C new) m (B new))) 1)
  (check-equal? (raised (lambda () (evaluate '((C new) m (A new)))))
                '(#f "eval-aloe: unknown message: m")))

(test-case "evaluator overloads select by class record"
  (define evaluate (make-class-evaluator))
  (check-equal? (evaluate '((D new) n k2)) 1)
  (check-equal? (raised (lambda () (evaluate '((D new) n k1))))
                '(#f "eval-aloe: unknown message: n")))

(test-case "a single candidate compares names"
  (define evaluate (make-class-evaluator))
  (evaluate '(define-class E (fields) (methods (s (x K) Int 3))))
  (check-equal? (evaluate '((E new) s k1)) 3))

(test-case "Mirror invoke and Signature accepts? compare names"
  (define evaluate (make-protocol-evaluator))
  (evaluate '(define-class Hold (fields) (methods (take (x P) Int 7))))
  (check-equal?
   (evaluate
    '((Mirror of (Hold new))
      invoke
      (((Mirror of (Hold new)) signatures) first)
      (A new)))
   7)
  (check-equal?
   (evaluate
    '((((Mirror of (Hold new)) signatures) first)
      accepts?
      (Mirror of (A new))))
   #t))

(test-case "list element protocols compare records"
  (define evaluate (make-protocol-evaluator))
  (check-equal? (raised (lambda () (evaluate '(List of (A new) (B new)))))
                '(#f "eval-aloe: List of elements must have one type"))
  (evaluate '(define-class B2 P (fields) (methods)))
  (evaluate
   '(define-class Count (fields)
      (methods (count (xs (List P)) Int (xs len)))))
  (check-equal?
   (evaluate '((Count new) count (List of (B new) (B2 new))))
   2))

(test-case "a class's protocol is looked up"
  (define evaluate (make-raw-evaluator))
  (check-equal?
   (raised (lambda ()
             (evaluate '(define-class Q1 Missing (fields) (methods)))))
   '(#f "eval-aloe: unbound symbol: Missing"))
  (evaluate '(define NotProto 1))
  (check-equal?
   (raised (lambda ()
             (evaluate '(define-class Q2 NotProto (fields) (methods)))))
   '(#f "eval-aloe: NotProto is not a protocol"))
  (evaluate '(define-protocol P))
  (check-equal? (raised (lambda () (evaluate 'P))) 'no-error)
  (check-equal? (aloe-value->string (evaluate 'P)) "#<object>"))
