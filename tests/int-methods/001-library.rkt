#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         (prefix-in driver: "../../aloe/driver.rkt")
         (only-in "../../aloe/eval.rkt" eval-expr eval-exprs)
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/library.rkt"
         "../../aloe/main.rkt"
         "../../aloe/parse.rkt"
         "../../aloe/signature-catalog.rkt"
         "../../aloe/signature.rkt"
         "../../aloe/symbol.rkt"
         (prefix-in checker: "../../aloe/type.rkt"))

(define-runtime-path int-library-path "../../lib/int.aloe")

(define exact-int-library-source
  (string-append
   #<<ALOE
(define-methods Int
  (methods
    (min (other Int) Int
      (if (self < other) self other))
    (max (other Int) Int
      (if (self > other) self other))))
ALOE
   "\n"))

(define kernel-selectors '(+ - * / < > <= >= = float text))
(define default-selectors (append kernel-selectors '(min max)))

(define (checked-type source [environment (make-type-environment)])
  (type->datum (typecheck-source source environment)))

(define (raw-eval datum environment)
  (eval-expr (parse-datum datum) environment))

(define (row-source index)
  (format "(~a first)"
          (for/fold ([source "int-rows"]) ([_ (in-range index)])
            (format "(~a rest)" source))))

(define (runtime-row->spec row)
  (signature-spec
   (string->symbol (symbol-value-name (signature-value-selector row)))
   (signature-value-parameter-data row)
   (signature-value-return-data row)))

(test-case "library is exactly one form with two derived Aloe methods"
  (check-equal? (file->string int-library-path) exact-int-library-source)
  (check-match
   (int-library-expressions)
   (list
    (define-methods-expr
     'Int
     (list
      (method-declaration 'min '()
                          (list (parameter-declaration 'other 'Int))
                          'Int _)
      (method-declaration 'max '()
                          (list (parameter-declaration 'other 'Int))
                          'Int _))
     _)))
  (define kernel-rows (kernel-instance-signature-specs 'Int))
  (check-equal? (length kernel-rows) 11)
  (check-equal? (map signature-spec-selector kernel-rows) kernel-selectors)
  (check-false (member 'min (map signature-spec-selector kernel-rows)))
  (check-false (member 'max (map signature-spec-selector kernel-rows)))
  (define raw (runtime:make-top-level-env))
  (for ([selector (in-list '(min max))])
    (check-exn #rx"unknown message"
               (lambda () (raw-eval `(3 ,selector 2) raw)))))

(test-case "min and max return Int for every sign combination and tie"
  (for ([row (in-list '((3 2 2 3)
                       (-3 2 -3 2)
                       (3 -2 -2 3)
                       (-3 -2 -3 -2)
                       (3 3 3 3)
                       (-3 -3 -3 -3)))])
    (define receiver (first row))
    (define argument (second row))
    (for ([selector (in-list '(min max))]
          [expected (in-list (list (third row) (fourth row)))])
      (define source (format "(~a ~a ~a)" receiver selector argument))
      (check-equal? (checked-type source) 'Int source)
      (check-equal? (eval-source source) expected source))))

(test-case "method argument types and arities are checked and enforced"
  (for ([source (in-list '("(3 min \"x\")" "(3 max 2.0)"
                          "(3 min)" "(3 max)"
                          "(3 min 1 2)" "(3 max 1 2)"))])
    (check-exn exn:fail:aloe-type?
               (lambda () (checked-type source))))
  (define raw (runtime:make-top-level-env))
  (eval-exprs (int-library-expressions) raw)
  (for ([datum (in-list '((3 min "x") (3 max 2.0)
                          (3 min) (3 max)
                          (3 min 1 2) (3 max 1 2)))])
    (check-exn exn:fail? (lambda () (raw-eval datum raw)))))

(test-case "public defaults and raw-runtime fallback install per environment"
  (define types (make-type-environment))
  (check-equal? (checked-type "(3 min 2)" types) 'Int)
  (check-equal? (checked-type "(3 max 2)" types) 'Int)
  (define environment (make-top-level-env))
  (check-equal? (raw-eval '(3 min 2) environment) 2)
  (check-equal? (raw-eval '(3 max 2) environment) 3)
  (check-equal? (eval-source "(3 min 2)") 2)
  (check-equal? (eval-source "(3 max 2)") 3)
  (define state (driver:make-driver))
  (check-equal? (driver:driver-eval! state '(3 min 2)) 2)
  (check-equal? (driver:driver-eval! state '(3 max 2)) 3)
  (define raw-type (checker:make-type-environment))
  (define raw-runtime (runtime:make-top-level-env))
  (for ([selector (in-list '(min max))])
    (check-exn checker:exn:fail:aloe-type?
               (lambda ()
                 (checker:type-of (parse-datum `(3 ,selector 2)) raw-type)))
    (check-exn #rx"unknown message"
               (lambda () (raw-eval `(3 ,selector 2) raw-runtime))))
  (check-equal? (eval-source "(3 min 2)" raw-runtime) 2)
  (check-equal? (eval-source "(3 max 2)" raw-runtime) 3)
  (check-equal? (eval-datum '(3 min 2) (runtime:make-top-level-env)) 2)
  (check-equal? (eval-program '((3 max 2)) (runtime:make-top-level-env)) 3)
  (define extension
    "(define-methods Int (methods (local-001 () Int 42)))")
  (check-equal? (checked-type extension types) 'Void)
  (check-equal? (checked-type "(3 local-001)" types) 'Int)
  (check-exn exn:fail:aloe-type?
             (lambda () (checked-type "(3 local-001)")))
  (eval-source extension environment)
  (check-equal? (eval-source "(3 local-001)" environment) 42)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source "(3 local-001)" (make-top-level-env)))))

(test-case "Int reflection appends both exact library rows after the kernel"
  (define types (make-type-environment))
  (define checker-rows
    (checker:type-signature-specs (checker:int-type) types))
  (check-equal? (map signature-spec-selector checker-rows)
                default-selectors)
  (check-equal? (drop checker-rows 11)
                (list (signature-spec 'min '(Int) 'Int)
                      (signature-spec 'max '(Int) 'Int)))
  (define environment (make-top-level-env))
  (eval-source "(define int-mirror (Mirror of 3))" environment)
  (eval-source "(define int-rows (int-mirror signatures))" environment)
  (check-equal? (eval-source "(int-rows len)" environment) 13)
  (define runtime-rows
    (for/list ([index (in-range 13)])
      (runtime-row->spec (eval-source (row-source index) environment))))
  (check-equal? runtime-rows checker-rows)
  (check-equal? (eval-source "((int-mirror messages) len)" environment)
                13)
  (check-equal? (length (remove-duplicates
                         (map signature-spec-selector runtime-rows)))
                13)
  (check-equal? (eval-source "(3 min 2)" environment) 2)
  (check-equal? (eval-source "(3 max 2)" environment) 3)
  (check-equal?
   (eval-source
    (format "(int-mirror invoke ~a 2)" (row-source 11))
    environment)
   2)
  (check-equal?
   (eval-source
    (format "(int-mirror invoke ~a 2)" (row-source 12))
    environment)
   3))
