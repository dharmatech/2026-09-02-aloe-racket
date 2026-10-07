# Charter — suite time

**Status.** Handoff from the high-level discussion into a
**design conversation**. Not a checkpoint. Not an implementer
assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Process: [`docs/workflow.md`](../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Starting commit: `main` at `9af2f39`. The human chooses the
branch.

**Your job.** Write the specification for **suite-time**. A
session comparison evaluates each supplied expression once, then
inspects the stored values. A following slice reports how long
each test file took. Then **stop**. Do not write checkpoints. Do
not implement.

This effort refuses a cache of generic method bodies, a change
to `driver-eval!` or `driver-prepare!`, a parallel `raco test
-j` command, and a failing time limit on ordinary tests. Those
stay out so this spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.8.
3. Write `spec.md` in this folder. State the series facts in §7
   in the spec's own words. A later checkpoint-manager
   conversation slices **suite-time 000**, … under
   `checkpoints/`.
4. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the layers in §7. A checker cache, a change to
the standing test command's process count, or a deadline that
fails a correct test on a busy machine is a defect in this
document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`aloe/driver.rkt`](../../../../aloe/driver.rkt) | `driver-eval!` parses, typechecks, and evaluates on every call. `driver-prepare!` typechecks once and returns a procedure that only evaluates. The runner uses prepare. These session tests use `driver-eval!` |
| [`aloe/type.rkt`](../../../../aloe/type.rkt) `infer-instance-send` | A generic `(fields ...)` class rechecks the selected method body on each send. That rule stays |
| [`docs/design/implementation/aloemacs/runner-check/`](../aloemacs/runner-check/) | The interactive loop already prepares its datums once. This series does not reopen that repair |
| [`docs/design/implementation/checker-recursion/`](../checker-recursion/) | Withdrawn. Recursive generic methods are not this series |
| [`docs/design/implementation/racket-bytecode/`](../racket-bytecode/) | The standing command is `TMPDIR=/tmp raco test -y <paths>`. `-y` stays. `-j` stays unauthorized |

**Why this series.** On 2026-10-07 a serial
`TMPDIR=/tmp raco test -y tests`, with bytecode already current,
passed 2,650 tests in 592.59 seconds (user 569.88, sys 22.16).
The median file took 0.424 seconds. About 90% of the time was
under `tests/aloemacs/`.

| Test file | Time |
|---|---:|
| `tests/aloemacs/keymap-session.rkt` | 249.7 s |
| `tests/aloemacs/keymap-prefix.rkt` | 84.6 s |
| `tests/aloemacs/minibuffer-session.rkt` | 22.3 s |
| `tests/aloemacs/completion-page-session.rkt` | 16.1 s |

The two keymap files were 56% of the suite. Their `same-session`
helpers splice each supplied expression into every field check,
every editor-field check, the text check, and each frame size.
Each of those calls `driver-eval!`, so each one typechecks the
original operation again. `keymap-session` does that 26 times
for the session and editor fields, then again for `to-string`
and for two frame sizes. `keymap-prefix` does the same with two
frame sizes. `buffer-value` splices the same way and took 5.3
seconds.

Ten typechecks of one representative `handle-key` expression
took about 1.15 seconds. Ten evaluations of that expression took
about 1 millisecond. Loading `main.aloe` took tens of
milliseconds. One keymap-prefix case, "quit absorbs prefix and
save before search or effects, preserving even armed state,"
spent 32.3 seconds in a sample, 99.8% of it in
`check-method-body!`. A temporary copy that stored each side
once, then ran the same assertions on those values, took 1.3
seconds and passed. That copy is not in the tree and is not
authority. It is evidence that the repeated check is the cost.

Most other `same-session` helpers already store each side once.
`minibuffer-session.rkt`, `minibuffer-value.rkt`, and
`buffer-session.rkt` bind `comparison-actual` and
`comparison-expected`. The windows helpers bind `actual` and
`expected`. Those files are the pattern. Their remaining time is
not this first slice.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **One evaluation per side.** In the three helpers that still
   splice, each argument expression is evaluated once. Later
   field, editor, text, and frame checks inspect the stored
   values. The original operation is not typechecked again for
   each field.
