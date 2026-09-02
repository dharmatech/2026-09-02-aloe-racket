#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/driver.rkt"
         "../aloe/main.rkt")

(define-runtime-path point-path "../examples/point.aloe")
(define-runtime-path boids-path "../examples/boids.aloe")
(define-runtime-path nested-path "fixtures/load-nested-a.aloe")
(define-runtime-path cycle-path "fixtures/load-cycle-a.aloe")
(define-runtime-path missing-path "fixtures/no-such-file.aloe")

(define (load-form path)
  (format "(load ~s)" (path->string path)))

(define point-program
  (string-append
   (load-form point-path)
   "\n((Point new 1.0 0.0) dot (Point new 2.0 0.0))"))

;; load checks and evaluates in the caller's environments, so Point is
;; immediately available to the expression following the load.
(check-equal?
 (type->datum (typecheck-source point-program))
 'Float)
(check-equal? (eval-source point-program) 2.0)

;; A driver-loaded file carries its own directory into relative loads.
(define boids-source (file->string boids-path))
(define checker-environment (make-type-environment))
(check-equal?
 (type->datum
  (typecheck-source boids-source checker-environment
                    #:source-path boids-path))
 'Sim)
(check-equal?
 (type->datum (typecheck-source "(demo step)" checker-environment))
 'Sim)

(define boids-driver (make-driver))
(define boids-results
  (driver-load-file! boids-driver boids-path (open-output-string)))
(check-equal? (length boids-results) 2)
(check-equal?
 (driver-eval! boids-driver '(((demo step) flock) len))
 3)

;; Nested relative loads are allowed and share bindings with their caller.
(check-equal?
 (eval-source
  (string-append (load-form nested-path) "\nnested-value"))
 7)

;; Missing files and active load cycles are explicit errors.
(check-exn
 #px"load file not found"
 (lambda () (eval-source (load-form missing-path))))
(check-exn
 #px"load cycle"
 (lambda () (eval-source (load-form cycle-path))))

(check-false
 (regexp-match? #px"\\(define-class[[:space:]]+\\(?Point"
                boids-source))
