# aloemacs frame time

**Status: Closed 2026-10-19.** The spec was written 2026-10-18; 000
and 001 were issued, implemented, and committed in `9dd3c60` on
2026-10-19, and the closing review passed: the hand check held and
five consecutive whole-suite runs were green. The review record is in
[`checkpoints/001-read-visible-lines.md`](checkpoints/001-read-visible-lines.md).
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Designer assignment |
| [`spec.md`](spec.md) | The design. The checkpoint manager reads this, after human review |
| [`checkpoints/000-blank-by-find.md`](checkpoints/000-blank-by-find.md) | aloemacs-frame-time 000: doubled padding, `safe-cells` by `find`, `safe-rows`, the bar with the short fixture. Implemented and reviewed 2026-10-19 |
| [`checkpoints/001-read-visible-lines.md`](checkpoints/001-read-visible-lines.md) | aloemacs-frame-time 001: `Text.lines-from`, both frame paths reading through it, the long fixture, the last page, and the growth rule. Implemented and reviewed 2026-10-19; the last checkpoint, holding the closing review record |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-frame-time**. Two checkpoints:
**aloemacs-frame-time 000**, `checkpoints/000-blank-by-find.md`, and
**aloemacs-frame-time 001**, `checkpoints/001-read-visible-lines.md`.
This is not aloemacs-window-pictures 001, which stays unissued. Do not
write global checkpoint numbers.

A held Down must not outrun the frame. With global 118 landed, the deep
four-window Down is 23 ms alone at 971 lines and 27 at the length of
`file.aloe`. The spec brings both to about 9 ms, in three Aloe repairs:
doubled padding, `safe-cells` by `find` with a leaf's rows checked as
one block, and `Text.lines-from`, which reads the visible lines without
moving the focus. The bytes on screen stay what `frame` paints today.

Held typing is not this series. A typed character in four windows of
one buffer is 140 to 250 ms, because each other window walks back to
its own scroll row. The spec's read makes each step of that walk
cheaper, about 53 ms at line 817, but the walk stays and grows with the
distance: 266 ms at the end of a 2,400-line file. Where it goes is a
language-spine discussion of indexed read and slicing for List, not yet
opened.

The measurement behind the charter is
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md`](../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md).
Part of today's cost is an evaluator regression, which goes to the
language spine through
[`docs/evaluator-compile-limit-brief.md`](../../../../evaluator-compile-limit-brief.md),
not through this series. That spine checkpoint, global 118, landed in
`29c5103`. The designer's probes are in
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/`](../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/).

The series is closed. Nothing further is issued from this folder.
Held typing's next step is the language-spine discussion named above.
