#lang racket/base

(require racket/list
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

;; This is the acceptance table, independent of the production dispatcher.
(define rows
  '(("return" Newline "newline" newline)
    ("backspace" BackwardDelete "backward-delete" backward-delete)
    ("left" MoveLeft "move-left" move-left)
    ("right" MoveRight "move-right" move-right)
    ("up" MoveUp "move-up" move-up)
    ("down" MoveDown "move-down" move-down)
    ("line-start" LineStart "line-start" line-start)
    ("line-end" LineEnd "line-end" line-end)
    ("page-up" PageUp "page-up" page-up)
    ("page-down" PageDown "page-down" page-down)
    ("buffer-start" BufferStart "buffer-start" buffer-start)
    ("buffer-end" BufferEnd "buffer-end" buffer-end)
    ("escape" RequestQuit "request-quit" request-quit)
    ("undo" Undo "undo" undo)
    ("mark" SetMark "set-mark" set-mark)
    ("kill" Kill "kill" kill)
    ("kill-line" KillLine "kill-line" kill-line)
    ("yank" Yank "yank" yank)
    ("find" Find "find" find)
    ("save" Save "save" save-key)))
(define commands (append rows '(("x" SelfInsert "self-insert" insert))))
;; Commands grow independently of the unchanged production binding table.
(define command-inventory
  (append commands '(("" SwitchBuffer "switch-buffer" switch-buffer)
                     ("" KillBuffer "kill-buffer" kill-buffer)
                     ("" FindFile "find-file" start-command-prompt)
                     ("" SaveAs "save-as" start-command-prompt)
                     ("" SelectBuffer "select-buffer" start-command-prompt)
                     ("" SplitBelow "split-below" split-below)
                     ("" SplitRight "split-right" split-right)
                     ("" DeleteWindow "delete-window" delete-window)
                     ("" OtherWindow "other-window" other-window)
                     ("" ToggleWindowLock "toggle-window-lock" toggle-window-lock))))
(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new "/unused"))))
(define no-default
  '(if #t (Option None) (Option Some (AloemacsCommand SelfInsert))))
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define session-fields '(buffers fs echo searching query origin wrapped failing kill-ring pending
                                prompt last-submission waiting-command windows))
