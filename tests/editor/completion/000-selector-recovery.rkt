#lang racket/base

(require rackunit
         racket/list
         racket/path
         racket/string
         "../../../aloe/parse.rkt"
         "../../../aloe/private/completion-selection.rkt"
         "../../../aloe/private/expression-selection.rkt")

(define (remove-cursor marked-source)
  (define bars (regexp-match-positions* #rx"\\|" marked-source))
  (unless (= (length bars) 1)
    (error 'remove-cursor
           "expected exactly one display-only cursor: ~e"
           marked-source))
  (define cursor-index (caar bars))
  (values (string-append (substring marked-source 0 cursor-index)
                         (substring marked-source (add1 cursor-index)))
          (add1 cursor-index)))

(define (check-site marked-source expected-text expected-start expected-span
                    #:source-path [source-path #f])
  (define-values (source position) (remove-cursor marked-source))
  (define site
    (recover-selector-completion-site
     source position #:source-path source-path))
  (unless site
    (error 'check-site "recovery failed for ~e" marked-source))
  (check-equal? (selector-completion-site-selector-text site) expected-text)
  (check-equal? (selector-completion-site-replacement-start site)
                expected-start)
  (check-equal? (selector-completion-site-replacement-span site)
                expected-span)
  (define target (selector-completion-site-target-send site))
  (define expressions (selector-completion-site-expressions site))
  (check-true (send-expr? target))
  (check-true
   (string-contains? (symbol->string (send-expr-selector target))
                     "aloecompletioncursor"))
  (check-true
   (for/or ([root (in-list expressions)])
     (expression-contains-node? root target)))
  (define matching-node
    (for*/first ([root (in-list expressions)]
                 [node (in-list (let walk ([expression root])
                                  (cons expression
                                        (cond
                                          [(check-expr? expression)
                                           (append
                                            (walk (check-expr-left expression))
                                            (walk (check-expr-right expression)))]
                                          [(define-expr? expression)
                                           (walk (define-expr-value expression))]
                                          [(define-class-expr? expression)
                                           (append-map
                                            (lambda (method)
                                              (walk
                                               (method-declaration-body method)))
                                            (define-class-expr-methods expression))]
                                          [(define-methods-expr? expression)
                                           (append-map
                                            (lambda (method)
                                              (walk
                                               (method-declaration-body method)))
                                            (define-methods-expr-methods
                                             expression))]
                                          [(fn-expr? expression)
                                           (walk (fn-expr-body expression))]
                                          [(case-expr? expression)
                                           (append
                                            (walk
                                             (case-expr-scrutinee expression))
                                            (append-map
                                             (lambda (clause)
                                               (walk (case-clause-body clause)))
                                             (case-expr-clauses expression))
                                            (if (case-expr-else-body expression)
                                                (walk
                                                 (case-expr-else-body
                                                  expression))
                                                '()))]
                                          [(send-expr? expression)
                                           (append
                                            (walk
                                             (send-expr-receiver expression))
                                            (append-map
                                             walk
                                             (send-expr-arguments expression)))]
                                          [else '()]))))]
                 #:when (eq? node target))
      node))
  (check-eq? matching-node target)
  (check-eq? (send-expr-receiver matching-node)
             (send-expr-receiver target))
  (check-false
   (string-contains? (selector-completion-site-selector-text site)
                     "aloecompletioncursor"))
  (check-equal?
   (substring source
              (sub1 (selector-completion-site-replacement-start site))
              (+ (sub1 (selector-completion-site-replacement-start site))
                 (selector-completion-site-replacement-span site)))
   expected-text)
  (values source position site))

(define (check-no-site marked-source)
  (define-values (source position) (remove-cursor marked-source))
  (check-false (recover-selector-completion-site source position)))

(define (check-site-only marked-source expected-text expected-start expected-span)
  (define-values (_source _position _site)
    (check-site marked-source expected-text expected-start expected-span))
  (void))

;; Every boundary in an existing selector maps the complete original token.
(for ([marked-source (in-list '("(receiver |dist argument)"
                                "(receiver di|st argument)"
                                "(receiver dist| argument)"))])
  (check-site-only marked-source "dist" 11 4))

;; Partial and empty selectors recover at EOF. The empty source needs one
;; appended close, while the editor range remains zero-width in the source.
(check-site-only "(receiver dis|" "dis" 11 3)
(check-site-only "(receiver |" "" 11 0)

;; The outer selector is targeted without copying its inner-send receiver or
;; absorbing its argument into the replacement range.
(define-values (_nested-source _nested-position nested-site)
  (check-site "((Point new 1.0 2.0) di|st other)" "dist" 22 4))
(define nested-target
  (selector-completion-site-target-send nested-site))
(define nested-receiver (send-expr-receiver nested-target))
(check-true (send-expr? nested-receiver))
(check-eq? nested-receiver
           (send-expr-receiver
            (first (selector-completion-site-expressions nested-site))))
(check-true
 (< (+ (selector-completion-site-replacement-start nested-site)
       (selector-completion-site-replacement-span nested-site))
    (srcloc-position
     (expression-loc (first (send-expr-arguments nested-target))))))

;; Traversal reaches method bodies and real sends nested under parser sugar.
(define class-source
  (string-append
   "(define-class Sample\n"
   "  (fields)\n"
   "  (methods\n"
   "    (measure () Int (self di|st))))"))
(define-values (_class-source _class-position class-site)
  (check-site class-source "dist" 70 4))
(define class-root
  (first (selector-completion-site-expressions class-site)))
(check-eq?
 (selector-completion-site-target-send class-site)
 (method-declaration-body
  (first (define-class-expr-methods class-root))))

(define-values (_let-source _let-position let-site)
  (check-site "(let ((x 1)) (x va|lue))" "value" 17 5))
(define let-root (first (selector-completion-site-expressions let-site)))
(check-false (send-expr-selector-loc let-root))
(check-eq? (selector-completion-site-target-send let-site)
           (fn-expr-body (send-expr-receiver let-root)))

(for-each check-no-site
          '("(let| ((x 1)) (x value))"
            "(let |((x 1)) (x value))"
            "(i|f #t (x value) 0)"
            "(co|nd (#t (x value)) (else 0))"))

;; `(f x)` remains an ordinary send, and a class object can be the receiver of
;; an empty selector hole without construction or checking.
(check-site-only "(f |x)" "x" 4 1)
(check-site-only "(Point |)" "" 8 0)

;; Receiver, argument, completed-form, gap, comment, and string positions are
;; not selector sites.
(for-each check-no-site
          '("(|receiver dist first second)"
            "(rece|iver dist first second)"
            "(receiver dist fi|rst second)"
            "(receiver dist first sec|ond)"
            "(receiver dist)|"
            "(receiver dist)\n|(other send)"
            "|"
            "; com|ment\n(receiver dist)"
            "(receiver dist \"te|xt\")"
            "\"top-|level\""))

;; Keywords, binders, annotations, and operands of every listed special-form
;; family remain syntax rather than ordinary selector sites.
(for-each
 check-no-site
 '("(def|ine answer 1)"
   "(define answer va|lue)"
   "(define-|class Sample (fields) (methods))"
   "(define-class Sam|ple (fields) (methods))"
   "(define-|methods String (methods))"
   "(define-methods Str|ing (methods))"
   "(lo|ad \"missing.aloe\")"
   "(load \"missing.|aloe\")"
   "(f|n (x) x)"
   "(fn (x|) x)"
   "(l|et ((x 1)) x)"
   "(let ((x| 1)) x)"
   "(i|f #t 1 2)"
   "(if #|t 1 2)"
   "(co|nd (#t 1) (else 2))"
   "(cond (#|t 1) (else 2))"
   "(value ca|se (Some () 1))"
   "(value case (Some (pay|load) payload))"
   "(che|ck 1 1)"
   "(check va|lue 1)"))

;; Recovery never drops an unreadable suffix or repairs anything except EOF
;; with bounded right-parenthesis appending.
(for-each check-no-site
          '("(receiver di|st \"unfinished"
            "[receiver di|st)"
            "(receiver di|st)\n(define broken)"
            "(receiver di|st))"))

(define (nested-incomplete-source depth)
  (string-append (apply string-append
                        (make-list (sub1 depth) "(outer selector "))
                 "(receiver "))

(define source-needing-64 (nested-incomplete-source 64))
(define position-needing-64 (add1 (string-length source-needing-64)))
(define site-needing-64
  (recover-selector-completion-site source-needing-64 position-needing-64))
(check-true (selector-completion-site? site-needing-64))
(check-equal? (selector-completion-site-selector-text site-needing-64) "")
(check-equal? (selector-completion-site-replacement-start site-needing-64)
              position-needing-64)
(check-equal? (selector-completion-site-replacement-span site-needing-64) 0)

(define source-needing-65 (nested-incomplete-source 65))
(check-false
 (recover-selector-completion-site
  source-needing-65
  (add1 (string-length source-needing-65))))

;; Marker-like source text forces collision avoidance without affecting an
;; unrelated selector token.
(define collision-marked-source
  (string-append
   "aloecompletioncursor\n"
   "aloecompletioncursor0\n"
   "aloecompletioncursor1\n"
   "(receiver di|st)"))
(define-values (collision-source _collision-position collision-site)
  (let-values ([(source position) (remove-cursor collision-marked-source)])
    (values source
            position
            (recover-selector-completion-site source position))))
(check-true (selector-completion-site? collision-site))
(check-equal? (selector-completion-site-selector-text collision-site) "dist")
(check-equal?
 (substring collision-source
            (sub1
             (selector-completion-site-replacement-start collision-site))
            (+ (sub1
                (selector-completion-site-replacement-start collision-site))
               (selector-completion-site-replacement-span collision-site)))
 "dist")

;; The first boundary beyond the source is rejected before candidate work.
(define bounded-source "(receiver dist)")
(check-false
 (recover-selector-completion-site bounded-source
                                   (+ 2 (string-length bounded-source))))

;; A source path is only a reader source name. Neither it nor a load target is
;; opened or created by selector recovery.
(define missing-source-path
  (build-path (current-directory)
              (format "completion-~a.aloe" (gensym 'missing))))
(define missing-load-path
  (build-path (path-only missing-source-path) "also-missing.aloe"))
(check-false (file-exists? missing-source-path))
(check-false (file-exists? missing-load-path))
(define-values (_path-source _path-position path-site)
  (check-site
   "(load \"also-missing.aloe\")\n(receiver di|st)"
   "dist"
   38
   4
   #:source-path missing-source-path))
(check-equal?
 (srcloc-source
  (send-expr-selector-loc
   (selector-completion-site-target-send path-site)))
 missing-source-path)
(check-false (file-exists? missing-source-path))
(check-false (file-exists? missing-load-path))

;; Expected reader and parser failures are silent.
(define captured-output (open-output-string))
(define captured-errors (open-output-string))
(parameterize ([current-output-port captured-output]
               [current-error-port captured-errors])
  (for ([marked-source
         (in-list '("(receiver di|st \"unfinished"
                     "[receiver di|st)"
                     "(define bro|ken)"))])
    (define-values (source position) (remove-cursor marked-source))
    (check-false (recover-selector-completion-site source position))))
(check-equal? (get-output-string captured-output) "")
(check-equal? (get-output-string captured-errors) "")
