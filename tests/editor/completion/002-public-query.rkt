#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         (prefix-in public: "../../../aloe/completion-query.rkt"))

(define-runtime-path public-path "../../../aloe/completion-query.rkt")
(define-runtime-path main-path "../../../aloe/main.rkt")
(define-runtime-path driver-path "../../../aloe/driver.rkt")
(define-runtime-path point-path "../../../examples/point.aloe")
(define-runtime-path boids-path "../../../examples/boids.aloe")

(define point-source (file->string point-path))
(define boids-source (file->string boids-path))

(define missing-export (gensym 'missing-export))

(define (module-exports? module-path name)
  (not (eq? (dynamic-require module-path name (lambda () missing-export))
            missing-export)))

(define (phase-zero-export-names exports)
  (map car (cdr (assq 0 exports))))

(define (datum-text datum)
  (call-with-output-string
   (lambda (output) (write datum output))))

(define (triples->items triples start span)
  (for/list ([triple (in-list triples)])
    (match-define (list selector parameters return) triple)
    (define label (datum-text selector))
    (public:selector-completion-item
     label
     (string-append (datum-text parameters)
                    " -> "
                    (datum-text return))
     label
     start
     span)))

(define point-int-triples
  '((x () Int)
    (y () Int)
    (+ ((Point Int)) (Point Int))
    (- ((Point Int)) (Point Int))
    (dist2 ((Point Int)) Int)
    (dot ((Point Int)) Int)
    (* (Int) (Point Int))
    (/ (Int) (Point Int))))

(define point-float-triples
  '((x () Float)
    (y () Float)
    (+ ((Point Float)) (Point Float))
    (- ((Point Float)) (Point Float))
    (dist2 ((Point Float)) Float)
    (dot ((Point Float)) Float)
    (* (Float) (Point Float))
    (/ (Float) (Point Float))))

(define int-triples
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
    (text () String)))

(define list-int-triples
  '((empty? () Bool)
    (first () Int)
    (rest () (List Int))
    (cons (Int) (List Int))
    (len () Int)
    (fold (A (-> A Int A)) A)
    (reverse () (List Int))
    (map ((-> Int U)) (List U))))

(define string-triples
  '((= (String) Bool)
    (append (String) String)
    (len () Int)
    (take (Int) String)
    (starts-with? (String) Bool)))

(define boid-triples
  '((position () (Point Float))
    (velocity () (Point Float))
    (in-view? (Boid) Bool)
    (neighbors ((List Boid) Float) (List Boid))
    (cohere ((List Boid)) (Point Float))
    (align ((List Boid)) (Point Float))
    (separate ((List Boid)) (Point Float))
    (advance ((Point Float)) Boid)))

