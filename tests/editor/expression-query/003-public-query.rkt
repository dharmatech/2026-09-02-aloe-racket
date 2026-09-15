#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         (prefix-in public: "../../../aloe/expression-query.rkt")
         (prefix-in catalog: "../../../aloe/signature-catalog.rkt")
         (prefix-in main: "../../../aloe/main.rkt")
         "../../../aloe/parse.rkt"
         (prefix-in type: "../../../aloe/type.rkt"))

(define-runtime-path public-module-path
  "../../../aloe/expression-query.rkt")
(define-runtime-path main-module-path "../../../aloe/main.rkt")
(define-runtime-path driver-module-path "../../../aloe/driver.rkt")
(define-runtime-path point-path "fixtures/point.aloe")
(define-runtime-path load-root-path
  "fixtures/003-public-query/root.aloe")
(define-runtime-path load-support-path
  "fixtures/003-public-query/support.aloe")

(define (normalized path)
  (simplify-path (path->complete-path path) #f))

(define (position-of source text [start 0])
  (define positions
    (regexp-match-positions (regexp (regexp-quote text)) source start))
  (unless positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar positions)))

(define (triples->specs triples)
  (for/list ([triple (in-list triples)])
    (apply public:signature-spec triple)))

(define point-t-rows
  (triples->specs
   '((x () T)
     (y () T)
     (+ ((Point T)) (Point T))
     (dist2 ((Point T)) T))))

(define point-int-rows
  (triples->specs
   '((x () Int)
     (y () Int)
     (+ ((Point Int)) (Point Int))
     (dist2 ((Point Int)) Int))))

(define int-rows
  (triples->specs
   '((+ (Int) Int)
     (- (Int) Int)
     (* (Int) Int)
     (/ (Int) Int)
     (< (Int) Bool)
     (> (Int) Bool)
     (<= (Int) Bool)
     (>= (Int) Bool)
     (= (Int) Bool)
     (float () Float)
     (text () String))))

(define list-int-rows
  (triples->specs
   '((empty? () Bool)
     (first () Int)
     (rest () (List Int))
     (cons (Int) (List Int))
     (len () Int)
     (fold (A (-> A Int A)) A)
     (reverse () (List Int))
     (map ((-> Int U)) (List U)))))

(define string-rows
  (triples->specs
   '((= (String) Bool)
     (append (String) String)
     (len () Int)
     (take (Int) String)
     (starts-with? (String) Bool))))

