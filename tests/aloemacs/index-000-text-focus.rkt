#lang racket/base

(require racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" type-of type->datum))

(define-runtime-path text-path "../../lib/text.aloe")

(define (state-with-text)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string text-path)))
  state)

(define (checked-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (focused source line)
  `(((Text from-string ,source) focus-at ,line) case
      (None () (Text from-string ""))
      (Some (text) text)))

(define (list-display strings)
  (format "#<List ~a>"
          (string-join (map (lambda (s) (format "~s" s)) strings) " ")))

(define (check-lines state expression expected)
  (check-equal?
   (aloe-value->string (driver-eval! state `(,expression lines)))
   (list-display expected)))

(define (option-text expression)
  `(,expression case
      (None () (Text from-string "unexpected None"))
      (Some (text) text)))

(test-case "indexed constructor and focused sends have checked types"
  (define state (state-with-text))
  (define indexed
    '(Text indexed (List empty) "a" (List of "b") 0))
  (for ([entry
         (in-list
          `((,indexed Text)
            ((,indexed focus-at 1) (Option Text))
            ((,indexed focus-line) Int)
            ((,indexed current-line) String)
            ((,indexed has-previous?) Bool)
            ((,indexed has-next?) Bool)
            ((,indexed focus-up) Text)
            ((,indexed focus-down) Text)))])
    (check-equal? (checked-type state (car entry)) (cadr entry)))
  (check-equal? (driver-eval! state `(,indexed focus-line)) 0)
  (check-equal? (driver-eval! state `(,indexed current-line)) "a"))

