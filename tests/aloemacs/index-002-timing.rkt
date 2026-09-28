#lang racket/base

(require racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt")

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define expected-body (string-join (make-list 24 "x") "\r\n"))

(define (expected-frame cursor-row)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   expected-body
   (format "\u001b[~a;1H\u001b[?25h" cursor-row)))

(define (median values)
  (define sorted (sort values <))
  (/ (+ (list-ref sorted 9) (list-ref sorted 10)) 2.0))

(define (measure-case state name starting-line)
  (define durations
    (for/list ([step (in-range 1 21)])
      (define previous (string->symbol (format "~a-~a" name (sub1 step))))
      (define next (string->symbol (format "~a-~a" name step)))
      (define start (current-inexact-milliseconds))
      (driver-eval!
       state
       `(define ,next
          ((,previous handle-key "down") ensure-visible 80 24)))
      (define result (driver-eval! state `(,next frame 80 24)))
      (define elapsed (/ (- (current-inexact-milliseconds) start) 1000.0))
      (check-equal? result
                    (expected-frame
                     (if (= starting-line 0) (add1 step) 24))
                    (format "~a pair ~a" name step))
      elapsed))
  (define final-name (string->symbol (format "~a-20" name)))
  (check-equal? (driver-eval! state `((,final-name point) line))
                (+ starting-line 20))
  (check-equal? (driver-eval! state `((,final-name point) column)) 0)
  (printf "~a: total ~a seconds; median ~a seconds per pair\n"
          name (apply + durations) (median durations)))

(module+ main
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define source (string-append (apply string-append (make-list 9999 "x\n")) "x"))
  (driver-eval! state `(define source-text (Text from-string ,source)))
  (driver-eval!
   state
   '(define top-text
      ((source-text focus-at 0) case
        (None () source-text)
        (Some (text) text))))
  (driver-eval!
   state
   '(define bottom-text
      ((top-text focus-at 9000) case
        (None () top-text)
        (Some (text) text))))
  (driver-eval!
   state
   '(define top-0
      (AloemacsEditor new top-text (Position new 0 0) #f 0 0
        (List empty))))
  (driver-eval!
   state
   '(define bottom-0
      (AloemacsEditor new bottom-text (Position new 9000 0) #f 0 0
        (List empty))))
  (check-equal? (driver-eval! state '((top-0 text) focus-line)) 0)
  (check-equal? (driver-eval! state '((bottom-0 text) focus-line)) 9000)
  (measure-case state 'top 0)
  (measure-case state 'bottom 9000))
