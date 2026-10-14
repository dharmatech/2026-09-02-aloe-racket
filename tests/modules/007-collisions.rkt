#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  env-base
                  env-bound?
                  env-lookup)
         (only-in "../../aloe/main.rkt"
                  exn:fail:aloe-type?
                  type->datum
                  type-of)
         (only-in "../../aloe/parse.rkt"
                  parse-datum)
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?)
         "../../aloe/expression-query.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path view-a-path "fixtures/view-a.aloe")
(define-runtime-path view-b-path "fixtures/view-b.aloe")
(define-runtime-path view-both-path "fixtures/view-both.aloe")
(define-runtime-path view-redefined-path "fixtures/view-redefined.aloe")
(define-runtime-path view-after-alpha-path "fixtures/view-after-alpha.aloe")
(define-runtime-path view-b-user-path "fixtures/view-b-user.aloe")
(define-runtime-path view-local-path "fixtures/view-local.aloe")
(define-runtime-path defines-option-path "fixtures/defines-option.aloe")
(define-runtime-path defines-list-path "fixtures/defines-list.aloe")
(define-runtime-path defines-mirror-path "fixtures/defines-mirror.aloe")
(define-runtime-path defines-fs-host-path "fixtures/defines-fs-host.aloe")
(define-runtime-path defines-twice-path "fixtures/defines-twice.aloe")
(define-runtime-path diamond-leaf-path "fixtures/diamond-leaf.aloe")
(define-runtime-path diamond-top-path "fixtures/diamond-top.aloe")
(define-runtime-path shared-one-path "fixtures/shared-one.aloe")
(define-runtime-path shared-two-path "fixtures/shared-two.aloe")
(define-runtime-path text-library-path "../../lib/text.aloe")
(define-runtime-path fs-library-path "../../lib/fs.aloe")
(define-runtime-path option-library-path "../../lib/option.aloe")

