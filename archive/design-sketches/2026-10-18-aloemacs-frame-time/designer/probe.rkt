#lang racket/base

;; Frame-time probe from the aloemacs-frame-time designer, 2026-10-18.
;; Scratch program, not a test: its effects are in a main submodule.
;;   racket probe.rkt <tree> <lines> [samples] [cases] [ctl]
;; <tree> is a repository copy. Same geometry and fixture as
;; tests/aloemacs/window-pictures.rkt: 220x54, lines "n xxx..." of 35
;; characters, three split-right, the 109-column leaf. Deep is page-down to
;; line 800; *-end is page-down to <lines> - 120. Cases, comma-separated:
;; first wide one wide-end one-end up-wide up-one wide-key one-key wide-hk
;; one-hk type4 type1 type4-end. Without -key/-hk the key is outside the
;; interval, as in window-pictures.rkt. "ctl" puts a tab at index 10 of
;; every line n with n mod 7 = 0.

(require racket/format racket/list racket/string)

(module+ main
  (define args (current-command-line-arguments))
  (define root (vector-ref args 0))
  (define line-count (string->number (vector-ref args 1)))
  (define samples (if (> (vector-length args) 2) (string->number (vector-ref args 2)) 11))
  (define cases
    (if (> (vector-length args) 3)
        (map string->symbol (string-split (vector-ref args 3) ","))
        '(first wide one)))
  (define control? (and (> (vector-length args) 4) (equal? (vector-ref args 4) "ctl")))

  (define (rp rel) (simplify-path (build-path root rel)))
  (define (driver name) (dynamic-require (rp "aloe/driver.rkt") name))
  (define make-driver (driver 'make-driver))
  (define driver-inject-host! (driver 'driver-inject-host!))
  (define driver-load-file! (driver 'driver-load-file!))
  (define driver-eval! (driver 'driver-eval!))
  (define driver-prepare! (driver 'driver-prepare!))
  (define make-fs-double (dynamic-require (rp "host/racket/fs.rkt") 'make-fs-double))

  (define fixture
    (string-join
     (for/list ([n (in-range line-count)])
       (define head (format "~a " n))
       (define body (string-append head (make-string (- 35 (string-length head)) #\x)))
       ;; ctl: every 7th line carries a tab at column 10
       (if (and control? (zero? (modulo n 7)))
           (string-append (substring body 0 10) "\t" (substring body 11))
           body))
     "\n"))

  (define st (make-driver))
  (driver-inject-host! st 'fs-host
    (make-fs-double "/cwd" (hash "/cwd" 'directory "/cwd/lines.txt" 'file)
                    (hash "/cwd/lines.txt" fixture)))
  (void (driver-load-file! st (rp "examples/aloemacs/main.aloe")))
  (for ([file '("examples/aloemacs/file.aloe" "examples/aloemacs/editor.aloe"
                "lib/text.aloe" "lib/fs.aloe")])
    (driver-eval! st `(load ,(path->string (rp file)))))

  (define (ev expr) (driver-eval! st expr))
  (define (def! name expr) (ev `(define ,name ,expr)))
  (define (point-line s) (ev `((,s point) line)))

  (def! 'one '(((aloemacs-editor visit (Path new "/cwd/lines.txt")) case
                 (None () aloemacs-editor) (Some (s) s))
               ensure-visible 220 54))
  (def! 'top 'one)
  (for ([_ 3]) (def! 'top '(top split-right)))
  (def! 'wide 'top)
  (let loop ()
    (unless (= (ev '((wide fit-rect 220 54) columns)) 109)
      (def! 'wide '(wide other-window))
      (loop)))
  (define (deep! name target)
    (let loop ()
      (when (< (point-line name) target)
        (def! name `(,name page-down))
        (loop)))
    (def! name `(,name ensure-visible 220 54)))

  (def! 'timed 'top)
  (define fit! (driver-prepare! st '(define timed (timed ensure-visible 220 54))))
  (define record! (driver-prepare! st '(define timed (timed record-pictures 220 54))))
  (define paint! (driver-prepare! st '(timed frame 220 54)))
  (define down! (driver-prepare! st '(define timed (timed move-down))))
  (define up! (driver-prepare! st '(define timed (timed move-up))))
  (define type! (driver-prepare! st '(define timed (timed insert "q"))))
  (define hk! (driver-prepare! st '(define timed (timed handle-key "down"))))

  (define (median-ms start key! key-inside?)
    (def! 'timed start)
    (fit!)
    (record!)
    (define durations
      (for/list ([sample (in-range samples)])
        (define begun0 (current-inexact-monotonic-milliseconds))
        (key!)
        (define begun (if key-inside? begun0 (current-inexact-monotonic-milliseconds)))
        (fit!)
        (record!)
        (paint!)
        (- (current-inexact-monotonic-milliseconds) begun)))
    (list-ref (sort durations <) (quotient samples 2)))

  (define-values (wide-deep one-deep) (values #f #f))
  (define (ensure-deep!)
    (unless wide-deep
      (def! 'wide-deep 'wide) (deep! 'wide-deep 800)
      (def! 'one-deep 'one) (deep! 'one-deep 800)
      (set! wide-deep #t)))
  (define end-done #f)
  (define (ensure-end!)
    (unless end-done
      (def! 'wide-end 'wide) (deep! 'wide-end (- line-count 120))
      (def! 'one-end 'one) (deep! 'one-end (- line-count 120))
      (set! end-done #t)))
  ;; Up cases: deep, then move the point to the top row of the selected view.
  (define up-done #f)
  (define (ensure-up!)
    (unless up-done
      (ensure-deep!)
      (for ([name '(wide-up one-up)] [from '(wide-deep one-deep)])
        (def! name from)
        (let loop ()
          (unless (= (point-line name) (ev `((,name editor) scroll-row)))
            (def! name `(,name move-up))
            (loop)))
        (def! name `(,name ensure-visible 220 54)))
      (set! up-done #t)))

  (define results
    (for/list ([c cases])
      (define ms
        (case c
          [(first) (median-ms 'top down! #f)]
          [(wide) (ensure-deep!) (median-ms 'wide-deep down! #f)]
          [(one) (ensure-deep!) (median-ms 'one-deep down! #f)]
          [(wide-key) (ensure-deep!) (median-ms 'wide-deep down! #t)]
          [(one-key) (ensure-deep!) (median-ms 'one-deep down! #t)]
          [(wide-end) (ensure-end!) (median-ms 'wide-end down! #f)]
          [(one-end) (ensure-end!) (median-ms 'one-end down! #f)]
          [(up-wide) (ensure-up!) (median-ms 'wide-up up! #t)]
          [(up-one) (ensure-up!) (median-ms 'one-up up! #t)]
          [(type4) (ensure-deep!) (median-ms 'wide-deep type! #t)]
          [(type1) (ensure-deep!) (median-ms 'one-deep type! #t)]
          [(wide-hk) (ensure-deep!) (median-ms 'wide-deep hk! #t)]
          [(one-hk) (ensure-deep!) (median-ms 'one-deep hk! #t)]
          [(type4-end) (ensure-end!) (median-ms 'wide-end type! #t)]))
      (cons c ms)))
  (printf "~a ~a:" (let-values ([(base name dir?) (split-path root)]) name) line-count)
  (for ([r results]) (printf " ~a=~a" (car r) (~r (cdr r) #:precision '(= 1))))
  (newline))
