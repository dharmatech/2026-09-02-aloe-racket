# aloemacs-index 000 — Text index and algebra

**Status.** Ready to implement.

## Goal

Give `Text` an immutable focused line representation, preserve its exact
string and line views, and perform validity checks and replacement on lines.
Make File visits construct a line-0 focused `Text`. Keep the existing Text,
editor, and File behavior green.

Stop after this slice. Do not change editor movement or frame algorithms;
those belong to later aloemacs-index checkpoints.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is `(aloemacs-index, 000)`, spoken **aloemacs-index 000**. This is
  the first checkpoint, so there is no predecessor checkpoint in this series.
- The project root for code, tests, and commands is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- The governing index spec sections are 1–4, 5's visit-construction paragraph,
  7's Text and File verification, and 8's scope and stop. The accepted
  [`../../text/spec.md`](../../text/spec.md) governs existing Text behavior.
  The accepted [`../../file/spec.md`](../../file/spec.md) governs visit/save
  behavior. [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is Aloe
  language law: evaluation is send, not apply; the head of a list is the
  receiver and its second element is a literal selector.
- `lib/text.aloe` currently stores a source string and re-splits or folds it
  for lookups and edits. `examples/aloemacs/file.aloe` currently constructs a
  cold `Text` during `visited`. The editor still uses `lines` and retains its
  old movement and frame algorithms in this checkpoint.

## Exact file scope

### May edit

- `lib/text.aloe`
- `examples/aloemacs/file.aloe`, only in `visited` to focus the newly read
  `Text` at line 0
- `tests/aloemacs/index-000-text-focus.rkt` (new focused tests)
- `tests/aloemacs/002-text-view-validity.rkt` and
  `tests/aloemacs/003-text-edits.rkt`, only to extend Text behavior coverage
  or adjust representation-only assertions while retaining their behavioral
  goldens
- `tests/aloemacs/file-session.rkt`, only to compare a visited `Text` with an
  equivalently focused value and assert that visit starts at focus 0; retain
  the exact source-string and visit/save assertions

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, the runner,
  Term, Fs, Gel, and all other product files
- All test files outside the four named paths under `tests/aloemacs/`
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, and design documents

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Slice requirements

### Focused `Text`

Keep `(Text from-string source)` source-compatible. It remains a cold value
whose sole content payload is the exact `String`. Add the alternative
`indexed` constructor with fields in this order and these types:

```aloe
(indexed (fields
  (above (List String))
  (current String)
  (below (List String))
  (focus Int)))
```

An indexed value has `above` in reverse order, nearest preceding line first;
`below` in forward order, nearest following line first; and `focus` equal to
the number of lines in `above`. `current` is the line at that zero-based
focus. The full sequence is `reverse(above)`, `current`, `below`; it is
nonempty, and no line contains LF. A final empty line represents a trailing
LF. The indexed form contains no saved source string or second full line
cache. Raw `indexed` construction outside these invariants has unspecified
behavior.

Add these exact sends:

| Send | Type | Required behavior |
|---|---|---|
| `focus-at n` | `(Int) -> (Option Text)` | `None` for an invalid line; focus the valid line without changing the receiver |
| `focus-line` | `() -> Int` | zero-based focused line |
| `current-line` | `() -> String` | focused line |
| `has-previous?` | `() -> Bool` | whether a preceding line exists |
| `has-next?` | `() -> Bool` | whether a following line exists |
| `focus-up` | `() -> Text` | shift one line up, equal value at top edge |
| `focus-down` | `() -> Text` | shift one line down, equal value at bottom edge |

`focus-at` on a cold value splits its source once and walks to `n`. On an
indexed value it walks from the current focus through `above` or `below` by
the distance moved, using list `first`, `rest`, and `cons`; it must not call
`to-string`, `lines`, or `split-lines`. A move shares untouched line strings
and list tails. The accessors and one-step methods first index a cold value
at line 0 if needed. `focus-up` and `focus-down` use constant list operations
for an already indexed value. These methods do not mutate their receiver.

`lines` and `to-string` keep their public names and types. A cold `to-string`
returns its exact source; indexed `to-string` joins its line sequence with one
LF between neighbors. `lines` returns the exact sequence for either form and
reconstructs the full list only on an explicit `lines` send. The forms agree
for empty content, interior and repeated empty lines, final LF, CRLF, BOM,
and Unicode. For every valid focus `n`, extracting `Some` from
`((Text from-string s) focus-at n)` and sending `to-string` to that `Text`
returns exactly `s`. No movement or frame implementation is added here.

### Validity and replacement

Keep `Position`, `Span`, `EditResult`, and all existing Text send names,
types, half-open span semantics, and `Option` results. `valid-position?`
rejects negative coordinates, focuses at the requested line, and checks the
column against that line's length, including the end column.
`valid-span?` checks both endpoints and their order. On indexed values these
checks must not reconstruct `lines` or the whole source.

`replace` validates first and returns `None` without changing the input for
an invalid span. For a valid span, focus at its start, traverse through its
end, take the start-line prefix and end-line suffix, and split only the
replacement string at LF. One replacement piece forms one new current line;
multiple pieces form the prefixed first line, unchanged interior pieces, and
suffixed last line. Retain the untouched lines before and after the span,
sharing list tails and line strings where possible. Return an indexed `Text`
focused at `EditResult.position`, the end of the insertion. Do not compute
flat offsets or concatenate and re-split the entire source for an edit.

The result must equal the Text spec's flat-string definition for every valid
span. Keep `insert`, `delete`, and `newline` as delegates to `replace` with
the same results. Deleting a line separator joins its neighboring lines;
inserting a final LF leaves a final empty line. Every successful edit returns
a new immutable value, and input values stay unchanged.

### File visit

In `AloemacsSession.visited`, focus `(Text from-string contents)` at line 0
before constructing the point-0 editor. This is valid even for an empty
source. Preserve the session's fields, delegated methods, visit/save
behavior, and exact UTF-8 string round-trip. Change no editor method in this
checkpoint.

## Focused tests

Add checked, no-TTY tests under the allowed paths. Drive production behavior
through Aloe sends with the existing Racket checked driver.

1. Prove the new constructor and focus/accessor signatures, and cold and
   focused `lines`/`to-string` equivalence for `""`, `"a\nb"`, `"a\n"`,
   repeated LF, CRLF, BOM, and Unicode. Retain every existing Text golden.
2. Prove `focus-at` at the first, interior, and final lines; invalid negative
   and past-end lines return `None`. Prove up/down movement and edge values,
   and that the original focused value remains unchanged.
3. Prove valid and invalid positions and spans when the receiver is focused
   at different lines. Test end columns and the final empty line.
4. Run every existing replacement golden on cold and focused receivers,
   including single- and multi-line changes, LF joining, final LF, boundary
   edits, and invalid `None` results. For each success, check the exact
   source, lines, result position, and result text's focus line. Check the
   original text, positions, and spans remain unchanged.
5. Check that a visited existing or missing file yields focus 0 and exact
   content. Replace only the obsolete structural assertion that compares a
   visited indexed `Text` to a cold one; preserve all behavioral assertions
   and complete frame goldens.

Inspect `lib/text.aloe` and the still-unchanged editor for the structural
rule: indexed `focus-at`, validity, and replacement must not rebuild the
whole source or line list for a local step. The editor's existing scans are
allowed until later checkpoints.

## Verification and completion

From the project root, run:

```sh
raco test tests/aloemacs/index-000-text-focus.rkt tests/aloemacs/002-text-view-validity.rkt tests/aloemacs/003-text-edits.rkt
raco test tests/aloemacs/file-session.rkt tests/aloemacs/editor-keys.rkt tests/aloemacs/frame.rkt tests/aloemacs/file-runner.rkt
raco test tests/aloemacs
```

This checkpoint is complete when the focused tests and existing aloemacs
tests pass, exact Text and File behavior is preserved, successful edits return
an indexed `Text` focused at the returned position, and the scoped source
inspection confirms line-local operations. The 10,000-line timing belongs to
the final checkpoint, after editor movement and frame rendering use the
index.

Report the changed files and verification results, then stop for human
review. Do not begin aloemacs-index 001.
