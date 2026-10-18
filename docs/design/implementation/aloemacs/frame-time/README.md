# aloemacs frame time

**Status: Chartered.** Awaiting a designer. Not Aloe law. Not Gel. Not
a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-frame-time**. Checkpoints will be spoken
**aloemacs-frame-time 000**, **001**, … and filed under `checkpoints/`.
This is not aloemacs-window-pictures 001, which stays unissued. Do not
write global 116 or 118. Do not write `spec.md` in the discussion that
issued this charter.

A held Down must not outrun the frame. Today the deep four-window Down
is 27 to 29 ms alone against a 30 ms bar, and it fails under `-j 4`.
The bytes on screen stay what `frame` paints today.

Held typing is not this series. A typed character in four windows of
one buffer is about 200 ms, because each other window walks the zipper
back to its own scroll row. The charter records that walk, leaves it in
place, and names where it goes: a language-spine discussion of indexed
read and slicing for List, not yet opened.

The measurement behind the charter is
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md`](../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md).
Part of today's cost is an evaluator regression, which goes to the
language spine through
[`docs/evaluator-compile-limit-brief.md`](../../../../evaluator-compile-limit-brief.md),
not through this series. The spec may be written now. No
checkpoint of this series goes to an implementer until that spine
checkpoint has landed.

Hand the charter to a designer:

> Read `docs/workflow.md`. You are the designer. Your assignment is `docs/design/implementation/aloemacs/frame-time/charter.md`. If you have been told to read that file, it is the whole assignment.
