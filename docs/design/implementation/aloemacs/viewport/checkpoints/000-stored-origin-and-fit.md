# aloemacs-viewport 000 — Stored origin and fit

**Status.** Ready to implement.

## Goal

Give `AloemacsEditor` immutable first-visible line and column payloads and a
pure `ensure-visible` send. Forward that send through `AloemacsSession`,
initialize the origin in the empty and visited editors, and preserve it through
all existing transitions. A checked driver with no Term can exercise this
slice.

Stop after the fit behavior and focused tests are green. `frame` continues to
use its existing point-derived origin until aloemacs-viewport 001. Do not
change the runner or its fit-before-frame order in this checkpoint.

## Authority and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-viewport 000**, the first local checkpoint of the
  **aloemacs-viewport** series. There is no predecessor viewport checkpoint.
  Aloemacs Text, Loop, File, and Index are the implemented predecessors.
- The governing spec sections are §1–4, §5's fit algorithm and invariants,
  §7 “Layer 1 — stored origin and fit,” and §8's retained boundaries. In §5,
  the stored-origin *frame* behavior belongs to the next checkpoint; the
  origin fields and `ensure-visible` belong here.
- The project root for code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. The accepted spec and
  this checkpoint live in its `docs/design/implementation/aloemacs/viewport/`
  folder. `SPEC.md` remains Aloe language law: a list is a send to its head,
  its second element is a literal selector, and function objects run only
  through `call`. Do not add language forms, mutation, inheritance, or
  implicit `Int`/`Float` conversion.
- The starting editor has three fields (`text`, `point`, `quit`) and derives
  `frame`'s `top` and `left` from point. The session has three fields
  (`editor`, `fs`, `path`), delegates `frame`, and rebuilds on edits. The
  runner currently frames before reading each key. Keep these predecessor
  behaviors except for the state and fit additions below.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe`
- `examples/aloemacs/file.aloe`
- `examples/aloemacs/main.aloe`
- `tests/aloemacs/viewport-editor.rkt` (new)
- `tests/aloemacs/editor-keys.rkt`
- `tests/aloemacs/frame.rkt`
- `tests/aloemacs/index-001-editor-movement.rkt`
- `tests/aloemacs/index-002-frame.rkt`
- `tests/aloemacs/index-002-timing.rkt`
- `tests/aloemacs/file-session.rkt`
- `tests/aloemacs/runner.rkt` **only** for its exact `main.aloe` source
  expectation

For the existing tests, update constructor expressions and checked type
assertions needed by the two new fields and send. Keep predecessor exact
frame expectations and runner behavior assertions intact. In particular,
the old negative constructor-arity assertion must reject the former
three-argument constructor, while valid five-argument construction succeeds;
continue rejecting wrong types and arities.

### Must leave untouched

- `host/racket/aloemacs-run.rkt`, every other host file, Term and Fs
  implementations, `lib/text.aloe`, other libraries, Gel, `aloe/eval.rkt`,
  and any kernel or compiler file
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, earlier aloemacs
  checkpoints, the accepted viewport spec, and project maps
- All other files, including `tests/aloemacs/file-runner.rkt` and other
  runner logic or tests

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Required state and sends

Append exactly two ordinary `Int` fields to `AloemacsEditor`, after its
existing fields and in this order:

```aloe
(fields
  (text Text)
  (point Position)
  (quit Bool)
  (scroll-row Int)
  (scroll-col Int))
```

Construction becomes
`(AloemacsEditor new text point quit scroll-row scroll-col)`. The new field
selectors are zero-based first-visible source line and zero-based first-visible
character column. In this ASCII layout, one character column is one terminal
cell. The raw constructor is not a validator, but program-created editors
have a valid point and nonnegative origin. Do not add dimensions or an origin
to `AloemacsSession`, `Text`, or Term, or another state class.

Add `(editor ensure-visible columns rows) -> AloemacsEditor` for positive
`Int` dimensions. Both axes use the same independent, half-open fit rule.
For row, let `p = ((editor point) line)`, `old = (editor scroll-row)`, and
`size = rows`; for column, use point column, `scroll-col`, and `columns`:

```text
candidate = if p < old          then p
            else if p >= old + size then p - size + 1
            else                     old
