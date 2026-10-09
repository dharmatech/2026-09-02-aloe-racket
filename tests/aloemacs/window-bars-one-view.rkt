#lang racket/base

(require racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/env.rkt" "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" type-of type->datum
                  exn:fail:aloe-type? type-environment-bound?)
         "../../host/racket/aloemacs-run.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (dtype st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))

;; Test-local chrome literals. Expectations never send bar, row, frame-rows,
;; or a session composer.
(define LIGHT "\e[38;5;16;48;5;250m")
(define DARK "\e[38;5;252;48;5;239m")
(define PLAIN "\e[0m")
(define (visible s)
  (for/fold ([s s]) ([sequence (list LIGHT DARK PLAIN)]) (string-replace s sequence "")))
(define (occurrences s part) (length (regexp-match-positions* (regexp-quote part) s)))
(define (no-sequence? s)
  (for/and ([sequence (list LIGHT DARK PLAIN)]) (zero? (occurrences s sequence))))
(define (lit row) (if (string=? row "") "" (string-append LIGHT row PLAIN)))

(define no-path '(if #t (Option None) (Option Some (Path new ""))))
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define history '(List of (UndoFrame new (Text from-string "old") (Position new 0 1) 2 3)))
(define (editor text [line 0] [col 0] [top 0] [left 0] [height 0])
  `(AloemacsEditor new ((Text from-string ,text) indexed-value)
     (Position new ,line ,col) #f ,top ,left ,history ,no-mark ,height))
(define (buffer id ed [name #f])
  `(AloemacsBuffer new ,ed ,(if name `(Option Some (Path new ,name)) no-path) ,id))
(define (zipper bs [focus 0])
  `(AloemacsBuffers new (List of ,@(reverse (take bs focus))) ,(list-ref bs focus)
     (List of ,@(drop bs (add1 focus)))))
(define (leaf id [bid 41] [top 0] [left 0] [lock #f])
  `(AloemacsWindowTree Leaf (AloemacsView new ,id ,bid ,top ,left ,lock)))
(define (right a b) `(AloemacsWindowTree Right ,a ,b))
(define (below a b) `(AloemacsWindowTree Below ,a ,b))
(define (windows tree selected [w 9] [h 6]) `(AloemacsWindows new ,tree ,selected ,w ,h))
(define (session bs tree selected)
  `(AloemacsSession new ,bs (s fs) "" #f "" (Position new 0 0) #f #f (s kill-ring)
     (s pending) (s prompt) (s last-submission) (s waiting-command)
     ,(windows tree selected)))

(define (counted-fs)
  (define calls (box '()))
  (define disk (make-fs-double "/cwd"
                 (hash "/cwd" 'directory "/cwd/a" 'file "/cwd/b" 'file "/cwd/dir" 'directory)
                 (hash "/cwd/a" "zero\none\ntwo\nthree" "/cwd/b" "bee")))
  (define (forward selector args)
    (set-box! calls (append (unbox calls) (list (cons selector args))))
    (host-receiver-send disk selector args))
  (define interface
    (make-host-interface 'FsHost
      (for/list ([m (in-list (host-interface-methods fs-interface))])
        (define selector (host-method-selector m))
        (define params (host-method-parameter-types m))
        (make-host-method selector params (host-method-return-type m)
          (case (length params)
            [(0) (lambda (_) (forward selector '()))]
            [(1) (lambda (_ a) (forward selector (list a)))]
            [(2) (lambda (_ a b) (forward selector (list a b)))])))))
  (values (make-host-receiver interface #f) calls))
;; Every Term entry point records; a frame must never reach one.
(define (recording-term events)
  (define (record! x) (set-box! events (append (unbox events) (list x))))
  (make-term-receiver
    (make-output-port 'window-bars always-evt
      (lambda (bytes start end _non-block? _breakable?) (record! 'write) (- end start)) void)
    (lambda () (record! 'read) "escape")
    (lambda () (record! 'size) (values 12 4))))
(define (state #:term [term #f])
  (define st (make-driver))
  (define-values (fs calls) (counted-fs))
  (driver-inject-host! st 'fs-host fs)
  (when term (driver-inject-host! st 'term term))
  (ev st `(load ,(path->string main-path)))
  (def! st 's 'aloemacs-editor)
  (values st calls))

;; Independent visible cells and chrome.
(define (clip s w) (substring s 0 (max 0 (min w (string-length s)))))
(define (safe s)
  (list->string (for/list ([c (in-string s)])
                  (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (spelled name w)
  (define label (clip (string-append name " ") w))
  (string-append label (make-string (max 0 (- w (string-length label))) #\-)))
(define (mode name w) (safe (spelled name w)))
(define (cursor row col) (format "\e[~a;~aH" row col))
(define (direct body row col)
  (string-append "\e[?25l\e[2J\e[H" body (cursor row col) "\e[?25h"))
(define (count-rows lines h) (if (< h 2) 0 (min (length lines) (max 0 (- h 2)))))
(define (root-height lines h) (if (< h 2) h (- h 1 (count-rows lines h))))
(define (list-suffix lines w h)
  (define root (root-height lines h))
  (apply string-append
    (for/list ([line (in-list (take lines (count-rows lines h)))] [j (in-naturals 1)])
      (string-append (cursor (+ root j) 1) (safe (clip line w))))))
;; paint is lit for 000 and values for today's plain name row.
(define (one-view body row col w h name echo
                  #:lines [lines '()] #:final [final #f] #:paint [paint lit])
  (define root (root-height lines h))
  (string-append (direct body row col)
    (if (< h 2) ""
        (string-append "\e[?25l"
          (if (>= root 2) (string-append (cursor root 1) (paint (mode name w))) "")
          (list-suffix lines w h) (cursor h 1) (safe (clip echo w))
          (cursor (if final (car final) row) (if final (cadr final) col)) "\e[?25h"))))

(define (paint st s w h expected calls)
  (define before (ev st s))
  (define effects (unbox calls))
  (for ([i '(1 2)]) (check-equal? (ev st `(,s frame ,w ,h)) expected))
  (check-equal? (ev st s) before)
  (check-equal? (unbox calls) effects))
;; One LIGHT bar, closed by PLAIN before the next address.
(define (check-bar frame w h lines)
  (check-equal? (occurrences frame LIGHT) 1)
  (check-equal? (occurrences frame PLAIN) 1)
  (check-equal? (occurrences frame DARK) 0)
  (define light-at (caar (regexp-match-positions (regexp-quote LIGHT) frame)))
  (define plain-at (caar (regexp-match-positions (regexp-quote PLAIN) frame)))
  (define shown (substring frame (+ light-at (string-length LIGHT)) plain-at))
  (check-equal? (string-length shown) w)
  (check-equal? (safe shown) shown)
  (define root (root-height lines h))
  (check-true (string-suffix? (substring frame 0 light-at) (cursor root 1)))
  (check-true (string-prefix? (substring frame (+ plain-at (string-length PLAIN)))
                (cursor (if (null? (take lines (count-rows lines h))) h (add1 root)) 1))))
(define (paint-one st s calls body row col w h name echo #:lines [lines '()] #:final [final #f])
  (define expected (one-view body row col w h name echo #:lines lines #:final final))
  (define today (one-view body row col w h name echo #:lines lines #:final final #:paint values))
  (paint st s w h expected calls)
  (check-equal? (visible expected) today)
  (if (and (>= h 2) (>= (root-height lines h) 2) (> w 0))
      (check-bar (ev st `(,s frame ,w ,h)) w h lines)
      (begin (check-equal? expected today) (check-true (no-sequence? expected)))))

(test-case "bar types, rejections, shapes and a capability-free checked load"
  (define datums (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) datums))
  (check-equal? (take datums 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsView
      AloemacsWindowTree AloemacsWindowRect AloemacsWindows AloemacsCommand
      (AloemacsKeymap B) AloemacsBinding AloemacsSearchScan (AloemacsSession H)))
  (define (payload name) (caddr (findf (lambda (d) (equal? (cadr d) name)) classes)))
  (check-equal? (payload 'AloemacsModeLine) '(fields))
  (check-equal? (payload 'AloemacsBuffer)
                '(fields (editor AloemacsEditor) (path (Option Path)) (id Int)))
  (check-equal? (payload 'AloemacsView)
                '(fields (id Int) (buffer-id Int) (scroll-row Int) (scroll-col Int) (locked Bool)))
  (check-equal? (payload 'AloemacsWindowRect)
                '(fields (x Int) (y Int) (columns Int) (rows Int)))
  (check-equal? (payload 'AloemacsWindows)
                '(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int)))
  (check-equal? (map car (cdr (payload '(AloemacsSession H))))
                '(buffers fs echo searching query origin wrapped failing kill-ring pending
                          prompt last-submission waiting-command windows))
  (define editor-datums (call-with-input-file editor-path (lambda (in) (port->list read in))))
  (define editor-class
    (findf (lambda (d) (equal? (take d 2) '(define-class AloemacsEditor))) editor-datums))
  (check-equal? (caddr editor-class)
    '(fields (text Text) (point Position) (quit Bool) (scroll-row Int) (scroll-col Int)
             (history (List UndoFrame)) (mark (Option Position)) (text-rows Int)))
  ;; Only AloemacsModeLine owns bar; any helper takes nothing and returns String.
  (define (methods-of d) (cdr (findf (lambda (s) (and (pair? s) (eq? (car s) 'methods))) d)))
  (for ([d (in-list (append datums editor-datums))]
        #:when (memq (car d) '(define-class define-methods)))
    (define selectors (map car (methods-of d)))
    (if (eq? (cadr d) 'AloemacsModeLine)
        (check-not-false (memq 'bar selectors))
        (check-false (memq 'bar selectors) (format "~s has no bar" (cadr d)))))
  (define line-methods (methods-of (findf (lambda (d) (eq? (cadr d) 'AloemacsModeLine)) classes)))
  (check-equal? (take (assq 'bar line-methods) 4) '(bar (row String) (selected? Bool) String))
  (check-equal? (take (assq 'row line-methods) 4) '(row (name String) (width Int) String))
  (check-equal? (take (assq 'fill line-methods) 3) '(fill (remaining Int) String))
  (for ([m (in-list line-methods)] #:unless (memq (car m) '(row fill bar)))
    (check-equal? (take m 3) (list (car m) '() 'String)))
  (define out (open-output-string))
  (define err (open-output-string))
  (define st (parameterize ([current-output-port out] [current-error-port err])
               (define st (make-driver))
               (ev st `(load ,(path->string file-path)))
               st))
  (for ([name '(fs-host term)])
    (check-false (env-bound? (driver-runtime-environment st) name))
    (check-false (type-environment-bound? (driver-type-environment st) name)))
  (check-equal? (get-output-string out) "")
  (check-equal? (get-output-string err) "")
  (check-equal? (dtype st '((AloemacsModeLine new) bar "x" #t)) 'String)
  (check-equal? (dtype st '((AloemacsModeLine new) bar "" #f)) 'String)
  (check-equal? (dtype st '((AloemacsModeLine new) row "x" 4)) 'String)
  (check-equal? (ev st '((AloemacsModeLine new) row "/a" 4)) "/a -")
  (check-equal? (ev st '((AloemacsModeLine new) fill 3)) "---")
  (for ([expr '(((AloemacsModeLine new) bar) ((AloemacsModeLine new) bar "x")
                ((AloemacsModeLine new) bar "x" #t #f) ((AloemacsModeLine new) bar "x" #t "y")
                ((AloemacsModeLine new) bar 1 #t) ((AloemacsModeLine new) bar 1.0 #t)
                ((AloemacsModeLine new) bar "x" "t") ((AloemacsModeLine new) bar "x" 1)
                ((AloemacsModeLine new) bar #t "x")
                ("x" bar "x" #t) (1 bar "x" #t) (AloemacsModeLine bar "x" #t)
                ((AloemacsView new 0 0 0 0 #f) bar "x" #t)
                ((AloemacsWindowRect new 0 0 3 4) bar "x" #t))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st expr)) (format "reject ~s" expr))))

(test-case "bar values through raw row, safe cells and bar, plus bar alone"
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  (def! st 'ed (editor ""))
  (define (painted name width selected)
    (ev st `((AloemacsModeLine new) bar
              (ed safe-cells ((AloemacsModeLine new) row ,name ,width)) ,selected)))
  ;; Literal witnesses for the checkpoint's bar table.
  (for ([entry `(("/a" 4 #t "\e[38;5;16;48;5;250m/a -\e[0m")
                 ("/a" 4 #f "\e[38;5;252;48;5;239m/a -\e[0m")
                 ("untitled" 12 #t "\e[38;5;16;48;5;250muntitled ---\e[0m")
                 ("untitled" 12 #f "\e[38;5;252;48;5;239muntitled ---\e[0m")
                 ("untitled" 1 #t "\e[38;5;16;48;5;250mu\e[0m")
                 ("untitled" 1 #f "\e[38;5;252;48;5;239mu\e[0m")
                 ("untitled" 0 #t "") ("untitled" 0 #f "")
                 ("" 4 #t "\e[38;5;16;48;5;250m ---\e[0m")
                 ("a\e[31m" 8 #t "\e[38;5;16;48;5;250ma [31m -\e[0m"))])
    (check-equal? (apply painted (take entry 3)) (cadddr entry) (format "~s" entry)))
  (define control "a\e[31m\t\r\n\u007fZ")
  (for* ([entry `(("/a" 4) ("untitled" 12) ("untitled" 1) ("untitled" 0) ("untitled" -3)
                  ("untitled" 8) ("untitled" 9) ("" 1) ("" 4) ("a\e[31m" 8)
                  (,control 1) (,control 2) (,control 3) (,control 6) (,control 10) (,control 15)
                  ("abc\e\t\r\n\u007f" 3) ("abc\e\t\r\n\u007f" 5) ("ab\e[31m" 2))]
         [selected '(#t #f)])
    (define name (car entry))
    (define width (cadr entry))
    (define actual (painted name width selected))
    (define shown (mode name (max 0 width)))
    (check-equal? actual
                  (if (<= width 0) "" (string-append (if selected LIGHT DARK) shown PLAIN)))
    (check-equal? (visible actual) shown)
    (check-equal? (string-length (visible actual)) (max 0 width))
    (check-equal? (safe (visible actual)) (visible actual)))
  (check-equal? (mode control 15) "a [31m    Z ---")
  ;; bar alone neither clips, pads nor applies safe cells.
  (for ([row (list control "\e[0m" "x" "a long row beyond any width")] [selected '(#t #f #t #f)])
    (check-equal? (ev st `((AloemacsModeLine new) bar ,row ,selected))
                  (string-append (if selected LIGHT DARK) row PLAIN)))
  (for ([selected '(#t #f)])
    (check-equal? (ev st `((AloemacsModeLine new) bar "" ,selected)) "")))

(test-case "complete one-view frames: widths, buffers, names, origins and echo states"
  (define-values (st calls) (state))
  ;; Byte-for-byte checkpoint examples.
  (paint st 's 12 4
    "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[1;1H\e[?25h"
    calls)
  (paint st 's 1 4
    "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250mu\e[0m\e[4;1H\e[1;1H\e[?25h"
    calls)
  (def! st 'text `((s with-editor ,(editor "zero\none\ntwo\nthree" 3 0)) ensure-visible 12 4))
  (paint st 'text 12 4
    "\e[?25l\e[2J\e[Htwo\r\nthree\e[2;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[2;1H\e[?25h"
    calls)
  (for ([width '(1 4 12 40)])
    (paint-one st 's calls "\r\n" 1 1 width 4 "untitled" "")
    (paint-one st 's calls "" 1 1 width 3 "untitled" "")
    (paint-one st 'text calls (string-join (map (lambda (l) (clip l width)) '("two" "three")) "\r\n")
               2 1 width 4 "untitled" ""))
  (paint-one st 'text calls "two\r\nthree\r\n\r\n\r\n" 2 1 12 7 "untitled" "")
  (def! st 'blank `(s with-editor ,(editor "\n\n")))
  (paint-one st 'blank calls "\r\n" 1 1 12 4 "untitled" "")
  (paint-one st 'blank calls "\r\n\r\n\r\n" 1 1 12 6 "untitled" "")
  (def! st 'bound '(s add-buffer "zero\none\ntwo\nthree" (Path new "/cwd/a")))
  (def! st 'bound '(bound with-editor (AloemacsEditor new
                    (Text indexed (List of "one" "zero") "two" (List of "three") 2)
                    (Position new 3 2) #f 2 1 (List empty)
                    (Option Some (Position new 1 1)) 9)))
  (for ([status '("" "saved" "failed")]
        [echo '("" "saved: /cwd/a" "failed: /cwd/a")])
    (def! st 'status `(bound with-echo ,status))
    (for ([width '(1 3 8 20)])
      (define rows (for/list ([line '("wo" "hree")]) (clip line width)))
      (paint-one st 'status calls (string-join rows "\r\n") 2 2 width 4 "/cwd/a" echo)
      (paint-one st 'status calls (car rows) 2 2 width 3 "/cwd/a" echo)))
  (def! st 'search '(bound with-search (bound editor) #t "two" (Position new 1 2) #f #f))
  (paint-one st 'search calls "wo\r\nhree" 2 2 12 4 "/cwd/a" "search: two")
  (paint-one st 'search calls "wo" 2 2 12 3 "/cwd/a" "search: two")
  (for ([wrapped '(#t #f)] [failing '(#f #t)] [echo '("wrapped: two" "failing: two")])
    (def! st 'search `(search with-search (search editor) #t "two" (search origin) ,wrapped ,failing))
    (paint-one st 'search calls "wo" 2 2 20 3 "/cwd/a" echo))
  (def! st 'prompt '(search with-active-prompt
                     (AloemacsPrompt new "Ask: " "abcd" 2 "" (List empty) (List empty) 0)))
  (for ([width '(1 6 12)])
    (paint-one st 'prompt calls (clip "wo" width) 2 2 width 3 "/cwd/a" "Ask: abcd"
               #:final (list 3 (min width 8))))
  ;; A painted completion list sits between PLAIN and the echo address.
  (define lines '("alpha" "b\tc" "gamma"))
  (def! st 'listed `(bound with-active-prompt
                     (AloemacsPrompt new "Find: " "x" 1 "" (List of ,@lines) (List empty) 0)))
  (for ([width '(1 5 12)])
    (paint-one st 'listed calls (string-join (map (lambda (l) (clip l width)) '("wo" "hree")) "\r\n")
               2 2 width 7 "/cwd/a" "Find: x" #:lines lines #:final (list 7 (min width 8)))
    (paint-one st 'listed calls (clip "wo" width) 2 2 width 6 "/cwd/a" "Find: x"
               #:lines lines #:final (list 6 (min width 8))))
  (paint st 'listed 12 7
    (string-append "\e[?25l\e[2J\e[Hwo\r\nhree\e[2;2H\e[?25h\e[?25l\e[3;1H" LIGHT "/cwd/a -----"
                   PLAIN "\e[4;1Halpha\e[5;1Hb c\e[6;1Hgamma\e[7;1HFind: x\e[7;8H\e[?25h")
    calls)
  (check-equal? (unbox calls) '()))

(test-case "short frames, completion-shortened roots and direct editor frames have no sequence"
  (define-values (st calls) (state))
  (paint st 's 12 2 "\e[?25l\e[2J\e[H\e[1;1H\e[?25h\e[?25l\e[2;1Huntitled\e[1;1H\e[?25h" calls)
  (paint st 's 12 1 "\e[?25l\e[2J\e[H\e[1;1H\e[?25h" calls)
  (for ([width '(0 1 12)])
    (paint-one st 's calls "" 1 1 width 2 "untitled" "untitled")
    (paint-one st 's calls "" 1 1 width 1 "untitled" "")
    (paint-one st 's calls "" 1 1 width 0 "untitled" ""))
  ;; Width zero paints an empty name row, which bar leaves empty.
  (paint st 's 0 4 "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[4;1H\e[1;1H\e[?25h" calls)
  (def! st 'bound '(s add-buffer "zero\none\ntwo\nthree" (Path new "/cwd/a")))
  (def! st 'bound '(bound with-editor (AloemacsEditor new
                    (Text indexed (List of "one" "zero") "two" (List of "three") 2)
                    (Position new 3 2) #f 2 1 (List empty)
                    (Option Some (Position new 1 1)) 9)))
  (paint-one st 'bound calls "wo" 2 2 20 2 "/cwd/a" "/cwd/a")
  (paint-one st 'bound calls "wo" 2 2 20 1 "/cwd/a" "")
  (define lines '("alpha" "b\tc" "gamma"))
  (def! st 'listed `(bound with-active-prompt
                     (AloemacsPrompt new "Find: " "x" 1 "" (List of ,@lines) (List empty) 0)))
  (for ([h '(2 3 4 5)])
    (check-true (< (root-height lines h) 2))
    (paint-one st 'listed calls "wo" 2 2 12 h "/cwd/a" "Find: x"
               #:lines lines #:final (list h 8)))
  (paint st 'listed 12 4
    "\e[?25l\e[2J\e[Hwo\e[2;2H\e[?25h\e[?25l\e[2;1Halpha\e[3;1Hb c\e[4;1HFind: x\e[4;8H\e[?25h"
    calls)
  (paint st 'listed 12 1 "\e[?25l\e[2J\e[Hwo\e[2;2H\e[?25h" calls)
  (for ([rows '(0 1 2 3)] [body '("" "wo" "wo\r\nhree" "wo\r\nhree\r\n")])
    (define framed (ev st `((bound editor) frame 12 ,rows)))
    (check-equal? framed (direct body 2 2))
    (check-true (no-sequence? framed)))
  (check-equal? (ev st '((bound editor) frame-ansi "x\ty" 3 4)) "\e[?25l\e[2J\e[Hx\ty\e[3;4H\e[?25h")
  (check-equal? (unbox calls) '()))

(define a-lines "abcdef\nghijkl\nmnopqr\nstuvwx\nyz0123")
(define b-lines "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
;; Right below three columns supplies the zero axis; the Below has extent five.
(define fallback-tree
  (below (right (leaf 0 41 0 0) (leaf 1 9 1 2 #t)) (leaf 2 41 2 1 #t)))

(test-case "too-small fallback paints one LIGHT bar, short root is plain, growth restores split bars"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor a-lines 3 1) "/a"))
  (def! st 'b (buffer 9 (editor b-lines 1 1) "/b"))
  (def! st 'v (session (zipper '(a b)) fallback-tree 0))
  ;; The selected leaf (0,0,1,3) is positive alone; the Right's other child is zero.
  (check-true (ev st `(,fallback-tree positive-layout? (AloemacsWindowRect new 0 0 9 5))))
  (check-false (ev st `(,fallback-tree positive-layout? (AloemacsWindowRect new 0 0 2 5))))
  (same st `(,fallback-tree rect-for 0 (AloemacsWindowRect new 0 0 2 5))
        '(Option Some (AloemacsWindowRect new 0 0 1 3)))
  (def! st 'small '(v ensure-visible 2 6))
  (check-equal? (ev st '((small editor) text-rows)) 4)
  (paint-one st 'small calls "ab\r\ngh\r\nmn\r\nst" 4 2 2 6 "/a" "")
  (paint st 'small 2 6
    (string-append "\e[?25l\e[2J\e[Hab\r\ngh\r\nmn\r\nst\e[4;2H\e[?25h\e[?25l\e[5;1H"
                   LIGHT "/a" PLAIN "\e[6;1H\e[4;2H\e[?25h") calls)
  (paint-one st 'small calls "ab\r\ngh\r\nmn" 4 2 2 5 "/a" "")
  (paint-one st 'small calls "a\r\ng\r\nm\r\ns" 4 2 1 6 "/a" "")
  ;; Root height one is a Below at extent one: today's bytes.
  (def! st 'tiny '(small ensure-visible 9 2))
  (paint-one st 'tiny calls "stuvwx" 1 2 9 2 "/a" "/a")
  (paint st 'tiny 9 2 "\e[?25l\e[2J\e[Hstuvwx\e[1;2H\e[?25h\e[?25l\e[2;1H/a\e[1;2H\e[?25h" calls)
  (paint-one st 'tiny calls "stuvwx" 1 2 9 1 "/a" "")
  (def! st 'grown '(tiny ensure-visible 9 6))
  ;; Growth: (0,0,4,3), (5,0,4,3) and (0,3,9,2); no rule row, one LIGHT bar.
  (define grown (list "stuv|HIJ " "yz01|MNO " (string-append LIGHT "/a -" PLAIN "|" DARK "/b -" PLAIN)
                      "nopqr    " (string-append DARK "/a ------" PLAIN)))
  (define expected
    (string-append "\e[?25l\e[2J\e[H" (string-join grown "\r\n") "\e[6;1H\e[1;2H\e[?25h"))
  (paint st 'grown 9 6 expected calls)
  (check-equal? (map visible grown) '("stuv|HIJ " "yz01|MNO " "/a -|/b -" "nopqr    " "/a ------"))
  (check-equal? (occurrences expected LIGHT) 1)
  (check-equal? (occurrences expected DARK) 2)
  (check-equal? (occurrences expected PLAIN) 3)
  (same st '((grown windows) tree)
    (below (right (leaf 0 41 3 0) (leaf 1 9 1 2 #t)) (leaf 2 41 2 1 #t)))
  (for ([s '(small tiny grown)])
    (check-equal? (ev st `((,s windows) selected)) 0))
  (same st '((small windows) tree)
    (below (right (leaf 0 41 0 0) (leaf 1 9 1 2 #t)) (leaf 2 41 2 1 #t)))
  ;; A zero selected leaf also frames its own buffer through the one-view bar.
  (def! st 'w (session (zipper '(a b) 1) fallback-tree 1))
  (def! st 'zero '(w ensure-visible 2 6))
  (paint-one st 'zero calls "AB\r\nFG\r\nKL\r\nPQ" 2 2 2 6 "/b" "")
  (same st '((zero windows) tree)
    (below (right (leaf 0 41 0 0) (leaf 1 9 0 0 #t)) (leaf 2 41 2 1 #t)))
  (check-equal? (unbox calls) '()))

(test-case "positive split frames paint LIGHT and DARK bars; prompts keep the selected bar"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor a-lines) "/a"))
  ;; Selected view 0 paints LIGHT; view 1 paints DARK.
  (define (split tree rows echo row col)
    (def! st 'v (session (zipper '(a)) tree 0))
    (define expected
      (string-append "\e[?25l\e[2J\e[H" (string-join rows "\r\n") (cursor 6 1) echo
                     (cursor row col) "\e[?25h"))
    (paint st 'v 9 6 expected calls)
    (check-equal? (occurrences expected LIGHT) 1)
    (check-equal? (occurrences expected DARK) 1)
    (check-equal? (occurrences expected PLAIN) 2))
  (define side (list "abcd|ijkl" "ghij|opqr" "mnop|uvwx" "stuv|0123"
                     (string-append LIGHT "/a -" PLAIN "|" DARK "/a -" PLAIN)))
  (split (right (leaf 0) (leaf 1 41 1 2)) side "" 1 1)
  (define stacked (list "abcdef   " "ghijkl   " (string-append LIGHT "/a ------" PLAIN)
                        "ijkl     " (string-append DARK "/a ------" PLAIN)))
  (split (below (leaf 0) (leaf 1 41 1 2)) stacked "" 1 1)
  (def! st 'p '(v with-active-prompt (AloemacsPrompt new "P:" "x" 1 "" (List empty) (List empty) 0)))
  (paint st 'p 9 6
    (string-append "\e[?25l\e[2J\e[H" (string-join stacked "\r\n")
                   "\e[6;1HP:x\e[6;4H\e[?25h") calls)
  (def! st 'v (session (zipper '(a)) (right (leaf 0) (leaf 1 41 1 2)) 0))
  (def! st 'p '(v with-active-prompt (AloemacsPrompt new "P:" "x" 1 "" (List empty) (List empty) 0)))
  (paint st 'p 9 6
    (string-append "\e[?25l\e[2J\e[H" (string-join side "\r\n") "\e[6;1HP:x\e[6;4H\e[?25h") calls)
  ;; One view: the prompt owns the cursor and the bar stays LIGHT.
  (def! st 'one (session (zipper '(a)) (leaf 0) 0))
  (def! st 'asked '(one with-active-prompt (AloemacsPrompt new "P:" "x" 1 "" (List empty) (List empty) 0)))
  (paint-one st 'asked calls "abcdef\r\nghijkl\r\nmnopqr\r\nstuvwx" 1 1 9 6 "/a" "P:x"
             #:final (list 6 4))
  (check-true (string-suffix? (ev st '(asked frame 9 6)) "\e[6;1HP:x\e[6;4H\e[?25h"))
  (check-equal? (unbox calls) '()))

(test-case "frame is pure, and the production runner fits, frames and writes before each read"
  (define term-events (box '()))
  (define-values (st calls) (state #:term (recording-term term-events)))
  (def! st 'bound '(s add-buffer "zero\none\ntwo\nthree" (Path new "/cwd/a")))
  (def! st 'bound '((bound with-search (bound editor) #t "two" (Position new 1 2) #f #f)
                    ensure-visible 12 4))
  (define before (ev st 'bound))
  (define effects (unbox calls))
  (define framed (ev st '(bound frame 12 4)))
  (check-equal? (ev st '(bound frame 12 4)) framed)
  (check-equal? (occurrences framed LIGHT) 1)
  (ev st '(bound frame 40 9))
  (ev st '(bound frame 3 2))
  (check-equal? (ev st 'bound) before)
  (check-equal? (unbox calls) effects)
  (check-equal? (unbox term-events) '())
  (define sizes '((12 4) (12 4) (12 2) (12 4) (12 4) (12 4)))
  (define keys '("down" "save" "ctrl-x" "find" "escape" "escape"))
  (define frames
    (list (one-view "zero\r\none" 1 1 12 4 "/cwd/a" "")
          (one-view "zero\r\none" 2 1 12 4 "/cwd/a" "")
          (one-view "one" 1 1 12 2 "/cwd/a" "saved: /cwd/a")
          (one-view "one\r\ntwo" 1 1 12 4 "/cwd/a" "")
          (one-view "one\r\ntwo" 1 1 12 4 "/cwd/a" "Find file: /cwd/" #:final '(4 12))
          (one-view "one\r\ntwo" 1 1 12 4 "/cwd/a" "")))
  (check-equal? (car frames)
    (string-append "\e[?25l\e[2J\e[Hzero\r\none\e[1;1H\e[?25h\e[?25l\e[3;1H" LIGHT "/cwd/a -----"
                   PLAIN "\e[4;1H\e[1;1H\e[?25h"))
  (check-equal? (caddr frames)
    "\e[?25l\e[2J\e[Hone\e[1;1H\e[?25h\e[?25l\e[2;1Hsaved: /cwd/\e[1;1H\e[?25h")
  (for ([f frames] [size sizes])
    (check-equal? (occurrences f LIGHT) (if (= (cadr size) 4) 1 0))
    (check-equal? (occurrences f DARK) 0))
  (define events '())
  (define (record! x) (set! events (append events (list x))))
  (define dimensions 0)
  (define remaining keys)
  (define out (make-output-port 'window-bars always-evt
    (lambda (bytes start end _non-block? _breakable?)
      (record! (if (= start end) 'flush
                   (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
      (- end start)) void))
  (define term (make-term-receiver out
    (lambda () (define key (car remaining)) (set! remaining (cdr remaining))
      (record! (list 'key key)) key)
    (lambda ()
      (define size (list-ref sizes (quotient dimensions 2)))
      (record! (list (if (even? dimensions) 'columns 'rows)
                     (if (even? dimensions) (car size) (cadr size))))
      (set! dimensions (add1 dimensions)) (values (car size) (cadr size)))))
  (define-values (fs runner-calls) (counted-fs))
  (run-aloemacs-with-hosts term fs "a")
  (check-equal? remaining '())
  (check-equal? dimensions (* 2 (length keys)))
  (check-equal? events
    (append-map (lambda (size key expected)
                  (list (list 'columns (car size)) (list 'rows (cadr size))
                        (list 'write expected) 'flush (list 'key key))) sizes keys frames))
  (check-equal? (length (filter (lambda (e) (and (pair? e) (eq? (car e) 'write))) events)) 6)
  (check-equal? (length (filter (lambda (e) (and (pair? e) (eq? (car e) 'key))) events)) 6)
  (check-equal? (filter (lambda (c) (memq (car c) '(read write))) (unbox runner-calls))
                '((read "/cwd/a") (write "/cwd/a" "zero\none\ntwo\nthree"))))
