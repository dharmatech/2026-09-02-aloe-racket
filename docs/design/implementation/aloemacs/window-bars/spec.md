# aloemacs window-bars specification

**Status: Accepted for checkpoint planning.** Written by the designer
conversation from [`charter.md`](charter.md). The charter writer reviewed
it, two sentences were corrected, and the human accepted it. This file
is the complete design input for the **aloemacs-window-bars** checkpoint
manager and implementers. They do not need the charter or the design
conversation. This is application design;
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law, and
[`docs/workflow.md`](../../../../workflow.md) governs roles and review
boundaries.

A tall window's mode line is that window's horizontal edge. It is
painted as a **bar**: the accepted name row, on a background distinct
from the buffer text. The bar is lighter on the selected window and
darker on every other window. A Below split spends no row on a `-`
rule. A Right split keeps its one `|` column. A leaf shorter than two
rows stays all text, with no bar and no substitute rule.

Decisions this spec makes, in one place:

| Question | Decision | Section |
|---|---|---|
| Sequences | Lighter `ESC[38;5;16;48;5;250m`, darker `ESC[38;5;252;48;5;239m`, restore `ESC[0m` right after the last visible cell | §3.1, §3.3 |
| Below division | `earlier = (n + 1) / 2`, `later = n - earlier`, no divider row | §4.1 |
| Below minimum | A below split needs at least four rows, so each child is at least two | §4.2 |
| Selector | `(line bar row selected?) -> String` on `AloemacsModeLine` | §3.2 |

## 1. Series, predecessors, and authority

The series identity is **aloemacs-window-bars**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code stays in
`examples/aloemacs/`. Tests stay in `tests/aloemacs/`. This folder holds
the specification and later checkpoint documents, never the program.

There are two intended checkpoints, in this order:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-window-bars 000** | `checkpoints/000-one-view-bar.md` | The `bar` send. The one-view and too-small-fallback name row is the lighter bar. Text rows, completion rows, and the echo row are outside it. Short one-view frames and direct editor frames keep their bytes. Split frames keep today's bytes, rule row included. |
| **aloemacs-window-bars 001** | `checkpoints/001-split-bars.md` | Below spends no rule row, and a below split needs four rows. Each tall split leaf ends in a bar: lighter on the selected view, darker on the others. No `-` rule and no `+`. Right rectangles and `|` stay. Fit, cursor, echo, and fallback follow §5. |

Numbers are three digits, start at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. After the human accepts this
spec, the manager writes **000 only**, then stops. Human review of 000's
implementation precedes issuing 001. Do not issue both together. Do not
take a global number or add a `CHECKPOINTS.md` entry.

000 changes two places in one product file and migrates one-view
goldens through each test file's existing one-view helper. 001 changes
Below geometry and split composition and migrates split goldens. If the
manager's inventory shows that 001 cannot fit one implementer
conversation **because of the inactive bar**, and only then, split it
in this order: 001 is the Below edge (all of §4, §7 with every tall
split leaf painted with the lighter bar), then 002,
`checkpoints/002-inactive-bars.md`, paints every unselected bar darker.
That added number introduces no other feature. If the size problem is
the geometry or golden migration itself, return the finding for a spec
revision instead. No checkpoint may leave a split frame whose accepted
look is a colored bar with a dash rule under it.

### 1.1 Predecessors

| Series | State this spec reads |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 implemented; final human review open. The geometry law for Right splits, the tree, locks, commands, selected fit, and composition. |
| [`../mode-line/`](../mode-line/) | aloemacs-mode-line 000–001 implemented; final human review open. A leaf of height at least two paints `(buffer name)`, a space when it fits, then `-` fill, on its last row. |
| [`../echo/`](../echo/) | The last screen row is the echo row when `rows >= 2`. |
| [`../safe-cells/`](../safe-cells/) | A control paints as one space after clipping. |

This series reads those accepted specs and does not wait for their open
reviews. It does not edit their specs, charters, or checkpoints. A
defect in one of them that blocks a bar stops this series; report it.
Do not patch the earlier series from here.

### 1.2 Neighbors already in the tree

The tree also implements idle echo (aloemacs-idle-echo 000), completion
(aloemacs-completion 000–001), and completion page
(aloemacs-completion-page 000), whatever the parent map's status column
says. They are not predecessors. This series does not wait for them and
does not edit their documents. Their behavior is frame input that this
series preserves byte for byte:

- Session `root-rect(columns, rows)` is `(0, 0, columns, rows)` when
  `rows < 2`, otherwise `(0, 0, columns, rows - 1 - k)`, where `k` is
  `completion-row-count(rows)`. The windows' own `text-rect`, used by
  split and delete with the remembered size, is `rows - 1`.
