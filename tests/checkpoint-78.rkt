#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define checker-environment (make-type-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string gel-loop-path))
  checker-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string point-path))
  checker-environment))

(check-equal?
 (type->datum
  (typecheck-source "(((gel-rows of 10) first) expected-text)"
                    checker-environment))
 'String)
(check-equal?
 (type->datum
  (typecheck-source "(((gel-rows of 10) first) int-hole?)"
                    checker-environment))
 'Bool)
(check-equal?
 (type->datum
  (typecheck-source
   "(((gel-rows of 10) first) accepts? (Mirror of 2))"
   checker-environment))
 'Bool)
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source "(((gel-rows of 10) first) accepts? 2)"
                     checker-environment)))

;; Pending-argument semantics no longer have a separate callable owner.
(for ([name '(GelIntHole gel-int-hole?)])
  (check-exn
   (regexp (format "unbound symbol: ~a" name))
   (lambda ()
     (typecheck-source (symbol->string name) checker-environment))))

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string gel-loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(define (bind-row! name rows selector arity)
  (eval-source
   (format
    (string-append
     "(define ~a\n"
     "  (~a fold\n"
     "    (~a first)\n"
     "    (fn (found row)\n"
     "      (if (((row selector) name) = ~s)\n"
     "          (if ((row arity) = ~a) row found)\n"
     "          found))))")
    name
    rows
    rows
    selector
    arity)
   environment))

(void (eval-source "(define int-rows-78 (gel-rows of 10))" environment))
(void (bind-row! "int-plus-row-78" "int-rows-78" "+" 1))
(void (eval-source "(define point-78 (Point new 10 20))" environment))
(void (eval-source "(define point-rows-78 (gel-rows of point-78))"
                   environment))
(void (bind-row! "point-plus-row-78" "point-rows-78" "+" 1))

;; Exact Int and compound Point parameter presentations remain unchanged.
(check-equal? (eval-source "(int-plus-row-78 expected-text)" environment)
              "#<Symbol Int>")
(check-true (eval-source "(int-plus-row-78 int-hole?)" environment))
(check-equal? (eval-source "(point-plus-row-78 expected-text)" environment)
              "#<List #<Symbol Point> #<Symbol Int>>")
(check-false (eval-source "(point-plus-row-78 int-hole?)" environment))

;; GelRow.accepts? delegates exactly to its retained Signature.
(for ([row '(int-plus-row-78 point-plus-row-78)]
      [matching '(2 (Point new 1 2))]
      [mismatching '((Point new 1 2) 2)])
  (for ([candidate (list matching mismatching)])
    (define row-text (symbol->string row))
    (define candidate-text (format "(Mirror of ~s)" candidate))
    (check-equal?
     (eval-source (format "(~a accepts? ~a)" row-text candidate-text)
                  environment)
     (eval-source
      (format "((~a signature) accepts? ~a)" row-text candidate-text)
      environment))))

(check-true
 (eval-source "(int-plus-row-78 accepts? (Mirror of 2))" environment))
(check-false
 (eval-source
  "(int-plus-row-78 accepts? (Mirror of (Point new 1 2)))"
  environment))
(check-true
 (eval-source
  "(point-plus-row-78 accepts? (Mirror of (Point new 1 2)))"
  environment))
(check-false
 (eval-source "(point-plus-row-78 accepts? (Mirror of 2))" environment))

;; Pending menus and the Int-entry transition still consume those semantics.
(void
 (eval-source
  #<<ALOE
(define int-state-78
  (GelStep new (gel-empty-stack push 10)
    #f (List of int-plus-row-78) 0 #f #f 0))
ALOE
  environment))
(check-equal? (eval-source "(gel-text menu int-state-78)" environment)
              "pending +  Int \r\n")
(void
 (eval-source
  "(define typed-78 (int-state-78 handle-key \"2\"))"
  environment))
(void
 (eval-source
  "(define result-78 (typed-78 handle-key \"return\"))"
  environment))
(check-equal? (eval-source "(((result-78 stack) tos) subject)" environment)
              12)
