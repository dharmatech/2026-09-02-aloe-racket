# suite-time 002 — Evaluate the point source once

**Status: Ready to implement.**

## Goal and stop

Repair the remaining `point` helper in
`tests/aloemacs/keymap-session.rkt` so it evaluates its supplied Aloe
session datum once, then reads both coordinates from the stored value.
Prove the effect contract with the existing counted filesystem double
and use the completed report for full-suite verification.

Stop when this slice is green and its results are reported. This is
the final helper layer in the accepted spec. Do not start another
helper cleanup, checker change, or parallel-testing exploration.

## Authority, dependencies, and identity

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: `(suite-time, 002)`, spoken **suite-time 002**. Local
  numbering; do not edit `CHECKPOINTS.md` or `docs/checkpoints/`.
- Design authority: [`../spec.md`](../spec.md), §§1–3, §6 in full,
  and the applicable acceptance and boundary conditions in §7.
  §§4–5 describe completed predecessors, not work to repeat.
- Process and host verification:
  [`docs/workflow.md`](../../../../workflow.md). Read the project-root
  `AGENTS.md`, `SPEC.md`, and `CHECKPOINTS.md` before writing code.
  `SPEC.md` remains Aloe language law.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Run all commands there. Use installed Racket and Rackunit; add no
  package or tool dependency.
- Predecessors:
  [`000-bind-comparison-sides-once.md`](000-bind-comparison-sides-once.md)
  and [`001-observational-report.md`](001-observational-report.md)
  are implemented in the working tree. Retain their changes; no
  commit is required before this checkpoint. Recorded 000 verification
  reports 42 focused tests and 2,653 recursive-suite tests passing,
  with warm before/after evidence. For 001, the 14 focused report tests
  pass; both recorded full report runs cover 205 files, all passing,
  with observed `warm` labels and matching previous-run comparisons.
  The manager checked those two transcripts against their validated
  records and current discovery. Do not repeat the 000 measurement
  procedure or the 001 two-run acceptance procedure.
- The recorded series starting point is `main` at `9af2f39`. The human
  chooses the branch; this checkpoint does not assign a new one.

If you have been told to read this file, this is the whole assignment,
together with the authority named above.

## Exact file scope

May edit only `tests/aloemacs/keymap-session.rkt`:

- the definition of `point`;
- focused regression coverage for its evaluate-once and fixture-binding
  contract, using the file's existing driver and filesystem setup.

No new source or test file is needed. Preserve all five existing
`point` call sites, their arguments, and their expected coordinates.
Keep every existing test case and assertion.

Must leave untouched:

- `same-session`, its completed regressions, `history-len`, the
  existing fixture builders, filesystem double, and other helpers;
- every other test, including the `point` helpers in
  `search-session.rkt` and `kill-session.rkt`, report coverage,
  runner-check, and string-load-save timing tests;
- `bin/suite-time.rkt`, the root `README.md`, and `.gitignore`;
- `SPEC.md`, `CHECKPOINTS.md`, `AGENTS.md`, `docs/workflow.md`, and all
  design and checkpoint documents;
- all of `aloe/`, `host/`, `examples/`, `lib/`, and existing `bin/aloe`.

The existing report command may update its gitignored runtime record
under `.suite-time/` as usual. Keep existing bytecode caches in place;
`compiled/` stays uncommitted. Timing transcripts may stay under `/tmp`.

If another repository file is necessary, stop and return the checkpoint
to the manager rather than widening its scope.

## Required helper behavior

The starting helper splices its supplied datum into two evaluations:

