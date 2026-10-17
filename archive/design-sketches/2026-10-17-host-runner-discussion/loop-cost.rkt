#lang racket/base

;; Per-key cost: today's Racket loop with driver-prepare! (A), an Aloe-side
;; loop run once through driver-eval! (B), and per-key driver-eval! without
;; driver-prepare! (C). Same scripted term, same fs double, same startup visit.
;; Scratch program from the 2026-10-17 host runner discussion; not a test.
;;   racket loop-cost.rkt
;; Needs the optional tui-term package (host/racket/term.rkt requires it).

(require racket/list
         racket/runtime-path
         "../../../aloe/driver.rkt"
         "../../../host/racket/aloemacs-run.rkt"
         "../../../host/racket/fs.rkt"
         "../../../host/racket/term.rkt")

(define-runtime-path main-path "../../../examples/aloemacs/main.aloe")
(define-runtime-path file-aloe-path "../../../examples/aloemacs/file.aloe")

(module+ main
  (define key-count 50)
  (define keys (append (make-list key-count "down") '("escape")))
  (define spare-keys '("x" "save"))
  (define size '(20 8))

  (define (now) (current-inexact-monotonic-milliseconds))

  ;; -------------------------------------------------------------- fixture

  (struct fixture
    (receiver          ; host receiver for 'term
     bytes             ; -> bytes written so far
     events            ; -> list of events in order
     gaps              ; -> list of gaps (ms), key-read return -> next key-read call
     remaining         ; -> keys left
     first-columns     ; -> ms of the first columns call, or #f
     first-key-call    ; -> ms of the first key call
     first-key-return  ; -> ms of the first key return
     key-calls))       ; -> count

  (define (make-fixture)
    (define remaining (box (append keys spare-keys)))
    (define size-calls (box 0))
    (define recorded '())
    (define gaps '())
    (define last-key-return #f)
    (define first-columns #f)
    (define first-key-call #f)
    (define first-key-return #f)
    (define key-calls 0)
    (define accumulated (open-output-bytes))
    (define (record! event) (set! recorded (cons event recorded)))
    (define output
      (make-output-port
       'loop-cost always-evt
       (lambda (bytes start end _non-block? _breakable?)
         (cond
           [(= start end) (record! 'flush)]
           [else
            (write-bytes bytes accumulated start end)
            (record! 'write)])
         (- end start))
       void))
    (define receiver
      (make-term-receiver
       output
       (lambda ()
         (define key-call (now))
         (unless first-key-call (set! first-key-call key-call))
         (when last-key-return
           (set! gaps (cons (- key-call last-key-return) gaps)))
         (define keys-left (unbox remaining))
         (unless (pair? keys-left)
           (error 'scripted-term "key script exhausted"))
         (define key (car keys-left))
         (set-box! remaining (cdr keys-left))
         (record! (list 'key key))
         (set! key-calls (add1 key-calls))
         (set! last-key-return (now))
         (unless first-key-return (set! first-key-return last-key-return))
         key)
       (lambda ()
         (define call (unbox size-calls))
         (when (= call 0) (set! first-columns (now)))
         (record! (list (if (even? call) 'columns 'rows)
                        (if (even? call) (car size) (cadr size))))
         (set-box! size-calls (add1 call))
         (values (car size) (cadr size)))))
    (fixture receiver
             (lambda () (get-output-bytes accumulated))
             (lambda () (reverse recorded))
             (lambda () (reverse gaps))
             (lambda () (unbox remaining))
             (lambda () first-columns)
             (lambda () first-key-call)
             (lambda () first-key-return)
             (lambda () key-calls)))

  (define (make-fs)
    (make-fs-double
     "/cwd"
     (hash "/cwd" 'directory "/cwd/a.txt" 'file)
     (hash "/cwd/a.txt" "a\nb\nc\nd\ne\nf\ng\nh")))

  ;; A driver with term and fs-host injected, main.aloe loaded, and the
  ;; startup visit of "a.txt" done as aloemacs-run.rkt lines 28-41 do it.
  (define (make-visited-driver fx)
    (define state (make-driver))
    (driver-inject-host! state 'term (fixture-receiver fx))
    (driver-inject-host! state 'fs-host (make-fs))
    (driver-load-file! state main-path)
    (driver-eval!
     state
     `(define aloemacs-startup-visit
        (aloemacs-editor visit
          ((aloemacs-editor fs) path ,"a.txt"))))
    (unless (driver-eval! state '(aloemacs-startup-visit present?))
      (error 'aloemacs "cannot visit path: ~s" "a.txt"))
    (driver-eval!
     state
     '(define aloemacs-editor
        (aloemacs-startup-visit case
          (None () aloemacs-editor)
          (Some (session) session))))
    state)

  ;; ---------------------------------------------------------------- stats

  (define (median xs)
    (define sorted (sort xs <))
    (define n (length sorted))
    (if (odd? n)
        (list-ref sorted (quotient n 2))
        (/ (+ (list-ref sorted (sub1 (quotient n 2)))
              (list-ref sorted (quotient n 2)))
           2)))

  (define (r2 x) (/ (round (* x 100)) 100.0))

  (define (gap-report label fx)
    (define gaps ((fixture-gaps fx)))
    (printf "  ~a: ~a gaps, median ~a ms, first ~a ms, max ~a ms, min ~a ms, mean ~a ms\n"
            label
            (length gaps)
            (r2 (median gaps))
            (r2 (car gaps))
            (r2 (apply max gaps))
            (r2 (apply min gaps))
            (r2 (/ (apply + gaps) (length gaps))))
    gaps)

  ;; -------------------------------------------------------------------- A

  (define (run-A)
    (define fx (make-fixture))
    (define t0 (now))
    (run-aloemacs-with-hosts (fixture-receiver fx) (make-fs) "a.txt")
    (define t1 (now))
    (printf "A (today's runner, driver-prepare!): total ~a ms; start->first columns ~a ms; start->first key return ~a ms\n"
            (r2 (- t1 t0))
            (r2 (- ((fixture-first-columns fx)) t0))
            (r2 (- ((fixture-first-key-return fx)) t0)))
    (gap-report "A gaps" fx)
    fx)

  ;; -------------------------------------------------------------------- B

  ;; The prompt does not see AloemacsSession after main.aloe (SPEC section 11:
  ;; names a file only received from its own loads are not copied), so load
  ;; file.aloe at the prompt; the same path and bytes copy the definitions
  ;; without rerunning.
  (define load-file-aloe-datum `(load ,(path->string file-aloe-path)))

  ;; Encoding (c), in two parts. The two natural encodings, a define-methods
  ;; on AloemacsSession with a recursive run, and a generic (fields ...)
  ;; wrapper recursing through a new wrapper, hang the checker; see
  ;; recursion-hang.rkt.
  ;; 1. The per-iteration body is a define-methods on the generic session that
  ;;    returns a fn. Its body is deferred until the send `(aloemacs-editor
  ;;    step-fn)` sees a concrete H, where the fn's parameter takes the expected
  ;;    arrow type from the return type.
  (define step-method-datum
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

  ;; 2. The recursion lives in an explicit-constructors generic class. Its `run`
  ;;    body is checked once at definition (H rigid; it only sends `quit`, which
  ;;    never reaches the host) and is never re-walked at a send.
  (define loop-class-datum
    '(define-class (AloemacsLoop H)
       (constructors
         (Loop (fields (session (AloemacsSession H)))))
       (methods
         (run (s (AloemacsSession H))
              (step (-> (AloemacsSession H) (AloemacsSession H)))
              (AloemacsSession H)
           (let ((next (step call s)))
             (if (next quit)
                 next
                 (self run next step)))))))

  (define run-loop-datum
    '(define aloemacs-editor
       ((AloemacsLoop Loop aloemacs-editor) run
         aloemacs-editor
         (aloemacs-editor step-fn))))

  (define (run-B)
    (define fx (make-fixture))
    (define t0 (now))
    (define state (make-visited-driver fx))
    (define t-loaded (now))
    (define t-load0 (now))
    (driver-eval! state load-file-aloe-datum)
    (define t-load1 (now))
    (define t-step0 (now))
    (driver-eval! state step-method-datum)
    (define t-step1 (now))
    (define t-def0 (now))
    (driver-eval! state loop-class-datum)
    (define t-def1 (now))
    (define t-eval0 (now))
    (driver-eval! state run-loop-datum)
    (define t-eval1 (now))
    (printf "B (Aloe loop, one driver-eval!, no driver-prepare!): load+visit ~a ms; prompt load of file.aloe ~a ms; define-methods step-fn ~a ms; define AloemacsLoop ~a ms; run eval total ~a ms\n"
            (r2 (- t-loaded t0))
            (r2 (- t-load1 t-load0))
            (r2 (- t-step1 t-step0))
            (r2 (- t-def1 t-def0))
            (r2 (- t-eval1 t-eval0)))
    (printf "  B first iteration: eval start->first columns call (parse+typecheck of loop send) ~a ms; eval start->first key return ~a ms; first columns->first key return ~a ms\n"
            (r2 (- ((fixture-first-columns fx)) t-eval0))
            (r2 (- ((fixture-first-key-return fx)) t-eval0))
            (r2 (- ((fixture-first-key-return fx)) ((fixture-first-columns fx)))))
    (gap-report "B gaps" fx)
    (printf "  B quit after loop: ~a\n" (driver-eval! state '(aloemacs-editor quit)))
    fx)

  ;; Rigid-H attempt: the whole loop body inside an explicit-constructors
  ;; class, whose bodies are checked once at definition with H rigid. The
  ;; session is a parameter. Rejected by the checker at the first host send
  ;; inside handle-event: unknown message: kind. ensure-visible, frame, and
  ;; quit alone are accepted under rigid H; handle-event is not.
  (define body-in-class-datum
    '(define-class (AloemacsMainC H)
       (constructors
         (MainC (fields (tag Int))))
       (methods
         (run (s (AloemacsSession H)) (AloemacsSession H)
           (let ((columns (term columns)))
             (let ((rows (term rows)))
               (let ((fitted (s ensure-visible columns rows)))
                 (let ((recorded (fitted record-pictures columns rows)))
                   (let ((written (term write (recorded frame columns rows))))
                     (let ((next (recorded handle-event (term read-event))))
                       (if (next quit)
                           next
                           (self run next))))))))))))

  (define (try-rigid-H)
    (define fx (make-fixture))
    (define state (make-visited-driver fx))
    (driver-eval! state load-file-aloe-datum)
    (define t0 (now))
    (define outcome
      (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
        (driver-eval! state body-in-class-datum)
        'accepted))
    (printf "Rigid-H encoding (loop body inside explicit-constructors class): ~a ms -> ~s\n"
            (r2 (- (now) t0)) outcome))

  ;; -------------------------------------------------------------------- C

  (define (run-C)
    (define fx (make-fixture))
    (define t0 (now))
    (define state (make-visited-driver fx))
    (define t-loaded (now))
    (let loop ()
      (define columns (driver-eval! state '(term columns)))
      (define rows (driver-eval! state '(term rows)))
      (driver-eval! state `(define aloemacs-editor
                             (aloemacs-editor ensure-visible ,columns ,rows)))
      (driver-eval! state `(define aloemacs-editor
                             (aloemacs-editor record-pictures ,columns ,rows)))
      (driver-eval! state `(term write (aloemacs-editor frame ,columns ,rows)))
      (driver-eval! state '(define aloemacs-editor
                             (aloemacs-editor handle-event (term read-event))))
      (unless (driver-eval! state '(aloemacs-editor quit))
        (loop)))
    (define t1 (now))
    (printf "C (per-key driver-eval!, no driver-prepare!): load+visit ~a ms; loop total ~a ms\n"
            (r2 (- t-loaded t0)) (r2 (- t1 t-loaded)))
    (gap-report "C gaps" fx)
    fx)

  ;; -------------------------------------------------------------- compare

  (define (same-output? label fx-a fx-b)
    (define ba ((fixture-bytes fx-a)))
    (define bb ((fixture-bytes fx-b)))
    (define ea ((fixture-events fx-a)))
    (define eb ((fixture-events fx-b)))
    (printf "  ~a: bytes identical? ~a (~a vs ~a bytes); event order identical? ~a (~a vs ~a events); keys consumed ~a/~a; remaining ~s/~s\n"
            label
            (bytes=? ba bb) (bytes-length ba) (bytes-length bb)
            (equal? ea eb) (length ea) (length eb)
            ((fixture-key-calls fx-a)) ((fixture-key-calls fx-b))
            ((fixture-remaining fx-a)) ((fixture-remaining fx-b))))

  (define (expected-events? fx)
    (define events ((fixture-events fx)))
    (define expected
      (append-map
       (lambda (key)
         (list '(columns 20) '(rows 8) 'write 'flush (list 'key key)))
       keys))
    (equal? events expected))

  ;; ----------------------------------------------------------------- main

  (printf "keys: ~a down then escape; size ~a; machine: ~a\n\n"
          key-count size (system-type 'machine))

  (try-rigid-H)
  (newline)

  (define rounds 3)
  (define results
    (for/list ([round (in-range rounds)])
      (printf "=== round ~a ===\n" (add1 round))
      (collect-garbage)
      (define a (run-A))
      (collect-garbage)
      (define b (run-B))
      (collect-garbage)
      (define c (run-C))
      (same-output? "A vs B" a b)
      (same-output? "A vs C" a c)
      (printf "  A events match the expected per-key order? ~a; B? ~a; C? ~a\n"
              (expected-events? a) (expected-events? b) (expected-events? c))
      (newline)
      (list a b c)))

  (printf "=== medians across rounds (ms) ===\n")
  (for ([label '("A" "B" "C")] [index (in-range 3)])
    (define medians
      (for/list ([round (in-list results)])
        (r2 (median ((fixture-gaps (list-ref round index)))))))
    (printf "~a: ~a\n" label medians)))
