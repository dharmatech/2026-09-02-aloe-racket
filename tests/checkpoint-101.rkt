#lang racket/base

(require racket/list
         rackunit
         "../aloe/driver.rkt"
         (only-in "../aloe/env.rkt" env-bound?)
         "../aloe/host.rkt"
         "../aloe/parse.rkt"
         (only-in "../aloe/type.rkt"
                  exn:fail:aloe-type?
                  type-environment-bound?
                  type-of
                  type->datum)
         "../host/racket/fs.rkt"
         "../host/racket/term.rkt")

(define nodes
  (hash
   "/cwd" 'directory
   "/cwd/a.txt" 'file
   "/cwd/dir" 'directory
   "/cwd/link" 'symlink
   "/cwd/pipe" "fifo"))

(define (driver-type-datum state datum)
  (type->datum
   (type-of
    (parse-datum datum)
    (driver-type-environment state))))

(define (host-failure? interface selector)
  (lambda (exception)
    (and (exn:fail:aloe-host? exception)
         (regexp-match?
          (regexp (regexp-quote (symbol->string interface)))
          (exn-message exception))
         (regexp-match?
          (regexp (regexp-quote (symbol->string selector)))
          (exn-message exception)))))

(test-case "filesystem host interface has one locked nominal identity"
  (check-equal?
   (map host-method-selector (host-interface-methods fs-interface))
   '(current resolve child root? parent name kind names))
  (define first-double (make-fs-double "/cwd" nodes))
  (define second-double (make-fs-double "/other" (hash)))
  (check-eq? (host-receiver-interface first-double) fs-interface)
  (check-eq? (host-receiver-interface second-double) fs-interface)
  (check-eq? (host-receiver-interface first-double)
             (host-receiver-interface second-double)))

(test-case "fresh drivers remain capability-free"
  (define state (make-driver))
  (for ([name (in-list '(fs-host term))])
    (check-false (env-bound? (driver-runtime-environment state) name))
    (check-false
     (type-environment-bound? (driver-type-environment state) name)))
  (check-equal? (driver-eval! state '((List of 1 2 3) len)) 3))

(test-case "filesystem double resolves and decomposes POSIX paths"
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))

  (for ([datum+expected
         (in-list
          '(((fs-host current) "/cwd")
            ((fs-host resolve "/tmp/a/../b") "/tmp/b")
            ((fs-host resolve "/tmp/a/") "/tmp/a")
            ((fs-host resolve "/tmp//a") "/tmp/a")
            ((fs-host resolve ".") "/cwd")
            ((fs-host resolve "x") "/cwd/x")
            ((fs-host resolve "a\\b") "/cwd/a\\b")
            ((fs-host resolve "/") "/")
            ((fs-host child "/tmp" "a") "/tmp/a")
            ((fs-host child "/tmp/" "a") "/tmp/a")
            ((fs-host child "/tmp" ".") "/tmp")
            ((fs-host child "/tmp/a" "..") "/tmp")
            ((fs-host child "/" "..") "/")
            ((fs-host child "/" "a") "/a")
            ((fs-host child "dir" "x") "/cwd/dir/x")
            ((fs-host root? "/") #t)
            ((fs-host root? "/tmp") #f)
            ((fs-host root? "/tmp/..") #t)
            ((fs-host parent "/tmp/a") "/tmp")
            ((fs-host parent "/tmp") "/")
            ((fs-host parent "/") "/")
            ((fs-host name "/tmp/a") "a")
            ((fs-host name "/tmp") "tmp")
            ((fs-host name "/") "")))])
    (check-equal?
     (driver-eval! state (first datum+expected))
     (second datum+expected)))

  (for ([component (in-list '("" "a/b"))])
    (check-exn
     (host-failure? 'FsHost 'child)
     (lambda ()
       (driver-eval! state `(fs-host child "/cwd" ,component))))))

(test-case "filesystem double classifies and lists only planted nodes"
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))

  (check-equal? (driver-type-datum state '(fs-host current)) 'String)
  (check-equal? (driver-type-datum state '(fs-host root? "/")) 'Bool)
  (check-equal?
   (driver-type-datum state '(fs-host names "/cwd"))
   '(List String))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(fs-host current 1))))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(fs-host kind 1))))
  (check-exn
   #rx"unbound symbol: FsHost"
   (lambda ()
     (driver-eval!
      state
      '(define-class HostHolder
         (fields (value FsHost))
         (methods)))))

  (for ([datum+expected
         (in-list
          '(((fs-host kind "/cwd") "directory")
            ((fs-host kind "/cwd/a.txt") "file")
            ((fs-host kind "dir") "directory")
            ((fs-host kind "/cwd/link") "symlink")
            ((fs-host kind "/cwd/pipe") "fifo")
            ((fs-host kind "/cwd/nope") "missing")))])
    (check-equal?
     (driver-eval! state (first datum+expected))
     (second datum+expected)))

  (driver-eval! state '(define cwd-names (fs-host names "/cwd")))
  (check-equal? (driver-eval! state '(cwd-names len)) 4)
  (check-equal? (driver-eval! state '(cwd-names first)) "a.txt")
  (check-equal? (driver-eval! state '((cwd-names rest) first)) "dir")
  (check-equal?
   (driver-eval! state '(((cwd-names rest) rest) first))
   "link")
  (check-equal?
   (driver-eval! state '((((cwd-names rest) rest) rest) first))
   "pipe")
  (check-equal? (driver-eval! state '((fs-host names "/cwd/dir") len)) 0)

  (define implied-state (make-driver))
  (driver-inject-host!
   implied-state
   'fs-host
   (make-fs-double
    "/cwd"
    (hash "/cwd" 'directory
          "/cwd/deep/item" 'file
          "/cwd/." 'file
          "/cwd/.." 'file)))
  (check-equal? (driver-eval! implied-state '((fs-host names "/cwd") len)) 1)
  (check-equal?
   (driver-eval! implied-state '((fs-host names "/cwd") first))
   "deep")

  (for ([path (in-list '("/cwd/nope" "/cwd/a.txt" "/cwd/link"))])
    (check-exn
     (host-failure? 'FsHost 'names)
     (lambda () (driver-eval! state `(fs-host names ,path))))))

(test-case "filesystem and terminal capabilities coexist without defaults"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host! state 'fs-host (make-fs-double "/cwd" nodes))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(fs-host current)) "/cwd")
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))

(test-case "Term remains independently injectable and sealed"
  (define output (open-output-string))
  (define state (make-driver))
  (driver-inject-host!
   state 'term (make-term-receiver output (lambda () "unused")))
  (check-equal? (driver-eval! state '(term write-line "sealed")) "sealed")
  (check-equal? (get-output-string output) "sealed\r\n"))
