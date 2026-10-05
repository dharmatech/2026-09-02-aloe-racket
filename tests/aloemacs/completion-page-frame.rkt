#lang racket/base

(require racket/list racket/port racket/runtime-path racket/string rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt" "../../host/racket/aloemacs-run.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (type st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define no-path '(if #t (Option None) (Option Some (Path new ""))))
(define no-prompt '(if #t (Option None)
                       (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0))))
(define history '(List of (UndoFrame new (Text from-string "undo") (Position new 0 1) 2 3)))
(define mark '(Option Some (Position new 1 1)))
(define (indexed lines [focus 0])
  `(Text indexed (List of ,@(reverse (take lines focus))) ,(list-ref lines focus)
     (List of ,@(drop lines (add1 focus))) ,focus))
(define (editor lines [line 0] [col 0] [top 0] [left 0] [height 17] [quit #f] [focus 0])
  `(AloemacsEditor new ,(indexed lines focus) (Position new ,line ,col)
     ,quit ,top ,left ,history ,mark ,height))
(define (buffer id ed [path #f])
  `(AloemacsBuffer new ,ed ,(if path `(Option Some (Path new ,path)) no-path) ,id))
(define (zipper bs [focus 0])
  `(AloemacsBuffers new (List of ,@(reverse (take bs focus))) ,(list-ref bs focus)
     (List of ,@(drop bs (add1 focus)))))
(define (leaf id [bid 41] [top 0] [left 0] [lock #f])
  `(AloemacsWindowTree Leaf (AloemacsView new ,id ,bid ,top ,left ,lock)))
(define (right a b) `(AloemacsWindowTree Right ,a ,b))
(define (below a b) `(AloemacsWindowTree Below ,a ,b))
(define (windows tree selected [w 9] [h 8]) `(AloemacsWindows new ,tree ,selected ,w ,h))
(define (prepared lines [text "x"] [col 1] [label "P:"] [note ""]
                  [matches display-names] [start 0])
  `(Option Some (AloemacsPrompt new ,label ,text ,col ,note
     (List of ,@lines) (List of ,@matches) ,start)))
(define (session bs tree [selected 7] [lines first-page] [start 0])
  `(AloemacsSession new ,bs (base fs) "saved" #f "old query" (Position new 1 2)
     #t #t (List of "ring" "older") (base pending) ,(prepared lines "x" 1 "P:" "" display-names start)
     (Option Some "previous") (Option Some (AloemacsCommand FindFile))
     ,(windows tree selected)))
(define (rebuild s #:buffers [bs `(,s buffers)] #:windows [ws `(,s windows)]
                 #:prompt [p `(,s prompt)] #:waiting [waiting `(,s waiting-command)]
                 #:submission [submission `(,s last-submission)] #:echo [echo `(,s echo)]
                 #:pending [pending `(,s pending)] #:searching [searching `(,s searching)]
                 #:query [query `(,s query)] #:wrapped [wrapped `(,s wrapped)]
                 #:failing [failing `(,s failing)])
  `(AloemacsSession new ,bs (,s fs) ,echo ,searching ,query (,s origin)
     ,wrapped ,failing (,s kill-ring) ,pending ,p ,submission ,waiting ,ws))

;; Ordered, changeable directory names; every Fs send remains observable.
(define default-listing '(("alpha.txt" file) ("alpine.txt" file) ("dir" directory)
                          ("beta.txt" file) ("bravo.txt" file)))
(define (counted-fs [host-name 'FsHost] [listing default-listing])
  (define names (box (map car listing)))
  (define disk (make-fs-double "/cwd"
    (for/hash ([entry (in-list (cons '("" directory) listing))])
      (values (if (equal? (car entry) "") "/cwd" (string-append "/cwd/" (car entry)))
              (cadr entry)))
    (for/hash ([entry (in-list listing)] #:when (eq? (cadr entry) 'file))
      (values (string-append "/cwd/" (car entry)) "disk contents"))))
  (define calls (box '()))
  (define (forward selector args)
    (set-box! calls (append (unbox calls) (list (cons selector args))))
    (define result (host-receiver-send disk selector args))
    (if (eq? selector 'names) (unbox names) result))
  (define interface
    (make-host-interface host-name
      (for/list ([m (in-list (host-interface-methods fs-interface))])
        (define selector (host-method-selector m))
        (define params (host-method-parameter-types m))
        (make-host-method selector params (host-method-return-type m)
          (case (length params)
            [(0) (lambda (_) (forward selector '()))]
            [(1) (lambda (_ a) (forward selector (list a)))]
            [(2) (lambda (_ a b) (forward selector (list a b)))])))))
  (values (make-host-receiver interface #f) calls names))
(define (state [host-name 'FsHost] [listing default-listing])
  (define st (make-driver))
  (define-values (host calls names) (counted-fs host-name listing))
  (driver-inject-host! st 'fs-host host)
  (ev st `(load ,(path->string main-path)))
  (def! st 'base 'aloemacs-editor)
  (values st calls names))
