#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/path
         racket/runtime-path
         rackunit
         (prefix-in lsp: "../../../aloe/lsp.rkt")
         (prefix-in support:
                    (submod "../../../aloe/lsp.rkt" test-support))
         "../../../aloe/definition-query.rkt")

(define-runtime-path fixtures-path "fixtures")
(define-runtime-path shapes-path "fixtures/shapes.aloe")
(define-runtime-path point-path "fixtures/point.aloe")
(define-runtime-path wide-path "fixtures/wide.aloe")
(define-runtime-path wide-user-path "fixtures/wide-user.aloe")
(define-runtime-path option-path "../../../lib/option.aloe")

(define (normalized path)
  (simplify-path (path->complete-path path) #f))

(define (path-uri path)
  (url->string (path->url (normalized path))))

(define normalized-shapes-path (normalized shapes-path))
(define normalized-fixtures-path (normalized fixtures-path))
(define shapes-bytes (file->bytes normalized-shapes-path))
(define shapes-text (bytes->string/utf-8 shapes-bytes))

;; The client may percent-encode a URI; a jump into it echoes these bytes.
(define shapes-uri
  (regexp-replace
   #rx"shapes\\.aloe$"
   (url->string (path->url normalized-shapes-path))
   "%73hapes%2Ealoe"))

(define point-uri (path-uri point-path))
(define wide-uri (path-uri wide-path))
(define wide-user-uri (path-uri wide-user-path))
(define option-uri (path-uri option-path))

(define expected-initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync (hasheq 'openClose #t 'change 1)
    'hoverProvider #t
    'completionProvider (hasheq 'triggerCharacters (list " "))
    'definitionProvider #t)
   'serverInfo (hasheq 'name "aloe-lsp")))

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

