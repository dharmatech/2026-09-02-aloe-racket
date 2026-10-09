#lang racket/base

(require rackunit
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
    (set-x (x T) (Point T)
      (self with (x x)))
    (swap () (Point T)
      (self with (x (self y)) (y (self x))))))
(define-class Record
  (fields (a Int) (b String) (c Bool) (d Float))
  (methods))
(define-class (Box T) (fields (value T) (flag Bool)) (methods))
(define-class (ListBox T) (fields (items (List T)) (flag Bool)) (methods))
(define-class Holder (fields (inner (Point Int)) (label String)) (methods))
(define-class Context
  (fields (items (List String)) (measure (-> String Int)))
  (methods))
(define-class Empty (fields) (methods))
(define-class ExplicitPoint
  (constructors (new (fields (x Int) (y Int)))) (methods))
(define-class (Option T)
  (constructors (None (fields)) (Some (fields (value T))))
  (methods))
(define-protocol Shape (area () Int))
(define-class Square Shape
  (fields (side Int))
  (methods (area () Int ((self side) * (self side)))))
(define-class Factory (fields) (methods (make () Shape (Square new 2))))
(define p (Point new 1 2))
(define q (Point new 3 4))
ALOE
  )

(define (load-source! state source)
  (void (driver-load-port! state (open-input-string source) (open-output-string))))

