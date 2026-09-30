# racket-bytecode 000 — gitignore bytecode and test with `-y`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Make Racket bytecode a local build product, and make every test run
refresh it.

Add a root `.gitignore` that ignores `compiled/`. Document one
standing test command, `TMPDIR=/tmp raco test -y <paths>`, in
`AGENTS.md`, `README.md`, and `docs/workflow.md`. Document
`raco make host/racket/aloemacs-run.rkt bin/aloe` as the rebuild for
a launch when the suite is not being run. Leave launch commands as
they are. Stop.

This slice does not change Aloe, the editor, or the runners.

## Why this command

Ordinary `racket` on this tree does not write `.zo` files. A require
of `aloe/driver.rkt` took about 2.35 seconds and left no bytecode.
`raco test` on a directory starts one process per file and, unless
`-j` is passed, runs those processes one at a time. Almost every test
file loads the Aloe Racket modules, so each file pays that startup.

`raco make` writes bytecode next to the sources. On a copy of this
tree it took about 3.4 seconds the first time and about 0.55 seconds
when nothing had changed. After that, `./bin/aloe --quit
examples/point.aloe` took about 0.23 seconds, and Aloemacs reached
its first frame in about 0.3 seconds. Those later numbers are from
the diagnosis that motivated this checkpoint. The implementer's own
timing check is below.

`-y` is required for correctness, not only for speed. Racket's
`use-compiled-file-check` is `modify-seconds`. An edited `.rkt` file
is loaded from source. An unedited module whose `.zo` is newer than
its source keeps that `.zo`, even when a module it requires has
changed. A two-module check showed the failure: compile `b.rkt` which
requires `a.rkt`, edit `a.rkt`, and a test that still expects `b`'s
old behavior **passes** under `raco test`. The same test under
`raco test -y` runs the new `a.rkt`. The test command is how an agent
that edits `.rkt` and then runs tests both notices the stale graph
and rewrites it.

`raco make` of the two entry points compiles the modules those
entries require (`aloe/driver.rkt`, `aloe/eval.rkt`, `aloe/type.rkt`,
the terminal and filesystem hosts, and so on). It does not compile
`aloe/main.rkt`, `aloe/lsp.rkt`, or the test modules. `raco test -y`
compiles those when a test loads them.

Editing only `.aloe` files does not invalidate this bytecode. The
interpreter reads those files at run time.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` is unchanged and stays the language law.
[`docs/workflow.md`](../../../workflow.md) is the conversation
pipeline; this slice adds a host-verification section and does not
change the roles.

- Identity is **racket-bytecode 000**. No predecessor. No 001.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- There is no root `.gitignore`. `editors/vscode/.gitignore` ignores
  `node_modules/` and `*.vsix` only. Leave that file alone.
- `AGENTS.md` tells an implementer to add tests and run them. It does
  not name `raco test` or `-y`.
- `README.md`'s Driver section gives `./bin/aloe` and does not mention
  bytecode.
- `docs/workflow.md` tells an implementer to run the verification
  named in the checkpoint. It does not name the Racket command.
- Launch commands that must remain, character for character, as ways
  to start a program:
  - `./bin/aloe`
  - `./bin/aloe examples/boids.aloe`
  - `./bin/aloe --quit examples/boids.aloe`
  - `racket host/racket/aloemacs-run.rkt`
  - `racket host/racket/aloemacs-run.rkt` with a path argument

Do not re-measure the two-module stale-bytecode case. It is settled.

## Exact file scope

### May edit

- `.gitignore` (new, at the project root)
- `AGENTS.md`
- `README.md`
- `docs/workflow.md`

### Must leave untouched

- `aloe/`, `host/`, `bin/`, `lib/`, `examples/`, `tests/`, `gel/`,
  `editors/`
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, and every
  historical checkpoint that already says `raco test` without `-y`
- This folder's `README.md` and this checkpoint
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion. Do not widen the slice.

The `compiled/` directories created by the hand check stay in the
working tree. Do not delete them. Do not `git add` them.

## Required behavior

### `.gitignore`

Create a root `.gitignore` whose only line is:

```gitignore
compiled/
```

The pattern has no leading slash, so it matches a directory named
`compiled` anywhere in the tree. Do not add other ignore rules.

### `AGENTS.md`

Keep the existing bullets. Immediately after

> Add tests in the same change. Run them. Stop when green.

add these three bullets, in this order:

- Run tests as `TMPDIR=/tmp raco test -y <paths>` from the project
  root. `-y` rebuilds bytecode for `.rkt` files that changed and for
  modules that depend on them. Include `-y` even when the checkpoint
  writes `raco test` without it. `TMPDIR=/tmp` is required for agent
  runs.
- Do not commit `compiled/`. It is gitignored.
- `./bin/aloe` and `racket host/racket/aloemacs-run.rkt` load existing
  bytecode and do not rebuild it. After a `.rkt` edit, run the test
  command, or `raco make host/racket/aloemacs-run.rkt bin/aloe`,
  before launching. Editing only `.aloe` files needs no rebuild.

Do not rewrite the language-law bullets.

### `README.md`

Immediately after the Driver section (after the paragraph that ends
with "still available."), add this section before `## 0.1 goal`.
Copy it as written, including the heading.

