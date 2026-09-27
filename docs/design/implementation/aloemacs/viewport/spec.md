# aloemacs viewport specification

**Status: Accepted.** This is the complete design input for the
aloemacs-viewport checkpoint manager and implementers. It is
not Aloe language law. `SPEC.md` governs Aloe; this file governs only the
viewport change described here. A later conversation writes one checkpoint at
a time. No checkpoint or product code is part of this design conversation.

The editor remembers the first visible line and column. Point still moves by
the existing key commands. When terminal dimensions are known, a pure
`ensure-visible` send moves the origin only far enough to bring point into the
window. `frame` then paints from that stored origin. Thus Up from the last
screen row moves the cursor up inside the same window.

## 1. Checkpoint series

The local series identity is **aloemacs-viewport**. Its first checkpoint is
spoken **aloemacs-viewport 000** and filed as
`checkpoints/000-slug.md`; later numbers are three digits, never renumbered,
with lowercase hyphenated slugs. The manager writes only the next checkpoint
and stops. Each implementer builds and tests only that checkpoint, then stops.
The project root for code and tests is
`/home/dharmatech/journal/2026-09-02-aloe-racket`; this design folder holds
the spec and future checkpoint documents, not product code.

The intended order is:

1. **Stored origin and fit.** Add origin payloads and `ensure-visible` to
   `AloemacsEditor`, forward fit through the session, initialize and reset
   the origin, and update constructor fixtures. The pure fit API is testable
   with a checked driver and no Term. `frame` still uses its predecessor
   formula until the next layer.
2. **Frame from stored origin.** Make direct editor and session frames paint
   from the fitted origin; replace the old formula's behavioral goldens with
   exact stored-origin frames.
3. **Runner fit and resize.** Fit the current session with the current Term
   dimensions before each full-frame write, and prove the order and resize
   behavior with a scripted Term double.

A checkpoint manager may split a layer if it is too large for one implementer
conversation. It must preserve this order, keep each slice independently
testable, and add no behavior beyond this spec. These three layers are the
intended checkpoints 000, 001, and 002; the manager may add a number only to
split an oversized layer, never to add a feature. Layer 1's direct fit API
and layer 2's fitted frame are tested before layer 3 makes the interactive
runner use them.

## 2. Product boundary and authority

This is one buffer in one terminal viewport. It stores an immutable origin,
fits point to positive `columns` and `rows`, and draws the same complete ANSI
frame as before. `Text` retains its zipper and owns line focus; point is the
editor's `Position`. The session still owns filesystem and path state. Visit,
save, exact `to-string`, all existing keys, and one-string `term write` remain
as implemented.

This spec supersedes only the point-derived `top` and `left` formulas in
`../loop/spec.md` §6 and the “no persistent viewport” rule in
`../index/spec.md`. Loop's ANSI byte order, clipping, empty-row padding,
one-based cursor position, movement, and key semantics still apply. Index's
focused `Text` and bounded visible-row rendering still apply.
`../file/spec.md` still governs session, visit, save, and runner effects except
for the fit-before-frame sequence here. `../README.md` governs the aloemacs
project boundary. `SPEC.md` wins on Aloe syntax, checking, and evaluation.
The current `examples/aloemacs/editor.aloe` and
`host/racket/aloemacs-run.rkt` are implementation starting points, not
authority over this changed behavior.

Legmacs `buffer.lg` `ensure-visible` supplies the minimal scroll rule, and
`render.lg` `scroll-to-fit` supplies the fit-before-render order. Its
scroll-anchor, recenter, display-column expansion, and other UI behavior are
outside this layer. Chez Emacs `paint.sls` `scroll-window!` is a seam catalog
only; its mutation, wrapping, and `scroll-margin` are not adopted.

No windows or per-pane views, `scroll-margin`, recenter or `C-l`, new page
keys, wrapping, tab display-column mapping, `wcwidth`, paint cache, dirty
rectangles, mutation, compiler, or kernel `Vector` belongs to this series.
There is no change to `lib/text.aloe`, Term, Fs, Gel, `aloe/eval.rkt`,
`SPEC.md`, `CHECKPOINTS.md`, or the global checkpoint spine. This series does
not start Boids.

## 3. Host, layout, and commands

