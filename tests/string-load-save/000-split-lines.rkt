#lang racket/base

(require rackunit
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt"
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/main.rkt"
         "../../aloe/parse.rkt"
         "../../aloe/signature-catalog.rkt"
         (prefix-in checker: "../../aloe/type.rkt"))

(define (list-display pieces)
  (format "#<List~a>"
          (apply string-append
                 (for/list ([piece (in-list pieces)])
                   (format " ~s" piece)))))

(test-case "split-lines preserves every LF-delimited String piece"
  (define state (make-driver))
  (for ([entry (in-list
                '(("" (""))
                  ("ab" ("ab"))
                  ("ab\ncd" ("ab" "cd"))
                  ("ab\n" ("ab" ""))
                  ("\n" ("" ""))
                  ("\na\n\n" ("" "a" "" ""))
                  ("a\n\nb\n" ("a" "" "b" ""))
                  ("a\r\nb" ("a\r" "b"))
                  ("\uFEFFé🙂\n水\r" ("\uFEFFé🙂" "水\r"))))])
    (define source (car entry))
    (define pieces (cadr entry))
    (define result (driver-eval! state `(,source split-lines)))
    (check-equal? (aloe-value->string result) (list-display pieces) source)
    (check-equal?
     (aloe-value->string
      (driver-eval! state `(check (,source split-lines) (List of ,@pieces))))
     (list-display pieces)
     source)
    (check-equal?
     (type->datum
      (type-of (parse-datum `(,source split-lines))
               (driver-type-environment state)))
     '(List String)
     source)))

(test-case "split-lines is a zero-argument String kernel send"
  (define state (make-driver))
  (check-equal? (aloe-value->string (driver-eval! state '("x" split-lines)))
                "#<List \"x\">")
  (for ([datum (in-list '(("x" split-lines 1)
                          ("x" split-lines 1 2)
                          (3 split-lines)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))))

  (define raw-runtime (runtime:make-top-level-env))
  (define raw-checker (checker:make-type-environment))
  (check-equal?
   (aloe-value->string
    (eval-expr (parse-datum '("a\nb" split-lines)) raw-runtime))
   "#<List \"a\" \"b\">")
  (check-equal?
   (checker:type->datum
    (checker:type-of (parse-datum '("a\nb" split-lines)) raw-checker))
   '(List String))
  (for ([datum (in-list '(("x" split-lines 1)
                          ("x" split-lines 1 2)))])
    (check-exn #rx"arity error for String split-lines"
               (lambda () (eval-expr (parse-datum datum) raw-runtime))))
  (check-exn #rx"unknown message: split-lines"
             (lambda ()
               (eval-expr (parse-datum '(3 split-lines)) raw-runtime)))
  (check-exn #rx"unknown message: starts-with\\?"
             (lambda ()
               (eval-expr
                (parse-datum '("abc" starts-with? "a")) raw-runtime)))
  (check-exn checker:exn:fail:aloe-type?
             (lambda ()
               (checker:type-of
                (parse-datum '("abc" starts-with? "a")) raw-checker)))
  (check-true (driver-eval! state '("abc" starts-with? "a"))))

(define expected-kernel-rows
  (list (signature-spec '= '(String) 'Bool)
        (signature-spec 'append '(String) 'String)
        (signature-spec 'len '() 'Int)
        (signature-spec 'take '(Int) 'String)
        (signature-spec 'drop '(Int) 'String)
        (signature-spec 'split-lines '() '(List String))
        (signature-spec 'joined-with
                        '((List String) String (List String))
                        'String)
        (signature-spec 'find '(String Int) '(Option Int))))

(define (row-at index)
  `(,(for/fold ([rows 'rows-000]) ([n (in-range index)])
       `(,rows rest)) first))

(test-case "catalog, reflection, and exact Mirror invocation agree"
  (check-equal? (kernel-instance-signature-specs 'String)
                expected-kernel-rows)
  (check-equal? (kernel-class-object-signature-specs 'String) '())
  (define state (make-driver))
  (driver-eval! state '(define mirror-000 (Mirror of "a\nb")))
  (driver-eval! state '(define rows-000 (mirror-000 signatures)))
  (check-equal? (driver-eval! state '((mirror-000 messages) len)) 9)
  (check-equal? (driver-eval! state '(rows-000 len)) 9)
  (check-equal?
   (for/list ([index (in-range 9)])
     (driver-eval! state `((,(row-at index) selector) name)))
   '("=" "append" "len" "take" "drop" "split-lines" "joined-with" "find" "starts-with?"))
  (check-equal? (driver-eval! state `((,(row-at 5) params) len)) 0)
  (check-equal?
   (aloe-value->string (driver-eval! state `(,(row-at 5) return)))
   "#<List #<Symbol List> #<Symbol String>>")
  (check-equal?
   (aloe-value->string
    (driver-eval! state `(mirror-000 invoke ,(row-at 5))))
   "#<List \"a\" \"b\">")
  (check-equal?
   (aloe-value->string (driver-eval! state '((Mirror of "String") messages)))
   "#<List #<Symbol => #<Symbol append> #<Symbol len> #<Symbol take> #<Symbol drop> #<Symbol split-lines> #<Symbol joined-with> #<Symbol find> ...>")
  (check-equal?
   (driver-eval! state '(((Mirror of String) messages) len))
   0))
