#lang racket/base

(require (only-in "main.rkt"
                  make-type-environment)
         (only-in "parse.rkt"
                  expression-loc
                  read-program)
         (only-in "private/expression-selection.rkt"
                  select-expression-at-position)
         "signature-catalog.rkt"
         (only-in (submod "type.rkt" expression-query-observation)
                  expression-type-observation-signatures
                  expression-type-observation-type
                  typecheck-program/observe))

(provide (struct-out expression-query-result)
         (struct-out signature-spec)
         query-expression-at)

(struct expression-query-result (type signatures location) #:transparent)

(define (query-expression-at source-path position)
  (unless (path-string? source-path)
    (raise-argument-error
     'query-expression-at
     "path-string?"
     source-path))
  (unless (exact-positive-integer? position)
    (raise-argument-error
     'query-expression-at
     "exact-positive-integer?"
     position))

  (define normalized-path
    (simplify-path (path->complete-path source-path) #f))
  (unless (file-exists? normalized-path)
    (raise-arguments-error
     'query-expression-at
     "source path does not name a regular file"
     "source path" normalized-path))

  (define expressions
    (call-with-input-file
     normalized-path
     (lambda (input)
       (read-program input #:source-path normalized-path))))
  (define selected
    (select-expression-at-position expressions position))
  (define observation
    (typecheck-program/observe
     expressions
     (make-type-environment)
     selected))
  (and observation
       (expression-query-result
        (expression-type-observation-type observation)
        (expression-type-observation-signatures observation)
        (expression-loc selected))))
