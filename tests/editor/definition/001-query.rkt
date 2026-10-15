#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../../aloe/definition-query.rkt"
         (only-in "../../../aloe/main.rkt"
                  exn:fail:aloe-type?))

(define-runtime-path point-path "fixtures/point.aloe")
(define-runtime-path shapes-path "fixtures/shapes.aloe")
(define-runtime-path wide-path "fixtures/wide.aloe")
(define-runtime-path wide-user-path "fixtures/wide-user.aloe")
(define-runtime-path option-path "../../../lib/option.aloe")

(define (normalized path)
  (simplify-path (path->complete-path path) #f))

;; The one-based character position of a one-based line and zero-based column.
(define (line-column->position text line column)
  (define lines (string-split text "\n" #:trim? #f))
  (+ 1
     column
     (for/sum ([preceding (in-list (take lines (sub1 line)))])
       (add1 (string-length preceding)))))

(define shapes-text (file->string shapes-path))

(define (check-shapes-cursor line column position)
  (check-equal? (line-column->position shapes-text line column) position))

;; A target as its file and (line column position span).
(define targets
  (hash 'Point (list point-path '(1 14 15 5))
        'Box (list shapes-path '(7 15 131 3))
        'Segment (list shapes-path '(16 14 279 7))
        'Holder (list shapes-path '(38 14 702 6))
        'Option (list option-path '(1 15 16 6))
        'Wide (list wide-path '(1 32 33 4))))

(define (location-numbers loc)
  (list (srcloc-line loc)
        (srcloc-column loc)
        (srcloc-position loc)
        (srcloc-span loc)))

;; The result's location is numbers in source, and its text is text.
(define (check-answer result source numbers text)
  (check-true (definition-query-result? result))
  (define location (definition-query-result-location result))
  (check-true (srcloc? location))
  (check-equal? (srcloc-source location) (normalized source))
  (check-equal? (location-numbers location) numbers)
  (check-equal? (definition-query-result-text result) text))

(define (check-jump result target)
  (define file (car (hash-ref targets target)))
  (check-answer result
                file
                (cadr (hash-ref targets target))
                (file->string file)))

(define (query-shapes position)
  (query-definition-at shapes-path position))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-file "definition-001-~a"
                         'directory
                         (find-system-path 'temp-dir)))
  (dynamic-wind
    void
    (lambda () (procedure directory))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (write-source path source)
  (call-with-output-file path
    (lambda (output) (display source output))
    #:exists 'truncate))

;; Calls procedure with a temporary file holding source.
(define (call-with-temporary-program source procedure)
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "program.aloe"))
     (write-source path source)
     (procedure path))))

