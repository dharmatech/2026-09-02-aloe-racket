# aloemacs index specification

**Status: Accepted.** This is the complete design input for the
aloemacs-index checkpoint manager and implementers. It is not Aloe language
law. `SPEC.md` governs the language. The accepted Text, Loop, and File specs
govern behavior; this spec changes only the Text storage and the editor's way
of finding lines.

## 1. Checkpoint series and boundary

The local identity is **aloemacs-index**. Checkpoint 000 is spoken
**aloemacs-index 000** and filed as `checkpoints/000-slug.md`. Numbers have
three digits, start at 000, and are never renumbered. Slugs use lowercase
words separated by hyphens. The checkpoint manager writes one checkpoint and
stops. Each checkpoint is implemented and tested in its own conversation;
implementation stops when that checkpoint is green. A manager may split a
layer that is too large for one implementer conversation, preserving the order
below and adding no features.

The project root for code and tests is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. This design folder holds
the spec and checkpoints only. The intended order is:

1. **Text index and algebra.** Give `Text` an immutable focused line form,
   exact conversions, valid positions, and line-local replacement. Keep every
   existing Text test green.
2. **Editor movement.** Carry the focused `Text` through Up, Down, Left, Right,
   edits, and no-ops. Keep the existing editor and File behavior green.
3. **Frame and measurement.** Render from the focused visible lines; prove
   unchanged bytes and record top and bottom timing.

These are the layer boundaries for checkpoint file scopes:

| Layer | Product files it may edit | Focused verification |
|---|---|---|
| Text index and algebra | `lib/text.aloe`; `examples/aloemacs/file.aloe` only for visit construction | Text tests and `file-session.rkt` |
| Editor movement | `examples/aloemacs/editor.aloe` | `editor-keys.rkt`, `file-session.rkt`, and existing `frame.rkt` |
| Frame and measurement | `examples/aloemacs/editor.aloe` | `frame.rkt`, editor/File regressions, and the recorded no-TTY timing |

Each layer may create or adjust focused tests under `tests/aloemacs/`.
Files not named for that layer stay untouched. Layer 1 leaves the old editor
algorithm in place; layer 2 leaves its frame algorithm in place. Existing
behavioral tests must pass at each stop, even when performance is only
complete after layer 3.

The work ends there. It does not start Boids, a compiler, a kernel `Vector`,
mutation, a paint cache, highlighting, windows, or keymaps.

## 2. Host, files, and authority

The implementation is checked Aloe 0.1, driven by Racket tests. `Text` and
the editor are Aloe classes; Racket is only a test driver and the existing
runner. There is no new host selector or kernel message. Use the repository's
existing `racket` commands and checked driver. From the project root, run
focused tests with, for example, `raco test tests/aloemacs/002-text-view-validity.rkt
tests/aloemacs/003-text-edits.rkt`, then the editor and File tests with
`raco test tests/aloemacs/editor-keys.rkt tests/aloemacs/frame.rkt
tests/aloemacs/file-session.rkt tests/aloemacs/file-runner.rkt`. Run the full
suite with `raco test tests` after the final layer. The application is run
with `racket host/racket/aloemacs-run.rkt [path]`; benchmark scripts use the
checked driver without a TTY.

Permitted product files are `lib/text.aloe`,
`examples/aloemacs/editor.aloe`, and `examples/aloemacs/file.aloe` only to
make `visit` build a focused `Text`. Tests live under `tests/aloemacs/`.
Existing tests may change their construction helpers or representation-only
structural assertions when the focused representation requires it; their
behavioral goldens, including complete frame strings, do not change.
`examples/aloemacs/main.aloe`, the runner, Term, Fs, Gel, `aloe/eval.rkt`,
`SPEC.md`, `CHECKPOINTS.md`, and global checkpoints stay outside this series.

For behavior, `../text/spec.md` governs `from-string`, `to-string`, lines,
positions, spans, and replacement; `../loop/spec.md` governs editor keys,
movement, viewport, and ANSI bytes; `../file/spec.md` governs visit/save and
exact UTF-8 strings. This spec supersedes only their internal storage and
lookup strategies. The parent `../README.md` governs immutability and project
scope. `examples/aloemacs/editor.aloe` is the current implementation to
replace. Legmacs `buffer.lg` and `render.lg`, and Chez Emacs `text.sls`, are
seam examples: line-based movement, visible-row rendering, and immutable line
strings. Their newline normalization, mutable state, highlighting, and screen
caches are not Aloe behavior.

## 3. Representation: one source of text

`Text` has two **alternative** immutable constructor forms, never a source
string beside a line cache:

```aloe
(define-class Text
  (constructors
    (from-string (fields (source String)))
    (indexed (fields
      (above (List String))
      (current String)
      (below (List String))
      (focus Int))))
  (methods ...))
```

