# aloemacs safe cells specification

**Status: Accepted.** Implemented as aloemacs-safe-cells 000. This is local editor design, not
Aloe language law. This file is the complete design input for the checkpoint
manager and implementer; they need not read the charter.
`SPEC.md` governs Aloe syntax and evaluation.

The editor paints a control character from file text or the echo label as
one blank cell. It changes only the frame's displayed text. The original
String, Text, path, and saved content retain their characters.

## 1. Checkpoint series

The identity is **aloemacs-safe-cells**. The first checkpoint is spoken
**aloemacs-safe-cells 000** and filed as `checkpoints/000-slug.md`.
Numbers have three digits, start at 000, and are never renumbered; slugs
are lowercase words separated by hyphens. The checkpoint manager writes
one checkpoint and stops. The implementer tests that one slice and stops
when green. Code and tests live at the project root
`/home/dharmatech/journal/2026-09-02-aloe-racket`, outside this design
folder.

One checkpoint should cover both text rows and the echo label because they
use the same replacement method. If that exceeds the checkpoint size in
`docs/workflow.md`, the manager may split it into consecutive checkpoints:
text rows first, echo label second. The series is unfinished until both
sites pass their tests. The manager must add no other feature and must not
issue multiple checkpoints in one conversation.

## 2. Boundary and authority

The implemented Loop supplies one String frame with ANSI chrome and CRLF
row separators. The implemented Echo layer reserves the last row of a
session frame and clips its label with `take`. The implemented Index layer
supplies `indexed-value`; the completed `string-load-save` series supplies
`split-lines`, `joined-with`, and `to-string`. Their behavior and call sites
stay as they are. `../README.md` sets the ASCII, one-character-per-cell
editor layout;
`../loop/spec.md` and `../loop/charter.md` govern the frame;
`../echo/spec.md` governs the session row and its cursor sequences;
`../viewport/charter.md` excludes display-column expansion; and
`../../string-load-save/spec.md` governs visit/save text preservation.
This spec supersedes the earlier lack of a control-display rule only at
the two frame call sites. `SPEC.md` wins on language behavior.

The implementation scope is `examples/aloemacs/editor.aloe` and
`examples/aloemacs/file.aloe`, with focused and existing tests under
`tests/aloemacs/`. Do not change the kernel, `SPEC.md`, `CHECKPOINTS.md`,
`lib/string.aloe`, `lib/text.aloe`, `host/racket/term.rkt`, the runner,
or the key map. In particular, visiting and saving still use their
current `Text` and Fs paths. No new host or kernel message is needed.

This series adds no Tab key or insertion command, indent rule, tab stop,
caret notation, display-column model, ANSI interpretation of file text,
CR stripping, newline conversion, Unicode width rule, mode, minibuffer,
search, window, or Boids behavior.

## 3. Host, layout, and commands

The application code is checked Aloe in `examples/aloemacs/`. Racket tests
use a checked driver and existing Fs doubles without a TTY. The current
interactive command remains `racket host/racket/aloemacs-run.rkt` with an
optional path argument; this series needs no new build step or dependency.

Write failing tests before product edits. From the project root, use
`TMPDIR=/tmp raco test tests/aloemacs` for the focused suite and
`TMPDIR=/tmp raco test tests` for the final regression. The `TMPDIR`
setting is required for Racket tests on this machine. A terminal look may
help debugging but is not acceptance evidence.

## 4. One-cell replacement

`AloemacsEditor` gains a method with this exact send and checked type:

```text
(editor safe-cells clipped-string) : String
clipped-string : String
```

The method walks the argument from left to right. For each character
with code 0 through 31 inclusive, or 127 (`DEL`), it appends one ordinary
space (code 32). For every other character it appends that character
unchanged. Thus the result has the same String `len` as the argument;
`""` produces `""`. `ESC` followed by printable `[31m` becomes a space
followed by `[31m`. Characters 128 and above copy through. This method is
display-only and does not change the editor or session payload.

The current String API has no character-code or ordering send. Implement
membership in Aloe by comparing a one-character String for equality with
the 33 literal one-character controls (`\u0000` through `\u001f`, and
`\u007f`), using existing sends, `if`, and/or List operations. Scan only
the clipped String. Do not add a primitive, special form, or host helper.

## 5. Frame placement and columns

For each editor text row, the order is exactly:

```text
clipped = ((line drop left) take columns)
shown   = (editor safe-cells clipped)
```

`AloemacsEditor.frame` joins the shown rows with its existing `"\r\n"`
separator, then passes that body to its existing ANSI frame constructor.
The walk never sees the full source line, the row separators, the completed
frame, or the editor's own cursor sequences.

For a session with at least two rows, retain the Echo layer's label and
status-prefix rules. After it computes `row`, the order is exactly:

```text
clipped = row take columns
shown   = (editor safe-cells clipped)
```

`AloemacsSession.frame` inserts `shown` into its existing last-row ANSI
suffix. It uses its stored editor as the receiver of `safe-cells`. For a
one-row session it still returns the editor frame without an echo label.
The row's own control characters, whether from a stored path or otherwise,
are painted as spaces only after clipping. The stored `Path.text` and
`echo` field are unchanged.

Point, `scroll-col`, `ensure-visible`, and both editor and session
cursor-column formulas continue to count source characters. A tab is one
character and becomes one blank cell; point on a tab retains its current
one-based cursor column. `split-lines` still splits only on LF, so CR in a
CRLF file remains at the end of a line, counts as one character, and
paints as one space. No control character from clipped source text or a
clipped echo label reaches the terminal as a control byte. The frame's
own ANSI `ESC` bytes and CRLF separators remain byte-for-byte unchanged.

## 6. No-TTY verification

Focused tests under `tests/aloemacs/` use checked Aloe loads and exact
frame expectations. To inspect a frame's displayed regions, test helpers
may extract the editor body after its fixed concatenated prefix
`\u001b[?25l\u001b[2J\u001b[H` and before the next editor
cursor-address `ESC[` marker. For a session with an echo row, extract the
label after its `ESC[rows;1H` marker and before the following
cursor-address `ESC[`.
No displayed region contains `ESC` after replacement, so these are
unambiguous boundaries. Assert the fixed chrome and cursor sequences
separately, or compare the full frame to an exact expected String. Never
assert that the whole frame has no `ESC`.

Tests must prove all of the following:

1. A direct checked send of `safe-cells` replaces all 33 specified
   controls, preserves length, and copies printable characters and those
   with codes 128 and above. A shown text line containing `ESC` (27), tab
   (9), `CR` (13), one other code below 32 (0 or 7), and `DEL` (127)
   shows one space in each
   position, without shortening the row. An `ESC` followed by `[31m`
   shows ` [31m`; those four printable characters remain literal.
2. A control left of `scroll-col` and one past the right edge do not
   appear in the clipped body. An empty clip remains empty. A point on a
   tab keeps today's character-based cursor column.
3. An echo label with `ESC` and tab in its path shows spaces at those
   positions after `row take columns`. The stored path is unchanged.
   Status prefixes keep the Echo layer's order and clipping rule.
4. The frame's own cursor sequences still contain `ESC`, and its row
   separators remain `"\r\n"`. Existing printable ASCII frame goldens
   remain exact.
5. Visiting and saving a buffer containing tab, `CR`, and `ESC` writes
   those original characters through the Fs double. A CRLF input still
   has its CR before each LF when saved.

Both call sites and the focused suite must pass before the series is
accepted. The full repository suite must pass after the final slice.
