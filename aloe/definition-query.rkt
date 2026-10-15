#lang racket/base

(require (only-in racket/port port->bytes)
         (only-in (submod "main.rkt" query-base)
                  base-library-path
                  typecheck-base-library-buffer
                  typecheck-file-module-buffer)
         (only-in "parse.rkt"
                  read-program)
         (only-in "private/definition-selection.rkt"
                  name-token-loc
                  name-token-owner
                  name-token-symbol
                  name-token-type-symbol?
                  select-name-token-at-position)
         (only-in (submod "type.rkt" definition-query-observation)
                  definition-jump-defining-path
                  definition-jump-name-loc
                  definition-jump-source-bytes
                  typecheck-program/definition-jump))

(provide (struct-out definition-query-result)
         query-definition-at)

(struct definition-query-result (location text) #:transparent)

(define (query-definition-at source-path
                             position
                             #:document-path [document-path source-path])
  (unless (path-string? source-path)
    (raise-argument-error
     'query-definition-at
     "path-string?"
     source-path))
  (unless (exact-positive-integer? position)
    (raise-argument-error
     'query-definition-at
     "exact-positive-integer?"
     position))
  (unless (path-string? document-path)
    (raise-argument-error
     'query-definition-at
     "path-string?"
     document-path))

  (define normalized-path
    (simplify-path (path->complete-path source-path) #f))
  (unless (file-exists? normalized-path)
    (raise-arguments-error
     'query-definition-at
     "source path does not name a regular file"
     "source path" normalized-path))

  (define source-bytes
    (call-with-input-file normalized-path port->bytes))
  (define expressions
    (read-program (open-input-bytes source-bytes)
                  #:source-path normalized-path))
  (define token
    (select-name-token-at-position expressions position))
  (define (observe expressions environment)
    (typecheck-program/definition-jump
     expressions
     environment
     (and token (name-token-owner token))
     (and token (name-token-symbol token))
     (and token (name-token-type-symbol? token) (name-token-loc token))))
  ;; The document path is the buffer's identity; the file read may be the LSP
  ;; adapter's sibling of it. Any buffer but a base library is a file module.
  (define library-path (base-library-path document-path))
  (define jump
    (if library-path
        (typecheck-base-library-buffer
         library-path source-bytes expressions observe)
        (typecheck-file-module-buffer
         document-path source-bytes expressions observe)))
  (and jump
       (definition-query-result
        (jump-location jump)
        (bytes->string/utf-8 (definition-jump-source-bytes jump)
                             (integer->char #xFFFD)))))

;; The class name's span, in the file that defined the class. The span's own
;; source may be the file that was read rather than that path.
(define (jump-location jump)
  (define name-loc (definition-jump-name-loc jump))
  (srcloc (definition-jump-defining-path jump)
          (srcloc-line name-loc)
          (srcloc-column name-loc)
          (srcloc-position name-loc)
          (srcloc-span name-loc)))
