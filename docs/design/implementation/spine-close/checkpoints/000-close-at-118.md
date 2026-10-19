# spine-close 000 — Close the global numbering at 118 and move its index

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Move `CHECKPOINTS.md` from the project root to
`docs/design/implementation/spine/CHECKPOINTS.md`. Rewrite every link
to it, and every root-relative link inside it. Record, in
`docs/workflow.md`, `AGENTS.md`, the root `README.md`, the spine map,
and the implementation map, that the global checkpoint numbering
closed at 118 and that every series, kernel work included, uses the
one folder shape. Keep `tests/docs-layout/links.rkt` green. Stop.

After this checkpoint, the project root holds exactly these files:

```text
AGENTS.md  README.md  SPEC.md  info.rkt
```

Nothing about Aloe, the editor, the runners, or the tests changes.
No executable file changes.

## Why this shape

`CHECKPOINTS.md` is the index of the global checkpoint spine: 405
lines, one entry per number from 1 to 118. The spine's documents and
briefs already live under `docs/design/implementation/spine/`, with a
map in that folder's `README.md` that points back out to the index at
the root. The index belongs beside them.

The numbering itself is closed because practice closed it. Since
2026-09-19, five kernel and library changes went through series
folders with `(project, number)` identity: int-methods, string-load-save,
parenthetical-construction, `with`, and modules. The only global
number taken in that time was 118, on 2026-10-18. The clause in
`docs/workflow.md` and in many series READMEs that a human may
promote a local series onto `CHECKPOINTS.md` has never been used. So
the fork in `docs/workflow.md` between a "language spine" shape and a
"local project" shape describes a choice nobody makes. This slice
removes the fork and says so.

The file keeps its name. About 390 lines across the tree mention
`CHECKPOINTS.md` by bare name, almost all in historical checkpoints
and READMEs. The name stays unique and true, so those lines are not
touched. Only links change.

The index and the spine map stay separate files. The map is a short
table of ranges; the index is the long per-number record. They read
differently.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` is unchanged and stays the language law.
[`docs/workflow.md`](../../../../workflow.md) is the conversation
pipeline; this slice rewrites two of its passages, quoted below, and
nothing else in it.

- Identity is **spine-close 000**. File:
  `docs/design/implementation/spine-close/checkpoints/000-close-at-118.md`.
  Local numbering. Do not issue 001.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Starting point: the working tree at `5648f5e` or a later commit.
  Before changing anything, confirm the inventory. The project root
  holds exactly `AGENTS.md`, `CHECKPOINTS.md`, `README.md`,
  `SPEC.md`, and `info.rkt`. `CHECKPOINTS.md` is 405 lines. No file
  other than Markdown names it. `docs/design/implementation/` holds
  fourteen folders, every one listed in its `README.md`. The Markdown
  links to `CHECKPOINTS.md` outside fenced blocks are the 25 listed
  under **Links to the index**. If the inventory differs, stop and
  report the difference.
- `tests/docs-layout/links.rkt` (from docs-layout 000) scans every
  Markdown file for a broken relative link. It is the gate for this
  slice. It passes on the starting tree and runs in about one second.
- Each edit below quotes the text it replaces. Confirm that each
  quoted text occurs exactly once in its file before editing. If one
  does not, stop and report that file.

## The move

```sh
git mv CHECKPOINTS.md docs/design/implementation/spine/CHECKPOINTS.md
```

Name unchanged. No stub or redirect is left at the root.

## Links inside the index

The index links by paths written from the project root. From its new
folder those no longer resolve. In
`docs/design/implementation/spine/CHECKPOINTS.md`, edit link targets
only, never link text:

| Target begins with | Becomes | Count |
|---|---|---|
| `docs/design/implementation/spine/checkpoints/` | `checkpoints/` | 22 |
| `docs/design/implementation/editor/README.md` | `../editor/README.md` | 1 |

Find each by its target string inside a link, not by searching the
whole file: the first string also occurs in link text, which stays. Then, immediately after the heading line
`# Aloe 0.1 checkpoints` and the blank line that follows it, insert
this paragraph and one blank line. Copy it as written.

