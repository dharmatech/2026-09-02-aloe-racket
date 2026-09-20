#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum))

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (bound-in-driver? state name)
  (and (env-bound? (driver-runtime-environment state) name)
       (type-environment-bound? (driver-type-environment state) name)))

(define (unbound-in-driver? state name)
  (and (not (env-bound? (driver-runtime-environment state) name))
       (not (type-environment-bound? (driver-type-environment state) name))))

(define (load-editor! state)
  (driver-eval! state `(load ,(path->string editor-path))))

(define (editor-expression source line column quit)
  `(AloemacsEditor new
     (Text from-string ,source)
     (Position new ,line ,column)
     ,quit))

(define (define-editor! state name source line column quit)
  (driver-eval!
   state
   `(define ,name ,(editor-expression source line column quit))))

(define (check-editor state expression source line column quit)
  (check-equal?
   (driver-eval! state `((,expression text) to-string))
   source
   (format "text of ~s" expression))
  (check-equal?
   (driver-eval! state `((,expression point) line))
   line
   (format "line of ~s" expression))
  (check-equal?
   (driver-eval! state `((,expression point) column))
   column
   (format "column of ~s" expression))
  (check-equal?
   (driver-eval! state `(,expression quit))
   quit
   (format "quit of ~s" expression)))

(define (check-valid-editor state expression)
  (check-true
   (driver-eval!
    state
    `((,expression text) valid-position? (,expression point)))
   (format "valid point of ~s" expression)))

