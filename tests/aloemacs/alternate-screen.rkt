#lang racket/base

;; aloemacs-alternate-screen 000: the runner enters the alternate screen
;; before it turns button tracking on and leaves it after it turns button
;; tracking off. The bytes are terminal setup in the runner only. No TTY is
;; opened here; the proofs read source files.

(require racket/runtime-path racket/file rackunit)

(define-runtime-path runner-path "../../host/racket/aloemacs-run.rkt")
(define-runtime-path term-path "../../host/racket/term.rkt")
(define-runtime-path gel-run-path "../../host/racket/gel-run.rkt")
(define-runtime-path term-run-path "../../host/racket/term-run.rkt")

(define runner (file->string runner-path))

(define (pattern phrase) (regexp (regexp-quote phrase)))
(define (has? source phrase) (regexp-match? (pattern phrase) source))
(define (count source phrase) (length (regexp-match* (pattern phrase) source)))
(define (position source phrase)
  (define found (regexp-match-positions (pattern phrase) source))
  (and found (caar found)))
;; #f when either phrase is missing, so a missing byte fails instead of erroring.
(define (before? source earlier later)
  (define a (position source earlier))
  (define b (position source later))
  (and a b (< a b)))

(define enter "[?1049h")
(define leave "[?1049l")
(define buttons-on "[?1000h")
(define buttons-off "[?1000l")

;; 1. Once each.
(test-case "the runner enters the alternate screen once and leaves it once"
  (check-equal? (count runner enter) 1 enter)
  (check-equal? (count runner leave) 1 leave))

;; 2. The before thunk's order.
(test-case "the alternate screen is entered before button tracking is enabled"
  (check-true (before? runner enter buttons-on)))

;; 3. The after thunk's order.
(test-case "the alternate screen is left after button tracking is disabled"
  (check-true (before? runner buttons-off leave)))

;; 4. Enter, then leave.
(test-case "the enable comes before the disable"
  (check-true (before? runner enter leave)))

;; 5. By hand, and no clear from the runner.
(test-case "the runner calls no tui-term screen procedure and clears nothing"
  (for ([phrase '("term-alternate-screen" "term-normal-screen" "[2J")])
    (check-false (has? runner phrase) phrase)))

;; The Term host, Gel's runner, and the term runner stay out of it.
(test-case "term.rkt, gel-run.rkt, and term-run.rkt contain no 1049"
  (for ([path (list term-path gel-run-path term-run-path)])
    (check-false (has? (file->string path) "1049") (format "1049 in ~a" path))))
