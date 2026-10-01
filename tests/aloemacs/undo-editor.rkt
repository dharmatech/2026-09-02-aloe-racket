#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type? type-of type->datum))

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (make-editor-state)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  state)

(define (checked-type state datum)
  (type->datum (type-of (parse-datum datum)
                        (driver-type-environment state))))

(define (focused-text source line)
  `(((Text from-string ,source) focus-at ,line) case
      (None () (Text from-string "unexpected None"))
      (Some (focused) focused)))

(define (editor-expr source line column row col [quit #f])
  `(AloemacsEditor new
     ,(focused-text source line)
     (Position new ,line ,column)
     ,quit ,row ,col (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0))

(define (define-editor! state name source line column row col [quit #f])
  (driver-eval! state
                `(define ,name ,(editor-expr source line column row col quit))))

(define (step! state name source selector . args)
  (driver-eval! state `(define ,name (,source ,selector ,@args))))

(define (equal-aloe state actual expected)
  (check-not-exn
   (lambda () (driver-eval! state `(check ,actual ,expected)))))

(define (check-editor state name source line column row col quit history-len)
  (check-equal? (driver-eval! state `((,name text) to-string)) source)
  (check-equal? (driver-eval! state `((,name point) line)) line)
  (check-equal? (driver-eval! state `((,name point) column)) column)
  (check-equal? (driver-eval! state `(,name scroll-row)) row)
  (check-equal? (driver-eval! state `(,name scroll-col)) col)
  (check-equal? (driver-eval! state `(,name quit)) quit)
  (check-equal? (driver-eval! state `((,name history) len)) history-len))

(test-case "UndoFrame and eight-field editor are checked"
  (define state (make-editor-state))
  (define editor (editor-expr "abc" 0 2 0 0))
  (define frame
    '(UndoFrame new (Text from-string "abc") (Position new 0 2) 0 0))
  (for ([entry (in-list
                `((,frame UndoFrame)
                  ((,frame text) Text)
                  ((,frame point) Position)
                  ((,frame scroll-row) Int)
                  ((,frame scroll-col) Int)
                  (,editor AloemacsEditor)
                  ((,editor history) (List UndoFrame))
                  ((,editor undo) AloemacsEditor)
                  ((,editor handle-key "undo") AloemacsEditor)))])
    (check-equal? (checked-type state (car entry)) (cadr entry)))
  (for ([bad (in-list
              '((AloemacsEditor new (Text from-string "abc")
                   (Position new 0 2) #f 0 0 (if #t (Option None) (Option Some (Position new 0 0))))
                (AloemacsEditor new (Text from-string "abc")
                   (Position new 0 2) #f 0 0 0 (if #t (Option None) (Option Some (Position new 0 0))))
                (UndoFrame new (Text from-string "abc")
                   (Position new 0 2) 0)
                ((AloemacsEditor new (Text from-string "abc")
                   (Position new 0 2) #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0)))) undo 1)))])
    (check-exn exn:fail:aloe-type? (lambda () (driver-eval! state bad)))))

(test-case "each successful edit makes one reversible frame"
  (define state (make-editor-state))
  (for ([entry (in-list
                '((inserted "ab" 0 1 insert ("X") "aXb" 0 2)
                  (newline "ab" 0 1 newline () "a\nb" 1 0)
                  (deleted "ab" 0 2 backward-delete () "a" 0 1)
                  (joined "ab\ncd" 1 0 backward-delete () "abcd" 0 2)))])
    (define name (list-ref entry 0))
    (define source (list-ref entry 1))
    (define line (list-ref entry 2))
    (define column (list-ref entry 3))
    (define command (list-ref entry 4))
    (define args (list-ref entry 5))
    (define edited (string->symbol (format "~a-edit" name)))
    (define undone (string->symbol (format "~a-undo" name)))
    (define-editor! state name source line column 0 0)
    (driver-eval! state `(define ,edited (,name ,command ,@args)))
    (check-editor state edited (list-ref entry 6)
                  (list-ref entry 7) (list-ref entry 8) 0 0 #f 1)
    (equal-aloe state `((,edited history) first)
                `(UndoFrame new (,name text) (,name point) 0 0))
    (step! state undone edited 'undo)
    (check-editor state undone source line column 0 0 #f 0)
    (equal-aloe state undone name)
    (check-editor state name source line column 0 0 #f 0))
  (define-editor! state 'empty "ab" 0 1 0 0)
  (step! state 'empty-insert 'empty 'insert "")
  (check-editor state 'empty-insert "ab" 0 1 0 0 #f 1)
  (step! state 'empty-restored 'empty-insert 'undo)
  (equal-aloe state 'empty-restored 'empty))

(test-case "history is newest first and movement does not become a step"
  (define state (make-editor-state))
  (define-editor! state 'original "ab" 0 1 0 0)
  (step! state 'one 'original 'insert "X")
  (step! state 'two 'one 'insert "Y")
  (step! state 'moved 'two 'move-left)
  (check-editor state 'moved "aXYb" 0 2 0 0 #f 2)
  (step! state 'undo-two 'moved 'handle-key "undo")
  (check-editor state 'undo-two "aXb" 0 2 0 0 #f 1)
  (equal-aloe state 'undo-two 'one)
  (step! state 'undo-one 'undo-two 'undo)
  (equal-aloe state 'undo-one 'original)
  (step! state 'bottom 'undo-one 'undo)
  (equal-aloe state 'bottom 'original)
  (check-editor state 'two "aXYb" 0 3 0 0 #f 2))

(test-case "failures and non-editing transitions keep history"
  (define state (make-editor-state))
  (define-editor! state 'fresh "ab\ncd" 0 0 0 0)
  (step! state 'fresh-undo 'fresh 'undo)
  (equal-aloe state 'fresh-undo 'fresh)
  (step! state 'backspace 'fresh 'backward-delete)
  (equal-aloe state 'backspace 'fresh)
  (define-editor! state 'invalid "ab" 0 4 0 0)
  (step! state 'failed 'invalid 'insert "X")
  (equal-aloe state 'failed 'invalid)
  (step! state 'edited 'fresh 'insert "X")
  (for ([command (in-list '(move-left move-right move-up move-down
                            request-quit))])
    (define result (string->symbol (format "result-~a" command)))
    (step! state result 'edited command)
    (check-equal? (driver-eval! state `((,result history) len)) 1)
    (equal-aloe state `(,result history) '(edited history)))
  (step! state 'fitted 'edited 'ensure-visible 1 1)
  (check-equal? (driver-eval! state '((fitted history) len)) 1)
  (equal-aloe state '(fitted history) '(edited history))
  (step! state 'unknown 'edited 'handle-key "home")
  (equal-aloe state 'unknown 'edited)
  (define rendered (driver-eval! state '(edited frame 5 2)))
  (check-equal? (driver-eval! state '(edited frame 5 2)) rendered)
  (check-editor state 'edited "Xab\ncd" 0 1 0 0 #f 1)
  (step! state 'quit 'edited 'request-quit)
  (step! state 'direct-undo 'quit 'undo)
  (check-editor state 'direct-undo "ab\ncd" 0 0 0 0 #t 0)
  (for ([key (in-list '("undo" "z" "backspace" "return"))])
    (equal-aloe state `(quit handle-key ,key) 'quit)))

(test-case "frame retains focused Text, point, and both origins at edit time"
  (define state (make-editor-state))
  (define-editor! state 'source "abc\nwxyz\npq" 1 3 1 2)
  (step! state 'edited 'source 'insert "!")
  (check-editor state 'edited "abc\nwxy!z\npq" 1 4 1 2 #f 1)
  (equal-aloe state '((edited history) first)
              '(UndoFrame new (source text) (source point) 1 2))
  (check-equal? (driver-eval! state '(((edited history) first) text))
                (driver-eval! state '(source text)))
  (check-equal? (driver-eval! state '(((edited history) first) scroll-row)) 1)
  (check-equal? (driver-eval! state '(((edited history) first) scroll-col)) 2)
  (step! state 'moved 'edited 'move-up)
  (step! state 'fitted 'moved 'ensure-visible 1 1)
  (check-equal? (driver-eval! state '(fitted scroll-row)) 0)
  (step! state 'restored 'fitted 'undo)
  (for ([field (in-list '(text point quit scroll-row scroll-col history mark))])
    (equal-aloe state `(restored ,field) `(source ,field)))
  (check-equal? (driver-eval! state '(restored text-rows)) 1)
  (check-editor state 'source "abc\nwxyz\npq" 1 3 1 2 #f 0)
  (check-equal? (driver-eval! state '((source text) focus-line)) 1)
  (check-equal? (driver-eval! state '((restored text) focus-line)) 1))
