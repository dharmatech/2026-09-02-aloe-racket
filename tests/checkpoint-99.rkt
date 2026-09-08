#lang racket/base

(require rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/host.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/term.rkt")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (make-names-interface [name 'NamesHost])
  (make-host-interface
   name
   (list
    (make-host-method
     'names
     '(String)
     '(List String)
     (lambda (_state path)
       (cond
         [(string=? path "dir") '("a" "b")]
         [(string=? path "empty") '()]
         [else '()]))))))

(define holder-definition
  '(define-class (Holder T)
     (fields
       (value T))
     (methods
       (names (path String) (List String)
         ((self value) names path))
       (kept () T
         (self value))
       (retain (other T) T
         other))))

(test-case "a generic field retains an injected host receiver type"
  (define interface (make-names-interface))
  (define receiver (make-host-receiver interface #f))
  (define state (make-driver))
  (driver-inject-host! state 'names-host receiver)

  (check-true (void? (driver-eval! state holder-definition)))
  (check-true
   (void? (driver-eval! state '(define h (Holder new names-host)))))
  (check-equal? (driver-type-datum state 'h) '(Holder NamesHost))
  (check-equal?
   (driver-type-datum state '(h names "dir"))
   '(List String))
  (check-equal? (driver-eval! state '((h names "dir") len)) 2)
  (check-equal? (driver-eval! state '((h names "dir") first)) "a")
  (check-equal?
   (driver-eval! state '(((h names "dir") rest) first))
   "b")
  (check-equal? (driver-eval! state '((h names "empty") len)) 0)
  (check-equal?
   (driver-eval! state '(((h value) names "dir") len))
   2)
  (check-eq? (driver-eval! state '(h kept)) receiver)

  (check-true
   (void? (driver-eval! state '(define int-holder (Holder new 1)))))
  (check-equal? (driver-type-datum state 'int-holder) '(Holder Int))
  (check-equal? (driver-type-datum state '(int-holder kept)) 'Int)
  (check-equal? (driver-eval! state '(int-holder kept)) 1))

(test-case "generic host fields preserve nominal interface identity"
  (define first-interface (make-names-interface 'TwinNames))
  (define second-interface (make-names-interface 'TwinNames))
  (define first-receiver (make-host-receiver first-interface 'first))
  (define shared-receiver (make-host-receiver first-interface 'shared))
  (define second-receiver (make-host-receiver second-interface 'second))
  (define state (make-driver))
  (driver-inject-host! state 'first-host first-receiver)
  (driver-inject-host! state 'shared-host shared-receiver)
  (driver-inject-host! state 'second-host second-receiver)
  (driver-eval! state holder-definition)
  (driver-eval! state '(define first-holder (Holder new first-host)))
  (driver-eval! state '(define shared-holder (Holder new shared-host)))
  (driver-eval! state '(define second-holder (Holder new second-host)))

  (check-eq?
   (driver-eval! state '(first-holder retain (shared-holder value)))
   shared-receiver)
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval! state '(first-holder retain (second-holder value))))))

(test-case "host interface names remain unavailable in source annotations"
  (define state (make-driver))
  (driver-inject-host!
   state 'term
   (make-term-receiver (open-output-string) (lambda () "unused")))
  (check-exn
   #rx"unbound symbol: Term"
   (lambda ()
     (driver-eval!
      state
      '(define-class TermHolder
         (fields (value Term))
         (methods))))))

(test-case "Term remains sealed and default drivers remain capability-free"
  (define default-state (make-driver))
  (check-false
   (env-bound? (driver-runtime-environment default-state) 'term))
  (check-false
   (type-environment-bound?
    (driver-type-environment default-state) 'term))

  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
