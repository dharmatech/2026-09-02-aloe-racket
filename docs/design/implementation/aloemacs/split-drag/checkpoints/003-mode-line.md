# aloemacs-split-drag 003 — The mode line

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the spec sections named below, implement this slice, and stop
when green.

## Goal

A left press on the mode line between an upper and a lower window
arms that `Below`, unless the cell is ↕, ↔, or ×, which stay the
commands they are. A move while armed makes the pointer row the
upper window's last row, within the structural floor, and rewrites
that split's weights. The left release ends the drag.

- The tree gains `min-rows` with its search `rows-from`. The `Below`
  arm of `handle-at` gains its boundary check, and the `Below` arm
  of `with-cut-at` gains its rewrite arm, so both axes are complete.
- The `""` branch of `press-mode-line` sends `press-handle` with the
  cell it recovers from the rectangle and the index.
- The labels stay commands. The bottom mode line, a text cell, and
  a one-row child arm nothing. A locked leaf in either child refuses.
- Three existing tests change, one assertion each.

This is the last checkpoint of the series. Stop when the focused
proof and the wider suite pass. The hand check is the human's.

## Authority, identity, and starting point

The implementer receives this checkpoint and the spec. The
checkpoint narrows the spec to one slice, restates its migration
from a scratch run of the tree at issuance, and adds one assertion
the spec's §9.3 did not list. It does not revise the spec.

