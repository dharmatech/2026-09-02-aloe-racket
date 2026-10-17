#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         (prefix-in lsp: "../../../aloe/lsp.rkt")
         (prefix-in support:
                    (submod "../../../aloe/lsp.rkt" test-support))
         "../../../aloe/host-manifest.rkt"
         (only-in "../../../aloe/host.rkt"
                  host-interface-methods
                  host-method-selector
                  host-method-parameter-types
                  host-method-return-type)
         "../../../host/racket/fs.rkt"
         "../../../host/racket/term.rkt")

(define-runtime-path configured-folder "fixtures/configured")
(define-runtime-path broken-folder "fixtures/broken")
(define-runtime-path aloemacs-main-path "../../../examples/aloemacs/main.aloe")
(define-runtime-path aloemacs-file-path "../../../examples/aloemacs/file.aloe")
(define-runtime-path gel-main-path "../../../gel/main.aloe")

(define (normalized path)
  (simplify-path (path->complete-path path) #f))

(define (path-uri path)
  (url->string (path->url (normalized path))))

(define uses-fs-path (normalized (build-path configured-folder "uses-fs.aloe")))
(define spot-path (normalized (build-path configured-folder "spot.aloe")))
(define failing-path (normalized (build-path configured-folder "failing.aloe")))
(define neighbor-path (normalized (build-path broken-folder "neighbor.aloe")))

(define uses-fs-uri (path-uri uses-fs-path))
(define spot-uri (path-uri spot-path))
(define failing-uri (path-uri failing-path))
(define neighbor-uri (path-uri neighbor-path))

(define uses-fs-bytes (file->bytes uses-fs-path))
(define uses-fs-text (bytes->string/utf-8 uses-fs-bytes))

(define fs-hosts (list (cons 'fs-host fs-interface)))

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

(define initialize-message
  (hasheq
   'jsonrpc "2.0"
   'id "initialize"
   'method "initialize"
   'params (hasheq)))

(define initialized-message
  (hasheq
   'jsonrpc "2.0"
   'method "initialized"
   'params (hasheq)))

(define (open-message uri text)
  (hasheq
   'jsonrpc "2.0"
   'method "textDocument/didOpen"
   'params
   (hasheq
    'textDocument
    (hasheq
     'uri uri
     'languageId "aloe"
     'version 1
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

(define (hover-message uri line character id)
  (position-request "textDocument/hover" uri line character id))

(define (definition-message uri line character id)
  (position-request "textDocument/definition" uri line character id))

(define (completion-message uri line character id)
  (position-request "textDocument/completion" uri line character id))

(define shutdown-message
  (hasheq 'jsonrpc "2.0" 'id "shutdown" 'method "shutdown"))

(define exit-message
  (hasheq 'jsonrpc "2.0" 'method "exit"))

;; Initialize, the messages, then a clean shutdown and exit.
(define (session messages)
  (append
   (list initialize-message initialized-message)
   messages
   (list shutdown-message exit-message)))

(define (success-response id result)
  (hasheq 'jsonrpc "2.0" 'id id 'result result))

(define initialize-response
  (success-response "initialize" expected-initialize-result))

(define shutdown-response
  (success-response "shutdown" (json-null)))

;; Each request's response, between initialize's and shutdown's.
(define (session-responses responses)
  (append (list initialize-response)
          responses
          (list shutdown-response)))

(define (lsp-range start-line start-character end-line end-character)
  (hasheq
   'start (hasheq 'line start-line 'character start-character)
   'end (hasheq 'line end-line 'character end-character)))

(define (location uri start-line start-character end-line end-character)
  (hasheq
   'uri uri
   'range (lsp-range start-line start-character end-line end-character)))

(define (hover-result text line start-character end-character)
  (hasheq
   'contents (hasheq 'kind "plaintext" 'value text)
   'range (lsp-range line start-character line end-character)))

;; A host's hover text, from its interface: there is no from: line, because
;; the type and the pathed type are the same.
(define (host-hover-text name interface)
  (apply
   string-append
   "type: "
   name
   "\nmessages:"
   (for/list ([method (in-list (host-interface-methods interface))])
     (format "\n  ~s : ~s -> ~s"
             (host-method-selector method)
             (host-method-parameter-types method)
             (host-method-return-type method)))))

(define fs-host-hover-text (host-hover-text "FsHost" fs-interface))

;; The FsHost completion items at line:character, in declaration order.
(define (fs-host-items line character)
  (for/list ([method (in-list (host-interface-methods fs-interface))])
    (define label (format "~s" (host-method-selector method)))
    (hasheq
     'label label
     'detail (format "~s -> ~s"
                     (host-method-parameter-types method)
                     (host-method-return-type method))
     'insertText label
     'textEdit
     (hasheq
      'range (lsp-range line character line character)
      'newText label))))

(struct exchange (status input output error responses) #:transparent)

;; The public server, or the test-support seam with three stubs.
(define (run-exchange messages
                      #:hover [hover #f]
                      #:definition [definition #f]
                      #:completion [completion #f])
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define status
    (if hover
        (support:run-lsp-server/with-queries
         input output error-output hover completion
         #:definition-query definition)
        (lsp:run-lsp-server input output error-output)))
  (exchange status
            input
            output
            error-output
            (decode-frames (get-output-bytes output))))

;; decode-frames has already checked that the output is nothing but frames.
(define (check-clean result expected-responses)
  (check-equal? (exchange-status result) 0)
  (check-equal? (exchange-responses result) expected-responses)
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (check-true (eof-object? (peek-byte (exchange-input result)))))

(define (snapshot-entries folder)
  (for/list ([entry (in-list (directory-list folder))]
             #:when (string-prefix? (path->string entry) "aloe-lsp-snapshot-"))
    entry))

(define uses-fs-shifted-text (string-append "\n" uses-fs-text))

(test-case "the product manifests name each main.aloe's one host"
  (check-equal? (read-document-hosts aloemacs-main-path)
                (document-hosts (list (cons 'fs-host fs-interface))))
  (check-equal? (read-document-hosts gel-main-path)
                (document-hosts (list (cons 'term term-interface))))
  (check-false (read-document-hosts aloemacs-file-path)))

(test-case "real queries answer with the folder's hosts, clean or dirty"
  (define completion-text
    (string-replace uses-fs-text
                    "(define here (fs-host current))"
                    "(define here (fs-host ))"))
  (check-not-equal? completion-text uses-fs-text)
  (define result
    (run-exchange
     (session
      (list
       (open-message uses-fs-uri uses-fs-text)
       (hover-message uses-fs-uri 3 14 "hover")
       (definition-message uses-fs-uri 4 16 "definition")
       (change-message uses-fs-uri completion-text 2)
       (completion-message uses-fs-uri 3 22 "completion")
       (change-message uses-fs-uri uses-fs-shifted-text 3)
       (hover-message uses-fs-uri 4 14 "dirty-hover")))))
  (check-clean
   result
   (session-responses
    (list
     (success-response "hover" (hover-result fs-host-hover-text 3 14 21))
     (success-response "definition" (location spot-uri 0 14 0 18))
     (success-response "completion" (fs-host-items 3 22))
     (success-response "dirty-hover"
                       (hover-result fs-host-hover-text 4 14 21)))))
  (define completion-response
    (findf (lambda (response) (equal? (hash-ref response 'id) "completion"))
           (exchange-responses result)))
  (check-equal?
   (for/list ([item (in-list (hash-ref completion-response 'result))])
     (hash-ref item 'detail))
   '("() -> String"
     "(String) -> String"
     "(String String) -> String"
     "(String) -> Bool"
     "(String) -> String"
     "(String) -> String"
     "(String) -> String"
     "(String) -> (List String)"
     "(String) -> String"
     "(String String) -> String"))
  (check-equal? (snapshot-entries configured-folder) '())
  (check-equal? (file->bytes uses-fs-path) uses-fs-bytes))

(test-case "a failing row is a miss, and the server keeps answering"
  (check-clean
   (run-exchange
    (session
     (list
      (open-message failing-uri (file->string failing-path))
      (hover-message failing-uri 0 14 "hover")
      (definition-message failing-uri 0 14 "definition")
      (completion-message failing-uri 0 14 "completion")
      (open-message uses-fs-uri uses-fs-text)
      (hover-message uses-fs-uri 3 14 "after"))))
   (session-responses
    (list
     (success-response "hover" (json-null))
     (success-response "definition" (json-null))
     (success-response "completion" '())
     (success-response "after" (hover-result fs-host-hover-text 3 14 21)))))
  (define calls 0)
  (define (counting-query path position
                          #:document-path [document path]
                          #:hosts [hosts 'none])
    (set! calls (add1 calls))
    #f)
  (define (counting-completion text position
                               #:source-path source
                               #:hosts [hosts 'none])
    (set! calls (add1 calls))
    '())
  (check-clean
   (run-exchange
    (session
     (list
      (open-message failing-uri (file->string failing-path))
      (hover-message failing-uri 0 14 "hover")
      (definition-message failing-uri 0 14 "definition")
      (completion-message failing-uri 0 14 "completion")))
    #:hover counting-query
    #:definition counting-query
    #:completion counting-completion)
   (session-responses
    (list
     (success-response "hover" (json-null))
     (success-response "definition" (json-null))
     (success-response "completion" '()))))
  (check-equal? calls 0)
  (check-equal? (snapshot-entries configured-folder) '()))

(test-case "a broken manifest leaves its folder unconfigured"
  (check-clean
   (run-exchange
    (session
     (list
      (open-message neighbor-uri (file->string neighbor-path))
      (hover-message neighbor-uri 5 20 "hover")
      (definition-message neighbor-uri 5 20 "definition"))))
   (session-responses
    (list
     (success-response
      "hover"
      (hover-result
       (string-append
        "type: (Class Mark)\n"
        "from: (Class Mark@tests/editor/host-queries/fixtures/broken/neighbor.aloe)\n"
        "messages:\n"
        "  new : (Int) -> Mark")
       5 20 24))
     (success-response "definition" (location neighbor-uri 0 14 0 18))))))

(test-case "the row's hosts reach each query, through the sibling too"
  (define records '())
  (define (record! kind path document hosts)
    (set! records (append records (list (list kind path document hosts)))))
  (define ((recording-query kind) path position
                                  #:document-path [document path]
                                  #:hosts [hosts 'none])
    (record! kind path document hosts)
    #f)
  (define (recording-completion text position
                                #:source-path source
                                #:hosts [hosts 'none])
    (record! 'completion source source hosts)
    '())
  (check-clean
   (run-exchange
    (session
     (list
      (open-message uses-fs-uri uses-fs-text)
      (hover-message uses-fs-uri 3 14 "hover")
      (definition-message uses-fs-uri 4 16 "definition")
      (completion-message uses-fs-uri 3 22 "completion")
      (change-message uses-fs-uri uses-fs-shifted-text 2)
      (hover-message uses-fs-uri 4 14 "dirty-hover")))
    #:hover (recording-query 'hover)
    #:definition (recording-query 'definition)
    #:completion recording-completion)
   (session-responses
    (list
     (success-response "hover" (json-null))
     (success-response "definition" (json-null))
     (success-response "completion" '())
     (success-response "dirty-hover" (json-null)))))
  (check-equal? (map first records) '(hover definition completion hover))
  (for ([record (in-list records)])
    (define hosts (fourth record))
    (check-equal? hosts fs-hosts)
    (check-eq? (cdr (first hosts)) fs-interface)
    (check-equal? (third record) uses-fs-path))
  (for ([record (in-list (take records 3))])
    (check-equal? (second record) uses-fs-path))
  (define sibling-path (second (last records)))
  (check-not-equal? sibling-path uses-fs-path)
  (check-true
   (string-prefix? (path->string (file-name-from-path sibling-path))
                   "aloe-lsp-snapshot-"))
  (check-false (file-exists? sibling-path))
  (check-equal? (snapshot-entries configured-folder) '()))

(test-case "documents without a row get today's call"
  (for ([path (in-list (list spot-path neighbor-path))])
    (define uri (path-uri path))
    (define calls 0)
    (define (counting-query query-path position
                            #:document-path [document query-path])
      (set! calls (add1 calls))
      #f)
    (define (counting-completion text position #:source-path source)
      (set! calls (add1 calls))
      '())
    (check-clean
     (run-exchange
      (session
       (list
        (open-message uri (file->string path))
        (hover-message uri 0 1 "hover")
        (definition-message uri 0 1 "definition")
        (completion-message uri 0 1 "completion")))
      #:hover counting-query
      #:definition counting-query
      #:completion counting-completion)
     (session-responses
      (list
       (success-response "hover" (json-null))
       (success-response "definition" (json-null))
       (success-response "completion" '()))))
    (check-equal? calls 3 (path->string path))))
