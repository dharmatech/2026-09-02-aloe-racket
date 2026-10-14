#lang racket/base

(require (only-in racket/port port->bytes)
         (only-in "env.rkt"
                  [make-top-level-env make-runtime-environment]
                  make-local-env
                  env-base
                  env-bound?
                  env-define!)
         "eval.rkt"
         "host.rkt"
         "library.rkt"
         "parse.rkt"
         "type.rkt"
         (only-in (submod "type.rkt" driver-host-injection)
                  type-environment-inject-host!)
         (only-in (submod "type.rkt" load-cache)
                  typecheck-keyed-root
                  record-checked-libraries!
                  record-checked-option-class!
                  make-interactive-type-environment
                  type-environment-base))

(provide (struct-out driver)
         make-driver
         driver-inject-host!
         driver-eval!
         driver-prepare!
         current-driver-prepare-counter
         driver-load-port!
         driver-load-file!
         aloe-value->string
         write-aloe-result
         run-repl
         run-cli)

;; The two fields hold the interactive environments; each one's parent is its
;; half's base.
(struct driver (runtime-environment type-environment) #:transparent)

(define (make-driver)
  (define runtime-base (make-runtime-environment))
  (define type-base (make-type-environment))
  (typecheck-program (list-library-expressions) type-base)
  (typecheck-program (string-library-expressions) type-base)
  (typecheck-program (int-library-expressions) type-base)
  (typecheck-program (option-library-expressions) type-base)
  (record-checked-option-class! type-base)
  (eval-exprs (list-library-expressions) runtime-base)
  (eval-exprs (string-library-expressions) runtime-base)
  (eval-exprs (int-library-expressions) runtime-base)
  (eval-exprs (option-library-expressions) runtime-base)
  (record-evaluated-option-class! runtime-base)
  (record-checked-libraries! type-base)
  (record-evaluated-libraries! runtime-base)
  (driver (make-local-env runtime-base '())
          (make-interactive-type-environment type-base)))

(define (driver-inject-host! state name receiver)
  (unless (driver? state)
    (raise-arguments-error
     'driver-inject-host!
     "a-driver must be a driver"
     "a-driver" state))
  (unless (symbol? name)
    (raise-arguments-error
     'driver-inject-host!
     "binding-name must be a symbol"
     "binding-name" name))
  (unless (host-receiver? receiver)
    (raise-arguments-error
     'driver-inject-host!
     "a-host-receiver must be a validated host receiver"
     "a-host-receiver" receiver))
  (define runtime-bound?
    (env-bound? (driver-runtime-environment state) name))
  (define checker-bound?
    (type-environment-bound? (driver-type-environment state) name))
  (when (or runtime-bound? checker-bound?)
    (raise-arguments-error
     'driver-inject-host!
     "binding-name is already bound in the driver"
     "binding-name" name
     "runtime binding present" runtime-bound?
     "checker binding present" checker-bound?))
  ;; A host lives on the base, so every file loaded afterwards sees it.
  (type-environment-inject-host!
   (type-environment-base (driver-type-environment state)) name receiver)
  (env-define! (env-base (driver-runtime-environment state)) name receiver)
  (void))

(define (driver-eval! state datum)
  (define expression (parse-datum datum))
  (type-of expression (driver-type-environment state))
  (eval-expr expression (driver-runtime-environment state)))

(define current-driver-prepare-counter (make-parameter #f))

;; Preparation checks without running. Reuse requires compatible bindings and
;; unchanged classes, methods, and loaded files; each run sees current values.
(define (driver-prepare! state datum)
  (define counter (current-driver-prepare-counter))
  (when (and (box? counter) (exact-integer? (unbox counter)))
    (set-box! counter (add1 (unbox counter))))
  (define expression (parse-datum datum))
  (type-of expression (driver-type-environment state))
  (lambda ()
    (eval-expr expression (driver-runtime-environment state))))

(define (write-aloe-result value
                           [output (current-output-port)]
                           #:raw? [raw? #f])
  (unless (void? value)
    (displayln
     ((if raw? aloe-value->string aloe-value->display-string) value)
     output)))

(define (driver-load-port! state
                           input
                           [output (current-output-port)]
                           #:source-path [source-path #f])
  (cond
    [source-path
     ;; A program with a source path runs once per driver, in its own file
     ;; environment, and copies its definitions to the prompt; a hit returns
     ;; '() and writes nothing.
     (define source-bytes (port->bytes input))
     (define-values (_result expressions)
       (typecheck-keyed-root (driver-type-environment state)
                             source-path
                             source-bytes))
     (eval-keyed-root (driver-runtime-environment state)
                      source-path
                      source-bytes
                      expressions
                      (lambda (expressions file-environment)
                        (eval-and-write file-environment expressions output))
                      '())]
    [else
     (define expressions (read-program input))
     ;; Check the complete file before evaluating its first expression.
     (typecheck-program expressions (driver-type-environment state))
     (eval-and-write (driver-runtime-environment state) expressions output)]))

(define (eval-and-write environment expressions output)
  (reverse
   (for/fold ([results '()])
             ([expression (in-list expressions)])
     (define value
       (eval-expr expression environment))
     (cond
       [(void? value) results]
       [else
        (write-aloe-result value output)
        (cons value results)]))))

(define (source-path? path)
  (define text
    (cond
      [(path? path) (path->string path)]
      [(string? path) path]
      [else #f]))
  (and text (regexp-match? #px"(?i:\\.(?:aloe|sexpr))$" text)))

(define (driver-load-file! state path [output (current-output-port)])
  (unless (source-path? path)
    (raise-arguments-error
     'driver-load-file!
     "expected an .aloe or .sexpr source file"
     "path" path))
  (call-with-input-file path
    (lambda (input)
      (driver-load-port! state input output #:source-path path))))

(define (run-repl [state (make-driver)]
                  [input (current-input-port)]
                  [output (current-output-port)]
                  [error-output (current-error-port)])
  (let loop ()
    (display "aloe> " output)
    (flush-output output)
    (define continue?
      (with-handlers ([exn:fail?
                       (lambda (exception)
                         (displayln (exn-message exception) error-output)
                         #t)])
        (define datum (read input))
        (cond
          [(eof-object? datum) #f]
          [(equal? datum '(exit)) #f]
          [(eq? datum ':raw)
           (define raw-datum (read input))
           (when (eof-object? raw-datum)
             (error 'aloe ":raw requires an expression"))
           (write-aloe-result
            (driver-eval! state raw-datum)
            output
            #:raw? #t)
           #t]
          [else
           (write-aloe-result (driver-eval! state datum) output)
           #t])))
    (if continue? (loop) (void))))

(define (run-cli [arguments (current-command-line-arguments)]
                 #:input [input (current-input-port)]
                 #:output [output (current-output-port)]
                 #:error [error-output (current-error-port)])
  (define args
    (if (vector? arguments) (vector->list arguments) arguments))
  (define state (make-driver))
  (define (load-and-finish path quit?)
    (with-handlers ([exn:fail?
                     (lambda (exception)
                       (fprintf error-output "aloe: ~a\n"
                                (exn-message exception))
                       1)])
      (driver-load-file! state path output)
      (unless quit?
        (run-repl state input output error-output))
      0))
  (cond
    [(null? args)
     (run-repl state input output error-output)
     0]
    [(and (= (length args) 1)
          (not (equal? (car args) "--quit")))
     (load-and-finish (car args) #f)]
    [(and (= (length args) 2)
          (equal? (car args) "--quit"))
     (load-and-finish (cadr args) #t)]
    [else
     (displayln "usage: aloe [--quit] [path.aloe|path.sexpr]"
                error-output)
     2]))
