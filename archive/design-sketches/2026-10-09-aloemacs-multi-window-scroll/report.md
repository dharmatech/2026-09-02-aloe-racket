# Multi-window scrolling

Record of a measurement taken on 9 October 2026. Four vertical Aloemacs windows fall behind a held Down key. One window does not. This file is the investigation. It is not a charter, not a specification, and not a decision to change the editor. No product code was edited.

The session under test was the working tree of this repository, run the way the screenshot was run:

```text
racket ./host/racket/aloemacs-run.rkt /tmp/aloemacs-all.aloe
```

The open file is 971 lines and 34,820 bytes. The average line is 35 characters, the longest is 203, and 90 lines are blank. 792 lines are 53 characters or shorter. It begins with the text of `examples/aloemacs/editor.aloe`.

## What was slow

One window keeps up with a held Down key. The cursor stops when the key is released, including while the window is scrolling. Four vertical windows of that same buffer do not. After the key is released the cursor keeps moving, and once the file is scrolling the motion continues for a noticeable time.

On this machine the keyboard starts repeating after 500 ms and then repeats about every 30 ms (`org.gnome.desktop.peripherals.keyboard` delay 500, repeat-interval 30; `xset` reports a repeat rate of 33). The runner in `host/racket/aloemacs-run.rkt` does three steps per key, and the third step reads exactly one key:

1. `ensure-visible` for the current terminal size
2. build the frame and write it
3. `handle-key` of one `term read-key`

`read-next-key` in `host/racket/term.rkt` returns one key event. Repeats that arrive while a frame is being built stay in the terminal queue. Each queued Down is then handled on its own, after another full frame. The cursor keeps moving because those keypresses are still waiting, and each one still costs a redraw.

A frame that takes longer than 30 ms falls behind. The leftover after a hold of T milliseconds is about `T/30 − T/frame` keys, and draining that leftover takes that many frames.

## How it was measured

The timer loaded `examples/aloemacs/main.aloe` through the Racket driver, injected the production filesystem host, and visited `/tmp/aloemacs-all.aloe`. Visit already stores an indexed `Text`, so the samples are not paying `split-lines` on every frame.

Each sample is a `driver-prepare!` thunk, so typechecking is outside the number, then `time-apply`. The session-frame numbers below are the median of five runs. Minimum and median stayed within a few milliseconds of each other. Garbage-collection time inside those samples was 0 ms except at the deepest four-window frames, where the median GC time was 1 ms. The cost is steady work per frame.

The timed call is `(session frame columns rows)`. It does not include the terminal write. A one-window frame at 220×54 is about 1.8 KB. A four-window frame is about 12 KB. The gap between 11 ms and 54 ms is in building those strings.

Four equal columns came from `split-right` and `other-window`, refitting after each split. At 220×54 the leaves were 55, 54, 54, and 54 columns. The selected window ended as the rightmost. The screenshot has the cursor in the second column. The cost is the same shape either way: one window tracks the cursor, and the other three keep the scroll they had at the split.

The one-window session is the same buffer before those splits. Both sessions were moved to the same line with `page-down` or `down`, then `ensure-visible`, and the frame was timed there. Vertical windows share the full height, so both layouts had 52 text rows at 220×54 and started scrolling at the same cursor line.

A second geometry, 160×48, split into columns of about 40. It is reported at the end. The 220×54 run is the one that matches the screenshot: each column shows about 55 characters of the long `\u0000…` line.

## Frame time

Milliseconds to build one frame. The 30 ms repeat is the budget.

| Cursor line | One window | Four windows | After a 2 s hold |
| ---: | ---: | ---: | --- |
| 0 | 11 | 54 | about 30 keys left, 1.6 s more motion |
| 40 | 12 | 57 | about 32 keys, 1.8 s |
| 120 | 14 | 66 | about 36 keys, 2.4 s |
| 400 | 14 | 100 | about 47 keys, 4.7 s |
| 800 | 12 | 136 | about 52 keys, 7.1 s |

Line 40 is the screenshot. The cursor is still on the first screen, every window still shows the top of the file, and four windows are already at 57 ms. One window stays near 12 ms at every depth, so a release stops it immediately. Four windows are over budget before scrolling starts, and the leftover grows as the cursor moves down.

At 160×48 the same pattern is smaller and still over budget:

| Cursor line | One window | Four windows |
| ---: | ---: | ---: |
| 0 | 9 | 39 |
| 40 | 11 | 45 |
| 800 | 10 | 123 |

