# Charter — aloemacs mouse

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **a button event that
reaches Aloe, and a left press that places the point**. The series
identity is **aloemacs-mouse**. Term gains one method, `read-event`,
on the read the editor already blocks on. A key still arrives as
the string it arrives as today. A left, middle, or right press or
release arrives as one string. A left press in a window's text
selects that window and places its point. Then **stop**. Do not
write checkpoints. Do not implement.

This effort refuses motion and hover, wheel scrolling, a click that
splits or deletes a window, a menu, a command on the mode line, the
directory browser, describe, jump to definition, faces, highlighting,
a language server, modules, and worksheet evaluation. It refuses
clipboard, paste, PTY, and daemon. It refuses a change to
`tui-term`. Those stay later or out, so this spec stays small
enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Do not reopen them.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-mouse 000** under
   `docs/design/implementation/aloemacs/mouse/checkpoints/`.
4. Stop. The human reviews the spec. Do not write that checkpoint
   file.

Keep the spec to the checkpoint in §4.9. A delivered event that
the editor ignores is not a checkpoint. Motion, a wheel, a second
host capability, and a new crossing type are defects in this
document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../term/`](../term/) | aloemacs-term 000 is accepted. Term is one injected capability. The ordered methods are `read-key`, `write-line`, `write`, `columns`, `rows`. `read-key` returns a `String` and ignores mouse and resize. The frame is one `String` passed to `write`. `call-with-tty-term-receiver` owns the `tui-term` lifetime. Gel sends only `read-key` and `write-line` |
| [`../window-point/`](../window-point/) | aloemacs-window-point 000 is implemented and accepted. Each view stores its own point and origin. The selected view's point equals the editor point. `other-window` stores the departing view, then `enter-view` installs the entered view's point and origin. The following fit is the runner's `ensure-visible` |
| [`../windows/`](../windows/) | A window is a view of a buffer. The tree is `Leaf`, `Below`, and `Right`. Rectangles are 0-based `(x, y, columns, rows)`. Right reserves one column between the leaves |
| [`../mode-line/`](../mode-line/) and [`../window-bars/`](../window-bars/) | A leaf at least two rows tall paints its bar on its last row. A shorter leaf is all text. The bar's text is the buffer name, which is the full path |
| [`../idle-echo/`](../idle-echo/) | The echo row is blank while idle when the selected leaf is at least two rows tall. Save, search, and prompt text stay. Do not reopen that series |
| [`../completion/`](../completion/) and [`../completion-page/`](../completion-page/) | Completion rows can occupy the screen above the echo while a prompt is active. `root-rect` shrinks by `completion-row-count` |
| [`../keymap/`](../keymap/) | `handle-key` is the session's key path: quit, then search, then prompt, then the keymap. A pending prefix is `pending` |
| The runner | [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt) reads columns and rows, fits, records pictures, writes the frame, then blocks on `(term read-key)` and sends that string to `handle-key` |

Final human review of any predecessor remains that predecessor's
business. This series reads the accepted specs and the current
program and does not wait. It does not edit those specs, those
charters, or those checkpoints. A defect there that blocks a click
stops this spec; the designer reports it and does not patch the
earlier series from here.

The parent map, [`../explorations.md`](../explorations.md), and
[`../discussion.md`](../discussion.md) stay as they are. This
series does not edit them.

**Why this layer:** `read-next-key` in
[`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
already receives `tui-term` mouse messages and discards them with
resize. The host never turns mouse reporting on. The editor cannot
place a point from a click until that same read can yield a button,
and until a left press in a leaf's text uses the per-window point
that already exists.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **A press and a release reach Aloe.** Left, middle, and right,
   each as a press and as a release, cross as one `String` on
   `(term read-event)`. A key that the editor already understands
   still crosses as the same `String` `(term read-key)` returns
   today. The frame stays one `String`. The crossing vocabulary
   stays `Int`, `Bool`, `String`, and `(List String)`.
2. **`read-key` still ignores mouse.** A mouse string followed by
   a key makes `(term read-key)` return the key. Gel still sends
   only `read-key` and `write-line`. Gel's runner does not turn
   mouse reporting on. `call-with-tty-term-receiver` stays free of
   mouse reporting.
