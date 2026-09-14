#lang racket/base

(require rackunit
         racket/list
         racket/runtime-path
         "../../../aloe/parse.rkt"
         "../../../aloe/private/expression-selection.rkt")

(define-runtime-path fixture-path "fixtures/point.aloe")

(define (read-expressions source)
  (read-program source))

(define (read-expression source)
  (first (read-expressions source)))

(define (position-of source text [start 0])
  (define match-positions
    (regexp-match-positions (regexp (regexp-quote text)) source start))
  (unless match-positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar match-positions)))

(define (expression-start expression)
  (srcloc-position (expression-loc expression)))

(define (check-selected expressions position expected)
  (check-eq? (select-expression-at-position expressions position)
             expected))

;; The normative Point fixture pins literal source positions and identity.
(define fixture-expressions
  (call-with-input-file
   fixture-path
   (lambda (input)
     (read-program input #:source-path fixture-path))))

(define point-class (first fixture-expressions))
(define point-send (second fixture-expressions))
(define point-methods (define-class-expr-methods point-class))
(define plus-body (method-declaration-body (first point-methods)))
(define dist2-body (method-declaration-body (second point-methods)))
(define point-one (first (send-expr-arguments point-send)))

(for ([position (in-list '(163 169 170 177))])
  (check-selected fixture-expressions position point-send))

(define point-send-loc (expression-loc point-send))
(check-equal? (srcloc-line point-send-loc) 10)
(check-equal? (srcloc-column point-send-loc) 0)
(check-equal? (srcloc-position point-send-loc) 163)
(check-equal? (srcloc-span point-send-loc) 15)
(check-selected fixture-expressions 174 point-one)
(check-selected fixture-expressions 108 plus-body)
(check-true (variable-expr? plus-body))
(check-selected fixture-expressions 157 dist2-body)
(check-true (send-expr? dist2-body))
(check-equal? (srcloc-position (expression-loc dist2-body)) 151)
(check-equal? (srcloc-span (expression-loc dist2-body)) 8)
(check-selected fixture-expressions 40 point-class)
(check-false (select-expression-at-position fixture-expressions 178))
(check-false (select-expression-at-position fixture-expressions 179))

;; Nested sends select the smallest containing expression. Selectors and
;; uncovered whitespace belong to the enclosing send, not to token nodes.
(define nested-expressions (read-expressions "((1 + 2) * 3)"))
(define nested-outer (first nested-expressions))
(define nested-inner (send-expr-receiver nested-outer))
(define nested-one (send-expr-receiver nested-inner))
(define nested-two (first (send-expr-arguments nested-inner)))

(check-selected nested-expressions 3 nested-one)
(check-selected nested-expressions 7 nested-two)
(for ([position (in-list '(2 4 5 6 8))])
  (check-selected nested-expressions position nested-inner))
(for ([position (in-list '(1 9 10 11 13))])
  (check-selected nested-expressions position nested-outer))

;; Top-level comments and whitespace are gaps. A comment inside a list is
;; covered by that list expression.
(define gap-source "1\n; gap\n\n(2 + 3)\n")
(define gap-expressions (read-expressions gap-source))
(check-false (select-expression-at-position gap-expressions 4))
(check-false (select-expression-at-position gap-expressions 9))

(define inside-comment-source "(1 + ; inside\n 2)")
(define inside-comment-expressions
  (read-expressions inside-comment-source))
(check-selected inside-comment-expressions
                (position-of inside-comment-source "inside")
                (first inside-comment-expressions))

;; `let` introduces an outer send and receiver function with equal locations.
;; Preorder keeps the outer send for the tie while smaller children still win.
(define let-source "(let ((x 1)) (x + 2))")
(define let-expressions (read-expressions let-source))
(define let-send (first let-expressions))
(define let-function (send-expr-receiver let-send))
(define let-value (first (send-expr-arguments let-send)))
(define let-body (fn-expr-body let-function))

(check-true (fn-expr? let-function))
(check-equal? (expression-loc let-send) (expression-loc let-function))
(check-selected let-expressions 2 let-send)
(check-selected let-expressions 8 let-send)
(check-selected let-expressions (expression-start let-value) let-value)
(check-selected let-expressions
                (srcloc-position (send-expr-selector-loc let-body))
                let-body)

;; check visits left then right.
(define check-expression
  (read-expression "(check (1 + 2) (3 * 4))"))
(define check-left (check-expr-left check-expression))
(define check-right (check-expr-right check-expression))
(check-selected (list check-expression)
                (expression-start check-left)
                check-left)
(check-selected (list check-expression)
                (expression-start check-right)
                check-right)

;; define visits its value, but its name is declaration syntax.
(define define-source "(define answer (5 + 6))")
(define define-expression (read-expression define-source))
(define define-value (define-expr-value define-expression))
(check-selected (list define-expression)
                (expression-start define-value)
                define-value)
(check-selected (list define-expression)
                (position-of define-source "answer")
                define-expression)

;; Classes visit method bodies in declaration order. Fields, method names,
;; parameters, and return annotations remain syntax owned by the class form.
(define class-source
  (string-append
   "(define-class Sample\n"
   "  (fields (field-name Int))\n"
   "  (methods\n"
   "    (first-method (first-parameter Int) FirstReturn\n"
   "      (self first-body))\n"
   "    (second-method (second-parameter Int) SecondReturn\n"
   "      (self second-body))))"))
(define class-expression (read-expression class-source))
(define class-methods (define-class-expr-methods class-expression))
(define first-method-body
  (method-declaration-body (first class-methods)))
(define second-method-body
  (method-declaration-body (second class-methods)))

(check-selected (list class-expression)
                (srcloc-position
                 (send-expr-selector-loc first-method-body))
                first-method-body)
(check-selected (list class-expression)
                (srcloc-position
                 (send-expr-selector-loc second-method-body))
                second-method-body)
(for ([syntax-text
       (in-list '("field-name"
                  "first-method"
                  "first-parameter"
                  "FirstReturn"))])
  (check-selected (list class-expression)
                  (position-of class-source syntax-text)
                  class-expression))

;; define-methods likewise visits each method body and no declaration syntax.
(define methods-source
  (string-append
   "(define-methods String\n"
   "  (methods\n"
   "    (decorate (suffix String) String (self append suffix))\n"
   "    (identity () String self)))"))
(define methods-expression (read-expression methods-source))
(define installed-methods
  (define-methods-expr-methods methods-expression))
(define decorate-body
  (method-declaration-body (first installed-methods)))
(define identity-body
  (method-declaration-body (second installed-methods)))

(check-selected (list methods-expression)
                (expression-start decorate-body)
                decorate-body)
(check-selected (list methods-expression)
                (expression-start identity-body)
                identity-body)
(for ([syntax-text (in-list '("define-methods" "decorate" "suffix"))])
  (check-selected (list methods-expression)
                  (position-of methods-source syntax-text)
                  methods-expression))

;; fn visits its body, but not its parameter names.
(define fn-source "(fn (parameter) (parameter + 1))")
(define fn-expression (read-expression fn-source))
(define fn-body (fn-expr-body fn-expression))
(check-selected (list fn-expression) (expression-start fn-body) fn-body)
(check-selected (list fn-expression)
                (position-of fn-source "parameter")
                fn-expression)

;; case visits its scrutinee, every named body, and its optional else body.
;; Constructor selectors and payload binders remain owned by the case form.
(define case-source
  (string-append
   "((Choice A 1) case\n"
   "  (A (payload) payload)\n"
   "  (B (other) (other + 1))\n"
   "  (else 0))"))
(define case-expression (read-expression case-source))
(define case-scrutinee (case-expr-scrutinee case-expression))
(define case-clauses (case-expr-clauses case-expression))
(define case-first-body (case-clause-body (first case-clauses)))
(define case-second-body (case-clause-body (second case-clauses)))
(define case-else-body (case-expr-else-body case-expression))

(for ([child (in-list (list case-scrutinee
                            case-first-body
                            case-second-body
                            case-else-body))])
  (check-selected (list case-expression)
                  (expression-start child)
                  child))
(check-selected (list case-expression)
                (position-of case-source "payload")
                case-expression)

;; send visits its receiver and every argument in source order.
(define send-source "(subject dispatch first-arg second-arg)")
(define send-expression (read-expression send-source))
(define send-children
  (cons (send-expr-receiver send-expression)
        (send-expr-arguments send-expression)))
(for ([child (in-list send-children)])
  (check-selected (list send-expression)
                  (expression-start child)
                  child))
(check-selected (list send-expression)
                (srcloc-position
                 (send-expr-selector-loc send-expression))
                send-expression)

;; Every atom kind is a leaf and can be selected as a root.
(for ([source (in-list '("1" "1.0" "#t" "\"text\"" "name"))])
  (define atom (read-expression source))
  (check-selected (list atom) (expression-start atom) atom))

;; load and define-protocol are leaves. Selection does not open a load path or
;; traverse protocol signatures.
(define load-source "(load \"definitely-missing.aloe\")")
(define load-expression (read-expression load-source))
(check-selected (list load-expression)
                (position-of load-source "definitely-missing.aloe")
                load-expression)

(define protocol-source "(define-protocol Marker (ping () Int))")
(define protocol-expression (read-expression protocol-source))
(check-selected (list protocol-expression)
                (position-of protocol-source "ping")
                protocol-expression)

;; Datum parsing remains location-less throughout complex trees.
(define locationless-datum
  (parse-datum
   '(let ((choice (Option Some 1)))
      (choice case
        (None () 0)
        (Some (value) (value + 1))))))
(define locationless-program
  (parse-program
   '((define answer (1 + 2))
     (check answer 3))))

(for ([position (in-list '(1 2 10 100))])
  (check-false
   (select-expression-at-position (list locationless-datum) position))
  (check-false
   (select-expression-at-position locationless-program position)))

;; The containment end is exclusive, and positions outside all roots miss.
(define bounded-expression (read-expression "(1 + 2)"))
(define bounded-loc (expression-loc bounded-expression))
(define bounded-end
  (+ (srcloc-position bounded-loc) (srcloc-span bounded-loc)))
(check-false
 (select-expression-at-position (list bounded-expression) bounded-end))
(check-false
 (select-expression-at-position (list bounded-expression) 100))
