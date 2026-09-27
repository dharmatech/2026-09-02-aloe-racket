# aloemacs-viewport 001 — Frame from stored origin

**Status.** Ready to implement.

## Goal

Make the pure `AloemacsEditor.frame` send render from the editor's stored
`scroll-row` and `scroll-col`. Direct editor and session callers first use the
existing `ensure-visible` send for the same positive dimensions. The frame
then returns exact complete ANSI bytes for the fitted window while leaving
the receiver unchanged.

Stop after direct frame behavior and tests are green. The Racket runner still
does not fit before drawing; runner fit, resize, and Term-order tests belong
to aloemacs-viewport 002.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-viewport 001**, the second local checkpoint in the
  **aloemacs-viewport** series. Its predecessor,
  [**aloemacs-viewport 000**](000-stored-origin-and-fit.md), is implemented:
  `AloemacsEditor` has five fields and a pure `ensure-visible`, the session
  forwards fit, and initial and visited editors start at origin `(0, 0)`.
- The governing spec sections are §1–5, §7 “Layer 2 — frame from stored
  origin,” and §8. The retained ANSI byte order is in
  [`../../loop/spec.md`](../../loop/spec.md) §6.1; the focused-`Text` row walk
  is in [`../../index/spec.md`](../../index/spec.md) §6. The accepted viewport
  spec supersedes only their point-derived origin and no-persistent-viewport
  rules. `SPEC.md` remains Aloe language law: a list is a send to its head;
  the second element is the literal selector. Function objects run only via
  `call`.
- The project root for code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. At this starting point,
  `examples/aloemacs/editor.aloe` still derives `top` and `left` from point
  in `frame`. Its `viewport-top`, `render-rows`, and `frame-ansi` helpers
  already provide the bounded row walk, clipping, and complete frame. The
  session already delegates `frame` to its editor. The runner is still at the
  predecessor iteration order.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe`
- `tests/aloemacs/viewport-editor.rkt` (add fitted-frame cases)
- `tests/aloemacs/frame.rkt`
- `tests/aloemacs/index-002-frame.rkt`
- `tests/aloemacs/index-002-timing.rkt`
- `tests/aloemacs/file-session.rkt` **only** for a direct frame-delegation
  assertion if needed

### Must leave untouched

- `examples/aloemacs/file.aloe`, `examples/aloemacs/main.aloe`, and
  `host/racket/aloemacs-run.rkt`
- All other tests, especially `tests/aloemacs/runner.rkt` and
  `tests/aloemacs/file-runner.rkt`
- `lib/text.aloe`, other libraries, Term, Fs, Gel, `aloe/eval.rkt`, any kernel
  or compiler file, `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, the
  accepted viewport spec, earlier checkpoints, and project maps
- Any file not listed under **May edit**

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Frame behavior

Keep `(editor frame columns rows) -> String` pure, with positive `Int`
dimensions. Its caller fits the editor first with `(editor ensure-visible
columns rows)` and frames that returned editor using the **same** dimensions.
The existing `handle-key` and movement sends still do not receive dimensions
or fit themselves. `frame` must not send `ensure-visible` internally: it
returns a `String`, so an internal fit would lose the updated editor value.

Replace only the origin calculation inside `frame`:

```text
top  = (editor scroll-row)
left = (editor scroll-col)
cursor-row    = point.line   - top  + 1
cursor-column = point.column - left + 1
```

For a fitted valid editor, both cursor coordinates are one-based and within
the supplied dimensions. Preserve the stored origin, text, point, and quit
payloads while framing. A frame does not recenter, move the origin toward
zero, or derive a new origin from point. No second origin is stored on the
session, Text, Term, or runner. The session's existing `frame` method remains
an exact `String` delegation to its nested editor; do not edit `file.aloe`.

Render source lines starting at `scroll-row` for exactly `rows` screen rows.
The focused-`Text` walk starts from `point.line`, moves up to the first
visible row, then renders forward through at most `rows` visible rows. It
must not use `Text.lines`, `Text.to-string`, or a head-of-buffer seek for each
frame. Each existing line is `((line drop scroll-col) take columns)`; missing
source rows are empty. Join rows with CRLF and no CRLF after the final row.

