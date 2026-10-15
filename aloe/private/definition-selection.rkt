#lang racket/base

(require racket/list
         racket/match
         "../parse.rkt"
         (only-in "expression-selection.rkt"
                  expression-children))

(provide (struct-out name-token)
         select-name-token-at-position)

;; A name token is a symbol a definition query can jump from: a variable, the
;; class name of a define-class header, the target of a define-methods form, or
;; a type symbol in an annotation. Its owner is the node the checker observes
;; for it; a type symbol's is the form that holds the annotation, and the
;; checker observes it by its loc.
(struct name-token (owner symbol loc type-symbol?) #:transparent)

(define (expression-name-tokens expression)
  (match expression
    [(variable-expr name loc)
     (list (name-token expression name loc #f))]
    [(define-class-expr name _ _ fields constructors methods _ name-loc)
     (cons (name-token expression name name-loc #f)
           (append
            (append-map
             (lambda (field) (field-type-tokens expression field))
             (append (or fields '())
                     (append-map constructor-declaration-fields
                                 (or constructors '()))))
            (append-map
             (lambda (method) (method-type-tokens expression method))
             methods)))]
    [(define-methods-expr target methods _ target-loc)
     (cons (name-token expression target target-loc #f)
           (append-map
            (lambda (method) (method-type-tokens expression method))
            methods))]
    [(define-protocol-expr _ signatures _)
     (append-map
      (lambda (signature) (method-type-tokens expression signature))
      signatures)]
    [_ '()]))

(define (field-type-tokens owner field)
  (type-tokens owner
               (field-declaration-type field)
               (field-declaration-type-spans field)))

(define (method-type-tokens owner method)
  (append
   (append-map
    (lambda (parameter)
      (type-tokens owner
                   (parameter-declaration-type parameter)
                   (parameter-declaration-type-spans parameter)))
    (method-declaration-parameters method))
   (type-tokens owner
                (method-declaration-return-type method)
                (method-declaration-return-type-spans method))))

;; Walks a type datum and its span tree together. A symbol that meets a span is
;; a token, and a list meets a list of the same length; anything else holds no
;; token.
(define (type-tokens owner datum spans)
  (cond
    [(and (symbol? datum) (srcloc? spans))
     (list (name-token owner datum spans #t))]
    [(and (list? datum)
          (list? spans)
          (= (length datum) (length spans)))
     (append-map (lambda (element element-spans)
                   (type-tokens owner element element-spans))
                 datum
                 spans)]
    [else '()]))

;; Tokens never overlap, so at most one contains the position.
(define (select-name-token-at-position expressions position)
  (define (containing? token)
    (define loc (name-token-loc token))
    (and loc
         (<= (srcloc-position loc) position)
         (< position
            (+ (srcloc-position loc)
               (srcloc-span loc)))))

  (define (visit expression)
    (or (for/first ([token (in-list (expression-name-tokens expression))]
                    #:when (containing? token))
          token)
        (for/or ([child (in-list (expression-children expression))])
          (visit child))))

  (for/or ([expression (in-list expressions)])
    (visit expression)))
