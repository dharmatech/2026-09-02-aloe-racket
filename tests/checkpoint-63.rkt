#lang racket/base

(require racket/runtime-path
         rackunit
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

(define point-menu
  (eval-source
   "(gel-menu-text call (Point new 10 20))"
   environment))
(check-true (string? point-menu))
(check-regexp-match #px"(^|\n)[1-9]  x  0\n" point-menu)

(define int-menu (eval-source "(gel-menu-text call 1)" environment))
(check-true (string? int-menu))
(check-regexp-match #px"(^|\n)[1-9]  \\+  1\n" int-menu)

;; A stack mirror formats the subject's menu, not Mirror's hatch methods.
(define mirror-menu
  (eval-source
   "(gel-menu-text call (gel-tos call (gel-start call (Point new 10 20))))"
   environment))
(check-regexp-match #px"(^|\n)[1-9]  x  0\n" mirror-menu)
(check-false (regexp-match? #rx"  subject  " mirror-menu))
