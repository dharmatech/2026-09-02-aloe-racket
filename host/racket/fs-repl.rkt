#lang racket/base

;; Interactive Aloe REPL with explicit production filesystem authority:
;;   racket host/racket/fs-repl.rkt
;;
;; The ordinary bin/aloe driver remains capability-free.

(require (only-in "../../aloe/driver.rkt"
                  driver-inject-host!
                  make-driver
                  run-repl)
         "fs.rkt")

(provide run-fs-repl)

(define (run-fs-repl [input (current-input-port)]
                     [output (current-output-port)]
                     [error-output (current-error-port)])
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-receiver))
  (run-repl state input output error-output))

(module+ main
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (eprintf "aloe-fs: ~a\n" (exn-message exception))
                     (exit 1))])
    (run-fs-repl)))