~~~~markdown
## Bytecode

Racket bytecode is written under `compiled/` next to the sources and
is gitignored. Refresh it before a launch when `.rkt` files have
changed and you are not about to run the tests:

```sh
raco make host/racket/aloemacs-run.rkt bin/aloe
```

Tests refresh bytecode for the modules they load, including test-only
modules the command above does not reach:

```sh
TMPDIR=/tmp raco test -y tests
```

A narrower path works the same way:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs
```

`./bin/aloe` and `racket host/racket/aloemacs-run.rkt` load that
bytecode and do not rebuild it. A launch, or a test run that omits
`-y`, can load an old `.zo` of a module that was not itself edited,
so the run does not match the sources.
~~~~

Leave the Driver launch commands unchanged.

### `docs/workflow.md`

Immediately after the Implementer subsection (after the paragraph
that ends with "unless the checkpoint says so."), and before
`## Checkpoint size`, add this section. Copy it as written, including
the heading.

~~~~markdown
## Host verification

From the project root, tests are:

```sh
TMPDIR=/tmp raco test -y <paths>
```

`<paths>` is the checkpoint's test file, then any wider suite that
checkpoint names. `-y` is required. It rebuilds Racket bytecode for
changed `.rkt` modules and for modules that depend on them. A
checkpoint that writes `raco test` without `-y` is still run with
`-y`.

`compiled/` is gitignored. Do not commit it.

`./bin/aloe` and `racket host/racket/aloemacs-run.rkt` load bytecode
and do not rebuild it. After a `.rkt` edit, run the test command, or:

```sh
raco make host/racket/aloemacs-run.rkt bin/aloe
```

before launching. `.aloe` edits do not need that rebuild. Do not put
`raco make` on every launch. Do not add `-j` unless the checkpoint
asks for it.
~~~~

Do not change the pipeline diagram, the role definitions, or the
handoff table.

## Tests

No new Rackunit file. The proof is the hand check. Do not add a test
that shells out to `git` or `raco`.

## Verification and completion

From the project root:

```sh
raco make host/racket/aloemacs-run.rkt bin/aloe
git check-ignore -q aloe/compiled/driver_rkt.zo
git check-ignore -q host/racket/compiled/aloemacs-run_rkt.zo
TMPDIR=/tmp raco test -y tests/checkpoint-1.rkt
git check-ignore -q tests/compiled/checkpoint-1_rkt.zo
git status --short
/usr/bin/time -f 'aloe wall=%e' ./bin/aloe --quit examples/point.aloe
git diff --check
```

If a `.zo` name differs from the three paths above, ignore one real
`.zo` under each of `aloe/compiled/`, `host/racket/compiled/`, and
`tests/compiled/` instead. The rule being proved is the directory
name `compiled`, not one spelling of a bytecode file.

Completion:

- `raco make` exits 0.
- Each `git check-ignore -q` exits 0.
- `tests/checkpoint-1.rkt` passes.
- `git status --short` lists no path under a `compiled/` directory.
  Ignored bytecode must not appear there. This checkpoint's own
  untracked files, and the four files in scope, may appear.
- `./bin/aloe --quit examples/point.aloe` exits 0 with wall time
  under 1 second. Record the time. If it is 1 second or more, stop
  and report that number. Do not start a further performance change.
- `git diff --check` is clean.

Stop. Do not issue 001.

## Non-goals

- A wrapper script, a Makefile, or `raco make` inside `bin/aloe` or
  `host/racket/aloemacs-run.rkt`
- `raco demod`, a long-lived process, or `-j` as a default
- Editing historical checkpoints, specs, or charters so they mention
  `-y`
- Committing `.zo` or `.dep` files
- Any change to Aloe semantics, host capabilities, or editor behavior
