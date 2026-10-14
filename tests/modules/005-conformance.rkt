#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  env-bound?)
         (only-in "../../aloe/main.rkt"
                  exn:fail:aloe-type?)
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?)
         (submod "../../aloe/type.rkt" conformance-walk)
         "../../aloe/expression-query.rkt")

(define-runtime-path sym-late-path "fixtures/sym-late.aloe")
(define-runtime-path sym-late-error-path "fixtures/sym-late-error.aloe")
(define-runtime-path core-path "../../examples/mpl/core.aloe")
(define-runtime-path sym-path "../../examples/mpl/sym.aloe")

(define sym-message
  "typecheck: class Sym does not implement protocol Math method show")

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

(define (position-of source text)
  (define positions (regexp-match-positions (regexp-quote text) source))
  (unless positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar positions)))

(test-case "the MPL shape conforms at the root's end"
  (define state (make-driver))
  (check-equal? (driver-load-file! state core-path (open-output-string))
                '()))

(test-case "a loaded class without its methods fails at the root's end"
  (define state (make-driver))
  (check-equal?
   (raised (lambda ()
             (driver-load-file! state sym-late-path (open-output-string))))
   (list #t sym-message))
  ;; The root's own later form is checked before conformance runs.
  (check-equal?
   (raised (lambda ()
             (driver-load-file! (make-driver) sym-late-error-path
                                (open-output-string))))
   (list #t "typecheck: Int + expects an Int argument"))
  (check-false (env-bound? (driver-runtime-environment state) 'after-load)))

(test-case "hover inside the MPL files"
  (check-equal? (raised (lambda () (query-expression-at sym-path 1)))
                (list #t sym-message))
  (define source (file->string core-path))
  (define result
    (query-expression-at core-path
                         (add1 (position-of source "(self name)"))))
  (check-equal? (expression-query-result-type result) 'Sym))

(test-case "the walk reaches the installed Option through the cache"
  (define state (make-driver))
  (define T (driver-type-environment state))
  (define (option-count)
    (count (lambda (name) (eq? name 'Option)) (conformance-classes T)))
  (check-equal? (option-count) 1)
  (driver-eval! state
                '(define-class (Option T)
                   (constructors
                    (None (fields))
                    (Some (fields (value T))))
                   (methods
                    (present? () Bool
                              (self case
                                    (None () #f)
                                    (Some (value) #t))))))
  (check-equal? (option-count) 2))
