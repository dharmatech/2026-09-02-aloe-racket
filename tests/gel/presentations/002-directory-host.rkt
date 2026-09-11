#lang racket/base

(require racket/file
         racket/format
         racket/list
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         "../../../aloe/driver.rkt"
         "../../../aloe/parse.rkt"
         (only-in "../../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-of
                  type->datum)
         "../../../host/racket/fs.rkt")

(define-runtime-path disk-library-path "../../../lib/disk.aloe")
(define-runtime-path directory-source-path "../../../gel/directory.aloe")
(define-runtime-path gel-loop-path "../../../gel/loop.aloe")
(define-runtime-path gel-menu-path "../../../gel/menu.aloe")
(define-runtime-path gel-point-path "../../../examples/point.aloe")
(define-runtime-path aloe-directory "../../../aloe")
(define-runtime-path host-directory "../../../host")
(define-runtime-path library-directory "../../../lib")

(define item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "o" "r" "s" "t" "v" "w" "x" "y" "z"))

(define mixed-nodes
  (hash "/" 'directory
        "/cwd" 'directory
        "/cwd/.config" 'directory
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
   "4 entries\r\n"
   "u  up\r\n"
   ".  show hidden\r\n"
   "n  next\r\n"
   "p  prev\r\n"))

(define all-menu
  (string-append
   "a  .config/\r\n"
   "b  .secret\r\n"
   "c  alpha\r\n"
   "d  bravo/\r\n"
   "e  charlie@\r\n"
   "f  pipe\r\n"
   "\r\n"
   "6 entries\r\n"
   "u  up\r\n"
   ".  hide hidden\r\n"
   "n  next\r\n"
   "p  prev\r\n"))

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

