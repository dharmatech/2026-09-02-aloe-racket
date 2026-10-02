#lang racket/base

(require rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "plain Ctrl-X accepts absent or matching decoded character"
  (for ([character (in-list '(#f #\x))])
    (define message (make-tkeymsg #\x '(ctrl) character))
    (check-equal? (tkeymsg->aloe-key message) "ctrl-x")
    (check-equal? (tkeymsg->aloe-key message) "ctrl-x")))

(test-case "printable x and neighboring modifiers stay printable"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\x)) "x")
  (for ([mods (in-list '((ctrl shift) (alt)))])
    (for ([character (in-list '(#f #\x))])
      (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\x mods character)) "x"))))

(test-case "mismatched printable decoded character retains character-first behavior"
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\x '(ctrl) #\s)) "s"))

(test-case "existing control motion and special key normalization is retained"
  (for ([key (in-list '(#\s #\f #\z #\w #\y #\k #\space #\` #\a #\e))]
        [expected (in-list '("save" "find" "undo" "kill" "yank" "kill-line"
                              "mark" "mark" "line-start" "line-end"))])
    (for ([character (in-list (list #f key))])
      (check-equal? (tkeymsg->aloe-key (make-tkeymsg key '(ctrl) character)) expected)))
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\h '(ctrl) #f)) "backspace")
  (for ([entry (in-list '((return () "return") (backspace () "backspace")
                          (escape () "escape") (left () "left") (right () "right")
                          (up () "up") (down () "down")
                          (home () "line-start") (end () "line-end")
                          (home (ctrl) "buffer-start") (end (ctrl) "buffer-end")
                          (prior () "page-up") (next () "page-down")))])
    (check-equal? (tkeymsg->aloe-key (make-tkeymsg (car entry) (cadr entry) #f))
                  (caddr entry))))
