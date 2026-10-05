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
  `(AloemacsWindowTree Leaf (AloemacsView new ,id ,bid ,row ,col ,lock)))
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
(define (single lines row col [echo-row #f] [echo ""] [final-row row] [final-col col]
                #:name [name "untitled"] #:width [width 0])
  (string-append "\e[?25l\e[2J\e[H"
    (if echo-row (text-body (string-join lines "\r\n") echo-row) (string-join lines "\r\n"))
    (format "\e[~a;~aH\e[?25h" row col)
    (if echo-row
        (string-append "\e[?25l"
          (if (>= echo-row 3) (format "\e[~a;1H~a" (sub1 echo-row) (mode-row name width)) "")
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
(define operations '((delete-window DeleteWindow "0") (other-window OtherWindow "o")))
(define (datums path) (call-with-input-file path (lambda (in) (port->list read in))))
(define (reset-entry s bs tree selected [prompt? #f] [columns 9] [rows 6])
  (rebuild s #:buffers bs #:windows (config tree selected columns rows)
    #:echo (if prompt? `(,s echo) "") #:searching #f #:query ""
    #:origin '(Position new 0 0) #:wrapped #f #:failing #f #:pending no-pending))

(test-case "ordered zero-payload constructors, cases, maps, checked types and unchanged startup"
  (define st0 (loaded))
  (for ([name '(fs-host term aloemacs-editor)])
    (check-false (env-bound? (driver-runtime-environment st0) name)))
  (define source (datums file-path))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) source))
  (define (decl name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (check-equal? (take source 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B)
      AloemacsBinding AloemacsSearchScan (AloemacsSession H)))
  (check-equal? (caddr (decl 'AloemacsCommand))
    `(constructors ,@(map (lambda (c) `(,c (fields))) commands)))
  (define methods (cdr (cadddr (decl '(AloemacsSession H)))))
  (define executions (cddr (last (assoc 'execute-command methods))))
  (define names (cddr (last (cadr (cadddr (decl 'AloemacsCommand))))))
  (for ([op operations] [name '("delete-window" "other-window")])
    (check-equal? (assoc (cadr op) executions) `(,(cadr op) () (self ,(car op))))
    (check-equal? (assoc (cadr op) names) `(,(cadr op) () ,name))
    (check-equal? (drop-right (assoc (car op) methods) 1)
      `(,(car op) () (AloemacsSession H))))
  (for ([host-name '(FsHost WindowDisk)])
    (define-values (st calls) (state host-name))
    (simple! st)
    (for ([op operations] [name '("delete-window" "other-window")])
      (check-equal? (ev st `((AloemacsCommand ,(cadr op)) name)) name)
      (check-equal? (dtype st `(s ,(car op))) `(AloemacsSession ,host-name))
      (check-equal? (dtype st `(s execute-command (AloemacsCommand ,(cadr op)) "ignored"))
        `(AloemacsSession ,host-name))
      (for ([bad (list `(s ,(car op) 0) `(s ,(car op) "x") `(s ,(car op) #f)
                       `(s ,(car op) 0 1) `(AloemacsSession ,(car op))
                       `(AloemacsCommand ,(cadr op) 0) `(AloemacsCommand ,(cadr op) "x")
                       `((AloemacsCommand ,(cadr op)) run s)
                       `((AloemacsCommand ,(cadr op)) name 0)
                       `(s execute-command (AloemacsCommand ,(cadr op)))
                       `(s execute-command (AloemacsCommand ,(cadr op)) 0)
                       `(s execute-command (AloemacsCommand ,(cadr op)) "x" "y"))])
        (check-exn exn:fail:aloe-type? (lambda () (ev st bad))))
      (for ([receiver '(a (s editor) (s windows) (s buffers) 0 "x")])
        (check-exn exn:fail:aloe-type? (lambda () (ev st `(,receiver ,(car op)))))))
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

(test-case "singleton preserves complete raw state; two shared leaves hand off only origins"
  (define-values (st calls) (state))
  (define text (indexed '("abcdefghi" "line one" "line two" "last") 2))
  (define a (buffer 41 (editor text 1 5 6 8 17 #:quit #t) '(Option Some (Path new "/a"))))
  (define b (buffer 99 (editor text 3 2 5 9 22) '(Option Some (Path new "/b"))))
  (define bs (zipper (list b a) 1))
  (def! st 'one (session bs (leaf 70 41 1 2 #t) 70 #:columns 0 #:rows 0
                        #:searching #t #:prompt active-prompt #:pending pending))
  (same-session st '(one other-window) 'one)
  (def! st 's (rebuild 'one #:windows
    (config (right (leaf 70 41 1 2) (leaf 2 41 40 50 #t)) 70 9 6)))
  (define installed (buffer 41 (editor text 1 5 40 50 17 #:quit #t)
                            '(Option Some (Path new "/a"))))
  (define stored (right (leaf 70 41 6 8) (leaf 2 41 40 50 #t)))
  (def! st 'entered '(s other-window))
  (same-session st 'entered (rebuild 's #:buffers (zipper (list b installed) 1)
                                    #:windows (config stored 2)))
  (same-session st '(entered other-window)
    (rebuild 's #:windows (config stored 70)))
  (same st '(entered point) '(s point))
  (same st '(entered origin) '(s origin))
  (check-equal? (unbox calls) '()))

(test-case "mixed tree order and zipper order differ; every rich buffer survives ID-based resets"
  (define-values (st calls) (state))
  (define text (indexed '("first line" "second line" "third" "fourth") 2))
  (define path '(Option Some (Path new "/duplicate")))
  ;; Names, text, point and every editor payload are identical, IDs differ.
  (define (b id row col) (buffer id (editor text 1 5 row col 23 #:quit #t) path))
  (define bs (zipper (list (b 99 7 8) (b 41 7 8) (b 12 7 8)) 1))
  (define t (right (below (leaf 70 41 0 0) (leaf 2 12 30 40 #t)) (leaf 40 99 5 6)))
  (def! st 's (session bs t 70 #:searching #t #:pending pending))
  (define stored (right (below (leaf 70 41 7 8) (leaf 2 12 30 40 #t)) (leaf 40 99 5 6)))
  (def! st 'second '(s other-window))
  (same-session st 'second (reset-entry 's
    (zipper (list (b 99 7 8) (b 41 7 8) (b 12 30 40)) 2) stored 2))
  (def! st 'third '(second other-window))
  (same-session st 'third (reset-entry 'second
    (zipper (list (b 99 5 6) (b 41 7 8) (b 12 30 40))) stored 40))
  (same-session st '(third other-window) (reset-entry 'third
    (zipper (list (b 99 5 6) (b 41 7 8) (b 12 30 40)) 1) stored 70))
  (same st '(second point) '(Position new 1 5))
  (same st '(((second buffers) before) map (fn (b) (b id))) '(List of 41 99))
  (check-equal? (unbox calls) '()))

(test-case "entry never fits; explicit fit translates the cursor and preserves inactive origins"
  (define-values (st calls) (state))
  (define text (indexed '("abcdef" "ghijkl" "mnopqr" "stuvwx") 2))
  (define a (buffer 41 (editor text 2 5 0 0 17)))
  (define t (right (below (leaf 70) (leaf 2 41 3 2 #t)) (leaf 40 41 0 1)))
  (def! st 's (session (zipper (list a)) t 70))
  (def! st 'entered '(s other-window))
  (same-session st 'entered (rebuild 's
    #:buffers (zipper (list (buffer 41 (editor text 2 5 3 2 17))))
    #:windows (config t 2)))
  (def! st 'fitted '(entered ensure-visible 9 6))
  (define fit-tree (right (below (leaf 70) (leaf 2 41 2 2 #t)) (leaf 40 41 0 1)))
  (same-session st 'fitted (rebuild 'entered
    #:buffers (zipper (list (buffer 41 (editor text 2 5 2 2 1))))
    #:windows (config fit-tree 2)))
  (paint st 'fitted 9 6
    (multi '("abcd|bcde" "unti|hijk" "----+nopq" "opqr|tuvw" "unti|unti") 4 4 6 "saved: un"))
  (def! st 'prompted (rebuild 'fitted #:prompt active-prompt))
  (paint st 'prompted 9 6
    (multi '("abcd|bcde" "unti|hijk" "----+nopq" "opqr|tuvw" "unti|unti") 6 5 6 "P x y"))
  (same-session st '(fitted ensure-visible 9 6) 'fitted)
  (check-equal? (unbox calls) '()))

(test-case "shared edits and undo use one point and history across origin handoffs"
  (define-values (st calls) (state))
  (define text (indexed '("abc" "def")))
  (define a (buffer 41 (editor text 0 1 0 0 5 #:history '(List empty) #:mark no-mark)))
  (define t (right (leaf 7) (leaf 3 41 1 1)))
  (def! st 's (session (zipper (list a)) t 7 #:echo ""))
  (def! st 'entered '(s other-window))
  (def! st 'edited '(entered insert "X"))
  (define edited-text (indexed '("aXbc" "def")))
  (define history `(List of (UndoFrame new ,text (Position new 0 1) 1 1)))
  (same-session st 'edited (rebuild 's #:buffers
    (zipper (list (buffer 41 (editor edited-text 0 2 1 1 5 #:history history #:mark no-mark))))
    #:windows (config t 3)))
  (def! st 'back '(edited other-window))
  (same-session st 'back (rebuild 'edited #:buffers
    (zipper (list (buffer 41 (editor edited-text 0 2 0 0 5 #:history history #:mark no-mark))))
    #:windows (config t 7)))
  (def! st 'fit '(back ensure-visible 9 6))
  (paint st 'fit 9 6 (multi '("aXbc|ef  " "def |    " "    |    " "    |    " "unti|unti") 1 3))
  (same-session st '(back undo) (rebuild 'back #:buffers
    (zipper (list (buffer 41 (editor text 0 1 1 1 5 #:history '(List empty) #:mark no-mark))))
    #:windows (config (right (leaf 7 41 1 1) (leaf 3 41 1 1)) 7)))
  (check-equal? (unbox calls) '()))

(test-case "delete each side of either orientation, including different-buffer search acceptance"
  (define-values (st calls) (state))
  (define text (indexed '("abcdef" "second" "third") 1))
  (define (a row col) (buffer 41 (editor text 1 3 row col 19 #:quit #t)
                            '(Option Some (Path new "/a"))))
  (define (b row col) (buffer 12 (editor text 2 4 row col 27)
                            '(Option Some (Path new "/b"))))
  (define unseen (buffer 99 (editor text 0 2 10 11 31)))
  (for* ([join (list below right)] [side '(early late)] [same-id? '(#f #t)])
    (define selected (if (eq? side 'early) 70 2))
    (define sibling (if (eq? side 'early) 2 70))
    (define early (leaf 70 (if (eq? side 'early) 41 (if same-id? 41 12)) 2 3))
    (define late (leaf 2 (if (eq? side 'late) 41 (if same-id? 41 12)) 4 5))
    (define row (if (eq? side 'early) 4 2))
    (define col (if (eq? side 'early) 5 3))
    (define survivor (leaf sibling (if same-id? 41 12) row col))
    (def! st 's (session (zipper (list unseen (a 7 8) (b 9 10)) 1)
      (join early late) selected #:searching #t #:pending pending #:prompt active-prompt))
    (define bs (zipper (list unseen (a (if same-id? row 7) (if same-id? col 8))
                                (b (if same-id? 9 row) (if same-id? 10 col)))
                       (if same-id? 1 2)))
    (same-session st '(s delete-window)
      (if same-id? (rebuild 's #:buffers bs #:windows (config survivor sibling))
          (reset-entry 's bs survivor sibling #t))))
  (check-equal? (unbox calls) '()))

(test-case "nested deletion promotes only the immediate sibling; buffers and outside views remain"
  (define-values (st calls) (state))
  (define text (indexed '("abc" "def") 1))
  (define a (buffer 41 (editor text 1 2 3 4 25)))
  (define b (buffer 12 (editor text 0 1 5 6 29)))
  (define unseen (buffer 99 (editor text 0 0 7 8 31 #:quit #t)))
  (define sibling (below (leaf 80 12 8 9) (leaf 4 41 10 11)))
  (define outside (leaf 1 41 12 13 #t))
  (define t (below (right (leaf 7 41 0 0) sibling) outside))
  (def! st 's (session (zipper (list b unseen a) 2) t 7 #:pending pending))
  (define promoted (below sibling outside))
  (same-session st '(s delete-window) (reset-entry 's
    (zipper (list (buffer 12 (editor text 0 1 8 9 29)) unseen a)) promoted 80))
  (def! st 'r '(s delete-window))
  (same st `(((r windows) tree) rect-for 80 ,(rect 0 0 9 5)) `(Option Some ,(rect 0 0 9 1)))
  (same st `(((r windows) tree) rect-for 4 ,(rect 0 0 9 5)) `(Option Some ,(rect 0 2 9 0)))
  (same st `(((r windows) tree) rect-for 1 ,(rect 0 0 9 5)) `(Option Some ,(rect 0 3 9 2)))
  (same st `(((s windows) tree) rect-for 1 ,(rect 0 0 9 5)) `(Option Some ,(rect 0 3 9 2)))
  ;; Leaf sibling in a nested parent; another view of the removed buffer stays.
  (define t2 (right (below (leaf 7 41 0 0) (leaf 80 41 8 9)) outside))
  (def! st 's (session (zipper (list b unseen a) 2) t2 7 #:pending pending))
  (same-session st '(s delete-window) (rebuild 's
    #:buffers (zipper (list b unseen (buffer 41 (editor text 1 2 8 9 25))) 2)
    #:windows (config (right (leaf 80 41 8 9) outside) 80)))
  (check-equal? (unbox calls) '()))

(test-case "locked deletion guards compare nominal rectangles, including zero-axis fallback"
  (define-values (st calls) (state))
  (simple! st)
  ;; Each table row names the locked view's independently calculated old/new rect.
  (define cases
    (list
      (list (right (leaf 7) (leaf 2 41 0 0 #t)) (leaf 2 41 0 0 #t) 2 9 6
            (rect 5 0 4 5) (rect 0 0 9 5) #f)
      (list (below (leaf 2 41 0 0 #t) (leaf 7)) (leaf 2 41 0 0 #t) 2 9 6
            (rect 0 0 9 2) (rect 0 0 9 5) #f)
      ;; Only x changes: the locked width stays zero during fallback.
      (list (right (leaf 7) (right (leaf 2 41 0 0 #t) (leaf 3)))
            (right (leaf 2 41 0 0 #t) (leaf 3)) 2 1 2
            (rect 1 0 0 1) (rect 0 0 0 1) #f)
      ;; Only y changes: the locked height stays zero during fallback.
      (list (below (leaf 7) (below (leaf 2 41 0 0 #t) (leaf 3)))
            (below (leaf 2 41 0 0 #t) (leaf 3)) 2 9 2
            (rect 0 1 9 0) (rect 0 0 9 0) #f)
      (list (right (right (right (leaf 2 41 0 0 #t) (leaf 3)) (leaf 4)) (leaf 7))
            (right (right (leaf 2 41 0 0 #t) (leaf 3)) (leaf 4)) 2 7 6
            (rect 0 0 0 5) (rect 0 0 1 5) #f)
      (list (right (right (right (leaf 2 41 0 0 #t) (leaf 3)) (leaf 4)) (leaf 7))
            (right (right (leaf 2 41 0 0 #t) (leaf 3)) (leaf 4)) 2 9 6
            (rect 0 0 1 5) (rect 0 0 2 5) #f)
      ;; A deep surviving lock has exactly the same nominal zero-width rect.
      (list (right (right (right (right (right (leaf 2 41 0 0 #t) (leaf 3))
                                   (leaf 4)) (leaf 5)) (leaf 6)) (leaf 7))
            (right (right (right (right (leaf 2 41 0 0 #t) (leaf 3)) (leaf 4))
                          (leaf 5)) (leaf 6)) 2 9 6
            (rect 0 0 0 5) (rect 0 0 0 5) #t)
      ;; Outside lock stays exact and does not block local deletion.
      (list (right (below (leaf 7) (leaf 3)) (leaf 2 41 0 0 #t))
            (right (leaf 3) (leaf 2 41 0 0 #t)) 2 9 6
            (rect 5 0 4 5) (rect 5 0 4 5) #t)))
  (for ([c cases])
    (define t (list-ref c 0)) (define candidate (list-ref c 1))
    (define id (list-ref c 2)) (define columns (list-ref c 3)) (define rows (list-ref c 4))
    (define root (rect 0 0 columns (sub1 rows)))
    (def! st 'raw (session (zipper '(a)) t 7 #:columns columns #:rows rows))
    (same st `(((raw windows) tree) rect-for ,id ,root) `(Option Some ,(list-ref c 5)))
    (same st `(,candidate rect-for ,id ,root) `(Option Some ,(list-ref c 6)))
    (same-session st '(raw delete-window)
      (if (list-ref c 7)
          (rebuild 'raw #:windows (config candidate
            (if (equal? (list-ref c 5) (rect 5 0 4 5)) 3 2) columns rows))
          (rebuild 'raw #:echo "failed"))))
  (check-equal? (unbox calls) '()))

(test-case "waiting prompt keeps line and slot across entry/deletion; Return targets current buffer"
  (define-values (st calls) (state))
  (define a (buffer 41 (editor ab-text) '(Option Some (Path new "/a"))))
  (define b-text (indexed '("B")))
  (define b (buffer 12 (editor b-text) '(Option Some (Path new "/b"))))
  (define t (right (leaf 7) (leaf 2 12)))
  (for ([op operations])
    (def! st 's (session (zipper (list a b)) t 7 #:pending pending
      #:prompt '(Option Some (AloemacsPrompt new "Save as: " "/cwd/a.txt" 10 "" (List empty) (List empty) 0))))
    (define target-tree (if (eq? (car op) 'delete-window) (leaf 2 12) t))
    (def! st 'entered `(s ,(car op)))
    (same-session st 'entered (reset-entry 's (zipper (list a b) 1) target-tree 2 #t))
    (same-session st '(entered handle-key "return") (rebuild 'entered
      #:buffers (zipper (list a (buffer 12 (editor b-text)
                        '(Option Some (Path new "/cwd/a.txt")))) 1)
      #:echo "saved" #:prompt no-prompt #:submission '(Option Some "/cwd/a.txt")
      #:waiting no-command))
    (check-equal? (unbox calls)
      '((resolve "/cwd/a.txt") (kind "/cwd/a.txt") (resolve "/cwd/a.txt")
        (write "/cwd/a.txt" "B")))
    (set-box! calls '()))
  (def! st 's (session (zipper (list a b)) t 7 #:pending pending
    #:prompt '(Option Some (AloemacsPrompt new "Buffer: " "/a" 2 "" (List empty) (List empty) 0))
    #:waiting '(Option Some (AloemacsCommand SelectBuffer))))
  (def! st 'entered '(s other-window))
  (same-session st '(entered handle-key "return") (rebuild 'entered
    #:buffers (zipper (list a b)) #:windows (config (right (leaf 7) (leaf 2)) 2)
    #:echo "" #:prompt no-prompt #:submission '(Option Some "/a") #:waiting no-command))
  ;; Submission/slot changes belong to Return, not entry.
  (def! st 'submitted '(entered handle-key "return"))
  (same st '(submitted prompt) no-prompt)
  (same st '(submitted waiting-command) no-command)
  (same st '(submitted last-submission) '(Option Some "/a"))
  (check-equal? (unbox calls) '())
  (def! st 's (session (zipper (list a b)) t 7
    #:prompt '(Option Some (AloemacsPrompt new "Find file: " "/cwd/b.txt" 10 "" (List empty) (List empty) 0))
    #:waiting '(Option Some (AloemacsCommand FindFile))))
  (def! st 'entered '(s other-window))
  (def! st 'submitted '(entered handle-key "return"))
  (define found (buffer 42 (editor (indexed '("disk b"))
    #:history '(List empty) #:mark no-mark) '(Option Some (Path new "/cwd/b.txt"))))
  (same-session st 'submitted (rebuild 'entered #:buffers (zipper (list a b found) 2)
    #:windows (config (right (leaf 7) (leaf 2 42)) 2) #:echo "" #:prompt no-prompt
    #:submission '(Option Some "/cwd/b.txt") #:waiting no-command))
  (check-equal? (unbox calls)
    '((resolve "/cwd/b.txt") (kind "/cwd/b.txt") (resolve "/cwd/b.txt")
      (kind "/cwd/b.txt") (resolve "/cwd/b.txt") (read "/cwd/b.txt"))))

(test-case "production runner: split, select a different rectangle, edit, delete, resize and quit"
  (for ([split-key '("2" "3")])
    (define below? (equal? split-key "2"))
    (define keys (list "ctrl-x" split-key "ctrl-x" "o" "x" "ctrl-x" "0" "escape"))
    (define sizes '((9 6) (9 6) (9 6) (9 6) (9 6) (2 3) (9 6) (9 6)))
    (define start (single '("abc" "def" "" "" "") 1 1 6 "" #:name "/cwd/a.txt" #:width 9))
    (define split-rows (if below?
      '("abc      " "/cwd/a.tx" "---------" "abc      " "/cwd/a.tx")
      '("abc |abc " "def |def " "    |    " "    |    " "/cwd|/cwd")))
    (define edited-rows (if below?
      '("xabc     " "/cwd/a.tx" "---------" "xabc     " "/cwd/a.tx")
      '("xabc|xabc" "def |def " "    |    " "    |    " "/cwd|/cwd")))
    (define frames
      (list start start (multi split-rows 1 1 6 "")
        (multi split-rows 1 1 6 "")
        (multi split-rows (if below? 4 1) (if below? 1 6) 6 "")
        (single '("xa" "de") 1 2 3 "" #:name "/cwd/a.txt" #:width 2)
        (multi edited-rows (if below? 4 1) (if below? 2 7) 6 "")
        (single '("xabc" "def" "" "" "") 1 2 6 "" #:name "/cwd/a.txt" #:width 9)))
    (define-values (host calls disk) (counted-fs))
    (define iteration 0)
    (define events (box '()))
    (define (record event) (set-box! events (append (unbox events) (list event))))
    (define output
      (make-output-port 'window-runner always-evt
        (lambda (bytes start end _non-block? _breakable?)
          (unless (= start end)
            (record (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
          (- end start)) void))
    (define term
      (make-term-receiver output
        (lambda ()
          (record 'read)
          (when (>= iteration (length keys)) (error 'window-runner "read after quit"))
          (begin0 (list-ref keys iteration) (set! iteration (add1 iteration))))
        (lambda ()
          (record 'size)
          (when (>= iteration (length sizes)) (error 'window-runner "size after quit"))
          (apply values (list-ref sizes iteration)))))
    (run-aloemacs-with-hosts term host "/cwd/a.txt")
    (check-equal? iteration (length keys))
    (check-equal? (unbox events)
      (append-map (lambda (frame) (list 'size 'size (list 'write frame) 'read)) frames))
    (define visit-calls
      '((resolve "/cwd/a.txt") (resolve "/cwd/a.txt") (kind "/cwd/a.txt")
        (resolve "/cwd/a.txt") (kind "/cwd/a.txt") (resolve "/cwd/a.txt") (read "/cwd/a.txt")))
    (check-equal? (unbox calls) visit-calls)
    (check-equal? (host-receiver-send disk 'read '("/cwd/a.txt")) "abc\ndef")
    ;; Match runner frames with independent state expectations from real startup.
    (define st (make-driver))
    (define-values (direct-host direct-calls _) (counted-fs))
    (driver-inject-host! st 'fs-host direct-host)
    (ev st `(load ,(path->string main-path)))
    (def! st 's '(aloemacs-editor visit (Path new "/cwd/a.txt")))
    (def! st 's '(s case (None () aloemacs-editor) (Some (value) value)))
    (for ([size sizes] [key keys] [frame frames] [i (in-naturals)])
      (def! st 's `(s ensure-visible ,@size))
      (paint st 's (car size) (cadr size) frame)
      (same st '((s windows) selected) (if (and (>= i 4) (< i 7)) 1 0))
      (same st '(s point) `(Position new 0 ,(if (>= i 5) 1 0)))
      (same st '((s windows) columns) (car size))
      (same st '((s windows) rows) (cadr size))
      (def! st 's `(s handle-key ,key)))
    (same st '(s quit) #t)
    (same st '(s pending) no-pending)
    (same st '((s windows) tree) (leaf 0 0))
    (same st '((s buffers) before) '(List empty))
    (same st '((s buffers) after) '(List empty))
    (same st '((s current-buffer) id) 0)
    (same st '(s text) (indexed '("xabc" "def")))
    (check-equal? (unbox direct-calls) (cdr visit-calls))))

(test-case "unknown sizes guard only sibling locks; unlocked deletion requires no fit"
  (define-values (st calls) (state))
  (simple! st)
  (for ([size '((0 0) (0 6) (9 0) (-1 6) (9 -1))])
    (define locked-sibling (below (leaf 3) (leaf 2 41 8 9 #t)))
    (def! st 'raw (session (zipper '(a)) (right (leaf 7) locked-sibling) 7
      #:columns (car size) #:rows (cadr size) #:pending pending))
    (same-session st '(raw delete-window) (rebuild 'raw #:echo "failed"))
    (def! st 'raw (rebuild 'raw #:prompt active-prompt))
    (same-session st '(raw delete-window) 'raw)
    (define outside (leaf 2 41 8 9 #t))
    (def! st 'raw (session (zipper '(a)) (right (below (leaf 7) (leaf 3)) outside) 7
      #:columns (car size) #:rows (cadr size) #:pending pending))
    (same-session st '(raw delete-window) (rebuild 'raw #:windows
      (config (right (leaf 3) outside) 3 (car size) (cadr size))))
    (def! st 'raw (session (zipper '(a)) (below (leaf 7) (leaf 3 41 40 50)) 7
      #:columns (car size) #:rows (cadr size) #:pending pending))
    (same-session st '(raw delete-window) (rebuild 'raw #:buffers
      (zipper (list (buffer 41 (editor ab-text 0 0 40 50))))
      #:windows (config (leaf 3 41 40 50) 3 (car size) (cadr size)))))
  (check-equal? (unbox calls) '()))

(test-case "deletion can restore displayable layout after fallback without fitting itself"
  (define-values (st calls) (state))
  (simple! st)
  (def! st 's (session (zipper '(a)) (right (leaf 7) (leaf 2 41 1 1)) 7
    #:columns 2 #:rows 3 #:echo ""))
  (paint st 's 2 3 (single '("ab" "de") 1 1 3 "" #:name "untitled" #:width 2))
  (def! st 'deleted '(s delete-window))
  (same-session st 'deleted (rebuild 's #:buffers
    (zipper (list (buffer 41 (editor ab-text 0 0 1 1))))
    #:windows (config (leaf 2 41 1 1) 2 2 3)))
  (def! st 'fit '(deleted ensure-visible 2 3))
  (same-session st 'fit (rebuild 'deleted #:buffers
    (zipper (list (buffer 41 (editor ab-text 0 0 0 0 1))))
    #:windows (config (leaf 2) 2 2 3)))
  (paint st 'fit 2 3 (single '("ab" "de") 1 1 3 "" #:name "untitled" #:width 2))
  (check-equal? (unbox calls) '()))

(test-case "all tokens: same-ID entry, different-ID resets, active rows and refusal preservation"
  (define-values (st calls) (state))
  (simple! st)
  (define b (buffer 12 (editor ab-text)))
  (for* ([token '("" "saved" "failed")] [mode '(neither prompt search both)]
         [same-id? '(#f #t)] [op operations])
    (define prompt? (and (memq mode '(prompt both)) #t))
    (define search? (and (memq mode '(search both)) #t))
    (define t (right (leaf 7) (leaf 2 (if same-id? 41 12))))
    (def! st 'raw (session (zipper (list 'a b)) t 7 #:echo token #:searching search?
      #:prompt (if prompt? active-prompt no-prompt) #:pending pending))
    (define result-tree (if (eq? (car op) 'delete-window) (leaf 2 (if same-id? 41 12)) t))
    (define bs (zipper (list 'a b) (if same-id? 0 1)))
    (define expected (if same-id? (rebuild 'raw #:buffers bs #:windows (config result-tree 2))
                        (reset-entry 'raw bs result-tree 2 prompt?)))
    (same-session st `(raw ,(car op)) expected)
    (same-session st `(raw execute-command (AloemacsCommand ,(cadr op)) "unused") expected)
    (def! st 'r `(raw ,(car op)))
    (define kept-token (if (or same-id? prompt?) token ""))
    (check-equal? (ev st '(r echo)) kept-token)
    (define shown (cond [prompt? "P x y"] [(and same-id? search?) "failing: "]
                       [(equal? kept-token "saved") "saved: un"]
                       [(equal? kept-token "failed") "failed: u"] [else ""]))
    (if (eq? (car op) 'delete-window)
        (paint st 'r 9 6 (single '("abc" "def" "" "" "") 1 1 6 shown
                                 (if prompt? 6 1) (if prompt? 5 1) #:name "untitled" #:width 9))
        (paint st 'r 9 6 (multi '("abc |abc " "def |def " "    |    " "    |    " "unti|unti")
                                 (if prompt? 6 1) (if prompt? 5 6) 6 shown))))
  (for* ([token '("" "saved" "failed")] [mode '(neither prompt search both)]
         [t (list (leaf 7) (right (leaf 7 41 0 0 #t) (leaf 2))
                  (right (leaf 7) (leaf 2 41 0 0 #t)))])
    (define prompt? (and (memq mode '(prompt both)) #t))
    (define search? (and (memq mode '(search both)) #t))
    (def! st 'raw (session (zipper '(a)) t 7 #:echo token #:searching search?
      #:prompt (if prompt? active-prompt no-prompt) #:pending pending))
    (same-session st '(raw delete-window)
      (if (or prompt? search?) 'raw (rebuild 'raw #:echo "failed")))
    (def! st 'r '(raw delete-window))
    (check-equal? (ev st '(r echo)) (if (or prompt? search?) token "failed"))
    (define shown (cond [prompt? "P x y"] [search? "failing: "] [else "failed: u"]))
    (if (equal? t (leaf 7))
        (paint st 'r 9 6 (single '("abc" "def" "" "" "") 1 1 6 shown
                                 (if prompt? 6 1) (if prompt? 5 1) #:name "untitled" #:width 9))
        (paint st 'r 9 6 (multi '("abc |abc " "def |def " "    |    " "    |    " "unti|unti")
                                 (if prompt? 6 1) (if prompt? 5 1) 6 shown))))
  (check-equal? (unbox calls) '()))

(test-case "direct/chord/execute equivalence, plain insertion, consumed misses and input precedence"
  (define-values (st calls) (state))
  (simple! st)
  (define t (right (leaf 7) (leaf 2)))
  (def! st 's (rebuild 's #:echo "" #:windows (config t 7)))
  (for ([op operations])
    (define result-tree (if (eq? (car op) 'delete-window) (leaf 2) t))
    (define expected (rebuild 's #:windows (config result-tree 2)))
    (for ([actual (list `(s ,(car op))
                       `(s execute-command (AloemacsCommand ,(cadr op)) "unused")
                       `((s handle-key "ctrl-x") handle-key ,(caddr op)))])
      (same-session st actual expected))
    (for ([token '("" "saved" "failed")])
      (def! st 'raw (rebuild 's #:echo token #:pending pending))
      (same-session st `(raw ,(car op)) (rebuild 'raw #:windows (config result-tree 2)))
      (same-session st `(raw handle-key ,(caddr op))
        (rebuild 'raw #:pending no-pending #:windows (config result-tree 2)))
      (same-session st `(((s with-echo ,token) handle-key "ctrl-x") handle-key ,(caddr op))
        (rebuild 's #:echo "" #:pending no-pending #:windows (config result-tree 2))))
    (def! st 'quit-s (rebuild 's #:buffers
      (zipper (list (buffer 41 (editor ab-text #:quit #t))))))
    (same-session st `(quit-s ,(car op)) (rebuild 'quit-s #:windows (config result-tree 2)))
    (same-session st `(quit-s execute-command (AloemacsCommand ,(cadr op)) "ignored")
      (rebuild 'quit-s #:windows (config result-tree 2)))
    (for ([key (list "ctrl-x" (caddr op))])
      (same-session st `(quit-s handle-key ,key) 'quit-s)))
  (for ([key '("0" "o")])
    (same-session st `(s handle-key ,key) (rebuild 's #:buffers (zipper (list (buffer 41
      (editor (indexed (list (string-append key "abc") "def")) 0 1
        #:history `(List of (UndoFrame new ,ab-text (Position new 0 0) 0 0)
          (UndoFrame new (Text from-string "previous") (Position new 0 2) 1 2)))))))))
  (for ([key '("x" "escape" "unknown" "" "left" "ctrl-x")])
    (same-session st `((s handle-key "ctrl-x") handle-key ,key) (rebuild 's #:echo "")))
  (for ([key '("delete-window" "other-window")])
    (same-session st `(s handle-key ,key) (rebuild 's #:echo "")))
  (def! st 'p (rebuild 's #:prompt active-prompt #:pending pending))
  (same-session st '(p handle-key "ctrl-x") 'p)
  (for ([key '("0" "o")])
    (same-session st `(p handle-key ,key) (rebuild 'p #:prompt
      `(Option Some (AloemacsPrompt new "P\t" ,(string-append "x\r" key "y") 3 "" (List empty) (List empty) 0)))))
  (def! st 'search (rebuild 's #:searching #t #:query "" #:wrapped #f #:failing #f
    #:origin '(Position new 0 0) #:pending no-pending))
  (for ([key '("0" "o")])
    (same-session st `(search handle-key ,key) (rebuild 'search #:query key #:failing #t)))
  (def! st 'both (rebuild 'search #:prompt active-prompt))
  (same-session st '(both handle-key "o") (rebuild 'both #:query "o" #:failing #t))
  (same-session st '((both handle-key "ctrl-x") handle-key "0")
    (rebuild 'both #:searching #f #:query "" #:origin '(Position new 0 0)
      #:wrapped #f #:failing #f #:echo "" #:pending pending
      #:prompt '(Option Some (AloemacsPrompt new "P\t" "x\r0y" 3 "" (List empty) (List empty) 0))))
  (same-session st '((search handle-key "ctrl-x") handle-key "o")
    (rebuild 'search #:searching #f #:query "" #:origin '(Position new 0 0)
      #:wrapped #f #:failing #f #:echo "" #:pending no-pending #:windows (config t 2)))
  (check-equal? (unbox calls) '()))
