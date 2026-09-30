#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt"
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/parse.rkt")

(define-runtime-path option-path "../../lib/option.aloe")

(module+ main
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string option-path)))
  (define environment (driver-runtime-environment state))
  (define haystack (string-append (make-string 20000 #\a) "bc"))
  (runtime:env-define! environment 'bench-haystack haystack)
  (runtime:env-define! environment 'bench-pattern "bc")
  (runtime:env-define! environment 'bench-index 0)
  (runtime:env-define! environment 'bench-tail "")
  (define fast-expression
    (parse-datum '(bench-haystack find bench-pattern 0)))
  (define drop-expression
    (parse-datum '(bench-haystack drop bench-index)))
  (define starts-expression
    (parse-datum '(bench-tail starts-with? bench-pattern)))

  (define (fast)
    (eval-expr fast-expression environment))

  (define (slow)
    (for/first ([index (in-range (add1 (- (string-length haystack) 2)))]
                #:when
                (begin
                  (runtime:env-define! environment 'bench-index index)
                  (runtime:env-define!
                   environment 'bench-tail
                   (eval-expr drop-expression environment))
                  (eval-expr starts-expression environment)))
      index))

  (define (measure thunk)
    (collect-garbage)
    (define start (current-inexact-monotonic-milliseconds))
    (define result (thunk))
    (values result
            (/ (- (current-inexact-monotonic-milliseconds) start) 1000.0)))

  (for ([case-name (in-list '(hit miss))]
        [pattern (in-list '("bc" "bd"))]
        [expected (in-list '(20000 #f))])
    (runtime:env-define! environment 'bench-pattern pattern)
    (for ([trial (in-range 1 4)])
      (define-values (fast-result fast-seconds) (measure fast))
      (define-values (slow-result slow-seconds) (measure slow))
      (check-eq? (instance-value-constructor fast-result)
                 (if expected 'Some 'None))
      (check-equal? slow-result expected)
      (define ratio (/ slow-seconds fast-seconds))
      (printf "~a trial ~a: fast ~a s, slow ~a s, slow/fast ~a×\n"
              case-name trial fast-seconds slow-seconds ratio)
      (when (< ratio 50)
        (error 'search-timing "~a trial ~a measured below 50×" case-name trial)))))
