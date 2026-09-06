#lang racket/base

(require racket/runtime-path
         rackunit
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt" eval-source make-top-level-env)
         "../aloe/parse.rkt"
         "../host/racket/term.rkt")

(define-runtime-path host-path "../aloe/host.rkt")

(define scalar-interface
  (make-host-interface
   'Scalars
   (list
    (make-host-method 'int '(Int) 'Int (lambda (_state value) value))
    (make-host-method 'bool '(Bool) 'Bool (lambda (_state value) value))
    (make-host-method
     'string '(String) 'String (lambda (_state value) value)))))

(define scalar-receiver (make-host-receiver scalar-interface 'opaque-state))

(define (boundary-error? interface-name selector position type)
  (lambda (exception)
    (define message (and (exn? exception) (exn-message exception)))
    (and (exn:fail? exception)
         (not (exn:fail:aloe-host? exception))
         (regexp-match? (regexp (regexp-quote (symbol->string interface-name)))
                        message)
         (regexp-match? (regexp (regexp-quote (symbol->string selector)))
                        message)
         (regexp-match? (regexp (regexp-quote position)) message)
         (regexp-match? (regexp (regexp-quote (symbol->string type)))
                        message))))

(test-case "host receiver construction requires and preserves an interface"
  (check-exn
   (lambda (exception)
     (and (exn:fail:contract? exception)
          (regexp-match? #rx"interface" (exn-message exception))))
   (lambda () (make-host-receiver 'Scalars 'state)))
  (check-true (host-receiver? scalar-receiver))
  (check-eq? (host-receiver-interface scalar-receiver) scalar-interface)
  (check-eq? (host-receiver-name scalar-receiver) 'Scalars))

(test-case "legacy receiver construction and message tables are not public"
  (for ([legacy-name
         (in-list
          '(host-message
            host-message?
            host-receiver
            host-receiver-state
            host-receiver-messages))])
    (check-exn exn:fail?
               (lambda () (dynamic-require host-path legacy-name)))))

(test-case "selector lookup and arity come from the interface"
  (check-equal? (host-receiver-send scalar-receiver 'int '(42)) 42)
  (check-exn #rx"unknown message: absent"
             (lambda ()
               (host-receiver-send scalar-receiver 'absent '())))
  (check-exn
   (lambda (exception)
     (and (exn:fail? exception)
          (not (exn:fail:aloe-host? exception))
          (regexp-match? #rx"arity error" (exn-message exception))
          (regexp-match? #rx"Scalars" (exn-message exception))
          (regexp-match? #rx"int" (exn-message exception))))
   (lambda () (host-receiver-send scalar-receiver 'int '()))))

(test-case "exact scalar crossings succeed"
  (check-equal? (host-receiver-send scalar-receiver 'int '(123)) 123)
  (check-eq? (host-receiver-send scalar-receiver 'bool '(#t)) #t)
  (define result
    (host-receiver-send scalar-receiver 'string '("aloe")))
  (check-equal? result "aloe")
  (check-true (immutable? result)))

(define wrong-scalar-arguments
  (list
   (list 'int 'Int #t)
   (list 'int 'Int "1")
   (list 'int 'Int 1.0)
   (list 'bool 'Bool 1)
   (list 'bool 'Bool "true")
   (list 'bool 'Bool 1.0)
   (list 'string 'String 1)
   (list 'string 'String #f)
   (list 'string 'String 1.0)))

(test-case "wrong scalar arguments fail at the generic boundary"
  (for ([entry (in-list wrong-scalar-arguments)])
    (define selector (car entry))
    (define type (cadr entry))
    (define value (caddr entry))
    (check-exn
     (boundary-error? 'Scalars selector "argument 1" type)
     (lambda ()
       (host-receiver-send scalar-receiver selector (list value))))))

(define wrong-scalar-results
  (list
   (list 'Int #t)
   (list 'Int "1")
   (list 'Int 1.0)
   (list 'Bool 1)
   (list 'Bool "true")
   (list 'Bool 1.0)
   (list 'String 1)
   (list 'String #f)
   (list 'String 1.0)))

(test-case "wrong scalar results fail at the generic boundary"
  (for ([entry (in-list wrong-scalar-results)])
    (define type (car entry))
    (define value (cadr entry))
    (define receiver
      (make-host-receiver
       (make-host-interface
        'BadResult
        (list
         (make-host-method
          'value '() type (lambda (_state) value))))
       #f))
    (check-exn
     (boundary-error? 'BadResult 'value "result" type)
     (lambda () (host-receiver-send receiver 'value '())))))

(test-case "non-crossing Aloe values fail in both directions"
  (define aloe-list (eval-source "(List of 1)"))
  (check-exn
   (boundary-error? 'Scalars 'int "argument 1" 'Int)
   (lambda () (host-receiver-send scalar-receiver 'int (list aloe-list))))
  (define receiver
    (make-host-receiver
     (make-host-interface
      'AloeResult
      (list
       (make-host-method 'value '() 'Int (lambda (_state) aloe-list))))
     #f))
  (check-exn
   (boundary-error? 'AloeResult 'value "result" 'Int)
   (lambda () (host-receiver-send receiver 'value '()))))

(test-case "argument validation completes before implementation effects"
  (define called? #f)
  (define output (open-output-string))
  (define receiver
    (make-host-receiver
     (make-host-interface
      'Effects
      (list
       (make-host-method
        'write
        '(String)
        'String
        (lambda (_state value)
          (set! called? #t)
          (display value output)
          value))))
     #f))
  (check-exn
   (boundary-error? 'Effects 'write "argument 1" 'String)
   (lambda () (host-receiver-send receiver 'write '(1))))
  (check-false called?)
  (check-equal? (get-output-string output) ""))

(test-case "mutable strings are copied at both boundary crossings"
  (define implementation-argument #f)
  (define mutable-result #f)
  (define receiver
    (make-host-receiver
     (make-host-interface
      'Strings
      (list
       (make-host-method
        'round-trip
        '(String)
        'String
        (lambda (_state value)
          (set! implementation-argument value)
          (set! mutable-result (string-copy value))
          mutable-result))))
     #f))
  (define mutable-input (string-copy "hello"))
  (check-false (immutable? mutable-input))
  (define result
    (host-receiver-send receiver 'round-trip (list mutable-input)))
  (check-true (immutable? implementation-argument))
  (check-false (eq? implementation-argument mutable-input))
  (check-false (immutable? mutable-result))
  (check-true (immutable? result))
  (check-false (eq? result mutable-result))
  (string-set! mutable-input 0 #\i)
  (string-set! mutable-result 0 #\j)
  (check-equal? implementation-argument "hello")
  (check-equal? result "hello"))

(test-case "implementation failures retain their original cause"
  (define original
    (exn:fail "device exploded" (current-continuation-marks)))
  (define receiver
    (make-host-receiver
     (make-host-interface
      'FailureHost
      (list
       (make-host-method 'explode '() 'Bool (lambda (_state) (raise original)))))
     #f))
  (define failure
    (with-handlers ([exn? values])
      (host-receiver-send receiver 'explode '())
      #f))
  (check-true (exn:fail:aloe-host? failure))
  (check-regexp-match #rx"FailureHost" (exn-message failure))
  (check-regexp-match #rx"explode" (exn-message failure))
  (check-regexp-match #rx"device exploded" (exn-message failure))
  (check-eq? (exn:fail:aloe-host-cause failure) original))

(test-case "breaks pass through without host-failure conversion"
  (define original
    (call-with-escape-continuation
     (lambda (escape)
       (exn:break "stop" (current-continuation-marks) escape))))
  (define receiver
    (make-host-receiver
     (make-host-interface
      'BreakHost
      (list
       (make-host-method 'stop '() 'Bool (lambda (_state) (raise original)))))
     #f))
  (define raised
    (with-handlers ([exn? values])
      (host-receiver-send receiver 'stop '())
      #f))
  (check-true (exn:break? raised))
  (check-false (exn:fail:aloe-host? raised))
  (check-eq? raised original))

(test-case "host receivers use identity equality and state-free output"
  (define receiver
    (make-host-receiver scalar-interface (string-copy "secret-state")))
  (define other
    (make-host-receiver scalar-interface (string-copy "secret-state")))
  (check-true (equal? receiver receiver))
  (check-false (equal? receiver other))
  (check-equal? (aloe-value->string receiver) "#<Scalars>")
  (check-false
   (regexp-match? #rx"secret-state" (aloe-value->string receiver)))
  (define environment (make-top-level-env))
  (env-define! environment 'receiver receiver)
  (env-define! environment 'alias receiver)
  (env-define! environment 'other other)
  (check-eq?
   (eval-expr (parse-datum '(check receiver alias)) environment)
   receiver)
  (check-exn #rx"check failed"
             (lambda ()
               (eval-expr
                (parse-datum '(check receiver other))
                environment))))

(test-case "Term exports one ordered production declaration"
  (define methods (host-interface-methods term-interface))
  (check-eq? (host-interface-name term-interface) 'Term)
  (check-equal? (map host-method-selector methods)
                '(read-key write-line))
  (check-equal? (map host-method-parameter-types methods)
                '(() (String)))
  (check-equal? (map host-method-return-type methods)
                '(String String))
  (define scripted
    (make-term-receiver (open-output-string) (lambda () "q")))
  (check-eq? (host-receiver-interface scripted) term-interface)
  (check-equal? (host-receiver-send scripted 'read-key '()) "q"))

(test-case "Term crossings are generic and precede output"
  (define output (open-output-string))
  (define term (make-term-receiver output (lambda () 1)))
  (check-exn
   (boundary-error? 'Term 'write-line "argument 1" 'String)
   (lambda () (host-receiver-send term 'write-line '(1))))
  (check-equal? (get-output-string output) "")
  (check-exn
   (boundary-error? 'Term 'read-key "result" 'String)
   (lambda () (host-receiver-send term 'read-key '()))))

(test-case "Term write-line preserves CRLF, flush, and return value"
  (define chunks (box '()))
  (define flushed? (box #f))
  (define output
    (make-output-port
     'tracked-output
     always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (cond
         [(= start end) (set-box! flushed? #t)]
         [else
          (set-box! chunks
                    (cons (subbytes bytes start end) (unbox chunks)))])
       (- end start))
     void))
  (define result
    (host-receiver-send
     (make-term-receiver output (lambda () "unused"))
     'write-line
     '("hi")))
  (check-equal? result "hi")
  (check-equal?
   (bytes->string/utf-8
    (apply bytes-append (reverse (unbox chunks))))
   "hi\r\n")
  (check-true (unbox flushed?)))