(define (make-fixture)
  (define state (make-driver))
  (load-source! state fixture-source)
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

(define (check-syntax-failure state datum . patterns)
  (check-exn (failure-matches? exn:fail:contract?
                               (cons #rx"parse-datum:" patterns))
             (lambda () (driver-eval! state datum))))

;; The capability is test-only and explicitly injected. Its state records
;; effects; Aloe programs themselves remain immutable.
(define trace-interface
  (make-host-interface
   'UpdateTrace
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

(define (check-update state datum type positional)
  (check-equal? (checked-type state datum) type)
  (define value (driver-eval! state datum))
  (check-eq? (instance-value-constructor value) 'new)
  (check-equal? value (driver-eval! state positional))
  (check-equal? (driver-eval! state `(check ,datum ,positional)) value))

(test-case "one field and several fields equal positional new of the assembled payload"
  (define state (make-fixture))
  (check-update state '((Point new 1 2) with (x 3)) '(Point Int) '(Point new 3 2))
  (check-update state '(p with (y 5)) '(Point Int) '(Point new 1 5))
  (check-update state '(p with (y 5) (x 4)) '(Point Int) '(Point new 4 5))
  (check-update state '((Point new 1.0 2.0) with (y 5.0)) '(Point Float)
                '(Point new 1.0 5.0))
  (define record '(Record new 1 "b" #t 1.0))
  (check-update state `(,record with (d 2.0)) 'Record '(Record new 1 "b" #t 2.0))
  (check-update state `(,record with (d 2.0) (b "z") (a 7)) 'Record
                '(Record new 7 "z" #t 2.0))
  (check-update state `(,record with (c #f) (a 0) (d 0.5) (b ""))
                'Record '(Record new 0 "" #f 0.5))
  ;; The receiver is unchanged.
  (check-equal? (driver-eval! state 'p) (driver-eval! state '(Point new 1 2)))
  (check-equal? (driver-eval! state '(((Point new 1 2) with (x 3)) x)) 3)
  (check-equal? (driver-eval! state '(((Point new 1 2) with (x 3)) y)) 2))

(test-case "computed receivers with one eligible instance type are legal"
  (define state (make-fixture))
  (for ([receiver (in-list '((if #t p q) (let ((r p)) r) ((Point new 1 2) set-x 1)))])
    (check-update state `(,receiver with (x 9)) '(Point Int) '(Point new 9 2)))
  (check-update state '(let ((r p)) (r with (y (r x)))) '(Point Int)
                '(Point new 1 1)))

(test-case "omitted slots are the receiver's stored values, not reconstructions"
  (define state (make-fixture))
  (load-source!
   state
   (string-append
    "(define h (Holder new (Point new 1 2) \"a\"))\n"
    "(define h2 (h with (label \"b\")))\n"
    "(define c (Context new (List of \"x\") (fn (s) (s len))))\n"
    "(define c2 (c with (items (List of \"y\" \"z\"))))\n"))
  (check-eq? (driver-eval! state '(h2 inner)) (driver-eval! state '(h inner)))
  (check-equal? (driver-eval! state '(h2 label)) "b")
  (check-eq? (driver-eval! state '(c2 measure)) (driver-eval! state '(c measure)))
  (check-equal? (driver-eval! state '((c2 items) len)) 2))

(test-case "each value sees the original receiver"
  (define state (make-fixture))
  (check-update state '(p with (x (p y)) (y (p x))) '(Point Int) '(Point new 2 1))
  (check-update state '(p with (y (p x)) (x (p y))) '(Point Int) '(Point new 2 1))
  (check-update state '(p swap) '(Point Int) '(Point new 2 1))
  (check-update state '((Point new 1.0 2.0) swap) '(Point Float)
                '(Point new 2.0 1.0)))

(test-case "names are literal fields and bind nothing"
  (define state (make-fixture))
  (check-update state '(p set-x 9) '(Point Int) '(Point new 9 2))
  (check-update state '((Point new 1.0 2.0) set-x 9.0) '(Point Float)
                '(Point new 9.0 2.0))
  (check-type-failure state '(p with (x x)) #rx"unbound symbol" #rx"x")
  (check-type-failure state '(p with (x 1) (y x)) #rx"unbound symbol" #rx"x")
  (load-source! state "(define x 40)\n(define with 7)")
  (check-update state '(p with (x x)) '(Point Int) '(Point new 40 2))
  (check-update state '(p with (y with)) '(Point Int) '(Point new 1 7)))

(test-case "receiver then written-order value effects on every prepared run"
  (define-values (state events) (make-traced-fixture))
  (for ([bindings (in-list '(((x (trace mark "x" 5)) (y (trace mark "y" 6)))
                             ((y (trace mark "y" 6)) (x (trace mark "x" 5)))))]
        [order (in-list '(("receiver" "x" "y") ("receiver" "y" "x")))])
    (set-box! events '())
    (define datum `((if (trace test "receiver") p q) with ,@bindings))
    (define run (driver-prepare! state datum))
    (check-equal? (unbox events) '())
    (check-equal? (run) (driver-eval! state '(Point new 5 6)))
    (check-equal? (unbox events) order)
    (check-equal? (run) (driver-eval! state '(Point new 5 6)))
    (check-equal? (unbox events) (append order order)))
  (for ([datum (in-list
                '(((if (trace test "receiver") p q) with
                   (z (trace mark "z" 1)) (x (trace mark "x" 2)))
                  ((if (trace test "receiver") p q) with
                   (x (trace mark "x" 1)) (x (trace mark "x" 2)))
                  (p with (x (trace mark "x" 1)) (y "bad"))
                  ((if (trace test "receiver") Point Point) with
                   (x (trace mark "x" 1)))))])
    (set-box! events '())
    (check-exn exn:fail:aloe-type? (lambda () (driver-eval! state datum)))
    (check-equal? (unbox events) '())))

(define diagnostic-cases
  (list
   (list '(p with (z 1) (x 1) (x 2)) #rx"unknown field z")
   (list '(p with (x 1) (x 2) (z 3)) #rx"duplicate field x")
   (list '(p with (y 1) (z 2) (y 3)) #rx"unknown field z")
   (list '(p with (y 1) (y 2) (z 3)) #rx"duplicate field y")
   (list '((Option Some 1) with (value 2)) #rx"ineligible with")
   (list '(Point with (x 1)) #rx"ineligible with" #rx"Point")))

(test-case "the diagnostic table names categories and fields"
  (define state (make-fixture))
  (for ([entry (in-list diagnostic-cases)])
    (apply check-type-failure state (car entry) (cdr entry)))
  (check-exn (lambda (failure)
               (not (regexp-match? #rx"z|unknown" (exn-message failure))))
             (lambda () (driver-eval! state '(p with (x 1) (x 2) (z 3)))))
  (check-type-failure state '(p with (y "bad"))
                      #rx"type mismatch" #rx"field y" #rx"Int" #rx"String")
  (check-type-failure state '(p with (x 1.0)) #rx"type mismatch" #rx"field x")
  (check-type-failure state '((Point new 1 2) with (x 1.0))
                      #rx"type mismatch" #rx"field x")
  (check-syntax-failure state '(p with) #rx"with requires at least one")
  (check-syntax-failure state '((Empty new) with) #rx"with requires at least one")
  (check-syntax-failure state '(p with (x)) #rx"malformed with binding")
  (check-type-failure state '((Empty new) with (a 1)) #rx"unknown field a"))

(test-case "receiver errors, then names, then values in declaration order"
  (define state (make-fixture))
  (check-type-failure state '(missing with (z missing-value))
                      #rx"unbound symbol" #rx"missing")
  (check-type-failure state '(Point with (z missing-value))
                      #rx"ineligible with")
  (check-type-failure state '(p with (x missing-value) (z 1)) #rx"unknown field z")
  (check-type-failure state '(p with (x missing-value) (x 1)) #rx"duplicate field x")
  (for ([datum (in-list '((p with (y "bad") (x absent-x))
                          (p with (x absent-x) (y "bad"))))])
    (check-type-failure state datum #rx"unbound symbol" #rx"absent-x"))
  (for ([datum (in-list '((p with (y absent-y) (x "bad"))
                          (p with (x "bad") (y absent-y))))])
    (check-type-failure state datum #rx"type mismatch" #rx"field x")))

(test-case "eligibility requires a concrete fields-class instance"
  (define state (make-fixture))
  (for ([receiver (in-list '(Point Record Empty ExplicitPoint Option List Int String
                                   Symbol Mirror 1 1.0 "s" #t
                                   (ExplicitPoint new 1 2) (Option Some 1)
                                   (List of 1 2) (List of 1)
                                   (fn (a) a) (Symbol intern "x") (Mirror of p)
                                   ((Factory new) make)))])
    (check-type-failure state `(,receiver with (x 1)) #rx"ineligible with"))
  (check-type-failure state '(((Factory new) make) with (side 3))
                      #rx"ineligible with" #rx"Shape")
  (check-update state '((Square new 2) with (side 3)) 'Square '(Square new 3))
  (check-equal? (driver-eval! state '(((Square new 2) with (side 3)) area)) 9)
  ;; An unapplied fn parameter is still a type variable, not a concrete instance.
  (check-type-failure state '(fn (r) (r with (x 1))) #rx"ineligible with"))

(test-case "known type arguments are kept and checked, not replaced"
  (define state (make-fixture))
  (check-update state '((Box new 1 #t) with (flag #f)) '(Box Int) '(Box new 1 #f))
  (check-update state '((Box new "s" #t) with (flag #f)) '(Box String)
                '(Box new "s" #f))
  (check-update state '((Box new 1 #t) with (value 2)) '(Box Int) '(Box new 2 #t))
  (check-type-failure state '((Box new 1 #t) with (value "s"))
                      #rx"type mismatch" #rx"field value" #rx"Int")
  (check-type-failure state '((Box new 1 #t) with (value 2.0))
                      #rx"type mismatch" #rx"field value")
  (check-type-failure state '((Box new 1 #t) with (flag 0))
                      #rx"type mismatch" #rx"field flag" #rx"Bool")
  (check-equal? (checked-type state '(Holder new ((Holder new p "a") inner) "b"))
                'Holder)
  ;; The field type is pushed into a nested construction, which reports its
  ;; own payload mismatch exactly as positional construction would.
  (check-type-failure state '((Holder new p "a") with (inner (Point new 1.0 2.0)))
                      #rx"type mismatch")
  (check-type-failure state '((Holder new p "a") with (inner "p"))
                      #rx"type mismatch" #rx"field inner" #rx"Point"))

(test-case "a replacement may instantiate a receiver's unknown type argument"
  (define state (make-fixture))
  (define receiver '(if #t (ListBox new (List empty) #t) (ListBox new (List empty) #f)))
  (check-update state `(,receiver with (items (List of 1))) '(ListBox Int)
                '(ListBox new (List of 1) #t))
  (check-type-failure state `(,receiver with (flag #f)) #rx"cannot infer" #rx"T"))

(test-case "function and list fields are checked against their field types"
  (define state (make-fixture))
  (load-source! state "(define c (Context new (List empty) (fn (s) (s len))))")
  (define updated '(c with (measure (fn (s) ((s len) + 1))) (items (List empty))))
  (check-equal? (checked-type state updated) 'Context)
  (check-equal? (driver-eval! state `((,updated measure) call "abc")) 4)
  (check-equal? (driver-eval! state `((,updated items) len)) 0)
  ;; The parameter receives String from the field type.
  (check-type-failure state '(c with (measure (fn (s) (s + 1)))) #rx"unknown message")
  (check-type-failure state '(c with (items (List of 1)))
                      #rx"type mismatch" #rx"field items"))

(test-case "a nested with is an ordinary value expression"
  (define state (make-fixture))
  (load-source! state "(define h (Holder new (Point new 1 2) \"a\"))")
  (check-update state '(h with (inner ((h inner) with (x 10))))
                'Holder '(Holder new (Point new 10 2) "a"))
  (check-update state '(p with (x ((p with (x 7)) x))) '(Point Int) '(Point new 7 2))
  (check-update state '((p with (x 5)) with (y 6)) '(Point Int) '(Point new 5 6))
  (check-type-failure state '(h with (inner ((h inner) with (z 10))))
                      #rx"unknown field z"))

(test-case "raw evaluation checks eligibility and names before value effects"
  (define-values (state events) (make-traced-fixture))
  (define (raw datum) (eval-expr (parse-datum datum) (driver-runtime-environment state)))
  (for ([entry (in-list diagnostic-cases)])
    (check-exn (failure-matches? exn:fail? (list #rx"^eval-aloe:" (cadr entry)))
               (lambda () (raw (car entry)))))
  (for ([receiver (in-list '(Point ExplicitPoint Option List Int String Symbol
                                   Mirror 1 "s" (ExplicitPoint new 1 2)
                                   (Option Some 1) (List of 1)))])
    (check-exn #rx"eval-aloe: ineligible with"
               (lambda () (raw `(,receiver with (x (trace mark "x" 1)))))))
  (check-equal? (unbox events) '())
  (for ([tail (in-list '(((z (trace mark "z" 1)) (x (trace mark "x" 1)))
                         ((x (trace mark "x" 1)) (x (trace mark "x" 2)) (z 3))))]
        [pattern (in-list '(#rx"unknown field z" #rx"duplicate field x"))])
    (set-box! events '())
    (check-exn pattern
               (lambda () (raw `((if (trace test "receiver") p q) with ,@tail))))
    (check-equal? (unbox events) '("receiver")))
  (set-box! events '())
  (check-equal? (raw '((if (trace test "receiver") p q)
                       with (y (trace mark "y" 6)) (x (trace mark "x" 5))))
                (raw '(Point new 5 6)))
  (check-equal? (unbox events) '("receiver" "y" "x"))
  ;; Raw evaluation is not the checker; a protocol-typed value is still an
  ;; instance of its fields class at runtime.
  (check-equal? (raw '(((Factory new) make) with (side 3))) (raw '(Square new 3))))

(test-case "new* still requires every field"
  (define state (make-fixture))
  (check-type-failure state '(Point new* (x 1)) #rx"missing fields" #rx"y")
  (check-type-failure state '(Record new* (d 1.0) (a 1)) #rx"missing fields" #rx"b.*c")
  (check-equal? (driver-eval! state '(Point new* (y 2) (x 1)))
                (driver-eval! state '(Point new 1 2))))

(test-case "reflection exposes no with row"
  (define state (make-fixture))
  (for ([row-kind (in-list '(messages signatures))])
    (check-equal? (driver-eval! state `((Mirror of (p with (x 3))) ,row-kind))
                  (driver-eval! state `((Mirror of (Point new 3 2)) ,row-kind)))
    (for ([subject (in-list '(Point p (p with (x 3)) Record
                                    (Record new 1 "b" #t 1.0)))])
      (check-false
       (regexp-match? #rx"with"
                      (aloe-value->string
                       (driver-eval! state `((Mirror of ,subject) ,row-kind)))))))
  (check-equal? (driver-eval! state '((Mirror of Point) messages))
                (driver-eval! state '(List of (Symbol intern "new")))))

(test-case "with remains an ordinary source name outside the selector position"
  (define state (make-fixture))
  (check-equal? (driver-eval! state '(define with 1)) (void))
  (check-equal? (driver-eval! state 'with) 1)
  (check-equal? (driver-eval! state '(with + 1)) 2)
  (check-syntax-failure state '(with p (x 1)) #rx"selector must be a symbol")
  (check-type-failure state '(with p (x y)) #rx"unknown message" #rx"p")
  ;; A method may still be named with; the selector position is the syntax.
  (load-source! state "(define-class Odd (fields (a Int)) (methods (with () Int 1)))")
  (check-equal? (driver-eval! state '((Odd new 1) a)) 1)
  (check-syntax-failure state '((Odd new 1) with) #rx"with requires at least one")
  (check-update state '((Odd new 1) with (a 2)) 'Odd '(Odd new 2)))
