# aloemacs split-drag specification

**Status: Accepted and implemented.** aloemacs-split-drag 000–003,
the whole series, is implemented, and the human's §10 hand check
passed on 2026-10-11. Written by the designer from
[`charter.md`](charter.md). The human authorized the manager to
proceed if the spec was ready. On 2026-10-11 the manager checked its
§5.1–§5.2 counts, its §6.2 examples, and its §6.3 inventory against
the tree and a scratch run, found it ready, and wrote
[`checkpoints/000-weights.md`](checkpoints/000-weights.md). After 000
and 001 were implemented, the manager removed the class-list pin
count from §4 and §6.3: each focused file in this series adds a pin
(seventeen before 000, nineteen after 001), and no class is added, so
nothing else changes. Not Aloe law. Not a checkpoint. Not an implementer
assignment.

This file is the complete design input for the checkpoint manager
and the implementers. They do not need the charter or the design
conversation. [`SPEC.md`](../../../../../SPEC.md) remains Aloe
language law. [`docs/workflow.md`](../../../../workflow.md) governs
roles and review. The accepted windows specification remains the
authority for leaf geometry, the split and delete minimums, the lock
comparison inside delete, the resize rule, and the shrink fallback,
except that this file replaces the even cut. The accepted mouse
specification remains the authority for the press and release
strings, `read-event`, the quit rule in `handle-event`, the
refusals, and every cell this file does not name. The accepted
mode-buttons specification remains the authority for the three
labels and a press on one. This file is the authority for the
weights, the division, the structural floor, the handles, the drag,
the move string, and mode `1002`.

## 1. Opening

A `Below` and a `Right` each remember how their space is divided:
two positive `Int` weights, `earlier` and `later`. A fresh split is
`1 1` and lays out exactly as today. A left press on a vertical bar
arms a drag of that `Right`. A left press on the mode line between
an upper and a lower window arms a drag of that `Below`, unless the
cell is ↕, ↔, or ×, which stay the commands they are. A move while
armed rewrites the armed split's weights from the pointer, clamped
so every leaf keeps at least two rows and one column. The left
release ends the drag. A terminal resize keeps the weights and
recomputes the cells. The Aloemacs TTY entry asks for motion while a
button is held, mode `1002`, in place of mode `1000`.

The charter locked the weights, the formula, the floor, the handle
rule, the event table, the lock rule, and the host bytes. It left
these to this spec. They are decided:

| What | Decision | Section |
|---|---|---|
| The rect's cut | `cut(extent, least, earlier, later)`, pure. `row-cut(earlier, later)` and `column-cut(earlier, later)` apply it to the rect's own extents. `top`, `bottom`, `left`, and `right` take `(earlier Int) (later Int)`. `earlier` is removed | §5.2 |
| The split a handle names | `handle-at(column, row, rect)` on the tree answers the split node, `(Option AloemacsWindowTree)`. `handle-id` on that node is the stored `Int`. `first-id` is the first leaf's id | §5.4 |
| The structural floor | `min-rows` and `min-columns` on the tree | §5.3 |
| The pointer mapping and the clamp | On the tree node, inside `with-cut-at(id, column, row, rect)`, which rewrites the named split and returns the tree | §5.6 |
| The field | `AloemacsWindows.drag`, last field, `(Option Int)`. `armed(id)` and `disarmed` on the configuration | §5.5 |
| The session sends | `disarmed`, `press-handle(column, row)`, `drag-to(column, row)` | §5.5 |
| Where the press reaches the walk | The no-leaf arm of `press-at`, and the `""` branch of `press-mode-line`, which recovers the cell from `rect` and `index`. `press-mode-line` keeps its three parameters | §5.4 |
| The move string in the session | `AloemacsMouse.move?`. `event?` accepts the second shape | §5.8 |
| Checkpoint count | Four. Motion and the field are 001; the bar is 002; the mode line is 003 | §2 |
| Focused tests | `tests/aloemacs/split-drag-weights.rkt`, `split-drag-motion.rkt`, `split-drag-bar.rkt`, `split-drag-mode-line.rkt` | §6–§9 |
| Wider suite | `tests/aloemacs` and `tests/parenthetical-construction` | §10 |

There were no open product questions in the charter. Every number in
this file was checked against the formula, and the migration
inventories in §6.3 and §7.3 come from a scratch run of the suite on
a copy of the tree with the product edit applied.

## 2. Checkpoint series

Series identity is **aloemacs-split-drag**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Checkpoint numbers
are three digits, start at 000, and are never renumbered. The slug is
lowercase words separated by hyphens.

| Identity | File | What it proves |
|---|---|---|
| **aloemacs-split-drag 000** | `checkpoints/000-weights.md` | The weights in §5.1 and the division in §5.2. Every tree a split builds has today's rectangles and today's frames; a constructed tree with unequal weights lays out per the formula, including the pinned values and the shrink fallback; a resize scales; every rewrite preserves weights; delete promotion keeps the promoted subtree's weights; the constructor, `case`, and rect-send migration lands. No press arms anything |
| **aloemacs-split-drag 001** | `checkpoints/001-motion.md` | The host in §5.8 and the field in §5.5. A move reaches `handle-event` and leaves an unarmed session unchanged. The runner enables `1002`. `read-key` skips a move. `drag` survives every window send as `None`; a key, a release, and a middle or right button disarm a constructed armed configuration. The field migration lands |
| **aloemacs-split-drag 002** | `checkpoints/002-bar.md` | The `Right` axis of §5.3, §5.4, and §5.6, and the session events of §5.5. A left press on a bar arms; moves rewrite that `Right` with the structural floor, nested or not; the release disarms; a key and any other press disarm; a locked child refuses; a lock elsewhere does not. A scripted runner drives one drag end to end |
| **aloemacs-split-drag 003** | `checkpoints/003-mode-line.md` | The `Below` axis of §5.3, §5.4, and §5.6, and the mode-line handle. A non-label cell on a `Below`'s boundary row arms; moves rewrite that `Below` with the structural floor, including a nested `Below` inside the top child and a `Right` inside it; the labels stay commands; the bottom mode line, a text cell, and a one-row child arm nothing. The hand check |

Why four and not the charter's three: the charter's 001 would carry
the host change, the move grammar, the `drag` field with its
migration across 38 test files, the walk, the floor, the rewrite,
the event table, the lock rule, and a scripted runner. That is two
implementer conversations. The charter allows exactly this split:
the field and the host motion take a number before the bar, proved
by a move reaching `handle-event` and leaving the session unchanged
and by the field surviving every window send as `None`. The added
number introduces no second feature. The bar and the mode line each
add one axis of the same three sends, so neither pins a result the
other changes.

The manager writes 000, then stops. After human review of each
implementation, the manager writes the next number. The mode line
stays last. If 000 would not fit one implementer conversation, the
manager sends this spec back; 000 is not split.

Do not take a global checkpoint number. Do not add a
`CHECKPOINTS.md` entry. Do not edit the parent map
[`../README.md`](../README.md), [`../explorations.md`](../explorations.md),
or [`../discussion.md`](../discussion.md), or any earlier series'
spec, charter, or checkpoint.

### 2.1 Predecessors

This series reads the accepted specs and the current program. It
does not edit those specs, those charters, or those checkpoints. A
defect there that blocks a drag stops the implementer; the fix
belongs to that series. The table is the tree as found on
2026-10-11, confirmed against `examples/aloemacs/file.aloe`,
`host/racket/term.rkt`, `host/racket/aloemacs-run.rkt`, and the
tests.

| What | The state this series starts from |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 is implemented; final human review remains. `AloemacsWindowTree` is `Leaf (view)`, `Below (top bottom)`, or `Right (left right)`. Neither split stores a share. `AloemacsWindowRect` is 0-based `(x, y, columns, rows)`. Its `top` and `bottom` take no argument and cut `(rows + 1) / 2`; its `left` and `right` take no argument and call `earlier(extent)`, which is `((extent - divider) + 1) / 2` with `divider = 1 min extent`. `Right` reserves one column for the bar; `Below` reserves no row. A below split needs four rows; a right split needs three columns. Lock lives on the view. Split refuses on a locked selected view. Delete compares every locked view's rectangle before and after. A terminal resize recomputes geometry from the tree and the new size. A tree that no longer fits, `positive-layout?` false, paints the selected buffer alone for that frame |
| [`../window-bars/`](../window-bars/) | aloemacs-window-bars 000–001 is implemented; final human review remains. The mode line is the horizontal edge of a window. A `Below` spends no rule row: the upper window's mode line is the boundary and the lower window starts on the next row. The bar wraps the row in LIGHT or DARK |
| [`../mode-line/`](../mode-line/) | aloemacs-mode-line 000–001 is implemented; final human review remains. A leaf at least two rows tall paints its mode line on its last row. A shorter leaf is all text |
| [`../mode-buttons/`](../mode-buttons/) | aloemacs-mode-buttons 000–001 is implemented and accepted, and it is the whole series. A mode line at least seven columns wide ends in ↕, ↔, and ×. `(AloemacsModeLine label-at width index)` names the label at a cell or answers `""`. `press-mode-line(view, rect, index)` runs `select-view` and `button-send` on a label and returns `(self unchanged)` on `""`. A press on a vertical bar takes `press-at`'s no-leaf arm and returns `(self unchanged)` |
| [`../mouse/`](../mouse/) | aloemacs-mouse 000 is implemented and accepted, and it is the whole series. `(term read-event)` yields one `String`. A button is `mouse down left 4 22` or `mouse up left 4 22`, 0-based. `AloemacsMouse` reads it with `event?`, `down?`, `left?`, `column`, and `row`. `tmousemsg->aloe-mouse` formats kind `button-down` or `button-up` and answers `#f` for every other kind, including `move`. `mouse-event-pattern` in `term.rkt` is the `read-key` skip. The runner writes `1049h`, `1000h`, `1006h` in a `dynamic-wind` before thunk and `1000l`, `1006l`, `1049l` in the after thunk. `handle-event` routes a mouse string to `handle-mouse`; a search, a prompt, or a pending prefix refuses every mouse string; `press-at` classifies the cell with the geometry of the last fit |
| [`../window-point/`](../window-point/) | aloemacs-window-point 000 is implemented and accepted. The drag never uses the entry handoff |
| [`../alternate-screen/`](../alternate-screen/) | aloemacs-alternate-screen 000 is implemented and its hand check passed. The mouse mode this series changes sits between the `1049` bytes. `tests/aloemacs/alternate-screen.rkt` pins the order with the phrases `[?1000h` and `[?1000l` |
| [`../window-pictures/`](../window-pictures/) | A leaf's recorded picture matches on `columns` and `rows`, among other inputs. A drag changes a leaf's picture by geometry, with no new key |
| tui-term | Installed at `~/.local/share/racket/9.3/pkgs/tui-term/`. `term/vt-input-port.rkt` decodes an SGR report with the motion bit, 32, as a `tmousemsg` of kind `move` at a 0-based `tpoint`, with the held buttons in its `left`, `right`, and `middle` fields and the `button` field at its default `#f`. `with-term`'s cleanup writes `1003l` and `1006l`; it never writes `1000`, `1002`, or an enable |

## 3. Product boundary

The program, after this series:

- Every `Below` and `Right` carries `earlier` and `later`, positive `Int` weights. A split the user makes is `1 1`. A drag writes the two cell counts. Nothing else writes a weight.
- A rectangle divides by the weights: the earlier side gets the ceiling of `extent * earlier / (earlier + later)`, clamped so neither side drops below two rows or one column while the extent allows it. Equal weights give today's cut at every extent.
- A left press on a vertical bar, or on a non-label cell of the mode line between an upper and a lower window, arms that split. A move while armed puts the bar at the pointer column, or makes the pointer row the upper window's last row, within the structural floor. The left release disarms. A key, another button, or a press elsewhere disarms first and then takes today's path.
- A press on a handle of a split with a locked leaf in either child arms nothing. A press on ↕, ↔, or × is the command it is today. A press on the bottom mode line, the echo row, a completion row, or text takes the path it takes today.
- A move with nothing armed leaves the session unchanged. A move, a press, and a release during a search, a prompt, or a pending prefix leave that activity unchanged.
- `(term read-event)` returns `mouse move <column> <row>` for motion while a button is held. `(term read-key)` skips it. The TTY entry enables mode `1002` and SGR `1006` after `1049`, and disables them in reverse before `1049` is left.

