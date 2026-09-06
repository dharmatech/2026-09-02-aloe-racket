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
         (struct-out host-message)
         (struct-out host-receiver)
         host-receiver-send)

;; Host declarations are opaque so an interface is a nominal identity rather
;; than a structural value. Their raw constructors remain private; the public
;; constructors below establish every declaration invariant.
(struct host-method
  (selector parameter-types return-type implementation))
(struct host-interface (name methods))

(define crossing-types '(Int Bool String))

(define (crossing-type? value)
  (and (memq value crossing-types) #t))

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

;; A host receiver is an explicitly injected Aloe value. Its messages use the
;; ordinary receiver/selector/arguments send shape, but their implementations
;; live in Racket. This module deliberately knows nothing about terminals.
(struct host-message (arity procedure) #:transparent)
(struct host-receiver (name messages state) #:transparent)

(define (host-receiver-send receiver selector arguments)
  (define message
    (hash-ref (host-receiver-messages receiver) selector #f))
  (unless message
    (error 'eval-aloe "unknown message: ~a" selector))
  (define expected (host-message-arity message))
  (define actual (length arguments))
  (unless (= expected actual)
    (error 'eval-aloe
           "arity error for ~a ~a: expected ~a argument(s), got ~a"
           (host-receiver-name receiver)
           selector
           expected
           actual))
  ((host-message-procedure message) receiver arguments))
