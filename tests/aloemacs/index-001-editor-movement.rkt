#lang racket/base

(require racket/list
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

(define (step! state name previous selector . arguments)
  (driver-eval! state `(define ,name (,previous ,selector ,@arguments))))

(define (check-payload state name source line column quit)
  (define label (symbol->string name))
  (check-equal? (driver-eval! state `((,name text) to-string)) source label)
  (check-equal? (driver-eval! state `((,name point) line)) line label)
  (check-equal? (driver-eval! state `((,name point) column)) column label)
  (check-equal? (driver-eval! state `(,name quit)) quit label)
  (check-true
   (driver-eval! state `((,name text) valid-position? (,name point)))
   label))

(define (check-focused state name source line column quit)
  (check-payload state name source line column quit)
  (check-equal? (driver-eval! state `((,name text) focus-line))
                line
                (symbol->string name)))

(define (check-point-and-focus state name line column)
  (define label (symbol->string name))
  (check-equal? (driver-eval! state `((,name point) line)) line label)
  (check-equal? (driver-eval! state `((,name point) column)) column label)
  (check-equal? (driver-eval! state `((,name text) focus-line)) line label)
  (check-true
   (driver-eval! state `((,name text) valid-position? (,name point)))
   label))

(define (check-equal-editor state actual expected)
  (check-not-exn
   (lambda () (driver-eval! state `(check ,actual ,expected)))
   (format "~a equals ~a" actual expected)))

