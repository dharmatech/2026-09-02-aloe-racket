# aloemacs-text 001 — Position and Span values

**Status.** Ready to implement.

## Goal

Create the aloemacs text library boundary and add its two coordinate values:
immutable `Position` values with lexicographic comparison and inserted-text
advance, and immutable half-open `Span` values with exact empty-span
detection.

This checkpoint establishes values only. Stop when it is green. Do not add
`Text`, `EditResult`, position/span validity relative to text, flat offsets,
or edits; those belong to later aloemacs-text checkpoints.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-text, 001)`, spoken **aloemacs-text 001**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is language law,
  especially send evaluation, `define-class`, typed immutable fields and
  methods, `load`, `let`, `if`, exact numeric types, and `List`. Evaluation is
  send, not apply: the head of a list is the receiver and its second element
  is the literal selector.
- [`../spec.md`](../spec.md), especially sections 1, 3.1, 3.2, 4, 8, and 9,
  is the local design authority. This checkpoint implements only `Position`,
  `Span`, and the text library's Option dependency.
- **aloemacs-text 000** is implemented and reviewed. Kernel
  `(string drop n)` and Aloe-defined `(string split-lines)` are available in
  ordinary checked drivers. Preserve their behavior and do not reopen that
  checkpoint.
- Existing `lib/option.aloe`, primitive `Int` comparison/arithmetic, and List
  `len`, `first`, `rest`, and `reverse` are predecessors.

## Starting point

`lib/text.aloe` does not yet exist. A fresh `make-driver` bootstraps the List
and String libraries, including `split-lines`, but it does not bind `Option`,
`Position`, `Span`, `Text`, or `EditResult`.

Local aloemacs libraries are loaded explicitly through the checked driver;
they are not added to `aloe/library.rkt`, `aloe/main.rkt`, or
`aloe/driver.rkt`. Loading `lib/text.aloe` must resolve its sibling
`option.aloe` through Aloe's existing source-relative `load` behavior.

## Exact file scope

### May edit

- `lib/text.aloe` (new)
- `tests/aloemacs/001-position-span.rkt` (new)

No existing source or test file needs compatibility maintenance for this
environment-local library.

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, or any global checkpoint document
- any file under `aloe/`, `host/`, `bin/`, `examples/`, `gel/`, or
  `docs/editor/`
- `lib/string.aloe`, `lib/list.aloe`, `lib/option.aloe`, or any other existing
  library
- `tests/aloemacs/000-string-prerequisite.rkt` or any existing test
- the aloemacs README, charter, specification, or earlier checkpoint
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Text library boundary

Create `lib/text.aloe` as Aloe source with no `#lang` line. Its first form is:

```aloe
(load "option.aloe")
```

This establishes the final library dependency required by the design even
though 001 does not yet return an `Option`. Do not copy `Option`, add Option
methods, or bind the constructor selectors `Some` and `None` as top-level
names.

After the load, this checkpoint defines `Position` and then `Span`. It does
not define `Text`, `EditResult`, helper classes, top-level sample values, or a
public Racket API.

Loading the file in one driver binds `Option`, `Position`, and `Span` only in
that driver. A fresh second driver remains unchanged. Do not bootstrap the
text library into every program.

## `Position`

Declare exactly this non-generic immutable class shape and field order:

```aloe
(define-class Position
  (fields
    (line Int)
    (column Int))
  (methods
    ...))
```

Construction is `(Position new line column)`. Both arguments are exactly
`Int`. Coordinates are zero-based by meaning, but construction itself does
not validate, clamp, or normalize anything. Negative and arbitrarily large
integers are legal `Position` payloads in this slice because validity exists
only relative to a future `Text`.

The only `Position` methods in 001 are:

| Send | Parameter | Result | Meaning |
|---|---|---|---|
| `(p = q)` | `q : Position` | `Bool` | both fields are equal |
| `(p before? q)` | `q : Position` | `Bool` | lexicographic order |
| `(p before-or-equal? q)` | `q : Position` | `Bool` | before or equal |
| `(p after string)` | `string : String` | `Position` | end after inserting `string` at `p` |

### Equality and ordering

`=` is true exactly when both `line` and `column` are equal. It is false when
either differs.

`before?` is strict lexicographic order:

- a smaller line is before a larger line regardless of columns;
- on equal lines, a smaller column is before a larger column;
- equal positions are not before one another;
- a larger line, or a larger column on the same line, is not before.

`before-or-equal?` is true exactly when `before?` or `=` is true. These
methods compare the stored integers as-is, including negative values. They do
not ask whether either position belongs to a text.

### Advancing after inserted text

`(p after string)` returns the position reached after inserting the supplied
String at `p`. Only LF (`"\n"`) starts a new line.

- With no LF, preserve `(p line)` and add `(string len)` to `(p column)`.
- With `k > 0` LFs, add `k` to `(p line)` and set the result column to the
  length of the piece after the final LF. The original column does not carry
  across an LF.

Normative examples:

```aloe
((Position new 3 4) after "")         ; (Position new 3 4)
((Position new 3 4) after "xy")       ; (Position new 3 6)
((Position new 3 4) after "x\nyz")   ; (Position new 4 2)
((Position new 3 4) after "\n")      ; (Position new 4 0)
((Position new 3 4) after "x\ny\nz") ; (Position new 5 1)
((Position new 3 4) after "x\n")     ; (Position new 4 0)
```

