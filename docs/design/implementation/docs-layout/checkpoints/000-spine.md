# docs-layout 000 — The global spine under `docs/design/implementation/spine/`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Move the documents of the global checkpoint spine out of the top of
`docs/` into one folder, `docs/design/implementation/spine/`, so that
`docs/` shows only what a reader opens first. Rewrite every reference
to a moved path. Add a map for the new folder. Amend the rows of
`docs/workflow.md` that say where spine files live. Add a test that
fails on a broken relative link in any Markdown file, and bring the
tree to zero broken links. Stop.

After this checkpoint, `ls docs` prints exactly these eight entries:

```text
decisions.md  design  editor  gel.md  handoff.md  journal  philosophy.md  workflow.md
```

Nothing about Aloe, the editor, the runners, or the existing tests
changes. One test file is added.

## Why this shape

Twenty Markdown files sit at the top of `docs/`. Five are what a
person or an agent reads on arrival: `philosophy.md`, `decisions.md`,
`gel.md`, `workflow.md`, and `handoff.md`. The other fifteen are
conversation assignments and design outputs for globally numbered
checkpoints: designer and checkpoint-manager briefs, locked
vocabularies, the Proposal B document, and four one-conversation
charters. They are what a per-series folder under
`docs/design/implementation/` holds today as `charter.md` and
`spec.md`. They were written before that convention existed.

The folder is named for what it holds, not for its age. Checkpoint
118 landed on 2026-10-18 through one of these briefs, and the next
global number continues in the moved `checkpoints/`. `spine` is the
word `docs/workflow.md`, `docs/editor/README.md`, and the aloemacs
map already use for this line of work.

