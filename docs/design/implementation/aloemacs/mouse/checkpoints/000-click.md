# aloemacs-mouse 000 — Click

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the spec sections named below, implement this slice, and stop
when green.

## Goal

A button press and a button release reach Aloe on the read the editor
already blocks on. A left press in a window's text selects that window
and places its point.

- Term gains a sixth method, `read-event`. It returns the next key
  string or the next mouse string. `read-key` still returns the next
  key string and skips a mouse string to do it.
- The TTY entry asks the terminal for button presses and releases
  only, and turns that off before it leaves.
- The runner blocks on `(term read-event)` and sends the string to the
  session's new `handle-event`.
- A left press in a text cell places the point on that cell, clamped
  to the text. In another window it first selects that window through
  the `other-window` handoff.
- A release, a middle or right button, a press on chrome, and any
  mouse string during a prompt, a search, or a pending prefix leave
  the session as it was.

This checkpoint is the whole series. Stop when the focused proof and
the wider suite pass.

## Authority, identity, and starting point

The implementer receives this checkpoint and the spec. The checkpoint
narrows the spec to the one slice it already is and adds the test
inventory the spec left to the manager. It does not revise the spec.

- Identity: **aloemacs-mouse 000**, filed as
  `checkpoints/000-click.md`. This is a local editor checkpoint. It
  takes no global number and gets no `CHECKPOINTS.md` entry. There is
  no 001.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits. `SPEC.md`
  remains Aloe language law. Evaluation is send with a literal
  selector. Function objects run only through `call`. No mutation,
  macros, inheritance, or new special forms.
- [../spec.md](../spec.md) governs all of this slice:
  - §3: the product boundary and the out-of-scope list.
  - §4: the file table. This checkpoint adds six test files to it;
    see **Exact file scope**.
  - §5.1: the sixth method, the shared reader, the runner send.
  - §5.2: the mouse string, its grammar, `AloemacsMouse`, and the
    formatter `tmousemsg->aloe-mouse`.
  - §5.3: the enable and disable bytes, and where they are written.
  - §5.4: `contains?`, `view-at`, and the region table.
  - §5.5: `place`, `place-at`, and the other-leaf handoff.
  - §5.6: `handle-event`, `handle-mouse`, and the unchanged list.
  - §5.7: what stays in place, and the two doc lines.
  - §6: verification. §6.1 is the focused proof this checkpoint turns
    into an inventory. §6.4 is the human's hand check.
  - §7: the acceptance list.
- The accepted Term spec stays the authority for the first five
  methods. The accepted window-point spec stays the authority for the
  per-view point and the store-then-enter handoff. Do not edit either,
  their charters, or their checkpoints.
- `tui-term` as installed with this Racket is read, not edited.

### Current tree

Start from these places. Line numbers are approximate.

- [host/racket/term.rkt](../../../../../../host/racket/term.rkt):
  requires `tui/term` and `../../aloe/host.rkt`. Provides
  `tkeymsg->aloe-key`, `term-interface`, `make-term-receiver`, and
  `call-with-tty-term-receiver`. `read-next-key` (line 133) is the
  shared production reader: it loops on `(read)`, raises
  `terminal input closed while reading a key` on eof, maps a
  `tkeymsg`, and skips a `tmousemsg`, a `tsizemsg`, and anything
  else. `term-read-key` (line 154) calls the state's reader thunk
  once. `term-interface` (line 192) lists five `make-host-method`
  rows. `make-term-receiver` (line 203) takes output, reader, and
  size reader. `call-with-tty-term-receiver` (line 210) wraps
  `with-term` around `(procedure (make-term-receiver … read-next-key
  current-term-size))`. The file does not contain `1000`, `1003`, or
  `term-enable-mouse`.
- [host/racket/aloemacs-run.rkt](../../../../../../host/racket/aloemacs-run.rkt):
  `run-aloemacs-with-hosts` (line 23) prepares `read-columns`,
  `read-rows`, the viewport triple, `handle-key` as
  `'(define aloemacs-editor (aloemacs-editor handle-key (term read-key)))`
  (line 62), and `quit?`. The loop is columns, rows, fit, record,
  frame, handle-key, quit check. `run-aloemacs` (line 89) is
  `(call-with-tty-term-receiver (lambda (term) …run-aloemacs-with-term…))`.
- [examples/aloemacs/editor.aloe](../../../../../../examples/aloemacs/editor.aloe):
  `at-focused (focused Text) (column Int)` (line 281) clamps the
  column with `line-length`, returns the receiver unchanged when the
  point is already there, otherwise `with-text-and-point`.
  `buffer-end` (line 348) is `(self at-focused last (last line-length))`
  with `last` from `focus-end`. `handle-key` (line 355) is the
  editor's key method and stays.
- [examples/aloemacs/file.aloe](../../../../../../examples/aloemacs/file.aloe):
  - `AloemacsView` (line 307): `id`, `buffer-id`, `scroll-row`,
    `scroll-col`, `point`, `locked`, `picture`.
  - `AloemacsWindowTree` (line 318): `Leaf`, `Below`, `Right`;
    `find-view` (line 337), `next-view`.
  - `AloemacsWindowRect` (line 548): `x`, `y`, `columns`, `rows`;
    `top`, `bottom`, `left`, `right`. A Right split reserves one
    column between `left` and `right`.
  - `define-methods AloemacsWindowTree` (line 599): `rect-for (id rect)`
    (line 617) walks `Below` with `(rect top)` and `(rect bottom)` and
    `Right` with `(rect left)` and `(rect right)`. This block exists
    because these methods need `AloemacsWindowRect`, which is declared
    after the tree class.
  - `AloemacsWindows` (line 742): `tree`, `selected`, `columns`,
    `rows`; `with-buffer (buffer)` (line 797) writes the selected
    leaf's id, buffer id, origin, and point from that buffer's editor.
  - `(AloemacsSession H)` (line 934). `with-editor` (line 1245) writes
    the buffer and sends `with-buffer`. `with-echo` (line 1273).
    `enter-view (tree view)` (line 1300) installs the view's stored
    point and origin and selects it; it has no lock check.
    `other-window` (line 1331) stores the departing view through
    `with-buffer`, then `next-view`, then `enter-view`.
    `completion-row-count (rows)` (line 1680). `root-rect (columns rows)`
    (line 1685). `fit-rect` (line 1689). `ensure-visible` (line 1817).
    `handle-key` (line 1892): quit, searching, prompt, idle.
  - The keymap: `ctrl-x` then `2` is split-below, `3` split-right,
    `o` other-window, `l` toggle-window-lock, `find` find-file. A bare
    `find` starts a search.
