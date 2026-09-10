#lang racket/base

(require racket/file
         racket/format
         racket/list
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

(define-runtime-path aloe-directory "../aloe")
(define-runtime-path bin-aloe-path "../bin/aloe")
(define-runtime-path disk-library-path "../lib/disk.aloe")
(define-runtime-path fs-library-path "../lib/fs.aloe")
(define-runtime-path gel-directory-path "../gel/directory.aloe")
(define-runtime-path gel-directory-application-path
  "../examples/gel-directory.aloe")
(define-runtime-path gel-directory-run-path
  "../host/racket/gel-directory-run.rkt")
(define-runtime-path gel-list-path "../examples/gel-list.aloe")
(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-menu-path "../gel/menu.aloe")
(define-runtime-path gel-point-path "../examples/gel-point.aloe")
(define-runtime-path gel-run-path "../host/racket/gel-run.rkt")
(define-runtime-path gel-stack-path "../gel/stack.aloe")
(define-runtime-path fs-host-path "../host/racket/fs.rkt")
(define-runtime-path term-host-path "../host/racket/term.rkt")

(define item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "n" "o" "p" "r" "s" "t" "v" "w" "x" "y" "z"))

(define mixed-nodes
  (hash
   "/" 'directory
   "/cwd" 'directory
   "/cwd/a.txt" 'file
   "/cwd/lib" 'directory
   "/cwd/lib/disk.aloe" 'file
   "/cwd/link" 'symlink
   "/cwd/pipe" "fifo"))

(define mixed-menu
  (string-append
   "a  a.txt\r\n"
   "b  lib/\r\n"
   "c  link@\r\n"
   "d  pipe\r\n"
   "\r\n"
   "u  up\r\n"
   ".  show hidden\r\n"))

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

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (load-silently! state path [output (open-output-string)])
  (check-equal? (driver-load-file! state path output) '())
  output)

(define (make-loop-driver)
  (define state (make-driver))
  (define output (load-silently! state gel-loop-path))
  (check-equal? (get-output-string output) "")
  state)

