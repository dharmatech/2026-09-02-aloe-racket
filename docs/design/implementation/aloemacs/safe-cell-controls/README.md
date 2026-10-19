# aloemacs safe-cell controls

Local readability cleanup. Not Aloe law. Not Gel. Not a global
checkpoint. The display rule stays the accepted safe-cells spec:
the same controls paint as one space.

**Status: Implemented.** Standalone checkpoint. **No charter. No
spec.md. No checkpoint manager.**

| File | Role |
|---|---|
| [`checkpoints/000-name-control-string.md`](checkpoints/000-name-control-string.md) | **Implemented.** The 33-character control literal is the top-level name `safe-cell-controls` |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-safe-cell-controls, 000)`, spoken
**aloemacs-safe-cell-controls 000**. Do not write global 116. Do not
issue 001. Do not issue safe-cells 001. Do not issue safe-cell-scan
001.

Since aloemacs-frame-time 000 (2026-10-19), `safe-cells` reads
`safe-cell-controls` a control at a time with `find`. It is still the
one string of the 33 controls. See
[`../frame-time/spec.md`](../frame-time/spec.md) §5.1.
