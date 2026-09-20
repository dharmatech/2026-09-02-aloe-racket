# aloemacs-text 002 — Text views and validity

**Status.** Ready to implement.

## Goal

Add the immutable `Text` value with its exact-source representation, derived
LF-split line view, and text-relative validation for `Position` and `Span`.

This checkpoint establishes the non-editing Text algebra. Stop when it is
green. Do not add `EditResult`, replacement, insertion, deletion, newline
editing, public offsets, or any mutable/editor state; those belong to later
aloemacs-text checkpoints.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-text, 002)`, spoken **aloemacs-text 002**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is language law,
  especially send evaluation, explicit constructors, typed immutable fields,
  `define-class`, `let`, `if`, exact `Int`, and List folds. Evaluation is send,
  not apply: the head of a list is the receiver and its second element is the
  literal selector.
- [`../spec.md`](../spec.md), especially sections 1, 3.3, 4, 5, 7.1, 7.6, 8,
  and 9, is the local design authority. This checkpoint implements only the
  non-editing portion of `Text`.
- **aloemacs-text 000–001** are implemented and reviewed. `String.drop`,
  `String.split-lines`, `Position`, `Position.before-or-equal?`, `Span`, and
  the explicit `lib/text.aloe` load boundary are available. Preserve them.
- `lib/text.aloe` already source-relatively loads `lib/option.aloe`. Keep that
  dependency even though 002 still does not construct an Option.

## Starting point

`lib/text.aloe` currently contains, in order:

1. `(load "option.aloe")`;
2. the checkpoint-001 `Position` class with fields `line`, `column` and its
   four methods; and
3. the checkpoint-001 `Span` class with fields `start`, `end` and `empty?`.

A fresh `make-driver` does not bind these local classes. Loading
`lib/text.aloe` binds `Option`, `Position`, and `Span` in that driver only.
This checkpoint adds `Text` after `Span`; it does not change bootstrap policy.

The 001 focused test deliberately records that `Text` is absent in its slice.
That one expectation becomes obsolete in 002. Update only the assertions
superseded by the new class; preserve all Position, Span, Option-load, and
driver-isolation coverage.

## Exact file scope

### May edit

- `lib/text.aloe`
- `tests/aloemacs/002-text-view-validity.rkt` (new)
- `tests/aloemacs/001-position-span.rkt`, only to remove/rename the now-obsolete
  post-load assertions that `Text` is unbound; retain the pre-load/fresh-driver
  assertions and every Position/Span test

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, or any global checkpoint document
- any file under `aloe/`, `host/`, `bin/`, `examples/`, `gel/`, or
  `docs/editor/`
- `lib/string.aloe`, `lib/list.aloe`, `lib/option.aloe`, or any other library
- `tests/aloemacs/000-string-prerequisite.rkt` or any test outside the exact
  list under **May edit**
- the aloemacs README, charter, specification, or earlier checkpoint documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## `Text` declaration and representation

After `Span`, declare `Text` with exactly one explicit constructor and exactly
one stored field:

```aloe
(define-class Text
  (constructors
    (from-string (fields (source String))))
  (methods
    ...))
