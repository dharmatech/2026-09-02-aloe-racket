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
        'Option (list option-path '(1 15 16 6))))

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
    (make-temporary-file "definition-002-~a"
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

;; Checks each (position answer) row of source in a temporary file. An answer
;; is #f or the (line column position span) of a jump within that file.
(define (check-temporary-program source rows)
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "program.aloe"))
     (write-source path source)
     (for ([row (in-list rows)])
       (define-values (position answer) (apply values row))
       (define result (query-definition-at path position))
       (if answer
           (check-answer result path answer source)
           (check-false result (format "position ~a" position)))))))

(define text-a
  (string-append
   "(define-class Pt (fields (x Int)) (methods))\n"
   "(define-class Q (fields (p (Pt Pt)) (r (Pt Nope))) (methods))\n"))

(define text-b
  (string-append
   "(define-class T (fields (n Int)) (methods))\n"
   "(define-class (Wrap T) (fields (v T)) (methods))\n"
   "(define-class Plain (fields (t T)) (methods (id (type T) (x T) T x)))\n"))

(define text-c
  (string-append "(define-methods String\n"
                 "  (methods\n"
                 "    (shout () String self)))\n"))

(define text-d
  (string-append
   "(define-class (Pair A B) (fields (a A) (b B)) (methods))\n"
   "(define-class Pt (fields (x Int)) (methods))\n"
   "(define-class U (fields (p (Pair Pt (List Pt)))) (methods))\n"))

(define text-e
  (string-append
   "(define-class Pt (fields (x Int)) (methods))\n"
   "(define-methods List (methods (firsts () (List T) self) "
   "(pts (p Pt) (List Pt) (List empty))))\n"))

(define text-f
  (string-append "(define-class Pt (fields (x Int)) (methods))\n"
                 "(define-class Q (fields (p Pt)) (methods))\n"))

(test-case "type symbols in annotations jump"
  (for ([row (in-list
              '((5 13 100 Point)
                (5 20 107 Point)
                (10 12 173 Point)
                (11 12 192 Option)
                (11 19 199 Point)
                (13 14 233 Point)
                (18 24 333 Point)
                (21 15 410 Point)
                (26 30 499 Box)
                (28 21 568 Point)
                (41 18 747 Box)
                (41 22 751 Point)
                (42 19 779 Point)))])
    (define-values (line column position target) (apply values row))
    (check-shapes-cursor line column position)
    (check-jump (query-shapes position) target)))

(test-case "a type symbol answers from its first character through its last"
  (define option (query-shapes 192))
  (check-jump option 'Option)
  (for ([position (in-range 192 198)])
    (check-equal? (query-shapes position) option))
  (check-false (query-shapes 198)))

(test-case "type symbols that resolve to no class by its name answer #f"
  (for ([position (in-list '(158 495 503 561 646 726 741 772 775))])
    (check-false (query-shapes position) (format "position ~a" position)))
  (check-false (query-definition-at point-path 38)))

(test-case "the arguments of a non-generic head are not read"
  (check-temporary-program
   text-a
   '((74 (1 14 15 2))
     (77 #f)
     (89 #f))))

(test-case "a type parameter in scope shadows a class of its name"
  (check-temporary-program
   text-b
   '((79 #f)
     (125 (1 14 15 1))
     (154 #f)
     (157 #f))))

(test-case "a kernel return type does not jump"
  (check-temporary-program text-c '((49 #f))))

(test-case "a generic head and its arguments jump"
  (check-temporary-program
   text-d
   '((131 (1 15 16 4))
     (136 (2 14 72 2))
     (145 (2 14 72 2)))))

(test-case "define-methods List resolves T and its parameter types"
  (check-temporary-program
   text-e
   '((93 #f)
     (110 (1 14 15 2)))))

(test-case "a type symbol jumps only when the complete file checks"
  (check-temporary-program text-f '((73 (1 14 15 2))))
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "program.aloe"))
     (write-source path (string-append text-f "(define oops (1 + \"x\"))\n"))
     (define failure
       (with-handlers ([exn:fail? values])
         (query-definition-at path 73)
         #f))
     (check-true (exn:fail:aloe-type? failure))
     (check-equal? (exn-message failure)
                   "typecheck: Int + expects an Int argument"))))
