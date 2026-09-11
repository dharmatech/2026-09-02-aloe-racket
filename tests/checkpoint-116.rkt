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

(define mixed-hidden-nodes
  (hash
   "/" 'directory
   "/cwd" 'directory
   "/cwd/.config" 'directory
   "/cwd/.link" 'symlink
   "/cwd/.secret" 'file
   "/cwd/alpha" 'file
   "/cwd/bravo" 'directory
   "/cwd/bravo/child" 'file
   "/cwd/charlie" 'symlink
   "/cwd/pipe" "fifo"))

(define default-menu
  (string-append
   "a  alpha\r\n"
   "b  bravo/\r\n"
   "c  charlie@\r\n"
   "d  pipe\r\n"
   "\r\n"
   "u  up\r\n"
   ".  show hidden\r\n"
   "n  next\r\n"
   "p  prev\r\n"))

(define all-menu
  (string-append
   "a  .config/\r\n"
   "b  .link@\r\n"
   "c  .secret\r\n"
   "d  alpha\r\n"
   "e  bravo/\r\n"
   "f  charlie@\r\n"
   "g  pipe\r\n"
   "\r\n"
   "u  up\r\n"
   ".  hide hidden\r\n"
   "n  next\r\n"
   "p  prev\r\n"))

(define (driver-type-datum state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (load-silently! state path [output (open-output-string)])
  (check-equal? (driver-load-file! state path output) '())
  output)

(define (make-directory-driver
         #:nodes [nodes mixed-hidden-nodes]
         #:main? [main? #f]
         #:term [term #f])
  (define state (make-driver))
  (define output (open-output-string))
  (when term
    (driver-inject-host! state 'term term))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (load-silently! state (if main? gel-main-path gel-loop-path) output)
  (load-silently! state disk-library-path output)
  (load-silently! state gel-directory-path output)
  (check-equal? (get-output-string output) "")
  state)

(define (define-directory! state name [path "/cwd"])
  (driver-eval!
   state
   `(define ,name (Directory new ((Disk new fs-host) at ,path)))))

(define (define-state! state name stack-expression [show-hidden #f])
  (driver-eval!
   state
   `(define ,name
      (GelStep new
        ,stack-expression
        #f
        (List empty)
        0
        #f
        ,show-hidden
        0))))

(define (define-value-rows! state rows-name mirror-name show-hidden)
  (define menu-name
    (string->symbol (format "~a-menu" rows-name)))
  (driver-eval!
   state
   `(define ,menu-name (gel-menus of ,mirror-name ,show-hidden)))
  (driver-eval!
   state
   `(define ,rows-name
      (,menu-name case
        (Messages (rows) (GelValueRows new (List empty)))
        (Values (rows) rows)))))

(define (row-labels state rows-name count)
  (for/list ([index (in-range 1 (add1 count))])
    (driver-eval! state `((,rows-name select ,index) label))))

(define (bind-row! state name rows-name selector arity)
  (driver-eval!
   state
   `(define ,name
      (,rows-name fold
        (,rows-name first)
        (fn (found row)
          (if (((row selector) name) = ,selector)
              (if ((row arity) = ,arity) row found)
              found))))))

(define (bind-signature! state name mirror-name selector)
  (driver-eval!
   state
   `(define ,name
      ((,mirror-name signatures) fold
        ((,mirror-name signatures) first)
        (fn (found signature)
          (if (((signature selector) name) = ,selector)
              (if (((signature params) len) = 0) signature found)
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
        (error 'checkpoint-116 "key script exhausted"))
      (set-box! remaining (cdr keys-left))
      (set-box! calls (add1 (unbox calls)))
      (car keys-left)))
   output
   calls))

(test-case "Directory rows filter raw leading-dot names before compact keys"
  (define state (make-directory-driver))
  (define-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (define-value-rows! state 'filtered-rows 'cwd-mirror #f)
  (define-value-rows! state 'all-rows 'cwd-mirror #t)

  (check-equal? (driver-eval! state '(filtered-rows len)) 4)
  (check-equal? (row-labels state 'filtered-rows 4)
                '("alpha" "bravo/" "charlie@" "pipe"))
  (check-equal? (row-labels state 'all-rows 7)
                '(".config/" ".link@" ".secret" "alpha"
                  "bravo/" "charlie@" "pipe"))
  (for ([index (in-range 1 5)]
        [key (in-list item-keys)])
    (check-equal? (driver-eval! state `((filtered-rows select ,index) key))
                  key)))

(test-case "more than 22 hidden names are removed before the window"
  (define nodes
    (for/fold ([nodes (hash "/" 'directory
                                  "/cwd" 'directory
                                  "/cwd/alpha" 'file
                                  "/cwd/bravo" 'directory
                                  "/cwd/charlie" 'symlink)])
              ([index (in-range 1 26)])
      (hash-set nodes
                (format "/cwd/.hidden~a"
                        (~r index #:min-width 2 #:pad-string "0"))
                'file)))
  (define state (make-directory-driver #:nodes nodes))
  (define-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (define-value-rows! state 'filtered-rows 'cwd-mirror #f)
  (define-value-rows! state 'all-rows 'cwd-mirror #t)

  (check-equal? (driver-eval! state '(filtered-rows len)) 3)
  (check-equal? (row-labels state 'filtered-rows 3)
                '("alpha" "bravo/" "charlie@"))
  (check-equal? (driver-eval! state '(all-rows len)) 22)
  (check-equal? (car (row-labels state 'all-rows 22)) ".hidden01")
  (check-equal? (last (row-labels state 'all-rows 22)) ".hidden22")
  (for ([index (in-range 1 23)]
        [key (in-list item-keys)])
    (check-equal? (driver-eval! state `((all-rows select ,index) key)) key))
  (check-false
   (string-contains?
    (driver-eval! state '(gel-text menu cwd-mirror #t))
    "alpha")))

(test-case "Directory dot toggles exact command and blank-line bytes"
  (define state (make-directory-driver))
  (define-directory! state 'cwd)
  (define-state! state 'hidden-state '(gel-empty-stack push cwd))
  (driver-eval! state '(define shown-state (hidden-state handle-key ".")))
  (driver-eval! state '(define hidden-again (shown-state handle-key ".")))

  (check-equal? (driver-eval! state '(gel-text menu hidden-state)) default-menu)
  (check-equal? (driver-eval! state '(gel-text menu shown-state)) all-menu)
  (check-equal? (driver-eval! state '(gel-text menu hidden-again)) default-menu)
  (check-false (driver-eval! state '(hidden-state show-hidden)))
  (check-true (driver-eval! state '(shown-state show-hidden)))
  (check-false (driver-eval! state '(hidden-again show-hidden)))
  (check-eq? (driver-eval! state '(hidden-state stack))
             (driver-eval! state '(shown-state stack)))
  (check-eq? (driver-eval! state '((hidden-state stack) tos))
             (driver-eval! state '((shown-state stack) tos)))

  (define only-hidden
    (hash "/" 'directory
          "/cwd" 'directory
          "/cwd/.one" 'file
          "/cwd/.two" 'file))
  (define empty-state (make-directory-driver #:nodes only-hidden))
  (define-directory! empty-state 'cwd)
  (define-state! empty-state 'hidden-state '(gel-empty-stack push cwd))
  (driver-eval! empty-state
                '(define shown-state (hidden-state handle-key ".")))
  (check-equal? (driver-eval! empty-state '(gel-text menu hidden-state))
                (string-append
                 "u  up\r\n.  show hidden\r\n"
                 "n  next\r\np  prev\r\n"))
  (check-equal?
   (driver-eval! empty-state '(gel-text menu shown-state))
   (string-append
    "a  .one\r\nb  .two\r\n\r\n"
    "u  up\r\n.  hide hidden\r\n"
    "n  next\r\np  prev\r\n")))

(test-case "visibility persists through Directory navigation and sends"
  (define state (make-directory-driver))
  (define-directory! state 'cwd)
  (define-state! state 'initial '(gel-empty-stack push cwd))
  (driver-eval! state '(define shown (initial handle-key ".")))
  (driver-eval! state '(define child (shown handle-key "d")))
  (driver-eval! state '(define sent (child handle-key "2")))
  (driver-eval! state '(define back-file (sent handle-key "escape")))
  (driver-eval! state '(define back-directory (back-file handle-key "escape")))
  (driver-eval! state '(define parent (back-directory handle-key "u")))
  (driver-eval! state '(define no-op (parent handle-key "return")))
  (driver-eval! state '(define quit (no-op handle-key "q")))

  (for ([name '(shown child sent back-file back-directory parent no-op quit)])
    (check-true (driver-eval! state `(,name show-hidden))
                (symbol->string name)))
  (check-equal? (driver-eval! state '(((sent stack) tos) subject)) "alpha")
  (check-equal? (driver-eval! state '(((child stack) tos) subject))
                (driver-eval! state '(((back-file stack) tos) subject)))
  (check-eq? (driver-eval! state '((back-directory stack) tos))
             (driver-eval! state '((shown stack) tos)))
  (check-equal? (driver-eval! state '(((back-directory stack) items) len))
                (driver-eval! state '(((shown stack) items) len)))
  (check-true (driver-eval! state '(quit quit)))
  (check-eq? (driver-eval! state '(quit stack))
             (driver-eval! state '(no-op stack))))

(test-case "pending dot and non-Directory dot are exact no-ops"
  (define state (make-directory-driver))
  (load-silently! state gel-point-path)
  (driver-eval! state '(define int-rows (gel-rows of 10)))
  (bind-row! state 'int-plus 'int-rows "+" 1)
  (driver-eval!
   state
   '(define int-pending
      (GelStep new
        (gel-empty-stack push 10)
        #f
        (List of int-plus)
        0
        #f
        #t
        0)))
  (driver-eval! state '(define int-typed (int-pending handle-key "2")))
  (check-eq? (driver-eval! state '(int-pending handle-key "."))
             (driver-eval! state 'int-pending))
  (check-eq? (driver-eval! state '(int-typed handle-key "."))
             (driver-eval! state 'int-typed))

  (driver-eval! state '(define point-rows (gel-rows of (Point new 10 20))))
  (bind-row! state 'point-plus 'point-rows "+" 1)
  (driver-eval!
   state
   '(define point-pending
      (GelStep new
        ((gel-empty-stack push (Point new 1 2)) push (Point new 10 20))
        #f
        (List of point-plus)
        0
        #f
        #t
        0)))
  (check-eq? (driver-eval! state '(point-pending handle-key "."))
             (driver-eval! state 'point-pending))
  (driver-eval! state '(define invoked (point-pending handle-key "2")))
  (check-true (driver-eval! state '(invoked show-hidden)))
  (check-equal? (driver-eval! state '(((invoked stack) tos) raw))
                "#<Point 11 22>")
  (driver-eval! state '(define cancelled (point-pending handle-key "escape")))
  (check-true (driver-eval! state '(cancelled show-hidden)))
  (check-equal? (driver-eval! state '((cancelled pending) len)) 0)

  (define-state! state 'point-idle
                 '(gel-empty-stack push (Point new 10 20))
                 #t)
  (check-eq? (driver-eval! state '(point-idle handle-key "."))
             (driver-eval! state 'point-idle))
  (check-false
   (string-contains? (driver-eval! state '(gel-text menu point-idle))
                     "hidden"))
  (check-false
   (string-contains? (driver-eval! state '(gel-text menu point-pending))
                     "hidden")))

(test-case "Directory command precedence and private exact signatures remain"
  (define state (make-directory-driver))
  (define-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (define-state! state 'state
                 '((gel-empty-stack push "history") push cwd)
                 #t)
  (check-equal? (driver-type-datum state '(state show-hidden)) 'Bool)
  (check-equal? (driver-type-datum state '((GelKey new ".") hidden?)) 'Bool)
  (check-equal? (driver-type-datum state '(gel-menus of cwd-mirror #t))
                'GelMenu)
  (driver-eval! state '(define quit (state handle-key "q")))
  (driver-eval! state '(define back (state handle-key "escape")))
  (driver-eval! state '(define up (state handle-key "u")))
  (driver-eval! state '(define item (state handle-key "a")))

  (check-true (driver-eval! state '(quit quit)))
  (check-eq? (driver-eval! state '(quit stack))
             (driver-eval! state '(state stack)))
  (check-equal? (driver-eval! state '(((back stack) tos) subject)) "history")
  (check-equal? (driver-eval! state '(((up stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/\">>")
  (check-equal? (driver-eval! state '(((item stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/cwd/.config\">>")
  (check-equal? (driver-eval! state '((GelKey new ".") item-index)) 0)
  (check-true (driver-eval! state '((GelKey new ".") hidden?)))

  (bind-signature! state 'filtered-signature 'cwd-mirror
                   "gel-directory-values")
  (bind-signature! state 'all-signature 'cwd-mirror
                   "gel-directory-all-values")
  (for ([name '(filtered-signature all-signature)])
    (check-equal? (driver-eval! state `((,name params) len)) 0)
    (check-equal?
     (driver-eval! state `((Mirror of (,name return)) raw))
     "#<Symbol GelValueRows>"))
  (driver-eval!
   state
   '(define direct-filtered
      ((GelMenu Values (cwd-mirror inv|o|ke filtered-signature)) case
        (Messages (rows) (GelValueRows new (List empty)))
        (Values (rows) rows))))
  (driver-eval!
   state
   '(define direct-all
      ((GelMenu Values (cwd-mirror inv|o|ke all-signature)) case
        (Messages (rows) (GelValueRows new (List empty)))
        (Values (rows) rows))))
  (check-equal? (row-labels state 'direct-filtered 4)
                '("alpha" "bravo/" "charlie@" "pipe"))
  (check-equal? (row-labels state 'direct-all 7)
                '(".config/" ".link@" ".secret" "alpha"
                  "bravo/" "charlie@" "pipe"))
  (define rendered (driver-eval! state '(gel-text menu state)))
  (for ([private '("gel-directory-values" "gel-directory-all-values"
                   "gel-up" "gel-tos-text")])
    (check-false (string-contains? rendered private) private))
  (check-equal? (driver-eval! state '(gel-text tos (state stack)))
                "TOS: #<Directory \"/cwd\">")
  (driver-eval!
   state
   '(define file-state
      (GelStep new (gel-empty-stack push (((state handle-key "d") stack) tos))
        #f (List empty) 0 #f #t 0)))
  (check-false
   (string-contains? (driver-eval! state '(gel-text menu file-state))
                     "hidden"))
  (check-equal?
   (driver-eval! state '(gel-text menu file-state))
   (string-append
    "1  location  0\r\n"
    "2  name  0\r\n"
    "3  text  0\r\n"
    "4  child  1\r\n"
    "5  parent  0\r\n"
    "6  inspect  0\r\n")))

(test-case "fresh GelMain hides and a scripted dot redraws the same Directory"
  (define-values (term terminal-output calls)
    (make-scripted-term '("." "q")))
  (define state (make-driver))
  (define load-output (open-output-string))
  (driver-inject-host! state 'term term)
  (driver-inject-host! state 'fs-host
                       (make-fs-double "/cwd" mixed-hidden-nodes))
  (load-silently! state gel-main-path load-output)
  (load-silently! state gel-directory-application-path load-output)
  (define start (driver-eval! state 'gel-start-value))
  (driver-eval!
   state
   '(define final-stack (gel-main start gel-start-value)))
  (define transcript (get-output-string terminal-output))

  (check-equal? (unbox calls) 2)
  (check-equal? (get-output-string load-output) "")
  (check-equal? (length (regexp-match* #rx"TOS: #<Directory \"/cwd\">"
                                        transcript))
                2)
  (check-equal? (length (regexp-match* #rx"a  alpha\r\n" transcript)) 1)
  (check-equal? (length (regexp-match* #rx"a  [.]config/\r\n" transcript)) 1)
  (check-regexp-match
   #rx"[.]  show hidden\r\nn  next\r\np  prev\r\n\r\nkey [.]\r\nTOS: #<Directory"
   transcript)
  (check-true (string-contains? transcript ".  hide hidden\r\n"))
  (check-true (string-suffix? transcript "key q\r\n"))
  (check-equal? (driver-eval! state '((final-stack items) len)) 1)
  (check-eq? (driver-eval! state '((final-stack tos) subject)) start))

(test-case "checkpoint stays inside Gel and adds no paging machinery"
  (define-values (process stdout stdin stderr)
    (subprocess #f #f #f
                (find-executable-path "git")
                "diff" "--name-only" "HEAD" "--" "aloe" "lib" "host"))
  (close-output-port stdin)
  (subprocess-wait process)
  (check-equal? (subprocess-status process) 0)
  (check-equal? (port->string stdout) "")
  (check-equal? (port->string stderr) "")

  (define implementation-source
    (string-append (file->string gel-directory-path)
                   (file->string gel-menu-path)
                   (file->string gel-loop-path)))
  (check-true (string-contains? implementation-source "starts-with?"))
  (for ([forbidden '("paging" "page-index" "search" "GelOptions"
                     "show-options")])
    (check-false (string-contains? implementation-source forbidden)
                 forbidden))
  (for ([directory (in-list (list aloe-directory lib-directory
                                  host-directory))])
    (for ([path (in-list (find-files file-exists? directory))])
      (when (file-exists? path)
        (check-false
         (regexp-match? #rx"GelDirectoryListing|gel-directory-all-values"
                        (file->string path))
         (path->string path))))))
