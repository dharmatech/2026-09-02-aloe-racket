# aloemacs frame time specification

**Status.** Written by the designer from [`charter.md`](charter.md) on
2026-10-18 and revised the same day after Grok's review, which is kept
verbatim in
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/grok-review.md`](../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/grok-review.md).
Awaiting human review. Not Aloe law. Not a checkpoint.
`SPEC.md` governs sends and types. The checkpoint manager reads this
file and need not read the charter. Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

A held Down keeps up. Deep in four windows of one buffer and deep in
one window, on a file as long as the editor's own source, a Down and
its frame take at most 11.9 ms alone at the worst place measured, under
half the 30 ms repeat interval. The bytes on screen stay the bytes
`frame` paints today.

Three repairs do it, all in Aloe, none in the kernel:

1. `spaces` and `fill` build their strings by doubling (§4).
2. `safe-cells` blanks each control it finds instead of walking every
   character. A leaf's clipped rows are checked as one block, and each
   row is blanked only for the controls the block holds (§5).
3. `Text` reads the visible lines straight from the zipper's two Lists,
   without moving the focus (§6).

Typing is not this series. §11 records what a typed character costs
before and after, and why the walk is still there.

## 1. Series

The identity is **aloemacs-frame-time**. Two checkpoints, spoken
**aloemacs-frame-time 000** and **aloemacs-frame-time 001**, filed under
`checkpoints/`. The manager writes one, stops, and writes the next only
after the human reviews the implementation of the one before. This is
not aloemacs-window-pictures 001, and it takes no global number.

| Checkpoint | File | Slice |
|---|---|---|
| **000** | `checkpoints/000-blank-by-find.md` | §4 and §5: doubled padding, `safe-cells` by `find`, `safe-rows` in both frame paths. The timing bar moves to `tests/aloemacs/frame-time.rkt` with a fixture that has tabs on screen |
| **001** | `checkpoints/001-read-visible-lines.md` | §6: `Text.lines-from` and both frame paths reading through it. The bar gains the long fixture, the last page, and the growth rule. The hand check and the `-j 4` check close the series |

There is no 002. §10 says what each holds and why there are two.

### 1.1 Precondition

Global checkpoint 118, the evaluator under the compile limit, landed in
`29c5103` on 18 October 2026. On today's tree `aloe/eval.rkt` compiles
whole. No checkpoint of this series goes to an implementer on a tree
without 118. Each checkpoint begins with
`TMPDIR=/tmp raco test -j 4 -y tests/checkpoint-118.rkt` green, and every
timing number it reports is taken on that tree.

## 2. Boundary and authority

The accepted specs and checkpoints of windows, mode-line, window-bars,
safe-cells, safe-cell-scan, window-pictures 000, window-point, mouse,
mode-buttons, split-drag, and completion paging define what is painted.
This series changes none of it. After clipping, codes 0–31 and 127
paint as one space and every other character is copied. The mode-line
spelling, the bars, the echo row, completion rows, and the cursor
address stay. A repair changes how bytes are computed, never which.

May change:

- `examples/aloemacs/editor.aloe`: `AloemacsEditor.safe-cells`'s body,
  four new `AloemacsEditor` methods (§5), and the read in `frame-rows`
  and `frame`
- `examples/aloemacs/file.aloe`: the bodies of
  `AloemacsWindowRect.spaces` and `AloemacsModeLine.fill`
- `lib/text.aloe`: two new `Text` methods (§6). Every existing message
  keeps its result. `next-lines` keeps its body
- `tests/aloemacs/`: three new files and the timing section of
  `window-pictures.rkt` (§8, §9)

Does not change: `aloe/`, `SPEC.md`, `lib/` outside `text.aloe`,
`host/racket/` (the runner stays `ensure-visible`, `record-pictures`,
the frame write, `handle-event`), `main.aloe`, Gel, `docs/editor/`, any
`define-class` list, any field, any constructor. No class is added, so
the tests that pin `file.aloe`'s ordered class list are untouched.

Recorded state does not change. `AloemacsLeafPicture`, its key, and
`record-pictures` stay as window-pictures 000 left them. Nothing new is
recorded between frames.

## 3. Where a deep Down goes today

Medians in ms, alone, on the record's machine (i9-10885H, Racket 9.3
CS), with 118 landed. The fixture is window-pictures' (line *n* is *n*,
a space, then `x` to 35 characters) at three lengths, 220×54, and the
test's procedure with eleven samples instead of five. **The clock covers
fit, record, and frame. The Down before each sample is outside it.**
A table below that says "the §3 procedure" is timed this way. "Deep" is
`page-down` to the first line at or past 800, which is 816, and then
the samples' Downs. "Last page" is the point within the last 120 lines
of the file.

| Lines | First screen, four windows | Four windows, 109-column leaf, deep | One window, deep | Four windows, last page | One window, last page |
|---:|---:|---:|---:|---:|---:|
| 971 | 2.7 | 23.2 | 14.3 | 23.0 | 14.5 |
| 2,400 | 2.6 | 26.9 | 18.4 | 27.5 | 18.7 |
| 5,000 | 2.7 | 34.6 | 26.1 | 34.8 | 26.2 |

These match the record's raised-limit rows. Two costs make them:

- **Per-character loops.** `safe-cells` sends about eight messages per
  character of every visible row, `pad-row` one `append` per padding
  space, and the mode line one per dash.
- **Reading by walking.** A frame sends `focus-at` from the point to
  the top row, then `next-lines` down again: about two zipper steps per
  row. Each step sends `rest` to one of `above` and `below` and `cons`
  to the other, and each of those copies its whole List. So each row
  costs the file's length, and the deep cases grow by about 3 ms per
  thousand lines.

## 4. Padding by doubling (charter §5.1 item 1)

`AloemacsWindowRect.spaces` and `AloemacsModeLine.fill` build half the
string, append it to itself, and add one more character when the count
is odd:

```aloe
(spaces (remaining Int) String
  (if (remaining <= 0)
      ""
      (let ((half (self spaces (remaining / 2))))
        (if (((remaining / 2) * 2) = remaining)
            (half append half)
            ((half append half) append " ")))))
