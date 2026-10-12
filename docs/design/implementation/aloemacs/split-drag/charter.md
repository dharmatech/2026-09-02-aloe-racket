# Charter — aloemacs split drag

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **a split that remembers
how its space is divided, and a left drag that moves that
division**. The series identity is **aloemacs-split-drag**. A
`Below` and a `Right` each carry two positive `Int` weights. A
fresh split is `1 1`, and equal weights lay out exactly as today.
A left press on a vertical bar arms a drag of that `Right`. A left
press on the mode line between an upper and a lower window arms a
drag of that `Below`, unless the cell is ↕, ↔, or ×. A move while
armed rewrites that split's weights from the pointer, clamped. The
left release ends the drag. The Aloemacs TTY entry asks for motion
while a button is held, mode `1002`, in place of mode `1000`. Then
**stop**. Do not write checkpoints. Do not implement.

This effort refuses drag-to-select and painting the mark; hover,
mode `1003`, the wheel, and the middle and right buttons; a click
on a path component, the directory browser, describe, and jump to
definition; painting `│` around the labels, or any new mode-line
command; dragging the echo row or the bottom mode line; changing
which window is selected, or moving a point; a keyboard command for
the same resize; balancing, saved layouts, and a general Unicode or
display-width change. Those stay later or out, so this spec stays
small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Do not reopen them.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-split-drag 000** under
   `docs/design/implementation/aloemacs/split-drag/checkpoints/`.
4. Stop. The human reviews the spec. Do not write those
   checkpoint files.

There are no open product questions. The spec names the sends, the
test files, the hand check, and the migration inventory from a
scratch run of the suite. A third kind of handle, a painted drag
state, a press that selects a window or places a point, or a change
to an equal cut are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 is implemented. `AloemacsWindowTree` is `Leaf`, `Below (top bottom)`, or `Right (left right)`. Neither split stores a share. `AloemacsWindowRect` is 0-based `(x, y, columns, rows)`; its `top`, `bottom`, `left`, and `right` recompute an even cut from the extent. `Right` reserves one column for the bar: the left gets `((columns - divider) + 1) / 2`, the bar is next, the right gets the rest. `Below` reserves no row: the top gets `(rows + 1) / 2` and the bottom starts on the next row. A below split requires four rows; a right split requires three columns. Lock lives on the view. Split refuses on a locked selected view. Delete compares every locked view's rectangle before and after and refuses when one moves or resizes. A terminal resize recomputes geometry from the tree and the new size, and lock does not block it. A tree that no longer fits paints the selected buffer alone for that frame |
| [`../window-bars/`](../window-bars/) | aloemacs-window-bars 000–001 is implemented. The mode line is the horizontal edge of a window. A `Below` spends no rule row: the upper window's mode line is the boundary and the lower window starts on the next row. The bar wraps the row in color. There is no separate horizontal rule |
| [`../mode-line/`](../mode-line/) | aloemacs-mode-line 000–001 is implemented. A leaf at least two rows tall paints its mode line on its last row. A shorter leaf is all text |
| [`../mode-buttons/`](../mode-buttons/) | aloemacs-mode-buttons 000–001 is implemented and accepted, and it is the whole series. Do not issue 002. A mode line at least seven columns wide ends in ↕, ↔, and ×. `(AloemacsModeLine label-at width index)` names the label at a cell or answers `""`. A left press on a label selects that window and sends `split-below`, `split-right`, or `delete-window`. A press on the rest of a mode line, and a press on a vertical bar, leave the session unchanged |
| [`../mouse/`](../mouse/) | aloemacs-mouse 000 is implemented and accepted, and it is the whole series. Do not issue 001. `(term read-event)` yields one `String`. A button is `mouse down left 4 22` or `mouse up left 4 22`, 0-based. `AloemacsMouse` reads it. `host/racket/term.rkt` formats a `tmousemsg` of kind `button-down` or `button-up` and drops every other kind, including `move`. The runner enables mode `1000` plus SGR `1006` and disables both on the way out. `handle-event` routes a mouse string to `handle-mouse`; a search, a prompt, or a pending prefix refuses every mouse string; `press-at` classifies the cell with the geometry of the last fit |
| [`../window-point/`](../window-point/) | aloemacs-window-point 000 is implemented and accepted. The drag never uses the entry handoff. It is named here so the spec does not reach for it |
| [`../alternate-screen/`](../alternate-screen/) | aloemacs-alternate-screen 000 is implemented. The runner writes `1049h` before `1000h` and `1006h`, and the reverse on the way out. The mouse mode this series changes sits between those bytes |
| tui-term | Installed at `~/.local/share/racket/9.3/pkgs/tui-term/`. `term/vt-input-port.rkt` decodes an SGR report with the motion bit as a `tmousemsg` of kind `move` at a 0-based `tpoint`, with the held buttons in its `left`, `middle`, and `right` fields and no `button` field |

