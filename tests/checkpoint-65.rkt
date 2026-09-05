#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt"
                  make-top-level-env
                  type->datum
                  typecheck-source)
         "../aloe/parse.rkt"
         "../host/racket/term.rkt")

(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path point-path "../examples/point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")

;; The injected host facade gives gel-main one String-shaped read-key result.
(define checker-environment (make-term-type-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string gel-main-path))
  checker-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string point-path))
  checker-environment))
(check-equal?
 (type->datum
  (typecheck-source
   "(gel-main call (gel-start call (Point new 10 20)))"
   checker-environment))
 '(List Mirror))

(struct fake-term-state ([keys #:mutable] output) #:transparent)

(define fake-read-key
  (host-message
   0
   (lambda (receiver _arguments)
     (define state (host-receiver-state receiver))
     (define keys (fake-term-state-keys state))
     (unless (pair? keys)
       (error 'fake-term "script exhausted"))
     (set-fake-term-state-keys! state (cdr keys))
     (car keys))))

(define fake-write-line
  (host-message
   1
   (lambda (receiver arguments)
     (define value (car arguments))
     (unless (string? value)
       (error 'fake-term "write-line expects a String"))
     (define output
       (fake-term-state-output (host-receiver-state receiver)))
     (display value output)
     (display "\r\n" output)
     (flush-output output)
     value)))

(define (make-fake-term keys)
  (define state (fake-term-state keys (open-output-string)))
  (values
   (host-receiver
    'Term
    (hasheq 'read-key fake-read-key
            'write-line fake-write-line)
    state)
   state))

(define (load-runtime! path environment)
  (eval-expr
   (parse-datum `(load ,(path->string path)))
   environment))

(define (run-script keys)
  (define environment (make-top-level-env))
  (define-values (term state) (make-fake-term keys))
  (env-define! environment 'term term)
  (load-runtime! gel-main-path environment)
  (load-runtime! point-path environment)
  (eval-expr
   (parse-datum
    '(define initial-stack
       (gel-start call (Point new 10 20))))
   environment)
  (eval-expr
   (parse-datum
    '(define final-stack
       (gel-main call initial-stack)))
   environment)
  (values environment state))

;; A q-only script prints once and returns the original stack.
(define-values (quit-environment quit-state) (run-script '("q")))
(check-eq? (eval-expr (parse-datum 'initial-stack) quit-environment)
           (eval-expr (parse-datum 'final-stack) quit-environment))
(check-regexp-match
 #rx"1  x  0"
 (get-output-string (fake-term-state-output quit-state)))

;; Row 1 is Point.x: its result is pushed, then q returns that new stack.
(define-values (step-environment step-state) (run-script '("1" "q")))
(check-equal?
 (eval-expr (parse-datum '(final-stack len)) step-environment)
 2)
(check-equal?
 (eval-expr
  (parse-datum '((gel-tos call final-stack) subject))
  step-environment)
 10)
(check-regexp-match
 #rx"1  \\+  1"
 (get-output-string (fake-term-state-output step-state)))

;; The runner is only the host lifecycle and one gel-main entry send.
(define runner-source (file->string gel-run-path))
(check-false (regexp-match? #rx"gel-handle-key" runner-source))
(check-false (regexp-match? #rx"gel-menu-text" runner-source))
(check-false (regexp-match? #rx"key-value->string" runner-source))
