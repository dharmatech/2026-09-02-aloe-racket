#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/string
         rackunit
         "../../../aloe/parse.rkt"
         "../../../aloe/lsp.rkt"
         "../../../aloe/completion-query.rkt")

;; Locations are written (line column position span).
(define (location loc)
  (list (srcloc-line loc)
        (srcloc-column loc)
        (srcloc-position loc)
        (srcloc-span loc)))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-file "aloe-lsp-010-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (procedure directory))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (write-text! path text)
  (call-with-output-file path
    #:exists 'truncate/replace
    (lambda (output)
      (write-bytes (string->bytes/utf-8 text) output))))

;; The send in the second form of "x<break>(a b)": the send, its
;; receiver, and its selector.
(define (second-send-locs expressions)
  (define send (second expressions))
  (list (expression-loc send)
        (expression-loc (send-expr-receiver send))
        (send-expr-selector-loc send)))

(test-case "parser: one line break"
  (for ([text (in-list (list "x\n(a b)" "x\r(a b)"))])
    (check-equal? (map location (second-send-locs (read-program text)))
                  '((2 0 3 5) (2 1 4 1) (2 3 6 1))
                  text))
  (check-equal? (map location (second-send-locs (read-program "x\r\n(a b)")))
                '((2 0 4 5) (2 1 5 1) (2 3 7 1)))
  (call-with-temporary-directory
   (lambda (directory)
     (define source-path (build-path directory "crlf.aloe"))
     (define locs
       (second-send-locs
        (read-program (open-input-bytes (string->bytes/utf-8 "x\r\n(a b)"))
                      #:source-path source-path)))
     (check-equal? (map location locs)
                   '((2 0 4 5) (2 1 5 1) (2 3 7 1)))
     (for ([loc (in-list locs)])
       (check-equal? (srcloc-source loc) source-path)))))

(test-case "parser: a span across a line break"
  (define expressions (read-program "(a\r\n b) c"))
  (check-equal? (location (expression-loc (first expressions)))
                '(1 0 1 7))
  (check-equal? (location (expression-loc (second expressions)))
                '(2 4 9 1)))

(test-case "parser: characters, a string literal, and a port"
  ;; U+1F600, then a raw CR LF inside the string literal.
  (define text "(define s \"😀\r\nx\")\r\ns")
  (define (locations expressions)
    (list (location (expression-loc (define-expr-value (first expressions))))
          (location (expression-loc (second expressions)))))
  (define expected '((1 10 11 6) (3 0 20 1)))
  (check-equal? (locations (read-program text)) expected)
  (check-equal? (locations
                 (read-program (open-input-bytes (string->bytes/utf-8 text))))
                expected))

;; LSP exchanges through the public server and its real queries.

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
          (define declared-length
            (string->number (bytes->string/utf-8 (second match))))
          (check-equal? (read-bytes-line input 'any) #"")
          (loop (cons (bytes->jsexpr (read-bytes declared-length input))
                      messages))))))

(define (request id method params)
  (hasheq 'jsonrpc "2.0" 'id id 'method method 'params params))

(define (notification method params)
  (hasheq 'jsonrpc "2.0" 'method method 'params params))

(define (position-params uri position)
  (hasheq 'textDocument (hasheq 'uri uri)
          'position (hasheq 'line (first position)
                            'character (second position))))

;; Opens text as path's document, sends one request per position, and
;; returns those requests' results in order.
(define (lsp-results path text method positions)
  (define uri (url->string (path->url path)))
  (define messages
    (append
     (list (request "initialize" "initialize" (hasheq))
           (notification "initialized" (hasheq))
           (notification
            "textDocument/didOpen"
            (hasheq 'textDocument
                    (hasheq 'uri uri
                            'languageId "aloe"
                            'version 1
                            'text text))))
     (for/list ([position (in-list positions)]
                [index (in-naturals)])
       (request index method (position-params uri position)))
     (list (hasheq 'jsonrpc "2.0" 'id "shutdown" 'method "shutdown")
           (hasheq 'jsonrpc "2.0" 'method "exit"))))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (check-equal?
   (run-lsp-server
    (open-input-bytes (apply bytes-append (map frame messages)))
    output
    error-output)
   0)
  (check-equal? (get-output-bytes error-output) #"")
  (define responses (decode-frames (get-output-bytes output)))
  (check-equal? (length responses) (+ (length positions) 2))
  (for/list ([response (in-list (take (drop responses 1)
                                      (length positions)))]
             [index (in-naturals)])
    (check-equal? (hash-ref response 'id) index)
    (hash-ref response 'result)))

(define (lsp-range start-line start-character end-line end-character)
  (hasheq 'start (hasheq 'line start-line 'character start-character)
          'end (hasheq 'line end-line 'character end-character)))

(define (hover-summary result)
  (list (first (string-split (hash-ref (hash-ref result 'contents) 'value)
                             "\n"))
        (hash-ref result 'range)))

(define (lf-text crlf-text)
  (string-replace crlf-text "\r\n" "\n"))

;; Hovers the CRLF text from a file with the same bytes, checks each
;; position's first hover line and range, then checks that the LF text
;; at the same path gives the same whole results.
(define (check-hover crlf-text expected)
  (define positions (map first expected))
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "hover.aloe"))
     (write-text! path crlf-text)
     (define crlf-results
       (lsp-results path crlf-text "textDocument/hover" positions))
     (check-equal? (map hover-summary crlf-results)
                   (map (lambda (row) (list (second row) (third row)))
                        expected))
     (write-text! path (lf-text crlf-text))
     (check-equal?
      (lsp-results path (lf-text crlf-text) "textDocument/hover" positions)
      crlf-results))))

(test-case "hover: real query on CRLF text"
  (check-hover
   "(define x 1)\r\n(define y \"s\")\r\n(x + 2)\r\n"
   (list (list '(2 1) "type: Int" (lsp-range 2 1 2 2))
         (list '(2 0) "type: Int" (lsp-range 2 0 2 7))
         (list '(1 9) "type: Void" (lsp-range 1 0 1 14))))
  (check-hover
   "(define-class P\r\n  (fields (x Int))\r\n  (methods))\r\n(P new 1)\r\n"
   (list (list '(0 1) "type: Void" (lsp-range 0 0 2 12))
         (list '(3 1) "type: (Class P)" (lsp-range 3 1 3 2)))))

(define completion-prefix "(define-class P (fields (x Int)) (methods))")
(define completion-tail "((P new 1) ")

(define (completion-summary source)
  (for/list ([item (in-list (query-selector-completions
                             source
                             (add1 (string-length source))))])
    (list (selector-completion-item-label item)
          (selector-completion-item-replacement-start item)
          (selector-completion-item-replacement-span item))))

(define (lsp-completion-summary text position)
  (call-with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "completion.aloe"))
     (write-text! path text)
     (for/list ([item (in-list (first (lsp-results path
                                                   text
                                                   "textDocument/completion"
                                                   (list position))))])
       (list (hash-ref item 'label)
             (hash-ref (hash-ref item 'textEdit) 'range))))))

(test-case "completion: real query on CRLF text"
  (define crlf-source
    (string-append completion-prefix "\r\n" completion-tail))
  (check-equal? (completion-summary crlf-source) '(("x" 57 0)))
  (check-equal? (completion-summary (string-append crlf-source "x"))
                '(("x" 57 1)))
  (define expected-lsp (list (list "x" (lsp-range 1 11 1 11))))
  (check-equal? (lsp-completion-summary crlf-source '(1 11)) expected-lsp)
  (for ([break (in-list (list "\n" "\r"))])
    (define source (string-append completion-prefix break completion-tail))
    (check-equal? (completion-summary source) '(("x" 56 0)) break)
    (check-equal? (completion-summary (string-append source "x"))
                  '(("x" 56 1))
                  break)
    (check-equal? (lsp-completion-summary source '(1 11)) expected-lsp
                  break)))