new-origin = max(0, candidate)
```

Return a newly rebuilt editor with the exact receiver `text`, `point`, and
`quit` payloads and the two computed origins. Do not mutate the receiver or
its nested values. If point is within `[old, old + size)` on an axis, keep
that origin except for the nonnegative clamp. Do not recenter, add a margin,
or clamp to a last full page. Repeating a fit with the same point and sizes
must leave both origin payloads unchanged. A raw negative origin is clamped
to nonnegative by fit.

Every existing editor transition preserves both origin payloads exactly:
`insert`, `newline`, `backward-delete`, movement in all four directions,
`request-quit`, `handle-key`, failed edits, edge and unknown-key no-ops, and
post-quit key handling. The command signatures and key policy remain as they
are. Commands need no terminal dimensions and may leave point outside the
stored viewport until a later fit. Preserve the current immutable rebuild
semantics, including no-op rebuilds.

Add
`(session ensure-visible columns rows) -> (AloemacsSession H)` by sending
fit to its nested editor and rebuilding with its exact existing `fs` and
`path`. Keep the session's three fields and constructor. Its `frame` remains
a direct `String` delegation. Session editing and save, including a
successful save's rebuild and a no-op save, carry the editor origin unchanged;
quit does not save. A visit to an existing or missing new-file location
creates a new editor with point `(0, 0)`, `quit = #f`, and origin `(0, 0)`.
The initial editor in `main.aloe` has origin `(0, 0)` as well.

In this checkpoint, leave `AloemacsEditor.frame`, its helpers, and its
point-derived `top` and `left` formula functionally unchanged. No test in
this slice treats frame as a consumer of the stored origin.

## Focused tests

Create `tests/aloemacs/viewport-editor.rkt` using a checked Aloe driver.
Test product behavior through Aloe sends; a Racket harness may build
expressions and compare results, but must not implement the fit rule as a
second product path. Cover:

1. Exact checked five-field constructor, `scroll-row` and `scroll-col` field
   types, editor fit result type, session fit result type, and rejection of
   wrong arities or types. Assert the session still has only `editor`, `fs`,
   and `path` as stored fields.
2. The initial editor and both regular-file and missing-file visits start
   with origin `(0, 0)`, while a visit resets a previously scrolled editor.
   Prove the session fit keeps its existing `fs` and `path` and stores the
   fitted editor, with no duplicate origin on the session.
3. Immutability: after fit, the original editor and session retain their
   original payloads; `text`, `point`, `quit`, `fs`, and `path` are preserved
   in the fitted results.
4. Origin preservation through successful insertion, newline and backward
   delete, all four movements, request-quit, an unknown-key no-op, a failed
   edit, a post-quit key, and session save success/no-op. Include cases where
   a command moves point outside the old viewport without moving its origin.
5. Independent vertical and horizontal fit with dimensions `1` and larger:
   staying inside a window; crossing its top, bottom, left, and right edges;
   a point several lines or columns outside; an old origin greater than
   point; clamping a raw negative origin; and fitting twice idempotently.
   Crossing only one axis must not change the other. The size is positive
   throughout these tests.

Update existing tests only within the file scope above so every constructor
fixture has the correct two `Int` payloads and the preserved type, state,
movement, source, and exact-frame assertions still run. Keep old
point-derived frame goldens in this intermediate checkpoint. Do not assert
stored-origin ANSI frames or fit-before-frame runner behavior yet.

## Verification and completion

From the project root, run:

```sh
raco test tests/aloemacs/viewport-editor.rkt
raco test tests/aloemacs
```

This checkpoint is complete when the new checked fit and forwarding tests
pass, the existing aloemacs suite remains green with its predecessor frame
goldens, all constructor sites in the permitted files use the five-field
editor, and no out-of-scope file or behavior has changed. No physical TTY is
needed. Report the test results and files changed, then stop for human
review. Do not start aloemacs-viewport 001.
