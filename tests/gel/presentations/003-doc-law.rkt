#lang racket

(require rackunit
         racket/file
         racket/runtime-path
         racket/string)

(define-runtime-path gel-doc "../../../docs/gel.md")
(define-runtime-path directory-doc "../../../docs/gel-directory-surface.md")
(define-runtime-path handoff-doc "../../../docs/handoff.md")
(define-runtime-path presentations-spec "../../../docs/gel/presentations/spec.md")
(define-runtime-path checkpoints-dir "../../../docs/checkpoints")
(define-runtime-path tests-dir "../..")
(define-runtime-path checkpoint-110
  "../../../docs/checkpoints/0110-gel-list-value-rows.md")
(define-runtime-path checkpoint-112
  "../../../docs/checkpoints/0112-gel-live-directory.md")
(define-runtime-path checkpoint-113
  "../../../docs/checkpoints/0113-gel-directory-tos.md")
(define-runtime-path checkpoint-117
  "../../../docs/checkpoints/0117-gel-directory-paging.md")

(define (source path)
  (file->string path))

(define (check-has text fragment)
  (check-not-false (string-contains? text fragment)))

(define (check-lacks text fragment)
  (check-false (string-contains? text fragment)))

(test-case
 "Gel law names Gel-owned presentations and drops specimen seams"
 (define text (source gel-doc))
 (for ([old (in-list '("List.gel-values"
                       "gel-values"
                       "gel-directory-values"
                       "gel-directory-all-values"
                       "gel-up"
                       "gel-tos-text"))])
   (check-lacks text old))
 (for ([current (in-list '("Signature.accepts?"
                           "`gel-presentations`"
                           "`list-values`"
                           "GelDirectoryPresentations"
                           "holds `fs-host`"
                           "never the TOS method table"
                           "After Gel loads, `Directory` still only answers disk."))])
   (check-has text current)))

(test-case
 "Gel law retains the frozen Directory and List UX"
 (define text (source gel-doc))
 (check-regexp-match #px"`n`, `p`, `q`, and\\s+`u` omitted" text)
 (for ([frozen (in-list '("Lists remain unpaged"
                          "Directory-only 22-row window"
                          "leading-dot names"
                          "`u` pushes the Directory's live parent"
                          "directories with `/`"
                          "symbolic links with `@`"
                          "**Listener**"
                          "**Inspector**"
                          "**Browser**"))])
   (check-has text frozen)))

(test-case
 "Directory-surface law keeps disk Gel-ignorant"
 (define text (source directory-doc))
 (check-lacks text "private Gel adapter")
 (check-lacks text "private seam")
 (check-has text "`lib/disk.aloe` stays Gel-ignorant")
 (check-has text "after Gel loads, disk method tables are unchanged")
 (check-has text "Gel-owned")
 (check-has text "presentation"))

(test-case
 "Handoff records the green 000 and 002 state"
 (define text (source handoff-doc))
 (check-regexp-match #px"gel-presentations 000 and 002\\s+are green" text)
 (check-has text "001 stays blocked; do not implement it")
 (check-lacks text "Do not issue 002")
 (check-has text "`gel-presentations list-values`")
 (check-has text "`GelDirectoryPresentations`, which holds `fs-host`")
 (check-has text "Disk types and `List` carry no `gel-*` selectors")
 (check-has text "112–117 is unchanged"))

(test-case
 "Experiment spec matches the 002 host-holding shape"
 (define text (source presentations-spec))
 (check-has text "Experiment law after green gel-presentations 000 and 002")
 (check-has text "003 is the current doc-law slice")
 (check-regexp-match
  #px"Directory\\s+lives on `gel-directory-presentations`, found through the\\s+`directory-presentations` index, not through `gel-presentations`"
  text)
 (check-has text "gel-presentations 002 — Directory host")
 (check-has text "gel-presentations 003 — doc law")
 (check-lacks text "extends `GelPresentations`, not `Directory`")
 (check-lacks text
              "`define-methods GelPresentations` the same way `gel/directory.aloe`"))

(test-case
 "Historical global checkpoints remain private-seam history"
 (check-has (source checkpoint-110) "private adapter message to built-in `List`")
 (check-has (source checkpoint-112) "private adapter on `Directory`")
 (check-has (source checkpoint-113) "Private TOS-text selector")
 (check-has (source checkpoint-117) "`gel-directory-values`")
 (check-equal?
  (for/list ([path (in-list (directory-list checkpoints-dir))]
             #:when (regexp-match? #rx"^0118-.*[.]md$" (path->string path)))
    path)
  '())
 (check-false (file-exists? (build-path tests-dir "checkpoint-118.rkt"))))
