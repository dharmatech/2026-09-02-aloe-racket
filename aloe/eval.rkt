#lang racket/base

;; The evaluator's hot path: eval-expr and the forms it evaluates, message
;; lookup, every kernel send table, List construction, runtime types, and
;; method selection and application. Racket CS inlines within this module only
;; while its body compiles whole; tests/checkpoint-118.rkt checks that at a
;; limit of 8,000 terms. Cold code is in eval-value.rkt, eval-load.rkt, and
;; eval-mirror.rkt.
(require racket/match
         "env.rkt"
         "eval-load.rkt"
         "eval-mirror.rkt"
         "eval-value.rkt"
         "host.rkt"
         (only-in (submod "host.rkt" evaluator-exact-host-method)
                  host-receiver-invoke-method)
         "mirror.rkt"
         "parse.rkt"
         "signature-catalog.rkt"
         "signature.rkt"
         "symbol.rkt")

(provide eval-expr
         eval-exprs
         eval-keyed-root
         record-evaluated-libraries!
         record-evaluated-option-class!
         aloe-value->string
         aloe-value->display-string
         instance-value?
         instance-value-constructor)

(struct runtime-method-match (method specificity) #:transparent)

;; The loader is the environment the load form is evaluated in.
(define (eval-load! expression environment)
  (define path (load-expr-resolved-path expression))
  (unless (file-exists? path)
    (error 'eval-aloe "load file not found: ~a" path))
  (eval-once!
   environment
   path
   (lambda ()
     (call-with-input-file path
       (lambda (input)
         (read-program input #:source-path path))))
   (lambda (expressions file-environment)
     (parameterize
         ([current-eval-load-paths
           (cons path (current-eval-load-paths))])
       (eval-exprs expressions file-environment))))
  (void))

(define (eval-expr expression environment)
  (match expression
    [(int-expr value _) value]
    [(float-expr value _) value]
    [(bool-expr value _) value]
    [(string-expr value _) value]
    [(variable-expr name _)
     (env-lookup environment name)]
    [(? load-expr?)
     (eval-load! expression environment)]
    [(check-expr left right left-datum right-datum _)
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
    [(define-expr name value-expression _)
     (define value (eval-expr value-expression environment))
     (env-define! environment name value)]
    [(define-protocol-expr name _ _)
     (env-define! environment name (protocol-value name environment))]
    [(define-class-expr name type-parameters protocol fields constructors methods _ _)
     (define class-protocol
       (and protocol (lookup-protocol environment protocol)))
     (define class-fields (or fields '()))
     (define class-constructors
       (or constructors
           (list (constructor-declaration 'new class-fields))))
     (define method-environments (make-hasheq))
     (record-method-environments! method-environments methods environment)
     (env-define! environment
                  name
                  (class-value
                   name
                   type-parameters
                   class-protocol
                   class-fields
                   class-constructors
                   (and constructors #t)
                   methods
                   environment
                   method-environments))]
    [(define-methods-expr target methods _ _)
     (define target-class (env-lookup environment target))
     (define method-environments
       (cond
         [(list-class-object? target-class)
          (set-list-class-object-methods!
           target-class
           (append (list-class-object-methods target-class) methods))
          (list-class-object-method-environments target-class)]
         [(string-class-object? target-class)
          (set-string-class-object-methods!
           target-class
           (append (string-class-object-methods target-class) methods))
          (string-class-object-method-environments target-class)]
         [(int-class-object? target-class)
          (set-int-class-object-methods!
           target-class
           (append (int-class-object-methods target-class) methods))
          (int-class-object-method-environments target-class)]
         [(class-value? target-class)
          (set-class-value-methods!
           target-class
           (append (class-value-methods target-class) methods))
          (class-value-method-environments target-class)]
         [else
          (error 'eval-aloe
                 "define-methods target is not a class: ~a"
                 target)]))
     ;; The appended methods run where this form is evaluated; earlier
     ;; methods keep the environment that wrote them.
     (record-method-environments! method-environments methods environment)]
    [(fn-expr parameters body _)
     (function-value parameters body environment)]
    [(case-expr scrutinee clauses else-body _)
     (eval-case scrutinee clauses else-body environment)]
    [(new-star-expr receiver bindings _)
     (eval-new-star receiver bindings environment)]
    [(with-expr receiver bindings _)
     (eval-with receiver bindings environment)]
    [(send-expr receiver-expression selector argument-expressions _ _)
     (define receiver (eval-expr receiver-expression environment))
     (define arguments
       (for/list ([argument-expression (in-list argument-expressions)])
         (eval-expr argument-expression environment)))
     (lookup-message receiver selector arguments environment)]))

(define (lookup-protocol environment name)
  (define protocol (env-lookup environment name))
  (unless (protocol-value? protocol)
    (error 'eval-aloe "~a is not a protocol" name))
  protocol)

;; A class record's table maps each method declaration, by eq?, to the
;; environment that wrote it. Library declarations are parsed once and shared
;; by every base, so the table lives on each base's record.
(define (record-method-environments! method-environments methods environment)
  (for ([method (in-list methods)])
    (hash-set! method-environments method environment)))

(define (recorded-method-environment method-environments method)
  (hash-ref method-environments
            method
            (lambda ()
              (error 'eval-aloe
                     "internal error: no recorded environment for method ~a"
                     (method-declaration-selector method)))))

(define (eval-case scrutinee-expression clauses else-body environment)
  (define scrutinee (eval-expr scrutinee-expression environment))
  (unless (instance-value? scrutinee)
    (error 'eval-aloe "case scrutinee is not an instance"))
  (define constructor (instance-value-constructor scrutinee))
  (define matching-clause
    (for/first ([clause (in-list clauses)]
                #:when (eq? constructor (case-clause-selector clause)))
      clause))
  (cond
    [matching-clause
     (define payload-names
       (case-clause-payload-names matching-clause))
     (define payload (instance-value-field-values scrutinee))
     (define expected-arity (vector-length payload))
     (define actual-arity (length payload-names))
     (unless (= expected-arity actual-arity)
       (error 'eval-aloe
              "arity error for case constructor ~a: expected ~a payload name(s), got ~a"
              constructor
              expected-arity
              actual-arity))
     (eval-expr
      (case-clause-body matching-clause)
      (make-local-env
       environment
       (map cons payload-names (vector->list payload))))]
    [else-body (eval-expr else-body environment)]
    [else
     (error 'eval-aloe
            "no matching case clause for constructor ~a"
            constructor)]))

(define (aloe-value->host-argument value)
  (if (list-value? value)
      (vector->list (list-value-elements value))
      value))

(define (host-result->aloe-value value environment)
  (cond
    [(list? value)
     (unless environment
       (error 'eval-aloe
              "cannot construct a host List result outside evaluation"))
     (make-list-value (env-lookup environment 'List) value 'String)]
    [else value]))

(define (lookup-message receiver selector arguments [environment #f])
  (cond
    [(list-class-object? receiver)
     (send-to-list-class receiver selector arguments)]
    [(symbol-class-object? receiver)
     (send-to-symbol-class selector arguments)]
    [(mirror-class-object? receiver)
     (send-to-mirror-class receiver selector arguments)]
    [(class-value? receiver)
     (construct-instance receiver selector arguments)]
    [(instance-value? receiver)
     (send-to-instance receiver selector arguments)]
    [(function-value? receiver)
     (send-to-function receiver selector arguments)]
    [(list-value? receiver)
     (send-to-list receiver selector arguments)]
    [(host-receiver? receiver)
     (host-result->aloe-value
      (host-receiver-send
       receiver selector (map aloe-value->host-argument arguments))
      environment)]
    [(exact-integer? receiver)
     (send-to-int receiver selector arguments environment)]
    [(flonum? receiver)
     (send-to-float receiver selector arguments)]
    [(boolean? receiver)
     (send-to-bool receiver selector arguments)]
    [(string? receiver)
     (send-to-string receiver selector arguments environment)]
    [(symbol-value? receiver)
     (send-to-symbol receiver selector arguments)]
    [(mirror-value? receiver)
     (send-to-mirror receiver selector arguments environment)]
    [(signature-value? receiver)
     (send-to-signature receiver selector arguments)]
    [else
     (unknown-message selector)]))

(define (invoke-signature-row subject row-index arguments environment)
  (define spec
    (list-ref (value-signature-specs subject environment) row-index))
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
     (define kernel-count (kernel-instance-signature-count 'List))
     (if (< row-index kernel-count)
         (send-to-list subject selector arguments)
         (apply-list-method
          subject
          (list-ref
           (list-class-object-methods (list-value-class subject))
           (- row-index kernel-count))
          arguments))]
    [(class-value? subject) (construct-instance subject selector arguments)]
    [(list-class-object? subject)
     (send-to-list-class subject selector arguments)]
    [(symbol-class-object? subject)
     (send-to-symbol-class selector arguments)]
    [(mirror-class-object? subject)
     (send-to-mirror-class subject selector arguments)]
    [(function-value? subject)
     (send-to-function subject selector arguments)]
    [(exact-integer? subject)
     (define kernel-count (kernel-instance-signature-count 'Int))
     (if (< row-index kernel-count)
         (send-to-int subject selector arguments environment)
         (let ([class (int-class-for environment)])
           (unless class (unknown-message selector))
           (apply-int-method
            subject
            class
            (list-ref
             (int-class-object-methods class)
             (- row-index kernel-count))
            arguments)))]
    [(flonum? subject)
     (send-to-float subject selector arguments)]
    [(boolean? subject)
     (send-to-bool subject selector arguments)]
    [(string? subject)
     (define kernel-count (kernel-instance-signature-count 'String))
     (if (< row-index kernel-count)
         (send-to-string subject selector arguments environment)
         (let ([class (string-class-for environment)])
           (unless class (unknown-message selector))
           (apply-string-method
            subject
            class
            (list-ref
             (string-class-object-methods class)
             (- row-index kernel-count))
            arguments)))]
    [(symbol-value? subject)
     (send-to-symbol subject selector arguments)]
    [(host-receiver? subject)
     (define method
       (list-ref
        (host-interface-methods (host-receiver-interface subject))
        row-index))
     (host-result->aloe-value
      (host-receiver-invoke-method
       subject method (map aloe-value->host-argument arguments))
      environment)]
    [(mirror-value? subject)
     (send-to-mirror subject selector arguments environment)]
    [(signature-value? subject)
     (send-to-signature subject selector arguments)]
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

(define (make-list-value class elements [empty-element-type #f])
  (define element-types (map runtime-type-of elements))
  (define element-type
    (cond
      [(null? element-types) empty-element-type]
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
            (protocol-value-name (car protocols)))]))
  (when (and (pair? elements) (not element-type))
    (error 'eval-aloe "List of elements must have one type"))
  (list-value class element-type (apply vector-immutable elements)))

(define (find-constructor class selector)
  (for/first ([constructor (in-list (class-value-constructors class))]
              #:when
              (eq? selector
                   (constructor-declaration-selector constructor)))
    constructor))

(define (eval-new-star receiver-expression bindings environment)
  (define receiver (eval-expr receiver-expression environment))
  (unless (and (class-value? receiver)
               (not (class-value-explicit-constructors? receiver)))
    (error 'eval-aloe
           "ineligible new*: receiver must be a class declared with fields"))
  (define constructor (find-constructor receiver 'new))
  (unless constructor
    (error 'eval-aloe "ineligible new*: class has no generated new constructor"))
  (define fields (constructor-declaration-fields constructor))
  (define indices
    (for/hasheq ([field (in-list fields)] [index (in-naturals)])
      (values (field-declaration-name field) index)))
  (define seen (make-hasheq))
  (for ([binding (in-list bindings)])
    (define name (construction-binding-name binding))
    (unless (hash-has-key? indices name)
      (error 'eval-aloe "unknown field ~a for new*" name))
    (when (hash-has-key? seen name)
      (error 'eval-aloe "duplicate field ~a for new*" name))
    (hash-set! seen name #t))
  (define missing
    (for/list ([field (in-list fields)]
               #:unless (hash-has-key? seen (field-declaration-name field)))
      (field-declaration-name field)))
  (unless (null? missing)
    (error 'eval-aloe "missing fields for new*: ~a" missing))
  ;; Validate the complete name set before running any value effects, then
  ;; record source-order results at their declaration indices.
  (define arguments (make-vector (length fields)))
  (for ([binding (in-list bindings)])
    (vector-set! arguments
                 (hash-ref indices (construction-binding-name binding))
                 (eval-expr (construction-binding-value binding) environment)))
  (construct-instance receiver 'new (vector->list arguments)))

(define (eval-with receiver-expression bindings environment)
  (define receiver (eval-expr receiver-expression environment))
  (define class (and (instance-value? receiver) (instance-value-class receiver)))
  (unless (and (class-value? class)
               (not (class-value-explicit-constructors? class)))
    (error 'eval-aloe
           "ineligible with: receiver must be an instance of a class declared with fields"))
  (define constructor (find-constructor class 'new))
  (unless constructor
    (error 'eval-aloe "ineligible with: class has no generated new constructor"))
  (define fields (constructor-declaration-fields constructor))
  (define declared
    (for/hasheq ([field (in-list fields)])
      (values (field-declaration-name field) #t)))
  (define seen (make-hasheq))
  (for ([binding (in-list bindings)])
    (define name (construction-binding-name binding))
    (unless (hash-has-key? declared name)
      (error 'eval-aloe "unknown field ~a for with" name))
    (when (hash-has-key? seen name)
      (error 'eval-aloe "duplicate field ~a for with" name))
    (hash-set! seen name #t))
  ;; Validate every name before running any value effects. Values run in
  ;; source order against the original receiver; unwritten slots copy the
  ;; receiver's stored payload.
  (define results
    (for/hasheq ([binding (in-list bindings)])
      (values (construction-binding-name binding)
              (eval-expr (construction-binding-value binding) environment))))
  (construct-instance
   class
   'new
   (for/list ([field (in-list fields)]
              [stored (in-vector (instance-value-field-values receiver))])
     (hash-ref results (field-declaration-name field) (lambda () stored)))))

(define (construct-instance class selector arguments)
  (define constructor (find-constructor class selector))
  (unless constructor (unknown-message selector))
  (define fields (constructor-declaration-fields constructor))
  (define expected-arity (length fields))
  (define actual-arity (length arguments))
  (unless (= expected-arity actual-arity)
    (error 'eval-aloe
           "arity error for ~a: expected ~a argument(s), got ~a"
           selector
           expected-arity
           actual-arity))
  (instance-value class
                  (infer-class-type-arguments class fields arguments)
                  selector
                  (apply vector-immutable arguments)))

(define (infer-class-type-arguments class fields arguments)
  (define inferred (make-hasheq))
  (for ([field (in-list fields)]
        [argument (in-list arguments)])
    (infer-type-expression! class
                            (field-declaration-type field)
                            (runtime-type-of argument)
                            inferred))
  (apply vector-immutable
         (for/list ([parameter
                     (in-list (class-value-type-parameters class))])
           (hash-ref inferred parameter #f))))

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
    [(or (class-value? value)
         (list-class-object? value)
         (int-class-object? value)
         (string-class-object? value))
     'Class]
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
        (lambda (method resolve-environment)
          (instance-method-specificity
           instance class method arguments resolve-environment))
        (class-value-method-environments class)))
     (apply-method
      instance class (runtime-method-match-method selected) arguments)]))

(define (select-runtime-method
         methods selector arguments target method-specificity
         method-environments)
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
  ;; A single candidate compares short names. With more than one, each
  ;; candidate's parameter annotations resolve in its recorded environment.
  (define several? (pair? (cdr arity-methods)))
  (define matches
    (filter
     values
     (for/list ([method (in-list arity-methods)])
       (define resolve-environment
         (and several?
              (recorded-method-environment method-environments method)))
       (define specificity (method-specificity method resolve-environment))
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

(define (instance-method-specificity
         receiver class method arguments environment)
  (define type-bindings
    (make-hasheq
     (map cons
          (class-value-type-parameters class)
          (vector->list (instance-value-type-arguments receiver)))))
  (method-arguments-specificity method arguments type-bindings environment))

(define (method-arguments-specificity method arguments bindings environment)
  (define type-specificity
    (if environment
        (lambda (declared actual bindings method-type-parameters)
          (resolved-type-specificity
           declared actual bindings method-type-parameters environment))
        runtime-type-specificity))
  (let loop ([parameters (method-declaration-parameters method)]
             [remaining-arguments arguments]
             [specificity 0])
    (cond
      [(null? parameters) specificity]
      [else
       (define next-specificity
         (type-specificity
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
          [(eq? declared (class-value-protocol-name actual-class)) 1]
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
        (and (eq? name (class-value-name actual-class))
             (runtime-type-arguments-match?
              (cdr declared) actual bindings method-type-parameters)
             2)]
       [else #f])]
    [else #f]))

(define (runtime-type-arguments-match?
         declared-arguments actual bindings method-type-parameters)
  (define actual-arguments (runtime-class-type-type-arguments actual))
  (or
   ;; Preserve the accepted checkpoint 3–4 spelling (Point Int)
   ;; for the original non-generic Point class.
   (zero? (vector-length actual-arguments))
   (and
    (= (length declared-arguments)
       (vector-length actual-arguments))
    (for/and ([nested-declared (in-list declared-arguments)]
              [nested-actual (in-vector actual-arguments)])
      (runtime-type-specificity
       nested-declared
       nested-actual
       bindings
       method-type-parameters)))))

;; An annotation that names a class or a protocol in the environment matches
;; by record: the class itself (2), or a class that opted into the protocol
;; (1). Type parameters and every other annotation compare as above.
(define (resolved-type-specificity
         declared actual bindings method-type-parameters environment)
  (define (named-record name)
    (and (not (memq name method-type-parameters))
         (not (hash-has-key? bindings name))
         (env-bound? environment name)
         (let ([value (env-lookup environment name)])
           (and (or (class-value? value) (protocol-value? value))
                value))))
  (define record
    (cond
      [(symbol? declared) (named-record declared)]
      [(and (list? declared) (pair? declared) (symbol? (car declared)))
       (define head (named-record (car declared)))
       (and (class-value? head) head)]
      [else #f]))
  (define actual-class
    (and (runtime-class-type? actual) (runtime-class-type-class actual)))
  (cond
    [(not record)
     (runtime-type-specificity
      declared actual bindings method-type-parameters)]
    [(not actual-class) #f]
    [(protocol-value? record)
     (and (eq? (class-value-protocol actual-class) record) 1)]
    [(symbol? declared)
     (and (eq? actual-class record) 2)]
    [else
     (and (eq? actual-class record)
          (runtime-type-arguments-match?
           (cdr declared) actual bindings method-type-parameters)
          2)]))

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
             (make-local-env
              (recorded-method-environment
               (class-value-method-environments class) method)
              bindings)))

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
      (cdr (vector->list elements))
      (list-value-element-type list-object))]
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
     (lambda (method resolve-environment)
       (method-arguments-specificity
        method arguments (hash-copy type-bindings) resolve-environment))
     (list-class-object-method-environments class)))
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
   (make-local-env
    (recorded-method-environment
     (list-class-object-method-environments class) method)
    bindings)))

(define (send-to-int receiver selector arguments [environment #f])
  (cond
    [(eq? selector 'float)
     (unless (null? arguments)
       (arity-error "Int float" 0 (length arguments)))
     (exact->inexact receiver)]
    [(eq? selector 'text)
     (unless (null? arguments)
       (arity-error "Int text" 0 (length arguments)))
     (number->string receiver)]
    [(memq selector '(+ - * / < > <= >= =))
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
         [(=) =]))
     (operation receiver
                (number-argument
                 "Int" selector arguments exact-integer?))]
    [else (send-to-int-method receiver selector arguments environment)]))

(define (send-to-int-method receiver selector arguments environment)
  (define class (int-class-for environment))
  (unless class (unknown-message selector))
  (define selected
    (select-runtime-method
     (int-class-object-methods class)
     selector
     arguments
     'Int
     (lambda (method resolve-environment)
       (method-arguments-specificity
        method arguments (make-hasheq) resolve-environment))
     (int-class-object-method-environments class)))
  (apply-int-method
   receiver class (runtime-method-match-method selected) arguments))

(define (apply-int-method receiver class method arguments)
  (define parameters (method-declaration-parameters method))
  (unless (= (length parameters) (length arguments))
    (arity-error
     (format "Int method ~a" (method-declaration-selector method))
     (length parameters)
     (length arguments)))
  (define bindings
    (cons (cons 'self receiver)
          (for/list ([parameter (in-list parameters)]
                     [argument (in-list arguments)])
            (cons (parameter-declaration-name parameter) argument))))
  (eval-expr
   (method-declaration-body method)
   (make-local-env
    (recorded-method-environment
     (int-class-object-method-environments class) method)
    bindings)))

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

(define (send-to-string receiver selector arguments [environment #f])
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
    [(len)
     (unless (null? arguments)
       (arity-error "String len" 0 (length arguments)))
     (string-length receiver)]
    [(take)
     (unless (= (length arguments) 1)
       (arity-error "String take" 1 (length arguments)))
     (define argument (car arguments))
     (unless (exact-integer? argument)
       (error 'eval-aloe "String take expects an Int argument"))
     (substring receiver
                0
                (min (max argument 0) (string-length receiver)))]
    [(drop)
     (unless (= (length arguments) 1)
       (arity-error "String drop" 1 (length arguments)))
     (define argument (car arguments))
     (unless (exact-integer? argument)
       (error 'eval-aloe "String drop expects an Int argument"))
     (substring receiver
                (min (max argument 0) (string-length receiver)))]
    [(split-lines)
     (unless (null? arguments)
       (arity-error "String split-lines" 0 (length arguments)))
     (define-values (piece-start reversed-pieces)
       (for/fold ([piece-start 0] [reversed-pieces '()])
                 ([index (in-range (string-length receiver))])
         (if (char=? (string-ref receiver index) #\newline)
             (values (add1 index)
                     (cons (substring receiver piece-start index)
                           reversed-pieces))
             (values piece-start reversed-pieces))))
     (make-list-value
      (env-lookup environment 'List)
      (reverse
       (cons (substring receiver piece-start (string-length receiver))
             reversed-pieces)))]
    [(joined-with)
     (unless (= (length arguments) 3)
       (arity-error "String joined-with" 3 (length arguments)))
     (define above (car arguments))
     (define current (cadr arguments))
     (define below (caddr arguments))
     (define (string-list-elements value)
       (unless (and (list-value? value)
                    (let ([element-type (list-value-element-type value)])
                      (or (not element-type) (eq? element-type 'String)))
                    (for/and ([element (in-vector (list-value-elements value))])
                      (string? element)))
         (error 'eval-aloe
                "String joined-with expects (List String) arguments"))
       (list-value-elements value))
     (define above-elements (string-list-elements above))
     (unless (string? current)
       (error 'eval-aloe "String joined-with expects a String current"))
     (define below-elements (string-list-elements below))
     (define piece-count
       (+ (vector-length above-elements) 1 (vector-length below-elements)))
     (define piece-length
       (+ (for/sum ([piece (in-vector above-elements)]) (string-length piece))
          (string-length current)
          (for/sum ([piece (in-vector below-elements)]) (string-length piece))))
     (define result
       (make-string (+ piece-length
                       (* (sub1 piece-count) (string-length receiver)))))
     (define offset 0)
     (define first-piece? #t)
     (define (copy-piece! piece)
       (unless first-piece?
         (string-copy! result offset receiver)
         (set! offset (+ offset (string-length receiver))))
       (set! first-piece? #f)
       (string-copy! result offset piece)
       (set! offset (+ offset (string-length piece))))
     (for ([index (in-range (sub1 (vector-length above-elements)) -1 -1)])
       (copy-piece! (vector-ref above-elements index)))
     (copy-piece! current)
     (for ([piece (in-vector below-elements)])
       (copy-piece! piece))
     result]
    [(find)
     (unless (= (length arguments) 2)
       (arity-error "String find" 2 (length arguments)))
     (define pattern (car arguments))
     (define start (cadr arguments))
     (unless (string? pattern)
       (error 'eval-aloe "String find expects a String pattern"))
     (unless (exact-integer? start)
       (error 'eval-aloe "String find expects an Int start"))
     (define haystack-length (string-length receiver))
     (define pattern-length (string-length pattern))
     (define index
       (if (zero? pattern-length)
           (min (max start 0) haystack-length)
           (for/first
               ([candidate (in-range (max start 0)
                                     (add1 (- haystack-length pattern-length)))]
                #:when
                (for/and ([offset (in-range pattern-length)])
                  (char=? (string-ref receiver (+ candidate offset))
                          (string-ref pattern offset))))
             candidate)))
     (define option-class (option-class-for environment))
     (unless option-class
       (error 'eval-aloe "unbound symbol: ~a" 'Option))
     (if index
         (construct-instance option-class 'Some (list index))
         (struct-copy instance-value
                      (construct-instance option-class 'None '())
                      [type-arguments (vector-immutable 'Int)]))]
    [else (send-to-string-method receiver selector arguments environment)]))

(define (send-to-string-method receiver selector arguments environment)
  (define class (string-class-for environment))
  (unless class (unknown-message selector))
  (define selected
    (select-runtime-method
     (string-class-object-methods class)
     selector
     arguments
     'String
     (lambda (method resolve-environment)
       (method-arguments-specificity
        method arguments (make-hasheq) resolve-environment))
     (string-class-object-method-environments class)))
  (apply-string-method
   receiver class (runtime-method-match-method selected) arguments))

(define (apply-string-method receiver class method arguments)
  (define parameters (method-declaration-parameters method))
  (unless (= (length parameters) (length arguments))
    (arity-error
     (format "String method ~a" (method-declaration-selector method))
     (length parameters)
     (length arguments)))
  (define bindings
    (cons (cons 'self receiver)
          (for/list ([parameter (in-list parameters)]
                     [argument (in-list arguments)])
            (cons (parameter-declaration-name parameter) argument))))
  (eval-expr
   (method-declaration-body method)
   (make-local-env
    (recorded-method-environment
     (string-class-object-method-environments class) method)
    bindings)))

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

(define (eval-exprs expressions environment)
  (for/fold ([result (void)])
            ([expression (in-list expressions)])
    (eval-expr expression environment)))

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

;; Reflection lives in eval-mirror.rkt, which cannot require this module; its
;; Mirror and Signature sends are built from these four procedures.
(define-values (send-to-mirror send-to-signature)
  (make-reflection-sends make-list-value
                         runtime-type-of
                         same-runtime-type?
                         invoke-signature-row))

;; Tests read the environment each method and protocol recorded through this
;; hook; nothing else does.
(module* method-records #f
  (provide evaluator-method-records
           evaluator-protocol-environment)

  ;; For the class, or the List, Int, or String class object, bound to name:
  ;; each method's selector and recorded environment, in method order.
  (define (evaluator-method-records environment name)
    (define class (env-lookup environment name))
    (define-values (methods method-environments)
      (cond
        [(class-value? class)
         (values (class-value-methods class)
                 (class-value-method-environments class))]
        [(list-class-object? class)
         (values (list-class-object-methods class)
                 (list-class-object-method-environments class))]
        [(int-class-object? class)
         (values (int-class-object-methods class)
                 (int-class-object-method-environments class))]
        [(string-class-object? class)
         (values (string-class-object-methods class)
                 (string-class-object-method-environments class))]
        [else
         (error 'evaluator-method-records "~a is not a class" name)]))
    (for/list ([method (in-list methods)])
      (cons (method-declaration-selector method)
            (recorded-method-environment method-environments method))))

  (define (evaluator-protocol-environment environment name)
    (protocol-value-environment (lookup-protocol environment name))))
