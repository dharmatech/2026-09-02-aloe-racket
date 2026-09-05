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

(define (message-list-count messages selector)
  (eval-source
   (format
    (string-append
     "(~a fold 0\n"
     "  (fn (count message)\n"
     "    (if (message = (Symbol intern ~s)) (count + 1) count)))")
    messages
    selector)
   environment))

(define (message-count subject selector)
  (message-list-count
   (format "((Mirror of ~a) messages)" subject)
   selector))

(define (has-message? subject selector)
  (= (message-count subject selector) 1))

(check-equal?
 (type->datum (typecheck-source "(Mirror of 1)"))
 'Mirror)
(check-equal?
 (type->datum (typecheck-source "((Mirror of 1) messages)"))
 '(List Symbol))

(define integer-mirror (eval-source "(Mirror of 1)" environment))
(check-equal? (aloe-value->string integer-mirror) "#<Mirror>")
(check-true (has-message? "1" "+"))
(check-true
 (string?
  (eval-source "((((Mirror of 1) messages) first) name)" environment)))

(define first-plus
  (eval-source "(((Mirror of 1) messages) first)" environment))
(define second-plus
  (eval-source "(((Mirror of 1) messages) first)" environment))
(check-equal? (eval-source "((((Mirror of 1) messages) first) name)"
                           environment)
              "+")
(check-eq? first-plus second-plus)

(void
 (eval-source "(define m (Mirror of (Point new 1 2)))" environment))
(check-true (has-message? "(Point new 1 2)" "x"))
(check-equal? (message-list-count "(m messages)" "+") 1)
(check-true (has-message? "Point" "new"))

(void
 (eval-source
  #<<ALOE
(define-class MirrorOverload
  (fields
    (field Int))
  (methods
    (pick (n Int) Int n)
    (pick (s String) String s)))
ALOE
  environment))
(check-equal? (message-count "(MirrorOverload new 1)" "pick") 1)
(check-equal? (message-count "(MirrorOverload new 1)" "field") 1)

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source source environment))))

(check-type-error "(Mirror of)")
(check-type-error "(Mirror of 1 2)")
(check-type-error "((Point new 1 2) messages)")
(check-type-error "(Point messages)")
(check-type-error "(1 messages)")
(check-type-error "(Mirror intern \"x\")")
