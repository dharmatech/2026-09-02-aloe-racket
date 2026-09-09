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

(define (load-fs! state)
  (driver-eval!
   state
   `(load ,(path->string fs-library-path))))

(define (make-double-state)
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (load-fs! state)
  (driver-eval! state '(define fs (Fs new fs-host)))
  state)

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-fs-path-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(test-case "fresh drivers have no filesystem library or optional capabilities"
  (define state (make-driver))
  (for ([name (in-list '(fs-host term Fs Path Option Entry))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))
  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3))

(test-case "fs library loads sibling Option and retains the injected host type"
  (define state (make-driver))
  (check-true (void? (load-fs! state)))

  (for ([name (in-list '(Option Path Fs))])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name)))
  (for ([name (in-list '(Some None Entry fs-host term))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))

  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (check-true
   (void? (driver-eval! state '(define fs (Fs new fs-host)))))
  (check-equal? (driver-type-datum state 'fs) '(Fs FsHost))
  (check-equal? (driver-type-datum state '(fs current)) 'Path)
  (check-equal?
   (driver-type-datum state '(fs parent (fs path "/")))
   '(Option Path))
  (check-exn
   #rx"unbound symbol: FsHost"
   (lambda ()
     (driver-eval!
      state
      '(define-class HostHolder
         (fields (value FsHost))
         (methods))))))

(test-case "Fs wraps the double's path algebra in Path and Option"
  (define state (make-double-state))

  (for ([datum+expected
         (in-list
          '((((fs current) text) "/cwd")
            (((fs path "/tmp/a/../b") text) "/tmp/b")
            (((fs path "x") text) "/cwd/x")
            (((fs child (fs path "/tmp") "a") text) "/tmp/a")
            ((fs name (fs path "/tmp/a")) "a")
            ((fs name (fs path "/")) "")
            (((fs parent (fs path "/tmp/a")) present?) #t)
            (((fs parent (fs path "/")) present?) #f)))])
    (check-equal?
     (driver-eval! state (car datum+expected))
     (cadr datum+expected)))

  (check-equal?
   (driver-eval!
    state
    '((fs parent (fs path "/tmp/a")) case
       (None () "none")
       (Some (value) (value text))))
   "/tmp")
  (check-equal?
   (driver-eval!
    state
    '((fs parent (fs path "/")) case
       (None () "root")
       (Some (value) (value text))))
   "root")

  (check-exn
   (host-failure? 'FsHost 'child)
   (lambda ()
     (driver-eval! state '(fs child (fs current) "a/b")))))

(test-case "checkpoint 103 exposes no entry operations or Path effects"
  (define state (make-double-state))
  (check-false (env-bound? (driver-runtime-environment state) 'Entry))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'Entry))
  (for ([datum+message
         (in-list
          '(((fs inspect (fs current)) "unknown message: inspect")
            ((fs entries (fs current)) "unknown message: entries")
            (((fs current) current) "unknown message: current")))])
    (check-exn
     (regexp (cadr datum+message))
     (lambda ()
       (driver-eval! state (car datum+message))))))

(test-case "production Fs path algebra observes an isolated current directory"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (path->string directory))
     (display-to-file "path algebra" (build-path directory "a.txt"))

     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (load-fs! state)
     (driver-eval! state '(define fs (Fs new fs-host)))

     (parameterize ([current-directory directory])
       (check-equal? (driver-eval! state '((fs current) text)) root)
       (check-equal?
        (driver-eval! state '((fs path "a.txt") text))
        (driver-eval!
         state
         '((fs child (fs current) "a.txt") text)))
       (check-false
        (driver-eval!
         state
         '((fs parent (fs path "/")) present?)))))))

(test-case "Term remains independently injectable and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
