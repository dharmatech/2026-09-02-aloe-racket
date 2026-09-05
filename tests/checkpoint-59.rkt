#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path stack-path "../gel/stack.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string stack-path))
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

(check-equal?
 (type->datum
  (typecheck-source
   (format "(load ~s) ((GelStack new (List empty)) push 1)"
           (path->string stack-path))))
 'GelStack)

(void (eval-source "(define p (Point new 10 20))" environment))
(void
 (eval-source
  "(define s ((GelStack new (List empty)) push p))"
  environment))
(check-equal? (aloe-value->string (eval-source "(s tos)"
                                               environment))
              "#<Mirror>")
(check-equal? (eval-source "((s items) len)" environment) 1)

;; Pushing a Mirror uses the exact overload and does not wrap it again.
(void (eval-source "(define existing-mirror (Mirror of 1))" environment))
(void
 (eval-source
  "(define mirror-stack ((GelStack new (List empty)) push existing-mirror))"
  environment))
(check-eq? (eval-source "existing-mirror" environment)
           (eval-source "(mirror-stack tos)" environment))

(void (eval-source "(define point-rows (gel-rows call p))" environment))
(void (bind-row! "x-row" "point-rows" "x" 0))
(void (bind-row! "plus-row" "point-rows" "+" 1))
(check-equal? (eval-source "(x-row arity)" environment) 0)
(check-equal? (eval-source "(plus-row arity)" environment) 1)

(void
 (eval-source
  "(define s2 (s invoke-zero x-row))"
  environment))
(check-equal? (aloe-value->string (eval-source "(s2 tos)"
                                               environment))
              "#<Mirror>")
(check-equal? (eval-source "((s2 items) len)" environment) 2)

(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source "((GelStack new (List empty)) tos)" environment)))
(check-exn #rx"arity error"
           (lambda ()
             (eval-source
              "(s invoke-zero plus-row)"
              environment)))
