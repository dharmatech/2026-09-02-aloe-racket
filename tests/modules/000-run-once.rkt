#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  [make-top-level-env make-raw-top-level-env]
                  env-bound?
                  env-lookup
                  list-class-object-methods
                  string-class-object-methods
                  int-class-object-methods)
         "../../aloe/main.rkt"
         (only-in "../../aloe/type.rkt"
                  int-type
                  list-type
                  string-type
                  type-environment-bound?
                  type-signature-specs))

(define-runtime-path fixtures-directory "fixtures")
(define-runtime-path box-path "fixtures/box.aloe")
(define-runtime-path box-root-path "fixtures/box-root.aloe")
(define-runtime-path command-path "fixtures/command.aloe")
(define-runtime-path keymap-path "fixtures/keymap.aloe")
(define-runtime-path keymap-user-path "fixtures/keymap-user.aloe")
(define-runtime-path failing-check-path "fixtures/failing-check.aloe")
(define-runtime-path missing-path "fixtures/no-such-file.aloe")
(define-runtime-path keyed-port-path "fixtures/keyed-port.aloe")
(define-runtime-path cycle-path "../fixtures/load-cycle-a.aloe")
(define-runtime-path list-library-path "../../lib/list.aloe")
(define-runtime-path string-library-path "../../lib/string.aloe")
(define-runtime-path int-library-path "../../lib/int.aloe")
(define-runtime-path option-library-path "../../lib/option.aloe")
(define-runtime-path text-library-path "../../lib/text.aloe")
(define-runtime-path fs-library-path "../../lib/fs.aloe")

