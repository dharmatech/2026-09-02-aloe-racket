# aloemacs-mode-buttons 001 — Press

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice,
and stop when green.

## Goal

A left press on ↕, ↔, or × in a mode line selects that window and
then sends `split-below`, `split-right`, or `delete-window`. The
session after the press equals the session that sequence returns.

- `AloemacsModeLine` gains `label-at`, which names the label a cell of
  a mode line holds, or `""`.
- The session gains `press-mode-line`, `select-view`, and
  `button-send`. The mode-line arm of `press-at`, which today returns
  the receiver, sends `press-mode-line`.
- The selected window runs the send alone. Another window takes the
  handoff the click already uses: store the departing view, enter the
  pressed one, then send. A refused split or delete stays that send's
  refusal, with the window selected first. The press places no point.
- A press on the name, the dash fill, or a space in the group, a
  release, a middle or right button, and any mouse string during a
  prompt, a search, a pending prefix, or after quit leave the session
  as it was.

This is the last checkpoint of the series. Stop when the two focused
files and the full aloemacs suite pass.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec. The
checkpoint narrows the spec to one slice and carries one correction
to a spec table (§1 below). It does not otherwise revise the spec.

- Identity: **aloemacs-mode-buttons 001**, filed as
  `checkpoints/001-press.md`. This is a local editor checkpoint. It
  takes no global number and gets no `CHECKPOINTS.md` entry. There is
  no 002.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`.
- The accepted [../spec.md](../spec.md) governs:
  - §§1–4: predecessors, the product boundary, the file boundary,
    exact shapes, and non-goals.
  - §5.4–§5.7: label cells, the press, the presses that leave the
    session, and what stays in place.
  - §7: this layer, including its worked geometry, press tables,
    migration, and focused proof.
  - §8: the 001 verification commands and the hand check.
- [000-paint.md](000-paint.md) is implemented and reviewed. Its row,
  `name-row`, `buttons`, and `buttons?` are the starting point and do
  not change.

### Current tree

Start from
[file.aloe](../../../../../../examples/aloemacs/file.aloe). Line
numbers are approximate.

- `AloemacsModeLine` (near line 251) has `buttons`, `buttons?`,
  `name-row`, `row`, `fill`, `bar`, `light`, `dark`, and `plain`. It
  keeps `(fields)`.
- `handle-event` (near line 2039) returns the receiver after quit,
  sends a mouse string to `handle-mouse`, and everything else to
  `handle-key`. `handle-mouse` (near line 2047) returns the receiver
  while `searching`, while the prompt is present, and while `pending`
  is present; otherwise only a string with `down?` and `left?`
  reaches `press-at`.
- `press-at` (near line 2062) classifies in this order: the echo row,
  a completion row, then `view-at`, then `rect-for` on the same root,
  then the mode-line test, then text. Its mode-line arm is the
  `(self unchanged)` in:

  ```aloe
  (if (if ((rect rows) >= 2)
          (row = (((rect y) + (rect rows)) - 1))
          #f)
      (self unchanged)
      (self place-in view
        ((view scroll-row) + (row - (rect y)))
        ((view scroll-col) + (column - (rect x)))))
  ```

- `place-in` (near line 2088) is the text arm: the selected leaf
  places directly; another leaf stores the departing view through
  `with-buffer`, finds the clicked view in the stored tree, and
  `enter-view`s it, then places. `place-at` is the last method of the
  session.
- `enter-view` (near line 1438) installs the entered view's point and
  origin, makes its buffer current, and on a buffer change resets the
  echo, search, and pending fields. It has no lock check.
- `split-below`, `split-right`, `delete-window`, `other-window`,
  `toggle-window-lock`, `with-echo`, and `find-file-submitted` exist
  on the session with the results the windows and window-point specs
  give them.

### Size

One conversation. The product edit is one short method on
`AloemacsModeLine`, three short methods on the session, and one
replaced arm in `press-at`. The focused file is new. Exactly two
existing test files change, each in one place.

The manager applied exactly the §5.4 and §5.5 product edit to a
scratch copy of the tree and ran `TMPDIR=/tmp raco test -j 4 -y
tests/aloemacs`. It reported 2 failures: item 8 of
`mode-buttons-paint.rkt`, which 001 replaces, and the method-shape
loop of `window-bars-one-view.rkt`, which 001 extends. `mouse.rkt`
and every other file passed unedited. The manager then checked every
row of the press and unchanged tables below, the short-leaf press,
the key sequence after a press, and the runner script against that
scratch copy. All hold.

The implementation on 2026-10-11 took the optional rewrite of
`place-in` over `select-view`, so the click and the label press share
one handoff. The manager reviewed the diff against this checkpoint and
found it conforming: `mode-buttons-paint.rkt` and
`mode-buttons-press.rkt` pass 21 tests, the aloemacs suite passes 610,
and `git diff --check` is clean. One note for the commit: the header
comment of `mode-buttons-paint.rkt` still says a label press leaves the
session unchanged. This checkpoint forbade other edits to that file, so
the comment is stale; correcting it is a one-line commit-time edit and
needs no further checkpoint.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, in exactly two classes:
  1. `AloemacsModeLine` gains `label-at`. Nothing else on the class
     changes.
  2. `(AloemacsSession H)` gains `press-mode-line`, `select-view`, and
     `button-send`, and the mode-line arm of `press-at` becomes
     `(self press-mode-line view rect (column - (rect x)))`. Nothing
     else in `press-at` changes. `place-in` may be rewritten over
     `select-view`, with `(None () self)` and
     `(Some (s) (s place-at line column))`, or left as it is; its
     result is unchanged either way and `mouse.rkt` is the proof.
  You may add a comment above each new method.
- Create `tests/aloemacs/mode-buttons-press.rkt` before the product
  edit, and watch it fail.
- `tests/aloemacs/mode-buttons-paint.rkt`: replace item 8, the test
  case "a left press on a label leaves the session unchanged", with
  the press results of §5 below for those three presses. Change
  nothing else in that file.
- `tests/aloemacs/window-bars-one-view.rkt`: in the method-shape
  assertion near lines 187–196, pin
  `(label-at (width Int) (index Int) String)` beside `row`, `fill`,
  `bar`, `name-row`, and `buttons?`, and add `label-at` to the
  zero-argument loop's exclusion. The `bar` ownership loop is
  unchanged. Change nothing else in that file.

### Must leave untouched

- In `file.aloe`: `buttons`, `buttons?`, `name-row`, `row`, `fill`,
  `bar`, `light`, `dark`, `plain`; `handle-event`, `handle-mouse`,
  every arm of `press-at` other than the mode-line arm, `place-at`,
  `place-in`'s result, `view-at`, `rect-for`, `contains?`,
  `root-rect`, `completion-row-count`, `split-below`, `split-right`,
  `delete-window`, `split-window`, `delete-refused`, `enter-view`,
  `other-window`, `with-buffer`, `with-editor`, `frame`,
  `single-frame`, `multi-frame`, `built-rows`, `right-rows`,
  `record-pictures`, the echo row, the completion rows, the keymap
  tables, `AloemacsCommand`'s constructors, `AloemacsMouse`, and the
  two loads. Do not change the order of declarations.
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`,
  everything under `host/racket/`, `lib/`, `aloe/`, `bin/`, `SPEC.md`,
  and `CHECKPOINTS.md`. Add no dependency, load, host capability,
  runner argument, Term method, mouse mode, or build step. The mouse
  string, mode `1000`, and SGR `1006` are unchanged.
- Shapes. The ordered `define-class` list of `file.aloe` is
  unchanged, so the fifteen tests that pin it need no edit.
  `AloemacsModeLine` keeps `(fields)` and its position. `AloemacsView`,
  `AloemacsLeafPicture`, `AloemacsWindowRect`, `AloemacsWindows`,
  `AloemacsBuffer`, `AloemacsEditor`, and the session keep their
  fields. Add no class, field, command, key, keymap entry, face, or
  kernel message. `C-x l` is not sent.
- Every existing test other than the two named above. In particular
  `tests/aloemacs/mouse.rkt` stays green unedited: its mode-line
  presses are at column 0, the name, and stay inert. If any other
  test fails, the product is wrong; fix the product. Create no shared
  helper module.
- Every document: this checkpoint, `spec.md`, `charter.md`,
  `README.md`, and `000-paint.md` in this folder; the mouse,
  mode-line, window-bars, window-point, windows, and safe-cells
  documents; and the parent `aloemacs/README.md`, `discussion.md`,
  and `explorations.md`.

If another file, another class, a fixture change, or a geometry
change seems necessary, stop and report it. Do not widen this
checkpoint.

## Required behavior

### 1. Label cells (spec §5.4)

Add to `AloemacsModeLine`:

```text
(line label-at width index) -> String
```

```text
label-at(width, index) = "↕"  when buttons?(width) and index = width - 5
                       = "↔"  when buttons?(width) and index = width - 3
                       = "×"  when buttons?(width) and index = width - 1
                       = ""   otherwise
```

`index` is a column within the row, 0-based from the leaf's left
edge. The send is pure, performs no effect, accepts any two `Int`s,
and never raises. It answers only which label a cell names; whether
anything happens is the session's decision in §2. The three results
are one character each: U+2195, U+2194, U+00D7. Spell them in
`file.aloe` with escapes, as `buttons` does, so the file stays ASCII
bytes:

```aloe
(label-at (width Int) (index Int) String
  (if (self buttons? width)
      (cond
        ((index = (width - 5)) "\u2195")
        ((index = (width - 3)) "\u2194")
        ((index = (width - 1)) "\u00d7")
        (else ""))
      ""))
```

An implementation may instead read the characters out of `buttons`.
This table is the contract:

| Width | Index | Result |
|---:|---:|---|
| 80 | 75 | `↕` |
| 80 | 77 | `↔` |
| 80 | 79 | `×` |
| 80 | 74, 76, 78 | `""` (the three spaces) |
| 80 | 0, 10, 73 | `""` (name or fill) |
| 80 | 80, -1 | `""` (outside the row) |
| 7 | 2, 4, 6 | `↕`, `↔`, `×` (the row is `u ↕ ↔ ×`) |
| 7 | 0, 1, 3, 5 | `""` |
| 6 | 1, 3, 5 | `""` (no labels below 7) |
| 40 | 35, 37, 39 | `↕`, `↔`, `×` |
| 39 | 34, 36, 38 | `↕`, `↔`, `×` |
| 0 | 0 | `""` |

**Correction to the spec.** As accepted, spec §5.4's table gave the
width-7 labels at indices 1, 3, 5. That contradicted the formula
above it, the pinned row `u ↕ ↔ ×`, and §5.2's statement that ↕ is
at `width - 5`. The manager corrected that table row in `spec.md` on
2026-10-11 to 2, 4, 6. The formula was always the rule; this
checkpoint's table is the corrected one.

The screen column of a label is the leaf rectangle's `x` plus the
index. The row is the leaf's last row, `y + rows - 1`, when the leaf
is at least two rows tall. That is the test `press-at` already
applies before it reaches the mode-line arm. Do not hard-code a row
number or a column.

### 2. The press (spec §5.5)

`handle-event` and `handle-mouse` are unchanged. Quit still wins
before the string is examined. A search, a prompt, or a pending
prefix still refuses every mouse string before the cell is
classified. Only a string with `event?`, `down?`, and `left?` reaches
`press-at`.

`press-at` keeps its order. Replace the `(self unchanged)` of its
mode-line arm with:

```aloe
(self press-mode-line view rect (column - (rect x)))
```

`view` is the leaf `view-at` found, `rect` is its rectangle from
`rect-for` on the same root, and `column` is the pressed screen
column. Add three session sends. This sketch can be pasted as it is:

```aloe
;; A label cell on a mode line selects that window, then runs the
;; window command the label names. Every other mode-line cell leaves
;; the session as it was.
(press-mode-line (view AloemacsView) (rect AloemacsWindowRect) (index Int)
                 (AloemacsSession H)
  (let ((label ((AloemacsModeLine new) label-at (rect columns) index)))
    (if (label = "")
        (self unchanged)
        ((self select-view view) case
          (None () (self unchanged))
          (Some (selected) (selected button-send label))))))

;; The selected view is already selected. Another view takes the
;; other-window handoff: store the departing view, then enter the
;; pressed one. A view the stored tree lacks is None.
(select-view (view AloemacsView) (Option (AloemacsSession H))
  (if ((view id) = ((self windows) selected))
      (Option Some self)
      (let ((stored ((self windows) with-buffer (self current-buffer))))
        (((stored tree) find-view (view id)) case
          (None () (Option None))
          (Some (stored-view)
            (Option Some (self enter-view (stored tree) stored-view)))))))

(button-send (label String) (AloemacsSession H)
  (cond
    ((label = "\u2195") (self split-below))
    ((label = "\u2194") (self split-right))
    ((label = "\u00d7") (self delete-window))
    (else (self unchanged))))
```

The session after the press **equals the session that sequence
returns**. Nothing is added after the send: no `with-echo`, no
`place-at`, no `ensure-visible` beyond the fit `split-window` already
performs. In particular:

- **Selected window.** `select-view` is `Some self`, so the result is
  the bare send on the receiver: `(self split-below)`,
  `(self split-right)`, or `(self delete-window)`.
- **Another window.** The handoff is the one `place-in` already uses,
  word for word: `with-buffer` stores the departing view's live point
  and origin, `find-view` finds the pressed view in that stored tree,
  and `enter-view` installs its stored point and origin and selects
  it. Then the send runs on the entered session. On a two-leaf tree
  this is exactly `other-window` followed by the send, which is how
  the tables below spell it. `enter-view` on another buffer makes
  that buffer current and applies its existing echo, search, and
  pending resets; on the same buffer it keeps them. A locked window
  can be selected; `enter-view` has no lock check and this path adds
  none.
- **The point.** The click column is never installed. The point after
  the press is whatever the send leaves: the entered view's stored
  point for a split or a same-buffer entry, and the promoted sibling's
  stored point for a successful delete.
- **Fit.** A successful split fits once, inside `split-window`, as it
  does from `C-x 2` and `C-x 3`. A successful delete does not fit; the
  runner's next `ensure-visible` is the fit, as after `C-x 0`.
- **Echo.** The token is whatever the send writes: a successful split
  stores `""`, a refused split or delete stores `"failed"`, and a
  successful delete stores `""` on a buffer change and keeps the token
  otherwise. The prompt and search rows of the windows spec's table
  cannot apply, because `handle-mouse` refused those sessions earlier.
- **Refusals.** Delete of the only window, delete of a locked window,
  a split of a locked window, a below split of a leaf shorter than
  four rows, and a right split of a leaf narrower than three columns
  are the sends' existing refusals. Selection still happens first:
  after × on an unselected locked window, that window is selected and
  the echo token is `failed`.
- **Missing view.** When `find-view` on the stored tree returns
  `None`, the session is unchanged and the send does not run.
  Program-created trees never miss; the arm mirrors `place-in`.

The classification uses the geometry the last fit stored, as the
mouse spec says. In a fallback frame that geometry is the nominal
tree's, as it already is for a text press.

### 3. Presses that leave the session (spec §5.6)

These return the receiver, so the point, the selection, every view's
stored point and origin, the echo token, the text, the mark, the kill
ring, the undo history, the prompt, the search, and the pending
prefix all stay:

- a left press on a mode line's name cells or dash fill, including on
  an unselected window
- a left press on any of the three spaces in the group: indices
  `width - 6`, `width - 4`, and `width - 2`
- a left press on a mode line narrower than 7 columns, which has no
  label cells
- a left release on a label, or anywhere else
- a middle or right button, pressed or released, anywhere
- any mouse string while `searching` is true, while the prompt is
  present, or while `pending` is present, including one aimed at a
  label
- any mouse string after quit

A leaf shorter than two rows has no mode line, so a press on its last
row is a text press under the mouse spec and places the point. The
echo row, a completion row, and a vertical bar keep the mouse spec's
results. A refused near-miss such as `mouse down left 075 22` is a
key, as today.

### 4. What stays in place (spec §5.7)

The keymap tables gain no binding. `AloemacsCommand` gains no
constructor. `C-x 2`, `C-x 3`, `C-x 0`, `C-x o`, and `C-x l` are
unchanged. The labels are painted exactly as 000 paints them; this
checkpoint changes no frame byte. The runner enables no new mouse
mode and gains no bytes. The accepted mouse spec's statement that a
left press on a mode line places nothing stays true: a label press
places nothing and runs a window command instead.

### 5. Fixtures and the press tables (spec §7.2)

Worked geometry, from the live `top`, `bottom`, `left`, and `right`.
The row of each mode line is the leaf's last row.

| Screen | Tree | Leaf | Mode line row | ↕, ↔, × columns |
|---|---|---|---:|---|
| 80 by 24 | one leaf | `(0,0,80,23)` | 22 | 75, 77, 79 |
| 80 by 24 | Below | `(0,0,80,12)`, `(0,12,80,11)` | 11, 22 | 75, 77, 79 on both |
| 80 by 24 | Right | left `(0,0,40,23)`, bar at 40, right `(41,0,39,23)` | 22 | left 35, 37, 39; right 75, 77, 79 |
| 40 by 10 | one leaf | `(0,0,40,9)` | 8 | 35, 37, 39 |
| 40 by 10 | Below | `(0,0,40,5)`, `(0,5,40,4)` | 4, 8 | 35, 37, 39 on both |
| 40 by 10 | Right | left `(0,0,20,9)`, bar at 20, right `(21,0,19,9)` | 8 | left 15, 17, 19; right 35, 37, 39 |
| 9 by 6 | Right | `(0,0,4,5)`, bar at 4, `(5,0,4,5)` | 4 | none; both leaves are narrower than 7 |

The fs double is the one `tests/aloemacs/mouse.rkt` uses:

```racket
(make-fs-double "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
  (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b"))
```

Fixtures, each an Aloe expression on the loaded `main.aloe`:

| Name | Expression | State |
|---|---|---|
| `s0` | `((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)` | one view, point `(0,0)`, echo `""` |
| `e16` | `((((s0 split-below) other-window) toggle-window-lock) other-window)` | view 0 selected on top, view 1 locked below |
| `s-two` | `((((s0 split-below) other-window) find-file-submitted "b.txt") other-window)` | view 0 selected on `/cwd/a.txt`, view 1 below showing `/cwd/b.txt`; `before` is empty and `after` holds one buffer |
| `s40b` | `((s0 ensure-visible 40 10) split-below)` | two leaves at 40 by 10 |
| `s9` | `((s0 ensure-visible 9 6) split-right)` | two leaves 4 wide |
| `e17` | `(((s0 handle-key "ctrl-x") handle-key "find") handle-key "tab")` | the find-file prompt with two completion lines; `(e17 root-rect 80 24)` has 21 rows, so the mode line is row 20 |
| `e18s` | `(s0 handle-key "find")` | `searching` |
| `e18p` | `(s0 handle-key "ctrl-x")` | `pending` present |
| `e19q` | `(((((s0 set-mark) handle-event "mouse down left 4 0") handle-event "x") handle-event "left") handle-event "escape")` | `quit`, as `mouse.rkt` item 19 builds it |

Each row below reads "the press on the left returns a session equal
to the expression on the right". Equality is `(check actual expected)`
through the driver.

| Session | Press | Equals |
|---|---|---|
| `s0` | `mouse down left 75 22` | `(s0 split-below)` |
| `s0` | `mouse down left 77 22` | `(s0 split-right)` |
| `s0` | `mouse down left 79 22` | `(s0 delete-window)`, which is `(s0 with-echo "failed")`: the sole window |
| `(s0 with-echo "saved")` | `mouse down left 75 22` | `((s0 with-echo "saved") split-below)`; its echo is `""` |
| `(s0 split-below)` | `mouse down left 79 22` | `(((s0 split-below) other-window) delete-window)`: one leaf, `selected` 0, point `(0,0)`, view 0 stored at point `(0,0)` and origin `(0,0)` |
| `(s0 split-below)` | `mouse down left 75 22` | `(((s0 split-below) other-window) split-below)`: three leaves, `selected` 1 |
| `(s0 split-below)` | `mouse down left 77 11` | `((s0 split-below) split-right)`: the selected upper leaf splits |
| `(s0 split-right)` | `mouse down left 79 22` | `(((s0 split-right) other-window) delete-window)` |
| `(s0 split-right)` | `mouse down left 39 22` | `((s0 split-right) delete-window)` |
| `e16` | `mouse down left 79 22` | `((e16 other-window) with-echo "failed")`: `selected` is 1, view 1 is still locked, two leaves, echo `failed` |
| `e16` | `mouse down left 75 22` | `((e16 other-window) with-echo "failed")`: a locked view refuses a split |
| `s-two` | `mouse down left 79 22` | `((s-two other-window) delete-window)`: enters the `/cwd/b.txt` window, deletes it, returns to view 0 on `/cwd/a.txt`; one leaf, the current buffer is `/cwd/a.txt`, and `(buffers after)` still holds the `/cwd/b.txt` buffer |
| `s40b` | `mouse down left 39 8` | `((s40b other-window) delete-window)` |

In every row the point is not placed: after `mouse down left 75 22`
on `s0`, the point is `(0,0)`, because `split-below` leaves it there.

Unchanged presses, each returning a session equal to the receiver:

| Session | Press | Why |
|---|---|---|
| `(s0 with-echo "saved")` | `mouse down left 0 22`, `mouse down left 40 22`, `mouse down left 73 22` | name and fill |
| `(s0 with-echo "saved")` | `mouse down left 74 22`, `mouse down left 76 22`, `mouse down left 78 22` | the three spaces |
| `(s0 with-echo "saved")` | `mouse up left 75 22`, `mouse up left 79 22` | a release |
| `(s0 with-echo "saved")` | `mouse down middle 75 22`, `mouse down right 79 22` | other buttons |
| `(s0 split-below)` | `mouse down left 0 22`, `mouse down left 10 22` | the unselected window's name; `selected` stays 0 |
| `(s0 split-right)` | `mouse down left 40 22`, `mouse down left 41 22` | the bar, then the right leaf's name |
| `s9` | `mouse down left 3 4`, `mouse down left 8 4` | leaves narrower than 7 |
| `e17` | `mouse down left 75 20`, `mouse down left 79 20` | the prompt |
| `e18s` | `mouse down left 75 22` | search |
| `e18p` | `mouse down left 79 22` | pending prefix |
| `e19q` | `mouse down left 75 22` | quit |

A leaf shorter than two rows has no labels: on
`(s0 ensure-visible 80 1)`, `mouse down left 79 0` is a text press
and places the point at `(0,5)`, the clamped end of `hello`.

Keys still work after a press: on `(s0 handle-event "mouse down left 75 22")`,
`handle-event "x"` inserts `x` at `(0,0)` of the selected upper
window, so the text is `xhello\nworld\nxyz`, the point is `(0,1)`,
`selected` is 0, and view 1's stored point is still `(0,0)`. Then
`handle-event "escape"` sets `quit`, and a further
`mouse down left 79 22` leaves that session unchanged.

### 6. Runner

Through `run-aloemacs-with-hosts` at 80 by 24 on `a.txt`, the script
`ctrl-x`, `2`, `mouse down left 79 22`, `escape` writes four frames.
The third is a split frame with two groups, on rows 11 and 22. The
fourth equals the first: one view, the cursor at `1;1`, no echo
payload. Each iteration is `(columns 80)`, `(rows 24)`,
`(write frame)`, `flush`, `(key k)`, as `mouse.rkt` item 7 records
them. The runner gains no bytes.

## Tests

### Focused proof: `tests/aloemacs/mode-buttons-press.rkt`

Write this file first and watch it fail. It uses a checked driver,
`rackunit`, and the fs double above, loads `main.aloe` through
`driver-load-file!` with the `fs-host` injected first, uses
`make-term-receiver` and `run-aloemacs-with-hosts` for the runner
item, and does not open a TTY. It does not call `with-term`,
`call-with-tty-term-receiver`, or `run-aloemacs`. Follow the patterns
of `mouse.rkt` (`same`, `unchanged!`, `at!`, `stores!`, `selected!`,
`make-scripted-term`) and `mode-buttons-paint.rkt` (reading
`file.aloe` as data, type rejections). Copy any helper you need into
this file. Do not `require` another test module.

"Equals" is `(check actual expected)` through the driver. Expected
values are raw constructors, selectors, and the sends named in the
tables. Prove:

1. **Types and arities.** `((AloemacsModeLine new) label-at 80 75)`
   types as `String` and rejects one and three arguments and a
   `String` argument. With `session-type` as `(dtype 's0)`, as
   `mouse.rkt` defines it: `(s0 select-view v)` for an `AloemacsView`
   `v` types as `(Option session-type)` and rejects zero and two
   arguments; `(s0 button-send "x")` types as `session-type` and
   rejects an `Int`; `(s0 press-mode-line v r 75)` for an
   `AloemacsWindowRect` `r` types as `session-type`. `press-at`,
   `handle-event`, and `handle-mouse` still type as `session-type`.
   Read as data with `port->list read`, `label-at` is declared
   `(label-at (width Int) (index Int) String)`, the ordered
   `define-class` list is the one `mode-buttons-paint.rkt` pins, and
   `AloemacsModeLine` keeps `(fields)`. `file.aloe` is still ASCII
   bytes and contains the three escape spellings; build the expected
   backslash from its character code rather than typing an escape, as
   `mode-buttons-paint.rkt` does.
2. **Label cells.** Every row of the table in §1.
3. **Each label, selected window.** The first four rows of §5's press
   table, plus the point staying `(0,0)` after the first.
4. **Each label, another window.** The `(s0 split-below)` rows for
   79 and 75 on row 22, and the `(s0 split-right)` rows for 79 and
   39. For the delete, also assert one leaf, `selected` 0, and view
   0's stored point `(0,0)` and origin `(0,0)`. For the split, assert
   three leaves and `selected` 1.
5. **Selected window in a split.** `(s0 split-below)` with
   `mouse down left 77 11`.
6. **Refusals after selection.** Both `e16` rows: `selected` is 1,
   view 1 is still locked, the tree has two leaves, and the echo token
   is `failed`.
7. **Another buffer.** The `s-two` row: one leaf, the current buffer
   is `/cwd/a.txt`, `(buffers before)` is empty, and `(buffers after)`
   holds one buffer named `/cwd/b.txt`.
8. **Small screen.** The `s40b` row.
9. **Unchanged presses.** Every row of §5's unchanged table, by
   whole-session equality. For the `(s0 split-below)` name presses,
   also assert `selected` is 0. For `e17`, first assert the prompt is
   present, `(e17 completion-lines)` has length 2, and
   `((e17 root-rect 80 24) rows)` is 21. For `e19q`, first assert
   `quit`.
10. **Short leaf.** The `(s0 ensure-visible 80 1)` press places
    `(0,5)`.
11. **Keys still work.** The sequence at the end of §5.
12. **Runner.** The four-frame script of §6, with the exact event
    list and the fourth frame equal to the first. Assert the third
    frame holds exactly two groups, on rows 11 and 22. Do not assert
    the frames' full bytes beyond that equality; 000's file owns the
    frame bytes.

### Changes to existing tests

Exactly two files change:

- `tests/aloemacs/mode-buttons-paint.rkt`: item 8 becomes the press
  contract for `s0` with `mouse down left 75 22`, `77 22`, and
  `79 22`: equal to `(s0 split-below)`, `(s0 split-right)`, and
  `(s0 delete-window)`. Nothing else in the file changes.
- `tests/aloemacs/window-bars-one-view.rkt`: the method-shape
  retarget described under "May create or edit".

`tests/aloemacs/mouse.rkt` stays green unedited. If any other test
fails, the product is wrong; fix the product. Do not edit a fixture,
geometry, or another expectation to force the suite green.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/mode-buttons-paint.rkt tests/aloemacs/mode-buttons-press.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

```sh
git diff --check
```

Every agent test run includes `TMPDIR=/tmp`, `-j 4`, and `-y`. Do
not commit `compiled/`. The product edit is `.aloe` only and needs no
rebuild before launch. The implementer does not need a TTY.

The checkpoint is complete when:

- both test commands pass and `git diff --check` is clean
- the only product changes are `label-at` on `AloemacsModeLine`,
  `press-mode-line`, `select-view`, and `button-send` on the session,
  the one replaced arm of `press-at`, and optionally `place-in`
  rewritten over `select-view` with its result unchanged
- `file.aloe` is still ASCII bytes
- the existing-test changes are limited to the two files above
- `tests/aloemacs/mode-buttons-press.rkt` exists and covers the
  twelve items above

Report the files changed and the verification output. Then stop.
This closes the series; there is no 002.

## Hand check

The hand check is the human's, after the tests are green. Run it on
a real UTF-8 terminal with 256 colors, at least 80 by 24:

```sh
cp SPEC.md /tmp/mode-buttons.txt
```

```sh
racket host/racket/aloemacs-run.rkt /tmp/mode-buttons.txt
```

1. The mode line ends ` ↕ ↔ ×` inside the lighter bar, with × in the
   last column. The echo row is blank.
2. Click ↕. Two windows are stacked. Both bars end with the three
   labels; the upper bar is lighter.
3. Click ↔ on the lower bar. The lower window splits right. The
   lower-left window is selected and its bar is lighter.
4. Click × on the upper bar. The upper window closes. The two lower
   windows fill the screen, and the left one is selected.
5. Click the name on the unselected window's bar. Nothing changes.
6. Click × on the selected window. One window remains. Click × again.
   The echo row shows `failed: /tmp/mode-buttons.txt`.
7. Escape quits. Nothing is written. In the shell, mouse selection
   works again.

A failure of the check sends the work back. It does not add a
feature.

## Non-goals

- Spec §3's non-goals: drag-to-select, mode `1002`, painting the
  mark, hover, wheel, the middle and right buttons; dragging a
  divider, painting `│` around the labels, or any fourth glyph; a
  click on a path component, the directory browser, describe, jump to
  definition, or a menu beyond these three; a new command
  constructor, a keymap change, or sending `C-x l`; changing
  `split-below`, `split-right`, or `delete-window`, including the lock
  refusal inside delete and the four-row below minimum; placing the
  point from a mode-line press, or installing the click column as the
  point; a new face, a per-button color, or a change to LIGHT, DARK,
  or PLAIN; window-bars 001's documents, idle echo, completion, or
  completion page; a display-width table, `wcwidth`, a grapheme rule,
  or any Unicode exception beyond these three code points; a new
  class, a stored mode-line field, a picture field, or an editor
  field; a Term method, a runner change, a new mouse mode, or a change
  to the mouse string; a kernel message, a `SPEC.md` row, a `lib/`
  method, a Text method, or a `CHECKPOINTS.md` entry.
- Any change to what 000 paints. This checkpoint changes no frame
  byte.
- Do not edit a spec, a charter, a README, or another checkpoint. Do
  not issue aloemacs-mouse 001. Do not start Boids.
