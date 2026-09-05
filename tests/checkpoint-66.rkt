#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         (only-in "../aloe/main.rkt" make-top-level-env)
         "../aloe/parse.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))

(define (load-runtime! path)
  (eval-expr
   (parse-datum `(load ,(path->string path)))
   environment))

(load-runtime! gel-loop-path)
(load-runtime! point-path)

(void
 (eval-expr
  (parse-datum
   '(define stack
      (gel-start call (Point new 10 20))))
  environment))

;; Point has no show/text/name presentation, so Gel uses its object fallback.
(define tos-text
  (eval-expr (parse-datum '(gel-tos-text call stack)) environment))
(check-true (string? tos-text))
(check-regexp-match #rx"TOS" tos-text)
(check-regexp-match #rx"object" tos-text)

;; Int supplies its existing text message, proving the subject can be shown.
(check-equal?
 (eval-expr
  (parse-datum
   '(gel-tos-text call (gel-start call 10)))
  environment)
 "TOS: 10")

;; The existing Point menu remains unchanged.
(define menu-from-stack
  (eval-expr
   (parse-datum '(gel-menu-text call (gel-tos call stack)))
   environment))
(define menu-from-subject
  (eval-expr
   (parse-datum '(gel-menu-text call (Point new 10 20)))
   environment))
(check-equal? menu-from-stack menu-from-subject)
(check-regexp-match #rx"1  x  0" menu-from-stack)
