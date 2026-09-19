#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         (prefix-in lsp: "../../../aloe/lsp.rkt")
         (prefix-in support:
                    (submod "../../../aloe/lsp.rkt" test-support))
         (prefix-in query: "../../../aloe/expression-query.rkt"))

(define-runtime-path lsp-module-path "../../../aloe/lsp.rkt")

(define (frame message)
  (define body (jsexpr->bytes message))
  (bytes-append
   (string->bytes/utf-8
    (format "Content-Length: ~a\r\n\r\n" (bytes-length body)))
   body))

(define (decode-frames framed-bytes)
  (define input (open-input-bytes framed-bytes))
  (let loop ([messages '()])
    (define header (read-bytes-line input 'any))
    (if (eof-object? header)
        (reverse messages)
        (let ()
          (define match
            (regexp-match #rx#"^Content-Length: ([0-9]+)$" header))
          (check-not-false match "response starts with a canonical header")
          (define declared-length
            (string->number (bytes->string/utf-8 (second match))))
          (check-equal? (read-bytes-line input 'any) #"")
          (define body (read-bytes declared-length input))
          (check-true (bytes? body))
          (check-equal? (bytes-length body) declared-length)
          (loop (cons (bytes->jsexpr body) messages))))))

(define initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync (hasheq 'openClose #t 'change 1)
    'hoverProvider #t
    'completionProvider
    (hasheq 'triggerCharacters (list " ")))
   'serverInfo (hasheq 'name "aloe-lsp")))

(define (initialize-message [id "initialize"])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "initialize"
   'params (hasheq)))

(define initialized-message
  (hasheq
   'jsonrpc "2.0"
   'method "initialized"
   'params (hasheq)))

(define (open-message uri text [version 1])
  (hasheq
   'jsonrpc "2.0"
   'method "textDocument/didOpen"
   'params
   (hasheq
    'textDocument
    (hasheq
     'uri uri
     'languageId "aloe"
     'version version
     'text text))))

(define (change-message uri text version)
  (hasheq
   'jsonrpc "2.0"
   'method "textDocument/didChange"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri 'version version)
    'contentChanges (list (hasheq 'text text)))))

(define (hover-message uri line character id)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/hover"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri)
    'position (hasheq 'line line 'character character))))

(define (shutdown-message [id "shutdown"])
  (hasheq 'jsonrpc "2.0" 'id id 'method "shutdown"))

(define exit-message
  (hasheq 'jsonrpc "2.0" 'method "exit"))

(define (success-response id result)
  (hasheq 'jsonrpc "2.0" 'id id 'result result))

(define (request-failed-response id message)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'error
   (hasheq
    'code -32803
    'message message)))

(define (generic-failure-response id)
  (request-failed-response id "unable to produce hover result"))

(define (snapshot-failure-response id)
  (request-failed-response
   id
   "unable to create synchronized document snapshot"))

(struct exchange
  (status input output error responses query-calls query-arguments)
  #:transparent)

(define (run-messages messages
                      #:query [query (lambda (_path _position) #f)]
                      #:public? [public? #f])
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define calls 0)
  (define arguments '())
  (define (counting-query path position)
    (set! calls (add1 calls))
    (set! arguments (append arguments (list (list path position))))
    (query path position))
  (define status
    (if public?
        (lsp:run-lsp-server input output error-output)
        (support:run-lsp-server/with-query
         input output error-output counting-query)))
  (exchange status
            input
            output
            error-output
            (decode-frames (get-output-bytes output))
            calls
            arguments))

(define (check-open-ports result)
  (for ([port
         (in-list
          (list (exchange-input result)
                (exchange-output result)
                (exchange-error result)))])
    (check-false (port-closed? port))))

(define (check-exchange result expected-responses expected-calls)
  (check-equal? (exchange-status result) 0)
  (check-equal? (exchange-responses result) expected-responses)
  (check-equal? (exchange-query-calls result) expected-calls)
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (check-open-ports result))

(define (path-uri path)
  (url->string (path->url path)))

(define (normalized path)
  (simplify-path (path->complete-path path) #f))

(define (directory-entry-paths directory)
  (sort
   (for/list ([entry (in-list (directory-list directory))])
     (path->string (normalized (build-path directory entry))))
   string<?))

(define (write-exact-bytes path bytes)
  (call-with-output-file
   path
   #:exists 'truncate/replace
   (lambda (output)
     (check-equal? (write-bytes bytes output) (bytes-length bytes))
     (flush-output output))))

(define (call-with-test-directory procedure)
  (define directory
    (make-temporary-file "aloe-lsp-008-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (procedure (normalized directory)))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define row-a
  (query:signature-spec 'first '(Int) 'String))

(define row-b
  (query:signature-spec 'first '(String) 'Bool))

(define (stub-result [signatures (list row-a row-b)]
                     [position 1]
                     [span 2]
                     [type '(Injected Type)])
  (query:expression-query-result
   type
   signatures
   (srcloc 'private-source-008 800 80 position span)))

(define expected-stub-hover
  (hasheq
   'contents
   (hasheq
    'kind "plaintext"
    'value
    (string-append
     "type: (Injected Type)\n"
     "messages:\n"
     "  first : (Int) -> String\n"
     "  first : (String) -> Bool"))
   'range
   (hasheq
    'start (hasheq 'line 0 'character 0)
    'end (hasheq 'line 0 'character 2))))

(define (standard-prefix uri text)
  (list
   (initialize-message)
   initialized-message
   (open-message uri text)))

(define standard-initialize-response
  (success-response "initialize" initialize-result))

(define standard-shutdown-response
  (success-response "shutdown" (json-null)))

(define (protocol-text result)
  (bytes->string/utf-8 (get-output-bytes (exchange-output result))))

(test-case "direct malformed result is generic and the same document recovers"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "unchanged.aloe"))
     (define text "abcdef")
     (define bytes (string->bytes/utf-8 text))
     (write-exact-bytes path bytes)
     (define original-entries (directory-entry-paths directory))
     (define uri (path-uri path))
     (define result-number 808008)
     (define calls 0)
     (define result
       (run-messages
        (append
         (standard-prefix uri text)
         (list
          (hover-message uri 0 0 "bad-direct")
          (hover-message uri 0 0 208)
          (shutdown-message)
          exit-message))
        #:query
        (lambda (query-path query-position)
          (set! calls (add1 calls))
          (check-equal? (normalized query-path) (normalized path))
          (check-equal? query-position 1)
          (check-equal? (file->bytes query-path) bytes)
          (check-equal? (directory-entry-paths directory) original-entries)
          (if (= calls 1) result-number (stub-result)))))
     (check-exchange
      result
      (list
       standard-initialize-response
       (generic-failure-response "bad-direct")
       (success-response 208 expected-stub-hover)
       standard-shutdown-response)
      2)
     (check-equal? calls 2)
     (check-equal? (file->bytes path) bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (check-false
      (string-contains? (protocol-text result) (number->string result-number))))))

(struct unrelated-value (secret) #:transparent)

(test-case "all other non-result values receive exact generic failures"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "malformed-values.aloe"))
     (define text "abcdef")
     (write-exact-bytes path (string->bytes/utf-8 text))
     (define uri (path-uri path))
     (define values
       (list
        (void)
        (json-null)
        '()
        "private-string-value-008"
        (unrelated-value 'private-struct-value-008)))
     (define ids (list 1 "json-null" 3 "string-id" 5))
     (define remaining values)
     (define result
       (run-messages
        (append
         (standard-prefix uri text)
         (map (lambda (id) (hover-message uri 0 0 id)) ids)
         (list (shutdown-message) exit-message))
        #:query
        (lambda (_path _position)
          (define value (car remaining))
          (set! remaining (cdr remaining))
          value)))
     (check-exchange
      result
      (append
       (list standard-initialize-response)
       (map generic-failure-response ids)
       (list standard-shutdown-response))
      (length values))
     (check-equal? remaining '())
     (define output-text (protocol-text result))
     (for ([forbidden
            (in-list
             '("private-string-value-008"
               "private-struct-value-008"
               "unrelated-value"))])
       (check-false (string-contains? output-text forbidden))))))

(test-case "malformed signature collections fail and ordered rows recover"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "signature-results.aloe"))
     (define text "abcdef")
     (write-exact-bytes path (string->bytes/utf-8 text))
     (define uri (path-uri path))
     (define results
       (list
        (stub-result (cons row-a 'private-improper-tail-008))
        (stub-result (list row-a 'private-invalid-row-008))
        (stub-result)))
     (define remaining results)
     (define result
       (run-messages
        (append
         (standard-prefix uri text)
         (list
          (hover-message uri 0 0 "improper")
          (hover-message uri 0 0 802)
          (hover-message uri 0 0 "recovered")
          (shutdown-message)
          exit-message))
        #:query
        (lambda (_path _position)
          (define value (car remaining))
          (set! remaining (cdr remaining))
          value)))
     (check-exchange
      result
      (list
       standard-initialize-response
       (generic-failure-response "improper")
       (generic-failure-response 802)
       (success-response "recovered" expected-stub-hover)
       standard-shutdown-response)
      3)
     (check-equal? remaining '())
     (define output-text (protocol-text result))
     (for ([forbidden
            (in-list
             '("private-improper-tail-008"
               "private-invalid-row-008"
               "signature-spec-selector: contract violation"))])
       (check-false (string-contains? output-text forbidden))))))

(test-case "snapshot cleanup precedes malformed-result adaptation"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "missing-root.aloe"))
     (define text "dirty snapshot text")
     (define synchronized-bytes (string->bytes/utf-8 text))
     (define uri (path-uri path))
     (define original-entries (directory-entry-paths directory))
     (define observed-snapshot #f)
     (define result
       (run-messages
        (append
         (standard-prefix uri text)
         (list
          (hover-message uri 0 0 "dirty-malformed")
          (shutdown-message)
          exit-message))
        #:query
        (lambda (query-path query-position)
          (set! observed-snapshot query-path)
          (check-not-equal? (normalized query-path) (normalized path))
          (check-equal?
           (normalized (path->directory-path (path-only query-path)))
           (normalized (path->directory-path directory)))
          (check-equal? query-position 1)
          (check-equal? (file->bytes query-path) synchronized-bytes)
          (check-equal?
           (directory-entry-paths directory)
           (sort
            (cons (path->string (normalized query-path)) original-entries)
            string<?))
          (unrelated-value 'snapshot-private-value-008))))
     ;; These filesystem assertions deliberately precede response inspection.
     (check-true (path? observed-snapshot))
     (check-false (file-exists? observed-snapshot))
     (check-false (file-exists? path))
     (check-equal? (directory-entry-paths directory) original-entries)
     (check-exchange
      result
      (list
       standard-initialize-response
       (generic-failure-response "dirty-malformed")
       standard-shutdown-response)
      1)
     (define output-text (protocol-text result))
     (for ([forbidden
            (in-list
             (list "snapshot-private-value-008"
                   (path->string path)
                   (path->string observed-snapshot)
                   "continuation"))])
       (check-false (string-contains? output-text forbidden))))))

(test-case "query nulls invalid range adapter failure and success stay distinct"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "boundary-comparison.aloe"))
     (define text "abcdef")
     (write-exact-bytes path (string->bytes/utf-8 text))
     (define uri (path-uri path))
     (define outcomes
       (list
        'raise-query-failure
        #f
        (stub-result (list row-a) 999 1 'InvalidRange)
        "malformed-comparison-value-008"
        (stub-result)))
     (define remaining outcomes)
     (define ids (list "query-exn" 22 "invalid-range" 44 "success"))
     (define result
       (run-messages
        (append
         (standard-prefix uri text)
         (map (lambda (id) (hover-message uri 0 0 id)) ids)
         (list (shutdown-message) exit-message))
        #:query
        (lambda (_path _position)
          (define outcome (car remaining))
          (set! remaining (cdr remaining))
          (if (eq? outcome 'raise-query-failure)
              (error 'distinctive-query-exception-008
                     "private query exception text")
              outcome))))
     (check-exchange
      result
      (list
       standard-initialize-response
       (success-response "query-exn" (json-null))
       (success-response 22 (json-null))
       (success-response "invalid-range" (json-null))
       (generic-failure-response 44)
       (success-response "success" expected-stub-hover)
       standard-shutdown-response)
      5)
     (check-equal? remaining '())
     (define output-text (protocol-text result))
     (for ([forbidden
            (in-list
             '("distinctive-query-exception-008"
               "private query exception text"
               "malformed-comparison-value-008"
               "private-source-008"
               "diagnostic"))])
       (check-false (string-contains? output-text forbidden))))))

(test-case "snapshot setup failure retains its specific recoverable response"
  (call-with-test-directory
   (lambda (directory)
     (define parent-component (build-path directory "not-a-directory"))
     (define parent-bytes #"unchanged blocker")
     (write-exact-bytes parent-component parent-bytes)
     (define path (build-path parent-component "root.aloe"))
     (define uri (path-uri path))
     (define original-entries (directory-entry-paths directory))
     (define result
       (run-messages
        (append
         (standard-prefix uri "dirty")
         (list
          (hover-message uri 0 0 "snapshot-setup")
          (shutdown-message 608)
          exit-message))))
     (check-exchange
      result
      (list
       standard-initialize-response
       (snapshot-failure-response "snapshot-setup")
       (success-response 608 (json-null)))
      0)
     (check-equal? (file->bytes parent-component) parent-bytes)
     (check-equal? (directory-entry-paths directory) original-entries))))

(define (run-until-query-escape path query)
  (define uri (path-uri path))
  (define input
    (open-input-bytes
     (apply
      bytes-append
      (map
       frame
       (append
        (standard-prefix uri "abcdef")
        (list (hover-message uri 0 0 "escape")))))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (values
   (lambda ()
     (support:run-lsp-server/with-query
      input output error-output query))
   input
   output
   error-output))

(test-case "breaks and non-failure control values are not translated"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "control.aloe"))
     (write-exact-bytes path #"abcdef")
     (define break-value
       (let/ec continuation
         (exn:break
          "private-break-008"
          (current-continuation-marks)
          continuation)))
     (define-values (run-break break-input break-output break-error)
       (run-until-query-escape path
                               (lambda (_path _position)
                                 (raise break-value))))
     (check-exn exn:break? run-break)
     (check-equal?
      (decode-frames (get-output-bytes break-output))
      (list standard-initialize-response))
     (check-equal? (get-output-bytes break-error) #"")
     (for ([port (in-list (list break-input break-output break-error))])
       (check-false (port-closed? port)))

     (define control-value (gensym 'private-control-008))
     (define-values (run-control control-input control-output control-error)
       (run-until-query-escape path
                               (lambda (_path _position)
                                 (raise control-value))))
     (define observed
       (with-handlers ([(lambda (value) (eq? value control-value)) values])
         (run-control)
         #f))
     (check-eq? observed control-value)
     (check-equal?
      (decode-frames (get-output-bytes control-output))
      (list standard-initialize-response))
     (check-equal? (get-output-bytes control-error) #"")
     (for ([port (in-list (list control-input control-output control-error))])
       (check-false (port-closed? port))))))

(test-case "protocol output failure escapes without a retry"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "output-failure.aloe"))
     (write-exact-bytes path #"abcdef")
     (define uri (path-uri path))
     (define input
       (open-input-bytes
        (apply
         bytes-append
         (map
          frame
          (append
           (standard-prefix uri "abcdef")
           (list (hover-message uri 0 0 "malformed")))))))
     (define captured (open-output-bytes))
     (define attempts 0)
     (define output
       (make-output-port
        'failing-protocol-output-008
        always-evt
        (lambda (bytes start end _non-blocking? _breakable?)
          (set! attempts (add1 attempts))
          (if (<= attempts 3)
              (write-bytes bytes captured start end)
              (error 'protocol-output-failure-008
                     "private output failure")))
        void))
     (define error-output (open-output-bytes))
     (check-exn
      (lambda (exception)
        (and (exn:fail? exception)
             (string-contains? (exn-message exception)
                               "protocol-output-failure-008")))
      (lambda ()
        (support:run-lsp-server/with-query
         input
         output
         error-output
         (lambda (_path _position) 808))))
     (check-equal? attempts 4)
     (check-equal?
      (decode-frames (get-output-bytes captured))
      (list standard-initialize-response))
     (check-equal? (get-output-bytes error-output) #"")
     (for ([port (in-list (list input output error-output))])
       (check-false (port-closed? port))))))

(define missing-export (gensym 'missing-export))

(define (module-exports? name)
  (not
   (eq? (dynamic-require
         lsp-module-path
         name
         (lambda () missing-export))
        missing-export)))

(test-case "public module stays inert and public query keeps null and success"
  (check-equal? (procedure-arity lsp:run-lsp-server) 3)
  (check-equal? (procedure-arity support:run-lsp-server/with-query) 4)
  (for ([private-name
         (in-list
          '(run-lsp-server/with-query
            hover-outcome
            hover-success
            hover-failure
            query-hover))])
    (check-false (module-exports? private-name)))
  (define inert-input (open-input-bytes #"not consumed"))
  (define inert-output (open-output-bytes))
  (define inert-error (open-output-bytes))
  (parameterize ([current-namespace (make-base-namespace)]
                 [current-input-port inert-input]
                 [current-output-port inert-output]
                 [current-error-port inert-error])
    (dynamic-require lsp-module-path #f))
  (check-equal? (read-bytes 12 inert-input) #"not consumed")
  (check-equal? (get-output-bytes inert-output) #"")
  (check-equal? (get-output-bytes inert-error) #"")
  (for ([port (in-list (list inert-input inert-output inert-error))])
    (check-false (port-closed? port)))

  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "public-query.aloe"))
     (define invalid-text "(1)\n")
     (write-exact-bytes path (string->bytes/utf-8 invalid-text))
     (define original-entries (directory-entry-paths directory))
     (define uri (path-uri path))
     (define result
       (run-messages
        (append
         (standard-prefix uri invalid-text)
         (list
          (hover-message uri 0 1 "public-null")
          (change-message uri "String" 2)
          (hover-message uri 0 0 "public-success")
          (shutdown-message)
          exit-message))
        #:public? #t))
     (define expected-string-hover
       (hasheq
        'contents
        (hasheq
         'kind "plaintext"
         'value "type: (Class String)\nmessages: none")
        'range
        (hasheq
         'start (hasheq 'line 0 'character 0)
         'end (hasheq 'line 0 'character 6))))
     (check-exchange
      result
      (list
       standard-initialize-response
       (success-response "public-null" (json-null))
       (success-response "public-success" expected-string-hover)
       standard-shutdown-response)
      0)
     (check-equal? (file->bytes path) (string->bytes/utf-8 invalid-text))
     (check-equal? (directory-entry-paths directory) original-entries))))

(test-case "source keeps the adapter boundary narrow"
  (define source (file->string lsp-module-path))
  (check-equal?
   (regexp-match* #rx"\"[^\"]+\\.rkt\"" source)
   '("\"expression-query.rkt\""
     "\"completion-query.rkt\""))
  (for ([forbidden
         (in-list
          '("parse.rkt"
            "type.rkt"
            "checker.rkt"
            "signature-catalog.rkt"
            "type-signature-specs"
            "signature-spec?"
            "exn-message"
            "continuation-mark-set->context"
            "[exn?"))])
    (check-false (string-contains? source forbidden)))
  (check-equal?
   (length
    (regexp-match* #px"\\(query\\s+path\\s+query-position\\)"
                   source))
   1))
