#lang racket/base

;; Optional prerequisite: raco pkg install tui-term
;;
;; `read-key` must run inside call-with-tty-term-receiver (or an equivalent
;; tui-term with-term extent) on a real TTY. with-term closes the TTY ports on
;; normal return, errors, and breaks, which restores cooked mode.

(require tui/term
         (only-in tui/term/geometry tpoint? tpoint-x tpoint-y)
         "../../aloe/host.rkt")

(provide tkeymsg->aloe-key
         tmousemsg->aloe-mouse
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

(define (plain-ctrl-s-key? message)
  (and (eqv? (tkeymsg-key message) #\s)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\s))))

(define (plain-ctrl-x-key? message)
  (and (eqv? (tkeymsg-key message) #\x)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\x))))

(define (plain-ctrl-f-key? message)
  (and (eqv? (tkeymsg-key message) #\f)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\f))))

(define (plain-ctrl-z-key? message)
  (and (eqv? (tkeymsg-key message) #\z)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\z))))

(define (plain-ctrl-w-key? message)
  (and (eqv? (tkeymsg-key message) #\w)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\w))))

(define (plain-ctrl-y-key? message)
  (and (eqv? (tkeymsg-key message) #\y)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\y))))

(define (plain-ctrl-k-key? message)
  (and (eqv? (tkeymsg-key message) #\k)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) #\k))))

(define (plain-ctrl-space-key? message)
  (define key (tkeymsg-key message))
  (and (or (eqv? key #\space)
           (eqv? key #\`))
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) key))))

(define (plain-ctrl-letter-key? message letter)
  (and (eqv? (tkeymsg-key message) letter)
       (equal? (tkeymsg-mods message) '(ctrl))
       (or (not (tkeymsg-char message))
           (eqv? (tkeymsg-char message) letter))))

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
    [(plain-ctrl-s-key? message) "save"]
    [(plain-ctrl-x-key? message) "ctrl-x"]
    [(plain-ctrl-f-key? message) "find"]
    [(plain-ctrl-z-key? message) "undo"]
    [(plain-ctrl-w-key? message) "kill"]
    [(plain-ctrl-y-key? message) "yank"]
    [(plain-ctrl-k-key? message) "kill-line"]
    [(plain-ctrl-space-key? message) "mark"]
    [(plain-ctrl-letter-key? message #\a) "line-start"]
    [(plain-ctrl-letter-key? message #\e) "line-end"]
    [(and (eq? key 'home) (equal? (tkeymsg-mods message) '())) "line-start"]
    [(and (eq? key 'end) (equal? (tkeymsg-mods message) '())) "line-end"]
    [(and (eq? key 'home) (equal? (tkeymsg-mods message) '(ctrl))) "buffer-start"]
    [(and (eq? key 'end) (equal? (tkeymsg-mods message) '(ctrl))) "buffer-end"]
    [(and (eq? key 'prior) (equal? (tkeymsg-mods message) '())) "page-up"]
    [(and (eq? key 'next) (equal? (tkeymsg-mods message) '())) "page-down"]
    [(and (eqv? key #\tab)
          (equal? (tkeymsg-mods message) '())
          (or (not character) (eqv? character #\tab)))
     "tab"]
    [(and (char? character) (printable-character? character))
     (string character)]
    [(and (char? key) (printable-character? key))
     (string key)]
    [(symbol? key) (symbol->string key)]
    [else
     (error 'term "unsupported key: ~s" key)]))

;; The mouse strings: `mouse <down|up> <left|middle|right> <column> <row>`
;; and `mouse move <column> <row>`. One space between fields, canonical
;; decimals, and nothing else.
(define mouse-event-pattern
  #rx"^mouse ((down|up) (left|middle|right)|move) (0|[1-9][0-9]*) (0|[1-9][0-9]*)$")

(define (mouse-event-string? value)
  (and (string? value) (regexp-match? mouse-event-pattern value)))

;; A button press or release with a left, middle, or right button at a
;; non-negative position formats as the press string. Motion with a button
;; held, kind move, formats as the move string; its held flags and its
;; button field are not read. Anything else is #f. tui-term already made
;; the coordinates 0-based; do not subtract again.
(define (tmousemsg->aloe-mouse message)
  (and (tmousemsg? message)
       (let ([position (tmousemsg-pos message)])
         (and (tpoint? position)
              (exact-nonnegative-integer? (tpoint-x position))
              (exact-nonnegative-integer? (tpoint-y position))
              (let ([coordinates (string-append (number->string (tpoint-x position))
                                                " "
                                                (number->string (tpoint-y position)))])
                (case (tmousemsg-kind message)
                  [(move) (string-append "mouse move " coordinates)]
                  [(button-down button-up)
                   (and (memq (tmousemsg-button message) '(left middle right))
                        (string-append
                         "mouse "
                         (if (eq? (tmousemsg-kind message) 'button-down) "down" "up")
                         " "
                         (symbol->string (tmousemsg-button message))
                         " "
                         coordinates))]
                  [else #f]))))))

(define (read-next-key)
  (let loop ()
    (define event (read))
    (cond
      [(eof-object? event)
       (error 'term "terminal input closed while reading a key")]
      [(tkeymsg? event)
       (tkeymsg->aloe-key event)]
      [(tmousemsg? event)
       (let ([mouse (tmousemsg->aloe-mouse event)])
         (if mouse mouse (loop)))]
      [(tsizemsg? event)
       (loop)]
      [else
       (loop)])))

(define fallback-columns 80)
(define fallback-rows 24)

(define (default-size-reader)
  (values fallback-columns fallback-rows))

(struct term-state (output reader size-reader))

;; read-event returns whatever the reader yields: a key string or a mouse string.
(define (term-read-event state)
  ((term-state-reader state)))

;; read-key skips mouse strings. A non-string result is returned as it is, so
;; the host boundary still reports it.
(define (term-read-key state)
  (let loop ()
    (define result ((term-state-reader state)))
    (if (mouse-event-string? result)
        (loop)
        result)))

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
    (make-host-method 'rows '() 'Int term-rows)
    (make-host-method 'read-event '() 'String term-read-event))))

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
