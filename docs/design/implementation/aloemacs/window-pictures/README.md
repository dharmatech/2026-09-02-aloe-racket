# aloemacs window pictures

Local performance repair. Not Aloe law. Not Gel. Not a global
checkpoint. The bytes on screen stay the bytes `frame` paints today.

**Status: Implemented.** Standalone checkpoint. **No charter. No
spec.md. No checkpoint manager.**

| File | Role |
|---|---|
| [`checkpoints/000-reuse-leaf-rows.md`](checkpoints/000-reuse-leaf-rows.md) | **Implemented.** Reuse unchanged leaf rows |

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

Reported verification: `tests/aloemacs/window-pictures.rkt`, 23 checks.
At 220×54 the medians were 2.47 ms for four windows on the first
screen, 23.62 ms for four windows with the wide leaf past line 800,
and 14.89 ms for one window at that depth. Each is under the 30 ms bar.