(test-case "every transition carries the focus and leaves older editors intact"
  (define state (state-with-editor))
  (define-editor! state 'e0 "ab\nc" 0 1 #f)
  (step! state 'e1 'e0 'move-right)
  (step! state 'e2 'e1 'move-right)
  (step! state 'e3 'e2 'move-left)
  (step! state 'e4 'e3 'move-down)
  (step! state 'e5 'e4 'move-up)
  (step! state 'e6 'e5 'insert "Z")
  (step! state 'e7 'e6 'newline)
  (step! state 'e8 'e7 'backward-delete)
  (step! state 'e9 'e8 'backward-delete)
  (step! state 'e9-unknown 'e9 'handle-key "home")
  (step! state 'e10 'e9-unknown 'request-quit)
  (step! state 'e11 'e10 'handle-key "left")
  (step! state 'e12 'e11 'handle-key "home")
  (step! state 'e13 'e12 'request-quit)
  (step! state 'e14 'e13 'move-right)

  (for ([expected
         (in-list
          '((e0 "ab\nc" 0 1 #f)
            (e1 "ab\nc" 0 2 #f)
            (e2 "ab\nc" 1 0 #f)
            (e3 "ab\nc" 0 2 #f)
            (e4 "ab\nc" 1 1 #f)
            (e5 "ab\nc" 0 1 #f)
            (e6 "aZb\nc" 0 2 #f)
            (e7 "aZ\nb\nc" 1 0 #f)
            (e8 "aZb\nc" 0 2 #f)
            (e9 "ab\nc" 0 1 #f)
            (e9-unknown "ab\nc" 0 1 #f)
            (e10 "ab\nc" 0 1 #t)
            (e11 "ab\nc" 0 1 #t)
            (e12 "ab\nc" 0 1 #t)
            (e13 "ab\nc" 0 1 #t)
            (e14 "ab\nc" 0 2 #t)))])
    (apply check-focused state expected))
  (check-equal-editor state 'e9-unknown 'e9)
  (check-equal-editor state 'e11 'e10)
  (check-equal-editor state 'e12 'e10)
  (check-equal-editor state 'e13 'e10))

(test-case "vertical clamping forgets the longer line's column"
  (define state (state-with-editor))
  (define-editor! state 'start "abcd\nx\nwxyz" 0 4 #f)
  (step! state 'short 'start 'move-down)
  (step! state 'long-again 'short 'move-down)
  (step! state 'short-again 'long-again 'move-up)
  (step! state 'first-again 'short-again 'move-up)
  (check-focused state 'start "abcd\nx\nwxyz" 0 4 #f)
  (check-focused state 'short "abcd\nx\nwxyz" 1 1 #f)
  (check-focused state 'long-again "abcd\nx\nwxyz" 2 1 #f)
  (check-focused state 'short-again "abcd\nx\nwxyz" 1 1 #f)
  (check-focused state 'first-again "abcd\nx\nwxyz" 0 1 #f))

(test-case "within-line movement, LF crossings, and movement edges"
  (define state (state-with-editor))
  (define-editor! state 'start "ab\ncd" 0 0 #f)
  (step! state 'left-edge 'start 'move-left)
  (step! state 'up-edge 'start 'move-up)
  (step! state 'right-one 'start 'move-right)
  (step! state 'left-one 'right-one 'move-left)
  (define-editor! state 'before-lf "ab\ncd" 0 2 #f)
  (step! state 'after-lf 'before-lf 'move-right)
  (step! state 'back-over-lf 'after-lf 'move-left)
  (define-editor! state 'eof "ab\ncd" 1 2 #f)
  (step! state 'right-edge 'eof 'move-right)
  (step! state 'down-edge 'eof 'move-down)
  (for ([expected
         (in-list '((start 0 0) (left-edge 0 0) (up-edge 0 0)
                    (right-one 0 1) (left-one 0 0) (before-lf 0 2)
                    (after-lf 1 0) (back-over-lf 0 2) (eof 1 2)
                    (right-edge 1 2) (down-edge 1 2)))])
    (apply check-focused state
           (list (car expected) "ab\ncd" (cadr expected)
                 (caddr expected) #f)))
  (for ([edge (in-list '(left-edge up-edge right-edge down-edge))]
        [source (in-list '(start start eof eof))])
    (check-equal-editor state edge source)))

(test-case "raw cold and differently focused editors align only on success"
  (define state (state-with-editor))
  (driver-eval! state
                '(define cold
                   (AloemacsEditor new
                     (Text from-string "aa\nbb\ncc")
                     (Position new 1 1)
                     #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (step! state 'cold-left 'cold 'move-left)
  (step! state 'cold-insert 'cold 'insert "Q")
  (check-focused state 'cold-left "aa\nbb\ncc" 1 0 #f)
  (check-focused state 'cold-insert "aa\nbQb\ncc" 1 2 #f)
  (check-payload state 'cold "aa\nbb\ncc" 1 1 #f)
  (check-equal? (driver-eval! state '((cold text) focus-line)) 0)

  (define-editor! state 'misfocused "aa\nbb\ncc" 1 1 #f 0)
  (step! state 'misfocused-down 'misfocused 'move-down)
  (step! state 'misfocused-newline 'misfocused 'newline)
  (check-focused state 'misfocused-down "aa\nbb\ncc" 2 1 #f)
  (check-focused state 'misfocused-newline "aa\nb\nb\ncc" 2 0 #f)
  (check-equal? (driver-eval! state '((misfocused text) focus-line)) 0)

  (driver-eval! state
                '(define cold-start
                   (AloemacsEditor new
                     (Text from-string "a\nb")
                     (Position new 0 0)
                     #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (step! state 'cold-start-left 'cold-start 'move-left)
  (step! state 'cold-start-up 'cold-start 'move-up)
  (driver-eval! state
                '(define cold-end
                   (AloemacsEditor new
                     (Text from-string "a\nb")
                     (Position new 1 1)
                     #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (step! state 'cold-end-right 'cold-end 'move-right)
  (step! state 'cold-end-down 'cold-end 'move-down)
  (for ([actual (in-list '(cold-start-left cold-start-up
                           cold-end-right cold-end-down))]
        [expected (in-list '(cold-start cold-start
                             cold-end cold-end))])
    (check-equal-editor state actual expected))
  (driver-eval! state
                '(define invalid
                   (AloemacsEditor new
                     (Text from-string "a\nb")
                     (Position new 4 0)
                     #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (step! state 'invalid-insert 'invalid 'insert "x")
  (check-equal-editor state 'invalid-insert 'invalid))

(test-case "consecutive local transitions around line 9000 keep old values"
  (define state (state-with-editor))
  (define source (string-join (make-list 10000 "x") "\n"))
  (driver-eval! state `(define source (Text from-string ,source)))
  (driver-eval! state
                '(define focused
                   ((source focus-at 9000) case
                     (None () source)
                     (Some (text) text))))
  (driver-eval! state
                '(define e0
                   (AloemacsEditor new focused (Position new 9000 0) #f 0 0
                     (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (step! state 'e1 'e0 'move-down)
  (step! state 'e2 'e1 'move-down)
  (step! state 'e3 'e2 'move-right)
  (step! state 'e4 'e3 'move-right)
  (step! state 'e5 'e4 'move-left)
  (step! state 'e6 'e5 'move-up)
  (step! state 'e7 'e6 'insert "z")
  (for ([expected (in-list '((e0 9000 0) (e1 9001 0) (e2 9002 0)
                             (e3 9002 1) (e4 9003 0) (e5 9002 1)
                             (e6 9001 1) (e7 9001 2)))])
    (apply check-point-and-focus state expected))
  (check-equal? (driver-eval! state '((e7 text) current-line)) "xz")
  (check-equal? (driver-eval! state '((e6 text) current-line)) "x")
  (check-equal? (driver-eval! state '((e0 text) current-line)) "x")
  (check-equal? (driver-eval! state '((e0 text) to-string)) source)
  (check-equal? (driver-eval! state '((e7 text) to-string))
                (string-append
                 (string-join (make-list 9001 "x") "\n")
                 "\nxz\n"
                 (string-join (make-list 998 "x") "\n"))))