2. **The observations stay.** Whole-session equality, the field
   inventory, editor fields, `to-string`, frame sizes, and the
   buffer-value empty-list checks remain. A test that already
   passes a bound name still compares that value. A test that
   means two executions writes two sends at the call site.
3. **The three splicing helpers are the first slice.**
   `keymap-session.rkt`, `keymap-prefix.rkt`, and
   `buffer-value.rkt`. Helpers that already bind once are left
   in the shape they have.
4. **Warm evidence, no new deadline.** The implementation records
   a warm serial before-and-after for the two keymap files on
   the same machine. The spec names that procedure. It does not
   add a rackunit timeout, a median bar, or any other check that
   fails because the machine is busy.
5. **The report is observational and second.** It prints each
   test file's duration and pass/fail result, slowest first, and
   can compare those durations with the previous local run. It
   distinguishes a run that rebuilt bytecode from a warm run.
   `TMPDIR=/tmp raco test -y tests` still runs the suite without
   the report.
6. **Language and runner behavior stay.** `SPEC.md`,
   `aloe/type.rkt`, `aloe/eval.rkt`, `driver-eval!`,
   `driver-prepare!`, production Aloe under `examples/` and
   `lib/`, and the host runners are unchanged by this series.

## 4. Locked decisions (record these; do not reopen)

### 4.1 Store each side, then inspect it

The three splicing helpers follow the minibuffer shape. Each
side is bound with the file's existing `def!`, which is
`driver-eval!` of a `define`. The comparison names are
`comparison-actual` and `comparison-expected`. Those names are
free in the three files. Field checks, editor checks,
`to-string`, frame checks, and the buffer-value empty-list
checks then use those names.

`driver-prepare!` is the runner's tool for evaluating one
prepared datum many times. These helpers do not switch to it.
`driver-eval!` continues to parse, typecheck, and evaluate on
every call, including the one `define` that stores each side.

A symbol argument is stored by evaluating that lookup once.
A large expression is stored by evaluating that expression once.
The helper does not splice the caller's expression into later
checks.

### 4.2 One run is the observation

Host effects inside an argument expression happen once.
`visit`, `save`, `save-key`, and `handle-key` are ordinary
argument expressions under that rule. A test that needs two
executions performs two sends, then compares. The helper's field
loop is not a repetition mechanism.

Tests that already evaluate into a name and then call
`same-session` on that name keep that shape. The helper must not
give those names a second meaning. `actual`, `expected`,
`result`, and `saved` are fixture names in these files. The
helper does not bind them.

### 4.3 Where the first slice may edit

- `tests/aloemacs/keymap-session.rkt`
- `tests/aloemacs/keymap-prefix.rkt`
- `tests/aloemacs/buffer-value.rkt`

The edit is the helper and any call site the §4.6 inventory
shows is green only because the helper used to repeat an effect.
Production Aloe, the checker, the evaluator, the driver, and the
other test files stay out of that slice.

### 4.4 The report comes after the helpers

The report is a separate slice. It covers the suite the standing
command covers, not only Aloemacs. It records duration and
pass/fail per file, sorts slowest first, and compares with a
previous run when a previous record exists. It says whether that
run rebuilt bytecode.

The previous-run record is local and gitignored. A timing number
is not a committed artifact. The report adds no failing
threshold. `raco test --table` remains a count table. The
standing command in [`docs/workflow.md`](../../../workflow.md)
stays serial and keeps `-y`.

### 4.5 What this series leaves for a later exploration

Generic method-body checking stays as `infer-instance-send`
implements it. A cache, a change to which bodies are deferred,
and a change to rebinding or generic instantiation are a
different exploration after this report exists.

`raco test -j` stays unauthorized. The longest file sets the
serial floor, and the suite already has tight timing checks:
the runner-check median under 20 milliseconds, and the
string-load-save limits under 0.110 seconds and 0.029 seconds.
A parallel trial waits until the report shows the remaining
files, and it needs its own charter.