- `completion-frame` paints `k` addressed list rows below the root and
  above the echo row.
- `echo-row(columns, leaf-rows)` is the one echo payload: the prompt,
  then active search, then `saved:` / `failed:`, then the idle payload.
  The idle payload is empty when `leaf-rows >= 2` and is the path or
  `untitled` otherwise. `leaf-rows` is the root height for a one-view or
  fallback frame and the selected rectangle height for a split frame.

If the tree differs when a checkpoint is issued, the checkpoint names
the composer it finds. The bar rules below do not change.

### 1.3 Authority

- [`../windows/spec.md`](../windows/spec.md): buffer and view ownership,
  IDs, Right allocation and its `|` column, locks, selection, selected
  fit, the too-small-tree fallback, commands, and echo rules. This spec
  supersedes only Below's reserved row, the `-` rule, the `+` junction,
  the below split minimum, and the divider/junction composition.
- [`../mode-line/spec.md`](../mode-line/spec.md): the visible spelling
  of the name row, the short leaf, derived display, and the leaf text
  height. This spec supersedes only its refusal of reverse video and of
  a selected-window style, for this bar only, and its statement that
  split rows compose through the divider and junction algorithms.
- [`../echo/spec.md`](../echo/spec.md),
  [`../safe-cells/spec.md`](../safe-cells/spec.md), and
  [`../minibuffer/spec.md`](../minibuffer/spec.md): the reserved echo
  row, the three tokens, safe cells, and the prompt's ownership of the
  echo row and cursor.
- [`file.aloe`](../../../../../examples/aloemacs/file.aloe) and
  [`editor.aloe`](../../../../../examples/aloemacs/editor.aloe): current
  code. `AloemacsModeLine`, `AloemacsWindowRect`, the tree's
  `frame-rows`, and session `frame`, `single-frame`, and `multi-frame`.
- Seam catalogs, with no requirement beyond what this spec states: GNU
  Emacs's `mode-line` and `mode-line-inactive` faces; the status bar in
  `/home/dharmatech/src/e/lib/head/paint.sls`; Legmacs's mode line in
  `/home/dharmatech/src/legmacs`. They supply a whole-row background,
  lighter on the current window, with the mode line as the horizontal
  edge. Their reverse video, segment colors, mode names, readouts,
  line-drawing glyphs, and continuous vertical rules supply nothing.

Language law wins on sends, types, and evaluation. The windows spec
wins on the tree, Right splits, locks, and commands. The mode-line spec
wins on the visible cells of the name row. This spec wins on the bar,
on Below division, and on the absence of the Below rule row. Neighbor
documents that describe a Below rule row or a `+` junction are
historical on that point. Do not amend them.

## 2. Product, host, and file boundary

The implementation is checked Aloe. Racket tests use the existing
checked driver, `rackunit`, counted Fs doubles, and scripted Term
doubles, without a physical TTY. Keep `file.aloe`'s two loads. No
dependency, host capability, module, or build step is added.

Both checkpoints edit **`examples/aloemacs/file.aloe` only** for product
changes. 000 adds `AloemacsModeLine.bar` and wraps the one-view mode
row. 001 changes Below division, the below split minimum, the tree's
split composition, and the selected argument that composition needs.

| Part | New focused test |
|---|---|
| 000 | `tests/aloemacs/window-bars-one-view.rkt` |
| 001 | `tests/aloemacs/window-bars-split.rkt` |

Existing files under `tests/aloemacs/` may receive the expectation and
fixture updates in §6.3 and §7.3, for the owning part only. Each
checkpoint names its exact subset after searching. This is not
permission for unrelated test cleanup.

Leave untouched: `examples/aloemacs/editor.aloe`,
`examples/aloemacs/main.aloe`, `host/racket/aloemacs-run.rkt`,
`host/racket/term.rkt`, `lib/`, the language implementation, `SPEC.md`,
`CHECKPOINTS.md`, and every predecessor and neighbor document.

Shapes stay exact. `AloemacsEditor` keeps its eight fields and gains no
method. Direct editor `frame`, `frame-ansi`, `frame-rows`, `safe-cells`,
`ensure-visible`, and page motion keep their bytes and results. The
session keeps its fourteen fields; the buffer its three; the view its
five; the rectangle its four; the window configuration its four.
`AloemacsModeLine` keeps `(fields)` and its declared position. The class
list and order in `file.aloe` stay exact. No class, constructor, command,
key, keymap entry, Term method, or runner change is added. The runner
still fits, then frames, then writes one String per drawn iteration.

