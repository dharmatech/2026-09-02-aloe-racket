#lang racket/base

;; Interactive aloemacs runner:
;;   racket host/racket/aloemacs-run.rkt [path]

(require racket/runtime-path
         (only-in "../../aloe/driver.rkt"
                  make-driver
                  driver-inject-host!
                  driver-load-file!
                  driver-eval!
                  driver-prepare!)
         "term.rkt"
         "fs.rkt")

(provide run-aloemacs
         run-aloemacs-with-term
         run-aloemacs-with-hosts)

(define-runtime-path aloemacs-main-path
  "../../examples/aloemacs/main.aloe")

(define (run-aloemacs-with-hosts term fs-host [path #f])
  (define state (make-driver))
  (driver-inject-host! state 'term term)
  (driver-inject-host! state 'fs-host fs-host)
  (driver-load-file! state aloemacs-main-path)
  (when path
    (driver-eval!
     state
     `(define aloemacs-startup-visit
        (aloemacs-editor visit
          ((aloemacs-editor fs) path ,path))))
    (unless (driver-eval! state '(aloemacs-startup-visit present?))
      (error 'aloemacs "cannot visit path: ~s" path))
    (driver-eval!
     state
     '(define aloemacs-editor
        (aloemacs-startup-visit case
          (None () aloemacs-editor)
          (Some (session) session)))))
  (define read-columns (driver-prepare! state '(term columns)))
  (define read-rows (driver-prepare! state '(term rows)))
  (define (prepare-viewport columns rows)
    (values
     (driver-prepare!
      state
      `(define aloemacs-editor
         (aloemacs-editor ensure-visible ,columns ,rows)))
     (driver-prepare!
      state
      `(define aloemacs-editor
         (aloemacs-editor record-pictures ,columns ,rows)))
     (driver-prepare!
      state
      `(term write
         (aloemacs-editor frame ,columns ,rows)))))
  (define handle-event
    (driver-prepare!
     state
     '(define aloemacs-editor
        (aloemacs-editor handle-event (term read-event)))))
  (define quit? (driver-prepare! state '(aloemacs-editor quit)))
  (let loop ([previous-columns #f]
             [previous-rows #f]
             [previous-fit #f]
             [previous-record #f]
             [previous-frame #f])
    (define columns (read-columns))
    (define rows (read-rows))
    (define-values (fit record frame)
      (if (and (equal? columns previous-columns)
               (equal? rows previous-rows))
          (values previous-fit previous-record previous-frame)
          (prepare-viewport columns rows)))
    (fit)
    (record)
    (frame)
    (handle-event)
    (unless (quit?)
      (loop columns rows fit record frame))))

(define (run-aloemacs-with-term term [path #f])
  (define fs-host (make-fs-receiver))
  (if path
      (run-aloemacs-with-hosts term fs-host path)
      (run-aloemacs-with-hosts term fs-host)))

;; The alternate screen (1049) first, then button presses and releases only
;; (1000) in SGR form (1006): enabled after with-term owns the output port,
;; disabled in reverse order before it tears the port down, on normal return
;; and when an exception leaves the editor. Terminal setup written by hand,
;; not frame bytes; the first frame clears the alternate screen.
(define (run-aloemacs [path #f])
  (call-with-tty-term-receiver
   (lambda (term)
     (dynamic-wind
      (lambda ()
        (write-string "\e[?1049h\e[?1000h\e[?1006h" (current-output-port))
        (flush-output (current-output-port)))
      (lambda ()
        (if path
            (run-aloemacs-with-term term path)
            (run-aloemacs-with-term term)))
      (lambda ()
        (write-string "\e[?1000l\e[?1006l\e[?1049l" (current-output-port))
        (flush-output (current-output-port)))))))

(module+ main
  (define arguments (vector->list (current-command-line-arguments)))
  (cond
    [(> (length arguments) 1)
     (fprintf (current-error-port)
              "usage: racket host/racket/aloemacs-run.rkt [path]\r\n")
     (exit 2)]
    [else
     (with-handlers ([exn:fail?
                      (lambda (exception)
                        (fprintf (current-error-port)
                                 "aloemacs: ~a\r\n"
                                 (exn-message exception))
                        (exit 1))])
       (void
        (if (null? arguments)
            (run-aloemacs)
            (run-aloemacs (car arguments)))))]))
