#lang racket/base

(require rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "exact plain Ctrl-S normalizes to save"
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\s '(ctrl) #f))
   "save"))

(test-case "neighboring s messages retain printable handling"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\s)) "s")
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\s '(ctrl shift) #f))
   "s")
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\s '(alt) #f))
   "s")
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\s '(ctrl) #\s))
   "s"))

(test-case "neighboring printable key remains unchanged"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\q)) "q"))

(test-case "Backspace still precedes printable handling"
  (check-equal?
   (tkeymsg->aloe-key (make-tkeymsg #\h '(ctrl) #f))
   "backspace"))

(test-case "exact Ctrl-S conversion is repeatable"
  (define message (make-tkeymsg #\s '(ctrl) #f))
  (check-equal? (tkeymsg->aloe-key message) "save")
  (check-equal? (tkeymsg->aloe-key message) "save"))
