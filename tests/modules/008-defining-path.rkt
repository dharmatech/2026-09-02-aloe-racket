#lang racket/base

(require racket/file
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/main.rkt"
                  exn:fail:aloe-type?
                  type->datum
                  type-of)
         (only-in "../../aloe/parse.rkt"
                  parse-datum)
         (submod "../../aloe/type.rkt" defining-path)
         "../../aloe/expression-query.rkt")

(define-runtime-path point-path "../../examples/point.aloe")
(define-runtime-path text-library-path "../../lib/text.aloe")
(define-runtime-path option-library-path "../../lib/option.aloe")
(define-runtime-path mpl-core-path "../../examples/mpl/core.aloe")
(define-runtime-path mpl-sym-path "../../examples/mpl/sym.aloe")
(define-runtime-path mpl-sum-path "../../examples/mpl/sum.aloe")
(define-runtime-path box-a-maker-path "fixtures/box-a-maker.aloe")
(define-runtime-path box-b-maker-path "fixtures/box-b-maker.aloe")
(define-runtime-path loaded-root-path
  "../editor/expression-query/fixtures/003-public-query/root.aloe")
(define-runtime-path lsp-point-path "../editor/lsp/fixtures/point.aloe")

(define (load-datum path)
  `(load ,(path->string path)))

(define (load! state path)
  (driver-eval! state (load-datum path)))

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

(define (position-of source text)
  (define positions (regexp-match-positions (regexp-quote text) source))
  (unless positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar positions)))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-directory "aloe-defining-path-~a" #:base-dir "/tmp"))
  (dynamic-wind
   void
   (lambda () (procedure directory))
   (lambda ()
     (when (directory-exists? directory)
       (delete-directory/files directory)))))

;; The plain and pathed datums of datum's type in the driver's checker.
(define (datums state datum)
  (define type (type-of (parse-datum datum) (driver-type-environment state)))
  (list (type->datum type) (type->pathed-datum type)))

;; The plain and pathed datums of the query result at text in path.
(define (hover path text)
  (define result
    (query-expression-at path (position-of (file->string path) text)))
  (list (expression-query-result-type result)
        (expression-query-result-pathed-type result)))

(define box-source "(define-class Box (fields) (methods))\n")

;; A driver that loaded the files the pathed datum table names, box.aloe
;; written to a temporary directory; procedure takes it and Box's datum.
(define (call-with-table-driver procedure)
  (call-with-temporary-directory
   (lambda (directory)
     (define box-path (build-path directory "box.aloe"))
     (call-with-output-file box-path
       (lambda (output) (write-string box-source output)))
     (define box-symbol
       (string->symbol
        (format "Box@~a"
                (path->string
                 (simplify-path (path->complete-path box-path) #f)))))
     (define state (make-driver))
     (for ([path (list point-path text-library-path mpl-core-path
                       mpl-sym-path mpl-sum-path box-path)])
       (load! state path))
     (procedure state box-symbol))))

(test-case "the pathed datum table"
  (call-with-table-driver
   (lambda (state box-symbol)
     (for ([row
            (in-list
             `(((1 + 2) Int Int)
               ((Point new 1 2) (Point Int) (Point@examples/point.aloe Int))
               ((Option Some (Position new 0 0))
                (Option Position)
                (Option@lib/option.aloe Position@lib/text.aloe))
               (Point (Class Point) (Class Point@examples/point.aloe))
               ((List of (Box new)) (List Box) (List ,box-symbol))
               (((Sum new (List of (Sym new "x")) 0) unwrap) Math Math)))])
       (check-equal? (datums state (car row)) (cdr row)
                     (format "~s" (car row)))))))

(test-case "a prompt class and an unkeyed port's class have no path"
  (call-with-table-driver
   (lambda (state _box-symbol)
     (driver-eval! state '(define-class Here (fields) (methods)))
     (check-equal? (datums state '(Here new)) '(Here Here))
     (driver-load-port!
      state
      (open-input-string "(define-class Ported (fields) (methods))")
      (open-output-string))
     (check-equal? (datums state '(Ported new)) '(Ported Ported)))))

(test-case "two Box classes"
  (define state (make-driver))
  (check-equal? (raised (lambda () (load! state box-a-maker-path)))
                'no-error)
  (check-equal? (raised (lambda () (load! state box-b-maker-path)))
                'no-error)
  (check-equal?
   (raised (lambda () (driver-eval! state '(check a-box b-box))))
   (list #t
         (string-append
          "typecheck: type mismatch: expected Box, got Box "
          "(Box@tests/modules/fixtures/box-a.aloe"
          " vs Box@tests/modules/fixtures/box-b.aloe)"))))

(test-case "the (Option Position) mismatches"
  (define state (make-driver))
  (load! state text-library-path)
  (driver-eval! state '(define op (Option Some (Position new 0 0))))
  (driver-eval! state '(define oi (Option Some 1)))
  (driver-eval!
   state
   '(define-class OptHolder (fields (held (Option Position))) (methods)))
  (check-equal?
   (raised (lambda ()
             (driver-eval! state '((OptHolder new op) with (held oi)))))
   (list #t
         (string-append
          "typecheck: type mismatch for with field held: "
          "expected (Option Position), got (Option Int) "
          "((Option@lib/option.aloe Position@lib/text.aloe)"
          " vs (Option@lib/option.aloe Int))")))
  (check-equal?
   (raised (lambda () (driver-eval! state '(check op oi))))
   (list #t
         (string-append
          "typecheck: type mismatch: expected Position, got Int "
          "(Position@lib/text.aloe vs Int)"))))

(test-case "hover on a nested-loaded class, and on a kernel type"
  (check-equal?
   (hover loaded-root-path "(Loaded new 7)")
   '(Loaded
     Loaded@tests/editor/expression-query/fixtures/003-public-query/support.aloe))
  (check-equal? (hover loaded-root-path "7") '(Int Int)))

(test-case "hover on a class the buffer defines"
  (check-equal?
   (hover lsp-point-path "(Point new 1 2)")
   '((Point Int) (Point@tests/editor/lsp/fixtures/point.aloe Int))))

(test-case "hover inside a dirty lib/text.aloe, through a sibling"
  (call-with-temporary-directory
   (lambda (directory)
     (define sibling (build-path directory "text-buffer"))
     (define original (file->string text-library-path))
     (define option-load "(load \"option.aloe\")")
     (check-true (string-contains? original option-load))
     (define probe "(define probe-008 (Position new 0 0))")
     (define buffer
       (string-append
        (string-replace original
                        option-load
                        (format "(load ~s)" (path->string option-library-path))
                        #:all? #f)
        "\n"
        probe
        "\n"))
     (call-with-output-file sibling
       (lambda (output) (write-string buffer output)))
     (define position
       (+ (position-of buffer probe) (string-length "(define probe-008 ")))
     (define result
       (query-expression-at sibling position
                            #:document-path text-library-path))
     (check-equal? (expression-query-result-type result) 'Position)
     (define pathed (expression-query-result-pathed-type result))
     (check-equal? pathed 'Position@lib/text.aloe)
     (check-false (string-contains? (format "~s" pathed)
                                    (path->string directory))))))

(test-case "hover inside lib/option.aloe"
  (define source (file->string option-library-path))
  (define result
    (query-expression-at option-library-path
                         (add1 (position-of source "(self case"))))
  (check-equal? (expression-query-result-type result) '(Option T))
  (check-equal? (expression-query-result-pathed-type result)
                '(Option@lib/option.aloe T)))