```markdown
This index is closed at checkpoint 118 (2026-10-19). No further
global number is issued. New work, kernel work included, is a series
folder under `docs/design/implementation/`; the map of those series is
[`../README.md`](../README.md).
```

Nothing else in the index changes.

## Links to the index

Twenty-five links outside fenced blocks, in five classes. Four of the
classes are single links inside passages this checkpoint rewrites
anyway; they are covered by those rewrites and listed here only so
the count closes.

Depth, for checking the arithmetic:

| From | To the project root | To `spine/` |
|---|---|---|
| `docs/design/implementation/<project>/checkpoints/` | `../../../../../` | `../../spine/` |
| `docs/design/implementation/aloemacs/<layer>/checkpoints/` | `../../../../../../` | `../../../spine/` |

### Two target substitutions, 21 links

Across every `.md` file under `docs/design/implementation/`, edit
link targets only. Each old target below occurs only as a link
target, so a plain substitution of the string is safe.

| Target | Becomes | Where |
|---|---|---|
| `../../../../../../CHECKPOINTS.md` | `../../../spine/CHECKPOINTS.md` | 17 links, all in aloemacs layer checkpoints: `completion-page` 1, `mode-line` 2, `prompt-commands` 3, `window-bars` 2, `window-point` 1, `windows` 8 |
| `../../../../../CHECKPOINTS.md` | `../../spine/CHECKPOINTS.md` | 4 links: `checker-recursion/checkpoints/` 1, `parenthetical-construction/checkpoints/` 3 |

Link text, which spells the bare name, is left as it is. Do not let
the second substitution reach the first pattern: apply the longer
target first, or anchor each on its full string.

### Four links covered by the rewrites below

- `README.md` at the root: the Layout bullet.
- `docs/workflow.md`: the "Where files live" table.
- `docs/design/implementation/README.md`: the identity paragraph.
- `docs/design/implementation/spine/README.md`: the first paragraph.

Links to the index inside fenced blocks, in the docs-layout
checkpoints that quote earlier versions of the two maps, are not
scanned by the test and are not edited. They are history.

## `docs/workflow.md`

Two passages change and nothing else.

### The identity paragraph

Replace

```markdown
Identity is either a global number (`checkpoint 103`) or
`(project, number)` spoken **project 000** (for example
`editor-lsp 000`). Do not mix local project work into
`CHECKPOINTS.md` or `docs/design/implementation/spine/checkpoints/` unless the work is actually
on the language spine.
```

with

```markdown
Identity is `(project, number)`, spoken **project 000** (for example
`editor-lsp 000`), or `(project-layer, number)` under a layered map.
A global number (`checkpoint 103`) is historical: the spine closed at
118 on 2026-10-19, and no further global number is issued. Nothing
new is written under `docs/design/implementation/spine/`.
```

### The "Where files live" section

Replace the whole section, from the line `## Where files live` up to
but not including the line `## Handoff`, with the text below. Copy it
as written. It keeps the folder shape, the layer rule, the tests
rule, and the editor-map rule from the old "Local project"
subsection, drops the "Language spine" table, and adds the closing
note.

~~~~markdown
## Where files live

One shape for every series, kernel work included:

```text
docs/design/implementation/<project>/
  README.md              map entry / status
  charter.md             designer assignment (if shape is open)
  spec.md                designer output
  checkpoint-manager.md  optional; manager assignment for 000
  checkpoints/000-slug.md
```

A project that still has open shape questions may use a subfolder
per layer (`text/`, `term/`, …) under that root, each with its own
charter, spec, and `checkpoints/`. Identity remains
`(project, number)` or `(project-layer, number)`.

Tests sit under `tests/<project>/`, not `tests/checkpoint-N.rkt`.

The map of every series is
[`docs/design/implementation/README.md`](design/implementation/README.md).
The editor map is
[`docs/design/implementation/editor/`](design/implementation/editor/README.md).
Do not put new work under it unless the work is actually that
editor-support line.

### The closed spine

