#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt"
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/main.rkt"
         "../../aloe/parse.rkt"
         "../../aloe/signature-catalog.rkt"
         (prefix-in checker: "../../aloe/type.rkt"))

(define-runtime-path option-path "../../lib/option.aloe")

(define (loaded-driver)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string option-path)))
  state)

(define (checked-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (row-at index)
  `(,(for/fold ([rows 'search-rows]) ([_ (in-range index)])
       `(,rows rest)) first))

(test-case "find returns the first eligible character index or None"
  (define state (loaded-driver))
  (for ([entry (in-list
                '((("abcabc" find "bc" 0) Some 1)
                  (("abcabc" find "bc" 2) Some 4)
                  (("abcabc" find "bc" 5) None #f)
                  (("ababa" find "aba" 1) Some 2)
                  (("aaaa" find "aa" 0) Some 0)
                  (("abc" find "z" 0) None #f)
                  (("abc" find "a" -7) Some 0)
                  (("abc" find "c" 99) None #f)
                  (("" find "x" 0) None #f)
                  (("" find "" 9) Some 0)
                  (("abc" find "" 99) Some 3)
                  (("abc" find "" -2) Some 0)
                  (("abc" find "" 2) Some 2)
                  (("Abc" find "a" 0) None #f)
                  (("é🙂水🙂" find "🙂" 2) Some 3)
                  (("é🙂水" find "水" 0) Some 2)))])
    (define datum (car entry))
    (define constructor (cadr entry))
    (define index (caddr entry))
    (check-equal? (checked-type state datum) '(Option Int) (format "~s" datum))
    (define result (driver-eval! state datum))
    (check-true (instance-value? result))
    (check-eq? (instance-value-constructor result) constructor (format "~s" datum))
    (when (eq? constructor 'Some)
      (check-equal?
       (driver-eval! state `(,datum case (None () -1) (Some (value) value)))
       index))))

(test-case "checked and raw sends reject invalid shapes"
  (define state (loaded-driver))
  (define raw-environment (runtime:make-top-level-env))
  (eval-expr (parse-datum `(load ,(path->string option-path))) raw-environment)
  (for ([datum (in-list '(("abc" find)
                          ("abc" find "a")
                          ("abc" find "a" 0 1)))])
    (check-exn exn:fail:aloe-type? (lambda () (driver-eval! state datum)))
    (check-exn #rx"arity error for String find"
               (lambda () (eval-expr (parse-datum datum) raw-environment))))
  (for ([datum (in-list '(("abc" find 1 0)
                          ("abc" find "a" 0.0)
                          ("abc" find "a" #t)))])
    (check-exn exn:fail:aloe-type? (lambda () (driver-eval! state datum)))
    (check-exn #rx"String find expects"
               (lambda () (eval-expr (parse-datum datum) raw-environment))))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(2 find "a" 0))))
  (check-exn #rx"unknown message: find"
             (lambda ()
               (eval-expr (parse-datum '(2 find "a" 0)) raw-environment))))

(test-case "the eighth String kernel row is reflected and invokable"
  (check-equal?
   (kernel-instance-signature-specs 'String)
   (list (signature-spec '= '(String) 'Bool)
         (signature-spec 'append '(String) 'String)
         (signature-spec 'len '() 'Int)
         (signature-spec 'take '(Int) 'String)
         (signature-spec 'drop '(Int) 'String)
         (signature-spec 'split-lines '() '(List String))
         (signature-spec 'joined-with
                         '((List String) String (List String)) 'String)
         (signature-spec 'find '(String Int) '(Option Int))))
  (check-equal? (kernel-class-object-signature-specs 'String) '())
  (define state (loaded-driver))
  (driver-eval! state '(define search-mirror (Mirror of "abcabc")))
  (driver-eval! state '(define search-rows (search-mirror signatures)))
  (check-equal? (driver-eval! state '((search-mirror messages) len)) 9)
  (check-equal? (driver-eval! state '(search-rows len)) 9)
  (check-equal?
   (for/list ([index (in-range 9)])
     (driver-eval! state `((,(row-at index) selector) name)))
   '("=" "append" "len" "take" "drop" "split-lines" "joined-with"
     "find" "starts-with?"))
  (check-equal? (driver-eval! state `((,(row-at 7) params) len)) 2)
  (check-equal?
   (aloe-value->string (driver-eval! state `(,(row-at 7) params)))
   "#<List #<Symbol String> #<Symbol Int>>")
  (check-equal?
   (aloe-value->string (driver-eval! state `(,(row-at 7) return)))
   "#<List #<Symbol Option> #<Symbol Int>>")
  (check-eq?
   (instance-value-constructor
    (driver-eval! state `(search-mirror invoke ,(row-at 7) "bc" 5)))
   'None)
  (define reflected-hit
    (driver-eval! state `(search-mirror invoke ,(row-at 7) "bc" 2)))
  (check-eq? (instance-value-constructor reflected-hit) 'Some)
  (check-equal? (aloe-value->string reflected-hit) "#<Option 4>")
  (check-equal? (driver-eval! state '(((Mirror of String) messages) len)) 0)
  (check-equal? (driver-eval! state '(((Mirror of String) signatures) len)) 0)
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(String find "x" 0))))
  (check-exn #rx"unknown message: find"
             (lambda ()
               (eval-expr (parse-datum '(String find "x" 0))
                          (driver-runtime-environment state)))))
