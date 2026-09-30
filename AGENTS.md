# Agent rules for Aloe 0.1

How work is split across conversations is [`docs/workflow.md`](docs/workflow.md).
Read that file before proposing a product change.

A conversation with no assigned role is a high-level discussion.
It does not implement, and it does not write `spec.md`. When a
change is ready to leave this conversation, name these two exits
and wait:

- an exploration charter (`README.md` and `charter.md`), for later
  conversations to write the spec, the checkpoints, and the
  implementation
- a standalone checkpoint, only when the work is already locked
  and fits one implementer conversation

Do not offer to edit the product from this role.

The rules below apply when this conversation has been given one
approved checkpoint to implement. Read `SPEC.md` and
`CHECKPOINTS.md` before writing code.

- Implement one checkpoint at a time. Do not skip ahead to Boids.
- Add tests in the same change. Run them. Stop when green.
- Run tests as `TMPDIR=/tmp raco test -y <paths>` from the project
  root. `-y` rebuilds bytecode for `.rkt` files that changed and for
  modules that depend on them. Include `-y` even when the checkpoint
  writes `raco test` without it. `TMPDIR=/tmp` is required for agent
  runs.
- Do not commit `compiled/`. It is gitignored.
- `./bin/aloe` and `racket host/racket/aloemacs-run.rkt` load existing
  bytecode and do not rebuild it. After a `.rkt` edit, run the test
  command, or `raco make host/racket/aloemacs-run.rkt bin/aloe`,
  before launching. Editing only `.aloe` files needs no rebuild.
- Evaluation is send, not apply. Head of a list is the receiver. Second element is a literal selector.
- `(f x)` does not call `f`. Function objects only run via `(f call x ...)`.
- `let` = `((fn (names ...) body) call exprs ...)`.
- No inheritance, mutation, macros, implicit Int/Float coercion.
- Int → Float is the message `(n float)`.
- Do not invent special forms that are not in `SPEC.md`.
