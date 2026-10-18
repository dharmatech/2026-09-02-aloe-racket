# Aloemacs frame time

Record of measurements taken on 18 October 2026 on
`experiment/2026-10-16-host-queries` at `21d1a36`. This file is evidence.
It is not a charter, not a specification, and not a decision to change
the editor. No product code was edited. The work it led to is
[`docs/design/implementation/aloemacs/frame-time/charter.md`](../../../docs/design/implementation/aloemacs/frame-time/charter.md)
and, on the language spine,
[`docs/evaluator-compile-limit-brief.md`](../../../docs/evaluator-compile-limit-brief.md).

## The question

`tests/aloemacs/window-pictures.rkt` times one held Down as three
medians against a 30 ms bar, the keyboard repeat interval on the machine
behind aloemacs-window-pictures 000. Run alone on 18 October they were
3.3 ms for four windows on the first screen, 28.9 ms for four windows
with the widest leaf deep, and 18.1 ms for one window deep. Under
`raco test -j 4` the deep four-window case failed in nearly every suite
run of the week before, at 30.5 to 42.2 ms, and implementers reran the
file alone to call the suite green. When window-pictures 000 landed on
9 October the two deep medians were 23.6 and 14.9 ms.

Machine: Intel i9-10885H, 16 hardware threads, 61 GB, Linux, Racket 9.3
CS. Every number below was taken with nothing else running, unless it
says `-j 4`.

## 1. The growth since 9 October is one evaluator commit

`bisect.sh` extracted eleven commits with `git archive`, compiled each
commit's own `window-pictures.rkt`, and ran them alone, round-robin, five
rounds. Each cell is the median of the five rounds, in milliseconds.

