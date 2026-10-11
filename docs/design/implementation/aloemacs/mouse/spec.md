# aloemacs mouse specification

**Status: Accepted.** The human accepted this specification for
aloemacs-mouse 000. Written by the designer from
[`charter.md`](charter.md). Not Aloe law. Not a checkpoint.
Not an implementer assignment.

This file is the complete design input for the checkpoint manager
and the implementer. They do not need the charter or the design
conversation. [`SPEC.md`](../../../../../SPEC.md) remains Aloe
language law. [`docs/workflow.md`](../../../../workflow.md) governs
roles and review. The accepted Term specification remains the
authority for the first five Term methods. The accepted
window-point specification remains the authority for the per-view
cursor. This file is the authority for `read-event`, the mouse
string, and the click.

## 1. Opening

A button press and a button release reach Aloe on the same read
the editor already blocks on. A key still arrives as the string
it arrives as today. A left press in a window's text selects that
window and places its point. The release reaches Aloe and leaves
the point where it is.

The charter left these names to this spec. They are decided:

| What | Decision | Section |
|---|---|---|
| The send that installs the point | `AloemacsEditor.place(line, column)`. It sets `point` and leaves the Text focus on that line. The characters stay | §5.5 |
| The session send | `place-at(line, column)`: `with-editor` of that `place`, then `with-echo ""` | §5.5 |
| Which leaf holds the cell | `AloemacsWindowRect.contains?`, then `AloemacsWindowTree.view-at` | §5.4 |
| The string the session reads | `AloemacsMouse`, defined in `file.aloe` before `AloemacsSession` | §5.2 |
| The host formatter | `tmousemsg->aloe-mouse`, beside `tkeymsg->aloe-key`. A string or `#f` | §5.2 |
| The later screen | 40 columns by 10 rows, from the live rectangle methods | §5.4 |
| The focused test | `tests/aloemacs/mouse.rkt` | §6 |

There were no open product questions in the charter. The locked
decisions are restated below and stay closed.

## 2. Checkpoint series

Series identity is **aloemacs-mouse**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Checkpoint
numbers are three digits, start at 000, and are never renumbered.
The slug is lowercase words separated by hyphens.

There is one checkpoint:

| Identity | File | What it proves |
|---|---|---|
| **aloemacs-mouse 000** | `checkpoints/000-click.md` | `read-event` yields a key or a button string, `read-key` skips the button string, the TTY entry enables button-only reporting, and a left press in a window's text selects that window and places its point. Chrome, release, the other buttons, and an active prompt, search, or prefix leave the session as it was |

000 is the whole series. The host read and the click are one
change. A button string that nothing places is not a checkpoint.
The manager writes 000, then stops. The manager does not issue
001 and does not split this layer. If 000 would not fit one
implementer conversation, the manager sends this spec back.

Do not take a global checkpoint number. Do not add a
`CHECKPOINTS.md` entry. Do not edit the parent map
[`../README.md`](../README.md), [`../explorations.md`](../explorations.md),
or [`../discussion.md`](../discussion.md).

### 2.1 Predecessors

This series reads the accepted specs and the current program. It
does not edit those specs, those charters, or those checkpoints.
A defect there that blocks a click stops the implementer; the
fix belongs to that series.

| What | The state this series starts from |
|---|---|
| [`../term/`](../term/) | aloemacs-term 000 is accepted. Term is one injected capability. The ordered methods are `read-key`, `write-line`, `write`, `columns`, `rows`. `read-key` returns a `String`. The frame is one `String` passed to `write`. `call-with-tty-term-receiver` owns the `tui-term` lifetime. Gel sends only `read-key` and `write-line` |
| [`../window-point/`](../window-point/) | Each view stores its own point and origin. The selected view's point equals the editor point. `other-window` stores the departing view through `AloemacsWindows.with-buffer`, then `enter-view` installs the entered view's point and origin. The following fit is the runner's `ensure-visible` |
| [`../windows/`](../windows/) | A window is a view of a buffer. The tree is `Leaf`, `Below`, and `Right`. Rectangles are 0-based `(x, y, columns, rows)`. A Right split reserves one column between the leaves |
| [`../mode-line/`](../mode-line/) and [`../window-bars/`](../window-bars/) | A leaf at least two rows tall paints its bar on its last row. A shorter leaf is all text. The bar's text is the buffer name |
| [`../idle-echo/`](../idle-echo/) | The echo row is blank while idle when the selected leaf is at least two rows tall. This series does not reopen that rule |
| [`../completion/`](../completion/) and [`../completion-page/`](../completion-page/) | Completion rows can occupy the screen above the echo while a prompt is active. `root-rect` shrinks by `completion-row-count` |
| [`../keymap/`](../keymap/) | `handle-key` is the session's key path: quit, then search, then prompt, then the keymap. A pending prefix is `pending` |
| The runner | [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt) reads columns and rows, fits, records pictures, writes the frame, then blocks on `(term read-key)` and sends that string to `handle-key` |