Checkpoints 1 through 118 were numbered globally. Their index is
[`docs/design/implementation/spine/CHECKPOINTS.md`](design/implementation/spine/CHECKPOINTS.md),
their documents sit under `spine/checkpoints/`, their briefs beside
them, and their tests at `tests/checkpoint-N.rkt`. That numbering
closed at 118 on 2026-10-19. A kernel change today is a series folder
like any other (`modules/`, `with/`, and `parenthetical-construction/`
are examples), and no series is promoted onto the index.

~~~~

The section ends with one blank line before `## Handoff`, as the
quoted text does.

## `AGENTS.md`

Replace

```markdown
The rules below apply when this conversation has been given one
approved checkpoint to implement. Read `SPEC.md` and
`CHECKPOINTS.md` before writing code.
```

with

```markdown
The rules below apply when this conversation has been given one
approved checkpoint to implement. Read `SPEC.md` and the README of
the checkpoint's series before writing code.
```

Nothing else in `AGENTS.md` changes.

## The root `README.md`

In its **Layout** list, replace

```markdown
- [CHECKPOINTS.md](CHECKPOINTS.md) — implementation order
```

with

```markdown
- [docs/design/implementation/spine/CHECKPOINTS.md](docs/design/implementation/spine/CHECKPOINTS.md) — the global checkpoint index, 1 through 118, closed
```

Nothing else in `README.md` changes.

## The spine map

In `docs/design/implementation/spine/README.md`, replace the first
two paragraphs after the title:

```markdown
The global checkpoint spine: the checkpoints numbered across the
whole language, and the briefs, designer assignments, locked
vocabularies, and one-conversation charters that produced them. The
index is [`CHECKPOINTS.md`](../../../../CHECKPOINTS.md) at the
project root. [`SPEC.md`](../../../../SPEC.md) is law.

Not a local project. Identity here is a global number, spoken
**checkpoint 118**. The next global number continues in
[`checkpoints/`](checkpoints/). The next spine brief is written in
this folder as `<topic>-brief.md` or `<topic>-designer.md`. Process:
[`docs/workflow.md`](../../../workflow.md).
```

with

```markdown
The global checkpoint spine: the checkpoints numbered across the
whole language, and the briefs, designer assignments, locked
vocabularies, and one-conversation charters that produced them. The
index is [`CHECKPOINTS.md`](CHECKPOINTS.md), in this folder.
[`SPEC.md`](../../../../SPEC.md) is law.

The spine is closed at **checkpoint 118** (2026-10-19). No further
global number is issued, and nothing new is written here. A change to
the kernel is a series folder beside this one, with
`(project, number)` identity. Process:
[`docs/workflow.md`](../../../workflow.md).
```

Nothing else in that file changes.

## The implementation map

In `docs/design/implementation/README.md`, three edits.

### The identity paragraph

Replace

```markdown
Identity is a global number on the spine (**checkpoint 118**) and
`(project, number)` everywhere else (**editor-lsp 000**,
**aloemacs-text 000**, **with 001**). Numbers are never renumbered.
A local series does not take a global number unless a human promotes
it onto [`CHECKPOINTS.md`](../../../CHECKPOINTS.md).
```

with

```markdown
Identity is `(project, number)` (**editor-lsp 000**,
**aloemacs-text 000**, **with 001**). Numbers are never renumbered.
The spine's global numbers (**checkpoint 118**) are historical: the
spine closed at 118 on 2026-10-19, its index is
[`spine/CHECKPOINTS.md`](spine/CHECKPOINTS.md), and no series is
promoted onto it.
```

### The spine row

Replace the row

```markdown
| [`spine/`](spine/README.md) | Globally numbered checkpoints `0072` through `0118`, and the briefs, vocabularies, and one-conversation charters that produced them. The index is `CHECKPOINTS.md` at the project root. | Through 118 (2026-10-18). The next global number continues here. |
```

with

```markdown
| [`spine/`](spine/README.md) | Globally numbered checkpoints `0072` through `0118`, and the briefs, vocabularies, and one-conversation charters that produced them. The index of all 118 is [`CHECKPOINTS.md`](spine/CHECKPOINTS.md) in that folder. | Closed at 118 (2026-10-19). Nothing new is written here. |
```

