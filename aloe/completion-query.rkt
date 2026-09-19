#lang racket/base

(require racket/port
         racket/string
         (only-in "main.rkt"
                  make-type-environment)
         (only-in "parse.rkt"
                  bool-expr?
                  case-clause-body
                  case-expr-clauses
                  case-expr-else-body
                  case-expr-scrutinee
                  case-expr?
                  check-expr-left
                  check-expr-right
                  check-expr?
                  define-class-expr-methods
                  define-class-expr?
                  define-expr-value
                  define-expr?
                  define-methods-expr-methods
                  define-methods-expr?
                  define-protocol-expr?
                  float-expr?
                  fn-expr-body
                  fn-expr?
                  int-expr?
                  load-expr?
                  method-declaration-body
                  send-expr-arguments
                  send-expr-receiver
                  send-expr?
                  string-expr?
                  variable-expr?)
         (only-in "private/completion-selection.rkt"
                  recover-selector-completion-site
                  selector-completion-site-expressions
                  selector-completion-site-replacement-span
                  selector-completion-site-replacement-start
                  selector-completion-site-selector-text
                  selector-completion-site-target-send)
         (only-in "signature-catalog.rkt"
                  signature-spec-parameters
                  signature-spec-return
                  signature-spec-selector)
         (only-in (submod "type.rkt" completion-query-observation)
                  selector-receiver-observation-signatures
                  typecheck-program/observe-selector-receiver))

(provide (struct-out selector-completion-item)
         query-selector-completions)

(struct selector-completion-item
  (label detail insert-text replacement-start replacement-span)
  #:transparent)

(define (expression-children expression)
  (cond
    [(or (int-expr? expression)
         (float-expr? expression)
         (bool-expr? expression)
         (string-expr? expression)
         (variable-expr? expression)
         (load-expr? expression)
         (define-protocol-expr? expression))
     '()]
    [(check-expr? expression)
     (list (check-expr-left expression)
           (check-expr-right expression))]
    [(define-expr? expression)
     (list (define-expr-value expression))]
    [(define-class-expr? expression)
     (for/list ([method
                 (in-list (define-class-expr-methods expression))])
       (method-declaration-body method))]
    [(define-methods-expr? expression)
     (for/list ([method
                 (in-list (define-methods-expr-methods expression))])
       (method-declaration-body method))]
    [(fn-expr? expression)
     (list (fn-expr-body expression))]
    [(case-expr? expression)
     (append (list (case-expr-scrutinee expression))
             (for/list ([clause (in-list (case-expr-clauses expression))])
               (case-clause-body clause))
             (if (case-expr-else-body expression)
                 (list (case-expr-else-body expression))
                 '()))]
    [(send-expr? expression)
     (cons (send-expr-receiver expression)
           (send-expr-arguments expression))]
    [else '()]))

(define (forest-contains-load? expressions)
  (define (contains-load? expression)
    (or (load-expr? expression)
        (for/or ([child (in-list (expression-children expression))])
          (contains-load? child))))
  (for/or ([expression (in-list expressions)])
    (contains-load? expression)))

(define (datum->source-token datum)
  (call-with-output-string
   (lambda (output)
     (write datum output))))

(define (read-single-symbol text)
  (call-with-input-string
   text
   (lambda (input)
     (define datum (read input))
     (and (symbol? datum)
          (eof-object? (read input))
          datum))))

(define (select-rows rows selector-text position replacement-start
                     replacement-span)
  (cond
    [(string=? selector-text "") rows]
    [else
     (define selector (read-single-symbol selector-text))
     (and selector
          (cond
            [(for/or ([row (in-list rows)])
               (eq? selector (signature-spec-selector row)))
             rows]
            [(= position (+ replacement-start replacement-span))
             (filter
              (lambda (row)
                (string-prefix?
                 (datum->source-token (signature-spec-selector row))
                 selector-text))
              rows)]
            [else #f]))]))

(define (row->completion-item row replacement-start replacement-span)
  (define label
    (datum->source-token (signature-spec-selector row)))
  (selector-completion-item
   label
   (string-append
    (datum->source-token (signature-spec-parameters row))
    " -> "
    (datum->source-token (signature-spec-return row)))
   label
   replacement-start
   replacement-span))

(define (query-selector-completions source position
                                    #:source-path [source-path #f])
  (unless (string? source)
    (raise-argument-error
     'query-selector-completions
     "string?"
     source))
  (unless (exact-positive-integer? position)
    (raise-argument-error
     'query-selector-completions
     "exact-positive-integer?"
     position))
  (unless (or (not source-path) (path-string? source-path))
    (raise-argument-error
     'query-selector-completions
     "(or/c path-string? #f)"
     source-path))

  (cond
    [(> position (add1 (string-length source))) '()]
    [else
     (with-handlers ([exn:fail? (lambda (_) '())])
       (parameterize ([current-output-port (open-output-string)]
                      [current-error-port (open-output-string)])
         (define normalized-path
           (and source-path
                (simplify-path (path->complete-path source-path) #f)))
         (define site
           (recover-selector-completion-site
            source position #:source-path normalized-path))
         (cond
           [(not site) '()]
           [(and (not source-path)
                 (forest-contains-load?
                  (selector-completion-site-expressions site)))
            '()]
           [else
            (define environment (make-type-environment))
            (define observation
              (typecheck-program/observe-selector-receiver
               (selector-completion-site-expressions site)
               environment
               (selector-completion-site-target-send site)))
            (define replacement-start
              (selector-completion-site-replacement-start site))
            (define replacement-span
              (selector-completion-site-replacement-span site))
            (define selected-rows
              (select-rows
               (selector-receiver-observation-signatures observation)
               (selector-completion-site-selector-text site)
               position
               replacement-start
               replacement-span))
            (if selected-rows
                (for/list ([row (in-list selected-rows)])
                  (row->completion-item
                   row replacement-start replacement-span))
                '())])))]))
