#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path aloe-directory "../../aloe")
(define-runtime-path directory-source-path "../../gel/directory.aloe")
(define-runtime-path gel-loop-path "../../gel/loop.aloe")
(define-runtime-path gel-menu-path "../../gel/menu.aloe")
(define-runtime-path gel-point-path "../../examples/gel-point.aloe")
(define-runtime-path host-directory "../../host")
(define-runtime-path library-directory "../../lib")
(define-runtime-path disk-library-path "../../lib/disk.aloe")
(define-runtime-path list-library-path "../../lib/list.aloe")
(define-runtime-path presentations-path "../../gel/presentations.aloe")

(define item-keys
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"
    "m" "o" "r" "s" "t" "v" "w" "x" "y" "z"))

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

(define (load-silently! state path [output (open-output-string)])
  (check-equal? (driver-load-file! state path output) '())
  (check-equal? (get-output-string output) "")
  state)

(define (make-loop-driver)
  (load-silently! (make-driver) gel-loop-path))

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

(define (menu-value-row-count state subject)
  (driver-eval!
   state
   `((gel-menus of (Mirror of ,subject)) case
     (Messages (rows) -1)
     (Values (rows) (rows len)))))

(test-case "List signatures stay fixed while the service accepts every List"
  (define state (make-driver))
  (for ([name '(GelPresentations gel-presentations)])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))

  (driver-eval! state '(define checkpoint-list (List of 10 20 30)))
  (driver-eval! state '(define checkpoint-empty (checkpoint-list rest)))
  (driver-eval! state '(define checkpoint-empty ((checkpoint-empty rest) rest)))
  (define messages-before
    (selector-names state 'checkpoint-list 'messages))
  (define signatures-before
    (selector-names state 'checkpoint-list 'signatures))
  (check-equal? (message-count state 'checkpoint-list "gel-values") 0)
  (check-equal? (signature-count state 'checkpoint-list "gel-values" 0) 0)

  (load-silently! state gel-loop-path)

  (check-equal? (selector-names state 'checkpoint-list 'messages)
                messages-before)
  (check-equal? (selector-names state 'checkpoint-list 'signatures)
                signatures-before)
  (check-equal? (message-count state 'checkpoint-list "gel-values") 0)
  (check-equal? (signature-count state 'checkpoint-list "gel-values" 0) 0)
  (check-equal?
   (signature-count state 'gel-presentations "list-values" 1)
   1)

  (driver-eval!
   state
   '(define list-value-signatures
      ((((Mirror of gel-presentations) signatures) fold
         (List empty)
         (fn (matches signature)
           (if (((signature selector) name) = "list-values")
               (if (((signature params) len) = 1)
                   (matches cons signature)
                   matches)
               matches)))
       reverse)))
  (driver-eval!
   state
   '(define list-value-signature (list-value-signatures first)))
  (check-true
   (driver-eval!
    state
    '(list-value-signature accepts? (Mirror of checkpoint-list))))
  (check-true
   (driver-eval!
    state
    '(list-value-signature accepts? (Mirror of checkpoint-empty))))
  (check-false
   (driver-eval! state '(list-value-signature accepts? (Mirror of 10)))))

(test-case "the moved body returns ordered mirrors and preserves mirror identity"
  (define state (make-loop-driver))
  (check-equal?
   (driver-type-datum
    state
    '(gel-presentations list-values (List of 10 20 30)))
   'GelListValues)
  (driver-eval!
   state
   '(define moved-values
      (gel-presentations list-values (List of 10 20 30))))
  (check-equal? (driver-eval! state '((moved-values items) len)) 3)
  (for ([index (in-range 3)]
        [expected '(10 20 30)])
    (define item
      (for/fold ([item '(moved-values items)])
                ([_ (in-range index)])
        `(,item rest)))
    (check-equal? (driver-eval! state `((,item first) subject)) expected))

  (driver-eval! state '(define existing-a (Mirror of 10)))
  (driver-eval! state '(define existing-b (Mirror of 20)))
  (driver-eval!
   state
   '(define retained
      (gel-presentations list-values (List of existing-a existing-b))))
  (check-eq? (driver-eval! state '((retained items) first))
             (driver-eval! state 'existing-a))
  (check-eq? (driver-eval! state '(((retained items) rest) first))
             (driver-eval! state 'existing-b))
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval! state '((List of 10 20) gel-values)))))

(test-case "GelMenus recognizes Lists without a specimen nametag"
  (define state (make-loop-driver))
  (driver-eval! state '(define empty-list ((List of 0) rest)))
  (driver-eval! state '(define one-list (List of 1)))
  (driver-eval! state `(define full-list (List of ,@(range 1 23))))
  (driver-eval! state `(define overflow-list (List of ,@(range 1 25))))
  (for ([subject '(empty-list one-list full-list overflow-list)]
        [expected '(0 1 22 22)])
    (check-equal? (menu-value-row-count state subject) expected))

  (check-equal? (driver-eval! state '(gel-text menu empty-list)) "")
  (define overflow-menu
    (driver-eval! state '(gel-text menu overflow-list)))
  (check-equal?
   overflow-menu
   (apply string-append
          (for/list ([key (in-list item-keys)]
                     [value (in-range 1 23)])
            (format "~a  ~a\r\n" key value))))
  (for ([selector '("empty?" "first" "rest" "cons" "len" "map"
                    "fold" "reverse" "gel-values" "list-values")])
    (check-false
     (regexp-match? (regexp (regexp-quote selector)) overflow-menu)
     selector))

  (check-equal? (driver-eval! state '(gel-text menu 10)) int-menu)
  (load-silently! state gel-point-path)
  (check-equal? (driver-eval! state '(gel-text menu gel-start-value))
                point-menu))

(test-case "Directory stays unpatched while the optional service is discoverable"
  (define state (make-driver))
  (driver-inject-host!
   state
   'fs-host
   (make-fs-double
    "/cwd"
    (hash "/" 'directory
          "/cwd" 'directory
          "/cwd/file.txt" 'file)))
  (load-silently! state disk-library-path)
  (load-silently! state gel-loop-path)
  (load-silently! state directory-source-path)
  (driver-eval!
   state
   '(define live-directory
      (Directory new ((Disk new fs-host) current))))

  (check-equal?
   (signature-count state 'live-directory "gel-directory-values" 0)
   0)
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-type-datum state '(live-directory gel-directory-values))))
  (check-equal?
   (signature-count state 'gel-menus "directory-presentations" 0)
   1)
  (check-equal?
   (signature-count state
                    'gel-directory-presentations
                    "directory-values"
                    1)
   1)
  (check-true
   (driver-eval!
    state
    '(gel-menus directory? (Mirror of live-directory)))))

(test-case "the slice stays within the List presentation surface"
  (define menu-source (file->string gel-menu-path))
  (define presentations-source (file->string presentations-path))
  (define directory-source (file->string directory-source-path))
  (define list-source (file->string list-library-path))

  (check-equal?
   (length (regexp-match* #rx"\\(define-methods List" menu-source))
   0)
  (check-equal?
   (length (regexp-match* #rx"\\(define-methods List" list-source))
   1)
  (check-false (regexp-match? #rx"\"gel-values\"" menu-source))
  (check-regexp-match #rx"[(]load \"presentations[.]aloe\"[)]" menu-source)
  (check-equal?
   (length
    (regexp-match* #rx"\\(define-methods GelPresentations" menu-source))
   1)
  (check-false
   (regexp-match? #rx"Directory|File|SymbolicLink|Other"
                  presentations-source))
  (check-regexp-match
   #rx"\\(define-class \\(GelDirectoryPresentations H\\)"
   directory-source)
  (check-equal?
   (length (regexp-match* #rx"\\(define-methods GelMenus" directory-source))
   1)
  (for ([class '(Directory File SymbolicLink Other)])
    (check-equal?
     (length
      (regexp-match*
       (regexp (format "\\(define-methods ~a" class))
       directory-source))
     0))
  (for ([source (in-list (list menu-source presentations-source))])
    (check-false
     (regexp-match? #px"\\s(?:take|drop)(?:\\s|[)])" source)))

  ;; The experiment adds no Gel presentation vocabulary to these layers.
  (for ([directory
         (in-list (list aloe-directory host-directory library-directory))])
    (for ([path
           (in-list
            (find-files
             (lambda (candidate)
               (and (file-exists? candidate)
                    (regexp-match? #rx"[.](?:rkt|aloe)$"
                                   (path->string candidate))))
             directory))])
      (check-false
       (regexp-match? #rx"GelPresentations|gel-presentations|list-values"
                      (file->string path))
       (path->string path)))))
