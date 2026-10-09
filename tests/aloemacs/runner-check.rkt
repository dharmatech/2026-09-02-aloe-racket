#lang racket/base

(require racket/string racket/list
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/host.rkt"
         (only-in "../../aloe/type.rkt" type-environment-bound?)
         "../../host/racket/aloemacs-run.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define (typecheck-failure? exception)
  (and (exn:fail? exception)
       (regexp-match? #rx"^typecheck:" (exn-message exception))))

(test-case "prepare checks a definition now and evaluates it on every run"
  (define state (make-driver))
  (define initialize (driver-prepare! state '(define n 1)))
  (check-true (procedure? initialize))
  (check-equal? (procedure-arity initialize) 0)
  (check-true (type-environment-bound? (driver-type-environment state) 'n))
  (check-false (env-bound? (driver-runtime-environment state) 'n))
  (check-true (void? (initialize)))
  (check-equal? (driver-eval! state 'n) 1)
  (define increment (driver-prepare! state '(define n (n + 1))))
  (check-true (void? (increment)))
  (check-true (void? (increment)))
  (check-equal? (driver-eval! state 'n) 3))

(test-case "a rejected prepare raises without returning a procedure"
  (define state (make-driver))
  (check-exn typecheck-failure?
             (lambda () (driver-prepare! state '(1 + "a"))))
  (check-true (void? (driver-eval! state '(define ok 1))))
  (check-equal? (driver-eval! state 'ok) 1))

(test-case "driver-eval! checks the same datum again after a type rebind"
  (define state (make-driver))
  (driver-eval! state '(define n 1))
  (check-equal? (driver-eval! state '(n + 1)) 2)
  (driver-eval! state '(define n "a"))
  (check-exn typecheck-failure?
             (lambda () (driver-eval! state '(n + 1)))))

(test-case "a prepared expression sees a later value of the same type"
  (define state (make-driver))
  (driver-eval! state '(define n 1))
  (define incremented (driver-prepare! state '(n + 1)))
  (check-equal? (incremented) 2)
  (driver-eval! state '(define n 10))
  (check-equal? (incremented) 11))

(test-case "preparation has no host effect and each run sends again"
  (define state (make-driver))
  (define counter (box 0))
  (define interface
    (make-host-interface
     'Probe
     (list
      (make-host-method
       'tick '() 'Int
       (lambda (host-state)
         (set-box! host-state (add1 (unbox host-state)))
         (unbox host-state))))))
  (driver-inject-host! state 'probe (make-host-receiver interface counter))
  (define tick (driver-prepare! state '(probe tick)))
  (check-equal? (unbox counter) 0)
  (check-equal? (tick) 1)
  (check-equal? (tick) 2)
  (check-equal? (unbox counter) 2))

(test-case "rejected construction preserves the checker's partial type bindings"
  (define state (make-driver))
  (driver-eval!
   state
   '(define-class (Option T)
      (constructors
        (None (fields))
        (Some (fields (value T))))
      (methods)))
  (define (uninferred-option? exception)
    (and (exn:fail? exception)
         (regexp-match?
          #rx"^typecheck: cannot infer type parameter T for Option"
          (exn-message exception))))
  (check-exn uninferred-option?
             (lambda () (driver-prepare! state '(define n (Option None)))))
  (check-false (type-environment-bound? (driver-type-environment state) 'n))
  (check-false (env-bound? (driver-runtime-environment state) 'n))
  (check-exn
   uninferred-option?
   (lambda ()
     (driver-prepare! state '(define n (if #t (Option None) (Option None))))))
  (check-true (type-environment-bound? (driver-type-environment state) 'n))
  (check-false (env-bound? (driver-runtime-environment state) 'n)))

(test-case "prepare counting includes attempts before parse or type failures"
  (check-false (current-driver-prepare-counter))
  (define state (make-driver))
  (define count (box 0))
  (parameterize ([current-driver-prepare-counter count])
    (define run (driver-prepare! state '(1 + 2)))
    (check-equal? (unbox count) 1)
    (check-equal? (run) 3)
    (check-equal? (run) 3)
    (check-equal? (unbox count) 1)
    (check-exn exn:fail? (lambda () (driver-prepare! state '())))
    (check-equal? (unbox count) 2)
    (check-exn typecheck-failure?
               (lambda () (driver-prepare! state '(1 + "a"))))
    (check-equal? (unbox count) 3)
    (check-equal? (driver-eval! state '(1 + 2)) 3)
    (check-equal? (unbox count) 3)))

;; Expected bytes are built independently of the Aloe frame implementation.
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
(define (frame body row column rows label #:name [name "untitled"] #:width [width 0])
  (string-append "\e[?25l\e[2J\e[H"
    (if rows (text-body body rows) body)
    (format "\e[~a;~aH\e[?25h" row column)
    (if (and rows (>= rows 2))
        (string-append "\e[?25l"
          (if (>= rows 3) (format "\e[~a;1H~a" (sub1 rows) (light (mode-row name width))) "")
          (format "\e[~a;1H~a\e[~a;~aH\e[?25h" rows label row column)) "")))

(struct scripted-term (receiver remaining size-calls events gaps) #:transparent)

(define spare-keys '("x" "save"))

(define (make-scripted-term sizes keys)
  (define remaining (box (append keys spare-keys)))
  (define size-calls (box 0))
  (define recorded '())
  (define gaps '())
  (define last-key-return #f)
  (define (record! event) (set! recorded (cons event recorded)))
  (define output
    (make-output-port
     'runner-check always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (record!
        (if (= start end)
            'flush
            (list 'write (bytes->string/utf-8 (subbytes bytes start end)))))
       (- end start))
     void))
  (define receiver
    (make-term-receiver
     output
     (lambda ()
       (define key-call (current-inexact-monotonic-milliseconds))
       (when last-key-return
         (set! gaps (cons (- key-call last-key-return) gaps)))
       (define keys-left (unbox remaining))
       (unless (pair? keys-left)
         (error 'scripted-term "key script exhausted"))
       (define key (car keys-left))
       (set-box! remaining (cdr keys-left))
       (record! (list 'key key))
       (set! last-key-return (current-inexact-monotonic-milliseconds))
       key)
     (lambda ()
       (define call (unbox size-calls))
       (define size (list-ref sizes (quotient call 2)))
       (record! (list (if (even? call) 'columns 'rows)
                      (if (even? call) (car size) (cadr size))))
       (set-box! size-calls (add1 call))
       (values (car size) (cadr size)))))
  (scripted-term receiver remaining size-calls
                 (lambda () (reverse recorded))
                 (lambda () (reverse gaps))))

(test-case "five Down cycles preserve frame order and stay under 20 ms"
  (define keys '("down" "down" "down" "down" "down" "escape"))
  (define fixture (make-scripted-term (make-list 6 '(20 8)) keys))
  (define fs
    (make-fs-double
     "/cwd"
     (hash "/cwd" 'directory "/cwd/a.txt" 'file)
     (hash "/cwd/a.txt" "a\nb\nc\nd\ne\nf\ng\nh")))
  (define count (box 0))
  (parameterize ([current-driver-prepare-counter count])
    (run-aloemacs-with-hosts (scripted-term-receiver fixture) fs "a.txt"))
  (check-equal? (unbox (scripted-term-remaining fixture)) spare-keys)
  (check-equal? (unbox (scripted-term-size-calls fixture)) 12)
  (check-equal?
   ((scripted-term-events fixture))
   (append-map
    (lambda (row key)
      (list '(columns 20) '(rows 8)
            (list 'write (frame "a\r\nb\r\nc\r\nd\r\ne\r\nf\r\ng"
                                row 1 8 "" #:name "/cwd/a.txt" #:width 20))
            'flush (list 'key key)))
    '(1 2 3 4 5 6) keys))
  (define gaps ((scripted-term-gaps fixture)))
  (check-equal? (length gaps) 5)
  (define median (list-ref (sort gaps <) 2))
  (check-true (< median 20)
              (format "Down-cycle median: ~a ms (must be under 20 ms)" median))
  (printf "Down-cycle median: ~a ms\n" median)
  (check-equal? (unbox count) 6))

(test-case "resize A to B to A prepares fit and frame for each current pair"
  (define fixture
    (make-scripted-term '((20 8) (21 8) (20 8)) '("down" "down" "escape")))
  (define count (box 0))
  (parameterize ([current-driver-prepare-counter count])
    (run-aloemacs-with-hosts
     (scripted-term-receiver fixture)
     (make-fs-double "/cwd" (hash "/cwd" 'directory))))
  (check-equal? (unbox count) 10)
  (check-equal? (unbox (scripted-term-remaining fixture)) spare-keys)
  (check-equal? (unbox (scripted-term-size-calls fixture)) 6))
