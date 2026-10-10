# aloemacs window point

**Status: Implemented and accepted.** aloemacs-window-point 000, the
whole series. Do not issue 001.
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the manager and the implementer |
| [`checkpoints/000-window-point.md`](checkpoints/000-window-point.md) | Per-window point, implemented and accepted |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-window-point**. Checkpoint 000 is spoken
**aloemacs-window-point 000** and is filed as
`checkpoints/000-window-point.md`. Numbers are three digits, start at
000, and are never renumbered. 000 is the whole series. Do not issue
001. Do not write global checkpoint numbers.

Each window showing a buffer keeps the cursor it had there. `C-x o`
restores that cursor and that window's origin before the fit. An edit
leaves every other window on the line and column it stored. A window
that leaves a buffer and later returns takes the buffer's current
cursor.
