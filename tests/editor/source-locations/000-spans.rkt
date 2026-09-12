#lang racket/base

(require rackunit
         racket/list
         racket/match
         racket/runtime-path
         "../../../aloe/parse.rkt")

(define-runtime-path fixture-path "fixtures/000-spans.aloe")

(define fixture-expressions
  (call-with-input-file
   fixture-path
   (lambda (input)
     (read-program input #:source-path fixture-path))))

(define (check-fixture-location loc line column position span)
  (check-true (srcloc? loc))
  (check-equal? (srcloc-source loc) fixture-path)
  (check-equal? (srcloc-line loc) line)
  (check-equal? (srcloc-column loc) column)
  (check-equal? (srcloc-position loc) position)
  (check-equal? (srcloc-span loc) span))

(define top-level-int (first fixture-expressions))
(define outer-send (second fixture-expressions))
(define let-send (third fixture-expressions))

(check-fixture-location (expression-loc top-level-int) 1 0 1 2)
(check-fixture-location (expression-loc outer-send) 2 0 4 21)

(define inner-send (send-expr-receiver outer-send))
(check-fixture-location (expression-loc inner-send) 2 1 5 15)
(check-fixture-location (send-expr-selector-loc inner-send) 2 8 12 3)
(check-fixture-location
 (expression-loc (first (send-expr-arguments inner-send)))
 2 12 16 1)
(check-fixture-location
 (expression-loc (second (send-expr-arguments inner-send)))
 2 14 18 1)
(check-fixture-location (send-expr-selector-loc outer-send) 2 17 21 1)
(check-fixture-location
 (expression-loc (first (send-expr-arguments outer-send)))
 2 19 23 1)

(check-fixture-location (expression-loc let-send) 3 0 26 21)
(check-eq? (send-expr-selector let-send) 'call)
(check-false (send-expr-selector-loc let-send))

(define introduced-function (send-expr-receiver let-send))
(check-true (fn-expr? introduced-function))
(check-fixture-location (expression-loc introduced-function) 3 0 26 21)

(define binding-value (first (send-expr-arguments let-send)))
(check-fixture-location (expression-loc binding-value) 3 9 35 1)

(define let-body (fn-expr-body introduced-function))
(check-true (send-expr? let-body))
(check-fixture-location (expression-loc let-body) 3 13 39 7)
(check-fixture-location
 (expression-loc (send-expr-receiver let-body))
 3 14 40 1)
(check-fixture-location (send-expr-selector-loc let-body) 3 16 42 1)
(check-fixture-location
 (expression-loc (first (send-expr-arguments let-body)))
 3 18 44 1)

(define (check-location-free expression)
  (check-false (expression-loc expression))
  (match expression
    [(check-expr left right _ _ _)
     (check-location-free left)
     (check-location-free right)]
    [(define-expr _ value _)
     (check-location-free value)]
    [(define-protocol-expr _ signatures _)
     (for ([signature (in-list signatures)]
           #:when (method-declaration-body signature))
       (check-location-free (method-declaration-body signature)))]
    [(define-class-expr _ _ _ _ _ methods _)
     (for ([method (in-list methods)])
       (check-location-free (method-declaration-body method)))]
    [(define-methods-expr _ methods _)
     (for ([method (in-list methods)])
       (check-location-free (method-declaration-body method)))]
    [(fn-expr _ body _)
     (check-location-free body)]
    [(case-expr scrutinee clauses else-body _)
     (check-location-free scrutinee)
     (for ([clause (in-list clauses)])
       (check-location-free (case-clause-body clause)))
     (when else-body
       (check-location-free else-body))]
    [(send-expr receiver _ arguments _ selector-loc)
     (check-false selector-loc)
     (check-location-free receiver)
     (for-each check-location-free arguments)]
    [_ (void)]))

(for ([datum (in-list
              '(((Point new 1 2) + p)
                (let ((x 1)) (x + 2))))])
  (define first-parse (parse-datum datum))
  (define second-parse (parse-datum datum))
  (check-equal? first-parse second-parse)
  (check-location-free first-parse))

(define pathless
  (first (read-program "(x + 2)\n")))

(define (check-populated-location loc)
  (check-true (srcloc? loc))
  (check-not-false (srcloc-line loc))
  (check-not-false (srcloc-column loc))
  (check-not-false (srcloc-position loc))
  (check-not-false (srcloc-span loc)))

(check-populated-location (expression-loc pathless))
(check-populated-location (expression-loc (send-expr-receiver pathless)))
(check-populated-location (send-expr-selector-loc pathless))
(check-populated-location
 (expression-loc (first (send-expr-arguments pathless))))
