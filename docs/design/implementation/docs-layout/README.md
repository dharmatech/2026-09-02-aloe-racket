# docs-layout

**Status: docs-layout 000 implemented and committed at `9cf7ce9`.
docs-layout 001 is ready to implement.**

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

Documentation layout for this tree. Not Aloe law. Not Gel. Not
aloemacs. Not the editor map. Local numbering: do not take a global
checkpoint integer and do not add this series to `CHECKPOINTS.md`.

Standalone checkpoints from the high-level discussion. **No charter.
No spec.md. No checkpoint manager.** If the implementer proves a
slice is too big, stop and promote it to a charter.

The aim across the series: the top of `docs/` shows what a reader
opens first, and every document about designing and implementing a
change lives under `docs/design/implementation/`. The discussion on
2026-10-19 split that into phases. Each later phase is written only
after the human reviews the one before it.

| File | Role |
|---|---|
| [`checkpoints/000-spine.md`](checkpoints/000-spine.md) | **Implemented and committed at `9cf7ce9`.** Moved `docs/checkpoints/` and the fifteen spine briefs, vocabularies, and one-shot charters into `docs/design/implementation/spine/`; rewrote every reference; added the spine map and `tests/docs-layout/links.rkt` |
| [`checkpoints/001-editor.md`](checkpoints/001-editor.md) | **Ready to implement.** Move `docs/editor/` to `docs/design/implementation/editor/`; rewrite every reference; replace the `docs/workflow.md` paragraph that forbids the move |

Expected later phase, **not issued**:

- 002: a map at `docs/design/implementation/README.md` listing every
  series folder with its status, written after 001 so it does not
  record the editor map in its old place, with the spine map's rule
  that a series README is right when the two disagree.

Identity is `(docs-layout, N)`, spoken **docs-layout 000** and
**docs-layout 001**. Numbers are three digits and are never
renumbered. Do not issue 002 from an implementer conversation.

Process: [`docs/workflow.md`](../../../workflow.md).

Hand this checkpoint to an implementer:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/docs-layout/checkpoints/001-editor.md`. If you have been told to read that file, it is the whole assignment.
