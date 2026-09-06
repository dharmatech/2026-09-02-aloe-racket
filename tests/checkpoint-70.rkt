#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path loop-path "../gel/loop.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string loop-path))
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

(void (eval-source "(define rows (gel-rows of 10))" environment))
(void (bind-row! "plus-row" "rows" "+" 1))
(void (eval-source "(define plus-key ((plus-row index) text))" environment))
(void (eval-source "(define stack (gel-empty-stack push 10))" environment))
(void
 (eval-source
  "(define state (GelStep new stack #f (List empty) 0 #f))"
  environment))
(void
 (eval-source
  "(define pending (state handle-key plus-key))"
  environment))

;; One typed digit followed by return supplies the pending Int argument.
(void
 (eval-source
  "(define typed-two (pending handle-key \"2\"))"
  environment))
(check-eq? (eval-source "stack" environment)
           (eval-source "(typed-two stack)" environment))
(check-equal? (eval-source "(typed-two int-input)" environment) 2)
(check-true (eval-source "(typed-two has-digits)" environment))
(check-equal? (eval-source "((typed-two pending) len)" environment) 1)
(check-regexp-match #rx"pending.*\\+.*Int.*2"
                    (eval-source "(gel-menu-text call typed-two)" environment))

(void
 (eval-source
  "(define result (typed-two handle-key \"return\"))"
  environment))
(check-equal? (eval-source "((result pending) len)" environment) 0)
(check-equal?
 (eval-source "(((result stack) tos) subject)" environment)
 12)

;; The accumulator uses acc * 10 + digit.
(void
 (eval-source
  "(define typed-twenty-three (typed-two handle-key \"3\"))"
  environment))
(check-equal? (eval-source "(typed-twenty-three int-input)" environment) 23)

;; Return without any digits is a no-op and remains pending.
(void
 (eval-source
  "(define empty-return (pending handle-key \"return\"))"
  environment))
(check-eq? (eval-source "pending" environment)
           (eval-source "empty-return" environment))
(check-equal? (eval-source "((empty-return pending) len)" environment) 1)

;; q cancels the pending row and discards the accumulated literal.
(void
 (eval-source
  "(define cancelled (typed-two handle-key \"q\"))"
  environment))
(check-false (eval-source "(cancelled quit)" environment))
(check-eq? (eval-source "stack" environment)
           (eval-source "(cancelled stack)" environment))
(check-equal? (eval-source "((cancelled pending) len)" environment) 0)
(check-equal? (eval-source "(cancelled int-input)" environment) 0)
(check-false (eval-source "(cancelled has-digits)" environment))
