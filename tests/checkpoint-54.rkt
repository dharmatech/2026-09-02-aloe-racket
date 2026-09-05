#lang racket/base

(require rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(check-equal?
 (type->datum (typecheck-source "(Symbol intern \"dist2\")"))
 'Symbol)

(check-equal?
 (eval-source "((Symbol intern \"dist2\") name)")
 "dist2")

(check-true
 (eval-source
  "((Symbol intern \"dist2\") = (Symbol intern \"dist2\"))"))

(check-false
 (eval-source
  "((Symbol intern \"dist2\") = (Symbol intern \"Dist2\"))"))

(define environment (make-top-level-env))
(check-equal?
 (eval-source
  (string-append
   "(define sel (Symbol intern \"dist2\"))\n"
   "(sel name)")
  environment)
 "dist2")

(define first-dist2 (eval-source "(Symbol intern \"dist2\")"))
(define second-dist2 (eval-source "(Symbol intern \"dist2\")"))
(check-eq? first-dist2 second-dist2)

(check-equal? (aloe-value->string first-dist2) "#<Symbol dist2>")
(check-equal? (eval-source "((Symbol intern \"\") name)") "")

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (typecheck-source source))))

(check-type-error "(Symbol intern 1)")
(check-type-error "((Symbol intern \"x\") = \"x\")")
(check-type-error "(Symbol new \"x\")")
