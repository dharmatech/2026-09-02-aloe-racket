#lang racket/base

(require racket/list
         rackunit
         "../../../aloe/driver.rkt"
         "../../../aloe/host.rkt"
         "../../../aloe/parse.rkt"
         "../../../aloe/signature-catalog.rkt"
         "../../../aloe/signature.rkt"
         "../../../aloe/symbol.rkt"
         (prefix-in type: "../../../aloe/type.rkt"))

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

(define (mirror-messages state subject)
  (define messages-expression
    (list (list 'Mirror 'of subject) 'messages))
  (define count
    (driver-eval! state (list messages-expression 'len)))
  (for/list ([index (in-range count)])
    (string->symbol
     (driver-eval!
      state
      (list
       (list-element-expression messages-expression index)
       'name)))))

(define (install! state forms)
  (for ([form (in-list forms)])
    (check-true (void? (driver-eval! state form)))))

(define declaration-forms
  '((define-class (CatalogInner002 T)
      (fields
        (value T))
      (methods))
    (define-class (CatalogLegacy002 T)
      (fields
        (direct T)
        (items (List T))
        (nested (CatalogInner002 T))
        (callback (-> T (List T))))
      (methods
        (nested-value
          (value (CatalogInner002 (List T)))
          (CatalogInner002 (List T))
          value)
        (transform
          (function (-> (List T) (CatalogInner002 T)))
          (-> T (CatalogInner002 (List T)))
          self)
        (local
          (type A)
          (function (-> A T))
          (-> (CatalogInner002 A) (List T))
          self)
        (pick (other Int) Int other)
        (pick (other String) String other)))
    (define-class (CatalogOption002 T)
      (constructors
        (None (fields))
        (Some (fields (value T))))
      (methods
        (present? () Bool
          (self case
            (None () #f)
            (Some (value) #t)))
        (or (fallback T) T
          (self case
            (None () fallback)
            (Some (value) value)))))))

(define legacy-subject
  '(CatalogLegacy002
    new
    10
    (List of 20 30)
    (CatalogInner002 new 40)
    (fn (value) (List of value))))

(define expected-legacy-rows
  (triples->specs
   '((direct () Int)
     (items () (List Int))
     (nested () (CatalogInner002 Int))
     (callback () (-> Int (List Int)))
     (nested-value
       ((CatalogInner002 (List Int)))
       (CatalogInner002 (List Int)))
     (transform
       ((-> (List Int) (CatalogInner002 Int)))
       (-> Int (CatalogInner002 (List Int))))
     (local
       ((-> A Int))
       (-> (CatalogInner002 A) (List Int)))
     (pick (Int) Int)
     (pick (String) String))))

(test-case "generic legacy instances recursively substitute ordered declarations"
  (define state (make-driver))
  (install! state declaration-forms)
  (define environment (driver-type-environment state))
  (check-equal?
   (static-signatures environment legacy-subject)
   expected-legacy-rows)
  (check-equal?
   (mirror-signatures state legacy-subject)
   expected-legacy-rows)
  (check-equal?
   (static-signatures environment 'CatalogLegacy002)
   (triples->specs
    '((new
        (T (List T) (CatalogInner002 T) (-> T (List T)))
        (CatalogLegacy002 T)))))
  (check-equal?
   (static-signatures environment 'CatalogLegacy002)
   (mirror-signatures state 'CatalogLegacy002))
  (check-equal?
   (mirror-messages state legacy-subject)
   '(direct items nested callback nested-value transform local pick))
  (check-equal? (driver-eval! state (list legacy-subject 'pick 7)) 7)
  (check-equal?
   (driver-eval! state (list legacy-subject 'pick "seven"))
   "seven"))

(test-case "explicit constructor class objects and instances stay distinct"
  (define state (make-driver))
  (install! state declaration-forms)
  (define environment (driver-type-environment state))
  (define constructor-rows
    (triples->specs
     '((None () (CatalogOption002 T))
       (Some (T) (CatalogOption002 T)))))
  (check-equal?
   (static-signatures environment 'CatalogOption002)
   constructor-rows)
  (check-equal?
   (mirror-signatures state 'CatalogOption002)
   constructor-rows)
  (define instance-rows
    (triples->specs
     '((present? () Bool)
       (or (Int) Int))))
  (check-equal?
   (static-signatures environment '(CatalogOption002 Some 10))
   instance-rows)
  (check-equal?
   (mirror-signatures state '(CatalogOption002 Some 10))
   instance-rows)
  (for ([forbidden (in-list '(None Some new value))])
    (check-false
     (member forbidden
             (map signature-spec-selector instance-rows))))
  (check-true
   (driver-eval! state '((CatalogOption002 Some "value") present?)))
  (check-equal?
   (driver-eval!
    state
    '((CatalogOption002 Some "value") case
       (None () "missing")
       (Some (value) value)))
   "value"))

(define installed-method
  '(define-methods CatalogLegacy002
     (methods
       (catalog-tail-002 () T (self direct)))))

(test-case "define-methods is visible once without a cached catalog"
  (define state (make-driver))
  (install! state declaration-forms)
  (define environment (driver-type-environment state))
  (define before
    (static-signatures environment legacy-subject))
  (check-equal? before expected-legacy-rows)
  (check-true (void? (driver-eval! state installed-method)))
  (define after
    (static-signatures environment legacy-subject))
  (check-equal? (drop-right after 1) before)
  (check-equal?
   (last after)
   (signature-spec 'catalog-tail-002 '() 'Int))
  (check-equal?
   (length
    (filter
     (lambda (row)
       (eq? (signature-spec-selector row) 'catalog-tail-002))
     after))
   1)
  (check-equal? after (mirror-signatures state legacy-subject))
  (check-equal?
   (driver-eval! state (list legacy-subject 'catalog-tail-002))
   10))

(define protocol-forms
  '((define-protocol CatalogProtocol002
      (label () String)
      (combine (other Int) String)
      (combine (other String) String))
    (define-protocol CatalogMarker002)
    (define-class CatalogConcrete002 CatalogProtocol002
      (fields
        (name String))
      (methods
        (label () String (self name))
        (combine (other Int) String (self name))
        (combine (other String) String (self name))))
    (define-class CatalogProtocolBox002
      (fields
        (value CatalogProtocol002))
      (methods))))

(define protocol-value
  '((CatalogProtocolBox002
     new
     (CatalogConcrete002 new "concrete"))
    value))

(test-case "protocol catalogs preserve contracts and the erasure exception"
  (define state (make-driver))
  (install! state protocol-forms)
  (define environment (driver-type-environment state))
  (define protocol-rows
    (triples->specs
     '((label () String)
       (combine (Int) String)
       (combine (String) String))))
  (check-equal?
   (static-signatures environment 'CatalogProtocol002)
   protocol-rows)
  (check-equal?
   (static-signatures environment 'CatalogMarker002)
   '())
  (check-equal?
   (static-signatures environment protocol-value)
   protocol-rows)
  (define concrete-rows
    (triples->specs
     '((name () String)
       (label () String)
       (combine (Int) String)
       (combine (String) String))))
  (check-equal?
   (mirror-signatures state protocol-value)
   concrete-rows)
  (check-not-equal? protocol-rows concrete-rows)
  (check-equal?
   (driver-eval! state (list protocol-value 'combine 1))
   "concrete")
  (check-equal?
   (driver-eval! state (list protocol-value 'combine "other"))
   "concrete"))

(define (make-effect-method selector parameters return counter result)
  (make-host-method
   selector
   parameters
   return
   (case (length parameters)
     [(0)
      (lambda (_state)
        (set-box! counter (add1 (unbox counter)))
        result)]
     [(1)
      (lambda (_state _argument)
        (set-box! counter (add1 (unbox counter)))
        result)])))

(test-case "direct host catalogs use the carried nominal interface"
  (define calls (box 0))
  (define full-interface
    (make-host-interface
     'CatalogHost002
     (list
      (make-effect-method 'scale '(Int) 'Int calls 12)
      (make-effect-method 'flip '(Bool) 'Bool calls #t)
      (make-effect-method 'greet '(String) 'String calls "hello")
      (make-effect-method
       'names '((List String)) '(List String) calls '("a" "b")))))
  (define different-interface
    (make-host-interface
     'CatalogHost002
     (list
      (make-effect-method 'different '() 'String calls "different"))))
  (define equal-interface
    (make-host-interface
     'CatalogHost002
     (list
      (make-effect-method 'scale '(Int) 'Int calls 99)
      (make-effect-method 'flip '(Bool) 'Bool calls #f)
      (make-effect-method 'greet '(String) 'String calls "other")
      (make-effect-method
       'names '((List String)) '(List String) calls '("other")))))
  (define state (make-driver))
  (driver-inject-host!
   state 'catalog-host-002
   (make-host-receiver full-interface 'full))
  (driver-inject-host!
   state 'different-host-002
   (make-host-receiver different-interface 'different))
  (driver-inject-host!
   state 'equal-host-002
   (make-host-receiver equal-interface 'equal))
  (define environment (driver-type-environment state))
  (define expected
    (triples->specs
     '((scale (Int) Int)
       (flip (Bool) Bool)
       (greet (String) String)
       (names ((List String)) (List String)))))
  (define full-type (static-type environment 'catalog-host-002))
  (define different-type (static-type environment 'different-host-002))
  (define equal-type (static-type environment 'equal-host-002))
  (check-false (equal? full-type different-type))
  (check-false (equal? full-type equal-type))
  (check-equal? (type:type->datum full-type)
                (type:type->datum different-type))
  (check-equal?
   (type:type-signature-specs full-type environment)
   expected)
  (check-equal?
   (type:type-signature-specs different-type environment)
   (triples->specs '((different () String))))
  (check-equal?
   (type:type-signature-specs equal-type environment)
   expected)
  (check-equal?
   (mirror-signatures state 'catalog-host-002)
   expected)
  (check-equal? (unbox calls) 0)
  (check-equal?
   (driver-eval! state '(catalog-host-002 scale 7))
   12)
  (check-equal? (unbox calls) 1)
  (check-exn
   #rx"expects Int"
   (lambda ()
     (driver-eval! state '(catalog-host-002 scale "wrong"))))
  (check-equal? (unbox calls) 1)
  (define scale-row-expression
    (list-element-expression
     '((Mirror of catalog-host-002) signatures)
     0))
  (check-equal?
   (driver-eval!
    state
    `((Mirror of catalog-host-002) invoke ,scale-row-expression 8))
   12)
  (check-equal? (unbox calls) 2))

(test-case "nested generic host types retain the named static exception"
  (define calls (box 0))
  (define interface
    (make-host-interface
     'CatalogNestedHost002
     (list
      (make-effect-method 'ready? '() 'Bool calls #t))))
  (define state (make-driver))
  (driver-inject-host!
   state 'nested-host-002
   (make-host-receiver interface #f))
  (install!
   state
   '((define-class (CatalogHostBox002 T)
       (fields
         (item T))
       (methods
         (replace (other T) T other)))))
  (define environment (driver-type-environment state))
  (define subject '(CatalogHostBox002 new nested-host-002))
  (define static-rows
    (static-signatures environment subject))
  (define runtime-rows
    (mirror-signatures state subject))
  (check-equal?
   static-rows
   (triples->specs
    '((item () CatalogNestedHost002)
      (replace (CatalogNestedHost002) CatalogNestedHost002))))
  (check-equal?
   runtime-rows
   (triples->specs
    '((item () Object)
      (replace (Object) Object))))
  (check-equal?
   (map signature-spec-selector static-rows)
   (map signature-spec-selector runtime-rows))
  (check-equal?
   (map (lambda (row)
          (length (signature-spec-parameters row)))
        static-rows)
   (map (lambda (row)
          (length (signature-spec-parameters row)))
        runtime-rows))
  (check-equal? (unbox calls) 0))

(test-case "invalid arguments still use the public query contract"
  (define environment (type:make-type-environment))
  (check-exn
   #rx"type-signature-specs: contract violation.*checker type"
   (lambda ()
     (type:type-signature-specs 'not-a-checker-type environment)))
  (check-exn
   #rx"type-signature-specs: contract violation.*type-environment"
   (lambda ()
     (type:type-signature-specs (type:int-type) 'not-an-environment))))
