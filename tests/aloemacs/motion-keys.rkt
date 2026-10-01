#lang racket/base

(require rackunit
         (only-in tui/term/messages make-tkeymsg)
         "../../host/racket/term.rkt")

(test-case "line, page, and buffer keys map to editor commands"
  (for ([key (in-list '(#\a #\e))]
        [expected (in-list '("line-start" "line-end"))])
    (for ([character (in-list (list #f key))])
      (check-equal? (tkeymsg->aloe-key (make-tkeymsg key '(ctrl) character))
                    expected)))
  (for ([entry (in-list '((home () "line-start")
                          (end () "line-end")
                          (home (ctrl) "buffer-start")
                          (end (ctrl) "buffer-end")
                          (prior () "page-up")
                          (next () "page-down")))])
    (check-equal?
     (tkeymsg->aloe-key (make-tkeymsg (car entry) (cadr entry) #f))
     (caddr entry)))
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\a '(ctrl shift) #f)) "a")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg 'home '(shift) #f)) "home")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\a)) "a")
  (check-equal? (tkeymsg->aloe-key (make-tkeymsg #\e)) "e"))
