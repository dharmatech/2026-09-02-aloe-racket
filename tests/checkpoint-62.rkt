#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string loop-path))
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

(void (eval-source "(define p (Point new 10 20))" environment))
(void (eval-source "(define st (gel-start call p))" environment))
(check-equal? (eval-source "(st len)" environment) 1)
(check-equal?
 (aloe-value->string (eval-source "(gel-tos call st)" environment))
 "#<Mirror>")

;; Discover the current row positions instead of freezing dispatch order in
;; the Racket test.
(void (eval-source "(define point-rows (gel-rows call p))" environment))
(void (bind-row! "x-row" "point-rows" "x" 0))
(void (bind-row! "plus-row" "point-rows" "+" 1))
(void (eval-source "(define x-key ((x-row index) text))" environment))
(void (eval-source "(define plus-key ((plus-row index) text))" environment))

(void
 (eval-source
  "(define x-step (gel-handle-key call st x-key))"
  environment))
(check-false (eval-source "(x-step quit)" environment))
(check-equal? (eval-source "((x-step stack) len)" environment) 2)
(check-equal?
 (eval-source "((gel-tos call (x-step stack)) subject)" environment)
 10)

(void
 (eval-source
  "(define quit-step (gel-handle-key call st \"q\"))"
  environment))
(check-true (eval-source "(quit-step quit)" environment))
(check-eq? (eval-source "st" environment)
           (eval-source "(quit-step stack)" environment))

(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source "(gel-handle-key call st \"0\")" environment)))
(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source "(gel-handle-key call st \"+\")" environment)))
(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source
              "(gel-handle-key call st plus-key)"
              environment)))
(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source
              "(gel-handle-key call (List empty) \"1\")"
              environment)))
