#lang racket/base

(require racket/match
         "../parse.rkt")

(provide select-expression-at-position
         expression-contains-node?)

(define (expression-children expression)
  (match expression
    [(int-expr _ _) '()]
    [(float-expr _ _) '()]
    [(bool-expr _ _) '()]
    [(string-expr _ _) '()]
    [(variable-expr _ _) '()]
    [(load-expr _ _ _) '()]
    [(define-protocol-expr _ _ _) '()]
    [(check-expr left right _ _ _)
     (list left right)]
    [(define-expr _ value _)
     (list value)]
    [(define-class-expr _ _ _ _ _ methods _)
     (map method-declaration-body methods)]
    [(define-methods-expr _ methods _)
     (map method-declaration-body methods)]
    [(fn-expr _ body _)
     (list body)]
    [(case-expr scrutinee clauses else-body _)
     (append (list scrutinee)
             (map case-clause-body clauses)
             (if else-body (list else-body) '()))]
    [(send-expr receiver _ arguments _ _)
     (cons receiver arguments)]))

(define (select-expression-at-position expressions position)
  (define (containing? expression)
    (define loc (expression-loc expression))
    (and loc
         (<= (srcloc-position loc) position)
         (< position
            (+ (srcloc-position loc)
               (srcloc-span loc)))))

  (define (visit expression winner)
    (define candidate
      (cond
        [(not (containing? expression)) winner]
        [(not winner) expression]
        [(< (srcloc-span (expression-loc expression))
            (srcloc-span (expression-loc winner)))
         expression]
        [else winner]))
    (for/fold ([current candidate])
              ([child (in-list (expression-children expression))])
      (visit child current)))

  (for/fold ([winner #f])
            ([expression (in-list expressions)])
    (visit expression winner)))

(define (expression-contains-node? root target)
  (or (eq? root target)
      (for/or ([child (in-list (expression-children root))])
        (expression-contains-node? child target))))
