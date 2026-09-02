#lang racket/base

(require racket/match
         racket/list
         racket/port)

(provide (struct-out int-expr)
         (struct-out float-expr)
         (struct-out bool-expr)
         (struct-out variable-expr)
         (struct-out define-expr)
         (struct-out field-declaration)
         (struct-out parameter-declaration)
         (struct-out method-declaration)
         (struct-out define-class-expr)
         (struct-out fn-expr)
         (struct-out send-expr)
         parse-datum
         parse-program
         read-program)

(struct int-expr (value) #:transparent)
(struct float-expr (value) #:transparent)
(struct bool-expr (value) #:transparent)
(struct variable-expr (name) #:transparent)
(struct define-expr (name value) #:transparent)
(struct field-declaration (name type) #:transparent)
(struct parameter-declaration (name type) #:transparent)
(struct method-declaration (selector parameters return-type body) #:transparent)
(struct define-class-expr (name type-parameters fields methods) #:transparent)
(struct fn-expr (parameters body) #:transparent)
(struct send-expr (receiver selector arguments) #:transparent)

(define (parse-atom datum)
  (cond
    [(boolean? datum) (bool-expr datum)]
    [(exact-integer? datum) (int-expr datum)]
    [(flonum? datum) (float-expr datum)]
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
           (capital-name? (car datum)))))

(define (parse-method-declaration datum)
  (match datum
    [(list (? symbol? selector) '() return-type body)
     (unless (clearly-type-sexpr? return-type)
       (raise-arguments-error
        'parse-datum
        "method return type must be a type expression"
        "return type" return-type
        "method" datum))
     (method-declaration selector '() return-type (parse-datum body))]
    [(list (? symbol? selector) parts ...)
     (when (< (length parts) 2)
       (raise-arguments-error
        'parse-datum
        "malformed method; expected parameters, return type, and body"
        "method" datum))
     (define parameter-count (- (length parts) 2))
     (define return-type (list-ref parts parameter-count))
     (unless (clearly-type-sexpr? return-type)
       (raise-arguments-error
        'parse-datum
        "method return type must be a type expression"
        "return type" return-type
        "method" datum))
     (method-declaration
      selector
      (map parse-parameter-declaration (take parts parameter-count))
      return-type
      (parse-datum (list-ref parts (add1 parameter-count))))]
    [_
     (raise-arguments-error
      'parse-datum
      "malformed method declaration"
      "method" datum)]))

(define (ensure-distinct-methods methods datum)
  (define duplicate
    (check-duplicates (map method-declaration-selector methods)))
  (when duplicate
    (raise-arguments-error
     'parse-datum
     "method selectors must be unique"
     "selector" duplicate
     "datum" datum))
  methods)

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

(define (desugar-if test-datum then-datum else-datum)
  (send-expr
   (parse-datum test-datum)
   'if
   (list (fn-expr '() (parse-datum then-datum))
         (fn-expr '() (parse-datum else-datum)))))

(define (parse-datum datum)
  (match datum
    ['()
     (raise-arguments-error
      'parse-datum
      "empty combination is illegal"
      "datum" datum)]
    [(list 'define (? symbol? name) value)
     (define-expr name (parse-datum value))]
    [(cons 'define _)
     (raise-arguments-error
      'parse-datum
      "malformed define; expected (define name expression)"
      "datum" datum)]
    [(list 'define-class
           header
           (cons 'fields field-datums)
           (cons 'methods method-datums))
     (define class-header (parse-class-header header datum))
     (define-class-expr
      (car class-header)
      (cdr class-header)
      (map parse-field-declaration field-datums)
      (ensure-distinct-methods
       (map parse-method-declaration method-datums)
       datum))]
    [(cons 'define-class _)
     (raise-arguments-error
      'parse-datum
      "malformed define-class; expected a name, fields, and methods"
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

(define (read-program input)
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
      input)]))
