#lang racket/base

;; docs-layout 000. Every relative link in every Markdown file under the
;; project root must name a file or directory that exists. Lines inside
;; fenced blocks are not scanned. Fragments are dropped before resolving, and
;; a target that is empty, absolute, or a URL with a scheme is skipped.

(require racket/file
         racket/path
         racket/runtime-path
         racket/string
         rackunit)

(define-runtime-path root "../..")

(define skipped-directories
  (map string->path '(".git" "compiled" "node_modules")))

;; Every .md file under root, as paths relative to root, sorted. Does not
;; descend into a directory named .git, compiled, or node_modules.
(define (markdown-files)
  (parameterize ([current-directory root])
    (sort
     (for/list ([path (in-directory
                       #f
                       (lambda (directory)
                         (not (member (file-name-from-path directory)
                                      skipped-directories))))]
                #:when (and (file-exists? path)
                            (regexp-match? #rx"[.]md$" (path->string path))))
       path)
     string<?
     #:key path->string)))

;; When line is a fence line, its marker character and count; else #f.
(define (fence-marker line)
  (define match (regexp-match #px"^\\s*(`{3,}|~{3,})" line))
  (and match
       (cons (string-ref (cadr match) 0)
             (string-length (cadr match)))))

;; Does a fence opened with open close on a line with marker?
(define (closes? open marker)
  (and marker
       (char=? (car marker) (car open))
       (>= (cdr marker) (cdr open))))

;; The lines outside fenced blocks, each as (cons line-number line). Fence
;; lines themselves are left out.
(define (unfenced-lines lines)
  (let loop ([lines lines] [number 1] [open #f] [kept '()])
    (cond
      [(null? lines) (reverse kept)]
      [else
       (define line (car lines))
       (define marker (fence-marker line))
       (cond
         [open
          (loop (cdr lines) (add1 number) (if (closes? open marker) #f open) kept)]
         [marker
          (loop (cdr lines) (add1 number) marker kept)]
         [else
          (loop (cdr lines) (add1 number) #f (cons (cons number line) kept))])])))

;; Every link target on line.
(define (link-targets line)
  (regexp-match* #px"\\]\\(([^)]+)\\)" line #:match-select cadr))

;; The part of target to resolve, or #f when the target is not checked.
(define (checkable-target target)
  (define path (regexp-replace #rx"#.*$" target ""))
  (and (not (string=? path ""))
       (not (string-prefix? path "/"))
       (not (regexp-match? #px"^[a-zA-Z][a-zA-Z0-9+.-]*:" path))
       path))

;; Does path, built against the directory of file, name a file or directory?
(define (resolves? file path)
  (define directory (or (path-only file) (build-path 'same)))
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (define resolved (build-path root directory path))
    (or (file-exists? resolved) (directory-exists? resolved))))

(define files (markdown-files))

(define broken
  (for*/list ([file (in-list files)]
              [entry (in-list (unfenced-lines (file->lines (build-path root file))))]
              [target (in-list (link-targets (cdr entry)))]
              [path (in-value (checkable-target target))]
              #:when (and path (not (resolves? file path))))
    (format "~a:~a -> ~a" (path->string file) (car entry) target)))

(check-true (>= (length files) 100))
(check-equal? broken '())
