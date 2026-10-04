#lang racket/base

(require racket/list racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt"
         "../../host/racket/aloemacs-run.rkt" "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define (editor text [line 0] [column 0] [top 0] [left 0] [height 0])
  `(AloemacsEditor new ((Text from-string ,text) indexed-value)
     (Position new ,line ,column) #f ,top ,left
     (List of (UndoFrame new (Text from-string "old") (Position new 0 1) 0 0))
     ,no-mark ,height))
(define (counted-fs)
  (define calls (box '()))
  (define disk (make-fs-double "/cwd"
                 (hash "/cwd" 'directory "/cwd/a" 'file "/cwd/b" 'file "/cwd/dir" 'directory)
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
(define (cursor row col) (format "\e[~a;~aH" row col))
(define (direct body row col)
  (string-append "\e[?25l\e[2J\e[H" body (cursor row col) "\e[?25h"))
(define (safe s)
  (list->string (for/list ([c (in-string s)])
                 (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (clip s width) (substring s 0 (min width (string-length s))))
(define (name-row name width)
  (define label (clip (string-append name " ") width))
  (safe (string-append label (make-string (- width (string-length label)) #\-))))
;; Independent chrome; body is literal data, never a product frame.
(define (frame body row col width rows name echo [final-row row] [final-col col])
  (string-append (direct body row col)
    (if (= rows 1) ""
        (string-append "\e[?25l"
          (if (>= rows 3) (string-append (cursor (sub1 rows) 1) (name-row name width)) "")
          (cursor rows 1) (safe (clip echo width))
          (cursor final-row final-col) "\e[?25h"))))
(define (paint st s width rows expected calls)
  (define before (ev st s))
  (define effects (unbox calls))
  (check-equal? (ev st `(,s frame ,width ,rows)) expected)
  (check-equal? (ev st `(,s frame ,width ,rows)) expected)
  (check-equal? (ev st s) before)
  (check-equal? (unbox calls) effects))

(test-case "complete independent tall/short frames, statuses, search and prompt"
  (define-values (st calls) (state))
  (for ([width '(1 4 12 20)])
    (paint st 's width 4 (frame "\r\n" 1 1 width 4 "untitled" "") calls))
  (def! st 'bound '(s add-buffer "zero\none\ntwo\nthree" (Path new "/cwd/a")))
  (def! st 'bound '(bound with-editor (AloemacsEditor new
                    (Text indexed (List of "one" "zero") "two" (List of "three") 2)
                    (Position new 3 2) #f 2 1 (List empty)
                    (Option Some (Position new 1 1)) 9)))
  (for ([status '("" "saved" "failed")]
        [echo '("/cwd/a" "saved: /cwd/a" "failed: /cwd/a")])
    (def! st 'status `(bound with-echo ,status))
    (paint st 'status 20 4 (frame "wo\r\nhree" 2 2 20 4 "/cwd/a" (if (equal? status "") "" echo)) calls)
    (paint st 'status 20 2 (frame "wo" 2 2 20 2 "/cwd/a" echo) calls)
    (paint st 'status 20 1 (direct "wo" 2 2) calls))
  (def! st 'search '(bound with-search (bound editor) #t "two" (Position new 1 2) #f #f))
  (paint st 'search 12 3 (frame "wo" 2 2 12 3 "/cwd/a" "search: two") calls)
  (paint st 'search 12 2 (frame "wo" 2 2 12 2 "/cwd/a" "search: two") calls)
  (paint st 'search 12 1 (direct "wo" 2 2) calls)
  (for ([wrapped '(#t #f)] [failing '(#f #t)] [echo '("wrapped: two" "failing: two")])
    (def! st 'search `(search with-search (search editor) #t "two" (search origin) ,wrapped ,failing))
    (paint st 'search 20 3 (frame "wo" 2 2 20 3 "/cwd/a" echo) calls))
  (def! st 'prompt '(search with-active-prompt (AloemacsPrompt new "Ask: " "abcd" 2)))
  (for ([rows '(1 2 3 4)])
    (paint st 'prompt 12 rows
      (frame (if (= rows 4) "wo\r\nhree" "wo") 2 2 12 rows "/cwd/a" "Ask: abcd"
             (if (= rows 1) 2 rows) (if (= rows 1) 2 8)) calls))
  (def! st 'blank `(s with-editor ,(editor "\n\n")))
  (paint st 'blank 12 4 (frame "\r\n" 1 1 12 4 "untitled" "") calls)
  ;; Actual direct editor heights and raw branches remain independent goldens.
  (for ([rows '(0 1 2 3)] [body '("" "wo" "wo\r\nhree" "wo\r\nhree\r\n")])
    (check-equal? (ev st `((bound editor) frame 12 ,rows)) (direct body 2 2)))
  (def! st 'raw `(s with-editor ,(editor "x" 99 -2 0 0)))
  (paint st 'raw 12 4 (frame "" 100 -1 12 4 "untitled" "") calls)
  (def! st 'raw `(s with-editor ,(editor "x" 0 0 99 2)))
  (paint st 'raw 12 4 (frame "" -98 -1 12 4 "untitled" "") calls))

(test-case "control names stay raw in storage/helper and paint safe after clipping"
  (define-values (st calls) (state))
  (define name "a\e[31m\t\r\n\u0001\u007fZ")
  (def! st 's `(s with-current-path (Path new ,name)))
  (for ([width '(1 3 6 10 15)])
    (define label (clip (string-append name " ") width))
    (check-equal? (ev st `((AloemacsModeLine new) row ,name ,width))
                  (string-append label (make-string (- width (string-length label)) #\-)))
    (paint st 's width 3 (frame "" 1 1 width 3 name "") calls)
    (check-equal? (ev st '((s current-buffer) name)) name)
    (check-equal? (ev st '((s path) case (None () "") (Some (path) (path text)))) name))
  (check-equal? (name-row name 15) "a [31m     Z --"))

(test-case "minimal fit, all preserved payloads, remembered heights and page distances"
  (define-values (st calls) (state))
  (def! st 's `(s with-editor ,(editor "zero\none\ntwo\nthree" 3)))
  (def! st 's '(s with-search (s editor) #t "query" (Position new 1 2) #t #t))
  (def! st 's '(s with-prefix aloemacs-ctrl-x-keymap))
  (def! st 'fit '(s ensure-visible 12 4))
  (check-equal? (ev st '((fit editor) scroll-row)) 2)
  (check-equal? (ev st '((fit editor) text-rows)) 2)
  (for ([field '(fs echo searching query origin wrapped failing kill-ring pending prompt
                   last-submission waiting-command path)])
    (check-equal? (ev st `(fit ,field)) (ev st `(s ,field))))
  (for ([field '(text point quit history mark)])
    (check-equal? (ev st `((fit editor) ,field)) (ev st `((s editor) ,field))))
  (check-equal? (ev st '((fit buffers) before)) (ev st '((s buffers) before)))
  (check-equal? (ev st '((fit buffers) after)) (ev st '((s buffers) after)))
  (check-equal? (ev st '((fit windows) columns)) 12)
  (check-equal? (ev st '((fit windows) rows)) 4)
  (check-equal? (ev st '(((fit windows) tree) case
                         (Leaf (v) (v scroll-row)) (else -1))) 2)
  (check-equal? (ev st '(fit ensure-visible 12 4)) (ev st 'fit))
  (def! st 'idle '(fit with-search (fit editor) #f "" (fit origin) #f #f))
  (paint st 'idle 12 4 (frame "two\r\nthree" 2 1 12 4 "untitled" "") calls)
  (def! st 'up '((idle move-up) ensure-visible 12 4))
  (check-equal? (ev st '((up editor) scroll-row)) 2)
  (paint st 'up 12 4 (frame "two\r\nthree" 1 1 12 4 "untitled" "") calls)
  (define before (ev st 'idle))
  (ev st '(idle frame 1 2))
  (check-equal? (ev st 'idle) before)
  (for ([terminal-height '(1 2 3 4 5)] [text-height '(1 1 1 2 3)] [distance '(1 1 1 1 2)])
    (def! st 'page `(s ensure-visible 12 ,terminal-height))
    (check-equal? (ev st '((page editor) text-rows)) text-height)
    (check-equal? (ev st '((page editor) page-distance)) distance)
    (check-equal? (ev st '(((page page-up) point) line)) (- 3 distance)))
  (check-equal? (unbox calls) '()))

(test-case "complete rich fit reconstruction preserves inactive buffers and exact Text focus"
  (define-values (st calls) (state))
  (def! st 'ed `(AloemacsEditor new
    (Text indexed (List of "zero") "one" (List of "two" "third-long") 1)
    (Position new 3 6) #t 0 0
    (List of (UndoFrame new (Text from-string "old") (Position new 0 1) 2 3))
    (Option Some (Position new 1 1)) 17))
  (def! st 'rich '(AloemacsSession new
    (AloemacsBuffers new (List of (AloemacsBuffer new ed (Option None) 11))
      (AloemacsBuffer new ed (Option Some (Path new "/cwd/a")) 0)
      (List of (AloemacsBuffer new ed (Option Some (Path new "/inactive")) 22)))
    (s fs) "saved" #t "query" (Position new 1 2) #t #t (List of "ring" "older")
    (Option Some aloemacs-ctrl-x-keymap) (Option Some (AloemacsPrompt new "A:" "abc" 1))
    (Option Some "prior") (Option Some (AloemacsCommand FindFile))
    (AloemacsWindows new (AloemacsWindowTree Leaf (AloemacsView new 7 0 0 0 #t)) 7 80 24)))
  (define before (ev st 'rich))
  (def! st 'fit '(rich ensure-visible 3 4))
  (check-not-exn (lambda () (ev st '(check fit
    (AloemacsSession new
      (AloemacsBuffers new ((rich buffers) before)
        (AloemacsBuffer new
          (AloemacsEditor new (ed text) (ed point) (ed quit) 2 4 (ed history) (ed mark) 2)
          (rich path) ((rich current-buffer) id)) ((rich buffers) after))
      (rich fs) "saved" #t "query" (Position new 1 2) #t #t (List of "ring" "older")
      (Option Some aloemacs-ctrl-x-keymap) (Option Some (AloemacsPrompt new "A:" "abc" 1))
      (Option Some "prior") (Option Some (AloemacsCommand FindFile))
      (AloemacsWindows new (AloemacsWindowTree Leaf (AloemacsView new 7 0 2 4 #t)) 7 3 4))))))
  (check-equal? (ev st 'rich) before)
  (paint st 'fit 3 4 (frame "\r\nd-l" 2 3 3 4 "/cwd/a" "A:abc" 4 3) calls)
  (define fitted (ev st 'fit))
  (ev st '(fit frame 12 5))
  (check-equal? (ev st 'fit) fitted)
  (check-equal? (ev st '(fit ensure-visible 3 4)) fitted)
  (check-equal? (unbox calls) '()))

(test-case "global fallback with positive selection, locks and inactive shared origins"
  (define-values (st calls) (state))
  (def! st 's `(s with-editor ,(editor "zero\none\ntwo\nthree" 3 2 0 0)))
  (def! st 's '(AloemacsSession new (s buffers) (s fs) "" #f "" (s origin) #f #f
     (s kill-ring) (s pending) (s prompt) (s last-submission) (s waiting-command)
     (AloemacsWindows new
       (AloemacsWindowTree Right
         (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #t))
         (AloemacsWindowTree Leaf (AloemacsView new 1 0 99 3 #t))) 0 12 4)))
  (def! st 'small '(s ensure-visible 2 4))
  (check-equal? (ev st '((small editor) text-rows)) 2)
  (check-equal? (ev st '((small editor) scroll-row)) 2)
  (check-equal? (ev st '((small editor) scroll-col)) 1)
  (paint st 'small 2 4 (frame "wo\r\nhr" 2 2 2 4 "untitled" "") calls)
  (define inactive '(((s windows) tree) case (Right (a b) b) (else ((s windows) tree))))
  ;; Compare whole inactive leaf, including its lock and shared-buffer identity.
  (check-equal? (ev st '(((small windows) tree) case (Right (a b) b) (else ((small windows) tree))))
                (ev st inactive))
  (def! st 'grown '(small ensure-visible 9 4))
  ;; Completed 001: each tall leaf reserves its final row for its name.
  (check-equal? (ev st '((grown editor) text-rows)) 2)
  (paint st 'grown 9 4
    (string-append "\e[?25l\e[2J\e[Hwo  |    \r\nhree|    \r\nunti|unti"
                   "\e[4;1H\e[2;2H\e[?25h") calls)
  (check-equal? (ev st '(((grown windows) tree) case (Right (a b) b) (else ((grown windows) tree))))
                (ev st inactive)))

(test-case "next frames derive operation names without further Fs effects"
  (define-values (st calls) (state))
  (def! st 'saved '(s save-as-submitted "a"))
  (paint st 'saved 12 3 (frame "" 1 1 12 3 "/cwd/a" "saved: /cwd/a") calls)
  (def! st 'visited '((s visit (Path new "b")) case (None () s) (Some (v) v)))
  (paint st 'visited 12 3 (frame "bee" 1 1 12 3 "/cwd/b" "") calls)
  (def! st 'found '(s find-file-submitted "b"))
  (paint st 'found 12 3 (frame "bee" 1 1 12 3 "/cwd/b" "") calls)
  (def! st 'selected '(found select-buffer-submitted "untitled"))
  (paint st 'selected 12 3 (frame "" 1 1 12 3 "untitled" "") calls)
  (def! st 'switched '(selected switch-buffer))
  (paint st 'switched 12 3 (frame "bee" 1 1 12 3 "/cwd/b" "") calls)
  (def! st 'killed '(switched kill-buffer))
  (paint st 'killed 12 3 (frame "" 1 1 12 3 "untitled" "") calls)
  (def! st 'single '(visited kill-buffer))
  (paint st 'single 12 3 (frame "" 1 1 12 3 "untitled" "") calls)
  (def! st 'refused '(found find-file-submitted "dir"))
  (paint st 'refused 12 3 (frame "bee" 1 1 12 3 "/cwd/b" "failed: /cwd/b") calls)
  (check-equal? (filter (lambda (c) (memq (car c) '(read write))) (unbox calls))
                '((write "/cwd/a" "") (read "/cwd/b") (read "/cwd/b"))))

(test-case "production runner fits, writes once, resizes, saves, prompts and quits"
  (define sizes '((12 4) (12 4) (12 2) (12 4) (12 4) (12 4)))
  (define keys '("down" "save" "ctrl-x" "find" "escape" "escape"))
  (define frames
    (list (frame "zero\r\none" 1 1 12 4 "/cwd/a" "")
          (frame "zero\r\none" 2 1 12 4 "/cwd/a" "")
          (frame "one" 1 1 12 2 "/cwd/a" "saved: /cwd/a")
          (frame "one\r\ntwo" 1 1 12 4 "/cwd/a" "")
          (frame "one\r\ntwo" 1 1 12 4 "/cwd/a" "Find file: " 4 12)
          (frame "one\r\ntwo" 1 1 12 4 "/cwd/a" "")))
  (define events '())
  (define (record! x) (set! events (append events (list x))))
  (define dimensions 0)
  (define remaining keys)
  (define out (make-output-port 'mode-line always-evt
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
  (check-equal? (filter (lambda (c) (memq (car c) '(read write))) (unbox calls))
                '((read "/cwd/a") (write "/cwd/a" "zero\none\ntwo\nthree"))))
