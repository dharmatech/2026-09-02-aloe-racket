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

(define (check-clean result)
  (check-equal? (exchange-status result) 0)
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

(define invalid-request-response
  (error-response (json-null) -32600 "Invalid Request"))

(define parse-error-response
  (error-response (json-null) -32700 "Parse error"))

(define (method-not-found-response id)
  (error-response id -32601 "Method not found"))

(define (invalid-params-response id)
  (error-response id -32602 "Invalid params"))

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

(define (successful-prefix)
  (list (initialize-message) initialized-message))

(define (successful-suffix)
  (list (shutdown-message) exit-message))

(define (stub-result [start 1] [span 0])
  (query:expression-query-result
   'Stub
   (list (query:signature-spec 'probe '() 'Stub))
   (srcloc 'ignored 1 0 start span)))

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

(test-case "non-object JSON values and response objects are Invalid Request"
  (define apparent-batch
    (list (initialize-message 7)))
  (define invalid-values
    (list apparent-batch
          '()
          "scalar"
          19
          1.5
          #t
          #f
          (json-null)
          (hasheq 'jsonrpc "2.0" 'id "response" 'result 1)
          (hasheq 'jsonrpc "2.0"
                  'id 3
                  'error (hasheq 'code -1 'message "incoming"))))
  (define split-index 5)
  (define result
    (run-messages
     (append
      (take invalid-values split-index)
      (list (initialize-message "after-invalid"))
      (drop invalid-values split-index)
      (successful-suffix))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (response-values result)
   (append
    (make-list split-index invalid-request-response)
    (list (success-response "after-invalid" initialize-result))
    (make-list (- (length invalid-values) split-index)
               invalid-request-response)
    (list (success-response "shutdown" (json-null))))))

(test-case "malformed envelopes always use a null Invalid Request id"
  (define malformed
    (list
     (hasheq)
     (hasheq 'method "initialize" 'params (hasheq))
     (hasheq 'jsonrpc "1.0" 'method "initialize" 'id "looks-valid")
     (hasheq 'jsonrpc 2.0 'method "initialize" 'id 42)
     (hasheq 'jsonrpc "2.0" 'id "looks-valid")
     (hasheq 'jsonrpc "2.0" 'method 7 'id 42)
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'id (json-null))
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'id #t)
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'id 4.5)
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'id '(1 2))
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'id (hasheq))))
  (define result
    (run-messages
     (append
      (take malformed 4)
      (list (initialize-message "valid-initialize"))
      (drop malformed 4)
      (successful-suffix))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (response-values result)
   (append
    (make-list 4 invalid-request-response)
    (list (success-response "valid-initialize" initialize-result))
    (make-list (- (length malformed) 4) invalid-request-response)
    (list (success-response "shutdown" (json-null))))))

(test-case "unsupported requests preserve numeric and string ids and service"
  (define result
    (run-messages
     (append
      (successful-prefix)
      (list
       (hasheq 'jsonrpc "2.0" 'id 81 'method "unknown" 'params '("bad"))
       (hasheq 'jsonrpc "2.0" 'id "u-2" 'method "other" 'params #f)
       (open-message fixture-uri fixture-text)
       (hover-message fixture-uri 9 7 "later-hover"))
      (successful-suffix))
     #:query (lambda (_path _position) (stub-result 163 15))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 1)
  (define responses (response-values result))
  (check-equal? (second responses) (method-not-found-response 81))
  (check-equal? (third responses) (method-not-found-response "u-2"))
  (check-true (hash-has-key? (fourth responses) 'result))
  (check-false (equal? (hash-ref (fourth responses) 'result) (json-null))))

(test-case "unknown and cancellation notifications are silent and inert"
  (define untouched-uri "file:///tmp/unsupported-notification.aloe")
  (define notifications
    (list
     (hasheq 'jsonrpc "2.0" 'method "unknown/absent")
     (hasheq 'jsonrpc "2.0"
             'method "unknown/object"
             'params (open-params untouched-uri "must not open"))
     (hasheq 'jsonrpc "2.0" 'method "unknown/array" 'params '(1 2))
     (hasheq 'jsonrpc "2.0"
             'method "$/cancelRequest"
             'params (hasheq 'id "ignored"))))
  (define result
    (run-messages
     (append
      (successful-prefix)
      notifications
      (list (hover-message untouched-uri 0 0 "untouched"))
      (successful-suffix))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (response-values result)
   (list
    (success-response "initialize" initialize-result)
    (success-response "untouched" (json-null))
    (success-response "shutdown" (json-null)))))

(test-case "request and notification method roles are enforced first"
  (define role-uri "file:///tmp/request-form-open.aloe")
  (define request-only-notifications
    (list
     (hasheq 'jsonrpc "2.0" 'method "initialize" 'params (hasheq))
     (hasheq 'jsonrpc "2.0"
             'method "textDocument/hover"
             'params (hover-params fixture-uri 9 7))
     (hasheq 'jsonrpc "2.0" 'method "shutdown")))
  (define notification-only-requests
    (list
     (hasheq 'jsonrpc "2.0" 'id "initialized-r" 'method "initialized")
     (hasheq 'jsonrpc "2.0"
             'id "open-r"
             'method "textDocument/didOpen"
             'params (open-params role-uri "must not open"))
     (hasheq 'jsonrpc "2.0"
             'id "change-r"
             'method "textDocument/didChange"
             'params (hasheq))
     (hasheq 'jsonrpc "2.0"
             'id "close-r"
             'method "textDocument/didClose"
             'params (hasheq))
     (hasheq 'jsonrpc "2.0"
             'id "cancel-r"
             'method "$/cancelRequest"
             'params '("anything"))
     (hasheq 'jsonrpc "2.0" 'id "exit-r" 'method "exit")))
  (define result
    (run-messages
     (append
      request-only-notifications
      (successful-prefix)
      notification-only-requests
      (list (hover-message role-uri 0 0 "not-opened"))
      (successful-suffix))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (response-values result)
   (append
    (list (success-response "initialize" initialize-result))
    (map method-not-found-response
         '("initialized-r" "open-r" "change-r"
           "close-r" "cancel-r" "exit-r"))
    (list
     (success-response "not-opened" (json-null))
     (success-response "shutdown" (json-null))))))

(test-case "initialize requires an object params value"
  (define absent-params
    (hasheq 'jsonrpc "2.0" 'id "absent" 'method "initialize"))
  (define invalid-initializes
    (list
     absent-params
     (initialize-message "null" (json-null))
     (initialize-message "array" '(1))
     (initialize-message "string" "bad")
     (initialize-message "number" 2)
     (initialize-message "boolean" #f)))
  (for ([invalid (in-list invalid-initializes)])
    (define invalid-id (hash-ref invalid 'id))
    (define result
      (run-messages
       (list invalid
             (initialize-message "valid-after-invalid")
             (shutdown-message)
             exit-message)))
    (check-clean result)
    (check-equal? (exchange-query-calls result) 0)
    (check-equal?
     (response-values result)
     (list
      (invalid-params-response invalid-id)
      (success-response "valid-after-invalid" initialize-result)
      (success-response "shutdown" (json-null))))))

(test-case "Hover validates the complete nested parameter shape"
  (define td (hasheq 'uri fixture-uri))
  (define position (hasheq 'line 0 'character 0))
  (define invalid-params
    (list
     #f
     (json-null)
     '()
     "bad"
     1
     #t
     (hasheq)
     (hasheq 'position position)
     (hasheq 'textDocument "bad" 'position position)
     (hasheq 'textDocument (hasheq) 'position position)
     (hasheq 'textDocument (hasheq 'uri 7) 'position position)
     (hasheq 'textDocument td)
     (hasheq 'textDocument td 'position "bad")
     (hasheq 'textDocument td 'position (hasheq 'character 0))
     (hasheq 'textDocument td 'position (hasheq 'line 0))
     (hasheq 'textDocument td
             'position (hasheq 'line -1 'character 0))
     (hasheq 'textDocument td
             'position (hasheq 'line 0 'character -1))
     (hasheq 'textDocument td
             'position (hasheq 'line 1.0 'character 0))
     (hasheq 'textDocument td
             'position (hasheq 'line 0 'character 1.0))
     (hasheq 'textDocument td
             'position (hasheq 'line #t 'character 0))
     (hasheq 'textDocument td
             'position (hasheq 'line 0 'character #f))))
  (define invalid-messages
    (for/list ([params (in-list invalid-params)]
               [index (in-naturals)])
      (if (zero? index)
          (hasheq 'jsonrpc "2.0"
                  'id index
                  'method "textDocument/hover")
          (hasheq 'jsonrpc "2.0"
                  'id index
                  'method "textDocument/hover"
                  'params params))))
  (define unsupported-uri "untitled:buffer")
  (define surrogate-uri "file:///tmp/aloe-lsp-surrogate.aloe")
  (define controls
    (list
     (hover-message "file:///tmp/unopened.aloe" 0 0 "unopened")
     (open-message unsupported-uri fixture-text)
     (hover-message unsupported-uri 0 0 "unsupported")
     (open-message fixture-uri fixture-text)
     (hover-message fixture-uri 500 0 "out-of-range")
     (open-message surrogate-uri "😀")
     (hover-message surrogate-uri 0 1 "split-surrogate")))
  (define result
    (run-messages
     (append
      (successful-prefix)
      invalid-messages
      controls
      (successful-suffix))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (response-values result)
   (append
    (list (success-response "initialize" initialize-result))
    (for/list ([index (in-range (length invalid-params))])
      (invalid-params-response index))
    (map (lambda (id) (success-response id (json-null)))
         '("unopened" "unsupported" "out-of-range" "split-surrogate"))
    (list (success-response "shutdown" (json-null))))))

(test-case "invalid shutdown params do not prevent later Hover or shutdown"
  (define bad-values
    (list (hasheq) '(1) "bad" 3 #t))
  (define bad-shutdowns
    (for/list ([value (in-list bad-values)]
               [index (in-naturals)])
      (hasheq 'jsonrpc "2.0"
              'id (format "bad-shutdown-~a" index)
              'method "shutdown"
              'params value)))
  (define result
    (run-messages
     (append
      (successful-prefix)
      (list (open-message fixture-uri fixture-text))
      bad-shutdowns
      (list
       (hover-message fixture-uri 9 7 "after-bad-shutdown")
       (shutdown-message "valid-shutdown")
       exit-message))
     #:query (lambda (_path _position) (stub-result 163 15))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 1)
  (define responses (response-values result))
  (check-equal?
   (take responses (+ 1 (length bad-values)))
   (cons
    (success-response "initialize" initialize-result)
    (for/list ([index (in-range (length bad-values))])
      (invalid-params-response (format "bad-shutdown-~a" index)))))
  (check-true (hash-has-key? (list-ref responses 6) 'result))
  (check-equal? (last responses)
                (success-response "valid-shutdown" (json-null))))

(test-case "initialized and exit malformed params are silent no-ops"
  (define result
    (run-messages
     (list
      (initialize-message)
      (hasheq 'jsonrpc "2.0" 'method "initialized" 'params '("bad"))
      (hasheq 'jsonrpc "2.0" 'method "exit" 'params (hasheq))
      (hasheq 'jsonrpc "2.0"
              'id "shutdown"
              'method "shutdown"
              'params (json-null))
      (hasheq 'jsonrpc "2.0" 'method "exit" 'params "bad")
      (hasheq 'jsonrpc "2.0" 'method "exit" 'params (json-null)))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (response-values result)
   (list
    (success-response "initialize" initialize-result)
    (success-response "shutdown" (json-null)))))

(define (seed-documents)
  (define documents (make-hash))
  (support:apply-document-sync!
   documents
   "textDocument/didOpen"
   (open-params fixture-uri fixture-text 9))
  documents)

(test-case "the synchronization reducer remains atomic for malformed params"
  (define malformed
    (list
     (list "textDocument/didOpen"
           (hasheq 'textDocument
                   (hasheq 'uri fixture-uri
                           'languageId "aloe"
                           'version 10)))
     (list "textDocument/didChange"
           (hasheq
            'textDocument (hasheq 'uri fixture-uri 'version 10)
            'contentChanges
            (list (hasheq 'text "would replace")
                  (hasheq 'text "incremental" 'range (json-null)))))
     (list "textDocument/didClose"
           (hasheq 'textDocument (hasheq 'uri 7)))))
  (for ([case (in-list malformed)])
    (define documents (seed-documents))
    (define before (hash-copy documents))
    (support:apply-document-sync! documents (first case) (second case))
    (check-equal? documents before)))

(test-case "framed malformed synchronization is response-free and atomic"
  (define malformed-notifications
    (list
     (hasheq 'jsonrpc "2.0"
             'method "textDocument/didOpen"
             'params
             (hasheq 'textDocument
                     (hasheq 'uri fixture-uri
                             'languageId "aloe"
                             'version 2)))
     (hasheq 'jsonrpc "2.0"
             'method "textDocument/didChange"
             'params
             (hasheq
              'textDocument (hasheq 'uri fixture-uri 'version 2)
              'contentChanges
              (list (hasheq 'text "would replace")
                    (hasheq 'text "bad" 'rangeLength (json-null)))))
     (hasheq 'jsonrpc "2.0"
             'method "textDocument/didClose"
             'params (hasheq 'textDocument (hasheq 'uri #f)))))
  (define result
    (run-messages
     (append
      (successful-prefix)
      (list (open-message fixture-uri fixture-text))
      malformed-notifications
      (list (hover-message fixture-uri 9 7 "atomic-hover"))
      (successful-suffix))
     #:query (lambda (_path _position) (stub-result 163 15))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 1)
  (check-equal? (second (first (exchange-query-arguments result))) 170)
  (check-equal? (length (response-values result)) 3)
  (check-false
   (equal? (hash-ref (second (response-values result)) 'result)
           (json-null))))

(test-case "recoverable errors and ignored notifications remain ordered"
  (define mixed-input
    (bytes-append
     (message-frame (initialize-message "mixed-init"))
     (body-frame #"{\"jsonrpc\":\"2.0\",]")
     (message-frame 17)
     (message-frame
      (hasheq 'jsonrpc "2.0" 'id "missing" 'method "no/such"))
     (message-frame
      (hasheq 'jsonrpc "2.0"
              'id "bad-hover"
              'method "textDocument/hover"
              'params (hasheq 'position (hasheq 'line 0 'character 0))))
     (message-frame
      (hasheq 'jsonrpc "2.0" 'method "ignored" 'params '(1 2)))
     (message-frame
      (hasheq 'jsonrpc "2.0"
              'method "$/cancelRequest"
              'params (hasheq 'id "missing")))
     (message-frame (open-message fixture-uri fixture-text))
     (message-frame (hover-message fixture-uri 9 7 "good-hover"))
     (message-frame (shutdown-message "mixed-shutdown"))
     (message-frame exit-message)))
  (define result
    (run-input mixed-input
               #:query (lambda (_path _position) (stub-result 163 15))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 1)
  (define responses (response-values result))
  (check-equal?
   responses
   (list
    (success-response "mixed-init" initialize-result)
    parse-error-response
    invalid-request-response
    (method-not-found-response "missing")
    (invalid-params-response "bad-hover")
    (success-response "good-hover" stub-hover-result)
    (success-response "mixed-shutdown" (json-null))))
  (define raw-output (get-output-bytes (exchange-output result)))
  (for ([forbidden
         (in-list
          '(#"hash-ref" #"exception" #"snapshot" #".rkt" #"diagnostic"))])
    (check-false (regexp-match? (regexp-quote forbidden) raw-output))))

(define missing-export (gensym 'missing-export))

(define (module-exports? name)
  (not
   (eq? (dynamic-require
         lsp-module-path
         name
         (lambda () missing-export))
        missing-export)))

(test-case "public surface and caller-owned ports remain unchanged"
  (check-equal? (procedure-arity lsp:run-lsp-server) 3)
  (check-equal? (procedure-arity support:run-lsp-server/with-query) 4)
  (for ([name
         (in-list
          '(run-lsp-server/with-query
            classify-json-rpc-message
            rpc-request
            rpc-notification
            hover-params?
            request-id?))])
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
  (define result
    (run-messages
     (list
      7
      (initialize-message)
      (hasheq 'jsonrpc "2.0"
              'id "bad"
              'method "textDocument/hover"
              'params (hasheq))
      (shutdown-message)
      exit-message)
     #:public? #t))
  (check-clean result)
  (check-equal?
   (response-values result)
   (list
    invalid-request-response
    (success-response "initialize" initialize-result)
    (invalid-params-response "bad")
    (success-response "shutdown" (json-null)))))

(test-case "production source keeps validation in the thin static adapter"
  (define source (file->string lsp-module-path))
  (for ([forbidden
         (in-list
          '("(eval "
            "dynamic-require"
            "exn-message"
            "batch"
            "parse.rkt"
            "type.rkt"
            "eval.rkt"
            "checker.rkt"
            "main.rkt"
            "type-signature-specs"))])
    (check-false (string-contains? source forbidden))))
