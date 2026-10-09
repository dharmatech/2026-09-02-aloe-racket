# Charter — aloemacs window bars

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **the mode line as the
horizontal edge of a window, drawn as a bar**. The series identity
is **aloemacs-window-bars**. A tall window keeps the name row it
has today. That row is the only horizontal boundary of the window.
A Below split spends no row on a rule of dashes. Every painted
mode line has a background distinct from the buffer text. The
selected window's bar is lighter. Every other mode line is darker.
Then **stop**. Do not write checkpoints. Do not implement.

This effort refuses a new vertical-divider character, a face or
attribute on a text span, a mode name, a dirty mark, a position
readout, a window number, a new key, and any change to the echo
row's text. Those stay later or out, so this spec stays small
enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-window-bars 000** under
   `docs/design/implementation/aloemacs/window-bars/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the checkpoints in §4.8. A box-drawing vertical
rule, a span face, or a second horizontal rule are defects in
this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 is implemented. A window is a view of a buffer. Right reserves one column and paints a vertical bar. Below reserves one row and paints a dash rule, with a plus where a vertical divider meets that row. The accepted windows spec is the geometry law this series amends only as §4.3 says |
| [`../mode-line/`](../mode-line/) | aloemacs-mode-line 000–001 is implemented. A leaf of height at least 2 paints `(buffer name)`, then a space when it fits, then `-` fill, on its last row. A shorter leaf is all text. The echo row stays the last screen row. Direct editor `frame` has no mode line |
| [`../echo/`](../echo/) | The last screen row is the echo row when `rows >= 2`. The root text rectangle is `rows - 1` |
| [`../safe-cells/`](../safe-cells/) | A control paints as one space after clipping |

Final human review of windows and of the mode line remains. This
series reads those accepted specs and does not wait for that
review. It does not edit those specs, those charters, or those
checkpoints. A defect in either series that blocks a bar stops
this spec; the designer reports it and does not patch the earlier
series from here.

Idle echo, completion, and completion page are not predecessors.
Do not implement them here and do not edit their documents. A
frame golden already in the tree moves only when this contract
changes its mode-line bytes or its Below rule row.

**Why this layer:** four views of one file currently end in a
name-and-dash row and then, between upper and lower windows, a
second dash row. The name row is the same color as the buffer, so
the extra row is doing the separating, and no window is marked
current. GNU Emacs and the Chez editor `e` use the mode line itself
as that edge and give it a background, lighter on the current
window.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **The name row stays the name row.** The visible cells of a
   mode line are still the accepted mode-line spelling: the
   buffer name, a space when it fits, then `-` fill, clipped by
   prefix, then safe cells. The row's visible width is the leaf
   width. ANSI bytes around those cells occupy no cell.
2. **The mode line is the horizontal edge.** In a no-TTY frame of
   two or more stacked windows, no row between an upper leaf and
   the leaf below it is a rule of `-` and `+`. When both leaves
   are at least two rows tall, the upper leaf's last row is its
   mode line and the next row is the lower leaf's first text row.
3. **Every mode line is a bar.** A tall leaf's mode line is
   painted with a background distinct from the buffer text. The
   leaf whose view id is the selected id uses the lighter
   background. Every other mode line uses the darker background.
   Two tall views of one buffer still differ that way. A leaf
   shorter than two rows has no mode line, no bar, and no
   substitute rule.
4. **The bar stops at the mode line.** Buffer text, the echo row,
   an active prompt, a search echo, and a completion list are not
   left inside either mode-line sequence. The cursor stays in the
   text rows, or on the echo row while a prompt is active. It
   never sits on the mode line. While a prompt owns the cursor,
   the selected window's bar is still the lighter one.
5. **Right splits stay.** A Right split still reserves one
   column and paints `|` on every row of that rectangle,
   including beside a mode line. Its child rectangles match the
   accepted windows spec. This series introduces no vertical
   glyph and no `+`.
6. **State otherwise matches today.** Idle keys, search, quit,
   visit, save, switch, kill-buffer, find-file, save-as,
   select-buffer, both splits, delete, other-window, and lock
   keep today's text, point, quit flag, mark, kill-ring, undo
   history, search flags, echo token, pending map, prompt,
   submission, buffer zipper, window tree, locks, and written
   file. Below rectangles change only as §4.3 and §5.2 say. Fit
   still uses the selected leaf's text height. Unselected origins
   stay until that view is fitted.
7. **A person can see it.** The spec names a hand check, separate
   from the no-TTY byte tests: four windows on one file, the
   current window's whole mode line lighter, the other three
   darker, no dash rule under the upper mode lines, and the
   vertical stroke still `|`.

## 4. Locked decisions

### 4.1 What it is

The bar is session display, derived when the frame is built. The
session, the buffer, the view, and `AloemacsEditor` gain no field
for it. `AloemacsEditor` gains no mode-line method. Direct editor
`frame` keeps today's bytes.

The visible spelling stays the accepted mode-line rule. This
series adds the background around those cells and removes the
Below rule row. It does not add a mode name, a dirty mark, a line
or column, a percentage, a lock mark, a window number, or a
pending-key badge.

"Current" means the selected view id on the window tree. It does
not mean the view under the cursor when a prompt has moved the
cursor to the echo row, and it does not mean "the view whose
buffer has point." Several views of one buffer paint one lighter
bar, on the selected view.

### 4.2 The two backgrounds

Both backgrounds differ from the buffer, which stays the terminal
default. The selected mode line is the lighter bar. Each other
mode line is the darker bar. A one-view frame and the
too-small-tree fallback paint their single mode line with the
lighter background, because that paint is the selected buffer.

The sequences are ANSI strings inside the frame, the same way the
existing clear and cursor sequences are. They are not a new Term
method and not a host capability. They are not cells. Safe cells
still runs on the visible name, not on the sequences. A control
in the name still paints as one space inside the bar.

This is not the faces exploration. There is no attribute on a
text span, no face name, and no per-character style in the buffer.
The two treatments belong only to the mode-line row.

### 4.3 Below spends no rule row

Right allocation stays the accepted windows formula, including
the minimum of three columns and the one-column `|` divider.

Below no longer reserves a row. The row a Below split spends
today on `-` and `+` becomes part of a child rectangle. The
parent's width and x stay. Sibling rectangles outside that Below
stay exact. A new split still changes only the selected leaf's
rectangle.

There is no horizontal divider query left to satisfy and no `+`
junction. A vertical divider occupies its own column inside its
Right rectangle and does not paint a cell of a neighboring
window. The one-cell extension that existed to meet a parent
horizontal rule goes away with that rule.

A leaf shorter than two rows stays all text. This series does not
invent a rule, a bar, or a blank separator for that leaf.

The root text rectangle is still `rows - 1` when `rows >= 2`.
The echo row is still the last screen row. This series adds no
screen-level row. The too-small-tree fallback still paints the
selected buffer in the whole text rectangle, with no dividers,
and with the lighter bar when that rectangle is at least two
rows tall.

### 4.4 Fit, cursor, and echo

Fit the selected view through the existing `ensure-visible`,
using that leaf's text height: one less than the leaf height when
the leaf has a mode line, otherwise the whole leaf. Page up and
page down use that text height. The cursor formula still
addresses the text rectangle. Echo selection and clipping stay:
prompt, then active search, then `saved:` / `failed:` / the idle
path or `untitled`. An active prompt or search still owns the
echo row.

### 4.5 One view and a split

For one tall leaf, the session frame is the text rows, then the
lighter bar, then today's echo suffix. The bytes of the text rows
match today's one-view text for that height. For one short leaf,
session `frame` keeps today's complete string, with no bar
sequences.

For several leaves, compose as the accepted windows spec
composes, except that a Below split contributes no rule row, each
tall leaf's last row is its bar, and a Right split's divider
column is `|` on every row of that rectangle. A short leaf is
still all buffer text. Padding, safe cells, one clear, one write,
and one cursor sequence stay.

### 4.6 What this series leaves alone

`Text` gains no method. `SPEC.md` gains no row. The kernel gains
no message. List gains no index message. The runner, Term, and
`AloemacsEditor`'s fields stay. Window commands stay the same
sends. The echo token keeps its three values. The buffer name
stays the derived path text or `"untitled"`. The ASCII cell lock
stays: the visible mode line is ASCII, and this series does not
introduce a line-drawing character.

### 4.7 Where the paint lives

The bar is built by `AloemacsModeLine` or by one new fieldless
nongeneric helper beside it. No instance is stored. The recursive
send that walks the window tree does not gain a recursive display
walk on `(AloemacsSession H)` or on any other legacy generic
`(fields ...)` class. The spec names the selector in §5.

### 4.8 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-window-bars 000** | The one-view name row is the lighter bar. Visible cells match the accepted spelling. Text rows and the echo row are outside the sequence. A short one-view frame and direct editor `frame` match today. Below still has its rule row |
| **aloemacs-window-bars 001** | A Below split has no rule row. Each tall leaf is a bar: lighter on the selected view, darker on the others. A short leaf is text. Right rectangles and the vertical bar match today. The cursor, the echo row, fit at the new text height, and the too-small fallback follow §4 |

000 is testable on a one-view frame and does not create a colored
bar stacked on the dash rule. 001 removes that rule in the same
checkpoint that paints both bars on a split. 001 is testable once
000 is green. The manager writes 000 only, then stops.

If 001's geometry and golden migration would not fit one
implementer conversation, the spec adds the next number and keeps
this order: the one-view bar, then the Below edge, then the
inactive bar only if that last part is why 001 broke. That added
number introduces no second feature. The spec does not leave a
split frame whose accepted look is a colored mode line with the
dash rule still under it.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The sequences.** Which ANSI sequences paint the lighter bar
   and the darker bar, and which sequence restores the buffer
   background. Visible cells follow §4.1 and count as `width`.
   Give the wrapped row for a selected window and for an
   unselected window at a width where the name fits with fill,
   and at width 1. Width 0 is still not a painted row. Say where
   the restoring sequence sits when the mode line is the last
   text row before the echo row, and when the next row is buffer
   text of the leaf below.
2. **Below division.** With no reserved row, give `earlier` and
   `later` for an extent `n`, including the nominal case that can
   produce a zero axis. Give the minimum `n` at which a below
   split is allowed. Right stays at three. Prefer refusing a
   below split when either child would be shorter than two rows,
   and choose that or a lower minimum. Either way, a child
   shorter than two rows has no bar and no substitute rule. Show
   the rectangles for the accepted windows example: a 9-by-5
   text rectangle split right, then its left view split below.
   The right view stays `(5,0,4,5)` and the divider stays at
   x=4. Show one below split the command refuses.
3. **The selector.** The send on `AloemacsModeLine`, or on the
   one helper §4.7 allows, that wraps a visible row for the
   selected bar and for the inactive bar. It is a pure display
   send. It is not a stored field and not an `AloemacsEditor`
   method.

## 6. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  the window bars
- [`../explorations.md`](../explorations.md) — Band 3. Faces
  stay the later exploration. This bar is not that algebra
- [`../windows/spec.md`](../windows/spec.md) — leaf geometry,
  Right dividers, selected-only fit, one-view and multi-view
  composition, locks, and the echo rule. §4.3 and §4.5 of this
  charter supersede only Below's reserved row, the `-` rule, and
  the `+` junction
- [`../mode-line/spec.md`](../mode-line/spec.md) — the visible
  name-row spelling, the short leaf, and derived display.
  §4.2 of this charter supersedes only that spec's refusal of
  reverse video and of a selected-window style, and only for
  this bar. Do not amend that spec
- [`../echo/spec.md`](../echo/spec.md) — the reserved screen
  row, the three tokens, and the idle label
- [`../safe-cells/spec.md`](../safe-cells/spec.md) — controls
  paint as one space after clipping
- [`../minibuffer/spec.md`](../minibuffer/spec.md) — the prompt
  owns the echo row and the cursor while it is active
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `AloemacsModeLine`, the window rectangles, and session
  `frame`
- GNU Emacs's mode line, the status line in
  `/home/dharmatech/src/e`, and Legmacs's mode line in
  `/home/dharmatech/src/legmacs` — seam catalogs. GNU Emacs and
  `e` supply the whole-bar background, lighter on the current
  window, with the mode line as the horizontal edge. Legmacs
  supplies a per-window bar. Its continuous vertical rule and
  its coloring of only the buffer name and the mode name supply
  no requirement

`SPEC.md` remains language law. This series does not amend it.
The accepted windows spec remains the authority for Right
splits, the tree, locks, and commands. The accepted mode-line
spec remains the authority for the visible cells of the name
row. This charter is the authority for the bar and for the
absence of the Below rule row. After the human accepts
`spec.md`, that file is the design authority for the checkpoint
manager and the implementers.

## 7. Non-goals

- A line-drawing character, or any replacement of `|`
- Faces, span attributes, syntax highlighting, or a language mode
- A mode name, a dirty mark, a position readout, a percentage,
  a lock mark, a window number, or a pending-key badge
- Recoloring buffer text, the echo row, the prompt, or a
  completion list
- A second screen-level row, or a blank separator in place of
  the removed rule
- A new key, a new command, or a new Term method
- Changing Right allocation, the three-column minimum, lock, or
  the windows echo rule
- A stored format string or a user-arranged mode line
- Implementing idle echo, completion, or completion page
- A second editor, point, or origin per view
- A kernel message, a `SPEC.md` row, a `Text` method, or a
  change to `AloemacsEditor`'s fields
- A runner change, or an edit to `host/racket/aloemacs-run.rkt`
- Mirror, mutation, or delegation
- A `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-window-bars`.
- Checkpoint 000 is spoken **aloemacs-window-bars 000** and
  filed as `checkpoints/000-one-view-bar.md`. Checkpoint 001 is
  spoken **aloemacs-window-bars 001** and filed as
  `checkpoints/001-split-bars.md`. Numbers are three digits,
  start at 000, and are never renumbered. The slug is lowercase
  words separated by hyphens. The checkpoint manager writes one
  checkpoint, then stops.
- Intended order: §4.8. 000 first. A later number exists only
  for the size split §4.8 allows.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md` and
  later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
