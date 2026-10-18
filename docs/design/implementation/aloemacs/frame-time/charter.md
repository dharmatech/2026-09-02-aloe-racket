# Charter — aloemacs frame time

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. The specification will live beside this file
as [`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **keeping an Aloemacs frame
inside the key-repeat interval while Down is held**, in one window and
in several windows of one buffer, deep in a file as long as the
editor's own source. The series identity is **aloemacs-frame-time**.
The bytes on screen stay the bytes `frame` paints today. Then
**stop**. Do not write checkpoints. Do not implement.

A held letter key is not this series. Its cost is measured in §2, and
§4.8 says why it is left in place and where it goes.

This effort refuses a change to the evaluator, the checker, `SPEC.md`,
`List`, `String`, or any kernel message. It refuses a change to the
runner, key coalescing, terminal scroll regions, partial or
cursor-only terminal writes, a `Vector`, and mutation. Those stay out
so the spec stays small enough to slice, and so it does not collide
with the host-runner work that owns the runner's future.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), the record in §2, and
   the authority in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-frame-time 000** under
   `docs/design/implementation/aloemacs/frame-time/checkpoints/`.
5. Stop. The human reviews the spec. Do not write checkpoint files.

## 2. Measured (do not re-litigate)

The evidence is
[`archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md`](../../../../../archive/design-sketches/2026-10-18-aloemacs-frame-time/summary.md),
with its probes and its reviews. It is evidence, not part of the
assignment. Its findings, at `21d1a36`, 220×54, the window-pictures
fixture of 971 lines of 35 characters, alone:

| Case | ms |
|---|---:|
| Held Down, four windows, widest leaf deep (the test's sample) | 27.4 |
| Held Down, one window deep | 17.6 |
| Held Down, four windows, first screen | 3.2 |
| One typed character, four windows of one buffer, deep | 198 |
| One typed character, one window, deep | 17.8 |

1. **The growth since 9 October is the evaluator.** `aloe/eval.rkt`
   crossed Racket CS's compile limit on 14 October (`0e20fae`). Its
   body is now compiled in interpretable mode, and the editor's frames
   lost about 20 percent. With `eval.rkt` compiled whole, the three
   test medians are 2.6, 22.8, and 14.1 ms. The editor commits since
   window-pictures 000 add under 1 ms. That repair is on the language
   spine; see §4.2.
2. **Per-character Aloe loops are most of a leaf.** In the deep
   four-window sample, rebuilding the selected 109×52 leaf is 24.1 ms.
   Of that, `safe-cells` is 9.5, `pad-row` (through `spaces`) is 7.4,
   and the mode line (through `fill`) is 0.7. In one window,
   `safe-cells` is 9.8 of 17.6 ms and the mode line is 1.5.
3. **Zipper steps grow with the file.** `focus-up` and `focus-down`
   copy both line Lists on every step. A frame walks from the point to
   its top row, then `next-lines` back down: 5.6 ms at 971 lines. Both
   deep Down cases grow about 3 ms per thousand lines with the
   evaluator fixed, 5 ms without. At 2,400 lines the wide case is
   34.2 ms alone today.
4. **A typed character rebuilds every leaf of its buffer**, and each
   unselected leaf walks from the cursor back to its own scroll row,
   copying the whole line list at every step. That is the 198 ms. With
   the evaluator fixed it is 141 ms at 971 lines, 244 ms at 2,400, and
   438 ms at 5,000.
5. **Prototypes, not proposals.** Two changes are editor-only: doubling
   `spaces` and `fill`, and checking a whole leaf's clipped rows for
   controls once before the per-row walk. With the evaluator fixed,
   those two alone gave these medians, alone, in ms:

   | Lines | Down, four windows | Down, one window | Typed character, four windows | Typed character, one window |
   |---:|---:|---:|---:|---:|
   | 971 | 10.9 | 6.6 | 105 | 6.7 |
   | 2,400 | 14.7 | 10.6 | 214 | 11.0 |
   | 5,000 | 22.6 | 18.4 | 404 | 18.1 |

   They do not touch what dominates typing in four windows, the walk in
   item 4. A cheaper List `cons` and `rest`, which §4.3 keeps out, gave
   7.9 and 4.2 ms on Down at 971 lines, and 46, 58, and 88 ms on
   four-window typing at the three lengths. Every frame golden still
   passed.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Same bytes.** Every frame golden in the tree stays. For every
   sequence of keys the spec's tests use, edits included, the frame
   equals the frame of the same session with no recorded state.
   aloemacs-window-pictures 000's equalities still hold: visit,
   kill-buffer, undo then edit with a record between, a resize, and a
   skipped record.
2. **Held Down keeps up.** Four windows of one buffer with the widest
   leaf selected deep in the file, and one window deep, each stay under
   the **30 ms** bar. So does the first screen in four windows. The
   30 ms bar is not raised.
3. **File length.** At least one fixture is as long as
   `examples/aloemacs/file.aloe`. The spec states how the deep cases
   may grow between that fixture and a short one, and holds them to it.
4. **The suite is green under `-j 4`.** The timing bars pass in
   `TMPDIR=/tmp raco test -j 4 -y tests` with no rerun-alone rule. The
   spec states the margin it designs for, and how the human checks it,
   for example a stated number of consecutive whole-suite runs.
5. **No kernel or runner change.** Nothing under `aloe/`, `SPEC.md`,
   `host/racket/`, or `lib/` other than `lib/text.aloe` changes.
6. **A person can see it.** The spec names a hand check, separate from
   the tests: `examples/aloemacs/file.aloe` open in four windows, the
   widest selected, scrolled past line 800. Hold Down, then release:
   the cursor stops with the key. Then the same in one window.

## 4. Locked decisions

### 4.1 Identity and place

Identity is **aloemacs-frame-time**. Checkpoints are spoken
**aloemacs-frame-time 000**, **001**, … This is not window-pictures
001, which stays unissued, and it is not a global checkpoint. Do not
write global 116 or 118.

### 4.2 The evaluator regression is not this series

The compile-limit repair is a language-spine checkpoint, handed to a
checkpoint manager by
[`docs/evaluator-compile-limit-brief.md`](../../../../evaluator-compile-limit-brief.md).
This series does not edit `aloe/`.

The spec may be written before that checkpoint lands. No checkpoint of
this series goes to an implementer until it has landed and
`aloe/eval.rkt` compiles whole, because no timing bar can honestly be
met on today's evaluator. Every checkpoint's timing evidence is taken
on that tree. The spec states this as a precondition of every
checkpoint.

### 4.3 List operations go back, not in

The record shows `List` `cons` and `rest` copy and retype every
element, and that this is the floor that makes zipper steps grow with
the file. A cheaper `cons` and `rest`, an indexed read, or slicing
would each change what List sends do. That is language law, and §4.8
names the discussion it belongs to. Do not put an evaluator, List, or
kernel change in this spec. Held Down measured under the bar without
one (§2, item 5). If the designer finds it cannot be met without one,
stop and send the spec back to the high-level discussion with the
measurement.

### 4.4 Where code may live

- `examples/aloemacs/editor.aloe`, `file.aloe`, and `main.aloe`
- `lib/text.aloe`. `Text` is aloemacs-owned, as the Index and
  next-lines series used it. Its existing messages keep their results,
  and the tests under `tests/modules/` and `tests/string-load-save/`
  that load it stay green.
- `tests/aloemacs/` and, for constructor and inventory migrations,
  `tests/parenthetical-construction/`
- Not `aloe/`, `SPEC.md`, `lib/` outside `text.aloe`, `host/racket/`,
  Gel, or `docs/editor/`

`host/racket/aloemacs-run.rkt` stays as it is: `ensure-visible`, then
`record-pictures`, then the frame write, then `handle-key`. The
host-runner record under
`archive/design-sketches/2026-10-17-host-runner-discussion/` owns that
loop's future. If a repair needs a runner change, stop and send it
back.

### 4.5 What is painted

The frame stays one String written once. The safe-cells display rule
stays: after clipping, codes 0–31 and 127 paint as one space and every
other character is copied. The mode-line spelling, the bars, the echo
row, completion rows, and the cursor address stay. A repair changes how
those bytes are computed, never which bytes they are.

### 4.6 Recorded state stays value state

Anything the spec records between frames, such as pictures or rows, is
an immutable field reached by `with`, as `AloemacsLeafPicture` is. No
mutation, no host cache, no hidden table.

### 4.7 The timing test

`tests/aloemacs/window-pictures.rkt` keeps its byte checks. Its timing
bar may move into a new file or gain cases; the spec decides. The 30 ms
number stays the bar for every Down case. Timed samples keep
typechecking outside the interval (`driver-prepare!`), as today. There
is no timing bar for typing (§4.8).

### 4.8 Held typing is not this series

A typed character deep in four windows of one buffer is 198 ms today,
and 214 ms at 2,400 lines with the evaluator fixed and §5.1 items 1 and
2 in place. One window is 11.0 ms at that length. The difference is the
walk in §2, item 4: after an edit, each unselected leaf walks from the
cursor back to its own scroll row, copying the line lists at every
step. Items 1 and 2 shorten each leaf's build, not that walk. This
series leaves the walk in place.

Keeping a leaf's recorded rows across an edit that does not touch the
lines it shows would hide the walk in some layouts. It cannot carry a
bar. A correct key still misses, and a miss pays the whole walk: a
change in line count above a window whose scroll row is far from the
cursor, a kill or a yank across lines, and an undo or a visit, which
drop every picture. Held undo in four windows would stay near 200 ms
with that key finished. A typing bar would be true where the key hits
and false where it misses. Do not specify edit-aware row reuse, an
edit range, or any other typing machinery here.

Record today's typing cost in the spec as the known walk this series
leaves in place. Do not add a suite timing bar for it. The byte checks
in §3.1 still cover edits.

The repair belongs to a language-spine discussion, named here and not
opened: **indexed read and slicing for List**, with the record in §2
as its evidence. The two operations are separate, and that discussion
may find that painting needs only the read.

- **Indexed read.** A one-line edit already shares the zipper's
  `above` and `below`: `replace-pieces` builds the new current line and
  passes both Lists through. The typing cost is the other windows
  walking the zipper, not the edit. An indexed read on the Lists the
  zipper already holds reads a distant line without a walk and without
  a change to `Text`'s shape. `above` is nearest-first. For a line
  number *j* above the focus, the line is entry `focus − 1 − j` of
  `above`; for a line number *j* below it, entry `j − focus − 1` of
  `below`. At focus 800, line 0 is entry 799 of `above` and line 801
  is entry 0 of `below`.
- **Slicing.** Each extra line of a multi-line insert `cons`es onto
  `above`, and each `cons` copies that whole List, so a large yank
  costs its line count times the file length. A flat line list updated
  only by `cons` would pay that for a one-line edit too. Slicing is
  what those need.

That discussion meets two recorded decisions. Checkpoint 114 left List
`take` out because `first` and `rest` could derive it, before this
measurement existed. The aloemacs Index charter §4.3 asked for the
measurement to come back if List lookup was the floor; this record is
that floor. A scratch prototype of four windows rebuilt by indexed read
is how that discussion learns whether 30 ms still wants row reuse. None
of it blocks this series.

## 5. Open questions (resolve these)

### 5.1 Which repairs, in which order

The record measured some of these. Pick, combine, or replace them, and
give each a measured reason:

1. Doubled `spaces` and `fill`: log *n* sends instead of *n*.
2. Skipping the per-character `safe-cells` walk for clean rows with the
   String messages that exist: the block check in the record's
   prototype, or something better.
3. Building only the rows a scroll exposes, reusing the rest of the
   selected leaf's recorded rows.
4. Fewer zipper steps per frame: collect the visible rows in one walk
   from the point instead of walking up and then down.

Items 1 and 2 alone, with the evaluator fixed, put the wide case at
14.7 ms at 2,400 lines (§2, item 5). Without them it is 27.2 ms, which
leaves no room for the `-j 4` spread. They are what make §3.4
reachable. Items 3 and 4 cut the zipper steps that still grow with the
file, about 3 ms per thousand lines. They are how a longer file stays
inside the margin.

The one-window path stays on `AloemacsEditor.frame`, with no recorded
rows. With items 1 and 2 it measured 6.6, 10.6, and 18.4 ms at the
three lengths.

### 5.2 The bar's cases and numbers

Name the fixtures (lengths, line widths, at least one control
character somewhere so the slow path is exercised), the geometry, the
cases, the sample count, and the statistic. Say how the bar stays
reliable under `-j 4`: the margin each case is designed to, and whether
the test needs more samples or a different statistic. The Index charter
preferred a recorded hand check plus structural rules to a flaky CI
timeout. Window-pictures and safe-cell-scan chose timing bars in
`raco test`. Choose, and make §3.4 true.

### 5.3 Checkpoints

How many checkpoints, and in what order. Each checkpoint has its own
byte checks and its own timing evidence. A slice that only pays off
once the next one lands is not a checkpoint.

### 5.4 Closed documents

The accepted safe-cells spec describes the walk as it was first
written, and window-pictures 000 lists its own non-goals. Closed specs
and checkpoints stay unedited. Say where this spec points instead.

## 6. Authority

- `SPEC.md` governs sends and types.
- The accepted specs and checkpoints of windows, mode-line,
  window-bars, safe-cells, safe-cell-scan, window-pictures 000,
  window-point, mouse, mode-buttons, split-drag, and completion paging
  define what is painted. This series changes none of them.
- The record in §2 is evidence.

Before writing the migration section, apply the spec's product edits
to a scratch copy of the repository, run the aloemacs suite, and list
the failing files. That list, not a guess, is the inventory. A class
added to `file.aloe` fails every test that pins its ordered
`define-class` list (find them with
`grep -rl "AloemacsSearchScan AloemacsMouse (AloemacsSession H)" tests/`).
Name those files without stating a count.

## 7. Non-goals

- Held typing, edit-aware row reuse, and a typing timing bar (§4.8)
- Recorded rows for the one-window path
- The evaluator compile limit (§4.2) and the checker's own compile limit
- An indexed read, slicing, or a cheaper `cons` and `rest` for List;
  `String` or `Text` kernel messages; a `Vector`; ropes or piece tables
- Key coalescing, the runner, the manifest runner, and the Aloe-side
  loop
- Writing fewer bytes to the terminal, scroll regions, or cursor-only
  writes
- Syntax colors, `wcwidth`, wrapping
- Startup, visit, save, and LSP latency