## 3. Product boundary

The program, after this series:

- `(term read-event)` returns the next key string or the next mouse string.
- `(term read-key)` still returns the next key string, and skips a mouse string to do it.
- The Aloemacs TTY entry asks the terminal for button presses and releases, and turns that request off before it leaves.
- A left press in a window's text selects that window and places its point on the clicked cell, clamped to the text.
- A left release, a middle button, a right button, and a left press on chrome leave the session as it was.
- A mouse string during a prompt, a search, or a pending prefix leaves that activity as it was.

Out of scope, for the implementer as well as the manager:

- Motion, hover, and any-event tracking (mode `1003`)
- Wheel scrolling
- A modifier field, or a modified click placing the point
- Drag, a selection region, or pairing a press with a later release
- Click to split, delete, or lock; a menu; a command on the mode line
- Placing the point during a prompt, a search, or a pending prefix
- The directory browser, describe, jump to definition, faces, highlighting, a language server, modules, and worksheet evaluation
- Clipboard, paste, PTY, daemon, and a VT emulator
- A second host capability, a new crossing type, or a mouse value other than the string in §5.2
- A change to `tui-term`, to Gel's sends, or to the body of `call-with-tty-term-receiver`
- A change to frame composition, picture reuse, mode-line paint, bar color, or idle-echo paint
- A new keymap binding or command constructor
- Rewriting the accepted Term spec, or editing the parent map
- A kernel message, a `SPEC.md` row, or a global checkpoint number

## 4. Host and layout

Language is Aloe for the editor and Racket for the host. The
project root is `/home/dharmatech/journal/2026-09-02-aloe-racket`.
The design folder receives this spec and later the one checkpoint.
The program stays in the tree below.

| May edit | What changes |
|---|---|
| `host/racket/term.rkt` | Sixth method, shared reader, formatter, `read-key` skip |
| `host/racket/aloemacs-run.rkt` | The loop blocks on `read-event`. `run-aloemacs` enables button tracking |
| `examples/aloemacs/editor.aloe` | `AloemacsEditor.place` |
| `examples/aloemacs/file.aloe` | `contains?`, `view-at`, `AloemacsMouse`, `handle-event`, `place-at` |
| `tests/aloemacs/mouse.rkt` | New focused proof |
| `tests/checkpoint-53.rkt`, `tests/checkpoint-84.rkt`, `tests/checkpoint-87.rkt` | Sixth catalog row |
| `tests/aloemacs/term-capability.rkt` | Sixth catalog row |
| `tests/aloemacs/viewport-runner.rkt` | Source-order phrase only |
| `tests/aloemacs/file-runner.rkt` | Source phrase only |
| `docs/gel.md` §6 and `docs/decisions.md` | A factual `read-event` line |

When another file looks necessary, the implementer stops and sends
the checkpoint back.

Leave these alone. They are Gel, `term-run`, a local two-method
fixture, or they already call `read-key` or `handle-key` as the
key path:

- `host/racket/gel-run.rkt` and `host/racket/term-run.rkt`
- `tests/checkpoint-83.rkt`, `tests/checkpoint-85.rkt`, `tests/checkpoint-86.rkt`
- Session tests that send `handle-key` a key string
- `tui-term`, the accepted Term spec, and the parent aloemacs map

From the project root, tests are:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

`<paths>` is the focused file, then the wider suite in §6.
`compiled/` stays gitignored. `./bin/aloe` and
`racket host/racket/aloemacs-run.rkt` load bytecode and do not
rebuild it. After a `.rkt` edit, the test command rebuilds what
it runs. `.aloe` edits need no separate rebuild for a test that
loads them. Launching the TTY entry by hand, after a `.rkt` edit,
needs `raco make host/racket/aloemacs-run.rkt` first. The hand
check is the human's, after the tests are green.

