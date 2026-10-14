#lang racket/base

;; aloemacs-split-drag 002: a left press on a vertical bar arms that Right. A
;; move while armed puts the bar at the pointer column, within the structural
;; floor, and rewrites that split's weights. The left release ends the drag.
;; The mode line stays inert until 003. No TTY is opened here.

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
(define (text-of s) (ev `((,s text) to-string)))
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

;; Each row is id x y columns rows, read through rect-for on r.
(define (rects! s r rows)
  (for ([row rows])
    (same `(,(tree-of s) rect-for ,(car row) ,r) (some (apply rect (cdr row))))))

(define contents "hello\nworld\nxyz")

;; Fixtures. Every weight is 1 1 before a drag.
(def! 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt")) ensure-visible 80 24))
(define session-type (dtype 's0))
(def! 'sr '(s0 split-right))
(def! 'srr '(sr split-right))
(def! 'srrr '(srr split-right))
(def! 'sbr '((s0 split-below) split-right))
(def! 'lr '(((sr other-window) toggle-window-lock) other-window))
(def! 'lb '((((sbr other-window) other-window) toggle-window-lock) other-window))
(def! 's40r '((s0 ensure-visible 40 10) split-right))
(def! 'e17 '(((s0 handle-key "ctrl-x") handle-key "find") handle-key "tab"))
(def! 'root '(AloemacsWindowRect new 0 0 80 23))
(def! 'v0 '((((sr windows) tree) leaves) first))
(def! 'v1 '(((((sr windows) tree) leaves) rest) first))
(def! 'sr1 (armed 'sr 1))

;; 1. Types and arities.
(test-case "types: the tree sends, press-handle, drag-to, the handlers, the declarations"
  (def! 't '((sr windows) tree))
  (for ([selector '(first-id handle-id min-columns)])
    (check-equal? (dtype `(t ,selector)) 'Int)
    (rejects `(t ,selector 1)))
  (check-equal? (dtype '(t columns-from 1 2 3 4 5)) 'Int)
  (rejects '(t columns-from 1 2 3 4))
  (rejects '(t columns-from 1 2 3 4 5 6))
  (check-equal? (dtype '(t handle-at 0 0 root)) '(Option AloemacsWindowTree))
  (rejects '(t handle-at 0 0))
  (rejects '(t handle-at 0 0 root root))
  (check-equal? (dtype '(t with-cut-at 0 0 0 root)) 'AloemacsWindowTree)
  (rejects '(t with-cut-at 0 0 root))
  (rejects '(t with-cut-at 0 0 0 root root))
  (for ([selector '(press-handle drag-to)])
    (check-equal? (dtype `(sr ,selector 0 0)) session-type)
    (rejects `(sr ,selector 0))
    (rejects `(sr ,selector 0 0 0))
    (rejects `(sr ,selector 0 "0")))
  (check-equal? (dtype '(sr press-at 0 0)) session-type)
  (check-equal? (dtype '(sr press-mode-line v0 root 0)) session-type)
  (check-equal? (dtype '(sr handle-event "x")) session-type)
  (check-equal? (dtype '(sr handle-mouse "x")) session-type)
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

;; 2. Ids.
(test-case "ids: a split is named by the first leaf of its later child"
  (def! 'trrr '((srrr windows) tree))
  (check-equal? (map kind (list 'trrr (first-child 'trrr) (first-child (first-child 'trrr))))
                '("Right" "Right" "Right"))
  (check-equal? (ev '(trrr first-id)) 0)
  (check-equal? (ev '(trrr handle-id)) 1)
  (check-equal? (ev `(,(first-child 'trrr) handle-id)) 2)
  (check-equal? (ev `(,(first-child (first-child 'trrr)) handle-id)) 3)
  (def! 'tbr '((sbr windows) tree))
  (check-equal? (kind 'tbr) "Below")
  (check-equal? (ev '(tbr handle-id)) 1)
  (check-equal? (ev `(,(first-child 'tbr) handle-id)) 2))

;; 3. The floor, on trees built with raw constructors.
(define leaf '(AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 (Position new 0 0) #f (Option None))))
(define (R a b [earlier 1] [later 1]) `(AloemacsWindowTree Right ,a ,b ,earlier ,later))
(define (B a b [earlier 1] [later 1]) `(AloemacsWindowTree Below ,a ,b ,earlier ,later))

(test-case "the floor: min-columns counts every leaf, each child divided by its own weights"
  (for ([row (list (list leaf 1)
                   (list (B leaf leaf) 1)
                   (list (R leaf leaf) 3)
                   (list (R leaf leaf 1 78) 3)
                   (list (R leaf leaf 78 1) 3)
                   (list (B (R leaf leaf) leaf) 3)
                   (list (R (B leaf leaf) leaf) 3)
                   (list (B (B leaf leaf) leaf) 1)
                   (list (B (B leaf leaf) leaf 4 8) 1)
                   (list (R (R leaf leaf) leaf) 6)
                   (list (B (B (B leaf leaf) leaf) leaf) 1)
                   (list (R (R (R leaf leaf) leaf) leaf) 12))])
    (check-equal? (ev `(,(car row) min-columns)) (cadr row) (format "~s" (car row))))
  ;; The sum is where the search starts: 5 columns cut 2 and 2.
  (check-equal? (ev `(,leaf columns-from 5 3 1 1 1)) 6)
  (check-equal? (ev `(,leaf columns-from 3 1 1 1 1)) 3))

;; 4. The walk.
(test-case "the walk: a Right's bar column, the ancestor first"
  (def! 'tr '((sr windows) tree))
  (same '(tr handle-at 40 5 root) '(Option Some tr))
  (for ([cell '((39 5) (41 5) (40 23))])
    (check-false (ev `((tr handle-at ,@cell root) present?)) (format "~s" cell)))
  (def! 'trr '((srr windows) tree))
  (same '(trr handle-at 20 0 root) (some (first-child 'trr)))
  (same '(trr handle-at 40 0 root) '(Option Some trr))
  (def! 'tbr '((sbr windows) tree))
  (same '(tbr handle-at 40 3 root) (some (first-child 'tbr)))
  (same '(tbr handle-at 0 11 root) '(Option Some tbr)))

;; 5. The event table, by whole-session equality.
(test-case "a left press on the bar arms it and changes nothing else"
  (def! 'p1 (press 'sr "mouse down left 40 5"))
  (same 'p1 'sr1)
  (selected! 'p1 0)
  (check-equal? (echo-of 'p1) "")
  (weights! (tree-of 'p1) '(1 1))
  (drag! 'p1 1)
  (for ([event '("mouse down left 40 0" "mouse down left 40 22")])
    (same (press 'sr event) 'sr1)))

(test-case "a move writes the two cell counts; the release keeps them; a resize scales them"
  (def! 't3049 '(AloemacsWindowTree Right (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 30 49))
  (def! 'm3 (press 'sr1 "mouse move 30 5"))
  (same 'm3 '(sr1 with (windows ((sr1 windows) with (tree t3049)))))
  (rects! 'm3 'root '((0 0 0 30 23) (1 31 0 49 23)))
  (check-true (armed? 'm3))
  (def! 'u4 (press 'm3 "mouse up left 30 5"))
  (same 'u4 '(sr with (windows ((sr windows) with (tree t3049)))))
  (check-false (armed? 'u4))
  (def! 'r5 '(u4 ensure-visible 120 24))
  (rects! 'r5 '(AloemacsWindowRect new 0 0 120 23) '((0 0 0 46 23) (1 47 0 73 23)))
  (weights! (tree-of 'r5) '(30 49)))

(test-case "a move clamps to the floor; the row does not matter"
  (same (press (press 'sr1 "mouse move 30 5") "mouse move 50 5") (dragged 'sr 1 '() 50 29))
  (same (press 'sr1 "mouse move 0 5") (dragged 'sr 1 '() 1 78))
  (for ([event '("mouse move 79 5" "mouse move 200 5")])
    (same (press 'sr1 event) (dragged 'sr 1 '() 78 1)))
  (same (press 'sr1 "mouse move 40 100") (dragged 'sr 1 '() 40 39))
  (weights! (tree-of (press 'sr1 "mouse move 0 5")) '(1 78)))

(test-case "a resize between events keeps the armed id; the next move uses the new geometry"
  (def! 'r10 '(sr1 ensure-visible 120 24))
  (drag! 'r10 1)
  (def! 'm10 (press 'r10 "mouse move 60 5"))
  (same 'm10 (dragged 'r10 1 '() 60 59))
  (weights! (tree-of 'm10) '(60 59)))

(test-case "a key, a release, another button, and a press elsewhere disarm"
  (def! 'k11 (press 'sr1 "x"))
  (same 'k11 '(sr handle-event "x"))
  (check-false (armed? 'k11))
  (check-equal? (text-of 'k11) "xhello\nworld\nxyz")
  (same (press 'sr1 "mouse up left 40 5") 'sr)
  (for ([event '("mouse down middle 40 5" "mouse up right 0 0")])
    (same (press 'sr1 event) 'sr))
  (def! 'p14 (press 'sr1 "mouse down left 50 0"))
  (same 'p14 '(sr handle-event "mouse down left 50 0"))
  (selected! 'p14 1)
  (at! 'p14 '(0 5))
  (check-false (armed? 'p14))
  (same (press 'sr1 "mouse down left 40 5") 'sr1))

(test-case "a search and a quit disarm, and a following move leaves them"
  (def! 'f16 (press 'sr1 "find"))
  (same 'f16 '(sr handle-key "find"))
  (check-true (ev '(f16 searching)))
  (check-false (armed? 'f16))
  (unchanged! 'f16 "mouse move 30 5")
  (def! 'q17 (press 'sr1 "escape"))
  (same 'q17 '(sr handle-key "escape"))
  (check-true (ev '(q17 quit)))
  (check-false (armed? 'q17))
  (unchanged! 'q17 "mouse move 30 5"))

(test-case "unarmed: a move leaves the session; a text press is today's; a lock refuses"
  (unchanged! 'sr "mouse move 30 5")
  (def! 'p19 (press 's0 "mouse down left 40 5"))
  (same 'p19 '(s0 place-at 5 40))
  (at! 'p19 '(2 3))
  (check-false (armed? 'p19))
  (unchanged! 'p19 "mouse move 30 5")
  (check-true (locked? 'lr 1))
  (selected! 'lr 0)
  (unchanged! 'lr "mouse down left 40 5")
  (unchanged! (press 'lr "mouse down left 40 5") "mouse move 30 5")
  (same (press (press 'lr "mouse down left 40 5") "mouse move 30 5") 'lr))

(test-case "nested Rights: the inner bar and the outer bar, each within its floor"
  (def! 'p21 (press 'srr "mouse down left 20 0"))
  (same 'p21 (armed 'srr 2))
  (def! 'm22 (press 'p21 "mouse move 10 0"))
  (same 'm22 (dragged 'srr 2 '(first) 10 29))
  (weights! (first-child (tree-of 'm22)) '(10 29))
  (weights! (tree-of 'm22) '(1 1))
  (rects! 'm22 'root '((0 0 0 10 23) (2 11 0 29 23) (1 41 0 39 23)))
  (def! 'm23 (press (press 'srr "mouse down left 40 0") "mouse move 0 0"))
  (same 'm23 (dragged 'srr 1 '() 3 76))
  (weights! (tree-of 'm23) '(3 76))
  (weights! (first-child (tree-of 'm23)) '(1 1))
  (rects! 'm23 'root '((0 0 0 1 23) (2 2 0 1 23) (1 4 0 76 23)))
  (def! 'm24 (press (press 'srrr "mouse down left 40 0") "mouse move 0 0"))
  (same 'm24 (dragged 'srrr 1 '() 6 73))
  (weights! (tree-of 'm24) '(6 73))
  (rects! 'm24 'root '((0 0 0 1 23) (3 2 0 1 23) (2 4 0 2 23) (1 7 0 73 23))))

(test-case "a Right inside a Below; a lock elsewhere does not refuse"
  (def! 'm25 (press (press 'sbr "mouse down left 40 3") "mouse move 30 3"))
  (same 'm25 (dragged 'sbr 2 '(first) 30 49))
  (weights! (first-child (tree-of 'm25)) '(30 49))
  (weights! (tree-of 'm25) '(1 1))
  (define three '((0 0 0 30 12) (2 31 0 49 12) (1 0 12 80 11)))
  (rects! 'm25 'root three)
  (check-true (locked? 'lb 1))
  (selected! 'lb 0)
  (def! 'm26 (press (press 'lb "mouse down left 40 3") "mouse move 30 3"))
  (same 'm26 (dragged 'lb 2 '(first) 30 49))
  (rects! 'm26 'root three)
  (check-true (locked? 'm26 1)))

(test-case "40 by 10: the bar at 20 drags to 10"
  (def! 'm27 (press (press 's40r "mouse down left 20 2") "mouse move 10 2"))
  (same 'm27 (dragged 's40r 1 '() 10 29))
  (weights! (tree-of 'm27) '(10 29))
  (rects! 'm27 '(AloemacsWindowRect new 0 0 40 9) '((0 0 0 10 9) (1 11 0 29 9))))

(test-case "a prompt and a pending prefix refuse the bar"
  (check-true (ev '((e17 prompt) present?)))
  (unchanged! 'e17 "mouse down left 40 0")
  (def! 'x29 '(sr handle-key "ctrl-x"))
  (check-true (ev '((x29 pending) present?)))
  (unchanged! 'x29 "mouse down left 40 5"))

;; 6. The frame holds.
(test-case "the frame of an armed session is the frame of the unarmed one"
  (check-equal? (ev '(sr1 frame 80 24)) (ev '(sr frame 80 24))))

;; 7. Runner: the scripted-term shape from mouse.rkt.
(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define size-calls (box 0))
  (define recorded '())
  (define (record! event) (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'aloemacs-bar-output
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

(define (frame-tail frame)
  (define m (regexp-match #px"(\e\\[[0-9]+;[0-9]+H\e\\[\\?25h)$" frame))
  (and m (cadr m)))

(test-case "runner: C-x 3, press the bar, move it to 30, release, escape"
  (define keys '("ctrl-x" "3" "mouse down left 40 0" "mouse move 30 0" "mouse up left 30 0"
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
  (define bar-at-40 (string-append "hello" (make-string 35 #\space) "|"))
  (define bar-at-30 (string-append "hello" (make-string 25 #\space) "|"))
  (check-true (string-contains? (list-ref frames 2) bar-at-40))
  (check-equal? (list-ref frames 3) (list-ref frames 2))
  (check-true (string-contains? (list-ref frames 4) bar-at-30))
  (check-false (string-contains? (list-ref frames 4) bar-at-40))
  (check-equal? (list-ref frames 5) (list-ref frames 4))
  (for ([frame frames])
    (check-equal? (frame-tail frame) "\e[1;1H\e[?25h")))