Non-goals: a line-drawing character or any replacement of `|`; faces,
span attributes, syntax highlighting, or language modes; recoloring
buffer text, the echo row, the prompt, or a completion list; a mode
name, dirty mark, position readout, percentage, lock mark, window
number, or pending-key badge; a second screen-level row, or a blank
separator in place of the removed rule; terminal color detection or a
`TERM` query; a stored format string or user-arranged mode line;
changing Right allocation, the three-column minimum, lock policy, or the
echo rules; a second editor, point, or origin per view; a kernel
message, `SPEC.md` row, `Text` method, or List index; Mirror, mutation,
inheritance, delegation, macros, or a new special form. Evaluation is
send. Function objects run only through `call`.

## 3. The bar

### 3.1 Sequences

The bar uses three ANSI strings. ESC is U+001B, written `\u001b` in Aloe
and `\e` in Racket test strings.

| Name | Bytes | Meaning |
|---|---|---|
| LIGHT | `ESC[38;5;16;48;5;250m` | black (palette 16) on grey 250 (`#bcbcbc`) |
| DARK | `ESC[38;5;252;48;5;239m` | grey 252 (`#d0d0d0`) on grey 239 (`#4e4e4e`) |
| PLAIN | `ESC[0m` | reset to the terminal's default attributes |

These are the nearest 256-color indices to GNU Emacs's `mode-line`
(grey75 background, black foreground) and its dark-background
`mode-line-inactive` (grey30 background, grey80 foreground). Explicit
indices keep LIGHT lighter than DARK on dark and light terminal schemes.
Reverse video, as in `e`, would make the selected bar dark on a light
scheme, so it is not used. Both sequences set the foreground too, so the
name stays readable on either bar. Buffer text keeps the terminal's
default foreground and background, and both bars differ from ordinary
dark and light defaults. The frame never asks the terminal about color.
A terminal without 256 colors is out of scope.

These strings are frame chrome, like the existing `ESC[2J` and cursor
addresses. They are not cells, not a Term method, not a host capability,
and not a face. They occupy no cell. They are ASCII bytes. The visible
mode line stays ASCII; no line-drawing character is introduced.

### 3.2 The selector

Add one send to `AloemacsModeLine`:

```text
(line bar row selected?) -> String
line      : AloemacsModeLine
row       : String      ; a visible row: name row after safe cells
selected? : Bool
```

```text
bar(row, selected?) = ""                      when row.len = 0
                    = LIGHT ++ row ++ PLAIN   when selected?
                    = DARK  ++ row ++ PLAIN   otherwise
```

It is a pure display send. It does not clip, pad, inspect, or apply safe
cells to `row`. It performs no effect. No instance is stored on the
session, buffer, editor, or view. `AloemacsModeLine` may gain private
zero-argument helpers for the three strings. No other class gains a bar
method. `row` and `fill` keep their results.

Every bar is painted in this order:

```text
raw   = (AloemacsModeLine new) row name width     ; accepted spelling
shown = editor safe-cells raw                    ; control -> one space
paint = (AloemacsModeLine new) bar shown selected?
```

Safe cells sees only the name row, never the sequences. A name holding
ESC cannot open, close, or recolor a bar.

| Name | Width | `selected?` | Painted (quotes delimit visible cells) |
|---|---|---|---|
| `"/a"` | 4 | `#t` | LIGHT `"/a -"` PLAIN |
| `"/a"` | 4 | `#f` | DARK `"/a -"` PLAIN |
| `"untitled"` | 12 | `#t` | LIGHT `"untitled ---"` PLAIN |
| `"untitled"` | 12 | `#f` | DARK `"untitled ---"` PLAIN |
| `"untitled"` | 1 | `#t` | LIGHT `"u"` PLAIN |
| `"untitled"` | 1 | `#f` | DARK `"u"` PLAIN |
| `"untitled"` | 0 | either | `""`, not a painted row |
| `"a\u001b[31m"` | 8 | `#t` | LIGHT `"a [31m -"` PLAIN |

In Racket test spelling, the first row is
`"\e[38;5;16;48;5;250m/a -\e[0m"` and the second is
`"\e[38;5;252;48;5;239m/a -\e[0m"`.

The **visible row** of a painted row is that row with every LIGHT, DARK,
and PLAIN removed. A bar's visible row is exactly the accepted spelling,
exactly `width` characters. Every composed root row's visible width is
the root width.

### 3.3 Where PLAIN sits

PLAIN immediately follows the bar's last visible cell, inside the same
row String. Nothing is emitted while a bar is open: no CRLF, no `|`
divider, no next-leaf text, no completion address, no echo address, and
no cursor address.

