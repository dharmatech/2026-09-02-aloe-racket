# suite-jobs

**Status: Accepted specification; suite-jobs 000 implemented and
verified in the working tree. The specified series is complete.**
[`spec.md`](spec.md) is the design authority. Recorded 000
verification reports 6 focused `009-launch.rkt` tests and 2,669
full-suite tests passing in the real tree with
`TMPDIR=/tmp raco test -j 4 -y tests`: 82.63 s wall, 269.28 s user,
Down-cycle median 0.751 ms, 80-column frame median 9.62 ms. The
stale-bytecode proof ran on a scratch copy without the real tree's
`compiled/`. The cold run passed 2,669 tests in 100.98 s. After a
comment was inserted as line 2 of the copy's `aloe/eval.rkt`, the
next run rewrote 193 `.zo` files, including
`aloe/compiled/eval_rkt.zo`, and passed 2,669 tests in 100.81 s, with
medians 0.904 ms and 11.94 ms. The manager reviewed the diff against
checkpoint 000. Only the four permitted files changed. The snapshot
skips only `compiled` directories and keeps the root-only `.git`
skip. `git diff --check` passes, and a focused rerun passed 6 tests.
This review uses the implementer's recorded measurements. It does
not rerun the full suite or the proof.

How many test files run at once. Not an editor feature. Not Aloe
law. Not Gel. Local numbering: do not take the next global
checkpoint integer, and do not add this series to
`CHECKPOINTS.md`.

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Starting commit: `main` at `a860e3a`. The human chooses the branch.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Whole assignment for the designer |
| [`spec.md`](spec.md) | Accepted design authority |
| [`checkpoints/`](checkpoints/) | One checkpoint file per manager conversation |
| [`000-parallel-standing-command.md`](checkpoints/000-parallel-standing-command.md) | Implemented and verified: `-j 4` standing command and the `compiled` snapshot skip |

Series identity is `suite-jobs`. Checkpoint 000 is spoken
**suite-jobs 000** and is filed as
`checkpoints/000-parallel-standing-command.md`.
Numbers are three digits, start at 000, and are never renumbered.
The checkpoint manager writes one checkpoint, then stops.

Process: [`docs/workflow.md`](../../../workflow.md).

The standing command becomes `TMPDIR=/tmp raco test -j 4 -y <paths>`.
`repository-snapshot` in `tests/editor/lsp/009-launch.rkt` skips
gitignored `compiled/` directories so sibling jobs can refresh
bytecode during that test. The intended result is one checkpoint.
The observational report in [`../suite-time/`](../suite-time/)
stays serial. A generic method-body cache is a separate
exploration.

Series stop: the one layer in the accepted specification is
implemented and verified. There is no next checkpoint in this scope.
A generic method-body cache, another comparison-helper repair, or a
different job count requires its own exploration.
