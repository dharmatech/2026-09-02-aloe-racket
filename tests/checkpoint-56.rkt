#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(define (signature-count signatures selector)
  (eval-source
   (format
    (string-append
     "(~a fold 0\n"
     "  (fn (count signature)\n"
     "    (if (((signature selector) name) = ~s)\n"
     "        (count + 1)\n"
     "        count)))")
    signatures
    selector)
   environment))

(define (mirror-signature-count subject selector)
  (signature-count
   (format "((Mirror of ~a) signatures)" subject)
   selector))

(check-equal?
 (type->datum (typecheck-source "((Mirror of 1) signatures)"))
 '(List Signature))
(check-equal?
 (type->datum
  (typecheck-source "(((Mirror of 1) signatures) first)"))
 'Signature)
(check-equal?
 (type->datum
  (typecheck-source
   "((((Mirror of 1) signatures) first) selector)"))
 'Symbol)

(void (eval-source "(define m (Mirror of 1))" environment))
(check-equal? (mirror-signature-count "1" "+") 1)

(void
 (eval-source
  #<<ALOE
(define plus-signature
  ((m signatures) fold
    ((m signatures) first)
    (fn (found signature)
      (if (((signature selector) name) = "+") signature found))))
ALOE
  environment))

(check-equal? (eval-source "((plus-signature selector) name)" environment)
              "+")
(check-equal? (eval-source "((plus-signature params) len)" environment)
              1)
(check-equal?
 (aloe-value->string
  (eval-source "((plus-signature params) first)" environment))
 "#<Symbol Int>")
(check-equal?
 (aloe-value->string (eval-source "(plus-signature return)" environment))
 "#<Symbol Int>")
(check-equal? (aloe-value->string
               (eval-source "plus-signature" environment))
              "#<Signature +>")

(define first-selector
  (eval-source "((((Mirror of 1) signatures) first) selector)"
               environment))
(define same-selector
  (eval-source "((((Mirror of 1) signatures) first) selector)"
               environment))
(check-eq? first-selector same-selector)

(void
 (eval-source "(define p (Mirror of (Point new 1 2)))" environment))
(check-equal? (signature-count "(p signatures)" "x") 1)
(check-equal? (signature-count "(p signatures)" "+") 1)
(check-equal? (signature-count "(p signatures)" "dist2") 1)
(check-equal? (mirror-signature-count "Point" "new") 1)

;; A compound annotation is reflected as nested List/Symbol data, never sent.
(void
 (eval-source
  #<<ALOE
(define point-plus-signature
  ((p signatures) fold
    ((p signatures) first)
    (fn (found signature)
      (if (((signature selector) name) = "+") signature found))))
ALOE
  environment))
(check-equal?
 (aloe-value->string
  (eval-source "((point-plus-signature params) first)" environment))
 "#<List #<Symbol Point> #<Symbol Int>>")
(check-equal?
 (aloe-value->string
  (eval-source "(point-plus-signature return)" environment))
 "#<List #<Symbol Point> #<Symbol Int>>")

;; Overloads remain separate table rows even though messages reports one name.
(void
 (eval-source
  #<<ALOE
(define-class SignatureOverload
  (fields)
  (methods
    (pick (n Int) Int n)
    (pick (s String) String s)))
ALOE
  environment))
(check-equal?
 (mirror-signature-count "(SignatureOverload new)" "pick")
 2)

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source source environment))))

(check-type-error "(1 signatures)")
(check-type-error "((Point new 1 2) signatures)")
(check-type-error "(Mirror of)")
(check-type-error "((Mirror of 1) invoke)")
