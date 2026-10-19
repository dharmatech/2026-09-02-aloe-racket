#lang racket/base

;; aloemacs-frame-time 000 and 001: a held Down keeps up in four windows and
;; in one, on the short fixture and the long one, deep and at the last page.
;; Each sample is the runner's own turn, key, fit, record, and frame, as four
;; prepared calls timed as one interval, with tabs on screen. The deep cases
;; are paired across the fixtures, and the long median may not grow past the
;; short one by 1.5 ms. The byte checks are tests/aloemacs/frame-time-cells.rkt
;; and tests/aloemacs/frame-time-lines.rkt.

(require racket/list racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path text-path "../../lib/text.aloe")
(define-runtime-path fs-path "../../lib/fs.aloe")

;; The fixtures (spec section 8.1). Line n is n, one space, then x up to 35
;; characters; when n mod 7 is 3, the character at index 10 is a tab, so
;; every 52-row window shows seven or eight tabbed rows. The short fixture
;; is 971 lines; the long one, 2,400, stands in for a file as long as the
;; editor's own source.
(define (fixture-line n)
  (define head (format "~a " n))
  (define line (string-append head (make-string (- 35 (string-length head)) #\x)))
  (if (= (modulo n 7) 3)
      (string-append (substring line 0 10) "\t" (substring line 11))
      line))
(define short-fixture
  (string-join (for/list ([n (in-range 971)]) (fixture-line n)) "\n"))
(check-equal? (length (string-split short-fixture "\n" #:trim? #f)) 971)
(check-equal? (for/sum ([c (in-string short-fixture)]) (if (char=? c #\tab) 1 0)) 139)
(define long-fixture
  (string-join (for/list ([n (in-range 2400)]) (fixture-line n)) "\n"))
(check-equal? (length (string-split long-fixture "\n" #:trim? #f)) 2400)
(check-equal? (for/sum ([c (in-string long-fixture)]) (if (char=? c #\tab) 1 0)) 343)

(define st (make-driver))
(driver-inject-host!
 st 'fs-host
 (make-fs-double "/cwd"
   (hash "/cwd" 'directory "/cwd/short.txt" 'file "/cwd/long.txt" 'file)
   (hash "/cwd/short.txt" short-fixture "/cwd/long.txt" long-fixture)))
(void (driver-load-file! st main-path))
(driver-eval! st `(load ,(path->string file-path)))
(driver-eval! st `(load ,(path->string editor-path)))
(driver-eval! st `(load ,(path->string text-path)))
(driver-eval! st `(load ,(path->string fs-path)))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))
(define (fit s) `(,s ensure-visible 220 54))
(define (point-line s) (ev `((,s point) line)))
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

(define (visit! name path)
  (def! name `((aloemacs-editor visit (Path new ,path)) case
                (None () aloemacs-editor)
                (Some (session) session)))
  (check-equal? (ev `((,name path) present?)) #t (format "visited ~a" path)))
;; page-down until the point line reaches target, then fit.
(define (page-deep! name [target 800])
  (let loop ()
    (when (< (point-line name) target)
      (def! name `(,name page-down))
      (loop)))
  (def! name (fit name)))
;; Three right splits leave the selected leaf at 27 columns.
(define (split-three! name)
  (for ([n '(2 3 4)])
    (def! name `(,name split-right))
    (unless (and (= (leaf-count name) n)
                 (not (equal? (ev `(,name echo)) "failed")))
      (error 'frame-time "~a: split-right ~a was refused" name (sub1 n))))
  (check-equal? (selected-columns name) 27))
;; other-window until the selected leaf is 109 columns.
(define (select-widest! name)
  (let loop ([sends 0])
    (unless (= (selected-columns name) 109)
      (when (= sends 4) (error 'frame-time "~a: no 109-column leaf in four sends" name))
      (def! name `(,name other-window))
      (loop (add1 sends))))
  (check-equal? (selected-columns name) 109))

;; Sessions (spec section 8.2). A session is a value: building one from
;; another copies it, so paging or sampling one never moves another.

;; 1. One window.
(visit! 'one "/cwd/short.txt")
(def! 'one (fit 'one))

;; 2. First screen: three right splits leave the selected leaf at 27 columns.
(def! 'first-screen 'one)
(split-three! 'first-screen)

;; 3. Widest leaf: other-window until the selected leaf is 109 columns.
(def! 'widest 'first-screen)
(select-widest! 'widest)

;; 4. Four windows deep: only the selected view scrolls.
(def! 'four-deep 'widest)
(page-deep! 'four-deep)
(check-true (>= (point-line 'four-deep) 800))
(check-true (> (selected-scroll 'four-deep) 700))
(check-true (unselected-at-top? 'four-deep))

;; 5. One window deep.
(def! 'one-deep 'one)
(page-deep! 'one-deep)
(check-true (>= (point-line 'one-deep) 800))

;; The same sessions on the long fixture, in the same order.

;; 1. One window.
(visit! 'long-one "/cwd/long.txt")
(def! 'long-one (fit 'long-one))

;; 2. First screen.
(def! 'long-first-screen 'long-one)
(split-three! 'long-first-screen)

;; 3. Widest leaf.
(def! 'long-widest 'long-first-screen)
(select-widest! 'long-widest)

;; 4. Four windows deep: only the selected view scrolls.
(def! 'long-four-deep 'long-widest)
(page-deep! 'long-four-deep)
(check-true (>= (point-line 'long-four-deep) 800))
(check-true (> (selected-scroll 'long-four-deep) 700))
(check-true (unselected-at-top? 'long-four-deep))

;; 5. One window deep.
(def! 'long-one-deep 'long-one)
(page-deep! 'long-one-deep)
(check-true (>= (point-line 'long-one-deep) 800))

;; 6. Last page: from each deep session, a new session paged until the point
;; line is at least 2,300. A point line at most 2,388 keeps eleven Downs
;; inside the last line, 2,399; the deep sessions stay at their depth.
(define long-four-deep-line (point-line 'long-four-deep))
(define long-one-deep-line (point-line 'long-one-deep))
(def! 'long-four-end 'long-four-deep)
(page-deep! 'long-four-end 2300)
(check-true (>= (point-line 'long-four-end) 2300))
(check-true (<= (point-line 'long-four-end) 2388))
(def! 'long-one-end 'long-one-deep)
(page-deep! 'long-one-end 2300)
(check-true (>= (point-line 'long-one-end) 2300))
(check-true (<= (point-line 'long-one-end) 2388))
(check-equal? (point-line 'long-four-deep) long-four-deep-line)
(check-equal? (point-line 'long-one-deep) long-one-deep-line)

;; Sample (spec section 8.3). The four forms are prepared once per timed
;; name, so typechecking stays outside every interval; the fit and the
;; record run once untimed. One sample is the four prepared calls in order,
;; timed as one interval: the key, fit, record, and frame.
(define (sampler t)
  (define key! (driver-prepare! st `(define ,t (,t handle-event "down"))))
  (define fit! (driver-prepare! st `(define ,t (,t ensure-visible 220 54))))
  (define record! (driver-prepare! st `(define ,t (,t record-pictures 220 54))))
  (define paint! (driver-prepare! st `(,t frame 220 54)))
  (fit!)
  (record!)
  (lambda ()
    (define begun (current-inexact-monotonic-milliseconds))
    (key!)
    (fit!)
    (record!)
    (paint!)
    (- (current-inexact-monotonic-milliseconds) begun)))

(define samples 11)

;; A group of one or more cases is sampled in alternation, one sample of
;; each per round, for eleven rounds. Each case's timed name is bound to a
;; copy of its session, so the samples move that name and nothing else. The
;; median is the sixth sample after sorting ascending.
(define (medians cases)
  (define samplers
    (for/list ([case cases])
      (define t (string->symbol (format "timed-~a" case)))
      (def! t case)
      (sampler t)))
  (collect-garbage)
  (define rounds
    (for/list ([round (in-range samples)])
      (for/list ([sample samplers]) (sample))))
  (for/list ([index (in-range (length cases))])
    (define durations (for/list ([round rounds]) (list-ref round index)))
    (list-ref (sort durations <) (quotient samples 2))))

(define (bar! label median)
  (printf "~a: median ~a ms\n" label (real->decimal-string median 2))
  (check-true (< median 30.0) (format "~a: median ~a ms" label median)))

;; The long median of a deep pair minus the short one is under 1.5 ms: at
;; the same depth the read takes nothing from the file below the point.
(define (growth! label short-label long-label short-median long-median)
  (define growth (- long-median short-median))
  (printf "~a: ~a ms\n" label (real->decimal-string growth 2))
  (check-true (< growth 1.5)
              (format "~a: ~a minus ~a is ~a ms" label long-label short-label growth)))

;; Cases (spec section 8.4), four groups in this order. A group of two is
;; sampled in alternation, so load during the suite falls on both alike.

;; Group 1.
(bar! "four windows, first screen" (first (medians '(first-screen))))

;; Group 2: four windows deep, paired across the fixtures.
(define four-deep-medians (medians '(four-deep long-four-deep)))
(bar! "four windows, widest leaf deep, 971 lines" (first four-deep-medians))
(bar! "four windows, widest leaf deep, 2400 lines" (second four-deep-medians))
(growth! "growth, four windows deep"
         "four windows, widest leaf deep, 971 lines"
         "four windows, widest leaf deep, 2400 lines"
         (first four-deep-medians) (second four-deep-medians))

;; Group 3: one window deep, paired across the fixtures.
(define one-deep-medians (medians '(one-deep long-one-deep)))
(bar! "one window deep, 971 lines" (first one-deep-medians))
(bar! "one window deep, 2400 lines" (second one-deep-medians))
(growth! "growth, one window deep"
         "one window deep, 971 lines"
         "one window deep, 2400 lines"
         (first one-deep-medians) (second one-deep-medians))

;; Group 4: the last page of the long fixture, held to the 30 ms bar alone.
(define end-medians (medians '(long-four-end long-one-end)))
(bar! "four windows, widest leaf, last page of 2400 lines" (first end-medians))
(bar! "one window, last page of 2400 lines" (second end-medians))
