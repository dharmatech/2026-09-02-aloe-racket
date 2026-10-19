# aloemacs-frame-time 000 — Blank controls by find

**Status: Ready to implement.** Issued 2026-10-19 by the checkpoint
manager from [`../spec.md`](../spec.md). Human review of this
checkpoint precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the spec sections named below, implement this slice, and stop
when green.

## Goal

A held Down keeps up in four windows and in one. This slice takes the
per-character loops out of a frame and leaves the zipper walk for 001:

1. `AloemacsWindowRect.spaces` and `AloemacsModeLine.fill` build their
   strings by doubling (spec §4).
2. `AloemacsEditor.safe-cells` blanks each control it finds instead of
   walking every character. A new `safe-rows` checks a leaf's clipped
   rows as one block and blanks each row only for the controls the
   block holds (spec §5). Both frame paths send `safe-rows` to their
   clipped rows and keep reading through `focus-at` and `next-lines`.

The bytes on screen stay the bytes `frame` paints today. The timing bar
leaves `tests/aloemacs/window-pictures.rkt` for a new
`tests/aloemacs/frame-time.rkt`, with a fixture that has tabs on
screen. A new `tests/aloemacs/frame-time-cells.rkt` checks the bytes
against a reference painter written in Racket.

On the designer's scratch copy at 971 lines, with the clock of spec
§8.3 and a tab on every seventh line, this edit alone took a deep Down
from about 23 / 14 ms (four windows / one window) to 11.4 / 7.0.

Stop when green. Do not start 001.

## Authority, identity, and starting point

The implementer receives this checkpoint and the spec. The checkpoint
narrows the spec to one slice and restates every rule the slice needs.
It does not revise the spec.

- Identity: **aloemacs-frame-time 000**, filed as
  `checkpoints/000-blank-by-find.md`. A local editor checkpoint: it
  takes no global number, gets no `CHECKPOINTS.md` entry, and adds
  nothing under `docs/checkpoints/`. It is not
  aloemacs-window-pictures 001 and not safe-cells 001.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`. `let`
  is `((fn (names ...) body) call exprs ...)`, so its bindings are
  independent of one another; every `let` below is written that way.
  `/` on two `Int` values is integer division. No mutation, macros,
  inheritance, implicit coercion, or new special forms.
- [`../spec.md`](../spec.md) governs this slice through §2 (boundary),
  §4 (padding), §5 (blank by find, `safe-rows`, where it is sent), §8
  as far as the short fixture (§8.1 **Short**, §8.2 sessions 1–5,
  §8.3, the three 000 rows of §8.4, §8.5), the preamble of §9 and
  §9.1, the 000 entry of §10, and §15. Its measured tables are
  evidence, not rules. §6, §9.2, §14, and the long fixture, the last
  page, the pairs, and the growth check of §8 are 001's and are not
  implemented here.
- Precondition (spec §1.1): global checkpoint 118 landed in `29c5103`.
  Begin with `TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-118.rkt`
  green. Every timing number you report is taken on that tree.

Facts about today's tree. Do not redesign them.

- `examples/aloemacs/editor.aloe` defines `safe-cell-controls` before
  `AloemacsEditor`: one string of the 33 controls, codes 0–31 and then
  127, in that order. It stays the one control string.
- Today's `safe-cells` walks the clipped string one character at a
  time: `take 1`, one `find` of that cell in `safe-cell-controls`, one
  `append`, and a recursive send on `drop 1`.
- `AloemacsEditor.frame-rows` sends `focus-at scroll-row`, then
  `next-lines rows`, then `map` with `safe-cells` of each row clipped
  as `((line drop scroll-col) take columns)`. `AloemacsEditor.frame`
  sends `focus-at (point line)`, then `focus-at top` on that, then
  `next-lines rows`, clips each row as `((line drop left) take columns)`
  through `safe-cells`, folds the rows with `"\r\n"`, and wraps the
  body with `frame-ansi`. Both paths stay on `focus-at` and
  `next-lines` in this slice.
- `AloemacsWindowRect.spaces` and `AloemacsModeLine.fill` build one
  character per send. `pad-row`, `name-row`, and `row` send them and
  keep their bodies.
- `safe-cells` is also sent by `AloemacsWindowTree.built-rows` and
  `AloemacsSession.single-frame` on the mode row, by `echo-row`, by
  `completion-frame`, and by the search key check
  `((self editor) safe-cells key)`. Every one of those sends stays.
- `tests/aloemacs/window-pictures.rkt` holds the timing bar from the
  comment line beginning `;; Timing bar.` to the end of the file, and
  its two-line header ends with the clause
  `and a held Down stays under the keyboard repeat interval.`
- `AloemacsSession` answers `visit`, `ensure-visible`, `split-right`,
  `other-window`, `page-down`, `move-down`, `insert`, `undo`,
  `record-pictures`, `frame`, `fit-rect`, `handle-event`, `editor`,
  `point`, and `windows`. The event string `"down"` is bound to
  `MoveDown`. `AloemacsEditor` answers `with-origin scroll-row
  scroll-col`, `frame columns rows`, and `frame-rows columns rows
  scroll-row scroll-col`.
- The driver provides `make-driver`, `driver-load-file!`,
  `driver-eval!`, `driver-prepare!`, and the Aloe `check` form.
  `host/racket/fs.rkt` provides `make-fs-double`.
  `tests/aloemacs/window-pictures.rkt` shows how a session test loads
  `main.aloe`, `file.aloe`, `editor.aloe`, `lib/text.aloe`, and
  `lib/fs.aloe` over that double and visits a planted path.
- The designer's prototype,
  [`archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/prototype.diff`](../../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/prototype.diff),
  is evidence that the design runs. It carries 001's `lib/text.aloe`
  edit, 001's read in both frame paths, and a draft bar with the long
  fixture and a growth check. Do not apply it. This checkpoint, not
  the diff, says what 000 writes.

Scratch-run inventory (spec §13): the designer applied 000's product
edit alone to a copy of `29c5103` and ran the whole suite. No existing
test failed. Since `29c5103` the tree has changed only under `docs/`
and `archive/`, and today the whole suite passes 3,094 tests. There is
no migration. No class list, field, or constructor changes, so the
tests that pin `file.aloe`'s ordered class list are untouched. If an
existing test fails after the product edit, stop and report it; do not
edit that test.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` — the body of
  `AloemacsEditor.safe-cells`; four new `AloemacsEditor` methods,
  `blank-controls`, `blank-from`, `safe-rows`, and `controls-in`; and
  the one send in `frame-rows` and the one in `frame` that becomes
  `safe-rows`. Nothing else in either method changes.
