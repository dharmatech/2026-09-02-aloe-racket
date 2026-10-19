# aloemacs-frame-time 001 — Read the visible lines

**Status: Implemented and reviewed; the series is closed.** Issued
2026-10-19 by the checkpoint manager from [`../spec.md`](../spec.md)
after [`000-blank-by-find.md`](000-blank-by-find.md), implemented the
same day, and committed with 000 in `9dd3c60`. The closing review of
2026-10-19 passed: the hand check of spec §14 held on four windows and
on one, and five consecutive `TMPDIR=/tmp raco test -j 4 -y tests`
runs were green at 4,990 tests each with no rerun.

Medians in ms, alone (one run of `frame-time.rkt` by itself) and from
each of the five whole-suite runs:

| Case | Alone | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|---:|
| four windows, first screen | 3.14 | 3.23 | 3.26 | 3.36 | 3.33 | 3.28 |
| four windows, widest leaf deep, 971 lines | 9.45 | 9.67 | 9.49 | 9.74 | 9.85 | 9.60 |
| four windows, widest leaf deep, 2,400 lines | 9.47 | 9.76 | 9.48 | 9.80 | 9.82 | 9.66 |
| growth, four windows deep | 0.02 | 0.09 | -0.00 | 0.06 | -0.03 | 0.06 |
| one window deep, 971 lines | 4.90 | 4.96 | 4.99 | 5.05 | 5.09 | 4.99 |
| one window deep, 2,400 lines | 5.08 | 4.97 | 5.00 | 5.20 | 5.16 | 5.02 |
| growth, one window deep | 0.18 | 0.01 | 0.01 | 0.15 | 0.07 | 0.03 |
| four windows, widest leaf, last page of 2,400 lines | 11.65 | 12.31 | 11.97 | 12.45 | 12.55 | 12.21 |
| one window, last page of 2,400 lines | 7.15 | 7.59 | 7.32 | 7.72 | 7.72 | 7.49 |

Every median is under the 15 ms design margin alone and under the 30 ms
bar under `-j 4`; every growth is under the 1.5 ms bound.

If you have been told to read this file, it is the whole assignment.
Read the spec sections named below, implement this slice, and stop
when green.

## Goal

A deep Down stops growing with the length of the file. Today each
frame walks the zipper from the point to the top row and down again,
and every step copies a whole List, so a deep frame costs the file's
length per row. This slice reads the visible lines straight from the
zipper's two Lists without moving the focus:

1. `Text` gains `lines-from` and its helper `entries-after` (spec
   §6.1). For every well-formed text, `(t lines-from top count)`
   equals `focus-at top` followed by `next-lines count`.
2. `AloemacsEditor.frame-rows` and `AloemacsEditor.frame` read through
   `lines-from` (spec §6.2). `next-lines` stays on `Text`, unchanged;
   the editor no longer sends it.
3. `tests/aloemacs/frame-time.rkt` gains the long fixture, the paired
   deep cases, the last page, and the growth rule (spec §8). A new
   `tests/aloemacs/frame-time-lines.rkt` holds the contract of §6.1
   on small texts and the recorded-equals-unrecorded check on the
   long fixture (spec §9.2).

The bytes on screen stay the bytes `frame` paints today. On the
designer's scratch copy at 2,400 lines, with the clock of spec §8.3
and tabs on screen, the deep cases went from 15.7 / 11.2 ms (four
windows / one window) after 000 to 9.2 / 4.9. The worst Down measured
after this slice is 11.9 ms, four windows at the last page of 2,400
lines.

This is the last checkpoint of the series. There is no 002. Stop when
green; the human's closing review runs the hand check and the five
whole-suite runs.

## Authority, identity, and starting point

The implementer receives this checkpoint and the spec. The checkpoint
narrows the spec to one slice and restates every rule the slice needs.
It does not revise the spec.

