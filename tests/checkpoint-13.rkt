#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt")

(define-runtime-path fixture-path "fixtures/checkpoint-13.aloe")
(define-runtime-path boids-path "../examples/boids.aloe")
(define-runtime-path boids-sexpr-path "../boids.sexpr")

(define fixture-driver (make-driver))
(define fixture-output (open-output-string))
(check-equal?
 (driver-load-file! fixture-driver fixture-path fixture-output)
 '(1))
(check-equal? (get-output-string fixture-output) "1\n")

;; Keep the .aloe example byte-for-byte aligned with the accepted Boids source.
(check-equal? (file->string boids-path)
              (file->string boids-sexpr-path))

(define boids-driver (make-driver))
(define boids-output (open-output-string))
(define boids-results
  (driver-load-file! boids-driver boids-path boids-output))
(check-equal? (length boids-results) 2)
(check-true
 (andmap (lambda (value)
           (regexp-match? #rx"^#<Sim " (aloe-value->string value)))
         boids-results))
(check-true
 (regexp-match? #rx"^#<Sim "
                (aloe-value->string (driver-eval! boids-driver 'demo))))
(check-equal?
 (driver-eval! boids-driver '(((demo step) flock) len))
 3)

(define repl-driver (make-driver))
(define repl-output (open-output-string))
(define repl-errors (open-output-string))
(run-repl repl-driver
          (open-input-string
           "(define x 7)\nx\n(1 no-such)\nx\n(exit)\n")
          repl-output
          repl-errors)
(check-equal? (driver-eval! repl-driver 'x) 7)
(check-equal?
 (length (regexp-match* #rx"7\n" (get-output-string repl-output)))
 2)
(check-regexp-match #rx"unknown message" (get-output-string repl-errors))