(test-case "cold and focused forms preserve exact source and lines"
  (define state (state-with-text))
  (for ([fixture
         (in-list
          (list (list "" '(""))
                (list "a\nb" '("a" "b"))
                (list "a\n" '("a" ""))
                (list "\n\n" '("" "" ""))
                (list "a\r\nb\r\n" '("a\r" "b\r" ""))
                (list "\uFEFFfirst\n" '("\uFEFFfirst" ""))
                (list "λ🙂\n界" '("λ🙂" "界"))))])
    (define source (car fixture))
    (define expected (cadr fixture))
    (define cold `(Text from-string ,source))
    (check-equal? (driver-eval! state `(,cold to-string)) source)
    (check-lines state cold expected)
    (for ([line (in-range (length expected))])
      (define at-line (focused source line))
      (check-equal? (driver-eval! state `(,at-line to-string)) source)
      (check-lines state at-line expected)
      (check-equal? (driver-eval! state `(,at-line focus-line)) line)
      (check-equal? (driver-eval! state `(,at-line current-line))
                    (list-ref expected line)))))

(test-case "focus walks both directions, preserves inputs, and rejects edges"
  (define state (state-with-text))
  (driver-eval! state '(define original (Text from-string "a\nb\nc\n")))
  (driver-eval! state
                '(define middle
                   ((original focus-at 2) case
                     (None () original)
                     (Some (text) text))))
  (check-equal? (driver-eval! state '(middle focus-line)) 2)
  (check-equal? (driver-eval! state '(middle current-line)) "c")
  (check-true (driver-eval! state '(middle has-previous?)))
  (check-true (driver-eval! state '(middle has-next?)))
  (check-equal? (driver-eval! state '((middle focus-up) current-line)) "b")
  (check-equal? (driver-eval! state '((middle focus-down) current-line)) "")
  (check-equal?
   (driver-eval! state `(,(option-text '(middle focus-at 0)) current-line))
   "a")
  (check-equal?
   (driver-eval! state `(,(option-text '(middle focus-at 3)) current-line))
   "")
  (for ([line (in-list '(-1 4))])
    (check-false (driver-eval! state `((middle focus-at ,line) present?))))
  (check-false (driver-eval! state '((original focus-at -1) present?)))
  (check-false (driver-eval! state '((original focus-at 4) present?)))
  (check-equal? (driver-eval! state '(original to-string)) "a\nb\nc\n")
  (check-equal? (driver-eval! state '(middle focus-line)) 2)
  (check-equal? (driver-eval! state '((original focus-up) focus-line)) 0)
  (check-equal? (driver-eval! state '((original focus-down) focus-line)) 1)
  (check-not-exn
   (lambda ()
     (driver-eval! state
                   `(check
                      (,(focused "a\nb\nc\n" 0) focus-up)
                      ,(focused "a\nb\nc\n" 0)))))
  (check-not-exn
   (lambda ()
     (driver-eval! state
                   `(check
                      (,(focused "a\nb\nc\n" 3) focus-down)
                      ,(focused "a\nb\nc\n" 3))))))

(test-case "validity checks arbitrary lines from different focuses"
  (define state (state-with-text))
  (for ([focus (in-list '(0 1 2))])
    (define text (focused "ab\nc\n" focus))
    (for ([position (in-list '((0 0) (0 2) (1 1) (2 0)))])
      (check-true
       (driver-eval! state
                     `(,text valid-position?
                        (Position new ,(car position) ,(cadr position))))))
    (for ([position (in-list '((-1 0) (0 -1) (0 3) (1 2) (2 1) (3 0)))])
      (check-false
       (driver-eval! state
                     `(,text valid-position?
                        (Position new ,(car position) ,(cadr position))))))
    (check-true
     (driver-eval!
      state
      `(,text valid-span?
         (Span new (Position new 0 2) (Position new 2 0)))))
    (check-false
     (driver-eval!
      state
      `(,text valid-span?
         (Span new (Position new 2 0) (Position new 0 2)))))
    (check-false
     (driver-eval!
      state
      `(,text valid-span?
         (Span new (Position new 0 0) (Position new 2 1)))))))

(define edit-cases
  (list
   (list "abcd" 0 '(0 2 0 2) "X" "abXcd" '("abXcd") 0 3)
   (list "abcd" 0 '(0 2 0 2) "\n" "ab\ncd" '("ab" "cd") 1 0)
   (list "abcd" 0 '(0 1 0 2) "" "acd" '("acd") 0 1)
   (list "ab\ncd" 1 '(0 2 1 0) "" "abcd" '("abcd") 0 2)
   (list "ab\ncd\nef" 2 '(0 1 2 1) "X" "aXf" '("aXf") 0 2)
   (list "ab\ncd" 1 '(0 1 1 1) "X\nY\nZ"
         "aX\nY\nZd" '("aX" "Y" "Zd") 2 1)
   (list "ab\n" 1 '(1 0 1 0) "X" "ab\nX" '("ab" "X") 1 1)
   (list "ab\n" 0 '(1 0 1 0) "\n" "ab\n\n" '("ab" "" "") 2 0)
   (list "ab\n" 1 '(0 0 1 0) "" "" '("") 0 0)
   (list "ab" 0 '(0 1 0 1) "X\n" "aX\nb" '("aX" "b") 1 0)))

(test-case "replacement goldens hold for cold and focused immutable inputs"
  (define state (state-with-text))
  (for ([fixture (in-list edit-cases)]
        [case-index (in-naturals)])
    (define source (list-ref fixture 0))
    (define initial-focus (list-ref fixture 1))
    (define coords (list-ref fixture 2))
    (define replacement (list-ref fixture 3))
    (define expected-source (list-ref fixture 4))
    (define expected-lines (list-ref fixture 5))
    (define expected-line (list-ref fixture 6))
    (define expected-column (list-ref fixture 7))
    (define span
      `(Span new
         (Position new ,(list-ref coords 0) ,(list-ref coords 1))
         (Position new ,(list-ref coords 2) ,(list-ref coords 3))))
    (for ([receiver-expression
           (in-list (list `(Text from-string ,source)
                          (focused source initial-focus)))]
          [form-index (in-naturals)])
      (define receiver
        (string->symbol (format "original-~a-~a" case-index form-index)))
      (define saved-span
        (string->symbol (format "span-~a-~a" case-index form-index)))
      (driver-eval! state `(define ,receiver ,receiver-expression))
      (driver-eval! state `(define ,saved-span ,span))
      (define edit `(,receiver replace ,saved-span ,replacement))
      (define result
        `(,edit case
            (None () (EditResult new (Text from-string "unexpected None")
                                     (Position new -1 -1)))
            (Some (value) value)))
      (check-true (driver-eval! state `(,edit present?)))
      (check-equal? (driver-eval! state `((,result text) to-string))
                    expected-source)
      (check-lines state `(,result text) expected-lines)
      (check-equal? (driver-eval! state `((,result position) line))
                    expected-line)
      (check-equal? (driver-eval! state `((,result position) column))
                    expected-column)
      (check-equal? (driver-eval! state `((,result text) focus-line))
                    expected-line)
      (check-equal?
       (driver-eval!
        state
        `((,result text) case
           (from-string (source) "cold")
           (indexed (above current below focus) "indexed")))
       "indexed")
      (check-equal? (driver-eval! state `(,receiver to-string)) source)
      (when (= form-index 1)
        (check-equal? (driver-eval! state `(,receiver focus-line))
                      initial-focus))
      (check-equal? (driver-eval! state `((,saved-span start) line))
                    (list-ref coords 0))
      (check-equal? (driver-eval! state `((,saved-span start) column))
                    (list-ref coords 1))
      (check-equal? (driver-eval! state `((,saved-span end) line))
                    (list-ref coords 2))
      (check-equal? (driver-eval! state `((,saved-span end) column))
                    (list-ref coords 3)))))

(test-case "invalid replacement returns None for cold and indexed values"
  (define state (state-with-text))
  (for ([receiver-expression
         (in-list (list '(Text from-string "ab\n")
                        (focused "ab\n" 1)))]
        [index (in-naturals)])
    (define receiver (string->symbol (format "invalid-original-~a" index)))
    (driver-eval! state `(define ,receiver ,receiver-expression))
    (for ([span
           (in-list
            '((Span new (Position new 0 3) (Position new 1 0))
              (Span new (Position new 1 0) (Position new 0 0))
              (Span new (Position new -1 0) (Position new 0 0))
              (Span new (Position new 0 0) (Position new 2 0))))])
      (check-false
       (driver-eval! state `((,receiver replace ,span "X") present?))))
    (check-equal? (driver-eval! state `(,receiver to-string)) "ab\n")
    (when (= index 1)
      (check-equal? (driver-eval! state `(,receiver focus-line)) 1))))

(test-case "focused insert delete and newline delegate to replacement"
  (define state (state-with-text))
  (define text (focused "ab\ncd" 1))
  (define position '(Position new 1 1))
  (define span
    '(Span new (Position new 0 2) (Position new 1 0)))
  (for ([pair
         (in-list
          (list (list `(,text insert ,position "X\nY")
                      `(,text replace
                         (Span new ,position ,position) "X\nY"))
                (list `(,text delete ,span)
                      `(,text replace ,span ""))
                (list `(,text newline ,position)
                      `(,text replace
                         (Span new ,position ,position) "\n"))))])
    (define left (car pair))
    (define right (cadr pair))
    (check-true (driver-eval! state `(,left present?)))
    (check-not-exn
     (lambda ()
       (driver-eval! state
                     `(check ,left ,right))))))
