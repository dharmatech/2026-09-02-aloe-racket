#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         (only-in "../aloe/main.rkt"
                  eval-source
                  make-top-level-env
                  make-type-environment
                  type->datum
                  typecheck-source)
         "../aloe/parse.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string gel-loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(define checker-environment (make-type-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string gel-loop-path))
  checker-environment))

;; Invocation is now a GelStack protocol; the callable helpers are gone.
(for ([name '(GelInvokeZero GelInvokeOne gel-invoke-zero gel-invoke-one)])
  (check-exn
   (regexp (format "unbound symbol: ~a" name))
   (lambda ()
     (typecheck-source (symbol->string name) checker-environment))))

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

(void (eval-source "(define point (Point new 10 20))" environment))
(void (eval-source "(define point-stack (gel-empty-stack push point))"
                   environment))
(void
 (eval-source
  (string-append
   "(define point-rows "
   "  (gel-rows of (point-stack tos)))")
  environment))
(void (bind-row! "point-x-row" "point-rows" "x" 0))
(void (bind-row! "point-plus-row" "point-rows" "+" 1))

;; A zero-argument send preserves the old stack and pushes one mirrored result.
(void
 (eval-source
  "(define x-stack (point-stack invoke-zero point-x-row))"
  environment))
(check-equal? (eval-source "((point-stack items) len)" environment) 1)
(check-equal? (eval-source "((x-stack items) len)" environment) 2)
(check-equal? (eval-source "((x-stack tos) subject)" environment) 10)

;; One-argument sends accept either an ordinary value or a Mirror.
(void (eval-source "(define int-stack (gel-empty-stack push 10))" environment))
(void
 (eval-source
  "(define int-rows (gel-rows of (int-stack tos)))"
  environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(void
 (eval-source
  "(define raw-sum (int-stack invoke-one int-plus-row 2))"
  environment))
(check-equal? (eval-source "((raw-sum tos) subject)" environment) 12)
(void (eval-source "(define two-mirror (Mirror of 2))" environment))
(void
 (eval-source
  "(define mirror-sum (int-stack invoke-one int-plus-row two-mirror))"
  environment))
(check-equal? (eval-source "((mirror-sum tos) subject)" environment) 12)

;; Mirror.invoke remains the authority for signature and runtime-type checks.
(check-exn #rx"does not belong to the subject type"
           (lambda ()
             (eval-source
              "(int-stack invoke-zero point-x-row)"
              environment)))
(check-exn #rx"arity error"
           (lambda ()
             (eval-source
              "(point-stack invoke-zero point-plus-row)"
              environment)))
(check-exn #rx"argument 1 does not match"
           (lambda ()
             (eval-source
              "(point-stack invoke-one point-plus-row 1)"
              environment)))

;; Bypass static checking to prove that invoke still guards a row's result.
(void
 (eval-expr
  (parse-datum
   '(define-class GelBadResult73
      (fields)
      (methods
        (wrong () Int "not an Int"))))
  environment))
(void
 (eval-expr
  (parse-datum
   '(define bad-stack
      ((GelStack new (List empty)) push (GelBadResult73 new))))
  environment))
(void
 (eval-expr
  (parse-datum
   '(define bad-row
      ((gel-rows of (bad-stack tos)) first)))
  environment))
(check-exn #rx"result does not match Int"
           (lambda ()
             (eval-expr
              (parse-datum '(bad-stack invoke-zero bad-row))
              environment)))

;; The existing key path still selects the same row and stack result.
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
                    (eval-source "(gel-text menu x-step)" environment))

(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define stack (GelStack new (List empty)))
(define row
  ((gel-rows of
     ((stack push 10) tos))
   first))
((stack push 10) invoke-zero row)
ALOE
   checker-environment))
 'GelStack)
