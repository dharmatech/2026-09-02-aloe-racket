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
(void
 (typecheck-source
  (format "(load ~s)" (path->string point-path))
  checker-environment))

;; The same GelRows service remains independently polymorphic across `of`
;; sends, including the exact Mirror overload, and owns selection.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define int-rows-81 (gel-rows of 10))
(define point-rows-81 (gel-rows of (Point new 10 20)))
(define mirror-rows-81 (gel-rows of (Mirror of (Point new 10 20))))
(gel-rows select mirror-rows-81 1)
ALOE
   checker-environment))
 'GelRow)

;; Function-shaped construction and the separate selector are gone.
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source "(gel-rows call 10)" checker-environment)))
(for ([name '(GelSelectRow gel-select-row)])
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

(void (eval-source "(define point-81 (Point new 10 20))" environment))
(void (eval-source "(define point-mirror-81 (Mirror of point-81))" environment))
(void (eval-source "(define value-rows-81 (gel-rows of point-81))"
                   environment))
(void (eval-source "(define mirror-rows-81 (gel-rows of point-mirror-81))"
                   environment))

;; Ordinary values and existing mirrors retain identical subject rows.
(check-equal?
 (eval-source "(gel-menu-text rows-text value-rows-81)" environment)
 (eval-source "(gel-menu-text rows-text mirror-rows-81)" environment))
(check-equal? (eval-source "(value-rows-81 len)" environment)
              (eval-source "(mirror-rows-81 len)" environment))

(define (selector-count rows selector)
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

(check-equal? (selector-count "mirror-rows-81" "x") 1)
(check-equal? (selector-count "mirror-rows-81" "+") 1)
(check-equal? (selector-count "mirror-rows-81" "subject") 0)
(check-equal? (selector-count "mirror-rows-81" "signatures") 0)

;; `select` returns the same existing row for every valid one-based index.
(define row-count (eval-source "(mirror-rows-81 len)" environment))
(for ([index (in-range 1 (add1 row-count))])
  (define selected
    (eval-source (format "(gel-rows select mirror-rows-81 ~a)" index)
                 environment))
  (define existing
    (eval-source
     (format
      (string-append
       "(mirror-rows-81 fold\n"
       "  (mirror-rows-81 first)\n"
       "  (fn (found candidate)\n"
       "    (if ((candidate index) = ~a) candidate found)))")
      index)
     environment))
  (check-eq? selected existing)
  (check-equal?
   (eval-source (format "((gel-rows select mirror-rows-81 ~a) index)" index)
                environment)
   index))

;; Missing indices retain the existing deliberate empty-first failure.
(for ([index (list 0 (add1 row-count))])
  (check-exn
   #rx"first on empty List"
   (lambda ()
     (eval-source (format "(gel-rows select mirror-rows-81 ~a)" index)
                  environment))))

;; Menu rendering and the key-selected invocation still consume these rows.
(check-equal? (eval-source "(gel-menu-text call point-81)" environment)
              (eval-source "(gel-menu-text rows-text value-rows-81)"
                           environment))
(void
 (eval-source
  #<<ALOE
(define x-row-81
  (value-rows-81 fold
    (value-rows-81 first)
    (fn (found candidate)
      (if (((candidate selector) name) = "x") candidate found))))
(define point-state-81
  (GelStep new (gel-empty-stack push point-81)
    #f (List empty) 0 #f))
(define x-step-81
  (point-state-81 handle-key ((x-row-81 index) text)))
ALOE
  environment))
(check-eq? (eval-source "x-row-81" environment)
           (eval-source
            "(gel-rows select value-rows-81 (x-row-81 index))"
            environment))
(check-equal? (eval-source "(((x-step-81 stack) tos) subject)" environment)
              10)