Final human review of windows, mode line, and window bars remains
that work's business. This series reads the accepted specs and the
current program and does not wait. It does not edit those specs,
those charters, or those checkpoints. A defect there that blocks a
drag stops this spec; the designer reports it and does not patch
the earlier series from here.

The parent map is already updated. This series does not edit
[`../README.md`](../README.md), [`../explorations.md`](../explorations.md),
or [`../discussion.md`](../discussion.md).

**Why this layer:** every split is an even cut, and nothing a user
does changes it. A press on a bar and a press on the rest of a mode
line already reach Aloe and leave the session unchanged. The
terminal can report motion while a button is held, and tui-term
already decodes it. This series stores the division on the split
and lets the pointer move it.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Equal weights are today's cut.** A tree whose every split has
   weights `1 1`, which is every tree a split builds, lays out to
   the rectangles it has today at every extent, including the
   extents of the shrink fallback. Which side takes the odd cell
   does not change. Every frame golden already pinned stays green
   once its constructions pass `1 1`.
2. **A split remembers its division.** After a drag, the next frame
   reads the weights back. A terminal resize keeps the weights and
   recomputes the cells. Split of a leaf inside, delete,
   other-window, lock, and a buffer change leave every surviving
   split's weights as they were.
3. **The bar drags a `Right`.** A left press on the bar column arms.
   A move puts the bar at the pointer column, clamped by §4.3. The
   left child takes the columns before the bar and the right child
   the rest.
4. **The mode line drags a `Below`.** A left press on a mode-line
   cell whose `label-at` is `""`, on the last row of a `Below`'s
   top child, arms. A text cell on that row, which a shrink can
   produce when the top child is one row tall, stays a text press.
   A move makes the pointer row the top child's last row, clamped
   by §4.3. The bottom child starts on the next row.
5. **The three labels stay commands.** A left press on ↕, ↔, or ×
   on a handle row matches the session mode-buttons 001 already
   returns, and arms nothing.
6. **The bottom mode line, the echo row, a completion row, and
   text arm nothing.** A press there takes the path it takes today.
7. **The drag changes nothing but weights.** Selection, every
   point, every origin, the echo, the buffers, the lock bits, and
   the tree shape are the same before the press and after the
   release. The press alone and the release alone paint the frame
   painted before them. This speaks of the session `handle-event`
   returns. The runner's next fit may scroll the selected window to
   keep its point inside the new rectangle, as it already does
   after a terminal resize.
8. **Lock refuses the handle.** A press on a handle of a split with
   a locked leaf in either child leaves the session unchanged, and
   the moves that follow leave it unchanged.
9. **The floor is structural.** No move leaves a leaf shorter than
   two rows or narrower than one column, counting every leaf of
   both children of the dragged split.
10. **Motion reaches Aloe only while a button is held.** The runner
    enables mode `1002`, not `1000` and not `1003`, and disables it
    on the way out. Gel is untouched. A move string with nothing
    armed leaves the session unchanged. Wheel messages stay dropped.
11. **Tests are the proof.** The focused tests call `handle-event`
    with `mouse down left`, `mouse move`, and `mouse up left`
    strings and compare sessions and rectangles. They do not open a
    TTY. A scripted runner feeds the same strings through
    `read-event`.

## 4. Locked decisions

### 4.1 The weights

```text
(Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree) (earlier Int) (later Int)))
(Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree) (earlier Int) (later Int)))
```