3. **The editor asks for buttons, and only buttons.** The Aloemacs
   TTY entry enables mode `1000` and SGR `1006`, and disables both
   before the terminal is torn down, including when the loop fails.
   It does not enable mode `1003`. A scripted run writes no enable
   bytes.
4. **A left press in text places the point.** In the selected
   window, the point moves to that cell, clamped to the text. In
   another window, that window becomes selected and its point
   moves to that cell. The window left behind keeps the point it
   had. Other views keep the points they stored.
5. **Chrome is recognized and does not place the point.** A left
   press on a mode line, the echo row, a completion row, or a
   vertical bar leaves the point, the selection, and the echo
   token as they were. A left release, a middle button, and a
   right button do the same wherever they land.
6. **An active prompt, search, or prefix stays active.** A mouse
   string during any of those leaves that activity, the point, and
   the selection as they were. The string is not inserted.
7. **Tests are the proof.** The focused tests inject the mouse
   string through the existing reader thunk. They do not open a
   TTY. The spec names one hand check a person runs after those
   tests are green.
8. **000 is the whole series.** The host read and the click are
   one checkpoint. The spec does not plan 001.

## 4. Locked decisions

### 4.1 One more method on Term

Term stays one injected capability. Append one method. The ordered
interface becomes:

| Order | Send | Type | Result |
|---:|---|---|---|
| 1 | `(term read-key)` | `() -> String` | The next key string. A mouse string is skipped. |
| 2 | `(term write-line s)` | `(String) -> String` | Unchanged. |
| 3 | `(term write s)` | `(String) -> String` | Unchanged. |
| 4 | `(term columns)` | `() -> Int` | Unchanged. |
| 5 | `(term rows)` | `() -> Int` | Unchanged. |
| 6 | `(term read-event)` | `() -> String` | The next key string or the next mouse string. |

`make-term-receiver` keeps its arguments: output port, reader thunk,
size reader. The thunk still returns one `String`. `read-event`
returns that string. `read-key` calls the thunk again while the
string is a mouse event, and returns the first string that is not.
Existing key scripts stay green because the Aloemacs runner calls
`read-event` only, and a key string passes through it unchanged.

The production TTY thunk is the shared reader. It still maps a
`tkeymsg` through `tkeymsg->aloe-key`. It maps a button event to
the mouse string in §4.2. It skips resize. End of input is still
an error on both methods.

The Aloemacs loop in `run-aloemacs-with-hosts` blocks here:

```aloe
(define aloemacs-editor
  (aloemacs-editor handle-event (term read-event)))
```

The order around that send stays: columns, rows, `ensure-visible`,
`record-pictures`, `frame`, `write`, then this send. The loop does
not also call `read-key`. `handle-event` sends every non-mouse
string to the existing `handle-key`. Quit still wins before the
string is examined, and the receiver is unchanged.

`host/racket/gel-run.rkt` and `host/racket/term-run.rkt` are not
edited. Gel still sends only `read-key` and `write-line`. Neither
runner contains `read-event`, `1000`, or `term-enable-mouse`. The
spec does not assert that either file contains `(term read-key)`.
`gel-run.rkt` does not contain that phrase. `term-run.rkt`
contains it only in a comment. The checks in
`tests/checkpoint-86.rkt` stay as they are.

### 4.2 The mouse string

A mouse event is this entire string, fields separated by one
space, with no extra spaces:

```text
mouse <down|up> <left|middle|right> <column> <row>
```

`down` is a press and `up` is a release. The button is `left`,
`middle`, or `right`. `column` and `row` are canonical decimals:
`0`, or a non-zero digit followed by digits. No sign and no
leading zero. Examples: `mouse down left 4 2`,
`mouse up middle 0 0`.

The host builds that string from a `tmousemsg` whose kind is
`button-down` or `button-up`, whose button is `left`, `middle`,
or `right`, and whose position has both components exact and
greater than or equal to zero. `tpoint-x` is the column.
`tpoint-y` is the row. Those components are already 0-based:
SGR `\e[<0;2;3M` is 1-based column 2, row 3, and `tui-term`
stores `(1, 2)`.