(define editor-fields '(text point quit scroll-row scroll-col history mark text-rows))

(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (type st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (same st left right)
  (check-not-exn (lambda () (ev st `(check ,left ,right)))))

;; No capability is injected while file.aloe is loading.
(define (loaded)
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  st)

;; Retain the real Fs-double behavior and record every host call. The fixed
;; arities also exercise the unchanged guarded host boundary.
(define (attach-fs! st [name 'fs-host] [interface-name 'FsHost]
                    #:fail-write? [fail-write? #f])
  (define inner
    (make-fs-double "/cwd"
                    (hash "/cwd" 'directory "/cwd/a.txt" 'file
                          "/cwd/dir" 'directory)
                    (hash "/cwd/a.txt" "original")))
  (define calls (box '()))
  (define (forward selector args)
    (set-box! calls (cons (cons selector args) (unbox calls)))
    (when (and fail-write? (eq? selector 'write))
      (error 'keymap-test "write failed"))
    (host-receiver-send inner selector args))
  (define interface
    (make-host-interface
     interface-name
     (for/list ([method (in-list (host-interface-methods fs-interface))])
       (define selector (host-method-selector method))
       (define params (host-method-parameter-types method))
       (make-host-method
        selector params (host-method-return-type method)
        (case (length params)
          [(0) (lambda (state) (forward selector '()))]
          [(1) (lambda (state a) (forward selector (list a)))]
          [(2) (lambda (state a b) (forward selector (list a b)))])))))
  (driver-inject-host! st name (make-host-receiver interface #f))
  calls)

(define (state)
  (define st (loaded))
  (define calls (attach-fs! st))
  (values st calls))
(define (writes calls)
  (reverse (filter (lambda (call) (eq? (car call) 'write)) (unbox calls))))

(define (session source line column
                 #:history [history '(List empty)] #:mark [mark no-mark]
                 #:ring [ring '(List empty)] #:echo [echo "saved"]
                 #:path [path '(Option Some (Path new "/cwd/a.txt"))]
                 #:host [host 'fs-host] #:pending [pending no-pending])
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new (Text from-string ,source) (Position new ,line ,column)
                             #f 2 3 ,history ,mark 0)
         ,path 0)
       (List empty))
     (Fs new ,host)
     ,echo
     #f
     ""
     (Position new 4 2)
     #t
     #t
     ,ring
     ,pending
     (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
     (if #t (Option None) (Option Some ""))
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer ((AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new (Text from-string ,source) (Position new ,line ,column)
                             #f 2 3 ,history ,mark 0)
         ,path 0)
       (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f (Option None)))
         0 0 0))))

;; Build expected echo results without using the new with-echo helper.
(define (token s echo)
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (,s editor)
         (,s path) ((,s current-buffer) id))
       (List empty))
     (,s fs)
     ,echo
     (,s searching)
     (,s query)
     (,s origin)
     (,s wrapped)
     (,s failing)
     (,s kill-ring)
     (,s pending)
     (,s prompt)
     (,s last-submission)
     (,s waiting-command)
     (let ((buffer ((AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (,s editor)
         (,s path) ((,s current-buffer) id))
       (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f (Option None)))
         0 ((,s windows) columns) ((,s windows) rows)))))

;; Independent expected-value construction for prefix installation/clearing.
(define (prefix-state s pending [echo `(,s echo)])
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (,s editor)
         (,s path) ((,s current-buffer) id))
       (List empty))
     (,s fs)
     ,echo
     (,s searching)
     (,s query)
     (,s origin)
     (,s wrapped)
     (,s failing)
     (,s kill-ring)
     ,pending
     (,s prompt)
     (,s last-submission)
     (,s waiting-command)
     (let ((buffer ((AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (,s editor)
         (,s path) ((,s current-buffer) id))
       (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f (Option None)))
         0 ((,s windows) columns) ((,s windows) rows)))))

(define (expected s row)
  (define selector (fourth row))
  (case selector
    [(find) `(,s with-search (,s editor) #t "" (,s point) #f #f)]
    [(save-key) `((,s save) case
                  (None () ,(token s "failed"))
                  (Some (saved) ,(token 'saved "saved")))]
    [(set-mark kill kill-line yank) `(,s ,selector)]
    [else
     (token `(,s with-editor
                ((,s editor) ,selector ,@(if (eq? selector 'insert)
                                           (list (first row)) '())))
            "")]))

(define (same-session st actual expected)
  (def! st 'comparison-actual actual)
  (def! st 'comparison-expected expected)
  ;; Whole-value equality includes constructor payloads and actual UndoFrames.
  (same st 'comparison-actual 'comparison-expected)
  (for ([field (in-list (append session-fields '(current-buffer editor path)))])
    (same st `(comparison-actual ,field) `(comparison-expected ,field)))
  (for ([field (in-list editor-fields)])
    (same st `((comparison-actual editor) ,field)
             `((comparison-expected editor) ,field)))
  (check-equal? (ev st '((comparison-actual text) to-string))
                (ev st '((comparison-expected text) to-string)))
  (for ([size (in-list '((8 1) (12 6)))])
    (check-equal? (ev st `(comparison-actual frame ,@size))
                  (ev st `(comparison-expected frame ,@size)))))

(define (point st s)
  (def! st 'comparison-point-source s)
  (list (ev st '((comparison-point-source point) line))
        (ev st '((comparison-point-source point) column))))
(define (history-len st s) (ev st `(((,s editor) history) len)))

(define (rich! st)
  (def! st 'seed
    (session "ababa\nsecond\nababa\nfourth\nfifth\nsixth" 2 2
             #:mark '(Option Some (Position new 1 1))
             #:ring '(List of "Z\nY" "older")))
  (def! st 'base '((seed insert "!") ensure-visible 2 4))
  (check-equal? (history-len st 'base) 1)
  (check-equal? (ev st '((base editor) text-rows)) 2))

(test-case "session comparison evaluates each side once and preserves fixture bindings"
  (define-values (st calls) (state))
  (rich! st)
  (for ([name '(actual expected result saved)])
    (def! st name `(base with-echo ,(symbol->string name))))
  (define fixtures
    (for/list ([name '(actual expected result saved)])
      (cons name (ev st name))))
  (define write-call
    (list 'write "/cwd/a.txt" (ev st '((base text) to-string))))
  (set-box! calls '())
  (same-session st '(base save-key) '(base save-key))
  ;; Count after all field, text, and frame observations.
  (check-equal? (writes calls) (list write-call write-call))
  (set-box! calls '())
  (def! st 'bound-save '(base save-key))
  (check-equal? (writes calls) (list write-call))
  (define calls-after-binding (unbox calls))
  (same-session st 'bound-save 'bound-save)
  (check-equal? (unbox calls) calls-after-binding)
  (for ([fixture (in-list fixtures)])
    (check-equal? (ev st (car fixture)) (cdr fixture))))

(test-case "point evaluates its source once and preserves fixture bindings"
  (define-values (st calls) (state))
  (def! st 'base (session "abc\ndef" 1 2))
  (for ([name '(actual expected result saved)])
    (def! st name `(base with-echo ,(symbol->string name))))
  (define fixtures
    (for/list ([name '(actual expected result saved)])
      (cons name (ev st name))))
  (define write-call '(write "/cwd/a.txt" "abc\ndef"))
  (set-box! calls '())
  (check-equal? (point st '(base handle-key "save")) '(1 2))
  (check-equal? (writes calls) (list write-call))
  (set-box! calls '())
  (def! st 'bound-point-save '(base handle-key "save"))
  (check-equal? (writes calls) (list write-call))
  (define calls-after-binding (unbox calls))
  (check-equal? (point st 'bound-point-save) '(1 2))
  (check-equal? (unbox calls) calls-after-binding)
  (for ([fixture (in-list fixtures)])
    (check-equal? (ev st (car fixture)) (cdr fixture))))

(test-case "classes and constants load twice without capabilities or effects"
  (for ([i (in-range 2)])
    (define out (open-output-string))
    (define err (open-output-string))
    (define st (parameterize ([current-output-port out] [current-error-port err])
                 (loaded)))
    (check-equal? (get-output-string out) "")
    (check-equal? (get-output-string err) "")
    (for ([name (in-list '(AloemacsCommand AloemacsKeymap AloemacsBinding
                          aloemacs-self-insert-command aloemacs-save-command
                          aloemacs-ctrl-x-keymap aloemacs-global-keymap))])
      (check-true (env-bound? (driver-runtime-environment st) name))
      (check-true (type-environment-bound? (driver-type-environment st) name)))
    (for ([name (in-list '(term fs-host))])
      (check-false (env-bound? (driver-runtime-environment st) name))
      (check-false (type-environment-bound? (driver-type-environment st) name)))
    (check-equal? (type st 'aloemacs-global-keymap)
                  '(AloemacsKeymap AloemacsBinding))))

(test-case "exact command names, bindings, default, and pure application lookup"
  (define st (loaded))
  (define datums
    (call-with-input-file file-path
      (lambda (in)
        (let loop ([result '()])
          (define datum (read in))
          (if (eof-object? datum) (reverse result) (loop (cons datum result)))))))
  (define command-class
    (findf (lambda (datum) (and (eq? (car datum) 'define-class)
                               (eq? (cadr datum) 'AloemacsCommand))) datums))
  (check-equal? (caddr command-class)
    `(constructors ,@(for/list ([row (in-list command-inventory)])
                      `(,(second row) (fields)))))
  (check-equal? (map (lambda (method) (drop-right method 1)) (cdr (cadddr command-class)))
                '((name () String)))
  (for ([row (in-list command-inventory)])
    (check-equal? (ev st `((AloemacsCommand ,(second row)) name)) (third row))
    (check-equal? (type st `((AloemacsCommand ,(second row)) name)) 'String))
  (same st 'aloemacs-self-insert-command '(AloemacsCommand SelfInsert))
  (same st 'aloemacs-save-command '(AloemacsCommand Save))
  (same st '(aloemacs-global-keymap bindings)
        `(List of ,@(for/list ([row (in-list rows)])
                      `(AloemacsBinding Command ,(first row)
                                        (AloemacsCommand ,(second row))))
                  (AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap)))
  (same st '(aloemacs-global-keymap default)
        '(Option Some (AloemacsCommand SelfInsert)))
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
  (same st '(aloemacs-ctrl-x-keymap lookup "save")
        '(aloemacs-global-keymap lookup "save"))
  (check-equal? (ev st '((AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap) key))
                "ctrl-x")
  (check-equal? (type st '(AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap))
                'AloemacsBinding)
  (check-equal? (type st '(aloemacs-global-keymap lookup "ctrl-x"))
                '(Option AloemacsBinding))
  (same st '(aloemacs-global-keymap lookup "ctrl-x")
        '(Option Some (AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap)))
  (for ([row (in-list rows)])
    (define binding `(AloemacsBinding Command ,(first row)
                                    (AloemacsCommand ,(second row))))
    (check-equal? (ev st `(,binding key)) (first row))
    (check-equal? (type st `(,binding key)) 'String)
    (same st `(aloemacs-global-keymap lookup ,(first row)) `(Option Some ,binding)))
  (for ([key (in-list '("" "x" "s" "q" " " "unknown" "newline"
                          "switch-buffer" "kill-buffer"))])
    (check-equal? (type st `(aloemacs-global-keymap lookup ,key))
                  '(Option AloemacsBinding))
    (check-false (ev st `((aloemacs-global-keymap lookup ,key) present?)))))

(test-case "small maps retain source order, first duplicate, and metadata independence"
  (define-values (st calls) (state))
  (define bindings
    '(List of (AloemacsBinding Command "x" (AloemacsCommand Save))
              (AloemacsBinding Command "x" (AloemacsCommand MoveLeft))
              (AloemacsBinding Command "other" (AloemacsCommand SelfInsert))))
  (def! st 'bindings bindings)
  (def! st 'map `(AloemacsKeymap new bindings ,no-default))
  (same st '(map lookup "x")
        '(Option Some (AloemacsBinding Command "x" (AloemacsCommand Save))))
  (same st '(map lookup-in (bindings rest) "x")
        '(Option Some (AloemacsBinding Command "x" (AloemacsCommand MoveLeft))))
  (for ([key (in-list '("save" "" "X" "xx"))])
    (check-false (ev st `((map lookup ,key) present?))))
  (same st 'bindings bindings)
  (same st '(map bindings) bindings)
  (def! st 'empty-map `(AloemacsKeymap new (if #t (List empty) bindings) ,no-default))
  (check-false (ev st '((empty-map lookup "x") present?)))
  (def! st 'default-map '(AloemacsKeymap new bindings (Option Some aloemacs-save-command)))
  (check-false (ev st '((default-map lookup "s") present?)))
  (check-equal? (unbox calls) '()))

(test-case "idle dispatch uses a bound character before the map's optional default"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'base))
  (define bindings
    '(List of (AloemacsBinding Command "x" (AloemacsCommand MoveLeft))))
  ;; Replace the map only in this fresh test driver to exercise dispatch rules
  ;; the fixed production table cannot expose.
  (def! st 'aloemacs-global-keymap
    `(AloemacsKeymap new ,bindings (Option Some (AloemacsCommand Newline))))
  (same-session st '(base handle-key "x") (expected 'base (third rows)))
  (same-session st '(base handle-key "s") (expected 'base (first rows)))
  (for ([key (in-list '("" "unknown"))])
    (same-session st `(base handle-key ,key) (token 'base "")))
  (def! st 'aloemacs-global-keymap `(AloemacsKeymap new ,bindings ,no-default))
  (same-session st '(base handle-key "x") (expected 'base (third rows)))
  (same-session st '(base handle-key "s") (token 'base ""))
  (same st '(aloemacs-global-keymap bindings) bindings)
  (check-equal? (ev st 'base) original)
  (check-equal? (unbox calls) '()))

(test-case "checked execution and new session sends retain each receiver's concrete host"
  (define-values (st calls) (state))
  (def! st 'base (session "abc" 0 1))
  (attach-fs! st 'other-fs 'OtherFs)
  (def! st 'other (session "abc" 0 1 #:host 'other-fs))
  (for ([s (in-list '(base other))] [h (in-list '(FsHost OtherFs))])
    (for ([row (in-list command-inventory)])
      (check-equal? (type st `(,s execute-command (AloemacsCommand ,(second row)) "x"))
                    `(AloemacsSession ,h)))
    (for ([selector (in-list '(line-start line-end page-up page-down
                              buffer-start buffer-end undo find save-key
                              switch-buffer kill-buffer))])
      (check-equal? (type st `(,s ,selector)) `(AloemacsSession ,h)))
    (for ([send (in-list '((add-buffer "new") (add-buffer "new" (Path new "relative"))))])
      (check-equal? (type st `(,s ,@send)) `(AloemacsSession ,h)))
    (for ([constructor '(SwitchBuffer KillBuffer)])
      (define expected-buffers
        (if (eq? constructor 'SwitchBuffer) `(,s buffers)
            `(AloemacsBuffers new (List empty)
               (AloemacsBuffer new
                 (AloemacsEditor new ((Text from-string "") indexed-value)
                   (Position new 0 0) #f 0 0 (List empty) ,no-mark 0)
                 ,no-path ((,s current-buffer) id))
               (List empty))))
      (same-session st `(,s execute-command (AloemacsCommand ,constructor) "x")
        `(AloemacsSession new ,expected-buffers (,s fs) "" #f ""
           (Position new 0 0) #f #f (,s kill-ring) ,no-pending
           (,s prompt)
           (,s last-submission)
           (,s waiting-command)
     (let ((buffer (,expected-buffers current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f (Option None)))
         0 ((,s windows) columns) ((,s windows) rows))))))
    (check-equal? (type st `(,s with-echo "failed")) `(AloemacsSession ,h))
    (check-equal? (type st `(,s pending)) '(Option (AloemacsKeymap AloemacsBinding)))
    (check-equal? (type st `(,s with-prefix aloemacs-ctrl-x-keymap))
                  `(AloemacsSession ,h))
    (check-equal? (type st `(,s clear-prefix)) `(AloemacsSession ,h))
    (check-equal? (type st `(,s save)) `(Option (AloemacsSession ,h)))
    (same-session st `(,s execute-command (AloemacsCommand MoveLeft) "ignored")
                  (expected s (third rows))))
  (for ([expr (in-list '((base execute-command)
                        (base execute-command aloemacs-save-command)
                        (base execute-command aloemacs-save-command "save" "extra")
                        (base execute-command aloemacs-save-command 1)
                        (base execute-command "save" "save")
                        (base execute-command 1 "save")
                        (base execute-command (base editor) "save")
                        ((base editor) execute-command aloemacs-save-command "save")
                        (1 execute-command aloemacs-save-command "save")
                        (aloemacs-save-command execute-command aloemacs-save-command "save")
                        (AloemacsSession execute-command aloemacs-save-command "save")
                        (aloemacs-save-command run base "save")
                        (aloemacs-save-command name "save")
                        (aloemacs-global-keymap lookup 1)
                        (aloemacs-global-keymap lookup)
                        (aloemacs-global-keymap lookup "x" "y")
                        (aloemacs-global-keymap lookup-in (List of "x") "x")
                        ((AloemacsBinding Command "x" aloemacs-save-command) key "x")
                        (AloemacsBinding Command 1 aloemacs-save-command)
                        (AloemacsBinding Command "x" "save")
                        (AloemacsCommand Save "save")
                        (AloemacsCommand new "save")
                        (base with-echo 1) (base with-echo)
                        (base line-start 1) (base undo "x")
                        (base find "x") (base save-key "x")
                        (base pending "x")
                        (base with-prefix) (base with-prefix "map")
                        (base with-prefix aloemacs-save-command)
                        (base with-prefix (Option Some aloemacs-ctrl-x-keymap))
                        (base with-prefix aloemacs-ctrl-x-keymap "x")
                        (base with-prefix (AloemacsKeymap new (List of "x")
                                           (Option Some aloemacs-save-command)))
                        (base clear-prefix "x")
                        (AloemacsBinding Prefix 1 aloemacs-ctrl-x-keymap)
                        (AloemacsBinding Prefix "x" aloemacs-save-command)
                        (AloemacsBinding Prefix "x")
                        (AloemacsBinding Prefix "x" aloemacs-ctrl-x-keymap "extra")
                        ((AloemacsBinding Prefix "x" aloemacs-ctrl-x-keymap) key "x")))])
    (check-exn exn:fail:aloe-type? (lambda () (ev st expr))))
  (for ([pending (in-list '(1 aloemacs-ctrl-x-keymap
                           (Option Some "map") (Option Some aloemacs-save-command)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (ev st (session "abc" 0 1 #:pending pending)))))
  (check-exn exn:fail:aloe-type?
             (lambda () (ev st (drop-right (session "abc" 0 1) 1)))))

(test-case "all table rows reproduce independent operations and preserve source values"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'base))
  (for ([row (in-list commands)])
    (define key (first row))
    (def! st 'expected (expected 'base row))
    (set-box! calls '())
    (def! st 'actual `(base handle-key ,key))
    (same-session st 'actual 'expected)
    (if (equal? key "save")
        (check-equal? (writes calls) `((write "/cwd/a.txt" ,(ev st '((base text) to-string)))))
        (check-equal? (unbox calls) '()))
    (check-equal? (ev st 'base) original)
    (def! st 'direct `(base execute-command (AloemacsCommand ,(second row)) ,key))
    (same-session st 'direct 'actual)))

(test-case "thin wrappers preserve all payloads and echo, including no-op boundaries"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'boundary (session "" 0 0 #:mark '(Option Some (Position new 9 9))))
  (def! st 'active '(base with-search (base editor) #t "aba" (base point) #t #t))
  (for ([s (in-list '(base boundary active))])
    (for ([row (in-list (take rows 14))])
      (define selector (fourth row))
      (same-session st `(,s ,selector) `(,s with-editor ((,s editor) ,selector)))
      (check-equal? (ev st `((,s ,selector) echo)) "saved")
      (check-equal? (ev st `((,s execute-command (AloemacsCommand ,(second row)) "ignored") echo)) ""))
    (same-session st `(,s insert "X") `(,s with-editor ((,s editor) insert "X")))
    (same-session st `(,s with-echo "failed") (token s "failed")))
  (check-equal? (unbox calls) '()))

(test-case "successful and no-op edits retain mark policy and exact history frames"
  (define-values (st calls) (state))
  (for ([fixture (in-list (list (session "abc\ndef" 0 1)
                               (session "abc\ndef" 1 0)
                               (session "abc" 0 0)
                               (session "abc" 9 9)))])
    (def! st 'base fixture)
    (for ([row (in-list (list (first rows) (second rows) (last commands)))])
      (def! st 'expected (expected 'base row))
      (def! st 'actual `(base handle-key ,(first row)))
      (same-session st 'actual 'expected)))
  (def! st 'invalid (session "abc" 9 9 #:mark '(Option Some (Position new 9 9))))
  (for ([key (in-list '("x" "return" "backspace"))])
    (same-session st `(invalid handle-key ,key) (token 'invalid "")))
  (def! st 'bottom (session "abc" 0 0 #:mark '(Option Some (Position new 9 9))))
  (same-session st '(bottom handle-key "backspace") (token 'bottom ""))
  (same-session st '(bottom handle-key "undo") (token 'bottom ""))
  (def! st 'inserted '(bottom handle-key "x"))
  (check-equal? (history-len st 'inserted) 1)
  (same st '((inserted editor) mark) '((bottom editor) mark))
  (same st '((inserted editor) history)
        '(List of (UndoFrame new (bottom text) (bottom point) 2 3)))
  (same-session st '(inserted handle-key "undo") (token 'bottom ""))
  (check-equal? (unbox calls) '()))

(test-case "fitted page commands use remembered rows and all six motions keep history"
  (define-values (st calls) (state))
  (rich! st)
  (for ([row (in-list (take (drop rows 6) 6))])
    (same-session st `(base handle-key ,(first row)) (expected 'base row))
    (same st `(((base handle-key ,(first row)) editor) history) '((base editor) history)))
  (check-equal? (point st '(base handle-key "page-up")) '(1 3))
  (check-equal? (point st '(base handle-key "page-down")) '(3 3))
  (def! st 'unfit (session "abc\ndef" 0 1))
  (same-session st '(unfit handle-key "page-down") (token 'unfit ""))
  (def! st 'one-row '(unfit ensure-visible 8 1))
  (check-equal? (point st '(one-row handle-key "page-down")) '(1 1)))

(test-case "mark and ring commands preserve no-op decisions and sources"
  (define-values (st calls) (state))
  (for ([fixture (in-list (list (session "ab\ncd" 0 1)
                               (session "ab\ncd" 0 1 #:mark '(Option Some (Position new 0 1)))
                               (session "ab" 0 2 #:ring '(List of "Z"))
                               (session "ab" 9 9 #:mark '(Option Some (Position new 9 9))
                                        #:ring '(List of "Z"))))])
    (def! st 'base fixture)
    (for ([row (in-list (take (drop rows 14) 4))])
      (same-session st `(base handle-key ,(first row)) (expected 'base row)))
    (same st 'base fixture))
  (check-equal? (unbox calls) '()))

(test-case "find preserves both tokens; save writes once, preserves payload, and raises failures"
  (define-values (st calls) (state))
  (for ([echo (in-list '("saved" "failed"))])
    (def! st 'base (session "a\r\nb\n" 1 0 #:echo echo))
    (same-session st '(base handle-key "find") (expected 'base (list-ref rows 18)))
    (check-equal? (ev st '((base handle-key "find") echo)) echo))
  (for ([path (in-list (list '(Option Some (Path new "/cwd/a.txt"))
                            '(Option Some (Path new "/cwd/new.txt"))
                            no-path '(Option Some (Path new "/cwd/dir"))))]
        [echo (in-list '("saved" "saved" "failed" "failed"))])
    (def! st 'base (session "a\r\nb\n" 1 0 #:path path #:ring '(List of "Z")))
    (set-box! calls '())
    (def! st 'actual '(base handle-key "save"))
    (same-session st 'actual (token 'base echo))
    (check-equal? (length (writes calls)) (if (equal? echo "saved") 1 0))
    (when (equal? echo "saved")
      (check-equal? (third (car (writes calls))) "a\r\nb\n"))
    (set-box! calls '())
    (def! st 'direct '(base save-key))
    (same-session st 'direct 'actual)
    (check-equal? (length (writes calls)) (if (equal? echo "saved") 1 0))
    (same st 'base (session "a\r\nb\n" 1 0 #:path path #:ring '(List of "Z"))))
  (define failing (loaded))
  (define failures (attach-fs! failing #:fail-write? #t))
  (def! failing 'base (session "draft" 0 0))
  (check-exn exn:fail:aloe-host? (lambda () (ev failing '(base handle-key "save"))))
  (check-equal? (writes failures) '((write "/cwd/a.txt" "draft"))))

(test-case "self-insert uses its argument; plain letters, control input, and misses retain old results"
  (define-values (st calls) (state))
  (rich! st)
  (for ([key (in-list '("x" "s" "q" " " "\u001b"))])
    (same-session st `(base handle-key ,key)
                  (token `(base with-editor ((base editor) insert ,key)) "")))
  (same-session st '(base execute-command aloemacs-self-insert-command "XY")
                (token '(base with-editor ((base editor) insert "XY")) ""))
  (for ([key (in-list '("" "unknown" "newline"))])
    (same-session st `(base handle-key ,key) (token 'base "")))
  (same-session st '(base handle-key "ctrl-x")
                (prefix-state 'base '(Option Some aloemacs-ctrl-x-keymap) ""))
  (check-equal? (unbox calls) '()))

(test-case "quit absorbs all keys before search and filesystem effects"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'quit '((base with-search (base editor) #t "aba" (base point) #t #t)
                  request-quit))
  (set-box! calls '())
  (for ([key (in-list (append (map first commands) '("" "unknown" "ctrl-x")))])
    (same-session st `(quit handle-key ,key) 'quit))
  (check-equal? (unbox calls) '()))

(test-case "search owns query keys and resets before motion, save, undo, kill, or rejected input"
  (define-values (st calls) (state))
  (def! st 'seed (session "ababa\nsecond\nababa" 0 0
                         #:mark '(Option Some (Position new 0 0)) #:ring '(List of "Z")))
  (def! st 'base '((seed insert "!") ensure-visible 8 4))
  (def! st 'entry '(base handle-key "find"))
  (def! st 'query '(entry handle-key "a"))
  (check-equal? (ev st '(query query)) "a")
  (check-equal? (point st 'query) '(0 1))
  (def! st 'next '(query handle-key "find"))
  (check-equal? (point st 'next) '(0 3))
  (def! st 'back '(next handle-key "backspace"))
  (check-equal? (ev st '(back query)) "")
  (same st '((query editor) history) '((base editor) history))
  (same st '((next editor) history) '((base editor) history))
  (for ([key (in-list '("escape" "return"))])
    (same-session st `(next handle-key ,key) '(next end-search))
    (check-false (ev st `((next handle-key ,key) quit)))
    (check-equal? (ev st `((next handle-key ,key) echo)) "saved"))
  (for ([row (in-list (filter (lambda (row)
                               (member (first row) '("left" "page-down" "save" "undo" "kill")))
                             rows))])
    (def! st 'expected (expected '(next end-search) row))
    (set-box! calls '())
    (def! st 'actual `(next handle-key ,(first row)))
    (same-session st 'actual 'expected)
    (check-false (ev st '(actual searching)))
    (check-equal? (ev st '(actual query)) "")
    (same st '(actual origin) '(Position new 0 0))
    (check-false (ev st '(actual wrapped)))
    (check-false (ev st '(actual failing)))
    (check-equal? (length (writes calls)) (if (equal? (first row) "save") 1 0)))
  (same-session st '(next handle-key "\u001b")
                (token '((next end-search) with-editor ((next editor) insert "\u001b")) "")))

(test-case "fresh sessions and the checked main start without a prefix"
  (define-values (st calls) (state))
  (def! st 'base (session "abc" 0 1))
  (check-false (ev st '((base pending) present?)))
  (ev st `(load ,(path->string main-path)))
  (check-equal? (type st '(aloemacs-editor pending))
                '(Option (AloemacsKeymap AloemacsBinding)))
  (check-false (ev st '((aloemacs-editor pending) present?)))
  (check-equal? (unbox calls) '()))

(test-case "Prefix lookup returns immutable data without arming or descending"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'base))
  (define global (ev st 'aloemacs-global-keymap))
  (define nested (ev st 'aloemacs-ctrl-x-keymap))
  (def! st 'prefix '(AloemacsBinding Prefix "p" aloemacs-ctrl-x-keymap))
  (def! st 'bindings '(List of prefix (AloemacsBinding Command "p" aloemacs-save-command)))
  (def! st 'map `(AloemacsKeymap new bindings ,no-default))
  (same st '(map lookup "p") '(Option Some prefix))
  (check-false (ev st '((map lookup "save") present?)))
  (same st '(map bindings)
        '(List of prefix (AloemacsBinding Command "p" aloemacs-save-command)))
  (same st '(prefix case (Command (key command) aloemacs-global-keymap)
                        (Prefix (key map) map))
        'aloemacs-ctrl-x-keymap)
  (check-equal? (ev st 'base) original)
  (check-equal? (ev st 'aloemacs-global-keymap) global)
  (check-equal? (ev st 'aloemacs-ctrl-x-keymap) nested)
  (check-equal? (unbox calls) '()))

(test-case "prefix helpers preserve every other field and clear keeps echo"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'active '(base with-search (base editor) #t "aba" (base point) #t #t))
  (for ([source (in-list '(base active))])
    (def! st 'armed `(,source with-prefix aloemacs-ctrl-x-keymap))
    (same-session st 'armed (prefix-state source '(Option Some aloemacs-ctrl-x-keymap) ""))
    (same-session st '((armed with-echo "failed") clear-prefix)
                  (prefix-state source no-pending "failed")))
  (check-equal? (unbox calls) '()))

(test-case "armed ordinary rebuilds, direct wrappers, search, kill, and save preserve pending"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'armed (prefix-state 'base '(Option Some aloemacs-ctrl-x-keymap)))
  (for ([operation
         (in-list '((with-editor (base editor))
                    (with-echo "failed")
                    (with-kill-state (base editor) (base kill-ring))
                    (with-search (base editor) #t "aba" (base point) #t #t)
                    (insert "X") (newline) (backward-delete)
                    (move-left) (move-right) (move-up) (move-down)
                    (line-start) (line-end) (page-up) (page-down)
                    (buffer-start) (buffer-end) (undo) (request-quit)
                    (set-mark) (kill) (kill-line) (yank)
                    (kill-span (Span new (Position new 0 0) (Position new 0 1)) #f)
                    (find) (end-search) (search-hit "aba" (Position new 0 0) #t)
                    (search-miss "missing") (seek-from (base point) "aba")))])
    (def! st 'expected `(base ,@operation))
    (def! st 'actual `(armed ,@operation))
    (same-session st 'actual (prefix-state 'expected '(armed pending))))
  (def! st 'saved '((armed save) case (None () armed) (Some (session) session)))
  (same-session st 'saved 'armed)
  (check-equal? (writes calls) `((write "/cwd/a.txt" ,(ev st '((armed text) to-string)))))
  (def! st 'save-key '(armed save-key))
  (same-session st 'save-key (token 'armed "saved"))
  (def! st 'untitled (session "draft" 0 0 #:path no-path
                             #:pending '(Option Some aloemacs-ctrl-x-keymap)))
  (same-session st '(untitled save-key) (token 'untitled "failed")))

(test-case "fit and frame preserve the armed map before the next key"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'armed '(base handle-key "ctrl-x"))
  (define original (ev st 'armed))
  (def! st 'expected '(base ensure-visible 3 2))
  (def! st 'fitted '(armed ensure-visible 3 2))
  (same-session st 'fitted (prefix-state 'expected '(armed pending) ""))
  (define fitted (ev st 'fitted))
  (check-equal? (ev st '(fitted frame 3 2)) (ev st `(,(token 'expected "") frame 3 2)))
  (check-equal? (ev st 'fitted) fitted)
  (check-equal? (ev st 'armed) original)
  (def! st 'result '(fitted handle-key "save"))
  (same-session st 'result (token 'expected "saved"))
  (check-equal? (length (writes calls)) 1))

(test-case "successful existing and missing visits reset pending; rejection retains source"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'armed '(base with-prefix aloemacs-ctrl-x-keymap))
  (define original (ev st 'armed))
  (for ([path (in-list '("a.txt" "missing.txt"))]
        [contents (in-list '("original" ""))])
    (def! st 'result `((armed visit (Path new ,path)) case
                      (None () armed) (Some (session) session)))
    (same-session st 'result
      `(AloemacsSession new
         (AloemacsBuffers new
           (List empty)
           (AloemacsBuffer new
             (AloemacsEditor new ((Text from-string ,contents) indexed-value)
                                 (Position new 0 0) #f 0 0 (List empty) ,no-mark 0)
             (Option Some (Path new ,(string-append "/cwd/" path))) ((armed current-buffer) id))
           (List empty))
         (armed fs)
         ""
         #f
         ""
         (Position new 0 0)
         #f
         #f
         (List empty)
         ,no-pending
         (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
         (armed last-submission)
         (armed waiting-command)
     (let ((buffer ((AloemacsBuffers new
           (List empty)
           (AloemacsBuffer new
             (AloemacsEditor new ((Text from-string ,contents) indexed-value)
                                 (Position new 0 0) #f 0 0 (List empty) ,no-mark 0)
             (Option Some (Path new ,(string-append "/cwd/" path))) ((armed current-buffer) id))
           (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f (Option None)))
         0 ((armed windows) columns) ((armed windows) rows)))))
    (check-false (ev st '((result pending) present?))))
  (check-false (ev st '((armed visit (Path new "dir")) present?)))
  (same-session st '((armed visit (Path new "dir")) case
                     (None () armed) (Some (session) session)) 'armed)
  (check-equal? (ev st 'armed) original)
  (check-equal? (writes calls) '()))
