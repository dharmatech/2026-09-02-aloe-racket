#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         "../aloe/eval.rkt"
         (prefix-in runtime: "../aloe/env.rkt")
         "../aloe/library.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt"
         (prefix-in checker: "../aloe/type.rkt"))

(define-runtime-path string-library-path "../lib/string.aloe")
(define-runtime-path eval-path "../aloe/eval.rkt")
(define-runtime-path env-path "../aloe/env.rkt")
(define-runtime-path type-path "../aloe/type.rkt")

(define exact-string-library-source
  (string-append
   "(define-methods String\n"
   "  (methods\n"
   "    (starts-with? (prefix String) Bool\n"
   "      ((self take (prefix len)) = prefix))))\n"))

(define (checked-type source [environment (make-type-environment)])
  (type->datum (typecheck-source source environment)))

(define starts-with-cases
  (list (list "(\"hello\" starts-with? \".\")" #f)
        (list "(\".bashrc\" starts-with? \".\")" #t)
        (list "(\".\" starts-with? \".\")" #t)
        (list "(\"\" starts-with? \".\")" #f)
        (list "(\"abc\" starts-with? \"ab\")" #t)
        (list "(\"ab\" starts-with? \"abc\")" #f)
        (list "(\"abc\" starts-with? \"\")" #t)
        (list "(\"\" starts-with? \"\")" #t)))

(test-case "String starts-with has the specified values and Bool type"
  (for ([entry (in-list starts-with-cases)])
    (define source (car entry))
    (define expected (cadr entry))
    (check-equal? (eval-source source) expected source)
    (check-equal? (checked-type source) 'Bool source)))

(test-case "starts-with requires a String prefix statically and at runtime"
  (check-exn
   exn:fail:aloe-type?
   (lambda () (typecheck-source "(\"abc\" starts-with? 1)")))

  (define raw-environment (runtime:make-top-level-env))
  (eval-exprs (string-library-expressions) raw-environment)
  (check-exn
   #rx"unknown message: starts-with\\?"
   (lambda ()
     (eval-expr
      (parse-datum '("abc" starts-with? 1))
      raw-environment))))

(test-case "public default environments bootstrap the String library"
  (check-true (eval-source "(\".bashrc\" starts-with? \".\")"))

  (define environment (make-top-level-env))
  (check-true
   (eval-source "(\".bashrc\" starts-with? \".\")" environment))

  (define state (make-driver))
  (check-true
   (driver-eval! state '(".bashrc" starts-with? "."))))

(test-case "raw environments remain raw until a public fallback bootstraps them"
  (define raw-runtime-environment (runtime:make-top-level-env))
  (check-exn
   #rx"unknown message: starts-with\\?"
   (lambda ()
     (eval-expr
      (parse-datum '(".bashrc" starts-with? "."))
      raw-runtime-environment)))

  (define raw-type-environment (checker:make-type-environment))
  (check-exn
   checker:exn:fail:aloe-type?
   (lambda ()
     (checker:type-of
      (parse-datum '(".bashrc" starts-with? "."))
      raw-type-environment)))

  (check-true
   (eval-source
    "(\".bashrc\" starts-with? \".\")"
    raw-runtime-environment)))

(test-case "the String library contains exactly the derived starts-with method"
  (check-equal? (file->string string-library-path)
                exact-string-library-source)
  (check-match
   (string-library-expressions)
   (list
    (define-methods-expr
     'String
     (list
      (method-declaration
       'starts-with?
       '()
       (list (parameter-declaration 'prefix 'String))
       'Bool
       (send-expr
        (send-expr
         (variable-expr 'self _)
         'take
         (list (send-expr
                (variable-expr 'prefix _)
                'len
                '()
                _
                _))
         _
         _)
        '=
        (list (variable-expr 'prefix _))
        _
        _)))
     _))))

(define (define-string-reflection! environment)
  (eval-source
   #<<ALOE
(define checkpoint-115-string-mirror (Mirror of "abc"))
(define checkpoint-115-string-messages
  (checkpoint-115-string-mirror messages))
(define checkpoint-115-string-rows
  (checkpoint-115-string-mirror signatures))
(define checkpoint-115-equal-row (checkpoint-115-string-rows first))
(define checkpoint-115-append-row
  ((checkpoint-115-string-rows rest) first))
(define checkpoint-115-len-row
  (((checkpoint-115-string-rows rest) rest) first))
(define checkpoint-115-take-row
  ((((checkpoint-115-string-rows rest) rest) rest) first))
(define checkpoint-115-drop-row
  (((((checkpoint-115-string-rows rest) rest) rest) rest) first))
(define checkpoint-115-split-lines-row
  ((((((checkpoint-115-string-rows rest) rest) rest) rest) rest) first))
(define checkpoint-115-joined-with-row
  (((((((checkpoint-115-string-rows rest) rest) rest) rest) rest) rest) first))
(define checkpoint-115-starts-with-row
  ((((((((checkpoint-115-string-rows rest) rest) rest) rest) rest) rest) rest) first))
ALOE
   environment))

(define (row-selector environment row)
  (eval-source (format "((~a selector) name)" row) environment))

(test-case "default String reflection exposes the kernel split before the Aloe method"
  (define environment (make-top-level-env))
  (void (define-string-reflection! environment))

  (check-equal?
   (eval-source "(checkpoint-115-string-messages len)" environment)
   8)
  (check-equal?
   (eval-source "(checkpoint-115-string-rows len)" environment)
   8)
  (check-equal?
   (for/list ([row (in-list '(checkpoint-115-equal-row
                              checkpoint-115-append-row
                              checkpoint-115-len-row
                              checkpoint-115-take-row
                              checkpoint-115-drop-row
                              checkpoint-115-split-lines-row
                              checkpoint-115-joined-with-row
                              checkpoint-115-starts-with-row))])
     (row-selector environment row))
   '("=" "append" "len" "take" "drop" "split-lines" "joined-with" "starts-with?"))
  (check-equal?
   (eval-source "((checkpoint-115-starts-with-row params) len)" environment)
   1)
  (check-equal?
   (aloe-value->string
    (eval-source
     "((checkpoint-115-starts-with-row params) first)"
     environment))
   "#<Symbol String>")
  (check-equal?
   (aloe-value->string
    (eval-source "(checkpoint-115-starts-with-row return)" environment))
   "#<Symbol Bool>")
  (check-equal?
   (eval-source "((checkpoint-115-split-lines-row params) len)" environment)
   0)
  (check-equal?
   (aloe-value->string
    (eval-source "(checkpoint-115-split-lines-row return)" environment))
   "#<List #<Symbol List> #<Symbol String>>")
  (check-true
   (eval-source
    (string-append
     "(checkpoint-115-string-mirror invoke "
     "checkpoint-115-starts-with-row \"ab\")")
    environment))
  (check-false
   (eval-source
    (string-append
     "(checkpoint-115-string-mirror invoke "
     "checkpoint-115-starts-with-row \".\")")
    environment)))

(test-case "starts-with stays Aloe-defined and split-lines moves to the kernel"
  (for ([path (in-list (list eval-path env-path type-path))])
    (check-false
     (regexp-match? #rx"starts-with\\?" (file->string path))
     (path->string path)))
  (for ([path (in-list (list eval-path type-path))])
    (check-true
     (regexp-match? #rx"split-lines" (file->string path))
     (path->string path))))

(test-case "List library and String kernel behavior remain available"
  (check-equal?
   (eval-source
    "((List of 1 2 3) fold 0 (fn (sum item) (sum + item)))")
   6)
  (check-equal? (eval-source "(\"é🙂水\" len)") 3)
  (check-equal? (eval-source "(\"é🙂水\" take 2)") "é🙂"))