`tui/term` exports the `tmousemsg` accessors and
`make-tmousemsg-leave`. It does not export `tpoint`, `tpoint-x`,
`tpoint-y`, or `make-tmousemsg`. The host requires
`tui/term/geometry` for the point accessors. The focused test
requires `tui/term/geometry` for `tpoint` and `tui/term/messages`
for `make-tmousemsg`. Requiring those modules does not change
tui-term.

`read-key` treats a string as a mouse event only when the whole
string matches this grammar. Any other string is a key, including
a string the host would never produce.

These `tmousemsg` values produce no string and are skipped, the
way resize is skipped:

- kind `move`
- kind `wheel-up` or `wheel-down`
- a button other than `left`, `middle`, or `right`, including `#f`
- a negative column or row

A modified click arrives from `tui-term` with button `#f`, because
the decoder does not strip shift, meta, or control. It is skipped
with the other unknown buttons. This series does not change
`tui-term` and does not add a modifier field.

### 4.3 Button-only reporting

`term-enable-mouse` sends any-event tracking, mode `1003`, plus
SGR `1006`. This series does not call it.

`run-aloemacs`, the TTY entry, writes these bytes to the terminal
output after `with-term` has that port, and before the editor
loop:

```text
ESC [ ? 1 0 0 0 h ESC [ ? 1 0 0 6 h
```

Before that procedure returns, and before an exception leaves it,
while the port still accepts output, it writes:

```text
ESC [ ? 1 0 0 0 l ESC [ ? 1 0 0 6 l
```

`with-term` then disables `1003` and `1006` itself. The runner's
own `1000` disable is what turns button tracking off for the
shell. The bytes are terminal setup. They are not part of the
frame string and they are not an Aloe send.

`run-aloemacs-with-hosts` and `run-aloemacs-with-term` do not
write those bytes. `call-with-tty-term-receiver` does not write
them. A scripted frame stays free of them.

### 4.4 Where a cell lands

The click uses the geometry the last fit stored: `windows.columns`,
`windows.rows`, `root-rect`, `completion-row-count`, and the
leaf rectangles from the tree. Coordinates are the 0-based column
and row from §4.2. A cell is inside a rectangle when
`x <= column < x + columns` and `y <= row < y + rows`. The
cursor address already agrees with that origin: CUP row is
`rect.y + point.line - scroll-row + 1`, and CUP column is
`rect.x + point.column - scroll-col + 1`.

Classify in this order. The first match wins.

| Order | Region | Cell | Result |
|---:|---|---|---|
| 1 | Echo | `rows >= 2` and `row = rows - 1` | No placement |
| 2 | Completion | `row` is in `[root.rows, root.rows + completion-row-count)` | No placement |
| 3 | Mode line | Inside a leaf whose `rows >= 2`, on that leaf's last row | No placement |
| 4 | Text | Inside a leaf, and not its mode line | §4.5 |
| 5 | Elsewhere | A vertical bar, a gap, or any cell outside every leaf | No placement |

A leaf shorter than two rows is all text. A terminal shorter than
two rows has no echo row, and its completion count is 0. Leaf
rectangles do not overlap. The right-split bar is the column
between them.

On an 80 by 24 screen with no completion rows, the root is
`(0, 0, 80, 23)` and the echo row is 23. One tall leaf uses rows
0 through 21 as text and row 22 as the mode line. A Below split
gives `(0, 0, 80, 12)` and `(0, 12, 80, 11)`: mode lines on rows
11 and 22, text on 0 through 10 and 12 through 21. A Right split
of 80 columns puts the bar on column 40; the right leaf starts
at column 41. The spec takes a later screen from the same
rectangle methods. The windows spec's old divider arithmetic is
not this geometry.

Completion rows exist while a prompt is active. §4.6 refuses
every mouse event during a prompt, so a completion press and a
text press during a prompt have the same observable result. The
region table is still the definition of a text cell. The
completion proof clicks a completion row and shows the prompt
and the point unchanged.

