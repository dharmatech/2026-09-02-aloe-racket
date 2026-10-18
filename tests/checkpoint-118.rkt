#lang racket/base

;; Racket CS compiles a module body whole only while it is smaller than
;; PLT_CS_COMPILE_LIMIT terms. A larger body takes the interpretable path and
;; loses inlining between its own procedures. This test compiles the evaluator
;; modules in a temporary copy of aloe/ at a limit 20 percent under Racket's
;; default and fails when one takes that path. The variables it sets are
;; Racket CS debugging aids, observed on Racket 9.3 CS.

(require compiler/find-exe
         racket/file
         racket/path
         racket/runtime-path
         racket/system
         rackunit)

(define-runtime-path aloe-dir "../aloe")

(define guarded-modules '("eval" "eval-load" "eval-mirror" "eval-value"))
(define guard-limit 8000)
(define detector-limit 100)

(define (module-file name)
  (string-append "aloe/" name ".rkt"))

;; Every file under aloe/ outside a compiled/ directory, as paths relative to
;; aloe/.
(define (aloe-source-files)
  (parameterize ([current-directory aloe-dir])
    (for/list ([path (in-directory
                      #f
                      (lambda (directory)
                        (not (equal? (file-name-from-path directory)
                                     (string->path "compiled")))))]
               #:when (file-exists? path))
      path)))

(define (copy-aloe-sources! destination)
  (for ([path (in-list (aloe-source-files))])
    (define target (build-path destination "aloe" path))
    (make-parent-directory* target)
    (copy-file (build-path aloe-dir path) target)))

(define (call-with-aloe-copy procedure)
  (define directory (make-temporary-directory "checkpoint-118-~a"))
  (dynamic-wind
   void
   (lambda ()
     (copy-aloe-sources! directory)
     (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

;; Runs raco make on the files in directory at limit, with the post-interp
;; report on. Returns whether it exited successfully and its standard output
;; and standard error together.
(define (raco-make directory files limit)
  (define environment
    (environment-variables-copy (current-environment-variables)))
  (environment-variables-set! environment
                              #"PLT_CS_COMPILE_LIMIT"
                              (string->bytes/utf-8 (number->string limit)))
  (environment-variables-set! environment
                              #"PLT_LINKLET_SHOW_POST_INTERP"
                              #"1")
  (define output (open-output-string))
  (define ok?
    (parameterize ([current-directory directory]
                   [current-environment-variables environment]
                   [current-output-port output]
                   [current-error-port output])
      (apply system* (find-exe) "-l-" "raco" "make" files)))
  (values ok? (get-output-string output)))

(define (output-start output)
  (substring output 0 (min 2000 (string-length output))))

;; Maps (list module phase name) to the steps Racket reported for that
;; linklet. Each step belongs to the latest module, phase, and name seen.
(define (linklet-steps output)
  (define steps (make-hash))
  (for/fold ([module #f] [phase #f] [name #f] #:result steps)
            ([line (in-lines (open-input-string output))])
    (define fields
      (regexp-match #rx"^;; compile-linklet: ([a-z]+): (.*)$" line))
    (define key (and fields (cadr fields)))
    (define value (and fields (caddr fields)))
    (cond
      [(equal? key "module") (values value phase name)]
      [(equal? key "phase") (values module value name)]
      [(equal? key "name") (values module phase value)]
      [(equal? key "step")
       (hash-update! steps (list module phase name)
                     (lambda (seen) (cons value seen))
                     '())
       (values module phase name)]
      [else (values module phase name)])))

;; A guarded module's body is its phase-0 linklet named module. Submodules
;; print as (eval method-records) and are not bodies.
(define (body-steps steps module)
  (hash-ref steps (list module "0" "module") '()))

(test-case "the guarded list names every evaluator module"
  (define evaluator-files
    (for/list ([path (in-list (directory-list aloe-dir))]
               #:when (regexp-match? #rx"^eval.*[.]rkt$" (path->string path))
               #:when (file-exists? (build-path aloe-dir path)))
      (path->string path)))
  (check-equal?
   (sort evaluator-files string<?)
   (sort (for/list ([name (in-list guarded-modules)])
           (string-append name ".rkt"))
         string<?)
   "a new evaluator module is named aloe/eval-<part>.rkt and joins the list"))

(test-case "each evaluator module compiles whole at the guard's limit"
  (check-eq? (system-type 'vm) 'chez-scheme
             "the compile-limit guard needs Racket CS")
  (call-with-aloe-copy
   (lambda (directory)
     (define-values (ok? output)
       (raco-make directory (map module-file guarded-modules) guard-limit))
     (check-true ok?
                 (format "raco make failed at ~a:\n~a"
                         guard-limit
                         (output-start output)))
     (define steps (linklet-steps output))
     (for ([module (in-list guarded-modules)])
       (define seen (body-steps steps module))
       (check-not-false (member "compiled" seen)
                        (format "~a not compiled at ~a" module guard-limit))
       (check-false (member "post-interp" seen)
                    (format "~a interpretable at ~a" module guard-limit)))

     ;; The detector: with its dependencies already compiled, eval.rkt alone
     ;; recompiles, and at this limit its body must report post-interp. A change
     ;; in Racket's output shape fails here instead of passing above.
     (delete-file (build-path directory "aloe" "compiled" "eval_rkt.zo"))
     (delete-file (build-path directory "aloe" "compiled" "eval_rkt.dep"))
     (define-values (detector-ok? detector-output)
       (raco-make directory (list (module-file "eval")) detector-limit))
     (check-true detector-ok?
                 (format "raco make failed at ~a:\n~a"
                         detector-limit
                         (output-start detector-output)))
     (check-not-false
      (member "post-interp"
              (body-steps (linklet-steps detector-output) "eval"))
      (format "eval not reported interpretable at ~a; the detector is broken"
              detector-limit)))))
