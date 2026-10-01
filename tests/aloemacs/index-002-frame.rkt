#lang racket/base

(require racket/format
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt")

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (state-with-editor)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  state)

(define (focused-text source line)
  `(((Text from-string ,source) focus-at ,line) case
      (None () (Text from-string "unexpected None"))
      (Some (text) text)))

(define (define-editor! state name source line column quit [focus line])
  (driver-eval!
   state
   `(define ,name
      (AloemacsEditor new
        ,(focused-text source focus)
        (Position new ,line ,column)
        ,quit
        0
        0
        (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0))))

(define (fit-editor! state name source columns rows)
  (driver-eval!
   state
   `(define ,name (,source ensure-visible ,columns ,rows))))

(define (frame body row column)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   body
   (format "\u001b[~a;~aH\u001b[?25h" row column)))

(define (check-state state name line column quit focus)
  (check-equal? (driver-eval! state `((,name point) line)) line)
  (check-equal? (driver-eval! state `((,name point) column)) column)
  (check-equal? (driver-eval! state `(,name quit)) quit)
  (check-equal? (driver-eval! state `((,name text) focus-line)) focus))

(test-case "focused frames near both ends of 10,000 lines are exact and repeatable"
  (define state (state-with-editor))
  (define source
    (string-join
     (for/list ([i (in-range 10000)]) (format "L~a" (~r i #:min-width 4 #:pad-string "0")))
     "\n"))
  (define-editor! state 'top source 2 3 #f)
  (define-editor! state 'bottom source 9000 2 #t)
  (fit-editor! state 'top-fitted 'top 8 4)
  (fit-editor! state 'bottom-fitted 'bottom 8 4)
  (define top-frame
    (frame "L0000\r\nL0001\r\nL0002\r\nL0003" 3 4))
  (define bottom-frame
    (frame "L8997\r\nL8998\r\nL8999\r\nL9000" 4 3))
  (for ([i (in-range 2)])
    (check-equal? (driver-eval! state '(top-fitted frame 8 4)) top-frame)
    (check-equal? (driver-eval! state '(bottom-fitted frame 8 4)) bottom-frame))
  (check-equal? (driver-eval! state '(bottom scroll-row)) 0)
  (check-equal? (driver-eval! state '(bottom-fitted scroll-row)) 8997)
  (check-state state 'top 2 3 #f 2)
  (check-state state 'bottom 9000 2 #t 9000)
  (check-equal? (driver-eval! state '((bottom text) current-line)) "L9000"))

(test-case "empty, EOF padding, and shared horizontal clipping keep exact bytes"
  (define state (state-with-editor))
  (define-editor! state 'empty "" 0 0 #f)
  (define-editor! state 'eof "ab\ncd\n" 2 0 #f)
  (define-editor! state 'wide "0123456789\nabcdefghij\nKLMNOPQRST" 2 10 #f)
  (fit-editor! state 'eof-fitted 'eof 5 4)
  (fit-editor! state 'wide-fitted 'wide 4 3)
  (check-equal? (driver-eval! state '(empty frame 5 3))
                (frame "\r\n\r\n" 1 1))
  (check-equal? (driver-eval! state '(eof-fitted frame 5 4))
                (frame "ab\r\ncd\r\n\r\n" 3 1))
  (check-equal? (driver-eval! state '(wide-fitted frame 4 3))
                (frame "789\r\nhij\r\nRST" 3 4))
  (check-equal? (driver-eval! state '(wide scroll-col)) 0)
  (check-equal? (driver-eval! state '(wide-fitted scroll-col)) 7)
  (check-state state 'empty 0 0 #f 0)
  (check-state state 'eof 2 0 #f 2)
  (check-state state 'wide 2 10 #f 2))

(test-case "raw cold and differently focused editors align locally"
  (define state (state-with-editor))
  (define source "aa\nbb\ncc\ndd")
  (define-editor! state 'focused source 2 1 #f)
  (define-editor! state 'misfocused source 2 1 #f 0)
  (driver-eval!
   state
   `(define cold
      (AloemacsEditor new
        (Text from-string ,source)
        (Position new 2 1)
        #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (define expected (frame "aa\r\nbb\r\ncc" 3 2))
  (for ([name (in-list '(focused misfocused cold))])
    (check-equal? (driver-eval! state `(,name frame 5 3)) expected))
  (check-state state 'focused 2 1 #f 2)
  (check-state state 'misfocused 2 1 #f 0)
  (check-state state 'cold 2 1 #f 0)
  (check-equal?
   (driver-eval!
    state
    `(check cold
       (AloemacsEditor new
         (Text from-string ,source)
         (Position new 2 1)
         #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
   (driver-eval! state 'cold)))
