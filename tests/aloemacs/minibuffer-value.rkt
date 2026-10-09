#lang racket/base

(require racket/string racket/list racket/port racket/runtime-path rackunit
         "../../aloe/driver.rkt" "../../aloe/env.rkt" "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type? type-of type->datum type-environment-bound?)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new "/typed-none"))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define no-prompt '(if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0))))
(define no-submission '(if #t (Option None) (Option Some "")))
(define active '(Option Some (AloemacsPrompt new "Ask:\t " "ab\u001b[31mc" 3 "" (List empty) (List empty) 0)))
(define submitted '(Option Some "previous\tanswer"))
(define session-fields
  '(buffers fs echo searching query origin wrapped failing kill-ring pending
            prompt last-submission waiting-command windows))
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (type st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))
(define (loaded)
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  st)

;; Load with no capabilities; only then inject a counted in-memory Fs double.
(define (attach-fs! st #:fail [fail #f] #:vanish? [vanish? #f])
  (define inner
    (make-fs-double "/cwd"
      (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file
            "/cwd/dir" 'directory "/cwd/link" 'symlink "/cwd/pipe" "fifo")
      (hash "/cwd/a.txt" "\uFEFFλ\r\nb\n" "/cwd/b.txt" "disk b")))
  (define calls (box '()))
  (define probes 0)
  (define (forward selector args)
    (set-box! calls (cons (cons selector args) (unbox calls)))
    (when (eq? selector fail) (error 'minibuffer-test "host failure"))
    (when (eq? selector 'kind) (set! probes (add1 probes)))
    (if (and vanish? (eq? selector 'kind) (> probes 1)) "missing"
        (host-receiver-send inner selector args)))
  (define interface
    (make-host-interface 'FsHost
      (for/list ([method (in-list (host-interface-methods fs-interface))])
        (define selector (host-method-selector method))
        (define params (host-method-parameter-types method))
        (make-host-method selector params (host-method-return-type method)
          (case (length params)
            [(0) (lambda (state) (forward selector '()))]
            [(1) (lambda (state a) (forward selector (list a)))]
            [(2) (lambda (state a b) (forward selector (list a b)))])))))
  (driver-inject-host! st 'fs-host (make-host-receiver interface #f))
  calls)
(define (state #:fail [fail #f] #:vanish? [vanish? #f])
  (define st (loaded))
  (values st (attach-fs! st #:fail fail #:vanish? vanish?)))
(define (effects calls selector)
  (reverse (filter (lambda (call) (eq? (car call) selector)) (unbox calls))))
(define (editor contents [point '(Position new 0 0)] [cold? #f])
  `(AloemacsEditor new
     ,(if cold? `(Text from-string ,contents)
          `((Text from-string ,contents) indexed-value))
     ,point #f 0 0 (List empty) ,no-mark 0))
(define (buffer contents [path no-path] [id 0])
  `(AloemacsBuffer new ,(editor contents) ,path ,id))
(define (zipper order focus)
  `(AloemacsBuffers new (List of ,@(reverse (take order focus)))
     ,(list-ref order focus) (List of ,@(drop order (add1 focus)))))
(define (session buffers #:prompt [prompt active] #:submission [submission submitted]
                 #:pending [pending '(Option Some aloemacs-ctrl-x-keymap)])
  `(AloemacsSession new ,buffers (Fs new fs-host) "saved" #t "old query"
     (Position new 4 2) #t #t (List of "newest" "older") ,pending ,prompt ,submission
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer (,buffers current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 0 0))))

;; All expectations rebuild independently of production session helpers.
(define (rebuild s #:buffers [buffers `(,s buffers)] #:echo [echo `(,s echo)]
                 #:searching [searching `(,s searching)] #:query [query `(,s query)]
                 #:origin [origin `(,s origin)] #:wrapped [wrapped `(,s wrapped)]
                 #:failing [failing `(,s failing)] #:ring [ring `(,s kill-ring)]
                 #:pending [pending `(,s pending)] #:prompt [prompt `(,s prompt)]
                 #:submission [submission `(,s last-submission)]
                 #:columns [columns `((,s windows) columns)]
                 #:rows [rows `((,s windows) rows)])
  `(AloemacsSession new ,buffers (,s fs) ,echo ,searching ,query ,origin
     ,wrapped ,failing ,ring ,pending ,prompt ,submission
     (,s waiting-command)
     (let ((buffer (,buffers current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 ,columns ,rows))))
(define (replace-current s editor [path `(,s path)])
  `(AloemacsBuffers new ((,s buffers) before)
     (AloemacsBuffer new ,editor ,path ((,s current-buffer) id)) ((,s buffers) after)))
(define (reset s buffers #:visit? [visit? #f])
  (rebuild s #:buffers buffers #:echo "" #:searching #f #:query ""
           #:origin '(Position new 0 0) #:wrapped #f #:failing #f
           #:ring (if visit? '(List empty) `(,s kill-ring)) #:pending no-pending
           #:prompt (if visit? no-prompt `(,s prompt))))
(define (same-session st actual expected)
  (def! st 'comparison-actual actual)
  (def! st 'comparison-expected expected)
  (same st 'comparison-actual 'comparison-expected)
  (for ([field (in-list (append session-fields '(current-buffer editor path text point quit)))])
    (same st `(comparison-actual ,field) `(comparison-expected ,field))))
(define (preserved st name)
  (same st `(,name prompt) active)
  (same st `(,name last-submission) submitted))
(define (rich! st)
  (def! st 'a (buffer "neighbor a" '(Option Some (Path new "/cwd/a.txt")) 0))
  (def! st 'rich-editor
    '(AloemacsEditor new
       (Text indexed (List of "second" "first") "third-long"
                     (List of "fourth" "fifth") 2)
       (Position new 2 4) #f 2 3
       (List of (UndoFrame new (Text from-string "old b") (Position new 0 2) 1 2))
       (Option Some (Position new 1 1)) 4))
  (def! st 'b '(AloemacsBuffer new rich-editor (Option Some (Path new "/cwd/b.txt")) 1))
  (def! st 'c (buffer "neighbor c" no-path 2))
  (def! st 'source (session (zipper '(a b c) 1))))
(define (editor-frame body row column)
  (string-append "\u001b[?25l\u001b[2J\u001b[H" body
                 (format "\u001b[~a;~aH\u001b[?25h" row column)))
;; Independent name and text allocation from the supplied fixture and size.
(define (mode-row name width)
  (define label (substring (string-append name " ") 0
                          (min width (add1 (string-length name)))))
  (list->string
    (for/list ([c (in-string (string-append label
                              (make-string (- width (string-length label)) #\-)))])
      (if (or (< (char->integer c) 32) (= (char->integer c) 127)) #\space c))))
(define (text-body body rows)
  (define lines (string-split body "\r\n" #:trim? #f))
  (string-join (take lines (min (length lines) (if (>= rows 3) (- rows 2) 1))) "\r\n"))
;; One-view name rows are the LIGHT bar; an empty row stays empty.
(define LIGHT "\e[38;5;16;48;5;250m")
(define PLAIN "\e[0m")
(define (light row) (if (string=? row "") "" (string-append LIGHT row PLAIN)))
(define (frame body row column rows shown cursor-row cursor-column #:name [name "untitled"] #:width [width 0])
  (string-append "\e[?25l\e[2J\e[H"
    (if rows (text-body body rows) body)
    (format "\e[~a;~aH\e[?25h" row column)
    (if (and rows (>= rows 2))
        (string-append "\e[?25l"
          (if (>= rows 3) (format "\e[~a;1H~a" (sub1 rows) (light (mode-row name width))) "")
          (format "\e[~a;1H~a\e[~a;~aH\e[?25h" rows shown cursor-row cursor-column)) "")))

(test-case "exact prompt declaration, signatures, session fields, and class order"
  (define datums (call-with-input-file file-path (lambda (in) (port->list read in))))
  (check-equal? (take datums 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) datums))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand
      (AloemacsKeymap B) AloemacsBinding AloemacsSearchScan (AloemacsSession H)))
  (define prompt (findf (lambda (d) (eq? (cadr d) 'AloemacsPrompt)) classes))
  (check-not-false prompt)
  (check-equal? (caddr prompt) '(fields (label String) (text String) (column Int)
       (completion-note String) (completion-lines (List String))
       (completion-matches (List String)) (completion-start Int)))
  (check-equal? (map (lambda (m) (drop-right m 1)) (cdr (cadddr prompt)))
    '((row () String) (screen-column (columns Int) Int)
      (with-completion (text String) (note String) (lines (List String)) AloemacsPrompt)
      (with-completion-page (matches (List String)) (start Int) (lines (List String)) AloemacsPrompt)
      (clear-completion () AloemacsPrompt)
      (insert (character String) AloemacsPrompt)
      (backward-delete () AloemacsPrompt)
      (move-left () AloemacsPrompt) (move-right () AloemacsPrompt)
      (line-start () AloemacsPrompt) (line-end () AloemacsPrompt)))
  (define session (findf (lambda (d) (equal? (cadr d) '(AloemacsSession H))) classes))
  (check-equal? (caddr session)
    '(fields (buffers AloemacsBuffers) (fs (Fs H)) (echo String) (searching Bool)
             (query String) (origin Position) (wrapped Bool) (failing Bool)
             (kill-ring (List String)) (pending (Option (AloemacsKeymap AloemacsBinding)))
             (prompt (Option AloemacsPrompt)) (last-submission (Option String)) (waiting-command (Option AloemacsCommand)) (windows AloemacsWindows))))

(test-case "two fresh checked loads have no output, capability, or host effects"
  (for ([i (in-range 2)])
    (define out (open-output-string))
    (define err (open-output-string))
    (define st (parameterize ([current-output-port out] [current-error-port err]) (loaded)))
    (for ([name '(AloemacsPrompt AloemacsSession)])
      (check-true (env-bound? (driver-runtime-environment st) name))
      (check-true (type-environment-bound? (driver-type-environment st) name)))
    (for ([name '(fs-host term)])
      (check-false (env-bound? (driver-runtime-environment st) name))
      (check-false (type-environment-bound? (driver-type-environment st) name)))
    (check-equal? (get-output-string out) "")
    (check-equal? (get-output-string err) "")))

(test-case "checked prompt algebra, generated reads, arities, types, and immutable values"
  (define st (loaded))
  (def! st 'p '(AloemacsPrompt new "Ask: " "abcd" 2 "" (List empty) (List empty) 0))
  (define original (ev st 'p))
  (for ([entry '((p AloemacsPrompt) ((p label) String) ((p text) String)
                 ((p column) Int) ((p row) String) ((p screen-column 12) Int))])
    (check-equal? (type st (car entry)) (cadr entry)))
  (check-equal? (ev st '(p label)) "Ask: ")
  (check-equal? (ev st '(p text)) "abcd")
  (check-equal? (ev st '(p column)) 2)
  (check-equal? (ev st '(p row)) "Ask: abcd")
  (for ([width '(12 7 1)] [column '(8 7 1)])
    (check-equal? (ev st `(p screen-column ,width)) column))
  (check-equal? (ev st '((AloemacsPrompt new "" "λβ" 1 "" (List empty) (List empty) 0) row)) "λβ")
  (check-equal? (ev st '((AloemacsPrompt new "" "λβ" 1 "" (List empty) (List empty) 0) screen-column 9)) 2)
  (check-equal? (ev st '((AloemacsPrompt new "a\t" "\r\u001b[31m" 0 "" (List empty) (List empty) 0) row)) "a\t\r\u001b[31m")
  ;; The generated constructor trusts callers; it adds no runtime validation.
  (check-equal? (ev st '((AloemacsPrompt new "" "\n" -1 "" (List empty) (List empty) 0) column)) -1)
  (for ([bad '((AloemacsPrompt new) (AloemacsPrompt new "a" "b")
               (AloemacsPrompt new "a" "b" 0 1) (AloemacsPrompt new 1 "b" 0 "" (List empty) (List empty) 0)
               (AloemacsPrompt new "a" 1 0 "" (List empty) (List empty) 0) (AloemacsPrompt new "a" "b" 0.0 "" (List empty) (List empty) 0)
               (p label 1) (p text 1) (p column 1) (p row 1)
               (p screen-column) (p screen-column 1 2) (p screen-column "12")
               (p screen-column 12.0) (1 row) ("x" screen-column 4)
               (AloemacsPrompt row))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st bad)) (format "reject ~s" bad)))
  (check-equal? (ev st 'p) original))

(test-case "six editing sends have exact checked types and reject bad arguments and arities"
  (define st (loaded))
  (def! st 'p '(AloemacsPrompt new "Ask: " "abc" 1 "" (List empty) (List empty) 0))
  (for ([send '((p insert "x") (p backward-delete) (p move-left) (p move-right)
                (p line-start) (p line-end))])
    (check-equal? (type st send) 'AloemacsPrompt)
    (check-not-exn (lambda () (ev st send))))
  (for ([bad '((p insert) (p insert "x" "y") (p insert 1) (p insert #f)
               (p insert (Option Some "x")) (AloemacsPrompt insert "x")
               (1 insert "x") ("s" insert "x"))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st bad)) (format "reject ~s" bad)))
  (for* ([method '(backward-delete move-left move-right line-start line-end)]
         [bad (list `(p ,method 0) `(p ,method "x") `(p ,method 0 1)
                    `(1 ,method) `("x" ,method) `(AloemacsPrompt ,method))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st bad)) (format "reject ~s" bad))))

(test-case "prompt edit algebra has independent literal strings, columns, and immutable receivers"
  (define st (loaded))
  (define label "L\t\u001b: ")
  ;; Each row specifies the input and literal output, rather than deriving an
  ;; expectation from another editing send.
  (for ([row '(("abc" 0 (insert "X") "Xabc" 1)
               ("abc" 1 (insert "X") "aXbc" 2)
               ("abc" 3 (insert "X") "abcX" 4)
               ("" 0 (insert "λ") "λ" 1)
               ("λβ" 1 (insert "γ") "λγβ" 2)
               ("abc" 0 (backward-delete) "abc" 0)
               ("abc" 2 (backward-delete) "ac" 1)
               ("abc" 3 (backward-delete) "ab" 2)
               ("" 0 (backward-delete) "" 0)
               ("λβ" 1 (backward-delete) "β" 0)
               ("abc" 0 (move-left) "abc" 0)
               ("abc" 3 (move-left) "abc" 2)
               ("abc" 0 (move-right) "abc" 1)
               ("abc" 3 (move-right) "abc" 3)
               ("abc" 2 (line-start) "abc" 0)
               ("abc" 1 (line-end) "abc" 3)
               ("" 0 (move-left) "" 0)
               ("" 0 (move-right) "" 0)
               ("" 0 (line-start) "" 0)
               ("" 0 (line-end) "" 0)
               ("abc" 1 (insert "") "abc" 1)
               ("abc" 1 (insert "xy") "abc" 1)
               ("abc" 1 (insert "\n") "abc" 1)
               ("abc" 1 (insert "x\n") "abc" 1))])
    (def! st 'p `(AloemacsPrompt new ,label ,(car row) ,(cadr row) "" (List empty) (List empty) 0))
    (define original (ev st 'p))
    (def! st 'edited `(p ,@(list-ref row 2)))
    (same st 'edited `(AloemacsPrompt new ,label ,(list-ref row 3) ,(list-ref row 4) "" (List empty) (List empty) 0))
    (check-equal? (ev st '(edited label)) label)
    (check-equal? (ev st '(edited text)) (list-ref row 3))
    (check-equal? (ev st '(edited column)) (list-ref row 4))
    (check-false (ev st '(((edited text) find "\n" 0) present?)))
    (check-true (ev st '((edited column) >= 0)))
    (check-true (ev st '((edited column) <= ((edited text) len))))
    (check-equal? (ev st 'p) original))
  (for ([character '(" " "\t" "\r" "\u001b" "\u0000" "\u007f" "\u0001" "λ")])
    (def! st 'p `(AloemacsPrompt new ,label "ab" 1 "" (List empty) (List empty) 0))
    (define original (ev st 'p))
    (def! st 'edited `(p insert ,character))
    (check-equal? (ev st '(edited text)) (string-append "a" character "b"))
    (check-equal? (ev st '(edited column)) 2)
    (check-equal? (ev st '(edited label)) label)
    (check-false (ev st '(((edited text) find "\n" 0) present?)))
    (check-equal? (ev st 'p) original)))

(test-case "fourteen-field constructor, pure Option reads, and lawful cold startup"
  (define-values (st calls) (state))
  (rich! st)
  (check-equal? (type st '(source prompt)) '(Option AloemacsPrompt))
  (check-equal? (type st '(source last-submission)) '(Option String))
  (check-equal? (type st 'source) '(AloemacsSession FsHost))
  (define fixture (session (zipper '(a b c) 1)))
  (for ([bad (list (drop-right fixture 2) (drop-right fixture 1)
                   (append fixture '(0))
                   (append (take fixture 12) (list '(Option Some "wrong") submitted)
                           (take-right fixture 2))
                   (append (take fixture 13) (list '(Option Some 1))
                           (take-right fixture 2))
                   '(source prompt 0) '(source last-submission 0)
                   '(1 prompt) '("x" last-submission))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st bad))))
  (for ([submission (list no-submission '(Option Some "") submitted)]
        [present? '(#f #t #t)])
    (def! st 's (rebuild 'source #:submission submission))
    (define original (ev st 's))
    (for ([i (in-range 2)])
      (same st '(s last-submission) submission)
      (check-equal? (ev st '((s last-submission) present?)) present?))
    (check-equal? (ev st 's) original))
  (same st '(source last-submission) submitted)
  (define startup (make-driver))
  (define startup-calls (attach-fs! startup))
  (ev startup `(load ,(path->string main-path)))
  (same-session startup 'aloemacs-editor
    `(AloemacsSession new
       ,(zipper (list `(AloemacsBuffer new ,(editor "" '(Position new 0 0) #t) ,no-path 0)) 0)
       (Fs new fs-host) "" #f "" (Position new 0 0) #f #f (List empty)
       ,no-pending ,no-prompt ,no-submission
       (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer (,(zipper (list `(AloemacsBuffer new ,(editor "" '(Position new 0 0) #t) ,no-path 0)) 0) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 0 0))))
  (check-false (ev startup '((aloemacs-editor prompt) present?)))
  (check-false (ev startup '((aloemacs-editor last-submission) present?)))
  (check-equal? (unbox startup-calls) '())
  (check-equal? (unbox calls) '()))

(test-case "every preserving rebuild, editor wrapper, and fit keeps both exact new fields"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'source))
  (def! st 'replacement '(rich-editor move-left))
  (for ([row
         (list
          (list '(source with-editor replacement)
                (rebuild 'source #:buffers (replace-current 'source 'replacement)))
          (list '(source with-kill-state replacement (List of "supplied"))
                (rebuild 'source #:buffers (replace-current 'source 'replacement)
                         #:echo "" #:ring '(List of "supplied")))
          (list '(source with-search replacement #f "new query" (Position new 1 2) #f #f)
                (rebuild 'source #:buffers (replace-current 'source 'replacement)
                         #:searching #f #:query "new query" #:origin '(Position new 1 2)
                         #:wrapped #f #:failing #f))
          (list '(source with-echo "failed") (rebuild 'source #:echo "failed"))
          (list '(source with-prefix aloemacs-global-keymap)
                (rebuild 'source #:echo "" #:pending '(Option Some aloemacs-global-keymap)))
          (list '(source clear-prefix) (rebuild 'source #:pending no-pending))
          (list '(source unchanged) 'source)
          (list '(source find)
                (rebuild 'source #:searching #t #:query "" #:origin '(source point)
                         #:wrapped #f #:failing #f))
          (list '(source end-search)
                (rebuild 'source #:searching #f #:query "" #:origin '(Position new 0 0)
                         #:wrapped #f #:failing #f))
          (list '(source set-mark)
                (rebuild 'source #:echo "" #:buffers
                  (replace-current 'source '(rich-editor with-mark (Option Some (source point)))))))])
    (def! st 'actual (car row))
    (same-session st 'actual (cadr row))
    (preserved st 'actual))
  (for ([op '((insert "!") (newline) (backward-delete) (move-left) (move-right)
              (move-up) (move-down) (line-start) (line-end) (page-up) (page-down)
              (buffer-start) (buffer-end) (undo) (request-quit))])
    (def! st 'actual `(source ,@op))
    (same-session st 'actual
      (rebuild 'source #:buffers (replace-current 'source `(rich-editor ,@op))))
    (preserved st 'actual))
  (for ([rows '(1 2 5)])
    (def! st 'actual `(source ensure-visible 3 ,rows))
    (same-session st 'actual
      (rebuild 'source #:columns 3 #:rows rows #:buffers
        (replace-current 'source `(rich-editor ensure-visible 3 ,(if (>= rows 3) (- rows 2) 1)))))
    (preserved st 'actual)
    (define before-frame (ev st 'actual))
    (ev st `(actual frame 3 ,rows))
    (ev st `(actual frame 3 ,rows))
    (check-equal? (ev st 'actual) before-frame))
  (check-equal? (ev st 'source) original)
  (check-equal? (unbox calls) '()))

(test-case "direct kill, kill-line, yank, and search helpers preserve prompt and submission"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'line-editor
    `(AloemacsEditor new ((Text from-string "abcd") indexed-value)
       (Position new 0 2) #f 1 2 (List empty) (Option Some (Position new 0 0)) 3))
  (def! st 'line (rebuild 'source #:buffers (replace-current 'source 'line-editor)))
  (for ([op '(kill kill-line)] [contents '("cd" "ab")] [column '(0 2)]
        [mark (list no-mark '(Option Some (Position new 0 0)))] [entry '("ab" "cd")])
    (def! st 'actual `(line ,op))
    (define expected-editor
      `(AloemacsEditor new ((Text from-string ,contents) indexed-value)
         (Position new 0 ,column) #f 1 2
         (List of (UndoFrame new (line text) (line point) 1 2)) ,mark 3))
    (same-session st 'actual
      (rebuild 'line #:echo "" #:buffers (replace-current 'line expected-editor)
               #:ring `((line kill-ring) cons ,entry)))
    (preserved st 'actual))
  (same-session st '(line yank)
    (rebuild 'line #:echo "" #:buffers
      (replace-current 'line '(line-editor insert "newest"))))
  (def! st 'hit '(source search-hit "third" (Position new 2 0) #f))
  (same-session st 'hit
    (rebuild 'source #:query "third" #:wrapped #f #:failing #f #:buffers
      (replace-current 'source '(rich-editor with-text-and-point (source text) (Position new 2 0)))))
  (preserved st 'hit)
  (def! st 'miss '(source search-miss "absent"))
  (same-session st 'miss
    (rebuild 'source #:query "absent" #:wrapped #f #:failing #t #:buffers
      (replace-current 'source
        '(rich-editor with-text-and-point
           (((source text) focus-at 4) case
             (None () (source text)) (Some (focused) focused))
           (source origin)))))
  (preserved st 'miss)
  (check-equal? (unbox calls) '()))

(test-case "both additions, positional switch, and every removal keep the active value"
  (define-values (st calls) (state))
  (rich! st)
  (for ([focus '(0 1 2)])
    (def! st 'source (session (zipper '(a b c) focus)))
    (define original (ev st 'source))
    (for ([path (list #f "./dir/../optional")])
      (define new-buffer (buffer "new\ntext" (if path `(Option Some (Path new ,path)) no-path) 3))
      (def! st 'actual `(source add-buffer "new\ntext" ,@(if path `((Path new ,path)) '())))
      (same-session st 'actual
        (reset 'source (zipper (append (take '(a b c) (add1 focus)) (list new-buffer)
                                      (drop '(a b c) (add1 focus))) (add1 focus))))
      (preserved st 'actual))
    (same-session st '(source switch-buffer)
      (reset 'source (zipper '(a b c) (modulo (add1 focus) 3))))
    (define remaining (append (take '(a b c) focus) (drop '(a b c) (add1 focus))))
    (same-session st '(source kill-buffer) (reset 'source (zipper remaining (min focus 1))))
    (check-equal? (ev st 'source) original))
  (def! st 'singleton (session (zipper '(b) 0)))
  (same-session st '(singleton switch-buffer) (reset 'singleton (zipper '(b) 0)))
  (same-session st '(singleton kill-buffer)
    (reset 'singleton (zipper (list (buffer "" no-path 1)) 0)))
  (check-equal? (unbox calls) '()))

(test-case "direct save writes buffer contents only and preserves the full active session"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'source))
  (for ([i (in-range 2)])
    (def! st 'saved '(source save))
    (check-true (ev st '(saved present?)))
    (same-session st '(saved case (None () source) (Some (s) s)) 'source))
  (check-equal? (effects calls 'write)
    '((write "/cwd/b.txt" "first\nsecond\nthird-long\nfourth\nfifth")
      (write "/cwd/b.txt" "first\nsecond\nthird-long\nfourth\nfifth")))
  (check-equal? (effects calls 'read) '())
  (check-equal? (ev st 'source) original)
  (def! st 'saved-key '(source save-key))
  (same-session st 'saved-key (rebuild 'source #:echo "saved"))
  (for ([path (list no-path '(Option Some (Path new "/cwd/dir"))
                   '(Option Some (Path new "/cwd/link")) '(Option Some (Path new "/cwd/pipe"))
                   '(Option Some (Path new "/cwd/absent/file")))])
    (def! st 'refused (rebuild 'source #:buffers (replace-current 'source 'rich-editor path)))
    (define before (ev st 'refused))
    (set-box! calls '())
    (check-false (ev st '((refused save) present?)))
    (check-equal? (effects calls 'write) '())
    (check-equal? (ev st 'refused) before)
    (preserved st 'refused))
  (define-values (failing failures) (state #:fail 'write))
  (rich! failing)
  (define before (ev failing 'source))
  (check-exn exn:fail:aloe-host? (lambda () (ev failing '(source save))))
  (check-equal? (length (effects failures 'write)) 1)
  (check-equal? (ev failing 'source) before))

(test-case "successful visited and regular/missing visit clear only the prompt among new fields"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'source))
  (def! st 'direct '(source visited "direct\ntext" (Path new "../direct")))
  (same-session st 'direct
    (reset 'source (replace-current 'source (editor "direct\ntext")
                    '(Option Some (Path new "../direct"))) #:visit? #t))
  (check-equal? (unbox calls) '())
  (for ([path '("./dir/../a.txt" "missing.txt")]
        [resolved '("/cwd/a.txt" "/cwd/missing.txt")] [contents '("\uFEFFλ\r\nb\n" "")])
    (set-box! calls '())
    (def! st 'option `(source visit (Path new ,path)))
    (check-true (ev st '(option present?)))
    (def! st 'actual '(option case (None () source) (Some (s) s)))
    (same-session st 'actual
      (reset 'source (replace-current 'source (editor contents)
                      `(Option Some (Path new ,resolved))) #:visit? #t))
    (same st '(actual prompt) no-prompt)
    (same st '(actual last-submission) submitted)
    (check-equal? (effects calls 'kind)
      (if (equal? contents "") '((kind "/cwd/missing.txt"))
          '((kind "/cwd/a.txt") (kind "/cwd/a.txt"))))
    (check-equal? (effects calls 'read)
      (if (equal? contents "") '() '((read "/cwd/a.txt"))))
    (check-equal? (effects calls 'write) '())
    (check-equal? (ev st 'source) original)))

(test-case "all refused visits and raised failures retain the entire source session"
  (for ([path '("dir" "link" "pipe")])
    (define-values (st calls) (state))
    (rich! st)
    (define before (ev st 'source))
    (check-false (ev st `((source visit (Path new ,path)) present?)))
    (check-equal? (effects calls 'kind) `((kind ,(string-append "/cwd/" path))))
    (check-equal? (effects calls 'read) '())
    (check-equal? (effects calls 'write) '())
    (preserved st 'source)
    (check-equal? (ev st 'source) before))
  (define-values (vanished calls) (state #:vanish? #t))
  (rich! vanished)
  (define original (ev vanished 'source))
  (check-false (ev vanished '((source visit (Path new "a.txt")) present?)))
  (check-equal? (effects calls 'kind) '((kind "/cwd/a.txt") (kind "/cwd/a.txt")))
  (check-equal? (effects calls 'read) '())
  (check-equal? (effects calls 'write) '())
  (check-equal? (ev vanished 'source) original)
  (for ([selector '(resolve kind read)])
    (define-values (failing calls) (state #:fail selector))
    (rich! failing)
    (define before (ev failing 'source))
    (check-exn exn:fail:aloe-host? (lambda () (ev failing '(source visit (Path new "a.txt")))))
    (check-equal? (ev failing 'source) before)
    (check-equal? (effects calls 'write) '())))

(test-case "full active frames clamp insertion slots and retain exact editor prefixes"
  (define-values (st calls) (state))
  (def! st 'base (session (zipper (list (buffer "a\u001bb\nsecond")) 0) #:pending no-pending))
  (def! st 'base (rebuild 'base #:buffers
                  (replace-current 'base (editor "a\u001bb\nsecond" '(Position new 0 1)))))
  ;; Shown strings and cursor addresses are literal independent expectations.
  (for ([row '(("Ask: " "abcd" 0 12 "Ask: abcd" 6 "a b\r\nsecond")
               ("Ask: " "abcd" 2 12 "Ask: abcd" 8 "a b\r\nsecond")
               ("Ask: " "abcd" 4 12 "Ask: abcd" 10 "a b\r\nsecond")
               ("Ask: " "abcd" 2 7 "Ask: ab" 7 "a b\r\nsecond")
               ("Ask: " "ab" 2 12 "Ask: ab" 8 "a b\r\nsecond")
               ("long-label" "x" 0 4 "long" 4 "a b\r\nseco")
               ("four" "x" 0 4 "four" 4 "a b\r\nseco")
               ("" "abcd" 0 12 "abcd" 1 "a b\r\nsecond")
               ("" "abcd" 2 12 "abcd" 3 "a b\r\nsecond")
               ("" "abcd" 4 12 "abcd" 5 "a b\r\nsecond")
               ("Ask: " "" 0 12 "Ask: " 6 "a b\r\nsecond")
               ("" "" 0 1 "" 1 " \r\ne")
               ("Ask: " "abcd" 4 1 "A" 1 " \r\ne"))])
    (define label (list-ref row 0))
    (define text (list-ref row 1))
    (define column (list-ref row 2))
    (define width (list-ref row 3))
    (def! st 'raw (rebuild 'base #:prompt `(Option Some (AloemacsPrompt new ,label ,text ,column "" (List empty) (List empty) 0))))
    (def! st 'fitted `(raw ensure-visible ,width 3))
    (define original (ev st 'fitted))
    (define text-column (if (= width 1) 1 2))
    (define expected (frame (list-ref row 6) 1 text-column 3 (list-ref row 4) 3 (list-ref row 5) #:name "untitled" #:width width))
    (for ([i (in-range 2)])
      (check-equal? (ev st `(fitted frame ,width 3)) expected))
    (check-equal? (ev st `((fitted editor) frame ,width 2))
      (editor-frame (list-ref row 6) 1 text-column))
    (check-equal? (ev st 'fitted) original)
    (same st '(fitted prompt) `(Option Some (AloemacsPrompt new ,label ,text ,column "" (List empty) (List empty) 0)))
    (same st '(fitted last-submission) submitted)
    (def! st 'resized '(fitted ensure-visible 20 3))
    (same st '(resized prompt) '(fitted prompt))
    (same st '(resized last-submission) submitted)
    (check-equal? (ev st '(resized frame 20 3))
      (frame (if (= width 1) " b\r\necond" "a b\r\nsecond")
             1 text-column 3 (string-append label text) 3
             (+ (string-length label) column 1) #:name "untitled" #:width 20)))
  (check-equal? (unbox calls) '()))

(test-case "prompt controls are sanitized after clipping without changing stored data"
  (define-values (st calls) (state))
  (define label "L\u001b[31m\t")
  (define text "T\r\u0001\u007fZ\u0000")
  (def! st 'base (session (zipper (list (buffer "")) 0)))
  (def! st 's (rebuild 'base #:prompt `(Option Some (AloemacsPrompt new ,label ,text 4 "" (List empty) (List empty) 0))))
  (define original (ev st 's))
  (for ([width '(30 12 9 1)] [shown '("L [31m T   Z " "L [31m T   Z" "L [31m T " "L")]
        [column '(12 12 9 1)])
    (check-equal? (ev st `(s frame ,width 2)) (frame "" 1 1 2 shown 2 column #:name "untitled" #:width width)))
  (check-equal? (ev st '((s prompt) case (None () "") (Some (p) (p label)))) label)
  (check-equal? (ev st '((s prompt) case (None () "") (Some (p) (p text)))) text)
  (check-equal? (ev st 's) original)
  (same st '(s last-submission) submitted)
  (check-equal? (unbox calls) '()))

(test-case "text fit, inactive row goldens, raw search precedence, and one-row fallback"
  (define-values (st calls) (state))
  (def! st 'base (session (zipper (list (buffer "zero\none\ntwo\nthree\nfour"
                                       '(Option Some (Path new "/cwd/a.txt")))) 0)))
  (def! st 'base (rebuild 'base #:buffers
    (replace-current 'base (editor "zero\none\ntwo\nthree\nfour" '(Position new 3 2)))
    #:prompt '(Option Some (AloemacsPrompt new "Ask: " "abcd" 2 "" (List empty) (List empty) 0))))
  (def! st 'fitted '(base ensure-visible 12 4))
  (check-equal? (ev st '((fitted editor) scroll-row)) 2)
  (check-equal? (ev st '((fitted editor) text-rows)) 2)
  (same-session st 'fitted
    (rebuild 'base #:columns 12 #:rows 4 #:buffers (replace-current 'base '((base editor) ensure-visible 12 2))))
  (check-equal? (ev st '(fitted frame 12 4))
    (frame "two\r\nthree" 2 3 4 "Ask: abcd" 4 8 #:name "/cwd/a.txt" #:width 12))
  ;; Search and pending remain raw active fixture state despite prompt painting.
  (same st '(fitted searching) '(base searching))
  (same st '(fitted query) '(base query))
  (same st '(fitted pending) '(base pending))
  (for ([echo '("" "saved" "failed")]
        [shown '("" "saved: /cwd/" "failed: /cwd")])
    (def! st 'inactive (rebuild 'fitted #:prompt no-prompt #:searching #f #:echo echo))
    (check-equal? (ev st '(inactive frame 12 4))
      (frame "two\r\nthree" 2 3 4 shown 2 3 #:name "/cwd/a.txt" #:width 12)))
  (for ([wrapped '(#f #t #t)] [failing '(#f #f #t)]
        [shown '("search: abc" "wrapped: abc" "failing: abc")])
    (def! st 'inactive (rebuild 'fitted #:prompt no-prompt #:query "abc"
                               #:wrapped wrapped #:failing failing))
    (check-equal? (ev st '(inactive frame 12 4))
      (frame "two\r\nthree" 2 3 4 shown 2 3 #:name "/cwd/a.txt" #:width 12)))
  (def! st 'single '(fitted ensure-visible 12 1))
  (check-equal? (ev st '((single editor) text-rows)) 1)
  (check-equal? (ev st '(single frame 12 1)) (editor-frame "three" 1 3))
  (check-equal? (ev st '(single frame 12 1)) (ev st '((single editor) frame 12 1)))
  (same st '(single prompt) '(fitted prompt))
  (same st '(single last-submission) submitted)
  (def! st 'grown '(single ensure-visible 12 4))
  (check-equal? (ev st '(grown frame 12 4))
    (frame "three\r\nfour\r\n" 1 3 4 "Ask: abcd" 4 8 #:name "/cwd/a.txt" #:width 12))
  (same st '(grown prompt) '(single prompt))
  (same st '(grown last-submission) submitted)
  (check-equal? (unbox calls) '()))
