#lang racket/base

(require racket/file
         racket/format
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../aloe/driver.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt" type-of type->datum)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

(define-runtime-path aloe-directory "../aloe")
(define-runtime-path disk-library-path "../lib/disk.aloe")
(define-runtime-path gel-directory-path "../gel/directory.aloe")
(define-runtime-path gel-directory-application-path
  "../examples/gel-directory.aloe")
(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path gel-main-path "../gel/main.aloe")
(define-runtime-path gel-menu-path "../gel/menu.aloe")
(define-runtime-path gel-point-path "../examples/point.aloe")
(define-runtime-path gel-stack-path "../gel/stack.aloe")

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
   "u  up\r\n"))

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (load-silently! state path [output (open-output-string)])
  (check-equal? (driver-load-file! state path output) '())
  output)

(define (make-gel-driver #:adapter? [adapter? #f]
                         #:receiver
                         [receiver (make-fs-double "/cwd" mixed-nodes)])
  (define state (make-driver))
  (define output (open-output-string))
  (driver-inject-host! state 'fs-host receiver)
  (load-silently! state gel-loop-path output)
  (load-silently! state disk-library-path output)
  (when adapter?
    (load-silently! state gel-directory-path output))
  (check-equal? (get-output-string output) "")
  state)

(define (define-live-values! state)
  (driver-eval!
   state
   '(define directory-value
      (Directory new (Location new fs-host "/home/dharmatech"))))
  (driver-eval!
   state
   '(define file-value
      (File new (Location new fs-host "/etc/passwd"))))
  (driver-eval!
   state
   '(define link-value
      (SymbolicLink new (Location new fs-host "/bin"))))
  (driver-eval!
   state
   '(define other-value
      (Other new (Location new fs-host "/dev/null") "character-device"))))

(define (tos-expression name)
  `(gel-text tos (gel-empty-stack push ,name)))

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
    (make-temporary-directory "aloe-gel-tos-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

(test-case "generic Gel keeps exact raw TOS bytes before the adapter loads"
  (define state (make-gel-driver))
  (load-silently! state gel-point-path)
  (define-live-values! state)
  (for ([expression
         (in-list
          '(10
            "alpha"
            (List of 10 20)
            (Point new 1 2)
            directory-value))]
        [expected
         (in-list
          '("TOS: 10"
            "TOS: \"alpha\""
            "TOS: #<List 10 20>"
            "TOS: #<Point 1 2>"
            "TOS: #<Directory #<Location #<FsHost> \"/home/dharmatech\">>"))])
    (check-equal?
     (driver-eval!
      state
      `(gel-text tos (gel-empty-stack push ,expression)))
     expected)))

