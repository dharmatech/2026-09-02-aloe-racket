#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         (only-in "../aloe/env.rkt" env-bound?)
         (only-in "../aloe/type.rkt" type-environment-bound?))

(define-runtime-path host-path "../aloe/host.rkt")
(define-runtime-path driver-path "../aloe/driver.rkt")
(define-runtime-path eval-path "../aloe/eval.rkt")
(define-runtime-path main-path "../aloe/main.rkt")
(define-runtime-path type-path "../aloe/type.rkt")
(define-runtime-path term-path "../host/racket/term.rkt")
(define-runtime-path bin-path "../bin/aloe")

(define (module-submodule-path path name)
  `(submod (file ,(path->string path)) ,name))

(test-case "the intended host declaration surface remains public"
  (for ([name
         (in-list
          '(make-host-method
            host-method?
            host-method-selector
            host-method-parameter-types
            host-method-return-type
            host-method-implementation
            make-host-interface
            host-interface?
            host-interface-name
            host-interface-methods
            make-host-receiver
            host-receiver?
            host-receiver-interface
            host-receiver-name
            host-receiver-send
            exn:fail:aloe-host?
            exn:fail:aloe-host-cause))])
    (check-true
     (procedure? (dynamic-require host-path name))
     (symbol->string name)))
  (check-true
   (procedure? (dynamic-require driver-path 'driver-inject-host!)))
  (check-true
   (procedure? (dynamic-require term-path 'make-term-receiver)))
  (define host-interface?
    (dynamic-require host-path 'host-interface?))
  (check-true
   (host-interface? (dynamic-require term-path 'term-interface))))

(test-case "raw and evaluator-facing operations stay off primary surfaces"
  ;; Instantiate each primary module successfully before checking individual
  ;; missing exports, so a failure means the requested name is unavailable.
  (for ([path (in-list (list host-path type-path eval-path))])
    (check-not-exn (lambda () (dynamic-require path #f))))
  (for ([name
         (in-list
          '(host-method
            host-interface
            host-receiver
            host-receiver-state
            exn:fail:aloe-host
            host-receiver-invoke-method))])
    (check-exn exn:fail?
               (lambda () (dynamic-require host-path name))))
  (for ([name
         (in-list
          '(host-receiver-type
            host-receiver-type?
            host-receiver-type-interface
            type-environment-inject-host!))])
    (check-exn exn:fail?
               (lambda () (dynamic-require type-path name))))
  (check-exn
   exn:fail?
   (lambda ()
     (dynamic-require eval-path 'host-receiver-invoke-method))))

(test-case "the two narrow internal hooks remain connected"
  (check-true
   (procedure?
    (dynamic-require
     (module-submodule-path type-path 'driver-host-injection)
     'type-environment-inject-host!)))
  (check-true
   (procedure?
    (dynamic-require
     (module-submodule-path host-path 'evaluator-exact-host-method)
     'host-receiver-invoke-method))))

(define make-driver* (dynamic-require driver-path 'make-driver))
(define driver-inject-host!*
  (dynamic-require driver-path 'driver-inject-host!))
(define driver-eval!* (dynamic-require driver-path 'driver-eval!))
(define driver-runtime-environment*
  (dynamic-require driver-path 'driver-runtime-environment))
(define driver-type-environment*
  (dynamic-require driver-path 'driver-type-environment))

(test-case "default drivers remain free of optional Term authority"
  (define state (make-driver*))
  (check-false
   (env-bound? (driver-runtime-environment* state) 'term))
  (check-false
   (type-environment-bound? (driver-type-environment* state) 'term)))

(test-case "ordinary entry points have no terminal dependency"
  (define forbidden-dependency
    #rx"host/racket/term\\.rkt|tui/term|term-interface|make-term-receiver")
  (for ([path (in-list (list driver-path main-path bin-path))])
    (check-false
     (regexp-match? forbidden-dependency (file->string path))
     (path->string path))))

(test-case "production host modules contain no legacy Term path"
  (define legacy-path #rx"host-message|HostTerm|make-term-type-environment")
  (for ([path (in-list (list host-path term-path))])
    (check-false
     (regexp-match? legacy-path (file->string path))
     (path->string path))))

(test-case "the sealed public route performs a checked Term send"
  (define make-term-receiver*
    (dynamic-require term-path 'make-term-receiver))
  (define term-interface
    (dynamic-require term-path 'term-interface))
  (define host-receiver-interface*
    (dynamic-require host-path 'host-receiver-interface))
  (define output (open-output-string))
  (define receiver
    (make-term-receiver* output (lambda () "unused")))
  (check-eq? (host-receiver-interface* receiver) term-interface)
  (define state (make-driver*))
  (check-true (void? (driver-inject-host!* state 'term receiver)))
  (check-equal?
   (driver-eval!* state '(term write-line "sealed"))
   "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