### 4.5 The left press

Placement runs only for `mouse down left` in a text cell, and
only when §4.6 allows it.

The cell's line and column, before clamping:

```text
line   = view.scroll-row + (row - rect.y)
column = view.scroll-col + (column - rect.x)
```

Clamp with the text's existing line length. A column past that
length becomes that length, which is the position after the last
character. A line past the last line becomes the last line at
that line's length. The spec names the send that installs this
point. The characters stay. The Text focus moves to the placed
line: the editor's `at-focused` when the line exists, and the
editor's `buffer-end` when it does not. The send does not change
the mark, the kill ring, or the undo history, and it does not
push an undo frame. It writes the editor point onto the selected
view through the
existing `with-editor` path, so the selected view's stored point
equals the editor point. It does not change the origin. The
runner's next `ensure-visible` is the fit, as it is after a
motion key. A session proof that the click itself preserved the
origin calls `handle-event` without that fit.

The selected leaf is already selected. Place the point and clear
the echo token the way a motion command does, with `with-echo ""`.
That clear happens even when the point was already on that cell.

Another leaf uses the `other-window` handoff and no other
selection rule. Store the departing view's live point and origin
first, then `enter-view` of the clicked leaf, then place the
point and clear the echo token. The departed view keeps the
point it stored. The entered view's old point is replaced by
the click. Its origin is the origin `enter-view` installed,
until the later fit. A locked leaf can be selected. Views that
were not the departure and not the arrival keep their points
and origins.

A placing click does not call `ensure-visible` itself.

### 4.6 Events that leave the session as it was

`handle-event` returns the receiver unchanged for every mouse
string except the placement in §4.5. Unchanged covers the point,
the selection, every view's stored point and origin, the echo
token, the text, the mark, the kill ring, and the undo history.

That list includes:

- `mouse up left`
- `mouse down middle`, `mouse up middle`, `mouse down right`,
  and `mouse up right`, in any region
- a left press on the echo row, a completion row, a mode line,
  a vertical bar, or any other non-text cell
- any mouse string while `searching` is true, while the prompt
  is present, or while `pending` is present

Those three activities stay as they were. The event does not end
the search, submit or cancel the prompt, clear the prefix, or
insert the string. A mouse string never reaches the keymap.

A key string still takes the existing `handle-key` path,
including quit, search, prompt, prefix, and self-insert.

### 4.7 What this series leaves alone

The frame's bytes stay the frame's bytes. A click that moves the
point changes the cursor address the next frame already computes.
The picture reuse key does not gain the point. `record-pictures`
stays. Mode-line paint, bar color, and idle-echo paint stay.
Direct editor `frame` stays the one-view frame.

The keymap tables gain no binding. The click is not a command
constructor. `AloemacsEditor.handle-key` stays the editor's key
method. The session's `handle-key` stays the key path that
`handle-event` sends to.

The accepted Term spec stays the authority for the first five
methods and for the observable rule that `read-key` ignores mouse
and resize. This spec is the authority for `read-event`, for the
mouse string, and for `read-key` skipping that string. Do not
rewrite
[`../term/spec.md`](../term/spec.md),
[`../term/charter.md`](../term/charter.md), or the Term
checkpoints.

`docs/gel.md` section 6 and the host-terminal paragraph in
`docs/decisions.md` gain a factual catalog line for `read-event`.
Both still say Gel sends only `read-key` and `write-line`, and
that `read-key` ignores mouse. Gel's "no mouse" scope stays true
for Gel.

### 4.8 Proof

The focused tests live under `tests/aloemacs/`. The spec names
the file. They use a checked driver and `make-term-receiver`.
They do not call `with-term`, `call-with-tty-term-receiver`, or
`run-aloemacs`. A no-TTY test injects a mouse string by returning
it from the reader thunk. A formatter proof may construct a
`tmousemsg` in Racket. That proof does not open a terminal.

The focused proof shows all of these:

- `read-event` returns a scripted `mouse down left 4 2`.
- `read-key` skips that string and returns the following key.
- The production selector order is
  `(read-key write-line write columns rows read-event)`, and
  the return types are
  `(String String String Int Int String)`.
