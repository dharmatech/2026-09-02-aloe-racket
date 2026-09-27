# aloemacs-index 001 — Editor movement

**Status.** Ready to implement.

## Goal

Carry the focused `Text` with the editor's point through movement, edits, and
no-ops. Make line lookup for a key depend on the current or adjacent line,
including when the point is near line 9,000. Preserve editor, File, and frame
behavior.

Stop when editor transitions and their tests are green. Do not change frame
rendering or run the final key-plus-frame timing; those belong to
aloemacs-index 002.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is `(aloemacs-index, 001)`, spoken **aloemacs-index 001**. Its
  predecessor is [`000-text-index-and-algebra.md`](000-text-index-and-algebra.md):
  the user reports it implemented and green, with immutable focused `Text`,
  line-local replacement, and File visits focused at line 0.
- The project root for code, tests, and commands is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- The governing index spec sections are 1–3 for scope and focused `Text`, 5
  for editor transitions, 7 for movement verification, and 8 for acceptance
  and stop. The accepted [`../../loop/spec.md`](../../loop/spec.md),
  especially sections 2–4 and 8, governs existing editor commands and keys.
  The accepted [`../../text/spec.md`](../../text/spec.md) governs edit results
  and positions. The accepted [`../../file/spec.md`](../../file/spec.md)
  governs session behavior. [`../../../../../../SPEC.md`](../../../../../../SPEC.md)
  is Aloe language law: evaluation is send, not apply; the head of a list is
  the receiver and its second element is a literal selector.
