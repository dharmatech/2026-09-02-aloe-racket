#lang racket/base

(require racket/list racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (state)
  (define st (make-driver))
  (define calls (box '()))
  (define disk (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (define (forward selector args)
    (set-box! calls (cons (cons selector args) (unbox calls)))
    (host-receiver-send disk selector args))
  (define interface
    (make-host-interface 'FsHost
      (for/list ([m (in-list (host-interface-methods fs-interface))])
        (define selector (host-method-selector m))
        (make-host-method selector (host-method-parameter-types m)
          (host-method-return-type m)
          (case (length (host-method-parameter-types m))
            [(0) (lambda (_) (forward selector '()))]
            [(1) (lambda (_ a) (forward selector (list a)))]
            [(2) (lambda (_ a b) (forward selector (list a b)))])))))
  (driver-inject-host! st 'fs-host (make-host-receiver interface #f))
  (ev st `(load ,(path->string main-path)))
  (def! st 's '(aloemacs-editor with-editor
                (AloemacsEditor new ((Text from-string "abc\ndef") indexed-value)
                  (Position new 0 1) #f 0 0
                  (List of (UndoFrame new (Text from-string "old") (Position new 0 0) 0 0))
                  (Option Some (Position new 0 0)) 17)))
  (values st calls))

;; Independent expectations: supplied text, names, echo and cursor addresses.
(define (cursor row column) (format "\e[~a;~aH" row column))
(define (clip text width) (substring text 0 (min width (string-length text))))
(define (safe text)
  (list->string (for/list ([c (in-string text)])
    (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (mode name width)
  (define label (clip (string-append name " ") width))
  (safe (string-append label (make-string (- width (string-length label)) #\-))))
;; One-view name rows are the LIGHT bar; an empty row stays empty.
(define LIGHT "\e[38;5;16;48;5;250m")
(define PLAIN "\e[0m")
(define (light row) (if (string=? row "") "" (string-append LIGHT row PLAIN)))
;; Split name rows are bars: LIGHT on the selected view, DARK on the others.
(define DARK "\e[38;5;252;48;5;239m")
(define (painted row selected?)
  (if selected? (light row) (if (string=? row "") "" (string-append DARK row PLAIN))))
(define (single body width rows name echo [final-row 1] [final-column 2])
  (string-append "\e[?25l\e[2J\e[H" body (cursor 1 2) "\e[?25h"
    (if (< rows 2) ""
        (string-append "\e[?25l"
          (if (>= rows 3) (string-append (cursor (sub1 rows) 1) (light (mode name width))) "")
          (cursor rows 1) (safe (clip echo width))
          (cursor final-row final-column) "\e[?25h"))))
(define (multi lines width rows echo cursor-row)
  (string-append "\e[?25l\e[2J\e[H" (string-join lines "\r\n")
    (cursor rows 1) (safe (clip echo width)) (cursor cursor-row 2) "\e[?25h"))
(define (snapshot st s)
  (for/list ([expr (list s `(,s buffers) `((,s buffers) before)
                        `(,s current-buffer) `((,s buffers) after)
                        `(,s windows) `(,s text) `(,s echo))])
    (ev st expr)))
(define (paint st s width rows expected calls)
  (define before (snapshot st s))
  (define effects (unbox calls))
  (for ([i '(1 2)])
    (check-equal? (ev st `(,s frame ,width ,rows)) expected))
  (check-equal? (snapshot st s) before)
  (check-equal? (unbox calls) effects))

(test-case "tall untitled idle keeps mode line and echo address with an empty payload"
  (define-values (st calls) (state))
  (paint st 's 12 4 (single "abc\r\ndef" 12 4 "untitled" "") calls))

(test-case "tall bound idle keeps path on mode line only"
  (define-values (st calls) (state))
  (def! st 'bound '(s with-current-path (Path new "/cwd/a")))
  (paint st 'bound 12 4 (single "abc\r\ndef" 12 4 "/cwd/a" "") calls))

(test-case "height two keeps the untitled or bound idle name without a mode line"
  (define-values (st calls) (state))
  (paint st 's 12 2 (single "abc" 12 2 "untitled" "untitled") calls)
  (def! st 'bound '(s with-current-path (Path new "/cwd/a")))
  (paint st 'bound 12 2 (single "abc" 12 2 "/cwd/a" "/cwd/a") calls))

(test-case "height two still clips the idle name"
  (define-values (st calls) (state))
  (paint st 's 4 2 (single "abc" 4 2 "untitled" "unti") calls))

(test-case "height one has neither echo nor mode line"
  (define-values (st calls) (state))
  (paint st 's 12 1 (single "abc" 12 1 "untitled" "") calls))

(test-case "tall saved and failed messages keep the label and text cursor"
  (define-values (st calls) (state))
  (for ([name '("untitled" "/cwd/a")])
    (def! st 'bound (if (equal? name "untitled") 's `(s with-current-path (Path new ,name))))
    (for ([token '("saved" "failed")])
      (def! st 'status `(bound with-echo ,token))
      (paint st 'status 20 4
        (single "abc\r\ndef" 20 4 name (string-append token ": " name)) calls))))

(test-case "search precedence, safe cells and prompt cursor stay intact beside the mode line"
  (define-values (st calls) (state))
  (def! st 'status '(s with-echo "failed"))
  (for ([wrapped '(#f #t #t)] [failing '(#f #f #t)]
        [echo '("search: q " "wrapped: q " "failing: q ")])
    (def! st 'search `(status with-search (status editor) #t "q\t" (status origin) ,wrapped ,failing))
    (paint st 'search 20 4 (single "abc\r\ndef" 20 4 "untitled" echo) calls))
  (def! st 'prompt '(search with-active-prompt (AloemacsPrompt new "Ask: " "abcd" 2 "" (List empty) (List empty) 0)))
  (paint st 'prompt 20 4 (single "abc\r\ndef" 20 4 "untitled" "Ask: abcd" 4 8) calls))

(define (buffer id text name)
  `(AloemacsBuffer new
     (AloemacsEditor new ((Text from-string ,text) indexed-value) (Position new 0 1)
       #f 0 0 (List empty) (Option None) 17)
     (Option Some (Path new ,name)) ,id))
(define (leaf id buffer-id)
  `(AloemacsWindowTree Leaf (AloemacsView new ,id ,buffer-id 0 0 #f (Option None))))
(define (stacked! st selected)
  (def! st 'top (buffer 41 "top\nmore" "/top"))
  (def! st 'bottom (buffer 9 "bottom\nmore" "/bottom"))
  (def! st 'v
    `(AloemacsSession new
       ,(if (= selected 7)
            '(AloemacsBuffers new (List empty) top (List of bottom))
            '(AloemacsBuffers new (List of top) bottom (List empty)))
       (s fs) "" #f "" (s origin) #f #f (s kill-ring) (s pending)
       (s prompt) (s last-submission) (s waiting-command)
       (AloemacsWindows new (AloemacsWindowTree Below ,(leaf 7 41) ,(leaf 3 9))
         ,selected 80 24))))

(test-case "uneven split uses the selected leaf height and its buffer name"
  (define-values (st calls) (state))
  ;; A three-row root gives a two-row top leaf (text and bar) and a one-row
  ;; bottom leaf of text only.
  (define (lines selected) (list "top         " (painted (mode "/top" 12) (= selected 7))
                                 "bottom      "))
  (stacked! st 7)
  (paint st 'v 12 4 (multi (lines 7) 12 4 "" 1) calls)
  (stacked! st 3)
  (paint st 'v 12 4 (multi (lines 3) 12 4 "/bottom" 3) calls))

(test-case "both split leaves paint their names and the idle echo is empty"
  (define-values (st calls) (state))
  (define (lines selected) (list "top         " "more        "
                                 (painted (mode "/top" 12) (= selected 7))
                                 "bottom      " (painted (mode "/bottom" 12) (= selected 3))))
  (for ([selected '(7 3)] [row '(1 4)])
    (stacked! st selected)
    (paint st 'v 12 6 (multi (lines selected) 12 6 "" row) calls)))

(test-case "too-small split fallback judges the root height from frame arguments"
  (define-values (st calls) (state))
  (def! st 'fallback
    `(AloemacsSession new (s buffers) (s fs) (s echo) (s searching) (s query)
       (s origin) (s wrapped) (s failing) (s kill-ring) (s pending) (s prompt)
       (s last-submission) (s waiting-command)
       (AloemacsWindows new (AloemacsWindowTree Right ,(leaf 7 0) ,(leaf 3 0))
         7 80 24)))
  (paint st 'fallback 2 4 (single "ab\r\nde" 2 4 "untitled" "") calls)
  (paint st 'fallback 2 2 (single "ab" 2 2 "untitled" "un") calls))
