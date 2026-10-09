#lang racket/base

(require racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type?)
         "../../host/racket/aloemacs-run.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))

;; Test-local chrome literals. Expectations never send bar, row, frame-rows,
;; a rectangle send, or a session composer.
(define LIGHT "\e[38;5;16;48;5;250m")
(define DARK "\e[38;5;252;48;5;239m")
(define PLAIN "\e[0m")
(define (visible s)
  (for/fold ([s s]) ([sequence (list LIGHT DARK PLAIN)]) (string-replace s sequence "")))
(define (occurrences s part) (length (regexp-match-positions* (regexp-quote part) s)))
(define (no-sequence? s)
  (for/and ([sequence (list LIGHT DARK PLAIN)]) (zero? (occurrences s sequence))))
(define (painted row selected?)
  (if (string=? row "") "" (string-append (if selected? LIGHT DARK) row PLAIN)))

;; Raw constructors only.
(define no-path '(if #t (Option None) (Option Some (Path new ""))))
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define no-prompt
  '(if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0))))
(define active-prompt '(Option Some (AloemacsPrompt new "P\t" "x\ry" 2 "" (List empty) (List empty) 0)))
(define pending '(Option Some aloemacs-ctrl-x-keymap))
(define history '(List of (UndoFrame new (Text from-string "old") (Position new 0 1) 2 3)))
(define (indexed lines [focus 0])
  `(Text indexed (List of ,@(reverse (take lines focus))) ,(list-ref lines focus)
     (List of ,@(drop lines (add1 focus))) ,focus))
(define (editor text [line 0] [col 0] [top 0] [left 0] [rows 0] #:quit [quit #f])
  `(AloemacsEditor new ,text (Position new ,line ,col) ,quit ,top ,left
     ,history (Option Some (Position new 0 1)) ,rows))
(define (buffer id ed [name #f])
  `(AloemacsBuffer new ,ed ,(if name `(Option Some (Path new ,name)) no-path) ,id))
(define (zipper bs [focus 0])
  `(AloemacsBuffers new (List of ,@(reverse (take bs focus))) ,(list-ref bs focus)
     (List of ,@(drop bs (add1 focus)))))
(define (leaf id [bid 41] [top 0] [left 0] [lock #f])
  `(AloemacsWindowTree Leaf (AloemacsView new ,id ,bid ,top ,left ,lock (Option None))))
(define (right a b) `(AloemacsWindowTree Right ,a ,b))
(define (below a b) `(AloemacsWindowTree Below ,a ,b))
(define (rect x y w h) `(AloemacsWindowRect new ,x ,y ,w ,h))
(define (config tree selected [w 9] [h 6]) `(AloemacsWindows new ,tree ,selected ,w ,h))
(define (session bs tree [selected 7] #:columns [w 9] #:rows [h 6] #:echo [echo ""]
                 #:searching [searching #f] #:prompt [prompt no-prompt] #:pending [prefix no-pending])
  `(AloemacsSession new ,bs (s fs) ,echo ,searching "q" (Position new 0 0) #f #f
     (List of "ring") ,prefix ,prompt (Option Some "prior") (Option Some (AloemacsCommand SaveAs))
     ,(config tree selected w h)))
(define (rebuild s #:buffers [bs `(,s buffers)] #:windows [ws `(,s windows)]
                 #:echo [echo `(,s echo)])
  `(AloemacsSession new ,bs (,s fs) ,echo (,s searching) (,s query) (,s origin)
     (,s wrapped) (,s failing) (,s kill-ring) (,s pending) (,s prompt)
     (,s last-submission) (,s waiting-command) ,ws))
(define session-fields '(buffers fs echo searching query origin wrapped failing kill-ring
                                 pending prompt last-submission waiting-command windows))
(define (same-session st actual expected)
  (def! st 'actual actual)
  (def! st 'expected expected)
  (same st 'actual 'expected)
  (for ([field session-fields]) (same st `(actual ,field) `(expected ,field))))

(define (counted-fs)
  (define calls (box '()))
  (define disk (make-fs-double "/cwd"
                 (hash "/cwd" 'directory "/cwd/a" 'file "/cwd/b" 'file)
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
(define (state)
  (define st (make-driver))
  (define-values (fs calls) (counted-fs))
  (driver-inject-host! st 'fs-host fs)
  (ev st `(load ,(path->string main-path)))
  (def! st 's 'aloemacs-editor)
  (values st calls))

;; Independent visible cells.
(define (clip s w) (substring s 0 (max 0 (min w (string-length s)))))
(define (safe s)
  (list->string (for/list ([c (in-string s)])
                  (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (mode name w)
  (define label (clip (string-append name " ") w))
  (safe (string-append label (make-string (max 0 (- w (string-length label))) #\-))))
(define (pad s w) (string-append s (make-string (max 0 (- w (string-length s))) #\space)))
;; A leaf: h - 1 text rows then its bar, or h text rows when h < 2.
(define (cells lines w h top left name selected?)
  (append
    (for/list ([i (in-range top (+ top (if (>= h 2) (sub1 h) h)))])
      (define line (if (< i (length lines)) (list-ref lines i) ""))
      (pad (safe (clip (substring line (min left (string-length line))) w)) w))
    (if (>= h 2) (list (painted (mode name w) selected?)) '())))
(define (blank w h) (make-list h (make-string w #\space)))
(define (side a b) (map (lambda (l r) (string-append l "|" r)) a b))
(define (cursor row col) (format "\e[~a;~aH" row col))
(define (multi rows row col w h echo #:list [list-rows ""])
  (string-append "\e[?25l\e[2J\e[H" (string-join rows "\r\n") list-rows
    (if (>= h 2) (string-append (cursor h 1) (safe (clip echo w))) "")
    (cursor row col) "\e[?25h"))
;; The one-view composer, for fallback frames.
(define (one-view body row col w h name echo)
  (define root (if (< h 2) h (sub1 h)))
  (string-append "\e[?25l\e[2J\e[H" body (cursor row col) "\e[?25h"
    (if (< h 2) ""
        (string-append "\e[?25l"
          (if (>= root 2) (string-append (cursor root 1) (painted (mode name w) #t)) "")
          (cursor h 1) (safe (clip echo w)) (cursor row col) "\e[?25h"))))

;; Split a painted row into attribute runs. Bars open only from default
;; attributes, close only with PLAIN, and every row ends in default attributes.
(define (runs row)
  (let loop ([s row] [attr 'plain] [acc '()])
    (define m (regexp-match-positions
                (pregexp (string-join (map regexp-quote (list LIGHT DARK PLAIN)) "|")) s))
    (cond
      [(not m)
       (check-equal? attr 'plain (format "row ends in default attributes: ~s" row))
       (reverse (if (string=? s "") acc (cons (cons attr s) acc)))]
      [else
       (define start (caar m))
       (define seq (substring s start (cdar m)))
       (define next (cond [(string=? seq LIGHT) 'light] [(string=? seq DARK) 'dark] [else 'plain]))
       (check-not-equal? (eq? attr 'plain) (eq? next 'plain) (format "bar nesting in ~s" row))
       (loop (substring s (cdar m)) next
             (if (= start 0) acc (cons (cons attr (substring s 0 start)) acc)))])))
(define (cell-attrs row)
  (append-map (lambda (r) (make-list (string-length (cdr r)) (car r))) (runs row)))
;; Structural checks over a frame's root rows. dividers lists (column first last)
;; for every Right rectangle; light and dark count bars.
(define (check-rows rows w h #:light light #:dark dark #:dividers [dividers '()]
                    #:punctuation-names [names? #f])
  (check-equal? (length rows) h)
  (for ([row rows])
    (define shown (visible row))
    (check-equal? (string-length shown) w (format "visible width of ~s" row))
    (check-equal? (length (cell-attrs row)) w)
    (check-false (regexp-match? #rx"^[-+]+$" shown) (format "no rule row: ~s" row))
    (unless names?
      (check-false (regexp-match? #rx"[+]" shown) (format "no junction: ~s" row))))
  (define joined (apply string-append rows))
  (check-equal? (occurrences joined LIGHT) light)
  (check-equal? (occurrences joined DARK) dark)
  (check-equal? (occurrences joined PLAIN) (+ light dark))
  (for ([divider dividers])
    (for ([y (in-range (cadr divider) (add1 (caddr divider)))])
      (define row (list-ref rows y))
      (check-equal? (string-ref (visible row) (car divider)) #\| (format "divider in ~s" row))
      (check-equal? (list-ref (cell-attrs row) (car divider)) 'plain
                    (format "divider after PLAIN in ~s" row)))))

(define (snapshot st s)
  (for/list ([expr (list s `(,s buffers) `((,s buffers) current-buffer) `((,s editor) text)
                         `(,s windows))])
    (ev st expr)))
(define (paint st s w h expected calls)
  (define before (snapshot st s))
  (define effects (unbox calls))
  (for ([i '(1 2)]) (check-equal? (ev st `(,s frame ,w ,h)) expected))
  (check-equal? (snapshot st s) before)
  (check-equal? (unbox calls) effects))
(define (rows! st s w h expected)
  (def! st 'composed `(((,s windows) tree) frame-rows (,s buffers)
                       (AloemacsWindowRect new 0 0 ,w ,h) ((,s windows) selected)))
  (same st 'composed `(List of ,@expected)))

(define a-lines '("abcdef" "ghijkl" "mnopqr" "stuvwx" "yz0123"))
(define b-lines '("ABCDE" "FGHIJ" "KLMNO" "PQRST" "UVWXY"))
(define (methods-of d) (cdr (findf (lambda (s) (and (pair? s) (eq? (car s) 'methods))) d)))

(test-case "composition signature, removed divider helpers and unchanged shapes"
  (define datums (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) datums))
  (check-equal? (take datums 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView
      AloemacsWindowTree AloemacsWindowRect AloemacsWindows AloemacsCommand
      (AloemacsKeymap B) AloemacsBinding AloemacsSearchScan (AloemacsSession H)))
  (define (decl name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (check-equal? (caddr (decl 'AloemacsModeLine)) '(fields))
  (check-equal? (caddr (decl 'AloemacsWindowRect)) '(fields (x Int) (y Int) (columns Int) (rows Int)))
  (check-equal? (caddr (decl 'AloemacsWindows))
                '(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int)))
  (check-equal? (length (cdr (caddr (decl '(AloemacsSession H))))) 14)
  (define tree-methods
    (append (methods-of (decl 'AloemacsWindowTree))
            (methods-of (findf (lambda (d) (and (eq? (car d) 'define-methods)
                                                (eq? (cadr d) 'AloemacsWindowTree)))
                               datums))))
  (define rect-methods (methods-of (decl 'AloemacsWindowRect)))
  (for ([gone '(horizontal-divider? vertical-divider? below-divider)])
    (check-false (assq gone tree-methods) (format "~s removed" gone)))
  (for ([gone '(divider-row divider-column)])
    (check-false (assq gone rect-methods) (format "~s removed" gone)))
  (check-equal? (take (assq 'frame-rows tree-methods) 5)
    '(frame-rows (buffers AloemacsBuffers) (rect AloemacsWindowRect) (selected Int) (List String)))
  (check-equal? (take (assq 'right-rows tree-methods) 4)
    '(right-rows (left-rows (List String)) (right-rows (List String)) (List String)))
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed '("abc")))))
  (def! st 'v (session (zipper '(a)) (below (leaf 7) (leaf 8))))
  (for ([bad '((((v windows) tree) frame-rows (v buffers) (AloemacsWindowRect new 0 0 3 4))
               (((v windows) tree) frame-rows (v buffers) (AloemacsWindowRect new 0 0 3 4) #t)
               (((v windows) tree) frame-rows (v buffers) (AloemacsWindowRect new 0 0 3 4) 7 7)
               ((AloemacsWindowRect new 0 0 3 4) divider-row)
               ((AloemacsWindowRect new 0 0 3 4) divider-column)
               (((v windows) tree) below-divider (AloemacsWindowRect new 0 0 3 4) 0 3))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st bad)) (format "reject ~s" bad)))
  (check-equal? (unbox calls) '()))

(test-case "Below division for extents zero through nine; Right is unchanged"
  (define-values (st calls) (state))
  (define stacked (below (leaf 0) (leaf 1)))
  (define beside (right (leaf 0) (leaf 1)))
  (for ([n (in-range 10)]
        [top '(0 1 1 2 2 3 3 4 4 5)]
        [bottom '(0 0 1 1 2 2 3 3 4 4)])
    (check-equal? (+ top bottom) n)
    (same st `(,stacked rect-for 0 ,(rect 2 3 7 n)) `(Option Some ,(rect 2 3 7 top)))
    (same st `(,stacked rect-for 1 ,(rect 2 3 7 n)) `(Option Some ,(rect 2 (+ 3 top) 7 bottom)))
    (same st `(,(rect 2 3 7 n) top) (rect 2 3 7 top))
    (same st `(,(rect 2 3 7 n) bottom) (rect 2 (+ 3 top) 7 bottom))
    (check-equal? (ev st `(,stacked positive-layout? ,(rect 2 3 7 n))) (>= n 2))
    (check-false (ev st `(,stacked positive-layout? ,(rect 2 3 0 n)))))
  (for ([n (in-range 10)]
        [left '(0 0 1 1 2 2 3 3 4 4)]
        [later '(0 0 0 1 1 2 2 3 3 4)]
        [offset '(0 1 2 2 3 3 4 4 5 5)])
    (same st `(,beside rect-for 0 ,(rect 2 3 n 4)) `(Option Some ,(rect 2 3 left 4)))
    (same st `(,beside rect-for 1 ,(rect 2 3 n 4)) `(Option Some ,(rect (+ 2 offset) 3 later 4)))
    (same st `(,(rect 2 3 n 4) left) (rect 2 3 left 4))
    (same st `(,(rect 2 3 n 4) right) (rect (+ 2 offset) 3 later 4))
    (check-equal? (ev st `(,beside positive-layout? ,(rect 2 3 n 4))) (>= n 3)))
  ;; Nested: the old rule row now belongs to a child, and text-rows is unchanged.
  (define nested (right (below (leaf 0) (leaf 1)) (below (leaf 2) (below (leaf 3) (leaf 4)))))
  (for ([id '(0 1 2 3 4)] [r '((0 0 4 3) (0 3 4 2) (5 0 4 3) (5 3 4 1) (5 4 4 1))])
    (same st `(,nested rect-for ,id ,(rect 0 0 9 5)) `(Option Some ,(apply rect r))))
  (check-true (ev st `(,nested positive-layout? ,(rect 0 0 9 5))))
  (check-true (ev st `(,nested positive-layout? ,(rect 0 0 9 4))))
  (same st `(,nested rect-for 4 ,(rect 0 0 9 3)) `(Option Some ,(rect 5 3 4 0)))
  (check-false (ev st `(,nested positive-layout? ,(rect 0 0 9 3))))
  (for ([rows '(0 1 2 3 9)] [text '(0 1 1 2 8)])
    (check-equal? (ev st `(,(rect 0 0 9 rows) text-rows)) text))
  (check-equal? (unbox calls) '()))

(test-case "real splits: the spec rectangles, visit order, the four-row minimum and stable neighbors"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed '("abc" "def")))))
  (def! st 'v (session (zipper '(a)) (leaf 7)))
  (def! st 'r '(v split-right))
  (def! st 'rb '(r split-below))
  (same st '((rb windows) tree) (right (below (leaf 7) (leaf 9)) (leaf 8)))
  (same st '(((rb windows) tree) leaves)
    '(List of (AloemacsView new 7 41 0 0 #f (Option None)) (AloemacsView new 9 41 0 0 #f (Option None))
              (AloemacsView new 8 41 0 0 #f (Option None))))
  (define (rects! s expected)
    (for ([entry expected])
      (same st `(((,s windows) tree) rect-for ,(car entry) ,(rect 0 0 9 5))
            `(Option Some ,(apply rect (cdr entry))))))
  (rects! 'rb '((7 0 0 4 3) (9 0 3 4 2) (8 5 0 4 5)))
  (check-equal? (ev st '((rb editor) text-rows)) 2)
  ;; The lower-left view is two rows: below refuses, right is allowed.
  (def! st 'low '(rb other-window))
  (check-equal? (ev st '((low windows) selected)) 9)
  (same-session st '(low split-below) (rebuild 'low #:echo "failed"))
  (def! st 'low-right '(low split-right))
  (same st '((low-right windows) tree) (right (below (leaf 7) (right (leaf 9) (leaf 10))) (leaf 8)))
  (rects! 'low-right '((7 0 0 4 3) (9 0 3 2 2) (10 3 3 1 2) (8 5 0 4 5)))
  ;; Splitting the right view below leaves its ancestors and siblings exact.
  (def! st 'far '(low other-window))
  (check-equal? (ev st '((far windows) selected)) 8)
  (def! st 'far-below '(far split-below))
  (same st '((far-below windows) tree) (right (below (leaf 7) (leaf 9)) (below (leaf 8) (leaf 10))))
  (rects! 'far-below '((7 0 0 4 3) (9 0 3 4 2) (8 5 0 4 3) (10 5 3 4 2)))
  (check-equal? (ev st '((far-below editor) text-rows)) 2)
  ;; One view: terminal 9 by 4 refuses; 9 by 5 gives two rows each.
  (def! st 'four (session (zipper '(a)) (leaf 7) #:rows 4))
  (same-session st '(four split-below) (rebuild 'four #:echo "failed"))
  (def! st 'five (session (zipper '(a)) (leaf 7) #:rows 5))
  (same-session st '(five split-below)
    (rebuild 'five #:echo "" #:buffers (zipper (list (buffer 41 (editor (indexed '("abc" "def")) 0 0 0 0 1))))
             #:windows (config (below (leaf 7) (leaf 8)) 7 9 5)))
  (for ([id '(7 8)] [r '((0 0 9 2) (0 2 9 2))])
    (same st `((((five split-below) windows) tree) rect-for ,id ,(rect 0 0 9 4))
          `(Option Some ,(apply rect r))))
  (check-equal? (unbox calls) '()))

(test-case "below splits by extent, right at three columns, unfitted and locked refusals"
  (define-values (st calls) (state))
  (define text (indexed '("abcdefghi" "jklmnopqr" "stuvwxyz" "last")))
  (def! st 'a (buffer 41 (editor text)))
  (for ([extent '(3 4 5 6 7 8 9)] [early '(#f 2 3 3 4 4 5)] [late '(#f 2 2 3 3 4 4)])
    (def! st 'v (session (zipper '(a)) (leaf 7) #:rows (add1 extent)))
    (cond
      [(not early) (same-session st '(v split-below) (rebuild 'v #:echo "failed"))]
      [else
       (same-session st '(v split-below)
         (rebuild 'v #:echo "" #:buffers (zipper (list (buffer 41 (editor text 0 0 0 0 (sub1 early)))))
                  #:windows (config (below (leaf 7) (leaf 8)) 7 9 (add1 extent))))
       (def! st 'r '(v split-below))
       (same st `(((r windows) tree) rect-for 7 ,(rect 0 0 9 extent)) `(Option Some ,(rect 0 0 9 early)))
       (same st `(((r windows) tree) rect-for 8 ,(rect 0 0 9 extent))
             `(Option Some ,(rect 0 early 9 late)))
       (same-session st `(r ensure-visible 9 ,(add1 extent)) 'r)]))
  ;; Right: three columns split into one and one; two refuse.
  (def! st 'v (session (zipper '(a)) (leaf 7) #:columns 3))
  (same-session st '(v split-right)
    (rebuild 'v #:echo "" #:buffers (zipper (list (buffer 41 (editor text 0 0 0 0 4))))
             #:windows (config (right (leaf 7) (leaf 8)) 7 3 6)))
  (for ([id '(7 8)] [r '((0 0 1 5) (2 0 1 5))])
    (same st `((((v split-right) windows) tree) rect-for ,id ,(rect 0 0 3 5))
          `(Option Some ,(apply rect r))))
  (def! st 'v (session (zipper '(a)) (leaf 7) #:columns 2))
  (same-session st '(v split-right) (rebuild 'v #:echo "failed"))
  ;; Unknown sizes and locks refuse both orientations.
  (for ([size '((0 0) (0 6) (9 0) (-1 6) (9 -1))])
    (def! st 'raw (session (zipper '(a)) (leaf 7) #:columns (car size) #:rows (cadr size)))
    (for ([send '(split-below split-right)])
      (same-session st `(raw ,send) (rebuild 'raw #:echo "failed"))))
  (def! st 'locked (session (zipper '(a)) (leaf 7 41 0 0 #t) #:rows 12))
  (for ([send '(split-below split-right)])
    (same-session st `(locked ,send) (rebuild 'locked #:echo "failed")))
  ;; A positive selected leaf can still be refused by the four-row minimum.
  (def! st 'short (session (zipper '(a)) (right (leaf 7) (leaf 8)) #:rows 4))
  (same st `(((short windows) tree) rect-for 7 ,(rect 0 0 9 3)) `(Option Some ,(rect 0 0 4 3)))
  (same-session st '(short split-below) (rebuild 'short #:echo "failed"))
  (check-equal? (unbox calls) '()))

(test-case "echo outcomes for every token at the below minimum, with and without prompt or search"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed '("abc" "def")))))
  (for* ([token '("" "saved" "failed")] [mode '(neither prompt search both)]
         [o '((split-below 4 5 1) (split-right 2 3 4))] [success? '(#f #t)])
    (define prompted? (and (memq mode '(prompt both)) #t))
    (define searching? (and (memq mode '(search both)) #t))
    (define active? (or prompted? searching?))
    (define vertical? (eq? (car o) 'split-below))
    (define w (if vertical? 9 (if success? (caddr o) (cadr o))))
    (define h (if vertical? (if success? (caddr o) (cadr o)) 6))
    (def! st 'raw (session (zipper '(a)) (leaf 7) #:columns w #:rows h #:echo token
                           #:searching searching? #:prompt (if prompted? active-prompt no-prompt)
                           #:pending pending))
    (same-session st `(raw ,(car o))
      (cond
        [success?
         (rebuild 'raw #:echo (if active? token "")
                  #:buffers (zipper (list (buffer 41 (editor (indexed '("abc" "def")) 0 0 0 0 (cadddr o)))))
                  #:windows (config ((if vertical? below right) (leaf 7) (leaf 8)) 7 w h))]
        [active? 'raw]
        [else (rebuild 'raw #:echo "failed")])))
  (check-equal? (unbox calls) '()))

(test-case "delete promotion and lock comparisons under the new division"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed '("abc" "def")))))
  (define (deleted tree selected w h)
    (def! st 'v (session (zipper '(a)) tree selected #:columns w #:rows h))
    (def! st 'd '(v delete-window)))
  ;; Promotion recomputes the sibling in the old parent's rectangle.
  (deleted (right (below (leaf 7) (leaf 9)) (leaf 8)) 9 9 6)
  (same st '((d windows) tree) (right (leaf 7) (leaf 8)))
  (check-equal? (ev st '((d windows) selected)) 7)
  (same st `(((d windows) tree) rect-for 7 ,(rect 0 0 9 5)) `(Option Some ,(rect 0 0 4 5)))
  (deleted (below (leaf 7) (below (leaf 2) (leaf 3))) 7 9 9)
  (same st '((d windows) tree) (below (leaf 2) (leaf 3)))
  (check-equal? (ev st '((d windows) selected)) 2)
  (for ([id '(2 3)] [r '((0 0 9 4) (0 4 9 4))])
    (same st `(((d windows) tree) rect-for ,id ,(rect 0 0 9 8)) `(Option Some ,(apply rect r))))
  ;; A locked descendant that would move from (0,4,9,2) to (0,0,9,4) refuses.
  (define moving (below (leaf 7) (below (leaf 2 41 0 0 #t) (leaf 3))))
  (same st `(,moving rect-for 2 ,(rect 0 0 9 8)) `(Option Some ,(rect 0 4 9 2)))
  (same st `(,(below (leaf 2 41 0 0 #t) (leaf 3)) rect-for 2 ,(rect 0 0 9 8))
        `(Option Some ,(rect 0 0 9 4)))
  (deleted moving 7 9 9)
  (same-session st 'd (rebuild 'v #:echo "failed"))
  ;; At extent three the descendant still moves, from (0,2,9,1) to (0,0,9,2).
  (deleted moving 7 9 4)
  (same-session st 'd (rebuild 'v #:echo "failed"))
  ;; The top of a Below at extent one keeps its row, so its locked
  ;; descendants do not move when the zero-height bottom is deleted.
  (define kept (below (below (leaf 2 41 0 0 #t) (leaf 3)) (leaf 7)))
  (for ([id '(2 3 7)] [r '((0 0 9 1) (0 1 9 0) (0 1 9 0))])
    (same st `(,kept rect-for ,id ,(rect 0 0 9 1)) `(Option Some ,(apply rect r))))
  (for ([id '(2 3)] [r '((0 0 9 1) (0 1 9 0))])
    (same st `(,(below (leaf 2 41 0 0 #t) (leaf 3)) rect-for ,id ,(rect 0 0 9 1))
          `(Option Some ,(apply rect r))))
  (deleted kept 7 9 2)
  (same st '((d windows) tree) (below (leaf 2 41 0 0 #t) (leaf 3)))
  (check-equal? (ev st '((d windows) selected)) 2)
  (check-equal? (ev st '(d echo)) "")
  ;; A locked view outside the promoted sibling never moves.
  (deleted (below (leaf 2 41 0 0 #t) (below (leaf 7) (leaf 3))) 7 9 9)
  (same st '((d windows) tree) (below (leaf 2 41 0 0 #t) (leaf 3)))
  (check-equal? (ev st '((d windows) selected)) 3)
  (for ([id '(2 3)] [r '((0 0 9 4) (0 4 9 4))])
    (same st `(((d windows) tree) rect-for ,id ,(rect 0 0 9 8)) `(Option Some ,(apply rect r))))
  (check-equal? (unbox calls) '()))

(test-case "the spec examples byte for byte, in both orientations, with either selection"
  (define-values (st calls) (state))
  (define lines '("one" "two" "three" "four"))
  (def! st 'a (buffer 0 (editor (indexed lines) 0 0 0 0) "/a"))
  (def! st 'v (session (zipper '(a)) (below (leaf 0 0 0 0) (leaf 1 0 2 0)) 0 #:columns 8 #:rows 6))
  (define stacked
    "\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a -----\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a -----\e[0m\e[6;1H\e[1;1H\e[?25h")
  (define stacked-rows (append (cells lines 8 3 0 0 "/a" #t) (cells lines 8 2 2 0 "/a" #f)))
  (check-equal? (multi stacked-rows 1 1 8 6 "") stacked)
  (paint st 'v 8 6 stacked calls)
  (rows! st 'v 8 5 stacked-rows)
  (check-rows stacked-rows 8 5 #:light 1 #:dark 1)
  ;; The same views side by side.
  (def! st 'v (session (zipper '(a)) (right (leaf 0 0 0 0) (leaf 1 0 2 0)) 0 #:columns 8 #:rows 6))
  (define beside (side (cells lines 4 5 0 0 "/a" #t) (cells lines 3 5 2 0 "/a" #f)))
  (check-equal? beside
    (list "one |thr" "two |fou" "thre|   " "four|   "
          (string-append LIGHT "/a -" PLAIN "|" DARK "/a " PLAIN)))
  (paint st 'v 8 6 (multi beside 1 1 8 6 "") calls)
  (rows! st 'v 8 5 beside)
  (check-rows beside 8 5 #:light 1 #:dark 1 #:dividers '((4 0 4)))
  ;; Mixed nesting, view 1 selected.
  (def! st 'a (buffer 0 (editor (indexed a-lines 3) 3 2 3 1) "/a"))
  (def! st 'b (buffer 1 (editor (indexed b-lines 1) 1 2 1 2) "/b"))
  (define mixed-tree (right (below (leaf 0 0 0 0) (leaf 1 0 3 1)) (leaf 2 1 1 2)))
  (def! st 'v (session (zipper '(a b)) mixed-tree 1))
  (define mixed
    "\e[?25l\e[2J\e[Habcd|HIJ \r\nghij|MNO \r\n\e[38;5;252;48;5;239m/a -\e[0m|RST \r\ntuvw|WXY \r\n\e[38;5;16;48;5;250m/a -\e[0m|\e[38;5;252;48;5;239m/b -\e[0m\e[6;1H\e[4;2H\e[?25h")
  (define (mixed-rows selected)
    (side (append (cells a-lines 4 3 0 0 "/a" (= selected 0)) (cells a-lines 4 2 3 1 "/a" (= selected 1)))
          (cells b-lines 4 5 1 2 "/b" (= selected 2))))
  (check-equal? (map visible (mixed-rows 1)) '("abcd|HIJ " "ghij|MNO " "/a -|RST " "tuvw|WXY " "/a -|/b -"))
  (check-equal? (multi (mixed-rows 1) 4 2 9 6 "") mixed)
  (paint st 'v 9 6 mixed calls)
  (rows! st 'v 9 5 (mixed-rows 1))
  (check-rows (mixed-rows 1) 9 5 #:light 1 #:dark 2 #:dividers '((4 0 4)))
  ;; Selecting view 0 swaps only the two left bars and the cursor.
  (def! st 'a0 (buffer 0 (editor (indexed a-lines 0) 0 0 0 0) "/a"))
  (def! st 'v0 (session (zipper '(a0 b)) mixed-tree 0))
  (paint st 'v0 9 6 (multi (mixed-rows 0) 1 1 9 6 "") calls)
  (check-equal? (map visible (mixed-rows 0)) (map visible (mixed-rows 1)))
  (check-equal? (list-ref (mixed-rows 0) 2) (string-append LIGHT "/a -" PLAIN "|RST "))
  (check-equal? (list-ref (mixed-rows 0) 4)
                (string-append DARK "/a -" PLAIN "|" DARK "/b -" PLAIN))
  (check-rows (mixed-rows 0) 9 5 #:light 1 #:dark 2 #:dividers '((4 0 4)))
  ;; Selecting view 2 makes every left bar DARK.
  (def! st 'b2 (buffer 1 (editor (indexed b-lines 1) 1 2 1 2) "/b"))
  (def! st 'v2 (session (zipper '(a b2) 1) mixed-tree 2))
  (paint st 'v2 9 6 (multi (mixed-rows 2) 1 6 9 6 "") calls)
  (check-rows (mixed-rows 2) 9 5 #:light 1 #:dark 2 #:dividers '((4 0 4)))
  ;; The transposed mixed tree: Below(Right(view 0, view 1), view 2).
  (define transposed (below (right (leaf 0 0 0 0) (leaf 1 0 3 1)) (leaf 2 1 1 2)))
  (def! st 'v (session (zipper '(a b)) transposed 1))
  (define t-rows (append (side (cells a-lines 4 3 0 0 "/a" #f) (cells a-lines 4 3 3 1 "/a" #t))
                         (cells b-lines 9 2 1 2 "/b" #f)))
  (check-equal? t-rows
    (list "abcd|tuvw" "ghij|z012" (string-append DARK "/a -" PLAIN "|" LIGHT "/a -" PLAIN)
          "HIJ      " (string-append DARK "/b ------" PLAIN)))
  (paint st 'v 9 6 (multi t-rows 1 7 9 6 "") calls)
  (rows! st 'v 9 5 t-rows)
  (check-rows t-rows 9 5 #:light 1 #:dark 2 #:dividers '((4 0 2)))
  (check-equal? (unbox calls) '()))

(test-case "deeper nesting, shared and distinct buffers, width one, names, controls and dangling IDs"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed a-lines 0) 0 0 0 0) "/a"))
  (def! st 'b (buffer 9 (editor (indexed b-lines 0)) "/b"))
  ;; Three levels: Below(Right(Below(0, 1), 2), Right(3, Below(4, 5))).
  (define deep (below (right (below (leaf 0) (leaf 1 41 2 1)) (leaf 2 9 1 0))
                      (right (leaf 3 9 3 3) (below (leaf 4 41 0 0) (leaf 5 41 99 101)))))
  (def! st 'v (session (zipper '(a b)) deep 4 #:rows 11))
  (define deep-rows
    (append (side (append (cells a-lines 4 3 0 0 "/a" #f) (cells a-lines 4 2 2 1 "/a" #f))
                  (cells b-lines 4 5 1 0 "/b" #f))
            (side (cells b-lines 4 5 3 3 "/b" #f)
                  (append (cells a-lines 4 3 0 0 "/a" #t) (cells a-lines 4 2 99 101 "/a" #f)))))
  (check-equal? (map visible deep-rows)
    '("abcd|FGHI" "ghij|KLMN" "/a -|PQRS" "nopq|UVWX" "/a -|/b -"
      "ST  |abcd" "XY  |ghij" "    |/a -" "    |    " "/b -|/a -"))
  (paint st 'v 9 11 (multi deep-rows 6 6 9 11 "") calls)
  (rows! st 'v 9 10 deep-rows)
  (check-rows deep-rows 9 10 #:light 1 #:dark 5 #:dividers '((4 0 4) (4 5 9)))
  ;; Identical names on distinct buffer IDs paint their own text.
  (def! st 'twin (buffer 9 (editor (indexed b-lines 0)) "/a"))
  (def! st 'v (session (zipper '(a twin)) (right (leaf 0) (leaf 1 9)) 0))
  (define twins (side (cells a-lines 4 5 0 0 "/a" #t) (cells b-lines 4 5 0 0 "/a" #f)))
  (paint st 'v 9 6 (multi twins 1 1 9 6 "") calls)
  (check-rows twins 9 5 #:light 1 #:dark 1 #:dividers '((4 0 4)))
  (check-equal? (map visible twins) '("abcd|ABCD" "ghij|FGHI" "mnop|KLMN" "stuv|PQRS" "/a -|/a -"))
  ;; Width-one leaves, long names, controls and punctuation stay inside bars.
  (for ([name '("/a" "/a/very/long/name" "a\e[31m\tb" "-|+\u007fname" "|" "+")])
    (def! st 'n (buffer 41 (editor (indexed '("x" "y" "z"))) name))
    (for ([w '(1 2 4)])
      (define columns (add1 (* 2 w)))
      (def! st 'v (session (zipper '(n)) (right (leaf 0) (below (leaf 1) (leaf 2 41 1 0))) 0
                           #:columns columns))
      (define rows (side (cells '("x" "y" "z") w 5 0 0 name #t)
                         (append (cells '("x" "y" "z") w 3 0 0 name #f)
                                 (cells '("x" "y" "z") w 2 1 0 name #f))))
      (paint st 'v columns 6 (multi rows 1 1 columns 6 "") calls)
      (rows! st 'v columns 5 rows)
      (check-rows rows columns 5 #:light 1 #:dark 2 #:dividers `((,w 0 4)) #:punctuation-names #t)
      (for ([row rows] [y (in-naturals)] #:when (memv y '(2 4)))
        (for ([r (runs row)] #:unless (eq? (car r) 'plain))
          (check-equal? (cdr r) (mode name w))))))
  ;; A valid inactive origin beyond EOF paints blank text and its bar.
  (def! st 'v (session (zipper '(a)) (below (leaf 0) (leaf 1 41 99 101)) 0))
  (define beyond (append (cells a-lines 9 3 0 0 "/a" #t) (list (make-string 9 #\space))
                         (list (painted (mode "/a" 9) #f))))
  (check-equal? beyond (append (cells a-lines 9 3 0 0 "/a" #t) (cells a-lines 9 2 99 101 "/a" #f)))
  (paint st 'v 9 6 (multi beyond 1 1 9 6 "") calls)
  (check-rows beyond 9 5 #:light 1 #:dark 1)
  ;; A raw dangling buffer ID paints blank rows and no bar, selected or not.
  (for ([selected '(0 1)])
    (def! st 'v (session (zipper '(a)) (below (leaf 0) (leaf 1 999)) selected))
    (define dangling (append (cells a-lines 9 3 0 0 "/a" (= selected 0)) (blank 9 2)))
    (rows! st 'v 9 5 dangling)
    (check-rows dangling 9 5 #:light (if (= selected 0) 1 0) #:dark (if (= selected 0) 0 1)))
  (def! st 'v (session (zipper '(a)) (right (leaf 0 999) (leaf 1)) 1))
  (define dangling-side (side (blank 4 5) (cells a-lines 4 5 0 0 "/a" #t)))
  (rows! st 'v 9 5 dangling-side)
  (check-rows dangling-side 9 5 #:light 1 #:dark 0 #:dividers '((4 0 4)))
  (check-equal? (unbox calls) '()))

(test-case "bar counts: one LIGHT for a tall selected leaf, none for a short one; all-short has none"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed a-lines 0)) "/a"))
  ;; Root 9 by 3: Below at extent three gives a tall top and a short bottom.
  (define t (right (below (leaf 0) (leaf 1)) (leaf 2)))
  (for ([selected '(0 1 2)] [light '(1 0 1)] [dark '(1 2 1)] [cur '((1 1) (3 1) (1 6))])
    (def! st 'v (session (zipper '(a)) t selected #:rows 4))
    (define rows (side (append (cells a-lines 4 2 0 0 "/a" (= selected 0))
                               (cells a-lines 4 1 0 0 "/a" (= selected 1)))
                       (cells a-lines 4 3 0 0 "/a" (= selected 2))))
    (check-equal? (map visible rows) '("abcd|abcd" "/a -|ghij" "abcd|/a -"))
    (check-equal? (list-ref rows 2)
      (string-append "abcd|" (painted "/a -" (= selected 2))))
    (paint st 'v 9 4 (multi rows (car cur) (cadr cur) 9 4 (if (= selected 1) "/a" "")) calls)
    (rows! st 'v 9 3 rows)
    (check-rows rows 9 3 #:light light #:dark dark #:dividers '((4 0 2))))
  ;; A short selected leaf beside a short neighbor: positive, no sequence.
  (for ([tree (list (below (leaf 0) (leaf 1)) (right (below (leaf 0) (leaf 1)) (below (leaf 2) (leaf 3))))]
        [rows (list '("abcdef   " "abcdef   ") '("abcd|abcd" "abcd|abcd"))])
    (for ([selected '(0 1)])
      (def! st 'v (session (zipper '(a)) tree selected #:rows 3))
      (define frame (multi rows (add1 selected) 1 9 3 "/a"))
      (paint st 'v 9 3 frame calls)
      (check-true (no-sequence? frame))
      (check-rows rows 9 2 #:light 0 #:dark 0)))
  (check-equal? (unbox calls) '()))

(test-case "other-window and delete move the LIGHT bar; prompt, search and list keep it"
  (define-values (st calls) (state))
  (def! st 'a (buffer 41 (editor (indexed a-lines 0)) "/a"))
  (def! st 'v (session (zipper '(a)) (right (below (leaf 0) (leaf 1)) (leaf 2)) 0))
  (define (rows-for selected)
    (side (append (cells a-lines 4 3 0 0 "/a" (= selected 0)) (cells a-lines 4 2 0 0 "/a" (= selected 1)))
          (cells a-lines 4 5 0 0 "/a" (= selected 2))))
  (paint st 'v 9 6 (multi (rows-for 0) 1 1 9 6 "") calls)
  (for ([selected '(1 2 0)] [cur '((4 1) (1 6) (1 1))])
    (def! st 'v '(v other-window))
    (check-equal? (ev st '((v windows) selected)) selected)
    (paint st 'v 9 6 (multi (rows-for selected) (car cur) (cadr cur) 9 6 "") calls)
    (check-rows (rows-for selected) 9 5 #:light 1 #:dark 2 #:dividers '((4 0 4))))
  ;; Deleting view 0 enters view 1 in the promoted Right; deleting view 2
  ;; promotes the Below into the whole root.
  (def! st 'd '(v delete-window))
  (check-equal? (ev st '((d windows) selected)) 1)
  (define after-0 (side (cells a-lines 4 5 0 0 "/a" #t) (cells a-lines 4 5 0 0 "/a" #f)))
  (paint st 'd 9 6 (multi after-0 1 1 9 6 "") calls)
  (check-rows after-0 9 5 #:light 1 #:dark 1 #:dividers '((4 0 4)))
  (def! st 'd '(((v other-window) other-window) delete-window))
  (check-equal? (ev st '((d windows) selected)) 0)
  (define after-2 (append (cells a-lines 9 3 0 0 "/a" #t) (cells a-lines 9 2 0 0 "/a" #f)))
  (paint st 'd 9 6 (multi after-2 1 1 9 6 "") calls)
  (check-rows after-2 9 5 #:light 1 #:dark 1)
  ;; A prompt owns the echo row and cursor; the selected bar stays LIGHT.
  (def! st 'p '((v other-window) with-active-prompt
                (AloemacsPrompt new "P:" "x" 1 "" (List empty) (List empty) 0)))
  (paint st 'p 9 6 (multi (rows-for 1) 6 4 9 6 "P:x") calls)
  ;; Search keeps the text cursor.
  (def! st 'q '((v other-window) with-search ((v other-window) editor) #t "q" (Position new 0 0) #f #f))
  (paint st 'q 9 6 (multi (rows-for 1) 4 1 9 6 "search: q") calls)
  ;; A painted completion list follows the root's last PLAIN.
  (def! st 'listed '((v other-window) with-active-prompt
                     (AloemacsPrompt new "Find: " "x" 1 "" (List of "alpha" "b\tc") (List empty) 0)))
  (define framed (multi (rows-for 1) 8 8 9 8 "Find: x"
                        #:list (string-append (cursor 6 1) "alpha" (cursor 7 1) "b c")))
  (paint st 'listed 9 8 framed calls)
  (check-true (string-contains? framed
                (string-append DARK "/a -" PLAIN "\e[6;1Halpha\e[7;1Hb c\e[8;1HFind: x\e[8;8H")))
  (check-equal? (unbox calls) '()))

(test-case "selected fit at the new heights, page travel at text heights one to three, post-split fit"
  (define-values (st calls) (state))
  (define lines (for/list ([i (in-range 12)]) (format "abcdef~a" i)))
  (define text (indexed lines 4))
  ;; Below(locked 7 at (8,2), selected 3): bottom text heights one, two, three.
  (for ([h '(5 7 9)] [height '(1 2 3)] [early '(2 3 4)] [origin '(4 3 2)] [distance '(1 1 2)])
    (def! st 'a (buffer 41 (editor text 4 5 0 0)))
    (def! st 'v (session (zipper '(a)) (below (leaf 7 41 8 2 #t) (leaf 3)) 3 #:columns 4 #:rows h))
    (def! st 'fit `(v ensure-visible 4 ,h))
    (check-equal? (ev st '((fit editor) text-rows)) height)
    (check-equal? (ev st '((fit editor) page-distance)) distance)
    (check-equal? (ev st '((fit editor) scroll-row)) origin)
    (check-equal? (ev st '((fit editor) scroll-col)) 2)
    (same st '((fit windows) tree) (below (leaf 7 41 8 2 #t) (leaf 3 41 origin 2)))
    (same-session st `(fit ensure-visible 4 ,h) 'fit)
    (define rows (append (cells lines 4 early 8 2 "untitled" #f)
                         (cells lines 4 (add1 height) origin 2 "untitled" #t)))
    (paint st 'fit 4 h (multi rows (+ early (- 4 origin) 1) 4 4 h "") calls)
    (check-rows rows 4 (sub1 h) #:light 1 #:dark 1)
    (for ([send '(page-up page-down)] [line (list (- 4 distance) (+ 4 distance))]
          [top (list (min origin (- 4 distance)) (+ origin distance))])
      (def! st 'moved `((fit ,send) ensure-visible 4 ,h))
      (check-equal? (ev st '((moved point) line)) line)
      (check-equal? (ev st '((moved editor) scroll-row)) top)
      (same st '(((moved windows) tree) find-view 7) '(Option Some (AloemacsView new 7 41 8 2 #t (Option None))))
      (same st '((moved editor) history) history)))
  ;; A split fits once at the selected child's text height; the fresh child
  ;; keeps the pre-split origin.
  (def! st 'a (buffer 41 (editor text 4 5 0 0)))
  (def! st 'v (session (zipper '(a)) (leaf 7) #:rows 7))
  (def! st 'split '(v split-below))
  (same st '((split windows) tree) (below (leaf 7 41 3 0) (leaf 8 41 0 0)))
  (check-equal? (ev st '((split editor) text-rows)) 2)
  (check-equal? (ev st '((split editor) scroll-row)) 3)
  (same-session st '(split ensure-visible 9 7) 'split)
  (define split-rows (append (cells lines 9 3 3 0 "untitled" #t) (cells lines 9 3 0 0 "untitled" #f)))
  (paint st 'split 9 7 (multi split-rows 2 6 9 7 "") calls)
  ;; Selecting the fresh view fits there; the departed origin stays.
  (def! st 'other '((split other-window) ensure-visible 9 7))
  (same st '((other windows) tree) (below (leaf 7 41 3 0) (leaf 8 41 3 0)))
  (check-equal? (ev st '((other editor) text-rows)) 2)
  (check-equal? (unbox calls) '()))

(test-case "a zero axis paints the one-view bar; growth restores split bars with state intact"
  (define-values (st calls) (state))
  (def! st 'a (buffer 0 (editor (indexed a-lines 3) 3 2 3 1) "/a"))
  (def! st 'b (buffer 1 (editor (indexed b-lines 1) 1 2 1 2) "/b"))
  (define tree (right (below (leaf 0 0 0 0) (leaf 1 0 3 1)) (leaf 2 1 1 2 #t)))
  (def! st 'v (session (zipper '(a b)) tree 1))
  ;; Width two: Right's right child has zero columns.
  (def! st 'narrow '(v ensure-visible 2 6))
  (define narrow (one-view "tu\r\nz0\r\n\r\n" 1 2 2 6 "/a" ""))
  (paint st 'narrow 2 6 narrow calls)
  (check-equal? (occurrences narrow LIGHT) 1)
  (check-equal? (occurrences narrow DARK) 0)
  ;; Root height one: Below at extent one has a zero bottom; no sequence.
  (def! st 'tiny '(narrow ensure-visible 9 2))
  (define tiny (one-view "tuvwx" 1 2 9 2 "/a" "/a"))
  (paint st 'tiny 9 2 tiny calls)
  (check-true (no-sequence? tiny))
  ;; Growth: the §7.2 mixed frame, with view 2 still locked.
  (def! st 'grown '(tiny ensure-visible 9 6))
  (paint st 'grown 9 6
    "\e[?25l\e[2J\e[Habcd|HIJ \r\nghij|MNO \r\n\e[38;5;252;48;5;239m/a -\e[0m|RST \r\ntuvw|WXY \r\n\e[38;5;16;48;5;250m/a -\e[0m|\e[38;5;252;48;5;239m/b -\e[0m\e[6;1H\e[4;2H\e[?25h"
    calls)
  (for ([s '(narrow tiny grown)])
    (same st `((,s windows) tree) tree)
    (check-equal? (ev st `((,s windows) selected)) 1))
  (check-equal? (unbox calls) '()))

(test-case "the production runner splits, selects, edits, prompts, saves, deletes, resizes and quits"
  (define keys '("ctrl-x" "2" "ctrl-x" "3" "ctrl-x" "o" "X" "ctrl-x" "find" "escape" "save"
                 "ctrl-x" "0" "escape"))
  (define sizes (for/list ([i (in-range (length keys))]) (if (= i 7) '(9 4) '(9 6))))
  (define (bars a b) (string-append (painted "/cwd" a) "|" (painted "/cwd" b)))
  (define initial
    (string-append "\e[?25l\e[2J\e[Hzero\r\none\r\ntwo\r\nthree\e[1;1H\e[?25h\e[?25l\e[5;1H"
                   LIGHT "/cwd/a --" PLAIN "\e[6;1H\e[1;1H\e[?25h"))
  (define stacked (list "zero     " "one      " (painted "/cwd/a --" #t) "zero     "
                        (painted "/cwd/a --" #f)))
  ;; Below(Right(view 0, view 2), view 1): (0,0,4,3), (5,0,4,3), (0,3,9,2).
  (define (mixed line0 left?)
    (define cell (pad (clip line0 4) 4))
    (list (string-append cell "|" cell) "one |one " (bars left? (not left?))
          (pad line0 9) (painted "/cwd/a --" #f)))
  (define mixed-0 (mixed "zero" #t))
  (define mixed-2 (mixed "zero" #f))
  (define edited (mixed "Xzero" #f))
  (define short-rows (list "Xzer|Xzer" (bars #f #t) "Xzero    "))
  (define deleted (list "Xzero    " "one      " (painted "/cwd/a --" #t) "Xzero    "
                        (painted "/cwd/a --" #f)))
  (check-equal? (list-ref mixed-0 3) "zero     ")
  (check-equal? (list-ref edited 3) "Xzero    ")
  (define frames
    (list initial initial
          (multi stacked 1 1 9 6 "") (multi stacked 1 1 9 6 "")
          (multi mixed-0 1 1 9 6 "") (multi mixed-0 1 1 9 6 "")
          (multi mixed-2 1 6 9 6 "")
          (multi short-rows 1 7 9 4 "")
          (multi edited 1 7 9 6 "")
          (multi edited 6 9 9 6 "Find file: /cwd/")
          (multi edited 1 7 9 6 "")
          (multi edited 1 7 9 6 "saved: /cwd/a")
          (multi edited 1 7 9 6 "")
          (multi deleted 1 2 9 6 "")))
  (check-rows stacked 9 5 #:light 1 #:dark 1)
  (check-rows mixed-0 9 5 #:light 1 #:dark 2 #:dividers '((4 0 2)))
  (check-rows mixed-2 9 5 #:light 1 #:dark 2 #:dividers '((4 0 2)))
  (check-rows short-rows 9 3 #:light 1 #:dark 1 #:dividers '((4 0 1)))
  (check-rows edited 9 5 #:light 1 #:dark 2 #:dividers '((4 0 2)))
  (check-rows deleted 9 5 #:light 1 #:dark 1)
  (define events '())
  (define (record! x) (set! events (append events (list x))))
  (define dimensions 0)
  (define remaining keys)
  (define out (make-output-port 'window-bars-split always-evt
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
  (define-values (fs calls) (counted-fs))
  (run-aloemacs-with-hosts term fs "a")
  (check-equal? remaining '())
  (check-equal? dimensions (* 2 (length keys)))
  (check-equal? events
    (append-map (lambda (size key expected)
                  (list (list 'columns (car size)) (list 'rows (cadr size))
                        (list 'write expected) 'flush (list 'key key))) sizes keys frames))
  (check-equal? (length (filter (lambda (e) (and (pair? e) (eq? (car e) 'write))) events)) 14)
  (check-equal? (length (filter (lambda (e) (and (pair? e) (eq? (car e) 'key))) events)) 14)
  (check-equal? (filter (lambda (c) (memq (car c) '(read write))) (unbox calls))
                '((read "/cwd/a") (write "/cwd/a" "Xzero\none\ntwo\nthree")))
  (check-equal? (unbox calls)
    '((resolve "a") (resolve "/cwd/a") (kind "/cwd/a") (resolve "/cwd/a")
      (kind "/cwd/a") (resolve "/cwd/a") (read "/cwd/a")
      (root? "/cwd/a") (parent "/cwd/a")
      (kind "/cwd/a") (resolve "/cwd/a") (write "/cwd/a" "Xzero\none\ntwo\nthree"))))
