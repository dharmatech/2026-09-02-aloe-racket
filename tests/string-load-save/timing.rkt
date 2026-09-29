#lang racket/base

(require racket/list
         racket/runtime-path
         racket/string
         "../../aloe/driver.rkt"
         "../../aloe/eval.rkt")

(define-runtime-path text-path "../../lib/text.aloe")

(module+ main
  (define source (string-join (make-list 10000 "x") "\n"))
  (unless (= (string-length source) 19999)
    (error 'timing "fixture must have exactly 19,999 characters"))
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string text-path)))

  (define started (current-inexact-milliseconds))
  (driver-eval! state `(define source-text-000 (Text from-string ,source)))
  (driver-eval! state
                '(define indexed-text-000 (source-text-000 indexed-value)))
  (define elapsed-seconds
    (/ (- (current-inexact-milliseconds) started) 1000.0))

  (unless (eq? (instance-value-constructor
                (driver-eval! state 'indexed-text-000))
               'indexed)
    (error 'timing "Text.indexed-value did not produce indexed Text"))
  (unless (= (driver-eval!
              state
              '(indexed-text-000 case
                 (from-string (stored-source) -1)
                 (indexed (above current below focus) focus)))
             0)
    (error 'timing "indexed Text focus is not zero"))
  (unless (string=? (driver-eval! state '(indexed-text-000 to-string))
                    source)
    (error 'timing "indexed Text did not round-trip the source"))
  (printf "String split-lines / Text.indexed-value: ~a s\n"
          elapsed-seconds)
  (unless (< elapsed-seconds 0.110)
    (error 'timing "interval 1 must be below 0.110 s"))

  (define (check-indexed receiver expected-focus)
    (unless (eq? (instance-value-constructor (driver-eval! state receiver))
                 'indexed)
      (error 'timing "timed Text must be indexed"))
    (unless (= (driver-eval! state `(,receiver focus-line)) expected-focus)
      (error 'timing "timed Text has the wrong focus")))

  (check-indexed 'indexed-text-000 0)
  (define focus-zero-start (current-inexact-milliseconds))
  (define focus-zero-source (driver-eval! state '(indexed-text-000 to-string)))
  (define focus-zero-seconds
    (/ (- (current-inexact-milliseconds) focus-zero-start) 1000.0))
  (unless (string=? focus-zero-source source)
    (error 'timing "focus-0 save did not round-trip the source"))
  (check-indexed 'indexed-text-000 0)
  (printf "Text.to-string, indexed focus 0: ~a s\n" focus-zero-seconds)
  (unless (< focus-zero-seconds 0.029)
    (error 'timing "interval 2 must be below 0.029 s"))

  (driver-eval!
   state
   '(define last-text-001
      ((indexed-text-000 focus-at 9999) case
        (None () indexed-text-000)
        (Some (text) text))))
  (check-indexed 'last-text-001 9999)
  (define last-start (current-inexact-milliseconds))
  (define last-source (driver-eval! state '(last-text-001 to-string)))
  (define last-seconds
    (/ (- (current-inexact-milliseconds) last-start) 1000.0))
  (unless (string=? last-source source)
    (error 'timing "last-line save did not round-trip the source"))
  (check-indexed 'last-text-001 9999)
  (printf "Text.to-string, indexed focus 9,999: ~a s\n" last-seconds)
  (unless (< last-seconds 0.029)
    (error 'timing "interval 3 must be below 0.029 s")))