Almost every reference to a moved file is a prose mention of the
literal path, not a Markdown link. One textual substitution per path
rewrites prose and links together. The only subtle references are
relative links that cross folders; every one is listed below.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` is unchanged and stays the language law.
[`docs/workflow.md`](../../../../workflow.md) is the conversation
pipeline; this slice changes where it says spine files live and
nothing else in it.

- Identity is **docs-layout 000**. File:
  `docs/design/implementation/docs-layout/checkpoints/000-spine.md`.
  Local numbering. Do not add a global checkpoint or a
  `CHECKPOINTS.md` entry. Do not issue 001.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Starting point: the working tree at `cf5330b` on
  `experiment/2026-10-16-host-queries`, or a later commit. Before
  moving anything, confirm the inventory: `docs/checkpoints/` holds
  40 files, `0072` through `0118` including `0083a`, and the fifteen
  files named under **The moves** exist at the top of `docs/`. If the
  inventory differs, stop and report the difference.
- No `.rkt`, `.aloe`, or other non-Markdown file names a moved path.
  The strings in **Path substitutions** occur in `.md` files only, on
  about 340 lines of about 140 files.
- Twelve relative links are broken before this checkpoint starts,
  all in three files. They are listed under **Links that were
  already broken** and are fixed here so the new test is green.

Read the **Where files live** section of `docs/workflow.md` before
starting.

## The moves

Create `docs/design/implementation/spine/`. Use `git mv` for every
move so history follows each file. No file is renamed. No stub or
redirect is left at an old path.

### The checkpoints folder

| From | To |
|---|---|
| `docs/checkpoints/` | `docs/design/implementation/spine/checkpoints/` |

The whole folder, 40 files, names unchanged.

### The fifteen files

Each moves from `docs/<name>` to
`docs/design/implementation/spine/<name>`:

| File |
|---|
| `0.3-language-merge.md` |
| `boid-monomorphic-brief.md` |
| `class-constructors.md` |
| `editor-lsp-merge.md` |
| `evaluator-compile-limit-brief.md` |
| `filesystem-designer.md` |
| `filesystem-oo-designer.md` |
| `filesystem-oo-surface.md` |
| `filesystem-oo-vocabulary.md` |
| `filesystem-vocabulary.md` |
| `host-boundary-designer.md` |
| `host-boundary-extensions.md` |
| `parser-checker-elegance.md` |
| `string-len-take-brief.md` |
| `string-starts-with-library-brief.md` |

### Stays where it is

`docs/philosophy.md`, `docs/decisions.md`, `docs/gel.md`,
`docs/workflow.md`, `docs/handoff.md`, `docs/journal/`,
`docs/editor/`, and `docs/design/`. `CHECKPOINTS.md` stays at the
project root and remains the index.

## Path substitutions

In every `.md` file in the tree outside `.git/`, `compiled/`, and
`node_modules/`, replace each old string with its new string. That
includes `CHECKPOINTS.md`, `archive/`, `docs/workflow.md`,
`docs/handoff.md`, `docs/editor/`, every series folder, and the
moved files themselves.

| Old | New |
|---|---|
| `docs/checkpoints` | `docs/design/implementation/spine/checkpoints` |
| `docs/0.3-language-merge.md` | `docs/design/implementation/spine/0.3-language-merge.md` |
| `docs/boid-monomorphic-brief.md` | `docs/design/implementation/spine/boid-monomorphic-brief.md` |
| `docs/class-constructors.md` | `docs/design/implementation/spine/class-constructors.md` |
| `docs/editor-lsp-merge.md` | `docs/design/implementation/spine/editor-lsp-merge.md` |
| `docs/evaluator-compile-limit-brief.md` | `docs/design/implementation/spine/evaluator-compile-limit-brief.md` |
| `docs/filesystem-designer.md` | `docs/design/implementation/spine/filesystem-designer.md` |
| `docs/filesystem-oo-designer.md` | `docs/design/implementation/spine/filesystem-oo-designer.md` |
| `docs/filesystem-oo-surface.md` | `docs/design/implementation/spine/filesystem-oo-surface.md` |
| `docs/filesystem-oo-vocabulary.md` | `docs/design/implementation/spine/filesystem-oo-vocabulary.md` |
| `docs/filesystem-vocabulary.md` | `docs/design/implementation/spine/filesystem-vocabulary.md` |
| `docs/host-boundary-designer.md` | `docs/design/implementation/spine/host-boundary-designer.md` |
| `docs/host-boundary-extensions.md` | `docs/design/implementation/spine/host-boundary-extensions.md` |
| `docs/parser-checker-elegance.md` | `docs/design/implementation/spine/parser-checker-elegance.md` |
| `docs/string-len-take-brief.md` | `docs/design/implementation/spine/string-len-take-brief.md` |
| `docs/string-starts-with-library-brief.md` | `docs/design/implementation/spine/string-starts-with-library-brief.md` |

The replacement is textual. It applies inside code spans, inside
fenced blocks, in link text, and in link targets alike. A quoted
`CHECKPOINTS.md` entry inside a checkpoint's fenced block must show
the new path, because the index links from the project root. The
sentence "If you have been told to read `docs/<name>`, this file is
the whole assignment" in each brief must name the new path. No new
string contains an old string, so the order of the rows does not
matter and a second pass changes nothing.

A relative link target that spells `docs/` is rewritten by the same
substitution and still resolves. For example,
`docs/design/implementation/string-load-save/charter.md` links to
`../../../../docs/checkpoints/0114-string-len-take.md`; after the
substitution it links to
`../../../../docs/design/implementation/spine/checkpoints/0114-string-len-take.md`,
and four levels up from that folder is the project root. Such targets
need no hand edit.

Exclude this checkpoint's own folder,
`docs/design/implementation/docs-layout/`, from the substitution and
from the grep in **Verification**. It names the old paths on purpose.

## Relative link targets changed by hand

A relative link whose target never spelled `docs/` is not reached by
the substitution. Each target below changes. Find each by its target
string, not by a line number. Where the link text spells a path, the
substitution has already rewritten the text; only the target is
edited here.

Depth, for checking the arithmetic:

| From | To `docs/` | To the project root | To `spine/` |
|---|---|---|---|
| `docs/design/implementation/spine/` | `../../../` | `../../../../` | `./` |
| `docs/design/implementation/spine/checkpoints/` | `../../../../` | `../../../../../` | `../` |
| `docs/design/implementation/<project>/` | `../../../` | `../../../../` | `../spine/` |
| `docs/design/implementation/aloemacs/<layer>/` | `../../../../` | `../../../../../` | `../../spine/` |

### In files that move

`docs/design/implementation/spine/evaluator-compile-limit-brief.md`:

| Target | Becomes |
|---|---|
| `../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md` | `../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md` |
| `../archive/design-sketches/2026-10-18-aloemacs-frame-time/interp-check.sh` | `../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/interp-check.sh` |

Its target `checkpoints/0114-string-len-take.md` is unchanged and
still resolves, because `checkpoints/` moves beside it.

`docs/design/implementation/spine/checkpoints/0118-evaluator-compile-limit.md`:

| Target | Becomes |
|---|---|
| `../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md` | `../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md` |

The links among the fifteen files themselves (`filesystem-designer.md`
to `filesystem-oo-designer.md`, `filesystem-vocabulary.md` to
`host-boundary-designer.md`, and so on) are sibling links and are
unchanged.

### In files that stay, pointing at moved files

`docs/workflow.md`:

| Target | Becomes |
|---|---|
| `checkpoints/0103-fs-path-algebra.md` | `design/implementation/spine/checkpoints/0103-fs-path-algebra.md` |
| `0.3-language-merge.md` | `design/implementation/spine/0.3-language-merge.md` |
| `parser-checker-elegance.md` | `design/implementation/spine/parser-checker-elegance.md` |

`docs/handoff.md`:

| Target | Becomes |
|---|---|
| `checkpoints/0096-ratify-class-constructors.md` | `design/implementation/spine/checkpoints/0096-ratify-class-constructors.md` |
| `class-constructors.md` | `design/implementation/spine/class-constructors.md` |

`docs/design/implementation/aloemacs/discussion.md`:

| Target | Becomes |
|---|---|
| `../../../evaluator-compile-limit-brief.md` | `../spine/evaluator-compile-limit-brief.md` |

`docs/design/implementation/aloemacs/frame-time/README.md` and
`docs/design/implementation/aloemacs/frame-time/charter.md`, one each:

| Target | Becomes |
|---|---|
| `../../../../evaluator-compile-limit-brief.md` | `../../spine/evaluator-compile-limit-brief.md` |

`docs/design/implementation/aloemacs/file/charter.md`, two of each:

| Target | Becomes |
|---|---|
| `../../../../filesystem-vocabulary.md` | `../../spine/filesystem-vocabulary.md` |
| `../../../../filesystem-oo-vocabulary.md` | `../../spine/filesystem-oo-vocabulary.md` |

`docs/design/implementation/parenthetical-construction/charter.md`,
twice:

| Target | Becomes |
|---|---|
| `../../../checkpoints/0083a-host-implementation-call-shape.md` | `../spine/checkpoints/0083a-host-implementation-call-shape.md` |

`docs/design/implementation/int-methods/charter.md`:

| Target | Becomes |
|---|---|
| `../../checkpoints/0114-string-len-take.md` | `../spine/checkpoints/0114-string-len-take.md` |
| `../../checkpoints/0115-string-starts-with.md` | `../spine/checkpoints/0115-string-starts-with.md` |

These two were already broken, written one level short.

### Links that were already broken

The test below reports twelve broken links on the tree before this
checkpoint. Two are the targets just above. Fix the other ten here.

`docs/design/implementation/int-methods/charter.md` sits three levels
below `docs/` and writes its links one level short. Prepend one
`../` to each of these eight targets:

| Target | Becomes |
|---|---|
| `../../workflow.md` | `../../../workflow.md` |
| `../../decisions.md` | `../../../decisions.md` |
| `../../philosophy.md` | `../../../philosophy.md` |
| `../../../lib/string.aloe` (twice) | `../../../../lib/string.aloe` |
| `../../../aloe/library.rkt` (twice) | `../../../../aloe/library.rkt` |
| `../../../lib/list.aloe` | `../../../../lib/list.aloe` |

`docs/design/implementation/racket-bytecode/checkpoints/000-bytecode-and-test-flag.md`:

| Target | Becomes |
|---|---|
| `../../../workflow.md` | `../../../../workflow.md` |

`docs/design/implementation/aloemacs/int-min/checkpoints/000-inline-min-max.md`:

| Target | Becomes |
|---|---|
| `../../int-methods/spec.md` | `../../../int-methods/spec.md` |

Its link text is the same string in backticks. Make the text
`docs/design/implementation/int-methods/spec.md`.

Two links in `docs/design/implementation/aloemacs/text/charter.md`
have absolute targets under `/home/dharmatech/src/`. They point
outside the repository. Leave them alone; the test skips absolute
targets.

Fifteen more links sit inside fenced blocks in spine checkpoints:
the `CHECKPOINTS.md` entry that fourteen checkpoints quote for the
implementer to append, and one sentence in 0118. They are not links of those
files, the test does not scan fenced blocks, and the substitution
gives them the right text. Do not edit them beyond the substitution.

## The spine map

Create `docs/design/implementation/spine/README.md` with the content
below. Copy it as written. Its links are relative to that folder.

~~~~markdown
# spine

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

Every file here lived at the top of `docs/` until docs-layout 000
moved it. Contents are unchanged apart from paths.

## Checkpoints

`checkpoints/NNNN-slug.md`. The files present run from `0072` to
`0118`. `CHECKPOINTS.md` records every number: 1 through 71 predate
per-checkpoint documents, 12 through 52 are `tests/checkpoint-N.rkt`,
and the index says where 108 through 113 and 116 through 117 live.

| Range | Topic | Written from |
|---|---|---|
| 0072–0082 | Gel stack, step, key, rows, picks, text | [`docs/gel.md`](../../../gel.md), law for the Gel phase |
| 0083–0088, with 0083a | Typed host boundary | `docs/decisions.md`, Typed host capabilities (2026-09-06) |
| 0089–0096 | Class constructors and `case`, Proposal B | [`class-constructors.md`](class-constructors.md) |
| 0097–0099 | The typed host boundary on the constructor branch, `(List String)` crossing, generic retention | [`host-boundary-designer.md`](host-boundary-designer.md), [`host-boundary-extensions.md`](host-boundary-extensions.md) |
| 0100–0104 | `Option` library and the thin filesystem library | [`filesystem-designer.md`](filesystem-designer.md), [`filesystem-vocabulary.md`](filesystem-vocabulary.md) |
| 0105–0107 | Live `Disk`, `Location`, and `Item` | [`filesystem-oo-surface.md`](filesystem-oo-surface.md), [`filesystem-oo-vocabulary.md`](filesystem-oo-vocabulary.md), [`filesystem-oo-designer.md`](filesystem-oo-designer.md) |
| 0114–0115 | String `len`, `take`, `starts-with?` | [`string-len-take-brief.md`](string-len-take-brief.md), [`string-starts-with-library-brief.md`](string-starts-with-library-brief.md) |
| 0118 | The evaluator under the compile limit | [`evaluator-compile-limit-brief.md`](evaluator-compile-limit-brief.md) |

## Briefs, vocabularies, and charters

| File | Role | Status |
|---|---|---|
| [`host-boundary-designer.md`](host-boundary-designer.md) | Designer brief for checkpoints 97–99 | Complete through 99 |
| [`host-boundary-extensions.md`](host-boundary-extensions.md) | Working design for the `(List String)` crossing and generic retention | Implemented by 98–99 and 101–104 |
| [`class-constructors.md`](class-constructors.md) | Proposal B: constructors and receiver-anchored `case` | Ratified into `SPEC.md` by checkpoint 96; historical |
| [`filesystem-designer.md`](filesystem-designer.md) | Designer brief for the thin filesystem library | Complete through 104 |
| [`filesystem-vocabulary.md`](filesystem-vocabulary.md) | Locked thin vocabulary, `lib/fs.aloe` | Implemented through 104 |
| [`filesystem-oo-surface.md`](filesystem-oo-surface.md) | Design-conversation brief for the live surface | Produced `filesystem-oo-vocabulary.md` |
| [`filesystem-oo-vocabulary.md`](filesystem-oo-vocabulary.md) | Locked live vocabulary, `lib/disk.aloe` | Implemented through 107; `Location.entries` and `enter` not issued |
| [`filesystem-oo-designer.md`](filesystem-oo-designer.md) | Checkpoint-manager brief for 105–107 | Complete |
| [`string-len-take-brief.md`](string-len-take-brief.md) | Checkpoint-manager brief for 114 | Landed |
| [`string-starts-with-library-brief.md`](string-starts-with-library-brief.md) | Checkpoint-manager brief for 115 | Landed |
| [`evaluator-compile-limit-brief.md`](evaluator-compile-limit-brief.md) | Checkpoint-manager brief for 118 | Landed 2026-10-18 at `29c5103` |
| [`0.3-language-merge.md`](0.3-language-merge.md) | One-conversation charter: land the language work on `main` | Landed at `8b0a110` |
| [`editor-lsp-merge.md`](editor-lsp-merge.md) | One-conversation charter: land editor support on `main` | Landed at `266e031` |
| [`parser-checker-elegance.md`](parser-checker-elegance.md) | One-conversation charter: one grammar, one checker | Landed at `8701dce` |
| [`boid-monomorphic-brief.md`](boid-monomorphic-brief.md) | One-shot brief: monomorphic `Boid` | Landed; `Boid` is monomorphic in `examples/boids.aloe` |

Each file keeps its own **Status** line. When this table and that
line disagree, the file is right.
~~~~

## `docs/workflow.md`

Beyond the substitution and the three link targets listed above, make
these edits and no others.

In **Where files live**, under **Language spine**, the table today
reads, after the substitution:

```markdown
| Artifact | Path |
|---|---|
| Checkpoints index | [`CHECKPOINTS.md`](../CHECKPOINTS.md) |
| Checkpoint | `docs/design/implementation/spine/checkpoints/NNNN-slug.md` |
| Tests | `tests/checkpoint-N.rkt` |
| Designer / manager brief | `docs/<topic>-designer.md` or `docs/<topic>-brief.md` |
```

Make it:

```markdown
| Artifact | Path |
|---|---|
| Checkpoints index | [`CHECKPOINTS.md`](../CHECKPOINTS.md) |
| Spine map | [`docs/design/implementation/spine/README.md`](design/implementation/spine/README.md) |
| Checkpoint | `docs/design/implementation/spine/checkpoints/NNNN-slug.md` |
| Tests | `tests/checkpoint-N.rkt` |
| Designer / manager brief | `docs/design/implementation/spine/<topic>-designer.md` or `docs/design/implementation/spine/<topic>-brief.md` |
```

Leave the **Local project** subsection unchanged, including the
sentence that keeps `docs/editor/` where it is. Moving `docs/editor/`
is a later checkpoint, not this one. Do not change the pipeline
diagram, the roles, the host verification section, or the handoff
table.

## The link test

Create `tests/docs-layout/links.rkt`. It is a Rackunit module in the
shape of `tests/checkpoint-118.rkt`: `#lang racket/base`, requiring
`racket/file`, `racket/path`, `racket/runtime-path`, `racket/string`,
and `rackunit`. It does not shell out and does not run `git`.

