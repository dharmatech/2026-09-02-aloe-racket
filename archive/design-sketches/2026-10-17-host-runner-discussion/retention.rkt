#lang racket/base
;; Retention probe for the Aloemacs editor loop written in Aloe, run over a
;; long key script in tail and non-tail form, plus the scope check that the
;; end-state sketch's run.aloe needs a second load of file.aloe.
;; Scratch program from the 2026-10-17 host runner discussion; not a test.
;;   racket retention.rkt
;; Needs the optional tui-term package (host/racket/term.rkt requires it).
;; Each form runs 20,000 keys at about 1 ms per key.

(require racket/list racket/math racket/port racket/runtime-path
         "../../../aloe/driver.rkt"
         "../../../host/racket/fs.rkt"
         "../../../host/racket/term.rkt")

(define-runtime-path main-path "../../../examples/aloemacs/main.aloe")
(define-runtime-path file-path "../../../examples/aloemacs/file.aloe")
(define-runtime-path aloemacs-folder "../../../examples/aloemacs")

(module+ main
  (define (make-fs)
    (make-fs-double "/cwd" (hash "/cwd" 'directory "/cwd/a.txt" 'file)
                    (hash "/cwd/a.txt" "a\nb\nc\nd\ne\nf\ng\nh")))
  (define (mb b) (/ (round (/ b 10485.76)) 100.0))
  (define (quiet-term reader)
    (make-term-receiver (open-output-nowhere) reader (lambda () (values 20 8))))

  ;; ---- 1. scope: a file that loads main.aloe does not see AloemacsSession,
  ;; because a load copies only the names the loaded file itself defines.
  (define (scope-check label program)
    (define st (make-driver))
    (driver-inject-host! st 'term (quiet-term (lambda () "escape")))
    (driver-inject-host! st 'fs-host (make-fs))
    (printf "~a: ~a\n" label
            (with-handlers ([exn:fail? exn-message])
              (driver-load-port! st (open-input-string program) (open-output-nowhere)
                                 #:source-path (build-path aloemacs-folder "zz-scope-probe.aloe"))
              'accepted)))
  (scope-check "load main.aloe only"
               (format "(load ~s)\n(define-class (R H) (fields (s (AloemacsSession H))) (methods))\n"
                       (path->string main-path)))
  (scope-check "load main.aloe and file.aloe"
               (format "(load ~s)\n(load ~s)\n(define-class (R H) (fields (s (AloemacsSession H))) (methods))\n"
                       (path->string main-path) (path->string file-path)))

  ;; ---- 2. retention over a long run
  (define (run-editor-loop n tail?)
    (define remaining (box (append (make-list n "down") '("escape" "x" "save"))))
    (define gaps '())
    (define last-return #f)
    (define (reader)
      (define t (current-inexact-monotonic-milliseconds))
      (when last-return (set! gaps (cons (- t last-return) gaps)))
      (define k (car (unbox remaining)))
      (set-box! remaining (cdr (unbox remaining)))
      (set! last-return (current-inexact-monotonic-milliseconds))
      k)
    (define st (make-driver))
    (driver-inject-host! st 'term (quiet-term reader))
    (driver-inject-host! st 'fs-host (make-fs))
    (driver-load-file! st main-path)
    (driver-eval! st '(define aloemacs-startup-visit
                        (aloemacs-editor visit ((aloemacs-editor fs) path "a.txt"))))
    (driver-eval! st '(define aloemacs-editor
                        (aloemacs-startup-visit case
                          (None () aloemacs-editor)
                          (Some (session) session))))
    (driver-eval! st `(load ,(path->string file-path)))
    ;; Encoding (c) from loop-cost.rkt: the step as a session method returning
    ;; a fn, the recursion in an explicit-constructors class.
    (driver-eval! st
     '(define-methods AloemacsSession
        (methods
          (step-fn () (-> (AloemacsSession H) (AloemacsSession H))
            (fn (s)
              (let ((columns (term columns)))
                (let ((rows (term rows)))
                  (let ((fitted (s ensure-visible columns rows)))
                    (let ((recorded (fitted record-pictures columns rows)))
                      (let ((written (term write (recorded frame columns rows))))
                        (recorded handle-event (term read-event))))))))))))
    (driver-eval! st
     (if tail?
         '(define-class (AloemacsLoop H)
            (constructors (Loop (fields (session (AloemacsSession H)))))
            (methods
              (run (s (AloemacsSession H))
                   (step (-> (AloemacsSession H) (AloemacsSession H)))
                   (AloemacsSession H)
                (let ((next (step call s)))
                  (if (next quit) next (self run next step))))))
         ;; Non-tail: the recursive send is an argument of a let, its result
         ;; returned. This is the shape a careless edit produces.
         '(define-class (AloemacsLoop H)
            (constructors (Loop (fields (session (AloemacsSession H)))))
            (methods
              (run (s (AloemacsSession H))
                   (step (-> (AloemacsSession H) (AloemacsSession H)))
                   (AloemacsSession H)
                (let ((next (step call s)))
                  (if (next quit)
                      next
                      (let ((result (self run next step))) result))))))))
    (collect-garbage) (collect-garbage)
    (define mem0 (current-memory-use))
    (define peak (box mem0))
    (define sampler
      (thread (lambda ()
                (let poll ()
                  (define m (current-memory-use))
                  (when (> m (unbox peak)) (set-box! peak m))
                  (sleep 0.002)
                  (poll)))))
    (define t0 (current-inexact-monotonic-milliseconds))
    (driver-eval! st '(define aloemacs-editor
                        ((AloemacsLoop Loop aloemacs-editor) run
                          aloemacs-editor
                          (aloemacs-editor step-fn))))
    (define t1 (current-inexact-monotonic-milliseconds))
    (define mem-raw (current-memory-use))
    (kill-thread sampler)
    (collect-garbage) (collect-garbage)
    (define mem1 (current-memory-use))
    (define sorted (sort gaps <))
    (define (pct p)
      (list-ref sorted (min (sub1 (length sorted)) (exact-floor (* p (length sorted))))))
    (define (r2 x) (/ (round (* 100 x)) 100.0))
    (define (median-of xs) (list-ref (sort xs <) (quotient (length xs) 2)))
    (printf "~a N=~a keys: wall ~a s, ~a ms/key; mem before ~a MB, raw after ~a MB, after GC ~a MB (delta ~a MB), sampled peak ~a MB (+~a); gap median ~a ms, p99 ~a ms, first-1000 median ~a ms, last-1000 median ~a ms; quit=~a\n"
            (if tail? "TAIL   " "NONTAIL") n
            (r2 (/ (- t1 t0) 1000)) (/ (round (* 1000 (/ (- t1 t0) n))) 1000.0)
            (mb mem0) (mb mem-raw) (mb mem1) (mb (- mem1 mem0))
            (mb (unbox peak)) (mb (- (unbox peak) mem0))
            (r2 (pct 0.5)) (r2 (pct 0.99))
            (r2 (median-of (take (reverse gaps) 1000)))
            (r2 (median-of (take gaps 1000)))
            (driver-eval! st '(aloemacs-editor quit))))

  (run-editor-loop 20000 #t)
  (run-editor-loop 20000 #f))