- [examples/aloemacs/main.aloe](../../../../../../examples/aloemacs/main.aloe)
  defines `aloemacs-editor`. Tests load it with an injected `fs-host`.
- Catalog tests that spell the five-row descriptor:
  `tests/checkpoint-53.rkt` (line 35), `tests/checkpoint-84.rkt`
  (line 268), `tests/checkpoint-87.rkt` (lines 59–66, with two
  counts of `5`), `tests/aloemacs/term-capability.rkt` (line 47).
- Runner source checks: `tests/aloemacs/viewport-runner.rkt`
  (line 102) requires one occurrence each of seven phrases in source
  order, ending with `(term read-key)`.
  `tests/aloemacs/file-runner.rkt` (line 179) requires
  `aloemacs-editor handle-key` and forbids, among others, the six
  characters `\u001b`, `write-line`, and `"escape"` in the runner
  source. `tests/aloemacs/runner.rkt` (line 265) forbids the same
  strings and requires `driver-prepare!`, `call-with-tty-term-receiver`,
  and `run-aloemacs-with-hosts`.
- Six runner tests hand `run-aloemacs-with-hosts` a Term double of
  their own, built with `make-host-interface`, whose only read method
  is `read-key`: `tests/aloemacs/completion-session.rkt` (line 821),
  `tests/aloemacs/completion-frame.rkt` (line 541),
  `tests/aloemacs/completion-page-frame.rkt` (line 311),
  `tests/aloemacs/prompt-commands-find-file.rkt` (line 604),
  `tests/aloemacs/prompt-commands-save-as.rkt` (line 570), and
  `tests/aloemacs/prompt-commands-select-buffer.rkt` (line 602). The
  first three also record the symbol `'read-key` in an event list.
  Once the runner prepares `(term read-event)`, a double without that
  selector fails the checker. The spec's §4 table does not list these
  files; this checkpoint does.
- Fifteen tests read `file.aloe` and assert the ordered `define-class`
  names. Each expected list ends
  `AloemacsSearchScan (AloemacsSession H)`. The new class sits
  immediately before `(define-class (AloemacsSession H))`, so each of
  those assertions fails until the list gains `AloemacsMouse` in that
  position. The files are named under **Exact file scope**.
- `tui-term`: `tui/term` provides the `tmousemsg` accessors and
  predicate but not `make-tmousemsg`, `tpoint`, or the `tpoint`
  accessors. `tui/term/messages` provides `make-tmousemsg`, with
  fields in the order `kind pos left right middle button`.
  `tui/term/geometry` provides `tpoint`, `tpoint?`, `tpoint-x`,
  `tpoint-y`. `with-term` parameterizes `current-output-port` to the
  terminal and, on exit, calls `term-disable-mouse` (which writes
  `1003l` and `1006l`), shows the cursor, and closes the ports. The
  SGR decoder subtracts one from each coordinate, maps buttons 0, 1,
  2 to `left`, `middle`, `right`, and leaves the button `#f` for a
  modified click.

At issuance, from the project root,
`TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/checkpoint-53.rkt tests/checkpoint-84.rkt tests/checkpoint-87.rkt`
passes 606 tests. The working tree has uncommitted edits in the
parent aloemacs map and this folder; they are documents, not code.

### Size

One conversation. The host side is about forty lines in `term.rkt`
and fifteen in the runner. The Aloe side is one editor method, one
rectangle method, one tree method, one small class, and three or four
session methods. The focused file is new. Twelve existing test files
each take a one- or two-line catalog or runner edit. Fifteen tests
that pin the ordered `define-class` names in `file.aloe` each gain
the token `AloemacsMouse` immediately before `(AloemacsSession H)`.
Two of those fifteen are among the twelve. If you cannot finish in
this conversation, stop and report which files remain. Do not split
the slice or write 001.

## Exact file scope

### May create or edit

- `host/racket/term.rkt`: the sixth method, `term-read-event`, the
  `read-key` skip, `tmousemsg->aloe-mouse` and its export, the
  `tui/term/geometry` require, and the `tmousemsg` arm of
  `read-next-key`. Nothing else.
- `host/racket/aloemacs-run.rkt`: the prepared read-and-handle send
  in `run-aloemacs-with-hosts`, and the `dynamic-wind` in
  `run-aloemacs`. Nothing else.
- `examples/aloemacs/editor.aloe`: add `place` beside `buffer-end`.
  Nothing else.
- `examples/aloemacs/file.aloe`, only in these places:
  1. `AloemacsWindowRect`: `contains?`.
  2. `define-methods AloemacsWindowTree`: `view-at`, beside
     `rect-for`.
  3. A new `define-class AloemacsMouse`, placed after
     `AloemacsWindows` and before `(define-class (AloemacsSession H)`.
     Private helper methods on this class are allowed.
  4. `(AloemacsSession H)`: `handle-event`, `handle-mouse`,
     `place-at`, and any private helpers the cell classification
     needs, on the session only.
