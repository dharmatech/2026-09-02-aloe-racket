#lang racket/base

(require rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/env.rkt" env-bound?)
         "../../aloe/host.rkt"
         "../../aloe/parse.rkt"
         (only-in "../../aloe/type.rkt"
                  type-environment-bound?
                  type-of
                  type->datum)
         "../../host/racket/term.rkt")

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (make-term-driver receiver)
  (define state (make-driver))
  (driver-inject-host! state 'term receiver)
  state)

(define (make-tracked-output)
  (define events '())
  (define output
    (make-output-port
     'tracked-output
     always-evt
     (lambda (bytes start end _non-block? _breakable?)
       (set! events
             (cons
              (if (= start end)
                  'flush
                  (subbytes bytes start end))
              events))
       (- end start))
     void))
  (values output (lambda () (reverse events))))

(test-case "Term has the exact five-row production descriptor"
  (define methods (host-interface-methods term-interface))
  (check-eq? (host-interface-name term-interface) 'Term)
  (check-equal?
   (map host-method-selector methods)
   '(read-key write-line write columns rows))
  (check-equal?
   (map host-method-parameter-types methods)
   '(() (String) (String) () ()))
  (check-equal?
   (map host-method-return-type methods)
   '(String String String Int Int)))

(test-case "Term injection supplies checker types but remains optional"
  (define default-state (make-driver))
  (check-false
   (env-bound? (driver-runtime-environment default-state) 'term))
  (check-false
   (type-environment-bound?
    (driver-type-environment default-state)
    'term))

  (define state
    (make-term-driver
     (make-term-receiver
      (open-output-string)
      (lambda () "unused")
      (lambda () (values 132 43)))))
  (check-equal?
   (driver-type-datum state '(term write "frame"))
   'String)
  (check-equal?
   (driver-type-datum state '(term write-line "line"))
   'String)
  (check-equal? (driver-type-datum state '(term columns)) 'Int)
  (check-equal? (driver-type-datum state '(term rows)) 'Int))

(test-case "write appends nothing and returns each String"
  (define output (open-output-string))
  (define state
    (make-term-driver
     (make-term-receiver output (lambda () "unused"))))
  (check-equal? (driver-eval! state '(term write "ab")) "ab")
  (check-equal? (driver-eval! state '(term write "c")) "c")
  (check-equal? (get-output-string output) "abc"))

(test-case "write-line retains exact CRLF output and return value"
  (define output (open-output-string))
  (define state
    (make-term-driver
     (make-term-receiver output (lambda () "unused"))))
  (check-equal?
   (driver-eval! state '(term write-line "sealed"))
   "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))

(test-case "write flushes after display, including an empty String"
  (define-values (output events) (make-tracked-output))
  (define state
    (make-term-driver
     (make-term-receiver output (lambda () "unused"))))
  (check-equal? (driver-eval! state '(term write "frame")) "frame")
  (check-equal? (events) (list #"frame" 'flush))
  (check-equal? (driver-eval! state '(term write "")) "")
  (check-equal? (events) (list #"frame" 'flush 'flush)))

(test-case "write-line still flushes after its CRLF"
  (define-values (output events) (make-tracked-output))
  (define state
    (make-term-driver
     (make-term-receiver output (lambda () "unused"))))
  (check-equal?
   (driver-eval! state '(term write-line "hi"))
   "hi")
  (check-equal? (events) (list #"hi" #"\r\n" 'flush)))

(test-case "the default size source reports 80 columns by 24 rows"
  (define state
    (make-term-driver
     (make-term-receiver
      (open-output-string)
      (lambda () "unused"))))
  (check-equal? (driver-eval! state '(term columns)) 80)
  (check-equal? (driver-eval! state '(term rows)) 24))

(test-case "each size selector obtains one fresh ordered pair"
  (define calls 0)
  (define state
    (make-term-driver
     (make-term-receiver
      (open-output-string)
      (lambda () "unused")
      (lambda ()
        (set! calls (add1 calls))
        (values 132 43)))))
  (check-equal? calls 0)
  (check-equal? (driver-eval! state '(term columns)) 132)
  (check-equal? calls 1)
  (check-equal? (driver-eval! state '(term rows)) 43)
  (check-equal? calls 2))

(define bad-size-readers
  (list
   (cons "wrong value count" (lambda () 132))
   (cons "non-exact-integer component" (lambda () (values 132 43.0)))
   (cons "zero component" (lambda () (values 132 0)))
   (cons "negative component" (lambda () (values -1 43)))
   (cons "ordinary failure" (lambda () (error 'size "unavailable")))))

(for ([fixture (in-list bad-size-readers)])
  (test-case
   (format "~a falls back as a whole pair" (car fixture))
   (define state
     (make-term-driver
      (make-term-receiver
       (open-output-string)
       (lambda () "unused")
       (cdr fixture))))
   (check-equal? (driver-eval! state '(term columns)) 80)
   (check-equal? (driver-eval! state '(term rows)) 24)))

(test-case "input, output, and size dependencies remain separate"
  (define key-calls 0)
  (define size-calls 0)
  (define output (open-output-string))
  (define state
    (make-term-driver
     (make-term-receiver
      output
      (lambda ()
        (set! key-calls (add1 key-calls))
        "left")
      (lambda ()
        (set! size-calls (add1 size-calls))
        (values 132 43)))))
  (check-equal? (driver-eval! state '(term write "x")) "x")
  (check-equal? (driver-eval! state '(term write-line "y")) "y")
  (check-equal? key-calls 0)
  (check-equal? size-calls 0)
  (check-equal? (driver-eval! state '(term columns)) 132)
  (check-equal? (driver-eval! state '(term rows)) 43)
  (check-equal? key-calls 0)
  (check-equal? size-calls 2)
  (check-equal? (get-output-string output) "xy\r\n")
  (check-equal? (driver-eval! state '(term read-key)) "left")
  (check-equal? key-calls 1)
  (check-equal? size-calls 2)
  (check-equal? (get-output-string output) "xy\r\n"))

(test-case "zero-, one-, and two-argument receiver calls remain valid"
  (check-true (host-receiver? (make-term-receiver)))
  (check-true
   (host-receiver? (make-term-receiver (open-output-string))))
  (define two-argument-receiver
    (make-term-receiver
     (open-output-string)
     (lambda () "left")))
  (check-true (host-receiver? two-argument-receiver))
  (check-equal?
   (host-receiver-send two-argument-receiver 'read-key '())
   "left"))