- A constructed left press at `(4, 2)` formats as
  `mouse down left 4 2`. A constructed release formats with
  `up`. Motion, wheel, an unknown button, and a negative
  component produce no string.
- Through the runner, a scripted left press in another window's
  text selects that window and places its point. The window
  left behind keeps its point.
- A left press in the selected window's text places that point
  and clears a `saved` echo token. Another view's point stays.
- A left press past the end of a short line clamps to that
  line's length. A left press in the blank text rows below the
  last line places the point at the end of the last line. The
  click itself leaves the origin unchanged.
- A left release, a middle press, and a right press leave the
  point and the selection unchanged.
- A left press on the mode line, the echo row, and a vertical
  bar leaves the point, the selection, and the echo token
  unchanged.
- During a prompt that is showing completion rows, a left press
  on a completion row leaves the prompt and the point unchanged.
  During search, and during a pending prefix, a left press in
  text leaves that activity and the point unchanged.
- The mouse string is not inserted. A later ordinary key still
  inserts, moves, or quits. The mark and the undo history are
  unchanged by a press that places the point. The characters are
  unchanged. The Text focus is on the placed line.

These production-catalog assertions gain `read-event` as the
sixth row. Their assertions about the first five rows keep their
meaning:

- [`tests/checkpoint-53.rkt`](../../../../../tests/checkpoint-53.rkt)
- [`tests/checkpoint-84.rkt`](../../../../../tests/checkpoint-84.rkt)
- [`tests/checkpoint-87.rkt`](../../../../../tests/checkpoint-87.rkt)
  (the reflected message count, the signature count, and the
  expected rows)
- [`tests/aloemacs/term-capability.rkt`](../../../../../tests/aloemacs/term-capability.rkt)

[`tests/aloemacs/viewport-runner.rkt`](../../../../../tests/aloemacs/viewport-runner.rkt)
moves its source-order phrase from `(term read-key)` to
`(term read-event)`, in the same position after the frame.
[`tests/aloemacs/file-runner.rkt`](../../../../../tests/aloemacs/file-runner.rkt)
moves its source phrase from `aloemacs-editor handle-key` to
`aloemacs-editor handle-event`. A behavioral proof in that file
still shows a scripted key is handled.

Leave these alone. They are Gel, `term-run`, or a local
two-method fixture, or they already call `read-key` or
`handle-key` as the key path:

- [`tests/checkpoint-83.rkt`](../../../../../tests/checkpoint-83.rkt)
- [`tests/checkpoint-85.rkt`](../../../../../tests/checkpoint-85.rkt)
- [`tests/checkpoint-86.rkt`](../../../../../tests/checkpoint-86.rkt)
- session tests that send `handle-key` a key string

Existing scripted runners stay green without new frames. Their
thunks return key strings, and `read-event` returns those strings.
The spec names a source proof that `run-aloemacs` contains the
`1000` and `1006` enable and disable sequences and does not
contain `1003` or `term-enable-mouse`.

The hand check is the human's, after the tests are green. The
implementer does not need a TTY to finish. From the project root,
on a terminal at least 80 by 24:

1. `racket host/racket/aloemacs-run.rkt` on a scratch file.
   `C-x 2`. Click text in the other window. That window is
   selected and the point is on the clicked character. The first
   window still shows the place it had.
2. Click that window's mode line. The point stays.
3. Click the echo row. The point stays.
4. Click text in the first window. The point moves there, and
   the other window keeps its place.
5. Escape quits. Nothing is saved. In the shell, mouse selection
   works again.

The spec repeats this check. A failure of the check sends the
work back. It does not add a feature.

### 4.9 One checkpoint

| Checkpoint | What it proves |
|---|---|
| **aloemacs-mouse 000** | `read-event` yields a key or a button string, `read-key` skips the button string, the TTY entry enables button-only reporting, and a left press in a window's text selects that window and places its point. Chrome, release, the other buttons, and an active prompt, search, or prefix leave the session as it was |