```

Construction is:

```aloe
(Text from-string source)
```

The lowercase constructor selector is intentional and normative. Do not add
`new`, a top-level `from-string` binding, another constructor, another stored
field, a trailing-newline flag, or a cached line list.

The exact input String is the representation. `Text`, its source, and every
derived List/String value remain immutable. This checkpoint adds these and
only these instance methods:

| Send | Result | Meaning |
|---|---|---|
| `(text to-string)` | `String` | exact stored source |
| `(text lines)` | `(List String)` | `(source split-lines)` |
| `(text valid-position? p)` | `Bool` | whether `p` is a position in `text` |
| `(text valid-span? span)` | `Bool` | whether both endpoints are valid and ordered |

`source` is constructor-specific payload, not an automatically exposed field
send. `to-string` extracts that payload with exhaustive `case` on `self` and
is the only public source accessor. `(text source)` is an unknown message. Do
not add a second source accessor or conversion path.

`Text` is declared now without edit methods. A later checkpoint may declare
`EditResult` and extend `Text` with `define-methods`; 002 must not introduce a
forward type or placeholder edit API.

## Lines and newline policy

`(text lines)` derives its result by sending `split-lines` to the stored
source. Do not copy the checkpoint-000 recursion, use a host/Racket splitter,
or store/cache the result.

Only the single LF character (`"\n"`) separates lines. Empty pieces are real
lines, including the one after a trailing LF. The line List is therefore
always nonempty:

| Source | Lines |
|---|---|
| `""` | `(List of "")` |
| `"one\ntwo"` | `(List of "one" "two")` |
| `"one\ntwo\n"` | `(List of "one" "two" "")` |
| `"\n"` | `(List of "" "")` |
| `"x\n\n"` | `(List of "x" "" "")` |

Carriage return has no special meaning. `(Text from-string "a\r\nb")` has
the lines `(List of "a\r" "b")`. Do not recognize or normalize CRLF.

`to-string` round-trips the exact source, including empty input, Unicode,
carriage returns, and zero, one, or several trailing LFs:

```aloe
((Text from-string s) to-string) = s
```

There is no separate final-newline flag.

## Valid positions

For `lines = (text lines)`, a Position `p` is valid exactly when both are
true:

```text
0 <= (p line) < (lines len)
0 <= (p column) <= ((line selected by p.line) len)
```

Coordinates and line indexes use `Int`. The end of a line is a valid column.
The final empty line after a trailing LF is an ordinary line whose sole valid
position is column 0.

Required boundary examples:

- In `""`, `(0, 0)` is valid; `(0, 1)`, `(-1, 0)`, `(0, -1)`, and `(1, 0)`
  are invalid.
- In `"abc"`, columns 0 through 3 on line 0 are valid; column 4 is invalid.
- In `"ab\nc"`, line 0 admits columns 0 through 2 and line 1 admits columns
  0 through 1; line 2 is invalid.
- In `"ab\n"`, `(1, 0)` is valid; `(1, 1)` and `(2, 0)` are invalid.
- In `"🙂水"`, `(0, 2)` is valid and `(0, 3)` is invalid because String
  positions use the same character-count unit as `len`.
- In `"a\r\nb"`, line 0 has length 2, so `(0, 2)` is valid.

`valid-position?` returns `#f` for every negative or out-of-range coordinate.
It does not clamp, construct a replacement Position, or raise a host error.
It must reject an invalid line before attempting to select that line.

Implement this as ordinary Aloe code using existing sends. Do not add a
public `line-at`, `offset`, or recursive helper selector, and do not add a
helper class or top-level binding. One closed implementation can first check
the line/column bounds and then fold the nonempty line List with a `Position`
accumulator whose fields carry the current index and selected line length;
that is an implementation option, not a new public meaning for Position.

## Valid spans

A Span is valid for a Text exactly when:

1. its start is a valid position for that same Text;
2. its end is a valid position for that same Text; and
3. `(start before-or-equal? end)` is true.

Use the existing public `Position.before-or-equal?` behavior. Do not reorder,
normalize, or clamp endpoints.

Consequences:

- an empty span at any valid boundary is valid;
- a forward span within one line is valid;
- a forward span across lines is valid;
- a reversed span is invalid even when both endpoints are individually valid;
- a span is invalid when either endpoint is invalid.

Invalidity is the Bool result `#f`; no Option or host exception is used by the
predicate. The input Text, Span, and endpoint Positions remain unchanged.

## Required tests

Add `tests/aloemacs/002-text-view-validity.rkt`. Use `racket/runtime-path` to
locate `../../lib/text.aloe`, then load it through an ordinary checked Aloe
driver (`make-driver` and `driver-eval!`). Do not parse/evaluate the library
through a test-only path and do not implement a parallel Racket text API.

Cover all of the following:

1. A fresh driver has no `Text`; loading `lib/text.aloe` binds it in that
   driver, while a second fresh driver remains unaffected. `Option`,
   `Position`, and `Span` retain checkpoint-001 behavior.
