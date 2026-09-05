#lang racket/base

;; Optional prerequisite: raco pkg install tui-term
;;
;; `read-key` must run inside call-with-tty-term-receiver (or an equivalent
;; tui-term with-term extent) on a real TTY. with-term closes the TTY ports on
;; normal return, errors, and breaks, which restores cooked mode.

(require tui/term
         "../../aloe/host.rkt")

(provide tkeymsg->aloe-key
         make-term-receiver
         call-with-tty-term-receiver)

(define key-name-message
  (host-message
   0
   (lambda (receiver _arguments)
     (host-receiver-state receiver))))

(define (make-key name)
  (host-receiver 'Key
                 (hasheq 'name key-name-message)
                 name))

(define (return-key? key)
  (or (eq? key 'return)
      (eqv? key #\return)
      (eqv? key #\newline)))

(define (escape-key? key)
  (or (eq? key 'escape)
      (eq? key 'esc)
      (eqv? key #\u1b)))

(define (printable-character? character)
  (or (char-graphic? character)
      (char=? character #\space)))

(define (tkeymsg->aloe-key message)
  (unless (tkeymsg? message)
    (raise-argument-error 'tkeymsg->aloe-key "tkeymsg?" message))
  (define key (tkeymsg-key message))
  (define character (tkeymsg-char message))
  (cond
    [(return-key? key) (make-key "return")]
    [(escape-key? key) (make-key "escape")]
    [(and (char? character) (printable-character? character))
     (string character)]
    [(and (char? key) (printable-character? key))
     (string key)]
    [(symbol? key)
     ;; Preserve unknown named keys as data for later Aloe menus.
     (make-key (symbol->string key))]
    [else
     (error 'term "unsupported key: ~s" key)]))

(define (read-next-key)
  (let loop ()
    (define event (read))
    (cond
      [(eof-object? event)
       (error 'term "terminal input closed while reading a key")]
      [(tkeymsg? event)
       (tkeymsg->aloe-key event)]
      [(or (tmousemsg? event) (tsizemsg? event))
       (loop)]
      [else
       (loop)])))

(define read-key-message
  (host-message
   0
   (lambda (_receiver _arguments)
     (read-next-key))))

(define (make-term-receiver)
  (host-receiver 'Term
                 (hasheq 'read-key read-key-message)
                 #f))

(define (call-with-tty-term-receiver procedure)
  (with-term (make-tty-term)
    (procedure (make-term-receiver))))
