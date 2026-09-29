#lang racket/base

(require racket/list
         rackunit
         "../../aloe/host.rkt"
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define (frame body cursor-row echo-row label)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   body
   (format "\u001b[~a;1H\u001b[?25h" cursor-row)
   (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;1H\u001b[?25h"
           echo-row label cursor-row)))

(define (make-scripted-term sizes keys)
  (define remaining (box keys))
  (define calls (box 0))
  (define observed '())
  (define (record! event) (set! observed (cons event observed)))
  (define output
    (make-output-port
     'echo-test always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (record! (if (= start end)
                    'flush
                    (list 'write
                          (bytes->string/utf-8 (subbytes bytes start end)))))
       (- end start))
     void))
  (values
   (make-term-receiver
    output
    (lambda ()
      (define key (car (unbox remaining)))
      (set-box! remaining (cdr (unbox remaining)))
      (record! (list 'key key))
      key)
    (lambda ()
      (define call (unbox calls))
      (define size (list-ref sizes (quotient call 2)))
      (define dimension (if (even? call) (car size) (cadr size)))
      (record! (list (if (even? call) 'columns 'rows) dimension))
      (set-box! calls (add1 call))
      (values (car size) (cadr size))))
   (lambda () (reverse observed))
   remaining
   calls))

(define (check-script events remaining calls sizes keys frames)
  (check-equal? (unbox remaining) '())
  (check-equal? (unbox calls) (* 2 (length keys)))
  (check-equal?
   (events)
   (append-map
    (lambda (size key expected-frame)
      (list (list 'columns (car size))
            (list 'rows (cadr size))
            (list 'write expected-frame)
            'flush
            (list 'key key)))
    sizes keys frames)))

(test-case "first untitled and visited frames use one write at full Term size"
  (define sizes '((8 4)))
  (define keys '("escape"))
  (define-values (untitled events remaining calls)
    (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts
   untitled (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (check-script events remaining calls sizes keys
                (list (frame "\r\n\r\n" 1 4 "untitled")))

  (define-values (visited visited-events visited-remaining visited-calls)
    (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts
   visited
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file)
    (hash "/cwd/a.txt" "hello\nworld"))
   "a.txt")
  (check-script visited-events visited-remaining visited-calls sizes keys
                (list (frame "hello\r\nworld\r\n" 1 4 "/cwd/a.t"))))

(test-case "runner fit reserves row four and scrolls after Down to line three"
  (define sizes (make-list 5 '(8 4)))
  (define keys '("down" "down" "down" "up" "escape"))
  (define-values (term events remaining calls)
    (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts
   term
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file)
    (hash "/cwd/a.txt" "zero\none\ntwo\nthree\nfour"))
   "a.txt")
  (check-script events remaining calls sizes keys
                (list (frame "zero\r\none\r\ntwo" 1 4 "/cwd/a.t")
                      (frame "zero\r\none\r\ntwo" 2 4 "/cwd/a.t")
                      (frame "zero\r\none\r\ntwo" 3 4 "/cwd/a.t")
                      (frame "one\r\ntwo\r\nthree" 3 4 "/cwd/a.t")
                      (frame "one\r\ntwo\r\nthree" 2 4 "/cwd/a.t"))))

(test-case "bound key-save paints success in one write until a non-save key"
  (define sizes (make-list 3 '(20 4)))
  (define keys '("save" "left" "escape"))
  (define-values (term events remaining calls)
    (make-scripted-term sizes keys))
  (define fs
    (make-fs-double
     "/cwd"
     (hash "/cwd" 'directory "/cwd/a.txt" 'file)
     (hash "/cwd/a.txt" "hello")))
  (run-aloemacs-with-hosts term fs "a.txt")
  (check-script events remaining calls sizes keys
                (list (frame "hello\r\n\r\n" 1 4 "/cwd/a.txt")
                      (frame "hello\r\n\r\n" 1 4 "saved: /cwd/a.txt")
                      (frame "hello\r\n\r\n" 1 4 "/cwd/a.txt")))
  (check-equal? (host-receiver-send fs 'read '("/cwd/a.txt")) "hello"))

(test-case "untitled key-save paints failure then clears"
  (define sizes (make-list 3 '(8 4)))
  (define keys '("save" "left" "escape"))
  (define-values (term events remaining calls)
    (make-scripted-term sizes keys))
  (define fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts term fs)
  (check-script events remaining calls sizes keys
                (list (frame "\r\n\r\n" 1 4 "untitled")
                      (frame "\r\n\r\n" 1 4 "failed: ")
                      (frame "\r\n\r\n" 1 4 "untitled")))
  (check-equal? (host-receiver-send fs 'names '("/cwd")) '()))

(test-case "ineligible bound key-save paints failure and does not write"
  (define sizes (make-list 3 '(20 4)))
  (define keys '("save" "left" "escape"))
  (define-values (term events remaining calls)
    (make-scripted-term sizes keys))
  (define fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts term fs "absent/a.txt")
  (check-script events remaining calls sizes keys
                (list (frame "\r\n\r\n" 1 4 "/cwd/absent/a.txt")
                      (frame "\r\n\r\n" 1 4 "failed: /cwd/absent/")
                      (frame "\r\n\r\n" 1 4 "/cwd/absent/a.txt")))
  (check-equal? (host-receiver-send fs 'names '("/cwd")) '()))