The editor loads through `examples/aloemacs/main.aloe`, which
loads `file.aloe`, which loads `editor.aloe`. New classes keep
the `Aloemacs` prefix. `Int.min` is already available where
`editor.aloe` uses it. `Text.focus-at`, `Text.line-length`,
`Text.indexed-value`, and `Text.focus-line` are already loaded
with the editor. String `starts-with?` is the library method.
This series adds no kernel message and no `lib/` method.

## 5. The layer

### 5.1 One more method on Term

Term stays one injected capability. Append one method. The
ordered interface becomes:

| Order | Send | Type | Result |
|---:|---|---|---|
| 1 | `(term read-key)` | `() -> String` | The next key string. A mouse string is skipped. |
| 2 | `(term write-line s)` | `(String) -> String` | Unchanged. |
| 3 | `(term write s)` | `(String) -> String` | Unchanged. |
| 4 | `(term columns)` | `() -> Int` | Unchanged. |
| 5 | `(term rows)` | `() -> Int` | Unchanged. |
| 6 | `(term read-event)` | `() -> String` | The next key string or the next mouse string. |

`make-term-receiver` keeps its arguments: output port, reader
thunk, size reader. The thunk still returns one `String`.
`read-event` returns that string. `read-key` calls the thunk
again while the string is a mouse event, and returns the first
string that is not.

The production thunk is `read-next-key`, still the shared reader
inside `call-with-tty-term-receiver`. It maps a `tkeymsg` through
`tkeymsg->aloe-key`. It maps a button `tmousemsg` through
`tmousemsg->aloe-mouse` and returns that string when the formatter
returns one. It skips resize, and it skips a `tmousemsg` for which
the formatter returns `#f`, and it skips any other value, by
reading again. End of input is still the existing error,
`terminal input closed while reading a key`, raised from that
shared reader, so both methods raise it. The focused tests do
not open a TTY to prove that error.

The Aloemacs loop in `run-aloemacs-with-hosts` blocks here:

```aloe
(define aloemacs-editor
  (aloemacs-editor handle-event (term read-event)))
```

The order around that send stays: columns, rows, `ensure-visible`,
`record-pictures`, `frame`, `write`, then this send. The loop
does not also call `read-key`. `handle-event` is a session
method. `AloemacsEditor.handle-key` stays the editor's key method.
The session's `handle-key` stays the key path that `handle-event`
sends to.

`host/racket/gel-run.rkt` and `host/racket/term-run.rkt` are not
edited. Gel still sends only `read-key` and `write-line`. Gel's
runner does not turn mouse reporting on. Neither runner contains
`read-event`, `1000`, or `term-enable-mouse`. The focused proof
does not assert that either file contains `(term read-key)`.
`gel-run.rkt` does not contain that phrase. `term-run.rkt`
contains it only in a comment. The checks in
`tests/checkpoint-86.rkt` stay as they are.

### 5.2 The mouse string

A mouse event is this entire string, fields separated by one
space, with no extra spaces:

```text
mouse <down|up> <left|middle|right> <column> <row>
```

`down` is a press and `up` is a release. The button is `left`,
`middle`, or `right`. `column` and `row` are canonical decimals:
`0`, or a non-zero digit followed by digits. No sign and no
leading zero. The match is the whole string.

Accepted: `mouse down left 4 2`, `mouse up middle 0 0`,
`mouse down right 10 12`.

Rejected, and therefore keys: `mouse down left 04 2`,
`mouse down left 4 2 `, `mouse down left -1 2`, `mouse`,
`Mouse down left 4 2`.

`read-key` treats a string as a mouse event only when the whole
string matches this grammar. Any other string is a key, including
a string the host would never produce. The same grammar is what
`AloemacsMouse.event?` accepts. Both sides accept exactly that
set. The session parses with the String and Int messages that
already exist: `starts-with?`, `take`, `drop`, `len`, `=`, `find`,
and `min`. It does not add a kernel message.

`AloemacsMouse` has one field, `event`, a `String`. These results
are defined when `event?` is true:

| Send | Result |
|---|---|
| `(mouse event?)` | The whole string matches the grammar |
| `(mouse down?)` | The action field is `down` |
| `(mouse left?)` | The button field is `left` |
| `(mouse column)` | The column decimal, as an `Int` |
| `(mouse row)` | The row decimal, as an `Int` |

