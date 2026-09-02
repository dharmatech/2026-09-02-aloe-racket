#lang racket/base

(provide top-level-env?
         (struct-out list-class-object)
         make-top-level-env
         make-local-env
         env-lookup
         env-define!)

(struct top-level-env (bindings parent))
(struct dummy-object ())
(struct list-class-object ([methods #:mutable] [environment #:mutable]))

(define (make-top-level-env)
  (top-level-env
   (make-hasheq (list (cons 'dummy (dummy-object))
                      (cons 'List (list-class-object '() #f))))
   #f))

(define (make-local-env parent bindings)
  (top-level-env (make-hasheq bindings) parent))

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
