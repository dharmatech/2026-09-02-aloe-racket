#lang racket/base

(require rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "only exact Ctrl-Z messages normalize to undo"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z '(ctrl) #f)) "undo")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z '(ctrl) #\z)) "undo")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z)) "z")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z '(ctrl shift) #f)) "z")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z '(alt) #\z)) "z")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z '(ctrl) #\x)) "x")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\s '(ctrl) #\s)) "save")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\h '(ctrl) #f)) "backspace"))
