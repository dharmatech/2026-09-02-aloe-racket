#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         rackunit
         "../../../aloe/expression-query.rkt"
         "../../../aloe/definition-query.rkt"
         "../../../aloe/completion-query.rkt"
         (only-in "../../../aloe/main.rkt"
                  exn:fail:aloe-type?
                  make-type-environment)
         (only-in "../../../aloe/host.rkt"
                  make-host-interface
                  make-host-method
                  host-interface-methods
                  host-method-selector
                  host-method-parameter-types
                  host-method-return-type
                  host-receiver-interface)
         (only-in (submod "../../../aloe/type.rkt" load-cache)
                  type-environment-base)
         (only-in (submod "../../../aloe/type.rkt" query-host-binding)
                  type-environment-bind-host-interface!)
         (only-in (submod "../../../aloe/type.rkt" host-binding-interface)
                  checker-host-interface)
         (only-in (submod "../../../aloe/type.rkt" driver-host-injection)
                  type-environment-inject-host!)
         "../../../host/racket/fs.rkt"
         "../../../host/racket/term.rkt")

(define-runtime-path configured-folder "fixtures/configured")
(define-runtime-path aloemacs-main-path "../../../examples/aloemacs/main.aloe")
(define-runtime-path aloemacs-file-path "../../../examples/aloemacs/file.aloe")
(define-runtime-path fs-library-path "../../../lib/fs.aloe")
(define-runtime-path option-path "../../../lib/option.aloe")
(define-runtime-path gel-main-path "../../../gel/main.aloe")
(define-runtime-path type-module-path "../../../aloe/type.rkt")
(define-runtime-path main-module-path "../../../aloe/main.rkt")

(define spot-path (build-path configured-folder "spot.aloe"))
(define reads-fs-path (build-path configured-folder "reads-fs.aloe"))
(define uses-path (build-path configured-folder "uses-fs.aloe"))
(define defines-fs-host-path
  (build-path configured-folder "defines-fs-host.aloe"))