`(Text from-string source)` stays source-compatible. It is a cold value whose
only text payload is the exact source string. `(text focus-at n)` converts it
to `indexed` once by splitting at LF, then walks to line `n`. A focused value
has `above` in reverse order (nearest preceding line first), `current` at
zero-based `focus`, and `below` in forward order (nearest following line
first). The complete line sequence is `reverse(above)`, `current`, `below`.
It is nonempty; no line contains LF; `focus` equals the number of lines in
`above`. The final empty line represents a trailing LF. The indexed value
contains no original source string. A raw `indexed` construction outside
these invariants has unspecified behavior; program construction uses the
methods here.

`focus-at : (Int) -> (Option Text)` returns `None` for an invalid line.
On a cold value it splits once; on an indexed value it walks from the current
focus through `above` or `below` by the distance moved, using `first`, `rest`,
and `cons`. It does not call `to-string`, `lines`, or `split-lines` on an
indexed value. It shares all untouched line strings and list tails. This
operation is for initial indexing, arbitrary-position algebra, and the
bounded move from point to viewport top; it is not a head-of-buffer lookup on
every key. `focus-at` never changes its receiver.

The indexed accessors are `focus-line : () -> Int`,
`current-line : () -> String`, `has-previous? : () -> Bool`, and
`has-next? : () -> Bool`. `focus-up : () -> Text` and
`focus-down : () -> Text` shift one line in constant list operations; at an
edge they return an equal value. These sends first index a cold value at line
0 if necessary. Callers use `has-previous?`/`has-next?` before crossing an
edge. Current and adjacent line lengths come from `current-line` after at
most one focus shift, never from a fold over all lines.

The existing `lines : () -> (List String)` remains an exact view. On an
indexed value it reconstructs the full list only for an explicit `lines`
send. `to-string : () -> String` returns the cold source directly or joins
the indexed lines with one LF between neighbors. `to-string` is a full-buffer
conversion for save and tests; no movement or `frame` may send it. The two
forms agree on all public Text behavior:

```text
(Text from-string "")          -> lines [""]
(Text from-string "a\nb")      -> lines ["a", "b"]
(Text from-string "a\n")       -> lines ["a", ""]
(Text from-string "a\r\nb")    -> lines ["a\r", "b"]
```

For every source `s` and valid focus `n`, focusing then sending `to-string`
returns exactly `s`, including multiple final LFs, CR, BOM, and Unicode.
The focused line strings and their order are the sole content authority.

## 4. Text validity and replacement

`Position`, `Span`, `EditResult`, and all existing Text send names, types,
half-open semantics, and `Option` failure results remain as in the Text spec.
`valid-position?` checks a nonnegative line by attempting `focus-at`, then
checks `0 <= column <= current-line.len`. `valid-span?` checks both endpoints
and their order. On indexed values these methods walk only as far as the
requested positions; they do not rebuild `lines` or the source string.

`replace` first validates the span. An invalid span yields `None` and does
not alter the input. For a valid span it focuses at the start line, traverses
to the end line, and takes the prefix before the start column and suffix after
the end column. It splits only the **replacement string** at LF. With one
piece, the new current line is `prefix + piece + suffix`. With several
pieces, the first new line is `prefix + first-piece`, the last is
`last-piece + suffix`, and intermediate pieces are lines as supplied. The
untouched lines before the start and after the end keep their immutable
strings and share list tails where possible. The returned `Text` is indexed
at the returned `EditResult.position`, the end of the insertion. There is no
whole-source concatenation, whole-buffer resplit, or shadow line list on
every edit. A cold input is converted to indexed once during this operation.

This construction must equal the old Text spec's flat-string definition:
`old.take(a) + replacement + old.drop(b)` for valid flat offsets `a,b`.
The implementation does not compute those offsets or materialize that old
string. `insert`, `delete`, and `newline` still delegate to `replace` and
return the same `Option EditResult`. In particular, deleting the LF before
the focused line joins it to its predecessor, and inserting a final LF leaves
a final empty line. Every successful edit returns a new `Text`; no nested
value changes in place.

## 5. Editor ownership and transitions

`AloemacsEditor` retains exactly the fields and constructor
`(text Text)`, `(point Position)`, `(quit Bool)`, and
`(AloemacsEditor new text point quit)`. The session retains its fields and
its delegated commands. No persistent viewport, duplicate line array, or
stored source string is added to the editor or session. The editor owns the
point; its `Text` owns the index. For an actively indexed editor, the
invariant is `(text focus-line) = (point line)`. Every command preserves it.

The raw editor constructor cannot validate or align its fields. Existing
callers may construct a valid point with a cold or differently focused Text.
Before a command needs a line, it sends `focus-at point.line` once and uses
the returned focused value. An invalid raw point retains the Loop behavior:
an unsuccessful edit is an equal no-op; valid program states remain valid.
The ordinary running path starts focused: `AloemacsSession.visited` converts
the newly read `(Text from-string contents)` with `focus-at 0` before creating
its point-0 editor. The empty `main.aloe` source has one line, so its initial
cold conversion is bounded; no `main.aloe` change is needed. The File test
that checks the visited `Text` structurally must compare with an equivalently
focused `Text`, while also retaining the exact source-string assertion.

