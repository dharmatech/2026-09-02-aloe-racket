#lang racket/base

(require rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         (only-in "../aloe/eval.rkt" eval-expr)
         "../aloe/host.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/term.rkt")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (host-crossing-error? interface selector position type)
  (lambda (exception)
    (define message (and (exn? exception) (exn-message exception)))
    (and (exn:fail? exception)
         (not (exn:fail:aloe-host? exception))
         (regexp-match? (regexp (regexp-quote (format "~a" interface)))
                        message)
         (regexp-match? (regexp (regexp-quote (format "~a" selector)))
                        message)
         (regexp-match? (regexp (regexp-quote position)) message)
         (regexp-match? (regexp (regexp-quote (format "~a" type)))
                        message))))

(test-case "declarations admit only the List String compound crossing"
  (check-true
   (host-method?
    (make-host-method
     'names '(String) '(List String) (lambda (_state _path) '()))))
  (check-true
   (host-method?
    (make-host-method
     'count '((List String)) 'Int
     (lambda (_state names) (length names)))))
  (for ([type (in-list '(List
                         (List Int)
                         (List Entry)
                         (List (List String))))])
    (check-exn
     #rx"return-type is not a permitted crossing type"
     (lambda ()
       (make-host-method
        'bad '() type (lambda (_state) '()))))))

(define observed-names-result #f)
(define observed-count-argument #f)

(define names-interface
  (make-host-interface
   'NamesHost
   (list
    (make-host-method
     'names
     '(String)
     '(List String)
     (lambda (_state path)
       (cond
         [(string=? path "empty") '()]
         [(string=? path "dir")
          (define names (list (string-copy "a") (string-copy "b")))
          (set! observed-names-result names)
          names]
         [else '()])))
    (make-host-method
     'count
     '((List String))
     'Int
     (lambda (_state names)
       (set! observed-count-argument names)
       (length names))))))

(define names-receiver (make-host-receiver names-interface #f))

(test-case "direct host sends marshal ordinary Aloe List String values"
  (define state (make-driver))
  (driver-inject-host! state 'host names-receiver)

  (check-equal?
   (driver-type-datum state '(host names "empty"))
   '(List String))
  (check-equal? (driver-eval! state '((host names "empty") len)) 0)
  (check-equal?
   (driver-eval! state '(host count (host names "empty")))
   0)
  (driver-eval! state '(define empty-names (host names "empty")))
  (driver-eval!
   state
   '(define empty-name-rows ((Mirror of empty-names) signatures)))
  (check-equal?
   (aloe-value->string
    (driver-eval! state '(((empty-name-rows rest) first) return)))
   "#<Symbol String>")

  (check-equal?
   (driver-type-datum state '(host count (host names "dir")))
   'Int)
  (driver-eval! state '(define dir-names (host names "dir")))
  (check-equal? (driver-eval! state '(dir-names len)) 2)
  (check-equal? (driver-eval! state '(dir-names first)) "a")
  (check-equal? (driver-eval! state '((dir-names rest) first)) "b")
  (check-true (immutable? (driver-eval! state '(dir-names first))))

  ;; The Aloe result owns frozen strings rather than the mutable host values.
  (string-set! (car observed-names-result) 0 #\z)
  (string-set! (cadr observed-names-result) 0 #\y)
  (check-equal? (driver-eval! state '(dir-names first)) "a")
  (check-equal? (driver-eval! state '((dir-names rest) first)) "b")

  (check-equal? (driver-eval! state '(host count dir-names)) 2)
  (check-true (list? observed-count-argument))
  (check-true (andmap string? observed-count-argument))
  (check-true (andmap immutable? observed-count-argument))
  (check-equal? (driver-eval! state '(host count (host names "dir"))) 2))

(test-case "raw List String argument crossings validate shape and elements"
  (define mutable-input (string-copy "input"))
  (check-equal?
   (host-receiver-send names-receiver 'count (list (list mutable-input)))
   1)
  (check-true (immutable? (car observed-count-argument)))
  (for ([bad-value
         (in-list
          (list "a,b"
                1
                '(1 2)
                '("a" 2)
                (cons "a" "b")
                (vector "a" "b")))])
    (check-exn
     (host-crossing-error?
      'NamesHost 'count "argument 1" '(List String))
     (lambda ()
       (host-receiver-send names-receiver 'count (list bad-value))))))

(test-case "bad List String results fail at the guarded boundary"
  (for ([bad-value
         (in-list
          (list "a,b"
                '(1 2)
                '("a" 2)
                (cons "a" "b")
                (vector "a" "b")))])
    (define receiver
      (make-host-receiver
       (make-host-interface
        'BadNames
        (list
         (make-host-method
          'names '(String) '(List String)
          (lambda (_state _path) bad-value))))
       #f))
    (check-exn
     (host-crossing-error?
      'BadNames 'names "result" '(List String))
     (lambda ()
       (host-receiver-send receiver 'names '("dir"))))))

(test-case "checker rejects nonmatching host arguments"
  (define state (make-driver))
  (driver-inject-host! state 'host names-receiver)
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(host names 1))))
  (check-exn
   exn:fail:aloe-type?
   (lambda ()
     (driver-eval! state '(host count (List of 1 2)))))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(host count "a,b")))))

(test-case "host reflection reifies and invokes the compound return type"
  (define state (make-driver))
  (driver-inject-host! state 'host names-receiver)
  (driver-eval! state '(define host-mirror (Mirror of host)))
  (driver-eval! state '(define host-rows (host-mirror signatures)))
  (driver-eval! state '(define names-row (host-rows first)))
  (driver-eval! state '(define count-row ((host-rows rest) first)))

  (check-equal?
   (aloe-value->string (driver-eval! state '(names-row return)))
   "#<List #<Symbol List> #<Symbol String>>")
  (check-equal?
   (aloe-value->string
    (driver-eval! state '((count-row params) first)))
   "#<List #<Symbol List> #<Symbol String>>")
  (check-equal?
   (driver-eval!
    state
    '(host-mirror invoke count-row (host names "dir")))
   2)

  ;; Mirror.invoke deliberately erases its static result type, so exercise the
  ;; returned value through the evaluator just as the reflection checkpoints
  ;; exercise other exact-row results.
  (define reflected-call
    '(host-mirror invoke names-row "dir"))
  (check-equal?
   (aloe-value->string (driver-eval! state reflected-call))
   "#<List \"a\" \"b\">")
  (check-equal?
   (eval-expr
    (parse-datum `(,reflected-call len))
    (driver-runtime-environment state))
   2)
  (check-equal?
   (eval-expr
    (parse-datum `(,reflected-call first))
    (driver-runtime-environment state))
   "a"))

(test-case "Term remains scalar-only and optional"
  (define default-state (make-driver))
  (check-false
   (env-bound? (driver-runtime-environment default-state) 'term))
  (check-false
   (type-environment-bound?
    (driver-type-environment default-state) 'term))

  (define output (open-output-string))
  (define term-state (make-driver))
  (driver-inject-host!
   term-state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal?
   (driver-eval! term-state '(term write-line "sealed"))
   "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
