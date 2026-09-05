#lang racket/base

(provide (struct-out signature-value))

;; Reflection creates signatures from the dispatch table. Aloe source has no
;; constructor for this kernel value.
(struct signature-value (selector params return) #:transparent)
