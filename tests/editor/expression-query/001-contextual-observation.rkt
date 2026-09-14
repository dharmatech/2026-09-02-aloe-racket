#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../../../aloe/host.rkt"
         "../../../aloe/parse.rkt"
         "../../../aloe/signature-catalog.rkt"
         (prefix-in type: "../../../aloe/type.rkt")
         (only-in (submod "../../../aloe/type.rkt"
                          driver-host-injection)
                  type-environment-inject-host!)
         (submod "../../../aloe/type.rkt"
                 expression-query-observation))

(define-runtime-path type-path "../../../aloe/type.rkt")
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

(define int-rows
  (triples->specs
   '((+ (Int) Int)
     (- (Int) Int)
     (* (Int) Int)
     (/ (Int) Int)
     (< (Int) Bool)
     (> (Int) Bool)
     (<= (Int) Bool)
     (>= (Int) Bool)
     (= (Int) Bool)
     (float () Float)
     (text () String))))

(define string-rows
  (triples->specs
   '((= (String) Bool)
     (append (String) String)
     (len () Int)
     (take (Int) String))))

(define list-int-rows
  (triples->specs
   '((empty? () Bool)
     (first () Int)
     (rest () (List Int))
     (cons (Int) (List Int))
     (len () Int))))

(define missing-export (gensym 'missing-export))

(define (module-exports? module-path name)
  (not
   (eq? (dynamic-require module-path name (lambda () missing-export))
        missing-export)))

(test-case "observation bridge is narrow and the result field order is exact"
  (define sample
    (expression-type-observation 'Sample '(row)))
  (check-true (expression-type-observation? sample))
  (check-equal? (procedure-arity expression-type-observation) 2)
  (check-equal?
   (struct->vector sample)
   '#(struct:expression-type-observation Sample (row)))
  (check-equal? (expression-type-observation-type sample) 'Sample)
  (check-equal? (expression-type-observation-signatures sample) '(row))
  (check-equal? (procedure-arity typecheck-program/observe) 3)
  (for* ([module-path (in-list (list type-path main-path driver-path))]
         [name (in-list
                '(expression-type-observation
                  expression-type-observation?
                  expression-type-observation-type
                  expression-type-observation-signatures
                  typecheck-program/observe))])
    (check-false (module-exports? module-path name))))

(test-case "empty List materializes after same-root inference"
  (define expressions
    (read-expressions "(check (List empty) (List of 1))"))
  (define selected
    (check-expr-left (first expressions)))
  (define answer (observe expressions selected))
  (check-equal?
   answer
   (expression-type-observation '(List Int) list-int-rows)))

(define non-generic-class-source
  (string-append
   "(define-class ContextPair001\n"
   "  (fields (left Int) (right Int))\n"
   "  (methods\n"
   "    (choose (other ContextPair001) ContextPair001\n"
   "      (check self other))))"))

(test-case "method self and parameter retain their lexical class context"
  (define expressions (read-expressions non-generic-class-source))
  (define class-expression (first expressions))
  (define method
    (first (define-class-expr-methods class-expression)))
  (define body (method-declaration-body method))
  (define self-expression (check-expr-left body))
  (define parameter-expression (check-expr-right body))
  (define expected-rows
    (triples->specs
     '((left () Int)
       (right () Int)
       (choose (ContextPair001) ContextPair001))))
  (for ([selected (in-list (list self-expression parameter-expression))])
    (check-equal?
     (observe expressions selected)
     (expression-type-observation 'ContextPair001 expected-rows))))

(test-case "function and desugared let parameters use same-root constraints"
  (define function-expressions
    (read-expressions "((fn (x) x) call 1)"))
  (define function-root (first function-expressions))
  (define function-parameter-use
    (fn-expr-body (send-expr-receiver function-root)))
  (check-equal?
   (observe function-expressions function-parameter-use)
   (expression-type-observation 'Int int-rows))

  (define let-expressions
    (read-expressions
     "(let ((items (List empty))) (check items (List of 1)))"))
  (define let-root (first let-expressions))
  (define let-body
    (fn-expr-body (send-expr-receiver let-root)))
  (define let-binding-use (check-expr-left let-body))
  (check-equal?
   (observe let-expressions let-binding-use)
   (expression-type-observation '(List Int) list-int-rows)))

(define case-source
  (string-append
   "(define-class (ContextOption001 T)\n"
   "  (constructors\n"
   "    (None (fields))\n"
   "    (Some (fields (value T))))\n"
   "  (methods))\n"
   "((fn (fallback)\n"
   "   ((ContextOption001 Some 1) case\n"
   "     (Some (payload) payload)\n"
   "     (else fallback)))\n"
   " call 0)"))

(test-case "case payload and else body use their lexical environments"
  (define expressions (read-expressions case-source))
  (define call-expression (second expressions))
  (define function-expression (send-expr-receiver call-expression))
  (define case-expression (fn-expr-body function-expression))
  (define payload-expression
    (case-clause-body (first (case-expr-clauses case-expression))))
  (define else-expression (case-expr-else-body case-expression))
  (for ([selected (in-list (list payload-expression else-expression))])
    (check-equal?
     (observe expressions selected)
     (expression-type-observation 'Int int-rows))))

(test-case "explicit-constructor generic self stays rigid and symbolic"
  (define expressions
    (read-expressions
     (string-append
      "(define-class (ContextExplicit001 T)\n"
      "  (constructors\n"
      "    (Only (fields (value T))))\n"
      "  (methods\n"
      "    (same (other (ContextExplicit001 T)) (ContextExplicit001 T)\n"
      "      self)))\n"
      "(ContextExplicit001 Only 1)")))
  (define class-expression (first expressions))
  (define selected
    (method-declaration-body
     (first (define-class-expr-methods class-expression))))
  (check-equal?
   (observe expressions selected)
   (expression-type-observation
    '(ContextExplicit001 T)
    (triples->specs
     '((same
        ((ContextExplicit001 T))
        (ContextExplicit001 T)))))))

(test-case "define-methods materializes after every row is installed"
  (define expressions
    (read-expressions
     (string-append
      "(define-methods String\n"
      "  (methods\n"
      "    (identity001 () String self)\n"
      "    (decorate001 (suffix String) String\n"
      "      (self append suffix))))")))
  (define declaration (first expressions))
  (define selected
    (method-declaration-body
     (first (define-methods-expr-methods declaration))))
  (define expected-rows
    (append
     string-rows
     (triples->specs
      '((identity001 () String)
        (decorate001 (String) String)))))
  (check-equal?
   (observe expressions selected)
   (expression-type-observation 'String expected-rows))
  (check-equal?
   (observe expressions declaration)
   (expression-type-observation 'Void '())))

(test-case "later roots do not change an earlier materialized catalog"
  (define expressions
    (read-expressions
     (string-append
      "\"before\"\n"
      "(define-methods String\n"
      "  (methods\n"
      "    (later001 () String self)))")))
  (check-equal?
   (observe expressions (first expressions))
   (expression-type-observation 'String string-rows)))

(test-case "only the successful overload derivation is observed"
  (define expressions
    (read-expressions
     (string-append
      "(define-class ContextOverload001\n"
      "  (fields)\n"
      "  (methods\n"
      "    (pick (value Int) Int value)\n"
      "    (pick (value String) String value)))\n"
      "((ContextOverload001 new) pick \"chosen\")")))
  (define selected (second expressions))
  (check-equal?
   (observe expressions selected)
   (expression-type-observation 'String string-rows)))

(define (captured-type-error thunk)
  (with-handlers ([type:exn:fail:aloe-type? values])
    (thunk)
    #f))

(test-case "strict checking suppresses observations after later failures"
  (define valid-expressions (read-expressions "1\n2"))
  (check-false (observe valid-expressions #f))

  (define later-error-source "1\n(\"bad\" + 2)")
  (define ordinary-later-error
    (captured-type-error
     (lambda ()
       (type:typecheck-program
        (read-expressions later-error-source)
        (type:make-type-environment)))))
  (check-true (type:exn:fail:aloe-type? ordinary-later-error))
  (define observed-later-expressions
    (read-expressions later-error-source))
  (define observed-later-error
    (captured-type-error
     (lambda ()
       (observe observed-later-expressions
                (first observed-later-expressions)))))
  (check-true (type:exn:fail:aloe-type? observed-later-error))
  (check-equal? (exn-message observed-later-error)
                (exn-message ordinary-later-error))
  (check-exn
   type:exn:fail:aloe-type?
   (lambda ()
     (observe (read-expressions later-error-source) #f)))

  (define protocol-error-source
    (string-append
     "1\n"
     "(define-protocol ContextRequired001\n"
     "  (required () Int))\n"
     "(define-class ContextMissing001 ContextRequired001\n"
     "  (fields (value Int))\n"
     "  (methods))"))
  (define protocol-expressions
    (read-expressions protocol-error-source))
  (check-exn
   (lambda (exception)
     (and (type:exn:fail:aloe-type? exception)
          (regexp-match? #rx"does not implement protocol"
                         (exn-message exception))))
   (lambda ()
     (observe protocol-expressions (first protocol-expressions))))
  (check-exn
   type:exn:fail:aloe-type?
   (lambda ()
     (observe (read-expressions protocol-error-source) #f))))

(define legacy-source-without-use
  (string-append
   "(define-class (ContextLegacy001 T)\n"
   "  (fields (value T))\n"
   "  (methods\n"
   "    (identity () (ContextLegacy001 T) self)))"))

(define legacy-source-with-use
  (string-append
   legacy-source-without-use
   "\n((ContextLegacy001 new 1) identity)"))

(define (legacy-target expressions)
  (method-declaration-body
   (first
    (define-class-expr-methods (first expressions)))))

(test-case "legacy generic fields bodies are observed symbolically"
  (for ([source (in-list
                 (list legacy-source-without-use
                       legacy-source-with-use))])
    (define expressions (read-expressions source))
    (check-equal?
     (observe expressions (legacy-target expressions))
     (expression-type-observation
      '(ContextLegacy001 T)
      (triples->specs
       '((value () T)
         (identity () (ContextLegacy001 T)))))))

  (define ordinary-expressions
    (read-expressions legacy-source-with-use))
  (check-equal?
   (type:type->datum
    (type:typecheck-program
     ordinary-expressions
     (type:make-type-environment)))
   '(ContextLegacy001 Int)))

(test-case "nested load roots do not materialize the outer root early"
  (define loaded-path
    (make-temporary-file "expression-query-001-~a.aloe" #f "/tmp"))
  (dynamic-wind
    (lambda ()
      (call-with-output-file
       loaded-path
       #:exists 'truncate
       (lambda (output)
         (display
          (string-append
           "1\n"
           "(define-methods String\n"
           "  (methods\n"
           "    (loaded001 () String self)))\n")
          output))))
    (lambda ()
      (define expressions
        (parse-program
         `(((fn (chosen ignored) chosen)
            call
            "selected"
            (load ,(path->string loaded-path))))))
      (define root (first expressions))
      (define selected (first (send-expr-arguments root)))
      (check-equal?
       (observe expressions selected)
       (expression-type-observation
        'String
        (append
         string-rows
         (triples->specs '((loaded001 () String)))))))
    (lambda ()
      (when (file-exists? loaded-path)
        (delete-file loaded-path)))))

(test-case "observation never invokes a host implementation"
  (define called? #f)
  (define interface
    (make-host-interface
     'ContextHost001
     (list
      (make-host-method
       'value
       '()
       'Int
       (lambda (_state)
         (set! called? #t)
         1)))))
  (define environment (type:make-type-environment))
  (type-environment-inject-host!
   environment
   'context-host-001
   (make-host-receiver interface #f))
  (define selected (parse-datum '(context-host-001 value)))
  (check-equal?
   (typecheck-program/observe (list selected) environment selected)
   (expression-type-observation 'Int int-rows))
  (check-false called?))

(test-case "calls are independent and ordinary checker entry points remain clean"
  (define expressions (read-expressions "1"))
  (define selected (first expressions))
  (define first-answer (observe expressions selected))
  (define second-answer (observe expressions selected))
  (check-equal? first-answer second-answer)
  (check-false
   (eq? (expression-type-observation-signatures first-answer)
        (expression-type-observation-signatures second-answer)))
  (check-equal?
   (type:type->datum
    (type:type-of (parse-datum '(1 + 2))
                  (type:make-type-environment)))
   'Int)
  (check-equal?
   (type:type->datum
    (type:typecheck-program
     (parse-program '((define clean001 1) clean001))
     (type:make-type-environment)))
   'Int))
