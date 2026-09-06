#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/host.rkt"
         (only-in (submod "../aloe/host.rkt" evaluator-exact-host-method)
                  host-receiver-invoke-method)
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/term.rkt")

(define-runtime-path host-path "../aloe/host.rkt")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(test-case "Term reflects its exact ordered descriptor without effects"
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
  (driver-eval! state '(define term-mirror (Mirror of term)))
  (driver-eval! state '(define term-rows (term-mirror signatures)))

  (check-equal? (driver-type-datum state '(Mirror of term)) 'Mirror)
  (check-equal?
   (driver-type-datum state '(term-mirror messages))
   '(List Symbol))
  (check-equal?
   (driver-type-datum state '(term-mirror signatures))
   '(List Signature))

  (check-equal? (driver-eval! state '((term-mirror messages) len)) 2)
  (check-equal?
   (driver-eval! state '(((term-mirror messages) first) name))
   "read-key")
  (check-equal?
   (driver-eval! state '((((term-mirror messages) rest) first) name))
   "write-line")
  (check-equal? (driver-eval! state '(term-rows len)) 2)
  (check-equal?
   (driver-eval! state '(((term-rows first) selector) name))
   "read-key")
  (check-equal?
   (driver-eval!
    state
    '((((term-rows rest) first) selector) name))
   "write-line")
  (check-equal?
   (driver-eval! state '(((term-rows first) params) len))
   0)
  (check-equal?
   (aloe-value->string
    (driver-eval! state '((term-rows first) return)))
   "#<Symbol String>")
  (check-equal?
   (aloe-value->string
    (driver-eval!
     state
     '((((term-rows rest) first) params) first)))
   "#<Symbol String>")
  (check-equal?
   (aloe-value->string
    (driver-eval!
     state
     '(((term-rows rest) first) return)))
   "#<Symbol String>")
  (check-equal? reader-calls 0)
  (check-equal? (get-output-string output) ""))

(test-case "all scalar declaration tokens reify from one interface"
  (define implementation-calls 0)
  (define interface
    (make-host-interface
     'ScalarVocabulary
     (list
      (make-host-method
       'all-parameters
       '(Int Bool String)
       'String
       (lambda (_state _integer _boolean text)
         (set! implementation-calls (add1 implementation-calls))
         text))
      (make-host-method
       'integer '() 'Int
       (lambda (_state)
         (set! implementation-calls (add1 implementation-calls))
         1))
      (make-host-method
       'boolean '() 'Bool
       (lambda (_state)
         (set! implementation-calls (add1 implementation-calls))
         #t)))))
  (define state (make-driver))
  (driver-inject-host!
   state 'scalars (make-host-receiver interface #f))
  (driver-eval! state '(define scalar-rows ((Mirror of scalars) signatures)))
  (driver-eval! state '(define all-row (scalar-rows first)))
  (driver-eval! state '(define int-row ((scalar-rows rest) first)))
  (driver-eval!
   state
   '(define bool-row (((scalar-rows rest) rest) first)))
  (check-equal? (driver-eval! state '((all-row params) len)) 3)
  (check-equal?
   (aloe-value->string
    (driver-eval! state '((all-row params) first)))
   "#<Symbol Int>")
  (check-equal?
   (aloe-value->string
    (driver-eval! state '(((all-row params) rest) first)))
   "#<Symbol Bool>")
  (check-equal?
   (aloe-value->string
    (driver-eval!
     state
     '((((all-row params) rest) rest) first)))
   "#<Symbol String>")
  (check-equal?
   (aloe-value->string (driver-eval! state '(all-row return)))
   "#<Symbol String>")
  (check-equal?
   (aloe-value->string (driver-eval! state '(int-row return)))
   "#<Symbol Int>")
  (check-equal?
   (aloe-value->string (driver-eval! state '(bool-row return)))
   "#<Symbol Bool>")
  (check-equal? implementation-calls 0))

(test-case "reflected Term invocation preserves direct behavior"
  (define remaining-keys (box '("direct" "reflected")))
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state
   'term
   (make-term-receiver
    output
    (lambda ()
      (define keys (unbox remaining-keys))
      (set-box! remaining-keys (cdr keys))
      (car keys))))
  (check-equal? (driver-eval! state '(term read-key)) "direct")
  (check-equal? (driver-eval! state '(term write-line "one")) "one")
  (driver-eval! state '(define tm (Mirror of term)))
  (driver-eval! state '(define rows (tm signatures)))
  (driver-eval! state '(define read-row (rows first)))
  (driver-eval! state '(define write-row ((rows rest) first)))
  (check-equal? (driver-eval! state '(tm invoke read-row)) "reflected")
  (check-equal?
   (driver-eval! state '(tm invoke write-row "two"))
   "two")
  (check-equal? (get-output-string output) "one\r\ntwo\r\n"))

(test-case "Mirror checks reflected arguments before host effects"
  (define implementation-calls 0)
  (define output (open-output-string))
  (define interface
    (make-host-interface
     'Effects
     (list
      (make-host-method
       'write '(String) 'String
       (lambda (_state text)
         (set! implementation-calls (add1 implementation-calls))
         (display text output)
         text)))))
  (define state (make-driver))
  (driver-inject-host! state 'effects (make-host-receiver interface #f))
  (driver-eval! state '(define effects-mirror (Mirror of effects)))
  (driver-eval!
   state
   '(define effects-row ((effects-mirror signatures) first)))
  (check-exn
   #rx"arity error"
   (lambda ()
     (driver-eval! state '(effects-mirror invoke effects-row))))
  (check-exn
   #rx"argument 1 does not match String"
   (lambda ()
     (driver-eval! state '(effects-mirror invoke effects-row 1))))
  (check-equal? implementation-calls 0)
  (check-equal? (get-output-string output) ""))

(test-case "reflected results retain host crossing validation"
  (define implementation-calls 0)
  (define interface
    (make-host-interface
     'BadResult
     (list
      (make-host-method
       'value '() 'String
       (lambda (_state)
         (set! implementation-calls (add1 implementation-calls))
         1)))))
  (define state (make-driver))
  (driver-inject-host! state 'bad (make-host-receiver interface #f))
  (driver-eval! state '(define bad-mirror (Mirror of bad)))
  (driver-eval! state '(define bad-row ((bad-mirror signatures) first)))
  (check-exn
   (lambda (exception)
     (and (exn:fail? exception)
          (not (exn:fail:aloe-host? exception))
          (regexp-match? #rx"BadResult" (exn-message exception))
          (regexp-match? #rx"value" (exn-message exception))
          (regexp-match? #rx"result" (exn-message exception))
          (regexp-match? #rx"String" (exn-message exception))))
   (lambda () (driver-eval! state '(bad-mirror invoke bad-row))))
  (check-equal? implementation-calls 1))

(test-case "reflected implementation failures retain their cause"
  (define original
    (exn:fail "device exploded" (current-continuation-marks)))
  (define interface
    (make-host-interface
     'FailureHost
     (list
      (make-host-method
       'explode '() 'Bool (lambda (_state) (raise original))))))
  (define state (make-driver))
  (driver-inject-host! state 'failure (make-host-receiver interface #f))
  (driver-eval! state '(define failure-mirror (Mirror of failure)))
  (driver-eval!
   state
   '(define failure-row ((failure-mirror signatures) first)))
  (define raised
    (with-handlers ([exn? values])
      (driver-eval! state '(failure-mirror invoke failure-row))
      #f))
  (check-true (exn:fail:aloe-host? raised))
  (check-regexp-match #rx"FailureHost" (exn-message raised))
  (check-regexp-match #rx"explode" (exn-message raised))
  (check-eq? (exn:fail:aloe-host-cause raised) original))

(test-case "breaks pass through reflected host invocation"
  (define original
    (call-with-escape-continuation
     (lambda (escape)
       (exn:break "stop" (current-continuation-marks) escape))))
  (define interface
    (make-host-interface
     'BreakHost
     (list
      (make-host-method
       'stop '() 'Bool (lambda (_state) (raise original))))))
  (define state (make-driver))
  (driver-inject-host! state 'breaker (make-host-receiver interface #f))
  (driver-eval! state '(define break-mirror (Mirror of breaker)))
  (driver-eval!
   state
   '(define break-row ((break-mirror signatures) first)))
  (define raised
    (with-handlers ([exn? values])
      (driver-eval! state '(break-mirror invoke break-row))
      #f))
  (check-true (exn:break? raised))
  (check-false (exn:fail:aloe-host? raised))
  (check-eq? raised original))

(test-case "host signature ownership follows exact interface identity"
  (define target-states (box '()))
  (define method
    (make-host-method
     'state '() 'String
     (lambda (receiver-state)
       (set-box! target-states
                 (cons receiver-state (unbox target-states)))
       receiver-state)))
  (define interface (make-host-interface 'StateHost (list method)))
  (define first (make-host-receiver interface "first"))
  (define second (make-host-receiver interface "second"))
  (define state (make-driver))
  (driver-inject-host! state 'first-host first)
  (driver-inject-host! state 'second-host second)
  (driver-eval! state '(define first-mirror (Mirror of first-host)))
  (driver-eval! state '(define second-mirror (Mirror of second-host)))
  (driver-eval!
   state
   '(define state-row ((first-mirror signatures) first)))
  (check-equal?
   (driver-eval! state '(second-mirror invoke state-row))
   "second")
  (check-equal? (unbox target-states) '("second")))

(test-case "same-name interface signatures remain nominal"
  (define first-calls 0)
  (define second-calls 0)
  (define first-interface
    (make-host-interface
     'Twin
     (list
      (make-host-method
       'touch '() 'String
       (lambda (_state)
         (set! first-calls (add1 first-calls))
         "first")))))
  (define second-interface
    (make-host-interface
     'Twin
     (list
      (make-host-method
       'touch '() 'String
       (lambda (_state)
         (set! second-calls (add1 second-calls))
         "second")))))
  (define state (make-driver))
  (driver-inject-host!
   state 'first-twin (make-host-receiver first-interface #f))
  (driver-inject-host!
   state 'second-twin (make-host-receiver second-interface #f))
  (driver-eval! state '(define first-twin-mirror (Mirror of first-twin)))
  (driver-eval! state '(define second-twin-mirror (Mirror of second-twin)))
  (driver-eval!
   state
   '(define twin-row ((first-twin-mirror signatures) first)))
  (check-exn
   #rx"does not belong to the subject type"
   (lambda ()
     (driver-eval! state '(second-twin-mirror invoke twin-row))))
  (check-equal? first-calls 0)
  (check-equal? second-calls 0))

(test-case "host and ordinary signatures cannot cross owners"
  (define host-calls 0)
  (define interface
    (make-host-interface
     'NumberHost
     (list
      (make-host-method
       'identity '(Int) 'Int
       (lambda (_state value)
         (set! host-calls (add1 host-calls))
         value)))))
  (define state (make-driver))
  (driver-inject-host! state 'number-host
                       (make-host-receiver interface #f))
  (driver-eval! state '(define host-mirror (Mirror of number-host)))
  (driver-eval!
   state
   '(define host-row ((host-mirror signatures) first)))
  (driver-eval!
   state
   '(define ordinary-row (((Mirror of 1) signatures) first)))
  (check-exn
   #rx"does not belong to the subject type"
   (lambda ()
     (driver-eval! state '(host-mirror invoke ordinary-row 1))))
  (check-exn
   #rx"does not belong to the subject type"
   (lambda ()
     (driver-eval! state '((Mirror of 1) invoke host-row 1))))
  (check-equal? host-calls 0))

(test-case "the exact-method seam rejects unrelated validated methods"
  (define permitted-calls 0)
  (define alien-calls 0)
  (define permitted
    (make-host-method
     'permitted '() 'String
     (lambda (_state)
       (set! permitted-calls (add1 permitted-calls))
       "permitted")))
  (define alien
    (make-host-method
     'alien '() 'String
     (lambda (_state)
       (set! alien-calls (add1 alien-calls))
       "alien")))
  (define receiver
    (make-host-receiver
     (make-host-interface 'ExactHost (list permitted))
     #f))
  (check-exn
   exn:fail:contract?
   (lambda () (host-receiver-invoke-method receiver alien '())))
  (check-equal? permitted-calls 0)
  (check-equal? alien-calls 0)
  (check-exn
   exn:fail?
   (lambda ()
     (dynamic-require host-path 'host-receiver-invoke-method))))

(test-case "host subject and raw reflection reveal no state"
  (define interface
    (make-host-interface
     'SecretHost
     (list
      (make-host-method 'ping '() 'String (lambda (_state) "pong")))))
  (define receiver
    (make-host-receiver interface "do-not-expose-this-state"))
  (define state (make-driver))
  (driver-inject-host! state 'secret receiver)
  (driver-eval! state '(define secret-mirror (Mirror of secret)))
  (check-eq? (driver-eval! state '(secret-mirror subject)) receiver)
  (check-equal? (driver-eval! state '(secret-mirror raw)) "#<SecretHost>")
  (check-equal? (driver-eval! state '((secret-mirror messages) len)) 1)
  (check-equal?
   (driver-eval! state '(((secret-mirror messages) first) name))
   "ping")
  (check-false
   (regexp-match?
    #rx"do-not-expose-this-state"
    (driver-eval! state '(secret-mirror raw)))))

(test-case "default drivers remain free of Term"
  (define state (make-driver))
  (check-false
   (env-bound? (driver-runtime-environment state) 'term))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'term)))
