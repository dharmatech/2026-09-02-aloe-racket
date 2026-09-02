#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(check-exn #rx"unknown message"
           (lambda () (eval-source "(dummy no-such)")))

(check-exn #rx"no selector"
           (lambda () (eval-source "(dummy)")))

(check-exn #rx"empty combination"
           (lambda () (eval-source "()")))

(check-exn #rx"selector must be a symbol"
           (lambda () (eval-source "(dummy 1)")))

(check-exn #rx"unknown message: sel"
           (lambda ()
             (eval-source "(define sel dummy)\n(dummy sel)")))
