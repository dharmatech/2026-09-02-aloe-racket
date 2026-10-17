#lang racket/base
;; Stack-safety probe for a recursive Aloe loop in the Gel shape.
;; Scratch program from the 2026-10-17 host runner discussion; not a test.
;;   racket loop-stack.rkt <tail|nontail> <N> [<N> ...]
;; Each N runs in this process in sequence; a major GC separates runs.
;; Needs the optional tui-term package (host/racket/term.rkt requires it).

(require racket/port
         "../../../aloe/driver.rkt"
         "../../../host/racket/term.rkt")

(module+ main
  (define mode (string->symbol (vector-ref (current-command-line-arguments) 0)))
  (define sizes
    (for/list ([arg (in-vector (current-command-line-arguments) 1)])
      (string->number arg)))

  ;; Guard: shut the process down instead of thrashing if something explodes.
  (custodian-limit-memory (current-custodian) (* 12 1024 1024 1024))

  ;; The term double. `remaining` is reset before each run: the reader returns
  ;; "x" for N-1 calls and "q" on the Nth call. Output is discarded.
  (define remaining (box 0))
  (define read-calls (box 0))
  (define (reader)
    (set-box! read-calls (add1 (unbox read-calls)))
    (define r (unbox remaining))
    (set-box! remaining (sub1 r))
    (if (<= r 1) "q" "x"))
  (define term
    (make-term-receiver (open-output-nowhere) reader (lambda () (values 80 24))))

  (define state (make-driver))
  (driver-inject-host! state 'term term)

  ;; `loop` is the Gel shape: write, read-key, nested let, if, tail self-send.
  ;; `loop-nontail` puts the recursive send in argument position of a `+`.
  (driver-eval!
   state
   '(define-class Looper
      (fields (count Int))
      (methods
        (loop (n Int) Int
          (let ((key (term read-key)))
            (let ((written (term write-line key)))
              (if (key = "q")
                  n
                  (self loop (n + 1))))))
        (loop-nontail (n Int) Int
          (let ((key (term read-key)))
            (let ((written (term write-line key)))
              (if (key = "q")
                  n
                  ((self loop-nontail (n + 1)) + 0))))))))

  (define (mb bytes) (/ (round (/ bytes 10485.76)) 100.0))

  (define (perf-stats)
    (define v (make-vector 12 0))
    (vector-set-performance-stats! v)
    v)

  (define (run-once n)
    (set-box! remaining n)
    (set-box! read-calls 0)
    (collect-garbage)
    (collect-garbage)
    (define mem0 (current-memory-use))
    (define cum0 (current-memory-use 'cumulative))
    (define stats0 (perf-stats))
    (define gc-ms0 (current-gc-milliseconds))
    ;; Sample current-memory-use while the loop runs to approximate the peak.
    (define peak (box mem0))
    (define sampler
      (thread
       (lambda ()
         (let poll ()
           (define m (current-memory-use))
           (when (> m (unbox peak)) (set-box! peak m))
           (sleep 0.001)
           (poll)))))
    (define selector (if (eq? mode 'tail) 'loop 'loop-nontail))
    (define t0 (current-inexact-milliseconds))
    (define result
      (driver-eval! state `((Looper new 0) ,selector 0)))
    (define t1 (current-inexact-milliseconds))
    (define mem-raw (current-memory-use))
    (define gc-ms1 (current-gc-milliseconds))
    (define stats-run (perf-stats))
    (define cum1 (current-memory-use 'cumulative))
    (kill-thread sampler)
    (collect-garbage)
    (collect-garbage)
    (define mem-gc (current-memory-use))
    (define stats1 (perf-stats))
    (define elapsed (- t1 t0))
    (printf "mode=~a N=~a result=~a read-calls=~a\n" mode n result (unbox read-calls))
    (printf "  wall ms            ~a   (~a ms/iter)\n"
            (/ (round (* 10 elapsed)) 10.0)
            (/ (round (* 1000 (/ elapsed n))) 1000.0))
    (printf "  gc ms during run   ~a\n" (- gc-ms1 gc-ms0))
    (printf "  gc count           ~a\n" (- (vector-ref stats-run 3) (vector-ref stats0 3)))
    (printf "  mem before (MB)    ~a   [post-GC]\n" (mb mem0))
    (printf "  mem after raw (MB) ~a   [no GC yet]\n" (mb mem-raw))
    (printf "  mem after GC (MB)  ~a   delta vs before ~a MB\n" (mb mem-gc) (mb (- mem-gc mem0)))
    (printf "  sampled peak (MB)  ~a   delta vs before ~a MB\n" (mb (unbox peak)) (mb (- (unbox peak) mem0)))
    (printf "  peak-before-GC stat slot 11 (MB)  ~a\n" (mb (vector-ref stats1 11)))
    (printf "  allocated during run (MB) ~a   (~a bytes/iter)\n"
            (mb (- cum1 cum0)) (round (/ (- cum1 cum0) n)))
    (printf "  internal stack overflows stat slot 5: before ~a after ~a\n"
            (vector-ref stats0 5) (vector-ref stats-run 5))
    (flush-output))

  (for ([n (in-list sizes)])
    (run-once n)))
