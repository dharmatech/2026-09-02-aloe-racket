#lang racket/base

(require racket/string racket/list
         rackunit
         "../../aloe/host.rkt"
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

;; Independent name and text allocation from the supplied fixture and size.
(define (mode-row name width)
  (define label (substring (string-append name " ") 0
                          (min width (add1 (string-length name)))))
  (list->string
    (for/list ([c (in-string (string-append label
                              (make-string (- width (string-length label)) #\-)))])
      (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (text-body body rows)
  (define lines (string-split body "\r\n" #:trim? #f))
  (string-join (take lines (min (length lines) (if (>= rows 3) (- rows 2) 1))) "\r\n"))
(define (frame body row rows label #:name [name "untitled"] #:width [width 0])
  (string-append "\e[?25l\e[2J\e[H"
    (if rows (text-body body rows) body)
    (format "\e[~a;~aH\e[?25h" row 1)
    (if (and rows (>= rows 2))
        (string-append "\e[?25l"
          (if (>= rows 3) (format "\e[~a;1H~a" (sub1 rows) (mode-row name width)) "")
          (format "\e[~a;1H~a\e[~a;~aH\e[?25h" rows label row 1)) "")))

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
                (list (frame "\r\n\r\n" 1 4 "untitled" #:name "untitled" #:width 8)))

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
                (list (frame "hello\r\nworld\r\n" 1 4 "/cwd/a.t" #:name "/cwd/a.txt" #:width 8))))

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
                (list (frame "zero\r\none\r\ntwo" 1 4 "/cwd/a.t" #:name "/cwd/a.txt" #:width 8)
                      (frame "zero\r\none\r\ntwo" 2 4 "/cwd/a.t" #:name "/cwd/a.txt" #:width 8)
                      (frame "one\r\ntwo" 2 4 "/cwd/a.t" #:name "/cwd/a.txt" #:width 8)
                      (frame "two\r\nthree" 2 4 "/cwd/a.t" #:name "/cwd/a.txt" #:width 8)
                      (frame "two\r\nthree" 1 4 "/cwd/a.t" #:name "/cwd/a.txt" #:width 8))))

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
                (list (frame "hello\r\n\r\n" 1 4 "/cwd/a.txt" #:name "/cwd/a.txt" #:width 20)
                      (frame "hello\r\n\r\n" 1 4 "saved: /cwd/a.txt" #:name "/cwd/a.txt" #:width 20)
                      (frame "hello\r\n\r\n" 1 4 "/cwd/a.txt" #:name "/cwd/a.txt" #:width 20)))
  (check-equal? (host-receiver-send fs 'read '("/cwd/a.txt")) "hello"))

(test-case "untitled key-save paints failure then clears"
  (define sizes (make-list 3 '(8 4)))
  (define keys '("save" "left" "escape"))
  (define-values (term events remaining calls)
    (make-scripted-term sizes keys))
  (define fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts term fs)
  (check-script events remaining calls sizes keys
                (list (frame "\r\n\r\n" 1 4 "untitled" #:name "untitled" #:width 8)
                      (frame "\r\n\r\n" 1 4 "failed: " #:name "untitled" #:width 8)
                      (frame "\r\n\r\n" 1 4 "untitled" #:name "untitled" #:width 8)))
  (check-equal? (host-receiver-send fs 'names '("/cwd")) '()))

(test-case "ineligible bound key-save paints failure and does not write"
  (define sizes (make-list 3 '(20 4)))
  (define keys '("save" "left" "escape"))
  (define-values (term events remaining calls)
    (make-scripted-term sizes keys))
  (define fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts term fs "absent/a.txt")
  (check-script events remaining calls sizes keys
                (list (frame "\r\n\r\n" 1 4 "/cwd/absent/a.txt" #:name "/cwd/absent/a.txt" #:width 20)
                      (frame "\r\n\r\n" 1 4 "failed: /cwd/absent/" #:name "/cwd/absent/a.txt" #:width 20)
                      (frame "\r\n\r\n" 1 4 "/cwd/absent/a.txt" #:name "/cwd/absent/a.txt" #:width 20)))
  (check-equal? (host-receiver-send fs 'names '("/cwd")) '()))
