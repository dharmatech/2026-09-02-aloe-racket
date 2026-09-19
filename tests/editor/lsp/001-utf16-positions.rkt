#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/path
         racket/port
         rackunit
         (prefix-in support:
                    (submod "../../../aloe/lsp.rkt" test-support))
         (prefix-in query: "../../../aloe/expression-query.rkt"))

(define mixed-text "a😀b\r\nλz\rq\n尾")

(define mixed-boundaries
  ;; offset, LSP line, LSP character, one-based query position
  '((0 0 0 1)
    (1 0 1 2)
    (2 0 3 3)
    (3 0 4 4)
    (5 1 0 6)
    (6 1 1 7)
    (7 1 2 8)
    (8 2 0 9)
    (9 2 1 10)
    (10 3 0 11)
    (11 3 1 12)))

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

(define (initialize-message)
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

(define (hover-message uri position id)
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/hover"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri)
    'position
    (hasheq
     'line (first position)
     'character (second position)))))

(define shutdown-message
  (hasheq
   'jsonrpc "2.0"
   'id "shutdown"
   'method "shutdown"))

(define exit-message
  (hasheq
   'jsonrpc "2.0"
   'method "exit"))

(struct exchange (status error responses hover-results) #:transparent)

(define (run-exchange path synchronized-text positions query-procedure)
  (define uri (url->string (path->url path)))
  (define messages
    (append
     (list (initialize-message)
           initialized-message
           (open-message uri synchronized-text))
     (for/list ([position (in-list positions)]
                [index (in-naturals)])
       (hover-message uri position (format "hover-~a" index)))
     (list shutdown-message exit-message)))
  (define input
    (open-input-bytes (apply bytes-append (map frame messages))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define status
    (support:run-lsp-server/with-query
     input output error-output query-procedure))
  (define responses (decode-frames (get-output-bytes output)))
  (exchange
   status
   (get-output-bytes error-output)
   responses
   (map (lambda (response) (hash-ref response 'result))
        (take (drop responses 1) (length positions)))))

(define (call-with-test-file disk-text procedure)
  (define directory
    (make-temporary-file "aloe-lsp-001-~a" 'directory))
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

(define (stub-result start span)
  (query:expression-query-result
   'Stub
   (list (query:signature-spec 'probe '() 'Stub))
   ;; These deliberately disagree with the actual range.
   (srcloc 'ignored-source 999 777 start span)))

(define (check-clean-exchange result expected-hover-count)
  (check-equal? (exchange-status result) 0)
  (check-equal? (exchange-error result) #"")
  (check-equal? (length (exchange-responses result))
                (+ expected-hover-count 2)))

(define (position line character)
  (hasheq 'line line 'character character))

(test-case "mixed UTF-16 positions convert exactly in both directions"
  (call-with-test-file
   mixed-text
   (lambda (path _directory)
     (define calls '())
     (define result
       (run-exchange
        path
        mixed-text
        (for/list ([boundary (in-list mixed-boundaries)])
          (list (second boundary) (third boundary)))
        (lambda (query-path query-position)
          (set! calls (append calls (list (list query-path query-position))))
          (stub-result query-position 0))))
     (check-clean-exchange result (length mixed-boundaries))
     (check-equal? (map second calls) (map fourth mixed-boundaries))
     (for ([call (in-list calls)])
       (check-equal? (simplify-path (first call) #f)
                     (simplify-path path #f)))
     (for ([hover-result (in-list (exchange-hover-results result))]
           [boundary (in-list mixed-boundaries)])
       (define expected-position
         (position (second boundary) (third boundary)))
       (check-equal?
        (hash-ref hover-result 'range)
        (hasheq 'start expected-position 'end expected-position))))))

(test-case "invalid incoming positions do not query"
  (call-with-test-file
   mixed-text
   (lambda (path _directory)
     (define calls 0)
     (define result
       (run-exchange
        path
        mixed-text
        '((0 2) (1 3) (4 0))
        (lambda (_path _position)
          (set! calls (add1 calls))
          (stub-result 1 0))))
     (check-clean-exchange result 3)
     (check-equal? calls 0)
     (for ([hover-result (in-list (exchange-hover-results result))])
       (check-equal? hover-result (json-null))))))

(test-case "a range crosses a supplementary character and CRLF"
  (call-with-test-file
   mixed-text
   (lambda (path _directory)
     (define calls 0)
     (define result
       (run-exchange
        path
        mixed-text
        '((0 0))
        (lambda (_path _position)
          (set! calls (add1 calls))
          ;; Offset 1 through offset 6 is five Racket characters.
          (stub-result 2 5))))
     (check-clean-exchange result 1)
     (check-equal? calls 1)
     (check-equal?
      (hash-ref (first (exchange-hover-results result)) 'range)
      (hasheq
       'start (position 0 1)
       'end (position 1 1))))))

(test-case "range endpoints inside CRLF are rejected after one query"
  (call-with-test-file
   mixed-text
   (lambda (path _directory)
     (define locations '((5 0) (4 1)))
     (define calls 0)
     (define result
       (run-exchange
        path
        mixed-text
        '((0 0) (0 0))
        (lambda (_path _position)
          (define location (list-ref locations calls))
          (set! calls (add1 calls))
          (stub-result (first location) (second location)))))
     (check-clean-exchange result 2)
     (check-equal? calls 2)
     (for ([hover-result (in-list (exchange-hover-results result))])
       (check-equal? hover-result (json-null))))))

(test-case "range endpoints outside the text are rejected after one query"
  (call-with-test-file
   mixed-text
   (lambda (path _directory)
     (define locations '((13 0) (12 1)))
     (define calls 0)
     (define result
       (run-exchange
        path
        mixed-text
        '((0 0) (0 0))
        (lambda (_path _position)
          (define location (list-ref locations calls))
          (set! calls (add1 calls))
          (stub-result (first location) (second location)))))
     (check-clean-exchange result 2)
     (check-equal? calls 2)
     (for ([hover-result (in-list (exchange-hover-results result))])
       (check-equal? hover-result (json-null))))))

(test-case "each trailing line break creates exactly one empty line"
  (for ([case (in-list '(("x\n" 3)
                         ("x\r\n" 4)
                         ("x\r" 3)))])
    (define text (first case))
    (define expected-query-position (second case))
    (call-with-test-file
     text
     (lambda (path _directory)
       (define calls '())
       (define result
         (run-exchange
          path
          text
          '((1 0) (2 0))
          (lambda (_path query-position)
            (set! calls (append calls (list query-position)))
            (stub-result 1 0))))
       (check-clean-exchange result 2)
       (check-equal? calls (list expected-query-position))
       (check-not-equal? (first (exchange-hover-results result)) (json-null))
       (check-equal? (second (exchange-hover-results result)) (json-null))))))

(test-case "BMP, supplementary, and Unicode separator widths are exact"
  (define text "λ\u2028😀尾")
  (call-with-test-file
   text
   (lambda (path _directory)
     (define calls '())
     (define result
       (run-exchange
        path
        text
        '((0 0) (0 1) (0 2) (0 3) (0 4) (0 5) (1 0))
        (lambda (_path query-position)
          (set! calls (append calls (list query-position)))
          (stub-result 1 0))))
     (check-clean-exchange result 7)
     (check-equal? calls '(1 2 3 4 5))
     (for ([hover-result (in-list (exchange-hover-results result))]
           [valid? (in-list '(#t #t #t #f #t #t #f))])
       (if valid?
           (check-not-equal? hover-result (json-null))
           (check-equal? hover-result (json-null)))))))

(test-case "a one-byte disk mismatch queries and removes a sibling"
  (define disk-text
    (string-append "b" (substring mixed-text 1)))
  (call-with-test-file
   disk-text
   (lambda (path directory)
     (define original-bytes (file->bytes path))
     (define original-entries (directory-list directory))
     (define calls 0)
     (define result
       (run-exchange
        path
        mixed-text
        '((0 0))
        (lambda (_path _position)
          (set! calls (add1 calls))
          (stub-result 1 0))))
     (check-clean-exchange result 1)
     (check-equal? calls 1)
     (check-not-equal? (first (exchange-hover-results result)) (json-null))
     (check-equal? (file->bytes path) original-bytes)
     (check-equal? (directory-list directory) original-entries))))
