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

(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define state
  (GelStep new (gel-empty-stack push 10) #f (List empty) 0 #f))
(state handle-key "q")
ALOE
   checker-environment))
 'GelStep)

;; Key transitions belong to GelStep; the callable helper is gone.
(for ([name '(GelHandleKey gel-handle-key)])
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

(void
 (eval-source
  "(define point-stack (gel-empty-stack push (Point new 10 20)))"
  environment))
(void
 (eval-source
  (string-append
   "(define idle-state "
   "  (GelStep new point-stack #f (List empty) 0 #f))")
  environment))
(void
 (eval-source
  "(define point-rows (gel-rows of (point-stack tos)))"
  environment))
(void (bind-row! "point-x-row" "point-rows" "x" 0))
(void (bind-row! "point-plus-row" "point-rows" "+" 1))
(void (eval-source "(define point-x-key ((point-x-row index) text))"
                   environment))
(void (eval-source "(define point-plus-key ((point-plus-row index) text))"
                   environment))

;; Idle quit and no-op transitions preserve the original immutable state.
(void (eval-source "(define quit-state (idle-state handle-key \"q\"))"
                   environment))
(check-true (eval-source "(quit-state quit)" environment))
(check-false (eval-source "(idle-state quit)" environment))
(check-eq? (eval-source "(idle-state stack)" environment)
           (eval-source "(quit-state stack)" environment))
(void (eval-source "(define noop-state (idle-state handle-key \"0\"))"
                   environment))
(check-false (eval-source "(noop-state quit)" environment))
(check-eq? (eval-source "(idle-state stack)" environment)
           (eval-source "(noop-state stack)" environment))

;; A zero-arity row invokes immediately; an arity-one row becomes pending.
(void
 (eval-source
  "(define x-state (idle-state handle-key point-x-key))"
  environment))
(check-equal? (eval-source "(((x-state stack) tos) subject)" environment) 10)
(check-equal? (eval-source "(((x-state stack) items) len)" environment) 2)
(void
 (eval-source
  "(define point-pending (idle-state handle-key point-plus-key))"
  environment))
(check-equal? (eval-source "((point-pending pending) len)" environment) 1)
(check-eq? (eval-source "point-stack" environment)
           (eval-source "(point-pending stack)" environment))
(void
 (eval-source
  "(define point-cancelled (point-pending handle-key \"escape\"))"
  environment))
(check-false (eval-source "(point-cancelled quit)" environment))
(check-equal? (eval-source "((point-cancelled pending) len)" environment) 0)
(check-equal? (eval-source "((point-pending pending) len)" environment) 1)

;; Pending Int entry accumulates without changing the old state, then invokes.
(void (eval-source "(define int-stack (gel-empty-stack push 10))" environment))
(void
 (eval-source
  "(define int-state (GelStep new int-stack #f (List empty) 0 #f))"
  environment))
(void
 (eval-source
  "(define int-rows (gel-rows of (int-stack tos)))"
  environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(void (eval-source "(define int-plus-key ((int-plus-row index) text))"
                   environment))
(void
 (eval-source
  "(define int-pending (int-state handle-key int-plus-key))"
  environment))
(void
 (eval-source
  "(define int-two (int-pending handle-key \"2\"))"
  environment))
(check-false (eval-source "(int-pending has-digits)" environment))
(check-true (eval-source "(int-two has-digits)" environment))
(check-equal? (eval-source "(int-two int-input)" environment) 2)
(void
 (eval-source
  "(define int-result (int-two handle-key \"return\"))"
  environment))
(check-equal? (eval-source "(((int-result stack) tos) subject)" environment) 12)
(check-equal? (eval-source "((int-result pending) len)" environment) 0)

;; A non-Int pending row still accepts a typed pick from the stack.
(void
 (eval-source
  (string-append
   "(define two-point-stack "
   "  ((gel-empty-stack push (Point new 1 2)) "
   "   push (Point new 10 20)))")
  environment))
(void
 (eval-source
  (string-append
   "(define two-point-state "
   "  (GelStep new two-point-stack #f (List empty) 0 #f))")
  environment))
(void
 (eval-source
  "(define pick-pending (two-point-state handle-key point-plus-key))"
  environment))
(void
 (eval-source
  "(define pick-result (pick-pending handle-key \"2\"))"
  environment))
(check-equal?
 (eval-source "(((pick-result stack) tos) raw)" environment)
 "#<Point 11 22>")
(check-regexp-match #rx"[1-9]  x  0"
                    (eval-source "(gel-text menu idle-state)"
                                 environment))