So `(AloemacsMouse new "mouse down left 4 2")` is an event, a
press, and a left button, at column 4 and row 2.
`(AloemacsMouse new "mouse up middle 0 0")` is an event at column
0 and row 0, and both `down?` and `left?` are false.
`handle-event` does not send `column` or `row` unless `event?`
is true.

The host builds that string in `tmousemsg->aloe-mouse`. Export it
next to `tkeymsg->aloe-key`. It returns the mouse string, or `#f`
when the value is not one this series reports. A string requires
all of these:

- the value is a `tmousemsg`
- `tmousemsg-kind` is `button-down` or `button-up`
- `tmousemsg-button` is `left`, `middle`, or `right`
- `tmousemsg-pos` is a `tpoint`
- `tpoint-x` and `tpoint-y` are exact integers, both `>= 0`

`tui/term` exports the `tmousemsg` accessors and
`make-tmousemsg-leave`. Its provide list does not include
`tpoint`, `tpoint-x`, `tpoint-y`, or `make-tmousemsg`.
`tpoint` and its accessors come from `tui/term/geometry`.
`make-tmousemsg` comes from `tui/term/messages`. Those are the
modules tui-term's Scribble docs declare. `host/racket/term.rkt`
requires `tui/term/geometry` for `tpoint-x` and `tpoint-y`.
`tests/aloemacs/mouse.rkt` requires `tui/term/geometry` for
`tpoint` and `tui/term/messages` for `make-tmousemsg`. Requiring
those modules does not change tui-term.

`tpoint-x` is the column and `tpoint-y` is the row. Format with
`down` for `button-down` and `up` for `button-up`, then the button
symbol's name, then the two numbers in canonical decimal. The
three boolean flags on the struct do not change the string.
`(make-tmousemsg 'button-down (tpoint 4 2) #t #f #f 'left)`
formats as `mouse down left 4 2`. The same call with
`button-up` formats as `mouse up left 4 2`.
`(make-tmousemsg 'button-up (tpoint 0 0) #f #f #t 'middle)`
formats as `mouse up middle 0 0`.

These values return `#f`, and the production reader skips them
the way it skips resize:

- kind `move`
- kind `wheel-up` or `wheel-down`
- a button other than `left`, `middle`, or `right`, including `#f`
- a negative component, or a component that is not an exact integer

Those coordinates are already 0-based. SGR `\e[<0;2;3M` is
1-based column 2, row 3, and `tui-term` stores `(tpoint 1 2)`.
The formatter does not subtract again. A constructed
`(tpoint 1 2)` formats as column 1 and row 2.

A modified click arrives from `tui-term` with button `#f`, because
the decoder does not strip shift, meta, or control. It is skipped
with the other unknown buttons. This series does not change
`tui-term` and does not add a modifier field.

### 5.3 Button-only reporting

`term-enable-mouse` sends any-event tracking, mode `1003`, plus
SGR `1006`. This series does not call it.

`run-aloemacs`, the TTY entry, writes these bytes to the current
output port after `with-term` has that port, and before the editor
loop:

```text
ESC [ ? 1 0 0 0 h ESC [ ? 1 0 0 6 h
```

Before that procedure returns, and before an exception leaves it,
while the port still accepts output, it writes:

```text
ESC [ ? 1 0 0 0 l ESC [ ? 1 0 0 6 l
```

Flush after each write. The enable and the disable are the before
and after thunks of a `dynamic-wind` around the call to
`run-aloemacs-with-term`, inside the procedure
`call-with-tty-term-receiver` runs. The after thunk does not catch
the editor's exception. `with-term` then disables `1003` and
`1006` itself. The runner's own `1000` disable is what turns
button tracking off for the shell. The bytes are terminal setup.
They are not part of the frame string and they are not an Aloe
send.

`run-aloemacs-with-hosts` and `run-aloemacs-with-term` do not
write those bytes. `call-with-tty-term-receiver` does not write
them. A scripted frame stays free of them. `term.rkt` does not
contain `1000`, `1003`, or `term-enable-mouse`.

### 5.4 Where a cell lands

The click uses the geometry the last fit stored:
`windows.columns`, `windows.rows`, `(self root-rect columns rows)`,
`(self completion-row-count rows)`, and the leaf rectangles from
the tree. It does not send `(term columns)` or `(term rows)`.
Coordinates are the 0-based column and row from §5.2.

`AloemacsWindowRect.contains?(column, row)` is true when
`x <= column < x + columns` and `y <= row < y + rows`.

