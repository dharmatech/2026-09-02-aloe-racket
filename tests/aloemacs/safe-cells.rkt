#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt" type-of type->datum)
         "../../host/racket/fs.rkt")

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")

(define (make-state [file? #f] [contents (hash)])
  (define state (make-driver))
  (when file?
    (driver-inject-host!
     state 'fs-host
     (make-fs-double "/cwd"
                     (hash "/cwd" 'directory
                           "/cwd/a.txt" 'file)
                     contents)))
  (driver-eval! state `(load ,(path->string (if file? file-path editor-path))))
  state)

(define (checked-type state datum)
  (type->datum
   (type-of (parse-datum datum) (driver-type-environment state))))

(define (editor source column [scroll 0])
  `(AloemacsEditor new
     (Text from-string ,source)
     (Position new 0 ,column)
     #f 0 ,scroll (List empty) (if #t (Option None) (Option Some (Position new 0 0)))))

(define (editor-frame body row column)
  (string-append
   "\u001b[?25l\u001b[2J\u001b[H" body
   (format "\u001b[~a;~aH\u001b[?25h" row column)))

(define (session-frame body row column terminal-row label)
  (string-append
   (editor-frame body row column)
   (format "\u001b[?25l\u001b[~a;1H~a\u001b[~a;~aH\u001b[?25h"
           terminal-row label row column)))

(define (session source path echo)
  `(AloemacsSession new
     ,(editor source 0)
     (Fs new fs-host)
     (Option Some (Path new ,path))
     ,echo #f "" (Position new 0 0) #f #f (List empty)))

(test-case "direct checked safe-cells send covers every control and keeps length"
  (define state (make-state))
  (driver-eval! state `(define e ,(editor "" 0)))
  (define controls
    (list->string (append (for/list ([n (in-range 32)]) (integer->char n))
                          (list (integer->char 127)))))
  (define source (string-append "A" controls "[31m" (string (integer->char 128)) "λ"))
  (define shown (string-append "A" (make-string 33 #\space) "[31m"
                               (string (integer->char 128)) "λ"))
  (check-equal? (checked-type state `(e safe-cells ,source)) 'String)
  (check-equal? (driver-eval! state `(e safe-cells ,source)) shown)
  (check-equal? (driver-eval! state `((e safe-cells ,source) len))
                (string-length source))
  (check-equal? (driver-eval! state '(e safe-cells "")) ""))

(test-case "editor paints only clipped cells and retains source cursor columns"
  (define state (make-state))
  (define source "A\u001b[31m\tB\r\u0000\u007fZ")
  (driver-eval! state `(define e ,(editor source 6)))
  (check-equal? (driver-eval! state '(e frame 20 1))
                (editor-frame "A [31m B   Z" 1 7))
  (check-equal? (driver-eval! state '((e text) to-string)) source)
  (check-equal? (driver-eval! state '((e point) column)) 6)

  (driver-eval! state `(define clipped ,(editor "X\u001bABC\u007f" 4 2)))
  (check-equal? (driver-eval! state '(clipped frame 3 1))
                (editor-frame "ABC" 1 3))
  (check-equal? (driver-eval! state '(clipped frame 0 1))
                (editor-frame "" 1 3))
  (driver-eval! state `(define lines ,(editor "\t\n\r\n\u001b" 0)))
  (check-equal? (driver-eval! state '(lines frame 3 3))
                (editor-frame " \r\n \r\n " 1 1)))

(test-case "session paints clipped idle and status labels after prefixing"
  (define state (make-state #t))
  (define path "/cwd/\u001b\tXYZ")
  (driver-eval! state `(define idle ,(session "" path "")))
  (driver-eval! state `(define saved ,(session "" path "saved")))
  (driver-eval! state `(define failed ,(session "" path "failed")))
  (check-equal? (driver-eval! state '(idle frame 9 2))
                (session-frame "" 1 1 2 "/cwd/  XY"))
  (check-equal? (driver-eval! state '(saved frame 15 2))
                (session-frame "" 1 1 2 "saved: /cwd/  X"))
  (check-equal? (driver-eval! state '(failed frame 15 2))
                (session-frame "" 1 1 2 "failed: /cwd/  "))
  (check-equal? (driver-eval! state '(idle frame 9 1))
                (driver-eval! state '((idle editor) frame 9 1)))
  (for ([name (in-list '(idle saved failed))])
    (check-equal?
     (driver-eval! state `((,name path) case
                            (None () "missing")
                            (Some (p) (p text))))
     path))
  (check-equal? (driver-eval! state '(saved echo)) "saved")
  (check-equal? (driver-eval! state '(failed echo)) "failed"))

(test-case "visit renders safely and save writes original CRLF and controls"
  (define source "A\t\r\nB\u001b\r\n")
  (define state (make-state #t (hash "/cwd/a.txt" source)))
  (driver-eval! state `(define base ,(session "" "/cwd/a.txt" "")))
  (driver-eval! state
                '(define visited
                   ((base visit (Path new "a.txt")) case
                     (None () base)
                     (Some (s) s))))
  (check-equal? (driver-eval! state '((visited text) to-string)) source)
  (check-equal? (driver-eval! state '(visited frame 20 4))
                (session-frame "A  \r\nB  \r\n" 1 1 4 "/cwd/a.txt"))
  (check-equal? (driver-eval! state '((visited text) to-string)) source)
  (driver-eval! state
                '(define saved
                   ((visited save) case
                     (None () base)
                     (Some (s) s))))
  (check-equal? (driver-eval! state '(fs-host read "/cwd/a.txt")) source)
  (check-equal? (driver-eval! state '((saved text) to-string)) source))