Product behavior is checked Aloe 0.1 in
`examples/aloemacs/editor.aloe`, `file.aloe`, and `main.aloe`. The existing
Racket `host/racket/aloemacs-run.rkt` remains the effect and iteration skin.
Tests use the checked driver and host doubles under `tests/aloemacs/`; no
physical TTY is required. No new host selector, crossing type, or library
class is introduced.

From the project root, use `raco test tests/aloemacs` for the focused suite
and `raco test tests` for the full repository suite. Run the application with
`racket host/racket/aloemacs-run.rkt` or
`racket host/racket/aloemacs-run.rkt path`. These are the existing setup,
test, and run tools; no dependency or build step is added.

## 4. State, sends, and invariants

`AloemacsEditor` is the sole owner of the origin. Append two ordinary `Int`
payloads to its existing fields, in this exact order:

```aloe
(define-class AloemacsEditor
  (fields
    (text Text)
    (point Position)
    (quit Bool)
    (scroll-row Int)
    (scroll-col Int))
  (methods ...))
```

Construction is
`(AloemacsEditor new text point quit scroll-row scroll-col)`. The two new
field selectors are the zero-based first visible source line and zero-based
first visible character column. In the existing ASCII layout model, a
character column is one terminal cell. There is no second origin on
`AloemacsSession`, `Text`, the runner, or Term. The session's three fields and
constructor are unchanged.

The new editor send is:

```aloe
(editor ensure-visible columns rows) ; Int Int -> AloemacsEditor
```

Both dimensions must be positive, as for `frame`. It returns a newly rebuilt
editor with the same `text`, `point`, and `quit` payloads, and with the origin
computed by §5. It changes neither the receiver nor its nested values. A
valid editor has a valid point and nonnegative origin. The raw constructor is
still not a validator: callers may construct arbitrary `Int` origins, and
`ensure-visible` clamps its result to nonnegative values. Program-created
editors start and remain valid.

Every existing editor transition, including insert, newline, backward
delete, all movement, request-quit, unknown-key no-op, failed edit, and
post-quit `handle-key`, carries `scroll-row` and `scroll-col` unchanged.
Commands still have their old arities; `handle-key` is still
`String -> AloemacsEditor` and does not receive terminal dimensions. A
command may leave point temporarily outside the stored viewport. The next
fit, when size is known, restores visibility. This is immutable rebuild, not
`set!` or an effectful frame.

`AloemacsSession` forwards
`(session ensure-visible columns rows) -> (AloemacsSession H)` by sending to
its nested editor and rebuilding with the exact existing `fs` and `path`.
`(session frame columns rows)` remains a direct `String` delegation. Tests
can inspect the origin through `((session editor) scroll-row)` and
`((session editor) scroll-col)`; the session has no stored copy and needs no
additional origin accessors. Visit creates its new nested editor with point
`(0, 0)`, `quit = #f`, and origin `(0, 0)`, whether the visited file exists
or is a missing new-file location. The empty initial editor in `main.aloe`
also has origin `(0, 0)`. Save, including its success/no-op rebuild, carries
the nested origin unchanged. Quit never saves.

## 5. Fit and frame

For positive dimensions, let `p-row = (point line)`,
`p-col = (point column)`, `old-row = (editor scroll-row)`, and
`old-col = (editor scroll-col)`. `ensure-visible` computes each axis
independently:

```text
candidate-row = if p-row < old-row         then p-row
                else if p-row >= old-row + rows
                                             then p-row - rows + 1
                else                              old-row
candidate-col = if p-col < old-col         then p-col
                else if p-col >= old-col + columns
                                             then p-col - columns + 1
                else                              old-col
scroll-row = max(0, candidate-row)
scroll-col = max(0, candidate-col)
```

The windows are half-open intervals
`[scroll-row, scroll-row + rows)` and
`[scroll-col, scroll-col + columns)`. If point is already inside an axis, that
origin stays where it is, including after a resize. There is no automatic
recenter, scroll margin, or clamp to the last full page. Calling
`ensure-visible` twice with the same point and dimensions has the same
payloads as calling it once. Horizontal and vertical adjustment are
independent: crossing the right edge does not change `scroll-row`, and
crossing the bottom does not change `scroll-col`.

`(editor frame columns rows) -> String` remains pure. Its caller must first
fit that editor for those same positive dimensions; normal program and
normative frame tests obey this precondition. `frame` reads the stored
`scroll-row` and `scroll-col` and does not calculate a new origin or return a
new editor. In particular, it does not silently fit and lose the result.
Rendering starts at stored `scroll-row`; each existing source line uses
`((line drop scroll-col) take columns)`. Index's focused-`Text` walk from
point to the first visible row, then through at most `rows` visible rows,
remains in force. It does not send `Text.lines` or `Text.to-string` or seek
from the first line on every frame. Missing source rows are empty; rows are
joined by CRLF with no CRLF after the final row.

