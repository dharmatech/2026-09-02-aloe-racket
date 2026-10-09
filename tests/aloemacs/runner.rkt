#lang racket/base

(require racket/file
         racket/port
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt"
         "../../host/racket/aloemacs-run.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")

(define expected-main-datums
  '((load "file.aloe")
    (define aloemacs-editor
      (let ((initial-buffer
              (AloemacsBuffer new*
                (editor
                  (AloemacsEditor new*
                    (text (Text from-string ""))
                    (point (Position new 0 0))
                    (quit #f)
                    (scroll-row 0)
                    (scroll-col 0)
                    (history (List empty))
                    (mark
                      (if #t
                          (Option None)
                          (Option Some (Position new 0 0))))
                    (text-rows 0)))
                (path
                  (if #t
                      (Option None)
                      (Option Some (Path new "/typed-none"))))
                (id 0)))
            (inactive-prompt
              (if #t
                  (Option None)
                  (Option Some
                    (AloemacsPrompt new*
                      (label "")
                      (text "")
                      (column 0)
                      (completion-note "")
                      (completion-lines (List empty))
                      (completion-matches (List empty))
                      (completion-start 0)))))
            (initial-windows
              (AloemacsWindows new*
                (tree
                  (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f (Option None))))
                (selected 0)
                (columns 0)
                (rows 0))))
        (let ((initial-buffers
                (AloemacsBuffers new*
                  (before (List empty))
                  (current-buffer initial-buffer)
                  (after (List empty))))
              (initial-pending
                (if #t
                    (Option None)
                    (Option Some aloemacs-global-keymap)))
              (initial-last-submission
                (if #t
                    (Option None)
                    (Option Some "")))
              (initial-waiting-command
                (if #t
                    (Option None)
                    (Option Some (AloemacsCommand FindFile)))))
          (AloemacsSession new*
            (buffers initial-buffers)
            (fs (Fs new fs-host))
            (echo "")
            (searching #f)
            (query "")
            (origin (Position new 0 0))
            (wrapped #f)
            (failing #f)
            (kill-ring (List empty))
            (pending initial-pending)
            (prompt inactive-prompt)
            (last-submission initial-last-submission)
            (waiting-command initial-waiting-command)
            (windows initial-windows)))))))

(define empty-frame
  "\u001b[?25l\u001b[2J\u001b[H\r\n\u001b[1;1H\u001b[?25h\u001b[?25l\u001b[3;1H\u001b[38;5;16;48;5;250muntitled\u001b[0m\u001b[4;1H\u001b[1;1H\u001b[?25h")

(define x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\u001b[1;2H\u001b[?25h\u001b[?25l\u001b[3;1H\u001b[38;5;16;48;5;250muntitled\u001b[0m\u001b[4;1H\u001b[1;2H\u001b[?25h")

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
  (define fs-host
    (make-fs-double
     "/cwd"
     (hash "/cwd" 'directory "/cwd/kept.txt" 'file)
     (hash "/cwd/kept.txt" "kept")))
  (for ([name (in-list
               '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsSession AloemacsEditor Text Fs Path Option
                 aloemacs-editor))])
    (check-true (unbound-in-driver? state name))
    (check-true (unbound-in-driver? fresh-state name)))
  (driver-inject-host! state 'fs-host fs-host)
  (check-true (unbound-in-driver? state 'term))

  (define load-output (open-output-string))
  (check-equal? (driver-load-file! state main-path load-output) '())
  (check-equal? (get-output-string load-output) "")
  (for ([name (in-list
               '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsSession AloemacsEditor Text Fs Path Option
                 aloemacs-editor))])
    (check-true (bound-in-driver? state name))
    (check-true (unbound-in-driver? fresh-state name)))
  (check-equal? (driver-type state 'aloemacs-editor)
                '(AloemacsSession FsHost))
  (check-equal?
   (driver-eval! state '((aloemacs-editor text) to-string))
   "")
  (check-equal? (driver-eval! state '((aloemacs-editor point) line)) 0)
  (check-equal? (driver-eval! state '((aloemacs-editor point) column)) 0)
  (check-false (driver-eval! state '(aloemacs-editor quit)))
  (check-false (driver-eval! state '((aloemacs-editor path) present?)))
  (check-false (driver-eval! state '((aloemacs-editor pending) present?)))
  (check-false (driver-eval! state '((aloemacs-editor prompt) present?)))
  (check-false (driver-eval! state '((aloemacs-editor last-submission) present?)))
  (check-false (driver-eval! state '((aloemacs-editor waiting-command) present?)))
  (check-equal? (driver-eval! state '(aloemacs-editor echo)) "")
  (check-equal? (driver-eval! state '(fs-host read "/cwd/kept.txt"))
                "kept")
  (check-equal? (driver-eval! state '((fs-host names "/cwd") len)) 1)
  (check-equal? (driver-eval! state '((fs-host names "/cwd") first))
                "kept.txt")
  (check-true (unbound-in-driver? state 'term)))

(test-case "main requires explicit fs-host injection"
  (define state (make-driver))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-load-file! state main-path))))

(test-case "runner exports the three entry procedures at their exact arities"
  (check-true (procedure? run-aloemacs))
  (check-true (procedure-arity-includes? run-aloemacs 0))
  (check-true (procedure-arity-includes? run-aloemacs 1))
  (check-false (procedure-arity-includes? run-aloemacs 2))
  (check-true (procedure? run-aloemacs-with-term))
  (check-true (procedure-arity-includes? run-aloemacs-with-term 1))
  (check-true (procedure-arity-includes? run-aloemacs-with-term 2))
  (check-false (procedure-arity-includes? run-aloemacs-with-term 0))
  (check-false (procedure-arity-includes? run-aloemacs-with-term 3))
  (check-true (procedure? run-aloemacs-with-hosts))
  (check-true (procedure-arity-includes? run-aloemacs-with-hosts 2))
  (check-true (procedure-arity-includes? run-aloemacs-with-hosts 3))
  (check-false (procedure-arity-includes? run-aloemacs-with-hosts 1))
  (check-false (procedure-arity-includes? run-aloemacs-with-hosts 4)))

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
            "driver-prepare!"
            "call-with-tty-term-receiver"
            "make-fs-receiver"
            "run-aloemacs-with-hosts"))])
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
            "\"save\""
            "\"escape\""
            "\"backspace\""
            "\"left\""
            "\"right\""
            "\"up\""
            "\"down\""))])
    (check-false
     (regexp-match? (regexp (regexp-quote forbidden)) source)
     forbidden))
  (for ([forbidden
         (in-list
          '("\\(fs-host (?:kind|inspect|read|write)"
            "\\(aloemacs-editor save\\)"
            "\\(.*text.*to-string"
            "\\(AloemacsSession new"
            "\\(Text from-string"
            "\\(Position new"))])
    (check-false (regexp-match? (pregexp forbidden) source) forbidden)))