```

`fill` is the same with `"-"`. `/` on two `Int` values is integer
division. The results are unchanged: `""` for a count of 0 or less,
otherwise exactly that many spaces or dashes. A count of *n* costs
about log₂ *n* levels instead of *n* sends. `pad-row`, `name-row`, and
`row` keep their bodies.

Measured reason: in the record, doubling alone took the deep
four-window case from 22.9 to 18.0 ms at 971 lines. After this series,
padding the 52 rows of the 109-column leaf is 1.7 ms of the sample
(§7.5).

## 5. Blank controls by find (charter §5.1 item 2)

### 5.1 `safe-cells`

`safe-cells` keeps its send, argument, result type, and rule. It now
walks the 33 controls instead of the characters. For each control in
`safe-cell-controls`, in order, it finds each occurrence from left to
right and puts one space in its place:

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

The result is the old one. A space is not a control, so a replacement
never makes a match for a later control. Each position is replaced at
most once, and the length is kept. A String with no control costs 33
`find` sends, whatever its length. Each control in it adds one `find`,
`take`, `drop`, and two `append` sends, and one copy of the whole
String. *k* controls in a String of length *n* copy about *k* × *n*
characters. That is why §5.2 blanks a row, never a whole leaf.

Every caller keeps sending `safe-cells`: the mode row in `built-rows`
and in `single-frame`, `echo-row`, `completion-frame`, and the search
key's `((self editor) safe-cells key)`. A one-character key now costs
33 `find` sends instead of one; that is microseconds, once per key.

### 5.2 `safe-rows`

`AloemacsEditor` gains:

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
block and keeps the ones it finds. A block with none returns the
clipped rows themselves. Otherwise each row goes through
`blank-controls` with only the present controls, so a row costs one
`find` per present control and each copy is one row long. A control
absent from the block is absent from every row, so for every
`(List String)`, `(editor safe-rows rows)` equals
`(rows map (fn (row) (editor safe-cells row)))`.

### 5.3 Where it is sent

`AloemacsEditor.frame-rows` and `AloemacsEditor.frame` clip each row as
today, `((line drop scroll-col) take columns)` and
`((line drop left) take columns)`, and send `safe-rows` to the list of
clipped rows instead of `safe-cells` to each. Nothing else in either
method changes in 000.

### 5.4 Measured reason

The record's prototype checked the joined block for the 33 controls and,
when one was there, walked every row a character at a time. Real files
have tabs. Without controls and with a tab on every seventh line, alone,
the §3 procedure, ms, four windows deep / one window deep:

| Lines | Fixture | Today | Record's block check (with §4) | §4 and §5 |
|---:|---|---:|---:|---:|
| 971 | no controls | 23.2 / 14.3 | 10.5 / 6.6 | 10.4 / 5.9 |
| 971 | tab every 7th line | 23.4 / 14.5 | 18.6 / 14.7 | 11.2 / 6.8 |
| 2,400 | no controls | 26.9 / 18.4 | 14.5 / 10.6 | 14.6 / 9.9 |
| 2,400 | tab every 7th line | 26.9 / 18.2 | 23.4 / 19.2 | 15.3 / 11.0 |

The last column is checkpoint 000's product edit alone. With a tab on
screen the record's check saves nothing in one window. §5 pays about
1 ms for the tabs.

Density matters as well as presence. `safe-rows` alone on one leaf,
medians of 5, ms. "Today" is `safe-cells` sent to each row. "Blank the
block" is this spec's first draft, `safe-cells` sent to the whole
joined block and the block cut back into rows; Grok's review of that
draft asked how it scales:

| Rows × columns | Controls | Today | Blank the block | §5.2 |
|---|---|---:|---:|---:|
| 52 × 109 | none | 25.7 | 1.6 | 1.6 |
| 52 × 109 | one tab per row | 25.7 | 2.9 | 2.6 |
| 52 × 109 | a tab every 7th character | 25.2 | 14.6 | 5.1 |
| 52 × 109 | every character a tab | 24.8 | 85.2 | 21.7 |
| 52 × 109 | every character a control, all 33 | 24.5 | 85.0 | 28.7 |
| 53 × 220 | one tab per row | 53.2 | 5.4 | 4.2 |
| 53 × 220 | every character a tab | 52.2 | 310 | 46.1 |
| 53 × 220 | every character a control, all 33 | 53.4 | 311 | 54.3 |

Blanking the block copies the whole block once per control, so a dense
leaf is quadratic in its size. §5.2 copies one row. On ordinary text it
is ten to fifteen times faster than today; at the densest mix it is
about a sixth slower than today, and never quadratic in the leaf.

## 6. Read the visible lines without moving the focus (charter §5.1 item 4)

### 6.1 `Text.lines-from`

`Text` gains:

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

The contract is exact on every well-formed `Text`: a `from-string`
text, or an `indexed` one whose `focus` is `(above len)`. Every `Text`
message builds only those. For every such *t*, `Int` *top*, and `Int`
*count*:

```aloe
(t lines-from top count)
=
((t focus-at top) case
  (None () (Option None))
  (Some (at) (Option Some (at next-lines count))))