The cursor coordinates are still one-based:

```text
cursor-row    = point.line   - scroll-row + 1
cursor-column = point.column - scroll-col + 1
```

After fit, both are within the positive dimensions. The complete frame still
has exactly Loop §6.1's bytes: hide cursor, clear screen, home, exactly
`rows` clipped/padded rows, cursor position, show cursor. The runner writes
that one `String` once per frame. No Term or ANSI method changes.

At 8 columns by 4 rows with lines `zero`, `one`, `two`, `three`, `four`,
`five`, starting from point `(0, 0)` and origin `(0, 0)`, three Down keys
with a fit before each frame put point on source line 3, origin row 0, and
screen cursor row 4. One Up followed by fit leaves origin row 0 and moves
the cursor to screen row 3. A later Down to source line 4 shifts origin to
row 1, placing point on screen row 4. Up back to line 3 keeps origin row 1
and puts the cursor on screen row 3. Repeated Up keeps row 1 until point
would leave its top, then origin becomes point's line. The same rule makes
Left walk left within a horizontally scrolled window before `scroll-col`
decreases.

For that fixture, the full 8-by-4 frames at point lines 3 and then 2 are,
respectively, these exact strings (the displayed `\u001b` denotes one ESC
character in the resulting Aloe string):

```text
\u001b[?25l\u001b[2J\u001b[Hzero\r\none\r\ntwo\r\nthree\u001b[4;1H\u001b[?25h
\u001b[?25l\u001b[2J\u001b[Hzero\r\none\r\ntwo\r\nthree\u001b[3;1H\u001b[?25h
```

After scrolling to origin row 1, the following Up from point line 4 to 3
keeps the body `one\r\ntwo\r\nthree\r\nfour` and changes only the cursor
suffix from `\u001b[4;1H` to `\u001b[3;1H`.

The old Loop exact frames for a point far below or right of origin remain
valid **after an explicit fit** if that fit lands on their old derived
origin. Other old frame expectations are revised to the stored-origin
goldens; the old formula is not a continuing contract.

## 6. Runner and resize

Keep `run-aloemacs`, `run-aloemacs-with-term`, and
`run-aloemacs-with-hosts` and their current arities, startup visit rules,
and quit behavior. In each iteration, including the first frame before any
key, the Racket runner does exactly this in order:

1. Query `(term columns)` once and `(term rows)` once. Retain those two
   `Int` values for this iteration.
2. Rebind `aloemacs-editor` to
   `(aloemacs-editor ensure-visible columns rows)` through the checked
   driver.
3. Compute `(aloemacs-editor frame columns rows)` using those **same**
   values, then send its one `String` to `(term write ...)` once.
4. Read one `(term read-key)`, send `handle-key`, and rebind the returned
   immutable session.
5. If the session is quit, stop without another frame; otherwise repeat.

The runner may hold the two returned dimensions as Racket local integers
and inject them as Aloe `Int` literals into the fit and frame expressions.
It contains no origin arithmetic, key table, editing policy, ANSI literal,
or new Term operation. It does not query size again between fit and frame.
The existing two size queries, one write/flush, and one key read per drawn
iteration remain observable to Term doubles.

Resize is a size query on the next iteration, not a `read-key` event.
With the newly queried dimensions, `ensure-visible` preserves each old origin
if point is inside that new axis's window, or shifts that axis by the minimal
rule in §5 if point would be outside. A growing window does not pull the
origin toward zero merely to fill newly available cells. A shrinking window
does not move the origin if point remains visible. Frame uses the same size
that caused the fit. A quit key still ends without another size query or
redraw.

## 7. Layer scopes and verification

### Layer 1 — stored origin and fit

Permitted product files are `examples/aloemacs/editor.aloe`,
`examples/aloemacs/file.aloe`, and `examples/aloemacs/main.aloe` only.
Create focused `tests/aloemacs/viewport-editor.rkt`. Adjust existing tests
under `tests/aloemacs/` only to update constructor sites and checked types:
`editor-keys.rkt`, `frame.rkt`, `index-001-editor-movement.rkt`,
`index-002-frame.rkt`, `index-002-timing.rkt`, `file-session.rkt`, and
`runner.rkt`'s exact `main.aloe` source expectation. Other runner logic and
tests stay for layer 3. An old negative constructor-arity assertion is
updated to reject the old three-argument form and wrong types/arity for the
five-argument form; it must not falsely reject the new constructor.

