#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         (only-in tui/term/messages make-tkeymsg)
         (only-in "../aloe/env.rkt" env-define!)
         "../aloe/eval.rkt"
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt" make-top-level-env eval-source)
         "../aloe/parse.rkt"
         "../host/racket/term.rkt")

(define-runtime-path project-root "..")

(define (key-name value)
  (check-true (host-receiver? value))
  (host-receiver-send value 'name '()))

(test-case "printable a maps to an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\a)) "a"))

(test-case "printable q maps to an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\q)) "q"))

(test-case "return maps to a Key named return"
  (check-equal? (key-name (tkeymsg->aloe-key (make-tkeymsg 'return)))
                "return"))

(test-case "escape maps to a Key named escape"
  (check-equal? (key-name (tkeymsg->aloe-key (make-tkeymsg 'esc)))
                "escape"))

(test-case "an unknown named key keeps its symbolic name"
  (check-equal? (key-name (tkeymsg->aloe-key (make-tkeymsg 'left)))
                "left"))

(test-case "Key exposes name as an Aloe message"
  (define environment (make-top-level-env))
  (env-define!
   environment
   'key
   (tkeymsg->aloe-key (make-tkeymsg 'return)))
  (check-equal? (eval-expr (parse-datum '(key name)) environment)
                "return"))

(test-case "term receiver exposes read-key without reading the TTY"
  (define term (make-term-receiver))
  (check-eq? (host-receiver-name term) 'Term)
  (check-true (hash-has-key? (host-receiver-messages term) 'read-key)))

(test-case "the default evaluator does not bind term"
  (check-exn #rx"unbound symbol: term"
             (lambda () (eval-source "term"))))

(test-case "core and default driver do not require tui-term"
  (for ([relative-path (in-list '("aloe/main.rkt"
                                  "aloe/eval.rkt"
                                  "aloe/parse.rkt"
                                  "aloe/type.rkt"
                                  "bin/aloe"))])
    (define path (build-path project-root relative-path))
    (check-false
     (regexp-match? #rx"tui/term" (file->string path))
     relative-path))
  (check-false
   (regexp-match? #rx"tui-term"
                  (file->string (build-path project-root "info.rkt")))
   "info.rkt"))
