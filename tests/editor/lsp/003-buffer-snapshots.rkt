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

(define (change-message uri text [version 2])
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
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "shutdown"))

(define exit-message
  (hasheq
   'jsonrpc "2.0"
   'method "exit"))

(define (complete-exchange uri text hover [extra-messages '()])
  (append
   (list (initialize-message)
         initialized-message
         (open-message uri text))
   extra-messages
   (list hover (shutdown-message) exit-message)))

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

(define (run-with-query query-procedure messages)
  (run-exchange
   (lambda (input output error-output)
     (support:run-lsp-server/with-query
      input output error-output query-procedure))
   messages))

(define (check-clean-exchange result expected-response-count)
  (check-equal? (exchange-status result) 0)
  (check-equal? (get-output-bytes (exchange-error result)) #"")
  (check-equal? (length (exchange-responses result))
                expected-response-count)
  (check-false (port-closed? (exchange-input result)))
  (check-false (port-closed? (exchange-output result)))
  (check-false (port-closed? (exchange-error result))))

(define (response-with-id responses id)
  (findf (lambda (response)
           (equal? (hash-ref response 'id #f) id))
         responses))

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
    (make-temporary-file "aloe-lsp-003-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (procedure (normalized directory)))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (stub-result start span [type 'Stub])
  (query:expression-query-result
   type
   (list (query:signature-spec 'probe '() type))
   (srcloc 'private-snapshot-source 999 888 start span)))

(test-case "unchanged read-only document queries its original path"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "unchanged.aloe"))
     (define text "unchanged")
     (write-exact-bytes path (string->bytes/utf-8 text))
     (define original-permissions
       (file-or-directory-permissions path 'bits))
     (define original-entries (directory-entry-paths directory))
     (dynamic-wind
       (lambda ()
         (file-or-directory-permissions path #o444))
       (lambda ()
         (define calls '())
         (define result
           (run-with-query
            (lambda (query-path query-position)
              (set! calls (list (list query-path query-position)))
              (check-equal? (normalized query-path) (normalized path))
              (check-equal? (directory-entry-paths directory)
                            original-entries)
              (stub-result 1 1))
            (complete-exchange
             (path-uri path)
             text
             (hover-message (path-uri path) 0 0 73))))
         (check-clean-exchange result 3)
         (check-equal? calls (list (list path 1)))
         (check-not-equal?
          (hash-ref (response-with-id (exchange-responses result) 73)
                    'result)
          (json-null))
         (check-equal? (directory-entry-paths directory)
                       original-entries))
       (lambda ()
         (when (file-exists? path)
           (file-or-directory-permissions path original-permissions)))))))

(test-case "dirty didOpen queries exact bytes through a temporary sibling"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "existing-root.aloe"))
     (define original-bytes #"original disk bytes")
     (define synchronized-text "dirty λ😀\r\nbytes")
     (define synchronized-bytes (string->bytes/utf-8 synchronized-text))
     (write-exact-bytes path original-bytes)
     (define original-entries (directory-entry-paths directory))
     (define observed-snapshot #f)
     (define result
       (run-with-query
        (lambda (query-path query-position)
          (set! observed-snapshot query-path)
          (check-not-equal? (normalized query-path) (normalized path))
          (check-equal? (normalized (path->directory-path
                                     (path-only query-path)))
                        (normalized (path->directory-path directory)))
          (check-equal? (file-or-directory-type query-path #t) 'file)
          (check-equal? (file->bytes query-path) synchronized-bytes)
          (check-equal? query-position 1)
          (check-equal?
           (directory-entry-paths directory)
           (sort (cons (path->string (normalized query-path))
                       original-entries)
                 string<?))
          (stub-result 1 5))
        (complete-exchange
         (path-uri path)
         synchronized-text
         (hover-message (path-uri path) 0 0 "dirty-hover"))))
     (check-clean-exchange result 3)
     (check-true (path? observed-snapshot))
     (check-false (file-exists? observed-snapshot))
     (check-equal? (file->bytes path) original-bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (check-false
      (string-contains?
       (bytes->string/utf-8 (get-output-bytes (exchange-output result)))
       (path->string directory))))))

(test-case "dirty final didChange drives snapshot position and range"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "changed-root"))
     (define disk-bytes #"disk")
     (define final-text "😀\r\nfinal")
     (write-exact-bytes path disk-bytes)
     (define original-entries (directory-entry-paths directory))
     (define calls '())
     (define uri (path-uri path))
     (define result
       (run-with-query
        (lambda (query-path query-position)
          (set! calls (append calls (list (list query-path query-position))))
          (check-not-equal? (normalized query-path) (normalized path))
          (check-equal? (file->bytes query-path)
                        (string->bytes/utf-8 final-text))
          (stub-result 4 5))
        (complete-exchange
         uri
         "older synchronized text"
         (hover-message uri 1 5 92)
         (list (change-message uri final-text)))))
     (check-clean-exchange result 3)
     (check-equal? (length calls) 1)
     (check-equal? (second (first calls)) 9)
     (check-equal?
      (hash-ref
       (hash-ref (response-with-id (exchange-responses result) 92) 'result)
       'range)
      (hasheq
       'start (hasheq 'line 1 'character 0)
       'end (hasheq 'line 1 'character 5)))
     (check-equal? (file->bytes path) disk-bytes)
     (check-equal? (directory-entry-paths directory) original-entries))))

(test-case "null and invalid-range results each remove their snapshot"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "null-results.aloe"))
     (define original-bytes #"disk")
     (define synchronized-text "dirty")
     (write-exact-bytes path original-bytes)
     (define original-entries (directory-entry-paths directory))
     (define snapshots '())
     (define call-count 0)
     (define uri (path-uri path))
     (define messages
       (append
        (list (initialize-message)
              initialized-message
              (open-message uri synchronized-text)
              (hover-message uri 0 0 "false-result")
              (hover-message uri 0 0 "invalid-range"))
        (list (shutdown-message) exit-message)))
     (define result
       (run-with-query
        (lambda (query-path _query-position)
          (set! call-count (add1 call-count))
          (set! snapshots (append snapshots (list query-path)))
          (check-equal? (file->bytes query-path)
                        (string->bytes/utf-8 synchronized-text))
          (check-equal? (length (directory-entry-paths directory))
                        (add1 (length original-entries)))
          (if (= call-count 1)
              #f
              (stub-result 20 1)))
        messages))
     (check-clean-exchange result 4)
     (check-equal? call-count 2)
     (check-equal? (length snapshots) 2)
     (for ([snapshot (in-list snapshots)])
       (check-false (file-exists? snapshot)))
     (for ([id (in-list '("false-result" "invalid-range"))])
       (check-equal?
        (hash-ref (response-with-id (exchange-responses result) id) 'result)
        (json-null)))
     (check-equal? (file->bytes path) original-bytes)
     (check-equal? (directory-entry-paths directory) original-entries))))

(test-case "ordinary query failure becomes a null Hover after snapshot cleanup"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "exception.aloe"))
     (define original-bytes #"disk")
     (define synchronized-text "dirty")
     (write-exact-bytes path original-bytes)
     (define original-entries (directory-entry-paths directory))
     (define observed-snapshot #f)
     (define distinctive
       (exn:fail "distinctive snapshot query exception"
                 (current-continuation-marks)))
     (define calls 0)
     (define result
       (run-with-query
        (lambda (query-path _query-position)
          (set! calls (add1 calls))
          (set! observed-snapshot query-path)
          (check-equal? (file->bytes query-path)
                        (string->bytes/utf-8 synchronized-text))
          (raise distinctive))
        (complete-exchange
         (path-uri path)
         synchronized-text
         (hover-message (path-uri path) 0 0 "raises"))))
     (check-clean-exchange result 3)
     (check-equal? calls 1)
     (check-equal?
      (response-with-id (exchange-responses result) "raises")
      (hasheq 'jsonrpc "2.0" 'id "raises" 'result (json-null)))
     (check-true (path? observed-snapshot))
     (check-false (file-exists? observed-snapshot))
     (check-equal? (file->bytes path) original-bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (define protocol-text
       (bytes->string/utf-8
        (get-output-bytes (exchange-output result))))
     (check-false
      (string-contains? protocol-text
                        "distinctive snapshot query exception"))
     (check-equal? (get-output-bytes (exchange-error result)) #""))))

(test-case "missing root is queried through a sibling and remains missing"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "missing-root.aloe"))
     (define synchronized-text "missing root text")
     (define original-entries (directory-entry-paths directory))
     (define observed-snapshot #f)
     (define result
       (run-with-query
        (lambda (query-path query-position)
          (set! observed-snapshot query-path)
          (check-false (file-exists? path))
          (check-equal? (normalized (path->directory-path
                                     (path-only query-path)))
                        (normalized (path->directory-path directory)))
          (check-equal? (file->bytes query-path)
                        (string->bytes/utf-8 synchronized-text))
          (check-equal? query-position 9)
          (stub-result 1 7))
        (complete-exchange
         (path-uri path)
         synchronized-text
         (hover-message (path-uri path) 0 8 "missing-success"))))
     (check-clean-exchange result 3)
     (check-not-equal?
      (hash-ref
       (response-with-id (exchange-responses result) "missing-success")
       'result)
      (json-null))
     (check-false (file-exists? path))
     (check-false (file-exists? observed-snapshot))
     (check-equal? (directory-entry-paths directory) original-entries))))

(test-case "real query preserves relative disk loads without dirty overlays"
  (call-with-test-directory
   (lambda (directory)
     (define root-path (build-path directory "missing-root.aloe"))
     (define support-path (build-path directory "support.aloe"))
     (define support-text
       (string-append
        "(define-class LoadedFromDisk\n"
        "  (fields\n"
        "    (value Int))\n"
        "  (methods))\n"))
     (define root-text
       (string-append
        "(load \"support.aloe\")\n"
        "(LoadedFromDisk new 7)\n"))
     (write-exact-bytes support-path (string->bytes/utf-8 support-text))
     (define support-bytes (file->bytes support-path))
     (define original-entries (directory-entry-paths directory))
     (define root-uri (path-uri root-path))
     (define support-uri (path-uri support-path))
     (define messages
       (list
        (initialize-message)
        initialized-message
        (open-message support-uri "(" 41)
        (open-message root-uri root-text 9)
        (hover-message root-uri 1 17 "loaded-hover")
        (shutdown-message)
        exit-message))
     (define result (run-exchange lsp:run-lsp-server messages))
     (check-clean-exchange result 3)
     (define hover-result
       (hash-ref
        (response-with-id (exchange-responses result) "loaded-hover")
        'result))
     (check-equal?
      hover-result
      (hasheq
       'contents
       (hasheq
        'kind "plaintext"
        'value
        (string-append
         "type: LoadedFromDisk\n"
         "messages:\n"
         "  value : () -> Int"))
       'range
       (hasheq
        'start (hasheq 'line 1 'character 0)
        'end (hasheq 'line 1 'character 22))))
     (check-false (file-exists? root-path))
     (check-equal? (file->bytes support-path) support-bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (define protocol-text
       (bytes->string/utf-8 (get-output-bytes (exchange-output result))))
     (check-false (string-contains? protocol-text (path->string directory)))
     (check-false (string-contains? protocol-text "aloe-lsp-snapshot")))))

(test-case "snapshot setup failures return RequestFailed and service continues"
  (call-with-test-directory
   (lambda (directory)
     (define parent-component (build-path directory "not-a-directory"))
     (define parent-bytes #"unchanged blocker")
     (write-exact-bytes parent-component parent-bytes)
     (define path (build-path parent-component "root.aloe"))
     (define uri (path-uri path))
     (define original-entries (directory-entry-paths directory))
     (define calls 0)
     (define messages
       (list
        (initialize-message)
        initialized-message
        (open-message uri "dirty")
        (hover-message uri 0 0 303)
        (hover-message uri 0 0 "snapshot-failure")
        (shutdown-message 404)
        exit-message))
     (define result
       (run-with-query
        (lambda (_path _position)
          (set! calls (add1 calls))
          #f)
        messages))
     (check-clean-exchange result 4)
     (check-equal? calls 0)
     (define (expected-error id)
       (hasheq
        'jsonrpc "2.0"
        'id id
        'error
        (hasheq
         'code -32803
         'message "unable to create synchronized document snapshot")))
     (check-equal? (response-with-id (exchange-responses result) 303)
                   (expected-error 303))
     (check-equal?
      (response-with-id (exchange-responses result) "snapshot-failure")
      (expected-error "snapshot-failure"))
     (check-equal?
      (response-with-id (exchange-responses result) 404)
      (hasheq 'jsonrpc "2.0" 'id 404 'result (json-null)))
     (check-equal? (file->bytes parent-component) parent-bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (check-equal? (get-output-bytes (exchange-error result)) #""))))

(test-case "source confines snapshots to sibling paths and the public query"
  (define source (file->string lsp-module-path))
  (check-true (string-contains? source "make-temporary-file"))
  (check-true (string-contains? source "path-only path"))
  (check-true
   (string-contains? source
                     "(call-with-output-file\n     snapshot-path"))
  (check-false
   (string-contains? source
                     "(call-with-output-file\n     path"))
  (for ([forbidden
         (in-list
          '("find-system-path"
            "current-temporary-directory"
            "read-program"
            "type-signature-specs"
            "catalog"
            "signature-catalog.rkt"
            "load"
            "copy-file"))])
    (check-false (string-contains? source forbidden))))