(define (captured-exception thunk)
  (with-handlers ([exn:fail? values])
    (thunk)
    #f))

(test-case "class names, define-methods targets, and variables jump"
  (for ([row (in-list
              '((7 15 131 Box)
                (14 7 246 Point)
                (16 14 279 Segment)
                (24 16 452 Point)
                (27 7 513 Box)
                (27 26 532 Option)
                (31 16 615 Box)
                (36 10 680 Point)
                (38 14 702 Holder)
                (45 16 818 Point)
                (48 28 917 Point)
                (48 49 938 Point)
                (49 15 961 Point)))])
    (define-values (line column position target) (apply values row))
    (check-shapes-cursor line column position)
    (check-jump (query-shapes position) target))

  (define wide-user-text (file->string wide-user-path))
  (check-equal? (line-column->position wide-user-text 2 11) 31)
  (define wide-result (query-definition-at wide-user-path 31))
  (check-jump wide-result 'Wide)
  (check-true
   (string-contains? (definition-query-result-text wide-result)
                     (string (integer->char #x1F600)))))

(test-case "positions without a jumping token answer #f"
  (for ([row (in-list
              '((2 2 23)
                (4 17 81)
                (7 19 135)
                (9 10 158)
                (14 6 245)
                (14 12 251)
                (14 13 252)
                (16 22 287)
                (18 5 314)
                (26 26 495)
                (26 34 503)
                (27 20 526)
                (27 33 539)
                (28 14 561)
                (33 16 646)
                (36 8 678)
                (40 7 726)
                (41 12 741)
                (42 12 772)
                (42 15 775)
                (46 12 846)
                (46 19 853)
                (47 20 877)
                (48 20 909)
                (48 44 933)
                (49 21 967)
                (50 24 1010)
                (51 19 1042)
                (52 15 1070)))])
    (define-values (line column position) (apply values row))
    (check-shapes-cursor line column position)
    (check-false (query-shapes position) (format "position ~a" position)))

  (check-false (query-definition-at point-path 38))
  (check-false (query-shapes 5000)))

(test-case "a token answers from its first character through its last"
  (define segment (query-shapes 279))
  (check-jump segment 'Segment)
  (for ([position (in-range 279 286)])
    (check-equal? (query-shapes position) segment))
  (check-jump (query-shapes 133) 'Box)
  (check-false (query-shapes 134))
  (check-jump (query-shapes 822) 'Point)
  (check-false (query-shapes 823)))

(test-case "kernel class targets and receivers do not jump"
  (define source
    (string-append "(define-methods String\n"
                   "  (methods\n"
                   "    (shout () String self)))\n"
                   "(define s String)\n"))
  (define receiver-position (line-column->position source 4 10))
  (call-with-temporary-program
   source
   (lambda (path)
     (check-false (query-definition-at path 17))
     (check-false (query-definition-at path receiver-position)))))

(test-case "Option jumps to the base library and to a queried library buffer"
  (check-jump (query-shapes 532) 'Option)
  (check-jump (query-definition-at option-path 16) 'Option)

  (call-with-temporary-directory
   (lambda (directory)
     (define copy-path (build-path directory "option.aloe"))
     (define copy-text
       (string-append "; edited\n" (file->string option-path)))
     (write-source copy-path copy-text)
     (check-answer (query-definition-at copy-path
                                        25
                                        #:document-path option-path)
                   option-path
                   '(2 15 25 6)
                   copy-text))))

(test-case "a dirty buffer jumps by its identity and its loads by disk"
  (call-with-temporary-directory
   (lambda (directory)
     (define shapes-copy (build-path directory "shapes.aloe"))
     (define point-copy (build-path directory "point.aloe"))
     (define shapes-copy-text (string-append "\n" shapes-text))
     (define point-copy-text
       (string-append "; copied\n" (file->string point-path)))
     (write-source shapes-copy shapes-copy-text)
     (write-source point-copy point-copy-text)
     (define (query position)
       (query-definition-at shapes-copy
                            position
                            #:document-path shapes-path))
     (check-answer (query 132) shapes-path '(8 15 132 3) shapes-copy-text)
     (check-answer (query 514) shapes-path '(8 15 132 3) shapes-copy-text)
     (check-answer (query 819) point-copy '(2 14 24 5) point-copy-text))))

(test-case "failures raise as the expression query's do"
  (for ([thunk
         (in-list
          (list (lambda () (query-definition-at 3 1))
                (lambda () (query-definition-at shapes-path 0))
                (lambda ()
                  (query-definition-at shapes-path 1 #:document-path 'x))))])
    (define failure (captured-exception thunk))
    (check-true (exn:fail:contract? failure))
    (check-true
     (string-prefix? (exn-message failure) "query-definition-at: ")))

  (call-with-temporary-directory
   (lambda (directory)
     (define failure
       (captured-exception
        (lambda ()
          (query-definition-at (build-path directory "missing.aloe") 1))))
     (check-true (exn:fail? failure))
     (check-true
      (string-contains? (exn-message failure)
                        "source path does not name a regular file"))))

  (call-with-temporary-program
   "(define-class Point\n"
   (lambda (path)
     (check-exn exn:fail:read? (lambda () (query-definition-at path 1)))))

  ;; The text read-program raises for a define-class with no name.
  (call-with-temporary-program
   "(define-class)\n"
   (lambda (path)
     (define failure
       (captured-exception (lambda () (query-definition-at path 1))))
     (check-true (exn:fail? failure))
     (check-equal?
      (exn-message failure)
      (string-append
       "parse-datum: malformed define-class; expected a name, optional "
       "protocol, fields or constructors, and methods\n"
       "  datum: '(define-class)"))))

  (define bad-source
    (string-append "(define-class Bad (fields (n Int)) (methods))\n"
                   "(define b (Bad new 1))\n"))
  (call-with-temporary-program
   bad-source
   (lambda (path)
     (for ([position (in-list '(15 58))])
       (check-answer (query-definition-at path position)
                     path
                     '(1 14 15 3)
                     bad-source))))
  (call-with-temporary-program
   (string-append bad-source "(define oops (1 + \"x\"))\n")
   (lambda (path)
     (for ([position (in-list '(15 58))])
       (define failure
         (captured-exception (lambda () (query-definition-at path position))))
       (check-true (exn:fail:aloe-type? failure))
       (check-equal? (exn-message failure)
                     "typecheck: Int + expects an Int argument")))))

(test-case "repeated queries are independent"
  (check-equal? (query-shapes 532) (query-shapes 532))
  (check-equal? (query-shapes 131) (query-shapes 131)))
