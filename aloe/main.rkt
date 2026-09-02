#lang racket/base

(require (only-in "env.rkt"
                  [make-top-level-env make-runtime-environment])
         "eval.rkt"
         "parse.rkt"
         (prefix-in checker: "type.rkt"))

(provide make-top-level-env
         make-type-environment
         type-of
         typecheck-program
         typecheck-source
         type->datum
         exn:fail:aloe-type?
         eval-datum
         eval-program
         eval-source)

(define runtime-type-environments (make-weak-hasheq))

(define make-type-environment checker:make-type-environment)
(define type-of checker:type-of)
(define typecheck-program checker:typecheck-program)
(define type->datum checker:type->datum)
(define exn:fail:aloe-type? checker:exn:fail:aloe-type?)

(define (make-top-level-env)
  (define environment (make-runtime-environment))
  (hash-set! runtime-type-environments
             environment
             (make-type-environment))
  environment)

(define (type-environment-for environment)
  (cond
    [(hash-ref runtime-type-environments environment #f) => values]
    [else
     (define type-environment (make-type-environment))
     (hash-set! runtime-type-environments environment type-environment)
     type-environment]))

(define (typecheck-source input
                          [environment (make-type-environment)])
  (typecheck-program (read-program input) environment))

(define (eval-datum datum [environment (make-top-level-env)])
  (define expression (parse-datum datum))
  (type-of expression (type-environment-for environment))
  (eval-expr expression environment))

(define (eval-program datums [environment (make-top-level-env)])
  (define expressions (parse-program datums))
  (typecheck-program expressions (type-environment-for environment))
  (eval-exprs expressions environment))

(define (eval-source input [environment (make-top-level-env)])
  (define expressions (read-program input))
  (typecheck-program expressions (type-environment-for environment))
  (eval-exprs expressions environment))
