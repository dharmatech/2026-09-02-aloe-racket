#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum))

(define-runtime-path text-path "../../lib/text.aloe")

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (bound-in-driver? state name)
  (and (env-bound? (driver-runtime-environment state) name)
       (type-environment-bound? (driver-type-environment state) name)))

(define (unbound-in-driver? state name)
  (and (not (env-bound? (driver-runtime-environment state) name))
       (not (type-environment-bound? (driver-type-environment state) name))))

(define (load-text! state)
  (driver-eval! state `(load ,(path->string text-path))))

(define (check-position state expression expected-line expected-column)
  (check-equal?
   (driver-eval! state `(,expression line))
   expected-line
   (format "line of ~s" expression))
  (check-equal?
   (driver-eval! state `(,expression column))
   expected-column
   (format "column of ~s" expression)))

(test-case "text library is explicit, source-relative, and driver-local"
  (define state (make-driver))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? state name)))
  (check-equal?
   (aloe-value->string (driver-eval! state '((List of 1 2 3) reverse)))
   "#<List 3 2 1>")
  (check-equal?
   (aloe-value->string (driver-eval! state '("a\nb" split-lines)))
   "#<List \"a\" \"b\">")

  (check-true (void? (load-text! state)))
  (for ([name (in-list '(Option Position Span Text))])
    (check-true (bound-in-driver? state name)))
  (for ([name (in-list '(Some None EditResult))])
    (check-true (unbound-in-driver? state name)))

  (define fresh-state (make-driver))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? fresh-state name)))
  (check-equal?
   (aloe-value->string (driver-eval! fresh-state '("ready\n" split-lines)))
   "#<List \"ready\" \"\">")
  (for ([name (in-list '(Position Span))])
    (check-exn
     (regexp (format "unbound symbol: ~a" name))
     (lambda () (driver-eval! fresh-state name)))))

(test-case "Position construction, fields, and methods have exact types"
  (define state (make-driver))
  (load-text! state)
  (for ([entry (in-list
                '(((Position new 1 2) Position)
                  (((Position new 1 2) line) Int)
                  (((Position new 1 2) column) Int)
                  (((Position new 1 2) = (Position new 1 2)) Bool)
                  (((Position new 1 2) before? (Position new 2 0)) Bool)
                  (((Position new 1 2) before-or-equal?
                    (Position new 1 2))
                   Bool)
                  (((Position new 1 2) after "x") Position)))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum (in-list
                '((Position new)
                  (Position new 1)
                  (Position new 1 2 3)
                  (Position new 1.0 2)
                  (Position new 1 2.0)
                  (Position new "1" 2)
                  ((Position new 1 2) after 3)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))))

  (check-position state '(Position new -7 9999999999999)
                  -7 9999999999999))

(test-case "Position equality and lexicographic ordering use stored integers"
  (define state (make-driver))
  (load-text! state)

  (check-true
   (driver-eval! state
                 '((Position new 3 4) = (Position new 3 4))))
  (check-false
   (driver-eval! state
                 '((Position new 3 4) = (Position new 2 4))))
  (check-false
   (driver-eval! state
                 '((Position new 3 4) = (Position new 3 5))))

  (for ([entry (in-list
                '((((Position new 1 99) before? (Position new 2 -99)) #t)
                  (((Position new 2 -99) before? (Position new 1 99)) #f)
                  (((Position new 2 3) before? (Position new 2 4)) #t)
                  (((Position new 2 4) before? (Position new 2 3)) #f)
                  (((Position new 2 3) before? (Position new 2 3)) #f)
                  (((Position new -3 50) before? (Position new -2 -50)) #t)
                  (((Position new -3 -2) before? (Position new -3 -1)) #t)))])
    (check-equal? (driver-eval! state (car entry)) (cadr entry)
                  (format "~s" (car entry))))

  (for ([entry (in-list
                '((((Position new 1 2) before-or-equal?
                    (Position new 1 3))
                   #t)
                  (((Position new 1 2) before-or-equal?
                    (Position new 1 2))
                   #t)
                  (((Position new 1 3) before-or-equal?
                    (Position new 1 2))
                   #f)))])
    (check-equal? (driver-eval! state (car entry)) (cadr entry)
                  (format "~s" (car entry)))))

(test-case "Position.after advances by LF-delimited pieces without mutation"
  (define state (make-driver))
  (load-text! state)
  (for ([entry (in-list
                (list (list "" 3 4)
                      (list "xy" 3 6)
                      (list "x\nyz" 4 2)
                      (list "\n" 4 0)
                      (list "x\ny\nz" 5 1)
                      (list "x\n" 4 0)
                      (list "🙂水" 3 6)
                      (list "a\rb" 3 7)))])
    (define inserted (car entry))
    (check-position state
                    `((Position new 3 4) after ,inserted)
                    (cadr entry)
                    (caddr entry)))

  (void (driver-eval! state '(define original-position-001
                               (Position new 8 9))))
  (void (driver-eval! state '(original-position-001 after "x\nyz")))
  (check-position state 'original-position-001 8 9))

(test-case "Span stores exact endpoints and detects only equal positions"
  (define state (make-driver))
  (load-text! state)
  (for ([entry (in-list
                '(((Span new (Position new 1 2) (Position new 3 4)) Span)
                  (((Span new (Position new 1 2) (Position new 3 4)) start)
                   Position)
                  (((Span new (Position new 1 2) (Position new 3 4)) end)
                   Position)
                  (((Span new (Position new 1 2) (Position new 3 4)) empty?)
                   Bool)))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum (in-list
                '((Span new)
                  (Span new (Position new 1 2))
                  (Span new (Position new 1 2) (Position new 3 4)
                            (Position new 5 6))
                  (Span new 1 (Position new 3 4))
                  (Span new (Position new 1 2) "end")))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))))

  (check-true
   (driver-eval!
    state
    '((Span new (Position new 1 2) (Position new 1 2)) empty?)))
  (check-false
   (driver-eval!
    state
    '((Span new (Position new 1 2) (Position new 1 3)) empty?)))
  (check-false
   (driver-eval!
    state
    '((Span new (Position new 5 6) (Position new 1 2)) empty?)))

  (define reversed
    '(Span new (Position new 5 6) (Position new -1 -2)))
  (check-position state `(,reversed start) 5 6)
  (check-position state `(,reversed end) -1 -2))

(test-case "001 values expose no later edit surface"
  (define state (make-driver))
  (load-text! state)
  (check-true (bound-in-driver? state 'Text))
  (for ([name (in-list '(EditResult))])
    (check-true (unbound-in-driver? state name))
    (check-exn
     (regexp (format "unbound symbol: ~a" name))
     (lambda () (driver-eval! state name))))
  (for ([selector (in-list '(valid-position?
                             valid-span?
                             offset
                             replace
                             insert
                             delete
                             newline
                             rebase
                             set-line))])
    (check-exn
     exn:fail:aloe-type?
     (lambda ()
       (driver-eval! state `((Position new 0 0) ,selector))))))
