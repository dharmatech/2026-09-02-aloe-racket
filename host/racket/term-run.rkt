#lang racket/base

;; Optional file runner for Aloe programs that use (term read-key):
;;   racket host/racket/term-run.rkt path/to/program.aloe
;;
;; The production Term interface gives read-key one checked result shape:
;; String. The normal bin/aloe driver remains term-free.

(require (only-in "../../aloe/driver.rkt"
                  driver-inject-host!
                  driver-load-port!
                  make-driver)
         "term.rkt")

(define (run path)
  (call-with-tty-term-receiver
   (lambda (term)
     (define state (make-driver))
     (driver-inject-host! state 'term term)
     (call-with-input-file path
       (lambda (input)
         (driver-load-port!
          state input (current-output-port) #:source-path path))))))

(module+ main
  (define arguments (vector->list (current-command-line-arguments)))
  (unless (= (length arguments) 1)
    (eprintf "usage: racket host/racket/term-run.rkt path.aloe\n")
    (exit 2))
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (eprintf "aloe-term: ~a\n" (exn-message exception))
                     (exit 1))])
    (run (car arguments))))