`AloemacsWindowTree.view-at(column, row, rect)` walks the same
children `rect-for` walks: a `Below` uses `rect.top` and
`rect.bottom`, a `Right` uses `rect.left` and `rect.right`. A
leaf returns that view when the rect contains the cell, and
`None` otherwise. The right-split bar falls in neither child, so
`view-at` returns `None` there.

Classify in this order. The first match wins. `rows` here is
`windows.rows`, the stored terminal height.

| Order | Region | Cell | Result |
|---:|---|---|---|
| 1 | Echo | `rows >= 2` and `row = rows - 1` | No placement |
| 2 | Completion | `row` is in `[root.rows, root.rows + completion-row-count)` | No placement |
| 3 | Mode line | `view-at` finds a leaf whose `rows >= 2`, on that leaf's last row `y + rows - 1` | No placement |
| 4 | Text | `view-at` finds a leaf, and the cell is not its mode line | §5.5 |
| 5 | Elsewhere | `view-at` returns `None`: a vertical bar, a gap, or a cell outside every leaf | No placement |

A leaf shorter than two rows is all text. A terminal shorter than
two rows has no echo row, and its completion count is 0. Leaf
rectangles do not overlap.

On an 80 by 24 screen with no completion rows, the root is
`(0, 0, 80, 23)` and the echo row is 23. One tall leaf uses rows
0 through 21 as text and row 22 as the mode line. A Below split
gives `(0, 0, 80, 12)` and `(0, 12, 80, 11)`: mode lines on rows
11 and 22, text on 0 through 10 and 12 through 21. A Right split
of that root puts the bar on column 40; the left leaf is columns
0 through 39 and the right leaf starts at column 41. These are
the current `top`, `bottom`, `left`, and `right` methods. The
windows specification's old divider arithmetic is not this
geometry.

The later screen is 40 by 10, still with no completion rows. The
root is `(0, 0, 40, 9)` and the echo row is 9. One tall leaf uses
rows 0 through 7 as text and row 8 as the mode line. A Below
split gives `(0, 0, 40, 5)` and `(0, 5, 40, 4)`: mode lines on
rows 4 and 8, text on 0 through 3 and 5 through 7. A Right split
of that root puts the bar on column 20; the right leaf starts at
column 21.

With two completion lines on an 80 by 24 screen, `root-rect`
is `(0, 0, 80, 21)`. The completion rows are 21 and 22. The echo
row is 23. One tall leaf's mode line is row 20.

Completion rows exist while a prompt is active. §5.6 refuses
every mouse event during a prompt, so a completion press and a
text press during a prompt have the same observable result. The
region table is still the definition of a text cell. The
completion proof clicks the first completion row.

### 5.5 The left press

Placement runs only for a string with `event?`, `down?`, and
`left?`, in a text cell, and only when §5.6 allows it.

The cell's line and column, before clamping, use the leaf from
`view-at` and that leaf's rectangle from `rect-for` on the same
root:

```text
line   = view.scroll-row + (row - rect.y)
column = view.scroll-col + (column - rect.x)
```

For a cell inside the leaf and a stored origin `>= 0`, both
results are `>= 0`.

`AloemacsEditor.place(line, column)` installs that point. `line`
and `column` are `>= 0`. The send is:

```aloe
(place (line Int) (column Int) AloemacsEditor
  (((self text) focus-at line) case
    (Some (focused) (self at-focused focused column))
    (None () (self buffer-end))))
```

A column past that line's length becomes that length, the
position after the last character. A line `focus-at` finds uses
the editor's existing `at-focused`, which clamps `column` with
`line-length` and stores that focused Text. A line for which
`focus-at` returns `None` uses the editor's existing
`buffer-end`: the last line, at that line's length, with the
focus on that line. When the receiver's point is already the
clamped point, `at-focused` returns the receiver unchanged, and
the focus stays where the last motion, edit, entry, or place
left it.

The characters stay. `(text to-string)` is the receiver's
string. A place that moves the point leaves `(text focus-line)`
on the placed line, so the next key's `focus-at` of that line
walks nothing. `place` does not change the mark, the history,
`quit`, `text-rows`, `scroll-row`, or `scroll-col`, and it does
not push an undo frame.

`AloemacsSession.place-at(line, column)` writes that editor onto
the selected view through the existing `with-editor` path, so
the selected view's stored point equals the editor point, and
then clears the echo token:

