#lang racket/base

;; modules 001: every census file loads each file whose names it uses.
;; Under run-once inclusion a missing load still typechecks, so this test
;; is what sees one until file environments land. It walks parsed source;
;; the language gains no checker that walks identifiers.

(require racket/list
         racket/match
         racket/path
         racket/runtime-path
         rackunit
         "../../aloe/parse.rkt")

(define-runtime-path project-root-path "../..")

(define project-root (simplify-path (path->complete-path project-root-path)))

(define (project-path relative)
  (simplify-path (build-path project-root relative)))

(define (relative-string path)
  (path->string (find-relative-path project-root (simplify-path path))))

;; ---------------------------------------------------------------------------
;; The census files

(define census-directories '("examples" "lib" "gel" "tests"))

;; tests/editor/source-locations/000-spans.rkt only parses this fixture for
;; source locations; nothing loads or checks it, and it uses `Point` and `p`
;; on purpose. It is not a census file.
(define excluded-census-files
  (list (project-path "tests/editor/source-locations/fixtures/000-spans.aloe")))

(define (aloe-file? path)
  (and (file-exists? path)
       (equal? (path-get-extension path) #".aloe")))

(define census-files
  (sort
   (for*/list ([directory (in-list census-directories)]
               [path (in-directory (project-path directory))]
               #:when (aloe-file? path)
               #:unless (member (simplify-path path) excluded-census-files))
     (simplify-path path))
   string<?
   #:key path->string))

;; ---------------------------------------------------------------------------
;; Free names

;; On the base in every environment.
(define base-names '(dummy List Int String Symbol Mirror term fs-host))

;; `Option` is not counted in this layer: slice 3a installs lib/option.aloe
;; on the base, and every file already reaches it through that library.
(define uncounted-names '(Option))

(define kernel-type-names '(-> Int Float Bool String Symbol Mirror Signature))

;; Type parameters of the built-in classes that `define-methods` can extend.
(define kernel-class-type-parameters
  (hash 'List '(T) 'Int '() 'String '()))

(define (read-file-program path)
  (call-with-input-file path
    (lambda (input) (read-program input #:source-path path))))

(define (own-definitions program)
  (for/list ([expression (in-list program)]
             #:when (or (define-expr? expression)
                        (define-class-expr? expression)
                        (define-protocol-expr? expression)))
    (match expression
      [(define-expr name _ _) name]
      [(define-class-expr name _ _ _ _ _ _) name]
      [(define-protocol-expr name _ _) name])))

(define (direct-load-paths program)
  (for/list ([expression (in-list program)]
             #:when (load-expr? expression))
    (load-expr-resolved-path expression)))

(define (class-type-parameters programs target)
  (or (for*/first ([program (in-list programs)]
                   [expression (in-list program)]
                   #:when (and (define-class-expr? expression)
                               (eq? (define-class-expr-name expression)
                                    target)))
        (define-class-expr-type-parameters expression))
      (hash-ref kernel-class-type-parameters target '())))

;; A type is a symbol, or a list whose every element, head included, is
;; walked.
(define (type-references type type-parameters)
  (cond
    [(symbol? type)
     (if (or (memq type kernel-type-names)
             (memq type type-parameters))
         '()
         (list type))]
    [(list? type)
     (append-map (lambda (part) (type-references part type-parameters))
                 type)]
    [else
     (raise-argument-error 'type-references "Aloe type datum" type)]))

(define (method-references method type-parameters target-parameters)
  (match method
    [(method-declaration _ method-type-parameters parameters return-type body)
     (define in-scope (append method-type-parameters type-parameters))
     (append
      (append-map (lambda (parameter)
                    (type-references (parameter-declaration-type parameter)
                                     in-scope))
                  parameters)
      (type-references return-type in-scope)
      (if body
          (expression-references
           body
           (cons 'self (map parameter-declaration-name parameters))
           target-parameters)
          '()))]))

(define (field-references fields type-parameters)
  (append-map (lambda (field)
                (type-references (field-declaration-type field)
                                 type-parameters))
              (or fields '())))

;; `bound` holds the names an enclosing binder binds. `target-parameters`
;; maps a `define-methods` target to its class's type parameters.
(define (expression-references expression bound target-parameters)
  (define (walk expression)
    (expression-references expression bound target-parameters))
  (define (walk-under names expression)
    (expression-references expression (append names bound) target-parameters))
  (match expression
    [(variable-expr name _)
     (if (memq name bound) '() (list name))]
    [(or (? int-expr?) (? float-expr?) (? bool-expr?) (? string-expr?)
         (? load-expr?))
     '()]
    [(check-expr left right _ _ _)
     (append (walk left) (walk right))]
    [(define-expr _ value _)
     (walk value)]
    [(fn-expr parameters body _)
     (walk-under parameters body)]
    [(send-expr receiver _ arguments _ _)
     (append (walk receiver) (append-map walk arguments))]
    [(case-expr scrutinee clauses else-body _)
     (append
      (walk scrutinee)
      (append-map (lambda (clause)
                    (walk-under (case-clause-payload-names clause)
                                (case-clause-body clause)))
                  clauses)
      (if else-body (walk else-body) '()))]
    [(or (new-star-expr receiver bindings _)
         (with-expr receiver bindings _))
     (append (walk receiver)
             (append-map (lambda (binding)
                           (walk (construction-binding-value binding)))
                         bindings))]
    [(define-class-expr _ type-parameters protocol fields constructors methods _)
     (append
      (if protocol (list protocol) '())
      (field-references fields type-parameters)
      (append-map (lambda (constructor)
                    (field-references
                     (constructor-declaration-fields constructor)
                     type-parameters))
                  (or constructors '()))
      (append-map (lambda (method)
                    (method-references method type-parameters target-parameters))
                  methods))]
    [(define-protocol-expr _ signatures _)
     (append-map (lambda (signature)
                   (method-references signature '() target-parameters))
                 signatures)]
    [(define-methods-expr target methods _)
     (define type-parameters (target-parameters target))
     (cons target
           (append-map (lambda (method)
                         (method-references method
                                            type-parameters
                                            target-parameters))
                       methods))]
    [_
     (raise-argument-error 'expression-references "Aloe expression"
                           expression)]))

(define (free-names program)
  (define loaded-programs
    (map read-file-program (direct-load-paths program)))
  (define (target-parameters target)
    (class-type-parameters (cons program loaded-programs) target))
  (define references
    (append-map (lambda (expression)
                  (expression-references expression '() target-parameters))
                program))
  (define known
    (append (own-definitions program)
            base-names
            uncounted-names
            (append-map own-definitions loaded-programs)))
  (sort (remove-duplicates
         (filter (lambda (name) (not (memq name known))) references))
        symbol<?))

(define (free-names-of-source source #:source-path [source-path #f])
  (free-names (read-program source #:source-path source-path)))

(define (free-names-of-file path)
  (free-names (read-file-program path)))

;; ---------------------------------------------------------------------------
;; 1. Every census file has no free names.

(test-case "the excluded census file exists"
  (for ([path (in-list excluded-census-files)])
    (check-true (file-exists? path) (relative-string path))))

(for ([path (in-list census-files)])
  (define name (relative-string path))
  (test-case (format "census: ~a" name)
    (define names (free-names-of-file path))
    (check-equal? names
                  '()
                  (format "~a uses names it neither defines nor loads: ~a"
                          name
                          names))))

;; ---------------------------------------------------------------------------
;; 2. The walker sees names.

(define walker-cases
  '(("(define-class A (fields (b B)) (methods))"
     (B))
    ("(define f (fn (x) (x foo y)))"
     (y))
    ("(define-class (C T) (fields (v T)) (methods (get () T (self v))))"
     ())
    ("(define-methods List (methods (twice () (List T) (self append self))))"
     ())
    ("(define g (fn (o) (o case (Some (v) (v + z)) (None () 0))))"
     (z))
    ("(define h (Point new* (x 1) (y q)))"
     (Point q))
    ("(define w (p with (x r)))"
     (p r))
    ("(define k (let ((n 1)) (n + m)))"
     (m))
    ("(define-protocol P (m (other Q) R))"
     (Q R))
    ("(define-methods Foo (methods (pick (type A) (a A) A a)))"
     (Foo))
    ("(define-class D Proto (fields) (methods))"
     (Proto))
    ("(define-class K (fields (a Int) (b Float) (c Bool) (d String) (e Symbol) (f Mirror) (g Signature) (h (-> Int Bool))) (methods))"
     ())
    ("(define o (Option Some 1))"
     ())
    ("(define t term)"
     ())
    ("(define u fs-host)"
     ())))

(test-case "the walker sees names"
  (for ([walker-case (in-list walker-cases)])
    (define source (first walker-case))
    (check-equal? (free-names-of-source source)
                  (second walker-case)
                  source)))

(test-case "a direct load supplies only the loaded file's own definitions"
  ;; AloemacsBuffer is file.aloe's own definition. AloemacsEditor is
  ;; editor.aloe's, which file.aloe only loads.
  (check-equal?
   (free-names-of-source
    "(load \"file.aloe\") (define e AloemacsEditor) (define b AloemacsBuffer)"
    #:source-path (project-path "examples/aloemacs/census-probe.aloe"))
   '(AloemacsEditor)))

;; ---------------------------------------------------------------------------
;; 3. The leading loads.

(define expected-leading-loads
  '(("examples/aloemacs/file.aloe"
     "editor.aloe" "../../lib/text.aloe" "../../lib/fs.aloe")
    ("examples/aloemacs/main.aloe"
     "file.aloe" "editor.aloe" "../../lib/text.aloe" "../../lib/fs.aloe")
    ("gel/loop.aloe" "stack.aloe" "menu.aloe")
    ("gel/main.aloe" "loop.aloe" "stack.aloe")
    ("examples/mpl/core.aloe"
     "math.aloe" "sym.aloe" "sum.aloe" "num.aloe" "prod.aloe" "pow.aloe")
    ("examples/mpl/sym.aloe" "math.aloe")
    ("examples/mpl/sum.aloe" "math.aloe")
    ("examples/mpl/num.aloe" "math.aloe")
    ("examples/mpl/prod.aloe" "math.aloe" "num.aloe")
    ("examples/mpl/pow.aloe" "math.aloe" "num.aloe")
    ("examples/mpl/identities.aloe" "core.aloe" "sym.aloe")
    ("tests/modules/fixtures/keymap-user.aloe" "command.aloe" "keymap.aloe")))

(define (read-datums path)
  (call-with-input-file path
    (lambda (input)
      (for/list ([datum (in-port read input)]) datum))))

(define (load-datum? datum)
  (and (pair? datum) (eq? (car datum) 'load)))

(test-case "each edited file's leading datums are exactly its loads"
  (for ([row (in-list expected-leading-loads)])
    (define relative (first row))
    (define loads (map (lambda (path) `(load ,path)) (rest row)))
    (define path (project-path relative))
    (check-not-false (member path census-files) relative)
    (define datums (read-datums path))
    (check-true (>= (length datums) (length loads)) relative)
    (check-equal? (take datums (length loads)) loads relative)
    (define after (drop datums (length loads)))
    (check-false (and (pair? after) (load-datum? (first after)))
                 (format "~a: a load follows the expected loads" relative))))

;; ---------------------------------------------------------------------------
;; 4. The Math file.

(test-case "Math lives in math.aloe and core.aloe defines no protocol"
  (define math-datums (read-datums (project-path "examples/mpl/math.aloe")))
  (check-equal? (length math-datums) 1)
  (match (first math-datums)
    [(list 'define-protocol name signatures ...)
     (check-equal? name 'Math)
     (check-equal? (length signatures) 11)]
    [datum
     (fail (format "math.aloe holds ~s, not a define-protocol" datum))])
  (check-false
   (for/or ([datum (in-list (read-datums (project-path "examples/mpl/core.aloe")))])
     (and (pair? datum) (eq? (car datum) 'define-protocol)))))
