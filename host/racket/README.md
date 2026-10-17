# Racket hosts

Racket modules that give Aloe programs their hosts, such as the
filesystem (`fs.rkt`) and the terminal (`term.rkt`), and the runners
that inject them.

## Effects rule

Every module in this folder has a definition-only top level. Loading a
module must not print, read standard input, open a TTY, touch the
filesystem, or start a loop. Effects live in `main` submodules or in
procedures a caller invokes.

Why: the Aloe language server loads a module from this folder when an
`aloe-hosts.rktd` manifest names it, to read the exported interface.
The server's stdout is its LSP frame stream, and its stdin is the
request stream.

A manifest can name only a module directly in this folder whose name
is lowercase ASCII letters, digits, `_`, and `-`, such as
`host/racket/fs`.

A test loads every module in this folder and checks that nothing is
written: `tests/editor/host-queries/001-manifest-reader.rkt`.
