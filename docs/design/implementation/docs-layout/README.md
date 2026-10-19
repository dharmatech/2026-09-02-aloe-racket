# docs-layout

**Status: Closed 2026-10-19. docs-layout 000 committed at `9cf7ce9`,
001 at `473863a`, and 002 in the commit that added the map.**

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
| [`checkpoints/001-editor.md`](checkpoints/001-editor.md) | **Implemented and committed at `473863a`.** Moved `docs/editor/` to `docs/design/implementation/editor/`; rewrote every reference; replaced the `docs/workflow.md` paragraph that forbade the move |
| [`checkpoints/002-map.md`](checkpoints/002-map.md) | **Implemented; committed with the map.** Wrote the map at `docs/design/implementation/README.md`, point the root `README.md` at it, and refresh the five series status lines that lag git |

No later phase is expected. 002 closes the series as the discussion
on 2026-10-19 planned it: the top of `docs/` holds orientation files,
and `docs/design/implementation/` holds every series behind a map.

Identity is `(docs-layout, N)`, spoken **docs-layout 000**,
**docs-layout 001**, and **docs-layout 002**. Numbers are three
digits and are never renumbered. Do not issue 003 from an
implementer conversation.

Process: [`docs/workflow.md`](../../../workflow.md).

Every checkpoint in this folder is implemented. There is nothing to
hand to an implementer.
