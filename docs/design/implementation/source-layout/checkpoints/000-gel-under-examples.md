# source-layout 000 — The Gel tree under `examples/gel/`

**Status.** Implemented 2026-10-19 by an implementer conversation:
the three greps print nothing, the named tests and the whole suite
pass (4992 tests), `git diff --check` is clean. The human ran the
TTY hand check the same day and it passed.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Move `gel/`, as one unit, to `examples/gel/`. Rewrite every reference
to the old path with one anchored substitution. Rewrite by hand the
two test lines that name the folder without a trailing slash, which
the substitution cannot reach: the census directory list and one
runtime path. Amend the one line of `docs/gel.md` that placed the
tree and the one spec row that lists the census directories. Keep the
whole suite green. Stop.

After this checkpoint, `ls` at the project root prints exactly these
fourteen entries:

```text
AGENTS.md  CHECKPOINTS.md  README.md  SPEC.md  aloe  archive  bin  docs  editors  examples  host  info.rkt  lib  tests
```

and `ls examples` prints exactly these five:

```text
aloemacs  boids.aloe  gel  mpl  point.aloe
```

Nothing about Aloe, the Gel program, what the runners do, what the
manifests declare, or the language server changes. No test file is
added, and the suite has the same number of tests before and after.

## Why this shape

Gel is a program written in Aloe with its own folder, its own
`aloe-hosts.rktd`, and its own runner under `host/racket/`. That is
the shape of aloemacs, which lives at `examples/aloemacs/`. Gel sits
at the top of the tree only because it was written before `examples/`
held applications. The root `README.md` says libraries and programs
grow the rest of the language from `lib/` and `examples/`, lists
`boids.aloe` and `mpl/` under `examples/`, and never mentions
`gel/`.

The only recorded decision about where Gel lives is section 8 of
`docs/gel.md`: not in `lib/` until a second application wants the
code, and beside the host runner as its own Aloe tree. The move keeps
Gel out of `lib/` and keeps it one tree. The sentence that placed the
tree beside `host/` is amended below; that file says informal chat is
how it is amended.

The folder path is not part of any identity. Checkpoints 58 through
82 are still spoken that way, `tests/checkpoint-N.rkt` stays where it
is, and `host/racket/gel-run.rkt` keeps its name and place.

Nothing inside the folder changes. The four `.aloe` files load each
other by a name resolved from the loading file, as modules 000 wrote
into `SPEC.md`, and none loads a file under `lib/`. The manifest names `host/racket/term` as a
collection path, which `aloe/host-manifest.rkt` resolves without
regard to the manifest's depth; `examples/aloemacs/aloe-hosts.rktd`
already proves that at the new depth. The five files move
byte-identical.