- **One view.** `ESC[h;1H` LIGHT name-row PLAIN, then any completion
  rows, then `ESC[rows;1H` and the echo payload.
- **Split, bar on the root's last row.** The row ends in PLAIN, or in
  PLAIN `|` and the right neighbor's cells. The frame continues with
  completion rows or `ESC[rows;1H`. There is no CRLF after the root's
  last row.
- **Split, buffer text of the leaf below.** PLAIN, then `\r\n`, then
  that text row.
- **Right neighbor.** PLAIN, then `|`. The divider cell is painted in
  default attributes, never inside a bar.

So every frame ends in the terminal's default attributes. The next
frame's `ESC[2J`, which many terminals erase with the current
background, and every CRLF run in default colors.

### 3.4 Which bar is lighter

`selected?` is true exactly when the leaf's view ID equals the window
configuration's `selected` ID. It does not mean the view under the
cursor while a prompt owns the echo row, or the view whose buffer has
point. Several views of one buffer paint one LIGHT bar, on the selected
view, and DARK bars on the others. The one-view frame and the
too-small-tree fallback paint their single bar LIGHT. An active prompt,
search, or completion list changes no bar.

## 4. Geometry

### 4.1 Below division

Right is unchanged. For an extent `n`, `divider = min(1, n)`,
`available = n - divider`, `earlier = (available + 1) / 2`,
`later = available - earlier`, the right child's x is
`x + earlier + divider`, and `|` sits at `x + earlier`.

Below reserves no row. For every nonnegative extent `n`:

```text
earlier = (n + 1) / 2          [integer division]
later   = n - earlier
top     = (x, y,           columns, earlier)
bottom  = (x, y + earlier, columns, later)
```

The top gets the odd row. Both children keep the parent's x and width.

| `n` | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| earlier | 0 | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 | 5 |
| later | 0 | 0 | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 |

A nominal zero axis comes from `n = 0` (both children) and `n = 1` (the
bottom). A Below lays out positively when `n >= 2`. The global fallback
rule is unchanged: when any nominal leaf has a zero axis, fit and paint
the selected buffer in the whole root through the one-view composer,
with no dividers, even when the selected leaf alone is positive.

Today a Below at `n` gives `floor(n / 2)` rows, a rule row, then
`n - 1 - floor(n / 2)` rows. Each child now has at least as many rows as
before. The old rule row joins the top when `n` is odd and the bottom
when `n` is even.

### 4.2 Below split minimum

A below split is allowed when a positive size is remembered, the
selected view is unlocked, its nominal rectangle is positive, and that
rectangle has **at least four rows**. Both children then have at least
two rows, so each has a bar. A right split still needs at least three
columns. Refusal outcomes are unchanged: a refused split stores
`"failed"` when neither a prompt nor a search is active, and leaves the
whole session unchanged while either is active.

A later terminal shrink can still leave a leaf one row tall, at Below
extents two and three. That leaf is all text, with no bar and no
substitute rule, directly above or below its neighbor. A shrink that
reaches a zero axis uses the fallback.

### 4.3 Example

A 9-by-5 text rectangle (terminal 9 by 6, no list) split right gives
`(0,0,4,5)` and `(5,0,4,5)`, with `|` at x=4. Splitting its left view
below, at `n = 5`, gives `(0,0,4,3)` and `(0,3,4,2)`. The right view
stays `(5,0,4,5)` and the divider stays at x=4. Visit order is
original-left-top, new-left-bottom, original-right. Today the left
children are `(0,0,4,2)` and `(0,3,4,2)`, with the rule at y=2.

The command refuses a below split of the lower-left view `(0,3,4,2)`,
because two rows are fewer than four. A right split of that view is
allowed. A one-view session at terminal 9 by 4 (text height three) also
refuses `C-x 2`; today it succeeds with one row, a rule, and one row. At
terminal 9 by 5 (text height four) it gives `(0,0,9,2)` and `(0,2,9,2)`.

### 4.4 What stays, and what goes

A new split changes only the selected leaf's rectangle; ancestors and
siblings stay exact. Lock comparisons still compare all four nominal
coordinates, now under this division; there is no new lock rule. Delete
still recomputes the promoted sibling in the old parent's rectangle,
under this division. The root rectangle, the echo row, and the
completion rows are unchanged. Rectangles are still derived, never
stored. `AloemacsWindowRect.text-rows` is unchanged.

There is no horizontal divider, no `+` junction, and no one-cell
divider extension. In 001, remove the tree's `horizontal-divider?`,
`vertical-divider?`, and `below-divider`, and the rectangle's
`divider-row` and `divider-column`, which nothing else uses. The tree's
`right-rows` paints `|` on every row and drops the parameters it no
longer reads.