- `tests/aloemacs/mouse.rkt`: create it before the product edit and
  watch it fail.
- `tests/checkpoint-53.rkt`, `tests/checkpoint-84.rkt`,
  `tests/checkpoint-87.rkt`, `tests/aloemacs/term-capability.rkt`:
  the sixth catalog row, under **Catalog and runners** below.
- `tests/aloemacs/viewport-runner.rkt`,
  `tests/aloemacs/file-runner.rkt`: the source phrase, under
  **Catalog and runners**.
- `tests/aloemacs/completion-session.rkt`,
  `tests/aloemacs/completion-frame.rkt`,
  `tests/aloemacs/completion-page-frame.rkt`,
  `tests/aloemacs/prompt-commands-find-file.rkt`,
  `tests/aloemacs/prompt-commands-save-as.rkt`,
  `tests/aloemacs/prompt-commands-select-buffer.rkt`: the local Term
  double, under **Catalog and runners**. Spec §4 did not list them.
  They are in scope because they hand the runner a Term double that
  lacks the selector the runner now sends. For
  `completion-frame.rkt`, `completion-page-frame.rkt`,
  `prompt-commands-save-as.rkt`, and
  `prompt-commands-select-buffer.rkt`, that double is the only edit.
  `completion-session.rkt` and `prompt-commands-find-file.rkt` also
  take the class-name pin below.
- These fifteen files, the class-name pin only, under **Class-name
  pins**: `tests/aloemacs/buffer-value.rkt`,
  `tests/aloemacs/completion-page-session.rkt`,
  `tests/aloemacs/completion-session.rkt`,
  `tests/aloemacs/minibuffer-value.rkt`,
  `tests/aloemacs/mode-line-row.rkt`,
  `tests/aloemacs/prompt-commands-find-file.rkt`,
  `tests/aloemacs/window-bars-one-view.rkt`,
  `tests/aloemacs/window-bars-split.rkt`,
  `tests/aloemacs/windows-buffer-identity.rkt`,
  `tests/aloemacs/windows-delete-and-other.rkt`,
  `tests/aloemacs/windows-layout-and-rendering.rkt`,
  `tests/aloemacs/windows-lock.rkt`,
  `tests/aloemacs/windows-split.rkt`,
  `tests/aloemacs/windows-state-foundation.rkt`,
  `tests/aloemacs/windows-state.rkt`. In each, the expected
  `define-class` name list changes
  `AloemacsSearchScan (AloemacsSession H)` to
  `AloemacsSearchScan AloemacsMouse (AloemacsSession H)`. No other
  line in the thirteen files that appear only in this bullet.
- `docs/gel.md` §6 and `docs/decisions.md`: one factual line each,
  under **Documents**.

### Must leave untouched

- `host/racket/gel-run.rkt`, `host/racket/term-run.rkt`,
  `host/racket/fs.rkt`, everything under `aloe/`, `lib/`, `bin/`,
  `gel/`, `archive/`
- `tests/checkpoint-83.rkt`, `tests/checkpoint-85.rkt`,
  `tests/checkpoint-86.rkt`, and every test not listed above. Session
  tests that send `handle-key` a key string, and the session test
  that sends `(s handle-key (term read-key))` with a scripted double,
  stay green without edits.
- `SPEC.md`, `CHECKPOINTS.md`, the parent aloemacs map, this folder's
  `charter.md` and `spec.md`, every other document under `docs/`, and
  this checkpoint
- The body of `call-with-tty-term-receiver`, `tkeymsg->aloe-key`,
  `make-term-receiver`'s arguments, and the first five catalog rows
- `run-aloemacs-with-hosts` apart from the one prepared send,
  `run-aloemacs-with-term`, and the loop order
- `AloemacsEditor.handle-key`, `at-focused`, `buffer-end`,
  `with-text-and-point`, `ensure-visible`, `enter-view`,
  `other-window`, `with-editor`, `with-buffer`, `rect-for`,
  `find-view`, `root-rect`, `completion-row-count`, `frame`,
  `multi-frame`, `single-frame`, `record-pictures`, the mode-line and
  bar paint, the echo-row paint, and the keymap tables
- `tui-term`

Add no key, command constructor, keymap binding, kernel message,
`SPEC.md` row, `lib/` method, Text method, or second host capability.
Do not call `term-enable-mouse`. Do not write `1003`. If another file
or method is necessary, stop and send this checkpoint back. Do not
widen the slice.

## Required behavior

### The sixth method and the skip (spec §5.1, §5.2)

Append one row to `term-interface`:

```racket
(make-host-method 'read-event '() 'String term-read-event)
```

The ordered selectors become
`(read-key write-line write columns rows read-event)`, the parameter
types `(() (String) (String) () () ())`, and the return types
`(String String String Int Int String)`.

`term-read-event` calls the state's reader thunk once and returns
what it returns. `term-read-key` calls the thunk, and while the result
is a string that matches the mouse grammar, calls it again; it returns
the first result that is not. Test the grammar only on a string. A
non-string result is returned as it is, so the existing boundary
error in `tests/checkpoint-84.rkt` (`read-key` result must be a
`String`, with a thunk that returns `1`) still fires from the host
boundary and not from `regexp-match?`.

The grammar, as one Racket regexp over the whole string:

```racket
#rx"^mouse (down|up) (left|middle|right) (0|[1-9][0-9]*) (0|[1-9][0-9]*)$"
```

`make-term-receiver` keeps its three arguments and its defaults.

### The formatter and the production reader (spec §5.2)

