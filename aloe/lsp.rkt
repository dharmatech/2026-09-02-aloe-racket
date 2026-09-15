#lang racket/base

(require (only-in json
                  jsexpr->bytes
                  json-null
                  read-json)
         (only-in net/url
                  string->url
                  url-host
                  url-path-absolute?
                  url-scheme
                  url->path)
         (only-in racket/file
                  file->bytes
                  make-temporary-file)
         (only-in racket/path
                  path-only)
         (only-in "expression-query.rkt"
                  query-expression-at
                  expression-query-result?
                  expression-query-result-location
                  expression-query-result-signatures
                  expression-query-result-type
                  signature-spec-parameters
                  signature-spec-return
                  signature-spec-selector))

(provide run-lsp-server)

(struct open-document (uri version text) #:transparent)
(struct decoded-message (value) #:transparent)
(struct rpc-request (id method params-present? params) #:transparent)
(struct rpc-notification (method params-present? params) #:transparent)
(struct exn:fail:framing exn:fail ())
(struct exn:fail:snapshot exn:fail ())
(struct hover-success (result) #:transparent)
(struct hover-failure (message) #:transparent)

(define snapshot-failure-message
  "unable to create synchronized document snapshot")

(define generic-hover-failure-message
  "unable to produce hover result")

(define (raise-snapshot-failure)
  (raise
   (exn:fail:snapshot
    snapshot-failure-message
    (current-continuation-marks))))

(define (document-item-shape? item)
  (and (hash? item)
       (hash-has-key? item 'uri)
       (string? (hash-ref item 'uri))
       (hash-has-key? item 'languageId)
       (string? (hash-ref item 'languageId))
       (hash-has-key? item 'version)
       (exact-integer? (hash-ref item 'version))
       (hash-has-key? item 'text)
       (string? (hash-ref item 'text))))

(define (versioned-document-shape? item)
  (and (hash? item)
       (hash-has-key? item 'uri)
       (string? (hash-ref item 'uri))
       (hash-has-key? item 'version)
       (exact-integer? (hash-ref item 'version))))

(define (full-content-change-shape? change)
  (and (hash? change)
       (hash-has-key? change 'text)
       (string? (hash-ref change 'text))
       (not (hash-has-key? change 'range))
       (not (hash-has-key? change 'rangeLength))))

(define (close-document-shape? item)
  (and (hash? item)
       (hash-has-key? item 'uri)
       (string? (hash-ref item 'uri))))

(define (apply-document-sync! documents method params)
  (cond
    [(equal? method "textDocument/didOpen")
     (when (and (hash? params)
                (hash-has-key? params 'textDocument)
                (document-item-shape?
                 (hash-ref params 'textDocument)))
       (define item (hash-ref params 'textDocument))
       (define uri (hash-ref item 'uri))
       (hash-set! documents
                  uri
                  (open-document uri
                                 (hash-ref item 'version)
                                 (hash-ref item 'text))))]
    [(equal? method "textDocument/didChange")
     (when (and (hash? params)
                (hash-has-key? params 'textDocument)
                (versioned-document-shape?
                 (hash-ref params 'textDocument))
                (hash-has-key? params 'contentChanges)
                (list? (hash-ref params 'contentChanges))
                (for/and ([change
                           (in-list (hash-ref params 'contentChanges))])
                  (full-content-change-shape? change)))
       (define item (hash-ref params 'textDocument))
       (define uri (hash-ref item 'uri))
       (define document (hash-ref documents uri #f))
       (when document
         (define final-text
           (for/fold ([text (open-document-text document)])
                     ([change
                       (in-list (hash-ref params 'contentChanges))])
             (hash-ref change 'text)))
         (hash-set! documents
                    uri
                    (open-document uri
                                   (hash-ref item 'version)
                                   final-text))))]
    [(equal? method "textDocument/didClose")
     (when (and (hash? params)
                (hash-has-key? params 'textDocument)
                (close-document-shape?
                 (hash-ref params 'textDocument)))
       (hash-remove! documents
                     (hash-ref (hash-ref params 'textDocument) 'uri)))])
  (void))

(define initialize-result
  (hasheq
   'capabilities
   (hasheq
    'positionEncoding "utf-16"
    'textDocumentSync
    (hasheq
     'openClose #t
     'change 1)
    'hoverProvider #t)
   'serverInfo
   (hasheq
    'name "aloe-lsp")))

(define (raise-framing-failure)
  (raise
   (exn:fail:framing
    "invalid protocol framing"
    (current-continuation-marks))))

(define (read-crlf-line input)
  (let loop ([octets '()])
    (define octet (read-byte input))
    (cond
      [(eof-object? octet)
       (if (null? octets)
           octet
           (raise-framing-failure))]
      [(= octet 13)
       (define next-octet (read-byte input))
       (unless (and (byte? next-octet)
                    (= next-octet 10))
         (raise-framing-failure))
       (list->bytes (reverse octets))]
      [(or (= octet 10)
           (> octet 127))
       (raise-framing-failure)]
      [else
       (loop (cons octet octets))])))

(define (parse-header-line line)
  (define match (regexp-match #rx#"^([^:]+): (.+)$" line))
  (unless match
    (raise-framing-failure))
  (values
   (string-downcase (bytes->string/latin-1 (list-ref match 1)))
   (bytes->string/latin-1 (list-ref match 2))))

(define (content-length-value value)
  (unless (regexp-match? #rx"^[0-9]+$" value)
    (raise-framing-failure))
  (define length (string->number value 10))
  (unless (exact-nonnegative-integer? length)
    (raise-framing-failure))
  length)

(define (valid-content-type? value)
  (member
   (string-downcase value)
   '("application/vscode-jsonrpc; charset=utf-8"
     "application/vscode-jsonrpc; charset=utf8")))

(define (read-exact-body input content-length)
  (define body-output (open-output-bytes))
  (let loop ([remaining content-length])
    (cond
      [(zero? remaining)
       (get-output-bytes body-output)]
      [else
       (define chunk (read-bytes (min remaining 4096) input))
       (unless (and (bytes? chunk)
                    (positive? (bytes-length chunk)))
         (raise-framing-failure))
       (write-bytes chunk body-output)
       (loop (- remaining (bytes-length chunk)))])))

(define (read-frame input)
  (define first-line (read-crlf-line input))
  (if (eof-object? first-line)
      first-line
      (let ()
        (define-values (first-name first-value)
          (parse-header-line first-line))
        (define content-length
          (cond
            [(string=? first-name "content-length")
             (content-length-value first-value)]
            [(string=? first-name "content-type")
             (unless (valid-content-type? first-value)
               (raise-framing-failure))
             #f]
            [else
             (raise-framing-failure)]))
        (define remaining-length
          (let loop ([length content-length]
                     [content-type-seen?
                      (string=? first-name "content-type")])
            (define line (read-crlf-line input))
            (when (eof-object? line)
              (raise-framing-failure))
            (cond
              [(zero? (bytes-length line))
               (or length (raise-framing-failure))]
              [else
               (define-values (name value) (parse-header-line line))
               (cond
                 [(string=? name "content-length")
                  (when length
                    (raise-framing-failure))
                  (loop (content-length-value value)
                        content-type-seen?)]
                 [(string=? name "content-type")
                  (when (or content-type-seen?
                            (not (valid-content-type? value)))
                    (raise-framing-failure))
                  (loop length #t)]
                 [else
                  (raise-framing-failure)])])))
        (read-exact-body input remaining-length))))

(define (json-whitespace? character)
  (or (char=? character #\space)
      (char=? character #\tab)
      (char=? character #\return)
      (char=? character #\newline)))

(define (decode-frame-body body)
  (with-handlers ([exn:fail? (lambda (_exception) #f)])
    (define input
      (open-input-string (bytes->string/utf-8 body)))
    (define value (read-json input))
    (and
     (not (eof-object? value))
     (let loop ()
       (define character (read-char input))
       (cond
         [(eof-object? character)
          (decoded-message value)]
         [(json-whitespace? character)
          (loop)]
         [else #f])))))

(define (write-frame output message)
  (define body (jsexpr->bytes message))
  (define header
    (string->bytes/utf-8
     (format "Content-Length: ~a\r\n\r\n" (bytes-length body))))
  (write-bytes header output)
  (write-bytes body output)
  (flush-output output))

(define (write-response output id result)
  (write-frame
   output
   (hasheq
    'jsonrpc "2.0"
    'id id
    'result result)))

(define (write-error-response output id code message)
  (write-frame
   output
   (hasheq
    'jsonrpc "2.0"
    'id id
    'error
    (hasheq
     'code code
     'message message))))

(define supported-request-methods
  '("initialize"
    "textDocument/hover"
    "shutdown"))

(define supported-notification-methods
  '("initialized"
    "textDocument/didOpen"
    "textDocument/didChange"
    "textDocument/didClose"
    "$/cancelRequest"
    "exit"))

(define (request-id? value)
  (or (string? value)
      (exact-integer? value)))

(define (classify-json-rpc-message value)
  (and
   (hash? value)
   (hash-has-key? value 'jsonrpc)
   (equal? (hash-ref value 'jsonrpc) "2.0")
   (hash-has-key? value 'method)
   (string? (hash-ref value 'method))
   (let ([method (hash-ref value 'method)]
         [params-present? (hash-has-key? value 'params)]
         [params (hash-ref value 'params #f)])
     (if (hash-has-key? value 'id)
         (let ([id (hash-ref value 'id)])
           (and (request-id? id)
                (rpc-request id method params-present? params)))
         (rpc-notification method params-present? params)))))

(define (initialize-params? request)
  (and (rpc-request-params-present? request)
       (hash? (rpc-request-params request))))

(define (hover-params? request)
  (and
   (rpc-request-params-present? request)
   (let ([params (rpc-request-params request)])
     (and
      (hash? params)
      (hash-has-key? params 'textDocument)
      (hash? (hash-ref params 'textDocument))
      (hash-has-key? (hash-ref params 'textDocument) 'uri)
      (string? (hash-ref (hash-ref params 'textDocument) 'uri))
      (hash-has-key? params 'position)
      (hash? (hash-ref params 'position))
      (hash-has-key? (hash-ref params 'position) 'line)
      (exact-nonnegative-integer?
       (hash-ref (hash-ref params 'position) 'line))
      (hash-has-key? (hash-ref params 'position) 'character)
      (exact-nonnegative-integer?
       (hash-ref (hash-ref params 'position) 'character))))))

(define (shutdown-params? request)
  (or (not (rpc-request-params-present? request))
      (equal? (rpc-request-params request) (json-null))))

(define (exit-params? notification)
  (or (not (rpc-notification-params-present? notification))
      (equal? (rpc-notification-params notification) (json-null))))

(define (uri->local-path uri)
  (and
   (string? uri)
   (with-handlers ([exn:fail? (lambda (_exception) #f)])
     (define url (string->url uri))
     (define host (url-host url))
     (and (equal? (url-scheme url) "file")
          (or (not host) (string=? host ""))
          (url-path-absolute? url)
          (let ([path (url->path url)])
            (and (path? path)
                 (absolute-path? path)
                 path))))))

(define (matching-disk-bytes? path synchronized-bytes)
  (with-handlers ([exn:fail:filesystem? (lambda (_exception) #f)])
    (and (eq? (file-or-directory-type path #t) 'file)
         (bytes=? (file->bytes path) synchronized-bytes))))

(define (remove-snapshot snapshot-path)
  (with-handlers ([exn:fail? (lambda (_exception)
                               (raise-snapshot-failure))])
    (delete-file snapshot-path)))

(define (invoke-query query path query-position)
  (with-handlers ([exn:fail? (lambda (_exception) #f)])
    (query path query-position)))

(define (query-through-snapshot query path synchronized-bytes query-position)
  (define snapshot-path #f)
  (with-handlers
      ([exn:fail?
        (lambda (_exception)
          (when snapshot-path
            (with-handlers ([exn:fail? void])
              (delete-file snapshot-path)))
          (raise-snapshot-failure))])
    (define parent (path-only path))
    (unless parent
      (raise-snapshot-failure))
    (set! snapshot-path
          (make-temporary-file
           "aloe-lsp-snapshot-~a"
           #f
           parent))
    (call-with-output-file
     snapshot-path
     #:exists 'truncate
     (lambda (output)
       (unless (= (write-bytes synchronized-bytes output)
                  (bytes-length synchronized-bytes))
         (raise-snapshot-failure))
       (flush-output output))))
  (dynamic-wind
    void
    (lambda ()
      (invoke-query query snapshot-path query-position))
    (lambda ()
      (remove-snapshot snapshot-path))))

(define (query-synchronized-document query path text query-position)
  (define synchronized-bytes (string->bytes/utf-8 text))
  (if (matching-disk-bytes? path synchronized-bytes)
      (invoke-query query path query-position)
      (query-through-snapshot
       query path synchronized-bytes query-position)))

(define (lsp-position line character)
  (hasheq 'line line 'character character))

(define (character-utf-16-width character)
  (if (<= (char->integer character) #xFFFF) 1 2))

(define (text-offset-positions text)
  (define length (string-length text))
  (define positions (make-vector (add1 length) #f))
  (vector-set! positions 0 (lsp-position 0 0))
  (let loop ([offset 0]
             [line 0]
             [character 0])
    (cond
      [(= offset length) positions]
      [(char=? (string-ref text offset) #\return)
       (if (and (< (add1 offset) length)
                (char=? (string-ref text (add1 offset)) #\newline))
           (let ([next-offset (+ offset 2)])
             ;; The boundary between CR and LF is inside one line break.
             (vector-set! positions next-offset
                          (lsp-position (add1 line) 0))
             (loop next-offset (add1 line) 0))
           (let ([next-offset (add1 offset)])
             (vector-set! positions next-offset
                          (lsp-position (add1 line) 0))
             (loop next-offset (add1 line) 0)))]
      [(char=? (string-ref text offset) #\newline)
       (define next-offset (add1 offset))
       (vector-set! positions next-offset
                    (lsp-position (add1 line) 0))
       (loop next-offset (add1 line) 0)]
      [else
       (define next-offset (add1 offset))
       (define next-character
         (+ character
            (character-utf-16-width (string-ref text offset))))
       (vector-set! positions next-offset
                    (lsp-position line next-character))
       (loop next-offset line next-character)])))

(define (lsp-position->query-position text line character)
  (and
   (exact-nonnegative-integer? line)
   (exact-nonnegative-integer? character)
   (let ([positions (text-offset-positions text)])
     (for/first ([position (in-vector positions)]
                 [offset (in-naturals)]
                 #:when (and position
                             (= (hash-ref position 'line) line)
                             (= (hash-ref position 'character) character)))
       (add1 offset)))))

(define (offset->lsp-position text offset)
  (and
   (exact-nonnegative-integer? offset)
   (<= offset (string-length text))
   (vector-ref (text-offset-positions text) offset)))

(define (result-range text result)
  (define location (expression-query-result-location result))
  (and
   (srcloc? location)
   (let ([start (srcloc-position location)]
         [span (srcloc-span location)])
     (and
      (exact-positive-integer? start)
      (exact-nonnegative-integer? span)
      (let* ([start-offset (sub1 start)]
             [end-offset (+ start-offset span)]
             [start-position (offset->lsp-position text start-offset)]
             [end-position (offset->lsp-position text end-offset)])
        (and start-position
             end-position
             (hasheq
              'start start-position
              'end end-position)))))))

(define (datum-text datum)
  (format "~s" datum))

(define (result-contents result)
  (define signatures (expression-query-result-signatures result))
  (string-append
   "type: "
   (datum-text (expression-query-result-type result))
   (if (null? signatures)
       "\nmessages: none"
       (string-append
        "\nmessages:"
        (apply
         string-append
         (for/list ([signature (in-list signatures)])
           (string-append
            "\n  "
            (datum-text (signature-spec-selector signature))
            " : "
            (datum-text (signature-spec-parameters signature))
            " -> "
            (datum-text (signature-spec-return signature)))))))))

(define (query-hover query document line character)
  (define text (open-document-text document))
  (define path (uri->local-path (open-document-uri document)))
  (define query-position
    (and path
         (lsp-position->query-position text line character)))
  (if query-position
      (let ([result
             (query-synchronized-document
              query path text query-position)])
        (cond
          [(eq? result #f) (json-null)]
          [(expression-query-result? result)
           (define range (result-range text result))
           (if range
               (hasheq
                'contents
                (hasheq
                 'kind "plaintext"
                 'value (result-contents result))
                'range range)
               (json-null))]
          [else
           (error 'query-hover "unexpected query result")]))
      (json-null)))

(define (hover-outcome computation)
  (with-handlers
      ([exn:fail:snapshot?
        (lambda (_exception)
          (hover-failure snapshot-failure-message))]
       [exn:fail?
        (lambda (_exception)
          (hover-failure generic-hover-failure-message))])
    (hover-success (computation))))

(define (run-lsp-server/with-query input output error-output query)
  (void error-output)
  (define documents (make-hash))
  (with-handlers ([exn:fail:framing? (lambda (_exception) 1)])
    (let loop ([state 'uninitialized])
      (define body (read-frame input))
      (cond
        [(eof-object? body) 1]
        [else
         (define decoded (decode-frame-body body))
         (cond
           [(not decoded)
            (write-error-response output (json-null) -32700 "Parse error")
            (loop state)]
           [else
            (define message
              (classify-json-rpc-message
               (decoded-message-value decoded)))
            (cond
              [(not message)
               (write-error-response
                output (json-null) -32600 "Invalid Request")
               (loop state)]
              [(rpc-request? message)
               (define id (rpc-request-id message))
               (define method (rpc-request-method message))
               (cond
                 [(eq? state 'uninitialized)
                  (if (string=? method "initialize")
                      (if (initialize-params? message)
                          (begin
                            (write-response output id initialize-result)
                            (loop 'active))
                          (begin
                            (write-error-response
                             output id -32602 "Invalid params")
                            (loop state)))
                      (begin
                        (write-error-response
                         output id -32002 "Server not initialized")
                        (loop state)))]
                 [(eq? state 'shutdown)
                  (write-error-response
                   output id -32600 "Invalid Request")
                  (loop state)]
                 [(string=? method "initialize")
                  (write-error-response
                   output id -32600 "Invalid Request")
                  (loop state)]
                 [(not (member method supported-request-methods))
                  (write-error-response
                   output id -32601 "Method not found")
                  (loop state)]
                 [(string=? method "textDocument/hover")
                  (if
                   (not (hover-params? message))
                   (begin
                     (write-error-response
                      output id -32602 "Invalid params")
                     (loop state))
                   (let ()
                     (define parameters (rpc-request-params message))
                     (define uri
                       (hash-ref (hash-ref parameters 'textDocument) 'uri))
                     (define position (hash-ref parameters 'position))
                     (define document (hash-ref documents uri #f))
                     (define outcome
                       (hover-outcome
                        (lambda ()
                          (if document
                              (query-hover
                               query
                               document
                               (hash-ref position 'line)
                               (hash-ref position 'character))
                              (json-null)))))
                     (cond
                       [(hover-success? outcome)
                        (write-response
                         output id (hover-success-result outcome))]
                       [else
                        (write-error-response
                         output id -32803 (hover-failure-message outcome))])
                     (loop state)))]
                 [(string=? method "shutdown")
                  (if (shutdown-params? message)
                      (begin
                        (write-response output id (json-null))
                        (loop 'shutdown))
                      (begin
                        (write-error-response
                         output id -32602 "Invalid params")
                        (loop state)))])]
              [else
               (define method (rpc-notification-method message))
               (cond
                 [(eq? state 'uninitialized)
                  (if (and (string=? method "exit")
                           (exit-params? message))
                      1
                      (loop state))]
                 [(eq? state 'shutdown)
                  (if (and (string=? method "exit")
                           (exit-params? message))
                      0
                      (loop state))]
                 [(not (member method supported-notification-methods))
                  (loop state)]
                 [(or (string=? method "textDocument/didOpen")
                      (string=? method "textDocument/didChange")
                      (string=? method "textDocument/didClose"))
                  (apply-document-sync!
                   documents method (rpc-notification-params message))
                  (loop state)]
                 [(string=? method "exit")
                  (if (exit-params? message)
                      1
                      (loop state))]
                 [else
                  (loop state)])])])]))))

(define (run-lsp-server input output error-output)
  (run-lsp-server/with-query
   input output error-output query-expression-at))

(module+ main
  (exit
   (if (zero? (vector-length (current-command-line-arguments)))
       (run-lsp-server
        (current-input-port)
        (current-output-port)
        (current-error-port))
       1)))

(module* test-support #f
  (provide run-lsp-server/with-query
           apply-document-sync!
           open-document?
           open-document-uri
           open-document-version
           open-document-text))
