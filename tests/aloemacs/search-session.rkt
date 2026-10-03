#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

(define no-path '(if #t (Option None) (Option Some (Path new "/unused"))))

(define (make-state [main? #f])
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double "/cwd"
                   (hash "/cwd" 'directory "/cwd/a.txt" 'file)
                   (hash "/cwd/a.txt" "ababa\nsecond\nababa")))
  (driver-eval! state `(load ,(path->string (if main? main-path file-path))))
  state)

(define (session source line column [echo ""] [path #f])
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new
            (Text from-string ,source) (Position new ,line ,column)
            #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)
         ,(if path `(Option Some (Path new ,path)) no-path))
       (List empty))
     (Fs new fs-host)
     ,echo
     #f
     ""
     (Position new 0 0)
     #f
     #f
     (List empty)
     (if #t (Option None) (Option Some aloemacs-global-keymap))
     (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
     (if #t (Option None) (Option Some ""))))

(define (define! state name expression)
  (driver-eval! state `(define ,name ,expression)))

(define (value state expression)
  (driver-eval! state expression))

(define (step! state name prior key)
  (define! state name `(,prior handle-key ,key)))

(define (point state name)
  (list (value state `((,name point) line))
        (value state `((,name point) column))))

(define (position state expression)
  (list (value state `(,expression line))
        (value state `(,expression column))))

(define (search-state state name)
  (list (value state `(,name searching))
        (value state `(,name query))
        (position state `(,name origin))
        (value state `(,name wrapped))
        (value state `(,name failing))))

(define (history state name)
  (value state `((,name editor) history)))

(define (same state left right)
  (check-not-exn (lambda () (value state `(check ,left ,right)))))

(define (frame body row column rows label)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H" body
   (format "\u001b[~a;~aH\u001b[?25h" row column)
   (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;~aH\u001b[?25h"
           rows label row column)))

(test-case "ordered fields, entry, ordinary rebuilds, exit, and visit reset"
  (define state (make-state #t))
  (define fields '((searching Bool) (query String) (origin Position)
                 (wrapped Bool) (failing Bool)))
  (for ([entry (in-list fields)])
    (check-equal?
     (type->datum
      (type-of (parse-datum `(aloemacs-editor ,(car entry)))
               (driver-type-environment state)))
     (cadr entry)))
  (check-equal? (search-state state 'aloemacs-editor)
                '(#f "" (0 0) #f #f))
  (check-exn exn:fail:aloe-type?
             (lambda ()
               (value state
                      '(AloemacsSession new
                         (aloemacs-editor editor) (aloemacs-editor fs)
                         (aloemacs-editor path) "" #f ""
                         (Position new 0 0) #f (List empty)))))
  (define! state 'base (session "abc\ndef" 1 1 "saved"))
  (step! state 'active 'base "find")
  (check-equal? (search-state state 'active)
                '(#t "" (1 1) #f #f))
  (check-equal? (point state 'active) '(1 1))
  (check-equal? (value state '(active echo)) "saved")
  (define! state 'rebuilt '(active with-editor (active editor)))
  (define! state 'fitted '(rebuilt ensure-visible 8 3))
  (for ([name (in-list '(rebuilt fitted))])
    (check-equal? (search-state state name) '(#t "" (1 1) #f #f)))
  (step! state 'accepted 'fitted "escape")
  (check-equal? (search-state state 'accepted)
                '(#f "" (0 0) #f #f))
  (check-equal? (point state 'accepted) '(1 1))
  (check-equal? (value state '(accepted echo)) "saved")
  (define! state 'visited
    '((active visit (Path new "a.txt")) case
       (None () active) (Some (session) session)))
  (check-equal? (search-state state 'visited)
                '(#f "" (0 0) #f #f)))

(test-case "query edits, overlaps, ordered wrap, and post-wrap failure"
  (define state (make-state))
  (define! state 'base (session "ababa\naba\nababa" 0 0))
  (step! state 'entry 'base "find")
  (step! state 'a 'entry "a")
  (step! state 'ab 'a "b")
  (step! state 'aba 'ab "a")
  (check-equal? (point state 'aba) '(0 0))
  (step! state 'overlap 'aba "find")
  (check-equal? (point state 'overlap) '(0 2))
  (step! state 'later 'overlap "find")
  (check-equal? (point state 'later) '(1 0))
  (step! state 'last 'later "find")
  (check-equal? (point state 'last) '(2 0))
  (step! state 'last-overlap 'last "find")
  (check-equal? (point state 'last-overlap) '(2 2))
  (step! state 'wrapped 'last-overlap "find")
  (check-equal? (point state 'wrapped) '(0 0))
  (check-equal? (search-state state 'wrapped)
                '(#t "aba" (0 0) #t #f))
  (step! state 'failed 'wrapped "find")
  (check-equal? (point state 'failed) '(0 0))
  (check-equal? (search-state state 'failed)
                '(#t "aba" (0 0) #t #t))
  (step! state 'recover 'failed "backspace")
  (check-equal? (search-state state 'recover)
                '(#t "ab" (0 0) #f #f))
  (check-equal? (point state 'recover) '(0 0))
  (same state '((recover text) to-string) '((base text) to-string))
  (same state '((recover editor) history) '((base editor) history)))

(test-case "start-line prefix extension, miss recovery, space, and empty query"
  (define state (make-state))
  (define! state 'base (session "abcde\nxxxxx" 0 3))
  (step! state 'entry 'base "find")
  (step! state 'a 'entry "a")
  (step! state 'ab 'a "b")
  (step! state 'abc 'ab "c")
  (step! state 'abcd 'abc "d")
  (check-equal? (point state 'abcd) '(0 0))
  (check-true (value state '(abcd wrapped)))
  (step! state 'miss 'abcd "z")
  (check-equal? (point state 'miss) '(0 3))
  (check-equal? (search-state state 'miss)
                '(#t "abcdz" (0 3) #f #t))
  (step! state 'recover 'miss "backspace")
  (check-equal? (point state 'recover) '(0 0))
  (check-true (value state '(recover wrapped)))
  (step! state 'space 'recover " ")
  (check-equal? (value state '(space query)) "abcd ")
  (check-true (value state '(space failing)))
  (define! state 'one '(space handle-key "backspace"))
  (define! state 'two '(one handle-key "backspace"))
  (define! state 'three '(two handle-key "backspace"))
  (define! state 'four '(three handle-key "backspace"))
  (define! state 'empty '(four handle-key "backspace"))
  (check-equal? (point state 'empty) '(0 3))
  (check-equal? (search-state state 'empty)
                '(#t "" (0 3) #f #f))
  (step! state 'empty-again 'empty "backspace")
  (step! state 'empty-find 'empty-again "find")
  (check-equal? (point state 'empty-find) '(0 3))
  (check-equal? (search-state state 'empty-find)
                '(#t "" (0 3) #f #f)))

(test-case "acceptance, forwarding, save, undo, and quit"
  (define state (make-state))
  (define! state 'base (session "ababa" 0 0 "" "/cwd/a.txt"))
  (step! state 'inserted 'base "x")
  (step! state 'saved 'inserted "save")
  (check-equal? (value state '(saved echo)) "saved")
  (step! state 'entry 'saved "find")
  (step! state 'hit 'entry "a")
  (step! state 'return 'hit "return")
  (check-equal? (value state '(return echo)) "saved")
  (check-false (value state '(return quit)))
  (check-equal? (point state 'return) '(0 1))
  (same state '((return text) to-string) '((saved text) to-string))
  (same state '((return editor) history) '((saved editor) history))
  (step! state 'search-again 'return "find")
  (step! state 'arrow 'search-again "right")
  (check-false (value state '(arrow searching)))
  (check-equal? (point state 'arrow) '(0 2))
  (check-equal? (value state '(arrow echo)) "")
  (step! state 'search-save 'arrow "find")
  (step! state 'forward-save 'search-save "save")
  (check-equal? (value state '(forward-save echo)) "saved")
  (check-false (value state '(forward-save searching)))
  (step! state 'search-undo 'forward-save "find")
  (step! state 'forward-undo 'search-undo "undo")
  (check-equal? (value state '((forward-undo text) to-string)) "ababa")
  (check-equal? (value state '(((forward-undo editor) history) len)) 0)
  (step! state 'search-escape 'forward-undo "find")
  (step! state 'accepted 'search-escape "escape")
  (check-false (value state '(accepted quit)))
  (step! state 'quit 'accepted "escape")
  (check-true (value state '(quit quit)))
  (step! state 'absorbed 'quit "find")
  (same state 'absorbed 'quit))

(test-case "search rows clip, sanitize, restore text cursor, and vanish at one row"
  (define state (make-state))
  (define! state 'base (session "ababa\naba" 0 0 "saved"))
  (step! state 'active 'base "find")
  (check-equal? (value state '(active frame 8 3))
                (frame "ababa\r\naba" 1 1 3 "search: "))
  (step! state 'a 'active "a")
  (step! state 'b 'a "b")
  (step! state 'c 'b "a")
  (step! state 'next 'c "find")
  (step! state 'later 'next "find")
  (step! state 'wrapped 'later "find")
  (check-equal? (value state '(wrapped frame 12 3))
                (frame "ababa\r\naba" 1 1 3 "wrapped: aba"))
  (step! state 'failed 'wrapped "find")
  (check-equal? (value state '(failed frame 10 3))
                (frame "ababa\r\naba" 1 1 3 "failing: a"))
  (check-equal? (value state '(failed frame 8 1))
                (value state '((failed editor) frame 8 1)))
  (define! state 'sanitized
    '(AloemacsSession new
       (AloemacsBuffers new
         (List empty)
         (AloemacsBuffer new
           (base editor)
           (base path))
         (List empty))
       (base fs)
       "saved"
       #t
       "a\u001b"
       (Position new 0 0)
       #f
       #f
       (List empty)
       (if #t (Option None) (Option Some aloemacs-global-keymap))
       (base prompt)
       (base last-submission)))
  (check-equal? (value state '(sanitized frame 12 3))
                (frame "ababa\r\naba" 1 1 3 "search: a "))
  (step! state 'exit 'failed "return")
  (check-equal? (value state '(exit frame 20 3))
                (frame "ababa\r\naba" 1 1 3 "saved: untitled")))
