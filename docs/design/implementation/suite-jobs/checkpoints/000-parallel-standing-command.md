# suite-jobs 000 — Run four test files at once

**Status: Ready to implement.**

## Goal and stop

Make `TMPDIR=/tmp raco test -j 4 -y <paths>` the standing test command
in the three files that state it. Teach `repository-snapshot` in
`tests/editor/lsp/009-launch.rkt` to skip directories named
`compiled`, so sibling test processes can refresh gitignored bytecode
while that test runs. Prove the skip with one focused fixture test,
the full suite with the new command, and a stale-bytecode run on a
scratch copy.

Stop when this slice is green and its measurements are reported. This
is the only layer in the accepted spec. Do not start a method-body
cache, a helper repair, or a change to the suite-time report.

## Authority, dependencies, and identity

The implementer receives this checkpoint and the accepted spec. The
checkpoint narrows the spec to one slice and does not revise it.

- Identity: `(suite-jobs, 000)`, spoken **suite-jobs 000**. Local
  numbering. Do not edit `CHECKPOINTS.md` or `docs/checkpoints/`.
- Design authority: [`../spec.md`](../spec.md), all of it. §2 is the
  trial evidence; do not rerun the `-j 8` comparison or any part of
  the trial matrix.
- Process and host verification:
  [`docs/workflow.md`](../../../../workflow.md). Read the project-root
  `AGENTS.md`, `SPEC.md`, and `CHECKPOINTS.md` before writing code.
  `SPEC.md` remains Aloe language law and is not touched.
- Snapshot contract: item 10 of
  [`docs/editor/lsp/checkpoints/009-launch.md`](../../../../editor/lsp/checkpoints/009-launch.md).
  The launch must not rewrite source, fixtures, or metadata, or create
  a checked-in launcher or build artifact. Gitignored `compiled/`
  bytecode is none of those.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Run every command there unless a step names the scratch copy. Use
  installed Racket 9.3 and Rackunit. Add no package, wrapper, runner,
  or Makefile.
- Starting point: `main` at `a860e3a`. The human chooses the branch.
  Before this slice, `git status --short` shows exactly:

  ```text
   M docs/design/implementation/suite-time/README.md
  ?? docs/design/implementation/suite-jobs/
  ```

  Leave both as they are.
- Baseline: `TMPDIR=/tmp raco test -y tests/editor/lsp/009-launch.rkt`
  reports 5 tests passed at the starting point. The trial's warm full
  suite reports 2668 tests passed.

If you have been told to read this file, this is the whole assignment,
together with the authority named above.

## Exact file scope

May edit only:

| Path | Permitted change |
|---|---|
| `docs/workflow.md` | The Host verification section's test command and the sentences that explain it |
| `AGENTS.md` | The bullet that begins "Run tests as" |
| `README.md` (root) | The two `raco test` commands in the Bytecode section, one sentence beside the first, and one optional clause in the report description |
| `tests/editor/lsp/009-launch.rkt` | `repository-snapshot`, and one new focused test case |

No new file is needed.

Must leave untouched:

- `bin/suite-time.rkt`, `tests/suite-time/`, and `.suite-time/`
  (do not run the report in this slice);
- every other test file, including `tests/aloemacs/runner-check.rkt`,
  `tests/aloemacs/safe-cell-scan.rkt`,
  `tests/string-load-save/timing.rkt`,
  `tests/aloemacs/index-002-timing.rkt`, and
  `tests/aloemacs/search-timing.rkt`;
- in `009-launch.rkt`: every existing test case, the
  `source-before` capture, the final
  `(check-equal? (repository-snapshot) source-before)`, the
  `info.rkt` byte check, and `call-with-isolated-package-state`;
- `.gitignore`, `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`;
- all of `aloe/`, `host/`, `examples/`, `lib/`, `gel/`, and `bin/aloe`;
- every historical checkpoint, spec, charter, and design README,
  including this folder. Older documents that write `raco test` or
  `raco test -y` stay as written; the standing rule supplies `-j 4`
  and `-y` when they are run.

`compiled/` stays gitignored and uncommitted. Scratch copies and
timing logs live under `/tmp` and are not committed.

If another repository file is necessary, stop and return the
checkpoint to the manager rather than widening its scope.

## Required behavior

### 1. Standing command text

All three files state this exact command string:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

Prose may match each file's voice. Command strings are exact.

**`docs/workflow.md`, Host verification.** Today it reads, in part:

```text
TMPDIR=/tmp raco test -y <paths>
...
`-y` is required. It rebuilds Racket bytecode for changed `.rkt`
modules and for modules that depend on them. A checkpoint that writes
`raco test` without `-y` is still run with `-y`.
...
Do not put `raco make` on every launch. Do not add `-j` unless the
checkpoint asks for it.
```

