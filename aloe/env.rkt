#lang racket/base

(require "mirror.rkt"
         "symbol.rkt")

(provide top-level-env?
         (struct-out list-class-object)
         (struct-out string-class-object)
         make-top-level-env
         make-local-env
         env-bound?
         env-lookup
         env-string-class
         env-define!)

(struct top-level-env (bindings parent string-class))
(struct dummy-object ())
(struct list-class-object ([methods #:mutable] [environment #:mutable]))
(struct string-class-object ([methods #:mutable] [environment #:mutable]))

(define (make-top-level-env)
  (define list-class (list-class-object '() #f))
  (define string-class (string-class-object '() #f))
  (top-level-env
   (make-hasheq (list (cons 'dummy (dummy-object))
                      (cons 'List list-class)
                      (cons 'String string-class)
                      (cons 'Symbol (symbol-class-object))
                      (cons 'Mirror (mirror-class-object list-class))))
   #f
   string-class))

(define (make-local-env parent bindings)
  (top-level-env
   (make-hasheq bindings)
   parent
   (top-level-env-string-class parent)))

(define (env-string-class environment)
  (top-level-env-string-class environment))

(define (env-bound? environment name)
  (cond
    [(hash-has-key? (top-level-env-bindings environment) name) #t]
    [(top-level-env-parent environment)
     (env-bound? (top-level-env-parent environment) name)]
    [else #f]))

(define (env-lookup environment name)
  (define bindings (top-level-env-bindings environment))
  (cond
    [(hash-has-key? bindings name)
     (hash-ref bindings name)]
    [(top-level-env-parent environment)
     (env-lookup (top-level-env-parent environment) name)]
    [else
     (error 'eval-aloe "unbound symbol: ~a" name)]))

(define (env-define! environment name value)
  (hash-set! (top-level-env-bindings environment) name value))
