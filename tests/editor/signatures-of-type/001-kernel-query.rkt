#lang racket/base

(require racket/list
         racket/runtime-path
         rackunit
         "../../../aloe/driver.rkt"
         "../../../aloe/host.rkt"
         "../../../aloe/parse.rkt"
         "../../../aloe/signature-catalog.rkt"
         "../../../aloe/signature.rkt"
         "../../../aloe/symbol.rkt"
         (prefix-in type: "../../../aloe/type.rkt"))

(define-runtime-path type-path "../../../aloe/type.rkt")
(define-runtime-path main-path "../../../aloe/main.rkt")

(define (triples->specs triples)
  (for/list ([triple (in-list triples)])
    (apply signature-spec triple)))

(define (static-type environment datum)
  (type:type-of (parse-datum datum) environment))

(define (static-signatures environment datum)
  (type:type-signature-specs
   (static-type environment datum)
   environment))

(define (runtime-signature->spec value)
  (signature-spec
   (string->symbol
    (symbol-value-name (signature-value-selector value)))
   (signature-value-parameter-data value)
   (signature-value-return-data value)))

(define (list-element-expression expression index)
  (define tail
    (for/fold ([tail expression])
              ([_ (in-range index)])
      (list tail 'rest)))
  (list tail 'first))

(define (mirror-signatures state subject)
  (define rows-expression
    (list (list 'Mirror 'of subject) 'signatures))
  (define count
    (driver-eval! state (list rows-expression 'len)))
  (for/list ([index (in-range count)])
    (runtime-signature->spec
     (driver-eval!
      state
      (list-element-expression rows-expression index)))))

(define (check-deferred thunk family)
  (check-exn
   (regexp
    (format
     "type-signature-specs: checker type family ~a is deferred"
     family))
   thunk))

(test-case "the exact two-argument query and shared row type are public"
  (define query (dynamic-require type-path 'type-signature-specs))
  (check-equal? (procedure-arity query) 2)
  (check-exn #rx"type-signature-specs"
             (lambda () (query (type:int-type))))
  (check-exn #rx"type-signature-specs"
             (lambda ()
               (query (type:int-type)
                      (type:make-type-environment)
                      'extra)))
  (check-exn
   #rx"type-signature-specs: contract violation.*checker type"
   (lambda () (query 1 (type:make-type-environment))))
  (check-exn
   #rx"type-signature-specs: contract violation.*checker type"
   (lambda ()
     (query (type:list-type 'not-a-checker-type)
            (type:make-type-environment))))
  (check-exn
   #rx"type-signature-specs: contract violation.*checker type"
   (lambda ()
     (query (type:function-type
             (list 'not-a-checker-type)
             (type:int-type))
            (type:make-type-environment))))
  (check-exn
   #rx"type-signature-specs: contract violation.*type-environment"
   (lambda () (query (type:int-type) 'not-an-environment)))
  (define first-result
    (query (type:int-type) (type:make-type-environment)))
  (define second-result
    (query (type:int-type) (type:make-type-environment)))
  (check-true (andmap signature-spec? first-result))
  (check-true (andmap type:signature-spec? first-result))
  (check-equal? first-result second-result)
  (check-false (eq? first-result second-result))
  (check-exn exn:fail?
             (lambda ()
               (dynamic-require main-path 'type-signature-specs))))

(test-case "primitive checker types select exact shared rows"
  (define environment (type:make-type-environment))
  (for ([datum (in-list
                (list 1
                      1.0
                      #t
                      "text"
                      '(Symbol intern "name")
                      '(Mirror of 1)
                      '(((Mirror of 1) signatures) first)))]
        [name (in-list
               '(Int Float Bool String Symbol Mirror Signature))])
    (check-equal?
     (static-signatures environment datum)
     (kernel-instance-signature-specs name)
     (symbol->string name))))

(test-case "primitive static rows have runtime Mirror parity"
  (define state (make-driver))
  (define environment (driver-type-environment state))
  (for ([datum (in-list
                (list 1
                      1.0
                      #t
                      "text"
                      '(Symbol intern "name")
                      '(Mirror of 1)
                      '(((Mirror of 1) signatures) first)))])
    (check-equal?
     (static-signatures environment datum)
     (mirror-signatures state datum)
     (format "Mirror parity for ~s" datum))))

(define list-extension
  '(define-methods List
     (methods
       (catalog-001-pair (type A) (other A) (List T) self))))

(test-case "List substitutes kernel and installed method rows"
  (define environment (type:make-type-environment))
  (type:typecheck-program
   (list (parse-datum list-extension))
   environment)
  (check-equal?
   (static-signatures environment '(List of "value"))
   (triples->specs
    '((empty? () Bool)
      (first () String)
      (rest () (List String))
      (cons (String) (List String))
      (len () Int)
      (catalog-001-pair (A) (List String)))))
  (define state (make-driver))
  (check-true (void? (driver-eval! state list-extension)))
  (define static-rows
    (static-signatures
     (driver-type-environment state)
     '(List of "value")))
  (check-equal? static-rows
                (mirror-signatures state '(List of "value")))
  (check-equal?
   (last static-rows)
   (signature-spec
    'catalog-001-pair '(A) '(List String))))

(define string-a-extension
  '(define-methods String
     (methods
       (catalog-001-a () String self))))

(define string-b-extension
  '(define-methods String
     (methods
       (catalog-001-b () Int (self len)))))

(test-case "String and List extensions remain local and observational"
  (define environment-a (type:make-type-environment))
  (define environment-b (type:make-type-environment))
  (type:typecheck-program
   (list (parse-datum string-a-extension)
         (parse-datum list-extension))
   environment-a)
  (type:typecheck-program
   (list (parse-datum string-b-extension))
   environment-b)
  (define string-a-rows
    (static-signatures environment-a "a"))
  (define string-b-rows
    (static-signatures environment-b "b"))
  (check-equal?
   (last string-a-rows)
   (signature-spec 'catalog-001-a '() 'String))
  (check-equal?
   (last string-b-rows)
   (signature-spec 'catalog-001-b '() 'Int))
  (check-false
   (member (signature-spec 'catalog-001-a '() 'String)
           string-b-rows))
  (check-false
   (member (signature-spec 'catalog-001-b '() 'Int)
           string-a-rows))
  (check-equal? (static-signatures environment-a "again")
                string-a-rows)
  (check-equal?
   (length
    (filter
     (lambda (row)
       (eq? (signature-spec-selector row) 'catalog-001-a))
     (static-signatures environment-a "again")))
   1)
  (check-equal?
   (last (static-signatures environment-a '(List of 1)))
   (signature-spec 'catalog-001-pair '(A) '(List Int)))
  (check-equal?
   (driver-eval!
    (let ([state (make-driver)])
      (driver-eval! state string-a-extension)
      state)
    '("still-works" catalog-001-a))
   "still-works"))

(define function-box-definition
  '(define-class CatalogFunctionBox001
     (fields
       (value (-> Int String Bool)))
     (methods)))

(test-case "functions expose one exact static call row"
  (define environment (type:make-type-environment))
  (type:typecheck-program
   (list (parse-datum function-box-definition))
   environment)
  (check-equal?
   (static-signatures environment '(fn () 1))
   (triples->specs '((call () Int))))
  (check-equal?
   (static-signatures environment '(fn (value) (value + 1)))
   (triples->specs '((call (Int) Int))))
  (define multi-expression
    '((CatalogFunctionBox001 new (fn (number text) #t)) value))
  (check-equal?
   (static-signatures environment multi-expression)
   (triples->specs '((call (Int String) Bool)))))

(test-case "function Mirror parity keeps the documented erasure exception"
  (define state (make-driver))
  (check-true
   (void? (driver-eval! state function-box-definition)))
  (define environment (driver-type-environment state))
  (define subjects
    (list '(fn () 1)
          '(fn (value) (value + 1))
          '((CatalogFunctionBox001
             new
             (fn (number text) #t))
            value)))
  (define expected-static
    (triples->specs
     '((call () Int)
       (call (Int) Int)
       (call (Int String) Bool))))
  (define expected-runtime
    (triples->specs
     '((call () U)
       (call (T) U)
       (call (T T) U))))
  (for ([subject (in-list subjects)]
        [static-row (in-list expected-static)]
        [runtime-row (in-list expected-runtime)])
    (define actual-static
      (car (static-signatures environment subject)))
    (define actual-runtime
      (car (mirror-signatures state subject)))
    (check-equal? actual-static static-row)
    (check-equal? actual-runtime runtime-row)
    (check-eq? (signature-spec-selector actual-static)
               (signature-spec-selector actual-runtime))
    (check-equal? (length (signature-spec-parameters actual-static))
                  (length (signature-spec-parameters actual-runtime)))))

(test-case "built-in class objects have distinct exact catalogs"
  (define environment (type:make-type-environment))
  (for ([name (in-list '(List String Symbol Mirror))])
    (check-equal?
     (static-signatures environment name)
     (kernel-class-object-signature-specs name)
     (symbol->string name)))
  (check-equal?
   (static-signatures environment 'List)
   (triples->specs
    '((of (T) (List T))
      (empty () (List T)))))
  (check-equal? (static-signatures environment 'String) '())
  (check-not-equal? (static-signatures environment 'Symbol)
                    (static-signatures
                     environment '(Symbol intern "name"))))

(test-case "rigid parameters use nine same-parameter numeric rows"
  (define environment (type:make-type-environment))
  (define list-class (static-type environment 'List))
  (define parameter
    (type:list-class-type-element-parameter list-class))
  (check-equal?
   (type:type-signature-specs parameter environment)
   (triples->specs
    '((+ (T) T)
      (- (T) T)
      (* (T) T)
      (/ (T) T)
      (< (T) Bool)
      (> (T) Bool)
      (<= (T) Bool)
      (>= (T) Bool)
      (= (T) Bool)))))

(test-case "inference variables resolve without inspection constraints"
  (define environment (type:make-type-environment))
  (define unresolved-list
    (static-type environment '(List empty)))
  (define unresolved
    (type:list-type-element unresolved-list))
  (define before (struct->vector unresolved))
  (check-equal?
   (type:type-signature-specs unresolved environment)
   '())
  (check-equal? (struct->vector unresolved) before)
  (check-equal?
   (type:type-signature-specs unresolved-list environment)
   (triples->specs
    '((empty? () Bool)
      (first () List-element)
      (rest () (List List-element))
      (cons (List-element) (List List-element))
      (len () Int))))

  (type:typecheck-program
   (list (parse-datum '(define pending-001 (List empty))))
   environment)
  (define pending-type (static-type environment 'pending-001))
  (define pending-element (type:list-type-element pending-type))
  (check-equal?
   (type:type-signature-specs pending-element environment)
   '())
  (static-type environment '(pending-001 cons "bound"))
  (check-equal?
   (type:type-signature-specs pending-element environment)
   (kernel-instance-signature-specs 'String)))

(test-case "legitimate empty internal types remain empty"
  (define environment (type:make-type-environment))
  (define void-result
    (static-type environment '(define ignored-001 1)))
  (define type-data-result
    (static-type
     environment
     '((((Mirror of 1) signatures) first) return)))
  (define opaque-result (static-type environment 'dummy))
  (for ([type (in-list
               (list void-result type-data-result opaque-result))])
    (check-equal?
     (type:type-signature-specs type environment)
     '())))

(test-case "declaration-backed type families are visibly deferred"
  (define environment (type:make-type-environment))
  (type:typecheck-program
   (map parse-datum
        '((define-protocol DeferredProtocol001)
          (define-class DeferredPoint001
            (fields (x Int))
            (methods))))
   environment)
  (check-deferred
   (lambda ()
     (type:type-signature-specs
      (static-type environment '(DeferredPoint001 new 1))
      environment))
   'instance-type)
  (check-deferred
   (lambda ()
     (type:type-signature-specs
      (static-type environment 'DeferredPoint001)
      environment))
   'class-type)
  (check-deferred
   (lambda ()
     (type:type-signature-specs
      (static-type environment 'DeferredProtocol001)
      environment))
   'protocol-type)

  (define implementation-calls 0)
  (define interface
    (make-host-interface
     'DeferredHost001
     (list
      (make-host-method
       'touch
       '()
       'String
       (lambda (_state)
         (set! implementation-calls (add1 implementation-calls))
         "called")))))
  (define state (make-driver))
  (driver-inject-host!
   state 'deferred-host-001 (make-host-receiver interface #f))
  (check-deferred
   (lambda ()
     (type:type-signature-specs
      (static-type
       (driver-type-environment state)
       'deferred-host-001)
      (driver-type-environment state)))
   'host-receiver-type)
  (check-equal? implementation-calls 0))
