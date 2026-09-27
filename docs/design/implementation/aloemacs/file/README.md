# aloemacs file

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produced the spec |
| [`spec.md`](spec.md) | Reviewed design specification for the local series |
| [`checkpoints/000-fs-contents.md`](checkpoints/000-fs-contents.md) | **Implemented and reviewed.** Whole-file contents through thin `Fs` |
| [`checkpoints/001-file-session.md`](checkpoints/001-file-session.md) | **Implemented and reviewed.** Immutable file session, visit, save, and forwarding |
| [`checkpoints/002-ctrl-s-key-normalization.md`](checkpoints/002-ctrl-s-key-normalization.md) | **Implemented and reviewed.** Exact plain Ctrl-S maps to `"save"` |
| [`checkpoints/003-main-and-runner.md`](checkpoints/003-main-and-runner.md) | **Implemented.** File-aware starting state and optional-path runner |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-file, N)`, spoken **aloemacs-file 000**.
Do not write global 116. Do not specify windows, prefix keymaps, or
a minibuffer.

Series complete: aloemacs-file 000–003 implement [`spec.md`](spec.md).
Do not issue 004. Windows, prefix maps, and a minibuffer remain off
this map.