The complete frame bytes remain in this order, without extra bytes:
`"\u001b[?25l"` (hide cursor), `"\u001b[2J"` (clear),
`"\u001b[H"` (home), the exactly-`rows` body, `"\u001b[<row>;<column>H"`
(cursor position), and `"\u001b[?25h"` (show cursor). Decimal coordinates
use the existing Aloe `Int text` behavior. `frame` neither writes to Term
nor adds an ANSI or Term method.

## Required frame cases

Use checked driver sends and compare **complete** frame strings, not only
cursor suffixes. For text `"zero\none\ntwo\nthree\nfour\nfive"`, size 8 by
4, and initial point and origin `(0, 0)`, fit after each key:

1. Three `"down"` keys put point on source line 3 and keep origin row 0.
   The cursor is on screen row 4. The complete frame is
   `"\u001b[?25l\u001b[2J\u001b[Hzero\r\none\r\ntwo\r\nthree\u001b[4;1H\u001b[?25h"`.
2. One `"up"` puts point on line 2, keeps origin row 0, and moves the screen
   cursor to row 3. The body remains `zero\r\none\r\ntwo\r\nthree`; the
   complete frame is
   `"\u001b[?25l\u001b[2J\u001b[Hzero\r\none\r\ntwo\r\nthree\u001b[3;1H\u001b[?25h"`.
3. Move down to line 4, fitting after each key: origin becomes row 1 and
   the body is `one\r\ntwo\r\nthree\r\nfour` with cursor row 4. One `"up"`
   back to line 3 keeps row 1 and changes only the cursor suffix to row 3.
   Further Up keys keep row 1 until point would leave the top, when fit moves
   origin to point's line.

For horizontal movement, start from a fitted point at the end of
`"0123456789"` with a narrow width. Left moves the cursor left inside the
same clipped window while `scroll-col` holds; only crossing its left edge
decreases `scroll-col`. Compare full frames, including blank rows and the
one-based column, on both sides of that crossing. A right-edge crossing
likewise shifts only the horizontal origin. Horizontal movement must not
change `scroll-row`.

Retain the old Loop exact 8-by-4 vertical and horizontal frames where an
explicit fit from origin `(0, 0)` lands on their old derived origins. The
source editor remains unchanged by fitting and framing. Revise other
point-derived goldens: they are no longer the steady-state frame contract.
Keep exact blank-row padding, clipping, quit-independent framing, and the
existing tests with cold, focused, and differently focused Text values.

## Tests and verification

In `tests/aloemacs/viewport-editor.rkt`, add the Down/Up sequence above,
horizontal Left and right-edge cases, preserved origin and source editor
checks, complete ANSI bytes, and a direct fitted session frame equal to its
nested editor frame. The latter may live instead in the direct delegation
assertion of `file-session.rkt`; it must not require a Term double. Include
sizes that produce blank rows and clipping, and verify the exact cursor
coordinates after fit.

Update `frame.rkt` and `index-002-frame.rkt` so direct frame tests first fit
when their point is outside the constructed origin. Keep old goldens only
when that explicit fit reaches the same origin, and replace expectations
that rely on the old formula after point moves back inside a stored window.
Preserve exact full-frame comparisons and the unchanged-source assertions.
The large focused-Text cases must still render near both ends of the fixture
without making frame traverse from the source start.

Update the optional no-TTY timing driver in `index-002-timing.rkt` so each
key transition is followed by a fit with 80 columns and 24 rows, then a
frame of that fitted editor. Retain the 10,000-line fixture, 20 transitions
at both start locations, exact frame-body and final-point assertions, and
bounded visible-row behavior. A manual timing run is optional for this
checkpoint; if run, record its result. The runner production file and its
scripted-Term tests are left for the next checkpoint. Existing runner
fixtures use point-visible states and should stay green unchanged.

From the project root, run:

```sh
raco test tests/aloemacs/viewport-editor.rkt tests/aloemacs/frame.rkt tests/aloemacs/index-002-frame.rkt tests/aloemacs/file-session.rkt
raco test tests/aloemacs
```

This checkpoint is complete when fitted direct editor and session frames
match the stored-origin goldens byte for byte, the existing aloemacs suite
passes without a TTY, frame retains its bounded Text walk and pure state,
and no out-of-scope file or behavior changes. Report the tests and files
changed, then stop for human review. Do not start aloemacs-viewport 002.
