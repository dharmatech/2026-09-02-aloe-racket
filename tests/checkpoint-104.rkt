#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/host.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

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
    (make-temporary-directory "aloe-fs-entry-~a" #:base-dir "/tmp"))
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

(define (entry-kind-datum entry)
  `(,entry case
     (RegularFile (path) "file")
     (Directory (path) "directory")
     (SymbolicLink (path) "symlink")
     (Other (path kind) kind)))

(define (inspect-kind-datum path)
  `((fs inspect ,path) case
     (None () "missing")
     (Some (entry) ,(entry-kind-datum 'entry))))

(define (inspect-path-datum path)
  `((fs inspect ,path) case
     (None () "missing")
     (Some (entry) ((entry path) text))))

(test-case "fresh drivers have no filesystem library or optional capabilities"
  (define state (make-driver))
  (for ([name (in-list '(fs-host term Fs Path Entry Option))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))

(test-case "fs library adds Entry, inspect, and homogeneous Entry listings"
  (define state (make-double-state))
  (for ([name (in-list '(Option Path Entry Fs fs-host fs))])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name)))
  (for ([name (in-list '(None Some RegularFile Directory SymbolicLink Other
                         term))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))
  (check-equal?
   (driver-type-datum state '(fs inspect (fs current)))
   '(Option Entry))
  (check-equal?
   (driver-type-datum state '(fs entries (fs current)))
   '(List Entry)))

(test-case "inspect maps host kinds and resolves every Entry path"
  (define state (make-double-state))

  (check-false
   (driver-eval!
    state
    '((fs inspect (Path new "nope")) present?)))
  (check-equal?
   (driver-eval!
    state
    '((fs inspect (Path new "nope")) case
       (None () "none")
       (Some (entry) "some")))
   "none")

  (for ([text+kind+path
         (in-list
          '(("a.txt" "file" "/cwd/a.txt")
            ("dir" "directory" "/cwd/dir")
            ("link" "symlink" "/cwd/link")
            ("pipe" "fifo" "/cwd/pipe")
            ("." "directory" "/cwd")))])
    (define path `(Path new ,(first text+kind+path)))
    (check-equal?
     (driver-eval! state (inspect-kind-datum path))
     (second text+kind+path))
    (check-equal?
     (driver-eval! state (inspect-path-datum path))
     (third text+kind+path))))

(test-case "Entry case is exhaustive and constructors are class messages"
  (define state (make-double-state))

  (for ([constructor+expected
         (in-list
          '((RegularFile "file")
            (Directory "directory")
            (SymbolicLink "symlink")
            (Other "fifo")))])
    (define constructor (first constructor+expected))
    (define entry
      (if (eq? constructor 'Other)
          `(Entry Other (fs current) "fifo")
          `(Entry ,constructor (fs current))))
    (check-equal?
     (driver-eval! state (entry-kind-datum entry))
     (second constructor+expected)))

  (check-exn
   #rx"missing constructors: \\(Other\\)"
   (lambda ()
     (driver-eval!
      state
      '((Entry RegularFile (fs current)) case
         (RegularFile (path) "file")
         (Directory (path) "directory")
         (SymbolicLink (path) "symlink")))))
  (check-exn
   #rx"selector must be a symbol"
   (lambda ()
     (driver-eval! state '(RegularFile (fs current)))))
  (check-exn
   #rx"unbound symbol: RegularFile"
   (lambda ()
     (driver-eval! state 'RegularFile)))
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-type-datum state 'RegularFile))))

(test-case "entries preserves names and constructor order"
  (define state (make-double-state))
  (driver-eval! state '(define cwd-entries (fs entries (fs current))))

  (check-equal? (driver-eval! state '(cwd-entries len)) 4)
  (for ([name+kind
         (in-list
          '(("a.txt" "file")
            ("dir" "directory")
            ("link" "symlink")
            ("pipe" "fifo"))) ]
        [index (in-naturals)])
    (define entry (list-item-datum 'cwd-entries index))
    (check-equal?
     (driver-eval! state `(fs name (,entry path)))
     (first name+kind))
    (check-equal?
     (driver-eval! state (entry-kind-datum entry))
     (second name+kind)))

  (check-equal?
   (driver-eval! state '((fs entries (fs path "/cwd/dir")) len))
   0)
  (for ([path (in-list '("/cwd/a.txt" "/cwd/link" "/cwd/nope"))])
    (check-exn
     (host-failure? 'FsHost 'names)
     (lambda ()
       (driver-eval! state `(fs entries (fs path ,path))))))
  (check-false
   (driver-eval! state '((fs parent (fs path "/")) present?))))

(test-case "production inspect and entries classify isolated filesystem data"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (path->string directory))
     (define file-path (build-path directory "a.txt"))
     (define child-directory (build-path directory "dir"))
     (define link-path (build-path directory "link"))
     (define missing-path (build-path directory "missing"))

     (display-to-file "entry" file-path #:exists 'truncate)
     (make-directory child-directory)
     (make-file-or-directory-link "dir" link-path)

     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (load-fs! state)
     (driver-eval! state '(define fs (Fs new fs-host)))

     (for ([path+kind
            (in-list
             (list (list (path->string file-path) "file")
                   (list (path->string child-directory) "directory")
                   (list (path->string link-path) "symlink")
                   (list (path->string missing-path) "missing")))])
       (check-equal?
        (driver-eval!
         state
         (inspect-kind-datum `(fs path ,(first path+kind))))
        (second path+kind)))

     (driver-eval! state `(define root-entries (fs entries (fs path ,root))))
     (check-equal? (driver-eval! state '(root-entries len)) 3)
     (for ([name+kind
            (in-list
             '(("a.txt" "file")
               ("dir" "directory")
               ("link" "symlink")))]
           [index (in-naturals)])
       (define entry (list-item-datum 'root-entries index))
       (check-equal?
        (driver-eval! state `(fs name (,entry path)))
        (first name+kind))
       (check-equal?
        (driver-eval! state (entry-kind-datum entry))
        (second name+kind)))

     (for ([path (in-list (list file-path link-path))])
       (check-exn
        (host-failure? 'FsHost 'names)
        (lambda ()
          (driver-eval!
           state
           `(fs entries (fs path ,(path->string path)))))))
     (check-false
      (driver-eval!
       state
       `((fs inspect (fs path ,(path->string missing-path))) present?))))))

(test-case "Term on another driver remains independently injectable and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
