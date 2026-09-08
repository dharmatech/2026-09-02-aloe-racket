#lang racket/base

;; Interactive Gel runner:
;;   racket host/racket/gel-run.rkt
;;
;; Optional prerequisite: raco pkg install tui-term

(require racket/runtime-path
         (only-in "../../aloe/driver.rkt"
                  driver-eval!
                  driver-inject-host!
                  driver-load-file!
                  make-driver)
         "term.rkt")

(define-runtime-path gel-main-path "../../gel/main.aloe")
(define-runtime-path point-path "../../examples/point.aloe")

(define (run-gel)
  (call-with-tty-term-receiver
   (lambda (term)
     (define state (make-driver))
     (driver-inject-host! state 'term term)
     (driver-load-file! state gel-main-path)
     (driver-load-file! state point-path)
     (driver-eval!
      state
      '(gel-main call
         ((gel-empty-stack push (Point new 1 2))
          push
          (Point new 10 20)))))))

(module+ main
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (fprintf (current-error-port)
                              "gel: ~a\r\n"
                              (exn-message exception))
                     (exit 1))])
    (void (run-gel))))