```

`upper` lines come from `above`, nearest first, and the `fold` with
`cons` puts them in file order in front of `middle`. `here?` says
whether the focused line is in the window. `lower` lines come from
`below`, with `""` once it runs out. The last line of the text is
`focus + (below len)`. A hand-built `Text indexed` whose `focus` is not
`(above len)` is outside the contract: `focus-at` walks it and
`lines-from` does arithmetic on it, and they can disagree.

`lines-from` never sends `focus-up`, `focus-down`, or `focus-at`, and
never copies the List on the other side of the focus. Reading *k* lines
above the focus costs *k* `rest` sends to `above`, each a copy of
`above`; the same holds for `below`. A Down that scrolls puts the point
on the bottom row, so its whole window is `above` and the List below
the point is not touched: the read's cost follows the depth of the
point, not the length of the file. An Up that scrolls puts the point on
the top row and reads only `below`, so its cost follows the distance
from the point to the end. The key itself is apart from the read:
`move-down` sends `focus-down` once, which copies both Lists, the
whole file once per key.

### 6.2 Where it is read

`AloemacsEditor.frame-rows`:

```aloe
(frame-rows (columns Int) (rows Int) (scroll-row Int) (scroll-col Int)
            (List String)
  (((self text) lines-from scroll-row rows) case
    (None () (self blank-rows rows))
    (Some (lines)
      (self safe-rows
        (lines map (fn (line) ((line drop scroll-col) take columns)))))))
