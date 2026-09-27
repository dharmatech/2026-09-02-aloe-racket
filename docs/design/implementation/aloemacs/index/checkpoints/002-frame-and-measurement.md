# aloemacs-index 002 — Frame and measurement

**Status.** Ready to implement.

## Goal

Render a complete frame from the editor's focused `Text` by visiting only the
visible rows. Preserve the existing frame bytes and File behavior. Measure
the completed key-plus-frame path near both ends of a 10,000-line source.

This is the last aloemacs-index layer. Stop after its tests, source
inspection, and recorded timing. Do not start Boids or another feature.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is `(aloemacs-index, 002)`, spoken **aloemacs-index 002**. Its
  predecessor is [`001-editor-movement.md`](001-editor-movement.md), which the
  user reports implemented and green: editor transitions retain the focused
  `Text`, with movement tests near line 9,000. Checkpoint
  [`000-text-index-and-algebra.md`](000-text-index-and-algebra.md) supplied the
  immutable Text index and line-local replacement.
- The project root for code, tests, and commands is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- The governing index spec sections are 1–3 for scope and focused `Text`, 5
  for the editor invariant, 6 for frame behavior, 7 for verification and
  timing, and 8 for final acceptance. The accepted
  [`../../loop/spec.md`](../../loop/spec.md), especially section 6, governs
  viewport and exact ANSI bytes. The accepted
  [`../../file/spec.md`](../../file/spec.md) governs visit/save and exact
  strings. [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is Aloe
  language law: evaluation is send, not apply; the head of a list is the
  receiver and its second element is a literal selector.
- `examples/aloemacs/editor.aloe` now carries focused `Text` through keys,
  but `frame` still sends `(text lines)` and its helpers search the list from
  the first line. This checkpoint replaces that rendering traversal.

## Exact file scope

### May edit or create

- `examples/aloemacs/editor.aloe`, only `frame` and its rendering helpers
  (`source-line`, `render-rows`, `frame-ansi`, `max-zero`) as needed for the
  focused visible-row walk; keep public frame signature and bytes
- `tests/aloemacs/index-002-frame.rkt` (new checked, no-TTY frame tests)
- `tests/aloemacs/index-002-timing.rkt` (new standalone no-TTY timing script;
  its timed work belongs in `module+ main`, outside `raco test tests`)

### Must leave untouched

- Editor fields, constructor, key dispatch, movement and edit methods, and
  their already established focus invariant
- `lib/text.aloe`, `examples/aloemacs/file.aloe`,
  `examples/aloemacs/main.aloe`, the runner, Term, Fs, Gel, and all other
  product files
- Existing tests and their behavioral goldens, including complete frame
  strings; put new coverage in the two files above
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, and design documents

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Frame requirements

Keep `(editor frame columns rows) -> String` pure, with the Loop precondition
that both dimensions are positive. It sends no Term message. The runner still
writes its one complete result through `(term write frame)`.

For a valid editor, compute the existing point-anchored origin exactly:

```text
top  = max(0, point.line   - (rows    - 1))
left = max(0, point.column - (columns - 1))
cursor-row    = point.line   - top  + 1
cursor-column = point.column - left + 1
```

Align one local `Text` value to `point.line` with `focus-at` when needed;
active editors are already aligned. Move it up at most `rows - 1` times to
`top`. Render exactly `rows` rows from there. For each existing line, emit
`((current-line drop left) take columns)`, then advance focus down once if a
next line exists. After the final source line, emit empty pad rows without
traversing further. One horizontal `left` applies to every row. Join rows
with CRLF, with no CRLF after the last row.

Wrap that body in the existing ANSI prefix and cursor/suffix sequence from
the Loop spec: hide cursor, clear display, home, body, one-based cursor
position, show cursor. The result must match every existing complete frame
golden byte for byte, including empty frames, vertical and horizontal
clipping, blank pad rows, and the final row. Repeated frames on an active
editor do not change its Text, point, or quit fact. A valid raw cold or
differently focused editor may be aligned locally for rendering, but `frame`
does not store that alignment in the receiver. No new behavior is specified
for an invalid raw point.

The frame path must not send `(text lines)` or `(text to-string)`, split the
whole source, fold all lines, seek from the list head for each row, or derive
a new source string. For an active editor, one-line movement and a frame of
`rows` rows do not depend on absolute cursor depth. A one-time distant
`focus-at` during raw editor setup is allowed.

## Focused tests

Add `tests/aloemacs/index-002-frame.rkt` using `make-driver` and
`driver-eval!`. Use checked Aloe sends without a TTY; do not add a Racket
frame implementation.

1. Compare complete frame strings near the top and bottom of a many-line
   ASCII fixture. Check the visible body, point-derived cursor coordinates,
   unchanged editor state, and repeatability. Construct the lower editor
   with Text already focused near line 9,000.
2. Compare complete bytes for an empty source, an EOF frame with blank pad
   rows, and horizontal clipping across several rows. Include the exact
   CRLF separators and no trailing CRLF.
3. Compare a valid raw cold or differently focused editor with an equivalent
   focused editor at the same point. Their frames must match while the raw
   receiver remains structurally unchanged.
4. Run the existing `frame.rkt` goldens and the Text, editor, File, key
   mapping, and runner regressions unchanged. File visit/save must still
   round-trip exact UTF-8 content without CRLF conversion.

Inspect the completed `frame` and motion paths to confirm there is no
whole-buffer split, `to-string`, line-list fold, or repeated head-of-buffer
lookup. The timed results below do not replace this structural check.

## Standalone no-TTY timing

Add `tests/aloemacs/index-002-timing.rkt` as a checked-driver script with
timed work only in `module+ main`. It is run explicitly with `racket`, not as
a CI timeout or a test assertion in `raco test tests`.

- Build one source of exactly 10,000 one-character lines: 9,999 repetitions
  of `"x\n"` followed by `"x"`.
- Before starting either timer, split/index the source and construct a
  focused editor at line 0 for the top case and another at line 9,000 for
  the bottom case. The one-time `focus-at 9000` is setup, outside timing.
- For each case, perform 20 consecutive `"down"` keys. Follow **each** key
  with an 80-column by 24-row `frame`, retain the returned editor for the
  next pair, and measure each key-plus-frame pair. Use the checked driver;
  do not call a direct Racket frame algorithm.
- Verify every captured frame body contains exactly 24 `"x"` rows separated
  by CRLF, and verify the final points are `(20, 0)` and `(9020, 0)`
  respectively. Check one-based cursor column 1 in each frame; top-case
  cursor rows are 2 through 21, and bottom-case cursor row is 24 throughout.
  Include the ANSI wrapper in this check so an empty or stale frame cannot
  pass.
- Print the total time and median per pair for **each** location. A median
  below **0.179 seconds per pair** at both locations is the minimum 100×
  improvement over the measured 17.9 seconds per pair; below 0.1 seconds
  is the target. This is a recorded hand check. If either location misses
  the minimum, report the measurements to the design discussion and stop
  without adding a kernel type in this series.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test tests/aloemacs/index-002-frame.rkt tests/aloemacs/frame.rkt
TMPDIR=/tmp raco test tests/aloemacs
TMPDIR=/tmp raco test tests
TMPDIR=/tmp racket tests/aloemacs/index-002-timing.rkt
```

Complete this final checkpoint only when the focused and full repository
tests pass, all existing frame bytes and Text/Loop/File behavior remain
unchanged, the source inspection confirms bounded frame traversal and
immutable editor states, and both recorded timing medians meet the minimum.
Report changed files, test results, the top and bottom timing totals and
medians, and the frame/point validation. Then stop for human review. Do not
begin another checkpoint or feature.
