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

(define faint "\u001b[2m")
(define reset "\u001b[0m")
(define escape (string #\u001b))

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
                      #:page [page 0]
                      #:pending [pending '(List empty)])
  (driver-eval!
   state
   `(define ,name
      (GelStep new
        (gel-empty-stack push ,directory)
        #f ,pending 0 #f ,show-hidden ,page))))

(define (page-count count)
  (quotient (+ count (sub1 (length item-keys))) (length item-keys)))

(define (paging-line text live?)
  (if live?
      (string-append text "\r\n")
      (string-append faint text reset "\r\n")))

(define (paging-commands count page show-hidden)
  (define pages (page-count count))
  (string-append
   "u  up\r\n"
   (if show-hidden ".  hide hidden\r\n" ".  show hidden\r\n")
   (paging-line "n  next" (< (add1 page) pages))
   (paging-line "p  prev" (positive? page))))

(define (expected-directory-menu labels page show-hidden)
  (define page-size (length item-keys))
  (define count (length labels))
  (define offset (* page page-size))
  (define visible
    (take (drop labels (min count offset))
          (min page-size (max 0 (- count offset)))))
  (define rows
    (apply string-append
           (for/list ([label (in-list visible)]
                      [key (in-list item-keys)])
             (string-append key "  " label "\r\n"))))
  (define pages (page-count count))
  (string-append
   rows
   (if (null? visible) "" "\r\n")
   (format "~a entries\r\n" count)
   (if (> pages 1)
       (format "page ~a of ~a\r\n" (add1 page) pages)
       "")
   (paging-commands count page show-hidden)))

(define (check-no-unexpected-ansi text)
  (define without-faint (string-replace text faint ""))
  (define without-allowed (string-replace without-faint reset ""))
  (check-false (string-contains? without-allowed escape))
  (for ([code (in-list (append (range 30 40) (range 90 100)))])
    (check-false (string-contains? text (format "\u001b[~am" code)))))

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

(test-case "empty and one-page Directory menus dim both paging commands"
  (for ([count '(0 1 22)])
    (define state
      (make-directory-driver
       (make-fs-double "/cwd" (ordinary-nodes count))))
    (define-directory! state)
    (define text
      (driver-eval! state '(gel-text menu (Mirror of cwd) #f 0)))
    (check-equal? text
                  (expected-directory-menu (ordinary-labels count) 0 #f))
    (check-true
     (string-suffix?
      text
      (string-append
       "u  up\r\n.  show hidden\r\n"
       faint "n  next" reset "\r\n"
       faint "p  prev" reset "\r\n")))
    (check-false (string-contains? text (string-append reset "\r" faint)))
    (check-no-unexpected-ansi text)))

(test-case "first middle and last pages style only dead moves"
  (for ([count '(23 23 45)]
        [page '(0 1 1)])
    (define state
      (make-directory-driver
       (make-fs-double "/cwd" (ordinary-nodes count))))
    (define-directory! state)
    (define text
      (driver-eval! state `(gel-text menu (Mirror of cwd) #f ,page)))
    (check-equal? text
                  (expected-directory-menu (ordinary-labels count) page #f))
    (check-no-unexpected-ansi text))

  (define state
    (make-directory-driver
     (make-fs-double "/cwd" (ordinary-nodes 45))))
  (define-directory! state)
  (define first
    (driver-eval! state '(gel-text menu (Mirror of cwd) #f 0)))
  (define middle
    (driver-eval! state '(gel-text menu (Mirror of cwd) #f 1)))
  (define last
    (driver-eval! state '(gel-text menu (Mirror of cwd) #f 2)))
  (check-true
   (string-suffix? first
                   (string-append
                    "u  up\r\n.  show hidden\r\nn  next\r\n"
                    faint "p  prev" reset "\r\n")))
  (check-true
   (string-suffix? middle
                   (string-append
                    "u  up\r\n.  show hidden\r\n"
                    "n  next\r\np  prev\r\n")))
  (check-true
   (string-suffix? last
                   (string-append
                    "u  up\r\n.  show hidden\r\n"
                    faint "n  next" reset "\r\np  prev\r\n")))
  (check-false (string-contains? middle escape)))

(test-case "hidden filtering controls availability and resets to page zero"
  (define nodes
    (hash-set (ordinary-nodes 22) "/cwd/.secret" 'file))
  (define state
    (make-directory-driver (make-fs-double "/cwd" nodes)))
  (define-directory! state)
  (define-step! state 'hidden-page 'cwd #:page 1)
  (define hidden-text
    (driver-eval! state '(gel-text menu (Mirror of cwd) #f 0)))
  (check-equal? hidden-text
                (expected-directory-menu (ordinary-labels 22) 0 #f))
  (driver-eval! state '(define shown (hidden-page handle-key ".")))
  (check-true (driver-eval! state '(shown show-hidden)))
  (check-equal? (driver-eval! state '(shown page)) 0)
  (define shown-labels (cons ".secret" (ordinary-labels 22)))
  (define shown-text (driver-eval! state '(gel-text menu shown)))
  (check-equal? shown-text (expected-directory-menu shown-labels 0 #t))
  (check-true
   (string-suffix?
    shown-text
    (string-append
     "u  up\r\n.  hide hidden\r\nn  next\r\n"
     faint "p  prev" reset "\r\n"))))

(test-case "one Directory draw lists the selected presentation once"
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

(test-case "display predicates agree with bounded Directory transitions"
  (define state
    (make-directory-driver
     (make-fs-double "/cwd" (ordinary-nodes 45))))
  (define-directory! state)
  (define-step! state 'first 'cwd)
  (driver-eval! state '(define middle (first handle-key "n")))
  (driver-eval! state '(define last (middle handle-key "n")))
  (check-equal? (driver-eval! state '(first page)) 0)
  (check-equal? (driver-eval! state '(middle page)) 1)
  (check-equal? (driver-eval! state '(last page)) 2)
  (check-eq? (driver-eval! state '(first stack))
             (driver-eval! state '(middle stack)))
  (check-eq? (driver-eval! state '(middle stack))
             (driver-eval! state '(last stack)))
  (check-eq? (driver-eval! state '(first handle-key "p"))
             (driver-eval! state 'first))
  (check-eq? (driver-eval! state '(last handle-key "n"))
             (driver-eval! state 'last))
  (driver-eval! state '(define back (last handle-key "p")))
  (check-equal? (driver-eval! state '(back page)) 1)
  (driver-eval! state '(define selected (middle handle-key "a")))
  (check-equal? (driver-eval! state '(selected page)) 0)
  (check-equal? (driver-eval! state '(((selected stack) items) len)) 2)
  (check-equal? (driver-eval! state '(((selected stack) tos) raw))
                "#<File #<Location #<FsHost> \"/cwd/name023\">>")
  (for ([name '(first middle last)])
    (check-equal?
     (driver-eval! state `(gel-text menu ,name))
     (expected-directory-menu
      (ordinary-labels 45)
      (driver-eval! state `(,name page))
      #f))))

(test-case "empty pending and non-Directory paging behavior is unchanged"
  (for ([count '(0 1)])
    (define state
      (make-directory-driver
       (make-fs-double "/cwd" (ordinary-nodes count))))
    (define-directory! state)
    (define-step! state 'start 'cwd)
    (check-eq? (driver-eval! state '(start handle-key "n"))
               (driver-eval! state 'start))
    (check-eq? (driver-eval! state '(start handle-key "p"))
               (driver-eval! state 'start)))

  (define state
    (make-directory-driver
     (make-fs-double "/cwd" (ordinary-nodes 1))))
  (load-silently! state gel-point-path)
  (driver-eval! state '(define point (Point new 10 20)))
  (define point-text (driver-eval! state '(gel-text menu point)))
  (check-equal?
   point-text
   (string-append
    "1  x  0\r\n2  y  0\r\n3  +  1\r\n4  -  1\r\n"
    "5  dist2  1\r\n6  dot  1\r\n7  *  1\r\n8  /  1\r\n"))
  (check-false (string-contains? point-text escape))
  (define-step! state 'point-idle 'point #:page 3)
  (for ([key '("n" "p")])
    (check-eq? (driver-eval! state `(point-idle handle-key ,key))
               (driver-eval! state 'point-idle)))

  (driver-eval! state '(define int-rows (gel-rows of 10)))
  (bind-row! state 'int-plus 'int-rows "+" 1)
  (driver-eval!
   state
   '(define pending
      (GelStep new
        (gel-empty-stack push 10)
        #f (List of int-plus) 0 #f #f 3)))
  (define pending-text (driver-eval! state '(gel-text menu pending)))
  (check-equal? pending-text "pending +  Int \r\n")
  (check-false (string-contains? pending-text escape))
  (for ([key '("n" "p")])
    (check-eq? (driver-eval! state `(pending handle-key ,key))
               (driver-eval! state 'pending)))
  (check-equal? (driver-eval! state '(gel-text menu (List of 1 2)))
                "a  1\r\nb  2\r\n"))

(test-case "dimming stays inside GelText presentation"
  (define state (make-driver))
  (load-silently! state gel-loop-path)
  (check-equal? (driver-eval! state '(gel-item-keys len)) 22)
  (define loop-source (file->string gel-loop-path))
  (define menu-source (file->string gel-menu-path))
  (define directory-source (file->string gel-directory-path))
  (check-true (string-contains? loop-source "(gel-item-keys len)"))
  (check-true (string-contains? loop-source "\"\\x1b[2m\""))
  (check-true (string-contains? loop-source "\"\\x1b[0m\""))
  (check-false (string-contains? loop-source "(directory entries)"))
  (check-true
   (string-contains? directory-source
                     "(define-class (GelDirectoryPresentations H)"))
  (check-equal? (length (regexp-match* #rx"\\(GelItemKey new" menu-source))
                22)
  (for ([forbidden '("define-methods Directory"
                     "define-methods Term"
                     "GelPager"
                     "GelStyle"
                     "GelColor"
                     "NO_COLOR"
                     "armed-window"
                     "search"
                     "show-options")])
    (check-false
     (string-contains? (string-append loop-source directory-source menu-source)
                       forbidden)
     forbidden)))