## 5. Fit, cursor, echo, and state

Fit keeps its code path. Session `ensure-visible(columns, rows)` takes
`fit-rect`: the selected leaf, or the whole root for one view or the
fallback. It fits the current editor at that rectangle's width and
`text-rows`, mirrors the fitted origin onto the selected view, and
remembers the full terminal size. Unselected origins stay until that
view is selected and fitted. Page Up and Page Down use the remembered
text height. A successful split still fits once, at the selected child's
text height; the fresh child keeps the pre-split origin. Other commands
keep their fit timing. Fit and page results change only because Below
leaves change height.

The selected cursor formula is unchanged:

```text
cursor-row    = selected.y + point.line   - editor.scroll-row + 1
cursor-column = selected.x + point.column - editor.scroll-col + 1
```

After fit the cursor is in the selected leaf's text rows, never on a
bar. With an active prompt and `rows >= 2`, the cursor is on the echo
row at `prompt.screen-column(columns)`. The selected bar stays LIGHT
while the prompt owns the cursor.

Echo is unchanged: `echo-row(columns, leaf-rows)` as in §1.2. A selected
Below leaf that grows from one row to two now gets the empty idle
payload. That is geometry, not an echo change. The stored tokens stay
`""`, `"saved"`, and `"failed"`.

The bar is derived when the frame is built. No field, stored bar,
stored flag, or name update is added. Frame stays pure: it never fits,
remembers a size, changes point, installs a focus or origin, or writes
a token. Idle keys, search, quit, visit, save, switch, kill-buffer,
find-file, save-as, select-buffer, both splits, delete, other-window,
and lock keep their text, point, quit flag, mark, kill ring, undo
history, search flags, echo token, pending map, prompt, submission,
buffer zipper, window tree, locks, and file effects. The only
command-visible changes are §4's Below rectangles and §4.2's below
minimum.

## 6. Layer 000 — one-view bar

### 6.1 Product

Add `bar` (§3.2). In session `single-frame`, where the root is at least
two rows tall, paint the mode row through `bar` with `selected?` true.
Every other byte stays. With `h = root.rows` and `t = root.text-rows`:

```text
editor.frame(columns, t)
ESC[?25l
ESC[h;1H LIGHT shown-mode PLAIN        only when h >= 2
completion rows                        unchanged; only when painted
ESC[rows;1H shown-echo
ESC[final-row;final-columnH ESC[?25h
```

The spaces and line breaks above separate pieces and add no bytes. At
`rows < 2`, `single-frame` keeps today's complete body. At `rows >= 2`
with `h < 2`, it keeps today's bytes and has no sequence. The
too-small-tree fallback composes through `single-frame`, so its bar is
LIGHT in 000.

`multi-frame` and the tree's composition stay exactly as they are in
000. Split leaves keep their plain mode rows and the `-` / `+` rule rows.
Below division and the split minimum stay. 000 never paints a colored
bar above a dash rule: the fallback draws no dividers.

### 6.2 Examples

An empty untitled buffer at 12 columns and 4 terminal rows, idle:

```text
today: "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1Huntitled ---\e[4;1H\e[1;1H\e[?25h"
000:   "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[1;1H\e[?25h"
```

Untitled text `zero\none\ntwo\nthree`, point at line 3, column 0,
fitted at 12 by 4 (origin row 2):

```text
000:   "\e[?25l\e[2J\e[Htwo\r\nthree\e[2;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[2;1H\e[?25h"
```

The empty buffer at width 1, 4 rows:

```text
000:   "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250mu\e[0m\e[4;1H\e[1;1H\e[?25h"
```

Short frames keep today's bytes. The empty buffer at 12 by 2 is
`"\e[?25l\e[2J\e[H\e[1;1H\e[?25h\e[?25l\e[2;1Huntitled\e[1;1H\e[?25h"`,
and at 12 by 1 it is `"\e[?25l\e[2J\e[H\e[1;1H\e[?25h"`.

### 6.3 Migration

