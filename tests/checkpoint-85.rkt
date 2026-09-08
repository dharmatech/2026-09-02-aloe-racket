#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt"
                  env-bound?
                  env-define!
                  env-lookup)
         "../aloe/host.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/term.rkt")

(define-runtime-path term-path "../host/racket/term.rkt")
(define-runtime-path type-path "../aloe/type.rkt")

(define (driver-type-of state datum)
  (type-of (parse-datum datum) (driver-type-environment state)))

(define (static-error? . patterns)
  (lambda (exception)
    (and (exn:fail:aloe-type? exception)
         (for/and ([pattern (in-list patterns)])
           (regexp-match? pattern (exn-message exception))))))

(define (make-test-interface [name 'TestHost])
  (make-host-interface
   name
   (list
    (make-host-method 'ping '() 'String (lambda (_state) "pong")))))

(test-case "a driver injects Term into runtime and checker environments"
  (define reader-calls 0)
  (define output (open-output-string))
  (define receiver
    (make-term-receiver
     output
     (lambda ()
       (set! reader-calls (add1 reader-calls))
       "q")))
  (define state (make-driver))
  (check-true (void? (driver-inject-host! state 'term receiver)))
  (check-eq? (env-lookup (driver-runtime-environment state) 'term)
             receiver)
  (check-equal? (type->datum (driver-type-of state 'term)) 'Term)
  (check-exn exn:fail:contract?
             (lambda () (driver-inject-host! state 'term receiver)))
  (check-eq? (env-lookup (driver-runtime-environment state) 'term)
             receiver)

  ;; Descriptor checking alone performs neither terminal operation.
  (check-equal?
   (type->datum (driver-type-of state '(term read-key)))
   'String)
  (check-equal?
   (type->datum (driver-type-of state '(term write-line "hi")))
   'String)
  (check-equal? reader-calls 0)
  (check-equal? (get-output-string output) "")

  (check-equal? (driver-eval! state '(term read-key)) "q")
  (check-equal? reader-calls 1)
  (check-equal? (driver-eval! state '(term write-line "hi")) "hi")
  (check-equal? (get-output-string output) "hi\r\n"))

(test-case "an Aloe alias retains the injected nominal host type"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "q")))
  (check-true (void? (driver-eval! state '(define console term))))
  (check-equal? (type->datum (driver-type-of state 'console)) 'Term)
  (check-equal? (driver-eval! state '(console read-key)) "q")
  (check-equal? (driver-eval! state '(console write-line "alias")) "alias")
  (check-equal? (get-output-string output) "alias\r\n"))

(test-case "invalid Term sends fail statically without effects"
  (define reader-calls 0)
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state
   'term
   (make-term-receiver
    output
    (lambda ()
      (set! reader-calls (add1 reader-calls))
      "q")))
  (check-exn
   (static-error? #rx"unknown message" #rx"missing")
   (lambda () (driver-eval! state '(term missing))))
  (check-exn
   (static-error? #rx"arity" #rx"Term" #rx"write-line")
   (lambda () (driver-eval! state '(term write-line))))
  (check-exn
   (static-error? #rx"arity" #rx"Term" #rx"read-key")
   (lambda () (driver-eval! state '(term read-key "extra"))))
  (check-exn
   (static-error? #rx"Term" #rx"write-line" #rx"String")
   (lambda () (driver-eval! state '(term write-line 1))))
  (check-equal? reader-calls 0)
  (check-equal? (get-output-string output) ""))

(test-case "all crossing declarations map directly to scalar checker types"
  (define interface
    (make-host-interface
     'Scalars
     (list
      (make-host-method 'int-result '(Bool) 'Int
                        (lambda (_state _value) 1))
      (make-host-method 'bool-result '(Int) 'Bool
                        (lambda (_state _value) #t))
      (make-host-method 'string-result '(String) 'String
                        (lambda (_state value) value)))))
  (define state (make-driver))
  (driver-inject-host!
   state 'scalars (make-host-receiver interface #f))
  (check-equal?
   (type->datum (driver-type-of state '(scalars int-result #t)))
   'Int)
  (check-equal?
   (type->datum (driver-type-of state '(scalars bool-result 1)))
   'Bool)
  (check-equal?
   (type->datum
    (driver-type-of state '(scalars string-result "value")))
   'String)
  (check-exn
   (static-error? #rx"int-result" #rx"Bool")
   (lambda () (driver-type-of state '(scalars int-result 1)))))

(test-case "whole-file checking prevents earlier host effects"
  (define reader-calls 0)
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state
   'term
   (make-term-receiver
    output
    (lambda ()
      (set! reader-calls (add1 reader-calls))
      "q")))
  (check-exn
   (static-error? #rx"write-line" #rx"String")
   (lambda ()
     (driver-load-port!
      state
      (open-input-string
       (string-append
        "(term read-key)\n"
        "(term write-line \"before\")\n"
        "(term write-line 1)\n"))
      (open-output-string))))
  (check-equal? reader-calls 0)
  (check-equal? (get-output-string output) ""))

(test-case "receivers sharing an interface share one inferred host type"
  (define interface (make-test-interface 'Shared))
  (define first (make-host-receiver interface 'first-state))
  (define second (make-host-receiver interface 'second-state))
  (define state (make-driver))
  (driver-inject-host! state 'first first)
  (driver-inject-host! state 'second second)
  (driver-eval! state '(define retain (fn (value) value)))
  (check-eq? (driver-eval! state '(retain call first)) first)
  (check-eq? (driver-eval! state '(retain call second)) second))

(test-case "same-name interfaces remain distinct checker types"
  (define first-interface (make-test-interface 'Twin))
  (define second-interface (make-test-interface 'Twin))
  (define first (make-host-receiver first-interface #f))
  (define second (make-host-receiver second-interface #f))
  (define state (make-driver))
  (driver-inject-host! state 'first first)
  (driver-inject-host! state 'second second)
  (driver-eval! state '(define retain (fn (value) value)))
  (check-eq? (driver-eval! state '(retain call first)) first)
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(retain call second)))))

(test-case "occupied injection preserves existing paired bindings"
  (define state (make-driver))
  (driver-eval! state '(define occupied 17))
  (define receiver (make-host-receiver (make-test-interface) #f))
  (check-exn
   (lambda (exception)
     (and (exn:fail:contract? exception)
          (regexp-match? #rx"binding-name" (exn-message exception))))
   (lambda () (driver-inject-host! state 'occupied receiver)))
  (check-equal?
   (env-lookup (driver-runtime-environment state) 'occupied)
   17)
  (check-equal?
   (type->datum (driver-type-of state 'occupied))
   'Int))

(test-case "runtime-side collision cannot create a checker binding"
  (define state (make-driver))
  (define receiver (make-host-receiver (make-test-interface) #f))
  (env-define! (driver-runtime-environment state) 'runtime-only 'sentinel)
  (check-false
   (type-environment-bound? (driver-type-environment state) 'runtime-only))
  (check-exn exn:fail:contract?
             (lambda ()
               (driver-inject-host! state 'runtime-only receiver)))
  (check-eq?
   (env-lookup (driver-runtime-environment state) 'runtime-only)
   'sentinel)
  (check-false
   (type-environment-bound? (driver-type-environment state) 'runtime-only)))

(test-case "checker-side collision cannot create a runtime binding"
  (define state (make-driver))
  (define receiver (make-host-receiver (make-test-interface) #f))
  (type-of
   (parse-datum '(define checker-only 23))
   (driver-type-environment state))
  (check-false
   (env-bound? (driver-runtime-environment state) 'checker-only))
  (check-exn exn:fail:contract?
             (lambda ()
               (driver-inject-host! state 'checker-only receiver)))
  (check-false
   (env-bound? (driver-runtime-environment state) 'checker-only))
  (check-equal?
   (type->datum (driver-type-of state 'checker-only))
   'Int))

(test-case "bad injection arguments make no driver changes"
  (define state (make-driver))
  (check-exn exn:fail:contract?
             (lambda ()
               (driver-inject-host! 'not-a-driver 'host 'not-a-receiver)))
  (check-exn exn:fail:contract?
             (lambda ()
               (driver-inject-host! state "host" 'not-a-receiver)))
  (check-exn exn:fail:contract?
             (lambda ()
               (driver-inject-host! state 'host 'not-a-receiver)))
  (check-false (env-bound? (driver-runtime-environment state) 'host))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'host)))

(test-case "default drivers remain capability-free"
  (define state (make-driver))
  (check-false (env-bound? (driver-runtime-environment state) 'term))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'term))
  (check-exn
   (static-error? #rx"unbound symbol" #rx"term")
   (lambda () (driver-eval! state 'term))))

(test-case "Term remains unavailable in source annotations"
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver (open-output-string) (lambda () "q")))
  (check-exn
   (static-error? #rx"unbound symbol" #rx"Term")
   (lambda ()
     (driver-eval!
      state
      '(define-class TermHolder
         (fields (value Term))
         (methods))))))

(test-case "the synthetic Term checker facade is gone"
  (check-exn
   exn:fail?
   (lambda () (dynamic-require term-path 'make-term-type-environment)))
  (check-false
   (regexp-match? #rx"HostTerm|make-term-type-environment"
                  (file->string term-path))))

(test-case "the raw nominal host checker type is not public"
  (check-exn
   exn:fail?
   (lambda () (dynamic-require type-path 'host-receiver-type))))
