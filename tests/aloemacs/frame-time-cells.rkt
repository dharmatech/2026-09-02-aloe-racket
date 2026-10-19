#lang racket/base

;; aloemacs-frame-time 000: safe-cells, safe-rows, and the padding match a
;; reference painter written here in Racket; one-window frames on the short
;; fixture match it at six origins; and recorded four-window frames equal the
;; unrecorded ones at five steps.

(require racket/list racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path text-path "../../lib/text.aloe")
(define-runtime-path fs-path "../../lib/fs.aloe")

;; The short fixture (spec section 8.1). Line n is n, one space, then x up to 35
;; characters; when n mod 7 is 3, the character at index 10 is a tab.
(define (fixture-line n)
  (define head (format "~a " n))
  (define line (string-append head (make-string (- 35 (string-length head)) #\x)))
  (if (= (modulo n 7) 3)
      (string-append (substring line 0 10) "\t" (substring line 11))
      line))
(define short-lines (for/vector ([n (in-range 971)]) (fixture-line n)))
(define short-fixture (string-join (vector->list short-lines) "\n"))
(check-equal? (length (string-split short-fixture "\n" #:trim? #f)) 971)
(check-equal? (for/sum ([c (in-string short-fixture)]) (if (char=? c #\tab) 1 0)) 139)
(check-equal? (string-ref (vector-ref short-lines 3) 10) #\tab)

(define st (make-driver))
(driver-inject-host!
 st 'fs-host
 (make-fs-double "/cwd"
   (hash "/cwd" 'directory "/cwd/short.txt" 'file)
   (hash "/cwd/short.txt" short-fixture)))
(void (driver-load-file! st main-path))
(driver-eval! st `(load ,(path->string file-path)))
(driver-eval! st `(load ,(path->string editor-path)))
(driver-eval! st `(load ,(path->string text-path)))
(driver-eval! st `(load ,(path->string fs-path)))

(define (ev expr) (driver-eval! st expr))
(define (def! name expr) (ev `(define ,name ,expr)))

;; An Aloe (List String) read back element by element as a Racket list.
(define (aloe-strings expr)
  (def! 'answer expr)
  (for/list ([i (in-range (ev '(answer len)))])
    (ev `(,(for/fold ([e 'answer]) ([_ (in-range i)]) `(,e rest)) first))))
(define (aloe-list strings)
  (if (null? strings) '(List empty) `(List of ,@strings)))

;; The reference painter (spec section 9). Step 4: every character whose code is
;; below 32 or is 127 becomes a space.
(define (blank s)
  (list->string
   (for/list ([c (in-string s)])
     (define code (char->integer c))
     (if (or (< code 32) (= code 127)) #\space c))))
;; Steps 1 to 4 for an origin top, left and a size columns x rows.
(define (reference-rows top left columns rows)
  (for/list ([i (in-range rows)])
    (define n (+ top i))
    (define line (if (< n (vector-length short-lines)) (vector-ref short-lines n) ""))
    (define dropped (if (< left (string-length line)) (substring line left) ""))
    (blank (substring dropped 0 (min columns (string-length dropped))))))
(define (reference-frame rows point-line point-column top left)
  (string-append "\e[?25l\e[2J\e[H"
                 (string-join rows "\r\n")
                 "\e[" (number->string (+ (- point-line top) 1))
                 ";" (number->string (+ (- point-column left) 1))
                 "H\e[?25h"))

(define (control code) (string (integer->char code)))
(define controls (for/list ([code (append (range 32) (list 127))]) (control code)))
(define all-controls (apply string-append controls))
(check-equal? (string-length all-controls) 33)
(define printable (list->string (for/list ([code (in-range 32 127)]) (integer->char code))))
;; e-acute, up-down arrow, left-right arrow, multiplication sign.
(define glyphs (list->string (map integer->char '(#xe9 #x2195 #x2194 #xd7))))
;; 300 y's with ESC at 0, a tab at 150, DEL at 299, three tabs at 40-42, and
;; CR LF at 80-81.
(define long-string
  (let ([s (make-string 300 #\y)])
    (string-set! s 0 (integer->char 27))
    (string-set! s 150 #\tab)
    (string-set! s 299 (integer->char 127))
    (for ([i (in-range 40 43)]) (string-set! s i #\tab))
    (string-set! s 80 #\return)
    (string-set! s 81 #\newline)
    s))
(define nul (control 0))
(define esc (control 27))
(define del (control 127))

(def! 'ed '(aloemacs-editor editor))

;; 1. safe-cells against the reference rule, keeping the argument's length.
(for ([s (append (list "") controls
                 (list all-controls "a\tb" "\e[31m" printable glyphs long-string
                       (string-append nul (control 31) del nul "\t\t")))])
  (define shown (ev `(ed safe-cells ,s)))
  (check-equal? shown (blank s) (format "safe-cells ~s" s))
  (check-equal? (string-length shown) (string-length s) (format "safe-cells length ~s" s)))

;; 2. safe-rows: the reference per row, and the law against safe-cells.
(define clean-rows (list "" "a" (make-string 35 #\x) (make-string 109 #\z)))
(define cycled
  (list->string (for/list ([i (in-range 109)]) (string-ref all-controls (modulo i 33)))))
(check-equal? (aloe-strings `(ed safe-rows ,(aloe-list clean-rows))) clean-rows)
(check-equal? (ev `(ed safe-cells ,cycled)) (make-string 109 #\space))
(for ([rows (list '()
                  '("")
                  '("" "" "")
                  clean-rows
                  (list "\tabc" "def" "ghi")
                  (list "abc" "def" (string-append "ghi" del))
                  (list (string-append nul esc "\t" del "\r"))
                  (list "a\tb" "" (string-append "c" esc "d"))
                  (list "a\tb" (string-append "c" del "d"))
                  (list cycled))])
  (check-equal? (aloe-strings `(ed safe-rows ,(aloe-list rows))) (map blank rows)
                (format "safe-rows ~s" rows))
  (check-not-exn
   (lambda ()
     (ev `(check (ed safe-rows ,(aloe-list rows))
                 (,(aloe-list rows) map (fn (row) (ed safe-cells row))))))
   (format "safe-rows equals safe-cells per row ~s" rows)))

;; 3. Padding by doubling.
(for ([n (in-range -2 301)])
  (check-equal? (ev `((AloemacsWindowRect new 0 0 109 53) spaces ,n))
                (make-string (max n 0) #\space) (format "spaces ~a" n))
  (check-equal? (ev `((AloemacsModeLine new) fill ,n))
                (make-string (max n 0) #\-) (format "fill ~a" n)))

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

;; 4. One-window frames on the short fixture against the reference painter.
(visit! 'one "/cwd/short.txt")
(def! 'one (fit 'one))
(let loop ()
  (when (< (point-line 'one) 800)
    (def! 'one '(one page-down))
    (loop)))
(def! 'one (fit 'one))
(check-true (>= (point-line 'one) 800))
(def! 'deep-ed '(one editor))
(define deep-line (ev '((deep-ed point) line)))
(define deep-column (ev '((deep-ed point) column)))
(for* ([top (list (- deep-line 52) deep-line (- deep-line 20) 0 900 940)]
       [left '(0 5)]
       [columns '(220 20)])
  (define rows (reference-rows top left columns 53))
  (check-equal? (ev `((deep-ed with-origin ,top ,left) frame ,columns 53))
                (reference-frame rows deep-line deep-column top left)
                (format "frame at top ~a left ~a columns ~a" top left columns))
  (check-equal? (aloe-strings `(deep-ed frame-rows ,columns 53 ,top ,left)) rows
                (format "frame-rows at top ~a left ~a columns ~a" top left columns)))

;; 5. Recorded equals unrecorded: four windows, widest leaf, five steps.
(visit! 'four "/cwd/short.txt")
(def! 'four (fit 'four))
(for ([n '(2 3 4)])
  (def! 'four '(four split-right))
  (unless (and (= (leaf-count 'four) n) (not (equal? (ev '(four echo)) "failed")))
    (error 'frame-time-cells "split-right ~a was refused" (sub1 n))))
(let loop ([sends 0])
  (unless (= (selected-columns 'four) 109)
    (when (= sends 4) (error 'frame-time-cells "no 109-column leaf in four sends"))
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
