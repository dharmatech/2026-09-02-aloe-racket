# aloemacs mode-buttons specification

**Status: Accepted for checkpoint planning.** Written by the designer
from [`charter.md`](charter.md). The human authorized the manager to
proceed if the spec was ready. The manager reviewed its code seams,
its §6.2 examples, and its §6.3 inventory against the current tree
and found it ready; the inventory is restated from a scratch run in
[`checkpoints/000-paint.md`](checkpoints/000-paint.md). While writing
[`checkpoints/001-press.md`](checkpoints/001-press.md) the manager
corrected one row of the §5.4 table: at width 7 the labels are at
indices 2, 4, 6, as the formula and the pinned row `u ↕ ↔ ×` already
said. Not Aloe law. Not a checkpoint. Not an implementer assignment.

This file is the complete design input for the checkpoint manager
and the implementers. They do not need the charter or the design
conversation. [`SPEC.md`](../../../../../SPEC.md) remains Aloe
language law. [`docs/workflow.md`](../../../../workflow.md) governs
roles and review. The accepted mouse specification remains the
authority for the mouse string, `handle-event`, the prompt, search,
and prefix refusals, and every cell that is not one of the three
label cells. The accepted mode-line specification remains the
authority for the name row at widths below 7. The accepted
window-bars specification remains the authority for the bar wrap
and its colors. This file is the authority for the mode-line row at
width 7 or more and for a left press on a label cell.

## 1. Opening

A mode line at least seven columns wide ends with the six characters
` ↕ ↔ ×`. The buffer name and its dash fill stop six columns early to
make room. A left press on ↕ selects that window and sends
`split-below`. A left press on ↔ selects it and sends `split-right`.
A left press on × selects it and sends `delete-window`. Those three
sends stay exactly as they are, refusals included. A narrower mode
line keeps today's text. A leaf shorter than two rows, the echo row,
a completion row, and a vertical bar gain no labels. Every other
mode-line press leaves the session as it was.

The charter left these names to this spec. They are decided:

| What | Decision | Section |
|---|---|---|
| The six-character group | `(line buttons) -> String`, the constant ` ↕ ↔ ×`, on `AloemacsModeLine` | §5.1 |
| When a row shows it | `(line buttons? width) -> Bool`, true exactly when `width >= 7` | §5.2 |
| Today's row | `(line name-row name width) -> String`, the accepted mode-line spelling, under the body `row` has today | §5.2 |
| The mode-line text | `(line row name width)` keeps its signature and both call sites. It is `name-row` at `width - 6` followed by `buttons` when `buttons?` holds, and `name-row` at `width` otherwise | §5.2 |
| Which label a cell is | `(line label-at width index) -> String`: `"↕"`, `"↔"`, `"×"`, or `""` | §5.4 |
| The selection before the send | Session `(select-view view) -> (Option (AloemacsSession H))`: `Some self` for the selected view, `Some` of the store-then-`enter-view` handoff for another view, `None` when the stored tree lacks the view | §5.5 |
| The send | Session `(button-send label) -> (AloemacsSession H)`: `split-below`, `split-right`, or `delete-window`, chosen by the label | §5.5 |
| Where the press is classified | The mode-line arm of `press-at`, which today returns the receiver, sends `(self press-mode-line view rect (column - (rect x)))` | §5.5 |
| How the glyphs are spelled in `file.aloe` | The escapes `\u2195`, `\u2194`, and `\u00d7`, so the file stays ASCII bytes. Tests may spell them either way | §5.1 |
| Focused tests | `tests/aloemacs/mode-buttons-paint.rkt` for 000, `tests/aloemacs/mode-buttons-press.rkt` for 001 | §6.4, §7.4 |

There were no open product questions in the charter. Its locked
decisions are restated below and stay closed.

## 2. Checkpoint series

Series identity is **aloemacs-mode-buttons**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Checkpoint
numbers are three digits, start at 000, and are never renumbered.
The slug is lowercase words separated by hyphens.

There are two checkpoints, in this order:

| Identity | File | What it proves |
|---|---|---|
| **aloemacs-mode-buttons 000** | `checkpoints/000-paint.md` | `row` at width 7 or more is today's row at `width - 6` followed by the group; narrower widths keep the strings already pinned. The one-view frame and every tall split leaf paint the group inside the bar wrap the row already has. A left press on a label still leaves the session unchanged |
| **aloemacs-mode-buttons 001** | `checkpoints/001-press.md` | A left press on each label of an unselected window matches entering that window and then the send. A label on the selected window matches the send alone. A refused delete and a refused split match that send's refusal, with the window selected first. A press off a label, a release on a label, and a press during a prompt, a search, or a pending prefix leave the session unchanged |

Paint first, then the press. After the human accepts this spec, the
manager writes **000 only**, then stops. Human review of 000's
implementation precedes 001. Do not issue both together.

000 changes one product file in one class and migrates goldens
through each test file's existing row helper, plus the literal rows
and the one method-shape assertion §6.3 lists. 001 changes one
product file in two classes and adds one focused test. If the manager's inventory shows that 000 cannot fit
one implementer conversation **because of the golden migration**,
and only then, split paint in this order: 000 is the row formula and
the one-view frame, 001 is `checkpoints/001-split-paint.md`, the
split leaves, and the press becomes 002 `checkpoints/002-press.md`.
§6.5 says how the two paint halves divide. The added number
introduces no other feature. If the size problem is anything else,
return the finding for a spec revision instead.

Do not take a global checkpoint number. Do not add a
`CHECKPOINTS.md` entry. Do not edit the parent map
[`../README.md`](../README.md), [`../explorations.md`](../explorations.md),
or [`../discussion.md`](../discussion.md). Do not issue
aloemacs-mouse 001. Do not edit the mouse, mode-line, window-bars,
window-point, windows, or safe-cells specs, charters, or checkpoints.

### 2.1 Predecessors

This series reads the accepted specs and the current program. It
does not wait for the open human reviews of windows and of the mode
line. A defect in a predecessor that blocks a button stops the
implementer; the fix belongs to that series.

