#lang racket/base

(require rackunit
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt"
                  exn:fail:aloe-type?
                  make-top-level-env
                  type->datum
                  typecheck-source)
         "../aloe/parse.rkt"
         "../host/racket/term.rkt")

(define checker-environment (make-term-type-environment))

(check-equal?
 (type->datum
  (typecheck-source
   "(term write-line \"hi\")"
   checker-environment))
 'String)

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda ()
               (typecheck-source source checker-environment))))

(check-type-error "(term write-line)")
(check-type-error "(term write-line 1)")
(check-type-error "(1 write-line)")

(define output (open-output-string))
(define term (make-term-receiver output))

(check-equal? (host-receiver-send term 'write-line '("hi")) "hi")
(check-equal? (get-output-string output) "hi\r\n")

;; Exercise the ordinary Aloe send path with the injected runtime receiver.
(define runtime-environment (make-top-level-env))
(env-define! runtime-environment 'term term)
(check-equal?
 (eval-expr
  (parse-datum '(term write-line "again"))
  runtime-environment)
 "again")
(check-equal? (get-output-string output) "hi\r\nagain\r\n")

(check-exn #rx"arity error"
           (lambda ()
             (host-receiver-send term 'write-line '())))
(check-exn #rx"expects a String"
           (lambda ()
             (host-receiver-send term 'write-line '(1))))
