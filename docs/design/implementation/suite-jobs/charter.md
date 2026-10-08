# Charter — suite jobs

**Status.** Handoff from the high-level discussion into a
**design conversation**. Not a checkpoint. Not an implementer
assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Process: [`docs/workflow.md`](../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Starting commit: `main` at `a860e3a`. The human chooses the
branch.

**Amendment.** The first design pass stopped because §4.7 asked
an ordinary `raco test` run to execute
`tests/string-load-save/timing.rkt`. That file is a `module+ main`
hand check. Ordinary `raco test` reports zero tests for it and
does not run its limits. `-s main` runs the body, and it is not
the suite command. This charter keeps that hand check outside
`raco test`. The two Rackunit limits below remain part of the
suite result.

**Second amendment.** The warm trial locked 4 jobs, and both
Rackunit timing files stayed inside that run. A scratch copy
then showed that `tests/editor/lsp/009-launch.rkt` fails under
`-j 4` when bytecode is out of date, because its repository
snapshot includes gitignored `compiled/` files that sibling
processes rewrite. This charter authorizes that snapshot to
skip directories named `compiled`, and it locks policy A.

**Your job.** Write the specification for **suite-jobs**. Record
the locked trial in §4.6. Take one warm serial
`TMPDIR=/tmp raco test -y tests` from the project root and record
its wall time. Then **stop**. Do not write checkpoints. Do not
implement. Do not rerun the parallel matrix.

This effort refuses a generic method-body cache, a change to the
suite-time report's serial execution, a higher timing limit, and
`--drdr` or `--place`. Those stay out so this spec stays small
enough to slice.

If you have been told to read this file, it is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4, including the trial table.
   Take the one warm serial measurement §4.6 still asks for.
3. Write `spec.md` in this folder. State the series facts in §7
   in the spec's own words. A later checkpoint-manager
   conversation slices **suite-jobs 000** under `checkpoints/`.
4. Stop. The human reviews the spec. Do not write that checkpoint
   file.

The spec names one implementer slice. A second product layer, a
checker change, or a new deadline is a defect in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`docs/workflow.md`](../../../workflow.md) | The standing command is `TMPDIR=/tmp raco test -y <paths>`. `-y` rebuilds bytecode. The same file says not to add `-j` unless a checkpoint asks for it |
| [`AGENTS.md`](../../../../AGENTS.md) and the root [`README.md`](../../../../README.md) | They document that same serial command |
| [`docs/design/implementation/suite-time/`](../suite-time/) | Implemented and verified. Comparisons bind each side once. `TMPDIR=/tmp racket bin/suite-time.rkt` reports every file serially. This series does not reopen those slices |
| [`docs/design/implementation/racket-bytecode/`](../racket-bytecode/) | `compiled/` is gitignored. `-y` stays |
| Racket's `raco test` | `-j <n>` / `--jobs <n>` runs up to `n` test files at once. Omitting it leaves this suite serial. `--drdr` is the mode that defaults the job count to the processor count. The manual is [raco test](https://docs.racket-lang.org/raco/test.html) |

**Why this series.** suite-time removed the repeated typechecking
that made two keymap files half the suite. The saved warm report
at `.suite-time/previous.rktd`, timestamp `2026-10-07T23:22:46Z`,
covers 205 files in 398.4 seconds. The longest file is
`tests/aloemacs/minibuffer-session.rkt` at 22.1 seconds. The
machine used for that measurement has 16 processors. Packing
those recorded durations onto idle workers, ignoring contention,
gives about 100 seconds at 4 jobs and about 50 seconds at 8 jobs.
That packing is a hypothesis. The trial in §4.6 replaces it.

Two Rackunit files already run inside `raco test`, and they fail
when their own work slows down. Their limits stay:

| File | Limit |
|---|---|
| `tests/aloemacs/runner-check.rkt` | Down-cycle median under 20 ms |
| `tests/aloemacs/safe-cell-scan.rkt` | 80-column frame median under 80 ms |

`tests/string-load-save/timing.rkt` is not in that table. Its
checks live in `module+ main`. The accepted string-load-save
spec runs them with `TMPDIR=/tmp racket tests/string-load-save/timing.rkt`
and calls them review-time hand bars, not suite thresholds:
split under 0.110 s, and each indexed `to-string` under 0.029 s.
Ordinary `raco test` does not execute them. This series leaves
that entry point and those numbers alone.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **The trial in §4.6 is in the spec.** That includes the two
   warm `-j 4` runs, the `-j 8` comparison, the scratch-copy
   failure, and the green run after the snapshot skip. The spec
   also records one warm serial `TMPDIR=/tmp raco test -y tests`
   from the real project root. The 398-second suite-time report
   is a different command: it starts `raco` once per file.
2. **The job count is 4.** The command names `-j 4`. It does
   not rely on `--drdr` to pick the processor count.
