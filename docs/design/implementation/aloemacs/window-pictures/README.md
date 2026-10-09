# aloemacs window pictures

Local performance repair. Not Aloe law. Not Gel. Not a global
checkpoint. The bytes on screen stay the bytes `frame` paints today.

Standalone checkpoint from the aloemacs high-level discussion. **No
charter. No spec.md. No checkpoint manager.** If the implementer
proves the slice is too big, stop and promote it to a charter.

| File | Role |
|---|---|
| [`checkpoints/000-reuse-leaf-rows.md`](checkpoints/000-reuse-leaf-rows.md) | The implementer's whole assignment |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-window-pictures, 000)`, spoken
**aloemacs-window-pictures 000**. Do not write global 116. Do not
issue 001. Do not change List, Text, or `safe-cells` in this slice.

A multi-window frame reuses each leaf's recorded rows while that
leaf's scroll, buffer history, name, selection, and rectangle stay
the same. One window still uses the editor frame. The measurement
behind the bar is
`archive/design-sketches/2026-10-09-aloemacs-multi-window-scroll/profile-investigation-grok.md`.
That report is not part of the assignment.

Hand this checkpoint to an implementer:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/aloemacs/window-pictures/checkpoints/000-reuse-leaf-rows.md`. If you have been told to read that file, it is the whole assignment.
