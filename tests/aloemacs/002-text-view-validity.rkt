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

(define (text-expression source)
  `(Text from-string ,source))

(define (position-expression line column)
  `(Position new ,line ,column))

(define (valid-position-expression source line column)
  `(,(text-expression source)
    valid-position?
    ,(position-expression line column)))

(define (span-expression start-line start-column end-line end-column)
  `(Span new
         ,(position-expression start-line start-column)
         ,(position-expression end-line end-column)))

(define (valid-span-expression source
                               start-line start-column
                               end-line end-column)
  `(,(text-expression source)
    valid-span?
    ,(span-expression start-line start-column end-line end-column)))

(test-case "text library loading is explicit and driver-local"
  (define state (make-driver))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? state name)))

  (check-true (void? (load-text! state)))
  (for ([name (in-list '(Option Position Span Text))])
    (check-true (bound-in-driver? state name)))
  (for ([name (in-list '(Some None EditResult from-string))])
    (check-true (unbound-in-driver? state name)))

  (check-true
   (driver-eval! state '((Option Some "kept") present?)))
  (check-true
   (driver-eval!
    state
    '((Position new 1 2) before-or-equal? (Position new 1 2))))
  (check-true
   (driver-eval!
    state
    '((Span new (Position new 3 4) (Position new 3 4)) empty?)))

  (define fresh-state (make-driver))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? fresh-state name)))
  (for ([name (in-list '(Position Span Text))])
    (check-exn
     (regexp (format "unbound symbol: ~a" name))
     (lambda () (driver-eval! fresh-state name)))))

(test-case "Text construction and methods have exact types"
  (define state (make-driver))
  (load-text! state)
  (for ([entry
         (in-list
          '(((Text from-string "source") Text)
            (((Text from-string "source") to-string) String)
            (((Text from-string "source") lines) (List String))
            (((Text from-string "source") valid-position?
              (Position new 0 0))
             Bool)
            (((Text from-string "source") valid-span?
              (Span new (Position new 0 0) (Position new 0 1)))
             Bool)))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum (in-list
                '((Text from-string)
                  (Text from-string "one" "two")
                  (Text from-string 1)
                  (Text new "source")))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))))

  (check-true (unbound-in-driver? state 'from-string))
  (check-exn #rx"unbound symbol: from-string"
             (lambda () (driver-eval! state 'from-string))))

(test-case "to-string preserves the exact source"
  (define state (make-driver))
  (load-text! state)
  (for ([source (in-list '(""
                           "one line"
                           "one\ntwo"
                           "🙂水"
                           "a\r\nb"
                           "one\ntwo\n"
                           "x\n\n"))])
    (check-equal?
     (driver-eval! state `(,(text-expression source) to-string))
     source)))

