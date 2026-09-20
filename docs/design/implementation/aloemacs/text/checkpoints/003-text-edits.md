# aloemacs-text 003 — Immutable text edits

**Status.** Ready to implement.

## Goal

Complete the pure aloemacs text algebra with immutable half-open replacement,
the `EditResult` value, and the delegating `insert`, `delete`, and `newline`
messages. Valid edits return `(Option Some edit-result)`; invalid coordinates
return `(Option None)` without changing any input.

This checkpoint completes the behavior in the aloemacs text specification.
Stop when it is green. Do not begin Term, editor state, files, buffers,
rebasing, undo, or a running editor.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-text, 003)`, spoken **aloemacs-text 003**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is language law,
  especially send evaluation, typed immutable classes, explicit constructors,
  `define-methods`, exhaustive `case`, expected-type inference for
  `(Option None)`, `let`, `fn`/`call`, and exact `Int`. Evaluation is send,
  not apply: the head of a list is the receiver and its second element is the
  literal selector.
- [`../spec.md`](../spec.md), especially sections 1, 3.3, 3.4, 5, 6, 7.2–7.6,
  8, and 9, is the local design authority. This checkpoint implements the
  remaining edit behavior exactly.
- **aloemacs-text 000–002** are implemented and reviewed. `String.take`,
  `String.drop`, `Position.after`, `Span`, `Text.from-string`, exact source
  and line views, and Text position/span validation are available. Preserve
  them.
- `lib/text.aloe` already loads `lib/option.aloe`, so `Option`, `Some`, and
  `None` constructor selectors are available inside the loaded library.

## Starting point

`lib/text.aloe` currently contains, in order:

1. `(load "option.aloe")`;
2. `Position`;
3. `Span`; and
4. the non-editing `Text` declaration.

`Text` has the single explicit `from-string` constructor and methods
`to-string`, `lines`, `valid-position?`, and `valid-span?`. Its constructor
payload is private behind `to-string`; `(text source)` is not a message.

The checkpoint-001 and checkpoint-002 focused tests deliberately record that
`EditResult` and edits are absent in those slices. Those expectations become
obsolete in 003. Update only the superseded binding/no-edit assertions while
preserving all String, Position, Span, Text-view, validity, load-isolation,
and private-source coverage.

## Exact file scope

### May edit

- `lib/text.aloe`
- `tests/aloemacs/003-text-edits.rkt` (new)
- `tests/aloemacs/001-position-span.rkt`, only to add `EditResult` to the
  post-load bound classes, remove its obsolete post-load unbound assertion,
  and rename the final surface test; retain its proof that Position itself
  does not own Text/edit selectors, plus every Position/Span and fresh-driver
  assertion
- `tests/aloemacs/002-text-view-validity.rkt`, only to update the post-load
  `EditResult` binding expectation and replace its obsolete no-edit assertions
  with the still-valid rejection of `source`, public offsets/helpers, setters,
  and normalization; retain all Text-view and validity tests

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

## Declaration order and `EditResult`

Do not add edit methods inside the existing `define-class Text` body because
their return type refers to `EditResult`, which is declared afterward.

After `Text`, declare exactly this immutable non-generic class and field order:

```aloe
(define-class EditResult
  (fields
    (text Text)
    (position Position))
  (methods))
```

Construction is `(EditResult new text position)`. Its ordinary field sends
are `(result text)` and `(result position)`. It has no methods, alternate
constructors, status flag, old text, span, replacement, delta, or undo data.

Then extend the existing Text class:

```aloe
(define-methods Text
  (methods
    (replace (span Span) (string String) (Option EditResult)
      ...)
    (insert (position Position) (string String) (Option EditResult)
      ...)
    (delete (span Span) (Option EditResult)
      ...)
    (newline (position Position) (Option EditResult)
      ...)))
```

These are ordinary Aloe methods. Do not add Racket/evaluator/checker cases,
host crossings, another class declaration for Text, or another public helper
selector.

## Flat offsets used by replacement

Replacement translates each valid endpoint `(line, column)` to a flat source
offset:

```text
sum(len(each line before line) + 1) + column
```

The added 1 accounts for each LF separator before the selected line. Examples:

- in `"abcd"`, `(0, 2)` has offset 2;
- in `"ab\ncd"`, `(1, 0)` has offset 3 and `(1, 2)` has offset 5;
- in `"ab\n"`, the final empty-line position `(1, 0)` has offset 3.

Offsets are an internal calculation only. Do not expose `offset`, `line-at`,
or another helper message/class/top-level binding.

Implement the calculation in ordinary Aloe. A local function value inside
`replace` may fold `(self lines)` with a `Position` accumulator whose `line`
field is the current line index and whose `column` field is the accumulated
prefix length, then add the endpoint column. Invoke such a function only with
`call`; `(f position)` would be a send, not function application. This is an
implementation option, not a new public meaning for Position.

`replace` must call `valid-span?` before calculating offsets. Invalid
coordinates return `None`; they are not made safe by relying on the clamping
behavior of `take` or `drop`.

## `replace`

The public send and type are:

```text
(text replace span replacement) : (Option EditResult)
```

If `(text valid-span? span)` is false, return:

```aloe
(Option None)
```

Do not construct a new Text or EditResult and do not raise a host error.

For a valid span, bind:

- `old` to `(text to-string)`;
- `a` to the start flat offset;
- `b` to the end flat offset; and
- `new-source` to exactly:

```aloe
(((old take a) append replacement) append (old drop b))
```

Return exactly:

```aloe
(Option Some
  (EditResult new
    (Text from-string new-source)
    ((span start) after replacement)))
