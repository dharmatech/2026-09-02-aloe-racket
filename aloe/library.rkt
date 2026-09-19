#lang racket/base

(require racket/promise
         racket/runtime-path
         "parse.rkt")

(provide list-library-expressions
         string-library-expressions)

(define-runtime-path list-library-path "../lib/list.aloe")
(define-runtime-path string-library-path "../lib/string.aloe")

(define cached-list-library
  (delay
    (call-with-input-file list-library-path
      (lambda (input)
        (read-program input #:source-path list-library-path)))))

(define cached-string-library
  (delay
    (call-with-input-file string-library-path
      (lambda (input)
        (read-program input #:source-path string-library-path)))))

(define (list-library-expressions)
  (force cached-list-library))

(define (string-library-expressions)
  (force cached-string-library))
