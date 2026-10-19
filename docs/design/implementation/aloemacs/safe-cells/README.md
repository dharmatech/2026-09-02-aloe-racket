# aloemacs safe cells

**Status: Implemented; checkpoint 000 complete.** Local experiment. Not Aloe law.
Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produces the spec |
| [`spec.md`](spec.md) | Accepted design authority for the checkpoint manager and implementer |
| [`checkpoints/000-one-cell-display.md`](checkpoints/000-one-cell-display.md) | Completed implementation slice |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-safe-cells, 000)`, spoken **aloemacs-safe-cells 000**.
Do not write global 116. Do not add a Tab key, indent stops, or a
programming mode in this series.

Since aloemacs-frame-time 000 (2026-10-19), `safe-cells` finds each
control and blanks it instead of walking every character, and both
frame paths send `safe-rows` to a leaf's clipped rows. The display rule
above still governs what is painted;
[`../frame-time/spec.md`](../frame-time/spec.md) §5 describes the
computation.
