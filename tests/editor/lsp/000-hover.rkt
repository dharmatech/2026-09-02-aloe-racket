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
(define fixture-bytes (file->bytes normalized-fixture-path))
(define fixture-text (bytes->string/utf-8 fixture-bytes))

(define fixture-uri
  (regexp-replace
   #rx"point\\.aloe$"
   (url->string (path->url normalized-fixture-path))
   "%70oint%2Ealoe"))

(define expected-hover-text
  (string-append
   "type: (Point Int)\n"
   "messages:\n"
   "  x : () -> Int\n"
   "  y : () -> Int\n"
   "  + : ((Point Int)) -> (Point Int)\n"
   "  dist2 : ((Point Int)) -> Int"))

(define expected-initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync
    (hasheq 'openClose #t 'change 1)
    'hoverProvider #t)
   'serverInfo
   (hasheq 'name "aloe-lsp")))

(define expected-hover
  (hasheq
   'contents
   (hasheq
    'kind "plaintext"
    'value expected-hover-text)
   'range
   (hasheq
    'start (hasheq 'line 9 'character 0)
    'end (hasheq 'line 9 'character 15))))

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

(define (initialize-message [id 1])
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

(define (hover-message uri line character [id "point-hover"])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/hover"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri)
    'position (hasheq 'line line 'character character))))

(define (shutdown-message [id 2])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "shutdown"))

(define exit-message
  (hasheq
   'jsonrpc "2.0"
   'method "exit"))

(define (successful-messages
         #:uri [uri fixture-uri]
         #:text [text fixture-text]
         #:line [line 9]
         #:character [character 7])
  (list
   (initialize-message)
   initialized-message
   (open-message uri text)
   (hover-message uri line character)
   (shutdown-message)
   exit-message))

(struct exchange (status input output error responses) #:transparent)

(define (run-exchange run messages)
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define status (run input output error-output))
  (exchange status
            input
            output
            error-output
            (decode-frames (get-output-bytes output))))

(define (check-successful-ports result)
  (check-false (port-closed? (exchange-input result)))
  (check-false (port-closed? (exchange-output result)))
  (check-false (port-closed? (exchange-error result)))
  (check-equal? (get-output-bytes (exchange-error result)) #""))

(define missing-export (gensym 'missing-export))

(define (module-exports? name)
  (not
   (eq? (dynamic-require
         lsp-module-path
         name
         (lambda () missing-export))
        missing-export)))

(test-case "normal module is inert and has the exact narrow public surface"
  (check-true (procedure-arity-includes? lsp:run-lsp-server 3))
  (for ([name
         (in-list
          '(run-lsp-server/with-query
            query-expression-at
            expression-query-result
            expression-query-result?
            signature-spec
            signature-spec?
            read-frame
            write-frame
            open-document
            uri->local-path
            lsp-position->query-position
            offset->lsp-position))])
    (check-false (module-exports? name)))
  (define input (open-input-bytes #""))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (parameterize ([current-namespace (make-base-namespace)]
                 [current-input-port input]
                 [current-output-port output]
                 [current-error-port error-output])
    (dynamic-require lsp-module-path #f))
  (check-equal? (get-output-bytes output) #"")
  (check-equal? (get-output-bytes error-output) #"")
  (check-false (port-closed? input))
  (check-false (port-closed? output))
  (check-false (port-closed? error-output)))

(test-case "recorded public exchange returns the exact framed Point hover"
  (define result
    (run-exchange lsp:run-lsp-server (successful-messages)))
  (check-equal? (exchange-status result) 0)
  (check-successful-ports result)
  (check-equal?
   (exchange-responses result)
   (list
    (hasheq
     'jsonrpc "2.0"
     'id 1
     'result expected-initialize-result)
    (hasheq
     'jsonrpc "2.0"
     'id "point-hover"
     'result expected-hover)
    (hasheq
     'jsonrpc "2.0"
     'id 2
     'result (json-null))))
  (define capabilities
    (hash-ref
     (hash-ref (first (exchange-responses result)) 'result)
     'capabilities))
  (check-equal? capabilities
                (hash-ref expected-initialize-result 'capabilities))
  (check-false (hash-has-key? capabilities 'completionProvider))
  (check-false (hash-has-key? capabilities 'diagnosticProvider)))

(test-case "test-support query is called once and wholly supplies hover data"
  (define calls '())
  (define stub-result
    (query:expression-query-result
     '(Stub String)
     (list
      (query:signature-spec 'second '(Int) 'Bool)
      (query:signature-spec 'first '() 'String))
     (srcloc 'ignored 100 200 163 15)))
  (define (counting-query path position)
    (set! calls (cons (list path position) calls))
    stub-result)
  (define result
    (run-exchange
     (lambda (input output error-output)
       (support:run-lsp-server/with-query
        input output error-output counting-query))
     (successful-messages)))
  (check-equal? (exchange-status result) 0)
  (check-successful-ports result)
  (check-equal? (length calls) 1)
  (check-equal? (simplify-path (first (first calls)) #f)
                normalized-fixture-path)
  (check-equal? (second (first calls)) 170)
  (define hover-result
    (hash-ref (second (exchange-responses result)) 'result))
  (check-equal?
   (hash-ref (hash-ref hover-result 'contents) 'value)
   (string-append
    "type: (Stub String)\n"
    "messages:\n"
    "  second : (Int) -> Bool\n"
    "  first : () -> String"))
  (check-equal? (hash-ref hover-result 'range)
                (hash-ref expected-hover 'range)))

(test-case "invalid synchronized positions return null without a query"
  (for ([position (in-list '((11 0) (9 16)))])
    (define calls 0)
    (define (counting-query _path _position)
      (set! calls (add1 calls))
      #f)
    (define result
      (run-exchange
       (lambda (input output error-output)
         (support:run-lsp-server/with-query
          input output error-output counting-query))
       (successful-messages
        #:line (first position)
        #:character (second position))))
    (check-equal? (exchange-status result) 0)
    (check-successful-ports result)
    (check-equal? calls 0)
    (check-equal?
     (hash-ref (second (exchange-responses result)) 'result)
     (json-null))))

(test-case "dirty synchronized text queries a snapshot without changing the file"
  (define original-bytes (file->bytes normalized-fixture-path))
  (define original-directory-entries
    (directory-list (path-only normalized-fixture-path)))
  (define dirty-text
    (string-replace fixture-text "(Point new 1 2)" "(Point new 1 3)"))
  (define calls 0)
  (define result
    (run-exchange
     (lambda (input output error-output)
       (support:run-lsp-server/with-query
        input
        output
        error-output
        (lambda (_path _position)
          (set! calls (add1 calls))
          #f)))
     (successful-messages #:text dirty-text)))
  (check-equal? (exchange-status result) 0)
  (check-successful-ports result)
  (check-equal? calls 1)
  (check-equal?
   (hash-ref (second (exchange-responses result)) 'result)
   (json-null))
  (check-equal? (file->bytes normalized-fixture-path) original-bytes)
  (check-equal? (directory-list (path-only normalized-fixture-path))
                original-directory-entries))

(test-case "unsupported and unopened URIs safely return null"
  (define cases
    (list
     (list fixture-uri #f)
     (list "untitled:point" #t)
     (list "file://remote.example/tmp/point.aloe" #t)))
  (for ([case (in-list cases)])
    (define uri (first case))
    (define should-open? (second case))
    (define calls 0)
    (define messages
      (append
       (list (initialize-message) initialized-message)
       (if should-open?
           (list (open-message uri fixture-text))
           '())
       (list
        (hover-message uri 9 7)
        (shutdown-message)
        exit-message)))
    (define result
      (run-exchange
       (lambda (input output error-output)
         (support:run-lsp-server/with-query
          input
          output
          error-output
          (lambda (_path _position)
            (set! calls (add1 calls))
            #f)))
       messages))
    (check-equal? (exchange-status result) 0)
    (check-successful-ports result)
    (check-equal? calls 0)
    (check-equal?
     (hash-ref (second (exchange-responses result)) 'result)
     (json-null))))

(test-case "production adapter has no private Aloe or method-catalog copy"
  (define source (file->string lsp-module-path))
  (for ([forbidden-module
         (in-list
          '("main.rkt"
            "parse.rkt"
            "eval.rkt"
            "type.rkt"
            "driver.rkt"
            "host.rkt"
            "signature-catalog.rkt"
            "private/expression-selection.rkt"
            "private/expression-observation.rkt"))])
    (check-false (string-contains? source forbidden-module)))
  (for ([forbidden-catalog-text
         (in-list
          '("type-signature-specs"
            "Point"
            "dist2"
            "starts-with?"
            "empty?"))])
    (check-false (string-contains? source forbidden-catalog-text))))
