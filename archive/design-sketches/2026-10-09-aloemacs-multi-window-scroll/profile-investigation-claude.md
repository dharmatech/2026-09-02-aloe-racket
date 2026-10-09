# Aloemacs multi-window scroll: profile investigation (Claude)

Investigation only. This file records what was measured and what the
measurements point to in the code. It does not propose a repair.

## The symptom

Reported on 2026-10-09. Aloemacs runs with four vertical windows on
one buffer, `/tmp/aloemacs-all.aloe`. Holding Down moves the cursor,
and once it reaches the bottom it scrolls. After the key is released,
the cursor keeps moving and the window keeps scrolling for a while.
With one window, the cursor stops as soon as the key is released.

## Setup

- Code: commit 685bbb7. There have been no changes under `aloe/`,
  `lib/`, `examples/` or `host/` from that commit through d2b7a84.
- Racket v9.3 [cs], Linux, Wayland session.
- Key repeat: GNOME `repeat-interval` is 30 ms and `delay` is 500 ms.
  A held key therefore delivers one key about every 30 ms.
- Fixture: `/tmp/aloemacs-all.aloe`, the file in the screenshot. It
  has 971 lines and 34,820 bytes.
- For the file-size checks, the fixture was concatenated 4 times
  (3,884 lines) and 12 times (11,652 lines).
- Terminal size: 251 columns × 52 rows, estimated from the screenshot.
  - Four windows give leaves 62 columns wide, each with 50 text rows
    and one mode-line row. The root has 51 rows plus the echo row.

## Harness

The harness is headless. It mirrors the loop in
`run-aloemacs-with-hosts` ([aloemacs-run.rkt:60](../../../host/racket/aloemacs-run.rkt)).

- It prepares the same three thunks with `driver-prepare!`: fit
  (`ensure-visible`), frame (`(term write (aloemacs-editor frame …))`)
  and `handle-key`.
- It times each thunk separately for every key, using
  `current-inexact-monotonic-milliseconds`.
- The term receiver has three parts:
  - a scripted key reader
  - an output port that only counts bytes
  - a fixed size
- Terminal emulator cost is not included.
- The four-window layout is built with the keys
  `C-x 3, C-x 3, C-x o, C-x o, C-x 3, C-x o, C-x o, C-x o`. This gives
  four equal columns with the second column selected, as in the
  screenshot. The selected view is id 2. The other three views keep
  `scroll-row` 0.
- The source is in the appendix.

The pieces of a frame were timed separately with Aloe expressions run
through `driver-prepare!`. Each was run once to warm up, then averaged
over 20 runs.

The Racket sampling profiler (`profile` library, 1 ms sampler) was run
over 15 four-window frames at two cursor lines.

## Measurement 1: time per key while holding Down (971 lines)

All times are averages per key, in milliseconds.

| Layout | Cursor lines | fit | frame | handle-key | total |
|---|---|---|---|---|---|
| 1 window | 0–99 | 0.09 | 12.64 | 0.24 | 12.97 |
| 1 window | 100–199 | 0.10 | 13.31 | 0.25 | 13.66 |
| 1 window | 200–299 | 0.09 | 15.86 | 0.25 | 16.20 |
| 2 windows | 0–99 | 0.13 | 40.14 | 0.25 | 40.53 |
| 2 windows | 100–199 | 0.13 | 44.17 | 0.26 | 44.56 |
| 2 windows | 200–299 | 0.13 | 49.17 | 0.25 | 49.55 |
| 4 windows | 0–99 | 0.20 | 57.54 | 0.26 | 58.00 |
| 4 windows | 100–199 | 0.20 | 68.32 | 0.27 | 68.79 |
| 4 windows | 200–299 | 0.20 | 79.78 | 0.26 | 80.25 |
| 4 windows | 300–399 | 0.20 | 89.63 | 0.27 | 90.09 |
| 4 windows | 400–499 | 0.20 | 99.46 | 0.27 | 99.93 |
| 4 windows | 500–599 | 0.20 | 109.93 | 0.27 | 110.40 |
| 4 windows | 600–699 | 0.20 | 121.41 | 0.27 | 121.88 |
| 4 windows | 700–799 | 0.20 | 130.27 | 0.27 | 130.74 |
| 4 windows | 800–899 | 0.20 | 140.71 | 0.27 | 141.18 |

Bytes written per frame:

| Layout | Bytes |
|---|---|
| 1 window | 2,041 |
| 2 windows | 12,909 |
| 4 windows | 13,011 |

Observations:

- Building the frame is almost all of the time. `handle-key` and fit
  together are under 0.5 ms.
- One window stays under the 30 ms repeat interval.
- Four windows start at about 2× the interval (58 ms). The cost then
  grows by about 10 ms per 100 lines of cursor travel, reaching about
  4.7× the interval (141 ms) near line 800.