- `examples/aloemacs/file.aloe` — the bodies of
  `AloemacsWindowRect.spaces` and `AloemacsModeLine.fill` only. Their
  names, parameters, and result types stay.
- `tests/aloemacs/frame-time-cells.rkt` (new)
- `tests/aloemacs/frame-time.rkt` (new)
- `tests/aloemacs/window-pictures.rkt` — delete the timing section and
  the header's clause about the repeat interval, as written under
  **Tests**. Every byte check stays as it is.

### Must leave untouched

- `lib/`, including `lib/text.aloe` (`lines-from` is 001)
- `aloe/`, `host/racket/`, `SPEC.md`, `CHECKPOINTS.md`, `bin/`
- `examples/aloemacs/main.aloe`, Gel, `docs/editor/`
- Every `define-class` list, every field, every constructor, and the
  signature of every existing method. No class is added.
- `safe-cell-controls`, `AloemacsLeafPicture`, its key,
  `record-pictures`, and every other method of `editor.aloe` and
  `file.aloe` not named above
- Every existing test other than `window-pictures.rkt`, in particular
  `tests/aloemacs/safe-cells.rkt`, `safe-cell-scan.rkt`,
  `window-bars-one-view.rkt`, `mode-buttons-paint.rkt`, and
  `next-lines.rkt`. They pin the result of `safe-cells`, the
  signature of `fill`, `fill 3`, and `next-lines`; all of that stays.
- Every frame golden string. A failure there means the new bytes
  differ from today's. Fix the product edit, not the expected bytes.
- `archive/`, [`../spec.md`](../spec.md), [`../README.md`](../README.md),
  the parent aloemacs map, the closed documents listed in spec §12,
  and this checkpoint

If another file is necessary, stop and send this checkpoint back to
the manager. Do not widen the slice.

## Required behavior

### 1. Padding by doubling (spec §4)

Replace the body of `AloemacsWindowRect.spaces` with:

```aloe
(spaces (remaining Int) String
  (if (remaining <= 0)
      ""
      (let ((half (self spaces (remaining / 2))))
        (if (((remaining / 2) * 2) = remaining)
            (half append half)
            ((half append half) append " ")))))
```

