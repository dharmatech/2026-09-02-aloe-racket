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
(void
 (eval-source
  (string-append
   "(define st "
   "  (GelStep new (gel-empty-stack push p) #f (List empty) 0 #f #f))")
  environment))
(check-equal? (eval-source "(((st stack) items) len)" environment) 1)
(check-equal?
 (aloe-value->string (eval-source "((st stack) tos)" environment))
 "#<Mirror>")

;; Discover the current row positions instead of freezing dispatch order in
;; the Racket test.
(void (eval-source "(define point-rows (gel-rows of p))" environment))
(void (bind-row! "x-row" "point-rows" "x" 0))
(void (bind-row! "plus-row" "point-rows" "+" 1))
(void (eval-source "(define x-key ((x-row index) text))" environment))
(void (eval-source "(define plus-key ((plus-row index) text))" environment))

(void
 (eval-source
  "(define x-step (st handle-key x-key))"
  environment))
(check-false (eval-source "(x-step quit)" environment))
(check-equal? (eval-source "(((x-step stack) items) len)" environment) 2)
(check-equal?
 (eval-source "(((x-step stack) tos) subject)" environment)
 10)

(void
 (eval-source
  "(define quit-step (st handle-key \"q\"))"
  environment))
(check-true (eval-source "(quit-step quit)" environment))
(check-eq? (eval-source "(st stack)" environment)
           (eval-source "(quit-step stack)" environment))

(void
 (eval-source
  "(define zero-step (st handle-key \"0\"))"
  environment))
(check-false (eval-source "(zero-step quit)" environment))
(check-eq? (eval-source "(st stack)" environment)
           (eval-source "(zero-step stack)" environment))

(void
 (eval-source
  "(define unknown-step (st handle-key \"+\"))"
  environment))
(check-false (eval-source "(unknown-step quit)" environment))
(check-eq? (eval-source "(st stack)" environment)
           (eval-source "(unknown-step stack)" environment))

(void
 (eval-source
  "(define argument-step (st handle-key plus-key))"
  environment))
(check-false (eval-source "(argument-step quit)" environment))
(check-eq? (eval-source "(st stack)" environment)
           (eval-source "(argument-step stack)" environment))

(check-exn #rx"first on empty List"
           (lambda ()
             (eval-source
              (string-append
               "((GelStep new gel-empty-stack #f (List empty) 0 #f #f) "
               " handle-key \"1\")")
              environment)))
