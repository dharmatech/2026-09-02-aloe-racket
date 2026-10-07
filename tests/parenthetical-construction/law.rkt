#lang racket/base

(require rackunit
         racket/list
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt"
         "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         "../../aloe/type.rkt")

(define fixture-source
  #<<ALOE
(define-class (Point T)
  (fields (x T) (y T))
  (methods
    (+ (other (Point T)) (Point T)
      (Point new ((self x) + (other x)) ((self y) + (other y))))))
(define-class IntPoint (fields (x Int) (y Int)) (methods))
(define-class Other (fields (x Int) (y Int)) (methods))
(define-class Empty (fields) (methods))
(define-class (GenericEmpty T) (fields) (methods))
(define-class ExplicitEmpty (constructors (new (fields))) (methods))
(define-class ExplicitPoint
  (constructors (new (fields (x Int) (y Int)))) (methods))
(define-class (Option T)
  (constructors (None (fields)) (Some (fields (value T))))
  (methods
    (present? () Bool (self case (None () #f) (Some (value) #t)))))
(define-class Context
  (fields (items (List String)) (measure (-> String Int))) (methods))
(define-class (GenericContext T)
  (fields (items (List T)) (measure (-> T Int))) (methods))
(define-class ContextHolder (fields (box (GenericContext String))) (methods))
(define-class EmptyHolder (fields (box (GenericEmpty String))) (methods))
(define also-point Point)
ALOE
  )

(define (load-source! state source)
  (void (driver-load-port! state (open-input-string source) (open-output-string))))

(define (make-fixture [source fixture-source])
  (define state (make-driver))
  (load-source! state source)
  state)

(define (checked-type state datum)
  (type->datum (type-of (parse-datum datum) (driver-type-environment state))))

(define (failure-matches? kind patterns)
  (lambda (failure)
    (and (kind failure)
         (for/and ([pattern (in-list patterns)])
           (regexp-match? pattern (exn-message failure))))))

(define (check-type-failure state datum . patterns)
  (check-exn (failure-matches? exn:fail:aloe-type? patterns)
             (lambda () (driver-eval! state datum))))

;; The capability is test-only and explicitly injected. Its state records
;; effects; Aloe programs themselves remain immutable.
(define trace-interface
  (make-host-interface
   'ConstructionTrace
   (list
    (make-host-method
     'mark '(String Int) 'Int
     (lambda (events marker value)
       (set-box! events (append (unbox events) (list marker)))
       value))
    (make-host-method
     'test '(String) 'Bool
     (lambda (events marker)
       (set-box! events (append (unbox events) (list marker)))
       #t)))))

(define (make-traced-fixture)
  (define state (make-fixture))
  (define events (box '()))
  (driver-inject-host! state 'trace (make-host-receiver trace-interface events))
  (values state events))

(test-case "both labeled orders preserve positional type, payload, and constructor"
  (define state (make-fixture))
  (for ([numbers (in-list '((1 2) (1.0 2.0)))]
        [type (in-list '((Point Int) (Point Float)))])
    (define x (first numbers))
    (define y (second numbers))
    (define positional `(Point new ,x ,y))
    (for ([labeled (in-list `((Point new* (x ,x) (y ,y))
                              (Point new* (y ,y) (x ,x))))])
      (check-equal? (checked-type state labeled) type)
      (check-equal? (checked-type state labeled) (checked-type state positional))
      (define value (driver-eval! state labeled))
      (check-eq? (instance-value-constructor value) 'new)
      (check-equal? value (driver-eval! state positional))
      (check-equal? (driver-eval! state `(,labeled x)) x)
      (check-equal? (driver-eval! state `(,labeled y)) y)
      (check-equal? (driver-eval! state `(check ,labeled ,positional)) value)))
  (check-equal?
   (driver-eval! state '((Point new 1.0 2.0) + (Point new 3.0 4.0)))
   (driver-eval! state '(Point new 4.0 6.0)))
  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3)
  (check-equal? (driver-eval! state '((ExplicitPoint new 1 2) case (new (x y) x))) 1)
  (check-equal? (driver-eval! state '((ExplicitPoint new 1 2) case (new (x y) y))) 2)
  (check-eq? (instance-value-constructor (driver-eval! state '(Option Some "x")))
             'Some)
  (check-true (driver-eval! state '((Option Some "x") present?)))
  (check-false (driver-eval! state '((if #t (Option None) (Option Some "x")) present?)))
  (check-type-failure state '(define n (Option None)) #rx"cannot infer" #rx"T"))

(test-case "reflection retains only the existing constructor row and field rows"
  (define state (make-fixture))
  (for ([labeled (in-list '((Point new* (x 1) (y 2))
                            (Point new* (y 2) (x 1))))])
    (for ([row-kind (in-list '(messages signatures))])
      (check-equal?
       (driver-eval! state `((Mirror of ,labeled) ,row-kind))
       (driver-eval! state `((Mirror of (Point new 1 2)) ,row-kind)))))
  (check-equal?
   (driver-eval! state '((Mirror of Point) messages))
   (driver-eval! state '(List of (Symbol intern "new"))))
  (check-equal? (driver-eval! state '(((Mirror of Point) signatures) len)) 1)
  (check-equal?
   (driver-eval! state '((((Mirror of Point) signatures) first) selector))
   (driver-eval! state '(Symbol intern "new")))
  (for ([subject (in-list '(Point (Point new 1 2)
                                 (Point new* (y 2) (x 1))))])
    (for ([row-kind (in-list '(messages signatures))])
      (check-false
       (regexp-match? #rx"new\\*"
                      (aloe-value->string
                       (driver-eval! state `((Mirror of ,subject) ,row-kind))))))))

(test-case "aliases, computed receivers, literal names, and surrounding bindings"
  (define state (make-fixture))
  (for ([receiver (in-list '(also-point (if #t Point also-point)))])
    (check-equal? (driver-eval! state `(,receiver new* (y 2) (x 1)))
                  (driver-eval! state '(Point new 1 2))))
  (load-source! state "(define x 5)\n(define new* 12)\n(define x: 123)")
  (check-equal? (driver-eval! state '(Point new* (y (x + 1)) (x 10)))
                (driver-eval! state '(Point new 10 6)))
  (check-equal? (driver-eval! state '(Point new* (x new*) (y x:)))
                (driver-eval! state '(Point new 12 123)))
  (load-source! state "(define-class Colon (fields (x: Int)) (methods))")
  (check-equal? (driver-eval! state '((Colon new* (x: x:)) x:)) 123)
  (check-type-failure state '(Colon new* (x 1)) #rx"unknown field" #rx"x")
  ;; Without bindings for x or y, the first fixture's labels already worked.
  (check-type-failure state '((if #t Point Other) new* (bad missing))
                      #rx"type mismatch")
  (check-type-failure state '(missing-receiver new* (bad missing-value))
                      #rx"unbound symbol" #rx"missing-receiver"))

(test-case "shape errors precede all receiver, name, and value checking"
  (define state (make-fixture))
  (for ([bad (in-list '(1 x () (x) (x 1 2) (x . 1) (x 1 . 2)
                         (1 2) ("x" 1) (() 1) (#:x 1)))])
    (check-exn
     (failure-matches? exn:fail:contract? (list #rx"malformed new\\* binding"))
     (lambda () (driver-eval! state `(missing-receiver new* (y missing-value) ,bad)))))
  (check-exn #rx"malformed combination"
             (lambda () (driver-eval! state '(IntPoint new* (x 1) . rest))))
  (check-exn #rx"empty combination"
             (lambda () (driver-eval! state '(IntPoint new* (x ()) (y 2))))))

(define diagnostic-cases
  (list
   (list '(IntPoint new* (z missing) (x 1) (x 2)) #rx"unknown field" #rx"z")
   (list '(IntPoint new* (x missing) (x 2) (z 3)) #rx"duplicate field" #rx"x")
   (list '(IntPoint new* (y "bad")) #rx"missing fields" #rx"x")
   (list '(IntPoint new* (x missing)) #rx"missing fields" #rx"y")
   (list '(IntPoint new*) #rx"missing fields" #rx"x.*y")
   (list '(IntPoint new* (y 2) (x 1) (z 3)) #rx"unknown field" #rx"z")
   (list '(IntPoint new* (y 2) (x 1) (y 3)) #rx"duplicate field" #rx"y")))

(test-case "name diagnostics precede values and preserve first-offending order"
  (define state (make-fixture))
  (for ([entry (in-list diagnostic-cases)])
    (apply check-type-failure state (car entry) (cdr entry)))
  (check-type-failure state '(IntPoint new 1) #rx"arity")
  (check-type-failure state '(IntPoint new 1 2 3) #rx"arity")
  (check-type-failure state '(IntPoint nonexistent 1 2) #rx"unknown message")
  (check-type-failure state '(IntPoint new* (x "bad") (y 2)) #rx"type mismatch")
  (check-type-failure state '(IntPoint new* (y missing) (x 1))
                      #rx"unbound symbol" #rx"missing")
  (for ([datum (in-list '((IntPoint new* (x absent-x) (y "bad"))
                          (IntPoint new* (y "bad") (x absent-x))))])
    (check-type-failure state datum #rx"unbound symbol" #rx"absent-x")))

(test-case "eligibility uses declaration provenance, including empty declarations"
  (define state (make-fixture))
  (check-equal? (driver-eval! state '(Empty new*)) (driver-eval! state '(Empty new)))
  (check-eq? (instance-value-constructor (driver-eval! state '(Empty new*))) 'new)
  (check-eq? (instance-value-constructor (driver-eval! state '(ExplicitEmpty new))) 'new)
  (for ([receiver (in-list '(ExplicitEmpty ExplicitPoint Option
                                          (IntPoint new 1 2)
                                          List Int String Symbol Mirror 1))])
    (check-type-failure state `(,receiver new* (bad missing))
                        #rx"ineligible new\\*"))
  (check-type-failure state '(GenericEmpty new*) #rx"cannot infer" #rx"T")
  (check-type-failure state '(GenericEmpty new) #rx"cannot infer" #rx"T")
  (check-equal? (checked-type state '((EmptyHolder new (GenericEmpty new*)) box))
                '(GenericEmpty String))
  (check-equal? (checked-type state '((EmptyHolder new (GenericEmpty new)) box))
                '(GenericEmpty String)))

(test-case "generic consistency and expected concrete instances match positional calls"
  (define state (make-fixture))
  (for ([datum (in-list '((Point new 1 2.0)
                          (Point new* (x 1) (y 2.0))
                          (Point new* (y 2.0) (x 1))))])
    (check-type-failure state datum #rx"inconsistent|type mismatch"))
  (for ([bindings (in-list '(((items (List empty)) (measure (fn (s) (s len))))
                             ((measure (fn (s) (s len))) (items (List empty)))))])
    (define value `((ContextHolder new (GenericContext new* ,@bindings)) box))
    (check-equal? (checked-type state value) '(GenericContext String))
    (check-equal? (checked-type state `(,value items)) '(List String))
    (check-equal? (driver-eval! state `((,value items) len)) 0)
    (check-equal? (driver-eval! state `((,value measure) call "abc")) 3))
  (define positional
    '((ContextHolder new (GenericContext new (List empty) (fn (s) (s len)))) box))
  (check-equal? (checked-type state positional) '(GenericContext String))
  (check-equal? (driver-eval! state `((,positional measure) call "abc")) 3))

(test-case "receiver then source-order effects recur on every prepared run"
  (define-values (state events) (make-traced-fixture))
  (for ([bindings (in-list '(((x (trace mark "x" 1)) (y (trace mark "y" 2)))
                             ((y (trace mark "y" 2)) (x (trace mark "x" 1)))))]
        [order (in-list '(("receiver" "x" "y") ("receiver" "y" "x")))])
    (set-box! events '())
    (define datum `((if (trace test "receiver") Point also-point) new* ,@bindings))
    (define run (driver-prepare! state datum))
    (check-equal? (unbox events) '())
    (check-equal? (run) (driver-eval! state '(Point new 1 2)))
    (check-equal? (unbox events) order)
    (check-equal? (run) (driver-eval! state '(Point new 1 2)))
    (check-equal? (unbox events) (append order order)))
  (for ([datum (in-list
               '(((if (trace test "receiver") IntPoint IntPoint) new*
                  (x (trace mark "x" 1)))
                 ((if (trace test "receiver") IntPoint IntPoint) new*
                  (z (trace mark "z" 1)) (x (trace mark "x" 2)))
                 (IntPoint new* (x (trace mark "x" 1)) (y "bad"))
                 ((if (trace test "receiver") Point Other) new*
                  (x (trace mark "x" 1)) (y (trace mark "y" 2)))))])
    (set-box! events '())
    (check-exn exn:fail:aloe-type? (lambda () (driver-eval! state datum)))
    (check-equal? (unbox events) '())))

(test-case "raw evaluation checks eligibility and all names before value effects"
  (define-values (state events) (make-traced-fixture))
  (define (raw datum) (eval-expr (parse-datum datum) (driver-runtime-environment state)))
  (for ([entry (in-list diagnostic-cases)])
    (check-exn (failure-matches? exn:fail? (cons #rx"^eval-aloe:" (cdr entry)))
               (lambda () (raw (car entry)))))
  (for ([receiver (in-list '(ExplicitEmpty ExplicitPoint Option
                                          (IntPoint new 1 2)
                                          List Int String Symbol Mirror 1))])
    (check-exn #rx"eval-aloe: ineligible new\\*"
               (lambda () (raw `(,receiver new* (bad (trace mark "bad" 1)))))))
  (check-equal? (unbox events) '())
  (for ([tail (in-list '(((z (trace mark "z" 1)) (x 1) (x 2))
                         ((x (trace mark "x" 1)) (x 2) (z 3))
                         ((y (trace mark "y" 2))) ()))]
        [pattern (in-list '(#rx"unknown field.*z" #rx"duplicate field.*x"
                            #rx"missing fields.*x" #rx"missing fields.*x.*y"))])
    (set-box! events '())
    (check-exn pattern
               (lambda ()
                 (raw `((if (trace test "receiver") IntPoint IntPoint) new* ,@tail))))
    (check-equal? (unbox events) '("receiver")))
  (check-equal? (raw '(Empty new*)) (raw '(Empty new)))
  (set-box! events '())
  (check-equal? (raw '(IntPoint new* (y (trace mark "y" 2)) (x (trace mark "x" 1))))
                (raw '(IntPoint new 1 2)))
  (check-equal? (unbox events) '("y" "x")))

(test-case "list and function fields keep context while effects follow written order"
  (define-values (state events) (make-traced-fixture))
  (for ([effectful? (in-list '(#f #t))])
    (define items
      (if effectful?
          '(if (trace test "items") (List empty) (List empty))
          '(List empty)))
    (define measure
      (if effectful?
          '(if (trace test "measure") (fn (s) (s len)) (fn (s) (s len)))
          '(fn (s) (s len))))
    (for ([bindings (in-list `(((items ,items) (measure ,measure))
                               ((measure ,measure) (items ,items))))]
          [order (in-list '(("items" "measure") ("measure" "items")))])
      (define datum `(Context new* ,@bindings))
      (check-equal? (checked-type state datum) 'Context)
      (check-equal? (checked-type state `(,datum items)) '(List String))
      (define run (driver-prepare! state `(define observed ,datum)))
      (set-box! events '())
      (run)
      (check-equal? (unbox events) (if effectful? order '()))
      (check-equal? (driver-eval! state '((observed items) len)) 0)
      (check-true (driver-eval! state '((observed items) empty?)))
      (check-equal? (driver-eval! state '((observed measure) call "abc")) 3)
      (check-equal?
       (driver-eval! state '(check (observed items) (List empty)))
       (driver-eval! state '((Context new (List empty) (fn (s) (s len))) items)))
      (check-equal?
       (driver-eval! state '((observed measure) call "abc"))
       (driver-eval! state '(((Context new (List empty) (fn (s) (s len))) measure) call "abc"))))))

(define (make-fields-fixture fields)
  (define state (make-driver))
  (driver-eval! state `(define-class Record (fields ,@fields) (methods)))
  state)

(test-case "declaration changes expose positional associations and labeled stability"
  (define labeled '(Record new* (y 20) (x 10)))
  (define positional '(Record new 10 20))
  (for ([fields (in-list '(((x Int) (y Int)) ((y Int) (x Int))))]
        [positional-x (in-list '(10 20))]
        [positional-y (in-list '(20 10))])
    (define state (make-fields-fixture fields))
    (check-equal? (checked-type state positional) 'Record)
    (check-equal? (driver-eval! state `(,labeled x)) 10)
    (check-equal? (driver-eval! state `(,labeled y)) 20)
    (check-equal? (driver-eval! state `(,positional x)) positional-x)
    (check-equal? (driver-eval! state `(,positional y)) positional-y))
  (for ([fields (in-list '(((x Int) (y String)) ((y String) (x Int))))]
        [positional-ok? (in-list '(#t #f))])
    (define state (make-fields-fixture fields))
    (define typed-positional '(Record new 10 "twenty"))
    (define typed-labeled '(Record new* (y "twenty") (x 10)))
    (check-equal? (driver-eval! state `(,typed-labeled x)) 10)
    (check-equal? (driver-eval! state `(,typed-labeled y)) "twenty")
    (if positional-ok?
        (check-equal? (checked-type state typed-positional) 'Record)
        (check-type-failure state typed-positional #rx"type mismatch")))
  (check-type-failure (make-fields-fixture '((renamed Int) (y Int))) labeled
                      #rx"unknown field" #rx"x")
  (for ([fields (in-list '(((x Int) (y Int) (z Int)) ((x Int))))]
        [category (in-list '(#rx"missing fields.*z" #rx"unknown field.*y"))])
    (define state (make-fields-fixture fields))
    (check-type-failure state labeled category)
    (check-type-failure state positional #rx"arity")))
