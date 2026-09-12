#lang racket/base

(require racket/list
         rackunit
         "../../../aloe/eval.rkt"
         "../../../aloe/host.rkt"
         "../../../aloe/main.rkt"
         "../../../aloe/parse.rkt"
         "../../../aloe/signature-catalog.rkt"
         "../../../aloe/signature.rkt"
         "../../../aloe/symbol.rkt"
         (prefix-in type: "../../../aloe/type.rkt"))

(define (triples->specs triples)
  (for/list ([triple (in-list triples)])
    (apply signature-spec triple)))

(define (runtime-signature->spec value)
  (signature-spec
   (string->symbol
    (symbol-value-name (signature-value-selector value)))
   (signature-value-parameter-data value)
   (signature-value-return-data value)))

(define (list-element-source list-source index)
  (define tail-source
    (for/fold ([source list-source])
              ([_ (in-range index)])
      (format "(~a rest)" source)))
  (format "(~a first)" tail-source))

(define (mirror-signature-specs subject-source environment)
  (define rows-source
    (format "((Mirror of ~a) signatures)" subject-source))
  (define count
    (eval-source (format "(~a len)" rows-source) environment))
  (for/list ([index (in-range count)])
    (runtime-signature->spec
     (eval-source
      (list-element-source rows-source index)
      environment))))

(define (mirror-message-names subject-source environment)
  (define messages-source
    (format "((Mirror of ~a) messages)" subject-source))
  (define count
    (eval-source (format "(~a len)" messages-source) environment))
  (for/list ([index (in-range count)])
    (string->symbol
     (eval-source
      (format "(~a name)"
              (list-element-source messages-source index))
      environment))))