`AloemacsModeLine.fill` gets the same body with `"-"` in place of
`" "` and `fill` in place of `spaces`. The results are unchanged:
`""` for a count of 0 or less, otherwise exactly that many spaces or
dashes. `pad-row`, `name-row`, and `row` keep their bodies.
`file.aloe` stays ASCII bytes, and the new code in both files is
ASCII.

### 2. `safe-cells` by find (spec §5.1)

`safe-cells` keeps its send, its argument, its result type, and its
rule: after clipping, codes 0–31 and 127 paint as one space and every
other character is copied, and the result has the argument's length.
Replace its body and add two methods directly after it:

```aloe
;; One find per control; each match becomes one space.
(safe-cells (clipped-string String) String
  (self blank-controls clipped-string safe-cell-controls))

(blank-controls (shown String) (controls String) String
  (if ((controls len) = 0)
      shown
      (self blank-controls
        (self blank-from shown (controls take 1) 0)
        (controls drop 1))))

(blank-from (shown String) (control String) (start Int) String
  ((shown find control start) case
    (None () shown)
    (Some (at)
      (self blank-from
        (((shown take at) append " ") append (shown drop (at + 1)))
        control
        (at + 1)))))
```

The receiver of `find` is the string being shown and the pattern is
the one-character control; today's body has them the other way
round. A space is not a control, so a replacement never makes a match
for a later control. Each position is replaced at most once and the
length is kept. Every caller named under **Facts** keeps sending
`safe-cells`. A one-character search key now costs 33 `find` sends
instead of one; that is microseconds, once per key, and
`(editor safe-cells key)` still equals `key` for a printable key and
`" "` for a control key.

### 3. `safe-rows` (spec §5.2)

Add two methods to `AloemacsEditor` directly after `frame-rows`:

```aloe
;; A leaf's clipped rows are checked as one block. Each row is then
;; blanked for the controls the block holds, and only those.
(safe-rows (clipped (List String)) (List String)
  (let ((present
          (self controls-in ("" joined-with (List empty) "" clipped)
            safe-cell-controls)))
    (if ((present len) = 0)
        clipped
        (clipped map (fn (row) (self blank-controls row present))))))

;; The controls that occur in shown, in the order of controls.
(controls-in (shown String) (controls String) String
  (if ((controls len) = 0)
      ""
      (let ((rest (self controls-in shown (controls drop 1))))
        (if ((shown find (controls take 1) 0) present?)
            ((controls take 1) append rest)
            rest))))
```

`("" joined-with (List empty) "" clipped)` is the rows with nothing
between them: an empty separator, no `above`, and an empty `current`
before the rows. `controls-in` sends one `find` per control to that
block and keeps the ones it finds, in the order of
`safe-cell-controls`. A block with none returns the clipped rows
themselves. Otherwise each row goes through `blank-controls` with
only the present controls. A control absent from the block is absent
from every row, so for every `(List String)` `rows`,
`(editor safe-rows rows)` equals
`(rows map (fn (row) (editor safe-cells row)))`. The tests hold that
law. A row is blanked on its own, never the joined block, so the cost
is quadratic in a row's length at worst and never in the leaf's.

### 4. Both frame paths send `safe-rows` (spec §5.3)

`frame-rows` and `frame` clip each row as today and send `safe-rows`
to the list of clipped rows instead of `safe-cells` to each row.
`frame-rows` becomes:

```aloe
(frame-rows (columns Int) (rows Int) (scroll-row Int) (scroll-col Int)
            (List String)
  ;; Focus only a temporary zipper at this view's explicit origin.
  (((self text) focus-at scroll-row) case
    (None () (self blank-rows rows))
    (Some (at-top)
      (self safe-rows
        ((at-top next-lines rows) map
          (fn (line) ((line drop scroll-col) take columns)))))))
```

In `frame`, only the binding of `clipped` changes:

```aloe
(let ((clipped
       (self safe-rows
         ((at-top next-lines rows) map
           (fn (line) ((line drop left) take columns))))))
  ((clipped rest) fold
    (clipped first)
    (fn (body line)
      ((body append "\r\n") append line))))
```

