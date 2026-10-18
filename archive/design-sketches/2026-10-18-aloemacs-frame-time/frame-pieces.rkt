#lang racket/base

;; Where a deep Aloemacs frame spends its time, piece by piece, and what one
;; typed key costs. Same geometry and fixture as tests/aloemacs/window-pictures.rkt:
;; 220x54, lines "n xxx..." of 35 characters, three split-right, the 109-column
;; leaf selected, page-down past line 800, then ensure-visible.
;; Scratch program from the 2026-10-18 frame-time discussion; not a test.
;;   racket frame-pieces.rkt                 this checkout, 971 lines
;;   racket frame-pieces.rkt <root> [lines]  another tree (a git archive copy)
;; Every number is the median of 21 runs of one driver-prepare! thunk, so
;; typechecking is outside it.

(require racket/format
         racket/list
         racket/runtime-path
         racket/string)

(define-runtime-path here-root "../../..")

(module+ main
  (define args (current-command-line-arguments))
  (define root (if (> (vector-length args) 0) (vector-ref args 0) here-root))
  (define line-count
    (if (> (vector-length args) 1) (string->number (vector-ref args 1)) 971))
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
       (string-append head (make-string (- 35 (string-length head)) #\x)))
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
  (define (deep! name)
    (let loop ()
      (when (< (point-line name) 800)
        (def! name `(,name page-down))
        (loop)))
    (def! name `((,name ensure-visible 220 54) record-pictures 220 54)))
  (deep! 'wide)
  (deep! 'one)

  (define (median-ms runs thunk)
    (for ([_ 3]) (thunk))
    (define durations
      (for/list ([_ runs])
        (define begun (current-inexact-monotonic-milliseconds))
        (thunk)
        (- (current-inexact-monotonic-milliseconds) begun)))
    (list-ref (sort durations <) (quotient runs 2)))

  (define (piece label expr)
    (define thunk (driver-prepare! st expr))
    (printf "  ~a  ~a\n"
            (~a (~r (median-ms 21 thunk) #:precision '(= 2)) #:min-width 6 #:align 'right)
            label))

  ;; One sample's sessions: s0 after one Down, s0f fitted, s0r recorded.
  (define (sample! start)
    (def! 's0 `(,start move-down))
    (def! 's0f '(s0 ensure-visible 220 54))
    (def! 's0r '(s0f record-pictures 220 54))
    (def! 'ed '(s0f editor)))

  (printf "~a lines, 220x54\n\nfour windows, 109-column leaf deep\n" line-count)
  (sample! 'wide)
  (def! 'tree '((s0f windows) tree))
  (def! 'bufs '(s0f buffers))
  (def! 'sel '((s0f windows) selected))
  (def! 'rect '(s0f fit-rect 220 54))
  (def! 'root '(s0f root-rect 220 54))
  (def! 'v '((tree find-view sel) case
              (None () (AloemacsView new 0 0 0 0 (Position new 0 0) #f (Option None)))
              (Some (view) view)))
  (def! 'sr '(v scroll-row))
  (def! 'at-top '(((ed text) focus-at sr) case (None () (ed text)) (Some (t) t)))
  (def! 'raw '(at-top next-lines (rect text-rows)))
  (def! 'clipped '(raw map (fn (line) ((line drop 0) take (rect columns)))))
  (def! 'cells '(clipped map (fn (line) (ed safe-cells line))))
  (def! 'rows-r '(((s0r windows) tree) frame-rows bufs root sel))
  (printf "  point ~a, selected scroll ~a, leaf ~ax~a text rows\n"
          (point-line 's0f) (ev 'sr) (ev '(rect columns)) (ev '(rect text-rows)))
  (piece "sample: fit, record, frame"
         '((((s0 ensure-visible 220 54) record-pictures 220 54) frame 220 54) len))
  (piece "fit (session ensure-visible)" '(s0 ensure-visible 220 54))
  (piece "record-pictures" '(s0f record-pictures 220 54))
  (piece "frame" '(s0r frame 220 54))
  (piece "built-rows, selected leaf" '(tree built-rows v bufs rect sel))
  (piece "  editor frame-rows" '(ed frame-rows (rect columns) (rect text-rows) sr (v scroll-col)))
  (piece "    focus-at scroll-row, from point" '((ed text) focus-at sr))
  (piece "    next-lines text-rows" '(at-top next-lines (rect text-rows)))
  (piece "    drop and take" '(raw map (fn (line) ((line drop 0) take (rect columns)))))
  (piece "    safe-cells" '(clipped map (fn (line) (ed safe-cells line))))
  (piece "  pad-row" '(cells map (fn (line) (rect pad-row line))))
  (piece "  mode-line row and bar"
         '((AloemacsModeLine new) bar
            (ed safe-cells ((AloemacsModeLine new) row ((s0f current-buffer) name) (rect columns)))
            #t))
  (piece "tree frame-rows, four pictures reused" '(((s0r windows) tree) frame-rows bufs root sel))
  (piece "join rows" '((rows-r rest) fold (rows-r first) (fn (b l) ((b append "\r\n") append l))))

  (printf "\none window deep\n")
  (sample! 'one)
  (def! 'ed '(s0r editor))
  (def! 'top-row '(ed scroll-row))
  (def! 'focused '(((ed text) focus-at ((ed point) line)) case (None () (ed text)) (Some (t) t)))
  (def! 'at-top '((focused focus-at top-row) case (None () focused) (Some (t) t)))
  (def! 'raw '(at-top next-lines 53))
  (def! 'clipped '(raw map (fn (line) ((line drop 0) take 220))))
  (piece "sample: fit, record, frame"
         '((((s0 ensure-visible 220 54) record-pictures 220 54) frame 220 54) len))
  (piece "frame (single-frame)" '(s0r frame 220 54))
  (piece "  editor frame" '(ed frame 220 53))
  (piece "    focus-at top, from point" '(focused focus-at top-row))
  (piece "    next-lines 53" '(at-top next-lines 53))
  (piece "    drop and take" '(raw map (fn (line) ((line drop 0) take 220))))
  (piece "    safe-cells" '(clipped map (fn (line) (ed safe-cells line))))
  (piece "  mode-line row and bar"
         '((AloemacsModeLine new) bar
            (ed safe-cells ((AloemacsModeLine new) row ((s0r current-buffer) name) 220)) #t))

  (printf "\nunit costs\n")
  (def! 'mid '(((ed text) focus-at 500) case (None () (ed text)) (Some (t) t)))
  (def! 'all-lines '(mid lines))
  (piece "one focus-down" '(mid focus-down))
  (piece "List rest of every line" '(all-lines rest))
  (piece "List cons onto every line" '(all-lines cons "x"))
  (piece "safe-cells, one 35-character line" '(ed safe-cells "123 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"))
  (piece "pad-row, 35 to 109 columns"
         '((AloemacsWindowRect new 0 0 109 53) pad-row "123 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"))

  ;; One key and the runner's three prepared calls, as one interval.
  (define (per-key label start key)
    (def! 'timed start)
    (define key! (driver-prepare! st `(define timed (timed ,@key))))
    (define fit! (driver-prepare! st '(define timed (timed ensure-visible 220 54))))
    (define record! (driver-prepare! st '(define timed (timed record-pictures 220 54))))
    (define paint! (driver-prepare! st '(timed frame 220 54)))
    (printf "  ~a  ~a\n"
            (~a (~r (median-ms 7 (lambda () (key!) (fit!) (record!) (paint!))) #:precision '(= 1))
                #:min-width 6 #:align 'right)
            label))
  (printf "\nper key, key inside the interval\n")
  (per-key "Down, four windows deep" 'wide '(move-down))
  (per-key "Down, one window deep" 'one '(move-down))
  (per-key "typed character, four windows deep" 'wide '(insert "q"))
  (per-key "typed character, one window deep" 'one '(insert "q")))
