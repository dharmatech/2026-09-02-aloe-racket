# aloemacs high-level discussion

**Status.** Continuation of the parent aloemacs discussion. This
file is the assignment for a **new high-level conversation**. It
is not a designer spec, a checkpoint, or an implementer brief.

If you have been told to read this file, this is the whole
assignment. The previous discussion transcript is background and
must not be loaded.

---

## Your job

Carry the high-level discussion of **aloemacs** (spoken *aloe
macs*): maps, charters, process, and what to grow next. Write
implementation charters when the human asks. Stop at the charter.
The human reviews it and opens a **different** conversation for
`spec.md`, then another for each checkpoint, then another to
implement.

string-load-save 000–001 is implemented. Do not reopen that
series from this role, and do not write `spec.md` here. Ranked
later work is [`explorations.md`](explorations.md). Layers 1–12
are implemented, including search at [`search/`](search/) and
kill at [`kill/`](kill/) and motion at [`motion/`](motion/).
Keymap is implemented and accepted at [`keymap/`](keymap/),
aloemacs-keymap 000–001. The buffer series is implemented and
accepted at [`buffer/`](buffer/), aloemacs-buffer 000–001. The
minibuffer series is implemented and accepted at
[`minibuffer/`](minibuffer/), aloemacs-minibuffer 000–001. The
prompt-command series is implemented and accepted at
[`prompt-commands/`](prompt-commands/), aloemacs-prompt-commands
000–002. Do not reopen those
series, and do not write the prompt-command `spec.md` here.

## How this conversation works

1. Read [`docs/workflow.md`](../../../workflow.md),
   [`README.md`](README.md), and this file.
2. When the human wants a new increment, write that increment's
   `README.md` and `charter.md`, then stop.
3. Idiom cleanups that are already locked may be a **standalone
   000** (goal, files, tests, stop) with no charter or spec.
4. Leave `spec.md`, `checkpoints/`, and product code to the
   conversations that own those roles.

The map in [`README.md`](README.md) is the catalog. Layer folders
under this directory already hold the issued charters, accepted
specs, and implemented checkpoints. Read a layer folder when that
layer is the topic; do not survey the whole tree on every turn.

## Where we are

| Item | State |
|---|---|
| Layers 1–12 (Text through Motion) | Implemented |
| Idiom cleanups (line-length through safe-cell-scan) | Implemented |
| runner-check | **Implemented.** Standalone 000. Down-cycle median 0.55 ms |
| safe-cell-controls | **Implemented.** Standalone 000 |
| [`../string-load-save/`](../string-load-save/) | **Implemented.** 000–001 |
| Safe cells (`ESC` / tab / `CR` on the TTY) | **Implemented.** [`safe-cells/`](safe-cells/), checkpoint 000 |
| Search (incremental, echo row) | **Implemented.** aloemacs-search 000–001 |
| Kill (mark, kill, kill-line, yank) | **Implemented.** aloemacs-kill 000–002 |
| Motion (line, page, buffer) | **Implemented.** aloemacs-motion 000 |
| Keymap (commands as values, `C-x C-s`) | **Implemented and accepted.** aloemacs-keymap 000–001 at [`keymap/`](keymap/) |
| Buffer | **Implemented and accepted.** aloemacs-buffer 000–001 at [`buffer/`](buffer/) |
| Minibuffer | **Implemented and accepted.** aloemacs-minibuffer 000–001 at [`minibuffer/`](minibuffer/) |
| Prompt commands | **Implemented and accepted.** aloemacs-prompt-commands 000–002 at [`prompt-commands/`](prompt-commands/) |
| Ranked later work | [`explorations.md`](explorations.md) |
| Scale | Withdrawn |
| Branch | `experiment/2026-09-19-aloemacs` |
| Program | `examples/aloemacs/` plus `host/racket/aloemacs-run.rkt` |
| Tour | [`demo.md`](demo.md) |

`string-load-save` is a **language-library** series (sibling of
this map, same pattern as `int-methods`). It is implemented:
kernel `split-lines` and `joined-with`. aloemacs visit and save
already send `indexed-value` and `to-string`. It is not editor
layer 9.

On this machine, Racket tests often need `TMPDIR=/tmp`.

## Role boundaries this discussion already uses

- **This conversation:** map + charters (or a standalone 000).
- **Designer:** one `charter.md` → `spec.md` → stop.
- **Checkpoint manager:** accepted spec → one numbered checkpoint
  → stop.
- **Implementer:** one checkpoint → tests → stop when green.
- The human carries files between conversations and asks for
  commits.

Plan mode is unused for this pipeline. Local identity is
`(aloemacs-text, 000)` or `(string-load-save, 000)`, never the
next `CHECKPOINTS.md` integer unless the human promotes a kernel
lift after review.

## Parked on purpose (not the next charter)

These are known residue. Leave them until the human picks one.

- Session send-forwarding until the language has delegation
- Constructor arity growth on the editor
- Class methods / class-side `(String join …)`
- Windows and M-x (see [`explorations.md`](explorations.md)
  for order). The prompt-command series is implemented and accepted at
  [`prompt-commands/`](prompt-commands/)
- Live `eval` / Mirror

Chez Emacs (`/home/dharmatech/src/e`) and Legmacs
(`/home/dharmatech/src/legmacs`) are seam catalogs. Do not port
them.

## If a historical detail is missing

Ask the human. They can quote a finding from the previous
discussion. That previous conversation remains available for
later review; it is not an input file for this one.
