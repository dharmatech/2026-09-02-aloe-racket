#lang racket/base

(require compiler/module-suffix
         racket/date
         racket/file
         racket/format
         racket/list
         racket/math
         racket/path
         racket/port
         racket/string)

;; These operations are also the fixture seams. Importing the module does no I/O.
(provide discover-suite child-arguments compiler-logging compiler-event
         overall-bytecode run-child read-previous make-record write-record!
         print-report run-report
         (struct-out file-result))

(struct file-result (path seconds exit-code result bytecode) #:transparent)
(define schema-version 1)
(define labels '(rebuilt warm unknown))
(define (monotonic-seconds) (/ (current-inexact-monotonic-milliseconds) 1000.0))

(define (discover-suite root)
  (define suffix? (get-module-suffix-regexp))
  (define (walk dir)
    (append-map
     (lambda (name)
       (define path (build-path dir name))
       (cond
         [(directory-exists? path) (walk path)]
         [(equal? (path->string name) "info.rkt")
          (error 'suite-time "unsupported discovery: info.rkt under suite tree: ~a" path)]
         [(and (regexp-match? suffix? path)
               (not (regexp-match? #rx#"^[.]" (path->bytes name))))
          (list path)]
         [else '()]))
     (directory-list dir)))
  ;; Finish discovery (including the info.rkt check) before launching any child.
  (walk (build-path root "tests")))

(define (child-arguments path)
  (list "test" "-y" "--process" "--" (path->string path)))

(define (compiler-logging previous)
  (define tokens (string-split (or previous "error")))
  (define valid?
    (and (pair? tokens)
         (for/and ([token (in-list tokens)])
           (regexp-match? #px"^(none|fatal|error|warning|info|debug)(@[^@\\s]+)?$" token))))
  (define others
    (filter (lambda (token) (not (string-suffix? token "@compiler/cm"))) tokens))
  (values (string-join (append others '("info@compiler/cm")) " ") valid?))

;; stderr's logger rendering is specified by the installed compiler/cm logger.
;; Only known events are consumed; diagnostics and future events pass through.
(define (compiler-event line)
  (define event
    (regexp-match
     #px#"^compiler/cm: [ |]*(locking|start-compile|finish-compile|start-recompile|finish-recompile|start-touch|finish-touch|already-done): [^\r\n]+\r?\n?$"
     line))
  (cond
    [event (if (member (cadr event) '(#"start-compile" #"start-recompile" #"start-touch"))
               'rebuilt 'observed)]
    [(regexp-match? #rx#"^compiler/cm:" line) 'unknown]
    [else #f]))

(define (overall-bytecode classifications)
  (cond [(memq 'rebuilt classifications) 'rebuilt]
        [(memq 'unknown classifications) 'unknown]
        [else 'warm]))

;; Preserve bytes, including a final unterminated line and CRLF diagnostics.
(define (drain-stderr input observe!)
  (define buffer (make-bytes 8192))
  (let loop ([pending #""])
    (define count (read-bytes-avail! buffer input))
    (cond
      [(eof-object? count)
       (unless (zero? (bytes-length pending)) (observe! pending))]
      [else
       (define joined (bytes-append pending (subbytes buffer 0 count)))
       (define remainder
         (let lines ([start 0])
           (define end (for/first ([i (in-range start (bytes-length joined))]
                                  #:when (= (bytes-ref joined i) 10)) i))
           (if end
               (begin (observe! (subbytes joined start (add1 end)))
                      (lines (add1 end)))
               (subbytes joined start))))
       (loop remainder)])))

(define (run-child root path
                   #:out [out (current-output-port)]
                   #:err [err (current-error-port)]
                   #:clock [clock monotonic-seconds]
                   #:launch [launch subprocess])
  (define env (environment-variables-copy (current-environment-variables)))
  (define-values (logging reliable?)
    (compiler-logging (let ([v (environment-variables-ref env #"PLTSTDERR")])
                        (and v (bytes->string/utf-8 v #\?)))))
  (environment-variables-set! env #"TMPDIR" #"/tmp")
  (environment-variables-set! env #"PLTSTDERR" (string->bytes/utf-8 logging))
  (define rebuilt? #f)
  (define unknown? (not reliable?))
  (define (observe! line)
    (case (compiler-event line)
      [(rebuilt) (set! rebuilt? #t)]
      [(observed) (void)]
      [(unknown) (set! unknown? #t) (write-bytes line err) (flush-output err)]
      [else (write-bytes line err) (flush-output err)]))
  (define custodian (make-custodian))
  (dynamic-wind
    void
    (lambda ()
      (parameterize ([current-directory root]
                     [current-environment-variables env]
                     [current-custodian custodian]
                     [subprocess-group-enabled #t]
                     [current-subprocess-custodian-mode 'kill])
        (define raco (or (find-executable-path "raco")
                         (error 'suite-time "cannot find raco")))
        (define start (clock))
        (define-values (child stdout stdin stderr)
          (apply launch #f #f #f raco (child-arguments path)))
        (close-output-port stdin)
        ;; Capture I/O exceptions: a failed drainer must abort, not silently
        ;; save a completed record or strand a child on a full pipe.
        (define io-error (box #f))
        (define (drainer thunk)
          (thread
           (lambda ()
             (with-handlers ([exn? (lambda (e)
                                    (set-box! io-error e)
                                    (subprocess-kill child #t))])
               (thunk)))))
        (define stdout-thread
          (drainer (lambda () (copy-port stdout out) (flush-output out))))
        (define stderr-thread
          (drainer (lambda () (drain-stderr stderr observe!))))
        (subprocess-wait child)
        (thread-wait stdout-thread)
        (thread-wait stderr-thread)
        (when (unbox io-error) (raise (unbox io-error)))
        (define code (subprocess-status child))
        (define seconds (- (clock) start))
        (define label (cond [rebuilt? 'rebuilt] [unknown? 'unknown] [else 'warm]))
        (when unknown?
          (fprintf err "suite-time: ~a: compiler observation incomplete or unfamiliar; ~a\n"
                   path (if rebuilt? "update observed (rebuilt)" "bytecode unknown")))
        (file-result (path->string (find-relative-path root path)) seconds code
                     (if (zero? code) 'PASS 'FAIL) label)))
    (lambda () (custodian-shutdown-all custodian))))

(define (utc-timestamp)
  (parameterize ([date-display-format 'iso-8601])
    (string-append (date->string (seconds->date (current-seconds) #f) #t) "Z")))

(define (result->datum row)
  (hash 'path (file-result-path row) 'seconds (file-result-seconds row)
        'exit-code (file-result-exit-code row) 'result (file-result-result row)
        'bytecode (file-result-bytecode row)))

(define (make-record timestamp racket-version membership rows)
  (hash 'schema schema-version 'timestamp timestamp 'racket-version racket-version
        'bytecode (overall-bytecode (map file-result-bytecode rows))
        'membership membership 'files (map result->datum rows)))

(define (finite-seconds? v)
  (and (real? v) (>= v 0) (not (infinite? v)) (not (nan? v))))
(define (relative-file? v)
  (and (string? v) (positive? (string-length v))
       (relative-path? v)
       (for/and ([part (in-list (explode-path v))]) (path? part))))
(define (valid-row? row)
  (and (hash? row)
       (relative-file? (hash-ref row 'path #f))
       (finite-seconds? (hash-ref row 'seconds #f))
       (exact-nonnegative-integer? (hash-ref row 'exit-code #f))
       (eq? (hash-ref row 'result #f)
            (if (zero? (hash-ref row 'exit-code)) 'PASS 'FAIL))
       (memq (hash-ref row 'bytecode #f) labels)))
(define (valid-record? record)
  (and (hash? record)
       (equal? (hash-ref record 'schema #f) schema-version)
       (string? (hash-ref record 'racket-version #f))
       (let ([stamp (hash-ref record 'timestamp #f)])
         (and (string? stamp)
              (regexp-match? #px"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$" stamp)))
       (list? (hash-ref record 'membership #f))
       (andmap relative-file? (hash-ref record 'membership))
       (list? (hash-ref record 'files #f))
       (andmap valid-row? (hash-ref record 'files))
       (equal? (hash-ref record 'membership)
               (map (lambda (row) (hash-ref row 'path)) (hash-ref record 'files)))
       (= (length (remove-duplicates (hash-ref record 'membership)))
          (length (hash-ref record 'membership)))
       (eq? (hash-ref record 'bytecode #f)
            (overall-bytecode (map (lambda (row) (hash-ref row 'bytecode))
                                   (hash-ref record 'files))))))

(define (read-previous path [racket-version (version)])
  (cond
    [(not (file-exists? path)) (values #f "first run (no previous record)")]
    [else
     (with-handlers ([exn:fail? (lambda (e)
                                (values #f (format "malformed or unreadable previous record: ~a"
                                                   (exn-message e))))])
       (define record
         (call-with-input-file path
           (lambda (in)
             (parameterize ([read-accept-reader #f] [read-accept-lang #f]
                            [read-accept-compiled #f] [read-accept-graph #f])
               (define datum (read in))
               (unless (eof-object? (read in))
                 (error 'suite-time "extra data after previous record"))
               datum))))
       (cond
         [(and (hash? record) (not (equal? (hash-ref record 'schema #f) schema-version)))
          (values #f "incompatible previous record schema")]
         [(not (valid-record? record)) (values #f "malformed previous record")]
         [(not (equal? (hash-ref record 'racket-version) racket-version))
          (values #f "incompatible previous Racket version")]
         [else (values record #f)]))]))

(define (write-record! path record #:before-replace [before-replace void])
  (define directory (path-only path))
  (make-directory* directory)
  (define temporary #f)
  (dynamic-wind
    void
    (lambda ()
      (set! temporary (make-temporary-file "previous~a.rktd" #f directory))
      (call-with-output-file temporary
        (lambda (out) (write record out) (newline out)) #:exists 'truncate)
      (before-replace)
      ;; A break before replacement preserves the previous record. The single
      ;; rename is the commit point; no delete-then-rename window exists.
      (parameterize-break #f (rename-file-or-directory temporary path #t)))
    (lambda ()
      (when (and temporary (file-exists? temporary)) (delete-file temporary)))))

(define (seconds-text seconds) (~r seconds #:precision '(= 3)))
(define (delta-text delta)
  (string-append (if (negative? delta) "" "+") (seconds-text delta)))

(define (print-report record previous reason out)
  (fprintf out "\nSuite time: ~a\nRacket: ~a\nSerial command: TMPDIR=/tmp raco test -y --process -- <file>\nBytecode: ~a\n"
           (hash-ref record 'timestamp) (hash-ref record 'racket-version)
           (hash-ref record 'bytecode))
  (if previous
      (fprintf out "Previous: ~a; bytecode: ~a\n"
               (hash-ref previous 'timestamp) (hash-ref previous 'bytecode))
      (fprintf out "Comparison unavailable: ~a\n" reason))
  (define prior
    (if previous
        (for/hash ([row (in-list (hash-ref previous 'files))])
          (values (hash-ref row 'path) row))
        (hash)))
  (define rows
    (sort (hash-ref record 'files)
          (lambda (a b)
            (define sa (hash-ref a 'seconds))
            (define sb (hash-ref b 'seconds))
            (if (= sa sb) (string<? (hash-ref a 'path) (hash-ref b 'path)) (> sa sb)))))
  (displayln "Seconds | Result | Bytecode | Previous(s) | Previous result | Previous bytecode | Delta(s) | File" out)
  (for ([row (in-list rows)])
    (define old (hash-ref prior (hash-ref row 'path) #f))
    (fprintf out "~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a\n"
             (seconds-text (hash-ref row 'seconds)) (hash-ref row 'result)
             (hash-ref row 'bytecode)
             (if old (seconds-text (hash-ref old 'seconds)) "—")
             (if old (hash-ref old 'result) "—")
             (if old (hash-ref old 'bytecode) "—")
             (if old (delta-text (- (hash-ref row 'seconds) (hash-ref old 'seconds))) "—")
             (hash-ref row 'path))))

(define (run-report #:root [root (current-directory)]
                    #:record-path [record-path (build-path root ".suite-time" "previous.rktd")]
                    #:runner [runner run-child]
                    #:clock [clock monotonic-seconds]
                    #:timestamp [timestamp utc-timestamp]
                    #:out [out (current-output-port)]
                    #:err [err (current-error-port)])
  (with-handlers ([exn:break? (lambda (e) (fprintf err "suite-time: interrupted\n") 1)]
                  [exn:fail? (lambda (e) (fprintf err "suite-time: ~a\n" (exn-message e)) 1)])
    (define start (clock))
    (define project-root (path->complete-path root))
    (define history-path (path->complete-path record-path))
    (define stamp (timestamp))
    (define-values (previous reason) (read-previous history-path))
    (define paths (discover-suite project-root))
    (define rows
      (for/list ([path (in-list paths)])
        (runner project-root path #:out out #:err err)))
    (define membership
      (map (lambda (path) (path->string (find-relative-path project-root path))) paths))
    (define record (make-record stamp (version) membership rows))
    (unless (valid-record? record) (error 'suite-time "invalid report results"))
    (print-report record previous reason out)
    (flush-output out)
    (define passed (count (lambda (row) (eq? (file-result-result row) 'PASS)) rows))
    (write-record!
     history-path record
     #:before-replace
     (lambda ()
       (fprintf out "Files: ~a passed, ~a failed; sum: ~a s; total report wall: ~a s\n"
                passed (- (length rows) passed)
                (seconds-text (apply + (map file-result-seconds rows)))
                (seconds-text (- (clock) start)))
       (flush-output out)))
    (if (= passed (length rows)) 0 1)))

(module+ main
  (unless (zero? (vector-length (current-command-line-arguments)))
    (raise-user-error 'suite-time "this command accepts no arguments"))
  (exit (run-report)))
