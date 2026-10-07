# suite-time

**Status: Accepted specification; suite-time 000–002 implemented and
verified in the working tree. The specified series is complete.**
[`spec.md`](spec.md) is the design authority. Recorded 000 verification
reports 42 focused tests and 2,653 full-suite tests passing. The report's
14 focused tests pass; both recorded full report runs cover 205 files,
all passing, with observed `warm` labels. The manager checked both runs
against their validated records and current discovery, including the
second run's previous-run columns. For 002, the recorded report shows
22 keymap-session tests and all 205 suite files passing, with observed
`warm` labels. The manager reviewed the point repair and regression
against checkpoint 002 and validated the saved report's membership,
execution order, durations, and labels against current discovery and
the saved record. Its keymap-session row is 20.362 seconds; total
report wall time is 398.496 seconds. The 002 diff preserves all five
original point call sites, and `git diff --check` passes. This review
uses the existing verification evidence; it does not rerun the suite.

Test-suite cost. Not an editor feature. Not Aloe law. Not Gel.
Local numbering: do not take the next global checkpoint integer,
and do not add this series to `CHECKPOINTS.md`.

**Project root:** `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Starting commit: `main` at `9af2f39`. The human chooses the branch.

| File | Role |
|---|---|
| [`charter.md`](charter.md) | Whole assignment for the designer |
| [`spec.md`](spec.md) | Accepted design authority |
| [`checkpoints/`](checkpoints/) | One checkpoint file per manager conversation |
| [`000-bind-comparison-sides-once.md`](checkpoints/000-bind-comparison-sides-once.md) | Implemented and verified: evaluate each comparison side once |
| [`001-observational-report.md`](checkpoints/001-observational-report.md) | Implemented and verified: serial per-file timing and previous-run comparison |
| [`002-bind-point-source-once.md`](checkpoints/002-bind-point-source-once.md) | Implemented and verified: evaluate the point source once before both coordinate reads |

Series identity is `suite-time`. Checkpoint 000 is spoken
**suite-time 000** and is filed as
`checkpoints/000-bind-comparison-sides-once.md`. Numbers are three digits, start at
000, and are never renumbered. The checkpoint manager writes one
checkpoint, then stops.

Process: [`docs/workflow.md`](../../../workflow.md).

The first slice teaches three session comparisons to evaluate each
side once. The second slice adds an observational per-file timing
report. The third repairs the remaining `point` splicing helper in
`keymap-session.rkt`, after the report. Caching generic method bodies,
and `raco test -j`, are later explorations. This folder does not
specify them.

Series stop: all three layers in the accepted specification are
implemented and verified. There is no next checkpoint in this scope.
Any further helper repair, checker change, or parallel-testing work
requires its own exploration.
