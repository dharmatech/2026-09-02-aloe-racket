#lang racket/base

(require rackunit
         (only-in "../aloe/driver.rkt"
                  driver-eval!
                  driver-inject-host!
                  driver-runtime-environment
                  driver-type-environment
                  make-driver)
         (only-in "../aloe/env.rkt" env-bound?)
         (only-in "../aloe/host.rkt" make-host-method)
         (only-in "../aloe/type.rkt" type-environment-bound?)
         (only-in "../host/racket/term.rkt" make-term-receiver))

(define option-definition
  '(define-class (Option T)
     (constructors
       (None (fields))
       (Some (fields (value T))))
     (methods
       (present? () Bool
         (self case
           (None () #f)
           (Some (value) #t))))))

(test-case "typed host injection and constructor case coexist in one driver"
  (define state (make-driver))
  (check-false
   (env-bound? (driver-runtime-environment state) 'term))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'term))

  (define output (open-output-string))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal?
   (driver-eval! state '(term write-line "sealed"))
   "sealed")
  (check-equal? (get-output-string output) "sealed\r\n")

  (check-true (void? (driver-eval! state option-definition)))
  (check-true
   (driver-eval! state '((Option Some "x") present?))))

(test-case "host crossing vocabulary remains sealed"
  (check-exn
   #rx"return-type is not a permitted crossing type"
   (lambda ()
     (make-host-method 'path '() 'Path (lambda (_state) "ignored")))))
