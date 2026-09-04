#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define-runtime-path core-path "../examples/mpl/core.aloe")
(define-runtime-path boids-path "../examples/boids.aloe")

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(for ([expression
       (in-list
        '("(x show)"
          "((x + 2) show)"
          "((x * 0) show)"
          "((x ^ 2) show)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'String))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define sum-show (eval-source "((x + 2) show)" runtime-environment))
(check-regexp-match #rx"x" sum-show)
(check-regexp-match #rx"\\+" sum-show)
(check-regexp-match #rx"2" sum-show)
(check-equal? sum-show "(x + 2)")

(check-equal? (eval-source "((x * 0) show)" runtime-environment) "0")
(check-equal? (eval-source "((x ^ 2) show)" runtime-environment)
              "(x ^ 2)")
(check-equal? (eval-source "((x * y) show)" runtime-environment)
              "(x * y)")
(check-equal? (eval-source "(((x * y) * 2) show)" runtime-environment)
              "((x * y) * 2)")

;; The default REPL display sends show; :raw selects the old host printer.
(define repl-driver (make-driver))
(void (driver-load-file! repl-driver core-path (open-output-string)))
(void (driver-eval! repl-driver '(define x (Sym new "x"))))
(define repl-output (open-output-string))
(define repl-errors (open-output-string))
(run-repl repl-driver
          (open-input-string "(x + 2)\n:raw (x + 2)\n(exit)\n")
          repl-output
          repl-errors)
(define repl-text (get-output-string repl-output))
(check-regexp-match #rx"\\(x \\+ 2\\)" repl-text)
(check-regexp-match #rx"#<Sum" repl-text)
(check-true
 (or (regexp-match? #rx"terms" repl-text)
     (regexp-match? #rx"Sum" repl-text)))
(check-equal? (get-output-string repl-errors) "")

;; The structural API remains raw independent of REPL display policy.
(check-regexp-match
 #rx"#<Sum"
 (aloe-value->string
  (driver-eval! repl-driver '(x + 2))))

;; Boids has no show requirement and remains unchanged.
(define boids-source (file->string boids-path))
(define boids-checker-environment (make-type-environment))
(check-equal?
 (type->datum
  (typecheck-source boids-source boids-checker-environment
                    #:source-path boids-path))
 'Sim)
(check-equal?
 (type->datum
  (typecheck-source "(demo step)" boids-checker-environment))
 'Sim)
(define boids-runtime-environment (make-top-level-env))
(void (eval-source boids-source boids-runtime-environment
                   #:source-path boids-path))
(check-equal?
 (eval-source "(((demo step) flock) len)" boids-runtime-environment)
 3)
