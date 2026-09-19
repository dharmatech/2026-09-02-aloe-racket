#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         rackunit
         (prefix-in lsp: "../../../aloe/lsp.rkt")
         (prefix-in support:
                    (submod "../../../aloe/lsp.rkt" test-support))
         (prefix-in query: "../../../aloe/expression-query.rkt"))

(define-runtime-path lsp-module-path "../../../aloe/lsp.rkt")

(define did-open "textDocument/didOpen")
(define did-change "textDocument/didChange")
(define did-close "textDocument/didClose")

(define (open-params uri version text [language-id "aloe"])
  (hasheq
   'textDocument
   (hasheq
    'uri uri
    'languageId language-id
    'version version
    'text text)))

(define (change-params uri version changes)
  (hasheq
   'textDocument (hasheq 'uri uri 'version version)
   'contentChanges changes))

(define (close-params uri)
  (hasheq 'textDocument (hasheq 'uri uri)))

(define (check-document documents uri version text)
  (check-true (hash-has-key? documents uri))
  (define document (hash-ref documents uri))
  (check-true (support:open-document? document))
  (check-equal? (support:open-document-uri document) uri)
  (check-equal? (support:open-document-version document) version)
  (check-equal? (support:open-document-text document) text))

(test-case "didOpen stores and atomically replaces exact document state"
  (define documents (make-hash))
  (define uri "file:///tmp/exact%20document.aloe")
  (support:apply-document-sync!
   documents
   did-open
   (hasheq
    'textDocument
    (hasheq
     'uri uri
     'languageId "not-used-for-selection"
     'version 7
     'text "first\r\ntext"
     'unknown-item-property #t)
    'unknown-params-property "ignored"))
  (check-equal? (hash-count documents) 1)
  (check-document documents uri 7 "first\r\ntext")
  (support:apply-document-sync!
   documents did-open (open-params uri -3 "replacement"))
  (check-equal? (hash-count documents) 1)
  (check-document documents uri -3 "replacement"))

(test-case "full changes retain only the last replacement and exact version"
  (define documents (make-hash))
  (define uri "file:///tmp/change.aloe")
  (support:apply-document-sync!
   documents did-open (open-params uri 10 "original"))
  (support:apply-document-sync!
   documents
   did-change
   (hasheq
    'textDocument
    (hasheq 'uri uri 'version 10 'unknown "ignored")
    'contentChanges
    (list (hasheq 'text "first" 'unknown 1)
          (hasheq 'text "second")
          (hasheq 'text "last"))
    'unknown #f))
  (check-document documents uri 10 "last")
  (support:apply-document-sync!
   documents did-change (change-params uri -5 '()))
  (check-document documents uri -5 "last")
  (support:apply-document-sync!
   documents
   did-change
   (change-params uri -6 (list (hasheq 'text "lower version"))))
  (check-document documents uri -6 "lower version"))

(test-case "exact URI spellings remain independent keys"
  (define documents (make-hash))
  (define uri-a "file:///tmp/aloe-sync-document.aloe")
  (define uri-b "file:///tmp/%61loe-sync-document.aloe")
  (check-equal? (url->path (string->url uri-a))
                (url->path (string->url uri-b)))
  (support:apply-document-sync!
   documents did-open (open-params uri-a 1 "plain spelling"))
  (support:apply-document-sync!
   documents did-open (open-params uri-b 2 "encoded spelling"))
  (support:apply-document-sync!
   documents
   did-change
   (change-params uri-a 3 (list (hasheq 'text "changed plain"))))
  (check-document documents uri-a 3 "changed plain")
  (check-document documents uri-b 2 "encoded spelling")
  (support:apply-document-sync!
   documents
   did-close
   (hasheq
    'textDocument (hasheq 'uri uri-a 'unknown #t)
    'unknown "ignored"))
  (check-false (hash-has-key? documents uri-a))
  (check-document documents uri-b 2 "encoded spelling"))

(test-case "unopened change and close notifications are no-ops"
  (define documents (make-hash))
  (support:apply-document-sync!
   documents
   did-change
   (change-params "file:///tmp/unopened.aloe"
                  1
                  (list (hasheq 'text "not opened"))))
  (support:apply-document-sync!
   documents did-close (close-params "file:///tmp/unopened.aloe"))
  (check-equal? documents (make-hash)))

(test-case "malformed synchronization notifications preserve all state"
  (define uri "file:///tmp/known.aloe")
  (define malformed-cases
    (list
     (list did-open #f)
     (list did-open (hasheq))
     (list did-open (hasheq 'textDocument "not-an-object"))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'languageId "aloe" 'version 2 'text "new")))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri 7 'languageId "aloe" 'version 2 'text "new")))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri uri 'version 2 'text "new")))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri uri 'languageId #f 'version 2 'text "new")))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri uri 'languageId "aloe" 'text "new")))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri uri 'languageId "aloe" 'version 2.0
                           'text "new")))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri uri 'languageId "aloe" 'version 2)))
     (list did-open
           (hasheq 'textDocument
                   (hasheq 'uri uri 'languageId "aloe" 'version 2 'text 8)))
     (list did-change #f)
     (list did-change (hasheq))
     (list did-change
           (hasheq 'textDocument "not-an-object" 'contentChanges '()))
     (list did-change
           (hasheq 'textDocument (hasheq 'version 2) 'contentChanges '()))
     (list did-change
           (hasheq 'textDocument (hasheq 'uri #f 'version 2)
                   'contentChanges '()))
     (list did-change
           (hasheq 'textDocument (hasheq 'uri uri) 'contentChanges '()))
     (list did-change
           (hasheq 'textDocument (hasheq 'uri uri 'version 2.0)
                   'contentChanges '()))
     (list did-change
           (hasheq 'textDocument (hasheq 'uri uri 'version 2)))
     (list did-change
           (hasheq 'textDocument (hasheq 'uri uri 'version 2)
                   'contentChanges "not-an-array"))
     (list did-change
           (change-params uri 2 (list "not-an-object")))
     (list did-change
           (change-params uri 2 (list (hasheq))))
     (list did-change
           (change-params uri 2 (list (hasheq 'text 10))))
     (list did-change
           (change-params uri 2
                          (list (hasheq 'text "incremental" 'range (json-null)))))
     (list did-change
           (change-params uri 2
                          (list (hasheq 'text "incremental"
                                        'rangeLength (json-null)))))
     (list did-close #f)
     (list did-close (hasheq))
     (list did-close (hasheq 'textDocument "not-an-object"))
     (list did-close (hasheq 'textDocument (hasheq)))
     (list did-close (hasheq 'textDocument (hasheq 'uri 11)))))
  (for ([case (in-list malformed-cases)])
    (define documents (make-hash))
    (support:apply-document-sync!
     documents did-open (open-params uri 1 "known text"))
    (support:apply-document-sync!
     documents did-open (open-params "file:///tmp/other.aloe" 4 "other"))
    (define before (hash-copy documents))
    (support:apply-document-sync! documents (first case) (second case))
    (check-equal? documents before)))

(test-case "a later invalid change item prevents every replacement"
  (define documents (make-hash))
  (define uri "file:///tmp/atomic.aloe")
  (support:apply-document-sync!
   documents did-open (open-params uri 4 "before"))
  (support:apply-document-sync!
   documents
   did-change
   (change-params
    uri
    5
    (list (hasheq 'text "would-be replacement")
          (hasheq 'text "incremental" 'rangeLength (json-null)))))
  (check-document documents uri 4 "before"))

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
          (check-not-false match)
          (define length
            (string->number (bytes->string/utf-8 (second match))))
          (check-equal? (read-bytes-line input 'any) #"")
          (define body (read-bytes length input))
          (check-true (bytes? body))
          (check-equal? (bytes-length body) length)
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

(define (open-message uri version text)
  (hasheq
   'jsonrpc "2.0"
   'method did-open
   'params (open-params uri version text)))

(define (change-message uri version changes)
  (hasheq
   'jsonrpc "2.0"
   'method did-change
   'params (change-params uri version changes)))

(define (close-message uri)
  (hasheq
   'jsonrpc "2.0"
   'method did-close
   'params (close-params uri)))

(define (hover-message uri line character id)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/hover"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri)
    'position (hasheq 'line line 'character character))))

(define shutdown-message
  (hasheq
   'jsonrpc "2.0"
   'id "shutdown"
   'method "shutdown"))

(define exit-message
  (hasheq
   'jsonrpc "2.0"
   'method "exit"))

(struct exchange (status error responses) #:transparent)

(define (run-exchange messages query-procedure)
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define status
    (support:run-lsp-server/with-query
     input output error-output query-procedure))
  (exchange status
            (get-output-bytes error-output)
            (decode-frames (get-output-bytes output))))

(define (call-with-test-file disk-text procedure)
  (define directory
    (make-temporary-file "aloe-lsp-002-~a" 'directory))
  (define path
    (make-temporary-file "document-~a.aloe" #f directory))
  (dynamic-wind
    (lambda ()
      (call-with-output-file path
        #:exists 'truncate/replace
        (lambda (output)
          (write-bytes (string->bytes/utf-8 disk-text) output))))
    (lambda () (procedure path directory))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (stub-result start [span 0])
  (query:expression-query-result
   'Stub
   (list (query:signature-spec 'probe '() 'Stub))
   (srcloc 'ignored 1 0 start span)))

(define (check-clean-exchange result response-count)
  (check-equal? (exchange-status result) 0)
  (check-equal? (exchange-error result) #"")
  (check-equal? (length (exchange-responses result)) response-count))

(test-case "framed multiple change observes only final synchronized text"
  (define final-text "😀\r\nfinal")
  (call-with-test-file
   final-text
   (lambda (path _directory)
     (define uri (url->string (path->url path)))
     (define calls '())
     (define result
       (run-exchange
        (list initialize-message
              initialized-message
              (open-message uri 1 "initial")
              (change-message uri
                              2
                              (list (hasheq 'text "dirty first")
                                    (hasheq 'text final-text)))
              (hover-message uri 1 5 "final-hover")
              shutdown-message
              exit-message)
        (lambda (query-path query-position)
          (set! calls (list (list query-path query-position)))
          (stub-result 4 5))))
     (check-clean-exchange result 3)
     (check-equal? (map (lambda (response) (hash-ref response 'id))
                        (exchange-responses result))
                   '("initialize" "final-hover" "shutdown"))
     (check-equal? (length calls) 1)
     (check-equal? (simplify-path (first (first calls)) #f)
                   (simplify-path path #f))
     (check-equal? (second (first calls)) 9)
     (check-not-equal?
      (hash-ref (second (exchange-responses result)) 'result)
      (json-null)))))

(test-case "framed malformed change leaves the original synchronized text"
  (define original-text "abc\r\nstay")
  (call-with-test-file
   original-text
   (lambda (path _directory)
     (define uri (url->string (path->url path)))
     (define calls '())
     (define result
       (run-exchange
        (list initialize-message
              initialized-message
              (open-message uri 1 original-text)
              (change-message
               uri
               2
               (list (hasheq 'text "first replacement")
                     (hasheq 'text "invalid second" 'range (json-null))))
              (hover-message uri 1 4 "original-hover")
              shutdown-message
              exit-message)
        (lambda (_query-path query-position)
          (set! calls (append calls (list query-position)))
          (stub-result 6 4))))
     (check-clean-exchange result 3)
     (check-equal? calls '(10))
     (check-not-equal?
      (hash-ref (second (exchange-responses result)) 'result)
      (json-null)))))

(test-case "close removes hover state and reopen establishes fresh state"
  (define reopened-text "reopened")
  (call-with-test-file
   reopened-text
   (lambda (path _directory)
     (define uri (url->string (path->url path)))
     (define calls '())
     (define result
       (run-exchange
        (list initialize-message
              initialized-message
              (open-message uri 1 "old text")
              (close-message uri)
              (hover-message uri 0 0 "closed-hover")
              (open-message uri -10 reopened-text)
              (hover-message uri 0 3 "reopened-hover")
              shutdown-message
              exit-message)
        (lambda (_query-path query-position)
          (set! calls (append calls (list query-position)))
          (stub-result 1))))
     (check-clean-exchange result 4)
     (check-equal? calls '(4))
     (check-equal?
      (hash-ref (second (exchange-responses result)) 'result)
      (json-null))
     (check-not-equal?
      (hash-ref (third (exchange-responses result)) 'result)
      (json-null)))))

(test-case "dirty final change queries a snapshot without changing the filesystem"
  (define disk-text "disk text")
  (call-with-test-file
   disk-text
   (lambda (path directory)
     (define uri (url->string (path->url path)))
     (define original-bytes (file->bytes path))
     (define original-entries (directory-list directory))
     (define calls 0)
     (define result
       (run-exchange
        (list initialize-message
              initialized-message
              (open-message uri 1 disk-text)
              (change-message uri
                              2
                              (list (hasheq 'text disk-text)
                                    (hasheq 'text "dirty final text")))
              (hover-message uri 0 0 "dirty-hover")
              shutdown-message
              exit-message)
        (lambda (_query-path _query-position)
          (set! calls (add1 calls))
          (stub-result 1))))
     (check-clean-exchange result 3)
     (check-equal? calls 1)
     (check-not-equal?
      (hash-ref (second (exchange-responses result)) 'result)
      (json-null))
     (check-equal? (file->bytes path) original-bytes)
     (check-equal? (directory-list directory) original-entries))))

(define missing-export (gensym 'missing-export))

(define (normal-module-exports? name)
  (not
   (eq? (dynamic-require
         lsp-module-path
         name
         (lambda () missing-export))
        missing-export)))

(test-case "document synchronization internals remain private"
  (check-true (procedure-arity-includes? lsp:run-lsp-server 3))
  (for ([name
         (in-list
          '(run-lsp-server/with-query
            apply-document-sync!
            open-document
            open-document?
            open-document-uri
            open-document-version
            open-document-text
            documents))])
    (check-false (normal-module-exports? name))))