- Both weights are positive `Int`. The names are the two sides in
  layout order, top before bottom and left before right, so one
  formula serves both axes. The rect's existing `earlier` method,
  which only `left` and `right` call and which subtracts the
  divider itself, is replaced by the §4.2 cut. `top` and `bottom`
  never called it.
- `with-split` writes `1 1`. Nothing else writes a weight except
  the move in §4.6.
- Every tree rewrite carries a split's weights through unchanged:
  `with-toggled-lock`, `without-pictures`, `without-pictures-of`,
  `without-view`, `with-split` on a leaf inside, `with-view-buffer`,
  `retarget-buffer`, and `with-pictures`. When delete promotes a
  sibling subtree, that subtree keeps its own weights; the removed
  parent's weights go with it.
- `with` is not available on an explicit-constructor instance
  (SPEC §4.12). A weight rewrite rebuilds the node with the same
  children.
- Every `case` arm on `Below` or `Right` binds the two new payload
  names.

### 4.2 The division

On `AloemacsWindowRect`, replacing the even cut:

```text
share = ((extent * earlier) + ((earlier + later) - 1)) / (earlier + later)
        ; the ceiling of extent * earlier / (earlier + later)
lo    = floor min (extent / 2)
cut   = lo max (share min (extent - lo))

Below: extent = rows,              floor = 2.
       top gets cut rows; bottom starts at y + cut and gets rows - cut.
Right: extent = columns - divider, floor = 1.
       left gets cut columns; the bar is next;
       right starts at x + cut + divider and gets extent - cut.
```

`divider` stays `1 min columns`, as the rect computes it today. The
cut above replaces the rect's `earlier` method on both axes.

Equal weights give `share = (extent + 1) / 2`, which is today's
`earlier` exactly, and the clamp is then the identity at every
extent: `lo` never exceeds `extent / 2`, and `share` never exceeds
`extent - lo`. So an equal tree, including one the shrink fallback
is painting, has today's rectangles, and the fallback decision
itself (`positive-layout?`) is unchanged.

The clamp exists for the unequal case after a terminal shrink. A
dragged share can round to one row; with four rows available the
top keeps two, so the mode line that is the handle survives the
resize. The clamp never changes a drag's own result, because the
move already writes a legal cut.

Pinned values:

| Axis | extent | earlier, later | share | lo | cut, rest |
|---|---:|---|---:|---:|---|
| Below | 23 | 1, 1 | 12 | 2 | 12, 11 (today) |
| Below | 23 | 6, 17 | 6 | 2 | 6, 17 |
| Below | 11 | 6, 17 | 3 | 2 | 3, 8 |
| Below | 3 | 1, 1 | 2 | 1 | 2, 1 (today) |
| Below | 3 | 22, 1 | 3 | 1 | 2, 1 |
| Below | 1 | 1, 1 | 1 | 0 | 1, 0 (today; fallback) |
| Right | 79 | 1, 1 | 40 | 1 | 40, 39 (today) |
| Right | 79 | 30, 49 | 30 | 1 | 30, 49 |
| Right | 119 | 30, 49 | 46 | 1 | 46, 73 |
| Right | 0 | 1, 1 | 0 | 0 | 0, 0 (today; fallback) |

### 4.3 What a drag writes, and the floor

A move while armed maps the pointer to a cut for the armed split,
in the rectangle that split has under the last fit:

```text
Below: wanted = (row - rect.y) + 1     ; the pointer row becomes the top child's last row
Right: wanted = column - rect.x        ; the pointer column becomes the bar column
```

The cut is `wanted` clamped to the interval below. The weights
become `cut` and `extent - cut`, the two cell counts. At that size
the formula reproduces the cut exactly; after a resize it scales.

The floor is structural. A child that is itself split needs room
for every leaf inside it, divided by the weights that child already
has:

```text
min-rows (Leaf)     = 2
min-rows (Right)    = min-rows (left) max min-rows (right)
min-rows (Below)    = the smallest rows whose §4.2 cut, with that Below's
                      own weights, gives the top at least min-rows (top)
                      and the bottom at least min-rows (bottom)

min-columns (Leaf)  = 1
min-columns (Below) = min-columns (top) max min-columns (bottom)
min-columns (Right) = the smallest columns whose §4.2 cut, with that
                      Right's own weights and its divider, gives the left
                      at least min-columns (left) and the right at least
                      min-columns (right)

Below: cut in [min-rows (top),       rows   - min-rows (bottom)]
Right: cut in [min-columns (left),   extent - min-columns (right)]
```