(test-case "lines is the exact LF-split derived view"
  (define state (make-driver))
  (load-text! state)
  (for ([entry
         (in-list
          '(("" "#<List \"\">")
            ("one\ntwo" "#<List \"one\" \"two\">")
            ("one\ntwo\n" "#<List \"one\" \"two\" \"\">")
            ("\n" "#<List \"\" \"\">")
            ("x\n\n" "#<List \"x\" \"\" \"\">")
            ("a\r\nb" "#<List \"a\\r\" \"b\">")))])
    (check-equal?
     (aloe-value->string
      (driver-eval! state `(,(text-expression (car entry)) lines)))
     (cadr entry))))

(test-case "valid-position? accepts boundaries and rejects invalid coordinates"
  (define state (make-driver))
  (load-text! state)
  (for ([entry
         (in-list
          (list
           (list "" 0 0 #t)
           (list "" 0 1 #f)
           (list "" -1 0 #f)
           (list "" 0 -1 #f)
           (list "" 1 0 #f)
           (list "" 9999999999999 0 #f)
           (list "abc" 0 0 #t)
           (list "abc" 0 3 #t)
           (list "abc" 0 4 #f)
           (list "ab\nc" 0 2 #t)
           (list "ab\nc" 0 3 #f)
           (list "ab\nc" 1 0 #t)
           (list "ab\nc" 1 1 #t)
           (list "ab\nc" 1 2 #f)
           (list "ab\nc" 2 0 #f)
           (list "ab\n" 1 0 #t)
           (list "ab\n" 1 1 #f)
           (list "ab\n" 2 0 #f)
           (list "🙂水" 0 2 #t)
           (list "🙂水" 0 3 #f)
           (list "a\r\nb" 0 2 #t)
           (list "a\r\nb" 0 3 #f)))])
    (check-equal?
     (driver-eval!
      state
      (valid-position-expression
       (car entry) (cadr entry) (caddr entry)))
     (cadddr entry)
     (format "valid position in ~s at (~a, ~a)"
             (car entry) (cadr entry) (caddr entry))))

  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval! state '((Text from-string "abc") valid-position? 0)))))

(test-case "valid-span? requires valid ordered endpoints"
  (define state (make-driver))
  (load-text! state)
  (for ([entry
         (in-list
          (list
           (list "ab\nc" 0 0 0 0 #t)
           (list "ab\nc" 0 0 0 2 #t)
           (list "ab\nc" 0 2 1 1 #t)
           (list "ab\n" 0 2 1 0 #t)
           (list "ab\n" 1 0 1 0 #t)
           (list "ab\nc" 0 2 0 1 #f)
           (list "ab\nc" 1 0 0 2 #f)
           (list "ab\nc" -1 0 1 1 #f)
           (list "ab\nc" 0 0 2 0 #f)
           (list "ab\nc" -1 -1 2 2 #f)
           (list "ab\n" 0 2 1 1 #f)))])
    (check-equal?
     (driver-eval!
      state
      (valid-span-expression
       (list-ref entry 0)
       (list-ref entry 1)
       (list-ref entry 2)
       (list-ref entry 3)
       (list-ref entry 4)))
     (list-ref entry 5)
     (format "valid span in ~s from (~a, ~a) to (~a, ~a)"
             (list-ref entry 0)
             (list-ref entry 1)
             (list-ref entry 2)
             (list-ref entry 3)
             (list-ref entry 4))))

  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval! state '((Text from-string "abc") valid-span?
                           (Position new 0 0))))))

(test-case "validity predicates do not change their inputs"
  (define state (make-driver))
  (load-text! state)
  (void (driver-eval! state '(define text-002
                               (Text from-string "ab\n"))))
  (void (driver-eval! state '(define position-002
                               (Position new 1 0))))
  (void (driver-eval! state '(define span-002
                               (Span new
                                 (Position new 0 2)
                                 (Position new 1 0)))))

  (check-true
   (driver-eval! state '(text-002 valid-position? position-002)))
  (check-true
   (driver-eval! state '(text-002 valid-span? span-002)))

  (check-equal? (driver-eval! state '(text-002 to-string)) "ab\n")
  (check-equal?
   (aloe-value->string (driver-eval! state '(text-002 lines)))
   "#<List \"ab\" \"\">")
  (check-position state 'position-002 1 0)
  (check-position state '(span-002 start) 0 2)
  (check-position state '(span-002 end) 1 0))

(test-case "002 exposes no edit, offset, setter, or normalization surface"
  (define state (make-driver))
  (load-text! state)
  (check-true (unbound-in-driver? state 'EditResult))
  (check-exn #rx"unbound symbol: EditResult"
             (lambda () (driver-eval! state 'EditResult)))

  (for ([datum
         (in-list
          '(((Text from-string "abc") replace
             (Span new (Position new 0 0) (Position new 0 1)) "x")
            ((Text from-string "abc") insert (Position new 0 0) "x")
            ((Text from-string "abc") delete
             (Span new (Position new 0 0) (Position new 0 1)))
            ((Text from-string "abc") newline (Position new 0 0))
            ((Text from-string "abc") offset (Position new 0 0))
            ((Text from-string "abc") line-at 0)
            ((Text from-string "abc") source)
            ((Text from-string "abc") set-source "changed")
            ((Text from-string "abc") normalize)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))
