# aloemacs text

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produced the spec |
| [`spec.md`](spec.md) | Reviewed design specification for the local series |
| [`checkpoints/000-string-prerequisite.md`](checkpoints/000-string-prerequisite.md) | **Implemented.** Kernel `String.drop` and Aloe `split-lines` |
| [`checkpoints/001-position-span.md`](checkpoints/001-position-span.md) | **Implemented.** `Position`, `Span`, library load boundary |
| [`checkpoints/002-text-view-validity.md`](checkpoints/002-text-view-validity.md) | **Implemented.** `Text` views, validity; payload private behind `to-string` |
| [`checkpoints/003-text-edits.md`](checkpoints/003-text-edits.md) | **Implemented.** `EditResult`, `replace` / `insert` / `delete` / `newline` |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-text, N)`, spoken **aloemacs-text 000**. Do not
write global 116. Do not specify Term, the editor loop, or file I/O.

Series complete: aloemacs-text 000–003 implement [`spec.md`](spec.md).
Do not issue 004. Term, files, undo/rebase, and a running editor remain
separate layers.
