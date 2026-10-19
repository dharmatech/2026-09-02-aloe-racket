# aloemacs next-lines

Local idiom cleanup. Not Aloe law. Not Gel. Not a global checkpoint.

Standalone checkpoint from the aloemacs high-level discussion. **No
charter. No spec.md. No checkpoint manager.** If the implementer
proves the slice is too big, stop and promote it to a charter.

| File | Role |
|---|---|
| [`checkpoints/000-text-next-lines.md`](checkpoints/000-text-next-lines.md) | **Implemented.** `Text.next-lines`; `render-rows` removed |

Parent map: [`../README.md`](../README.md).

Identity is `(aloemacs-next-lines, 000)`, spoken
**aloemacs-next-lines 000**. Do not write global 116. Do not
issue 001. Do not rewrite `frame-ansi`.

Since aloemacs-frame-time 001 (2026-10-19), neither frame path sends
`next-lines`; both read through `Text.lines-from`. `Text.next-lines`
stays, `Text.excerpt` sends it, and `tests/aloemacs/next-lines.rkt`
pins it. See [`../frame-time/spec.md`](../frame-time/spec.md) §6.2.
