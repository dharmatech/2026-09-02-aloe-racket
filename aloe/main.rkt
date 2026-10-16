#lang racket/base

(require (only-in racket/port port->bytes)
         (only-in "env.rkt"
                  [make-top-level-env make-runtime-environment]
                  make-local-env)
         "eval.rkt"
         "library.rkt"
         "parse.rkt"
         (only-in "host.rkt" host-interface?)
         (prefix-in checker: "type.rkt")
         (only-in (submod "type.rkt" load-cache)
                  typecheck-keyed-root
                  typecheck-keyed-buffer
                  typecheck-file-buffer
                  record-checked-libraries!
                  record-checked-option-class!
                  make-interactive-type-environment
                  type-environment-base)
         (only-in (submod "type.rkt" query-host-binding)
                  type-environment-bind-host-interface!))

(provide make-top-level-env
         make-type-environment
         type-of
         typecheck-program
         typecheck-source
         type->datum
         exn:fail:aloe-type?
         eval-datum
         eval-program
         eval-source)

;; Each runtime interactive environment maps to its checker interactive
;; environment.
(define runtime-type-environments (make-weak-hasheq))
;; A raw kernel environment handed to eval-source, eval-program, or eval-datum
;; is the base of the interactive environment memoized here beside it.
(define raw-interactive-environments (make-ephemeron-hasheq))

(define make-raw-type-environment checker:make-type-environment)
(define type-of checker:type-of)
(define typecheck-program checker:typecheck-program)
(define type->datum checker:type->datum)
(define exn:fail:aloe-type? checker:exn:fail:aloe-type?)

;; The interactive environment of a fresh base.
(define (make-type-environment)
  (define base (make-raw-type-environment))
  (typecheck-program (list-library-expressions) base)
  (typecheck-program (string-library-expressions) base)
  (typecheck-program (int-library-expressions) base)
  (typecheck-program (option-library-expressions) base)
  (record-checked-option-class! base)
  (record-checked-libraries! base)
  (make-interactive-type-environment base))

;; The interactive environment of a fresh base.
(define (make-top-level-env)
  (define base (make-runtime-environment))
  (install-evaluated-libraries! base)
  (make-interactive-environment base))

(define (install-evaluated-libraries! base)
  (eval-exprs (list-library-expressions) base)
  (eval-exprs (string-library-expressions) base)
  (eval-exprs (int-library-expressions) base)
  (eval-exprs (option-library-expressions) base)
  (record-evaluated-option-class! base)
  (record-evaluated-libraries! base))

