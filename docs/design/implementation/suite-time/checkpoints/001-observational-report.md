# suite-time 001 — Observational per-file timing report

**Status: Ready to implement.**

## Goal and stop

Add an optional Racket command that runs the complete test suite one
file at a time, reports each file's elapsed time and outcome, observes
bytecode updates during that invocation, and compares the result with
the previous completed local report run.

This is one complete report slice: discovery, serial child execution,
compiler observation, table, validated previous-run data, and atomic
replacement are tested together. Stop when its focused tests and two
real report runs are green. Do not repair the remaining `point` helper
or start another helper, checker, or parallel-testing layer.

## Authority, dependencies, and identity

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: `(suite-time, 001)`, spoken **suite-time 001**. Local
  numbering; do not edit `CHECKPOINTS.md` or `docs/checkpoints/`.
- Design authority: [`../spec.md`](../spec.md), §§1–3, §5 in full,
  and the report and boundary acceptance conditions in §7. §4 is the
  completed predecessor; §6 is later work.
- Process and host verification:
  [`docs/workflow.md`](../../../../workflow.md). Read the project-root
  `AGENTS.md`, `SPEC.md`, and `CHECKPOINTS.md` before writing code.
  `SPEC.md` remains Aloe language law.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Run commands there. Use installed Racket and Rackunit; add no package,
  Python environment, build system, or test service.
- Predecessor: [`000-bind-comparison-sides-once.md`](000-bind-comparison-sides-once.md)
  is implemented in the working tree. Its three helper repairs and
  regressions are present; recorded verification reports 42 focused
  tests and 2,653 recursive-suite tests passing. Its warm before/after
  evidence has been recorded. Retain those changes; do not require a
  commit or redo that measurement procedure for this checkpoint.
- The recorded series starting point is `main` at `9af2f39`. The human
  chooses the branch; this checkpoint does not assign a new one.

If you have been told to read this file, this is the whole assignment,
together with the authority named above.

## Exact file scope

May create or edit only:

- `bin/suite-time.rkt` (new): report operations and explicit command;
- `tests/suite-time/report.rkt` (new): focused report coverage;
- `.gitignore`: add `/.suite-time/`, preserving `compiled/`;
- root `README.md`: document the optional invocation and local report
  history in the existing Bytecode section, preserving the standing
  test and launch commands.

The command may write its runtime record and temporary sibling under
the root `.suite-time/`. Fixture projects and their test records belong
under `/tmp`, created by the tests; do not commit fixture projects or
timing transcripts. Keep existing repository bytecode caches in place.

Must leave untouched:

- every existing test, including the three suite-time 000 files,
  `point`, `history-len`, runner-check, and string-load-save timing tests;
- `SPEC.md`, `CHECKPOINTS.md`, `AGENTS.md`, `docs/workflow.md`, and all
  suite-time design and checkpoint documents;
- all of `aloe/`, `host/`, `examples/`, `lib/`, and existing `bin/aloe`;
- other documentation, tools, dependencies, or test infrastructure.

If another repository file is necessary, stop and return the checkpoint
to the manager rather than widening the scope.

## Command and discovery

The only user-facing invocation in this slice is:

```sh
TMPDIR=/tmp racket bin/suite-time.rkt
```

It runs the complete `tests/` tree. Add no path-selection, parallelism,
deadline, or threshold options. Ordinary
`TMPDIR=/tmp raco test -y tests` remains sufficient to run everything
without a report or timing-history update.

Keep the report outside `tests/`; execute the command only through
`module+ main`. Requiring `bin/suite-time.rkt` must not discover or run
the real suite, print a report, or write history. Internal test seams
may supply a fixture root, record path, deterministic durations, and
fake child outcomes; these are not command-line features. Keep the
implementation and its test seams in the two allowed Racket files.

Discover recursively in Racket's directory traversal order, using the
installed `compiler/module-suffix` recognition and excluding
dot-prefixed **file basenames** as directory-mode `raco test` does.
Include top-level tests, `test` submodules, and recognized modules that
log zero tests. Do not grep for Rackunit forms, use a committed manifest,
or run slowest-first: sorting happens only in the final table.

At this starting point suite modules are `.rkt`, and no `info.rkt`
beneath `tests/` governs discovery. This wrapper does not implement
`info.rkt` inclusion/omission configuration. Detect an `info.rkt`
anywhere under the selected suite tree and stop **before any file runs**
with a clear unsupported-discovery error. Do not silently report a
different suite. Existing module submodule configuration remains
handled by `raco test`.