```racket
(define (point st s)
  (list (ev st `((,s point) line)) (ev st `((,s point) column))))
```

Use the file's existing `def!` to evaluate and store `s` before either
coordinate read:

```racket
(define (point st s)
  (def! st 'comparison-point-source s)
  (list (ev st '((comparison-point-source point) line))
        (ev st '((comparison-point-source point) column))))
```

`comparison-point-source` is currently free and becomes helper-owned
scratch space. Neither existing nor new call sites may use it as a
fixture or supplied argument. Do not bind or rebind `actual`,
`expected`, `result`, or `saved` inside the helper.

For a successful helper call, an expression argument is evaluated
once; a symbol argument is looked up once and that value is stored.
Each definition and coordinate observation still goes through
`driver-eval!` and normal checking. Return the same Racket list of
line followed by column, retaining both observations. Do not use
`driver-prepare!`, a driver mock, or production instrumentation.

### Preserve the existing call-site meanings

In “fitted page commands use remembered rows and all six motions keep
history,” retain:

| Argument | Expected result |
|---|---|
| `(base handle-key "page-up")` | `(1 3)` |
| `(base handle-key "page-down")` | `(3 3)` |
| `(one-row handle-key "page-down")` | `(1 1)` |

These sends are pure and need no explicit second execution. The two
existing search-test calls on bound `query` and `next` remain lookups,
with expected coordinates `(0 1)` and `(0 3)`. Do not rewrite any of
these calls or collapse independent sends elsewhere in the tests.

## Required regression coverage

Add a focused Rackunit test in the same file using its existing
`state`, `session`, `def!`, `ev`, and `writes` helpers. Use a fresh
driver and counted filesystem double. No host capability is injected
while `file.aloe` loads.

1. Bind a suitable idle `base` session with an existing regular path,
   no pending prefix or prompt, and `quit` false. For example,
   `(session "abc\ndef" 1 2)` has path `/cwd/a.txt` and known
   coordinates `(1 2)`. Establish distinct fixture bindings named
   `actual`, `expected`, `result`, and `saved`, and capture each
   evaluated Racket value before invoking `point`; distinct
   `base with-echo` values follow the existing regression's pattern.
2. Reset the host-call log after fixture setup. Invoke
   `(point st '(base handle-key "save"))` and check the returned
   coordinates. After both coordinate reads have completed, check
   that the write log contains exactly one entry with the expected
   path and exact text. With the example fixture this is
   `(write "/cwd/a.txt" "abc\ndef")`. The old splicing helper must
   fail this proof by writing twice. Use an eligible save, not a quit,
   untitled, searching, or otherwise refused fixture.
3. Reset the log and bind one separate effectful
   `(base handle-key "save")` result under a fresh fixture name such
   as `bound-point-save`. Check its one expected write and capture
   the complete host-call log after binding. Call `point` on the
   bound name, check the coordinates, and prove the complete call
   log is unchanged after both reads. Checking only writes is
   insufficient for this no-additional-call proof.
4. Read the four captured fixture names again after the comparisons
   and check that none of their values changed. Neither the helper
   nor its regression may repurpose these names for scratch storage.

These checks may share one focused test case. Keep the original
coordinate, history, immutable-source, exact-host-call, and
failure-propagation assertions. Add no clock limit or speedup assertion.

## Verification and completion

After editing and adding the regression, run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt
```

Then run the existing report once for full-suite verification:

```sh
TMPDIR=/tmp racket bin/suite-time.rkt
git diff --check
```

The report runs every discovered test file serially with `-y` and
`--process`; do not add `-j`, `--jobs`, `--drdr`, or any other test
parallelism. This report invocation is the full-suite check for this
slice. Do not add a redundant ordinary full-suite run unless a new
change, failure, or unresolved concern calls for it. Do not delete
caches or precompile outside the focused verification to manufacture
a timing classification.

Completion requires:

- the supplied `point` source is evaluated once before both reads;
- all five original call sites and coordinate assertions remain;
- the inline save writes once, observing a bound save adds no host
  calls, and fixture bindings remain intact;
- the focused tests pass, the report completes with all files passing,
  and `git diff --check` passes;
- the only intentional repository edit is the scoped test file.

In the implementation handoff, report the changed file, focused pass
count, report file pass/fail counts, the keymap-session row's seconds
and bytecode label, and the report's overall classification and wall
duration. Include previous-run values when the report has a compatible
record. These are observational durations; no speedup is required.
Leave timing history and bytecode uncommitted. Stop for human review
when green; do not write or start another checkpoint.

## Explicit non-goals

- No changes to the completed comparison helpers or report
- No other helper rewrite, call-site cleanup, or assertion removal
- No checker cache, generic-body rule, or driver preparation change
- No parser, evaluator, host runner, or production Aloe change
- No deadline, performance-ratio test, committed timing log, or parallel trial
- No global checkpoint entry, language feature, Gel, or Boids work
