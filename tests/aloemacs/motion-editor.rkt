#lang racket/base

(require racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")

(define (state)
  (define st (make-driver))
  (driver-inject-host! st 'fs-host (make-fs-double "/cwd" (hash "/cwd" 'directory) (hash)))
  (driver-eval! st `(load ,(path->string file-path)))
  st)

(define (editor source line column)
  `(AloemacsEditor new (Text from-string ,source)
                       (Position new ,line ,column) #f 0 0 (List empty)
                       (Option Some (Position new 0 1)) 0))

(define (at st name)
  (list (driver-eval! st `((,name point) line))
        (driver-eval! st `((,name point) column))))

(define (step! st name expr)
  (driver-eval! st `(define ,name ,expr)))

(define (same st left right)
  (check-not-exn (lambda () (driver-eval! st `(check ,left ,right)))))

(define (preserved st before after)
  (check-equal? (driver-eval! st `((,after history) len))
                (driver-eval! st `((,before history) len)))
  (same st `(,after mark) `(,before mark))
  (check-equal? (driver-eval! st `((,after text) to-string))
                (driver-eval! st `((,before text) to-string)))
  (check-equal? (driver-eval! st `(,after scroll-row))
                (driver-eval! st `(,before scroll-row)))
  (check-equal? (driver-eval! st `(,after scroll-col))
                (driver-eval! st `(,before scroll-col))))

(test-case "line and buffer commands move once and preserve non-point state"
  (define st (state))
  (step! st 'base (editor "abc\ndefg\nh" 1 2))
  (step! st 'start '(base handle-key "line-start"))
  (check-equal? (at st 'start) '(1 0))
  (same st '(start handle-key "line-start") 'start)
  (step! st 'end '(start handle-key "line-end"))
  (check-equal? (at st 'end) '(1 4))
  (same st '(end handle-key "line-end") 'end)
  (step! st 'beginning '(end handle-key "buffer-start"))
  (check-equal? (at st 'beginning) '(0 0))
  (same st '(beginning handle-key "buffer-start") 'beginning)
  (step! st 'ending '(beginning handle-key "buffer-end"))
  (check-equal? (at st 'ending) '(2 1))
  (same st '(ending handle-key "buffer-end") 'ending)
  (for ([pair (in-list '((base start) (start end) (end beginning)
                         (beginning ending)))])
    (preserved st (car pair) (cadr pair)))
  (step! st 'empty (editor "" 0 0))
  (same st '(empty handle-key "buffer-start") 'empty)
  (same st '(empty handle-key "buffer-end") 'empty))

(test-case "page distance remembers fitted text rows and clamps only at destination"
  (define st (state))
  (define lines
    (for/list ([i (in-range 31)])
      (cond [(= i 0) "abcdef"]
            [(= i 1) "x"]
            [(= i 23) "uvwxyz"]
            [(= i 30) "xy"]
            [else "abcdef"])))
  (step! st 'base (editor (string-join lines "\n") 0 5))
  (same st '(base handle-key "page-down") 'base)
  (step! st 'fit '(base ensure-visible 80 24))
  (check-equal? (driver-eval! st '(fit text-rows)) 24)
  (step! st 'down '(fit handle-key "page-down"))
  (check-equal? (at st 'down) '(23 5))
  (step! st 'clamped '(down handle-key "page-down"))
  (check-equal? (at st 'clamped) '(30 2))
  (step! st 'up '(down handle-key "page-up"))
  (check-equal? (at st 'up) '(0 5))
  (step! st 'near-top
         `((,(editor (string-join lines "\n") 3 5) ensure-visible 80 24)
           handle-key "page-up"))
  (check-equal? (at st 'near-top) '(0 5))
  (step! st 'one '(base ensure-visible 80 1))
  (step! st 'one-down '(one handle-key "page-down"))
  (check-equal? (at st 'one-down) '(1 1))
  (step! st 'edited '(fit insert "!"))
  (step! st 'undone '(edited undo))
  (check-equal? (driver-eval! st '(undone text-rows)) 24)
  (for ([pair (in-list '((fit down) (down clamped) (down up) (one one-down)))])
    (preserved st (car pair) (cadr pair))))

(test-case "session clears echo, ends search, and ignores motion after quit"
  (define st (state))
  (step! st 'base
         `(AloemacsSession new ,(editor "abc\ndef" 1 2)
                               (Fs new fs-host)
                               (if #t (Option None) (Option Some (Path new "/unused")))
                               "saved" #f ""
                               (Position new 0 0) #f #f (List empty)))
  (step! st 'fit '(base ensure-visible 80 1))
  (step! st 'paged '(fit handle-key "page-down"))
  (check-equal? (driver-eval! st '(paged echo)) "")
  (step! st 'searching '(base handle-key "find"))
  (step! st 'moved '(searching handle-key "line-start"))
  (check-false (driver-eval! st '(moved searching)))
  (check-equal? (driver-eval! st '(moved echo)) "")
  (check-equal? (at st '(moved editor)) '(1 0))
  (step! st 'quit '((base editor) handle-key "escape"))
  (same st '(quit handle-key "line-end") 'quit))
