# aloemacs-motion 000 — Line, page, and buffer motion

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Add six motions to the one buffer: start and end of the line, up and
down one page, and start and end of the buffer.

The point moves. The mark, the kill-ring, and the undo history stay.
The frame bytes stay. `handle-key` still takes one `String`.

Do not add a goal column. Do not scroll inside the motion. Do not add
a kernel message, a `Text` method, or a `SPEC.md` row. Do not paint a
region. Do not issue 001.

## Why this shape

Arrows already move one character or one line and keep the column,
clamped to the destination line. These commands are the same kind of
move, with a longer distance.

`handle-key` does not receive the terminal size. The runner already
calls `ensure-visible` with that size before it draws and before it
reads the next key. The editor remembers the text-row count from that
call, and page motion reads the memory. A fresh editor has not been
fitted, so its page distance is 0 and the page commands do nothing
until a fit.

The page distance is one row short of that count when the count is at
least 2, so the line that was at the bottom stays on screen. A count
of 1 moves one line. A count of 0 moves none.

The column passed to a page command is the column at the start of the
command, clamped only at the destination line. A short line in
between does not shrink it. Arrows keep clamping on every line. This
slice does not change arrows.

Line and buffer commands do not use the remembered row count.

Walking to the start or end of a long buffer uses the zipper one line
at a time. That walk is one user command. This slice does not add an
O(1) end focus.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs sends.

- Identity is **aloemacs-motion 000**. No predecessor in this folder.
  Kill 000–002 are implemented. This is not kill 003.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- `AloemacsEditor` fields today end with `(mark (Option Position))`.
  `ensure-visible` takes `columns` and `rows`. The session passes
  text rows: `rows - 1` when `rows >= 2`, otherwise `rows`.
- `move-up` and `move-down` clamp the column with `min` and
  `line-length`. At the first or last line they return `unchanged`.
  They go through `with-text-and-point`, not `from-edit`.
- Editor `handle-key` returns `unchanged` when `quit` is true. The
  session `idle-key` fallback sends any other key to that method and
  sets the echo token to `""`. An active search sends any
  non-search key through `end-search`, then `idle-key`.
- `tui-term` decodes Home, End, Page Up, and Page Down as the symbols
  `home`, `end`, `prior`, and `next`. Ctrl-Home and Ctrl-End are those
  symbols with mods exactly `'(ctrl)`. Ctrl-A and Ctrl-E are `#\a` and
  `#\e` with mods exactly `'(ctrl)`, and char either `#f` or that same
  character. The same shape as Ctrl-S.
- `(make-tkeymsg 'home)` currently becomes `"home"`.
  `tests/aloemacs/key-mapping.rkt` asserts that. This slice changes
  that result.

## Commands

All six are editor methods. Editor `handle-key` gains an arm for each
Aloe string. The session does not gain arms. A quit editor ignores
them.

| String | Motion |
|---|---|
| `"line-start"` | Column 0 on the point's line |
| `"line-end"` | Column `(line-length)` on the point's line |
| `"page-up"` | The page distance toward line 0 |
| `"page-down"` | The page distance toward the last line |
| `"buffer-start"` | Point `(0, 0)` |
| `"buffer-end"` | Last line, column `(line-length)` |

The page distance is `(text-rows - 1)` when `text-rows >= 2`, and
`text-rows` otherwise.

Each command focuses the destination line and sets the point. Page
commands keep the starting column, then `min` it with the destination
line's length. When the resulting point equals the current point,
return `unchanged`. Do not push an undo frame. Do not read or write
the mark or the kill-ring.

`buffer-end` walks `focus-down` while `has-next?` is true. It does
not send `lines` or `to-string`. `buffer-start` uses `focus-at` of
line 0. An empty buffer is already `(0, 0)` for both.

`text-rows` is not part of `UndoFrame`. Undo keeps the receiver's
current `text-rows`, the same way it keeps the mark.

## The remembered row count

Append one field after `mark`:

```aloe
(text-rows Int)
```

The constructor gains that argument at the end. A fresh editor and a
successful visit pass `0`. Every other `AloemacsEditor new` in
`examples/aloemacs/` and `tests/aloemacs/` passes the receiver's
current `text-rows`, except `ensure-visible`, which stores its `rows`
argument.

`ensure-visible` still fits `scroll-row` and `scroll-col` as it does
today. It also stores `rows` into `text-rows` on that rebuild. The
motion methods do not change `scroll-row` or `scroll-col`. The
runner's existing `ensure-visible` before the next frame brings the
point on screen.