Out of scope, for the implementers as well as the manager:

- Drag-to-select, painting the mark, or pairing a press with a release for anything but this resize
- Hover, mode `1003`, the wheel, or the middle and right buttons doing anything
- A click on a path component, the directory browser, describe, or jump to definition
- Painting `│` around the labels, a fourth glyph, a painted drag state, a cursor change, or a new face
- Dragging the echo row or the bottom mode line
- Changing which window is selected, moving a point, scrolling, or an entry handoff from a drag
- A keyboard command for the same resize, a keymap change, or a new command constructor
- Balancing, equalizing, saved layouts, or writing weights from anything but a drag or a split
- A stricter per-side floor than two rows and one column, or any clamp on a terminal resize
- A new class, a new field on a view, a picture, or the session, or a Term method
- Changing what `split-below`, `split-right`, `delete-window`, `other-window`, or the lock toggle do, or their echo tokens
- A display-width table, `wcwidth`, or a grapheme rule
- A change to `tui-term`, to Gel's runner, or to `term-run.rkt`
- Editing the windows, mouse, mode-buttons, or window-bars specs, or the parent map
- A kernel message, a `SPEC.md` row, a `lib/` method, or a `CHECKPOINTS.md` entry

## 4. Host, files, and layout

Language is Aloe for the editor and Racket for the host. The design
folder receives this spec and later the checkpoints. The program
stays in the tree below.

| May edit | Checkpoint | What changes |
|---|---|---|
| `examples/aloemacs/file.aloe` | 000 | `Below` and `Right` payloads, every `case` arm on them, every construction, the rect's `cut`, `row-cut`, `column-cut`, `top`, `bottom`, `left`, `right`, the removal of `earlier`, and the five walks that call the four |
| `examples/aloemacs/file.aloe` | 001 | `AloemacsWindows.drag`, `armed`, `disarmed`; `AloemacsMouse.move?` and `event?`; the session's `disarmed`; `handle-event` and `handle-mouse` |
| `examples/aloemacs/main.aloe` | 001 | `(drag (Option None))` in the `new*` of `initial-windows` |
| `host/racket/term.rkt` | 001 | `mouse-event-pattern` and `tmousemsg->aloe-mouse` |
| `host/racket/aloemacs-run.rkt` | 001 | The mode bytes and the comment above them |
| `examples/aloemacs/file.aloe` | 002 | `first-id`, `handle-id`, `min-columns`, `handle-at`, `with-cut-at` with the `Right` axis; `press-handle`, `drag-to`; the no-leaf arm of `press-at`; the move arm of `handle-mouse` |
| `examples/aloemacs/file.aloe` | 003 | `min-rows`; the `Below` axis of `handle-at` and `with-cut-at`; the `""` branch of `press-mode-line` |
| `tests/aloemacs/split-drag-weights.rkt` | 000 | New focused proof |
| `tests/aloemacs/split-drag-motion.rkt` | 001 | New focused proof |
| `tests/aloemacs/split-drag-bar.rkt` | 002 | New focused proof |
| `tests/aloemacs/split-drag-mode-line.rkt` | 003 | New focused proof |
| The files §6.3 names | 000 | Constructions, `case` arms, declaration pins, and rect sends |
| The files §7.3 names | 001 | Constructions, declaration pins, the `move` formatter pin, and the `1000` phrases |
| `tests/aloemacs/mouse.rkt`, `tests/aloemacs/mode-buttons-press.rkt` | 002 | One bar press in each becomes the armed expectation (§8.3) |
| `tests/aloemacs/mouse.rkt` | 003 | One boundary-row press becomes the armed expectation (§9.3) |
| `tests/aloemacs/split-drag-weights.rkt` | 002, 003 | Its last item loses one row each time |

When another file looks necessary, the implementer stops and sends
the checkpoint back.

Leave these alone:

- `host/racket/gel-run.rkt`, `host/racket/term-run.rkt`, and `tui-term`
- `examples/aloemacs/editor.aloe` and `lib/`
- `AloemacsView`, `AloemacsLeafPicture`, `AloemacsModeLine`, `AloemacsSession`'s fields, and the ordered `define-class` list, which the tests pin as data
- `split-below`, `split-right`, `delete-window`, `other-window`, `toggle-window-lock`, `select-view`, `button-send`, `place-in`, `place-at`, and `enter-view`
- The accepted Term, windows, window-bars, mode-line, mode-buttons, and mouse specs, and the parent map

From the project root, tests are:

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

`<paths>` is the focused file, then the wider suite in §10.
`compiled/` stays gitignored. `./bin/aloe` and
`racket host/racket/aloemacs-run.rkt` load bytecode and do not
rebuild it. After a `.rkt` edit, the test command rebuilds what it
runs; launching the TTY entry by hand after a `.rkt` edit needs
`raco make host/racket/aloemacs-run.rkt` first. `.aloe` edits need
no rebuild. The hand check is the human's, after 003 is green.

The editor loads through `examples/aloemacs/main.aloe`, which loads
`file.aloe`. `Int` has `+`, `-`, `*`, `/`, `min`, `max`, `=`, `<`,
`<=`, `>`, `>=`, and `text`; `/` on two `Int` values is integer
division, which is what every formula below means. `cond`, `case`,
`let`, `if`, and `with` are the forms `file.aloe` already uses.
`with` is not available on a `Below` or a `Right` (SPEC §4.12); a
weight rewrite rebuilds the node with the same children. This series
adds no kernel message and no `lib/` method.

## 5. The layer

### 5.1 The weights

```text
(define-class AloemacsWindowTree
  (constructors
    (Leaf (fields (view AloemacsView)))
    (Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree) (earlier Int) (later Int)))
    (Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree) (earlier Int) (later Int))))
  ...)
```

- Both weights are positive `Int`. The names are the two sides in
  layout order, top before bottom and left before right, so one
  formula serves both axes. Nothing checks positivity at
  construction; the two writers below only write positive values.
- `with-split` writes `1 1` on the node it builds. `with-cut-at`
  (§5.6) writes the two cell counts of a drag. Nothing else writes a
  weight.
- Every `case` arm on `Below` binds `(top bottom earlier later)` and
  every arm on `Right` binds `(left right earlier later)`. The
  thirty arms in `file.aloe` are the two in each of `leaves`,
  `find-view`, `with-toggled-lock`, `without-pictures`,
  `without-pictures-of`, `sibling-for`, `without-view`,
  `with-split`, `with-view-buffer`, `retarget-buffer`, `rect-for`,
  `view-at`, `positive-layout?`, `with-pictures`, and `frame-rows`.
- Every tree rewrite carries a split's weights through unchanged:
  `with-toggled-lock`, `without-pictures`, `without-pictures-of`,
  `without-view`, `with-split` on a leaf inside, `with-view-buffer`,
  `retarget-buffer`, and `with-pictures`. Each rebuilds
  `(AloemacsWindowTree Below top' bottom' earlier later)` with the
  names its arm bound. When `without-view` promotes a sibling
  subtree, that subtree keeps its own weights; the removed parent's
  weights go with it.
- `fresh-id`, `next-view`, `next-in`, `any-locked?`, `pictured?`,
  `locked-rects-equal?`, `right-rows`, `blank-rows`, `built-rows`,
  `reused-rows`, and `picture-for` do not read a weight.

### 5.2 The division

On `AloemacsWindowRect`, replacing `earlier` and the even cut:

```aloe
;; The ceiling of extent * earlier / (earlier + later), clamped so
;; neither side drops below least while the extent allows it.
(cut (extent Int) (least Int) (earlier Int) (later Int) Int
  (let ((share (((extent * earlier) + ((earlier + later) - 1)) / (earlier + later)))
        (lo (least min (extent / 2))))
    (lo max (share min (extent - lo)))))

(row-cut (earlier Int) (later Int) Int
  (self cut (self rows) 2 earlier later))

(column-cut (earlier Int) (later Int) Int
  (self cut ((self columns) - (self divider (self columns))) 1 earlier later))

;; Below reserves no row.
(top (earlier Int) (later Int) AloemacsWindowRect
  (self with (rows (self row-cut earlier later))))

(bottom (earlier Int) (later Int) AloemacsWindowRect
  (let ((cut (self row-cut earlier later)))
    (self with
      (y ((self y) + cut))
      (rows ((self rows) - cut)))))

(left (earlier Int) (later Int) AloemacsWindowRect
  (self with (columns (self column-cut earlier later))))

(right (earlier Int) (later Int) AloemacsWindowRect
  (let ((cut (self column-cut earlier later)) (divider (self divider (self columns))))
    (self with
      (x (((self x) + cut) + divider))
      (columns (((self columns) - divider) - cut)))))
```

`divider` stays `1 min extent`. `text-rows`, `positive?`, `same?`,
`contains?`, `spaces`, and `pad-row` are unchanged. `earlier` is
removed; nothing but `left` and `right` called it. In words:

```text
share = ceiling of extent * earlier / (earlier + later)
lo    = least min (extent / 2)
cut   = lo max (share min (extent - lo))

Below: extent = rows,              least = 2.
       top gets cut rows; bottom starts at y + cut and gets rows - cut.
Right: extent = columns - divider, least = 1.
       left gets cut columns; the bar is at x + cut;
       right starts at x + cut + divider and gets extent - cut.
```

The five walks pass each node's weights to the rect:
`(rect top earlier later)`, `(rect bottom earlier later)`,
`(rect left earlier later)`, and `(rect right earlier later)` in
`rect-for`, `view-at`, `positive-layout?`, `with-pictures`, and
`frame-rows`. Twenty call sites, all in `file.aloe`.

**Equal weights are today's cut.** With `1 1`,
`share = (extent + 1) / 2`, which is today's `earlier` on both
axes, and the clamp is the identity: `lo` never exceeds
`extent / 2`, and `share` never exceeds `extent - lo`. So an equal
tree, including one the shrink fallback is painting, has today's
rectangles at every extent, and `positive-layout?` decides the
fallback exactly as today. This was checked for every extent from
0 to 399 on both axes, and the scratch run of §6.3 confirms every
frame golden in the suite.

**The clamp exists for the unequal case after a terminal shrink.**
A dragged share can round to one row; with four rows available the
top keeps two, so the mode line that is the handle survives the
resize. The clamp never changes a drag's own result, because the
move already writes a legal cut (§5.6).

**The cut and its remainder each climb by at most one per added
cell**, for every pair of weights. This is what makes the search in
§5.3 a climb. It was checked for every pair of weights up to 39 and
every extent up to 199 on both floors.

Pinned values. Each row is `((AloemacsWindowRect new 0 0 0 0) cut extent least earlier later)`:

| Axis | extent | earlier, later | share | lo | cut, rest |
|---|---:|---|---:|---:|---|
| Below | 23 | 1, 1 | 12 | 2 | 12, 11 (today) |
| Below | 23 | 6, 17 | 6 | 2 | 6, 17 |
| Below | 11 | 6, 17 | 3 | 2 | 3, 8 |
| Below | 5 | 6, 17 | 2 | 2 | 2, 3 |
| Below | 4 | 6, 17 | 2 | 2 | 2, 2 |
| Below | 3 | 6, 17 | 1 | 1 | 1, 2 |
| Below | 2 | 6, 17 | 1 | 1 | 1, 1 |
| Below | 3 | 1, 1 | 2 | 1 | 2, 1 (today) |
| Below | 3 | 22, 1 | 3 | 1 | 2, 1 |
| Below | 3 | 1, 22 | 1 | 1 | 1, 2 |
| Below | 1 | 1, 1 | 1 | 0 | 1, 0 (today; fallback) |
| Right | 79 | 1, 1 | 40 | 1 | 40, 39 (today) |
| Right | 79 | 30, 49 | 30 | 1 | 30, 49 |
| Right | 119 | 30, 49 | 46 | 1 | 46, 73 |
| Right | 2 | 30, 49 | 1 | 1 | 1, 1 |
| Right | 1 | 30, 49 | 1 | 0 | 1, 0 (fallback) |
| Right | 0 | 1, 1 | 0 | 0 | 0, 0 (today; fallback) |