When both children are leaves this is the split minimum already in
force: two rows on each side of a `Below`, one column on each side
of a `Right` plus its bar. A flat floor would let a drag squeeze a
nested `Below` to two rows, giving its leaves one row each and
erasing both mode lines, so the inner handle and the outer handle
would both vanish.

The sum of the two children's minimums is where the search starts,
not the answer. A drag rewrites only the dragged split's weights.
A child keeps its own, and §4.2 divides whatever that child is
given by them. A `Below` whose sides need 4 and 2 needs 7 rows at
equal weights, not 6, because the equal cut of 6 is 3 and 3, and
the inner cut of 3 is 2 and 1. The §4.2 cut and its remainder each
climb by at most one per added cell, so the smallest size is found
by climbing from the sum until both children fit, and it reads the
weights the child has at that moment. A child dragged earlier to
`4 8` needs 10 rows before its top gets 4.

An empty interval means the move changes nothing. A pointer outside
the root rectangle is clamped, not refused.

Pinned cases at 80 by 24, root rectangle `(0, 0, 80, 23)`:

| Tree | Drag | Result |
|---|---|---|
| `Right (A, B)` | bar at column 40 to column 30 | A `(0,0,30,23)`, bar 30, B `(31,0,49,23)`; weights `30 49` |
| that tree, then `ensure-visible 120 24` | none | A 46 columns, bar 46, B 73 columns; weights still `30 49` |
| `Below (A, B)` | A's mode line at row 11 to row 5 | A `(0,0,80,6)`, B `(0,6,80,17)`; weights `6 17` |
| that tree, then `ensure-visible 80 12` | none | A 3 rows, B 8 rows; weights still `6 17` |
| `Below (A, B)` | A's mode line to row 0 | A 2 rows; weights `2 21` |
| `Below (Below (A, B), C)` | the outer boundary, B's mode line at row 11, to row 0 | the top child gets 4 rows: A 2, B 2; C 19; outer weights `4 19`, inner `1 1` |
| `Right (Right (A, B), C)` | the outer bar at column 40 to column 0 | the left child gets 3 columns: A 1, bar, B 1; outer bar at column 3; C starts at column 4 with 76 columns; outer weights `3 76` |
| `Below (Below (Below (A, B), C), D)`, every weight `1 1`; today A 3, B 3, C 6, D 11 | the outer boundary, C's mode line at row 11, to row 0 | the middle child gets 7 rows: inner 4 (A 2, B 2), C 3; D 16; outer weights `7 16`. The summed minimum, 6, would cut 3 and 3 and leave B one row |
| that tree with the middle already dragged to `4 8` | the outer boundary to row 0 | the middle child gets 10 rows: inner 4 (A 2, B 2), C 6; D 13; outer weights `10 13` |
| `Right (Right (Right (A, B), C), D)`, every weight `1 1` | the outer bar at column 40 to column 0 | the left child gets 6 columns: A 1, bar, B 1, middle bar at column 3, C 2; outer bar at column 6; D starts at column 7 with 73 columns; outer weights `6 73`. The summed minimum, 5, would give the innermost `Right` 2 columns and one leaf none |

### 4.4 The move string and the host

The move string is `mouse move <column> <row>`: four fields, one
space between them, canonical decimals, 0-based, nothing else. It
carries no button. Mode `1002` delivers motion only while a button
is held, and the editor's armed state is the authority for what a
move means.

- `tmousemsg->aloe-mouse` formats kind `move` at a non-negative
  point as that string and does not read the held fields.
  `button-down` and `button-up` format as today. A wheel kind, a
  negative component, and a press or release with button `#f` stay
  `#f` and are dropped.
- The pattern behind `read-key`'s skip accepts both shapes, so
  `read-key` skips a move as it skips a press.
