# aloemacs file

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produced the spec |
| [`spec.md`](spec.md) | Reviewed design specification for the local series |
| [`checkpoints/000-fs-contents.md`](checkpoints/000-fs-contents.md) | **Implemented and reviewed.** Whole-file contents through thin `Fs` |
| [`checkpoints/001-file-session.md`](checkpoints/001-file-session.md) | **Ready.** Immutable file session, visit, save, and forwarding |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-file, N)`, spoken **aloemacs-file 000**.
Do not write global 116. Do not specify windows, prefix keymaps, or
a minibuffer.

Issue and implement one checkpoint at a time. Do not issue aloemacs-file 002
until 001 is implemented, reviewed, and green.