On rectangles, `((AloemacsWindowRect new 0 0 80 23) top 6 17)` is
`(0, 0, 80, 6)` and `bottom 6 17` is `(0, 6, 80, 17)`;
`((AloemacsWindowRect new 0 0 80 23) left 30 49)` is `(0, 0, 30, 23)`
and `right 30 49` is `(31, 0, 49, 23)`; the same rect with `1 1`
gives `(0, 0, 80, 12)`, `(0, 12, 80, 11)`, `(0, 0, 40, 23)`, and
`(41, 0, 39, 23)`, today's values. `((AloemacsWindowRect new 2 3 7 n) top 1 1)`
and `bottom 1 1` reproduce the window-bars table for `n` from 0 to
9, and `((AloemacsWindowRect new 2 3 n 4) left 1 1)` and `right 1 1`
reproduce its Right table.

### 5.3 The structural floor

A drag never leaves a leaf shorter than two rows or narrower than
one column, counting every leaf of both children of the dragged
split. A child that is itself split needs room for every leaf
inside it, divided by the weights that child already has. On the
tree:

```aloe
(min-rows () Int
  (self case
    (Leaf (view) 2)
    (Right (left right earlier later) ((left min-rows) max (right min-rows)))
    (Below (top bottom earlier later)
      (self rows-from ((top min-rows) + (bottom min-rows))
        (top min-rows) (bottom min-rows) earlier later))))

;; The smallest rows at or above the start whose cut, by this Below's own
;; weights, gives the top at least top-least and the bottom at least
;; bottom-least.
(rows-from (rows Int) (top-least Int) (bottom-least Int) (earlier Int) (later Int) Int
  (let ((cut ((AloemacsWindowRect new 0 0 0 rows) row-cut earlier later)))
    (if (if (cut >= top-least) ((rows - cut) >= bottom-least) #f)
        rows
        (self rows-from (rows + 1) top-least bottom-least earlier later))))

(min-columns () Int
  (self case
    (Leaf (view) 1)
    (Below (top bottom earlier later) ((top min-columns) max (bottom min-columns)))
    (Right (left right earlier later)
      (self columns-from (((left min-columns) + (right min-columns)) + 1)
        (left min-columns) (right min-columns) earlier later))))

(columns-from (columns Int) (left-least Int) (right-least Int) (earlier Int) (later Int) Int
  (let ((probe (AloemacsWindowRect new 0 0 columns 0)))
    (let ((cut (probe column-cut earlier later))
          (extent (columns - (probe divider columns))))
      (if (if (cut >= left-least) ((extent - cut) >= right-least) #f)
          columns
          (self columns-from (columns + 1) left-least right-least earlier later)))))
```

`min-rows`, `min-columns`, and the two helpers are public tree sends
with these names and shapes; the helpers are the search, written
once. A probe rect carries only the extent under test. The search
starts at the sum of the children's minimums, plus the divider on
the column axis, and climbs by one. Below the start one side must
fall short, because the two cuts add up to the extent. From the
start, §5.2's climb-by-one property makes "both children fit"
monotone in the extent, so the first fit is the smallest. The climb
terminates because both the cut and its remainder grow without
bound.

When both children are leaves this is the split minimum already in
force: four rows for a `Below`, three columns for a `Right`. A flat
floor would let a drag squeeze a nested `Below` to two rows, giving
its leaves one row each and erasing both mode lines, so the inner
handle and the outer handle would both vanish.

The sum is where the search starts, not the answer. A drag rewrites
only the dragged split's weights. A child keeps its own, and §5.2
divides whatever that child is given by them. A `Below` whose sides
need 4 and 2 needs 7 rows at equal weights, not 6, because the equal
cut of 6 is 3 and 3, and the inner cut of 3 is 2 and 1. A child
dragged earlier to `4 8` needs 10 rows before its top gets 4.

Pinned values, every weight `1 1` unless written:

| Tree | `min-rows` | `min-columns` |
|---|---:|---:|
| `Leaf` | 2 | 1 |
| `Below (A, B)` | 4 | 1 |
| `Below (A, B)` with `1 22` or `22 1` | 4 | 1 |
| `Right (A, B)` | 2 | 3 |
| `Right (A, B)` with `1 78` or `78 1` | 2 | 3 |
| `Below (Right (A, B), C)` | 4 | 3 |
| `Right (Below (A, B), C)` | 4 | 3 |
| `Below (Below (A, B), C)` | 7 | 1 |
| `Below (Below (A, B), C)` with the outer `4 8` | 10 | 1 |
| `Right (Right (A, B), C)` | 2 | 6 |
| `Below (Below (Below (A, B), C), D)` | 13 | 1 |
| `Right (Right (Right (A, B), C), D)` | 2 | 12 |

The `4 8` row reads: `(top min-rows)` is 4, `(bottom min-rows)` is 2,
the search starts at 6, and the cuts at 6 through 9 by `4 8` are 2,
3, 3, 3; at 10 the cut is 4 and the rest is 6.

### 5.4 The handles

A handle belongs to one split. The split is named by one `Int`: the
id of the first leaf of its later child, the bottom of a `Below` or
the right of a `Right`. That id names exactly one split. Walking up
from that leaf, every ancestor below the split is a first child, and
the split's later child is the first node on that walk that is a
later child; no second split can have the same first leaf of its
later child. The session stores that id while armed.

```aloe
(first-id () Int
  (self case
    (Leaf (view) (view id))
    (Below (top bottom earlier later) (top first-id))
    (Right (left right earlier later) (left first-id))))

;; The id that names this split. On a leaf, the leaf's own id; a leaf is
;; never a handle.
(handle-id () Int
  (self case
    (Leaf (view) (view id))
    (Below (top bottom earlier later) (bottom first-id))
    (Right (left right earlier later) (right first-id))))
```

Which cell is a handle is decided by one walk from the root with the
rectangles `rect-for` already walks. The ancestor wins:

```aloe
;; The split whose handle holds the cell: a Right's bar column, or the
;; last row of a Below's top child. None for a leaf or a cell outside.
(handle-at (column Int) (row Int) (rect AloemacsWindowRect) (Option AloemacsWindowTree)
  (self case
    (Leaf (view) (Option None))
    (Below (top bottom earlier later)
      (if (rect contains? column row)
          (if (row = (((rect y) + (rect row-cut earlier later)) - 1))
              (Option Some self)
              ((top handle-at column row (rect top earlier later)) case
                (Some (found) (Option Some found))
                (None () (bottom handle-at column row (rect bottom earlier later)))))
          (Option None)))
    (Right (left right earlier later)
      (if (rect contains? column row)
          (if (column = ((rect x) + (rect column-cut earlier later)))
              (Option Some self)
              ((left handle-at column row (rect left earlier later)) case
                (Some (found) (Option Some found))
                (None () (right handle-at column row (rect right earlier later)))))
          (Option None)))))
```

- At a `Right`: the cell is in the rectangle and its column is the
  bar column. That `Right` is the split.
- At a `Below`: the cell is in the rectangle and its row is the top
  child's last row. That `Below` is the split.
- Otherwise recurse into the child whose rectangle holds the cell. A
  cell in neither is no handle.

A bar cell on a mode-line row drags the `Below` above it, because
the `Below` is checked before its children. A mode-line cell to the
left of a bar drags the `Below` inside that `Right`. The bottom mode
line is never a top child's last row, so it never arms. In 002 the
`Below` arm has no boundary check and only recurses; 003 adds the
check (§8.1, §9.1).

The press runs this walk only from the two branches that answer
"unchanged" today:

- the no-leaf arm of `press-at`, where `view-at` answered `None`:
  a bar cell, or a cell outside every leaf. That arm becomes
  `(self press-handle column row)`.
- the `""` branch of `press-mode-line`, a mode-line cell that is not
  a label. `press-mode-line` keeps its three parameters and recovers
  the cell: the column is `(rect x) + index` and the row is
  `((rect y) + (rect rows)) - 1`, the leaf's last row. That branch
  becomes `(self press-handle ((rect x) + index) (((rect y) + (rect rows)) - 1))`.

A label cell stays the command. A text cell stays `place-in`, even
on the boundary row of a one-row child: `press-at` sends `place-in`
for a leaf shorter than two rows before any walk. The echo row and a
completion row stay `unchanged`, as `press-at` already answers
before it looks for a leaf. A press while `positive-layout?` is false
arms nothing, and a move then writes nothing: `press-handle` and
`drag-to` check it first.

### 5.5 The drag field and the session events

`AloemacsWindows` gains a last field:

```text
(define-class AloemacsWindows
  (fields
    (tree AloemacsWindowTree)
    (selected Int)
    (columns Int)
    (rows Int)
    (drag (Option Int)))
  ...)
```

`drag` is the id of §5.4 while armed and `None` otherwise. It is
not painted; the bar stays `|` and the mode line stays its row.
`with-size` and every `with` keep it; so does every product path,
because nothing in `file.aloe` constructs `AloemacsWindows` with
`new`. Two sends write it:

```aloe
(armed (id Int) AloemacsWindows
  (self with (drag (Option Some id))))

(disarmed () AloemacsWindows
  (self with (drag (Option None))))
```

On the session:

```aloe
(disarmed () (AloemacsSession H)
  (if (((self windows) drag) present?)
      (self with (windows ((self windows) disarmed)))
      self))

;; Arm the split whose handle holds the cell, unless a leaf in either
;; child is locked or the tree does not fit.
(press-handle (column Int) (row Int) (AloemacsSession H)
  (let ((windows (self windows)))
    (let ((root (self root-rect (windows columns) (windows rows))))
      (if ((windows tree) positive-layout? root)
          (((windows tree) handle-at column row root) case
            (None () (self unchanged))
            (Some (split)
              (if (split any-locked?)
                  (self unchanged)
                  (self with (windows (windows armed (split handle-id)))))))
          (self unchanged)))))

;; Rewrite the armed split's weights from the pointer. Nothing armed, or
;; a tree that does not fit, leaves the session.
(drag-to (column Int) (row Int) (AloemacsSession H)
  (let ((windows (self windows)))
    ((windows drag) case
      (None () (self unchanged))
      (Some (id)
        (let ((root (self root-rect (windows columns) (windows rows))))
          (if ((windows tree) positive-layout? root)
              (self with
                (windows
                  (windows with (tree ((windows tree) with-cut-at id column row root)))))
              (self unchanged)))))))
```

`root-rect` is the completion-aware root the click already uses, so
a handle is classified with the geometry of the last fit, never with
`(term columns)` or `(term rows)`. `disarmed` returns the receiver
itself when nothing is armed, so an unarmed session is unchanged by
identity, not by rebuilding. `(split any-locked?)` on the split node
is true when any leaf of either child is locked, which is §5.7.

`handle-event` disarms before a key. `handle-mouse` keeps its three
refusals and then follows the event table:

```aloe
(handle-event (event String) (AloemacsSession H)
  (cond
    ((self quit) (self unchanged))
    (((AloemacsMouse new event) event?) (self handle-mouse event))
    (else ((self disarmed) handle-key event))))

(handle-mouse (event String) (AloemacsSession H)
  (cond
    ((self searching) (self unchanged))
    (((self prompt) present?) (self unchanged))
    (((self pending) present?) (self unchanged))
    (else
      (let ((mouse (AloemacsMouse new event)))
        (cond
          ((mouse move?) (self drag-to (mouse column) (mouse row)))
          ((mouse down?)
            (if (mouse left?)
                ((self disarmed) press-at (mouse column) (mouse row))
                (self disarmed)))
          (else (self disarmed)))))))
```

`handle-key` is unchanged. In 001 the move arm is `(self unchanged)`;
002 replaces it with `drag-to` (§7.1, §8.1). The table this
implements:

| Event | While not armed | While armed |
|---|---|---|
| `mouse down left` on a handle of a split with no locked leaf in either child | Arms. Nothing else changes: selection, points, origins, echo, frame | Re-arms on that handle. Nothing else changes |
| `mouse down left` on a handle of a split with a locked leaf in either child | Unchanged | Disarms. Nothing else changes |
| `mouse down left` anywhere else | Today's path: a label is its command, text places, chrome is unchanged | Disarms, then today's path |
| `mouse move` | Unchanged | Rewrites the armed split's weights per §5.6. A missing split, an empty interval, or a non-positive layout leaves the tree |
| `mouse up left` | Unchanged | Disarms. The weights stay what the last move wrote |
| `mouse down` or `mouse up` with middle or right | Unchanged | Disarms. Nothing else changes |
| A key | Today's path | Disarms, then today's path |
| Any mouse string during a search, a prompt, or a pending prefix | Unchanged | Unchanged; see below |
| Any event after quit | Unchanged | Unchanged |

