#lang racket/base

(require rackunit
         compiler/module-suffix
         racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         "../../bin/suite-time.rkt")

(define-runtime-path report-module "../../bin/suite-time.rkt")
(define stamp "2026-10-07T12:00:00Z")
(define old-stamp "2026-10-06T12:00:00Z")

(define (fixture thunk)
  (define root (make-temporary-file "suite-time~a" 'directory "/tmp"))
  (dynamic-wind
    (lambda () (make-directory (build-path root "tests")))
    (lambda () (thunk root))
    (lambda () (delete-directory/files root))))

(define (put root path source)
  (define target (build-path root path))
  (make-directory* (path-only target))
  (call-with-output-file target (lambda (out) (display source out)) #:exists 'truncate)
  target)

(define (history root) (build-path root ".suite-time" "previous.rktd"))
(define (row path seconds [code 0] [bytecode 'warm])
  (file-result path seconds code (if (zero? code) 'PASS 'FAIL) bytecode))
(define (record rows [timestamp stamp])
  (make-record timestamp (version) (map file-result-path rows) rows))
(define (fake-runner rows [visit void])
  (define remaining rows)
  (lambda (root path #:out out #:err err)
    (visit root path)
    (define next (car remaining))
    (set! remaining (cdr remaining))
    next))
(define (tick-clock . values)
  (define remaining values)
  (lambda () (begin0 (car remaining) (set! remaining (cdr remaining)))))
(define (captured-run root #:runner [runner run-child]
                      #:record-path [record-path (history root)]
                      #:clock [clock (tick-clock 10.0 20.0)])
  (define out (open-output-string))
  (define err (open-output-string))
  (define code (run-report #:root root #:record-path record-path #:runner runner
                           #:clock clock #:timestamp (lambda () stamp)
                           #:out out #:err err))
  (values code (get-output-string out) (get-output-string err)))
(define (datum path)
  (call-with-input-file path read))
(define (save-datum path v)
  (make-directory* (path-only path))
  (call-with-output-file path (lambda (out) (write v out)) #:exists 'truncate))

(test-case "import is inert, even with a suite beside it"
  (fixture
   (lambda (root)
     (put root "tests/trap.rkt" "#lang racket/base\n(error 'trap \"must not run\")\n")
     (define out (open-output-string))
     (define err (open-output-string))
     (parameterize ([current-directory root]
                    [current-namespace (make-base-namespace)]
                    [current-output-port out] [current-error-port err])
       (dynamic-require report-module #f))
     (check-equal? (get-output-string out) "")
     (check-equal? (get-output-string err) "")
     (check-false (directory-exists? (build-path root ".suite-time")))
     (check-equal? (map path->string (directory-list (build-path root "tests"))) '("trap.rkt")))))

(test-case "discovery matches depth-first directory traversal and installed suffixes"
  (fixture
   (lambda (root)
     (define files '("tests/z.rkt" "tests/a/top.rkt" "tests/a/sub.rkt"
                    "tests/a/zero.ss" "tests/.hidden.rkt" "tests/a/note.txt"
                    "tests/.directory/visible.rkt" "tests/upper.RKT"))
     (for ([file (in-list files)]) (put root file "#lang racket/base\n"))
     (make-directory (build-path root "tests" "directory.rkt"))
     (define expected
       (list "tests/.directory/visible.rkt" "tests/a/sub.rkt" "tests/a/top.rkt"
             "tests/a/zero.ss" "tests/upper.RKT" "tests/z.rkt"))
     (check-equal? (map (lambda (p) (path->string (find-relative-path root p)))
                        (discover-suite root)) expected)
     ;; Test all suffixes known to the installed recognition function.
     (for ([suffix (in-list (get-module-suffixes))])
       (put root (format "tests/suffix.~a" suffix) "#lang racket/base\n"))
     (check-equal? (length (discover-suite root))
                   (+ (length expected) (length (get-module-suffixes)))))))

(test-case "info.rkt anywhere aborts discovery before any child and preserves history"
  (fixture
   (lambda (root)
     (put root "tests/a.rkt" "#lang racket/base\n")
     (put root "tests/z/.hidden/info.rkt" "#lang info\n")
     (save-datum (history root) (record '()))
     (define before (file->bytes (history root)))
     (define calls 0)
     (define-values (code out err)
       (captured-run root #:runner
                     (fake-runner (list (row "tests/a.rkt" 1))
                                  (lambda args (set! calls (add1 calls))))))
     (check-equal? code 1)
     (check-equal? calls 0)
     (check-regexp-match #rx"unsupported discovery: info.rkt" err)
     (check-equal? out "")
     (check-equal? (file->bytes (history root)) before))))

(test-case "compiler logging preserves other topics and recognizes all installed events"
  (define-values (setting reliable?)
    (compiler-logging "warning debug@fixture none@compiler/cm info@another"))
  (check-true reliable?)
  (check-equal? setting "warning debug@fixture info@another info@compiler/cm")
  (define-values (default default-reliable?) (compiler-logging #f))
  (check-equal? default "error info@compiler/cm")
  (check-true default-reliable?)
  (define-values (invalid invalid-reliable?) (compiler-logging "unrecognized"))
  (check-false invalid-reliable?)
  (for ([event '(start-compile start-recompile start-touch)])
    (check-equal? (compiler-event (string->bytes/utf-8
                                  (format "compiler/cm:   | ~a: /tmp/dependency.rkt\r\n" event)))
                  'rebuilt))
  (for ([event '(locking finish-compile finish-recompile finish-touch already-done)])
    (check-equal? (compiler-event (string->bytes/utf-8
                                  (format "compiler/cm: ~a: /tmp/dependency.rkt\n" event)))
                  'observed))
  (check-equal? (compiler-event #"compiler/cm: future-event: /tmp/dep.rkt\n") 'unknown)
  (check-equal? (compiler-event #"compiler/cm: malformed\n") 'unknown)
  (check-false (compiler-event #"ordinary failure diagnostic\r\n"))
  (check-equal? (overall-bytecode '(warm warm)) 'warm)
  (check-equal? (overall-bytecode '(warm unknown)) 'unknown)
  (check-equal? (overall-bytecode '(unknown rebuilt)) 'rebuilt))

(test-case "real children are serial, preserve command arguments, and continue after failure"
  (fixture
   (lambda (root)
     (define (source name fail?)
       (format #<<SOURCE
#lang racket/base
(require rackunit raco/testing)
(define lock "../active")
(make-directory lock)
(call-with-output-file "../events" (lambda (out) (displayln '~a out)) #:exists 'append)
(check-equal? (getenv "TMPDIR") "/tmp")
(check-equal? (path->string (current-test-invocation-directory)) ~s)
(sleep 0.02)
(delete-directory lock)
(call-with-output-file "../events" (lambda (out) (displayln '~a-done out)) #:exists 'append)
(check-true ~s)
SOURCE
               name (path->string (path->directory-path root)) name (not fail?)))
     (put root "tests/a bad test.rkt" (source 'a #t))
     (put root "tests/b.rkt" (string-append "#lang racket/base\n(module+ test\n"
                                         (substring (source 'b #f) (string-length "#lang racket/base\n"))
                                         ")\n"))
     (put root "tests/c-zero.rkt" "#lang racket/base\n(displayln \"99999 tests failed (only text)\")\n")
     (define launches '())
     (define (launch . args)
       (set! launches
             (append launches
                     (list (list args (current-directory) (getenv "TMPDIR") (getenv "PLTSTDERR")))))
       (apply subprocess args))
     (define (runner root path #:out out #:err err)
       (run-child root path #:out out #:err err #:launch launch))
     (define-values (code out err) (captured-run root #:runner runner))
     (check-equal? code 1)
     (check-regexp-match #rx"FAILURE" err)
     (check-regexp-match #rx"99999 tests failed" out)
     (check-equal? (file->lines (build-path root "events")) '("a" "a-done" "b" "b-done"))
     (check-false (directory-exists? (build-path root "active")))
     (check-equal? (length launches) 3)
     (for ([launch (in-list launches)] [path (in-list (discover-suite root))])
       (define args (car launch))
       (check-equal? (take args 3) '(#f #f #f))
       (check-true (path? (list-ref args 3)))
       (check-equal? (drop args 4) (list "test" "-y" "--process" "--" (path->string path)))
       (check-equal? (list-ref launch 1) (path->directory-path root))
       (check-equal? (list-ref launch 2) "/tmp")
       (check-regexp-match #rx"info@compiler/cm" (list-ref launch 3)))
     (define saved (datum (history root)))
     (check-equal? (map (lambda (r) (hash-ref r 'exit-code)) (hash-ref saved 'files)) '(1 0 0))
     (check-equal? (map (lambda (r) (hash-ref r 'result)) (hash-ref saved 'files)) '(FAIL PASS PASS))
     (check-regexp-match #rx"Files: 2 passed, 1 failed" out))))

(test-case "ample output drains concurrently and preserves bytes and final fragments"
  (fixture
   (lambda (root)
     (define path
       (put root "tests/output.rkt" #<<SOURCE
#lang racket/base
(define a (thread (lambda () (write-bytes (make-bytes 180000 79)) (display "\r\nOUT-tail"))))
(define b (thread (lambda () (write-bytes (make-bytes 180000 69) (current-error-port))
                            (display "\r\nERR-tail" (current-error-port)))))
(thread-wait a)
(thread-wait b)
SOURCE
            ))
     (define out (open-output-bytes))
     (define err (open-output-bytes))
     (define result (run-child root path #:out out #:err err #:clock (tick-clock 2.0 3.23456789)))
     (check-equal? (file-result-exit-code result) 0)
     (check-equal? (file-result-seconds result) (- 3.23456789 2.0))
     (define expected-out (bytes-append (make-bytes 180000 79) #"\r\nOUT-tail"))
     (define actual-out (get-output-bytes out))
     (check-equal? (subbytes actual-out (- (bytes-length actual-out) (bytes-length expected-out))) expected-out)
     (check-equal? (get-output-bytes err) (bytes-append (make-bytes 180000 69) #"\r\nERR-tail")))))

(test-case "actual compilation in launcher and spawned process, warm repeat, and edited outside dependency"
  (fixture
   (lambda (root)
     (put root "static.rkt" "#lang racket/base\n(provide v)\n(define v 1)\n")
     (put root "runtime.rkt" "#lang racket/base\n(provide v)\n(define v 2)\n")
     ;; The launcher probes test submodules and compiles this static dependency
     ;; before spawning the test process. No runtime loads can mask that proof.
     (define launcher-only
       (put root "tests/launcher.rkt"
            "#lang racket/base\n(require rackunit \"../static.rkt\")\n(module+ test (check-equal? v 1))\n"))
     (define (launcher-run)
       (run-child root launcher-only #:out (open-output-string) #:err (open-output-string)))
     (check-equal? (file-result-bytecode (launcher-run)) 'rebuilt)
     (check-equal? (file-result-bytecode (launcher-run)) 'warm)
     (define path
       (put root "tests/compiler.rkt" #<<SOURCE
#lang racket/base
(require rackunit "../static.rkt")
(module+ test
  (check-equal? v 1)
  (check-true (positive? (dynamic-require "../runtime.rkt" 'v))))
SOURCE
            ))
     (define (run)
       (define out (open-output-string))
       (define err (open-output-string))
       (define r (run-child root path #:out out #:err err))
       (check-equal? (file-result-exit-code r) 0 (get-output-string err))
       (check-equal? (get-output-string err) "")
       (file-result-bytecode r))
     (check-false (file-exists? (build-path root "compiled" "runtime_rkt.zo")))
     (check-equal? (run) 'rebuilt)
     (check-true (file-exists? (build-path root "compiled" "static_rkt.zo")))
     (check-true (file-exists? (build-path root "compiled" "runtime_rkt.zo")))
     (check-equal? (run) 'warm)
     ;; Delete only temporary runtime bytecode. Its dynamic-require happens in
     ;; the test process, so this independently proves downstream telemetry.
     (delete-file (build-path root "compiled" "runtime_rkt.zo"))
     (check-equal? (run) 'rebuilt)
     (check-equal? (run) 'warm)
     (put root "runtime.rkt" "#lang racket/base\n(provide v)\n(define v 23)\n")
     (file-or-directory-modify-seconds (build-path root "compiled" "runtime_rkt.zo")
                                      (- (current-seconds) 5))
     (check-equal? (run) 'rebuilt)
     (check-equal? (run) 'warm))))

(test-case "unknown compiler output is retained, ordinary logs and diagnostics survive"
  (fixture
   (lambda (root)
     (define path
       (put root "tests/unknown.rkt" #<<SOURCE
#lang racket/base
(require racket/logging)
(define-logger fixture)
(log-fixture-info "ordinary topic message")
(display "ordinary diagnostic\r\n" (current-error-port))
(display "compiler/cm: future-event: /tmp/dependency.rkt\n" (current-error-port))
SOURCE
            ))
     (define env (environment-variables-copy (current-environment-variables)))
     (environment-variables-set! env #"PLTSTDERR" #"error info@fixture none@compiler/cm")
     (define (run)
       (define err (open-output-string))
       (define r
         (parameterize ([current-environment-variables env])
           (run-child root path #:out (open-output-string) #:err err)))
       (check-equal? (file-result-exit-code r) 0)
       (check-regexp-match #rx"fixture: ordinary topic message" (get-output-string err))
       (check-regexp-match #rx"ordinary diagnostic\r\n" (get-output-string err))
       (check-regexp-match #rx"compiler/cm: future-event" (get-output-string err))
       (check-regexp-match #rx"compiler observation incomplete or unfamiliar" (get-output-string err))
       r)
     (check-equal? (file-result-bytecode (run)) 'rebuilt)
     (check-equal? (file-result-bytecode (run)) 'unknown))))

(test-case "failed tests retain observed bytecode work"
  (fixture
   (lambda (root)
     (define path (put root "tests/broken.rkt" "#lang racket/base\n(require rackunit)\n(check-equal? 1 2)\n"))
     (define err (open-output-string))
     (define r (run-child root path #:out (open-output-string) #:err err))
     (check-equal? (file-result-exit-code r) 1)
     (check-equal? (file-result-result r) 'FAIL)
     (check-equal? (file-result-bytecode r) 'rebuilt)
     (check-regexp-match #rx"FAILURE" (get-output-string err)))))

(test-case "table uses unrounded ordering, path ties, signed deltas and explicit old labels"
  (define current
    (record (list (row "tests/b.rkt" 1.0001 7 'unknown)
                  (row "tests/a.rkt" 1.0001)
                  (row "tests/z.rkt" 1.0002 0 'rebuilt)
                  (row "tests/full path with spaces.rkt" 0.5))))
  (define previous
    (record (list (row "tests/a.rkt" 1.2 1 'rebuilt)
                  (row "tests/b.rkt" 0.8 0 'unknown)
                  (row "tests/z.rkt" 1.0001)) old-stamp))
  (define out (open-output-string))
  (print-report current previous #f out)
  (define rendered (get-output-string out))
  (check-regexp-match (regexp (regexp-quote (string-append "Suite time: " stamp))) rendered)
  (check-regexp-match (regexp (regexp-quote (string-append "Racket: " (version)))) rendered)
  (check-regexp-match #rx"Serial command: TMPDIR=/tmp raco test -y --process -- <file>" rendered)
  (check-regexp-match #rx"Bytecode: rebuilt" rendered)
  (check-regexp-match (regexp (regexp-quote (string-append "Previous: " old-stamp "; bytecode: rebuilt"))) rendered)
  (define table (filter (lambda (line) (string-contains? line " | tests/")) (string-split rendered "\n")))
  (check-equal? table
                '("1.000 | PASS | rebuilt | 1.000 | PASS | warm | +0.000 | tests/z.rkt"
                  "1.000 | PASS | warm | 1.200 | FAIL | rebuilt | -0.200 | tests/a.rkt"
                  "1.000 | FAIL | unknown | 0.800 | PASS | unknown | +0.200 | tests/b.rkt"
                  "0.500 | PASS | warm | — | — | — | — | tests/full path with spaces.rkt"))
  (check-regexp-match #rx"Seconds \\| Result \\| Bytecode \\| Previous[(]s[)] \\| Previous result \\| Previous bytecode \\| Delta[(]s[)] \\| File" rendered)
  (check-equal? (hash-ref (cadr (hash-ref current 'files)) 'seconds) 1.0001))

(test-case "first and second completed reports have truthful comparisons and footer"
  (fixture
   (lambda (root)
     (for ([path '("tests/a.rkt" "tests/b.rkt")]) (put root path "#lang racket/base\n"))
     (define-values (first out1 err1)
       (captured-run root #:runner (fake-runner (list (row "tests/a.rkt" 1.125 0 'rebuilt)
                                                     (row "tests/b.rkt" 2.5)))))
     (check-equal? first 0)
     (check-equal? err1 "")
     (check-regexp-match #rx"Comparison unavailable: first run" out1)
     (check-regexp-match #rx"— \\| — \\| — \\| — \\| tests/a.rkt" out1)
     (check-regexp-match #rx"Files: 2 passed, 0 failed; sum: 3.625 s; total report wall: 10.000 s" out1)
     (define-values (second out2 err2)
       (captured-run root #:runner (fake-runner (list (row "tests/a.rkt" 0.875 0 'unknown)
                                                     (row "tests/b.rkt" 2.75)))))
     (check-equal? second 0)
     (check-equal? err2 "")
     (check-regexp-match #rx"Previous: .*; bytecode: rebuilt" out2)
     (check-regexp-match #rx"0.875 \\| PASS \\| unknown \\| 1.125 \\| PASS \\| rebuilt \\| -0.250" out2)
     (check-equal? (hash-ref (datum (history root)) 'bytecode) 'unknown)
     (check-equal? (hash-ref (datum (history root)) 'membership) '("tests/a.rkt" "tests/b.rkt")))))

(test-case "validated previous data rejects incompatible or malformed records without evaluation"
  (fixture
   (lambda (root)
     (define path (history root))
     (define good (record (list (row "tests/a.rkt" 1.23456789))))
     (save-datum path good)
     (define-values (loaded reason) (read-previous path))
     (check-equal? loaded good)
     (check-false reason)
     (define bad-records
       (list (cons (hash-set good 'schema 2) #rx"schema")
             (cons (hash-set good 'racket-version "old-version") #rx"Racket version")
             (cons '(run bogus) #rx"malformed")
             (cons (hash-set good 'timestamp "yesterday") #rx"malformed")
             (cons (hash-set good 'membership '("tests/b.rkt")) #rx"malformed")
             (cons (hash-set good 'bytecode 'unknown) #rx"malformed")))
     (define good-row (car (hash-ref good 'files)))
     (define bad-rows
       (list (hash-set good-row 'seconds -1)
             (hash-set good-row 'seconds +nan.0)
             (hash-set good-row 'seconds +inf.0)
             (hash-set good-row 'exit-code 0.0)
             (hash-set good-row 'result 'FAIL)
             (hash-set good-row 'bytecode 'cold)
             (hash-set good-row 'path "/tmp/absolute.rkt")
             (hash-set good-row 'path "../escape.rkt")))
     (for ([entry (in-list (append bad-records
                                   (map (lambda (row) (cons (hash-set good 'files (list row)) #rx"malformed"))
                                        bad-rows)))])
       (save-datum path (car entry))
       (define-values (prior why) (read-previous path))
       (check-false prior)
       (check-regexp-match (cdr entry) why)
       (define out (open-output-string))
       (print-report good prior why out)
       (check-regexp-match #rx"— \\| — \\| — \\| —" (get-output-string out)))
     (for ([source '("(" "#reader racket/base 1" "#lang racket/base\n(error 'bad)" "#0=(#0#)")])
       (put root ".suite-time/previous.rktd" source)
       (define-values (prior why) (read-previous path))
       (check-false prior)
       (check-regexp-match #rx"malformed" why))
     (put root ".suite-time/previous.rktd" (format "~s ~s" good good))
     (define-values (extra why) (read-previous path))
     (check-false extra)
     (check-regexp-match #rx"extra data" why))))

(test-case "aborted execution and interruptions preserve the last completed record"
  (fixture
   (lambda (root)
     (put root "tests/a.rkt" "#lang racket/base\n")
     (put root "tests/b.rkt" "#lang racket/base\n")
     (save-datum (history root) (record '()))
     (define before (file->bytes (history root)))
     (for ([interrupt? '(#f #t)])
       (define calls 0)
       (define (runner root path #:out out #:err err)
         (set! calls (add1 calls))
         (when (= calls 2)
           (if interrupt?
               (raise (exn:break "fixture interruption" (current-continuation-marks)
                                 (let/ec k k)))
               (error 'fixture "operational abort")))
         (row "tests/a.rkt" 1))
       (define-values (code out err) (captured-run root #:runner runner))
       (check-equal? code 1)
       (check-equal? calls 2)
       (check-equal? (file->bytes (history root)) before)
       (check-regexp-match (if interrupt? #rx"interrupted" #rx"operational abort") err)))))

(test-case "staging, formatting and persistence failures preserve history; failures still complete"
  (fixture
   (lambda (root)
     (put root "tests/a.rkt" "#lang racket/base\n")
     (define old (record '()))
     (save-datum (history root) old)
     (define before (file->bytes (history root)))
     (check-exn exn:fail?
                (lambda () (write-record! (history root) (record (list (row "tests/a.rkt" 1)))
                                          #:before-replace (lambda () (error 'fixture "staging abort")))))
     (check-equal? (file->bytes (history root)) before)
     (check-equal? (map path->string (directory-list (path-only (history root)))) '("previous.rktd"))
     ;; At staging time the prior file is still readable and the complete new
     ;; datum is in a sibling. An interruption there also removes the sibling.
     (check-exn
      exn:break?
      (lambda ()
        (write-record!
         (history root) (record (list (row "tests/a.rkt" 1)))
         #:before-replace
         (lambda ()
           (check-equal? (file->bytes (history root)) before)
           (define siblings (directory-list (path-only (history root))))
           (check-equal? (length siblings) 2)
           (define staged (findf (lambda (p) (not (equal? (path->string p) "previous.rktd"))) siblings))
           (check-equal? (datum (build-path (path-only (history root)) staged))
                         (record (list (row "tests/a.rkt" 1))))
           (raise (exn:break "staging interrupted" (current-continuation-marks) (let/ec k k)))))))
     (check-equal? (file->bytes (history root)) before)
     (check-equal? (map path->string (directory-list (path-only (history root)))) '("previous.rktd"))
     (define broken-out (open-output-string))
     (close-output-port broken-out)
     (check-equal? (run-report #:root root #:runner (fake-runner (list (row "tests/a.rkt" 1)))
                              #:out broken-out #:err (open-output-string)) 1)
     (check-equal? (file->bytes (history root)) before)
     (define footer-failure
       (make-output-port
        'footer-failure always-evt
        (lambda (bytes start end non-block? breakable?)
          (when (regexp-match? #rx#"Files:" (subbytes bytes start end))
            (error 'fixture "cannot print footer"))
          (- end start))
        void))
     (define footer-err (open-output-string))
     (check-equal? (run-report #:root root #:runner (fake-runner (list (row "tests/a.rkt" 1)))
                              #:out footer-failure #:err footer-err) 1)
     (check-regexp-match #rx"cannot print footer" (get-output-string footer-err))
     (check-equal? (file->bytes (history root)) before)
     ;; A directory cannot be atomically replaced with a file, even as root.
     (define blocked (build-path root ".suite-time" "blocked.rktd"))
     (make-directory blocked)
     (define-values (code out err)
       (captured-run root #:record-path blocked #:runner (fake-runner (list (row "tests/a.rkt" 1)))))
     (check-equal? code 1)
     (check-true (directory-exists? blocked))
     (check-not-equal? err "")
     (check-equal? (file->bytes (history root)) before)
     (define-values (failed out2 err2)
       (captured-run root #:runner (fake-runner (list (row "tests/a.rkt" 1.23456789 17 'rebuilt)))))
     (check-equal? failed 1)
     (check-equal? err2 "")
     (define saved (datum (history root)))
     (check-equal? (hash-ref (car (hash-ref saved 'files)) 'exit-code) 17)
     (check-equal? (hash-ref (car (hash-ref saved 'files)) 'seconds) 1.23456789)
     (check-equal? (hash-ref saved 'bytecode) 'rebuilt)
     (check-regexp-match #rx"Files: 0 passed, 1 failed" out2))))
