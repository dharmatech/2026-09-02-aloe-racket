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
  (hash
   "/cwd" 'directory
   "/cwd/a.txt" 'file
   "/cwd/dir" 'directory
   "/cwd/link" 'symlink
   "/cwd/pipe" "fifo"))

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
    (make-temporary-directory "aloe-directory-entries-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(define (list-item-datum list-name index)
  (define receiver
    (for/fold ([receiver list-name])
              ([_ (in-range index)])
      (list receiver 'rest)))
  (list receiver 'first))

(define (item-name-datum item)
  `(,item case
     (File (file) (file name))
     (Directory (directory) (directory name))
     (SymbolicLink (link) (link name))
     (Other (thing) (thing name))))

(define (item-kind-datum item)
  `(,item case
     (File (file) "file")
     (Directory (directory) "directory")
     (SymbolicLink (link) "symlink")
     (Other (thing) (thing kind))))

(define (entry-kind-datum entry)
  `(,entry case
     (RegularFile (path) "file")
     (Directory (path) "directory")
     (SymbolicLink (path) "symlink")
     (Other (path kind) kind)))

(define (define-live-directory! state name location)
  (driver-eval!
   state
   `(define ,name
      ((,location inspect) case
        (None () (Directory new ,location))
        (Some (item)
          (item case
            (File (file) (Directory new (file location)))
            (Directory (directory) directory)
            (SymbolicLink (link) (Directory new (link location)))
            (Other (thing) (Directory new (thing location)))))))))

(test-case "fresh drivers have no filesystem library or optional capabilities"
  (define state (make-driver))
  (for ([name
         (in-list
          '(fs-host term Disk Location Item Directory Option))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))

(test-case "live Directory entries retains the injected host type"
  (define state (make-double-state))
  (define-live-directory! state 'cwd-directory '(fs current))

  (check-equal?
   (driver-type-datum state '(cwd-directory entries))
   '(List (Item FsHost))))

(test-case "Directory entries preserves names and mixed Item constructors"
  (define state (make-double-state))
  (define-live-directory! state 'cwd-directory '(fs current))
  (driver-eval! state '(define cwd-items (cwd-directory entries)))

  (check-equal? (driver-eval! state '(cwd-items len)) 4)
  (for ([name+kind
         (in-list
          '(("a.txt" "file")
            ("dir" "directory")
            ("link" "symlink")
            ("pipe" "fifo")))]
        [index (in-naturals)])
    (define item (list-item-datum 'cwd-items index))
    (check-equal?
     (driver-eval! state (item-name-datum item))
     (car name+kind))
    (check-equal?
     (driver-eval! state (item-kind-datum item))
     (cadr name+kind)))

  (define-live-directory! state 'empty-directory '(fs at "/cwd/dir"))
  (check-equal? (driver-eval! state '((empty-directory entries) len)) 0))

(test-case "entries exists only on live Directory"
  (define state (make-double-state))

  (for ([location (in-list '((fs current) (fs at "/cwd/dir")))])
    (check-exn
     #rx"unknown message: entries"
     (lambda ()
       (driver-eval! state `(,location entries)))))
  (check-exn
   #rx"unknown message: entries"
   (lambda ()
     (driver-eval!
      state
      '(((fs at "/cwd/a.txt") inspect) case
         (None () "missing")
         (Some (item)
           (item case
             (File (file) (file entries))
             (Directory (directory) "directory")
             (SymbolicLink (link) "symlink")
             (Other (thing) "other")))))))
  (check-exn
   (host-failure? 'FsHost 'names)
   (lambda ()
     (driver-eval!
      state
      '((Directory new (fs at "/cwd/a.txt")) entries)))))

(test-case "missing Location inspect remains None"
  (define state (make-double-state))
  (check-false
   (driver-eval! state '(((fs at "/cwd/missing") inspect) present?))))

(test-case "thin Entry listings and live Item listings coexist"
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (load-fs! state)
  (load-disk! state)
  (driver-eval! state '(define thin (Fs new fs-host)))
  (driver-eval! state '(define fs (Disk new fs-host)))
  (define-live-directory! state 'cwd-directory '(fs current))
  (driver-eval! state '(define thin-items (thin entries (thin current))))
  (driver-eval! state '(define live-items (cwd-directory entries)))

  (for ([name (in-list '(Entry Item))])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name)))
  (check-equal? (driver-type-datum state 'thin-items) '(List Entry))
  (check-equal?
   (driver-type-datum state 'live-items)
   '(List (Item FsHost)))
  (check-equal? (driver-eval! state '(thin-items len)) 4)
  (check-equal? (driver-eval! state '(live-items len)) 4)
  (check-equal?
   (driver-eval!
    state
    (entry-kind-datum (list-item-datum 'thin-items 0)))
   "file")
  (check-equal?
   (driver-eval!
    state
    (item-kind-datum (list-item-datum 'live-items 0)))
   "file"))

(test-case "production Directory entries returns classified live children"
  (call-with-temporary-directory
   (lambda (directory)
     (define file-path (build-path directory "a.txt"))
     (define child-directory (build-path directory "dir"))
     (define link-path (build-path directory "link"))

     (display-to-file "listed file" file-path #:exists 'truncate)
     (make-directory child-directory)
     (make-file-or-directory-link "dir" link-path)

     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (load-disk! state)
     (driver-eval! state '(define fs (Disk new fs-host)))
     (define-live-directory!
      state 'root-directory `(fs at ,(path->string directory)))
     (driver-eval! state '(define root-items (root-directory entries)))

     (check-equal? (driver-eval! state '(root-items len)) 3)
     (for ([name+kind
            (in-list
             '(("a.txt" "file")
               ("dir" "directory")
               ("link" "symlink")))]
           [index (in-naturals)])
       (define item (list-item-datum 'root-items index))
       (check-equal?
        (driver-eval! state (item-name-datum item))
        (car name+kind))
       (check-equal?
        (driver-eval! state (item-kind-datum item))
        (cadr name+kind))))))

(test-case "Term remains independently injectable and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
