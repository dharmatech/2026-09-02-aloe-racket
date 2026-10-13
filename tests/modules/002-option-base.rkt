#lang racket/base

(require racket/file
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  [make-top-level-env make-raw-top-level-env]
                  env-bound?
                  env-lookup)
         (only-in "../../aloe/eval.rkt"
                  eval-expr)
         "../../aloe/main.rkt"
         (only-in "../../aloe/parse.rkt"
                  parse-datum)
         (only-in "../../aloe/type.rkt"
                  [make-type-environment make-raw-type-environment]
                  type-environment-bound?)
         "../../aloe/expression-query.rkt"
         "../../aloe/completion-query.rkt")

(define-runtime-path list-library-path "../../lib/list.aloe")
(define-runtime-path string-library-path "../../lib/string.aloe")
(define-runtime-path option-library-path "../../lib/option.aloe")
(define-runtime-path text-library-path "../../lib/text.aloe")
(define-runtime-path fs-library-path "../../lib/fs.aloe")

(define (load-datum path)
  `(load ,(path->string path)))

(define (changed-message displayed)
  (format "typecheck: load file changed: ~a; this version does not reload a changed file"
          displayed))

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

(define (runtime-value state name)
  (env-lookup (driver-runtime-environment state) name))

(define (position-of source text)
  (define positions (regexp-match-positions (regexp-quote text) source))
  (unless positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar positions)))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-option-base-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

;; The SPEC.md section 3.1 Option, defined at the prompt.
(define prompt-option
  '(define-class (Option T)
     (constructors
       (None (fields))
       (Some (fields (value T))))
     (methods
       (present? () Bool
         (self case
           (None () #f)
           (Some (value) #t))))))

(define prompt-option-text (format "~s" prompt-option))

(define unknown-constructor-names '(Some None))

(test-case "a fresh base binds Option"
  (define state (make-driver))
  (check-true (env-bound? (driver-runtime-environment state) 'Option))
  (check-true
   (type-environment-bound? (driver-type-environment state) 'Option))
  (for ([name (in-list unknown-constructor-names)])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))

  (define checker-environment (make-type-environment))
  (check-true (type-environment-bound? checker-environment 'Option))
  (define runtime-environment (make-top-level-env))
  (check-true (env-bound? runtime-environment 'Option))
  (check-equal? (raised (lambda ()
                          (eval-source "(Option Some 1)" runtime-environment)))
                'no-error)
  (for ([name (in-list unknown-constructor-names)])
    (check-false (type-environment-bound? checker-environment name))
    (check-false (env-bound? runtime-environment name)))

  (check-false
   (type-environment-bound? (make-raw-type-environment) 'Option))
  (check-false (env-bound? (make-raw-top-level-env) 'Option)))

(test-case "find returns the base class"
  (define state (make-driver))
  (check-equal?
   (raised
    (lambda ()
      (driver-eval! state '(define found ("abc" find "b" 0)))
      (driver-eval! state '(check found (Option Some 1)))))
   'no-error)
  (driver-eval! state prompt-option)
  (check-equal?
   (raised (lambda () (driver-eval! state '(check found ("abc" find "b" 0)))))
   'no-error)
  (check-equal?
   (car (raised
         (lambda ()
           (driver-eval! state '(check ("abc" find "b" 0) (Option Some 1))))))
   #t)

  (for ([environment (in-list (list (make-top-level-env)
                                    (make-raw-top-level-env)))])
    (check-equal?
     (raised
      (lambda ()
        (eval-source "(define found (\"abc\" find \"b\" 0))" environment)
        (eval-source "(check found (Option Some 1))" environment)))
     'no-error)
    (eval-source prompt-option-text environment)
    (check-equal?
     (raised
      (lambda ()
        (eval-source "(check found (\"abc\" find \"b\" 0))" environment)))
     'no-error)
    (check-equal?
     (car (raised
           (lambda ()
             (eval-source "(check (\"abc\" find \"b\" 0) (Option Some 1))"
                          environment))))
     #t))

  (check-equal?
   (type->datum (typecheck-source "(\"abc\" find \"b\" 0)"
                                  (make-type-environment)))
   '(Option Int)))

(test-case "a raw environment rejects find"
  (define find-expression (parse-datum '("abc" find "b" 0)))
  (check-equal?
   (raised (lambda () (type-of find-expression (make-raw-type-environment))))
   (list #t "typecheck: unbound symbol: Option"))
  (define runtime-environment (make-raw-top-level-env))
  (check-equal?
   (raised (lambda () (eval-expr find-expression runtime-environment)))
   (list #f "eval-aloe: unbound symbol: Option"))
  (eval-expr (parse-datum (load-datum option-library-path))
             runtime-environment)
  (check-true (env-bound? runtime-environment 'Option))
  (check-equal?
   (raised (lambda () (eval-expr find-expression runtime-environment)))
   (list #f "eval-aloe: unbound symbol: Option")))

(test-case "the install is an entry"
  (define state (make-driver))
  (define option-class (runtime-value state 'Option))
  (check-equal?
   (raised (lambda () (driver-eval! state (load-datum option-library-path))))
   'no-error)
  (check-eq? (runtime-value state 'Option) option-class)
  (check-equal?
   (raised
    (lambda ()
      (driver-load-port! state
                         (open-input-string "(define changed 1)\n")
                         (open-output-string)
                         #:source-path option-library-path)))
   (list #t (changed-message "lib/option.aloe"))))

(test-case "the diamond shares the installed class"
  (define state (make-driver))
  (define option-class (runtime-value state 'Option))
  (driver-eval! state (load-datum text-library-path))
  (driver-eval! state (load-datum fs-library-path))
  (check-eq? (runtime-value state 'Option) option-class))

(test-case "the section 9 goldens run with a prompt Option"
  (define state (make-driver))
  (driver-eval! state prompt-option)
  (check-equal?
   (type->datum
    (type-of (parse-datum '(Option Some "x")) (driver-type-environment state)))
   '(Option String))
  (check-equal? (driver-eval! state '((Option Some "x") present?)) #t)
  (check-equal?
   (driver-eval! state '((if #t (Option None) (Option Some "x")) present?))
   #f)
  (check-equal?
   (driver-eval!
    state
    '((Option Some "x") case (None () "unknown") (Some (name) name)))
   "x")
  (for ([datum (in-list '((define n (Option None))
                          ((Option Some "x") case (Some (name) name))))])
    (check-equal? (car (raised (lambda () (driver-eval! state datum)))) #t
                  (format "~s" datum)))
  ;; The parser, not the checker, rejects a string selector.
  (check-exn #rx"selector must be a symbol"
             (lambda () (driver-eval! state '(Some "x")))))

(test-case "hover inside lib/option.aloe"
  (define source (file->string option-library-path))
  (define result
    (query-expression-at option-library-path
                         (add1 (position-of source "(self case"))))
  (check-equal? (expression-query-result-type result) '(Option T)))

(test-case "hover inside a dirty lib/option.aloe"
  (call-with-temporary-directory
   (lambda (directory)
     (define sibling (build-path directory "option-buffer"))
     (define added-line "((Option Some \"x\") present?)\n")
     (define buffer
       (bytes-append (file->bytes option-library-path)
                     (string->bytes/utf-8 added-line)))
     (call-with-output-file sibling
       (lambda (output) (write-bytes buffer output)))
     (define text (bytes->string/utf-8 buffer))
     (define position
       (add1 (position-of text "((Option Some \"x\") present?)")))
     (check-true
      (> position (string-length (file->string option-library-path))))
     (define result
       (query-expression-at sibling position
                            #:document-path option-library-path))
     (check-equal? (expression-query-result-type result) '(Option String)))))

(test-case "hover inside lib/list.aloe"
  (define source (file->string list-library-path))
  (define position (add1 (position-of source "(self empty?)")))
  (check-equal?
   (expression-query-result-type
    (query-expression-at list-library-path position))
   '(List T))
  (call-with-temporary-directory
   (lambda (directory)
     (define sibling (build-path directory "list-buffer"))
     (copy-file list-library-path sibling)
     (check-equal?
      (expression-query-result-type
       (query-expression-at sibling position
                            #:document-path list-library-path))
      '(List T))
     (check-exn #rx"ambiguous message: fold"
                (lambda () (query-expression-at sibling position))))))

(test-case "completion inside lib/string.aloe"
  (define original "((self take (prefix len)) = prefix)")
  (define source
    (string-replace (file->string string-library-path)
                    original
                    "((self take (prefix len)) = (prefix starts-with? self))"
                    #:all? #f))
  (check-not-equal? source (file->string string-library-path))
  (define position
    (+ (position-of source "prefix sta") (string-length "prefix sta")))
  (define labels
    (map selector-completion-item-label
         (query-selector-completions source position
                                     #:source-path string-library-path)))
  (check-equal?
   (length (filter (lambda (label) (equal? label "starts-with?")) labels))
   1))
