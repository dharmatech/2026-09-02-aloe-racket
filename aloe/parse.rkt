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
         (struct-out parameter-declaration)
         (struct-out method-declaration)
         (struct-out define-protocol-expr)
         (struct-out define-class-expr)
         (struct-out define-methods-expr)
         (struct-out fn-expr)
         (struct-out send-expr)
         parse-datum
         parse-program
         read-program
         load-expr-resolved-path)

(struct int-expr (value) #:transparent)
(struct float-expr (value) #:transparent)
(struct bool-expr (value) #:transparent)
(struct string-expr (value) #:transparent)
(struct variable-expr (name) #:transparent)
(struct load-expr (path directory) #:transparent)
(struct check-expr (left right left-datum right-datum) #:transparent)
(struct define-expr (name value) #:transparent)
(struct field-declaration (name type) #:transparent)
(struct parameter-declaration (name type) #:transparent)
(struct method-declaration
  (selector type-parameters parameters return-type body)
  #:transparent)
(struct define-protocol-expr (name signatures) #:transparent)
(struct define-class-expr
  (name type-parameters protocol fields methods)
  #:transparent)
(struct define-methods-expr (target methods) #:transparent)
(struct fn-expr (parameters body) #:transparent)
(struct send-expr (receiver selector arguments) #:transparent)

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
    [(boolean? datum) (bool-expr datum)]
    [(exact-integer? datum) (int-expr datum)]
    [(flonum? datum) (float-expr datum)]
    [(string? datum) (string-expr datum)]
    [(symbol? datum) (variable-expr datum)]
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
  (send-expr (fn-expr names (parse-datum body))
             'call
             (map cdr bindings)))

(define (make-if-expression test-expression then-expression else-expression)
  (send-expr
   test-expression
   'if
   (list (fn-expr '() then-expression)
         (fn-expr '() else-expression))))

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
                    (current-directory)))]
    [(cons 'load _)
     (raise-arguments-error
      'parse-datum
      "malformed load; expected (load \"path.aloe\")"
      "datum" datum)]
    [(list 'check left right)
     (check-expr (parse-datum left)
                 (parse-datum right)
                 left
                 right)]
    [(cons 'check _)
     (raise-arguments-error
      'parse-datum
      "malformed check; expected (check left right)"
      "datum" datum)]
    [(list 'define (? symbol? name) value)
     (define-expr name (parse-datum value))]
    [(cons 'define _)
     (raise-arguments-error
      'parse-datum
      "malformed define; expected (define name expression)"
      "datum" datum)]
    [(list 'define-protocol (? symbol? name) signature-datums ...)
     (define-protocol-expr
      name
      (map parse-protocol-signature signature-datums))]
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
      (map parse-method-declaration method-datums))]
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
      (map parse-method-declaration method-datums))]
    [(cons 'define-class _)
     (raise-arguments-error
      'parse-datum
      "malformed define-class; expected a name, optional protocol, fields, and methods"
      "datum" datum)]
    [(list 'define-methods
           (? symbol? target)
           (cons 'methods method-datums))
     (define-methods-expr
      target
      (map parse-method-declaration method-datums))]
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
     (fn-expr parameter-names (parse-datum body))]
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
                (map parse-datum arguments))]
    [(? pair?)
     (raise-arguments-error
      'parse-datum
      "malformed combination"
      "datum" datum)]
    [_ (parse-atom datum)]))

(define (parse-program datums)
  (map parse-datum datums))

(define (read-program input #:source-path [source-path #f])
  (parameterize
      ([current-aloe-source-directory
        (if source-path
            (source-directory source-path)
            (current-aloe-source-directory))])
    (cond
      [(string? input)
       (call-with-input-string input read-program)]
      [(input-port? input)
       (let loop ([expressions '()])
         (define datum (read input))
         (if (eof-object? datum)
             (reverse expressions)
             (loop (cons (parse-datum datum) expressions))))]
      [else
       (raise-argument-error
        'read-program
        "(or/c string? input-port?)"
        input)])))
