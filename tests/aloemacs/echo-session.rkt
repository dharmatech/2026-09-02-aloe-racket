#lang racket/base

(require racket/list
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type? type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

(define no-path
  '(if #t (Option None) (Option Some (Path new "/unused"))))

(define (make-state [main? #f])
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file
          "/cwd/dir" 'directory)
    (hash "/cwd/a.txt" "zero\none\ntwo\nthree")))
  (driver-eval! state `(load ,(path->string (if main? main-path file-path))))
  state)

(define (session source path echo)
  `(AloemacsSession new
     (AloemacsEditor new
       (Text from-string ,source)
       (Position new 0 0)
       #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))))
     (Fs new fs-host)
     ,(if path `(Option Some (Path new ,path)) no-path)
     ,echo #f "" (Position new 0 0) #f #f (List empty)))

(define (define! state name expression)
  (driver-eval! state `(define ,name ,expression)))

(define (value state expression)
  (driver-eval! state expression))

(define (type state expression)
  (type->datum
   (type-of (parse-datum expression) (driver-type-environment state))))

(define (same state left right)
  (check-not-exn
   (lambda () (value state `(check ,left ,right)))))

(define (same-payload state actual expected)
  (for ([field (in-list '(editor fs path))])
    (same state `(,actual ,field) `(,expected ,field)))
  (check-equal? (value state `((,actual editor) scroll-row))
                (value state `((,expected editor) scroll-row)))
  (check-equal? (value state `((,actual editor) scroll-col))
                (value state `((,expected editor) scroll-col)))
  (check-equal? (value state `(((,actual editor) history) len))
                (value state `(((,expected editor) history) len))))

(define (editor-frame body row column)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H" body
   (format "\u001b[~a;~aH\u001b[?25h" row column)))

(define (session-frame body row column terminal-row label)
  (string-append
   (editor-frame body row column)
   (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;~aH\u001b[?25h"
           terminal-row label row column)))

(test-case "fourth field is checked and main starts idle"
  (define state (make-state #t))
  (define untitled (session "" #f ""))
  (define bound (session "" "/cwd/a.txt" ""))
  (check-equal? (type state untitled) '(AloemacsSession FsHost))
  (check-equal? (type state bound) '(AloemacsSession FsHost))
  (check-equal? (type state '(aloemacs-editor echo)) 'String)
  (check-equal? (value state '(aloemacs-editor echo)) "")
  (check-equal? (value state '(aloemacs-editor frame 8 4))
                (session-frame "\r\n\r\n" 1 1 4 "untitled"))
  (check-exn exn:fail:aloe-type?
             (lambda () (value state (drop-right untitled 1))))
  (check-exn exn:fail:aloe-type?
             (lambda ()
               (value state (append (drop-right untitled 1) '(7))))))

(test-case "rebuilds preserve echo and visit resets it"
  (define state (make-state))
  (define! state 'base (session "draft" #f "prior"))
  (define! state 'replaced '(base with-editor (base editor)))
  (define! state 'edited '(base insert "!"))
  (define! state 'fitted '(edited ensure-visible 8 4))
  (for ([name (in-list '(replaced edited fitted))])
    (check-equal? (value state `(,name echo)) "prior")
    (same state `(,name fs) '(base fs))
    (same state `(,name path) '(base path)))
  (check-equal? (value state '((edited text) to-string)) "!draft")
  (same state '((fitted editor) text) '((edited editor) text))
  (define! state 'existing
    '((base visit (Path new "a.txt")) case
       (None () base) (Some (s) s)))
  (define! state 'missing
    '((base visit (Path new "new.txt")) case
       (None () base) (Some (s) s)))
  (for ([name (in-list '(existing missing))])
    (check-equal? (value state `(,name echo)) ""))
  (check-equal? (value state '((existing path) case
                               (None () "none")
                               (Some (p) (p text))))
                "/cwd/a.txt")
  (check-equal? (value state '((missing path) case
                               (None () "none")
                               (Some (p) (p text))))
                "/cwd/new.txt")
  (check-false (value state '((base visit (Path new "dir")) present?)))
  (same state 'base (session "draft" #f "prior"))
  (define! state 'bound (session "changed" "/cwd/a.txt" "prior"))
  (define! state 'saved
    '((bound save) case (None () bound) (Some (s) s)))
  (same state 'saved 'bound)
  (check-equal? (value state '(saved echo)) "prior")
  (check-equal? (value state '(fs-host read "/cwd/a.txt")) "changed"))

(test-case "idle frames clip labels, pad text, and restore the text cursor"
  (define state (make-state))
  (define! state 'untitled (session "" #f ""))
  (define! state 'bound (session "zero\none\ntwo\nthree" "/cwd/a.txt" ""))
  (check-equal? (value state '(untitled frame 8 4))
                (session-frame "\r\n\r\n" 1 1 4 "untitled"))
  (check-equal? (value state '(bound frame 8 4))
                (session-frame "zero\r\none\r\ntwo" 1 1 4 "/cwd/a.t"))
  (check-equal? (value state '(bound frame 20 4))
                (session-frame "zero\r\none\r\ntwo" 1 1 4 "/cwd/a.txt"))
  (check-equal? (value state '(untitled frame 4 2))
                (session-frame "" 1 1 2 "unti"))
  (define! state 'prior (session "one\ntwo" #f "prior"))
  (define! state 'single '(prior ensure-visible 8 1))
  (check-equal? (value state '(single frame 8 1))
                (value state '((single editor) frame 8 1)))
  (check-equal? (value state '(single echo)) "prior")
  (define! state 'grown '(single ensure-visible 8 4))
  (check-equal? (value state '(grown echo)) "prior"))

(test-case "three text rows scroll at source line three and hold on Up"
  (define state (make-state))
  (define! state 'start
    (session "zero\none\ntwo\nthree\nfour" "/cwd/a.txt" ""))
  (define! state 'one '((start handle-key "down") ensure-visible 8 4))
  (define! state 'two '((one handle-key "down") ensure-visible 8 4))
  (define! state 'three '((two handle-key "down") ensure-visible 8 4))
  (check-equal? (value state '((three editor) scroll-row)) 1)
  (check-equal? (value state '(three frame 8 4))
                (session-frame "one\r\ntwo\r\nthree" 3 1 4 "/cwd/a.t"))
  (define! state 'up '((three handle-key "up") ensure-visible 8 4))
  (check-equal? (value state '((up editor) scroll-row)) 1)
  (check-equal? (value state '(up frame 8 4))
                (session-frame "one\r\ntwo\r\nthree" 2 1 4 "/cwd/a.t")))

(test-case "key saves report success or failure without changing session payload"
  (define state (make-state))
  (define! state 'bound
    `((,(session "changed" "/cwd/a.txt" "") handle-key "right")
      ensure-visible 8 4))
  (define! state 'success '(bound handle-key "save"))
  (same-payload state 'success 'bound)
  (check-equal? (value state '(success echo)) "saved")
  (check-equal? (value state '(((success editor) history) len)) 0)
  (check-equal? (value state '(fs-host read "/cwd/a.txt")) "changed")
  (check-equal? (value state '(success frame 20 4))
                (session-frame "changed\r\n\r\n" 1 2 4
                               "saved: /cwd/a.txt"))
  (define! state 'untitled (session "draft" #f ""))
  (define! state 'untitled-failed '(untitled handle-key "save"))
  (same-payload state 'untitled-failed 'untitled)
  (check-equal? (value state '(untitled-failed echo)) "failed")
  (check-equal? (value state '(untitled-failed frame 20 4))
                (session-frame "draft\r\n\r\n" 1 1 4
                               "failed: untitled"))
  (define! state 'ineligible (session "draft" "/cwd/dir" ""))
  (define! state 'ineligible-failed '(ineligible handle-key "save"))
  (same-payload state 'ineligible-failed 'ineligible)
  (check-equal? (value state '(ineligible-failed echo)) "failed")
  (check-equal? (value state '(ineligible-failed frame 20 4))
                (session-frame "draft\r\n\r\n" 1 1 4
                               "failed: /cwd/dir"))
  (check-equal? (value state '(fs-host kind "/cwd/dir")) "directory"))

(test-case "later saves replace outcomes and frames preserve them"
  (define state (make-state))
  (define! state 'was-failed (session "changed" "/cwd/a.txt" "failed"))
  (define! state 'now-saved '(was-failed handle-key "save"))
  (same-payload state 'now-saved 'was-failed)
  (check-equal? (value state '(now-saved echo)) "saved")
  (define expected
    (session-frame "changed\r\n\r\n" 1 1 4 "saved: /cwd/a.txt"))
  (check-equal? (value state '(now-saved frame 20 4)) expected)
  (check-equal? (value state '(now-saved frame 20 4)) expected)
  (define! state 'was-saved (session "draft" "/cwd/dir" "saved"))
  (define! state 'now-failed '(was-saved handle-key "save"))
  (same-payload state 'now-failed 'was-saved)
  (check-equal? (value state '(now-failed echo)) "failed")
  (check-equal? (value state '(now-failed frame 8 4))
                (session-frame "draft\r\n\r\n" 1 1 4 "failed: "))
  (check-equal? (value state '(now-failed frame 20 4))
                (session-frame "draft\r\n\r\n" 1 1 4
                               "failed: /cwd/dir")))

(test-case "non-save active keys clear outcomes after editor handling"
  (define state (make-state))
  (define! state 'base (session "ab" #f "saved"))
  (for ([entry (in-list '(("right" moved) ("x" inserted)
                          ("undo" undone) ("unknown" unknown)
                          ("escape" escaped)))])
    (define key (car entry))
    (define name (cadr entry))
    (define! state name `(base handle-key ,key))
    (same state `(,name editor) `((base editor) handle-key ,key))
    (same state `(,name fs) '(base fs))
    (same state `(,name path) '(base path))
    (check-equal? (value state `(,name echo)) ""))
  (check-equal? (value state '((moved point) column)) 1)
  (check-equal? (value state '((inserted text) to-string)) "xab")
  (check-equal? (value state '((undone text) to-string)) "ab")
  (check-true (value state '(escaped quit)))
  (define! state 'quit-with-status '(base request-quit))
  (for ([key (in-list '("save" "left"))])
    (same state `(quit-with-status handle-key ,key) 'quit-with-status))
  (check-equal? (value state '(quit-with-status echo)) "saved"))

(test-case "direct sends, resize, and one-row frame retain outcome"
  (define state (make-state))
  (define! state 'base (session "one\ntwo" #f "saved"))
  (for ([expression (in-list '((base insert "x") (base newline)
                              (base request-quit)
                              (base ensure-visible 8 1)
                              (base ensure-visible 8 4)))])
    (check-equal? (value state `(,expression echo)) "saved"))
  (define! state 'small '(base ensure-visible 8 1))
  (check-equal? (value state '(small frame 8 1))
                (value state '((small editor) frame 8 1)))
  (define! state 'grown '(small ensure-visible 8 4))
  (check-equal? (value state '(grown frame 8 4))
                (session-frame "one\r\ntwo\r\n" 1 1 4 "saved: u"))
  (check-equal? (value state '(grown frame 8 4))
                (session-frame "one\r\ntwo\r\n" 1 1 4 "saved: u"))
  (define! state 'failed (session "" #f "failed"))
  (check-equal? (value state '(failed frame 8 4))
                (session-frame "\r\n\r\n" 1 1 4 "failed: ")))

(test-case "direct save keeps Option and any existing echo"
  (define state (make-state))
  (define! state 'bound (session "direct" "/cwd/a.txt" "failed"))
  (check-equal? (value state '((bound save) present?)) #t)
  (define! state 'saved
    '((bound save) case (None () bound) (Some (s) s)))
  (same state 'saved 'bound)
  (check-equal? (value state '(saved echo)) "failed")
  (check-equal? (value state '(fs-host read "/cwd/a.txt")) "direct")
  (define! state 'untitled (session "draft" #f "saved"))
  (define! state 'ineligible (session "draft" "/cwd/dir" "saved"))
  (for ([name (in-list '(untitled ineligible))])
    (check-false (value state `((,name save) present?)))
    (check-equal? (value state `(,name echo)) "saved")))
