# Design and implementation

One folder per series. Every document about designing and
implementing a change to this tree lives under one of them: the
charter a discussion wrote, the `spec.md` a designer wrote, the
checkpoints a manager issued one at a time, and the README that
records where the series stands. The process is
[`docs/workflow.md`](../../workflow.md). Language law stays in
[`SPEC.md`](../../../SPEC.md); this folder is assignments and
history, not law.

Each series README is the authority for its series. When this map
and a series README disagree, the README is right. The statuses
below were checked against git on 2026-10-19.

Identity is a global number on the spine (**checkpoint 118**) and
`(project, number)` everywhere else (**editor-lsp 000**,
**aloemacs-text 000**, **with 001**). Numbers are never renumbered.
A local series does not take a global number unless a human promotes
it onto [`CHECKPOINTS.md`](../../../CHECKPOINTS.md).

## The global spine

| Folder | What | Status |
|---|---|---|
| [`spine/`](spine/README.md) | Globally numbered checkpoints `0072` through `0118`, and the briefs, vocabularies, and one-conversation charters that produced them. The index is `CHECKPOINTS.md` at the project root. | Through 118 (2026-10-18). The next global number continues here. |

## Maps with layers of their own

| Folder | What | Status |
|---|---|---|
| [`editor/`](editor/README.md) | Editing Aloe from outside: source locations, signatures of a type, expression and completion queries, the LSP adapter, the VS Code client, highlighting, class-name definition, and host-configured queries. Nine projects, each with its own charter, spec, and checkpoints. | Projects 1 through 9 implemented and reviewed. |
| [`aloemacs/`](aloemacs/README.md) | A terminal editor written in Aloe. Its README maps the layers (text, term, loop, windows, buffer, minibuffer, search, undo, and more), each with its own charter, spec, and checkpoints. | Active. The latest closed series is frame-time (2026-10-19). |

## Language series

| Folder | What | Status |
|---|---|---|
| [`int-methods/`](int-methods/README.md) | `Int` methods lifted into the library, then derived `min` and `max`. | Complete; 000 and 001 reviewed. |
| [`modules/`](modules/README.md) | Run-once `load`, explicit loads, `Option` on the base, overload identity, method records, conformance, file environments, load collisions, and defining paths. | Closed 2026-10-14 after 008. Adoption is not issued. |
| [`parenthetical-construction/`](parenthetical-construction/README.md) | Labeled construction, `(Point new* (x 10) (y 20))`, and the session definition that uses it. | Complete; 000 through 002 landed at `9af2f39` (2026-10-07). |
| [`string-load-save/`](string-load-save/README.md) | Kernel `split-lines` and indexed `to-string` for `String`. | Complete; 000 and 001 reviewed. |
| [`with/`](with/README.md) | Selector-position `with` for field update, then its use across Aloemacs. | Complete; 000 at `0aeeea6` and 001 at `c20a18f` (2026-10-08). |

## Host tooling

| Folder | What | Status |
|---|---|---|
| [`racket-bytecode/`](racket-bytecode/README.md) | `compiled/` gitignored, and `raco test -y` as the standing test command. | Complete; 000 landed at `d701b29` (2026-09-30). |
| [`suite-jobs/`](suite-jobs/README.md) | Four test files at once: `-j 4` in the standing command. | Complete; 000 landed at `445f68c` (2026-10-07). |
| [`suite-time/`](suite-time/README.md) | The suite timing report, and session helpers evaluated once. | Complete; 000 through 002 landed at `a860e3a` (2026-10-07). |

## Documentation

| Folder | What | Status |
|---|---|---|
| [`docs-layout/`](docs-layout/README.md) | This layout: the spine and the editor map moved under this folder, and this map. | 000 at `9cf7ce9` and 001 at `473863a` (2026-10-19); 002 is this map. |

## Withdrawn

| Folder | What | Status |
|---|---|---|
| [`checker-recursion/`](checker-recursion/README.md) | A checker prerequisite for Aloemacs completion. | Withdrawn 2026-10-04. Not an assignment. |
