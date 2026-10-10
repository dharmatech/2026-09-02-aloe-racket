# aloemacs window point

**Status.** Handoff from the aloemacs high-level discussion into a
design conversation. The designer writes `spec.md` and stops.
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| `spec.md` | Not written yet |
| `checkpoints/` | Not written yet. The manager writes one checkpoint after the human accepts the spec |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-window-point**. Checkpoint 000 is spoken
**aloemacs-window-point 000** and is filed as
`checkpoints/000-window-point.md`. Numbers are three digits, start at
000, and are never renumbered. The intended series is that one
checkpoint. 000 is the whole series. If it would not fit one
implementer conversation, the manager sends the spec back. The spec
does not plan a second number. Do not write global checkpoint
numbers. Do not write `spec.md` in the discussion that issued this
charter.

Each window showing a buffer keeps the cursor it had there. `C-x o`
restores that cursor and that window's origin before the fit. An edit
leaves every other window on the line and column it stored. A window
that leaves a buffer and later returns takes the buffer's current
cursor.

Managers read `spec.md` after the human accepts it. Implementers
read the one approved checkpoint and its named authority. This
charter is the spec writer's assignment.
