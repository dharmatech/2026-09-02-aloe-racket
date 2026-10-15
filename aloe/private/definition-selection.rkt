#lang racket/base

(require racket/match
         "../parse.rkt"
         (only-in "expression-selection.rkt"
                  expression-children))

(provide (struct-out name-token)
         select-name-token-at-position)

;; A name token is a symbol a definition query can jump from: a variable, the
;; class name of a define-class header, or the target of a define-methods form.
;; Its owner is the node the checker observes for it.
(struct name-token (owner symbol loc) #:transparent)

(define (expression-name-tokens expression)
  (match expression
    [(variable-expr name loc)
     (list (name-token expression name loc))]
    [(define-class-expr name _ _ _ _ _ _ name-loc)
     (list (name-token expression name name-loc))]
    [(define-methods-expr target _ _ target-loc)
     (list (name-token expression target target-loc))]
    [_ '()]))

;; Tokens never overlap, so at most one contains the position.
(define (select-name-token-at-position expressions position)
  (define (containing? token)
    (define loc (name-token-loc token))
    (and loc
         (<= (srcloc-position loc) position)
         (< position
            (+ (srcloc-position loc)
               (srcloc-span loc)))))

  (define (visit expression)
    (or (for/first ([token (in-list (expression-name-tokens expression))]
                    #:when (containing? token))
          token)
        (for/or ([child (in-list (expression-children expression))])
          (visit child))))

  (for/or ([expression (in-list expressions)])
    (visit expression)))
