#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt"
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/parse.rkt"
         "../../aloe/signature-catalog.rkt"
         (prefix-in checker: "../../aloe/type.rkt"))

(define-runtime-path text-path "../../lib/text.aloe")

(define (checked-type state datum)
  (checker:type->datum
   (checker:type-of (parse-datum datum)
                    (driver-type-environment state))))

(define (row-at index)
  `(,(for/fold ([rows 'joined-rows]) ([n (in-range index)])
       `(,rows rest)) first))

(define (focused source line)
  `(((Text from-string ,source) focus-at ,line) case
      (None () (Text from-string "invalid focus"))
      (Some (text) text)))

(test-case "joined-with keeps zipper order and every empty piece"
  (define state (make-driver))
  (for ([entry (in-list
                (list
                 (list '() "c" '() "|" "c")
                 (list '("b" "a") "c" '() "|" "a|b|c")
                 (list '() "c" '("d" "e") "|" "c|d|e")
                 (list '("b" "a") "c" '("d" "e") "|" "a|b|c|d|e")
                 (list '("a") "" '("b") "|" "a||b")
                 (list '() "c" '("d" "") "|" "c|d|")
                 (list '("" "a") "" '("" "b") "|" "a||||b")
                 (list '("b" "a") "c" '("d" "e") "" "abcde")
                 (list '("b" "a") "c" '("d") "<>" "a<>b<>c<>d")
                 (list '("\uFEFFé" "a\r") "🙂" '("水" "") "\n"
                       "a\r\n\uFEFFé\n🙂\n水\n")))])
    (define above (car entry))
    (define current (cadr entry))
    (define below (caddr entry))
    (define separator (cadddr entry))
    (define expected (car (cddddr entry)))
    (define datum
      `(,separator joined-with
                   ,(if (null? above) '(List empty) `(List of ,@above))
                   ,current
                   ,(if (null? below) '(List empty) `(List of ,@below))))
    (check-equal? (driver-eval! state datum) expected (format "~s" datum))
    (check-equal? (checked-type state datum) 'String (format "~s" datum))))

(test-case "checker and raw runtime reject wrong arity and argument types"
  (define state (make-driver))
  (define raw-runtime (runtime:make-top-level-env))
  (define invalid
    '(("|" joined-with)
      ("|" joined-with (List empty) "c")
      ("|" joined-with (List empty) "c" (List empty) "extra")
      (1 joined-with (List empty) "c" (List empty))
      ("|" joined-with 1 "c" (List empty))
      ("|" joined-with (List empty) 1 (List empty))
      ("|" joined-with (List empty) "c" 1)
      ("|" joined-with (List of 1) "c" (List empty))
      ("|" joined-with (List empty) "c" (List of 1))))
  (for ([datum (in-list invalid)])
    (check-exn checker:exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))
               (format "checked ~s" datum))
    (check-exn exn:fail?
               (lambda () (eval-expr (parse-datum datum) raw-runtime))
               (format "raw ~s" datum)))
  (check-equal?
   (eval-expr
    (parse-datum '("|" joined-with (List empty) "c" (List empty)))
    raw-runtime)
   "c"))

(test-case "joined-with is the seventh String kernel row and exact Mirror row"
  (check-equal?
   (kernel-instance-signature-specs 'String)
   (list (signature-spec '= '(String) 'Bool)
         (signature-spec 'append '(String) 'String)
         (signature-spec 'len '() 'Int)
         (signature-spec 'take '(Int) 'String)
         (signature-spec 'drop '(Int) 'String)
         (signature-spec 'split-lines '() '(List String))
         (signature-spec 'joined-with
                         '((List String) String (List String))
                         'String)))
  (check-equal? (kernel-class-object-signature-specs 'String) '())
  (define state (make-driver))
  (driver-eval! state '(define joined-mirror (Mirror of "|")))
  (driver-eval! state '(define joined-rows (joined-mirror signatures)))
  (check-equal? (driver-eval! state '((joined-mirror messages) len)) 8)
  (check-equal? (driver-eval! state '(joined-rows len)) 8)
  (check-equal?
   (for/list ([index (in-range 8)])
     (driver-eval! state `((,(row-at index) selector) name)))
   '("=" "append" "len" "take" "drop" "split-lines"
     "joined-with" "starts-with?"))
  (check-equal? (driver-eval! state `((,(row-at 6) params) len)) 3)
  (check-equal?
   (aloe-value->string (driver-eval! state `(,(row-at 6) params)))
   "#<List #<List #<Symbol List> #<Symbol String>> #<Symbol String> #<List #<Symbol List> #<Symbol String>>>")
  (check-equal? (aloe-value->string (driver-eval! state `(,(row-at 6) return)))
                "#<Symbol String>")
  (check-equal?
   (driver-eval! state
                 `(joined-mirror invoke ,(row-at 6)
                                 (List of "b" "a") "c" (List of "d" "")))
   "a|b|c|d|")
  (check-equal? (driver-eval! state '(((Mirror of String) messages) len)) 0)
  (for ([selector (in-list '(join joined-with))])
    (check-exn checker:exn:fail:aloe-type?
               (lambda ()
                 (driver-eval! state `(String ,selector (List empty) "c"
                                              (List empty)))))))

(test-case "cold and every indexed focus reproduce exact source"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string text-path)))
  (for ([entry (in-list
                (list (list "" 1)
                      (list "a\nb" 2)
                      (list "a\n\nb\n" 4)
                      (list "\n\n" 3)
                      (list "a\r\nb\r\n" 3)
                      (list "\uFEFFfirst\n" 2)
                      (list "λ🙂\n界" 2)))])
    (define source (car entry))
    (define count (cadr entry))
    (define cold `(Text from-string ,source))
    (check-equal? (driver-eval! state `(,cold to-string)) source)
    (check-equal? (checked-type state `(,cold to-string)) 'String)
    (for ([line (in-range count)])
      (define at-line (focused source line))
      (check-equal? (driver-eval! state `(,at-line focus-line)) line)
      (check-equal? (driver-eval! state `(,at-line to-string)) source)
      (check-equal? (checked-type state `(,at-line to-string)) 'String))))

(test-case "Text.to-string has a direct cold branch and one indexed send"
  (define forms (file->list text-path))
  (define text-class
    (for/first ([form (in-list forms)]
                #:when (and (list? form)
                            (equal? (car form) 'define-class)
                            (equal? (cadr form) 'Text)))
      form))
  (define methods (for/first ([form (in-list (cddr text-class))]
                              #:when (and (list? form)
                                          (equal? (car form) 'methods)))
                    form))
  (define to-string
    (for/first ([form (in-list (cdr methods))]
                #:when (equal? (car form) 'to-string))
      form))
  (check-equal?
   to-string
   '(to-string () String
      (self case
        (from-string (stored-source) stored-source)
        (indexed (above current below focus)
          ("\n" joined-with above current below))))))