- `run-aloemacs` writes `1049h`, `1002h`, `1006h` on the way in and
  `1002l`, `1006l`, `1049l` on the way out, in that order, on the
  normal path and on the exception path. It writes neither `1000`
  nor `1003`. `with-term` does not disable `1002`; the runner's own
  `1002l` is what turns it off. `term.rkt`, `gel-run.rkt`, and
  `term-run.rkt` contain no mouse mode.
- `AloemacsMouse` gains `move?`. `event?` accepts both shapes.
  `down?` and `left?` are false on a move. `column` and `row` read
  both shapes.

Pinned strings: `mouse move 0 0` and `mouse move 30 5` are events.
`mouse move left 30 5`, `mouse move 30`, `mouse move 030 5`, and
`mouse move 30 5` with a trailing space are not.

### 4.5 The handles

A handle belongs to one split. The split is named by one `Int`:
the id of the first leaf of its later child, the bottom of a
`Below` or the right of a `Right`. That id names exactly one split.
Walking up from that leaf, every ancestor below the split is a
first child, and the split's later child is the first node on that
walk that is a later child; no second split can have the same
first leaf of its later child. The session stores that id while
armed.

Which cell is a handle is decided by one walk from the root with
the rectangles `rect-for` already walks:

- At a `Right`: the cell is in the rectangle and its column is the
  bar column, `x + cut`. That `Right` is the split.
- At a `Below`: the cell is in the rectangle and its row is the top
  child's last row, `y + cut - 1`. That `Below` is the split.
- Otherwise recurse into the child whose rectangle holds the cell.
  A cell in neither is no handle.

The ancestor wins. A bar cell on a mode-line row drags the `Below`
above it. A mode-line cell to the left of a bar drags the `Below`
inside that `Right`. The bottom mode line is never a top child's
last row, so it never arms. The press runs this walk only from the
branches that answer "unchanged" today: a bar cell, which `view-at`
places in no leaf, and a mode-line cell whose `label-at` is `""`.
A label cell stays the command. A text cell stays `place-in`, even
on the boundary row of a one-row child. A press while
`positive-layout?` is false arms nothing, and a move then writes
nothing.

### 4.6 Press, move, release, and the rest

`AloemacsWindows` gains a last field, `(drag (Option Int))`: the
id of §4.5 while armed, `None` otherwise. `with-size` and every
`with` keep it. It is not painted; the bar stays `|` and the mode
line stays its row.

| Event | While not armed | While armed |
|---|---|---|
| `mouse down left` on a handle of a split with no locked leaf in either child | Arms. Nothing else changes: selection, points, origins, echo, frame | Re-arms on that handle. Nothing else changes |
| `mouse down left` on a handle of a split with a locked leaf in either child | Unchanged | Disarms. Nothing else changes |
| `mouse down left` anywhere else | Today's path: a label is its command, text places, chrome is unchanged | Disarms, then today's path |
| `mouse move` | Unchanged | Rewrites the armed split's weights per §4.3. A missing split, an empty interval, or a non-positive layout leaves the tree |
| `mouse up left` | Unchanged | Disarms. The weights stay what the last move wrote |
| `mouse down` or `mouse up` with middle or right | Unchanged | Disarms. Nothing else changes |
| A key | Today's path | Disarms, then today's path |
| Any event after quit | Unchanged | Unchanged |

A search, a prompt, and a pending prefix keep refusing every mouse
string before the cell is classified. They cannot coexist with an
armed drag: the arming press is refused while they are active, and
the key that starts one of them disarms first.

A move rewrites weights with no fit and no echo. The runner's next
`ensure-visible` and frame read the weights back. That fit may
scroll the selected window, as it does after a resize; the drag
itself stores no origin. A terminal
resize between events keeps the armed id; the next move uses the
new geometry.

### 4.7 Lock

A press on a handle arms only when neither child of that split has
a locked leaf (`any-locked?` on each child). Every leaf of both
children is in the resize domain of that handle. The exact-geometry
comparison delete uses would let the bar follow the pointer only at
positions where rounding happened to spare the locked leaf, so the
handle would stick and skip. The refusal is blanket over the
split's two children, not over the tree. A locked leaf elsewhere
does not refuse. A terminal resize still recomputes every
rectangle, locked or not, as today.

### 4.8 Where the work lives

