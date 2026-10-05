#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

(define no-mark '(if #t (Option None) (Option Some (Position new 0 0))))
(define no-path '(if #t (Option None) (Option Some (Path new "/unused"))))

(define (state [main? #f])
  (define st (make-driver))
  (driver-inject-host! st 'fs-host
                       (make-fs-double
                        "/cwd"
                        (hash "/cwd" 'directory "/cwd/a.txt" 'file)
                        (hash "/cwd/a.txt" "visited\ntext")))
  (driver-eval! st `(load ,(path->string (if main? main-path file-path))))
  st)

(define (session source line column #:mark [mark no-mark]
                 #:ring [ring '(List empty)] #:echo [echo ""]
                 #:scroll-row [scroll-row 0] #:scroll-col [scroll-col 0]
                 #:path [path no-path])
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new (Text from-string ,source)
                             (Position new ,line ,column) #f
                             ,scroll-row ,scroll-col (List empty) ,mark 0)
         ,path 0)
       (List empty))
     (Fs new fs-host)
     ,echo
     #f
     ""
     (Position new 0 0)
     #f
     #f
     ,ring
     (if #t (Option None) (Option Some aloemacs-global-keymap))
     (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty))))
     (if #t (Option None) (Option Some ""))
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer ((AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new (Text from-string ,source)
                             (Position new ,line ,column) #f
                             ,scroll-row ,scroll-col (List empty) ,mark 0)
         ,path 0)
       (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 0 0))))

(define (ev st expr) (driver-eval! st expr))
(define (def! st name expr) (ev st `(define ,name ,expr)))
(define (key! st name from key) (def! st name `(,from handle-key ,key)))
(define (same st a b) (check-not-exn (lambda () (ev st `(check ,a ,b)))))
(define (type st expr)
  (type->datum (type-of (parse-datum expr) (driver-type-environment st))))
(define (point st name)
  (list (ev st `((,name point) line)) (ev st `((,name point) column))))
(define (text st name) (ev st `((,name text) to-string)))
(define (mark-position st name)
  (ev st `(((,name editor) mark) case
           (None () "none")
           (Some (p) (((p line) text) append
                      (":" append ((p column) text)))))))
(define (ring st name)
  (ev st `((,name kill-ring) fold "" (fn (acc entry)
                                      ((acc append "|") append entry)))))
(define (history st name) (ev st `(((,name editor) history) len)))

(test-case "checked fields, construction, mark replacement, preservation, and visit reset"
  (define st (state #t))
  (check-equal? (type st '((aloemacs-editor editor) mark)) '(Option Position))
  (check-equal? (type st '(aloemacs-editor kill-ring)) '(List String))
  (check-equal? (mark-position st 'aloemacs-editor) "none")
  (check-equal? (ring st 'aloemacs-editor) "")
  (check-exn exn:fail:aloe-type?
             (lambda () (ev st '(AloemacsEditor new (Text from-string "")
                                     (Position new 0 0) #f 0 0 (List empty)))))
  (check-exn exn:fail:aloe-type?
             (lambda () (ev st '(AloemacsSession new
                                   (aloemacs-editor editor) (aloemacs-editor fs)
                                   (aloemacs-editor path) "" #f ""
                                   (Position new 0 0) #f #f))))
  (check-exn exn:fail:aloe-type?
             (lambda () (ev st `(AloemacsEditor new (Text from-string "")
                                      (Position new 0 0) #f 0 0 (List empty)
                                      "wrong"))))
  (check-exn exn:fail:aloe-type?
             (lambda () (ev st '(AloemacsSession new
                                  (AloemacsBuffers new
                                    (List empty)
                                    (AloemacsBuffer new
                                      (aloemacs-editor editor)
                                      (aloemacs-editor path) ((aloemacs-editor current-buffer) id))
                                    (List empty))
                                  (aloemacs-editor fs)
                                  ""
                                  #f
                                  ""
                                  (Position new 0 0)
                                  #f
                                  #f
                                  "wrong"
                                  (if #t (Option None) (Option Some aloemacs-global-keymap))
                                  (aloemacs-editor prompt)
                                  (aloemacs-editor last-submission)
                                  (aloemacs-editor waiting-command)
     (let ((buffer ((AloemacsBuffers new
                                    (List empty)
                                    (AloemacsBuffer new
                                      (aloemacs-editor editor)
                                      (aloemacs-editor path) ((aloemacs-editor current-buffer) id))
                                    (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f))
         0 ((aloemacs-editor windows) columns) ((aloemacs-editor windows) rows)))))))
  (def! st 'base (session "ab\ncd" 0 0))
  (key! st 'marked 'base "mark")
  (check-equal? (mark-position st 'marked) "0:0")
  (check-equal? (history st 'marked) 0)
  (key! st 'moved 'marked "right")
  (key! st 'replaced 'moved "mark")
  (check-equal? (mark-position st 'replaced) "0:1")
  (def! st 'editor-rebuilt '((replaced editor) with-text-and-point
                             (replaced text) (Position new 0 2)))
  (check-equal? (mark-position st '(replaced with-editor editor-rebuilt)) "0:1")
  (def! st 'visible '(replaced ensure-visible 1 1))
  (check-equal? (mark-position st 'visible) "0:1")
  (same st '(visible kill-ring) '(base kill-ring))
  (def! st 'searched '(visible handle-key "find"))
  (def! st 'ended '(searched handle-key "escape"))
  (check-equal? (mark-position st 'ended) "0:1")
  (def! st 'visited '((ended visit (Path new "a.txt")) case
                      (None () ended) (Some (s) s)))
  (check-equal? (mark-position st 'visited) "none")
  (check-equal? (ring st 'visited) ""))

(test-case "nonempty ring survives session rebuilds and visit clears it"
  (define st (state))
  (define supplied '(List of "older" "newest"))
  (def! st 'base (session "abc" 0 1 #:ring supplied
                          #:mark '(Option Some (Position new 0 0))))
  (def! st 'edited '(base insert "X"))
  (def! st 'wrapped '(edited with-editor (edited editor)))
  (def! st 'fitted '(wrapped ensure-visible 2 2))
  (def! st 'searching '(fitted handle-key "find"))
  (def! st 'ended '(searching handle-key "escape"))
  (def! st 'saved '(ended handle-key "save"))
  (for ([name (in-list '(base edited wrapped fitted searching ended saved))])
    (check-equal? (ring st name) "|older|newest")
    (check-equal? (mark-position st name) "0:0"))
  (def! st 'visited '((saved visit (Path new "a.txt")) case
                      (None () saved) (Some (s) s)))
  (check-equal? (ring st 'visited) "")
  (check-equal? (mark-position st 'visited) "none")
  (def! st 'named (session "abc" 0 1 #:ring supplied
                           #:mark '(Option Some (Position new 0 0))
                           #:path '(Option Some (Path new "/cwd/a.txt"))))
  (key! st 'saved-successfully 'named "save")
  (check-equal? (ev st '(saved-successfully echo)) "saved")
  (check-equal? (ring st 'saved-successfully) "|older|newest")
  (check-equal? (mark-position st 'saved-successfully) "0:0"))

(test-case "region ordering, empty and absent marks, ring order, undo, and yank"
  (define st (state))
  (def! st 'base (session "ab\ncd\nef" 0 1 #:scroll-row 2 #:scroll-col 3))
  (key! st 'no-mark 'base "kill")
  (same st '(no-mark editor) '(base editor))
  (check-equal? (history st 'no-mark) 0)
  (key! st 'marked 'base "mark")
  (key! st 'down 'marked "down")
  (key! st 'forward 'down "kill")
  (check-equal? (text st 'forward) "ad\nef")
  (check-equal? (point st 'forward) '(0 1))
  (check-equal? (mark-position st 'forward) "none")
  (check-equal? (ring st 'forward) "|b\nc")
  (check-equal? (history st 'forward) 1)
  (def! st 'scrolled '(forward ensure-visible 1 1))
  (check-equal? (ev st '((scrolled editor) scroll-row)) 0)
  (check-equal? (ev st '((scrolled editor) scroll-col)) 1)
  (key! st 'undone 'scrolled "undo")
  (check-equal? (text st 'undone) "ab\ncd\nef")
  (check-equal? (point st 'undone) '(1 1))
  (check-equal? (ev st '((undone editor) scroll-row)) 2)
  (check-equal? (ev st '((undone editor) scroll-col)) 3)
  (check-equal? (mark-position st 'undone) "none")
  (check-equal? (ring st 'undone) "|b\nc")
  (key! st 'yanked 'undone "yank")
  (check-equal? (text st 'yanked) "ab\ncb\ncd\nef")
  (check-equal? (ring st 'yanked) "|b\nc")
  (check-equal? (history st 'yanked) 1)
  (key! st 'empty-region 'marked "kill")
  (same st '(empty-region editor) '(marked editor))
  (check-equal? (ring st 'empty-region) "")
  (def! st 'back-base (session "ab\ncd\nef" 1 1))
  (key! st 'back-marked 'back-base "mark")
  (key! st 'back-up 'back-marked "up")
  (key! st 'backward 'back-up "kill")
  (check-equal? (text st 'backward) "ad\nef")
  (check-equal? (ring st 'backward) "|b\nc")
  (check-equal? (point st 'backward) '(0 1)))

(test-case "invalid and empty spans and no-op kills retain editor and ring"
  (define st (state))
  (def! st 'base (session "ab\ncd" 0 1 #:ring '(List of "prior")
                          #:mark '(Option Some (Position new 9 9))
                          #:echo "saved"))
  (for ([selected-span
         (in-list '((Span new (Position new 0 1) (Position new 0 1))
                    (Span new (Position new 1 2) (Position new 0 0))
                    (Span new (Position new 0 0) (Position new 9 0))))]
        [name (in-list '(empty-span reversed-span out-of-range-span))])
    (def! st name `(base kill-span ,selected-span #t))
    (same st `(,name editor) '(base editor))
    (same st `(,name kill-ring) '(base kill-ring))
    (check-equal? (ev st `(,name echo)) "")
    (check-equal? (history st name) 0)
    (check-equal? (mark-position st name) "9:9"))
  (def! st 'invalid-mark (session "ab" 0 0
                                  #:mark '(Option Some (Position new 9 9))))
  (key! st 'invalid-kill 'invalid-mark "kill")
  (same st '(invalid-kill editor) '(invalid-mark editor))
  (check-equal? (mark-position st 'invalid-kill) "9:9"))

(test-case "kill-line suffix, newline, boundaries, newest-first ring, and mark validity"
  (define st (state))
  (def! st 'base (session "abc\ndef\n" 0 1))
  (key! st 'marked 'base "mark")
  (key! st 'suffix 'marked "kill-line")
  (check-equal? (text st 'suffix) "a\ndef\n")
  (check-equal? (ring st 'suffix) "|bc")
  (check-equal? (mark-position st 'suffix) "0:1")
  (key! st 'lf 'suffix "kill-line")
  (check-equal? (text st 'lf) "adef\n")
  (check-equal? (ring st 'lf) "|\n|bc")
  (check-equal? (history st 'lf) 2)
  (def! st 'invalid-mark (session "abc" 0 1 #:mark '(Option Some (Position new 0 3))))
  (key! st 'cleared 'invalid-mark "kill-line")
  (check-equal? (mark-position st 'cleared) "none")
  (def! st 'end (session "ab" 0 2))
  (def! st 'final-empty (session "ab\n" 1 0))
  (def! st 'beyond (session "ab" 0 3 #:mark '(Option Some (Position new 9 9))))
  (def! st 'no-line (session "ab" 9 0))
  (for ([name (in-list '(end final-empty beyond no-line))])
    (key! st (string->symbol (format "~a-noop" name)) name "kill-line")
    (define result (string->symbol (format "~a-noop" name)))
    (same st `(,result editor) `(,name editor))
    (check-equal? (history st result) 0)
    (check-equal? (ring st result) ""))
  (check-equal? (mark-position st 'beyond-noop) "9:9"))

(test-case "yank validates the mark and undo retains the current mark"
  (define st (state))
  (def! st 'base (session "abc" 0 1 #:ring '(List of "Z")
                          #:mark '(Option Some (Position new 0 8))))
  (key! st 'yanked 'base "yank")
  (check-equal? (text st 'yanked) "aZbc")
  (check-equal? (mark-position st 'yanked) "none")
  (check-equal? (history st 'yanked) 1)
  (def! st 'marked '(yanked handle-key "mark"))
  (check-equal? (mark-position st 'marked) "0:2")
  (key! st 'undone 'marked "undo")
  (check-equal? (text st 'undone) "abc")
  (check-equal? (point st 'undone) '(0 1))
  (check-equal? (mark-position st 'undone) "0:2")
  (check-equal? (ring st 'undone) "|Z")
  (check-equal? (history st 'undone) 0))

(test-case "yank validity, echo, search forwarding, quit, and frame bytes"
  (define st (state))
  (def! st 'base (session "ab\ncd" 0 1 #:echo "saved"))
  (key! st 'empty-yank 'base "yank")
  (check-equal? (ev st '(empty-yank echo)) "")
  (same st '(empty-yank editor) '(base editor))
  (key! st 'marked 'base "mark")
  (check-equal? (ev st '(marked echo)) "")
  (check-equal? (ev st '(marked frame 12 3))
                (ev st '(empty-yank frame 12 3)))
  (same st '((marked editor) handle-key "kill") '(marked editor))
  (def! st 'with-ring (session "ab" 0 1 #:ring '(List of "X")
                               #:mark '(Option Some (Position new 0 2))
                               #:echo "failed"))
  (key! st 'yanked 'with-ring "yank")
  (check-equal? (text st 'yanked) "aXb")
  (check-equal? (point st 'yanked) '(0 2))
  (check-equal? (mark-position st 'yanked) "0:2")
  (check-equal? (history st 'yanked) 1)
  (check-equal? (ring st 'yanked) "|X")
  (check-equal? (ev st '(yanked echo)) "")
  (def! st 'invalid (session "ab" 0 9 #:ring '(List of "X")
                             #:mark '(Option Some (Position new 9 9))))
  (key! st 'invalid-yank 'invalid "yank")
  (same st '(invalid-yank editor) '(invalid editor))
  (check-equal? (ring st 'invalid-yank) "|X")
  (check-equal? (mark-position st 'invalid-yank) "9:9")
  (def! st 'searching '(with-ring handle-key "find"))
  (key! st 'search-yank 'searching "yank")
  (check-false (ev st '(search-yank searching)))
  (check-equal? (ev st '(search-yank echo)) "")
  (check-equal? (text st 'search-yank) "aXb")
  (key! st 'quit 'base "escape")
  (key! st 'absorbed 'quit "mark")
  (same st 'absorbed 'quit)
  (check-equal? (ev st '(marked frame 12 1))
                (ev st '((marked editor) frame 12 1)))
  (check-equal? (ev st '(base frame 12 1))
                "\u001b[?25l\u001b[2J\u001b[Hab\u001b[1;2H\u001b[?25h")
  (check-true (regexp-match? #rx"untitled" (ev st '(marked frame 12 3))))
  (def! st 'named (session "ab" 0 1 #:echo "saved"
                           #:path '(Option Some (Path new "/cwd/a.txt"))))
  (key! st 'named-mark 'named "mark")
  (check-true (regexp-match? #rx"/cwd/a.txt" (ev st '(named-mark frame 30 3))))
  (check-false (regexp-match? #rx"saved:" (ev st '(named-mark frame 30 3)))))

(test-case "commands clear echo after search and run with no echo row"
  (define st (state))
  (def! st 'base (session "ab\ncd" 0 1 #:ring '(List of "Z")
                          #:mark '(Option Some (Position new 0 0))
                          #:echo "saved"))
  (for ([key (in-list '("mark" "kill" "kill-line" "yank"))]
        [name (in-list '(mark-search kill-search line-search yank-search))])
    (def! st name `(,(session "ab\ncd" 0 1 #:ring '(List of "Z")
                               #:mark '(Option Some (Position new 0 0))
                               #:echo "saved") handle-key "find"))
    (key! st (string->symbol (format "~a-done" name)) name key)
    (define done (string->symbol (format "~a-done" name)))
    (check-false (ev st `(,done searching)))
    (check-equal? (ev st `(,done echo)) "")
    (check-equal? (ev st `(,done frame 10 1))
                  (ev st `((,done editor) frame 10 1))))
  (check-equal? (mark-position st 'mark-search-done) "0:1")
  (check-equal? (text st 'kill-search-done) "b\ncd")
  (check-equal? (text st 'line-search-done) "a\ncd")
  (check-equal? (text st 'yank-search-done) "aZb\ncd")
  (key! st 'quit 'base "escape")
  (for ([key (in-list '("mark" "kill" "kill-line" "yank"))])
    (same st `(quit handle-key ,key) 'quit)))

(test-case "each idle no-op command clears a prior echo token"
  (define st (state))
  (for ([entry
         (in-list
          (list (list "mark" (session "ab" 0 0 #:echo "saved"))
                (list "kill" (session "ab" 0 0 #:echo "saved"))
                (list "kill-line" (session "ab" 0 2 #:echo "saved"))
                (list "yank" (session "ab" 0 0 #:echo "saved"))))]
        [name (in-list '(mark-noop kill-noop line-noop yank-noop))])
    (def! st name `(,(cadr entry) handle-key ,(car entry)))
    (check-equal? (ev st `(,name echo)) "")
    (check-equal? (history st name) 0)
    (check-equal? (ring st name) "")))