(test-case "signature-spec is one public transparent structure"
  (define row
    (signature-spec 'map '((-> T U)) '(List U)))
  (define same-row
    (type:signature-spec 'map '((-> T U)) '(List U)))
  (check-true (signature-spec? same-row))
  (check-true (type:signature-spec? row))
  (check-equal? row same-row)
  (check-equal? (signature-spec-selector row) 'map)
  (check-equal? (signature-spec-parameters row) '((-> T U)))
  (check-equal? (signature-spec-return row) '(List U))
  (check-equal?
   (struct->vector row)
   '#(struct:signature-spec map ((-> T U)) (List U))))

(test-case "kernel instance rows have exact triples and order"
  (check-equal?
   (kernel-instance-signature-specs 'Int)
   (triples->specs
    '((+ (Int) Int)
      (- (Int) Int)
      (* (Int) Int)
      (/ (Int) Int)
      (< (Int) Bool)
      (> (Int) Bool)
      (<= (Int) Bool)
      (>= (Int) Bool)
      (= (Int) Bool)
      (float () Float)
      (text () String))))
  (check-equal?
   (kernel-instance-signature-specs 'Float)
   (triples->specs
    '((+ (Float) Float)
      (- (Float) Float)
      (* (Float) Float)
      (/ (Float) Float)
      (< (Float) Bool)
      (> (Float) Bool)
      (<= (Float) Bool)
      (>= (Float) Bool)
      (= (Float) Bool))))
  (check-equal?
   (kernel-instance-signature-specs 'Bool)
   (triples->specs
    '((if ((-> T) (-> T)) T))))
  (check-equal?
   (kernel-instance-signature-specs 'String)
   (triples->specs
    '((= (String) Bool)
      (append (String) String)
      (len () Int)
      (take (Int) String))))
  (check-equal?
   (kernel-instance-signature-specs 'Symbol)
   (triples->specs
    '((name () String)
      (= (Symbol) Bool))))
  (check-equal?
   (kernel-instance-signature-specs 'Mirror)
   (triples->specs
    '((messages () (List Symbol))
      (signatures () (List Signature))
      (invoke (Signature) U)
      (subject () U)
      (raw () String))))
  (check-equal?
   (kernel-instance-signature-specs 'Signature)
   (triples->specs
    '((selector () Symbol)
      (params () (List TypeData))
      (return () TypeData)
      (accepts? (Mirror) Bool))))
  (check-equal?
   (kernel-instance-signature-specs 'List)
   (triples->specs
    '((empty? () Bool)
      (first () T)
      (rest () (List T))
      (cons (T) (List T))
      (len () Int)))))

(test-case "built-in class-object rows are separate exact catalogs"
  (check-equal?
   (kernel-class-object-signature-specs 'List)
   (triples->specs
    '((of (T) (List T))
      (empty () (List T)))))
  (check-equal?
   (kernel-class-object-signature-specs 'Symbol)
   (triples->specs '((intern (String) Symbol))))
  (check-equal?
   (kernel-class-object-signature-specs 'Mirror)
   (triples->specs '((of (T) Mirror))))
  (check-equal? (kernel-class-object-signature-specs 'String) '()))

(test-case "substitution recursively traverses every type datum"
  (define row
    (signature-spec
     'transform
     '((List T) (Point T) (-> T A) U)
     '(-> (List T) (Point T))))
  (check-equal?
   (substitute-signature-spec row (hasheq 'T 'Int 'U 'String))
   (signature-spec
    'transform
    '((List Int) (Point Int) (-> Int A) String)
    '(-> (List Int) (Point Int))))
  (check-equal?
   (substitute-signature-specs
    (list row)
    (hasheq 'T '(List String)))
   (list
    (signature-spec
     'transform
     '((List (List String))
       (Point (List String))
       (-> (List String) A)
       U)
     '(-> (List (List String)) (Point (List String)))))))

(test-case "declaration conversion retains order and overload rows"
  (define fields
    (list (field-declaration 'left 'T)
          (field-declaration 'right '(List T))))
  (define methods
    (list
     (method-declaration
      'pick '() (list (parameter-declaration 'value 'T)) 'T #f)
     (method-declaration
      'pick '(A) (list (parameter-declaration 'value 'A)) 'A #f)))
  (define constructors
    (list (constructor-declaration 'None '())
          (constructor-declaration
           'Some
           (list (field-declaration 'value 'T)))))
  (check-equal?
   (field-declarations->signature-specs fields (hasheq 'T 'Int))
   (triples->specs
    '((left () Int)
      (right () (List Int)))))
  (check-equal?
   (method-declarations->signature-specs methods (hasheq 'T 'Int))
   (triples->specs
    '((pick (Int) Int)
      (pick (A) A))))
  (check-equal?
   (constructor-declarations->signature-specs
    constructors
    '(Option T))
   (triples->specs
    '((None () (Option T))
      (Some (T) (Option T))))))

(define environment (make-top-level-env))

(void
 (eval-source
  #<<ALOE
(define-class (CatalogPoint T)
  (fields
    (value T)
    (values (List T)))
  (methods
    (map-one (f (-> T T)) (CatalogPoint T) self)
    (local (type A) (other A) A other)
    (pick (other Int) Int other)
    (pick (other String) String other)))
ALOE
  environment))

(test-case "generic legacy class mirrors substitute fields and methods"
  (check-equal?
   (mirror-signature-specs
    "(CatalogPoint new 10 (List of 20 30))"
    environment)
   (triples->specs
    '((value () Int)
      (values () (List Int))
      (map-one ((-> Int Int)) (CatalogPoint Int))
      (local (A) A)
      (pick (Int) Int)
      (pick (String) String))))
  (check-equal?
   (mirror-signature-specs "CatalogPoint" environment)
   (triples->specs
    '((new (T (List T)) (CatalogPoint T)))))
  (check-equal?
   (mirror-message-names
    "(CatalogPoint new 10 (List of 20 30))"
    environment)
   '(value values map-one local pick))
  (check-equal?
   (eval-source
    "((CatalogPoint new 10 (List of 20 30)) pick 7)"
    environment)
   7)
  (check-equal?
   (eval-source
    "((CatalogPoint new 10 (List of 20 30)) pick \"seven\")"
    environment)
   "seven"))

(void
 (eval-source
  #<<ALOE
(define-class (CatalogOption T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods
    (present? () Bool
      (self case
        (None () #f)
        (Some (value) #t)))))
ALOE
  environment))

(test-case "explicit constructors are reflected and invoked as exact rows"
  (check-equal?
   (mirror-signature-specs "CatalogOption" environment)
   (triples->specs
    '((None () (CatalogOption T))
      (Some (T) (CatalogOption T)))))
  (check-equal?
   (mirror-message-names "CatalogOption" environment)
   '(None Some))
  (check-false
   (member 'new (mirror-message-names "CatalogOption" environment)))
  (check-equal?
   (mirror-signature-specs "(CatalogOption Some 10)" environment)
   (triples->specs '((present? () Bool))))

  (void
   (eval-source
    #<<ALOE
(define catalog-option-mirror (Mirror of CatalogOption))
(define catalog-option-rows (catalog-option-mirror signatures))
(define catalog-none-row (catalog-option-rows first))
(define catalog-some-row ((catalog-option-rows rest) first))
(define-class CatalogOptionInvoker
  (fields
    (none-row Signature)
    (some-row Signature))
  (methods
    (make-none () (CatalogOption Int)
      ((Mirror of CatalogOption) invoke (self none-row)))
    (make-some (value String) (CatalogOption String)
      ((Mirror of CatalogOption) invoke (self some-row) value))))
ALOE
    environment))
  (define none-result
    (eval-source
     "((CatalogOptionInvoker new catalog-none-row catalog-some-row) make-none)"
     environment))
  (define some-result
    (eval-source
     (string-append
      "((CatalogOptionInvoker new catalog-none-row catalog-some-row) "
      "make-some \"ready\")")
     environment))
  (check-eq? (instance-value-constructor none-result) 'None)
  (check-eq? (instance-value-constructor some-result) 'Some)
  (check-false
   (eval-source
    (string-append
     "(((CatalogOptionInvoker new catalog-none-row catalog-some-row) "
     "make-none) present?)")
    environment))
  (check-equal?
   (eval-source
    (string-append
     "(((CatalogOptionInvoker new catalog-none-row catalog-some-row) "
     "make-some \"ready\") case "
     "(None () \"missing\") (Some (value) value))")
    environment)
   "ready")
  (check-true
   (eval-source "((CatalogOption Some \"direct\") present?)" environment)))

(test-case "environment-installed String method is one final runtime row"
  (void
   (eval-source
    #<<ALOE
(define-methods String
  (methods
    (catalog-000-tail () String self)))
ALOE
    environment))
  (define rows (mirror-signature-specs "\"catalog\"" environment))
  (check-equal? (last rows)
                (signature-spec 'catalog-000-tail '() 'String))
  (check-equal?
   (length
    (filter (lambda (row)
              (eq? (signature-spec-selector row) 'catalog-000-tail))
            rows))
   1)
  (check-equal?
   (eval-source "(\"catalog\" catalog-000-tail)" environment)
   "catalog"))

(test-case "host declarations become rows without implementation calls"
  (define implementation-calls 0)
  (define interface
    (make-host-interface
     'CatalogHost
     (list
      (make-host-method
       'name
       '()
       'String
       (lambda (_state)
         (set! implementation-calls (add1 implementation-calls))
         "called"))
      (make-host-method
       'accept
       '((List String))
       'Bool
       (lambda (_state _values)
         (set! implementation-calls (add1 implementation-calls))
         #t)))))
  (check-equal?
   (host-method-declarations->signature-specs
    (host-interface-methods interface))
   (triples->specs
    '((name () String)
      (accept ((List String)) Bool))))
  (check-equal? implementation-calls 0))

(test-case "runtime function reflection retains its erased call row"
  (check-equal?
   (make-call-signature-spec '(Int String) 'Bool)
   (signature-spec 'call '(Int String) 'Bool))
  (void
   (eval-source
    #<<ALOE
(define-class CatalogFunctionBox
  (fields
    (value (-> Int String Int)))
  (methods))
ALOE
    environment))
  (check-equal?
   (mirror-signature-specs
    "((CatalogFunctionBox new (fn (left right) left)) value)"
    environment)
   (triples->specs '((call (T T) U)))))

(test-case "the runtime String class object has no reflected rows"
  (check-equal? (mirror-signature-specs "String" environment) '())
  (check-equal? (mirror-message-names "String" environment) '()))