- `examples/aloemacs/editor.aloe` still reconstructs `(text lines)` for
  `line-length`, `move-right`, `move-down`, and `frame`. Its movement helpers
  retain the old `Text` when point changes. This checkpoint replaces the
  transition lookup and storage only. The frame scan remains until 002.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe`, only its line lookup helpers and editor
  transitions: `insert`, `newline`, `backward-delete`, Left, Right, Up, Down,
  no-ops, `request-quit`, and `handle-key` as needed to maintain the focused
  `Text` invariant
- `tests/aloemacs/index-001-editor-movement.rkt` (new checked, no-TTY tests)

### Must leave untouched

- The `frame`, `source-line`, `render-rows`, `frame-ansi`, and viewport
  calculation behavior in `examples/aloemacs/editor.aloe`; their optimization
  belongs to 002
- `lib/text.aloe`, `examples/aloemacs/file.aloe`,
  `examples/aloemacs/main.aloe`, the runner, Term, Fs, Gel, and all other
  product files
- All existing tests, including their behavioral goldens and complete frame
  strings; add this checkpoint's coverage in the new test file
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, and design documents

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Slice requirements

### State and alignment

Keep the exact `AloemacsEditor` fields and constructor: `text Text`,
`point Position`, `quit Bool`, and `(AloemacsEditor new text point quit)`.
Add no persistent viewport, duplicate line array, source string, goal
column, or mutable state. For an actively focused editor, every transition
must keep `(text focus-line) = (point line)`. Movement that changes the point
must return an editor carrying the corresponding focused `Text`, even when
the receiver was constructed with cold or differently focused `Text`.

The raw constructor does not validate or align its fields. Before a command
needs a line, align a local `Text` value with `focus-at point.line` once and
use that value. On the ordinary indexed path this is a same-focus check and
does not resplit or walk from the head. A valid raw cold or misfocused editor
must work on its first command. An invalid raw point keeps the Loop rule:
an unsuccessful edit is an equal no-op. At a movement edge, preserve an
editor structurally equal to the receiver, including a raw cold receiver;
do not turn that no-op into an indexing change.

Keep the existing public command signatures and key dispatch. A direct
command may still act when `quit` is true, as in the Loop spec;
`handle-key` after quit remains absorbing. Successful edits and motion must
not change the old editor or its nested values.

### Movement

- Up and Down check `has-previous?` or `has-next?` on the aligned `Text`,
  shift that `Text` once with `focus-up` or `focus-down`, move `point.line` by
  one, and clamp `point.column` to the new `current-line` length. At the
  first or final line, return an equal editor. There is no remembered goal
  column.
- Left within a line decreases the column and carries a `Text` focused at
  the point's line. Left at column 0 crosses one LF by focusing up once and
  places point at the previous line's end. Left at `(0, 0)` is an equal
  no-op.
- Right within a line increases the column and carries a `Text` focused at
  the point's line. Right at end of line crosses one LF by focusing down
  once and places point at column 0. Right at the final line's end is an
  equal no-op.
- Any `line-length` or clamping helper used by these paths reads the focused
  current or adjacent line. No motion path may send `(text lines)` or
  `(text to-string)`, split the source, fold all lines, or seek from the list
  head for each key. A one-time `focus-at` to align an arbitrary raw editor
  is permitted.

### Edits and no-ops

`insert` and `newline` keep their existing `Text` sends and use the returned
indexed `EditResult.text` and `EditResult.position` together. `backward-delete`
keeps its three Loop cases. For column greater than 0, delete the preceding
character span. At column 0 after the first line, obtain the predecessor's
length through one `focus-up`, then delete exactly the intervening LF through
`Text.delete`. At `(0, 0)`, return an equal editor. Do not splice lines a
second time in the editor.

For `None` edit results, return an editor equal to the receiver. Preserve
structural no-ops for movement edges, unknown keys, repeated quit, and keys
after quit. `request-quit` preserves `Text` and point and sets `quit` true.
Keep the existing key names and one-character insertion rule. The session
continues to delegate its commands and retain exact File visit/save results.

## Focused tests

Add `tests/aloemacs/index-001-editor-movement.rkt`. Use `make-driver` and
`driver-eval!` to exercise Aloe sends without a TTY. Keep the old tests
unchanged and green.

1. Construct active editors from indexed `Text`, then check after every Up,
   Down, Left, Right, insert, newline, backward-delete, quit, and no-op that
   text content, point, quit, point validity, and `text.focus-line` agree.
   Retain prior editor values and prove they remain unchanged.
2. Cover vertical clamping in both directions, including a short middle
   line followed by a longer one to prove there is no remembered goal
   column. Cover within-line horizontal steps, both LF crossings, start and
   EOF edge no-ops, and deletion of the LF before the focused line.
3. Construct valid raw editors with cold and differently focused `Text` at
   nonzero points. Prove the first successful movement or edit aligns the
   returned `Text` with the returned point. Prove raw cold edge no-ops and
   an invalid raw insertion stay structurally equal to their receivers.
4. Use a many-line ASCII fixture with positions around line 9,000. Perform
   consecutive one-line movements, horizontal LF crossings, and a local edit
   there; check each returned point and focus and the unchanged older
   editors. Establish the behavior without a timing threshold or a `frame`
   call on this large fixture.
5. Check that unknown and post-quit keys preserve the focused Text and
   existing key semantics. Run the existing editor, File, frame, and runner
   tests as regressions. Their complete frame strings must remain unchanged.

Inspect the transition paths in `examples/aloemacs/editor.aloe` to confirm
they use focused current or adjacent lines. The existing frame path may
still call `(text lines)` in this checkpoint.

## Verification and completion

From the project root, run:

```sh
raco test tests/aloemacs/index-001-editor-movement.rkt tests/aloemacs/editor-keys.rkt
raco test tests/aloemacs/file-session.rkt tests/aloemacs/frame.rkt tests/aloemacs/file-runner.rkt tests/aloemacs/runner.rkt
raco test tests/aloemacs
```

This checkpoint is complete when the focused movement tests and existing
aloemacs suite pass, moving or editing a focused editor retains the point
and Text focus invariant, all old frame bytes and File behavior are preserved,
and source inspection confirms no full-buffer lookup on a motion path.
No final timing result is required yet because `frame` is still unchanged.

Report the changed files and verification results, then stop for human
review. Do not begin aloemacs-index 002.
