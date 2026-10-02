#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")

(define (make-session-state)
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file)
    (hash "/cwd/a.txt" "a\nb")))
  (driver-eval! state `(load ,(path->string file-path)))
  state)

(test-case "unchanged preserves editor and session fields"
  (define state (make-session-state))
  (driver-eval!
   state
   '(define editor
      (AloemacsEditor new
        ((Text from-string "a\nb") indexed-value)
        (Position new 0 1)
        #t
        2
        3
        (List of
          (UndoFrame new
            (Text from-string "old")
            (Position new 0 0)
            4
            5)) (if #t (Option None) (Option Some (Position new 0 0))) 0)))
  (driver-eval!
   state
   '(define session
      (AloemacsSession new
        editor
        (Fs new fs-host)
        (Option Some (Path new "/cwd/a.txt"))
        "prior" #f "" (Position new 0 0) #f #f (List empty)
        (if #t (Option None) (Option Some aloemacs-global-keymap)))))

  (check-not-exn
   (lambda () (driver-eval! state '(check (editor unchanged) editor))))
  (check-not-exn
   (lambda () (driver-eval! state '(check (session unchanged) session))))
  (check-equal? (driver-eval! state '(((editor unchanged) text) to-string))
                "a\nb")
  (check-equal? (driver-eval! state '(((editor unchanged) point) column))
                1)
  (check-equal? (driver-eval! state '((editor unchanged) quit)) #t)
  (check-equal? (driver-eval! state '((editor unchanged) scroll-row)) 2)
  (check-equal? (driver-eval! state '((editor unchanged) scroll-col)) 3)
  (check-equal? (driver-eval! state '(((editor unchanged) history) len)) 1)
  (check-equal? (driver-eval! state '(((session unchanged) path) present?))
                #t)
  (check-equal? (driver-eval! state '((session unchanged) echo))
                "prior"))

(test-case "visit indexes the first line of nonempty and empty text"
  (define state (make-session-state))
  (driver-eval!
   state
   '(define source
      (AloemacsSession new
        (AloemacsEditor new
          (Text from-string "before")
          (Position new 0 0)
          #f
          0
          0
          (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)
        (Fs new fs-host)
        (Option Some (Path new "/cwd/a.txt"))
        "prior" #f "" (Position new 0 0) #f #f (List empty)
        (if #t (Option None) (Option Some aloemacs-global-keymap)))))
  (driver-eval!
   state
   '(define visited
      ((source visit (Path new "a.txt")) case
        (None () source)
        (Some (session) session))))
  (check-equal? (driver-eval! state '((visited text) focus-line)) 0)
  (check-equal? (driver-eval! state '((visited text) current-line)) "a")
  (check-equal? (driver-eval! state '((visited text) to-string)) "a\nb")
  (check-equal? (driver-eval! state '(visited echo)) "")

  (driver-eval!
   state
   '(define empty-visit
      ((source visit (Path new "missing.txt")) case
        (None () source)
        (Some (session) session))))
  (check-equal? (driver-eval! state '((empty-visit text) focus-line)) 0)
  (check-equal? (driver-eval! state '((empty-visit text) current-line)) "")
  (check-equal? (driver-eval! state '((empty-visit text) to-string)) "")
  (check-equal? (driver-eval! state '(empty-visit echo)) ""))
