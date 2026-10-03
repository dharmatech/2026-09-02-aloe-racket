# aloemacs buffer

**Status: Both checkpoints implemented, reviewed, and accepted.**
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the checkpoint manager and implementers |
| [`checkpoints/000-buffer-value.md`](checkpoints/000-buffer-value.md) | Implemented, reviewed, and accepted |
| [`checkpoints/001-switch-and-kill-buffer.md`](checkpoints/001-switch-and-kill-buffer.md) | Implemented, reviewed, and accepted |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-buffer**. Checkpoint 000 is spoken
**aloemacs-buffer 000**. Checkpoint 001 is spoken
**aloemacs-buffer 001**. 000 is the buffer value: the editor and
the optional path move onto it, and the session holds one of
them. 001 is switch and kill-buffer across two buffers in the
one window. Do not write global 116. Do not write `spec.md` in
the discussion that issued this charter.

The accepted spec chooses a buffer zipper, path-text or `untitled` names,
forward cycling, and a fresh untitled fallback after killing the only
buffer. `add-buffer` accepts text alone or text plus a Path. New commands
are sends with no new key bindings. The minibuffer, find-file, save-as,
`C-x b`, and windows stay later series.

**aloemacs-buffer 000** is implemented, reviewed against its written
checkpoint with no findings, and accepted by the user. Reported
implementation verification is 10 focused tests and 261 full aloemacs
tests passing, with
`git diff --check` clean. The manager reviewed the product diff, focused
tests, and migrated assertions and independently checked whitespace;
the manager did not rerun the test suites.

**aloemacs-buffer 001** is implemented, reviewed against its written
checkpoint with no findings, and accepted by the user. Reported
implementation verification is
19 initial failures from missing behavior, followed by 48 focused tests
and 279 full aloemacs tests passing, with `git diff --check` clean.
The manager reviewed the zipper transitions, selection/reset methods,
command dispatch, focused tests, and retained assertions, and
independently checked whitespace without rerunning the test suites.

The completed series is accepted against the accepted [`spec.md`](spec.md) §5.
This two-checkpoint series ends at 001; there is no 002.

Original designer handoff:

> Read `docs/workflow.md`. You are the designer. Your assignment is `docs/design/implementation/aloemacs/buffer/charter.md`. If you have been told to read that file, it is the whole assignment.
