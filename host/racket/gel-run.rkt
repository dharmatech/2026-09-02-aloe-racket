#lang racket/base

;; Interactive Gel runner:
;;   racket host/racket/gel-run.rkt
;;
;; Optional prerequisite: raco pkg install tui-term

(require racket/runtime-path
         (only-in "../../aloe/env.rkt" env-define!)
         (only-in "../../aloe/eval.rkt" eval-expr)
         (only-in "../../aloe/main.rkt" make-top-level-env)
         (only-in "../../aloe/parse.rkt" parse-datum read-program)
         "term.rkt")

(define-runtime-path gel-main-path "../../gel/main.aloe")
(define-runtime-path point-path "../../examples/point.aloe")

(define (load-runtime-file! path environment)
  (define expressions
    (call-with-input-file path
      (lambda (input)
        (read-program input #:source-path path))))
  (for ([expression (in-list expressions)])
    (eval-expr expression environment)))

(define (run-gel)
  (define environment (make-top-level-env))
  (call-with-tty-term-receiver
   (lambda (term)
     (env-define! environment 'term term)
     (load-runtime-file! gel-main-path environment)
     (load-runtime-file! point-path environment)
     (eval-expr
      (parse-datum
       '(gel-main call (gel-start call (Point new 10 20))))
      environment))))

(module+ main
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (fprintf (current-error-port)
                              "gel: ~a\r\n"
                              (exn-message exception))
                     (exit 1))])
    (void (run-gel))))