Export `tmousemsg->aloe-mouse` next to `tkeymsg->aloe-key`. Require
`tui/term/geometry` for `tpoint?`, `tpoint-x`, and `tpoint-y`. The
procedure returns a string when all of these hold, and `#f`
otherwise:

- the value is a `tmousemsg`
- `tmousemsg-kind` is `button-down` or `button-up`
- `tmousemsg-button` is `left`, `middle`, or `right`
- `tmousemsg-pos` is a `tpoint` whose `tpoint-x` and `tpoint-y` are
  exact integers `>= 0`

The string is `mouse`, a space, `down` or `up`, a space, the button
symbol's name, a space, `tpoint-x` in decimal, a space, `tpoint-y` in
decimal. `number->string` of an exact non-negative integer is the
canonical decimal the grammar accepts. The three boolean fields do not
affect the string. Do not subtract one; `tui-term` already did.

In `read-next-key`, split the `tmousemsg` arm from the `tsizemsg`
arm. For a `tmousemsg`, call the formatter; return its string when it
is one, and loop when it is `#f`. Resize and anything else still loop.
End of input still raises the existing error from this reader, so
both `read-key` and `read-event` raise it. The focused tests do not
open a TTY to prove that.

### Button-only reporting (spec §5.3)

In `run-aloemacs`, the procedure given to `call-with-tty-term-receiver`
wraps its call to `run-aloemacs-with-term` in a `dynamic-wind`:

- The before thunk writes `ESC [ ? 1 0 0 0 h ESC [ ? 1 0 0 6 h` to
  `(current-output-port)` and flushes.
- The after thunk writes `ESC [ ? 1 0 0 0 l ESC [ ? 1 0 0 6 l` to
  `(current-output-port)` and flushes.

Inside that procedure `(current-output-port)` is the terminal, because
`with-term` parameterized it. The after thunk runs on normal return
and when an exception leaves the editor, before `with-term` closes the
port. It does not catch the exception. `with-term` then writes its own
`1003l` and `1006l`; the runner's `1000l` is what turns button tracking
off for the shell.

Spell ESC as `\e` or `\x1b` in the Racket string. `tests/aloemacs/runner.rkt`
and `tests/aloemacs/file-runner.rkt` forbid the six characters
`\u001b` anywhere in the runner source. Write with `display` or
`write-string` and `flush-output`; `write-line` is forbidden in that
source too.

`run-aloemacs-with-hosts`, `run-aloemacs-with-term`,
`call-with-tty-term-receiver`, and `term.rkt` do not write those bytes.
A scripted run writes no enable bytes. The runner source contains the
literal substrings `[?1000h`, `[?1006h`, `[?1000l`, and `[?1006l`, and
contains neither `1003` nor `term-enable-mouse`. `term.rkt` contains
neither `1000`, `1003`, nor `term-enable-mouse`. `gel-run.rkt` and
`term-run.rkt` are not edited and contain neither `read-event`,
`1000`, nor `term-enable-mouse`.

### The runner send (spec §5.1)

Replace the prepared definition in `run-aloemacs-with-hosts` with:

```racket
'(define aloemacs-editor
   (aloemacs-editor handle-event (term read-event)))
```

Rename the local binding if you like. The loop order stays: columns,
rows, fit, record, frame, this send, quit check. The runner source
contains `(term read-event)` exactly once, after `aloemacs-editor frame`,
and no longer contains `(term read-key)`. It contains
`aloemacs-editor handle-event`. It still contains the phrases
`tests/aloemacs/runner.rkt` and `tests/aloemacs/file-runner.rkt`
require and none they forbid.

### `AloemacsMouse` (spec §5.2)

```aloe
(define-class AloemacsMouse
  (fields
    (event String))
  (methods
    …))
```

Five public sends. Their results are fixed when `event?` is true:

| Send | Type | Result |
|---|---|---|
| `(mouse event?)` | `Bool` | The whole string matches the grammar |
| `(mouse down?)` | `Bool` | The action field is `down` |
| `(mouse left?)` | `Bool` | The button field is `left` |
| `(mouse column)` | `Int` | The column decimal |
| `(mouse row)` | `Int` | The row decimal |

`event?` is true for exactly the strings the Racket regexp accepts:
`mouse`, one space, `down` or `up`, one space, `left`, `middle`, or
`right`, one space, a canonical decimal, one space, a canonical
decimal, and nothing else. A canonical decimal is `0`, or a non-zero
digit followed by digits. Rejected, and therefore keys:
`mouse down left 04 2`, `mouse down left 4 2 ` (trailing space),
`mouse down left -1 2`, `mouse`, `Mouse down left 4 2`,
`mouse down left 4`, `mouse down left 4  2` (two spaces),
`mouse down left 4 2 1`.

Parse with the String and Int messages that exist: `starts-with?`,
`take`, `drop`, `len`, `=`, `find`, `min`, `+`, `*`. One way: a digit
is a one-character string `d` with `(("0123456789" find d 0) present?)`,
and its value is that index; a decimal's value is a fold over its
characters. Guard the empty string: `find` of `""` succeeds at `0`.
Add no kernel message and no `lib/` method. Private helpers on
`AloemacsMouse` are allowed; name them as you like. On a string that
is not an event, `column` and `row` return some `Int` without
raising; nothing sends them then.

### `contains?` and `view-at` (spec §5.4)

On `AloemacsWindowRect`:

```aloe
(contains? (column Int) (row Int) Bool
  …)
```

True when `x <= column < x + columns` and `y <= row < y + rows`.

In `define-methods AloemacsWindowTree`, beside `rect-for`:

```aloe
(view-at (column Int) (row Int) (rect AloemacsWindowRect) (Option AloemacsView)
  …)
```

