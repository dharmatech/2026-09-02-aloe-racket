#lang racket/base

(require racket/list
         racket/match
         racket/port
         racket/runtime-path
         rackunit
         "../../../aloe/driver.rkt"
         "../../../aloe/expression-query.rkt"
         (only-in "../../../aloe/main.rkt"
                  exn:fail:aloe-type?)
         "../../../aloe/parse.rkt"
         (submod "../../../aloe/type.rkt" class-name-span))

(define-runtime-path point-path "fixtures/point.aloe")
(define-runtime-path shapes-path "fixtures/shapes.aloe")
(define-runtime-path option-path "../../../lib/option.aloe")

;; A location as (line column position span).
(define (location-numbers loc)
  (list (srcloc-line loc)
        (srcloc-column loc)
        (srcloc-position loc)
        (srcloc-span loc)))

(define (check-location loc expected [source #f])
  (check-true (srcloc? loc))
  (check-equal? (location-numbers loc) expected)
  (when source
    (check-equal? (srcloc-source loc) source)))

;; A span tree with each srcloc written as a vector of its numbers.
(define (span-tree-numbers tree)
  (cond
    [(srcloc? tree) (list->vector (location-numbers tree))]
    [(list? tree) (map span-tree-numbers tree)]
    [else tree]))

(define (span-tree-locations tree)
  (cond
    [(srcloc? tree) (list tree)]
    [(list? tree) (append-map span-tree-locations tree)]
    [else '()]))

(define (check-span-tree tree expected [source #f])
  (check-equal? (span-tree-numbers tree) expected)
  (when source
    (for ([loc (in-list (span-tree-locations tree))])
      (check-equal? (srcloc-source loc) source))))

(define shapes-expressions
  (call-with-input-file
   shapes-path
   (lambda (input)
     (read-program input #:source-path shapes-path))))

(define (class-form name)
  (findf (lambda (expression)
           (and (define-class-expr? expression)
                (eq? (define-class-expr-name expression) name)))
         shapes-expressions))

(define (methods-form target)
  (findf (lambda (expression)
           (and (define-methods-expr? expression)
                (eq? (define-methods-expr-target expression) target)))
         shapes-expressions))

(define (protocol-form name)
  (findf (lambda (expression)
           (and (define-protocol-expr? expression)
                (eq? (define-protocol-expr-name expression) name)))
         shapes-expressions))

(define (named-method methods selector)
  (findf (lambda (method)
           (eq? (method-declaration-selector method) selector))
         methods))

(define (named-field fields name)
  (findf (lambda (field)
           (eq? (field-declaration-name field) name))
         fields))

(define (named-parameter method name)
  (findf (lambda (parameter)
           (eq? (parameter-declaration-name parameter) name))
         (method-declaration-parameters method)))

(define (constructor-field class selector name)
  (named-field
   (constructor-declaration-fields
    (findf (lambda (constructor)
             (eq? (constructor-declaration-selector constructor) selector))
           (define-class-expr-constructors class)))
   name))

(test-case "header and target spans"
  (check-location (define-class-expr-name-loc (class-form 'Box))
                  '(7 15 131 3)
                  shapes-path)
  (check-location (define-class-expr-name-loc (class-form 'Segment))
                  '(16 14 279 7)
                  shapes-path)
  (check-location (define-class-expr-name-loc (class-form 'Holder))
                  '(38 14 702 6)
                  shapes-path)
  (check-location (define-methods-expr-target-loc (methods-form 'Point))
                  '(24 16 452 5)
                  shapes-path)
  (check-location (define-methods-expr-target-loc (methods-form 'Box))
                  '(31 16 615 3)
                  shapes-path)

  (check-location (expression-loc (protocol-form 'Mover))
                  '(4 0 64 50)
                  shapes-path)
  (check-location (expression-loc (class-form 'Box))
                  '(7 0 116 147)
                  shapes-path)
  (check-location (expression-loc (class-form 'Segment))
                  '(16 0 265 169)
                  shapes-path)
  (check-location (expression-loc (methods-form 'Point))
                  '(24 0 436 161)
                  shapes-path)
  (check-location (expression-loc (methods-form 'Box))
                  '(31 0 599 69)
                  shapes-path)
  (check-location (expression-loc (class-form 'Holder))
                  '(38 0 688 112)
                  shapes-path))

(test-case "span trees"
  (define mover-moved
    (first (define-protocol-expr-signatures (protocol-form 'Mover))))
  (define box (class-form 'Box))
  (define box-fresh (named-method (define-class-expr-methods box) 'fresh))
  (define segment (class-form 'Segment))
  (define segment-moved
    (named-method (define-class-expr-methods segment) 'moved))
  (define point-methods (define-methods-expr-methods (methods-form 'Point)))
  (define boxed (named-method point-methods 'boxed))
  (define nudge (named-method point-methods 'nudge))
  (define item-of
    (named-method (define-methods-expr-methods (methods-form 'Box)) 'item-of))
  (define holder (class-form 'Holder))

  (define (field-of class name)
    (named-field (define-class-expr-fields class) name))

  ;; Each row: the type datum, its span tree, then the expected datum and
  ;; tree.
  (define rows
    (list
     (let ([parameter (named-parameter mover-moved 'by)])
       (list (parameter-declaration-type parameter)
             (parameter-declaration-type-spans parameter)
             'Point
             #(5 13 100 5)))
     (list (method-declaration-return-type mover-moved)
           (method-declaration-return-type-spans mover-moved)
           'Point
           #(5 20 107 5))
     (let ([field (field-of box 'item)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             'T
             #(9 10 158 1)))
     (let ([field (field-of box 'corner)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             'Point
             #(10 12 173 5)))
     (let ([field (field-of box 'spare)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             '(Option Point)
             (list #(11 12 192 6) #(11 19 199 5))))
     (list (method-declaration-return-type box-fresh)
           (method-declaration-return-type-spans box-fresh)
           'Point
           #(13 14 233 5))
     (let ([field (constructor-field segment 'Line 'from)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             'Point
             #(18 24 333 5)))
     (let ([field (constructor-field segment 'Line 'to)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             'Point
             #(18 35 344 5)))
     (let ([field (constructor-field segment 'Dot 'at)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             'Point
             #(19 21 374 5)))
     (let ([parameter (named-parameter segment-moved 'by)])
       (list (parameter-declaration-type parameter)
             (parameter-declaration-type-spans parameter)
             'Point
             #(21 15 410 5)))
     (list (method-declaration-return-type segment-moved)
           (method-declaration-return-type-spans segment-moved)
           'Point
           #(21 22 417 5))
     (let ([parameter (named-parameter boxed 'item)])
       (list (parameter-declaration-type parameter)
             (parameter-declaration-type-spans parameter)
             'A
             #(26 26 495 1)))
     (list (method-declaration-return-type boxed)
           (method-declaration-return-type-spans boxed)
           '(Box A)
           (list #(26 30 499 3) #(26 34 503 1)))
     (let ([parameter (named-parameter nudge 'm)])
       (list (parameter-declaration-type parameter)
             (parameter-declaration-type-spans parameter)
             'Mover
             #(28 14 561 5)))
     (list (method-declaration-return-type nudge)
           (method-declaration-return-type-spans nudge)
           'Point
           #(28 21 568 5))
     (list (method-declaration-return-type item-of)
           (method-declaration-return-type-spans item-of)
           'T
           #(33 16 646 1))
     (let ([field (field-of holder 'p)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             'P
             #(40 7 726 1)))
     (let ([field (field-of holder 'boxes)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             '(List (Box Point))
             (list #(41 12 741 4) (list #(41 18 747 3) #(41 22 751 5)))))
     (let ([field (field-of holder 'maker)])
       (list (field-declaration-type field)
             (field-declaration-type-spans field)
             '(-> Int Point)
             (list #(42 12 772 2) #(42 15 775 3) #(42 19 779 5))))))

  (check-equal? (length rows) 19)
  (for ([row (in-list rows)])
    (match-define (list type tree expected-type expected-tree) row)
    (check-equal? type expected-type)
    (check-span-tree tree expected-tree shapes-path)))

(test-case "span-tree leaves that are not symbols"
  (define odd
    (first
     (read-program
      "(define-class Odd\n  (fields (a 3) (b \"s\") (c (Option . Point)) (d #(Point)) (e (List 3)) (f (Option)))\n  (methods))\n")))
  (define (spans name)
    (field-declaration-type-spans
     (named-field (define-class-expr-fields odd) name)))
  (check-false (spans 'a))
  (check-false (spans 'b))
  (check-false (spans 'c))
  (check-false (spans 'd))
  (check-span-tree (spans 'e) (list #(2 62 81 4) #f))
  (check-span-tree (spans 'f) (list #(2 75 94 6)))
  (check-location (define-class-expr-name-loc odd) '(1 14 15 3)))

;; Every name and type span of the declarations in expressions; each must be
;; #f as a whole field. Returns how many fields were seen.
(define (check-location-free-declarations expressions)
  (define seen 0)
  (define (check-free value)
    (set! seen (add1 seen))
    (check-false value))
  (define (check-fields fields)
    (for ([field (in-list (or fields '()))])
      (check-free (field-declaration-type-spans field))))
  (define (check-method method)
    (check-free (method-declaration-return-type-spans method))
    (for ([parameter (in-list (method-declaration-parameters method))])
      (check-free (parameter-declaration-type-spans parameter))))
  (for ([expression (in-list expressions)])
    (match expression
      [(define-class-expr _ _ _ fields constructors methods _ name-loc)
       (check-free name-loc)
       (check-fields fields)
       (for ([constructor (in-list (or constructors '()))])
         (check-fields (constructor-declaration-fields constructor)))
       (for-each check-method methods)]
      [(define-methods-expr _ methods _ target-loc)
       (check-free target-loc)
       (for-each check-method methods)]
      [(define-protocol-expr _ signatures _)
       (for-each check-method signatures)]
      [_ (void)]))
  seen)

(test-case "location-free datums"
  (define datums
    (call-with-input-file shapes-path
      (lambda (input)
        (for/list ([datum (in-port read input)]) datum))))
  (define first-parse (map parse-datum datums))
  (define second-parse (map parse-datum datums))
  (check-equal? first-parse second-parse)
  ;; 3 class names, 2 targets, the protocol signature's return and parameter,
  ;; 9 class and constructor fields, and 5 method returns and 3 parameters.
  (check-equal? (check-location-free-declarations first-parse) 24)
  (define program (parse-program datums))
  (check-equal? program first-parse)
  (check-equal? (check-location-free-declarations program) 24))

(define (quiet-driver-load! state path)
  (driver-load-file! state path (open-output-nowhere)))

(test-case "the class record"
  (define shapes-state (make-driver))
  (quiet-driver-load! shapes-state shapes-path)
  (define shapes-environment (driver-type-environment shapes-state))
  (check-location (checker-class-name-loc shapes-environment 'Box)
                  '(7 15 131 3)
                  shapes-path)
  (check-location (checker-class-name-loc shapes-environment 'Segment)
                  '(16 14 279 7)
                  shapes-path)
  (check-location (checker-class-name-loc shapes-environment 'Holder)
                  '(38 14 702 6)
                  shapes-path)

  (define point-state (make-driver))
  (quiet-driver-load! point-state point-path)
  (check-location (checker-class-name-loc
                   (driver-type-environment point-state) 'Point)
                  '(1 14 15 5)
                  point-path)

  (define datum-state (make-driver))
  (driver-eval! datum-state '(define-class Q (fields (a Int)) (methods)))
  (check-false (checker-class-name-loc
                (driver-type-environment datum-state) 'Q))

  (define base-environment (driver-type-environment (make-driver)))
  (check-location (checker-class-name-loc base-environment 'Option)
                  '(1 15 16 6))

  (check-exn exn:fail?
             (lambda ()
               (checker-class-name-loc shapes-environment 'Mover)))
  (for ([name (in-list '(List String Int))])
    (check-exn exn:fail?
               (lambda ()
                 (checker-class-name-loc base-environment name))
               (format "~a" name)))
  (check-exn exn:fail:aloe-type?
             (lambda ()
               (checker-class-name-loc base-environment 'Unbound))))

(define error-cases
  '(("(define-class A (fields (x)) (methods))"
     "parse-datum: malformed field; expected (name Type)\n  field: '(x)")
    ("(define-class A (fields (x Int . y)) (methods))"
     "parse-datum: malformed field; expected (name Type)\n  field: '(x Int . y)")
    ("(define-class A (fields (x Int) (x Int)) (methods))"
     "parse-datum: field names must be unique\n  field: 'x\n  datum: '(define-class A (fields (x Int) (x Int)) (methods))")
    ("(define-class A (constructors (B)) (methods))"
     "parse-datum: malformed constructor; expected (Name (fields ...))\n  constructor: '(B)")
    ("(define-class A (constructors (B (fields . 3))) (methods))"
     "parse-datum: malformed constructor fields; expected (fields ...)\n  constructor: '(B (fields . 3))")
    ("(define-class A (constructors (B (fields (x Int) (x Int)))) (methods))"
     "parse-datum: field names must be unique\n  field: 'x\n  datum: '(B (fields (x Int) (x Int)))")
    ("(define-class A (constructors (B (fields)) (B (fields))) (methods))"
     "parse-datum: constructor selectors must be unique\n  selector: 'B\n  datum: '(define-class A (constructors (B (fields)) (B (fields))) (methods))")
    ("(define-class A (constructors) (methods))"
     "parse-datum: constructors section must be nonempty\n  datum: '(define-class A (constructors) (methods))")
    ("(define-methods A (methods (m (x Int) (y) Int 1)))"
     "parse-datum: malformed parameter; expected (name Type)\n  parameter: '(y)")
    ("(define-class A (fields) (methods (m () 3 1)))"
     "parse-datum: method return type must be a type expression\n  return type: 3\n  method: '(m () 3 1)")
    ("(define-protocol P 3)"
     "parse-datum: malformed protocol signature\n  signature: 3")
    ("(define-protocol P (ping))"
     "parse-datum: malformed protocol signature; expected parameters and a return type\n  signature: '(ping)")
    ("(define-protocol P (ping () Int Int))"
     "parse-datum: malformed zero-parameter protocol signature\n  signature: '(ping () Int Int)")
    ("(define-protocol P (ping (x Int) 3))"
     "parse-datum: protocol return type must be a type expression\n  return type: 3\n  signature: '(ping (x Int) 3)")
    ("(define-protocol P (ping (x) Int))"
     "parse-datum: malformed parameter; expected (name Type)\n  parameter: '(x)")))

;; The message a thunk raises, or 'no-error.
(define (raised-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    'no-error))

(test-case "error text is unchanged"
  (for ([error-case (in-list error-cases)])
    (match-define (list source message) error-case)
    (check-equal? (raised-message
                   (lambda () (parse-datum (read (open-input-string source)))))
                  message
                  source)
    (check-equal? (raised-message (lambda () (read-program source)))
                  message
                  source)))

(test-case "hover is unchanged"
  (define result (query-expression-at shapes-path 680))
  (check-equal? (expression-query-result-type result) '(Class Point))
  (check-equal? (expression-query-result-signatures result)
                (list (signature-spec 'new '(Int Int) 'Point)))
  (check-equal?
   (expression-query-result-pathed-type result)
   (list 'Class
         (string->symbol "Point@tests/editor/definition/fixtures/point.aloe")))
  (check-location (expression-query-result-location result)
                  '(36 10 680 5)
                  (simplify-path (path->complete-path shapes-path) #f)))
