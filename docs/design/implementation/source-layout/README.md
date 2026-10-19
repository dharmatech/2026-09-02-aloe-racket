# source-layout

**Status: Closed 2026-10-19. source-layout 000 implemented, hand
check passed on a real TTY, committed in the commit that closed the
series.**

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.

Source layout for this tree: where a program written in Aloe lives.
Not Aloe law. Not Gel law: `docs/gel.md` stays law for the Gel phase,
and 000 amends one line of it. Not aloemacs. Not the editor map.
Local numbering: do not take a global checkpoint integer and do not
add this series to `CHECKPOINTS.md`.

Standalone checkpoints from the high-level discussion. **No charter.
No spec.md. No checkpoint manager.** If the implementer proves a
slice is too big, stop and promote it to a charter.

The aim: a program written in Aloe lives under `examples/`, beside
`boids.aloe`, `mpl/`, and `aloemacs/`. `lib/` holds libraries,
`host/` holds the Racket hosts and the runners that inject them, and
the top of the tree holds no application. The discussion on
2026-10-19 found one exception, `gel/`, and wrote 000 for it.

| File | Role |
|---|---|
| [`checkpoints/000-gel-under-examples.md`](checkpoints/000-gel-under-examples.md) | **Implemented 2026-10-19; hand check passed.** Moved `gel/` to `examples/gel/` as one unit; rewrite every reference with one anchored substitution; rewrite by hand the two test lines that name the folder without a slash; amend the one line of `docs/gel.md` that placed the tree |

No later checkpoint is expected. 000 closed the series: the top of
the tree holds no application. A later move of the same kind would
be issued as 001 from a new discussion, not from an implementer
conversation.

Identity is `(source-layout, N)`, spoken **source-layout 000**.
Numbers are three digits and are never renumbered. Do not issue 001
from an implementer conversation.

Process: [`docs/workflow.md`](../../../workflow.md).

Every checkpoint in this folder is implemented. There is nothing to
hand to an implementer.
