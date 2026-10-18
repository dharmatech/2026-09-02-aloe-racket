#lang racket/base

;; The evaluator's load cache: each resolved path runs once per base, and a
;; completed run's exports are copied into each loader.
(require racket/match
         "env.rkt"
         (only-in "library.rkt"
                  list-library-resolved-path
                  string-library-resolved-path
                  int-library-resolved-path
                  option-library-resolved-path
                  resolved-source-path)
         "parse.rkt")

(provide current-eval-load-paths
         eval-once!
         eval-keyed-root
         record-evaluated-libraries!
         record-evaluated-option-class!)

;; A base's evaluator load cache maps a resolved path to its entry. The state
;; is running or completed. Exports are the (name . value) bindings the file's
;; own definitions made, in definition order.
(struct evaluator-load-entry (state exports) #:transparent)

(define current-eval-load-paths (make-parameter '()))

;; A program given with a source path runs once per base, in its own file
;; environment; the caller's environment is its loader. On a checker miss the
;; checker's expressions run; after a checker hit the bytes are parsed. run
;; receives the expressions and the file environment.
(define (eval-keyed-root environment
                         source-path
                         source-bytes
                         expressions
                         run
                         [hit-result (void)])
  (eval-once!
   environment
   (resolved-source-path source-path)
   (lambda ()
     (or expressions
         (read-program (open-input-bytes source-bytes)
                       #:source-path source-path)))
   run
   hit-result))

;; One rule for a load and a keyed root. The checker has already compared
;; bytes, so a completed entry is a hit by path alone, and a hit copies the
;; entry's exports into the loader. A miss runs the file's forms in a new file
;; environment under the loader's base, then copies its exports. A run that
;; does not complete leaves no entry and copies nothing; the definitions it
;; made stay in its file environment.
(define (eval-once! loader path read-expressions run [hit-result (void)])
  (define cache (env-load-cache loader))
  (define entry (hash-ref cache path #f))
  (cond
    [(or (and entry (eq? (evaluator-load-entry-state entry) 'running))
         (member path (current-eval-load-paths) equal?))
     (error 'eval-aloe "load cycle: ~a" path)]
    [entry
     (copy-exports! loader (evaluator-load-entry-exports entry))
     hit-result]
    [else
     (hash-set! cache path (evaluator-load-entry 'running '()))
     (define completed? #f)
     (dynamic-wind
      void
      (lambda ()
        (define file-environment (make-file-env (env-base loader) path))
        (define expressions (read-expressions))
        (define result (run expressions file-environment))
        (define exports (file-exports expressions file-environment))
        (hash-set! cache path (evaluator-load-entry 'completed exports))
        (set! completed? #t)
        (copy-exports! loader exports)
        result)
      (lambda ()
        (unless completed?
          (hash-remove! cache path))))]))

;; The bindings a file's own define, define-class, and define-protocol forms
;; left in its environment, in definition order, each name once.
(define (file-exports expressions file-environment)
  (for/fold ([exports '()]
             #:result (reverse exports))
            ([expression (in-list expressions)])
    (define name
      (match expression
        [(define-expr name _ _) name]
        [(define-class-expr name _ _ _ _ _ _ _) name]
        [(define-protocol-expr name _ _) name]
        [_ #f]))
    (if (and name (not (assq name exports)))
        (cons (cons name (env-lookup file-environment name)) exports)
        exports)))

;; A copied name already bound in the loader replaces it.
(define (copy-exports! loader exports)
  (for ([export (in-list exports)])
    (env-define! loader (car export) (cdr export))))

;; A base records the libraries it installed as completed loads. The Option
;; seed exports the class the base binds under Option right after the install.
(define (record-evaluated-libraries! environment)
  (define cache (env-load-cache environment))
  (for ([path (in-list (list list-library-resolved-path
                             string-library-resolved-path
                             int-library-resolved-path
                             option-library-resolved-path))]
        [exported-names (in-list '(() () () (Option)))])
    (define exports
      (for/list ([name (in-list exported-names)])
        (cons name (env-lookup environment name))))
    (hash-set! cache path (evaluator-load-entry 'completed exports))))

;; A base keeps the Option class it installed; find reads it, not the name.
(define (record-evaluated-option-class! environment)
  (set-env-option-class! environment (env-lookup environment 'Option)))
