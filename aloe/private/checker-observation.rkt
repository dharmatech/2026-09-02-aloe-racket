#lang racket/base

(require (only-in "../parse.rkt"
                  method-declaration-body
                  send-expr-receiver)
         (only-in "expression-selection.rkt"
                  expression-contains-node?))

(provide (struct-out expression-type-observation)
         (struct-out selector-receiver-observation)
         make-checker-observation-api)

(struct expression-type-observation (type signatures pathed-type)
  #:transparent)
(struct selector-receiver-observation (signatures) #:transparent)

(struct retained-expression-type (expression type environment))
(struct expression-observer
  (target root-depth [retained #:mutable] [answer #:mutable]))
(struct selector-receiver-observer (target escape))
;; A definition observer waits for the owner of one name token, and for a type
;; symbol also its span, or #f for any other token. A variable's type is
;; retained until its root form ends; once the token is observed, the record is
;; its class record, or #f for nothing.
(struct definition-observer
  (owner type-loc root-depth
         [retained #:mutable]
         [observed? #:mutable]
         [record #:mutable]))

(define (make-checker-observation-api
         typecheck-program
         current-typecheck-program-depth
         type->datum
         type->pathed-datum
         type-signature-specs
         resolve-type
         class-type?
         class-type-class)
  (define current-expression-observer (make-parameter #f))
  (define current-selector-receiver-observer (make-parameter #f))
  (define current-definition-observer (make-parameter #f))
  (define current-legacy-deferred-generic-instantiation?
    (make-parameter #f))

  (define (typecheck-program/observe
           expressions environment selected-expression)
    (define observer
      (expression-observer
       selected-expression
       (add1 (current-typecheck-program-depth))
       #f
       #f))
    (parameterize ([current-expression-observer observer])
      (typecheck-program expressions environment))
    (cond
      [(not selected-expression) #f]
      [(expression-observer-answer observer)
       (expression-observer-answer observer)]
      [else
       (error
        'typecheck-program/observe
        "successful program did not observe the selected expression")]))

  (define (typecheck-program/observe-selector-receiver
           expressions environment target-send)
    (let/ec escape
      (define observer
        (selector-receiver-observer
         (send-expr-receiver target-send)
         escape))
      (parameterize ([current-selector-receiver-observer observer])
        (typecheck-program expressions environment))
      (error
       'typecheck-program/observe-selector-receiver
       "successful program did not observe the target send receiver")))

  ;; The class record the owner names, or #f; a program with no owner observes
  ;; nothing and answers #f.
  (define (typecheck-program/observe-definition
           expressions environment owner type-loc)
    (define observer
      (definition-observer
       owner
       type-loc
       (add1 (current-typecheck-program-depth))
       #f
       #f
       #f))
    (parameterize ([current-definition-observer observer])
      (typecheck-program expressions environment))
    (cond
      [(not owner) #f]
      [(definition-observer-observed? observer)
       (definition-observer-record observer)]
      [else
       (error
        'typecheck-program/observe-definition
        "successful program did not observe the definition owner")]))

  ;; The definition observer active for owner, unless it waits for a type
  ;; symbol, it already observed, or a deferred generic body is re-checked for
  ;; a concrete send.
  (define (waiting-definition-observer owner)
    (define observer (current-definition-observer))
    (and observer
         (not (definition-observer-type-loc observer))
         (not (definition-observer-observed? observer))
         (eq? owner (definition-observer-owner observer))
         (not (current-legacy-deferred-generic-instantiation?))
         observer))

  (define (observe-definition! observer record)
    (set-definition-observer-retained! observer #f)
    (set-definition-observer-record! observer record)
    (set-definition-observer-observed?! observer #t))

  (define (binding-class-record type)
    (and (class-type? type) (class-type-class type)))

  (define (retain-definition-observation! expression type)
    (define observer (waiting-definition-observer expression))
    (when observer
      (set-definition-observer-retained! observer type)))

  ;; A define-class name or define-methods target is observed at once, by the
  ;; binding its form checked.
  (define (observe-definition-binding! expression type)
    (define observer (waiting-definition-observer expression))
    (when observer
      (observe-definition! observer (binding-class-record type))))

  ;; A type symbol is observed where its annotation is declared, by the class
  ;; record it resolved to there, or #f.
  (define (observe-definition-type-symbol! loc record)
    (define observer (current-definition-observer))
    (when (and observer
               loc
               (eq? loc (definition-observer-type-loc observer))
               (not (definition-observer-observed? observer))
               (not (current-legacy-deferred-generic-instantiation?)))
      (observe-definition! observer record)))

  (define (retain-expression-observation! expression type environment)
    (define observer (current-expression-observer))
    (when (and observer
               (not (expression-observer-answer observer))
               (eq? expression (expression-observer-target observer))
               (not (current-legacy-deferred-generic-instantiation?)))
      (set-expression-observer-retained!
       observer
       (retained-expression-type expression type environment))))

  (define (observe-selector-receiver! expression type environment)
    (define observer (current-selector-receiver-observer))
    (when (and observer
               (eq? expression
                    (selector-receiver-observer-target observer))
               (not (current-legacy-deferred-generic-instantiation?)))
      ((selector-receiver-observer-escape observer)
       (selector-receiver-observation
        (type-signature-specs type environment)))))

  ;; Both observers that retain an expression's type resolve it at the end of
  ;; the root form that encloses it.
  (define (materialize-expression-observation-at-root-end!)
    (materialize-expression-type-at-root-end!)
    (materialize-definition-at-root-end!))

  (define (materialize-definition-at-root-end!)
    (define observer (current-definition-observer))
    (when (and observer
               (= (current-typecheck-program-depth)
                  (definition-observer-root-depth observer))
               (definition-observer-retained observer)
               (not (definition-observer-observed? observer)))
      (observe-definition!
       observer
       (binding-class-record
        (resolve-type (definition-observer-retained observer))))))

  (define (materialize-expression-type-at-root-end!)
    (define observer (current-expression-observer))
    (when (and observer
               (= (current-typecheck-program-depth)
                  (expression-observer-root-depth observer))
               (expression-observer-retained observer)
               (not (expression-observer-answer observer)))
      (define retained (expression-observer-retained observer))
      (define type (retained-expression-type-type retained))
      (define environment
        (retained-expression-type-environment retained))
      (define answer
        (expression-type-observation
         (type->datum type)
         (type-signature-specs type environment)
         (type->pathed-datum type)))
      (set-expression-observer-answer! observer answer)
      (set-expression-observer-retained! observer #f)))

  (define (selected-expression-in-method-body? method)
    (define expression-observer (current-expression-observer))
    (define selector-observer (current-selector-receiver-observer))
    (define definition-observer (current-definition-observer))
    (define targets
      (filter
       values
       (list
        (and expression-observer
             (expression-observer-target expression-observer))
        (and selector-observer
             (selector-receiver-observer-target selector-observer))
        (and definition-observer
             (definition-observer-owner definition-observer)))))
    (for/or ([target (in-list targets)])
      (expression-contains-node?
       (method-declaration-body method)
       target)))

  (values
   current-legacy-deferred-generic-instantiation?
   typecheck-program/observe
   typecheck-program/observe-selector-receiver
   typecheck-program/observe-definition
   retain-expression-observation!
   observe-selector-receiver!
   retain-definition-observation!
   observe-definition-binding!
   observe-definition-type-symbol!
   materialize-expression-observation-at-root-end!
   selected-expression-in-method-body?))
