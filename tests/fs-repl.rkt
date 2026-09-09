#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         "../host/racket/fs.rkt"
         "../host/racket/fs-repl.rkt")

(define-runtime-path fs-library-path "../lib/fs.aloe")
(define-runtime-path worksheet-path "../archive/fs-worksheet.aloe")
(define-runtime-path project-path "..")

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-fs-repl-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(define (eval-worksheet-cells! state)
  (call-with-input-file worksheet-path
    (lambda (input)
      (let loop ()
        (define datum (read input))
        (unless (eof-object? datum)
          (driver-eval! state datum)
          (loop))))))

(test-case "filesystem REPL injects fs-host and evaluates worksheet setup"
  (call-with-temporary-directory
   (lambda (directory)
     (define input
       (open-input-string
        (string-append
         (format "(load ~s)\n" (path->string fs-library-path))
         "(define fs (Fs new fs-host))\n"
         "((fs current) text)\n"
         "((fs inspect (fs current)) present?)\n"
         "(exit)\n")))
     (define output (open-output-string))
     (define errors (open-output-string))

     (parameterize ([current-directory directory])
       (run-fs-repl input output errors))

     (check-regexp-match
      (regexp (regexp-quote (path->string directory)))
      (get-output-string output))
     (check-regexp-match #rx"#t" (get-output-string output))
     (check-equal? (get-output-string errors) ""))))

(test-case "filesystem worksheet evaluates cell by cell from the project root"
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-receiver))
  (parameterize ([current-directory project-path])
    (check-not-exn
     (lambda ()
       (eval-worksheet-cells! state))))
  (check-true (driver-eval! state '(library-inspection present?)))
  (check-true (positive? (driver-eval! state '(cwd-entries len))))
  (check-true (positive? (driver-eval! state '(archive-entries len)))))
