#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path fs-library-path "../../lib/fs.aloe")

(define fixture-nodes
  (hash
   "/cwd" 'directory
   "/cwd/a.txt" 'file
   "/cwd/empty.txt" 'file
   "/cwd/dir" 'directory
   "/cwd/dir/nested.txt" 'file
   "/cwd/link" 'symlink
   "/cwd/pipe" "fifo"))

(define fixture-contents
  (hash
   "/cwd/a.txt" "λ\r\nlast\n"
   "/cwd/dir/nested.txt" "nested"))

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

(define (make-double-state [nodes fixture-nodes]
                           [contents fixture-contents])
  (define state (make-driver))
  (driver-inject-host!
   state
   'fs-host
   (make-fs-double "/cwd" nodes contents))
  state)

(define (make-thin-state [nodes fixture-nodes]
                         [contents fixture-contents])
  (define state (make-double-state nodes contents))
  (load-fs! state)
  (driver-eval! state '(define fs (Fs new fs-host)))
  state)

(define (list-item-datum list-name index)
  (define receiver
    (for/fold ([receiver list-name])
              ([_ (in-range index)])
      (list receiver 'rest)))
  (list receiver 'first))

(define (inspect-kind-datum path)
  `((fs inspect ,path) case
     (None () "missing")
     (Some (entry)
       (entry case
         (RegularFile (file) "file")
         (Directory (directory) "directory")
         (SymbolicLink (link) "symlink")
         (Other (other kind) kind)))))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-fs-contents-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(define (write-exact-bytes path bytes)
  (call-with-output-file
   path
   (lambda (output) (write-bytes bytes output))
   #:exists 'truncate
   #:mode 'binary))

(test-case "FsHost appends exact read and write rows without adding a capability"
  (define methods (host-interface-methods fs-interface))
  (check-equal?
   (for/list ([method (in-list methods)])
     (list (host-method-selector method)
           (host-method-parameter-types method)
           (host-method-return-type method)))
   '((current () String)
     (resolve (String) String)
     (child (String String) String)
     (root? (String) Bool)
     (parent (String) String)
     (name (String) String)
     (kind (String) String)
     (names (String) (List String))
     (read (String) String)
     (write (String String) String)))
  (for ([method (in-list methods)])
    (check-equal?
     (procedure-arity (host-method-implementation method))
     (add1 (length (host-method-parameter-types method)))))

  (define production (make-fs-receiver))
  (define double (make-fs-double "/cwd" fixture-nodes fixture-contents))
  (check-eq? (host-receiver-interface production) fs-interface)
  (check-eq? (host-receiver-interface double) fs-interface)

  (check-true (procedure-arity-includes? make-fs-double 2))
  (check-true (procedure-arity-includes? make-fs-double 3))
  (check-false (procedure-arity-includes? make-fs-double 1))
  (check-false (procedure-arity-includes? make-fs-double 4))
  (check-not-exn (lambda () (make-fs-double "/cwd" fixture-nodes)))
  (check-not-exn
   (lambda () (make-fs-double "/cwd" fixture-nodes fixture-contents)))
  (check-exn exn:fail:contract:arity?
             (lambda () (make-fs-double "/cwd")))
  (check-exn exn:fail:contract:arity?
             (lambda ()
               (make-fs-double "/cwd" fixture-nodes fixture-contents 'extra)))

  (define state (make-driver))
  (check-false (env-bound? (driver-runtime-environment state) 'fs-host))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'fs-host))
  (load-fs! state)
  (check-false (env-bound? (driver-runtime-environment state) 'fs-host))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'fs-host))
  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3))

(test-case "filesystem double validates and privately copies content fixtures"
  (for ([bad-contents
         (in-list
          (list
           'not-a-hash
           (hash 1 "bad key")
           (hash "/cwd/a.txt" 1)
           (hash "/cwd/missing" "missing")
           (hash "/cwd" "directory")
           (hash "/cwd/link" "link")
           (hash "/cwd/pipe" "other")))])
    (check-exn exn:fail:contract?
               (lambda ()
                 (make-fs-double "/cwd" fixture-nodes bad-contents))))

  (define caller-nodes (make-hash (hash->list fixture-nodes)))
  (define caller-contents (make-hash (hash->list fixture-contents)))
  (define receiver
    (make-fs-double "/cwd" caller-nodes caller-contents))
  (hash-set! caller-nodes "/cwd/a.txt" 'directory)
  (hash-set! caller-nodes "/cwd/later.txt" 'file)
  (hash-set! caller-contents "/cwd/a.txt" "caller mutation")

  (define state (make-driver))
  (driver-inject-host! state 'fs-host receiver)
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/a.txt")) "file")
  (check-equal? (driver-eval! state '(fs-host read "/cwd/a.txt"))
                "λ\r\nlast\n")
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/later.txt"))
                "missing")

  (check-equal?
   (driver-eval! state '(fs-host write "/cwd/a.txt" "receiver write"))
   "receiver write")
  (check-equal?
   (driver-eval! state '(fs-host write "/cwd/created.txt" "雪\n\r\nend"))
   "雪\n\r\nend")
  (check-equal? (hash-ref caller-nodes "/cwd/a.txt") 'directory)
  (check-false (hash-has-key? caller-nodes "/cwd/created.txt"))
  (check-equal? (hash-ref caller-contents "/cwd/a.txt") "caller mutation")
  (check-false (hash-has-key? caller-contents "/cwd/created.txt")))

(test-case "raw double reads, overwrites, creates, and rejects non-files"
  (define state (make-double-state))
  (check-equal? (driver-eval! state '(fs-host read "/cwd/a.txt"))
                "λ\r\nlast\n")
  (check-equal? (driver-eval! state '(fs-host read "/cwd/empty.txt")) "")
  (check-equal?
   (driver-eval! state '(fs-host write "a.txt" "overwrite\r\nλ"))
   "overwrite\r\nλ")
  (check-equal? (driver-eval! state '(fs-host read "/cwd/a.txt"))
                "overwrite\r\nλ")

  (check-equal?
   (driver-eval! state '(fs-host write "new.txt" "new\n雪"))
   "new\n雪")
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/new.txt")) "file")
  (check-equal? (driver-eval! state '(fs-host read "/cwd/new.txt"))
                "new\n雪")
  (driver-eval! state '(define current-names (fs-host names "/cwd")))
  (check-equal? (driver-eval! state '(current-names len)) 6)
  (for ([expected (in-list '("a.txt" "dir" "empty.txt" "link" "new.txt" "pipe"))]
        [index (in-naturals)])
    (check-equal?
     (driver-eval! state (list-item-datum 'current-names index))
     expected))

  (for ([path (in-list '("/cwd/missing"
                         "/cwd"
                         "/cwd/link"
                         "/cwd/pipe"))])
    (check-exn
     (host-failure? 'FsHost 'read)
     (lambda () (driver-eval! state `(fs-host read ,path)))))
  (for ([path (in-list '("/cwd"
                         "/cwd/link"
                         "/cwd/pipe"
                         "/missing/child"
                         "/cwd/a.txt/child"
                         "/cwd/link/child"
                         "/cwd/pipe/child"))])
    (check-exn
     (host-failure? 'FsHost 'write)
     (lambda () (driver-eval! state `(fs-host write ,path "refused"))))))

(test-case "thin Fs exposes Option String and classifies before I/O"
  (define state (make-thin-state))
  (check-equal?
   (driver-type-datum state '(fs read (fs path "a.txt")))
   '(Option String))
  (check-equal?
   (driver-type-datum state '(fs write (fs path "a.txt") "text"))
   '(Option String))

  (check-equal?
   (driver-eval!
    state
    '((fs read (fs path "a.txt")) case
       (None () "none")
       (Some (text) text)))
   "λ\r\nlast\n")
  (check-equal?
   (driver-eval!
    state
    '((fs read (fs path "empty.txt")) case
       (None () "none")
       (Some (text) text)))
   "")
  (for ([path (in-list '("missing" "dir" "link" "pipe"))])
    (check-false
     (driver-eval! state `((fs read (fs path ,path)) present?))))

  (check-equal?
   (driver-eval!
    state
    '((fs write (fs path "a.txt") "thin overwrite") case
       (None () "none")
       (Some (text) text)))
   "thin overwrite")
  (check-equal?
   (driver-eval!
    state
    '((fs write (fs path "created.txt") "λ\r\ncreated") case
       (None () "none")
       (Some (text) text)))
   "λ\r\ncreated")
  (check-equal?
   (driver-eval!
    state
    '((fs read (fs path "created.txt")) case
       (None () "none")
       (Some (text) text)))
   "λ\r\ncreated")
  (check-equal?
   (driver-eval! state (inspect-kind-datum '(fs path "created.txt")))
   "file")
  (driver-eval! state '(define current-entries (fs entries (fs current))))
  (check-equal? (driver-eval! state '(current-entries len)) 6)

  (define names-before
    (driver-eval! state '((fs-host names "/cwd") len)))
  (for ([path (in-list '("dir"
                         "link"
                         "pipe"
                         "/"
                         "/missing/child"
                         "/cwd/a.txt/child"
                         "/cwd/link/child"
                         "/cwd/pipe/child"))])
    (check-false
     (driver-eval!
      state
      `((fs write (fs path ,path) "refused") present?))))
  (check-equal? (driver-eval! state '((fs-host names "/cwd") len))
                names-before)
  (check-equal? (driver-eval! state '(fs-host read "/cwd/a.txt"))
                "thin overwrite")
  (for ([path (in-list '("/missing/child"
                         "/cwd/a.txt/child"
                         "/cwd/link/child"
                         "/cwd/pipe/child"))])
    (check-equal? (driver-eval! state `(fs-host kind ,path)) "missing"))
  (check-equal? (driver-eval! state '(fs-host kind "/cwd")) "directory")
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/link")) "symlink")
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/pipe")) "fifo"))

(test-case "production bytes are exact UTF-8 and symbolic links are not followed"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (path->string directory))
     (define file-path (build-path directory "created.txt"))
     (define empty-path (build-path directory "empty.txt"))
     (define target-path (build-path directory "target.txt"))
     (define link-path (build-path directory "link.txt"))
     (define invalid-path (build-path directory "invalid.txt"))
     (define state (make-driver))
     (driver-inject-host! state 'fs-host (make-fs-receiver))

     (define exact-text "λ\r\nlast")
     (check-equal?
      (driver-eval! state `(fs-host write ,(path->string file-path) ,exact-text))
      exact-text)
     (check-equal? (file->bytes file-path) (string->bytes/utf-8 exact-text))
     (check-equal?
      (driver-eval! state `(fs-host read ,(path->string file-path)))
      exact-text)

     (check-equal?
      (driver-eval! state `(fs-host write ,(path->string file-path) "second"))
      "second")
     (check-equal? (file->bytes file-path) #"second")

     (write-exact-bytes empty-path #"")
     (check-equal?
      (driver-eval! state `(fs-host read ,(path->string empty-path)))
      "")

     (write-exact-bytes target-path #"target stays")
     (make-file-or-directory-link "target.txt" link-path)
     (check-exn
      (host-failure? 'FsHost 'read)
      (lambda ()
        (driver-eval! state `(fs-host read ,(path->string link-path)))))
     (check-exn
      (host-failure? 'FsHost 'write)
      (lambda ()
        (driver-eval!
         state
         `(fs-host write ,(path->string link-path) "replacement"))))
     (check-equal? (file->bytes target-path) #"target stays")

     (write-exact-bytes invalid-path (bytes #xc3 #x28))
     (check-exn
      (host-failure? 'FsHost 'read)
      (lambda ()
        (driver-eval! state `(fs-host read ,(path->string invalid-path)))))

     (check-equal? (driver-eval! state `(fs-host kind ,root)) "directory"))))