000 is the whole series. The host event and the click are one
change. A button string that nothing places is not a checkpoint.
The manager writes 000 only, then stops. If 000 would not fit
one implementer conversation, the manager sends the spec back.
The spec does not plan a second number.

## 5. Authority

- [`../README.md`](../README.md) — the parent map. Mouse is its
  own row. Paste, the host clipboard, PTY, and daemon stay
  outside this series. This series does not edit the map
- [`../term/spec.md`](../term/spec.md) — the first five Term
  methods, the frame string, the size queries, and the rule that
  `read-key` ignores mouse and resize. §4.1–§4.3 of this charter
  add `read-event` and the skip. Do not amend that spec
- [`SPEC.md`](../../../../../SPEC.md) §14 — the crossing
  vocabulary. This series does not amend `SPEC.md`
- [`../window-point/spec.md`](../window-point/spec.md) — the
  per-view point, the store-then-enter handoff, and the fit
  after entry. §4.5 uses that handoff. Do not amend that spec
- [`../windows/spec.md`](../windows/spec.md) — the tree, the
  commands, and echo policy. Live rectangles, the mode line, and
  completion rows are whatever the current program does
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `AloemacsWindowRect`, `root-rect`, `completion-row-count`,
  `enter-view`, `other-window`, `handle-key`, and `echo-row`
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `at-focused`, the cursor address, and `handle-key`
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — the production reader and `tkeymsg->aloe-key`
- [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt)
  — the loop this series switches to `read-event`
- `tui-term` as installed with this Racket: `term-enable-mouse`
  writes `1003` and `1006`; the SGR decoder subtracts one from
  the 1-based position; kind is `button-down`, `button-up`, or
  `move`; wheel kinds are `wheel-up` and `wheel-down`. This
  series reads that package and does not modify it
- [`docs/gel.md`](../../../../gel.md) §6 and
  [`docs/decisions.md`](../../../../decisions.md) — the factual
  Term catalog. §4.7 says what this series adds there

`SPEC.md` remains language law. The accepted Term spec remains
the authority for the first five methods. The accepted
window-point spec remains the authority for the per-view cursor.
This charter is the authority for the button string and the
click. After the human accepts `spec.md`, that file is the
design authority for the checkpoint manager and the implementer.

## 6. Non-goals

- Motion, hover, and any-event tracking (`1003`)
- Wheel scrolling
- A modifier field, or a modified click placing the point
- Drag, a selection region, or pairing a press with a later release
- Click to split, delete, or lock; a menu; a command on the mode line
- Placing the point during a prompt, a search, or a pending prefix
- The directory browser, describe, jump to definition, faces,
  highlighting, a language server, modules, and worksheet evaluation
- Clipboard, paste, PTY, daemon, and a VT emulator
- A second host capability, a new crossing type, or a mouse value
  other than the string in §4.2
- A change to `tui-term`, to Gel's sends, or to
  `call-with-tty-term-receiver`
- A change to frame composition, picture reuse, mode-line paint,
  bar color, or idle-echo paint
- A new keymap binding or command constructor
- Rewriting the accepted Term spec, or editing the parent map
- A kernel message, a `SPEC.md` row, or a global checkpoint number

## 7. Handoff

- Series identity: `aloemacs-mouse`.
- Checkpoint 000 is spoken **aloemacs-mouse 000** and filed as
  `checkpoints/000-click.md`. Numbers are three digits, start at
  000, and are never renumbered. The slug is lowercase words
  separated by hyphens. The checkpoint manager writes one
  checkpoint, then stops.
- Intended order: the host read, then the click that proves it,
  as one checkpoint (§4.9). 000 is the whole series. The spec
  does not plan a second number. If 000 would not fit one
  implementer conversation, the manager sends the spec back.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `host/racket/term.rkt`,
  `host/racket/aloemacs-run.rkt`, and `examples/aloemacs/`.
  New tests stay in `tests/aloemacs/`. The catalog updates in
  §4.8 are part of the same change. The spec names the focused
  test file and the standing command
  `TMPDIR=/tmp raco test -j 4 -y`. The design folder receives
  `spec.md` and later the one checkpoint, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
