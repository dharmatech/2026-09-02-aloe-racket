# parenthetical-construction

**Status: Spec accepted; parenthetical-construction 000–002 implemented
in the working tree and checkpoint-manager reviewed; the series is complete
pending human review.**
The checkpoint manager reviewed the spec and the closing implementation
against [002 — The session definition](checkpoints/002-session-definition.md)
on 2026-10-07. No blocking issues were found. The actual startup source
matches the spec and checkpoint targets as datums, the full suite passes
2,650 tests, and the whitespace check is green. The accepted spec defines
no further checkpoint. Human review and merging follow.

A `(fields ...)` class is built positionally with `new`, or labeled with `new*` in the selector position. The labeled tail is a binding list in the `let` shape: `(Point new* (x 10) (y 20))`.

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Branch:** `experiment/2026-10-06-parenthetical-construction`, cut from `main` at `987cbd0`. This series stays on that branch until a human merges it.

Language change. Not an aloemacs layer. Not Gel. Local numbering: do not take the next global checkpoint integer unless a human promotes this series onto `CHECKPOINTS.md` after review.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Whole assignment for the designer |
| [`spec.md`](spec.md) | Accepted design authority; complete input to the checkpoint manager and implementers |
| [000 — Grammar and AST traversal](checkpoints/000-grammar-and-ast-traversal.md) | Implemented in the working tree and reviewed against its checkpoint |
| [001 — Checking, evaluation, and language law](checkpoints/001-checking-evaluation-and-language-law.md) | Implemented in the working tree and reviewed against its checkpoint |
| [002 — The session definition](checkpoints/002-session-definition.md) | Implemented in the working tree and reviewed against its checkpoint; the closing consumer slice |

Series identity is `parenthetical-construction`. Checkpoint 000 is spoken **parenthetical-construction 000** and is filed as `checkpoints/000-grammar-and-ast-traversal.md`. Numbers are three digits, start at 000, and are never renumbered. The checkpoint manager writes one checkpoint, then stops.

Process: [`docs/workflow.md`](../../../workflow.md).

The comparison that chose this spelling is [`archive/design-sketches/2026-10-06-aloemacs-labels/`](../../../../archive/design-sketches/2026-10-06-aloemacs-labels/). The closing edit follows [`003-parens-let-aligned-let.aloe`](../../../../archive/design-sketches/2026-10-06-aloemacs-labels/003-parens-let-aligned-let.aloe), with the positional exceptions in the charter. A colon spelling was explored on `experiment/2026-10-05-labeled-construction`. That branch is not authority for this series.

The motivating program is the `aloemacs-editor` definition in [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe). Rewriting that one definition is the closing slice. The positional rebuilds in `examples/aloemacs/file.aloe` and `examples/aloemacs/editor.aloe` are not part of this series.

Next step: human review of the completed series on
`experiment/2026-10-06-parenthetical-construction`. All three planned
checkpoints are implemented; no next checkpoint remains within this spec.