(define (make-interactive-environment base)
  (define environment (make-local-env base '()))
  (hash-set! runtime-type-environments
             environment
             (make-type-environment))
  environment)

;; Forms evaluate in an interactive environment: the one given, or the one
;; memoized beside a raw kernel environment, which is bootstrapped in place
;; the first time and never holds a prompt definition.
(define (interactive-environment-for environment)
  (cond
    [(hash-has-key? runtime-type-environments environment) environment]
    [(hash-ref raw-interactive-environments environment #f) => values]
    [else
     (install-evaluated-libraries! environment)
     (define interactive-environment
       (make-interactive-environment environment))
     (hash-set! raw-interactive-environments
                environment
                interactive-environment)
     interactive-environment]))

(define (type-environment-for interactive-environment)
  (hash-ref runtime-type-environments interactive-environment))

(define (source-bytes input)
  (if (string? input)
      (string->bytes/utf-8 input)
      (port->bytes input)))

(define (typecheck-source input
                          [environment (make-type-environment)]
                          #:source-path [source-path #f])
  (cond
    [source-path
     (define-values (result _expressions)
       (typecheck-keyed-root environment source-path (source-bytes input)))
     result]
    [else
     (typecheck-program (read-program input) environment)]))

(define (eval-datum datum [environment (make-top-level-env)])
  (define interactive-environment (interactive-environment-for environment))
  (define expression (parse-datum datum))
  (type-of expression (type-environment-for interactive-environment))
  (eval-expr expression interactive-environment))

(define (eval-program datums [environment (make-top-level-env)])
  (define interactive-environment (interactive-environment-for environment))
  (define expressions (parse-program datums))
  (typecheck-program expressions
                     (type-environment-for interactive-environment))
  (eval-exprs expressions interactive-environment))

(define (eval-source input
                     [environment (make-top-level-env)]
                     #:source-path [source-path #f])
  (define interactive-environment (interactive-environment-for environment))
  (cond
    [source-path
     (define input-bytes (source-bytes input))
     (define-values (_result expressions)
       (typecheck-keyed-root (type-environment-for interactive-environment)
                             source-path
                             input-bytes))
     (eval-keyed-root interactive-environment
                      source-path
                      input-bytes
                      expressions
                      (lambda (expressions file-environment)
                        (eval-exprs expressions file-environment)))]
    [else
     (define expressions (read-program input))
     (typecheck-program expressions
                        (type-environment-for interactive-environment))
     (eval-exprs expressions interactive-environment)]))

;; The base libraries in install order, by resolved path.
(define base-libraries
  (list (cons list-library-resolved-path list-library-expressions)
        (cons string-library-resolved-path string-library-expressions)
        (cons int-library-resolved-path int-library-expressions)
        (cons option-library-resolved-path option-library-expressions)))

;; The resolved path when a query's identity path names a base library.
(define (base-library-path identity-path)
  (define path (resolved-source-path identity-path))
  (and (assoc path base-libraries) path))

;; A query of a base library does not check the buffer on top of an installed
;; copy. Its fresh base installs the other libraries and then the buffer, last,
;; as the query's one root check, keyed by the library's path.
(define (typecheck-base-library-buffer library-path
                                       source-bytes
                                       expressions
                                       observe)
  (define environment (make-raw-type-environment))
  (for ([library (in-list base-libraries)]
        #:unless (equal? (car library) library-path))
    (typecheck-program ((cdr library)) environment)
    (when (equal? (car library) option-library-resolved-path)
      (record-checked-option-class! environment)))
  (record-checked-libraries! environment #:except library-path)
  (begin0
    (typecheck-keyed-buffer environment
                            library-path
                            source-bytes
                            (lambda () (observe expressions environment)))
    (when (equal? library-path option-library-resolved-path)
      (record-checked-option-class! environment))))

;; Any other queried buffer is a file module at its identity path, in a fresh
;; base whose interactive environment stays empty. Each host's type is bound on
;; that base first, as the driver's injection binds it, so the buffer and every
;; file it loads see the host; a name the base already binds is refused. Who
;; names the query.
(define (typecheck-file-module-buffer document-path
                                      source-bytes
                                      expressions
                                      observe
                                      #:hosts [hosts '()]
                                      #:who [who 'typecheck-file-module-buffer])
  (define environment (make-type-environment))
  (define base (type-environment-base environment))
  (for ([host (in-list hosts)])
    (define name (car host))
    (when (checker:type-environment-bound? base name)
      (raise-arguments-error who
                             "host name is already bound on the query base"
                             "host name" name))
    (type-environment-bind-host-interface! base name (cdr host)))
  (typecheck-file-buffer environment
                         document-path
                         source-bytes
                         (lambda (file-environment)
                           (observe expressions file-environment))))

;; A query's hosts are a list of distinct names, each paired with a host
;; interface. Who names the query.
(define (check-query-hosts who hosts)
  (unless (and (list? hosts)
               (for/and ([host (in-list hosts)])
                 (and (pair? host)
                      (symbol? (car host))
                      (host-interface? (cdr host)))))
    (raise-argument-error who
                          "(listof (cons/c symbol? host-interface?))"
                          hosts))
  (for/fold ([seen (hasheq)])
            ([host (in-list hosts)])
    (define name (car host))
    (when (hash-ref seen name #f)
      (raise-arguments-error who
                             "host names must be distinct"
                             "host name" name))
    (hash-set seen name #t))
  (void))

;; The editor queries install a queried base library, or check any other
;; buffer as a file module, through these hooks, and check their hosts'
;; shape through check-query-hosts.
(module* query-base #f
  (provide base-library-path
           check-query-hosts
           typecheck-base-library-buffer
           typecheck-file-module-buffer))