`frame` and `safe-cells` do not read `text-rows`.

A bare `0` is an `Int`. This field does not need the `(Option None)`
spelling.

Find every `AloemacsEditor new`. Do not treat a file list copied from
an older checkpoint as complete. A test whose purpose is an arity or
type error may keep that error. Every other constructor site gains
the argument.

## Keys

In `tkeymsg->aloe-key`, recognize these before the printable-character
branches and before `(symbol? key)` becomes `(symbol->string key)`.

| Message | Aloe string |
|---|---|
| `#\a`, mods exactly `'(ctrl)`, char `#f` or `#\a` | `"line-start"` |
| `#\e`, mods exactly `'(ctrl)`, char `#f` or `#\e` | `"line-end"` |
| symbol `home`, mods `'()` | `"line-start"` |
| symbol `end`, mods `'()` | `"line-end"` |
| symbol `home`, mods exactly `'(ctrl)` | `"buffer-start"` |
| symbol `end`, mods exactly `'(ctrl)` | `"buffer-end"` |
| symbol `prior`, mods `'()` | `"page-up"` |
| symbol `next`, mods `'()` | `"page-down"` |

Ctrl-Shift-A still inserts `"a"`, because its mods are not exactly
`'(ctrl)`. Shift-Home stays the symbol string `"home"`, and the
editor has no `"home"` arm, so it does not move. Ctrl-S, Ctrl-F,
Ctrl-Z, and the kill chords stay as they are. A plain `a` or `e`
still inserts.

## Echo and search

Do not add session arms and do not add an echo token. The idle
fallback already clears the echo token and sends the string to the
editor. Search already ends, then uses that fallback, for any key
other than the search keys. A test must show `"line-start"` during a
search ends the search, clears the token, and moves the point.

## Tests

Write the tests first. No TTY.

`tests/aloemacs/motion-editor.rkt` sends the six strings through the
editor, and one of them through the session:

- Mid-line `"line-start"` and `"line-end"`, and the no-op when the
  point is already there.
- A multiline buffer: `"buffer-start"` is `(0, 0)`, `"buffer-end"` is
  the last line at its length. An empty buffer stays `(0, 0)`.
- After `(editor ensure-visible 80 24)`, `"page-down"` moves 23
  lines. A short line between the start and the destination does not
  shrink the column. The destination clamps it.
- `text-rows` of 0 does not move. `text-rows` of 1 moves one line.
- `"page-up"` from a line above the distance lands on line 0.
- History length and the mark are the same after each motion.
- A session whose echo token is `"saved"` sends `"page-down"` and
  the token becomes `""`.
- A searching session sends `"line-start"` and is idle, with an empty
  echo token, at column 0.
- A quit editor ignores `"line-end"`.

`tests/aloemacs/motion-keys.rkt` checks the table above, including
the `#f` char variant, Ctrl-Shift-A, and Shift-Home.

In `tests/aloemacs/key-mapping.rkt`, the case that expects
`(make-tkeymsg 'home)` to be `"home"` moves to a symbol this slice
does not claim. `f1` stays `"f1"`.

Existing frame assertions stay. They change only where a constructor
call needs the new argument.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe`
- `examples/aloemacs/file.aloe`, only to pass `text-rows` at each
  `AloemacsEditor new`
- `examples/aloemacs/main.aloe`, the same argument
- `host/racket/term.rkt`
- `tests/aloemacs/motion-editor.rkt` and
  `tests/aloemacs/motion-keys.rkt`, created by this slice
- `tests/aloemacs/key-mapping.rkt`, the Home case above
- other files under `tests/aloemacs/` and `examples/aloemacs/` only
  to add the constructor argument

### Must leave untouched

- `lib/text.aloe`, `SPEC.md`, `CHECKPOINTS.md`
- `host/racket/aloemacs-run.rkt`
- the kill, search, undo, echo, and safe-cells specs and checkpoints
- frame ANSI, except constructor arguments in tests

## Verification and completion

From the project root:

```text
TMPDIR=/tmp raco test -y tests/aloemacs/motion-editor.rkt tests/aloemacs/motion-keys.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
```

The checkpoint is complete when both commands pass and `git diff
--check` is clean. Stop. Do not start 001. If the constructor
threading will not fit this conversation, stop and tell the human
the slice needs a charter. Do not widen it.