3. **`-y` and `TMPDIR=/tmp` stay.** Bytecode still refreshes.
   `compiled/` stays gitignored and uncommitted.
4. **The timing limits are unchanged.** The spec may change
   which invocation runs the two Rackunit files. It may not
   raise, remove, or widen their limits. The string-load-save
   hand bars stay hand bars.
5. **The suite-time report stays serial.** `bin/suite-time.rkt`
   still runs one test file at a time. Parallel jobs are a
   `raco test` invocation, not a change to that report.
6. **One slice.** The spec's layer list is the single change in
   §7: the standing command, and the snapshot skip in §4.4.
   Language, editor behavior, the checker, the evaluator, and
   comparison helpers stay as suite-time left them.
7. **A stale-bytecode proof.** The spec requires the implementer
   to repeat, in a scratch copy that does not share this tree's
   `compiled/`, a line inserted near the top of `aloe/eval.rkt`
   and then `TMPDIR=/tmp raco test -j 4 -y tests`. A comment
   appended at the end of that file is not the proof: it can
   leave the compiled bytes unchanged. The run passes. The real
   tree is not that copy.

## 4. Locked decisions (record these; do not reopen)

### 4.1 Parallel means several test files

`-j` runs several of `raco test`'s per-file processes at once.
Each file still has the isolation `--process` already gives a
multi-file run. This series does not switch the suite to
`--direct` or `--place`.

A one-file path still works with the same flag. One file has one
process. The flag matters when the path expands to many files.

### 4.2 Timing limits stay

The numbers in §2 stay the acceptance criteria of those two
Rackunit files. A parallel run that makes one of them fail is evidence
about placement, not a reason to edit the limit. `viewport-runner`
compares source positions. It is not one of these timing files.

### 4.3 The report stays a serial record

[`bin/suite-time.rkt`](../../../../bin/suite-time.rkt) keeps one
active test file. Its gitignored history stays a serial
comparison. This series does not add `-j` to that program and
does not make the report the only way to run the suite.

### 4.4 Where the slice may edit

The implementer slice may edit the standing-command text in:

- `docs/workflow.md`
- `AGENTS.md`
- the root `README.md`

It adds no runner. §4.7 needs no serial tail.

The slice edits `repository-snapshot` in
`tests/editor/lsp/009-launch.rkt`. While walking, it skips a
directory whose name is `compiled`, and it does not record that
directory or anything under it. The root `.git` skip stays. The
before-and-after `check-equal?` stays. Source, fixtures,
metadata, and every other path stay in the snapshot. No tracked
path is named `compiled`. Item 10 of
[`docs/editor/lsp/checkpoints/009-launch.md`](../../../editor/lsp/checkpoints/009-launch.md)
asks this test to prove the launch does not rewrite source,
fixtures, or metadata, or create a checked-in build artifact.
Gitignored bytecode is not that artifact.

That is the only test edit this series authorizes in advance.
Any other test file may be edited only when a trial shows it
fails because two files share one filesystem path. The edit
gives that case a private path. It does not restyle the test.

A missing `test` submodule is not that kind of fix.
`tests/string-load-save/timing.rkt` stays `module+ main`. This
series does not add a `test` submodule, and it does not pass
`-s main` to the suite. The same rule covers the other hand
scripts, `tests/aloemacs/index-002-timing.rkt` and
`tests/aloemacs/search-timing.rkt`.

### 4.5 What stays for a later exploration

Caching or skipping `check-method-body!` is a different
exploration. So is any further comparison-helper repair. This
spec does not start either one.

### 4.6 Job count

The count is **4**. The trial below is the measurement. The spec
records it and does not replace it with the 398-second report.

Machine: i9-10885H, 8 cores / 16 threads, Racket 9.3 CS,
background load around 1.5. The saved suite-time report on that
machine was 205 files and 398.4 seconds, with both timing files
about 1 second each.

| Run | Wall | Result | runner-check | safe-cell-scan |
|---|---:|---|---:|---:|
| `-j 4`, warm, run 1 | 84.0 s | 2668 passed | 0.80 ms | 9.3 ms |
| `-j 4`, warm, run 2 | 96.2 s | 2668 passed | 1.10 ms | 11.5 ms |
| `-j 8`, warm, run 1 | 63.8 s | passed | 1.17 ms | 14.4 ms |
| `-j 8`, warm, run 2 | 67.7 s | passed | 1.18 ms | 14.3 ms |
| `-j 4`, scratch copy, no bytecode | 141.5 s | 1 failure | 0.87 ms | 10.5 ms |
| `-j 4`, scratch copy, line inserted near the top of `aloe/eval.rkt` | 140.8 s | 1 failure | 0.98 ms | 11.5 ms |
| serial `raco test -y tests`, scratch copy, same kind of edit | 318.7 s | 2668 passed | 0.80 ms | 9.4 ms |
| `-j 4`, scratch copy, same kind of edit, snapshot skips `compiled` | 118.8 s | 2668 passed | 2.46 ms | 21.8 ms |

