#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         syntax/modcode
         "../../../aloe/host-manifest.rkt"
         "../../../host/racket/fs.rkt"
         "../../../host/racket/term.rkt")

(define-runtime-path repository-root-path "../../..")
(define-runtime-path configured-folder "fixtures/configured")
(define-runtime-path host-manifest-module-path
  "../../../aloe/host-manifest.rkt")

(define repository-root
  (simplify-path (path->complete-path repository-root-path)))
(define aloe-folder (build-path repository-root "aloe"))
(define host-folder (build-path repository-root "host" "racket"))

(define uses-fs-path (build-path configured-folder "uses-fs.aloe"))

;; R, the one row of the manifest M.
(define row-r
  "(file \"main.aloe\" (host fs-host host/racket/fs fs-interface))")
(define manifest-m (format "(~a)" row-r))

(define fs-entry "(host fs-host host/racket/fs fs-interface)")
(define term-entry "(host term host/racket/term term-interface)")

(define fs-hosts (document-hosts (list (cons 'fs-host fs-interface))))

;; Calls proc with a fresh folder under the system's temporary directory and
;; removes the folder however proc returns.
(define (call-with-temporary-folder proc)
  (define folder (make-temporary-file "host-queries-001-~a" 'directory))
  (dynamic-wind
   void
   (lambda () (proc folder))
   (lambda () (delete-directory/files folder #:must-exist? #f))))

(define (write-manifest folder text)
  (call-with-output-file (build-path folder host-manifest-name)
    (lambda (out) (void (write-string text out)))
    #:exists 'truncate/replace))

;; A loader that records each (list MODULE EXPORT) it is called with and
;; returns fs-interface, and a procedure that lists the calls in order.
(define (make-counting-loader)
  (define calls '())
  (values (lambda (module export missing)
            (set! calls (cons (list module export) calls))
            fs-interface)
          (lambda () (reverse calls))))

;; The result for main.aloe under a one-row manifest holding entries. With
;; no loader, the reader's default loader.
(define (main-row-result #:loader [loader #f] . entries)
  (call-with-temporary-folder
   (lambda (folder)
     (write-manifest folder
                     (format "((file \"main.aloe\" ~a))"
                             (string-join entries " ")))
     (define main-path (build-path folder "main.aloe"))
     (if loader
         (read-document-hosts main-path #:loader loader)
         (read-document-hosts main-path)))))

(test-case "the reader's surface and its argument checks"
  (check-equal? host-manifest-name "aloe-hosts.rktd")
  (define-values (value-exports syntax-exports)
    (module->exports host-manifest-module-path))
  (define (phase-0-names exports)
    (sort (map car (cdr (or (assv 0 exports) '(0)))) symbol<?))
  (check-equal? (phase-0-names value-exports)
                '(document-hosts-bindings
                  document-hosts-failure-reason
                  document-hosts-failure?
                  document-hosts?
                  host-manifest-name
                  struct:document-hosts
                  struct:document-hosts-failure))
  (check-equal? (phase-0-names syntax-exports)
                '(document-hosts
                  document-hosts-failure
                  read-document-hosts))
  (define (argument-error? exn)
    (and (exn:fail:contract? exn)
         (string-prefix? (exn-message exn) "read-document-hosts: ")))
  (check-exn argument-error? (lambda () (read-document-hosts 3)))
  (check-exn argument-error?
             (lambda ()
               (read-document-hosts "main.aloe"
                                    #:loader (lambda (module export)
                                               fs-interface))))
  (check-exn argument-error?
             (lambda () (read-document-hosts "main.aloe" #:loader 'nope))))

(test-case "a row matches only its own document, and every call rereads"
  (call-with-temporary-folder
   (lambda (folder)
     (define-values (loader calls) (make-counting-loader))
     (define (hosts-of document)
       (read-document-hosts document #:loader loader))
     (define main-path (build-path folder "main.aloe"))
     (define other-path (build-path folder "other.aloe"))
     (check-false (hosts-of main-path))
     (write-manifest folder manifest-m)
     (check-equal? (hosts-of main-path) fs-hosts)
     (for ([name (in-list
                  '("other.aloe" "Main.aloe" "aloe-lsp-snapshot-123"))])
       (check-false (hosts-of (build-path folder name)) name))
     (check-equal? (hosts-of (build-path folder "sub" 'up "main.aloe"))
                   fs-hosts)
     (parameterize ([current-directory folder])
       (check-equal? (hosts-of "main.aloe") fs-hosts))
     (write-manifest
      folder
      "((file \"other.aloe\" (host fs-host host/racket/fs fs-interface)))")
     (check-false (hosts-of main-path))
     (check-equal? (hosts-of other-path) fs-hosts)
     (write-manifest folder "()")
     (check-false (hosts-of other-path)))))

;; Each whole manifest text, the document it names, and why it is broken.
(define broken-manifests
  (list
   (list "((file \"main.aloe\" (host fs-host host/racket/fs fs-interface))"
         "main.aloe" "unparseable")
   (list "#lang racket/base" "main.aloe" "#lang is not accepted")
   (list "() ()" "main.aloe" "a second datum")
   (list "(file \"main.aloe\" (host fs-host host/racket/fs fs-interface))"
         "main.aloe" "not a list of rows")
   (list "((file \"main.aloe\"))" "main.aloe" "a row with no entry")
   (list "((file main.aloe (host fs-host host/racket/fs fs-interface)))"
         "main.aloe" "NAME is a symbol")
   (list "((file \"../main.aloe\" (host fs-host host/racket/fs fs-interface)))"
         "main.aloe" "NAME contains /")
   (list "((file \"main.aloe\" (host fs-host host/racket/fs)))"
         "main.aloe" "an entry of three")
   (list "((file \"main.aloe\" (hosts fs-host host/racket/fs fs-interface)))"
         "main.aloe" "wrong entry head")
   (list (string-append
          "((file \"main.aloe\""
          " (host \"fs-host\" host/racket/fs fs-interface)))")
         "main.aloe" "BINDING is a string")
   (list (string-append
          "((file \"main.aloe\" (host fs-host host/racket/fs fs-interface"
          " (receiver make-fs-receiver))))")
         "main.aloe" "a fifth element")
   (list (string-append
          "((file \"a.aloe\" (host fs-host host/racket/fs fs-interface))"
          " (file \"a.aloe\" (host term host/racket/term term-interface)))")
         "a.aloe" "a repeated NAME")
   (list (format "#0=(~a)" row-r) "main.aloe" "graph notation")
   (list (format "#reader racket/base (~a)" row-r)
         "main.aloe" "#reader is not accepted")
   (list (format "(~a (file \"\" ~a))" row-r term-entry)
         "main.aloe" "an empty NAME")
   (list (format "(~a (file \".\" ~a))" row-r term-entry)
         "main.aloe" "NAME is .")
   (list (format "(~a (file \"..\" ~a))" row-r term-entry)
         "main.aloe" "NAME is ..")
   (list (format "(~a (file \"a\\\\b\" ~a))" row-r term-entry)
         "main.aloe" "NAME contains \\")
   (list (format "(~a (file \"a\\0b\" ~a))" row-r term-entry)
         "main.aloe" "NAME contains NUL")))

(test-case "a broken manifest configures no document in its folder"
  ;; The last two texts spell their NAMEs with the reader's escapes.
  (define (second-name text)
    (cadr (cadr (read (open-input-string text)))))
  (check-equal? (second-name (first (list-ref broken-manifests 17)))
                (string #\a #\\ #\b))
  (check-equal? (second-name (first (list-ref broken-manifests 18)))
                (string #\a #\nul #\b))
  (for ([broken (in-list broken-manifests)])
    (define-values (text document why) (apply values broken))
    (call-with-temporary-folder
     (lambda (folder)
       (define-values (loader calls) (make-counting-loader))
       (write-manifest folder text)
       (for ([name (in-list (list document "neighbor.aloe"))])
         (check-false (read-document-hosts (build-path folder name)
                                           #:loader loader)
                      (format "~a: ~a" why name)))
       (check-equal? (calls) '() why))))
  (call-with-temporary-folder
   (lambda (folder)
     (define-values (loader calls) (make-counting-loader))
     (make-directory (build-path folder host-manifest-name))
     (check-false (read-document-hosts (build-path folder "main.aloe")
                                       #:loader loader))
     (check-equal? (calls) '()))))

;; Every MODULE outside the host/racket boundary.
(define rejected-modules
  '("host/racket/fs"
    (file "/tmp/x.rkt")
    (lib "host/racket/fs")
    (planet a/b)
    (submod host/racket/fs main)
    ./fs
    fs
    host/racket/../aloe/lsp
    host/racket/fs/deeper
    host/racket
    aloe/lsp
    racket/base
    host/racket/FS
    host/racket/a.b))

(test-case "a failing row is all or nothing, with one of four reasons"
  (define-values (loader calls) (make-counting-loader))
  (check-equal? (main-row-result
                 #:loader loader
                 fs-entry
                 "(host fs-host host/racket/term term-interface)")
                (document-hosts-failure 'duplicate-name))
  (check-equal? (main-row-result #:loader loader
                                 fs-entry
                                 "(host fs-host racket/base term-interface)")
                (document-hosts-failure 'duplicate-name))
  (for ([module (in-list rejected-modules)])
    (define entry (format "(host fs-host ~s fs-interface)" module))
    (check-equal? (main-row-result #:loader loader entry)
                  (document-hosts-failure 'module-path)
                  entry)
    (check-equal? (main-row-result #:loader loader term-entry entry)
                  (document-hosts-failure 'module-path)
                  entry))
  (check-equal? (calls) '())
  (check-equal? (main-row-result #:loader (lambda (module export missing)
                                            (error 'loader "failed"))
                                 fs-entry)
                (document-hosts-failure 'load))
  (check-equal? (main-row-result #:loader (lambda (module export missing)
                                            (raise 'boom))
                                 fs-entry)
                (document-hosts-failure 'load))
  (check-equal? (main-row-result #:loader (lambda (module export missing)
                                            (missing))
                                 fs-entry)
                (document-hosts-failure 'export))
  (check-equal? (main-row-result #:loader (lambda (module export missing)
                                            42)
                                 fs-entry)
                (document-hosts-failure 'export))
  (define raising-calls 0)
  (check-equal? (main-row-result #:loader (lambda (module export missing)
                                            (set! raising-calls
                                                  (add1 raising-calls))
                                            (error 'loader "failed"))
                                 fs-entry
                                 term-entry)
                (document-hosts-failure 'load))
  (check-equal? raising-calls 1)
  (check-equal? (main-row-result
                 "(host fs-host host/racket/no-such-module fs-interface)")
                (document-hosts-failure 'load))
  (check-equal? (main-row-result
                 "(host fs-host host/racket/fs no-such-interface)")
                (document-hosts-failure 'export))
  (check-equal? (main-row-result
                 "(host fs-host host/racket/fs make-fs-receiver)")
                (document-hosts-failure 'export)))

(test-case "the default loader binds each host to its exported interface"
  (define uses-fs (read-document-hosts uses-fs-path))
  (check-equal? uses-fs fs-hosts)
  (check-eq? (cdr (first (document-hosts-bindings uses-fs))) fs-interface)
  (check-equal? (read-document-hosts
                 (build-path configured-folder "failing.aloe"))
                (document-hosts-failure 'export))
  (check-false (read-document-hosts
                (build-path configured-folder "spot.aloe")))
  (check-false (read-document-hosts
                (build-path configured-folder "reads-fs.aloe")))
  (define both (main-row-result fs-entry term-entry))
  (check-equal? both
                (document-hosts (list (cons 'fs-host fs-interface)
                                      (cons 'term term-interface))))
  (check-eq? (cdr (first (document-hosts-bindings both))) fs-interface)
  (check-eq? (cdr (second (document-hosts-bindings both))) term-interface)
  (define-values (loader calls) (make-counting-loader))
  (check-equal? (read-document-hosts uses-fs-path #:loader loader) fs-hosts)
  (check-equal? (calls) '((host/racket/fs fs-interface))))

(test-case "a load writes nothing to the caller's ports and reads nothing"
  (call-with-temporary-folder
   (lambda (folder)
     (write-manifest folder manifest-m)
     (define out (open-output-string))
     (define err (open-output-string))
     (define in (open-input-bytes #"held"))
     (define loaded-byte #f)
     (define (loud-loader module export missing)
       (write-string "loading" (current-output-port))
       (write-string "loading" (current-error-port))
       (set! loaded-byte (read-byte (current-input-port)))
       fs-interface)
     (define result
       (parameterize ([current-output-port out]
                      [current-error-port err]
                      [current-input-port in])
         (read-document-hosts (build-path folder "main.aloe")
                              #:loader loud-loader)))
     (check-equal? result fs-hosts)
     (check-equal? (get-output-string out) "")
     (check-equal? (get-output-string err) "")
     (check-pred eof-object? loaded-byte)
     (check-equal? (read-bytes 4 in) #"held"))))

(define (path-elements path)
  (explode-path (simplify-path path #f)))

(define (path-under? path folder)
  (define elements (path-elements path))
  (define prefix (path-elements folder))
  (and (<= (length prefix) (length elements))
       (equal? (take elements (length prefix)) prefix)))

;; The files that compiled module code and its submodules, recursively,
;; import at every phase. Relative imports resolve against
;; current-load-relative-directory. A symbol names a primitive module or a
;; submodule's enclosing module and is left out.
(define (compiled-import-files code)
  (remove-duplicates
   (let walk ([code code])
     (append
      (for*/list ([phase+imports (in-list (module-compiled-imports code))]
                  [import (in-list (cdr phase+imports))]
                  [name (in-value (resolved-module-path-name
                                   (module-path-index-resolve import)))]
                  [file (in-value (if (pair? name) (car name) name))]
                  #:when (path? file))
        (simplify-path file #f))
      (append-map walk
                  (append (module-compiled-submodules code #t)
                          (module-compiled-submodules code #f)))))))

(define (source-import-files file)
  (parameterize ([current-load-relative-directory (path-only file)])
    (compiled-import-files (get-module-code file))))

(test-case "no module under aloe/ imports a host module"
  (define aloe-files
    (for/list ([path (in-directory
                      aloe-folder
                      (lambda (folder)
                        (not (equal? (file-name-from-path folder)
                                     (string->path "compiled")))))]
               #:when (and (file-exists? path)
                           (path-has-extension? path #".rkt")))
      (simplify-path path #f)))
  (define (aloe-file . elements)
    (simplify-path (apply build-path aloe-folder elements) #f))
  (define lsp-file (aloe-file "lsp.rkt"))
  (define reader-file (aloe-file "host-manifest.rkt"))
  (check-not-false (member reader-file aloe-files))
  (check-not-false (member (aloe-file "private" "checker-observation.rkt")
                           aloe-files))
  (define imports
    (for/hash ([file (in-list aloe-files)])
      (values file (source-import-files file))))
  (for* ([(file files) (in-hash imports)]
         [import (in-list files)])
    (define label (format "~a imports ~a" file import))
    (check-true (or (path-under? import aloe-folder)
                    (not (path-under? import repository-root)))
                label)
    (check-false (path-under? import host-folder) label))
  (check-not-false (member (aloe-file "expression-query.rkt")
                           (hash-ref imports lsp-file)))
  (check-equal? (filter (lambda (import)
                          (path-under? import repository-root))
                        (hash-ref imports reader-file))
                (list (aloe-file "host.rkt")))
  (define lsp-closure
    (let loop ([pending (list lsp-file)] [seen '()])
      (cond
        [(null? pending) seen]
        [(member (car pending) seen) (loop (cdr pending) seen)]
        [else
         (loop (append (filter (lambda (import)
                                 (path-under? import aloe-folder))
                               (hash-ref imports (car pending) '()))
                       (cdr pending))
               (cons (car pending) seen))])))
  (check-not-false (member (aloe-file "main.rkt") lsp-closure))
  (check-false (member (aloe-file "driver.rkt") lsp-closure))
  ;; Self-check: the walk sees a host import inside a module* submodule.
  (define self-check-code
    (parameterize ([current-namespace (make-base-namespace)])
      (compile '(module self-check racket/base
                  (module* host-user #f
                    (require host/racket/fs))))))
  (define self-check-files (compiled-import-files self-check-code))
  (check-not-false
   (member (path-elements (build-path host-folder "fs.rkt"))
           (map path-elements
                (filter (lambda (import)
                          (path-under? import repository-root))
                        self-check-files)))))

(test-case "the queries and the reader never construct a host receiver"
  (for ([name (in-list '("main.rkt"
                         "expression-query.rkt"
                         "definition-query.rkt"
                         "completion-query.rkt"
                         "host-manifest.rkt"))])
    (define source (file->string (build-path aloe-folder name)))
    (check-false (string-contains? source "make-host-receiver") name)
    (check-false (string-contains? source "driver-inject-host!") name)))

;; What loading the module at path in a fresh base namespace writes to
;; stdout and stderr.
(define (load-output path)
  (define out (open-output-string))
  (define err (open-output-string))
  (parameterize ([current-namespace (make-base-namespace)]
                 [current-output-port out]
                 [current-error-port err])
    (dynamic-require path #f))
  (list (get-output-string out) (get-output-string err)))

(test-case "loading a host module writes nothing"
  (define host-modules
    (for/list ([path (in-list (directory-list host-folder #:build? #t))]
               #:when (and (file-exists? path)
                           (path-has-extension? path #".rkt")))
      path))
  (check-true (>= (length host-modules) 7))
  (for ([path (in-list host-modules)])
    (check-equal? (load-output path) '("" "") (path->string path)))
  ;; Self-check: a module that prints is caught even after this namespace
  ;; has already instantiated it.
  (call-with-temporary-folder
   (lambda (folder)
     (define printing-path (build-path folder "printing.rkt"))
     (call-with-output-file printing-path
       (lambda (out)
         (void (write-string "#lang racket/base\n(display \"loaded\")\n"
                             out))))
     (parameterize ([current-output-port (open-output-nowhere)])
       (dynamic-require printing-path #f))
     (check-equal? (load-output printing-path) '("loaded" "")))))
