#lang racket/base

(require racket/string racket/list racket/runtime-path rackunit
         "../../aloe/driver.rkt" "../../aloe/host.rkt" "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new "/unused"))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define no-default '(if #t (Option None) (Option Some (AloemacsCommand SelfInsert))))
(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (type st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))
                 (format "~s equals ~s" actual expected)))

(define (state #:fail [fail #f] #:vanish? [vanish? #f])
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  (define inner
    (make-fs-double "/cwd"
      (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file
            "/cwd/dir" 'directory "/cwd/link" 'symlink "/cwd/pipe" "fifo")
      (hash "/cwd/a.txt" "\uFEFFλ\r\nb\n" "/cwd/b.txt" "disk b")))
  (define calls (box '()))
  (define probes 0)
  (define (forward selector args)
    (set-box! calls (cons (cons selector args) (unbox calls)))
    (when (eq? selector fail) (error 'buffer-session-test "host failure"))
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
  (values st calls inner))
(define (effects calls selector)
  (reverse (filter (lambda (call) (eq? (car call) selector)) (unbox calls))))
(define (fresh-editor contents)
  `(AloemacsEditor new ((Text from-string ,contents) indexed-value)
                      (Position new 0 0) #f 0 0 (List empty) ,no-mark 0))
(define (buffer contents [path no-path] [id 0])
  `(AloemacsBuffer new ,(fresh-editor contents) ,path ,id))
(define (zipper order focus)
  `(AloemacsBuffers new (List of ,@(reverse (take order focus)))
                       ,(list-ref order focus) (List of ,@(drop order (add1 focus)))))
(define (session buffers #:echo [echo "saved"] #:searching [searching #f]
                 #:query [query "stale"] #:origin [origin '(Position new 8 7)]
                 #:wrapped [wrapped #t] #:failing [failing #t]
                 #:ring [ring '(List of "newest" "older")]
                 #:pending [pending '(Option Some aloemacs-ctrl-x-keymap)])
  `(AloemacsSession new ,buffers (Fs new fs-host) ,echo ,searching ,query ,origin
                       ,wrapped ,failing ,ring ,pending
     (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
     (if #t (Option None) (Option Some ""))
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer (,buffers current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 0 0))))

;; Expectations explicitly rebuild all fields. They never invoke the selection
;; methods, collection transitions, or execute-command being tested.
(define (reset s buffers #:ring [ring `(,s kill-ring)])
  `(AloemacsSession new ,buffers (,s fs) "" #f "" (Position new 0 0)
                       #f #f ,ring ,no-pending
     (,s prompt)
     (,s last-submission)
     (,s waiting-command)
     (let ((buffer (,buffers current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 ((,s windows) columns) ((,s windows) rows)))))
(define (rebuild s #:buffers [buffers `(,s buffers)] #:echo [echo `(,s echo)]
                 #:searching [searching `(,s searching)] #:query [query `(,s query)]
                 #:origin [origin `(,s origin)] #:wrapped [wrapped `(,s wrapped)]
                 #:failing [failing `(,s failing)] #:ring [ring `(,s kill-ring)]
                 #:pending [pending `(,s pending)]
                 #:columns [columns `((,s windows) columns)]
                 #:rows [rows `((,s windows) rows)])
  `(AloemacsSession new ,buffers (,s fs) ,echo ,searching ,query ,origin ,wrapped
                       ,failing ,ring ,pending
     (,s prompt)
     (,s last-submission)
     (,s waiting-command)
     (let ((buffer (,buffers current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 ,columns ,rows))))
(define (with-editor s editor #:columns [columns `((,s windows) columns)]
                     #:rows [rows `((,s windows) rows)])
  (rebuild s #:columns columns #:rows rows #:buffers
    `(AloemacsBuffers new ((,s buffers) before)
       (AloemacsBuffer new ,editor (,s path) ((,s current-buffer) id)) ((,s buffers) after))))
(define (same-session st actual expected)
  (def! st 'comparison-actual actual)
  (def! st 'comparison-expected expected)
  (same st 'comparison-actual 'comparison-expected)
  (for ([field '(buffers fs echo searching query origin wrapped failing kill-ring
                        pending prompt last-submission waiting-command current-buffer editor path text point quit)])
    (same st `(comparison-actual ,field) `(comparison-expected ,field)))
  (for ([field '(before current-buffer after)])
    (same st `((comparison-actual buffers) ,field) `((comparison-expected buffers) ,field))))
(define (rich! st)
  (def! st 'a
    '(AloemacsBuffer new
       (AloemacsEditor new
         (Text indexed (List of "second" "first") "third-long"
                       (List of "fourth" "fifth") 2)
         (Position new 2 4) #f 2 3
         (List of (UndoFrame new (Text from-string "old a") (Position new 0 2) 1 2))
         (Option Some (Position new 1 1)) 4)
       (Option Some (Path new "/cwd/a.txt")) 0))
  (def! st 'b
    '(AloemacsBuffer new
       (AloemacsEditor new (Text indexed (List empty) "Z" (List empty) 0)
         (Position new 0 1) #f 0 0
         (List of (UndoFrame new (Text from-string "old b") (Position new 0 3) 0 1))
         (Option Some (Position new 0 0)) 2)
       (Option Some (Path new "/cwd/b.txt")) 1))
  (def! st 'c
    `(AloemacsBuffer new
       (AloemacsEditor new (Text indexed (List of "one") "three" (List of "last") 1)
         (Position new 1 3) #f 1 2
         (List of (UndoFrame new (Text from-string "old c") (Position new 0 4) 0 2))
         (Option Some (Position new 1 1)) 5)
       ,no-path 2))
  (def! st 'base (session (zipper '(a b c) 0))))

(test-case "new checked session sends, commands, arities and wrong types"
  (define-values (st calls disk) (state))
  (rich! st)
  (for ([expr '((base add-buffer "new") (base add-buffer "new" (Path new "relative"))
               (base switch-buffer) (base kill-buffer)
               (base execute-command (AloemacsCommand SwitchBuffer) "x")
               (base execute-command (AloemacsCommand KillBuffer) "x"))])
    (check-equal? (type st expr) '(AloemacsSession FsHost))
    (check-not-exn (lambda () (ev st expr))))
  (for ([constructor '(SwitchBuffer KillBuffer)] [name '("switch-buffer" "kill-buffer")])
    (check-equal? (type st `(AloemacsCommand ,constructor)) 'AloemacsCommand)
    (check-equal? (type st `((AloemacsCommand ,constructor) name)) 'String)
    (check-equal? (ev st `((AloemacsCommand ,constructor) name)) name)
    (for ([expr (list `(AloemacsCommand ,constructor "x")
                     `((AloemacsCommand ,constructor) run base)
                     `((AloemacsCommand ,constructor) name "x"))])
      (check-exn exn:fail:aloe-type? (lambda () (ev st expr)))))
  (for ([selector '(switch-buffer kill-buffer)])
    (for ([expr (list `(base ,selector "x") `(base ,selector 1 2)
                     `((base editor) ,selector) `((base buffers) ,selector)
                     `(1 ,selector) `(AloemacsSession ,selector))])
      (check-exn exn:fail:aloe-type? (lambda () (ev st expr)))))
  (for ([expr `((base add-buffer) (base add-buffer 1) (base add-buffer (Text from-string "x"))
               (base add-buffer "x" "path") (base add-buffer "x" ,no-path)
               (base add-buffer "x" (Option Some (Path new "x")))
               (base add-buffer "x" 1) (base add-buffer "x" (Path new "x") "extra")
               (base add-buffer (Path new "x") "x")
               ((base editor) add-buffer "x") ((base buffers) add-buffer "x")
               (1 add-buffer "x") (AloemacsSession add-buffer "x"))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st expr)) (format "reject ~s" expr)))
  (check-equal? (unbox calls) '()))

(test-case "addition by either arity inserts after each focus, accepts paths, and resets"
  (define-values (st calls disk) (state))
  (rich! st)
  (define contents "\uFEFFλ\r\nb\n")
  (for ([focus '(0 1 2)] [echo '("saved" "failed" "saved")])
    (def! st 'source (session (zipper '(a b c) focus) #:echo echo))
    (define original (ev st 'source))
    (for ([path (in-list (list #f "./dir/../a.txt" "/cwd/a.txt" "/cwd/dir"
                              "/cwd/link" "/cwd/pipe" "/cwd/missing/file"))])
      (define supplied (if path `(Option Some (Path new ,path)) no-path))
      (define new-buffer (buffer contents supplied 3))
      (define order (append (take '(a b c) (add1 focus)) (list new-buffer)
                            (drop '(a b c) (add1 focus))))
      (def! st 'added `(source add-buffer ,contents ,@(if path `((Path new ,path)) '())))
      (same-session st 'added (reset 'source (zipper order (add1 focus))))
      (check-equal? (ev st '((added current-buffer) name)) (or path "untitled"))
      (check-equal? (ev st 'source) original)))
  (for ([known-path (list no-path '(Option Some (Path new "../optional")))])
    (def! st 'known-path known-path)
    (def! st 'added
      '(known-path case (None () (base add-buffer "second"))
                        (Some (path) (base add-buffer "second" path))))
    (same-session st 'added
      (reset 'base (zipper (list 'a (buffer "second" known-path 3) 'b 'c) 1))))
  ;; Repeated same text/path and untitled names never deduplicate positions.
  (def! st 'same (reset 'base (zipper (list (buffer "x" no-path)) 0)))
  (def! st 'added '((same add-buffer "x") add-buffer "x"))
  (same-session st 'added
    (reset 'same (zipper (for/list ([id '(0 1 2)]) (buffer "x" no-path id)) 2)))
  (def! st 'added '((base add-buffer "x" (Path new "/cwd/a.txt"))
                   add-buffer "x" (Path new "/cwd/a.txt")))
  (same-session st 'added
    (reset 'base (zipper (list 'a (buffer "x" '(Option Some (Path new "/cwd/a.txt")) 3)
                                 (buffer "x" '(Option Some (Path new "/cwd/a.txt")) 4) 'b 'c) 2)))
  (check-equal? (unbox calls) '()))

(test-case "switch, kill and command execution select positionally with exact resets"
  (define-values (st calls disk) (state))
  (rich! st)
  (for ([focus '(0 1 2)])
    (def! st 'source (session (zipper '(a b c) focus) #:searching #t))
    (define original (ev st 'source))
    (define remaining (append (take '(a b c) focus) (drop '(a b c) (add1 focus))))
    (define switched (reset 'source (zipper '(a b c) (modulo (add1 focus) 3))))
    (define killed (reset 'source (zipper remaining (min focus 1))))
    (same-session st '(source switch-buffer) switched)
    (same-session st '(source kill-buffer) killed)
    (for ([key '("" "x" "switch-buffer" "kill-buffer")])
      (same-session st `(source execute-command (AloemacsCommand SwitchBuffer) ,key) switched)
      (same-session st `(source execute-command (AloemacsCommand KillBuffer) ,key) killed))
    (check-equal? (ev st 'source) original))
  (for ([active? '(#f #t)])
    (def! st 'source (session (zipper '(a) 0) #:searching active? #:echo "failed"))
    (same-session st '(source switch-buffer) (reset 'source (zipper '(a) 0)))
    (def! st 'killed '(source kill-buffer))
    (same-session st 'killed (reset 'source (zipper (list (buffer "")) 0)))
    (same-session st '(killed kill-buffer) 'killed))
  (def! st 'killed 'base)
  (for ([expected (list (zipper '(b c) 0) (zipper '(c) 0)
                       (zipper (list (buffer "" no-path 2)) 0) (zipper (list (buffer "" no-path 2)) 0))])
    (def! st 'killed '(killed kill-buffer))
    (same-session st 'killed (reset 'base expected)))
  (check-equal? (unbox calls) '()))

(test-case "round trips, edits, undo and removal keep other editors and sources exact"
  (define-values (st calls disk) (state))
  (rich! st)
  (define original (ev st 'base))
  (same-session st '(((base switch-buffer) switch-buffer) switch-buffer)
                (reset 'base (zipper '(a b c) 0)))
  (def! st 'selected '(base switch-buffer))
  (def! st 'edited '(selected insert "!"))
  (same-session st 'edited (with-editor 'selected '((b editor) insert "!")))
  (same st '((edited buffers) before) '(List of a))
  (same st '((edited buffers) after) '(List of c))
  (same st '((edited editor) history)
        '(((b editor) history) cons
           (UndoFrame new ((b editor) text) ((b editor) point)
                          ((b editor) scroll-row) ((b editor) scroll-col))))
  (same-session st '(edited undo) 'selected)
  (same-session st '(edited kill-buffer) (reset 'edited (zipper '(a c) 1)))
  (def! st 'other '((edited switch-buffer) insert "?"))
  (same st '((other buffers) before) '(List of (edited current-buffer) a))
  (same-session st '(other undo) '(edited switch-buffer))
  (same st '((selected current-buffer) name) '(b name))
  (check-equal? (ev st 'base) original)
  (check-equal? (unbox calls) '()))

(test-case "one ring carries region kills across switching, source removal, yank and undo"
  (define-values (st calls disk) (state))
  (def! st 'a
    `(AloemacsBuffer new
       (AloemacsEditor new ((Text from-string "abc") indexed-value)
         (Position new 0 3) #f 1 2 (List empty) (Option Some (Position new 0 0)) 3)
       ,no-path 0))
  (for ([mark '(0 9)])
    (def! st 'b
      `(AloemacsBuffer new
         (AloemacsEditor new ((Text from-string "X") indexed-value)
           (Position new 0 0) #f 0 0 (List empty) (Option Some (Position new 0 ,mark)) 2)
         ,no-path 1))
    (def! st 'base (session (zipper '(a b) 0) #:pending no-pending))
    (define original (ev st 'base))
    (def! st 'cut '(base kill))
    (check-equal? (ev st '((cut text) to-string)) "")
    (check-false (ev st '(((cut editor) mark) present?)))
    (check-equal? (ev st '(((cut editor) history) len)) 1)
    (same st '(cut kill-ring) '(List of "abc" "newest" "older"))
    (same st '((cut buffers) after) '(List of b))
    (for ([operation '(switch-buffer kill-buffer)])
      (def! st 'target `(cut ,operation))
      (def! st 'pasted '(target yank))
      (check-equal? (ev st '((pasted text) to-string)) "abcX")
      (same st '(pasted kill-ring) '(cut kill-ring))
      (same st '((pasted editor) mark)
            (if (= mark 0) '(Option Some (Position new 0 0)) no-mark))
      (define expected-editor
        (if (= mark 0) '(b editor)
            `(AloemacsEditor new ((b editor) text) ((b editor) point) #f 0 0
                                (List empty) ,no-mark 2)))
      (same-session st '(pasted undo) (with-editor 'target expected-editor))
      (same st '((pasted buffers) before) '((target buffers) before))
      (same st '((pasted buffers) after) '((target buffers) after)))
    (check-equal? (ev st 'base) original))
  (check-equal? (unbox calls) '()))

(test-case "direct save, Ctrl-S and C-x C-s write only the selected path and exact text"
  (define-values (st calls disk) (state))
  (rich! st)
  (def! st 'source (rebuild 'base #:pending '(Option Some aloemacs-ctrl-x-keymap)))
  (define original (ev st 'source))
  (for ([selected (list 'source '(source switch-buffer))]
        [path '("/cwd/a.txt" "/cwd/b.txt")])
    (def! st 'selected selected)
    (set-box! calls '())
    (def! st 'saved '((selected save) case (None () selected) (Some (result) result)))
    (same-session st 'saved 'selected)
    (check-equal? (effects calls 'write)
                  (list (list 'write path (ev st '((selected text) to-string)))))
    (same st '(saved pending) '(selected pending))
    (def! st 'idle (rebuild 'selected #:pending no-pending))
    (for ([send '((idle handle-key "save") ((idle handle-key "ctrl-x") handle-key "save"))])
      (set-box! calls '())
      (def! st 'saved send)
      (same-session st 'saved (rebuild 'idle #:echo "saved"))
      (check-equal? (effects calls 'write)
                    (list (list 'write path (ev st '((idle text) to-string)))))
      (check-equal? (host-receiver-send disk 'read (list path))
                    (ev st '((idle text) to-string)))))
  (check-equal? (ev st 'source) original)
  (for ([path (list no-path '(Option Some (Path new "/cwd/dir"))
                   '(Option Some (Path new "/cwd/link"))
                   '(Option Some (Path new "/cwd/pipe"))
                   '(Option Some (Path new "/cwd/absent/file")))])
    (def! st 'refused (reset 'source (zipper (list 'a (buffer "draft" path 1) 'c) 1)))
    (set-box! calls '())
    (check-false (ev st '((refused save) present?)))
    (when (equal? path no-path) (check-equal? (unbox calls) '()))
    (for ([send '((refused handle-key "save")
                 ((refused handle-key "ctrl-x") handle-key "save"))])
      (same-session st send (rebuild 'refused #:echo "failed")))
    (check-equal? (effects calls 'write) '())
    (same st '(refused buffers) (zipper (list 'a (buffer "draft" path 1) 'c) 1)))
  (def! st 'shared (session
    (zipper (list (buffer "first\r\n" '(Option Some (Path new "/cwd/a.txt")))
                  (buffer "second\n" '(Option Some (Path new "/cwd/a.txt")) 1)) 0)
    #:pending no-pending))
  (define shared (ev st 'shared))
  (for ([selected (list 'shared '(shared switch-buffer))] [contents '("first\r\n" "second\n")])
    (def! st 'saved `((,selected save) case (None () ,selected) (Some (result) result)))
    (same-session st 'saved selected)
    (check-equal? (host-receiver-send disk 'read '("/cwd/a.txt")) contents))
  (check-equal? (ev st 'shared) shared))

(test-case "save host failures propagate through all entry points without changing buffers"
  (define-values (st calls disk) (state #:fail 'write))
  (rich! st)
  (def! st 'base (rebuild 'base #:pending no-pending))
  (define original (ev st 'base))
  (for ([send '((base save) (base handle-key "save")
               ((base handle-key "ctrl-x") handle-key "save"))])
    (set-box! calls '())
    (check-exn exn:fail:aloe-host? (lambda () (ev st send)))
    (check-equal? (effects calls 'write)
                  (list (list 'write "/cwd/a.txt" (ev st '((base text) to-string)))))
    (check-equal? (ev st 'base) original)))

(test-case "visit replaces only current, resets its state and ring, and leaves refusals exact"
  (define-values (st calls disk) (state))
  (rich! st)
  (for ([focus '(0 1 2)])
    (def! st 'source (session (zipper '(a b c) focus) #:searching #t))
    (define original (ev st 'source))
    (for ([path '("./dir/../a.txt" "missing.txt")]
          [resolved '("/cwd/a.txt" "/cwd/missing.txt")]
          [contents '("\uFEFFλ\r\nb\n" "")])
      (set-box! calls '())
      (def! st 'result `(source visit (Path new ,path)))
      (check-true (ev st '(result present?)))
      (def! st 'visited '(result case (None () source) (Some (session) session)))
      (same-session st 'visited
        (reset 'source
          (zipper (append (take '(a b c) focus)
                          (list (buffer contents `(Option Some (Path new ,resolved))
                                        '((source current-buffer) id)))
                          (drop '(a b c) (add1 focus))) focus)
          #:ring '(List empty)))
      (check-equal? (effects calls 'read)
                    (if (equal? contents "") '() '((read "/cwd/a.txt"))))
      (check-equal? (effects calls 'write) '()))
    (for ([path '("dir" "link" "pipe")])
      (set-box! calls '())
      (check-false (ev st `((source visit (Path new ,path)) present?)))
      (same-session st `((source visit (Path new ,path)) case
                         (None () source) (Some (session) session)) 'source)
      (check-equal? (effects calls 'read) '())
      (check-equal? (effects calls 'write) '()))
    (check-equal? (ev st 'source) original))
  (define-values (vanished vanished-calls vanished-disk) (state #:vanish? #t))
  (rich! vanished)
  (check-false (ev vanished '((base visit (Path new "a.txt")) present?)))
  (same-session vanished 'base (session (zipper '(a b c) 0)))
  (define-values (failed failed-calls failed-disk) (state #:fail 'read))
  (rich! failed)
  (check-exn exn:fail:aloe-host? (lambda () (ev failed '(base visit (Path new "a.txt")))))
  (same-session failed 'base (session (zipper '(a b c) 0))))

(test-case "selection accepts a search-result point and cannot carry origin to shorter text"
  (define-values (st calls disk) (state))
  (rich! st)
  (def! st 'origin
    (rebuild 'base #:pending no-pending #:query "" #:wrapped #f #:failing #f))
  (def! st 'active '((origin find) handle-key "f"))
  (check-equal? (ev st '((active origin) line)) 2)
  (check-equal? (ev st '((active origin) column)) 4)
  (check-equal? (ev st '((active point) line)) 3)
  (check-equal? (ev st '((active point) column)) 0)
  (same st '((active editor) history) '((a editor) history))
  (def! st 'departed '(active current-buffer))
  (for ([send '((active switch-buffer) (active kill-buffer)
               (active add-buffer "Q"))]
        [expected (list (zipper '(departed b c) 1) (zipper '(b c) 0)
                        (zipper (list 'departed (buffer "Q" no-path 3) 'b 'c) 1))])
    (def! st 'selected send)
    (same-session st 'selected (reset 'active expected))
    (check-false (ev st '((selected text) valid-position? (active origin))))
    (def! st 'finding '(selected handle-key "find"))
    (same-session st 'finding
      (rebuild 'selected #:searching #t #:origin '(selected point)))
    (same st '((finding editor) history) '((selected editor) history)))
  (def! st 'single (rebuild 'active #:buffers (zipper '(departed) 0)))
  (same-session st '(single switch-buffer) (reset 'single (zipper '(departed) 0)))
  (same st '((active buffers) before) '(List empty))
  (same st '((active buffers) after) '(List of b c))
  (check-equal? (unbox calls) '()))

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
(define (frame body row column [rows #f] [label ""] #:name [name "untitled"] #:width [width 0])
  (string-append "\e[?25l\e[2J\e[H"
    (if rows (text-body body rows) body)
    (format "\e[~a;~aH\e[?25h" row column)
    (if (and rows (>= rows 2))
        (string-append "\e[?25l"
          (if (>= rows 3) (format "\e[~a;1H~a" (sub1 rows) (mode-row name width)) "")
          (format "\e[~a;1H~a\e[~a;~aH\e[?25h" rows label row column)) "")))

(test-case "selection frames destination stored origins, safe clipping, padding and one row"
  (define-values (st calls disk) (state))
  (rich! st)
  (def! st 'b
    `(AloemacsBuffer new
       (AloemacsEditor new
         (Text indexed (List of "ignored") "012\u001bXYZ" (List of "last") 1)
         (Position new 1 5) #f 1 2
         (List of (UndoFrame new (Text from-string "old") (Position new 0 0) 0 0))
         (Option Some (Position new 0 1)) 7)
       (Option Some (Path new "/b\u001blong")) 1))
  (def! st 'c (buffer "" no-path 2))
  (for ([echo '("saved" "failed")])
    (def! st 'base (session (zipper '(a b c) 0) #:echo echo))
    (def! st 'selected '(base switch-buffer))
    (define original (ev st 'selected))
    (same-session st 'selected (reset 'base (zipper '(a b c) 1)))
    (check-equal? (ev st '(selected frame 4 4)) (frame "2 XY\r\nst\r\n" 1 4 4 "" #:name "/b\u001blong" #:width 4))
    (check-equal? (ev st '(selected frame 4 1)) (frame "2 XY" 1 4 #:name "untitled" #:width 4))
    (check-equal? (ev st 'selected) original)
    (def! st 'fitted '(selected ensure-visible 2 3))
    (define fitted-editor
      '(AloemacsEditor new ((b editor) text) ((b editor) point) #f 1 4
                          ((b editor) history) ((b editor) mark) 1))
    (same-session st 'fitted (with-editor 'selected fitted-editor #:columns 2 #:rows 3))
    (check-equal? (ev st '(fitted frame 2 3)) (frame "XY\r\n" 1 2 3 "" #:name "/b\u001blong" #:width 2))
    (same-session st '(selected ensure-visible 2 1)
      (with-editor 'selected
        '(AloemacsEditor new ((b editor) text) ((b editor) point) #f 1 4
                            ((b editor) history) ((b editor) mark) 1) #:columns 2 #:rows 1))
    (def! st 'untitled '(selected switch-buffer))
    (check-equal? (ev st '(untitled frame 4 3)) (frame "\r\n" 1 1 3 "" #:name "untitled" #:width 4))
    (check-equal? (ev st '(untitled frame 4 1)) (frame "" 1 1 #:name "untitled" #:width 4))
    (same-session st '(selected kill-buffer) (reset 'selected (zipper '(a c) 1)))
    (check-equal? (ev st '((selected kill-buffer) frame 4 3)) (frame "\r\n" 1 1 3 "" #:name "untitled" #:width 4))
    (def! st 'added '(selected add-buffer "a\u001bb" (Path new "new\u001bname")))
    (check-equal? (ev st '(added frame 4 3)) (frame "a b\r\n" 1 1 3 "" #:name "new\u001bname" #:width 4)))
  (check-equal? (unbox calls) '()))

(test-case "test-only maps follow pending consumption and search precedence"
  (define-values (st calls disk) (state))
  (rich! st)
  (for ([constructor '(SwitchBuffer KillBuffer)]
        [expected (list (zipper '(a b c) 1) (zipper '(b c) 0))])
    (def! st 'map
      `(AloemacsKeymap new
         (List of (AloemacsBinding Command "select" (AloemacsCommand ,constructor))
                  (AloemacsBinding Command "x" (AloemacsCommand ,constructor)))
         ,no-default))
    (def! st 'armed '(base with-prefix map))
    (for ([key '("select" "x")])
      (same-session st `(armed handle-key ,key) (reset 'armed expected)))
    (same-session st '(armed handle-key "save")
      (rebuild 'armed #:pending no-pending #:echo ""))
    (same-session st '(armed handle-key "ctrl-x")
      (rebuild 'armed #:pending no-pending #:echo ""))
    (def! st 'active '(armed find))
    (def! st 'typed '(active handle-key "x"))
    (check-equal? (ev st '(typed query)) "x")
    (same st '(typed pending) '(armed pending))
    (same st '(typed current-buffer) '(armed current-buffer))
    (same st '((typed editor) history) '((armed editor) history))
    (same st '(typed buffers) '(armed buffers))
    (same-session st '(active handle-key "select") (reset 'active expected))
    (for ([key '("escape" "return")])
      (same-session st `(active handle-key ,key)
        (rebuild 'active #:searching #f #:query "" #:origin '(Position new 0 0)
                         #:wrapped #f #:failing #f)))
    (same-session st '(active handle-key "backspace") 'active)
    (same-session st '(active handle-key "find") 'active)
    (def! st 'aloemacs-global-keymap '(AloemacsKeymap new (map bindings) (map default)))
    (def! st 'idle (rebuild 'base #:pending no-pending))
    (same-session st '(idle handle-key "select") (reset 'idle expected))
    (same-session st '((idle find) handle-key "select") (reset 'idle expected)))
  (check-equal? (unbox calls) '()))

(test-case "production maps keep their exact commands, prefix and idle misses"
  (define-values (st calls disk) (state))
  (rich! st)
  (define rows
    '(("return" Newline) ("backspace" BackwardDelete) ("left" MoveLeft) ("right" MoveRight)
      ("up" MoveUp) ("down" MoveDown) ("line-start" LineStart) ("line-end" LineEnd)
      ("page-up" PageUp) ("page-down" PageDown) ("buffer-start" BufferStart)
      ("buffer-end" BufferEnd) ("escape" RequestQuit) ("undo" Undo) ("mark" SetMark)
      ("kill" Kill) ("kill-line" KillLine) ("yank" Yank) ("find" Find) ("save" Save)))
  (same st '(aloemacs-global-keymap bindings)
    `(List of ,@(for/list ([row rows])
                  `(AloemacsBinding Command ,(car row) (AloemacsCommand ,(cadr row))))
              (AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap)))
  (same st '(aloemacs-global-keymap default) '(Option Some (AloemacsCommand SelfInsert)))
  (same st '(aloemacs-ctrl-x-keymap bindings)
        '(List of (AloemacsBinding Command "save" aloemacs-save-command)
                  (AloemacsBinding Command "find" (AloemacsCommand FindFile))
                  (AloemacsBinding Command "kill" (AloemacsCommand SaveAs))
                  (AloemacsBinding Command "b" (AloemacsCommand SelectBuffer))
                  (AloemacsBinding Command "2" (AloemacsCommand SplitBelow))
                  (AloemacsBinding Command "3" (AloemacsCommand SplitRight))
                  (AloemacsBinding Command "0" (AloemacsCommand DeleteWindow))
                  (AloemacsBinding Command "o" (AloemacsCommand OtherWindow))
                  (AloemacsBinding Command "l" (AloemacsCommand ToggleWindowLock))))
  (same st '(aloemacs-ctrl-x-keymap default) no-default)
  (def! st 'idle (rebuild 'base #:pending no-pending))
  (for ([key '("switch-buffer" "kill-buffer")])
    (check-false (ev st `((aloemacs-global-keymap lookup ,key) present?)))
    (same-session st `(idle handle-key ,key) (rebuild 'idle #:echo "")))
  (same-session st '(idle handle-key "x") (rebuild
    'idle #:buffers `(AloemacsBuffers new (List empty)
                      (AloemacsBuffer new ((a editor) insert "x") (a path) (a id)) (List of b c))
    #:echo ""))
  (same-session st '((idle handle-key "ctrl-x") handle-key "x")
                (rebuild 'idle #:echo ""))
  (check-equal? (unbox calls) '()))

(test-case "selected quit flags stay exact; keys absorb while direct commands still select"
  (define-values (st calls disk) (state))
  (rich! st)
  (def! st 'quit-buffer '(AloemacsBuffer new ((a editor) request-quit) (a path) (a id)))
  (def! st 'base (session (zipper '(quit-buffer b c) 0) #:searching #t))
  (define original (ev st 'base))
  (for ([key '("save" "ctrl-x" "find" "x" "switch-buffer" "kill-buffer" "return" "escape")])
    (same-session st `(base handle-key ,key) 'base))
  (same-session st '(base execute-command (AloemacsCommand SwitchBuffer) "x")
                (reset 'base (zipper '(quit-buffer b c) 1)))
  (same-session st '(base execute-command (AloemacsCommand KillBuffer) "x")
                (reset 'base (zipper '(b c) 0)))
  (def! st 'live (session (zipper '(b quit-buffer) 0)))
  (check-true (ev st '((live switch-buffer) quit)))
  (same st '((live switch-buffer) current-buffer) 'quit-buffer)
  (def! st 'single (session (zipper '(quit-buffer) 0)))
  (check-true (ev st '((single switch-buffer) quit)))
  (check-false (ev st '((single kill-buffer) quit)))
  (same-session st '(single execute-command (AloemacsCommand KillBuffer) "x")
                (reset 'single (zipper (list (buffer "")) 0)))
  (check-equal? (ev st 'base) original)
  (check-equal? (unbox calls) '()))
