#lang racket/base

(require rackunit
         "../aloe/host.rkt")

(define implementation-called? #f)

(define read-key-method
  (make-host-method
   'read-key
   '()
   'String
   (lambda (_state)
     (set! implementation-called? #t)
     "x")))

(define write-line-implementation
  (lambda (_state value) value))

(define write-line-method
  (make-host-method
   'write-line
   '(String)
   'String
   write-line-implementation))

(define term-methods (list read-key-method write-line-method))
(define term-interface (make-host-interface 'Term term-methods))

;; A valid Term-shaped declaration retains every field and its source order.
(check-true (host-method? read-key-method))
(check-eq? (host-method-selector read-key-method) 'read-key)
(check-equal? (host-method-parameter-types read-key-method) '())
(check-eq? (host-method-return-type read-key-method) 'String)
(check-eq? (host-method-implementation write-line-method)
           write-line-implementation)
(check-true (host-interface? term-interface))
(check-eq? (host-interface-name term-interface) 'Term)
(check-equal?
 (map host-method-selector (host-interface-methods term-interface))
 '(read-key write-line))
(check-eq? (host-interface-methods term-interface) term-methods)

;; Construction validates procedures without invoking them.
(check-false implementation-called?)

;; Interface equality is nominal, even for equal declaration contents.
(define another-term-interface
  (make-host-interface 'Term term-methods))
(check-false (eq? term-interface another-term-interface))
(check-false (equal? term-interface another-term-interface))

(define (check-contract-error field-pattern thunk)
  (check-exn
   (lambda (exception)
     (and (exn:fail:contract? exception)
          (regexp-match? field-pattern (exn-message exception))))
   thunk))

(check-contract-error
 #rx"selector"
 (lambda ()
   (make-host-method "read-key" '() 'String (lambda (_state) "x"))))

(check-contract-error
 #rx"parameter-types"
 (lambda ()
   (make-host-method
    'read-key
    (cons 'String 'Bool)
    'String
    (lambda (_state _value) "x"))))

;; Each category outside the closed crossing vocabulary is
;; rejected in both parameter and return positions.
(define unsupported-types
  '(Float
    Symbol
    Mirror
    Signature
    List
    (List Int)
    (List Entry)
    (List (List String))
    (-> String String)
    T
    Point
    Term
    arbitrary-type
    42))

(for ([unsupported-type (in-list unsupported-types)])
  (check-contract-error
   #rx"parameter-types"
   (lambda ()
     (make-host-method
      'bad-parameter
      (list unsupported-type)
      'String
      (lambda (_state _value) "x"))))
  (check-contract-error
   #rx"return-type"
   (lambda ()
     (make-host-method
      'bad-return
      '()
      unsupported-type
      (lambda (_state) "x")))))

;; All three crossing types are admitted in a single declaration.
(check-true
 (host-method?
  (make-host-method
   'scalars
   '(Int Bool String)
   'Bool
   (lambda (_state _integer _boolean _string) #t))))

;; The one admitted compound crossing type is valid in either position.
(check-true
 (host-method?
  (make-host-method
   'names
   '(String)
   '(List String)
   (lambda (_state _path) '()))))
(check-true
 (host-method?
  (make-host-method
   'count
   '((List String))
   'Int
   (lambda (_state names) (length names)))))

(check-contract-error
 #rx"implementation"
 (lambda ()
   (make-host-method 'read-key '() 'String 'not-a-procedure)))

;; One declared parameter requires exactly state plus one value argument.
(for ([bad-implementation
       (in-list
        (list
         (lambda (_state) "too few")
         (lambda (_state _value _extra) "too many")
         (lambda (_state [_value "optional"]) "optional")
         (lambda (_state . _values) "variadic")
         (lambda (_state _value #:required _keyword) "required keyword")
         (lambda (_state _value #:optional [_keyword #f])
           "optional keyword")))])
  (check-contract-error
   #rx"implementation"
   (lambda ()
     (make-host-method
      'write-line '(String) 'String bad-implementation))))

(check-contract-error
 #rx"name"
 (lambda ()
   (make-host-interface "Term" term-methods)))

(check-contract-error
 #rx"methods"
 (lambda ()
   (make-host-interface 'Term (cons read-key-method write-line-method))))

(check-contract-error
 #rx"methods"
 (lambda ()
   (make-host-interface 'Term (list read-key-method 'not-a-method))))

(define duplicate-read-key-method
  (make-host-method 'read-key '() 'String (lambda (_state) "y")))

(check-contract-error
 #rx"duplicate selector"
 (lambda ()
   (make-host-interface
    'Term
    (list read-key-method duplicate-read-key-method))))
