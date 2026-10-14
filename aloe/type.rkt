#lang racket/base

(require racket/list
         racket/match
         (only-in racket/port port->bytes)
         "host.rkt"
         "library.rkt"
         "parse.rkt"
         "private/checker-observation.rkt"
         "signature-catalog.rkt")

(provide (struct-out exn:fail:aloe-type)
         (struct-out int-type)
         (struct-out float-type)
         (struct-out bool-type)
         (struct-out string-type)
         (struct-out symbol-type)
         (struct-out mirror-type)
         (struct-out signature-type)
         (struct-out protocol-type)
         (struct-out instance-type)
         (struct-out list-type)
         (struct-out class-type)
         (struct-out list-class-type)
         (struct-out int-class-type)
         (struct-out symbol-class-type)
         (struct-out mirror-class-type)
         (struct-out function-type)
         (struct-out signature-spec)
         type-environment?
         type-environment-bound?
         make-type-environment
         type-of
         typecheck-program
         type->datum
         type-signature-specs)

(struct exn:fail:aloe-type exn:fail () #:transparent)

(struct int-type () #:transparent)
(struct float-type () #:transparent)
(struct bool-type () #:transparent)
(struct string-type () #:transparent)
(struct symbol-type () #:transparent)
(struct mirror-type () #:transparent)
(struct signature-type () #:transparent)
(struct type-data-type () #:transparent)
;; A protocol records the environment its define-protocol is checked in; its
;; signatures resolve there.
(struct protocol-type (name signatures environment) #:transparent)
(struct instance-type (class arguments) #:transparent)
(struct list-type (element) #:transparent)
(struct class-type (class) #:transparent)
;; Each class record maps each of its method declarations, by eq?, to the
;; environment that wrote it. A base owns its records and their tables.
(struct list-class-type
  (element-parameter [methods #:mutable] method-environments)
  #:transparent)
(struct int-class-type ([methods #:mutable] method-environments)
  #:transparent)
(struct string-class-type ([methods #:mutable] method-environments)
  #:transparent)
(struct symbol-class-type () #:transparent)
(struct mirror-class-type () #:transparent)
(struct function-type (parameters result) #:transparent)
(struct host-receiver-type (interface))
(struct parameter-type (id name) #:transparent)
(struct type-variable
  (id label [binding #:mutable] [numeric? #:mutable])
  #:transparent)
(struct opaque-type (name) #:transparent)
(struct void-type () #:transparent)
(struct method-match (method substitution specificity) #:transparent)
(struct construction-obligation (parameter class type) #:transparent)

;; A class records the environment its define-class form is checked in, where
;; its field annotations resolve, beside its method table.
(struct class-info
  (name type-parameters parameter-types protocol fields constructors
        explicit-constructors?
        [methods #:mutable]
        environment
        method-environments)
  #:transparent)
;; A file environment records its file's resolved path; every other environment
;; records #f. A base, an interactive environment, and a file environment map
;; each name in their own table to its origin: the resolved path of the file
;; that defined it, prompt, or base. A local environment's origins are #f.
(struct type-environment
  (bindings parent int-class string-class option-class load-cache path origins)
  #:transparent)
;; A base's checker load cache maps a resolved path to its entry. The state is
;; running or completed. Exports are the (name . type) bindings the file's own
;; definitions made, in definition order.
(struct checker-load-entry (state source-bytes exports) #:transparent)

(define INT (int-type))
(define FLOAT (float-type))
(define BOOL (bool-type))
(define STRING (string-type))
(define SYMBOL (symbol-type))
(define MIRROR (mirror-type))
(define SIGNATURE (signature-type))
(define TYPE-DATA (type-data-type))
(define VOID (void-type))

(define current-typecheck-load-paths (make-parameter '()))
(define current-typecheck-program-depth (make-parameter 0))
;; The interactive environment a root's conformance walk visits when the root
;; is checked in a file environment; #f when the root is checked in it.
(define current-root-interactive-environment (make-parameter #f))
(define current-construction-obligations (make-parameter #f))

(define (raise-type-error format-string . arguments)
  (raise
   (exn:fail:aloe-type
    (string-append
     "typecheck: "
     (apply format format-string arguments))
    (current-continuation-marks))))

(define (fresh-type-variable [label #f])
  (type-variable (gensym 'type) label #f #f))

(define (make-type-environment)
  (define list-element-parameter
    (parameter-type (gensym 'T) 'T))
  (define string-class (string-class-type '() (make-hasheq)))
  (define int-class (int-class-type '() (make-hasheq)))
  (define bindings
    (list (cons 'dummy (opaque-type 'Dummy))
          (cons 'List
                (list-class-type list-element-parameter '() (make-hasheq)))
          (cons 'Int int-class)
          (cons 'String string-class)
          (cons 'Symbol (symbol-class-type))
          (cons 'Mirror (mirror-class-type))))
  (type-environment
   (make-hasheq bindings)
   #f
   int-class
   string-class
   (box #f)
   (make-hash)
   #f
   (make-hasheq
    (for/list ([binding (in-list bindings)])
      (cons (car binding) 'base)))))

(define (make-local-type-environment parent bindings)
  (make-child-type-environment parent bindings #f #f))

;; A loaded file is checked in its own environment, a child of the base.
(define (make-file-type-environment base path)
  (make-child-type-environment base '() path (make-hasheq)))

(define (make-child-type-environment parent bindings path origins)
  (type-environment
   (make-hasheq bindings)
   parent
   (type-environment-int-class parent)
   (type-environment-string-class parent)
   (type-environment-option-class parent)
   (type-environment-load-cache parent)
   path
   origins))

;; The base is the end of an environment's parent chain.
(define (type-environment-base environment)
  (define parent (type-environment-parent environment))
  (if parent (type-environment-base parent) environment))

;; A base's interactive environment starts with no bindings of its own.
(define (make-interactive-type-environment base)
  (make-child-type-environment base '() #f (make-hasheq)))

(define (type-environment-bound? environment name)
  (cond
    [(hash-has-key? (type-environment-bindings environment) name) #t]
    [(type-environment-parent environment)
     (type-environment-bound? (type-environment-parent environment) name)]
    [else #f]))

(define (type-environment-ref environment name)
  (define bindings (type-environment-bindings environment))
  (cond
    [(hash-has-key? bindings name)
     (hash-ref bindings name)]
    [(type-environment-parent environment)
     (type-environment-ref (type-environment-parent environment) name)]
    [else
     (raise-type-error "unbound symbol: ~a" name)]))

;; A binding records its origin where the environment keeps origins: the given
;; one for a copy, otherwise the environment's own.
(define (type-environment-set! environment name type [origin #f])
  (hash-set! (type-environment-bindings environment) name type)
  (define origins (type-environment-origins environment))
  (when origins
    (hash-set! origins name (or origin (definition-origin environment)))))

;; A definition in a file environment comes from its file, one in an
;; interactive environment from the prompt, and one in a base from the base.
(define (definition-origin environment)
  (cond
    [(type-environment-path environment)]
    [(type-environment-parent environment) 'prompt]
    [else 'base]))

;; The origin of the binding a base, interactive, or file environment sees for
;; name: its own table's, else its base's; #f when neither binds it.
(define (visible-origin environment name)
  (or (hash-ref (type-environment-origins environment) name #f)
      (hash-ref (type-environment-origins (type-environment-base environment))
                name
                #f)))

;; A file may not define a name the base binds, or a name one of its loads
;; copied in; a name the file itself defined earlier is replaced. Every other
;; environment's definitions are not checked.
(define (check-definition-name! environment name)
  (define path (type-environment-path environment))
  (define origin
    (and path
         (or (hash-ref
              (type-environment-origins (type-environment-base environment))
              name
              #f)
             (hash-ref (type-environment-origins environment) name #f))))
  (when (and origin (not (equal? origin path)))
    (raise-name-collision name origin path)))

;; The binding already visible is named first, the colliding file second.
(define (raise-name-collision name visible-origin origin)
  (define (origin->string origin)
    (case origin
      [(prompt) "the prompt"]
      [(base) "the language base"]
      [else (displayed-path origin)]))
  (raise-type-error "name collision: ~a is defined by ~a and by ~a"
                    name
                    (origin->string visible-origin)
                    (origin->string origin)))

(define (type-environment-inject-host! environment name receiver)
  (unless (type-environment? environment)
    (raise-arguments-error
     'type-environment-inject-host!
     "environment must be a type environment"
     "environment" environment))
  (unless (symbol? name)
    (raise-arguments-error
     'type-environment-inject-host!
     "name must be a symbol"
     "name" name))
  (unless (host-receiver? receiver)
    (raise-arguments-error
     'type-environment-inject-host!
     "receiver must be a validated host receiver"
     "receiver" receiver))
  (type-environment-set!
   environment
   name
   (host-receiver-type (host-receiver-interface receiver))))

(define (resolve-type type)
  (cond
    [(and (type-variable? type) (type-variable-binding type))
     (define resolved (resolve-type (type-variable-binding type)))
     (set-type-variable-binding! type resolved)
     resolved]
    [else type]))

(define (type->datum type)
  (define resolved (resolve-type type))
  (cond
    [(int-type? resolved) 'Int]
    [(float-type? resolved) 'Float]
    [(bool-type? resolved) 'Bool]
    [(string-type? resolved) 'String]
    [(symbol-type? resolved) 'Symbol]
    [(mirror-type? resolved) 'Mirror]
    [(signature-type? resolved) 'Signature]
    [(type-data-type? resolved) 'TypeData]
    [(protocol-type? resolved) (protocol-type-name resolved)]
    [(instance-type? resolved)
     (define name (class-info-name (instance-type-class resolved)))
     (if (null? (instance-type-arguments resolved))
         name
         (cons name (map type->datum (instance-type-arguments resolved))))]
    [(list-type? resolved)
     (list 'List (type->datum (list-type-element resolved)))]
    [(class-type? resolved)
     (list 'Class (class-info-name (class-type-class resolved)))]
    [(list-class-type? resolved) '(Class List)]
    [(int-class-type? resolved) '(Class Int)]
    [(string-class-type? resolved) '(Class String)]
    [(symbol-class-type? resolved) '(Class Symbol)]
    [(mirror-class-type? resolved) '(Class Mirror)]
    [(function-type? resolved)
     (cons '->
           (append
            (map type->datum (function-type-parameters resolved))
            (list (type->datum (function-type-result resolved)))))]
    [(host-receiver-type? resolved)
     (host-interface-name (host-receiver-type-interface resolved))]
    [(parameter-type? resolved) (parameter-type-name resolved)]
    [(type-variable? resolved)
     (or (type-variable-label resolved) '?)]
    [(opaque-type? resolved) (opaque-type-name resolved)]
    [(void-type? resolved) 'Void]
    [else '?]))

(define (checker-type? value)
  (let checker-type? ([candidate value])
    (cond
      [(or (int-type? candidate)
           (float-type? candidate)
           (bool-type? candidate)
           (string-type? candidate)
           (symbol-type? candidate)
           (mirror-type? candidate)
           (signature-type? candidate)
           (type-data-type? candidate)
           (symbol-class-type? candidate)
           (mirror-class-type? candidate)
           (void-type? candidate))
       #t]
      [(protocol-type? candidate)
       (and (symbol? (protocol-type-name candidate))
            (list? (protocol-type-signatures candidate))
            (andmap method-declaration?
                    (protocol-type-signatures candidate)))]
      [(instance-type? candidate)
       (and (class-info? (instance-type-class candidate))
            (list? (instance-type-arguments candidate))
            (= (length (instance-type-arguments candidate))
               (length
                (class-info-type-parameters
                 (instance-type-class candidate))))
            (andmap checker-type?
                    (instance-type-arguments candidate)))]
      [(list-type? candidate)
       (checker-type? (list-type-element candidate))]
      [(class-type? candidate)
       (class-info? (class-type-class candidate))]
      [(list-class-type? candidate)
       (and (parameter-type?
             (list-class-type-element-parameter candidate))
            (list? (list-class-type-methods candidate))
            (andmap method-declaration?
                    (list-class-type-methods candidate)))]
      [(int-class-type? candidate)
       (and (list? (int-class-type-methods candidate))
            (andmap method-declaration?
                    (int-class-type-methods candidate)))]
      [(string-class-type? candidate)
       (and (list? (string-class-type-methods candidate))
            (andmap method-declaration?
                    (string-class-type-methods candidate)))]
      [(function-type? candidate)
       (and (list? (function-type-parameters candidate))
            (andmap checker-type?
                    (function-type-parameters candidate))
            (checker-type? (function-type-result candidate)))]
      [(host-receiver-type? candidate)
       (host-interface? (host-receiver-type-interface candidate))]
      [(parameter-type? candidate)
       (and (symbol? (parameter-type-id candidate))
            (symbol? (parameter-type-name candidate)))]
      [(type-variable? candidate)
       (and (symbol? (type-variable-id candidate))
            (or (not (type-variable-label candidate))
                (symbol? (type-variable-label candidate)))
            (boolean? (type-variable-numeric? candidate))
            (or (not (type-variable-binding candidate))
                (checker-type?
                 (type-variable-binding candidate))))]
      [(opaque-type? candidate)
       (symbol? (opaque-type-name candidate))]
      [else #f])))

(define (fresh-signature-spec-list specs)
  (for/list ([spec (in-list specs)]) spec))

(define (type-signature-specs type environment)
  (unless (checker-type? type)
    (raise-argument-error 'type-signature-specs "checker type" type))
  (unless (type-environment? environment)
    (raise-argument-error
     'type-signature-specs "type-environment?" environment))
  (define resolved (resolve-type type))
  (cond
    [(int-type? resolved)
     (append
      (kernel-instance-signature-specs 'Int)
      (method-declarations->signature-specs
       (int-class-type-methods
        (type-environment-int-class environment))))]
    [(float-type? resolved)
     (fresh-signature-spec-list
      (kernel-instance-signature-specs 'Float))]
    [(bool-type? resolved)
     (fresh-signature-spec-list
      (kernel-instance-signature-specs 'Bool))]
    [(string-type? resolved)
     (append
      (kernel-instance-signature-specs 'String)
      (method-declarations->signature-specs
       (string-class-type-methods
        (type-environment-string-class environment))))]
    [(symbol-type? resolved)
     (fresh-signature-spec-list
      (kernel-instance-signature-specs 'Symbol))]
    [(mirror-type? resolved)
     (fresh-signature-spec-list
      (kernel-instance-signature-specs 'Mirror))]
    [(signature-type? resolved)
     (fresh-signature-spec-list
      (kernel-instance-signature-specs 'Signature))]
    [(list-type? resolved)
     (define element-datum
       (type->datum (list-type-element resolved)))
     (define substitution (hasheq 'T element-datum))
     (define list-class (type-environment-ref environment 'List))
     (append
      (substitute-signature-specs
       (kernel-instance-signature-specs 'List)
       substitution)
      (if (list-class-type? list-class)
          (method-declarations->signature-specs
           (list-class-type-methods list-class)
           substitution)
          '()))]
    [(function-type? resolved)
     (list
      (make-call-signature-spec
       (map type->datum (function-type-parameters resolved))
       (type->datum (function-type-result resolved))))]
    [(list-class-type? resolved)
     (fresh-signature-spec-list
      (kernel-class-object-signature-specs 'List))]
    [(int-class-type? resolved) '()]
    [(string-class-type? resolved) '()]
    [(symbol-class-type? resolved)
     (fresh-signature-spec-list
      (kernel-class-object-signature-specs 'Symbol))]
    [(mirror-class-type? resolved)
     (fresh-signature-spec-list
      (kernel-class-object-signature-specs 'Mirror))]
    [(parameter-type? resolved)
     (substitute-signature-specs
      (kernel-instance-signature-specs 'Float)
      (hasheq 'Float (parameter-type-name resolved)))]
    [(or (type-variable? resolved)
         (void-type? resolved)
         (type-data-type? resolved)
         (opaque-type? resolved))
     '()]
    [(instance-type? resolved)
     (define class (instance-type-class resolved))
     (define substitution
       (make-hasheq
        (map cons
             (class-info-type-parameters class)
             (map type->datum (instance-type-arguments resolved)))))
     (append
      (field-declarations->signature-specs
       (class-info-fields class)
       substitution)
      (method-declarations->signature-specs
       (class-info-methods class)
       substitution))]
    [(class-type? resolved)
     (define class (class-type-class resolved))
     (constructor-declarations->signature-specs
      (class-info-constructors class)
      (type->datum
       (instance-type class (class-info-parameter-types class))))]
    [(protocol-type? resolved)
     (method-declarations->signature-specs
      (protocol-type-signatures resolved))]
    [(host-receiver-type? resolved)
     (host-method-declarations->signature-specs
      (host-interface-methods
       (host-receiver-type-interface resolved)))]))

(define (type-mismatch message left right)
  (if message
      (raise-type-error "~a" message)
      (raise-type-error "type mismatch: expected ~a, got ~a"
                        (type->datum right)
                        (type->datum left))))

(define (occurs-in? variable type)
  (define resolved (resolve-type type))
  (cond
    [(eq? variable resolved) #t]
    [(instance-type? resolved)
     (ormap (lambda (argument) (occurs-in? variable argument))
            (instance-type-arguments resolved))]
    [(list-type? resolved)
     (occurs-in? variable (list-type-element resolved))]
    [(function-type? resolved)
     (or (ormap (lambda (parameter) (occurs-in? variable parameter))
                (function-type-parameters resolved))
         (occurs-in? variable (function-type-result resolved)))]
    [else #f]))

(define (ensure-numeric-type! type [message #f])
  (define resolved (resolve-type type))
  (cond
    [(or (int-type? resolved)
         (float-type? resolved)
         (parameter-type? resolved))
     (void)]
    [(type-variable? resolved)
     (set-type-variable-numeric?! resolved #t)]
    [else
     (type-mismatch
      (or message "numeric message requires Int or Float")
      resolved
      INT)]))

(define (bind-type-variable! variable type message)
  (define resolved (resolve-type type))
  (cond
    [(eq? variable resolved) variable]
    [(occurs-in? variable resolved)
     (type-mismatch message resolved variable)]
    [else
     (when (type-variable-numeric? variable)
       (ensure-numeric-type! resolved message))
     (when (and (type-variable? resolved)
                (type-variable-numeric? variable))
       (set-type-variable-numeric?! resolved #t))
     (set-type-variable-binding! variable resolved)
     resolved]))

(define (unify-types! left right [message #f])
  (define resolved-left (resolve-type left))
  (define resolved-right (resolve-type right))
  (cond
    [(eq? resolved-left resolved-right) resolved-left]
    [(type-variable? resolved-left)
     (bind-type-variable! resolved-left resolved-right message)]
    [(type-variable? resolved-right)
     (bind-type-variable! resolved-right resolved-left message)]
    [(and (int-type? resolved-left) (int-type? resolved-right)) INT]
    [(and (float-type? resolved-left) (float-type? resolved-right)) FLOAT]
    [(and (bool-type? resolved-left) (bool-type? resolved-right)) BOOL]
    [(and (string-type? resolved-left) (string-type? resolved-right)) STRING]
    [(and (symbol-type? resolved-left) (symbol-type? resolved-right)) SYMBOL]
    [(and (mirror-type? resolved-left) (mirror-type? resolved-right)) MIRROR]
    [(and (signature-type? resolved-left)
          (signature-type? resolved-right))
     SIGNATURE]
    [(and (type-data-type? resolved-left)
          (type-data-type? resolved-right))
     TYPE-DATA]
    [(and (protocol-type? resolved-left)
          (protocol-type? resolved-right)
          (eq? resolved-left resolved-right))
     resolved-left]
    [(and (instance-type? resolved-left)
          (protocol-type? resolved-right)
          (eq? (class-info-protocol
                (instance-type-class resolved-left))
               resolved-right))
     resolved-right]
    [(and (parameter-type? resolved-left)
          (parameter-type? resolved-right)
          (eq? (parameter-type-id resolved-left)
               (parameter-type-id resolved-right)))
     resolved-left]
    [(and (instance-type? resolved-left) (instance-type? resolved-right)
          (eq? (instance-type-class resolved-left)
               (instance-type-class resolved-right))
          (= (length (instance-type-arguments resolved-left))
             (length (instance-type-arguments resolved-right))))
     (for ([left-argument (in-list (instance-type-arguments resolved-left))]
           [right-argument (in-list (instance-type-arguments resolved-right))])
       (unify-types! left-argument right-argument message))
     resolved-left]
    [(and (list-type? resolved-left) (list-type? resolved-right))
     (unify-types! (list-type-element resolved-left)
                   (list-type-element resolved-right)
                   message)
     resolved-left]
    [(and (class-type? resolved-left) (class-type? resolved-right)
          (eq? (class-type-class resolved-left)
               (class-type-class resolved-right)))
     resolved-left]
    [(and (list-class-type? resolved-left)
          (list-class-type? resolved-right))
     resolved-left]
    [(and (int-class-type? resolved-left)
          (int-class-type? resolved-right))
     resolved-left]
    [(and (string-class-type? resolved-left)
          (string-class-type? resolved-right))
     resolved-left]
    [(and (symbol-class-type? resolved-left)
          (symbol-class-type? resolved-right))
     resolved-left]
    [(and (mirror-class-type? resolved-left)
          (mirror-class-type? resolved-right))
     resolved-left]
    [(and (function-type? resolved-left) (function-type? resolved-right)
          (= (length (function-type-parameters resolved-left))
             (length (function-type-parameters resolved-right))))
     (for ([left-parameter
            (in-list (function-type-parameters resolved-left))]
           [right-parameter
            (in-list (function-type-parameters resolved-right))])
       (unify-types! left-parameter right-parameter message))
     (unify-types! (function-type-result resolved-left)
                   (function-type-result resolved-right)
                   message)
     resolved-left]
    [(and (host-receiver-type? resolved-left)
          (host-receiver-type? resolved-right)
          (eq? (host-receiver-type-interface resolved-left)
               (host-receiver-type-interface resolved-right)))
     resolved-left]
    [(and (opaque-type? resolved-left) (opaque-type? resolved-right)
          (eq? (opaque-type-name resolved-left)
               (opaque-type-name resolved-right)))
     resolved-left]
    [(and (void-type? resolved-left) (void-type? resolved-right)) VOID]
    [else
     (type-mismatch message resolved-left resolved-right)]))

(define (type-of expression [environment (make-type-environment)])
  (define obligations (box '()))
  (define inferred
    (parameterize ([current-construction-obligations obligations])
      (infer-expression expression environment #f)))
  (for ([obligation (in-list (unbox obligations))])
    (when (type-variable?
           (resolve-type (construction-obligation-type obligation)))
      (raise-type-error
       "cannot infer type parameter ~a for ~a"
       (construction-obligation-parameter obligation)
       (class-info-name (construction-obligation-class obligation)))))
  (resolve-type inferred))

(define (typecheck-program expressions
                           [environment (make-type-environment)])
  (define outermost? (zero? (current-typecheck-program-depth)))
  (define result
    (parameterize
        ([current-typecheck-program-depth
          (add1 (current-typecheck-program-depth))])
      (for/fold ([result VOID])
                ([expression (in-list expressions)])
        (define root-type (type-of expression environment))
        (materialize-expression-observation-at-root-end!)
        root-type)))
  (when outermost?
    (check-protocol-conformance!
     environment
     (or (current-root-interactive-environment) environment)))
  result)

;; The loader is the environment the load form is checked in.
(define (typecheck-load! expression environment)
  (define path (load-expr-resolved-path expression))
  (unless (file-exists? path)
    (raise-type-error "load file not found: ~a" path))
  (typecheck-once!
   environment
   path
   (lambda () (call-with-input-file path port->bytes))
   (lambda (source-bytes)
     (define expressions
       (read-program (open-input-bytes source-bytes) #:source-path path))
     (parameterize
         ([current-typecheck-load-paths
           (cons path (current-typecheck-load-paths))])
       (check-file-module environment path expressions))))
  VOID)

;; A program given with a source path is checked once per base, under the
;; same rule as a nested load; the caller's environment is its loader. A hit
;; returns Void and no expressions.
(define (typecheck-keyed-root environment source-path source-bytes)
  (define path (resolved-source-path source-path))
  (define expressions #f)
  (define result
    (typecheck-once!
     environment
     path
     (lambda () source-bytes)
     (lambda (source-bytes)
       (set! expressions
             (read-program (open-input-bytes source-bytes)
                           #:source-path source-path))
       (check-file-module environment path expressions))))
  (values result expressions))

;; A file's forms are checked in a new file environment under the loader's
;; base. When the file is a root, the loader is the interactive environment its
;; conformance walk visits.
(define (check-file-module loader path expressions)
  (define file-environment
    (make-file-type-environment (type-environment-base loader) path))
  (define result
    (parameterize ([current-root-interactive-environment loader])
      (typecheck-program expressions file-environment)))
  (values result (file-exports expressions file-environment)))

;; The bindings a file's own define, define-class, and define-protocol forms
;; left in its environment, in definition order, each name once.
(define (file-exports expressions file-environment)
  (define bindings (type-environment-bindings file-environment))
  (for/fold ([exports '()]
             #:result (reverse exports))
            ([expression (in-list expressions)])
    (define name
      (match expression
        [(define-expr name _ _) name]
        [(define-class-expr name _ _ _ _ _ _) name]
        [(define-protocol-expr name _ _) name]
        [_ #f]))
    (if (and name (not (assq name exports)))
        (cons (cons name (hash-ref bindings name)) exports)
        exports)))

;; Every export is a definition made by the file at path. A loader that keeps
;; origins compares each export with its visible binding before any is bound:
;; the same origin is already there, and a different one is a collision, so
;; nothing from a colliding copy lands. A local environment takes every export.
(define (copy-exports! loader path exports)
  (define copied
    (for/fold ([copied '()]
               #:result (reverse copied))
              ([export (in-list exports)])
      (define origin
        (and (type-environment-origins loader)
             (visible-origin loader (car export))))
      (cond
        [(not origin) (cons export copied)]
        [(equal? origin path) copied]
        [else (raise-name-collision (car export) origin path)])))
  (for ([export (in-list copied)])
    (type-environment-set! loader (car export) (cdr export) path)))

;; One rule for a load and a keyed root: a resolved path is checked once per
;; base; the same bytes again are a hit, and different bytes are an error that
;; parses nothing. A check that does not complete leaves no entry and copies
;; nothing. Otherwise the file's exports are copied into the loader, on a miss
;; and on every hit; a copy that collides leaves the entry completed.
(define (typecheck-once! loader path read-source-bytes check-source)
  (define cache (type-environment-load-cache loader))
  (define entry (hash-ref cache path #f))
  (when (or (and entry (eq? (checker-load-entry-state entry) 'running))
            (member path (current-typecheck-load-paths) equal?))
    (raise-type-error "load cycle: ~a" path))
  (define source-bytes (read-source-bytes))
  (cond
    [(not entry)
     (hash-set! cache path (checker-load-entry 'running source-bytes '()))
     (define completed? #f)
     (dynamic-wind
      void
      (lambda ()
        (define-values (result exports) (check-source source-bytes))
        (hash-set! cache
                   path
                   (checker-load-entry 'completed source-bytes exports))
        (set! completed? #t)
        (copy-exports! loader path exports)
        result)
      (lambda ()
        (unless completed?
          (hash-remove! cache path))))]
    [(equal? (checker-load-entry-source-bytes entry) source-bytes)
     (copy-exports! loader path (checker-load-entry-exports entry))
     VOID]
    [else
     (raise-type-error
      "load file changed: ~a; this version does not reload a changed file"
      (displayed-path path))]))

;; An editor query of a base library checks the buffer it already read as a
;; keyed root under the document's path, so its base installs that library from
;; the buffer, once.
(define (typecheck-keyed-buffer environment document-path source-bytes
                                check-buffer)
  (typecheck-once! environment
                   (resolved-source-path document-path)
                   (lambda () source-bytes)
                   (lambda (_source-bytes) (values (check-buffer) '()))))

;; Any other queried buffer is a file module keyed by the document's path: a
;; file environment under the query's base, with the query's interactive
;; environment for conformance. The query's base is discarded afterwards, so
;; the buffer copies nothing into it.
(define (typecheck-file-buffer environment document-path source-bytes
                               check-buffer)
  (define path (resolved-source-path document-path))
  (typecheck-once!
   environment
   path
   (lambda () source-bytes)
   (lambda (_source-bytes)
     (define file-environment
       (make-file-type-environment (type-environment-base environment) path))
     (values
      (parameterize ([current-root-interactive-environment environment])
        (check-buffer file-environment))
      '()))))

;; A base records the libraries it installed as completed loads. A query's base
;; skips the library it installs from the buffer. The Option seed exports the
;; class the base binds under Option right after the install.
(define (record-checked-libraries! environment #:except [skipped-path #f])
  (define cache (type-environment-load-cache environment))
  (for ([path (in-list (list list-library-resolved-path
                             string-library-resolved-path
                             int-library-resolved-path
                             option-library-resolved-path))]
        [source-bytes (in-list (list (list-library-bytes)
                                     (string-library-bytes)
                                     (int-library-bytes)
                                     (option-library-bytes)))]
        [exported-names (in-list '(() () () (Option)))]
        #:unless (equal? path skipped-path))
    (define exports
      (for/list ([name (in-list exported-names)])
        (cons name (type-environment-ref environment name))))
    (hash-set! cache
               path
               (checker-load-entry 'completed source-bytes exports))))

;; A base keeps the Option class record it installed; find reads it, not the
;; name. Its origin is lib/option.aloe. A queried buffer that binds no Option
;; class leaves the field empty.
(define (record-checked-option-class! environment)
  (define option-type
    (and (type-environment-bound? environment 'Option)
         (type-environment-ref environment 'Option)))
  (when (class-type? option-type)
    (set-box! (type-environment-option-class environment)
              (class-type-class option-type))
    (hash-set! (type-environment-origins environment)
               'Option
               option-library-resolved-path)))

(define (infer-expression expression environment expected
                          [mismatch-context #f])
  (define inferred
    (match expression
      [(int-expr _ _) INT]
      [(float-expr _ _) FLOAT]
      [(bool-expr _ _) BOOL]
      [(string-expr _ _) STRING]
      [(variable-expr name _)
       (type-environment-ref environment name)]
      [(? load-expr?)
       (typecheck-load! expression environment)]
      [(check-expr left right _ _ _)
       (define left-type
         (infer-expression left environment expected))
       (define right-type
         (infer-expression right environment left-type))
       (unify-types!
        left-type
        right-type
        "check operands must have the same type")
       right-type]
      [(define-expr name value-expression _)
       (check-definition-name! environment name)
       (define value-type
         (infer-expression value-expression environment #f))
       (type-environment-set! environment name value-type)
       VOID]
      [(define-protocol-expr name signatures _)
       (check-definition-name! environment name)
       (define protocol (protocol-type name signatures environment))
       (type-environment-set! environment name protocol)
       (for ([signature (in-list signatures)])
         (check-method-types! signature environment (make-hasheq)))
       VOID]
      [(define-class-expr
        name type-parameters protocol fields constructors methods _)
       (check-definition-name! environment name)
       (check-class-definition!
        name
        type-parameters
        protocol
        fields
        constructors
        methods
        environment)
       VOID]
      [(define-methods-expr target methods _)
       (check-method-definitions! target methods environment)
       VOID]
      [(fn-expr parameters body _)
       (infer-function parameters body environment expected)]
      [(case-expr scrutinee clauses else-body _)
       (infer-case scrutinee clauses else-body environment expected)]
      [(new-star-expr receiver bindings _)
       (infer-new-star receiver bindings environment expected)]
      [(with-expr receiver bindings _)
       (infer-with receiver bindings environment)]
      [(send-expr receiver selector arguments _ _)
       (infer-send receiver selector arguments environment expected)]))
  (when expected
    ;; A context names what the expected type belongs to, such as a with
    ;; field, in the mismatch report.
    (unify-types!
     inferred
     expected
     (and mismatch-context
          (format "type mismatch for ~a: expected ~a, got ~a"
                  mismatch-context
                  (type->datum expected)
                  (type->datum inferred)))))
  (retain-expression-observation! expression inferred environment)
  (observe-selector-receiver! expression inferred environment)
  inferred)

(define (infer-function parameters body environment expected)
  (define resolved-expected (and expected (resolve-type expected)))
  (define expected-function
    (and (function-type? resolved-expected) resolved-expected))
  (when (and expected-function
             (not (= (length parameters)
                     (length
                      (function-type-parameters expected-function)))))
    (raise-type-error
     "arity error for function: expected ~a parameter(s), got ~a"
     (length (function-type-parameters expected-function))
     (length parameters)))
  (define parameter-types
    (if expected-function
        (function-type-parameters expected-function)
        (for/list ([parameter (in-list parameters)])
          (fresh-type-variable parameter))))
  (define local-environment
    (make-local-type-environment
     environment
     (map cons parameters parameter-types)))
  (define result-expected
    (and expected-function (function-type-result expected-function)))
  (define result-type
    (infer-expression body local-environment result-expected))
  (function-type parameter-types result-type))

(define (infer-case scrutinee-expression clauses else-body environment expected)
  (define scrutinee-type
    (resolve-type
     (infer-expression scrutinee-expression environment #f)))
  (unless (instance-type? scrutinee-type)
    (raise-type-error
     "case scrutinee must be a concrete class instance, got ~a"
     (type->datum scrutinee-type)))
  (define class (instance-type-class scrutinee-type))
  (define constructors (class-info-constructors class))
  (define constructor-selectors
    (map constructor-declaration-selector constructors))
  (define clause-selectors (map case-clause-selector clauses))
  (define duplicate-clause (check-duplicates clause-selectors))
  (when duplicate-clause
    (raise-type-error
     "duplicate case constructor ~a"
     duplicate-clause))
  (for ([selector (in-list clause-selectors)])
    (unless (memq selector constructor-selectors)
      (raise-type-error
       "unknown constructor ~a for class ~a"
       selector
       (class-info-name class))))
  (define missing-constructors
    (filter (lambda (selector)
              (not (memq selector clause-selectors)))
            constructor-selectors))
  (cond
    [else-body
     (when (null? clauses)
       (raise-type-error
        "case with else must name at least one constructor"))
     (when (null? missing-constructors)
       (raise-type-error
        "case with else must leave at least one constructor unmatched"))]
    [(pair? missing-constructors)
     (raise-type-error
      "non-exhaustive case; missing constructors: ~a"
      missing-constructors)])
  (define substitution (instance-substitution scrutinee-type))
  (for ([clause (in-list clauses)])
    (define constructor
      (class-constructor class (case-clause-selector clause)))
    (define fields (constructor-declaration-fields constructor))
    (define payload-names (case-clause-payload-names clause))
    (unless (= (length fields) (length payload-names))
      (raise-type-error
       "arity error for case constructor ~a: expected ~a payload name(s), got ~a"
       (constructor-declaration-selector constructor)
       (length fields)
       (length payload-names))))
  (define result-type (or expected (fresh-type-variable 'case-result)))
  (for ([clause (in-list clauses)])
    (define constructor
      (class-constructor class (case-clause-selector clause)))
    (define payload-types
      (for/list
          ([field (in-list (constructor-declaration-fields constructor))])
        (type-from-sexpr
         (field-declaration-type field)
         (class-info-environment class)
         substitution)))
    (define clause-environment
      (make-local-type-environment
       environment
       (map cons (case-clause-payload-names clause) payload-types)))
    (define body-type
      (infer-expression
       (case-clause-body clause) clause-environment result-type))
    (unify-types! body-type result-type "case branch type mismatch"))
  (when else-body
    (define else-type
      (infer-expression else-body environment result-type))
    (unify-types! else-type result-type "case branch type mismatch"))
  result-type)

;; Library declarations are parsed once and shared by every base, so a method's
;; environment is recorded in its base's class record, never process-wide.
(define (record-method-environments! method-environments methods environment)
  (for ([method (in-list methods)])
    (hash-set! method-environments method environment)))

;; A method without a record is an internal error. It is not a type error,
;; which overload matching would read as a candidate that does not apply.
(define (recorded-method-environment method-environments method)
  (hash-ref method-environments
            method
            (lambda ()
              (error 'typecheck
                     "internal error: no recorded environment for method ~a"
                     (method-declaration-selector method)))))

;; Overload selection asks each candidate for its environment through this.
(define (recorded-method-environments method-environments)
  (lambda (method)
    (recorded-method-environment method-environments method)))

(define (class-method-environment class method)
  (recorded-method-environment (class-info-method-environments class) method))

(define (check-class-definition!
         name
         type-parameters
         protocol-name
         fields
         constructors
         methods
         environment)
  (define protocol
    (and protocol-name
         (let ([candidate
                (type-environment-ref environment protocol-name)])
           (unless (protocol-type? candidate)
             (raise-type-error "~a is not a protocol" protocol-name))
           candidate)))
  (define parameter-types
    (for/list ([parameter (in-list type-parameters)])
      (parameter-type (gensym parameter) parameter)))
  (define normalized-fields (or fields '()))
  (define normalized-constructors
    (if fields
        (list (constructor-declaration 'new fields))
        constructors))
  (unless (pair? normalized-constructors)
    (raise-type-error "class ~a must have at least one constructor" name))
  (define duplicate-constructor
    (check-duplicates
     (map constructor-declaration-selector normalized-constructors)))
  (when duplicate-constructor
    (raise-type-error
     "duplicate constructor selector ~a in class ~a"
     duplicate-constructor
     name))
  (define class
    (class-info
     name
     type-parameters
     parameter-types
     protocol
     normalized-fields
     normalized-constructors
     (and constructors #t)
     methods
     environment
     (make-hasheq)))
  (record-method-environments!
   (class-info-method-environments class) methods environment)
  (type-environment-set! environment name (class-type class))
  (check-constructor-method-collisions! class methods)
  (define substitution
    (make-hasheq (map cons type-parameters parameter-types)))
  (for* ([constructor (in-list normalized-constructors)]
         [field (in-list (constructor-declaration-fields constructor))])
    (type-from-sexpr
     (field-declaration-type field) environment substitution))
  (for ([method (in-list methods)])
    (check-method-definition!
     class
     method
     environment
     substitution
     (or (class-info-explicit-constructors? class)
         (null? type-parameters)))))

(define (class-constructor class selector)
  (for/first ([constructor (in-list (class-info-constructors class))]
              #:when
              (eq? selector (constructor-declaration-selector constructor)))
    constructor))

(define (check-constructor-method-collisions! class methods)
  (for ([method (in-list methods)])
    (define selector (method-declaration-selector method))
    (when (class-constructor class selector)
      (raise-type-error
       "constructor selector ~a cannot also be an instance method on ~a"
       selector
       (class-info-name class)))))

(define (check-method-definition!
         class method environment substitution check-body?)
  (define method-substitution
    (extend-method-substitution substitution method #t))
  (check-method-types! method environment method-substitution)
  (when (or check-body?
            (selected-expression-in-method-body? method))
    (check-method-body!
     (instance-type class (class-info-parameter-types class))
     method
     environment
     method-substitution)))

(define (check-method-types! method environment substitution)
  (for ([parameter (in-list (method-declaration-parameters method))])
    (type-from-sexpr
     (parameter-declaration-type parameter)
     environment
     substitution))
  (type-from-sexpr
   (method-declaration-return-type method)
   environment
   substitution))

(define (extend-method-substitution substitution method rigid?)
  (define extended (hash-copy substitution))
  (for ([name (in-list (method-declaration-type-parameters method))])
    (when (hash-has-key? extended name)
      (raise-type-error "method type parameter already in scope: ~a" name))
    (hash-set!
     extended
     name
     (if rigid?
         (parameter-type (gensym name) name)
         (fresh-type-variable name))))
  extended)

(define (check-method-definitions! target methods environment)
  (define target-type (type-environment-ref environment target))
  (cond
    [(and (eq? target 'List) (list-class-type? target-type))
     (define existing-methods (list-class-type-methods target-type))
     ;; Install the complete set before checking bodies so methods may recurse
     ;; and may call other methods from the same define-methods form.
     (set-list-class-type-methods!
      target-type
      (append existing-methods methods))
     (record-method-environments!
      (list-class-type-method-environments target-type) methods environment)
     (define list-substitution
       (make-hasheq
        (list
         (cons 'T (list-class-type-element-parameter target-type)))))
     (for ([method (in-list methods)])
       (define method-substitution
         (extend-method-substitution list-substitution method #t))
       (check-method-types! method environment method-substitution)
       (check-method-body!
        (list-type (list-class-type-element-parameter target-type))
        method
        environment
        method-substitution))]
    [(and (eq? target 'String) (string-class-type? target-type))
     (define existing-methods (string-class-type-methods target-type))
     ;; Match List: install every declaration before checking bodies so
     ;; methods in one extension form may recurse and call one another.
     (set-string-class-type-methods!
      target-type
      (append existing-methods methods))
     (record-method-environments!
      (string-class-type-method-environments target-type) methods environment)
     (for ([method (in-list methods)])
       (define method-substitution
         (extend-method-substitution (make-hasheq) method #t))
       (check-method-types! method environment method-substitution)
       (check-method-body!
        STRING method environment method-substitution))]
    [(and (eq? target 'Int) (int-class-type? target-type))
     (set-int-class-type-methods!
      target-type
      (append (int-class-type-methods target-type) methods))
     (record-method-environments!
      (int-class-type-method-environments target-type) methods environment)
     (for ([method (in-list methods)])
       (define method-substitution
         (extend-method-substitution (make-hasheq) method #t))
       (check-method-types! method environment method-substitution)
       (check-method-body!
        INT method environment method-substitution))]
    [(class-type? target-type)
     (define class (class-type-class target-type))
     (define existing-methods (class-info-methods class))
     (check-constructor-method-collisions! class methods)
     (set-class-info-methods! class (append existing-methods methods))
     (record-method-environments!
      (class-info-method-environments class) methods environment)
     (define substitution
       (make-hasheq
        (map cons
             (class-info-type-parameters class)
             (class-info-parameter-types class))))
     (for ([method (in-list methods)])
       (check-method-definition!
        class
        method
        environment
        substitution
        (or (class-info-explicit-constructors? class)
            (null? (class-info-type-parameters class)))))]
    [else
     (raise-type-error
      "define-methods target is not a class: ~a"
      target)]))

;; A root's conformance walk visits each class a completed cache entry exports,
;; then each class bound in the file environment and its parents, then in the
;; interactive environment and its parents. Each class record is visited once.
(define (conformance-walk-classes file-environment interactive-environment)
  (define seen-classes (make-hasheq))
  (define classes '())
  (define (visit! type)
    (when (class-type? type)
      (define class (class-type-class type))
      (unless (hash-ref seen-classes class #f)
        (hash-set! seen-classes class #t)
        (set! classes (cons class classes)))))
  (for ([entry (in-hash-values
                (type-environment-load-cache file-environment))]
        #:when (eq? (checker-load-entry-state entry) 'completed))
    (for ([export (in-list (checker-load-entry-exports entry))])
      (visit! (cdr export))))
  (for ([environment (in-list (list file-environment
                                    interactive-environment))])
    (let loop ([current environment])
      (when current
        (for ([binding (in-hash-values
                        (type-environment-bindings current))])
          (visit! binding))
        (loop (type-environment-parent current)))))
  (reverse classes))

(define (check-protocol-conformance! file-environment interactive-environment)
  (for ([class (in-list (conformance-walk-classes file-environment
                                                  interactive-environment))])
    (define protocol (class-info-protocol class))
    (when protocol
      (for ([signature (in-list (protocol-type-signatures protocol))])
        (unless
            (for/or ([method (in-list (class-info-methods class))])
              (method-signature-conforms?
               class method protocol signature))
          (raise-type-error
           "class ~a does not implement protocol ~a method ~a"
           (class-info-name class)
           (protocol-type-name protocol)
           (method-declaration-selector signature)))))))

;; The protocol's annotations resolve in the protocol's environment, the
;; method's in the method's.
(define (method-signature-conforms?
         class method protocol signature)
  (define protocol-environment (protocol-type-environment protocol))
  (define method-environment (class-method-environment class method))
  (and
   (eq? (method-declaration-selector method)
        (method-declaration-selector signature))
   (= (length (method-declaration-parameters method))
      (length (method-declaration-parameters signature)))
   (with-handlers ([exn:fail:aloe-type? (lambda (_) #f)])
     (define class-substitution
       (make-hasheq
        (map cons
             (class-info-type-parameters class)
             (class-info-parameter-types class))))
     (define method-substitution
       (extend-method-substitution class-substitution method #t))
     ;; An implementation must accept the full protocol parameter type.
     (for ([implementation-parameter
            (in-list (method-declaration-parameters method))]
           [required-parameter
            (in-list (method-declaration-parameters signature))])
       (unify-types!
        (type-from-sexpr
         (parameter-declaration-type required-parameter)
         protocol-environment
         (make-hasheq))
        (type-from-sexpr
         (parameter-declaration-type implementation-parameter)
         method-environment
         method-substitution)))
     ;; Concrete class results may satisfy a protocol result covariantly.
     (unify-types!
      (type-from-sexpr
       (method-declaration-return-type method)
       method-environment
       method-substitution)
      (type-from-sexpr
       (method-declaration-return-type signature)
       protocol-environment
       (make-hasheq)))
     #t)))

(define (check-method-body! self-type method environment substitution)
  (define parameter-types
    (for/list ([parameter
                (in-list (method-declaration-parameters method))])
      (type-from-sexpr
       (parameter-declaration-type parameter)
       environment
       substitution)))
  (define return-type
    (type-from-sexpr
     (method-declaration-return-type method)
     environment
     substitution))
  (define bindings
    (cons
     (cons 'self self-type)
     (for/list ([parameter
                 (in-list (method-declaration-parameters method))]
                [parameter-type (in-list parameter-types)])
       (cons (parameter-declaration-name parameter) parameter-type))))
  (define local-environment
    (make-local-type-environment environment bindings))
  (define body-type
    (infer-expression
     (method-declaration-body method) local-environment return-type))
  (unify-types!
   body-type
   return-type
   (format "method ~a return type mismatch"
           (method-declaration-selector method))))

(define (type-from-sexpr datum environment substitution)
  (cond
    [(symbol? datum)
     (cond
       [(eq? datum 'Int) INT]
       [(eq? datum 'Float) FLOAT]
       [(eq? datum 'Bool) BOOL]
       [(eq? datum 'String) STRING]
       [(eq? datum 'Symbol) SYMBOL]
       [(eq? datum 'Mirror) MIRROR]
       [(eq? datum 'Signature) SIGNATURE]
       [(hash-has-key? substitution datum)
        (hash-ref substitution datum)]
       [else
        (define named-type (type-environment-ref environment datum))
        (cond
          [(class-type? named-type)
           (define class (class-type-class named-type))
           (unless (null? (class-info-type-parameters class))
             (raise-type-error "generic type ~a needs arguments" datum))
           (instance-type class '())]
          [(list-class-type? named-type)
           (raise-type-error "List type needs an element type")]
          [(protocol-type? named-type) named-type]
          [else
           (raise-type-error "~a is not a type" datum)])])]
    [(and (list? datum) (pair? datum) (symbol? (car datum)))
     (define name (car datum))
     (define arguments (cdr datum))
     (cond
       [(eq? name '->)
        (unless (pair? arguments)
          (raise-type-error
           "function type needs at least a result type"))
        (define parts
          (for/list ([argument (in-list arguments)])
            (type-from-sexpr argument environment substitution)))
        (function-type (drop-right parts 1) (last parts))]
       [(eq? name 'List)
        (unless (= (length arguments) 1)
          (raise-type-error "List type needs one argument"))
        (list-type
         (type-from-sexpr (car arguments) environment substitution))]
       [else
        (define named-type (type-environment-ref environment name))
        (unless (class-type? named-type)
          (raise-type-error "~a is not a class type" name))
        (define class (class-type-class named-type))
        (define expected-count
          (length (class-info-type-parameters class)))
        (if (zero? expected-count)
            ;; Checkpoints 3–4 used (Point Int) annotations on a
            ;; non-generic Point. Preserve that accepted surface form.
            (instance-type class '())
            (begin
              (unless (= expected-count (length arguments))
                (raise-type-error
                 "type ~a expects ~a argument(s), got ~a"
                 name expected-count (length arguments)))
              (instance-type
               class
               (for/list ([argument (in-list arguments)])
                 (type-from-sexpr
                  argument environment substitution)))))])]
    [else
     (raise-type-error "malformed type: ~a" datum)]))

(define (infer-send receiver-expression selector arguments environment expected)
  (cond
    [(and (eq? selector 'call) (fn-expr? receiver-expression))
     (define argument-types
       (for/list ([argument (in-list arguments)])
         (infer-expression argument environment #f)))
     (define result-type (fresh-type-variable 'call-result))
     (define expected-function
       (function-type argument-types result-type))
     (define actual-function
       (infer-expression
        receiver-expression environment expected-function))
     (unify-types! actual-function expected-function)
     result-type]
    [else
     (define receiver-type
       (resolve-type
        (infer-expression receiver-expression environment #f)))
     (cond
       [(class-type? receiver-type)
        (define class (class-type-class receiver-type))
        (define constructor (class-constructor class selector))
        (if constructor
            (infer-construction
             class constructor arguments environment expected)
            (unknown-message selector))]
       [(list-class-type? receiver-type)
        (case selector
          [(of) (infer-list-construction arguments environment)]
          [(empty) (infer-empty-list arguments expected)]
          [else (unknown-message selector)])]
       [(symbol-class-type? receiver-type)
        (infer-symbol-class-send selector arguments environment)]
       [(mirror-class-type? receiver-type)
        (infer-mirror-class-send selector arguments environment)]
       [(instance-type? receiver-type)
        (infer-instance-send
         receiver-type selector arguments environment)]
       [(protocol-type? receiver-type)
        (infer-protocol-send
         receiver-type selector arguments environment)]
       [(list-type? receiver-type)
        (infer-list-send receiver-type selector arguments environment)]
       [(function-type? receiver-type)
        (infer-function-call
         receiver-type selector arguments environment)]
       [(or (int-type? receiver-type)
            (float-type? receiver-type)
            (parameter-type? receiver-type))
        (if (and (int-type? receiver-type)
                 (not (memq selector '(+ - * / < > <= >= = float text))))
            (infer-defined-int-method selector arguments environment)
            (infer-numeric-send
             receiver-type selector arguments environment))]
       [(bool-type? receiver-type)
        (infer-bool-send selector arguments environment expected)]
       [(string-type? receiver-type)
        (infer-string-send selector arguments environment)]
       [(symbol-type? receiver-type)
        (infer-symbol-send selector arguments environment)]
       [(mirror-type? receiver-type)
        (infer-mirror-send selector arguments environment expected)]
       [(signature-type? receiver-type)
        (infer-signature-send selector arguments environment)]
       [(host-receiver-type? receiver-type)
        (infer-host-send receiver-type selector arguments environment)]
       [(type-variable? receiver-type)
        (cond
          [(eq? selector 'call)
           (define argument-types
             (for/list ([argument (in-list arguments)])
               (infer-expression argument environment #f)))
           (define result-type (fresh-type-variable 'result))
           (unify-types!
            receiver-type
            (function-type argument-types result-type))
           result-type]
          [(memq selector '(+ - * / < > <= >= =))
           (infer-numeric-send
            receiver-type selector arguments environment)]
          [else (unknown-message selector)])]
       [else
        (unknown-message selector)])]))

(define (host-crossing-type->type crossing-type)
  (cond
    [(eq? crossing-type 'Int) INT]
    [(eq? crossing-type 'Bool) BOOL]
    [(eq? crossing-type 'String) STRING]
    [(equal? crossing-type '(List String)) (list-type STRING)]))

(define (infer-host-send receiver-type selector arguments environment)
  (define interface (host-receiver-type-interface receiver-type))
  (define method
    (for/first ([candidate (in-list (host-interface-methods interface))]
                #:when (eq? selector (host-method-selector candidate)))
      candidate))
  (unless method (unknown-message selector))
  (define parameter-types (host-method-parameter-types method))
  (unless (= (length parameter-types) (length arguments))
    (raise-type-error
     "arity error for ~a method ~a: expected ~a argument(s), got ~a"
     (host-interface-name interface)
     selector
     (length parameter-types)
     (length arguments)))
  (for ([crossing-type (in-list parameter-types)]
        [argument (in-list arguments)]
        [index (in-naturals 1)])
    (define expected-type (host-crossing-type->type crossing-type))
    (define actual-type (infer-expression argument environment #f))
    (unify-types!
     actual-type
     expected-type
     (format "~a method ~a argument ~a expects ~a"
             (host-interface-name interface)
             selector
             index
             crossing-type)))
  (host-crossing-type->type (host-method-return-type method)))

(define (infer-protocol-send protocol selector arguments environment)
  (define protocol-environment (protocol-type-environment protocol))
  (define selected
    (select-method-overload
     (protocol-type-signatures protocol)
     (lambda (_signature) protocol-environment)
     selector
     arguments
     environment
     (make-hasheq)
     (protocol-type-name protocol)))
  (type-from-sexpr
   (method-declaration-return-type (method-match-method selected))
   protocol-environment
   (method-match-substitution selected)))

(define (infer-new-star receiver-expression bindings environment expected)
  (define receiver-type
    (resolve-type (infer-expression receiver-expression environment #f)))
  (unless (and (class-type? receiver-type)
               (not (class-info-explicit-constructors?
                     (class-type-class receiver-type))))
    (raise-type-error
     "ineligible new*: receiver must be a class declared with fields"))
  (define class (class-type-class receiver-type))
  (define constructor (class-constructor class 'new))
  (unless constructor
    (raise-type-error "ineligible new*: class has no generated new constructor"))
  (define fields (constructor-declaration-fields constructor))
  (define field-names (map field-declaration-name fields))
  (define declared (make-hasheq (map (lambda (name) (cons name #t)) field-names)))
  (define expressions (make-hasheq))
  (for ([binding (in-list bindings)])
    (define name (construction-binding-name binding))
    (unless (hash-has-key? declared name)
      (raise-type-error "unknown field ~a for new*" name))
    (when (hash-has-key? expressions name)
      (raise-type-error "duplicate field ~a for new*" name))
    (hash-set! expressions name (construction-binding-value binding)))
  (define missing
    (filter (lambda (name) (not (hash-has-key? expressions name))) field-names))
  (unless (null? missing)
    (raise-type-error "missing fields for new*: ~a" missing))
  ;; This view preserves the original children and their field context. The
  ;; bindings themselves remain in written order for runtime evaluation.
  (infer-construction
   class constructor
   (map (lambda (name) (hash-ref expressions name)) field-names)
   environment expected))

(define (infer-with receiver-expression bindings environment)
  (define receiver-type
    (resolve-type (infer-expression receiver-expression environment #f)))
  (unless (and (instance-type? receiver-type)
               (not (class-info-explicit-constructors?
                     (instance-type-class receiver-type))))
    (raise-type-error
     "ineligible with: receiver must be an instance of a class declared with fields, got ~a"
     (type->datum receiver-type)))
  (define class (instance-type-class receiver-type))
  (define constructor (class-constructor class 'new))
  (unless constructor
    (raise-type-error "ineligible with: class has no generated new constructor"))
  (define fields (constructor-declaration-fields constructor))
  (define declared
    (make-hasheq
     (map (lambda (field) (cons (field-declaration-name field) #t)) fields)))
  (define expressions (make-hasheq))
  (for ([binding (in-list bindings)])
    (define name (construction-binding-name binding))
    (unless (hash-has-key? declared name)
      (raise-type-error "unknown field ~a for with" name))
    (when (hash-has-key? expressions name)
      (raise-type-error "duplicate field ~a for with" name))
    (hash-set! expressions name (construction-binding-value binding)))
  ;; Written values are checked in declaration order against the receiver's
  ;; instantiation. Unwritten fields keep their stored, already-checked values.
  (define substitution (instance-substitution receiver-type))
  (for ([field (in-list fields)])
    (define name (field-declaration-name field))
    (when (hash-has-key? expressions name)
      (infer-expression
       (hash-ref expressions name)
       environment
       (type-from-sexpr
        (field-declaration-type field)
        (class-info-environment class)
        substitution)
       (format "with field ~a" name))))
  receiver-type)

(define (infer-construction class constructor arguments environment expected)
  (define selector (constructor-declaration-selector constructor))
  (define fields (constructor-declaration-fields constructor))
  (unless (= (length fields) (length arguments))
    (raise-type-error
     "arity error for ~a: expected ~a argument(s), got ~a"
     selector
     (length fields)
     (length arguments)))
  (define resolved-expected (and expected (resolve-type expected)))
  (define expected-instance
    (cond
      [(and (instance-type? resolved-expected)
            (eq? class (instance-type-class resolved-expected)))
       resolved-expected]
      [(type-variable? resolved-expected)
       (define provisional
         (instance-type
          class
          (for/list ([parameter
                      (in-list (class-info-type-parameters class))])
            (fresh-type-variable parameter))))
       (unify-types! resolved-expected provisional)
       provisional]
      [else #f]))
  (define inferred (make-hasheq))
  (for ([parameter (in-list (class-info-type-parameters class))]
        [index (in-naturals)])
    (hash-set!
     inferred
     parameter
     (and expected-instance
          (list-ref (instance-type-arguments expected-instance) index))))
  (define argument-types
    (for/list ([argument (in-list arguments)]
               [field (in-list fields)])
      (define expected-field-type
        (and (or (null? (class-info-type-parameters class))
                 expected-instance)
             (type-from-sexpr
              (field-declaration-type field)
              (class-info-environment class)
              inferred)))
      (infer-expression argument environment expected-field-type)))
  (for ([field (in-list fields)]
        [argument-type (in-list argument-types)])
    (infer-field-type!
     class
     (field-declaration-type field)
     argument-type
     inferred))
  (define type-arguments
    (for/list ([parameter (in-list (class-info-type-parameters class))])
      (define inferred-type (hash-ref inferred parameter))
      (define resolved-inferred
        (and inferred-type (resolve-type inferred-type)))
      (when (or (not resolved-inferred)
                (type-variable? resolved-inferred))
        (if (and expected-instance resolved-inferred)
            (set-box!
             (current-construction-obligations)
             (cons
              (construction-obligation parameter class resolved-inferred)
              (unbox (current-construction-obligations))))
            (raise-type-error
             "cannot infer type parameter ~a for ~a"
             parameter
             (class-info-name class))))
      resolved-inferred))
  (instance-type class type-arguments))

;; Field annotations resolve in the class form's environment.
(define (infer-field-type! class declared-type actual-type inferred)
  (define environment (class-info-environment class))
  (cond
    [(and (symbol? declared-type)
          (hash-has-key? inferred declared-type))
     (define previous (hash-ref inferred declared-type))
     (if previous
         (unify-types!
          actual-type
          previous
          (format "inconsistent type parameter ~a" declared-type))
         (hash-set! inferred declared-type actual-type))]
    [(and (list? declared-type)
          (pair? declared-type)
          (eq? (car declared-type) 'List))
     (define resolved-actual (resolve-type actual-type))
     (unless (and (= (length declared-type) 2)
                  (list-type? resolved-actual))
       (raise-type-error "constructor field type mismatch"))
     (infer-field-type!
      class
      (cadr declared-type)
      (list-type-element resolved-actual)
      inferred)]
    [(and (list? declared-type)
          (pair? declared-type)
          (eq? (car declared-type) '->))
     (define resolved-actual (resolve-type actual-type))
     (unless (and (function-type? resolved-actual)
                  (= (length (cdr declared-type))
                     (add1
                      (length
                       (function-type-parameters resolved-actual)))))
       (raise-type-error "constructor field type mismatch"))
     (define actual-parts
       (append (function-type-parameters resolved-actual)
               (list (function-type-result resolved-actual))))
     (for ([nested-declared (in-list (cdr declared-type))]
           [nested-actual (in-list actual-parts)])
       (infer-field-type! class nested-declared nested-actual inferred))]
    [(and (list? declared-type)
          (pair? declared-type)
          (symbol? (car declared-type)))
     (define named-type
       (type-environment-ref environment (car declared-type)))
     (define resolved-actual (resolve-type actual-type))
     (unless (and (class-type? named-type)
                  (instance-type? resolved-actual)
                  (eq? (class-type-class named-type)
                       (instance-type-class resolved-actual)))
       (raise-type-error "constructor field type mismatch"))
     (define nested-class (class-type-class named-type))
     (unless (zero? (length (class-info-type-parameters nested-class)))
       (unless (= (length (cdr declared-type))
                  (length (instance-type-arguments resolved-actual)))
         (raise-type-error "constructor field type mismatch"))
       (for ([nested-declared (in-list (cdr declared-type))]
             [nested-actual
              (in-list (instance-type-arguments resolved-actual))])
         (infer-field-type! class nested-declared nested-actual inferred)))]
    [else
     (define expected
       (type-from-sexpr declared-type environment (make-hasheq)))
     (unify-types! actual-type expected "constructor field type mismatch")]))

(define (infer-instance-send instance selector arguments environment)
  (define class (instance-type-class instance))
  (define field
    (for/first ([candidate (in-list (class-info-fields class))]
                #:when (eq? selector
                            (field-declaration-name candidate)))
      candidate))
  (cond
    [field
     (unless (null? arguments)
       (raise-type-error
        "arity error for field ~a: expected 0 arguments, got ~a"
        selector
        (length arguments)))
     (type-from-sexpr
      (field-declaration-type field)
      (class-info-environment class)
      (instance-substitution instance))]
    [else
     (define selected
       (select-method-overload
        (class-info-methods class)
        (recorded-method-environments (class-info-method-environments class))
        selector
        arguments
        environment
        (instance-substitution instance)
        (class-info-name class)))
     (define method (method-match-method selected))
     (define substitution (method-match-substitution selected))
     (define method-environment (class-method-environment class method))
     (define return-type
       (type-from-sexpr
        (method-declaration-return-type method)
        method-environment
        substitution))
     (when (and (pair? (class-info-type-parameters class))
                (not (class-info-explicit-constructors? class)))
       (parameterize
           ([current-legacy-deferred-generic-instantiation? #t])
         (check-method-body!
          instance method method-environment substitution)))
     return-type]))

;; Each candidate's annotations resolve in the environment
;; method-environment-of gives it; arguments infer where the send is.
(define (select-method-overload
         methods method-environment-of selector arguments environment
         base-substitution target)
  (define selector-methods
    (filter
     (lambda (method)
       (eq? selector (method-declaration-selector method)))
     methods))
  (unless (pair? selector-methods) (unknown-message selector))
  (define arity-methods
    (filter
     (lambda (method)
       (= (length (method-declaration-parameters method))
          (length arguments)))
     selector-methods))
  (unless (pair? arity-methods)
    (raise-type-error
     "arity error for ~a method ~a: no overload accepts ~a argument(s)"
     target selector (length arguments)))
  (cond
    [(null? (cdr arity-methods))
     (match-sole-method
      (car arity-methods)
      (method-environment-of (car arity-methods))
      arguments
      environment
      base-substitution
      target)]
    [else
     (define argument-types
       (for/list ([argument (in-list arguments)])
         (infer-expression argument environment #f)))
     (define matches
       (filter
        values
        (for/list ([method (in-list arity-methods)])
          (try-method-match
           method
           (method-environment-of method)
           argument-types
           base-substitution))))
     (unless (pair? matches) (unknown-message selector))
     (define best-specificity
       (apply max (map method-match-specificity matches)))
     (define best-matches
       (filter
        (lambda (candidate)
          (= (method-match-specificity candidate) best-specificity))
        matches))
     (unless (= (length best-matches) 1)
       (raise-type-error "ambiguous message: ~a" selector))
     (car best-matches)]))

(define (match-sole-method
         method method-environment arguments environment base-substitution
         target)
  (define substitution
    (extend-method-substitution base-substitution method #f))
  (define specificity
    (for/sum ([parameter
               (in-list (method-declaration-parameters method))]
              [argument (in-list arguments)])
      (define expected
        (type-from-sexpr
         (parameter-declaration-type parameter)
         method-environment
         substitution))
      (define actual
        (infer-expression
         argument
         environment
         (and (eq? target 'List) expected)))
      (define score (parameter-specificity actual expected))
      (unify-types!
       actual
       expected
       (format "generic instantiation mismatch for method ~a"
               (method-declaration-selector method)))
      score))
  (ensure-method-type-parameters-inferred! method substitution)
  (method-match method substitution specificity))

(define (try-method-match
         method method-environment argument-types base-substitution)
  (with-handlers ([exn:fail:aloe-type? (lambda (_) #f)])
    (define substitution
      (extend-method-substitution base-substitution method #f))
    (define specificity
      (for/sum ([parameter
                 (in-list (method-declaration-parameters method))]
                [actual (in-list argument-types)])
        (define expected
          (type-from-sexpr
           (parameter-declaration-type parameter)
           method-environment
           substitution))
        (define score (parameter-specificity actual expected))
        (unify-types! actual expected)
        score))
    (ensure-method-type-parameters-inferred! method substitution)
    (method-match method substitution specificity)))

(define (parameter-specificity actual expected)
  (define resolved-actual (resolve-type actual))
  (define resolved-expected (resolve-type expected))
  (cond
    [(type-variable? resolved-expected) 0]
    [(and (protocol-type? resolved-expected)
          (instance-type? resolved-actual))
     1]
    [else 2]))

(define (instance-substitution instance)
  (make-hasheq
   (map cons
        (class-info-type-parameters (instance-type-class instance))
        (instance-type-arguments instance))))

(define (ensure-method-type-parameters-inferred! method substitution)
  (for ([name (in-list (method-declaration-type-parameters method))])
    (define inferred (resolve-type (hash-ref substitution name)))
    (when (type-variable? inferred)
      (raise-type-error
       "cannot infer method type parameter ~a for ~a"
       name
       (method-declaration-selector method)))))

(define (infer-list-construction arguments environment)
  (cond
    [(null? arguments)
     (list-type (fresh-type-variable 'List-element))]
    [else
     (define element-type
       (infer-expression (car arguments) environment #f))
     (for ([argument (in-list (cdr arguments))])
       (define next-type
         (infer-expression argument environment #f))
       (unify-types!
        next-type
        element-type
        "List of elements must have one type"))
     (list-type element-type)]))

(define (infer-empty-list arguments expected)
  (unless (null? arguments)
    (raise-type-error
     "arity error for List empty: expected 0 arguments, got ~a"
     (length arguments)))
  (define resolved-expected (and expected (resolve-type expected)))
  (if (list-type? resolved-expected)
      resolved-expected
      (list-type (fresh-type-variable 'List-element))))

(define (infer-list-send list-value-type selector arguments environment)
  (define element-type (list-type-element list-value-type))
  (case selector
    [(empty?)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List empty?: expected 0 arguments, got ~a"
        (length arguments)))
     BOOL]
    [(first)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List first: expected 0 arguments, got ~a"
        (length arguments)))
     element-type]
    [(rest)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List rest: expected 0 arguments, got ~a"
        (length arguments)))
     list-value-type]
    [(cons)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for List cons: expected 1 argument, got ~a"
        (length arguments)))
     (define argument-type
       (infer-expression (car arguments) environment element-type))
     (unify-types!
      argument-type element-type "List cons element type mismatch")
     list-value-type]
    [(len)
     (unless (null? arguments)
       (raise-type-error
        "arity error for List len: expected 0 arguments, got ~a"
        (length arguments)))
     INT]
    [else
     (infer-defined-list-method
      list-value-type selector arguments environment)]))

(define (infer-defined-list-method
         receiver-type selector arguments environment)
  (define list-class (type-environment-ref environment 'List))
  (define base-substitution
    (make-hasheq
     (list (cons 'T (list-type-element receiver-type)))))
  (unless (list-class-type? list-class) (unknown-message selector))
  (define selected
    (select-method-overload
     (list-class-type-methods list-class)
     (recorded-method-environments
      (list-class-type-method-environments list-class))
     selector
     arguments
     environment
     base-substitution
     'List))
  (define method (method-match-method selected))
  (define substitution (method-match-substitution selected))
  (type-from-sexpr
   (method-declaration-return-type method)
   (recorded-method-environment
    (list-class-type-method-environments list-class) method)
   substitution))

(define (infer-function-call function selector arguments environment)
  (unless (eq? selector 'call) (unknown-message selector))
  (define parameters (function-type-parameters function))
  (unless (= (length parameters) (length arguments))
    (raise-type-error
     "arity error for function call: expected ~a argument(s), got ~a"
     (length parameters)
     (length arguments)))
  (for ([parameter (in-list parameters)]
        [argument (in-list arguments)])
    (define actual
      (infer-expression argument environment parameter))
    (unify-types! actual parameter))
  (function-type-result function))

(define (infer-numeric-send receiver selector arguments environment)
  (define resolved-receiver (resolve-type receiver))
  (cond
    [(eq? selector 'float)
     (unless (int-type? resolved-receiver)
       (unknown-message selector))
     (unless (null? arguments)
       (raise-type-error
       "arity error for Int float: expected 0 arguments, got ~a"
       (length arguments)))
     FLOAT]
    [(eq? selector 'text)
     (unless (int-type? resolved-receiver)
       (unknown-message selector))
     (unless (null? arguments)
       (raise-type-error
        "arity error for Int text: expected 0 arguments, got ~a"
        (length arguments)))
     STRING]
    [else
     (unless (memq selector '(+ - * / < > <= >= =))
       (unknown-message selector))
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for numeric ~a: expected 1 argument, got ~a"
        selector
        (length arguments)))
     (ensure-numeric-type! receiver)
     (define mismatch-message
       (cond
         [(int-type? resolved-receiver)
          (format "Int ~a expects an Int argument" selector)]
         [(float-type? resolved-receiver)
          (format "Float ~a expects a Float argument" selector)]
         [else "numeric operands must have the same type"]))
     (define argument-type
       (infer-expression (car arguments) environment #f))
     (unify-types! argument-type receiver mismatch-message)
     (ensure-numeric-type! receiver)
     (if (memq selector '(< > <= >= =)) BOOL receiver)]))

(define (infer-defined-int-method selector arguments environment)
  (define int-class (type-environment-int-class environment))
  (define selected
    (select-method-overload
     (int-class-type-methods int-class)
     (recorded-method-environments
      (int-class-type-method-environments int-class))
     selector
     arguments
     environment
     (make-hasheq)
     'Int))
  (define method (method-match-method selected))
  (type-from-sexpr
   (method-declaration-return-type method)
   (recorded-method-environment
    (int-class-type-method-environments int-class) method)
   (method-match-substitution selected)))

(define (infer-bool-send selector arguments environment expected)
  (unless (eq? selector 'if) (unknown-message selector))
  (unless (= (length arguments) 2)
    (raise-type-error
     "arity error for Bool if: expected 2 arguments, got ~a"
     (length arguments)))
  (define result-type
    (or expected (fresh-type-variable 'if-result)))
  (define expected-thunk (function-type '() result-type))
  (for ([argument (in-list arguments)])
    (define actual-thunk
      (infer-expression argument environment expected-thunk))
    (unify-types! actual-thunk expected-thunk))
  result-type)

(define (infer-string-send selector arguments environment)
  (case selector
    [(= append)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for String ~a: expected 1 argument, got ~a"
        selector
        (length arguments)))
     (define argument-type
       (infer-expression (car arguments) environment STRING))
     (unify-types!
      argument-type
      STRING
      (format "String ~a expects a String argument" selector))
     (if (eq? selector '=) BOOL STRING)]
    [(len split-lines)
     (unless (null? arguments)
       (raise-type-error
        "arity error for String ~a: expected 0 arguments, got ~a"
        selector
        (length arguments)))
     (if (eq? selector 'len) INT (list-type STRING))]
    [(take drop)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for String ~a: expected 1 argument, got ~a"
        selector
        (length arguments)))
     (define argument-type
       (infer-expression (car arguments) environment INT))
     (unify-types!
      argument-type
      INT
      (format "String ~a expects an Int argument" selector))
     STRING]
    [(joined-with)
     (unless (= (length arguments) 3)
       (raise-type-error
        "arity error for String joined-with: expected 3 arguments, got ~a"
        (length arguments)))
     (for ([argument (in-list arguments)]
           [expected-type (in-list (list (list-type STRING)
                                         STRING
                                         (list-type STRING)))])
       (define actual-type
         (infer-expression argument environment expected-type))
       (unify-types! actual-type expected-type
                     "String joined-with argument type mismatch"))
     STRING]
    [(find)
     (unless (= (length arguments) 2)
       (raise-type-error
        "arity error for String find: expected 2 arguments, got ~a"
        (length arguments)))
     (for ([argument (in-list arguments)]
           [expected-type (in-list (list STRING INT))])
       (define actual-type (infer-expression argument environment expected-type))
       (unify-types! actual-type expected-type
                     "String find argument type mismatch"))
     (define option-class
       (unbox (type-environment-option-class environment)))
     (unless option-class
       (raise-type-error "unbound symbol: ~a" 'Option))
     (instance-type option-class (list INT))]
    [else
     (infer-defined-string-method selector arguments environment)]))

(define (infer-defined-string-method selector arguments environment)
  (define string-class (type-environment-string-class environment))
  (define selected
    (select-method-overload
     (string-class-type-methods string-class)
     (recorded-method-environments
      (string-class-type-method-environments string-class))
     selector
     arguments
     environment
     (make-hasheq)
     'String))
  (define method (method-match-method selected))
  (type-from-sexpr
   (method-declaration-return-type method)
   (recorded-method-environment
    (string-class-type-method-environments string-class) method)
   (method-match-substitution selected)))

(define (infer-symbol-class-send selector arguments environment)
  (unless (eq? selector 'intern) (unknown-message selector))
  (unless (= (length arguments) 1)
    (raise-type-error
     "arity error for Symbol intern: expected 1 argument, got ~a"
     (length arguments)))
  (define argument-type
    (infer-expression (car arguments) environment STRING))
  (unify-types!
   argument-type
   STRING
   "Symbol intern expects a String argument")
  SYMBOL)

(define (infer-mirror-class-send selector arguments environment)
  (unless (eq? selector 'of) (unknown-message selector))
  (unless (= (length arguments) 1)
    (raise-type-error
     "arity error for Mirror of: expected 1 argument, got ~a"
     (length arguments)))
  (infer-expression (car arguments) environment #f)
  MIRROR)

(define (infer-mirror-send selector arguments environment expected)
  (case selector
    [(messages)
     (unless (null? arguments)
       (raise-type-error
        "arity error for Mirror messages: expected 0 arguments, got ~a"
        (length arguments)))
     (list-type SYMBOL)]
    [(signatures)
     (unless (null? arguments)
       (raise-type-error
        "arity error for Mirror signatures: expected 0 arguments, got ~a"
        (length arguments)))
     (list-type SIGNATURE)]
    [(invoke)
     (unless (pair? arguments)
       (raise-type-error
        "arity error for Mirror invoke: expected at least a Signature"))
     (define signature-type
       (infer-expression (car arguments) environment SIGNATURE))
     (unify-types!
      signature-type
      SIGNATURE
      "Mirror invoke expects a Signature first")
     (for ([argument (in-list (cdr arguments))])
       (infer-expression argument environment #f))
     (or expected (fresh-type-variable 'invoke-result))]
    [(subject)
     (unless (null? arguments)
       (raise-type-error
        "arity error for Mirror subject: expected 0 arguments, got ~a"
        (length arguments)))
     (or expected (fresh-type-variable 'subject-result))]
    [(raw)
     (unless (null? arguments)
       (raise-type-error
        "arity error for Mirror raw: expected 0 arguments, got ~a"
        (length arguments)))
     STRING]
    [else (unknown-message selector)]))

(define (infer-signature-send selector arguments environment)
  (case selector
    [(selector params return)
     (unless (null? arguments)
       (raise-type-error
        "arity error for Signature ~a: expected 0 arguments, got ~a"
        selector
        (length arguments)))
     (case selector
       [(selector) SYMBOL]
       [(params) (list-type TYPE-DATA)]
       [(return) TYPE-DATA])]
    [(accepts?)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for Signature accepts?: expected 1 argument, got ~a"
        (length arguments)))
     (define argument-type
       (infer-expression (car arguments) environment MIRROR))
     (unify-types!
      argument-type MIRROR
      "Signature accepts? expects a Mirror argument")
     BOOL]
    [else (unknown-message selector)]))

(define (infer-symbol-send selector arguments environment)
  (case selector
    [(name)
     (unless (null? arguments)
       (raise-type-error
        "arity error for Symbol name: expected 0 arguments, got ~a"
        (length arguments)))
     STRING]
    [(=)
     (unless (= (length arguments) 1)
       (raise-type-error
        "arity error for Symbol =: expected 1 argument, got ~a"
        (length arguments)))
     (define argument-type
       (infer-expression (car arguments) environment SYMBOL))
     (unify-types!
      argument-type
      SYMBOL
      "Symbol = expects a Symbol argument")
     BOOL]
    [else (unknown-message selector)]))

(define (unknown-message selector)
  (raise-type-error "unknown message: ~a" selector))

(define-values
  (current-legacy-deferred-generic-instantiation?
   typecheck-program/observe
   typecheck-program/observe-selector-receiver
   retain-expression-observation!
   observe-selector-receiver!
   materialize-expression-observation-at-root-end!
   selected-expression-in-method-body?)
  (make-checker-observation-api
   typecheck-program
   current-typecheck-program-depth
   type->datum
   type-signature-specs))

;; The driver needs one narrow construction hook without making host types a
;; normal part of the checker's public API.
(module* driver-host-injection #f
  (provide type-environment-inject-host!))

;; Bases record their installed libraries and Option, keyed roots share the
;; load cache, and each base gets its interactive environment, through these
;; hooks for the driver and aloe/main.rkt.
(module* load-cache #f
  (provide typecheck-keyed-root
           typecheck-keyed-buffer
           typecheck-file-buffer
           record-checked-libraries!
           record-checked-option-class!
           make-interactive-type-environment
           type-environment-base))

;; Editor expression queries observe the real checker pass through this
;; deliberately narrow internal bridge.
(module* expression-query-observation #f
  (provide (struct-out expression-type-observation)
           typecheck-program/observe))

;; Editor completion queries escape at the successful inference boundary for
;; the exact receiver recovered by the private selector-site parser.
(module* completion-query-observation #f
  (provide (struct-out selector-receiver-observation)
           typecheck-program/observe-selector-receiver))

;; Tests read the classes a root's conformance walk visits through this hook;
;; nothing else does.
(module* conformance-walk #f
  (provide conformance-classes)

  ;; The names of the classes the walk visits for a root checked in
  ;; environment, as both its file and its interactive environment, in visit
  ;; order, each class record once.
  (define (conformance-classes environment)
    (map class-info-name
         (conformance-walk-classes environment environment))))

;; Tests read the environment each method, class, and protocol recorded through
;; this hook; nothing else does.
(module* method-records #f
  (provide checker-method-records
           checker-class-environment
           checker-protocol-environment)

  ;; For the class, or the List, Int, or String class, bound to name: each
  ;; method's selector and recorded environment, in method order.
  (define (checker-method-records environment name)
    (define class (type-environment-ref environment name))
    (define-values (methods method-environments)
      (cond
        [(class-type? class)
         (define info (class-type-class class))
         (values (class-info-methods info)
                 (class-info-method-environments info))]
        [(list-class-type? class)
         (values (list-class-type-methods class)
                 (list-class-type-method-environments class))]
        [(int-class-type? class)
         (values (int-class-type-methods class)
                 (int-class-type-method-environments class))]
        [(string-class-type? class)
         (values (string-class-type-methods class)
                 (string-class-type-method-environments class))]
        [else
         (error 'checker-method-records "~a is not a class" name)]))
    (for/list ([method (in-list methods)])
      (cons (method-declaration-selector method)
            (recorded-method-environment method-environments method))))

  (define (checker-class-environment environment name)
    (define class (type-environment-ref environment name))
    (unless (class-type? class)
      (error 'checker-class-environment "~a is not a class" name))
    (class-info-environment (class-type-class class)))

  (define (checker-protocol-environment environment name)
    (define protocol (type-environment-ref environment name))
    (unless (protocol-type? protocol)
      (error 'checker-protocol-environment "~a is not a protocol" name))
    (protocol-type-environment protocol)))
