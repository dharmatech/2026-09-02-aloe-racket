#lang racket/base

(require racket/file
         racket/port
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         (only-in "../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?)
         "../host/racket/term.rkt")

(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path point-path "../examples/point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")
(define-runtime-path term-run-path "../host/racket/term-run.rkt")

(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define reader-calls (box 0))
  (define output (open-output-string))
  (values
   (make-term-receiver
    output
    (lambda ()
      (define remaining (unbox remaining-keys))
      (unless (pair? remaining)
        (error 'scripted-term "key script exhausted"))
      (set-box! remaining-keys (cdr remaining))
      (set-box! reader-calls (add1 (unbox reader-calls)))
      (car remaining)))
   output
   reader-calls))

(test-case "a checked Term file preserves effects and result printing"
  ;; An extensionless temporary file exercises the same driver-load-port!
  ;; path used by term-run.rkt without adding a driver extension restriction.
  (define path (make-temporary-file "checkpoint-86-~a"))
  (dynamic-wind
   void
   (lambda ()
     (call-with-output-file path
       (lambda (output)
         (display
          (string-append
           "(term write-line \"hello\")\n"
           "(term read-key)\n"
           "(1 + 2)\n")
          output))
       #:exists 'truncate)
     (define-values (term terminal-output reader-calls)
       (make-scripted-term '("q")))
     (define state (make-driver))
     (define result-output (open-output-string))
     (driver-inject-host! state 'term term)
     (define results
       (call-with-input-file path
         (lambda (input)
           (driver-load-port!
            state input result-output #:source-path path))))
     (check-equal? results '("hello" "q" 3))
     (check-equal? (get-output-string result-output)
                   "\"hello\"\n\"q\"\n3\n")
     (check-equal? (get-output-string terminal-output) "hello\r\n")
     (check-equal? (unbox reader-calls) 1))
   (lambda ()
     (when (file-exists? path)
       (delete-file path)))))

(test-case "whole-file checking prevents earlier terminal effects"
  (define-values (term terminal-output reader-calls)
    (make-scripted-term '("q")))
  (define state (make-driver))
  (define result-output (open-output-string))
  (driver-inject-host! state 'term term)
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-load-port!
      state
      (open-input-string
       (string-append
        "(term read-key)\n"
        "(term write-line \"before\")\n"
        "(term write-line 1)\n"))
      result-output
      #:source-path "bad-terminal-program")))
  (check-equal? (unbox reader-calls) 0)
  (check-equal? (get-output-string terminal-output) "")
  (check-equal? (get-output-string result-output) ""))

(define point-transcript
  (string-append
   "TOS: #<Point 10 20>\r\n"
   "1  x  0\r\n"
   "2  y  0\r\n"
   "3  +  1\r\n"
   "4  -  1\r\n"
   "5  dist2  1\r\n"
   "6  dot  1\r\n"
   "7  *  1\r\n"
   "8  /  1\r\n"
   "\r\n"))

(define int-transcript
  (string-append
   "TOS: 10\r\n"
   "1  +  1\r\n"
   "2  -  1\r\n"
   "3  *  1\r\n"
   "4  /  1\r\n"
   "5  <  1\r\n"
   "6  >  1\r\n"
   "7  <=  1\r\n"
   "8  >=  1\r\n"
   "9  =  1\r\n"
   "10  float  0\r\n"
   "11  text  0\r\n"
   "\r\n"))

(define (run-scripted-gel keys)
  (define-values (term terminal-output reader-calls)
    (make-scripted-term keys))
  (define state (make-driver))
  (define load-output (open-output-string))
  (driver-inject-host! state 'term term)
  (check-equal? (driver-load-file! state gel-main-path load-output) '())
  (check-equal? (driver-load-file! state point-path load-output) '())
  (driver-eval!
   state
   '(define checkpoint-86-initial-stack
      ((gel-empty-stack push (Point new 1 2))
       push
       (Point new 10 20))))
  (define initial-stack
    (driver-eval! state 'checkpoint-86-initial-stack))
  (driver-eval!
   state
   '(define checkpoint-86-final-stack
      (gel-main call checkpoint-86-initial-stack)))
  (values state
          initial-stack
          (driver-eval! state 'checkpoint-86-final-stack)
          (get-output-string terminal-output)
          (get-output-string load-output)
          (unbox reader-calls)))

(test-case "checked quit-only Gel run preserves stack and transcript"
  (define-values (state initial final transcript load-output reader-calls)
    (run-scripted-gel '("q")))
  (check-eq? final initial)
  (check-equal?
   (driver-eval! state '((checkpoint-86-final-stack items) len))
   2)
  (check-equal? transcript
                (string-append point-transcript "key q\r\n"))
  (check-equal? load-output "")
  (check-equal? reader-calls 1))

(test-case "checked digit-then-quit Gel run preserves result and transcript"
  (define-values (state initial final transcript load-output reader-calls)
    (run-scripted-gel '("1" "q")))
  (check-not-eq? final initial)
  (check-equal?
   (driver-eval! state '((checkpoint-86-final-stack items) len))
   3)
  (check-equal?
   (driver-eval! state '((checkpoint-86-final-stack tos) subject))
   10)
  (check-not-exn
   (lambda ()
     (driver-eval!
      state
      '(check
        ((checkpoint-86-final-stack items) rest)
        (checkpoint-86-initial-stack items)))))
  (check-equal?
   transcript
   (string-append
    point-transcript
    "key 1\r\n"
    int-transcript
    "key q\r\n"))
  (check-equal? load-output "")
  (check-equal? reader-calls 2))

(test-case "terminal runner sources use only the checked driver boundary"
  (define gel-source (file->string gel-run-path))
  (define term-source (file->string term-run-path))
  (for ([source (in-list (list gel-source term-source))])
    (check-regexp-match #rx"driver-inject-host!" source)
    (check-regexp-match #rx"make-driver" source)
    (check-false
     (regexp-match?
      #rx"env-define!|eval-expr|make-top-level-env|parse-datum|read-program"
      source)))
  (check-regexp-match #rx"driver-load-file!" gel-source)
  (check-regexp-match #rx"driver-eval!" gel-source)
  (check-regexp-match #rx"driver-load-port!" term-source)
  (check-false (regexp-match? #rx"driver-load-file!" term-source))
  (for ([policy-name
         (in-list
          '(gel-handle-key gel-text key-value->string GelKey GelStep))])
    (check-false
     (regexp-match? (regexp (symbol->string policy-name)) gel-source))))

(test-case "Term runner usage exits two without opening a TTY"
  (define racket-path (find-executable-path "racket"))
  (check-not-false racket-path)
  (define-values (process stdout stdin stderr)
    (subprocess #f #f #f racket-path term-run-path))
  (close-output-port stdin)
  (subprocess-wait process)
  (check-equal? (subprocess-status process) 2)
  (check-equal? (port->string stdout) "")
  (check-equal?
   (port->string stderr)
   "usage: racket host/racket/term-run.rkt path.aloe\n"))

(test-case "ordinary drivers remain free of Term"
  (define state (make-driver))
  (check-false
   (env-bound? (driver-runtime-environment state) 'term))
  (check-false
   (type-environment-bound? (driver-type-environment state) 'term)))
