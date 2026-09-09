#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
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
   "/cwd/pipe" "fifo"
   "/linkdir" 'symlink
   "/linkdir/a.txt" 'file
   "/ghost/a.txt" 'file))

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

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

(define (make-root-double-state)
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host (make-fs-double "/cwd" (hash-set nodes "/" 'directory)))
  (load-disk! state)
  (driver-eval! state '(define fs (Disk new fs-host)))
  state)

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-disk-inspect-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(define (inspect-kind-datum location)
  `((,location inspect) case
     (None () "missing")
     (Some (item)
       (item case
         (File (file) "file")
         (Directory (directory) "directory")
         (SymbolicLink (link) "symlink")
         (Other (thing) (thing kind))))))

(define (inspect-location-text-datum location)
  `((,location inspect) case
     (None () "missing")
     (Some (item)
       (item case
         (File (file) ((file location) text))
         (Directory (directory) ((directory location) text))
         (SymbolicLink (link) ((link location) text))
         (Other (thing) ((thing location) text))))))

(define (file-result-datum location body)
  `((,location inspect) case
     (None () "missing")
     (Some (item)
       (item case
         (File (file) ,body)
         (Directory (directory) "not-file")
         (SymbolicLink (link) "not-file")
         (Other (thing) "not-file")))))

(define (live-parent-text-datum location)
  `((,location inspect) case
     (None () "missing")
     (Some (item)
       (item case
         (File (file)
           ((file parent) case
             (None () "none")
             (Some (directory) (directory text))))
         (Directory (directory)
           ((directory parent) case
             (None () "none")
             (Some (parent) (parent text))))
         (SymbolicLink (link)
           ((link parent) case
             (None () "none")
             (Some (directory) (directory text))))
         (Other (thing)
           ((thing parent) case
             (None () "none")
             (Some (directory) (directory text))))))))

(test-case "fresh drivers have no filesystem libraries or optional capabilities"
  (define state (make-driver))
  (for ([name
         (in-list
          '(fs-host term Fs Path Entry Disk Location Item File Directory
                    SymbolicLink Other Option))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))

(test-case "disk library installs typed inspect and live classes"
  (define state (make-driver))
  (load-disk! state)
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (driver-eval! state '(define fs (Disk new fs-host)))

  (for ([name (in-list '(Option Disk Location Item File Directory
                         SymbolicLink Other fs-host fs))])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name)))
  (check-equal?
   (driver-type-datum state '((fs current) inspect))
   '(Option (Item FsHost)))
  (check-equal?
   (driver-type-datum state '((fs current) parent))
   '(Option (Location FsHost)))
  (check-equal?
   (driver-type-datum state '((File new (fs current)) parent))
   '(Option (Directory FsHost)))
  (check-exn
   #rx"unbound symbol: FsHost"
   (lambda ()
     (driver-eval!
      state
      '(define-class HostHolder
         (fields (value FsHost))
         (methods))))))

(test-case "Location inspect classifies live objects and resolves locations"
  (define state (make-double-state))

  (check-false
   (driver-eval! state '(((fs at "/cwd/nope") inspect) present?)))
  (check-equal?
   (driver-eval!
    state
    '(((fs at "/cwd/nope") inspect) case
       (None () "none")
       (Some (item) "some")))
   "none")

  (for ([path+kind+resolved
         (in-list
          '(("a.txt" "file" "/cwd/a.txt")
            ("dir" "directory" "/cwd/dir")
            ("link" "symlink" "/cwd/link")
            ("pipe" "fifo" "/cwd/pipe")
            ("." "directory" "/cwd")))])
    (define location `(fs at ,(car path+kind+resolved)))
    (check-equal?
     (driver-eval! state (inspect-kind-datum location))
     (cadr path+kind+resolved))
    (check-equal?
     (driver-eval! state (inspect-location-text-datum location))
     (caddr path+kind+resolved)))

  (check-equal?
   (driver-eval!
    state
    (file-result-datum
     '(fs at "a.txt")
     '((file location) text)))
   "/cwd/a.txt"))

(test-case "Item case is exhaustive and constructors remain sends"
  (define state (make-double-state))

  (check-equal?
   (driver-eval! state (inspect-kind-datum '(fs current)))
   "directory")
  (check-exn
   #rx"missing constructors: \\(Other\\)"
   (lambda ()
     (driver-eval!
      state
      '(((fs current) inspect) case
         (None () "missing")
         (Some (item)
           (item case
             (File (file) "file")
             (Directory (directory) "directory")
             (SymbolicLink (link) "symlink")))))))
  (check-exn
   #rx"selector must be a symbol"
   (lambda ()
     (driver-eval! state '(File (fs current))))))

(test-case "File forwards path questions and inspect through its Location"
  (define state (make-double-state))
  (define location '(fs at "/cwd/a.txt"))

  (check-equal?
   (driver-eval! state (file-result-datum location '(file name)))
   "a.txt")
  (check-equal?
   (driver-eval! state (file-result-datum location '(file text)))
   "/cwd/a.txt")
  (check-equal?
   (driver-eval!
    state
    (file-result-datum location '((file child "nope") text)))
   "/cwd/a.txt/nope")
  (check-equal?
   (driver-eval!
    state
    (file-result-datum
     location
     '((file inspect) case
        (None () "missing")
        (Some (again)
          (again case
            (File (next) "file")
            (Directory (directory) "directory")
            (SymbolicLink (link) "symlink")
            (Other (thing) "other"))))))
   "file"))

(test-case "live parent returns only inspected directories"
  (define state (make-double-state))
  (define root-state (make-root-double-state))

  (check-equal?
   (driver-eval! root-state (live-parent-text-datum '(fs at "/")))
   "none")
  (check-equal?
   (driver-eval!
    state
    (live-parent-text-datum '(fs at "/cwd/a.txt")))
   "/cwd")
  (check-equal?
   (driver-eval!
    state
    (live-parent-text-datum '(fs at "/linkdir/a.txt")))
   "none")
  (check-equal?
   (driver-eval!
    state
    (live-parent-text-datum '(fs at "/ghost/a.txt")))
   "none")
  (check-false
   (driver-eval! state '(((fs at "/") parent) present?))))

(test-case "entries and manager inspect remain outside this checkpoint"
  (define state (make-double-state))
  (check-exn
   #rx"unknown message: entries"
   (lambda ()
     (driver-eval!
      state
      '(((fs current) inspect) case
         (None () "missing")
         (Some (item)
           (item case
             (File (file) "file")
             (Directory (directory) (directory entries))
             (SymbolicLink (link) "symlink")
             (Other (thing) "other")))))))
  (check-exn
   #rx"unknown message: inspect"
   (lambda ()
     (driver-eval! state '(fs inspect)))))

(test-case "thin Entry and object-oriented Item coexist without mixing"
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

  (check-equal?
   (driver-eval!
    state
    '((thin inspect (thin current)) case
       (None () "missing")
       (Some (entry)
         (entry case
           (RegularFile (path) "thin-file")
           (Directory (path) "thin-directory")
           (SymbolicLink (path) "thin-symlink")
           (Other (path kind) "thin-other")))))
   "thin-directory")
  (check-equal?
   (driver-eval! state (inspect-kind-datum '(fs current)))
   "directory"))

(test-case "production inspect and live parent use isolated filesystem facts"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (path->string directory))
     (define file-path (build-path directory "a.txt"))
     (define child-directory (build-path directory "dir"))
     (define link-path (build-path directory "link"))
     (define missing-path (build-path directory "missing"))

     (display-to-file "live file" file-path #:exists 'truncate)
     (make-directory child-directory)
     (make-file-or-directory-link "dir" link-path)

     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (load-disk! state)
     (driver-eval! state '(define fs (Disk new fs-host)))

     (for ([path+kind
            (in-list
             (list (list file-path "file")
                   (list child-directory "directory")
                   (list link-path "symlink")
                   (list missing-path "missing")))])
       (check-equal?
        (driver-eval!
         state
         (inspect-kind-datum
          `(fs at ,(path->string (car path+kind)))))
        (cadr path+kind)))

     (check-equal?
      (driver-eval!
       state
       (file-result-datum
        `(fs at ,(path->string file-path))
        '((file location) text)))
      (driver-eval!
       state
       `(,(list 'fs 'at (path->string file-path)) text)))
     (check-equal?
      (driver-eval!
       state
       (live-parent-text-datum
        `(fs at ,(path->string file-path))))
      root)
     (check-equal?
      (driver-eval! state (live-parent-text-datum '(fs at "/")))
      "none")
     (check-false
      (driver-eval!
       state
       `((((fs at ,root) child "missing") inspect) present?))))))

(test-case "Term remains independently injectable and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
