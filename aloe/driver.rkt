#lang racket/base

(require (only-in "env.rkt"
                  [make-top-level-env make-runtime-environment])
         "eval.rkt"
         "library.rkt"
         "parse.rkt"
         "type.rkt")

(provide (struct-out driver)
         make-driver
         driver-eval!
         driver-load-port!
         driver-load-file!
         aloe-value->string
         write-aloe-result
         run-repl
         run-cli)

(struct driver (runtime-environment type-environment) #:transparent)

(define (make-driver)
  (define runtime-environment (make-runtime-environment))
  (define type-environment (make-type-environment))
  (typecheck-program (list-library-expressions) type-environment)
  (eval-exprs (list-library-expressions) runtime-environment)
  (driver runtime-environment type-environment))

(define (driver-eval! state datum)
  (define expression (parse-datum datum))
  (type-of expression (driver-type-environment state))
  (eval-expr expression (driver-runtime-environment state)))

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
  (define expressions
    (read-program input #:source-path source-path))
  ;; Check the complete file before evaluating its first expression.
  (typecheck-program expressions (driver-type-environment state))
  (reverse
   (for/fold ([results '()])
             ([expression (in-list expressions)])
     (define value
       (eval-expr expression (driver-runtime-environment state)))
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