| What | The state this series starts from |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 is implemented. The tree is `Leaf`, `Below`, and `Right`. Rectangles are 0-based `(x, y, columns, rows)`. A Right split reserves one column and paints `|` on every row. Session `split-below`, `split-right`, and `delete-window` exist. A refused split or delete answers with the echo token `failed` when neither a prompt nor a search is active, and leaves the tree. Delete of the sole leaf and delete of a locked leaf are refusals |
| [`../mode-line/`](../mode-line/) | aloemacs-mode-line 000–001 is implemented. `(AloemacsModeLine new)` is fieldless. `(line row name width)` is `(name append " ")` taken to `width`, then `-` fill; `""` at a non-positive width. A leaf of height at least 2 paints that row on its last row. A shorter leaf is all text. The echo row stays the last screen row |
| [`../window-bars/`](../window-bars/) | aloemacs-window-bars 000–001 is implemented. `AloemacsWindowRect` `top` and `bottom` spend no rule row, and a below split needs four rows. `built-rows` paints each tall leaf's row through `bar` with `(view id) = selected`, LIGHT on the selected view and DARK on every other; `single-frame` paints its one bar LIGHT. The bar wrap and its colors stay with that series |
| [`../window-point/`](../window-point/) | aloemacs-window-point 000 is implemented and accepted. Entering a window stores the departing view through `AloemacsWindows with-buffer`, then `enter-view` installs the entered view's point and origin. `enter-view` has no lock check |
| [`../mouse/`](../mouse/) | aloemacs-mouse 000 is implemented and accepted, and is the whole series. `(term read-event)` yields one string such as `mouse down left 4 22`. `handle-event` sends a mouse string to `handle-mouse`, which refuses during a search, a prompt, or a pending prefix, then classifies a left press through `press-at`: echo row, completion row, mode line, text, elsewhere. The mode-line arm returns the receiver. The text arm is `place-in`, which uses the handoff above and then `place-at` |
| [`../safe-cells/`](../safe-cells/) | `editor safe-cells` turns codes 0–31 and 127 into one space each and copies every other character. The three labels are not controls |
| Neighbors | Idle echo, completion, and completion page are in the tree. They are frame inputs this series preserves. `root-rect` shrinks by `completion-row-count`; the echo payload is blank while idle beside a tall selected leaf. They are not predecessors and this series does not edit their documents |
| The runner | [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt) reads columns and rows, fits, records pictures, writes the frame as one `String`, then blocks on `(term read-event)` and sends that string to `handle-event`. Racket and `tui-term` write the frame as UTF-8 |

At issuance, `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs` passes
589 tests. The working tree holds uncommitted document edits only:
the parent map and this folder.

## 3. Product boundary

The program, after this series:

- `(line row name width)` at `width >= 7` is today's row at `width - 6` followed by ` ↕ ↔ ×`. At `width <= 6` it is today's row.
- Every mode line the program paints goes through `row`, so a one-view frame, a fallback frame, and every tall split leaf at least 7 columns wide end with the group, inside the LIGHT or DARK bar the row already has.
- A left press on ↕, ↔, or × selects that window, through the handoff the click already uses, and then sends `split-below`, `split-right`, or `delete-window`. The session is the one that sequence returns. The press places no point.
- A left press on any other mode-line cell, a release anywhere, a middle or right button anywhere, and any mouse string during a prompt, a search, or a pending prefix leave the session as it was.
- The echo row, a completion row, a vertical bar, and a leaf shorter than two rows gain no labels and keep the mouse spec's results.

Out of scope, for the implementer as well as the manager:

- Drag-to-select, mode `1002`, painting the mark, hover, wheel, and the middle and right buttons
- Dragging a divider, painting `│` around the labels, or any fourth glyph
- A click on a path component, the directory browser, describe, jump to definition, or a menu beyond these three
- A new command constructor, a keymap change, or sending `C-x l`
- Changing what `split-below`, `split-right`, or `delete-window` do, including the lock refusal inside delete and the four-row below minimum
- Placing the point from a mode-line press, or installing the click column as the point
- A new face, a per-button color, or a change to LIGHT, DARK, or PLAIN
- Window-bars 001's documents, idle echo, completion, or completion page
- A display-width table, `wcwidth`, a grapheme rule, or any Unicode exception beyond these three code points
- A new class, a stored mode-line field, a picture field, or an editor field
- A Term method, a runner change, a new mouse mode, or a change to the mouse string
- Editing the mouse, mode-line, window-bars, window-point, windows, or safe-cells documents, or the parent map
- A kernel message, a `SPEC.md` row, a `lib/` method, a Text method, or a `CHECKPOINTS.md` entry

## 4. Host and layout

Language is Aloe for the editor and Racket for the tests. The
project root is `/home/dharmatech/journal/2026-09-02-aloe-racket`.
The design folder receives this spec and later the checkpoints. The
program stays in the tree below.

| May edit | What changes |
|---|---|
| `examples/aloemacs/file.aloe`, `AloemacsModeLine` | 000: `name-row`, `buttons`, `buttons?`, and the new body of `row`. 001: `label-at` |
| `examples/aloemacs/file.aloe`, `(AloemacsSession H)` | 001 only: the mode-line arm of `press-at`, `press-mode-line`, `select-view`, `button-send` |
| `tests/aloemacs/mode-buttons-paint.rkt` | 000: new focused proof |
| `tests/aloemacs/mode-buttons-press.rkt` | 001: new focused proof |
| Existing files under `tests/aloemacs/` | 000: the golden migration and the method-shape retarget in §6.3. 001: one item of 000's focused file and the `label-at` shape in `window-bars-one-view.rkt` (§7.3) |

When another file or another class looks necessary, the implementer
stops and sends the checkpoint back.

Leave these alone: `examples/aloemacs/editor.aloe`,
`examples/aloemacs/main.aloe`, everything under `host/racket/`,
`lib/`, `aloe/`, `bin/`, `SPEC.md`, `CHECKPOINTS.md`, every test
outside `tests/aloemacs/`, `tests/aloemacs/mouse.rkt` (its mode-line
presses are at column 0, the name, and stay inert), and every
document under `docs/` other than this folder's checkpoints.

