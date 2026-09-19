# aloemacs text specification

**Status.** Design for the local **aloemacs-text** project. This is not
Aloe language law, a checkpoint, or an implementation assignment. A later
checkpoint-manager conversation will slice `aloemacs-text 000`, `001`, …
under `checkpoints/`. The authority for Aloe syntax, sends, construction,
types, and immutability remains [`SPEC.md`](../../../../../SPEC.md).

This project defines a pure text algebra in Aloe: text, positions, half-open
spans, and replacement. It also requires one new primitive `String` message,
`drop`. The `drop` addition belongs to this local checkpoint series unless a
human separately ratifies it onto the language spine.

## 1. Scope and invariants

A `Text` is an immutable ordered, nonempty sequence of immutable `String`
lines. In this specification, **newline means the single character LF**
(`"\n"`). No line contains LF. The empty source has one line, `""`.

The representation stores the exact source `String`; the line sequence is a
derived view. This keeps construction and exact string round-tripping small
while still making lines the coordinate space of the algebra. Neither the
source nor a line list is ever mutated.

The algebra has no display semantics. A column is a count in the same units
as `(s len)`, not a terminal cell width, byte offset, grapheme index, or tab
stop.

The following are deliberately absent: editor state and point, marks,
rebasing, deltas, inversion, undo, files, newline conversion, terminal
operations, screen geometry, Unicode width, and a running editor.

### 1.1 Project boundary

- The algebra lives in `lib/text.aloe`.
- Aloe-defined `String` behavior lives in `lib/string.aloe`.
- The one `String` kernel lift is implemented in the evaluator and type
  machinery that own the messages in `SPEC.md` section 7.5; its checkpoint
  must name those exact files and their focused kernel tests.
- Algebra tests live under `tests/aloemacs/` and load Aloe source through the
  checked driver.
- Nothing from this project belongs in `examples/aloemacs/`, `docs/editor/`,
  the global `docs/checkpoints/` directory, or `CHECKPOINTS.md`.

The existing `List` messages and Aloe methods, `String` messages and
`starts-with?`, constructors and `case`, and `lib/option.aloe` are
predecessors. Term and every later aloemacs layer are not predecessors.

## 2. String prerequisite

### 2.1 Kernel message `drop`

`String` gains exactly one kernel message:

| Send | Meaning | Type |
|---|---|---|
| `(s drop n)` | suffix after dropping a clamped prefix | `String`, with `n : Int` |

The receiver must be a `String` and the argument must be an `Int`.

- If `n <= 0`, `(s drop n)` returns all of `s`.
- If `n >= (s len)`, it returns `""`.
- Otherwise it returns `s` without its first `n` characters.
- It uses the same character-count unit as `len` and `take`.

For every `String` `s` and `Int` `n`, the clamping rules make this identity
hold:

```aloe
((s take n) append (s drop n))
```

is equal to `s`.

No other kernel message is needed. In particular this project does not add
`Char`, string indexing, a substring primitive, a newline primitive, or
mutation.

### 2.2 Aloe method `split-lines`

[`lib/string.aloe`](../../../../../lib/string.aloe) adds the Aloe-defined
message:

| Send | Result |
|---|---|
| `(s split-lines)` | a nonempty `(List String)` obtained by splitting `s` at every LF |

`split-lines` preserves empty pieces, including the final one:

| `s` | `(s split-lines)` |
|---|---|
| `""` | `(List of "")` |
| `"ab"` | `(List of "ab")` |
| `"ab\ncd"` | `(List of "ab" "cd")` |
| `"ab\n"` | `(List of "ab" "")` |
| `"\n"` | `(List of "" "")` |

It is implementable in Aloe by repeatedly comparing `(s take 1)` with
`"\n"`, accumulating that one-character `String`, and continuing with
`(s drop 1)`. It uses existing `String` and `List` messages. A helper selector
for that recursion is permitted, but it does not change these results.

Generic `insert` and `delete` messages are not added to `String`; span
replacement is a `Text` responsibility.

## 3. Values and construction

The implementation declares the following Aloe classes. Field order and
types are normative.

### 3.1 `Position`

```aloe
(define-class Position
  (fields
    (line Int)
    (column Int))
  (methods ...))
```

Construction is `(Position new line column)`. Coordinates are zero-based.
The end of a line is a valid column, so a line of length 3 admits columns 0
through 3.

A position is only meaningful relative to a `Text`. Construction itself does
not clamp or reject negative or out-of-range integers.

`Position` supplies these comparison messages:

| Send | Result |
|---|---|
| `(p = q)` | `Bool`; both fields are equal |
| `(p before? q)` | `Bool`; lexicographic order by line, then column |
| `(p before-or-equal? q)` | `Bool`; `(p before? q)` or `(p = q)` |
| `(p after string)` | `Position`; the position reached after inserting `string` at `p` |

`after` counts LF characters in `string`. With no LF, the result is
`(Position new (p line) ((p column) + (string len)))`. With `k > 0` LFs, the
result is on line `((p line) + k)` and its column is the length of the piece
after the last LF. Thus:

```aloe
((Position new 3 4) after "xy")       ; (Position new 3 6)
((Position new 3 4) after "x\nyz")   ; (Position new 4 2)
((Position new 3 4) after "\n")      ; (Position new 4 0)
```

The method may use `(string split-lines)`; it does not inspect characters as
`Char` values.

### 3.2 `Span`

```aloe
(define-class Span
  (fields
    (start Position)
    (end Position))
  (methods
    (empty? () Bool ...)))
```

Construction is `(Span new start end)`. A span denotes the half-open region
`[start, end)`. `(span empty?)` is true exactly when its endpoints are equal.

The constructor does not reorder endpoints. Span validity is relative to a
`Text`; a span whose start follows its end is invalid rather than silently
normalized.

### 3.3 `Text`

`Text` has one explicit constructor. The lowercase constructor selector is
intentional: it makes construction itself the `from-string` message.

```aloe
(define-class Text
  (constructors
    (from-string (fields (source String))))
  (methods ...))
```

Construction is:

```aloe
(Text from-string source)
```

The exact `source` is the representation. `Text` exposes:

| Send | Type | Meaning |
|---|---|---|
| `(text to-string)` | `String` | the exact source represented by `text` |
| `(text lines)` | `(List String)` | `(source split-lines)` |
| `(text valid-position? p)` | `Bool` | whether `p` is a position in `text` |
| `(text valid-span? span)` | `Bool` | whether both endpoints are valid and ordered |
| `(text replace span string)` | `(Option EditResult)` | replace `[start, end)` with `string` |
| `(text insert p string)` | `(Option EditResult)` | replace `[p, p)` with `string` |
| `(text delete span)` | `(Option EditResult)` | replace `span` with `""` |
| `(text newline p)` | `(Option EditResult)` | insert `"\n"` at `p` |

[`lib/text.aloe`](../../../../../lib/text.aloe) loads `option.aloe`. No
`Option` behavior is copied into this library.

### 3.4 `EditResult`

```aloe
(define-class EditResult
  (fields
    (text Text)
    (position Position))
  (methods))
```

Construction is `(EditResult new text position)`. It is the successful result
of an edit: `text` is the new value and `position` is the end of the inserted
string. It is not a delta, undo record, or mutable editor state.

Because `Text` edit methods return `EditResult` while `EditResult` contains a
`Text`, declaration order must not require an unsupported forward type. An
implementation can declare the non-editing portion of `Text`, then
`EditResult`, then add `replace`, `insert`, `delete`, and `newline` with
`define-methods Text`.

## 4. Lines and newline policy

Only LF splits a line. Carriage return has no special meaning here. For
example, `(Text from-string "a\r\nb")` has the lines
`(List of "a\r" "b")`. CRLF recognition or normalization belongs to the
later File layer.

There is no separate trailing-newline flag. A trailing LF is represented by
the source ending in `"\n"` and by a final empty line in `(text lines)`:

| Source | Lines |
|---|---|
| `"one\ntwo"` | `(List of "one" "two")` |
| `"one\ntwo\n"` | `(List of "one" "two" "")` |
| `""` | `(List of "")` |

Consequently `to-string` is the exact inverse of `from-string`, including
zero, one, or several trailing LFs:

```aloe
((Text from-string s) to-string) = s
```

## 5. Validity and offsets

For a `Text` with lines `lines`, a `Position(line, column)` is valid exactly
when:

1. `0 <= line < (lines len)`, and
2. `0 <= column <= ((the selected line) len)`.

The final empty line after a trailing LF is an ordinary line and admits its
single position at column 0.

A `Span(start, end)` is valid exactly when both endpoints are valid for the
same text and `start` is before or equal to `end`. Text does not clamp
coordinates and does not normalize a reversed span.

Invalid input is represented with `Option`, not a host exception:

- `valid-position?` and `valid-span?` return `#f`.
- `replace`, `insert`, `delete`, and `newline` return `(Option None)`.
- A valid operation returns `(Option Some edit-result)`.
- The input `Text`, `Position`, and `Span` remain unchanged in either case.

For a valid position `(line, column)`, its flat offset is:

```text
sum(len(each line before line) + 1) + column
```

The added 1 accounts for the LF between adjacent lines. This definition is
only part of replacement semantics; the project need not expose an offset as
a public message.

## 6. Replacement semantics

Let `old` be `(text to-string)`, let `a` and `b` be the flat offsets of a
valid span's start and end, and let `replacement` be the supplied `String`.
The successful replacement is exactly:

```aloe
(((old take a) append replacement) append (old drop b))
```

The returned value is:

```aloe
(Option Some
  (EditResult new
    (Text from-string new-source)
    ((span start) after replacement)))
```

This defines insertion, deletion, and newline without separate edit
machinery:

- `(text insert p s)` is `(text replace (Span new p p) s)`.
- `(text delete span)` is `(text replace span "")`.
- `(text newline p)` is `(text insert p "\n")`.

