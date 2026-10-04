#lang racket/base

(require racket/file
         racket/list
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/host.rkt"
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")

(define empty-frame
  "\u001b[?25l\u001b[2J\u001b[H\r\n\u001b[1;1H\u001b[?25h\u001b[?25l\u001b[3;1Huntitled\u001b[4;1Huntitled\u001b[1;1H\u001b[?25h")

(define loaded-x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\u001b[1;1H\u001b[?25h\u001b[?25l\u001b[3;1H/cwd/a.t\u001b[4;1H/cwd/a.t\u001b[1;1H\u001b[?25h")

(define inserted-x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\u001b[1;2H\u001b[?25h\u001b[?25l\u001b[3;1H/cwd/new\u001b[4;1H/cwd/new\u001b[1;2H\u001b[?25h")

(define saved-x-frame
  "\u001b[?25l\u001b[2J\u001b[Hx\r\n\u001b[1;2H\u001b[?25h\u001b[?25l\u001b[3;1H/cwd/new\u001b[4;1Hsaved: /\u001b[1;2H\u001b[?25h")

(struct scripted-term
  (receiver remaining-keys key-calls size-calls events)
  #:transparent)

(define (make-tracked-output)
  (define events '())
  (define output
    (make-output-port
     'aloemacs-file-runner-output
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

(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define key-calls (box 0))
  (define size-calls (box 0))
  (define-values (output events) (make-tracked-output))
  (scripted-term
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

(define (term-events fixture)
  ((scripted-term-events fixture)))

(define (expected-events . frames)
  (append-map (lambda (frame)
                (list (string->bytes/utf-8 frame) 'flush))
              frames))

(define (fs-send fs-host selector . arguments)
  (host-receiver-send fs-host selector arguments))

(define (check-term-observations fixture keys sizes frames)
  (check-equal? (unbox (scripted-term-key-calls fixture)) keys)
  (check-equal? (unbox (scripted-term-size-calls fixture)) sizes)
  (check-equal? (term-events fixture) (apply expected-events frames)))

(test-case "pathless host-aware run stays empty, untitled, and filesystem-free"
  (define term (make-scripted-term '("escape")))
  (define fs-host
    (make-fs-double
     "/cwd"
     (hash "/cwd" 'directory "/cwd/planted.txt" 'file)
     (hash "/cwd/planted.txt" "planted")))
  (define names-before (fs-send fs-host 'names "/cwd"))

  (check-not-exn
   (lambda ()
     (run-aloemacs-with-hosts (scripted-term-receiver term) fs-host)))

  (check-equal? (unbox (scripted-term-remaining-keys term)) '())
  (check-term-observations term 1 2 (list empty-frame))
  (check-equal? (fs-send fs-host 'names "/cwd") names-before)
  (check-equal? (fs-send fs-host 'read "/cwd/planted.txt") "planted")
  (check-equal? (fs-send fs-host 'kind "/cwd/new.txt") "missing"))

(test-case "existing relative file is visited before the first frame"
  (define term (make-scripted-term '("escape")))
  (define fs-host
    (make-fs-double
     "/cwd"
     (hash "/cwd" 'directory "/cwd/a.txt" 'file)
     (hash "/cwd/a.txt" "x")))

  (check-not-exn
   (lambda ()
     (run-aloemacs-with-hosts
      (scripted-term-receiver term) fs-host "a.txt")))

  (check-equal? (unbox (scripted-term-remaining-keys term)) '())
  (check-term-observations term 1 2 (list loaded-x-frame))
  (check-equal? (fs-send fs-host 'read "/cwd/a.txt") "x"))

(test-case "missing startup path remains absent until a named save key"
  (define escape-term (make-scripted-term '("escape")))
  (define escape-fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts
   (scripted-term-receiver escape-term) escape-fs "new.txt")
  (check-term-observations escape-term 1 2
                           (list (string-replace empty-frame "untitled" "/cwd/new")))
  (check-equal? (fs-send escape-fs 'kind "/cwd/new.txt") "missing")
  (check-equal? (fs-send escape-fs 'names "/cwd") '())

  (define save-term (make-scripted-term '("x" "save" "escape")))
  (define save-fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts
   (scripted-term-receiver save-term) save-fs "new.txt")
  (check-equal? (unbox (scripted-term-remaining-keys save-term)) '())
  (check-term-observations
   save-term 3 6
   (list (string-replace empty-frame "untitled" "/cwd/new")
         inserted-x-frame saved-x-frame))
  (check-equal? (fs-send save-fs 'kind "/cwd/new.txt") "file")
  (check-equal? (fs-send save-fs 'read "/cwd/new.txt") "x")
  (check-equal? (fs-send save-fs 'names "/cwd") '("new.txt")))

(test-case "directory, symlink, and other startup nodes are refused before TTY use"
  (for ([path (in-list '("dir" "link" "pipe"))]
        [kind (in-list '(directory symlink "fifo"))])
    (define term (make-scripted-term '("escape")))
    (define absolute-path (string-append "/cwd/" path))
    (define fs-host
      (make-fs-double
       "/cwd"
       (hash "/cwd" 'directory
             "/cwd/kept.txt" 'file
             absolute-path kind)
       (hash "/cwd/kept.txt" "kept")))
    (define names-before (fs-send fs-host 'names "/cwd"))

    (check-exn
     (lambda (exception)
       (and (exn:fail? exception)
            (regexp-match? #rx"^aloemacs: cannot visit path:"
                           (exn-message exception))
            (regexp-match? (regexp (regexp-quote (format "~s" path)))
                           (exn-message exception))))
     (lambda ()
       (run-aloemacs-with-hosts
        (scripted-term-receiver term) fs-host path)))

    (check-equal? (unbox (scripted-term-remaining-keys term)) '("escape"))
    (check-term-observations term 0 0 '())
    (check-equal? (fs-send fs-host 'names "/cwd") names-before)
    (check-equal? (fs-send fs-host 'read "/cwd/kept.txt") "kept")
    (check-equal? (fs-send fs-host 'kind absolute-path)
                  (if (string? kind) kind (symbol->string kind)))))

(test-case "runner keeps visit, save policy, and editor behavior in checked Aloe"
  (define source (file->string runner-path))
  (for ([required
         (in-list
          '("make-driver"
            "driver-inject-host!"
            "driver-load-file!"
            "driver-eval!"
            "make-fs-receiver"
            "call-with-tty-term-receiver"
            "aloemacs-editor fs"
            "aloemacs-editor visit"
            "aloemacs-editor frame"
            "aloemacs-editor handle-key"
            "aloemacs-editor quit"))])
    (check-regexp-match (regexp (regexp-quote required)) source))
  (check-equal?
   (length (regexp-match* #rx"aloemacs-editor visit" source))
   1)
  (for ([forbidden
         (in-list
          '("\"save\""
            "(fs-host kind"
            "(fs-host inspect"
            "(fs-host read"
            "(fs-host write"
            "(Fs write"
            "(aloemacs-editor save)"
            "to-string"
            "AloemacsSession new"
            "AloemacsEditor new"
            "Text from-string"
            "Position new"
            "EditResult"
            "Span new"
            "write-line"
            "Mirror"
            "\\u001b"
            "env-define!"
            "eval-expr"
            "parse-datum"
            "read-program"
            "make-top-level-env"))])
    (check-false
     (regexp-match? (regexp (regexp-quote forbidden)) source)
     forbidden)))

(test-case "command-line over-arity reports usage without starting a TTY"
  (define input (open-input-string "must remain unread"))
  (define output (open-output-string))
  (define error-output (open-output-string))
  (define statuses '())

  (parameterize ([current-namespace (make-base-namespace)]
                 [current-command-line-arguments #("one" "two")]
                 [current-input-port input]
                 [current-output-port output]
                 [current-error-port error-output]
                 [exit-handler
                  (lambda (status)
                    (set! statuses (cons status statuses)))])
    (dynamic-require `(submod ,runner-path main) #f))

  (check-equal? (reverse statuses) '(2))
  (check-regexp-match #rx"usage" (get-output-string error-output))
  (check-equal? (get-output-string output) "")
  (check-equal? (file-position input) 0))