Use `(string split-lines)` to derive the LF count and final piece. The result
of `split-lines` is nonempty, so its length minus one is the LF count; its
last element can be obtained with existing List behavior. Do not inspect
characters as `Char` values or add a second line-splitting implementation.

String lengths use the same character-count unit as checkpoint 000. Thus
advancing `(Position new 1 2)` after `"🙂水"` yields line 1, column 4. A
carriage return has no special meaning; without LF it contributes one to the
column like any other String character.

`after` constructs a `Position`; it does not mutate its receiver or any
String/List value. It does not validate the starting coordinates.

## `Span`

After `Position`, declare exactly this immutable class shape and field order:

```aloe
(define-class Span
  (fields
    (start Position)
    (end Position))
  (methods
    (empty? () Bool
      ...)))
```

Construction is `(Span new start end)`. A Span denotes the half-open region
`[start, end)`, but 001 does not yet validate that region against text.

`(span empty?)` is true exactly when `(span start)` equals `(span end)` by the
`Position.=` method. It is false for every pair of different positions.

Construction preserves the supplied endpoints in order. It does not reorder
or normalize them: a start that follows its end is still stored as `start`
and makes `empty?` false. A later `Text.valid-span?` checkpoint will reject
such a span relative to a text.

Do not add Span equality, ordering, normalization, length, validity, offset,
replacement, insertion, or deletion methods in this slice.

## Required tests

Add `tests/aloemacs/001-position-span.rkt`. Use `racket/runtime-path` to locate
`../../lib/text.aloe`, then load it with an ordinary checked Aloe driver
(`make-driver` and `driver-eval!`). Do not parse or evaluate the library with
a separate test-only path.

Cover all of the following:

1. Before loading, a fresh driver has no bindings for `Option`, `Position`,
   `Span`, `Text`, or `EditResult`; checkpoint-000 String/List behavior still
   works.
2. Loading `lib/text.aloe` binds `Option`, `Position`, and `Span`. `Some` and
   `None` remain constructor selectors rather than top-level bindings.
   `Text` and `EditResult` remain unbound in 001.
3. A second fresh driver remains unaffected, proving the library is not
   globally bootstrapped or leaked between environments.
4. `Position` construction, field reads, and method sends have the exact
   types in this document. Wrong arity or non-Int fields are rejected.
5. Negative and large coordinate payloads construct successfully and are
   returned unchanged by their field sends.
6. `Position.=` covers equal values, a differing line, and a differing
   column.
7. `before?` covers all lexicographic branches: smaller line, larger line,
   equal line with smaller/larger column, equality, and negative coordinates.
8. `before-or-equal?` is true for strict-before and equality and false for
   strict-after.
9. `after` covers every normative example above, plus a non-ASCII no-LF
   String and a carriage return. Assert both result fields, not only printed
   presentation.
10. Calling `after` leaves the original Position fields unchanged.
11. `Span` construction and field reads have types `Span` and `Position` as
    appropriate. Non-Position endpoints and wrong arity are rejected.
12. `empty?` is true for equal endpoint payloads even when the two Positions
    were constructed separately; it is false for a nonempty forward span and
    a reversed span.
13. A reversed Span preserves its exact supplied `start` and `end`; it is not
    silently reordered.
14. The 001 surface has no `Text`/`EditResult` classes and no validity,
    offset, replacement, insertion, deletion, newline, rebasing, or mutation
    behavior.

Tests may use `aloe-value->string` for concise structural diagnostics, but
the normative assertions must exercise Aloe constructors, fields, and sends
through the checked driver.

## Verification and hand check

Run the new test and its predecessor first:

```sh
raco test tests/aloemacs/000-string-prerequisite.rkt
raco test tests/aloemacs/001-position-span.rkt
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
 (aloe-value->string
  (driver-eval! state '((Position new 3 4) after "x\nyz")))
 (driver-eval!
  state
  '((Span new (Position new 1 2) (Position new 1 2)) empty?)))
```

The result is:

```racket
'("#<Position 4 2>" #t)
```

## Acceptance

This checkpoint is complete when:

- `lib/text.aloe` source-relatively loads the existing Option library and is
  itself loaded only when requested;
- `Position` has exactly the two fields and four methods specified here;
- equality, lexicographic ordering, and LF-aware `after` obey every stated
  rule without validation or mutation;
- `Span` has exactly the two fields and `empty?`, preserves endpoint order,
  and performs no validation or normalization;
- no `Text`, `EditResult`, edit operation, new kernel message, host behavior,
  or bootstrap change is introduced;
- the focused tests and full recursive suite are green; and
- the hand check has the exact stated result.

Stop for human review. Do not begin aloemacs-text 002.

## Explicit non-goals

- `Text`, `EditResult`, `Text.from-string`, line access, round-tripping, or
  text-relative position/span validity
- flat offsets, replacement, insertion, deletion, newline insertion, result
  positions, rebasing, deltas, undo, or mutable editor state
- clamping or rejecting Position construction; normalizing Span endpoints
- files, encodings, CRLF conversion, final-newline policy, Term, a TTY,
  rendering, screen geometry, Unicode display width, or a running editor
- `Char`, string indexing, substring, new String/List behavior, mutation, new
  special forms, host crossings, or any kernel change
- bootstrapping `lib/text.aloe` into default environments or exposing a
  parallel Racket text API
