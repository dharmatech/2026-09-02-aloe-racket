#lang racket/base

;; aloemacs-mode-buttons 000: a mode line at least seven columns wide ends
;; with the six characters " ↕ ↔ ×" inside the bar it already has. A
;; narrower line keeps today's row. A left press on a label runs the window
;; command it names; mode-buttons-press.rkt is that proof. No TTY is opened here.

(require racket/file racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/env.rkt" "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" type-of type->datum
                  exn:fail:aloe-type? type-environment-bound?)
         "../../host/racket/aloemacs-run.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (dtype st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (rejects st bad)
  (check-exn exn:fail:aloe-type? (lambda () (ev st bad)) (format "reject ~s" bad)))

;; A fresh checked load of file.aloe alone; no host is injected.
(define (loaded)
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  st)

;; The fs double of mouse.rkt, behind a receiver that records every call.
(define (counted-fs)
  (define calls (box '()))
  (define disk (make-fs-double "/cwd"
                 (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
                 (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b")))
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

;; main.aloe with the fs injected first; s is the empty session and s0 is
;; the 80 by 24 session of mouse.rkt.
(define contents "hello\nworld\nxyz")
(define (session-state)
  (define st (make-driver))
  (define-values (fs calls) (counted-fs))
  (driver-inject-host! st 'fs-host fs)
  (void (driver-load-file! st main-path))
  (def! st 's 'aloemacs-editor)
  (def! st 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt"))
                 ensure-visible 80 24))
  (values st calls))

;; Test-local literals. Expectations never send row, name-row, buttons,
;; bar, frame-rows, or a session composer.
(define LIGHT "\e[38;5;16;48;5;250m")
(define DARK "\e[38;5;252;48;5;239m")
(define PLAIN "\e[0m")
(define GROUP " ↕ ↔ ×")
(define UPDOWN (integer->char #x2195))
(define LEFTRIGHT (integer->char #x2194))
(define TIMES (integer->char #xd7))
(define label-rx (regexp (string-append "[" (string UPDOWN LEFTRIGHT TIMES) "]")))
;; The escape spelling file.aloe uses, built so this source holds no escape.
(define backslash (string (integer->char 92)))
(define escaped-group
  (string-append " " backslash "u2195 " backslash "u2194 " backslash "u00d7"))
(define (read-string-literal text)
  (read (open-input-string (string-append "\"" text "\""))))
(define (visible s)
  (for/fold ([s s]) ([sequence (list LIGHT DARK PLAIN)]) (string-replace s sequence "")))
(define (occurrences s part) (length (regexp-match-positions* (regexp-quote part) s)))
(define (lit row) (string-append LIGHT row PLAIN))
(define (dark row) (string-append DARK row PLAIN))
(define (pad s w) (string-append s (make-string (max 0 (- w (string-length s))) #\space)))
(define (dashes n) (make-string n #\-))
(define (lines->body lines count)
  (string-join (append lines (make-list (- count (length lines)) "")) "\r\n"))
(define control "a\e[31m\t\r\n\x01\x7fZ")
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))

(define class-list
  '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView
    AloemacsWindowTree AloemacsWindowRect AloemacsWindows AloemacsCommand
    (AloemacsKeymap B) AloemacsBinding AloemacsSearchScan AloemacsMouse (AloemacsSession H)))

;; Frame twice, byte for byte; the session and the Fs double are untouched.
(define (paint st s w h expected calls)
  (define before (ev st s))
  (define effects (unbox calls))
  (for ([i '(1 2)])
    (check-equal? (ev st `(,s frame ,w ,h)) expected (format "~s at ~a by ~a" s w h)))
  (check-equal? (ev st s) before)
  (check-equal? (unbox calls) effects))

;; One LIGHT bar of width w, closed by PLAIN; the group ends it at 7 or more.
(define (check-one-bar frame w)
  (check-equal? (occurrences frame LIGHT) 1)
  (check-equal? (occurrences frame PLAIN) 1)
  (check-equal? (occurrences frame DARK) 0)
  (define light-at (caar (regexp-match-positions (regexp-quote LIGHT) frame)))
  (define plain-at (caar (regexp-match-positions (regexp-quote PLAIN) frame)))
  (define shown (substring frame (+ light-at (string-length LIGHT)) plain-at))
  (check-equal? (string-length shown) w)
  (cond
    [(>= w 7)
     (check-equal? (substring shown (- w 6)) GROUP)
     (check-equal? (string-ref shown (- w 5)) UPDOWN)
     (check-equal? (string-ref shown (- w 3)) LEFTRIGHT)
     (check-equal? (string-ref shown (- w 1)) TIMES)
     (check-equal? (string-ref frame (sub1 plain-at)) TIMES)
     (check-equal? (occurrences frame GROUP) 1)]
    [else (check-false (regexp-match? label-rx frame))]))

;; 1. Types and arities.
(test-case "types, arities, declared shapes, an ASCII source and a capability-free load"
  (define datums (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) datums))
  (check-equal? (take datums 3)
                '((load "editor.aloe")
                  (load "../../lib/text.aloe")
                  (load "../../lib/fs.aloe")))
  (check-equal? (map cadr classes) class-list)
  (define line (findf (lambda (d) (eq? (cadr d) 'AloemacsModeLine)) classes))
  (check-equal? (caddr line) '(fields))
  (define methods (cdr (findf (lambda (s) (and (pair? s) (eq? (car s) 'methods))) line)))
  (check-equal? (take (assq 'row methods) 4) '(row (name String) (width Int) String))
  (check-equal? (take (assq 'name-row methods) 4) '(name-row (name String) (width Int) String))
  (check-equal? (take (assq 'buttons? methods) 3) '(buttons? (width Int) Bool))
  (for ([selector '(buttons light dark plain)])
    (check-equal? (take (assq selector methods) 3) (list selector '() 'String)))
  ;; The source stays ASCII bytes and spells the group with escapes that
  ;; the reader turns into the three glyphs.
  (define source (file->string file-path))
  (check-true (for/and ([b (in-bytes (file->bytes file-path))]) (< b 128)))
  (for ([code '("u2195" "u2194" "u00d7")])
    (check-true (string-contains? source (string-append backslash code)) code))
  (check-false (regexp-match? label-rx source))
  (check-equal? (read-string-literal escaped-group) GROUP)
  (check-equal? (last (assq 'buttons methods)) GROUP)
  (define out (open-output-string))
  (define err (open-output-string))
  (define st (parameterize ([current-output-port out] [current-error-port err]) (loaded)))
  (for ([name '(fs-host term)])
    (check-false (env-bound? (driver-runtime-environment st) name))
    (check-false (type-environment-bound? (driver-type-environment st) name)))
  (check-equal? (get-output-string out) "")
  (check-equal? (get-output-string err) "")
  (check-equal? (dtype st '(AloemacsModeLine new)) 'AloemacsModeLine)
  (check-equal? (dtype st '((AloemacsModeLine new) buttons)) 'String)
  (check-equal? (dtype st '((AloemacsModeLine new) buttons? 7)) 'Bool)
  (check-equal? (dtype st '((AloemacsModeLine new) name-row "x" 4)) 'String)
  (check-equal? (dtype st '((AloemacsModeLine new) row "x" 4)) 'String)
  (for ([bad '(((AloemacsModeLine new) buttons 1)
               ((AloemacsModeLine new) buttons?) ((AloemacsModeLine new) buttons? 7 8)
               ((AloemacsModeLine new) buttons? "7")
               ((AloemacsModeLine new) name-row) ((AloemacsModeLine new) name-row "x")
               ((AloemacsModeLine new) name-row "x" 1 2)
               ((AloemacsModeLine new) name-row 1 2) ((AloemacsModeLine new) name-row "x" "2")
               ((AloemacsModeLine new) name-row "x" 2.0) ("x" name-row "x" 2)
               ((AloemacsModeLine new) row) ((AloemacsModeLine new) row "x" 1 2))])
    (rejects st bad)))

;; 2. The group.
(test-case "the group is six cells with three labels that safe cells copy"
  (define st (loaded))
  (define group (ev st '((AloemacsModeLine new) buttons)))
  (check-equal? (string-length group) 6)
  (for ([i '(1 3 5)] [c (list UPDOWN LEFTRIGHT TIMES)])
    (check-equal? (string-ref group i) c))
  (for ([i '(0 2 4)]) (check-equal? (string-ref group i) #\space))
  (check-equal? group GROUP)
  (check-equal? group (read-string-literal escaped-group))
  (def! st 'ed `(AloemacsEditor new (Text from-string "") (Position new 0 0) #f 0 0
                   (List empty) ,no-mark 0))
  (check-equal? (ev st '(ed safe-cells ((AloemacsModeLine new) buttons))) GROUP))

;; 3. The threshold.
(test-case "buttons? is true from seven columns"
  (define st (loaded))
  (for ([w '(-1 0 1 6)])
    (check-false (ev st `((AloemacsModeLine new) buttons? ,w)) (format "~a" w)))
  (for ([w '(7 8 12 80)])
    (check-true (ev st `((AloemacsModeLine new) buttons? ,w)) (format "~a" w))))

;; 4. Rows.
(define name-row-table
  `(("untitled" 0 "") ("untitled" -8 "") ("untitled" 1 "u")
    ("untitled" 8 "untitled") ("untitled" 9 "untitled ") ("untitled" 12 "untitled ---")
    ("/cwd/a.txt" 8 "/cwd/a.t") ("/a" 4 "/a -") ("" 4 " ---")
    ("abc" 3 "abc") ("abc" 4 "abc ") ("abc" 6 "abc --") ("/a/very/long/name" 5 "/a/ve")
    ("a\eb" 6 "a\eb --") (,control 15 "a\e[31m\t\r\n\x01\x7fZ --")
    ("abc\e\t\r\n\x01\x7f" 3 "abc")))
(define row-table
  `(("untitled" 6 "untitl") ("untitled" 7 "u ↕ ↔ ×") ("untitled" 8 "un ↕ ↔ ×")
    ("untitled" 9 "unt ↕ ↔ ×") ("untitled" 12 "untitl ↕ ↔ ×") ("untitled" 14 "untitled ↕ ↔ ×")
    ("untitled" 15 "untitled  ↕ ↔ ×") ("untitled" 16 "untitled - ↕ ↔ ×")
    ("untitled" 20 "untitled ----- ↕ ↔ ×") ("/tmp/file.aloe" 12 "/tmp/f ↕ ↔ ×")
    ("/cwd/a.txt" 8 "/c ↕ ↔ ×")
    ("/cwd/a.txt" 80 ,(string-append "/cwd/a.txt " (dashes 63) " ↕ ↔ ×"))
    ("/a" 8 "/a ↕ ↔ ×") ("/a" 9 "/a  ↕ ↔ ×") ("-|+" 7 "- ↕ ↔ ×") ("" 7 "  ↕ ↔ ×")))

(test-case "name-row keeps today's rows; row ends with the group from seven columns"
  (define st (loaded))
  (for ([entry name-row-table])
    (define actual (ev st `((AloemacsModeLine new) name-row ,(car entry) ,(cadr entry))))
    (check-equal? actual (caddr entry) (format "~s" entry))
    (check-equal? (string-length actual) (max 0 (cadr entry))))
  (for* ([name '("untitled" "/cwd/a.txt" "")] [w '(-8 0 1 3 4 6)])
    (check-equal? (ev st `((AloemacsModeLine new) row ,name ,w))
                  (ev st `((AloemacsModeLine new) name-row ,name ,w))
                  (format "~s at ~a" name w)))
  (for ([entry row-table])
    (define actual (ev st `((AloemacsModeLine new) row ,(car entry) ,(cadr entry))))
    (check-equal? actual (caddr entry) (format "~s" entry))
    (check-equal? (string-length actual) (cadr entry) (format "~s" entry)))
  (for* ([name '("untitled" "/cwd/a.txt")] [w '(7 8 15 20 80)])
    (define actual (ev st `((AloemacsModeLine new) row ,name ,w)))
    (check-equal? (string-length actual) w)
    (check-equal? (substring actual (- w 6)) GROUP)
    (check-equal? (substring actual (- w 6)) (ev st '((AloemacsModeLine new) buttons)))
    (check-equal? (string-ref actual 0) (string-ref name 0))
    (check-equal? (string-ref actual (- w 5)) UPDOWN)
    (check-equal? (string-ref actual (- w 3)) LEFTRIGHT)
    (check-equal? (string-ref actual (- w 1)) TIMES))
  ;; Controls stay raw in the row; the paint site makes them one space each.
  (check-equal? (ev st `((AloemacsModeLine new) row ,control 15)) "a\e[31m\t\r\n ↕ ↔ ×")
  (def! st 'ed `(AloemacsEditor new (Text from-string "") (Position new 0 0) #f 0 0
                   (List empty) ,no-mark 0))
  (check-equal? (ev st `(ed safe-cells ((AloemacsModeLine new) row ,control 15)))
                "a [31m    ↕ ↔ ×"))

;; 5. One-view frames.
(define untitled-12
  (string-append "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H" LIGHT "untitl ↕ ↔ ×" PLAIN
                 "\e[4;1H\e[1;1H\e[?25h"))
(define untitled-12-today
  (string-append "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H" LIGHT "untitled ---" PLAIN
                 "\e[4;1H\e[1;1H\e[?25h"))
(define untitled-7
  (string-append "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H" LIGHT "u ↕ ↔ ×" PLAIN
                 "\e[4;1H\e[1;1H\e[?25h"))
(define untitled-6
  (string-append "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H" LIGHT "untitl" PLAIN
                 "\e[4;1H\e[1;1H\e[?25h"))
(define s0-body (lines->body '("hello" "world" "xyz") 22))
(define s0-row (string-append "/cwd/a.txt " (dashes 63) " ↕ ↔ ×"))
(define (one-view body cursor echo final)
  (string-append "\e[?25l\e[2J\e[H" body cursor "\e[?25h\e[?25l\e[23;1H" (lit s0-row)
                 "\e[24;1H" echo final "\e[?25h"))

(test-case "one-view frames end the bar with the group from seven columns"
  (define-values (st calls) (session-state))
  (paint st 's 12 4 untitled-12 calls)
  (check-not-equal? (ev st '(s frame 12 4)) untitled-12-today)
  (paint st 's 7 4 untitled-7 calls)
  (paint st 's 6 4 untitled-6 calls)
  (check-one-bar untitled-12 12)
  (check-one-bar untitled-7 7)
  (check-one-bar untitled-6 6)
  (check-equal? (string-length s0-row) 80)
  (paint st 's0 80 24 (one-view s0-body "\e[1;1H" "" "\e[1;1H") calls)
  (def! st 'saved '(s0 with-echo "saved"))
  (paint st 'saved 80 24 (one-view s0-body "\e[1;1H" "saved: /cwd/a.txt" "\e[1;1H") calls)
  (def! st 'searching '(s0 handle-key "find"))
  (check-true (ev st '(searching searching)))
  (paint st 'searching 80 24 (one-view s0-body "\e[1;1H" "search: " "\e[1;1H") calls)
  (def! st 'prompting '((s0 handle-key "ctrl-x") handle-key "find"))
  (check-true (ev st '((prompting prompt) present?)))
  (paint st 'prompting 80 24 (one-view s0-body "\e[1;1H" "Find file: /cwd/" "\e[24;17H") calls)
  (def! st 'moved `(s0 with-editor (AloemacsEditor new (Text from-string ,contents)
                      (Position new 1 1) #f 1 1 (List empty) ,no-mark 22)))
  (paint st 'moved 80 24 (one-view (lines->body '("orld" "yz") 22) "\e[1;1H" "" "\e[1;1H") calls)
  (for ([s '(s0 saved searching prompting moved)])
    (check-one-bar (ev st `(,s frame 80 24)) 80))
  ;; A control name paints safe after the clip and stays raw in the buffer.
  (def! st 'ctl `(s0 with-current-path (Path new ,control)))
  (check-equal? (ev st '((ctl current-buffer) name)) control)
  (paint st 'ctl 15 4
    (string-append "\e[?25l\e[2J\e[Hhello\r\nworld\e[1;1H\e[?25h\e[?25l\e[3;1H"
                   LIGHT "a [31m    ↕ ↔ ×" PLAIN "\e[4;1H\e[1;1H\e[?25h")
    calls)
  (check-one-bar (ev st '(ctl frame 15 4)) 15)
  ;; The find-file prompt asked the Fs for its directory; framing asked for nothing.
  (check-equal? (unbox calls) '((root? "/cwd/a.txt") (parent "/cwd/a.txt"))))

;; 6. Split frames, from raw constructors.
(define history '(List of (UndoFrame new (Text from-string "old") (Position new 0 1) 2 3)))
(define (indexed lines [focus 0])
  `(Text indexed (List of ,@(reverse (take lines focus))) ,(list-ref lines focus)
     (List of ,@(drop lines (add1 focus))) ,focus))
(define (editor text [line 0] [col 0] [top 0] [left 0])
  `(AloemacsEditor new ,text (Position new ,line ,col) #f ,top ,left ,history
     (Option Some (Position new 0 1)) 0))
(define (buffer id ed name) `(AloemacsBuffer new ,ed (Option Some (Path new ,name)) ,id))
(define (zipper bs [focus 0])
  `(AloemacsBuffers new (List of ,@(reverse (take bs focus))) ,(list-ref bs focus)
     (List of ,@(drop bs (add1 focus)))))
(define (leaf id bid top left point)
  `(AloemacsWindowTree Leaf
     (AloemacsView new ,id ,bid ,top ,left (Position new ,@point) #f (Option None))))
(define (right a b) `(AloemacsWindowTree Right ,a ,b 1 1))
(define (below a b) `(AloemacsWindowTree Below ,a ,b 1 1))
(define (session bs tree selected w h)
  `(AloemacsSession new ,bs (s fs) "" #f "" (Position new 0 0) #f #f (s kill-ring)
     (s pending) (s prompt) (s last-submission) (s waiting-command)
     (AloemacsWindows new ,tree ,selected ,w ,h (Option None))))
(define (multi rows h cursor)
  (string-append "\e[?25l\e[2J\e[H" (string-join rows "\r\n") (format "\e[~a;1H" h) cursor "\e[?25h"))
(define (rows! st s w h expected)
  (def! st 'composed `(((,s windows) tree) frame-rows (,s buffers)
                       (AloemacsWindowRect new 0 0 ,w ,h) ((,s windows) selected)))
  (same st 'composed `(List of ,@expected))
  (for ([row expected])
    (check-equal? (string-length (visible row)) w (format "visible width of ~s" row))))

(define a-lines '("abcdef" "ghijkl" "mnopqr" "stuvwx" "yz0123"))
(define b-lines '("ABCDE" "FGHIJ" "KLMNO" "PQRST" "UVWXY"))
(define text-lines '("hello" "world" "xyz"))
(define (text-row i w) (pad (if (< i (length text-lines)) (list-ref text-lines i) "") w))

(test-case "split frames: every tall leaf at least seven wide ends its bar with the group"
  (define-values (st calls) (session-state))
  ;; The spec's stacked example, 8 by 6.
  (def! st 'a (buffer 0 (editor (indexed '("one" "two" "three" "four"))) "/a"))
  (def! st 'v (session (zipper '(a)) (below (leaf 0 0 0 0 '(0 0)) (leaf 1 0 2 0 '(0 0))) 0 8 6))
  (define stacked-rows
    (list "one     " "two     " (lit "/a ↕ ↔ ×") "three   " (dark "/a ↕ ↔ ×")))
  (define stacked
    "\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a ↕ ↔ ×\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a ↕ ↔ ×\e[0m\e[6;1H\e[1;1H\e[?25h")
  (check-equal? (multi stacked-rows 6 "\e[1;1H") stacked)
  (paint st 'v 8 6 stacked calls)
  (rows! st 'v 8 5 stacked-rows)
  (check-equal? (occurrences stacked LIGHT) 1)
  (check-equal? (occurrences stacked DARK) 1)
  (check-equal? (occurrences stacked GROUP) 2)
  (check-true (string-contains? stacked (string-append DARK "/a ↕ ↔ ×" PLAIN)))
  ;; The window-bars spec's mixed nesting at 9 by 6: leaves 4 wide, unchanged.
  (def! st 'ma (buffer 0 (editor (indexed a-lines 3) 3 2 3 1) "/a"))
  (def! st 'mb (buffer 1 (editor (indexed b-lines 1) 1 2 1 2) "/b"))
  (def! st 'mixed-v (session (zipper '(ma mb))
                             (right (below (leaf 0 0 0 0 '(3 2)) (leaf 1 0 3 1 '(3 2)))
                                    (leaf 2 1 1 2 '(1 2)))
                             1 9 6))
  (define mixed
    "\e[?25l\e[2J\e[Habcd|HIJ \r\nghij|MNO \r\n\e[38;5;252;48;5;239m/a -\e[0m|RST \r\ntuvw|WXY \r\n\e[38;5;16;48;5;250m/a -\e[0m|\e[38;5;252;48;5;239m/b -\e[0m\e[6;1H\e[4;2H\e[?25h")
  (paint st 'mixed-v 9 6 mixed calls)
  (check-false (regexp-match? label-rx mixed))
  ;; split-right at 80 by 24: (0,0,40,23) and (41,0,39,23).
  (def! st 'sr '(s0 split-right))
  (same st '(((sr windows) tree) rect-for 0 (AloemacsWindowRect new 0 0 80 23))
        '(Option Some (AloemacsWindowRect new 0 0 40 23)))
  (same st '(((sr windows) tree) rect-for 1 (AloemacsWindowRect new 0 0 80 23))
        '(Option Some (AloemacsWindowRect new 41 0 39 23)))
  (define right-bar
    (string-append (lit (string-append "/cwd/a.txt " (dashes 23) " ↕ ↔ ×")) "|"
                   (dark (string-append "/cwd/a.txt " (dashes 22) " ↕ ↔ ×"))))
  (define right-rows
    (append (for/list ([i (in-range 22)]) (string-append (text-row i 40) "|" (text-row i 39)))
            (list right-bar)))
  (paint st 'sr 80 24 (multi right-rows 24 "\e[1;1H") calls)
  (rows! st 'sr 80 23 right-rows)
  (define shown-right (visible right-bar))
  (check-equal? (string-ref shown-right 39) TIMES)
  (check-equal? (string-ref shown-right 40) #\|)
  (check-equal? (string-ref shown-right 79) TIMES)
  (check-true (string-contains? right-bar (string-append (string TIMES) PLAIN "|" DARK)))
  (check-true (string-suffix? right-bar (string-append (string TIMES) PLAIN)))
  ;; split-below at 80 by 24: rows 11 and 22 are the bars.
  (def! st 'sb '(s0 split-below))
  (define below-rows
    (append (for/list ([i (in-range 11)]) (text-row i 80)) (list (lit s0-row))
            (for/list ([i (in-range 10)]) (text-row i 80)) (list (dark s0-row))))
  (paint st 'sb 80 24 (multi below-rows 24 "\e[1;1H") calls)
  (rows! st 'sb 80 23 below-rows)
  (for ([i '(11 22)] [open (list LIGHT DARK)])
    (define row (list-ref below-rows i))
    (check-true (string-prefix? row open))
    (check-true (string-suffix? row (string-append GROUP PLAIN)))
    (for ([col '(75 77 79)] [c (list UPDOWN LEFTRIGHT TIMES)])
      (check-equal? (string-ref (visible row) col) c)))
  ;; A Below whose lower leaf is one row tall: that leaf is text, no bar, no group.
  (def! st 'sa (buffer 41 (editor (indexed a-lines 0)) "/a"))
  (def! st 'short (session (zipper '(sa)) (below (leaf 0 41 0 0 '(0 0)) (leaf 1 41 0 0 '(0 0)))
                           0 9 4))
  (def! st 'top '((AloemacsWindowRect new 0 0 9 3) top 1 1))
  (def! st 'bottom '((AloemacsWindowRect new 0 0 9 3) bottom 1 1))
  (define top-rows (ev st '(top rows)))
  (define bottom-rows (ev st '(bottom rows)))
  (check-equal? (+ top-rows bottom-rows) 3)
  (check-true (>= top-rows 2))
  (check-true (< bottom-rows 2))
  (define (leaf-rows n selected?)
    (if (>= n 2)
        (append (for/list ([i (in-range (sub1 n))]) (pad (list-ref a-lines i) 9))
                (list ((if selected? lit dark) "/a  ↕ ↔ ×")))
        (for/list ([i (in-range n)]) (pad (list-ref a-lines i) 9))))
  (define short-rows (append (leaf-rows top-rows #t) (leaf-rows bottom-rows #f)))
  (paint st 'short 9 4 (multi short-rows 4 "\e[1;1H") calls)
  (rows! st 'short 9 3 short-rows)
  (check-equal? (occurrences (apply string-append short-rows) GROUP) 1)
  (check-true (string-suffix? (list-ref short-rows (sub1 top-rows)) (string-append GROUP PLAIN)))
  (for ([row (drop short-rows top-rows)])
    (check-false (regexp-match? label-rx row))
    (check-equal? (visible row) row))
  (check-equal? (unbox calls) '()))

;; 7. Pictures.
(test-case "recorded pictures paint the labelled bytes a fresh build paints"
  (define-values (st calls) (session-state))
  (def! st 'sr '(s0 split-right))
  (define before (ev st '(sr frame 80 24)))
  (check-equal? (occurrences before GROUP) 2)
  (def! st 'rec '(sr record-pictures 80 24))
  (check-equal? (ev st '(rec frame 80 24)) before)
  (check-equal? (ev st '(rec frame 80 24)) before)
  (check-equal? (ev st '((((rec windows) tree) leaves) fold 0
                          (fn (count view) (if ((view picture) present?) (count + 1) count))))
                2)
  (same st '(rec buffers) '(sr buffers))
  (for ([field '(echo searching query origin wrapped failing kill-ring pending prompt
                 last-submission waiting-command)])
    (same st `(rec ,field) `(sr ,field)))
  (for ([field '(selected columns rows)])
    (same st `((rec windows) ,field) `((sr windows) ,field)))
  (for ([field '(id buffer-id scroll-row scroll-col point locked)])
    (same st `((((rec windows) tree) leaves) map (fn (view) (view ,field)))
          `((((sr windows) tree) leaves) map (fn (view) (view ,field)))))
  (check-equal? (unbox calls) '()))

;; 8. Labels press. The 001 contract for the selected window; the full
;; press tables are in mode-buttons-press.rkt.
(test-case "a left press on a label sends the window command the label names"
  (define-values (st calls) (session-state))
  (same st '(s0 handle-event "mouse down left 75 22") '(s0 split-below))
  (same st '(s0 handle-event "mouse down left 77 22") '(s0 split-right))
  (same st '(s0 handle-event "mouse down left 79 22") '(s0 delete-window))
  (check-equal? (unbox calls) '()))

;; 9. Runner.
(test-case "the runner writes the labelled 12 by 4 frame once per key"
  (define keys '("x" "escape"))
  (define remaining (box keys))
  (define reads (box 0))
  (define writes (box 0))
  (define sizes (box 0))
  (define events '())
  (define (record! e) (set! events (append events (list e))))
  (define out
    (make-output-port 'mode-buttons always-evt
      (lambda (bytes start end _non-block? _breakable?)
        (if (= start end)
            (record! 'flush)
            (begin (set-box! writes (add1 (unbox writes)))
                   (record! (list 'write (bytes->string/utf-8 (subbytes bytes start end))))))
        (- end start))
      void))
  (define term
    (make-term-receiver out
      (lambda ()
        (define key (car (unbox remaining)))
        (set-box! remaining (cdr (unbox remaining)))
        (set-box! reads (add1 (unbox reads)))
        (record! (list 'key key))
        key)
      (lambda ()
        (define n (unbox sizes))
        (set-box! sizes (add1 n))
        (record! (if (even? n) '(columns 12) '(rows 4)))
        (values 12 4))))
  (define-values (fs calls) (counted-fs))
  (run-aloemacs-with-hosts term fs)
  (define x-frame
    (string-append "\e[?25l\e[2J\e[Hx\r\n\e[1;2H\e[?25h\e[?25l\e[3;1H" LIGHT "untitl ↕ ↔ ×" PLAIN
                   "\e[4;1H\e[1;2H\e[?25h"))
  (check-equal? events
    (list '(columns 12) '(rows 4) (list 'write untitled-12) 'flush '(key "x")
          '(columns 12) '(rows 4) (list 'write x-frame) 'flush '(key "escape")))
  (check-equal? (unbox remaining) '())
  (check-equal? (unbox reads) 2)
  (check-equal? (unbox writes) 2)
  (check-equal? (unbox sizes) 4)
  (check-equal? (filter (lambda (c) (memq (car c) '(read write))) (unbox calls)) '()))
