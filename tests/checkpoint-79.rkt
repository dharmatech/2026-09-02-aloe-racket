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

(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define picks-79
  (GelPicks new
    (List of
      (GelPick new 1 (Mirror of 10))
      (GelPick new 2 (Mirror of 20)))))
(picks-79 len)
ALOE
   checker-environment))
 'Int)
(check-equal?
 (type->datum (typecheck-source "(picks-79 items)" checker-environment))
 '(List GelPick))
(check-equal?
 (type->datum (typecheck-source "(picks-79 select 2)" checker-environment))
 'GelPick)

;; Matching now returns the nominal collection rather than its backing list.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define point-rows-79 (gel-rows call (Point new 10 20)))
(define point-plus-row-79
  (point-rows-79 fold
    (point-rows-79 first)
    (fn (found row)
      (if (((row selector) name) = "+") row found))))
((gel-empty-stack push (Point new 1 2))
 matching-picks point-plus-row-79)
ALOE
   checker-environment))
 'GelPicks)
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source
    "(gel-menu-text picks-text (picks-79 items))"
    checker-environment)))

;; The separate raw-list selector and its class are gone.
(for ([name '(GelSelectPick gel-select-pick)])
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

;; The nominal collection owns its length and valid one-based selection.
(void
 (eval-source
  #<<ALOE
(define direct-picks-79
  (GelPicks new
    (List of
      (GelPick new 1 (Mirror of 10))
      (GelPick new 2 (Mirror of 20)))))
ALOE
  environment))
(check-equal? (eval-source "(direct-picks-79 len)" environment) 2)
(check-equal?
 (eval-source "(((direct-picks-79 select 1) mirror) subject)" environment)
 10)
(check-equal?
 (eval-source "(((direct-picks-79 select 2) mirror) subject)" environment)
 20)
(check-eq? (eval-source "((direct-picks-79 items) first)" environment)
           (eval-source "(direct-picks-79 select 1)" environment))
(check-eq? (eval-source "(((direct-picks-79 items) rest) first)" environment)
           (eval-source "(direct-picks-79 select 2)" environment))

;; Matching keeps the former filter, compact numbering, and stack order.
(void
 (eval-source
  #<<ALOE
(define point-79 (Point new 10 20))
(define point-rows-79 (gel-rows call point-79))
(define point-plus-row-79
  (point-rows-79 fold
    (point-rows-79 first)
    (fn (found row)
      (if (((row selector) name) = "+") row found))))
(define matching-stack-79
  (((gel-empty-stack push (Point new 1 2)) push 99) push point-79))
(define matching-picks-79
  (matching-stack-79 matching-picks point-plus-row-79))
ALOE
  environment))
(check-equal? (eval-source "(matching-picks-79 len)" environment) 2)
(check-equal? (eval-source "((matching-picks-79 items) len)" environment) 2)
(check-equal? (eval-source "((matching-picks-79 select 1) index)" environment)
              1)
(check-equal? (eval-source "((matching-picks-79 select 2) index)" environment)
              2)
(check-equal?
 (eval-source "(((matching-picks-79 select 1) mirror) raw)" environment)
 "#<Point 10 20>")
(check-equal?
 (eval-source "(((matching-picks-79 select 2) mirror) raw)" environment)
 "#<Point 1 2>")
(check-equal?
 (eval-source "(gel-menu-text picks-text matching-picks-79)" environment)
 "1  #<Point 10 20>\r\n2  #<Point 1 2>\r\n")

;; GelStep retains the bounds check and invokes the selected valid pick.
(void
 (eval-source
  #<<ALOE
(define pending-79
  (GelStep new matching-stack-79
    #f (List of point-plus-row-79) 0 #f))
(define out-of-range-79 (pending-79 handle-key "3"))
(define selected-79 (pending-79 handle-key "2"))
ALOE
  environment))
(check-eq? (eval-source "pending-79" environment)
           (eval-source "out-of-range-79" environment))
(check-equal?
 (eval-source "(((selected-79 stack) tos) raw)" environment)
 "#<Point 11 22>")
(check-equal? (eval-source "((selected-79 pending) len)" environment) 0)
