# with 000 — Field update

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Add selector-position `with`, spelled without a star. On a concrete
instance of a `(fields ...)` class, a nonempty tail of `(field expr)`
pairs builds a new instance of that same class and those same type
arguments. Written fields are replaced. Every other stored field is
the original value.

```scheme
(p with (x 20) (y 30))
(editor with (mark val))
```

Stop when parse, checking, evaluation, the editor walkers, the
language-document amendments, and the tests below are green.

Do not rewrite Aloemacs, or any other `.aloe` program, to use the
form. Do not issue 001. Do not add `with*`. Do not make instance
`new*` a partial update.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` remains law except for the amendments this
checkpoint authorizes.

- Identity is **with 000**. File:
  `docs/design/implementation/with/checkpoints/000-field-update.md`.
  Number this locally. Do not add a global checkpoint or a
  `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- No predecessor. `new*` is already on `main`: `(fields ...)`
  construction, pair shape, declaration-order checking, and
  written-order evaluation. Reuse that machinery. Do not change
  `new*` acceptance.
- Read [`docs/workflow.md`](../../../../workflow.md) and
  [`SPEC.md`](../../../../../SPEC.md) before writing code. §3.2 and
  §4.11 are the construction law this form sits beside. §4.10 is the
  other reserved selector-position form.

Evaluation remains send. Selectors are literal. Functions run through
`call`. `let` expands to `fn` plus `call`. Add no inheritance, Aloe
mutation, macros, implicit Int/Float coercion, or any other special
form.

## Exact file scope

### May create or edit

- `aloe/parse.rkt` — a `with-expr` node, pair-shape validation, and
  `expression-loc`.
- `aloe/type.rkt` — checking.
- `aloe/eval.rkt` — evaluation.
- `aloe/private/expression-selection.rkt` — children are the receiver
  and the value expressions, in written order.
- `aloe/private/completion-selection.rkt` — the same children, and
  `with` joined to the reserved selector set that already holds
  `case` and `new*`.
- `aloe/completion-query.rkt` — the same children.
- `SPEC.md` — only the edits in **Language law** below.
- `docs/decisions.md` — only the one entry in **Language law**.
- `tests/with/grammar.rkt` and `tests/with/law.rkt`, both new.
  Keep fixtures and helpers in these files.

### Must leave untouched

- Every `.aloe` program, including `examples/aloemacs/`.
- `new*` acceptance, diagnostics, and tests. A shared helper may
  grow only when `new*` behavior stays the same.
- `aloe/expression-query.rkt`, `aloe/lsp.rkt`, drivers, host
  implementations, signature catalogs, and libraries.
- `tests/editor/source-locations/000-spans.rkt` and every existing
  test. Its location walker has a catch-all; cover `with` locations
  in `tests/with/grammar.rkt`.
- `CHECKPOINTS.md`, `docs/checkpoints/`, this folder's README, this
  checkpoint, and every other design document.
- Gel, Boids, and unrelated working-tree changes.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back instead of widening it. If the slice cannot
fit one implementer conversation, stop and say so. Promote it to a
charter rather than cutting the rules below.

## Slice requirements

### 1. Grammar

`with` in the second position is syntax, not a send. It is reserved
there the way `case` and `new*` are. Elsewhere `with` stays an
ordinary source name: `(define with 3)` is still a definition, and
`(with p (x 1))` is an ordinary combination whose receiver is the
variable `with`. It is not this form.

The tail is zero or more forms, but zero is a syntax error. Each
other form is a proper list of two elements whose first element is a
symbol. Validate every pair, and reject an empty tail, before parsing
the receiver or any value. A malformed pair or an empty tail runs no
receiver and no value.

Reuse `construction-binding`. Store the form as a transparent
`with-expr` of the receiver, the bindings in written order, and the
form's source location. Pair names are not expressions and introduce
no bindings. Square brackets gain no meaning.

| Source | Result |
|---|---|
| `(p with (x 1) (y 2))` | `with-expr`; names `x`, `y` in that order |
| `(p with (x 1))` | one pair; the flat spelling is not also accepted |
| `(p with)` | syntax error; receiver is not parsed |
| `(p with x 1)` | syntax error |
| `(p with (x))` and `(p with (x 1 2))` | syntax error |
| `(with p (x 1))` | ordinary send, not `with-expr` |

The expression's children are the receiver and then each value
expression, in written order. A label is not a child. The form's
location covers the whole combination. Selector completion does not
treat `with` as an ordinary send selector.

### 2. What it means

For a well-shaped form, the result is the receiver's class and
constructor `new`, with this payload:

- a written field gets its value expression's result
- every unwritten field gets the value stored in the receiver

The result's type is the receiver's type, including type arguments
that are already known. Replacements are checked against the field
types at that instantiation. Updating `(flag Bool)` on a `(Box Int)`
still yields a `(Box Int)`. Updating the `Int` field with a `String`
is a type error. This form does not replace an already-known type
argument.

If a type argument of the receiver is still a variable, checking a
replacement against its field type may instantiate that variable by
ordinary unification. The result type is still the receiver's type.

Unwritten fields are not checked again and are not evaluated. Copy
the stored payload values. Do not build expressions for them, and do
not send to the receiver to read them.

There is no missing-field error. One pair is enough on a class of
many fields. A `(fields)` class has no legal `with`, because the
empty tail is a syntax error.

### 3. Checking order

After the parser accepts the shape:

1. Infer the receiver with the existing expression rules. Report
   receiver errors, including an unbound name, before eligibility or
   field names.
2. Require a concrete instance whose class is declared with
   `(fields ...)` and has the generated `new` constructor. Use the
   explicit-constructor flag; a constructor named `new` on an
   explicit `(constructors ...)` class does not qualify. Reject a
   class object, `List`, a primitive class object, an instance of an
   explicit-constructor class, and a protocol-typed receiver.
