# aloemacs-window-pictures 000 — Reuse unchanged leaf rows

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Make a held Down key keep up when several windows show one buffer.

A four-window frame of a thousand-line buffer is rebuilt from scratch
on every key. On the machine measured for this slice, that rebuild
takes about 54 ms while the cursor is still on the first screen and
about 136 ms once the selected window has moved deep into the file.
The keyboard repeats about every 30 ms. Keys that arrive during a
rebuild stay queued, so the cursor keeps moving after the key is
released. One window stays near 9–14 ms and stops with the key.

Record each leaf's finished rows. On the next frame, reuse those
rows when that leaf's inputs are unchanged. The bytes on screen stay
the same. Add a timing test that fails if the steady multi-window
paint returns to the slow side of the repeat interval.

Do not change List, Text, or `safe-cells`. Do not coalesce keys. Do
not make unselected windows follow the selected window's scroll.

## Why this is the repair

The measurement is
`archive/design-sketches/2026-10-09-aloemacs-multi-window-scroll/profile-investigation-grok.md`.
That file is evidence. This checkpoint is the assignment.

The runner fits the viewport, writes one frame, then reads one key.
`read-next-key` returns one event. Repeats that arrive while the
frame is being built wait in the terminal queue, and each queued Down
is painted on its own.

Two costs show up in `(session frame columns rows)`. Visit has
already indexed the Text, and the terminal write is not in the
number.

At the first screen the shared Text is already near the top. Four
leaves each take their lines, run `safe-cells`, and pad. One narrow
leaf is about 8 ms plus about 2 ms of padding. Four of them, plus
joining, the vertical bars, the echo line, and the cursor address,
are about 54 ms. The mode-line colors are a fraction of a
millisecond. One window does not take this path: `AloemacsEditor.frame`
clips and joins, and it does not pad.

After the selected window moves down, the other leaves still have the
scroll they had at the split. `with-view-buffer` copies `scroll-row`
and `scroll-col` onto the selected view only. Painting another leaf
sends `focus-at` from the cursor back to that old origin. Each step
copies both line lists. From line 800 back to line 0 that walk is
about 27 ms, and three stale leaves account for the climb from 54 ms
to 136 ms.

A Down that has not changed a leaf's text, scroll, rectangle, name,
or selection does not change that leaf's rows. The cursor is a
terminal address written after the body. Reusing the recorded rows
skips both the repeated leaf build and the stale walk. The walk
still happens the first time a leaf is painted at a new origin.

An edit changes the history length, so every leaf of that buffer
misses, including a leaf whose scroll stayed put. Each of those leaves walks `focus-at` from the cursor back to
its own origin. Typing or a held Backspace deep in this file stays
near the measured 136 ms. This slice leaves that cost in place.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs Aloe sends and types. The observable
frame remains whatever `frame` paints today, including the window-bar
bytes already in the working tree.

- Identity is **aloemacs-window-pictures 000**. No predecessor in
  this folder. This is not a windows checkpoint and not a global
  checkpoint.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- `AloemacsView` has `id`, `buffer-id`, `scroll-row`, `scroll-col`,
  and `locked`. It has no recorded rows.
- `AloemacsWindowTree.frame-rows` builds every leaf on every call.
  The leaf sends `AloemacsEditor.frame-rows`, pads with
  `AloemacsWindowRect.pad-row`, and, when the leaf is at least two
  rows tall, appends `AloemacsModeLine.bar`. A missing buffer paints
  blank padded rows. `AloemacsSession.multi-frame` joins those rows.
  `AloemacsSession.single-frame` sends `AloemacsEditor.frame` and
  does not use `frame-rows`.
- `AloemacsSession.ensure-visible` fits the selected editor and
  stores the terminal size. It does not build rows.
- The runner in `host/racket/aloemacs-run.rkt` prepares
  `ensure-visible`, then `(term write (aloemacs-editor frame …))`,
  then `handle-key`. The fit and frame thunks are reused while the
  terminal size is unchanged. Each thunk reads the current
  `aloemacs-editor` binding.
- `visited` replaces the current buffer's editor and keeps that
  buffer's id. `from-edit` and `undo` change `((editor history) len)`.
  Motion, search, and `with-text-and-point` leave that length alone.

## Exact file scope

### May edit