| Commit | Date | Subject | First | Wide deep | One deep |
|---|---|---|---:|---:|---:|
| `062f8c6` | 10-09 | Reuse unchanged Aloemacs leaf rows | 2.3 | 22.1 | 14.2 |
| `d8d7ebc` | 10-10 | Give each Aloemacs window its own point | 2.2 | 22.2 | 14.3 |
| `bf1d1e8` | 10-11 | Add split weights to Aloemacs windows | 2.6 | 22.6 | 14.4 |
| `40344c3` | 10-11 | Drag the mode line in Aloemacs | 2.6 | 22.8 | 14.4 |
| `5d435a5` | 10-13 | Run each loaded path once per base | 2.6 | 23.0 | 14.5 |
| `0f026a6` | 10-13 | Install Option on the base | 2.6 | 22.6 | 14.2 |
| `1ab41bb` | 10-13 | Select overloads by class and protocol record | 2.6 | 22.2 | 13.9 |
| `f1311a9` | 10-14 | Walk the cache, the file, and the prompt for conformance | 2.7 | 23.1 | 14.5 |
| `0e20fae` | 10-14 | Give each loaded file its own environment and copy its names | **3.2** | **27.9** | **17.7** |
| `87c0844` | 10-15 | Record the spans of class names … | 3.2 | 27.4 | 17.5 |
| `21d1a36` | 10-17 | (this branch's tip) | 3.2 | 27.6 | 17.6 |

The editor commits from 10 to 11 October add under 1 ms. The modules
series is flat until `0e20fae`, which moves all three medians by about
20 percent at once.

### Why that commit

Racket CS compiles a module body to machine code as one unit only when
it is smaller than `PLT_CS_COMPILE_LIMIT`, 10,000 terms by default. A
larger body is compiled in interpretable mode: each procedure is still
machine code, but calls between the module's own procedures go through
variables, and nothing is inlined across them. `0e20fae` added 39 lines
to `aloe/eval.rkt`, from 1871 to 1910.

- Recompiling only `eval.rkt` at a range of limits: at `f1311a9` it
  compiles whole at 10,000 and not at 9,500. At `21d1a36` it compiles
  whole at 10,500 and not at 10,000. It sat just under the limit and
  now sits just over it.
- The profiler shows the loss directly. `List rest` of 971 Strings
  spends its time in `make-list-value`. At `f1311a9`,
  `same-runtime-type?` is inlined there and has no frame of its own. At
  `0e20fae` it is a separate frame with 16 percent of the samples. One
  such `rest` went from 26 to 42 µs. `focus-down` on a 971-line `Text`
  went from 30 to 48 µs.
- It is not garbage collection: GC was 1 to 2 ms of each 130 to 240 ms
  loop, and memory use was the same.
- `interp-check.sh` compiles every `aloe/` module with
  `PLT_LINKLET_SHOW_POST_INTERP=1` and names the module bodies that take
  the interpretable path. At `21d1a36` they are `eval` and `type`. At
  `f1311a9` no named module does. At a limit of 8,000 the list is still
  `eval` and `type`. `type.rkt` is the checker. `driver-prepare!`
  checks each timed form once before the samples, so it is outside
  every interval in this record.
- With `eval.rkt` alone recompiled at a limit of 1,000,000, `21d1a36`
  runs the test at 2.6, 22.8, and 14.1 ms, three rounds. With the whole
  tree recompiled that way, 2.7, 23.2, and 14.4 ms. That is the
  `f1311a9` speed.

Every Aloe program runs on that module, not only the editor.

## 2. Where a deep frame goes

`frame-pieces.rkt` at `21d1a36`, default limit, 971-line fixture, 220×54,
medians of 21 runs of each piece as one prepared thunk.

### Four windows, the 109-column leaf deep

Point at line 817, selected scroll 766, leaf 109 columns by 52 text rows.
The other three leaves are at scroll 0 and their pictures match. Each
sample rebuilds the selected leaf.

| Piece | ms |
|---|---:|
| **Sample: fit, record, frame** | **27.4** |
| Fit (`ensure-visible`) | 0.3 |
| `record-pictures` | 24.6 |
| — `built-rows` of the selected leaf | 24.1 |
| —— `safe-cells` on 52 clipped rows | 9.5 |
| —— `pad-row` of 52 rows to 109 columns | 7.4 |
| —— `next-lines 52` | 3.0 |
| —— `focus-at` the scroll row from the point (51 steps) | 2.6 |
| —— mode-line row, its safe cells, and the bar | 0.7 |
| —— `drop` and `take` | 0.6 |
| `frame` (four pictures reused, then joined) | 2.4 |
| — `frame-rows` over the tree | 1.4 |
| — joining 53 rows | 0.3 |

### One window deep

Point at line 817, scroll 766, 53 text rows at 220 columns.

| Piece | ms |
|---|---:|
| **Sample: fit, record, frame** | **17.6** |
| `AloemacsEditor.frame` | 16.2 |
| — `safe-cells` on 53 rows | 9.8 |
| — `next-lines 53` | 3.1 |
| — `focus-at` the top from the point (51 steps) | 2.6 |
| — `drop` and `take` | 0.6 |
| — joining | 0.2 |
| mode-line row, its safe cells, and the bar, 220 columns | 1.5 |
| fit and record | 0.1 |

### Unit costs

| Send | ms |
|---|---:|
| One `focus-down` on the 971-line `Text` | 0.05 |
| `List rest` of 971 Strings | 0.04 |
| `List cons` onto 971 Strings | 0.04 |
| `safe-cells` of one 35-character line | 0.17 |
| `pad-row` of one 35-character line to 109 columns | 0.13 |

Three kinds of cost, then:

- **Per-character Aloe loops.** `safe-cells` walks one character at a
  time (`take 1`, `find`, `drop 1`, `append`). `pad-row` builds its
  padding with `spaces`, one `" "` per send, and the mode line builds its
  dashes with `fill` the same way. Together these are 17.6 of the 24.1 ms
  leaf rebuild and 11.3 of the 17.6 ms one-window frame.
- **Zipper steps.** `focus-up` and `focus-down` send `cons` and `rest` to
  the `above` and `below` Lists. Each send copies every element into a
  new vector and recomputes the element type of every element. A frame
  walks from the point to the top row and then `next-lines` down again,
  about two steps per text row, and each step costs time in proportion to
  the file's length. 5.6 ms of the four-window sample and 5.7 ms of the
  one-window sample.
- **Assembly.** Joining the leaves, the vertical bars, the echo row, and
  the cursor sequence: about 2.4 ms with four windows.

## 3. File length

The same test with the fixture's 971 replaced by 2,400 (about the length
of `examples/aloemacs/file.aloe`, 2,370 lines) and 5,000. Medians of
three alone runs.

| Tree | Lines | First | Wide deep | One deep |
|---|---:|---:|---:|---:|
| `21d1a36` | 971 | 3.3 | 27.8 | 17.6 |
| `21d1a36` | 2,400 | 3.2 | 34.2 | 24.1 |
| `21d1a36` | 5,000 | 3.3 | 47.2 | 36.9 |
| `21d1a36`, limit raised | 971 | 2.6 | 22.9 | 14.2 |
| `21d1a36`, limit raised | 2,400 | 2.6 | 27.2 | 18.2 |
| `21d1a36`, limit raised | 5,000 | 2.7 | 35.1 | 26.6 |

Both deep cases grow by about 3 ms per thousand lines with the limit
raised, and about 5 ms per thousand without. On a file the size of
`file.aloe`, the wide case already fails the bar alone.

## 4. A typed key

`frame-pieces.rkt` also times one key, then fit, record, and frame, as
one interval. The key is inside the interval here, unlike the test's
samples. Medians of seven.

| Tree | Lines | Down, four windows | Down, one window | Typed character, four windows | Typed character, one window |
|---|---:|---:|---:|---:|---:|
| `21d1a36` | 971 | 27.8 | 17.8 | **197.9** | 17.8 |
| `21d1a36`, limit raised | 971 | 23.2 | 14.6 | 141.2 | 14.7 |
| `21d1a36`, limit raised | 5,000 | 35.4 | 26.3 | 438.3 | 26.5 |

