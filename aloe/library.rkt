#lang racket/base

(require racket/list
         racket/port
         racket/promise
         racket/runtime-path
         racket/string
         "parse.rkt")

(provide list-library-expressions
         string-library-expressions
         int-library-expressions
         list-library-bytes
         string-library-bytes
         int-library-bytes
         list-library-resolved-path
         string-library-resolved-path
         int-library-resolved-path
         resolved-source-path
         displayed-path)

(define-runtime-path repository-directory "..")
(define-runtime-path list-library-path "../lib/list.aloe")
(define-runtime-path string-library-path "../lib/string.aloe")
(define-runtime-path int-library-path "../lib/int.aloe")

;; A root resolves the way load-expr-resolved-path resolves a load, without
;; the filesystem, so two spellings of one file are one load-cache key.
(define (resolved-source-path source-path)
  (simplify-path (path->complete-path source-path) #f))

(define repository-elements
  (explode-path (resolved-source-path repository-directory)))

;; Messages show a path inside the repository relative to its root, with /
;; separators. The comparison is by path element, so a sibling directory whose
;; name extends the root's is outside.
(define (displayed-path path)
  (define elements (explode-path path))
  (define root-length (length repository-elements))
  (if (and (> (length elements) root-length)
           (equal? (take elements root-length) repository-elements))
      (string-join (map path->string (drop elements root-length)) "/")
      (path->string path)))

;; Each library is read once per process. The expressions are parsed from the
;; same bytes a base records for its load-cache seed.
(define (read-library path)
  (delay
    (define source-bytes (call-with-input-file path port->bytes))
    (cons source-bytes
          (read-program (open-input-bytes source-bytes)
                        #:source-path path))))

(define cached-list-library (read-library list-library-path))
(define cached-string-library (read-library string-library-path))
(define cached-int-library (read-library int-library-path))

(define list-library-resolved-path (resolved-source-path list-library-path))
(define string-library-resolved-path
  (resolved-source-path string-library-path))
(define int-library-resolved-path (resolved-source-path int-library-path))

(define (list-library-expressions)
  (cdr (force cached-list-library)))

(define (string-library-expressions)
  (cdr (force cached-string-library)))

(define (int-library-expressions)
  (cdr (force cached-int-library)))

(define (list-library-bytes)
  (car (force cached-list-library)))

(define (string-library-bytes)
  (car (force cached-string-library)))

(define (int-library-bytes)
  (car (force cached-int-library)))
