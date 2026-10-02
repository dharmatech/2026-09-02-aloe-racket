#lang racket/base

(require racket/list
         rackunit
         "../../aloe/host.rkt"
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

;; Expected bytes are independent of the Aloe frame implementation.
(define (frame body row column rows label)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H" body
   (format "\u001b[~a;~aH\u001b[?25h" row column)
   (if (= rows 1) ""
       (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;~aH\u001b[?25h"
               rows label row column))))

(define spare-keys '("save" "x"))
(define (make-scripted-term sizes keys)
  (define remaining (box (append keys spare-keys)))
  (define calls (box 0))
  (define observed '())
  (define (record! event) (set! observed (cons event observed)))
  (define output
    (make-output-port
     'keymap-runner always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (record! (if (= start end) 'flush
                    (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
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
      (record! (list (if (even? call) 'columns 'rows)
                     (if (even? call) (car size) (cadr size))))
      (set-box! calls (add1 call))
      (values (car size) (cadr size))))
   (lambda () (reverse observed)) remaining calls))

(define (tracked-fs nodes contents)
  (define inner (make-fs-double "/cwd" nodes contents))
  (define writes (box '()))
  (define (forward selector args)
    (when (eq? selector 'write)
      (set-box! writes (cons args (unbox writes))))
    (host-receiver-send inner selector args))
  (define interface
    (make-host-interface
     'FsHost
     (for/list ([method (in-list (host-interface-methods fs-interface))])
       (define selector (host-method-selector method))
       (define params (host-method-parameter-types method))
       (make-host-method
        selector params (host-method-return-type method)
        (case (length params)
          [(0) (lambda (state) (forward selector '()))]
          [(1) (lambda (state a) (forward selector (list a)))]
          [(2) (lambda (state a b) (forward selector (list a b)))])))))
  (values (make-host-receiver interface #f) writes inner))

(define (check-script events remaining calls sizes keys frames)
  ;; A quit must leave later keys unread, with no frame or size read after it.
  (check-equal? (unbox remaining) spare-keys)
  (check-equal? (unbox calls) (* 2 (length keys)))
  (check-equal?
   (events)
   (append-map
    (lambda (size key expected-frame)
      (list (list 'columns (car size)) (list 'rows (cadr size))
            (list 'write expected-frame) 'flush (list 'key key)))
    sizes keys frames)))

(test-case "plain x, prefix redraw and resize, save, consumed cancellations, and quit"
  (define sizes '((20 4) (20 4) (5 2) (20 4) (20 4) (20 4) (20 4) (20 4) (20 4)))
  (define keys '("x" "ctrl-x" "save" "left" "ctrl-x" "x" "ctrl-x" "escape" "escape"))
  (define-values (term events remaining calls) (make-scripted-term sizes keys))
  (define-values (fs writes inner)
    (tracked-fs (hash "/cwd" 'directory "/cwd/a.txt" 'file)
                (hash "/cwd/a.txt" "abcdef\nsecond\nthird\nfourth")))
  (run-aloemacs-with-hosts term fs "a.txt")
  (check-script events remaining calls sizes keys
    (list (frame "abcdef\r\nsecond\r\nthird" 1 1 4 "/cwd/a.txt")
          (frame "xabcdef\r\nsecond\r\nthird" 1 2 4 "/cwd/a.txt")
          (frame "xabcd" 1 2 2 "/cwd/")
          (frame "xabcdef\r\nsecond\r\nthird" 1 2 4 "saved: /cwd/a.txt")
          (frame "xabcdef\r\nsecond\r\nthird" 1 1 4 "/cwd/a.txt")
          (frame "xabcdef\r\nsecond\r\nthird" 1 1 4 "/cwd/a.txt")
          (frame "xabcdef\r\nsecond\r\nthird" 1 1 4 "/cwd/a.txt")
          (frame "xabcdef\r\nsecond\r\nthird" 1 1 4 "/cwd/a.txt")
          (frame "xabcdef\r\nsecond\r\nthird" 1 1 4 "/cwd/a.txt")))
  (check-equal? (unbox writes) '(("/cwd/a.txt" "xabcdef\nsecond\nthird\nfourth")))
  (check-equal? (host-receiver-send inner 'read '("/cwd/a.txt"))
                "xabcdef\nsecond\nthird\nfourth"))

(test-case "armed resize fits before framing and preserves clipping, safe cells, and cursor bytes"
  (define sizes '((8 3) (8 3) (8 3) (2 2) (8 3) (8 3) (8 3)))
  (define keys '("right" "right" "ctrl-x" "save" "ctrl-x" "return" "escape"))
  (define-values (term events remaining calls) (make-scripted-term sizes keys))
  (define-values (fs writes inner)
    (tracked-fs (hash "/cwd" 'directory "/cwd/a.txt" 'file)
                (hash "/cwd/a.txt" "a\u001bb\nc\rd")))
  (run-aloemacs-with-hosts term fs "a.txt")
  (check-script events remaining calls sizes keys
    (list (frame "a b\r\nc d" 1 1 3 "/cwd/a.t")
          (frame "a b\r\nc d" 1 2 3 "/cwd/a.t")
          (frame "a b\r\nc d" 1 3 3 "/cwd/a.t")
          (frame " b" 1 2 2 "/c")
          (frame " b\r\n d" 1 2 3 "saved: /")
          (frame " b\r\n d" 1 2 3 "/cwd/a.t")
          (frame " b\r\n d" 1 2 3 "/cwd/a.t")))
  (check-equal? (unbox writes) '(("/cwd/a.txt" "a\u001bb\nc\rd")))
  (check-equal? (host-receiver-send inner 'read '("/cwd/a.txt")) "a\u001bb\nc\rd"))

(test-case "one-row runner saves and consumes cancellation without any echo suffix"
  (define keys '("x" "ctrl-x" "save" "ctrl-x" "x" "save" "escape"))
  (define sizes (make-list (length keys) '(2 1)))
  (define-values (term events remaining calls) (make-scripted-term sizes keys))
  (define-values (fs writes inner)
    (tracked-fs (hash "/cwd" 'directory "/cwd/a.txt" 'file)
                (hash "/cwd/a.txt" "ab")))
  (run-aloemacs-with-hosts term fs "a.txt")
  (check-script events remaining calls sizes keys
                (cons (frame "ab" 1 1 1 "") (make-list 6 (frame "xa" 1 2 1 ""))))
  (check-equal? (unbox writes) '(("/cwd/a.txt" "xab") ("/cwd/a.txt" "xab"))))

(test-case "untitled and ineligible prefix saves show failure and retain zero writes"
  (for ([path (in-list '(#f "absent/a.txt"))]
        [label (in-list '("untitled" "/cwd/absent/a.txt"))]
        [failure (in-list '("failed: untitled" "failed: /cwd/absent/"))])
    (define keys '("ctrl-x" "save" "left" "ctrl-x" "escape" "escape"))
    (define sizes (make-list (length keys) '(20 4)))
    (define-values (term events remaining calls) (make-scripted-term sizes keys))
    (define-values (fs writes inner) (tracked-fs (hash "/cwd" 'directory) (hash)))
    (run-aloemacs-with-hosts term fs path)
    (check-script events remaining calls sizes keys
      (list (frame "\r\n\r\n" 1 1 4 label)
            (frame "\r\n\r\n" 1 1 4 label)
            (frame "\r\n\r\n" 1 1 4 failure)
            (frame "\r\n\r\n" 1 1 4 label)
            (frame "\r\n\r\n" 1 1 4 label)
            (frame "\r\n\r\n" 1 1 4 label)))
    (check-equal? (unbox writes) '())))
