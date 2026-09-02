#lang racket/base

(require racket/match
         racket/string
         "env.rkt"
         "parse.rkt")

(provide eval-expr
         eval-exprs
         aloe-value->string)

(struct class-value (name type-parameters fields methods environment) #:transparent)
(struct instance-value (class type-arguments field-values) #:transparent)
(struct function-value (parameters body environment) #:transparent)
(struct list-value (element-type elements) #:transparent)
(struct runtime-class-type (class type-arguments) #:transparent)
(struct runtime-list-type (element-type) #:transparent)

(define (eval-expr expression environment)
  (match expression
    [(int-expr value) value]
    [(float-expr value) value]
    [(bool-expr value) value]
    [(variable-expr name)
     (env-lookup environment name)]
    [(define-expr name value-expression)
     (define value (eval-expr value-expression environment))
     (env-define! environment name value)]
    [(define-class-expr name type-parameters fields methods)
     (env-define! environment
                  name
                  (class-value
                   name type-parameters fields methods environment))]
    [(fn-expr parameters body)
     (function-value parameters body environment)]
    [(send-expr receiver-expression selector argument-expressions)
     (define receiver (eval-expr receiver-expression environment))
     (define arguments
       (for/list ([argument-expression (in-list argument-expressions)])
         (eval-expr argument-expression environment)))
     (lookup-message receiver selector arguments)]))

(define (lookup-message receiver selector arguments)
  (cond
    [(list-class-object? receiver)
     (send-to-list-class selector arguments)]
    [(class-value? receiver)
     (if (eq? selector 'new)
         (construct-instance receiver arguments)
         (unknown-message selector))]
    [(instance-value? receiver)
     (send-to-instance receiver selector arguments)]
    [(function-value? receiver)
     (send-to-function receiver selector arguments)]
    [(list-value? receiver)
     (send-to-list receiver selector arguments)]
    [(exact-integer? receiver)
     (send-to-int receiver selector arguments)]
    [(flonum? receiver)
     (send-to-float receiver selector arguments)]
    [(boolean? receiver)
     (send-to-bool receiver selector arguments)]
    [else
     (unknown-message selector)]))

(define (send-to-list-class selector arguments)
  (case selector
    [(of) (make-list-value arguments)]
    [(empty)
     (unless (null? arguments)
       (arity-error "List empty" 0 (length arguments)))
     (make-list-value '())]
    [else (unknown-message selector)]))

(define (make-list-value elements)
  (define element-type
    (and (pair? elements) (runtime-type-of (car elements))))
  (when element-type
    (for ([element (in-list (cdr elements))])
      (unless (same-runtime-type? element-type (runtime-type-of element))
        (error 'eval-aloe "List of elements must have one type"))))
  (list-value element-type (apply vector-immutable elements)))

(define (construct-instance class arguments)
  (define expected-arity (length (class-value-fields class)))
  (define actual-arity (length arguments))
  (unless (= expected-arity actual-arity)
    (error 'eval-aloe
           "arity error for new: expected ~a argument(s), got ~a"
           expected-arity
           actual-arity))
  (instance-value class
                  (infer-class-type-arguments class arguments)
                  (apply vector-immutable arguments)))

(define (infer-class-type-arguments class arguments)
  (define inferred (make-hasheq))
  (for ([field (in-list (class-value-fields class))]
        [argument (in-list arguments)])
    (infer-type-expression! class
                            (field-declaration-type field)
                            (runtime-type-of argument)
                            inferred))
  (for ([parameter (in-list (class-value-type-parameters class))])
    (unless (hash-has-key? inferred parameter)
      (error 'eval-aloe
             "cannot infer type parameter ~a for ~a"
             parameter
             (class-value-name class))))
  (apply vector-immutable
         (for/list ([parameter
                     (in-list (class-value-type-parameters class))])
           (hash-ref inferred parameter))))

(define (infer-type-expression! class declared-type actual-type inferred)
  (cond
    [(and (symbol? declared-type)
          (memq declared-type (class-value-type-parameters class)))
     (bind-inferred-type! declared-type actual-type inferred)]
    [(and (list? declared-type)
          (pair? declared-type)
          (eq? (car declared-type) 'List)
          (= (length declared-type) 2)
          (runtime-list-type? actual-type)
          (runtime-list-type-element-type actual-type))
     (infer-type-expression!
      class
      (cadr declared-type)
      (runtime-list-type-element-type actual-type)
      inferred)]
    [(and (list? declared-type)
          (pair? declared-type)
          (runtime-class-type? actual-type)
          (eq? (car declared-type)
               (class-value-name (runtime-class-type-class actual-type)))
          (= (length (cdr declared-type))
             (vector-length
              (runtime-class-type-type-arguments actual-type))))
     (for ([nested-type (in-list (cdr declared-type))]
           [nested-actual
            (in-vector (runtime-class-type-type-arguments actual-type))])
       (infer-type-expression! class nested-type nested-actual inferred))]))

(define (bind-inferred-type! parameter actual-type inferred)
  (cond
    [(hash-has-key? inferred parameter)
     (unless (same-runtime-type? (hash-ref inferred parameter) actual-type)
       (error 'eval-aloe
              "inconsistent type parameter ~a"
              parameter))]
    [else
     (hash-set! inferred parameter actual-type)]))

(define (runtime-type-of value)
  (cond
    [(exact-integer? value) 'Int]
    [(flonum? value) 'Float]
    [(boolean? value) 'Bool]
    [(instance-value? value)
     (runtime-class-type (instance-value-class value)
                         (instance-value-type-arguments value))]
    [(list-value? value)
     (runtime-list-type (list-value-element-type value))]
    [(function-value? value) 'Fn]
    [(or (class-value? value) (list-class-object? value)) 'Class]
    [else 'Object]))

(define (same-runtime-type? left right)
  (cond
    [(and (runtime-class-type? left) (runtime-class-type? right))
     (and (eq? (runtime-class-type-class left)
               (runtime-class-type-class right))
          (= (vector-length (runtime-class-type-type-arguments left))
             (vector-length (runtime-class-type-type-arguments right)))
          (for/and ([left-argument
                     (in-vector (runtime-class-type-type-arguments left))]
                    [right-argument
                     (in-vector (runtime-class-type-type-arguments right))])
            (same-runtime-type? left-argument right-argument)))]
    [(and (runtime-list-type? left) (runtime-list-type? right))
     (cond
       [(and (runtime-list-type-element-type left)
             (runtime-list-type-element-type right))
        (same-runtime-type? (runtime-list-type-element-type left)
                            (runtime-list-type-element-type right))]
       [else
        (eq? (runtime-list-type-element-type left)
             (runtime-list-type-element-type right))])]
    [(or (runtime-class-type? left) (runtime-class-type? right)) #f]
    [(or (runtime-list-type? left) (runtime-list-type? right)) #f]
    [else (eq? left right)]))

(define (send-to-instance instance selector arguments)
  (define class (instance-value-class instance))
  (define fields (class-value-fields class))
  (define field-index
    (for/first ([field (in-list fields)]
                [index (in-naturals)]
                #:when (eq? selector (field-declaration-name field)))
      index))
  (cond
    [field-index
     (unless (null? arguments)
       (arity-error (format "field ~a" selector) 0 (length arguments)))
     (vector-ref (instance-value-field-values instance) field-index)]
    [else
     (define method
       (for/first ([candidate (in-list (class-value-methods class))]
                   #:when (eq? selector
                              (method-declaration-selector candidate)))
         candidate))
     (if method
         (apply-method instance class method arguments)
         (unknown-message selector))]))

(define (apply-method receiver class method arguments)
  (define parameters (method-declaration-parameters method))
  (unless (= (length parameters) (length arguments))
    (arity-error
     (format "method ~a" (method-declaration-selector method))
     (length parameters)
     (length arguments)))
  (check-generic-method-arguments receiver class method arguments)
  (define bindings
    (cons (cons 'self receiver)
          (for/list ([parameter (in-list parameters)]
                     [argument (in-list arguments)])
            (cons (parameter-declaration-name parameter) argument))))
  (eval-expr (method-declaration-body method)
             (make-local-env (class-value-environment class) bindings)))

(define (check-generic-method-arguments receiver class method arguments)
  (unless (null? (class-value-type-parameters class))
    (for ([parameter (in-list (method-declaration-parameters method))]
          [argument (in-list arguments)])
      (check-generic-method-argument
       receiver
       class
       (parameter-declaration-type parameter)
       argument
       (method-declaration-selector method)))))

(define (check-generic-method-argument
         receiver class declared-type argument selector)
  (cond
    [(and (symbol? declared-type)
          (memq declared-type (class-value-type-parameters class)))
     (define expected
       (receiver-type-argument receiver class declared-type))
     (unless (same-runtime-type? expected (runtime-type-of argument))
       (generic-instantiation-error selector))]
    [(and (list? declared-type)
          (pair? declared-type)
          (eq? (car declared-type) (class-value-name class)))
     (unless (and (instance-value? argument)
                  (eq? (instance-value-class argument) class))
       (generic-instantiation-error selector))
     (define declared-arguments (cdr declared-type))
     (define actual-arguments (instance-value-type-arguments argument))
     (unless (= (length declared-arguments)
                (vector-length actual-arguments))
       (generic-instantiation-error selector))
     (for ([declared-argument (in-list declared-arguments)]
           [actual-argument (in-vector actual-arguments)])
       (define expected
         (resolve-method-type-argument receiver class declared-argument))
       (when (and expected
                  (not (same-runtime-type? expected actual-argument)))
         (generic-instantiation-error selector)))]))

(define (receiver-type-argument receiver class parameter)
  (for/first ([candidate
               (in-list (class-value-type-parameters class))]
              [argument
               (in-vector (instance-value-type-arguments receiver))]
              #:when (eq? candidate parameter))
    argument))

(define (resolve-method-type-argument receiver class declared-type)
  (cond
    [(and (symbol? declared-type)
          (memq declared-type (class-value-type-parameters class)))
     (receiver-type-argument receiver class declared-type)]
    [(symbol? declared-type) declared-type]
    [else #f]))

(define (generic-instantiation-error selector)
  (error 'eval-aloe
         "generic instantiation mismatch for method ~a"
         selector))

(define (send-to-function function selector arguments)
  (unless (eq? selector 'call)
    (unknown-message selector))
  (define parameters (function-value-parameters function))
  (unless (= (length parameters) (length arguments))
    (arity-error "function call" (length parameters) (length arguments)))
  (define bindings
    (for/list ([parameter (in-list parameters)]
               [argument (in-list arguments)])
      (cons parameter argument)))
  (eval-expr (function-value-body function)
             (make-local-env (function-value-environment function) bindings)))

(define (send-to-list list-object selector arguments)
  (define elements (list-value-elements list-object))
  (case selector
    [(empty?)
     (unless (null? arguments)
       (arity-error "List empty?" 0 (length arguments)))
     (zero? (vector-length elements))]
    [(first)
     (unless (null? arguments)
       (arity-error "List first" 0 (length arguments)))
     (when (zero? (vector-length elements))
       (error 'eval-aloe "first on empty List"))
     (vector-ref elements 0)]
    [(rest)
     (unless (null? arguments)
       (arity-error "List rest" 0 (length arguments)))
     (when (zero? (vector-length elements))
       (error 'eval-aloe "rest on empty List"))
     (make-list-value (cdr (vector->list elements)))]
    [(cons)
     (unless (= (length arguments) 1)
       (arity-error "List cons" 1 (length arguments)))
     (make-list-value
      (cons (car arguments) (vector->list elements)))]
    [(len)
     (unless (null? arguments)
       (arity-error "List len" 0 (length arguments)))
     (vector-length elements)]
    [(map)
     (unless (= (length arguments) 1)
       (arity-error "List map" 1 (length arguments)))
     (define function (car arguments))
     (make-list-value
      (for/list ([element (in-vector elements)])
        (lookup-message function 'call (list element))))]
    [(fold)
     (unless (= (length arguments) 2)
       (arity-error "List fold" 2 (length arguments)))
     (define initial (car arguments))
     (define function (cadr arguments))
     (for/fold ([accumulator initial])
               ([element (in-vector elements)])
       (lookup-message function 'call (list accumulator element)))]
    [else
     (unknown-message selector)]))

(define (send-to-int receiver selector arguments)
  (cond
    [(eq? selector 'float)
     (unless (null? arguments)
       (arity-error "Int float" 0 (length arguments)))
     (exact->inexact receiver)]
    [else
     (define operation
       (case selector
         [(+) +]
         [(-) -]
         [(*) *]
         [(/) quotient]
         [(<) <]
         [(>) >]
         [(<=) <=]
         [(>=) >=]
         [(=) =]
         [else (unknown-message selector)]))
     (operation receiver
                (number-argument
                 "Int" selector arguments exact-integer?))]))

(define (send-to-float receiver selector arguments)
  (define operation
    (case selector
      [(+) +]
      [(-) -]
      [(*) *]
      [(/) /]
      [(<) <]
      [(>) >]
      [(<=) <=]
      [(>=) >=]
      [(=) =]
      [else (unknown-message selector)]))
  (operation receiver
             (number-argument "Float" selector arguments flonum?)))

(define (send-to-bool receiver selector arguments)
  (unless (eq? selector 'if)
    (unknown-message selector))
  (unless (= (length arguments) 2)
    (arity-error "Bool if" 2 (length arguments)))
  (for ([argument (in-list arguments)])
    (unless (function-value? argument)
      (error 'eval-aloe
             "Bool if expects zero-argument function objects")))
  (lookup-message (if receiver (car arguments) (cadr arguments))
                  'call
                  '()))

(define (number-argument kind selector arguments expected-kind?)
  (unless (= (length arguments) 1)
    (arity-error (format "~a ~a" kind selector) 1 (length arguments)))
  (define argument (car arguments))
  (unless (expected-kind? argument)
    (error 'eval-aloe
           "~a ~a expects ~a ~a argument"
           kind
           selector
           (if (string=? kind "Int") "an" "a")
           kind))
  argument)

(define (arity-error target expected actual)
  (error 'eval-aloe
         "arity error for ~a: expected ~a argument(s), got ~a"
         target
         expected
         actual))

(define (unknown-message selector)
  (error 'eval-aloe "unknown message: ~a" selector))

(define (eval-exprs expressions environment)
  (for/fold ([result (void)])
            ([expression (in-list expressions)])
    (eval-expr expression environment)))

(define (aloe-value->string value)
  (cond
    [(boolean? value) (if value "#t" "#f")]
    [(number? value) (number->string value)]
    [(class-value? value)
     (format "#<class ~a>" (class-value-name value))]
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
     (define count (vector-length (list-value-elements value)))
     (format "#<List ~a ~a>"
             count
             (if (= count 1) "element" "elements"))]
    [(list-class-object? value) "#<class List>"]
    [(void? value) "#<void>"]
    [else "#<object>"]))