`focus-at (point line)`, `focus-at top`, both `None` arms, the
`(rows < 1)` check, the `"\r\n"` fold, `frame-ansi`, and the cursor
address stay as they are. `next-lines` stays on `Text` unchanged and
both paths still send it; 001 replaces that read. The mode row in
`built-rows` and `single-frame`, the echo row, and the completion
frame keep sending `safe-cells` and are not routed through
`safe-rows`.

## Tests

Both new files run their checks at module top level, with no
`module+ main`, so `raco test` runs them. Each uses a checked
`make-driver`, injects the filesystem double the other session tests
inject, loads `examples/aloemacs/main.aloe` with `driver-load-file!`,
then loads `file.aloe`, `editor.aloe`, `lib/text.aloe`, and
`lib/fs.aloe` as `window-pictures.rkt` does. No TTY. Compare whole
strings or whole `List`s, never a substring alone.

### The short fixture (spec §8.1)

Build it in Racket before loading it. Line *n*, counting from 0, is
the decimal text of *n*, one space, then `x` up to 35 characters.
When *n* mod 7 is 3, the character at index 10 is a tab (U+0009) in
place of that `x`. 971 lines, joined with `"\n"`. Plant it as
`/cwd/short.txt`. Check that it has 971 lines and 139 tabs, so every
52-row window shows seven or eight tabbed rows and every timed leaf
takes the per-row path of `safe-rows`. Do not plant the long fixture;
that is 001.

### The reference painter (spec §9)

Written in Racket in `frame-time-cells.rkt`, not in Aloe. For a list
of lines, an origin `top` and `left`, and a size `columns` × `rows`:

1. Take lines `top` through `top + rows − 1`, with `""` for each line
   past the end of the list.
2. Drop the first `left` characters of each; all of a shorter line.
3. Keep the first `columns` characters.
4. Replace every character whose code is below 32 or is 127 with a
   space.

Those are the reference rows. The reference frame for an editor whose
point is at `(line, column)` is `"\e[?25l\e[2J\e[H"`, the rows
joined with `"\r\n"`, then `"\e["`, the decimal text of
`line − top + 1`, `";"`, the decimal text of `column − left + 1`,
and `"H\e[?25h"`. Spell the escape as the existing tests do, through
`\e` or `\u001b`, never as a decoded glyph.

### `tests/aloemacs/frame-time-cells.rkt` (spec §9.1)

Bind `ed` to `(aloemacs-editor editor)` for items 1–3. The sessions
of items 4 and 5 visit `/cwd/short.txt`.

1. **`safe-cells` against the reference rule.** For each argument,
   `(ed safe-cells s)` equals step 4 of the reference applied to `s`
   and has `s`'s length: `""`; each of the 33 controls alone; the 33
   in order as one String; `"a\tb"`; `"\e[31m"`; printable ASCII 32–126
   as one String; `"é↕↔×"`; a 300-character String of `y` with ESC at
   index 0, a tab at 150, DEL (U+007F) at 299, the run `"\t\t\t"` at
   40–42, and the run `"\r\n"` at 80–81; and a String of only controls
   with repeats, for example NUL, US, DEL, NUL, tab, tab.
2. **`safe-rows`.** For each list of rows, `(ed safe-rows rows)`
   equals step 4 applied to every row, and `check` holds
   `(ed safe-rows rows)` equal to
   `(rows map (fn (row) (ed safe-cells row)))`: `(List empty)`;
   `(List of "")`; three empty rows; clean rows of lengths 0, 1, 35,
   and 109, whose result is the same rows; a control as the first
   character of the first row; a control as the last character of
   the last row; a row of only controls; an empty row between two
   rows that hold controls; two rows that hold different controls;
   and one 109-character row whose characters cycle through the 33
   controls in order, so every control is present and every cell is
   blanked.
3. **Padding.** For every count *n* from −2 through 300,
   `((AloemacsWindowRect new 0 0 109 53) spaces n)` is a String of
   `max(n, 0)` spaces and `((AloemacsModeLine new) fill n)` a String
   of `max(n, 0)` dashes.
4. **One-window frames on the short fixture.** Visit `/cwd/short.txt`,
   `ensure-visible 220 54`, `page-down` until the point line is at
   least 800, `ensure-visible 220 54` again, and take that session's
   `editor`. Its text is focused at the point. Read the point's line
   and column once. For every `top` in: the point's line minus 52
   (point on the bottom row), the point's line (top row), the point's
   line minus 20, 0 (window wholly above the point), 900 (wholly
   below), and 940 (rows run past the last line, 970); every `left`
   in 0 and 5; every `columns` in 220 and 20; and `rows` 53:
   `((editor with-origin top left) frame columns 53)` equals the
   reference frame, and `(editor frame-rows columns 53 top left)`
   equals the reference rows. That is 24 frames and 24 row lists.
   Line 3's tab sits at index 10, so `left` 5 with `columns` 20 puts
   tabs inside the clip at `top` 0.
