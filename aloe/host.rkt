#lang racket/base

(provide (struct-out host-message)
         (struct-out host-receiver)
         host-receiver-send)

;; A host receiver is an explicitly injected Aloe value. Its messages use the
;; ordinary receiver/selector/arguments send shape, but their implementations
;; live in Racket. This module deliberately knows nothing about terminals.
(struct host-message (arity procedure) #:transparent)
(struct host-receiver (name messages state) #:transparent)

(define (host-receiver-send receiver selector arguments)
  (define message
    (hash-ref (host-receiver-messages receiver) selector #f))
  (unless message
    (error 'eval-aloe "unknown message: ~a" selector))
  (define expected (host-message-arity message))
  (define actual (length arguments))
  (unless (= expected actual)
    (error 'eval-aloe
           "arity error for ~a ~a: expected ~a argument(s), got ~a"
           (host-receiver-name receiver)
           selector
           expected
           actual))
  ((host-message-procedure message) receiver arguments))
