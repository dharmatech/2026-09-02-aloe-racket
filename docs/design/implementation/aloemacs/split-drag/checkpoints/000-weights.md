# aloemacs-split-drag 000 — Weights

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the spec sections named below, implement this slice, and stop
when green.

## Goal

A `Below` and a `Right` each remember how their space is divided:
two positive `Int` weights, `earlier` and `later`. The rectangle
divides by them. A split the user makes is `1 1`, which is today's
even cut at every extent, so no frame changes. Nothing arms, nothing
drags, and no mouse mode changes.

- `Below` gains `(earlier Int) (later Int)` after `bottom`; `Right`
  gains the same after `right`. Every `case` arm binds them. Every
  rebuild carries them through. `with-split` writes `1 1` on the
  node it builds.
- `AloemacsWindowRect` loses `earlier` and gains `cut`, `row-cut`,
  and `column-cut`. Its `top`, `bottom`, `left`, and `right` take
  `(earlier Int) (later Int)`.
- The five walks that call those four pass each node's weights.
- A constructed tree with unequal weights lays out per the formula,
  a terminal resize scales it, every tree rewrite preserves weights,
  and delete promotion keeps the promoted subtree's own weights.
- Eighteen existing test files change construction spelling only.
  Every expected rectangle, row, frame, refusal, cursor, origin, and
  Fs count stays.

This is the first of four checkpoints. Stop when the focused proof
and the wider suite pass. Do not start 001.

## Authority, identity, and starting point

The implementer receives this checkpoint and the spec. The
checkpoint narrows the spec to one slice and restates its migration
inventory from a scratch run of the tree at issuance. It does not
revise the spec.