### 4.6 Repeated effects (resolve this)

Read every `same-session` call in the three files. List the
arguments whose evaluation performs a host effect or whose
result depends on being evaluated more than once. For each,
state the observation after one evaluation, and name any call
site the first slice rewrites into an explicit second send.

A call that passes an already-bound name has already performed
its effect. Record that class as unchanged.

### 4.7 Another splicing helper (resolve this)

Search the suite for a helper other than the three in §4.3 that
still splices one expensive expression into repeated
`driver-eval!` checks. `completion-page-session.rkt` is one
file to read: it is slow, and it does not define `same-session`.

If you find that same defect, add one later layer for it, after
the report, and name the files. If the remaining time is the
cost of many distinct checks, the series ends at the report.
Do not convert that finding into a checker change.

### 4.8 Report shape (resolve this)

Pick the command, the output columns, the gitignored path of the
previous-run record, and how a bytecode rebuild is distinguished
from a warm run. The command runs from the project root, uses
`TMPDIR=/tmp`, and keeps `-y`.

Lean toward a small Racket program beside the tests, invoked
explicitly. The ordinary `raco test` invocation stays enough to
run the suite. The report may wrap that invocation. It does not
replace it, and it does not require `-j`.

## 5. Authority

- [`docs/workflow.md`](../../../workflow.md). Process, the
  standing test command, and the rule that `-j` needs its own
  checkpoint. This charter is not language law.
- [`aloe/driver.rkt`](../../../../aloe/driver.rkt). `driver-eval!`
  checks every call. `driver-prepare!` is the prepare-once tool.
  This series uses the first and does not change either.
- [`aloe/type.rkt`](../../../../aloe/type.rkt). The deferred
  generic body check explains the cost. The checker-recursion
  folder withdrew a change to that rule. `SPEC.md` wins on
  language behavior.
- The bind-once helpers in
  [`tests/aloemacs/minibuffer-session.rkt`](../../../../tests/aloemacs/minibuffer-session.rkt)
  and
  [`tests/aloemacs/buffer-session.rkt`](../../../../tests/aloemacs/buffer-session.rkt)
  are the local pattern for §4.1. Their remaining runtime is not
  a defect this spec has to remove.
- The three splicing helpers named in §4.3 are the source of the
  first slice. The measurements in §2 are the baseline. A fresh
  transcript is not authority over those numbers.

## 6. Non-goals

- Caching or skipping `check-method-body!`
- Changing which generic bodies are checked at definition
- Changing `driver-eval!`, `driver-prepare!`, parsing, or evaluation
- Editing `SPEC.md`, `examples/`, `lib/`, or the host runners
- Renaming or restyling helpers that already bind once
- Dropping a field, frame, or `to-string` assertion to save time
- A committed timing log, or a deadline that fails a correct test
- Making the report the only way to run the suite
- `raco test -j`, or any change to how many test processes run
- Promoting this series onto `CHECKPOINTS.md`

## 7. Handoff

Series identity: `suite-time`. Checkpoint 000 is spoken
**suite-time 000** and filed as `checkpoints/000-slug.md`.
Numbers are three digits, start at 000, and are never renumbered.
The checkpoint manager writes one checkpoint, then stops.
Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Code and tests go there, not in this design folder. Local
numbering. The human chooses the branch. Start from `main` at
`9af2f39`.

Intended layer order:

1. **Bind once.** The three helpers in §4.3, the effect
   inventory in §4.6, and the warm before-and-after for the two
   keymap files. No new deadline.
2. **The report.** The observational per-file timing report in
   §4.4 and §4.8.
3. **Another splicing helper,** only if §4.7 finds one. Same
   defect, same repair, after the report.

The spec keeps this order. It adds no checker layer and no
parallel layer. A manager may split a layer that misses
checkpoint size, keeps this order, and adds no features.

If you have been told to read this file, this is the whole assignment.
