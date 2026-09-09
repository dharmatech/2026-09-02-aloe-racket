#lang racket/base

(require racket/file
         racket/list
         racket/string
         "../../aloe/host.rkt")

(provide fs-interface
         make-fs-double
         make-fs-receiver)

(struct fs-double-state (current nodes))
(struct fs-production-state ())

(define production-state (fs-production-state))

(define (absolute-posix-path? path)
  (string-prefix? path "/"))

;; Normalize lexically so the test double never consults or follows anything
;; on the host filesystem.
(define (normalize-absolute-posix-path path)
  (define components
    (for/fold ([reversed '()])
              ([component (in-list (string-split path "/" #:trim? #f))])
      (cond
        [(or (string=? component "")
             (string=? component "."))
         reversed]
        [(string=? component "..")
         (if (null? reversed) '() (rest reversed))]
        [else
         (cons component reversed)])))
  (if (null? components)
      "/"
      (string-append "/" (string-join (reverse components) "/"))))

(define (production-current-path)
  (define directory (current-directory))
  (define complete-directory
    (if (complete-path? directory)
        directory
        (path->complete-path directory)))
  (normalize-absolute-posix-path (path->string complete-directory)))

(define (state-current-path state)
  (cond
    [(fs-double-state? state) (fs-double-state-current state)]
    [(fs-production-state? state) (production-current-path)]
    [else (error 'fs "unknown filesystem receiver state")]))

(define (resolve-path state path)
  (normalize-absolute-posix-path
   (if (absolute-posix-path? path)
       path
       (string-append (state-current-path state) "/" path))))

(define (fs-current state)
  (state-current-path state))

(define (fs-resolve state path)
  (resolve-path state path))

(define (fs-child state path component)
  (when (or (string=? component "")
            (string-contains? component "/"))
    (error 'fs "child name must be one nonempty POSIX path component"))
  (normalize-absolute-posix-path
   (string-append (resolve-path state path) "/" component)))

(define (fs-root? state path)
  (string=? (resolve-path state path) "/"))

(define (fs-parent state path)
  (define normalized (resolve-path state path))
  (cond
    [(string=? normalized "/") "/"]
    [else
     (define parent-components
       (drop-right (string-split normalized "/") 1))
     (if (null? parent-components)
         "/"
         (string-append "/" (string-join parent-components "/")))]))

(define (fs-name state path)
  (define normalized (resolve-path state path))
  (if (string=? normalized "/")
      ""
      (last (string-split normalized "/"))))

(define (double-kind state path)
  (define kind
    (hash-ref (fs-double-state-nodes state)
              path
              #f))
  (cond
    [(eq? kind 'file) "file"]
    [(eq? kind 'directory) "directory"]
    [(eq? kind 'symlink) "symlink"]
    [(string? kind) kind]
    [else "missing"]))

(define (production-kind path)
  (define kind (file-or-directory-type path #f))
  (cond
    [(not kind) "missing"]
    [(eq? kind 'link) "symlink"]
    [else (symbol->string kind)]))

(define (fs-kind state path)
  (define normalized (resolve-path state path))
  (cond
    [(fs-double-state? state) (double-kind state normalized)]
    [(fs-production-state? state) (production-kind normalized)]
    [else (error 'fs "unknown filesystem receiver state")]))

(define (path-child-name parent candidate)
  (define prefix
    (if (string=? parent "/")
        "/"
        (string-append parent "/")))
  (and (string-prefix? candidate prefix)
       (let* ([remainder (substring candidate (string-length prefix))]
              [parts (string-split remainder "/" #:trim? #f)]
              [name (and (pair? parts) (first parts))])
         (and name
              (not (string=? name ""))
              (not (string=? name "."))
              (not (string=? name ".."))
              name))))

(define (double-names state normalized)
  (define nodes (fs-double-state-nodes state))
  (unless (eq? (hash-ref nodes normalized #f) 'directory)
    (error 'fs "names requires a directory: ~a" normalized))
  (sort
   (remove-duplicates
    (for/list ([candidate (in-hash-keys nodes)]
               #:do [(define name (path-child-name normalized candidate))]
               #:when name)
      name)
    string=?)
   string<?))

(define (production-names state normalized)
  (unless (string=? (fs-kind state normalized) "directory")
    (error 'fs "names requires a directory: ~a" normalized))
  (sort
   (for/list ([candidate (in-list (directory-list normalized))]
              #:do [(define name (path->string candidate))]
              #:unless (or (string=? name ".")
                           (string=? name "..")))
     name)
   string<?))

(define (fs-names state path)
  (define normalized (resolve-path state path))
  (cond
    [(fs-double-state? state) (double-names state normalized)]
    [(fs-production-state? state) (production-names state normalized)]
    [else (error 'fs "unknown filesystem receiver state")]))

(define fs-interface
  (make-host-interface
   'FsHost
   (list
    (make-host-method 'current '() 'String fs-current)
    (make-host-method 'resolve '(String) 'String fs-resolve)
    (make-host-method 'child '(String String) 'String fs-child)
    (make-host-method 'root? '(String) 'Bool fs-root?)
    (make-host-method 'parent '(String) 'String fs-parent)
    (make-host-method 'name '(String) 'String fs-name)
    (make-host-method 'kind '(String) 'String fs-kind)
    (make-host-method 'names '(String) '(List String) fs-names))))

(define (make-fs-double current nodes)
  (unless (and (string? current) (absolute-posix-path? current))
    (raise-argument-error 'make-fs-double "absolute POSIX path string" current))
  (unless (hash? nodes)
    (raise-argument-error 'make-fs-double "hash?" nodes))
  (for ([(path kind) (in-hash nodes)])
    (unless (string? path)
      (raise-arguments-error
       'make-fs-double
       "node table keys must be path strings"
       "path" path))
    (unless (or (memq kind '(file directory symlink)) (string? kind))
      (raise-arguments-error
       'make-fs-double
       "node table values must be file, directory, symlink, or a string"
       "path" path
       "kind" kind)))
  (make-host-receiver
   fs-interface
   (fs-double-state
    (normalize-absolute-posix-path current)
    (for/hash ([(path kind) (in-hash nodes)])
      (values (string->immutable-string path)
              (if (string? kind)
                  (string->immutable-string kind)
                  kind))))))

(define (make-fs-receiver)
  (make-host-receiver fs-interface production-state))