(define (load-datum path)
  `(load ,(path->string path)))

(define (load-form path)
  (format "(load ~s)" (path->string path)))

(define (resolved-string path)
  (path->string (simplify-path (path->complete-path path) #f)))

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

(define (write-source path text)
  (display-to-file text path #:exists 'truncate/replace))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-run-once-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(test-case "a second load of a class file keeps the class"
  (define state (make-driver))
  (driver-eval! state (load-datum box-path))
  (driver-eval! state '(define b (Box new 3)))
  (define box-class (runtime-value state 'Box))
  (driver-eval! state (load-datum box-path))
  (check-equal? (raised (lambda () (driver-eval! state '(check b (Box new 3)))))
                'no-error)
  (check-eq? (runtime-value state 'Box) box-class))

(test-case "a second load of the option library keeps (Option Int)"
  (define state (make-driver))
  (driver-eval! state (load-datum option-library-path))
  (driver-eval! state '(define o (Option Some 1)))
  (define option-class (runtime-value state 'Option))
  (driver-eval! state (load-datum option-library-path))
  (check-equal?
   (raised (lambda () (driver-eval! state '(check o (Option Some 1)))))
   'no-error)
  (check-eq? (runtime-value state 'Option) option-class))

(test-case "a keymap built from a loaded class survives a later load"
  (define state (make-driver))
  (check-equal?
   (raised
    (lambda ()
      (driver-eval! state (load-datum keymap-path))
      (driver-eval! state (load-datum command-path))
      (driver-eval! state (load-datum keymap-user-path))))
   'no-error)
  (check-equal? (driver-eval! state 'first-label) "save"))

(test-case "a second load of changed bytes is an error that installs nothing"
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "changing.aloe"))
     (define original "(define changing-value 1)\n")
     (define changed
       "(define changing-value 2)\n(define added-value 3)\n")
     (define message (changed-message (resolved-string path)))

     (write-source path original)
     (define state (make-driver))
     (driver-eval! state (load-datum path))
     (write-source path changed)
     (check-equal? (raised (lambda () (driver-eval! state (load-datum path))))
                   (list #t message))
     (check-equal? (driver-eval! state 'changing-value) 1)
     (check-false (env-bound? (driver-runtime-environment state) 'added-value))
     (check-false
      (type-environment-bound? (driver-type-environment state) 'added-value))
     (write-source path original)
     (check-equal? (raised (lambda () (driver-eval! state (load-datum path))))
                   'no-error)
     (check-equal? (driver-eval! state 'changing-value) 1)

     (define file-state (make-driver))
     (check-equal?
      (driver-load-file! file-state path (open-output-string))
      '())
     (write-source path changed)
     (check-equal?
      (raised
       (lambda ()
         (driver-load-file! file-state path (open-output-string))))
      (list #t message))
     (write-source path original)
     (check-equal?
      (driver-load-file! file-state path (open-output-string))
      '()))))

(test-case "a relative and an absolute spelling are one key"
  (define state (make-driver))
  (parameterize ([current-directory fixtures-directory])
    (driver-eval! state '(load "box.aloe")))
  (driver-eval! state '(define b (Box new 3)))
  (define box-class (runtime-value state 'Box))
  (driver-eval!
   state
   (load-datum (build-path fixtures-directory 'up "fixtures" "box.aloe")))
  (check-equal? (raised (lambda () (driver-eval! state '(check b (Box new 3)))))
                'no-error)
  (check-eq? (runtime-value state 'Box) box-class))

(define (checker-row-count state type)
  (length (type-signature-specs type (driver-type-environment state))))

(define (runtime-method-count state name methods)
  (length (methods (runtime-value state name))))

(test-case "the installed libraries are already loaded"
  (for ([library
         (in-list
          (list (list list-library-path "lib/list.aloe" 'List
                      (lambda () (list-type (int-type)))
                      list-class-object-methods)
                (list string-library-path "lib/string.aloe" 'String
                      string-type
                      string-class-object-methods)
                (list int-library-path "lib/int.aloe" 'Int
                      int-type
                      int-class-object-methods)))])
    (define-values (path displayed name make-type methods)
      (apply values library))
    (define (counts state)
      (list (checker-row-count state (make-type))
            (runtime-method-count state name methods)))

    (define state (make-driver))
    (define before (counts state))
    (check-equal? (raised (lambda () (driver-eval! state (load-datum path))))
                  'no-error
                  displayed)
    (check-equal? (counts state) before displayed)

    (check-equal?
     (raised
      (lambda ()
        (driver-load-port! state
                           (open-input-string "(define changed 1)\n")
                           (open-output-string)
                           #:source-path path)))
     (list #t (changed-message displayed))
     displayed)
    (check-false (env-bound? (driver-runtime-environment state) 'changed))
    (check-false
     (type-environment-bound? (driver-type-environment state) 'changed))

    (check-equal?
     (driver-load-port! state
                        (open-input-bytes (file->bytes path))
                        (open-output-string)
                        #:source-path path)
     '()
     displayed)
    (check-equal? (counts state) before displayed)

    (define other-state (make-driver))
    (for ([class-name (in-list '(List String Int))])
      (check-not-eq? (runtime-value other-state class-name)
                     (runtime-value state class-name)))
    (define other-before (counts other-state))
    (check-equal?
     (raised (lambda () (driver-eval! other-state (load-datum path))))
     'no-error
     displayed)
    (check-equal? (counts other-state) other-before displayed))

  (check-equal?
   (raised
    (lambda ()
      (eval-source (load-form list-library-path) (make-top-level-env))))
   'no-error)
  (define checker-environment (make-type-environment))
  (define (list-rows)
    (length
     (type-signature-specs (list-type (int-type)) checker-environment)))
  (define rows-before (list-rows))
  (check-equal?
   (type->datum
    (typecheck-source (load-form list-library-path) checker-environment))
   'Void)
  (check-equal? (list-rows) rows-before)
  (check-equal?
   (raised
    (lambda ()
      (eval-source (load-form list-library-path) (make-raw-top-level-env))))
   'no-error))

(test-case "the option diamond under text and fs builds one Option"
  (define state (make-driver))
  (driver-eval! state (load-datum text-library-path))
  (define option-class (runtime-value state 'Option))
  (driver-eval! state '(define o (Option Some 1)))
  (driver-eval! state (load-datum fs-library-path))
  (check-eq? (runtime-value state 'Option) option-class)
  (check-equal?
   (raised (lambda () (driver-eval! state '(check o (Option Some 1)))))
   'no-error))

(test-case "cycles and missing files keep their errors"
  (define state (make-driver))
  (define cycle-message
    (format "typecheck: load cycle: ~a" (resolved-string cycle-path)))
  (check-equal? (raised (lambda () (driver-eval! state (load-datum cycle-path))))
                (list #t cycle-message))
  (check-equal? (raised (lambda () (driver-eval! state (load-datum cycle-path))))
                (list #t cycle-message))
  (check-equal?
   (raised (lambda () (driver-eval! state (load-datum missing-path))))
   (list #t
         (format "typecheck: load file not found: ~a"
                 (resolved-string missing-path)))))

(test-case "an unkeyed port runs its own definitions again"
  (define text
    (format (string-append
             "(define-class Local\n"
             "  (fields\n"
             "    (n Int))\n"
             "  (methods))\n"
             "\n"
             "(load ~s)\n")
            (path->string box-path)))
  (define state (make-driver))
  (driver-load-port! state (open-input-string text) (open-output-string))
  (define local-class (runtime-value state 'Local))
  (define box-class (runtime-value state 'Box))
  (driver-load-port! state (open-input-string text) (open-output-string))
  (check-not-eq? (runtime-value state 'Local) local-class)
  (check-eq? (runtime-value state 'Box) box-class))

(define tally-text
  (string-append
   "(define-class Tally\n"
   "  (fields\n"
   "    (n Int))\n"
   "  (methods))\n"
   "\n"
   "((Tally new 4) n)\n"))

(test-case "a keyed root runs once"
  (define state (make-driver))
  (define first-output (open-output-string))
  (check-equal?
   (driver-load-port! state (open-input-string tally-text) first-output
                      #:source-path keyed-port-path)
   '(4))
  (check-equal? (get-output-string first-output) "4\n")
  (define tally-class (runtime-value state 'Tally))
  (define second-output (open-output-string))
  (check-equal?
   (driver-load-port! state (open-input-string tally-text) second-output
                      #:source-path keyed-port-path)
   '())
  (check-equal? (get-output-string second-output) "")
  (check-eq? (runtime-value state 'Tally) tally-class)

  (define file-state (make-driver))
  (define file-output (open-output-string))
  (check-equal? (driver-load-file! file-state box-root-path file-output)
                '(3))
  (driver-eval! file-state (load-datum box-path))
  (define box-class (runtime-value file-state 'Box))
  (check-equal? (driver-load-file! file-state box-root-path file-output)
                '())
  (check-equal? (get-output-string file-output) "3\n")
  (driver-eval! file-state (load-datum box-root-path))
  (check-eq? (runtime-value file-state 'Box) box-class)

  (define runtime-environment (make-top-level-env))
  (check-equal?
   (eval-source tally-text runtime-environment
                #:source-path keyed-port-path)
   4)
  (define source-tally (env-lookup runtime-environment 'Tally))
  (check-equal?
   (eval-source tally-text runtime-environment
                #:source-path keyed-port-path)
   (void))
  (check-eq? (env-lookup runtime-environment 'Tally) source-tally)

  (define checker-environment (make-type-environment))
  (check-equal?
   (type->datum
    (typecheck-source tally-text checker-environment
                      #:source-path keyed-port-path))
   'Int)
  (check-equal?
   (type->datum
    (typecheck-source tally-text checker-environment
                      #:source-path keyed-port-path))
   'Void))

(test-case "the checker rejects changed bytes before the evaluator runs"
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "checked.aloe"))
     (write-source path "(define checked-value 1)\n")
     (define state (make-driver))
     (driver-eval! state (load-datum path))
     (write-source path
                   "(define checked-value 2)\n(define evaluated-value 3)\n")
     (check-equal? (raised (lambda () (driver-eval! state (load-datum path))))
                   (list #t (changed-message (resolved-string path))))
     (check-false
      (env-bound? (driver-runtime-environment state) 'evaluated-value))
     (check-equal? (driver-eval! state 'checked-value) 1))))

(test-case "two bases do not share a load"
  (define first-state (make-driver))
  (driver-eval! first-state (load-datum box-path))
  (define second-state (make-driver))
  (driver-eval! second-state (load-datum box-path))
  (check-not-eq? (runtime-value second-state 'Box)
                 (runtime-value first-state 'Box))
  (check-equal? (driver-eval! second-state '((Box new 3) get)) 3))

(test-case "a failed load can be tried again"
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "broken.aloe"))
     (write-source path "(define broken (1 + \"a\"))\n")
     (define state (make-driver))
     (check-equal?
      (car (raised (lambda () (driver-eval! state (load-datum path)))))
      #t)
     (write-source path "(define broken (1 + 2))\n")
     (check-equal? (raised (lambda () (driver-eval! state (load-datum path))))
                   'no-error)
     (check-equal? (driver-eval! state 'broken) 3)))

  (define state (make-driver))
  (define check-message "eval-aloe: check failed: 1 => 1 vs 2 => 2")
  (check-equal?
   (raised (lambda () (driver-eval! state (load-datum failing-check-path))))
   (list #f check-message))
  (check-false (env-bound? (driver-runtime-environment state) 'before-failure))
  (check-equal?
   (raised (lambda () (driver-eval! state (load-datum failing-check-path))))
   (list #f check-message)))