(define missing-export (gensym 'missing-export))

(define (module-exports? module-path name)
  (not
   (eq? (dynamic-require module-path name (lambda () missing-export))
        missing-export)))

(define (call-with-temporary-program source procedure)
  (define path
    (make-temporary-file "expression-query-003-~a" #f "/tmp"))
  (dynamic-wind
    (lambda ()
      (call-with-output-file path
        (lambda (output) (display source output))
        #:exists 'truncate))
    (lambda () (procedure path))
    (lambda ()
      (when (file-exists? path)
        (delete-file path)))))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-file
     "expression-query-003-~a" 'directory "/tmp"))
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

(define (query-source source position)
  (call-with-temporary-program
   source
   (lambda (path)
     (public:query-expression-at path position))))

(define (captured-exception thunk)
  (with-handlers ([exn:fail? values])
    (thunk)
    #f))

(test-case "public surface, structures, and shared signature identity are exact"
  (check-equal? (procedure-arity public:query-expression-at) 2)
  (define result
    (public:expression-query-result 'A '(rows) 'location))
  (check-true (public:expression-query-result? result))
  (check-equal?
   (struct->vector result)
   '#(struct:expression-query-result A (rows) location))
  (check-equal? (public:expression-query-result-type result) 'A)
  (check-equal? (public:expression-query-result-signatures result) '(rows))
  (check-equal? (public:expression-query-result-location result) 'location)

  (check-eq? public:signature-spec catalog:signature-spec)
  (check-eq? public:signature-spec? catalog:signature-spec?)
  (check-eq? public:signature-spec-selector catalog:signature-spec-selector)
  (check-eq? public:signature-spec-parameters catalog:signature-spec-parameters)
  (check-eq? public:signature-spec-return catalog:signature-spec-return)

  (for ([name (in-list
               '(select-expression-at-position
                 expression-contains-node?
                 expression-type-observation
                 expression-type-observation?
                 expression-type-observation-type
                 expression-type-observation-signatures
                 typecheck-program/observe
                 make-type-environment
                 type-of
                 typecheck-program
                 make-driver
                 driver-eval!
                 query-expression-from-string
                 query-expression-at-position))])
    (check-false (module-exports? public-module-path name)))
  (for ([module-path (in-list (list main-module-path driver-module-path))])
    (check-false
     (module-exports? module-path 'query-expression-at))))

(test-case "normative Point result includes exact rows and source location"
  (define answer
    (public:query-expression-at point-path 170))
  (check-equal? (public:expression-query-result-type answer) '(Point Int))
  (check-equal? (public:expression-query-result-signatures answer)
                point-int-rows)
  (define location (public:expression-query-result-location answer))
  (check-equal? (srcloc-source location) (normalized point-path))
  (check-equal? (srcloc-line location) 10)
  (check-equal? (srcloc-column location) 0)
  (check-equal? (srcloc-position location) 163)
  (check-equal? (srcloc-span location) 15))

(test-case "generic Point body remains rigid through the public operation"
  (define answer
    (public:query-expression-at point-path 108))
  (check-equal? (public:expression-query-result-type answer) '(Point T))
  (check-equal? (public:expression-query-result-signatures answer)
                point-t-rows)
  (check-equal?
   (srcloc-position (public:expression-query-result-location answer))
   108))

(test-case "representative source selections survive the public boundary"
  (define nested "((1 + 2) * 3)\n")
  (define atom
    (query-source nested (position-of nested "2")))
  (check-equal? (public:expression-query-result-type atom) 'Int)
  (check-equal?
   (srcloc-span (public:expression-query-result-location atom))
   1)

  (for ([position (in-list
                   (list (position-of nested "(1 + 2)")
                         (position-of nested "+")
                         (position-of nested " + ")))])
    (define inner (query-source nested position))
    (check-equal? (public:expression-query-result-type inner) 'Int)
    (check-equal?
     (srcloc-span (public:expression-query-result-location inner))
     7))

  (define let-source "(let ((x 1)) (x + 2))\n")
  (define let-answer
    (query-source let-source (position-of let-source "let")))
  (check-equal? (public:expression-query-result-type let-answer) 'Int)
  (check-equal?
   (srcloc-span (public:expression-query-result-location let-answer))
   21)

  (define gaps "1\n; top-level comment\n\n(2 + 3)\n")
  (for ([position (in-list
                   (list 2
                         (position-of gaps "top-level")
                         (add1 (string-length gaps))))])
    (check-false (query-source gaps position))))

(test-case "lexical method and function bindings are observed in context"
  (define method-source
    (string-append
     "(define-class QueryContext003\n"
     "  (fields (value Int))\n"
     "  (methods\n"
     "    (choose (other QueryContext003) QueryContext003\n"
     "      (check self other))))\n"))
  (for ([name (in-list '(self other))])
    (define answer
      (query-source method-source
                    (position-of
                     method-source
                     (symbol->string name)
                     (sub1 (position-of method-source "(check")))))
    (check-equal? (public:expression-query-result-type answer)
                  'QueryContext003))

  (define function-source "((fn (item) item) call 1)\n")
  (define function-answer
    (query-source
     function-source
     (position-of function-source "item" 10)))
  (check-equal? (public:expression-query-result-type function-answer) 'Int)
  (check-equal? (public:expression-query-result-signatures function-answer)
                int-rows))

(test-case "default List and String catalogs are complete, ordered, and fresh"
  (define list-source "(List of 1)\n")
  (define string-source "\"query\"\n")
  (define list-position (position-of list-source "of"))
  (define list-first (query-source list-source list-position))
  (define list-second (query-source list-source list-position))
  (define string-first (query-source string-source 2))
  (define string-second (query-source string-source 2))
  (check-equal? (public:expression-query-result-type list-first) '(List Int))
  (check-equal? (public:expression-query-result-signatures list-first)
                list-int-rows)
  (check-equal? (public:expression-query-result-signatures string-first)
                string-rows)
  (for ([first (in-list (list list-first string-first))]
        [second (in-list (list list-second string-second))])
    (define first-rows
      (public:expression-query-result-signatures first))
    (define second-rows
      (public:expression-query-result-signatures second))
    (check-true (list? first-rows))
    (check-equal? first-rows second-rows)
    (check-false (eq? first-rows second-rows))
    (check-equal?
     (length (remove-duplicates
              (map public:signature-spec-selector first-rows)))
     (length first-rows)))

  (define environment (main:make-type-environment))
  (define list-type (type:type-of (parse-datum '(List of 1)) environment))
  (check-equal?
   (public:expression-query-result-signatures list-first)
   (type:type-signature-specs list-type environment)))

(test-case "relative load contributes declarations without changing root locations"
  (define answer
    (public:query-expression-at
     load-root-path
     (position-of (file->string load-root-path) "new")))
  (check-equal? (public:expression-query-result-type answer) 'Loaded)
  (check-equal?
   (public:expression-query-result-signatures answer)
   (list (public:signature-spec 'value '() 'Int)))
  (define source
    (srcloc-source (public:expression-query-result-location answer)))
  (check-equal? source (normalized load-root-path))
  (check-not-equal? source (normalized load-support-path)))

(test-case "extensionless, relative string, and path requests normalize identically"
  (call-with-temporary-program
   "(1 + 2)\n"
   (lambda (path)
     (define relative
       (path->string
        (find-relative-path (current-directory) path)))
     (define indirect-relative
       (string-append "./unused-segment/../" relative))
     (define from-string
       (public:query-expression-at indirect-relative 4))
     (define from-path
       (public:query-expression-at
        (string->path indirect-relative)
        4))
     (check-equal? from-string from-path)
     (check-equal?
      (srcloc-source (public:expression-query-result-location from-string))
      (normalized path)))))

(test-case "later method rows do not retroactively change an earlier result"
  (define valid-source
    (string-append
     "\"before\"\n"
     "(define-methods String\n"
     "  (methods (later003 () String self)))\n"))
  (define answer (query-source valid-source 2))
  (check-equal? (public:expression-query-result-signatures answer)
                string-rows)

  (define invalid-source
    (string-append
     "\"before\"\n"
     "(define-methods String\n"
     "  (methods (later003 () String missing-later003)))\n"))
  (check-exn
   #rx"typecheck: unbound symbol: missing-later003"
   (lambda () (query-source invalid-source 2))))

(test-case "querying is static-only and emits no output"
  (call-with-temporary-program
   "(1 / 0)\n"
   (lambda (path)
     (define output (open-output-string))
     (define error-output (open-output-string))
     (define answer
       (parameterize ([current-output-port output]
                      [current-error-port error-output])
         (public:query-expression-at path 4)))
     (check-equal? (public:expression-query-result-type answer) 'Int)
     (check-equal? (get-output-string output) "")
     (check-equal? (get-output-string error-output) "")))
  (check-exn
   (lambda (exception)
     (and (type:exn:fail:aloe-type? exception)
          (regexp-match? #rx"typecheck: unbound symbol: term"
                         (exn-message exception))))
   (lambda () (query-source "term\n" 1))))

(test-case "arguments are validated before filesystem access"
  (for ([bad-path (in-list (list #f 17 'source '(a b)))])
    (check-exn
     #rx"query-expression-at: contract violation.*path-string\\?"
     (lambda () (public:query-expression-at bad-path 1))))
  (for ([bad-position (in-list (list 0 -1 1.0 1/2 'one))])
    (check-exn
     #rx"query-expression-at: contract violation.*exact-positive-integer\\?"
     (lambda ()
       (public:query-expression-at
        "/definitely/missing/expression-query-003"
        bad-position)))))

(test-case "missing and directory roots name the rejected path"
  (call-with-temporary-directory
   (lambda (directory)
     (define missing (build-path directory "missing-root"))
     (for ([path (in-list (list missing directory))])
       (define exception
         (captured-exception
          (lambda () (public:query-expression-at path 1))))
       (check-true (exn:fail? exception))
       (check-true
        (string-contains? (exn-message exception) (path->string path)))))))

(test-case "missing relative loads preserve the checker error"
  (call-with-temporary-directory
   (lambda (directory)
     (define root (build-path directory "root"))
     (define missing (normalized (build-path directory "missing.aloe")))
     (write-source root "(load \"missing.aloe\")\n")
     (define exception
       (captured-exception
        (lambda () (public:query-expression-at root 2))))
     (check-true (type:exn:fail:aloe-type? exception))
     (check-equal?
      (exn-message exception)
      (format "typecheck: load file not found: ~a" missing)))))

(test-case "reader and parser failures are never query misses"
  (check-exn exn:fail:read?
             (lambda () (query-source "(1 + 2\n" 2)))
  (check-exn
   #rx"combination has no selector"
   (lambda () (query-source "(1)\n" 2)))
  (define exception
    (captured-exception
     (lambda ()
       (query-source "missing-before-read003\n(1 + 2\n" 1))))
  (check-true (exn:fail:read? exception))
  (check-false (type:exn:fail:aloe-type? exception)))

(test-case "strict complete checking reports the first error and invalidates answers"
  (define first-error
    (captured-exception
     (lambda ()
       (query-source "missing-first003\nmissing-second003\n" 1))))
  (check-true (type:exn:fail:aloe-type? first-error))
  (check-equal? (exn-message first-error)
                "typecheck: unbound symbol: missing-first003")
  (check-exn
   #rx"typecheck: unbound symbol: missing-after003"
   (lambda () (query-source "1\nmissing-after003\n" 1))))

(test-case "all valid top-level gaps return false only after complete checking"
  (define valid "1\n; comment gap\n\n2\n")
  (define gap-positions
    (list 2
          (position-of valid "comment")
          (string-length valid)
          (add1 (string-length valid))))
  (for ([position (in-list gap-positions)])
    (check-false (query-source valid position)))

  (define invalid "1\n; comment gap\n\nmissing-gap003\n")
  (for ([position (in-list
                   (list 2
                         (position-of invalid "comment")))])
    (check-exn
     #rx"typecheck: unbound symbol: missing-gap003"
     (lambda () (query-source invalid position)))))

(test-case "successful and failed queries retain no checker state"
  (define definition
    (string-append
     "(define-class Isolation003\n"
     "  (fields (value Int))\n"
     "  (methods))\n"
     "(Isolation003 new 1)\n"))
  (check-equal?
   (public:expression-query-result-type
    (query-source definition (position-of definition "new")))
   'Isolation003)
  (for ([_ (in-range 2)])
    (check-exn
     #rx"typecheck: unbound symbol: Isolation003"
     (lambda () (query-source "(Isolation003 new 2)\n" 2))))

  (define failed-definition
    (string-append
     "(define-class FailedIsolation003\n"
     "  (fields (value Int))\n"
     "  (methods))\n"
     "missing-failed003\n"))
  (for ([_ (in-range 2)])
    (check-exn
     #rx"typecheck: unbound symbol: missing-failed003"
     (lambda () (query-source failed-definition 2))))
  (check-exn
   #rx"typecheck: unbound symbol: FailedIsolation003"
   (lambda () (query-source "(FailedIsolation003 new 2)\n" 2))))

(test-case "production module remains a static catalog adapter"
  (define source (file->string public-module-path))
  (for ([forbidden
         (in-list
          (list #rx"\\(signature-spec[[:space:]]"
                #rx"class-info-methods"
                #rx"eval-expr"
                #rx"eval-exprs"
                #rx"eval-source"
                #rx"make-driver"
                #rx"make-runtime-environment"
                #rx"host-receiver"
                #rx"'Point"
                #rx"'List"
                #rx"'String"))])
    (check-false (regexp-match? forbidden source))))