## Two costs

### Every window rebuilds its own lines

`AloemacsWindowTree.frame-rows` asks each leaf for lines. The leaf calls `AloemacsEditor.frame-rows`, which focuses the shared `Text` at that view's `scroll-row`, takes `next-lines` for the window's text rows, and runs `safe-cells` on each clipped line. A tall leaf then pads every line to the column width and appends the mode-line bar.

One window does not take that path. `AloemacsEditor.frame` clips and safe-cells the lines, joins them, and clears the rest of the screen. It does not pad.

At line 0 on the 220×54 layout, where every scroll position is 0:

| Piece | Time |
| --- | ---: |
| One session frame | 11 ms |
| The editor frame inside it | 9 ms |
| One narrow pane, `frame-rows` at scroll 0 | 8 ms |
| `safe-cells` on 48 lines clipped to 53 characters | 5 ms |
| The same 48 lines clipped to 220 | 6 ms |
| `pad-row` of those 48 lines to width 53 | 2 ms |
| `pad-row` of those 48 lines to width 220 | 14 ms |
| One mode-line row, width 53 | under 1 ms |
| That row wrapped in the light bar | under 1 ms |
| Four-window session frame | 54 ms |

Four panes at 8 ms account for about 32 ms. Padding four narrow screens accounts for about another 8 ms. The rest is joining the rows, the vertical bars, the echo line, and the cursor sequence. The colored mode line is inside the sub-millisecond bar measurement. One window, which also draws that bar, stays at 11 ms.

The lines are shorter than a column, so a narrow window still scans almost the whole line. `safe-cells` walks one character at a time: `take` 1, `find` in the 33-character control string, `drop` 1, `append`. A screen of these lines is 5 or 6 ms whether the clip width is 35, 53, or 220. Four windows each do that walk. Splitting the screen does not divide the character work.

### The other windows walk back to an old scroll

`with-view-buffer` copies `scroll-row` and `scroll-col` onto the selected view only. A Down key updates the shared editor, then stores the new origin on that one view. The other views keep the origin from the split.

The shared `Text` sits on the cursor line, because `move-down` stores the zipper returned by `focus-down`. Painting another window calls `focus-at` on that zipper with the old `scroll-row`. From line 800 back to line 0, that walk measured 27 ms. The same 27 ms is the walk from line 0 down to line 800. Per line, that is about 0.034 ms.

After moving only the selected window:

| Cursor line | Selected scroll | Other three scrolls | Walk back to line 0 | One stale pane, `frame-rows` |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 0 | 0, 0, 0 | under 1 ms | 8 ms |
| 40 | 0 | 0, 0, 0 | 1 ms | 9 ms |
| 120 | 69 | 0, 0, 0 | 4 ms | 12 ms |
| 400 | 349 | 0, 0, 0 | 14 ms | 24 ms |
| 800 | 749 | 0, 0, 0 | 27 ms | 36 ms |

At line 40 the walk is 1 ms, so the 57 ms frame is the four rebuilds. That is the lag in the screenshot. Three windows walking 800 lines at 0.034 ms is about 82 ms, which is the growth from the 54 ms frame at the top to the 136 ms frame at line 800. The selected window's walk stays about one screen long, which is why the one-window number does not grow.

At line 800, three stale panes at 36 ms plus the selected window's ordinary frame land on the measured 136 ms.

Each step of that walk copies the file's line lists. `focus-down` and `focus-up` send `cons` and `rest` to the `above` and `below` lists. Those lists together hold every line. `List` `cons` and `rest` in `aloe/eval.rkt` copy the elements into a new immutable vector, and `make-list-value` walks the elements again to recompute the element type. A chain of 40 rests on this 971-line file, and a chain of 40 `focus-down` steps, each measured about 1 ms. The 27 ms walk over 800 lines is that per-step copy, repeated.

## What the numbers say

A held Down key queues work whenever a frame takes longer than about 30 ms. One window builds a frame in 9–14 ms at every depth measured, so the queue stays empty. Four vertical windows of this file build a frame in 54 ms while the cursor is still on the first screen, and in 136 ms by line 800.

The first-screen cost is four copies of line extraction, safe-cells, and padding. The growth after that is the three windows whose scroll is still at the top, each walking the shared zipper from the cursor back to line 0 on every frame. The mode-line color is a fraction of a millisecond on top of a row that was already being built.
