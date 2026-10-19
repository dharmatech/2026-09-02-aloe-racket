# docs-layout

**Status: Ready to implement.** docs-layout 000 is the whole job for
this phase.

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
| [`checkpoints/000-spine.md`](checkpoints/000-spine.md) | **Ready to implement.** Move `docs/checkpoints/` and the fifteen spine briefs, vocabularies, and one-shot charters into `docs/design/implementation/spine/`; rewrite every reference; add the spine map and a relative-link test |

Expected later phases, **not issued**:

- 001: move `docs/editor/` to `docs/design/implementation/editor/`
  and rewrite the sentence in `docs/workflow.md` that keeps it where
  it is.
- 002: a map at `docs/design/implementation/README.md` listing every
  series folder with its status, written after 001 so it does not
  record the editor map in its old place, with the spine map's rule
  that a series README is right when the two disagree.

Identity is `(docs-layout, 000)`, spoken **docs-layout 000**. Numbers
are three digits and are never renumbered. Do not issue 001 from an
implementer conversation.

Process: [`docs/workflow.md`](../../../workflow.md).

Hand this checkpoint to an implementer:

> Read `docs/workflow.md`. You are the implementer. Your assignment is `docs/design/implementation/docs-layout/checkpoints/000-spine.md`. If you have been told to read that file, it is the whole assignment.
