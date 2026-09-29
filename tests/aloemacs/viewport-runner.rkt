#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt"
         "../../aloe/host.rkt")

(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")

(define (complete-frame body row column [label "/cwd/a.t"] [echo-row 5])
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   body
   (format "\u001b[~a;~aH\u001b[?25h" row column)
   (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;~aH\u001b[?25h"
           echo-row label row column)))

(struct scripted-term (receiver remaining-keys size-calls events) #:transparent)

(define (make-scripted-term sizes keys)
  (define remaining-keys (box keys))
  (define size-calls (box 0))
  (define recorded '())
  (define (record! event)
    (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'aloemacs-viewport-output
     always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (record!
        (if (= start end)
            'flush
            (list 'write
                  (bytes->string/utf-8 (subbytes bytes start end)))))
       (- end start))
     void))
  (define receiver
    (make-term-receiver
     output
     (lambda ()
       (define remaining (unbox remaining-keys))
       (unless (pair? remaining)
         (error 'scripted-term "key script exhausted"))
       (set-box! remaining-keys (cdr remaining))
       (record! (list 'key (car remaining)))
       (car remaining))
     (lambda ()
       (define call (unbox size-calls))
       (define iteration (quotient call 2))
       (unless (< iteration (length sizes))
         (error 'scripted-term "size script exhausted"))
       (define size (list-ref sizes iteration))
       (set-box! size-calls (add1 call))
       (record! (list (if (even? call) 'columns 'rows)
                      (if (even? call) (car size) (cadr size))))
       (values (car size) (cadr size)))))
  (scripted-term receiver remaining-keys size-calls
                 (lambda () (reverse recorded))))

(define (expected-events sizes frames keys)
  (append-map
   (lambda (size frame key)
     (list (list 'columns (car size))
           (list 'rows (cadr size))
           (list 'write frame)
           'flush
           (list 'key key)))
   sizes frames keys))

(define (check-script fixture sizes frames keys)
  (check-equal? (unbox (scripted-term-remaining-keys fixture)) '())
  (check-equal? (unbox (scripted-term-size-calls fixture))
                (* 2 (length frames)))
  (check-equal? ((scripted-term-events fixture))
                (expected-events sizes frames keys)))

(define (file-double source)
  (make-fs-double
   "/cwd"
   (hash "/cwd" 'directory "/cwd/a.txt" 'file)
   (hash "/cwd/a.txt" source)))

(test-case "runner source queries once, fits, frames, writes, then reads"
  (define source (file->string runner-path))
  (define (positions phrase)
    (regexp-match-positions* (regexp (regexp-quote phrase)) source))
  (for ([phrase (in-list '("(term columns)" "(term rows)"
                          "aloemacs-editor ensure-visible"
                          "aloemacs-editor frame"
                          "(term write" "(term read-key)"))])
    (check-equal? (length (positions phrase)) 1 phrase))
  (define (start phrase) (caar (positions phrase)))
  (check-true (< (start "(term columns)")
                 (start "(term rows)")
                 (start "aloemacs-editor ensure-visible")
                 (start "(term write")
                 (start "aloemacs-editor frame")
                 (start "(term read-key)"))))

(test-case "pathless and visited first frames precede the first key"
  (define sizes '((8 4)))
  (define keys '("escape"))
  (define pathless (make-scripted-term sizes keys))
  (define empty-fs (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (run-aloemacs-with-hosts (scripted-term-receiver pathless) empty-fs)
  (check-script pathless sizes
                (list (complete-frame "\r\n\r\n" 1 1 "untitled" 4)) keys)

  (define visited (make-scripted-term sizes keys))
  (define fs (file-double "hello\nworld"))
  (run-aloemacs-with-hosts (scripted-term-receiver visited) fs "a.txt")
  (check-script visited sizes
                (list (complete-frame "hello\r\nworld\r\n" 1 1 "/cwd/a.t" 4))
                keys)
  (check-equal? (host-receiver-send fs 'read '("/cwd/a.txt"))
                "hello\nworld"))

(test-case "Down to last screen row then Up holds the complete frame body"
  (define source "zero\none\ntwo\nthree\nfour\nfive")
  (define keys '("down" "down" "down" "up" "escape"))
  (define sizes (make-list (length keys) '(8 5)))
  (define top-body "zero\r\none\r\ntwo\r\nthree")
  (define frames
    (for/list ([row (in-list '(1 2 3 4 3))])
      (complete-frame top-body row 1)))
  (define fixture (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts (scripted-term-receiver fixture)
                           (file-double source) "a.txt")
  (check-script fixture sizes frames keys)
  (check-equal? (list-ref frames 3)
                "\u001b[?25l\u001b[2J\u001b[Hzero\r\none\r\ntwo\r\nthree\u001b[4;1H\u001b[?25h\u001b[?25l\u001b[5;1H/cwd/a.t\u001b[4;1H\u001b[?25h")
  (check-equal? (list-ref frames 4)
                "\u001b[?25l\u001b[2J\u001b[Hzero\r\none\r\ntwo\r\nthree\u001b[3;1H\u001b[?25h\u001b[?25l\u001b[5;1H/cwd/a.t\u001b[3;1H\u001b[?25h"))

(test-case "vertical shrink shifts only on exit and growth holds the origin"
  (define keys '("down" "down" "down" "f1" "up" "f1" "escape"))
  (define sizes '((8 5) (8 5) (8 5) (8 5)
                  (8 4) (8 3) (8 6)))
  (define top-body "zero\r\none\r\ntwo\r\nthree")
  (define frames
    (append
     (for/list ([row (in-list '(1 2 3 4))])
       (complete-frame top-body row 1))
     (list (complete-frame "one\r\ntwo\r\nthree" 3 1 "/cwd/a.t" 4)
           (complete-frame "one\r\ntwo" 2 1 "/cwd/a.t" 3)
           (complete-frame "one\r\ntwo\r\nthree\r\nfour\r\nfive" 2 1 "/cwd/a.t" 6))))
  (define fixture (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts
   (scripted-term-receiver fixture)
   (file-double "zero\none\ntwo\nthree\nfour\nfive") "a.txt")
  (check-script fixture sizes frames keys))

(test-case "width-only shrink shifts column; later growth keeps it"
  (define keys (append (make-list 6 "right") '("f1" "escape")))
  (define sizes (append (make-list 6 '(8 3)) '((4 3) (8 3))))
  (define frames
    (append
     (for/list ([column (in-range 1 7)])
       (complete-frame "01234567\r\nabcdefgh" 1 column "/cwd/a.t" 3))
     (list (complete-frame "3456\r\ndefg" 1 4 "/cwd" 3)
           (complete-frame "3456789\r\ndefghij" 1 4 "/cwd/a.t" 3))))
  (define fixture (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts
   (scripted-term-receiver fixture)
   (file-double "0123456789\nabcdefghij") "a.txt")
  (check-script fixture sizes frames keys))

(test-case "refused startup visit has no Term effects or consumed key"
  (for ([entry (in-list '(("dir" directory)
                         ("link" symlink)
                         ("pipe" "fifo")))])
    (define path (car entry))
    (define fixture (make-scripted-term '((8 4)) '("escape")))
    (define fs
      (make-fs-double
       "/cwd"
       (hash "/cwd" 'directory
             (string-append "/cwd/" path) (cadr entry))))
    (check-exn
     #rx"cannot visit path"
     (lambda ()
       (run-aloemacs-with-hosts
        (scripted-term-receiver fixture) fs path)))
    (check-equal? (unbox (scripted-term-remaining-keys fixture))
                  '("escape"))
    (check-equal? (unbox (scripted-term-size-calls fixture)) 0)
    (check-equal? ((scripted-term-events fixture)) '())))
