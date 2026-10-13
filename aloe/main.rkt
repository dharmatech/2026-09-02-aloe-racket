#lang racket/base

(require (only-in racket/port port->bytes)
         (only-in "env.rkt"
                  [make-top-level-env make-runtime-environment])
         "eval.rkt"
         "library.rkt"
         "parse.rkt"
         (prefix-in checker: "type.rkt")
         (only-in (submod "type.rkt" load-cache)
                  typecheck-keyed-root
                  record-checked-libraries!))

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

(define make-raw-type-environment checker:make-type-environment)
(define type-of checker:type-of)
(define typecheck-program checker:typecheck-program)
(define type->datum checker:type->datum)
(define exn:fail:aloe-type? checker:exn:fail:aloe-type?)

(define (make-type-environment)
  (define environment (make-raw-type-environment))
  (typecheck-program (list-library-expressions) environment)
  (typecheck-program (string-library-expressions) environment)
  (typecheck-program (int-library-expressions) environment)
  (record-checked-libraries! environment)
  environment)

(define (make-top-level-env)
  (define environment (make-runtime-environment))
  (eval-exprs (list-library-expressions) environment)
  (eval-exprs (string-library-expressions) environment)
  (eval-exprs (int-library-expressions) environment)
  (record-evaluated-libraries! environment)
  (hash-set! runtime-type-environments
             environment
             (make-type-environment))
  environment)

(define (type-environment-for environment)
  (cond
    [(hash-ref runtime-type-environments environment #f) => values]
    [else
     (define type-environment (make-type-environment))
     (eval-exprs (list-library-expressions) environment)
     (eval-exprs (string-library-expressions) environment)
     (eval-exprs (int-library-expressions) environment)
     (record-evaluated-libraries! environment)
     (hash-set! runtime-type-environments environment type-environment)
     type-environment]))

(define (source-bytes input)
  (if (string? input)
      (string->bytes/utf-8 input)
      (port->bytes input)))

(define (typecheck-source input
                          [environment (make-type-environment)]
                          #:source-path [source-path #f])
  (cond
    [source-path
     (define-values (result _expressions)
       (typecheck-keyed-root environment source-path (source-bytes input)))
     result]
    [else
     (typecheck-program (read-program input) environment)]))

(define (eval-datum datum [environment (make-top-level-env)])
  (define expression (parse-datum datum))
  (type-of expression (type-environment-for environment))
  (eval-expr expression environment))

(define (eval-program datums [environment (make-top-level-env)])
  (define expressions (parse-program datums))
  (typecheck-program expressions (type-environment-for environment))
  (eval-exprs expressions environment))

(define (eval-source input
                     [environment (make-top-level-env)]
                     #:source-path [source-path #f])
  (cond
    [source-path
     (define input-bytes (source-bytes input))
     (define-values (_result expressions)
       (typecheck-keyed-root (type-environment-for environment)
                             source-path
                             input-bytes))
     (eval-keyed-root environment
                      source-path
                      input-bytes
                      expressions
                      (lambda (expressions)
                        (eval-exprs expressions environment)))]
    [else
     (define expressions (read-program input))
     (typecheck-program expressions (type-environment-for environment))
     (eval-exprs expressions environment)]))