- The fields and the formula live on `AloemacsWindowTree` and
  `AloemacsWindowRect` in `examples/aloemacs/file.aloe`. The walk,
  the weight rewrite, and the structural minimums are tree sends.
  The pointer mapping and the clamp may live on the tree or the
  rect; the spec decides. The arming and the event table are
  session sends beside `press-at`.
- The host change is `tmousemsg->aloe-mouse` and the skip pattern
  in `host/racket/term.rkt`, and the mode bytes in
  `host/racket/aloemacs-run.rkt`. Term gains no method. Host values
  that cross stay `Int`, `Bool`, `String`, and `(List String)`.
- No new class. The ordered `define-class` inventory stays as it
  is, so the tests that pin it stay green. No new field on
  `AloemacsView`, `AloemacsLeafPicture`, or the session. The
  picture cache already matches on `columns` and `rows`, so a drag
  invalidates a leaf's picture by geometry.
- The migration is the largest cost of this series, and the spec
  restates it from a scratch run. Measured on the tree at this
  writing:

| What changes | Where |
|---|---|
| `case` arms binding `(top bottom)` or `(left right)` | 30 in `file.aloe` |
| Constructions of `Below` or `Right` gaining `1 1` | 17 test files; most go through a local `below` / `right` helper, some are inline |
| Constructions of `AloemacsWindows` gaining `(Option None)` | 37 test files and `examples/aloemacs/main.aloe`; some go through a local `windows` / `config` helper |
| The pin that a `move` formats as `#f` | `tests/aloemacs/mouse.rkt` |
| Pins of the `1000` bytes and phrases | `tests/aloemacs/alternate-screen.rkt`, `tests/aloemacs/mouse.rkt` |

Per the standing rule, the suite after the product edit is the
inventory; expect literals hidden behind helpers.

### 4.9 What this series leaves alone

`Text` gains no method. `SPEC.md` gains no row. The kernel gains
no message. The press and release strings, and SGR `1006`, stay as
the mouse spec left them. `split-below`, `split-right`,
`delete-window`, `other-window`, and the lock toggle stay the same
sends with the same refusals and the same echo tokens. The label
cells and `label-at` stay as mode-buttons left them. Bar colors
and the no-rule-row `Below` stay with window bars. The frame stays
one `String`. The runner still fits, records pictures, and frames
around each event, and reads one string per event. Gel's runner is
untouched.

### 4.10 Three checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-split-drag 000** | The weights in §4.1 and the division in §4.2. Every tree a split builds has today's rectangles; constructed trees with unequal weights lay out per the formula, including the pinned values and the shrink fallback; a resize scales; every rewrite preserves weights; the constructor and `case` migration lands. No press arms anything |
| **aloemacs-split-drag 001** | The host in §4.4, the `drag` field, and the bar. A move reaches `handle-event` and leaves an unarmed session unchanged. A press on a bar arms; moves rewrite that `Right` with the structural floor; the release disarms; a key and any other press disarm; a locked child refuses. A scripted runner drives one drag end to end |
| **aloemacs-split-drag 002** | The mode line. A non-label cell on a `Below`'s boundary row arms; moves rewrite that `Below` with the structural floor, including a nested `Below` inside the top child and a `Right` inside it; the labels stay commands; the bottom mode line, a text cell, and a one-row child arm nothing. The hand check |

000 is testable from rectangles and frames. 001 is testable once
motion reaches Aloe. 002 reuses 001's arming with the label
exclusion. The manager writes 000 only, then stops.

If 001 would not fit one implementer conversation, the spec splits
the `drag` field and the host motion into a numbered step before
the bar, proved by a move reaching `handle-event` and leaving the
session unchanged and by the field surviving every window send as
`None`, and the bar takes the next number. The mode line stays
last. The added number introduces no second feature.

### 4.11 The hand check

The spec ends with a hand check the human runs on a real terminal,
in the shape mode-buttons §8 used. It covers at least: split right
and drag the bar both ways; split below inside one side and drag
that mode line both ways; shrink and grow the terminal window and
watch the proportions hold; lock a window with `C-x l` and find
that its handles do not move; press ↕ on a handle row and get the
split; press the bottom mode line and move, and see nothing; quit,
and find the shell unchanged with mouse reporting off.

