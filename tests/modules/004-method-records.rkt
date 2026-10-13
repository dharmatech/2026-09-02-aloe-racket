#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  [make-top-level-env make-raw-top-level-env]
                  make-local-env
                  env-lookup)
         (only-in "../../aloe/eval.rkt"
                  eval-expr)
         (submod "../../aloe/eval.rkt" method-records)
         (only-in "../../aloe/main.rkt"
                  eval-source
                  exn:fail:aloe-type?
                  make-top-level-env)
         (only-in "../../aloe/parse.rkt"
                  parse-datum)
         (submod "../../aloe/type.rkt" method-records)
         "../../host/racket/fs.rkt")

(define-runtime-path aloemacs-main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path identities-path "../../examples/mpl/identities.aloe")

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

;; Records list each method's selector in order; every record is the one
;; environment named.
(define (check-records records selectors environment)
  (check-equal? (map car records) selectors)
  (for ([record (in-list records)])
    (check-eq? (cdr record) environment (format "~a" (car record)))))

(define (driver-eval-all! state datums)
  (for ([datum (in-list datums)])
    (driver-eval! state datum)))

;; A raw evaluator environment E: no checker, no libraries.
(define (make-raw-evaluator)
  (define environment (make-raw-top-level-env))
  (values environment
          (lambda (datum [where environment])
            (eval-expr (parse-datum datum) where))))

(test-case "a class, a later define-methods, and a protocol record the shared environment"
  (define state (make-driver))
  (define T (driver-type-environment state))
  (define R (driver-runtime-environment state))
  (driver-eval-all!
   state
   '((define-protocol Shape (area () Int))
     (define-class Sq Shape (fields (s Int))
       (methods (area () Int ((self s) * (self s)))))
     (define-methods Sq (methods (twice () Int ((self area) * 2))))))
  (check-equal? (driver-eval! state '((Sq new 3) area)) 9)
  (check-equal? (driver-eval! state '((Sq new 3) twice)) 18)
  (check-records (checker-method-records T 'Sq) '(area twice) T)
  (check-eq? (checker-class-environment T 'Sq) T)
  (check-eq? (checker-protocol-environment T 'Shape) T)
  (check-records (evaluator-method-records R 'Sq) '(area twice) R)
  (check-eq? (evaluator-protocol-environment R 'Shape) R))

(test-case "the base tables are per base"
  (define first-state (make-driver))
  (define second-state (make-driver))
  (define (check-base-records state)
    (define T (driver-type-environment state))
    (define R (driver-runtime-environment state))
    (for ([name (in-list '(List Int String Option))]
          [selectors (in-list '((fold reverse map)
                                (min max)
                                (starts-with?)
                                (present?)))])
      (check-records (checker-method-records T name) selectors T)
      (check-records (evaluator-method-records R name) selectors R)))
  (check-base-records first-state)
  (check-base-records second-state)
  (check-false (eq? (driver-type-environment first-state)
                    (driver-type-environment second-state)))
  (check-false (eq? (driver-runtime-environment first-state)
                    (driver-runtime-environment second-state)))
  (driver-eval! first-state
                '(define-methods Int (methods (thrice () Int (self * 3)))))
  (check-records
   (checker-method-records (driver-type-environment first-state) 'Int)
   '(min max thrice)
   (driver-type-environment first-state))
  (check-records
   (evaluator-method-records (driver-runtime-environment first-state) 'Int)
   '(min max thrice)
   (driver-runtime-environment first-state))
  (check-equal? (driver-eval! first-state '(4 thrice)) 12))

(test-case "a later define-methods leaves earlier records alone"
  (define-values (E evaluate) (make-raw-evaluator))
  (evaluate '(define g 1))
  (evaluate '(define-methods Int (methods (first-g () Int g))))
  (define L (make-local-env E (list (cons 'g 2))))
  (evaluate '(define-methods Int (methods (second-g () Int g))) L)
  (check-equal? (evaluate '(5 first-g)) 1)
  (check-equal? (evaluate '(5 second-g)) 2)
  (define records (evaluator-method-records E 'Int))
  (check-equal? (map car records) '(first-g second-g))
  (check-eq? (cdr (car records)) E)
  (check-eq? (cdr (cadr records)) L))

(test-case "a method runs where it was written"
  (define-values (E evaluate) (make-raw-evaluator))
  (evaluate '(define g 1))
  (evaluate '(define-class Cell (fields) (methods (from-class () Int g))))
  (define L (make-local-env E (list (cons 'g 2))))
  (evaluate '(define-methods Cell (methods (from-later () Int g))) L)
  (check-equal? (evaluate '((Cell new) from-class)) 1)
  (check-equal? (evaluate '((Cell new) from-later)) 2))

(test-case "evaluator selection resolves in the method's environment"
  (define-values (E evaluate) (make-raw-evaluator))
  (evaluate '(define-class K (fields) (methods)))
  (evaluate '(define-class K2 (fields) (methods)))
  (evaluate '(define k1 (K new)))
  (evaluate
   '(define-class C (fields) (methods (n (x K) Int 1) (n (x Int) Int 2))))
  (define shadowing (make-local-env E (list (cons 'K (env-lookup E 'K2)))))
  (check-equal? (evaluate '((C new) n k1) shadowing) 1))

(test-case "checker annotations resolve in the method's environment"
  (define state (make-driver))
  (driver-eval-all!
   state
   '((define-class K (fields) (methods))
     (define k1 (K new))
     (define-class Uses (fields) (methods (take (x K) Int 7)))))
  (check-equal? (driver-eval! state '(let ((K 5)) ((Uses new) take k1))) 7))

(test-case "the deferred re-check runs in the method's environment"
  (define state (make-driver))
  (driver-eval-all!
   state
   '((define g 1)
     (define-class (Holder T) (fields (v T))
       (methods (plus-g () Int (g + 1))))
     (define-class (Bad T) (fields (v T))
       (methods (oops () Int (1 + "a"))))))
  (check-equal?
   (driver-eval! state '(let ((g "s")) ((Holder new 1) plus-g)))
   2)
  (check-equal? (raised (lambda () (driver-eval! state '((Bad new 1) oops))))
                '(#t "typecheck: Int + expects an Int argument")))

(test-case "an AloemacsSession send from the prompt"
  (define state (make-driver))
  (driver-inject-host!
   state
   'fs-host
   (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (check-equal?
   (driver-load-file! state aloemacs-main-path (open-output-string))
   '())
  (check-equal? (driver-eval! state '((aloemacs-editor text) to-string)) ""))

(test-case "the MPL workbook still runs"
  (define environment (make-top-level-env))
  (check-not-exn
   (lambda ()
     (eval-source (file->string identities-path)
                  environment
                  #:source-path identities-path)))
  (check-equal?
   (eval-source "(((x ^ 2) * (x ^ 3)) show)" environment)
   "(x ^ 5)"))