```aloe
(place-at (line Int) (column Int) (AloemacsSession H)
  ((self with-editor ((self editor) place line column)) with-echo ""))
```

`with-editor` already sends `AloemacsWindows.with-buffer`, which
copies the editor point and origin onto the selected view only.
`place-at` does not change the origin. The runner's next
`ensure-visible` is the fit, as it is after a motion key.
`place-at` does not send `ensure-visible`. The echo clear happens
even when the point was already on that cell. The clear is
`with-echo ""`, the same token a motion command writes.

The selected leaf is already selected. `place-at` is the whole
update.

Another leaf uses the `other-window` handoff and no other
selection rule. Store the departing view's live point and origin
first, then `enter-view` of the clicked leaf, then `place-at`:

```aloe
(let ((stored ((self windows) with-buffer (self current-buffer))))
  (((stored tree) find-view (view id)) case
    (None () self)
    (Some (stored-view)
      ((self enter-view (stored tree) stored-view) place-at line column))))
```

`view` is the leaf `view-at` found. The store rewrites the
departing view and leaves the clicked view's stored point and
origin as they were. `enter-view` installs that stored point and
origin, then `place-at` replaces the point with the click and
clears the echo token. The departed view keeps the point the
store wrote. The entered view's origin is the origin
`enter-view` installed, until a later fit. A locked leaf can be
selected; `enter-view` has no lock check, and this path adds
none. Views that were neither the departure nor the arrival keep
their points and origins.

`enter-view` on another buffer clears a non-prompt echo before
`place-at` clears it again. `enter-view` on the same buffer keeps
the echo, and `place-at` then clears it. Placement does not run
while a prompt, a search, or a prefix is active, so this path
does not meet `enter-view`'s search-match branch.

### 5.6 Events that leave the session as it was

`handle-event(event)` is the session method the runner sends.
Quit wins before the string is examined:

```aloe
(handle-event (event String) (AloemacsSession H)
  (cond
    ((self quit) (self unchanged))
    (((AloemacsMouse new event) event?) (self handle-mouse event))
    (else (self handle-key event))))
```

`handle-mouse` returns the receiver unchanged when `searching` is
true, when the prompt is present, or when `pending` is present.
Otherwise it classifies the cell. A left press in a text cell
takes §5.5. Every other mouse string returns the receiver
unchanged.

Unchanged covers the point, the selection, every view's stored
point and origin, the echo token, the text, the mark, the kill
ring, and the undo history. The three activities stay as they
were. The event does not end the search, submit or cancel the
prompt, clear the prefix, or insert the string. A mouse string
never reaches the keymap.

That unchanged list includes:

- `mouse up left`, in any region
- `mouse down middle`, `mouse up middle`, `mouse down right`, and `mouse up right`, in any region
- a left press on the echo row, a completion row, a mode line, a vertical bar, or any other non-text cell
- any mouse string while `searching` is true, while the prompt is present, or while `pending` is present

A key string still takes the existing `handle-key` path,
including quit, search, prompt, prefix, and self-insert. A
rejected near-miss such as `mouse down left 04 2` is a key.

### 5.7 What this series leaves in place

The frame's bytes stay the frame's bytes. A click that moves the
point changes the cursor address the next frame already computes.
The picture reuse key does not gain the point. `record-pictures`
stays. Mode-line paint, bar color, and idle-echo paint stay.
Direct editor `frame` stays the one-view frame.

The keymap tables gain no binding. The click is not a command
constructor.

The accepted Term spec stays the authority for the first five
methods and for the observable rule that `read-key` ignores mouse
and resize. This spec is the authority for `read-event`, for the
mouse string, and for `read-key` skipping that string. Do not
rewrite [`../term/spec.md`](../term/spec.md),
[`../term/charter.md`](../term/charter.md), or the Term
checkpoints.

`docs/gel.md` section 6 and the host-terminal paragraph in
`docs/decisions.md` gain a factual catalog line:
`(term read-event) : () -> String` is the sixth method, and it
returns the next key string or the next mouse string. Both
documents still say Gel sends only `read-key` and `write-line`,
and that `read-key` ignores mouse. Gel's "no mouse" scope stays
true for Gel. Section 7 of `docs/gel.md` stays as it is.

## 6. Verification

### 6.1 Focused file

