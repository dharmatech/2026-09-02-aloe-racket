#lang racket/base

(require racket/match
         racket/list
         racket/path
         racket/port)

(provide (struct-out int-expr)
         (struct-out float-expr)
         (struct-out bool-expr)
         (struct-out string-expr)
         (struct-out variable-expr)
         (struct-out load-expr)
         (struct-out check-expr)
         (struct-out define-expr)
         (struct-out field-declaration)
         (struct-out constructor-declaration)
         (struct-out parameter-declaration)
         (struct-out method-declaration)
         (struct-out define-protocol-expr)
         (struct-out define-class-expr)
         (struct-out define-methods-expr)
         (struct-out fn-expr)
         (struct-out case-clause)
         (struct-out case-expr)
         (struct-out send-expr)
         parse-datum
         parse-program
         read-program
         expression-loc
         load-expr-resolved-path)

(struct int-expr (value loc) #:transparent)
(struct float-expr (value loc) #:transparent)
(struct bool-expr (value loc) #:transparent)
(struct string-expr (value loc) #:transparent)
(struct variable-expr (name loc) #:transparent)
(struct load-expr (path directory loc) #:transparent)
(struct check-expr (left right left-datum right-datum loc) #:transparent)
(struct define-expr (name value loc) #:transparent)
(struct field-declaration (name type) #:transparent)
(struct constructor-declaration (selector fields) #:transparent)
(struct parameter-declaration (name type) #:transparent)
(struct method-declaration
  (selector type-parameters parameters return-type body)
  #:transparent)
(struct define-protocol-expr (name signatures loc) #:transparent)
(struct define-class-expr
  (name type-parameters protocol fields constructors methods loc)
  #:transparent)
(struct define-methods-expr (target methods loc) #:transparent)
(struct fn-expr (parameters body loc) #:transparent)
(struct case-clause (selector payload-names body) #:transparent)
(struct case-expr (scrutinee clauses else-body loc) #:transparent)
(struct send-expr (receiver selector arguments loc selector-loc) #:transparent)

(define (expression-loc expression)
  (match expression
    [(int-expr _ loc) loc]
    [(float-expr _ loc) loc]
    [(bool-expr _ loc) loc]
    [(string-expr _ loc) loc]
    [(variable-expr _ loc) loc]
    [(load-expr _ _ loc) loc]
    [(check-expr _ _ _ _ loc) loc]
    [(define-expr _ _ loc) loc]
    [(define-protocol-expr _ _ loc) loc]
    [(define-class-expr _ _ _ _ _ _ loc) loc]
    [(define-methods-expr _ _ loc) loc]
    [(fn-expr _ _ loc) loc]
    [(case-expr _ _ _ loc) loc]
    [(send-expr _ _ _ loc _) loc]
    [_
     (raise-argument-error
      'expression-loc
      "Aloe expression"
      expression)]))

(define current-aloe-source-directory (make-parameter #f))

(define (source-directory source-path)
  (or (path-only (path->complete-path source-path))
      (current-directory)))

(define (load-expr-resolved-path expression)
  (simplify-path
   (path->complete-path
    (string->path (load-expr-path expression))
    (load-expr-directory expression))
   #f))

(define (parse-atom datum)
  (cond
    [(boolean? datum) (bool-expr datum #f)]
    [(exact-integer? datum) (int-expr datum #f)]
    [(flonum? datum) (float-expr datum #f)]
    [(string? datum) (string-expr datum #f)]
    [(symbol? datum) (variable-expr datum #f)]
    [else
     (raise-arguments-error
      'parse-datum
      "unsupported Aloe atom in checkpoint 1"
      "datum" datum)]))

(define (parse-field-declaration datum)
  (match datum
    [(list (? symbol? name) type)
     (field-declaration name type)]
    [_
     (raise-arguments-error
      'parse-datum
      "malformed field; expected (name Type)"
      "field" datum)]))

(define (parse-class-header header datum)
  (cond
    [(symbol? header)
     (cons header '())]
    [(and (list? header)
          (pair? header)
          (andmap symbol? header))
     (define name (car header))
     (define type-parameters (cdr header))
     (define duplicate (check-duplicates type-parameters))
     (when duplicate
       (raise-arguments-error
        'parse-datum
        "class type parameters must be unique"
        "type parameter" duplicate
        "datum" datum))
     (cons name type-parameters)]
    [else
     (raise-arguments-error
      'parse-datum
      "class header must be a name or (Name T ...)"
      "header" header
      "datum" datum)]))

(define (parse-parameter-declaration datum)
  (match datum
    [(list (? symbol? name) type)
     (parameter-declaration name type)]
    [_
     (raise-arguments-error
      'parse-datum
      "malformed parameter; expected (name Type)"
      "parameter" datum)]))

(define (clearly-type-sexpr? datum)
  (define (capital-name? value)
    (and (symbol? value)
         (let ([name (symbol->string value)])
           (and (positive? (string-length name))
                (char-upper-case? (string-ref name 0))))))
  (or (capital-name? datum)
      (and (list? datum)
           (pair? datum)
           (or (eq? (car datum) '->)
               (capital-name? (car datum))))))

(define (split-method-type-parameters parts datum)
  (cond
    [(and (pair? parts)
          (list? (car parts))
          (pair? (car parts))
          (eq? (caar parts) 'type))
     (define names (cdar parts))
     (unless (and (pair? names) (andmap symbol? names))
       (raise-arguments-error
        'parse-datum
        "method type header must be (type Name ...)"
        "header" (car parts)
        "method" datum))
     (define duplicate (check-duplicates names))
     (when duplicate
       (raise-arguments-error
        'parse-datum
        "method type parameters must be unique"
        "type parameter" duplicate
        "method" datum))
     (values names (cdr parts))]
    [else (values '() parts)]))

(define (parse-method-declaration datum)
  (match datum
    [(list (? symbol? selector) raw-parts ...)
     (define-values (type-parameters parts)
       (split-method-type-parameters raw-parts datum))
     (when (< (length parts) 2)
       (raise-arguments-error
        'parse-datum
        "malformed method; expected parameters, return type, and body"
        "method" datum))
     (define explicit-empty-parameters?
       (and (pair? parts) (null? (car parts))))
     (when (and explicit-empty-parameters?
                (not (= (length parts) 3)))
       (raise-arguments-error
        'parse-datum
        "malformed zero-parameter method"
        "method" datum))
     (define parameter-datums
       (if explicit-empty-parameters?
           '()
           (take parts (- (length parts) 2))))
     (define return-type
       (if explicit-empty-parameters?
           (cadr parts)
           (list-ref parts (length parameter-datums))))
     (define body
       (if explicit-empty-parameters?
           (caddr parts)
           (last parts)))
     (unless (clearly-type-sexpr? return-type)
       (raise-arguments-error
        'parse-datum
        "method return type must be a type expression"
        "return type" return-type
        "method" datum))
     (method-declaration
      selector
      type-parameters
      (map parse-parameter-declaration parameter-datums)
      return-type
      (parse-datum body))]
    [_
     (raise-arguments-error
      'parse-datum
      "malformed method declaration"
      "method" datum)]))

(define (parse-protocol-signature datum)
  (match datum
    [(list (? symbol? selector) raw-parts ...)
     (when (null? raw-parts)
       (raise-arguments-error
        'parse-datum
        "malformed protocol signature; expected parameters and a return type"
        "signature" datum))
     (define explicit-empty-parameters?
       (and (pair? raw-parts) (null? (car raw-parts))))
     (when (and explicit-empty-parameters?
                (not (= (length raw-parts) 2)))
       (raise-arguments-error
        'parse-datum
        "malformed zero-parameter protocol signature"
        "signature" datum))
     (define parameter-datums
       (if explicit-empty-parameters?
           '()
           (drop-right raw-parts 1)))
     (define return-type (last raw-parts))
     (unless (clearly-type-sexpr? return-type)
       (raise-arguments-error
        'parse-datum
        "protocol return type must be a type expression"
        "return type" return-type
        "signature" datum))
     (method-declaration
      selector
      '()
      (map parse-parameter-declaration parameter-datums)
      return-type
      #f)]
    [_
     (raise-arguments-error
      'parse-datum
      "malformed protocol signature"
      "signature" datum)]))

(define (ensure-distinct-fields fields datum)
  (define duplicate
    (check-duplicates (map field-declaration-name fields)))
  (when duplicate
    (raise-arguments-error
     'parse-datum
     "field names must be unique"
     "field" duplicate
     "datum" datum))
  fields)

(define (parse-constructor-declaration datum)
  (match datum
    [(list (? symbol? selector) (cons 'fields field-datums))
     (unless (list? field-datums)
       (raise-arguments-error
        'parse-datum
        "malformed constructor fields; expected (fields ...)"
        "constructor" datum))
     (constructor-declaration
      selector
      (ensure-distinct-fields
       (map parse-field-declaration field-datums)
       datum))]
    [_
     (raise-arguments-error
      'parse-datum
      "malformed constructor; expected (Name (fields ...))"
      "constructor" datum)]))

(define (parse-constructors constructor-datums datum)
  (unless (and (list? constructor-datums)
               (pair? constructor-datums))
    (raise-arguments-error
     'parse-datum
     "constructors section must be nonempty"
     "datum" datum))
  (define constructors
    (map parse-constructor-declaration constructor-datums))
  (define duplicate
    (check-duplicates
     (map constructor-declaration-selector constructors)))
  (when duplicate
    (raise-arguments-error
     'parse-datum
     "constructor selectors must be unique"
     "selector" duplicate
     "datum" datum))
  constructors)

(define (parse-case scrutinee-datum clause-datums datum)
  (unless (pair? clause-datums)
    (raise-arguments-error
     'parse-datum
     "case requires at least one clause"
     "datum" datum))
  (define named-clauses '())
  (define else-body #f)
  (for ([clause-datum (in-list clause-datums)]
        [index (in-naturals)])
    (define final? (= index (sub1 (length clause-datums))))
    (match clause-datum
      [(list 'else body-datum)
       (unless final?
         (raise-arguments-error
          'parse-datum
          "else must be the final case clause"
          "datum" datum))
       (set! else-body (parse-datum body-datum))]
      [(list (? symbol? selector) (? list? payload-names) body-datum)
       (when (eq? selector 'else)
         (raise-arguments-error
          'parse-datum
          "malformed else clause; expected (else body)"
          "clause" clause-datum
          "datum" datum))
       (unless (andmap symbol? payload-names)
         (raise-arguments-error
          'parse-datum
          "case payload names must be identifiers"
          "clause" clause-datum
          "datum" datum))
       (set! named-clauses
             (cons (case-clause
                    selector
                    payload-names
                    (parse-datum body-datum))
                   named-clauses))]
      [_
       (raise-arguments-error
        'parse-datum
        "malformed case clause; expected (Name (id ...) body) or (else body)"
        "clause" clause-datum
        "datum" datum)]))
  (case-expr (parse-datum scrutinee-datum)
             (reverse named-clauses)
             else-body
             #f))

(define (desugar-let binding-datums body datum)
  (unless (list? binding-datums)
    (raise-arguments-error
     'parse-datum
     "let bindings must be a list"
     "bindings" binding-datums))
  (define bindings
    (for/list ([binding-datum (in-list binding-datums)])
      (match binding-datum
        [(list (? symbol? name) expression)
         (cons name (parse-datum expression))]
        [_
         (raise-arguments-error
          'parse-datum
          "malformed let binding; expected (name expression)"
          "binding" binding-datum)])))
  (define names (map car bindings))
  (define duplicate (check-duplicates names))
  (when duplicate
    (raise-arguments-error
     'parse-datum
     "let binding names must be unique"
     "name" duplicate
     "datum" datum))
  (send-expr (fn-expr names (parse-datum body) #f)
             'call
             (map cdr bindings)
             #f
             #f))

(define (make-if-expression test-expression
                            then-expression
                            else-expression
                            [loc #f])
  (send-expr
   test-expression
   'if
   (list (fn-expr '() then-expression loc)
         (fn-expr '() else-expression loc))
   loc
   #f))

(define (desugar-if test-datum then-datum else-datum)
  (make-if-expression
   (parse-datum test-datum)
   (parse-datum then-datum)
   (parse-datum else-datum)))

(define (desugar-cond clause-datums datum)
  (unless (and (list? clause-datums) (pair? clause-datums))
    (raise-arguments-error
     'parse-datum
     "cond requires at least one clause and a final else clause"
     "datum" datum))
  (define clauses
    (for/list ([clause (in-list clause-datums)])
      (match clause
        [(list test expression) (list test expression)]
        [_
         (raise-arguments-error
          'parse-datum
          "malformed cond clause; expected (test expression)"
          "clause" clause
          "datum" datum)])))
  (define final-clause (last clauses))
  (unless (eq? (first final-clause) 'else)
    (raise-arguments-error
     'parse-datum
     "cond requires else as its final clause"
     "datum" datum))
  (for ([clause (in-list (drop-right clauses 1))])
    (when (eq? (first clause) 'else)
      (raise-arguments-error
       'parse-datum
       "else must be the final cond clause"
       "datum" datum)))
  (for/fold ([alternate (parse-datum (second final-clause))])
            ([clause (in-list (reverse (drop-right clauses 1)))])
    (make-if-expression
     (parse-datum (first clause))
     (parse-datum (second clause))
     alternate)))

(define (parse-datum datum)
  (match datum
    ['()
     (raise-arguments-error
      'parse-datum
      "empty combination is illegal"
      "datum" datum)]
    [(list 'load (? string? path))
     (load-expr path
                (or (current-aloe-source-directory)
                    (current-directory))
                #f)]
    [(cons 'load _)
     (raise-arguments-error
      'parse-datum
      "malformed load; expected (load \"path.aloe\")"
      "datum" datum)]
    [(list 'check left right)
     (check-expr (parse-datum left)
                 (parse-datum right)
                 left
                 right
                 #f)]
    [(cons 'check _)
     (raise-arguments-error
      'parse-datum
      "malformed check; expected (check left right)"
      "datum" datum)]
    [(list 'define (? symbol? name) value)
     (define-expr name (parse-datum value) #f)]
    [(cons 'define _)
     (raise-arguments-error
      'parse-datum
      "malformed define; expected (define name expression)"
      "datum" datum)]
    [(list 'define-protocol (? symbol? name) signature-datums ...)
     (define-protocol-expr
      name
      (map parse-protocol-signature signature-datums)
      #f)]
    [(cons 'define-protocol _)
     (raise-arguments-error
      'parse-datum
      "malformed define-protocol; expected a name and method signatures"
      "datum" datum)]
    [(list 'define-class
           header
           (cons 'fields field-datums)
           (cons 'methods method-datums))
     (define class-header (parse-class-header header datum))
     (define-class-expr
      (car class-header)
      (cdr class-header)
      #f
      (ensure-distinct-fields
       (map parse-field-declaration field-datums)
       datum)
      #f
      (map parse-method-declaration method-datums)
      #f)]
    [(list 'define-class
           header
           (? symbol? protocol)
           (cons 'fields field-datums)
           (cons 'methods method-datums))
     (define class-header (parse-class-header header datum))
     (define-class-expr
      (car class-header)
      (cdr class-header)
      protocol
      (ensure-distinct-fields
       (map parse-field-declaration field-datums)
       datum)
      #f
      (map parse-method-declaration method-datums)
      #f)]
    [(list 'define-class
           header
           (cons 'constructors constructor-datums)
           (cons 'methods method-datums))
     (define class-header (parse-class-header header datum))
     (define-class-expr
      (car class-header)
      (cdr class-header)
      #f
      #f
      (parse-constructors constructor-datums datum)
      (map parse-method-declaration method-datums)
      #f)]
    [(list 'define-class
           header
           (? symbol? protocol)
           (cons 'constructors constructor-datums)
           (cons 'methods method-datums))
     (define class-header (parse-class-header header datum))
     (define-class-expr
      (car class-header)
      (cdr class-header)
      protocol
      #f
      (parse-constructors constructor-datums datum)
      (map parse-method-declaration method-datums)
      #f)]
    [(cons 'define-class _)
     (raise-arguments-error
      'parse-datum
      "malformed define-class; expected a name, optional protocol, fields or constructors, and methods"
      "datum" datum)]
    [(list 'define-methods
           (? symbol? target)
           (cons 'methods method-datums))
     (define-methods-expr
      target
      (map parse-method-declaration method-datums)
      #f)]
    [(cons 'define-methods _)
     (raise-arguments-error
      'parse-datum
      "malformed define-methods; expected a target and methods"
      "datum" datum)]
    [(list 'fn parameter-names body)
     (unless (and (list? parameter-names)
                  (andmap symbol? parameter-names))
       (raise-arguments-error
        'parse-datum
        "fn parameters must be an untyped list of names"
        "parameters" parameter-names))
     (define duplicate (check-duplicates parameter-names))
     (when duplicate
       (raise-arguments-error
        'parse-datum
        "fn parameter names must be unique"
        "parameter" duplicate))
     (fn-expr parameter-names (parse-datum body) #f)]
    [(cons 'fn _)
     (raise-arguments-error
      'parse-datum
      "malformed fn; expected (fn (name ...) body)"
      "datum" datum)]
    [(list 'let binding-datums body)
     (desugar-let binding-datums body datum)]
    [(cons 'let _)
     (raise-arguments-error
      'parse-datum
      "malformed let; expected (let ((name expression) ...) body)"
      "datum" datum)]
    [(cons 'cond clause-datums)
     (desugar-cond clause-datums datum)]
    [(list 'if test-datum then-datum else-datum)
     (desugar-if test-datum then-datum else-datum)]
    [(cons 'if _)
     (raise-arguments-error
      'parse-datum
      "malformed if; expected (if test then else)"
      "datum" datum)]
    [(list scrutinee 'case clause-datums ...)
     (parse-case scrutinee clause-datums datum)]
    [(list _)
     (raise-arguments-error
      'parse-datum
      "combination has no selector"
      "datum" datum)]
    [(list receiver selector arguments ...)
     (unless (symbol? selector)
       (raise-arguments-error
        'parse-datum
        "selector must be a symbol"
        "selector" selector
        "datum" datum))
     (send-expr (parse-datum receiver)
                selector
                (map parse-datum arguments)
                #f
                #f)]
    [(? pair?)
     (raise-arguments-error
      'parse-datum
      "malformed combination"
      "datum" datum)]
    [_ (parse-atom datum)]))

(define (parse-program datums)
  (map parse-datum datums))

(define (syntax-location form)
  (srcloc (syntax-source form)
          (syntax-line form)
          (syntax-column form)
          (syntax-position form)
          (syntax-span form)))

(define (syntax-section-items form name)
  (define items (syntax->list form))
  (and items
       (pair? items)
       (eq? (syntax-e (car items)) name)
       (cdr items)))

(define (parse-syntax-atom form)
  (define datum (syntax-e form))
  (define loc (syntax-location form))
  (cond
    [(boolean? datum) (bool-expr datum loc)]
    [(exact-integer? datum) (int-expr datum loc)]
    [(flonum? datum) (float-expr datum loc)]
    [(string? datum) (string-expr datum loc)]
    [(symbol? datum) (variable-expr datum loc)]
    [else
     (raise-arguments-error
      'parse-datum
      "unsupported Aloe atom in checkpoint 1"
      "datum" (syntax->datum form))]))

(define (parse-method-syntax form)
  (define datum (syntax->datum form))
  (define items (syntax->list form))
  (unless (and items
               (pair? items)
               (symbol? (syntax-e (car items))))
    (raise-arguments-error
     'parse-datum
     "malformed method declaration"
     "method" datum))
  (define selector (syntax-e (car items)))
  (define raw-parts (cdr items))
  (define-values (type-parameters parts)
    (cond
      [(and (pair? raw-parts)
            (let ([header (syntax->datum (car raw-parts))])
              (and (list? header)
                   (pair? header)
                   (eq? (car header) 'type))))
       (define header (syntax->datum (car raw-parts)))
       (define names (cdr header))
       (unless (and (pair? names) (andmap symbol? names))
         (raise-arguments-error
          'parse-datum
          "method type header must be (type Name ...)"
          "header" header
          "method" datum))
       (define duplicate (check-duplicates names))
       (when duplicate
         (raise-arguments-error
          'parse-datum
          "method type parameters must be unique"
          "type parameter" duplicate
          "method" datum))
       (values names (cdr raw-parts))]
      [else (values '() raw-parts)]))
  (when (< (length parts) 2)
    (raise-arguments-error
     'parse-datum
     "malformed method; expected parameters, return type, and body"
     "method" datum))
  (define explicit-empty-parameters?
    (and (pair? parts)
         (null? (syntax->datum (car parts)))))
  (when (and explicit-empty-parameters?
             (not (= (length parts) 3)))
    (raise-arguments-error
     'parse-datum
     "malformed zero-parameter method"
     "method" datum))
  (define parameter-forms
    (if explicit-empty-parameters?
        '()
        (take parts (- (length parts) 2))))
  (define return-type
    (syntax->datum
     (if explicit-empty-parameters?
         (cadr parts)
         (list-ref parts (length parameter-forms)))))
  (define body-form
    (if explicit-empty-parameters?
        (caddr parts)
        (last parts)))
  (unless (clearly-type-sexpr? return-type)
    (raise-arguments-error
     'parse-datum
     "method return type must be a type expression"
     "return type" return-type
     "method" datum))
  (method-declaration
   selector
   type-parameters
   (map (lambda (parameter-form)
          (parse-parameter-declaration
           (syntax->datum parameter-form)))
        parameter-forms)
   return-type
   (parse-syntax-expression body-form)))

(define (parse-case-syntax scrutinee-form clause-forms form)
  (define datum (syntax->datum form))
  (unless (pair? clause-forms)
    (raise-arguments-error
     'parse-datum
     "case requires at least one clause"
     "datum" datum))
  (define named-clauses '())
  (define else-body #f)
  (for ([clause-form (in-list clause-forms)]
        [index (in-naturals)])
    (define clause-datum (syntax->datum clause-form))
    (define clause-items (syntax->list clause-form))
    (define final? (= index (sub1 (length clause-forms))))
    (cond
      [(and clause-items
            (= (length clause-items) 2)
            (eq? (syntax-e (car clause-items)) 'else))
       (unless final?
         (raise-arguments-error
          'parse-datum
          "else must be the final case clause"
          "datum" datum))
       (set! else-body
             (parse-syntax-expression (cadr clause-items)))]
      [(and clause-items
            (= (length clause-items) 3)
            (symbol? (syntax-e (car clause-items)))
            (list? (syntax->datum (cadr clause-items))))
       (define selector (syntax-e (car clause-items)))
       (define payload-names (syntax->datum (cadr clause-items)))
       (when (eq? selector 'else)
         (raise-arguments-error
          'parse-datum
          "malformed else clause; expected (else body)"
          "clause" clause-datum
          "datum" datum))
       (unless (andmap symbol? payload-names)
         (raise-arguments-error
          'parse-datum
          "case payload names must be identifiers"
          "clause" clause-datum
          "datum" datum))
       (set! named-clauses
             (cons (case-clause
                    selector
                    payload-names
                    (parse-syntax-expression (caddr clause-items)))
                   named-clauses))]
      [else
       (raise-arguments-error
        'parse-datum
        "malformed case clause; expected (Name (id ...) body) or (else body)"
        "clause" clause-datum
        "datum" datum)]))
  (case-expr (parse-syntax-expression scrutinee-form)
             (reverse named-clauses)
             else-body
             (syntax-location form)))

(define (desugar-let-syntax bindings-form body-form form)
  (define datum (syntax->datum form))
  (define binding-forms (syntax->list bindings-form))
  (unless binding-forms
    (raise-arguments-error
     'parse-datum
     "let bindings must be a list"
     "bindings" (syntax->datum bindings-form)))
  (define bindings
    (for/list ([binding-form (in-list binding-forms)])
      (define binding-datum (syntax->datum binding-form))
      (define items (syntax->list binding-form))
      (unless (and items
                   (= (length items) 2)
                   (symbol? (syntax-e (car items))))
        (raise-arguments-error
         'parse-datum
         "malformed let binding; expected (name expression)"
         "binding" binding-datum))
      (cons (syntax-e (car items))
            (parse-syntax-expression (cadr items)))))
  (define names (map car bindings))
  (define duplicate (check-duplicates names))
  (when duplicate
    (raise-arguments-error
     'parse-datum
     "let binding names must be unique"
     "name" duplicate
     "datum" datum))
  (define loc (syntax-location form))
  (send-expr (fn-expr names
                      (parse-syntax-expression body-form)
                      loc)
             'call
             (map cdr bindings)
             loc
             #f))

(define (desugar-cond-syntax clause-forms form)
  (define datum (syntax->datum form))
  (unless (pair? clause-forms)
    (raise-arguments-error
     'parse-datum
     "cond requires at least one clause and a final else clause"
     "datum" datum))
  (define clauses
    (for/list ([clause-form (in-list clause-forms)])
      (define clause-datum (syntax->datum clause-form))
      (define items (syntax->list clause-form))
      (unless (and items (= (length items) 2))
        (raise-arguments-error
         'parse-datum
         "malformed cond clause; expected (test expression)"
         "clause" clause-datum
         "datum" datum))
      items))
  (define final-clause (last clauses))
  (unless (eq? (syntax-e (first final-clause)) 'else)
    (raise-arguments-error
     'parse-datum
     "cond requires else as its final clause"
     "datum" datum))
  (for ([clause (in-list (drop-right clauses 1))])
    (when (eq? (syntax-e (first clause)) 'else)
      (raise-arguments-error
       'parse-datum
       "else must be the final cond clause"
       "datum" datum)))
  (define loc (syntax-location form))
  (for/fold ([alternate
              (parse-syntax-expression (second final-clause))])
            ([clause (in-list (reverse (drop-right clauses 1)))])
    (make-if-expression
     (parse-syntax-expression (first clause))
     (parse-syntax-expression (second clause))
     alternate
     loc)))

(define (parse-class-syntax items form)
  (define datum (syntax->datum form))
  (define loc (syntax-location form))
  (define (build header-form protocol data-form methods-form)
    (define field-forms (syntax-section-items data-form 'fields))
    (define constructor-forms
      (syntax-section-items data-form 'constructors))
    (define method-forms (syntax-section-items methods-form 'methods))
    (unless (and (or field-forms constructor-forms) method-forms)
      (raise-arguments-error
       'parse-datum
       "malformed define-class; expected a name, optional protocol, fields or constructors, and methods"
       "datum" datum))
    (define class-header
      (parse-class-header (syntax->datum header-form) datum))
    (define fields
      (and field-forms
           (ensure-distinct-fields
            (map (lambda (field-form)
                   (parse-field-declaration (syntax->datum field-form)))
                 field-forms)
            datum)))
    (define constructors
      (and constructor-forms
           (parse-constructors
            (map syntax->datum constructor-forms)
            datum)))
    (define-class-expr
     (car class-header)
     (cdr class-header)
     protocol
     fields
     constructors
     (map parse-method-syntax method-forms)
     loc))
  (cond
    [(= (length items) 4)
     (build (list-ref items 1)
            #f
            (list-ref items 2)
            (list-ref items 3))]
    [(and (= (length items) 5)
          (symbol? (syntax-e (list-ref items 2))))
     (build (list-ref items 1)
            (syntax-e (list-ref items 2))
            (list-ref items 3)
            (list-ref items 4))]
    [else
     (raise-arguments-error
      'parse-datum
      "malformed define-class; expected a name, optional protocol, fields or constructors, and methods"
      "datum" datum)]))

(define (parse-syntax-expression form)
  (define datum (syntax->datum form))
  (define items (syntax->list form))
  (define pair-form? (pair? (syntax-e form)))
  (define head
    (and pair-form?
         (let ([first-part (car (syntax-e form))])
           (and (syntax? first-part) (syntax-e first-part)))))
  (define loc (syntax-location form))
  (cond
    [(and items (null? items))
     (raise-arguments-error
      'parse-datum
      "empty combination is illegal"
      "datum" datum)]
    [(eq? head 'load)
     (if (and items
              (= (length items) 2)
              (string? (syntax-e (cadr items))))
         (load-expr (syntax-e (cadr items))
                    (or (current-aloe-source-directory)
                        (current-directory))
                    loc)
         (raise-arguments-error
          'parse-datum
          "malformed load; expected (load \"path.aloe\")"
          "datum" datum))]
    [(eq? head 'check)
     (if (and items (= (length items) 3))
         (check-expr
          (parse-syntax-expression (cadr items))
          (parse-syntax-expression (caddr items))
          (syntax->datum (cadr items))
          (syntax->datum (caddr items))
          loc)
         (raise-arguments-error
          'parse-datum
          "malformed check; expected (check left right)"
          "datum" datum))]
    [(eq? head 'define)
     (if (and items
              (= (length items) 3)
              (symbol? (syntax-e (cadr items))))
         (define-expr (syntax-e (cadr items))
                      (parse-syntax-expression (caddr items))
                      loc)
         (raise-arguments-error
          'parse-datum
          "malformed define; expected (define name expression)"
          "datum" datum))]
    [(eq? head 'define-protocol)
     (if (and items
              (>= (length items) 2)
              (symbol? (syntax-e (cadr items))))
         (define-protocol-expr
          (syntax-e (cadr items))
          (map (lambda (signature-form)
                 (parse-protocol-signature
                  (syntax->datum signature-form)))
               (cddr items))
          loc)
         (raise-arguments-error
          'parse-datum
          "malformed define-protocol; expected a name and method signatures"
          "datum" datum))]
    [(eq? head 'define-class)
     (if items
         (parse-class-syntax items form)
         (raise-arguments-error
          'parse-datum
          "malformed define-class; expected a name, optional protocol, fields or constructors, and methods"
          "datum" datum))]
    [(eq? head 'define-methods)
     (define method-forms
       (and items
            (= (length items) 3)
            (symbol? (syntax-e (cadr items)))
            (syntax-section-items (caddr items) 'methods)))
     (if method-forms
         (define-methods-expr
          (syntax-e (cadr items))
          (map parse-method-syntax method-forms)
          loc)
         (raise-arguments-error
          'parse-datum
          "malformed define-methods; expected a target and methods"
          "datum" datum))]
    [(eq? head 'fn)
     (if (and items (= (length items) 3))
         (let ([parameter-names (syntax->datum (cadr items))])
           (unless (and (list? parameter-names)
                        (andmap symbol? parameter-names))
             (raise-arguments-error
              'parse-datum
              "fn parameters must be an untyped list of names"
              "parameters" parameter-names))
           (define duplicate (check-duplicates parameter-names))
           (when duplicate
             (raise-arguments-error
              'parse-datum
              "fn parameter names must be unique"
              "parameter" duplicate))
           (fn-expr parameter-names
                    (parse-syntax-expression (caddr items))
                    loc))
         (raise-arguments-error
          'parse-datum
          "malformed fn; expected (fn (name ...) body)"
          "datum" datum))]
    [(eq? head 'let)
     (if (and items (= (length items) 3))
         (desugar-let-syntax (cadr items) (caddr items) form)
         (raise-arguments-error
          'parse-datum
          "malformed let; expected (let ((name expression) ...) body)"
          "datum" datum))]
    [(eq? head 'cond)
     (if items
         (desugar-cond-syntax (cdr items) form)
         (raise-arguments-error
          'parse-datum
          "cond requires at least one clause and a final else clause"
          "datum" datum))]
    [(eq? head 'if)
     (if (and items (= (length items) 4))
         (make-if-expression
          (parse-syntax-expression (list-ref items 1))
          (parse-syntax-expression (list-ref items 2))
          (parse-syntax-expression (list-ref items 3))
          loc)
         (raise-arguments-error
          'parse-datum
          "malformed if; expected (if test then else)"
          "datum" datum))]
    [(and items
          (>= (length items) 2)
          (eq? (syntax-e (cadr items)) 'case))
     (parse-case-syntax (car items) (cddr items) form)]
    [(and items (= (length items) 1))
     (raise-arguments-error
      'parse-datum
      "combination has no selector"
      "datum" datum)]
    [(and items (>= (length items) 2))
     (define selector (syntax-e (cadr items)))
     (unless (symbol? selector)
       (raise-arguments-error
        'parse-datum
        "selector must be a symbol"
        "selector" (syntax->datum (cadr items))
        "datum" datum))
     (send-expr (parse-syntax-expression (car items))
                selector
                (map parse-syntax-expression (cddr items))
                loc
                (syntax-location (cadr items)))]
    [pair-form?
     (raise-arguments-error
      'parse-datum
      "malformed combination"
      "datum" datum)]
    [else (parse-syntax-atom form)]))

(define (read-program-port input source-path)
  (port-count-lines! input)
  (let loop ([expressions '()])
    (define form (read-syntax source-path input))
    (if (eof-object? form)
        (reverse expressions)
        (loop (cons (parse-syntax-expression form) expressions)))))

(define (read-program input #:source-path [source-path #f])
  (parameterize
      ([current-aloe-source-directory
        (if source-path
            (source-directory source-path)
            (current-aloe-source-directory))])
    (cond
      [(string? input)
       (call-with-input-string
        input
        (lambda (port)
          (read-program-port port source-path)))]
      [(input-port? input)
       (read-program-port input source-path)]
      [else
       (raise-argument-error
        'read-program
        "(or/c string? input-port?)"
        input)])))
