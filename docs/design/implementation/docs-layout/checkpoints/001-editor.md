# docs-layout 001 — The editor map under `docs/design/implementation/editor/`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Move `docs/editor/`, as one unit, to
`docs/design/implementation/editor/`. Rewrite every reference to the
old path. Replace the paragraph in `docs/workflow.md` that forbids
this move. Keep `tests/docs-layout/links.rkt` green. Stop.

After this checkpoint, `ls docs` prints exactly these seven entries:

```text
decisions.md  design  gel.md  handoff.md  journal  philosophy.md  workflow.md
```

Nothing about Aloe, the editor, the language server, the runners, or
the tests changes. No test file is added.

## Why this shape

`docs/editor/` is a local map of the same kind as the aloemacs or
modules maps: nine projects, each with a charter, a spec, and a
`checkpoints/` folder, with identity `(project, number)`. It sat at
the top of `docs/` only because it predates the
`docs/design/implementation/` convention. `docs/workflow.md` pinned
it there on 2026-09-19, when the aloemacs text foundation was added,
to avoid churn at the time. docs-layout 000 moved the global spine;
this slice finishes the top shelf.

The folder path is not part of any identity. **editor-lsp 000** is
still spoken that way, `tests/editor/` stays where it is, and
`editors/vscode/` is untouched.

