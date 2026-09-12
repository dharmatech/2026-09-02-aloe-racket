#lang racket/base

(require "host.rkt"
         "parse.rkt")

(provide (struct-out signature-spec)
         kernel-instance-signature-specs
         kernel-class-object-signature-specs
         kernel-instance-signature-count
         field-declarations->signature-specs
         constructor-declarations->signature-specs
         method-declarations->signature-specs
         host-method-declarations->signature-specs
         make-call-signature-spec
         substitute-signature-spec
         substitute-signature-specs)

;; A signature catalog row is deliberately declarative. Runtime ownership,
;; exact-row invocation metadata, and checker types belong to its consumers.
(struct signature-spec (selector parameters return) #:transparent)

(define int-instance-signatures
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
        (signature-spec 'text '() 'String)))

(define float-instance-signatures
  (list (signature-spec '+ '(Float) 'Float)
        (signature-spec '- '(Float) 'Float)
        (signature-spec '* '(Float) 'Float)
        (signature-spec '/ '(Float) 'Float)
        (signature-spec '< '(Float) 'Bool)
        (signature-spec '> '(Float) 'Bool)
        (signature-spec '<= '(Float) 'Bool)
        (signature-spec '>= '(Float) 'Bool)
        (signature-spec '= '(Float) 'Bool)))

(define bool-instance-signatures
  (list (signature-spec 'if '((-> T) (-> T)) 'T)))

(define string-instance-signatures
  (list (signature-spec '= '(String) 'Bool)
        (signature-spec 'append '(String) 'String)
        (signature-spec 'len '() 'Int)
        (signature-spec 'take '(Int) 'String)))

(define symbol-instance-signatures
  (list (signature-spec 'name '() 'String)
        (signature-spec '= '(Symbol) 'Bool)))

(define mirror-instance-signatures
  (list (signature-spec 'messages '() '(List Symbol))
        (signature-spec 'signatures '() '(List Signature))
        (signature-spec 'invoke '(Signature) 'U)
        (signature-spec 'subject '() 'U)
        (signature-spec 'raw '() 'String)))

(define signature-instance-signatures
  (list (signature-spec 'selector '() 'Symbol)
        (signature-spec 'params '() '(List TypeData))
        (signature-spec 'return '() 'TypeData)
        (signature-spec 'accepts? '(Mirror) 'Bool)))

(define list-instance-signature-template
  (list (signature-spec 'empty? '() 'Bool)
        (signature-spec 'first '() 'T)
        (signature-spec 'rest '() '(List T))
        (signature-spec 'cons '(T) '(List T))
        (signature-spec 'len '() 'Int)))

(define list-class-object-signatures
  (list (signature-spec 'of '(T) '(List T))
        (signature-spec 'empty '() '(List T))))

(define symbol-class-object-signatures
  (list (signature-spec 'intern '(String) 'Symbol)))

(define mirror-class-object-signatures
  (list (signature-spec 'of '(T) 'Mirror)))

(define (kernel-instance-signature-specs name)
  (case name
    [(Int) int-instance-signatures]
    [(Float) float-instance-signatures]
    [(Bool) bool-instance-signatures]
    [(String) string-instance-signatures]
    [(Symbol) symbol-instance-signatures]
    [(Mirror) mirror-instance-signatures]
    [(Signature) signature-instance-signatures]
    [(List) list-instance-signature-template]
    [else
     (raise-argument-error
      'kernel-instance-signature-specs
      "kernel instance type name"
      name)]))

(define (kernel-class-object-signature-specs name)
  (case name
    [(List) list-class-object-signatures]
    [(String) '()]
    [(Symbol) symbol-class-object-signatures]
    [(Mirror) mirror-class-object-signatures]
    [else
     (raise-argument-error
      'kernel-class-object-signature-specs
      "bound kernel class-object name"
      name)]))

(define (kernel-instance-signature-count name)
  (length (kernel-instance-signature-specs name)))

(define (substitute-type-datum datum substitution)
  (cond
    [(and (symbol? datum) (hash-has-key? substitution datum))
     (hash-ref substitution datum)]
    [(list? datum)
     (map (lambda (part)
            (substitute-type-datum part substitution))
          datum)]
    [else datum]))

(define (substitute-signature-spec spec substitution)
  (signature-spec
   (signature-spec-selector spec)
   (map (lambda (parameter)
          (substitute-type-datum parameter substitution))
        (signature-spec-parameters spec))
   (substitute-type-datum (signature-spec-return spec) substitution)))

(define (substitute-signature-specs specs substitution)
  (map (lambda (spec)
         (substitute-signature-spec spec substitution))
       specs))

(define (field-declarations->signature-specs
         fields
         [substitution (hasheq)])
  (for/list ([field (in-list fields)])
    (substitute-signature-spec
     (signature-spec
      (field-declaration-name field)
      '()
      (field-declaration-type field))
     substitution)))

(define (constructor-declarations->signature-specs
         constructors
         instance-type-datum
         [substitution (hasheq)])
  (for/list ([constructor (in-list constructors)])
    (substitute-signature-spec
     (signature-spec
      (constructor-declaration-selector constructor)
      (map field-declaration-type
           (constructor-declaration-fields constructor))
      instance-type-datum)
     substitution)))

(define (method-declarations->signature-specs
         methods
         [substitution (hasheq)])
  (for/list ([method (in-list methods)])
    (substitute-signature-spec
     (signature-spec
      (method-declaration-selector method)
      (map parameter-declaration-type
           (method-declaration-parameters method))
      (method-declaration-return-type method))
     substitution)))

(define (host-method-declarations->signature-specs methods)
  (for/list ([method (in-list methods)])
    (signature-spec
     (host-method-selector method)
     (host-method-parameter-types method)
     (host-method-return-type method))))

(define (make-call-signature-spec parameter-type-data return-type-datum)
  (signature-spec 'call parameter-type-data return-type-datum))
