#lang racket/base

(require rackunit
         racket/file
         racket/list
         "../../aloe/expression-query.rkt"
         "../../aloe/completion-query.rkt")

(define context-source
  "(define-class Context\n  (fields (items (List String)) (measure (-> String Int)))\n  (methods))\n")

(define string-triples
  '((= (String) Bool)
    (append (String) String)
    (len () Int)
    (take (Int) String)
    (drop (Int) String)
    (split-lines () (List String))
    (joined-with ((List String) String (List String)) String)
    (find (String Int) (Option Int))
    (starts-with? (String) Bool)))

(define (position-of source text)
  (define match (regexp-match-positions (regexp (regexp-quote text)) source))
  (unless match (error 'position-of "missing text ~s" text))
  (add1 (caar match)))

(define (remove-cursor marked-source)
  (define markers (regexp-match-positions* #rx"[|]" marked-source))
  (unless (= (length markers) 1)
    (error 'remove-cursor "expected one cursor"))
  (define index (caar markers))
  (values (string-append (substring marked-source 0 index)
                         (substring marked-source (add1 index)))
          (add1 index)))

(define (write-source! path source)
  (call-with-output-file path (lambda (output) (display source output))
    #:exists 'truncate))

(define (with-temporary-directory procedure)
  (define directory (make-temporary-file "construction-editor-~a" 'directory "/tmp"))
  (dynamic-wind void
                (lambda () (procedure directory))
                (lambda () (delete-directory/files directory))))

(define (expected-location source path start span)
  (define preceding (substring source 0 (sub1 start)))
  (define newlines (regexp-match-positions* #rx"\n" preceding))
  (srcloc path
          (add1 (length newlines))
          (- (string-length preceding) (if (null? newlines) 0 (cdr (last newlines))))
          start span))

(define (check-hover source path text type)
  (define start (position-of source text))
  (define result (query-expression-at path start))
  (check-true (expression-query-result? result))
  (check-equal? (expression-query-result-type result) type)
  (check-equal? (expression-query-result-location result)
                (expected-location source path start (string-length text)))
  (void))

(define (check-string-completions source position start span [path #f])
  (define items (query-selector-completions source position #:source-path path))
  (check-equal?
   items
   (for/list ([triple (in-list string-triples)])
     (define label (symbol->string (first triple)))
     (selector-completion-item label
                               (format "~s -> ~s" (second triple) (third triple))
                               label start span)))
  (for ([item (in-list items)])
    (check-equal? (substring source (sub1 (selector-completion-item-replacement-start item))
                             (+ (sub1 (selector-completion-item-replacement-start item))
                                (selector-completion-item-replacement-span item)))
                  "len")))

(test-case "hover and completion preserve field context in both orders and methods"
  (with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "context.aloe"))
     (for* ([swapped? (in-list '(#f #t))]
            [method? (in-list '(#f #t))])
       (define pairs
         (if swapped?
             "(measure (fn (s) (s len)))\n  (items (List empty))"
             "(items (List empty))\n  (measure (fn (s) (s len)))"))
       (define construction (string-append "(Context new*\n  " pairs ")"))
       ;; Selecting a generic method body must trigger its contextual check.
       (define source
         (string-append
          context-source
          (if method?
              (string-append
               "(define-class (Builder T) (fields (value T))\n"
               "  (methods (build () Context\n    " construction ")))\n")
              (string-append construction "\n"))))
       (write-source! path source)
       (check-hover source path "(List empty)" '(List String))
       (define s-position (add1 (position-of source "(s len)")))
       (define parameter (query-expression-at path s-position))
       (check-equal? (expression-query-result-type parameter) 'String)
       (check-equal?
        (expression-query-result-signatures parameter)
        (map (lambda (triple) (apply signature-spec triple)) string-triples))
       (check-equal? (expression-query-result-location parameter)
                     (expected-location source path s-position 1))
       (define selector-start (position-of source "len"))
       (check-string-completions source (add1 selector-start) selector-start 3 path)))))

(test-case "expected concrete generic construction supplies editor context"
  (with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "generic.aloe"))
     (define prefix
       (string-append
        "(define-class (Generic T)\n"
        "  (fields (items (List T)) (measure (-> T Int))) (methods))\n"
        "(define-class Holder (fields (box (Generic String))) (methods))\n"))
     (for ([pairs (in-list
                   '("(items (List empty)) (measure (fn (s) (s len)))"
                     "(measure (fn (s) (s len))) (items (List empty))"))])
       (define source (string-append prefix "(Holder new (Generic new* " pairs "))\n"))
       (write-source! path source)
       (check-hover source path "(List empty)" '(List String))
       (define position (add1 (position-of source "(s len)")))
       (check-equal? (expression-query-result-type (query-expression-at path position))
                     'String)
       (define start (position-of source "len"))
       (check-string-completions source start start 3 path)))))

(test-case "ordinary nested value sends retain their own source spans"
  (with-temporary-directory
   (lambda (directory)
     (define path (build-path directory "value.aloe"))
     (define source
       (string-append context-source
                      "(Context new* (measure (fn (s) (s len)))\n"
                      "  (items (List of (\"ab\" append \"cd\"))))\n"))
     (write-source! path source)
     (check-hover source path "(\"ab\" append \"cd\")" 'String))))

(test-case "loads inside labeled values retain source-relative completion policy"
  (with-temporary-directory
   (lambda (directory)
     (define root (build-path directory "unsaved.aloe"))
     (define support (build-path directory "support.aloe"))
     (write-source! support "(define from-load 99)\n")
     (for ([pairs (in-list
                   '("(items (let ((loaded (load \"support.aloe\"))) (List empty)))\n  (measure (fn (s) (s le|n)))"
                     "(measure (fn (s) (s le|n)))\n  (items (let ((loaded (load \"support.aloe\"))) (List empty)))"))])
       (define-values (source position)
         (remove-cursor (string-append context-source "(Context new*\n  " pairs ")")))
       (define start (position-of source "len"))
       (check-string-completions source position start 3 root)
       ;; The load can resolve from cwd, so absence of a source path is the
       ;; reason for the empty completion result, rather than a missing file.
       (parameterize ([current-directory directory])
         (check-equal? (query-selector-completions source position) '()))
       (check-false (file-exists? root))))))

(test-case "labels and reserved new* have no selector completion"
  (for ([tail (in-list
               '("(Context new* (ite|ms (List empty)) (measure (fn (s) (s len))))"
                 "(Context new* (measure| (fn (s) (s len))) (items (List empty)))"
                 "(Context ne|w* (items (List empty)) (measure (fn (s) (s len))))"))])
    (define-values (source position) (remove-cursor (string-append context-source tail)))
    (check-equal? (query-selector-completions source position) '())))