(define fs-hosts (list (cons 'fs-host fs-interface)))
(define term-hosts (list (cons 'term term-interface)))

(define (normalized path)
  (simplify-path (path->complete-path path) #f))

;; An interface's methods as hover rows, in declaration order.
(define (interface-rows interface)
  (for/list ([method (in-list (host-interface-methods interface))])
    (signature-spec (host-method-selector method)
                    (host-method-parameter-types method)
                    (host-method-return-type method))))

;; An interface's methods as completion items at start and span, in
;; declaration order.
(define (interface-items interface start span)
  (for/list ([method (in-list (host-interface-methods interface))])
    (define label (format "~s" (host-method-selector method)))
    (selector-completion-item
     label
     (format "~s -> ~s"
             (host-method-parameter-types method)
             (host-method-return-type method))
     label
     start
     span)))

;; The zero-based index of needle's one occurrence in text.
(define (unique-index text needle)
  (define matches (regexp-match-positions* (regexp-quote needle) text))
  (check-equal? (length matches) 1 needle)
  (caar matches))

;; The zero-based index of needle's first occurrence in text.
(define (first-index text needle)
  (caar (regexp-match-positions (regexp-quote needle) text)))

;; The one-based line and zero-based column of a zero-based index in text.
(define (index-line-column text index)
  (define preceding (substring text 0 index))
  (define newlines (regexp-match-positions* #rx"\n" preceding))
  (list (add1 (length newlines))
        (if (null? newlines)
            index
            (- index (cdr (last newlines))))))

;; A location's (line column position span).
(define (location-numbers loc)
  (list (srcloc-line loc)
        (srcloc-column loc)
        (srcloc-position loc)
        (srcloc-span loc)))

;; The (line column position span) of span characters at index in text.
(define (text-numbers text index span)
  (append (index-line-column text index) (list (add1 index) span)))

(define ((message-starts-with prefix) exn)
  (and (exn:fail:contract? exn)
       (string-prefix? (exn-message exn) prefix)))

(define (check-contract-prefix prefix thunk)
  (check-exn (message-starts-with prefix) thunk))

(define (check-aloe-type-message message thunk)
  (check-exn (lambda (exn)
               (and (exn:fail:aloe-type? exn)
                    (equal? (exn-message exn) message)))
             thunk))

(define (check-unbound name thunk)
  (check-aloe-type-message
   (format "typecheck: unbound symbol: ~a" name)
   thunk))

;; A hover answer on a host: its interface's name, its rows, and its location
;; in source.
(define (check-host-hover result interface-name interface source numbers)
  (check-true (expression-query-result? result))
  (check-equal? (expression-query-result-type result) interface-name)
  (check-equal? (expression-query-result-pathed-type result) interface-name)
  (check-equal? (expression-query-result-signatures result)
                (interface-rows interface))
  (define location (expression-query-result-location result))
  (check-equal? (srcloc-source location) (normalized source))
  (check-equal? (location-numbers location) numbers))

;; A definition answer in target at numbers, whose text is target's text.
(define (check-jump result target numbers)
  (check-true (definition-query-result? result))
  (define location (definition-query-result-location result))
  (check-equal? (srcloc-source location) (normalized target))
  (check-equal? (location-numbers location) numbers)
  (check-equal? (definition-query-result-text result) (file->string target)))

(define uses-text (file->string uses-path))
(define hole-text
  (string-replace uses-text
                  "(define here (fs-host current))"
                  "(define here (fs-host ))"))

(define (complete-hole #:hosts [hosts '()])
  (query-selector-completions hole-text 66
                              #:source-path uses-path
                              #:hosts hosts))

(define (call-with-temporary-directory procedure)
  (define directory
    (make-temporary-file "host-queries-000-~a"
                         'directory
                         (find-system-path 'temp-dir)))
  (dynamic-wind
    void
    (lambda () (procedure directory))
    (lambda ()
      (when (directory-exists? directory)
        (delete-directory/files directory)))))

(define (write-source path source)
  (call-with-output-file path
    (lambda (output) (display source output))
    #:exists 'truncate))

(test-case "the query hook binds a host's type from its interface alone"
  (define base (type-environment-base (make-type-environment)))
  (type-environment-bind-host-interface! base 'fs-host fs-interface)
  (check-eq? (checker-host-interface base 'fs-host) fs-interface)

  (check-contract-prefix
   (string-append "type-environment-bind-host-interface!: "
                  "environment must be a type environment")
   (lambda ()
     (type-environment-bind-host-interface! 'nope 'fs-host fs-interface)))
  (check-contract-prefix
   "type-environment-bind-host-interface!: name must be a symbol"
   (lambda ()
     (type-environment-bind-host-interface! base "fs-host" fs-interface)))
  (check-contract-prefix
   (string-append "type-environment-bind-host-interface!: "
                  "interface must be a validated host interface")
   (lambda ()
     (type-environment-bind-host-interface! base 'fs-host
                                            (make-fs-receiver))))

  (type-environment-bind-host-interface! base 'fs-host term-interface)
  (check-eq? (checker-host-interface base 'fs-host) term-interface)
  (check-exn exn:fail? (lambda () (checker-host-interface base 'Option)))

  (define receiver (make-fs-receiver))
  (type-environment-inject-host! base 'other receiver)
  (check-eq? (checker-host-interface base 'other)
             (host-receiver-interface receiver))
  (check-contract-prefix
   "type-environment-inject-host!: environment must be a type environment"
   (lambda () (type-environment-inject-host! 'nope 'other receiver)))
  (check-contract-prefix
   "type-environment-inject-host!: name must be a symbol"
   (lambda () (type-environment-inject-host! base "other" receiver)))
  (check-contract-prefix
   "type-environment-inject-host!: receiver must be a validated host receiver"
   (lambda () (type-environment-inject-host! base 'other fs-interface)))

  (check-exn exn:fail?
             (lambda ()
               (dynamic-require type-module-path
                                'type-environment-bind-host-interface!)))
  (check-exn exn:fail?
             (lambda ()
               (dynamic-require type-module-path 'checker-host-interface)))
  (check-exn exn:fail?
             (lambda ()
               (dynamic-require main-module-path 'check-query-hosts))))

(test-case "Aloemacs's main.aloe answers with fs-host bound"
  (define main-text (file->string aloemacs-main-path))
  (define file-text (file->string aloemacs-file-path))
  (define fs-text (file->string fs-library-path))

  (define wrapper-index (unique-index main-text "(Fs new fs-host)"))
  (define fs-host-position (+ wrapper-index 8 1))
  (define fs-position (+ wrapper-index 1 1))
  (define buffer-index (unique-index main-text "(AloemacsBuffer new*"))
  (define buffer-position (+ buffer-index 1 1))
  (define from-string-position
    (+ (unique-index main-text "(Text from-string \"\")") 6 1))

  (check-host-hover
   (query-expression-at aloemacs-main-path fs-host-position #:hosts fs-hosts)
   'FsHost
   fs-interface
   aloemacs-main-path
   (text-numbers main-text (sub1 fs-host-position) 7))
  (check-false
   (query-definition-at aloemacs-main-path fs-host-position #:hosts fs-hosts))

  (define buffer-hover
    (query-expression-at aloemacs-main-path buffer-position #:hosts fs-hosts))
  (check-equal? (expression-query-result-type buffer-hover)
                '(Class AloemacsBuffer))
  (check-equal? (expression-query-result-pathed-type buffer-hover)
                '(Class AloemacsBuffer@examples/aloemacs/file.aloe))
  (check-jump
   (query-definition-at aloemacs-main-path buffer-position #:hosts fs-hosts)
   aloemacs-file-path
   (text-numbers file-text
                 (+ (unique-index file-text "(define-class AloemacsBuffer\n")
                    14)
                 14))

  (check-jump
   (query-definition-at aloemacs-main-path fs-position #:hosts fs-hosts)
   fs-library-path
   (text-numbers fs-text
                 (+ (unique-index fs-text "(define-class (Fs H)") 15)
                 2))

  (define from-string-items
    (query-selector-completions main-text from-string-position
                               #:source-path aloemacs-main-path
                               #:hosts fs-hosts))
  (check-equal? from-string-items
                (query-selector-completions main-text from-string-position
                                           #:source-path aloemacs-main-path))
  (check-not-false
   (member "from-string" (map selector-completion-item-label
                              from-string-items)))

  (define main-hole-text
    (string-replace main-text "(Fs new fs-host)" "(Fs new (fs-host ))"))
  (define hole-position
    (+ (unique-index main-hole-text "(Fs new (fs-host ))") 17 1))
  (check-equal? (query-selector-completions main-hole-text hole-position
                                            #:source-path aloemacs-main-path
                                            #:hosts fs-hosts)
                (interface-items fs-interface hole-position 0))

  (for ([position (list fs-host-position buffer-position fs-position)])
    (check-unbound 'fs-host
                   (lambda () (query-expression-at aloemacs-main-path
                                                   position)))
    (check-unbound 'fs-host
                   (lambda () (query-definition-at aloemacs-main-path
                                                   position))))
  (check-equal? (query-selector-completions main-hole-text hole-position
                                            #:source-path aloemacs-main-path)
                '()))

(test-case "Gel's main.aloe answers with term bound"
  (define gel-text (file->string gel-main-path))
  (define call-index (first-index gel-text "(term write-line"))
  (define term-position (+ call-index 1 1))
  (define write-line-position (+ call-index 6 1))

  (check-host-hover
   (query-expression-at gel-main-path term-position #:hosts term-hosts)
   'Term
   term-interface
   gel-main-path
   (text-numbers gel-text (sub1 term-position) 4))
  (check-false
   (query-definition-at gel-main-path term-position #:hosts term-hosts))
  (check-equal? (query-selector-completions gel-text write-line-position
                                            #:source-path gel-main-path
                                            #:hosts term-hosts)
                (interface-items term-interface write-line-position 10))

  (check-unbound 'term
                 (lambda () (query-expression-at gel-main-path term-position)))
  (check-unbound 'term
                 (lambda () (query-definition-at gel-main-path term-position)))
  (check-equal? (query-selector-completions gel-text write-line-position
                                            #:source-path gel-main-path)
                '()))

(test-case "the configured fixtures answer with fs-host bound"
  (check-host-hover (query-expression-at uses-path 58 #:hosts fs-hosts)
                    'FsHost
                    fs-interface
                    uses-path
                    '(4 14 58 7))
  (check-unbound 'fs-host (lambda () (query-expression-at uses-path 58)))

  (check-false (query-definition-at uses-path 58 #:hosts fs-hosts))
  (check-unbound 'fs-host (lambda () (query-definition-at uses-path 58)))

  (check-jump (query-definition-at uses-path 92 #:hosts fs-hosts)
              spot-path
              '(1 14 15 4))
  (check-unbound 'fs-host (lambda () (query-definition-at uses-path 92)))

  (check-equal? (expression-query-result-type
                 (query-expression-at uses-path 138 #:hosts fs-hosts))
                'String)
  (check-unbound 'fs-host (lambda () (query-expression-at uses-path 138)))

  (check-equal? (complete-hole #:hosts fs-hosts)
                (interface-items fs-interface 66 0))
  (check-equal? (complete-hole) '())

  (define collision
    (string-append
     "typecheck: name collision: fs-host is defined by the language base and "
     "by tests/editor/host-queries/fixtures/configured/defines-fs-host.aloe"))
  (check-aloe-type-message
   collision
   (lambda () (query-expression-at defines-fs-host-path 17 #:hosts fs-hosts)))
  (check-aloe-type-message
   collision
   (lambda () (query-definition-at defines-fs-host-path 17 #:hosts fs-hosts)))
  (check-equal? (expression-query-result-type
                 (query-expression-at defines-fs-host-path 17))
                'Int)

  (check-unbound 'fs-host (lambda () (query-expression-at reads-fs-path 15))))

(test-case "a sibling copy loads from its own folder under the document's hosts"
  (define copy-path
    (make-temporary-file "host-queries-copy-~a" #f configured-folder))
  (dynamic-wind
    void
    (lambda ()
      (write-source copy-path (string-append "\n" uses-text))
      (check-host-hover (query-expression-at copy-path 59
                                             #:document-path uses-path
                                             #:hosts fs-hosts)
                        'FsHost
                        fs-interface
                        copy-path
                        '(5 14 59 7)))
    (lambda ()
      (when (file-exists? copy-path)
        (delete-file copy-path)))))

(test-case "a host bound for one query is not visible to another"
  (define answer (query-expression-at uses-path 58 #:hosts fs-hosts))
  (check-true (expression-query-result? answer))
  (check-unbound 'fs-host (lambda () (query-expression-at uses-path 58)))
  (check-equal? (query-expression-at uses-path 58 #:hosts fs-hosts) answer))

(test-case "host types are equal only when their interfaces are eq?"
  (call-with-temporary-directory
   (lambda (directory)
     (define both-path (build-path directory "both.aloe"))
     (write-source both-path "(define both (List of fs-host other-fs))\n")

     (define same-hosts
       (list (cons 'fs-host fs-interface) (cons 'other-fs fs-interface)))
     (check-equal? (expression-query-result-type
                    (query-expression-at both-path 20 #:hosts same-hosts))
                   '(List FsHost))
     (check-equal? (expression-query-result-type
                    (query-expression-at both-path 9 #:hosts same-hosts))
                   'Void)

     (define copy-hosts
       (list (cons 'fs-host fs-interface)
             (cons 'other-fs
                   (make-host-interface
                    'FsHost
                    (host-interface-methods fs-interface)))))
     (check-aloe-type-message
      "typecheck: List of elements must have one type"
      (lambda () (query-expression-at both-path 20 #:hosts copy-hosts))))))

(test-case "no host implementation runs"
  (define calls 0)
  (define counting-interface
    (make-host-interface
     'FsHost
     (for/list ([method (in-list (host-interface-methods fs-interface))])
       (define parameter-types (host-method-parameter-types method))
       (make-host-method
        (host-method-selector method)
        parameter-types
        (host-method-return-type method)
        (procedure-reduce-arity
         (lambda _arguments
           (set! calls (add1 calls))
           "x")
         (add1 (length parameter-types)))))))
  (define counting-hosts (list (cons 'fs-host counting-interface)))

  (check-equal? (expression-query-result-type
                 (query-expression-at uses-path 58 #:hosts counting-hosts))
                'FsHost)
  (check-jump (query-definition-at uses-path 92 #:hosts counting-hosts)
              spot-path
              '(1 14 15 4))
  (check-equal? (length (complete-hole #:hosts counting-hosts)) 10)
  (check-equal? calls 0))

(test-case "malformed hosts raise the query's contract errors first"
  (define malformed
    (list 'fs-host
          (list (cons "fs-host" fs-interface))
          (list (cons 'fs-host (make-fs-receiver)))
          (list (cons 'fs-host fs-interface) (cons 'fs-host fs-interface))))
  (for ([hosts (in-list malformed)])
    (check-contract-prefix
     "query-expression-at: "
     (lambda () (query-expression-at uses-path 58 #:hosts hosts)))
    (check-contract-prefix
     "query-definition-at: "
     (lambda () (query-definition-at uses-path 58 #:hosts hosts)))
    (check-contract-prefix
     "query-selector-completions: "
     (lambda () (complete-hole #:hosts hosts))))

  (check-contract-prefix
   "query-expression-at: host names must be distinct\n  host name: 'b"
   (lambda ()
     (query-expression-at uses-path 58
                          #:hosts (for/list ([name (in-list '(a b b a))])
                                    (cons name fs-interface)))))
  (define shape-expected
    "contract violation\n  expected: (listof (cons/c symbol? host-interface?))")
  (check-contract-prefix
   (string-append "query-expression-at: " shape-expected)
   (lambda ()
     (query-expression-at "definitely/missing.aloe" 1 #:hosts 'fs-host)))
  (check-contract-prefix
   (string-append "query-selector-completions: " shape-expected)
   (lambda () (query-selector-completions "" 99 #:hosts 'fs-host)))
  (check-contract-prefix
   "query-definition-at: contract violation\n  expected: path-string?"
   (lambda () (query-definition-at 3 1 #:hosts 'fs-host))))

(test-case "a host name already bound on the query base is refused"
  (for ([name (in-list '(Option List dummy))])
    (define hosts
      (list (cons 'fs-host fs-interface) (cons name fs-interface)))
    (define (refusal who)
      (format (string-append "~a: host name is already bound on the query "
                             "base\n  host name: '~a")
              who
              name))
    (check-contract-prefix
     (refusal 'query-expression-at)
     (lambda () (query-expression-at uses-path 58 #:hosts hosts)))
    (check-contract-prefix
     (refusal 'query-definition-at)
     (lambda () (query-definition-at uses-path 92 #:hosts hosts)))
    (check-equal? (complete-hole #:hosts hosts) '()))

  (call-with-temporary-directory
   (lambda (directory)
     (define broken-path (build-path directory "broken.aloe"))
     (write-source broken-path "(define-class Point\n")
     (check-exn exn:fail:read?
                (lambda ()
                  (query-expression-at
                   broken-path 1
                   #:hosts (list (cons 'Option fs-interface))))))))

(test-case "base libraries and completion without a source path ignore hosts"
  (for ([hosts (in-list (list fs-hosts
                              (list (cons 'Option fs-interface))))])
    (check-equal? (query-expression-at option-path 16 #:hosts hosts)
                  (query-expression-at option-path 16))
    (check-equal? (query-definition-at option-path 16 #:hosts hosts)
                  (query-definition-at option-path 16)))
  (check-contract-prefix
   (string-append
    "query-expression-at: contract violation\n"
    "  expected: (listof (cons/c symbol? host-interface?))")
   (lambda () (query-expression-at option-path 16 #:hosts 'fs-host)))

  (define let-source "(let ((x \"text\")) (x l))")
  (define let-items
    (query-selector-completions let-source 23 #:hosts fs-hosts))
  (check-equal? let-items (query-selector-completions let-source 23))
  (check-not-equal? let-items '())
  (check-equal? (query-selector-completions "(fs-host )" 10 #:hosts fs-hosts)
                '()))

(test-case "no hosts is today's call"
  (check-equal? (query-expression-at defines-fs-host-path 17 #:hosts '())
                (query-expression-at defines-fs-host-path 17))
  (check-equal? (query-definition-at spot-path 15 #:hosts '())
                (query-definition-at spot-path 15))
  (check-equal? (complete-hole #:hosts '())
                (query-selector-completions hole-text 66
                                            #:source-path uses-path))

  (for ([query (list query-expression-at query-definition-at)])
    (define-values (required allowed) (procedure-keywords query))
    (check-equal? required '())
    (check-equal? allowed '(#:document-path #:hosts)))
  (define-values (required allowed)
    (procedure-keywords query-selector-completions))
  (check-equal? required '())
  (check-equal? allowed '(#:hosts #:source-path)))
