#lang racket/base

(require racket/list
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/host.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define no-pending '(if #t (Option None) (Option Some aloemacs-global-keymap)))
(define no-path '(if #t (Option None) (Option Some (Path new "/unused"))))
(define no-default '(if #t (Option None) (Option Some aloemacs-self-insert-command)))
(define session-fields '(buffers fs echo searching query origin wrapped failing kill-ring pending))
(define editor-fields '(text point quit scroll-row scroll-col history mark text-rows))

(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (same st actual expected)
  (check-not-exn (lambda () (ev st `(check ,actual ,expected)))))
(define (same-session st actual expected)
  (same st actual expected)
  (for ([field (in-list (append session-fields '(current-buffer editor path)))])
    (same st `(,actual ,field) `(,expected ,field)))
  (for ([field (in-list editor-fields)])
    (same st `((,actual editor) ,field) `((,expected editor) ,field)))
  (for ([size (in-list '((8 1) (20 4)))])
    (check-equal? (ev st `(,actual frame ,@size)) (ev st `(,expected frame ,@size)))))

;; Expected construction is independent of with-prefix/clear-prefix/dispatch.
(define (rebuild s pending echo [editor `(,s editor)])
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         ,editor
         (,s path))
       (List empty))
     (,s fs)
     ,echo
     (,s searching)
     (,s query)
     (,s origin)
     (,s wrapped)
     (,s failing)
     (,s kill-ring)
     ,pending))

(define (fixture [path '(Option Some (Path new "/cwd/a.txt"))] [echo "saved"])
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new
            (Text from-string "ababa\nsecond\nababa\nfourth\nfifth")
            (Position new 2 3) #f 2 2 (List empty)
            (Option Some (Position new 1 1)) 3)
         ,path)
       (List empty))
     (Fs new fs-host)
     ,echo
     #f
     "old query"
     (Position new 4 2)
     #t
     #t
     (List of "Z\nY" "older")
     ,no-pending))

(define (state #:fail-write? [fail-write? #f])
  (define st (make-driver))
  (ev st `(load ,(path->string file-path)))
  (define inner
    (make-fs-double "/cwd"
                    (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/dir" 'directory)
                    (hash "/cwd/a.txt" "original")))
  (define calls (box '()))
  (define (forward selector args)
    (set-box! calls (cons (cons selector args) (unbox calls)))
    (when (and fail-write? (eq? selector 'write))
      (error 'keymap-prefix "write failed"))
    (host-receiver-send inner selector args))
  (define interface
    (make-host-interface
     'FsHost
     (for/list ([method (in-list (host-interface-methods fs-interface))])
       (define selector (host-method-selector method))
       (define params (host-method-parameter-types method))
       (make-host-method
        selector params (host-method-return-type method)
        (case (length params)
          [(0) (lambda (state) (forward selector '()))]
          [(1) (lambda (state a) (forward selector (list a)))]
          [(2) (lambda (state a b) (forward selector (list a b)))])))))
  (driver-inject-host! st 'fs-host (make-host-receiver interface #f))
  (values st calls))
(define (writes calls)
  (reverse (filter (lambda (call) (eq? (car call) 'write)) (unbox calls))))
(define (rich! st [path '(Option Some (Path new "/cwd/a.txt"))] [echo "saved"])
  (def! st 'seed (fixture path echo))
  (def! st 'base '(seed insert "!")))

(define (frame body row column rows label)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H" body
   (format "\u001b[~a;~aH\u001b[?25h" row column)
   (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;~aH\u001b[?25h"
           rows label row column)))

(test-case "arming changes only pending and echo, without effects or history"
  (define-values (st calls) (state))
  (for ([echo (in-list '("saved" "failed"))])
    (rich! st '(Option Some (Path new "/cwd/a.txt")) echo)
    (define original (ev st 'base))
    (define global (ev st 'aloemacs-global-keymap))
    (define nested (ev st 'aloemacs-ctrl-x-keymap))
    (def! st 'armed '(base handle-key "ctrl-x"))
    (same-session st 'armed (rebuild 'base '(Option Some aloemacs-ctrl-x-keymap) ""))
    (check-equal? (ev st '(((armed editor) history) len)) 1)
    (check-equal? (ev st 'base) original)
    (check-equal? (ev st 'aloemacs-global-keymap) global)
    (check-equal? (ev st 'aloemacs-ctrl-x-keymap) nested)
    (check-equal? (unbox calls) '())))

(test-case "prefix save equals plain save in every payload and frame for all outcomes"
  (define-values (st calls) (state))
  (for ([path (in-list (list '(Option Some (Path new "/cwd/a.txt"))
                            '(Option Some (Path new "/cwd/new.txt"))
                            no-path '(Option Some (Path new "/cwd/dir"))
                            '(Option Some (Path new "/cwd/absent/a.txt"))))]
        [echo (in-list '("saved" "saved" "failed" "failed" "failed"))])
    (rich! st path "failed")
    (define original (ev st 'base))
    (set-box! calls '())
    (def! st 'armed '(base handle-key "ctrl-x"))
    (check-equal? (unbox calls) '())
    (def! st 'result '(armed handle-key "save"))
    (same-session st 'result (rebuild 'base no-pending echo))
    (check-false (ev st '((result pending) present?)))
    (check-equal? (length (writes calls)) (if (equal? echo "saved") 1 0))
    (when (equal? echo "saved")
      (check-equal? (third (car (writes calls))) (ev st '((base text) to-string))))
    (set-box! calls '())
    (def! st 'plain '(base handle-key "save"))
    (same-session st 'result 'plain)
    (check-equal? (length (writes calls)) (if (equal? echo "saved") 1 0))
    (check-equal? (ev st 'base) original)
    (same st '(armed pending) '(Option Some aloemacs-ctrl-x-keymap))))

(test-case "prefix save preserves exact CRLF Unicode BOM and final newline, and raises host failures"
  (define-values (st calls) (state))
  (def! st 'base
    `(AloemacsSession new
       (AloemacsBuffers new
         (List empty)
         (AloemacsBuffer new
           (AloemacsEditor new (Text from-string "\uFEFFλ\r\nb\n")
                               (Position new 1 0) #f 0 0 (List empty)
                               (if #t (Option None) (Option Some (Position new 0 0))) 0)
           (Option Some (Path new "/cwd/a.txt")))
         (List empty))
       (Fs new fs-host)
       "saved"
       #f
       ""
       (Position new 0 0)
       #f
       #f
       (List empty)
       ,no-pending))
  (def! st 'result '((base handle-key "ctrl-x") handle-key "save"))
  (check-equal? (writes calls) '((write "/cwd/a.txt" "\uFEFFλ\r\nb\n")))
  (same-session st 'result (rebuild 'base no-pending "saved"))
  (define-values (failing failures) (state #:fail-write? #t))
  (rich! failing)
  (def! failing 'armed '(base handle-key "ctrl-x"))
  (check-equal? (unbox failures) '())
  (check-exn exn:fail:aloe-host? (lambda () (ev failing '(armed handle-key "save"))))
  (check-equal? (length (writes failures)) 1)
  (same failing '(armed pending) '(Option Some aloemacs-ctrl-x-keymap)))

(test-case "every non-save second key is consumed once; the following key dispatches globally"
  (define-values (st calls) (state))
  (rich! st)
  (define original (ev st 'base))
  (def! st 'armed '(base handle-key "ctrl-x"))
  (define armed (ev st 'armed))
  (for ([key (in-list '("x" "s" "left" "escape" "find" "undo" "return" "mark"
                        "unknown" "" "ctrl-x" "kill" "kill-line" "yank"))])
    (set-box! calls '())
    (def! st 'cancel `(armed handle-key ,key))
    (same-session st 'cancel (rebuild 'base no-pending ""))
    (check-false (ev st '((cancel pending) present?)))
    (check-false (ev st '(cancel quit)))
    (check-false (ev st '(cancel searching)))
    (check-equal? (ev st '(((cancel editor) history) len)) 1)
    (def! st 'next '(cancel handle-key "x"))
    (same-session st 'next (rebuild 'cancel no-pending "" '((cancel editor) insert "x")))
    (check-equal? (ev st '(((next editor) history) len)) 2)
    (check-equal? (unbox calls) '())
    (check-equal? (ev st 'base) original)
    (check-equal? (ev st 'armed) armed))
  (def! st 'cancel '(armed handle-key "escape"))
  (same-session st '(cancel handle-key "escape")
                (rebuild 'cancel no-pending "" '((cancel editor) request-quit)))
  (check-true (ev st '((cancel handle-key "escape") quit))))

(test-case "active search owns its keys, then Ctrl-X resets search before arming and saving"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'entry '(base find))
  (def! st 'active '(entry handle-key "a"))
  (for ([key (in-list '("x" "backspace" "find" "return" "escape"))])
    (same-session st `(active handle-key ,key) `(active search-key ,key)))
  (def! st 'armed '(active handle-key "ctrl-x"))
  (same-session st 'armed
                (rebuild '(active end-search) '(Option Some aloemacs-ctrl-x-keymap) ""))
  (check-false (ev st '(armed searching)))
  (check-equal? (ev st '(armed query)) "")
  (same st '(armed origin) '(Position new 0 0))
  (check-false (ev st '(armed wrapped)))
  (check-false (ev st '(armed failing)))
  (same st '((armed editor) history) '((base editor) history))
  (check-equal? (unbox calls) '())
  (def! st 'result '(armed handle-key "save"))
  (same-session st 'result (rebuild '(active end-search) no-pending "saved"))
  (check-equal? (length (writes calls)) 1)
  ;; Direct helpers can preserve a prefix into search. Search still wins.
  (def! st 'pending-search '(armed find))
  (def! st 'query '(pending-search handle-key "a"))
  (check-true (ev st '(query searching)))
  (check-equal? (ev st '(query query)) "a")
  (same st '(query pending) '(armed pending))
  (same-session st '(query handle-key "escape") '(query end-search)))

(test-case "quit absorbs prefix and save before search or effects, preserving even armed state"
  (define-values (st calls) (state))
  (rich! st)
  (for ([source (in-list '(base (base with-prefix aloemacs-ctrl-x-keymap)))])
    (def! st 'quit `((,source find) request-quit))
    (define original (ev st 'quit))
    (for ([key (in-list '("ctrl-x" "save" "x" "find" "escape"))])
      (same-session st `(quit handle-key ,key) 'quit))
    (check-equal? (ev st 'quit) original)
    (check-equal? (unbox calls) '())))

(test-case "pending lookup ignores defaults, replaces nested Prefix data, and clears before no-op commands"
  (define-values (st calls) (state))
  (rich! st)
  (def! st 'map
    '(AloemacsKeymap new
       (List of (AloemacsBinding Prefix "next" aloemacs-ctrl-x-keymap)
                (AloemacsBinding Command "x" (AloemacsCommand MoveLeft)))
       (Option Some aloemacs-save-command)))
  (def! st 'armed '(base with-prefix map))
  (define original (ev st 'map))
  (same-session st '(armed handle-key "s") (rebuild 'base no-pending ""))
  (check-equal? (unbox calls) '())
  (same-session st '(armed handle-key "next")
                (rebuild 'base '(Option Some aloemacs-ctrl-x-keymap) ""))
  (same-session st '(armed handle-key "x")
                (rebuild 'base no-pending "" '((base editor) move-left)))
  (def! st 'boundary
    (rebuild 'base no-pending "failed"
             '(AloemacsEditor new (Text from-string "") (Position new 0 0)
                                 #f 2 3 (List empty) (Option Some (Position new 9 9)) 3)))
  (def! st 'pending '(boundary with-prefix map))
  (same-session st '(pending execute-command (AloemacsCommand MoveLeft) "x")
                (rebuild 'pending '(pending pending) ""))
  (same-session st '(pending handle-key "x") (rebuild 'boundary no-pending ""))
  (check-equal? (ev st 'map) original)
  (check-equal? (unbox calls) '()))

(test-case "exact frames and history survive arm, resize, save, and cancel including one row"
  (define-values (st calls) (state))
  (def! st 'base
    `(AloemacsSession new
       (AloemacsBuffers new
         (List empty)
         (AloemacsBuffer new
           (AloemacsEditor new (Text from-string "a\u001bb\nsecond")
                               (Position new 0 2) #f 0 0 (List empty)
                               (Option Some (Position new 0 0)) 0)
           (Option Some (Path new "/cwd/a.txt")))
         (List empty))
       (Fs new fs-host)
       "failed"
       #f
       ""
       (Position new 0 0)
       #f
       #f
       (List of "ring")
       ,no-pending))
  (def! st 'armed '((base handle-key "ctrl-x") ensure-visible 20 4))
  (check-equal? (ev st '(armed frame 20 4))
                (frame "a b\r\nsecond\r\n" 1 3 4 "/cwd/a.txt"))
  (def! st 'small '(armed ensure-visible 2 2))
  (check-equal? (ev st '(small frame 2 2)) (frame " b" 1 2 2 "/c"))
  (same st '(small pending) '(armed pending))
  (def! st 'saved '(small handle-key "save"))
  (check-equal? (ev st '(saved frame 2 2)) (frame " b" 1 2 2 "sa"))
  (def! st 'cancel '(armed handle-key "return"))
  (check-equal? (ev st '(cancel frame 20 4))
                (frame "a b\r\nsecond\r\n" 1 3 4 "/cwd/a.txt"))
  (def! st 'one-row '(armed ensure-visible 2 1))
  (define expected "\u001b[?25l\u001b[2J\u001b[H b\u001b[1;2H\u001b[?25h")
  (check-equal? (ev st '(one-row frame 2 1)) expected)
  (def! st 'one-save '(one-row handle-key "save"))
  (check-equal? (ev st '(one-save frame 2 1)) expected)
  (check-equal? (ev st '(one-save echo)) "saved")
  (check-false (ev st '((one-save pending) present?)))
  (def! st 'one-cancel '(one-row handle-key "x"))
  (check-equal? (ev st '(one-cancel frame 2 1)) expected)
  (same-session st 'one-cancel (rebuild 'one-row no-pending ""))
  (for ([s (in-list '(armed small saved cancel one-row one-save one-cancel))])
    (same st `((,s editor) history) '((base editor) history)))
  (check-equal? (writes calls) '((write "/cwd/a.txt" "a\u001bb\nsecond")
                               (write "/cwd/a.txt" "a\u001bb\nsecond"))))