- The fenced command becomes `TMPDIR=/tmp raco test -j 4 -y <paths>`.
- The paragraph after it keeps its `<paths>` sentence and its `-y`
  sentences. Add that `-j 4` runs up to four test files at once, each
  in its own process. The last sentence says a checkpoint that writes
  `raco test` without `-j` or without `-y` is still run with `-j 4`
  and `-y`.
- Replace "Do not add `-j` unless the checkpoint asks for it." so it
  no longer contradicts the test command: `raco make` gets no `-j`,
  and the test command's job count stays 4, unless a checkpoint asks
  otherwise.
- Keep the `raco make host/racket/aloemacs-run.rkt bin/aloe` block,
  the `compiled/` sentence, and "Do not put `raco make` on every
  launch." Change nothing else in the file.

**`AGENTS.md`.** The bullet that begins "Run tests as" names
`TMPDIR=/tmp raco test -j 4 -y <paths>` from the project root. It
keeps the sentence explaining `-y`. It says to include `-j 4` and
`-y` even when the checkpoint writes `raco test` without them. It
keeps "`TMPDIR=/tmp` is required for agent runs." No other bullet or
paragraph changes.

**Root `README.md`, Bytecode section.**

- `TMPDIR=/tmp raco test -y tests` becomes
  `TMPDIR=/tmp raco test -j 4 -y tests`. Add one sentence, before or
  after that block, saying the command runs up to four test files at
  once.
- `TMPDIR=/tmp raco test -y tests/aloemacs` becomes
  `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs`.
- Keep the `raco make` block, the
  `TMPDIR=/tmp racket bin/suite-time.rkt` block, and the report's
  description. The description may gain one clause saying the report
  stays serial while the ordinary command runs four files at once. It
  must keep the words "runs files serially with
  `raco test -y --process`".
- Keep "The ordinary test commands above do not update this history."
- Change nothing outside the Bytecode section.

### 2. The snapshot skip

The starting walk in `tests/editor/lsp/009-launch.rkt` sorts
`(directory-list directory)` with `path<?`, skips `.git` only when
`relative-directory` is `"."`, and records each entry as
`(list relative-path-string 'directory)` followed by its contents,
`(list relative-path-string 'file bytes)`, or
`(list relative-path-string 'other)`. It always starts at
`normalized-repository-root`.

Change it as follows:

- `repository-snapshot` takes one optional positional root argument
  that defaults to `normalized-repository-root`. The walk starts at
  that root with relative directory `"."`, as today. The two existing
  calls stay `(repository-snapshot)` with no argument.
- While walking, skip an entry whose name is exactly `compiled` and
  which is a directory (`directory-exists?`), at any depth. Record
  neither that directory nor anything under it.
- A regular file named `compiled` is still recorded as a file.
- Keep the root-only `.git` skip. A `.git` below the root is still
  recorded.
- Do not skip any other name. Keep the sort, the walk order, and the
  three entry shapes unchanged.

### 3. Focused fixture test

Add one `test-case` in the same file, for example named
"repository snapshot skips compiled directories only". Place it
before or after the installed-collection test case; do not nest it in
another case.

- Create the root with
  `(make-temporary-directory #:base-dir (string->path "/tmp"))` from
  `racket/file`, which the file already requires. Delete it with
  `delete-directory/files` in a `dynamic-wind` post thunk, so it is
  removed even when a check fails, following the pattern of
  `call-with-isolated-package-state`.
- Build exactly this tree. Give each file distinct, nonempty bytes.

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

- Call `(repository-snapshot root)` and check the whole result with
  one `check-equal?` against this exact list, in this order, where
  each file's bytes are the bytes the test wrote:

  ```text
  ("./a" directory)
  ("./a/.git" directory)
  ("./a/.git/config" file <bytes>)
  ("./a/b.txt" file <bytes>)
  ("./c" directory)
  ("./c/compiled" file <bytes>)
  ("./src.rkt" file <bytes>)
  ```

- Assert no wall-clock limit. Add no driver, host mock, or helper
  module. Do not write into the repository.

Against the starting walk, this test must fail: the starting walk has
no root argument and records both `compiled` directories.

## Verification

Run these in the real tree, in this order.

1. Focused:

   ```sh
   TMPDIR=/tmp raco test -j 4 -y tests/editor/lsp/009-launch.rkt
   ```

   Expect 6 tests passed: the 5 existing cases plus the new one.

2. Full, timed:

   ```sh
   /usr/bin/time -f 'wall=%e user=%U sys=%S' env TMPDIR=/tmp raco test -j 4 -y tests
   ```

   It must pass. Record wall, user, and sys time, the pass count, and
   the two printed medians, "Down-cycle median" and
   "80-column frame median". The expected count is 2669, the trial's
   2668 plus the new case; report the actual count either way. Output
   from concurrent files interleaves, so read the medians from their
   own lines, not from position.