(define (overflow-nodes)
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

(define (load-silently! state path [output (open-output-string)])
  (check-equal? (driver-load-file! state path output) '())
  (check-equal? (get-output-string output) "")
  state)

(define (make-disk-driver nodes)
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (load-silently! state disk-library-path)
  state)

(define (make-directory-driver [nodes mixed-nodes])
  (define state (make-disk-driver nodes))
  (load-silently! state gel-loop-path)
  (load-silently! state directory-source-path)
  state)

(define (driver-type-datum state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (define-specimens! state)
  (driver-eval!
   state
   '(define live-directory
      (Directory new ((Disk new fs-host) at "/cwd"))))
  (driver-eval!
   state
   '(define live-file
      (File new ((Disk new fs-host) at "/cwd/alpha"))))
  (driver-eval!
   state
   '(define live-link
      (SymbolicLink new ((Disk new fs-host) at "/cwd/charlie"))))
  (driver-eval!
   state
   '(define live-other
      (Other new ((Disk new fs-host) at "/cwd/pipe") "fifo")))
  (driver-eval! state '(define live-list (List of 10 20 30))))

(define (selector-names state subject selector)
  (driver-eval!
   state
   (case selector
     [(messages)
      `(((Mirror of ,subject) messages) map
        (fn (message) (message name)))]
     [(signatures)
      `(((Mirror of ,subject) signatures) map
        (fn (signature) ((signature selector) name)))])))

(define (message-count state subject selector)
  (driver-eval!
   state
   `(((Mirror of ,subject) messages) fold
     0
     (fn (count message)
       (if ((message name) = ,selector)
           (count + 1)
           count)))))

(define (signature-count state subject selector arity)
  (driver-eval!
   state
   `(((Mirror of ,subject) signatures) fold
     0
     (fn (count signature)
       (if (((signature selector) name) = ,selector)
           (if (((signature params) len) = ,arity)
               (count + 1)
               count)
           count)))))

(define (accepting-signature-count state owner selector candidate)
  (driver-eval!
   state
   `(((Mirror of ,owner) signatures) fold
     0
     (fn (count signature)
       (if (((signature selector) name) = ,selector)
           (if (((signature params) len) = 1)
               (if (signature accepts? (Mirror of ,candidate))
                   (count + 1)
                   count)
               count)
           count)))))

(define (define-accepted-signature! state name owner selector candidate)
  (driver-eval!
   state
   `(define ,name
      (((((Mirror of ,owner) signatures) fold
          (List empty)
          (fn (matches signature)
            (if (((signature selector) name) = ,selector)
                (if (((signature params) len) = 1)
                    (if (signature accepts? (Mirror of ,candidate))
                        (matches cons signature)
                        matches)
                    matches)
                matches)))
        reverse)
       first))))

(define (menu-row-count state expression)
  (driver-eval!
   state
   `(,expression case
     (Messages (rows) -1)
     (Values (rows) (rows len)))))

(define (define-value-rows! state name expression)
  (driver-eval!
   state
   `(define ,name
      (,expression case
        (Messages (rows) (GelValueRows new (List empty)))
        (Values (rows) rows)))))

(define (row-labels state rows-name count)
  (for/list ([index (in-range 1 (add1 count))])
    (driver-eval! state `((,rows-name select ,index) label))))

(define (type-error-message thunk)
  (with-handlers ([exn:fail:aloe-type? exn-message])
    (thunk)
    #f))

(define abstract-h-methods
  '(define-methods GelPresentations
     (methods
       (directory-values (type H)
         (directory (Directory H))
         GelValueRows
         ((GelDirectoryListing new (directory entries)) values #f)))))

(define fshost-methods
  '(define-methods GelPresentations
     (methods
       (directory-values
         (directory (Directory FsHost))
         GelValueRows
         ((GelDirectoryListing new (directory entries)) values #f)))))

(test-case "disk and List selector snapshots do not grow when Gel loads"
  (define state (make-disk-driver mixed-nodes))
  (define-specimens! state)
  (define subjects
    '(live-directory live-file live-link live-other live-list))
  (define before
    (for/hash ([subject (in-list subjects)])
      (values subject
              (list (selector-names state subject 'messages)
                    (selector-names state subject 'signatures)))))

  (load-silently! state gel-loop-path)
  (load-silently! state directory-source-path)

  (for ([subject (in-list subjects)])
    (check-equal?
     (list (selector-names state subject 'messages)
           (selector-names state subject 'signatures))
     (hash-ref before subject))
    (for ([forbidden
           (in-list '("gel-tos-text" "gel-directory-values"
                      "gel-directory-all-values" "gel-up" "gel-values"))])
      (check-equal?
       (message-count state subject forbidden)
       0
       (format "~a gained ~a" subject forbidden)))))

(test-case "the optional index exposes typed host-holding selectors"
  (define state (make-disk-driver mixed-nodes))
  (define-specimens! state)
  (load-silently! state gel-loop-path)

  (check-equal? (signature-count state 'gel-presentations "list-values" 1) 1)
  (check-equal? (signature-count state 'gel-menus "directory-presentations" 0)
                0)
  (check-equal?
   (accepting-signature-count state 'gel-presentations "list-values" 'live-list)
   1)
  (check-equal?
   (accepting-signature-count
    state 'gel-presentations "list-values" 'live-directory)
   0)

  (load-silently! state directory-source-path)
  (check-equal? (signature-count state 'gel-menus "directory-presentations" 0)
                1)
  (for ([selector '("directory-values" "directory-all-values" "up")])
    (check-equal?
     (signature-count state 'gel-directory-presentations selector 1)
     1))
  (check-equal?
   (signature-count state 'gel-directory-presentations "tos-text" 1)
   4)
  (for ([selector '("directory-values" "up" "tos-text")])
    (check-equal?
     (accepting-signature-count
      state 'gel-directory-presentations selector 'live-directory)
     1)
    (for ([candidate '(live-list live-file 10)])
      (check-equal?
       (accepting-signature-count
        state 'gel-directory-presentations selector candidate)
       (if (and (equal? selector "tos-text")
                (eq? candidate 'live-file))
           1
           0))))
  (define-accepted-signature!
   state 'file-tos-signature 'gel-directory-presentations
   "tos-text" 'live-file)
  (check-true
   (driver-eval! state '(file-tos-signature accepts? (Mirror of live-file))))
  (check-false
   (driver-eval!
    state
    '(file-tos-signature accepts? (Mirror of live-directory)))))

(test-case "moved Directory bodies return full rows parent and TOS text"
  (define state (make-directory-driver (overflow-nodes)))
  (define-specimens! state)
  (driver-eval!
   state
   '(define root-directory
      (Directory new ((Disk new fs-host) at "/"))))
  (driver-eval!
   state
   '(define filtered-full
      (gel-directory-presentations directory-values live-directory)))
  (driver-eval!
   state
   '(define all-full
      (gel-directory-presentations directory-all-values live-directory)))
  (check-equal? (driver-eval! state '(filtered-full len)) 25)
  (check-equal? (driver-eval! state '(all-full len)) 48)
  (check-equal? (car (row-labels state 'filtered-full 25)) "ordinary01")
  (check-equal? (take-right (row-labels state 'filtered-full 25) 3)
                '("ordinary23" "ordinary24/" "ordinary25@"))
  (check-equal? (car (row-labels state 'all-full 48)) ".hidden01")

  (check-equal?
   (driver-eval!
    state
    '((gel-directory-presentations up root-directory) case
       (Unavailable () "unavailable")
       (NoParent () "none")
       (Parent (value) "parent")))
   "none")
  (check-equal?
   (driver-eval!
    state
    '((gel-directory-presentations up live-directory) case
       (Unavailable () "unavailable")
       (NoParent () "none")
       (Parent (value) (value raw))))
   "#<Directory #<Location #<FsHost> \"/\">>")

  (for ([name '(live-directory live-file live-link live-other)]
        [expected '("#<Directory \"/cwd\">"
                    "#<File \"/cwd/alpha\">"
                    "#<SymbolicLink \"/cwd/charlie\">"
                    "#<Other \"/cwd/pipe\">")])
    (check-equal?
     (driver-type-datum
      state
      `(gel-directory-presentations tos-text ,name))
     'String)
    (check-equal?
     (driver-eval! state `(gel-directory-presentations tos-text ,name))
     expected))

  (for ([datum '((live-directory gel-directory-values)
                  (live-directory gel-directory-all-values)
                  (live-directory gel-up)
                  (live-directory gel-tos-text)
                  (live-file gel-tos-text)
                  (live-link gel-tos-text)
                  (live-other gel-tos-text))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-type-datum state datum)))))

(test-case "Gel lookup browses Directory and falls back for every other value"
  (define state (make-directory-driver (overflow-nodes)))
  (define-specimens! state)
  (load-silently! state gel-point-path)
  (check-true
   (driver-eval! state '(gel-menus directory? (Mirror of live-directory))))
  (for ([candidate '(live-list live-file live-link live-other 10)])
    (check-false
     (driver-eval! state `(gel-menus directory? (Mirror of ,candidate)))))

  (check-equal?
   (menu-row-count
    state '(gel-menus of (Mirror of live-directory) #f 0))
   22)
  (check-equal?
   (menu-row-count
    state '(gel-menus of (Mirror of live-directory) #f 1))
   3)
  (check-equal?
   (menu-row-count state '(gel-menus of (Mirror of live-list) #f 7))
   3)
  (check-true
   (driver-eval! state '(gel-ups available? (Mirror of live-directory))))
  (for ([candidate '(live-list live-file live-link live-other 10)])
    (check-false
     (driver-eval! state `(gel-ups available? (Mirror of ,candidate)))))

  (for ([name '(live-directory live-file live-link live-other)]
        [expected '("TOS: #<Directory \"/cwd\">"
                    "TOS: #<File \"/cwd/alpha\">"
                    "TOS: #<SymbolicLink \"/cwd/charlie\">"
                    "TOS: #<Other \"/cwd/pipe\">")])
    (check-equal?
     (driver-eval! state `(gel-text tos (gel-empty-stack push ,name)))
     expected))
  (for ([expression '(live-list (Point new 1 2) 10)]
        [expected '("TOS: #<List 10 20 30>"
                    "TOS: #<Point 1 2>"
                    "TOS: 10")])
    (check-equal?
     (driver-eval! state `(gel-text tos (gel-empty-stack push ,expression)))
     expected))
  (define file-menu
    (driver-eval! state '(gel-text menu (Mirror of live-file))))
  (check-regexp-match #rx"(?m:^1  location  0\r?$)" file-menu)
  (for ([forbidden '("gel-tos-text" "n  next" "p  prev" "hidden")])
    (check-false (string-contains? file-menu forbidden))))

(test-case "generic Gel has no Directory index and preserves ordinary bytes"
  (define state (make-disk-driver mixed-nodes))
  (define-specimens! state)
  (load-silently! state gel-loop-path)
  (load-silently! state gel-point-path)
  (check-true (driver-eval! state '((gel-menus directory-indexes) empty?)))
  (check-false
   (driver-eval! state '(gel-menus directory? (Mirror of live-directory))))
  (check-equal?
   (driver-eval!
    state
    '(gel-text tos (gel-empty-stack push live-directory)))
   "TOS: #<Directory #<Location #<FsHost> \"/cwd\">>")
  (check-equal? (driver-eval! state '(gel-text menu (List of 10 20)))
                "a  10\r\nb  20\r\n")
  (check-equal? (driver-eval! state '(gel-text menu (Point new 1 2)))
                point-menu)
  (check-equal? (driver-eval! state '(gel-text menu 10)) int-menu))

(test-case "abstract H and source-written FsHost remain forbidden"
  (for ([datum (in-list (list abstract-h-methods fshost-methods))]
        [pattern (in-list (list #rx"unknown message: names"
                                #rx"unbound symbol: FsHost"))])
    (define state (make-directory-driver))
    (define message
      (type-error-message (lambda () (driver-eval! state datum))))
    (check-regexp-match pattern message)))

(test-case "frozen Directory menus and key transitions retain their bytes"
  (define state (make-directory-driver))
  (define-specimens! state)
  (check-equal?
   (driver-eval! state '(gel-text menu (Mirror of live-directory)))
   default-menu)
  (check-equal?
   (driver-eval! state '(gel-text menu (Mirror of live-directory) #t 0))
   all-menu)

  (driver-eval!
   state
   '(define state
      (GelStep new
        ((gel-empty-stack push "history") push live-directory)
        #f (List empty) 0 #f #f 0)))
  (driver-eval! state '(define child (state handle-key "b")))
  (check-equal? (driver-eval! state '(((child stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/cwd/bravo\">>")
  (check-equal? (driver-eval! state '(child page)) 0)
  (driver-eval! state '(define parent (child handle-key "u")))
  (check-equal? (driver-eval! state '(((parent stack) tos) raw))
                "#<Directory #<Location #<FsHost> \"/cwd\">>")
  (check-equal? (driver-eval! state '(parent page)) 0)
  (check-equal?
   (driver-eval! state '((((state handle-key "escape") stack) tos) subject))
   "history")
  (check-equal?
   (driver-eval! state '((((state handle-key "escape") stack) items) len))
   1)
  (check-true (driver-eval! state '((state handle-key "q") quit)))
  (driver-eval! state '(define shown (state handle-key ".")))
  (check-true (driver-eval! state '(shown show-hidden)))
  (check-equal? (driver-eval! state '(shown page)) 0)

  (define paging-state (make-directory-driver (overflow-nodes)))
  (define-specimens! paging-state)
  (driver-eval!
   paging-state
   '(define first-page
      (GelStep new
        (gel-empty-stack push live-directory)
        #f (List empty) 0 #f #f 0)))
  (driver-eval! paging-state '(define second-page (first-page handle-key "n")))
  (check-equal? (driver-eval! paging-state '(second-page page)) 1)
  (check-equal?
   (driver-eval! paging-state '(gel-text menu second-page))
   (string-append
    "a  ordinary23\r\n"
    "b  ordinary24/\r\n"
    "c  ordinary25@\r\n"
    "\r\n"
    "25 entries\r\n"
    "page 2 of 2\r\n"
    "u  up\r\n"
    ".  show hidden\r\n"
    "n  next\r\n"
    "p  prev\r\n"))
  (check-equal?
   (driver-eval! paging-state '((second-page handle-key "p") page))
   0))

(test-case "implementation stays inside the issued presentation slice"
  (define directory-source (file->string directory-source-path))
  (define menu-source (file->string gel-menu-path))
  (define loop-source (file->string gel-loop-path))
  (for ([class '(Directory File SymbolicLink Other)])
    (check-false
     (regexp-match? (regexp (format "\\(define-methods ~a" class))
                    directory-source)))
  (check-regexp-match
   #rx"\\(define-class \\(GelDirectoryPresentations H\\)"
   directory-source)
  (check-regexp-match
   #rx"GelDirectoryPresentations new fs-host"
   directory-source)
  (check-equal?
   (length (regexp-match* #rx"\\(define-methods GelMenus" directory-source))
   1)
  (check-false
   (regexp-match?
    #px"directory-values\\s+\\([^)]*Bool|directory-all-values\\s+\\([^)]*Bool"
    directory-source))
  (for ([source (in-list (list menu-source loop-source))])
    (for ([forbidden
           (in-list '("gel-directory-presentations"
                      "GelDirectoryPresentations"
                      "FsHost"))])
      (check-false (string-contains? source forbidden) forbidden))
    (for ([forbidden
           (in-list '("gel-directory-values"
                      "gel-directory-all-values"
                      "gel-up"
                      "gel-tos-text"))])
      (check-false
       (string-contains? source (format "\"~a\"" forbidden))
       forbidden)))
  (define-values (process stdout stdin stderr)
    (subprocess #f #f #f
                (find-executable-path "git")
                "diff" "--name-only" "HEAD" "--" "aloe" "lib" "host"))
  (close-output-port stdin)
  (subprocess-wait process)
  (check-equal? (subprocess-status process) 0)
  (check-equal? (port->string stdout) "")
  (check-equal? (port->string stderr) "")
  (for ([directory (in-list (list aloe-directory
                                  library-directory
                                  host-directory))])
    (for ([path (in-list (find-files file-exists? directory))])
      (when (file-exists? path)
        (check-false
         (regexp-match?
          #rx"GelDirectoryPresentations|gel-directory-presentations"
          (file->string path))
         (path->string path))))))
