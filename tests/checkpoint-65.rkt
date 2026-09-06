#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/main.rkt"
                  type->datum
                  typecheck-source)
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
(void (driver-load-file! checker-driver gel-main-path (open-output-string)))
(void (driver-load-file! checker-driver point-path (open-output-string)))
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

(define (run-script keys)
  (define state (make-driver))
  (define-values (term output) (make-scripted-term keys))
  (driver-inject-host! state 'term term)
  (void (driver-load-file! state gel-main-path (open-output-string)))
  (void (driver-load-file! state point-path (open-output-string)))
  (driver-eval!
   state
   '(define initial-stack
      (gel-empty-stack push (Point new 10 20))))
  (driver-eval!
   state
   '(define final-stack
      (gel-main call initial-stack)))
  (values state output))

;; A q-only script prints once and returns the original stack.
(define-values (quit-driver quit-output) (run-script '("q")))
(check-eq? (driver-eval! quit-driver 'initial-stack)
           (driver-eval! quit-driver 'final-stack))
(check-regexp-match
 #rx"1  x  0"
 (get-output-string quit-output))

;; Row 1 is Point.x: its result is pushed, then q returns that new stack.
(define-values (step-driver step-output) (run-script '("1" "q")))
(check-equal?
 (driver-eval! step-driver '((final-stack items) len))
 2)
(check-equal?
 (driver-eval! step-driver '((final-stack tos) subject))
 10)
(check-regexp-match
 #rx"1  \\+  1"
 (get-output-string step-output))

;; The runner is only the host lifecycle and one gel-main entry send.
(define runner-source (file->string gel-run-path))
(check-false (regexp-match? #rx"gel-handle-key" runner-source))
(check-false (regexp-match? #rx"gel-text" runner-source))
(check-false (regexp-match? #rx"key-value->string" runner-source))
