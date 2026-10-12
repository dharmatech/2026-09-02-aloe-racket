#lang racket/base

;; aloemacs-split-drag 000: a Below and a Right each remember how their space
;; is divided, two positive Int weights named earlier and later. The rectangle
;; divides by them. A split the user makes is 1 1, today's even cut at every
;; extent, so no frame changes. Nothing arms and nothing drags. No TTY is
;; opened here.

(require racket/list racket/port racket/runtime-path rackunit
         "../../aloe/driver.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")

;; The fs double of mouse.rkt.
(define (fs-double)
  (make-fs-double "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
    (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b")))

(define st (make-driver))
(driver-inject-host! st 'fs-host (fs-double))
(void (driver-load-file! st main-path))

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

;; A node's weights, read through a case with an else arm; a Leaf reads -1.
(define (earlier-of tree) `(,tree case (Right (l r e la) e) (Below (t b e la) e) (else -1)))
(define (later-of tree) `(,tree case (Right (l r e la) la) (Below (t b e la) la) (else -1)))
(define (weights tree) (list (ev (earlier-of tree)) (ev (later-of tree))))
(define (weights! tree expected)
  (check-equal? (weights tree) expected (format "~s reads ~s" tree expected)))
(define (first-child tree) `(,tree case (Below (t b e la) t) (Right (l r e la) l) (else ,tree)))
(define (kind tree)
  (ev `(,tree case (Leaf (v) "Leaf") (Below (t b e la) "Below") (Right (l r e la) "Right"))))

(define contents "hello\nworld\nxyz")

;; Fixtures. sr: view 0 selected on the left, view 1 on the right.
;; sb: view 0 selected on top, view 1 below.
(def! 's0 `((aloemacs-editor visited ,contents (Path new "/cwd/a.txt")) ensure-visible 80 24))
(def! 'sr '(s0 split-right))
(def! 'sb '(s0 split-below))
(def! 'root '(AloemacsWindowRect new 0 0 80 23))
(def! 'v0 '((((sr windows) tree) leaves) first))
(def! 'v1 '(((((sr windows) tree) leaves) rest) first))
(def! 'b0 '((((sb windows) tree) leaves) first))
(def! 'b1 '(((((sb windows) tree) leaves) rest) first))

;; 1. Types and arities.
(test-case "types: weights, cut, row-cut, column-cut, the four rectangles, no earlier"
  (def! 'a '(AloemacsWindowTree Leaf v0))
  (def! 'b '(AloemacsWindowTree Leaf v1))
  (check-equal? (dtype '(AloemacsWindowTree Below a b 1 1)) 'AloemacsWindowTree)
  (check-equal? (dtype '(AloemacsWindowTree Right a b 1 1)) 'AloemacsWindowTree)
  (rejects '(AloemacsWindowTree Below a b))
  (rejects '(AloemacsWindowTree Below a b 1))
  (rejects '(AloemacsWindowTree Below a b 1 1 1))
  (rejects '(AloemacsWindowTree Right a b "1" 1))
  (check-equal? (dtype '(root cut 1 2 3 4)) 'Int)
  (rejects '(root cut 1 2 3))
  (rejects '(root cut 1 2 3 4 5))
  (check-equal? (dtype '(root row-cut 1 1)) 'Int)
  (check-equal? (dtype '(root column-cut 1 1)) 'Int)
  (rejects '(root row-cut 1))
  (for ([selector '(top bottom left right)])
    (check-equal? (dtype `(root ,selector 1 1)) 'AloemacsWindowRect)
    (rejects `(root ,selector))
    (rejects `(root ,selector 1))
    (rejects `(root ,selector 1 1 1)))
  (rejects '(root earlier 5))
  ;; Read as data: the payloads, the rect and configuration fields, and the
  ;; ordered define-class list windows-state.rkt pins.
  (define source (call-with-input-file file-path (lambda (in) (port->list read in))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) source))
  (define (decl name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (check-equal? (caddr (decl 'AloemacsWindowTree))
    '(constructors
       (Leaf (fields (view AloemacsView)))
       (Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree) (earlier Int) (later Int)))
       (Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree) (earlier Int) (later Int)))))
  (check-equal? (caddr (decl 'AloemacsWindowRect))
    '(fields (x Int) (y Int) (columns Int) (rows Int)))
  (check-equal? (caddr (decl 'AloemacsWindows))
    '(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int) (drag (Option Int))))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B)
      AloemacsBinding AloemacsSearchScan AloemacsMouse (AloemacsSession H))))

;; 2. The cut. Each row is extent, least, earlier, later, cut.
(define cut-table
  '((23 2 1 1 12) (23 2 6 17 6) (11 2 6 17 3) (5 2 6 17 2) (4 2 6 17 2) (3 2 6 17 1)
    (2 2 6 17 1) (3 2 1 1 2) (3 2 22 1 2) (3 2 1 22 1) (1 2 1 1 1)
    (79 1 1 1 40) (79 1 30 49 30) (119 1 30 49 46) (2 1 30 49 1) (1 1 30 49 1) (0 1 1 1 0)))

(test-case "cut: the pinned table, row-cut and column-cut, and today's even cut"
  (def! 'probe '(AloemacsWindowRect new 0 0 0 0))
  (for ([row cut-table])
    (check-equal? (ev `(probe cut ,@(take row 4))) (list-ref row 4) (format "cut ~s" row)))
  (for ([w '((1 1) (6 17) (30 49))] [rows '(12 6 9)] [columns '(40 21 30)])
    (check-equal? (ev `(root row-cut ,@w)) rows (format "row-cut ~s" w))
    (check-equal? (ev `(root column-cut ,@w)) columns (format "column-cut ~s" w)))
  (for ([n (in-range 31)])
    (check-equal? (ev `((AloemacsWindowRect new 0 0 0 ,n) row-cut 1 1))
                  (quotient (+ n 1) 2) (format "row-cut 1 1 at ~a" n))
    (check-equal? (ev `((AloemacsWindowRect new 0 0 ,n 0) column-cut 1 1))
                  (quotient (+ (- n (min 1 n)) 1) 2) (format "column-cut 1 1 at ~a" n))))

;; 3. The four rectangles.
(test-case "top, bottom, left, right: unequal and equal weights, and the window-bars tables"
  (same '(root top 6 17) (rect 0 0 80 6))
  (same '(root bottom 6 17) (rect 0 6 80 17))
  (same '(root left 30 49) (rect 0 0 30 23))
  (same '(root right 30 49) (rect 31 0 49 23))
  (same '(root top 1 1) (rect 0 0 80 12))
  (same '(root bottom 1 1) (rect 0 12 80 11))
  (same '(root left 1 1) (rect 0 0 40 23))
  (same '(root right 1 1) (rect 41 0 39 23))
  (for ([n (in-range 10)]
        [top '(0 1 1 2 2 3 3 4 4 5)]
        [bottom '(0 0 1 1 2 2 3 3 4 4)])
    (same `(,(rect 2 3 7 n) top 1 1) (rect 2 3 7 top))
    (same `(,(rect 2 3 7 n) bottom 1 1) (rect 2 (+ 3 top) 7 bottom)))
  (for ([n (in-range 10)]
        [left '(0 0 1 1 2 2 3 3 4 4)]
        [later '(0 0 0 1 1 2 2 3 3 4)]
        [offset '(0 1 2 2 3 3 4 4 5 5)])
    (same `(,(rect 2 3 n 4) left 1 1) (rect 2 3 left 4))
    (same `(,(rect 2 3 n 4) right 1 1) (rect (+ 2 offset) 3 later 4))))

;; 4. A split writes 1 1.
(test-case "a split writes 1 1, and a nested split writes 1 1 under a parent that keeps 1 1"
  (same '((sr windows) tree)
        '(AloemacsWindowTree Right (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 1 1))
  (same '((sb windows) tree)
        '(AloemacsWindowTree Below (AloemacsWindowTree Leaf b0) (AloemacsWindowTree Leaf b1) 1 1))
  (weights! '((sb windows) tree) '(1 1))
  (def! 'sbr '(sb split-right))
  (weights! '((sbr windows) tree) '(1 1))
  (check-equal? (kind (first-child '((sbr windows) tree))) "Right")
  (weights! (first-child '((sbr windows) tree)) '(1 1)))

;; 5. An unequal tree lays out. ur and ub replace the trees of sr and sb.
(def! 'ur '(sr with (windows ((sr windows) with
  (tree (AloemacsWindowTree Right (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 30 49))))))
(def! 'ub '(sb with (windows ((sb windows) with
  (tree (AloemacsWindowTree Below (AloemacsWindowTree Leaf b0) (AloemacsWindowTree Leaf b1) 6 17))))))

(test-case "an unequal Right lays out, a resize scales it, and the fallback is today's"
  (def! 'urt '((ur windows) tree))
  (same '(urt rect-for 0 root) (some (rect 0 0 30 23)))
  (same '(urt rect-for 1 root) (some (rect 31 0 49 23)))
  (same '(urt view-at 30 5 root) '(if #t (Option None) (Option Some v1)))
  (same '(urt view-at 31 5 root) '(Option Some v1))
  (check-true (ev '(urt positive-layout? root)))
  (def! 'ur120 '(ur ensure-visible 120 24))
  (def! 'root120 '(AloemacsWindowRect new 0 0 120 23))
  (same '(((ur120 windows) tree) rect-for 0 root120) (some (rect 0 0 46 23)))
  (same '(((ur120 windows) tree) rect-for 1 root120) (some (rect 47 0 73 23)))
  (check-equal? (ev '((ur120 windows) columns)) 120)
  (weights! '((ur120 windows) tree) '(30 49))
  (def! 'root3 '(AloemacsWindowRect new 0 0 3 23))
  (same '(urt rect-for 0 root3) (some (rect 0 0 1 23)))
  (same '(urt rect-for 1 root3) (some (rect 2 0 1 23)))
  (def! 'root2 '(AloemacsWindowRect new 0 0 2 23))
  (same '(urt rect-for 0 root2) (some (rect 0 0 1 23)))
  (same '(urt rect-for 1 root2) (some (rect 2 0 0 23)))
  (check-false (ev '(urt positive-layout? root2)))
  (def! 'ur2 '(ur ensure-visible 2 24))
  (check-true (ev '((ur2 fit-rect 2 24) same? (ur2 root-rect 2 24))))
  (check-equal? (ev '(ur2 frame 2 24)) (ev '((s0 ensure-visible 2 24) frame 2 24))))

(test-case "an unequal Below lays out at every listed height and keeps 6 17 through a resize"
  (def! 'ubt '((ub windows) tree))
  (for ([rows '(23 11 5 4 3 2 1)]
        [top '((0 0 80 6) (0 0 80 3) (0 0 80 2) (0 0 80 2) (0 0 80 1) (0 0 80 1) (0 0 80 1))]
        [bottom '((0 6 80 17) (0 3 80 8) (0 2 80 3) (0 2 80 2) (0 1 80 2) (0 1 80 1) (0 1 80 0))])
    (same `(ubt rect-for 0 ,(rect 0 0 80 rows)) (some (apply rect top)))
    (same `(ubt rect-for 1 ,(rect 0 0 80 rows)) (some (apply rect bottom))))
  (weights! '(((ub ensure-visible 80 12) windows) tree) '(6 17)))

;; 6. An unequal frame composes. A second driver with two eight-letter files.
(test-case "an unequal Right composes its rows: ab|ABCDEF, and abcd|ABCD with 1 1"
  (define st2 (make-driver))
  (driver-inject-host! st2 'fs-host
    (make-fs-double "/cwd"
      (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
      (hash "/cwd/a.txt" "abcdefgh" "/cwd/b.txt" "ABCDEFGH")))
  (void (driver-load-file! st2 main-path))
  (define (ev2 expr) (driver-eval! st2 expr))
  ;; View 0 selected on a.txt, view 1 on b.txt.
  (ev2 '(define t2 ((((((aloemacs-editor visited "abcdefgh" (Path new "/cwd/a.txt"))
                      ensure-visible 9 6) split-right) other-window)
                    find-file-submitted "b.txt") other-window)))
  (ev2 '(define w0 ((((t2 windows) tree) leaves) first)))
  (ev2 '(define w1 (((((t2 windows) tree) leaves) rest) first)))
  (ev2 '(define tw (t2 with (windows ((t2 windows) with
    (tree (AloemacsWindowTree Right (AloemacsWindowTree Leaf w0) (AloemacsWindowTree Leaf w1) 2 6)))))))
  (check-equal? (ev2 '((((tw windows) tree) frame-rows (tw buffers) (AloemacsWindowRect new 0 0 9 5) 0) first))
                "ab|ABCDEF")
  (check-equal? (ev2 '((((t2 windows) tree) frame-rows (t2 buffers) (AloemacsWindowRect new 0 0 9 5) 0) first))
                "abcd|ABCD")
  (check-equal? (ev2 '((((tw windows) tree) frame-rows (tw buffers) (AloemacsWindowRect new 0 0 9 5) 0)
                       fold 0 (fn (n row) (n + 1))))
                5))

;; 7. Preservation. pt is Below (Right (Leaf 0, Leaf 2) 30 49, Leaf 1) 6 17.
(test-case "every tree rewrite and every session send keeps the weights; delete promotes with its own"
  (def! 'sbr7 '(sb split-right))
  (def! 'pt '(((sbr7 windows) tree) case
               (Below (t b e la)
                 (AloemacsWindowTree Below
                   (t case (Right (l r e2 la2) (AloemacsWindowTree Right l r 30 49)) (else t))
                   b 6 17))
               (else ((sbr7 windows) tree))))
  (def! 'ps '(sbr7 with (windows ((sbr7 windows) with (tree pt)))))
  (def! 'bid '((ps current-buffer) id))
  (weights! 'pt '(6 17))
  (weights! (first-child 'pt) '(30 49))
  (check-equal? (ev '((ps windows) selected)) 0)
  (for ([send '((pt with-toggled-lock 2) (pt without-pictures) (pt without-pictures-of bid)
                (pt with-view-buffer 0 (ps current-buffer))
                (pt retarget-buffer bid 99 0 0 (Position new 0 0))
                (pt with-pictures (ps buffers) root 0))])
    (weights! send '(6 17))
    (weights! (first-child send) '(30 49)))
  (def! 'split7 '(pt with-split 0 3 0 0 (Position new 0 0) #t))
  (weights! 'split7 '(6 17))
  (weights! (first-child 'split7) '(30 49))
  (check-equal? (kind (first-child (first-child 'split7))) "Below")
  (weights! (first-child (first-child 'split7)) '(1 1))
  (def! 'no1 '(pt without-view 1))
  (check-equal? (kind 'no1) "Right")
  (weights! 'no1 '(30 49))
  (def! 'no2 '(pt without-view 2))
  (check-equal? (kind 'no2) "Below")
  (weights! 'no2 '(6 17))
  (for ([send '((ps split-below) (ps split-right) (ps other-window) (ps toggle-window-lock)
                (ps ensure-visible 120 30) (ps record-pictures 80 24)
                (ps find-file-submitted "b.txt") (ps handle-event "x"))])
    (define tree `((,send windows) tree))
    (weights! tree '(6 17))
    (weights! (first-child tree) '(30 49)))
  (def! 'deleted '(ps delete-window))
  (check-equal? (kind '((deleted windows) tree)) "Below")
  (weights! '((deleted windows) tree) '(6 17))
  (check-equal? (kind (first-child '((deleted windows) tree))) "Leaf")
  (same '((((deleted windows) tree) leaves) map (fn (view) (view id))) '(List of 2 1)))

;; 8. Today's frames, captured through the driver on the tree before this
;; checkpoint. ESC is \e; the bar colors are spelled as mode-line-one-view.rkt
;; spells them.
(define LIGHT "\e[38;5;16;48;5;250m")
(define DARK "\e[38;5;252;48;5;239m")
(define PLAIN "\e[0m")

(define frame-right
  (string-append
   "\e[?25l\e[2J\e[Hhello                                   |hello                                  \r\nworld                                   |world                                  \r\nxyz                                     |xyz                                    \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n"
   LIGHT
   "/cwd/a.txt ----------------------- ↕ ↔ ×"
   PLAIN
   "|"
   DARK
   "/cwd/a.txt ---------------------- ↕ ↔ ×"
   PLAIN
   "\e[24;1H\e[1;1H\e[?25h"
   ))

(define frame-below
  (string-append
   "\e[?25l\e[2J\e[Hhello                                                                           \r\nworld                                                                           \r\nxyz                                                                             \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n"
   LIGHT
   "/cwd/a.txt --------------------------------------------------------------- ↕ ↔ ×"
   PLAIN
   "\r\nhello                                                                           \r\nworld                                                                           \r\nxyz                                                                             \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n"
   DARK
   "/cwd/a.txt --------------------------------------------------------------- ↕ ↔ ×"
   PLAIN
   "\e[24;1H\e[1;1H\e[?25h"
   ))

(define frame-both
  (string-append
   "\e[?25l\e[2J\e[Hhello                                   |hello                                  \r\nworld                                   |world                                  \r\nxyz                                     |xyz                                    \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n                                        |                                       \r\n"
   LIGHT
   "/cwd/a.txt ----------------------- ↕ ↔ ×"
   PLAIN
   "|"
   DARK
   "/cwd/a.txt ---------------------- ↕ ↔ ×"
   PLAIN
   "\r\nhello                                                                           \r\nworld                                                                           \r\nxyz                                                                             \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n                                                                                \r\n"
   DARK
   "/cwd/a.txt --------------------------------------------------------------- ↕ ↔ ×"
   PLAIN
   "\e[24;1H\e[1;1H\e[?25h"
   ))

(define frame-small
  (string-append
   "\e[?25l\e[2J\e[Hhello                                   \r\nworld                                   \r\nxyz                                     \r\n                                        \r\n"
   LIGHT
   "/cwd/a.txt ----------------------- ↕ ↔ ×"
   PLAIN
   "\r\nhello                                   \r\nworld                                   \r\nxyz                                     \r\n"
   DARK
   "/cwd/a.txt ----------------------- ↕ ↔ ×"
   PLAIN
   "\e[10;1H\e[1;1H\e[?25h"
   ))

(test-case "today's frames: four split frames are byte for byte the frames before this checkpoint"
  (for ([frame (list frame-right frame-below frame-both frame-small)]
        [chars '(1963 1963 1987 455)]
        [lines '(23 23 23 9)])
    (check-equal? (string-length frame) chars)
    (check-equal? (length (regexp-split #rx"\r\n" frame)) lines))
  (check-equal? (ev '((s0 split-right) frame 80 24)) frame-right)
  (check-equal? (ev '((s0 split-below) frame 80 24)) frame-below)
  (check-equal? (ev '(((s0 split-below) split-right) frame 80 24)) frame-both)
  (check-equal? (ev '(((s0 ensure-visible 40 10) split-below) frame 40 10)) frame-small))

;; 9. Pictures.
(test-case "recording pictures on an unequal tree paints the same bytes and keeps 30 49"
  (define f1 (ev '(ur frame 80 24)))
  (def! 'rec1 '(ur record-pictures 80 24))
  (check-equal? (ev '(rec1 frame 80 24)) f1)
  (def! 'rec2 '(rec1 record-pictures 80 24))
  (check-equal? (ev '(rec2 frame 80 24)) f1)
  (weights! '((rec2 windows) tree) '(30 49)))

;; 10. A mode-line press does not arm yet. 003 replaces this item.
(test-case "a non-label mode-line press returns the receiver"
  (same '(sb handle-event "mouse down left 0 11") 'sb))
