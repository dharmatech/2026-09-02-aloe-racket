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
                    (submod "../../../aloe/lsp.rkt" test-support)))

(define-runtime-path lsp-module-path "../../../aloe/lsp.rkt")
(define-runtime-path fixture-path "fixtures/point.aloe")

(define normalized-fixture-path
  (simplify-path (path->complete-path fixture-path) #f))
(define fixture-text
  (bytes->string/utf-8 (file->bytes normalized-fixture-path)))
(define fixture-uri
  (url->string (path->url normalized-fixture-path)))

(define canonical-content-type
  #"Content-Type: application/vscode-jsonrpc; charset=utf-8")
(define legacy-content-type
  #"Content-Type: application/vscode-jsonrpc; charset=utf8")

(define (length-header body [name "Content-Length"] [length #f])
  (string->bytes/latin-1
   (format "~a: ~a" name (or length (bytes-length body)))))

(define (body-frame body [header-lines (list (length-header body))])
  (bytes-append
   (apply
    bytes-append
    (for/list ([line (in-list header-lines)])
      (bytes-append line #"\r\n")))
   #"\r\n"
   body))

(define (message-body message)
  (jsexpr->bytes message))

(define (message-frame message [headers #f])
  (define body (message-body message))
  (body-frame body (or headers (list (length-header body)))))

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
         (error 'decode-output "non-canonical response header"))
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

(struct exchange (status input output error frames query-calls) #:transparent)

(define (run-bytes input-bytes
                   #:public? [public? #f]
                   #:query [query (lambda (_path _position) #f)])
  (define input (open-input-bytes input-bytes))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define calls 0)
  (define (counting-query path position)
    (set! calls (add1 calls))
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
            calls))

(define (frame-values result)
  (map output-frame-value (exchange-frames result)))

(define (check-open-ports result)
  (check-false (port-closed? (exchange-input result)))
  (check-false (port-closed? (exchange-output result)))
  (check-false (port-closed? (exchange-error result))))

(define (check-clean result)
  (check-equal? (exchange-status result) 0)
  (check-open-ports result)
  (check-equal? (get-output-bytes (exchange-error result)) #""))

(define (check-fatal input-bytes)
  (define result (run-bytes input-bytes))
  (check-equal? (exchange-status result) 1)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal? (get-output-bytes (exchange-output result)) #"")
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (check-open-ports result)
  result)

(define (initialize-message [id 1] [params (hasheq)])
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

(define expected-initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync (hasheq 'openClose #t 'change 1)
    'hoverProvider #t
    'completionProvider
    (hasheq 'triggerCharacters (list " ")))
   'serverInfo (hasheq 'name "aloe-lsp")))

(define expected-hover
  (hasheq
   'contents
   (hasheq
    'kind "plaintext"
    'value
    (string-append
     "type: (Point Int)\n"
     "messages:\n"
     "  x : () -> Int\n"
     "  y : () -> Int\n"
     "  + : ((Point Int)) -> (Point Int)\n"
     "  dist2 : ((Point Int)) -> Int"))
   'range
   (hasheq
    'start (hasheq 'line 9 'character 0)
    'end (hasheq 'line 9 'character 15))))

(define parse-error
  (hasheq
   'jsonrpc "2.0"
   'id (json-null)
   'error
   (hasheq
    'code -32700
    'message "Parse error")))

(define (canonical-frames messages)
  (apply bytes-append (map message-frame messages)))

(test-case "the accepted Point exchange remains six concatenated frames"
  (define result
    (run-bytes
     (canonical-frames
      (list
       (initialize-message)
       initialized-message
       (open-message fixture-uri fixture-text)
       (hover-message fixture-uri 9 7)
       (shutdown-message)
       exit-message))
     #:public? #t))
  (check-clean result)
  (check-equal?
   (frame-values result)
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
     'result (json-null)))))

(test-case "accepted headers are ordered flexibly and ASCII case-insensitively"
  (define initialize (initialize-message "header-init"))
  (define initialize-body (message-body initialize))
  (define initialized-body (message-body initialized-message))
  (define shutdown (shutdown-message "header-shutdown"))
  (define shutdown-body (message-body shutdown))
  (define exit-body (message-body exit-message))
  (define input
    (bytes-append
     (body-frame
      initialize-body
      (list canonical-content-type (length-header initialize-body)))
     (body-frame
      initialized-body
      (list (length-header initialized-body)
            legacy-content-type))
     (body-frame
      shutdown-body
      (list
       (length-header shutdown-body "cOnTeNt-LeNgTh")
       #"cOnTeNt-TyPe: APPLICATION/VSCODE-JSONRPC; CHARSET=UTF-8"))
     (body-frame
      exit-body
      (list (length-header exit-body "content-length")))))
  (define result (run-bytes input))
  (check-clean result)
  (check-equal? (length (exchange-frames result)) 2)
  (check-equal?
   (map (lambda (response) (hash-ref response 'id))
        (frame-values result))
   '("header-init" "header-shutdown")))

(test-case "UTF-8 byte lengths retain a non-ASCII string id at the next boundary"
  (define unicode-id "初😀")
  (define initialize
    (initialize-message
     unicode-id
     (hasheq 'clientInfo (hasheq 'name "λ😀尾"))))
  (define initialize-body (message-body initialize))
  (check-true
   (> (bytes-length initialize-body)
      (string-length (bytes->string/utf-8 initialize-body))))
  (define result
    (run-bytes
     (canonical-frames
      (list initialize (shutdown-message "終😀") exit-message))))
  (check-clean result)
  (check-equal?
   (map (lambda (response) (hash-ref response 'id))
        (frame-values result))
   (list unicode-id "終😀"))
  (for ([frame (in-list (exchange-frames result))])
    (check-equal? (output-frame-declared-length frame)
                  (bytes-length (output-frame-body frame)))))

(test-case "CRLF and Content-Length text inside JSON bodies do not reframe"
  (define id "body says Content-Length: 1")
  (define body
    (string->bytes/utf-8
     (string-append
      "{\r\n"
      "\"jsonrpc\": \"2.0\",\r\n"
      "\"id\": \"body says Content-Length: 1\",\r\n"
      "\"method\": \"initialize\",\r\n"
      "\"params\": {}\r\n"
      "}")))
  (define result
    (run-bytes
     (bytes-append
      (body-frame body)
      (message-frame (shutdown-message 44))
      (message-frame exit-message))))
  (check-clean result)
  (check-equal?
   (map (lambda (response) (hash-ref response 'id))
        (frame-values result))
   (list id 44)))

(test-case "bounded malformed JSON recovers before initialization"
  (define result
    (run-bytes
     (bytes-append
      (body-frame #"{\"jsonrpc\":\"2.0\",]")
      (message-frame (initialize-message "after-parse"))
      (message-frame (shutdown-message "clean-shutdown"))
      (message-frame exit-message))))
  (check-clean result)
  (check-equal?
   (frame-values result)
   (list
    parse-error
    (hasheq
     'jsonrpc "2.0"
     'id "after-parse"
     'result expected-initialize-result)
    (hasheq
     'jsonrpc "2.0"
     'id "clean-shutdown"
     'result (json-null)))))

(test-case "each complete malformed body gets one Parse Error and service continues"
  (define invalid-utf-8 (bytes #xff #xfe))
  (define result
    (run-bytes
     (bytes-append
      (message-frame (initialize-message))
      (body-frame #"")
      (body-frame invalid-utf-8)
      (body-frame #"{\"truncated\":")
      (body-frame #"{} trailing")
      (message-frame (hover-message "file:///not-open.aloe" 0 0 "later"))
      (message-frame (shutdown-message))
      (message-frame exit-message))))
  (check-clean result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (frame-values result)
   (append
    (list
     (hasheq
      'jsonrpc "2.0"
      'id 1
      'result expected-initialize-result))
    (make-list 4 parse-error)
    (list
     (hasheq
      'jsonrpc "2.0"
      'id "later"
      'result (json-null))
     (hasheq
      'jsonrpc "2.0"
      'id 2
      'result (json-null))))))

(test-case "malformed id fragments always use null and preserve lifecycle state"
  (define malformed-with-id #"{\"jsonrpc\":\"2.0\",\"id\":99,")
  (define uninitialized
    (run-bytes
     (bytes-append
      (body-frame malformed-with-id)
      (message-frame exit-message))))
  (check-equal? (exchange-status uninitialized) 1)
  (check-equal? (frame-values uninitialized) (list parse-error))
  (check-open-ports uninitialized)

  (define initialized
    (run-bytes
     (bytes-append
      (message-frame (initialize-message "still-initialized"))
      (body-frame malformed-with-id)
      (message-frame exit-message))))
  (check-equal? (exchange-status initialized) 1)
  (check-equal? (second (frame-values initialized)) parse-error)
  (check-open-ports initialized)

  (define shutdown
    (run-bytes
     (bytes-append
      (message-frame (initialize-message))
      (message-frame (shutdown-message))
      (body-frame malformed-with-id)
      (message-frame exit-message))))
  (check-clean shutdown)
  (check-equal? (third (frame-values shutdown)) parse-error))

(test-case "malformed and unsupported headers are fatal"
  (define fatal-headers
    (list
     #"Content-Length: 2\n\n{}"
     #"Content-Length: 2\r\r{}"
     #"Content-Length: 2\r\n{}"
     (bytes-append canonical-content-type #"\r\n\r\n{}")
     #"Content-Length: 2\r\nContent-Length: 2\r\n\r\n{}"
     (bytes-append
      canonical-content-type #"\r\n"
      legacy-content-type #"\r\n"
      #"Content-Length: 2\r\n\r\n{}")
     #"Content-Length: 2\r\nUnknown: value\r\n\r\n{}"
     (bytes-append #"Cont" (bytes #xff) #"ent-Length: 2\r\n\r\n{}")
     #"Content-Length:2\r\n\r\n{}"
     #"Content-Length: \r\n\r\n"
     #"Content-Length: +2\r\n\r\n{}"
     #"Content-Length: -2\r\n\r\n{}"
     #"Content-Length: 2.0\r\n\r\n{}"
     #"Content-Length: 2e0\r\n\r\n{}"
     #"Content-Length: #d2\r\n\r\n{}"
     #"Content-Length: 2junk\r\n\r\n{}"
     #"Content-Length:  2\r\n\r\n{}"
     #"Content-Length: 2 \r\n\r\n{}"
     #"Content-Length: 2\r\nContent-Type: application/vscode-jsonrpc; charset=utf-16\r\n\r\n{}"
     #"Content-Length: 2\r\nContent-Type: application/json; charset=utf-8\r\n\r\n{}"
     #": 2\r\n\r\n{}"
     #"Content-Type: \r\nContent-Length: 2\r\n\r\n{}"))
  (for ([bad-input (in-list fatal-headers)])
    (check-fatal bad-input)))

(test-case "premature EOF is fatal without a response or closed caller port"
  (for ([bad-input
         (in-list
          (list
           #""
           #"Content-Len"
           #"Content-Length: 2\r\n"
           #"Content-Length: 2\r\n\r\n"
           #"Content-Length: 2\r\n\r\n{"))])
    (check-fatal bad-input)))

(test-case "a response before fatal framing remains one complete frame"
  (define result
    (run-bytes
     (bytes-append
      (message-frame (initialize-message "written-first"))
      #"Content-Length: nope\r\n\r\n")))
  (check-equal? (exchange-status result) 1)
  (check-open-ports result)
  (check-equal? (exchange-query-calls result) 0)
  (check-equal?
   (frame-values result)
   (list
    (hasheq
     'jsonrpc "2.0"
     'id "written-first"
     'result expected-initialize-result))))

(test-case "fatal framing never scans forward to a valid-looking frame"
  (define valid-looking
    (canonical-frames
     (list
      (initialize-message "must-not-run")
      (shutdown-message)
      exit-message)))
  (for ([bad-prefix
         (in-list
          (list
           #"Unknown: value\r\n\r\n"
           #"Content-Length: 1000\r\n\r\nshort"))])
    (check-fatal (bytes-append bad-prefix valid-looking))))

(define missing-export (gensym 'missing-export))

(define (module-exports? name)
  (not
   (eq?
    (dynamic-require
     lsp-module-path
     name
     (lambda () missing-export))
    missing-export)))

(test-case "the normal module stays inert and caller-owned ports stay open"
  (check-true (procedure-arity-includes? lsp:run-lsp-server 3))
  (for ([private-name
         (in-list
          '(run-lsp-server/with-query
            read-frame
            write-frame
            decode-frame-body
            exn:fail:framing?))])
    (check-false (module-exports? private-name)))
  (define require-input (open-input-bytes #"not consumed"))
  (define require-output (open-output-bytes))
  (define require-error (open-output-bytes))
  (parameterize ([current-namespace (make-base-namespace)]
                 [current-input-port require-input]
                 [current-output-port require-output]
                 [current-error-port require-error])
    (dynamic-require lsp-module-path #f))
  (check-equal? (read-bytes 12 require-input) #"not consumed")
  (check-equal? (get-output-bytes require-output) #"")
  (check-equal? (get-output-bytes require-error) #"")
  (for ([port (in-list (list require-input require-output require-error))])
    (check-false (port-closed? port)))

  (define success
    (run-bytes
     (canonical-frames
      (list
       (initialize-message)
       (shutdown-message)
       exit-message))
     #:public? #t))
  (check-clean success)
  (define failure
    (run-bytes #"Content-Length: 2\r\n\r\n{" #:public? #t))
  (check-equal? (exchange-status failure) 1)
  (check-open-ports failure)
  (check-equal? (get-output-bytes (exchange-output failure)) #""))

(test-case "production framing is byte-oriented and bounded"
  (define source (file->string lsp-module-path))
  (for ([required
         (in-list
          '("read-byte"
            "read-bytes"
            "bytes-length"
            "bytes->string/utf-8"))])
    (check-true (string-contains? source required)))
  (for ([forbidden
         (in-list
          '("read-line"
            "read-bytes-line"
            "port->bytes"
            "port->string"))])
    (check-false (string-contains? source forbidden))))
