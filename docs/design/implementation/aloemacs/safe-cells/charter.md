# Charter — aloemacs safe cells

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for **safe
cells**: a control character in file text or in the echo label
occupies one blank cell, so the terminal does not execute it.
Then **stop**. Do not write checkpoints. Do not implement. Do not
specify a Tab key, indent, tab stops, or caret notation.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-safe-cells 000** under
   `docs/design/implementation/aloemacs/safe-cells/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. A Tab binding, inserting
spaces, display columns, and interpreting a file's escape
sequences are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../loop/`](../loop/) | `frame` is one `String`. ASCII, one cell per character. Tabs and controls have no layout semantics yet |
| [`../echo/`](../echo/) | Session frame reserves the last row and clips the label with `take` |
| [`../string-load-save/`](../../string-load-save/) | Visit and save already use `indexed-value` and `to-string`. Leave that series alone |

**Why this layer:** the frame is one byte string. A raw `ESC`,
tab, `CR`, or other control copied from the buffer is executed
by the host terminal. `ESC` can swallow the editor's later cursor
sequence, `CR` returns the cursor to column 1, and a tab jumps to
the terminal's tab stop while the editor counts one character.

The bytes arrive by visiting a file. The Tab key is still an
unsupported key in `host/racket/term.rkt`. This layer does not
add it.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **One blank cell.** In a clipped text row and in the clipped
   echo label, every character whose code is below 32, and
   character 127 (`DEL`), is displayed as one space (code 32).
   The string length is unchanged. Printable characters,
   including the `[31m` that may follow a file's `ESC`, stay.
2. **Clip first.** Text rows are sanitized after
   `(line drop left) take columns`, and before those rows are
   joined with `"\r\n"`. The echo label is sanitized after
   `(row take columns)`, before it is placed in the session
   frame. The walk sees a screen-width string. The finished
   frame, the editor's own cursor sequences, and the `"\r\n"`
   row separators are not sanitized.
3. **Columns stay character columns.** Point, `scroll-col`, and
   the cursor-column formula are unchanged. A tab still counts
   as one character. A `CR` that `split-lines` left inside a
   line still counts as one character and displays as a space,
   so a CRLF file shows a blank at the end of each line.
4. **Save writes the original bytes.** Visit, `Text`,
   `split-lines`, and `joined-with` are unchanged.
5. **Tests first**, no TTY, under `tests/aloemacs/`. At least:
   - a shown line containing `ESC` (27), tab (9), `CR` (13),
     one other code below 32 (0 or 7), and `DEL` (127) displays
     spaces in those positions
   - `ESC` followed by printable `[31m` displays a space and
     then those four characters
   - a control left of `scroll-col`, and a control past the
     right edge, are absent from the clipped text
   - an empty clip stays empty
   - point sitting on a tab still produces today's character
     cursor column
   - an echo label whose path contains `ESC` and tab displays
     spaces there; the stored path is unchanged
   - the frame's own cursor sequences still contain `ESC`
   - save of a buffer that contains tab, `CR`, and `ESC` writes
     those bytes
   - a printable ASCII frame still matches existing goldens
6. On this machine, Racket tests need `TMPDIR=/tmp`.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 The mark is one space

E's screen rule: a control occupies one blank cell. The surveyed
caret (`^M`, `^[`) and tab-stop rules are a different charter.
They change column math. Unicode control pictures and parsing a
file's `ESC` as color are out.

The set is every code below 32, plus 127. That includes tab,
`CR`, `ESC`, backspace, bell, vertical tab, and form feed. Codes
128 and above copy through. Unicode width is a later exploration.

### 4.2 The editor owns the replacement

`AloemacsEditor.frame` sends it for each clipped line.
`AloemacsSession.frame` sends the clipped echo label to that same
editor method. Display policy stays in `examples/aloemacs/`.

No new kernel message. No `SPEC.md` row. No change to
`lib/string.aloe`, `lib/text.aloe`, or Term.

### 4.3 Length is part of the contract

Replacement does not delete the control and does not expand it.
Clip and cursor math stay correct because one character remains
one character. A later indent command can count the same column
the screen uses.

### 4.4 File bytes stay file bytes

`split-lines` splits on LF only, so `"a\r\nb"` is the line
`"a\r"` then `"b"`. This layer paints the `CR`. It does not
strip it on visit and does not remember a newline convention.

### 4.5 One checkpoint is the intended slice

Text rows and the echo label are the same rule at two call
sites. **aloemacs-safe-cells 000** should do both. Split only if
that slice misses the checkpoint size in `docs/workflow.md`:
text rows first, echo label second. A text-only result still
leaves the label unsanitized, so the series is unfinished until
both sites are tested.

### 4.6 Resolve these

1. The selector name for the editor method that replaces
   controls in one string.
2. How a test reads the clipped text and the echo label out of
   a frame whose chrome also contains `ESC`. The whole frame
   string is the wrong place to assert "no `ESC`."

## 5. Authority

- [`../README.md`](../README.md) — ASCII, one cell per character
- [`../loop/spec.md`](../loop/spec.md) — printable one-cell
  layout; controls have no layout semantics yet
- [`../loop/charter.md`](../loop/charter.md) — frame bytes,
  §4.8
- [`../echo/spec.md`](../echo/spec.md) — label clip and the
  session's own cursor sequences
- [`../viewport/charter.md`](../viewport/charter.md) — no
  display-column expansion
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `(line drop left) take columns`, then join with `"\r\n"`
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `(row take columns)` on the echo label
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — Tab is unsupported; do not change that mapping
- [`../../string-load-save/spec.md`](../../string-load-save/spec.md)
  — `split-lines` and `joined-with` are accepted; do not reopen

`SPEC.md` remains language law. This spec is not language law.
When a seam document and this charter disagree about controls,
this charter wins for display. It does not win against `SPEC.md`.

## 6. Non-goals

- A Tab key, a programming mode, or inserting spaces to a stop
- Inserting a tab character
- Tab stops, caret notation (`^M`, `^[`), or a display column
  distinct from the character column
- Interpreting `ESC` in the file as ANSI color
- Unicode control pictures, `wcwidth`, grapheme clusters
- Stripping `CR` on visit, or a newline convention on save
- Changing `Text`, `split-lines`, `joined-with`, Term, or the
  key map
- Kernel or `SPEC.md` edits
- Minibuffer, search, prefix maps, windows

Indent and tab display belong with language modes in
[`../explorations.md`](../explorations.md). This charter does not
choose a stop width.

When that later charter is written, the mode owns the width. A
spaces language inserts spaces to the next stop. Make and Go
insert one tab byte. The same width paints that one tab as blank
cells out to the next stop: the buffer keeps the single tab, the
cursor sits on that character, and save writes the tab. Until a
mode supplies a width, this layer's one-space rule remains. The
charter that teaches the frame those screen columns is the mode
charter, not this spec.

## 7. Handoff

- Series identity: `aloemacs-safe-cells`.
- Checkpoint 000 is spoken **aloemacs-safe-cells 000** and filed
  as `checkpoints/000-slug.md`. Numbers are three digits, start
  at 000, and are never renumbered. The checkpoint manager
  writes one checkpoint, then stops.
- Intended order: one checkpoint, both call sites (§4.5).
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.