A search, a prompt, and a pending prefix keep refusing every mouse
string before the cell is classified. They cannot coexist with an
armed drag: the arming press is refused while they are active, and
the key that starts one of them disarms first. A quit session is
never armed, because the key that sets quit disarms first.

A move rewrites weights with no fit and no echo. The runner's next
`ensure-visible` and frame read the weights back. That fit may
scroll the selected window to keep its point inside the new
rectangle, as it does after a terminal resize; the drag itself
stores no origin, changes no point, and changes no selection. A
terminal resize between events keeps the armed id; the next move
uses the new geometry. The press alone and the release alone paint
the frame painted before them.

### 5.6 What a move writes

A move while armed maps the pointer to a cut for the armed split, in
the rectangle that split has under the last fit, clamped to the
structural interval, and writes the two cell counts as the weights.
At that size the formula reproduces the cut exactly; after a resize
it scales.

```text
Below: wanted = (row - rect.y) + 1     ; the pointer row becomes the top child's last row
       cut in [min-rows (top), rows - min-rows (bottom)]
       weights become cut, rows - cut
Right: wanted = column - rect.x        ; the pointer column becomes the bar column
       extent = columns - divider
       cut in [min-columns (left), extent - min-columns (right)]
       weights become cut, extent - cut
```

An empty interval means the move changes nothing. A pointer outside
the root rectangle, or outside the split's rectangle, is clamped,
not refused. On the tree:

```aloe
;; Rewrite the weights of the split that id names, from a pointer cell,
;; in the rectangle the split has under rect. The tree is unchanged when
;; no split has that id or the interval is empty.
(with-cut-at (id Int) (column Int) (row Int) (rect AloemacsWindowRect) AloemacsWindowTree
  (self case
    (Leaf (view) self)
    (Below (top bottom earlier later)
      (cond
        (((bottom first-id) = id)
          (let ((lo (top min-rows)) (hi ((rect rows) - (bottom min-rows))))
            (if (lo > hi)
                self
                (let ((cut (lo max (((row - (rect y)) + 1) min hi))))
                  (AloemacsWindowTree Below top bottom cut ((rect rows) - cut))))))
        (((top find-view id) present?)
          (AloemacsWindowTree Below
            (top with-cut-at id column row (rect top earlier later)) bottom earlier later))
        (((bottom find-view id) present?)
          (AloemacsWindowTree Below
            top (bottom with-cut-at id column row (rect bottom earlier later)) earlier later))
        (else self)))
    (Right (left right earlier later)
      (cond
        (((right first-id) = id)
          (let ((extent ((rect columns) - (rect divider (rect columns))))
                (lo (left min-columns)))
            (let ((hi (extent - (right min-columns))))
              (if (lo > hi)
                  self
                  (let ((cut (lo max ((column - (rect x)) min hi))))
                    (AloemacsWindowTree Right left right cut (extent - cut)))))))
        (((left find-view id) present?)
          (AloemacsWindowTree Right
            (left with-cut-at id column row (rect left earlier later)) right earlier later))
        (((right find-view id) present?)
          (AloemacsWindowTree Right
            left (right with-cut-at id column row (rect right earlier later)) earlier later))
        (else self)))))
```

The first arm of each `cond` is the split itself: its later child's
first leaf is the id. The next two descend into the child that holds
the id with that child's rectangle. The children are unchanged by a
rewrite; only the two weights are new. In 002 the `Below` arm has
only the two descents and `else`; 003 adds the first arm.

The weights written are positive, because `lo` is at least 2 on
rows and at least 1 on columns, and `hi` leaves the other side at
least its minimum. At the size of the drag, §5.2 gives `share` equal
to `cut` exactly, since `cut * (cut + rest) / (cut + rest)` is
`cut`, and the clamp is the identity because `cut` is inside the
interval. So the next frame paints the bar at the pointer column, or
the top child's last row on the pointer row.

Pinned cases at 80 by 24, root rectangle `(0, 0, 80, 23)`, every
weight `1 1` before the drag. "A's mode line" is the boundary row of
the `Below` whose top child A is in:

| Tree | Drag | Result |
|---|---|---|
| `Right (A, B)`, bar at column 40 | to column 30 | A `(0,0,30,23)`, bar 30, B `(31,0,49,23)`; weights `30 49` |
| that tree, then `ensure-visible 120 24` | none | A 46 columns, bar 46, B 73 columns; weights still `30 49` |
| `Right (A, B)` | to column 0 | A `(0,0,1,23)`, bar 1, B `(2,0,78,23)`; weights `1 78` |
| `Right (A, B)` | to column 79, or 200 | A `(0,0,78,23)`, bar 78, B `(79,0,1,23)`; weights `78 1` |
| `Below (A, B)`, A's mode line at row 11 | to row 5 | A `(0,0,80,6)`, B `(0,6,80,17)`; weights `6 17` |
| that tree, then `ensure-visible 80 12` | none | A 3 rows, B 8 rows; weights still `6 17` |
| `Below (A, B)` | to row 0 | A 2 rows; weights `2 21` |
| `Below (A, B)` | to row 22, or 100 | A `(0,0,80,21)`, B `(0,21,80,2)`; weights `21 2` |
| `Right (Right (A, B), C)`, bars at 20 and 40 | the inner bar to column 10 | A `(0,0,10,23)`, bar 10, B `(11,0,29,23)`; inner `10 29`, outer `1 1`, outer bar still 40 |
| `Right (Right (A, B), C)` | the outer bar to column 0 | the left child gets 3 columns: A `(0,0,1,23)`, bar 1, B `(2,0,1,23)`; outer bar at column 3; C `(4,0,76,23)`; outer `3 76`, inner `1 1` |
| `Right (Right (Right (A, B), C), D)`, bars at 10, 20, 40 | the outer bar to column 0 | the left child gets 6 columns: A 1, bar 1, B 1, bar 3, C 2; outer bar at column 6; D `(7,0,73,23)`; outer `6 73`. The summed minimum, 5, would give the innermost `Right` 2 columns and one leaf none |
| `Below (Below (A, B), C)`, boundaries at rows 5 and 11 | the inner boundary to row 1 | A `(0,0,80,2)`, B `(0,2,80,10)`; inner `2 10`, outer `1 1` |
| `Below (Below (A, B), C)` | the outer boundary, B's mode line at row 11, to row 0 | the top child gets 4 rows: A 2, B 2; C `(0,4,80,19)`; outer `4 19`, inner `1 1` |
| `Below (Below (Below (A, B), C), D)`; today A 3, B 3, C 6, D 11, boundaries at 2, 5, 11 | the outer boundary to row 0 | the middle child gets 7 rows: inner 4 (A 2, B 2), C 3; D 16; outer `7 16`. The summed minimum, 6, would cut 3 and 3 and leave B one row |
| that tree with the middle already dragged to `4 8` (its boundary at row 5 to row 3) | the outer boundary to row 0 | the middle child gets 10 rows: inner 4 (A 2, B 2), C 6; D 13; outer `10 13` |
| `Below (Right (A, B), C)`, inner bar at column 40 on rows 0–11, boundary at row 11 | the bar at `(40, 3)` to column 30 | A `(0,0,30,12)`, bar 30, B `(31,0,49,12)`; C `(0,12,80,11)`; inner `30 49`, outer `1 1` |
| `Below (Right (A, B), C)` | the boundary at `(40, 11)`, the bar cell, or at `(10, 11)` or `(50, 11)`, to row 3 | the top child gets 4 rows: A `(0,0,40,4)`, B `(41,0,39,4)`; C `(0,4,80,19)`; outer `4 19` |
| `Right (Below (A, B), C)`, inner boundary at row 11 on columns 0–39, bar at 40 | the boundary at `(10, 11)` to row 3 | A `(0,0,40,4)`, B `(0,4,40,19)`; C `(41,0,39,23)`; inner `4 19` |
| `Right (Below (A, B), C)` | the bar at `(40, 11)` to column 30 | the `Right`: A `(0,0,30,12)`, B `(0,12,30,11)`, bar 30, C `(31,0,49,23)`; outer `30 49` |

On the 40 by 10 screen, root `(0, 0, 40, 9)`: `Right (A, B)` has
its bar at column 20, and a drag to column 10 gives `10 29`,
A `(0,0,10,9)`, B `(11,0,29,9)`. `Below (A, B)` has its boundary at
row 4, and a drag to row 2 gives `3 6`, A `(0,0,40,3)`,
B `(0,3,40,6)`.

### 5.7 Lock

A press on a handle arms only when neither child of that split has
a locked leaf, which is `any-locked?` on the split node. Every leaf
of both children is in the resize domain of that handle. The
exact-geometry comparison delete uses would let the bar follow the
pointer only at positions where rounding happened to spare the
locked leaf, so the handle would stick and skip. The refusal is
blanket over the split's two children, not over the tree. A locked
leaf elsewhere does not refuse. A terminal resize still recomputes
every rectangle, locked or not, as today. Lock does not block a
move on a split that was armed before the lock, because a lock
toggle is a key and the key disarmed first.

### 5.8 The move string and the host

The mouse string gains a second shape. A mouse event is one of
these entire strings, fields separated by one space, with no extra
spaces, coordinates canonical decimals, 0-based:

```text
mouse <down|up> <left|middle|right> <column> <row>
mouse move <column> <row>
```

A move carries no button. Mode `1002` delivers motion only while a
button is held, and the editor's armed state is the authority for
what a move means. The match is the whole string.

Accepted: `mouse move 0 0`, `mouse move 30 5`, and every string the
mouse spec accepts. Rejected, and therefore keys:
`mouse move left 30 5`, `mouse move 30`, `mouse move 030 5`,
`mouse move 30 5 ` with a trailing space, `mouse move -1 5`,
`mouse  move 30 5`, and `Mouse move 30 5`.

`AloemacsMouse` keeps one field and gains `move?`:

| Send | Result |
|---|---|
| `(mouse event?)` | The whole string matches either shape |
| `(mouse move?)` | The action field is `move` |
| `(mouse down?)` | The action field is `down`; false on a move |
| `(mouse left?)` | The button field is `left`; false on a move |
| `(mouse column)`, `(mouse row)` | The decimals, as `Int`, on either shape |

The session parses with the String messages it already uses:
`starts-with?`, `take`, `drop`, `len`, `=`, `find`. A move has an
action of five characters and no button field; the coordinates
follow the action directly. `handle-event` does not send `column`
or `row` unless `event?` is true.

In `host/racket/term.rkt`:

- `mouse-event-pattern` accepts both shapes, so `read-key` skips a
  move as it skips a press:

  ```racket
  #rx"^mouse ((down|up) (left|middle|right)|move) (0|[1-9][0-9]*) (0|[1-9][0-9]*)$"
  ```

- `tmousemsg->aloe-mouse` formats kind `move` at a `tpoint` whose
  `tpoint-x` and `tpoint-y` are exact integers `>= 0` as
  `mouse move <x> <y>`. It does not read the three held flags or
  the `button` field on a move. `button-down` and `button-up`
  format as today. A wheel kind, a negative or non-integer
  component, and a press or release with a button other than
  `left`, `middle`, or `right` stay `#f` and are skipped by
  `read-next-key`, which is unchanged.

  `(make-tmousemsg 'move (tpoint 30 5) #t #f #f)` formats as
  `mouse move 30 5`. `(make-tmousemsg 'move (tpoint 4 2) #f #f #f 'left)`
  formats as `mouse move 4 2`. `(make-tmousemsg 'move (tpoint -1 2) #t #f #f)`
  is `#f`. `(make-tmousemsg 'wheel-up (tpoint 4 2) #f #f #f)` is `#f`.

- `term.rkt` contains no mouse mode: neither `1000`, `1002`,
  `1003`, nor `term-enable-mouse`.

In `host/racket/aloemacs-run.rkt`, `run-aloemacs` writes, in the
before thunk of its `dynamic-wind`:

```text
ESC [ ? 1 0 4 9 h ESC [ ? 1 0 0 2 h ESC [ ? 1 0 0 6 h
```