(define (make-directory-driver
         #:current [current "/cwd"]
         #:nodes [nodes mixed-nodes]
         #:main? [main? #f])
  (define state (make-driver))
  (define output (open-output-string))
  (driver-inject-host! state 'fs-host (make-fs-double current nodes))
  (load-silently! state (if main? gel-main-path gel-loop-path) output)
  (load-silently! state disk-library-path output)
  (load-silently! state gel-directory-path output)
  (check-equal? (get-output-string output) "")
  state)

(define (define-current-directory! state name)
  (driver-eval!
   state
   `(define ,name
      (Directory new ((Disk new fs-host) current)))))

(define (define-directory! state name path)
  (driver-eval!
   state
   `(define ,name
      (Directory new ((Disk new fs-host) at ,path)))))

(define (define-value-rows! state rows-name mirror-name)
  (define menu-name
    (string->symbol (format "~a-menu" rows-name)))
  (driver-eval!
   state
   `(define ,menu-name (gel-menus of ,mirror-name)))
  (driver-eval!
   state
   `(define ,rows-name
      (,menu-name case
        (Messages (rows) (GelValueRows new (List empty)))
        (Values (rows) rows)))))

(define (bind-signature! state name mirror-name selector)
  (driver-eval!
   state
   `(define ,name
      ((,mirror-name signatures) fold
        ((,mirror-name signatures) first)
        (fn (found signature)
          (if (((signature selector) name) = ,selector)
              (if (((signature params) len) = 0)
                  signature
                  found)
              found))))))

(define (list-item-datum list-expression zero-based-index)
  (define receiver
    (for/fold ([receiver list-expression])
              ([_ (in-range zero-based-index)])
      (list receiver 'rest)))
  (list receiver 'first))

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

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-gel-directory-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(test-case "labeled rows and nominal up service are generic Gel types"
  (define fresh (make-driver))
  (for ([name
         (in-list
          '(GelValueRow GelUp GelUps gel-ups Disk Directory
                        GelDirectoryBuild GelDirectoryRows
                        gel-directory-rows fs-host term))])
    (check-false (env-bound? (driver-runtime-environment fresh) name))
    (check-false
     (type-environment-bound? (driver-type-environment fresh) name)))

  (define state (make-loop-driver))
  (for ([datum+type
         (in-list
          '(((GelValueRow new 1 (Mirror of 10) "ten") GelValueRow)
            (((GelValueRow new 1 (Mirror of 10) "ten") label) String)
            ((GelUp Unavailable) GelUp)
            ((GelUp NoParent) GelUp)
            ((GelUp Parent (Mirror of 10)) GelUp)
            ((gel-ups available? (Mirror of 10)) Bool)
            ((gel-ups of (Mirror of 10)) GelUp)))])
    (check-equal?
     (driver-type-datum state (first datum+type))
     (second datum+type)))
  (check-false (driver-eval! state '(gel-ups available? (Mirror of 10))))
  (check-true
   (driver-eval!
    state
    '((gel-ups of (Mirror of 10)) case
       (Unavailable () #t)
       (NoParent () #f)
       (Parent (value) #f))))
  (for ([name
         '(Disk Directory GelDirectoryBuild GelDirectoryRows
                gel-directory-rows fs-host term)])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name))))

(test-case "generic Gel remains disk-free and preserves List and Point menus"
  (define state (make-loop-driver))
  (driver-eval! state '(define generic-list (List of "alpha" "beta")))
  (check-equal?
   (driver-eval! state '(gel-text menu generic-list))
   "a  \"alpha\"\r\nb  \"beta\"\r\n")
  (check-false
   (driver-eval! state '(gel-ups available? (Mirror of generic-list))))
  (check-false
   (driver-eval!
    state
    '(((Mirror of generic-list) signatures) fold
       #f
       (fn (found signature)
         (if (((signature selector) name) = "gel-directory-values")
             #t
             found)))))
  (for ([name '(Disk Directory GelDirectoryRows gel-directory-rows)])
    (check-false (env-bound? (driver-runtime-environment state) name)))

  (load-silently! state gel-point-path)
  (check-equal? (driver-eval! state '(gel-text menu gel-start-value))
                point-menu)
  (check-false
   (driver-eval! state '(gel-ups available? (Mirror of gel-start-value)))))

(test-case "Directory adapter adds the exact reflected zero-argument rows"
  (define state (make-directory-driver))
  (define-current-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (bind-signature!
   state 'directory-values-signature 'cwd-mirror "gel-directory-values")
  (bind-signature!
   state 'directory-all-values-signature 'cwd-mirror
   "gel-directory-all-values")
  (bind-signature! state 'up-signature 'cwd-mirror "gel-up")

  (check-equal? (driver-type-datum state '(cwd gel-directory-values))
                'GelValueRows)
  (check-equal? (driver-type-datum state '(cwd gel-up)) 'GelUp)
  (check-equal?
   (driver-eval! state '((directory-values-signature params) len))
   0)
  (check-equal?
   (driver-eval!
    state
    '((Mirror of (directory-values-signature return)) raw))
   "#<Symbol GelValueRows>")
  (check-equal?
   (driver-eval! state '((directory-all-values-signature params) len))
   0)
  (check-equal?
   (driver-eval!
    state
    '((Mirror of (directory-all-values-signature return)) raw))
   "#<Symbol GelValueRows>")
  (check-equal? (driver-eval! state '((up-signature params) len)) 0)
  (check-equal?
   (driver-eval! state '((Mirror of (up-signature return)) raw))
   "#<Symbol GelUp>")
  (check-true (driver-eval! state '(gel-ups available? cwd-mirror)))
  (for ([name '(GelDirectoryBuild GelDirectoryRows gel-directory-rows)])
    (check-true (env-bound? (driver-runtime-environment state) name))
    (check-true
     (type-environment-bound? (driver-type-environment state) name))))

(test-case "mixed Directory menu is ordered labeled and hides reflected rows"
  (define state (make-directory-driver))
  (define-current-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (define rendered (driver-eval! state '(gel-text menu cwd-mirror)))
  (check-equal? rendered mixed-menu)
  (for ([hidden
         '("entries" "parent" "gel-directory-values"
           "gel-directory-all-values" "gel-up"
           "File" "Directory" "SymbolicLink" "Other" "fifo")])
    (check-false
     (regexp-match? (regexp (regexp-quote hidden)) rendered)
     hidden))

  (define-value-rows! state 'cwd-rows 'cwd-mirror)
  (check-equal? (driver-eval! state '(cwd-rows len)) 4)
  (for ([index (in-range 1 5)]
        [key (in-list '("a" "b" "c" "d"))]
        [label (in-list '("a.txt" "lib/" "link@" "pipe"))]
        [raw-pattern
         (in-list
          '("^#<File " "^#<Directory " "^#<SymbolicLink " "^#<Other "))])
    (check-equal? (driver-eval! state `((cwd-rows select ,index) key)) key)
    (check-equal? (driver-eval! state `((cwd-rows select ,index) label)) label)
    (check-regexp-match
     (regexp raw-pattern)
     (driver-eval! state `(((cwd-rows select ,index) value) raw))))
  (check-equal?
   (length (regexp-match* #rx"\\(self entries\\)"
                          (file->string gel-directory-path)))
   2))

