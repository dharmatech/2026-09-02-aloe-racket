#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-equal? (eval-source "((List of 1 2 3) len)") 3)

(define mapped-source
  "((List of 1 2 3) map (fn (n) (n + 1)))")

(check-equal? (eval-source (string-append "(" mapped-source " len)")) 3)
(check-equal?
 (eval-source
  (string-append
   "(" mapped-source
   " fold 0 (fn (acc n) ((acc * 10) + n)))"))
 234)

(check-equal?
 (eval-source
  "((List of 1 2 3) fold 0 (fn (acc n) (acc + n)))")
 6)

(check-equal? (eval-source "((List of) len)") 0)

(check-exn #rx"unknown message"
           (lambda () (eval-source "((List of 1 2 3) no-such)")))

(check-exn #rx"unknown message"
           (lambda () (eval-source "(List new 1 2)")))
