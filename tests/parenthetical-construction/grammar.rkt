#lang racket/base

(require rackunit
         racket/list
         racket/match
         "../../aloe/parse.rkt"
         "../../aloe/private/expression-selection.rkt"
         "../../aloe/private/completion-selection.rkt")

(define (binding-values expression)
  (map construction-binding-value (new-star-expr-bindings expression)))

(define (position-of source text)
  (add1 (caar (regexp-match-positions (regexp (regexp-quote text)) source))))

(define (check-syntax-error datum category)
  (check-exn
   (lambda (failure)
     (and (exn:fail:contract? failure)
          (regexp-match? #rx"parse-datum:" (exn-message failure))
          (regexp-match? category (exn-message failure))))
   (lambda () (parse-datum datum))))

(test-case "construction AST preserves literal names and written order"
  (for ([datum (in-list '((Point new* (x 10) (y 20))
                         (Point new* (y 20) (x 10))
                         (Point new* (unknown 30) (x 10) (x 40))))])
    (define expression (parse-datum datum))
    (check-true (new-star-expr? expression))
    (check-equal? (new-star-expr-receiver expression)
                  (variable-expr 'Point #f))
    (check-equal? (new-star-expr-bindings expression)
                  (for/list ([pair (in-list (cddr datum))])
                    (construction-binding (car pair)
                                          (int-expr (cadr pair) #f)))))
  (check-equal? (parse-datum '(Empty new*))
                (new-star-expr (variable-expr 'Empty #f) '() #f))
  (define nested
    (parse-datum '(Outer new* (point (Point new* (y 2) (x 1))))))
  (check-equal? (binding-values nested)
                (list (parse-datum '(Point new* (y 2) (x 1)))))
  (define computed
    (parse-datum '((if #t Point also-point) new* (x 1) (y 2))))
  (check-equal? (new-star-expr-receiver computed)
                (parse-datum '(if #t Point also-point)))
  (check-equal? (binding-values computed)
                (list (int-expr 1 #f) (int-expr 2 #f)))
  ;; Lists inside values remain ordinary expressions, including sends.
  (check-equal?
   (binding-values (parse-datum '(Point new* (x (source x)) (y (source y)))))
   (list (send-expr (variable-expr 'source #f) 'x '() #f #f)
         (send-expr (variable-expr 'source #f) 'y '() #f #f))))

(test-case "all pair shapes are validated before receiver and value syntax"
  (for ([bad-pair (in-list '(10 x () (x) (x 1 2) (x . 1)
                            (x 1 . 2) (10 1) ("x" 1) (() 1) (#:x 1)))])
    (for ([receiver (in-list '(Point (receiver)))])
      (check-syntax-error `(,receiver new* (valid 1) ,bad-pair)
                          #rx"malformed new\\* binding"))
    (check-syntax-error `(Point new* (valid (value)) ,bad-pair)
                        #rx"malformed new\\* binding"))
  (check-syntax-error '(Point new* (x 1) . tail) #rx"malformed combination")
  ;; Once shapes pass, receiver syntax precedes ordinary value syntax.
  (check-syntax-error '((receiver 10) new* (x ()))
                      #rx"selector must be a symbol")
  (check-syntax-error '(Point new* (x ())) #rx"empty combination")
  (check-syntax-error '(Point new* (x (value))) #rx"no selector")
  (check-syntax-error '(Point new* (x (source 10)))
                      #rx"selector must be a symbol"))

(test-case "positional sends, names, and special-form priority are unchanged"
  (check-equal?
   (parse-datum '(Point new (source x) (source y)))
   (send-expr (variable-expr 'Point #f) 'new
              (list (send-expr (variable-expr 'source #f) 'x '() #f #f)
                    (send-expr (variable-expr 'source #f) 'y '() #f #f))
              #f #f))
  (check-syntax-error '(Point new (x 10) (y 20))
                      #rx"selector must be a symbol")
  (check-equal? (parse-datum 'new*) (variable-expr 'new* #f))
  (check-equal? (parse-datum '(define new* 123))
                (define-expr 'new* (int-expr 123 #f) #f))
  (check-equal? (parse-datum '(new* call x))
                (send-expr (variable-expr 'new* #f) 'call
                           (list (variable-expr 'x #f)) #f #f))
  (check-equal? (parse-datum '(source value new*))
                (send-expr (variable-expr 'source #f) 'value
                           (list (variable-expr 'new* #f)) #f #f))
  (check-equal? (parse-datum '(define x: 123))
                (define-expr 'x: (int-expr 123 #f) #f))
  (check-equal? (parse-datum '(new* new* (x: new*)))
                (new-star-expr
                 (variable-expr 'new* #f)
                 (list (construction-binding 'x: (variable-expr 'new* #f)))
                 #f))
  (check-equal? (parse-datum '(x: value))
                (send-expr (variable-expr 'x: #f) 'value '() #f #f))
  ;; `if` and `define` keep their head-position meaning even with new* second.
  (check-equal? (parse-datum '(if new* 1 2))
                (send-expr (variable-expr 'new* #f) 'if
                           (list (fn-expr '() (int-expr 1 #f) #f)
                                 (fn-expr '() (int-expr 2 #f) #f))
                           #f #f))
  (check-true (case-expr? (parse-datum '(choice case (A () 1)))))
  (check-eq? (send-expr-selector (parse-datum '(let ((x 1)) x))) 'call)
  (check-equal? (parse-datum '(Option Some 1))
                (send-expr (variable-expr 'Option #f) 'Some
                           (list (int-expr 1 #f)) #f #f)))

(test-case "source parsing preserves construction, child, and selector spans"
  (define source "(Point new*\n  (y (source y))\n  (x 10))\n")
  (define source-path (build-path (current-directory) "grammar-spans.aloe"))
  (define expression (first (read-program source #:source-path source-path)))
  (define values (binding-values expression))
  (define nested-send (first values))
  (define (check-location loc line column position span)
    (check-equal? loc (srcloc source-path line column position span)))
  (check-location (expression-loc expression) 1 0 1 38)
  (check-location (expression-loc (new-star-expr-receiver expression)) 1 1 2 5)
  (check-location (expression-loc nested-send) 2 5 18 10)
  (check-location (expression-loc (send-expr-receiver nested-send)) 2 6 19 6)
  (check-location (send-expr-selector-loc nested-send) 2 13 26 1)
  (check-location (expression-loc (second values)) 3 5 35 2))

(define (check-location-free expression)
  (check-false (expression-loc expression))
  (match expression
    [(new-star-expr receiver bindings _)
     (check-location-free receiver)
     (for-each check-location-free (map construction-binding-value bindings))]
    [(send-expr receiver _ arguments _ selector-loc)
     (check-false selector-loc)
     (check-location-free receiver)
     (for-each check-location-free arguments)]
    [(fn-expr _ body _)
     (check-location-free body)]
    [_ (void)]))

(test-case "datum construction trees have no locations and parse deterministically"
  (for ([datum
         (in-list '((Empty new*)
                    ((if #t Point also-point) new*
                     (x (source x))
                     (y (Inner new* (value (source y)))))
                    (Box new* (value (let ((x 1)) (x + 2))))))])
    (define expression (parse-datum datum))
    (check-equal? expression (parse-datum datum))
    (check-location-free expression)
    (check-false (select-expression-at-position (list expression) 1))))

(define (check-selected-and-contained expressions root child)
  (check-eq? (select-expression-at-position
              expressions (srcloc-position (expression-loc child)))
             child)
  (check-true (expression-contains-node? root child)))

(test-case "selection and containment retain receiver and nested value identity"
  (define source
    "((source class) new* (x (Inner new* (part (value len)))) (y 20))")
  (define expressions (read-program source))
  (define root (first expressions))
  (define receiver (new-star-expr-receiver root))
  (define inner (first (binding-values root)))
  (define nested-send (first (binding-values inner)))
  (for ([child (in-list (list receiver (send-expr-receiver receiver)
                              inner (new-star-expr-receiver inner)
                              nested-send (send-expr-receiver nested-send)
                              (second (binding-values root))))])
    (check-selected-and-contained expressions root child))
  (for ([label (in-list '("x" "y" "new*"))])
    (check-eq? (select-expression-at-position expressions (position-of source label))
               root))
  (check-eq? (select-expression-at-position expressions (position-of source "part"))
             inner)
  (check-false (expression-contains-node? root (variable-expr 'x #f)))
  (check-false (expression-contains-node? root (variable-expr 'part #f)))
  (check-false
   (expression-contains-node? root (first (read-program source))))
  (check-false
   (select-expression-at-position expressions (add1 (string-length source)))))

(test-case "construction traversal preserves preorder ties and written binding order"
  (define loc (srcloc #f 1 0 1 10))
  (define child-loc (srcloc #f 1 2 3 1))
  (define receiver (variable-expr 'Point child-loc))
  (define a (int-expr 1 child-loc))
  (define b (int-expr 2 child-loc))
  (define (construction receiver values)
    (new-star-expr receiver
                   (map (lambda (value) (construction-binding 'field value)) values)
                   loc))
  (check-eq? (select-expression-at-position (list (construction receiver (list a b))) 3)
             receiver)
  (define unlocated-receiver (variable-expr 'Point #f))
  (check-eq? (select-expression-at-position
              (list (construction unlocated-receiver (list a b))) 3)
             a)
  (check-eq? (select-expression-at-position
              (list (construction unlocated-receiver (list b a))) 3)
             b)
  (define body (parse-datum '(Point new* (x 1))))
  (define tied (new-star-expr (new-star-expr-receiver body)
                             (new-star-expr-bindings body) loc))
  (define outer (send-expr (fn-expr '() tied loc) 'call '() loc #f))
  (check-eq? (select-expression-at-position (list outer) 2) outer))

(test-case "method bodies retain construction containment and selection"
  (for ([source
         (in-list '("(define-class Sample (fields) (methods (build () Point (Point new* (x (source len))))))"
                    "(define-methods String (methods (build () Point (Point new* (x (source len))))))"))])
    (define expressions (read-program source))
    (define root (first expressions))
    (define methods
      (if (define-class-expr? root)
          (define-class-expr-methods root)
          (define-methods-expr-methods root)))
    (define body (method-declaration-body (first methods)))
    (define value (first (binding-values body)))
    (for ([child (in-list (list body (new-star-expr-receiver body)
                                value (send-expr-receiver value)))])
      (check-selected-and-contained expressions root child)
      (check-true (expression-contains-node? body child)))
    (check-eq? (select-expression-at-position expressions (position-of source "(x"))
               body)))

(define (remove-cursor marked-source)
  (define cursor-index (caar (regexp-match-positions #rx"\\|" marked-source)))
  (values (string-append (substring marked-source 0 cursor-index)
                         (substring marked-source (add1 cursor-index)))
          (add1 cursor-index)))

(define (check-site marked-source expected-text expected-start expected-span)
  (define-values (source position) (remove-cursor marked-source))
  (define site (recover-selector-completion-site source position))
  (check-true (selector-completion-site? site))
  (check-equal? (selector-completion-site-selector-text site) expected-text)
  (check-equal? (selector-completion-site-replacement-start site) expected-start)
  (check-equal? (selector-completion-site-replacement-span site) expected-span)
  (check-equal? (substring source (sub1 expected-start)
                           (+ (sub1 expected-start) expected-span))
                expected-text)
  (define target (selector-completion-site-target-send site))
  (check-true (send-expr? target))
  (check-true
   (for/or ([root (in-list (selector-completion-site-expressions site))])
     (expression-contains-node? root target)))
  site)

(test-case "recovery reaches nested selectors in both binding orders"
  (for ([marked-source
         (in-list '("(Point new* (x (source |len)) (y 20))"
                    "(Point new* (x (source le|n)) (y 20))"
                    "(Point new* (x (source len|)) (y 20))"
                    "(Point new* (y 20) (x (source le|n)))"))]
        [start (in-list '(24 24 24 31))]
        [binding-index (in-list '(0 0 0 1))])
    (define site (check-site marked-source "len" start 3))
    (define root (first (selector-completion-site-expressions site)))
    (check-eq? (selector-completion-site-target-send site)
               (list-ref (binding-values root) binding-index)))
  (define incomplete-site (check-site "(Point new* (x (source le|" "le" 24 2))
  (check-eq? (selector-completion-site-target-send incomplete-site)
             (first (binding-values
                     (first (selector-completion-site-expressions incomplete-site))))))

(test-case "recovery traverses construction receivers, nested constructions, and methods"
  (for ([marked-source
         (in-list '("((source cl|ass) new* (x 1))"
                    "(Outer new* (point (Inner new* (x (source le|n)))))"
                    "(define-class Sample (fields) (methods (build () Point (Point new* (x (source le|n))))))"))]
        [selector (in-list '("class" "len" "len"))])
    (define-values (source _position) (remove-cursor marked-source))
    (check-site marked-source selector (position-of source selector)
                (string-length selector))))

(test-case "labels, pairs, values, and the reserved token are not selector sites"
  (for ([marked-source
         (in-list '("(Point |new* (x 10) (y 20))"
                    "(Point ne|w* (x 10) (y 20))"
                    "(Point new*| (x 10) (y 20))"
                    "(Empty new*|)"
                    "(Point new* |(x 10) (y 20))"
                    "(Point new* (|x 10) (y 20))"
                    "(Point new* (x| 10) (y 20))"
                    "(Point new* (x 10) (y| 20))"
                    "(Point new* (x:| 10))"
                    "(Point new* (x va|lue))"))])
    (define-values (source position) (remove-cursor marked-source))
    (check-false (recover-selector-completion-site source position))))
