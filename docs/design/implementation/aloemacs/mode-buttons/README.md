# aloemacs mode buttons

**Status: Implemented and accepted.** aloemacs-mode-buttons 000–001,
the whole series, is implemented in the working tree, uncommitted,
with `tests/aloemacs/mode-buttons-paint.rkt`,
`tests/aloemacs/mode-buttons-press.rkt`, and the aloemacs suite green.
The manager reviewed each implementation against its checkpoint on
2026-10-11 and found both conforming. The human ran the §8 hand check
in [`spec.md`](spec.md) on 2026-10-11 and every step behaved as
written. There is no next checkpoint in this scope; do not issue 002.
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the manager and implementers |
| [`checkpoints/000-paint.md`](checkpoints/000-paint.md) | Implemented and accepted: `buttons`, `buttons?`, `name-row`, the new `row`, the labels inside every bar at least 7 wide, and the golden migration. A label press stays inert |
| [`checkpoints/001-press.md`](checkpoints/001-press.md) | Implemented and accepted, final: `label-at`, the press that selects the window and sends `split-below`, `split-right`, or `delete-window`, and the inert presses |

Parent map: [`../README.md`](../README.md). This folder does not edit
the parent map, `explorations.md`, or `discussion.md`.

Series identity is **aloemacs-mode-buttons**. Checkpoint 000 is spoken
**aloemacs-mode-buttons 000** and is filed as
`checkpoints/000-paint.md`. Checkpoint 001 is spoken
**aloemacs-mode-buttons 001** and is filed as
`checkpoints/001-press.md`. Numbers are three digits, start at 000,
and are never renumbered. 000 paints the three labels on a mode line
that has room. 001 is the left press that selects that window and
runs the command the editor already has. Do not write global
checkpoint numbers.

A tall window's mode line shows ↕, ↔, and × on the right when the
line is at least seven columns wide. ↕ sends `split-below`. ↔ sends
`split-right`. × sends `delete-window`. Those sends stay as they
are. A line that is narrower, and a leaf with no mode line, stay
today's paint.

Series stop: both checkpoints in the accepted specification are
implemented and verified. The §8 hand check in `spec.md`, and in
`checkpoints/001-press.md`, is the human's. A failure of that check
sends the work back; it does not add a feature. Drag, hover, a
fourth glyph, a click on a path component, or a menu each require
their own exploration.