Search `tests/aloemacs/` for one-view and fallback frames that contain
a mode row. Most files build them through a local one-view helper,
usually beside a `mode-row` function. Likely sites are
`buffer-session.rkt`, `buffer-value.rkt`, `echo-runner.rkt`,
`echo-session.rkt`, `keymap-prefix.rkt`, `keymap-runner.rkt`,
`minibuffer-session.rkt`, `minibuffer-value.rkt`, the three
`prompt-commands-*.rkt` files, `runner-check.rkt`, `safe-cells.rkt`,
`search-session.rkt`, `viewport-runner.rkt`, `completion-session.rkt`,
`windows-state-foundation.rkt`, `mode-line-one-view.rkt`,
`idle-echo.rkt`, `completion-frame.rkt`, `completion-page-frame.rkt`,
`completion-page-session.rkt`, and the fallback cases in `windows-*.rkt`
and `mode-line-split-views.rkt`. Search again; this list is not
exhaustive.

Wrap only the one-view or fallback mode row, in LIGHT and PLAIN spelled
as test-local literals. Never build an expectation by calling `bar`,
`row`, or a session composer. Keep every split-frame expectation, Below
rectangle, fit result, and refusal byte for byte. Keep whole-frame
assertions; do not replace them with substring checks. No fixture, fit,
or geometry change belongs to 000. If one seems necessary, stop and
report it.

### 6.4 Focused proof

Write `tests/aloemacs/window-bars-one-view.rkt` first. Without a TTY,
prove:

1. `bar` is typed `String`. Wrong arity, wrong argument types (an Int
   row, a String `selected?`), and a wrong receiver are rejected by
   checking. A fresh checked load needs no Fs or Term and has no
   effect. The class list, `AloemacsModeLine`'s `(fields)`, and every
   field inventory are unchanged.
2. Every §3.2 example, both selections at width 1 and with fill, the
   empty row, an empty name, and controls (ESC followed by `[31m`, tab,
   CR, LF, DEL) inside and beyond the clip. Assert the exact painted
   String and its visible row and width independently.
3. Complete one-view frames at width 1, a narrow width, and a wide
   width; empty, text, and blank-row buffers; untitled and bound names;
   nonzero vertical and horizontal origins; saved, failed, idle,
   search, and prompt echo states; and a painted completion list. Each
   has exactly one LIGHT, one PLAIN, and no DARK. List rows and the echo
   address follow PLAIN. The editor frame prefix is exact.
4. Terminal heights one and two, and a root shortened below two rows by
   a completion list, keep today's complete bytes with no sequence.
   Direct editor frames are unchanged.
5. A too-small tree at root height at least two frames exactly as the
   one-view composer for the selected buffer, with LIGHT. At root height
   one it keeps today's bytes. Growth restores today's split frame,
   still with its rule row and with no sequence.
6. A split frame is byte-identical to today. An active prompt keeps the
   LIGHT bar and puts the cursor on the echo row.
7. Frame twice and at another size: the session is unchanged and there
   is no Fs or Term effect. A scripted runner double fits, frames, and
   writes once before each read, observes resize from tall to short and
   back, and quits, with exact effect counts.

Stop with this file and the full aloemacs suite green.

## 7. Layer 001 — split bars

### 7.1 Product

- `AloemacsWindowRect` `top` and `bottom` follow §4.1. `left` and
  `right` are unchanged.
- The window configuration's below split check needs at least four rows
  (§4.2). The right check is unchanged.
- The tree's display send gains the selected view ID:
  `frame-rows(buffers : AloemacsBuffers, rect : AloemacsWindowRect,
  selected : Int) -> (List String)`. Session `multi-frame` passes
  `(windows selected)`.
  - **Leaf, buffer lookup miss** (raw dangling ID): `h` blank rows of
    width `w`, with no name and no bar.
  - **Leaf, `h >= 2`**: `h - 1` text rows from that buffer editor's
    `frame-rows(w, h - 1, view.scroll-row, view.scroll-col)`, each
    padded to `w`, then `bar(shown, view.id = selected)`.
  - **Leaf, `h < 2`**: today's all-text rows.
  - **Below**: the top's rows, then the bottom's rows. No row between.
  - **Right**: each row is the left row, `|`, then the right row, on
    every row of the rectangle.
- Remove the queries and helpers named in §4.4.
- The multi-view envelope is unchanged:

```text
ESC[?25l ESC[2J ESC[H joined-root-rows completion-rows
[ESC[rows;1H shown-echo, only when rows >= 2]
ESC[final-row;final-columnH ESC[?25h
```

Each leaf returns exactly `h` rows of visible width `w`. The joined root
has exactly `root.rows` rows of visible width `columns`, joined with
CRLF and no trailing CRLF. There is one clear, one hide/show pair, one
final cursor, and one Term write. Find buffers through the existing
temporary focused collection; never install that focus. Keep bounded
`focus-at` / `next-lines` traversal. Do not clamp an inactive origin or
build a temporary editor.

### 7.2 Examples

