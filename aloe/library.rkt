#lang racket/base

(require racket/promise
         racket/runtime-path
         "parse.rkt")

(provide list-library-expressions
         string-library-expressions
         int-library-expressions)

(define-runtime-path list-library-path "../lib/list.aloe")
(define-runtime-path string-library-path "../lib/string.aloe")
(define-runtime-path int-library-path "../lib/int.aloe")

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

(define cached-int-library
  (delay
    (call-with-input-file int-library-path
      (lambda (input)
        (read-program input #:source-path int-library-path)))))

(define (list-library-expressions)
  (force cached-list-library))

(define (string-library-expressions)
  (force cached-string-library))

(define (int-library-expressions)
  (force cached-int-library))