## Measurement 2: the pieces of a frame

Timed as Aloe expressions at the four-window leaf size: 62 columns,
50 rows.

- `ed0` is the visited editor. Its Text zipper is focused at line 0.
- `ed800` is the same editor with the zipper focused at line 800.

All times are in milliseconds.

| Expression | 971 lines | 3,884 lines |
|---|---|---|
| One window: `(ed0 frame 251 51)`, cursor at line 0 | 9.38 | 14.18 |
| One leaf: `(ed0 frame-rows 62 50 0 0)`, zipper at 0 | 8.22 | 12.89 |
| One leaf: `(ed800 frame-rows 62 50 0 0)`, zipper at 800 | 35.37 | 109.21 |
| `((ed800 text) focus-at 0)`: 800 zipper steps | 27.07 | 96.01 |
| `focus-at 400`, then `focus-at 0`: also 800 steps | 27.01 | 95.69 |
| `next-lines 50` | 2.02 | 6.60 |
| `safe-cells` on 50 lines clipped to 62 | 6.58 | 5.94 |
| `pad-row` on 50 lines to 62 | 4.95 | 3.44 |
| Mode line `row` + `bar`, 62 wide | 0.35 | 0.34 |

Derived costs at 971 lines:

- **A zipper step** (`focus-up` or `focus-down`) costs about 34 µs. At
  3,884 lines it costs about 120 µs.
- **`safe-cells`** processes 1,218 characters in those 50 clipped
  lines, about 5.4 µs per character.
- **`pad-row`** adds 1,882 padding spaces, about 2.6 µs per space.
- **One leaf at the top of the file** costs about 13.5 ms:
  `next-lines` + `safe-cells` + `pad-row` + bar. Four leaves come to
  about 54 ms. The joins, echo row and cursor address bring that up to
  the measured 57.5 ms.

The first 50 lines of the 4× file are the same as the original's, so
the `safe-cells` and `pad-row` rows compare the same text. Their
difference between the two columns is run-to-run noise.

## Measurement 3: one window and file size

One window, holding Down from the top. All times are in milliseconds.

| File | frame | handle-key | total |
|---|---|---|---|
| 971 lines | 13.94 | 0.25 | 14.28 |
| 3,884 lines | 20.95 | 0.36 | 21.40 |
| 11,652 lines | 42.48 | 0.67 | 43.24 |

The one-window frame and `handle-key` both grow with file length.
They grow even with the cursor near the top.

## Measurement 4: profile

The figures are self time of evaluator functions in `aloe/eval.rkt`,
over 15 four-window frames. Self time is the share of samples where
the function itself was running.

At cursor line 0:

| Function | Self |
|---|---|
| `make-list-value` | 17.3% |
| `eval-expr` | 11.0% |
| `send-to-string` | 7.7% |
| `send-to-function` | 4.4% |
| `send-to-instance` | 0.8% |

At cursor line 400:

| Function | Self |
|---|---|
| `make-list-value` | 33.0% |
| `eval-expr` | 8.9% |
| `send-to-list` | 5.1% |
| `send-to-string` | 4.0% |
| `eval-case` | 1.5% |

At line 400, `make-list-value` including its callees is 44.4% of all
samples.

The profiler sees Racket functions, not Aloe methods. The time that
is not listed is spread thinly across many evaluator functions.

## Measurement 5: one leaf rebuilt after a scroll

This used a second fixture: 971 lines of 35 characters each (`"n "`
then `x` padding), at 220 × 54. The leaves there are 54 or 55 columns
wide with 52 text rows.

| Expression | ms |
|---|---|
| One leaf with the zipper at line 852 and scroll 801. Includes the 51-step walk, `frame-rows`, `pad-row` and the bar. | 15.40 |
| Three `right-rows` joins plus the body fold over 53 rows | 1.17 |

## How the measurements map to the code

### The loop draws one full frame per key

[aloemacs-run.rkt:60](../../../host/racket/aloemacs-run.rkt) runs fit,
then frame, then `handle-key`, then loops.

- `read-next-key` in `host/racket/term.rkt` returns one key event.
- Keys that arrive while a frame is being built wait in the terminal's
  input queue.
- Each queued key then gets its own complete frame.

Any key whose frame costs more than the 30 ms repeat interval adds to
a backlog. That backlog is still draining after the key is released.

### The cost at the top of the file: four leaves, all built every frame

`AloemacsSession.frame` takes the multi-window path when the tree is
not a single leaf ([file.aloe:1577](../../../examples/aloemacs/file.aloe)).
`AloemacsWindowTree.frame-rows` ([file.aloe:591](../../../examples/aloemacs/file.aloe))
does the same work for every leaf, every frame:

- gets the lines with `AloemacsEditor.frame-rows` ([editor.aloe:76](../../../examples/aloemacs/editor.aloe)),
  which runs `next-lines` and then `safe-cells` per line
