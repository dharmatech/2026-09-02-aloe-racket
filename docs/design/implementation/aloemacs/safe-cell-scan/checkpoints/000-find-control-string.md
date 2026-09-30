# aloemacs-safe-cell-scan 000 — `find` the control string

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Make a wide frame cheap again, and make the suite fail if that cost
comes back.

`AloemacsEditor.safe-cells` still walks a clipped string one
character at a time. For every character it builds a 33-element
list of controls and folds equality. Replace that membership test
with one `String.find` against a single 33-character control
string. Keep the walk, the replacements, and the length rule.

Add a timing test that runs under ordinary `raco test`. An
80-column, 24-row frame of printable lines must stay under 80
milliseconds. That test is part of this slice, not a later
checkpoint.

Do not change what is painted. Do not add a kernel message. Do not
rewrite `take` / `drop` / `append`.

## Why this is the repair

Holding Down or Up re-frames the viewport. Movement on the indexed
text stayed under a millisecond. The frame did not.

On a 10,000-line file of 80-character lines, a 24-row frame
measured about 21 ms before safe cells and about 269 ms after
commit `b2eec48`. The search commit left it at about 272 ms. The
bytecode work is unrelated. `tests/aloemacs/index-002-timing.rkt`
stayed green because its lines are one `x`, and its timer is in
`module+ main`, so `raco test` does not run it.

A temporary copy that swapped the 33-list for `String.find` brought
an 80-column session frame from about 252 ms to about 30 ms, and
`tests/aloemacs/safe-cells.rkt` passed. The gap from that 30 ms
back to the old 21 ms is the per-character `take`, `drop`, and
`append`. This slice does not touch that.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs sends. The observable display
contract remains
[`../../safe-cells/spec.md`](../../safe-cells/spec.md): after
clipping, codes 0–31 and 127 paint as one space, every other
character is copied, and the result has the same `len`. That
spec's sentence about 33 equality comparisons is how the method
was written before `String.find` existed. Do not edit the spec.
`find` is already a kernel String message. Do not add another.

- Identity is **aloemacs-safe-cell-scan 000**. No predecessor in
  this folder. Safe cells 000 and search 000–001 are implemented.
  This is not safe-cells 001.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today `examples/aloemacs/editor.aloe` defines `safe-cells` with
  a `List of` the 33 control strings, a `fold` of `(cell = candidate)`,
  and `(self safe-cells (clipped-string drop 1))`.
- `examples/aloemacs/editor.aloe` loads `lib/text.aloe`, which
  loads `Option`. `find` returns that `Option`. No new `load`.
- `examples/aloemacs/file.aloe` already sends `safe-cells`: once
  per text row through `frame`, once on the clipped echo label,
  and once on a one-character search key
  (`((self editor) safe-cells key) = key`). Those callers stay.
  A printable key must still come back unchanged. A control key
  must still come back as `" "`.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` — replace only the body of
  `safe-cells`. The method name, argument, and result type stay
  `(safe-cells (clipped-string String) String`.
- `tests/aloemacs/safe-cell-scan.rkt` (new) — the wide-frame
  timing bar, checks at module top level so `raco test` runs them.

### Must leave untouched

- `examples/aloemacs/file.aloe`, `main.aloe`, the runner, Term, Fs
- `lib/`, `aloe/`, `SPEC.md`, `CHECKPOINTS.md`
- [`../../safe-cells/spec.md`](../../safe-cells/spec.md) and the
  rest of that folder
- `tests/aloemacs/safe-cells.rkt`,
  `tests/aloemacs/index-002-timing.rkt`, and every other existing
  test
- `frame`, `frame-ansi`, `next-lines`, scroll, point, and history
- This folder's `README.md`, the parent aloemacs map, and this
  checkpoint
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion. Do not widen the slice.

## Required behavior

Replace the `safe-cells` body with this. `controls` below is one
string literal of the 33 characters U+0000 through U+001F and
U+007F, in that order. Write it as one Aloe string literal. Do
not build it with `List of`, `fold`, or 33 separate comparisons.

```aloe
(safe-cells (clipped-string String) String
  (if ((clipped-string len) = 0)
      ""
      (let ((cell (clipped-string take 1)))
        ((if ((controls find cell 0) present?)
             " "
             cell)
         append
         (self safe-cells (clipped-string drop 1))))))
```

`controls` in that expression is the literal, in the receiver
position of `find`. The pattern is the one-character `cell`. The
start index is `0`. `present?` means the cell is one of those 33
controls.

`""` still returns `""`. A printable character, including codes
128 and above, is still appended unchanged. `ESC` followed by
`[31m` is still a space followed by those four characters. The
frame still sanitizes only the clipped row, then joins with
`"\r\n"`. The echo label and the one-character search key still
use this same method.

## Tests

New `tests/aloemacs/safe-cell-scan.rkt`. Checked `make-driver`,
load `examples/aloemacs/editor.aloe`, no TTY. No `module+ main`.
The checks run when `raco test` loads the file.

Fixture, built before the timer:

- 24 lines, each `(make-string 80 #\x)`, joined with `"\n"`.
- An `AloemacsEditor` whose text is that source focused at line 0,
  point `(Position new 0 0)`, scroll row 0, scroll column 0, empty
  history.
- One untimed `(editor frame 80 24)` before the samples.

Then five timed samples. Each sample is only the send
`(editor frame 80 24)`. Use
`current-inexact-monotonic-milliseconds`. The median is the third
value after sorting the five durations ascending.

Assertions:

- That median is strictly under **80** ms. On failure, the
  Rackunit message includes the median in milliseconds. Also
  `printf` the median when the check passes.
- One frame result, not inside a timed sample, equals the usual
  editor frame: prefix `"\u001b[?25l\u001b[2J\u001b[H"`, then the
  24 lines of 80 `x` joined with `"\r\n"`, then
  `"\u001b[1;1H\u001b[?25h"`.

Leave `tests/aloemacs/safe-cells.rkt` as the behavior suite. It
already covers all 33 controls, length, clipping, the echo label,
and a printable kept unchanged. Do not weaken it. Do not move
those cases into the timing file.

If the repaired frame's median on this machine is 80 ms or more,
stop and report the number. Do not raise the bar. Do not start
the `take` / `drop` / `append` rewrite.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/safe-cell-scan.rkt
TMPDIR=/tmp raco test -y tests/aloemacs/safe-cells.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
```

If those are green, `TMPDIR=/tmp raco test -y tests`.
`git diff --check` clean.

The timing file's printed median is part of the result. Record it.

Stop. Do not issue 001. Do not issue safe-cells 001.

## Non-goals

- A new String or character-code message
- Replacing the recursive `take` / `drop` / `append` walk
- Changing `file.aloe`, the echo row, or search keys
- Editing the safe-cells spec, or rewriting its 33-equality
  sentence
- Putting the bar only in `module+ main`, or widening the
  one-character fixture in `index-002-timing.rkt`
- `raco demod`, a resident process, or a change to launch commands
