#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum))

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (bound-in-driver? state name)
  (and (env-bound? (driver-runtime-environment state) name)
       (type-environment-bound? (driver-type-environment state) name)))

(define (unbound-in-driver? state name)
  (and (not (env-bound? (driver-runtime-environment state) name))
       (not (type-environment-bound? (driver-type-environment state) name))))

(define (load-editor! state)
  (driver-eval! state `(load ,(path->string editor-path))))

(define (editor-expression source line column quit)
  `(AloemacsEditor new
     (Text from-string ,source)
     (Position new ,line ,column)
     ,quit))

(define (define-editor! state name source line column quit)
  (driver-eval!
   state
   `(define ,name ,(editor-expression source line column quit))))

(define (check-editor-unchanged state name source line column quit)
  (check-equal? (driver-eval! state `((,name text) to-string)) source)
  (check-equal? (driver-eval! state `((,name point) line)) line)
  (check-equal? (driver-eval! state `((,name point) column)) column)
  (check-equal? (driver-eval! state `(,name quit)) quit))

(define empty-frame
  "\u001b[?25l\u001b[2J\u001b[H\r\n\r\n\r\n\u001b[1;1H\u001b[?25h")

(define vertical-frame
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   "two\r\nthree\r\nfour\r\nfive"
   "\u001b[4;5H\u001b[?25h"))

(define horizontal-frame
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   "3456789\r\n\r\n\r\n"
   "\u001b[1;8H\u001b[?25h"))

(define shared-origin-frame
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   "3456789\r\ndefghij"
   "\u001b[2;8H\u001b[?25h"))

(test-case "frame loads explicitly, checks as String, and needs no Term"
  (define state (make-driver))
  (check-true (unbound-in-driver? state 'AloemacsEditor))
  (check-true (unbound-in-driver? state 'term))

  (check-true (void? (load-editor! state)))
  (check-true (bound-in-driver? state 'AloemacsEditor))
  (check-true (bound-in-driver? state 'Text))
  (check-true (unbound-in-driver? state 'term))
  (check-equal?
   (driver-type state
                `(,(editor-expression "" 0 0 #f) frame 8 4))
   'String))

(test-case "empty frame has four blank rows and exact ANSI ordering"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'empty-source "" 0 0 #f)

  (check-equal? (driver-eval! state '(empty-source frame 8 4)) empty-frame)
  (check-equal? (driver-eval! state '(empty-source frame 8 4)) empty-frame)
  (check-editor-unchanged state 'empty-source "" 0 0 #f))

(test-case "frame clips vertically and leaves its source editor unchanged"
  (define state (make-driver))
  (load-editor! state)
  (define source "zero\none\ntwo\nthree\nfour\nfive")
  (define-editor! state 'vertical-source source 5 4 #f)

  (check-equal?
   (driver-eval! state '(vertical-source frame 8 4))
   vertical-frame)
  (check-editor-unchanged state 'vertical-source source 5 4 #f))

(test-case "frame clips horizontally and renders missing source lines blank"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'horizontal-source "0123456789" 0 10 #f)

  (check-equal?
   (driver-eval! state '(horizontal-source frame 8 4))
   horizontal-frame)
  (check-editor-unchanged
   state 'horizontal-source "0123456789" 0 10 #f))

(test-case "all rows share one horizontal origin and frame ignores quit"
  (define state (make-driver))
  (load-editor! state)
  (define source "0123456789\nabcdefghij")
  (define-editor! state 'running-source source 1 10 #f)
  (define-editor! state 'quit-source source 1 10 #t)

  (define running-frame
    (driver-eval! state '(running-source frame 8 2)))
  (define quit-frame
    (driver-eval! state '(quit-source frame 8 2)))
  (check-equal? running-frame shared-origin-frame)
  (check-equal? quit-frame shared-origin-frame)
  (check-equal? running-frame quit-frame)
  (check-editor-unchanged state 'running-source source 1 10 #f)
  (check-editor-unchanged state 'quit-source source 1 10 #t))

(test-case "unscrolled cursor coordinates are one-based for another size"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'small-source "ab\nc" 0 1 #f)
  (define expected
    (string-append
     "\u001b[?25l\u001b[2J\u001b[H"
     "ab\r\nc"
     "\u001b[1;2H\u001b[?25h"))

  (check-equal? (driver-eval! state '(small-source frame 5 2)) expected)
  (check-editor-unchanged state 'small-source "ab\nc" 0 1 #f))
