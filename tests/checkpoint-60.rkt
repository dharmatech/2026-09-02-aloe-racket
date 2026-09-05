#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(check-equal? (eval-source "((Mirror of 10) subject)" environment) 10)
(check-equal? (eval-source "((Mirror of \"a\") subject)" environment) "a")

;; Typed method parameters provide an expected type to subject and enforce the
;; same type again at the runtime method-dispatch boundary.
(void
 (eval-source
  #<<ALOE
(define-class SubjectContext
  (fields)
  (methods
    (as-int (value Int) Int value)
    (point-x (value (Point Int)) Int (value x))
    (point-y (value (Point Int)) Int (value y))))
ALOE
  environment))

(check-equal?
 (eval-source
  "((SubjectContext new) as-int ((Mirror of 10) subject))"
  environment)
 10)
(check-equal?
 (eval-source
  (string-append
   "((SubjectContext new) point-x "
   "  ((Mirror of (Point new 1 2)) subject))")
  environment)
 1)
(check-equal?
 (eval-source
  (string-append
   "((SubjectContext new) point-y "
   "  ((Mirror of (Point new 1 2)) subject))")
  environment)
 2)

;; Without an expected type, subject has a fresh checker type and evaluates to
;; the actual Point value rather than another Mirror.
(check-equal?
 (aloe-value->string
  (eval-source "((Mirror of (Point new 1 2)) subject)" environment))
 "#<Point 1 2>")

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source source environment))))

(check-type-error "(1 subject)")
(check-type-error "(Point subject)")
(check-type-error "((Point new 1 2) subject)")

;; The checker accepts the opaque subject in an Int context; runtime dispatch
;; then rejects the Point because it does not match that annotated parameter.
(check-exn #rx"unknown message|does not match|type"
           (lambda ()
             (eval-source
              (string-append
               "((SubjectContext new) as-int "
               "  ((Mirror of (Point new 1 2)) subject))")
              environment)))
