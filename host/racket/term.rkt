#lang racket/base

;; Optional prerequisite: raco pkg install tui-term
;;
;; `read-key` must run inside call-with-tty-term-receiver (or an equivalent
;; tui-term with-term extent) on a real TTY. with-term closes the TTY ports on
;; normal return, errors, and breaks, which restores cooked mode.

(require tui/term
         "../../aloe/host.rkt")

(provide tkeymsg->aloe-key
         term-interface
         make-term-receiver
         call-with-tty-term-receiver)

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
    [(return-key? key) "return"]
    [(escape-key? key) "escape"]
    [(and (char? character) (printable-character? character))
     (string character)]
    [(and (char? key) (printable-character? key))
     (string key)]
    [(symbol? key) (symbol->string key)]
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

(struct term-state (output reader))

(define (term-read-key state)
  ((term-state-reader state)))

(define (term-write-line state value)
  (define output (term-state-output state))
  (display value output)
  (display "\r\n" output)
  (flush-output output)
  value)

(define term-interface
  (make-host-interface
   'Term
   (list
    (make-host-method 'read-key '() 'String term-read-key)
    (make-host-method
     'write-line '(String) 'String term-write-line))))

(define (make-term-receiver [output (current-output-port)]
                            [reader read-next-key])
  (make-host-receiver term-interface (term-state output reader)))

(define (call-with-tty-term-receiver procedure)
  (with-term (make-tty-term)
    (procedure (make-term-receiver))))