The installed Racket implementation is the starting point for matching
traversal and suffix behavior. The
[Racket test manual](https://docs.racket-lang.org/raco/test.html)
is the external authority for the child testing modes.

## Serial execution and duration

For each discovered file, use this effective child invocation:

```sh
TMPDIR=/tmp raco test -y --process -- <file>
```

Use a subprocess argument vector, never shell interpolation. Launch
from the project root and preserve `TMPDIR=/tmp` in the child
environment. Keep `-y`, explicit `--process`, default `test` submodule
selection, and default run-if-absent behavior. `--process` preserves
the ordinary directory run's isolated test process when this wrapper
names one file. Do not add timeout or test-parallelism flags.

Wait for child termination and complete output draining before starting
the next file. There is only one active test file at a time. Drain
stdout and stderr concurrently; auxiliary I/O threads are allowed so
neither pipe blocks the child. Stream stdout and ordinary stderr without
loss, retaining ordinary failure diagnostics.

Measure elapsed wall seconds with a monotonic clock, from immediately
before child launch through termination and output draining. The
duration includes that invocation's startup, bytecode updates, and
testing. Do not precompile outside the timed invocation. The extra
`raco` launcher per file means these durations need not sum to the
ordinary suite command's elapsed time.

Record the exact child exit code. Zero means `PASS`; any nonzero code
means `FAIL`. Printed test counts are not the success oracle. A failed
file does not prevent later files from running.

## Compiler observation

Enable `info` logging for `compiler/cm` in each child's `PLTSTDERR`
configuration, including the spawned test process. Preserve existing
logging settings for other topics. Observe events during the timed
invocation; do not classify by run number or `.zo` existence.

The
[compilation manager API](https://docs.racket-lang.org/raco/API_for_Making_Bytecode.html)
documents the topic and events. Consult the installed implementation
for recompile and touch events as well. Recognized compiler event lines
may be consumed by the report. Forward all unrecognized output,
including unfamiliar compiler messages; do not discard test diagnostics
as noise.

Each file receives one bytecode classification:

- `rebuilt`: a `start-compile`, `start-recompile`, or `start-touch`
  event occurred for the test or any dependency, including shared
  modules outside `tests/`. This includes timestamp updates. For a
  failing file, it reports attempted update work, not a promised
  completed build.
- `warm`: observation completed reliably and no such event occurred.
  This describes observed compilation-manager work, not disk-cache
  warmth or machine load.
- `unknown`: telemetry could not be observed or classified reliably.
  Forward unfamiliar compiler messages, print the limitation, and
  make no claim of warmth. Unknown observation does not fail a passing
  test.

The overall label is `rebuilt` if any file is rebuilt, otherwise
`unknown` if any is unknown, otherwise `warm`. Observation must not
change sources, delete caches, add errortrace, alter checking, or hide
compilation in an untimed preparation pass.

## Table and run metadata

After all files finish, print one row per discovered file, sorted by
unrounded seconds descending, with repository-relative path ascending
to break ties. Print these columns in this order:

| Column | Value |
|---|---|
| `Seconds` | Current wall seconds, displayed to three decimals |
| `Result` | Current `PASS` or `FAIL` |
| `Bytecode` | Current `rebuilt`, `warm`, or `unknown` |
| `Previous(s)` | Prior duration for the same path |
| `Previous result` | Prior pass/fail result |
| `Previous bytecode` | Prior update classification |
| `Delta(s)` | Current minus prior seconds; positive is slower |
| `File` | Complete repository-relative path, without truncation |

Keep durations unrounded in the record and when calculating deltas.
Missing prior rows display `—` in the previous and delta columns.
Show prior results and compiler labels alongside numeric comparisons;
an `unknown` label remains explicit. Deltas are descriptive and never
gate success.

Above the table, print the current run's UTC timestamp, Racket version,
serial command, and overall bytecode label. When comparison is
available, also print the prior timestamp and bytecode label. The
footer gives files passed/failed, sum of file durations, and total
report wall time. Discovery, formatting, and persistence are outside
per-file timing, so the sum and total may differ.

## Previous-run data and completion semantics

Use `.suite-time/previous.rktd` relative to the project root. Read the
old record before testing. A missing record is a normal first run.
If the schema or Racket version differs, or the record is malformed,
explain why comparisons are unavailable and show no fabricated prior
values. Validate the record as data; never evaluate it.

Use a versioned Racket datum containing:

- run timestamp, Racket version, and overall bytecode classification;
- ordered suite membership;
- per-file path, unrounded seconds, exact child exit code, result,
  and bytecode classification.

After a completed run, atomically replace the prior record using a
temporary sibling and rename. A completed run with failing test files
still becomes the next previous record. An interrupted or operationally
aborted run must leave the prior record intact. Add no history database,
committed timing log, Git lookup, or network dependency.

Return 0 only when all files pass and reporting finishes. Return
nonzero when a file fails or an operational error prevents discovery,
execution, or persistence. Timing differences and unknown compiler
observation never change test success or introduce a deadline.

## Required focused tests

Add `tests/suite-time/report.rkt`. Exercise the actual report operations
against temporary roots and record paths under `/tmp`; requiring the
report must never start a recursive real-suite run. Use deterministic
durations for table and comparison assertions, and real small Racket
fixtures for process and compiler behavior. Prove all of the following:

1. Discovery includes nested recognized modules, top-level tests,
   `test` submodules, and zero-test modules; excludes nonmodules and
   dot-prefixed module basenames; follows traversal order; and rejects
   an unsupported `info.rkt` before starting any test.
2. Child commands retain `-y`, `--process`, separate argument values,
   project-root invocation, and `/tmp`. A path containing spaces stays
   one argument. No two test files run concurrently; a failed file
   does not skip a later file.
3. Real passing and failing Rackunit fixture files produce the expected
   outcomes and exact exit codes. Ample stdout and stderr are drained
   intact. Success comes from exit status, not a printed count.
4. Deterministic table coverage proves unrounded sorting, path
   tie-breaking, column values, signed deltas, missing prior files,
   first-run behavior, and incompatible or malformed records. Metadata
   and footer values reflect the run. Add no wall-time limit assertion.
5. Real `-y` fixture invocations with absent bytecode classify as
   rebuilt; repeating unchanged sources classifies as warm; editing a
   dependency produces an observed update. Cover telemetry through
   launcher and spawned test process, including a dependency outside
   the fixture's test tree. Representative events cover recompile,
   touch, unfamiliar-event handling, and overall label precedence.
   Existing logging settings for other topics and ordinary diagnostics
   are preserved.
6. Only a completed run replaces history, including completed test
   failures. Interruptions and operational aborts preserve it.
   Persistence errors return nonzero. Requiring the report performs no
   suite run or record-writing action.

Do not weaken existing tests or add production instrumentation to make
these proofs. Temporary fixture sources may be changed for the compiler
update regression; leave repository sources and caches alone.

## Verification and acceptance

Run the focused tests from the project root:

```sh
TMPDIR=/tmp raco test -y tests/suite-time/report.rkt
```

Then run the report twice, serially, from the real project root:

```sh
TMPDIR=/tmp racket bin/suite-time.rkt
TMPDIR=/tmp racket bin/suite-time.rkt
```

Inspect complete suite membership, pass/fail rows, compiler labels,
full paths, and prior-run columns. The first run may rebuild and may
already have prior history. The second compares against the first and
reports actual observed updates rather than assuming warmth. Both
real runs must pass. These are this slice's full-suite verification;
do not add a redundant ordinary recursive run after they pass unless
a change or failure calls for it.

Finally run:

```sh
git check-ignore .suite-time/previous.rktd
git status --short
git diff --check
```

Confirm history and bytecode are ignored and uncommitted, the new
source and test are visible, and edits remain in scope. Keep
`TMPDIR=/tmp` and `-y` for every agent test invocation, including
fixture children. Add no `-j`, `--jobs`, `--drdr`, or parallel trial.

The checkpoint is complete when the focused proofs pass, both real
reports cover the suite and exit successfully, the second report uses
the first completed record with truthful bytecode labels, history is
ignored, and `git diff --check` passes. Report the changed files,
focused pass count, real-run file outcomes, observed compiler labels,
and previous-run behavior in the implementation handoff. No speedup
or duration threshold is required. Stop for human review without
committing, writing suite-time 002, or repairing `point`.

## Explicit non-goals

- No further helper repair, fixture cleanup, or removed assertion
- No parser, evaluator, driver, host, or production Aloe change
- No checker cache, generic-body rule, or driver-preparation change
- No test parallelism, timeout, performance ratio, or failing threshold
- No full `info.rkt` discovery implementation, manifest, or CLI options
- No committed timing history, history service, or new tool dependency
- No global checkpoint entry, language feature, Gel, or Boids work
