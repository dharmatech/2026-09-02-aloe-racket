#lang racket/base

;; Optional prerequisite: raco pkg install tui-term
;;
;; `read-key` must run inside call-with-tty-term-receiver (or an equivalent
;; tui-term with-term extent) on a real TTY. with-term closes the TTY ports on
;; normal return, errors, and breaks, which restores cooked mode.

(require tui/term
         "../../aloe/host.rkt"
         (only-in "../../aloe/main.rkt"
                  make-type-environment
                  typecheck-source))

(provide tkeymsg->aloe-key
         make-term-receiver
         make-term-type-environment
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

(define read-key-message
  (host-message
   0
   (lambda (_receiver _arguments)
     (read-next-key))))

(define write-line-message
  (host-message
   1
   (lambda (receiver arguments)
     (define value (car arguments))
     (unless (string? value)
       (error 'term "Term write-line expects a String argument"))
     (define output (host-receiver-state receiver))
     (display value output)
     (display "\r\n" output)
     (flush-output output)
     value)))

(define (make-term-receiver [output (current-output-port)])
  (host-receiver 'Term
                 (hasheq 'read-key read-key-message
                         'write-line write-line-message)
                 output))

;; The optional terminal runner injects its runtime receiver separately. This
;; private Aloe facade supplies the corresponding checked shape without
;; binding term in Aloe's default environment.
(define (make-term-type-environment)
  (define environment (make-type-environment))
  (typecheck-source
   #<<ALOE
(define-class HostTerm
  (fields)
  (methods
    (read-key () String "")
    (write-line (value String) String value)))
(define term (HostTerm new))
ALOE
   environment)
  environment)

(define (call-with-tty-term-receiver procedure)
  (with-term (make-tty-term)
    (procedure (make-term-receiver))))
