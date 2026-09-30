#lang racket/base

(require rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "plain Ctrl-F enters search in either decoded shape"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\f '(ctrl) #f)) "find")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\f '(ctrl) #\f)) "find"))

(test-case "other controls and printable or modified F retain their keys"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\s '(ctrl) #f)) "save")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\z '(ctrl) #f)) "undo")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'escape)) "escape")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\f)) "f")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\f '(ctrl shift) #f)) "f")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\f '(alt) #\f)) "f")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\f '(ctrl) #\x)) "x"))
