#lang racket/base

(require json
         net/url
         racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         rackunit)

(define-runtime-path lsp-module-path "../../../aloe/lsp.rkt")
(define-runtime-path fixture-path "fixtures/point.aloe")
(define-runtime-path repository-root "../../..")
(define-runtime-path info-path "../../../info.rkt")

(define normalized-repository-root
  (simplify-path (path->complete-path repository-root) #f))
(define normalized-fixture-path
  (simplify-path (path->complete-path fixture-path) #f))
(define fixture-bytes (file->bytes normalized-fixture-path))
(define fixture-text (bytes->string/utf-8 fixture-bytes))
(define fixture-uri (url->string (path->url normalized-fixture-path)))

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

(define (hover-message uri [id "point-hover"])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "textDocument/hover"
   'params
   (hasheq
    'textDocument (hasheq 'uri uri)
    'position (hasheq 'line 9 'character 7))))

(define (shutdown-message [id "shutdown"])
  (hasheq
   'jsonrpc "2.0"
   'id id
   'method "shutdown"))

(define exit-message
  (hasheq 'jsonrpc "2.0" 'method "exit"))

(define (success-response id result)
  (hasheq 'jsonrpc "2.0" 'id id 'result result))

(define (frame message)
  (define body (jsexpr->bytes message))
  (bytes-append
   (string->bytes/utf-8
    (format "Content-Length: ~a\r\n\r\n" (bytes-length body)))
   body))

(define (messages->bytes messages)
  (apply bytes-append (map frame messages)))

(define (decode-canonical-frames framed-bytes)
  (let loop ([remaining framed-bytes]
             [messages '()])
    (cond
      [(zero? (bytes-length remaining)) (reverse messages)]
      [else
       (define header-match
         (regexp-match
          #rx#"^Content-Length: ([0-9]+)\r\n\r\n"
          remaining))
       (unless header-match
         (error 'decode-canonical-frames
                "output contains an unframed or noncanonical byte"))
       (define header-length (bytes-length (first header-match)))
       (define content-length
         (string->number
          (bytes->string/utf-8 (second header-match))))
       (define body-end (+ header-length content-length))
       (when (> body-end (bytes-length remaining))
         (error 'decode-canonical-frames "short framed body"))
       (define body (subbytes remaining header-length body-end))
       (loop (subbytes remaining body-end)
             (cons (bytes->jsexpr body) messages))])))

(define (check-ports-open ports)
  (for ([port (in-list ports)])
    (check-false (port-closed? port))))

(struct main-result
  (statuses input output error-output)
  #:transparent)

(define (run-main-in-namespace arguments input-bytes)
  (define input (open-input-bytes input-bytes))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define statuses '())
  (parameterize
      ([current-namespace (make-base-namespace)]
       [current-command-line-arguments arguments]
       [current-input-port input]
       [current-output-port output]
       [current-error-port error-output]
       [exit-handler
        (lambda (status)
          (set! statuses (cons status statuses)))])
    (dynamic-require `(submod ,lsp-module-path main) #f))
  (main-result (reverse statuses) input output error-output))

(test-case "normal module is inert and exports only run-lsp-server"
  (define input (open-input-bytes #"normal require must not read this"))
  (define output (open-output-bytes))
  (define error-output (open-output-bytes))
  (define statuses '())
  (define-values (value-exports syntax-exports)
    (parameterize
        ([current-namespace (make-base-namespace)]
         [current-command-line-arguments #("unexpected")]
         [current-input-port input]
         [current-output-port output]
         [current-error-port error-output]
         [exit-handler
          (lambda (status)
            (set! statuses (cons status statuses)))])
      (dynamic-require lsp-module-path #f)
      (module->exports lsp-module-path)))
  (check-equal? value-exports '((0 (run-lsp-server ()))))
  (check-equal? syntax-exports '())
  (define run-lsp-server
    (parameterize ([current-namespace (make-base-namespace)])
      (dynamic-require lsp-module-path 'run-lsp-server)))
  (check-equal? (procedure-arity run-lsp-server) 3)
  (check-equal? statuses '())
  (check-equal? (file-position input) 0)
  (check-equal? (get-output-bytes output) #"")
  (check-equal? (get-output-bytes error-output) #"")
  (check-ports-open (list input output error-output)))

(test-case "main uses current ports and propagates successful status"
  (define exchange
    (messages->bytes
     (list
      (initialize-message)
      (shutdown-message)
      exit-message)))
  (define trailing (frame (initialize-message "after-exit")))
  (define result
    (run-main-in-namespace #() (bytes-append exchange trailing)))
  (check-equal? (main-result-statuses result) '(0))
  (check-equal? (file-position (main-result-input result))
                (bytes-length exchange))
  (check-equal?
   (decode-canonical-frames
    (get-output-bytes (main-result-output result)))
   (list
    (success-response "initialize" expected-initialize-result)
    (success-response "shutdown" (json-null))))
  (check-equal? (get-output-bytes (main-result-error-output result)) #"")
  (check-ports-open
   (list (main-result-input result)
         (main-result-output result)
         (main-result-error-output result))))

(test-case "main rejects even an empty-string argument before server input"
  (define server-input
    (messages->bytes
     (list
      (initialize-message)
      (shutdown-message)
      exit-message)))
  (define result (run-main-in-namespace #("") server-input))
  (check-equal? (main-result-statuses result) '(1))
  (check-equal? (file-position (main-result-input result)) 0)
  (check-equal? (get-output-bytes (main-result-output result)) #"")
  (check-equal? (get-output-bytes (main-result-error-output result)) #"")
  (check-ports-open
   (list (main-result-input result)
         (main-result-output result)
         (main-result-error-output result))))

(struct child-result (status output error-output) #:transparent)

(define (close-port-if-open port close-port)
  (unless (port-closed? port)
    (close-port port)))

(define (run-child executable arguments input-bytes environment directory)
  (define-values (process child-output child-input child-error)
    (parameterize ([current-environment-variables environment]
                   [current-directory directory])
      (apply subprocess #f #f #f executable arguments)))
  (dynamic-wind
    void
    (lambda ()
      (with-handlers
          ([exn:fail:filesystem?
            (lambda (exception)
              (unless (sync/timeout 0 process)
                (raise exception)))])
        (write-bytes input-bytes child-input)
        (flush-output child-input))
      (close-output-port child-input)
      (unless (sync/timeout 30 process)
        (subprocess-kill process #t)
        (unless (sync/timeout 5 process)
          (error 'run-child "child did not terminate after timeout"))
        (error 'run-child "child process timed out"))
      (child-result
       (subprocess-status process)
       (port->bytes child-output)
       (port->bytes child-error)))
    (lambda ()
      (when (eq? (subprocess-status process) 'running)
        (subprocess-kill process #t)
        (sync/timeout 5 process))
      (close-port-if-open child-input close-output-port)
      (close-port-if-open child-output close-input-port)
      (close-port-if-open child-error close-input-port))))

(define (call-with-isolated-package-state procedure)
  (define temporary-root
    (make-temporary-file
     "aloe-editor-lsp-009-~a"
     'directory
     (string->path "/tmp")))
  (define user-home (build-path temporary-root "racket-user-home"))
  (define launch-directory (build-path temporary-root "launch"))
  (make-directory user-home)
  (make-directory launch-directory)
  (dynamic-wind
    void
    (lambda ()
      (procedure user-home launch-directory))
    (lambda ()
      (when (directory-exists? temporary-root)
        (delete-directory/files temporary-root)))))

(define (repository-snapshot)
  (define (walk directory relative-directory)
    (apply
     append
     (for/list ([entry
                 (in-list
                  (sort (directory-list directory)
                        path<?))]
                #:unless
                (and (equal? relative-directory (string->path "."))
                     (equal? entry (string->path ".git"))))
       (define path (build-path directory entry))
       (define relative-path (build-path relative-directory entry))
       (cond
         [(directory-exists? path)
          (cons (list (path->string relative-path) 'directory)
                (walk path relative-path))]
         [(file-exists? path)
          (list (list (path->string relative-path)
                      'file
                      (file->bytes path)))]
         [else
          (list (list (path->string relative-path) 'other))]))))
  (walk normalized-repository-root (string->path ".")))

(define (copy-environment-with-user-home user-home)
  (define environment
    (environment-variables-copy (current-environment-variables)))
  (environment-variables-set!
   environment
   #"PLTUSERHOME"
   (path->bytes user-home))
  environment)

(define test-package-name "aloe-editor-lsp-009-test-package")

(test-case "installed collection command launches the real stdio server"
  (define racket-path (find-executable-path "racket"))
  (define raco-path (find-executable-path "raco"))
  (check-not-false racket-path)
  (check-not-false raco-path)
  (unless (and racket-path raco-path)
    (error '009-launch "racket and raco must be available through PATH"))
  (define source-before (repository-snapshot))
  (define info-before (file->bytes info-path))
  (call-with-isolated-package-state
   (lambda (user-home launch-directory)
     (define environment
       (copy-environment-with-user-home user-home))
     (define package-result
       (run-child
        raco-path
        (list
         "pkg" "install"
         "--batch"
         "--deps" "fail"
         "--no-setup"
         "--user"
         "--link"
         "--name" test-package-name
         normalized-repository-root)
        #""
        environment
        launch-directory))
     (check-equal?
      (child-result-status package-result)
      0
      (bytes->string/utf-8 (child-result-error-output package-result)))
     (unless (zero? (child-result-status package-result))
       (error '009-launch
              "isolated package link failed: ~a"
              (bytes->string/utf-8
               (child-result-error-output package-result))))

     (define successful-input
       (messages->bytes
        (list
         (initialize-message)
         initialized-message
         (open-message fixture-uri fixture-text)
         (hover-message fixture-uri)
         (shutdown-message)
         exit-message
         (initialize-message "after-exit"))))
     (define successful-result
       (run-child
        racket-path
        (list "-l" "aloe/lsp")
        successful-input
        environment
        launch-directory))
     (check-equal? (child-result-status successful-result) 0)
     (check-equal? (child-result-error-output successful-result) #"")
     (check-equal?
      (decode-canonical-frames (child-result-output successful-result))
      (list
       (success-response "initialize" expected-initialize-result)
       (success-response "point-hover" expected-hover)
       (success-response "shutdown" (json-null))))
     (define protocol-text
       (bytes->string/utf-8 (child-result-output successful-result)))
     (for ([forbidden
            (in-list
             (list
              (path->string normalized-repository-root)
              (path->string normalized-fixture-path)
              (path->string user-home)
              (path->string launch-directory)
              "(define-class (Point T)"
              "aloe-lsp-snapshot-"
              "diagnostic"
              "logging"
              "Welcome to Racket"))])
       (check-false (string-contains? protocol-text forbidden)))

     (define eof-result
       (run-child racket-path
                  (list "-l" "aloe/lsp")
                  #""
                  environment
                  launch-directory))
     (check-equal? (child-result-status eof-result) 1)
     (check-equal? (child-result-output eof-result) #"")

     (define early-exit-result
       (run-child racket-path
                  (list "-l" "aloe/lsp")
                  (frame exit-message)
                  environment
                  launch-directory))
     (check-equal? (child-result-status early-exit-result) 1)
     (check-equal? (child-result-output early-exit-result) #"")

     (define framing-result
       (run-child racket-path
                  (list "-l" "aloe/lsp")
                  #"Content-Length: nope\r\n\r\n"
                  environment
                  launch-directory))
     (check-equal? (child-result-status framing-result) 1)
     (check-equal? (child-result-output framing-result) #"")

     (define argument-result
       (run-child
        racket-path
        (list "-l" "aloe/lsp" "--" "unexpected")
        (messages->bytes
         (list
          (initialize-message)
          (shutdown-message)
          exit-message))
        environment
        launch-directory))
     (check-equal? (child-result-status argument-result) 1)
     (check-equal? (child-result-output argument-result) #"")

     (for ([result
            (in-list
             (list eof-result
                   early-exit-result
                   framing-result
                   argument-result))])
       (check-equal? (child-result-error-output result) #""))
     (check-equal? (directory-list launch-directory) '())))
  (check-equal? (repository-snapshot) source-before)
  (check-equal? (file->bytes info-path) info-before))

(test-case "production source has one narrow main submodule"
  (define source (file->string lsp-module-path))
  (check-equal?
   (length (regexp-match* #px"\\(module\\+\\s+main\\b" source))
   1)
  (check-equal?
   (length
    (regexp-match* #px"\\(current-command-line-arguments\\)" source))
   1)
  (check-equal? (length (regexp-match* #px"\\(exit\\s" source)) 1)
  (check-equal?
   (length
    (regexp-match*
     #px"\\(define\\s+\\(run-lsp-server\\s+input\\s+output\\s+error-output\\)"
     source))
   1)
  (check-equal?
   (length
    (regexp-match*
     #px"\\(define\\s+\\(run-lsp-server/with-query\\s+"
     source))
   1)
  (for ([forbidden
         (in-list
          '("racket/cmdline"
            "(command-line"
            "tcp-listen"
            "subprocess"
            "system*"
            "racket/thread"
            "async-channel"))])
    (check-false (string-contains? source forbidden))))
