#lang racket/base

(provide (struct-out symbol-class-object)
         (struct-out symbol-value)
         intern-symbol)

(struct symbol-class-object () #:transparent)
(struct symbol-value (name) #:transparent)

(define interned-symbols (make-hash))

(define (intern-symbol name)
  (unless (string? name)
    (raise-argument-error 'Symbol-intern "string?" name))
  (define canonical-name (string->immutable-string name))
  (hash-ref!
   interned-symbols
   canonical-name
   (lambda () (symbol-value canonical-name))))
