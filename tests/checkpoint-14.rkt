#lang racket/base

(require rackunit
         "../aloe/main.rkt")

;; Bool atoms and zero-argument function calls.
(check-equal? (eval-source "#t") #t)
(check-equal? (eval-source "#f") #f)
(check-equal? (type->datum (typecheck-source "#t")) 'Bool)
(check-equal? (eval-source "((fn () 9) call)") 9)

;; Comparisons are same-kind numeric messages that return Bool.
(check-equal? (eval-source "(1 < 2)") #t)
(check-equal? (eval-source "(2 < 1)") #f)
(check-equal? (eval-source "(1.0 < 2.0)") #t)
(check-equal? (eval-source "(2 > 1)") #t)
(check-equal? (eval-source "(2 <= 2)") #t)
(check-equal? (eval-source "(2 >= 3)") #f)
(check-equal? (eval-source "(2 = 2)") #t)
(check-exn exn:fail:aloe-type?
           (lambda () (eval-source "(1 < 2.0)")))

;; Bool.if calls only the selected zero-argument thunk.
(check-equal?
 (eval-source "((1 < 2) if (fn () 10) (fn () 20))")
 10)
(check-equal?
 (eval-source "((2 < 1) if (fn () 10) (fn () 20))")
 20)
(check-equal?
 (eval-source "((1 < 2) if (fn () 10) (fn () (1 / 0)))")
 10)
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (eval-source "(1 if (fn () 10) (fn () 20))")))

;; if is only a desugaring to Bool.if and two thunks.
(check-equal? (eval-source "(if (1 < 2) 10 20)") 10)
(check-equal? (eval-source "(if (2 < 1) 10 20)") 20)
(check-exn exn:fail:aloe-type?
           (lambda () (eval-source "(if (1 < 2) 10 20.0)")))
(check-exn exn:fail:aloe-type?
           (lambda () (eval-source "(if 1 10 20)")))
