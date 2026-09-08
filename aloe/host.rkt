#lang racket/base

(provide make-host-method
         host-method?
         host-method-selector
         host-method-parameter-types
         host-method-return-type
         host-method-implementation
         make-host-interface
         host-interface?
         host-interface-name
         host-interface-methods
         make-host-receiver
         host-receiver?
         host-receiver-interface
         host-receiver-name
         exn:fail:aloe-host?
         exn:fail:aloe-host-cause
         host-receiver-send)

;; Host declarations are opaque so an interface is a nominal identity rather
;; than a structural value. Their raw constructors remain private; the public
;; constructors below establish every declaration invariant.
(struct host-method
  (selector parameter-types return-type implementation))
(struct host-interface (name methods))

(define crossing-types '(Int Bool String (List String)))

(define (crossing-type? value)
  (and (member value crossing-types equal?) #t))

(define (make-host-method selector
                          parameter-types
                          return-type
                          implementation)
  (unless (symbol? selector)
    (raise-arguments-error
     'make-host-method
     "selector must be a symbol"
     "selector" selector))
  (unless (list? parameter-types)
    (raise-arguments-error
     'make-host-method
     "parameter-types must be a proper list"
     "parameter-types" parameter-types))
  (for ([parameter-type (in-list parameter-types)])
    (unless (crossing-type? parameter-type)
      (raise-arguments-error
       'make-host-method
       "parameter-types contains an unsupported crossing type"
       "parameter-types" parameter-types
       "unsupported type" parameter-type
       "permitted types" crossing-types)))
  (unless (crossing-type? return-type)
    (raise-arguments-error
     'make-host-method
     "return-type is not a permitted crossing type"
     "return-type" return-type
     "permitted types" crossing-types))
  (unless (procedure? implementation)
    (raise-arguments-error
     'make-host-method
     "implementation must be a procedure"
     "implementation" implementation))
  (define required-arity (add1 (length parameter-types)))
  (define-values (required-keywords allowed-keywords)
    (procedure-keywords implementation))
  (unless (and (equal? (procedure-arity implementation) required-arity)
               (null? required-keywords)
               (null? allowed-keywords))
    (raise-arguments-error
     'make-host-method
     (string-append
      "implementation must accept exactly one state argument followed by "
      "one positional argument per declared parameter, with no other "
      "arities or keyword arguments")
     "implementation" implementation
     "required positional arity" required-arity
     "accepted positional arity" (procedure-arity implementation)
     "required keywords" required-keywords
     "allowed keywords" allowed-keywords))
  (host-method selector parameter-types return-type implementation))

(define (make-host-interface name methods)
  (unless (symbol? name)
    (raise-arguments-error
     'make-host-interface
     "name must be a symbol"
     "name" name))
  (unless (list? methods)
    (raise-arguments-error
     'make-host-interface
     "methods must be a proper list"
     "methods" methods))
  (for ([method (in-list methods)])
    (unless (host-method? method)
      (raise-arguments-error
       'make-host-interface
       "methods contains a value that is not a validated host method"
       "methods" methods
       "non-method value" method)))
  (define duplicate-selector
    (for/fold ([seen (hasheq)]
               [duplicate #f]
               #:result duplicate)
              ([method (in-list methods)]
               #:break duplicate)
      (define selector (host-method-selector method))
      (values (hash-set seen selector #t)
              (and (hash-has-key? seen selector) selector))))
  (when duplicate-selector
    (raise-arguments-error
     'make-host-interface
     "methods must have unique selectors"
     "methods" methods
     "duplicate selector" duplicate-selector))
  (host-interface name methods))

;; A host receiver is an explicitly injected Aloe value whose opaque state is
;; available only to the implementation selected through its interface.
(struct host-receiver (interface state))

(define (make-host-receiver interface state)
  (unless (host-interface? interface)
    (raise-arguments-error
     'make-host-receiver
     "interface must be a validated host interface"
     "interface" interface))
  (host-receiver interface state))

(define (host-receiver-name receiver)
  (host-interface-name (host-receiver-interface receiver)))

;; Host implementations are foreign code. Keep their original failure
;; available while presenting one stable Aloe runtime failure at the boundary.
(struct exn:fail:aloe-host exn:fail (cause))

(define (find-host-method interface selector)
  (for/first ([method (in-list (host-interface-methods interface))]
              #:when (eq? selector (host-method-selector method)))
    method))

(define (normalize-crossing-value receiver selector position type value)
  (define valid?
    (cond
      [(eq? type 'Int) (exact-integer? value)]
      [(eq? type 'Bool) (boolean? value)]
      [(eq? type 'String) (string? value)]
      [(equal? type '(List String))
       (and (list? value) (andmap string? value))]
      [else #f]))
  (unless valid?
    (error 'eval-aloe
           "host crossing error for ~a ~a ~a: expected ~a"
           (host-receiver-name receiver)
           selector
           position
           type))
  (cond
    [(eq? type 'String) (string->immutable-string value)]
    [(equal? type '(List String))
     (for/list ([element (in-list value)])
       (string->immutable-string element))]
    [else value]))

(define (call-host-implementation receiver method arguments)
  (with-handlers
      ([exn:fail?
        (lambda (cause)
          (raise
           (exn:fail:aloe-host
            (format "eval-aloe: host failure for ~a ~a: ~a"
                    (host-receiver-name receiver)
                    (host-method-selector method)
                    (exn-message cause))
            (exn-continuation-marks cause)
            cause)))])
    (apply (host-method-implementation method)
           (host-receiver-state receiver)
           arguments)))

(define (host-receiver-invoke-method receiver method arguments)
  (unless (host-receiver? receiver)
    (raise-arguments-error
     'host-receiver-invoke-method
     "receiver must be a validated host receiver"
     "receiver" receiver))
  (unless (and (host-method? method)
               (memq method
                     (host-interface-methods
                      (host-receiver-interface receiver))))
    (raise-arguments-error
     'host-receiver-invoke-method
     "method must belong to the receiver's exact host interface"
     "receiver" receiver
     "method" method))
  (define selector (host-method-selector method))
  (define parameter-types (host-method-parameter-types method))
  (define expected (length parameter-types))
  (define actual (length arguments))
  (unless (= expected actual)
    (error 'eval-aloe
           "arity error for ~a ~a: expected ~a argument(s), got ~a"
           (host-receiver-name receiver)
           selector
           expected
           actual))
  (define normalized-arguments
    (for/list ([argument (in-list arguments)]
               [type (in-list parameter-types)]
               [index (in-naturals 1)])
      (normalize-crossing-value
       receiver selector (format "argument ~a" index) type argument)))
  (define result
    (call-host-implementation receiver method normalized-arguments))
  (normalize-crossing-value
   receiver selector "result" (host-method-return-type method) result))

(define (host-receiver-send receiver selector arguments)
  (define method
    (find-host-method (host-receiver-interface receiver) selector))
  (unless method
    (error 'eval-aloe "unknown message: ~a" selector))
  (host-receiver-invoke-method receiver method arguments))

;; Reflection already owns an exact validated row. Keep this evaluator-facing
;; seam out of the public host declaration API while sharing all guards with
;; ordinary host sends.
(module* evaluator-exact-host-method #f
  (provide host-receiver-invoke-method))
