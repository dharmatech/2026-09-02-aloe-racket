#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../aloe/host.rkt"
         (only-in "../aloe/main.rkt" make-top-level-env eval-source)
         "../host/racket/term.rkt")

(define-runtime-path project-root "..")

(test-case "printable a maps to an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\a)) "a"))

(test-case "printable q maps to an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\q)) "q"))

(test-case "return maps to an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'return)) "return"))

(test-case "escape maps to an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'esc)) "escape"))

(test-case "an unknown named key becomes an Aloe String"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'left)) "left"))

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
