#lang racket/base

(require racket/file
         racket/format
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../../aloe/driver.rkt"
         "../../../aloe/host.rkt"
         "../../../host/racket/fs.rkt")

(define-runtime-path disk-library-path "../../../lib/disk.aloe")
(define-runtime-path gel-directory-path "../../../gel/directory.aloe")
(define-runtime-path gel-loop-path "../../../gel/loop.aloe")
(define-runtime-path gel-menu-path "../../../gel/menu.aloe")
(define-runtime-path gel-point-path "../../../examples/point.aloe")

(define item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "o" "r" "s" "t" "v" "w" "x" "y" "z"))

(define (load-silently! state path)
  (define output (open-output-string))
  (check-equal? (driver-load-file! state path output) '())
  (check-equal? (get-output-string output) ""))

(define (make-directory-driver receiver)
  (define state (make-driver))
  (driver-inject-host! state 'fs-host receiver)
  (load-silently! state gel-loop-path)
  (load-silently! state disk-library-path)
  (load-silently! state gel-directory-path)
  state)

(define (ordinary-nodes count)
  (for/fold ([nodes (hash "/" 'directory "/cwd" 'directory)])
            ([index (in-range 1 (add1 count))])
    (hash-set nodes
              (format "/cwd/name~a"
                      (~r index #:min-width 3 #:pad-string "0"))
              'file)))

(define (ordinary-labels count)
  (for/list ([index (in-range 1 (add1 count))])
    (format "name~a" (~r index #:min-width 3 #:pad-string "0"))))

(define (define-directory! state [name 'cwd])
  (driver-eval!
   state
   `(define ,name (Directory new ((Disk new fs-host) at "/cwd")))))

(define (define-step! state name directory
                      #:show-hidden [show-hidden #f]
                      #:page [page 0])
  (driver-eval!
   state
   `(define ,name
      (GelStep new
        (gel-empty-stack push ,directory)
        #f (List empty) 0 #f ,show-hidden ,page))))

(define (expected-directory-menu labels page show-hidden)
  (define page-size (length item-keys))
  (define count (length labels))
  (define page-count (quotient (+ count (sub1 page-size)) page-size))
  (define visible
    (take (drop labels (* page page-size))
          (min page-size (max 0 (- count (* page page-size))))))
  (define rows
    (apply string-append
           (for/list ([label (in-list visible)]
                      [key (in-list item-keys)])
             (string-append key "  " label "\r\n"))))
  (string-append
   rows
   (if (null? visible) "" "\r\n")
   (format "~a entries\r\n" count)
   (if (> page-count 1)
       (format "page ~a of ~a\r\n" (add1 page) page-count)
       "")
   "u  up\r\n"
   (if show-hidden ".  hide hidden\r\n" ".  show hidden\r\n")
   "n  next\r\n"
   "p  prev\r\n"))

(define (make-counting-fs current nodes)
  (define inner (make-fs-double current nodes))
  (define names-calls (box 0))
  (define interface
    (make-host-interface
     'CountingFsHost
     (list
      (make-host-method
       'current '() 'String
       (lambda (state)
         (host-receiver-send state 'current '())))
      (make-host-method
       'resolve '(String) 'String
       (lambda (state path)
         (host-receiver-send state 'resolve (list path))))
      (make-host-method
       'child '(String String) 'String
       (lambda (state path name)
         (host-receiver-send state 'child (list path name))))
      (make-host-method
       'root? '(String) 'Bool
       (lambda (state path)
         (host-receiver-send state 'root? (list path))))
      (make-host-method
       'parent '(String) 'String
       (lambda (state path)
         (host-receiver-send state 'parent (list path))))
      (make-host-method
       'name '(String) 'String
       (lambda (state path)
         (host-receiver-send state 'name (list path))))
      (make-host-method
       'kind '(String) 'String
       (lambda (state path)
         (host-receiver-send state 'kind (list path))))
      (make-host-method
       'names '(String) '(List String)
       (lambda (state path)
         (set-box! names-calls (add1 (unbox names-calls)))
         (host-receiver-send state 'names (list path)))))))
  (values (make-host-receiver interface inner) names-calls))

(define (selector-names state expression)
  (driver-eval!
   state
   `(((Mirror of ,expression) messages) map
     (fn (message) (message name)))))

(test-case "exact status bytes cover empty one-page and multi-page listings"
  (for ([count '(0 1 22 23 23 180 180)]
        [page '(0 0 0 0 1 0 8)])
    (define state
      (make-directory-driver
       (make-fs-double "/cwd" (ordinary-nodes count))))
    (define-directory! state)
    (check-equal?
     (driver-eval! state `(gel-text menu (Mirror of cwd) #f ,page))
     (expected-directory-menu (ordinary-labels count) page #f))))

(test-case "hidden filtering changes the unwindowed count before paging"
  (define nodes
    (hash-set (ordinary-nodes 22) "/cwd/.secret" 'file))
  (define state
    (make-directory-driver (make-fs-double "/cwd" nodes)))
  (define-directory! state)
  (define filtered-labels (ordinary-labels 22))
  (define all-labels (cons ".secret" filtered-labels))
  (check-equal?
   (driver-eval! state '(gel-text menu (Mirror of cwd) #f 0))
   (expected-directory-menu filtered-labels 0 #f))
  (check-equal?
   (driver-eval! state '(gel-text menu (Mirror of cwd) #t 0))
   (expected-directory-menu all-labels 0 #t))
  (define-step! state 'filtered 'cwd)
  (driver-eval! state '(define shown (filtered handle-key ".")))
  (check-true (driver-eval! state '(shown show-hidden)))
  (check-equal? (driver-eval! state '(shown page)) 0)
  (check-equal?
   (driver-eval! state '(gel-text menu shown))
   (expected-directory-menu all-labels 0 #t))
  (driver-eval! state '(define shown-last (shown handle-key "n")))
  (check-equal? (driver-eval! state '(shown-last page)) 1)
  (check-true
   (string-prefix? (driver-eval! state '(gel-text menu shown-last))
                   "a  name022\r\n\r\n23 entries\r\npage 2 of 2\r\n")))

(test-case "one Directory draw invokes host names exactly once"
  (define-values (receiver names-calls)
    (make-counting-fs "/cwd" (ordinary-nodes 23)))
  (define state (make-directory-driver receiver))
  (define-directory! state)
  (check-equal? (unbox names-calls) 0)
  (check-equal?
   (driver-eval! state '(gel-text menu (Mirror of cwd) #f 0))
   (expected-directory-menu (ordinary-labels 23) 0 #f))
  (check-equal? (unbox names-calls) 1)
  (check-equal?
   (driver-eval! state '(gel-text menu (Mirror of cwd) #t 1))
   (expected-directory-menu (ordinary-labels 23) 1 #t))
  (check-equal? (unbox names-calls) 2))

(test-case "paging controls stay visible and retain their transitions"
  (for ([count '(0 1)])
    (define state
      (make-directory-driver
       (make-fs-double "/cwd" (ordinary-nodes count))))
    (define-directory! state)
    (define-step! state 'start 'cwd)
    (define menu (driver-eval! state '(gel-text menu start)))
    (check-true (string-contains? menu "n  next\r\np  prev\r\n"))
    (check-eq? (driver-eval! state '(start handle-key "n"))
               (driver-eval! state 'start))
    (check-eq? (driver-eval! state '(start handle-key "p"))
               (driver-eval! state 'start)))

  (define state
    (make-directory-driver
     (make-fs-double "/cwd" (ordinary-nodes 23))))
  (define-directory! state)
  (define-step! state 'first 'cwd)
  (driver-eval! state '(define second (first handle-key "n")))
  (check-equal? (driver-eval! state '(first page)) 0)
  (check-equal? (driver-eval! state '(second page)) 1)
  (check-eq? (driver-eval! state '(second handle-key "n"))
             (driver-eval! state 'second))
  (driver-eval! state '(define back (second handle-key "p")))
  (check-equal? (driver-eval! state '(back page)) 0)
  (driver-eval! state '(define selected (second handle-key "a")))
  (check-equal? (driver-eval! state '(selected page)) 0)
  (check-equal? (driver-eval! state '(((selected stack) tos) raw))
                "#<File #<Location #<FsHost> \"/cwd/name023\">>"))

(test-case "non-Directory and pending menu bytes have no status"
  (define nodes
    (hash "/" 'directory
          "/cwd" 'directory
          "/cwd/file" 'file
          "/cwd/link" 'symlink
          "/cwd/pipe" "fifo"))
  (define state
    (make-directory-driver (make-fs-double "/cwd" nodes)))
  (load-silently! state gel-point-path)
  (driver-eval! state
                '(define file
                   (File new ((Disk new fs-host) at "/cwd/file"))))
  (driver-eval! state
                '(define link
                   (SymbolicLink new ((Disk new fs-host) at "/cwd/link"))))
  (driver-eval! state
                '(define other
                   (Other new ((Disk new fs-host) at "/cwd/pipe") "fifo")))
  (driver-eval!
   state
   '(define-class Derived
      (fields (value Int))
      (methods
        (twice () Int ((self value) * 2)))))
  (check-equal? (driver-eval! state '(gel-text menu (List of 1 2)))
                "a  1\r\nb  2\r\n")
  (for ([expression '(file link other
                      (Point new 1 2)
                      10
                      (Derived new 7))])
    (define text (driver-eval! state `(gel-text menu ,expression)))
    (check-false (regexp-match? #rx"entries\r\n|page [0-9]+ of" text)))

  (driver-eval! state '(define int-rows (gel-rows of 10)))
  (driver-eval!
   state
   '(define int-plus
      (int-rows fold
        (int-rows first)
        (fn (found row)
          (if (((row selector) name) = "+") row found)))))
  (driver-eval!
   state
   '(define pending
      (GelStep new
        (gel-empty-stack push 10)
        #f (List of int-plus) 0 #f #f 0)))
  (check-equal? (driver-eval! state '(gel-text menu pending))
                "pending +  Int \r\n"))

(test-case "presentation ownership and surrounding machinery stay unchanged"
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double "/cwd" (ordinary-nodes 1)))
  (load-silently! state disk-library-path)
  (define-directory! state)
  (driver-eval! state
                '(define file
                   (File new ((Disk new fs-host) at "/cwd/name001"))))
  (driver-eval! state
                '(define link
                   (SymbolicLink new ((Disk new fs-host) at "/cwd/link"))))
  (driver-eval! state
                '(define other
                   (Other new ((Disk new fs-host) at "/cwd/other") "fifo")))
  (driver-eval! state '(define values (List of 1 2)))
  (define subjects '(cwd file link other values))
  (define before
    (for/hash ([subject (in-list subjects)])
      (values subject (selector-names state subject))))
  (load-silently! state gel-loop-path)
  (load-silently! state gel-directory-path)
  (for ([subject (in-list subjects)])
    (check-equal? (selector-names state subject) (hash-ref before subject)))

  (define menu-source (file->string gel-menu-path))
  (define loop-source (file->string gel-loop-path))
  (define directory-source (file->string gel-directory-path))
  (check-true
   (string-contains? directory-source
                     "(define-class (GelDirectoryPresentations H)"))
  (check-false (string-contains? loop-source "(directory entries)"))
  (for ([source (in-list (list menu-source loop-source))])
    (for ([forbidden '("define-methods Directory"
                       "define-methods File"
                       "define-methods SymbolicLink"
                       "define-methods Other"
                       "define-methods List"
                       "define-methods Term"
                       "GelPager"
                       "GelStatus"
                       "GelColor"
                       "armed-window"
                       "search"
                       "\\e["
                       "\\033[")])
      (check-false (string-contains? source forbidden) forbidden))))
