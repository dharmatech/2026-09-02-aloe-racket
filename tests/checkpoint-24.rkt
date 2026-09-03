#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define environment (make-top-level-env))

;; The root-relative source path resolves through the info.rkt project root
;; when the test runner's working directory is tests/.
(void
 (eval-source
  (string-append
   "(load \"examples/mpl/sym.aloe\")\n"
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))")
  environment))

(check-equal? (eval-source "(x name)" environment) "x")
(check-equal? (eval-source "(y name)" environment) "y")
(check-not-equal?
 (eval-source "(x name)" environment)
 (eval-source "(y name)" environment))
