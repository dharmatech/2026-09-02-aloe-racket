#lang racket/base

(require rackunit
         "../aloe/driver.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt"
                  exn:fail:aloe-type?
                  type->datum
                  typecheck-source)
         "../host/racket/term.rkt")

(define output (open-output-string))
(define term (make-term-receiver output))
(define state (make-driver))
(driver-inject-host! state 'term term)

(define checker-environment (driver-type-environment state))

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

(check-equal? (host-receiver-send term 'write-line '("hi")) "hi")
(check-equal? (get-output-string output) "hi\r\n")

;; Exercise the ordinary Aloe send path with the injected runtime receiver.
(check-equal?
 (driver-eval! state '(term write-line "again"))
 "again")
(check-equal? (get-output-string output) "hi\r\nagain\r\n")

(check-exn #rx"arity error"
           (lambda ()
             (host-receiver-send term 'write-line '())))
(check-exn #rx"Term.*write-line.*argument 1.*String"
           (lambda ()
             (host-receiver-send term 'write-line '(1))))
