#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path gel-loop-path "../gel/loop.aloe")
(define-runtime-path point-path "../examples/point.aloe")

(define checker-environment (make-type-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string gel-loop-path))
  checker-environment))
(void
 (typecheck-source
  (format "(load ~s)" (path->string point-path))
  checker-environment))

;; Named menu overloads remain independently polymorphic and TOS rendering
;; joins them on the same GelText service.
(check-equal?
 (type->datum
  (typecheck-source
   #<<ALOE
(define int-menu-82 (gel-text menu 10))
(define point-menu-82 (gel-text menu (Point new 10 20)))
(define mirror-menu-82 (gel-text menu (Mirror of (Point new 10 20))))
(define idle-menu-82
  (gel-text menu
    (GelStep new (gel-empty-stack push 10)
      #f (List empty) 0 #f)))
(gel-text tos (gel-empty-stack push 10))
ALOE
   checker-environment))
 'String)

;; The renderer has no function-shaped interface, and all former names are
;; absent from the loaded environment.
(check-exn
 exn:fail:aloe-type?
 (lambda ()
   (typecheck-source "(gel-text call 10)" checker-environment)))
(for ([name '(GelMenuText gel-menu-text GelTosText gel-tos-text)])
  (check-exn
   (regexp (format "unbound symbol: ~a" name))
   (lambda ()
     (typecheck-source (symbol->string name) checker-environment))))

(define environment (make-top-level-env))
(void
 (eval-source
  (format "(load ~s)" (path->string gel-loop-path))
  environment))
(void
 (eval-source
  (format "(load ~s)" (path->string point-path))
  environment))

;; TOS text remains the exact prefix plus the top mirror's raw presentation.
(check-equal?
 (eval-source "(gel-text tos (gel-empty-stack push 10))" environment)
 "TOS: 10")
(check-equal?
 (eval-source
  "(gel-text tos (gel-empty-stack push (Point new 10 20)))"
  environment)
 "TOS: #<Point 10 20>")

(void (eval-source "(define point-82 (Point new 10 20))" environment))
(void (eval-source "(define point-mirror-82 (Mirror of point-82))" environment))
(void
 (eval-source
  #<<ALOE
(define point-stack-82
  ((gel-empty-stack push (Point new 1 2)) push point-82))
(define idle-state-82
  (GelStep new point-stack-82 #f (List empty) 0 #f))
ALOE
  environment))

;; Ordinary, exact-Mirror, and idle-state menus preserve identical bytes.
(define point-menu (eval-source "(gel-text menu point-82)" environment))
(check-equal? point-menu
              (eval-source "(gel-text menu point-mirror-82)" environment))
(check-equal? point-menu
              (eval-source "(gel-text menu idle-state-82)" environment))
(check-regexp-match #rx"[1-9][0-9]*  x  0\r\n" point-menu)
(check-false (regexp-match? #rx"  subject  " point-menu))

(define (bind-row! name rows selector arity)
  (eval-source
   (format
    (string-append
     "(define ~a\n"
     "  (~a fold\n"
     "    (~a first)\n"
     "    (fn (found row)\n"
     "      (if (((row selector) name) = ~s)\n"
     "          (if ((row arity) = ~a) row found)\n"
     "          found))))")
    name
    rows
    rows
    selector
    arity)
   environment))

;; Pending typed-pick rendering keeps its exact header and compact pick lines.
(void (eval-source "(define point-rows-82 (gel-rows of point-82))"
                   environment))
(void (bind-row! "point-plus-row-82" "point-rows-82" "+" 1))
(void
 (eval-source
  #<<ALOE
(define point-pending-82
  (GelStep new point-stack-82
    #f (List of point-plus-row-82) 0 #f))
ALOE
  environment))
(check-equal?
 (eval-source "(gel-text menu point-pending-82)" environment)
 (string-append
  "pending +  #<List #<Symbol Point> #<Symbol Int>>\r\n"
  "1  #<Point 10 20>\r\n"
  "2  #<Point 1 2>\r\n"))

;; Pending Int rendering still distinguishes empty and accumulated input.
(void (eval-source "(define int-rows-82 (gel-rows of 10))" environment))
(void (bind-row! "int-plus-row-82" "int-rows-82" "+" 1))
(void
 (eval-source
  #<<ALOE
(define int-pending-82
  (GelStep new (gel-empty-stack push 10)
    #f (List of int-plus-row-82) 0 #f))
(define int-typed-82 (int-pending-82 handle-key "2"))
ALOE
  environment))
(check-equal? (eval-source "(gel-text menu int-pending-82)" environment)
              "pending +  Int \r\n")
(check-equal? (eval-source "(gel-text menu int-typed-82)" environment)
              "pending +  Int 2\r\n")
