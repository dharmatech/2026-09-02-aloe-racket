#lang racket/base

;; Spec section 5.4's density table: safe-rows alone on one leaf (or
;; safe-cells sent to each row, on a tree without safe-rows) for three
;; mixes of controls at 52x109 and 53x220. Scratch program, not a test.
;;   racket density.rkt <tree>

(require racket/list racket/string racket/format)

(module+ main
  (define root (vector-ref (current-command-line-arguments) 0))
  (define (rp rel) (simplify-path (build-path root rel)))
  (define (driver name) (dynamic-require (rp "aloe/driver.rkt") name))
  (define st ((driver 'make-driver)))
  (define driver-eval! (driver 'driver-eval!))
  (define driver-prepare! (driver 'driver-prepare!))
  (driver-eval! st `(load ,(path->string (rp "examples/aloemacs/editor.aloe"))))
  (driver-eval! st `(load ,(path->string (rp "lib/text.aloe"))))
  (define (ev e) (driver-eval! st e))
  (define (median-ms thunk n)
    (thunk)
    (define ds (for/list ([_ n]) (define b (current-inexact-monotonic-milliseconds)) (thunk) (- (current-inexact-monotonic-milliseconds) b)))
    (list-ref (sort ds <) (quotient n 2)))
  (ev '(define ed (AloemacsEditor new (Text from-string "") (Position new 0 0) #f 0 0 (List empty) (Option None) 0)))
  (define has-rows? (with-handlers ([exn:fail? (lambda (e) #f)]) (ev '(ed safe-rows (List of "a"))) #t))
  (define controls (append (for/list ([i 32]) (integer->char i)) (list (integer->char 127))))
  (for* ([shape '((52 109) (53 220))]
         [kind '(tab-every-1 all-33-cycling tab-per-row)])
    (define rows (car shape)) (define cols (cadr shape))
    (define row (list->string (for/list ([i cols])
                                (case kind
                                  [(tab-every-1) #\tab]
                                  [(all-33-cycling) (list-ref controls (modulo i 33))]
                                  [(tab-per-row) (if (= i 4) #\tab #\x)]))))
    (ev `(define rows (List of ,@(make-list rows row))))
    (define expr (if has-rows? '(ed safe-rows rows) '(rows map (fn (r) (ed safe-cells r)))))
    (printf "~ax~a ~a: ~a ms\n" rows cols kind (~r (median-ms (driver-prepare! st expr) 5) #:precision '(= 1)))))
