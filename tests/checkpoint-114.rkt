#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         (prefix-in runtime: "../aloe/env.rkt")
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

(define (checked-type source [environment (make-type-environment)])
  (type->datum (typecheck-source source environment)))

(define (check-static-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (typecheck-source source))))

(define successful-kernel-cases
  (list (list "(\"\" len)" 0 'Int)
        (list "(\"abc\" len)" 3 'Int)
        (list "(\"abc\" take 0)" "" 'String)
        (list "(\"abc\" take 2)" "ab" 'String)
        (list "(\"abc\" take 3)" "abc" 'String)
        (list "(\"abc\" take 5)" "abc" 'String)
        (list "(\"abc\" take -1)" "" 'String)
        (list "(\"\" take 2)" "" 'String)))

(test-case "String len and take have the specified values and types"
  (for ([entry (in-list successful-kernel-cases)])
    (define source (car entry))
    (define expected-value (cadr entry))
    (define expected-type (caddr entry))
    (check-equal? (eval-source source) expected-value source)
    (check-equal? (checked-type source) expected-type source)))

(test-case "String len and take count characters rather than encoded bytes"
  (check-equal? (eval-source "(\"é🙂水\" len)") 3)
  (check-equal? (checked-type "(\"é🙂水\" len)") 'Int)
  (check-equal? (eval-source "(\"é🙂水\" take 2)") "é🙂")
  (check-equal? (checked-type "(\"é🙂水\" take 2)") 'String))

(test-case "the checker enforces String kernel arities and exact Int take"
  (for ([source (in-list '("(\"abc\" len 1)"
                           "(\"abc\" take)"
                           "(\"abc\" take 1 2)"
                           "(\"abc\" take 1.0)"
                           "(\"abc\" take #t)"
                           "(\"abc\" take \"2\")"))])
    (check-static-error source)))

(test-case "the raw runtime enforces String kernel arities and exact Int take"
  (define environment (runtime:make-top-level-env))
  (define (raw-eval datum)
    (eval-expr (parse-datum datum) environment))
  (for ([datum (in-list '(("abc" len 1)
                          ("abc" take)
                          ("abc" take 1 2)))])
    (check-exn #rx"arity error" (lambda () (raw-eval datum))))
  (for ([datum (in-list '(("abc" take 1.0)
                          ("abc" take #t)
                          ("abc" take "2")))])
    (check-exn #rx"expects an Int argument"
               (lambda () (raw-eval datum)))))

(test-case "existing String equality and append remain unchanged"
  (check-true (eval-source "(\"same\" = \"same\")"))
  (check-false (eval-source "(\"same\" = \"other\")"))
  (check-equal? (checked-type "(\"same\" = \"same\")") 'Bool)
  (check-equal? (eval-source "(\"al\" append \"oe\")") "aloe")
  (check-equal? (checked-type "(\"al\" append \"oe\")") 'String))

(define empty-method-source
  #<<ALOE
(define-methods String
  (methods
    (empty? () Bool
      ((self len) = 0))))
ALOE
  )

(test-case "define-methods String installs an ordinary Aloe method locally"
  (define checker-environment (make-type-environment))
  (check-equal?
   (checked-type empty-method-source checker-environment)
   'Void)
  (check-equal? (checked-type "(\"\" empty?)" checker-environment) 'Bool)
  (check-equal? (checked-type "(\"x\" empty?)" checker-environment) 'Bool)

  (define environment (make-top-level-env))
  (void (eval-source empty-method-source environment))
  (check-true (eval-source "(\"\" empty?)" environment))
  (check-false (eval-source "(\"x\" empty?)" environment))

  (define fresh-environment (make-top-level-env))
  (check-exn #rx"unknown message: empty\\?"
             (lambda ()
               (eval-source "(\"\" empty?)" fresh-environment)))
  (define raw-fresh-environment (runtime:make-top-level-env))
  (check-exn #rx"unknown message: empty\\?"
             (lambda ()
               (eval-expr
                (parse-datum '("" empty?))
                raw-fresh-environment))))

(test-case "String method type parameters are local and freshly inferred"
  (define source
    #<<ALOE
(define-methods String
  (methods
    (keep (type U) (value U) U value)))
ALOE
    )
  (define checker-environment (make-type-environment))
  (check-equal? (checked-type source checker-environment) 'Void)
  (check-equal?
   (checked-type "(\"receiver\" keep 7)" checker-environment)
   'Int)
  (check-equal?
   (checked-type "(\"receiver\" keep #t)" checker-environment)
   'Bool)
  (define environment (make-top-level-env))
  (void (eval-source source environment))
  (check-equal? (eval-source "(\"receiver\" keep 7)" environment) 7)
  (check-true (eval-source "(\"receiver\" keep #t)" environment)))

(test-case "String does not put a class-level T in method scope"
  (check-static-error
   #<<ALOE
(define-methods String
  (methods
    (bad (value T) T value)))
ALOE
   ))

(test-case "only List String and user classes accept define-methods"
  (for ([target (in-list '(Int Float Bool Symbol))])
    (define source
      (format
       "(define-methods ~a (methods (extended? () Bool #t)))"
       target))
    (check-static-error source)
    (define raw-environment (runtime:make-top-level-env))
    (check-exn exn:fail?
               (lambda ()
                 (eval-expr
                  (parse-datum
                   `(define-methods ,target
                      (methods (extended? () Bool #t))))
                  raw-environment)))))

(define (define-string-reflection-rows! environment)
  (eval-source
   #<<ALOE
(define string-mirror (Mirror of "abc"))
(define string-messages (string-mirror messages))
(define string-rows (string-mirror signatures))
(define string-equal-row (string-rows first))
(define string-append-row ((string-rows rest) first))
(define string-len-row (((string-rows rest) rest) first))
(define string-take-row ((((string-rows rest) rest) rest) first))
(define string-starts-with-row
  (((((string-rows rest) rest) rest) rest) first))
(define string-empty-row
  ((((((string-rows rest) rest) rest) rest) rest) first))
ALOE
   environment))

(define (row-selector environment row)
  (eval-source (format "((~a selector) name)" row) environment))

(define (row-parameter-count environment row)
  (eval-source (format "((~a params) len)" row) environment))

(define (row-first-parameter environment row)
  (aloe-value->string
   (eval-source (format "((~a params) first)" row) environment)))

(define (row-return environment row)
  (aloe-value->string
   (eval-source (format "(~a return)" row) environment)))

(test-case "String reflection reports kernel, library, then installed methods"
  (define environment (make-top-level-env))
  (void (eval-source empty-method-source environment))
  (void (define-string-reflection-rows! environment))

  (check-equal? (eval-source "(string-messages len)" environment) 6)
  (check-equal? (eval-source "(string-rows len)" environment) 6)
  (check-equal?
   (for/list ([row (in-list '(string-equal-row
                              string-append-row
                              string-len-row
                              string-take-row
                              string-starts-with-row
                              string-empty-row))])
     (row-selector environment row))
   '("=" "append" "len" "take" "starts-with?" "empty?"))
  (check-equal?
   (for/list ([row (in-list '(string-equal-row
                              string-append-row
                              string-len-row
                              string-take-row
                              string-starts-with-row
                              string-empty-row))])
     (row-parameter-count environment row))
   '(1 1 0 1 1 0))
  (check-equal? (row-first-parameter environment 'string-equal-row)
                "#<Symbol String>")
  (check-equal? (row-first-parameter environment 'string-append-row)
                "#<Symbol String>")
  (check-equal? (row-first-parameter environment 'string-take-row)
                "#<Symbol Int>")
  (check-equal? (row-first-parameter environment 'string-starts-with-row)
                "#<Symbol String>")
  (check-equal?
   (for/list ([row (in-list '(string-equal-row
                              string-append-row
                              string-len-row
                              string-take-row
                              string-starts-with-row
                              string-empty-row))])
     (row-return environment row))
   '("#<Symbol Bool>"
     "#<Symbol String>"
     "#<Symbol Int>"
     "#<Symbol String>"
     "#<Symbol Bool>"
     "#<Symbol Bool>"))

  (check-equal?
   (eval-source "(string-mirror invoke string-len-row)" environment)
   3)
  (check-equal?
   (eval-source "(string-mirror invoke string-take-row 2)" environment)
   "ab")
  (check-false
   (eval-source "(string-mirror invoke string-empty-row)" environment))
  (check-true
   (eval-source
    "((Mirror of \"\") invoke string-empty-row)"
    environment))

  (define fresh-environment (make-top-level-env))
  (check-equal?
   (eval-source "(((Mirror of \"abc\") messages) len)" fresh-environment)
   5)
  (check-equal?
   (eval-source "(((Mirror of \"abc\") signatures) len)" fresh-environment)
   5))

(test-case "exact invocation of a shadowed String selector runs its Aloe row"
  (define environment (make-top-level-env))
  (void
   (eval-source
    #<<ALOE
(define-methods String
  (methods
    (len () String "Aloe len")))
(define collision-mirror (Mirror of "abc"))
(define collision-rows (collision-mirror signatures))
(define aloe-len-row
  ((((((collision-rows rest) rest) rest) rest) rest) first))
ALOE
    environment))
  (check-equal? (eval-source "(\"abc\" len)" environment) 3)
  (check-equal? (checked-type "(\"abc\" len)") 'Int)
  (check-equal? (eval-source "((collision-mirror messages) len)" environment) 5)
  (check-equal? (row-selector environment 'aloe-len-row) "len")
  (check-equal? (row-return environment 'aloe-len-row) "#<Symbol String>")
  (check-equal?
   (eval-source "(collision-mirror invoke aloe-len-row)" environment)
   "Aloe len"))

(define-runtime-path gel-directory "../gel")

(test-case "String starts-with remains outside Gel"
  (for ([path (in-list (find-files file-exists? gel-directory))])
    (when (file-exists? path)
      (define source (file->string path))
      (check-false (regexp-match? #rx"starts-with\\?|define-methods String"
                                  source)
                   (path->string path)))))
