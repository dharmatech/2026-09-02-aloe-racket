#lang racket/base

(require racket/runtime-path
         rackunit
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt"
                  eval-source
                  make-top-level-env
                  type->datum
                  typecheck-source)
         "../aloe/parse.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define (load-runtime! path environment)
  (eval-expr
   (parse-datum `(load ,(path->string path)))
   environment))

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string gel-loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(check-equal?
 (type->datum
  (typecheck-source
   (format
    "(load ~s) ((GelStack new (List empty)) push 10)"
    (path->string gel-loop-path))))
 'GelStack)
(check-equal?
 (type->datum
  (typecheck-source
   (format
    "(load ~s) ((gel-empty-stack push 1) push 2)"
    (path->string gel-loop-path))))
 'GelStack)
(check-exn
 #rx"unbound symbol: gel-push"
 (lambda ()
   (typecheck-source
    (format
     "(load ~s) (gel-push call (List empty) 10)"
     (path->string gel-loop-path)))))

;; Ordinary values are mirrored once, while an existing Mirror is retained.
(void
 (eval-source
  "(define empty-stack (GelStack new (List empty)))"
  environment))
(void (eval-source "(define one-stack (empty-stack push 10))" environment))
(check-equal? (eval-source "((one-stack items) len)" environment) 1)
(check-equal? (eval-source "((one-stack tos) subject)" environment) 10)
(void (eval-source "(define existing-mirror (Mirror of 20))" environment))
(void
 (eval-source
  "(define two-stack (one-stack push existing-mirror))"
  environment))
(check-eq? (eval-source "existing-mirror" environment)
           (eval-source "(two-stack tos)" environment))
(check-equal? (eval-source "((one-stack items) len)" environment) 1)
(check-equal? (eval-source "((two-stack items) len)" environment) 2)
(check-equal?
 (eval-source "((((two-stack items) rest) first) subject)" environment)
 10)

(void (eval-source "(define started-two ((gel-empty-stack push 1) push 2))"
                   environment))
(check-equal? (eval-source "((started-two tos) subject)" environment) 2)
(check-equal?
 (eval-source "((((started-two items) rest) first) subject)" environment)
 1)

(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source "(empty-stack tos)" environment)))

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

;; Stack invocation pushes mirrored results.
(void (eval-source "(define point (Point new 10 20))" environment))
(void (eval-source "(define point-rows (gel-rows call point))" environment))
(void (bind-row! "point-x-row" "point-rows" "x" 0))
(void (eval-source "(define point-stack (gel-empty-stack push point))"
                   environment))
(void
 (eval-source
  "(define x-stack (point-stack invoke-zero point-x-row))"
  environment))
(check-equal? (eval-source "((x-stack items) len)" environment) 2)
(check-equal? (eval-source "((x-stack tos) subject)" environment) 10)

(void (eval-source "(define int-rows (gel-rows call 10))" environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(void
 (eval-source
  "(define sum-stack ((gel-empty-stack push 10) invoke-one int-plus-row 2))"
  environment))
(check-equal? (eval-source "((sum-stack tos) subject)" environment) 12)
(void (eval-source "(define two-mirror (Mirror of 2))" environment))
(void
 (eval-source
  (string-append
   "(define mirrored-sum-stack "
   "  ((gel-empty-stack push 10) invoke-one int-plus-row two-mirror))")
  environment))
(check-equal?
 (eval-source "((mirrored-sum-stack tos) subject)" environment)
 12)

;; Menu stepping still uses the stack's TOS and leaves its transcript shape.
(void (eval-source "(define point-x-key ((point-x-row index) text))"
                   environment))
(void
 (eval-source
  (string-append
   "(define point-state "
   "  (GelStep new point-stack #f (List empty) 0 #f))")
  environment))
(void
 (eval-source
  "(define point-step (point-state handle-key point-x-key))"
  environment))
(check-equal? (eval-source "(((point-step stack) items) len)" environment) 2)
(check-regexp-match #rx"[1-9]  x  0"
                    (eval-source "(gel-menu-text call (point-stack tos))"
                                 environment))

(struct fake-term-state ([keys #:mutable] output) #:transparent)

(define fake-read-key
  (host-message
   0
   (lambda (receiver _arguments)
     (define state (host-receiver-state receiver))
     (define keys (fake-term-state-keys state))
     (set-fake-term-state-keys! state (cdr keys))
     (car keys))))

(define fake-write-line
  (host-message
   1
   (lambda (receiver arguments)
     (define value (car arguments))
     (display value
              (fake-term-state-output
               (host-receiver-state receiver)))
     (display "\r\n"
              (fake-term-state-output
               (host-receiver-state receiver)))
     value)))

(define transcript-environment (make-top-level-env))
(define transcript-state
  (fake-term-state '("1" "q") (open-output-string)))
(env-define!
 transcript-environment
 'term
 (host-receiver
  'Term
  (hasheq 'read-key fake-read-key
          'write-line fake-write-line)
  transcript-state))
(load-runtime! gel-main-path transcript-environment)
(load-runtime! point-path transcript-environment)
(void
 (eval-expr
  (parse-datum
   '(gel-main call (gel-empty-stack push (Point new 10 20))))
  transcript-environment))
(define transcript (get-output-string (fake-term-state-output transcript-state)))
(check-regexp-match #rx"key 1\r\nTOS: 10\r\n" transcript)
(check-regexp-match #rx"key q\r\n" transcript)