### Stale-bytecode proof

This repeats the trial's failing case on a copy that does not share
the real tree's `compiled/`. Never run it in the real tree, and never
edit the real tree's `aloe/eval.rkt`.

1. Copy the working tree, including the uncommitted edits, into a new
   directory under `/tmp`. Leave out `.git`, every `compiled`
   directory, and `.suite-time`. From the project root:

   ```sh
   COPY=$(mktemp -d /tmp/suite-jobs-proof-XXXXXX)
   tar --exclude=./.git --exclude=compiled --exclude=./.suite-time -cf - . | tar -xf - -C "$COPY"
   find "$COPY" -name compiled
   ```

   The `find` must print nothing.

2. From `$COPY`, run `TMPDIR=/tmp raco test -j 4 -y tests` under the
   same `/usr/bin/time` form. This builds the copy's bytecode. It must
   pass. Record its wall time and pass count. The trial did not run
   this cold case with the skip in place. If it fails, report the
   failing file and its differences. Do not widen the skip or edit
   another test to make it pass.

3. In `$COPY` only, insert a fresh comment line as line 2 of
   `aloe/eval.rkt`, directly after `#lang`. Do not append it at the
   end of the file: an appended comment can leave the compiled bytes
   unchanged and prove nothing. Then touch a marker file outside
   `$COPY`, for example `MARKER=$(mktemp /tmp/suite-jobs-marker-XXXXXX)`.

4. From `$COPY`, run `TMPDIR=/tmp raco test -j 4 -y tests` under
   `/usr/bin/time`. It must pass. Record wall, user, and sys time, the
   pass count, both medians, and

   ```sh
   find "$COPY" -name '*.zo' -newer "$MARKER" | wc -l
   ```

   That count must be nonzero, and the list must include
   `$COPY/aloe/compiled/eval_rkt.zo`. Otherwise the run did not
   exercise stale bytecode: report that instead of claiming the proof.

5. Delete `$COPY` and the marker.

Showing the old snapshot failing again is not required. Spec §2.5
records it.

### Finish

```sh
git diff --check
git status --short
```

`git diff --check` passes. Beyond the two starting lines above,
`git status --short` lists only the four permitted files. No
`compiled/` path, scratch copy, marker, or timing log appears.

## Acceptance

The slice is complete only when:

1. `docs/workflow.md`, `AGENTS.md`, and the root `README.md` give
   `TMPDIR=/tmp raco test -j 4 -y <paths>` (the README with `tests`
   and `tests/aloemacs`) and say a bare `raco test` in a checkpoint
   still runs with `-j 4` and `-y`. The workflow no longer forbids
   the `-j` it now requires, and `raco make` still gets no `-j`.
2. `-y` and `TMPDIR=/tmp` remain in every standing command.
   `compiled/` stays gitignored and uncommitted.
3. Both Rackunit timing files ran inside the parallel full run, with
   unchanged files and limits. The three `module+ main` hand scripts
   are unchanged and outside the suite result. No `-s main` anywhere.
4. `bin/suite-time.rkt` and `tests/suite-time/` are unchanged.
5. `repository-snapshot` skips only directories named `compiled`,
   still skips only the root `.git`, and both existing calls still
   compare the whole remaining repository before and after the
   launch.
6. The focused test passes with 6 tests, the full real-tree run
   passes, and both scratch-copy runs pass, the second with rewritten
   bytecode that includes `aloe/compiled/eval_rkt.zo`.
7. `git diff --check` passes and the only intentional edits are the
   four permitted files.

## Handoff

Report:

- the four changed files;
- the focused pass count;
- the real-tree full run: wall, user, sys, pass count, both medians;
- the cold scratch-copy run: wall and pass count;
- the stale scratch-copy run: wall, user, sys, pass count, both
  medians, and the `.zo` count newer than the marker, confirming
  `eval_rkt.zo` is among them.

These are evidence, not new thresholds. Stop for human review when
green. Do not write or start another checkpoint.

## Explicit non-goals

- A job count other than 4, `--drdr`, `--place`, `--direct`,
  `--timeout`, or a processor-count default
- A serial tail, wrapper, runner, Makefile, or second standing command
- `-j` in `bin/suite-time.rkt`, or running that report concurrently
- Raising, removing, or widening either Rackunit limit, or the
  string-load-save hand bars
- A `test` submodule for any `module+ main` hand script, or `-s main`
  in the suite command
- Skipping any snapshot directory other than `compiled`, or removing
  the before-and-after snapshot
- Any other test-file edit, including a collision fix for another
  file; that needs its own approved checkpoint
- A new failing duration check on ordinary files
- A method-body cache, a comparison-helper repair, or any change to
  the checker, evaluator, driver, host runners, or production Aloe
- Updating historical documents that write `raco test -y`
- A global checkpoint entry, language feature, Gel, or Boids work
