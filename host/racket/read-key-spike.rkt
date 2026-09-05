#lang racket/base

;; Prerequisite: raco pkg install tui-term
;;
;; Finding: make-tty-term installs a VT input port whose custom `read` handler
;; returns decoded tui-term messages, including tkeymsg values. This is not a
;; stream of Racket datums from the terminal, so read-syntax is unsupported.
;; with-term closes the terminal input port on normal return and on exceptions
;; (including breaks); that close restores cooked mode.

(require tui/term)

(define (quit-key? key)
  (or (equal? key #\q)
      (eq? key 'q)))

(define (read-keys)
  (let loop ()
    (define event (read))
    (cond
      [(eof-object? event) (void)]
      [(tkeymsg? event)
       (define key (tkeymsg-key event))
       (printf "key: ~s mods: ~s\n" key (tkeymsg-mods event))
       (flush-output)
       (unless (quit-key? key)
         (loop))]
      [(or (tsizemsg? event) (tmousemsg? event))
       (loop)]
      [else
       (loop)])))

(module+ main
  (with-term (make-tty-term)
    (displayln "Press keys; q quits.")
    (flush-output)
    (read-keys)))