5. **Recorded equals unrecorded on the short fixture.** Visit
   `/cwd/short.txt`, `ensure-visible 220 54`, three `split-right`
   sends, then `other-window` until `((s fit-rect 220 54) columns)`
   is 109; stop and report if a split is refused or four sends do not
   reach 109. Keep two sessions from there, one that is never sent
   `record-pictures` and one that is sent `record-pictures 220 54`
   after every step, so its pictures carry from step to step as the
   runner's do. At each of these steps, `frame 220 54` on the recorded
   session equals `frame 220 54` on the plain one: at the first screen;
   deep, after `page-down` until the point line is at least 800 and
   `ensure-visible 220 54`; after one `move-down` and
   `ensure-visible 220 54`; after `insert "q"`; after `undo`. After
   the insert the frame contains `"q"`; after the undo it equals the
   frame from before the insert.

Items 4 and 5 stay in the suite through 001, where they cover the new
read at origins above, around, and below the focus.

Before the product edit, item 2 and every send of `safe-rows` fail,
because the method does not exist. That is the lock this file holds.
Items 1, 3, 4, and 5 pass on today's bytes and must still pass after
the edit.

### `tests/aloemacs/frame-time.rkt` (spec §8, short fixture)

Geometry is 220 columns by 54 rows. Every timed case starts from its
own session value under its own name. A session is a value, so
building one from another copies it; paging or sampling one never
moves another. Build these, in this order:

1. **One window:** visit `/cwd/short.txt`, then `ensure-visible 220 54`.
2. **First screen:** from one window, three `split-right` sends. If one
   is refused, stop and report it. The selected leaf stays where the
   splits leave it, at 27 columns.
3. **Widest leaf:** from the first screen, `other-window` until
   `((s fit-rect 220 54) columns)` is 109. If four sends do not reach
   a 109-column leaf, stop and report it.
4. **Four windows deep:** from the widest leaf, `page-down` until the
   point line is at least 800, then `ensure-visible 220 54`. Check
   that the selected view's `scroll-row` is greater than 700 and the
   other three views' `scroll-row` is 0. `window-pictures.rkt`'s
   `selected-scroll` and `unselected-at-top?` helpers show how to read
   them.
5. **One window deep:** from one window, the same paging and fit.
   Check that the point line is at least 800.

**Sample (spec §8.3).** For each timed case, bind its own name *t* to
a copy of the case's session, so the samples move that name and
nothing else, and prepare these four forms with `driver-prepare!`
before any sample:

```text
(define t (t handle-event "down"))
(define t (t ensure-visible 220 54))
(define t (t record-pictures 220 54))
(t frame 220 54)
```

Typechecking stays outside the interval. Run the prepared fit and the
prepared record once, untimed. One sample is those four prepared calls
in that order, timed as one interval with
`current-inexact-monotonic-milliseconds`. The clock covers the key,
fit, record, and frame. The key is the runner's own send,
`handle-event`, which tests the mouse prefix, disarms, and reaches
`move-down` through `handle-key` and the keymap.

Eleven samples per case. The median is the sixth after sorting
ascending. Send `(collect-garbage)` once before each group of samples.
Write the sampler to take a group of one or more timed names and
sample them in alternation, one sample of each per round, for eleven
rounds; 000 passes it three groups of one case each. 001 adds the
long fixture's cases as the second member of the deep groups.

**Cases and assertions (spec §8.4).** Three cases, each on the short
fixture, in this order and with these labels:

| Label | Session |
|---|---|
| `four windows, first screen` | first screen |
| `four windows, widest leaf deep, 971 lines` | four windows deep |
| `one window deep, 971 lines` | one window deep |

- `printf` every median with its label, passing or not, before its
  check.
- Every median is strictly under **30** ms. The failure message names
  the case and the median.
- No growth check in 000.

Today's editor is already under 30 ms alone on these three cases, so
the bar passes without the product edit; `frame-time-cells.rkt` is
the lock. The bar holds the key-repeat interval, which is the
charter's bar, and the margin below it is a review rule (see
**Acceptance**).

