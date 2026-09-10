#lang racket/base

(require racket/file
         racket/port
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

(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-point-path "../examples/gel-point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")
(define-runtime-path term-run-path "../host/racket/term-run.rkt")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

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

(define (make-gel-driver keys)
  (define-values (term terminal-output reader-calls)
    (make-scripted-term keys))
  (define state (make-driver))
  (define load-output (open-output-string))
  (driver-inject-host! state 'term term)
  (check-equal? (driver-load-file! state gel-main-path load-output) '())
  (values state terminal-output load-output reader-calls))

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
   "\r\n"
   "key q\r\n"))

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
   "\r\n"
   "key q\r\n"))

(test-case "fresh drivers have no Gel application or optional host bindings"
  (define state (make-driver))
  (for ([name (in-list '(term fs-host gel-start-value GelMain))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))

(test-case "GelMain.start is generic and preserves the empty stack"
  (define-values (state terminal-output load-output reader-calls)
    (make-gel-driver '("q")))
  (check-equal? (driver-type-datum state '(gel-main start 10)) 'GelStack)
  (driver-eval!
   state
   '(define checkpoint-108-int-stack
      (gel-main start 10)))

  (check-equal?
   (driver-eval! state '((checkpoint-108-int-stack items) len))
   1)
  (check-equal?
   (driver-eval! state '((checkpoint-108-int-stack tos) subject))
   10)
  (check-equal? (driver-eval! state '((gel-empty-stack items) len)) 0)
  (check-equal? (get-output-string terminal-output) int-transcript)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 1))

(test-case "separate Gel sessions infer unrelated start types"
  (define-values (state terminal-output load-output reader-calls)
    (make-gel-driver '("q")))
  (check-equal?
   (driver-type-datum state '(gel-main start "hello"))
   'GelStack)
  (driver-eval!
   state
   '(define checkpoint-108-string-stack
      (gel-main start "hello")))
  (check-equal?
   (driver-eval! state '((checkpoint-108-string-stack tos) subject))
   "hello")
  (check-equal?
   (driver-eval! state '((checkpoint-108-string-stack items) len))
   1)
  (check-regexp-match #rx"^TOS: \"hello\"" (get-output-string terminal-output))
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 1))

(test-case "GelMain.call remains the lower-level assembled-stack entry"
  (define-values (state terminal-output load-output reader-calls)
    (make-gel-driver '("q")))
  (driver-eval!
   state
   '(define checkpoint-108-assembled
      ((gel-empty-stack push 1) push "two")))
  (define assembled
    (driver-eval! state 'checkpoint-108-assembled))
  (driver-eval!
   state
   '(define checkpoint-108-called
      (gel-main call checkpoint-108-assembled)))
  (define called
    (driver-eval! state 'checkpoint-108-called))

  (check-eq? called assembled)
  (check-equal? (driver-eval! state '((checkpoint-108-called items) len)) 2)
  (check-equal?
   (driver-eval! state '((checkpoint-108-called tos) subject))
   "two")
  (check-equal?
   (driver-eval!
    state
    '((((checkpoint-108-called items) rest) first) subject))
   1)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 1))

(test-case "the Point application supplies the checked generic start value"
  (define-values (state terminal-output load-output reader-calls)
    (make-gel-driver '("q")))
  (check-equal? (driver-load-file! state gel-point-path load-output) '())
  (check-equal? (driver-type-datum state 'gel-start-value) '(Point Int))
  (check-equal?
   (driver-type-datum state '(gel-main start gel-start-value))
   'GelStack)
  (define start-value (driver-eval! state 'gel-start-value))
  (driver-eval!
   state
   '(define checkpoint-108-point-stack
      (gel-main start gel-start-value)))
  (check-equal? (driver-eval! state '((checkpoint-108-point-stack items) len)) 1)
  (check-eq?
   (driver-eval! state '((checkpoint-108-point-stack tos) subject))
   start-value)
  (check-equal? (get-output-string terminal-output) point-transcript)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 1))

(test-case "the Point application owns only its class load and start binding"
  (define source (file->string gel-point-path))
  (check-equal?
   source
   (string-append
    "(load \"point.aloe\")\n\n"
    "(define gel-start-value\n"
    "  (Point new 10 20))\n"))
  (check-false
   (regexp-match?
    #rx"term|GelStack|gel-empty-stack|gel-main|#lang|require|lambda"
    source)))

(test-case "the Gel runner keeps one checked generic application launch"
  (define source (file->string gel-run-path))
  (check-regexp-match #rx"\\(define state \\(make-driver\\)\\)" source)
  (check-regexp-match
   #px"driver-load-file! state gel-main-path\\)\\s*\\(driver-load-file! state path\\)\\s*\\(driver-eval!\\s*state\\s*'\\(gel-main start gel-start-value\\)\\)"
   source)
  (check-regexp-match #rx"driver-inject-host! state 'term term" source)
  (for ([forbidden
         (in-list
          '("Point"
            "point-path"
            "fs-host"
            "env-define!"
            "eval-expr"
            "make-top-level-env"
            "parse-datum"
            "read-program"
            "driver-load-port!"
            "gel-handle-key"
            "gel-text"
            "GelKey"
            "GelStep"))])
    (check-false
     (regexp-match? (regexp (regexp-quote forbidden)) source)
     forbidden)))

(define (check-runner-usage arguments)
  (define racket-path (find-executable-path "racket"))
  (check-not-false racket-path)
  (define-values (process stdout stdin stderr)
    (apply subprocess #f #f #f racket-path gel-run-path arguments))
  (close-output-port stdin)
  (subprocess-wait process)
  (check-equal? (subprocess-status process) 2)
  (check-equal? (port->string stdout) "")
  (check-equal?
   (port->string stderr)
   "usage: racket host/racket/gel-run.rkt path.aloe\n"))

(test-case "the Gel runner rejects invalid arity before opening a TTY"
  (check-runner-usage '())
  (check-runner-usage '("one.aloe" "two.aloe")))

(test-case "a missing start binding is an ordinary checked Aloe failure"
  (define application-path
    (make-temporary-file "checkpoint-108-~a.aloe" #f "/tmp"))
  (dynamic-wind
   void
   (lambda ()
     (call-with-output-file application-path
       (lambda (output)
         (display "(define some-other-value 10)\n" output))
       #:exists 'truncate)
     (define-values (state _terminal-output load-output _reader-calls)
       (make-gel-driver '("q")))
     (check-equal? (driver-load-file! state application-path load-output) '())
     (check-exn
      #rx"unbound symbol: gel-start-value"
      (lambda ()
        (driver-eval! state '(gel-main start gel-start-value))))
     (check-equal? (get-output-string load-output) ""))
   (lambda ()
     (when (file-exists? application-path)
       (delete-file application-path)))))

(test-case "existing host boundaries and default drivers remain unchanged"
  (check-equal?
   (map host-method-selector (host-interface-methods term-interface))
   '(read-key write-line))
  (check-equal?
   (map host-method-selector (host-interface-methods fs-interface))
   '(current resolve child root? parent name kind names))
  (check-false
   (regexp-match? #rx"gel-start-value|GelMain|fs-host"
                  (file->string term-run-path)))
  (define state (make-driver))
  (for ([name (in-list '(term fs-host gel-start-value GelMain))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))
