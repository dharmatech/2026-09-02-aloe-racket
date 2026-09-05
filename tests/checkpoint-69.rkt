#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(define (bind-row! name rows selector arity)
  (eval-source
   (format
    (string-append
     "(define ~a\n"
     "  (~a fold\n"
     "    (~a first)\n"
     "    (fn (found row)\n"
     "      (if (((row selector) name) = ~s)\n"
     "          (if ((row arity) = ~a) row found)\n"
     "          found))))")
    name
    rows
    rows
    selector
    arity)
   environment))

(void (eval-source "(define int-rows (gel-rows call 10))" environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(void (eval-source "(define int-plus-key ((int-plus-row index) text))"
                   environment))

;; 10 is TOS and 2 is the second matching slot. Selecting + only records the
;; row; selecting pick 2 then invokes that exact row with 2.
(void
 (eval-source
  "(define int-stack ((gel-empty-stack push 2) push 10))"
  environment))
(void
 (eval-source
  "(define int-state (GelStep new int-stack #f (List empty) 0 #f))"
  environment))
(void
 (eval-source
  "(define int-pending (int-state handle-key int-plus-key))"
  environment))
(check-false (eval-source "(int-pending quit)" environment))
(check-eq? (eval-source "int-stack" environment)
           (eval-source "(int-pending stack)" environment))
(check-equal? (eval-source "((int-pending pending) len)" environment) 1)

(define pending-menu
  (eval-source "(gel-menu-text call int-pending)" environment))
(check-regexp-match #rx"pending" pending-menu)
(check-regexp-match #rx"\\+" pending-menu)
(check-regexp-match #rx"Int" pending-menu)
(check-false (regexp-match? #rx"1  10" pending-menu))

(void
 (eval-source
  "(define int-digit (int-pending handle-key \"2\"))"
  environment))
(check-equal? (eval-source "(int-digit int-input)" environment) 2)
(check-true (eval-source "(int-digit has-digits)" environment))
(void
 (eval-source
  "(define int-result (int-digit handle-key \"return\"))"
  environment))
(check-false (eval-source "(int-result quit)" environment))
(check-equal? (eval-source "((int-result pending) len)" environment) 0)
(check-equal?
 (eval-source "(((int-result stack) tos) subject)" environment)
 12)

;; Non-Int holes retain checkpoint 69's typed stack picks. Int does not appear
;; among the matching Point picks, so compact pick 2 remains missing.
(void (eval-source "(define point (Point new 10 20))" environment))
(void (eval-source "(define point-rows (gel-rows call point))" environment))
(void (bind-row! "point-plus-row" "point-rows" "+" 1))
(void (eval-source "(define point-plus-key ((point-plus-row index) text))"
                   environment))
(void
 (eval-source
  (string-append
   "(define mixed-stack\n"
   "  ((gel-empty-stack push 10) push point))")
  environment))
(void
 (eval-source
  "(define mixed-state (GelStep new mixed-stack #f (List empty) 0 #f))"
  environment))
(void
 (eval-source
  "(define mixed-pending (mixed-state handle-key point-plus-key))"
  environment))
(define mixed-menu
  (eval-source "(gel-menu-text call mixed-pending)" environment))
(check-regexp-match #rx"1  #<Point 10 20>" mixed-menu)
(check-false (regexp-match? #rx"2  " mixed-menu))
(void
 (eval-source
  "(define mixed-pick (mixed-pending handle-key \"2\"))"
  environment))
(check-eq? (eval-source "mixed-pending" environment)
           (eval-source "mixed-pick" environment))
(check-equal? (eval-source "((mixed-pick pending) len)" environment) 1)

;; Even a one-item Point stack may select +; it becomes pending and does not
;; invoke until a stack pick is made.
(void (eval-source "(define point-stack (gel-empty-stack push point))"
                   environment))
(void
 (eval-source
  "(define point-state (GelStep new point-stack #f (List empty) 0 #f))"
  environment))
(void
 (eval-source
  "(define point-pending (point-state handle-key point-plus-key))"
  environment))
(check-false (eval-source "(point-pending quit)" environment))
(check-eq? (eval-source "point-stack" environment)
           (eval-source "(point-pending stack)" environment))
(check-equal? (eval-source "((point-pending pending) len)" environment) 1)

;; q cancels a pending row but does not request application exit.
(void
 (eval-source
  "(define cancelled (point-pending handle-key \"q\"))"
  environment))
(check-false (eval-source "(cancelled quit)" environment))
(check-eq? (eval-source "point-stack" environment)
           (eval-source "(cancelled stack)" environment))
(check-equal? (eval-source "((cancelled pending) len)" environment) 0)
