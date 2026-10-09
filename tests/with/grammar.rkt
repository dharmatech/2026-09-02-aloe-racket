#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/match
         "../../aloe/completion-query.rkt"
         "../../aloe/parse.rkt"
         "../../aloe/private/completion-selection.rkt"
         "../../aloe/private/expression-selection.rkt")

(define (binding-names expression)
  (map construction-binding-name (with-expr-bindings expression)))

(define (binding-values expression)
  (map construction-binding-value (with-expr-bindings expression)))

(define (position-of source text)
  (add1 (caar (regexp-match-positions (regexp (regexp-quote text)) source))))

(define (check-syntax-error datum category)
  (check-exn
   (lambda (failure)
     (and (exn:fail:contract? failure)
          (regexp-match? #rx"parse-datum:" (exn-message failure))
          (regexp-match? category (exn-message failure))))
   (lambda () (parse-datum datum))))

(test-case "the parse table: pairs in written order, one pair, and syntax errors"
  (define expression (parse-datum '(p with (x 1) (y 2))))
  (check-true (with-expr? expression))
  (check-equal? expression
                (with-expr (variable-expr 'p #f)
                           (list (construction-binding 'x (int-expr 1 #f))
                                 (construction-binding 'y (int-expr 2 #f)))
                           #f))
  (check-equal? (binding-names (parse-datum '(p with (y 2) (x 1)))) '(y x))
  (check-equal? (binding-names (parse-datum '(p with (z 1) (x 1) (x 2))))
                '(z x x))
  (check-equal? (parse-datum '(p with (x 1)))
                (with-expr (variable-expr 'p #f)
                           (list (construction-binding 'x (int-expr 1 #f)))
                           #f))
  (check-syntax-error '(p with) #rx"with requires at least one")
  (check-syntax-error '(p with x 1) #rx"malformed with binding")
  (check-syntax-error '(p with (x)) #rx"malformed with binding")
  (check-syntax-error '(p with (x 1 2)) #rx"malformed with binding")
  ;; Head position is not the reserved position. The argument (x 1) is an
  ;; ordinary combination, so its literal selector is what fails.
  (check-syntax-error '(with p (x 1)) #rx"selector must be a symbol")
  (check-equal? (parse-datum '(with p (x y)))
                (send-expr (variable-expr 'with #f) 'p
                           (list (send-expr (variable-expr 'x #f) 'y '() #f #f))
                           #f #f)))

(test-case "every pair shape and the empty tail are rejected before the receiver"
  (for ([bad-pair (in-list '(10 x () (x) (x 1 2) (x . 1)
                            (x 1 . 2) (10 1) ("x" 1) (() 1) (#:x 1)))])
    (for ([receiver (in-list '(p (receiver) (receiver 10)))])
      (check-syntax-error `(,receiver with (valid 1) ,bad-pair)
                          #rx"malformed with binding")
      (check-syntax-error `(,receiver with ,bad-pair (valid 1))
                          #rx"malformed with binding"))
    (check-syntax-error `(p with (valid (value)) ,bad-pair)
                        #rx"malformed with binding"))
  (for ([receiver (in-list '(p (receiver) (receiver 10) ()))])
    (check-syntax-error `(,receiver with) #rx"with requires at least one"))
  (check-syntax-error '(p with (x 1) . tail) #rx"malformed combination")
  ;; Once shapes pass, receiver syntax precedes ordinary value syntax.
  (check-syntax-error '((receiver 10) with (x ())) #rx"selector must be a symbol")
  (check-syntax-error '(p with (x ())) #rx"empty combination")
  (check-syntax-error '(p with (x (value))) #rx"no selector"))

(test-case "with stays an ordinary name outside the selector position"
  (check-equal? (parse-datum 'with) (variable-expr 'with #f))
  (check-equal? (parse-datum '(define with 3))
                (define-expr 'with (int-expr 3 #f) #f))
  (check-equal? (parse-datum '(with call x))
                (send-expr (variable-expr 'with #f) 'call
                           (list (variable-expr 'x #f)) #f #f))
  (check-equal? (parse-datum '(source value with))
                (send-expr (variable-expr 'source #f) 'value
                           (list (variable-expr 'with #f)) #f #f))
  (check-equal? (parse-datum '(with with (with with)))
                (with-expr (variable-expr 'with #f)
                           (list (construction-binding 'with (variable-expr 'with #f)))
                           #f))
  (check-equal? (parse-datum '(if with 1 2))
                (send-expr (variable-expr 'with #f) 'if
                           (list (fn-expr '() (int-expr 1 #f) #f)
                                 (fn-expr '() (int-expr 2 #f) #f))
                           #f #f))
  (check-true (new-star-expr? (parse-datum '(Point new* (x 1) (y 2)))))
  (check-true (case-expr? (parse-datum '(choice case (A () 1)))))
  ;; Square brackets are the reader's parentheses and nothing more.
  (check-equal? (read-program "(p with [x 1] [y (q with [z 2])])")
                (read-program "(p with (x 1) (y (q with (z 2))))")))

(test-case "values are ordinary expressions, including a nested with"
  (define nested (parse-datum '(outer with (inner (inner-source with (y 2) (x 1))))))
  (check-equal? (binding-values nested)
                (list (parse-datum '(inner-source with (y 2) (x 1)))))
  (define computed (parse-datum '((if #t p q) with (x (source x)) (y (source y)))))
  (check-equal? (with-expr-receiver computed) (parse-datum '(if #t p q)))
  (check-equal? (binding-values computed)
                (list (send-expr (variable-expr 'source #f) 'x '() #f #f)
                      (send-expr (variable-expr 'source #f) 'y '() #f #f))))

(test-case "source parsing gives the whole form, receiver, and values their spans"
  (define source "(p with\n  (x (source y))\n  (y 10))\n")
  (define source-path (build-path (current-directory) "with-spans.aloe"))
  (define expression (first (read-program source #:source-path source-path)))
  (define values (binding-values expression))
  (define nested-send (first values))
  (define (check-location loc line column position span)
    (check-equal? loc (srcloc source-path line column position span)))
  (check-location (expression-loc expression) 1 0 1 34)
  (check-location (expression-loc (with-expr-receiver expression)) 1 1 2 1)
  (check-location (expression-loc nested-send) 2 5 14 10)
  (check-location (expression-loc (send-expr-receiver nested-send)) 2 6 15 6)
  (check-location (send-expr-selector-loc nested-send) 2 13 22 1)
  (check-location (expression-loc (second values)) 3 5 31 2))

(define (check-location-free expression)
  (check-false (expression-loc expression))
  (match expression
    [(with-expr receiver bindings _)
     (check-location-free receiver)
     (for-each check-location-free (map construction-binding-value bindings))]
    [(send-expr receiver _ arguments _ selector-loc)
     (check-false selector-loc)
     (check-location-free receiver)
     (for-each check-location-free arguments)]
    [(fn-expr _ body _)
     (check-location-free body)]
    [_ (void)]))

(test-case "datum trees have no locations and parse deterministically"
  (for ([datum (in-list '((p with (x 1))
                          ((if #t p q) with
                           (x (source x))
                           (y (inner with (value (source y)))))
                          (box with (value (let ((x 1)) (x + 2))))))])
    (define expression (parse-datum datum))
    (check-equal? expression (parse-datum datum))
    (check-location-free expression)
    (check-false (select-expression-at-position (list expression) 1))))

(define (check-selected-and-contained expressions root child)
  (check-eq? (select-expression-at-position
              expressions (srcloc-position (expression-loc child)))
             child)
  (check-true (expression-contains-node? root child)))

(test-case "children are the receiver and values; labels are not children"
  (define source
    "((source point) with (x (inner with (part (value len)))) (y 20))")
  (define expressions (read-program source))
  (define root (first expressions))
  (define receiver (with-expr-receiver root))
  (define inner (first (binding-values root)))
  (define nested-send (first (binding-values inner)))
  (for ([child (in-list (list receiver (send-expr-receiver receiver)
                              inner (with-expr-receiver inner)
                              nested-send (send-expr-receiver nested-send)
                              (second (binding-values root))))])
    (check-selected-and-contained expressions root child))
  (for ([label (in-list '("(x" "(y" "with"))])
    (check-eq? (select-expression-at-position expressions (position-of source label))
               root))
  (check-eq? (select-expression-at-position expressions (position-of source "part"))
             inner)
  (check-false (expression-contains-node? root (variable-expr 'x #f)))
  (check-false (expression-contains-node? root (variable-expr 'part #f)))
  (check-false (expression-contains-node? root (first (read-program source))))
  (check-false
   (select-expression-at-position expressions (add1 (string-length source)))))

(test-case "traversal visits the receiver, then values in written order"
  (define loc (srcloc #f 1 0 1 10))
  (define child-loc (srcloc #f 1 2 3 1))
  (define receiver (variable-expr 'p child-loc))
  (define a (int-expr 1 child-loc))
  (define b (int-expr 2 child-loc))
  (define (update receiver values)
    (with-expr receiver
               (map (lambda (value) (construction-binding 'field value)) values)
               loc))
  (check-eq? (select-expression-at-position (list (update receiver (list a b))) 3)
             receiver)
  (define unlocated-receiver (variable-expr 'p #f))
  (check-eq? (select-expression-at-position
              (list (update unlocated-receiver (list a b))) 3)
             a)
  (check-eq? (select-expression-at-position
              (list (update unlocated-receiver (list b a))) 3)
             b))

(test-case "method bodies contain the form and its children"
  (for ([source
         (in-list '("(define-class Sample (fields (x Int)) (methods (bump () Sample (self with (x (source len))))))"
                    "(define-methods String (methods (bump () Sample (sample with (x (self len))))))"))])
    (define expressions (read-program source))
    (define root (first expressions))
    (define methods
      (if (define-class-expr? root)
          (define-class-expr-methods root)
          (define-methods-expr-methods root)))
    (define body (method-declaration-body (first methods)))
    (define value (first (binding-values body)))
    (for ([child (in-list (list body (with-expr-receiver body)
                                value (send-expr-receiver value)))])
      (check-selected-and-contained expressions root child)
      (check-true (expression-contains-node? body child)))
    (check-eq? (select-expression-at-position expressions (position-of source "(x ("))
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
  (define target (selector-completion-site-target-send site))
  (check-true (send-expr? target))
  (check-true
   (for/or ([root (in-list (selector-completion-site-expressions site))])
     (expression-contains-node? root target)))
  site)

(test-case "completion recovery reaches receivers and values in written order"
  (for ([marked-source
         (in-list '("(p with (x (source |len)) (y 20))"
                    "(p with (x (source le|n)) (y 20))"
                    "(p with (x (source len|)) (y 20))"
                    "(p with (y 20) (x (source le|n)))"))]
        [binding-index (in-list '(0 0 0 1))])
    (define-values (source _position) (remove-cursor marked-source))
    (define site (check-site marked-source "len" (position-of source "len") 3))
    (define root (first (selector-completion-site-expressions site)))
    (check-eq? (selector-completion-site-target-send site)
               (list-ref (binding-values root) binding-index)))
  (for ([marked-source
         (in-list '("((source poi|nt) with (x 1))"
                    "(outer with (inner (p with (x (source le|n)))))"
                    "(define-class Sample (fields (x Int)) (methods (bump () Sample (self with (x (source le|n))))))"))]
        [selector (in-list '("point" "len" "len"))])
    (define-values (source _position) (remove-cursor marked-source))
    (check-site marked-source selector (position-of source selector)
                (string-length selector))))

(test-case "the reserved token, labels, and pairs are not selector sites"
  (for ([marked-source
         (in-list '("(p |with (x 10) (y 20))"
                    "(p wi|th (x 10) (y 20))"
                    "(p with| (x 10) (y 20))"
                    "(p with|)"
                    "(p with |(x 10) (y 20))"
                    "(p with (|x 10) (y 20))"
                    "(p with (x| 10) (y 20))"
                    "(p with (x 10) (y| 20))"
                    "(p with (x va|lue))"
                    "(source wi|th)"))])
    (define-values (source position) (remove-cursor marked-source))
    (check-false (recover-selector-completion-site source position))))

(define (write-source! path source)
  (call-with-output-file path (lambda (output) (display source output))
    #:exists 'truncate))

(define point-source
  "(define-class (Point T) (fields (x T) (y T)) (methods))\n(define p (Point new 1 2))\n")

(test-case "completion queries walk with values, including loads inside them"
  (define directory (make-temporary-file "with-grammar-~a" 'directory "/tmp"))
  (dynamic-wind
   void
   (lambda ()
     (define root (build-path directory "unsaved.aloe"))
     (write-source! (build-path directory "support.aloe") "(define from-load 99)\n")
     (for ([tail (in-list
                  '("(p with (y (let ((loaded (load \"support.aloe\"))) from-load)) (x ((p with (x 3)) |x)))"
                    "(p with (x ((p with (x 3)) |x)) (y (let ((loaded (load \"support.aloe\"))) from-load)))"))])
       (define-values (source position) (remove-cursor (string-append point-source tail)))
       (check-equal?
        (map selector-completion-item-label
             (query-selector-completions source position #:source-path root))
        '("x" "y"))
       ;; The load resolves from cwd, so the missing source path is the
       ;; reason the walker withholds completions.
       (parameterize ([current-directory directory])
         (check-equal? (query-selector-completions source position) '())))
     (define-values (source position)
       (remove-cursor (string-append point-source "(p wi|th (x 3))")))
     (check-equal? (query-selector-completions source position) '()))
   (lambda () (delete-directory/files directory))))