(define (check-structurally-equal state actual expected)
  (check-not-exn
   (lambda () (driver-eval! state `(check ,actual ,expected)))
   (format "structural equality of ~s and ~s" actual expected)))

(define (check-source-editor state name source line column quit)
  (check-editor state name source line column quit)
  (check-valid-editor state name))

(test-case "editor loading is explicit, source-relative, and driver-local"
  (define state (make-driver))
  (for ([name (in-list '(AloemacsEditor Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? state name)))

  (check-true (void? (load-editor! state)))
  (for ([name (in-list '(AloemacsEditor Option Position Span Text EditResult))])
    (check-true (bound-in-driver? state name)))

  (define fresh-state (make-driver))
  (for ([name (in-list '(AloemacsEditor Option Position Span Text EditResult))])
    (check-true (unbound-in-driver? fresh-state name)))
  (check-exn #rx"unbound symbol: AloemacsEditor"
             (lambda () (driver-eval! fresh-state 'AloemacsEditor))))

(test-case "AloemacsEditor has the exact three-field construction surface"
  (define state (make-driver))
  (load-editor! state)
  (define editor (editor-expression "abc" 0 2 #f))
  (for ([entry
         (in-list
          `((,editor AloemacsEditor)
            ((,editor text) Text)
            ((,editor point) Position)
            ((,editor quit) Bool)))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum
         (in-list
          `((AloemacsEditor new)
            (AloemacsEditor new (Text from-string "abc"))
            (AloemacsEditor new
              (Text from-string "abc")
              (Position new 0 2))
            (AloemacsEditor new
              (Text from-string "abc")
              (Position new 0 2)
              #f
              "fourth")
            (AloemacsEditor new "abc" (Position new 0 2) #f)
            (AloemacsEditor new (Text from-string "abc") 2 #f)
            (AloemacsEditor new
              (Text from-string "abc")
              (Position new 0 2)
              0)
            (AloemacsEditor from-string
              (Text from-string "abc")
              (Position new 0 2)
              #f)
            (,editor path)
            (,editor dirty)
            (,editor selection)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))

(test-case "all editor commands have exact checked signatures"
  (define state (make-driver))
  (load-editor! state)
  (define editor (editor-expression "ab\ncd" 1 1 #f))
  (for ([datum
         (in-list
          `((,editor insert "x")
            (,editor newline)
            (,editor backward-delete)
            (,editor move-left)
            (,editor move-right)
            (,editor move-up)
            (,editor move-down)
            (,editor request-quit)
            (,editor handle-key "left")))])
    (check-equal? (driver-type state datum) 'AloemacsEditor))

  (check-equal? (driver-type state `(,editor frame 8 4)) 'String)

  (for ([datum
         (in-list
          `((,editor insert)
            (,editor insert 1)
            (,editor insert "x" "y")
            (,editor newline 1)
            (,editor backward-delete 1)
            (,editor move-left 1)
            (,editor move-right 1)
            (,editor move-up 1)
            (,editor move-down 1)
            (,editor request-quit 1)
            (,editor handle-key)
            (,editor handle-key 1)
            (,editor handle-key "left" "right")
            (,editor frame)
            (,editor frame 8)
            (,editor frame 8 4 2)
            (,editor frame "8" 4)
            (,editor frame 8 #t)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))

(test-case "insert and newline rebuild only from Text edit results"
  (define state (make-driver))
  (load-editor! state)

  (define-editor! state 'insert-source "" 0 0 #f)
  (driver-eval! state '(define insert-result (insert-source insert "x")))
  (check-editor state 'insert-result "x" 0 1 #f)
  (check-valid-editor state 'insert-result)
  (check-source-editor state 'insert-source "" 0 0 #f)

  (define-editor! state 'newline-source "a" 0 1 #f)
  (driver-eval! state '(define newline-result (newline-source newline)))
  (check-editor state 'newline-result "a\n" 1 0 #f)
  (check-valid-editor state 'newline-result)
  (check-source-editor state 'newline-source "a" 0 1 #f)

  (define-editor! state 'quit-edit-source "a" 0 1 #t)
  (driver-eval! state '(define quit-edit-result
                         (quit-edit-source insert "x")))
  (check-editor state 'quit-edit-result "ax" 0 2 #t)
  (check-valid-editor state 'quit-edit-result)
  (check-source-editor state 'quit-edit-source "a" 0 1 #t))

(test-case "backward-delete removes characters and LF separators through Text"
  (define state (make-driver))
  (load-editor! state)

  (define-editor! state 'character-source "ab" 0 2 #f)
  (driver-eval! state '(define character-result
                         (character-source backward-delete)))
  (check-editor state 'character-result "a" 0 1 #f)
  (check-valid-editor state 'character-result)
  (check-source-editor state 'character-source "ab" 0 2 #f)

  (define-editor! state 'join-source "ab\ncd" 1 0 #f)
  (driver-eval! state '(define join-result (join-source backward-delete)))
  (check-editor state 'join-result "abcd" 0 2 #f)
  (check-valid-editor state 'join-result)
  (check-source-editor state 'join-source "ab\ncd" 1 0 #f)

  (define-editor! state 'beginning-source "ab\ncd" 0 0 #f)
  (driver-eval! state '(define beginning-result
                         (beginning-source backward-delete)))
  (check-editor state 'beginning-result "ab\ncd" 0 0 #f)
  (check-valid-editor state 'beginning-result)
  (check-structurally-equal state 'beginning-result 'beginning-source)
  (check-source-editor state 'beginning-source "ab\ncd" 0 0 #f))

(test-case "a failed Text insertion exhausts None and preserves invalid payloads"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'invalid-source "abc" 0 4 #f)
  (driver-eval! state '(define invalid-result (invalid-source insert "x")))
  (check-editor state 'invalid-result "abc" 0 4 #f)
  (check-structurally-equal state 'invalid-result 'invalid-source)
  (check-editor state 'invalid-source "abc" 0 4 #f))

(test-case "horizontal movement steps, crosses LF, and stops at both edges"
  (define state (make-driver))
  (load-editor! state)

  (define-editor! state 'left-step-source "ab\ncd" 1 2 #f)
  (driver-eval! state '(define left-step-result (left-step-source move-left)))
  (check-editor state 'left-step-result "ab\ncd" 1 1 #f)
  (check-valid-editor state 'left-step-result)
  (check-source-editor state 'left-step-source "ab\ncd" 1 2 #f)

  (define-editor! state 'right-step-source "ab\ncd" 0 0 #t)
  (driver-eval! state '(define right-step-result
                         (right-step-source move-right)))
  (check-editor state 'right-step-result "ab\ncd" 0 1 #t)
  (check-valid-editor state 'right-step-result)
  (check-source-editor state 'right-step-source "ab\ncd" 0 0 #t)

  (define-editor! state 'left-cross-source "ab\ncd" 1 0 #f)
  (driver-eval! state '(define left-cross-result
                         (left-cross-source move-left)))
  (check-editor state 'left-cross-result "ab\ncd" 0 2 #f)
  (check-valid-editor state 'left-cross-result)
  (check-source-editor state 'left-cross-source "ab\ncd" 1 0 #f)

  (define-editor! state 'right-cross-source "ab\ncd" 0 2 #f)
  (driver-eval! state '(define right-cross-result
                         (right-cross-source move-right)))
  (check-editor state 'right-cross-result "ab\ncd" 1 0 #f)
  (check-valid-editor state 'right-cross-result)
  (check-source-editor state 'right-cross-source "ab\ncd" 0 2 #f)

  (define-editor! state 'left-edge-source "ab\ncd" 0 0 #f)
  (driver-eval! state '(define left-edge-result
                         (left-edge-source move-left)))
  (check-editor state 'left-edge-result "ab\ncd" 0 0 #f)
  (check-valid-editor state 'left-edge-result)
  (check-structurally-equal state 'left-edge-result 'left-edge-source)
  (check-source-editor state 'left-edge-source "ab\ncd" 0 0 #f)

  (define-editor! state 'right-edge-source "ab\ncd" 1 2 #f)
  (driver-eval! state '(define right-edge-result
                         (right-edge-source move-right)))
  (check-editor state 'right-edge-result "ab\ncd" 1 2 #f)
  (check-valid-editor state 'right-edge-result)
  (check-structurally-equal state 'right-edge-result 'right-edge-source)
  (check-source-editor state 'right-edge-source "ab\ncd" 1 2 #f))

(test-case "vertical movement fits, clamps, stops, and forgets old columns"
  (define state (make-driver))
  (load-editor! state)

  (define-editor! state 'up-fit-source "abcd\nxyz\nuv" 2 1 #f)
  (driver-eval! state '(define up-fit-result (up-fit-source move-up)))
  (check-editor state 'up-fit-result "abcd\nxyz\nuv" 1 1 #f)
  (check-valid-editor state 'up-fit-result)
  (check-source-editor state 'up-fit-source "abcd\nxyz\nuv" 2 1 #f)

  (define-editor! state 'down-fit-source "abcd\nxyz\nuv" 0 2 #t)
  (driver-eval! state '(define down-fit-result (down-fit-source move-down)))
  (check-editor state 'down-fit-result "abcd\nxyz\nuv" 1 2 #t)
  (check-valid-editor state 'down-fit-result)
  (check-source-editor state 'down-fit-source "abcd\nxyz\nuv" 0 2 #t)

  (define-editor! state 'down-clamp-source "abcd\nx\nwxyz" 0 4 #f)
  (driver-eval! state '(define down-clamp-one
                         (down-clamp-source move-down)))
  (driver-eval! state '(define down-clamp-two (down-clamp-one move-down)))
  (check-editor state 'down-clamp-one "abcd\nx\nwxyz" 1 1 #f)
  (check-editor state 'down-clamp-two "abcd\nx\nwxyz" 2 1 #f)
  (check-valid-editor state 'down-clamp-one)
  (check-valid-editor state 'down-clamp-two)
  (check-source-editor state 'down-clamp-source "abcd\nx\nwxyz" 0 4 #f)

  (define-editor! state 'up-clamp-source "abcd\nx\nwxyz" 2 4 #f)
  (driver-eval! state '(define up-clamp-one (up-clamp-source move-up)))
  (driver-eval! state '(define up-clamp-two (up-clamp-one move-up)))
  (check-editor state 'up-clamp-one "abcd\nx\nwxyz" 1 1 #f)
  (check-editor state 'up-clamp-two "abcd\nx\nwxyz" 0 1 #f)
  (check-valid-editor state 'up-clamp-one)
  (check-valid-editor state 'up-clamp-two)
  (check-source-editor state 'up-clamp-source "abcd\nx\nwxyz" 2 4 #f)

  (define-editor! state 'up-edge-source "abcd\nx" 0 3 #f)
  (driver-eval! state '(define up-edge-result (up-edge-source move-up)))
  (check-editor state 'up-edge-result "abcd\nx" 0 3 #f)
  (check-valid-editor state 'up-edge-result)
  (check-structurally-equal state 'up-edge-result 'up-edge-source)
  (check-source-editor state 'up-edge-source "abcd\nx" 0 3 #f)

  (define-editor! state 'down-edge-source "abcd\nx" 1 1 #f)
  (driver-eval! state '(define down-edge-result (down-edge-source move-down)))
  (check-editor state 'down-edge-result "abcd\nx" 1 1 #f)
  (check-valid-editor state 'down-edge-result)
  (check-structurally-equal state 'down-edge-result 'down-edge-source)
  (check-source-editor state 'down-edge-source "abcd\nx" 1 1 #f))

(test-case "request-quit preserves payloads and constructs an absorbing fact"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'quit-source "ab\ncd" 1 1 #f)
  (driver-eval! state '(define quit-result (quit-source request-quit)))
  (check-editor state 'quit-result "ab\ncd" 1 1 #t)
  (check-valid-editor state 'quit-result)
  (check-source-editor state 'quit-source "ab\ncd" 1 1 #f)

  (driver-eval! state '(define requit-result (quit-result request-quit)))
  (check-editor state 'requit-result "ab\ncd" 1 1 #t)
  (check-valid-editor state 'requit-result)
  (check-structurally-equal state 'requit-result 'quit-result)
  (check-editor state 'quit-result "ab\ncd" 1 1 #t))

(test-case "handle-key dispatches every named key before printable fallback"
  (define state (make-driver))
  (load-editor! state)

  (for ([entry
         (in-list
          (list
           (list 'key-return "a" 0 1 "return" 'newline)
           (list 'key-backspace "ab" 0 2 "backspace" 'backward-delete)
           (list 'key-left "ab\ncd" 1 1 "left" 'move-left)
           (list 'key-right "ab\ncd" 0 1 "right" 'move-right)
           (list 'key-up "ab\ncd" 1 1 "up" 'move-up)
           (list 'key-down "ab\ncd" 0 1 "down" 'move-down)
           (list 'key-escape "ab\ncd" 1 1 "escape" 'request-quit)))])
    (define name (list-ref entry 0))
    (define result-name (string->symbol (format "~a-result" name)))
    (define source (list-ref entry 1))
    (define line (list-ref entry 2))
    (define column (list-ref entry 3))
    (define key (list-ref entry 4))
    (define command (list-ref entry 5))
    (define-editor! state name source line column #f)
    (driver-eval! state `(define ,result-name (,name handle-key ,key)))
    (check-structurally-equal state result-name `(,name ,command))
    (check-valid-editor state result-name)
    (check-source-editor state name source line column #f)))

(test-case "handle-key inserts one-character strings including q"
  (define state (make-driver))
  (load-editor! state)
  (for ([entry (in-list '((printable-source "x") (q-source "q")))])
    (define name (car entry))
    (define key (cadr entry))
    (define result-name (string->symbol (format "~a-result" name)))
    (define-editor! state name "ab" 0 1 #f)
    (driver-eval! state `(define ,result-name (,name handle-key ,key)))
    (check-structurally-equal state result-name `(,name insert ,key))
    (check-editor state result-name (string-append "a" key "b") 0 2 #f)
    (check-valid-editor state result-name)
    (check-source-editor state name "ab" 0 1 #f)))

(test-case "unknown empty, named, and multi-character keys are equal no-ops"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'unknown-source "ab\ncd" 1 1 #f)
  (for ([entry (in-list '((empty-key-result "")
                          (home-key-result "home")
                          (delete-key-result "delete")
                          (multi-key-result "xy")))])
    (define result-name (car entry))
    (define key (cadr entry))
    (driver-eval!
     state
     `(define ,result-name (unknown-source handle-key ,key)))
    (check-editor state result-name "ab\ncd" 1 1 #f)
    (check-valid-editor state result-name)
    (check-structurally-equal state result-name 'unknown-source))
  (check-source-editor state 'unknown-source "ab\ncd" 1 1 #f))

(test-case "handle-key is absorbing after escape for every transition category"
  (define state (make-driver))
  (load-editor! state)
  (define-editor! state 'absorbing-source "ab\ncd" 1 1 #f)
  (driver-eval! state '(define absorbing-quit
                         (absorbing-source handle-key "escape")))
  (check-editor state 'absorbing-quit "ab\ncd" 1 1 #t)
  (check-valid-editor state 'absorbing-quit)

  (for ([entry (in-list '((absorbed-printable "x")
                          (absorbed-movement "left")
                          (absorbed-return "return")
                          (absorbed-backspace "backspace")))])
    (define result-name (car entry))
    (define key (cadr entry))
    (driver-eval! state `(define ,result-name
                           (absorbing-quit handle-key ,key)))
    (check-editor state result-name "ab\ncd" 1 1 #t)
    (check-valid-editor state result-name)
    (check-structurally-equal state result-name 'absorbing-quit))
  (check-editor state 'absorbing-quit "ab\ncd" 1 1 #t)
  (check-source-editor state 'absorbing-source "ab\ncd" 1 1 #f))
