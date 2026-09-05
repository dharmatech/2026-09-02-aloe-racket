#lang racket/base

;; Optional file runner for Aloe programs that use (term read-key):
;;   racket host/racket/term-run.rkt path/to/program.aloe
;;
;; The v0 key representation intentionally has two runtime shapes (String and
;; Key), so this isolated host runner does not extend or weaken Aloe's static
;; type language. The normal bin/aloe driver remains checked and term-free.

(require (only-in "../../aloe/driver.rkt" write-aloe-result)
         (only-in "../../aloe/env.rkt" env-define!)
         (only-in "../../aloe/eval.rkt" eval-expr)
         (only-in "../../aloe/main.rkt" make-top-level-env)
         (only-in "../../aloe/parse.rkt" read-program)
         "term.rkt")

(define (load-runtime-file! path environment)
  (define expressions
    (call-with-input-file path
      (lambda (input)
        (read-program input #:source-path path))))
  (for ([expression (in-list expressions)])
    (write-aloe-result (eval-expr expression environment))))

(define (run path)
  (define environment (make-top-level-env))
  (call-with-tty-term-receiver
   (lambda (term)
     (env-define! environment 'term term)
     (load-runtime-file! path environment))))

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
