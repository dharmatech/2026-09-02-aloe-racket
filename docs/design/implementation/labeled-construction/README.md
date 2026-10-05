# labeled-construction

**Status: Charter written. Waiting for a design conversation.**

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Branch:** `experiment/2026-10-05-labeled-construction`, cut from `main` at `cef9088`. This series stays on that branch until a human merges it.

Language change. Not an aloemacs layer. Not Gel. Local numbering: do not take the next global checkpoint integer unless a human promotes this series onto `CHECKPOINTS.md` after review.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Whole assignment for the designer |
| `spec.md` | Not written. The designer writes it beside the charter and stops |
| `checkpoints/` | Not written. A later checkpoint manager adds one file at a time |

Series identity is `labeled-construction`. Checkpoint 000 is spoken **labeled-construction 000** and will be filed as `checkpoints/000-slug.md`. Numbers are three digits, start at 000, and are never renumbered. The checkpoint manager writes one checkpoint, then stops.

Process: [`docs/workflow.md`](../../../workflow.md).

The motivating program is the `aloemacs-editor` definition in [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe). Rewriting that one definition is the closing slice. The positional rebuilds in `examples/aloemacs/file.aloe` and `examples/aloemacs/editor.aloe` are not part of this series.

If you have been told to read this file, read [`charter.md`](charter.md). That file is the whole assignment.
