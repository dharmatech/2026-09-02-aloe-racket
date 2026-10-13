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
                  typecheck-keyed-buffer
                  record-checked-libraries!
                  record-checked-option-class!))

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
  (typecheck-program (option-library-expressions) environment)
  (record-checked-option-class! environment)
  (record-checked-libraries! environment)
  environment)

(define (make-top-level-env)
  (define environment (make-runtime-environment))
  (eval-exprs (list-library-expressions) environment)
  (eval-exprs (string-library-expressions) environment)
  (eval-exprs (int-library-expressions) environment)
  (eval-exprs (option-library-expressions) environment)
  (record-evaluated-option-class! environment)
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
     (eval-exprs (option-library-expressions) environment)
     (record-evaluated-option-class! environment)
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

;; The base libraries in install order, by resolved path.
(define base-libraries
  (list (cons list-library-resolved-path list-library-expressions)
        (cons string-library-resolved-path string-library-expressions)
        (cons int-library-resolved-path int-library-expressions)
        (cons option-library-resolved-path option-library-expressions)))

;; The resolved path when a query's identity path names a base library.
(define (base-library-path identity-path)
  (define path (resolved-source-path identity-path))
  (and (assoc path base-libraries) path))

;; A query of a base library does not check the buffer on top of an installed
;; copy. Its fresh base installs the other libraries and then the buffer, last,
;; as the query's one root check, keyed by the library's path.
(define (typecheck-base-library-buffer library-path
                                       source-bytes
                                       expressions
                                       observe)
  (define environment (make-raw-type-environment))
  (for ([library (in-list base-libraries)]
        #:unless (equal? (car library) library-path))
    (typecheck-program ((cdr library)) environment)
    (when (equal? (car library) option-library-resolved-path)
      (record-checked-option-class! environment)))
  (record-checked-libraries! environment #:except library-path)
  (begin0
    (typecheck-keyed-buffer environment
                            library-path
                            source-bytes
                            (lambda () (observe expressions environment)))
    (when (equal? library-path option-library-resolved-path)
      (record-checked-option-class! environment))))

;; The editor queries install a queried base library through these hooks.
(module* query-base #f
  (provide base-library-path
           typecheck-base-library-buffer))