`tests/aloemacs/mouse.rkt` uses a checked driver and
`make-term-receiver`. It does not call `with-term`,
`call-with-tty-term-receiver`, or `run-aloemacs`. A mouse string
is injected by returning it from the reader thunk. The formatter
proof constructs a `tmousemsg` in Racket and does not open a
terminal.

The buffer text for the placement proofs is `"hello\nworld\nxyz"`:
line 0 `"hello"` length 5, line 1 `"world"` length 5, line 2
`"xyz"` length 3.

The focused proof shows all of these:

- Through a checked driver, `read-event` returns a scripted `mouse down left 4 2`. A second read on that receiver returns the following thunk string. `read-key` on a receiver whose thunk yields that mouse string and then `"x"` returns `"x"`. A thunk that yields two mouse strings and then `"x"` still returns `"x"`. A thunk that yields `mouse down left 04 2` returns that string from `read-key`, because the leading zero is not the grammar.
- The production selector order is `(read-key write-line write columns rows read-event)`, and the return types are `(String String String Int Int String)`.
- `(tmousemsg->aloe-mouse (make-tmousemsg 'button-down (tpoint 4 2) #t #f #f 'left))` is `mouse down left 4 2`. The same position with `button-up` is `mouse up left 4 2`. `(tpoint 0 0)` with `button-up` and button `middle` is `mouse up middle 0 0`. `(tpoint 1 2)` with a left press is `mouse down left 1 2`. Motion, `wheel-up`, button `#f`, and a negative component each return `#f`.
- `run-aloemacs`'s source contains the `1000` and `1006` enable sequences and the `1000` and `1006` disable sequences, and contains neither `1003` nor `term-enable-mouse`. `term.rkt` contains neither `1000`, `1003`, nor `term-enable-mouse`. `gel-run.rkt` and `term-run.rkt` contain neither `read-event`, `1000`, nor `term-enable-mouse`.
- Through the runner, the size source reports 80 by 24 and the visited file is `hello\nworld\nxyz`. The script sends `ctrl-x`, then `2`, then `mouse down left 1 14`. The lower window is selected and its point is `(2, 1)`. The selected editor text's `focus-line` is 2. The upper window keeps `(0, 0)`. The scripted frames gain no enable bytes.
- On a session fitted at 80 by 24, one window, `with-echo "saved"`, then `handle-event` of `mouse down left 4 0`, places the point at `(0, 4)` and clears the echo token. The proof does not send `ensure-visible` after the press. The origin after the press equals the origin after the fit that preceded it. A second session does `split-below` after that fit, leaves the new view unselected, and sends the same press: the selected point becomes `(0, 4)` and the unselected view keeps the point it stored at the split.
- A left press `mouse down left 9 1` clamps to `(1, 5)`, and the editor text's `focus-line` is 1. A left press `mouse down left 0 5` places the point at `(2, 3)`, the end of the last line, and `focus-line` is 2.
- The origin proof constructs the session with `windows` already 80 by 24, one view, editor and view `scroll-row` 10 and `scroll-col` 3, and text `"hi"`. It sends `handle-event` of `mouse down left 0 5` and does not send `ensure-visible`. The point becomes `(0, 2)`. `scroll-row` stays 10 and `scroll-col` stays 3.
- On the 40 by 10 screen, after `ensure-visible` of 40 and 10 and `split-below`, a left press `mouse down left 1 6` selects the lower window and places its point at `(1, 1)`. The upper window keeps its point.
- A left release `mouse up left 4 0`, a middle press `mouse down middle 4 0`, and a right press `mouse down right 4 0` leave the point, the selection, and the echo token unchanged.
- A left press `mouse down left 0 22` on the mode line, `mouse down left 0 23` on the echo row, and `mouse down left 40 0` on the vertical bar of a Right split leave the point, the selection, and the echo token unchanged.
- A terminal fitted at 80 by 1 has no echo row and no mode line. `handle-event` of `mouse down left 2 0` places the point at `(0, 2)`.
- A locked lower window can be selected. On an 80 by 24 session, `split-below`, select the lower window, toggle its lock, and return to the upper window. `handle-event` of `mouse down left 1 14` selects the lower window and places its point at `(2, 1)`. The lock flag stays true.
- During a find-file prompt whose tab has produced at least one completion line, on a session fitted at 80 by 24, a left press on row `(root rows)` of `root-rect` at 80 by 24 leaves the prompt present and leaves the point and the prompt text unchanged. The directory lists at least two regular files, so the completion list is non-empty. During search, after `handle-key "find"`, a left press `mouse down left 0 0` leaves `searching` true, leaves the query, and leaves the point. During a pending prefix, after `handle-key "ctrl-x"`, the same press leaves `pending` present and leaves the point.
- The mouse string is not inserted. `(text to-string)` is unchanged by a press that places the point. The mark set by `set-mark` before that press is still that mark. The history length is unchanged. After that press, `handle-event` of `"x"` inserts, `handle-event` of `"left"` moves, and `handle-event` of `"escape"` sets quit. A quit session then ignores `mouse down left 4 0`: quit stays true and the point stays. `handle-event` of `mouse down left 04 2` does not place the point.

