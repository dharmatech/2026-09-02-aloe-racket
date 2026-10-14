#lang racket/base

;; aloemacs-split-drag 003: a left press on the mode line between an upper and
;; a lower window arms that Below, unless the cell is a label, which stays its
;; command. A move while armed makes the pointer row the upper window's last
;; row, within the structural floor, and rewrites that split's weights. The
;; left release ends the drag. No TTY is opened here.

(require racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/term.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/aloemacs-run.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path text-path "../../lib/text.aloe")
(define-runtime-path fs-path "../../lib/fs.aloe")

;; The fs double of mouse.rkt.
(define (fs-double)
  (make-fs-double "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
    (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b")))

(define st (make-driver))
(driver-inject-host! st 'fs-host (fs-double))
(void (driver-load-file! st main-path))
(driver-eval! st `(load ,(path->string file-path)))
(driver-eval! st `(load ,(path->string editor-path)))
(driver-eval! st `(load ,(path->string text-path)))
(driver-eval! st `(load ,(path->string fs-path)))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))
(define (same actual expected)
  (check-not-exn (lambda () (ev `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (dtype expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (rejects bad)
  (check-exn exn:fail:aloe-type? (lambda () (ev bad)) (format "reject ~s" bad)))

;; Expected values use raw constructors and selectors only.
(define (rect x y w h) `(AloemacsWindowRect new ,x ,y ,w ,h))
(define (some r) `(Option Some ,r))
(define (pos p) `(Position new ,(car p) ,(cadr p)))

;; A node's weights, read through a case with an else arm; a Leaf reads -1.
(define (earlier-of tree) `(,tree case (Right (l r e la) e) (Below (t b e la) e) (else -1)))
(define (later-of tree) `(,tree case (Right (l r e la) la) (Below (t b e la) la) (else -1)))
(define (weights tree) (list (ev (earlier-of tree)) (ev (later-of tree))))
(define (weights! tree expected)
  (check-equal? (weights tree) expected (format "~s reads ~s" tree expected)))
(define (first-child tree) `(,tree case (Below (t b e la) t) (Right (l r e la) l) (else ,tree)))
(define (kind tree)
  (ev `(,tree case (Leaf (v) "Leaf") (Below (t b e la) "Below") (Right (l r e la) "Right"))))

(define (press s event) `(,s handle-event ,event))
(define (tree-of s) `((,s windows) tree))
(define (armed s n) `(,s with (windows ((,s windows) armed ,n))))
(define (armed? s) (ev `(((,s windows) drag) present?)))
(define (drag! s n) (same `((,s windows) drag) `(Option Some ,n)))
(define (selected! s id) (check-equal? (ev `((,s windows) selected)) id))
(define (at! s point) (same `(,s point) (pos point)))
(define (echo-of s) (ev `(,s echo)))
(define (locked? s id)
  (ev `((((,s windows) tree) find-view ,id) case (None () #f) (Some (v) (v locked)))))
(define (unchanged! s event)
  (same `(,s handle-event ,event) s))

;; The tree with the weights of the split at path replaced. A path is a list
;; of steps into the top or left child; each level binds its own names.
(define (reweighted tree path earlier later)
  (define (nm base) (string->symbol (format "~a~a" base (length path))))
  (define-values (x y e la) (values (nm 'x) (nm 'y) (nm 'e) (nm 'la)))
  (define (child) (if (null? path) x (reweighted x (cdr path) earlier later)))
  (define-values (ew lw) (if (null? path) (values earlier later) (values e la)))
  `(,tree case
     (Right (,x ,y ,e ,la) (AloemacsWindowTree Right ,(child) ,y ,ew ,lw))
     (Below (,x ,y ,e ,la) (AloemacsWindowTree Below ,(child) ,y ,ew ,lw))
     (else ,tree)))

;; s armed n, with only the weights of the split at path rewritten.
(define (dragged s n path earlier later)
  `(,s with (windows ((,s windows) with
     (tree ,(reweighted (tree-of s) path earlier later))
     (drag (Option Some ,n))))))

;; s with only the weights of the split at path rewritten; drag as s has it.
(define (settled s path earlier later)
  `(,s with (windows ((,s windows) with
     (tree ,(reweighted (tree-of s) path earlier later))))))

;; Each row is id x y columns rows, read through rect-for on r.
(define (rects! s r rows)
  (for ([row rows])
    (same `(,(tree-of s) rect-for ,(car row) ,r) (some (apply rect (cdr row))))))

(define contents "hello\nworld\nxyz")

;; Fixtures. Every weight is 1 1 before a drag.
(def! 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt")) ensure-visible 80 24))
(define session-type (dtype 's0))
(def! 'sb '(s0 split-below))
(def! 'sbb '(sb split-below))
(def! 'sbbb '(sbb split-below))
(def! 'sbr '(sb split-right))
(def! 'srb '((s0 split-right) split-below))
(def! 'lb '((((sbr other-window) other-window) toggle-window-lock) other-window))
(def! 'ls '(((sb other-window) toggle-window-lock) other-window))
(def! 's40b '((s0 ensure-visible 40 10) split-below))
(def! 'root '(AloemacsWindowRect new 0 0 80 23))
(def! 'v0 '((((sb windows) tree) leaves) first))
(def! 'v1 '(((((sb windows) tree) leaves) rest) first))
(def! 'sb1 (armed 'sb 1))

;; 1. Types and arities.
(test-case "types: min-rows, rows-from, press-mode-line, the session sends, the declarations"
  (def! 't '((sb windows) tree))
  (check-equal? (dtype '(t min-rows)) 'Int)
  (rejects '(t min-rows 1))
  (check-equal? (dtype '(t rows-from 1 2 3 4 5)) 'Int)
  (rejects '(t rows-from 1 2 3 4))
  (rejects '(t rows-from 1 2 3 4 5 6))
  (check-equal? (dtype '(sb press-mode-line v0 root 0)) session-type)
  (rejects '(sb press-mode-line v0 root))
  (rejects '(sb press-mode-line v0 root 0 0))
  (for ([selector '(press-at press-handle drag-to)])
    (check-equal? (dtype `(sb ,selector 0 0)) session-type))
  (check-equal? (dtype '(sb handle-event "x")) session-type)
  (check-equal? (dtype '(sb handle-mouse "x")) session-type)
  ;; Read as data: the tree and configuration payloads and the ordered
  ;; define-class list split-drag-weights.rkt pins.
  (define source (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) source))
  (define (decl name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (check-equal? (caddr (decl 'AloemacsWindowTree))
    '(constructors
       (Leaf (fields (view AloemacsView)))
       (Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree) (earlier Int) (later Int)))
       (Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree) (earlier Int) (later Int)))))
  (check-equal? (caddr (decl 'AloemacsWindows))
    '(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int) (drag (Option Int))))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B)
      AloemacsBinding AloemacsSearchScan AloemacsMouse (AloemacsSession H))))

;; The fixtures lay out as the checkpoint states.
(test-case "fixtures: sb, sbb, sbbb, sbr, srb, and s40b"
  (rects! 'sb 'root '((0 0 0 80 12) (1 0 12 80 11)))
  (check-equal? (map kind (list (tree-of 'sbb) (first-child (tree-of 'sbb)))) '("Below" "Below"))
  (rects! 'sbb 'root '((0 0 0 80 6) (2 0 6 80 6) (1 0 12 80 11)))
  (rects! 'sbbb 'root '((0 0 0 80 3) (3 0 3 80 3) (2 0 6 80 6) (1 0 12 80 11)))
  (check-equal? (map kind (list (tree-of 'sbr) (first-child (tree-of 'sbr)))) '("Below" "Right"))
  (rects! 'sbr 'root '((0 0 0 40 12) (2 41 0 39 12) (1 0 12 80 11)))
  (check-equal? (map kind (list (tree-of 'srb) (first-child (tree-of 'srb)))) '("Right" "Below"))
  (rects! 'srb 'root '((0 0 0 40 12) (2 0 12 40 11) (1 41 0 39 23)))
  (rects! 's40b '(AloemacsWindowRect new 0 0 40 9) '((0 0 0 40 5) (1 0 5 40 4)))
  (check-true (locked? 'lb 1))
  (selected! 'lb 0)
  (check-true (locked? 'ls 1))
  (selected! 'ls 0))

;; 2. The floor, on trees built with raw constructors.
(define leaf '(AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 (Position new 0 0) #f (Option None))))
(define (R a b [earlier 1] [later 1]) `(AloemacsWindowTree Right ,a ,b ,earlier ,later))
(define (B a b [earlier 1] [later 1]) `(AloemacsWindowTree Below ,a ,b ,earlier ,later))

(test-case "the floor: min-rows counts every leaf, each child divided by its own weights"
  (for ([row (list (list leaf 2)
                   (list (B leaf leaf) 4)
                   (list (B leaf leaf 1 22) 4)
                   (list (B leaf leaf 22 1) 4)
                   (list (R leaf leaf) 2)
                   (list (R leaf leaf 1 78) 2)
                   (list (R leaf leaf 78 1) 2)
                   (list (B (R leaf leaf) leaf) 4)
                   (list (R (B leaf leaf) leaf) 4)
                   (list (B (B leaf leaf) leaf) 7)
                   (list (B (B leaf leaf) leaf 4 8) 10)
                   (list (R (R leaf leaf) leaf) 2)
                   (list (B (B (B leaf leaf) leaf) leaf) 13)
                   (list (R (R (R leaf leaf) leaf) leaf) 2))])
    (check-equal? (ev `(,(car row) min-rows)) (cadr row) (format "~s" (car row))))
  ;; The 4 8 reading: the search starts at 6 and the top first gets 4 at 10.
  (check-equal? (for/list ([n (in-range 6 11)])
                  (ev `(,(rect 0 0 0 n) row-cut 4 8)))
                '(2 3 3 3 4))
  (check-equal? (ev `(,leaf rows-from 6 4 2 4 8)) 10)
  (check-equal? (ev `(,leaf rows-from 4 2 2 1 1)) 4))

;; 3. The walk.
(test-case "the walk: a Below's boundary row, a Right's bar column, the ancestor first"
  (def! 'tb '((sb windows) tree))
  (same '(tb handle-at 0 11 root) '(Option Some tb))
  (for ([cell '((0 10) (0 12) (0 22))])
    (check-false (ev `((tb handle-at ,@cell root) present?)) (format "~s" cell)))
  (def! 'tbb '((sbb windows) tree))
  (same '(tbb handle-at 0 5 root) (some (first-child 'tbb)))
  (same '(tbb handle-at 0 11 root) '(Option Some tbb))
  (def! 'tbr '((sbr windows) tree))
  (same '(tbr handle-at 40 11 root) '(Option Some tbr))
  (same '(tbr handle-at 40 3 root) (some (first-child 'tbr)))
  (def! 'trb '((srb windows) tree))
  (same '(trb handle-at 10 11 root) (some (first-child 'trb)))
  (same '(trb handle-at 40 11 root) '(Option Some trb)))

;; 4. The event table, by whole-session equality.
(test-case "a non-label press on the boundary row arms it and changes nothing else"
  (def! 'p1 (press 'sb "mouse down left 0 11"))
  (same 'p1 'sb1)
  (drag! 'p1 1)
  (selected! 'p1 0)
  (check-equal? (echo-of 'p1) "")
  (weights! (tree-of 'p1) '(1 1))
  (for ([event '("mouse down left 40 11" "mouse down left 74 11")])
    (same (press 'sb event) 'sb1)))

(test-case "a move writes the two cell counts; the release keeps them; a resize scales them"
  (def! 't617 '(AloemacsWindowTree Below (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 6 17))
  (def! 'm3 (press 'sb1 "mouse move 0 5"))
  (same 'm3 '(sb1 with (windows ((sb1 windows) with (tree t617)))))
  (rects! 'm3 'root '((0 0 0 80 6) (1 0 6 80 17)))
  (check-true (armed? 'm3))
  (def! 'u4 (press 'm3 "mouse up left 0 5"))
  (same 'u4 '(sb with (windows ((sb windows) with (tree t617)))))
  (check-false (armed? 'u4))
  (def! 'r5 '(u4 ensure-visible 80 12))
  (rects! 'r5 '(AloemacsWindowRect new 0 0 80 11) '((0 0 0 80 3) (1 0 3 80 8)))
  (weights! (tree-of 'r5) '(6 17)))

(test-case "a move clamps to the floor; the column does not matter"
  (def! 'm6 (press 'sb1 "mouse move 0 0"))
  (same 'm6 (dragged 'sb 1 '() 2 21))
  (weights! (tree-of 'm6) '(2 21))
  (for ([event '("mouse move 0 22" "mouse move 0 100")])
    (def! 'm7 (press 'sb1 event))
    (same 'm7 (dragged 'sb 1 '() 21 2))
    (weights! (tree-of 'm7) '(21 2))
    (rects! 'm7 'root '((0 0 0 80 21) (1 0 21 80 2))))
  (def! 'm8 (press 'sb1 "mouse move 50 5"))
  (same 'm8 (dragged 'sb 1 '() 6 17))
  (weights! (tree-of 'm8) '(6 17)))

(test-case "a key disarms, then takes today's path"
  (def! 'k9 (press 'sb1 "x"))
  (same 'k9 '(sb handle-event "x"))
  (check-false (armed? 'k9)))

(test-case "the bottom mode line, the echo row, and text arm nothing"
  (for ([event '("mouse down left 0 22" "mouse down left 40 22" "mouse down left 0 23")])
    (unchanged! 'sb event))
  (def! 'p13 (press 'sb "mouse down left 0 5"))
  (same 'p13 '(sb place-at 5 0))
  (check-false (armed? 'p13))
  (def! 'p14 (press 'sb "mouse down left 1 14"))
  (selected! 'p14 1)
  (at! 'p14 '(2 1))
  (check-false (armed? 'p14)))

(test-case "a locked leaf in either child refuses the boundary row"
  (unchanged! 'ls "mouse down left 0 11")
  (unchanged! (press 'ls "mouse down left 0 11") "mouse move 0 5")
  (same (press (press 'ls "mouse down left 0 11") "mouse move 0 5") 'ls)
  (for ([event '("mouse down left 0 11" "mouse down left 40 11")])
    (unchanged! 'lb event)))

(test-case "nested Belows: the outer boundary and the inner boundary, each within its floor"
  (def! 'm17 (press (press 'sbb "mouse down left 0 11") "mouse move 0 0"))
  (same 'm17 (dragged 'sbb 1 '() 4 19))
  (weights! (tree-of 'm17) '(4 19))
  (weights! (first-child (tree-of 'm17)) '(1 1))
  (rects! 'm17 'root '((0 0 0 80 2) (2 0 2 80 2) (1 0 4 80 19)))
  (def! 'p18 (press 'sbb "mouse down left 0 5"))
  (same 'p18 (armed 'sbb 2))
  (def! 'm18 (press 'p18 "mouse move 0 1"))
  (same 'm18 (dragged 'sbb 2 '(first) 2 10))
  (weights! (first-child (tree-of 'm18)) '(2 10))
  (weights! (tree-of 'm18) '(1 1))
  (rects! 'm18 'root '((0 0 0 80 2) (2 0 2 80 10)))
  (def! 'm19 (press (press 'sbbb "mouse down left 0 11") "mouse move 0 0"))
  (same 'm19 (dragged 'sbbb 1 '() 7 16))
  (weights! (tree-of 'm19) '(7 16))
  (rects! 'm19 'root '((0 0 0 80 2) (3 0 2 80 2) (2 0 4 80 3) (1 0 7 80 16))))

(test-case "a child dragged to 4 8 needs 10 rows before its top gets 4"
  (def! 'd20 (press (press (press 'sbbb "mouse down left 0 5") "mouse move 0 3")
                    "mouse up left 0 3"))
  (same 'd20 (settled 'sbbb '(first) 4 8))
  (check-false (armed? 'd20))
  (weights! (first-child (tree-of 'd20)) '(4 8))
  (rects! 'd20 'root '((0 0 0 80 2) (3 0 2 80 2) (2 0 4 80 8)))
  (def! 'm20 (press (press 'd20 "mouse down left 0 11") "mouse move 0 0"))
  (same 'm20 (dragged 'd20 1 '() 10 13))
  (weights! (tree-of 'm20) '(10 13))
  (weights! (first-child (tree-of 'm20)) '(4 8))
  (rects! 'm20 'root '((0 0 0 80 2) (3 0 2 80 2) (2 0 4 80 6) (1 0 10 80 13))))

(test-case "a Right inside a Below: any non-label cell of the boundary row drags the Below"
  (define four '((0 0 0 40 4) (2 41 0 39 4) (1 0 4 80 19)))
  (def! 'm21 (press (press 'sbr "mouse down left 40 11") "mouse move 40 3"))
  (same 'm21 (dragged 'sbr 1 '() 4 19))
  (weights! (tree-of 'm21) '(4 19))
  (weights! (first-child (tree-of 'm21)) '(1 1))
  (rects! 'm21 'root four)
  (for ([event '("mouse down left 10 11" "mouse down left 50 11")])
    (def! 'm22 (press (press 'sbr event) "mouse move 0 3"))
    (same 'm22 (dragged 'sbr 1 '() 4 19))
    (rects! 'm22 'root four)))

(test-case "a Below inside a Right: the mode-line cell drags the Below, the bar cell the Right"
  (def! 'm23 (press (press 'srb "mouse down left 10 11") "mouse move 10 3"))
  (same 'm23 (dragged 'srb 2 '(first) 4 19))
  (weights! (first-child (tree-of 'm23)) '(4 19))
  (weights! (tree-of 'm23) '(1 1))
  (rects! 'm23 'root '((0 0 0 40 4) (2 0 4 40 19) (1 41 0 39 23)))
  (def! 'm24 (press (press 'srb "mouse down left 40 11") "mouse move 30 11"))
  (same 'm24 (dragged 'srb 1 '() 30 49))
  (weights! (tree-of 'm24) '(30 49))
  (weights! (first-child (tree-of 'm24)) '(1 1))
  (rects! 'm24 'root '((0 0 0 30 12) (2 0 12 30 11) (1 31 0 49 23))))

(test-case "40 by 10: the boundary at row 4 drags to row 2"
  (def! 'm25 (press (press 's40b "mouse down left 0 4") "mouse move 0 2"))
  (same 'm25 (dragged 's40b 1 '() 3 6))
  (weights! (tree-of 'm25) '(3 6))
  (rects! 'm25 '(AloemacsWindowRect new 0 0 40 9) '((0 0 0 40 3) (1 0 3 40 6))))

;; 5. The one-row child, and the frame holds.
(test-case "a one-row child has no mode line: its boundary row is text"
  (def! 'short '(((sb1 handle-event "mouse move 0 0") handle-event "mouse up left 0 0")
                 ensure-visible 80 4))
  (weights! (tree-of 'short) '(2 21))
  (same '(short root-rect 80 4) (rect 0 0 80 3))
  (rects! 'short '(AloemacsWindowRect new 0 0 80 3) '((0 0 0 80 1) (1 0 1 80 2)))
  (def! 'p26 (press 'short "mouse down left 0 0"))
  (same 'p26 '(short place-at 0 0))
  (check-false (armed? 'p26))
  (unchanged! 'short "mouse down left 0 2"))

(test-case "the frame of an armed session is the frame of the unarmed one"
  (check-equal? (ev '(sb1 frame 80 24)) (ev '(sb frame 80 24))))

;; 6. Labels stay commands.
(test-case "a press on a label is its command and arms nothing"
  (for ([event '("mouse down left 75 11" "mouse down left 77 11" "mouse down left 79 11")]
        [expected '((sb split-below) (sb split-right) (sb delete-window))])
    (def! 'p27 (press 'sb event))
    (same 'p27 expected)
    (check-false (armed? 'p27) event))
  (def! 'so '(sb other-window))
  (selected! 'so 1)
  (def! 'p28 (press 'so "mouse down left 75 11"))
  (same 'p28 '((so other-window) split-below))
  (check-false (armed? 'p28)))

;; 7. Runner: the scripted-term shape from mouse.rkt.
(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define size-calls (box 0))
  (define recorded '())
  (define (record! event) (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'aloemacs-mode-line-output
     always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (record! (if (= start end)
                    'flush
                    (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
       (- end start))
     void))
  (define receiver
    (make-term-receiver
     output
     (lambda ()
       (define remaining (unbox remaining-keys))
       (unless (pair? remaining) (error 'scripted-term "key script exhausted"))
       (set-box! remaining-keys (cdr remaining))
       (record! (list 'key (car remaining)))
       (car remaining))
     (lambda ()
       (define call (unbox size-calls))
       (set-box! size-calls (add1 call))
       (record! (if (even? call) '(columns 80) '(rows 24)))
       (values 80 24))))
  (values receiver remaining-keys (lambda () (reverse recorded))))

(define LIGHT "\e[38;5;16;48;5;250m")
(define DARK "\e[38;5;252;48;5;239m")

(test-case "runner: C-x 2, press the mode line, move it to row 5, release, escape"
  (define keys '("ctrl-x" "2" "mouse down left 0 11" "mouse move 0 5" "mouse up left 0 5"
                 "escape"))
  (define-values (receiver remaining events) (make-scripted-term keys))
  (run-aloemacs-with-hosts receiver (fs-double) "a.txt")
  (check-equal? (unbox remaining) '())
  (define recorded (events))
  (define frames
    (for/list ([event recorded] #:when (and (pair? event) (eq? (car event) 'write)))
      (cadr event)))
  (check-equal? (length frames) 6)
  (check-equal?
   recorded
   (append-map (lambda (frame key)
                 (list '(columns 80) '(rows 24) (list 'write frame) 'flush (list 'key key)))
               frames keys))
  (define (begins? frame index seq)
    (string-prefix? (list-ref (regexp-split #rx"\r\n" (list-ref frames frame)) index) seq))
  (check-true (begins? 2 11 LIGHT))
  (check-true (begins? 2 22 DARK))
  (check-equal? (list-ref frames 3) (list-ref frames 2))
  (check-true (begins? 4 5 LIGHT))
  (check-true (begins? 4 22 DARK))
  (check-false (begins? 4 11 LIGHT))
  (check-equal? (list-ref frames 5) (list-ref frames 4)))
