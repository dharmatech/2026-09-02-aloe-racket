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
series from this role, and do not write `spec.md` here. The next
increment is whichever exploration the human names.

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
| Layers 1–8 (Text through Echo) | Implemented |
| Idiom cleanups (line-length through visited-unchanged) | Implemented |
| [`../string-load-save/`](../string-load-save/) | **Implemented.** 000–001 |
| Safe cells (`ESC` / tab / `CR` on the TTY) | Later, separate display exploration |
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
- Windows, prefix `C-x`, minibuffer, search
- Live `eval` / Mirror

Chez Emacs (`/home/dharmatech/src/e`) and Legmacs
(`/home/dharmatech/src/legmacs`) are seam catalogs. Do not port
them.

## If a historical detail is missing

Ask the human. They can quote a finding from the previous
discussion. That previous conversation remains available for
later review; it is not an input file for this one.
