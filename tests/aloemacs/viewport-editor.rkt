#lang racket/base

(require racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-of
                  type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (editor-expression source line column quit scroll-row scroll-col)
  `(AloemacsEditor new
     (Text from-string ,source)
     (Position new ,line ,column)
     ,quit
     ,scroll-row
     ,scroll-col
     (List empty) (if #t (Option None) (Option Some (Position new 0 0))) 0))

(define (define-editor! state name source line column quit scroll-row scroll-col)
  (driver-eval!
   state
   `(define ,name
      ,(editor-expression source line column quit scroll-row scroll-col))))

(define (step-and-fit! state name source key columns rows)
  (driver-eval!
   state
   `(define ,name
      ((,source handle-key ,key) ensure-visible ,columns ,rows))))

(define (complete-frame body row column)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H"
   body
   (format "\u001b[~a;~aH\u001b[?25h" row column)))

(define (check-origin state editor row column)
  (check-equal? (driver-eval! state `(,editor scroll-row)) row)
  (check-equal? (driver-eval! state `(,editor scroll-col)) column))

(define (check-same state actual expected)
  (check-not-exn
   (lambda () (driver-eval! state `(check ,actual ,expected)))
   (format "same payload: ~s and ~s" actual expected)))

(define (make-file-state)
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file)
    (hash "/cwd/a.txt" "first\nsecond")))
  (driver-eval! state `(load ,(path->string file-path)))
  state)

(define no-path
  '(if #t (Option None) (Option Some (Path new "/unused"))))

(define (session-expression editor path)
  `(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         ,editor
         ,(if path `(Option Some (Path new ,path)) no-path))
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
     (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
     (if #t (Option None) (Option Some ""))
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))))

(define (define-from-option! state name expression fallback)
  (driver-eval!
   state
   `(define ,name
      (,expression case
        (None () ,fallback)
        (Some (session) session)))))

(test-case "checked editor and session surfaces have exact fields and fit types"
  (define state (make-file-state))
  (define editor (editor-expression "abc" 0 2 #f 1 3))
  (define session (session-expression editor #f))
  (for ([entry
         (in-list
          `((,editor AloemacsEditor)
            ((,editor scroll-row) Int)
            ((,editor scroll-col) Int)
            ((,editor ensure-visible 4 2) AloemacsEditor)
            (,session (AloemacsSession FsHost))
            ((,session editor) AloemacsEditor)
            ((,session fs) (Fs FsHost))
            ((,session path) (Option Path))
            ((,session echo) String)
            ((,session ensure-visible 4 2) (AloemacsSession FsHost))))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))
  (for ([datum
         (in-list
          `((AloemacsEditor new (Text from-string "abc")
              (Position new 0 2) #f (if #t (Option None) (Option Some (Position new 0 0))))
            (AloemacsEditor new (Text from-string "abc")
              (Position new 0 2) #f 0 (if #t (Option None) (Option Some (Position new 0 0))))
            (AloemacsEditor new (Text from-string "abc")
              (Position new 0 2) #f 0 0 0 (if #t (Option None) (Option Some (Position new 0 0))))
            (AloemacsEditor new (Text from-string "abc")
              (Position new 0 2) #f "row" 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))))
            (AloemacsEditor new (Text from-string "abc")
              (Position new 0 2) #f 0 "column" (List empty) (if #t (Option None) (Option Some (Position new 0 0))))
            (,editor ensure-visible)
            (,editor ensure-visible 4)
            (,editor ensure-visible 4 2 1)
            (,editor ensure-visible "4" 2)
            (,editor ensure-visible 4 #t)
            (,session ensure-visible 4)
            (,session ensure-visible #t 2)
            (,session scroll-row)
            (,session scroll-col)
            (AloemacsSession new ,editor (Fs new fs-host) (List empty))
            (AloemacsSession new
              (AloemacsBuffers new
                (List empty)
                (AloemacsBuffer new
                  ,editor
                  "path")
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
              (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
              (if #t (Option None) (Option Some ""))
              (if #t (Option None) (Option Some (AloemacsCommand FindFile))))
            (AloemacsSession new
              (AloemacsBuffers new
                (List empty)
                (AloemacsBuffer new
                  ,editor
                  ,no-path)
                (List empty))
              (Fs new fs-host)
              0
              #f
              ""
              (Position new 0 0)
              #f
              #f
              (List empty)
              (if #t (Option None) (Option Some aloemacs-global-keymap))
              (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
              (if #t (Option None) (Option Some ""))
              (if #t (Option None) (Option Some (AloemacsCommand FindFile))))))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum)))))

(test-case "initial and visited editors reset origin; session fit forwards payloads"
  (define state (make-driver))
  (driver-inject-host!
   state 'fs-host
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory "/cwd/a.txt" 'file)
    (hash "/cwd/a.txt" "first\nsecond")))
  (check-equal? (driver-load-file! state main-path) '())
  (check-origin state '(aloemacs-editor editor) 0 0)
  (define-editor! state 'scrolled "first\nsecond" 1 4 #f 5 6)
  (driver-eval! state
                `(define base ,(session-expression 'scrolled #f)))
  (driver-eval! state '(define fitted (base ensure-visible 3 1)))
  (check-origin state '(fitted editor) 1 4)
  (check-origin state '(base editor) 5 6)
  (check-same state '(fitted fs) '(base fs))
  (check-same state '(fitted path) '(base path))
  (check-same state '((fitted editor) text) '((base editor) text))
  (check-same state '((fitted editor) point) '((base editor) point))
  (check-equal? (driver-eval! state '((fitted editor) quit)) #f)
  (check-origin state 'scrolled 5 6)

  (define-from-option! state 'existing
    '(base visit (Path new "a.txt")) 'base)
  (define-from-option! state 'missing
    '(base visit (Path new "new.txt")) 'base)
  (for ([name (in-list '(existing missing))])
    (check-origin state `(,name editor) 0 0)
    (check-equal? (driver-eval! state `((,name point) line)) 0)
    (check-equal? (driver-eval! state `((,name point) column)) 0)
    (check-false (driver-eval! state `(,name quit)))
    (check-same state `(,name fs) '(base fs)))
  (check-equal? (driver-eval! state '((existing text) to-string))
                "first\nsecond")
  (check-equal? (driver-eval! state '((missing text) to-string)) "")
  (check-origin state '(base editor) 5 6))

(test-case "all editor transitions carry origin even when point exits the window"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define-editor! state 'source "abcd\nwxyz\npqrs" 1 2 #f 1 2)
  (for ([entry
         (in-list
          '((inserted (source insert "Q") 1 3)
            (newlined (source newline) 2 0)
            (deleted (source backward-delete) 1 1)
            (leftward (source move-left) 1 1)
            (rightward (source move-right) 1 3)
            (upward (source move-up) 0 2)
            (downward (source move-down) 2 2)
            (quitting (source request-quit) 1 2)
            (unknown (source handle-key "home") 1 2)))])
    (define name (car entry))
    (driver-eval! state `(define ,name ,(cadr entry)))
    (check-origin state name 1 2)
    (check-equal? (driver-eval! state `((,name point) line)) (caddr entry))
    (check-equal? (driver-eval! state `((,name point) column))
                  (cadddr entry)))
  (check-origin state 'source 1 2)
  (check-same state '(source text) '(unknown text))
  (check-same state '(source point) '(unknown point))
  (check-false (driver-eval! state '(source quit)))
  (check-true (driver-eval! state '(quitting quit)))
  (driver-eval! state '(define post-quit (quitting handle-key "x")))
  (check-origin state 'post-quit 1 2)
  (check-same state 'post-quit 'quitting)
  (define-editor! state 'invalid "abc" 0 4 #f 2 3)
  (driver-eval! state '(define failed (invalid insert "x")))
  (check-origin state 'failed 2 3)
  (check-same state 'failed 'invalid)
  (define-editor! state 'edge "abc" 0 0 #f 2 3)
  (driver-eval! state '(define at-edge (edge move-left)))
  (check-origin state 'at-edge 2 3)
  (check-same state 'at-edge 'edge))

(test-case "session edit and save paths preserve the nested origin"
  (define state (make-file-state))
  (define-editor! state 'editor "first\nsecond" 1 2 #f 1 2)
  (driver-eval! state
                `(define base ,(session-expression 'editor "/cwd/a.txt")))
  (driver-eval! state '(define edited (base insert "!")))
  (check-origin state '(edited editor) 1 2)
  (define-from-option! state 'saved '(edited save) 'base)
  (check-origin state '(saved editor) 1 2)
  (check-same state '(saved editor) '(edited editor))
  (check-same state '(saved fs) '(edited fs))
  (check-same state '(saved path) '(edited path))
  (check-equal? (driver-eval! state '(fs-host read "/cwd/a.txt"))
                "first\nse!cond")
  (driver-eval! state
                `(define untitled ,(session-expression 'editor #f)))
  (driver-eval! state '(define no-save (untitled handle-key "save")))
  (check-origin state '(no-save editor) 1 2)
  (for ([field (in-list '(editor fs path))])
    (check-same state `(no-save ,field) `(untitled ,field)))
  (check-equal? (driver-eval! state '(no-save echo)) "failed")
  (check-equal?
   (driver-eval! state
                 '((untitled save) case
                     (None () "none")
                     (Some (session) "some")))
   "none"))

(test-case "fit keeps each axis independently in a half-open window"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define source (string-join (make-list 12 "abcdefghijklmnop") "\n"))
  ;; line, column, old row, old column, columns, rows, new row, new column
  (for ([case
         (in-list
          '((4 5 2 3 5 4 2 3)
            (6 5 2 3 5 4 3 3)
            (1 5 2 3 5 4 1 3)
            (4 2 2 3 5 4 2 2)
            (4 8 2 3 5 4 2 4)
            (10 14 2 3 5 4 7 10)
            (2 1 8 12 5 4 2 1)
            (0 0 -3 -4 5 4 0 0)
            (4 5 4 5 1 1 4 5)
            (6 8 4 5 1 1 6 8)
            (2 1 4 5 1 1 2 1)))]
        [index (in-naturals)])
    (define name (string->symbol (format "editor-~a" index)))
    (define line (list-ref case 0))
    (define column (list-ref case 1))
    (define old-row (list-ref case 2))
    (define old-col (list-ref case 3))
    (define columns (list-ref case 4))
    (define rows (list-ref case 5))
    (define new-row (list-ref case 6))
    (define new-col (list-ref case 7))
    (define-editor! state name source line column #f old-row old-col)
    (define fitted (string->symbol (format "~a-fitted" name)))
    (define twice (string->symbol (format "~a-twice" name)))
    (driver-eval! state
                  `(define ,fitted (,name ensure-visible ,columns ,rows)))
    (driver-eval! state
                  `(define ,twice (,fitted ensure-visible ,columns ,rows)))
    (check-origin state name old-row old-col)
    (check-origin state fitted new-row new-col)
    (check-origin state twice new-row new-col)
    (check-same state fitted twice)
    (check-same state `(,fitted text) `(,name text))
    (check-same state `(,fitted point) `(,name point))
    (check-equal? (driver-eval! state `(,fitted quit)) #f)))

(test-case "Down and Up move within a held vertical frame before crossing its edge"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define source "zero\none\ntwo\nthree\nfour\nfive")
  (define-editor! state 'initial source 0 0 #f 0 0)
  (step-and-fit! state 'down-1 'initial "down" 8 4)
  (step-and-fit! state 'down-2 'down-1 "down" 8 4)
  (step-and-fit! state 'down-3 'down-2 "down" 8 4)
  (define top-body "zero\r\none\r\ntwo\r\nthree")
  (check-origin state 'down-3 0 0)
  (check-equal? (driver-eval! state '(down-3 frame 8 4))
                (complete-frame top-body 4 1))

  (step-and-fit! state 'up-2 'down-3 "up" 8 4)
  (check-origin state 'up-2 0 0)
  (check-equal? (driver-eval! state '(up-2 frame 8 4))
                (complete-frame top-body 3 1))

  (step-and-fit! state 'down-again-3 'up-2 "down" 8 4)
  (step-and-fit! state 'down-4 'down-again-3 "down" 8 4)
  (define scrolled-body "one\r\ntwo\r\nthree\r\nfour")
  (check-origin state 'down-4 1 0)
  (check-equal? (driver-eval! state '(down-4 frame 8 4))
                (complete-frame scrolled-body 4 1))

  (step-and-fit! state 'up-3 'down-4 "up" 8 4)
  (step-and-fit! state 'up-again-2 'up-3 "up" 8 4)
  (step-and-fit! state 'up-1 'up-again-2 "up" 8 4)
  (for ([entry (in-list '((up-3 3) (up-again-2 2) (up-1 1)))])
    (define name (car entry))
    (check-origin state name 1 0)
    (check-equal? (driver-eval! state `(,name frame 8 4))
                  (complete-frame scrolled-body (cadr entry) 1)))
  (step-and-fit! state 'up-0 'up-1 "up" 8 4)
  (check-origin state 'up-0 0 0)
  (check-equal? (driver-eval! state '(up-0 frame 8 4))
                (complete-frame top-body 1 1))
  (check-same state 'initial
              (editor-expression source 0 0 #f 0 0))
  (check-equal? (driver-eval! state '((down-4 text) to-string)) source))

(test-case "Left holds a clipped window until its edge; Right crosses the other edge"
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  (define-editor! state 'initial "0123456789" 0 10 #f 0 0)
  (driver-eval! state
                '(define start (initial ensure-visible 4 3)))
  (check-origin state 'start 0 7)
  (check-equal? (driver-eval! state '(start frame 4 3))
                (complete-frame "789\r\n\r\n" 1 4))
  (step-and-fit! state 'left-9 'start "left" 4 3)
  (step-and-fit! state 'left-8 'left-9 "left" 4 3)
  (step-and-fit! state 'left-7 'left-8 "left" 4 3)
  (for ([entry (in-list '((left-9 3) (left-8 2) (left-7 1)))])
    (define name (car entry))
    (check-origin state name 0 7)
    (check-equal? (driver-eval! state `(,name frame 4 3))
                  (complete-frame "789\r\n\r\n" 1 (cadr entry))))
  (step-and-fit! state 'left-6 'left-7 "left" 4 3)
  (check-origin state 'left-6 0 6)
  (check-equal? (driver-eval! state '(left-6 frame 4 3))
                (complete-frame "6789\r\n\r\n" 1 1))
  (step-and-fit! state 'right-7 'left-6 "right" 4 3)
  (step-and-fit! state 'right-8 'right-7 "right" 4 3)
  (step-and-fit! state 'right-9 'right-8 "right" 4 3)
  (for ([name (in-list '(right-7 right-8 right-9))])
    (check-origin state name 0 6))
  (step-and-fit! state 'right-10 'right-9 "right" 4 3)
  (check-origin state 'right-10 0 7)
  (check-equal? (driver-eval! state '(right-10 frame 4 3))
                (complete-frame "789\r\n\r\n" 1 4))
  (check-same state 'initial
              (editor-expression "0123456789" 0 10 #f 0 0)))

(test-case "fitted session frame delegates exact bytes to its nested editor"
  (define state (make-file-state))
  (define-editor! state 'editor "ab\ncd" 1 2 #f 0 0)
  (driver-eval! state
                `(define session ,(session-expression 'editor #f)))
  (driver-eval! state
                '(define fitted (session ensure-visible 2 1)))
  (check-origin state '(fitted editor) 1 1)
  (check-equal? (driver-eval! state '(fitted frame 2 1))
                (complete-frame "d" 1 2))
  (check-equal? (driver-eval! state '(fitted frame 2 1))
                (driver-eval! state '((fitted editor) frame 2 1)))
  (check-origin state '(session editor) 0 0)
  (check-same state 'editor
              (editor-expression "ab\ncd" 1 2 #f 0 0)))