## 5. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  split drag
- [`../windows/spec.md`](../windows/spec.md) — leaf geometry, the
  even cut this series replaces, the split and delete minimums, the
  lock comparison inside delete, the resize rule, and the shrink
  fallback. This charter is the authority for the division formula
  and for the weights. Do not amend that spec
- [`../window-bars/spec.md`](../window-bars/spec.md) — the mode
  line as the horizontal edge, the no-rule-row `Below`, and the
  bar wrap
- [`../mode-line/spec.md`](../mode-line/spec.md) — the mode-line
  row and the short leaf
- [`../mode-buttons/spec.md`](../mode-buttons/spec.md) — the three
  labels, `label-at`, and the press on a label. Those stay. This
  charter is the authority for a non-label mode-line press on a
  boundary row. Do not issue aloemacs-mode-buttons 002
- [`../mouse/spec.md`](../mouse/spec.md) — the press and release
  strings, `read-event`, `handle-event`, the refusals, and the cell
  classification. This charter is the authority for the move
  string, for mode `1002`, and for a press on a bar or a non-label
  boundary cell. Every other mouse result stays that spec. Do not
  amend that spec, and do not issue aloemacs-mouse 001
- [`../alternate-screen/`](../alternate-screen/) — the order of
  the runner's enter and leave bytes around the mouse mode
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `AloemacsWindowTree`, `AloemacsWindowRect`, `AloemacsWindows`,
  `AloemacsMouse`, `handle-event`, `handle-mouse`, `press-at`,
  `press-mode-line`
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt) —
  `tmousemsg->aloe-mouse`, the skip pattern, `read-next-key`
- [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt)
  — the mode bytes and the loop
- `~/.local/share/racket/9.3/pkgs/tui-term/term/vt-input-port.rkt`
  — how a motion report becomes kind `move`
- `/home/dharmatech/src/e` — a seam catalog for dragging a divider.
  It supplies no requirement

`SPEC.md` remains language law. This series does not amend it.
When this charter and the windows spec disagree about how a split
divides its rectangle, this charter wins. When this charter and the
mouse spec disagree about a move, mode `1002`, or a press on a
handle, this charter wins. After the human accepts `spec.md`, that
file is the design authority for the checkpoint manager and the
implementers.

## 6. Non-goals

- Drag-to-select, or painting the mark
- Hover, mode `1003`, the wheel, or the middle and right buttons
  doing anything
- A click on a path component, the directory browser, describe, or
  jump to definition
- Painting `│` around the labels, a fourth glyph, or any new
  mode-line command
- Dragging the echo row or the bottom mode line
- Changing which window is selected, moving a point, or an entry
  handoff from a drag
- A keyboard command for the same resize, a keymap change, or a
  new command constructor
- Balancing, equalizing, saved layouts, or writing weights from
  anything but a drag
- A painted drag state, a cursor change, or a new face
- A stricter per-side floor than two rows and one column, or any
  clamp on a terminal resize
- A new class, a new field on a view, a picture, or the session, or
  a Term method
- Changing what `split-below`, `split-right`, `delete-window`, or
  the lock toggle do
- A display-width table, `wcwidth`, or a grapheme rule
- Editing the windows, mouse, mode-buttons, or window-bars specs,
  or the parent map
- A kernel message, a `SPEC.md` row, or a `CHECKPOINTS.md` entry

## 7. Handoff

- Series identity: `aloemacs-split-drag`.
- Checkpoint 000 is spoken **aloemacs-split-drag 000** and filed
  as `checkpoints/000-slug.md`. Numbers are three digits, start at
  000, and are never renumbered. The slug is lowercase words
  separated by hyphens. The checkpoint manager writes one
  checkpoint, then stops.
- Intended order: §4.10. The weights and the division first, then
  the host motion and the bar, then the mode line. A later number
  exists only for the size split §4.10 allows, and the mode line
  stays last.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/file.aloe`,
  `host/racket/term.rkt`, and `host/racket/aloemacs-run.rkt`.
  Tests stay in `tests/aloemacs/`. The spec names the focused test
  files and the standing command `TMPDIR=/tmp raco test -j 4 -y`.
  The design folder receives `spec.md` and later the checkpoints,
  not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementers. This
  charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