A `Leaf` returns `(Option Some view)` when `rect` contains the cell
and `(Option None)` otherwise. `Below` tries `top` with `(rect top)`,
then `bottom` with `(rect bottom)`. `Right` tries `left` with
`(rect left)`, then `right` with `(rect right)`. The reserved column
of a Right split is in neither child, so `view-at` is `None` there.

### Editor `place` (spec §5.5)

Add to `AloemacsEditor`, beside `buffer-end`:

```aloe
(place (line Int) (column Int) AloemacsEditor
  (((self text) focus-at line) case
    (Some (focused) (self at-focused focused column))
    (None () (self buffer-end))))
```

`line` and `column` are `>= 0` when sent. A column past the line's
length becomes that length. A line `focus-at` does not find becomes
the end of the last line. When the receiver's point is already the
clamped point, `at-focused` returns the receiver unchanged. The
characters stay. A place that moves the point leaves the Text focused
on the placed line. `place` does not touch the mark, the history,
`quit`, `text-rows`, `scroll-row`, or `scroll-col`, and pushes no undo
frame.

### Session `place-at` (spec §5.5)

```aloe
(place-at (line Int) (column Int) (AloemacsSession H)
  ((self with-editor ((self editor) place line column)) with-echo ""))
```

`with-editor` already stores the editor point and origin on the
selected view. `place-at` does not send `ensure-visible` and does not
change the origin; the runner's next fit is the fit. The echo clear
happens even when the point did not move.

### `handle-event` and `handle-mouse` (spec §5.6)

```aloe
(handle-event (event String) (AloemacsSession H)
  (cond
    ((self quit) (self unchanged))
    (((AloemacsMouse new event) event?) (self handle-mouse event))
    (else (self handle-key event))))
```

`handle-mouse` returns the receiver unchanged when `searching` is
true, when `prompt` is present, or when `pending` is present. Otherwise
it reads the string. Only a string with `down?` and `left?` goes on to
the cell; every other mouse string returns the receiver unchanged.

A key string takes `handle-key` exactly as today. A mouse string never
reaches `handle-key`, `idle-key`, the keymap, or `insert`.

### Where a cell lands (spec §5.4)

Use the geometry the last fit stored: `columns` and `rows` are
`((self windows) columns)` and `((self windows) rows)`; `root` is
`(self root-rect columns rows)`; `count` is
`(self completion-row-count rows)`. Do not send `(term columns)` or
`(term rows)`. `column` and `row` are the 0-based numbers from the
string. Classify in this order; the first match wins:

| Order | Region | Condition | Result |
|---:|---|---|---|
| 1 | Echo | `rows >= 2` and `row = rows - 1` | unchanged |
| 2 | Completion | `(root rows) <= row < (root rows) + count` | unchanged |
| 3 | Mode line | `((tree view-at column row root))` finds a leaf; its `rect-for` on `root` has `rows >= 2`; `row = y + rows - 1` | unchanged |
| 4 | Text | that leaf, and the cell is not its mode line | place |
| 5 | Elsewhere | `view-at` is `None` | unchanged |

A leaf shorter than two rows is all text. A terminal shorter than two
rows has no echo row and `count` is 0. The leaf's rectangle comes from
`rect-for (view id) root`; its `Some` arm is the one that runs, since
`view-at` found the leaf on the same walk.

Worked rectangles, from the live `top`, `bottom`, `left`, and `right`:

- 80 by 24, no completion rows: root `(0, 0, 80, 23)`, echo row 23.
  One leaf: text rows 0–21, mode line 22. Below split: `(0, 0, 80, 12)`
  and `(0, 12, 80, 11)`, mode lines 11 and 22. Right split: bar on
  column 40, left leaf columns 0–39, right leaf from column 41.
- 40 by 10, no completion rows: root `(0, 0, 40, 9)`, echo row 9.
  One leaf: text rows 0–7, mode line 8. Below split: `(0, 0, 40, 5)`
  and `(0, 5, 40, 4)`, mode lines 4 and 8. Right split: bar on
  column 20, right leaf from column 21.
- 80 by 24 with two completion lines: root `(0, 0, 80, 21)`,
  completion rows 21 and 22, echo row 23, one leaf's mode line 20.
- 80 by 1: root `(0, 0, 80, 1)`, no echo row, count 0, the leaf is
  all text.

### The text cell (spec §5.5)

With the leaf `view` from `view-at` and its `rect`:

```text
line   = (view scroll-row) + (row - (rect y))
column = (view scroll-col) + (column - (rect x))
```

Both are `>= 0` for a cell inside the leaf and a stored origin `>= 0`.

When `(view id)` is `((self windows) selected)`, the update is
`(self place-at line column)`.

Otherwise, use the `other-window` handoff and nothing else:

```aloe
(let ((stored ((self windows) with-buffer (self current-buffer))))
  (((stored tree) find-view (view id)) case
    (None () self)
    (Some (stored-view)
      ((self enter-view (stored tree) stored-view) place-at line column))))
```

The store rewrites the departing view's point and origin. `enter-view`
installs the clicked view's stored point and origin and selects it.
`place-at` then replaces the point with the click and clears the echo
token. The departed view keeps what the store wrote. The entered
view's origin is what `enter-view` installed, until the next fit.
Views that were neither keep their points and origins. A locked leaf
can be selected; add no lock check. Placement never runs during a
prompt, a search, or a prefix, so this path does not meet
`enter-view`'s search branch.

### What stays in place (spec §5.7)

The frame's bytes are unchanged. The picture key does not gain the
point. No keymap binding, command constructor, or Term method beyond
the sixth. Gel still sends only `read-key` and `write-line`.

### Documents (spec §5.7)

- `docs/gel.md` §6, in the bullet that lists the five Term rows: add
  that `read-event : () -> String` is the sixth, and that it returns
  the next key string or the next mouse string. Keep the sentences
  that Gel sends only `read-key` and `write-line` and that mouse and
  resize events are ignored by `read-key`. Section 7 stays.