- `(define-runtime-path root "../..")` names the project root.
- **Files.** Every path under `root` whose name ends in `.md`, found
  with `in-directory` and a filter that does not descend into a
  directory named `.git`, `compiled`, or `node_modules`.
- **Fences.** Each file is read as lines. A line whose leading
  whitespace is followed by three or more backticks, or three or more
  tildes, opens a fence when none is open. An open fence closes only
  on a line of the same character with at least as many of them. A
  line of the other marker inside an open fence is content, like any
  other line there. Fence lines and lines inside a fence are not
  scanned. The distinction matters: the racket-bytecode checkpoint
  quotes samples fenced with four tildes that themselves contain
  fences of three backticks, and a scanner that let either marker
  close either fence would count itself inside a fence from there to
  the end of that file. A `CHECKPOINTS.md` entry quoted inside a
  checkpoint's fence is not a link of that checkpoint.
- **Links.** On each scanned line, every match of
  `#px"\\]\\(([^)]+)\\)"` yields one target. Drop everything from the
  first `#` onward. Skip the target when what remains is empty,
  begins with `/`, or matches `#px"^[a-zA-Z][a-zA-Z0-9+.-]*:"` (a URL
  scheme such as `https:` or `mailto:`).
- **Resolution.** Build the remaining target against the file's
  directory. It is broken when neither `file-exists?` nor
  `directory-exists?` holds for the result.
