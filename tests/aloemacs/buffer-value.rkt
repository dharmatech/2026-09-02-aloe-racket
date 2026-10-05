#lang racket/base

(require racket/string racket/list
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/env.rkt"
         "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type? type-of type->datum
                  type-environment-bound?)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new "/typed-none"))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
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
(define (singleton editor path [id 0])
  `(AloemacsBuffers new (List empty) (AloemacsBuffer new ,editor ,path ,id)
                     (List empty)))
(define (editor source [indexed? #f])
  `(AloemacsEditor new
     ,(if indexed? `((Text from-string ,source) indexed-value)
          `(Text from-string ,source))
     (Position new 0 0) #f 0 0 (List empty) ,no-mark 0))
(define (fresh-session contents path [indexed? #t])
  `(AloemacsSession new ,(singleton (editor contents indexed?) path)
     (Fs new fs-host) "" #f "" (Position new 0 0) #f #f (List empty) ,no-pending
     (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
     (if #t (Option None) (Option Some ""))
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer (,(singleton (editor contents indexed?) path) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 0 0))))

;; Independent full-value reconstruction; no production rebuild/dispatcher is
;; used to construct expectations. Every session fixture is a singleton.
(define (rebuild s #:editor [editor `(,s editor)] #:path [path `(,s path)]
                 #:echo [echo `(,s echo)] #:searching [searching `(,s searching)]
                 #:query [query `(,s query)] #:origin [origin `(,s origin)]
                 #:wrapped [wrapped `(,s wrapped)] #:failing [failing `(,s failing)]
                 #:ring [ring `(,s kill-ring)] #:pending [pending `(,s pending)]
                 #:columns [columns `((,s windows) columns)]
                 #:rows [rows `((,s windows) rows)])
  `(AloemacsSession new ,(singleton editor path `((,s current-buffer) id)) (,s fs) ,echo ,searching ,query
     ,origin ,wrapped ,failing ,ring ,pending
     (,s prompt)
     (,s last-submission)
     (,s waiting-command)
     (let ((buffer (,(singleton editor path `((,s current-buffer) id)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 ,columns ,rows))))
(define (same-session st actual expected)
  (same st actual expected)
  (for ([field (in-list (append session-fields '(current-buffer editor path)))])
    (same st `(,actual ,field) `(,expected ,field)))
  (check-true (ev st `(((,actual buffers) before) empty?)))
  (check-true (ev st `(((,actual buffers) after) empty?))))

(define (loaded)
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  st)

;; Forward the real double through fixed host arities while counting effects.
;; A second kind probe can simulate a file disappearing between inspect/read.
(define (attach-fs! st #:vanish? [vanish? #f] #:fail [fail #f])
  (define inner
    (make-fs-double "/cwd"
      (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/dir" 'directory
            "/cwd/link" 'symlink "/cwd/pipe" "fifo")
      (hash "/cwd/a.txt" "\uFEFFλ\r\nb\n")))
  (define calls (box '()))
  (define probes 0)
  (define (forward selector args)
    (set-box! calls (cons (cons selector args) (unbox calls)))
    (when (eq? selector fail) (error 'buffer-test "host failure"))
    (when (eq? selector 'kind) (set! probes (add1 probes)))
    (if (and vanish? (eq? selector 'kind) (> probes 1))
        "missing"
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
(define (state)
  (define st (loaded))
  (values st (attach-fs! st)))
(define (writes calls)
  (reverse (filter (lambda (call) (eq? (car call) 'write)) (unbox calls))))
(define (reads calls)
  (reverse (filter (lambda (call) (eq? (car call) 'read)) (unbox calls))))
(define (rich! st)
  (def! st 'old-editor
    '(AloemacsEditor new
       (Text indexed (List of "second" "first") "third-long" (List of "fourth" "fifth") 2)
       (Position new 2 4) #f 2 3
       (List of (UndoFrame new (Text from-string "older") (Position new 0 2) 1 2))
       (Option Some (Position new 1 1)) 4))
  (def! st 'source
    `(AloemacsSession new
       ,(singleton 'old-editor '(Option Some (Path new "/cwd/a.txt")))
       (Fs new fs-host) "saved" #t "old query" (Position new 4 2) #t #t
       (List of "newest" "older") (Option Some aloemacs-ctrl-x-keymap)
       (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
       (if #t (Option None) (Option Some ""))
       (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer (,(singleton 'old-editor '(Option Some (Path new "/cwd/a.txt"))) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 0 0)))))

(test-case "exact stored ownership, class order, and new method signatures"
  (define datums
    (call-with-input-file file-path
      (lambda (in)
        (let loop ([result '()])
          (define datum (read in))
          (if (eof-object? datum) (reverse result) (loop (cons datum result)))))))
  (define classes (filter (lambda (d) (eq? (car d) 'define-class)) datums))
  (check-equal? (take datums 2) '((load "editor.aloe") (load "../../lib/fs.aloe")))
  (check-equal? (map cadr classes)
    '(AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsView AloemacsWindowTree
      AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B)
      AloemacsBinding AloemacsSearchScan (AloemacsSession H)))
  (define (class name) (findf (lambda (d) (equal? (cadr d) name)) classes))
  (define buffer (class 'AloemacsBuffer))
  (define buffers (class 'AloemacsBuffers))
  (define session (class '(AloemacsSession H)))
  (check-equal? (caddr buffer) '(fields (editor AloemacsEditor) (path (Option Path)) (id Int)))
  (check-equal? (caddr buffers)
    '(fields (before (List AloemacsBuffer)) (current-buffer AloemacsBuffer)
             (after (List AloemacsBuffer))))
  (check-equal? (map (lambda (method) (drop-right method 1)) (cdr (cadddr buffer)))
    '((name () String) (with-editor (editor AloemacsEditor) AloemacsBuffer)
      (with-path (path Path) AloemacsBuffer)))
  (check-equal? (map (lambda (method) (drop-right method 1)) (cdr (cadddr buffers)))
    '((with-current-buffer (buffer AloemacsBuffer) AloemacsBuffers)
      (fresh-id () Int)
      (find-id (id Int) (Option AloemacsBuffers))
      (find-id-in (id Int) (remaining Int) (Option AloemacsBuffers))
      (find-name (name String) (Option AloemacsBuffers))
      (find-name-in (name String) (remaining Int) (Option AloemacsBuffers))
      (focus-next () AloemacsBuffers)
      (focus-previous () AloemacsBuffers)
      (insert-after (buffer AloemacsBuffer) AloemacsBuffers)
      (remove-current () AloemacsBuffers)))
  (check-equal? (caddr session)
    '(fields (buffers AloemacsBuffers) (fs (Fs H)) (echo String) (searching Bool)
             (query String) (origin Position) (wrapped Bool) (failing Bool)
             (kill-ring (List String)) (pending (Option (AloemacsKeymap AloemacsBinding)))
             (prompt (Option AloemacsPrompt)) (last-submission (Option String)) (waiting-command (Option AloemacsCommand)) (windows AloemacsWindows)))
  (for ([signature (in-list '((current-buffer () AloemacsBuffer)
                              (editor () AloemacsEditor) (path () (Option Path))))])
    (define method (assq (car signature) (cdr (cadddr session))))
    (check-not-false method)
    (check-equal? (drop-right method 1) signature)))

(test-case "fresh checked file load is local and has no optional capabilities"
  (define out (open-output-string))
  (define err (open-output-string))
  (define st (parameterize ([current-output-port out] [current-error-port err]) (loaded)))
  (for ([name '(AloemacsPrompt AloemacsBuffer AloemacsBuffers AloemacsSession)])
    (check-true (env-bound? (driver-runtime-environment st) name))
    (check-true (type-environment-bound? (driver-type-environment st) name)))
  (for ([name '(fs-host term)])
    (check-false (env-bound? (driver-runtime-environment st) name))
    (check-false (type-environment-bound? (driver-type-environment st) name)))
  (check-equal? (get-output-string out) "")
  (check-equal? (get-output-string err) ""))

(test-case "checked constructors, computed selectors, argument types and arities"
  (define-values (st calls) (state))
  (rich! st)
  (for ([entry
         (in-list '((source (AloemacsSession FsHost))
                    ((source buffers) AloemacsBuffers) ((source current-buffer) AloemacsBuffer)
                    ((source editor) AloemacsEditor) ((source path) (Option Path))
                    (((source current-buffer) name) String)
                    (((source current-buffer) with-editor old-editor) AloemacsBuffer)
                    (((source buffers) before) (List AloemacsBuffer))
                    (((source buffers) after) (List AloemacsBuffer))
                    (((source buffers) current-buffer) AloemacsBuffer)
                    (((source buffers) with-current-buffer (source current-buffer)) AloemacsBuffers)
                    (((source buffers) focus-next) AloemacsBuffers)
                    (((source buffers) focus-previous) AloemacsBuffers)
                    (((source buffers) insert-after (source current-buffer)) AloemacsBuffers)
                    (((source buffers) remove-current) AloemacsBuffers)))])
    (check-equal? (type st (car entry)) (cadr entry)))
  (same st '(source current-buffer) '((source buffers) current-buffer))
  (same st '(source editor) 'old-editor)
  (same st '(source path) '((source current-buffer) path))
  (for ([datum
         (in-list (append
          '((AloemacsBuffer new) (AloemacsBuffer new old-editor)
            (AloemacsBuffer new old-editor (Option Some (Path new "x")))
            (AloemacsBuffer new old-editor (Option Some (Path new "x")) 0 0)
            (AloemacsBuffer new "editor" (Option Some (Path new "x")) 0)
            (AloemacsBuffer new old-editor (Option Some "path") 0)
            (AloemacsBuffer new old-editor (Path new "x") 0)
            (AloemacsBuffers new) (AloemacsBuffers new (List empty) (List empty) (List empty))
            (AloemacsBuffers new (List of old-editor) (source current-buffer) (List empty))
            (AloemacsBuffers new (List empty) (source current-buffer) (List of "wrong"))
            (AloemacsBuffers new (List empty) (source current-buffer))
            (AloemacsBuffers new (List empty) (source current-buffer) (List empty) 0)
            (AloemacsSession new (source buffers) (source fs))
            ((source current-buffer) name "extra")
            ((source current-buffer) editor 0) ((source current-buffer) path 0)
            ((source current-buffer) with-editor) ((source current-buffer) with-editor "bad")
            ((source current-buffer) with-editor old-editor old-editor)
            ((source buffers) current-buffer 0) ((source buffers) before 0) ((source buffers) after 0)
            ((source buffers) with-current-buffer) ((source buffers) with-current-buffer old-editor)
            ((source buffers) with-current-buffer (source current-buffer) (source current-buffer))
            (source current-buffer 0) (source editor 0) (source path 0))
          (list `(AloemacsSession new old-editor (source fs) "" #f "" (Position new 0 0)
                                  #f #f (List empty) ,no-pending
                   (source prompt)
                   (source last-submission)
                   (source waiting-command)
     (source windows))
                `(AloemacsSession new (source current-buffer) (source fs) "" #f ""
                                  (Position new 0 0) #f #f (List empty) ,no-pending
                   (source prompt)
                   (source last-submission)
                   (source waiting-command)
     (source windows))
                `(AloemacsSession new (source buffers) (source fs) "" #f "" (Position new 0 0)
                                  #f #f (List empty) ,no-pending
                                  (source prompt) (source last-submission) (source waiting-command) (source windows) 0))))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st datum)) (format "reject ~s" datum)))
  (check-equal? (unbox calls) '()))

(test-case "derived names and immutable buffer/collection replacements"
  (define st (loaded))
  (def! st 'editor (editor "original"))
  (def! st 'replacement (editor "replacement"))
  (for ([path (in-list (list no-path '(Option Some (Path new "./dir/../a.txt"))
                            '(Option Some (Path new "/full/path/a.txt"))))]
        [name '("untitled" "./dir/../a.txt" "/full/path/a.txt")])
    (def! st 'buffer `(AloemacsBuffer new editor ,path 0))
    (define original (ev st 'buffer))
    (def! st 'changed '(buffer with-editor replacement))
    (check-equal? (ev st '(buffer name)) name)
    (check-equal? (ev st '(changed name)) name)
    (same st '(changed path) '(buffer path))
    (same st '(changed editor) 'replacement)
    (check-equal? (ev st 'buffer) original)
    ;; Raw collection values prove list preservation without a multi-buffer
    ;; session, focus operation, or second-buffer command.
    (def! st 'buffer-before '(AloemacsBuffer new (buffer editor) (buffer path) 1))
    (def! st 'changed-before '(AloemacsBuffer new (changed editor) (changed path) 2))
    (def! st 'changed-after '(AloemacsBuffer new (changed editor) (changed path) 3))
    (def! st 'buffer-after '(AloemacsBuffer new (buffer editor) (buffer path) 4))
    (def! st 'collection '(AloemacsBuffers new (List of buffer-before changed-before)
                           buffer (List of changed-after buffer-after)))
    (define old-collection (ev st 'collection))
    (def! st 'updated '(collection with-current-buffer changed))
    (same st '(updated before) '(collection before))
    (same st '(updated after) '(collection after))
    (same st '(updated current-buffer) 'changed)
    (same st '(collection current-buffer) 'buffer)
    (check-equal? (ev st 'collection) old-collection))
  ;; Raw constructors store even an invalid point and an ineligible path.
  (def! st 'raw `(AloemacsBuffer new
                  (AloemacsEditor new (Text from-string "") (Position new 99 -2)
                                     #f 0 0 (List empty) ,no-mark 0)
                  (Option Some (Path new "../directory")) 0))
  (check-equal? (ev st '(raw name)) "../directory")
  (check-equal? (ev st '(((raw editor) point) line)) 99))

(test-case "main has one cold untitled buffer and requires only explicit Fs"
  (check-exn exn:fail:aloe-type?
    (lambda () (ev (make-driver) `(load ,(path->string main-path)))))
  (define st (make-driver))
  (define calls (attach-fs! st))
  (ev st `(load ,(path->string main-path)))
  (same-session st 'aloemacs-editor (fresh-session "" no-path #f))
  (check-equal? (ev st '((aloemacs-editor current-buffer) name)) "untitled")
  (check-equal? (ev st '((aloemacs-editor text) case
                         (from-string (source) "cold")
                         (indexed (above current below focus) "indexed"))) "cold")
  (check-false (env-bound? (driver-runtime-environment st) 'term))
  (check-equal? (unbox calls) '()))

(test-case "every reconstruction preserves the specified rich payloads and pending"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'source))
  (def! st 'replacement '(old-editor move-left))
  (for ([row
         (in-list
          (list (list '(source with-editor replacement) (rebuild 'source #:editor 'replacement))
                (list '(source with-kill-state replacement (List of "supplied"))
                      (rebuild 'source #:editor 'replacement #:ring '(List of "supplied") #:echo ""))
                (list '(source with-search replacement #f "new query" (Position new 1 2) #f #f)
                      (rebuild 'source #:editor 'replacement #:searching #f #:query "new query"
                               #:origin '(Position new 1 2) #:wrapped #f #:failing #f))
                (list '(source with-echo "failed") (rebuild 'source #:echo "failed"))
                (list '(source with-prefix aloemacs-global-keymap)
                      (rebuild 'source #:echo "" #:pending '(Option Some aloemacs-global-keymap)))
                (list '(source clear-prefix) (rebuild 'source #:pending no-pending))
                (list '(source unchanged) 'source)))])
    (def! st 'actual (car row))
    (same-session st 'actual (cadr row)))
  (for ([operation '((insert "!") (newline) (backward-delete) (move-left) (move-right)
                     (move-up) (move-down) (line-start) (line-end) (page-up) (page-down)
                     (buffer-start) (buffer-end) (undo) (request-quit))])
    (same-session st `(source ,@operation)
      (rebuild 'source #:editor `(old-editor ,@operation))))
  (for ([rows '(1 2 5)])
    (same-session st `(source ensure-visible 3 ,rows)
      (rebuild 'source #:columns 3 #:rows rows #:editor `(old-editor ensure-visible 3 ,(if (>= rows 3) (- rows 2) 1)))))
  (check-equal? (ev st 'source) original)
  (check-equal? (unbox calls) '()))

(test-case "existing/missing visits replace the singleton with exact fresh defaults"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'source))
  (for ([path '("./dir/../a.txt" "missing.txt")]
        [resolved '("/cwd/a.txt" "/cwd/missing.txt")]
        [contents '("\uFEFFλ\r\nb\n" "")])
    (set-box! calls '())
    (def! st 'option `(source visit (Path new ,path)))
    (check-true (ev st '(option present?)))
    (def! st 'visited '(option case (None () source) (Some (session) session)))
    (same-session st 'visited (fresh-session contents `(Option Some (Path new ,resolved))))
    (check-equal? (ev st '((visited current-buffer) name)) resolved)
    (check-equal? (reads calls) (if (equal? contents "") '() '((read "/cwd/a.txt"))))
    (check-equal? (writes calls) '())
    (check-equal? (ev st 'source) original))
  (check-equal? (ev st '(fs-host kind "/cwd/missing.txt")) "missing"))

(test-case "refused and vanished visits preserve every source field, including pending"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'source))
  (for ([path '("dir" "link" "pipe")])
    (set-box! calls '())
    (check-false (ev st `((source visit (Path new ,path)) present?)))
    (same-session st `((source visit (Path new ,path)) case
                       (None () source) (Some (session) session)) 'source)
    (check-equal? (reads calls) '())
    (check-equal? (writes calls) '())
    (check-equal? (ev st 'source) original))
  (define vanished (loaded))
  (define vanish-calls (attach-fs! vanished #:vanish? #t))
  (rich! vanished)
  (define before (ev vanished 'source))
  (check-false (ev vanished '((source visit (Path new "a.txt")) present?)))
  (check-equal? (reads vanish-calls) '())
  (check-equal? (ev vanished 'source) before)
  (define failing (loaded))
  (attach-fs! failing #:fail 'read)
  (rich! failing)
  (check-exn exn:fail:aloe-host? (lambda () (ev failing '(source visit (Path new "a.txt"))))))

(test-case "direct saves preserve the entire singleton and write exact contents each time"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'bound (rebuild 'source #:editor (editor "\uFEFFλ\r\nb\n")))
  (define original (ev st 'bound))
  (for ([i (in-range 2)])
    (def! st 'saved '(bound save))
    (check-true (ev st '(saved present?)))
    (same-session st '(saved case (None () bound) (Some (session) session)) 'bound))
  (check-equal? (writes calls) '((write "/cwd/a.txt" "\uFEFFλ\r\nb\n")
                               (write "/cwd/a.txt" "\uFEFFλ\r\nb\n")))
  (check-equal? (ev st 'bound) original)
  (for ([path (in-list (list no-path '(Option Some (Path new "/cwd/dir"))
                            '(Option Some (Path new "/cwd/link"))
                            '(Option Some (Path new "/cwd/pipe"))
                            '(Option Some (Path new "/cwd/absent/file"))))])
    (def! st 'refused (rebuild 'source #:path path))
    (define before (ev st 'refused))
    (set-box! calls '())
    (check-false (ev st '((refused save) present?)))
    (check-equal? (writes calls) '())
    (when (equal? path no-path) (check-equal? (unbox calls) '()))
    (check-equal? (ev st 'refused) before))
  (define failing (loaded))
  (define failures (attach-fs! failing #:fail 'write))
  (rich! failing)
  (define before (ev failing 'source))
  (check-exn exn:fail:aloe-host? (lambda () (ev failing '(source save))))
  (check-equal? (length (writes failures)) 1)
  (check-equal? (ev failing 'source) before))

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

(test-case "prefix, save echoes and complete ANSI frames survive singleton fitting"
  (define-values (st calls) (state))
  (def! st 'base (fresh-session "a\u001bb\nsecond" '(Option Some (Path new "/cwd/a.txt"))))
  (def! st 'base '(base with-editor ((base editor) move-right)))
  (def! st 'armed '(base handle-key "ctrl-x"))
  (define original (ev st 'armed))
  (def! st 'fitted '(armed ensure-visible 3 3))
  (same-session st 'fitted (rebuild 'armed #:columns 3 #:rows 3 #:editor '((armed editor) ensure-visible 3 1)))
  (check-equal? (ev st '(fitted frame 3 3)) (frame "a b\r\nsec" 1 2 3 "" #:name "/cwd/a.txt" #:width 3))
  (check-equal? (ev st '(fitted frame 3 1)) (frame "a b" 1 2 #:name "/cwd/a.txt" #:width 3))
  (same st '(fitted pending) '(armed pending))
  (check-equal? (ev st 'armed) original)
  (check-equal? (unbox calls) '())
  (for ([path (in-list (list '(Option Some (Path new "/cwd/a.txt")) no-path
                            '(Option Some (Path new "/cwd/dir"))))]
        [echo '("saved" "failed" "failed")])
    (def! st 'idle (rebuild 'fitted #:path path #:pending no-pending))
    (set-box! calls '())
    (def! st 'plain '(idle handle-key "save"))
    (def! st 'prefixed '((idle handle-key "ctrl-x") handle-key "save"))
    (same-session st 'plain (rebuild 'idle #:echo echo))
    (same-session st 'prefixed 'plain)
    (check-false (ev st '((prefixed pending) present?)))
    (check-equal? (length (writes calls)) (if (equal? echo "saved") 2 0))
    (check-equal? (ev st '(plain frame 20 3))
      (frame "a b\r\nsecond" 1 2 3
             (string-append echo ": " (if (equal? path no-path) "untitled"
                                            (if (equal? echo "saved") "/cwd/a.txt" "/cwd/dir"))) #:name (if (equal? path no-path) "untitled" (if (equal? echo "saved") "/cwd/a.txt" "/cwd/dir")) #:width 20))
    (check-equal? (ev st '(prefixed frame 3 1)) (frame "a b" 1 2 #:name (if (equal? path no-path) "untitled" (if (equal? echo "saved") "/cwd/a.txt" "/cwd/dir")) #:width 20)))
  (def! st 'miss '(armed handle-key "x"))
  (same-session st 'miss (rebuild 'armed #:pending no-pending #:echo ""))
  (same-session st '(miss handle-key "x")
    (rebuild 'miss #:editor '((miss editor) insert "x") #:echo "")))
