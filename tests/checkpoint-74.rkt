#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         (only-in "../aloe/main.rkt"
                  eval-source
                  make-top-level-env
                  make-type-environment
                  type->datum
                  typecheck-source))

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define checker-environment (make-type-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string gel-loop-path))
  checker-environment))

(check-equal?
 (type->datum (typecheck-source "gel-empty-stack" checker-environment))
 'GelStack)
(check-equal?
 (type->datum
  (typecheck-source
   "((gel-empty-stack push 1) push \"two\")"
   checker-environment))
 'GelStack)

;; The callable start wrappers and their class objects are gone.
(for ([name '(GelStart GelStartTwo gel-start gel-start-two)])
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

(check-equal? (eval-source "((gel-empty-stack items) len)" environment) 0)

;; Each push starts from the same immutable empty value with a fresh type.
(void (eval-source "(define int-stack (gel-empty-stack push 10))" environment))
(void
 (eval-source
  "(define string-stack (gel-empty-stack push \"hello\"))"
  environment))
(check-equal? (eval-source "((int-stack tos) subject)" environment) 10)
(check-equal?
 (eval-source "((string-stack tos) subject)" environment)
 "hello")
(check-equal? (eval-source "((int-stack items) len)" environment) 1)
(check-equal? (eval-source "((string-stack items) len)" environment) 1)
(check-equal? (eval-source "((gel-empty-stack items) len)" environment) 0)

;; Two pushes preserve the established first-is-TOS order across value types.
(void
 (eval-source
  "(define two-stack ((gel-empty-stack push 1) push \"two\"))"
  environment))
(check-equal? (eval-source "((two-stack tos) subject)" environment) "two")
(check-equal?
 (eval-source "((((two-stack items) rest) first) subject)" environment)
 1)
(check-equal? (eval-source "((gel-empty-stack items) len)" environment) 0)

;; Menu and key stepping retain their behavior with direct stack construction.
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
  "(define point-rows (gel-rows call (point-stack tos)))"
  environment))
(void (bind-row! "point-x-row" "point-rows" "x" 0))
(void (eval-source "(define x-key ((point-x-row index) text))" environment))
(void
 (eval-source
  (string-append
   "(define point-state "
   "  (GelStep new point-stack #f (List empty) 0 #f))")
  environment))
(void
 (eval-source
  "(define x-step (point-state handle-key x-key))"
  environment))
(check-equal? (eval-source "(((x-step stack) tos) subject)" environment) 10)
(check-regexp-match #rx"[1-9][0-9]*  \\+  1"
                    (eval-source "(gel-menu-text call x-step)" environment))
(check-equal? (eval-source "((gel-empty-stack items) len)" environment) 0)