- **Checks.** Two. `(check-true (>= (length files) 100))` guards
  against scanning the wrong directory; the tree holds about 350
  Markdown files today. `(check-equal? broken '())`, where each
  element of `broken` is a string
  `"<path relative to root>:<line> -> <target>"`, in file order then
  line order. A failure prints the list, which is the report.

Run on the tree before this checkpoint, the test lists the twelve
links under **Links that were already broken**. Run on the finished
tree, it passes.

## Exact file scope

### May create or edit

- `docs/design/implementation/spine/` (new): the moved folder and
  the fifteen moved files, changed only by the substitution and the
  targets listed above; `README.md` (new) as written above.
- `tests/docs-layout/links.rkt` (new).
- `docs/workflow.md`: the substitution, the three targets, and the
  table rows.
- `docs/handoff.md`: the substitution and the two targets.
- `docs/design/implementation/aloemacs/discussion.md`,
  `aloemacs/frame-time/README.md`, `aloemacs/frame-time/charter.md`,
  `aloemacs/file/charter.md`, `aloemacs/int-min/checkpoints/000-inline-min-max.md`,
  `parenthetical-construction/charter.md`, `int-methods/charter.md`,
  and `racket-bytecode/checkpoints/000-bytecode-and-test-flag.md`:
  the substitution and the targets listed for each.
