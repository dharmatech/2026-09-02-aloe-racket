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
      `(term write
         (aloemacs-editor frame ,columns ,rows)))))
  (define handle-key
    (driver-prepare!
     state
     '(define aloemacs-editor
        (aloemacs-editor handle-key (term read-key)))))
  (define quit? (driver-prepare! state '(aloemacs-editor quit)))
  (let loop ([previous-columns #f]
             [previous-rows #f]
             [previous-fit #f]
             [previous-frame #f])
    (define columns (read-columns))
    (define rows (read-rows))
    (define-values (fit frame)
      (if (and (equal? columns previous-columns)
               (equal? rows previous-rows))
          (values previous-fit previous-frame)
          (prepare-viewport columns rows)))
    (fit)
    (frame)
    (handle-key)
    (unless (quit?)
      (loop columns rows fit frame))))

(define (run-aloemacs-with-term term [path #f])
  (define fs-host (make-fs-receiver))
  (if path
      (run-aloemacs-with-hosts term fs-host path)
      (run-aloemacs-with-hosts term fs-host)))

(define (run-aloemacs [path #f])
  (call-with-tty-term-receiver
   (lambda (term)
     (if path
         (run-aloemacs-with-term term path)
         (run-aloemacs-with-term term)))))

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
