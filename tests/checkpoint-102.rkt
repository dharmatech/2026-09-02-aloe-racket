#lang racket/base

(require racket/file
         racket/list
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/host.rkt"
         (only-in "../aloe/type.rkt" type-environment-bound?)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

(define (host-failure? interface selector)
  (lambda (exception)
    (and (exn:fail:aloe-host? exception)
         (regexp-match?
          (regexp (regexp-quote (symbol->string interface)))
          (exn-message exception))
         (regexp-match?
          (regexp (regexp-quote (symbol->string selector)))
          (exn-message exception)))))

(define (list-item-datum list-name index)
  (define receiver
    (for/fold ([receiver list-name])
              ([_ (in-range index)])
      (list receiver 'rest)))
  (list receiver 'first))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-fs-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(test-case "production and double receivers share the FsHost identity"
  (define production (make-fs-receiver))
  (define double (make-fs-double "/cwd" (hash)))
  (check-equal? (procedure-arity make-fs-receiver) 0)
  (check-eq? (host-receiver-interface production) fs-interface)
  (check-eq? (host-receiver-interface double) fs-interface)
  (check-eq? (host-receiver-interface production)
             (host-receiver-interface double)))

(test-case "production receiver keeps the locked lexical POSIX path algebra"
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-receiver))

  (for ([datum+expected
         (in-list
          '(((fs-host resolve "/tmp/a/../b") "/tmp/b")
            ((fs-host resolve "/tmp/a/") "/tmp/a")
            ((fs-host resolve "/tmp//a") "/tmp/a")
            ((fs-host resolve "/") "/")
            ((fs-host child "/tmp" "a") "/tmp/a")
            ((fs-host child "/tmp/" "a") "/tmp/a")
            ((fs-host child "/tmp/a" "..") "/tmp")
            ((fs-host child "/" "..") "/")
            ((fs-host child "/" "a") "/a")
            ((fs-host root? "/") #t)
            ((fs-host root? "/tmp") #f)
            ((fs-host root? "/tmp/..") #t)
            ((fs-host parent "/tmp/a") "/tmp")
            ((fs-host parent "/tmp") "/")
            ((fs-host parent "/") "/")
            ((fs-host name "/tmp/a") "a")
            ((fs-host name "/tmp") "tmp")
            ((fs-host name "/") "")))])
    (check-equal?
     (driver-eval! state (first datum+expected))
     (second datum+expected)))

  (for ([component (in-list '("" "a/b"))])
    (check-exn
     (host-failure? 'FsHost 'child)
     (lambda ()
       (driver-eval! state `(fs-host child "/tmp" ,component))))))

(test-case "production receiver classifies and lists an isolated directory"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (path->string directory))
     (define file-path (build-path directory "a.txt"))
     (define unicode-path (build-path directory "café"))
     (define child-directory (build-path directory "dir"))
     (define link-path (build-path directory "link"))
     (define missing-path (build-path directory "missing"))

     (display-to-file "hi" file-path #:exists 'truncate)
     (display-to-file "bonjour" unicode-path #:exists 'truncate)
     (make-directory child-directory)
     (make-file-or-directory-link "dir" link-path)

     ;; Construct before changing current-directory so current is observed at
     ;; send time rather than captured by make-fs-receiver.
     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))

     (for ([path+kind
            (in-list
             (list (list root "directory")
                   (list (path->string file-path) "file")
                   (list (path->string unicode-path) "file")
                   (list (path->string child-directory) "directory")
                   (list (path->string link-path) "symlink")
                   (list (path->string missing-path) "missing")))])
       (check-equal?
        (driver-eval! state `(fs-host kind ,(first path+kind)))
        (second path+kind)))

     (check-equal?
      (driver-eval!
       state
       `((fs-host names ,(path->string child-directory)) len))
      0)

     (for ([path (in-list (list file-path link-path missing-path))])
       (check-exn
        (host-failure? 'FsHost 'names)
        (lambda ()
          (driver-eval! state `(fs-host names ,(path->string path))))))

     (driver-eval! state `(define root-names (fs-host names ,root)))
     (define expected-children
       '(("a.txt" "file")
          ("café" "file")
          ("dir" "directory")
          ("link" "symlink")))
     (check-equal? (driver-eval! state '(root-names len))
                   (length expected-children))
     (for ([name+kind (in-list expected-children)]
           [index (in-naturals)])
       (define name
         (driver-eval! state (list-item-datum 'root-names index)))
       (check-equal? name (first name+kind))
       (define child
         (driver-eval! state `(fs-host child ,root ,name)))
       (check-equal? (driver-eval! state `(fs-host kind ,child))
                     (second name+kind)))

     (parameterize ([current-directory directory])
       (define current (driver-eval! state '(fs-host current)))
       (check-equal? current root)
       (check-equal? (driver-eval! state '(fs-host resolve "a.txt"))
                     (driver-eval! state `(fs-host child ,current "a.txt")))
       (check-equal? (driver-eval! state '(fs-host kind "a.txt")) "file")
       (check-equal? (driver-eval! state '((fs-host names ".") len))
                     (length expected-children))
       (check-equal? (driver-eval! state '(fs-host child "dir" "..")) root)
       (check-equal? (driver-eval! state '(fs-host parent "dir")) root)
       (check-equal? (driver-eval! state '(fs-host name "dir")) "dir")
       (check-false (driver-eval! state '(fs-host root? ".")))))))

(test-case "filesystem and terminal remain absent by default and independent"
  (define fresh-state (make-driver))
  (for ([name (in-list '(fs-host term))])
    (check-false (env-bound? (driver-runtime-environment fresh-state) name))
    (check-false
     (type-environment-bound? (driver-type-environment fresh-state) name)))

  (define output (open-output-string))
  (define term-state (make-driver))
  (driver-inject-host!
   term-state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! term-state '(term write-line "sealed"))
                "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
