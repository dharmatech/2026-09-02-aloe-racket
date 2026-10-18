#lang racket/base

;; Spec section 6.1's contract, checked on small texts: lines-from equals
;; focus-at then next-lines for every focus, top, and count.
;; Scratch program, not a test.
;;   racket lines-from-equivalence.rkt <tree>

(require racket/list racket/string)

(module+ main
  (define root (vector-ref (current-command-line-arguments) 0))
  (define (rp rel) (simplify-path (build-path root rel)))
  (define (driver name) (dynamic-require (rp "aloe/driver.rkt") name))
  (define st ((driver 'make-driver)))
  (define ev (lambda (e) ((driver 'driver-eval!) st e)))
  (ev `(load ,(path->string (rp "lib/text.aloe"))))
  (define checks 0)
  (for ([src '("" "a" "a\n\nc" "0\n1\n2\n3\n4\n" "\n\n")])
    (define n (length (string-split src "\n" #:trim? #f)))
    (for* ([indexed? '(#f #t)]
           [focus (if indexed? (in-range n) (in-list '(0)))]
           [top (in-range -1 (+ n 2))]
           [count (in-range -1 (+ n 3))])
      (define text
        (if indexed?
            `((((Text from-string ,src) indexed-value) focus-at ,focus) case (None () (Text from-string "")) (Some (t) t))
            `(Text from-string ,src)))
      (ev `(check (,text lines-from ,top ,count)
                  ((,text focus-at ,top) case
                    (None () (Option None))
                    (Some (at) (Option Some (at next-lines ,count))))))
      (set! checks (add1 checks))))
  (printf "~a checks passed\n" checks))
