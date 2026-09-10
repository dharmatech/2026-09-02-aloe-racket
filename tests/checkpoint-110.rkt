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

(define-runtime-path aloe-directory "../aloe")
(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-menu-path "../gel/menu.aloe")
(define-runtime-path gel-list-path "../examples/gel-list.aloe")
(define-runtime-path gel-point-path "../examples/gel-point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")
(define-runtime-path host-directory "../host")
(define-runtime-path list-library-path "../lib/list.aloe")

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

(define (define-value-rows! state name menu-name)
  (driver-eval!
   state
   `(define ,name
      (,menu-name case
        (Messages (rows)
          (GelValueRows new (List empty)))
        (Values (rows) rows)))))

(define (list-item-datum list-name index)
  (define receiver
    (for/fold ([receiver list-name])
              ([_ (in-range index)])
      (list receiver 'rest)))
  (list receiver 'first))

(define point-menu
  (string-append
   "1  x  0\r\n"
   "2  y  0\r\n"
   "3  +  1\r\n"
   "4  -  1\r\n"
   "5  dist2  1\r\n"
   "6  dot  1\r\n"
   "7  *  1\r\n"
   "8  /  1\r\n"))

(define int-menu
  (string-append
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
   "11  text  0\r\n"))

(define (int-screen value)
  (string-append
   "TOS: " (number->string value) "\r\n"
   int-menu
   "\r\n"))

(define string-list-menu
  (string-append
   "a  \"alpha\"\r\n"
   "b  \"beta\"\r\n"
   "c  \"gamma\"\r\n"))

(define value-item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "n" "o" "p" "r" "s" "t" "v" "w" "x" "y" "z"))

(test-case "Gel value-menu names and types appear only after Gel loads"
  (define fresh (make-driver))
  (for ([name (in-list '(GelMirrors
                         gel-mirrors
                         GelListValues
                         GelValueRow
                         GelValueRows
                         GelMenu
                         GelMenus
                         gel-menus))])
    (check-false (env-bound? (driver-runtime-environment fresh) name))
    (check-false
     (type-environment-bound? (driver-type-environment fresh) name)))

  (define state (make-loop-driver))
  (for ([datum+type
         (in-list
          '(((gel-mirrors of 10) Mirror)
            ((gel-mirrors of (Mirror of 10)) Mirror)
            (((List of 10 20) gel-values) GelListValues)
            ((GelValueRow new 1 (Mirror of 10) "10") GelValueRow)
            ((GelValueRows new
               (List of (GelValueRow new 1 (Mirror of 10) "10")))
             GelValueRows)
            ((GelMenu Messages (gel-rows of 10)) GelMenu)
            ((GelMenu Values
               (GelValueRows new
                 (List of (GelValueRow new 1 (Mirror of 10) "10"))))
             GelMenu)
            ((gel-menus of (Mirror of (List of 10 20))) GelMenu)))])
    (check-equal?
     (driver-type-datum state (car datum+type))
     (cadr datum+type))))

(test-case "List values become ordered one-based mirror rows"
  (define state (make-loop-driver))
  (driver-eval! state '(define checkpoint-110-values (List of 10 20 30)))
  (driver-eval!
   state
   '(define checkpoint-110-carrier
      (checkpoint-110-values gel-values)))
  (driver-eval!
   state
   '(define checkpoint-110-rows
      (gel-menus value-rows checkpoint-110-carrier)))

  (check-equal? (driver-eval! state '(checkpoint-110-rows len)) 3)
  (check-equal?
   (driver-type-datum state '(checkpoint-110-carrier items))
   '(List Mirror))
  (for ([index (in-range 1 4)]
        [subject (in-list '(10 20 30))])
    (check-equal?
     (driver-eval! state `((checkpoint-110-rows select ,index) index))
     index)
    (check-equal?
     (driver-eval!
      state
      `(((checkpoint-110-rows select ,index) value) subject))
     subject)))

(test-case "List Mirror values retain exact mirror identity"
  (define state (make-loop-driver))
  (driver-eval! state '(define checkpoint-110-mirror-a (Mirror of 10)))
  (driver-eval! state '(define checkpoint-110-mirror-b (Mirror of 20)))
  (driver-eval!
   state
   '(define checkpoint-110-mirrors
      (List of checkpoint-110-mirror-a checkpoint-110-mirror-b)))
  (driver-eval!
   state
   '(define checkpoint-110-mirror-carrier
      (checkpoint-110-mirrors gel-values)))
  (driver-eval!
   state
   '(define checkpoint-110-mirror-rows
      (gel-menus value-rows checkpoint-110-mirror-carrier)))

  (for ([index (in-range 1 3)]
        [mirror-name (in-list '(checkpoint-110-mirror-a
                                checkpoint-110-mirror-b))]
        [subject (in-list '(10 20))])
    (check-eq?
     (driver-eval!
      state
      (list-item-datum '(checkpoint-110-mirror-carrier items)
                       (sub1 index)))
     (driver-eval! state mirror-name))
    (check-eq?
     (driver-eval!
      state
      `((checkpoint-110-mirror-rows select ,index) value))
     (driver-eval! state mirror-name))
    (check-equal?
     (driver-eval!
      state
      `(((checkpoint-110-mirror-rows select ,index) value) subject))
     subject)))

(test-case "an empty typed List is an empty Values menu"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-110-empty
      ((List of 1) rest)))
  (driver-eval!
   state
   '(define checkpoint-110-empty-menu
      (gel-menus of (Mirror of checkpoint-110-empty))))
  (define-value-rows!
   state 'checkpoint-110-empty-rows 'checkpoint-110-empty-menu)

  (check-true
   (driver-eval!
    state
    '(checkpoint-110-empty-menu case
       (Messages (rows) #f)
       (Values (rows) #t))))
  (check-equal? (driver-eval! state '(checkpoint-110-empty-rows len)) 0)
  (check-equal? (driver-eval! state '(gel-text menu checkpoint-110-empty)) "")
  (check-equal?
   (driver-eval!
    state
    '(gel-text menu (Mirror of checkpoint-110-empty)))
   ""))

(test-case "value rows expose only the first 24 list elements"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-110-many
      (List of
        1 2 3 4 5 6 7 8 9 10 11 12 13
        14 15 16 17 18 19 20 21 22 23 24 25 26)))
  (driver-eval!
   state
   '(define checkpoint-110-many-menu
      (gel-menus of (Mirror of checkpoint-110-many))))
  (define-value-rows!
   state 'checkpoint-110-many-rows 'checkpoint-110-many-menu)
  (driver-eval!
   state
   '(define checkpoint-110-many-stack
      (gel-empty-stack push checkpoint-110-many)))
  (driver-eval!
   state
   '(define checkpoint-110-many-state
      (GelStep new checkpoint-110-many-stack #f (List empty) 0 #f)))
  (driver-eval!
   state
   '(define checkpoint-110-hidden-twenty-five
      (checkpoint-110-many-state handle-key "25")))

  (define expected
    (apply string-append
           (for/list ([key (in-list value-item-keys)]
                      [value (in-range 1 25)])
             (format "~a  ~a\r\n" key value))))
  (define rendered
    (driver-eval! state '(gel-text menu checkpoint-110-many)))
  (check-equal? (driver-eval! state '(checkpoint-110-many-rows len)) 24)
  (check-equal? rendered expected)
  (check-equal?
   (driver-eval!
    state
    '(((checkpoint-110-many-rows select 24) value) subject))
   24)
  (check-false (regexp-match? #rx"25" rendered))
  (check-false (regexp-match? #rx"overflow|next|search" rendered))
  (check-eq? (driver-eval! state 'checkpoint-110-hidden-twenty-five)
             (driver-eval! state 'checkpoint-110-many-state)))

(test-case "List menu text is raw value data without List selectors"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-110-strings
      (List of "alpha" "beta" "gamma")))
  (define rendered
    (driver-eval! state '(gel-text menu checkpoint-110-strings)))
  (check-equal? rendered string-list-menu)
  (for ([selector
         (in-list '("empty?" "first" "rest" "cons" "len"
                    "map" "fold" "reverse" "gel-values"))])
    (check-false
     (regexp-match? (regexp (regexp-quote selector)) rendered)
     selector)))

(test-case "ordinary Mirror and idle routes share the same List menu"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-110-route-list
      (List of "alpha" "beta" "gamma")))
  (driver-eval!
   state
   '(define checkpoint-110-route-mirror
      (Mirror of checkpoint-110-route-list)))
  (driver-eval!
   state
   '(define checkpoint-110-route-state
      (GelStep new
        (gel-empty-stack push checkpoint-110-route-mirror)
        #f
        (List empty)
        0
        #f)))

  (define value-menu
    (driver-eval! state '(gel-text menu checkpoint-110-route-list)))
  (check-equal? value-menu string-list-menu)
  (check-equal?
   value-menu
   (driver-eval! state '(gel-text menu checkpoint-110-route-mirror)))
  (check-equal?
   value-menu
   (driver-eval! state '(gel-text menu checkpoint-110-route-state))))

(test-case "message and pending menus retain their exact bytes"
  (define state (make-loop-driver #:point? #t))
  (driver-eval! state '(define checkpoint-110-point (Point new 10 20)))
  (driver-eval!
   state
   '(define checkpoint-110-point-stack
      ((gel-empty-stack push (Point new 1 2))
       push
       checkpoint-110-point)))
  (driver-eval!
   state
   '(define checkpoint-110-point-state
      (GelStep new checkpoint-110-point-stack #f (List empty) 0 #f)))
  (driver-eval!
   state
   '(define checkpoint-110-point-rows
      (gel-rows of checkpoint-110-point)))
  (bind-row!
   state
   'checkpoint-110-point-plus-row
   'checkpoint-110-point-rows
   "+"
   1)
  (driver-eval!
   state
   '(define checkpoint-110-point-pending
      (GelStep new
        checkpoint-110-point-stack
        #f
        (List of checkpoint-110-point-plus-row)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-110-int-rows
      (gel-rows of 10)))
  (bind-row!
   state
   'checkpoint-110-int-plus-row
   'checkpoint-110-int-rows
   "+"
   1)
  (driver-eval!
   state
   '(define checkpoint-110-int-pending
      (GelStep new
        (gel-empty-stack push 10)
        #f
        (List of checkpoint-110-int-plus-row)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-110-int-typed
      (checkpoint-110-int-pending handle-key "2")))

  (check-equal?
   (driver-eval! state '(gel-text menu checkpoint-110-point-state))
   point-menu)
  (check-equal?
   (driver-eval! state '(gel-text menu 10))
   int-menu)
  (check-equal?
   (driver-eval! state '(gel-text menu checkpoint-110-point-pending))
   (string-append
    "pending +  #<List #<Symbol Point> #<Symbol Int>>\r\n"
    "1  #<Point 10 20>\r\n"
    "2  #<Point 1 2>\r\n"))
  (check-equal?
   (driver-eval! state '(gel-text menu checkpoint-110-int-pending))
   "pending +  Int \r\n")
  (check-equal?
   (driver-eval! state '(gel-text menu checkpoint-110-int-typed))
   "pending +  Int 2\r\n")
  (check-true
   (driver-eval!
    state
    '((gel-menus of (Mirror of checkpoint-110-point)) case
       (Messages (rows) #t)
       (Values (rows) #f)))))

(test-case "value selection pushes the exact mirror and Escape restores List"
  (define state (make-loop-driver))
  (driver-eval! state '(define checkpoint-110-value-a (Mirror of 10)))
  (driver-eval! state '(define checkpoint-110-value-b (Mirror of 20)))
  (driver-eval!
   state
   '(define checkpoint-110-select-list
      (List of checkpoint-110-value-a checkpoint-110-value-b)))
  (driver-eval!
   state
   '(define checkpoint-110-list-mirror
      (Mirror of checkpoint-110-select-list)))
  (driver-eval!
   state
   '(define checkpoint-110-list-stack
      ((gel-empty-stack push "history")
       push
       checkpoint-110-list-mirror)))
  (driver-eval!
   state
   '(define checkpoint-110-list-state
      (GelStep new checkpoint-110-list-stack #f (List empty) 0 #f)))
  (driver-eval!
   state
   '(define checkpoint-110-chosen
      (checkpoint-110-list-state handle-key "b")))
  (driver-eval!
   state
   '(define checkpoint-110-restored
      (checkpoint-110-chosen handle-key "escape")))

  (check-eq? (driver-eval! state '((checkpoint-110-chosen stack) tos))
             (driver-eval! state 'checkpoint-110-value-b))
  (check-eq?
   (driver-eval!
    state
    '((((checkpoint-110-chosen stack) items) rest) first))
   (driver-eval! state 'checkpoint-110-list-mirror))
  (check-equal?
   (driver-eval! state '(((checkpoint-110-chosen stack) items) len))
   3)
  (check-equal?
   (driver-eval!
    state
    '((((((checkpoint-110-chosen stack) items) rest) rest) first) subject))
   "history")
  (check-equal?
   (driver-eval! state '((checkpoint-110-chosen pending) len))
   0)
  (check-eq? (driver-eval! state '((checkpoint-110-restored stack) tos))
             (driver-eval! state 'checkpoint-110-list-mirror))
  (check-equal?
   (driver-eval! state '(((checkpoint-110-restored stack) items) len))
   2))

(test-case "List commands retain precedence and invalid keys are no-ops"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-110-short-list
      (List of 10 20 30)))
  (driver-eval!
   state
   '(define checkpoint-110-floor-stack
      (gel-empty-stack push checkpoint-110-short-list)))
  (driver-eval!
   state
   '(define checkpoint-110-short-state
      (GelStep new checkpoint-110-floor-stack #f (List empty) 0 #f)))

  (for ([key (in-list '("0" "2" "u" "A" "return" "d"))]
        [name (in-list '(checkpoint-110-zero
                         checkpoint-110-digit
                         checkpoint-110-u
                         checkpoint-110-uppercase
                         checkpoint-110-named
                         checkpoint-110-out-of-range))])
    (driver-eval!
     state
     `(define ,name
        (checkpoint-110-short-state handle-key ,key)))
    (check-eq? (driver-eval! state name)
               (driver-eval! state 'checkpoint-110-short-state)))

  (driver-eval!
   state
   '(define checkpoint-110-list-quit
      (checkpoint-110-short-state handle-key "q")))
  (driver-eval!
   state
   '(define checkpoint-110-list-floor
      (checkpoint-110-short-state handle-key "escape")))
  (check-true (driver-eval! state '(checkpoint-110-list-quit quit)))
  (check-eq? (driver-eval! state '(checkpoint-110-list-quit stack))
             (driver-eval! state 'checkpoint-110-floor-stack))
  (check-false (driver-eval! state '(checkpoint-110-list-floor quit)))
  (check-eq? (driver-eval! state '(checkpoint-110-list-floor stack))
             (driver-eval! state 'checkpoint-110-floor-stack)))

(test-case "a selected nested List receives its own value menu"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-110-nested
      (List of (List of 1 2) (List of 3 4))))
  (driver-eval!
   state
   '(define checkpoint-110-nested-state
      (GelStep new
        (gel-empty-stack push checkpoint-110-nested)
        #f
        (List empty)
        0
        #f)))
  (driver-eval!
   state
   '(define checkpoint-110-nested-chosen
      (checkpoint-110-nested-state handle-key "b")))

  (check-equal?
   (driver-eval! state '(((checkpoint-110-nested-chosen stack) tos) raw))
   "#<List 3 4>")
  (check-equal?
   (driver-eval! state '(gel-text menu checkpoint-110-nested-chosen))
   "a  3\r\nb  4\r\n")
  (check-equal?
   (driver-eval! state '((checkpoint-110-nested-chosen pending) len))
   0))

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

(test-case "GelMain renders chooses and returns to an in-memory List"
  (define-values (state terminal-output load-output reader-calls)
    (make-main-driver '("b" "escape" "q")))
  (driver-eval!
   state
   '(define checkpoint-110-main-value
      (List of 10 20)))
  (driver-eval!
   state
   '(define checkpoint-110-main-final
      (gel-main start checkpoint-110-main-value)))

  (define list-screen
    (string-append
     "TOS: #<List 10 20>\r\n"
     "a  10\r\n"
     "b  20\r\n"
     "\r\n"))
  (check-equal?
   (get-output-string terminal-output)
   (string-append
    list-screen
    "key b\r\n"
    (int-screen 20)
    "key escape\r\n"
    list-screen
    "key q\r\n"))
  (check-equal?
   (driver-eval! state '((checkpoint-110-main-final items) len))
   1)
  (check-equal?
   (driver-eval! state '((checkpoint-110-main-final tos) raw))
   "#<List 10 20>")
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 3))

(test-case "the minimal List application launches through GelMain.start"
  (define source (file->string gel-list-path))
  (check-equal?
   source
   (string-append
    "(define gel-start-value\n"
    "  (List of \"alpha\" \"beta\" \"gamma\"))\n"))
  (check-false
   (regexp-match?
    #rx"load|term|GelStack|gel-empty-stack|gel-main|#lang|require|lambda"
    source))

  (define-values (state terminal-output load-output reader-calls)
    (make-main-driver '("q")))
  (check-equal? (driver-load-file! state gel-list-path load-output) '())
  (check-equal?
   (driver-type-datum state 'gel-start-value)
   '(List String))
  (driver-eval!
   state
   '(define checkpoint-110-application-final
      (gel-main start gel-start-value)))
  (check-equal?
   (get-output-string terminal-output)
   (string-append
    "TOS: #<List \"alpha\" \"beta\" \"gamma\">\r\n"
    string-list-menu
    "\r\n"
    "key q\r\n"))
  (check-equal?
   (driver-eval! state '((checkpoint-110-application-final items) len))
   1)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 1))

(test-case "value rows add no kernel host runner filesystem or library path"
  (define runner-source (file->string gel-run-path))
  (check-regexp-match #rx"gel-main start gel-start-value" runner-source)
  (check-regexp-match #rx"driver-inject-host! state 'term term" runner-source)
  (check-false
   (regexp-match? #rx"gel-values|GelMenu|GelValue|fs-host" runner-source))
  (check-false
   (regexp-match? #rx"gel-values|GelMenu|GelValue"
                  (file->string list-library-path)))
  (for ([directory (in-list (list aloe-directory host-directory))])
    (for ([path (in-list (find-files file-exists? directory))])
      (when (file-exists? path)
        (check-false
         (regexp-match? #rx"gel-values|GelListValues|GelValueRow|GelMenu"
                        (file->string path))
         (path->string path)))))
  (define menu-source (file->string gel-menu-path))
  (check-equal?
   (length (regexp-match* #rx"\\(define-methods List" menu-source))
   1)

  (define state (make-driver))
  (for ([name (in-list '(term
                         fs-host
                         gel-start-value
                         GelMirrors
                         GelListValues
                         GelValueRow
                         GelValueRows
                         GelMenu
                         GelMenus))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))
