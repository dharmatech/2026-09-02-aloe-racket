# aloemacs window bars

**Status.** Specification accepted. **aloemacs-window-bars 000** is
implemented in the working tree. **001**, the final checkpoint, is
issued and awaits human review before implementation. Not Aloe law.
Not Gel. Not a global checkpoint. Not a faces series. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Design assignment. The spec writer reads this |
| [`spec.md`](spec.md) | Accepted design authority for the manager and implementers |
| [`checkpoints/000-one-view-bar.md`](checkpoints/000-one-view-bar.md) | Implemented: the `bar` send and the lighter one-view and fallback bar, with one-view golden migration |
| [`checkpoints/001-split-bars.md`](checkpoints/001-split-bars.md) | Issued, final: Below division with no rule row, the four-row below minimum, and LIGHT/DARK split bars, with split golden migration |

Parent map: [`../README.md`](../README.md).

Series identity is **aloemacs-window-bars**. Checkpoint 000 is spoken
**aloemacs-window-bars 000** and is filed as
`checkpoints/000-one-view-bar.md`. Checkpoint 001 is spoken
**aloemacs-window-bars 001** and is filed as
`checkpoints/001-split-bars.md`. 000 paints the one-view mode line as
a lighter bar. 001 removes the horizontal rule row and paints the
selected bar lighter than the other mode lines. Do not write global
116. Do not write `spec.md` in the discussion that issued this
charter.

A tall window's mode line is the horizontal edge of that window.
The extra dash row under it goes away. Every mode line has a
background distinct from the buffer. The selected window's bar is
lighter. The other mode lines are darker. The vertical divider
stays `|`.

Managers read `spec.md` after the human accepts it. Implementers
read the one approved checkpoint and its named authority. This
charter is the spec writer's assignment.
