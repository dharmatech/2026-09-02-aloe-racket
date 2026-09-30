#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type?))

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (state-with-editor)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  state)

(define (editor-expression source line column scroll-row)
  `(AloemacsEditor new
     (Text from-string ,source)
     (Position new ,line ,column)
     #f
     ,scroll-row
     0
     (List empty) (if #t (Option None) (Option Some (Position new 0 0)))))

(define (frame body row column)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   body
   (format "\u001b[~a;~aH\u001b[?25h" row column)))

(test-case "viewport-top is no longer an editor message"
  (define state (state-with-editor))
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval!
      state
      `(,(editor-expression "zero\none" 0 0 0)
        viewport-top (Text from-string "zero\none") 0)))))

(test-case "Up from the last row keeps the fitted four-row frame"
  (define state (state-with-editor))
  (driver-eval!
   state
   `(define last-row
      ,(editor-expression "zero\none\ntwo\nthree\nfour\nfive" 3 0 0)))
  (driver-eval! state '(define fitted (last-row ensure-visible 8 4)))
  (driver-eval!
   state
   '(define up ((fitted handle-key "up") ensure-visible 8 4)))
  (check-equal? (driver-eval! state '(up scroll-row)) 0)
  (check-equal?
   (driver-eval! state '(up frame 8 4))
   (frame "zero\r\none\r\ntwo\r\nthree" 3 1)))

(test-case "origin below point yields an empty-body frame without hanging"
  (define state (state-with-editor))
  (driver-eval!
   state
   `(define unfitted
      ,(editor-expression "zero\none\ntwo\nthree" 1 0 5)))
  (define result-channel (make-channel))
  (define worker-custodian (make-custodian))
  (parameterize ([current-custodian worker-custodian])
    (thread
     (lambda ()
       (channel-put
        result-channel
        (with-handlers ([exn? values])
          (driver-eval! state '(unfitted frame 8 4)))))))
  (define result (sync/timeout 5 result-channel))
  (custodian-shutdown-all worker-custodian)
  (check-not-false result "frame did not return within five seconds")
  (check-true (string? result))
  (check-equal? result (frame "" -3 1)))
