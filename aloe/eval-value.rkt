#lang racket/base

;; The evaluator's runtime values: the structs dispatch and reflection share,
;; the small helpers both call, the printer, and structural equality.
(require racket/string
         "env.rkt"
         "host.rkt"
         "mirror.rkt"
         "signature.rkt"
         "symbol.rkt")

(provide (struct-out class-value)
         (struct-out instance-value)
         (struct-out function-value)
         (struct-out list-value)
         (struct-out runtime-class-type)
         (struct-out runtime-list-type)
         (struct-out protocol-value)
         class-value-protocol-name
         string-class-for
         int-class-for
         option-class-for
         arity-error
         unknown-message
         aloe-value->string
         aloe-values-equal?)

(struct class-value
  (name type-parameters protocol fields constructors explicit-constructors?
        [methods #:mutable]
        environment
        method-environments)
  #:transparent)
(struct instance-value (class type-arguments constructor field-values)
  #:transparent)
(struct function-value (parameters body environment) #:transparent)
(struct list-value (class element-type elements) #:transparent)
(struct runtime-class-type (class type-arguments) #:transparent)
(struct runtime-list-type (element-type) #:transparent)
;; A protocol's runtime record. Identity is the record; the name serves the
;; comparisons that still match short names. It records the environment that
;; wrote it.
(struct protocol-value (name environment))

;; The short name of a class's protocol, or #f for a class without one.
(define (class-value-protocol-name class)
  (define protocol (class-value-protocol class))
  (and protocol (protocol-value-name protocol)))

(define (string-class-for environment)
  (and environment (env-string-class environment)))

(define (int-class-for environment)
  (and environment (env-int-class environment)))

(define (option-class-for environment)
  (and environment (env-option-class environment)))

(define (arity-error target expected actual)
  (error 'eval-aloe
         "arity error for ~a: expected ~a argument(s), got ~a"
         target
         expected
         actual))

(define (unknown-message selector)
  (error 'eval-aloe "unknown message: ~a" selector))

(define (aloe-value->string value)
  (cond
    [(boolean? value) (if value "#t" "#f")]
    [(number? value) (number->string value)]
    [(string? value) (format "~s" value)]
    [(symbol-value? value)
     (format "#<Symbol ~a>" (symbol-value-name value))]
    [(string-class-object? value) "#<class String>"]
    [(int-class-object? value) "#<class Int>"]
    [(symbol-class-object? value) "#<class Symbol>"]
    [(mirror-class-object? value) "#<class Mirror>"]
    [(mirror-value? value) "#<Mirror>"]
    [(signature-value? value)
     (format "#<Signature ~a>"
             (symbol-value-name (signature-value-selector value)))]
    [(class-value? value)
     (format "#<class ~a>" (class-value-name value))]
    [(and (instance-value? value)
          (eq? (class-value-name (instance-value-class value)) 'Sum))
     (define fields (instance-value-field-values value))
     (format "#<Sum terms=~a const=~a>"
             (aloe-value->string (vector-ref fields 0))
             (aloe-value->string (vector-ref fields 1)))]
    [(and (instance-value? value)
          (eq? (class-value-name (instance-value-class value)) 'Prod))
     (define fields (instance-value-field-values value))
     (format "#<Prod coeff=~a factors=~a>"
             (aloe-value->string (vector-ref fields 0))
             (aloe-value->string (vector-ref fields 1)))]
    [(instance-value? value)
     (define fields
       (for/list ([field-value
                   (in-vector (instance-value-field-values value))])
         (aloe-value->string field-value)))
     (format "#<~a~a>"
             (class-value-name (instance-value-class value))
             (if (null? fields)
                 ""
                 (string-append " " (string-join fields " "))))]
    [(function-value? value)
     (format "#<fn/~a>" (length (function-value-parameters value)))]
    [(list-value? value)
     (define elements (list-value-elements value))
     (define count (vector-length elements))
     (define shown
       (for/list ([element (in-vector elements)]
                  [index (in-range 8)])
         (aloe-value->string element)))
     (define parts
       (if (> count 8) (append shown '("...")) shown))
     (format "#<List~a>"
             (if (null? parts)
                 ""
                 (string-append " " (string-join parts " "))))]
    [(host-receiver? value)
     (format "#<~a>" (host-receiver-name value))]
    [(list-class-object? value) "#<class List>"]
    [(void? value) "#<void>"]
    [else "#<object>"]))

(define (value-vectors-equal? left right)
  (and (= (vector-length left) (vector-length right))
       (for/and ([left-value (in-vector left)]
                 [right-value (in-vector right)])
         (aloe-values-equal? left-value right-value))))

(define (aloe-values-equal? left right)
  (cond
    [(and (exact-integer? left) (exact-integer? right)) (= left right)]
    [(and (flonum? left) (flonum? right)) (= left right)]
    [(and (boolean? left) (boolean? right)) (eq? left right)]
    [(and (string? left) (string? right)) (string=? left right)]
    [(and (instance-value? left) (instance-value? right))
     (and (eq? (instance-value-class left) (instance-value-class right))
          (eq? (instance-value-constructor left)
               (instance-value-constructor right))
          (value-vectors-equal? (instance-value-field-values left)
                                (instance-value-field-values right)))]
    [(and (list-value? left) (list-value? right))
     (and (eq? (list-value-class left) (list-value-class right))
          (value-vectors-equal? (list-value-elements left)
                                (list-value-elements right)))]
    [(and (host-receiver? left) (host-receiver? right))
     (eq? left right)]
    [(and (void? left) (void? right)) #t]
    [else (eq? left right)]))
