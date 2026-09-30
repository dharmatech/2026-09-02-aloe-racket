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

(define (checked-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (focused source line)
  `(((Text from-string ,source) focus-at ,line) case
      (None () (Text from-string "unexpected None"))
      (Some (text) text)))

(define (nth-line-expression lines index)
  (define tail
    (for/fold ([expression lines]) ([i (in-range index)])
      `(,expression rest)))
  `(,tail first))

(define (check-next-lines state text count expected)
  (define lines `(,text next-lines ,count))
  (check-equal? (driver-eval! state `(,lines len)) (length expected))
  (for ([line (in-list expected)] [index (in-naturals)])
    (check-equal? (driver-eval! state (nth-line-expression lines index))
                  line)))

(test-case "next-lines is checked and pads cold Text after EOF"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string text-path)))
  (check-equal?
   (checked-type state '((Text from-string "ab\nc") next-lines 4))
   '(List String))
  (check-next-lines state '(Text from-string "") 3 '("" "" ""))
  (check-next-lines state '(Text from-string "ab\nc") 4
                    '("ab" "c" "" ""))
  (check-next-lines state (focused "ab\nc" 1) 2 '("c" ""))
  (check-next-lines state '(Text from-string "ab\nc") 0 '())
  (check-next-lines state '(Text from-string "ab\nc") -2 '()))

(test-case "indexed next-lines reads the current and following zipper lines"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string text-path)))
  (define indexed
    '(Text indexed (List of "earlier") "here" (List of "next" "last") 1))
  (check-next-lines state indexed 5 '("here" "next" "last" "" ""))
  (check-next-lines state indexed 1 '("here")))

(test-case "editor has no render-rows and a fitted frame keeps its bytes"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define editor
    '(AloemacsEditor new
       (Text from-string "ab\nc")
       (Position new 0 1)
       #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0)))))
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (checked-type state `(,editor render-rows (Text from-string "ab\nc")
                                  0 5 2 #t))))
  (check-equal?
   (driver-eval! state `(,editor frame 5 2))
   "\u001b[?25l\u001b[2J\u001b[Hab\r\nc\u001b[1;2H\u001b[?25h"))
