# aloemacs split drag

**Status: aloemacs-split-drag 001 issued.** The designer wrote
[`spec.md`](spec.md) from [`charter.md`](charter.md) on 2026-10-11.
The manager wrote [`checkpoints/000-weights.md`](checkpoints/000-weights.md)
the same day; it is implemented, with
`tests/aloemacs/split-drag-weights.rkt` and the aloemacs suite green,
and the manager reviewed the diff against the checkpoint and found it
conforming. The manager then wrote
[`checkpoints/001-motion.md`](checkpoints/001-motion.md). Human review
of that checkpoint precedes its implementation. 002 is written after
001 is implemented and reviewed.
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted for checkpoint planning. Design authority for the manager and the implementers |
| [`checkpoints/000-weights.md`](checkpoints/000-weights.md) | Implemented 2026-10-11 and manager-reviewed: the weights, the division, the walks, and the migration of eighteen test files. No press arms |
| [`checkpoints/001-motion.md`](checkpoints/001-motion.md) | Issued 2026-10-11, awaiting human review: the `drag` field, `armed` and `disarmed`, the move string and `move?`, the session's `disarmed` and event handlers, mode `1002` in the runner, and the migration of forty-one test files. A move is inert |
| `checkpoints/002-bar.md`, `003-mode-line.md` | Not yet written. One at a time, after the previous one is implemented and reviewed |

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