(define (remove-cursor marked-source)
  (define positions (regexp-match-positions* #rx"\\|" marked-source))
  (unless (= (length positions) 1)
    (error 'remove-cursor
           "expected exactly one display-only cursor: ~e"
           marked-source))
  (define index (caar positions))
  (values (string-append (substring marked-source 0 index)
                         (substring marked-source (add1 index)))
          (add1 index)))

(define (query-marked marked-source #:source-path [source-path #f])
  (define-values (source position) (remove-cursor marked-source))
  (values source
          position
          (public:query-selector-completions
           source position #:source-path source-path)))

(define (query-marked/result marked-source #:source-path [source-path #f])
  (define-values (_source _position result)
    (query-marked marked-source #:source-path source-path))
  result)

(define (point-query marked-tail)
  (query-marked/result
   (string-append point-source "\n" marked-tail)
   #:source-path point-path))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-file "completion-query-002-~a" 'directory "/tmp"))
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

(test-case "public surface and arities are exact"
  (define sample
    (public:selector-completion-item "label" "detail" "insert" 4 5))
  (check-true (public:selector-completion-item? sample))
  (check-equal? (procedure-arity public:selector-completion-item) 5)
  (check-equal?
   (struct->vector sample)
   '#(struct:selector-completion-item "label" "detail" "insert" 4 5))
  (check-equal? (procedure-arity public:query-selector-completions) 2)
  (define-values (required-keywords allowed-keywords)
    (procedure-keywords public:query-selector-completions))
  (check-equal? required-keywords '())
  (check-equal? allowed-keywords '(#:source-path))

  (dynamic-require public-path #f)
  (define-values (value-exports syntax-exports)
    (module->exports public-path))
  (check-equal?
   (phase-zero-export-names value-exports)
   '(selector-completion-item-detail
     selector-completion-item-insert-text
     selector-completion-item-label
     selector-completion-item-replacement-span
     selector-completion-item-replacement-start
     selector-completion-item?
     struct:selector-completion-item))
  (check-equal?
   (phase-zero-export-names syntax-exports)
   '(query-selector-completions selector-completion-item))

  (for ([name (in-list
               '(signature-spec
                 signature-spec?
                 selector-completion-site
                 selector-receiver-observation
                 recover-selector-completion-site
                 typecheck-program/observe-selector-receiver
                 make-type-environment
                 read-program
                 query-expression-at))])
    (check-false (module-exports? public-path name)))
  (for ([module-path (in-list (list main-path driver-path))])
    (check-false
     (module-exports? module-path 'query-selector-completions))))

(test-case "public arguments are checked before source failure recovery"
  (for ([thunk (in-list
                (list
                 (lambda () (public:query-selector-completions 17 1))
                 (lambda () (public:query-selector-completions "" 0))
                 (lambda () (public:query-selector-completions "" 1.0))
                 (lambda ()
                   (public:query-selector-completions
                    "" 1 #:source-path 17))))])
    (check-exn #rx"^query-selector-completions:" thunk))
  (check-equal? (public:query-selector-completions "" 2) '())
  (check-equal?
   (public:query-selector-completions
    "" 2 #:source-path "definitely/missing/root.aloe")
   '()))

(test-case "relative string and path roots normalize for ordinary loads"
  (call-with-temporary-directory
   (lambda (directory)
     (define support-path (build-path directory "support.aloe"))
     (write-source
      support-path
      (string-append
       "(define-class Loaded002\n"
       "  (fields (value Int))\n"
       "  (methods))\n"))
     (define marked-source
       "(load \"support.aloe\")\n((Loaded002 new 1) v|)")
     (define expected (triples->items '((value () Int)) 42 1))
     (parameterize ([current-directory directory])
       (for ([relative-root
              (in-list (list "sub/../unsaved-buffer.aloe"
                             (string->path
                              "sub/../unsaved-buffer.aloe")))])
         (define root
           (simplify-path
            (path->complete-path relative-root) #f))
         (check-false (file-exists? root))
         (check-equal?
          (query-marked/result
           marked-source #:source-path relative-root)
          expected)
         (check-false (file-exists? root)))))))

(test-case "loads require a source path and respect the receiver boundary"
  (for ([marked-source
         (in-list
          (list
           (string-append
            "(load \"examples/point.aloe\")\n"
            "((Point new 1.0 2.0) d|)")
           (string-append
            point-source
            "\n((Point new 1.0 2.0) d|)\n"
            "(load \"examples/point.aloe\")")))])
    (check-equal? (query-marked/result marked-source) '()))

  (call-with-temporary-directory
   (lambda (directory)
     (define root (build-path directory "buffer.aloe"))
     (define malformed-load (build-path directory "malformed.aloe"))
     (write-source malformed-load "(define broken)")
     (check-equal?
      (query-marked/result
       "(load \"missing.aloe\")\n(1 +| 2)"
       #:source-path root)
      '())
     (check-equal?
      (query-marked/result
       "(load \"malformed.aloe\")\n(1 +| 2)"
       #:source-path root)
      '())
     (check-equal?
      (query-marked/result
       "(1 +| 2)\n(load \"missing.aloe\")"
       #:source-path root)
      (triples->items int-triples 4 1)))))

(test-case "Point Int exact selector returns the complete ordered catalog"
  (check-equal?
   (point-query "((Point new 1 2) |+ (Point new 3 4))")
   (triples->items point-int-triples 740 1)))

(test-case "Point Float exact, partial, interior, empty, and argument cases"
  (define all-float (triples->items point-float-triples 744 5))
  (for ([marked-tail
         (in-list
          '("((Point new 1.0 2.0) |dist2 (Point new 0.0 0.0))"
            "((Point new 1.0 2.0) di|st2 (Point new 0.0 0.0))"
            "((Point new 1.0 2.0) dist2| (Point new 0.0 0.0))"))])
    (check-equal? (point-query marked-tail) all-float))

  (check-equal?
   (point-query "((Point new 1.0 2.0) d|")
   (triples->items
    '((dist2 ((Point Float)) Float)
      (dot ((Point Float)) Float))
    744 1))
  (check-equal?
   (point-query "((Point new 1.0 2.0) dist|")
   (triples->items '((dist2 ((Point Float)) Float)) 744 4))
  (check-equal? (point-query "((Point new 1.0 2.0) z|") '())
  (check-equal? (point-query "((Point new 1.0 2.0) d|ist") '())
  (check-equal?
   (point-query "((Point new 1.0 2.0) |")
   (triples->items point-float-triples 744 0))
  (check-equal?
   (point-query
    "((Point new 1.0 2.0) di|st2 (Point new 0.0 0.0))")
   all-float)
  (for ([answer
         (in-list
          (list (point-query "((Point new 1.0 2.0) d|")
                (point-query "((Point new 1.0 2.0) dist|")))])
    (for ([item (in-list answer)])
      (check-equal? (public:selector-completion-item-insert-text item)
                    (public:selector-completion-item-label item)))))

(test-case "Boids fixed positions return the normative catalogs and ranges"
  (check-equal?
   (public:query-selector-completions
    boids-source 515 #:source-path boids-path)
   (triples->items point-float-triples 515 5))
  (check-equal?
   (public:query-selector-completions
    boids-source 2261 #:source-path boids-path)
   (triples->items boid-triples 2261 9)))

(test-case "standard List and String extension rows are ordered and fresh"
  (define list-source "((List of 1) empty?)")
  (define string-source "(\"text\" len)")
  (define list-first
    (public:query-selector-completions list-source 14))
  (define list-second
    (public:query-selector-completions list-source 14))
  (check-equal? list-first (triples->items list-int-triples 14 6))
  (check-equal? list-first list-second)
  (check-false (eq? list-first list-second))
  (check-equal?
   (public:query-selector-completions string-source 9)
   (triples->items string-triples 9 3)))

(test-case "function and class-object receivers obey ordinary send rules"
  (define function-source "((fn (x) (x + 1)) call 2)")
  (check-equal?
   (public:query-selector-completions function-source 22)
   (triples->items '((call (Int) Int)) 19 4))
  (check-equal?
   (point-query "(Point |")
   (triples->items '((new (T T) (Point T))) 730 0))
  (define ordinary-send
    "(define f (fn (x) (x + 1)))\n(f x)")
  (check-equal?
   (public:query-selector-completions ordinary-send 36)
   '()))

(test-case "method, function, let, case, and rigid generic contexts survive"
  (define class-source
    (string-append
     "(define-class Context002\n"
     "  (fields (value Int))\n"
     "  (methods\n"
     "    (from-self () Int (self v|alue))\n"
     "    (from-param (other Context002) Int (other value))))"))
  (define-values (_self-source self-position self-answer)
    (query-marked class-source))
  (check-equal?
   self-answer
   (triples->items
    '((value () Int)
      (from-self () Int)
      (from-param (Context002) Int))
    (sub1 self-position)
    5))
  (define parameter-source
    (string-replace class-source "(self v|alue)" "(self value)"))
  (define parameter-marked
    (string-replace parameter-source "(other value)" "(other v|alue)"))
  (define-values (_parameter-source parameter-position parameter-answer)
    (query-marked parameter-marked))
  (check-equal?
   parameter-answer
   (triples->items
    '((value () Int)
      (from-self () Int)
      (from-param (Context002) Int))
    (sub1 parameter-position)
    5))

  (define-values (_function-source function-position function-answer)
    (query-marked "((fn (x) (x +| 1)) call 1)"))
  (check-equal?
   function-answer
   (triples->items int-triples (sub1 function-position) 1))
  (check-equal?
   (query-marked/result "(let ((x \"text\")) (x l|))")
   (triples->items '((len () Int)) 22 1))

  (define case-source
    (string-append
     "(define-class (Option002 T)\n"
     "  (constructors\n"
     "    (None (fields))\n"
     "    (Some (fields (value T))))\n"
     "  (methods))\n"
     "((Option002 Some 1) case\n"
     "  (Some (payload) (payload f|))\n"
     "  (None () missing-later-body))"))
  (define-values (_case-source case-position case-answer)
    (query-marked case-source))
  (check-equal?
   case-answer
   (triples->items '((float () Float)) (sub1 case-position) 1))

  (define rigid-source
    (string-append
     "(define-class (Rigid002 T)\n"
     "  (fields (value T))\n"
     "  (methods\n"
     "    (adapt (type U) (item U) U item)\n"
     "    (rows (type U) (item U) T (self v|alue))))"))
  (define-values (_rigid-source rigid-position rigid-answer)
    (query-marked rigid-source))
  (check-equal?
   rigid-answer
   (triples->items
    '((value () T)
      (adapt (U) U)
      (rows (U) T))
    (sub1 rigid-position)
    5)))

(test-case "earlier rows, overload multiplicity, escaping, and later boundary"
  (define marked-source
    (string-append
     "(define-methods String\n"
     "  (methods\n"
     "    (repeat002 (n Int) String self)\n"
     "    (repeat002 (s String) String self)\n"
     "    (|two words| () String self)))\n"
     "(\"receiver\" |two words|)\n"
     "(define-methods String\n"
     "  (methods (later002 () String self)))"))
  (define selector-start
    (add1
     (car
      (last
       (regexp-match-positions* #rx"[|]two words[|]" marked-source)))))
  (check-equal?
   (public:query-selector-completions marked-source selector-start)
   (triples->items
    (append string-triples
            '((repeat002 (Int) String)
              (repeat002 (String) String)
              (|two words| () String)))
    selector-start
    11)))

(test-case "ineligible and unrecoverable sites collapse to the empty list"
  (for ([marked-source
         (in-list
          '("|"
            "1\n|2"
            "na|me"
            "; comm|ent\n(1 + 2)"
            "(\"te|xt\" len)"
            "(def|ine x 1)"
            "(|1 + 2)"
            "(1 + |2)"
            "(1 + 2)|"
            "(1 d| \"unfinished"
            "[1 d|)"
            "(1 d|)\n(define broken)"))])
    (check-equal? (query-marked/result marked-source) '()))
  (define too-deep
    (string-append
     (apply string-append (make-list 64 "(outer selector "))
     "(1 |"))
  (check-equal? (query-marked/result too-deep) '()))

(test-case "checker and load failures are prompt, silent, and indistinguishable"
  (define output (open-output-string))
  (define errors (open-output-string))
  (parameterize ([current-output-port output]
                 [current-error-port errors])
    (for ([marked-source
           (in-list
            '("(String p|)"
              "(1 z|)"
              "(missing-receiver p|)"
              "(\"bad\" + 1)\n(1 p|)"
              "(term p|)"))])
      (check-eq? (query-marked/result marked-source) '())))
  (check-equal? (get-output-string output) "")
  (check-equal? (get-output-string errors) ""))

(test-case "queries are static and calls retain no declarations"
  (define static-source
    (string-append
     point-source
     "\n((Point new (1 / 0) 2) |)"))
  (define-values (_static-source static-position static-answer)
    (query-marked static-source #:source-path point-path))
  (check-equal?
   static-answer
   (triples->items point-int-triples static-position 0))

  (define declaration-query
    (query-marked/result
     (string-append
      "(define-class Leaky002 (fields (value Int)) (methods))\n"
      "((Leaky002 new 1) v|)")))
  (check-equal?
   declaration-query
   (triples->items '((value () Int)) 74 1))
  (check-equal? (query-marked/result "((Leaky002 new 1) v|)") '())

  (define extension-query
    (query-marked/result
     (string-append
      "(define-methods String (methods (leaky002 () String self)))\n"
      "(\"x\" leaky002|)")))
  (check-equal?
   (map public:selector-completion-item-label extension-query)
   '("=" "append" "len" "take" "starts-with?" "leaky002"))
  (check-equal? (query-marked/result "(\"x\" leaky002|)") '())
  (check-equal? (query-marked/result "(missing-before p|)") '())
  (check-equal?
   (query-marked/result "(\"x\" starts-with?|)")
   (triples->items string-triples 6 12))
  (check-equal? (file->string point-path) point-source)
  (check-equal? (file->string boids-path) boids-source))

(test-case "production remains a narrow static composition"
  (define source (file->string public-path))
  (for ([forbidden
         (in-list
          '("query-expression-at"
            "type-signature-specs"
            "read-program"
            "type-of"
            "typecheck-program\n"
            "class-info-methods"
            "class-info-fields"
            "eval-expression"
            "Mirror"
            "Point"
            "Boid"
            "fold"
            "map"
            "reverse"
            "starts-with?"
            "sort"
            "remove-duplicates"
            "snippet"
            "textDocument/completion"
            "CompletionItem"))])
    (check-false (string-contains? source forbidden)))
  (check-equal?
   (length
    (regexp-match* #rx"recover-selector-completion-site" source))
   2)
  (check-equal?
   (length (regexp-match* #rx"make-type-environment" source))
   2)
  (check-equal?
   (length
    (regexp-match* #rx"typecheck-program/observe-selector-receiver" source))
   2))