Shapes stay exact. The ordered `define-class` list of `file.aloe` is
unchanged; the fifteen tests that pin it need no edit.
`AloemacsModeLine` keeps `(fields)`. `AloemacsView`,
`AloemacsLeafPicture`, `AloemacsWindowRect`, `AloemacsWindows`,
`AloemacsBuffer`, `AloemacsEditor`, and the session keep their
fields. `AloemacsCommand` keeps its constructors. The keymap tables
keep their bindings. `fill`, `bar`, `light`, `dark`, and `plain` keep
their results.

From the project root, tests are:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

`<paths>` is the focused file, then `tests/aloemacs`. `compiled/`
stays gitignored. Product edits in this series are `.aloe` only, so
a launch needs no rebuild; the test command rebuilds what it runs.
The hand check in §8 is the human's, after the tests are green.

The editor loads through `examples/aloemacs/main.aloe`, which loads
`file.aloe`, which loads `editor.aloe`. String `len`, `take`,
`drop`, `append`, `=`, and `>=` on `Int` are the only sends the new
methods need. This series adds no kernel message and no `lib/`
method.

## 5. The layer

### 5.1 The group

The group is these six characters, in this order:

| Index in group | Character | Code point | Role |
|---:|---|---|---|
| 0 | space | U+0020 | not a button |
| 1 | ↕ | U+2195 | `split-below` |
| 2 | space | U+0020 | not a button |
| 3 | ↔ | U+2194 | `split-right` |
| 4 | space | U+0020 | not a button |
| 5 | × | U+00D7 | `delete-window` |

Each arrow and the multiplication sign is one character and one
cell. Aloe `String` `len` counts it as one, `take` and `drop` step
over it as one, and that count is the column count. The parent map
locks this: these three code points are the one-cell exception to
the ASCII layout. This series adds no width table.

The three characters are ordinary cells of the row. They are not
controls, so `safe-cells` copies them unchanged. The bar wrap colors
the whole row, group included, with the LIGHT or DARK sequence the
row already has. No per-button sequence is added. The `│` that the
Chez editor paints around its labels is not painted.

In `file.aloe` spell the group with escapes, so the file stays ASCII
bytes and the reader does not depend on the source encoding:

```aloe
(buttons () String
  " \u2195 \u2194 \u00d7")
```

Aloe's reader produces the same `String` from that spelling and from
the literal glyphs; `(" \u2195 \u2194 \u00d7" = " ↕ ↔ ×")` is true.
Every label literal in `file.aloe` uses the same escapes: the group
in `buttons`, and the one-character strings `"\u2195"`, `"\u2194"`, and
`"\u00d7"` that `label-at` returns and `button-send` compares. The
sketches in this spec are written that way and can be pasted as
they are. Racket tests may use either spelling. Racket `string-length` and
`substring` count characters, and the runner doubles already decode
output with `bytes->string/utf-8`, so a row of width `w` is `w`
characters on both sides.

### 5.2 The row

`AloemacsModeLine` keeps `(fields)` and its declared position. It
gains three sends and `row` gains a new body. Nothing else on the
class changes.

```text
(line buttons)  -> String   ; the six characters of §5.1
(line buttons? width) -> Bool
(line name-row name width) -> String
(line row name width) -> String
```

```text
buttons?(width) = width >= 7

name-row(name, width) = ""                                    when width <= 0
                      = clipped ++ fill(width - clipped.len)  otherwise,
                        where clipped = (name ++ " ") take width

row(name, width) = name-row(name, width - 6) ++ buttons   when buttons?(width)
                 = name-row(name, width)                    otherwise
```

`name-row` is the accepted mode-line spelling, with the body `row`
has today, under a new name. Every result the mode-line spec pins
for `row` is now a result of `name-row`, at every width. `row` keeps
its signature and both call sites. A sketch:

```aloe
(buttons? (width Int) Bool
  (width >= 7))

(name-row (name String) (width Int) String
  (if (width <= 0)
      ""
      (let ((clipped ((name append " ") take width)))
        (clipped append (self fill (width - (clipped len)))))))

(row (name String) (width Int) String
  (if (self buttons? width)
      ((self name-row name (width - 6)) append (self buttons))
      (self name-row name width)))
```

For a positive width the result has exactly `width` characters. At
`width >= 7` the last six characters are the group, so ↕ is at index
`width - 5`, ↔ at `width - 3`, and × at `width - 1`. The name's
first character, or a space for an empty name, is at index 0. The
buffer names the program produces are `"untitled"` or a path, so the
leftmost column of a row that shows the labels is a character of
that name.

Pinned spellings. Quotes delimit the row and are not painted. These
are raw rows, before safe cells:

| Name | Width | `row` |
|---|---:|---|
| `untitled` | 6 | `untitl` (today's row) |
| `untitled` | 7 | `u ↕ ↔ ×` |
| `untitled` | 8 | `un ↕ ↔ ×` |
| `untitled` | 9 | `unt ↕ ↔ ×` |
| `untitled` | 12 | `untitl ↕ ↔ ×` |
| `untitled` | 14 | `untitled ↕ ↔ ×` |
| `untitled` | 15 | `untitled  ↕ ↔ ×` |
| `untitled` | 16 | `untitled - ↕ ↔ ×` |
| `untitled` | 20 | `untitled ----- ↕ ↔ ×` |
| `/tmp/file.aloe` | 12 | `/tmp/f ↕ ↔ ×` |
| `/cwd/a.txt` | 8 | `/c ↕ ↔ ×` |
| `/cwd/a.txt` | 80 | `/cwd/a.txt `, then 63 dashes, then ` ↕ ↔ ×` |
| `/a` | 8 | `/a ↕ ↔ ×` |
| `/a` | 9 | `/a  ↕ ↔ ×` |
| `-\|+` | 7 | `- ↕ ↔ ×` |
| `` (empty) | 7 | `  ↕ ↔ ×` |

At width 15 the name's separator space and the group's leading
space are adjacent. At width 14 the separator does not survive the
clip, so one space separates `untitled` from ↕. Both follow from the
formula and are not defects. Do not reserve a dash, trim a space, or
move the group.

Controls stay raw in `name-row` and in `row`; the paint site applies
safe cells to the whole row, as today. With the name
`"a\u001b[31m\t\r\n\u0001\u007fZ"` at width 15, the raw row is
`"a\u001b[31m\t\r\n ↕ ↔ ×"` and the painted row is
`"a [31m    ↕ ↔ ×"`: nine cells of name, then the group. A control in
a name cannot move or recolor a label.

### 5.3 Where the labels are painted

Both paint paths already call `row` and keep calling it with the
arguments they pass today:

- `single-frame`, for the one-view frame and the too-small-tree fallback, sends `((AloemacsModeLine new) row ((self current-buffer) name) columns)`, where `columns` is the screen width.
- `built-rows`, for each tall split leaf, sends `((AloemacsModeLine new) row (buffer name) (rect columns))`, where `rect` is that leaf's rectangle.

Each then applies `editor safe-cells` and wraps the shown row in
`bar` with `selected?` as today: `#t` in `single-frame`,
`((view id) = selected)` in `built-rows`. So the painted mode line
is LIGHT or DARK, the name cells, the group, then PLAIN, and the
only change in the bytes is inside the visible cells. The width each
path passes is the width `buttons?` and `label-at` use. A right-hand
leaf receives `rect.columns`, not the screen width, so its × is in
the leaf's last column, immediately before the `|` that `right-rows`
appends after PLAIN.

The labels are painted on the selected bar and on every unselected
bar. They are painted while a prompt, a search, or a prefix is
pending, because the row never reads those. The echo row, a
completion row, and the vertical bar are not mode lines and are
unchanged. A leaf shorter than two rows has no mode line and no
labels. A mode line narrower than 7 columns is today's row.

The buttons are derived from the name and the width.
`AloemacsLeafPicture.matches?` already keys on `name` and `columns`,
so a recorded leaf picture stays valid exactly when its row would be
the same. The picture gains no field. `record-pictures` and
`with-pictures` are unchanged.

The fallback frame is the one-view frame of the selected buffer at
the full screen width, as today, so it shows one group at the
screen's right edge. Direct editor `frame` still has no mode line.

### 5.4 Label cells

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
anything happens is the session's decision in §5.5. The three
results are the characters of §5.1, one character each. An
implementation may read them out of `buttons`; the table is the
contract.

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

The screen column of a label is the leaf rectangle's `x` plus the
index. The row is the leaf's last row, `y + rows - 1`, when the leaf
is at least two rows tall. That is the test `press-at` already
applies before it reaches the mode-line arm. Do not hard-code a row
number or a column.

### 5.5 The press

`handle-event` and `handle-mouse` are unchanged. Quit still wins
before the string is examined. A search, a prompt, or a pending
prefix still refuses every mouse string before the cell is
classified. Only a string with `event?`, `down?`, and `left?`
reaches `press-at`.

`press-at` keeps its order: echo row, completion row, then
`view-at`, then `rect-for`, then the mode-line test, then text. Its
mode-line arm today is `(self unchanged)`. That arm becomes:

```aloe
(self press-mode-line view rect (column - (rect x)))
```

Nothing else in `press-at` changes. `view` is the leaf `view-at`
found, `rect` is its rectangle from `rect-for` on the same root, and
`column` is the pressed screen column. Three session sends are
added:

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
`place-at`, no `ensure-visible` beyond the fit `split-window`
already performs. In particular:

- **Selected window.** `select-view` is `Some self`, so the result is the bare send on the receiver: `(self split-below)`, `(self split-right)`, or `(self delete-window)`.
- **Another window.** The handoff is the one `place-in` already uses, word for word: `with-buffer` stores the departing view's live point and origin, `find-view` finds the pressed view in that stored tree, and `enter-view` installs its stored point and origin and selects it. Then the send runs on the entered session. The departed view keeps what the store wrote. `enter-view` on another buffer makes that buffer current and applies its existing echo, search, and pending resets; on the same buffer it keeps them. A locked window can be selected; `enter-view` has no lock check and this path adds none.
- **The point.** The click column is never installed. The point after the press is whatever the send leaves: the entered view's stored point for a split or a same-buffer entry, and the promoted sibling's stored point for a successful delete.
- **Fit.** A successful split fits once, inside `split-window`, as it does from `C-x 2` and `C-x 3`. A successful delete does not fit; the runner's next `ensure-visible` is the fit, as after `C-x 0`.
- **Echo.** The token is whatever the send writes under the windows spec's rules: a successful split stores `""`, a refused split or delete stores `"failed"`, and a successful delete stores `""` on a buffer change and keeps the token otherwise. The prompt and search rows of that table cannot apply, because `handle-mouse` refused those sessions earlier.
- **Refusals.** Delete of the only window, delete of a locked window, a split of a locked window, a below split of a leaf shorter than four rows, and a right split of a leaf narrower than three columns are the sends' existing refusals. Selection still happens first: after × on an unselected locked window, that window is selected and the echo token is `failed`.
- **Missing view.** When `find-view` on the stored tree returns `None`, the session is unchanged and the send does not run. Program-created trees never miss; the arm mirrors `place-in`.

`place-in` keeps its result. Rewriting it over `select-view`, with
`(None () self)` and `(Some (s) (s place-at line column))`, is
allowed and not required; `tests/aloemacs/mouse.rkt` is the proof
either way.

The classification uses the geometry the last fit stored, as the
mouse spec says. In a fallback frame that geometry is the nominal
tree's, as it already is for a text press. This series adds no rule
there.

### 5.6 Presses that leave the session as it was

These return the receiver, so the point, the selection, every view's
stored point and origin, the echo token, the text, the mark, the kill
ring, the undo history, the prompt, the search, and the pending
prefix all stay:

- a left press on a mode line's name cells or dash fill, including on an unselected window
- a left press on any of the three spaces in the group: indices `width - 6`, `width - 4`, and `width - 2`
- a left press on a mode line narrower than 7 columns, which has no label cells
- a left release on a label, or anywhere else
- a middle or right button, pressed or released, anywhere
- any mouse string while `searching` is true, while the prompt is present, or while `pending` is present, including one aimed at a label
- any mouse string after quit

A leaf shorter than two rows has no mode line, so a press on its last
row is a text press under the mouse spec and places the point. The
echo row, a completion row, and a vertical bar keep the mouse spec's
results. The prompt, search, and prefix refusals stay in
`handle-mouse`, in front of the cell test. A refused near-miss such
as `mouse down left 075 22` is a key, as today.

### 5.7 What stays in place

The keymap tables gain no binding. `AloemacsCommand` gains no
constructor. `C-x 2`, `C-x 3`, `C-x 0`, `C-x o`, and `C-x l` are
unchanged. `split-below`, `split-right`, `delete-window`,
`split-window`, `delete-refused`, `enter-view`, `other-window`,
`with-buffer`, `with-editor`, `place-in`'s result, `place-at`,
`handle-event`, `handle-mouse`, `view-at`, `rect-for`, `contains?`,
`root-rect`, `completion-row-count`, `frame`, `single-frame`,
`multi-frame`, `built-rows`, `right-rows`, `record-pictures`, the
echo row, and the completion rows are unchanged, apart from the one
arm in `press-at`.

Term, the runner, `safe-cells`, `AloemacsMouse`, the mouse string,
mode `1000`, and SGR `1006` are unchanged. The runner enables no new
mouse mode. The frame is still one `String`. LIGHT, DARK, PLAIN,
and the Below division stay with window bars. `Text` gains no
method. `SPEC.md` gains no row. The kernel gains no message.

The accepted mouse spec's region table says a left press on a mode
line places nothing. That stays true: a label press places nothing
and runs a window command instead. This spec is the authority for
that cell.

## 6. Layer 000 — paint

### 6.1 Product

Add `buttons`, `buttons?`, and `name-row` to `AloemacsModeLine`, and
give `row` the body in §5.2. Both call sites, in `single-frame` and
`built-rows`, are unchanged. The session is unchanged. `label-at`
and the press belong to 001; a left press on a label still returns
the receiver in 000.

### 6.2 Examples

An empty untitled buffer at 12 columns and 4 terminal rows, idle.
Today's bytes and 000's bytes differ only in the mode row's cells:

```text
today: "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[1;1H\e[?25h"
000:   "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitl ↕ ↔ ×\e[0m\e[4;1H\e[1;1H\e[?25h"
```

The same buffer at 7 columns and 4 rows paints `u ↕ ↔ ×` in the bar.
At 6 columns it paints `untitl`, today's bytes.

Two stacked views of one buffer, from the window-bars spec: terminal
8 by 6, root 8 by 5, path `/a`, lines `one`, `two`, `three`, `four`,
`Below(Leaf view 0, Leaf view 1)`, view 0 selected at origin `(0,0)`
with point `(0,0)`, view 1 at origin `(2,0)`. Rectangles are
`(0,0,8,3)` and `(0,3,8,2)`. Each bar is `/a ↕ ↔ ×`:

```text
000:   "\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a ↕ ↔ ×\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a ↕ ↔ ×\e[0m\e[6;1H\e[1;1H\e[?25h"
```

The window-bars spec's mixed nesting at 9 by 6,
`Right(Below(view 0, view 1), view 2)`, has leaves 4 columns wide.
Every one of its rows, `"abcd|HIJ "` through `"/a -|/b -"`, is
unchanged, byte for byte. That is the narrow case.

One view at 80 by 24 on `/cwd/a.txt`: row 22 is LIGHT,
`/cwd/a.txt `, 63 dashes, ` ↕ ↔ ×`, PLAIN. ↕ is at column 75, ↔ at
77, × at 79. After `split-right`, the left leaf is `(0,0,40,23)` and
its row 22 is `/cwd/a.txt `, 23 dashes, ` ↕ ↔ ×`, with × at column
39, then PLAIN and `|` at column 40; the right leaf is
`(41,0,39,23)` and its row is `/cwd/a.txt `, 22 dashes, ` ↕ ↔ ×`,
with × at column 79. After `split-below` instead, both leaves are 80
wide and their rows 11 and 22 each end at column 79.

### 6.3 Migration

The failing list after the product edit is the inventory. This
section is the search at issuance; line numbers are approximate.
Search again before fixing the checkpoint's scope.

**Row helpers.** Each of these files builds its expected mode row
with a local helper: `label = clip(name ++ " ", w)`, then `-` fill.
The helper gains the group: when `w >= 7`, that spelling at `w - 6`
followed by the group; otherwise as today. One edit per file. Spell
the group as a test-local literal, `" ↕ ↔ ×"` or
`" \u2195 \u2194 \u00d7"`. Never build an expectation by sending
`row`, `name-row`, `buttons`, `bar`, or a composer.

**Method shapes.** `tests/aloemacs/window-bars-one-view.rkt`, near
lines 187–191, reads `file.aloe` as data, pins the declared shapes of
`bar`, `row`, and `fill`, and then requires every other
`AloemacsModeLine` method to take no arguments and return `String`.
`buttons` satisfies that; `name-row` and `buttons?` do not. 000
retargets the assertion: pin `(name-row (name String) (width Int) String)`
and `(buttons? (width Int) Bool)` beside `row` and `fill`, exclude
both from the zero-argument loop, and keep that loop for `buttons`,
`light`, `dark`, and `plain`. 001 adds
`(label-at (width Int) (index Int) String)` to the pinned shapes and
to the exclusion (§7.3). The `bar` ownership loop in the same test
is unchanged.

| Helper | Files |
|---|---|
| `mode-row` | `buffer-session.rkt`, `buffer-value.rkt`, `echo-runner.rkt`, `echo-session.rkt`, `keymap-prefix.rkt`, `keymap-runner.rkt`, `minibuffer-session.rkt`, `minibuffer-value.rkt`, `prompt-commands-find-file.rkt`, `prompt-commands-save-as.rkt`, `prompt-commands-select-buffer.rkt`, `runner-check.rkt`, `safe-cells.rkt`, `search-session.rkt`, `viewport-runner.rkt`, `completion-session.rkt`, `windows-state-foundation.rkt`, `windows-delete-and-other.rkt`, `windows-lock.rkt`, `windows-split.rkt`, `windows-layout-and-rendering.rkt`, `window-point.rkt` |
| `mode` | `idle-echo.rkt`, `completion-frame.rkt`, `completion-page-frame.rkt`, `mode-line-split-views.rkt`, `window-bars-split.rkt` |
| `name-row` | `mode-line-one-view.rkt` |
| `spelled`, under `mode` | `window-bars-one-view.rkt` |

**Literal rows.** These files also pin wide rows as literals, by
hand. Each literal becomes the §5.2 spelling at its width:

| File | Lines | Today | 000 |
|---|---|---|---|
| `mode-line-row.rkt` | 68–69, 74 | `("untitled" 8 "untitled")`, `("untitled" 9 "untitled ")`, `("untitled" 12 "untitled ---")`, `("/cwd/a.txt" 8 "/cwd/a.t")`, the control name at 15 ending `Z --` | `"un ↕ ↔ ×"`, `"unt ↕ ↔ ×"`, `"untitl ↕ ↔ ×"`, `"/c ↕ ↔ ×"`, `"a\u001b[31m\t\r\n ↕ ↔ ×"`. The length assertion still holds |
| `mode-line-one-view.rkt` | 116–119, 123 | an inline clip-and-dash recomputation of `row` on the control name at widths 1, 3, 6, 10, 15, separate from the `name-row` helper; and `(name-row name 15)` is `"a [31m     Z --"` | widths 1, 3, 6 stay; at 10 and 15 the expected raw row is the clip at `width - 6` plus the group, `"a\u001b[3 ↕ ↔ ×"` and `"a\u001b[31m\t\r\n ↕ ↔ ×"`; and `"a [31m    ↕ ↔ ×"` |
| `window-bars-one-view.rkt` | 228–229, 234, 251, 263, 270, 314, 387, 391, 428–429, 474 | `untitled ---` (12), `a [31m -` (8, inside LIGHT and PLAIN), `(mode control 15)`, `/cwd/a -----` (12), `/a ------` (9) | `untitl ↕ ↔ ×`, `a  ↕ ↔ ×`, `a [31m    ↕ ↔ ×`, `/cwd/a ↕ ↔ ×`, `/a  ↕ ↔ ×` |
| `window-bars-split.rkt` | 450, 506, 736–749 | `/a -----` (8), `/b ------` (9), `/cwd/a --` (9) | `/a ↕ ↔ ×`, `/b  ↕ ↔ ×`, `/cw ↕ ↔ ×` |
| `completion-frame.rkt` | 275 | `/a ------` (9) | `/a  ↕ ↔ ×` |
| `mode-line-split-views.rkt` | 186, 345 | `-\|+ ---` (7), `/a ------` (9) | `- ↕ ↔ ×`, `/a  ↕ ↔ ×` |
| `windows-layout-and-rendering.rkt` | 281–282, 383–384 | `untitle` (7) | `u ↕ ↔ ×` |
| `windows-lock.rkt` | 372 | `/cwd/a.tx` (9) | `/cw ↕ ↔ ×` |
| `windows-split.rkt` | 376, 391, 398–400, 413, 422, 426, 437, 459, 465, 570, 598, 671, 675, 679 | `untitle` (7), `/short ` (7), `untitled ` (9), `/cwd/a.tx` (9) | `u ↕ ↔ ×`, `/ ↕ ↔ ×`, `unt ↕ ↔ ×`, `/cw ↕ ↔ ×` |
| `runner.rkt` | 99, 102 | `untitled` (8) inside a whole frame | `un ↕ ↔ ×` |
| `file-runner.rkt` | 17, 20, 23, 26 | `untitled`, `/cwd/a.t`, `/cwd/new` (8) inside whole frames | `un ↕ ↔ ×`, `/c ↕ ↔ ×`, `/c ↕ ↔ ×` |

Rows narrower than 7 stay: `unti`, `/a -`, `unt`, `/cwd`, `/sho`,
`/cwd/` in `file-session.rkt`, and every width-4 split row. Visible
width assertions, such as `rows!` in `mode-line-split-views.rkt`,
still hold because each row keeps exactly `w` characters. Keep every
whole-frame assertion; do not replace one with a substring check.
Keep every fit result, rectangle, refusal, cursor, and Fs count
unchanged; 000 changes cells only. `tests/aloemacs/mouse.rkt` and
`tests/parenthetical-construction/session.rkt` paint no mode row and
need no edit.

### 6.4 Focused proof

Write `tests/aloemacs/mode-buttons-paint.rkt` first and watch it
fail. It uses a checked driver, loads `file.aloe` directly where it
needs no host and `main.aloe` with an injected `fs-host` where it
frames a session, and does not open a TTY. Expected rows and frames
are test-local literals. Prove:

1. **Types and arities.** `((AloemacsModeLine new) buttons)` types as `String` and rejects an argument. `buttons?` types as `Bool`, rejects zero and two arguments and a `String` argument. `name-row` types as `String` with the same arity and type rejections as `row`. `row` still types as `String`. Read as data, `name-row` is declared `(name String) (width Int) String`, `buttons?` is `(width Int) Bool`, and `buttons`, `light`, `dark`, and `plain` take nothing and return `String`. A fresh checked load of `file.aloe` needs no `fs-host` or `term`, writes nothing to output or error, and keeps the ordered `define-class` list and `AloemacsModeLine`'s `(fields)` exactly as `mode-line-row.rkt` pins them.
2. **The group.** `buttons` has length 6; its characters at indices 1, 3, 5 are U+2195, U+2194, U+00D7 and at 0, 2, 4 are spaces; `(ed safe-cells (buttons))` equals it; the escape spelling and the literal spelling are equal.
3. **The threshold.** `buttons?` is false at -1, 0, 1, 6 and true at 7, 8, 12, 80.
4. **Rows.** `name-row` equals the mode-line spec's table at every width it lists, including `("untitled" 12 "untitled ---")` and the control cases. `row` equals `name-row` at widths -8, 0, 1, 3, 4, 6. `row` equals every row in §5.2's table; assert each string and its length independently. For widths 7, 8, 15, 20, and 80, the last six characters of `row` equal `buttons` and the character at index 0 is the name's first character. The control name at 15 paints as `"a [31m    ↕ ↔ ×"` through `safe-cells`, and the stored name stays raw.
5. **One-view frames.** Both §6.2 one-view frames at 12 by 4, the 7-column frame, and the unchanged 6-column frame; one view at 80 by 24 on a bound path with the group at columns 75, 77, 79 inside LIGHT and PLAIN; the same with echo `saved`, during search, and during a prompt with the cursor on the echo row; a nonzero origin. Each frame has one LIGHT, one PLAIN, and no DARK. On the frames at least 7 columns wide, PLAIN immediately follows ×; the 6-column frame has no label.
6. **Split frames.** The §6.2 stacked frame at 8 by 6 byte for byte. The 9 by 6 mixed frame from the window-bars spec, unchanged. A Right split at 80 by 24 whose left row has × at column 39 followed by PLAIN and `|`, and whose right row has × at column 79. An unselected leaf's group is inside DARK. A Below split whose lower leaf is one row tall paints that leaf as text with no group. Every composed row's visible width is the root width.
7. **Pictures.** On a split session, `record-pictures` then `frame` yields the same bytes as `frame` before recording, and a second `frame` yields them again; the session apart from the pictures is unchanged and there is no Fs effect.
8. **Labels still inert.** On the 80 by 24 session `s0` of `tests/aloemacs/mouse.rkt`, `handle-event` of `mouse down left 75 22`, `mouse down left 77 22`, and `mouse down left 79 22` each return a session equal to the receiver. 001 replaces this item with the completed contract and changes nothing else in this file.
9. **Runner.** A scripted Term double at 12 by 4 drives `x` then `escape` through `run-aloemacs-with-hosts`; the two frames carry `untitl ↕ ↔ ×` in the bar, decoded with `bytes->string/utf-8`, and there is one write per iteration.

Stop with this file and the full aloemacs suite green.

### 6.5 If paint must split

Apply this only under §2's size rule. 000 is then `row`, `name-row`,
`buttons`, `buttons?`, the one-view and fallback frames, and their
goldens, with `built-rows` temporarily sending `name-row` so split
leaves keep today's cells. 001, `checkpoints/001-split-paint.md`,
switches `built-rows` back to `row` and migrates the split goldens.
Neither half adds a send beyond §5.2, and the second half removes
the temporary call. The press is then 002.

## 7. Layer 001 — press

### 7.1 Product

Add `label-at` (§5.4) to `AloemacsModeLine`. Add `press-mode-line`,
`select-view`, and `button-send` (§5.5) to the session, and replace
the `(self unchanged)` of `press-at`'s mode-line arm with
`(self press-mode-line view rect (column - (rect x)))`. Nothing else
changes. `place-in` may be rewritten over `select-view` or left as
it is.

### 7.2 Examples

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

`s0` is the mouse spec's base session:
`((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)`,
with the fs double of `tests/aloemacs/mouse.rkt`. `e16` is
`((((s0 split-below) other-window) toggle-window-lock) other-window)`:
view 0 selected on top, view 1 locked below. `s-two` is
`((((s0 split-below) other-window) find-file-submitted "b.txt") other-window)`:
view 0 selected on `/cwd/a.txt`, view 1 below showing `/cwd/b.txt`.
On a two-leaf tree, `other-window` is the handoff into the other
leaf, so the expected values below are spelled with it. Each row
reads "the press on the left returns a session equal to the
expression on the right":

| Session | Press | Equals |
|---|---|---|
| `s0` | `mouse down left 75 22` | `(s0 split-below)` |
| `s0` | `mouse down left 77 22` | `(s0 split-right)` |
| `s0` | `mouse down left 79 22` | `(s0 delete-window)`, which is `(s0 with-echo "failed")`: the sole window |
| `(s0 with-echo "saved")` | `mouse down left 75 22` | `((s0 with-echo "saved") split-below)`; its echo is `""` |
| `(s0 split-below)` | `mouse down left 79 22` | `(((s0 split-below) other-window) delete-window)`: one leaf, view 0 selected, point `(0,0)` |
| `(s0 split-below)` | `mouse down left 75 22` | `(((s0 split-below) other-window) split-below)`: three leaves, view 1 selected |
| `(s0 split-below)` | `mouse down left 77 11` | `((s0 split-below) split-right)`: the selected upper leaf splits |
| `(s0 split-right)` | `mouse down left 79 22` | `(((s0 split-right) other-window) delete-window)` |
| `(s0 split-right)` | `mouse down left 39 22` | `((s0 split-right) delete-window)` |
| `e16` | `mouse down left 79 22` | `((e16 other-window) with-echo "failed")`: view 1 is selected, still locked, the tree stays |
| `e16` | `mouse down left 75 22` | `((e16 other-window) with-echo "failed")`: a locked view refuses a split |
| `s-two` | `mouse down left 79 22` | `((s-two other-window) delete-window)`: enters the `/cwd/b.txt` window, deletes it, returns to view 0 on `/cwd/a.txt` |
| `((s0 ensure-visible 40 10) split-below)` | `mouse down left 39 8` | `((((s0 ensure-visible 40 10) split-below) other-window) delete-window)` |

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
| `((s0 ensure-visible 9 6) split-right)` | `mouse down left 3 4`, `mouse down left 8 4` | leaves narrower than 7 |
| the prompt session of `mouse.rkt` item 17 | `mouse down left 75 20`, `mouse down left 79 20` | the prompt; the mode line is row 20 under two completion rows |
| `(s0 handle-key "find")` | `mouse down left 75 22` | search |
| `(s0 handle-key "ctrl-x")` | `mouse down left 79 22` | pending prefix |
| the quit session of `mouse.rkt` item 19 | `mouse down left 75 22` | quit |

A leaf shorter than two rows has no labels: on
`(s0 ensure-visible 80 1)`, `mouse down left 79 0` is a text press
and places the point at `(0,5)`, the clamped end of `hello`.

Through the runner at 80 by 24 on `a.txt`, the script `ctrl-x`, `2`,
`mouse down left 79 22`, `escape` writes four frames. The third is a
split frame with two groups, on rows 11 and 22. The fourth equals
the first: one view, the cursor at `1;1`, no echo payload. Each
iteration is `(columns 80)`, `(rows 24)`, `(write frame)`, `flush`,
`(key k)`.

### 7.3 Migration

001 replaces item 8 of `tests/aloemacs/mode-buttons-paint.rkt`, the
inert-label assertions, with the press results of §7.2 for those
three presses, and changes nothing else in that file. It also
extends the method-shape assertion in
`tests/aloemacs/window-bars-one-view.rkt` (§6.3) with
`(label-at (width Int) (index Int) String)`, pinned beside `row`,
`fill`, `bar`, `name-row`, and `buttons?` and excluded from the
zero-argument loop. No other existing test changes. `tests/aloemacs/mouse.rkt` stays green
unedited: its mode-line presses are at column 0. If any other test
fails, the product is wrong; fix the product.

### 7.4 Focused proof

Write `tests/aloemacs/mode-buttons-press.rkt` first and watch it
fail. It uses a checked driver, loads `main.aloe` with the fs double
of `tests/aloemacs/mouse.rkt`, uses `make-term-receiver` and
`run-aloemacs-with-hosts` for the runner item, and does not open a
TTY. "Equals" is `(check actual expected)` through the driver, as
`mouse.rkt` spells `same`. Prove:

1. **Types and arities.** `label-at` types as `String`, rejects one and three arguments and a `String` argument, and is declared `(width Int) (index Int) String` when `file.aloe` is read as data. `select-view` types as `(Option (AloemacsSession H))` on `s0` and rejects zero and two arguments. `button-send` types as the session type and rejects an `Int`. `press-mode-line` types as the session type with three arguments. `press-at`, `handle-event`, and `handle-mouse` keep their types. The ordered `define-class` list and every field inventory are unchanged.
2. **Label cells.** Every row of §5.4's table.
3. **Each label, selected window.** The first four rows of §7.2's press table, plus the point staying `(0,0)`.
4. **Each label, another window.** The `(s0 split-below)` rows for 79 and 75 on row 22, and `(s0 split-right)` rows for 79 and 39. For the delete, also assert one leaf, `selected` 0, and view 0's stored point `(0,0)` and origin `(0,0)`. For the split, assert three leaves and `selected` 1.
5. **Selected window in a split.** `(s0 split-below)` with `mouse down left 77 11`.
6. **Refusals after selection.** Both `e16` rows: `selected` is 1, view 1 is still locked, the tree has two leaves, and the echo token is `failed`.
7. **Another buffer.** The `s-two` row: the result shows `/cwd/a.txt` in one leaf and the buffer zipper still holds both buffers.
8. **Small screen.** The 40 by 10 row.
9. **Unchanged presses.** Every row of §7.2's unchanged table, by whole-session equality. For the `(s0 split-below)` name presses, also assert `selected` is 0.
10. **Short leaf.** The `(s0 ensure-visible 80 1)` press places `(0,5)`.
11. **Keys still work.** After `mouse down left 75 22` on `s0`, `handle-event "x"` inserts `x` at `(0,0)` of the selected upper window and the lower view keeps its stored point; `handle-event "escape"` then sets quit, and a further `mouse down left 79 22` is unchanged.
12. **Runner.** The four-frame script of §7.2, with exact event order and the fourth frame equal to the first.

Stop with both focused files and the full aloemacs suite green.

## 8. Verification, hand check, and acceptance

Each implementer writes the focused test first, sees it fail,
implements one slice, and verifies from the project root.

For **aloemacs-mode-buttons 000**:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/mode-buttons-paint.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

For **aloemacs-mode-buttons 001**:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/mode-buttons-paint.rkt tests/aloemacs/mode-buttons-press.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

Run `git diff --check` as well. The aloemacs suite is the regression
bar. Do not commit `compiled/`. Product edits are `.aloe` only and
need no rebuild before launch.

**Hand check.** After 001, the human runs this on a real UTF-8
terminal with 256 colors, at least 80 by 24. The implementer does
not need a TTY.

```sh
cp SPEC.md /tmp/mode-buttons.txt
racket host/racket/aloemacs-run.rkt /tmp/mode-buttons.txt
```

1. The mode line ends ` ↕ ↔ ×` inside the lighter bar, with × in the last column. The echo row is blank.
2. Click ↕. Two windows are stacked. Both bars end with the three labels; the upper bar is lighter.
3. Click ↔ on the lower bar. The lower window splits right. The lower-left window is selected and its bar is lighter.
4. Click × on the upper bar. The upper window closes. The two lower windows fill the screen, and the left one is selected.
5. Click the name on the unselected window's bar. Nothing changes.
6. Click × on the selected window. One window remains. Click × again. The echo row shows `failed: /tmp/mode-buttons.txt`.
7. Escape quits. Nothing is written. In the shell, mouse selection works again.

A failure of the check sends the work back. It does not add a
feature.

The specification is met when all of these are true:

1. **A wide mode line shows the three labels.** On every mode line whose width is at least 7, selected or not, the text is today's row at `width - 6` followed by the six-character group, inside the bar color the row already has. The one-view frame and a split leaf use the same text.
2. **A narrow line and a short leaf stay today's paint.** A mode line narrower than 7 columns equals today's row. A leaf shorter than two rows has no mode line. The echo row, a completion row, and a vertical bar gain no labels.
3. **A left press on a label runs the existing command after selection.** On an unselected window, the session equals entering that window and then `split-below`, `split-right`, or `delete-window`. On the selected window, it equals the send alone. The click column does not become the point.
4. **A refusal stays the send's refusal.** Delete of the only window and delete of a locked window return the session those sends already return, including the echo token `failed`. Selection still happens first.
5. **Every other mode-line press stays inert.** A left press on the name, the dash fill, or a space in the group leaves the session unchanged, including which window is selected. A release on a label leaves it unchanged. A press during a prompt, a search, or a pending prefix leaves that activity unchanged. Quit still wins before the string is examined.
6. **The labels stay visible while a command is pending.** A prompt, a search, or a pending prefix does not remove them.
7. **Tests are the proof.** The focused tests call `handle-event` with a `mouse down left` string and compare sessions. They do not open a TTY. The runner gains no bytes. Both focused files and `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs` pass with product changes only in `file.aloe`.

After the human accepts this spec, the checkpoint manager writes
**aloemacs-mode-buttons 000 only**, then stops. If you have been
told to read this file as the manager assignment, it is the whole
assignment. Do not write later checkpoints in advance.
