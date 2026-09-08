#lang racket/base

(require rackunit
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt" make-top-level-env)
         "../aloe/parse.rkt")

(define environment (make-top-level-env))

(define (eval-raw datum)
  (eval-expr (parse-datum datum) environment))

(void
 (eval-raw
  '(define-class Point
     (fields (x Int) (y Int))
     (methods))))

;; A matching clause receives payload values in field order.
(check-equal?
 (eval-raw
  '((Point new 1 2) case
     (new (x y) x)))
 1)
(check-equal?
 (eval-raw
  '((Point new 1 2) case
     (new (x y) y)))
 2)

;; An unmatched constructor selects else, and only the selected body runs.
(check-equal?
 (eval-raw
  '((Point new 1 2) case
     (Some (value) missing-unmatched-body)
     (else 0)))
 0)
(check-equal?
 (eval-raw
  '((Point new 1 2) case
     (new (x y) x)
     (else missing-else-body)))
 1)

;; The clause environment extends the method environment, retaining both
;; `self` and outer bindings while adding the payload names.
(env-define! environment 'offset 10)
(void
 (eval-raw
  '(define-class CasePoint
     (fields (x Int) (y Int))
     (methods
       (total () Int
         (self case
           (new (x y)
             ((x + (self y)) + offset))))))))
(check-equal? (eval-raw '((CasePoint new 1 2) total)) 13)

;; The scrutinee expression is evaluated exactly once.
(define scrutinee-evaluations 0)
(define point (eval-raw '(Point new 7 8)))
(define next-point
  (host-message
   0
   (lambda (_receiver _arguments)
     (set! scrutinee-evaluations (add1 scrutinee-evaluations))
     point)))
(env-define!
 environment
 'probe
 (host-receiver 'CaseProbe (hasheq 'next next-point) #f))
(check-equal?
 (eval-raw
  '((probe next) case
     (new (x y) (x + y))))
 15)
(check-equal? scrutinee-evaluations 1)

;; Runtime checks stay local to case evaluation in this checkpoint.
(check-exn
 #rx"case scrutinee is not an instance"
 (lambda ()
   (eval-raw
    '(1 case
       (new () #t)))))
(check-exn
 #rx"arity error for case constructor new"
 (lambda ()
   (eval-raw
    '((Point new 1 2) case
       (new (x) x)))))
(check-exn
 #rx"no matching case clause for constructor new"
 (lambda ()
   (eval-raw
    '((Point new 1 2) case
       (Some (value) value)))))