```

`AloemacsEditor.frame` keeps `((self text) focus-at (point line))` and
its `None` arm. In place of `(focused focus-at top)` and then
`(at-top next-lines rows)`, it sends `(focused lines-from top rows)`,
with the same `None` arm and the rows from `Some`. The `(rows < 1)`
check, the clipping, `safe-rows`, the `"\r\n"` fold, and `frame-ansi`
stay. On a text already focused at the point, as a Down leaves it,
`focus-at (point line)` returns at once.

`next-lines` stays on `Text` unchanged. `Text.excerpt` sends it and
`tests/aloemacs/next-lines.rkt` pins it. The editor no longer sends it.

### 6.3 Measured reason

§4 and §5 in place, alone, the §3 procedure, no controls, ms, four
windows deep / one window deep:

| Lines | Without §6 | With §6, deep | With §6, last page | With §6, held Up deep |
|---:|---:|---:|---:|---:|
| 971 | 10.4 / 5.9 | 8.3 / 3.7 | 8.3 / 3.8 | 7.2 / 2.7 |
| 2,400 | 14.6 / 9.9 | 8.3 / 3.7 | 10.5 / 6.0 | 9.4 / 4.8 |
| 5,000 | 22.5 / 18.1 | 8.2 / 3.6 | 14.4 / 10.0 | 13.4 / 9.0 |

"Held Up deep" times an Up, not a Down, with the point on the top row
of the view near line 800, so the window is all `below`. At the same depth a Down no
longer grows with the file. It grows with the depth of the point, about
1.5 ms per thousand lines in four windows and in one. Held Up grows the
same way with the distance from the point to the end.

## 7. Measured and not chosen

### 7.1 Reusing the selected leaf's rows across a scroll (charter item 3)

Not chosen. The floor it approaches is the four-window first screen,
where every picture is reused: 3.3 ms. In §8.3's sample it could take
about 6 ms off the deep four-window case and about 8.5 off the last
page, and nothing off one
window, which the charter keeps without recorded rows. It would add a
second way for a picture to match, rows shifted by a scroll, with its
own byte checks. The bar's margin holds without it.

### 7.2 One zipper walk from the point

The charter's own wording of item 4: walk up from the point to the top
row collecting lines, then down for the rest. Each step still sends
`focus-up` or `focus-down`, which copies both Lists, so each row still
costs the file's length. With §4 and the record's block check, alone:
8.7 / 4.7 ms at 971 lines, 10.5 / 6.6 at 2,400, 14.8 / 10.6 at 5,000.
§6 on the same base: 8.5 / 4.4, 8.4 / 4.3, 8.4 / 4.4.

### 7.3 A read through one joined String

Join a List into one String with `"\n"`, `find` the line feeds, `take`,
and `split-lines`. No line of a `Text` holds a line feed, so this reads
any run of entries in one native copy plus one `find` per line. With §4
and the record's block check it is flat: 7.0–8.0 ms in four windows
and 3.0–3.6 in one, deep and at the last page, at every length. Not
chosen:

- It is an indexed read built out of String sends. Charter §4.8 sends
  the indexed read to a language-spine discussion.
- Every frame copies the whole of `above` into a String to read 52
  lines.
- §6 meets the bar with margin and is what `first` and `rest` already
  say. If List `rest` becomes cheap, §6 becomes cheap with it.

It also moved typing, which §6 does not: a typed character in four
windows at line 817 was 24 ms at every length, and 39 ms at the last
page of 2,400 lines. That is evidence for the indexed-read discussion,
not a proposal here.

### 7.4 List steps

Out by charter §4.3. Not measured again.

### 7.5 What a sample spends after the series

Four windows, 2,400 lines, §8.1's tabbed fixture, the 109×52 leaf
rebuilt on each Down, medians of 21, ms. The sample row's clock covers
the key, fit, record, and frame; each other row times that piece alone:

| Piece | Deep (line 817) | Last page (line 2,347) |
|---|---:|---:|
| **Sample: key, fit, record, frame** | **9.1** | **11.7** |
| `record-pictures` (the selected leaf) | 6.3 | 8.8 |
| — `lines-from` 52 rows | 1.5 | 4.1 |
| — clipping | 0.5 | 0.5 |
| — `safe-rows` (a tab present, blanked per row) | 1.4 | 1.4 |
| — `pad-row` of 52 rows | 1.6 | 1.7 |
| — mode row and bar | 0.2 | 0.2 |
| `frame`, four pictures reused and joined | 2.1 | 2.3 |

One window: sample 4.7 ms deep and 7.2 at the last page; the mode row
0.23, the echo row 0.15.

## 8. The bar (charter §5.2)

The timing moves out of `tests/aloemacs/window-pictures.rkt`, whose
byte checks stay, into a new `tests/aloemacs/frame-time.rkt`. 000
writes it with the short fixture; 001 adds the long one. Checks run at
module top level, with no `module+ main`, so `raco test` runs them.

### 8.1 Fixtures

Line *n*, counting from 0, is the decimal text of *n*, one space, then
`x` up to 35 characters. When *n* mod 7 is 3, the character at index 10
is a tab (U+0009) in place of that `x`. Every 52-row window shows seven
or eight tabbed rows, so every timed leaf and every one-window frame
takes the per-row path of `safe-rows`.

- **Short:** 971 lines, window-pictures' length.
- **Long (001):** 2,400 lines. `examples/aloemacs/file.aloe` was 2,370
  lines on 18 October 2026.

Load them through the filesystem double the other session tests use,
as `/cwd/short.txt` and `/cwd/long.txt`, then load `main.aloe`,
`file.aloe`, `editor.aloe`, `lib/text.aloe`, and `lib/fs.aloe` as
`window-pictures.rkt` does.

### 8.2 Sessions

Geometry is 220 columns by 54 rows. Every timed case starts from its
own session value under its own name. A session is a value, so building
one from another copies it; paging or sampling one never moves another.
For each fixture, in this order:

1. **One window:** visit the fixture, then `ensure-visible 220 54`.
2. **First screen:** from one window, three `split-right` sends. If one
   is refused, stop and report it. The selected leaf stays where the
   splits leave it.
3. **Widest leaf:** from the first screen, `other-window` until
   `((s fit-rect 220 54) columns)` is 109. If four sends do not reach a
   109-column leaf, stop and report it.
4. **Four windows deep:** from the widest leaf, `page-down` until the
   point line is at least 800, then `ensure-visible 220 54`. Check that
   the selected `scroll-row` is greater than 700 and the other three
   are 0.
5. **One window deep:** from one window, the same paging and fit.
6. **Last page (001, long fixture only):** from each deep session, a new
   session paged until the point line is at least 2,300, then
   `ensure-visible 220 54`. Check that the point line is at most 2,388,
   so eleven Downs stay inside the last line, 2,399. The deep sessions
   stay at their depth.

The timed name for a case is bound to a copy of its session, so the
samples move that name and nothing else.

### 8.3 Sample and statistic

For each timed session, prepare with `driver-prepare!` before any
sample, under its own name *t*:

```text
(define t (t handle-event "down"))
(define t (t ensure-visible 220 54))
(define t (t record-pictures 220 54))
(t frame 220 54)
```

Typechecking stays outside the interval. Run the fit and the record once
untimed. One sample is those four calls in that order, timed as one
interval with `current-inexact-monotonic-milliseconds`. **The clock
covers the key, fit, record, and frame.** This is the normative sample;
§3's procedure is for comparison with the record only. The key is the
runner's own send, `handle-event`: it tests the mouse prefix, disarms,
and reaches `move-down` through `handle-key` and the keymap. A held key
pays for it on every repeat. The runner's two terminal-size reads and
its terminal write are the parts of a turn left out.

Eleven samples per case. The median is the sixth after sorting
ascending. Send `(collect-garbage)` once before each group of samples.
Cases named as a pair are sampled in alternation, one sample of each per
round for eleven rounds, so load during the suite falls on both alike.

### 8.4 Cases and assertions

| Case | Session | Checkpoint |
|---|---|---|
| four windows, first screen | short, first-screen session | 000 |
| four windows, widest leaf, deep | short | 000; paired with long in 001 |
| one window, deep | short | 000; paired with long in 001 |
| four windows, widest leaf, deep | long | 001 |
| one window, deep | long | 001 |
| four windows, widest leaf, last page | long | 001, paired with the next |
| one window, last page | long | 001 |

- Every median is strictly under **30** ms. The failure message names
  the case and the median.
- **Growth (001).** For each deep pair, the long median minus the short
  median is strictly under **1.5** ms. At the same depth the read takes
  nothing from the file below the point. The key still copies the whole
  file once (§6.1), a few hundredths of a millisecond more at 2,400
  lines than at 971.
- `printf` every median and both growths, passing or not.

The deep cases may grow with the depth of the point, at about the rate
§6.3 measures, and the last-page cases hold that growth to the 30 ms
bar. They may not grow with the length of the file. A read that again
walks the zipper per row would add about 1.9 ms between the fixtures
for one step per row and 4 ms for today's two.

What the suite holds and what review holds:

- The 30 ms bars hold the key-repeat interval, the charter's bar. Today's
  editor is already under 30 ms alone on every case 000 times (about 23
  ms deep at 971 lines), so 000's timing checks pass without its
  product change. 000's byte checks do not: `safe-rows` does not exist
  today.
- The growth check, from 001, is what the suite holds against a read
  that walks the zipper per row. The last page has no short twin, and
  today's walk is under 30 ms there too (27.5 ms), so the deep pair
  carries that lock.
- The design margin is a review rule, not a test. After the series a
  later change could slide a Down from 9 ms toward 25 and the suite
  would stay green; the printed medians would show it.

### 8.5 Margin and how the human checks it

Designed to: every Down median at most **15 ms alone** on the record's
machine, half the bar, so a run under `-j 4` that doubles a frame still
passes. The record saw the old bar slow by up to 1.5× under `-j 4`. The
worst Down median measured alone is 11.9 ms after 001, four windows at
the last page of 2,400 lines, and 11.4 ms after 000 alone, four windows
deep at 971 lines. The growth bound is about ten times the largest
difference measured, alone or under load.

A scratch copy with both checkpoints' product edits and the draft tests
measured, alone, in two runs of `frame-time.rkt`: first screen 3.3,
deep four windows 9.2–9.3, deep one window 4.8–4.9, last page 11.9 and
7.1, growths 0.01 to 0.15 ms. In five consecutive
`TMPDIR=/tmp raco test -j 4 -y tests` runs of that copy, 3,806 tests
each, green but for the copy's collection-path failure (§13): first
screen 3.3–3.5, deep four windows 9.4–10.3, deep one window 5.0–5.6,
last page four windows 12.1–13.6, last page one window 7.4–8.3,
growths −0.06 to 0.13 ms.

Each checkpoint reports its medians alone and from its whole-suite run.
A Down median alone above 15 ms fails the checkpoint, however green the
suite: report it and stop, and do not raise the bar. After 001, the
human runs `TMPDIR=/tmp raco test -j 4 -y tests` five times in a row;
every run is green with no rerun, and the five runs' printed medians are
recorded with the review.

## 9. Byte checks

Each checkpoint has its own file. Every existing frame golden stays.
Compare whole strings or whole `List`s, never a substring alone.

The reference painter is Racket in the test file, not Aloe. For a line
list, an origin `top`, `left`, and a size `columns` × `rows`: take lines
`top` through `top + rows − 1`, `""` past the end; drop the first
`left` characters (all of a shorter line); keep the first `columns`;
replace every character whose code is below 32 or is 127 with a space.
Those are the rows. The editor frame is
`"\e[?25l\e[2J\e[H"`, the rows joined with `"\r\n"`, then
`"\e[" (point line − top + 1) ";" (point column − left + 1) "H\e[?25h"`.

### 9.1 000: `tests/aloemacs/frame-time-cells.rkt`

1. **`safe-cells` against the reference rule.** `""`; each of the 33
   controls alone; the 33 in order; `"a\tb"`; `"\e[31m"`; printable
   ASCII 32–126 as one String; `"é↕↔×"`; a 300-character String with
   controls at 0, 150, and 299 and the runs `"\t\t\t"` and `"\r\n"`; a
   String of only controls with repeats. Each result equals the
   reference and has the argument's length.
2. **`safe-rows`.** For `(List empty)`; `(List of "")`; three empty
   rows; clean rows of lengths 0, 1, 35, and 109 (the result is the
   same rows); a control as the first character of the first row; a
   control as the last character of the last row; a row of only
   controls; an empty row between two dirty rows; two rows that hold
   different controls; a 109-character row of every control in turn.
   Each result equals the reference applied per row, and equals
   `(rows map (fn (row) (editor safe-cells row)))`.
3. **Padding.** For every count from −2 through 300,
   `((AloemacsWindowRect new 0 0 109 53) spaces n)` is that many spaces
   (none at or below 0), and `((AloemacsModeLine new) fill n)` that many
   dashes.
4. **One-window frames on the short fixture.** Take the deep one-window
   session's editor (point at or past line 800, text focused there). For each origin,
   `((editor with-origin top left) frame columns rows)` equals the
   reference frame: `top` at the point's line minus 52 (point on the
   bottom row), at the point's line (top row), at the point's line minus
   20, at 0 (window wholly above the point), at 900 (wholly below), and
   at 940 (rows run past the last line, 970); `left` 0 and 5; `columns`
   220 and 20; `rows` 53. The same origins through
   `(editor frame-rows columns 53 top left)` equal the reference rows.
5. **Recorded equals unrecorded on the short fixture.** Four windows,
   widest leaf: at the first screen; deep; after one `move-down` and
   `ensure-visible 220 54`; after `insert "q"`; after `undo`. At each
   step, `frame 220 54` after `record-pictures 220 54` equals
   `frame 220 54` on the same steps with no record. After the insert the
   frame contains the `q`; after the undo it equals the pre-insert
   frame.

Items 4 and 5 stay in the suite through 001, where they cover the new
read at origins above, around, and below the focus.

### 9.2 001: `tests/aloemacs/frame-time-lines.rkt`

1. **The contract of §6.1, exhaustively on small texts.** For each of
   `""`, `"a"`, `"a\n\nc"`, `"0\n1\n2\n3\n4\n"`, and `"\n\n"`: the
   `from-string` text, and the indexed text focused at every line; `top`
   from −1 through the line count plus 1; `count` from −1 through the
   line count plus 2. `(t lines-from top count)` equals the
   `focus-at`-then-`next-lines` expression of §6.1 under `check`. The
   scratch copy ran 1,018 such checks.
2. **Recorded equals unrecorded on the long fixture.** §9.1 item 5,
   deep, again on 2,400 lines.

## 10. Checkpoints (charter §5.3)

Two, because each pays off alone and each fits one implementer.

**000 — Blank controls by find.** §4, §5, §8 with the short fixture,
§9.1.

- Product: `editor.aloe` (`safe-cells` body; `blank-controls`,
  `blank-from`, `safe-rows`, `controls-in`; `frame-rows` and `frame`
  send `safe-rows` to their clipped rows and keep `focus-at` and
  `next-lines`), `file.aloe` (`spaces` and `fill` bodies).
- Tests: `frame-time-cells.rkt` and `frame-time.rkt`, both new. In
  `window-pictures.rkt`, delete the timing section, from the comment
  `;; Timing bar.` to the end, and the header's clause about the repeat
  interval. Its byte checks stay as they are.
- Evidence: the three medians alone and from one whole-suite run. In
  the scratch copy, 000's product edit alone, with the clock of §8.3
  and a tab on every seventh line, gave 11.4 / 7.0 ms deep at 971
  lines.
- Acceptance: every median alone under 15 ms. One above 15 fails the
  checkpoint, however green the suite (§8.4, §8.5).
- Pays off alone: with the §3 procedure at 971 lines, the deep medians
  drop from 23.2 / 14.3 ms to 10.4 / 5.9 without controls, and from
  23.4 / 14.5 to 11.2 / 6.8 with tabs.

**001 — Read the visible lines.** §6, the rest of §8, §9.2, the hand
check (§14), the five-run check (§8.5).

- Product: `lib/text.aloe` (`lines-from`, `entries-after`),
  `editor.aloe` (`frame-rows` and `frame` read through `lines-from`).
- Tests: `frame-time-lines.rkt`, new; `frame-time.rkt` gains the long
  fixture, the pairs, the last page, and the growth checks.
- Acceptance: as 000, every median alone under 15 ms, and the growth
  checks green.
- Pays off alone: the deep cases stop growing with the file. At 2,400
  lines with the clock of §8.3 and tabs, they go from 15.7 / 11.2 ms
  after 000 to 9.2 / 4.9.

One checkpoint would carry both product changes across three files,
three new test files, and the bar's whole design. §6 also needs the
long fixture to show anything, and 000 is worth reviewing before 001
changes how every frame reads.

## 11. Typing: the walk this series leaves in place (charter §4.8)

A typed character changes the buffer's history length, so every leaf
of that buffer misses its picture. Each other leaf then reads from the
cursor back to its own scroll row. Today that read is the zipper walk:
per line of distance, one copy of each List, the whole file between
them. After §6 it is
`entries-after` skipping `above`: one copy of `above` per line of
distance, each shorter than the last. It is still a walk, still grows
with the distance, and still pays it on every edit, undo, and visit.

Four windows of one buffer, three unselected leaves at scroll 0, one
typed character with the key inside the interval, ms:

| Lines | Cursor | Today | After the series |
|---:|---|---:|---:|
| 971 | line 817 | 140 | 53 |
| 2,400 | line 817 | 246 | 54 |
| 5,000 | line 817 | 440 | 52 |
| 2,400 | last page | 561 | 266 |
| 5,000 | last page | 2,247 | 1,137 |

One window, line 817: 14.6, 18.4, and 26.2 ms today at the three
lengths; 3.8 after. There is no timing bar for typing, no edit-aware
reuse, and no edit range here. §9 covers edits for bytes. The repair
stays with the language-spine discussion of indexed read and slicing
for List that the charter names. §7.3 is evidence for it.

## 12. Closed documents (charter §5.4)

These stay unedited. Each still governs what it says is painted; this
spec is where the current computation is described.

| Document | Still governs | Superseded in method by |
|---|---|---|
| [`../safe-cells/spec.md`](../safe-cells/spec.md) | The display rule and its sites: §4's send, type, and per-character rule, §5, §6 | §5.1: `safe-cells` finds each control. §4's left-to-right walk and its 33 comparisons describe how it was first written |
| [`../safe-cell-scan/checkpoints/000-find-control-string.md`](../safe-cell-scan/checkpoints/000-find-control-string.md) | `tests/aloemacs/safe-cell-scan.rkt` and its 80 ms bar, which stay | §5.1 replaces the body it wrote and does what its non-goals left out |
| [`../safe-cell-controls/checkpoints/000-name-control-string.md`](../safe-cell-controls/checkpoints/000-name-control-string.md) | `safe-cell-controls`, still the one string of the 33 controls | §5.1 reads it a control at a time |
| [`../viewport-top/checkpoints/000-use-focus-at.md`](../viewport-top/checkpoints/000-use-focus-at.md) | The frame paints from the stored `scroll-row` | §6.2: `frame` reads that row through `lines-from`, not `(focused focus-at top)` |
| [`../next-lines/checkpoints/000-text-next-lines.md`](../next-lines/checkpoints/000-text-next-lines.md) | `Text.next-lines`, which stays | §6.2: neither frame path sends it |
| [`../window-pictures/checkpoints/000-reuse-leaf-rows.md`](../window-pictures/checkpoints/000-reuse-leaf-rows.md) | Pictures, their key, `record-pictures`, and the byte checks in `window-pictures.rkt` | §8: the timing bar now lives in `frame-time.rkt`. Its non-goal on the `safe-cells` walk is §5's work; `focus-at` and `focus-down` are still unchanged |

When the series closes, the parent map's frame-time row and these
folders' `README.md` files may point here. That is map work for the
closing review, not a checkpoint's edit.

## 13. Scratch-run inventory (charter §6)

The product edits were applied to an `rsync` copy of `29c5103` and the
whole suite was run with `PLTCOLLECTS` pointed at the copy.

- **000's product edit alone:** 3,094 tests, one failure,
  `tests/editor/lsp/009-launch.rkt:359`. That file fails in any copy
  run with that override and passes alone without it.
- **000 and 001's product edits:** the same: 3,094 tests, the same one
  failure, which passes alone.

Both runs used the revised §5.2. No existing test file fails, so there
is no migration. `window-pictures.rkt` changes because its bar moves,
not because it fails. No constructor, field, or class list changes.
With the draft `frame-time.rkt` and `frame-time-cells.rkt` added, the
prototype's `tests/aloemacs/` passed 1,382 tests and the whole suite
3,806.

The probes and the prototype diff are in
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/`](../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/designer/).

