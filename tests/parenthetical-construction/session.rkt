#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         (only-in "../../aloe/parse.rkt" parse-datum)
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         (only-in "../../host/racket/fs.rkt" make-fs-double))

(define-runtime-path main-path "../../examples/aloemacs/main.aloe")

;; Independent original startup fixture: positional construction throughout,
;; including every inactive alternative used to witness an Option's type.
(define positional-startup
  '(AloemacsSession new
     (AloemacsBuffers new
       (List empty)
       (AloemacsBuffer new
         (AloemacsEditor new
           (Text from-string "")
           (Position new 0 0)
           #f
           0
           0
           (List empty)
           (if #t (Option None) (Option Some (Position new 0 0)))
           0)
         (if #t
             (Option None)
             (Option Some (Path new "/typed-none")))
         0)
       (List empty))
     (Fs new fs-host)
     ""
     #f
     ""
     (Position new 0 0)
     #f
     #f
     (List empty)
     (if #t
         (Option None)
         (Option Some aloemacs-global-keymap))
     (if #t
         (Option None)
         (Option Some (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
     (if #t (Option None) (Option Some ""))
     (if #t (Option None) (Option Some (AloemacsCommand FindFile)))
     (AloemacsWindows new
       (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f))
       0 0 0)))

(define session-fields
  '(buffers fs echo searching query origin wrapped failing kill-ring pending
    prompt last-submission waiting-command windows))

(define startup-locals
  '(initial-buffer inactive-prompt initial-windows initial-buffers
    initial-pending initial-last-submission initial-waiting-command))

(define (make-startup-driver)
  (define state (make-driver))
  (define fs-host (make-fs-double "/cwd" (hash "/cwd" 'directory)))
  (driver-inject-host! state 'fs-host fs-host)
  (driver-load-file! state main-path (open-output-string))
  (values state fs-host))

(define (define-positional-startup! state)
  (driver-eval! state `(define positional-editor ,positional-startup)))

(define (checked-type state datum)
  (type->datum (type-of (parse-datum datum) (driver-type-environment state))))

(define (check-observation state datum expected)
  (check-equal? (driver-eval! state datum) expected (format "~s" datum)))

(define (check-none state datum)
  (check-observation state `(,datum case (None () #t) (Some (value) #f)) #t))

(define (check-initial-contents state session fs-host)
  (for ([field (in-list '(echo query))])
    (check-observation state `(,session ,field) ""))
  (for ([field (in-list '(searching wrapped failing))])
    (check-observation state `(,session ,field) #f))
  (for ([field (in-list '(line column))])
    (check-observation state `((,session origin) ,field) 0))
  (check-observation state `((,session kill-ring) len) 0)
  (for ([field (in-list '(pending prompt last-submission waiting-command))])
    (check-none state `(,session ,field)))
  (check-eq? (driver-eval! state `((,session fs) host)) fs-host)

  (define buffers `(,session buffers))
  (define buffer `(,buffers current-buffer))
  (define editor `(,buffer editor))
  (for ([field (in-list '(before after))])
    (check-observation state `((,buffers ,field) len) 0))
  (check-observation state `(,buffer id) 0)
  (check-none state `(,buffer path))
  (check-observation state `((,editor text) to-string) "")
  (for ([field (in-list '(line column))])
    (check-observation state `((,editor point) ,field) 0))
  (check-observation state `(,editor quit) #f)
  (for ([field (in-list '(scroll-row scroll-col text-rows))])
    (check-observation state `(,editor ,field) 0))
  (check-observation state `((,editor history) len) 0)
  (check-none state `(,editor mark))

  (define windows `(,session windows))
  (define tree `(,windows tree))
  (for ([field (in-list '(selected columns rows))])
    (check-observation state `(,windows ,field) 0))
  (check-observation state `(,tree case (Leaf (view) #t) (else #f)) #t)
  (for ([field (in-list '(id buffer-id scroll-row scroll-col))])
    (check-observation state
                       `(,tree case (Leaf (view) (view ,field)) (else -1))
                       0))
  (check-observation state `(,tree case (Leaf (view) (view locked)) (else #t)) #f))

(test-case "actual startup preserves the checked positional session type and value"
  (define-values (state fs-host) (make-startup-driver))
  (check-equal? (checked-type state 'aloemacs-editor) '(AloemacsSession FsHost))
  (check-equal? (checked-type state positional-startup) '(AloemacsSession FsHost))
  (define-positional-startup! state)
  (check-equal? (checked-type state 'positional-editor) '(AloemacsSession FsHost))
  (check-not-exn
   (lambda () (driver-eval! state '(check aloemacs-editor positional-editor)))))

(test-case "all fourteen session fields retain their positional associations"
  (define-values (state fs-host) (make-startup-driver))
  (define-positional-startup! state)
  (for ([field (in-list session-fields)])
    (check-not-exn
     (lambda ()
       (driver-eval! state
                     `(check (aloemacs-editor ,field) (positional-editor ,field))))
     (symbol->string field))))

(test-case "actual and independent positional startup have the original empty contents"
  (define-values (state fs-host) (make-startup-driver))
  (define-positional-startup! state)
  (for ([session (in-list '(aloemacs-editor positional-editor))])
    (check-initial-contents state session fs-host)))

(test-case "both let groups keep all seven locals out of the driver environments"
  (define-values (state fs-host) (make-startup-driver))
  (for ([name (in-list startup-locals)])
    (check-false (env-bound? (driver-runtime-environment state) name)
                 (symbol->string name))
    (check-false (type-environment-bound? (driver-type-environment state) name)
                 (symbol->string name))))
