# aloemacs-kill 000 — Read a Text span

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.

## Goal

Add `(text excerpt span) : (Option String)` to `Text`. It reads exactly the
characters that deleting the same valid half-open span removes. This is a
pure Text operation; stop after its focused test and the aloemacs suite pass.
Do not begin mark, kill commands, session state, or Term mapping.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); this checkpoint narrows the spec to one slice and
does not revise it. Sections 1–3 and 7–8 of that spec govern this work,
especially §3. [`../../../../../../SPEC.md`](../../../../../../SPEC.md)
governs Aloe syntax, type checking, and sends. The accepted
[`../../text/spec.md`](../../text/spec.md) governs existing Text validity,
half-open spans, and deletion.

- Identity: **aloemacs-kill 000**, the first local checkpoint in this series.
  No aloemacs-kill predecessor is required. Do not issue or implement 001.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- `lib/text.aloe` already has `Text.indexed-value`, `focus-at`,
  `current-line`, `next-lines`, `valid-span?`, `delete`, and `insert`.
  `Text` has cold `from-string` and indexed zipper values.
- Evaluation is send: the head of a list is the receiver, the second element
  is a literal selector. Function objects run only with `call`.

## Exact file scope

### May edit

- `lib/text.aloe` — add exactly the public `Text.excerpt` selector needed here
- `tests/aloemacs/kill-excerpt.rkt` — new focused checked Aloe tests

### Must leave untouched

- `SPEC.md`, `CHECKPOINTS.md`, earlier design specifications or checkpoints
- `Text` constructors, `delete`, `replace`, `insert`, and `EditResult` contracts
- every other `lib/`, `aloe/`, `host/`, `examples/`, and `tests/` file
- every file not listed under **May edit**

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Required behavior

The only new public send is:

```aloe
(text excerpt span) ; (Option String), span : Span
```

- If `(text valid-span? span)` is false, return `(Option None)`.
- For a valid empty span, return `(Option Some "")`.
- Otherwise return `Some` of the exact String removed by `(text delete span)`.
  The span is half-open; content at its end remains outside the excerpt.
- A cross-line excerpt includes every intervening LF. From the end of one
  line to column 0 of the next, its result is exactly `"\n"`.
- A carriage return inside a line is ordinary content and is preserved.
- The receiver, span, and endpoint Positions remain unchanged.

Index a cold source at most once for this operation, then validate and read
through the zipper. Validate on the indexed value, use `focus-at` and
`current-line` for endpoints, and take/drop their fragments. For a multiline
span, include the start-line suffix, each complete interior line and its LF,
then the end-line prefix. `next-lines` may supply interior lines from an
already indexed receiver. Joining fragments by `append` once per line is
acceptable.

Do not use `Text.lines`, `to-string`, or `joined-with` inside `excerpt`.
Do not expose offsets, `line-at`, another Text selector, or a new String
method. Do not alter existing edit behavior to implement the read.

## Required focused tests

Write `tests/aloemacs/kill-excerpt.rkt` first and observe it fail for the
missing selector. Use `racket/runtime-path` to load `lib/text.aloe` through
`make-driver` and `driver-eval!`. Assert the checked result type
`(Option String)`. Exercise `excerpt`, deletion, insertion, and Option
branching as Aloe sends; Racket may provide assertion helpers around them.

Cover at least:

1. A middle span within one line; an entire line fragment; and a span
   crossing two or more lines, with exact LF placement.
2. The LF-only boundary span from one line's end to the next line's column 0.
3. A valid empty span returns `Some ""`, including at a line boundary.
4. Reversed and out-of-range spans return `None`; do not mistake invalid
   for valid empty. Include a negative coordinate and a column beyond a
   line's end.
5. A CR-containing source returns exact characters, including CR where the
   requested span crosses it.
6. Cold `Text.from-string` and indexed Text. Include an indexed value focused
   between span endpoints, so reading must traverse both sides of the
   current focus.
7. For representative valid spans in those categories, read the excerpt,
   delete that same span, then insert the excerpt at the deletion
   `EditResult.position`. The final `(text to-string)` equals the original
   source exactly. Unwrap `Option` results with exhaustive Aloe `case`, so
   an unexpected `None` fails the test.

Tests should inspect `Some` payloads, not only `present?`. Keep all existing
Text and aloemacs assertions intact.

## Verification and completion

From the project root, run the focused test and then the complete aloemacs
suite:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/kill-excerpt.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

`-y` rebuilds changed `.rkt` bytecode and dependent modules. Do not commit
`compiled/`. No TTY hand check is needed.

The checkpoint is complete when the checked `Option String` results, exact
excerpt goldens, invalid/empty distinction, deletion-and-reinsertion
property, and both test commands pass, with only the two allowed files
changed. Report the result, then stop for human review. Do not start the
next checkpoint.