(define (position-request method uri line character id)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method method
   'params
   (hasheq
    'textDocument (hasheq 'uri uri)
    'position (hasheq 'line line 'character character))))

(define (definition-message uri line character id)
  (position-request "textDocument/definition" uri line character id))

(define (hover-message uri line character id)
  (position-request "textDocument/hover" uri line character id))

(define (shutdown-message [id "shutdown"])
  (hasheq 'jsonrpc "2.0" 'id id 'method "shutdown"))

(define exit-message
  (hasheq 'jsonrpc "2.0" 'method "exit"))

;; Initialize, the messages, then a clean shutdown and exit.
(define (session messages)
  (append
   (list (initialize-message) initialized-message)
   messages
   (list (shutdown-message) exit-message)))

(define (success-response id result)
  (hasheq 'jsonrpc "2.0" 'id id 'result result))

(define (error-response id code message)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'error (hasheq 'code code 'message message)))

(define initialize-response
  (success-response "initialize" expected-initialize-result))

(define shutdown-response
  (success-response "shutdown" (json-null)))

;; One LSP Location: a URI and a zero-based line:character range.
(define (location uri start-line start-character end-line end-character)
  (hasheq
   'uri uri
   'range
   (hasheq
    'start (hasheq 'line start-line 'character start-character)
    'end (hasheq 'line end-line 'character end-character))))

(struct exchange (status input output error responses) #:transparent)

(define (no-hover _path _position #:document-path [_document-path #f])
  #f)

(define (no-completions _text _position #:source-path _path)
  '())

;; The public server, or the test-support seam with a definition stub.
(define (run-exchange messages #:definition-query [definition-query #f])
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define status
    (if definition-query
        (support:run-lsp-server/with-queries
         input output error-output no-hover no-completions
         #:definition-query definition-query)
        (lsp:run-lsp-server input output error-output)))
  (exchange status
            input
            output
            error-output
            (decode-frames (get-output-bytes output))))

(define (check-clean result expected-responses)
  (check-equal? (exchange-status result) 0)
  (check-equal? (exchange-responses result) expected-responses)
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (for ([port (in-list (list (exchange-input result)
                             (exchange-output result)
                             (exchange-error result)))])
    (check-false (port-closed? port))))

(define (fixture-entries)
  (directory-list normalized-fixtures-path))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-file "definition-003-~a"
                         'directory
                         (find-system-path 'temp-dir)))
  (dynamic-wind
    void
    (lambda () (procedure (normalized directory)))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(test-case "initialize advertises definition as the last capability"
  (define result (run-exchange (session '())))
  (check-clean result (list initialize-response shutdown-response))
  (check-equal?
   (hash-ref (hash-ref (first (exchange-responses result)) 'result)
             'capabilities)
   (hash-ref expected-initialize-result 'capabilities)))

(test-case "class names jump into the document, a file, and a library"
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (definition-message shapes-uri 26 7 "box")
       (definition-message shapes-uri 9 12 "point")
       (definition-message shapes-uri 10 12 "option")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "box" (location shapes-uri 6 15 6 18))
    (success-response "point" (location point-uri 0 14 0 19))
    (success-response "option" (location option-uri 0 15 0 21))
    shutdown-response)))

(test-case "ranges count UTF-16 units in the defining file's text"
  (define result
    (run-exchange
     (session
      (list
       (open-message wide-user-uri (file->string wide-user-path))
       (definition-message wide-user-uri 1 11 "wide")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "wide" (location wide-uri 0 33 0 37))
    shutdown-response)))

(test-case "a queried library's header answers with that library's URI"
  (define result
    (run-exchange
     (session
      (list
       (open-message option-uri (file->string option-path))
       (definition-message option-uri 0 15 "header")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "header" (location option-uri 0 15 0 21))
    shutdown-response)))

(test-case "a dirty buffer jumps within its own text and leaves no sibling"
  (define original-entries (fixture-entries))
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (change-message shapes-uri (string-append "\n" shapes-text) 2)
       (definition-message shapes-uri 27 7 "dirty-box")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "dirty-box" (location shapes-uri 7 15 7 18))
    shutdown-response))
  (check-equal? (fixture-entries) original-entries)
  (check-equal? (file->bytes normalized-shapes-path) shapes-bytes))

(test-case "misses, unsupported documents, and invalid positions are null"
  (define original-entries (fixture-entries))
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (definition-message shapes-uri 13 13 "miss")
       (definition-message point-uri 0 14 "unopened")
       (open-message "untitled:Untitled-1" "(define x 1)")
       (definition-message "untitled:Untitled-1" 0 8 "untitled")
       (definition-message shapes-uri 500 0 "past-last-line")
       (definition-message shapes-uri 0 900 "past-line-end")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "miss" (json-null))
    (success-response "unopened" (json-null))
    (success-response "untitled" (json-null))
    (success-response "past-last-line" (json-null))
    (success-response "past-line-end" (json-null))
    shutdown-response))
  (check-equal? (fixture-entries) original-entries))

(test-case "a buffer that fails checking is null"
  (define original-entries (fixture-entries))
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri
                     (string-append shapes-text
                                    "(define oops (1 + \"x\"))\n"))
       (definition-message shapes-uri 6 15 "type-error")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "type-error" (json-null))
    shutdown-response))
  (check-equal? (fixture-entries) original-entries)
  (check-equal? (file->bytes normalized-shapes-path) shapes-bytes))

(test-case "a malformed buffer is null and the server keeps answering"
  (define original-entries (fixture-entries))
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (change-message shapes-uri "(define-class" 2)
       (definition-message shapes-uri 0 1 "malformed")
       (change-message shapes-uri shapes-text 3)
       (definition-message shapes-uri 6 15 "recovered")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "malformed" (json-null))
    (success-response "recovered" (location shapes-uri 6 15 6 18))
    shutdown-response))
  (check-equal? (fixture-entries) original-entries)
  (check-equal? (file->bytes normalized-shapes-path) shapes-bytes))

(test-case "definition requests follow hover's params and lifecycle errors"
  (define missing-position
    (hasheq
     'jsonrpc "2.0"
     'id "no-position"
     'method "textDocument/definition"
     'params (hasheq 'textDocument (hasheq 'uri shapes-uri))))
  (check-clean
   (run-exchange
    (session
     (list
      (open-message shapes-uri shapes-text)
      missing-position)))
   (list
    initialize-response
    (error-response "no-position" -32602 "Invalid params")
    shutdown-response))
  (check-clean
   (run-exchange
    (cons (definition-message shapes-uri 6 15 "early")
          (session '())))
   (list
    (error-response "early" -32002 "Server not initialized")
    initialize-response
    shutdown-response))
  (check-clean
   (run-exchange
    (list
     (initialize-message)
     initialized-message
     (open-message shapes-uri shapes-text)
     (shutdown-message)
     (definition-message shapes-uri 6 15 "late")
     exit-message))
   (list
    initialize-response
    shutdown-response
    (error-response "late" -32600 "Invalid Request"))))

(test-case "the definition hook is queried once per answerable request"
  (check-equal? (procedure-arity support:run-lsp-server/with-queries) 5)
  (define original-entries (fixture-entries))
  (define calls '())
  (define (counting-query path position
                          #:document-path [document-path 'absent])
    (set! calls (append calls (list (list path position document-path))))
    #f)
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (definition-message shapes-uri 6 15 "clean")
       (definition-message point-uri 0 14 "unopened")
       (definition-message shapes-uri 500 0 "invalid")
       (change-message shapes-uri (string-append "\n" shapes-text) 2)
       (definition-message shapes-uri 7 15 "dirty")))
     #:definition-query counting-query))
  (check-clean
   result
   (list
    initialize-response
    (success-response "clean" (json-null))
    (success-response "unopened" (json-null))
    (success-response "invalid" (json-null))
    (success-response "dirty" (json-null))
    shutdown-response))
  (check-equal? (length calls) 2)
  (check-equal? (first calls) (list normalized-shapes-path 131 'absent))
  (define sibling-call (second calls))
  (define sibling-path (first sibling-call))
  (check-not-equal? sibling-path normalized-shapes-path)
  (check-equal? (simplify-path (path-only sibling-path) #f)
                (path-only normalized-shapes-path))
  (check-equal? (second sibling-call) 132)
  (check-equal? (third sibling-call) normalized-shapes-path)
  (check-false (file-exists? sibling-path))
  (check-equal? (fixture-entries) original-entries))

(test-case "a snapshot failure is specific and the server recovers"
  (call-with-temporary-directory
   (lambda (directory)
     (define blocker (build-path directory "not-a-directory"))
     (define blocker-bytes #"unchanged blocker")
     (call-with-output-file blocker
       (lambda (output) (write-bytes blocker-bytes output)))
     (define blocked-uri (path-uri (build-path blocker "root.aloe")))
     (define original-entries (directory-list directory))
     (define result
       (run-exchange
        (session
         (list
          (open-message blocked-uri "dirty")
          (definition-message blocked-uri 0 0 "blocked")
          (open-message shapes-uri shapes-text)
          (definition-message shapes-uri 6 15 "after")))))
     (check-clean
      result
      (list
       initialize-response
       (error-response
        "blocked"
        -32803
        "unable to create synchronized document snapshot")
       (success-response "after" (location shapes-uri 6 15 6 18))
       shutdown-response))
     (check-equal? (file->bytes blocker) blocker-bytes)
     (check-equal? (directory-list directory) original-entries))))

;; A stub that answers its first call with value and later calls truly.
(define (first-call-stub value)
  (define called? #f)
  (lambda (path position #:document-path [document-path path])
    (cond
      [called?
       (query-definition-at path position #:document-path document-path)]
      [else
       (set! called? #t)
       value])))

(test-case "a value that is not a result is a generic definition failure"
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (definition-message shapes-uri 6 15 "not-a-result")
       (definition-message shapes-uri 6 15 "after")))
     #:definition-query (first-call-stub 'not-a-result)))
  (check-clean
   result
   (list
    initialize-response
    (error-response
     "not-a-result" -32803 "unable to produce definition result")
    (success-response "after" (location shapes-uri 6 15 6 18))
    shutdown-response)))

(test-case "a result whose range cannot be converted is null"
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (definition-message shapes-uri 6 15 "out-of-range")
       (definition-message shapes-uri 6 15 "after")))
     #:definition-query
     (first-call-stub
      (definition-query-result
       (srcloc normalized-shapes-path 1 0 1 500)
       "(define x 1)\n"))))
  (check-clean
   result
   (list
    initialize-response
    (success-response "out-of-range" (json-null))
    (success-response "after" (location shapes-uri 6 15 6 18))
    shutdown-response)))

(test-case "hover on the same document is unchanged"
  (define result
    (run-exchange
     (session
      (list
       (open-message shapes-uri shapes-text)
       (hover-message shapes-uri 35 10 "hover")))))
  (check-clean
   result
   (list
    initialize-response
    (success-response
     "hover"
     (hasheq
      'contents
      (hasheq
       'kind "plaintext"
       'value
       (string-append
        "type: (Class Point)\n"
        "from: (Class Point@tests/editor/definition/fixtures/point.aloe)\n"
        "messages:\n"
        "  new : (Int Int) -> Point"))
      'range
      (hasheq
       'start (hasheq 'line 35 'character 10)
       'end (hasheq 'line 35 'character 15))))
    shutdown-response)))
