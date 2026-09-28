# int-methods

**Status: Complete; int-methods 000 and 001 implemented and reviewed.**

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

Language-library experiment. Not Gel. Not aloemacs. Local numbering:
do not take the next global checkpoint integer unless the human
promotes this series onto `CHECKPOINTS.md` after review.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Accepted design authority for the checkpoint series |
| [`checkpoints/000-lift-int-methods.md`](checkpoints/000-lift-int-methods.md) | Reviewed Int method lift |
| [`checkpoints/001-int-library.md`](checkpoints/001-int-library.md) | Reviewed derived `min` and `max` library |

Series identity is `int-methods`; the first checkpoint is spoken
**int-methods 000**.
Process: [`docs/workflow.md`](../../../workflow.md).

aloemacs `clamp-column` / `max-zero` are the **consumer**, not
this series. A later standalone checkpoint inlines those helpers
once `min` / `max` exist.
