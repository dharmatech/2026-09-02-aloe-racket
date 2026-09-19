#lang racket/base

(require rackunit
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt"
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/main.rkt"
         "../../aloe/parse.rkt"
         "../../aloe/signature-catalog.rkt"
         (prefix-in checker: "../../aloe/type.rkt"))

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (check-list! state receiver expected)
  (define result
    (driver-eval!
     state
     `(check (,receiver split-lines) (List of ,@expected))))
  (check-equal?
   (aloe-value->string result)
   (format "#<List~a>"
           (apply string-append
                  (for/list ([piece (in-list expected)])
                    (format " ~s" piece))))))

(test-case "String.drop clamps, returns String, and counts characters"
  (define state (make-driver))
  (for ([entry (in-list
                '((("abc" drop -1) "abc")
                  (("abc" drop 0) "abc")
                  (("abc" drop 1) "bc")
                  (("abc" drop 3) "")
                  (("abc" drop 9) "")
                  (("" drop 2) "")
                  (("é🙂水" drop 2) "水")))])
    (define datum (car entry))
    (define expected (cadr entry))
    (check-equal? (driver-eval! state datum) expected (format "~s" datum))
    (check-equal? (driver-type state datum) 'String (format "~s" datum))))

(test-case "take and drop reconstruct every String across clamped bounds"
  (define state (make-driver))
  (for* ([text (in-list '("" "abc" "é🙂水"))]
         [count (in-list '(-2 0 1 2 3 9))])
    (check-equal?
     (driver-eval!
      state
      `(check ((,text take ,count) append (,text drop ,count)) ,text))
     text
     (format "~s at ~a" text count))))

(test-case "drop rejects every wrong checked and raw send shape"
  (define state (make-driver))
  (for ([datum (in-list '(("abc" drop)
                          ("abc" drop 1 2)
                          ("abc" drop 1.0)
                          ("abc" drop #t)
                          ("abc" drop "1")))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))))

  (define environment (runtime:make-top-level-env))
  (define (raw-eval datum)
    (eval-expr (parse-datum datum) environment))
  (for ([datum (in-list '(("abc" drop)
                          ("abc" drop 1 2)))])
    (check-exn #rx"arity error for String drop"
               (lambda () (raw-eval datum))))
  (for ([datum (in-list '(("abc" drop 1.0)
                          ("abc" drop #t)
                          ("abc" drop "1")))])
    (check-exn #rx"String drop expects an Int argument"
               (lambda () (raw-eval datum)))))

(test-case "String reflection exposes drop as the fifth exact kernel row"
  (check-equal?
   (kernel-instance-signature-specs 'String)
   (list (signature-spec '= '(String) 'Bool)
         (signature-spec 'append '(String) 'String)
         (signature-spec 'len '() 'Int)
         (signature-spec 'take '(Int) 'String)
         (signature-spec 'drop '(Int) 'String)))
  (check-equal? (kernel-class-object-signature-specs 'String) '())

  (define state (make-driver))
  (for ([datum (in-list
                '((define prerequisite-mirror (Mirror of "abc"))
                  (define prerequisite-rows (prerequisite-mirror signatures))
                  (define prerequisite-drop-row
                    (((((prerequisite-rows rest) rest) rest) rest) first))
                  (define prerequisite-split-lines-row
                    (((((((prerequisite-rows rest) rest) rest) rest) rest)
                      rest)
                     first))))])
    (void (driver-eval! state datum)))
  (check-equal?
   (driver-eval! state '((prerequisite-drop-row selector) name))
   "drop")
  (check-equal?
   (driver-eval! state '((prerequisite-drop-row params) len))
   1)
  (check-equal?
   (aloe-value->string
    (driver-eval! state '((prerequisite-drop-row params) first)))
   "#<Symbol Int>")
  (check-equal?
   (aloe-value->string (driver-eval! state '(prerequisite-drop-row return)))
   "#<Symbol String>")
  (check-equal?
   (driver-eval!
    state
    '(prerequisite-mirror invoke prerequisite-drop-row 1))
   "bc")
  (check-equal?
   (driver-eval! state '((prerequisite-split-lines-row selector) name))
   "split-lines")
  (check-false
   (for/or ([row (in-list (kernel-instance-signature-specs 'String))])
     (eq? (signature-spec-selector row) 'split-lines)))
  (for ([datum (in-list '((String new)
                          (String drop 1)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))

(test-case "String.split-lines preserves every LF-delimited piece"
  (define state (make-driver))
  (check-equal? (driver-type state '("" split-lines)) '(List String))
  (for ([entry (in-list
                (list (list "" '(""))
                      (list "ab" '("ab"))
                      (list "ab\ncd" '("ab" "cd"))
                      (list "ab\n" '("ab" ""))
                      (list "\n" '("" ""))
                      (list "\na" '("" "a"))
                      (list "a\n\nb\n" '("a" "" "b" ""))
                      (list "a\r\nb" '("a\r" "b"))))])
    (check-list! state (car entry) (cadr entry))))

(test-case "default drivers load both String methods and retain List behavior"
  (define state (make-driver))
  (check-true (driver-eval! state '(".bashrc" starts-with? ".")))
  (check-list! state "ready\n" '("ready" ""))
  (check-equal?
   (driver-eval!
    state
    '((List of 1 2 3) fold 0 (fn (sum item) (sum + item))))
   6))

(test-case "raw environments retain the library bootstrap boundary"
  (define runtime-environment (runtime:make-top-level-env))
  (check-equal?
   (eval-expr (parse-datum '("abc" drop 1)) runtime-environment)
   "bc")
  (check-exn
   #rx"unknown message: split-lines"
   (lambda ()
     (eval-expr
      (parse-datum '("a\nb" split-lines))
      runtime-environment)))

  (define type-environment (checker:make-type-environment))
  (check-equal?
   (checker:type->datum
    (checker:type-of (parse-datum '("abc" drop 1)) type-environment))
   'String)
  (check-exn
   checker:exn:fail:aloe-type?
   (lambda ()
     (checker:type-of
      (parse-datum '("a\nb" split-lines))
      type-environment))))
