# aloemacs

Spoken **aloe macs**. A terminal editor written in Aloe. Local work.
Not Aloe language law. Not Gel. Not the global checkpoint spine
(`docs/checkpoints/`, `CHECKPOINTS.md`). Not
[`docs/editor/`](../../../editor/README.md) (that map is edit-Aloe
from the outside).

Identity is `(project, number)` or `(aloemacs-layer, number)`.
Spoken name is **aloemacs-text 000**. Process:
[`docs/workflow.md`](../../../workflow.md).

## Why this program

Grow Aloe from an application. Borrow Legmacs's machine (immutable
editor state, `handle-key` returns a new editor, the frame is a
`String`, Term only at the runner) and Chez Emacs's text algebra
(`Text`, positions, half-open spans, replace a span). Do not port
either editor.

## Paths

| What | Where |
|---|---|
| This map, charters, specs, checkpoints | `docs/design/implementation/aloemacs/` |
| Editor program | `examples/aloemacs/` (promote to `apps/aloemacs/` only if it outgrows examples) |
| General libraries the editor forces | `lib/` (`string.aloe`, later `text.aloe`) |
| Term host and runner | `host/racket/` |
| Tests | `tests/aloemacs/` |

No top-level `aloemacs/` directory.

## Process

Each layer is either a **charter** (open questions; a designer writes
`spec.md` and stops) or a **brief** (locked enough to slice). Do not
design or implement a later layer in an earlier layer's conversation.

## Locks (do not reopen in child conversations)

- Evaluation is send. No mutation, no macros, no inheritance.
- Nested edit is rebuild. Commands are `(Editor → Editor)` once a
  loop exists; they are not `set-box!`.
- Static first. No `Mirror`, no live `eval`, no hot reload, no
  config-as-running-image.
- ASCII, one cell per character, until a later layer says otherwise.
- Host stays a typed injected capability. ANSI sequences are Aloe
  strings, not new Term methods, unless a slice proves otherwise.
- Do not mix these checkpoints into `CHECKPOINTS.md` unless the
  human promotes a kernel or host lift onto the language spine
  after review.

## Order

| # | Layer | Path | This conversation | Depends on |
|---|---|---|---|---|
| 1 | Text | [`text/`](text/) | **Charter issued.** Designer writes `spec.md`. | String messages the tests force |
| 2 | Term | `term/` | Not chartered. | Existing Term capability |
| 3 | Loop | `loop/` | Not chartered. | 1, 2 |
| 4 | File | `file/` | Not chartered. | 3, existing Fs |

Layers 1 and 2 do not depend on each other. Charter Term only after
the Text spec exists, or in a separate high-level pass — not inside
the Text designer conversation.

## Not in this map

Easy to smuggle in. They are not.

- Windows, prefix keymaps, minibuffer, search, modes
- Mouse, paste, PTY, VT emulator, daemon, multi-head
- Unicode clusters, `wcwidth`, grapheme width
- `M-x` eval, Gel's `Mirror`, hot reload
- A Chez Emacs or Legmacs source port
- Global checkpoint numbers 116, 118, …
- LSP / VS Code (`docs/editor/`)

## First consumer of each layer

| Layer | Consumer that is not a running editor |
|---|---|
| Text | Unit tests: insert, delete, newline, no TTY |
| Term | Tests and a host double; optional one-shot write of a frame |
| Loop | One-buffer insert / move / quit, full redraw |
| File | Load and save through existing Fs |

If a proposed slice has no consumer besides "the editor will need
this," it is too early.
