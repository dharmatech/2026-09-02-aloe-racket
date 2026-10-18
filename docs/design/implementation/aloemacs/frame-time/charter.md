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
inside the key-repeat interval while a key is held**: Down, and a
typed character, in one window and in several windows of one buffer,
deep in a file as long as the editor's own source. The series
identity is **aloemacs-frame-time**. The bytes on screen stay the
bytes `frame` paints today. Then **stop**. Do not write checkpoints.
Do not implement.

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
with its probes. It is evidence, not part of the assignment. Its
findings, at `21d1a36`, 220×54, the window-pictures fixture of 971
lines of 35 characters, alone:

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
   unselected leaf walks from the cursor back to its own scroll row.
   That is the 198 ms, and 438 ms at 5,000 lines with the evaluator
   fixed. No test measures it.
5. **Prototypes, not proposals.** Doubling `spaces` and `fill`, and
   checking a whole leaf's clipped rows for controls once before the
   per-row walk, are editor-only. With cheaper List steps added, and the
   evaluator fixed, the deep Down cases measured 7.9 and 4.2 ms at 971
   lines and 9.6 and 5.7 ms at 5,000. Under `-j 4` they measured 8.6
   to 10.4 and 4.5 to 6.5 ms. Every frame golden still passed. A typed
   character in four windows was still 46 ms.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Same bytes.** Every frame golden in the tree stays. For every
   sequence of keys the spec's tests use, the frame equals the frame
   of the same session with no recorded state.
   aloemacs-window-pictures 000's equalities still hold: visit,
   kill-buffer, undo then edit with a record between, a resize, and a
   skipped record.
2. **Held Down keeps up.** Four windows of one buffer with the widest
   leaf selected deep in the file, and one window deep, each stay under
   the **30 ms** bar. So does the first screen in four windows. The
   30 ms bar is not raised.
3. **Held typing keeps up.** One typed character, deep, in four
   windows of one buffer, stays under the same bar. One window stays
   under it too.
4. **File length.** At least one fixture is as long as
   `examples/aloemacs/file.aloe`. The spec states how the deep cases
   may grow between that fixture and a short one, and holds them to it.
5. **The suite is green under `-j 4`.** The timing bars pass in
   `TMPDIR=/tmp raco test -j 4 -y tests` with no rerun-alone rule. The
   spec states the margin it designs for, and how the human checks it,
   for example a stated number of consecutive whole-suite runs.
6. **No kernel or runner change.** Nothing under `aloe/`, `SPEC.md`,
   `host/racket/`, or `lib/` other than `lib/text.aloe` changes.
7. **A person can see it.** The spec names a hand check, separate from
   the tests: `examples/aloemacs/file.aloe` open in four windows, the
   widest selected, scrolled past line 800. Hold Down, then release:
   the cursor stops with the key. Hold a letter, then release: the text
   stops with the key. Then the same in one window.

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
This series does not edit `aloe/`. Its timing bars are judged on a
tree where `aloe/eval.rkt` compiles whole. The spec states that as a
precondition of every checkpoint that sets or tightens a timing bar.
The spec may be written before that checkpoint lands.

### 4.3 List step cost goes back, not in

The record shows `List` `cons` and `rest` copy and retype every
element, and that this is the floor that makes zipper steps grow with
the file. The aloemacs Index charter's rule still holds: if the bar
cannot be met without changing that cost, stop and send it back to the
high-level discussion with the measurement. Do not put an evaluator,
List, or kernel change in this spec. The record suggests the
editor-side options in §5.1 are not exhausted.

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

Anything the spec records between frames (pictures, rows, an edit
range) is an immutable field reached by `with`, as `AloemacsLeafPicture`
is. No mutation, no host cache, no hidden table.

### 4.7 The timing test

`tests/aloemacs/window-pictures.rkt` keeps its byte checks. Its timing
bar may move into a new file or gain cases; the spec decides. The 30 ms
number stays the bar for every case. Timed samples keep typechecking
outside the interval (`driver-prepare!`), as today.

## 5. Open questions (resolve these)

### 5.1 Which repairs, in which order

The record measured these, or their parts. Pick, combine, or replace
them, and give each a measured reason:

1. Doubled `spaces` and `fill`: log *n* sends instead of *n*.
2. Skipping the per-character `safe-cells` walk for clean rows with the
   String messages that exist: the block check in the record's
   prototype, or something better.
3. Building only the rows a scroll exposes, reusing the rest of the
   selected leaf's recorded rows.
4. Recorded rows for the one-window path. aloemacs-window-pictures 000
   kept one window on `AloemacsEditor.frame`; this series may reopen
   that.
5. Keeping a leaf's rows across an edit that does not touch the lines
   it shows. That needs a statement of which lines an edit changed,
   and a key that cannot match stale rows. Window-pictures 000 explains
   why history length alone is not that key.
6. Fewer zipper steps per frame: collect the visible rows in one walk
   from the point instead of walking up and then down.

### 5.2 The bar's cases and numbers

Name the fixtures (lengths, line widths, at least one control
character somewhere so the slow path is exercised), the geometry, the
cases, the sample count, and the statistic. Say how the bar stays
reliable under `-j 4`: the margin each case is designed to, and whether
the test needs more samples or a different statistic. The Index charter
preferred a recorded hand check plus structural rules to a flaky CI
timeout. Window-pictures and safe-cell-scan chose timing bars in
`raco test`. Choose, and make §3.5 true.

### 5.3 Which edits must be cheap

Which keys count as typing for §3.3: a printable character, Return,
Backspace, Delete, kill-line, yank, undo. In which layouts: four
columns, stacked windows, two buffers in four windows. Say which stay
at today's cost and why.

### 5.4 Slicing

How many checkpoints, and in what order. Each checkpoint has its own
byte checks and its own timing evidence. A slice that only pays off
once the next one lands is not a checkpoint.

### 5.5 Closed documents

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

- The evaluator compile limit (§4.2) and the checker's own compile limit
- `List`, `String`, or `Text` as new kernel types or messages; a
  `Vector`; ropes or piece tables
- Key coalescing, the runner, the manifest runner, and the Aloe-side
  loop
- Writing fewer bytes to the terminal, scroll regions, or cursor-only
  writes
- Syntax colors, `wcwidth`, wrapping
- Startup, visit, save, and LSP latency
