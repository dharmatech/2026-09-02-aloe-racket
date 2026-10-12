# aloemacs split drag

**Status: aloemacs-split-drag 002 implemented.** The designer wrote
[`spec.md`](spec.md) from [`charter.md`](charter.md) on 2026-10-11.
000 and 001 are implemented, manager-reviewed, and committed as
bf1d1e8 and ad62bf5. 002 is implemented and committed as 80e0fd2.
The manager writes `checkpoints/003-mode-line.md` next.
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted for checkpoint planning. Design authority for the manager and the implementers |
| [`checkpoints/000-weights.md`](checkpoints/000-weights.md) | Implemented 2026-10-11, manager-reviewed, committed as bf1d1e8: the weights, the division, the walks, and the migration of eighteen test files. No press arms |
| [`checkpoints/001-motion.md`](checkpoints/001-motion.md) | Implemented 2026-10-11, manager-reviewed, committed as ad62bf5: the `drag` field, `armed` and `disarmed`, the move string and `move?`, the session's `disarmed` and event handlers, mode `1002` in the runner, and the migration of forty-one test files. A move is inert |
| [`checkpoints/002-bar.md`](checkpoints/002-bar.md) | Implemented 2026-10-11, committed as 80e0fd2: `first-id`, `handle-id`, `min-columns`, `handle-at`, and `with-cut-at` on the `Right` axis, `press-handle` and `drag-to`, the bar press that arms, the move that drags, the lock refusal, and three test edits. The mode line stays inert. `min-columns` binds each child's minimum once in a `let` instead of sending it twice as the checkpoint text did: the values are the same, and the cost no longer doubles per level of nested `Right`s. `min-rows` in 003 has the same shape |
| `checkpoints/003-mode-line.md` | Not yet written. Next |

Parent map: [`../README.md`](../README.md). This folder does not edit
the parent map, `explorations.md`, or `discussion.md`.

Series identity is **aloemacs-split-drag**. Checkpoint 000 is spoken
**aloemacs-split-drag 000** and is filed as `checkpoints/000-slug.md`.
Numbers are three digits, start at 000, and are never renumbered.
The spec names four, using the split the charter allows:
`checkpoints/000-weights.md`, the weights and the division;
`checkpoints/001-motion.md`, the host motion and the `drag` field;
`checkpoints/002-bar.md`, the vertical bar; `checkpoints/003-mode-line.md`,
the mode line. Do not write global
checkpoint numbers.

A `Below` and a `Right` each remember two positive weights. A fresh
split is `1 1` and paints exactly today's even cut. A left press on a
vertical bar drags that `Right`. A left press on the mode line between
an upper and a lower window drags that `Below`, unless the cell is ↕,
↔, or ×, which stay the commands they are. The release ends the drag.
A terminal resize keeps the weights. A drag that would resize a locked
window does nothing. The Aloemacs TTY entry asks for motion while a
button is held, mode `1002`, in place of mode `1000`.

Series stop: the four checkpoints the spec names are implemented
and verified, and the human's hand check in `spec.md` passes. A
failure of that check sends the work back; it does not add a feature.
Drag-to-select, the wheel, hover, a keyboard resize, balancing, and
saved layouts each require their own exploration.
