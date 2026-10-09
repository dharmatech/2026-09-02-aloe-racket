#lang racket/base

(require racket/string racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt"
         "../../aloe/host.rkt")

(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")

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
;; One-view name rows are the LIGHT bar; an empty row stays empty.
(define LIGHT "\e[38;5;16;48;5;250m")
(define PLAIN "\e[0m")
(define (light row) (if (string=? row "") "" (string-append LIGHT row PLAIN)))
(define (complete-frame body row column [label ""] [echo-row 5]
                        #:name [name "/cwd/a.txt"] #:width [width 8])
  (string-append "\e[?25l\e[2J\e[H" (text-body body echo-row)
    (format "\e[~a;~aH\e[?25h" row column)
    (format "\e[?25l\e[~a;1H~a\e[~a;1H~a\e[~a;~aH\e[?25h"
      (sub1 echo-row) (light (mode-row name width)) echo-row label row column)))

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
                          "aloemacs-editor record-pictures"
                          "aloemacs-editor frame"
                          "(term write" "(term read-key)"))])
    (check-equal? (length (positions phrase)) 1 phrase))
  (define (start phrase) (caar (positions phrase)))
  (check-true (< (start "(term columns)")
                 (start "(term rows)")
                 (start "aloemacs-editor ensure-visible")
                 (start "aloemacs-editor record-pictures")
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
                (list (complete-frame "\r\n" 1 1 "" 4 #:name "untitled")) keys)

  (define visited (make-scripted-term sizes keys))
  (define fs (file-double "hello\nworld"))
  (run-aloemacs-with-hosts (scripted-term-receiver visited) fs "a.txt")
  (check-script visited sizes
                (list (complete-frame "hello\r\nworld\r\n" 1 1 "" 4))
                keys)
  (check-equal? (host-receiver-send fs 'read '("/cwd/a.txt"))
                "hello\nworld"))

(test-case "Down to last screen row then Up holds the complete frame body"
  (define source "zero\none\ntwo\nthree\nfour\nfive")
  (define keys '("down" "down" "down" "up" "escape"))
  (define sizes (make-list (length keys) '(8 5)))
  (define top-body "zero\r\none\r\ntwo\r\nthree")
  (define frames
    (for/list ([body '("zero\r\none\r\ntwo" "zero\r\none\r\ntwo"
                      "zero\r\none\r\ntwo" "one\r\ntwo\r\nthree" "one\r\ntwo\r\nthree")]
               [row '(1 2 3 3 2)])
      (complete-frame body row 1)))
  (define fixture (make-scripted-term sizes keys))
  (run-aloemacs-with-hosts (scripted-term-receiver fixture)
                           (file-double source) "a.txt")
  (check-script fixture sizes frames keys)
  (check-equal? (list-ref frames 3)
                "\u001b[?25l\u001b[2J\u001b[Hone\r\ntwo\r\nthree\u001b[3;1H\u001b[?25h\u001b[?25l\u001b[4;1H\u001b[38;5;16;48;5;250m/cwd/a.t\u001b[0m\u001b[5;1H\u001b[3;1H\u001b[?25h")
  (check-equal? (list-ref frames 4)
                "\u001b[?25l\u001b[2J\u001b[Hone\r\ntwo\r\nthree\u001b[2;1H\u001b[?25h\u001b[?25l\u001b[4;1H\u001b[38;5;16;48;5;250m/cwd/a.t\u001b[0m\u001b[5;1H\u001b[2;1H\u001b[?25h"))

(test-case "vertical shrink shifts only on exit and growth holds the origin"
  (define keys '("down" "down" "down" "f1" "up" "f1" "escape"))
  (define sizes '((8 5) (8 5) (8 5) (8 5)
                  (8 4) (8 3) (8 6)))
  (define top-body "zero\r\none\r\ntwo\r\nthree")
  (define frames
    (append
     (for/list ([body (list top-body top-body top-body "one\r\ntwo\r\nthree")]
                [row '(1 2 3 3)])
       (complete-frame body row 1))
     (list (complete-frame "two\r\nthree" 2 1 "" 4)
           (complete-frame "two" 1 1 "" 3)
           (complete-frame "two\r\nthree\r\nfour\r\nfive" 1 1 "" 6))))
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
       (complete-frame "01234567\r\nabcdefgh" 1 column "" 3))
     (list (complete-frame "3456" 1 4 "" 3 #:width 4)
           (complete-frame "3456789\r\ndefghij" 1 4 "" 3))))
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