- `examples/aloemacs/file.aloe` — the picture class, the view
  field, leaf-row reuse, `record-pictures`, the skip clear, and
  the `visited` clear
- `examples/aloemacs/main.aloe` — only the initial `AloemacsView`
  constructor, to pass the new picture argument
- `host/racket/aloemacs-run.rkt` — call `record-pictures` after
  `ensure-visible` and before `frame`
- `tests/aloemacs/window-pictures.rkt` (new)
- `tests/aloemacs/viewport-runner.rkt` — the source-order check,
  so `record-pictures` is part of the one loop
- Every other constructor or expected value of `AloemacsView` in
  `tests/aloemacs/` and `tests/parenthetical-construction/`, only
  to pass the new picture argument
- Class-order inventories and exact `AloemacsView` field lists in
  those same trees. Fourteen inventories name `AloemacsModeLine`
  and then `AloemacsView`; insert `AloemacsLeafPicture` immediately
  before `AloemacsView`. Five field lists stop at `locked`; add
  `(picture (Option AloemacsLeafPicture))` as the last field.
  These edits stay in this slice.

### Must leave untouched

- `lib/`, `aloe/`, `SPEC.md`, `CHECKPOINTS.md`, `archive/`
- `AloemacsEditor.frame`, `safe-cells`, `Text`, and List
- Frame golden strings. A failure there means the recorded rows
  disagree with a fresh build. Fix the recording. Do not edit the
  expected bytes.
- `ensure-visible`'s observable result on a session that has never
  recorded pictures
- This folder's `README.md`, the parent aloemacs map, and this
  checkpoint
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion. Do not widen the slice.

## Required behavior

### The picture

Add `AloemacsLeafPicture` before `AloemacsView`:

```aloe
(define-class AloemacsLeafPicture
  (fields
    (buffer-id Int)
    (history-length Int)
    (scroll-row Int)
    (scroll-col Int)
    (columns Int)
    (rows Int)
    (name String)
    (selected Bool)
    (lines (List String)))
  (methods
    (matches? (buffer-id Int) (history-length Int)
              (scroll-row Int) (scroll-col Int)
              (columns Int) (rows Int)
              (name String) (selected Bool) Bool)))
```

`matches?` is true only when every argument equals the stored
field. `lines` is the leaf's finished row list: padded text rows
and, when the leaf is at least two rows tall, the mode-line bar.
It is not a joined string.

Add one last field to `AloemacsView`:

```aloe
(picture (Option AloemacsLeafPicture))
```

Every `(AloemacsView new a b c d e)` outside `archive/` becomes
`(AloemacsView new a b c d e (Option None))`. A named `new*` gains
`(picture (Option None))`. A helper that builds a view adds that
argument once, inside the helper. An expected view value gains it
too. Existing negative arity checks stay failures: omitting the
picture is still a type error, and an `Int` in that position is
still a type error.

Updates that already send `view with` keep the picture. Do not
rebuild those views with `AloemacsView new`. A split may copy a
picture onto the fresh view. A picture recorded for the rectangle
being split misses on the fresh leaf, because that leaf is
smaller, and the next record rebuilds it. A picture recorded for
the half the fresh leaf is about to occupy matches. At 220
columns a right split is 110, one bar column, and 109, so the
fresh leaf is the 109-column side. Closing the selected leaf
keeps the survivor's picture at that 109-column size. The skip
clear drops that picture before a later split can copy it.

### One builder

Move the current leaf arm of `frame-rows` into one method,
`built-rows`, on `AloemacsWindowTree`. It returns the same
`(List String)` that arm returns today: missing buffer, short
leaf, padding, safe cells, and the selected or unselected bar.
`frame-rows` for a leaf calls `built-rows` only when the view has
no matching picture. On a match it returns `(picture lines)`.
`Below`, `Right`, and `right-rows` stay as they are.
`single-frame` does not read pictures.

The match key is:

- the view's `buffer-id`
- `((editor history) len)` for that buffer
- the view's `scroll-row` and `scroll-col`
- the leaf rectangle's `columns` and `rows`
- `(buffer name)`
- whether `(view id)` equals the selected id

A missing buffer does not match and does not get a picture.

### Recording

Add `(record-pictures (columns Int) (rows Int) (AloemacsSession H))`.