### `tests/aloemacs/window-pictures.rkt`

Delete from the comment line that begins `;; Timing bar.` to the end
of the file: the four `driver-prepare!` bindings, `median-ms`, `bar!`,
and the three bars with the `wide` and `single` sessions they build.
Change the header's second line so the two lines read:

```racket
;; aloemacs-window-pictures 000: recorded leaf rows paint the bytes a fresh
;; build paints. The timing bar is tests/aloemacs/frame-time.rkt.
```

Nothing else in the file changes. Its `require` line stays. Every
byte check stays and still passes.

## Verification and completion

From the project root, in this order:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-118.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/frame-time-cells.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/frame-time.rkt
```

Run `frame-time.rkt` by itself, as above, for the medians taken
alone. Then:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-pictures.rkt tests/aloemacs/safe-cells.rkt tests/aloemacs/safe-cell-scan.rkt tests/aloemacs/window-bars-one-view.rkt tests/aloemacs/mode-buttons-paint.rkt
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

The whole suite passes 3,094 tests today. After this slice it passes
those plus the two new files, with no failure. `-j 4` and `-y` are
required, and `TMPDIR=/tmp` is required for agent runs. The product
edit is in `.aloe` files only, so nothing needs `raco make`.

Report, with the result:

- the three medians from the run of `frame-time.rkt` alone, and
- the three medians printed by the whole-suite run.

Both sets are part of the result. Record them in the review. No hand
check in 000; spec §14's hand check closes the series after 001.

Stop for review. Do not start 001.

## Acceptance

- `tests/checkpoint-118.rkt` green before the edit.
- `frame-time-cells.rkt` green: `safe-cells`, `safe-rows`, and the
  padding match the reference, the law
  `(ed safe-rows rows)` = `(rows map (fn (row) (ed safe-cells row)))`
  holds on every listed list, the 24 one-window frames and 24 row
  lists match the reference painter, and the recorded four-window
  frames equal the unrecorded ones at all five steps.
- `frame-time.rkt` green: all three medians under 30 ms.
- **Every median alone is at most 15 ms** on the machine of the run
  (spec §8.5: half the bar, so a run under `-j 4` that doubles a
  frame still passes). A median alone above 15 ms fails the
  checkpoint, however green the suite. Report all three numbers and
  stop. Do not raise the bar, do not change the sample, do not touch
  `Text` or List. The designer measured 11.4 ms for the deep
  four-window case and 7.0 for one window with this edit alone.
- `window-pictures.rkt`, `safe-cells.rkt`, `safe-cell-scan.rkt`,
  `window-bars-one-view.rkt`, `mode-buttons-paint.rkt`, and
  `next-lines.rkt` green and unedited except for the deletion above.
- The whole suite green under `-j 4`. `git diff --check` clean.
- The working tree differs from the start of the slice in exactly
  `examples/aloemacs/editor.aloe`, `examples/aloemacs/file.aloe`,
  `tests/aloemacs/window-pictures.rkt`, and the two new test files.

## Non-goals

- `Text.lines-from`, `entries-after`, any edit to `lib/text.aloe`, or
  any change to how `frame-rows` and `frame` read lines (spec §6, 001).
  Both paths keep `focus-at` and `next-lines`.
- The long fixture, the last-page sessions, the paired deep cases, and
  the growth check (spec §8, 001).
- The hand check (spec §14) and the five consecutive whole-suite runs
  (spec §8.5), which close the series after 001.
- Routing the mode row, the echo row, the completion frame, or the
  search key through `safe-rows`. They keep sending `safe-cells`.
- A new String, Text, or List kernel message; a `Vector`; ropes or
  piece tables; any change under `aloe/`, `host/racket/`, or `lib/`.
- Reusing rows across a scroll, recorded rows for the one-window path,
  edit-aware reuse, an edit range, or a typing bar (spec §7.1, §11).
- Changing `AloemacsLeafPicture`, its key, or `record-pictures`.
- Key coalescing, the runner, the manifest runner, the Aloe-side loop,
  scroll regions, fewer terminal bytes.
- Joining rows with `joined-with` instead of `fold`, or any other
  change to frame assembly.
- Editing the spec, this folder's `README.md`, the parent map, or the
  closed documents of spec §12. Pointing those documents here is map
  work for the closing review.
