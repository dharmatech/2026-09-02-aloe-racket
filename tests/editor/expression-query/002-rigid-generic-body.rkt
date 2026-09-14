#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../../aloe/parse.rkt"
         "../../../aloe/private/expression-selection.rkt"
         "../../../aloe/signature-catalog.rkt"
         (prefix-in type: "../../../aloe/type.rkt")
         (submod "../../../aloe/type.rkt"
                 expression-query-observation))

(define-runtime-path fixture-path "fixtures/point.aloe")
(define-runtime-path parse-path "../../../aloe/parse.rkt")
(define-runtime-path main-path "../../../aloe/main.rkt")
(define-runtime-path driver-path "../../../aloe/driver.rkt")

(define (read-expressions source)
  (read-program (open-input-string source)))

(define (observe expressions selected-expression)
  (typecheck-program/observe
   expressions
   (type:make-type-environment)
   selected-expression))

(define (triples->specs triples)
  (for/list ([triple (in-list triples)])
    (apply signature-spec triple)))

(define (parameter-rows name)
  (triples->specs
   `((+ (,name) ,name)
     (- (,name) ,name)
     (* (,name) ,name)
     (/ (,name) ,name)
     (< (,name) Bool)
     (> (,name) Bool)
     (<= (,name) Bool)
     (>= (,name) Bool)
     (= (,name) Bool))))

(define list-t-rows
  (triples->specs
   '((empty? () Bool)
     (first () T)
     (rest () (List T))
     (cons (T) (List T))
     (len () Int))))

(define point-t-rows
  (triples->specs
   '((x () T)
     (y () T)
     (+ ((Point T)) (Point T))
     (dist2 ((Point T)) T))))

(define missing-export (gensym 'missing-export))

(define (module-exports? module-path name)
  (not
   (eq? (dynamic-require module-path name (lambda () missing-export))
        missing-export)))

(define (method-body declaration index)
  (method-declaration-body
   (list-ref
    (cond
      [(define-class-expr? declaration)
       (define-class-expr-methods declaration)]
      [(define-methods-expr? declaration)
       (define-methods-expr-methods declaration)])
    index)))

(define (captured-type-error thunk)
  (with-handlers ([type:exn:fail:aloe-type? values])
    (thunk)
    #f))

(test-case "expression containment follows the private identity traversal"
  (define root
    (first
     (parse-program
      '((check (1 + 2) 3)))))
  (define nested-send (check-expr-left root))
  (define nested-leaf (send-expr-receiver nested-send))
  (define equal-root
    (first
     (parse-program
      '((check (1 + 2) 3)))))
  (define equal-leaf
    (send-expr-receiver (check-expr-left equal-root)))

  (check-true (expression-contains-node? root root))
  (check-true (expression-contains-node? root nested-send))
  (check-true (expression-contains-node? root nested-leaf))
  (check-true (equal? nested-leaf equal-leaf))
  (check-false (eq? nested-leaf equal-leaf))
  (check-false (expression-contains-node? root equal-leaf))
  (for ([module-path (in-list (list parse-path main-path driver-path))])
    (check-false
     (module-exports? module-path 'expression-contains-node?))))

(define fixture-expressions
  (call-with-input-file
   fixture-path
   (lambda (input)
     (read-program input #:source-path fixture-path))))

(test-case "normative Point self is observed in its rigid declaration context"
  (define selected
    (select-expression-at-position fixture-expressions 108))
  (check-eq? selected (method-body (first fixture-expressions) 0))
  (check-equal?
   (observe fixture-expressions selected)
   (expression-type-observation '(Point T) point-t-rows)))

(test-case "later concrete Point uses cannot specialize the observation"
  (define source
    (string-append
     (file->string fixture-path)
     "(Point new 1.0 2.0)\n"
     "((Point new 1 2) + (Point new 3 4))\n"
     "((Point new 1.0 2.0) + (Point new 3.0 4.0))\n"))
  (define expressions (read-expressions source))
  (define selected (select-expression-at-position expressions 108))
  (check-equal?
   (observe expressions selected)
   (expression-type-observation '(Point T) point-t-rows)))

(test-case "a deferred body receives its declared return type as expected"
  (define expressions
    (read-expressions
     (string-append
      "(define-class (ContextList002 T)\n"
      "  (fields (value T))\n"
      "  (methods\n"
      "    (empty () (List T)\n"
      "      (List empty))))")))
  (define selected (method-body (first expressions) 0))
  (check-equal?
   (observe expressions selected)
   (expression-type-observation '(List T) list-t-rows)))

(define rigid-values-source
  (string-append
   "(define-class (ContextValues002 T)\n"
   "  (fields (value T))\n"
   "  (methods\n"
   "    (same (other (ContextValues002 T)) (ContextValues002 T) self)\n"
   "    (echo (item T) T item)\n"
   "    (adapt (type U) (item U) U item)))\n"
   "((ContextValues002 new 1) same (ContextValues002 new 2))\n"
   "((ContextValues002 new 1) echo 2)\n"
   "((ContextValues002 new 1) adapt \"later\")"))

(define rigid-values-rows
  (triples->specs
   '((value () T)
     (same ((ContextValues002 T)) (ContextValues002 T))
     (echo (T) T)
     (adapt (U) U))))

(test-case "self and rigid class and method parameters stay symbolic"
  (define expressions (read-expressions rigid-values-source))
  (define declaration (first expressions))
  (check-equal?
   (observe expressions (method-body declaration 0))
   (expression-type-observation
    '(ContextValues002 T)
    rigid-values-rows))
  (check-equal?
   (observe expressions (method-body declaration 1))
   (expression-type-observation 'T (parameter-rows 'T)))
  (check-equal?
   (observe expressions (method-body declaration 2))
   (expression-type-observation 'U (parameter-rows 'U))))

(define selective-source
  (string-append
   "(define-class (ContextSelective002 T)\n"
   "  (fields (value T))\n"
   "  (methods\n"
   "    (good () T (self value))\n"
   "    (bad () T missing002)))"))

(test-case "only the selected deferred class body is checked"
  (define expressions (read-expressions selective-source))
  (define declaration (first expressions))
  (check-equal?
   (observe expressions (method-body declaration 0))
   (expression-type-observation 'T (parameter-rows 'T)))

  (define bad-error
    (captured-type-error
     (lambda ()
       (observe expressions (method-body declaration 1)))))
  (check-true (type:exn:fail:aloe-type? bad-error))
  (check-equal? (exn-message bad-error)
                "typecheck: unbound symbol: missing002"))

(define extension-source
  (string-append
   "(define-class (ContextExtension002 T)\n"
   "  (fields (value T))\n"
   "  (methods\n"
   "    (base () T (self value))))\n"
   "(define-methods ContextExtension002\n"
   "  (methods\n"
   "    (first-added () (ContextExtension002 T) self)\n"
   "    (bad-added () T missing-added002)))"))

(define extension-rows
  (triples->specs
   '((value () T)
     (base () T)
     (first-added () (ContextExtension002 T))
     (bad-added () T))))

(test-case "define-methods checks only its selected body after all row installs"
  (define expressions (read-expressions extension-source))
  (define extension (second expressions))
  (check-equal?
   (observe expressions (method-body extension 0))
   (expression-type-observation
    '(ContextExtension002 T)
    extension-rows))

  (define bad-error
    (captured-type-error
     (lambda ()
       (observe expressions (method-body extension 1)))))
  (check-true (type:exn:fail:aloe-type? bad-error))
  (check-equal? (exn-message bad-error)
                "typecheck: unbound symbol: missing-added002"))

(test-case "selecting declarations does not force their deferred bodies"
  (define expressions (read-expressions extension-source))
  (for ([declaration (in-list expressions)])
    (check-equal?
     (observe expressions declaration)
     (expression-type-observation 'Void '()))))

(test-case "ordinary and target-free checks retain legacy deferral"
  (define ordinary-expressions (read-expressions selective-source))
  (check-equal?
   (type:type->datum
    (type:typecheck-program
     ordinary-expressions
     (type:make-type-environment)))
   'Void)
  (check-false
   (typecheck-program/observe
    (read-expressions selective-source)
    (type:make-type-environment)
    #f))

  (define first-expressions (read-expressions selective-source))
  (define second-expressions (read-expressions selective-source))
  (define first-answer
    (observe first-expressions
             (method-body (first first-expressions) 0)))
  (define second-answer
    (observe second-expressions
             (method-body (first second-expressions) 0)))
  (check-equal? first-answer second-answer)
  (check-false
   (eq? (expression-type-observation-signatures first-answer)
        (expression-type-observation-signatures second-answer))))

(test-case "a later checker error invalidates a rigid observation"
  (define later-error-source
    (string-append selective-source "\n(\"bad\" + 1)"))
  (define ordinary-error
    (captured-type-error
     (lambda ()
       (type:typecheck-program
        (read-expressions later-error-source)
        (type:make-type-environment)))))
  (define observed-expressions (read-expressions later-error-source))
  (define observed-error
    (captured-type-error
     (lambda ()
       (observe observed-expressions
                (method-body (first observed-expressions) 0)))))
  (check-true (type:exn:fail:aloe-type? ordinary-error))
  (check-true (type:exn:fail:aloe-type? observed-error))
  (check-equal? (exn-message observed-error)
                (exn-message ordinary-error)))
