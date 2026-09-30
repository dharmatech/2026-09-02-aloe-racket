#lang racket/base

(require rackunit
         tui/term/vt-input-port
         tui/term/tqueue
         (only-in tui/term/messages
                  make-tkeymsg tkeymsg-key tkeymsg-mods tkeymsg-char)
         "../../host/racket/term.rkt")

(test-case "plain Ctrl kill chords accept absent or matching decoded characters"
  (for ([key (in-list (list #\w #\y #\k #\space #\`))]
        [command (in-list '("kill" "yank" "kill-line" "mark" "mark"))])
    (for ([character (in-list (list #f key))])
      (check-equal?
       (tkeymsg->aloe-key (make-tkeymsg key '(ctrl) character))
       command))))

(test-case "raw NUL decodes to the Ctrl-backtick form of mark"
  (define decoded
    (read (make-vt-input-port (make-tqueue)
                              (open-input-string "\u0000"))))
  (check-equal? (tkeymsg-key decoded) #\`)
  (check-equal? (tkeymsg-mods decoded) '(ctrl))
  (check-equal? (tkeymsg-char decoded) #\`)
  (check-equal? (tkeymsg->aloe-key decoded) "mark"))

(test-case "plain letters and space remain printable"
  (for ([key (in-list (list #\w #\y #\k #\space))])
    (check-equal? (tkeymsg->aloe-key (make-tkeymsg key))
                  (string key))))

(test-case "neighboring modifiers use the existing printable paths"
  (for ([key (in-list (list #\w #\y #\k #\space))])
    (for ([mods (in-list '((ctrl shift) (alt)))])
      (for ([character (in-list (list #f key))])
        (check-equal?
         (tkeymsg->aloe-key (make-tkeymsg key mods character))
         (string key)))))
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\space '(shift) #f))
   " ")
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\` '(ctrl shift) #f))
   "`"))

(test-case "mismatched decoded characters keep character-first behavior"
  (for ([key (in-list (list #\w #\y #\k #\space #\`))])
    (check-equal?
     (tkeymsg->aloe-key (make-tkeymsg key '(ctrl) #\x))
     "x"))
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\w '(ctrl) #\nul))
   "w"))

(test-case "existing control and special keys retain their commands"
  (for ([key (in-list (list #\s #\f #\z))]
        [command (in-list '("save" "find" "undo"))])
    (for ([character (in-list (list #f key))])
      (check-equal?
       (tkeymsg->aloe-key (make-tkeymsg key '(ctrl) character))
       command)))
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'backspace)) "backspace")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'return)) "return")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'escape)) "escape")
  (check-exn
   #rx"unsupported key"
   (lambda () (tkeymsg->aloe-key (make-tkeymsg #\nul)))))
