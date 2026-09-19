#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         "../../../aloe/parse.rkt"
         "../../../aloe/private/completion-selection.rkt"
         "../../../aloe/signature-catalog.rkt"
         (prefix-in type: "../../../aloe/type.rkt")
         (submod "../../../aloe/type.rkt"
                 expression-query-observation)
         (submod "../../../aloe/type.rkt"
                 completion-query-observation))

(define-runtime-path type-path "../../../aloe/type.rkt")
(define-runtime-path checker-observation-path
  "../../../aloe/private/checker-observation.rkt")
(define-runtime-path main-path "../../../aloe/main.rkt")
(define-runtime-path driver-path "../../../aloe/driver.rkt")
(define-runtime-path point-path "../../../examples/point.aloe")
(define completion-submodule
  `(submod ,type-path completion-query-observation))

(define (triples->specs triples)
  (for/list ([triple (in-list triples)])
    (apply signature-spec triple)))

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

(define string-kernel-rows
  (triples->specs
   '((= (String) Bool)
     (append (String) String)
     (len () Int)
     (take (Int) String)
     (drop (Int) String))))

(define point-float-rows
  (triples->specs
   '((x () Float)
     (y () Float)
     (+ ((Point Float)) (Point Float))
     (- ((Point Float)) (Point Float))
     (dist2 ((Point Float)) Float)
     (dot ((Point Float)) Float)
     (* (Float) (Point Float))
     (/ (Float) (Point Float)))))

(define (remove-cursor marked-source)
  (define positions (regexp-match-positions* #rx"\\|" marked-source))
  (unless (= (length positions) 1)
    (error 'remove-cursor
           "expected exactly one display-only cursor: ~e"
           marked-source))
  (define index (caar positions))
  (values
   (string-append (substring marked-source 0 index)
                  (substring marked-source (add1 index)))
   (add1 index)))

(define (recover marked-source #:source-path [source-path #f])
  (define-values (source position) (remove-cursor marked-source))
  (define site
    (recover-selector-completion-site
     source position #:source-path source-path))
  (unless site
    (error 'recover "completion recovery failed: ~e" marked-source))
  site)

(define (observe-site site [environment (type:make-type-environment)])
  (typecheck-program/observe-selector-receiver
   (selector-completion-site-expressions site)
   environment
   (selector-completion-site-target-send site)))

(define (observe marked-source
                 #:source-path [source-path #f]
                 #:environment [environment (type:make-type-environment)])
  (observe-site
   (recover marked-source #:source-path source-path)
   environment))

(define (captured-type-error thunk)
  (with-handlers ([type:exn:fail:aloe-type? values])
    (thunk)
    #f))

(define missing-export (gensym 'missing-export))

(define (module-exports? module-path name)
  (not
   (eq? (dynamic-require module-path name (lambda () missing-export))
        missing-export)))

(define (phase-zero-export-names exports)
  (map car (cdr (assq 0 exports))))

(define (string-position text literal)
  (define matches
    (regexp-match-positions
     (regexp (regexp-quote literal))
     text))
  (and matches (caar matches)))

(test-case "completion observation bridge is exact, narrow, and one-field"
  (define sample (selector-receiver-observation '(one two)))
  (check-true (selector-receiver-observation? sample))
  (check-equal? (procedure-arity selector-receiver-observation) 1)
  (check-equal?
   (struct->vector sample)
   '#(struct:selector-receiver-observation (one two)))
  (check-equal?
   (selector-receiver-observation-signatures sample)
   '(one two))
  (check-equal?
   (procedure-arity typecheck-program/observe-selector-receiver)
   3)

  (dynamic-require completion-submodule #f)
  (define-values (value-exports syntax-exports)
    (module->exports completion-submodule))
  (check-equal?
   (phase-zero-export-names value-exports)
   '(selector-receiver-observation-signatures
     selector-receiver-observation?
     struct:selector-receiver-observation
     typecheck-program/observe-selector-receiver))
  (check-equal?
   (phase-zero-export-names syntax-exports)
   '(selector-receiver-observation))

  (for* ([module-path (in-list (list type-path main-path driver-path))]
         [name (in-list
                '(selector-receiver-observation
                  selector-receiver-observation?
                  selector-receiver-observation-signatures
                  typecheck-program/observe-selector-receiver))])
    (check-false (module-exports? module-path name)))

  (check-true (procedure? typecheck-program/observe))
  (check-equal? (procedure-arity typecheck-program/observe) 3))

(define point-source (file->string point-path))

(define (point-site selector-fragment)
  (recover
   (string-append point-source
                  "\n((Point new 1.0 2.0) "
                  selector-fragment)
   #:source-path point-path))

(test-case "normative Point Float receiver yields the eight shared rows"
  (define site (point-site "d|"))
  (define expressions (selector-completion-site-expressions site))
  (define target (selector-completion-site-target-send site))
  (define receiver (send-expr-receiver target))
  (check-eq? target (last expressions))
  (check-eq? receiver (send-expr-receiver (last expressions)))
  (check-true (send-expr? receiver))
  (check-equal?
   (observe-site site)
   (selector-receiver-observation point-float-rows)))

(test-case "empty, partial, and existing selectors do not affect receiver rows"
  (define answers
    (for/list ([fragment (in-list '("|" "d|" "di|st"))])
      (observe-site (point-site fragment))))
  (for ([answer (in-list answers)])
    (check-equal?
     answer
     (selector-receiver-observation point-float-rows))
    (check-equal? (vector-length (struct->vector answer)) 2))
  (check-equal? (first answers) (second answers))
  (check-equal? (second answers) (third answers)))

(test-case "completion escapes before selector, arguments, enclosing tail, and later roots"
  (for ([source
         (in-list
          (list
           "(1 p| missing-target-argument)"
           "(check (1 p|) \"ill-typed remainder\")"
           "(1 p|)\nmissing-later-root"))])
    (check-equal?
     (observe source)
     (selector-receiver-observation int-rows)))

  (define protocol-source
    (string-append
     "(define-protocol RequiredCompletion001\n"
     "  (required () Int))\n"
     "(define-class MissingCompletion001 RequiredCompletion001\n"
     "  (fields)\n"
     "  (methods))\n"
     "(1 p|)"))
  (check-equal?
   (observe protocol-source)
   (selector-receiver-observation int-rows)))

(test-case "failures before the receiver and in the receiver remain type errors"
  (define synthetic-path
    (build-path (path-only point-path) "completion-buffer-001.aloe"))
  (for ([source
         (in-list
          (list
           "missing-earlier-root\n(1 p|)"
           "(\"bad\" + 1)\n(1 p|)"
           "(load \"missing-completion-001.aloe\")\n(1 p|)"
           "(missing-receiver p|)"
           "((\"bad\" + 1) p|)"))])
    (check-exn
     type:exn:fail:aloe-type?
     (lambda ()
       (observe source #:source-path synthetic-path)))))

(test-case "earlier define-methods rows are ordered and later rows are absent"
  (define source
    (string-append
     "(define-methods String\n"
     "  (methods\n"
     "    (repeat001 (n Int) String self)\n"
     "    (repeat001 (s String) String self)\n"
     "    (before001 () String self)))\n"
     "(\"receiver\" b|)\n"
     "(define-methods String\n"
     "  (methods\n"
     "    (later001 () String self)))"))
  (define expected
    (append
     string-kernel-rows
     (triples->specs
      '((repeat001 (Int) String)
        (repeat001 (String) String)
        (before001 () String)))))
  (define answer (observe source))
  (check-equal? answer (selector-receiver-observation expected))
  (check-equal?
   (map signature-spec-selector
        (selector-receiver-observation-signatures answer))
   '(= append len take drop repeat001 repeat001 before001)))

(define lexical-class-template
  (string-append
   "(define-class CompletionLexical001\n"
   "  (fields (value Int))\n"
   "  (methods\n"
   "    (from-self () Int SELF-BODY)\n"
   "    (from-parameter (other CompletionLexical001) Int PARAM-BODY)))"))

(define lexical-class-rows
  (triples->specs
   '((value () Int)
     (from-self () Int)
     (from-parameter (CompletionLexical001) Int))))

(test-case "self and method parameters use their method lexical environment"
  (define self-source
    (string-replace
     (string-replace lexical-class-template
                     "SELF-BODY" "(self v|)")
     "PARAM-BODY" "(other value)"))
  (define parameter-source
    (string-replace
     (string-replace lexical-class-template
                     "SELF-BODY" "(self value)")
     "PARAM-BODY" "(other v|)"))
  (for ([source (in-list (list self-source parameter-source))])
    (check-equal?
     (observe source)
     (selector-receiver-observation lexical-class-rows))))

(test-case "function and let receivers retain same-root constraints"
  (check-equal?
   (observe "((fn (x) (x p|)) call 1)")
   (selector-receiver-observation int-rows))
  (check-equal?
   (observe "(let ((x \"text\")) (x p|))")
   (selector-receiver-observation string-kernel-rows)))

(test-case "case payload receiver is observed before a failing sibling"
  (define source
    (string-append
     "(define-class (CompletionOption001 T)\n"
     "  (constructors\n"
     "    (None (fields))\n"
     "    (Some (fields (value T))))\n"
     "  (methods))\n"
     "((CompletionOption001 Some 1) case\n"
     "  (Some (payload) (payload p|))\n"
     "  (None () missing-sibling-body))"))
  (check-equal?
   (observe source)
   (selector-receiver-observation int-rows)))

(define rigid-template
  (string-append
   "(define-class (CompletionRigid001 T)\n"
   "  (fields (value T))\n"
   "  (methods\n"
   "    (adapt (type U) (item U) U item)\n"
   "    (rows (type U) (item U) T ROWS-BODY)\n"
   "    (bad () T BAD-BODY)))\n"
   "((CompletionRigid001 new 1) adapt \"later\")\n"
   "((CompletionRigid001 new 1.0) rows \"also-later\")"))

(define rigid-rows
  (triples->specs
   '((value () T)
     (adapt (U) U)
     (rows (U) T)
     (bad () T))))

(test-case "legacy generic receiver is rigid, symbolic, and selectively checked"
  (define valid-source
    (string-replace
     (string-replace rigid-template "ROWS-BODY" "(self v|)")
     "BAD-BODY" "missing-latent-body"))
  (check-equal?
   (observe valid-source)
   (selector-receiver-observation rigid-rows))

  (define failing-source
    (string-replace
     (string-replace rigid-template "ROWS-BODY" "(self value)")
     "BAD-BODY" "(missing-rigid-receiver p|)"))
  (define error
    (captured-type-error (lambda () (observe failing-source))))
  (check-true (type:exn:fail:aloe-type? error))
  (check-equal?
   (exn-message error)
   "typecheck: unbound symbol: missing-rigid-receiver"))

(define extension-template
  (string-append
   "(define-class (CompletionExtension001 T)\n"
   "  (fields (value T))\n"
   "  (methods))\n"
   "(define-methods CompletionExtension001\n"
   "  (methods\n"
   "    (good () T GOOD-BODY)\n"
   "    (bad () T BAD-BODY)))"))

(define extension-rows
  (triples->specs
   '((value () T)
     (good () T)
     (bad () T))))

(test-case "generic define-methods uses the same selective rigid-body rule"
  (define valid-source
    (string-replace
     (string-replace extension-template "GOOD-BODY" "(self v|)")
     "BAD-BODY" "missing-extension-latent"))
  (check-equal?
   (observe valid-source)
   (selector-receiver-observation extension-rows))

  (define failing-source
    (string-replace
     (string-replace extension-template "GOOD-BODY" "(self value)")
     "BAD-BODY" "(missing-extension-receiver p|)"))
  (check-exn
   type:exn:fail:aloe-type?
   (lambda () (observe failing-source))))

(test-case "an earlier ordinary load contributes declarations in source order"
  (define synthetic-path
    (build-path (path-only point-path) "completion-buffer-001.aloe"))
  (define loaded-source
    (string-append
     "(load \"point.aloe\")\n"
     "((Point new 1.0 2.0) d|)"))
  (check-equal?
   (observe loaded-source #:source-path synthetic-path)
   (selector-receiver-observation point-float-rows))
  (check-exn
   type:exn:fail:aloe-type?
   (lambda ()
     (observe
      "(load \"missing-completion-001.aloe\")\n(1 p|)"
      #:source-path synthetic-path)))
  (check-equal? (file->string point-path) point-source))

(test-case "a real empty catalog is a successful empty observation"
  (check-equal?
   (observe "(String p|)")
   (selector-receiver-observation '())))

(test-case "calls are fresh and observers and escapes never leak"
  (define site (recover "(1 p|)"))
  (define first-answer
    (observe-site site (type:make-type-environment)))
  (define second-answer
    (observe-site site (type:make-type-environment)))
  (check-equal? first-answer second-answer)
  (check-false
   (eq? (selector-receiver-observation-signatures first-answer)
        (selector-receiver-observation-signatures second-answer)))

  (check-equal?
   (type:type->datum
    (type:type-of (parse-datum '(1 + 2))
                  (type:make-type-environment)))
   'Int)
  (check-equal?
   (type:type->datum
    (type:typecheck-program
     (parse-program '((define completion-clean-001 1)
                      completion-clean-001))
     (type:make-type-environment)))
   'Int)

  (check-exn
   type:exn:fail:aloe-type?
   (lambda () (observe "(missing-cleanup p|)")))
  (check-equal?
   (type:type->datum
    (type:type-of (parse-datum '(2 * 3))
                  (type:make-type-environment)))
   'Int)

  (define strict-expressions
    (parse-program '((check (List empty) (List of 1)))))
  (define strict-selected
    (check-expr-left (first strict-expressions)))
  (check-equal?
   (typecheck-program/observe
    strict-expressions
    (type:make-type-environment)
    strict-selected)
   (expression-type-observation
    '(List Int)
    (triples->specs
     '((empty? () Bool)
       (first () Int)
       (rest () (List Int))
       (cons (Int) (List Int))
       (len () Int))))))

(test-case "the observation is exactly the shared catalog result"
  (define site (recover "(1 p|)"))
  (define environment (type:make-type-environment))
  (define answer (observe-site site environment))
  (define shared-rows
    (type:type-signature-specs
     (type:type-of (parse-datum 1) environment)
     environment))
  (check-equal?
   (selector-receiver-observation-signatures answer)
   shared-rows)
  (check-false
   (eq? (selector-receiver-observation-signatures answer)
        shared-rows))

  ;; Keep the private observation hook visibly declarative: its result is
  ;; built by one direct shared-catalog call, without an alternate
  ;; declaration-table or runtime reflection path.
  (define observation-source
    (file->string checker-observation-path))
  (define bridge-start
    (string-position
     observation-source
     "(define (observe-selector-receiver!"))
  (define next-established-boundary
    (and bridge-start
         (let ([relative
                (string-position
                 (substring observation-source bridge-start)
                 "(define (materialize-expression-observation-at-root-end!")])
           (and relative (+ bridge-start relative)))))
  (check-not-false bridge-start)
  (check-not-false next-established-boundary)
  (define bridge-source
    (substring
     observation-source bridge-start next-established-boundary))
  (check-equal?
   (length (regexp-match* #rx"type-signature-specs" bridge-source))
   1)
  (for ([alternate
         (in-list
          '("class-info-fields"
            "class-info-methods"
            "class-info-constructors"
            "kernel-instance-signature-specs"
            "eval-expression"
            "Mirror"
            "host-receiver-invoke-method"))])
    (check-false (string-contains? bridge-source alternate))))