**Two stacked views of one buffer.** Terminal 8 by 6, root 8 by 5. One
buffer, ID 0, path `/a`, lines `one`, `two`, `three`, `four`. Tree
`Below(Leaf view 0, Leaf view 1)`, both showing buffer 0. View 0 is
selected at origin `(0,0)` with point `(0,0)`; view 1 is at origin
`(2,0)`. Rectangles are `(0,0,8,3)` and `(0,3,8,2)`. The idle echo
payload is empty because the selected leaf is three rows tall.

```text
"\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a -----\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a -----\e[0m\e[6;1H\e[1;1H\e[?25h"
```

Today the same session paints `one`, `/a -----`, `--------`, `three`,
`/a -----`: the top has one text row, and a rule row separates them.

**Mixed nesting.** Terminal 9 by 6, root 9 by 5. Tree
`Right(Below(view 0, view 1), view 2)`. Buffer A, ID 0, path `/a`, lines
`abcdef`, `ghijkl`, `mnopqr`, `stuvwx`, `yz0123`. Buffer B, ID 1, path
`/b`, lines `ABCDE`, `FGHIJ`, `KLMNO`, `PQRST`, `UVWXY`. View 0 shows A at
origin `(0,0)`; view 1 shows A at `(3,1)`; view 2 shows B at `(1,2)`.
View 1 is selected; A's editor has origin `(3,1)` and point `(3,2)`.
Rectangles are `(0,0,4,3)`, `(0,3,4,2)`, and `(5,0,4,5)`. Visible rows:

```text
"abcd|HIJ "
"ghij|MNO "
"/a -|RST "      view 0's bar, DARK
"tuvw|WXY "
"/a -|/b -"      view 1's bar LIGHT, view 2's bar DARK
```

The complete frame has the cursor at `(4,2)`. The idle echo payload is
empty because the selected leaf, view 1, is two rows tall:

```text
"\e[?25l\e[2J\e[Habcd|HIJ \r\nghij|MNO \r\n\e[38;5;252;48;5;239m/a -\e[0m|RST \r\ntuvw|WXY \r\n\e[38;5;16;48;5;250m/a -\e[0m|\e[38;5;252;48;5;239m/b -\e[0m\e[6;1H\e[4;2H\e[?25h"
```

Selecting view 0 instead makes its bar LIGHT and view 1's DARK; the
visible rows stay.

### 7.3 Migration

Search `tests/aloemacs/` for Below trees, below splits (`split-below`,
`SplitBelow`, the `"2"` chord), rule rows, `+` junctions, rectangle
tables, and direct `frame-rows` sends. Likely sites are
`windows-layout-and-rendering.rkt`, `windows-split.rkt`,
`windows-delete-and-other.rkt`, `windows-lock.rkt`,
`mode-line-split-views.rkt`, `idle-echo.rkt`, `completion-frame.rkt`,
`completion-page-frame.rkt`, and `completion-page-session.rkt`. Search
again.

- Rectangle tables, `rect-for`, `positive-layout?` (a Below is now
  positive at extent two), lock comparisons, and delete promotion take
  §4.1's division.
- A below split that succeeded at extent three now refuses. Give that
  scenario more rows to keep its success, and prove the refusal at three
  separately.
- A fixture whose purpose was a zero-axis fallback through a Below at
  extent two now lays out positively, as one row and one row. Extent
  three was already positive, and extent one is still a fallback.
  Rebuild such a fixture so the same fallback is still proved, for
  example with a Below at extent one or a Right at extent two. Keep its
  assertions' intent.
- Split frames lose their rule rows. Each tall split leaf's mode row is
  wrapped in LIGHT or DARK. Recompute text rows, fitted origins, page
  results, cursors, and idle echo payloads for the new heights, by hand.
- Direct tree `frame-rows` sends gain the selected ID.

Expected Strings use test-local literals for LIGHT, DARK, and PLAIN and
independently computed rows. Never build one with `bar`, `frame-rows`,
or a composer under test. 001 may change 000's focused test only where
it asserts today's split frames, replacing that with the completed
contract.

### 7.4 Focused proof

Write `tests/aloemacs/window-bars-split.rkt` first. Without a TTY,
prove:

1. §4.1's table for `n` from 0 to 9 through `rect-for` and
   `positive-layout?`, Right's unchanged table, §4.3's rectangles, and
   unchanged ancestors and siblings after a new split.
2. Below split at extent three refuses and at four succeeds with two
   rows each; odd and even larger extents; right split at three
   succeeds. Unfitted and locked refusals are unchanged. Echo outcomes
   for each initial token, with and without an active prompt or search.
   Delete promotion and lock comparisons under the new division,
   including a locked descendant that would move and one that would not.
