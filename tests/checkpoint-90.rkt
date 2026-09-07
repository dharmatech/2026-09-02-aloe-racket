#lang racket/base

(require rackunit
         "../aloe/parse.rkt")

(define point
  (parse-datum
   '(define-class Point
      (fields (x Int) (y Int))
      (methods))))

;; The existing fields surface form remains distinct for the evaluator and
;; checker, where it continues to provide the generated `new` constructor.
(check-true (define-class-expr? point))
(check-equal?
 (map field-declaration-name (define-class-expr-fields point))
 '(x y))
(check-false (define-class-expr-constructors point))

(define option
  (parse-datum
   '(define-class (Option T)
      (constructors
        (None (fields))
        (Some (fields (value T))))
      (methods
        (present? () Bool
          (self case
            (None () #f)
            (Some (value) #t)))))))

(check-true (define-class-expr? option))
(check-false (define-class-expr-fields option))
(check-equal?
 (map constructor-declaration-selector
      (define-class-expr-constructors option))
 '(None Some))
(check-equal?
 (map (lambda (constructor)
        (map field-declaration-name
             (constructor-declaration-fields constructor)))
      (define-class-expr-constructors option))
 '(() (value)))

(define present-body
  (method-declaration-body (car (define-class-expr-methods option))))
(check-true (case-expr? present-body))
(check-false (send-expr? present-body))
(check-equal? (map case-clause-selector (case-expr-clauses present-body))
              '(None Some))
(check-equal? (map case-clause-payload-names
                   (case-expr-clauses present-body))
              '(() (value)))
(check-false (case-expr-else-body present-body))

;; A protocol opt-in and a final else clause use the same new syntax.
(define with-else
  (parse-datum
   '(define-class Result Printable
      (constructors
        (Ok (fields (value String)))
        (Error (fields (message String))))
      (methods
        (text () String
          (self case
            (Ok (value) value)
            (else "error")))))))
(check-eq? (define-class-expr-protocol with-else) 'Printable)
(define with-else-body
  (method-declaration-body
   (car (define-class-expr-methods with-else))))
(check-equal? (map case-clause-selector (case-expr-clauses with-else-body))
              '(Ok))
(check-equal? (case-expr-else-body with-else-body)
              (string-expr "error"))

;; Exhaustiveness and constructor validity are deliberately not parser work.
(check-true
 (case-expr?
  (parse-datum '(option case (Some (value) value)))))
(check-true
 (case-expr?
  (parse-datum '(option case (else #f)))))

(define (check-parse-error datum)
  (check-exn #rx"parse-datum" (lambda () (parse-datum datum))))

;; A declaration has exactly one data section.
(check-parse-error
 '(define-class Mixed
    (fields (value Int))
    (constructors (Other (fields)))
    (methods)))
(check-parse-error
 '(define-class Mixed
    (constructors (Other (fields)))
    (fields (value Int))
    (methods)))

;; Constructors are nonempty, well shaped, and uniquely selected.
(check-parse-error
 '(define-class Empty (constructors) (methods)))
(check-parse-error
 '(define-class Bad (constructors (Only)) (methods)))
(check-parse-error
 '(define-class Bad (constructors (Only (value Int))) (methods)))
(check-parse-error
 '(define-class Duplicate
    (constructors (Same (fields)) (Same (fields (value Int))))
    (methods)))

;; `case` is reserved syntax and validates only its clause grammar here.
(check-parse-error '(option case))
(check-parse-error '(option case (else #f) (Some (value) value)))
(check-parse-error '(option case (Some value value)))
(check-parse-error '(option case (Some (value))))
(check-parse-error '(option case (Some (1) #t)))
(check-parse-error '(option case (else () #f)))
