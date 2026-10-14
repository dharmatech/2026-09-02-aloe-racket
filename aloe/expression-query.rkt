#lang racket/base

(require (only-in racket/port port->bytes)
         (only-in (submod "main.rkt" query-base)
                  base-library-path
                  typecheck-base-library-buffer
                  typecheck-file-module-buffer)
         (only-in "parse.rkt"
                  expression-loc
                  read-program)
         (only-in "private/expression-selection.rkt"
                  select-expression-at-position)
         "signature-catalog.rkt"
         (only-in (submod "type.rkt" expression-query-observation)
                  expression-type-observation-pathed-type
                  expression-type-observation-signatures
                  expression-type-observation-type
                  typecheck-program/observe))

(provide (struct-out expression-query-result)
         (struct-out signature-spec)
         query-expression-at)

(struct expression-query-result (type signatures location pathed-type)
  #:transparent)

(define (query-expression-at source-path
                             position
                             #:document-path [document-path source-path])
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
  (unless (path-string? document-path)
    (raise-argument-error
     'query-expression-at
     "path-string?"
     document-path))

  (define normalized-path
    (simplify-path (path->complete-path source-path) #f))
  (unless (file-exists? normalized-path)
    (raise-arguments-error
     'query-expression-at
     "source path does not name a regular file"
     "source path" normalized-path))

  (define source-bytes
    (call-with-input-file normalized-path port->bytes))
  (define expressions
    (read-program (open-input-bytes source-bytes)
                  #:source-path normalized-path))
  (define selected
    (select-expression-at-position expressions position))
  (define (observe expressions environment)
    (typecheck-program/observe expressions environment selected))
  ;; The document path is the buffer's identity; the file read may be the LSP
  ;; adapter's sibling of it. Any buffer but a base library is a file module.
  (define library-path (base-library-path document-path))
  (define observation
    (if library-path
        (typecheck-base-library-buffer
         library-path source-bytes expressions observe)
        (typecheck-file-module-buffer
         document-path source-bytes expressions observe)))
  (and observation
       (expression-query-result
        (expression-type-observation-type observation)
        (expression-type-observation-signatures observation)
        (expression-loc selected)
        (expression-type-observation-pathed-type observation))))
