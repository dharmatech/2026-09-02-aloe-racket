#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt"
                  [make-top-level-env make-raw-top-level-env]
                  env-base
                  env-bound?
                  env-lookup)
         (only-in "../../aloe/main.rkt"
                  eval-source
                  exn:fail:aloe-type?
                  make-top-level-env
                  type->datum
                  type-of)
         (only-in "../../aloe/parse.rkt"
                  parse-datum)
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?)
         (only-in (submod "../../aloe/type.rkt" load-cache)
                  type-environment-base)
         "../../aloe/expression-query.rkt"
         "../../host/racket/fs.rkt"
         "../../host/racket/term.rkt")

(define-runtime-path box-path "fixtures/box.aloe")
(define-runtime-path keyed-port-path "fixtures/keyed-thing-port.aloe")
(define-runtime-path holder-path "fixtures/holder.aloe")
(define-runtime-path holder-methods-path "fixtures/holder-methods.aloe")
(define-runtime-path uses-fs-host-path "fixtures/uses-fs-host.aloe")
(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")
(define-runtime-path file-path "../../examples/aloemacs/file.aloe")
(define-runtime-path point-path "../../examples/point.aloe")
(define-runtime-path boids-path "../../examples/boids.aloe")
(define-runtime-path core-path "../../examples/mpl/core.aloe")
(define-runtime-path sym-path "../../examples/mpl/sym.aloe")
(define-runtime-path text-library-path "../../lib/text.aloe")
(define-runtime-path option-library-path "../../lib/option.aloe")
(define-runtime-path gel-main-path "../../gel/main.aloe")
(define-runtime-path gel-loop-path "../../gel/loop.aloe")
(define-runtime-path gel-stack-path "../../gel/stack.aloe")
(define-runtime-path gel-menu-path "../../gel/menu.aloe")
(define-runtime-path loaded-root-path
  "../editor/expression-query/fixtures/003-public-query/root.aloe")
(define-runtime-path lsp-point-path "../editor/lsp/fixtures/point.aloe")

(define (load-datum path)
  `(load ,(path->string path)))

(define (runtime state)
  (driver-runtime-environment state))

(define (checker state)
  (driver-type-environment state))

;; Bound in both halves of the driver.
(define (bound? state name)
  (and (env-bound? (runtime state) name)
       (type-environment-bound? (checker state) name)))

;; Unbound in both halves of the driver.
(define (unbound? state name)
  (not (or (env-bound? (runtime state) name)
           (type-environment-bound? (checker state) name))))

;; The exception's kind and message, so a failure prints what was raised.
(define (raised thunk)
  (with-handlers ([exn:fail?
                   (lambda (exception)
                     (list (exn:fail:aloe-type? exception)
                           (exn-message exception)))])
    (thunk)
    'no-error))

(define (position-of source text)
  (define positions (regexp-match-positions (regexp-quote text) source))
  (unless positions
    (error 'position-of "text not found: ~e" text))
  (add1 (caar positions)))

(define (make-scripted-term keys)
  (define remaining-keys (box keys))
  (make-term-receiver
   (open-output-string)
   (lambda ()
     (define remaining (unbox remaining-keys))
     (unless (pair? remaining)
       (error 'scripted-term "key script exhausted"))
     (set-box! remaining-keys (cdr remaining))
     (car remaining))))

(define (fs-double)
  (make-fs-double "/cwd" (hash "/cwd" 'directory)))

;; Each named file holds its text in a fresh directory under the temporary
;; directory; the directory is removed afterwards.
(define (call-with-temporary-files files proc)
  (define directory (make-temporary-directory "modules-006-~a"))
  (dynamic-wind
   void
   (lambda ()
     (proc
      (for/list ([file (in-list files)])
        (define path (build-path directory (car file)))
        (call-with-output-file path
          (lambda (output) (display (cdr file) output)))
        path)))
   (lambda ()
     (delete-directory/files directory))))

(test-case "a load copies only the file's own names"
  (define state (make-driver))
  (driver-eval! state (load-datum editor-path))
  (for ([name '(AloemacsEditor UndoFrame safe-cell-controls)])
    (check-true (bound? state name) (format "~a bound" name)))
  (for ([name '(Span Text Position)])
    (check-true (unbound? state name) (format "~a unbound" name)))
  (driver-eval! state (load-datum text-library-path))
  (check-true (bound? state 'Span))
  (define (probe-text body)
    (format "(load ~s)\n\n(define probe ~a)\n" (path->string editor-path) body))
  (call-with-temporary-files
   (list (cons "span-probe.aloe" (probe-text "Span"))
         (cons "controls-probe.aloe" (probe-text "safe-cell-controls")))
   (lambda (paths)
     (check-equal?
      (raised (lambda ()
                (driver-load-file! (make-driver) (car paths)
                                   (open-output-string))))
      (list #t "typecheck: unbound symbol: Span"))
     (check-equal?
      (driver-load-file! (make-driver) (cadr paths) (open-output-string))
      '()))))

(test-case "Option is the base's"
  (define state (make-driver))
  (define R (runtime state))
  (driver-eval! state (load-datum option-library-path))
  (define loaded-option (driver-eval! state 'Option))
  (driver-eval! state '(define found ("abc" find "b" 0)))
  (driver-eval! state
                '(define-class (Option T)
                   (constructors
                    (None (fields))
                    (Some (fields (value T))))
                   (methods
                    (present? () Bool
                              (self case
                                    (None () #f)
                                    (Some (value) #t))))))
  (check-not-exn
   (lambda () (driver-eval! state '(check found ("abc" find "b" 0)))))
  (check-eq? loaded-option (env-lookup (env-base R) 'Option)))

(test-case "one lib/text.aloe per base"
  (define state (make-driver))
  (define base-option (driver-eval! state 'Option))
  (driver-eval! state (load-datum text-library-path))
  (define text-class (driver-eval! state 'Text))
  (driver-eval! state (load-datum editor-path))
  (driver-eval! state (load-datum file-path))
  (driver-eval! state (load-datum text-library-path))
  (check-eq? (driver-eval! state 'Text) text-class)
  (check-eq? (driver-eval! state 'Option) base-option))

(test-case "a second root unions; a repeat copies again"
  (define state (make-driver))
  (driver-inject-host! state 'term (make-scripted-term '()))
  (check-equal? (driver-load-file! state gel-main-path (open-output-string))
                '())
  (check-equal? (driver-load-file! state point-path (open-output-string))
                '())
  (check-true (bound? state 'gel-main))
  (check-true (bound? state 'Point))
  (define point-class (driver-eval! state 'Point))
  (check-equal? (driver-load-file! state point-path (open-output-string))
                '())
  (check-eq? (driver-eval! state 'Point) point-class))

(test-case "eval-source and the raw environment"
  (define boids-source (file->string boids-path))
  (define E (make-top-level-env))
  (eval-source boids-source E #:source-path boids-path)
  (check-true (env-bound? E 'demo))
  (check-false (env-bound? E 'Point))
  (check-equal? (eval-source "(((demo step) flock) len)" E) 3)
  (eval-source (format "(load ~s) (Point new 1 2)" (path->string point-path))
               E)
  (check-true (env-bound? E 'Point))
  (define RAW (make-raw-top-level-env))
  (eval-source boids-source RAW #:source-path boids-path)
  (check-equal? (eval-source "(((demo step) flock) len)" RAW) 3)
  (check-false (env-bound? RAW 'demo))
  (check-true (env-bound? RAW 'Option)))

(test-case "keyed and unkeyed ports"
  (define text
    (format "(load ~s) (define-class KeyedThing (fields) (methods))"
            (path->string box-path)))
  (define keyed (make-driver))
  (check-equal?
   (driver-load-port! keyed (open-input-string text) (open-output-string)
                      #:source-path keyed-port-path)
   '())
  (check-true (bound? keyed 'KeyedThing))
  (check-true (unbound? keyed 'Box))
  (define unkeyed (make-driver))
  (check-equal?
   (driver-load-port! unkeyed (open-input-string text) (open-output-string))
   '())
  (check-true (bound? unkeyed 'KeyedThing))
  (check-true (bound? unkeyed 'Box)))

(test-case "Gel end to end"
  (define state (make-driver))
  (driver-inject-host! state 'term (make-scripted-term '("q")))
  (for ([path (list gel-main-path point-path gel-stack-path)])
    (driver-load-file! state path (open-output-string)))
  (check-not-exn
   (lambda ()
     (driver-eval!
      state
      '(gel-main call
         ((gel-empty-stack push (Point new 1 2))
          push
          (Point new 10 20)))))))

(test-case "matching-picks runs where it was written"
  (define state (make-driver))
  (for ([path (list gel-loop-path gel-stack-path gel-menu-path)])
    (driver-load-file! state path (open-output-string)))
  (for ([datum
         (in-list
          '((define rows-80 (gel-rows of 10))
            (define row-80
              (rows-80 fold
                (rows-80 first)
                (fn (found candidate)
                  (if (((candidate selector) name) = "+") candidate found))))
            (define stack-80
              (((gel-empty-stack push 2) push "skip") push 10))))])
    (driver-eval! state datum))
  (define picks '(stack-80 matching-picks row-80))
  (check-equal? (type->datum (type-of (parse-datum picks) (checker state)))
                'GelPicks)
  (check-not-exn (lambda () (driver-eval! state picks))))

(test-case "a later load replaces a prompt name"
  (define state (make-driver))
  (driver-eval! state '(define-class Point (fields) (methods)))
  (define prompt-point (driver-eval! state 'Point))
  (driver-eval! state (load-datum point-path))
  (check-false (eq? (driver-eval! state 'Point) prompt-point))
  (check-not-exn
   (lambda () (type-of (parse-datum '(Point new 1 2)) (checker state)))))

(test-case "define-methods runs in the file that wrote it"
  (define state (make-driver))
  (driver-eval! state (load-datum holder-path))
  (driver-eval! state (load-datum holder-methods-path))
  (check-equal? (driver-eval! state '((Holder new) answer)) 42)
  (check-true (unbound? state 'helper-value)))

(test-case "two drivers"
  (define first-state (make-driver))
  (driver-eval! first-state (load-datum box-path))
  (check-true (bound? first-state 'Box))
  (check-true (unbound? (make-driver) 'Box)))

(test-case "hosts live on the base"
  (define state (make-driver))
  (define R (runtime state))
  (driver-eval! state (load-datum box-path))
  (check-exn exn:fail:contract?
             (lambda () (driver-inject-host! state 'Box (fs-double))))
  (driver-inject-host! state 'fs-host (fs-double))
  (check-equal? (driver-load-file! state uses-fs-host-path
                                   (open-output-string))
                '())
  (check-true (env-bound? (env-base R) 'fs-host))
  (check-true (type-environment-bound?
               (type-environment-base (checker state)) 'fs-host)))

(test-case "hover"
  (define (hover-type path text)
    (expression-query-result-type
     (query-expression-at path (position-of (file->string path) text))))
  (check-equal? (hover-type loaded-root-path "(Loaded new 7)") 'Loaded)
  (check-equal? (hover-type lsp-point-path "(Point new 1 2)") '(Point Int))
  (check-equal?
   (raised (lambda () (query-expression-at sym-path 1)))
   (list #t
         "typecheck: class Sym does not implement protocol Math method show")))

(test-case "MPL conforms"
  (check-equal? (driver-load-file! (make-driver) core-path
                                   (open-output-string))
                '()))