- Identity: **aloemacs-split-drag 003**, filed as
  `checkpoints/003-mode-line.md`. This is a local editor checkpoint.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
  There is no 004.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`. `let`
  binds independently, so a value that depends on another binding
  takes a nested `let`. `/` on two `Int` values is integer division.
  `with` is not available on a `Below` or a `Right`; a weight
  rewrite rebuilds the node with the same children. No mutation,
  macros, inheritance, or new special forms.
- [../spec.md](../spec.md) governs:
  - §3: the product boundary and the out-of-scope list.
  - §4: the file table and what stays alone.
  - §5.3: the structural floor, `min-rows`, and `rows-from`.
  - §5.4: the handles, the `Below` boundary row, and the `""`
    branch of `press-mode-line`.
  - §5.5: the event table.
  - §5.6: what a move writes on the row axis, and the pinned cases.
  - §5.7: lock.
  - §9: this layer. §9.1 is the product edit, §9.2 the examples,
    §9.3 the migration, §9.4 the focused proof.
  - §10: verification, the hand check, and the acceptance list,
    which this checkpoint completes.
- [000-weights.md](000-weights.md), [001-motion.md](001-motion.md),
  and [002-bar.md](002-bar.md) are implemented, reviewed, and
  committed as bf1d1e8, ad62bf5, and 80e0fd2. Everything they built
  is the starting point. 002's `min-columns` binds each child's
  minimum once in a `let`; `min-rows` has the same shape and takes
  the same `let`, as the sketch below does.
- The accepted mode-buttons spec stays the authority for the three
  labels, `label-at`, and the label branch of `press-mode-line`,
  none of which change. The accepted mouse spec stays the authority
  for the cells `press-at` classifies before it reaches a leaf. The
  accepted windows spec stays the authority for `any-locked?` and
  the shrink fallback.

### Current tree

Line numbers are from the tree at issuance on 2026-10-11, commit
c0ab0ea, and are approximate; search before editing.

- [examples/aloemacs/file.aloe](../../../../../../examples/aloemacs/file.aloe),
  in `define-methods AloemacsWindowTree` (line 645): `first-id`
  (702), `handle-id` (710), `columns-from` (719), `min-columns`
  (729), `handle-at` (741), `with-cut-at` (763), then the comment
  above `right-rows` (794).
  - `handle-at`'s `Below` arm is
    `(if (rect contains? column row) <the two descents> (Option None))`
    with no boundary check. Its comment says a `Below` only
    descends here and its boundary row is 003's.
  - `with-cut-at`'s `Below` arm is a `cond` with the two descents
    and `else`. Its comment says a `Below`'s own rewrite is 003's.
  - `AloemacsWindowRect.row-cut (earlier later)` is the top child's
    height, so the boundary row of a `Below` under `rect` is
    `(rect y) + (rect row-cut earlier later) - 1`.
- The session: `press-handle` (2202) and `drag-to` (2216) as 002
  wrote them. `press-at` (2230) reaches `press-mode-line` for a leaf
  at least two rows tall when the row is the leaf's last row, with
  `index` equal to `column - (rect x)`. `press-mode-line` (2257):

  ```aloe
  (let ((label ((AloemacsModeLine new) label-at (rect columns) index)))
    (if (label = "")
        (self unchanged)
        ((self select-view view) case
          (None () (self unchanged))
          (Some (selected) (selected button-send label)))))
  ```

  The `(self unchanged)` on the `""` branch is the one line this
  checkpoint replaces. `select-view` (2269) and `button-send` (2280)
  do not change.
- `tests/aloemacs/mouse.rkt` item 14 (line 342) presses `(0, 11)` on
  `((s0 with-echo "saved") split-below)` with `unchanged!`.
  `tests/aloemacs/split-drag-weights.rkt` item 10 presses `(0, 11)`
  on `sb` and expects the receiver; it is that test case's only
  assertion. `tests/aloemacs/split-drag-bar.rkt` item 4 (line 196)
  asserts that `handle-at 0 11` on the below-then-right tree is
  `None`, which is true only until this checkpoint.
  `tests/aloemacs/mode-buttons-press.rkt` presses `(0, 22)` and
  `(10, 22)` on `(s0 split-below)`, the bottom mode line, and
  `(77, 11)`, a label; none of those change.

At issuance, from the project root,
`TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction`
passes 684 tests and the working tree is clean.

### Size

One conversation. The product edit is two tree sends, one added
branch in each of two existing tree sends, and one replaced line in
`press-mode-line`, all in `file.aloe`. Three existing tests change
one assertion each. The focused file is new.

The manager applied exactly the product edit of **Required
behavior** to a scratch copy of the tree and ran the wider suite.
Three files failed, each on one assertion: `mouse.rkt`,
`split-drag-weights.rkt`, and `split-drag-bar.rkt`. After the three
edits under **Migration**, all 683 remaining tests passed with
product changes only in `file.aloe`; the count is one lower because
the weights test's item 10 has nothing left to assert and is
removed. The manager then checked every row of §9.2's table, the
one-row child, the frame across a press, the label press on an
unselected window, the walk, every row of the `min-rows` table with
the `4 8` reading, and the six-frame runner script against that
copy. All hold. If you cannot finish in this conversation, stop and
report which files remain. Do not split the slice.

The implementation on 2026-10-11 followed this checkpoint as
written. The manager reviewed the diff against this checkpoint and
found it conforming: the product diff is `rows-from`, `min-rows`
with its `let`, the boundary check in `handle-at`'s `Below` arm, the
rewrite arm in `with-cut-at`'s `Below` arm, their two comments, and
the `""` branch of `press-mode-line`, and nothing else; the three
test files change one assertion each; the focused file covers the
seven items; the four focused files pass 55 tests, the wider suite
702, and `git diff --check` is clean. The implementer flagged two
things. The comment above `press-mode-line` still says every other
mode-line cell leaves the session as it was, and after this
checkpoint such a cell is a handle press; this checkpoint forbade
that edit, so the comment is stale, and correcting it is a one-line
commit-time edit that needs no further checkpoint. And on a terminal
too short for a split upper window to keep two rows, a press on its
bar cell on the boundary row arms the `Below` above it, because the
ancestor wins, and the move then finds an empty interval and changes
nothing; that is spec §5.4 and §5.6 as written, and it ends when the
terminal grows. The human ran the §10 hand check on 2026-10-11 and
every step behaved as written. The stale comment was corrected at
commit time. The series is accepted.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, in exactly these places:
  1. `define-methods AloemacsWindowTree`: add `rows-from` and
     `min-rows`; add the boundary check to the `Below` arm of
     `handle-at`; add the rewrite arm to the `Below` arm of
     `with-cut-at`; update the two comments that say those are
     003's. Nothing else in the block changes.
  2. `(AloemacsSession H)`: the `""` branch of `press-mode-line`.
     Nothing else on the session changes.
  You may add a comment above each new method.
- Create `tests/aloemacs/split-drag-mode-line.rkt` before the
  product edit, and watch it fail.
- `tests/aloemacs/mouse.rkt`, `tests/aloemacs/split-drag-weights.rkt`,
  and `tests/aloemacs/split-drag-bar.rkt`, each in the one place
  **Migration** names.

### Must leave untouched

- In `file.aloe`: every class other than the tree's `define-methods`
  block and the session. In the block: every existing method apart
  from the two arms named above; in particular `first-id`,
  `handle-id`, `columns-from`, `min-columns`, the `Right` arms of
  `handle-at` and `with-cut-at`, and the `Leaf` arms. On the
  session: `press-handle`, `drag-to`, `press-at`, `handle-event`,
  `handle-mouse`, `disarmed`, the label branch of `press-mode-line`,
  `select-view`, `button-send`, `place-in`, `place-at`, `unchanged`,
  `enter-view`, `other-window`, `split-window`, `delete-window`,
  `toggle-window-lock`, `ensure-visible`, `fit-rect`, `root-rect`,
  `frame`, `record-pictures`, the echo tokens, and the keymap tables.
  `label-at` on `AloemacsModeLine`. Do not change the order of
  declarations. The ordered `define-class` list and every field
  inventory are unchanged. `file.aloe` stays ASCII bytes.
- `examples/aloemacs/main.aloe`, `examples/aloemacs/editor.aloe`,
  everything under `host/racket/`, `lib/`, `aloe/`, `bin/`, `gel/`,
  `archive/`, `SPEC.md`, `CHECKPOINTS.md`, and `tui-term`. Add no
  Term method, host capability, kernel message, `lib/` method, Text
  method, class, field, command, key, keymap entry, face, or build
  step.
- Every test not named above. `tests/aloemacs/mode-buttons-press.rkt`
  and `tests/aloemacs/split-drag-motion.rkt` stay green unedited. If
  any other test fails, the product is wrong; fix the product. Do
  not edit a fixture, a geometry, or an expectation to force the
  suite green. Create no shared helper module.
- Every document: this checkpoint, the three earlier checkpoints,
  `spec.md`, `charter.md`, and `README.md` in this folder; the
  mouse, mode-buttons, windows, window-bars, mode-line, window-point,
  and alternate-screen documents; and the parent `aloemacs/README.md`,
  `discussion.md`, and `explorations.md`.

If another file, another method, or a change to `press-at` seems
necessary, stop and report it. Do not widen this checkpoint.

## Required behavior

### 1. The structural floor, row axis (spec §5.3)

A drag never leaves a leaf shorter than two rows, counting every
leaf of both children of the dragged split, each child divided by
the weights it already has. Add to the `define-methods` block,
beside `min-columns`. This can be pasted as it is:

```aloe
    ;; The smallest rows at or above the start whose cut, by this Below's own
    ;; weights, gives the top at least top-least and the bottom at least
    ;; bottom-least.
    (rows-from (rows Int) (top-least Int) (bottom-least Int) (earlier Int) (later Int) Int
      (let ((cut ((AloemacsWindowRect new 0 0 0 rows) row-cut earlier later)))
        (if (if (cut >= top-least) ((rows - cut) >= bottom-least) #f)
            rows
            (self rows-from (rows + 1) top-least bottom-least earlier later))))

    ;; The shortest height at which every leaf keeps two rows, each child
    ;; divided by its own weights. Each child's minimum is computed once.
    (min-rows () Int
      (self case
        (Leaf (view) 2)
        (Right (left right earlier later) ((left min-rows) max (right min-rows)))
        (Below (top bottom earlier later)
          (let ((top-least (top min-rows)) (bottom-least (bottom min-rows)))
            (self rows-from (top-least + bottom-least)
              top-least bottom-least earlier later)))))
```

The `let` matters: sending `(top min-rows)` twice doubles the cost
at every level of nested `Below`s, which is why 002's `min-columns`
binds its two minimums once. The search starts at the sum of the
children's minimums and climbs by one; it terminates because the
cut and its remainder both grow without bound. The sum is where the
search starts, not the answer: `Below (Below (A, B), C)` needs 7
rows at equal weights, not 6, because the equal cut of 6 is 3 and 3
and the inner cut of 3 is 2 and 1. Pinned values, every weight
`1 1` unless written:

| Tree | `min-rows` |
|---|---:|
| `Leaf` | 2 |
| `Below (A, B)` | 4 |
| `Below (A, B)` with `1 22` or `22 1` | 4 |
| `Right (A, B)` | 2 |
| `Right (A, B)` with `1 78` or `78 1` | 2 |
| `Below (Right (A, B), C)` | 4 |
| `Right (Below (A, B), C)` | 4 |
| `Below (Below (A, B), C)` | 7 |
| `Below (Below (A, B), C)` with the outer `4 8` | 10 |
| `Right (Right (A, B), C)` | 2 |
| `Below (Below (Below (A, B), C), D)` | 13 |
| `Right (Right (Right (A, B), C), D)` | 2 |

The `4 8` row reads: the top child's minimum is 4 and the bottom's
is 2, so the search starts at 6. `((AloemacsWindowRect new 0 0 0 n) row-cut 4 8)`
is 2, 3, 3, 3, 4 for `n` from 6 to 10, so 10 is the first height
whose top gets 4 and whose rest, 6, is at least 2. Through the
helper, `rows-from 6 4 2 4 8` is 10 and `rows-from 4 2 2 1 1` is 4.

### 2. The walk, row axis (spec §5.4)

The `Below` arm of `handle-at` gains its boundary check before its
descents. The arm becomes:

```aloe
        (Below (top bottom earlier later)
          (if (rect contains? column row)
              (if (row = (((rect y) + (rect row-cut earlier later)) - 1))
                  (Option Some self)
                  ((top handle-at column row (rect top earlier later)) case
                    (Some (found) (Option Some found))
                    (None () (bottom handle-at column row (rect bottom earlier later)))))
              (Option None)))
```

The `Leaf` and `Right` arms do not change. The ancestor wins: a bar
cell on a mode-line row drags the `Below` above it, because the
`Below` is checked before its children, and a mode-line cell to the
left of a bar drags the `Below` inside that `Right`. The bottom
mode line is never a top child's last row, so it never arms. Update
the method's comment: the split whose handle holds the cell is a
`Right`'s bar column or the last row of a `Below`'s top child.

Pinned, with root `(AloemacsWindowRect new 0 0 80 23)` and the
fixtures below: on `sb`'s tree, `handle-at 0 11` is `Some` of the
root, and `handle-at 0 10`, `handle-at 0 12`, and `handle-at 0 22`
are `None`. On `sbb`'s tree, `handle-at 0 5` is the inner `Below`
and `handle-at 0 11` is the root. On `sbr`'s tree, `handle-at 40 11`
is the root and `handle-at 40 3` is the inner `Right`. On `srb`'s
tree, `handle-at 10 11` is the inner `Below` and `handle-at 40 11`
is the root.

### 3. What a move writes, row axis (spec §5.6)

The `Below` arm of `with-cut-at` gains its rewrite arm as the first
clause of its `cond`, before the two descents:

```aloe
            (((bottom first-id) = id)
              (let ((lo (top min-rows)) (hi ((rect rows) - (bottom min-rows))))
                (if (lo > hi)
                    self
                    (let ((cut (lo max (((row - (rect y)) + 1) min hi))))
                      (AloemacsWindowTree Below top bottom cut ((rect rows) - cut))))))
```

In words: `wanted = (row - rect.y) + 1`, so the pointer row becomes
the top child's last row; `cut` is `wanted` clamped to
`[min-rows (top), rows - min-rows (bottom)]`; the weights become
`cut, rows - cut`. An empty interval leaves the tree. A pointer
outside the split's rectangle is clamped, not refused; the column
does not matter. The children are unchanged by a rewrite. Update
the method's comment to drop the sentence that says a `Below` only
descends. The `Right` arm, the `Leaf` arm, and the two `Below`
descents do not change.

### 4. The press (spec §5.4)

In `press-mode-line`, the `""` branch becomes:

```aloe
            (self press-handle ((rect x) + index) (((rect y) + (rect rows)) - 1))
```

`press-mode-line` keeps its three parameters and its type. It
recovers the cell: the column is `(rect x) + index`, and the row is
the leaf's last row, `(rect y) + (rect rows) - 1`, which is the row
`press-at` already tested before it sent here. The label branch is
untouched, so ↕, ↔, and × stay the commands mode-buttons 001 gave
them, and a press on one arms nothing. `press-handle` then runs the
walk from the root and arms the `Below` whose boundary row holds the
cell, unless a leaf in either child is locked or the tree does not
fit.

What arms nothing, and why: the bottom mode line, because it is no
top child's last row, so the walk answers `None` and `press-handle`
returns the receiver; the echo row and a completion row, because
`press-at` answers before it looks for a leaf; a text cell, because
`press-at` sends `place-in`, even on the boundary row of a one-row
child, which has no mode line; a label, because `press-mode-line`
takes its label branch. A press while `positive-layout?` is false
arms nothing, and a move then writes nothing.

### 5. The event table, complete (spec §5.5)

| Event | While not armed | While armed |
|---|---|---|
| `mouse down left` on a handle of a split with no locked leaf in either child | Arms. Nothing else changes | Re-arms on that handle. Nothing else changes |
| `mouse down left` on a handle of a split with a locked leaf in either child | Unchanged | Disarms. Nothing else changes |
| `mouse down left` anywhere else | Today's path: a label is its command, text places, chrome is unchanged | Disarms, then today's path |
| `mouse move` | Unchanged | Rewrites the armed split's weights. A missing split, an empty interval, or a non-positive layout leaves the tree |
| `mouse up left` | Unchanged | Disarms. The weights stay what the last move wrote |
| `mouse down` or `mouse up` with middle or right | Unchanged | Disarms. Nothing else changes |
| A key | Today's path | Disarms, then today's path |
| Any mouse string during a search, a prompt, or a pending prefix | Unchanged | Unchanged |
| Any event after quit | Unchanged | Unchanged |

A handle is now a bar column or a boundary row. The drag stores no
origin, changes no point, and changes no selection. A terminal
resize between events keeps the armed id. The press alone and the
release alone paint the frame painted before them.

### 6. What stays in place (spec §5.9)

The labels and `label-at` are as mode-buttons left them. The bar is
`|`; the `Below` spends no rule row; nothing paints `drag`.
`split-below`, `split-right`, `delete-window`, `other-window`, and
the lock toggle are the same sends with the same refusals and echo
tokens. A split still writes `1 1`. The picture cache gains no key.
No keymap binding, command constructor, Term method, kernel message,
or `SPEC.md` row. The runner still enables `1002` inside `1049`.

## Tests

### Focused proof: `tests/aloemacs/split-drag-mode-line.rkt`

Write this file first and watch it fail. Same driver, double,
receiver, and equality as `tests/aloemacs/split-drag-bar.rkt`: a
checked driver, `rackunit`, `make-term-receiver`, and
`run-aloemacs-with-hosts`, no TTY, no `with-term`,
`call-with-tty-term-receiver`, or `run-aloemacs`. Copy the helpers
you need from `split-drag-bar.rkt` (`same`, `dtype`, `rejects`,
the weights reader, `first-child`, `armed`, `dragged`, `rects!`,
`make-scripted-term`) and from `split-drag-weights.rkt` (reading
`file.aloe` as data). Do not `require` another test module.

The fs double is the one `mouse.rkt` uses:

```racket
(make-fs-double "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
  (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b"))
```

Fixtures, each an Aloe expression on the loaded `main.aloe`. Every
weight is `1 1` before a drag, and `root` is
`(AloemacsWindowRect new 0 0 80 23)`.

| Name | Expression | Geometry |
|---|---|---|
| `s0` | `((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)` | one leaf |
| `sb` | `(s0 split-below)` | `Below (Leaf 0, Leaf 1)`, view 0 selected, A `(0,0,80,12)` with its mode line on row 11, B `(0,12,80,11)` with its mode line on row 22 |
| `sbb` | `(sb split-below)` | `Below (Below (Leaf 0, Leaf 2), Leaf 1)`, boundaries at rows 5 and 11 |
| `sbbb` | `(sbb split-below)` | leaves 0 `(0,0,80,3)`, 3 `(0,3,80,3)`, 2 `(0,6,80,6)`, 1 `(0,12,80,11)`; boundaries at 2, 5, 11 |
| `sbr` | `(sb split-right)` | `Below (Right (Leaf 0, Leaf 2), Leaf 1)`, inner bar at column 40 on rows 0 through 11, boundary at row 11 |
| `srb` | `((s0 split-right) split-below)` | `Right (Below (Leaf 0, Leaf 2), Leaf 1)`, 0 `(0,0,40,12)`, 2 `(0,12,40,11)`, bar 40, 1 `(41,0,39,23)` |
| `lb` | `((((sbr other-window) other-window) toggle-window-lock) other-window)` | view 1 locked below, view 0 selected |
| `ls` | `(((sb other-window) toggle-window-lock) other-window)` | view 1 locked, view 0 selected |
| `s40b` | `((s0 ensure-visible 40 10) split-below)` | root `(0,0,40,9)`, boundary at row 4 |
| `sb1` | `sb` armed 1 | |

"`s` armed `n`" means `(s with (windows ((s windows) armed n)))`.
"Equals" is `(check actual expected)` through the driver. Assert the
fixture geometry of `sbbb` and `srb` through `rect-for` before using
them. Prove:

1. **Types and arities.** On `((sb windows) tree)`: `min-rows` types
   as `Int` and rejects an argument; `rows-from` types as `Int` with
   five `Int` arguments and rejects four and six. `press-mode-line`
   keeps its three parameters: `(sb press-mode-line v r 0)` for a
   view `v` and a rect `r` types as the session type and rejects two
   and four arguments. `press-at`, `press-handle`, `drag-to`,
   `handle-event`, and `handle-mouse` keep their types. Read as
   data, the ordered `define-class` list is the one
   `split-drag-weights.rkt` pins, and the `AloemacsWindows` and
   `AloemacsWindowTree` payloads are as 001 left them.
2. **The floor.** Every row of the table in **Required behavior §1**,
   building each tree with raw constructors, and the `4 8` reading:
   `row-cut 4 8` on a probe rect of 6 through 10 rows is
   `2 3 3 3 4`, `rows-from 6 4 2 4 8` is 10, and `rows-from 4 2 2 1 1`
   is 4.
3. **The walk.** The pinned values of **Required behavior §2**,
   comparing `Some` results against the node by `check`.
4. **Every row of this table**, by whole-session equality.
   Rectangles are read through `rect-for` on `root` unless a row
   names another rect; weights from the tree.

   | Session | Events | Equals |
   |---|---|---|
   | `sb` | `mouse down left 0 11` | `sb1`; `drag` is `(Option Some 1)`, `selected` 0, echo `""`, the tree reads `1 1` |
   | `sb` | `mouse down left 40 11`; separately `mouse down left 74 11`, a space in the group | `sb1`, each |
   | `sb1` | `mouse move 0 5` | `sb1` with its tree replaced by `Below (Leaf b0, Leaf b1) 6 17`, where `b0` and `b1` are `sb`'s two leaves; `rect-for 0` `(0,0,80,6)`, `rect-for 1` `(0,6,80,17)`; `drag` present |
   | that | `mouse up left 0 5` | the same with `drag` `None` |
   | that | `ensure-visible 80 12` | `rect-for` on `(AloemacsWindowRect new 0 0 80 11)` gives `(0,0,80,3)` and `(0,3,80,8)`; weights still `6 17` |
   | `sb1` | `mouse move 0 0` | weights `2 21` |
   | `sb1` | `mouse move 0 22`; separately `mouse move 0 100` | weights `21 2`, each; `rect-for` 0 `(0,0,80,21)`, 1 `(0,21,80,2)` |
   | `sb1` | `mouse move 50 5` | weights `6 17`; the column does not matter |
   | `sb1` | `x` | `(sb handle-event "x")` |
   | `sb` | `mouse down left 75 11`; `77 11`; `79 11` | `(sb split-below)`, `(sb split-right)`, `(sb delete-window)`: the mode-buttons results; `drag` `None` in each |
   | `sb` | `mouse down left 0 22`; `40 22` | `sb`: the bottom mode line |
   | `sb` | `mouse down left 0 23` | `sb`: the echo row |
   | `sb` | `mouse down left 0 5` | `(sb place-at 5 0)`: text |
   | `sb` | `mouse down left 1 14` | the mouse spec's result: `selected` 1, point `(2,1)`, `drag` `None` |
   | `ls` | `mouse down left 0 11` | `ls`; a following `mouse move 0 5` leaves it unchanged |
   | `lb` | `mouse down left 0 11`; `40 11` | `lb`, each |
   | `sbb` | `mouse down left 0 11`, `mouse move 0 0` | the root reads `4 19` and the inner `Below` `1 1`; `rect-for` 0 `(0,0,80,2)`, 2 `(0,2,80,2)`, 1 `(0,4,80,19)` |
   | `sbb` | `mouse down left 0 5`, `mouse move 0 1` | the inner `Below` reads `2 10` and the root `1 1`; `rect-for` 0 `(0,0,80,2)`, 2 `(0,2,80,10)` |
   | `sbbb` | `mouse down left 0 11`, `mouse move 0 0` | the root reads `7 16`; `rect-for` 0 `(0,0,80,2)`, 3 `(0,2,80,2)`, 2 `(0,4,80,3)`, 1 `(0,7,80,16)` |
   | `sbbb` | `mouse down left 0 5`, `mouse move 0 3`, `mouse up left 0 3`, then `mouse down left 0 11`, `mouse move 0 0` | after the first drag the middle `Below` reads `4 8`: `rect-for` 0 `(0,0,80,2)`, 3 `(0,2,80,2)`, 2 `(0,4,80,8)`; after the second the root reads `10 13`: 0 `(0,0,80,2)`, 3 `(0,2,80,2)`, 2 `(0,4,80,6)`, 1 `(0,10,80,13)` |
   | `sbr` | `mouse down left 40 11`, `mouse move 40 3` | the root reads `4 19`; `rect-for` 0 `(0,0,40,4)`, 2 `(41,0,39,4)`, 1 `(0,4,80,19)`: the bar cell on the boundary row drags the `Below` |
   | `sbr` | `mouse down left 10 11`, then `mouse move 0 3`; separately `mouse down left 50 11`, then `mouse move 0 3` | the same configuration as the row above, each |
   | `srb` | `mouse down left 10 11`, `mouse move 10 3` | the inner `Below` reads `4 19`; `rect-for` 0 `(0,0,40,4)`, 2 `(0,4,40,19)`, 1 `(41,0,39,23)`: the mode-line cell left of the bar drags the `Below` inside the `Right` |
   | `srb` | `mouse down left 40 11`, `mouse move 30 11` | the root `Right` reads `30 49`; `rect-for` 0 `(0,0,30,12)`, 2 `(0,12,30,11)`, 1 `(31,0,49,23)`: the bar cell drags the `Right` |
   | `s40b` | `mouse down left 0 4`, `mouse move 0 2` | weights `3 6`; `rect-for` on `(AloemacsWindowRect new 0 0 40 9)` gives 0 `(0,0,40,3)` and 1 `(0,3,40,6)` |

   In every row the selection, every stored point and origin, the
   echo, the text, the lock bits, and the tree shape are those of
   the starting session; only `drag` and the two weights of the
   dragged split differ.
5. **The one-row child, and the frame holds.** `short` is
   `(((sb1 handle-event "mouse move 0 0") handle-event "mouse up left 0 0") ensure-visible 80 4)`:
   weights `2 21`, `(short root-rect 80 4)` has 3 rows, and
   `rect-for` on `(AloemacsWindowRect new 0 0 80 3)` gives 0
   `(0,0,80,1)` and 1 `(0,1,80,2)`. `mouse down left 0 0` on `short`
   equals `(short place-at 0 0)`, a text press on the boundary row,
   with `drag` `None`. `mouse down left 0 2` on `short` is the
   bottom mode line and is unchanged. `(frame 80 24)` of `sb1`
   equals `(frame 80 24)` of `sb`.
6. **Labels stay commands.** The three label rows of item 4, and on
   `(sb other-window)` pressing `(75, 11)`: equals
   `(((sb other-window) other-window) split-below)`, `drag` `None`.
7. **Runner.** With `make-scripted-term` as `mouse.rkt` item 7
   builds it, the fs double above, and `"a.txt"`: the script
   `ctrl-x`, `2`, `mouse down left 0 11`, `mouse move 0 5`,
   `mouse up left 0 5`, `escape` leaves the key list empty and
   records, for each key in order, `(columns 80)`, `(rows 24)`,
   `(write frame)`, `flush`, `(key k)`. There are six frames. The
   fourth equals the third. Splitting each frame on `\r\n`, the
   LIGHT sequence `\e[38;5;16;48;5;250m` begins the line at index 11
   of the third frame and the line at index 5 of the fifth, and the
   DARK sequence `\e[38;5;252;48;5;239m` begins the line at index 22
   of both; the fifth's line at index 11 does not begin with LIGHT.
   The sixth equals the fifth.

### Migration (spec §9.3, plus one)

Exactly three files change, one assertion each. Every other
expectation in them stays.

- `tests/aloemacs/mouse.rkt` item 14, line 342: the
  `(unchanged! 'e14b "mouse down left 0 11")` becomes the armed
  expectation: `(e14b handle-event "mouse down left 0 11")` equals
  `(e14b with (windows ((e14b windows) armed 1)))`, and its `drag`
  equals `(Option Some 1)`. The bottom-mode-line and echo-row
  presses stay unchanged, and the bar press stays as 002 left it.
  The test-case name may say the boundary row arms.
- `tests/aloemacs/split-drag-weights.rkt` item 10: the
  `(sb handle-event "mouse down left 0 11")` row was its only
  assertion. Remove the test case and its comment; 002 and 003 have
  replaced it. The nine items before it stay.
- `tests/aloemacs/split-drag-bar.rkt` item 4, line 196:
  `(check-false (ev '((tbr handle-at 0 11 root) present?)))` becomes
  `(same '(tbr handle-at 0 11 root) '(Option Some tbr))`: the
  boundary row of the below-then-right tree is now the root
  `Below`. The test-case name may drop "a Below only descends". Spec
  §8.4 asked for that assertion and §9.3 did not list it; this
  checkpoint does.

`tests/aloemacs/mode-buttons-press.rkt` is not edited: its presses
on `(s0 split-below)` at `(0, 22)` and `(10, 22)` are the bottom mode
line, `(77, 11)` is a label, and it has no `""` press on a boundary
row. No other file changes. If any other test fails, the product is
wrong; fix the product.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/split-drag-weights.rkt tests/aloemacs/split-drag-motion.rkt tests/aloemacs/split-drag-bar.rkt tests/aloemacs/split-drag-mode-line.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction
```

```sh
git diff --check
```

Every agent test run includes `TMPDIR=/tmp`, `-j 4`, and `-y`. Do
not commit `compiled/`. The product edit is `.aloe` only and needs
no rebuild before launch. The implementer does not need a TTY.
`tests/aloemacs/window-pictures.rkt` holds a 30 ms timing bar and
can fail under heavy parallel load; a failure there alone is rerun
by itself, not fixed.

The checkpoint is complete when:

- both test commands pass and `git diff --check` is clean; the
  second command passes 683 of its 684 tests at issuance plus the
  new file's, the one fewer being the removed item 10
- the only product changes are `rows-from`, `min-rows`, the
  boundary check in `handle-at`'s `Below` arm, the rewrite arm in
  `with-cut-at`'s `Below` arm, their two comments, and the `""`
  branch of `press-mode-line`, all in `file.aloe`
- `file.aloe` is still ASCII bytes
- the existing-test changes are limited to the three assertions
  above
- `tests/aloemacs/split-drag-mode-line.rkt` exists and covers the
  seven items above

Report the files changed and the verification output. Then stop.
This closes the series; there is no 004.

### Hand check (spec §10)

The hand check is the human's, after the tests are green, on a real
UTF-8 terminal with 256 colors and SGR mouse reporting, at least 80
by 24, in a window that can be resized:

```sh
cp SPEC.md /tmp/split-drag.txt
```

```sh
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
feature. When it passes, the series is accepted against spec §10's
eleven points.

## Non-goals

- Spec §3's out-of-scope list: drag-to-select, hover, mode `1003`,
  the wheel, the middle and right buttons doing anything; a click on
  a path component, the directory browser, describe, or jump to
  definition; painting `│`, a fourth glyph, a painted drag state, a
  cursor change, or a new face; dragging the echo row or the bottom
  mode line; changing selection, a point, scrolling, or an entry
  handoff from a drag; a keyboard resize, a keymap change, or a new
  command constructor; balancing, equalizing, saved layouts, or
  writing weights from anything but a drag or a split; a stricter
  floor or a clamp on a terminal resize; a new class, field, picture,
  session field, or Term method; changing `split-below`,
  `split-right`, `delete-window`, `other-window`, or the lock toggle;
  a display-width table; a change to `tui-term`, Gel, or
  `term-run.rkt`; editing any accepted spec or the parent map; a
  kernel message, a `SPEC.md` row, a `lib/` method, or a
  `CHECKPOINTS.md` entry.
- Any change to the labels, `label-at`, or the label branch of
  `press-mode-line`. A label press arms nothing.
- Do not edit a spec, a charter, a README, or another checkpoint.
  Do not issue 004. Do not start Boids.
