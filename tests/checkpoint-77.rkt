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

;; One GelRows value remains independently polymorphic, and its exact Mirror
;; overload has the same public result type as the generic overload.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define int-rows-77 (gel-rows of 10))
(define point-rows-77 (gel-rows of (Point new 10 20)))
(define mirror-rows-77 (gel-rows of (Mirror of (Point new 10 20))))
(mirror-rows-77 len)
ALOE
   checker-environment))
 'Int)

;; The duplicate mirror-specific callable and its class are gone.
(for ([name '(GelRowsFromMirror gel-rows-from-mirror)])
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

(void (eval-source "(define point-77 (Point new 10 20))" environment))
(void (eval-source "(define point-mirror-77 (Mirror of point-77))" environment))
(void (eval-source "(define value-rows-77 (gel-rows of point-77))"
                   environment))
(void (eval-source "(define mirror-rows-77 (gel-rows of point-mirror-77))"
                   environment))

;; Both routes preserve dispatch-table ordering, selectors, arities, and
;; one-based indexes, which are precisely the fields rendered by rows-text.
(check-equal?
 (eval-source "(gel-text rows-text value-rows-77)" environment)
 (eval-source "(gel-text rows-text mirror-rows-77)" environment))
(check-equal? (eval-source "(value-rows-77 len)" environment)
              (eval-source "(mirror-rows-77 len)" environment))
(check-equal? (eval-source "((mirror-rows-77 first) index)" environment) 1)
(void
 (eval-source
  #<<ALOE
(define-class GelRowIndexAudit77
  (fields
    (next Int)
    (ok Bool))
  (methods
    (add (row GelRow) GelRowIndexAudit77
      (GelRowIndexAudit77 new
        ((self next) + 1)
        (if (self ok)
            ((row index) = (self next))
            #f)))))
(define index-audit-77
  (mirror-rows-77 fold
    (GelRowIndexAudit77 new 1 #t)
    (fn (audit row) (audit add row))))
ALOE
  environment))
(check-true (eval-source "(index-audit-77 ok)" environment))
(check-equal?
 (eval-source "(index-audit-77 next)" environment)
 (eval-source "((mirror-rows-77 len) + 1)" environment))

;; Every row retains the signature from which its selector and arity came.
(check-true
 (eval-source
  #<<ALOE
(mirror-rows-77 fold #t
  (fn (ok row)
    (if ok
        (if (((row selector) name) =
             (((row signature) selector) name))
            ((row arity) = (((row signature) params) len))
            #f)
        #f)))
ALOE
  environment))

;; The exact overload reflects the mirror's subject API, not Mirror itself.
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

(check-equal? (selector-count "mirror-rows-77" "x") 1)
(check-equal? (selector-count "mirror-rows-77" "+") 1)
(check-equal? (selector-count "mirror-rows-77" "subject") 0)
(check-equal? (selector-count "mirror-rows-77" "signatures") 0)
(check-equal? (selector-count "mirror-rows-77" "invoke") 0)

;; A preserved row signature still invokes against the original mirror.
(void
 (eval-source
  #<<ALOE
(define x-row-77
  (mirror-rows-77 fold
    (mirror-rows-77 first)
    (fn (found row)
      (if (((row selector) name) = "x") row found))))
ALOE
  environment))
(check-equal?
 (eval-source "(point-mirror-77 invoke (x-row-77 signature))" environment)
 10)

;; Public menu rendering remains identical for a value and its mirror.
(check-equal? (eval-source "(gel-text menu point-77)" environment)
              (eval-source "(gel-text menu point-mirror-77)" environment))