- Identity: **aloemacs-split-drag 000**, filed as
  `checkpoints/000-weights.md`. This is a local editor checkpoint.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`. `let`
  is `((fn (names ...) body) call exprs ...)`, so its bindings are
  independent of one another; every `let` below is written that way.
  `/` on two `Int` values is integer division. No mutation, macros,
  inheritance, or new special forms.
- [../spec.md](../spec.md) governs:
  - §2.1: the predecessors and the tree this series starts from.
  - §3: the product boundary and the out-of-scope list.
  - §4: the file table and what stays alone.
  - §5.1: the weights and the thirty arms.
  - §5.2: the division, the pinned cut table, and the twenty walk
    sites.
  - §5.9: what the series leaves in place.
  - §6: this layer. §6.1 is the product edit, §6.2 the examples,
    §6.3 the migration, §6.4 the focused proof.
  - §10: verification and the acceptance list.
- The accepted windows spec stays the authority for leaf geometry,
  the split and delete minimums, the lock comparison inside delete,
  the resize rule, and the shrink fallback, except that the even cut
  is replaced by §5.2. The accepted window-bars, mode-line,
  mode-buttons, and mouse specs are unchanged. Do not edit those
  specs, their charters, or their checkpoints.

### Current tree

Start from
[examples/aloemacs/file.aloe](../../../../../../examples/aloemacs/file.aloe).
Line numbers are from the tree at issuance on 2026-10-11 and are
approximate; search before editing.

- `AloemacsWindowTree` (line 345) declares `Leaf (view)`,
  `Below (top bottom)`, `Right (left right)`. Its own methods with
  arms on both splits: `leaves` (354), `find-view` (364),
  `with-toggled-lock` (381), `without-pictures` (424),
  `without-pictures-of` (433), `sibling-for` (449), `without-view`
  (465), `with-split` (485), `with-view-buffer` (527),
  `retarget-buffer` (553). `single?`, `any-locked?`, `fresh-id`,
  `next-view`, and `next-in` use `else` or read no split.
- `AloemacsWindowRect` (line 575): `x`, `y`, `columns`, `rows`;
  `text-rows`, `positive?`, `same?`, `contains?`, `divider`,
  `earlier` (606), `top` (610), `bottom` (613), `left` (619),
  `right` (622), `spaces`, `pad-row`. `divider` is `(1 min extent)`.
  `earlier` is `(((extent - (self divider extent)) + 1) / 2)`. `top`
  cuts `(((self rows) + 1) / 2)` rows; `bottom` recomputes the same
  value in a local `let` named `earlier`. `left` and `right` call
  `(self earlier (self columns))`. Nothing else calls `earlier`.
- `define-methods AloemacsWindowTree` (line 635): the walks
  `rect-for` (653), `view-at` (668), `positive-layout?` (681),
  `with-pictures` (760), and `frame-rows` (777) each send
  `(rect top)`, `(rect bottom)`, `(rect left)`, and `(rect right)`
  once: twenty sites. `locked-rects-equal?`, `right-rows`,
  `blank-rows`, `built-rows`, `reused-rows`, and `picture-for` read
  no weight.
- `AloemacsWindows` (line 793) has `tree`, `selected`, `columns`,
  `rows`; its `with-split` (831) calls the tree's `with-split`.
  Nothing in `file.aloe` constructs `AloemacsWindows` with `new`.
- The session (line 1084): `split-window` (1432), `delete-window`
  (1496), `handle-event` (2051), `handle-mouse` (2059), `press-at`
  (2074), `press-mode-line` (2101). The no-leaf arm of `press-at`
  and the `""` branch of `press-mode-line` return `(self unchanged)`.
  They stay that way in this checkpoint.
- `examples/aloemacs/main.aloe` defines `aloemacs-editor` with `new*`
  forms. Tests load it with an injected `fs-host`. It does not
  change in this checkpoint.
- Seventeen tests pin the ordered `define-class` list of
  `file.aloe`. No class is added, so none of them changes for that
  reason. Two of them, `windows-state.rkt` and
  `windows-state-foundation.rkt`, also pin the two constructor
  payloads and are in scope for that pin only.

At issuance, from the project root,
`TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction`
passes 647 tests. The working tree has uncommitted edits in the
parent aloemacs map and this folder; they are documents, not code.

### Size

One conversation. The product edit is in `file.aloe` only: two
payload lines, thirty arm headers, twenty-six constructions, twenty
walk sites, and one replaced block of five rectangle methods that
becomes seven. Eighteen test files take spelling edits of one to
four lines each. The focused file is new.

The manager applied exactly the product edit of **Required
behavior** to a scratch copy of the tree and ran the wider suite.
Eighteen files failed, the eighteen in **Migration** below, for 91
of 647 tests. After the migration edits below, all 647 passed with
product changes only in `file.aloe`. The manager then checked every
value this checkpoint pins against that copy: the cut table, the
rectangles, the unequal layouts at every listed size, the 9 by 6
row, preservation through every listed send, the pictures, the
fallback, the type rejections, the two inert presses, and that seven
split frames are byte for byte the frames of the unedited tree. All
hold. If you cannot finish in this conversation, stop and report
which files remain. Do not split the slice or write 001.

The implementation on 2026-10-11 followed this checkpoint as
written. The manager reviewed the diff against this checkpoint and
found it conforming: the product diff is the two payloads, the
thirty arm headers, the twenty-six constructions, the rectangle
block, and the twenty walk sites, and nothing else; the eighteen
test files change only at the lines named; the focused file covers
the ten items, with the four frames of item 8 pinned as literals
captured before the edit; the focused file passes 11 tests, the
wider suite 658, and `git diff --check` is clean. The implementer
found one defect in this document: the `t2` expression of item 6
was missing one opening paren. It is corrected above. No comment in
a migrated file went stale.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, in exactly these places:
  1. The two split payloads of `AloemacsWindowTree`.
  2. The thirty `case` arm headers on `Below` and `Right` in the
     fifteen methods named under **Required behavior §1**.
  3. The twenty-six constructions in the eight methods named under
     **Required behavior §1**.
  4. On `AloemacsWindowRect`: remove `earlier`; add `cut`, `row-cut`,
     `column-cut`; replace `top`, `bottom`, `left`, `right`. The
     comment above `top` may change. Nothing else on the class.
  5. The twenty walk sites in `rect-for`, `view-at`,
     `positive-layout?`, `with-pictures`, and `frame-rows`.
  `file.aloe` stays ASCII bytes. Do not change the order of
  declarations.
- Create `tests/aloemacs/split-drag-weights.rkt` before the product
  edit, and watch it fail.
- The eighteen files under **Migration**, each only in the lines
  that section names: `completion-frame.rkt`,
  `completion-page-frame.rkt`, `completion-page-session.rkt`,
  `completion-session.rkt`, `idle-echo.rkt`, `mode-buttons-paint.rkt`,
  `mode-line-one-view.rkt`, `mode-line-split-views.rkt`,
  `window-bars-one-view.rkt`, `window-bars-split.rkt`,
  `window-pictures.rkt`, `window-point.rkt`,
  `windows-delete-and-other.rkt`, `windows-layout-and-rendering.rkt`,
  `windows-lock.rkt`, `windows-split.rkt`,
  `windows-state-foundation.rkt`, `windows-state.rkt`, all under
  `tests/aloemacs/`.

### Must leave untouched

- In `file.aloe`: `AloemacsView`, `AloemacsLeafPicture`,
  `AloemacsModeLine`, `AloemacsWindows` and its four fields,
  `AloemacsMouse`, `AloemacsCommand`, the keymaps, and the session's
  fourteen fields. On the tree: `single?`, `any-locked?`, `fresh-id`,
  `next-view`, `next-in`, `pictured?`, `locked-rects-equal?`,
  `right-rows`, `blank-rows`, `built-rows`, `reused-rows`,
  `picture-for`, and the bodies of `sibling-for`, `leaves`, and
  `find-view` beyond their arm headers. On the rect: `text-rows`,
  `positive?`, `same?`, `contains?`, `divider`, `spaces`, `pad-row`.
  On the session: everything, including `handle-event`,
  `handle-mouse`, `press-at`, `press-mode-line`, `split-window`,
  `delete-window`, `other-window`, `toggle-window-lock`,
  `enter-view`, `ensure-visible`, `fit-rect`, `root-rect`, `frame`,
  `record-pictures`, and the echo tokens.
- `examples/aloemacs/main.aloe`, `examples/aloemacs/editor.aloe`,
  everything under `host/racket/`, `lib/`, `aloe/`, `bin/`, `gel/`,
  `archive/`, `SPEC.md`, and `CHECKPOINTS.md`. Add no dependency,
  load, host capability, Term method, mouse mode, kernel message,
  `lib/` method, Text method, class, field, command, key, keymap
  entry, face, or build step. The mouse string, mode `1000`, and SGR
  `1006` are unchanged. `tui-term` is not edited.
- Every test not named above. In particular `tests/aloemacs/mouse.rkt`,
  `tests/aloemacs/mode-buttons-press.rkt`, and
  `tests/parenthetical-construction/session.rkt` construct no split
  and stay green unedited. The rejection loop at lines 201–203 of
  `windows-state-foundation.rkt` stays as it is (see **Migration**).
  If any test outside the eighteen fails, the product is wrong; fix
  the product. Do not edit a fixture, a geometry, or an expectation
  to force the suite green. Create no shared helper module.
- Every document: this checkpoint, `spec.md`, `charter.md`, and
  `README.md` in this folder; the windows, window-bars, mode-line,
  mode-buttons, mouse, window-point, window-pictures, and
  alternate-screen documents; and the parent `aloemacs/README.md`,
  `discussion.md`, and `explorations.md`.

If another file, another method, or a geometry change seems
necessary, stop and report it. Do not widen this checkpoint.

## Required behavior

### 1. The weights (spec §5.1)

Change the two payloads to:

```text
(Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree) (earlier Int) (later Int)))
(Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree) (earlier Int) (later Int)))
```

Both weights are positive `Int`. Nothing checks positivity at
construction; the only writer in this checkpoint, `with-split`,
writes `1 1`. Read as data, those two lines are exactly what the
declaration pins in **Migration** expect.

**Thirty arm headers.** Every `(Below (top bottom)` becomes
`(Below (top bottom earlier later)` and every `(Right (left right)`
becomes `(Right (left right earlier later)`: fifteen of each. They
are the two arms in each of `leaves`, `find-view`,
`with-toggled-lock`, `without-pictures`, `without-pictures-of`,
`sibling-for`, `without-view`, `with-split`, `with-view-buffer`,
`retarget-buffer`, `rect-for`, `view-at`, `positive-layout?`,
`with-pictures`, and `frame-rows`. A search for `(Below (top bottom)`
and `(Right (left right)`, each with its closing paren, finds
nothing after the edit; the new arms have a space there.

**Twenty-six constructions.** Every rebuild of a split appends the
two names its arm bound, in that order, after the second child.
Twenty-four rebuilds, by method:

| Method | Constructions | Each becomes |
|---|---:|---|
| `with-toggled-lock` | 4 | `(AloemacsWindowTree Below (top with-toggled-lock id) bottom earlier later)` and the three like it |
| `without-pictures` | 2 | `(AloemacsWindowTree Below (top without-pictures) (bottom without-pictures) earlier later)` and the `Right` |
| `without-pictures-of` | 2 | the multi-line `Below` and `Right`, with `earlier later` after the second child's send |
| `without-view` | 4 | `(AloemacsWindowTree Below (top without-view id) bottom earlier later)` and the three like it. The two `single?` promotions, which return `bottom`, `top`, `right`, or `left` bare, do not change: the promoted subtree keeps its own weights and the removed parent's go with it |
| `with-split`, the two split arms | 4 | `(AloemacsWindowTree Below (top with-split id fresh-id scroll-row scroll-col point below?) bottom earlier later)` and the three like it |
| `with-view-buffer` | 4 | `(AloemacsWindowTree Below (top with-view-buffer id buffer) bottom earlier later)` and the three like it |
| `retarget-buffer` | 2 | the multi-line `Below` and `Right`, with `earlier later` after the second child's send |
| `with-pictures` | 2 | the multi-line `Below` and `Right`, with `earlier later` after the second child's send |

The two fresh constructions in `with-split`'s `Leaf` arm write the
even split:

```aloe
(if below?
    (AloemacsWindowTree Below original fresh 1 1)
    (AloemacsWindowTree Right original fresh 1 1))
```

Nothing else in `file.aloe` constructs a split. After the edit, a
search for `AloemacsWindowTree Below` and `AloemacsWindowTree Right`
finds twenty-six forms, each ending in `earlier later)` or `1 1)`.

### 2. The division (spec §5.2)

On `AloemacsWindowRect`, delete `earlier`, `top`, `bottom`, `left`,
and `right`, and put this in their place. It can be pasted as it is:

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

`divider` stays `(1 min extent)`. In words:

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

With `1 1`, `share` is `(extent + 1) / 2`, today's `earlier` on both
axes, and the clamp is the identity, so every tree a split builds
has today's rectangles at every extent, including the extents of
the shrink fallback. The clamp exists for unequal weights after a
shrink: with four rows the top keeps two.

Pinned values. Each row is
`((AloemacsWindowRect new 0 0 0 0) cut extent least earlier later)`:

| Axis | extent | least | earlier, later | cut |
|---|---:|---:|---|---:|
| Below | 23 | 2 | 1, 1 | 12 |
| Below | 23 | 2 | 6, 17 | 6 |
| Below | 11 | 2 | 6, 17 | 3 |
| Below | 5 | 2 | 6, 17 | 2 |
| Below | 4 | 2 | 6, 17 | 2 |
| Below | 3 | 2 | 6, 17 | 1 |
| Below | 2 | 2 | 6, 17 | 1 |
| Below | 3 | 2 | 1, 1 | 2 |
| Below | 3 | 2 | 22, 1 | 2 |
| Below | 3 | 2 | 1, 22 | 1 |
| Below | 1 | 2 | 1, 1 | 1 |
| Right | 79 | 1 | 1, 1 | 40 |
| Right | 79 | 1 | 30, 49 | 30 |
| Right | 119 | 1 | 30, 49 | 46 |
| Right | 2 | 1 | 30, 49 | 1 |
| Right | 1 | 1 | 30, 49 | 1 |
| Right | 0 | 1 | 1, 1 | 0 |

On `(AloemacsWindowRect new 0 0 80 23)`: `row-cut` is 12, 6, and 9
and `column-cut` is 40, 21, and 30 for `1 1`, `6 17`, and `30 49`.
`top 6 17` is `(0, 0, 80, 6)`, `bottom 6 17` is `(0, 6, 80, 17)`,
`left 30 49` is `(0, 0, 30, 23)`, `right 30 49` is `(31, 0, 49, 23)`.
With `1 1` the four are `(0, 0, 80, 12)`, `(0, 12, 80, 11)`,
`(0, 0, 40, 23)`, and `(41, 0, 39, 23)`, today's values.
`(AloemacsWindowRect new 2 3 7 n) top 1 1` and `bottom 1 1`
reproduce the window-bars table for `n` from 0 to 9, and
`(AloemacsWindowRect new 2 3 n 4) left 1 1` and `right 1 1`
reproduce its Right table; those tables are the loops at lines
242–260 of `tests/aloemacs/window-bars-split.rkt`.

### 3. The walks (spec §5.2)

In `rect-for`, `view-at`, `positive-layout?`, `with-pictures`, and
`frame-rows`, each `(rect top)` becomes `(rect top earlier later)`,
and likewise `bottom`, `left`, and `right`: five of each, twenty
sites. The names are the ones the arm now binds. The walk order,
the `Some`/`None` handling, and the `right-rows` composition are
unchanged.

### 4. What stays in place (spec §5.9)

`split-below`, `split-right`, `delete-window`, `other-window`, and
`toggle-window-lock` are the same sends with the same refusals and
the same echo tokens: a below split still needs four rows, a right
split three columns, and the lock comparison inside delete still
compares four coordinates, now under the weighted division. The
session, `AloemacsWindows`, `AloemacsMouse`, the host, and the
runner are untouched. The frame is one `String` and no frame byte
changes. The picture cache gains no key; it already matches on
`columns` and `rows`. No press arms anything: a left press on a bar
and a non-label mode-line press still return the receiver.

## Tests

### Focused proof: `tests/aloemacs/split-drag-weights.rkt`

Write this file first and watch it fail. It uses a checked driver
and `rackunit`, loads `main.aloe` through `driver-load-file!` with
the `fs-host` injected first, and does not open a TTY. It does not
call `with-term`, `call-with-tty-term-receiver`, `run-aloemacs`, or
`run-aloemacs-with-hosts`. Copy the helpers you need from
`tests/aloemacs/mouse.rkt` (`ev`, `def!`, `same`, `dtype`,
`rejects`) and from `tests/aloemacs/windows-state.rkt` (reading
`file.aloe` with `port->list read` and the `decl` finder). Do not
`require` another test module.

The fs double is the one `mouse.rkt` uses:

```racket
(make-fs-double "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
  (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b"))
```

Fixtures, each an Aloe expression on the loaded `main.aloe`:

| Name | Expression |
|---|---|
| `s0` | `((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)` |
| `sr` | `(s0 split-right)`: view 0 selected on the left, view 1 on the right |
| `sb` | `(s0 split-below)`: view 0 selected on top, view 1 below |
| `root` | `(AloemacsWindowRect new 0 0 80 23)` |
| `v0`, `v1` | `((((sr windows) tree) leaves) first)` and `(((((sr windows) tree) leaves) rest) first)`, the two views `sr` stores |
| `b0`, `b1` | the same two reads on `sb` |
| `ur` | `sr` with its tree replaced: `(sr with (windows ((sr windows) with (tree (AloemacsWindowTree Right (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 30 49)))))` |
| `ub` | `sb` with its tree replaced by `(AloemacsWindowTree Below (AloemacsWindowTree Leaf b0) (AloemacsWindowTree Leaf b1) 6 17)` |

To read a node's weights, send a `case` with an `else` arm, for
example `(tree case (Right (l r e la) e) (Below (t b e la) e) (else -1))`
for `earlier` and the same with `la` for `later`. To reach the top
or left child, `(tree case (Below (t b e la) t) (Right (l r e la) l) (else tree))`.
"Equals" is `(check actual expected)` through the driver. Expected
values are raw constructors, selectors, and the sends named below.
Prove:

1. **Types and arities.** With `v0` and `v1` as leaves `a` and `b`:
   `(AloemacsWindowTree Below a b)`, `(AloemacsWindowTree Below a b 1)`,
   `(AloemacsWindowTree Below a b 1 1 1)`, and
   `(AloemacsWindowTree Right a b "1" 1)` are rejected
   (`exn:fail:aloe-type?`). `(root cut 1 2 3 4)` types as `Int`;
   `(root cut 1 2 3)` and `(root cut 1 2 3 4 5)` are rejected.
   `(root row-cut 1 1)` and `(root column-cut 1 1)` type as `Int`;
   `(root row-cut 1)` is rejected. `(root top 1 1)`, `bottom`,
   `left`, and `right` type as `AloemacsWindowRect`; `(root top)`,
   `(root top 1)`, and `(root top 1 1 1)` are rejected, and the same
   for the other three. `(root earlier 5)` is rejected. Read as
   data, the `AloemacsWindowTree` declaration's constructors are
   `(Leaf (fields (view AloemacsView)))`, then the two payload lines
   of **Required behavior §1**; `AloemacsWindowRect` still declares
   `(fields (x Int) (y Int) (columns Int) (rows Int))`;
   `AloemacsWindows` still declares
   `(fields (tree AloemacsWindowTree) (selected Int) (columns Int) (rows Int))`;
   and the ordered `define-class` list is the one `windows-state.rkt`
   pins, unchanged.
2. **The cut.** Every row of the table in **Required behavior §2**
   through `cut` on `(AloemacsWindowRect new 0 0 0 0)`. The six
   `row-cut` and `column-cut` values on `root`. For every `n` from
   0 to 30, `((AloemacsWindowRect new 0 0 0 n) row-cut 1 1)` equals
   `(quotient (+ n 1) 2)`, and `((AloemacsWindowRect new 0 0 n 0) column-cut 1 1)`
   equals `(quotient (+ (- n (min 1 n)) 1) 2)`, computed in Racket.
3. **The four rectangles.** The eight `top`, `bottom`, `left`, and
   `right` values on `root` in **Required behavior §2**, and the two
   window-bars loops: for `n` from 0 to 9, with `top` from
   `(0 1 1 2 2 3 3 4 4 5)` and `bottom` from `(0 0 1 1 2 2 3 3 4 4)`,
   `((AloemacsWindowRect new 2 3 7 n) top 1 1)` is
   `(AloemacsWindowRect new 2 3 7 top)` and `bottom 1 1` is
   `(AloemacsWindowRect new 2 (+ 3 top) 7 bottom)`; with `left` from
   `(0 0 1 1 2 2 3 3 4 4)`, `later` from `(0 0 0 1 1 2 2 3 3 4)`, and
   `offset` from `(0 1 2 2 3 3 4 4 5 5)`,
   `((AloemacsWindowRect new 2 3 n 4) left 1 1)` is
   `(AloemacsWindowRect new 2 3 left 4)` and `right 1 1` is
   `(AloemacsWindowRect new (+ 2 offset) 3 later 4)`.
4. **A split writes `1 1`.** `((sr windows) tree)` equals
   `(AloemacsWindowTree Right (AloemacsWindowTree Leaf v0) (AloemacsWindowTree Leaf v1) 1 1)`.
   `sb`'s tree reads `1 1`. `((sb split-right) windows) tree` reads
   `1 1` at the root and `1 1` at its top child.
5. **An unequal tree lays out.** On `ur`: `rect-for 0 root` is
   `(Option Some (AloemacsWindowRect new 0 0 30 23))`, `rect-for 1 root`
   is `(Option Some (AloemacsWindowRect new 31 0 49 23))`,
   `view-at 30 5 root` is `(Option None)`, `view-at 31 5 root` holds
   view 1, and `positive-layout? root` is true. On
   `(ur ensure-visible 120 24)`, `rect-for` on
   `(AloemacsWindowRect new 0 0 120 23)` gives `(0, 0, 46, 23)` and
   `(47, 0, 73, 23)`, `((windows) columns)` is 120, and the tree
   still reads `30 49`. On `ur`'s tree with root
   `(AloemacsWindowRect new 0 0 3 23)`: `(0, 0, 1, 23)` and
   `(2, 0, 1, 23)`. With root `(AloemacsWindowRect new 0 0 2 23)`:
   `(0, 0, 1, 23)` and `(2, 0, 0, 23)`, and `positive-layout?` is
   false. On `(ur ensure-visible 2 24)`, `(fit-rect 2 24)` is
   `same?` as `(root-rect 2 24)`, and `(frame 2 24)` equals
   `((s0 ensure-visible 2 24) frame 2 24)`, the one-view frame.
   On `ub`'s tree, `rect-for 0` and `rect-for 1` on
   `(AloemacsWindowRect new 0 0 80 rows)`:

   | rows | `rect-for 0` | `rect-for 1` |
   |---:|---|---|
   | 23 | `(0, 0, 80, 6)` | `(0, 6, 80, 17)` |
   | 11 | `(0, 0, 80, 3)` | `(0, 3, 80, 8)` |
   | 5 | `(0, 0, 80, 2)` | `(0, 2, 80, 3)` |
   | 4 | `(0, 0, 80, 2)` | `(0, 2, 80, 2)` |
   | 3 | `(0, 0, 80, 1)` | `(0, 1, 80, 2)` |
   | 2 | `(0, 0, 80, 1)` | `(0, 1, 80, 1)` |
   | 1 | `(0, 0, 80, 1)` | `(0, 1, 80, 0)` |

   On `(ub ensure-visible 80 12)` the tree still reads `6 17`.
6. **An unequal frame composes.** Use a second driver with an fs
   double whose `/cwd/a.txt` is `abcdefgh` and `/cwd/b.txt` is
   `ABCDEFGH`. Build
   `t2` as `((((((aloemacs-editor visited "abcdefgh" (Path new "/cwd/a.txt")) ensure-visible 9 6) split-right) other-window) find-file-submitted "b.txt") other-window)`:
   view 0 selected on `a.txt`, view 1 on `b.txt`. Read its two
   leaves as `w0` and `w1`, and build `tw` as `t2` with its tree
   replaced by
   `(AloemacsWindowTree Right (AloemacsWindowTree Leaf w0) (AloemacsWindowTree Leaf w1) 2 6)`.
   Then `((((tw windows) tree) frame-rows (tw buffers) (AloemacsWindowRect new 0 0 9 5) 0) first)`
   is `"ab|ABCDEF"`, the same send on `t2` gives `"abcd|ABCD"`, and
   the `tw` list has five rows (fold with `(fn (n row) (n + 1))`
   from 0). Assert row 0 and the count only; the mode rows carry
   the bar colors and are pinned by the existing frame goldens.
7. **Preservation.** Build `pt` from `((sb split-right) windows) tree`,
   which is `Below (Right (Leaf 0, Leaf 2) 1 1, Leaf 1) 1 1`, by
   rebuilding it with `30 49` inside and `6 17` outside through a
   `case`, and `ps` as that session with `pt` installed. `bid` is
   `((ps current-buffer) id)`. Each of `(pt with-toggled-lock 2)`,
   `(pt without-pictures)`, `(pt without-pictures-of bid)`,
   `(pt with-view-buffer 0 (ps current-buffer))`,
   `(pt retarget-buffer bid 99 0 0 (Position new 0 0))`, and
   `(pt with-pictures (ps buffers) root 0)` reads `6 17` at the root
   and `30 49` at its top child.
   `(pt with-split 0 3 0 0 (Position new 0 0) #t)` reads `6 17`,
   then `30 49` at the top child, then `1 1` at that child's left
   child, which is a `Below`. `(pt without-view 1)` is a `Right`
   reading `30 49`. `(pt without-view 2)` is a `Below` reading
   `6 17`. Through the session, each of `(ps split-below)`,
   `(ps split-right)`, `(ps other-window)`, `(ps toggle-window-lock)`,
   `(ps ensure-visible 120 30)`, `(ps record-pictures 80 24)`,
   `(ps find-file-submitted "b.txt")`, and `(ps handle-event "x")`
   has a tree reading `6 17` at the root and `30 49` at its top
   child. `(ps delete-window)` removes the selected view 0 and
   promotes leaf 2: its tree is a `Below` reading `6 17` whose top
   child is a `Leaf`.
8. **Today's frames.** `((s0 split-right) frame 80 24)`,
   `((s0 split-below) frame 80 24)`,
   `(((s0 split-below) split-right) frame 80 24)`, and
   `(((s0 ensure-visible 40 10) split-below) frame 40 10)` are byte
   for byte the frames the tree paints before this checkpoint.
   Before the product edit, evaluate the four sends through the
   driver on the unedited tree and pin the results as string
   literals, spelling ESC as `\e` and the bar colors as
   `mode-line-one-view.rkt` spells `LIGHT`, `DARK`, and `PLAIN`;
   or build each expectation with a helper written from the row
   rules of the window-bars and mode-buttons specs, as
   `window-bars-split.rkt` does. Do not send a composer to build the
   expectation. As a check on a captured literal: the four frames
   are 1963, 1963, 1987, and 455 characters, and split on `\r\n`
   into 23, 23, 23, and 9 lines. Keep every whole-frame assertion.
9. **Pictures.** On `ur`, with `f1` as `(ur frame 80 24)`:
   `((ur record-pictures 80 24) frame 80 24)` equals `f1`, a second
   `record-pictures 80 24` then `frame 80 24` equals `f1` again,
   and the tree after recording still reads `30 49`.
10. **No press arms.** `(sr handle-event "mouse down left 40 5")`
    equals `sr`. `(sb handle-event "mouse down left 0 11")` equals
    `sb`. 002 and 003 replace this item.

### Migration (spec §6.3)

Eighteen files change construction spelling only. Line numbers are
from the tree at issuance; search for the text before editing. Every
expected rectangle, row, frame, refusal, cursor, origin, and Fs
count in these files stays as it is. Keep every whole-frame
assertion; do not replace one with a substring check.

**Helpers.** Eleven files define
`` (define (right a b) `(AloemacsWindowTree Right ,a ,b)) `` and
`` (define (below a b) `(AloemacsWindowTree Below ,a ,b)) ``. Each
gains ` 1 1` before its closing paren: `` `(AloemacsWindowTree Right ,a ,b 1 1) ``.
One edit per helper, two per file:

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

**Inline constructions.** Each split gains ` 1 1` after its second
child, inside its own closing paren. Where a `Right` holds a
`Below`, both gain it:

| File | Lines | Edit |
|---|---|---|
| `completion-page-session.rkt` | 428, 431 | a `Right` holding a `Below`. The form ends `(Option None))))) 7 43 13)`; it becomes `(Option None))) 1 1) 1 1) 7 43 13)` |
| `completion-session.rkt` | 590, 593 | the same `Right` holding a `Below` in `source`. The form ends `(Option None)))))` then `7 43 13)` on the next line; the first becomes `(Option None))) 1 1) 1 1)` |
| `completion-session.rkt` | 730 | a `Right` of two leaves in `split`. The form ends `(Option None)))) 0 9 4)`; it becomes `(Option None))) 1 1) 0 9 4)` |
| `idle-echo.rkt` | 139 | `(AloemacsWindowTree Below ,(leaf 7 41 0 1) ,(leaf 3 9 0 1))` becomes `(... ,(leaf 3 9 0 1) 1 1)` |
| `idle-echo.rkt` | 168 | `(AloemacsWindowTree Right ,(leaf 7 0 0 1) ,(leaf 3 0 0 1))` becomes `(... ,(leaf 3 0 0 1) 1 1)` |
| `mode-line-one-view.rkt` | 209 | a `Right` of two leaves. The form ends `(Option None)))) 0 12 4)`; it becomes `(Option None))) 1 1) 0 12 4)` |
| `window-pictures.rkt` | 121 | `(AloemacsWindowTree Right left (AloemacsWindowTree Leaf (view with ...)))` rebuilt around the planted picture. Line 128 ends in fourteen closing parens after `marker`. Counting outward they close `make-list`, `List`, `lines`, `picture with`, `Option Some`, the `picture` field, `view with`, `Leaf`, then `Right`, so the `Right`'s paren is the ninth. Insert ` earlier later` after the eighth and before the ninth, so the line ends `marker)))))))) earlier later))))))`, using the names the arm at line 112 now binds. One paren earlier puts the weights on the `Leaf`, and the test fails to type-check |
| `windows-layout-and-rendering.rkt` | 153, 157 | `'(AloemacsWindowTree Right a b)` and `'(AloemacsWindowTree Below a b)` each gain ` 1 1` |
| `windows-state.rkt` | 62–65 | the `tree` helper: the inner `Below` and both `Right`s and the outer `Below` each gain ` 1 1`. Line 64 ends `,(leaf (list-ref vs 2)) 1 1) 1 1)` and line 65 ends `,(leaf (list-ref vs 4)) 1 1) 1 1))` |
| `windows-state-foundation.rkt` | 174–176 | the `tree` fixture: line 175 ends `(AloemacsWindowTree Leaf v4) 1 1)` and line 176 ends `(AloemacsWindowTree Leaf v2) 1 1) 1 1))` |

**`case` arms.** Each binds the two new names:

| File | Lines | Today | 000 |
|---|---|---|---|
| `mode-line-one-view.rkt` | 219, 221, 230 | `(Right (a b) b)` | `(Right (a b e l) b)` |
| `window-pictures.rkt` | 112 | `(Right (left right)` | `(Right (left right earlier later)` |

**Declaration pins.** These read `file.aloe` as data. Each gains
`(earlier Int) (later Int)` on both split lines, so the two lines
read exactly as **Required behavior §1** writes them:

| File | Lines |
|---|---|
| `windows-state.rkt` | 635–636 |
| `windows-state-foundation.rkt` | 143–144 |

**Rect sends.** Each gains ` 1 1`:

| File | Lines | Today | 000 |
|---|---|---|---|
| `window-bars-split.rkt` | 248–249 | `` `(,(rect 2 3 7 n) top) `` and `bottom` | `` `(,(rect 2 3 7 n) top 1 1) `` and `bottom 1 1` |
| `window-bars-split.rkt` | 258–259 | `` `(,(rect 2 3 n 4) left) `` and `right` | `` `(,(rect 2 3 n 4) left 1 1) `` and `right 1 1` |
| `mode-buttons-paint.rkt` | 398–399 | `'((AloemacsWindowRect new 0 0 9 3) top)` and `bottom` | `'((AloemacsWindowRect new 0 0 9 3) top 1 1)` and `bottom 1 1` |

**Keep rejected.** `windows-state-foundation.rkt` lines 201–203
send `(AloemacsWindowTree Below tree v4)`,
`(AloemacsWindowTree Right v4 tree)`, `(AloemacsWindowTree Below tree)`,
and `(AloemacsWindowTree Right tree tree tree)` inside a rejection
loop. Two and three payloads are still the wrong count; those lines
do not change.

No other file changes. `tests/aloemacs/mouse.rkt`,
`tests/aloemacs/mode-buttons-press.rkt`, and
`tests/parenthetical-construction/session.rkt` construct no split
and need no edit. The seventeen class-list pins stay green: no
class is added. If any file outside the eighteen fails, the product
is wrong; fix the product.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/split-drag-weights.rkt
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
  second command passes its 647 tests at issuance plus the new file's
- the only product changes are in `file.aloe`: the two payloads, the
  thirty arm headers, the twenty-six constructions, the rectangle
  block of **Required behavior §2**, and the twenty walk sites
- `file.aloe` is still ASCII bytes, contains no `earlier (extent`,
  and a search for `(rect top)`, `(rect bottom)`, `(rect left)`,
  `(rect right)`, `(Below (top bottom)`, and `(Right (left right)`,
  each including its closing paren, finds nothing
- the existing-test changes are limited to the eighteen files above,
  in the lines named
- `tests/aloemacs/split-drag-weights.rkt` exists and covers the ten
  items above

Report the files changed and the verification output. Then stop.
Do not write 001.

## Non-goals

- Spec §3's out-of-scope list: drag-to-select, hover, mode `1002`
  or `1003`, the wheel, the middle and right buttons; a click on a
  path component, the directory browser, describe, or jump to
  definition; painting `│`, a fourth glyph, a painted drag state, a
  cursor change, or a new face; dragging the echo row or the bottom
  mode line; changing selection, a point, scrolling, or an entry
  handoff; a keyboard resize, a keymap change, or a new command
  constructor; balancing, equalizing, saved layouts, or writing a
  weight from anything but a split; a stricter floor or a clamp on a
  terminal resize; a new class, field, picture, session field, or
  Term method; changing `split-below`, `split-right`,
  `delete-window`, `other-window`, or the lock toggle; a
  display-width table; a change to `tui-term`, Gel, or
  `term-run.rkt`; editing any accepted spec or the parent map; a
  kernel message, a `SPEC.md` row, a `lib/` method, or a
  `CHECKPOINTS.md` entry.
- Everything 001 through 003 own: `AloemacsWindows.drag`, `armed`,
  `disarmed`, `AloemacsMouse.move?`, the move string,
  `mouse-event-pattern`, `tmousemsg->aloe-mouse`, the runner's mode
  bytes, `first-id`, `handle-id`, `min-rows`, `min-columns`,
  `rows-from`, `columns-from`, `handle-at`, `with-cut-at`,
  `press-handle`, `drag-to`, and any change to `handle-event`,
  `handle-mouse`, `press-at`, or `press-mode-line`. A press arms
  nothing in this checkpoint.
- A weight other than `1 1` written by the program. Unequal weights
  exist only in constructed test trees.
- Do not edit a spec, a charter, a README, or another checkpoint.
  Do not start Boids.
