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
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "shutdown"))

(define exit-message
  (hasheq
   'jsonrpc "2.0"
   'method "exit"))

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

(define (run-with-query query messages)
  (run-exchange
   (lambda (input output error-output)
     (support:run-lsp-server/with-query
      input output error-output query))
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

(define (check-null-response response id)
  (check-equal?
   response
   (hasheq 'jsonrpc "2.0" 'id id 'result (json-null)))
  (check-true (hash-has-key? response 'result))
  (check-false (hash-has-key? response 'error)))

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
    (make-temporary-file "aloe-lsp-004-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (procedure (normalized directory)))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (expected-string-hover line)
  (hasheq
   'contents
   (hasheq
    'kind "plaintext"
    'value "type: (Class String)\nmessages: none")
   'range
   (hasheq
    'start (hasheq 'line line 'character 0)
    'end (hasheq 'line line 'character 6))))

(define (protocol-text result)
  (bytes->string/utf-8 (get-output-bytes (exchange-output result))))

(test-case "direct query failure becomes null exactly once and service continues"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "unchanged.aloe"))
     (define text "String")
     (define bytes (string->bytes/utf-8 text))
     (write-exact-bytes path bytes)
     (define original-entries (directory-entry-paths directory))
     (define calls 0)
     (define uri (path-uri path))
     (define result
       (run-with-query
        (lambda (query-path query-position)
          (set! calls (add1 calls))
          (check-equal? (normalized query-path) (normalized path))
          (check-equal? query-position 1)
          (check-equal? (file->bytes query-path) bytes)
          (check-equal? (directory-entry-paths directory) original-entries)
          (error 'distinctive-direct-004 "ordinary query failure"))
        (list
         (initialize-message)
         initialized-message
         (open-message uri text)
         (hover-message uri 0 0 404)
         (shutdown-message)
         exit-message)))
     (check-clean-exchange result 3)
     (check-equal? calls 1)
     (check-null-response
      (response-with-id (exchange-responses result) 404)
      404)
     (check-equal? (file->bytes path) bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (define output-text (protocol-text result))
     (for ([forbidden
            (in-list
             (list "distinctive-direct-004"
                   "ordinary query failure"
                   (path->string directory)
                   "aloe-lsp-snapshot"
                   "textDocument/publishDiagnostics"))])
       (check-false (string-contains? output-text forbidden))))))

(test-case "real snapshot query failures return null and a later change succeeds"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "missing-root.aloe"))
     (define uri (path-uri path))
     (define original-entries (directory-entry-paths directory))
     (define incomplete "(1 + 2")
     (define parser-invalid "(1)\n")
     (define checker-invalid "1\nmissing-after004\n")
     (define missing-load
       "(load \"missing-relative-004.aloe\")\n1\n")
     (define valid "String")
     (define messages
       (list
        (initialize-message 10)
        initialized-message
        (open-message uri incomplete 1)
        (hover-message uri 0 1 "incomplete")
        (change-message uri parser-invalid 2)
        (hover-message uri 0 1 20)
        (change-message uri checker-invalid 3)
        (hover-message uri 0 0 "later-checker-error")
        (change-message uri missing-load 4)
        (hover-message uri 1 0 40)
        (change-message uri valid 5)
        (hover-message uri 0 0 "recovered")
        (shutdown-message 60)
        exit-message))
     (define result (run-exchange lsp:run-lsp-server messages))
     (check-clean-exchange result 7)
     (for ([id (in-list '("incomplete" 20 "later-checker-error" 40))])
       (check-null-response
        (response-with-id (exchange-responses result) id)
        id))
     (check-equal?
      (response-with-id (exchange-responses result) "recovered")
      (hasheq
       'jsonrpc "2.0"
       'id "recovered"
       'result (expected-string-hover 0)))
     (check-false (file-exists? path))
     (check-equal? (directory-entry-paths directory) original-entries)
     (define output-text (protocol-text result))
     (for ([forbidden
            (in-list
             (list (path->string directory)
                   "aloe-lsp-snapshot"
                   "missing-after004"
                   "missing-relative-004"
                   "diagnostic"))])
       (check-false (string-contains? output-text forbidden))))))

(test-case "real top-level query miss is null before a later valid Hover"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "gap.aloe"))
     (define text "1\n; top-level gap\n\nString\n")
     (define bytes (string->bytes/utf-8 text))
     (write-exact-bytes path bytes)
     (define original-entries (directory-entry-paths directory))
     (define uri (path-uri path))
     (define result
       (run-exchange
        lsp:run-lsp-server
        (list
         (initialize-message)
         initialized-message
         (open-message uri text)
         (hover-message uri 2 0 "gap")
         (hover-message uri 3 0 73)
         (shutdown-message)
         exit-message)))
     (check-clean-exchange result 4)
     (check-null-response
      (response-with-id (exchange-responses result) "gap")
      "gap")
     (check-equal?
      (response-with-id (exchange-responses result) 73)
      (hasheq 'jsonrpc "2.0" 'id 73 'result (expected-string-hover 3)))
     (check-equal? (file->bytes path) bytes)
     (check-equal? (directory-entry-paths directory) original-entries))))

(test-case "unchanged public query failure and dirty recovery share the policy"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "direct-parser-error.aloe"))
     (define invalid-text "(1)\n")
     (define original-bytes (string->bytes/utf-8 invalid-text))
     (write-exact-bytes path original-bytes)
     (define original-entries (directory-entry-paths directory))
     (define uri (path-uri path))
     (define result
       (run-exchange
        lsp:run-lsp-server
        (list
         (initialize-message)
         initialized-message
         (open-message uri invalid-text)
         (hover-message uri 0 1 "direct-parser-failure")
         (change-message uri "String" 2)
         (hover-message uri 0 0 "snapshot-success")
         (shutdown-message)
         exit-message)))
     (check-clean-exchange result 4)
     (check-null-response
      (response-with-id (exchange-responses result)
                        "direct-parser-failure")
      "direct-parser-failure")
     (check-equal?
      (response-with-id (exchange-responses result) "snapshot-success")
      (hasheq
       'jsonrpc "2.0"
       'id "snapshot-success"
       'result (expected-string-hover 0)))
     (check-equal? (file->bytes path) original-bytes)
     (check-equal? (directory-entry-paths directory) original-entries)
     (check-equal? (get-output-bytes (exchange-error result)) #""))))

(test-case "a root made unreadable inside the public query returns null"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "temporarily-unreadable.aloe"))
     (define text "String")
     (define bytes (string->bytes/utf-8 text))
     (write-exact-bytes path bytes)
     (define original-permissions
       (file-or-directory-permissions path 'bits))
     (define original-entries (directory-entry-paths directory))
     (define uri (path-uri path))
     (define calls 0)
     (dynamic-wind
       void
       (lambda ()
         (define result
           (run-with-query
            (lambda (query-path query-position)
              (set! calls (add1 calls))
              (check-equal? (normalized query-path) (normalized path))
              (check-equal? query-position 1)
              (if (= calls 1)
                  (dynamic-wind
                    (lambda ()
                      (file-or-directory-permissions query-path #o000))
                    (lambda ()
                      (query:query-expression-at query-path query-position))
                    (lambda ()
                      (file-or-directory-permissions
                       query-path
                       original-permissions)))
                  (query:query-expression-at query-path query-position)))
            (list
             (initialize-message)
             initialized-message
             (open-message uri text)
             (hover-message uri 0 0 "unreadable")
             (hover-message uri 0 0 "readable-again")
             (shutdown-message)
             exit-message)))
         (check-clean-exchange result 4)
         (check-equal? calls 2)
         (check-null-response
          (response-with-id (exchange-responses result) "unreadable")
          "unreadable")
         (check-equal?
          (response-with-id (exchange-responses result) "readable-again")
          (hasheq
           'jsonrpc "2.0"
           'id "readable-again"
           'result (expected-string-hover 0)))
         (check-equal? (file->bytes path) bytes)
         (check-equal? (directory-entry-paths directory) original-entries)
         (define output-text (protocol-text result))
         (check-false (string-contains? output-text (path->string path)))
         (check-false (string-contains? output-text "open-input-file")))
       (lambda ()
         (when (file-exists? path)
           (file-or-directory-permissions path original-permissions)))))))

(test-case "real empty and overloaded catalogs render exactly in query order"
  (call-with-test-directory
   (lambda (directory)
     (define path (build-path directory "rendering.aloe"))
     (define uri (path-uri path))
     (define string-source "String")
     (define overload-source
       (string-append
        "(define-class Render004 (fields) (methods "
        "(z () Int 1) "
        "(pick (value Int) Int value) "
        "(pick (value String) String value) "
        "(a () String \"a\")))\n"
        "(Render004 new)\n"))
     (define original-entries (directory-entry-paths directory))
     (define result
       (run-exchange
        lsp:run-lsp-server
        (list
         (initialize-message)
         initialized-message
         (open-message uri string-source 1)
         (hover-message uri 0 0 "empty-catalog")
         (change-message uri overload-source 2)
         (hover-message uri 1 11 804)
         (shutdown-message)
         exit-message)))
     (check-clean-exchange result 4)
     (check-equal?
      (response-with-id (exchange-responses result) "empty-catalog")
      (hasheq
       'jsonrpc "2.0"
       'id "empty-catalog"
       'result (expected-string-hover 0)))
     (define expected-overload-hover
       (hasheq
        'contents
        (hasheq
         'kind "plaintext"
         'value
         (string-append
          "type: Render004\n"
          "messages:\n"
          "  z : () -> Int\n"
          "  pick : (Int) -> Int\n"
          "  pick : (String) -> String\n"
          "  a : () -> String"))
        'range
        (hasheq
         'start (hasheq 'line 1 'character 0)
         'end (hasheq 'line 1 'character 15))))
     (check-equal?
      (response-with-id (exchange-responses result) 804)
      (hasheq
       'jsonrpc "2.0"
       'id 804
       'result expected-overload-hover))
     (check-false (file-exists? path))
     (check-equal? (directory-entry-paths directory) original-entries))))

(test-case "source keeps one public query dependency and a narrow failure boundary"
  (define source (file->string lsp-module-path))
  (check-equal?
   (regexp-match* #rx"\"[^\"]+\\.rkt\"" source)
   '("\"expression-query.rkt\""))
  (for ([required
         (in-list
          '("query-expression-at"
            "expression-query-result?"
            "expression-query-result-location"
            "expression-query-result-signatures"
            "expression-query-result-type"
            "signature-spec-parameters"
            "signature-spec-return"
            "signature-spec-selector"))])
    (check-true (string-contains? source required)))
  (for ([forbidden
         (in-list
          '("parse.rkt"
            "type.rkt"
            "exn:fail:aloe-type?"
            "type-signature-specs"
            "method-catalog"
            "signature-catalog.rkt"
            "exn?"))])
    (check-false (string-contains? source forbidden)))
  (check-equal?
   (length
    (regexp-match* #px"\\(query\\s+path\\s+query-position\\)"
                   source))
   1))