- pads every row to the leaf width with `pad-row`
  ([file.aloe:529-533](../../../examples/aloemacs/file.aloe))
- adds the mode-line bar

Two things set the per-character costs:

- `safe-cells` ([editor.aloe:61](../../../examples/aloemacs/editor.aloe))
  makes one interpreted recursive call per character. Each call does
  `take 1`, `find` against the control-character string, `drop 1` and
  `append`.
- `spaces` makes one interpreted recursive call per padding space.

The one-window path (`single-frame` → `AloemacsEditor.frame`)
differs in two ways:

- It does not pad.
- It touches only the characters that lines actually contain.

Four 62-column leaves showing the same 50 lines process about four
times the characters of one wide window, plus the padding. That
matches four leaves at about 13.5 ms each.

### The growth with cursor line: unselected leaves walk from the cursor

- Only the selected view's `scroll-row` is updated as the cursor
  moves. `with-editor` sends `with-buffer`, and `with-view-buffer`
  copies `scroll-row` and `scroll-col` onto the selected view only.
  So the three unselected leaves keep `scroll-row` 0.
- All four leaves show the same buffer, so they share one editor and
  one Text zipper. That zipper is focused at the cursor line.
- To paint a leaf, `AloemacsEditor.frame-rows` sends
  `((self text) focus-at scroll-row)`. For an unselected leaf, that
  walks the zipper one line at a time from the cursor line back to
  line 0, on every frame.
- With the cursor at line 800, the walk costs 27 ms per leaf, or
  81 ms for three leaves. The measured four-window growth from lines
  0–99 to lines 800–899 is 83 ms (58.00 → 141.18 ms).
- The selected leaf walks at most one window height from the cursor
  to its own scroll row.

### Why one zipper step costs the whole file

List is stored as an immutable Racket vector inside the `list-value`
struct ([eval.rkt:31](../../../aloe/eval.rkt)). In `send-to-list`
([eval.rkt:1207](../../../aloe/eval.rkt)):

- `first`, `len` and `empty?` index or measure the vector. They are
  constant time.
- `rest` and `cons` each do the following:
  1. convert the whole vector to a Racket list (`vector->list`)
  2. drop or add one element
  3. call `make-list-value` ([eval.rkt:742](../../../aloe/eval.rkt))

`make-list-value` then does three things:

1. computes `runtime-type-of` for every element
2. checks that every element has the same runtime type, or the same
   protocol
3. copies everything into a new vector with
   `(apply vector-immutable elements)`

So `cons` and `rest` are each linear in the list's length, with a
per-element type computation.

In `lib/text.aloe`, `focus-up` ([text.aloe:130](../../../lib/text.aloe))
and `focus-down` ([text.aloe:142](../../../lib/text.aloe)) each do one
`cons` and one `rest`, on `above` and `below`. Those two lists
together hold every line except the current one, so every zipper step
is linear in the file's line count. That matches the measurements:

- The 800-step walk goes from 27 ms to 96 ms when the file grows 4×.
- `next-lines` ([text.aloe:106](../../../lib/text.aloe)) is one
  `focus-down` per row. It goes from 2.0 ms to 6.6 ms for 50 rows.
- In the profile, `make-list-value` grows from 17% to 33% of self
  time as the walk lengthens.

The same mechanism explains the one-window growth with file size in
Measurement 3:

- `move-down` does one `focus-down`, which is linear in file length.
- The frame's `next-lines` does one `focus-down` per visible row.

`fold` in `lib/list.aloe` recurses on `(self rest)`. Because `rest`
copies the list, `fold`, `reverse` and `map` are quadratic in list
length. The frame folds only over short lists, so this was not a
measured cost here.

## Regression or not

No older commits were benchmarked. These dates come from `git log -S`:

- The vector-backed List (`(apply vector-immutable elements)`) dates
  from the initial commit, 9ba6827 (2026-09-02).
- `pad-row` and the per-view `focus-at scroll-row` came in with the
  windows series, 918f5de (2026-10-03).
- The window-bars and mode-line color work (70156e7) adds the bar.
  The bar measures 0.35 ms per leaf.

So the multi-window costs measured here have existed since the
windows series. They were not introduced by the mode-line color
change.

## Not measured

- **Terminal emulator time.** The frame string was written to a port
  that only counts bytes. The real terminal receives about 13 KB per
  four-window frame, compared with 2 KB for one window. That cost
  comes on top of the numbers above.
- **Real key arrival timing.** The backlog explanation rests on two
  things: the 30 ms repeat setting and the per-key costs. Key-event
  timestamps were not recorded.
- **Garbage collection pauses.** These were not separated out. Each
  measurement section starts after a `collect-garbage`.

## Appendix: harness (`bench.rkt`)

