#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path menu-path "../gel/menu.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string menu-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

(define (matching-row-count rows selector arity)
  (eval-source
   (format
    (string-append
     "(~a fold 0\n"
     "  (fn (count row)\n"
     "    (if (((row selector) name) = ~s)\n"
     "        (if ((row arity) = ~a) (count + 1) count)\n"
     "        count)))")
    rows
    selector
    arity)
   environment))

(define (selector-row-count rows selector)
  (eval-source
   (format
    (string-append
     "(~a fold 0\n"
     "  (fn (count row)\n"
     "    (if (((row selector) name) = ~s)\n"
     "        (count + 1)\n"
     "        count)))")
    rows
    selector)
   environment))

(void (eval-source "(define int-rows (gel-rows call 1))" environment))
(check-true (positive? (eval-source "(int-rows len)" environment)))
(check-equal? (matching-row-count "int-rows" "+" 1) 1)
(check-equal? (matching-row-count "int-rows" "=" 1) 1)
(check-equal? (selector-row-count "int-rows" "messages") 0)
(check-equal? (selector-row-count "int-rows" "signatures") 0)
(check-equal? (selector-row-count "int-rows" "invoke") 0)
(check-equal? (eval-source "((int-rows first) index)" environment) 1)
(check-equal? (eval-source "(((int-rows rest) first) index)" environment) 2)
(check-true (string? (eval-source "((int-rows first) label)" environment)))
(check-equal?
 (eval-source "((int-rows first) label)" environment)
 (eval-source "(((((Mirror of 1) signatures) first) selector) name)"
              environment))

;; The same generic callable is reusable at a different subject type.
(void
 (eval-source
  "(define point-rows (gel-rows call (Point new 1 2)))"
  environment))
(check-equal? (matching-row-count "point-rows" "x" 0) 1)
(check-equal? (matching-row-count "point-rows" "+" 1) 1)

(define (check-type-error source)
  (check-exn exn:fail:aloe-type?
             (lambda () (eval-source source environment))))

(check-type-error "(1 gel-rows)")
(check-type-error "(gel-rows call)")

;; Gel menu construction consumes signatures but never invokes them.
(check-false
 (regexp-match? #rx"\\(.*invoke"
                (file->string menu-path)))