As in 000, almost every reference is a prose mention of the literal
path, so one substitution rewrites prose and links together. The
relative links that cross the folder boundary, in both directions,
are listed below. There are fifteen leaving and seventeen entering.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` is unchanged and stays the language law.
[`docs/workflow.md`](../../../../workflow.md) is the conversation
pipeline; this slice replaces one paragraph of it and two link
targets, and nothing else in it.

- Identity is **docs-layout 001**. File:
  `docs/design/implementation/docs-layout/checkpoints/001-editor.md`.
  Local numbering. Do not add a global checkpoint or a
  `CHECKPOINTS.md` entry. Do not issue 002.
- Predecessor: docs-layout 000, committed at `9cf7ce9`. It moved the
  spine and added `tests/docs-layout/links.rkt`, which scans every
  Markdown file for a broken relative link, skipping fenced blocks,
  fragments, URLs, and absolute targets. That test is the gate for
  this slice. It passes on the starting tree and runs in about one
  second.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Starting point: the working tree at `9cf7ce9` or a later commit.
  Before moving anything, confirm the inventory. `docs/editor/` holds
  59 files, all Markdown: `README.md` and nine project folders
  (`completion`, `definition`, `expression-query`, `highlighting`,
  `host-queries`, `lsp`, `signatures-of-type`, `source-locations`,
  `vscode`), each with a `checkpoints/` folder. The string
  `docs/editor/` occurs on about 220 lines of about 90 files. Two of
  those files are not Markdown: `gel/aloe-hosts.rktd` and
  `examples/aloemacs/aloe-hosts.rktd`, each on a `;;` comment line.
  If the inventory differs, stop and report the difference.

## The move

```sh
git mv docs/editor docs/design/implementation/editor
```

The whole folder, 59 files, names unchanged. No file is renamed. No
stub or redirect is left at `docs/editor/`.

## Path substitution

In every text file in the tree outside `.git/`, `compiled/`, and
`node_modules/`, replace the one string below with its new string.
That includes `README.md` and `CHECKPOINTS.md` at the project root,
`docs/workflow.md`, `docs/handoff.md`, `docs/journal/`, every series
folder, the spine, the moved folder itself, and the two `.rktd`
manifests.

| Old | New |
|---|---|
| `docs/editor/` | `docs/design/implementation/editor/` |

The trailing slash is part of the string. Without it the pattern
would also match the file name `editor-lsp-merge.md` spelled with its
old `docs/` prefix, which survives only inside this checkpoint's own
folder, and one bare path argument handled by hand below.

The replacement is textual and applies inside code spans, fenced
blocks, link text, and link targets alike. The new string does not
contain the old one, so a second pass changes nothing.

The two manifests are read by `aloe/host-manifest.rkt` with the
Racket reader, which skips a `;;` comment, so the datum each manifest
declares is unchanged. Edit only that comment line in each.

Exclude this checkpoint's own folder,
`docs/design/implementation/docs-layout/`, from the substitution and
from the grep in **Verification**. It names the old path on purpose.

## Relative link targets changed by hand

A relative link whose target never spelled `docs/editor/` is not
reached by the substitution. Each target below changes. Find each by
its target string, not by a line number. Where the link text spells
a path, the substitution has already rewritten the text; only the
target is edited here.

Depth, for checking the arithmetic:

| From | To `docs/` | To the project root | To `implementation/` |
|---|---|---|---|
| `docs/design/implementation/editor/` | `../../../` | `../../../../` | `../` |
| `docs/design/implementation/editor/<project>/` | `../../../../` | `../../../../../` | `../../` |
| `docs/design/implementation/<project>/` | `../../../` | `../../../../` | `../` |
| `docs/design/implementation/<project>/checkpoints/` | `../../../../` | `../../../../../` | `../../` |

### Leaving the moved folder

Fifteen links, seven distinct targets. All sit in the map's
`README.md` or in a project's `charter.md` or `spec.md`; none sits in
a `checkpoints/` folder.

`docs/design/implementation/editor/README.md`:

| Target | Becomes |
|---|---|
| `../workflow.md` | `../../../workflow.md` |

In the project folders:

| Target | Where | Becomes |
|---|---|---|
| `../../workflow.md` | `definition/charter.md` twice, `host-queries/charter.md` twice | `../../../../workflow.md` |
| `../../design/implementation/modules/spec.md` | `definition/charter.md` twice, `definition/spec.md` once | `../../modules/spec.md` |
| `../../../tests/editor/lsp/fixtures/point.aloe` | `highlighting/charter.md`, `highlighting/spec.md`, `vscode/charter.md`, `vscode/spec.md` | `../../../../../tests/editor/lsp/fixtures/point.aloe` |
| `../../../lib/text.aloe` | `highlighting/charter.md` | `../../../../../lib/text.aloe` |
| `../../../lib/string.aloe` | `highlighting/spec.md` | `../../../../../lib/string.aloe` |
| `../../../examples/boids.aloe` | `completion/charter.md` | `../../../../../examples/boids.aloe` |

Links among the editor projects themselves (`../README.md`,
`../lsp/spec.md`, `../../source-locations/checkpoints/000-spans.md`,
and the like) stay inside the folder and are unchanged. No target
inside the folder spells `docs/editor/`.

### Entering the moved folder from files that stay

Seventeen links.

`docs/workflow.md`:

| Target | Becomes |
|---|---|
| `editor/README.md` (twice; one is inside the paragraph replaced below) | `design/implementation/editor/README.md` |
| `editor/lsp/checkpoints/000-hover.md` | `design/implementation/editor/lsp/checkpoints/000-hover.md` |

`docs/design/implementation/aloemacs/README.md`:

| Target | Becomes |
|---|---|
| `../../../editor/README.md` | `../editor/README.md` |

`docs/design/implementation/modules/charter.md`, seven times:

| Target | Becomes |
|---|---|
| `../../../editor/lsp/spec.md` | `../editor/lsp/spec.md` |

`docs/design/implementation/suite-jobs/charter.md` twice and
`docs/design/implementation/suite-jobs/spec.md` once:

| Target | Becomes |
|---|---|
| `../../../editor/lsp/checkpoints/009-launch.md` | `../editor/lsp/checkpoints/009-launch.md` |

`docs/design/implementation/suite-jobs/checkpoints/000-parallel-standing-command.md`:

| Target | Becomes |
|---|---|
| `../../../../editor/lsp/checkpoints/009-launch.md` | `../../editor/lsp/checkpoints/009-launch.md` |

`docs/design/implementation/checker-recursion/checkpoints/000-deferred-generic-body.md`:

| Target | Becomes |
|---|---|
| `../../../../editor/expression-query/spec.md` | `../../editor/expression-query/spec.md` |
| `../../../../editor/expression-query/checkpoints/002-rigid-generic-body.md` | `../../editor/expression-query/checkpoints/002-rigid-generic-body.md` |

`README.md` and `CHECKPOINTS.md` at the project root link with the
full `docs/editor/` path from the root. The substitution rewrites
them and they still resolve.

### One bare path

`docs/design/implementation/spine/editor-lsp-merge.md` quotes, inside
a fenced block, the git command the landed merge ran, one path per
line. docs-layout 000 already rewrote that block's spine paths.
Change the line

```text
  docs/editor \
```

to

```text
  docs/design/implementation/editor \
