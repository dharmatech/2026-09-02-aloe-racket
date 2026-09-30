#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-of
                  type->datum))

(define-runtime-path text-path "../../lib/text.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (state-with-text)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string text-path)))
  state)

(define (checked-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (focused source line)
  `(((Text from-string ,source) focus-at ,line) case
      (None () (Text from-string "unexpected None"))
      (Some (text) text)))

(test-case "Text line-length has Int type and measures its current line"
  (define state (state-with-text))
  (check-equal? (checked-type state '((Text from-string "abc") line-length)) 'Int)
  (check-equal? (driver-eval! state '((Text from-string "") line-length)) 0)
  (check-equal? (driver-eval! state '((Text from-string "abc") line-length)) 3)
  (check-equal? (driver-eval! state '((Text from-string "ab\ncd") line-length)) 2)
  (check-equal?
   (driver-eval! state '((Text from-string "ab\ncd") line-length))
   (driver-eval! state '(((Text from-string "ab\ncd") current-line) len))))

(test-case "line-length follows focus-down and focus-at"
  (define state (state-with-text))
  (define first (focused "a\nbbb\ncc" 0))
  (check-equal? (driver-eval! state `(,first line-length)) 1)
  (check-equal? (driver-eval! state `((,first focus-down) line-length)) 3)
  (check-equal? (driver-eval! state `(,(focused "a\nbbb\ncc" 2) line-length)) 2)
  (check-equal? (driver-eval! state `(,(focused "a\nbbb\ncc" 0) line-length)) 1)
  (check-equal? (driver-eval! state `(,(focused "a\n" 1) line-length)) 0))

(test-case "AloemacsEditor no longer accepts line-length"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define editor
    '(AloemacsEditor new
       (Text from-string "abc")
       (Position new 0 0)
       #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0)))))
  (check-equal? (checked-type state editor) 'AloemacsEditor)
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval! state `(,editor line-length (Text from-string "abc"))))))
