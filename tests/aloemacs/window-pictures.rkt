#lang racket/base

;; aloemacs-window-pictures 000: recorded leaf rows paint the bytes a fresh
;; build paints, and a held Down stays under the keyboard repeat interval.

(require racket/list racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type?)
         "../../host/racket/fs.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

;; Line n is n, one space, then x up to 35 characters.
(define fixture
  (string-join
   (for/list ([n (in-range 971)])
     (define head (format "~a " n))
     (string-append head (make-string (- 35 (string-length head)) #\x)))
   "\n"))
(check-equal? (length (string-split fixture "\n" #:trim? #f)) 971)
(check-true (string-prefix? fixture "0 x"))

(define (numbered word count)
  (string-join (for/list ([n (in-range count)]) (format "~a ~a" word n)) "\n"))

(define st (make-driver))
(driver-inject-host!
 st 'fs-host
 (make-fs-double "/cwd"
   (hash "/cwd" 'directory "/cwd/lines.txt" 'file "/cwd/swap.txt" 'file)
   (hash "/cwd/lines.txt" fixture "/cwd/swap.txt" (numbered "alpha" 60))))
(void (driver-load-file! st main-path))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))
(define (same actual expected)
  (check-not-exn (lambda () (ev `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))

(define (frame s) (ev `(,s frame 220 54)))
(define (record s) `(,s record-pictures 220 54))
(define (fit s) `(,s ensure-visible 220 54))
(define (point-line s) (ev `((,s point) line)))
(define (history-length s) (ev `(((,s editor) history) len)))
(define (leaf-count s) (ev `((((,s windows) tree) leaves) len)))
(define (selected-columns s) (ev `((,s fit-rect 220 54) columns)))
(define (selected-scroll s)
  (ev `((((,s windows) tree) find-view ((,s windows) selected)) case
         (None () -1)
         (Some (view) (view scroll-row)))))
(define (unselected-at-top? s)
  (ev `((((,s windows) tree) leaves) fold #t
         (fn (ok view)
           (if ok
               (if ((view id) = ((,s windows) selected)) #t ((view scroll-row) = 0))
               #f)))))
(define (picture-count s)
  (ev `((((,s windows) tree) leaves) fold 0
         (fn (count view) (if ((view picture) present?) (count + 1) count)))))
;; Every leaf holds a picture at the buffer's current history length.
(define (pictured-at-history? s)
  (ev `((((,s windows) tree) leaves) fold #t
         (fn (ok view)
           (if ok
               ((view picture) case
                 (None () #f)
                 (Some (picture)
                   ((picture history-length) = (((,s editor) history) len))))
               #f)))))

(define (visit! name path)
  (def! name `((aloemacs-editor visit (Path new ,path)) case
                (None () aloemacs-editor)
                (Some (session) session)))
  (check-equal? (ev `((,name path) present?)) #t (format "visited ~a" path)))

(define (split-four! name from)
  (def! name from)
  (for ([n '(2 3 4)])
    (def! name `(,name split-right))
    (unless (and (= (leaf-count name) n)
                 (not (equal? (ev `(,name echo)) "failed")))
      (error 'window-pictures "split-right ~a was refused" (sub1 n)))))

(define (page-deep! name)
  (let loop ()
    (when (< (point-line name) 800)
      (def! name `(,name page-down))
      (loop)))
  (def! name (fit name)))

;; Fixture, one fitted window, then three right splits.
(visit! 'visited "/cwd/lines.txt")
(def! 'one (fit 'visited))
(split-four! 'top 'one)
(check-equal? (selected-columns 'top) 27)
(check-true (unselected-at-top? 'top))
(check-equal? (selected-scroll 'top) 0)

(test-case "first screen: recorded rows paint the same bytes"
  (def! 'top-recorded (record 'top))
  (check-equal? (picture-count 'top-recorded) 4)
  (check-equal? (frame 'top-recorded) (frame 'top))
  (check-equal? (frame (record '(top-recorded move-down)))
                (frame '(top move-down))))

(test-case "a matching picture is painted and a stale key rebuilds"
  ;; Replace the rightmost leaf's rows with a marker; change its key to miss.
  (define marker (make-string 109 #\P))
  (define (planted scroll-row)
    `(((top-recorded windows) tree) case
       (Right (left right)
         (right case
           (Leaf (view)
             ((view picture) case
               (Some (picture)
                 (top-recorded with
                   (windows
                     ((top-recorded windows) with
                       (tree
                         (AloemacsWindowTree Right left
                           (AloemacsWindowTree Leaf
                             (view with
                               (picture
                                 (Option Some
                                   (picture with
                                     (scroll-row ,scroll-row)
                                     (lines (List of ,@(make-list 53 marker))))))))))))))
               (None () top-recorded)))
           (else top-recorded)))
       (else top-recorded)))
  (check-true (string-contains? (frame (planted 0)) marker))
  (check-equal? (frame (planted 1)) (frame 'top)))

(test-case "deep selected scroll: recorded rows paint the same bytes"
  (def! 'deep 'top)
  (page-deep! 'deep)
  (check-true (>= (point-line 'deep) 800))
  (check-true (> (selected-scroll 'deep) 700))
  (check-true (unselected-at-top? 'deep))
  (def! 'deep-recorded (record 'deep))
  (check-equal? (picture-count 'deep-recorded) 4)
  (check-equal? (frame 'deep-recorded) (frame 'deep))
  (def! 'deep-next (fit '(deep move-down)))
  (def! 'deep-next-recorded (record (fit '(deep-recorded move-down))))
  (check-true (> (selected-scroll 'deep-next) (selected-scroll 'deep)))
  (check-true (unselected-at-top? 'deep-next))
  (check-true (unselected-at-top? 'deep-next-recorded))
  (check-equal? (frame 'deep-next-recorded) (frame 'deep-next)))

(test-case "an edit rebuilds every leaf and undo paints the pre-edit bytes"
  (define before (frame 'deep-next-recorded))
  (define line (point-line 'deep-next-recorded))
  (def! 'inserted (record '(deep-next-recorded insert "q")))
  (check-equal? (history-length 'inserted) 1)
  (check-true (pictured-at-history? 'inserted))
  (define edited (frame 'inserted))
  (check-not-equal? edited before)
  (check-true (string-contains? edited (format "q~a " line)))
  (check-equal? edited (frame '(deep-next insert "q")))
  (def! 'undone (record '(inserted undo)))
  (check-equal? (history-length 'undone) 0)
  (check-true (pictured-at-history? 'undone))
  (check-equal? (frame 'undone) before))

(test-case "visited drops the replaced buffer's pictures on every leaf"
  (visit! 'swap "/cwd/swap.txt")
  (check-equal? (history-length 'swap) 0)
  (split-four! 'swap-four (fit 'swap))
  (def! 'swap-recorded (record 'swap-four))
  (check-equal? (picture-count 'swap-recorded) 4)
  (define contents (numbered "omega" 60))
  (def! 'swap-fresh `(swap-four visited ,contents (Path new "/cwd/swap.txt")))
  (def! 'swap-revisited `(swap-recorded visited ,contents (Path new "/cwd/swap.txt")))
  ;; The key alone cannot see this replacement.
  (check-equal? (history-length 'swap-revisited) 0)
  (check-equal? (ev '((swap-revisited current-buffer) name)) "/cwd/swap.txt")
  (check-equal? (picture-count 'swap-revisited) 0)
  (define painted (frame (record 'swap-revisited)))
  (check-equal? painted (frame 'swap-fresh))
  (check-true (string-contains? painted "omega 0"))
  (check-false (string-contains? painted "alpha")))

(test-case "a one-window session that never recorded is returned unchanged"
  (check-equal? (picture-count 'one) 0)
  (same (record 'one) 'one)
  (check-eq? (ev (record 'one)) (ev 'one)))

(test-case "a skipped record drops pictures before a later split copies them"
  (define (steps recorded?)
    (define (maybe s) (if recorded? (record s) s))
    (def! 'c (maybe '((one insert "a") split-right)))
    (when recorded? (check-equal? (picture-count 'c) 2))
    (def! 'c '(c delete-window))
    (check-equal? (leaf-count 'c) 1)
    (when recorded?
      ;; The survivor still holds its 109-column picture until the skip.
      (check-equal? (picture-count 'c) 1)
      (def! 'c (record 'c))
      (check-equal? (picture-count 'c) 0)
      (same '(((c windows) tree) leaves)
            `(List of (AloemacsView new 1 ,(ev '((c current-buffer) id)) 0 0 #f
                        (Option None)))))
    (def! 'c (maybe '(((c undo) insert "b") split-right)))
    (check-equal? (history-length 'c) 1)
    (frame 'c))
  (define recorded (steps #t))
  (define plain (steps #f))
  (check-equal? recorded plain)
  (check-true (string-contains? recorded "|b0 "))
  (check-false (string-contains? recorded "a0 ")))

(test-case "a root with no positive layout drops every picture"
  (check-equal? (picture-count 'deep-recorded) 4)
  (def! 'zero '(deep-recorded record-pictures 0 0))
  (check-equal? (picture-count 'zero) 0))

(test-case "the picture argument is required and typed"
  (for ([bad '((AloemacsView new 0 0 0 0 #f) (AloemacsView new 0 0 0 0 #f 0))])
    (check-exn exn:fail:aloe-type? (lambda () (ev bad)) (format "reject ~s" bad))))

;; Timing bar. Each sample is one untimed Down, then the runner's three
;; prepared calls: fit, record, and paint.
(def! 'timed 'top)
(define fit! (driver-prepare! st '(define timed (timed ensure-visible 220 54))))
(define record! (driver-prepare! st '(define timed (timed record-pictures 220 54))))
(define paint! (driver-prepare! st '(timed frame 220 54)))
(define down! (driver-prepare! st '(define timed (timed move-down))))

(define (median-ms start)
  (def! 'timed start)
  (fit!)
  (record!)
  (define durations
    (for/list ([sample (in-range 5)])
      (down!)
      (define begun (current-inexact-monotonic-milliseconds))
      (fit!)
      (record!)
      (paint!)
      (- (current-inexact-monotonic-milliseconds) begun)))
  (list-ref (sort durations <) 2))

(define (bar! label median)
  (check-true (< median 30.0) (format "~a: median ~a ms" label median))
  (when (< median 30.0)
    (printf "~a: median ~a ms\n" label median)))

;; Four windows, first screen: every picture matches.
(bar! "four windows, first screen" (median-ms 'top))

;; Four windows, widest leaf deep in the file: one leaf rebuilds per Down.
(def! 'wide 'top)
(let loop ([sends 0])
  (unless (= (selected-columns 'wide) 109)
    (when (= sends 4) (error 'window-pictures "no 109-column leaf"))
    (def! 'wide '(wide other-window))
    (loop (add1 sends))))
(page-deep! 'wide)
(check-true (>= (point-line 'wide) 800))
(check-true (> (selected-scroll 'wide) 700))
(check-equal? (selected-columns 'wide) 109)
(check-true (unselected-at-top? 'wide))
(bar! "four windows, widest leaf deep" (median-ms 'wide))

;; One window deep in the file.
(def! 'single 'one)
(page-deep! 'single)
(check-true (>= (point-line 'single) 800))
(bar! "one window, deep" (median-ms 'single))
