# Specification — suite jobs

**Status: Accepted.** This specification resolves the
suite-jobs charter. Implementation proceeds one approved checkpoint
at a time.

The standing test command runs four test files at once:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

Bytecode still refreshes, both Rackunit timing files still run
inside that command under their current limits, and the suite-time
report stays serial. One test, `tests/editor/lsp/009-launch.rkt`,
stops recording gitignored `compiled/` directories in its repository
snapshot, because sibling test processes rewrite bytecode there.

This file carries the complete design input for the checkpoint
manager and the implementer. The charter and the design conversation
are not required context. A checkpoint narrows this specification to
one implementable slice; it does not revise the design.

## 1. Series and authority

- Series identity: `suite-jobs`. The first checkpoint is spoken
  **suite-jobs 000**, lives at `checkpoints/000-slug.md` beside this
  file, and uses a lowercase, hyphen-separated slug. Numbers have
  three digits, begin at 000, and are never renumbered.
- The manager writes one checkpoint and stops. Human review separates
  design, checkpoint writing, implementation, and any later number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Source and tests belong in that tree, outside this design folder.
- Starting point: `main` at `a860e3a`. The human chooses the branch.
  This series uses local numbering. It does not enter
  `CHECKPOINTS.md` or `docs/checkpoints/`.
- After human acceptance, this file is the series design authority.
  [`docs/workflow.md`](../../../workflow.md) governs process and host
  verification, and this series amends its standing test command.
  [`SPEC.md`](../../../../SPEC.md) remains Aloe law and is not
  touched.

Other authority this design keeps:

- [`docs/design/implementation/suite-time/spec.md`](../suite-time/spec.md):
  `bin/suite-time.rkt` runs one test file at a time and keeps a
  serial history. Comparison helpers bind each side once.
- [`docs/design/implementation/racket-bytecode/`](../racket-bytecode/):
  `-y` stays, and `compiled/` stays gitignored and uncommitted.
- [`docs/design/implementation/string-load-save/spec.md`](../string-load-save/spec.md)
  §3 and §6: `tests/string-load-save/timing.rkt` is a `module+ main`
  hand check run with `TMPDIR=/tmp racket tests/string-load-save/timing.rkt`.
  Its bars are review-time hand bars, not suite thresholds.
- [`docs/editor/lsp/checkpoints/009-launch.md`](../../../editor/lsp/checkpoints/009-launch.md)
  item 10: the launch test proves the package-link launch does not
  rewrite source, fixtures, or metadata, or create a checked-in
  launcher or build artifact.