3. Both §7.2 examples byte for byte, both orientations, deeper mixed
   nesting, two views of one buffer at distinct origins, identical names
   on distinct buffer IDs, width-one leaves, long names, safe controls,
   and a valid inactive origin beyond EOF that still paints its bar. A
   raw dangling buffer ID paints blank rows and no bar. Assert row count
   and visible width. No row is made only of `-` and `+`, and no `+`
   appears outside buffer text. `|` appears on every row of every Right
   rectangle, including beside bars, always after PLAIN. A name holding
   `-`, `|`, or `+` stays inside its bar.
4. Exactly one LIGHT per frame when the selected leaf is tall, none when
   it is short, and one DARK per other tall leaf. Short leaves next to
   tall leaves paint only text. An all-short positive layout has no
   sequence.
5. Other-window and delete move the LIGHT bar. An active prompt keeps
   it on the selected view with the cursor on the echo row. Search keeps
   the text cursor. A painted completion list sits below the root, after
   the last PLAIN.
6. Selected fit at the new text heights: minimal and idempotent, page
   motion at text heights one, two, and three, post-split fit, and
   unchanged unselected origins. Frame is pure.
7. Shrink to a zero axis paints the one-view frame with one LIGHT bar,
   and no sequence at root height one. Growth restores the split bars.
   The tree, selection, locks, and inactive origins persist.
8. A scripted Term drives split below, split right, other-window, an
   edit, a prompt, save, delete, resize, and quit through the unchanged
   runner contract, with exact read, write, and Fs counts.

Stop with both focused files and the full aloemacs suite green.

## 8. Verification, hand check, and acceptance

Each implementer writes focused tests first, sees them fail, implements
one slice, and verifies from the project root.

For **aloemacs-window-bars 000**:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-bars-one-view.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
git diff --check
```

For **aloemacs-window-bars 001**:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-bars-one-view.rkt tests/aloemacs/window-bars-split.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
git diff --check
```

The aloemacs suite is the regression bar. Do not commit `compiled/`.
Product edits are `.aloe` only and need no rebuild before launch.

**Hand check.** After 001, the human reviewer runs this on a real TTY
with 256 colors, at least 80 by 24. The implementer does not need a TTY.

```sh
cp SPEC.md /tmp/window-bars.txt
racket host/racket/aloemacs-run.rkt /tmp/window-bars.txt
```

Type `C-x 2`, `C-x 3`, `C-x o`, `C-x o`, `C-x 3`. There are four windows
on one file, and the lower-left window is selected. Its whole mode line
is the lighter bar. The other three mode lines are the darker bar. No
row of dashes sits under the upper mode lines; the next row is buffer
text. The vertical stroke is `|` on every row, including beside the
bars. The echo row is not colored. `C-x o` moves the lighter bar to the
lower right, then to the upper left. `C-x C-f` puts the cursor on the
echo row while the upper-left bar stays lighter. Escape cancels the
prompt; Escape again quits. Nothing is written.

The completed series is accepted when all of these are true:

1. Every painted mode line's visible cells are the accepted spelling:
   the buffer name, a space when it fits, then `-` fill, clipped by
   prefix, then safe cells. Its visible width is the leaf width.
2. In a frame of two or more stacked windows, no row between an upper
   leaf and the leaf below it is a rule of `-` and `+`. When both leaves
   are at least two rows tall, the upper leaf's last row is its bar and
   the next row is the lower leaf's first text row.
3. Every tall leaf's mode line is a bar. The selected view's bar is
   LIGHT; every other bar is DARK, including other views of the same
   buffer. A leaf shorter than two rows has no bar and no substitute
   rule.
4. Each bar ends in PLAIN before any CRLF, divider, text, list row, echo
   address, or cursor. The cursor is in the text rows, or on the echo
   row while a prompt is active, never on a bar.
5. A Right split reserves one column and paints `|` on every row of its
   rectangle. Right rectangles are unchanged. No vertical glyph and no
   `+` are introduced.
6. Below splits spend no row and need four rows. Fit uses the selected
   leaf's text height. Unselected origins stay until fitted. All other
   state transitions and file effects are unchanged.
7. Short one-view frames and direct editor frames keep their bytes. The
   fallback paints one LIGHT bar. Frame is pure.
8. Both focused proofs and `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs`
   pass without a TTY, with product changes only in `file.aloe`, and
   the hand check looks as described.

This spec is accepted. The checkpoint manager writes
**aloemacs-window-bars 000 only**, then stops. If you have been told to
read this file as the manager assignment, it is the whole assignment.
Do not write later checkpoints in advance.
