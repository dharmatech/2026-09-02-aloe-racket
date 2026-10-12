# modules

**Status: Charter written. Spec not started.**

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Branch:** `experiment/2026-10-12-modules`, cut from `main` at `40344c3`. This series stays on that branch until a human merges it.

Language change. `load` becomes the module system. Not an aloemacs feature layer. Not Gel. Local numbering: do not take the next global checkpoint integer unless a human promotes this series onto `CHECKPOINTS.md` after review.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Whole assignment for the designer |
| `spec.md` | Not written. Design authority after the human accepts it |
| `checkpoints/` | Not written. One file at a time, after the spec is accepted |

Series identity is `modules`. Checkpoint 000 is spoken **modules 000** and will be filed as `checkpoints/000-run-once.md`. Numbers are three digits, start at 000, and are never renumbered. The checkpoint manager writes one checkpoint, then stops.

Process: [`docs/workflow.md`](../../../workflow.md).

The discussion record is [`archive/design-sketches/2026-10-09-module-design-discussion/summary.md`](../../../../archive/design-sketches/2026-10-09-module-design-discussion/summary.md). The code sketch beside it is not a spelling to adopt. This charter closes the questions that record left open.

A `load` inside a file copies only that file's own definitions. The interactive environment receives each loaded root's local table, and a second root unions there. A program with a source path is a file module, including `driver-load-file!`, a keyed `driver-load-port!`, and `eval-source` or `typecheck-source` with `#:source-path`. The cache lives on the type environment and the runtime environment. A method body and its signature use the file that wrote them. A protocol does the same. Each root, and each hover query, conforms every class in the checker's cache, every class bound in the file being checked, and every class bound in the interactive environment, after that check's forms have run. Overload selection uses the class record and the protocol record. `Option` from `lib/option.aloe` is installed once on the base, and every load of that file is that same class. The list, string, and int libraries are cache entries from the run-once layer, and each seed stores the bytes that were installed. The explicit-load census includes `file.aloe` loading `lib/text.aloe`, `gel/loop.aloe` loading `menu.aloe`, `gel/main.aloe` loading `stack.aloe`, `core.aloe` and the MPL class files loading the new Math file, and `identities.aloe` loading `sym.aloe`. Hover reports the queried document's path for a class that buffer defines, not the temporary sibling written for a dirty buffer. A queried base library is installed from the buffer's bytes. That install is new: today the query reads the path it is given, and `make-type-environment` always forces the library promises. Hover inside `sym.aloe` stays null.

Code and tests live in the project root. Tests for this series live under `tests/modules/`.

Next step: a designer conversation. Its whole assignment is this folder's `charter.md`.

```text
Read docs/workflow.md. You are the designer. Your assignment is
docs/design/implementation/modules/charter.md. If you have been
told to read that file, it is the whole assignment.
```
