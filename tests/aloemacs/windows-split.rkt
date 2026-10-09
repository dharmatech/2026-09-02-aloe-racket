#lang racket/base

(require racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt" "../../host/racket/term.rkt"
         "../../host/racket/aloemacs-run.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new ""))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define no-prompt '(if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0))))
(define no-submission '(if #t (Option None) (Option Some "")))
(define no-command '(if #t (Option None) (Option Some (AloemacsCommand SaveAs))))
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (dtype st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (loaded)
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  st)
(define (counted-fs [host-name 'FsHost] [contents "abc\ndef"])
  (define disk (make-fs-double "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
    (hash "/cwd/a.txt" contents "/cwd/b.txt" "disk b")))
  (define calls (box '()))
  (define (forward selector args)
    (set-box! calls (append (unbox calls) (list (cons selector args))))
    (host-receiver-send disk selector args))
  (define interface
    (make-host-interface host-name
      (for/list ([method (in-list (host-interface-methods fs-interface))])
        (define selector (host-method-selector method))
        (define params (host-method-parameter-types method))
        (make-host-method selector params (host-method-return-type method)
          (case (length params)
            [(0) (lambda (_) (forward selector '()))]
            [(1) (lambda (_ a) (forward selector (list a)))]
            [(2) (lambda (_ a b) (forward selector (list a b)))])))))
  (values (make-host-receiver interface #f) calls disk))
(define (state [host-name 'FsHost])
  (define st (loaded))
  (define-values (host calls disk) (counted-fs host-name))
  (driver-inject-host! st 'fs-host host)
  (values st calls))

;; Expected values use raw constructors and selectors only. In particular,
;; allocation, dispatch, split, fit and paint never build an expected value.
(define (indexed lines [focus 0])
  `(Text indexed (List of ,@(reverse (take lines focus))) ,(list-ref lines focus)
     (List of ,@(drop lines (add1 focus))) ,focus))
(define rich-history
  '(List of (UndoFrame new (Text from-string "previous") (Position new 0 2) 1 2)))
(define (editor text [line 0] [column 0] [row 0] [left 0] [rows 0]
                #:quit [quit #f] #:history [history rich-history]
                #:mark [mark '(Option Some (Position new 0 1))])
  `(AloemacsEditor new ,text (Position new ,line ,column) ,quit ,row ,left
     ,history ,mark ,rows))
(define (buffer id ed [path no-path]) `(AloemacsBuffer new ,ed ,path ,id))
(define (zipper bs [focus 0])
  `(AloemacsBuffers new (List of ,@(reverse (take bs focus))) ,(list-ref bs focus)
     (List of ,@(drop bs (add1 focus)))))
(define (leaf id [bid 41] [row 0] [col 0] [lock #f])
  `(AloemacsWindowTree Leaf (AloemacsView new ,id ,bid ,row ,col ,lock (Option None))))
(define (below a b) `(AloemacsWindowTree Below ,a ,b))
(define (right a b) `(AloemacsWindowTree Right ,a ,b))
(define (config tree selected [columns 9] [rows 6])
  `(AloemacsWindows new ,tree ,selected ,columns ,rows))
(define (rect x y columns rows) `(AloemacsWindowRect new ,x ,y ,columns ,rows))
(define active-prompt '(Option Some (AloemacsPrompt new "P\t" "x\ry" 2 "" (List empty) (List empty) 0)))
(define waiting '(Option Some (AloemacsCommand SaveAs)))
(define pending '(Option Some aloemacs-ctrl-x-keymap))
(define (session bs tree [selected 7] #:columns [columns 9] #:rows [rows 6]
                 #:echo [echo "saved"] #:searching [searching #f]
                 #:prompt [prompt no-prompt] #:pending [prefix no-pending]
                 #:waiting [slot waiting])
  `(AloemacsSession new ,bs (Fs new fs-host) ,echo ,searching "q\tlong"
     (Position new 4 2) #t #t (List of "newest" "older") ,prefix ,prompt
     (Option Some "/must-not-write") ,slot ,(config tree selected columns rows)))
(define (rebuild s #:buffers [bs `(,s buffers)] #:windows [w `(,s windows)]
                 #:echo [echo `(,s echo)] #:searching [searching `(,s searching)]
                 #:query [query `(,s query)] #:origin [origin `(,s origin)]
                 #:wrapped [wrapped `(,s wrapped)] #:failing [failing `(,s failing)]
                 #:ring [ring `(,s kill-ring)] #:pending [prefix `(,s pending)]
                 #:prompt [prompt `(,s prompt)] #:submission [sub `(,s last-submission)]
                 #:waiting [slot `(,s waiting-command)])
  `(AloemacsSession new ,bs (,s fs) ,echo ,searching ,query ,origin ,wrapped ,failing
     ,ring ,prefix ,prompt ,sub ,slot ,w))
(define fields '(buffers fs echo searching query origin wrapped failing kill-ring
                         pending prompt last-submission waiting-command windows))
(define (same-session st actual expected)
  (def! st 'actual actual)
  (def! st 'expected expected)
  (same st 'actual 'expected)
  (for ([field fields]) (same st `(actual ,field) `(expected ,field))))
(define (cursor row col) (format "\e[~a;~aH" row col))
(define (multi lines row col [echo-row 6] [echo ""])
  (string-append "\e[?25l\e[2J\e[H" (string-join lines "\r\n")
                 (if echo-row (string-append (cursor echo-row 1) echo) "")
                 (cursor row col) "\e[?25h"))
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
;; Name rows are bars: LIGHT on the selected view, DARK on every other split
;; view. An empty row stays empty.
(define LIGHT "\e[38;5;16;48;5;250m")
(define DARK "\e[38;5;252;48;5;239m")
(define PLAIN "\e[0m")
(define (light row) (if (string=? row "") "" (string-append LIGHT row PLAIN)))
(define (dark row) (if (string=? row "") "" (string-append DARK row PLAIN)))
(define (single lines row col [echo-row #f] [echo ""] [final-row row] [final-col col]
                #:name [name "untitled"] #:width [width 0])
  (string-append "\e[?25l\e[2J\e[H"
    (if echo-row (text-body (string-join lines "\r\n") echo-row) (string-join lines "\r\n"))
    (format "\e[~a;~aH\e[?25h" row col)
    (if echo-row
        (string-append "\e[?25l"
          (if (>= echo-row 3) (format "\e[~a;1H~a" (sub1 echo-row) (light (mode-row name width))) "")
          (format "\e[~a;1H~a\e[~a;~aH\e[?25h" echo-row echo final-row final-col)) "")))
(define (paint st s columns rows expected)
  (define before (for/list ([expr (list s `(,s buffers) `(,s windows) `((,s editor) text))])
                   (ev st expr)))
  (check-equal? (ev st `(,s frame ,columns ,rows)) expected)
  (check-equal? (for/list ([expr (list s `(,s buffers) `(,s windows) `((,s editor) text))])
                  (ev st expr)) before))
(define ab-text (indexed '("abc" "def")))
(define (simple! st)
  (def! st 'a (buffer 41 (editor ab-text)))
  (def! st 's (session (zipper '(a)) (leaf 7))))
(define commands
  '(Newline BackwardDelete MoveLeft MoveRight MoveUp MoveDown LineStart LineEnd
    PageUp PageDown BufferStart BufferEnd RequestQuit Undo SetMark Kill KillLine
    Yank Find Save SelfInsert SwitchBuffer KillBuffer FindFile SaveAs SelectBuffer
    SplitBelow SplitRight DeleteWindow OtherWindow ToggleWindowLock))
(define orientations '((split-below SplitBelow "2") (split-right SplitRight "3")))
(define (datums path) (call-with-input-file path (lambda (in) (port->list read in))))

(test-case "exact constructors, checked sends, concrete host retention, startup and maps"
  (define st0 (loaded))
  (for ([name '(fs-host term aloemacs-editor)])
    (check-false (env-bound? (driver-runtime-environment st0) name)))
  (define source (datums file-path))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) source))
  (define (decl name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (check-equal? (take source 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B)
      AloemacsBinding AloemacsSearchScan (AloemacsSession H)))
  (check-equal? (caddr (decl 'AloemacsCommand))
    `(constructors ,@(map (lambda (c) `(,c (fields))) commands)))
  (check-equal? (map (lambda (m) (drop-right m 1)) (cdr (cadddr (decl 'AloemacsCommand))))
                '((name () String)))
  (check-equal? (caddr (decl '(AloemacsSession H)))
    '(fields (buffers AloemacsBuffers) (fs (Fs H)) (echo String) (searching Bool)
      (query String) (origin Position) (wrapped Bool) (failing Bool) (kill-ring (List String))
      (pending (Option (AloemacsKeymap AloemacsBinding))) (prompt (Option AloemacsPrompt))
      (last-submission (Option String)) (waiting-command (Option AloemacsCommand))
      (windows AloemacsWindows)))
  (for ([host-name '(FsHost SplitDisk)])
    (define-values (st calls) (state host-name))
    (simple! st)
    (for ([o orientations] [name '("split-below" "split-right")])
      (define send (car o))
      (define command (cadr o))
      (check-equal? (ev st `((AloemacsCommand ,command) name)) name)
      (check-equal? (dtype st `(s ,send)) `(AloemacsSession ,host-name))
      (check-equal? (dtype st `(s execute-command (AloemacsCommand ,command) "ignored"))
                    `(AloemacsSession ,host-name))
      (check-equal? (drop-right (assoc send (cdr (cadddr (decl '(AloemacsSession H))))) 1)
                    `(,send () (AloemacsSession H)))
      (for ([bad (list `(s ,send 0) `(s ,send "x") `(s ,send #f)
                       `(s ,send 0 1) `(AloemacsSession ,send)
                       `(AloemacsCommand ,command 0) `(AloemacsCommand ,command "x")
                       `((AloemacsCommand ,command) run s)
                       `((AloemacsCommand ,command) name 0)
                       `(s execute-command (AloemacsCommand ,command))
                       `(s execute-command (AloemacsCommand ,command) 0)
                       `(s execute-command (AloemacsCommand ,command) "x" "y"))])
        (check-exn exn:fail:aloe-type? (lambda () (ev st bad))))
      (for ([receiver '(a (s editor) (s windows) (s buffers) 0 "x")])
        (check-exn exn:fail:aloe-type? (lambda () (ev st `(,receiver ,send))))))
    (same st '(aloemacs-ctrl-x-keymap bindings)
      '(List of (AloemacsBinding Command "save" aloemacs-save-command)
                (AloemacsBinding Command "find" (AloemacsCommand FindFile))
                (AloemacsBinding Command "kill" (AloemacsCommand SaveAs))
                (AloemacsBinding Command "b" (AloemacsCommand SelectBuffer))
                (AloemacsBinding Command "2" (AloemacsCommand SplitBelow))
                (AloemacsBinding Command "3" (AloemacsCommand SplitRight))
                (AloemacsBinding Command "0" (AloemacsCommand DeleteWindow))
                (AloemacsBinding Command "o" (AloemacsCommand OtherWindow))
                (AloemacsBinding Command "l" (AloemacsCommand ToggleWindowLock))))
    (same st '(aloemacs-ctrl-x-keymap default)
      '(if #t (Option None) (Option Some (AloemacsCommand SelfInsert))))
    (same st '((aloemacs-global-keymap bindings) map (fn (b) (b key)))
      '(List of "return" "backspace" "left" "right" "up" "down" "line-start" "line-end"
         "page-up" "page-down" "buffer-start" "buffer-end" "escape" "undo" "mark" "kill"
         "kill-line" "yank" "find" "save" "ctrl-x"))
    (same st '(aloemacs-global-keymap default) '(Option Some (AloemacsCommand SelfInsert)))
    (same st '(aloemacs-ctrl-x-keymap lookup "save") '(aloemacs-global-keymap lookup "save"))
    (ev st `(load ,(path->string main-path)))
    (same-session st 'aloemacs-editor
      `(AloemacsSession new
         ,(zipper (list (buffer 0 (editor '(Text from-string "")
           #:history '(List empty) #:mark no-mark))))
         (Fs new fs-host) "" #f "" (Position new 0 0) #f #f (List empty)
         ,no-pending ,no-prompt ,no-submission ,no-command ,(config (leaf 0 0) 0 0 0)))
    (check-equal? (unbox calls) '())))

(test-case "minimum and odd/even extents: exact geometry, IDs, selection and one selected fit"
  (define-values (st calls) (state))
  ;; Explicit allocation tables, independent of rectangle/split helpers.
  ;; Right keeps its divider column; Below spends no row and its top takes
  ;; the odd row, so the bottom starts at the top's height.
  (for ([o orientations])
    (define vertical? (eq? (car o) 'split-below))
    (for ([extent (if vertical? '(4 5 6 7 8) '(3 4 5 6 7 8))]
          [early (if vertical? '(2 3 3 4 4) '(1 2 2 3 3 4))]
          [late (if vertical? '(2 2 3 3 4) '(1 1 2 2 3 3))]
          [offset (if vertical? '(2 3 3 4 4) '(2 3 3 4 4 5))])
      (define columns (if vertical? 9 extent))
      (define rows (if vertical? (add1 extent) 6))
      (define text (indexed '("abcdefghi" "jklmnopqr" "stuvwxyz" "last")))
      (def! st 'a (buffer 41 (editor text 0 0)))
      (def! st 's (session (zipper '(a)) (leaf 7) #:columns columns #:rows rows))
      (define t ((if vertical? below right) (leaf 7) (leaf 8)))
      (define h (if vertical? early 5))
      (define ed (editor text 0 0 0 0 (if (>= h 2) (sub1 h) h)))
      (same-session st `(s ,(car o))
        (rebuild 's #:buffers (zipper (list (buffer 41 ed)))
          #:windows (config t 7 columns rows) #:echo ""))
      (def! st 'result `(s ,(car o)))
      (same st `(((result windows) tree) rect-for 7 ,(rect 0 0 columns (sub1 rows)))
        `(Option Some ,(if vertical? (rect 0 0 columns early) (rect 0 0 early 5))))
      (same st `(((result windows) tree) rect-for 8 ,(rect 0 0 columns (sub1 rows)))
        `(Option Some ,(if vertical? (rect 0 offset columns late) (rect offset 0 late 5))))
      (same-session st `(result ensure-visible ,columns ,rows) 'result)))
  ;; Below needs four nominal rows: at extent three it refuses.
  (def! st 's (session (zipper '(a)) (leaf 7) #:columns 9 #:rows 4))
  (same-session st '(s split-below) (rebuild 's #:echo "failed"))
  ;; At one terminal row, Right can still split; Below cannot.
  (simple! st)
  (def! st 'one (rebuild 's #:windows (config (leaf 7) 7 3 1)))
  (same-session st '(one split-right)
    (rebuild 'one #:buffers (zipper (list (buffer 41 (editor ab-text 0 0 0 0 1))))
      #:windows (config (right (leaf 7) (leaf 8)) 7 3 1) #:echo ""))
  (def! st 'r '(one split-right))
  (paint st 'r 3 1 (multi '("a|a") 1 1 #f))
  (same-session st '(one split-below) (rebuild 'one #:echo "failed"))
  (check-equal? (unbox calls) '()))

(test-case "guards use remembered nominal geometry, never fallback display geometry"
  (define-values (st calls) (state))
  (simple! st)
  (for ([size '((0 0) (0 6) (9 0) (-1 6) (9 -1))])
    (def! st 'raw (rebuild 's #:windows (apply config (leaf 7) 7 size)))
    (for ([o orientations])
      (same-session st `(raw ,(car o)) (rebuild 'raw #:echo "failed"))))
  (for ([o orientations])
    (for ([extent '(1 2)])
      (define vertical? (eq? (car o) 'split-below))
      (def! st 'raw (rebuild 's #:windows
        (config (leaf 7) 7 (if vertical? 9 extent) (if vertical? (add1 extent) 6))))
      (same-session st `(raw ,(car o)) (rebuild 'raw #:echo "failed")))
    (def! st 'locked (rebuild 's #:windows (config (leaf 7 41 0 0 #t) 7)))
    (same-session st `(locked ,(car o)) (rebuild 'locked #:echo "failed")))
  ;; Selected bottom has zero height, though full-screen fallback is 9 x 1.
  (define zero-row (below (leaf 99 41 8 2 #t) (leaf 7)))
  (def! st 'zero (rebuild 's #:windows (config zero-row 7 9 2)))
  (same st '((zero windows) fit-rect 9 2) (rect 0 0 9 1))
  (same st `(((zero windows) tree) rect-for 7 ,(rect 0 0 9 1))
    `(Option Some ,(rect 0 1 9 0)))
  (for ([o orientations])
    (same-session st `(zero ,(car o)) (rebuild 'zero #:echo "failed")))
  ;; Zero selected width must also forbid Below despite its nominal height 5.
  (def! st 'zero (rebuild 's #:windows
    (config (right (leaf 99 41 8 2 #t) (leaf 7)) 7 1 6)))
  (same st '((zero windows) fit-rect 1 6) (rect 0 0 1 5))
  (for ([o orientations])
    (same-session st `(zero ,(car o)) (rebuild 'zero #:echo "failed")))
  ;; Selected is positive (4 x 2); another zero-height view forces fallback.
  ;; A Below at extent two gives one row each, so the zero-height view is the
  ;; bottom of a nested Below at extent one.
  ;; Right succeeds using selected width 4, then fallback text fit uses 9 x 1.
  (define bad-sibling
    (below (leaf 99 41 33 44 #t) (below (leaf 3 41 55 66) (leaf 5 41 77 88))))
  (define t (right (leaf 7) bad-sibling))
  (def! st 'raw (rebuild 's #:windows (config t 7 9 3)))
  (same st '((raw windows) fit-rect 9 3) (rect 0 0 9 2))
  (same-session st '(raw split-below) (rebuild 'raw #:echo "failed"))
  (define rt (right (right (leaf 7) (leaf 100)) bad-sibling))
  (same-session st '(raw split-right)
    (rebuild 'raw #:buffers (zipper (list (buffer 41 (editor ab-text 0 0 0 0 1))))
      #:windows (config rt 7 9 3) #:echo ""))
  (def! st 'r '(raw split-right))
  (paint st 'r 9 3 (single '("abc" "def") 1 1 3 "" #:name "untitled" #:width 9))
  (check-equal? (unbox calls) '()))

(test-case "sparse IDs, maximum away from selected, live origin capture and inactive locks"
  (define-values (st calls) (state))
  (define lines (for/list ([i (in-range 15)]) (format "line~a-abcdefghijk" i)))
  (define text (indexed lines 12))
  (def! st 'a (buffer 41 (editor text 10 9 2 3 17 #:quit #t)
                     '(Option Some (Path new "/cwd/a.txt"))))
  (def! st 'b (buffer 9 (editor '(Text from-string "other") 0 2 77 88 13)))
  (def! st 'c (buffer 101 (editor '(Text from-string "unshown"))))
  (define sibling (right (leaf 99 9 77 88 #t) (leaf 3 41 99 101 #t)))
  (define tree (below (leaf 7 41 2 3) sibling))
  (for ([o orientations])
    (def! st 's (session (zipper '(b a c) 1) tree #:columns 9 #:rows 13
      #:searching #t #:prompt active-prompt #:pending pending))
    (define vertical? (eq? (car o) 'split-below))
    (define fitted-row (if vertical? 9 6))
    (define fitted-col (if vertical? 3 6))
    (define h (if vertical? 2 5))
    (define replacement ((if vertical? below right)
      (leaf 7 41 fitted-row fitted-col) (leaf 100 41 2 3)))
    (define expected-tree (below replacement sibling))
    (same-session st `(s ,(car o))
      (rebuild 's #:buffers (zipper (list 'b (buffer 41
        (editor text 10 9 fitted-row fitted-col h #:quit #t) '(a path)) 'c) 1)
        #:windows (config expected-tree 7 9 13)))
    (def! st 'r `(s ,(car o)))
    (same st '(((r windows) tree) leaves)
      `(List of (AloemacsView new 7 41 ,fitted-row ,fitted-col #f (Option None))
                (AloemacsView new 100 41 2 3 #f (Option None))
                (AloemacsView new 99 9 77 88 #t (Option None))
                (AloemacsView new 3 41 99 101 #t (Option None))))
    (for ([id '(99 3)] [r '((0 6 4 6) (5 6 4 6))])
      (same st `(((r windows) tree) rect-for ,id ,(rect 0 0 9 12))
        `(Option Some ,(apply rect r)))))
  (check-equal? (unbox calls) '()))

(test-case "repeated and mixed real splits retain binary order and full T/cross frames"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed '("a")))))
  (def! st 's (session (zipper '(a)) (leaf 7) #:columns 7 #:rows 6))
  (define l (leaf 7))
  (define n (leaf 8))
  (define m (leaf 9))
  (def! st 'r '(s split-right))
  (same st '((r windows) tree) (right l n))
  (paint st 'r 7 6 (multi (list "a  |a  " "   |   " "   |   " "   |   "
                                (string-append (light "unt") "|" (dark "unt"))) 1 1 6 ""))
  (def! st 'rb '(r split-below))
  (same st '((rb windows) tree) (right (below l m) n))
  (same st '(((rb windows) tree) leaves)
    '(List of (AloemacsView new 7 41 0 0 #f (Option None)) (AloemacsView new 9 41 0 0 #f (Option None))
              (AloemacsView new 8 41 0 0 #f (Option None))))
  (paint st 'rb 7 6 (multi (list "a  |a  " "   |   " (string-append (light "unt") "|   ")
                                 "a  |   " (string-append (dark "unt") "|" (dark "unt")))
                           1 1 6 ""))
  (def! st 'b '(s split-below))
  (def! st 'br '(b split-right))
  (same st '((br windows) tree) (below (right l m) n))
  (paint st 'br 7 6 (multi (list "a  |a  " "   |   " (string-append (light "unt") "|" (dark "unt"))
                                 "a      " (dark "untitle")) 1 1 6 ""))
  ;; Arrange another selected leaf with raw constructors, never an entry API.
  (def! st 'other (rebuild 'rb #:windows (config (right (below l m) n) 8 7 6)))
  (def! st 'cross '(other split-below))
  (same st '((cross windows) tree) (right (below l m) (below n (leaf 10))))
  (paint st 'cross 7 6
    (multi (list "a  |a  " "   |   " (string-append (dark "unt") "|" (light "unt"))
                 "a  |a  " (string-append (dark "unt") "|" (dark "unt"))) 1 5 6 ""))
  (def! st 'wide (rebuild 's #:windows (config l 7 15 6)))
  (def! st 'rr '((wide split-right) split-right))
  (same st '((rr windows) tree) (right (right l m) n))
  (same st `(((rr windows) tree) rect-for 8 ,(rect 0 0 15 5))
    `(Option Some ,(rect 8 0 7 5)))
  (paint st 'rr 15 6
    (multi (list "a  |a  |a      " "   |   |       " "   |   |       " "   |   |       "
                 (string-append (light "unt") "|" (dark "unt") "|" (dark "untitle"))) 1 1 6 ""))
  (def! st 'tall (rebuild 's #:windows (config l 7 7 16)))
  (def! st 'bb '((tall split-below) split-below))
  (same st '((bb windows) tree) (below (below l m) n))
  (same st `(((bb windows) tree) rect-for 8 ,(rect 0 0 7 15))
    `(Option Some ,(rect 0 8 7 7)))
  (paint st 'bb 7 16
    (multi (list "a      " "       " "       " (light "untitle")
                 "a      " "       " "       " (dark "untitle")
                 "a      " "       " "       " "       " "       " "       " (dark "untitle"))
           1 1 16 ""))
  (check-equal? (unbox calls) '()))

(test-case "one owned editor: shared edits/undo/mark, independent origins and page height"
  (define-values (st calls) (state))
  (define text (indexed '("abcd" "efgh" "ijkl" "mnop" "qrst" "uvwx" "yz01")))
  (def! st 'a (buffer 41 (editor text 3 2 1 1 6)))
  (def! st 's (session (zipper '(a)) (leaf 7 41 1 1) #:columns 7 #:rows 6))
  (def! st 'b '(s split-below))
  (same-session st 'b (rebuild 's #:echo ""
    #:buffers (zipper (list (buffer 41 (editor text 3 2 2 1 2))))
    #:windows (config (below (leaf 7 41 2 1) (leaf 8 41 1 1)) 7 7 6)))
  (paint st 'b 7 6 (multi (list "jkl    " "nop    " (light "untitle") "fgh    " (dark "untitle"))
                          2 2 6 ""))
  (def! st 'edited '(b insert "λ"))
  (define changed (indexed '("abcd" "efgh" "ijkl" "mnλop" "qrst" "uvwx" "yz01") 3))
  (define undo-history `(List of (UndoFrame new ,text (Position new 3 2) 2 1)
    (UndoFrame new (Text from-string "previous") (Position new 0 2) 1 2)))
  (same-session st 'edited (rebuild 'b #:buffers (zipper (list (buffer 41
    (editor changed 3 3 2 1 2 #:history undo-history))))))
  (paint st 'edited 7 6 (multi (list "jkl    " "nλop   " (light "untitle") "fgh    " (dark "untitle"))
                               2 3 6 ""))
  (def! st 'undone '(edited undo))
  (same-session st 'undone 'b)
  (paint st 'undone 7 6 (multi (list "jkl    " "nop    " (light "untitle") "fgh    " (dark "untitle"))
                               2 2 6 ""))
  (same st '((b page-down) point) '(Position new 4 2))
  (same st '((b page-up) point) '(Position new 2 2))
  (same st '(((b page-down) editor) history) rich-history)
  (same st '(((b page-down) editor) mark) '(Option Some (Position new 0 1)))
  ;; The fresh child's two text rows retain the overlapping-source-row proof
  ;; while its original origin stays exact. Fit the moved selected point only.
  (def! st 'overlap-base '(b ensure-visible 7 8))
  (def! st 'overlap '(((overlap-base move-up) ensure-visible 7 8) insert "λ"))
  (paint st 'overlap 7 8
    (multi (list "jλkl   " "nop    " "rst    " (light "untitle") "fgh    " "jλkl   " (dark "untitle"))
           1 3 8 ""))
  (same st '(((overlap windows) tree) find-view 8) '(Option Some (AloemacsView new 8 41 1 1 #f (Option None))))
  (same st '((overlap editor) mark) '(Option Some (Position new 0 1)))
  (same st '(((overlap undo) editor) text) (indexed '("abcd" "efgh" "ijkl" "mnop" "qrst" "uvwx" "yz01") 2))
  ;; A shared deletion shortens below the inactive origin; it must stay there.
  (def! st 'marked `(b with-editor
    (AloemacsEditor new (b text) (Position new 6 4) #f 2 1
      ,rich-history (Option Some (Position new 0 0)) 2)))
  (def! st 'short '(marked kill))
  (define deleted-history `(List of (UndoFrame new ,text (Position new 6 4) 2 1)
    (UndoFrame new (Text from-string "previous") (Position new 0 2) 1 2)))
  (same-session st 'short (rebuild 'marked #:echo ""
    #:buffers (zipper (list (buffer 41 (editor (indexed '("")) 0 0 2 1 2
      #:history deleted-history #:mark no-mark))))
    #:ring '(List of "abcd\nefgh\nijkl\nmnop\nqrst\nuvwx\nyz01" "newest" "older")))
  (def! st 'short-fit '(short ensure-visible 7 6))
  (same st '((short-fit windows) tree) (below (leaf 7) (leaf 8 41 1 1)))
  (paint st 'short-fit 7 6
    (multi (list "       " "       " (light "untitle") "       " (dark "untitle")) 1 1 6 ""))
  (def! st 'visited '(b visited "x" (Path new "/short")))
  (same st '((visited windows) tree) (below (leaf 7) (leaf 8 41 1 1)))
  (def! st 'vfit '(visited ensure-visible 7 6))
  (paint st 'vfit 7 6
    (multi (list "x      " "       " (light "/short ") "       " (dark "/short ")) 1 1 6 ""))
  (check-equal? (unbox calls) '()))

(test-case "existing buffer operations after real splits: selected retarget and all-view kill"
  (define-values (st calls) (state))
  (simple! st)
  (def! st 'p '(s split-below))
  (define a (buffer 41 (editor ab-text 0 0 0 0 2)))
  (define fresh-text (indexed '("fresh")))
  (define fresh (buffer 42 (editor fresh-text #:history '(List empty) #:mark no-mark)))
  (define selected-new (below (leaf 7 42) (leaf 8)))
  (define (selected s bs tree)
    (rebuild s #:buffers bs #:windows (config tree 7) #:echo "" #:searching #f
      #:query "" #:origin '(Position new 0 0) #:wrapped #f #:failing #f #:pending no-pending))
  (def! st 'added '(p add-buffer "fresh"))
  (same-session st 'added (selected 'p (zipper (list a fresh) 1) selected-new))
  (def! st 'added-path '(p add-buffer "fresh" (Path new "/fresh")))
  (same-session st 'added-path (selected 'p
    (zipper (list a (buffer 42 (editor fresh-text #:history '(List empty) #:mark no-mark)
                           '(Option Some (Path new "/fresh")))) 1) selected-new))
  (same-session st '(added switch-buffer)
    (selected 'added (zipper (list a fresh)) (below (leaf 7) (leaf 8))))
  (same-session st '(added selected-buffers (AloemacsBuffers new
    (List empty) (p current-buffer) (List of (added current-buffer))))
    (selected 'added (zipper (list a fresh)) (below (leaf 7) (leaf 8))))
  (same-session st '(added select-buffer-submitted "untitled")
    (selected 'added (zipper (list a fresh) 1) selected-new))
  (same-session st '(added kill-buffer)
    (selected 'added (zipper (list a)) (below (leaf 7) (leaf 8))))
  (define empty (buffer 41 (editor (indexed '("")) #:history '(List empty) #:mark no-mark)))
  (same-session st '(p kill-buffer)
    (selected 'p (zipper (list empty)) (below (leaf 7) (leaf 8))))
  ;; All leaves of the killed ID retarget, including its inactive sibling.
  (def! st 'back '(added switch-buffer))
  (same-session st '(back kill-buffer)
    (selected 'back (zipper (list fresh)) (below (leaf 7 42) (leaf 8 42))))
  (same-session st '(p with-current-path (Path new "/renamed"))
    (rebuild 'p #:buffers (zipper (list (buffer 41 '(p editor) '(Option Some (Path new "/renamed")))))))
  (check-equal? (unbox calls) '())
  ;; Actual file visit replaces current ID, keeps inactive origin, and paints
  ;; the replacement text through both views. Count exact Fs calls.
  (def! st 'visit-result '(p visit (Path new "/cwd/b.txt")))
  (same st '(visit-result present?) #t)
  (def! st 'v '(visit-result case (None () p) (Some (value) value)))
  (define vb (buffer 41 (editor (indexed '("disk b")) #:history '(List empty) #:mark no-mark)
                     '(Option Some (Path new "/cwd/b.txt"))))
  (same-session st 'v (rebuild 'p #:buffers (zipper (list vb)) #:echo "" #:searching #f
    #:query "" #:origin '(Position new 0 0) #:wrapped #f #:failing #f
    #:ring '(List empty) #:pending no-pending #:prompt no-prompt #:waiting no-command))
  (check-equal? (unbox calls)
    '((resolve "/cwd/b.txt") (kind "/cwd/b.txt") (resolve "/cwd/b.txt")
      (kind "/cwd/b.txt") (resolve "/cwd/b.txt") (read "/cwd/b.txt")))
  (set-box! calls '())
  (def! st 'found '(p find-file-submitted "/cwd/b.txt"))
  (same-session st 'found (selected 'p
    (zipper (list a (buffer 42 (editor (indexed '("disk b")) #:history '(List empty) #:mark no-mark)
                           '(Option Some (Path new "/cwd/b.txt")))) 1) selected-new))
  (check-equal? (unbox calls)
    '((resolve "/cwd/b.txt") (kind "/cwd/b.txt") (resolve "/cwd/b.txt")
      (kind "/cwd/b.txt") (resolve "/cwd/b.txt") (read "/cwd/b.txt")))
  (set-box! calls '())
  (same-session st '(found find-file-submitted "/cwd/b.txt") 'found)
  (same-session st '(found select-buffer-submitted "/cwd/b.txt") 'found)
  (check-equal? (unbox calls) '((resolve "/cwd/b.txt")))
  (set-box! calls '())
  (same-session st '(found save-as-submitted "/cwd/a.txt")
    (rebuild 'found #:echo "saved" #:buffers (zipper (list a
      (buffer 42 '(found editor) '(Option Some (Path new "/cwd/a.txt")))) 1)))
  (check-equal? (unbox calls)
    '((resolve "/cwd/a.txt") (kind "/cwd/a.txt") (resolve "/cwd/a.txt") (write "/cwd/a.txt" "disk b"))))

(test-case "echo matrix: hidden tokens, prompt/search precedence and complete guarded refusal"
  (define-values (st calls) (state))
  (simple! st)
  (for* ([o orientations] [token '("" "saved" "failed")]
         [mode '(neither prompt search both)] [success? '(#f #t)])
    (define prompted? (memq mode '(prompt both)))
    (define searching? (and (memq mode '(search both)) #t))
    (define preserved? (or prompted? searching?))
    (define t (leaf 7 41 0 0 (not success?)))
    (def! st 'raw (session (zipper '(a)) t #:echo token #:searching searching?
      #:prompt (if prompted? active-prompt no-prompt) #:pending pending))
    (define vertical? (eq? (car o) 'split-below))
    (define result-token (if preserved? token (if success? "" "failed")))
    (define expected
      (if success?
          (rebuild 'raw #:echo result-token
            #:buffers (zipper (list (buffer 41 (editor ab-text 0 0 0 0 (if vertical? 2 4)))))
            #:windows (config ((if vertical? below right) (leaf 7) (leaf 8)) 7))
          (if preserved? 'raw (rebuild 'raw #:echo result-token))))
    (same-session st `(raw ,(car o)) expected)
    (same-session st `(raw execute-command (AloemacsCommand ,(cadr o)) "ignore-this") expected)
    (def! st 'r `(raw ,(car o)))
    (check-equal? (ev st '(r echo)) result-token)
    (define shown (cond [prompted? "P x y"] [searching? "failing: "]
                       [success? ""] [else "failed: u"]))
    (define crow (if prompted? 6 1))
    (define ccol (if prompted? 5 1))
    (if success?
        (paint st 'r 9 6
          (multi (if vertical?
                     (list "abc      " "def      " (light "untitled ") "abc      " (dark "untitled "))
                     (list "abc |abc " "def |def " "    |    " "    |    "
                           (string-append (light "unti") "|" (dark "unti"))))
                 crow ccol 6 shown))
        (paint st 'r 9 6 (single '("abc" "def" "" "" "") 1 1 6 shown crow ccol #:name "untitled" #:width 9))))
  ;; Unknown-size refusals with active owners also return the whole session.
  (for* ([token '("" "saved" "failed")] [mode '(prompt search both)] [o orientations])
    (def! st 'raw (session (zipper '(a)) (leaf 7) #:columns 0 #:rows 0 #:echo token
      #:searching (and (memq mode '(search both)) #t)
      #:prompt (if (memq mode '(prompt both)) active-prompt no-prompt) #:pending pending))
    (same-session st `(raw ,(car o)) 'raw))
  (check-equal? (unbox calls) '()))

(test-case "direct/execution/chord equivalence, pending consumption and exact input owners"
  (define-values (st calls) (state))
  (simple! st)
  (for ([o orientations])
    (define vertical? (eq? (car o) 'split-below))
    (define t ((if vertical? below right) (leaf 7) (leaf 8)))
    (define bs (zipper (list (buffer 41 (editor ab-text 0 0 0 0 (if vertical? 2 4))))))
    (define expected (rebuild 's #:buffers bs #:windows (config t 7) #:echo ""))
    (for ([actual (list `(s ,(car o))
                       `(s execute-command (AloemacsCommand ,(cadr o)) "ignored")
                       `((s handle-key "ctrl-x") handle-key ,(caddr o)))])
      (same-session st actual expected)
      (def! st 'r actual)
      (paint st 'r 9 6 (multi
        (if vertical?
            (list "abc      " "def      " (light "untitled ") "abc      " (dark "untitled "))
            (list "abc |abc " "def |def " "    |    " "    |    "
                  (string-append (light "unti") "|" (dark "unti")))) 1 1)))
    (def! st 'prefixed (rebuild 's #:echo "" #:pending pending))
    (same-session st `(prefixed ,(car o))
      (rebuild 'prefixed #:buffers bs #:windows (config t 7)))
    (same-session st `(prefixed handle-key ,(caddr o)) expected)
    (def! st 'locked (rebuild 's #:echo "" #:windows (config (leaf 7 41 0 0 #t) 7)))
    (define refused (rebuild 'locked #:echo "failed"))
    (for ([actual (list `(locked ,(car o))
                       `(locked execute-command (AloemacsCommand ,(cadr o)) "ignored")
                       `((locked handle-key "ctrl-x") handle-key ,(caddr o)))])
      (same-session st actual refused)
      (def! st 'r actual)
      (paint st 'r 9 6 (single '("abc" "def" "" "" "") 1 1 6 "failed: u" #:name "untitled" #:width 9)))
    ;; Direct sends and execute-command can act even when raw quit is true.
    (def! st 'quit-s (rebuild 's #:buffers
      (zipper (list (buffer 41 (editor ab-text #:quit #t))))))
    (define quit-expected (rebuild 'quit-s #:echo ""
      #:buffers (zipper (list (buffer 41 (editor ab-text 0 0 0 0 (if vertical? 2 4) #:quit #t))))
      #:windows (config t 7)))
    (same-session st `(quit-s ,(car o)) quit-expected)
    (same-session st `(quit-s execute-command (AloemacsCommand ,(cadr o)) "ignored")
      quit-expected)
    (for ([key (list "ctrl-x" (caddr o))])
      (same-session st `(quit-s handle-key ,key) 'quit-s)))
  (for ([key '("2" "3" "0" "o" "l")])
    (same-session st `(s handle-key ,key)
      (rebuild 's #:echo "" #:buffers (zipper (list (buffer 41
        (editor (indexed (list (string-append key "abc") "def")) 0 1
          #:history `(List of (UndoFrame new ,ab-text (Position new 0 0) 0 0)
            (UndoFrame new (Text from-string "previous") (Position new 0 2) 1 2)))))))))
  (for ([key '("x" "escape" "ctrl-x" "unknown" "" "left")])
    (same-session st `((s handle-key "ctrl-x") handle-key ,key) (rebuild 's #:echo "")))
  (for ([key '("split-below" "split-right")])
    (same-session st `(s handle-key ,key) (rebuild 's #:echo "")))
  (def! st 'p (rebuild 's #:prompt active-prompt #:pending pending))
  (same-session st '(p handle-key "ctrl-x") 'p)
  (same-session st '(p handle-key "2")
    (rebuild 'p #:prompt '(Option Some (AloemacsPrompt new "P\t" "x\r2y" 3 "" (List empty) (List empty) 0))))
  (def! st 'search (rebuild 's #:searching #t #:query "" #:wrapped #f #:failing #f
    #:origin '(Position new 0 0) #:pending no-pending))
  (same-session st '(search handle-key "3")
    (rebuild 'search #:query "3" #:failing #t))
  ;; Search precedes a constructed simultaneous prompt; named C-x ends search
  ;; and arms pending. The subsequent digit belongs to that still-active prompt.
  (def! st 'both (rebuild 'search #:prompt active-prompt))
  (same-session st '(both handle-key "2") (rebuild 'both #:query "2" #:failing #t))
  (same-session st '((both handle-key "ctrl-x") handle-key "3")
    (rebuild 'both #:searching #f #:query "" #:origin '(Position new 0 0)
      #:wrapped #f #:failing #f #:echo "" #:pending pending
      #:prompt '(Option Some (AloemacsPrompt new "P\t" "x\r3y" 3 "" (List empty) (List empty) 0))))
  (def! st 'exit '(search handle-key "ctrl-x"))
  (same-session st 'exit (rebuild 'search #:searching #f #:query "" #:echo "" #:pending pending))
  (same-session st '(exit handle-key "2")
    (rebuild 'exit #:pending no-pending #:buffers
      (zipper (list (buffer 41 (editor ab-text 0 0 0 0 2))))
      #:windows (config (below (leaf 7) (leaf 8)) 7)))
  (check-equal? (unbox calls) '()))

(test-case "general selection remains absent"
  (define-values (st calls) (state))
  (simple! st)
  (for ([bad '((s select-view 8))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st bad))))
  (check-equal? (unbox calls) '()))

(test-case "unchanged production runner: both chords, shared edit/save, shrink/growth and quit"
  (define keys '("ctrl-x" "2" "ctrl-x" "3" "x" "save" "unknown" "escape"))
  (define sizes '((9 6) (9 6) (9 6) (9 6) (9 6) (1 2) (9 6) (9 6)))
  (define start (single '("abc" "def" "" "" "") 1 1 6 "" #:name "/cwd/a.txt" #:width 9))
  (define below-frame
    (multi (list "abc      " "def      " (light "/cwd/a.tx") "abc      " (dark "/cwd/a.tx"))
           1 1 6 ""))
  (define mixed-frame
    (multi (list "abc |abc " "def |def " (string-append (light "/cwd") "|" (dark "/cwd"))
                 "abc      " (dark "/cwd/a.tx"))
           1 1 6 ""))
  (define restored-rows
    (list "abc |xabc" "ef  |def " (string-append (light "/cwd") "|" (dark "/cwd"))
          "xabc     " (dark "/cwd/a.tx")))
  (define frames
    (list start start below-frame below-frame mixed-frame
          (single '("a") 1 1 2 "/" #:name "/cwd/a.txt" #:width 1)
          (multi restored-rows 1 1 6 "saved: /c")
          (multi restored-rows 1 1 6 "")))
  (define-values (host calls disk) (counted-fs))
  (define iteration 0)
  (define events (box '()))
  (define (record event) (set-box! events (append (unbox events) (list event))))
  (define output
    (make-output-port 'split-runner always-evt
      (lambda (bytes start end _non-block? _breakable?)
        (unless (= start end)
          (record (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
        (- end start)) void))
  (define term
    (make-term-receiver output
      (lambda ()
        (record 'read)
        (when (>= iteration (length keys)) (error 'split-runner "read after quit"))
        (begin0 (list-ref keys iteration) (set! iteration (add1 iteration))))
      (lambda ()
        (record 'size)
        (when (>= iteration (length sizes)) (error 'split-runner "size after quit"))
        (apply values (list-ref sizes iteration)))))
  (run-aloemacs-with-hosts term host "/cwd/a.txt")
  (check-equal? iteration (length keys))
  (check-equal? (unbox events)
    (append-map (lambda (frame) (list 'size 'size (list 'write frame) 'read)) frames))
  (check-equal? (unbox calls)
    '((resolve "/cwd/a.txt") (resolve "/cwd/a.txt") (kind "/cwd/a.txt")
      (resolve "/cwd/a.txt") (kind "/cwd/a.txt") (resolve "/cwd/a.txt") (read "/cwd/a.txt")
      (kind "/cwd/a.txt") (resolve "/cwd/a.txt") (write "/cwd/a.txt" "xabc\ndef")))
  (check-equal? (host-receiver-send disk 'read '("/cwd/a.txt")) "xabc\ndef")
  ;; Pair every observable runner frame with direct checked-state assertions.
  ;; This separate driver uses the actual startup, not a supplied-session seam.
  (define st (make-driver))
  (define-values (direct-host direct-calls _) (counted-fs))
  (driver-inject-host! st 'fs-host direct-host)
  (ev st `(load ,(path->string main-path)))
  (def! st 's '(aloemacs-editor visit (Path new "/cwd/a.txt")))
  (def! st 's '(s case (None () aloemacs-editor) (Some (value) value)))
  (for ([size sizes] [key keys] [frame frames] [index (in-naturals)])
    (def! st 's `(s ensure-visible ,@size))
    (paint st 's (car size) (cadr size) frame)
    (same st '((s windows) columns) (car size))
    (same st '((s windows) rows) (cadr size))
    (same st '((s windows) selected) 0)
    (when (>= index 4)
      (same st '((s windows) tree)
        (below (right (leaf 0 0 0 (if (>= index 5) 1 0)) (leaf 2 0)) (leaf 1 0)))
      ;; The selected 4 x 3 leaf has two text rows; the 1 x 2 fallback has one.
      (same st '((s editor) text-rows) (if (= index 5) 1 2)))
    (def! st 's `(s handle-key ,key)))
  (same st '(s quit) #t)
  (same st '(s pending) no-pending)
  (same st '((s windows) tree)
    (below (right (leaf 0 0 0 1) (leaf 2 0)) (leaf 1 0)))
  (check-equal? (filter (lambda (c) (eq? (car c) 'write)) (unbox direct-calls))
                '((write "/cwd/a.txt" "xabc\ndef"))))
