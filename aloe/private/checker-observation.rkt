#lang racket/base

(require (only-in "../parse.rkt"
                  method-declaration-body
                  send-expr-receiver)
         (only-in "expression-selection.rkt"
                  expression-contains-node?))

(provide (struct-out expression-type-observation)
         (struct-out selector-receiver-observation)
         make-checker-observation-api)

(struct expression-type-observation (type signatures) #:transparent)
(struct selector-receiver-observation (signatures) #:transparent)

(struct retained-expression-type (expression type environment))
(struct expression-observer
  (target root-depth [retained #:mutable] [answer #:mutable]))
(struct selector-receiver-observer (target escape))

(define (make-checker-observation-api
         typecheck-program
         current-typecheck-program-depth
         type->datum
         type-signature-specs)
  (define current-expression-observer (make-parameter #f))
  (define current-selector-receiver-observer (make-parameter #f))
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

  (define (materialize-expression-observation-at-root-end!)
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
         (type-signature-specs type environment)))
      (set-expression-observer-answer! observer answer)
      (set-expression-observer-retained! observer #f)))

  (define (selected-expression-in-method-body? method)
    (define expression-observer (current-expression-observer))
    (define selector-observer (current-selector-receiver-observer))
    (define targets
      (filter
       values
       (list
        (and expression-observer
             (expression-observer-target expression-observer))
        (and selector-observer
             (selector-receiver-observer-target selector-observer)))))
    (for/or ([target (in-list targets)])
      (expression-contains-node?
       (method-declaration-body method)
       target)))

  (values
   current-legacy-deferred-generic-instantiation?
   typecheck-program/observe
   typecheck-program/observe-selector-receiver
   retain-expression-observation!
   observe-selector-receiver!
   materialize-expression-observation-at-root-end!
   selected-expression-in-method-body?))