(define (effects calls selector)
  (filter (lambda (c) (eq? (car c) selector)) (unbox calls)))

;; Independent fixture arithmetic and ANSI composition, with literal witnesses
;; below. These helpers never send to product geometry or frame methods.
(define (clip s w) (substring s 0 (min w (string-length s))))
(define (safe s)
  (list->string (for/list ([c (in-string s)])
    (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (mode name w)
  (define label (clip (string-append name " ") w))
  (safe (string-append label (make-string (- w (string-length label)) #\-))))
(define (count-rows lines h) (if (< h 2) 0 (min (length lines) (max 0 (- h 2)))))
(define (root-height lines h) (if (< h 2) h (- h 1 (count-rows lines h))))
(define (text-height h) (if (>= h 2) (sub1 h) h))
(define (cursor row col) (format "\e[~a;~aH" row col))
(define (list-suffix lines w h)
  (define root (root-height lines h))
  (apply string-append
    (for/list ([line (in-list (take lines (count-rows lines h)))] [j (in-naturals 1)])
      (string-append (cursor (+ root j) 1) (safe (clip line w))))))
(define (text-cells lines w h top left)
  (for/list ([i (in-range top (+ top h))])
    (define row (if (< i (length lines)) (list-ref lines i) ""))
    (safe (clip (substring row (min left (string-length row))) w))))
(define (leaf-cells lines w h top left name)
  (append (for/list ([row (in-list (text-cells lines w (text-height h) top left))])
            (string-append row (make-string (- w (string-length row)) #\space)))
          (if (>= h 2) (list (mode name w)) '())))
(define (side a b) (map (lambda (l r) (string-append l "|" r)) a b))
(define (single body text-row text-col w h name echo lines final-row final-col)
  (string-append "\e[?25l\e[2J\e[H" body (cursor text-row text-col) "\e[?25h"
    (if (< h 2) ""
        (string-append "\e[?25l"
          (if (>= (root-height lines h) 2)
              (string-append (cursor (root-height lines h) 1) (mode name w)) "")
          (list-suffix lines w h) (cursor h 1) (safe (clip echo w))
          (cursor final-row final-col) "\e[?25h"))))
(define (multi rows w h echo lines final-row final-col)
  (string-append "\e[?25l\e[2J\e[H" (string-join rows "\r\n")
    (list-suffix lines w h)
    (if (>= h 2) (string-append (cursor h 1) (safe (clip echo w))) "")
    (cursor final-row final-col) "\e[?25h"))
(define (paint st s w h expected calls)
  (define before (ev st s))
  (define snapshot (unbox calls))
  (for ([i '(1 2)]) (check-equal? (ev st `(,s frame ,w ,h)) expected))
  (check-equal? (ev st s) before)
  (check-equal? (unbox calls) snapshot))

(define display-names
  '("a01/" "a02\nLF" "a03\rCR" "a04\tTab" "a05\eESC" "a06\u007fDEL" "a07"
    "a08" "a09" "a10" "a11" "a12" "a13" "a14" "a15" "a16" "a17" "a18"))
(define first-page '("a01/" "a02\nLF" "a03\rCR" "a04\tTab" "a05\eESC" "a06\u007fDEL" "a07" "...(+11)"))
(define middle-page '("a08" "a09" "a10" "a11" "a12" "a13" "a14" "...(+11)"))
(define tail-page '("a15" "a16" "a17" "a18" "...(+14)"))
(define a-lines '("abcdef" "ghijkl" "mnopqr" "stuvwx" "yz0123" "last"))

(test-case "complete cached page frames at all heights and widths preserve raw snapshot and cursor"
  (define-values (st calls names) (state))
  (def! st 's (session (zipper (list (buffer 41 (editor '("body"))))) (leaf 7)))
  (def! st 'middle '(s handle-key "page-down"))
  (def! st 'tail '(middle handle-key "page-down"))
  (for ([s '(s middle tail)] [start '(0 7 14)] [lines (list first-page middle-page tail-page)])
    (same st `(,s prompt) (prepared lines "x" 1 "P:" "" display-names start))
    (for* ([w '(1 3 6 9 40)] [h '(1 2 5 10 12)])
      (define root (root-height lines h))
      (define body (string-join (text-cells '("body") w (text-height root) 0 0) "\r\n"))
      (same st `(,s root-rect ,w ,h) `(AloemacsWindowRect new 0 0 ,w ,root))
      (check-equal? (ev st `(,s completion-row-count ,h)) (count-rows lines h))
      (paint st s w h (single body 1 1 w h "untitled" "P:x" lines
        (if (< h 2) 1 h) (if (< h 2) 1 (min w 4))) calls)))
  ;; Literal complete goldens guard the independent frame builder as well.
  (paint st 'middle 9 12
    "\e[?25l\e[2J\e[Hbody\r\n\e[1;1H\e[?25h\e[?25l\e[3;1Huntitled \e[4;1Ha08\e[5;1Ha09\e[6;1Ha10\e[7;1Ha11\e[8;1Ha12\e[9;1Ha13\e[10;1Ha14\e[11;1H...(+11)\e[12;1HP:x\e[12;4H\e[?25h" calls)
  (paint st 'tail 9 5
    "\e[?25l\e[2J\e[Hbody\e[1;1H\e[?25h\e[?25l\e[2;1Ha15\e[3;1Ha16\e[4;1Ha17\e[5;1HP:x\e[5;4H\e[?25h" calls)
  (paint st 's 1 10
    "\e[?25l\e[2J\e[Hb\e[1;1H\e[?25h\e[?25l\e[2;1Ha\e[3;1Ha\e[4;1Ha\e[5;1Ha\e[6;1Ha\e[7;1Ha\e[8;1Ha\e[9;1H.\e[10;1HP\e[10;1H\e[?25h" calls)
  ;; Controls after the clipping boundary do not contribute extra spaces.
  (paint st 's 3 5
    "\e[?25l\e[2J\e[Hbod\e[1;1H\e[?25h\e[?25l\e[2;1Ha01\e[3;1Ha02\e[4;1Ha03\e[5;1HP:x\e[5;3H\e[?25h" calls)
  (check-equal? (unbox calls) '()))

(test-case "fit-before-frame preserves whole prompt, tail returns rows, clearing keeps minimal origins"
  (define-values (st calls names) (state))
  (define rows (for/list ([i (in-range 12)]) (format "abcdef~a" i)))
  (def! st 'a (buffer 41 (editor rows 4 5 0 0 17 #f 2) "/a"))
  (def! st 's (session (zipper '(a)) (leaf 7)))
  (def! st 'fit '(s ensure-visible 9 12))
  (same st '(fit prompt) '(s prompt))
  (check-equal? (ev st '((fit editor) text-rows)) 2)
  (check-equal? (ev st '((fit editor) scroll-row)) 3)
  (same st '(fit ensure-visible 9 12) 'fit)
  (def! st 'middle '(fit handle-key "page-down"))
  (same st '(middle editor) '(fit editor))
  (def! st 'tail '(middle handle-key "page-down"))
  (same st '(tail windows) '(middle windows))
  (def! st 'grown '(tail ensure-visible 9 12))
  (same st '(grown prompt) '(tail prompt))
  (check-equal? (ev st '((grown editor) text-rows)) 5)
  (check-equal? (ev st '((grown editor) scroll-row)) 3)
  (paint st 'grown 9 12
    (single "abcdef3\r\nabcdef4\r\nabcdef5\r\nabcdef6\r\nabcdef7" 2 6
      9 12 "/a" "P:x" tail-page 12 4) calls)
  (def! st 'cleared '(grown with-active-prompt
    ((grown prompt) case (Some (p) (p clear-completion))
                         (None () (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))))
  (def! st 'clear-fit '(cleared ensure-visible 9 12))
  (check-equal? (ev st '((clear-fit editor) text-rows)) 10)
  (check-equal? (ev st '((clear-fit editor) scroll-row)) 3)
  (same st '(clear-fit prompt) (prepared '() "x" 1 "P:" "" '() 0))
  (paint st 'clear-fit 9 12
    (single "abcdef3\r\nabcdef4\r\nabcdef5\r\nabcdef6\r\nabcdef7\r\nabcdef8\r\nabcdef9\r\nabcdef10\r\nabcdef11\r\n"
      2 6 9 12 "/a" "P:x" '() 12 4) calls)
  (check-equal? (unbox calls) '()))

(test-case "visible shared splits and list-induced global fallback retain modes, origins and locks"
  (define-values (st calls names) (state))
  (def! st 'a (buffer 41 (editor a-lines 3 2 0 0 17 #f 2) "/a"))
  (define l (leaf 7 41 0 0 #t))
  (define r (leaf 3 41 3 1 #t))
  (for ([tree (list (right l r) (below l r))])
    (def! st 's (session (zipper '(a)) tree))
    (def! st 'tail '((s handle-key "page-down") handle-key "page-down"))
    (same st '(tail windows) '(s windows))
    (for ([source '(s tail)] [lines (list first-page tail-page)])
      (define root (root-height lines 12))
      (define split-rows
        (if (equal? tree (right l r))
            (side (leaf-cells a-lines 4 root 0 0 "/a")
                  (leaf-cells a-lines 4 root 3 1 "/a"))
            (let* ([early (quotient root 2)] [late (- root early 1)])
              (append (leaf-cells a-lines 9 early 0 0 "/a") '("---------")
                      (leaf-cells a-lines 9 late 3 1 "/a")))))
      (paint st source 9 12 (multi split-rows 9 12 "P:x" lines 12 4) calls)
      (def! st 'fitted `(,source ensure-visible 9 12))
      (same st '(fitted prompt) `(,source prompt))
      (same st '((fitted windows) tree)
        (if (equal? tree (right l r)) (right (leaf 7 41 (if (eq? source 's) 2 0) 0 #t) r)
            (below (leaf 7 41 (if (eq? source 's) 3 2) 0 #t) r)))))
  ;; A positive selected leaf cannot rescue a zero-height leaf elsewhere.
  (define tree (right l (below r (leaf 55 41 2 1 #t))))
  (def! st 's (session (zipper '(a)) tree))
  (same st '(s root-rect 9 11) '(AloemacsWindowRect new 0 0 9 2))
  (same st '(((s windows) tree) rect-for 7 (AloemacsWindowRect new 0 0 9 2))
    '(Option Some (AloemacsWindowRect new 0 0 4 2)))
  (check-false (ev st '(((s windows) tree) positive-layout? (s root-rect 9 11))))
  (same st '(s fit-rect 9 11) '(AloemacsWindowRect new 0 0 9 2))
  (def! st 'fitted '(s ensure-visible 9 11))
  (check-equal? (ev st '((fitted editor) scroll-row)) 3)
  (check-equal? (ev st '((fitted editor) text-rows)) 1)
  (same st '(fitted prompt) '(s prompt))
  (paint st 'fitted 9 11 (single "stuvwx" 1 3 9 11 "/a" "P:x" first-page 11 4) calls)
  (def! st 'tail '((fitted handle-key "page-down") handle-key "page-down"))
  (def! st 'tail-fit '(tail ensure-visible 9 11))
  (same st '(tail-fit prompt) '(tail prompt))
  (same st '(tail-fit fit-rect 9 11) '(AloemacsWindowRect new 0 0 4 5))
  (check-equal? (unbox calls) '()))

(test-case "unchanged production runner: page both ways, resize, refresh, typed Return, cancel and quit"
  (define raw '("pz" "pa" "pm" "pb" "py" "pc" "px" "pd" "pw" "pe" "pv" "pf" "pu" "pg" "pt" "ph" "ps" "pi"))
  (define first '("pz" "pa" "pm" "pb" "py" "pc" "px" "...(+11)"))
  (define middle '("pd" "pw" "pe" "pv" "pf" "pu" "pg" "...(+11)"))
  (define tail '("pt" "ph" "ps" "pi" "...(+14)"))
  (define fresh '("pi" "pa" "pt" "ph" "pg" "pu" "pf" "...(+2)"))
  (define-values (host calls names) (counted-fs 'RunnerPageFs
    (for/list ([n raw]) (list n 'file))))
  ;; Each step is the frame BEFORE its key: height, body, text cursor,
  ;; prepared lines, prompt echo, prompt cursor, and current name.
  ;; End-of-buffer point makes first-list fitting and the later shrink visible:
  ;; full root -> "four/five" -> "five"; growth retains the minimal origin.
  (define full-body "zero\r\none\r\ntwo\r\nthree\r\nfour\r\nfive\r\n\r\n\r\n\r\n")
  (define steps
    (list
      (list "buffer-end" 12 full-body 1 1 '() "" #f)
      (list "ctrl-x" 12 full-body 6 5 '() "" #f)
      (list "find" 12 full-body 6 5 '() "" #f)
      (list "p" 12 full-body 6 5 '() "Find file: /cwd/" 17)
      (list "tab" 12 full-body 6 5 '() "Find file: /cwd/p" 18)
      (list "page-down" 12 "four\r\nfive" 2 5 first "Find file: /cwd/p" 18)
      (list "page-down" 5 "five" 1 5 middle "Find file: /cwd/p" 18)
      (list "page-down" 12 "five\r\n\r\n\r\n\r\n" 1 5 tail "Find file: /cwd/p" 18)
      (list "page-up" 12 "five\r\n\r\n\r\n\r\n" 1 5 tail "Find file: /cwd/p" 18)
      (list "page-up" 12 "five\r\n" 1 5 middle "Find file: /cwd/p" 18)
      (list "left" 5 "five" 1 5 first "Find file: /cwd/p" 18)
      (list "right" 10 "five" 1 5 first "Find file: /cwd/p" 17)
      (list "page-down" 12 "five\r\n" 1 5 first "Find file: /cwd/p" 18)
      (list "tab" 12 "five\r\n" 1 5 middle "Find file: /cwd/p" 18)
      (list "page-down" 12 "five\r\n" 1 5 fresh "Find file: /cwd/p" 18)
      (list "return" 12 "five\r\n\r\n\r\n\r\n\r\n\r\n" 1 5 '("pv" "pe" "...(+7)") "Find file: /cwd/p" 18)
      (list "ctrl-x" 12 "\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n" 1 1 '() "" #f)
      (list "find" 12 "\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n" 1 1 '() "" #f)
      (list "p" 12 "\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n" 1 1 '() "Find file: /cwd/" 17)
      (list "tab" 12 "\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n" 1 1 '() "Find file: /cwd/p" 18)
      (list "escape" 12 "\r\n" 1 1 fresh "Find file: /cwd/p" 18)
      (list "escape" 12 "\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n" 1 1 '() "" #f)))
  (define i 0)
  (define frames '())
  (define events '())
  (define snapshots '())
  (define (record x) (set! events (append events (list x))))
  (define term (make-host-receiver
    (make-host-interface 'ScriptedPageTerm
      (list
        (make-host-method 'columns '() 'Int (lambda (_) (record 'columns) 30))
        (make-host-method 'rows '() 'Int (lambda (_) (record (list 'rows (cadr (list-ref steps i))))
                                                    (cadr (list-ref steps i))))
        (make-host-method 'write '(String) 'String (lambda (_ text)
          (record 'write) (set! frames (append frames (list text))) text))
        (make-host-method 'read-key '() 'String (lambda (_)
          (record 'read-key) (set! snapshots (append snapshots (list (unbox calls))))
          ;; Mutate after initial Tab; pages/resize still use all 18 cached names.
          (when (= i 5) (set-box! names '("pi" "pa" "pt" "ph" "pg" "pu" "pf" "pv" "pe")))
          (define key (car (list-ref steps i))) (set! i (add1 i)) key)))) #f))
  ;; Startup file gives a complete no-list frame and a bound current buffer.
  ;; The runner prefill uses its parent rather than another ambient query.
  (define initial-host
    (make-host-receiver
      (make-host-interface 'RunnerStartupFs
        (for/list ([m (host-interface-methods fs-interface)])
          (define selector (host-method-selector m))
          (define params (host-method-parameter-types m))
          (define (forward args)
            (cond [(and (eq? selector 'kind) (equal? args '("/cwd/start")))
                   (set-box! calls (append (unbox calls) (list (cons selector args)))) "file"]
                  [(and (eq? selector 'read) (equal? args '("/cwd/start")))
                   (set-box! calls (append (unbox calls) (list (cons selector args)))) "zero\none\ntwo\nthree\nfour\nfive"]
                  [else (host-receiver-send host selector args)]))
          (make-host-method selector params (host-method-return-type m)
            (case (length params)
              [(0) (lambda (_) (forward '()))]
              [(1) (lambda (_ a) (forward (list a)))]
              [(2) (lambda (_ a b) (forward (list a b)))])))) #f))
  (run-aloemacs-with-hosts term initial-host "/cwd/start")
  (define expected (for/list ([step steps] [j (in-naturals)])
    (define h (cadr step))
    (define col (list-ref step 7))
    (single (list-ref step 2) (list-ref step 3) (list-ref step 4) 30 h
      (if (< j 16) "/cwd/start" "/cwd/p") (list-ref step 6) (list-ref step 5)
      (if col h (list-ref step 3)) (or col (list-ref step 4)))))
  (for ([actual frames] [gold expected] [j (in-naturals)])
    (check-equal? actual gold (format "drawn frame ~a" j)))
  (check-equal? i (length steps))
  (check-equal? events
    (append-map (lambda (s) (list 'columns (list 'rows (cadr s)) 'write 'read-key)) steps))
  (check-equal? (effects calls 'names) (make-list 3 '(names "/cwd")))
  (check-equal? (effects calls 'read) '((read "/cwd/start")))
  (check-equal? (effects calls 'write) '())
  (check-true (string-contains? (list-ref frames 7) "\e[10;1Hpi"))
  ;; Complete Fs snapshots, not only directory-read counts, remain identical.
  (for ([j (in-range 1 (length steps))] #:unless (member j '(3 5 14 16 18 20)))
    (check-equal? (list-ref snapshots j) (list-ref snapshots (sub1 j)))))