- Every other `.md` file outside `.git/`, `compiled/`, and
  `node_modules/`, including `CHECKPOINTS.md`, `docs/editor/`, and
  `archive/`: the substitution only.
- The git index, through `git mv`.

### Must leave untouched

- Every file that is not Markdown, except the new test.
- `SPEC.md`, `AGENTS.md`, and `README.md` at the project root. None
  of the strings in the table occurs in them. If the substitution
  would change one, stop and report.
- The location of `docs/editor/`, `docs/journal/`, and the five
  files that stay at the top of `docs/`.
- The content of any moved file beyond the substitution and the
  targets named here. No status line, heading, or prose changes.
- The sentence in `docs/workflow.md` that keeps `docs/editor/` where
  it is.
- This folder, `docs/design/implementation/docs-layout/`.
- Every existing test.

If another file or another kind of edit is necessary, stop and send
this checkpoint back to the high-level discussion. Do not widen the
slice.

## Verification and completion

From the project root:

```sh
ls docs
ls docs/design/implementation/spine | wc -l
ls docs/design/implementation/spine/checkpoints | wc -l
git status --short | grep -E '^.?D'
grep -rnE --exclude-dir=.git --exclude-dir=compiled --exclude-dir=node_modules --exclude-dir=docs-layout 'docs/checkpoints|docs/(0\.3-language-merge|boid-monomorphic-brief|class-constructors|editor-lsp-merge|evaluator-compile-limit-brief|filesystem-designer|filesystem-oo-designer|filesystem-oo-surface|filesystem-oo-vocabulary|filesystem-vocabulary|host-boundary-designer|host-boundary-extensions|parser-checker-elegance|string-len-take-brief|string-starts-with-library-brief)\.md' .
TMPDIR=/tmp raco test -j 4 -y tests/docs-layout/links.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Completion:

- `ls docs` prints the eight entries shown under **Goal** and nothing
  else.
- `spine/` holds 17 entries: `README.md`, `checkpoints/`, and the
  fifteen files. `spine/checkpoints/` holds 40 files.
- The `git status` line prints nothing: no path is deleted. The
  moves appear as renames, the rest as modifications and the two
  new files.
- The `grep` prints nothing.
- `tests/docs-layout/links.rkt` passes.
- The whole suite passes.
- `git diff --check` is clean.
- `git diff -M` over the moved files shows, in each, only lines that
  contain a substituted string or a target named above.

Stop. Do not commit. Do not issue 001.

## Non-goals

- Moving `docs/editor/`, or editing the sentence in `docs/workflow.md`
  that keeps it where it is. That is the expected 001.
- A map at `docs/design/implementation/README.md`. That is the
  expected 002.
- Grouping the fifteen files into subfolders, renaming any of them,
  or renumbering any checkpoint.
- A stub, symlink, or redirect at any old path.
- Refreshing the status prose of `docs/handoff.md`, which still
  describes `main` as of 2026-09-19.
- Converting the two absolute links in the aloemacs text charter.
- A change to `SPEC.md`, `CHECKPOINTS.md` beyond the substitution,
  any `.rkt` or `.aloe` file, or any existing test.
- Checking links inside fenced blocks, reference-style links, or
  links to anchors within a file.