### This series' row

Under the `## Layout` heading, immediately after the row for
`source-layout/` (the row whose first cell links to
`source-layout/README.md`), add this row. Copy it as written.

```markdown
| [`spine-close/`](spine-close/README.md) | The global numbering closed at 118 and its index moved into `spine/`. | 000 is this change. |
```

## Exact file scope

### May edit

- `CHECKPOINTS.md`: the move, the two link rewrites inside it, and
  the one inserted paragraph.
- The 21 checkpoint files under `docs/design/implementation/`
  reached by the two target substitutions: those targets only.
- `docs/workflow.md`: the two passages.
- `AGENTS.md`: the quoted lines.
- `README.md` at the root: the quoted bullet.
- `docs/design/implementation/spine/README.md`: the two paragraphs.
- `docs/design/implementation/README.md`: the three edits.
- The git index, through `git mv`.

### Must leave untouched

- `SPEC.md` and `info.rkt`.
- Every checkpoint, charter, spec, and README not named above,
  including the lines in older series READMEs about promotion onto
  `CHECKPOINTS.md` and the editor map's "Do not number these 118,
  119, …". They are history and the name still resolves to one file.
- `docs/handoff.md`, which names the index by bare name and is stale
  for other reasons.
- The line in `AGENTS.md` about Boids.
- `tests/`, `aloe/`, `host/`, `lib/`, `examples/`, `editors/`, and
  every other non-Markdown file.
- `docs/design/implementation/docs-layout/`,
  `docs/design/implementation/source-layout/`, and this folder.

If another file or another kind of edit is necessary, stop and send
this checkpoint back to the high-level discussion. Do not widen the
slice.

## Verification and completion

From the project root:

```sh
ls -p | grep -v /
ls docs/design/implementation/spine | wc -l
git status --short | grep -E '^.?D'
grep -rn --include='*.md' --exclude-dir=.git --exclude-dir=compiled --exclude-dir=docs-layout --exclude-dir=spine-close 'CHECKPOINTS.md` at the' .
for d in $(ls -p docs/design/implementation | grep '/'); do grep -q "\`$d\`" docs/design/implementation/README.md || echo "unmapped: $d"; done
TMPDIR=/tmp raco test -j 4 -y tests/docs-layout/links.rkt
git status --short
git diff --check
```

Completion:

- The root listing prints `AGENTS.md`, `README.md`, `SPEC.md`, and
  `info.rkt` and nothing else.
- `spine/` holds 18 entries: `README.md`, `CHECKPOINTS.md`,
  `checkpoints/`, and the fifteen briefs.
- The deletion line prints nothing.
- The `grep` prints nothing: no live text still places the index at
  the root. It excludes this series' folder because this checkpoint
  quotes the old text on purpose. (The implementer found that on
  2026-10-19; the first version of this checkpoint did not exclude
  it, and the grep printed the quoted lines.)
- The loop prints nothing: every folder, this one included, is named
  in the map.
- `tests/docs-layout/links.rkt` passes.
- `git status --short` shows one rename (modified in place) and 26
  modified files: the 21 checkpoints, `docs/workflow.md`, `AGENTS.md`,
  `README.md`, the spine map, and the implementation map. No
  addition, no deletion.
- `git diff --check` is clean.
- The whole suite is not run. No executable file changes.

Stop. Do not commit. Do not issue 001.

## Non-goals

- Merging the index into the spine map, or renaming the index.
- Rewriting the bare mentions of `CHECKPOINTS.md` across the tree, or
  the promotion boilerplate in older series READMEs.
- Moving or renaming `tests/checkpoint-N.rkt`, or any test.
- Refreshing the Status paragraph of the root `README.md`, or
  `docs/handoff.md`.
- Removing the Boids line from `AGENTS.md`.
- Any change to `SPEC.md`, to how checkpoints are written, or to the
  roles in `docs/workflow.md`.
- spine-close 001.