```

The span is half-open: content at the start is removed, content at the end is
retained. An empty span removes nothing. Replacing with `""` deletes. The
returned position is always the end of the inserted replacement in the new
text, independent of the old span end.

The original Text, Span, endpoint Positions, and replacement String remain
unchanged. The result contains newly constructed Text, Position, and
EditResult values; no in-place effect is allowed.

## Delegating edit messages

The other edit messages introduce no separate edit machinery:

```aloe
(text insert position string)
```

delegates to:

```aloe
(text replace (Span new position position) string)
```

```aloe
(text delete span)
```

delegates to:

```aloe
(text replace span "")
```

```aloe
(text newline position)
```

delegates to:

```aloe
(text insert position "\n")
```

Each returns `(Option EditResult)`. Invalid inputs become `None` through the
same validation path. Do not duplicate validation, offset calculation, source
splicing, or result construction in these wrappers.

## Normative successful edits

The following results are exact. “Result text” and “result position” mean the
fields of the `EditResult` carried by `Some`; `None` is a test failure.

### Insert within a line

```aloe
(define before (Text from-string "abcd"))
(define result (before insert (Position new 0 2) "X"))
```

- result text is `"abXcd"`;
- result position is `(Position new 0 3)`; and
- `(before to-string)` remains `"abcd"`.

### Insert a newline

```aloe
((Text from-string "abcd") newline (Position new 0 2))
```

- result text is `"ab\ncd"`;
- its lines are `(List of "ab" "cd")`; and
- result position is `(Position new 1 0)`.

### Delete a character

```aloe
((Text from-string "abcd") delete
  (Span new (Position new 0 1) (Position new 0 2)))
```

produces `"acd"` at `(Position new 0 1)`.

### Delete a line separator

```aloe
((Text from-string "ab\ncd") delete
  (Span new (Position new 0 2) (Position new 1 0)))
```

produces `"abcd"` at `(Position new 0 2)`. The LF lies between those two
positions, so this is the required end-of-line join.

### Replace a multi-line span with shorter text

```aloe
((Text from-string "ab\ncd\nef") replace
  (Span new (Position new 0 1) (Position new 2 1))
  "X")
```

produces `"aXf"` at `(Position new 0 2)`.

### Replace a multi-line span with longer text

```aloe
((Text from-string "ab\ncd") replace
  (Span new (Position new 0 1) (Position new 1 1))
  "X\nY\nZ")