and in the after thunk, on the normal path and on the exception
path:

```text
ESC [ ? 1 0 0 2 l ESC [ ? 1 0 0 6 l ESC [ ? 1 0 4 9 l
```

Flush after each write. It writes neither `1000` nor `1003`.
`with-term`'s cleanup writes `1003l` and `1006l` afterwards; the
runner's own `1002l` is what turns motion reporting off for the
shell. The comment above the bytes says motion while a button is
held, `1002`, in SGR form, inside the alternate screen.
`run-aloemacs-with-hosts`, `run-aloemacs-with-term`, and
`call-with-tty-term-receiver` do not write those bytes. A scripted
frame stays free of them. `gel-run.rkt` and `term-run.rkt` contain
no `read-event`, `1000`, `1002`, `1003`, or `term-enable-mouse`.

Term gains no method. The six-row catalog of the mouse spec stays.
Host values that cross stay `Int`, `Bool`, `String`, and
`(List String)`.

### 5.9 What this series leaves in place

`Text` gains no method. `SPEC.md` gains no row. The kernel gains no
message. The press and release strings, and SGR `1006`, stay as the
mouse spec left them. `split-below`, `split-right`,
`delete-window`, `other-window`, and the lock toggle stay the same
sends with the same refusals and the same echo tokens; a split still
writes `1 1`, delete still promotes the sibling, and the lock
comparison inside delete still compares four coordinates under the
weighted division. The label cells and `label-at` stay as
mode-buttons left them. Bar colors, the `|` bar, and the no-rule-row
`Below` stay with window bars. The frame stays one `String`. The
runner still fits, records pictures, and frames around each event,
and reads one string per event. The picture cache gains no key: it
already matches on `columns` and `rows`, so a drag invalidates a
leaf's picture by geometry, and a leaf whose size did not change
reuses its rows at its new position. Gel's runner is untouched. No
new class: the ordered `define-class` inventory stays as it is.
`AloemacsSession` keeps fourteen fields.

## 6. Layer 000 — weights

### 6.1 Product

In `file.aloe`:

1. `Below` and `Right` gain `(earlier Int) (later Int)` (§5.1).
2. Every `case` arm on `Below` binds `(top bottom earlier later)`;
   every arm on `Right` binds `(left right earlier later)`. Thirty
   arms.
3. Every construction passes the weights through: twenty-four
   rebuilds in `with-toggled-lock`, `without-pictures`,
   `without-pictures-of`, `without-view`, `with-split` on a leaf
   inside, `with-view-buffer`, `retarget-buffer`, and
   `with-pictures` append `earlier later`; the two in `with-split`'s
   `Leaf` arm append `1 1`.
4. On the rect, `earlier` is removed and `cut`, `row-cut`,
   `column-cut`, `top`, `bottom`, `left`, and `right` are as §5.2
   writes them.
5. The twenty walk sites in `rect-for`, `view-at`,
   `positive-layout?`, `with-pictures`, and `frame-rows` pass the
   node's weights.

Nothing else changes. The session, `AloemacsWindows`, `AloemacsMouse`,
the host, and the runner are untouched. No press arms anything; a
press on a bar and a non-label mode-line press still return the
receiver.

### 6.2 Examples

`s0` is the mouse spec's base session,
`((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)`,
with the fs double of `tests/aloemacs/mouse.rkt`.

- `(((s0 split-right) windows) tree)` equals
  `(AloemacsWindowTree Right (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 1 1)`
  with the views the split already stores. `split-below` gives the
  `Below` with `1 1`. A second split inside gives a nested node with
  `1 1` under a parent that keeps `1 1`.
- Every rectangle, frame, refusal, cursor, and Fs count in the
  existing suite is unchanged. That is the migration of §6.3 and the
  wider suite of §10.
- A constructed `Right (Leaf 0, Leaf 1)` with `30 49`, in a
  configuration at 80 by 24: `rect-for 0` on the root `(0,0,80,23)`
  is `(0,0,30,23)`, `rect-for 1` is `(31,0,49,23)`, `view-at 30 5`
  is `None`, `view-at 31 5` is view 1, `positive-layout?` is true.
  `ensure-visible 120 24` on that session gives `(0,0,46,23)` and
  `(47,0,73,23)` and the tree still reads `30 49`. At `3 24`,
  root `(0,0,3,23)`: `(0,0,1,23)` and `(2,0,1,23)`. At `2 24`:
  `(0,0,1,23)` and `(2,0,0,23)`, and `positive-layout?` is false, so
  `fit-rect` is the root and the frame is the one-view frame.
- A constructed `Below (Leaf 0, Leaf 1)` with `6 17` at 80 by 24:
  `(0,0,80,6)` and `(0,6,80,17)`. At 80 by 12: `(0,0,80,3)` and
  `(0,3,80,8)`. At 80 by 6, root rows 5: `(0,0,80,2)` and
  `(0,2,80,3)`. At 80 by 5: `(0,0,80,2)` and `(0,2,80,2)`. At 80 by
  4: `(0,0,80,1)` and `(0,1,80,2)`; the top leaf is all text and the
  bottom paints its mode line on row 2. At 80 by 3: `(0,0,80,1)` and
  `(0,1,80,1)`. At 80 by 2, root rows 1: `(0,0,80,1)` and
  `(0,1,80,0)`, the fallback.
- Frames of an unequal tree compose as today's composer composes
  them. On a 9 by 6 terminal, root `(0,0,9,5)`, two buffers, 41 with
  the line `abcdefgh` and 42 with `ABCDEFGH`, view 0 on 41 and view
  1 on 42, `Right (Leaf 0, Leaf 1)` with `2 6`: the leaves are
  `(0,0,2,5)` and `(3,0,6,5)`, and row 0 of `frame-rows` is
  `ab|ABCDEF`. With `1 1` it is `abcd|ABCD`, today's row. The mode
  rows follow the mode-line spec at widths 2 and 6, inside the bar
  colors window bars gives them.
- Preservation. Start from `Below (Right (Leaf 0, Leaf 2) 30 49, Leaf 1) 6 17`
  in a session. After `with-toggled-lock 2`, `without-pictures`,
  `without-pictures-of 41`, `with-view-buffer 0 b`,
  `retarget-buffer 41 42 0 0 (Position new 0 0)`, and
  `with-pictures` at the root, both splits read the same weights.
  `with-split` on view 0 gives `Below (Right (Below (Leaf 0, Leaf 3) 1 1, Leaf 2) 30 49, Leaf 1) 6 17`.
  `without-view 1` gives `Right (Leaf 0, Leaf 2) 30 49`: the removed
  `Below`'s `6 17` goes with it. `without-view 2` gives
  `Below (Leaf 0, Leaf 1) 6 17`: the removed `Right`'s `30 49` goes
  with it. Through the session, `split-below`, `split-right`,
  `delete-window`, `other-window`, `toggle-window-lock`,
  `find-file-submitted`, `ensure-visible`, `record-pictures`, and a
  key each leave every surviving split's weights as they were.
- Types. `(AloemacsWindowTree Below a b)`, `(AloemacsWindowTree Below a b 1)`,
  `(AloemacsWindowTree Below a b 1 1 1)`, and
  `(AloemacsWindowTree Right a b "1" 1)` are rejected. `cut` types
  as `Int` with four `Int` arguments and rejects three and five.
  `row-cut` and `column-cut` type as `Int` with two `Int` arguments.
  `top`, `bottom`, `left`, and `right` type as `AloemacsWindowRect`
  with two `Int` arguments and reject zero, one, and three.
  `(rect earlier 5)` is rejected. Read as data, the `Below` payload
  is `(fields (top AloemacsWindowTree) (bottom AloemacsWindowTree) (earlier Int) (later Int))`
  and `Right` is `(fields (left AloemacsWindowTree) (right AloemacsWindowTree) (earlier Int) (later Int))`;
  the rect's fields, the configuration's fields, the session's
  fourteen fields, and the ordered `define-class` list are
  unchanged.

### 6.3 Migration

The failing list after the product edit is the inventory. This
section is a scratch run of the suite on a copy of the tree with
§6.1 applied: 18 files failed, every one for a split construction, a
`case` arm, a declaration pin, or a rect send, and after these edits
the whole suite was green with product changes only in `file.aloe`.
Line numbers are from that run; search again before fixing the
checkpoint's scope.