- `docs/decisions.md`, the "Host terminal input" paragraph: one
  sentence saying the same. Nothing else there changes.

## Verification

### Focused file: `tests/aloemacs/mouse.rkt`

Create it before the product edit. It uses a checked driver,
`make-term-receiver`, and `run-aloemacs-with-hosts`. It does not call
`with-term`, `call-with-tty-term-receiver`, or `run-aloemacs`. It does
not open a TTY. A mouse string is injected by returning it from a
reader thunk, or by sending it to `handle-event` directly.

Requires: `rackunit`, `racket/runtime-path`, `racket/file`,
`racket/string`, `../../aloe/driver.rkt`, `../../aloe/host.rkt`,
`../../aloe/parse.rkt`, `../../aloe/type.rkt` (`exn:fail:aloe-type?`,
`type-of`, `type->datum`), `../../host/racket/term.rkt`,
`../../host/racket/fs.rkt`, `../../host/racket/aloemacs-run.rkt`,
`(only-in tui/term/messages make-tmousemsg)`, and
`(only-in tui/term/geometry tpoint)`.

Session proofs load `examples/aloemacs/main.aloe` through
`driver-load-file!` with an `fs-host` injected first, as
`tests/aloemacs/window-point.rkt` does:

```racket
(make-fs-double "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
  (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b"))
```

Two regular files make the find-file Tab list two completion lines.
The base session is

```aloe
(define s0 ((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt"))
            ensure-visible 80 24))
```

Line 0 is `hello` (length 5), line 1 `world` (5), line 2 `xyz` (3).
`split-below` on `s0` keeps view 0 selected on top and adds view 1
below. Expected values use `(check actual expected)` through the
driver, raw constructors, and field reads, in the style of the
existing session tests. "Unchanged" below means `(check result s)`
where `s` is the receiver.

Prove all of these:

1. **Types and arities.** `(AloemacsMouse new "x")` types as
   `AloemacsMouse`; zero and two arguments, and an `Int` argument, are
   rejected. `event?`, `down?`, `left?` type as `Bool`; `column` and
   `row` as `Int`; each rejects an argument.
   `(rect contains? 0 0)` is `Bool`; `(tree view-at 0 0 rect)` is
   `(Option AloemacsView)`; `(ed place 0 0)` is `AloemacsEditor`;
   `(s place-at 0 0)`, `(s handle-event "x")`, and
   `(s handle-mouse "x")` are the session type. Wrong arity and a
   `String` where an `Int` is due are rejected for each.
2. **Grammar.** `event?` is true for `mouse down left 4 2`,
   `mouse up middle 0 0`, and `mouse down right 10 12`, and false for
   each rejected string listed under **`AloemacsMouse`**. For
   `mouse down left 4 2`: `down?` true, `left?` true, `column` 4,
   `row` 2. For `mouse up middle 0 0`: `down?` false, `left?` false,
   `column` 0, `row` 0. For `mouse down right 10 12`: `column` 10,
   `row` 12.
3. **`read-event` and the skip.** With `make-term-receiver` over a
   thunk that yields `"mouse down left 4 2"` then `"x"`:
   `(term read-event)` through a checked driver returns the mouse
   string, and a second `(term read-event)` returns `"x"`. With a
   fresh receiver over the same script, `(term read-key)` returns
   `"x"`. Over `mouse`, `mouse`, `"x"`, `read-key` returns `"x"`. Over
   `"mouse down left 04 2"`, `read-key` returns that string. The
   checker types `(term read-event)` as `String`.
4. **Catalog.** `(map host-method-selector (host-interface-methods term-interface))`
   is `(read-key write-line write columns rows read-event)`; the
   parameter types are `(() (String) (String) () () ())`; the return
   types are `(String String String Int Int String)`.
5. **Formatter.** Each pair is `(check-equal? (tmousemsg->aloe-mouse …) …)`:
   - `(make-tmousemsg 'button-down (tpoint 4 2) #t #f #f 'left)` → `"mouse down left 4 2"`
   - `(make-tmousemsg 'button-up (tpoint 4 2) #t #f #f 'left)` → `"mouse up left 4 2"`
   - `(make-tmousemsg 'button-up (tpoint 0 0) #f #f #t 'middle)` → `"mouse up middle 0 0"`
   - `(make-tmousemsg 'button-down (tpoint 4 2) #f #t #f 'right)` → `"mouse down right 4 2"`
   - `(make-tmousemsg 'button-down (tpoint 1 2) #t #f #f 'left)` → `"mouse down left 1 2"`
   - kind `'move`, kind `'wheel-up`, button `#f`, and `(tpoint -1 2)` → `#f`
6. **Sources.** Read each file with `file->string`. The runner
   contains `[?1000h`, `[?1006h`, `[?1000l`, `[?1006l`,
   `(term read-event)` once, and `aloemacs-editor handle-event`; it
   contains neither `1003`, `term-enable-mouse`, nor `(term read-key)`.
   `term.rkt` contains neither `1000`, `1003`, nor `term-enable-mouse`.
   `gel-run.rkt` and `term-run.rkt` contain neither `read-event`,
   `1000`, nor `term-enable-mouse`.
