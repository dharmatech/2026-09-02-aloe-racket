#lang racket/base

;; aloemacs-frame-time 001: Text.lines-from equals focus-at then next-lines
;; on every small text, focus, top, and count (spec section 6.1), and
;; recorded four-window frames equal the unrecorded ones at five steps deep
;; in the long fixture (spec section 9.2).

(require racket/list racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path text-path "../../lib/text.aloe")
(define-runtime-path fs-path "../../lib/fs.aloe")

;; The long fixture (spec section 8.1), the short fixture's rule at 2,400
;; lines: line n is n, one space, then x up to 35 characters; when n mod 7
;; is 3, the character at index 10 is a tab.
(define (fixture-line n)
  (define head (format "~a " n))
  (define line (string-append head (make-string (- 35 (string-length head)) #\x)))
  (if (= (modulo n 7) 3)
      (string-append (substring line 0 10) "\t" (substring line 11))
      line))
(define long-fixture
  (string-join (for/list ([n (in-range 2400)]) (fixture-line n)) "\n"))
(check-equal? (length (string-split long-fixture "\n" #:trim? #f)) 2400)
(check-equal? (for/sum ([c (in-string long-fixture)]) (if (char=? c #\tab) 1 0)) 343)

(define st (make-driver))
(driver-inject-host!
 st 'fs-host
 (make-fs-double "/cwd"
   (hash "/cwd" 'directory "/cwd/long.txt" 'file)
   (hash "/cwd/long.txt" long-fixture)))
(void (driver-load-file! st main-path))
(driver-eval! st `(load ,(path->string file-path)))
(driver-eval! st `(load ,(path->string editor-path)))
(driver-eval! st `(load ,(path->string text-path)))
(driver-eval! st `(load ,(path->string fs-path)))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))
(define (checked-type datum)
  (type->datum (type-of (parse-datum datum) (driver-type-environment st))))

;; 1. The contract of spec section 6.1, exhaustively on small texts.

;; lines-from takes two Ints and answers an Option of a List of Strings.
(check-equal? (checked-type '((Text from-string "ab\nc") lines-from 1 2))
              '(Option (List String)))
(check-exn exn:fail:aloe-type?
           (lambda () (checked-type '((Text from-string "ab\nc") lines-from "1" 2))))
(check-exn exn:fail:aloe-type?
           (lambda () (checked-type '((Text from-string "ab\nc") lines-from 1 "2"))))

;; The indexed text focused at line; a None arm yields a text no source here
;; equals, so the pins below fail, as next-lines.rkt's focused helper does.
(define (focused source line)
  `((((Text from-string ,source) indexed-value) focus-at ,line) case
     (None () (Text from-string "unexpected None"))
     (Some (text) text)))

;; For each text t, top, and count, (t lines-from top count) equals focus-at
;; then next-lines, under Aloe's check.
(define (contract text top count)
  `(check (,text lines-from ,top ,count)
          ((,text focus-at ,top) case
            (None () (Option None))
            (Some (at) (Option Some (at next-lines ,count))))))

(define sources '("" "a" "a\n\nc" "0\n1\n2\n3\n4\n" "\n\n"))
(define line-counts '(1 1 3 6 3))
(define contract-checks
  (for/sum ([source sources] [expected-lines line-counts])
    (define n (ev `(((Text from-string ,source) lines) len)))
    (check-equal? n expected-lines (format "lines of ~s" source))
    ;; #f stands for the from-string text; an Int is the focus of an indexed one.
    (for*/sum ([focus (cons #f (range n))]
               [text (list (if focus (focused source focus) `(Text from-string ,source)))]
               [top (in-range -1 (+ n 2))]
               [count (in-range -1 (+ n 3))])
      (when (and focus (= top -1) (= count -1))
        (check-equal? (ev `(,text to-string)) source
                      (format "~s focused at ~a keeps its source" source focus))
        (check-equal? (ev `(,text focus-line)) focus
                      (format "~s focused at ~a" source focus)))
      (check-not-exn (lambda () (ev (contract text top count)))
                     (format "lines-from on ~s, focus ~a, top ~a, count ~a"
                             source (or focus "from-string") top count))
      1)))
(check-equal? contract-checks 1046)
(printf "lines-from contract: ~a checks\n" contract-checks)

;; 2. Recorded equals unrecorded on the long fixture: four windows, widest
;; leaf, five steps, as frame-time-cells.rkt's item 5 on the short one.
(define (visit! name path)
  (def! name `((aloemacs-editor visit (Path new ,path)) case
                (None () aloemacs-editor)
                (Some (session) session)))
  (check-equal? (ev `((,name path) present?)) #t (format "visited ~a" path)))
(define (fit s) `(,s ensure-visible 220 54))
(define (record s) `(,s record-pictures 220 54))
(define (frame s) (ev `(,s frame 220 54)))
(define (point-line s) (ev `((,s point) line)))
(define (leaf-count s) (ev `((((,s windows) tree) leaves) len)))
(define (selected-columns s) (ev `((,s fit-rect 220 54) columns)))
(define (picture-count s)
  (ev `((((,s windows) tree) leaves) fold 0
         (fn (count view) (if ((view picture) present?) (count + 1) count)))))

(visit! 'four "/cwd/long.txt")
(def! 'four (fit 'four))
(for ([n '(2 3 4)])
  (def! 'four '(four split-right))
  (unless (and (= (leaf-count 'four) n) (not (equal? (ev '(four echo)) "failed")))
    (error 'frame-time-lines "split-right ~a was refused" (sub1 n))))
(let loop ([sends 0])
  (unless (= (selected-columns 'four) 109)
    (when (= sends 4) (error 'frame-time-lines "no 109-column leaf in four sends"))
    (def! 'four '(four other-window))
    (loop (add1 sends))))
;; plain is never recorded; recorded records after every step, so its
;; pictures carry from step to step as the runner's do.
(def! 'plain 'four)
(def! 'recorded (record 'four))
(check-equal? (picture-count 'recorded) 4)
(define (same-frames! step)
  (check-equal? (frame 'recorded) (frame 'plain) step))
(same-frames! "first screen")
(let loop ()
  (when (< (point-line 'plain) 800)
    (def! 'plain '(plain page-down))
    (def! 'recorded (record '(recorded page-down)))
    (loop)))
(def! 'plain (fit 'plain))
(def! 'recorded (record (fit 'recorded)))
(check-true (>= (point-line 'plain) 800))
(same-frames! "deep")
(def! 'plain (fit '(plain move-down)))
(def! 'recorded (record (fit '(recorded move-down))))
(same-frames! "after move-down")
(define before-insert (frame 'plain))
(def! 'plain '(plain insert "q"))
(def! 'recorded (record '(recorded insert "q")))
(same-frames! "after insert")
(check-true (string-contains? (frame 'plain) "q"))
(check-not-equal? (frame 'plain) before-insert)
(def! 'plain '(plain undo))
(def! 'recorded (record '(recorded undo)))
(same-frames! "after undo")
(check-equal? (frame 'plain) before-insert)
