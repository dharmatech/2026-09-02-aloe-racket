# aloemacs mouse

**Status: Implemented and accepted.** aloemacs-mouse 000, the whole
series, is implemented and its proof is green. The manager reviewed
the diff against [`checkpoints/000-click.md`](checkpoints/000-click.md)
and closed the series. The human ran the spec's §6.4 hand check on
2026-10-10 and every step behaved as written. Do not issue 001. Not
Aloe law. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the manager and the implementer |
| [`checkpoints/000-click.md`](checkpoints/000-click.md) | Click, implemented and accepted. The whole series |

Parent map: [`../README.md`](../README.md). Mouse is its own row
there. Paste, the host clipboard, PTY, and daemon stay outside
this series. This folder does not edit the parent map,
`explorations.md`, or `discussion.md`.

Series identity is **aloemacs-mouse**. Checkpoint 000 is spoken
**aloemacs-mouse 000** and is filed as `checkpoints/000-click.md`.
Numbers are three digits, start at 000, and are never renumbered.
000 is the whole series. Do not issue 001. Do not write global
checkpoint numbers.

A press and a release reach Aloe on the same read that already
returns keys. A left press in a window's text selects that window
and places its point. The release reaches Aloe and leaves the point
where it is.

Series stop: the one checkpoint in the accepted specification is
implemented and verified. `tests/aloemacs/mouse.rkt` and the wider
suite named in the checkpoint pass. There is no next checkpoint in
this scope. Wheel scrolling, drag, a modifier field, a click on the
mode line that runs a command, or placing the point during a prompt
each require their own exploration.