(test-case "Directory selection pushes each exact live row mirror"
  (define state (make-directory-driver))
  (define-current-directory! state 'cwd)
  (driver-eval! state '(define cwd-mirror (Mirror of cwd)))
  (define-value-rows! state 'cwd-rows 'cwd-mirror)
  (driver-eval!
   state
   '(define cwd-state
      (GelStep new
        (gel-empty-stack push cwd-mirror)
        #f
        (List empty)
        0
        #f
        #f)))

  (for ([index (in-range 1 5)]
        [key (in-list '("a" "b" "c" "d"))])
    (define chosen-name
      (string->symbol (format "directory-choice-~a" index)))
    (driver-eval!
     state
     `(define ,chosen-name
        (cwd-state handle-values cwd-rows (GelKey new ,key))))
    (check-eq? (driver-eval! state `((,chosen-name stack) tos))
               (driver-eval! state `((cwd-rows select ,index) value)))
    (check-eq?
     (driver-eval!
      state
      `((((,chosen-name stack) items) rest) first))
     (driver-eval! state 'cwd-mirror))
    (check-equal? (driver-eval! state `(((,chosen-name stack) items) len)) 2)
    (check-equal? (driver-eval! state `((,chosen-name pending) len)) 0)))

(test-case "nested Directory recurs while other live children stay derived"
  (define state (make-directory-driver))
  (define-current-directory! state 'cwd)
  (driver-eval!
   state
   '(define cwd-state
      (GelStep new
        (gel-empty-stack push cwd)
        #f
        (List empty)
        0
        #f
        #f)))
  (for ([key '("a" "b" "c" "d")]
        [name '(file-step directory-step link-step other-step)])
    (driver-eval! state `(define ,name (cwd-state handle-key ,key))))

  (check-equal? (driver-eval! state '(gel-text menu directory-step))
                (string-append
                 "a  disk.aloe\r\n\r\n"
                 "u  up\r\n"
                 ".  show hidden\r\n"))
  (for ([name '(file-step link-step other-step)])
    (define text (driver-eval! state `(gel-text menu ,name)))
    (check-not-equal? text "")
    (check-false (regexp-match? #rx"(?m:^u  up\r?$)" text))
    (check-false (regexp-match? #rx"gel-directory-values|gel-up" text))
    (check-false
     (driver-eval! state `(gel-ups available? ((,name stack) tos)))))
  (check-regexp-match #rx"(?m:^1  location  0\r?$)"
                      (driver-eval! state '(gel-text menu file-step))))

(test-case "empty and overflowing Directory menus keep the fixed boundary"
  (define many-nodes
    (for/fold ([nodes (hash "/" 'directory
                            "/cwd" 'directory
                            "/cwd/empty" 'directory
                            "/many" 'directory)])
              ([index (in-range 1 27)])
      (hash-set nodes
                (format "/many/file~a" (~r index #:min-width 2 #:pad-string "0"))
                'file)))
  (define state
    (make-directory-driver #:nodes many-nodes #:current "/cwd"))
  (define-directory! state 'empty-directory "/cwd/empty")
  (define-directory! state 'many-directory "/many")
  (check-equal? (driver-eval! state '(gel-text menu empty-directory))
                "u  up\r\n.  show hidden\r\n")
  (driver-eval! state '(define many-mirror (Mirror of many-directory)))
  (define-value-rows! state 'many-rows 'many-mirror)
  (define rendered (driver-eval! state '(gel-text menu many-mirror)))
  (check-equal? (driver-eval! state '(many-rows len)) 24)
  (for ([index (in-range 1 25)]
        [key (in-list item-keys)])
    (check-equal? (driver-eval! state `((many-rows select ,index) key)) key)
    (check-equal?
     (driver-eval! state `((many-rows select ,index) label))
     (format "file~a" (~r index #:min-width 2 #:pad-string "0"))))
  (check-false (regexp-match? #rx"file25|file26|overflow|paging|search"
                              rendered))
  (check-false (regexp-match? #rx"(?m:^[qu]  file)" rendered))
  (check-equal? (length (regexp-match* #rx"u  up\r\n" rendered)) 1))

(test-case "GelKey recognizes only exact lowercase u without making it an item"
  (define state (make-loop-driver))
  (check-equal? (driver-type-datum state '((GelKey new "u") up?)) 'Bool)
  (check-true (driver-eval! state '((GelKey new "u") up?)))
  (check-equal? (driver-eval! state '((GelKey new "u") item-index)) 0)
  (for ([text '("" "U" "q" "escape" "return" "0" "1" "a" "up")])
    (check-false (driver-eval! state `((GelKey new ,text) up?)) text))
  (check-true (driver-eval! state '((GelKey new "q") quit?)))
  (check-true (driver-eval! state '((GelKey new "escape") escape?)))
  (check-equal? (driver-eval! state '((GelKey new "1") menu-index)) 1)
  (check-equal? (driver-eval! state '((GelKey new "a") item-index)) 1))

(test-case "u pushes a live parent while Escape restores the child"
  (define state (make-directory-driver))
  (define-current-directory! state 'cwd)
  (driver-eval!
   state
   '(define cwd-state
      (GelStep new
        (gel-empty-stack push cwd)
        #f
        (List empty)
        0
        #f
        #f)))
  (driver-eval! state '(define lib-step (cwd-state handle-key "b")))
  (define child-mirror (driver-eval! state '((lib-step stack) tos)))
  (driver-eval!
   state
   '(define captured-up (gel-ups of ((lib-step stack) tos))))
  (driver-eval!
   state
   '(define captured-parent
      (captured-up case
        (Unavailable () (Mirror of 0))
        (NoParent () (Mirror of 0))
        (Parent (value) value))))
  (driver-eval!
   state
   '(define direct-parent-step (lib-step handle-up captured-up)))
  (check-eq? (driver-eval! state '((direct-parent-step stack) tos))
             (driver-eval! state 'captured-parent))

  (driver-eval! state '(define parent-step (lib-step handle-key "u")))
  (check-equal? (driver-eval! state '(((parent-step stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/cwd\">>")
  (check-eq?
   (driver-eval! state '((((parent-step stack) items) rest) first))
   child-mirror)
  (check-equal? (driver-eval! state '(((parent-step stack) items) len)) 3)
  (check-eq?
   (driver-eval! state '(((parent-step handle-key "escape") stack) tos))
   child-mirror)
  (driver-eval! state '(define root-step (parent-step handle-key "u")))
  (check-equal? (driver-eval! state '(((root-step stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/\">>")
  (check-equal? (driver-eval! state '(fs-host current)) "/cwd"))

(test-case "u is total away from nested Directory and remains pending"
  (define state (make-directory-driver))
  (define-directory! state 'root-directory "/")
  (driver-eval!
   state
   '(define root-state
      (GelStep new
        (gel-empty-stack push root-directory)
        #f
        (List empty)
        0
        #f
        #f)))
  (check-eq? (driver-eval! state '(root-state handle-key "u"))
             (driver-eval! state 'root-state))

  (load-silently! state gel-point-path)
  (for ([expression '(10 (List of 10 20) (Point new 1 2))]
        [name '(int-state list-state point-state)])
    (driver-eval!
     state
     `(define ,name
        (GelStep new
          (gel-empty-stack push ,expression)
          #f
          (List empty)
          0
          #f
          #f)))
    (check-eq? (driver-eval! state `(,name handle-key "u"))
               (driver-eval! state name)))

  (define-current-directory! state 'cwd)
  (driver-eval!
   state
   '(define file-state
      ((GelStep new
         (gel-empty-stack push cwd)
         #f
         (List empty)
         0
         #f
         #f)
       handle-key
       "a")))
  (check-eq? (driver-eval! state '(file-state handle-key "u"))
             (driver-eval! state 'file-state))

  (driver-eval! state '(define int-rows (gel-rows of 10)))
  (driver-eval! state '(define int-plus (int-rows first)))
  (driver-eval!
   state
   '(define int-pending
      (GelStep new
        (gel-empty-stack push 10)
        #f
        (List of int-plus)
        0
        #f
        #f)))
  (check-eq? (driver-eval! state '(int-pending handle-key "u"))
             (driver-eval! state 'int-pending))

  (driver-eval! state '(define point-rows (gel-rows of (Point new 1 2))))
  (driver-eval! state '(define point-plus (((point-rows rest) rest) first)))
  (driver-eval!
   state
   '(define point-pending
      (GelStep new
        (gel-empty-stack push (Point new 1 2))
        #f
        (List of point-plus)
        0
        #f
        #f)))
  (check-eq? (driver-eval! state '(point-pending handle-key "u"))
             (driver-eval! state 'point-pending)))

(test-case "Directory keeps q Escape and letter selection precedence"
  (define state (make-directory-driver))
  (define-current-directory! state 'cwd)
  (driver-eval!
   state
   '(define history-state
      (GelStep new
        ((gel-empty-stack push "history") push cwd)
        #f
        (List empty)
        0
        #f
        #f)))
  (driver-eval! state '(define quit-step (history-state handle-key "q")))
  (driver-eval! state '(define back-step (history-state handle-key "escape")))
  (check-true (driver-eval! state '(quit-step quit)))
  (check-eq? (driver-eval! state '(quit-step stack))
             (driver-eval! state '(history-state stack)))
  (check-equal? (driver-eval! state '(((back-step stack) tos) subject))
                "history")
  (for ([key '("1" "2" "U" "return")])
    (check-eq? (driver-eval! state `(history-state handle-key ,key))
               (driver-eval! state 'history-state)))
  (check-regexp-match
   #rx"^#<File "
   (driver-eval! state '((((history-state handle-key "a") stack) tos) raw))))

(test-case "directory application is minimal typed and starts at injected current"
  (define source (file->string gel-directory-application-path))
  (check-equal?
   source
   (string-append
    "(load \"../lib/disk.aloe\")\n"
    "(load \"../gel/directory.aloe\")\n\n"
    "(define gel-start-value\n"
    "  (Directory new\n"
    "    ((Disk new fs-host) current)))\n"))
  (check-false
   (regexp-match?
    #rx"term|GelStack|gel-empty-stack|gel-main|lib/fs|inspect|chdir|/cwd"
    source))

  (define state (make-driver))
  (define output (open-output-string))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" mixed-nodes))
  (load-silently! state gel-loop-path output)
  (load-silently! state gel-directory-application-path output)
  (check-equal? (driver-type-datum state 'gel-start-value)
                '(Directory FsHost))
  (check-equal? (driver-eval! state '(gel-start-value text)) "/cwd")
  (check-equal? (get-output-string output) ""))

(test-case "production filesystem and scripted Term drive back and up differently"
  (call-with-temporary-directory
   (lambda (directory)
     (define file-path (build-path directory "a.txt"))
     (define lib-path (build-path directory "lib"))
     (define disk-path (build-path lib-path "disk.aloe"))
     (define link-path (build-path directory "link"))
     (display-to-file "top file" file-path #:exists 'truncate)
     (make-directory lib-path)
     (display-to-file "disk file" disk-path #:exists 'truncate)
     (make-file-or-directory-link "lib" link-path)

     (define-values (term terminal-output reader-calls)
       (make-scripted-term '("b" "a" "escape" "u" "q")))
     (define state (make-driver))
     (define load-output (open-output-string))
     (driver-inject-host! state 'term term)
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (load-silently! state gel-main-path load-output)
     (parameterize ([current-directory directory])
       (load-silently! state gel-directory-application-path load-output)
       (driver-eval!
        state
        '(define production-final
           (gel-main start gel-start-value))))

     (define transcript (get-output-string terminal-output))
     (check-equal? (unbox reader-calls) 5)
     (check-equal? (get-output-string load-output) "")
     (check-equal? (length (regexp-match* #rx"a  a.txt\r\n" transcript)) 2)
     (check-equal? (length (regexp-match* #rx"b  lib/\r\n" transcript)) 2)
     (check-equal? (length (regexp-match* #rx"c  link@\r\n" transcript)) 2)
     (check-regexp-match
      #rx"a  disk.aloe\r\n\r\nu  up\r\n[.]  show hidden\r\n\r\nkey a\r\n"
      transcript)
     (check-regexp-match #rx"key a\r\nTOS: #<File " transcript)
     (check-regexp-match
      #rx"key escape\r\nTOS: #<Directory .*lib"
      transcript)
     (check-regexp-match
      #rx"key u\r\nTOS: #<Directory "
      transcript)
     (check-true (string-suffix? transcript "key q\r\n"))

     (check-equal? (driver-eval! state '((production-final items) len)) 3)
     (check-equal?
      (driver-eval! state '((production-final tos) raw))
      (format "#<Directory #<Location #<FsHost> ~s>>"
              (path->string directory)))
     (check-equal?
      (driver-eval!
       state
       '((((production-final items) rest) first) raw))
      (format "#<Directory #<Location #<FsHost> ~s>>"
              (path->string lib-path)))
     (check-equal?
      (driver-eval!
       state
       '(((((production-final items) rest) rest) first) raw))
      (format "#<Directory #<Location #<FsHost> ~s>>"
              (path->string directory))))))

(define (check-runner-usage arguments)
  (define racket-path (find-executable-path "racket"))
  (check-not-false racket-path)
  (define-values (process stdout stdin stderr)
    (apply subprocess #f #f #f racket-path gel-directory-run-path arguments))
  (close-output-port stdin)
  (subprocess-wait process)
  (check-equal? (subprocess-status process) 2)
  (check-equal? (port->string stdout) "")
  (check-equal?
   (port->string stderr)
   "usage: racket host/racket/gel-directory-run.rkt path.aloe\n"))

(test-case "filesystem-capable runner has the exact authority and lifecycle"
  (check-runner-usage '())
  (check-runner-usage '("one.aloe" "two.aloe"))
  (define source (file->string gel-directory-run-path))
  (check-equal?
   (length (regexp-match* #rx"\\(driver-inject-host! state" source))
   2)
  (check-regexp-match #rx"driver-inject-host! state 'term term" source)
  (check-regexp-match
   #rx"driver-inject-host! state 'fs-host \\(make-fs-receiver\\)"
   source)
  (check-regexp-match
   #px"driver-load-file! state gel-main-path\\)\\s*\\(driver-load-file! state path\\)\\s*\\(driver-eval!\\s*state\\s*'\\(gel-main start gel-start-value\\)\\)"
   source)
  (check-true (string-contains? source "\"gel-directory: ~a\\r\\n\""))
  (for ([forbidden
         '("Disk" "Location" "Directory" "Item" "gel-directory-values"
           "GelValueRow" "parent" "chdir" "current-directory")])
    (check-false
     (regexp-match? (regexp (regexp-quote forbidden)) source)
     forbidden)))

(test-case "ordinary runners libraries kernel and applications remain isolated"
  (define ordinary-runner-source (file->string gel-run-path))
  (check-equal?
   (length
    (regexp-match* #rx"\\(driver-inject-host! state" ordinary-runner-source))
   1)
  (check-regexp-match #rx"driver-inject-host! state 'term term"
                      ordinary-runner-source)
  (check-false (regexp-match? #rx"fs-host|make-fs-receiver"
                              ordinary-runner-source))
  (check-false (regexp-match? #rx"fs-host" (file->string bin-aloe-path)))
  (check-false (regexp-match? #rx"Gel|gel-" (file->string disk-library-path)))
  (check-false (regexp-match? #rx"Gel|gel-" (file->string fs-library-path)))
  (for ([path (in-list (list fs-host-path term-host-path))])
    (check-false (regexp-match? #rx"GelValueRow|gel-directory-values|gel-up"
                                (file->string path))))
  (for ([path (in-list (list gel-stack-path gel-main-path))])
    (check-false
     (regexp-match? #rx"fs-host|Directory|gel-directory|gel-up|u  up"
                    (file->string path))))
  (check-equal?
   (file->string gel-list-path)
   (string-append
    "(define gel-start-value\n"
    "  (List of \"alpha\" \"beta\" \"gamma\"))\n"))
  (check-equal?
   (file->string gel-point-path)
   (string-append
    "(load \"point.aloe\")\n\n"
    "(define gel-start-value\n"
    "  (Point new 10 20))\n"))
  (for ([directory (in-list (list aloe-directory))])
    (for ([path (in-list (find-files file-exists? directory))])
      (when (file-exists? path)
        (check-false
         (regexp-match? #rx"GelDirectoryRows|gel-directory-values|gel-up"
                        (file->string path))
         (path->string path)))))
  (define fresh (make-driver))
  (for ([name '(term fs-host Disk Directory GelDirectoryRows gel-start-value)])
    (check-false (env-bound? (driver-runtime-environment fresh) name))
    (check-false
     (type-environment-bound? (driver-type-environment fresh) name))))
