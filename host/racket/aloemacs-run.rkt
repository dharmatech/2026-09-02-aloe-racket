#lang racket/base

;; Interactive aloemacs runner:
;;   racket host/racket/aloemacs-run.rkt

(require racket/runtime-path
         (only-in "../../aloe/driver.rkt"
                  make-driver
                  driver-inject-host!
                  driver-load-file!
                  driver-eval!)
         "term.rkt")

(provide run-aloemacs
         run-aloemacs-with-term)

(define-runtime-path aloemacs-main-path
  "../../examples/aloemacs/main.aloe")

(define (run-aloemacs-with-term term)
  (define state (make-driver))
  (driver-inject-host! state 'term term)
  (driver-load-file! state aloemacs-main-path)
  (let loop ()
    (driver-eval!
     state
     '(term write
        (aloemacs-editor frame (term columns) (term rows))))
    (driver-eval!
     state
     '(define aloemacs-editor
        (aloemacs-editor handle-key (term read-key))))
    (unless (driver-eval! state '(aloemacs-editor quit))
      (loop))))

(define (run-aloemacs)
  (call-with-tty-term-receiver run-aloemacs-with-term))

(module+ main
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (fprintf (current-error-port)
                              "aloemacs: ~a\r\n"
                              (exn-message exception))
                     (exit 1))])
    (void (run-aloemacs))))
