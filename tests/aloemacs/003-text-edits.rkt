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

(define (option-case expression none-body some-body)
  `(,expression case
     (None () ,none-body)
     (Some (result) ,some-body)))

(define (check-position state expression expected-line expected-column)
  (check-equal?
   (driver-eval! state `(,expression line))
   expected-line
   (format "line of ~s" expression))
  (check-equal?
   (driver-eval! state `(,expression column))
   expected-column
   (format "column of ~s" expression)))

(define (check-edit state expression expected-source expected-line expected-column)
  (check-equal?
   (driver-eval!
    state
    (option-case expression
                 "unexpected None"
                 '((result text) to-string)))
   expected-source
   (format "result text of ~s" expression))
  (check-equal?
   (driver-eval!
    state
    (option-case expression -1 '((result position) line)))
   expected-line
   (format "result line of ~s" expression))
  (check-equal?
   (driver-eval!
    state
    (option-case expression -1 '((result position) column)))
   expected-column
   (format "result column of ~s" expression)))

(define (check-edit-lines state expression expected-lines)
  (check-equal?
   (aloe-value->string
    (driver-eval!
     state
     (option-case expression '(List empty) '((result text) lines))))
   expected-lines
   (format "result lines of ~s" expression)))

(define (check-none state expression)
  (check-false
   (driver-eval! state `(,expression present?))
   (format "None from ~s" expression))
  (check-equal?
   (driver-eval!
    state
    (option-case expression "none" "some"))
   "none"
   (format "exhaustive None case for ~s" expression)))

