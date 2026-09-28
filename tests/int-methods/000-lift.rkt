#lang racket/base

(require racket/list
         rackunit
         "../../aloe/eval.rkt"
         (prefix-in runtime: "../../aloe/env.rkt")
         "../../aloe/main.rkt"
         "../../aloe/parse.rkt"
         (prefix-in checker: "../../aloe/type.rkt"))

(define methods-source
  #<<ALOE
(define-methods Int
  (methods
    (twice () Int (self + self))
    (triple () Int ((self twice) + self))
    (keep (type U) (value U) U value)
    (text () String "Aloe text")))
ALOE
  )

(define (checked-type source environment)
  (type->datum (typecheck-source source environment)))

(define (raw-eval datum environment)
  (eval-expr (parse-datum datum) environment))

(define (row-source index)
  (format "(~a first)"
          (for/fold ([source "int-rows"]) ([unused (in-range index)])
            (format "(~a rest)" source))))

(define (row-property environment index selector)
  (eval-source
   (format "((~a ~a) name)" (row-source index) selector)
   environment))

(test-case "Int methods typecheck, run, and stay local to their environments"
  (define types (make-type-environment))
  (check-equal? (checked-type "Int" types) '(Class Int))
  (check-equal? (checked-type "3" types) 'Int)
  (check-equal? (checked-type methods-source types) 'Void)
  (check-equal? (checked-type "(3 twice)" types) 'Int)
  (check-equal? (checked-type "(3 triple)" types) 'Int)
  (check-equal? (checked-type "(3 keep #t)" types) 'Bool)
  (check-equal? (checked-type "(3 keep \"x\")" types) 'String)
  (define environment (make-top-level-env))
  (eval-source methods-source environment)
  (check-equal? (eval-source "(3 twice)" environment) 6)
  (check-equal? (eval-source "(3 triple)" environment) 9)
  (check-true (eval-source "(3 keep #t)" environment))
  (check-equal? (eval-source "(3 keep \"x\")" environment) "x")
  (check-equal? (aloe-value->string (eval-source "Int" environment))
                "#<class Int>")
  (check-exn exn:fail:aloe-type?
             (lambda () (checked-type "(3 twice)" (make-type-environment))))
  (check-exn exn:fail?
             (lambda () (raw-eval '(3 twice) (runtime:make-top-level-env))))
  (check-exn exn:fail?
             (lambda () (eval-source "(3 twice)" (make-top-level-env)))))

(test-case "Int methods can call later declarations and capture their environment"
  (define forward-source
    #<<ALOE
(define-methods Int
  (methods
    (ahead () Int (self behind))
    (behind () Int (self + offset))))
ALOE
    )
  (define types (make-type-environment))
  (check-equal? (checked-type "(define offset 5)" types) 'Void)
  (check-equal? (checked-type forward-source types) 'Void)
  (check-equal? (checked-type "(3 ahead)" types) 'Int)
  (define raw (runtime:make-top-level-env))
  (raw-eval '(define offset 5) raw)
  (raw-eval (read (open-input-string forward-source)) raw)
  (define local (runtime:make-local-env raw (list (cons 'offset 99))))
  (check-equal? (raw-eval '(3 ahead) local) 8))

(test-case "Int methods require declared types and enforce argument shapes"
  (define types (make-type-environment))
  (check-exn exn:fail:aloe-type?
             (lambda ()
               (checked-type
                "(define-methods Int (methods (bad (value T) T value)))"
                types)))
  (check-equal? (checked-type methods-source types) 'Void)
  (for ([source (in-list '("(3 twice 1)" "(3 keep)" "(3 keep 1 2)"))])
    (check-exn exn:fail:aloe-type?
               (lambda () (checked-type source types))))
  (define typed-method
    "(define-methods Int (methods (plus (other Int) Int (self + other))))")
  (check-equal? (checked-type typed-method types) 'Void)
  (check-exn exn:fail:aloe-type?
             (lambda () (checked-type "(3 plus \"x\")" types)))
  (define raw (runtime:make-top-level-env))
  (raw-eval (read (open-input-string typed-method)) raw)
  (check-equal? (raw-eval '(3 plus 4) raw) 7)
  (for ([datum (in-list '((3 plus) (3 plus 4 5) (3 plus "x")))])
    (check-exn exn:fail? (lambda () (raw-eval datum raw))))
  (check-equal? (checked-type "(3 + 4)" types) 'Int)
  (check-equal? (raw-eval '(3 + 4) raw) 7)
  (for ([source (in-list '("(3 + 4.0)" "(3 +)"))])
    (check-exn exn:fail:aloe-type?
               (lambda () (checked-type source types))))
  (for ([datum (in-list '((3 + 4.0) (3 +)))])
    (check-exn exn:fail? (lambda () (raw-eval datum raw)))))

(test-case "other primitive targets and Int construction remain invalid"
  (for ([target (in-list '(Float Bool Symbol))])
    (define datum
      `(define-methods ,target (methods (extension () Bool #t))))
    (check-exn exn:fail:aloe-type?
               (lambda ()
                 (checked-type (format "~s" datum)
                               (make-type-environment))))
    (check-exn exn:fail?
               (lambda ()
                 (raw-eval datum (runtime:make-top-level-env)))))
  (check-exn exn:fail:aloe-type?
             (lambda ()
               (checked-type "(Int new 1)" (make-type-environment))))
  (check-exn exn:fail?
             (lambda ()
               (raw-eval '(Int new 1) (runtime:make-top-level-env)))))

(test-case "Int reflection appends exact Aloe rows after the kernel"
  (define types (make-type-environment))
  (check-equal? (checked-type methods-source types) 'Void)
  (define specs
    (checker:type-signature-specs (checker:int-type) types))
  (define selectors (map checker:signature-spec-selector specs))
  (check-equal? selectors
                '(+ - * / < > <= >= = float text min max
                    twice triple keep text))
  (define environment (make-top-level-env))
  (eval-source methods-source environment)
  (eval-source "(define int-mirror (Mirror of 3))" environment)
  (eval-source "(define int-rows (int-mirror signatures))" environment)
  (check-equal? (eval-source "(int-rows len)" environment) (length specs))
  (check-equal? (eval-source "(((Mirror of Int) signatures) len)"
                             environment)
                0)
  (check-equal? (eval-source "((int-mirror messages) len)" environment)
                (length (remove-duplicates selectors)))
  (check-equal?
   (for/list ([index (in-range (length specs))])
     (row-property environment index 'selector))
   (map symbol->string selectors))
  (check-equal?
   (for/list ([index (in-range (length specs))])
     (eval-source (format "((~a params) len)" (row-source index))
                  environment))
   (map (lambda (spec) (length (checker:signature-spec-parameters spec)))
        specs))
  (check-equal?
   (for/list ([index (in-range (length specs))]
              #:when
              (pair? (checker:signature-spec-parameters
                      (list-ref specs index))))
     (aloe-value->string
      (eval-source
       (format "((~a params) first)" (row-source index))
       environment)))
   (for/list ([spec (in-list specs)]
              #:when (pair? (checker:signature-spec-parameters spec)))
     (format "#<Symbol ~a>"
             (car (checker:signature-spec-parameters spec)))))
  (check-equal?
   (for/list ([index (in-range (length specs))])
     (aloe-value->string
      (eval-source (format "(~a return)" (row-source index)) environment)))
   (for/list ([spec (in-list specs)])
     (format "#<Symbol ~a>" (checker:signature-spec-return spec))))
  (check-equal? (eval-source "(3 text)" environment) "3")
  (check-equal? (checked-type "(3 text)" types) 'String)
  (check-equal? (eval-source "(int-mirror invoke (int-rows first) 4)"
                             environment)
                7)
  (check-equal? (eval-source
                 (format "(int-mirror invoke ~a)" (row-source 13))
                 environment)
                6)
  (check-true
   (eval-source
    (format "(int-mirror invoke ~a #t)" (row-source 15))
    environment))
  (check-equal? (eval-source
                 (format "(int-mirror invoke ~a)" (row-source 16))
                 environment)
                "Aloe text"))
