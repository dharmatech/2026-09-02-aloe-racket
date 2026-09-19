#lang racket/base

(require racket/match
         racket/port
         racket/string
         "../parse.rkt")

(provide (struct-out selector-completion-site)
         recover-selector-completion-site)

(struct selector-completion-site
  (expressions target-send selector-text replacement-start replacement-span)
  #:transparent)

(define marker-base "aloecompletioncursor")

(define (fresh-marker source)
  (let loop ([suffix #f])
    (define candidate
      (if suffix
          (string-append marker-base (number->string suffix))
          marker-base))
    (if (string-contains? source candidate)
        (loop (if suffix (add1 suffix) 0))
        candidate)))

(define (expression-children expression)
  (match expression
    [(int-expr _ _) '()]
    [(float-expr _ _) '()]
    [(bool-expr _ _) '()]
    [(string-expr _ _) '()]
    [(variable-expr _ _) '()]
    [(load-expr _ _ _) '()]
    [(define-protocol-expr _ _ _) '()]
    [(check-expr left right _ _ _)
     (list left right)]
    [(define-expr _ value _)
     (list value)]
    [(define-class-expr _ _ _ _ _ methods _)
     (map method-declaration-body methods)]
    [(define-methods-expr _ methods _)
     (map method-declaration-body methods)]
    [(fn-expr _ body _)
     (list body)]
    [(case-expr scrutinee clauses else-body _)
     (append (list scrutinee)
             (map case-clause-body clauses)
             (if else-body (list else-body) '()))]
    [(send-expr receiver _ arguments _ _)
     (cons receiver arguments)]))

(define (selector-location-contains-marker? expression position marker-length)
  (and (send-expr? expression)
       (let ([loc (send-expr-selector-loc expression)])
         (and loc
              (let ([start (srcloc-position loc)]
                    [span (srcloc-span loc)])
                (and (<= start position)
                     (<= (+ position marker-length)
                         (+ start span))))))))

(define (matching-sends expressions position marker-length)
  (define matches '())
  (define (visit expression)
    (when (selector-location-contains-marker?
           expression position marker-length)
      (set! matches (cons expression matches)))
    (for-each visit (expression-children expression)))
  (for-each visit expressions)
  (reverse matches))

(define (single-symbol text)
  (call-with-input-string
   text
   (lambda (input)
     (define value (read input))
     (and (symbol? value)
          (eof-object? (read input))
          value))))

(define (map-target source candidate position marker expressions target)
  (define loc (send-expr-selector-loc target))
  (define start (srcloc-position loc))
  (define temporary-span (srcloc-span loc))
  (define marker-length (string-length marker))
  (define mapped-span (- temporary-span marker-length))
  (define marker-offset (- position start))
  (define source-start (sub1 start))
  (define source-end (+ source-start mapped-span))
  (define temporary-start (sub1 start))
  (define temporary-end (+ temporary-start temporary-span))
  (and (>= mapped-span 0)
       (>= marker-offset 0)
       (<= (+ marker-offset marker-length) temporary-span)
       (<= 0 source-start source-end (string-length source))
       (<= start position (+ start mapped-span))
       (<= 0 temporary-start temporary-end (string-length candidate))
       (let* ([temporary-text
               (substring candidate temporary-start temporary-end)]
              [marker-end (+ marker-offset marker-length)]
              [inserted-text
               (substring temporary-text marker-offset marker-end)]
              [without-marker
               (string-append
                (substring temporary-text 0 marker-offset)
                (substring temporary-text marker-end))]
              [original-text (substring source source-start source-end)])
         (and (string=? inserted-text marker)
              (string=? original-text without-marker)
              (cond
                [(zero? mapped-span)
                 (and (= start position)
                      (= temporary-span marker-length)
                      (string=? temporary-text marker)
                      (selector-completion-site
                       expressions target "" position 0))]
                [else
                 (define selector (single-symbol original-text))
                 (and selector
                      ;; `case` in literal selector position is parser syntax,
                      ;; never an ordinary Aloe send selector.
                      (not (eq? selector 'case))
                      (selector-completion-site
                       expressions target original-text start mapped-span))])))))

(define (try-candidate source candidate position marker source-path)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (parameterize ([current-output-port (open-output-string)]
                   [current-error-port (open-output-string)])
      (define expressions
        (read-program candidate #:source-path source-path))
      (define matches
        (matching-sends expressions position (string-length marker)))
      (and (= (length matches) 1)
           (map-target source
                       candidate
                       position
                       marker
                       expressions
                       (car matches))))))

(define (recover-selector-completion-site source position
                                          #:source-path [source-path #f])
  (and (<= 1 position (add1 (string-length source)))
       (let* ([marker (fresh-marker source)]
              [insertion-index (sub1 position)]
              [marked-source
               (string-append (substring source 0 insertion-index)
                              marker
                              (substring source insertion-index))])
         (for/or ([close-count (in-range 65)])
           (define candidate
             (string-append marked-source
                            "\n"
                            (make-string close-count #\))))
           (try-candidate source
                          candidate
                          position
                          marker
                          source-path)))))