```

produces `"aX\nY\nZd"`, with lines `(List of "aX" "Y" "Zd")`, at
`(Position new 2 1)`.

### Empty and boundary edits

- Replacing an empty span with `""` preserves the source and returns the span
  start as the result position.
- Inserting at column 0 and at end-of-line is valid.
- Inserting on the final empty line of `"ab\n"` at `(1, 0)` is valid.
- Newline at that final position produces `"ab\n\n"` at `(2, 0)`.
- Deleting from `(0, 0)` to the final valid position deletes the corresponding
  half-open content exactly; no implicit final-newline policy is applied.

## Invalid edits

Each of the following returns `(Option None)`:

- insert at a negative line or column;
- insert past the last line;
- insert one column past a line's end;
- replace/delete when either endpoint is invalid; and
- replace/delete with a start after its end, on one line or across lines.

The corresponding valid positions at column 0, end-of-line, and the final
empty line after a trailing LF return `Some`.

Invalid edits do not clamp coordinates, reorder endpoints, partially edit,
or throw a host exception. Their input values remain unchanged.

## Required tests

Add `tests/aloemacs/003-text-edits.rkt`. Locate `../../lib/text.aloe` with
`racket/runtime-path` and load it through an ordinary checked Aloe driver
(`make-driver` and `driver-eval!`). Exercise edits as Aloe sends and unwrap
Options with exhaustive Aloe `case`; do not implement a parallel Racket text
API.

Cover all of the following:

1. A fresh driver has no `EditResult`; loading `lib/text.aloe` binds it only
   in that driver. `Some` and `None` remain constructor selectors rather than
   top-level names. A second fresh driver is unaffected.
2. `EditResult` construction and its `text`/`position` fields have exactly the
   declared types. Wrong arity and wrong field types are rejected. It has no
   extra method or constructor.
3. `replace`, `insert`, `delete`, and `newline` each have checked result type
   `(Option EditResult)`. Wrong argument types and arities are rejected.
4. Every normative successful edit above has the exact result source, line
   view where stated, and result Position fields. Use exhaustive Option case;
   merely checking `present?` is insufficient for successful goldens.
5. The original `before` Text in the insertion golden remains `"abcd"` after
   the edit. Also preserve representative Span and Position payloads.
6. Empty-span/empty-replacement, column-0, end-of-line, final-empty-line, and
   trailing-LF edits return `Some` with exact values.
7. Every invalid category above returns `None`. Prove at least one invalid
   result with exhaustive Option case in addition to `present?` checks.
8. Invalid operations leave their input Text, Position, and Span values
   unchanged and do not surface a host substring/list error.
9. The end-of-line separator deletion joins lines exactly, proving half-open
   offsets across an LF.
10. Multi-line replacement result positions come from `(span start) after
    replacement`, including a replacement ending in LF and one containing
    multiple LFs.
11. `insert`, `delete`, and `newline` agree with the equivalent direct
    `replace` operations in result text and result position.
12. `Text` still rejects `source`, `offset`, `line-at`, setters,
    normalization, rebasing, and undo messages. No public helper selector or
    helper class/top-level binding is introduced.
13. Updated 001–002 tests retain all earlier behavior while removing only the
    superseded post-load/no-edit expectations. In particular, 001 still proves
    that Position does not acquire Text/edit selectors, and 002 still proves
    that Text has no `source`, public offset/helper, setter, or normalization
    message.

Racket may provide assertion helpers around returned Aloe values, but the
production edit behavior, Option branching, Text construction, and field
reads under test must be Aloe operations through the checked driver.

## Verification and hand check

Run the complete local series first:

```sh
raco test tests/aloemacs/000-string-prerequisite.rkt
raco test tests/aloemacs/001-position-span.rkt
raco test tests/aloemacs/002-text-view-validity.rkt
raco test tests/aloemacs/003-text-edits.rkt
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
(driver-eval! state
  '(define before-003 (Text from-string "ab\ncd\nef")))
(driver-eval! state
  '(define option-003
     (before-003 replace
       (Span new (Position new 0 1) (Position new 2 1))
       "X")))

(list
 (driver-eval! state
  '(option-003 case
     (None () "unexpected")
     (Some (result) ((result text) to-string))))
 (driver-eval! state
  '(option-003 case
     (None () -1)
     (Some (result) ((result position) line))))
 (driver-eval! state
  '(option-003 case
     (None () -1)
     (Some (result) ((result position) column))))
 (driver-eval! state '(before-003 to-string)))
```

The result is:

```racket
'("aXf" 0 2 "ab\ncd\nef")
```

## Acceptance

This checkpoint is complete when:

- `EditResult` has exactly the two immutable fields and no methods specified
  here;
- valid replacement uses the exact half-open flat-offset splice and returns
  the exact new Text and inserted-content end Position inside `Some`;
- every invalid edit returns `None` without clamping, normalization, host
  failure, or input mutation;
- `insert`, `delete`, and `newline` delegate to the single replacement path;
- all required single-line, multi-line, LF separator, trailing-LF, empty, and
  boundary goldens hold;
- no public offset/helper, new kernel message, host behavior, mutable state,
  or bootstrap change is introduced;
- the complete aloemacs-text acceptance criteria in the design specification
  are satisfied;
- the focused tests and full recursive suite are green; and
- the hand check has the exact stated result.

Stop for human review. Do not begin another aloemacs layer.

## Explicit non-goals

- public offsets, line indexing helpers, generic String insertion/deletion,
  `Char`, substring, new String/List behavior, new special forms, host
  crossings, or kernel changes
- point as editor state, movement commands, goal columns, marks, selections,
  keymaps, windows, minibuffers, Term, a TTY, rendering, or a running editor
- deltas, snapshots, inverse edits, undo/redo, rebasing other Positions,
  mutation, setters, a mutable buffer store, or identity guarantees exposed to
  Aloe programs
- files, encodings, CRLF conversion, final-newline policy, search,
  indentation, syntax, evaluation of text, or reflection-specific behavior
- bootstrapping `lib/text.aloe` into default environments or exposing a
  parallel Racket text API
