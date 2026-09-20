#lang racket/base

(require rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "Backspace spellings normalize to one Aloe command"
  (for ([message
         (in-list
          (list
           (make-tkeymsg 'backspace)
           (make-tkeymsg #\backspace)
           (make-tkeymsg #\rubout)
           (make-tkeymsg #\h '(ctrl) #f)))])
    (check-equal? (tkeymsg->aloe-key message) "backspace")))

(test-case "control-H matching does not capture other h messages"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\h)) "h")
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\h '(shift) #f))
   "h"))

(test-case "arrows retain their named command strings"
  (for ([key (in-list '(up down left right))]
        [expected (in-list '("up" "down" "left" "right"))])
    (check-equal? (tkeymsg->aloe-key (make-tkeymsg key)) expected))
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg 'left '(ctrl) #f))
   "left"))

(test-case "Return spellings remain normalized"
  (for ([key (in-list (list 'return #\return #\newline))])
    (check-equal? (tkeymsg->aloe-key (make-tkeymsg key)) "return")))

(test-case "Escape spellings remain normalized"
  (for ([key (in-list (list 'escape 'esc #\u1b))])
    (check-equal? (tkeymsg->aloe-key (make-tkeymsg key)) "escape")))

(test-case "printable keys retain key and decoded-character routes"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\a)) "a")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\space)) " ")
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg 'decoded '(ctrl) #\z))
   "z"))

(test-case "unknown named keys remain Aloe strings"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'home)) "home"))

(test-case "unsupported non-printable characters remain errors"
  (check-exn
   #rx"unsupported key"
   (lambda () (tkeymsg->aloe-key (make-tkeymsg #\nul)))))

(test-case "non-key-message arguments retain their contract error"
  (check-exn
   exn:fail:contract?
   (lambda () (tkeymsg->aloe-key 'backspace))))

(test-case "conversion is repeatable without a driver or terminal"
  (define messages
    (list (make-tkeymsg #\rubout)
          (make-tkeymsg 'up)
          (make-tkeymsg #\space)))
  (define expected '("backspace" "up" " "))
  (check-equal? (map tkeymsg->aloe-key messages) expected)
  (check-equal? (map tkeymsg->aloe-key messages) expected))