Tests prove the exact field and send types, initial and visit origin `(0, 0)`,
session forwarding without duplicate origin storage, immutability of old
editor/session values, unchanged origin through edits, movement, no-ops,
save, and quit, and independent fit of both axes. Use positive sizes 1 and
larger. Check staying inside a window, crossing each edge, multiple-line
movement, an origin greater than point, clamping a raw negative origin, and
idempotent fit. At this intermediate stop, `frame` still uses the Loop/Index
point-derived formula and its existing exact-frame goldens stay green. The
stored origin and `ensure-visible` are independently asserted; no test in
this layer pretends that frame consumes them yet.

After layer 1, run `raco test tests/aloemacs`. Existing runner fixtures
retain the predecessor frame behavior. No runner production file is edited
in this layer.

### Layer 2 — frame from stored origin

Permitted product file is `examples/aloemacs/editor.aloe` only. Adjust
`tests/aloemacs/frame.rkt`, `tests/aloemacs/index-002-frame.rkt`,
`tests/aloemacs/index-002-timing.rkt`, and any direct frame-delegation
assertion in `tests/aloemacs/file-session.rkt`. Add the fitted-frame cases to
`tests/aloemacs/viewport-editor.rkt`. Other product files remain untouched.

Compare exact complete ANSI frame bytes, including the Up path in §5,
horizontal Left behavior, blank rows, clipping, and one-based cursor
coordinates. Direct frame tests fit first when point is outside the
constructed origin; the source editor remains unchanged. Keep the old Loop
exact frames where an explicit fit produces that origin, but revise goldens
that encode the old steady-state formula. Existing Index timing driver, if
run as a hand check, fits between each key and frame while retaining its
bounded visible-row property and final point assertions. The session's
`frame` delegation still returns the nested editor's exact frame.

After layer 2, run `raco test tests/aloemacs`. Existing runner fixtures use
point-visible states, so their simple frame counts and bytes remain green
until layer 3 adds production fit. No runner production file is edited in
this layer.

### Layer 3 — runner fit and resize

Permitted product file is `host/racket/aloemacs-run.rkt` only. Create focused
`tests/aloemacs/viewport-runner.rkt` and adjust
`tests/aloemacs/runner.rkt` and `tests/aloemacs/file-runner.rkt` only as
needed for the new fit-before-frame sequence. Do not change any Aloe class,
host capability, key mapping, or filesystem behavior in this layer.

With scripted Term and Fs doubles, prove first-frame fit ordering (including
a runner-source order assertion, since the initial point and origin are both
zero), exactly one query of each dimension and one complete write/flush before
each key,
the Down-then-Up screen-row behavior, a new size on the next iteration, and
the distinction between shrink (shift only if point exits) and growth (keep
origin if point remains visible). Compare full frame strings, not only
cursor suffixes. Escape/quit still draws no following frame. A rejected
startup visit still draws and reads nothing. No test requires a physical TTY.

After layer 3, run `raco test tests/aloemacs` and `raco test tests`. Existing
Text, Loop, File, Index, Term, Gel, and host tests must remain green. Revise
only assertions that intentionally encoded the old origin or constructor;
do not weaken the ANSI, visit/save, key, or source-string assertions. A
manual interactive check may confirm Up visibly walks upward, but automated
no-TTY tests are the acceptance evidence.

## 8. Acceptance and stop

The series is complete when the editor alone holds immutable first-visible
line and column payloads; all constructor sites initialize or preserve them;
the session forwards fit; and the runner fits with the same queried positive
dimensions before every complete frame, including the first. Point remains
visible after fit. Down to the last screen row followed by Up decreases the
screen cursor row while origin holds; horizontal movement follows the same
rule. Resize uses the next queried size and adjusts only when point exits.
Full-frame ANSI bytes, zipper rendering, keys, visit/save, and Text strings
obey their retained contracts. Focused and full tests pass without a TTY,
and no out-of-layer feature or file change is introduced.

The checkpoint manager writes only the next missing numbered checkpoint; each
implementer stops after its own tests are green.
