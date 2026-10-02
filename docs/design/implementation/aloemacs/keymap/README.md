# aloemacs keymap

**Status: Both checkpoints implemented and accepted.**
000 and 001 have been reviewed against their checkpoints and accepted by
the user. The revised spec remains accepted. §3.1 keeps execution on the
session. No checker prerequisite.
Not Aloe law. Not Gel. Not a global checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted revision. §3.1 specifies session `execute-command` |
| [`checkpoints/000-session-keymap.md`](checkpoints/000-session-keymap.md) | Implemented, reviewed, and accepted |
| [`checkpoints/001-prefix-and-ctrl-x.md`](checkpoints/001-prefix-and-ctrl-x.md) | Implemented, reviewed, and accepted |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-keymap**. Checkpoint 000 is spoken
**aloemacs-keymap 000**. Checkpoint 001 is spoken
**aloemacs-keymap 001**. 000 is the command values and the session
keymap for the keys the editor already has. 001 is the pending
prefix and `C-x C-s`. Do not write global 116. Do not write
`spec.md` in the discussion that issued this charter.

The completed series is accepted against [`spec.md`](spec.md) §5.
Reported final verification is 36 focused tests and 242 full aloemacs
tests passing, with
`git diff --check` clean. The manager reviewed the implementation and
tests without rerunning those suites. There is no 002 in this series.
