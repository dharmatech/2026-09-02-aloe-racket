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
(void
 (eval-source
  #<<ALOE
(define-class PointProbe67
  (fields)
  (methods
    (x-of (point (Point Int)) Int (point x))
    (y-of (point (Point Int)) Int (point y))))
ALOE
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

;; Int + takes the value beneath TOS: 10 receives + with argument 2.
(void
 (eval-source
  "(define int-stack (gel-start-two call 2 10))"
  environment))
(void (eval-source "(define int-rows (gel-rows call 10))" environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(void (eval-source "(define int-plus-key ((int-plus-row index) text))"
                   environment))
(void
 (eval-source
  "(define int-step (gel-handle-key call int-stack int-plus-key))"
  environment))
(check-false (eval-source "(int-step quit)" environment))
(check-equal?
 (eval-source "((gel-tos call (int-step stack)) subject)" environment)
 12)

;; Point + uses the Point under TOS and pushes the resulting Point.
(void
 (eval-source
  (string-append
   "(define point-stack\n"
   "  (gel-start-two call\n"
   "    (Point new 1 2)\n"
   "    (Point new 10 20)))")
  environment))
(void
 (eval-source
  "(define point-rows (gel-rows call (Point new 10 20)))"
  environment))
(void (bind-row! "point-plus-row" "point-rows" "+" 1))
(void (eval-source "(define point-plus-key ((point-plus-row index) text))"
                   environment))
(void
 (eval-source
  "(define point-step (gel-handle-key call point-stack point-plus-key))"
  environment))
(check-false (eval-source "(point-step quit)" environment))
(check-equal?
 (eval-source
  "((PointProbe67 new) x-of ((gel-tos call (point-step stack)) subject))"
  environment)
 11)
(check-equal?
 (eval-source
  "((PointProbe67 new) y-of ((gel-tos call (point-step stack)) subject))"
  environment)
 22)

;; With no argument mirror beneath TOS, an arity-one selection is a no-op.
(void (eval-source "(define one-stack (gel-start call 10))" environment))
(void
 (eval-source
  "(define one-step (gel-handle-key call one-stack int-plus-key))"
  environment))
(check-false (eval-source "(one-step quit)" environment))
(check-eq? (eval-source "one-stack" environment)
           (eval-source "(one-step stack)" environment))
