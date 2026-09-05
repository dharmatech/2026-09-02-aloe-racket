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

;; Find rows by selector rather than depending on dispatch-table positions.
(define (bind-signature! name mirror selector)
  (eval-source
   (format
    (string-append
     "(define ~a\n"
     "  ((~a signatures) fold\n"
     "    ((~a signatures) first)\n"
     "    (fn (found signature)\n"
     "      (if (((signature selector) name) = ~s)\n"
     "          signature\n"
     "          found))))")
    name
    mirror
    mirror
    selector)
   environment))

(void (eval-source "(define int-mirror (Mirror of 1))" environment))
(void (bind-signature! "int-plus" "int-mirror" "+"))

;; Confirm this is the one-Int-to-Int row before invoking it.
(check-equal? (eval-source "((int-plus params) len)" environment) 1)
(check-equal?
 (aloe-value->string (eval-source "((int-plus params) first)" environment))
 "#<Symbol Int>")
(check-equal?
 (aloe-value->string (eval-source "(int-plus return)" environment))
 "#<Symbol Int>")
(define int-result
  (eval-source "(int-mirror invoke int-plus 2)" environment))
(check-equal? int-result 3)
(check-true (exact-integer? int-result))

(void
 (eval-source
  "(define point-mirror (Mirror of (Point new 10 20)))"
  environment))
(void (bind-signature! "point-x" "point-mirror" "x"))
(check-equal? (eval-source "((point-x params) len)" environment) 0)
(check-equal? (eval-source "(point-mirror invoke point-x)" environment) 10)

(void (bind-signature! "point-plus" "point-mirror" "+"))
(check-equal? (eval-source "((point-plus params) len)" environment) 1)
(check-equal?
 (aloe-value->string
  (eval-source "((point-plus params) first)" environment))
 "#<List #<Symbol Point> #<Symbol Int>>")
(void
 (eval-source
  #<<ALOE
(define-class PointInvoker
  (fields
    (signature Signature))
  (methods
    (run (left (Point Int)) (right (Point Int)) (Point Int)
      ((Mirror of left) invoke (self signature) right))))
ALOE
  environment))
(void
 (eval-source
  (string-append
   "(define added-point\n"
   "  ((PointInvoker new point-plus) run\n"
   "    (Point new 1 2)\n"
   "    (Point new 3 4)))")
  environment))
(check-equal? (eval-source "(added-point x)" environment) 4)
(check-equal? (eval-source "(added-point y)" environment) 6)

;; An expected result type flows into invoke without exposing the chosen row
;; to the checker.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define-class InvokeExpected
  (fields)
  (methods
    (run (signature Signature) Int
      ((Mirror of 1) invoke signature 2))))
ALOE
   ))
 'Void)

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source source environment))))

(check-type-error "(1 invoke)")
(check-type-error "((Point new 1 2) invoke)")
(check-type-error "((Mirror of 1) invoke 1)")
(check-type-error "((Mirror of 1) invoke)")

(check-exn #rx"arity error"
           (lambda ()
             (eval-source "(int-mirror invoke int-plus)" environment)))
(check-exn #rx"arity error"
           (lambda ()
             (eval-source
              "(int-mirror invoke int-plus 1 2)"
              environment)))
(check-exn #rx"argument 1 does not match Int"
           (lambda ()
             (eval-source
              "(int-mirror invoke int-plus \"x\")"
              environment)))
(check-exn #rx"does not belong to the subject type"
           (lambda ()
             (eval-source
              (string-append
               "((Mirror of (Point new 1 2)) invoke int-plus\n"
               "  (Point new 3 4))")
              environment)))