No bytecode was written during the warm runs. The scratch copy
was made with `git archive`. The real tree was not modified.
`-j 8` saved about 25 seconds and cost about 30% more CPU, so 4
is the smallest green count. The highest timing medians during
the recompiling run were 2.46 ms against 20 ms and 21.8 ms
against 80 ms.

The one failure was
`tests/editor/lsp/009-launch.rkt`, in "installed collection
command launches the real stdio server". Every difference was a
`.zo` or `.dep` file under `compiled/`: 19 new files in the copy
with no bytecode, 7 changed files after the edit. No source file
differed. The serial control passed, so the edit itself was not
the failure.

The remaining measurement is one warm serial
`TMPDIR=/tmp raco test -y tests` on the real tree. Record that
wall time beside the 84.0 s and 96.2 s runs. Use it for the
same-command ratio. Do not quote the suite-time report as that
ratio.

### 4.7 Where the Rackunit timing files run

`runner-check.rkt` and `safe-cell-scan.rkt` stay inside the
parallel invocation. The trial never put either near its limit,
including while bytecode was being rewritten. There is no serial
tail.

Do not omit either file from a full `raco test` result.

The string-load-save hand script stays out of that result. The
spec does not add it to `raco test` and does not give the suite
`-s main`. Its existing command remains a separate serial hand
check.

### 4.8 Standing command

The standing command in `docs/workflow.md`, `AGENTS.md`, and the
root `README.md` becomes:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

Checkpoint text that writes `raco test` without `-j` is still
run with `-j 4` and with `-y`. The optional-command policy stays
closed: its trigger was a Rackunit timing file failing under
load, and none did. The snapshot skip in §4.4 is what keeps this
command green after a shared `.rkt` edit.

## 5. Authority

- [`docs/workflow.md`](../../../workflow.md). Process, the
  standing test command, and the rule that `-j` waits for a
  checkpoint. This charter is not language law. The spec may
  amend the standing command only as §4.8 allows.
- [`AGENTS.md`](../../../../AGENTS.md) and the root
  [`README.md`](../../../../README.md). They repeat the standing
  command. A change to one of the three updates the other two.
- [`docs/design/implementation/suite-time/spec.md`](../suite-time/spec.md).
  The report is serial. Comparison helpers bind each side once.
  Those rules stay.
- [`docs/design/implementation/string-load-save/spec.md`](../string-load-save/spec.md)
  §3 and §6. `tests/string-load-save/timing.rkt` is a `module+ main`
  hand check, and its bars are not suite thresholds. This series
  does not amend that entry point.
- [`docs/design/implementation/racket-bytecode/`](../racket-bytecode/).
  `-y` and the gitignore for `compiled/` stay.
- The Racket [raco test](https://docs.racket-lang.org/raco/test.html)
  manual. `-j` is the parallel-file flag. `--drdr` and `--place`
  are not candidates.
- [`docs/editor/lsp/checkpoints/009-launch.md`](../../../editor/lsp/checkpoints/009-launch.md)
  item 10. The launch snapshot protects source, fixtures,
  metadata, and checked-in build artifacts. Skipping gitignored
  `compiled/` directories keeps that proof.
- The trial table in §4.6 is the parallel evidence. The warm
  serial `raco test -y tests` the designer records is the
  same-command baseline. The suite-time report's 398.4 seconds
  is not that baseline.

## 6. Non-goals

- A cache or other change to generic method-body checking
- Another comparison-helper repair
- Raising, removing, or widening either Rackunit limit or the
  string-load-save hand bars
- Moving a `module+ main` hand script into a `test` submodule
- Passing `-s main` to the suite command
- Skipping any snapshot directory other than `compiled`
- Removing the before-and-after repository snapshot
- Adding `-j` to `bin/suite-time.rkt`, or making that report concurrent
- `--drdr`, `--place`, `--direct`, or a timeout flag
- A new failing duration check on ordinary files
- Editing `SPEC.md`, `aloe/`, `examples/`, `lib/`, or the host runners
- Promoting this series onto `CHECKPOINTS.md`

## 7. Handoff

Series identity: `suite-jobs`. Checkpoint 000 is spoken
**suite-jobs 000** and filed as `checkpoints/000-slug.md`.
Numbers are three digits, start at 000, and are never renumbered.
The checkpoint manager writes one checkpoint, then stops.
Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Code and tests go there, not in this design folder. Local
numbering. The human chooses the branch. Start from `main` at
`a860e3a`.

Intended layer order:

1. **The parallel command.** Document §4.8's `-j 4` command in
   the three command files. Skip `compiled` directories in
   `repository-snapshot`, as §4.4 describes. The implementer
   proves that command with the stale-bytecode run in §3.

The spec has this one layer. It adds no checker layer and no
report layer. A manager may split that layer only when one
conversation cannot hold it, keeps this scope, and adds no
features.

If you have been told to read this file, it is the whole assignment.
