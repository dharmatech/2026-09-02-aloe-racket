#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")

(define no-path
  '(if #t (Option None) (Option Some (Path new "/unused"))))

(define (make-state)
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double
    "/cwd"
    (make-hash '(("/cwd" . directory)
                 ("/cwd/old.txt" . file)
                 ("/cwd/dir" . directory)))
    (make-hash '(("/cwd/old.txt" . "a\r\nb\r\n")))))
  (driver-eval! state `(load ,(path->string file-path)))
  state)

(define (define-source! state)
  (driver-eval!
   state
   `(define source
      (AloemacsSession new
        (AloemacsBuffers new
          (List empty)
          (AloemacsBuffer new
            (AloemacsEditor new
              (Text from-string "draft") (Position new 0 0)
              #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)
            ,no-path 0)
          (List empty))
        (Fs new fs-host)
        ""
        #f
        ""
        (Position new 0 0)
        #f
        #f
        (List empty)
        (if #t (Option None) (Option Some aloemacs-global-keymap))
        (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
        (if #t (Option None) (Option Some ""))
        (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (let ((buffer ((AloemacsBuffers new
          (List empty)
          (AloemacsBuffer new
            (AloemacsEditor new
              (Text from-string "draft") (Position new 0 0)
              #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0)
            ,no-path 0)
          (List empty)) current-buffer)))
       (AloemacsWindows new
         (AloemacsWindowTree Leaf
           (AloemacsView new 0 (buffer id)
             ((buffer editor) scroll-row) ((buffer editor) scroll-col) #f (Option None)))
         0 0 0))))))

(define (step! state name expression)
  (driver-eval! state `(define ,name ,expression)))

(define (some! state name expression fallback)
  (step! state name
         `(,expression case
            (None () ,fallback)
            (Some (session) session))))

(define (same state actual expected)
  (check-not-exn
   (lambda () (driver-eval! state `(check ,actual ,expected)))))

(define (history-len state session)
  (driver-eval! state `(((,session editor) history) len)))

(define (text state session)
  (driver-eval! state `((,session text) to-string)))

(define (disk-text state path)
  (driver-eval! state `(fs-host read ,path)))

(test-case "visits start with empty history and rejected visits preserve source"
  (define state (make-state))
  (define-source! state)
  (step! state 'edited '(source insert "!"))
  (check-equal? (history-len state 'edited) 1)
  (some! state 'existing '(edited visit (Path new "old.txt")) 'source)
  (some! state 'missing '(edited visit (Path new "new.txt")) 'source)
  (for ([session (in-list '(existing missing))])
    (check-equal? (history-len state session) 0)
    (check-equal? (driver-eval! state `((,session point) line)) 0)
    (check-equal? (driver-eval! state `((,session point) column)) 0)
    (check-false (driver-eval! state `(,session quit)))
    (check-equal? (driver-eval! state `((,session editor) scroll-row)) 0)
    (check-equal? (driver-eval! state `((,session editor) scroll-col)) 0))
  (check-equal? (text state 'existing) "a\r\nb\r\n")
  (check-equal? (text state 'missing) "")
  (check-false
   (driver-eval! state '((edited visit (Path new "dir")) present?)))
  (same state 'edited '(source insert "!"))
  (check-equal? (history-len state 'edited) 1)
  (check-equal? (text state 'edited) "!draft"))

(test-case "session delegates edits and undo; save keeps history and bound path"
  (define state (make-state))
  (define-source! state)
  (some! state 'visited '(source visit (Path new "old.txt")) 'source)
  (step! state 'direct '(visited insert "X"))
  (step! state 'handled '(direct handle-key "z"))
  (check-equal? (text state 'handled) "Xza\r\nb\r\n")
  (check-equal? (history-len state 'handled) 2)
  (some! state 'saved '(handled save) 'source)
  (check-equal? (history-len state 'saved) 2)
  (check-equal? (disk-text state "/cwd/old.txt") "Xza\r\nb\r\n")
  (step! state 'saved-key '(saved handle-key "save"))
  (for ([field (in-list '(editor fs path))])
    (same state `(saved-key ,field) `(saved ,field)))
  (check-equal? (driver-eval! state '(saved-key echo)) "saved")
  (check-equal? (history-len state 'saved-key) 2)
  ;; A changed backing file makes any accidental write during undo visible.
  (driver-eval! state '(fs-host write "/cwd/old.txt" "external"))
  (step! state 'once '(saved-key handle-key "undo"))
  (check-equal? (text state 'once) "Xa\r\nb\r\n")
  (check-equal? (history-len state 'once) 1)
  (check-equal? (disk-text state "/cwd/old.txt") "external")
  (step! state 'twice '(once handle-key "undo"))
  (check-equal? (text state 'twice) "a\r\nb\r\n")
  (check-equal? (history-len state 'twice) 0)
  (check-equal? (disk-text state "/cwd/old.txt") "external")
  (check-equal?
   (driver-eval! state '((twice path) case
                          (None () "none")
                          (Some (path) (path text))))
   "/cwd/old.txt")
  (step! state 'resaved '(twice handle-key "save"))
  (check-equal? (disk-text state "/cwd/old.txt") "a\r\nb\r\n")
  (check-equal? (history-len state 'resaved) 0)
  (for ([field (in-list '(editor fs path))])
    (same state `(resaved ,field) `(twice ,field)))
  (check-equal? (driver-eval! state '(resaved echo)) "saved")
  (check-equal? (text state 'handled) "Xza\r\nb\r\n"))

(test-case "direct newline and backspace undo; untitled save remains a no-op"
  (define state (make-state))
  (define-source! state)
  (step! state 'newline '(source newline))
  (step! state 'deleted '(newline backward-delete))
  (check-equal? (history-len state 'deleted) 2)
  (step! state 'undone '(deleted handle-key "undo"))
  (same state '(undone editor) '(newline editor))
  (check-equal? (history-len state 'undone) 1)
  (step! state 'untitled-save '(undone handle-key "save"))
  (for ([field (in-list '(editor fs path))])
    (same state `(untitled-save ,field) `(undone ,field)))
  (check-equal? (driver-eval! state '(untitled-save echo)) "failed")
  (check-equal? (history-len state 'untitled-save) 1)
  (step! state 'bottom '(untitled-save handle-key "undo"))
  (same state 'bottom 'source))
