#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path stack-path "../gel/stack.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string stack-path))
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

;; Int + with a raw argument.
(void (eval-source "(define int-stack (gel-push call (List empty) 1))"
                   environment))
(void (eval-source "(define int-rows (gel-rows call 1))" environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(check-equal?
 (eval-source "(((int-plus-row signature) params) len)" environment)
 1)
(check-equal?
 (aloe-value->string
  (eval-source "(((int-plus-row signature) params) first)" environment))
 "#<Symbol Int>")
(void
 (eval-source
  "(define int-stack-2 (gel-invoke-one call int-stack int-plus-row 2))"
  environment))
(check-equal? (eval-source "(int-stack-2 len)" environment) 2)
(check-equal?
 (eval-source "((gel-tos call int-stack-2) subject)" environment)
 3)

;; The exact Mirror overload unwraps a mirrored argument before invoke.
(void (eval-source "(define other-mirror (Mirror of 10))" environment))
(void
 (eval-source
  (string-append
   "(define int-stack-3 "
   "  (gel-invoke-one call int-stack int-plus-row other-mirror))")
  environment))
(check-equal?
 (eval-source "((gel-tos call int-stack-3) subject)" environment)
 11)

;; Point + with a raw Point argument.
(void (eval-source "(define p (Point new 1 2))" environment))
(void (eval-source "(define q (Point new 3 4))" environment))
(void (eval-source "(define point-stack (gel-push call (List empty) p))"
                   environment))
(void (eval-source "(define point-rows (gel-rows call p))" environment))
(void (bind-row! "point-plus-row" "point-rows" "+" 1))
(void (bind-row! "point-x-row" "point-rows" "x" 0))
(void
 (eval-source
  (string-append
   "(define point-stack-2 "
   "  (gel-invoke-one call point-stack point-plus-row q))")
  environment))
(check-equal? (eval-source "(point-stack-2 len)" environment) 2)

;; These annotated parameters supply the expected Point type for subject.
(void
 (eval-source
  #<<ALOE
(define-class PointProbe
  (fields)
  (methods
    (x-of (point (Point Int)) Int (point x))
    (y-of (point (Point Int)) Int (point y))))
ALOE
  environment))
(check-equal?
 (eval-source
  (string-append
   "((PointProbe new) x-of "
   "  ((gel-tos call point-stack-2) subject))")
  environment)
 4)
(check-equal?
 (eval-source
  (string-append
   "((PointProbe new) y-of "
   "  ((gel-tos call point-stack-2) subject))")
  environment)
 6)

;; invoke owns arity and runtime argument validation; Gel does not re-resolve.
(check-exn #rx"argument 1 does not match|unknown message"
           (lambda ()
             (eval-source
              (string-append
               "(gel-invoke-one call point-stack point-plus-row 1)")
              environment)))
(check-exn #rx"arity error"
           (lambda ()
             (eval-source
              (string-append
               "(gel-invoke-one call point-stack point-x-row q)")
              environment)))
