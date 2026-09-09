#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/host.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

(define-runtime-path disk-library-path "../lib/disk.aloe")
(define-runtime-path fs-library-path "../lib/fs.aloe")

(define nodes
  (hash "/cwd" 'directory))

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (host-failure? interface selector)
  (lambda (exception)
    (and (exn:fail:aloe-host? exception)
         (regexp-match?
          (regexp (regexp-quote (symbol->string interface)))
          (exn-message exception))
         (regexp-match?
          (regexp (regexp-quote (symbol->string selector)))
          (exn-message exception)))))

(define (load-disk! state)
  (driver-eval!
   state
   `(load ,(path->string disk-library-path))))

(define (load-fs! state)
  (driver-eval!
   state
   `(load ,(path->string fs-library-path))))

(define (make-double-state)
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (load-disk! state)
  (driver-eval! state '(define fs (Disk new fs-host)))
  state)

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-disk-location-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(test-case "fresh drivers have no filesystem libraries or optional capabilities"
  (define state (make-driver))
  (for ([name (in-list '(fs-host term Fs Path Entry Disk Location Item Option))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))
  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3))

(test-case "disk library loads sibling Option and retains the injected host type"
  (define state (make-driver))
  (check-true (void? (load-disk! state)))

  (for ([name (in-list '(Option Location Disk Item File Directory
                         SymbolicLink Other))])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name)))
  (for ([name (in-list '(Some None Path Fs Entry fs-host term))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))

  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (check-true
   (void? (driver-eval! state '(define fs (Disk new fs-host)))))
  (check-equal? (driver-type-datum state 'fs) '(Disk FsHost))
  (check-equal?
   (driver-type-datum state '(fs current))
   '(Location FsHost))
  (check-equal?
   (driver-type-datum state '(fs at "x"))
   '(Location FsHost))
  (check-equal?
   (driver-type-datum state '((fs current) parent))
   '(Option (Location FsHost)))
  (check-equal? (driver-type-datum state '((fs current) name)) 'String)
  (check-equal? (driver-type-datum state '((fs current) text)) 'String)
  (check-equal?
   (driver-type-datum state '((fs current) child "lib"))
   '(Location FsHost))
  (check-exn
   #rx"unbound symbol: FsHost"
   (lambda ()
     (driver-eval!
      state
      '(define-class HostHolder
         (fields (value FsHost))
         (methods))))))

(test-case "Location wraps the double's path algebra in Location and Option"
  (define state (make-double-state))

  (for ([datum+expected
         (in-list
          '((((fs current) text) "/cwd")
            (((fs at "/tmp/a/../b") text) "/tmp/b")
            (((fs at "x") text) "/cwd/x")
            (((fs at "nope") text) "/cwd/nope")
            ((((fs at "/tmp") child "a") text) "/tmp/a")
            (((fs at "/tmp/a") name) "a")
            (((fs at "/cwd/a.txt") name) "a.txt")
            (((fs at "/") name) "")
            ((((fs at "/tmp/a") parent) present?) #t)
            ((((fs at "/") parent) present?) #f)))])
    (check-equal?
     (driver-eval! state (car datum+expected))
     (cadr datum+expected)))

  (check-equal?
   (driver-eval!
    state
    '(((fs at "/tmp/a") parent) case
       (None () "none")
       (Some (location) (location text))))
   "/tmp")
  (check-equal?
   (driver-eval!
    state
    '(((fs at "/") parent) case
       (None () "root")
       (Some (location) (location text))))
   "root")

  (check-exn
   (host-failure? 'FsHost 'child)
   (lambda ()
     (driver-eval! state '((fs current) child "a/b")))))

(test-case "Disk and Location expose only the checkpoint path vocabulary"
  (define state (make-double-state))
  (for ([selector (in-list '(entries current at))])
    (check-exn
     (regexp (format "unknown message: ~a" selector))
     (lambda ()
       (driver-eval! state `((fs current) ,selector)))))
  (for ([selector (in-list '(path name))])
    (check-exn
     (regexp (format "unknown message: ~a" selector))
     (lambda ()
       (driver-eval! state `(fs ,selector))))))

(test-case "thin and object-oriented filesystem libraries coexist"
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (load-fs! state)
  (load-disk! state)

  (for ([name (in-list '(Option Path Entry Fs Location Disk Item fs-host))])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name)))

  (driver-eval! state '(define thin (Fs new fs-host)))
  (driver-eval! state '(define fs (Disk new fs-host)))
  (check-equal? (driver-eval! state '((thin current) text)) "/cwd")
  (check-equal? (driver-eval! state '((fs current) text)) "/cwd"))

(test-case "production Disk path algebra observes an isolated current directory"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (path->string directory))
     (display-to-file "path algebra" (build-path directory "a.txt"))

     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (load-disk! state)
     (driver-eval! state '(define fs (Disk new fs-host)))

     (parameterize ([current-directory directory])
       (check-equal? (driver-eval! state '((fs current) text)) root)
       (check-equal?
        (driver-eval! state '((fs at "a.txt") text))
        (driver-eval!
         state
         '(((fs current) child "a.txt") text)))
       (check-false
        (driver-eval!
         state
         '(((fs at "/") parent) present?)))))))

(test-case "Term remains independently injectable and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
