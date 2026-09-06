#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         (only-in "../aloe/main.rkt"
                  make-top-level-env
                  type->datum
                  typecheck-source)
         "../aloe/parse.rkt"
         "../host/racket/term.rkt")

(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path point-path "../examples/point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")

;; The injected production interface gives gel-main its checked Term shape.
(define checker-driver (make-driver))
(driver-inject-host!
 checker-driver
 'term
 (make-term-receiver (open-output-string) (lambda () "q")))
(define checker-environment (driver-type-environment checker-driver))
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
   "(gel-main call (gel-empty-stack push (Point new 10 20)))"
   checker-environment))
 'GelStack)

(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define output (open-output-string))
  (values
   (make-term-receiver
    output
    (lambda ()
      (define keys (unbox remaining-keys))
      (unless (pair? keys)
        (error 'fake-term "script exhausted"))
      (set-box! remaining-keys (cdr keys))
      (car keys)))
   output))

(define (load-runtime! path environment)
  (eval-expr
   (parse-datum `(load ,(path->string path)))
   environment))

(define (run-script keys)
  (define environment (make-top-level-env))
  (define-values (term output) (make-scripted-term keys))
  (env-define! environment 'term term)
  (load-runtime! gel-main-path environment)
  (load-runtime! point-path environment)
  (eval-expr
   (parse-datum
    '(define initial-stack
       (gel-empty-stack push (Point new 10 20))))
   environment)
  (eval-expr
   (parse-datum
    '(define final-stack
       (gel-main call initial-stack)))
   environment)
  (values environment output))

;; A q-only script prints once and returns the original stack.
(define-values (quit-environment quit-output) (run-script '("q")))
(check-eq? (eval-expr (parse-datum 'initial-stack) quit-environment)
           (eval-expr (parse-datum 'final-stack) quit-environment))
(check-regexp-match
 #rx"1  x  0"
 (get-output-string quit-output))

;; Row 1 is Point.x: its result is pushed, then q returns that new stack.
(define-values (step-environment step-output) (run-script '("1" "q")))
(check-equal?
 (eval-expr (parse-datum '((final-stack items) len)) step-environment)
 2)
(check-equal?
 (eval-expr
  (parse-datum '((final-stack tos) subject))
  step-environment)
 10)
(check-regexp-match
 #rx"1  \\+  1"
 (get-output-string step-output))

;; The runner is only the host lifecycle and one gel-main entry send.
(define runner-source (file->string gel-run-path))
(check-false (regexp-match? #rx"gel-handle-key" runner-source))
(check-false (regexp-match? #rx"gel-text" runner-source))
(check-false (regexp-match? #rx"key-value->string" runner-source))
