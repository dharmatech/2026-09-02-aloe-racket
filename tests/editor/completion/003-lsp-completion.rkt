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
         (prefix-in completion: "../../../aloe/completion-query.rkt")
         (prefix-in hover: "../../../aloe/expression-query.rkt"))

(define-runtime-path lsp-module-path "../../../aloe/lsp.rkt")
(define-runtime-path point-path "../../../examples/point.aloe")
(define-runtime-path boids-path "../../../examples/boids.aloe")

(define point-path* (simplify-path (path->complete-path point-path) #f))
(define boids-path* (simplify-path (path->complete-path boids-path) #f))
(define point-bytes (file->bytes point-path*))
(define point-source (bytes->string/utf-8 point-bytes))
(define boids-source (file->string boids-path*))
(define point-uri (url->string (path->url point-path*)))
(define boids-uri (url->string (path->url boids-path*)))

(define initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync
    (hasheq
     'openClose #t
     'change 1)
    'hoverProvider #t
    'completionProvider
    (hasheq
     'triggerCharacters (list " ")))
   'serverInfo
   (hasheq
    'name "aloe-lsp")))

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
    'textDocument
    (hasheq 'uri uri 'version version)
    'contentChanges
    (list (hasheq 'text text)))))

(define (completion-message uri line character id
                            #:extra [extra (hasheq)])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/completion"
   'params
   (hash-set*
    extra
    'textDocument (hasheq 'uri uri)
    'position (hasheq 'line line 'character character))))

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
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "shutdown"))

(define exit-message
  (hasheq
   'jsonrpc "2.0"
   'method "exit"))

(define (success-response id result)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'result result))

(define (error-response id code message)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'error
   (hasheq
    'code code
    'message message)))

(define initialize-response
  (success-response "initialize" initialize-result))

(define shutdown-response
  (success-response "shutdown" (json-null)))

(define completion-failure-message
  "unable to produce completion result")

(struct exchange (status input output error responses) #:transparent)

(define (run-exchange run messages)
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define status (run input output error-output))
  (exchange
   status
   input
   output
   error-output
   (decode-frames (get-output-bytes output))))

(define (run-with-queries hover-query completion-query messages)
  (run-exchange
   (lambda (input output error-output)
     (support:run-lsp-server/with-queries
      input output error-output hover-query completion-query))
   messages))

(define (run-with-hover-query hover-query messages)
  (run-exchange
   (lambda (input output error-output)
     (support:run-lsp-server/with-query
      input output error-output hover-query))
   messages))

(define (check-clean result expected-responses)
  (check-equal? (exchange-status result) 0)
  (check-equal? (exchange-responses result) expected-responses)
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (for ([port
         (in-list
          (list (exchange-input result)
                (exchange-output result)
                (exchange-error result)))])
    (check-false (port-closed? port))))

(define (lsp-position line character)
  (hasheq 'line line 'character character))

(define (completion-item label detail insert-text
                         start-line start-character
                         end-line end-character)
  (hasheq
   'label label
   'detail detail
   'insertText insert-text
   'textEdit
   (hasheq
    'range
    (hasheq
     'start (lsp-position start-line start-character)
     'end (lsp-position end-line end-character))
    'newText insert-text)))

(define (call-with-test-directory procedure)
  (define directory
    (make-temporary-file "aloe-completion-003-~a" 'directory "/tmp"))
  (dynamic-wind
    void
    (lambda ()
      (procedure (simplify-path (path->complete-path directory) #f)))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (write-source path source)
  (call-with-output-file
   path
   #:exists 'truncate/replace
   (lambda (output)
     (display source output)
     (flush-output output))))

(define (directory-entry-names directory)
  (sort
   (map path->string (directory-list directory))
   string<?))

(define (stub-hover-result type [position 1] [span 1])
  (hover:expression-query-result
   type
   '()
   (srcloc 'injected-completion-003 1 0 position span)))

(define (phase-zero-export-names exports)
  (map car (cdr (assq 0 exports))))

(test-case "initialization and public surfaces are exact through every entry"
  (check-equal? (procedure-arity lsp:run-lsp-server) 3)
  (check-equal? (procedure-arity support:run-lsp-server/with-query) 4)
  (check-equal? (procedure-arity support:run-lsp-server/with-queries) 5)
  (define-values (value-exports syntax-exports)
    (module->exports lsp-module-path))
  (check-equal? (phase-zero-export-names value-exports)
                '(run-lsp-server))
  (check-equal? syntax-exports '())

  (define messages
    (list (initialize-message)
          (shutdown-message)
          exit-message))
  (define expected
    (list initialize-response shutdown-response))
  (for ([run
         (in-list
          (list
           lsp:run-lsp-server
           (lambda (input output error-output)
             (support:run-lsp-server/with-query
              input output error-output
              (lambda (_path _position) #f)))
           (lambda (input output error-output)
             (support:run-lsp-server/with-queries
              input output error-output
              (lambda (_path _position) #f)
              (lambda (_source _position #:source-path _path) '())))))])
    (define result (run-exchange run messages))
    (check-clean result expected)
    (define capabilities
      (hash-ref
       (hash-ref (first (exchange-responses result)) 'result)
       'capabilities))
    (check-equal? capabilities
                  (hash-ref initialize-result 'capabilities))
    (check-equal?
     (hash-ref capabilities 'completionProvider)
     (hasheq 'triggerCharacters (list " ")))
    (check-false
     (hash-has-key?
      (hash-ref capabilities 'completionProvider)
      'resolveProvider))
    (check-false
     (member "."
             (hash-ref
              (hash-ref capabilities 'completionProvider)
              'triggerCharacters)))))

(test-case "the two query seams route exact arguments without leaking"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "routing.aloe"))
     (define source "(1 + 2)")
     (write-source path source)
     (define uri (url->string (path->url path)))
     (define hover-calls '())
     (define completion-calls '())
     (define (hover-query query-path query-position)
       (set! hover-calls
             (append hover-calls
                     (list (list query-path query-position))))
       #f)
     (define (completion-query synchronized-source query-position
                               #:source-path source-path)
       (set! completion-calls
             (append completion-calls
                     (list
                      (list synchronized-source
                            query-position
                            source-path))))
       (list
        (completion:selector-completion-item
         "+" "(Int) -> Int" "+" 4 1)))
     (define result
       (run-with-queries
        hover-query
        completion-query
        (list
         (initialize-message)
         initialized-message
         (open-message uri source)
         (completion-message uri 0 4 "completion")
         (hover-message uri 0 1 "hover")
         (shutdown-message)
         exit-message)))
     (check-clean
      result
      (list
       initialize-response
       (success-response
        "completion"
        (list
         (completion-item "+" "(Int) -> Int" "+" 0 3 0 4)))
       (success-response "hover" (json-null))
       shutdown-response))
     (check-equal? completion-calls
                   (list (list source 5 path)))
     (check-equal? hover-calls
                   (list (list path 2)))
     (define protocol
       (bytes->string/utf-8 (get-output-bytes (exchange-output result))))
     (check-false (string-contains? protocol (path->string directory)))
     (check-equal? (get-output-bytes (exchange-error result)) #""))))

(define point-float-rows
  '(("x" "() -> Float")
    ("y" "() -> Float")
    ("+" "((Point Float)) -> (Point Float)")
    ("-" "((Point Float)) -> (Point Float)")
    ("dist2" "((Point Float)) -> Float")
    ("dot" "((Point Float)) -> Float")
    ("*" "(Float) -> (Point Float)")
    ("/" "(Float) -> (Point Float)")))

(test-case "real Boids completion preserves all eight Point rows"
  (define result
    (run-exchange
     lsp:run-lsp-server
     (list
      (initialize-message)
      initialized-message
      (open-message boids-uri boids-source)
      (completion-message boids-uri 19 37 "boids")
      (shutdown-message)
      exit-message)))
  (check-clean
   result
   (list
    initialize-response
    (success-response
     "boids"
     (for/list ([row (in-list point-float-rows)])
       (define label (first row))
       (define detail (second row))
       (completion-item label detail label 19 37 19 42)))
    shutdown-response)))

(test-case "dirty Point completion uses the buffer and leaves disk unchanged"
  (define original-entries
    (directory-entry-names (path-only point-path*)))
  (define dirty-source
    (string-append point-source "\n((Point new 1.0 2.0) d"))
  (define hover-calls 0)
  (define result
    (run-with-hover-query
     (lambda (_path _position)
       (set! hover-calls (add1 hover-calls))
       (stub-hover-result 'PointHover))
     (list
      (initialize-message)
      initialized-message
      (open-message point-uri point-source)
      (hover-message point-uri 0 0 "hover-before-change")
      (change-message point-uri dirty-source 2)
      (completion-message point-uri 34 22 "dirty-completion")
      (shutdown-message)
      exit-message)))
  (check-clean
   result
   (list
    initialize-response
    (success-response
     "hover-before-change"
     (hasheq
      'contents (hasheq 'kind "plaintext"
                        'value "type: PointHover\nmessages: none")
      'range
      (hasheq
       'start (lsp-position 0 0)
       'end (lsp-position 0 1))))
    (success-response
     "dirty-completion"
     (list
      (completion-item
       "dist2" "((Point Float)) -> Float" "dist2" 34 21 34 22)
      (completion-item
       "dot" "((Point Float)) -> Float" "dot" 34 21 34 22)))
    shutdown-response))
  (check-equal? hover-calls 1)
  (check-equal? (file->bytes point-path*) point-bytes)
  (check-equal? (directory-entry-names (path-only point-path*))
                original-entries))

(test-case "UTF-16 request and edit boundaries reject split surrogates"
  (define source "(\"😀\" l)")
  (define calls '())
  (define (completion-query synchronized-source query-position
                            #:source-path source-path)
    (set! calls
          (append calls
                  (list
                   (list synchronized-source
                         query-position
                         source-path))))
    (list
     (completion:selector-completion-item
      "len" "() -> Int" "len" 6 1)))
  (define result
    (run-with-queries
     (lambda (_path _position) #f)
     completion-query
     (list
      (initialize-message)
      initialized-message
      (open-message point-uri source)
      (completion-message point-uri 0 3 "split")
      (completion-message point-uri 0 7 "valid")
      (shutdown-message)
      exit-message)))
  (check-clean
   result
   (list
    initialize-response
    (success-response "split" '())
    (success-response
     "valid"
     (list
      (completion-item "len" "() -> Int" "len" 0 6 0 7)))
    shutdown-response))
  (check-equal? calls
                (list (list source 7 point-path*))))

(test-case "a missing root resolves sibling loads without snapshots"
  (call-with-test-directory
   (lambda (directory)
     (define support-path (build-path directory "support.aloe"))
     (define root-path (build-path directory "missing-root.aloe"))
     (define support-source
       (string-append
        "(define-class Loaded003\n"
        "  (fields (value Int))\n"
        "  (methods))\n"))
     (define source
       "(load \"support.aloe\")\n((Loaded003 new 1) v")
     (write-source support-path support-source)
     (define support-bytes (file->bytes support-path))
     (define original-entries (directory-entry-names directory))
     (define uri (url->string (path->url root-path)))
     (define result
       (run-with-hover-query
        (lambda (_path _position) #f)
        (list
         (initialize-message)
         initialized-message
         (open-message uri source)
         (completion-message uri 1 20 "loaded")
         (shutdown-message)
         exit-message)))
     (check-clean
      result
      (list
       initialize-response
       (success-response
        "loaded"
        (list
         (completion-item
          "value" "() -> Int" "value" 1 19 1 20)))
       shutdown-response))
     (check-false (file-exists? root-path))
     (check-equal? (file->bytes support-path) support-bytes)
     (check-equal? (directory-entry-names directory) original-entries))))

(test-case "validation misses are empty before any query invocation"
  (define source "(\"😀\" l)")
  (define calls 0)
  (define unopened-uri
    (url->string
     (path->url
      (build-path (path-only point-path*) "unopened-003.aloe"))))
  (define (completion-query _source _position #:source-path _path)
    (set! calls (add1 calls))
    (error 'unexpected-completion-query-003 "must not be called"))
  (define result
    (run-with-queries
     (lambda (_path _position) #f)
     completion-query
     (list
      (initialize-message)
      initialized-message
      (open-message point-uri source)
      (open-message "untitled:completion-003" source)
      (open-message "file://remote.example/tmp/completion-003.aloe" source)
      (completion-message unopened-uri 0 0 "unopened")
      (completion-message "untitled:completion-003" 0 0 "non-file")
      (completion-message
       "file://remote.example/tmp/completion-003.aloe" 0 0 "remote")
      (completion-message point-uri 10 0 "invalid-line")
      (completion-message point-uri 0 99 "invalid-character")
      (completion-message point-uri 0 3 "split-surrogate")
      (shutdown-message)
      exit-message)))
  (check-clean
   result
   (append
    (list initialize-response)
    (for/list ([id
                (in-list
                 '("unopened"
                   "non-file"
                   "remote"
                   "invalid-line"
                   "invalid-character"
                   "split-surrogate"))])
      (success-response id '()))
    (list shutdown-response)))
  (check-equal? calls 0))

(test-case "public no-match, ineligible, and source failures stay empty"
  (define no-match "(1 z)")
  (define ineligible "")
  (define failed "(1 d \"unfinished")
  (define result
    (run-with-hover-query
     (lambda (_path _position) #f)
     (list
      (initialize-message)
      initialized-message
      (open-message point-uri no-match)
      (completion-message point-uri 0 4 "no-match")
      (change-message point-uri ineligible 2)
      (completion-message point-uri 0 0 "ineligible")
      (change-message point-uri failed 3)
      (completion-message point-uri 0 4 "failed")
      (shutdown-message)
      exit-message)))
  (check-clean
   result
   (list
    initialize-response
    (success-response "no-match" '())
    (success-response "ineligible" '())
    (success-response "failed" '())
    shutdown-response)))

(test-case "completion params and lifecycle precedence remain exact"
  (define completion-calls 0)
  (define (completion-query _source _position #:source-path _path)
    (set! completion-calls (add1 completion-calls))
    '())
  (define malformed-params
    (list
     (cons "missing-params" #f)
     (cons "null-params" (json-null))
     (cons "scalar-params" 17)
     (cons "missing-document" (hasheq 'position (hasheq 'line 0 'character 0)))
     (cons "bad-document" (hasheq 'textDocument 17
                                    'position (hasheq 'line 0 'character 0)))
     (cons "missing-uri" (hasheq 'textDocument (hasheq)
                                  'position (hasheq 'line 0 'character 0)))
     (cons "bad-uri" (hasheq 'textDocument (hasheq 'uri 17)
                              'position (hasheq 'line 0 'character 0)))
     (cons "missing-position" (hasheq 'textDocument (hasheq 'uri point-uri)))
     (cons "bad-position" (hasheq 'textDocument (hasheq 'uri point-uri)
                                   'position 17))
     (cons "negative-line" (hasheq 'textDocument (hasheq 'uri point-uri)
                                    'position (hasheq 'line -1 'character 0)))
     (cons "bad-character" (hasheq 'textDocument (hasheq 'uri point-uri)
                                    'position (hasheq 'line 0 'character 1.0)))))
  (define (raw-completion id params-present? params)
    (hash-set*
     (hasheq
      'jsonrpc "2.0"
      'id id
      'method "textDocument/completion")
     'params
     (if params-present? params (hasheq))))
  (define preinitialize
    (hasheq
     'jsonrpc "2.0"
     'id "preinitialize"
     'method "textDocument/completion"))
  (define active-malformed
    (for/list ([entry (in-list malformed-params)])
      (define id (car entry))
      (define params (cdr entry))
      (if (string=? id "missing-params")
          (hasheq 'jsonrpc "2.0"
                  'id id
                  'method "textDocument/completion")
          (raw-completion id #t params))))
  (define completion-notification
    (hasheq
     'jsonrpc "2.0"
     'method "textDocument/completion"
     'params
     (hasheq
      'textDocument (hasheq 'uri point-uri)
      'position (hasheq 'line 0 'character 0))))
  (define valid-extra
    (completion-message
     point-uri 0 0 303
     #:extra
     (hasheq
      'context
      (hasheq 'triggerKind 2 'triggerCharacter " ")
      'workDoneToken "ignored")))
  (define post-shutdown
    (completion-message point-uri 0 0 "post-shutdown"))
  (define result
    (run-with-queries
     (lambda (_path _position) #f)
     completion-query
     (append
      (list preinitialize
            (initialize-message)
            initialized-message
            (open-message point-uri "x")
            completion-notification)
      active-malformed
      (list valid-extra
            (shutdown-message)
            post-shutdown
            exit-message))))
  (check-clean
   result
   (append
    (list
     (error-response
      "preinitialize" -32002 "Server not initialized")
     initialize-response)
    (for/list ([entry (in-list malformed-params)])
      (error-response (car entry) -32602 "Invalid params"))
    (list
     (success-response 303 '())
     shutdown-response
     (error-response "post-shutdown" -32600 "Invalid Request"))))
  (check-equal? completion-calls 1))

(test-case "unexpected completion results recover and later requests succeed"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "failures.aloe"))
     (define source "abc")
     (write-source path source)
     (define uri (url->string (path->url path)))
     (define valid-item
       (completion:selector-completion-item
        "ok" "() -> Int" "ok" 1 1))
     (define outcomes
       (list
        (lambda () (error 'private-completion-003 "secret exception"))
        (lambda () 17)
        (lambda () (cons valid-item 17))
        (lambda () (list 17))
        (lambda ()
          (list
           (completion:selector-completion-item
            'wrong "detail" "insert" 1 1)))
        (lambda ()
          (list
           (completion:selector-completion-item
            "range" "detail" "range" 1 10)))
        (lambda () (list valid-item))))
     (define completion-calls 0)
     (define hover-calls 0)
     (define (completion-query _source _position #:source-path _path)
       (define outcome (list-ref outcomes completion-calls))
       (set! completion-calls (add1 completion-calls))
       (outcome))
     (define (hover-query _path _position)
       (set! hover-calls (add1 hover-calls))
       (stub-hover-result 'AfterCompletionFailure))
     (define failure-ids
       '("raised" "non-list" "improper" "non-item" "wrong-field" "bad-range"))
     (define result
       (run-with-queries
        hover-query
        completion-query
        (append
         (list (initialize-message)
               initialized-message
               (open-message uri source))
         (for/list ([id (in-list failure-ids)])
           (completion-message uri 0 0 id))
         (list
          (completion-message uri 0 0 "recovered")
          (hover-message uri 0 0 "hover-after")
          (shutdown-message)
          exit-message))))
     (check-clean
      result
      (append
       (list initialize-response)
       (for/list ([id (in-list failure-ids)])
         (error-response id -32803 completion-failure-message))
       (list
        (success-response
         "recovered"
         (list
          (completion-item "ok" "() -> Int" "ok" 0 0 0 1)))
        (success-response
         "hover-after"
         (hasheq
          'contents
          (hasheq
           'kind "plaintext"
           'value "type: AfterCompletionFailure\nmessages: none")
          'range
          (hasheq
           'start (lsp-position 0 0)
           'end (lsp-position 0 1))))
        shutdown-response)))
     (check-equal? completion-calls 7)
     (check-equal? hover-calls 1)
     (define protocol
       (bytes->string/utf-8 (get-output-bytes (exchange-output result))))
     (check-false (string-contains? protocol "secret exception"))
     (check-false (string-contains? protocol "private-completion-003")))))

(test-case "completion output failures and non-failure raises escape"
  (define source "abc")
  (define input
    (open-input-bytes
     (apply
      bytes-append
      (map
       frame
       (list
        (initialize-message)
        initialized-message
        (open-message point-uri source)
        (completion-message point-uri 0 0 "write-failure"))))))
  (define captured (open-output-bytes))
  (define attempts 0)
  (define output
    (make-output-port
     'failing-completion-output-003
     always-evt
     (lambda (bytes start end _non-blocking? _breakable?)
       (set! attempts (add1 attempts))
       (if (<= attempts 3)
           (write-bytes bytes captured start end)
           (error 'completion-output-failure-003
                  "private output failure")))
     void))
  (define error-output (open-output-bytes))
  (check-exn
   (lambda (exception)
     (and (exn:fail? exception)
          (string-contains? (exn-message exception)
                            "completion-output-failure-003")))
   (lambda ()
     (support:run-lsp-server/with-queries
      input
      output
      error-output
      (lambda (_path _position) #f)
      (lambda (_source _position #:source-path _path)
        (list
         (completion:selector-completion-item
          "ok" "detail" "ok" 1 1))))))
  (check-equal? attempts 4)
  (check-equal? (decode-frames (get-output-bytes captured))
                (list initialize-response))
  (check-equal? (get-output-bytes error-output) #"")
  (for ([port (in-list (list input output error-output))])
    (check-false (port-closed? port)))

  (define control-value (gensym 'completion-break-003))
  (define control-input
    (open-input-bytes
     (apply
      bytes-append
      (map
       frame
       (list
        (initialize-message)
        initialized-message
        (open-message point-uri source)
        (completion-message point-uri 0 0 "control"))))))
  (define control-output (open-output-bytes))
  (define control-error (open-output-bytes))
  (define observed
    (with-handlers ([(lambda (value) (eq? value control-value)) values])
      (support:run-lsp-server/with-queries
       control-input
       control-output
       control-error
       (lambda (_path _position) #f)
       (lambda (_source _position #:source-path _path)
         (raise control-value)))
      #f))
  (check-eq? observed control-value)
  (check-equal? (decode-frames (get-output-bytes control-output))
                (list initialize-response))
  (check-equal? (get-output-bytes control-error) #"")
  (for ([port
         (in-list
          (list control-input control-output control-error))])
    (check-false (port-closed? port))))

(test-case "duplicate escaped items preserve order, strings, and CRLF ranges"
  (define source "first\r\n(\"x\" dup)")
  (define injected
    (list
     (completion:selector-completion-item
      "|two words|" "first detail" "|two words|" 13 3)
     (completion:selector-completion-item
      "quote\"slash\\" "second\ndetail" "replacement" 13 3)
     (completion:selector-completion-item
      "|two words|" "first detail" "|two words|" 13 3)))
  (define result
    (run-with-queries
     (lambda (_path _position) #f)
     (lambda (_source _position #:source-path _path) injected)
     (list
      (initialize-message)
      initialized-message
      (open-message point-uri source)
      (completion-message point-uri 1 8 "duplicates")
      (shutdown-message)
      exit-message)))
  (check-clean
   result
   (list
    initialize-response
    (success-response
     "duplicates"
     (list
      (completion-item
       "|two words|" "first detail" "|two words|" 1 5 1 8)
      (completion-item
       "quote\"slash\\" "second\ndetail" "replacement" 1 5 1 8)
      (completion-item
       "|two words|" "first detail" "|two words|" 1 5 1 8)))
    shutdown-response)))

(test-case "production composition remains narrow and completion-specific"
  (define source (file->string lsp-module-path))
  (check-equal?
   (regexp-match* #rx"\"[^\"]+\\.rkt\"" source)
   '("\"expression-query.rkt\""
     "\"completion-query.rkt\""))
  (for ([required
         (in-list
          '("query-selector-completions"
            "selector-completion-item?"
            "selector-completion-item-label"
            "selector-completion-item-detail"
            "selector-completion-item-insert-text"
            "selector-completion-item-replacement-start"
            "selector-completion-item-replacement-span"))])
    (check-true (string-contains? source required)))
  (for ([forbidden
         (in-list
          '("parse.rkt"
            "type.rkt"
            "eval.rkt"
            "signature-catalog.rkt"
            "type-signature-specs"
            "Point"
            "Boids"
            "List selectors"
            "String selectors"
            "CompletionList"
            "snippet"
            "remove-duplicates"
            "diagnosticProvider"))])
    (check-false (string-contains? source forbidden)))
  (define completion-section-match
    (regexp-match
     #px"(?s:\\(define \\(query-completion.*?)(?=\\(define \\(completion-outcome)"
     source))
  (check-not-false completion-section-match)
  (define completion-section (first completion-section-match))
  (for ([forbidden
         (in-list
          '("query-expression-at"
            "query-synchronized-document"
            "query-through-snapshot"
            "make-temporary-file"
            "sort"
            "remove-duplicates"))])
    (check-false (string-contains? completion-section forbidden)))
  (check-equal?
   (length
    (regexp-match*
     #px"\\(query\\s+text\\s+query-position\\s+#:source-path\\s+path\\)"
     completion-section))
   1)
  (check-equal?
   (length
    (regexp-match*
     #px"\\(define\\s+\\(run-lsp-server/with-queries\\s+"
     source))
   1)
  (check-equal?
   (length (regexp-match* #px"\\(module\\+\\s+main\\b" source))
   1)
  (check-equal?
   (length
    (regexp-match* #px"\\(current-command-line-arguments\\)" source))
   1))
