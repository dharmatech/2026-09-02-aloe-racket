#lang racket/base

(require racket/file
         racket/format
         racket/list
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         "../aloe/driver.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt" type-of type->datum)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

(define-runtime-path aloe-directory "../aloe")
(define-runtime-path lib-directory "../lib")
(define-runtime-path host-directory "../host")
(define-runtime-path disk-library-path "../lib/disk.aloe")
(define-runtime-path gel-directory-path "../gel/directory.aloe")
(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-menu-path "../gel/menu.aloe")
(define-runtime-path gel-point-path "../examples/point.aloe")
(define-runtime-path gel-directory-application-path
  "../examples/gel-directory.aloe")

(define item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "o" "r" "s" "t" "v" "w" "x" "y" "z"))

(define (driver-type-datum state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (load-silently! state path [output (open-output-string)])
  (check-equal? (driver-load-file! state path output) '())
  output)

(define (make-loop-driver)
  (define state (make-driver))
  (define output (load-silently! state gel-loop-path))
  (check-equal? (get-output-string output) "")
  state)

(define (make-directory-driver nodes
                               #:current [current "/cwd"]
                               #:main? [main? #f]
                               #:term [term #f])
  (define state (make-driver))
  (define output (open-output-string))
  (when term
    (driver-inject-host! state 'term term))
  (driver-inject-host! state 'fs-host (make-fs-double current nodes))
  (load-silently! state (if main? gel-main-path gel-loop-path) output)
  (load-silently! state disk-library-path output)
  (load-silently! state gel-directory-path output)
  (check-equal? (get-output-string output) "")
  state)

(define (ordinary-nodes count)
  (for/fold ([nodes (hash "/" 'directory "/cwd" 'directory)])
            ([index (in-range 1 (add1 count))])
    (hash-set nodes
              (format "/cwd/name~a"
                      (~r index #:min-width 2 #:pad-string "0"))
              'file)))

(define (mixed-overflow-nodes)
  (define hidden
    (for/fold ([nodes (hash "/" 'directory "/cwd" 'directory)])
              ([index (in-range 1 24)])
      (hash-set nodes
                (format "/cwd/.hidden~a"
                        (~r index #:min-width 2 #:pad-string "0"))
                'file)))
  (for/fold ([nodes hidden]) ([index (in-range 1 26)])
    (hash-set nodes
              (format "/cwd/ordinary~a"
                      (~r index #:min-width 2 #:pad-string "0"))
              (cond [(= index 24) 'directory]
                    [(= index 25) 'symlink]
                    [else 'file]))))

(define (define-directory! state name [path "/cwd"])
  (driver-eval!
   state
   `(define ,name (Directory new ((Disk new fs-host) at ,path)))))

(define (define-state! state name stack-expression
                       #:show-hidden [show-hidden #f]
                       #:page [page 0]
                       #:pending [pending '(List empty)]
                       #:int-input [int-input 0]
                       #:has-digits [has-digits #f])
  (driver-eval!
   state
   `(define ,name
      (GelStep new
        ,stack-expression
        #f
        ,pending
        ,int-input
        ,has-digits
        ,show-hidden
        ,page))))

(define (define-value-rows! state rows-name menu-expression)
  (define menu-name (string->symbol (format "~a-menu" rows-name)))
  (driver-eval! state `(define ,menu-name ,menu-expression))
  (driver-eval!
   state
   `(define ,rows-name
      (,menu-name case
        (Messages (rows) (GelValueRows new (List empty)))
        (Values (rows) rows)))))

(define (row-labels state rows-name count)
  (for/list ([index (in-range 1 (add1 count))])
    (driver-eval! state `((,rows-name select ,index) label))))

(define (row-keys state rows-name count)
  (for/list ([index (in-range 1 (add1 count))])
    (driver-eval! state `((,rows-name select ,index) key))))

(define (bind-row! state name rows-expression selector arity)
  (driver-eval!
   state
   `(define ,name
      (,rows-expression fold
        (,rows-expression first)
        (fn (found row)
          (if (((row selector) name) = ,selector)
              (if ((row arity) = ,arity) row found)
              found))))))

(define (make-scripted-term keys)
  (define remaining (box keys))
  (define calls (box 0))
  (define output (open-output-string))
  (values
   (make-term-receiver
    output
    (lambda ()
      (define keys-left (unbox remaining))
      (unless (pair? keys-left)
        (error 'checkpoint-117 "key script exhausted"))
      (set-box! remaining (cdr keys-left))
      (set-box! calls (add1 (unbox calls)))
      (car keys-left)))
   output
   calls))

(test-case "the shared item pool is 22 letters and Lists remain unpaged"
  (define state (make-loop-driver))
  (check-equal? (driver-eval! state '(gel-item-keys len)) 22)
  (for ([text (in-list item-keys)] [index (in-naturals 1)])
    (check-equal? (driver-eval! state `((gel-item-keys select ,index) text))
                  text)
    (check-equal? (driver-eval! state `(gel-item-keys index ,text)) index)
    (check-equal? (driver-eval! state `((GelKey new ,text) item-index))
                  index))
  (for ([text '("n" "p" "q" "u")])
    (check-equal? (driver-eval! state `(gel-item-keys index ,text)) 0)
    (check-equal? (driver-eval! state `((GelKey new ,text) item-index)) 0))
  (check-true (driver-eval! state '((GelKey new "n") next?)))
  (check-true (driver-eval! state '((GelKey new "p") prev?)))
  (for ([text '("N" "P" "next" "prev")])
    (check-false (driver-eval! state `((GelKey new ,text) next?)))
    (check-false (driver-eval! state `((GelKey new ,text) prev?))))

  (driver-eval! state '(define empty-list ((List of 1) rest)))
  (driver-eval! state '(define one-list (List of 1)))
  (driver-eval!
   state
   '(define twenty-two-list
      (List of 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22)))
  (driver-eval!
   state
   '(define long-list
      (List of 1 2 3 4 5 6 7 8 9 10 11 12 13
               14 15 16 17 18 19 20 21 22 23 24 25)))
  (for ([name '(empty-list one-list twenty-two-list long-list)]
        [length '(0 1 22 22)])
    (define rows-name (string->symbol (format "~a-rows" name)))
    (define-value-rows!
     state rows-name `(gel-menus of (Mirror of ,name) #f 7))
    (check-equal? (driver-eval! state `(,rows-name len)) length)
    (define text (driver-eval! state `(gel-text menu ,name)))
    (check-false (string-contains? text "n  next\r\n"))
    (check-false (string-contains? text "p  prev\r\n")))
  (define-state! state 'list-state '(gel-empty-stack push long-list) #:page 4)
  (for ([key '("n" "p" "N" "P")])
    (check-eq? (driver-eval! state `(list-state handle-key ,key))
               (driver-eval! state 'list-state))))

(test-case "Directory selectors stay full and GelMenus windows after filtering"
  (define state (make-directory-driver (mixed-overflow-nodes)))
  (define-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (driver-eval!
   state
   '(define filtered-full
      (gel-directory-presentations directory-values cwd)))
  (driver-eval!
   state
   '(define all-full
      (gel-directory-presentations directory-all-values cwd)))
  (check-equal? (driver-eval! state '(filtered-full len)) 25)
  (check-equal? (driver-eval! state '(all-full len)) 48)
  (check-equal? (car (row-labels state 'filtered-full 25)) "ordinary01")
  (check-equal? (take-right (row-labels state 'filtered-full 25) 3)
                '("ordinary23" "ordinary24/" "ordinary25@"))
  (check-equal? (car (row-labels state 'all-full 48)) ".hidden01")

  (define-value-rows! state 'page-zero
    '(gel-menus of cwd-mirror #f 0))
  (define-value-rows! state 'page-one
    '(gel-menus of cwd-mirror #f 1))
  (define-value-rows! state 'shown-page-zero
    '(gel-menus of cwd-mirror #t 0))
  (define-value-rows! state 'shown-page-one
    '(gel-menus of cwd-mirror #t 1))
  (check-equal? (driver-eval! state '(page-zero len)) 22)
  (check-equal? (driver-eval! state '(page-one len)) 3)
  (check-equal? (row-labels state 'page-one 3)
                '("ordinary23" "ordinary24/" "ordinary25@"))
  (check-equal? (row-keys state 'page-one 3) '("a" "b" "c"))
  (check-equal? (driver-eval! state '(shown-page-zero len)) 22)
  (check-equal? (car (row-labels state 'shown-page-zero 22)) ".hidden01")
  (check-equal? (last (row-labels state 'shown-page-zero 22)) ".hidden22")
  (check-equal? (driver-eval! state '(shown-page-one len)) 22)
  (check-equal? (car (row-labels state 'shown-page-one 22)) ".hidden23")
  (check-equal? (last (row-labels state 'shown-page-one 22)) "ordinary21"))

(test-case "Directory n and p move bounded pages without changing the stack"
  (define state (make-directory-driver (ordinary-nodes 25)))
  (define-directory! state 'cwd)
  (define-state! state 'page-zero '(gel-empty-stack push cwd))
  (define-value-rows! state 'first-page
    '(gel-menus of ((page-zero stack) tos) #f 0))
  (check-equal? (row-labels state 'first-page 22)
                (for/list ([index (in-range 1 23)])
                  (format "name~a" (~r index #:min-width 2 #:pad-string "0"))))
  (check-equal? (row-keys state 'first-page 22) item-keys)
  (driver-eval! state '(define page-one (page-zero handle-key "n")))
  (driver-eval! state '(define page-two (page-one handle-key "n")))
  (driver-eval! state '(define back-zero (page-one handle-key "p")))
  (driver-eval! state '(define before-zero (page-zero handle-key "p")))
  (check-equal? (driver-eval! state '(page-one page)) 1)
  (check-eq? (driver-eval! state '(page-one stack))
             (driver-eval! state '(page-zero stack)))
  (check-eq? (driver-eval! state 'page-two)
             (driver-eval! state 'page-one))
  (check-equal? (driver-eval! state '(back-zero page)) 0)
  (check-eq? (driver-eval! state '(back-zero stack))
             (driver-eval! state '(page-zero stack)))
  (check-eq? (driver-eval! state 'before-zero)
             (driver-eval! state 'page-zero))
  (driver-eval! state '(define chosen (page-one handle-key "a")))
  (check-equal? (driver-eval! state '(chosen page)) 0)
  (check-equal? (driver-eval! state '(((chosen stack) tos) raw))
                "#<File #<Location #<FsHost> \"/cwd/name23\">>"))

(test-case "Directory command text has exact bytes on every page"
  (define nodes
    (hash "/" 'directory
          "/cwd" 'directory
          "/cwd/.secret" 'file
          "/cwd/alpha" 'file
          "/cwd/bravo" 'directory))
  (define state (make-directory-driver nodes))
  (define-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (check-equal?
   (driver-eval! state '(gel-text menu cwd-mirror #f 0))
   (string-append
    "a  alpha\r\n"
    "b  bravo/\r\n"
    "\r\n"
    "u  up\r\n"
    ".  show hidden\r\n"
    "n  next\r\n"
    "p  prev\r\n"))
  (check-equal?
   (driver-eval! state '(gel-text menu cwd-mirror #t 0))
   (string-append
    "a  .secret\r\n"
    "b  alpha\r\n"
    "c  bravo/\r\n"
    "\r\n"
    "u  up\r\n"
    ".  hide hidden\r\n"
    "n  next\r\n"
    "p  prev\r\n"))
  (check-equal?
   (driver-eval! state '(gel-text menu cwd-mirror #f 1))
   "u  up\r\n.  show hidden\r\nn  next\r\np  prev\r\n")
  (check-equal?
   (driver-eval! state '(gel-text menu cwd-mirror #t 1))
   "u  up\r\n.  hide hidden\r\nn  next\r\np  prev\r\n"))

(test-case "page resets on navigation and hidden toggles while visibility persists"
  (define nodes
    (hash-set* (mixed-overflow-nodes)
               "/cwd/sub" 'directory
               "/cwd/sub/child" 'file))
  (define state (make-directory-driver nodes))
  (define-directory! state 'cwd)
  (define-directory! state 'sub "/cwd/sub")
  (define-state! state 'shown-page-one '(gel-empty-stack push cwd)
                 #:show-hidden #t #:page 1)
  (driver-eval! state '(define pushed (shown-page-one handle-key "a")))
  (check-equal? (driver-eval! state '(pushed page)) 0)
  (check-true (driver-eval! state '(pushed show-hidden)))
  (driver-eval! state '(define popped (shown-page-one handle-key "escape")))
  (check-equal? (driver-eval! state '(popped page)) 0)
  (check-true (driver-eval! state '(popped show-hidden)))
  (check-eq? (driver-eval! state '(popped stack))
             (driver-eval! state '(shown-page-one stack)))

  (define-state! state 'sub-page '(gel-empty-stack push sub)
                 #:show-hidden #t #:page 3)
  (driver-eval! state '(define parent (sub-page handle-key "u")))
  (check-equal? (driver-eval! state '(parent page)) 0)
  (check-true (driver-eval! state '(parent show-hidden)))
  (check-equal? (driver-eval! state '(((parent stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/cwd\">>")

  (define-state! state 'hidden-page-one '(gel-empty-stack push cwd) #:page 1)
  (driver-eval! state '(define toggled (hidden-page-one handle-key ".")))
  (check-equal? (driver-eval! state '(toggled page)) 0)
  (check-true (driver-eval! state '(toggled show-hidden)))
  (check-true
   (string-prefix? (driver-eval! state '(gel-text menu toggled))
                   "a  .hidden01\r\n"))

  (load-silently! state gel-point-path)
  (define-state! state 'point-page
                 '(gel-empty-stack push (Point new 10 20)) #:page 4)
  (driver-eval! state '(define zero-send (point-page handle-key "1")))
  (driver-eval! state '(define pending (point-page handle-key "3")))
  (driver-eval! state '(define cancelled (pending handle-key "escape")))
  (driver-eval! state '(define quit (pending handle-key "q")))
  (check-equal? (driver-eval! state '(zero-send page)) 0)
  (check-equal? (driver-eval! state '(pending page)) 4)
  (check-equal? (driver-eval! state '(cancelled page)) 4)
  (check-equal? (driver-eval! state '(quit page)) 4)
  (check-true (driver-eval! state '(quit quit)))
  (driver-eval! state '(define point-no-op (point-page handle-key "return")))
  (check-equal? (driver-eval! state '(point-no-op page)) 4)
  (check-eq? (driver-eval! state '(point-no-op stack))
             (driver-eval! state '(point-page stack))))

(test-case "pending n and p are no-ops for Int entry and stack picks"
  (define state (make-loop-driver))
  (load-silently! state gel-point-path)
  (driver-eval! state '(define int-rows (gel-rows of 10)))
  (bind-row! state 'int-plus 'int-rows "+" 1)
  (define-state! state 'int-pending '(gel-empty-stack push 10)
                 #:page 5 #:pending '(List of int-plus)
                 #:int-input 42 #:has-digits #t)
  (for ([key '("n" "p")])
    (check-eq? (driver-eval! state `(int-pending handle-key ,key))
               (driver-eval! state 'int-pending)))
  (driver-eval! state '(define int-invoked (int-pending handle-key "return")))
  (check-equal? (driver-eval! state '(int-invoked page)) 0)
  (check-equal? (driver-eval! state '(((int-invoked stack) tos) subject)) 52)

  (driver-eval! state '(define point-rows (gel-rows of (Point new 10 20))))
  (bind-row! state 'point-plus 'point-rows "+" 1)
  (define-state!
    state 'point-pending
    '((gel-empty-stack push (Point new 1 2)) push (Point new 10 20))
    #:page 5 #:pending '(List of point-plus))
  (for ([key '("n" "p")])
    (check-eq? (driver-eval! state `(point-pending handle-key ,key))
               (driver-eval! state 'point-pending)))
  (driver-eval! state '(define point-invoked (point-pending handle-key "2")))
  (check-equal? (driver-eval! state '(point-invoked page)) 0)
  (check-equal? (driver-eval! state '(((point-invoked stack) tos) raw))
                "#<Point 11 22>"))

(test-case "Directory controls retain precedence and other surfaces stay unchanged"
  (define nodes
    (hash "/" 'directory
          "/cwd" 'directory
          "/cwd/.hidden" 'file
          "/cwd/alpha" 'file
          "/cwd/sub" 'directory))
  (define state (make-directory-driver nodes))
  (define-directory! state 'cwd)
  (define-state! state 'directory-state
                 '((gel-empty-stack push "history") push cwd) #:page 2)
  (driver-eval! state '(define quit (directory-state handle-key "q")))
  (driver-eval! state '(define back (directory-state handle-key "escape")))
  (driver-eval! state '(define up (directory-state handle-key "u")))
  (driver-eval! state '(define toggled (directory-state handle-key ".")))
  (for ([name '(back up toggled)])
    (check-equal? (driver-eval! state `(,name page)) 0))
  (check-true (driver-eval! state '(quit quit)))
  (check-equal? (driver-eval! state '(quit page)) 2)
  (check-equal? (driver-eval! state '(((back stack) tos) subject)) "history")
  (check-equal? (driver-eval! state '(((up stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/\">>")
  (check-true (driver-eval! state '(toggled show-hidden)))
  (check-eq? (driver-eval! state '(directory-state handle-key "N"))
             (driver-eval! state 'directory-state))
  (check-eq? (driver-eval! state '(directory-state handle-key "P"))
             (driver-eval! state 'directory-state))

  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (define rendered (driver-eval! state '(gel-text menu directory-state)))
  (for ([private '("gel-directory-values" "gel-directory-all-values"
                   "gel-up" "gel-tos-text")])
    (check-false (string-contains? rendered private)))
  (check-equal? (driver-eval! state '(gel-text tos (directory-state stack)))
                "TOS: #<Directory \"/cwd\">")
  (driver-eval! state '(define file-state (toggled handle-key "b")))
  (check-false (string-contains? (driver-eval! state '(gel-text menu file-state))
                                 "n  next"))
  (check-false (string-contains? (driver-eval! state '(gel-text menu file-state))
                                 "p  prev"))
  (check-equal?
   (driver-eval! state '(gel-text menu file-state))
   (string-append
    "1  location  0\r\n"
    "2  name  0\r\n"
    "3  text  0\r\n"
    "4  child  1\r\n"
    "5  parent  0\r\n"
    "6  inspect  0\r\n")))

(test-case "fresh GelMain pages and echoes a scripted Directory session"
  (define-values (term terminal-output calls)
    (make-scripted-term '("n" "p" "q")))
  (define state
    (make-directory-driver (ordinary-nodes 25) #:main? #t #:term term))
  (load-silently! state gel-directory-application-path)
  (define start (driver-eval! state 'gel-start-value))
  (driver-eval! state '(define final-stack (gel-main start gel-start-value)))
  (define transcript (get-output-string terminal-output))
  (check-equal? (unbox calls) 3)
  (check-equal? (length (regexp-match* #rx"a  name01\r\n" transcript)) 2)
  (check-equal? (length (regexp-match* #rx"a  name23\r\n" transcript)) 1)
  (check-regexp-match #rx"key n\r\nTOS: #<Directory" transcript)
  (check-regexp-match #rx"key p\r\nTOS: #<Directory" transcript)
  (check-true (string-suffix? transcript "key q\r\n"))
  (check-equal? (driver-eval! state '((final-stack items) len)) 1)
  (check-eq? (driver-eval! state '((final-stack tos) subject)) start))

(test-case "paging remains a Gel-only Directory application change"
  (define-values (process stdout stdin stderr)
    (subprocess #f #f #f
                (find-executable-path "git")
                "diff" "--name-only" "HEAD" "--" "aloe" "lib" "host"))
  (close-output-port stdin)
  (subprocess-wait process)
  (check-equal? (subprocess-status process) 0)
  (check-equal? (port->string stdout) "")
  (check-equal? (port->string stderr) "")

  (define directory-source (file->string gel-directory-path))
  (define menu-source (file->string gel-menu-path))
  (define loop-source (file->string gel-loop-path))
  (define main-source (file->string gel-main-path))
  (define implementation-source
    (string-append directory-source menu-source loop-source main-source))
  (check-false (string-contains? implementation-source "(take"))
  (check-false (string-contains? implementation-source "(drop"))
  (check-false (regexp-match? #rx"directory-values \\(directory \\(Directory H\\)\\) \\(page|directory-all-values \\(directory \\(Directory H\\)\\) \\(page"
                              directory-source))
  (check-equal? (length (regexp-match* #rx"\\(GelItemKey new" menu-source)) 22)
  (check-true (string-contains? menu-source "(self window"))
  (check-true (string-contains? loop-source "(gel-menus directory? top)"))
  (check-true (regexp-match? #rx"GelStep new stack #f \\(List empty\\) 0 #f #f 0"
                             main-source))
  (for ([forbidden '("GelPager" "GelOptions" "armed-window" "search"
                     "show-options" "define-protocol")])
    (check-false (string-contains? implementation-source forbidden))))