It uses `(self root-rect columns rows)`, the same root `frame`
uses. It does not fit the cursor and it does not change scroll,
point, echo, or selection.

When the tree is a single leaf, or the layout at that root is not
positive, do not build rows and do not write a picture. Drop every
stored picture. If every picture is already `(Option None)`,
return `self` unchanged. Otherwise return the session whose
leaves hold `(Option None)`. The one-window path stays
`ensure-visible` plus `AloemacsEditor.frame`, and that painter
does not read pictures.

Otherwise walk the leaves the way `frame-rows` walks them. A leaf
whose picture matches keeps that picture. Any other leaf stores
`(Option Some …)` around the list `built-rows` returns and the key
above. Return the session whose tree holds those pictures.

`visited` clears pictures on every leaf whose `buffer-id` is the
buffer being replaced, including leaves that are not selected.
Replacing that editor keeps the buffer id and can leave history
length at 0, so a key compare would reuse the previous file's
rows. A skipped record is the other clear. Motion, search,
`other-window`, and `ensure-visible` leave pictures in place. An
edit changes history length, a rename changes `(buffer name)`, and
a selection change flips `selected`. The next record rebuilds the
leaves whose keys no longer match, and an edit rebuilds every
leaf of that buffer.

History length can repeat. Undo lowers it, and a later edit can
raise it to a length a picture already stores, with different
text. A record between those two keys stores the lower length, so
the repeat misses. A skipped record would leave the old picture
in place across both keys. Dropping pictures on that skip is what
keeps the later split from painting the pre-undo rows.

`frame` after `record-pictures`, with the same `columns` and
`rows`, paints the same string as `frame` on the session from
before that record. Later edits, undos, visits, resizes, and
scroll changes paint the same string as a session that never
recorded a picture.

### Runner

While the terminal size is unchanged, one loop iteration is:

1. `ensure-visible`
2. `record-pictures`
3. `(term write (aloemacs-editor frame …))`
4. `handle-key`

`record-pictures` rebinds `aloemacs-editor`, as `ensure-visible`
and `handle-key` do. The frame thunk still reads that binding.
All three prepared thunks are rebuilt when the size changes.
`aloemacs-editor frame` remains the write. Do not move the build
into `ensure-visible`.

`tests/aloemacs/viewport-runner.rkt` checks that the runner source
mentions each of these once, in this order: `(term columns)`,
`(term rows)`, `aloemacs-editor ensure-visible`,
`aloemacs-editor record-pictures`, `(term write`,
`aloemacs-editor frame`, `(term read-key)`. Keep that order check,
with `record-pictures` added. `tests/aloemacs/file-runner.rkt`
still requires the string `aloemacs-editor frame`.

## Tests

New `tests/aloemacs/window-pictures.rkt`. Checked driver, load
`examples/aloemacs/main.aloe`, inject the filesystem host the
other session tests inject, no TTY. The checks run at module top
level. No `module+ main`.

Build the fixture in Racket before loading it into the session.
971 lines, joined with `"\n"`. Line `n` is the decimal text of `n`,
one space, then enough `x` characters that the line's length is 35.
Line 0 begins with `"0 "` and line 800 begins with `"800 "`.

Fit with `ensure-visible` at 220 columns and 54 rows before the
first split. Three `split-right` sends produce four leaves. The
three that are not selected still have `scroll-row` 0. If a split
is refused, stop and report that. Do not force the selected leaf
to a particular column.

`page-down` moves the point and leaves every `scroll-row` alone.
`ensure-visible` stores the new origin on the selected view.

### Same bytes

At the first screen, and again after `page-down` until the selected
point line is at least 800, then `ensure-visible` at 220 columns
and 54 rows:

- The unselected leaves still have `scroll-row` 0. The selected
  leaf's `scroll-row` after that fit is greater than 700.
- `(session frame 220 54)` equals
  `((session record-pictures 220 54) frame 220 54)`.
- One `move-down` on the session that has not recorded, then
  `frame`, equals `record-pictures` and `frame` after the same
  `move-down` on the recorded session.
- On the deep fitted session, one `move-down` then
  `ensure-visible` on the session that has not recorded, then
  `frame`, equals `record-pictures` and `frame` after the same
  `move-down` and `ensure-visible` on the recorded session. The
  selected `scroll-row` has increased. The unselected scrolls are
  still 0.

