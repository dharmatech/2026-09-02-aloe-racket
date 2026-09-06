#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define checker-environment (make-type-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string gel-loop-path))
  checker-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string point-path))
  checker-environment))

;; Matching is a GelStack message with the nominal GelPicks result.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define rows-80 (gel-rows of 10))
(define row-80
  (rows-80 fold
    (rows-80 first)
    (fn (found candidate)
      (if (((candidate selector) name) = "+") candidate found))))
(define stack-80
  (((gel-empty-stack push 2) push "skip") push 10))
(stack-80 matching-picks row-80)
ALOE
   checker-environment))
 'GelPicks)

;; The stateless callable and its class are gone.
(for ([name '(GelMatchingPicks gel-matching-picks)])
  (check-exn
   (regexp (format "unbound symbol: ~a" name))
   (lambda ()
     (typecheck-source (symbol->string name) checker-environment))))

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string gel-loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

;; Mixed slots are filtered by row.accepts?, then numbered compactly while
;; retaining stack order.
(void
 (eval-source
  #<<ALOE
(define rows-80 (gel-rows of 10))
(define row-80
  (rows-80 fold
    (rows-80 first)
    (fn (found candidate)
      (if (((candidate selector) name) = "+") candidate found))))
(define stack-80
  (((gel-empty-stack push 2) push "skip") push 10))
(define picks-80 (stack-80 matching-picks row-80))
ALOE
  environment))
(check-true (eval-source "(row-80 accepts? (Mirror of 10))" environment))
(check-false
 (eval-source "(row-80 accepts? (Mirror of \"skip\"))" environment))
(check-true (eval-source "(row-80 accepts? (Mirror of 2))" environment))
(check-equal? (eval-source "((stack-80 items) len)" environment) 3)
(check-equal? (eval-source "(picks-80 len)" environment) 2)
(check-equal? (eval-source "((picks-80 select 1) index)" environment) 1)
(check-equal? (eval-source "((picks-80 select 2) index)" environment) 2)
(check-equal?
 (eval-source "(((picks-80 select 1) mirror) subject)" environment)
 10)
(check-equal?
 (eval-source "(((picks-80 select 2) mirror) subject)" environment)
 2)

;; Pending menus and GelStep's valid/out-of-range key behavior use the stack
;; method without changing text, selection, or invocation results.
(void
 (eval-source
  #<<ALOE
(define point-80 (Point new 10 20))
(define point-rows-80 (gel-rows of point-80))
(define point-plus-row-80
  (point-rows-80 fold
    (point-rows-80 first)
    (fn (found candidate)
      (if (((candidate selector) name) = "+") candidate found))))
(define point-stack-80
  ((gel-empty-stack push (Point new 1 2)) push point-80))
(define point-pending-80
  (GelStep new point-stack-80
    #f (List of point-plus-row-80) 0 #f))
(define point-out-of-range-80 (point-pending-80 handle-key "3"))
(define point-selected-80 (point-pending-80 handle-key "2"))
ALOE
  environment))
(check-equal?
 (eval-source "(gel-text menu point-pending-80)" environment)
 (string-append
  "pending +  #<List #<Symbol Point> #<Symbol Int>>\r\n"
  "1  #<Point 10 20>\r\n"
  "2  #<Point 1 2>\r\n"))
(check-eq? (eval-source "point-pending-80" environment)
           (eval-source "point-out-of-range-80" environment))
(check-equal?
 (eval-source "(((point-selected-80 stack) tos) raw)" environment)
 "#<Point 11 22>")
(check-equal? (eval-source "((point-selected-80 pending) len)" environment) 0)
