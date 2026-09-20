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

(define (backspace-key? message)
  (define key (tkeymsg-key message))
  (or (eq? key 'backspace)
      (eqv? key #\backspace)
      (eqv? key #\rubout)
      (and (eqv? key #\h)
           (equal? (tkeymsg-mods message) '(ctrl))
           (not (tkeymsg-char message)))))

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
    [(backspace-key? message) "backspace"]
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

(define fallback-columns 80)
(define fallback-rows 24)

(define (default-size-reader)
  (values fallback-columns fallback-rows))

(struct term-state (output reader size-reader))

(define (term-read-key state)
  ((term-state-reader state)))

(define (term-write-line state value)
  (define output (term-state-output state))
  (display value output)
  (display "\r\n" output)
  (flush-output output)
  value)

(define (term-write state value)
  (define output (term-state-output state))
  (display value output)
  (flush-output output)
  value)

(define (normalized-term-size state)
  (define size-values
    (with-handlers ([exn:fail? (lambda (_exception) #f)])
      (call-with-values (term-state-size-reader state) list)))
  (cond
    [(and size-values
          (= (length size-values) 2)
          (andmap (lambda (value)
                    (and (exact-integer? value) (positive? value)))
                  size-values))
     (apply values size-values)]
    [else
     (values fallback-columns fallback-rows)]))

(define (term-columns state)
  (define-values (columns _rows) (normalized-term-size state))
  columns)

(define (term-rows state)
  (define-values (_columns rows) (normalized-term-size state))
  rows)

(define term-interface
  (make-host-interface
   'Term
   (list
    (make-host-method 'read-key '() 'String term-read-key)
    (make-host-method
     'write-line '(String) 'String term-write-line)
    (make-host-method 'write '(String) 'String term-write)
    (make-host-method 'columns '() 'Int term-columns)
    (make-host-method 'rows '() 'Int term-rows))))

(define (make-term-receiver [output (current-output-port)]
                            [reader read-next-key]
                            [size-reader default-size-reader])
  (make-host-receiver
   term-interface
   (term-state output reader size-reader)))

(define (call-with-tty-term-receiver procedure)
  (with-term (make-tty-term)
    (procedure
     (make-term-receiver
      (current-output-port)
      read-next-key
      current-term-size))))
