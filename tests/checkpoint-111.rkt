#lang racket/base

(require racket/file
         (only-in racket/list remove-duplicates take)
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
(define-runtime-path examples-directory "../examples")
(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-menu-path "../gel/menu.aloe")
(define-runtime-path gel-point-path "../examples/gel-point.aloe")
(define-runtime-path gel-stack-path "../gel/stack.aloe")
(define-runtime-path host-directory "../host")
(define-runtime-path lib-directory "../lib")

(define item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "n" "o" "p" "r" "s" "t" "v" "w" "x" "y" "z"))

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
    (check-equal?
     (driver-load-file! state gel-point-path output)
     '()))
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

(define (list-item-datum list-name zero-based-index)
  (define receiver
    (for/fold ([receiver list-name])
              ([_ (in-range zero-based-index)])
      (list receiver 'rest)))
  (list receiver 'first))

(define (define-value-rows! state rows-name list-name)
  (define menu-name
    (string->symbol (format "~a-menu" rows-name)))
  (driver-eval!
   state
   `(define ,menu-name
      (gel-menus of (Mirror of ,list-name))))
  (driver-eval!
   state
   `(define ,rows-name
      (,menu-name case
        (Messages (rows)
          (GelValueRows new (List empty)))
        (Values (rows) rows)))))

(test-case "item-key types and methods are Gel-local"
  (define fresh (make-driver))
  (for ([name (in-list '(GelItemKey GelItemKeys gel-item-keys))])
    (check-false (env-bound? (driver-runtime-environment fresh) name))
    (check-false
     (type-environment-bound? (driver-type-environment fresh) name)))

  (define state (make-loop-driver))
  (for ([datum+type
         (in-list
          '(((GelItemKey new 1 "a") GelItemKey)
            ((GelItemKeys new
               (List of (GelItemKey new 1 "a")))
             GelItemKeys)
            ((gel-item-keys len) Int)
            ((gel-item-keys select 1) GelItemKey)
            ((gel-item-keys index "a") Int)
            (((GelValueRow new 1 (Mirror of 10) "10") key) String)
            (((GelKey new "a") item-index) Int)))])
    (check-equal?
     (driver-type-datum state (car datum+type))
     (cadr datum+type))))

(test-case "the item-key pool has the exact ordered 24 entries"
  (define state (make-loop-driver))
  (check-equal? (driver-eval! state '(gel-item-keys len)) 24)
  (define actual-texts
    (for/list ([expected (in-list item-keys)]
               [index (in-naturals 1)])
      (check-equal?
       (driver-eval! state `((gel-item-keys select ,index) index))
       index)
      (check-eq?
       (driver-eval! state `(gel-item-keys select ,index))
       (driver-eval!
        state
        (list-item-datum '(gel-item-keys items) (sub1 index))))
      (define actual
        (driver-eval! state `((gel-item-keys select ,index) text)))
      (check-equal? actual expected)
      actual))
  (check-equal? actual-texts item-keys)
  (check-equal? (length (remove-duplicates actual-texts)) 24)
  (check-false (member "q" actual-texts))
  (check-false (member "u" actual-texts)))

(test-case "pool selection reverse lookup and GelKey parsing agree"
  (define state (make-loop-driver))
  (for ([text (in-list item-keys)]
        [index (in-naturals 1)])
    (check-equal? (driver-eval! state `(gel-item-keys index ,text)) index)
    (check-equal?
     (driver-eval! state `((GelKey new ,text) item-index))
     index))
  (for ([text
         (in-list
          '("q" "u" "escape" "0" "1" "9" "A" "Q" "U" "/"
            "return" "left" "aa" "!" ""))])
    (check-equal? (driver-eval! state `(gel-item-keys index ,text)) 0)
    (check-equal?
     (driver-eval! state `((GelKey new ,text) item-index))
     0)))

(test-case "value-row capacity follows all 24 item keys"
  (define state (make-loop-driver))
  (driver-eval! state '(define checkpoint-111-empty ((List of 1) rest)))
  (driver-eval! state '(define checkpoint-111-one (List of 1)))
  (driver-eval!
   state
   '(define checkpoint-111-twenty-four
      (List of
        1 2 3 4 5 6 7 8 9 10 11 12
        13 14 15 16 17 18 19 20 21 22 23 24)))
  (driver-eval!
   state
   '(define checkpoint-111-overflow
      (List of
        1 2 3 4 5 6 7 8 9 10 11 12 13
        14 15 16 17 18 19 20 21 22 23 24 25 26)))
  (for ([list-name
         (in-list '(checkpoint-111-empty
                    checkpoint-111-one
                    checkpoint-111-twenty-four
                    checkpoint-111-overflow))]
        [rows-name
         (in-list '(checkpoint-111-empty-rows
                    checkpoint-111-one-rows
                    checkpoint-111-twenty-four-rows
                    checkpoint-111-overflow-rows))]
        [expected-len (in-list '(0 1 24 24))])
    (define-value-rows! state rows-name list-name)
    (check-equal?
     (driver-eval! state `(,rows-name len))
     expected-len)))

(test-case "long Lists preserve mirror identity order and omission boundaries"
  (define state (make-loop-driver))
  (define mirror-names
    (for/list ([index (in-range 1 26)])
      (define name
        (string->symbol (format "checkpoint-111-mirror-~a" index)))
      (driver-eval! state `(define ,name (Mirror of ,index)))
      name))
  (driver-eval!
   state
   `(define checkpoint-111-mirror-list
      (List of ,@mirror-names)))
  (driver-eval!
   state
   '(define checkpoint-111-mirror-carrier
      (checkpoint-111-mirror-list gel-values)))
  (driver-eval!
   state
   '(define checkpoint-111-mirror-rows
      (gel-menus value-rows checkpoint-111-mirror-carrier)))

  (check-equal? (driver-eval! state '(checkpoint-111-mirror-rows len)) 24)
  (for ([name (in-list (take mirror-names 24))]
        [index (in-naturals 1)]
        [key (in-list item-keys)])
    (check-eq?
     (driver-eval!
      state
      `((checkpoint-111-mirror-rows select ,index) value))
     (driver-eval! state name))
    (check-equal?
     (driver-eval!
      state
      `(((checkpoint-111-mirror-rows select ,index) value) subject))
     index)
    (check-equal?
     (driver-eval! state `((checkpoint-111-mirror-rows select ,index) key))
     key))
  (for ([index (in-list '(16 17 19 20))]
        [key (in-list '("p" "r" "t" "v"))])
    (check-equal?
     (driver-eval! state `((checkpoint-111-mirror-rows select ,index) key))
     key))
  (check-false
   (regexp-match? #rx"25"
                  (driver-eval!
                   state
                   '(gel-text menu checkpoint-111-mirror-list)))))

(test-case "List menu bytes use only position-bound item letters"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-111-menu-list
      (List of "alpha" "beta" "gamma")))
  (define rendered
    (driver-eval! state '(gel-text menu checkpoint-111-menu-list)))
  (check-equal?
   rendered
   (string-append
    "a  \"alpha\"\r\n"
    "b  \"beta\"\r\n"
    "c  \"gamma\"\r\n"))
  (check-false (regexp-match? #px"(?m:^[qu]  )" rendered))
  (check-false (regexp-match? #rx"overflow|next|previous|paging|search"
                              rendered)))

(test-case "the same value receives a fresh key from each listing position"
  (define state (make-loop-driver))
  (driver-eval! state '(define checkpoint-111-shared (Mirror of 20)))
  (driver-eval! state '(define checkpoint-111-other-a (Mirror of 10)))
  (driver-eval! state '(define checkpoint-111-other-b (Mirror of 30)))
  (driver-eval!
   state
   '(define checkpoint-111-first-list
      (List of checkpoint-111-shared
               checkpoint-111-other-a
               checkpoint-111-other-b)))
  (driver-eval!
   state
   '(define checkpoint-111-third-list
      (List of checkpoint-111-other-a
               checkpoint-111-other-b
               checkpoint-111-shared)))
  (define-value-rows!
   state 'checkpoint-111-first-rows 'checkpoint-111-first-list)
  (define-value-rows!
   state 'checkpoint-111-third-rows 'checkpoint-111-third-list)
  (check-eq?
   (driver-eval! state '((checkpoint-111-first-rows select 1) value))
   (driver-eval! state 'checkpoint-111-shared))
  (check-eq?
   (driver-eval! state '((checkpoint-111-third-rows select 3) value))
   (driver-eval! state 'checkpoint-111-shared))
  (check-equal?
   (driver-eval! state '((checkpoint-111-first-rows select 1) key))
   "a")
  (check-equal?
   (driver-eval! state '((checkpoint-111-third-rows select 3) key))
   "c"))

(test-case "every visible item letter selects its exact mirror and escapes back"
  (define state (make-loop-driver))
  (define mirror-names
    (for/list ([index (in-range 1 25)])
      (define name
        (string->symbol (format "checkpoint-111-select-mirror-~a" index)))
      (driver-eval! state `(define ,name (Mirror of ,index)))
      name))
  (driver-eval!
   state
   `(define checkpoint-111-select-list
      (List of ,@mirror-names)))
  (driver-eval!
   state
   '(define checkpoint-111-select-list-mirror
      (Mirror of checkpoint-111-select-list)))
  (driver-eval!
   state
   '(define checkpoint-111-select-stack
      ((gel-empty-stack push "history")
       push
       checkpoint-111-select-list-mirror)))
  (driver-eval!
   state
   '(define checkpoint-111-select-state
      (GelStep new checkpoint-111-select-stack #f (List empty) 0 #f #f)))

  (for ([key (in-list item-keys)]
        [mirror-name (in-list mirror-names)]
        [index (in-naturals 1)])
    (define chosen-name
      (string->symbol (format "checkpoint-111-chosen-~a" index)))
    (driver-eval!
     state
     `(define ,chosen-name
        (checkpoint-111-select-state handle-key ,key)))
    (check-eq? (driver-eval! state `((,chosen-name stack) tos))
               (driver-eval! state mirror-name))
    (check-eq?
     (driver-eval! state `((((,chosen-name stack) items) rest) first))
     (driver-eval! state 'checkpoint-111-select-list-mirror))
    (check-equal? (driver-eval! state `(((,chosen-name stack) items) len)) 3)
    (check-equal?
     (driver-eval!
      state
      `((((((,chosen-name stack) items) rest) rest) first) subject))
     "history")
    (check-equal? (driver-eval! state `((,chosen-name pending) len)) 0)
    (check-false (driver-eval! state `(,chosen-name quit)))
    (check-eq?
     (driver-eval!
      state
      `(((,chosen-name handle-key "escape") stack) tos))
     (driver-eval! state 'checkpoint-111-select-list-mirror))))

(test-case "List commands win and absent or out-of-range item keys are no-ops"
  (define state (make-loop-driver))
  (driver-eval! state '(define checkpoint-111-short (List of 10 20 30)))
  (driver-eval!
   state
   '(define checkpoint-111-floor-stack
      (gel-empty-stack push checkpoint-111-short)))
  (driver-eval!
   state
   '(define checkpoint-111-short-state
      (GelStep new checkpoint-111-floor-stack #f (List empty) 0 #f #f)))
  (for ([key
         (in-list
          '("0" "1" "9" "u" "A" "B" "/" "return" "left" "aa"
            "d" "z"))])
    (check-eq?
     (driver-eval! state `(checkpoint-111-short-state handle-key ,key))
     (driver-eval! state 'checkpoint-111-short-state)))

  (driver-eval!
   state
   '(define checkpoint-111-quit
      (checkpoint-111-short-state handle-key "q")))
  (driver-eval!
   state
   '(define checkpoint-111-floor
      (checkpoint-111-short-state handle-key "escape")))
  (check-true (driver-eval! state '(checkpoint-111-quit quit)))
  (check-eq? (driver-eval! state '(checkpoint-111-quit stack))
             (driver-eval! state 'checkpoint-111-floor-stack))
  (check-eq? (driver-eval! state '(checkpoint-111-floor stack))
             (driver-eval! state 'checkpoint-111-floor-stack))

  (driver-eval!
   state
   '(define checkpoint-111-history-stack
      ((gel-empty-stack push "history") push checkpoint-111-short)))
  (driver-eval!
   state
   '(define checkpoint-111-history-state
      (GelStep new checkpoint-111-history-stack #f (List empty) 0 #f #f)))
  (check-equal?
   (driver-eval!
    state
    '((((checkpoint-111-history-state handle-key "escape") stack) tos)
      subject))
   "history"))

(test-case "derived Point and Int menus and selection keep digit keys"
  (define state (make-loop-driver #:point? #t))
  (driver-eval! state '(define checkpoint-111-point (Point new 10 20)))
  (driver-eval!
   state
   '(define checkpoint-111-point-stack
      (gel-empty-stack push checkpoint-111-point)))
  (driver-eval!
   state
   '(define checkpoint-111-point-state
      (GelStep new checkpoint-111-point-stack #f (List empty) 0 #f #f)))
  (driver-eval!
   state
   '(define checkpoint-111-point-digit
      (checkpoint-111-point-state handle-key "1")))
  (driver-eval!
   state
   '(define checkpoint-111-point-letter
      (checkpoint-111-point-state handle-key "a")))
  (check-equal? (driver-eval! state '(gel-text menu checkpoint-111-point))
                point-menu)
  (check-equal?
   (driver-eval! state '(((checkpoint-111-point-digit stack) tos) subject))
   10)
  (check-eq? (driver-eval! state '(checkpoint-111-point-letter stack))
             (driver-eval! state 'checkpoint-111-point-stack))
  (check-equal?
   (driver-eval! state '((checkpoint-111-point-letter pending) len))
   0)

  (driver-eval!
   state
   '(define checkpoint-111-int-stack (gel-empty-stack push 10)))
  (driver-eval!
   state
   '(define checkpoint-111-int-state
      (GelStep new checkpoint-111-int-stack #f (List empty) 0 #f #f)))
  (driver-eval!
   state
   '(define checkpoint-111-int-digit
      (checkpoint-111-int-state handle-key "1")))
  (driver-eval!
   state
   '(define checkpoint-111-int-letter
      (checkpoint-111-int-state handle-key "a")))
  (check-equal? (driver-eval! state '(gel-text menu 10)) int-menu)
  (check-equal? (driver-eval! state '((checkpoint-111-int-digit pending) len))
                1)
  (check-eq? (driver-eval! state '(checkpoint-111-int-letter stack))
             (driver-eval! state 'checkpoint-111-int-stack))
  (check-equal?
   (driver-eval! state '((checkpoint-111-int-letter pending) len))
   0)
  (check-equal? (driver-eval! state '((GelKey new "2") menu-index)) 2)
  (check-equal? (driver-eval! state '((GelKey new "2") item-index)) 0)
  (check-equal? (driver-eval! state '((GelKey new "b") menu-index)) 0)
  (check-equal? (driver-eval! state '((GelKey new "b") item-index)) 2))

(test-case "pending picks and Int entry retain digit command behavior"
  (define state (make-loop-driver #:point? #t))
  (driver-eval!
   state
   '(define checkpoint-111-pick-stack
      ((gel-empty-stack push (Point new 1 2))
       push
       (Point new 10 20))))
  (driver-eval!
   state
   '(define checkpoint-111-point-rows
      (gel-rows of (Point new 10 20))))
  (bind-row!
   state
   'checkpoint-111-point-plus
   'checkpoint-111-point-rows
   "+"
   1)
  (driver-eval!
   state
   '(define checkpoint-111-pick-pending
      (GelStep new
        checkpoint-111-pick-stack
        #f
        (List of checkpoint-111-point-plus)
        0
        #f
        #f)))
  (check-eq?
   (driver-eval! state '(checkpoint-111-pick-pending handle-key "a"))
   (driver-eval! state 'checkpoint-111-pick-pending))
  (check-equal?
   (driver-eval!
    state
    '((((checkpoint-111-pick-pending handle-key "2") stack) tos) raw))
   "#<Point 11 22>")
  (check-true
   (driver-eval!
    state
    '((checkpoint-111-pick-pending handle-key "q") quit)))
  (check-equal?
   (driver-eval!
    state
    '(((checkpoint-111-pick-pending handle-key "escape") pending) len))
   0)
  (check-eq?
   (driver-eval!
    state
    '((checkpoint-111-pick-pending handle-key "escape") stack))
   (driver-eval! state 'checkpoint-111-pick-stack))

  (driver-eval! state '(define checkpoint-111-int-rows (gel-rows of 10)))
  (bind-row!
   state
   'checkpoint-111-int-plus
   'checkpoint-111-int-rows
   "+"
   1)
  (driver-eval!
   state
   '(define checkpoint-111-int-pending
      (GelStep new
        (gel-empty-stack push 10)
        #f
        (List of checkpoint-111-int-plus)
        0
        #f
        #f)))
  (check-eq?
   (driver-eval! state '(checkpoint-111-int-pending handle-key "b"))
   (driver-eval! state 'checkpoint-111-int-pending))
  (driver-eval!
   state
   '(define checkpoint-111-int-two
      (checkpoint-111-int-pending handle-key "2")))
  (check-equal? (driver-eval! state '(checkpoint-111-int-two int-input)) 2)
  (check-true (driver-eval! state '(checkpoint-111-int-two has-digits)))
  (check-equal?
   (driver-eval!
    state
    '((((checkpoint-111-int-two handle-key "return") stack) tos) subject))
   12)
  (check-true
   (driver-eval!
    state
    '((checkpoint-111-int-pending handle-key "q") quit)))
  (check-equal?
   (driver-eval!
    state
    '(((checkpoint-111-int-pending handle-key "escape") pending) len))
   0))

(test-case "a letter-selected nested List receives its own letter menu"
  (define state (make-loop-driver))
  (driver-eval!
   state
   '(define checkpoint-111-nested
      (List of (List of 1 2) (List of 3 4))))
  (driver-eval!
   state
   '(define checkpoint-111-nested-state
      (GelStep new
        (gel-empty-stack push checkpoint-111-nested)
        #f
        (List empty)
        0
        #f
        #f)))
  (driver-eval!
   state
   '(define checkpoint-111-nested-chosen
      (checkpoint-111-nested-state handle-key "b")))
  (check-equal?
   (driver-eval! state '(((checkpoint-111-nested-chosen stack) tos) raw))
   "#<List 3 4>")
  (check-equal?
   (driver-eval! state '(gel-text menu checkpoint-111-nested-chosen))
   "a  3\r\nb  4\r\n")
  (check-equal?
   (driver-eval! state '((checkpoint-111-nested-chosen pending) len))
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

(test-case "GelMain scripts letters while derived Int rows stay digits"
  (define-values (term terminal-output reader-calls)
    (make-scripted-term '("b" "escape" "q")))
  (define state (make-driver))
  (define load-output (open-output-string))
  (driver-inject-host! state 'term term)
  (check-equal? (driver-load-file! state gel-main-path load-output) '())
  (driver-eval! state '(define checkpoint-111-main-list (List of 10 20)))
  (driver-eval!
   state
   '(define checkpoint-111-main-final
      (gel-main start checkpoint-111-main-list)))

  (define list-screen
    (string-append
     "TOS: #<List 10 20>\r\n"
     "a  10\r\n"
     "b  20\r\n"
     "\r\n"))
  (define int-screen
    (string-append "TOS: 20\r\n" int-menu "\r\n"))
  (check-equal?
   (get-output-string terminal-output)
   (string-append
    list-screen
    "key b\r\n"
    int-screen
    "key escape\r\n"
    list-screen
    "key q\r\n"))
  (check-equal?
   (driver-eval! state '((checkpoint-111-main-final items) len))
   1)
  (check-equal?
   (driver-eval! state '((checkpoint-111-main-final tos) raw))
   "#<List 10 20>")
  (check-eq?
   (driver-eval! state '((checkpoint-111-main-final tos) subject))
   (driver-eval! state 'checkpoint-111-main-list))
  (check-equal? (get-output-string load-output) "")
  (check-equal? (unbox reader-calls) 3))

(test-case "item keys add one Gel-local pool and no broader capability"
  (define menu-source (file->string gel-menu-path))
  (define loop-source (file->string gel-loop-path))
  (check-equal?
   (length (regexp-match* #rx"\\(define gel-item-keys" menu-source))
   1)
  (check-equal?
   (length (regexp-match* #rx"\\(GelItemKey new" menu-source))
   24)
  (check-false (regexp-match? #rx"fs-host|Directory|paging|search|perform"
                              menu-source))
  (check-false (regexp-match? #rx"GelItemKey new|fs-host|Directory|up\\?"
                              loop-source))
  (for ([path (in-list (list gel-stack-path gel-main-path))])
    (check-false
     (regexp-match? #rx"GelItemKey|gel-item-keys|item-index"
                    (file->string path))))
  (for ([directory
         (in-list
          (list aloe-directory
                host-directory
                lib-directory
                examples-directory))])
    (for ([path
           (in-list
            (find-files
             (lambda (candidate)
               (and (file-exists? candidate)
                    (regexp-match? #rx"\\.(rkt|aloe)$"
                                   (path->string candidate))))
             directory))])
      (check-false
       (regexp-match? #rx"GelItemKey|gel-item-keys|item-index"
                      (file->string path))
       (path->string path))))

  (define fresh (make-driver))
  (for ([name
         (in-list
          '(term fs-host gel-start-value GelItemKey GelItemKeys gel-item-keys))])
    (check-false (env-bound? (driver-runtime-environment fresh) name))
    (check-false
     (type-environment-bound? (driver-type-environment fresh) name))))
