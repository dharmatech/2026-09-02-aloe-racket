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
(define-runtime-path fixture-path "fixtures/point.aloe")

(define normalized-fixture-path
  (simplify-path (path->complete-path fixture-path) #f))
(define fixture-text
  (bytes->string/utf-8 (file->bytes normalized-fixture-path)))
(define fixture-uri
  (url->string (path->url normalized-fixture-path)))

(define (body-frame body)
  (bytes-append
   (string->bytes/utf-8
    (format "Content-Length: ~a\r\n\r\n" (bytes-length body)))
   body))

(define (message-frame message)
  (body-frame (jsexpr->bytes message)))

(define (messages->bytes messages)
  (apply bytes-append (map message-frame messages)))

(struct output-frame (declared-length body value) #:transparent)

(define (decode-output framed-bytes)
  (let loop ([remaining framed-bytes]
             [frames '()])
    (cond
      [(zero? (bytes-length remaining))
       (reverse frames)]
      [else
       (define match
         (regexp-match
          #rx#"^Content-Length: ([0-9]+)\r\n\r\n"
          remaining))
       (unless match
         (error 'decode-output "non-canonical response bytes"))
       (define header (first match))
       (define declared-length
         (string->number (bytes->string/latin-1 (second match)) 10))
       (define body-start (bytes-length header))
       (define body-end (+ body-start declared-length))
       (when (> body-end (bytes-length remaining))
         (error 'decode-output "short response body"))
       (define body (subbytes remaining body-start body-end))
       (check-equal? (bytes-length body) declared-length)
       (loop
        (subbytes remaining body-end)
        (cons
         (output-frame declared-length body (bytes->jsexpr body))
         frames))])))

(struct exchange
  (status input output error frames query-calls query-arguments)
  #:transparent)

(define (run-input input-bytes
                   #:public? [public? #f]
                   #:query [query (lambda (_path _position) #f)])
  (define input (open-input-bytes input-bytes))
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
            (decode-output (get-output-bytes output))
            calls
            arguments))

(define (run-messages messages
                      #:public? [public? #f]
                      #:query [query (lambda (_path _position) #f)])
  (run-input (messages->bytes messages)
             #:public? public?
             #:query query))

(define (response-values result)
  (map output-frame-value (exchange-frames result)))

(define (check-open-ports result)
  (check-false (port-closed? (exchange-input result)))
  (check-false (port-closed? (exchange-output result)))
  (check-false (port-closed? (exchange-error result))))

(define (check-exchange result status responses query-calls)
  (check-equal? (exchange-status result) status)
  (check-equal? (response-values result) responses)
  (check-equal? (exchange-query-calls result) query-calls)
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (check-open-ports result))

(define initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync (hasheq 'openClose #t 'change 1)
    'hoverProvider #t)
   'serverInfo (hasheq 'name "aloe-lsp")))

(define (success-response id result)
  (hasheq 'jsonrpc "2.0" 'id id 'result result))

(define (error-response id code message)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'error (hasheq 'code code 'message message)))

(define parse-error-response
  (error-response (json-null) -32700 "Parse error"))

(define invalid-envelope-response
  (error-response (json-null) -32600 "Invalid Request"))

(define (invalid-request-response id)
  (error-response id -32600 "Invalid Request"))

(define (method-not-found-response id)
  (error-response id -32601 "Method not found"))

(define (invalid-params-response id)
  (error-response id -32602 "Invalid params"))

(define (not-initialized-response id)
  (error-response id -32002 "Server not initialized"))

(define (initialize-message [id "initialize"] [params (hasheq)])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "initialize"
   'params params))

(define initialized-message
  (hasheq
   'jsonrpc "2.0"
   'method "initialized"
   'params (hasheq)))

(define (open-params uri text [version 1])
  (hasheq
   'textDocument
   (hasheq
    'uri uri
    'languageId "aloe"
    'version version
    'text text)))

(define (open-message uri text [version 1])
  (hasheq
   'jsonrpc "2.0"
   'method "textDocument/didOpen"
   'params (open-params uri text version)))

(define (change-message uri text [version 2])
  (hasheq
   'jsonrpc "2.0"
   'method "textDocument/didChange"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri 'version version)
    'contentChanges (list (hasheq 'text text)))))

(define (close-message uri)
  (hasheq
   'jsonrpc "2.0"
   'method "textDocument/didClose"
   'params (hasheq 'textDocument (hasheq 'uri uri))))

(define (hover-params uri line character)
  (hasheq
   'textDocument (hasheq 'uri uri)
   'position (hasheq 'line line 'character character)))

(define (hover-message uri line character [id "hover"])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/hover"
   'params (hover-params uri line character)))

(define (shutdown-message [id "shutdown"])
  (hasheq 'jsonrpc "2.0" 'id id 'method "shutdown"))

(define exit-message
  (hasheq 'jsonrpc "2.0" 'method "exit"))

(define (stub-result [start 163] [span 15])
  (query:expression-query-result
   'Stub
   (list (query:signature-spec 'probe '() 'Stub))
   (srcloc 'ignored 10 0 start span)))

(define stub-hover-result
  (hasheq
   'contents
   (hasheq
    'kind "plaintext"
    'value "type: Stub\nmessages:\n  probe : () -> Stub")
   'range
   (hasheq
    'start (hasheq 'line 9 'character 0)
    'end (hasheq 'line 9 'character 15))))

(define successful-messages
  (list
   (initialize-message)
   initialized-message
   (open-message fixture-uri fixture-text)
   (hover-message fixture-uri 9 7)
   (shutdown-message)
   exit-message))

(define successful-responses
  (list
   (success-response "initialize" initialize-result)
   (success-response "hover" stub-hover-result)
   (success-response "shutdown" (json-null))))

(define (check-recoverable-response-shape response)
  (check-equal? (hash-ref response 'jsonrpc) "2.0")
  (check-true (hash-has-key? response 'id))
  (check-false (hash-has-key? response 'data))
  (check-not-equal? (hash-has-key? response 'error)
                    (hash-has-key? response 'result))
  (when (hash-has-key? response 'error)
    (define error-value (hash-ref response 'error))
    (check-equal? (sort (hash-keys error-value) symbol<?)
                  '(code message))))

(test-case "successful lifecycle retains active Hover behavior"
  (define result
    (run-messages
     successful-messages
     #:query (lambda (_path _position) (stub-result))))
  (check-exchange result 0 successful-responses 1)
  (check-equal? (exchange-query-arguments result)
                (list (list normalized-fixture-path 170))))

(test-case "uninitialized requests receive ServerNotInitialized first"
  (define requests
    (list
     (hover-message fixture-uri 9 7 10)
     (hasheq 'jsonrpc "2.0"
             'id "bad-hover"
             'method "textDocument/hover"
             'params (hasheq))
     (shutdown-message 12)
     (hasheq 'jsonrpc "2.0" 'id "unknown" 'method "no/such")
     (hasheq 'jsonrpc "2.0"
             'id 14
             'method "textDocument/didOpen"
             'params (open-params fixture-uri fixture-text))))
  (define ids '(10 "bad-hover" 12 "unknown" 14))
  (define result
    (run-messages
     (append requests
             (list (initialize-message "later")
                   (shutdown-message "done")
                   exit-message))))
  (check-exchange
   result
   0
   (append
    (map not-initialized-response ids)
    (list (success-response "later" initialize-result)
          (success-response "done" (json-null))))
   0))

(test-case "invalid initialize stays uninitialized and later recovery works"
  (define result
    (run-messages
     (list
      (initialize-message "bad" (json-null))
      (hover-message fixture-uri 9 7 "still-early")
      (initialize-message "good")
      (open-message fixture-uri fixture-text)
      (hover-message fixture-uri 9 7 "active-hover")
      (shutdown-message)
      exit-message)
     #:query (lambda (_path _position) (stub-result))))
  (check-exchange
   result
   0
   (list
    (invalid-params-response "bad")
    (not-initialized-response "still-early")
    (success-response "good" initialize-result)
    (success-response "active-hover" stub-hover-result)
    (success-response "shutdown" (json-null)))
   1))

(test-case "uninitialized notifications are silent and inert"
  (define pre-init-uri "file:///tmp/aloe-lsp-pre-init.aloe")
  (define notifications
    (list
     initialized-message
     (open-message pre-init-uri fixture-text)
     (change-message pre-init-uri "changed")
     (close-message pre-init-uri)
     (hasheq 'jsonrpc "2.0"
             'method "$/cancelRequest"
             'params (hasheq 'id 1))
     (hasheq 'jsonrpc "2.0" 'method "no/such")
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'params (hasheq))
     (hasheq 'jsonrpc "2.0"
             'method "textDocument/hover"
             'params (hover-params pre-init-uri 0 0))
     (hasheq 'jsonrpc "2.0" 'method "shutdown")
     (hasheq 'jsonrpc "2.0" 'method "exit" 'params (hasheq))))
  (define result
    (run-messages
     (append notifications
             (list (initialize-message)
                   (hover-message pre-init-uri 0 0 "not-open")
                   (shutdown-message)
                   exit-message))))
  (check-exchange
   result
   0
   (list
    (success-response "initialize" initialize-result)
    (success-response "not-open" (json-null))
    (success-response "shutdown" (json-null)))
   0))

(test-case "repeated initialize is InvalidRequest and preserves documents"
  (define result
    (run-messages
     (list
      (initialize-message)
      (open-message fixture-uri fixture-text)
      (initialize-message 31 (hasheq 'extra "accepted only initially"))
      (initialize-message "bad-repeat" '("invalid" "params"))
      (hover-message fixture-uri 9 7 "after-repeat")
      (shutdown-message)
      exit-message)
     #:query (lambda (_path _position) (stub-result))))
  (check-exchange
   result
   0
   (list
    (success-response "initialize" initialize-result)
    (invalid-request-response 31)
    (invalid-request-response "bad-repeat")
    (success-response "after-repeat" stub-hover-result)
    (success-response "shutdown" (json-null)))
   1))

(test-case "initialized is optional and repeatable"
  (define (run-with notifications)
    (run-messages
     (append
      (list (initialize-message)
            (open-message fixture-uri fixture-text))
      notifications
      (list (hover-message fixture-uri 9 7)
            (shutdown-message)
            exit-message))
     #:query (lambda (_path _position) (stub-result))))
  (define without (run-with '()))
  (define repeated
    (run-with (list initialized-message initialized-message initialized-message)))
  (check-exchange without 0 successful-responses 1)
  (check-exchange repeated 0 successful-responses 1))

(test-case "invalid shutdown params leave active Hover available"
  (define result
    (run-messages
     (list
      (initialize-message)
      (open-message fixture-uri fixture-text)
      (hasheq 'jsonrpc "2.0"
              'id "bad-shutdown"
              'method "shutdown"
              'params (hasheq))
      (hover-message fixture-uri 9 7 "after-bad")
      (shutdown-message "valid-shutdown")
      exit-message)
     #:query (lambda (_path _position) (stub-result))))
  (check-exchange
   result
   0
   (list
    (success-response "initialize" initialize-result)
    (invalid-params-response "bad-shutdown")
    (success-response "after-bad" stub-hover-result)
    (success-response "valid-shutdown" (json-null)))
   1))

(test-case "all requests after shutdown receive lifecycle InvalidRequest"
  (define requests
    (list
     (initialize-message "init-after")
     (shutdown-message 42)
     (hover-message fixture-uri 9 7 "hover-valid")
     (hasheq 'jsonrpc "2.0"
             'id 44
             'method "textDocument/hover"
             'params (hasheq))
     (hasheq 'jsonrpc "2.0" 'id "unknown-after" 'method "no/such")
     (hasheq 'jsonrpc "2.0" 'id 46 'method "exit")))
  (define ids '("init-after" 42 "hover-valid" 44 "unknown-after" 46))
  (define result
    (run-messages
     (append
      (list (initialize-message) (shutdown-message))
      requests
      (list exit-message))))
  (check-exchange
   result
   0
   (append
    (list (success-response "initialize" initialize-result)
          (success-response "shutdown" (json-null)))
    (map invalid-request-response ids))
   0))

(test-case "notifications after shutdown are silent and inert"
  (define temporary-directory
    (make-temporary-file "aloe-lsp-lifecycle-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define ignored-path (build-path temporary-directory "ignored.aloe"))
      (define ignored-uri (url->string (path->url ignored-path)))
      (define notifications
        (list
         initialized-message
         (open-message ignored-uri fixture-text)
         (change-message ignored-uri "changed")
         (close-message ignored-uri)
         (hasheq 'jsonrpc "2.0"
                 'method "textDocument/didOpen"
                 'params (hasheq))
         (hasheq 'jsonrpc "2.0"
                 'method "textDocument/didChange"
                 'params '("bad"))
         (hasheq 'jsonrpc "2.0"
                 'method "textDocument/didClose"
                 'params (json-null))
         (hasheq 'jsonrpc "2.0"
                 'method "$/cancelRequest"
                 'params (hasheq 'id "gone"))
         (hasheq 'jsonrpc "2.0" 'method "no/such")
         (hasheq 'jsonrpc "2.0" 'method "initialize" 'params (hasheq))
         (hasheq 'jsonrpc "2.0"
                 'method "textDocument/hover"
                 'params (hover-params ignored-uri 0 0))
         (hasheq 'jsonrpc "2.0" 'method "shutdown")
         (hasheq 'jsonrpc "2.0" 'method "exit" 'params "bad")))
      (define result
        (run-messages
         (append
          (list (initialize-message) (shutdown-message))
          notifications
          (list exit-message))))
      (check-exchange
       result
       0
       (list (success-response "initialize" initialize-result)
             (success-response "shutdown" (json-null)))
       0)
      (check-equal? (directory-list temporary-directory) '()))
    (lambda ()
      (delete-directory/files temporary-directory))))

(test-case "early exit is status 1 and leaves trailing frames unread"
  (define trailing (message-frame (initialize-message "trailing")))
  (for ([prefix (in-list (list #"" (message-frame (initialize-message))))]
        [responses (in-list (list '()
                                  (list (success-response
                                         "initialize"
                                         initialize-result))))])
    (define result
      (run-input
       (bytes-append prefix (message-frame exit-message) trailing)))
    (check-exchange result 1 responses 0)
    (check-equal? (port->bytes (exchange-input result)) trailing)))

(test-case "post-shutdown exit is status 0 and leaves trailing frames unread"
  (define trailing
    (message-frame
     (hasheq 'jsonrpc "2.0" 'id "trailing" 'method "no/such")))
  (define result
    (run-input
     (bytes-append
      (messages->bytes (list (initialize-message) (shutdown-message) exit-message))
      trailing)))
  (check-exchange
   result
   0
   (list (success-response "initialize" initialize-result)
         (success-response "shutdown" (json-null)))
   0)
  (check-equal? (port->bytes (exchange-input result)) trailing))

(test-case "EOF is status 1 in every lifecycle state"
  (define cases
    (list
     (list #"" '())
     (list (message-frame (shutdown-message "early"))
           (list (not-initialized-response "early")))
     (list (message-frame (initialize-message))
           (list (success-response "initialize" initialize-result)))
     (list (messages->bytes (list (initialize-message) (shutdown-message)))
           (list (success-response "initialize" initialize-result)
                 (success-response "shutdown" (json-null))))))
  (for ([case (in-list cases)])
    (define result (run-input (first case)))
    (check-exchange result 1 (second case) 0)))

(test-case "recoverable framing and envelope errors preserve lifecycle state"
  (define input
    (bytes-append
     (body-frame #"{\"jsonrpc\":\"2.0\",]")
     (message-frame 17)
     (message-frame (initialize-message))
     (message-frame
      (hasheq 'jsonrpc "2.0" 'id "unknown" 'method "no/such"))
     (message-frame
      (hasheq 'jsonrpc "2.0"
              'id "bad-hover"
              'method "textDocument/hover"
              'params (hasheq)))
     (message-frame (shutdown-message))
     (body-frame #"not-json")
     (message-frame (hasheq 'jsonrpc "1.0" 'id "bad" 'method "shutdown"))
     (message-frame exit-message)))
  (define result (run-input input))
  (check-exchange
   result
   0
   (list
    parse-error-response
    invalid-envelope-response
    (success-response "initialize" initialize-result)
    (method-not-found-response "unknown")
    (invalid-params-response "bad-hover")
    (success-response "shutdown" (json-null))
    parse-error-response
    invalid-envelope-response)
   0))

(test-case "fatal framing is status 1 in every lifecycle state"
  (define fatal #"Content-Length: nope\r\n\r\n")
  (define cases
    (list
     (list #"" '())
     (list (message-frame (initialize-message))
           (list (success-response "initialize" initialize-result)))
     (list (messages->bytes (list (initialize-message) (shutdown-message)))
           (list (success-response "initialize" initialize-result)
                 (success-response "shutdown" (json-null))))))
  (for ([case (in-list cases)])
    (define result
      (run-input (bytes-append (first case) fatal)))
    (check-exchange result 1 (second case) 0)))

(test-case "request error precedence changes across all three states"
  (define bad-hover
    (lambda (id)
      (hasheq 'jsonrpc "2.0"
              'id id
              'method "textDocument/hover"
              'params (hasheq))))
  (define unknown
    (lambda (id)
      (hasheq 'jsonrpc "2.0" 'id id 'method "no/such")))
  (define result
    (run-messages
     (list
      (bad-hover "pre-hover")
      (unknown "pre-unknown")
      (initialize-message)
      (bad-hover "active-hover")
      (unknown "active-unknown")
      (shutdown-message)
      (bad-hover "post-hover")
      (unknown "post-unknown")
      exit-message)))
  (define expected
    (list
     (not-initialized-response "pre-hover")
     (not-initialized-response "pre-unknown")
     (success-response "initialize" initialize-result)
     (invalid-params-response "active-hover")
     (method-not-found-response "active-unknown")
     (success-response "shutdown" (json-null))
     (invalid-request-response "post-hover")
     (invalid-request-response "post-unknown")))
  (check-exchange result 0 expected 0)
  (for ([response (in-list expected)])
    (check-recoverable-response-shape response)))

(define missing-export (gensym 'missing-export))

(define (module-exports? name)
  (not
   (eq? (dynamic-require
         lsp-module-path
         name
         (lambda () missing-export))
        missing-export)))

(test-case "public surface, shared lifecycle, and caller ports remain unchanged"
  (check-equal? (procedure-arity lsp:run-lsp-server) 3)
  (check-equal? (procedure-arity support:run-lsp-server/with-query) 4)
  (for ([name
         (in-list
          '(run-lsp-server/with-query
            classify-json-rpc-message
            rpc-request
            rpc-notification
            lifecycle-state))])
    (check-false (module-exports? name)))
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
  (define lifecycle-input
    (messages->bytes
     (list
      (shutdown-message "early")
      (initialize-message)
      (initialize-message "repeat")
      (shutdown-message)
      (hover-message fixture-uri 9 7 "late")
      exit-message)))
  (define seam-result (run-input lifecycle-input))
  (define public-result (run-input lifecycle-input #:public? #t))
  (check-equal? (exchange-status public-result)
                (exchange-status seam-result))
  (check-equal? (response-values public-result)
                (response-values seam-result))
  (check-equal?
   (response-values public-result)
   (list
    (not-initialized-response "early")
    (success-response "initialize" initialize-result)
    (invalid-request-response "repeat")
    (success-response "shutdown" (json-null))
    (invalid-request-response "late")))
  (check-open-ports seam-result)
  (check-open-ports public-result))

(test-case "production source remains a serial thin adapter"
  (define source (file->string lsp-module-path))
  (for ([forbidden
         (in-list
          '("racket/thread"
            "async-channel"
            "worker"
            "queue"
            "parse.rkt"
            "type.rkt"
            "eval.rkt"
            "checker.rkt"
            "type-signature-specs"))])
    (check-false (string-contains? source forbidden))))
