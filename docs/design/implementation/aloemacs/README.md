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
| High-level discussion continuation | [`discussion.md`](discussion.md) |
| Upcoming explorations (ranked) | [`explorations.md`](explorations.md) |
| Hands-on tour | [`demo.md`](demo.md) |
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
  Safe cells keeps this lock: a control paints as one space.
- Host stays a typed injected capability. ANSI sequences are Aloe
  strings, not new Term methods, unless a slice proves otherwise.
- Do not mix these checkpoints into `CHECKPOINTS.md` unless the
  human promotes a kernel or host lift onto the language spine
  after review.

## Order

| # | Layer | Path | This conversation | Depends on |
|---|---|---|---|---|
| 1 | Text | [`text/`](text/) | **Implemented.** Spec and aloemacs-text 000–003. | String messages the tests force |
| 2 | Term | [`term/`](term/) | **Implemented.** Spec and aloemacs-term 000. | Existing Term capability |
| 3 | Loop | [`loop/`](loop/) | **Implemented.** Spec and aloemacs-loop 000–003. | 1, 2 |
| 4 | File | [`file/`](file/) | **Implemented.** Spec and aloemacs-file 000–003. | 3, existing Fs |
| 5 | Index | [`index/`](index/) | **Implemented.** Spec and aloemacs-index 000–002. | 3–4 (editor + `Text` / File strings) |
| 6 | Viewport | [`viewport/`](viewport/) | **Implemented.** Spec and aloemacs-viewport 000–002. | 5 (stored origin; reopen Loop §6) |
| 7 | Undo | [`undo/`](undo/) | **Implemented.** Spec and aloemacs-undo 000. | 3–6 (edits + zipper sharing) |
| 8 | Echo | [`echo/`](echo/) | **Implemented.** Spec and aloemacs-echo 000–001. | 4, 6 (path + text rectangle) |
| 9 | Safe cells | [`safe-cells/`](safe-cells/) | **Implemented.** Spec and aloemacs-safe-cells 000. | 3, 8 (frame bytes + echo label) |
| 10 | Search | [`search/`](search/) | **Implemented.** aloemacs-search 000–001. | 4, 8, 9 (session keys, echo row, safe cells) |

The first-product ladder is Text through File. Index, Viewport,
and Undo are follow-ons. Echo is implemented. Faster
`split-lines` / `to-string` is completed as a **language-library**
series ([`../string-load-save/`](../string-load-save/)).
**Safe cells** is implemented at [`safe-cells/`](safe-cells/).
**Search** is implemented at [`search/`](search/).
Ranked later work lives in [`explorations.md`](explorations.md). The Scale charter
stays withdrawn. The running program remains
`examples/aloemacs/` plus `host/racket/aloemacs-run.rkt`.

## Related language work

Visit and save use the linear String sends from the completed series beside
this map.

| Identity | Path | This conversation |
|---|---|---|
| string-load-save | [`../string-load-save/`](../string-load-save/) | **Implemented and accepted.** Checkpoints 000–001. |

## Idiom cleanups

Locked one-slice cleanups. Each folder is a **standalone
checkpoint** (no charter, no spec, no manager) unless it grows.

| Identity | Path | This conversation |
|---|---|---|
| line-length | [`line-length/`](line-length/) | **Implemented.** aloemacs-line-length 000 |
| int-min | [`int-min/`](int-min/) | **Implemented.** aloemacs-int-min 000 |
| viewport-top | [`viewport-top/`](viewport-top/) | **Implemented.** aloemacs-viewport-top 000 |
| next-lines | [`next-lines/`](next-lines/) | **Implemented.** aloemacs-next-lines 000 |
| visited-unchanged | [`visited-unchanged/`](visited-unchanged/) | **Implemented.** aloemacs-visited-unchanged 000 |
| safe-cell-scan | [`safe-cell-scan/`](safe-cell-scan/) | **Implemented.** aloemacs-safe-cell-scan 000 |

## Not in this map

Easy to smuggle in. They are not.

- Windows, prefix keymaps, minibuffer, modes
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
| Index | No-TTY Down + frame at the start **and** end of a many-line fixture |
| Viewport | Down to last screen row, then Up: cursor row decreases, `top` holds |
| Undo | Insert/newline/backspace then undo restores prior text and point |
| Echo | Frame shows untitled or path; save success vs failure |
| Safe cells | No-TTY frame: ESC, tab, CR, and DEL in text and in the echo label display as spaces; save writes the original bytes |
| Search | No-TTY: Ctrl-F, type a query, point moves; wrap and failure show on the echo; Escape restores the previous echo and does not quit |

If a proposed slice has no consumer besides "the editor will need
this," it is too early.