A typed character changes the buffer's history length, so every leaf of
that buffer misses its picture. Each unselected leaf then walks the
shared `Text` from the cursor, near line 817, back to its own scroll row
of 0, as aloemacs-window-pictures 000 predicted and left in place. The
timing test does not measure this case.

## 5. Prototypes

Three changes were tried in scratch copies on top of `21d1a36` with
`eval.rkt` compiled whole. [`prototype.diff`](prototype.diff) holds all
three. They are probes, not proposals.

- **Doubled padding** (`file.aloe` only). `spaces` and `fill` build half
  the string, append it to itself, and add one character when the count
  is odd. Log *n* sends instead of *n*.
- **Block control check** (`editor.aloe` only). Before the per-row
  `safe-cells` walk, join the clipped rows with `joined-with` and `find`
  each of the 33 control characters in that one String. When none is
  there, the clipped rows are the safe rows. Otherwise walk each row as
  today. Applied in `frame-rows` and in `AloemacsEditor.frame`.
- **List steps** (`aloe/eval.rkt` only). `rest`, and `cons` of an
  element of the List's own type, keep the known element type and copy
  the vector once instead of rebuilding a Racket list and retyping every
  element. A List whose element type is a protocol, or a `cons` of
  another type, takes today's path.

Medians in ms, three alone runs, all with `eval.rkt` compiled whole.

| Variant | Lines | Wide deep | One deep | Typed character, four windows |
|---|---:|---:|---:|---:|
| Limit raised only | 971 | 22.9 | 14.2 | 141 |
| + doubled padding | 971 | 18.0 | 13.9 | |
| + block check, `frame-rows` only | 971 | 15.6 | — | |
| + List steps | 971 | 21.8 | 12.8 | 81 |
| All three | 971 | 7.9 | 4.2 | 46 |
| Limit raised only | 5,000 | 35.1 | 26.6 | 438 |
| + List steps | 5,000 | 22.7 | 14.3 | 128 |
| All three | 5,000 | 9.6 | 5.7 | 88 |

The first-screen median stayed between 2.4 and 2.8 ms in every variant.
The one-window number for the block check alone is missing because that
copy patched only `frame-rows`.

With all three in place, the whole suite ran 3,138 tests under
`raco test -j 4 -y` (3,092 in the tree, plus 46 checks from the 2,400-
and 5,000-line copies of the timing test). Six failed, all in
`tests/editor/host-queries/001-manifest-reader.rkt` and
`002-lsp-hosts.rkt`, which load host modules by collection path and so
reach the original checkout from a copy. An unmodified copy of
`21d1a36` run the same way failed those six and the wide deep bar of
`window-pictures.rkt`, at 34.1 ms. Every aloemacs frame golden passed in
both. Under that `-j 4` run the timing medians were 2.7 to 2.8 ms
(first screen), 8.6 to 10.4 ms (wide deep), and 4.5 to 6.5 ms (one
deep), across the three fixture sizes.

A typed character in four windows stays at 46 ms even with all three.
What remains is the walk from the cursor to each unselected origin.

## What the numbers say

The deep medians grew from 23.6 and 14.9 ms to 28.9 and 18.1 ms because
`aloe/eval.rkt` crossed Racket CS's compile limit on 14 October, not
because the editor grew. The evaluator runs every Aloe program, and the
editor's frames lost about 20 percent to it. That repair belongs to the
language spine and is mechanical.

Under the regression, a deep frame is two-thirds per-character Aloe
loops in `safe-cells`, `spaces`, and `fill`. A fifth is zipper steps,
which copy the whole file on every step and so grow with file length.
Editor-only changes to the loops, together with cheaper List steps,
brought both deep Down cases to under a third of the bar at 5,000 lines
alone, and to about a third under `-j 4`. They did not bring a typed
character in four windows under the bar. Today that case is 198 ms,
and nothing in the suite measures it.

## Probes in this folder

Scratch programs, not tests. The Racket probe's effects are in a `main`
submodule, so `raco test` runs nothing. It loads the repository from
this folder by default, or another tree named on the command line.

| File | What it measures | Run |
|---|---|---|
| [`frame-pieces.rkt`](frame-pieces.rkt) | the tables in sections 2 and 4 | `racket frame-pieces.rkt`, or `racket frame-pieces.rkt <tree> 5000` |
| [`bisect.sh`](bisect.sh) | section 1: each commit's own timing test, alone, round-robin | `./bisect.sh <work-dir> 5 062f8c6 … 21d1a36` |
| [`interp-check.sh`](interp-check.sh) | which `aloe/` module bodies compile in interpretable mode | `./interp-check.sh <work-dir> [limit]` |
| [`prototype.diff`](prototype.diff) | the three changes in section 5, against `21d1a36` | read it, or `git apply` in a copy |

To reproduce a raised-limit row, recompile `eval.rkt` in a copy:
`rm aloe/compiled/eval_rkt.*` then
`PLT_CS_COMPILE_LIMIT=1000000 raco make aloe/eval.rkt` inside that copy.