- Identity: **aloemacs-frame-time 001**, filed as
  `checkpoints/001-read-visible-lines.md`. A local editor checkpoint:
  no global number, no `CHECKPOINTS.md` entry, nothing under
  `docs/checkpoints/`. Predecessor: aloemacs-frame-time 000.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`. `let`
  is `((fn (names ...) body) call exprs ...)`, so its bindings are
  independent of one another; every `let` below is written that way,
  and a binding that needs an earlier one sits in a nested `let`.
  `cond` with a final `else` is `SPEC.md`'s sugar for nested `if`.
  No mutation, macros, inheritance, implicit coercion, or new special
  forms.
- [`../spec.md`](../spec.md) governs this slice through §2
  (boundary), §6 (the read), §8 (the bar, now whole), the preamble of
  §9 and §9.2, the 001 entry of §10, §12 (closed documents), §14 (the
  hand check), and §15. Its measured tables are evidence, not rules.
  §4, §5, and §9.1 are 000's and are done.
- Preconditions: global checkpoint 118 landed in `29c5103`, and 000 is
  in the tree. Begin with
  `TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-118.rkt` green and
  `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/frame-time-cells.rkt tests/aloemacs/frame-time.rkt`
  green. If `AloemacsEditor.safe-rows` or either file is missing, 000
  is not in the tree: stop and report it.

Facts about today's tree, with 000 in it. Do not redesign them.

- `lib/text.aloe` loads `option.aloe` and defines `Position`, `Span`,
  and `Text`. `Text` has two constructors, `from-string` with the
  field `source`, and `indexed` with the fields `above`, `current`,
  `below`, and `focus`. Its `define-class` methods, in order, are
  `to-string`, `lines`, `indexed-value`, `focus-at`, `focus-line`,
  `current-line`, `next-lines`, `line-length`, `has-previous?`,
  `has-next?`, `focus-up`, `focus-down`, `valid-position?`, and
  `valid-span?`. A `define-methods Text` block after `EditResult`
  adds `excerpt`, `replace-pieces`, `replace`, `insert`, `delete`,
  and `newline`.
- Every `Text` message builds only well-formed texts: a `from-string`
  text, or an `indexed` one whose `focus` is `(above len)`.
  `focus-up` and `focus-down` each send `rest` to one List and `cons`
  to the other, so each copies both. `next-lines` takes the current
  line and walks `focus-down`, padding with `""` past the end.
  `Text.excerpt` sends `next-lines`, and
  `tests/aloemacs/next-lines.rkt` pins it.
- `Int` answers `max` and `min`; they come from `lib/int.aloe`, which
  `aloe/library.rkt` bootstraps as it does `lib/list.aloe`. No new
  `load` is needed.
- After 000, `AloemacsEditor.frame-rows` sends `focus-at scroll-row`,
  then `next-lines rows` on the result, clips each line, and sends
  `safe-rows` to the list. `AloemacsEditor.frame` sends
  `focus-at (point line)`, then `focus-at top` on that, then
  `next-lines rows`, clips, sends `safe-rows`, folds with `"\r\n"`,
  and wraps the body with `frame-ansi`. `safe-rows`, `safe-cells`,
  `blank-controls`, `blank-from`, and `controls-in` are 000's and do
  not change.
- After 000, `tests/aloemacs/frame-time.rkt` builds the short fixture
  with a `fixture-line` function, plants it as `/cwd/short.txt`, and
  builds the sessions `one`, `first-screen`, `widest`, `four-deep`,
  and `one-deep`, paging with `page-deep!` to line 800. Its
  `sampler` prepares the four forms of spec §8.3 under a timed name;
  `medians` takes a list of case names, binds `timed-<case>` to a
  copy of each, sends `(collect-garbage)` once, samples the group in
  alternation for eleven rounds, and returns the sixth sorted sample
  of each; `bar!` prints a median with its label and then checks it
  under 30 ms. Three groups of one case each are timed.
- `tests/aloemacs/frame-time-cells.rkt` holds 000's byte checks. Its
  items 4 and 5, the one-window frames at six origins and the
  recorded four-window frames at five steps, stay as they are and
  cover the new read at origins above, around, and below the focus.
- The designer's prototype,
  [`archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/prototype.diff`](../../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/prototype.diff),
  is evidence that the design runs. Its `lib/text.aloe` hunk and its
  frame hunks are the spec's §6 code. Its draft bar holds the growth
  checks at 3.0 ms, not the spec's 1.5, and it predates 000's test
  files. Do not apply it. This checkpoint says what 001 writes.

Scratch-run inventory (spec §13): the designer applied 000's and
001's product edits together to a copy of `29c5103` and ran the whole
suite. No existing test failed, and 000's byte checks passed on the
new read. With 000 in the tree the whole suite passes 3,873 tests
today. There is no migration. No class list, field, or constructor
changes. If an existing test fails after the product edit, stop and
report it; do not edit that test.

## Exact file scope

### May edit

- `lib/text.aloe` — add `lines-from` and `entries-after` to the
  `define-class Text` methods, directly after `focus-down` and before
  `valid-position?`. Every existing message keeps its body and its
  result. `next-lines` keeps its body.
- `examples/aloemacs/editor.aloe` — the read in `frame-rows` and the
  read in `frame`, as written under **Required behavior**. Nothing
  else in either method changes, and no other method changes.
- `tests/aloemacs/frame-time-lines.rkt` (new)
- `tests/aloemacs/frame-time.rkt` — the long fixture, its sessions,
  the paired groups, the last page, the growth checks, and the header
  comment, as written under **Tests**. The short fixture, its
  sessions, `sampler`, `medians`, and `bar!` stay.

### Must leave untouched

- `aloe/`, `host/racket/`, `SPEC.md`, `CHECKPOINTS.md`, `bin/`
- `lib/` outside `text.aloe`; inside it, every method other than the
  two added, including `next-lines`, `excerpt`, `focus-at`,
  `focus-up`, and `focus-down`
- `examples/aloemacs/file.aloe`, `main.aloe`, Gel, `docs/editor/`
- Every `define-class` list, every field, every constructor, and the
  signature of every existing method. No class is added.
- `safe-cells`, `safe-rows`, `blank-controls`, `blank-from`,
  `controls-in`, `blank-rows`, `frame-ansi`, `with-origin`,
  `ensure-visible`, `AloemacsLeafPicture`, its key, and
  `record-pictures`
- `tests/aloemacs/frame-time-cells.rkt`, `window-pictures.rkt`,
  `next-lines.rkt`, `viewport-top.rkt`, and every other existing
  test. A frame golden that fails means the new read painted
  different bytes. Fix the product edit, not the expected bytes.
- `archive/`, [`../spec.md`](../spec.md), [`../README.md`](../README.md),
  the parent aloemacs map, the closed documents listed in spec §12,
  000, and this checkpoint

If another file is necessary, stop and send this checkpoint back to
the manager. Do not widen the slice.

## Required behavior

### 1. `Text.lines-from` and `entries-after` (spec §6.1)

Add to `Text`, directly after `focus-down`:

```aloe
;; count lines from line top, read without moving the focus. None when
;; top is not a line of this text; "" for each line past the end.
(lines-from (top Int) (count Int) (Option (List String))
  (self case
    (from-string (source) ((self indexed-value) lines-from top count))
    (indexed (above current below focus)
      (if (if (top < 0) #t (top > (focus + (below len))))
          (Option None)
          (let ((upper (((focus - top) max 0) min count))
                (here? (if (top <= focus) (focus < (top + count)) #f)))
            (let ((lower ((count - upper) - (if here? 1 0))))
              (let ((middle
                      (if here?
                          ((self entries-after below 0 lower) cons current)
                          (self entries-after below ((top - focus) - 1) lower))))
                (Option Some
                  ((self entries-after above (((focus - top) - count) max 0) upper)
                   fold middle
                   (fn (lines line) (lines cons line)))))))))))

;; After skip entries of xs, count entries in xs's order, then "" for
;; each one past its end.
(entries-after (xs (List String)) (skip Int) (count Int) (List String)
  (cond
    ((count <= 0) (List empty))
    ((xs empty?) ((self entries-after xs 0 (count - 1)) cons ""))
    ((skip > 0) (self entries-after (xs rest) (skip - 1) count))
    ((count = 1) (List of (xs first)))
    (else ((self entries-after (xs rest) 0 (count - 1)) cons (xs first)))))
```

The contract, exact on every well-formed `Text`: for every such *t*,
`Int` *top*, and `Int` *count*,

```aloe
(t lines-from top count)
=
((t focus-at top) case
  (None () (Option None))
  (Some (at) (Option Some (at next-lines count))))
```

How the arithmetic reads it. `above` holds the lines before the
focus, nearest first. `upper` is how many of the window's lines lie
above the focus; `entries-after` skips the lines of `above` that lie
below the window's top, takes `upper` of them, and the `fold` with
`cons` puts them in file order in front of `middle`. `here?` says
whether the focused line is in the window; when it is, `current` is
the first line of `middle`. `lower` lines come from `below`, in
order, with `""` once it runs out. The last line of the text is
`focus + (below len)`, so a `top` past it, or below 0, is `None`. A
`count` of 0 or less at a valid `top` is `Some` of the empty List,
as `next-lines` gives.

`lines-from` never sends `focus-up`, `focus-down`, or `focus-at`, and
never copies the List on the other side of the focus. A hand-built
`Text indexed` whose `focus` is not `(above len)` is outside the
contract: `focus-at` walks it and `lines-from` does arithmetic on it,
and they can disagree. No `Text` message builds such a value, and
this slice adds none.

### 2. `frame-rows` reads through `lines-from` (spec §6.2)

`AloemacsEditor.frame-rows` becomes:

```aloe
(frame-rows (columns Int) (rows Int) (scroll-row Int) (scroll-col Int)
            (List String)
  (((self text) lines-from scroll-row rows) case
    (None () (self blank-rows rows))
    (Some (lines)
      (self safe-rows
        (lines map (fn (line) ((line drop scroll-col) take columns)))))))
```

The comment about a temporary zipper goes with the `focus-at` it
described. `blank-rows`, the clipping, and `safe-rows` stay.

### 3. `frame` reads through `lines-from` (spec §6.2)

`AloemacsEditor.frame` keeps `((self text) focus-at (point line))`
and its `None` arm. In place of `(focused focus-at top)` and then
`(at-top next-lines rows)`, its `Some` arm becomes:

```aloe
(Some (focused)
  ((focused lines-from top rows) case
    (None ()
      (self frame-ansi "" cursor-row cursor-column))
    (Some (lines)
      (self frame-ansi
        (if (rows < 1)
            ""
            (let ((clipped
                   (self safe-rows
                     (lines map (fn (line) ((line drop left) take columns))))))
              ((clipped rest) fold
                (clipped first)
                (fn (body line)
                  ((body append "\r\n") append line)))))
        cursor-row
        cursor-column))))
```

The `(rows < 1)` check, the clipping, `safe-rows`, the `"\r\n"` fold,
`frame-ansi`, and the cursor address stay. On a text already focused
at the point, as a Down leaves it, `focus-at (point line)` returns at
once; the read then costs the depth of the point, not the length of
the file. After this edit `examples/aloemacs/editor.aloe` contains no
send of `next-lines`.

## Tests

Both files run their checks at module top level, with no
`module+ main`. `frame-time-lines.rkt` uses a checked `make-driver`,
injects the filesystem double, loads `examples/aloemacs/main.aloe`
with `driver-load-file!`, then loads `file.aloe`, `editor.aloe`,
`lib/text.aloe`, and `lib/fs.aloe` as `frame-time-cells.rkt` does.
No TTY. Compare whole strings or whole `List`s, never a substring
alone.

### The long fixture (spec §8.1)

The same rule as the short fixture, at 2,400 lines: line *n* is the
decimal text of *n*, one space, then `x` up to 35 characters, and
when *n* mod 7 is 3 the character at index 10 is a tab. Plant it as
`/cwd/long.txt` beside `/cwd/short.txt`. Check that it has 2,400
lines and 343 tabs. `examples/aloemacs/file.aloe` was 2,370 lines on
18 October 2026; this fixture stands in for a file that long.

### `tests/aloemacs/frame-time-lines.rkt` (spec §9.2)

1. **The contract of §6.1, exhaustively on small texts.** First check
   that `lines-from` types as `(Int Int) -> (Option (List String))`,
   as `next-lines.rkt` checks `next-lines`'s type. Then for each
   source *s* in `""`, `"a"`, `"a\n\nc"`, `"0\n1\n2\n3\n4\n"`, and
   `"\n\n"`, let *n* be `(((Text from-string s) lines) len)`: 1, 1,
   3, 6, and 3. The texts are `(Text from-string s)` and, for each
   *focus* from 0 through *n* − 1, the indexed text
   `(((Text from-string s) indexed-value) focus-at focus)` unwrapped
   with `case`, where the `None` arm yields a text that makes the
   check fail, as `next-lines.rkt`'s `focused` helper does. For each
   such text *t*, each *top* from −1 through *n* + 1, and each
   *count* from −1 through *n* + 2, the Aloe `check` form holds
   `(t lines-from top count)` equal to the `focus-at`-then-
   `next-lines` expression above, under `check-not-exn` with a message
   that names *s*, the focus, *top*, and *count*. That is 1,046
   checks; count them and `printf` the count. The designer's probe,
   `archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/lines-from-equivalence.rkt`,
   ran 1,018 because it counted the empty text as zero lines; this
   test counts it as one, which is what `lines` answers.
2. **Recorded equals unrecorded on the long fixture.** 000's item 5
   again, on `/cwd/long.txt`: visit it, `ensure-visible 220 54`,
   three `split-right` sends, then `other-window` until
   `((s fit-rect 220 54) columns)` is 109; stop and report if a split
   is refused or four sends do not reach 109. Keep a plain session
   that is never sent `record-pictures` and a recorded one that is
   sent `record-pictures 220 54` after every step. At each step,
   `frame 220 54` on the recorded session equals `frame 220 54` on the
   plain one: at the first screen; deep, after `page-down` until the
   point line is at least 800 and `ensure-visible 220 54`; after one
   `move-down` and `ensure-visible 220 54`; after `insert "q"`; after
   `undo`. After the insert the frame contains `"q"`; after the undo
   it equals the frame from before the insert.

Before the product edit, item 1 fails because `lines-from` does not
exist. Item 2 passes on 000's read and must still pass on the new
one.

### `tests/aloemacs/frame-time.rkt` (spec §8, whole)

Keep the short fixture, its five sessions, `sampler`, `medians`, and
`bar!`. Plant the long fixture beside the short one. Update the
header comment to say the bar covers both fixtures and the last
page. Then build the long fixture's sessions, in this order and with
the same checks as the short ones:

1. **`long-one`:** visit `/cwd/long.txt`, then `ensure-visible 220 54`.
2. **`long-first-screen`:** from `long-one`, three `split-right`
   sends; stop and report a refusal. The selected leaf is at 27
   columns.
3. **`long-widest`:** from `long-first-screen`, `other-window` until
   `((s fit-rect 220 54) columns)` is 109; stop and report if four
   sends do not reach it.
4. **`long-four-deep`:** from `long-widest`, `page-down` until the
   point line is at least 800, then `ensure-visible 220 54`. Check
   that the selected view's `scroll-row` is greater than 700 and the
   other three views' `scroll-row` is 0.
5. **`long-one-deep`:** from `long-one`, the same paging and fit.
   Check that the point line is at least 800.
6. **Last page:** `long-four-end` from `long-four-deep` and
   `long-one-end` from `long-one-deep`, each a new session paged with
   `page-down` until the point line is at least 2,300, then
   `ensure-visible 220 54`. Check that each point line is at most
   2,388, so eleven Downs stay inside the last line, 2,399, and that
   `long-four-deep` and `long-one-deep` still have the point line
   they had before, so the deep sessions stay at their depth.

`page-deep!` pages to 800; generalize it to a target line or add a
second helper. Every session is a value; building one from another
copies it.

**Groups and labels (spec §8.4).** Four groups, timed in this order.
A group of two is sampled in alternation, one sample of each per
round, as `medians` already does:

| Group | Cases | Labels |
|---|---|---|
| 1 | `first-screen` | `four windows, first screen` |
| 2 | `four-deep`, `long-four-deep` | `four windows, widest leaf deep, 971 lines`; `four windows, widest leaf deep, 2400 lines` |
| 3 | `one-deep`, `long-one-deep` | `one window deep, 971 lines`; `one window deep, 2400 lines` |
| 4 | `long-four-end`, `long-one-end` | `four windows, widest leaf, last page of 2400 lines`; `one window, last page of 2400 lines` |

- `printf` every median with its label, passing or not, before its
  check. Every median is strictly under **30** ms. The failure message
  names the case and the median.
- **Growth.** For group 2 and for group 3, the long median minus the
  short median is strictly under **1.5** ms. `printf` both growths,
  labeled `growth, four windows deep` and `growth, one window deep`,
  passing or not, before their checks. The failure message names the
  pair and the growth.

The growth check is what the suite holds against a read that again
walks the zipper per row: one step per row would add about 1.9 ms
between the fixtures and today's two steps about 4 ms, while the key
itself, which still copies the whole file once, adds a few hundredths
of a millisecond. The last-page cases have no short twin; they hold
the growth with the depth of the point to the 30 ms bar and nothing
tighter. Today's read is under 30 ms there too, about 27.5 ms, so the
deep pairs carry the lock.

## Verification and completion

From the project root, in this order:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-118.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/frame-time-lines.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/frame-time-cells.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/frame-time.rkt
```

Run `frame-time.rkt` by itself, as above, for the medians and growths
taken alone. Then:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/next-lines.rkt tests/aloemacs/viewport-top.rkt tests/aloemacs/window-pictures.rkt tests/aloemacs/index-000-text-focus.rkt tests/aloemacs/index-002-frame.rkt tests/aloemacs/kill-excerpt.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests
```

```sh
git diff --check
```

The whole suite passes 3,873 tests today. After this slice it passes
those plus `frame-time-lines.rkt` and the added bar checks, with no
failure. `-j 4` and `-y` are required, and `TMPDIR=/tmp` is required
for agent runs. The product edit is in `.aloe` files only, so nothing
needs `raco make`.

Report, with the result:

- the seven medians and two growths from the run of `frame-time.rkt`
  alone, and
- the seven medians and two growths printed by the whole-suite run.

Both sets are part of the result. Record them in the review.

Stop for review. Do not write a 002; there is none. Do not edit the
spec, the READMEs, or the closed documents.

## Acceptance

- `tests/checkpoint-118.rkt`, `frame-time-cells.rkt`, and
  `frame-time.rkt` green before the edit, so 000 is in the tree.
- `frame-time-lines.rkt` green: the type of `lines-from`, the 1,046
  contract checks, and the five recorded-equals-unrecorded steps on
  the long fixture.
- `frame-time.rkt` green: all seven medians under 30 ms and both
  growths under 1.5 ms.
- **Every median alone is at most 15 ms** on the machine of the run
  (spec §8.5: half the bar, so a run under `-j 4` that doubles a
  frame still passes). A median alone above 15 ms fails the
  checkpoint, however green the suite. Report every number and stop.
  Do not raise either bar, do not change the sample, do not touch
  List. The designer measured, alone: first screen 3.3, deep four
  windows 9.2 to 9.3, deep one window 4.8 to 4.9, last page 11.9 and
  7.1, growths 0.01 to 0.15 ms.
- `examples/aloemacs/editor.aloe` contains no send of `next-lines`.
  `git diff lib/text.aloe` shows only the two added methods.
- `frame-time-cells.rkt`, `next-lines.rkt`, `viewport-top.rkt`,
  `window-pictures.rkt`, and every index, kill, and viewport test
  green and unedited.
- The whole suite green under `-j 4`. `git diff --check` clean.
- The working tree differs from the start of the slice in exactly
  `lib/text.aloe`, `examples/aloemacs/editor.aloe`,
  `tests/aloemacs/frame-time.rkt`, and the new
  `tests/aloemacs/frame-time-lines.rkt`.

### Closing review, after the implementer stops

These are the human's, recorded with the review, not the
implementer's:

- **Hand check (spec §14).** On a real terminal, with no rebuild:

  ```sh
  racket host/racket/aloemacs-run.rkt examples/aloemacs/file.aloe
  ```

  1. `C-x 3` three times. `C-x o` until the widest window is selected.
  2. Page Down past line 800.
  3. Hold Down for a few seconds, then release. The cursor stops with
     the key: no lines scroll after the release.
  4. `C-x 0` until one window is left. Page Down past line 800 if
     needed, and repeat step 3.

- **Five runs (spec §8.5).** `TMPDIR=/tmp raco test -j 4 -y tests`
  five times in a row. Every run is green with no rerun. The five
  runs' printed medians and growths are recorded with the review.
- Then the series closes. The parent map's frame-time row, this
  folder's `README.md`, and the closed documents of spec §12 may point
  at the spec. That is map work for the closing review.

## Non-goals

- A 002. The series has two checkpoints.
- Held typing, edit-aware row reuse, an edit range, or a typing bar
  (spec §11). The walk a typed character pays in unselected windows
  stays; it is the language-spine discussion of indexed read and
  slicing for List.
- Reusing rows across a scroll (spec §7.1), one zipper walk from the
  point (§7.2), a read through one joined String (§7.3), or List
  steps (§7.4).
- An indexed read, slicing, or cheaper `cons` and `rest` for List, in
  the kernel or emulated with String sends; a `Vector`; ropes or
  piece tables; any change under `aloe/`, `host/racket/`, or `lib/`
  outside `text.aloe`.
- Changing `next-lines`, `excerpt`, `focus-at`, `focus-up`, or
  `focus-down`, or removing `next-lines` because the editor no longer
  sends it.
- Recorded rows for the one-window path; changing
  `AloemacsLeafPicture`, its key, or `record-pictures`.
- Key coalescing, the runner, the manifest runner, the Aloe-side
  loop, scroll regions, fewer terminal bytes.
- Joining rows with `joined-with` instead of `fold`, or any other
  change to frame assembly.
- Editing the spec, 000, this folder's `README.md`, the parent map, or
  the closed documents of spec §12.
