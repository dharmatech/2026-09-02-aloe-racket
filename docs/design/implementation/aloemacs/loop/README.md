# aloemacs loop

Local experiment. Not Aloe law. Not Gel. Not a global checkpoint.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment that produced the spec |
| [`spec.md`](spec.md) | Reviewed design specification for the local series |
| [`checkpoints/000-editor-key-transitions.md`](checkpoints/000-editor-key-transitions.md) | **Implemented.** Immutable `AloemacsEditor` key transitions |
| [`checkpoints/001-frame-and-viewport.md`](checkpoints/001-frame-and-viewport.md) | **Implemented.** Pure `frame` and point-anchored viewport |
| [`checkpoints/002-backspace-key-normalization.md`](checkpoints/002-backspace-key-normalization.md) | **Implemented.** Term maps Backspace to `"backspace"` |
| [`checkpoints/003-starting-state-and-runner.md`](checkpoints/003-starting-state-and-runner.md) | **Implemented.** Empty start and iterative runner |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-loop, N)`, spoken **aloemacs-loop 000**. Do not
write global 116. Do not specify files, windows, or prefix keymaps.

Series complete: aloemacs-loop 000–003 implement [`spec.md`](spec.md).
Do not issue 004. Load/save, windows, and prefix maps remain the File
layer and later work.
