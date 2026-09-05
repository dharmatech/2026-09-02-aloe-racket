#lang racket/base

;; Interactive Gel runner:
;;   racket host/racket/gel-run.rkt
;;
;; Optional prerequisite: raco pkg install tui-term

(require racket/runtime-path
         (only-in "../../aloe/driver.rkt" write-aloe-result)
         (only-in "../../aloe/env.rkt" env-define!)
         (only-in "../../aloe/eval.rkt" eval-expr)
         "../../aloe/host.rkt"
         (only-in "../../aloe/main.rkt" eval-source make-top-level-env)
         (only-in "../../aloe/parse.rkt" parse-datum)
         "term.rkt")

(define-runtime-path loop-path "../../gel/loop.aloe")
(define-runtime-path point-path "../../examples/point.aloe")

(define (load-gel! environment)
  (eval-source
   (format "(load ~s)" (path->string loop-path))
   environment)
  (eval-source
   (format "(load ~s)" (path->string point-path))
   environment)
  (eval-source
   "(define gel-stack (gel-start call (Point new 10 20)))"
   environment))

(define (read-aloe-key environment)
  ;; This follows term-run's runtime-only host-receiver path. The ordinary
  ;; checked Aloe environment remains free of a Term type.
  (eval-expr (parse-datum '(term read-key)) environment))

(define (key-value->string value)
  (cond
    [(string? value) value]
    [(and (host-receiver? value)
          (eq? (host-receiver-name value) 'Key))
     (define name (host-receiver-state value))
     (and (string? name)
          (regexp-match? #px"^[A-Za-z]$" name)
          name)]
    [else #f]))

(define (print-current-state environment)
  (display "TOS: ")
  (write-aloe-result
   (eval-source "((gel-tos call gel-stack) subject)" environment))
  (display
   (eval-source
    "(gel-menu-text call (gel-tos call gel-stack))"
    environment))
  (flush-output))

(define (handle-key! environment key)
  (eval-source
   (format
    "(define gel-step (gel-handle-key call gel-stack ~s))"
    key)
   environment)
  (cond
    [(eval-source "(gel-step quit)" environment) #f]
    [else
     (eval-source "(define gel-stack (gel-step stack))" environment)
     (print-current-state environment)
     #t]))

(define (run-gel)
  (define environment (make-top-level-env))
  (load-gel! environment)
  (call-with-tty-term-receiver
   (lambda (term)
     (env-define! environment 'term term)
     (displayln "Gel — digit selects a zero-argument row; q quits.")
     (print-current-state environment)
     (let loop ()
       (define key (key-value->string (read-aloe-key environment)))
       (define continue?
         (cond
           [(not key) #t]
           [else
            (with-handlers ([exn:fail?
                             (lambda (exception)
                               (printf "gel: ~a\n" (exn-message exception))
                               (flush-output)
                               #t)])
              (handle-key! environment key))]))
       (when continue? (loop))))))

(module+ main
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (eprintf "gel: ~a\n" (exn-message exception))
                     (exit 1))])
    (run-gel)))