Run as `racket bench.rkt <file> <columns> <rows> <layout> <downs>`.
For example, `racket bench.rkt sample.aloe 251 52 4 900`.

```racket
#lang racket/base

;; Headless Aloemacs key-loop benchmark. Mirrors run-aloemacs-with-hosts:
;; each key = fit (ensure-visible) + frame (build + term write) + handle-key.
;;   racket bench.rkt <file> <columns> <rows> <layout> <downs>
;; layout: 1 | 2 | 4 (vertical windows)

(require racket/list racket/port racket/string racket/sequence
         (file "/home/dharmatech/journal/2026-09-02-aloe-racket/aloe/driver.rkt")
         (file "/home/dharmatech/journal/2026-09-02-aloe-racket/host/racket/term.rkt")
         (file "/home/dharmatech/journal/2026-09-02-aloe-racket/host/racket/fs.rkt"))

(define args (current-command-line-arguments))
(define path (vector-ref args 0))
(define columns (string->number (vector-ref args 1)))
(define rows (string->number (vector-ref args 2)))
(define layout (string->number (vector-ref args 3)))
(define downs (string->number (vector-ref args 4)))

(define setup-keys
  (case layout
    [(1) '()]
    [(2) '("ctrl-x" "3")]
    ;; Four equal columns: split, split left half, move to right half, split it,
    ;; then select the second column (as in the screenshot).
    [(4) '("ctrl-x" "3" "ctrl-x" "3" "ctrl-x" "o" "ctrl-x" "o" "ctrl-x" "3"
           "ctrl-x" "o" "ctrl-x" "o" "ctrl-x" "o")]))

(define pending-key (box #f))
(define bytes-written (box 0))
(define out (make-output-port 'null always-evt
                              (lambda (bs start end _a _b)
                                (set-box! bytes-written (+ (unbox bytes-written) (- end start)))
                                (- end start))
                              void))
(define term (make-term-receiver out (lambda () (unbox pending-key))
                                 (lambda () (values columns rows))))

(define state (make-driver))
(driver-inject-host! state 'term term)
(driver-inject-host! state 'fs-host (make-fs-receiver))
(driver-load-file!
 state "/home/dharmatech/journal/2026-09-02-aloe-racket/examples/aloemacs/main.aloe")
(driver-eval! state
  `(define aloemacs-startup-visit
     (aloemacs-editor visit ((aloemacs-editor fs) path ,path))))
(driver-eval! state
  '(define aloemacs-editor
     (aloemacs-startup-visit case
       (None () aloemacs-editor)
       (Some (session) session))))

(define fit (driver-prepare! state `(define aloemacs-editor
                                      (aloemacs-editor ensure-visible ,columns ,rows))))
(define frame (driver-prepare! state `(term write (aloemacs-editor frame ,columns ,rows))))
(define handle (driver-prepare! state '(define aloemacs-editor
                                         (aloemacs-editor handle-key (term read-key)))))

(define (ms thunk)
  (define t0 (current-inexact-monotonic-milliseconds))
  (thunk)
  (- (current-inexact-monotonic-milliseconds) t0))

(define (step key)
  (set-box! pending-key key)
  (define f (ms fit))
  (define r (ms frame))
  (define h (ms handle))
  (list f r h))

(for ([k setup-keys]) (step k))
(printf "leaves: ~a  selected: ~a\n"
        (driver-eval! state '((((aloemacs-editor windows) tree) leaves) len))
        (driver-eval! state '((aloemacs-editor windows) selected)))

(collect-garbage)
(define samples
  (for/list ([i downs])
    (define line (driver-eval! state '((aloemacs-editor point) line)))
    (cons line (step "down"))))

(define (avg xs) (/ (apply + xs) (max 1 (length xs))))
(define (report label xs)
  (printf "~a  n=~a  fit ~a ms  frame ~a ms  key ~a ms  total ~a ms\n" label (length xs)
          (real->decimal-string (avg (map cadr xs)) 2)
          (real->decimal-string (avg (map caddr xs)) 2)
          (real->decimal-string (avg (map cadddr xs)) 2)
          (real->decimal-string (avg (map (lambda (s) (+ (cadr s) (caddr s) (cadddr s))) xs)) 2)))

(printf "~ax~a layout=~a\n" columns rows layout)
(for ([chunk (in-slice 100 samples)])
  (report (format "lines ~a-~a" (car (first chunk)) (car (last chunk))) chunk))
(report "ALL" samples)
(printf "bytes per frame ~a\n" (quotient (unbox bytes-written) (+ downs (length setup-keys))))
```

The profile used the same setup.

1. Build the four-window layout.
2. Send 0 or 400 Down keys.
3. Run:

```racket
(profile-thunk (lambda () (for ([i 15]) (frame))) #:delay 0.001)
```