(define (load-datum path)
  `(load ,(path->string path)))

(define (runtime state)
  (driver-runtime-environment state))

(define (checker state)
  (driver-type-environment state))

;; Bound in both halves of the driver.
(define (bound? state name)
  (and (env-bound? (runtime state) name)
       (type-environment-bound? (checker state) name)))

;; Unbound in both halves of the driver.
(define (unbound? state name)
  (not (or (env-bound? (runtime state) name)
           (type-environment-bound? (checker state) name))))

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

(define (load! state path)
  (driver-eval! state (load-datum path)))

;; The collision error as raised: a type error naming both sides.
(define (collision name first second)
  (list #t
        (format "typecheck: name collision: ~a is defined by ~a and by ~a"
                name first second)))

(define (position-of source text)
  (define positions (regexp-match-positions (regexp-quote text) source))
  (unless positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar positions)))

(define (fs-double)
  (make-fs-double "/cwd" (hash "/cwd" 'directory)))

(define view-a "tests/modules/fixtures/view-a.aloe")
(define view-b "tests/modules/fixtures/view-b.aloe")

(test-case "a third file loads both"
  (check-equal? (raised (lambda () (load! (make-driver) view-both-path)))
                (collision 'View view-a view-b)))

(test-case "two loads into the prompt, and the entry survives"
  (define state (make-driver))
  (load! state view-a-path)
  (define a-view (driver-eval! state 'View))
  (check-equal? (raised (lambda () (load! state view-b-path)))
                (collision 'View view-a view-b))
  (check-eq? (driver-eval! state 'View) a-view)
  (check-not-exn
   (lambda () (type-of (parse-datum '(View new)) (checker state))))
  (check-not-exn (lambda () (driver-eval! state '(View new))))
  (check-equal? (raised (lambda () (load! state view-b-user-path)))
                'no-error)
  (check-true (bound? state 'b-view))
  (check-eq? (driver-eval! state 'View) a-view))

(test-case "a file defines Option"
  (check-equal?
   (raised (lambda () (load! (make-driver) defines-option-path)))
   (collision 'Option
              "lib/option.aloe"
              "tests/modules/fixtures/defines-option.aloe")))

(test-case "a file defines List, checked before its value"
  (check-equal?
   (raised (lambda () (load! (make-driver) defines-list-path)))
   (collision 'List
              "the language base"
              "tests/modules/fixtures/defines-list.aloe")))

(test-case "a protocol and a host"
  (check-equal?
   (raised (lambda () (load! (make-driver) defines-mirror-path)))
   (collision 'Mirror
              "the language base"
              "tests/modules/fixtures/defines-mirror.aloe"))
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (fs-double))
  (check-equal?
   (raised (lambda () (load! state defines-fs-host-path)))
   (collision 'fs-host
              "the language base"
              "tests/modules/fixtures/defines-fs-host.aloe")))

(test-case "the prompt, then a file"
  (define state (make-driver))
  (driver-eval! state '(define-class View (fields) (methods)))
  (define prompt-view (driver-eval! state 'View))
  (check-equal? (raised (lambda () (load! state view-a-path)))
                (collision 'View "the prompt" view-a))
  (check-eq? (driver-eval! state 'View) prompt-view))

(test-case "nothing from a colliding copy lands"
  (define state (make-driver))
  (driver-eval! state '(define View 0))
  (check-equal? (raised (lambda () (load! state view-after-alpha-path)))
                (collision 'View
                           "the prompt"
                           "tests/modules/fixtures/view-after-alpha.aloe"))
  (check-true (unbound? state 'alpha)))

(test-case "a file defines a name its load copied in"
  (check-equal?
   (raised (lambda () (load! (make-driver) view-redefined-path)))
   (collision 'View view-a "tests/modules/fixtures/view-redefined.aloe")))

(test-case "two roots"
  (define state (make-driver))
  (check-equal? (driver-load-file! state shared-one-path (open-output-string))
                '())
  (check-equal?
   (raised (lambda ()
             (driver-load-file! state shared-two-path (open-output-string))))
   (collision 'shared
              "tests/modules/fixtures/shared-one.aloe"
              "tests/modules/fixtures/shared-two.aloe"))
  (check-equal? (driver-eval! state 'shared) 1))

(test-case "the prompt may replace a copied name"
  (define state (make-driver))
  (load! state view-a-path)
  (define a-view (driver-eval! state 'View))
  (driver-eval! state '(define-class View (fields (y Int)) (methods)))
  (check-not-exn
   (lambda () (type-of (parse-datum '(View new 1)) (checker state))))
  (check-not-exn (lambda () (driver-eval! state '(View new 1))))
  (check-false (eq? (driver-eval! state 'View) a-view))
  (check-equal? (raised (lambda () (load! state view-a-path)))
                (collision 'View "the prompt" view-a)))

(test-case "the same cached definition twice is not a collision"
  (define state (make-driver))
  (define R (runtime state))
  (for ([path (list text-library-path fs-library-path option-library-path)])
    (check-equal? (raised (lambda () (load! state path))) 'no-error))
  (check-eq? (driver-eval! state 'Option) (env-lookup (env-base R) 'Option))
  (define diamond-state (make-driver))
  (check-equal? (raised (lambda () (load! diamond-state diamond-top-path)))
                'no-error)
  (check-true (bound? diamond-state 'top-leaf))
  (check-true (unbound? diamond-state 'left-leaf))
  (check-equal? (raised (lambda () (load! diamond-state diamond-leaf-path)))
                'no-error)
  (define leaf (driver-eval! diamond-state 'Leaf))
  (check-equal? (raised (lambda () (load! diamond-state diamond-leaf-path)))
                'no-error)
  (check-eq? (driver-eval! diamond-state 'Leaf) leaf))

(test-case "replacement within one environment"
  (define state (make-driver))
  (load! state defines-twice-path)
  (check-equal? (driver-eval! state 'twice-name) "two")
  (check-equal?
   (type->datum (type-of (parse-datum 'twice-name) (checker state)))
   'String)
  (define prompt-state (make-driver))
  (driver-eval! prompt-state '(define p 1))
  (driver-eval! prompt-state '(define p "x"))
  (check-equal? (driver-eval! prompt-state 'p) "x"))

(test-case "a local scope is not checked"
  (define state (make-driver))
  (check-equal? (raised (lambda () (load! state view-local-path))) 'no-error)
  (check-true (bound? state 'a-view)))

(test-case "a base-library query is not a collision"
  (define source (file->string option-library-path))
  (define result
    (query-expression-at option-library-path
                         (add1 (position-of source "(self case"))))
  (check-equal? (expression-query-result-type result) '(Option T)))