Then, on the deep recorded session: `insert` of `"q"`,
`record-pictures`, and `frame`. The string differs from the
pre-insert frame and contains `"q"`. Every leaf of that buffer
was rebuilt. `undo`, `record-pictures`, and `frame` equal the
pre-insert frame.

Visit a path while the buffer's history is still empty, split to
four windows, and record. `visited` of that same path with different
contents, then `record-pictures` and `frame`, equals `frame` on a
session that has those new contents and has never recorded a
picture. The unselected leaves must not keep the previous file's
rows. History length is still 0 and the path text is unchanged, so
this is the case the `visited` clear exists for.

A one-window session at this geometry has never recorded.
`record-pictures` returns it unchanged: the session before the
send equals the session after it.

Close, undo, and a different insert, then split again. From a
fitted one-window session at 220 columns and 54 rows: `insert` of
`"a"`, `split-right`, and `record-pictures`. Then `delete-window`
and `record-pictures` again. That second record skips. The
surviving leaf's picture is `(Option None)`. Then `undo`,
`insert` of `"b"`, `split-right`, `record-pictures`, and `frame`
equal `frame` on a session that took the same steps and never
received `record-pictures`. The history length is back where the
first record stored it, and the text differs. Both frames show
the `"b"` insert in the unselected leaf.

A recorded multi-window session sent `record-pictures` of `0` and
`0` takes the other skip. The root is not positive. Every leaf's
picture is `(Option None)`.

### Timing bar

Prepare `ensure-visible`, `record-pictures`, and `frame` with
`driver-prepare!` before the samples, as the runner prepares them.
Each timed sample is only those three prepared calls, in that
order. `move-down` is prepared too and runs outside the timer.
Typechecking stays outside the timer.

`move-down` changes the point and leaves `scroll-row` alone. The
following `ensure-visible` stores the origin on the selected view.
When that origin changes, the selected picture misses and
`record-pictures` rebuilds that leaf. The other leaves still
match. A sample that skips the fit stays on four cache hits even
at line 800.

Warm once with an untimed `ensure-visible` and `record-pictures`
at the position under test. Then five samples. Each sample sends
one `move-down`, then times `ensure-visible`, `record-pictures`,
and `frame` as one interval. Use
`current-inexact-monotonic-milliseconds`. The median is the third
value after sorting the five durations ascending.

Three medians, each strictly under **30** milliseconds:

- four windows, first screen
- four windows, after the deep fit above: selected point line at
  least 800, selected `scroll-row` greater than 700, unselected
  scrolls still 0 before the warm record
- one window, selected point line at least 800 after the same
  `page-down` and `ensure-visible` fit

On failure, the Rackunit message includes the median in
milliseconds. `printf` all three medians when they pass.

The warm record is the first paint at that origin. It may cost
what a cold frame costs today, including the stale walk the first
time an unselected leaf is pictured there. The timed samples are
the paint a held key repeats. On the first screen the fit leaves
every scroll at 0, so all four pictures match. Once the selected
window is scrolling, each sample rebuilds that one leaf and reuses
the other three.

If a four-window median is 30 ms or more, stop and report all three
numbers. Do not raise the bar. Do not change `safe-cells`, List, or
Text. If the one-window median is 30 ms or more, stop and report it.
The one-window path was already under the bar, and this slice must
leave it there.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-pictures.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
TMPDIR=/tmp raco test -j 4 -y tests/parenthetical-construction
```

If those are green, `TMPDIR=/tmp raco test -j 4 -y tests`.
`git diff --check` clean.

The timing file's printed medians are part of the result. Record
them.

Stop. Do not issue 001.

## Non-goals

- A Vector, a linked List, or a change to `focus-at` or `focus-down`
- Rewriting the per-character `safe-cells` walk
- Coalescing queued keys in the runner
- Scrolling unselected windows when the selected window moves
- Caching the echo row, the completion addresses, or the cursor
  address
- Recording pictures from `ensure-visible` or from `single-frame`
- Reusing a leaf across an edit. A changed history length rebuilds
  every leaf of that buffer
- A buffer revision that only increases. The skip clear and the
  `visited` clear cover this slice
- Mutation, in Aloe or in the terminal buffer
