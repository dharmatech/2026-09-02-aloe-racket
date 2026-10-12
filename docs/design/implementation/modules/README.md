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

A `load` inside a file copies only that file's own definitions. The interactive environment receives each loaded root's local table, and a second root unions there. A method body runs in the file that wrote it. Hover reports the queried document's path for a class that buffer defines, not the temporary sibling written for a dirty buffer.

Code and tests live in the project root. Tests for this series live under `tests/modules/`.

Next step: a designer conversation. Its whole assignment is this folder's `charter.md`.

```text
Read docs/workflow.md. You are the designer. Your assignment is
docs/design/implementation/modules/charter.md. If you have been
told to read that file, it is the whole assignment.
```
