# string-load-save

**Status: Completed and accepted.** Both
[`000`](checkpoints/000-kernel-split-lines.md) and
[`001`](checkpoints/001-indexed-to-string.md) are implemented and reviewed.
[`spec.md`](spec.md) is the design authority. No further checkpoint is planned.

Language-library experiment. Not Gel. Not editor chrome. Local
numbering: do not take the next global checkpoint integer unless
the human promotes this series onto `CHECKPOINTS.md` after review.

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Accepted design authority |
| [`checkpoints/000-kernel-split-lines.md`](checkpoints/000-kernel-split-lines.md) | First implementation checkpoint; accepted |
| [`checkpoints/001-indexed-to-string.md`](checkpoints/001-indexed-to-string.md) | Second implementation checkpoint; accepted |
| `checkpoints/` | One checkpoint file per manager conversation |

Series identity is `string-load-save`; the first checkpoint is
spoken **string-load-save 000**.
Process: [`docs/workflow.md`](../../../workflow.md).

aloemacs visit (`indexed-value`) and save (`to-string`) are the
**first consumer**, not a second product in this series. Safe
control-character display stays a later aloemacs exploration.