(define (edit-source state expression)
  (driver-eval!
   state
   (option-case expression
                "unexpected None"
                '((result text) to-string))))

(define (edit-position-part state expression selector)
  (driver-eval!
   state
   (option-case expression -1 `((result position) ,selector))))

(define (check-equivalent-edits state left right)
  (check-equal? (edit-source state left) (edit-source state right))
  (check-equal? (edit-position-part state left 'line)
                (edit-position-part state right 'line))
  (check-equal? (edit-position-part state left 'column)
                (edit-position-part state right 'column)))

(test-case "text edits load explicitly and bind only their declaring driver"
  (define state (make-driver))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? state name)))

  (check-true (void? (load-text! state)))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (bound-in-driver? state name)))
  (for ([name (in-list '(Some None from-string))])
    (check-true (unbound-in-driver? state name)))
  (check-exn #rx"unbound symbol: Some"
             (lambda () (driver-eval! state 'Some)))
  (check-exn #rx"unbound symbol: None"
             (lambda () (driver-eval! state 'None)))

  (define fresh-state (make-driver))
  (for ([name (in-list '(Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? fresh-state name))))

(test-case "EditResult has exactly its immutable Text and Position fields"
  (define state (make-driver))
  (load-text! state)
  (for ([entry
         (in-list
          '(((EditResult new
                (Text from-string "abc")
                (Position new 0 2))
             EditResult)
            (((EditResult new
                 (Text from-string "abc")
                 (Position new 0 2))
              text)
             Text)
            (((EditResult new
                 (Text from-string "abc")
                 (Position new 0 2))
              position)
             Position)))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum
         (in-list
          '((EditResult new)
            (EditResult new (Text from-string "abc"))
            (EditResult new
              (Text from-string "abc")
              (Position new 0 2)
              (Position new 0 3))
            (EditResult new "abc" (Position new 0 2))
            (EditResult new (Text from-string "abc") 2)
            (EditResult from-string
              (Text from-string "abc")
              (Position new 0 2))
            ((EditResult new
               (Text from-string "abc")
               (Position new 0 2))
             status)
            ((EditResult new
               (Text from-string "abc")
               (Position new 0 2))
             old-text)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))

(test-case "Text edit messages have exact checked signatures"
  (define state (make-driver))
  (load-text! state)
  (for ([entry
         (in-list
          '((((Text from-string "abc") replace
              (Span new (Position new 0 0) (Position new 0 1))
              "x")
             (Option EditResult))
            (((Text from-string "abc") insert
              (Position new 0 1)
              "x")
             (Option EditResult))
            (((Text from-string "abc") delete
              (Span new (Position new 0 0) (Position new 0 1)))
             (Option EditResult))
            (((Text from-string "abc") newline
              (Position new 0 1))
             (Option EditResult))))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum
         (in-list
          '(((Text from-string "abc") replace)
            ((Text from-string "abc") replace
             (Span new (Position new 0 0) (Position new 0 1)))
            ((Text from-string "abc") replace
             (Span new (Position new 0 0) (Position new 0 1)) "x" "y")
            ((Text from-string "abc") replace (Position new 0 0) "x")
            ((Text from-string "abc") replace
             (Span new (Position new 0 0) (Position new 0 1)) 1)
            ((Text from-string "abc") insert (Position new 0 0))
            ((Text from-string "abc") insert 0 "x")
            ((Text from-string "abc") insert (Position new 0 0) 1)
            ((Text from-string "abc") delete)
            ((Text from-string "abc") delete (Position new 0 0))
            ((Text from-string "abc") delete
             (Span new (Position new 0 0) (Position new 0 1)) "x")
            ((Text from-string "abc") newline)
            ((Text from-string "abc") newline 0)
            ((Text from-string "abc") newline (Position new 0 0) "x")))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))

(test-case "successful edits use exact half-open replacement and result positions"
  (define state (make-driver))
  (load-text! state)

  (void (driver-eval! state '(define before-003
                               (Text from-string "abcd"))))
  (void (driver-eval! state '(define insertion-position-003
                               (Position new 0 2))))
  (void (driver-eval! state '(define insertion-003
                               (before-003 insert insertion-position-003 "X"))))
  (check-edit state 'insertion-003 "abXcd" 0 3)
  (check-equal? (driver-eval! state '(before-003 to-string)) "abcd")
  (check-position state 'insertion-position-003 0 2)

  (define newline-edit
    '((Text from-string "abcd") newline (Position new 0 2)))
  (check-edit state newline-edit "ab\ncd" 1 0)
  (check-edit-lines state newline-edit "#<List \"ab\" \"cd\">")

  (define delete-character
    '((Text from-string "abcd") delete
      (Span new (Position new 0 1) (Position new 0 2))))
  (check-edit state delete-character "acd" 0 1)

  (void (driver-eval! state '(define join-span-003
                               (Span new
                                 (Position new 0 2)
                                 (Position new 1 0)))))
  (define delete-separator
    '((Text from-string "ab\ncd") delete join-span-003))
  (check-edit state delete-separator "abcd" 0 2)
  (check-position state '(join-span-003 start) 0 2)
  (check-position state '(join-span-003 end) 1 0)

  (define shorter-replacement
    '((Text from-string "ab\ncd\nef") replace
      (Span new (Position new 0 1) (Position new 2 1))
      "X"))
  (check-edit state shorter-replacement "aXf" 0 2)

  (define longer-replacement
    '((Text from-string "ab\ncd") replace
      (Span new (Position new 0 1) (Position new 1 1))
      "X\nY\nZ"))
  (check-edit state longer-replacement "aX\nY\nZd" 2 1)
  (check-edit-lines state longer-replacement
                    "#<List \"aX\" \"Y\" \"Zd\">")

  (define ends-in-lf
    '((Text from-string "ab") replace
      (Span new (Position new 0 1) (Position new 0 1))
      "X\n"))
  (check-edit state ends-in-lf "aX\nb" 1 0))

(test-case "empty and boundary edits remain valid and exact"
  (define state (make-driver))
  (load-text! state)

  (check-edit
   state
   '((Text from-string "ab") replace
     (Span new (Position new 0 1) (Position new 0 1))
     "")
   "ab" 0 1)
  (check-edit
   state
   '((Text from-string "ab") insert (Position new 0 0) "X")
   "Xab" 0 1)
  (check-edit
   state
   '((Text from-string "ab") insert (Position new 0 2) "X")
   "abX" 0 3)
  (check-edit
   state
   '((Text from-string "ab\n") insert (Position new 1 0) "X")
   "ab\nX" 1 1)

  (define trailing-newline
    '((Text from-string "ab\n") newline (Position new 1 0)))
  (check-edit state trailing-newline "ab\n\n" 2 0)
  (check-edit-lines state trailing-newline
                    "#<List \"ab\" \"\" \"\">")

  (check-edit
   state
   '((Text from-string "ab\n") delete
     (Span new (Position new 0 0) (Position new 1 0)))
   "" 0 0))

(test-case "invalid edits return None before offsets and preserve every input"
  (define state (make-driver))
  (load-text! state)

  (for ([expression
         (in-list
          '(((Text from-string "ab\n") insert (Position new -1 0) "X")
            ((Text from-string "ab\n") insert (Position new 0 -1) "X")
            ((Text from-string "ab\n") insert (Position new 2 0) "X")
            ((Text from-string "ab\n") insert (Position new 0 3) "X")
            ((Text from-string "ab\n") replace
             (Span new (Position new -1 0) (Position new 0 1)) "X")
            ((Text from-string "ab\n") replace
             (Span new (Position new 0 0) (Position new 1 1)) "X")
            ((Text from-string "ab\n") delete
             (Span new (Position new 0 0) (Position new 2 0)))
            ((Text from-string "ab\n") replace
             (Span new (Position new 0 2) (Position new 0 1)) "X")
            ((Text from-string "ab\n") replace
             (Span new (Position new 1 0) (Position new 0 2)) "X")
            ((Text from-string "ab\n") delete
             (Span new (Position new 1 0) (Position new 0 0)))))])
    (check-none state expression))

  (void (driver-eval! state '(define invalid-text-003
                               (Text from-string "ab\n"))))
  (void (driver-eval! state '(define invalid-position-003
                               (Position new 0 3))))
  (void (driver-eval! state '(define invalid-span-003
                               (Span new
                                 (Position new 1 0)
                                 (Position new 0 0)))))
  (check-none state '(invalid-text-003 insert invalid-position-003 "X"))
  (check-none state '(invalid-text-003 delete invalid-span-003))
  (check-equal? (driver-eval! state '(invalid-text-003 to-string)) "ab\n")
  (check-position state 'invalid-position-003 0 3)
  (check-position state '(invalid-span-003 start) 1 0)
  (check-position state '(invalid-span-003 end) 0 0))

(test-case "insert delete and newline delegate to equivalent replace sends"
  (define state (make-driver))
  (load-text! state)

  (check-equivalent-edits
   state
   '((Text from-string "abcd") insert (Position new 0 2) "X\nY")
   '((Text from-string "abcd") replace
     (Span new (Position new 0 2) (Position new 0 2))
     "X\nY"))
  (check-equivalent-edits
   state
   '((Text from-string "ab\ncd") delete
     (Span new (Position new 0 1) (Position new 1 1)))
   '((Text from-string "ab\ncd") replace
     (Span new (Position new 0 1) (Position new 1 1))
     ""))
  (check-equivalent-edits
   state
   '((Text from-string "abcd") newline (Position new 0 2))
   '((Text from-string "abcd") replace
     (Span new (Position new 0 2) (Position new 0 2))
     "\n")))

(test-case "Text exposes no source offset mutation normalization or undo surface"
  (define state (make-driver))
  (load-text! state)
  (for ([name (in-list '(Offset TextOffset LineAt offset line-at))])
    (check-true (unbound-in-driver? state name)))
  (for ([datum
         (in-list
          '(((Text from-string "abc") source)
            ((Text from-string "abc") offset (Position new 0 0))
            ((Text from-string "abc") line-at 0)
            ((Text from-string "abc") set-source "changed")
            ((Text from-string "abc") set-lines (List of "changed"))
            ((Text from-string "abc") normalize)
            ((Text from-string "abc") rebase (Position new 0 0))
            ((Text from-string "abc") undo)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))
