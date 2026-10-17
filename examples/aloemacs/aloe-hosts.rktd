;; Hosts the Aloe language server binds when it checks a document in this
;; folder. See docs/editor/host-queries/spec.md.
((file "main.aloe"
   (host fs-host host/racket/fs fs-interface)))
