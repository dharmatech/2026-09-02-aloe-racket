#lang racket/base

(require racket/promise
         racket/runtime-path
         "parse.rkt")

(provide list-library-expressions)

(define-runtime-path list-library-path "../lib/list.aloe")

(define cached-list-library
  (delay
    (call-with-input-file list-library-path read-program)))

(define (list-library-expressions)
  (force cached-list-library))
