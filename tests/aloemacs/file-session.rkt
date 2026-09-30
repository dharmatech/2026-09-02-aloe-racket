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
                  type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path file-path "../../examples/aloemacs/file.aloe")

(define fixture-nodes
  (hash
   "/cwd" 'directory
   "/cwd/a.txt" 'file
   "/cwd/edit.txt" 'file
   "/cwd/quit.txt" 'file
   "/cwd/dir" 'directory
   "/cwd/link" 'symlink
   "/cwd/pipe" "fifo"
   "/cwd/lf-final.txt" 'file
   "/cwd/lf-no-final.txt" 'file
   "/cwd/crlf.txt" 'file
   "/cwd/unicode.txt" 'file
   "/cwd/bom.txt" 'file))

(define fixture-contents
  (hash
   "/cwd/a.txt" "old\ntext"
   "/cwd/edit.txt" "abc\nxy"
   "/cwd/quit.txt" "go"
   "/cwd/lf-final.txt" "one\ntwo\n"
   "/cwd/lf-no-final.txt" "one\ntwo"
   "/cwd/crlf.txt" "one\r\ntwo\r\n"
   "/cwd/unicode.txt" "λ\n"
   "/cwd/bom.txt" "\uFEFFfirst\n"))

(define (driver-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (bound-in-driver? state name)
  (and (env-bound? (driver-runtime-environment state) name)
       (type-environment-bound? (driver-type-environment state) name)))

(define (unbound-in-driver? state name)
  (and (not (env-bound? (driver-runtime-environment state) name))
       (not (type-environment-bound? (driver-type-environment state) name))))

(define (load-file! state)
  (driver-eval! state `(load ,(path->string file-path))))

(define (make-session-state [nodes fixture-nodes]
                            [contents fixture-contents])
  (define state (make-driver))
  (driver-inject-host!
   state
   'fs-host
   (make-fs-double "/cwd" nodes contents))
  (load-file! state)
  state)

;; A bare (Option None) intentionally has no principal type. This conditional
;; supplies Option Path while evaluating to None, without adding a source API.
(define no-path-expression
  '(if #t
       (Option None)
       (Option Some (Path new "/unused"))))

(define (editor-expression source line column quit)
  `(AloemacsEditor new
     (Text from-string ,source)
     (Position new ,line ,column)
     ,quit
     0
     0
     (List empty)))

(define (session-expression source line column quit [path #f] [echo ""])
  `(AloemacsSession new
     ,(editor-expression source line column quit)
     (Fs new fs-host)
     ,(if path
          `(Option Some (Path new ,path))
          no-path-expression)
     ,echo #f "" (Position new 0 0) #f #f))

(define (define-session! state name source line column quit [path #f])
  (driver-eval!
   state
   `(define ,name ,(session-expression source line column quit path))))

(define (define-option-session! state name expression fallback)
  (driver-eval!
   state
   `(define ,name
      (,expression case
        (None () ,fallback)
        (Some (session) session)))))

(define (check-structurally-equal state actual expected)
  (check-not-exn
   (lambda () (driver-eval! state `(check ,actual ,expected)))
   (format "structural equality of ~s and ~s" actual expected)))

(define (check-key-save state actual expected echo)
  (for ([field (in-list '(editor fs path))])
    (check-structurally-equal state `(,actual ,field) `(,expected ,field)))
  (check-equal? (driver-eval! state `(,actual echo)) echo))

(define (check-session state expression source line column quit path)
  (check-equal?
   (driver-eval! state `((,expression text) to-string))
   source)
  (check-equal? (driver-eval! state `((,expression point) line)) line)
  (check-equal? (driver-eval! state `((,expression point) column)) column)
  (check-equal? (driver-eval! state `(,expression quit)) quit)
  (check-equal?
   (driver-eval!
    state
    `((,expression path) case
       (None () "none")
       (Some (stored) (stored text))))
   (or path "none")))

(define (check-option-tag state expression expected)
  (check-equal?
   (driver-eval!
    state
    `(,expression case
       (None () "none")
       (Some (session) "some")))
   expected))

(define (raw-read state path)
  (driver-eval! state `(fs-host read ,path)))

(test-case "file session loading is explicit, source-relative, and local"
  (define state (make-driver))
  (for ([name (in-list '(AloemacsSession AloemacsEditor Text Fs Path Option))])
    (check-true (unbound-in-driver? state name)))
  (check-true (unbound-in-driver? state 'fs-host))
  (check-true (unbound-in-driver? state 'term))

  (check-true (void? (load-file! state)))
  (for ([name (in-list '(AloemacsSession AloemacsEditor Text Fs Path Option))])
    (check-true (bound-in-driver? state name)))
  (check-true (unbound-in-driver? state 'fs-host))
  (check-true (unbound-in-driver? state 'term))

  (define fresh-state (make-driver))
  (for ([name (in-list '(AloemacsSession AloemacsEditor Text Fs Path Option))])
    (check-true (unbound-in-driver? fresh-state name))))

(test-case "AloemacsSession exposes the exact checked application surface"
  (define state (make-session-state))
  (define-session! state 'session "ab\ncd" 1 1 #f)

  (check-equal? (driver-type state 'session) '(AloemacsSession FsHost))
  (for ([entry
         (in-list
          '(((session editor) AloemacsEditor)
            ((session fs) (Fs FsHost))
            ((session path) (Option Path))
            ((session echo) String)
            ((session text) Text)
            ((session point) Position)
            ((session quit) Bool)
            ((session insert "x") (AloemacsSession FsHost))
            ((session newline) (AloemacsSession FsHost))
            ((session backward-delete) (AloemacsSession FsHost))
            ((session move-left) (AloemacsSession FsHost))
            ((session move-right) (AloemacsSession FsHost))
            ((session move-up) (AloemacsSession FsHost))
            ((session move-down) (AloemacsSession FsHost))
            ((session request-quit) (AloemacsSession FsHost))
            ((session handle-key "left") (AloemacsSession FsHost))
            ((session frame 8 3) String)
            ((session visit (Path new "a.txt"))
             (Option (AloemacsSession FsHost)))
            ((session save) (Option (AloemacsSession FsHost)))))])
    (check-equal? (driver-type state (car entry)) (cadr entry)))

  (for ([datum
         (in-list
          '((session insert)
            (session insert 1)
            (session insert "x" "y")
            (session frame)
            (session frame 8)
            (session frame 8 3 2)
            (session frame "8" 3)
            (session frame 8 #t)
            (session handle-key)
            (session handle-key 1)
            (session handle-key "left" "right")
            (session visit)
            (session visit "a.txt")
            (session visit (Path new "a.txt") (Path new "b.txt"))
            (session save 1)
            (session dirty)
            (session encoding)
            (session buffers)))])
    (check-exn exn:fail:aloe-type?
               (lambda () (driver-eval! state datum))))

  (check-exn
   #rx"unbound symbol: FsHost"
   (lambda ()
     (driver-eval!
      state
      '(define-class BadSession
         (fields (host FsHost))
         (methods))))))

(test-case "visit resolves regular and missing paths and refuses non-files"
  (define state (make-session-state))
  (define-session! state 'source "untitled" 0 4 #t)

  (define-option-session!
   state 'visited '(source visit (Path new "./dir/../a.txt")) 'source)
  (check-session state 'visited "old\ntext" 0 0 #f "/cwd/a.txt")
  (check-structurally-equal
   state '(visited text)
   '(((Text from-string "old\ntext") focus-at 0) case
      (None () (Text from-string ""))
      (Some (focused) focused)))
  (check-equal? (driver-eval! state '((visited text) focus-line)) 0)
  (check-structurally-equal state '(visited fs) '(source fs))

  (define names-before (driver-eval! state '((fs-host names "/cwd") len)))
  (define-option-session!
   state 'missing '(source visit (Path new "new.txt")) 'source)
  (check-session state 'missing "" 0 0 #f "/cwd/new.txt")
  (check-equal? (driver-eval! state '((missing text) focus-line)) 0)
  (check-structurally-equal
   state '(missing text)
   '(((Text from-string "") focus-at 0) case
      (None () (Text from-string "unexpected None"))
      (Some (focused) focused)))
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/new.txt"))
                "missing")
  (check-equal? (driver-eval! state '((fs-host names "/cwd") len))
                names-before)

  (for ([path (in-list '("dir" "link" "pipe"))])
    (check-option-tag state `(source visit (Path new ,path)) "none"))

  (check-session state 'source "untitled" 0 4 #t #f)
  (check-structurally-equal
   state '(source editor)
   (editor-expression "untitled" 0 4 #t))
  (check-structurally-equal state '(source fs) '(Fs new fs-host))
  (check-structurally-equal state '(source path) no-path-expression))

(test-case "save overwrites, creates, refuses ineligible targets, and is explicit"
  (define state (make-session-state))
  (define-session! state 'untitled "draft" 0 2 #f)
  (define names-before (driver-eval! state '((fs-host names "/cwd") len)))
  (check-option-tag state '(untitled save) "none")
  (check-equal? (driver-eval! state '((fs-host names "/cwd") len))
                names-before)

  (define-option-session!
   state 'original '(untitled visit (Path new "a.txt")) 'untitled)
  (define-option-session! state 'saved '(original save) 'untitled)
  (check-structurally-equal state 'saved 'original)
  (check-equal? (raw-read state "/cwd/a.txt") "old\ntext")
  (check-session state 'original "old\ntext" 0 0 #f "/cwd/a.txt")

  ;; There is deliberately no dirty optimization: each save overwrites a
  ;; change made through the raw external receiver.
  (driver-eval! state '(fs-host write "/cwd/a.txt" "external one"))
  (define-option-session! state 'saved-again '(original save) 'untitled)
  (check-equal? (raw-read state "/cwd/a.txt") "old\ntext")
  (driver-eval! state '(fs-host write "/cwd/a.txt" "external two"))
  (define-option-session! state 'saved-third '(original save) 'untitled)
  (check-equal? (raw-read state "/cwd/a.txt") "old\ntext")
  (check-structurally-equal state 'saved-again 'original)
  (check-structurally-equal state 'saved-third 'original)

  (define-option-session!
   state 'editable '(untitled visit (Path new "edit.txt")) 'untitled)
  (driver-eval! state '(define direct-edit (editable insert "!")))
  (driver-eval! state '(define key-edit (direct-edit handle-key "z")))
  (check-session state 'key-edit "!zabc\nxy" 0 2 #f "/cwd/edit.txt")
  (define-option-session! state 'edited-save '(key-edit save) 'untitled)
  (check-equal? (raw-read state "/cwd/edit.txt") "!zabc\nxy")
  (define-option-session!
   state 'revisited '(untitled visit (Path new "edit.txt")) 'untitled)
  (check-session state 'revisited "!zabc\nxy" 0 0 #f "/cwd/edit.txt")

  (define-option-session!
   state 'new-file '(untitled visit (Path new "created.txt")) 'untitled)
  (driver-eval! state '(define new-file-edit (new-file insert "made")))
  (define-option-session!
   state 'new-file-save '(new-file-edit save) 'untitled)
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/created.txt"))
                "file")
  (check-equal? (raw-read state "/cwd/created.txt") "made")
  (define-option-session!
   state 'new-file-revisit
   '(untitled visit (Path new "created.txt"))
   'untitled)
  (check-session state 'new-file-revisit "made" 0 0 #f
                 "/cwd/created.txt")

  (define refused-names-before
    (driver-eval! state '((fs-host names "/cwd") len)))
  (for ([path (in-list '("/cwd/dir"
                         "/cwd/link"
                         "/cwd/pipe"
                         "/absent/child"
                         "/cwd/a.txt/child"))]
        [index (in-naturals)])
    (define name (string->symbol (format "refused-~a" index)))
    (define-session! state name "refused" 0 3 #f path)
    (check-option-tag state `(,name save) "none")
    (check-session state name "refused" 0 3 #f path))
  (check-equal? (driver-eval! state '((fs-host names "/cwd") len))
                refused-names-before)
  (check-equal? (raw-read state "/cwd/a.txt") "old\ntext")
  (check-equal? (driver-eval! state '(fs-host kind "/absent/child"))
                "missing")
  (check-equal? (driver-eval! state '(fs-host kind "/cwd/a.txt/child"))
                "missing"))

(test-case "quit never saves implicitly but direct save remains available"
  (define state (make-session-state))
  (define-session! state 'base "unused" 0 0 #f)
  (define-option-session!
   state 'visited '(base visit (Path new "quit.txt")) 'base)
  (driver-eval! state '(define edited (visited insert "!")))

  (driver-eval! state '(define requested (edited request-quit)))
  (check-true (driver-eval! state '(requested quit)))
  (check-equal? (raw-read state "/cwd/quit.txt") "go")

  (driver-eval! state '(define escaped (edited handle-key "escape")))
  (check-true (driver-eval! state '(escaped quit)))
  (check-equal? (raw-read state "/cwd/quit.txt") "go")

  (driver-eval! state '(fs-host write "/cwd/quit.txt" "external"))
  (driver-eval! state '(define post-quit-key (escaped handle-key "x")))
  (driver-eval! state '(define post-quit-save-key
                         (escaped handle-key "save")))
  (check-structurally-equal state 'post-quit-key 'escaped)
  (check-structurally-equal state 'post-quit-save-key 'escaped)
  (check-equal? (raw-read state "/cwd/quit.txt") "external")

  (define-option-session! state 'direct-saved '(escaped save) 'base)
  (check-session state 'direct-saved "!go" 0 1 #t "/cwd/quit.txt")
  (check-equal? (raw-read state "/cwd/quit.txt") "!go"))

(test-case "visit and no-edit save preserve exact text goldens"
  (define state (make-session-state))
  (define-session! state 'base "" 0 0 #f)
  (for ([entry
         (in-list
          '(("lf-final.txt" "one\ntwo\n")
            ("lf-no-final.txt" "one\ntwo")
            ("crlf.txt" "one\r\ntwo\r\n")
            ("unicode.txt" "λ\n")
            ("bom.txt" "\uFEFFfirst\n")))]
        [index (in-naturals)])
    (define visited-name (string->symbol (format "golden-~a" index)))
    (define saved-name (string->symbol (format "golden-saved-~a" index)))
    (define relative-path (car entry))
    (define exact-text (cadr entry))
    (define-option-session!
     state visited-name
     `(base visit (Path new ,relative-path))
     'base)
    (check-equal?
     (driver-eval! state `((,visited-name text) to-string))
     exact-text)
    (define-option-session! state saved-name `(,visited-name save) 'base)
    (check-structurally-equal state saved-name visited-name)
    (check-equal? (raw-read state (string-append "/cwd/" relative-path))
                  exact-text))

  (define-option-session!
   state 'crlf '(base visit (Path new "crlf.txt")) 'base)
  (check-equal? (driver-eval! state '(((crlf text) lines) len)) 3)
  (check-equal? (driver-eval! state '(((crlf text) lines) first)) "one\r")
  (check-equal?
   (driver-eval! state '((((crlf text) lines) rest) first))
   "two\r")
  (check-equal?
   (driver-eval! state '(((((crlf text) lines) rest) rest) first))
   ""))

(test-case "session forwards every editor command and key without adding policy"
  (define state (make-session-state))
  (define-session! state 'source "ab\ncd" 1 1 #f "/cwd/a.txt")

  (for ([command (in-list '((insert "x")
                            (newline)
                            (backward-delete)
                            (move-left)
                            (move-right)
                            (move-up)
                            (move-down)
                            (request-quit)))])
    (define selector (car command))
    (define arguments (cdr command))
    (check-structurally-equal
     state
     `(source ,selector ,@arguments)
     `(AloemacsSession new
        ((source editor) ,selector ,@arguments)
        (source fs)
        (source path)
        (source echo)
        (source searching) (source query) (source origin)
        (source wrapped) (source failing))))

  (for ([key (in-list '("return"
                        "backspace"
                        "left"
                        "right"
                        "up"
                        "down"
                        "s"
                        "q"
                        "unknown-key"
                        "escape"))])
    (check-structurally-equal
     state
     `(source handle-key ,key)
     `(AloemacsSession new
        ((source editor) handle-key ,key)
        (source fs)
        (source path)
        (source echo)
        (source searching) (source query) (source origin)
        (source wrapped) (source failing))))

  (driver-eval! state '(define inserted-s (source handle-key "s")))
  (driver-eval! state '(define inserted-q (source handle-key "q")))
  (check-equal? (driver-eval! state '((inserted-s text) to-string))
                "ab\ncsd")
  (check-equal? (driver-eval! state '((inserted-q text) to-string))
                "ab\ncqd")
  (check-false (driver-eval! state '(inserted-s quit)))
  (check-false (driver-eval! state '(inserted-q quit)))

  (define-session! state 'untitled "draft" 0 2 #f)
  (driver-eval! state '(define untitled-save-key
                         (untitled handle-key "save")))
  (check-key-save state 'untitled-save-key 'untitled "failed")

  (define-session! state 'ineligible "draft" 0 2 #f "/cwd/dir")
  (driver-eval! state '(define ineligible-save-key
                         (ineligible handle-key "save")))
  (check-key-save state 'ineligible-save-key 'ineligible "failed")

  (driver-eval! state '(fs-host write "/cwd/a.txt" "before-save-key"))
  (driver-eval! state '(define save-key-result
                         (source handle-key "save")))
  (check-key-save state 'save-key-result 'source "saved")
  (check-equal? (raw-read state "/cwd/a.txt") "ab\ncd")

  (define expected-frame
    (string-append
     (driver-eval! state '((source editor) frame 5 2))
     "\u001b[?25l\u001b[3;1H/cwd/\u001b[2;2H\u001b[?25h"))
  (define source-before-frame
    (driver-eval! state '((source text) to-string)))
  (check-equal? (driver-eval! state '(source frame 5 3)) expected-frame)
  (check-equal? (driver-eval! state '((source text) to-string))
                source-before-frame)
  (check-session state 'source "ab\ncd" 1 1 #f "/cwd/a.txt"))
