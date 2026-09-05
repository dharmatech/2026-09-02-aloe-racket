#lang racket/base

(require racket/list
         racket/match
         racket/string
         "env.rkt"
         "host.rkt"
         "mirror.rkt"
         "parse.rkt"
         "signature.rkt"
         "symbol.rkt")

(provide eval-expr
         eval-exprs
         aloe-value->string
         aloe-value->display-string)

(struct class-value
  (name type-parameters protocol fields [methods #:mutable] environment)
  #:transparent)
(struct instance-value (class type-arguments field-values) #:transparent)
(struct function-value (parameters body environment) #:transparent)
(struct list-value (class element-type elements) #:transparent)
(struct runtime-class-type (class type-arguments) #:transparent)
(struct runtime-list-type (element-type) #:transparent)
(struct runtime-class-object-type (class) #:transparent)
(struct runtime-method-match (method specificity) #:transparent)
(struct signature-spec (selector parameters return) #:transparent)

(define current-eval-load-paths (make-parameter '()))

(define (eval-load! expression environment)
  (define path (load-expr-resolved-path expression))
  (unless (file-exists? path)
    (error 'eval-aloe "load file not found: ~a" path))
  (when (member path (current-eval-load-paths) equal?)
    (error 'eval-aloe "load cycle: ~a" path))
  (define expressions
    (call-with-input-file path
      (lambda (input)
        (read-program input #:source-path path))))
  (parameterize
      ([current-eval-load-paths
        (cons path (current-eval-load-paths))])
    (eval-exprs expressions environment))
  (void))

(define (eval-expr expression environment)
  (match expression
    [(int-expr value) value]
    [(float-expr value) value]
    [(bool-expr value) value]
    [(string-expr value) value]
    [(variable-expr name)
     (env-lookup environment name)]
    [(? load-expr?)
     (eval-load! expression environment)]
    [(check-expr left right left-datum right-datum)
     (define left-value (eval-expr left environment))
     (define right-value (eval-expr right environment))
     (unless (aloe-values-equal? left-value right-value)
       (error 'eval-aloe
              "check failed: ~s => ~a vs ~s => ~a"
              left-datum
              (aloe-value->display-string left-value)
              right-datum
              (aloe-value->display-string right-value)))
     right-value]
    [(define-expr name value-expression)
     (define value (eval-expr value-expression environment))
     (env-define! environment name value)]
    [(define-protocol-expr _ _) (void)]
    [(define-class-expr name type-parameters protocol fields methods)
     (env-define! environment
                  name
                  (class-value
                   name
                   type-parameters
                   protocol
                   fields
                   methods
                   environment))]
    [(define-methods-expr target methods)
     (define target-class (env-lookup environment target))
     (cond
       [(list-class-object? target-class)
        (set-list-class-object-methods!
         target-class
         (append (list-class-object-methods target-class) methods))
        (set-list-class-object-environment! target-class environment)]
       [(class-value? target-class)
        (set-class-value-methods!
         target-class
         (append (class-value-methods target-class) methods))]
       [else
        (error 'eval-aloe
               "define-methods target is not a class: ~a"
               target)])]
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
     (send-to-list-class receiver selector arguments)]
    [(symbol-class-object? receiver)
     (send-to-symbol-class selector arguments)]
    [(mirror-class-object? receiver)
     (send-to-mirror-class receiver selector arguments)]
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
    [(host-receiver? receiver)
     (host-receiver-send receiver selector arguments)]
    [(exact-integer? receiver)
     (send-to-int receiver selector arguments)]
    [(flonum? receiver)
     (send-to-float receiver selector arguments)]
    [(boolean? receiver)
     (send-to-bool receiver selector arguments)]
    [(string? receiver)
     (send-to-string receiver selector arguments)]
    [(symbol-value? receiver)
     (send-to-symbol receiver selector arguments)]
    [(mirror-value? receiver)
     (send-to-mirror receiver selector arguments)]
    [(signature-value? receiver)
     (send-to-signature receiver selector arguments)]
    [else
     (unknown-message selector)]))

(define (send-to-mirror-class receiver selector arguments)
  (unless (eq? selector 'of)
    (unknown-message selector))
  (unless (= (length arguments) 1)
    (arity-error "Mirror of" 1 (length arguments)))
  (mirror-value (car arguments) (mirror-class-object-list-class receiver)))

(define (runtime-type->datum type)
  (cond
    [(runtime-class-type? type)
     (define class (runtime-class-type-class type))
     (define arguments
       (map runtime-type->datum
            (vector->list
             (runtime-class-type-type-arguments type))))
     (if (null? arguments)
         (class-value-name class)
         (cons (class-value-name class) arguments))]
    [(runtime-list-type? type)
     (list 'List
           (if (runtime-list-type-element-type type)
               (runtime-type->datum
                (runtime-list-type-element-type type))
               '?))]
    [(symbol? type) type]
    [else '?]))

(define (substitute-type-datum datum substitution)
  (cond
    [(and (symbol? datum) (hash-has-key? substitution datum))
     (hash-ref substitution datum)]
    [(list? datum)
     (map (lambda (part)
            (substitute-type-datum part substitution))
          datum)]
    [else datum]))

(define (method->signature-spec method substitution)
  (signature-spec
   (method-declaration-selector method)
   (for/list ([parameter
               (in-list (method-declaration-parameters method))])
     (substitute-type-datum
      (parameter-declaration-type parameter)
      substitution))
   (substitute-type-datum
    (method-declaration-return-type method)
    substitution)))

(define (methods->signature-specs methods substitution)
  (for/list ([method (in-list methods)])
    (method->signature-spec method substitution)))

(define (instance-signature-specs instance)
  (define class (instance-value-class instance))
  (define substitution
    (make-hasheq
     (map cons
          (class-value-type-parameters class)
          (map runtime-type->datum
               (vector->list
                (instance-value-type-arguments instance))))))
  (append
   (for/list ([field (in-list (class-value-fields class))])
     (signature-spec
      (field-declaration-name field)
      '()
      (substitute-type-datum
       (field-declaration-type field)
       substitution)))
   (methods->signature-specs (class-value-methods class) substitution)))

(define (class-instance-type-datum class)
  (define parameters (class-value-type-parameters class))
  (if (null? parameters)
      (class-value-name class)
      (cons (class-value-name class) parameters)))

(define (class-signature-specs class)
  (list
   (signature-spec
    'new
    (map field-declaration-type (class-value-fields class))
    (class-instance-type-datum class))))

(define (list-signature-specs value)
  (define element-type
    (if (list-value-element-type value)
        (runtime-type->datum (list-value-element-type value))
        'T))
  (define substitution (make-hasheq (list (cons 'T element-type))))
  (append
   (list (signature-spec 'empty? '() 'Bool)
         (signature-spec 'first '() element-type)
         (signature-spec 'rest '() (list 'List element-type))
         (signature-spec 'cons (list element-type)
                         (list 'List element-type))
         (signature-spec 'len '() 'Int))
   (methods->signature-specs
    (list-class-object-methods (list-value-class value))
    substitution)))

(define (value-signature-specs value)
  (cond
    [(exact-integer? value)
     (list (signature-spec '+ '(Int) 'Int)
           (signature-spec '- '(Int) 'Int)
           (signature-spec '* '(Int) 'Int)
           (signature-spec '/ '(Int) 'Int)
           (signature-spec '< '(Int) 'Bool)
           (signature-spec '> '(Int) 'Bool)
           (signature-spec '<= '(Int) 'Bool)
           (signature-spec '>= '(Int) 'Bool)
           (signature-spec '= '(Int) 'Bool)
           (signature-spec 'float '() 'Float)
           (signature-spec 'text '() 'String))]
    [(flonum? value)
     (list (signature-spec '+ '(Float) 'Float)
           (signature-spec '- '(Float) 'Float)
           (signature-spec '* '(Float) 'Float)
           (signature-spec '/ '(Float) 'Float)
           (signature-spec '< '(Float) 'Bool)
           (signature-spec '> '(Float) 'Bool)
           (signature-spec '<= '(Float) 'Bool)
           (signature-spec '>= '(Float) 'Bool)
           (signature-spec '= '(Float) 'Bool))]
    [(boolean? value)
     (list (signature-spec 'if '((-> T) (-> T)) 'T))]
    [(string? value)
     (list (signature-spec '= '(String) 'Bool)
           (signature-spec 'append '(String) 'String))]
    [(symbol-value? value)
     (list (signature-spec 'name '() 'String)
           (signature-spec '= '(Symbol) 'Bool))]
    [(function-value? value)
     (list
      (signature-spec
       'call
       (make-list (length (function-value-parameters value)) 'T)
       'U))]
    [(list-value? value) (list-signature-specs value)]
    [(instance-value? value) (instance-signature-specs value)]
    [(class-value? value) (class-signature-specs value)]
    [(list-class-object? value)
     (list (signature-spec 'of '(T) '(List T))
           (signature-spec 'empty '() '(List T)))]
    [(symbol-class-object? value)
     (list (signature-spec 'intern '(String) 'Symbol))]
    [(mirror-class-object? value)
     (list (signature-spec 'of '(T) 'Mirror))]
    [(mirror-value? value)
     (list (signature-spec 'messages '() '(List Symbol))
           (signature-spec 'signatures '() '(List Signature))
           (signature-spec 'invoke '(Signature) 'U)
           (signature-spec 'subject '() 'U))]
    [(signature-value? value)
     (list (signature-spec 'selector '() 'Symbol)
           (signature-spec 'params '() '(List TypeData))
           (signature-spec 'return '() 'TypeData))]
    [else '()]))

(define (value-selector-names value)
  (remove-duplicates
   (map signature-spec-selector (value-signature-specs value))
   eq?))

(define (make-type-data-list class elements)
  (list-value class 'TypeData (apply vector-immutable elements)))

(define (type-datum->aloe-value class datum)
  (cond
    [(symbol? datum) (intern-symbol (symbol->string datum))]
    [(list? datum)
     (make-type-data-list
      class
      (map (lambda (part)
             (type-datum->aloe-value class part))
           datum))]
    [else
     (error 'eval-aloe "cannot reify type datum: ~a" datum)]))

(define (signature-type-parameters subject row-index)
  (cond
    [(instance-value? subject)
     (define class (instance-value-class subject))
     (define method-index
       (- row-index (length (class-value-fields class))))
     (if (negative? method-index)
         '()
         (method-declaration-type-parameters
          (list-ref (class-value-methods class) method-index)))]
    [(list-value? subject)
     (define method-index (- row-index 5))
     (if (negative? method-index)
         '()
         (method-declaration-type-parameters
          (list-ref
           (list-class-object-methods (list-value-class subject))
           method-index)))]
    [(class-value? subject) (class-value-type-parameters subject)]
    [(boolean? subject) '(T)]
    [(function-value? subject) '(T U)]
    [(list-class-object? subject) '(T)]
    [(mirror-class-object? subject) '(T)]
    [(and (mirror-value? subject) (memv row-index '(2 3))) '(U)]
    [else '()]))

(define (runtime-owner-type value)
  (cond
    [(class-value? value) (runtime-class-object-type value)]
    [(list-class-object? value) 'ListClass]
    [(symbol-class-object? value) 'SymbolClass]
    [(mirror-class-object? value) 'MirrorClass]
    [else (runtime-type-of value)]))

(define (same-runtime-owner-type? left right)
  (cond
    [(and (runtime-class-object-type? left)
          (runtime-class-object-type? right))
     (eq? (runtime-class-object-type-class left)
          (runtime-class-object-type-class right))]
    [(or (runtime-class-object-type? left)
         (runtime-class-object-type? right))
     #f]
    [else (same-runtime-type? left right)]))

(define (signature-spec->value class subject spec row-index)
  (signature-value
   (intern-symbol (symbol->string (signature-spec-selector spec)))
   (make-type-data-list
    class
    (map (lambda (parameter)
           (type-datum->aloe-value class parameter))
         (signature-spec-parameters spec)))
   (type-datum->aloe-value class (signature-spec-return spec))
   (runtime-owner-type subject)
   row-index
   (signature-spec-parameters spec)
   (signature-spec-return spec)
   (signature-type-parameters subject row-index)))

(define (send-to-mirror receiver selector arguments)
  (define class (mirror-value-list-class receiver))
  (case selector
    [(messages)
     (unless (null? arguments)
       (arity-error "Mirror messages" 0 (length arguments)))
     (make-list-value
      class
      (map intern-symbol
           (map symbol->string
                (value-selector-names
                 (mirror-value-subject receiver)))))]
    [(signatures)
     (unless (null? arguments)
       (arity-error "Mirror signatures" 0 (length arguments)))
     (make-list-value
      class
      (for/list ([spec
                  (in-list
                   (value-signature-specs
                    (mirror-value-subject receiver)))]
                 [row-index (in-naturals)])
        (signature-spec->value
         class (mirror-value-subject receiver) spec row-index)))]
    [(invoke) (invoke-with-signature receiver arguments)]
    [(subject)
     (unless (null? arguments)
       (arity-error "Mirror subject" 0 (length arguments)))
     (mirror-value-subject receiver)]
    [else (unknown-message selector)]))

(define (bind-runtime-type-parameter! name actual bindings)
  (cond
    [(hash-has-key? bindings name)
     (same-runtime-type? (hash-ref bindings name) actual)]
    [else
     (hash-set! bindings name actual)
     #t]))

(define (runtime-named-type-matches? expected actual)
  (cond
    [(eq? expected '?) #t]
    [(and (eq? expected 'TypeData)
          (or (eq? actual 'Symbol)
              (and (runtime-list-type? actual)
                   (eq? (runtime-list-type-element-type actual)
                        'TypeData))))
     #t]
    [(symbol? actual) (eq? expected actual)]
    [(runtime-class-type? actual)
     (define class (runtime-class-type-class actual))
     (or (eq? expected (class-value-name class))
         (eq? expected (class-value-protocol class)))]
    [else #f]))

(define (runtime-type-matches-datum?
         expected actual type-parameters bindings)
  (cond
    [(symbol? expected)
     (if (memq expected type-parameters)
         (bind-runtime-type-parameter! expected actual bindings)
         (runtime-named-type-matches? expected actual))]
    [(and (list? expected) (pair? expected))
     (define name (car expected))
     (define arguments (cdr expected))
     (cond
       [(eq? name '->) (eq? actual 'Fn)]
       [(eq? name 'List)
        (and (= (length arguments) 1)
             (runtime-list-type? actual)
             (or (not (runtime-list-type-element-type actual))
                 (runtime-type-matches-datum?
                  (car arguments)
                  (runtime-list-type-element-type actual)
                  type-parameters
                  bindings)))]
       [(runtime-class-type? actual)
        (define class (runtime-class-type-class actual))
        (define actual-arguments
          (runtime-class-type-type-arguments actual))
        (and (eq? name (class-value-name class))
             (= (length arguments) (vector-length actual-arguments))
             (for/and ([expected-argument (in-list arguments)]
                       [actual-argument (in-vector actual-arguments)])
               (runtime-type-matches-datum?
                expected-argument
                actual-argument
                type-parameters
                bindings)))]
       [else #f])]
    [else #f]))

(define (invoke-with-signature mirror arguments)
  (unless (pair? arguments)
    (arity-error "Mirror invoke" "at least 1" (length arguments)))
  (define signature (car arguments))
  (unless (signature-value? signature)
    (error 'eval-aloe "Mirror invoke expects a Signature first"))
  (define subject (mirror-value-subject mirror))
  (unless
      (same-runtime-owner-type?
       (signature-value-owner-type signature)
       (runtime-owner-type subject))
    (error 'eval-aloe
           "Mirror invoke signature does not belong to the subject type"))
  (define invoke-arguments (cdr arguments))
  (define parameter-data (signature-value-parameter-data signature))
  (unless (= (length invoke-arguments) (length parameter-data))
    (arity-error
     (format "Mirror invoke ~a"
             (symbol-value-name (signature-value-selector signature)))
     (length parameter-data)
     (length invoke-arguments)))
  (define bindings (make-hasheq))
  (for ([argument (in-list invoke-arguments)]
        [expected (in-list parameter-data)]
        [position (in-naturals 1)])
    (unless
        (runtime-type-matches-datum?
         expected
         (runtime-type-of argument)
         (signature-value-type-parameters signature)
         bindings)
      (error 'eval-aloe
             "Mirror invoke argument ~a does not match ~a"
             position
             expected)))
  (define result
    (invoke-signature-row
     subject (signature-value-row-index signature) invoke-arguments))
  (unless
      (runtime-type-matches-datum?
       (signature-value-return-data signature)
       (runtime-type-of result)
       (signature-value-type-parameters signature)
       bindings)
    (error 'eval-aloe
           "Mirror invoke result does not match ~a"
           (signature-value-return-data signature)))
  result)

(define (invoke-signature-row subject row-index arguments)
  (define spec (list-ref (value-signature-specs subject) row-index))
  (define selector (signature-spec-selector spec))
  (cond
    [(instance-value? subject)
     (define class (instance-value-class subject))
     (define field-count (length (class-value-fields class)))
     (if (< row-index field-count)
         (vector-ref (instance-value-field-values subject) row-index)
         (apply-method
          subject
          class
          (list-ref (class-value-methods class)
                    (- row-index field-count))
          arguments))]
    [(list-value? subject)
     (if (< row-index 5)
         (send-to-list subject selector arguments)
         (apply-list-method
          subject
          (list-ref
           (list-class-object-methods (list-value-class subject))
           (- row-index 5))
          arguments))]
    [(class-value? subject) (construct-instance subject arguments)]
    [(list-class-object? subject)
     (send-to-list-class subject selector arguments)]
    [(symbol-class-object? subject)
     (send-to-symbol-class selector arguments)]
    [(mirror-class-object? subject)
     (send-to-mirror-class subject selector arguments)]
    [(function-value? subject)
     (send-to-function subject selector arguments)]
    [(exact-integer? subject)
     (send-to-int subject selector arguments)]
    [(flonum? subject)
     (send-to-float subject selector arguments)]
    [(boolean? subject)
     (send-to-bool subject selector arguments)]
    [(string? subject)
     (send-to-string subject selector arguments)]
    [(symbol-value? subject)
     (send-to-symbol subject selector arguments)]
    [(mirror-value? subject)
     (send-to-mirror subject selector arguments)]
    [(signature-value? subject)
     (send-to-signature subject selector arguments)]
    [else (unknown-message selector)]))

(define (send-to-signature receiver selector arguments)
  (unless (null? arguments)
    (arity-error (format "Signature ~a" selector) 0 (length arguments)))
  (case selector
    [(selector) (signature-value-selector receiver)]
    [(params) (signature-value-params receiver)]
    [(return) (signature-value-return receiver)]
    [else (unknown-message selector)]))

(define (send-to-symbol-class selector arguments)
  (unless (eq? selector 'intern)
    (unknown-message selector))
  (unless (= (length arguments) 1)
    (arity-error "Symbol intern" 1 (length arguments)))
  (define name (car arguments))
  (unless (string? name)
    (error 'eval-aloe "Symbol intern expects a String argument"))
  (intern-symbol name))

(define (send-to-symbol receiver selector arguments)
  (case selector
    [(name)
     (unless (null? arguments)
       (arity-error "Symbol name" 0 (length arguments)))
     (symbol-value-name receiver)]
    [(=)
     (unless (= (length arguments) 1)
       (arity-error "Symbol =" 1 (length arguments)))
     (define other (car arguments))
     (unless (symbol-value? other)
       (error 'eval-aloe "Symbol = expects a Symbol argument"))
     (eq? receiver other)]
    [else (unknown-message selector)]))

(define (send-to-list-class receiver selector arguments)
  (case selector
    [(of) (make-list-value receiver arguments)]
    [(empty)
     (unless (null? arguments)
       (arity-error "List empty" 0 (length arguments)))
     (make-list-value receiver '())]
    [else (unknown-message selector)]))

(define (make-list-value class elements)
  (define element-types (map runtime-type-of elements))
  (define element-type
    (cond
      [(null? element-types) #f]
      [(andmap (lambda (type)
                 (same-runtime-type? (car element-types) type))
               (cdr element-types))
       (car element-types)]
      [else
       (define protocols
         (for/list ([type (in-list element-types)])
           (and (runtime-class-type? type)
                (class-value-protocol
                 (runtime-class-type-class type)))))
       (and (car protocols)
            (andmap (lambda (protocol)
                      (eq? protocol (car protocols)))
                    (cdr protocols))
            (car protocols))]))
  (when (and (pair? elements) (not element-type))
    (error 'eval-aloe "List of elements must have one type"))
  (list-value class element-type (apply vector-immutable elements)))

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
    [(string? value) 'String]
    [(symbol-value? value) 'Symbol]
    [(mirror-value? value) 'Mirror]
    [(signature-value? value) 'Signature]
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
     (define selected
       (select-runtime-method
        (class-value-methods class)
        selector
        arguments
        (class-value-name class)
        (lambda (method)
          (instance-method-specificity
           instance class method arguments))))
     (apply-method
      instance class (runtime-method-match-method selected) arguments)]))

(define (select-runtime-method
         methods selector arguments target method-specificity)
  (define selector-methods
    (filter
     (lambda (method)
       (eq? selector (method-declaration-selector method)))
     methods))
  (unless (pair? selector-methods) (unknown-message selector))
  (define arity-methods
    (filter
     (lambda (method)
       (= (length (method-declaration-parameters method))
          (length arguments)))
     selector-methods))
  (unless (pair? arity-methods)
    (error 'eval-aloe
           "arity error for ~a method ~a: no overload accepts ~a argument(s)"
           target selector (length arguments)))
  (define matches
    (filter
     values
     (for/list ([method (in-list arity-methods)])
       (define specificity (method-specificity method))
       (and specificity
            (runtime-method-match method specificity)))))
  (unless (pair? matches) (unknown-message selector))
  (define best-specificity
    (apply max (map runtime-method-match-specificity matches)))
  (define best-matches
    (filter
     (lambda (candidate)
       (= (runtime-method-match-specificity candidate)
          best-specificity))
     matches))
  (unless (= (length best-matches) 1)
    (error 'eval-aloe "ambiguous message: ~a" selector))
  (car best-matches))

(define (instance-method-specificity receiver class method arguments)
  (define type-bindings
    (make-hasheq
     (map cons
          (class-value-type-parameters class)
          (vector->list (instance-value-type-arguments receiver)))))
  (method-arguments-specificity method arguments type-bindings))

(define (method-arguments-specificity method arguments bindings)
  (let loop ([parameters (method-declaration-parameters method)]
             [remaining-arguments arguments]
             [specificity 0])
    (cond
      [(null? parameters) specificity]
      [else
       (define next-specificity
         (runtime-type-specificity
          (parameter-declaration-type (car parameters))
          (runtime-type-of (car remaining-arguments))
          bindings
          (method-declaration-type-parameters method)))
       (and next-specificity
            (loop (cdr parameters)
                  (cdr remaining-arguments)
                  (+ specificity next-specificity)))])))

(define (runtime-type-specificity
         declared actual bindings method-type-parameters)
  (cond
    [(symbol? declared)
     (cond
       [(memq declared method-type-parameters)
        (cond
          [(hash-has-key? bindings declared)
           (and (same-runtime-type? (hash-ref bindings declared) actual)
                0)]
          [else
           (hash-set! bindings declared actual)
           0])]
       [(hash-has-key? bindings declared)
        (define expected (hash-ref bindings declared))
        (cond
          [(not expected)
           (hash-set! bindings declared actual)
           0]
          [(same-runtime-type? expected actual) 2]
          [else #f])]
       [(runtime-class-type? actual)
        (define actual-class (runtime-class-type-class actual))
        (cond
          [(eq? declared (class-value-name actual-class)) 2]
          [(eq? declared (class-value-protocol actual-class)) 1]
          [else #f])]
       [(eq? declared actual) 2]
       [else #f])]
    [(and (list? declared) (pair? declared))
     (define name (car declared))
     (cond
       [(eq? name '->)
        (and (eq? actual 'Fn) 2)]
       [(eq? name 'List)
        (and (= (length declared) 2)
             (runtime-list-type? actual)
             (or (not (runtime-list-type-element-type actual))
                 (runtime-type-specificity
                  (cadr declared)
                  (runtime-list-type-element-type actual)
                  bindings
                  method-type-parameters))
             2)]
       [(runtime-class-type? actual)
        (define actual-class (runtime-class-type-class actual))
        (define actual-arguments
          (runtime-class-type-type-arguments actual))
        (and (eq? name (class-value-name actual-class))
             (or
              ;; Preserve the accepted checkpoint 3–4 spelling (Point Int)
              ;; for the original non-generic Point class.
              (zero? (vector-length actual-arguments))
              (and
               (= (length (cdr declared))
                  (vector-length actual-arguments))
               (for/and ([nested-declared (in-list (cdr declared))]
                         [nested-actual (in-vector actual-arguments)])
                 (runtime-type-specificity
                  nested-declared
                  nested-actual
                  bindings
                  method-type-parameters))))
             2)]
       [else #f])]
    [else #f]))

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
     (make-list-value
      (list-value-class list-object)
      (cdr (vector->list elements)))]
    [(cons)
     (unless (= (length arguments) 1)
       (arity-error "List cons" 1 (length arguments)))
     (make-list-value
      (list-value-class list-object)
      (cons (car arguments) (vector->list elements)))]
    [(len)
     (unless (null? arguments)
       (arity-error "List len" 0 (length arguments)))
     (vector-length elements)]
    [else
     (send-to-list-method list-object selector arguments)]))

(define (send-to-list-method receiver selector arguments)
  (define class (list-value-class receiver))
  (define type-bindings
    (make-hasheq
     (list (cons 'T (list-value-element-type receiver)))))
  (define selected
    (select-runtime-method
     (list-class-object-methods class)
     selector
     arguments
     'List
     (lambda (method)
       (method-arguments-specificity
        method arguments (hash-copy type-bindings)))))
  (define method (runtime-method-match-method selected))
  (apply-list-method receiver method arguments))

(define (apply-list-method receiver method arguments)
  (define class (list-value-class receiver))
  (define parameters (method-declaration-parameters method))
  (unless (= (length parameters) (length arguments))
    (arity-error
     (format "List method ~a" (method-declaration-selector method))
     (length parameters)
     (length arguments)))
  (define bindings
    (cons (cons 'self receiver)
          (for/list ([parameter (in-list parameters)]
                     [argument (in-list arguments)])
            (cons (parameter-declaration-name parameter) argument))))
  (eval-expr
   (method-declaration-body method)
   (make-local-env (list-class-object-environment class) bindings)))

(define (send-to-int receiver selector arguments)
  (cond
    [(eq? selector 'float)
     (unless (null? arguments)
       (arity-error "Int float" 0 (length arguments)))
     (exact->inexact receiver)]
    [(eq? selector 'text)
     (unless (null? arguments)
       (arity-error "Int text" 0 (length arguments)))
     (number->string receiver)]
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

(define (send-to-string receiver selector arguments)
  (case selector
    [(=)
     (unless (= (length arguments) 1)
       (arity-error "String =" 1 (length arguments)))
     (define argument (car arguments))
     (unless (string? argument)
       (error 'eval-aloe "String = expects a String argument"))
     (string=? receiver argument)]
    [(append)
     (unless (= (length arguments) 1)
       (arity-error "String append" 1 (length arguments)))
     (define argument (car arguments))
     (unless (string? argument)
       (error 'eval-aloe "String append expects a String argument"))
     (string-append receiver argument)]
    [else (unknown-message selector)]))

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
    [(string? value) (format "~s" value)]
    [(symbol-value? value)
     (format "#<Symbol ~a>" (symbol-value-name value))]
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
     (define state (host-receiver-state value))
     (format "#<~a~a>"
             (host-receiver-name value)
             (if (string? state)
                 (format " ~s" state)
                 ""))]
    [(list-class-object? value) "#<class List>"]
    [(void? value) "#<void>"]
    [else "#<object>"]))

(define (instance-has-zero-argument-method? value selector)
  (and
   (instance-value? value)
   (for/or ([method
             (in-list
              (class-value-methods (instance-value-class value)))])
     (and (eq? selector (method-declaration-selector method))
          (null? (method-declaration-parameters method))))))

(define (aloe-value->display-string value)
  (cond
    [(instance-has-zero-argument-method? value 'show)
     (define shown (lookup-message value 'show '()))
     (unless (string? shown)
       (error 'eval-aloe "show must return a String"))
     shown]
    [else (aloe-value->string value)]))

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
          (value-vectors-equal? (instance-value-field-values left)
                                (instance-value-field-values right)))]
    [(and (list-value? left) (list-value? right))
     (and (eq? (list-value-class left) (list-value-class right))
          (value-vectors-equal? (list-value-elements left)
                                (list-value-elements right)))]
    [(and (host-receiver? left) (host-receiver? right))
     (and (eq? (host-receiver-name left) (host-receiver-name right))
          (aloe-values-equal? (host-receiver-state left)
                              (host-receiver-state right)))]
    [(and (void? left) (void? right)) #t]
    [else (eq? left right)]))