On Up and Down, test `has-previous?`/`has-next?`, shift `Text` one line,
increment or decrement `point.line`, and clamp `point.column` to the new
current-line length. At an edge return an editor structurally equal to the
receiver, including a raw cold receiver. Left and Right within a line change
only the point column. Across LF, shift `Text` once and use respectively the
previous line's end or next line's column 0. At the beginning or end of the
buffer they remain equal no-ops. `line-length` and any clamp helper used on
these paths read the focused current or adjacent line, never `(text lines)`
or a fold from the first line. There is no remembered goal column.

`insert`, `newline`, and `backward-delete` keep the same span and
`EditResult` contracts. The editor uses the returned indexed `Text` and
returned position together; it does not splice the line a second time.
Deleting at column 0 obtains the preceding length by one `focus-up`, then
deletes the intervening LF through `Text.delete`. `request-quit`, unknown
keys, failed edits, and post-quit keys preserve the existing content and
structural no-op rules. The runner may still rebind `aloemacs-editor` between
immutable sessions.

## 6. Frame

`frame(columns, rows)` retains the Loop precondition that both dimensions
are positive and returns one complete `String`. It computes the same
point-anchored `top` and `left`, cursor row and column, clipped text, CRLF row
separators, and ANSI prefix/suffix as `../loop/spec.md` section 6. It sends
no Term message. The runner still sends the whole result once with
`(term write frame)`.

The implementation aligns a local `Text` value to `point.line`, moves up at
most `rows - 1` times to `top`, then renders exactly `rows` rows. For each
existing line it uses `((current-line drop left) take columns)` and shifts
down once. After the final source line, it emits empty pad rows without
traversing the tail. It never sends `(text lines)` or `(text to-string)`,
walks from the head for each row, or derives a new source string. Repeated
frames on an active editor use the persistent focused value but do not mutate
it. For positive dimensions, output bytes are exactly the existing Loop
goldens, including the last row having no trailing CRLF.

## 7. Verification and performance

Each layer adds checked, no-TTY tests under `tests/aloemacs/` and runs them
with its existing predecessor tests. Do not weaken old behavioral assertions.

- Text tests cover cold and focused exact `to-string`/`lines` for empty,
  internal empty, final empty, repeated LF, CRLF, BOM, and Unicode sources;
  valid/invalid positions at different focuses; up/down edges; and all Text
  replacement goldens on cold and focused inputs. They check the original
  values remain unchanged and the result focus equals the result position.
- Movement tests use a many-line ASCII fixture and check Up, Down, Left,
  Right, clamping, LF crossing, EOF no-op, and immutable old editors near
  line 9,000. Existing `editor-keys.rkt` stays green.
- Frame tests compare complete frame bytes near both ends, including blank
  pad rows and horizontal clipping. Existing `frame.rkt`, File visit/save,
  key mapping, and runner tests stay green. Save/visit still round-trip the
  exact `(text to-string)` through strict UTF-8 with no CRLF conversion.

Record a no-TTY hand timing in the final checkpoint's completion report.
Build one source of 10,000 one-character lines: 9,999 repetitions of
`"x\n"` followed by `"x"`. Before timing, construct a
focused editor at line 0 for the top case and at line 9,000 for the bottom
case; initial splitting and the one-time `focus-at 9000` are setup. For each
case, perform 20 consecutive `"down"` keys, following **each** with an
80-column by 24-row `frame`, retaining the returned editor. Time the 20
key-plus-frame pairs, report total and median per pair, and verify the frame
body and final point so an empty shortcut cannot pass. A median below
0.179 seconds per pair is the minimum 100× improvement over the measured
17.9 seconds per pair; target below 0.1 seconds. This is a recorded hand
check, not a CI timeout. If it misses the minimum, return the result to the
design discussion instead of adding a kernel type in this series.

Structural checks are mandatory even when timing passes: no motion or frame
path may split the whole source, call `to-string`, fold all lines, or seek
from the list head at each key. A distant initial `focus-at` is a one-time
setup operation; current-line access, a one-line step, and a frame of
`rows` rows do not depend on absolute cursor depth.

## 8. Acceptance and stop

The series is complete when Text has one canonical content representation
per value, all edits and editor states stay immutable, every Text/Loop/File
behavioral test passes, full frame bytes remain unchanged, and both 10,000
line timing locations meet the minimum in section 7. The full repository
test suite passes. No implementation adds mutation, a compiler, a kernel
`Vector`, source-string scanning as the steady-state index, incremental
paint, syntax highlighting, Unicode cell width, windows, or keymaps.

After human acceptance of this spec, the checkpoint manager writes only the
next missing checkpoint. An implementer completes only that checkpoint,
tests it, and stops. Neither role takes an adjacent layer without a new
conversation and assignment.
