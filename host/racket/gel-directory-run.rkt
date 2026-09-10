#lang racket/base

;; Interactive filesystem-capable Gel runner:
;;   racket host/racket/gel-directory-run.rkt path/to/application.aloe
;;
;; Optional prerequisite: raco pkg install tui-term

(require racket/runtime-path
         (only-in "../../aloe/driver.rkt"
                  driver-eval!
                  driver-inject-host!
                  driver-load-file!
                  make-driver)
         (only-in "fs.rkt" make-fs-receiver)
         "term.rkt")

(define-runtime-path gel-main-path "../../gel/main.aloe")

(define (run-gel-directory path)
  (call-with-tty-term-receiver
   (lambda (term)
     (define state (make-driver))
     (driver-inject-host! state 'term term)
     (driver-inject-host! state 'fs-host (make-fs-receiver))
     (driver-load-file! state gel-main-path)
     (driver-load-file! state path)
     (driver-eval!
      state
      '(gel-main start gel-start-value)))))

(module+ main
  (define arguments (vector->list (current-command-line-arguments)))
  (unless (= (length arguments) 1)
    (eprintf "usage: racket host/racket/gel-directory-run.rkt path.aloe\n")
    (exit 2))
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (fprintf (current-error-port)
                              "gel-directory: ~a\r\n"
                              (exn-message exception))
                     (exit 1))])
    (void (run-gel-directory (car arguments)))))