7. **Runner.** Copy the scripted-term shape from
   `tests/aloemacs/viewport-runner.rkt`: a `make-term-receiver` whose
   output port records writes and flushes, whose reader thunk pops a
   key list and records it, and whose size reader reports 80 by 24
   each time. The fs double above; visit `"a.txt"`. The script is
   `ctrl-x`, `2`, `mouse down left 1 14`, `ctrl-x`, `o`, `escape`.
   Expect six iterations, each `(columns 80)`, `(rows 24)`,
   `(write frame)`, `flush`, `(key k)`, and an empty remaining list.
   The third frame ends with `\e[1;1H\e[?25h`. The fourth frame ends
   with `\e[15;2H\e[?25h`: the lower leaf is `(0, 12, 80, 11)`, so a
   cursor on its line 2, column 1 is screen row 15, column 2, and only
   a selected lower leaf puts the cursor there. The sixth frame, after
   `C-x o` returns to the upper window, ends with `\e[1;1H\e[?25h`:
   the upper window kept `(0, 0)`. No frame contains `[?1000h` or
   `[?1006h`. The runner owns its driver, so the `focus-line` claim of
   this scenario is proved in item 10, not here.
8. **Selected window, echo, origin.** `(s0 with-echo "saved")`, then
   `handle-event "mouse down left 4 0"`: point `(0, 4)`, echo `""`,
   `scroll-row` and `scroll-col` equal to `s0`'s, text `to-string`
   unchanged, and the selected view stores `(0, 4)`. Do not send
   `ensure-visible` after the press. Second session: `s0 split-below`,
   same press: the selected point is `(0, 4)`, `selected` is still 0,
   and view 1 stores `(0, 0)`.
9. **Clamp.** On `s0`, `mouse down left 9 1` gives `(1, 5)` with
   `focus-line` 1. `mouse down left 0 5` gives `(2, 3)` with
   `focus-line` 2.
10. **Other window.** On `(s0 split-below)`, `mouse down left 1 14`:
    `selected` is 1, point `(2, 1)`, the editor text's `focus-line` 2,
    view 0 stores `(0, 0)`, view 1 stores `(2, 1)`. The characters stay.
11. **Origin.** Build the session with raw constructors: an
    `AloemacsEditor` over `(Text from-string "hi")`, point `(0, 0)`,
    `quit` `#f`, `scroll-row` 10, `scroll-col` 3, empty history, no
    mark, `text-rows` 0; one `AloemacsBuffer` with no path and id 0;
    `AloemacsBuffers` with empty before and after lists; the session
    fields in order `buffers`, `(Fs new fs-host)`, echo `""`,
    `searching` `#f`, query `""`, origin `(Position new 0 0)`,
    `wrapped` `#f`, `failing` `#f`, empty kill ring, pending
    `(Option None)`, prompt `(Option None)`, last-submission
    `(Option None)`, waiting-command `(Option None)`, and
    `(AloemacsWindows new (AloemacsWindowTree Leaf (AloemacsView new 0 0 10 3 (Position new 0 0) #f (Option None))) 0 80 24)`.
    Write the typed `None` values the way `tests/aloemacs/completion-session.rkt`
    does. `handle-event "mouse down left 0 5"` without a fit: point
    `(0, 2)`, `scroll-row` 10, `scroll-col` 3, view 0 stores `(0, 2)`
    with origin `(10, 3)`.
12. **Small screen.** `((s0 ensure-visible 40 10) split-below)`, then
    `mouse down left 1 6`: `selected` 1, point `(1, 1)`, view 0 stores
    `(0, 0)`.
13. **Release and other buttons.** On `(s0 with-echo "saved")`, each
    of `mouse up left 4 0`, `mouse down middle 4 0`,
    `mouse down right 4 0` is unchanged: same session value, so the
    point, selection, and echo `"saved"` all stay.
14. **Chrome.** On `(s0 with-echo "saved")`: `mouse down left 0 22`
    (mode line) and `mouse down left 0 23` (echo row) are unchanged.
    On `((s0 with-echo "saved") split-right)`: `mouse down left 40 0`
    (the bar) is unchanged. On `((s0 with-echo "saved") split-below)`:
    `mouse down left 0 11` (the upper mode line) is unchanged.
15. **One row.** `(s0 ensure-visible 80 1)`, then
    `mouse down left 2 0`: point `(0, 2)`.
16. **Locked.** `((((s0 split-below) other-window) toggle-window-lock) other-window)`
    has `selected` 0 and view 1 locked. `mouse down left 1 14`:
    `selected` 1, point `(2, 1)`, view 1 still locked.
17. **Prompt.** `((s0 handle-key "ctrl-x") handle-key "find")` then
    `handle-key "tab"`: the prompt is present with text `"/cwd/"`,
    `completion-lines` has length 2, `(root-rect 80 24)` has `rows` 21.
    `handle-event "mouse down left 0 21"` is unchanged. So is
    `handle-event "mouse down left 4 0"` on the same session.
18. **Search and prefix.** `(s0 handle-key "find")` has `searching`
    true; `handle-event "mouse down left 0 0"` is unchanged.
    `(s0 handle-key "ctrl-x")` has `pending` present;
    `handle-event "mouse down left 0 0"` is unchanged.
19. **Not inserted, then keys still work.** On `(s0 set-mark)`,
    `handle-event "mouse down left 4 0"`: `to-string` is
    `"hello\nworld\nxyz"`, the mark is `(Option Some (Position new 0 0))`,
    `history` length is unchanged. Then `handle-event "x"` makes line
    0 `hellxo` with point `(0, 5)`; `handle-event "left"` on that
    gives `(0, 4)`; `handle-event "escape"` on that sets `quit`. On
    that quit session, `handle-event "mouse down left 1 1"` is
    unchanged. On `s0`, `handle-event "mouse down left 04 2"` leaves
    the point `(0, 0)` and the text unchanged; it is a key, so assert
    the point and text, not the whole session.

### Catalog and runners

- `tests/checkpoint-53.rkt` line 35, `tests/checkpoint-84.rkt`
  lines 268–270, `tests/aloemacs/term-capability.rkt` lines 47–49:
  append `read-event`, `()`, and `String` to the three lists. Nothing
  else in those tests changes.