```

Nothing else in that block changes.

## `docs/workflow.md`

Beyond the substitution and the two targets above, make this edit
and no other. In **Where files live**, under **Local project**, the
last paragraph reads today, after the substitution:

```markdown
Existing local maps stay where they are. Do not move
[`docs/design/implementation/editor/`](editor/README.md) into `docs/design/implementation/`.
Do not put new work under `docs/design/implementation/editor/` unless it is actually that
editor-support line.
```

Replace the whole paragraph with:

```markdown
The editor map is
[`docs/design/implementation/editor/`](design/implementation/editor/README.md).
Do not put new work under it unless the work is actually that
editor-support line.
```

Do not change the pipeline diagram, the roles, the host verification
section, the Language spine table, or the handoff table.

## The editor map

In `docs/design/implementation/editor/README.md`, after the first
paragraph (the one that ends "Do not number these 118, 119, … .") and
before the paragraph that begins "The editor question", insert this
paragraph. Copy it as written.

```markdown
This folder was `docs/editor/` until docs-layout 001 moved it here.
Project identities are unchanged: editor-lsp 000 is still spoken
that way, and the tests stay under `tests/editor/`.
```

Nothing else in that file changes beyond the substitution and the
one target above.

## Exact file scope

### May edit

- `docs/design/implementation/editor/` (moved): the substitution, the
  fifteen targets listed under **Leaving the moved folder**, and the
  one paragraph in its `README.md`.
- `docs/workflow.md`: the substitution, the two targets, and the
  paragraph.
- `docs/design/implementation/aloemacs/README.md`,
  `modules/charter.md`, `suite-jobs/charter.md`, `suite-jobs/spec.md`,
  `suite-jobs/checkpoints/000-parallel-standing-command.md`,
  `checker-recursion/checkpoints/000-deferred-generic-body.md`, and
  `spine/editor-lsp-merge.md`: the substitution and the edits listed
  for each.
- `gel/aloe-hosts.rktd` and `examples/aloemacs/aloe-hosts.rktd`: the
  comment line only.
- Every other `.md` file outside `.git/`, `compiled/`, and
  `node_modules/`, including `README.md`, `CHECKPOINTS.md`,
  `docs/handoff.md`, `docs/journal/`, and `archive/`: the
  substitution only.
- The git index, through `git mv`.

### Must leave untouched

- Every file that is not Markdown, except the two manifests' comment
  lines.
- `SPEC.md` and `AGENTS.md`. The string does not occur in them. If the
  substitution would change one, stop and report.
- `tests/docs-layout/links.rkt`, `tests/editor/`, `editors/vscode/`,
  and every existing test.
- The datum in each manifest.
- The content of any moved file beyond the substitution, the listed
  targets, and the one README paragraph. No status line, heading, or
  prose changes.
- The location of `docs/journal/` and the five files that stay at the
  top of `docs/`.
- This folder, `docs/design/implementation/docs-layout/`.

If another file or another kind of edit is necessary, stop and send
this checkpoint back to the high-level discussion. Do not widen the
slice.

## Verification and completion

From the project root:

```sh
ls docs
ls docs/design/implementation/editor | wc -l
find docs/design/implementation/editor -type f | wc -l
git status --short | grep -E '^.?D'
grep -rn --exclude-dir=.git --exclude-dir=compiled --exclude-dir=node_modules --exclude-dir=docs-layout 'docs/editor' .
TMPDIR=/tmp raco test -j 4 -y tests/docs-layout/links.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor/host-queries
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Completion:

- `ls docs` prints the seven entries shown under **Goal** and nothing
  else.
- `docs/design/implementation/editor/` holds 10 entries: `README.md`
  and the nine project folders. It holds 59 files.
- The `git status` line prints nothing: no path is deleted. The move
  appears as renames, the rest as modifications.
- The `grep` prints exactly one line: the provenance paragraph in
  `docs/design/implementation/editor/README.md`, which names the old
  path on purpose. Note that the grep has no trailing slash: apart
  from that line, the string `docs/editor` must not occur anywhere
  outside this checkpoint's folder. (The implementer found this
  conflict on 2026-10-19; the first version of this checkpoint said
  the grep prints nothing. The paragraph is right and the acceptance
  line was wrong.)
- `tests/docs-layout/links.rkt` passes.
- The host-queries tests pass, which proves the manifests still
  read.
- The whole suite passes.
- `git diff --check` is clean.
- `git diff -M` over the moved files shows, in each, only lines that
  contain the substituted string, a target named above, or the one
  README paragraph.

Stop. Do not commit. Do not issue 002.

## Non-goals

- A map at `docs/design/implementation/README.md`. That is the
  expected 002.
- Renaming an editor project, merging one into aloemacs, or
  renumbering any checkpoint.
- Moving `tests/editor/`, `editors/vscode/`, or any fixture.
- A stub, symlink, or redirect at `docs/editor/`.
- Any edit to `docs/handoff.md` beyond the substitution.
- Any change to what the two manifests declare, to
  `aloe/host-manifest.rkt`, or to the language server.
- Any change to `tests/docs-layout/links.rkt`.