## 14. Hand check (charter §3.6)

After 001 is green, on a real terminal. The edit is in `.aloe` files
only, so no rebuild is needed.

```sh
racket host/racket/aloemacs-run.rkt examples/aloemacs/file.aloe
```

1. `C-x 3` three times. `C-x o` until the widest window is selected.
2. Page Down past line 800.
3. Hold Down for a few seconds, then release. The cursor stops with the
   key: no lines scroll after the release.
4. `C-x 0` until one window is left. Page Down past line 800 if needed,
   and repeat step 3.

## 15. Non-goals

- Held typing, edit-aware row reuse, an edit range, and a typing timing
  bar (§11)
- Recorded rows for the one-window path; reusing rows across a scroll
  (§7.1)
- An indexed read, slicing, or cheaper `cons` and `rest` for List, in
  the kernel or emulated with String sends (§7.3)
- Any change under `aloe/`, `SPEC.md`, `host/racket/`, or `lib/` outside
  `text.aloe`; a new String or Text kernel message; a `Vector`; ropes or
  piece tables
- Key coalescing, the runner, the manifest runner, the Aloe-side loop
- Fewer terminal bytes, scroll regions, cursor-only writes
- Joining rows with `joined-with` instead of `fold`, or any other change
  to frame assembly (§7.5: 2.2 ms)
- Syntax colors, `wcwidth`, wrapping
- Startup, visit, save, and LSP latency
