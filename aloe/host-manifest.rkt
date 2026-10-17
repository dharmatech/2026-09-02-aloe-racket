#lang racket/base

;; The editor's reader for `aloe-hosts.rktd`, the manifest beside a program
;; that names the hosts its runner injects. The manifest is read as data and
;; never evaluated. This is the only module under aloe/ that loads a host
;; module, and it loads only modules in the `host/racket` collection.

(require racket/list
         racket/port
         (only-in "host.rkt" host-interface?))

(provide host-manifest-name
         (struct-out document-hosts)
         (struct-out document-hosts-failure)
         read-document-hosts)

(define host-manifest-name "aloe-hosts.rktd")

;; bindings: (cons BINDING interface) in row order.
(struct document-hosts (bindings) #:transparent)
;; reason: 'duplicate-name, 'module-path, 'load, or 'export.
(struct document-hosts-failure (reason) #:transparent)

;; The default loader requires host modules into an empty namespace that
;; shares this module's registry, so a host module and the reader share one
;; instance of host.rkt and `host-interface?` holds for its interfaces.
(define-namespace-anchor reader-anchor)

(define (default-loader module export missing)
  (parameterize ([current-namespace
                  (namespace-anchor->empty-namespace reader-anchor)])
    (dynamic-require module export missing)))

;; What the failure thunk returns. Nothing outside this module can make it.
(struct missing-export ())
(define the-missing-export (missing-export))
(define (missing) the-missing-export)

(struct load-failed ())
(define the-load-failure (load-failed))

;; #f when the document's folder has no manifest, a broken one, or no row
;; for the document. Otherwise the row's hosts or why the row failed.
(define (read-document-hosts document-path #:loader [loader default-loader])
  (unless (path-string? document-path)
    (raise-argument-error 'read-document-hosts "path-string?" document-path))
  (unless (and (procedure? loader) (procedure-arity-includes? loader 3))
    (raise-argument-error 'read-document-hosts
                          "(procedure-arity-includes/c 3)"
                          loader))
  (define path (simplify-path (path->complete-path document-path) #f))
  (define-values (folder name must-be-dir?) (split-path path))
  (define rows
    (and (path? folder)
         (path? name)
         (read-manifest (build-path folder host-manifest-name))))
  (define row (and rows (find-row rows name)))
  (and row (check-row (cddr row) loader)))

;; The manifest's rows, or #f when it cannot be opened or read or is outside
;; the manifest's shape. The manifest is read on every call.
(define (read-manifest manifest-path)
  (with-handlers ([exn:fail? (lambda (exn) #f)])
    (call-with-input-file manifest-path
      (lambda (in)
        (parameterize ([read-accept-reader #f]
                       [read-accept-lang #f]
                       [read-accept-compiled #f]
                       [read-accept-graph #f])
          (define datum (read in))
          (and (eof-object? (read in))
               (manifest? datum)
               datum))))))

(define (manifest? datum)
  (and (list? datum)
       (andmap row? datum)
       (not (check-duplicates (map cadr datum) string=?))))

(define (row? datum)
  (and (list? datum)
       (>= (length datum) 3)
       (eq? (car datum) 'file)
       (row-name? (cadr datum))
       (andmap entry? (cddr datum))))

(define (row-name? datum)
  (and (string? datum)
       (positive? (string-length datum))
       (not (member datum '("." "..")))
       (for/and ([char (in-string datum)])
         (not (memv char '(#\/ #\\ #\nul))))))

(define (entry? datum)
  (and (list? datum)
       (= (length datum) 4)
       (eq? (car datum) 'host)
       (symbol? (entry-binding datum))
       (symbol? (entry-export datum))))

(define (entry-binding entry) (list-ref entry 1))
(define (entry-module entry) (list-ref entry 2))
(define (entry-export entry) (list-ref entry 3))

;; The row whose NAME is exactly the document's file name.
(define (find-row rows name)
  (for/first ([row (in-list rows)]
              #:when (equal? (string->path-element (cadr row)) name))
    row))

;; Repeated binding names first, then every module path, then each entry's
;; load in row order. The first failure is the row's result.
(define (check-row entries loader)
  (cond
    [(check-duplicates (map entry-binding entries) eq?)
     (document-hosts-failure 'duplicate-name)]
    [(not (andmap host-module-path? (map entry-module entries)))
     (document-hosts-failure 'module-path)]
    [else
     (let loop ([entries entries] [bindings '()])
       (cond
         [(null? entries)
          (document-hosts (reverse bindings))]
         [else
          (define entry (car entries))
          (define interface
            (load-interface loader (entry-module entry) (entry-export entry)))
          (if (document-hosts-failure? interface)
              interface
              (loop (cdr entries)
                    (cons (cons (entry-binding entry) interface)
                          bindings)))]))]))

;; One segment directly under the `host/racket` collection, in one spelling.
(define (host-module-path? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^host/racket/[a-z0-9_-]+$" (symbol->string datum))))

;; The entry's interface, or its failure. While the loader runs, its output
;; goes nowhere and its input is empty: the language server's stdout and
;; stdin carry the LSP streams.
(define (load-interface loader module export)
  (define value
    (with-handlers ([(lambda (raised) (not (exn:break? raised)))
                     (lambda (raised) the-load-failure)])
      (parameterize ([current-output-port (open-output-nowhere)]
                     [current-error-port (open-output-nowhere)]
                     [current-input-port (open-input-bytes #"")])
        (call-with-values
         (lambda () (loader module export missing))
         (case-lambda
           [(value) value]
           [values #f])))))
  (cond
    [(eq? value the-load-failure) (document-hosts-failure 'load)]
    [(host-interface? value) value]
    [else (document-hosts-failure 'export)]))
