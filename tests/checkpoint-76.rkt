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

(check-equal?
 (type->datum
  (typecheck-source "((GelKey new \"0\") digit-value)"
                    checker-environment))
 'Int)
(check-equal?
 (type->datum
  (typecheck-source "((GelKey new \"0\") menu-index)"
                    checker-environment))
 'Int)
(check-equal?
 (type->datum
  (typecheck-source "((GelKey new \"q\") quit?)"
                    checker-environment))
 'Bool)
(check-equal?
 (type->datum
  (typecheck-source "((GelKey new \"return\") return?)"
                    checker-environment))
 'Bool)

;; The two callable parsers and their class objects are gone.
(for ([name '(GelKeyIndex GelDigitValue gel-key-index gel-digit-value)])
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

;; Digit values include zero; menu indexes intentionally do not.
(for ([text '("0" "1" "2" "3" "4" "5" "6" "7" "8" "9")]
      [value (in-range 10)])
  (check-equal?
   (eval-source (format "((GelKey new ~s) digit-value)" text) environment)
   value)
  (check-equal?
   (eval-source (format "((GelKey new ~s) menu-index)" text) environment)
   (if (zero? value) 0 value)))

(for ([text '("" "x" "10" "q" "return")])
  (check-equal?
   (eval-source (format "((GelKey new ~s) digit-value)" text) environment)
   -1)
  (check-equal?
   (eval-source (format "((GelKey new ~s) menu-index)" text) environment)
   0))

(check-true (eval-source "((GelKey new \"q\") quit?)" environment))
(check-false (eval-source "((GelKey new \"Q\") quit?)" environment))
(check-false (eval-source "((GelKey new \"return\") quit?)" environment))
(check-true (eval-source "((GelKey new \"return\") return?)" environment))
(check-false (eval-source "((GelKey new \"q\") return?)" environment))

;; handle-key remains the String-taking public boundary; internals take GelKey.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define state
  (GelStep new (gel-empty-stack push 10) #f (List empty) 0 #f))
(state handle-key "q")
ALOE
   checker-environment))
 'GelStep)
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source "(state handle-key (GelKey new \"q\"))"
                     checker-environment)))
(check-equal?
 (type->datum
  (typecheck-source "(state handle-idle (GelKey new \"q\"))"
                    checker-environment))
 'GelStep)
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source "(state handle-idle \"q\")" checker-environment)))

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

;; Public callers still pass text through idle and pending Int transitions.
(void (eval-source "(define int-stack (gel-empty-stack push 10))" environment))
(void
 (eval-source
  "(define int-state (GelStep new int-stack #f (List empty) 0 #f))"
  environment))
(void
 (eval-source
  "(define int-rows (gel-rows call (int-stack tos)))"
  environment))
(void (bind-row! "int-plus-row" "int-rows" "+" 1))
(void (eval-source "(define int-plus-key ((int-plus-row index) text))"
                   environment))
(void (eval-source "(define idle-zero (int-state handle-key \"0\"))"
                   environment))
(check-equal? (eval-source "((idle-zero pending) len)" environment) 0)
(check-false (eval-source "(idle-zero has-digits)" environment))
(void
 (eval-source
  "(define int-pending (int-state handle-key int-plus-key))"
  environment))
(void (eval-source "(define typed-zero (int-pending handle-key \"0\"))"
                   environment))
(check-true (eval-source "(typed-zero has-digits)" environment))
(check-equal? (eval-source "(typed-zero int-input)" environment) 0)
(void
 (eval-source
  "(define zero-result (typed-zero handle-key \"return\"))"
  environment))
(check-equal?
 (eval-source "(((zero-result stack) tos) subject)" environment)
 10)
(void
 (eval-source
  "(define int-cancelled (int-pending handle-key \"q\"))"
  environment))
(check-false (eval-source "(int-cancelled quit)" environment))
(check-equal? (eval-source "((int-cancelled pending) len)" environment) 0)
(void (eval-source "(define quit-state (int-state handle-key \"q\"))"
                   environment))
(check-true (eval-source "(quit-state quit)" environment))

;; Non-Int pending rows still use digit text as typed stack picks.
(void (eval-source "(define point (Point new 10 20))" environment))
(void
 (eval-source
  "(define point-rows (gel-rows call (Mirror of point)))"
  environment))
(void (bind-row! "point-plus-row" "point-rows" "+" 1))
(void (eval-source "(define point-plus-key ((point-plus-row index) text))"
                   environment))
(void
 (eval-source
  (string-append
   "(define point-state "
   "  (GelStep new "
   "    ((gel-empty-stack push (Point new 1 2)) push point) "
   "    #f (List empty) 0 #f))")
  environment))
(void
 (eval-source
  "(define point-pending (point-state handle-key point-plus-key))"
  environment))
(void
 (eval-source
  "(define point-result (point-pending handle-key \"2\"))"
  environment))
(check-equal?
 (eval-source "(((point-result stack) tos) raw)" environment)
 "#<Point 11 22>")
