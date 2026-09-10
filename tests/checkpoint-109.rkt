#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/term.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-point-path "../examples/gel-point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (make-loop-driver #:point? [point? #f])
  (define state (make-driver))
  (define output (open-output-string))
  (check-equal? (driver-load-file! state gel-loop-path output) '())
  (when point?
    (check-equal? (driver-load-file! state gel-point-path output) '()))
  (check-equal? (get-output-string output) "")
  state)

(define (bind-row! state name rows selector arity)
  (driver-eval!
   state
   `(define ,name
      (,rows fold
        (,rows first)
        (fn (found row)
          (if (((row selector) name) = ,selector)
              (if ((row arity) = ,arity) row found)
              found))))))

(define (define-point-pending! state)
  (driver-eval!
   state
   '(define checkpoint-109-point-stack
      ((gel-empty-stack push (Point new 1 2))
       push
       (Point new 10 20))))
  (driver-eval!
   state
   '(define checkpoint-109-point-state
      (GelStep new
        checkpoint-109-point-stack
        #f
        (List empty)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-109-point-rows
      (gel-rows of (checkpoint-109-point-stack tos))))
  (bind-row!
   state
   'checkpoint-109-point-plus-row
   'checkpoint-109-point-rows
   "+"
   1)
  (driver-eval!
   state
   '(define checkpoint-109-point-pending
      (checkpoint-109-point-state handle-key
        ((checkpoint-109-point-plus-row index) text)))))

(define (define-int-pending! state)
  (driver-eval!
   state
   '(define checkpoint-109-int-stack
      ((gel-empty-stack push 2) push 10)))
  (driver-eval!
   state
   '(define checkpoint-109-int-state
      (GelStep new
        checkpoint-109-int-stack
        #f
        (List empty)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-109-int-rows
      (gel-rows of (checkpoint-109-int-stack tos))))
  (bind-row!
   state
   'checkpoint-109-int-plus-row
   'checkpoint-109-int-rows
   "+"
   1)
  (driver-eval!
   state
   '(define checkpoint-109-int-pending
      (checkpoint-109-int-state handle-key
        ((checkpoint-109-int-plus-row index) text))))
  (driver-eval!
   state
   '(define checkpoint-109-int-digits
      (checkpoint-109-int-pending handle-key "2"))))

(test-case "Gel pop and Escape predicates have nominal result types"
  (define state (make-loop-driver))
  (check-equal?
   (driver-type-datum state '((gel-empty-stack push 1) pop))
   'GelStack)
  (check-equal?
   (driver-type-datum state '((GelKey new "escape") escape?))
   'Bool))

(test-case "GelStack.pop removes one exact mirror and preserves its source"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-109-three
      (((gel-empty-stack push 1) push "two") push #t)))
  (define former-second
    (driver-eval!
     state
     '(((checkpoint-109-three items) rest) first)))
  (define former-third
    (driver-eval!
     state
     '((((checkpoint-109-three items) rest) rest) first)))
  (driver-eval!
   state
   '(define checkpoint-109-popped
      (checkpoint-109-three pop)))

  (check-equal?
   (driver-eval! state '((checkpoint-109-popped items) len))
   2)
  (check-eq? (driver-eval! state '(checkpoint-109-popped tos))
             former-second)
  (check-eq?
   (driver-eval!
    state
    '(((checkpoint-109-popped items) rest) first))
   former-third)
  (check-equal?
   (driver-eval! state '((checkpoint-109-popped tos) subject))
   "two")
  (check-equal?
   (driver-eval! state '((checkpoint-109-three items) len))
   3)
  (check-true
   (driver-eval! state '((checkpoint-109-three tos) subject))))

(test-case "GelStack.pop stops by identity at one item and empty"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-109-two
      ((gel-empty-stack push 1) push "two")))
  (driver-eval!
   state
   '(define checkpoint-109-one
      (checkpoint-109-two pop)))
  (driver-eval!
   state
   '(define checkpoint-109-one-again
      (checkpoint-109-one pop)))
  (driver-eval!
   state
   '(define checkpoint-109-empty-again
      (gel-empty-stack pop)))

  (check-equal? (driver-eval! state '((checkpoint-109-one items) len)) 1)
  (check-equal?
   (driver-eval! state '((checkpoint-109-one tos) subject))
   1)
  (check-eq? (driver-eval! state 'checkpoint-109-one-again)
             (driver-eval! state 'checkpoint-109-one))
  (check-eq? (driver-eval! state 'checkpoint-109-empty-again)
             (driver-eval! state 'gel-empty-stack))
  (check-equal?
   (driver-eval! state '((checkpoint-109-empty-again items) len))
   0)
  (check-equal? (driver-eval! state '((checkpoint-109-two items) len)) 2))

(test-case "GelKey recognizes only the exact Escape spelling"
  (define state (make-loop-driver))
  (check-true (driver-eval! state '((GelKey new "escape") escape?)))
  (for ([text (in-list '("" "esc" "Escape" "q" "return" "0" "1" "x"))])
    (check-false
     (driver-eval! state `((GelKey new ,text) escape?))
     text))
  (check-equal?
   (driver-eval! state '((GelKey new "0") digit-value))
   0)
  (check-equal?
   (driver-eval! state '((GelKey new "1") menu-index))
   1)
  (check-true (driver-eval! state '((GelKey new "q") quit?)))
  (check-true (driver-eval! state '((GelKey new "return") return?))))

(test-case "idle Escape pops once and stops at the one-item floor"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-109-idle-stack
      (((gel-empty-stack push 1) push "two") push #t)))
  (driver-eval!
   state
   '(define checkpoint-109-idle
      (GelStep new
        checkpoint-109-idle-stack
        #f
        (List empty)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-109-back-one
      (checkpoint-109-idle handle-key "escape")))
  (driver-eval!
   state
   '(define checkpoint-109-back-two
      (checkpoint-109-back-one handle-key "escape")))
  (driver-eval!
   state
   '(define checkpoint-109-back-three
      (checkpoint-109-back-two handle-key "escape")))

  (check-equal?
   (driver-eval! state '(((checkpoint-109-back-one stack) items) len))
   2)
  (check-equal?
   (driver-eval! state '(((checkpoint-109-back-one stack) tos) subject))
   "two")
  (check-equal?
   (driver-eval! state '(((checkpoint-109-back-two stack) items) len))
   1)
  (check-equal?
   (driver-eval! state '(((checkpoint-109-back-two stack) tos) subject))
   1)
  (check-eq?
   (driver-eval! state '(checkpoint-109-back-three stack))
   (driver-eval! state '(checkpoint-109-back-two stack)))
  (for ([step (in-list '(checkpoint-109-back-one
                         checkpoint-109-back-two
                         checkpoint-109-back-three))])
    (check-false (driver-eval! state `(,step quit)))
    (check-equal? (driver-eval! state `((,step pending) len)) 0)))

(test-case "idle q quits without popping and u remains a no-op"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-109-idle-stack
      ((gel-empty-stack push 1) push "two")))
  (driver-eval!
   state
   '(define checkpoint-109-idle
      (GelStep new
        checkpoint-109-idle-stack
        #f
        (List empty)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-109-idle-quit
      (checkpoint-109-idle handle-key "q")))
  (driver-eval!
   state
   '(define checkpoint-109-idle-u
      (checkpoint-109-idle handle-key "u")))

  (check-true (driver-eval! state '(checkpoint-109-idle-quit quit)))
  (check-eq? (driver-eval! state '(checkpoint-109-idle-quit stack))
             (driver-eval! state 'checkpoint-109-idle-stack))
  (check-false (driver-eval! state '(checkpoint-109-idle-u quit)))
  (check-eq? (driver-eval! state '(checkpoint-109-idle-u stack))
             (driver-eval! state 'checkpoint-109-idle-stack))
  (check-equal?
   (driver-eval! state '((checkpoint-109-idle-u pending) len))
   0))

(test-case "pending Escape cancels while pending q always quits"
  (define point-state (make-loop-driver #:point? #t))
  (define-point-pending! point-state)
  (driver-eval!
   point-state
   '(define checkpoint-109-point-cancelled
      (checkpoint-109-point-pending handle-key "escape")))
  (driver-eval!
   point-state
   '(define checkpoint-109-point-quit
      (checkpoint-109-point-pending handle-key "q")))

  (for ([step (in-list '(checkpoint-109-point-cancelled
                         checkpoint-109-point-quit))])
    (check-eq?
     (driver-eval! point-state `(,step stack))
     (driver-eval! point-state 'checkpoint-109-point-stack))
    (check-equal?
     (driver-eval! point-state `((,step pending) len))
     0)
    (check-equal? (driver-eval! point-state `(,step int-input)) 0)
    (check-false (driver-eval! point-state `(,step has-digits)))
    (check-equal?
     (driver-eval! point-state `(((,step stack) items) len))
     2))
  (check-false
   (driver-eval! point-state '(checkpoint-109-point-cancelled quit)))
  (check-true
   (driver-eval! point-state '(checkpoint-109-point-quit quit)))

  (define int-state (make-loop-driver))
  (define-int-pending! int-state)
  (check-true
   (driver-eval! int-state '(checkpoint-109-int-digits has-digits)))
  (check-equal?
   (driver-eval! int-state '(checkpoint-109-int-digits int-input))
   2)
  (driver-eval!
   int-state
   '(define checkpoint-109-int-cancelled
      (checkpoint-109-int-digits handle-key "escape")))
  (driver-eval!
   int-state
   '(define checkpoint-109-int-quit
      (checkpoint-109-int-digits handle-key "q")))

  (for ([step (in-list '(checkpoint-109-int-cancelled
                         checkpoint-109-int-quit))])
    (check-eq?
     (driver-eval! int-state `(,step stack))
     (driver-eval! int-state 'checkpoint-109-int-stack))
    (check-equal? (driver-eval! int-state `((,step pending) len)) 0)
    (check-equal? (driver-eval! int-state `(,step int-input)) 0)
    (check-false (driver-eval! int-state `(,step has-digits)))
    (check-equal?
     (driver-eval! int-state `(((,step stack) items) len))
     2))
  (check-false
   (driver-eval! int-state '(checkpoint-109-int-cancelled quit)))
  (check-true
   (driver-eval! int-state '(checkpoint-109-int-quit quit))))

(test-case "pending Escape cancels before a second Escape pops"
  (define state (make-loop-driver #:point? #t))
  (define-point-pending! state)
  (driver-eval!
   state
   '(define checkpoint-109-cancel-first
      (checkpoint-109-point-pending handle-key "escape")))
  (driver-eval!
   state
   '(define checkpoint-109-pop-second
      (checkpoint-109-cancel-first handle-key "escape")))

  (check-eq? (driver-eval! state '(checkpoint-109-cancel-first stack))
             (driver-eval! state 'checkpoint-109-point-stack))
  (check-equal?
   (driver-eval! state '(((checkpoint-109-cancel-first stack) items) len))
   2)
  (check-equal?
   (driver-eval! state '(((checkpoint-109-pop-second stack) items) len))
   1)
  (check-equal?
   (driver-eval! state '(((checkpoint-109-pop-second stack) tos) raw))
   "#<Point 1 2>"))

(define point-screen
  (string-append
   "TOS: #<Point 10 20>\r\n"
   "1  x  0\r\n"
   "2  y  0\r\n"
   "3  +  1\r\n"
   "4  -  1\r\n"
   "5  dist2  1\r\n"
   "6  dot  1\r\n"
   "7  *  1\r\n"
   "8  /  1\r\n"
   "\r\n"))

(define (int-screen value)
  (string-append
   "TOS: " (number->string value) "\r\n"
   "1  +  1\r\n"
   "2  -  1\r\n"
   "3  *  1\r\n"
   "4  /  1\r\n"
   "5  <  1\r\n"
   "6  >  1\r\n"
   "7  <=  1\r\n"
   "8  >=  1\r\n"
   "9  =  1\r\n"
   "10  float  0\r\n"
   "11  text  0\r\n"
   "\r\n"))

(define string-screen
  (string-append
   "TOS: \"two\"\r\n"
   "1  =  1\r\n"
   "2  append  1\r\n"
   "\r\n"))

(define point-pending-screen
  (string-append
   "TOS: #<Point 10 20>\r\n"
   "pending +  #<List #<Symbol Point> #<Symbol Int>>\r\n"
   "1  #<Point 10 20>\r\n"
   "\r\n"))

(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (define reader-calls (box 0))
  (define output (open-output-string))
  (values
   (make-term-receiver
    output
    (lambda ()
      (define remaining (unbox remaining-keys))
      (unless (pair? remaining)
        (error 'scripted-term "key script exhausted"))
      (set-box! remaining-keys (cdr remaining))
      (set-box! reader-calls (add1 (unbox reader-calls)))
      (car remaining)))
   output
   reader-calls))

(define (make-main-driver keys)
  (define-values (term terminal-output reader-calls)
    (make-scripted-term keys))
  (define state (make-driver))
  (define load-output (open-output-string))
  (driver-inject-host! state 'term term)
  (check-equal? (driver-load-file! state gel-main-path load-output) '())
  (values state terminal-output load-output reader-calls))

(test-case "GelMain redraws the revealed TOS after idle Escape"
  (define-values (state terminal-output load-output reader-calls)
    (make-main-driver '("escape" "q")))
  (driver-eval!
   state
   '(define checkpoint-109-main-initial
      ((gel-empty-stack push 1) push "two")))
  (driver-eval!
   state
   '(define checkpoint-109-main-final
      (gel-main call checkpoint-109-main-initial)))

  (check-equal?
   (get-output-string terminal-output)
   (string-append
    string-screen
    "key escape\r\n"
    (int-screen 1)
    "key q\r\n"))
  (check-equal?
   (driver-eval! state '((checkpoint-109-main-final items) len))
   1)
  (check-equal?
   (driver-eval! state '((checkpoint-109-main-final tos) subject))
   1)
  (check-equal?
   (driver-eval! state '((checkpoint-109-main-initial items) len))
   2)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 2))

(test-case "GelMain.start preserves Point back navigation"
  (define-values (state terminal-output load-output reader-calls)
    (make-main-driver '("1" "escape" "q")))
  (check-equal? (driver-load-file! state gel-point-path load-output) '())
  (define start-value (driver-eval! state 'gel-start-value))
  (driver-eval!
   state
   '(define checkpoint-109-point-final
      (gel-main start gel-start-value)))

  (check-equal?
   (get-output-string terminal-output)
   (string-append
    point-screen
    "key 1\r\n"
    (int-screen 10)
    "key escape\r\n"
    point-screen
    "key q\r\n"))
  (check-equal?
   (driver-eval! state '((checkpoint-109-point-final items) len))
   1)
  (check-eq?
   (driver-eval! state '((checkpoint-109-point-final tos) subject))
   start-value)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 3))

(test-case "GelMain pending Escape cancels without invoking or popping"
  (define-values (state terminal-output load-output reader-calls)
    (make-main-driver '("3" "escape" "q")))
  (check-equal? (driver-load-file! state gel-point-path load-output) '())
  (define start-value (driver-eval! state 'gel-start-value))
  (driver-eval!
   state
   '(define checkpoint-109-pending-final
      (gel-main start gel-start-value)))

  (check-equal?
   (get-output-string terminal-output)
   (string-append
    point-screen
    "key 3\r\n"
    point-pending-screen
    "key escape\r\n"
    point-screen
    "key q\r\n"))
  (check-equal?
   (driver-eval! state '((checkpoint-109-pending-final items) len))
   1)
  (check-eq?
   (driver-eval! state '((checkpoint-109-pending-final tos) subject))
   start-value)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 3))

(test-case "runner and default capability boundaries remain unchanged"
  (define runner-source (file->string gel-run-path))
  (check-regexp-match
   #rx"driver-inject-host! state 'term term"
   runner-source)
  (check-regexp-match
   #rx"gel-main start gel-start-value"
   runner-source)
  (check-false
   (regexp-match? #rx"Point|point-path|fs-host|GelStep|GelKey|escape|pop"
                  runner-source))
  (define main-source (file->string gel-main-path))
  (check-false (regexp-match? #rx"escape|pop" main-source))

  (define state (make-driver))
  (for ([name (in-list '(term fs-host gel-start-value GelMain GelStack GelKey))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))
