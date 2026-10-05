#lang racket/base
(require rackunit (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "plain byte Tab has exactly two accepted decoded shapes"
  (define messages (list (make-tkeymsg #\tab '() #f)
                         (make-tkeymsg #\tab '() #\tab)))
  (for ([i '(1 2)])
    (check-equal? (map tkeymsg->aloe-key messages) '("tab" "tab"))))

(test-case "modified Tab and mismatched controls keep their unsupported path"
  (for* ([mods '((shift) (ctrl) (alt) (meta) (shift ctrl) (ctrl ctrl))]
         [decoded (list #f #\tab #\newline)])
    (check-exn #rx"unsupported key"
      (lambda () (tkeymsg->aloe-key (make-tkeymsg #\tab mods decoded)))))
  (for ([decoded (list #\nul #\newline #\return #\rubout)])
    (check-exn #rx"unsupported key"
      (lambda () (tkeymsg->aloe-key (make-tkeymsg #\tab '() decoded)))))
  ;; Printable decoded data still wins for excluded shapes; no Ctrl-I alias.
  (for ([mods '(() (shift) (ctrl) (alt) (meta))])
    (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\tab mods #\x)) "x"))
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\i '(ctrl) #f)) "i")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\i '(ctrl) #\tab)) "i")
  (check-exn #rx"unsupported key"
    (lambda () (tkeymsg->aloe-key (make-tkeymsg #\nul '() #\tab)))))

(test-case "representative existing conversions stay exact"
  (define messages
    (list (make-tkeymsg 'return) (make-tkeymsg #\newline)
          (make-tkeymsg 'escape) (make-tkeymsg #\u1b)
          (make-tkeymsg 'backspace) (make-tkeymsg #\h '(ctrl) #f)
          (make-tkeymsg 'left) (make-tkeymsg 'up)
          (make-tkeymsg #\x '(ctrl) #f) (make-tkeymsg #\f '(ctrl) #f)
          (make-tkeymsg #\w '(ctrl) #f) (make-tkeymsg #\s '(ctrl) #f)
          (make-tkeymsg #\a) (make-tkeymsg #\space)
          (make-tkeymsg 'decoded '(ctrl) #\λ)))
  (check-equal? (map tkeymsg->aloe-key messages)
    '("return" "return" "escape" "escape" "backspace" "backspace" "left" "up"
      "ctrl-x" "find" "kill" "save" "a" " " "λ"))
  (check-exn exn:fail:contract? (lambda () (tkeymsg->aloe-key "tab"))))