3. Walk names in written order. Report the first unknown field or
   duplicate field, whichever offending pair appears first, and stop.
   Do not infer any value before the names are accepted.
4. Check the written values in field declaration order, each against
   that field's instantiated type. Do not check them by first
   expanding into `let` or into a `new*` node. Do not infer a fresh
   class type from the replacements.

Use `exn:fail:aloe-type` for checker failures. Keep ineligible
`with`, unknown field, duplicate field, and type mismatch
distinguishable, and name the offending fields. Tests pin categories
and field names, not whole sentences.

| Form | Required result |
|---|---|
| `(p with (z 1) (x 1) (x 2))` | Unknown field `z` |
| `(p with (x 1) (x 2) (z 3))` | Duplicate field `x`; `z` is not the report |
| `(p with (y "bad"))` on `(Point Int)` | Type mismatch; `y` is `Int` |
| `((Option Some 1) with (value 2))` | Ineligible `with` |
| `(Point with (x 1))` | Ineligible `with`; `Point` is the class |
| `(p with (x 1.0))` on a `(Point Int)` | Type mismatch |

A computed receiver whose existing rules already give one eligible
instance type is legal. Do not change `if`.

### 4. Evaluation order

On raw `eval-expr`, independently of the checker:

1. The parser has already rejected an empty tail and a malformed pair.
2. Evaluate the receiver once.
3. Apply the same eligibility rule, then the same written-order
   unknown and duplicate checks. A failure here evaluates no value.
4. Evaluate each written value once, in written order, in the
   surrounding environment. Names and the `with` token do not
   evaluate and bind nothing. Each value sees the original receiver,
   not an earlier replacement.
5. Assemble declaration-order arguments: written results in their
   field slots, stored payload values in the others. Construct with
   the receiver's class and selector `new`.

```scheme
(p with
  (x (p y))
  (y (p x)))
```

swaps the original coordinates. In a method, a parameter may share a
field's name. The pair name is the field; the value expression sees
the parameter:

```scheme
(set-x (x Int) Point
  (self with (x x)))
```

The constructed instance uses constructor `new`. Omitted slots are
the same values that were stored in the receiver, not reconstructions.

### 5. Reflection and neighbors

Mirror gains no `with` row. Field selectors and `new` stay as they
are. `new*` still requires every field and still reports missing
fields. A method selector `with` cannot be sent, because that source
position is this syntax; do not add a separate definition-time ban
beyond what `case` and `new*` already have.

## Language law

Amend `SPEC.md` in its current voice. Do not edit any other section.

- §3.2, after the `new*` paragraph: an instance of a `(fields ...)`
  class is updated by `(receiver with (name expr) ...)`. That is
  syntax, not a send. Point at the new section. It adds no reflected
  message.
- New §4.12 `with`, directly after §4.11. State the grammar, the
  reservation, the nonempty pair tail, eligibility, the result type,
  payload copying, declaration-order checking, written-order
  evaluation, and that names bind nothing. Say that `with` remains an
  ordinary source name outside the selector position, that square
  brackets gain no meaning, and that reflection exposes no `with` row.
- §5.3, one bullet beside the `case` bullet: concrete `(fields ...)`
  instance, not a class object, an explicit-constructor instance, or
  a protocol-typed value; result type is the receiver's type;
  replacements checked in declaration order; unknown and duplicate
  fields reported from written order; empty tail is a syntax error.
- §9, beside the labeled Point goldens:
  - `((Point new 1 2) with (x 3))` → a `(Point Int)`, equal to
    `(Point new 3 2)`
  - `((Point new 1 2) with (x 1.0))` is a type error

Leave the §8 setter bullet in place. This form constructs a value.
It is not a setter.

Add one `docs/decisions.md` entry, dated the day it is written, after
the parenthetical-construction entry:

> **Field update (`with`).** Decided: selector-position `with` updates
> a concrete `(fields ...)` instance. The tail is a nonempty list of
> `(name expr)` pairs in the `new*` shape. Pair names are literal
> fields and bind nothing. The result keeps the receiver's class and
> type arguments. Unwritten fields keep their stored values. Values
> are checked in declaration order and evaluated in written order
> against the original receiver. Rejected for this slice: `with*`, a
> prefix `with`, a flat tail, instance `new*` as a partial update,
> punning, nested field paths, generated per-field methods,
> constructor-class updates, and a Mirror row.

## Tests

Follow the driver, trace, and diagnostic style of
`tests/parenthetical-construction/law.rkt`. Pin categories and names.

`tests/with/grammar.rkt` covers the parse table in §1, children,
locations, and that a malformed pair or empty tail does not parse the
receiver.

`tests/with/law.rkt` covers at least:

- one field and several fields, judged equal to the positional `new`
  of the assembled payload
- an omitted field slot identical to the receiver's stored value
- the coordinate swap, so each value sees the original receiver
- a method whose parameter shares the field name
- written-order effects: the receiver's effect runs once, then the
  value effects in source order; an unknown or duplicate name runs
  no value effect
- the diagnostic table in §3, plus an empty tail as a syntax error
- a protocol-typed receiver is ineligible
- `(Box Int)` updated in a `Bool` field stays `(Box Int)` at the
  checker and at runtime; a `String` in the `Int` field is a type
  error
- a nested `with` is only an ordinary value expression
- `new*` still reports a missing field
- a fields class's Mirror messages do not include `with`
- `(define with 1)` still evaluates, and `(with p (x 1))` is not
  accepted as an update

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/with
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

The checkpoint is complete when both test commands pass, the
whitespace check is clean, and the file scope is respected. Report
the results and stop.

Do not commit. Do not start an Aloemacs conversion. Do not write 001.
