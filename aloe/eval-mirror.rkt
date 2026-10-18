#lang racket/base

;; Reflection: sends to the Mirror class, Mirror values, and Signature values,
;; and the signature rows they read.
(require racket/list
         "env.rkt"
         "eval-value.rkt"
         "host.rkt"
         "mirror.rkt"
         "parse.rkt"
         "signature-catalog.rkt"
         "signature.rkt"
         "symbol.rkt")

(provide send-to-mirror-class
         value-signature-specs
         make-reflection-sends)

(struct runtime-class-object-type (class) #:transparent)

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
   (field-declarations->signature-specs
    (class-value-fields class)
    substitution)
   (method-declarations->signature-specs
    (class-value-methods class)
    substitution)))

(define (class-instance-type-datum class)
  (define parameters (class-value-type-parameters class))
  (if (null? parameters)
      (class-value-name class)
      (cons (class-value-name class) parameters)))

(define (class-signature-specs class)
  (constructor-declarations->signature-specs
   (class-value-constructors class)
   (class-instance-type-datum class)))

(define (list-signature-specs value)
  (define element-type
    (if (list-value-element-type value)
        (runtime-type->datum (list-value-element-type value))
        'T))
  (define substitution (make-hasheq (list (cons 'T element-type))))
  (append
   (substitute-signature-specs
    (kernel-instance-signature-specs 'List)
    substitution)
   (method-declarations->signature-specs
    (list-class-object-methods (list-value-class value))
    substitution)))

(define (value-signature-specs value [environment #f])
  (cond
    [(exact-integer? value)
     (append
      (kernel-instance-signature-specs 'Int)
      (let ([class (int-class-for environment)])
        (if class
            (method-declarations->signature-specs
             (int-class-object-methods class)
             (make-hasheq))
            '())))]
    [(flonum? value)
     (kernel-instance-signature-specs 'Float)]
    [(boolean? value)
     (kernel-instance-signature-specs 'Bool)]
    [(string? value)
     (append
      (kernel-instance-signature-specs 'String)
      (let ([class (string-class-for environment)])
        (if class
            (method-declarations->signature-specs
             (string-class-object-methods class)
             (make-hasheq))
            '())))]
    [(symbol-value? value)
     (kernel-instance-signature-specs 'Symbol)]
    [(host-receiver? value)
     (host-method-declarations->signature-specs
      (host-interface-methods
       (host-receiver-interface value)))]
    [(function-value? value)
     (list
      (make-call-signature-spec
       (make-list (length (function-value-parameters value)) 'T)
       'U))]
    [(list-value? value) (list-signature-specs value)]
    [(instance-value? value) (instance-signature-specs value)]
    [(class-value? value) (class-signature-specs value)]
    [(list-class-object? value)
     (kernel-class-object-signature-specs 'List)]
    [(string-class-object? value)
     (kernel-class-object-signature-specs 'String)]
    [(int-class-object? value) '()]
    [(symbol-class-object? value)
     (kernel-class-object-signature-specs 'Symbol)]
    [(mirror-class-object? value)
     (kernel-class-object-signature-specs 'Mirror)]
    [(mirror-value? value)
     (kernel-instance-signature-specs 'Mirror)]
    [(signature-value? value)
     (kernel-instance-signature-specs 'Signature)]
    [else '()]))

(define (value-selector-names value [environment #f])
  (remove-duplicates
   (map signature-spec-selector
        (value-signature-specs value environment))
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

(define (signature-type-parameters subject row-index [environment #f])
  (cond
    [(instance-value? subject)
     (define class (instance-value-class subject))
     (define method-index
       (- row-index
          (length
           (field-declarations->signature-specs
            (class-value-fields class)))))
     (if (negative? method-index)
         '()
         (method-declaration-type-parameters
          (list-ref (class-value-methods class) method-index)))]
    [(list-value? subject)
     (define method-index
       (- row-index (kernel-instance-signature-count 'List)))
     (if (negative? method-index)
         '()
         (method-declaration-type-parameters
          (list-ref
           (list-class-object-methods (list-value-class subject))
           method-index)))]
    [(string? subject)
     (define method-index
       (- row-index (kernel-instance-signature-count 'String)))
     (define class (string-class-for environment))
     (if (or (negative? method-index) (not class))
         '()
         (method-declaration-type-parameters
          (list-ref (string-class-object-methods class) method-index)))]
    [(exact-integer? subject)
     (define method-index
       (- row-index (kernel-instance-signature-count 'Int)))
     (define class (int-class-for environment))
     (if (or (negative? method-index) (not class))
         '()
         (method-declaration-type-parameters
          (list-ref (int-class-object-methods class) method-index)))]
    [(class-value? subject) (class-value-type-parameters subject)]
    [(boolean? subject) '(T)]
    [(function-value? subject) '(T U)]
    [(list-class-object? subject) '(T)]
    [(mirror-class-object? subject) '(T)]
    [(and (mirror-value? subject) (memv row-index '(2 3))) '(U)]
    [else '()]))

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
         (eq? expected (class-value-protocol-name class)))]
    [else #f]))

;; eval.rkt requires this module, so this module cannot require eval.rkt.
;; These sends call four evaluator procedures; eval.rkt passes them in once
;; and binds the two sends this returns.
(define (make-reflection-sends make-list-value
                               runtime-type-of
                               same-runtime-type?
                               invoke-signature-row)
  (define (runtime-owner-type value)
    (cond
      [(class-value? value) (runtime-class-object-type value)]
      [(list-class-object? value) 'ListClass]
      [(symbol-class-object? value) 'SymbolClass]
      [(mirror-class-object? value) 'MirrorClass]
      [(host-receiver? value) (host-receiver-interface value)]
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

  (define (signature-spec->value class subject spec row-index environment)
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
     (signature-type-parameters subject row-index environment)))

  (define (send-to-mirror receiver selector arguments [environment #f])
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
                   (mirror-value-subject receiver)
                   environment))))]
      [(signatures)
       (unless (null? arguments)
         (arity-error "Mirror signatures" 0 (length arguments)))
       (make-list-value
        class
        (for/list ([spec
                    (in-list
                     (value-signature-specs
                      (mirror-value-subject receiver)
                      environment))]
                   [row-index (in-naturals)])
          (signature-spec->value
           class (mirror-value-subject receiver) spec row-index environment)))]
      [(invoke) (invoke-with-signature receiver arguments environment)]
      [(subject)
       (unless (null? arguments)
         (arity-error "Mirror subject" 0 (length arguments)))
       (mirror-value-subject receiver)]
      [(raw)
       (unless (null? arguments)
         (arity-error "Mirror raw" 0 (length arguments)))
       (aloe-value->string (mirror-value-subject receiver))]
      [else (unknown-message selector)]))

  (define (bind-runtime-type-parameter! name actual bindings)
    (cond
      [(hash-has-key? bindings name)
       (same-runtime-type? (hash-ref bindings name) actual)]
      [else
       (hash-set! bindings name actual)
       #t]))

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

  (define (invoke-with-signature mirror arguments environment)
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
       subject
       (signature-value-row-index signature)
       invoke-arguments
       environment))
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

  (define (send-to-signature receiver selector arguments)
    (case selector
      [(selector params return)
       (unless (null? arguments)
         (arity-error (format "Signature ~a" selector) 0 (length arguments)))
       (case selector
         [(selector) (signature-value-selector receiver)]
         [(params) (signature-value-params receiver)]
         [(return) (signature-value-return receiver)])]
      [(accepts?)
       (unless (= (length arguments) 1)
         (arity-error "Signature accepts?" 1 (length arguments)))
       (define mirror (car arguments))
       (unless (mirror-value? mirror)
         (error 'eval-aloe "Signature accepts? expects a Mirror argument"))
       (define parameters (signature-value-parameter-data receiver))
       (and (= (length parameters) 1)
            (runtime-type-matches-datum?
             (car parameters)
             (runtime-type-of (mirror-value-subject mirror))
             (signature-value-type-parameters receiver)
             (make-hasheq)))]
      [else (unknown-message selector)]))
  (values send-to-mirror send-to-signature))