2. `(Text from-string source)` has type `Text`. The `to-string` send has type
   `String`, `lines` has type `(List String)`, and both validity sends have
   type `Bool`. Sending `source` is rejected.
3. `Text` has exactly the lowercase `from-string` constructor in this slice:
   wrong arity, a non-String payload, and `(Text new ...)` are rejected.
   `from-string` is not a top-level binding.
4. `to-string` exactly round-trips `""`, a one-line String, a multi-line
   String, Unicode, CRLF content, one trailing LF, and multiple trailing LFs.
5. `lines` returns every exact List in the table above plus the CRLF example;
   no returned line contains LF.
6. `valid-position?` covers every boundary example in this document,
   including negative line/column, a very large line, a column one past the
   end, end-of-line, the final empty line, Unicode, and carriage return.
7. `valid-position?` rejects a non-Position argument statically.
8. `valid-span?` accepts a valid empty span, a same-line forward span, and a
   cross-line forward span.
9. `valid-span?` rejects same-line and cross-line reversed spans and spans
   whose start, end, or both endpoints are invalid. Include the trailing-LF
   final-line boundary.
10. `valid-span?` rejects a non-Span argument statically.
11. Predicate calls leave the Text, Span, and Position payloads unchanged.
12. `EditResult` remains unbound. Sending `source`, `replace`, `insert`,
    `delete`, or `newline` to Text is an unknown-message/type error in 002.
    There is no public `offset`, `line-at`, setter, or normalization message.
13. The updated checkpoint-001 test continues to prove all Position/Span
    behavior and now defers only the later edit surface, not `Text` itself.

Racket may inspect Aloe values returned by the checked driver for assertions,
but all production text, line, and validity behavior must run as Aloe sends.

## Verification and hand check

Run the local series first:

```sh
raco test tests/aloemacs/000-string-prerequisite.rkt
raco test tests/aloemacs/001-position-span.rkt
raco test tests/aloemacs/002-text-view-validity.rkt
```

Then run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
raco test tests
```

Run this checked hand exercise from the repository root:

```racket
(require racket/runtime-path
         "aloe/driver.rkt")

(define-runtime-path text-path "lib/text.aloe")
(define state (make-driver))
(driver-eval! state `(load ,(path->string text-path)))

(list
 (driver-eval! state '((Text from-string "one\ntwo\n") to-string))
 (aloe-value->string
  (driver-eval! state '((Text from-string "one\ntwo\n") lines)))
 (driver-eval!
  state
  '((Text from-string "one\ntwo\n") valid-position?
    (Position new 2 0)))
 (driver-eval!
  state
  '((Text from-string "one\ntwo\n") valid-span?
    (Span new (Position new 1 1) (Position new 0 1)))))
```

The result is:

```racket
'("one\ntwo\n" "#<List \"one\" \"two\" \"\">" #t #f)
```

## Acceptance

This checkpoint is complete when:

- `Text` has exactly the `from-string` constructor, `source` representation,
  and four non-editing methods specified here;
- source round-tripping and LF-only derived lines preserve every empty and
  trailing piece exactly;
- position validity implements both line and inclusive-column bounds in
  String character units without clamping or host failures;
- span validity requires two valid endpoints in nondecreasing lexicographic
  order without normalization;
- the existing Position/Span and String behavior remains intact;
- no `EditResult`, edit operation, public offset/helper, new kernel message,
  host behavior, or bootstrap change is introduced;
- the focused tests and full recursive suite are green; and
- the hand check has the exact stated result.

Stop for human review. Do not begin aloemacs-text 003.

## Explicit non-goals

- `EditResult`, replacement, insertion, deletion, newline insertion, edit
  result positions, flat/public offsets, rebasing, deltas, undo, or mutation
- caching lines, a trailing-newline flag, CRLF recognition/conversion, file
  encoding, loading/saving files, or final-newline policy
- point as editor state, movement, marks, selections, keymaps, Term, a TTY,
  rendering, Unicode display width, grapheme handling, or a running editor
- `Char`, string indexing, substring, new String/List behavior, new special
  forms, host crossings, or kernel changes
- bootstrapping `lib/text.aloe` into default environments or exposing a
  parallel Racket text API