The returned position is always the end of the inserted content in the new
text. For deletion, the inserted content is empty, so it is the old span's
start. Positions other than this result are not rebased by this algebra.

A newline is content between two line positions. In particular, for a line
`r` whose length is `n`, the span from `(Position new r n)` to
`(Position new (r + 1) 0)` contains exactly that line's following LF.
Deleting it joins the two lines.

Every edit constructs fresh `Text`, `Position`, and `EditResult` values. Equal
payloads may compare equal under Aloe's normal structural equality, but the
operation has no in-place effect.

## 7. Required goldens

Tests live under `tests/aloemacs/`. They use the ordinary checked Aloe driver,
load `lib/text.aloe`, evaluate Aloe sends, and inspect Aloe results. Racket may
drive the tests, but there is no parallel Racket text API.

The following values are normative. `result-text` and `result-position` below
mean selecting the `text` and `position` fields from the `EditResult` carried
by `Some`; receiving `None` is a test failure.

### 7.1 Empty and round-trip

```aloe
((Text from-string "") lines)
; => (List of "")

((Text from-string "") to-string)
; => ""

((Text from-string "one\ntwo") to-string)
; => "one\ntwo"

((Text from-string "one\ntwo\n") to-string)
; => "one\ntwo\n"
```

The two nonempty fixtures must also have the exact line lists shown in
section 4.

### 7.2 Insert in a line

```aloe
(define before (Text from-string "abcd"))
(define result (before insert (Position new 0 2) "X"))
```

- `result-text` is `"abXcd"`.
- `result-position` is `(Position new 0 3)`.
- `(before to-string)` is still `"abcd"`.

### 7.3 Insert a newline

```aloe
((Text from-string "abcd") newline (Position new 0 2))
```

- `result-text` is `"ab\ncd"`.
- its lines are `(List of "ab" "cd")`.
- `result-position` is `(Position new 1 0)`.

### 7.4 Delete a character and a line separator

```aloe
((Text from-string "abcd") delete
  (Span new (Position new 0 1) (Position new 0 2)))
```

produces `"acd"` at `(Position new 0 1)`.

```aloe
((Text from-string "ab\ncd") delete
  (Span new (Position new 0 2) (Position new 1 0)))
```

produces `"abcd"` at `(Position new 0 2)`. This is the required
end-of-line join.

### 7.5 Replace a multi-line span

Shorter replacement:

```aloe
((Text from-string "ab\ncd\nef") replace
  (Span new (Position new 0 1) (Position new 2 1))
  "X")
```

produces `"aXf"` at `(Position new 0 2)`.

Longer replacement:

```aloe
((Text from-string "ab\ncd") replace
  (Span new (Position new 0 1) (Position new 1 1))
  "X\nY\nZ")
```

produces `"aX\nY\nZd"`, with lines `(List of "aX" "Y" "Zd")`, at
`(Position new 2 1)`.

### 7.6 Invalid coordinates

Each operation below returns `(Option None)`:

- insert at negative line or column;
- insert past the last line;
- insert one column past a line's end;
- replace when either endpoint is invalid;
- replace with a start after its end.

The corresponding boundary positions at column 0, at end-of-line, and on the
final empty line after a trailing LF return `Some`.

### 7.7 String prerequisite

Tests cover `drop` below, within, and above the bounds:

```aloe
("abc" drop -1)  ; => "abc"
("abc" drop 0)   ; => "abc"
("abc" drop 1)   ; => "bc"
("abc" drop 3)   ; => ""
("abc" drop 9)   ; => ""
```

They also cover every `split-lines` row in section 2.2 and verify that its
elements contain no LF.

## 8. Acceptance

The design is implemented when all of the following are true:

1. The public values and sends in sections 2 and 3 exist as typed Aloe
   messages with the stated results.
2. `Text`, `Position`, `Span`, and `EditResult` are ordinary immutable Aloe
   classes. Text behavior is not implemented as a public Racket API.
3. `drop` is the only new kernel operation, obeys its exact type and clamping
   contract, and `split-lines` is written in Aloe.
4. All validity, half-open span, replacement, newline, trailing-LF, and result
   position rules in sections 4–6 hold.
5. Checked Aloe tests under `tests/aloemacs/` prove every golden in section 7,
   including that the original text is unchanged.
6. The existing non-aloemacs test suite remains green.

## 9. Explicit non-goals

- A TTY, `Term`, ANSI, a frame, or an `examples/aloemacs/` loop
- File loading, saving, encoding, CRLF conversion, or final-newline policy
- Mutable vectors, boxes, setters, or a mutable buffer store
- Point as editor state, movement commands, goal columns, marks, selections,
  keymaps, windows, or minibuffers
- Deltas, snapshots, inverse edits, undo/redo, or rebasing other positions
- Search, indentation, syntax, evaluation of text, or reflection
- Tabs as display columns, grapheme clusters, `wcwidth`, or rendering
- Porting Chez Emacs `text.sls` or Legmacs `buffer.lg`
- `Char`, string indexing, general slicing, or any additional kernel message
- Global checkpoint numbers or changes to `CHECKPOINTS.md`
