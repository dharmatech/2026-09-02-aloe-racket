#lang racket/base

(provide (struct-out mirror-class-object)
         (struct-out mirror-value))

(struct mirror-class-object (list-class) #:transparent)
(struct mirror-value (subject list-class) #:transparent)