### 6.2 Catalog and runners

These production-catalog assertions gain `read-event` as the
sixth row. Their assertions about the first five rows keep their
meaning. Where a count is `5`, it becomes `6`. The reflected
message count, the signature count, and the expected rows in
`tests/checkpoint-87.rkt` follow that row.

- `tests/checkpoint-53.rkt`
- `tests/checkpoint-84.rkt`
- `tests/checkpoint-87.rkt`
- `tests/aloemacs/term-capability.rkt`

`tests/aloemacs/viewport-runner.rkt` moves its source-order phrase
from `(term read-key)` to `(term read-event)`, in the same
position after the frame. One occurrence. The order check stays.

`tests/aloemacs/file-runner.rkt` moves its source phrase from
`aloemacs-editor handle-key` to `aloemacs-editor handle-event`.
The existing scripted `"x"`, `"save"`, `"escape"` proof still
shows that a key is handled. It gains no frame.

Existing scripted runners stay green without new frames. Their
thunks return key strings, and `read-event` returns those
strings. One loop iteration still consumes one thunk result when
that result is a key.

### 6.3 Commands

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/mouse.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/checkpoint-53.rkt tests/checkpoint-84.rkt tests/checkpoint-87.rkt
```

The first command is the focused proof. The second is the wider
suite: every aloemacs test, including the scripted runners, and
the three catalog files. Both are green before the checkpoint is
done.

### 6.4 Hand check

The implementer does not need a TTY to finish. The human runs
this after the tests are green. From the project root, on a
terminal at least 80 by 24:

1. `racket host/racket/aloemacs-run.rkt` on a scratch file. `C-x 2`. Click text in the other window. That window is selected and the point is on the clicked character. The first window still shows the place it had.
2. Click that window's mode line. The point stays.
3. Click the echo row. The point stays.
4. Click text in the first window. The point moves there, and the other window keeps its place.
5. Escape quits. Nothing is saved. In the shell, mouse selection works again.

A failure of the check sends the work back. It does not add a
feature.

## 7. Acceptance

The specification meets the bar when all of these are true:

1. A press and a release reach Aloe. Left, middle, and right, each as a press and as a release, cross as one `String` on `(term read-event)`. A key the editor already understands still crosses as the same `String` `(term read-key)` returns today. The frame stays one `String`. The crossing vocabulary stays `Int`, `Bool`, `String`, and `(List String)`.
2. `read-key` still ignores mouse. A mouse string followed by a key makes `(term read-key)` return the key. Gel still sends only `read-key` and `write-line`. Gel's runner does not turn mouse reporting on. `call-with-tty-term-receiver` stays free of mouse reporting.
3. The editor asks for buttons, and only buttons. The Aloemacs TTY entry enables mode `1000` and SGR `1006`, and disables both before the terminal is torn down, including when the loop fails. It does not enable mode `1003`. A scripted run writes no enable bytes.
4. A left press in text places the point. In the selected window, the point moves to that cell, clamped to the text. The characters stay, and the Text focus is on the placed line. In another window, that window becomes selected and its point moves to that cell. The window left behind keeps the point it had. Other views keep the points they stored.
5. Chrome is recognized and does not place the point. A left press on a mode line, the echo row, a completion row, or a vertical bar leaves the point, the selection, and the echo token as they were. A left release, a middle button, and a right button do the same wherever they land.
6. An active prompt, search, or prefix stays active. A mouse string during any of those leaves that activity, the point, and the selection as they were. The string is not inserted.
7. Tests are the proof. The focused tests inject the mouse string through the existing reader thunk. They do not open a TTY. §6.4 is the hand check a person runs after those tests are green.
8. 000 is the whole series. The host read and the click are one checkpoint. This spec does not plan 001.