- The Racket [raco test](https://docs.racket-lang.org/raco/test.html)
  manual: `-j <n>` / `--jobs <n>` runs up to `n` test files at once.

The series has one layer, specified in §4:

1. The parallel standing command in the three command files, and the
   `compiled` skip in `009-launch.rkt`'s repository snapshot.

There is no checker layer, report layer, or runner. The manager may
split this layer only if one implementer conversation cannot hold it,
keeping this scope and adding no features.

## 2. Evidence

### 2.1 Starting behavior

`docs/workflow.md`, `AGENTS.md`, and the root `README.md` give the
standing command as `TMPDIR=/tmp raco test -y <paths>`. Without `-j`,
`raco test` runs a directory's per-file processes one at a time.
`docs/workflow.md` also says not to add `-j` unless a checkpoint asks
for it. This series is that request.

With `-j 4`, `raco test` keeps one process per test file, as a
multi-file run already does, and runs up to four of them at once.
Each child still installs the compilation manager when `-y` is
given, so each file refreshes the bytecode it loads. A one-file path
behaves as before: one file is one process. Each file's heading reads
`raco test: <slot> (file ...)`, where the slot is a worker number
from 0 to 3. Output from concurrent files is not buffered per file:
in the trial, one failure's diagnostic lines were split by other
files' headings. The final count and exit status still cover every
file.

Two Rackunit files fail when their own work slows down. Their limits
are unchanged by this series:

| File | Check | Limit |
|---|---|---|
| `tests/aloemacs/runner-check.rkt` | Down-cycle median | under 20 ms |
| `tests/aloemacs/safe-cell-scan.rkt` | 80-column frame median | under 80 ms |

Both print their measured median on success.

### 2.2 Trial

Machine: Intel i9-10885H, 8 cores / 16 threads, 61 GB, Racket 9.3
CS, background desktop load around 1.5. Commands ran from the project
root, or from the root of a scratch copy, with `TMPDIR=/tmp`.

| Run | Wall | Result | runner-check | safe-cell-scan |
|---|---:|---|---:|---:|
| `-j 4`, warm, run 1 | 84.0 s | 2668 passed | 0.80 ms | 9.3 ms |
| `-j 4`, warm, run 2 | 96.2 s | 2668 passed | 1.10 ms | 11.5 ms |
| `-j 8`, warm, run 1 | 63.8 s | 2668 passed | 1.17 ms | 14.4 ms |
| `-j 8`, warm, run 2 | 67.7 s | 2668 passed | 1.18 ms | 14.3 ms |
| `-j 4`, scratch copy, no bytecode | 141.5 s | 1 failure | 0.87 ms | 10.5 ms |
| `-j 4`, scratch copy, line inserted near the top of `aloe/eval.rkt` | 140.8 s | 1 failure | 0.98 ms | 11.5 ms |
| serial `raco test -y tests`, scratch copy, same kind of edit | 318.7 s | 2668 passed | 0.80 ms | 9.4 ms |
| `-j 4`, scratch copy, same kind of edit, snapshot skips `compiled` | 118.8 s | 2668 passed | 2.46 ms | 21.8 ms |
| serial `raco test -y tests`, warm, real tree | 275.9 s | 2668 passed | 0.76 ms | 9.7 ms |

The warm rows ran on the real tree with current bytecode. A marker
file touched before each warm run had no newer file under any
`compiled/` directory afterward, so no bytecode was written. The
scratch copy was made with `git archive a860e3a`. Each edit row
inserted a fresh comment line as line 2 of the copy's own
`aloe/eval.rkt`. That shifts source locations, changes
`aloe/compiled/eval_rkt.zo`, and made each following run rewrite 193
or 194 `.zo` files. A comment appended at the end of the file is not
equivalent: in the trial it left the compiled bytes unchanged,
dependents were only touched, and `-j 4` passed without exercising
the failure. The real tree was not modified.

The suite-time report recorded 205 files in 398.4 seconds on the
same machine. That report starts `raco` once per file, so it is not
the same command and is not the baseline for the ratio. The baseline
is the warm serial row: 275.9 s. The warm `-j 4` runs took 84.0 s and
96.2 s, a wait 2.9 to 3.3 times shorter. They used 275–321 s of user
CPU time against the serial run's 257 s.

### 2.3 Job count

The count is **4**. Both warm `-j 4` runs passed with both timing
files far inside their limits. `-j 8` passed too, but saved about
25 seconds for roughly a third more CPU time (385–419 s user against
275–321 s). Four is the smallest count tried, and it is the count
this series locks. The command names `-j 4`; it does not use
`--drdr` or any processor-count default.

### 2.4 Timing files

Neither Rackunit timing file came near its limit in any run,
including the run that rewrote bytecode while testing. The highest
medians were 2.46 ms against 20 ms and 21.8 ms against 80 ms. Both
files stay inside the parallel invocation. There is no serial tail
and no runner.

### 2.5 The snapshot failure

Every failing `-j 4` run had exactly one failure:
`tests/editor/lsp/009-launch.rkt`, test case "installed collection
command launches the real stdio server", at the `check-equal?` that
compares `(repository-snapshot)` with `source-before`.

`repository-snapshot` walks the whole repository except the root
`.git` and records each directory and each file's bytes. That
includes every `compiled/` directory. The test case takes several
seconds: it links the repository as a package in an isolated
`PLTUSERHOME` and launches `racket -l aloe/lsp` several times.
Under `-j`, sibling processes compile into `compiled/` during that
window whenever bytecode is out of date. In the trial, every
difference was a `.zo` or `.dep` file under `compiled/`: 19 new
files in the copy with no bytecode, and 7 changed files after the
edit. No other path differed. The serial control after the same
kind of edit passed, so the edit itself did not cause the failure.
Warm runs pass only because nothing compiles.

After any edit to a shared `.rkt` module, nearly every test file's
bytecode must be rebuilt, so a wide `-j 4` run would fail this test
almost every time. Skipping directories named `compiled` removed
the failure: the run after the same kind of edit passed.

`compiled/` is gitignored, and no tracked path is named `compiled`.
Item 10 of the 009 checkpoint protects source, fixtures, metadata,
and checked-in artifacts. Gitignored bytecode written by other test
files is none of those, so the skip keeps that proof.

Searches of `tests/` found no other test that observes paths written
by another test file. `tests/checkpoint-114.rkt` scans `gel/`, which
holds only `.aloe` files and no `compiled/` directory. Other
directory listings in `tests/editor/lsp/` and
`tests/editor/completion/` read fixture directories or their own
temporary directories.

## 3. Host, layout, and verification command

Use the installed Racket and Rackunit. No package, build system,
Makefile, wrapper, or runner is added. Run commands from the project
root unless a step names the scratch copy.

After this series, agent test runs are always:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

The implementer uses that command for its own verification.

The slice may edit only:

| Path | Permitted change |
|---|---|
| `docs/workflow.md` | Standing test command and the sentences that explain it (§4.1) |
| `AGENTS.md` | The test-command bullet (§4.1) |
| `README.md` (root) | The test commands in the Bytecode section, and one optional clause beside the report description (§4.1) |
| `tests/editor/lsp/009-launch.rkt` | `repository-snapshot` and one focused test case (§4.3) |

It must not edit `bin/suite-time.rkt`, `tests/suite-time/`, any other
test file, `.gitignore`, `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`,
`aloe/`, `host/`, `examples/`, `lib/`, `gel/`, `bin/aloe`, or any
historical checkpoint, spec, or charter. Older documents that write
`raco test` or `raco test -y` stay as they are; the standing rule in
§4.1 supplies `-j 4` and `-y` when they are run.

`compiled/` stays gitignored and is not committed. Scratch copies
live under `/tmp` and are not committed.

## 4. Layer one: the parallel command

### 4.1 Standing command text

The three command files must state the same command:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

**`docs/workflow.md`, Host verification.**

- The fenced command becomes `TMPDIR=/tmp raco test -j 4 -y <paths>`.
- The paragraph after it keeps its `<paths>` and `-y` sentences and
  says that `-j 4` runs up to four test files at once, each in its
  own process. A checkpoint that writes `raco test` without `-j` or
  without `-y` is still run with `-j 4` and `-y`.
- The sentence "Do not add `-j` unless the checkpoint asks for it"
  is replaced so it no longer contradicts the test command: `raco
  make` gets no `-j`, and the test command's count stays 4, unless a
  checkpoint asks otherwise.
- The `raco make host/racket/aloemacs-run.rkt bin/aloe` command and
  its sentences stay unchanged otherwise.

**`AGENTS.md`.** The bullet that begins "Run tests as" names
`TMPDIR=/tmp raco test -j 4 -y <paths>` and says to include `-j 4`
and `-y` even when the checkpoint writes `raco test` without them.
Its `TMPDIR=/tmp` sentence stays. No other bullet changes.

**Root `README.md`, Bytecode section.**

- `TMPDIR=/tmp raco test -y tests` becomes
  `TMPDIR=/tmp raco test -j 4 -y tests`, with one sentence that the
  command runs up to four test files at once.
- `TMPDIR=/tmp raco test -y tests/aloemacs` becomes
  `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs`.
- The `raco make` command, the suite-time report command, and the
  report's description stay. The description may gain one clause
  saying the report stays serial while the ordinary command runs four
  files at once. It must keep "runs files serially with
  `raco test -y --process`".
- "The ordinary test commands above do not update this history."
  stays true and stays.

Prose may be worded to match each file's voice. The command strings
are exact.

### 4.2 Timing files and hand scripts

`tests/aloemacs/runner-check.rkt` and
`tests/aloemacs/safe-cell-scan.rkt` run inside the parallel
invocation. Neither file, its limit, nor its median sample changes.
A full run executes both. Nothing omits either file from a
directory run.

`tests/string-load-save/timing.rkt`,
`tests/aloemacs/index-002-timing.rkt`, and
`tests/aloemacs/search-timing.rkt` keep their `module+ main`
entry points. The suite command does not pass `-s main`, and no
`test` submodule is added. The string-load-save hand check keeps its
separate serial command.

### 4.3 The snapshot skip

Edit `repository-snapshot` in `tests/editor/lsp/009-launch.rkt`:

- While walking, skip any directory entry whose name is exactly
  `compiled` and which is a directory, at any depth. Record neither
  that directory nor anything under it.
- Keep the existing skip of `.git` at the repository root only.
- Record everything else as today: each directory as
  `(list relative-path 'directory)`, each file with its bytes, any
  other entry as `'other`, in the same sorted walk order. A regular
  file named `compiled` is still recorded.
- Keep both existing calls, `source-before` and the final
  `check-equal?` against it, and the `info.rkt` byte check. Do not
  skip any other directory name.

So the skip can be tested without writing into the repository,
`repository-snapshot` takes an optional root argument that defaults
to the repository root. The two existing calls pass no
argument.

Add one focused test case in the same file. It builds a temporary
tree under `/tmp` with `make-temporary-directory` (deleted
afterward, even on failure), snapshots it, and checks the whole
result with `check-equal?`. The tree:

```text
<root>/
  .git/HEAD          skipped: root .git
  a/
    .git/config      recorded: only the root .git is skipped
    b.txt            recorded
    compiled/
      y_rkt.dep      skipped: compiled directory
  c/
    compiled         recorded: a regular file, not a directory
  compiled/
    x_rkt.zo         skipped: compiled directory
  src.rkt            recorded
```

The expected snapshot is exactly these entries in this order, with
each file's bytes as written by the test:

```text
./a                directory
./a/.git           directory
./a/.git/config    file
./a/b.txt          file
./c                directory
./c/compiled       file
./src.rkt          file
```

The test asserts no wall-clock limit and adds no driver or host
mock.

### 4.4 Verification

In the real tree, after editing:

1. Focused: `TMPDIR=/tmp raco test -j 4 -y tests/editor/lsp/009-launch.rkt`.
2. Full: `TMPDIR=/tmp raco test -j 4 -y tests`, timed with
   `/usr/bin/time -f 'wall=%e user=%U sys=%S'`. Record wall time,
   the pass count, and both printed medians.

**Stale-bytecode proof.** This repeats the trial's failing case on a
scratch copy that does not share the real tree's `compiled/`. Never
run it in the real tree.

1. Copy the working tree, including the uncommitted edits, into a new
   directory under `/tmp`, leaving out `.git`, every `compiled`
   directory, and `.suite-time`. For example, from the project root:

   ```sh
   COPY=$(mktemp -d /tmp/suite-jobs-proof-XXXXXX)
   tar --exclude=./.git --exclude=compiled --exclude=./.suite-time -cf - . | tar -xf - -C "$COPY"
   ```

   Confirm `find "$COPY" -name compiled` prints nothing.
2. From `$COPY`, run `TMPDIR=/tmp raco test -j 4 -y tests`. This
   builds the copy's bytecode. It must pass. Record its wall time.
   The trial did not run this cold case with the skip in place. If it
   fails, report the failing file and its differences. Do not widen
   the skip or edit another test to make it pass.
3. In `$COPY` only, insert a comment line as line 2 of
   `aloe/eval.rkt`, after `#lang`. Do not append it at the end of
   the file: an appended comment can leave the compiled bytes
   unchanged and prove nothing. Touch a marker file outside `$COPY`.
4. From `$COPY`, run `TMPDIR=/tmp raco test -j 4 -y tests` under
   `/usr/bin/time`. It must pass. Record the wall time, the pass
   count, both medians, and the number of `.zo` files under `$COPY`
   newer than the marker. That number must be nonzero and must
   include `aloe/compiled/eval_rkt.zo`. Otherwise the run did not
   exercise stale bytecode: report that instead of claiming the
   proof.
5. Delete `$COPY`.

Showing the old snapshot failing again is not required. §2.5 records
it.

Finish with `git diff --check` and `git status --short`. Beyond
whatever was already present before the slice, the status lists
only the four permitted files; no `compiled/` path, scratch copy, or
timing log appears. Report the measurements in the
implementation handoff. They are evidence, not new thresholds.

## 5. Non-goals

- A cache or other change to generic method-body checking
- Another comparison-helper repair
- Raising, removing, or widening either Rackunit limit, or the
  string-load-save hand bars
- Moving any `module+ main` hand script into a `test` submodule
- Passing `-s main` to the suite command
- A job count other than 4, `--drdr`, `--place`, `--direct`,
  `--timeout`, or a processor-count default
- Adding `-j` to `bin/suite-time.rkt`, or running that report
  concurrently
- A serial tail, wrapper, runner, Makefile, or second standing
  command
- Skipping any snapshot directory other than `compiled`, or removing
  the before-and-after repository snapshot
- Any other test-file edit. A later trial that shows two files
  colliding on one filesystem path is fixed by giving that case a
  private path, without restyling the test, and needs its own
  approved checkpoint
- A new failing duration check on ordinary files
- Editing `SPEC.md`, `aloe/`, `host/`, `examples/`, `lib/`, or
  historical checkpoints, specs, and charters
- Promoting this series onto `CHECKPOINTS.md`

## 6. Acceptance and stop

The series is accepted only when:

1. `docs/workflow.md`, `AGENTS.md`, and the root `README.md` give
   `TMPDIR=/tmp raco test -j 4 -y <paths>` as the standing command,
   and say that a checkpoint's bare `raco test` still runs with
   `-j 4` and `-y`. The workflow no longer forbids the `-j` it now
   requires.
2. `-y` and `TMPDIR=/tmp` remain in every standing command.
   `compiled/` stays gitignored and uncommitted.
3. Both Rackunit timing files run inside the parallel command with
   unchanged limits. The hand scripts stay `module+ main` and outside
   the suite result.
4. `bin/suite-time.rkt` and its tests are unchanged; the report still
   runs one file at a time.
5. `repository-snapshot` skips only directories named `compiled`,
   the focused fixture test passes, and the launch test still
   compares the whole remaining tree before and after.
6. The full suite passes in the real tree with the new command, and
   the stale-bytecode proof in §4.4 passes on a scratch copy with
   rewritten bytecode.
7. Language law, the checker, the evaluator, the driver, production
   Aloe, and the host runners are unchanged.

The designer stops at this draft. After human acceptance, a manager
receives this file to write **suite-jobs 000** only, then stops. The
implementer completes only that checkpoint, verifies it, and stops
for review.

If you have been told to read this file, this is the whole
assignment.