Unlike docs-layout 000 and 001, the substitution here must be
anchored. The string `gel/` also occurs inside `tests/gel/` and
`docs/gel/`, on 45 lines of editor and spine records. Those name
folders on experiment branches that this move does not touch, and
they must not become `tests/examples/gel/`.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` is unchanged and stays the language law.
[`docs/gel.md`](../../../../gel.md) stays law for the Gel phase; this
slice amends one bullet of it and nothing else in it.
[`docs/workflow.md`](../../../../workflow.md) is the conversation
pipeline and is untouched.

- Identity is **source-layout 000**. File:
  `docs/design/implementation/source-layout/checkpoints/000-gel-under-examples.md`.
  Local numbering. Do not add a global checkpoint or a
  `CHECKPOINTS.md` entry; `CHECKPOINTS.md` changes by the substitution
  only. Do not issue 001.
- Predecessors. docs-layout 000, at `9cf7ce9`, added
  `tests/docs-layout/links.rkt`, which fails on a broken relative
  Markdown link outside a fenced block; it is one gate for this slice
  and runs in about a second. docs-layout 001, at `473863a`, moved a
  folder by the same method: `git mv`, one textual substitution,
  listed hand edits. modules 000 wrote into `SPEC.md` that `load`
  resolves a relative path from the loading file, which is why the
  four Gel files move unchanged. host-queries 002, at
  `85f92c4`, bound the two manifests to the language server; its
  tests use `gel/main.aloe` as the `term` fixture and are the other
  gate.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Starting point: the working tree at `16519fb` on
  `experiment/2026-10-16-host-queries`, or a later commit. Before
  moving anything, confirm the inventory:
  - `gel/` holds five files: `aloe-hosts.rktd`, `loop.aloe`,
    `main.aloe`, `menu.aloe`, `stack.aloe`. None of them contains the
    string `gel/`.
  - The anchored pattern under **Path substitution** matches 293
    lines in 135 files outside `.git/`, `compiled/`, `node_modules/`,
    and `.suite-time/`:

    | Area | Files | Lines |
    |---|---|---|
    | `CHECKPOINTS.md` | 1 | 3 |
    | `docs/gel.md` | 1 | 4 |
    | `host/racket/gel-run.rkt` | 1 | 2 |
    | `tests/` | 28 | 78 |
    | `docs/design/` | 99 | 194 |
    | `archive/` | 5 | 12 |

    The 28 test files are `tests/checkpoint-58.rkt`, `-59`, `-61`
    through `-63`, `-65` through `-82`, and `-86`; the two under
    `tests/editor/host-queries/`; and `tests/modules/001-census.rkt`
    and `006-file-environments.rkt`. Apart from the two census rows,
    every test line is a `define-runtime-path`.
  - One more test file names the folder with no trailing slash.
    `tests/checkpoint-114.rkt` has
    `(define-runtime-path gel-directory "../gel")` and walks it with
    `find-files`. The pattern does not reach it. It is a hand edit
    below.
  - The plain string `gel/` matches 45 further lines, all `tests/gel/`
    or `docs/gel/`, in editor and spine records, and in one further
    file, `docs/design/implementation/spine/0.3-language-merge.md`,
    which has no anchored match.
  - The bare word `gel` as a directory name occurs in two more
    places, both hand edits below: the `census-directories` list in
    `tests/modules/001-census.rkt` and the Census row of the table in
    `docs/design/implementation/editor/host-queries/spec.md`. The
    string `gel: ` in `host/racket/gel-run.rkt` and in the 0086
    record is the runner's error prefix, not a path, and stays.
  - `README.md`, `SPEC.md`, `AGENTS.md`, `docs/workflow.md`, and
    `docs/handoff.md` do not contain `gel/`.

  If the inventory differs, stop and report the difference.
- The discussion dry-ran this checkpoint on 2026-10-19 on a copy of
  the starting tree. The first pass had only the substitution and the
  census edit, and `tests/checkpoint-114.rkt` raised `path
  disappeared` on `tests/../gel`; that is how the fourth hand edit
  was found. **Verification and completion** records the final run.

## The move

```sh
git mv gel examples/gel
```

The whole folder, five files, names unchanged. No file is renamed. No
stub, symlink, or redirect is left at `gel/`.

## Path substitution

In every text file in the tree outside `.git/`, `compiled/`,
`node_modules/`, and this checkpoint's folder, replace each match of
the pattern with the new string:

| Pattern (Perl syntax) | New string |
|---|---|
| `(?:(?<![\w/])\|(?<=\.\./))gel/` | `examples/gel/` |

In words: `gel/` where the character before it is neither a word
character nor a slash, or where the three characters before it are
`../`. That reaches every spelling in the tree: the bare path in
prose, code spans, and fenced blocks; the path inside double quotes
in a `.rkt` test, the runner, and `archive/misc-examples.aloe`; and
`../gel/` at every depth. It does not reach `tests/gel/` or
`docs/gel/`, where a slash precedes `gel/`. It does not reach its own
output, `examples/gel/`, for the same reason, so a second pass
changes nothing.

Inserting `examples/` after any run of `../` is right at every depth
because `gel/` and `examples/` are siblings at the project root. So
every `define-runtime-path` and the two Markdown links in
`docs/design/implementation/aloemacs/loop/charter.md` are rewritten
by the substitution and still resolve; no relative target needs a
hand edit. The shapes present, counted as occurrences, not lines:

| Shape | Occurrences | Where |
|---|---|---|
| `gel/` with no `../` | 236 | prose, fenced blocks, the two census rows, the archive |
| `../gel/` | 70 | `tests/checkpoint-NN.rkt` |
| `../../gel/` | 7 | `host/racket/gel-run.rkt`, `tests/modules/006-file-environments.rkt`, one line of the modules 006 record quoting it |
| `../../../gel/` | 2 | the two `tests/editor/host-queries/` tests |
| `../../../../../gel/` | 3 | the two link lines in the aloemacs loop charter |

From the project root, the substitution is:

```sh
grep -rlP --exclude-dir=.git --exclude-dir=compiled --exclude-dir=node_modules --exclude-dir=source-layout '(?:(?<![\w/])|(?<=\.\./))gel/' . | xargs perl -pi -e 's{(?:(?<![\w/])|(?<=\.\./))gel/}{examples/gel/}g'
```

`grep` on this machine is `ugrep`, which accepts `-P`. Any tool that
applies the same Perl pattern to the same files is equivalent.

The replacement is textual and applies inside code spans, fenced
blocks, link text, link targets, Racket strings, and comments alike.
It rewrites historical records, including the spine checkpoints 0072
through 0082 that created the files, the modules and host-queries
records, and the merge records and archive sketches that name Gel
files which exist only on experiment branches (`gel/directory.aloe`,
`gel/presentations.aloe`, `gel/run.aloe`). Those become
`examples/gel/…` too: that is where such a file would sit now. This
is the docs-layout practice, and it keeps the verification grep
clean.

Exclude this checkpoint's own folder,
`docs/design/implementation/source-layout/`, from the substitution
and from the grep in **Verification**. It names the old path on
purpose.

## Hand edits

Four. Each is found by its text, not by a line number.

### The census directory list

`tests/modules/001-census.rkt` walks a list of directories for every
`.aloe` file and issues one test per file. After the move, a walk
over `gel/` would raise on a missing directory, and the walk over
`examples/` already reaches the four Gel files. Change

```racket
(define census-directories '("examples" "lib" "gel" "tests"))
```

to

```racket
(define census-directories '("examples" "lib" "tests"))
```

The census still counts the same four files, so the number of tests
in that file, and in the suite, does not change. The census files are
sorted by path, so the four Gel tests run at a different position in
that file's order; nothing depends on the order. The two rows of
`expected-leading-loads` that name Gel files are rewritten by the
substitution, not here.

### The Gel directory walk in checkpoint 114

`tests/checkpoint-114.rkt` proves that no Gel file defines `String`
methods by walking the Gel folder. Change

```racket
(define-runtime-path gel-directory "../gel")
```

to

```racket
(define-runtime-path gel-directory "../examples/gel")
```

The test case `String method definitions remain outside Gel` then
walks the moved folder, as before. Nothing else in that file changes.

### The census row of the host-queries spec

In `docs/design/implementation/editor/host-queries/spec.md`, the
table under the layer summary has a row that begins `| Census |`. In
that row, change

```text
under `examples`, `lib`, `gel`, and `tests`
```

to

```text
under `examples`, `lib`, and `tests`
```

Nothing else in that file changes beyond the substitution.

### The placement bullet in `docs/gel.md`

In section 8, **Decisions**, the bullet reads today:

```markdown
- Do not put Gel in `lib/` until a second application wants the same
  code. Keep it beside the host runner (`host/` and a Gel Aloe tree).
```

Replace the whole bullet with:

```markdown
- Do not put Gel in `lib/` until a second application wants the same
  code. Its Aloe tree is `examples/gel/`, beside the other programs
  (source-layout 000, 2026-10-19); its runner stays in `host/`.
```

Nothing else in that file changes beyond the substitution, which
rewrites the four file mentions in section 5.

## Exact file scope

### May edit

- `examples/gel/` (moved): the git index only, through `git mv`. The
  five files' contents do not change.
- `host/racket/gel-run.rkt`: the substitution only, two
  `define-runtime-path` lines.
- `tests/modules/001-census.rkt`: the substitution and the
  `census-directories` edit.
- `tests/checkpoint-114.rkt`: the one `define-runtime-path`.
- The other 27 test files named under **Starting point**: the
  substitution only.
- `docs/gel.md`: the substitution and the one bullet.
- `docs/design/implementation/editor/host-queries/spec.md`: the
  substitution and the one row.
- Every other text file outside `.git/`, `compiled/`, and
  `node_modules/`, including `CHECKPOINTS.md`, every series folder,
  the spine, and `archive/`: the substitution only.

### Must leave untouched

- The content of the five moved files. `git diff -M` must show each
  as a pure rename.
- `README.md`, `SPEC.md`, `AGENTS.md`, `docs/workflow.md`, and
  `docs/handoff.md`. The pattern does not match in them. If the
  substitution would change one, stop and report.
- `aloe/`, including `aloe/host-manifest.rkt`; every module under
  `host/racket/` beyond the two lines in `gel-run.rkt`;
  `editors/vscode/`; `bin/`; `lib/`.
- `tests/docs-layout/links.rkt`, and every test beyond the
  substitution, the census list, and the one `define-runtime-path`
  in `tests/checkpoint-114.rkt`.
- What either manifest declares. The comment line in
  `examples/gel/aloe-hosts.rktd` names the host-queries spec, not the
  Gel folder, and is unchanged.
- Any line that spells `tests/gel/` or `docs/gel/`.
- This folder, `docs/design/implementation/source-layout/`, including
  its `README.md`, and the map at
  `docs/design/implementation/README.md`. The human refreshes their
  status lines after review.

If another file or another kind of edit is necessary, stop and send
this checkpoint back to the high-level discussion. Do not widen the
slice.

## Verification and completion

From the project root:

```sh
ls
ls examples
ls examples/gel
git status --short | grep -E '^(.?D|\?\?)'
grep -rnP --exclude-dir=.git --exclude-dir=compiled --exclude-dir=node_modules --exclude-dir=source-layout '(?:(?<![\w/])|(?<=\.\./))gel/' .
grep -rn --exclude-dir=.git --exclude-dir=compiled --exclude-dir=node_modules --exclude-dir=source-layout 'gel/' . | grep -vE 'examples/gel/|tests/gel/|docs/gel/'
grep -rnE --exclude-dir=.git --exclude-dir=compiled --exclude-dir=node_modules --exclude-dir=source-layout '"(\.\./)*gel"|`gel`' .
grep -n 'census-directories ' tests/modules/001-census.rkt
TMPDIR=/tmp raco test -j 4 -y tests/docs-layout/links.rkt
TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-114.rkt tests/modules tests/editor/host-queries
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Completion:

- `ls` prints the fourteen entries shown under **Goal** and nothing
  else; `ls examples` prints the five; `ls examples/gel` prints the
  five files named under **Starting point**.
- The `git status` line prints nothing: no path is deleted and no
  file is untracked. The move appears as five `R` lines, the rest as
  modifications.
- The first `grep` prints nothing: the anchored pattern no longer
  matches anywhere outside this checkpoint's folder.
- The second `grep` prints nothing: every remaining `gel/` is
  `examples/gel/`, `tests/gel/`, or `docs/gel/`.
- The third `grep` prints nothing: no quoted path and no code span
  names the folder without its new prefix.
- The `census-directories` line shows the three-element list.
- `tests/docs-layout/links.rkt` passes, which proves the two
  rewritten links in the aloemacs loop charter resolve.
- `tests/checkpoint-114.rkt`, `tests/modules`, and
  `tests/editor/host-queries` pass, which proves the directory walk,
  the census walk, and the `term` manifest fixture at the new depth.
- The whole suite passes with the same number of tests as the
  starting tree. The `tests/aloemacs/window-pictures.rkt` timing bar
  has failed under `-j 4` before on a loaded machine and passed
  alone; if it is the only failure, run that file alone.
- `git diff --check` is clean.
- `git diff -M` over the moved files shows five pure renames. Over
  every other file it shows only lines that contain `examples/gel/`
  or `examples/gel"`, the census list, the spec row, or the
  `docs/gel.md` bullet.

For comparison, the discussion's dry run on 2026-10-19, on a copy of
`16519fb` with every edit above applied, counted 4992 tests, the
same as the untouched tree, which passed all 4992. The copy is not a
linked package, so collection paths resolve to the original
checkout; that makes the manifest cases in
`tests/editor/host-queries/001-manifest-reader.rkt` and
`002-lsp-hosts.rkt` fail on a copy unless `PLTCOLLECTS` names it,
and makes the package-link case in `tests/editor/lsp/009-launch.rkt`
fail when it does. Run both ways, every test passed in one of the
two runs, and no failure named a moved path. On the real tree
neither artifact exists, and the suite is expected green in one run.

Stop. Do not commit. Do not issue 001.

## Hand check

The hand check is the human's, as in host-queries 002, because it
needs a real TTY. From the project root, after the implementer stops:

```sh
racket host/racket/gel-run.rkt
```

The runner prints a `TOS:` line for `(Point new 10 20)` and the
numbered menu. Press the digit shown for `x`: the transcript echoes
the key and the new `TOS:` line shows `10`. Press `q`: the runner
leaves with the terminal restored. That is the keystroke path
`docs/gel.md` section 10 asks for.

Optional: open `examples/gel/main.aloe` in VS Code and hover `term`
in `(term write-line`. The hover shows the `term` host's interface,
which proves the language server finds the manifest at the new
depth.

## Non-goals

- A line for `examples/gel/` or `examples/aloemacs/` in the root
  `README.md` layout list. Neither is listed today; adding one is a
  separate edit.
- Moving `host/racket/gel-run.rkt`, `term-run.rkt`, or any runner.
  The runners stay under `host/racket/` with their effects rule.
- The host-runner discussion's `gel/run.aloe` idea, or any change to
  how Gel is started.
- Renaming a Gel file, class, or selector; renumbering any
  checkpoint; renaming `tests/checkpoint-N.rkt`.
- Touching, rebasing, or merging the Gel experiment branches
  (`experiment/gel-directory-surface`,
  `experiment/2026-09-11-gel-presentations`). Their `gel/` is their
  own.
- Rewriting any `tests/gel/` or `docs/gel/` mention.
- A stub, symlink, or redirect at `gel/`.
- An `examples/README.md`.
- Any change to the census beyond the directory list.
- Refreshing the status prose of `docs/handoff.md`.
- Any change to `tests/docs-layout/links.rkt`.