(test-case "adapter renders all four live classes with exact path text"
  (define state (make-gel-driver #:adapter? #t))
  (define-live-values! state)
  (for ([name
         (in-list '(directory-value file-value link-value other-value))]
        [direct
         (in-list
          '("#<Directory \"/home/dharmatech\">"
            "#<File \"/etc/passwd\">"
            "#<SymbolicLink \"/bin\">"
            "#<Other \"/dev/null\">"))])
    (check-equal? (driver-type-datum state `(,name gel-tos-text)) 'String)
    (check-equal? (driver-eval! state `(,name gel-tos-text)) direct)
    (check-equal?
     (driver-eval! state (tos-expression name))
     (string-append "TOS: " direct)))
  (check-false
   (string-contains?
    (driver-eval! state (tos-expression 'other-value))
    "character-device")))

(test-case "path String raw spelling escapes quotes slashes and line breaks"
  (define state (make-gel-driver #:adapter? #t))
  (define path "/tmp/a\"b\\c\nnext")
  (driver-eval!
   state
   `(define escaped-directory
      (Directory new (Location new fs-host ,path))))
  (define rendered
    (driver-eval! state (tos-expression 'escaped-directory)))
  (check-equal? rendered (format "TOS: #<Directory ~s>" path))
  (check-equal? (length (regexp-match* #rx"\n" rendered)) 0)
  (check-true (string-contains? rendered "\\\""))
  (check-true (string-contains? rendered "\\\\"))
  (check-true (string-contains? rendered "\\n")))

(test-case "Mirror.raw remains the original structural disk dump"
  (define state (make-gel-driver #:adapter? #t))
  (define-live-values! state)
  (for ([name
         (in-list '(directory-value file-value link-value other-value))]
        [expected
         (in-list
          '("#<Directory #<Location #<FsHost> \"/home/dharmatech\">>"
            "#<File #<Location #<FsHost> \"/etc/passwd\">>"
            "#<SymbolicLink #<Location #<FsHost> \"/bin\">>"
            "#<Other #<Location #<FsHost> \"/dev/null\"> \"character-device\">"))])
    (check-equal?
     (driver-eval! state `((Mirror of ,name) raw))
     expected)))

(test-case "menus retain checkpoint 112 bytes and hide the private selector"
  (define generic-state (make-gel-driver))
  (define-live-values! generic-state)
  (define derived-before
    (for/hash ([name (in-list '(file-value link-value other-value))])
      (values name
              (driver-eval!
               generic-state
               `(gel-text menu (Mirror of ,name))))))

  (define state (make-gel-driver #:adapter? #t))
  (define-live-values! state)
  (driver-eval!
   state
   '(define cwd
      (Directory new ((Disk new fs-host) current))))
  (check-equal? (driver-eval! state '(gel-text menu (Mirror of cwd)))
                mixed-menu)
  (for ([name (in-list '(file-value link-value other-value))])
    (define menu
      (driver-eval! state `(gel-text menu (Mirror of ,name))))
    (check-equal? menu (hash-ref derived-before name))
    (check-not-equal? menu "")
    (check-false (string-contains? menu "gel-tos-text"))
    (driver-eval!
     state
     `(define visible-rows
        (gel-text message-rows (gel-rows of (Mirror of ,name)))))
    (check-false
     (driver-eval!
      state
      '(visible-rows fold
         #f
         (fn (found row)
           (if (((row selector) name) = "gel-tos-text")
               #t
               found))))))
  (check-true (string-contains? mixed-menu "u  up\r\n"))
  (check-false (string-contains? mixed-menu "gel-tos-text")))

(test-case "quit-only Directory main keeps its screen and one-item stack"
  (define-values (term terminal-output reader-calls)
    (make-scripted-term '("q")))
  (define state (make-driver))
  (define load-output (open-output-string))
  (driver-inject-host! state 'term term)
  (driver-inject-host!
   state
   'fs-host
   (make-fs-double "/cwd" mixed-nodes))
  (load-silently! state gel-main-path load-output)
  (load-silently! state gel-directory-application-path load-output)
  (define start-value (driver-eval! state 'gel-start-value))
  (driver-eval!
   state
   '(define checkpoint-113-final
      (gel-main start gel-start-value)))
  (check-equal?
   (get-output-string terminal-output)
   (string-append
    "TOS: #<Directory \"/cwd\">\r\n"
    mixed-menu
    "\r\n"
    "key q\r\n"))
  (check-equal? (unbox reader-calls) 1)
  (check-equal? (get-output-string load-output) "")
  (check-equal?
   (driver-eval! state '((checkpoint-113-final items) len))
   1)
  (check-eq?
   (driver-eval! state '((checkpoint-113-final tos) subject))
   start-value))

(test-case "production current Directory renders its actual isolated path"
  (call-with-temporary-directory
   (lambda (directory)
     (define state
       (make-gel-driver #:adapter? #t #:receiver (make-fs-receiver)))
     (parameterize ([current-directory directory])
       (driver-eval!
        state
        '(define production-directory
           (Directory new ((Disk new fs-host) current)))))
     (define path (path->string directory))
     (check-equal? (driver-eval! state '(production-directory text)) path)
     (check-equal?
      (driver-eval! state (tos-expression 'production-directory))
      (format "TOS: #<Directory ~s>" path)))))

(test-case "implementation stays inside the checkpoint seam and file scope"
  (define loop-source (file->string gel-loop-path))
  (define directory-source (file->string gel-directory-path))
  (check-false (regexp-match? #rx"tos-value|top subject" loop-source))
  (check-false (regexp-match? #rx"tos-value" directory-source))
  (check-equal?
   (length (regexp-match* #rx"\\(gel-tos-text \\(\\) String"
                          directory-source))
   4)
  (check-regexp-match
   #px"\\(tos-result\\s+\\(top Mirror\\)\\s+\\(signature Signature\\)\\s+String\\s+\\(top inv\\|o\\|ke signature\\)\\)"
   loop-source)
  (check-regexp-match #rx"top signatures" loop-source)
  (check-regexp-match #rx"top raw" loop-source)
  (check-regexp-match
   #px"handle-messages\\s+\\(gel-text message-rows rows\\)"
   loop-source)
  (for ([path (in-list (list gel-menu-path gel-stack-path gel-main-path))])
    (check-false
     (regexp-match? #rx"gel-tos-text|GelMessageRows|tos-value"
                    (file->string path))
     (path->string path)))
  (check-false
   (regexp-match? #rx"gel-tos-text|GelText|tos-value"
                  (file->string disk-library-path)))
  (for ([path (in-list (find-files file-exists? aloe-directory))])
    (when (file-exists? path)
      (check-false
       (regexp-match? #rx"gel-tos-text|GelMessageRows|tos-value"
                      (file->string path))
       (path->string path)))))
