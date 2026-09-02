#lang racket/base

(require racket/list
         racket/match
         "parse.rkt")

(provide (struct-out exn:fail:aloe-type)
         (struct-out int-type)
         (struct-out float-type)
         (struct-out bool-type)
         (struct-out instance-type)
         (struct-out list-type)
         (struct-out class-type)
         (struct-out list-class-type)
         (struct-out function-type)
         type-environment?
         make-type-environment
         type-of
         typecheck-program
         type->datum)

(struct exn:fail:aloe-type exn:fail () #:transparent)

(struct int-type () #:transparent)
(struct float-type () #:transparent)
(struct bool-type () #:transparent)
(struct instance-type (class arguments) #:transparent)
(struct list-type (element) #:transparent)
(struct class-type (class) #:transparent)
(struct list-class-type () #:transparent)
(struct function-type (parameters result) #:transparent)
(struct parameter-type (id name) #:transparent)
(struct type-variable
  (id label [binding #:mutable] [numeric? #:mutable])
  #:transparent)
(struct opaque-type (name) #:transparent)
(struct void-type () #:transparent)

(struct class-info
  (name type-parameters parameter-types fields methods)
  #:transparent)
(struct type-environment (bindings parent) #:transparent)

(define INT (int-type))
(define FLOAT (float-type))
(define BOOL (bool-type))
(define VOID (void-type))

(define (raise-type-error format-string . arguments)
  (raise
   (exn:fail:aloe-type
    (string-append
     "typecheck: "
     (apply format format-string arguments))
    (current-continuation-marks))))

(define (fresh-type-variable [label #f])
  (type-variable (gensym 'type) label #f #f))

(define (make-type-environment)
  (type-environment
   (make-hasheq
    (list (cons 'dummy (opaque-type 'Dummy))
          (cons 'List (list-class-type))))
   #f))

(define (make-local-type-environment parent bindings)
  (type-environment (make-hasheq bindings) parent))

(define (type-environment-ref environment name)
  (define bindings (type-environment-bindings environment))
  (cond
    [(hash-has-key? bindings name)
     (hash-ref bindings name)]
    [(type-environment-parent environment)
     (type-environment-ref (type-environment-parent environment) name)]
    [else
     (raise-type-error "unbound symbol: ~a" name)]))

(define (type-environment-set! environment name type)
  (hash-set! (type-environment-bindings environment) name type))

(define (resolve-type type)
  (cond
    [(and (type-variable? type) (type-variable-binding type))
     (define resolved (resolve-type (type-variable-binding type)))
     (set-type-variable-binding! type resolved)
     resolved]
    [else type]))

(define (type->datum type)
  (define resolved (resolve-type type))
  (cond
    [(int-type? resolved) 'Int]
    [(float-type? resolved) 'Float]
    [(bool-type? resolved) 'Bool]
    [(instance-type? resolved)
     (define name (class-info-name (instance-type-class resolved)))
     (if (null? (instance-type-arguments resolved))
         name
         (cons name (map type->datum (instance-type-arguments resolved))))]
    [(list-type? resolved)
     (list 'List (type->datum (list-type-element resolved)))]
    [(class-type? resolved)
     (list 'Class (class-info-name (class-type-class resolved)))]
    [(list-class-type? resolved) '(Class List)]
    [(function-type? resolved)
     (list 'Fn
           (map type->datum (function-type-parameters resolved))
           (type->datum (function-type-result resolved)))]
    [(parameter-type? resolved) (parameter-type-name resolved)]
    [(type-variable? resolved)
     (or (type-variable-label resolved) '?)]
    [(opaque-type? resolved) (opaque-type-name resolved)]
    [(void-type? resolved) 'Void]
    [else '?]))

(define (type-mismatch message left right)
  (if message
      (raise-type-error "~a" message)
      (raise-type-error "type mismatch: expected ~a, got ~a"
                        (type->datum right)
                        (type->datum left))))

(define (occurs-in? variable type)
  (define resolved (resolve-type type))
  (cond
    [(eq? variable resolved) #t]
    [(instance-type? resolved)
     (ormap (lambda (argument) (occurs-in? variable argument))
            (instance-type-arguments resolved))]
    [(list-type? resolved)
     (occurs-in? variable (list-type-element resolved))]
    [(function-type? resolved)
     (or (ormap (lambda (parameter) (occurs-in? variable parameter))
                (function-type-parameters resolved))
         (occurs-in? variable (function-type-result resolved)))]
    [else #f]))

(define (ensure-numeric-type! type [message #f])
  (define resolved (resolve-type type))
  (cond
    [(or (int-type? resolved)
         (float-type? resolved)
         (parameter-type? resolved))
     (void)]
    [(type-variable? resolved)
     (set-type-variable-numeric?! resolved #t)]
    [else
     (type-mismatch
      (or message "numeric message requires Int or Float")
      resolved
      INT)]))

(define (bind-type-variable! variable type message)
  (define resolved (resolve-type type))
  (cond
    [(eq? variable resolved) variable]
    [(occurs-in? variable resolved)
     (type-mismatch message resolved variable)]
    [else
     (when (type-variable-numeric? variable)
       (ensure-numeric-type! resolved message))
     (when (and (type-variable? resolved)
                (type-variable-numeric? variable))
       (set-type-variable-numeric?! resolved #t))
     (set-type-variable-binding! variable resolved)
     resolved]))

(define (unify-types! left right [message #f])
  (define resolved-left (resolve-type left))
  (define resolved-right (resolve-type right))
  (cond
    [(eq? resolved-left resolved-right) resolved-left]
    [(type-variable? resolved-left)
     (bind-type-variable! resolved-left resolved-right message)]
    [(type-variable? resolved-right)
     (bind-type-variable! resolved-right resolved-left message)]
    [(and (int-type? resolved-left) (int-type? resolved-right)) INT]
    [(and (float-type? resolved-left) (float-type? resolved-right)) FLOAT]
    [(and (bool-type? resolved-left) (bool-type? resolved-right)) BOOL]
    [(and (parameter-type? resolved-left)
          (parameter-type? resolved-right)
          (eq? (parameter-type-id resolved-left)
               (parameter-type-id resolved-right)))
     resolved-left]
    [(and (instance-type? resolved-left) (instance-type? resolved-right)
          (eq? (instance-type-class resolved-left)
               (instance-type-class resolved-right))
          (= (length (instance-type-arguments resolved-left))
             (length (instance-type-arguments resolved-right))))
     (for ([left-argument (in-list (instance-type-arguments resolved-left))]
           [right-argument (in-list (instance-type-arguments resolved-right))])
       (unify-types! left-argument right-argument message))
     resolved-left]
    [(and (list-type? resolved-left) (list-type? resolved-right))
     (unify-types! (list-type-element resolved-left)
                   (list-type-element resolved-right)
                   message)
     resolved-left]
    [(and (class-type? resolved-left) (class-type? resolved-right)
          (eq? (class-type-class resolved-left)
               (class-type-class resolved-right)))
     resolved-left]
    [(and (list-class-type? resolved-left)
          (list-class-type? resolved-right))
     resolved-left]
    [(and (function-type? resolved-left) (function-type? resolved-right)
          (= (length (function-type-parameters resolved-left))
             (length (function-type-parameters resolved-right))))
     (for ([left-parameter
            (in-list (function-type-parameters resolved-left))]
           [right-parameter
            (in-list (function-type-parameters resolved-right))])
       (unify-types! left-parameter right-parameter message))
     (unify-types! (function-type-result resolved-left)
                   (function-type-result resolved-right)
                   message)
     resolved-left]
    [(and (opaque-type? resolved-left) (opaque-type? resolved-right)
          (eq? (opaque-type-name resolved-left)
               (opaque-type-name resolved-right)))
     resolved-left]
    [(and (void-type? resolved-left) (void-type? resolved-right)) VOID]
    [else
     (type-mismatch message resolved-left resolved-right)]))

(define (type-of expression [environment (make-type-environment)])
  (resolve-type (infer-expression expression environment #f)))

(define (typecheck-program expressions
                           [environment (make-type-environment)])
  (for/fold ([result VOID])
            ([expression (in-list expressions)])
    (type-of expression environment)))

(define (infer-expression expression environment expected)
  (define inferred
    (match expression
      [(int-expr _) INT]
      [(float-expr _) FLOAT]
      [(bool-expr _) BOOL]
      [(variable-expr name)
       (type-environment-ref environment name)]
      [(define-expr name value-expression)
       (define value-type
         (infer-expression value-expression environment #f))
       (type-environment-set! environment name value-type)
       VOID]
      [(define-class-expr name type-parameters fields methods)
       (check-class-definition!
        name type-parameters fields methods environment)
       VOID]
      [(fn-expr parameters body)
       (infer-function parameters body environment expected)]
      [(send-expr receiver selector arguments)
       (infer-send receiver selector arguments environment expected)]))
  (when expected
    (unify-types! inferred expected))
  inferred)

(define (infer-function parameters body environment expected)
  (define resolved-expected (and expected (resolve-type expected)))
  (define expected-function
    (and (function-type? resolved-expected) resolved-expected))
  (when (and expected-function
             (not (= (length parameters)
                     (length
                      (function-type-parameters expected-function)))))
    (raise-type-error
     "arity error for function: expected ~a parameter(s), got ~a"
     (length (function-type-parameters expected-function))
     (length parameters)))
  (define parameter-types
    (if expected-function
        (function-type-parameters expected-function)
        (for/list ([parameter (in-list parameters)])
          (fresh-type-variable parameter))))
  (define local-environment
    (make-local-type-environment
     environment
     (map cons parameters parameter-types)))
  (define result-expected
    (and expected-function (function-type-result expected-function)))
  (define result-type
    (infer-expression body local-environment result-expected))
  (function-type parameter-types result-type))

(define (check-class-definition!
         name type-parameters fields methods environment)
  (define parameter-types
    (for/list ([parameter (in-list type-parameters)])
      (parameter-type (gensym parameter) parameter)))
  (define class
    (class-info name type-parameters parameter-types fields methods))
  (type-environment-set! environment name (class-type class))
  (define substitution
    (make-hasheq (map cons type-parameters parameter-types)))
  (for ([field (in-list fields)])
    (type-from-sexpr
     (field-declaration-type field) environment substitution))
  (for ([method (in-list methods)])
    (check-method-definition!
     class
     method
     environment
     substitution
     (null? type-parameters))))

(define (check-method-definition!
         class method environment substitution check-body?)
  (for ([parameter (in-list (method-declaration-parameters method))])
    (type-from-sexpr
     (parameter-declaration-type parameter)
     environment
     substitution))
  (type-from-sexpr
   (method-declaration-return-type method)
   environment
   substitution)
  (when check-body?
    (check-method-body!
     (instance-type class (class-info-parameter-types class))
     method
     environment
     substitution)))

(define (check-method-body! self-type method environment substitution)
  (define parameter-types
    (for/list ([parameter
                (in-list (method-declaration-parameters method))])
      (type-from-sexpr
       (parameter-declaration-type parameter)
       environment
       substitution)))
  (define return-type
    (type-from-sexpr
     (method-declaration-return-type method)
     environment
     substitution))
  (define bindings
    (cons
     (cons 'self self-type)
     (for/list ([parameter
                 (in-list (method-declaration-parameters method))]
                [parameter-type (in-list parameter-types)])
       (cons (parameter-declaration-name parameter) parameter-type))))
  (define local-environment
    (make-local-type-environment environment bindings))
  (define body-type
    (infer-expression
     (method-declaration-body method) local-environment return-type))
  (unify-types!
   body-type
   return-type
   (format "method ~a return type mismatch"
           (method-declaration-selector method))))

(define (type-from-sexpr datum environment substitution)
  (cond
    [(symbol? datum)
     (cond
       [(eq? datum 'Int) INT]
       [(eq? datum 'Float) FLOAT]
       [(eq? datum 'Bool) BOOL]
       [(hash-has-key? substitution datum)
        (hash-ref substitution datum)]
       [else
        (define named-type (type-environment-ref environment datum))
        (cond
          [(class-type? named-type)
           (define class (class-type-class named-type))
           (unless (null? (class-info-type-parameters class))
             (raise-type-error "generic type ~a needs arguments" datum))
           (instance-type class '())]
          [(list-class-type? named-type)
           (raise-type-error "List type needs an element type")]
          [else
           (raise-type-error "~a is not a type" datum)])])]
    [(and (list? datum) (pair? datum) (symbol? (car datum)))
     (define name (car datum))
     (define arguments (cdr datum))
     (cond
       [(eq? name 'List)
        (unless (= (length arguments) 1)
          (raise-type-error "List type needs one argument"))
        (list-type
         (type-from-sexpr (car arguments) environment substitution))]
       [else
        (define named-type (type-environment-ref environment name))
        (unless (class-type? named-type)
          (raise-type-error "~a is not a class type" name))
        (define class (class-type-class named-type))
        (define expected-count
          (length (class-info-type-parameters class)))
        (if (zero? expected-count)
            ;; Checkpoints 3–4 used (Point Int) annotations on a
            ;; non-generic Point. Preserve that accepted surface form.
            (instance-type class '())
            (begin
              (unless (= expected-count (length arguments))
                (raise-type-error
                 "type ~a expects ~a argument(s), got ~a"
                 name expected-count (length arguments)))
              (instance-type
               class
               (for/list ([argument (in-list arguments)])
                 (type-from-sexpr
                  argument environment substitution)))))])]
    [else
     (raise-type-error "malformed type: ~a" datum)]))

(define (infer-send receiver-expression selector arguments environment expected)
  (cond
    [(and (eq? selector 'call) (fn-expr? receiver-expression))
     (define argument-types
       (for/list ([argument (in-list arguments)])
         (infer-expression argument environment #f)))
     (define result-type (fresh-type-variable 'call-result))
     (define expected-function
       (function-type argument-types result-type))
     (define actual-function
       (infer-expression
        receiver-expression environment expected-function))
     (unify-types! actual-function expected-function)
     result-type]
    [else
     (define receiver-type
       (resolve-type
        (infer-expression receiver-expression environment #f)))
     (cond
       [(class-type? receiver-type)
        (if (eq? selector 'new)
            (infer-construction
             (class-type-class receiver-type) arguments environment)
            (unknown-message selector))]
       [(list-class-type? receiver-type)
        (case selector
          [(of) (infer-list-construction arguments environment)]
          [(empty) (infer-empty-list arguments expected)]
          [else (unknown-message selector)])]
       [(instance-type? receiver-type)
        (infer-instance-send
         receiver-type selector arguments environment)]
       [(list-type? receiver-type)
        (infer-list-send receiver-type selector arguments environment)]
       [(function-type? receiver-type)
        (infer-function-call
         receiver-type selector arguments environment)]
       [(or (int-type? receiver-type)
            (float-type? receiver-type)
            (parameter-type? receiver-type))
        (infer-numeric-send
         receiver-type selector arguments environment)]
       [(bool-type? receiver-type)
        (infer-bool-send selector arguments environment)]
       [(type-variable? receiver-type)
        (cond
          [(eq? selector 'call)
           (define argument-types
             (for/list ([argument (in-list arguments)])
               (infer-expression argument environment #f)))
           (define result-type (fresh-type-variable 'result))
           (unify-types!
            receiver-type
            (function-type argument-types result-type))
           result-type]
          [(memq selector '(+ - * / < > <= >= =))
           (infer-numeric-send
            receiver-type selector arguments environment)]
          [else (unknown-message selector)])]
       [else
        (unknown-message selector)])]))

(define (infer-construction class arguments environment)
  (define fields (class-info-fields class))
  (unless (= (length fields) (length arguments))
    (raise-type-error
     "arity error for new: expected ~a argument(s), got ~a"
     (length fields)
     (length arguments)))
  (define argument-types
    (for/list ([argument (in-list arguments)]
               [field (in-list fields)])
      (define expected-field-type
        (and (null? (class-info-type-parameters class))
             (type-from-sexpr
              (field-declaration-type field)
              environment
              (make-hasheq))))
      (infer-expression argument environment expected-field-type)))
  (define inferred (make-hasheq))
  (for ([parameter (in-list (class-info-type-parameters class))])
    (hash-set! inferred parameter #f))
  (for ([field (in-list fields)]
        [argument-type (in-list argument-types)])
    (infer-field-type!
     class
     (field-declaration-type field)
     argument-type
     environment
     inferred))
  (define type-arguments
    (for/list ([parameter (in-list (class-info-type-parameters class))])
      (define inferred-type (hash-ref inferred parameter))
      (unless inferred-type
        (raise-type-error
         "cannot infer type parameter ~a for ~a"
         parameter
         (class-info-name class)))
      (resolve-type inferred-type)))
  (instance-type class type-arguments))

(define (infer-field-type!
         class declared-type actual-type environment inferred)
  (cond
    [(and (symbol? declared-type)
          (hash-has-key? inferred declared-type))
     (define previous (hash-ref inferred declared-type))
     (if previous
         (unify-types!
          actual-type
          previous
          (format "inconsistent type parameter ~a" declared-type))
         (hash-set! inferred declared-type actual-type))]
    [(and (list? declared-type)
          (pair? declared-type)
          (eq? (car declared-type) 'List))
     (define resolved-actual (resolve-type actual-type))
     (unless (and (= (length declared-type) 2)
                  (list-type? resolved-actual))
       (raise-type-error "constructor field type mismatch"))
     (infer-field-type!
      class
      (cadr declared-type)
      (list-type-element resolved-actual)
      environment
      inferred)]
    [(and (list? declared-type)
          (pair? declared-type)
          (symbol? (car declared-type)))
     (define named-type
       (type-environment-ref environment (car declared-type)))
     (define resolved-actual (resolve-type actual-type))
     (unless (and (class-type? named-type)
                  (instance-type? resolved-actual)
                  (eq? (class-type-class named-type)
                       (instance-type-class resolved-actual)))
       (raise-type-error "constructor field type mismatch"))
     (define nested-class (class-type-class named-type))
     (unless (zero? (length (class-info-type-parameters nested-class)))
       (unless (= (length (cdr declared-type))
                  (length (instance-type-arguments resolved-actual)))
         (raise-type-error "constructor field type mismatch"))
       (for ([nested-declared (in-list (cdr declared-type))]
             [nested-actual
              (in-list (instance-type-arguments resolved-actual))])
         (infer-field-type!
          class nested-declared nested-actual environment inferred)))]
    [else
     (define expected
       (type-from-sexpr declared-type environment (make-hasheq)))
     (unify-types! actual-type expected "constructor field type mismatch")]))

(define (infer-instance-send instance selector arguments environment)
  (define class (instance-type-class instance))
  (define field
    (for/first ([candidate (in-list (class-info-fields class))]
                #:when (eq? selector
                            (field-declaration-name candidate)))
      candidate))
  (cond
    [field
     (unless (null? arguments)
       (raise-type-error
        "arity error for field ~a: expected 0 arguments, got ~a"
        selector
        (length arguments)))
     (type-from-sexpr
      (field-declaration-type field)
      environment
      (instance-substitution instance))]
    [else
     (define method
       (for/first ([candidate (in-list (class-info-methods class))]
                   #:when (eq? selector
                              (method-declaration-selector candidate)))
         candidate))
     (unless method (unknown-message selector))
     (define parameters (method-declaration-parameters method))
     (unless (= (length parameters) (length arguments))
       (raise-type-error
        "arity error for method ~a: expected ~a argument(s), got ~a"
        selector
        (length parameters)
        (length arguments)))
     (define substitution (instance-substitution instance))
     (for ([parameter (in-list parameters)]
           [argument (in-list arguments)])
       (define expected
         (type-from-sexpr
          (parameter-declaration-type parameter)
          environment
          substitution))
       (define actual
         (infer-expression argument environment #f))
       (unify-types!
        actual
        expected
        (format "generic instantiation mismatch for method ~a"
                selector)))
     (define return-type
       (type-from-sexpr
        (method-declaration-return-type method)
        environment
        substitution))
     (unless (null? (class-info-type-parameters class))
       (check-method-body!
        instance method environment substitution))
     return-type]))

(define (instance-substitution instance)
  (make-hasheq
   (map cons
        (class-info-type-parameters (instance-type-class instance))
        (instance-type-arguments instance))))

(define (infer-list-construction arguments environment)
  (cond
    [(null? arguments)
     (list-type (fresh-type-variable 'List-element))]
    [else
     (define element-type
       (infer-expression (car arguments) environment #f))
     (for ([argument (in-list (cdr arguments))])
       (define next-type
         (infer-expression argument environment #f))
       (unify-types!
        next-type
        element-type
        "List of elements must have one type"))
     (list-type element-type)]))

(define (infer-empty-list arguments expected)
  (unless (null? arguments)
    (raise-type-error
     "arity error for List empty: expected 0 arguments, got ~a"
     (length arguments)))
  (define resolved-expected (and expected (resolve-type expected)))
  (if (list-type? resolved-expected)
      resolved-expected
      (list-type (fresh-type-variable 'List-element))))

(define (infer-list-send list-value-type selector arguments environment)
  (define element-type (list-type-element list-value-type))
  (case selector
    [(empty?)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List empty?: expected 0 arguments, got ~a"
        (length arguments)))
     BOOL]
    [(first)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List first: expected 0 arguments, got ~a"
        (length arguments)))
     element-type]
    [(rest)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List rest: expected 0 arguments, got ~a"
        (length arguments)))
     list-value-type]
    [(cons)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for List cons: expected 1 argument, got ~a"
        (length arguments)))
     (define argument-type
       (infer-expression (car arguments) environment element-type))
     (unify-types!
      argument-type element-type "List cons element type mismatch")
     list-value-type]
    [(len)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List len: expected 0 arguments, got ~a"
        (length arguments)))
     INT]
    [(map)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for List map: expected 1 argument, got ~a"
        (length arguments)))
     (define result-type (fresh-type-variable 'map-result))
     (define expected-function
       (function-type (list element-type) result-type))
     (define actual-function
       (infer-expression (car arguments) environment expected-function))
     (unify-types! actual-function expected-function)
     (list-type result-type)]
    [(fold)
     (unless (= (length arguments) 2)
       (raise-type-error
        "arity error for List fold: expected 2 arguments, got ~a"
        (length arguments)))
     (define accumulator-type
       (infer-expression (car arguments) environment #f))
     (define expected-function
       (function-type
        (list accumulator-type element-type)
        accumulator-type))
     (define actual-function
       (infer-expression (cadr arguments) environment expected-function))
     (unify-types! actual-function expected-function)
     accumulator-type]
    [else
     (unknown-message selector)]))

(define (infer-function-call function selector arguments environment)
  (unless (eq? selector 'call) (unknown-message selector))
  (define parameters (function-type-parameters function))
  (unless (= (length parameters) (length arguments))
    (raise-type-error
     "arity error for function call: expected ~a argument(s), got ~a"
     (length parameters)
     (length arguments)))
  (for ([parameter (in-list parameters)]
        [argument (in-list arguments)])
    (define actual
      (infer-expression argument environment parameter))
    (unify-types! actual parameter))
  (function-type-result function))

(define (infer-numeric-send receiver selector arguments environment)
  (define resolved-receiver (resolve-type receiver))
  (cond
    [(eq? selector 'float)
     (unless (int-type? resolved-receiver)
       (unknown-message selector))
     (unless (null? arguments)
       (raise-type-error
        "arity error for Int float: expected 0 arguments, got ~a"
        (length arguments)))
     FLOAT]
    [else
     (unless (memq selector '(+ - * / < > <= >= =))
       (unknown-message selector))
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for numeric ~a: expected 1 argument, got ~a"
        selector
        (length arguments)))
     (ensure-numeric-type! receiver)
     (define mismatch-message
       (cond
         [(int-type? resolved-receiver)
          (format "Int ~a expects an Int argument" selector)]
         [(float-type? resolved-receiver)
          (format "Float ~a expects a Float argument" selector)]
         [else "numeric operands must have the same type"]))
     (define argument-type
       (infer-expression (car arguments) environment #f))
     (unify-types! argument-type receiver mismatch-message)
     (ensure-numeric-type! receiver)
     (if (memq selector '(< > <= >= =)) BOOL receiver)]))

(define (infer-bool-send selector arguments environment)
  (unless (eq? selector 'if) (unknown-message selector))
  (unless (= (length arguments) 2)
    (raise-type-error
     "arity error for Bool if: expected 2 arguments, got ~a"
     (length arguments)))
  (define result-type (fresh-type-variable 'if-result))
  (define expected-thunk (function-type '() result-type))
  (for ([argument (in-list arguments)])
    (define actual-thunk
      (infer-expression argument environment expected-thunk))
    (unify-types! actual-thunk expected-thunk))
  result-type)

(define (unknown-message selector)
  (raise-type-error "unknown message: ~a" selector))