**Helpers.** Each of these files builds its trees through local
`below` and `right` helpers of the shape
`` (define (below a b) `(AloemacsWindowTree Below ,a ,b)) ``. Both
gain ` 1 1` before the closing paren. One edit per helper:

| File | Lines |
|---|---|
| `completion-frame.rkt` | 36–37 |
| `completion-page-frame.rkt` | 36–37 |
| `mode-buttons-paint.rkt` | 314–315 |
| `mode-line-split-views.rkt` | 31–32 |
| `window-bars-one-view.rkt` | 48–49 |
| `window-bars-split.rkt` | 53–54 |
| `window-point.rkt` | 62–63 |
| `windows-delete-and-other.rkt` | 73–74 |
| `windows-layout-and-rendering.rkt` | 65–66 |
| `windows-lock.rkt` | 73–74 |
| `windows-split.rkt` | 73–74 |

**Inline constructions.** Each gains ` 1 1` after its second child:

| File | Lines | Forms |
|---|---|---|
| `completion-page-session.rkt` | 428, 431 | a `Right` holding a `Below` |
| `completion-session.rkt` | 590, 593, 730 | a `Right` holding a `Below`, and a `Right` |
| `idle-echo.rkt` | 139, 168 | a `Below` and a `Right`, each inside an `AloemacsWindows new` |
| `mode-line-one-view.rkt` | 209 | a `Right` |
| `window-pictures.rkt` | 121 | a `Right` rebuilt around a planted picture |
| `windows-layout-and-rendering.rkt` | 153, 157 | `'(AloemacsWindowTree Right a b)` and the `Below` |
| `windows-state.rkt` | 62–65 | the four forms of the `tree` helper |
| `windows-state-foundation.rkt` | 174–176 | the three forms of `tree` |

**`case` arms.** Each binds the two new names:

| File | Lines | Today | 000 |
|---|---|---|---|
| `mode-line-one-view.rkt` | 219, 221, 230 | `(Right (a b) b)` | `(Right (a b e l) b)` |
| `window-pictures.rkt` | 112 | `(Right (left right)` | `(Right (left right earlier later)` |

**Declaration pins.** These read `file.aloe` as data and pin the
constructor payloads. Each gains `(earlier Int) (later Int)` on both
split lines:

| File | Lines |
|---|---|
| `windows-state.rkt` | 635–636 |
| `windows-state-foundation.rkt` | 143–144 |

**Rect sends.** These send the four geometry methods directly. Each
gains ` 1 1`:

| File | Lines | Sends |
|---|---|---|
| `window-bars-split.rkt` | 248–249, 258–259 | `(,(rect 2 3 7 n) top)`, `bottom`, `(,(rect 2 3 n 4) left)`, `right` |
| `mode-buttons-paint.rkt` | 398–399 | `((AloemacsWindowRect new 0 0 9 3) top)` and `bottom` |

**Keep rejected.** `windows-state-foundation.rkt` lines 201–203 send
`(AloemacsWindowTree Below tree v4)`, `(AloemacsWindowTree Right v4 tree)`,
`(AloemacsWindowTree Below tree)`, and
`(AloemacsWindowTree Right tree tree tree)` inside a rejection loop.
Two and three payloads are still the wrong count; those lines do
not change.

Every expected rectangle, row, frame, refusal, cursor, origin, and
Fs count in those files stays as it is: 000 changes construction
spelling only. Keep every whole-frame assertion; do not replace one
with a substring check. `tests/aloemacs/mouse.rkt`,
`tests/aloemacs/mode-buttons-press.rkt`, and
`tests/parenthetical-construction/session.rkt` construct no split
and need no edit in 000. The files that pin the ordered
`define-class` list stay green: no class is added.

### 6.4 Focused proof

Write `tests/aloemacs/split-drag-weights.rkt` first and watch it
fail. It uses a checked driver, loads `main.aloe` with the fs double
of `tests/aloemacs/mouse.rkt`, builds expected values from raw
constructors and selectors, and does not open a TTY. "Equals" is
`(check actual expected)` through the driver, as `mouse.rkt` spells
`same`. Prove:

1. **Types and arities.** Every rejection and every type in the last
   item of §6.2, plus the declaration pins read as data.
2. **The cut.** Every row of §5.2's pinned table through `cut` on a
   probe rect. `row-cut` and `column-cut` on `(0,0,80,23)` with
   `1 1`, `6 17`, and `30 49`. `cut` with `1 1` equals today's
   `(extent + 1) / 2` on the row axis for every extent from 0 to 30,
   and on the column axis equals today's `((columns - divider) + 1) / 2`
   for every `columns` from 0 to 30.
3. **The four rectangles.** The `top`, `bottom`, `left`, and
   `right` values of §5.2, including the window-bars tables with
   `1 1` for extents 0 through 9.
4. **A split writes `1 1`.** The first item of §6.2.
5. **An unequal tree lays out.** The `Right 30 49` and
   `Below 6 17` items of §6.2 at every size they list, through
   `rect-for`, `view-at`, `positive-layout?`, `fit-rect`, and
   `ensure-visible`, with the weights read back from the tree after
   each resize.
6. **An unequal frame composes.** The 9 by 6 item of §6.2: row 0
   of `frame-rows` is `ab|ABCDEF`, and the `1 1` tree gives
   `abcd|ABCD`. Assert row 0 and that the list has five rows. The
   mode rows are wrapped in the bar color, so their string length is
   not the column count; leave them to the existing frame goldens.
7. **Preservation.** Every send in the preservation item of §6.2,
   reading both weights after each.
8. **Today's frames.** On `s0`, the frames at 80 by 24 after
   `split-right`, after `split-below`, and after both, and the frame
   at 40 by 10 after `split-below`, are byte for byte the frames the
   tree paints before this checkpoint. Capture them with a helper
   built from the row rules of the window-bars and mode-buttons
   specs, or pin them as literals; do not send a composer to build
   the expectation.
9. **Pictures.** On a split session with weights `30 49`,
   `record-pictures` then `frame` yields the same bytes as `frame`
   before recording, and a second `frame` yields them again.
10. **No press arms.** On `(s0 split-right)`, `mouse down left 40 5`
    returns a session equal to the receiver. On `(s0 split-below)`,
    `mouse down left 0 11` returns the receiver. 002 and 003 replace
    this item.

Stop with this file, the migrated files, and the wider suite of §10
green.

## 7. Layer 001 — motion and the field

### 7.1 Product

1. `AloemacsWindows` gains `(drag (Option Int))` as its last field,
   and `armed` and `disarmed` (§5.5). `main.aloe`'s `new*` for
   `initial-windows` gains `(drag (Option None))`; `new*` requires
   every field.
2. The session gains `disarmed` (§5.5). `handle-event` sends
   `((self disarmed) handle-key event)` for a key. `handle-mouse`
   takes the shape in §5.5 with the move arm reading
   `((mouse move?) (self unchanged))`. The press arm sends
   `((self disarmed) press-at ...)`; the release and the other
   buttons send `(self disarmed)`.
3. `AloemacsMouse` gains `move?`, and `event?` accepts the second
   shape (§5.8).
4. `term.rkt`: `mouse-event-pattern` and `tmousemsg->aloe-mouse`
   (§5.8).
5. `aloemacs-run.rkt`: the mode bytes and their comment (§5.8).

Nothing arms in 001. `press-at` and `press-mode-line` are unchanged.
The tree gains no send.

### 7.2 Examples

- `(AloemacsMouse new "mouse move 30 5")`: `event?` true, `move?`
  true, `down?` false, `left?` false, `column` 30, `row` 5.
  `(AloemacsMouse new "mouse down left 4 2")`: `move?` false, the
  rest as the mouse spec says. Every rejected string in §5.8 has
  `event?` false.
- `(term read-event)` on a scripted receiver whose thunk yields
  `mouse move 30 5` then `x` returns the move string, then `x`.
  `(term read-key)` on the same script returns `x`. A script of
  `mouse move 030 5` then `x` returns `mouse move 030 5` from
  `read-key`, because the leading zero is not the grammar.
- The formatter values of §5.8.
- On `s0` with echo `saved`, `handle-event "mouse move 30 5"`
  returns a session equal to the receiver, echo `saved`. The same
  on `(s0 split-right)`, on `(s0 split-below)`, on the 40 by 10
  split, during a search, during a prompt, during a pending prefix,
  and after quit.
- `((s0 windows) drag)` is `None`. After every one of `split-below`,
  `split-right`, `other-window`, `delete-window`,
  `toggle-window-lock`, `ensure-visible 120 24`, `record-pictures`,
  `find-file-submitted "b.txt"`, a key, a press, and a release, it
  is still `None`.
- A constructed armed configuration: `w` is `((s0 windows) armed 7)`;
  `(w drag)` is `(Option Some 7)`. `(w with-size 120 24)`,
  `(w with-split 0 0 (Position new 0 0) #t)`, `(w with-toggled-lock)`,
  `(w with-buffer b)`, and `(w without-buffer 41 b)` each keep
  `(Option Some 7)`. `(w disarmed)` is `None`.
- `a` is `(s0 with (windows ((s0 windows) armed 7)))`. Each of
  `handle-event "x"`, `"left"`, `"ctrl-x"`, `"find"`, `"escape"`,
  `"mouse up left 4 0"`, `"mouse down middle 4 0"`,
  `"mouse up right 4 0"`, and `"mouse down left 4 0"` returns a
  session whose `drag` is `None` and which otherwise equals
  `(s0 handle-event <the same string>)`. `handle-event "mouse move 4 0"`
  on `a` returns a session equal to `a` in 001; 002 changes this
  one row.
- Through the runner at 80 by 24 on `a.txt`, the script `x`,
  `mouse move 3 3`, `escape` writes three frames. The third equals
  the second. Each iteration is `(columns 80)`, `(rows 24)`,
  `(write frame)`, `flush`, `(key k)`; a move consumes one thunk
  result like a key.

### 7.3 Migration

The failing list after the product edit is the inventory. This
section is a scratch run of the suite on a copy of the tree with
000's migration done and the `drag` field added: every positional
`AloemacsWindows new` fails for arity, the labeled one in
`runner.rkt` fails for a missing field, and the declaration pins
fail on the payload. Search again before fixing the checkpoint's
scope.

**Positional constructions.** Each `(AloemacsWindows new tree selected columns rows)`
gains ` (Option None)` as a fifth argument, written literally. The
count is the number of forms in that file:

| File | Forms |
|---|---:|
| `buffer-session.rkt` | 3 |
| `buffer-value.rkt` | 3 |
| `completion-frame.rkt` | 1, the `windows` helper |
| `completion-page-frame.rkt` | 1, the `windows` helper |
| `completion-page-session.rkt` | 3 |
| `completion-session.rkt` | 5 |
| `echo-session.rkt` | 1 |
| `file-session.rkt` | 3 |
| `idle-echo.rkt` | 2 |
| `keymap-prefix.rkt` | 5 |
| `keymap-session.rkt` | 5 |
| `kill-session.rkt` | 2 |
| `minibuffer-session.rkt` | 2 |
| `minibuffer-value.rkt` | 3 |
| `mode-buttons-paint.rkt` | 1, the `session` helper |
| `mode-line-one-view.rkt` | 3 |
| `mode-line-split-views.rkt` | 1, the `windows` helper |
| `motion-editor.rkt` | 1 |
| `mouse.rkt` | 1 |
| `prompt-commands-find-file.rkt` | 2 |
| `prompt-commands-save-as.rkt` | 2 |
| `prompt-commands-select-buffer.rkt` | 2 |
| `safe-cells.rkt` | 1 |
| `search-session.rkt` | 2 |
| `undo-session.rkt` | 1 |
| `viewport-editor.rkt` | 3 |
| `visited-unchanged.rkt` | 2 |
| `window-bars-one-view.rkt` | 1, the `windows` helper |
| `window-bars-split.rkt` | 1, the `config` helper |
| `windows-buffer-identity.rkt` | 3 |
| `windows-delete-and-other.rkt` | 1, the `config` helper |
| `windows-layout-and-rendering.rkt` | 1, the `config` helper |
| `windows-lock.rkt` | 1, the `config` helper |
| `windows-split.rkt` | 1, the `config` helper |
| `windows-state-foundation.rkt` | 3: the `windows` helper at 65–68 and the two typed sends at 188–189 |
| `windows-state.rkt` | 2 |
| `tests/parenthetical-construction/session.rkt` | 1 |

**Labeled constructions.** `tests/aloemacs/runner.rkt` line 58 and
`examples/aloemacs/main.aloe` line 39 use `new*`; each gains
`(drag (Option None))` after `(rows 0)`.

**Declaration pins.** Each pins
`(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int))`
and gains `(drag (Option Int))`:

| File | Line |
|---|---|
| `mode-line-row.rkt` | 35 |
| `window-bars-one-view.rkt` | 171 |
| `window-bars-split.rkt` | 210 |
| `windows-layout-and-rendering.rkt` | 475 |
| `windows-state.rkt` | 638 |
| `windows-state-foundation.rkt` | 146 |

`mode-line-row.rkt` constructs nothing and fails only on this pin;
the other five also construct.

**Keep rejected.** `windows-state-foundation.rkt` lines 207–209
send `(AloemacsWindows new tree 19 80)`, `(AloemacsWindows new tree 19 80 24 0)`,
and the type-wrong forms inside a rejection loop. Four arguments,
five with a wrong type, and six are still rejected; those lines do
not change. The expectation for `(AloemacsWindows new tree 19 80 24 0)`
reads the same: the fifth argument is an `Int`, not an
`(Option Int)`.

**Host pins.** `tests/aloemacs/mouse.rkt` item 5 pins that a `move`
formats as `#f`; it becomes `mouse move 4 2` for the constructed
value there. Item 6 pins the phrases `[?1000h` and `[?1000l` in the
runner; they become `[?1002h` and `[?1002l`. Its list of phrases
absent from the runner gains `1000`; its lists of phrases absent
from `term.rkt`, `gel-run.rkt`, and `term-run.rkt` gain `1002`.
`tests/aloemacs/alternate-screen.rkt` defines `buttons-on` and
`buttons-off` as the `1000` phrases; they become the `1002`
phrases, and its test names say motion.

No other file changes. Every expected session, frame, and count in
the migrated files stays as it is: 001 changes construction
spelling, one formatter pin, and the mode phrases. The scratch run
confirmed the suite green after these edits.

### 7.4 Focused proof

Write `tests/aloemacs/split-drag-motion.rkt` first and watch it
fail. It uses a checked driver, `make-term-receiver`, and
`run-aloemacs-with-hosts`, and does not open a TTY. Prove:

1. **Types and arities.** `move?` types as `Bool` and rejects an
   argument. `armed` types as `AloemacsWindows` with one `Int` and
   rejects zero and two arguments and a `String`. `disarmed` on the
   configuration and on the session takes nothing. `drag` reads as
   `(Option Int)`. `(AloemacsWindows new tree 0 80 24)` is rejected
   and `(AloemacsWindows new tree 0 80 24 (Option None))` is
   accepted. Read as data, the configuration's payload is §5.5's,
   the session has fourteen fields, and the ordered `define-class`
   list is unchanged.
2. **Grammar.** Every accepted and rejected string of §5.8 through
   `event?`, and the field reads of §7.2.
3. **Reader.** The `read-event` and `read-key` items of §7.2.
4. **Formatter.** The four values of §5.8.
5. **Sources.** The runner contains `[?1049h[?1002h[?1006h` and
   `[?1002l[?1006l[?1049l` as contiguous escape sequences, once
   each, and contains neither `1000`, `1003`, nor `term-enable-mouse`.
   `term.rkt` contains none of `1000`, `1002`, `1003`,
   `term-enable-mouse`. `gel-run.rkt` and `term-run.rkt` contain
   none of `read-event`, `1000`, `1002`, `term-enable-mouse`.
6. **A move is inert.** Every unchanged session of §7.2's fourth
   item, by whole-session equality.
7. **The field survives.** The `None` item and the constructed
   `armed 7` item of §7.2.
8. **Events disarm.** The `a` item of §7.2, including the one row
   that 002 changes.
9. **Runner.** The three-frame script of §7.2, with exact event
   order and the third frame equal to the second. No frame contains
   an enable byte.

Stop with this file, the migrated files, and the wider suite of §10
green.

## 8. Layer 002 — the bar

### 8.1 Product

In `file.aloe`:

1. The tree gains `first-id`, `handle-id`, `min-columns` with
   `columns-from`, `handle-at`, and `with-cut-at` (§5.3, §5.4,
   §5.6). In this checkpoint the `Below` arm of `handle-at` is
   `(if (rect contains? column row) <the two descents> (Option None))`
   with no boundary check, and the `Below` arm of `with-cut-at` has
   the two descents and `else` with no rewrite arm. `min-rows` does
   not exist yet.
2. The session gains `press-handle` and `drag-to` (§5.5). The
   no-leaf arm of `press-at` sends `(self press-handle column row)`.
   The move arm of `handle-mouse` sends
   `(self drag-to (mouse column) (mouse row))`.

`press-mode-line` is unchanged: a non-label mode-line press still
returns the receiver. `handle-event`, the host, and the runner are
as 001 left them.

### 8.2 Examples

`sr` is `(s0 split-right)`: `Right (Leaf 0, Leaf 1) 1 1`, view 0
selected, A `(0,0,40,23)`, bar 40, B `(41,0,39,23)`. `srr` is
`(sr split-right)`: `Right (Right (Leaf 0, Leaf 2) 1 1, Leaf 1) 1 1`,
bars at 20 and 40. `srrr` is `(srr split-right)`: bars at 10, 20,
40, leaves 0 `(0,0,10,23)`, 3 `(11,0,9,23)`, 2 `(21,0,19,23)`,
1 `(41,0,39,23)`. `sbr` is `((s0 split-below) split-right)`:
`Below (Right (Leaf 0, Leaf 2) 1 1, Leaf 1) 1 1`, the inner bar at
column 40 on rows 0 through 11, view 1 at `(0,12,80,11)`. `lr` is
`(((sr other-window) toggle-window-lock) other-window)`: view 1
locked, view 0 selected. `lb` is
`((((sbr other-window) other-window) toggle-window-lock) other-window)`:
view 1 locked below, view 0 selected. `armed` of a session `s` with
id `n` means `(s with (windows ((s windows) armed n)))`. Each row
reads "the events on the left, in order, return a session equal to
the expression on the right":

| Session | Events | Equals |
|---|---|---|
| `sr` | `mouse down left 40 5` | `sr` armed 1. Selection 0, both points `(0,0)`, echo `""`, tree `1 1` |
| `sr` | `mouse down left 40 0`, `mouse down left 40 22` | the same |
| `sr` armed 1 | `mouse move 30 5` | `sr` armed 1 with the tree `Right (Leaf 0, Leaf 1) 30 49`; `rect-for 0` `(0,0,30,23)`, `rect-for 1` `(31,0,49,23)` |
| that | `mouse up left 30 5` | the same with `drag` `None` |
| that | `ensure-visible 120 24` | `rect-for 0` `(0,0,46,23)`, `rect-for 1` `(47,0,73,23)`, weights `30 49` |
| `sr` armed 1 | `mouse move 30 5`, `mouse move 50 5` | weights `50 29` |
| `sr` armed 1 | `mouse move 0 5` | weights `1 78` |
| `sr` armed 1 | `mouse move 79 5`, or `mouse move 200 5`, or `mouse move 40 100` | weights `78 1` after the first two; `40 39` after the third |
| `sr` armed 1 | `ensure-visible 120 24`, `mouse move 60 5` | weights `60 59`; the armed id survived the resize |
| `sr` armed 1 | `x` | `(sr handle-event "x")`: `drag` `None`, `x` inserted at `(0,0)` of view 0 |
| `sr` armed 1 | `mouse up left 40 5` | `sr` |
| `sr` armed 1 | `mouse down middle 40 5`, or `mouse up right 0 0` | `sr` |
| `sr` armed 1 | `mouse down left 50 0` | `(sr handle-event "mouse down left 50 0")`: view 1 selected, its point `(0,9)` clamped to `(0,5)`, `drag` `None` |
| `sr` armed 1 | `mouse down left 40 5` | `sr` armed 1 |
| `sr` armed 1 | `find` | `(sr handle-key "find")`: searching, `drag` `None`; a following `mouse move 30 5` is unchanged |
| `sr` armed 1 | `escape` | quit, `drag` `None`; a following `mouse move 30 5` is unchanged |
| `sr` | `mouse move 30 5` | `sr` |
| `s0` | `mouse down left 40 5` | `(s0 place-at 5 40)`: text, today's path. Row 5 is past the last line, so `place` takes `buffer-end` and the point is `(2,3)`; a following move is unchanged |
| `lr` | `mouse down left 40 5` | `lr`; a following `mouse move 30 5` is unchanged |
| `srr` | `mouse down left 20 0` | `srr` armed 2 |
| that | `mouse move 10 0` | inner `10 29`: 0 `(0,0,10,23)`, 2 `(11,0,29,23)`; outer `1 1`, bar 40 |
| `srr` | `mouse down left 40 0`, `mouse move 0 0` | outer `3 76`: 0 `(0,0,1,23)`, 2 `(2,0,1,23)`, 1 `(4,0,76,23)`; inner `1 1` |
| `srrr` | `mouse down left 40 0`, `mouse move 0 0` | outer `6 73`: 0 `(0,0,1,23)`, 3 `(2,0,1,23)`, 2 `(4,0,2,23)`, 1 `(7,0,73,23)` |
| `sbr` | `mouse down left 40 3`, `mouse move 30 3` | inner `30 49`: 0 `(0,0,30,12)`, 2 `(31,0,49,12)`, 1 `(0,12,80,11)`; outer `1 1` |
| `lb` | `mouse down left 40 3`, `mouse move 30 3` | the same geometry, view 1 still locked: a lock elsewhere does not refuse |
| `((s0 ensure-visible 40 10) split-right)` | `mouse down left 20 2`, `mouse move 10 2` | `10 29`: 0 `(0,0,10,9)`, 1 `(11,0,29,9)` |
| the prompt session of `mouse.rkt` item 17 | `mouse down left 40 0` | unchanged |
| `(sr handle-key "ctrl-x")` | `mouse down left 40 5` | unchanged |

In every row the selection, every stored point and origin, the
echo, the text, the lock bits, and the tree shape are those of the
starting session; only `drag` and the two weights of the dragged
split differ. The press alone and the release alone leave the frame:
`(frame 80 24)` of `sr` armed 1 equals `(frame 80 24)` of `sr`.

`sbr` with `mouse down left 40 11`, the bar cell on the boundary
row, is not pinned in 002; 003 pins it as the `Below`.

Through the runner at 80 by 24 on `a.txt`, the script `ctrl-x`,
`3`, `mouse down left 40 0`, `mouse move 30 0`, `mouse up left 30 0`,
`escape` writes six frames. The fourth equals the third. The third
contains `hello` followed by 35 spaces and `|`; the fifth contains
`hello` followed by 25 spaces and `|`, and does not contain the
former. The sixth equals the fifth. Every frame's cursor tail is
`\e[1;1H\e[?25h`. Each iteration is `(columns 80)`, `(rows 24)`,
`(write frame)`, `flush`, `(key k)`.

### 8.3 Migration

Two existing tests change, one assertion each. `tests/aloemacs/mouse.rkt`
item 14, the test case "a left press on a mode line, the echo row,
or the bar changes nothing", presses the bar of a Right split at
`(40, 0)` with `unchanged!`, which compares whole sessions; after
002 that press arms. That assertion becomes: the session equals the
receiver armed 1, and its `drag` is `(Option Some 1)`. The
mode-line and echo-row presses in the same item stay unchanged.
`tests/aloemacs/mode-buttons-press.rkt` presses `(40, 22)` and
`(41, 22)` on `(s0 split-right)` in one unchanged loop; `(40, 22)`
is the bar and now arms, so it leaves that loop and becomes the
armed expectation, while `(41, 22)`, the right leaf's name on the
bottom mode line, stays unchanged. Item 10 of
`tests/aloemacs/split-drag-weights.rkt` drops its bar row. If any
other test fails, the product is wrong; fix the product.

### 8.4 Focused proof

Write `tests/aloemacs/split-drag-bar.rkt` first and watch it fail.
It uses a checked driver, loads `main.aloe` with the fs double of
`tests/aloemacs/mouse.rkt`, uses `make-term-receiver` and
`run-aloemacs-with-hosts` for the runner item, and does not open a
TTY. Prove:

1. **Types and arities.** `first-id` and `handle-id` type as `Int`
   with no argument. `min-columns` types as `Int` with no argument.
   `columns-from` types as `Int` with five `Int` arguments.
   `handle-at` types as `(Option AloemacsWindowTree)` with
   `Int`, `Int`, `AloemacsWindowRect` and rejects two and four
   arguments. `with-cut-at` types as `AloemacsWindowTree` with
   `Int`, `Int`, `Int`, `AloemacsWindowRect`. `press-handle` and
   `drag-to` type as the session type with two `Int` arguments.
   `press-at`, `press-mode-line`, `handle-event`, and `handle-mouse`
   keep their types. The ordered `define-class` list and every
   field inventory are unchanged.
2. **Ids.** On `srrr`'s tree, `first-id` is 0, `handle-id` is 1,
   the left child's `handle-id` is 2, and the innermost `Right`'s
   `handle-id` is 3. On `sbr`'s tree, `handle-id` is 1 and the top
   child's is 2.
3. **The floor.** Every `min-columns` value of §5.3's table,
   building the trees with raw constructors, including the `1 78`
   and `78 1` rows.
4. **The walk.** On `sr`'s tree with root `(0,0,80,23)`,
   `handle-at 40 5` is `Some` of the root, `handle-at 39 5` and
   `handle-at 41 5` are `None`, and `handle-at 40 23` is `None`. On
   `srr`'s tree, `handle-at 20 0` is the inner `Right` and
   `handle-at 40 0` is the root. On `sbr`'s tree, `handle-at 40 3`
   is the inner `Right`; `handle-at 0 11` is `None` in 002.
5. **Every row of §8.2's table**, by whole-session equality, with
   the rectangles read through `rect-for` where a row names them
   and the weights read from the tree.
6. **The frame holds.** The last paragraph before the runner in
   §8.2.
7. **Runner.** The six-frame script of §8.2.

Stop with this file, the two edited files of §8.3, and the wider
suite of §10 green.

## 9. Layer 003 — the mode line

### 9.1 Product

In `file.aloe`:

1. The tree gains `min-rows` with `rows-from` (§5.3).
2. The `Below` arm of `handle-at` gains the boundary check before
   its descents, and the `Below` arm of `with-cut-at` gains the
   rewrite arm, both exactly as §5.4 and §5.6 write them.
3. The `""` branch of `press-mode-line` sends
   `(self press-handle ((rect x) + index) (((rect y) + (rect rows)) - 1))`.

Nothing else changes. `label-at`, `select-view`, `button-send`, and
the label branch of `press-mode-line` are untouched.

### 9.2 Examples

`sb` is `(s0 split-below)`: `Below (Leaf 0, Leaf 1) 1 1`, view 0
selected, A `(0,0,80,12)` with its mode line on row 11, B
`(0,12,80,11)` with its mode line on row 22. `sbb` is
`(sb split-below)`: `Below (Below (Leaf 0, Leaf 2) 1 1, Leaf 1) 1 1`,
boundaries at rows 5 and 11. `sbbb` is `(sbb split-below)`:
leaves 0 `(0,0,80,3)`, 3 `(0,3,80,3)`, 2 `(0,6,80,6)`,
1 `(0,12,80,11)`, boundaries at 2, 5, 11. `sbr` and `lb` are as
§8.2. `srb` is `(sr split-below)`: `Right (Below (Leaf 0, Leaf 2) 1 1, Leaf 1) 1 1`,
0 `(0,0,40,12)`, 2 `(0,12,40,11)`, bar 40, 1 `(41,0,39,23)`. `ls`
is `(((sb other-window) toggle-window-lock) other-window)`: view 1
locked, view 0 selected.

| Session | Events | Equals |
|---|---|---|
| `sb` | `mouse down left 0 11` | `sb` armed 1 |
| `sb` | `mouse down left 40 11`, or `74 11` (a space in the group) | `sb` armed 1 |
| `sb` armed 1 | `mouse move 0 5` | tree `Below (Leaf 0, Leaf 1) 6 17`; `rect-for 0` `(0,0,80,6)`, `rect-for 1` `(0,6,80,17)` |
| that | `mouse up left 0 5` | the same with `drag` `None` |
| that | `ensure-visible 80 12` | `rect-for 0` `(0,0,80,3)`, `rect-for 1` `(0,3,80,8)`, weights `6 17` |
| `sb` armed 1 | `mouse move 0 0` | weights `2 21` |
| `sb` armed 1 | `mouse move 0 22`, or `mouse move 0 100` | weights `21 2`: 0 `(0,0,80,21)`, 1 `(0,21,80,2)` |
| `sb` armed 1 | `mouse move 50 5` | weights `6 17`; the column does not matter |
| `sb` armed 1 | `x` | `(sb handle-event "x")` |
| `sb` | `mouse down left 75 11`, `77 11`, `79 11` | `(sb split-below)`, `(sb split-right)`, `(sb delete-window)`: the mode-buttons results, `drag` `None` |
| `sb` | `mouse down left 0 22`, or `40 22` | `sb`: the bottom mode line |
| `sb` | `mouse down left 0 23` | `sb`: the echo row |
| `sb` | `mouse down left 0 5` | `(sb place-at 5 0)`: text, clamped by `place` |
| `sb` | `mouse down left 1 14` | the mouse spec's result: view 1 selected, its point `(2,1)`, `drag` `None` |
| `ls` | `mouse down left 0 11` | `ls`; a following move is unchanged |
| `lb` | `mouse down left 0 11`, or `40 11` | `lb` |
| `sbb` | `mouse down left 0 11`, `mouse move 0 0` | outer `4 19`: 0 `(0,0,80,2)`, 2 `(0,2,80,2)`, 1 `(0,4,80,19)`; inner `1 1` |
| `sbb` | `mouse down left 0 5`, `mouse move 0 1` | inner `2 10`: 0 `(0,0,80,2)`, 2 `(0,2,80,10)`; outer `1 1` |
| `sbbb` | `mouse down left 0 11`, `mouse move 0 0` | outer `7 16`: 0 `(0,0,80,2)`, 3 `(0,2,80,2)`, 2 `(0,4,80,3)`, 1 `(0,7,80,16)` |
| `sbbb` | `mouse down left 0 5`, `mouse move 0 3`, `mouse up left 0 3`, `mouse down left 0 11`, `mouse move 0 0` | the middle is `4 8` after the first drag: 0 `(0,0,80,2)`, 3 `(0,2,80,2)`, 2 `(0,4,80,8)`; the outer is `10 13` after the second: 0 2 rows, 3 2 rows, 2 `(0,4,80,6)`, 1 `(0,10,80,13)` |
| `sbr` | `mouse down left 40 11`, `mouse move 40 3` | outer `4 19`: 0 `(0,0,40,4)`, 2 `(41,0,39,4)`, 1 `(0,4,80,19)`; the bar cell on the boundary row drags the `Below` |
| `sbr` | `mouse down left 10 11`, or `50 11`, then `mouse move 0 3` | the same |
| `srb` | `mouse down left 10 11`, `mouse move 10 3` | inner `4 19`: 0 `(0,0,40,4)`, 2 `(0,4,40,19)`, 1 `(41,0,39,23)`; the mode-line cell to the left of the bar drags the `Below` inside the `Right` |
| `srb` | `mouse down left 40 11`, `mouse move 30 11` | the `Right` `30 49`: 0 `(0,0,30,12)`, 2 `(0,12,30,11)`, 1 `(31,0,49,23)`; the bar cell drags the `Right` |
| `((s0 ensure-visible 40 10) split-below)` | `mouse down left 0 4`, `mouse move 0 2` | `3 6`: 0 `(0,0,40,3)`, 1 `(0,3,40,6)` |

The one-row child: `short` is `sb` armed 1 after `mouse move 0 0`
and `mouse up left 0 0`, weights `2 21`, then `ensure-visible 80 4`.
Its root is `(0,0,80,3)`; `rect-for 0` is `(0,0,80,1)` and
`rect-for 1` is `(0,1,80,2)`. `mouse down left 0 0` on `short`
equals `(short place-at 0 0)`: a text press on the boundary row,
arming nothing. `mouse down left 0 2` on `short` is the bottom mode
line and is unchanged.

The frame holds across a press and a release: `(frame 80 24)` of
`sb` armed 1 equals that of `sb`.

Through the runner at 80 by 24 on `a.txt`, the script `ctrl-x`,
`2`, `mouse down left 0 11`, `mouse move 0 5`, `mouse up left 0 5`,
`escape` writes six frames. The fourth equals the third. Splitting
each frame on `\r\n`, the LIGHT sequence `\e[38;5;16;48;5;250m`
begins the line at index 11 of the third frame and the line at index
5 of the fifth, and the DARK sequence begins the line at index 22 of
both. The sixth equals the fifth.

### 9.3 Migration

One existing test changes, one assertion. `tests/aloemacs/mouse.rkt`
item 14 presses `(0, 11)` on `(s0 split-below)` with `unchanged!`;
after 003 that press arms. That assertion becomes the armed
expectation, as the bar press did in 002.
`tests/aloemacs/mode-buttons-press.rkt` is not edited: its unchanged
loops press the name at `(0, 22)` and `(10, 22)` on
`(s0 split-below)`, the bottom mode line, and `(0, 22)`, `(40, 22)`,
and `(73, 22)` on `s0`, the sole window's mode line, which is also
the bottom; those stay unchanged. Its `(s0 split-below)` press at
`(77, 11)` is a label and stays. It has no `""` press on a boundary
row. Item 10 of `tests/aloemacs/split-drag-weights.rkt` drops its
mode-line row. If any other test fails, the product is wrong; fix
the product.

### 9.4 Focused proof

Write `tests/aloemacs/split-drag-mode-line.rkt` first and watch it
fail. Same driver, double, receiver, and equality as §8.4. Prove:

1. **Types and arities.** `min-rows` types as `Int` with no
   argument; `rows-from` types as `Int` with five `Int` arguments.
   `press-mode-line` keeps its three parameters and its type. The
   ordered `define-class` list and every field inventory are
   unchanged.
2. **The floor.** Every `min-rows` value of §5.3's table, including
   the `4 8` row, and the four-line reading under the table.
3. **The walk.** On `sb`'s tree with root `(0,0,80,23)`,
   `handle-at 0 11` is `Some` of the root, `handle-at 0 10`,
   `handle-at 0 12`, and `handle-at 0 22` are `None`. On `sbb`'s
   tree, `handle-at 0 5` is the inner `Below` and `handle-at 0 11`
   is the root. On `sbr`'s tree, `handle-at 40 11` is the root and
   `handle-at 40 3` is the inner `Right`. On `srb`'s tree,
   `handle-at 10 11` is the inner `Below` and `handle-at 40 11` is
   the root.
4. **Every row of §9.2's table**, by whole-session equality, with
   rectangles through `rect-for` and weights from the tree.
5. **The one-row child** and **the frame holds**, as §9.2 states
   them.
6. **Labels stay commands.** The three label rows, also on
   `(sb other-window)` pressing `(75, 11)`: equals
   `(((sb other-window) other-window) split-below)`, `drag` `None`.
7. **Runner.** The six-frame script of §9.2.

Stop with this file, the one edited file of §9.3, and the wider
suite of §10 green.

## 10. Verification, hand check, and acceptance

Each implementer writes the focused test first, sees it fail,
implements one slice, and verifies from the project root. The wider
suite is every aloemacs test and the parenthetical-construction
tests:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/split-drag-weights.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction
```

For 001, 002, and 003, the first command names that checkpoint's
focused file and every earlier one in this series; the second is
the same. Run `git diff --check` as well. Do not commit `compiled/`.
000's product edit is `.aloe` only. 001 edits `.rkt` files, so a
launch by hand after it needs `raco make host/racket/aloemacs-run.rkt`.

**Hand check.** After 003, the human runs this on a real UTF-8
terminal with 256 colors and SGR mouse reporting, at least 80 by 24,
in a window that can be resized. The implementer does not need a
TTY.

```sh
cp SPEC.md /tmp/split-drag.txt
racket host/racket/aloemacs-run.rkt /tmp/split-drag.txt
```

1. `C-x 3`. Press on the vertical bar and drag left; the bar follows
   the pointer and the left window narrows. Drag right past the
   middle; the right window narrows. Release. The bar stays where it
   was released. Drag the bar all the way left: the left window
   keeps one column, and the bar sits in the second. All the way
   right: the right window keeps one column, the last, and the bar
   sits before it.
2. `C-x 2` in the left window. Press on the mode line between the
   two left windows and drag up; the upper window shrinks to two
   rows and no further. Drag down; the lower window shrinks to two
   rows and no further. Release at a third of the height. The right
   window is unchanged throughout.
3. Shrink the terminal window, then grow it. Both divisions keep
   their proportions. Shrink it until the left side is four rows
   tall: the upper-left window has two rows, and its mode line is
   still the handle. One row shorter is today's shrink, where one
   side keeps a single row with no mode line. Grow it back.
4. `C-x l` in the upper-left window. Drag the mode line below it:
   nothing moves. Drag the vertical bar: nothing moves. `C-x o` to
   the right window and drag the bar from there: still nothing,
   because the locked window is a child of that split. `C-x o`
   back and `C-x l` to unlock. Both handles move again.
5. Press ↕ on the mode line between the two left windows. The
   upper-left window splits; nothing drags. Press × on the new
   window's mode line. It closes.
6. Press on the bottom mode line and move. Nothing changes. Press on
   the echo row and move. Nothing changes. Press in text and move.
   The point is placed on the press and does not follow the
   pointer.
7. Escape quits. Nothing is written. In the shell, mouse selection
   works again, moving the mouse prints nothing, and the scrollback
   is as it was.

A failure of the check sends the work back. It does not add a
feature.

The specification is met when all of these are true:

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
   A move puts the bar at the pointer column, clamped by §5.6. The
   left child takes the columns before the bar and the right child
   the rest.
4. **The mode line drags a `Below`.** A left press on a mode-line
   cell whose `label-at` is `""`, on the last row of a `Below`'s top
   child, arms. A text cell on that row, which a shrink can produce
   when the top child is one row tall, stays a text press. A move
   makes the pointer row the top child's last row, clamped by §5.6.
   The bottom child starts on the next row.
5. **The three labels stay commands.** A left press on ↕, ↔, or ×
   on a handle row matches the session mode-buttons 001 already
   returns, and arms nothing.
6. **The bottom mode line, the echo row, a completion row, and text
   arm nothing.** A press there takes the path it takes today.
7. **The drag changes nothing but weights.** Selection, every
   point, every origin, the echo, the buffers, the lock bits, and
   the tree shape are the same before the press and after the
   release. The press alone and the release alone paint the frame
   painted before them. The runner's next fit may scroll the
   selected window to keep its point inside the new rectangle, as
   it already does after a terminal resize.
8. **Lock refuses the handle.** A press on a handle of a split with
   a locked leaf in either child leaves the session unchanged, and
   the moves that follow leave it unchanged. A locked leaf elsewhere
   does not refuse.
9. **The floor is structural.** No move leaves a leaf shorter than
   two rows or narrower than one column, counting every leaf of
   both children of the dragged split, with each child divided by
   its own weights.
10. **Motion reaches Aloe only while a button is held.** The runner
    enables mode `1002`, not `1000` and not `1003`, and disables it
    on the way out. Gel is untouched. A move string with nothing
    armed leaves the session unchanged. Wheel messages stay dropped.
11. **Tests are the proof.** The focused tests call `handle-event`
    with `mouse down left`, `mouse move`, and `mouse up left`
    strings and compare sessions and rectangles. They do not open a
    TTY. A scripted runner feeds the same strings through
    `read-event`. The four focused files and the wider suite pass
    with product changes only in `file.aloe`, `main.aloe`,
    `term.rkt`, and `aloemacs-run.rkt`.

After the human accepts this spec, the checkpoint manager writes
**aloemacs-split-drag 000 only**, then stops. If you have been told
to read this file as the manager assignment, it is the whole
assignment. Do not write later checkpoints in advance.