- `tests/checkpoint-87.rkt`: append `("read-event" () "String")` to
  `expected-rows`; the two `5`s on lines 65–66 become `6`. The
  reflected-invocation test on line 157 keeps its `first` and
  `(rest first)` reads.
- `tests/aloemacs/viewport-runner.rkt` lines 102–119: the phrase
  `"(term read-key)"` becomes `"(term read-event)"` in the list and
  in the order check. One occurrence is still required. The
  scripted-frame tests in that file stay green as they are.
- `tests/aloemacs/file-runner.rkt` line 192: the required phrase
  `"aloemacs-editor handle-key"` becomes
  `"aloemacs-editor handle-event"`. The forbidden list stays. The
  scripted `"x"`, `"save"`, `"escape"` proof stays and gains no frame.
- In each of the six custom-double runner tests, rename the double's
  read method from `'read-key` to `'read-event`. In
  `completion-session.rkt`, `completion-frame.rkt`, and
  `completion-page-frame.rkt`, the recorded symbol `'read-key` and the
  `'read-key` in each expected event list become `'read-event`. The
  find-file, save-as, and select-buffer doubles record `(list 'key key)`
  and need only the selector rename. No frame, key, or expectation
  changes. If any other assertion in those six files fails, apart from
  the class-name list in `completion-session.rkt` and
  `prompt-commands-find-file.rkt`, the product is wrong; fix the
  product.

### Class-name pins

In each of the fifteen files named in **Exact file scope**, one
expected list of `define-class` names ends
`AloemacsSearchScan (AloemacsSession H)`. Insert `AloemacsMouse`
between those two names. The edited tail is
`AloemacsSearchScan AloemacsMouse (AloemacsSession H)`. Touch no
other line in a file that is in scope only for this pin.
`completion-session.rkt` and `prompt-commands-find-file.rkt` keep
the Term-double edit above and gain this token as well.

Existing scripted runners built on `make-term-receiver` stay green
without edits: their thunks return key strings, `read-event` returns
them, and one iteration still consumes one thunk result.

### Commands

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/mouse.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/checkpoint-53.rkt tests/checkpoint-84.rkt tests/checkpoint-87.rkt
```

Both green before this checkpoint is done. The second command also
covers `tests/checkpoint-86.rkt`'s neighbours only indirectly; run
`TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-83.rkt tests/checkpoint-85.rkt tests/checkpoint-86.rkt`
once as well, since they read `term.rkt`, and expect no change.

### Hand check

The human runs this after the tests are green, from the project root,
on a terminal at least 80 by 24, after
`raco make host/racket/aloemacs-run.rkt`:

1. `racket host/racket/aloemacs-run.rkt` on a scratch file. `C-x 2`.
   Click text in the other window. That window is selected and the
   point is on the clicked character. The first window still shows
   the place it had.
2. Click that window's mode line. The point stays.
3. Click the echo row. The point stays.
4. Click text in the first window. The point moves there, and the
   other window keeps its place.
5. Escape quits. Nothing is saved. In the shell, mouse selection works
   again.

A failure sends the work back. It does not add a feature.

## Acceptance

This checkpoint is done when all of these hold:

1. `(term read-event)` is the sixth Term method and returns the next
   key string or the next mouse string. The first five rows are
   unchanged. The frame is still one `String`.
2. `(term read-key)` returns the next key string and skips a string
   that matches the mouse grammar. A non-string reader result still
   raises the host boundary error.
3. `tmousemsg->aloe-mouse` formats a left, middle, or right press or
   release as `mouse <down|up> <button> <column> <row>` without
   subtracting, and returns `#f` for motion, wheel, an unknown or
   absent button, or a negative or non-integer coordinate. The
   production reader returns that string and skips the `#f` cases.
4. `run-aloemacs` enables `1000` and `1006` and disables both in a
   `dynamic-wind` around the editor, inside the procedure
   `call-with-tty-term-receiver` runs. It does not enable `1003`. No
   other file writes those bytes. A scripted run writes none.
5. The runner blocks on `(term read-event)` and sends the string to
   the session's `handle-event`. Gel and `term-run` are untouched.
6. A left press in a text cell places the point on that cell, clamped
   to the text, with the Text focused on the placed line, and clears
   the echo token. In another window it selects that window first
   through the store-then-enter handoff; the departed window keeps its
   point. The origin is not refitted by the press.
7. A release, a middle or right button, and a left press on the echo
   row, a completion row, a mode line, or a vertical bar leave the
   session value unchanged.
8. Any mouse string during a prompt, a search, or a pending prefix
   leaves the session value unchanged. A mouse string is never
   inserted and never reaches the keymap.
9. `tests/aloemacs/mouse.rkt` proves items 1–19 above without a TTY.
   The catalog, runner, and class-name pin edits are exactly those
   listed. Both commands are green.
10. `docs/gel.md` §6 and `docs/decisions.md` each carry the one
    factual line.

## Non-goals

- Motion, hover, any-event tracking (`1003`), or wheel scrolling
- A modifier field, or a modified click placing the point
- Drag, a selection region, or pairing a press with a release
- Click to split, delete, lock, or select a buffer; a menu; a command
  on the mode line
- Placing the point during a prompt, a search, or a pending prefix
- A second host capability, a new crossing type, or a mouse value
  other than the string
- A change to `tui-term`, Gel's sends, `call-with-tty-term-receiver`,
  frame composition, picture reuse, mode-line paint, bar color, or
  idle-echo paint
- A keymap binding or command constructor
- A kernel message, a `SPEC.md` row, a `lib/` method, a global
  checkpoint number, or an edit to the parent aloemacs map
- Checkpoint 001
