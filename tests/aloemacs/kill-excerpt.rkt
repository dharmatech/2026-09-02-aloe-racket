#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" type-of type->datum))

(define-runtime-path text-path "../../lib/text.aloe")

(define (load-text! state)
  (driver-eval! state `(load ,(path->string text-path))))

(define (checked-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (span start-line start-column end-line end-column)
  `(Span new
         (Position new ,start-line ,start-column)
         (Position new ,end-line ,end-column)))

(define (excerpt text selected-span)
  `(,text excerpt ,selected-span))

(define (excerpt-value text selected-span)
  `(,(excerpt text selected-span) case
     (None () "unexpected None")
     (Some (value) value)))

(define (roundtrip text selected-span)
  `(,(excerpt text selected-span) case
     (None () "unexpected excerpt None")
     (Some (value)
       ((,text delete ,selected-span) case
         (None () "unexpected delete None")
         (Some (deleted)
           (((deleted text) insert (deleted position) value) case
             (None () "unexpected insert None")
             (Some (restored) ((restored text) to-string))))))))

(define (check-some state text selected-span expected source)
  (check-true
   (driver-eval! state `(,(excerpt text selected-span) present?))
   (format "valid span ~s" selected-span))
  (check-equal?
   (driver-eval! state (excerpt-value text selected-span))
   expected
   (format "excerpt of ~s at ~s" source selected-span))
  (check-equal?
   (driver-eval! state (roundtrip text selected-span))
   source
   (format "delete then insert at ~s" selected-span)))

(test-case "excerpt has the checked Option String signature and exact half-open contents"
  (define state (make-driver))
  (load-text! state)
  (check-equal?
   (checked-type state
                 (excerpt '(Text from-string "abc") (span 0 0 0 1)))
   '(Option String))

  (for ([entry
         (in-list
          (list
           (list "abcdef" (span 0 2 0 4) "cd")
           (list "abcdef" (span 0 0 0 6) "abcdef")
           (list "ab\ncd\nef" (span 0 1 2 1) "b\ncd\ne")
           (list "ab\ncd\nef\ngh" (span 0 1 3 1) "b\ncd\nef\ng")
           (list "ab\ncd" (span 0 2 1 0) "\n")
           (list "ab\ncd" (span 0 2 0 2) "")
           (list "ab\ncd" (span 1 0 1 0) "")
           (list "a\r\nbc" (span 0 1 1 1) "\r\nb")
           (list "ab\n" (span 0 0 1 0) "ab\n")))])
    (define source (list-ref entry 0))
    (define selected-span (list-ref entry 1))
    (check-some state `(Text from-string ,source)
                selected-span (list-ref entry 2) source)))

(test-case "excerpt works on indexed Text focused between both endpoints"
  (define state (make-driver))
  (load-text! state)
  (define indexed
    '(Text indexed (List of "ab") "cd" (List of "ef") 1))
  (check-some state indexed (span 0 1 2 1) "b\ncd\ne" "ab\ncd\nef")
  (check-some state '((Text from-string "ab\ncd\nef") indexed-value)
              (span 0 2 1 0) "\n" "ab\ncd\nef")
  (check-equal? (driver-eval! state `(,indexed focus-line)) 1)
  (check-equal? (driver-eval! state `(,indexed to-string)) "ab\ncd\nef"))

(test-case "invalid spans return None, and reading preserves input values"
  (define state (make-driver))
  (load-text! state)
  (driver-eval! state '(define source-text (Text from-string "ab\ncd")))
  (driver-eval! state '(define start-position (Position new 0 1)))
  (driver-eval! state '(define end-position (Position new 1 1)))
  (driver-eval! state '(define selected-span
                         (Span new start-position end-position)))
  (check-some state 'source-text 'selected-span "b\nc" "ab\ncd")
  (check-equal? (driver-eval! state '(source-text to-string)) "ab\ncd")
  (check-equal? (driver-eval! state '((selected-span start) line)) 0)
  (check-equal? (driver-eval! state '((selected-span start) column)) 1)
  (check-equal? (driver-eval! state '((selected-span end) line)) 1)
  (check-equal? (driver-eval! state '((selected-span end) column)) 1)

  (for ([invalid-span
         (in-list
          (list (span 0 2 0 1)
                (span 1 0 0 2)
                (span -1 0 0 1)
                (span 0 -1 0 1)
                (span 0 0 1 3)
                (span 0 3 1 0)
                (span 0 0 2 0)))])
    (check-false
     (driver-eval! state `(,(excerpt 'source-text invalid-span) present?))
     (format "invalid span ~s" invalid-span))
    (check-equal?
     (driver-eval!
      state
      `(,(excerpt 'source-text invalid-span) case
         (None () "none")
         (Some (value) value)))
     "none")))
