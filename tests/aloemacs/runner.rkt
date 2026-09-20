#lang racket/base

(require racket/file
         racket/port
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../../host/racket/term.rkt"
         "../../host/racket/aloemacs-run.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")

(define expected-main-datums
  '((load "editor.aloe")
    (define aloemacs-editor
      (AloemacsEditor new
        (Text from-string "")
        (Position new 0 0)
        #f))))

(define empty-frame
  "\u001b[?25l\u001b[2J\u001b[H\r\n\r\n\r\n\u001b[1;1H\u001b[?25h")

(define x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\r\n\r\n\u001b[1;2H\u001b[?25h")

(define (source-datums path)
  (call-with-input-file path
    (lambda (input)
      (port->list read input))))

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (bound-in-driver? state name)
  (and (env-bound? (driver-runtime-environment state) name)
       (type-environment-bound? (driver-type-environment state) name)))

(define (unbound-in-driver? state name)
  (and (not (env-bound? (driver-runtime-environment state) name))
       (not (type-environment-bound?
             (driver-type-environment state)
             name))))

(define (make-tracked-output)
  (define events '())
  (define output
    (make-output-port
     'aloemacs-runner-output
     always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (set! events
             (cons
              (if (= start end)
                  'flush
                  (subbytes bytes start end))
              events))
       (- end start))
     void))
  (values output (lambda () (reverse events))))

(define (event-output events)
  (bytes->string/utf-8
   (apply bytes-append
          (for/list ([event (in-list events)]
                     #:when (bytes? event))
            event))))

(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define key-calls (box 0))
  (define size-calls (box 0))
  (define-values (output events) (make-tracked-output))
  (values
   (make-term-receiver
    output
    (lambda ()
      (define remaining (unbox remaining-keys))
      (unless (pair? remaining)
        (error 'scripted-term "key script exhausted"))
      (set-box! remaining-keys (cdr remaining))
      (set-box! key-calls (add1 (unbox key-calls)))
      (car remaining))
    (lambda ()
      (set-box! size-calls (add1 (unbox size-calls)))
      (values 8 4)))
   remaining-keys
   key-calls
   size-calls
   events))

(test-case "main has exactly the source-relative load and empty starting state"
  (check-equal? (source-datums main-path) expected-main-datums))

(test-case "main loads an exact checked starting state into only one driver"
  (define state (make-driver))
  (define fresh-state (make-driver))
  (for ([name (in-list '(AloemacsEditor Text aloemacs-editor))])
    (check-true (unbound-in-driver? state name))
    (check-true (unbound-in-driver? fresh-state name)))

  (define load-output (open-output-string))
  (check-equal? (driver-load-file! state main-path load-output) '())
  (check-equal? (get-output-string load-output) "")
  (for ([name (in-list '(AloemacsEditor Text aloemacs-editor))])
    (check-true (bound-in-driver? state name))
    (check-true (unbound-in-driver? fresh-state name)))
  (check-equal? (driver-type state 'aloemacs-editor) 'AloemacsEditor)
  (check-equal?
   (driver-eval! state '((aloemacs-editor text) to-string))
   "")
  (check-equal? (driver-eval! state '((aloemacs-editor point) line)) 0)
  (check-equal? (driver-eval! state '((aloemacs-editor point) column)) 0)
  (check-false (driver-eval! state '(aloemacs-editor quit))))

(test-case "runner exports the two entry procedures at their exact arities"
  (check-true (procedure? run-aloemacs))
  (check-true (procedure-arity-includes? run-aloemacs 0))
  (check-false (procedure-arity-includes? run-aloemacs 1))
  (check-true (procedure? run-aloemacs-with-term))
  (check-true (procedure-arity-includes? run-aloemacs-with-term 1))
  (check-false (procedure-arity-includes? run-aloemacs-with-term 0))
  (check-false (procedure-arity-includes? run-aloemacs-with-term 2)))

(test-case "escape writes and flushes one initial frame before stopping"
  (define-values (term remaining key-calls size-calls events)
    (make-scripted-term '("escape")))
  (check-not-exn (lambda () (run-aloemacs-with-term term)))
  (check-equal? (unbox remaining) '())
  (check-equal? (unbox key-calls) 1)
  (check-equal? (unbox size-calls) 2)
  (check-equal? (events)
                (list (string->bytes/utf-8 empty-frame) 'flush))
  (check-equal? (event-output (events)) empty-frame))

(test-case "edit then escape iterates, rebinds, and stops without a third frame"
  (define-values (term remaining key-calls size-calls events)
    (make-scripted-term '("x" "escape")))
  (check-not-exn (lambda () (run-aloemacs-with-term term)))
  (check-equal? (unbox remaining) '())
  (check-equal? (unbox key-calls) 2)
  (check-equal? (unbox size-calls) 4)
  (check-equal?
   (events)
   (list (string->bytes/utf-8 empty-frame)
         'flush
         (string->bytes/utf-8 x-frame)
         'flush))
  (check-equal? (event-output (events)) (string-append empty-frame x-frame)))

(test-case "runner source stays on the checked thin-skin boundary"
  (define source (file->string runner-path))
  (for ([required
         (in-list
          '("make-driver"
            "driver-inject-host!"
            "driver-load-file!"
            "driver-eval!"
            "call-with-tty-term-receiver"))])
    (check-regexp-match (regexp required) source))
  (for ([forbidden
         (in-list
          '("env-define!"
            "eval-expr"
            "parse-datum"
            "read-program"
            "make-top-level-env"
            "write-line"
            "AloemacsEditor new"
            "Text from-string"
            "Position new"
            "EditResult"
            "Span new"
            "Mirror"
            "\\u001b"
            "escape"
            "backspace"
            "left"
            "right"
            "up"
            "down"))])
    (check-false
     (regexp-match? (regexp (regexp-quote forbidden)) source)
     forbidden)))
