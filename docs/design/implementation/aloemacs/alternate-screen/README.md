# aloemacs alternate screen

**Status: Implemented.** Standalone checkpoint. **No charter.
No spec.md. No checkpoint manager.** aloemacs-alternate-screen 000 is
implemented with `tests/aloemacs/alternate-screen.rkt` and the
aloemacs suite green. The human ran the checkpoint's hand check in
Ptyxis on 2026-10-11 and every step behaved as written. Do not issue
001.

Not Aloe law. Not Gel. Not a global checkpoint. Not a mouse or loop
checkpoint. Product root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

| File | Role |
|---|---|
| [`checkpoints/000-enter-and-leave.md`](checkpoints/000-enter-and-leave.md) | **Implemented.** Enter the alternate screen before the first frame; leave it at exit |

Parent map: [`../README.md`](../README.md).

Identity is **aloemacs-alternate-screen**. Checkpoint 000 is spoken
**aloemacs-alternate-screen 000** and is filed as
`checkpoints/000-enter-and-leave.md`. Do not write global 116. Do
not issue 001. Do not mark the mouse series or the loop series
changed from this folder.

The runner enters the terminal's alternate screen before the first
frame and leaves it when the editor returns, on normal quit and when
an exception leaves the editor. On a VTE terminal such as Ptyxis the
alternate screen has no scrollback, so the overlay scrollbar stays
hidden while the editor is up, the shell comes back unchanged after
quit, and the editor's frames stay out of the shell's history. The
frame string, the Term receiver, tui-term, and every scripted run are
unchanged.

The slice fit one implementer conversation; no charter was needed.
