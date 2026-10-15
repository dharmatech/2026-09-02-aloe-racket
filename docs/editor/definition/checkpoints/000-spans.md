# Editor definition 000 — Name and type spans

**Status.** Implemented 2026-10-15. Manager-reviewed 2026-10-15 against
this document: conforming. Accepted by the human 2026-10-15. The
whole-suite count under Acceptance was corrected after implementation;
the two new fixtures each add a modules-census case.

## Goal

`read-program` records three kinds of name token that are not
expressions. These are the class name in a `define-class` header, the
target of a `define-methods` form, and every symbol of every type
annotation. The checker copies the class name's span onto the class
record. `parse-datum` stays location-free. Hover, completion, the
evaluator, and every error text are unchanged.

This checkpoint only stores these spans and proves them in tests. It
adds no query, no LSP method, and no jump. A later checkpoint reads the
spans.

The implementer receives only this document. Every rule for this slice
is below.

## Depends on, identity

Identity is `(editor-definition, 000)`, spoken **editor-definition
000**. It is a local editor checkpoint, not a global checkpoint. Do not
edit `CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

The tree at `3b77e99` (branch `experiment/2026-10-14-definition`) has
every predecessor:

- **Editor-source-locations 000.** Every `*-expr` in `aloe/parse.rkt`
  ends in a `loc` field. `send-expr` ends in `loc selector-loc`.
  `read-program` reads with `read-syntax` and parses the syntax objects.
  `parse-datum` is `(parse-syntax-expression (datum->syntax #f datum))`,
  so it shares that parser, and every location it records is `#f`.
- **Editor-lsp 010.** The parser has one location helper,
  `syntax-location`. It turns a syntax object into a `srcloc` whose
  position and span count characters of the source text, with CR and LF
  counted as two. It returns `#f` for a syntax object that has no
  location, which is every syntax object `parse-datum` builds.
- **Modules layer 4.** `class-info` in `aloe/type.rkt` ends in a
  mutable `defining-path`. Hover prints a `from:` line with
  `Name@path`.

## Authority

- `SPEC.md` is law and is not amended. Aloe's meaning does not change.
- [`docs/editor/definition/spec.md`](../spec.md) §3 is the design of
  this layer. This checkpoint restates every rule from it that you
  need.
- [Editor-source-locations 000](../../source-locations/checkpoints/000-spans.md)
  banned locations on declarations. The definition spec amends that ban
  for three name tokens: a class name, a `define-methods` target, and
  the symbols of a type. Its other bans hold. Do not add a wrapper node,
  side table, program-wide parallel syntax tree, structure property, or
  new expression type. A span tree stored in one field of one
  declaration is allowed. It is not the banned parallel syntax tree.

## Required behavior

### New fields

Each of these five structures in `aloe/parse.rkt` gains one field after
its existing fields. The field lists after this checkpoint are exactly:

| Structure | Fields |
|---|---|
| `define-class-expr` | `name type-parameters protocol fields constructors methods loc name-loc` |
| `define-methods-expr` | `target methods loc target-loc` |
| `field-declaration` | `name type type-spans` |
| `parameter-declaration` | `name type type-spans` |
| `method-declaration` | `selector type-parameters parameters return-type body return-type-spans` |

- **`name-loc`** is the `srcloc` of the class-name symbol in the
  `define-class` header. That is the header itself when the header is a
  bare symbol (`(define-class Segment ...)`). It is the first element
  when the header is `(Name T ...)`, so `(define-class (Box T) ...)`
  records the span of `Box`.
- **`target-loc`** is the `srcloc` of the `define-methods` target
  symbol.
- **`type-spans`** is the span tree of the field's or parameter's type.
  This covers every field in a `fields` section, every field of every
  constructor, every method parameter in `define-class` and
  `define-methods`, and every parameter of a protocol signature.
- **`return-type-spans`** is the span tree of the method's return type.
  This covers methods in `define-class` and `define-methods`, and
  protocol signatures.

Take each `srcloc` from that symbol's own syntax object, through
`syntax-location`, the way `selector-loc` is taken today. Never call
`syntax-position` or `syntax-span` directly. `syntax-location` already
counts CR LF as two characters, and the new spans must count the same
way.

The whole-form `loc` of `define-class-expr` and `define-methods-expr`
stays the span of the whole form.

### Span trees

The span tree of a type form is:

- for a symbol: its `srcloc`;
- for a form that `syntax->list` turns into a list: a list of the span
  trees of its elements, in order, with the same length;
- for anything else (a number, a string, a vector, an improper list):
  `#f`.

The `type` and `return-type` fields are unchanged. They still hold the
datum of the same form. So at every list and every symbol, the datum
and its span tree have the same shape. Writing `[X]` for the `srcloc` of
the symbol `X`:

| Type datum | Span tree |
|---|---|
| `Point` | `[Point]` |
| `(Option Point)` | `([Option] [Point])` |
| `(List (Box Point))` | `([List] ([Box] [Point]))` |
| `(-> Int Point)` | `([->] [Int] [Point])` |
| `(List 3)` | `([List] #f)` |
| `3`, `"s"`, `(Option . Point)`, `#(Point)` | `#f` |

Every symbol gets a span. That includes `->`, `List`, `Int`, kernel
names, aliases, protocol names, and type parameters. The parser does
not decide which symbols name classes. Each occurrence has its own span.

### `parse-datum` and `parse-program`

`parse-datum` and `parse-program` set every new field to `#f`. A whole
`type-spans` or `return-type-spans` field is `#f`, not a tree of `#f`.
Make this a single test in the shared parser: when the type form's
syntax object carries no location (`syntax-location` returns `#f`), the
field is `#f`. Under `read-program` every form carries one. `name-loc`
and `target-loc` get `#f` from `syntax-location` with no extra rule.

Two `parse-datum` trees of the same datum still compare `equal?`.

### Declarations parse from syntax objects

Today `parse-field-declaration`, `parse-parameter-declaration`,
`parse-constructor-declaration`, `parse-constructors`, and
`parse-protocol-signature` receive datums from `syntax->datum`, which
drops the spans. Change them to receive the syntax objects. Their
callers in `parse-class-syntax`, `parse-method-syntax`, and the
`define-protocol` branch of `parse-syntax-expression` pass the forms
unconverted.

They may still match on `(syntax->datum form)`. They must:

- store exactly the same `name`, `type`, `selector`, and field datums
  as today;
- accept exactly the same grammar;
- raise the same `parse-datum` errors with exactly the same text, in
  the same order, through both `parse-datum` and `read-program` (see
  test 6 for the pinned messages).

A helper such as `type-span-tree` beside `syntax-location` builds the
trees. Keep one parser. Do not add a second grammar.

### What stays without spans

Do not add a location to `constructor-declaration`, `case-clause`, the
name of `define-protocol`, the name of `define`, `fn` and `let`
parameters, `case` payload names, `new*` and `with` binding names, the
type parameters in a class header, a method's `(type ...)` names, a
class's protocol slot, method selectors, or constructor selectors.

Expression nodes, `expression-loc`, `selector-loc`, and every whole-form
`loc` are unchanged.

### The class record

`class-info` in `aloe/type.rkt` gains one final field, `name-loc`,
after `defining-path`. It is not mutable. Update the comment above the
struct to say it records the class name's span, or `#f`.

`check-class-definition!` takes the form's `name-loc` as a new final
argument. The `define-class-expr` arm of `infer-expression` binds it
from the form and passes it. `check-class-definition!` stores it in the
`class-info` it builds. This is its one caller, and that `class-info`
construction is the only one in the repository.

A class built from a `parse-datum` form records `#f`. The base's
`Option` record carries the span read from `lib/option.aloe`, because
`aloe/library.rkt` already reads that file with `read-program`. You do
not edit `aloe/library.rkt`.

The `define-methods` target span is not copied onto any class. The
evaluator's `class-value` gains nothing.

### Test hook

Add a submodule to `aloe/type.rkt`, beside the `method-records` hook:

```racket
;; Tests read the class-name span on a class record through this hook;
;; nothing else does.
(module* class-name-span #f
  (provide checker-class-name-loc)
  ...)
```

`(checker-class-name-loc environment name)` returns the `name-loc` of
the class record bound to `name` in `environment`, which may be `#f`.
When `name` is bound to anything that is not a class record (a
`class-type`), it raises with `error`, as `checker-class-environment`
does. That includes a protocol and the `List`, `String`, and `Int`
class objects. An unbound name raises the checker's own unbound-symbol
error.

### Mechanical migration

Every other construction of the five structures gains `#f` for each new
field. Every other match gains `_`. Make no other change in these files.
This inventory comes from a scratch run (below), and it is complete as of
`3b77e99`. Line numbers are as of that commit.

| File | Lines | Edit |
|---|---|---|
| `aloe/parse.rkt` | 74, 75 | `expression-loc`: one more `_` in the `define-class-expr` and `define-methods-expr` patterns |
| `aloe/type.rkt` | 767, 950 | one more `_` in the `define-class-expr` and `define-methods-expr` patterns. Line 938 is the `infer-expression` arm above, not mechanical |
| `aloe/eval.rkt` | 139, 195, 216 | one more `_` in each pattern |
| `aloe/private/expression-selection.rkt` | 22, 24 | one more `_` in each pattern |
| `aloe/private/completion-selection.rkt` | 40, 42 | one more `_` in each pattern |
| `tests/checkpoint-115.rkt` | 99–123 | In the `check-match` pattern, add `_` to `parameter-declaration`, to `method-declaration` after the body pattern, and to `define-methods-expr` after its `_` |
| `tests/int-methods/001-library.rkt` | 57–66 | In the `check-match` pattern, add `_` to both `parameter-declaration`s, to both `method-declaration`s, and to `define-methods-expr` |
| `tests/editor/signatures-of-type/000-shared-catalog.rkt` | 182–194 | Add `#f` to the three `field-declaration` constructions, the two `parameter-declaration` constructions, and the two `method-declaration` constructions |
| `tests/editor/source-locations/000-spans.rkt` | 80, 83 | one more `_` in the `define-class-expr` and `define-methods-expr` patterns |
| `tests/modules/001-census.rkt` | 77, 111, 167, 183 | one more `_` in each pattern |

The `check-match` patterns in `tests/checkpoint-115.rkt` and
`tests/int-methods/001-library.rkt` match library expressions that
`read-program` parsed. Their new fields hold `srcloc`s and span trees,
not `#f`. Use `_` there, never `#f`.

A `match` pattern with the wrong number of fields is a compile-time
error. Under `raco test -j 4 -y tests`, the first such file stops the
whole run, and no summary prints. If the run ends without a
`N/M test failures` or `N tests passed` line, look for a `match:
insufficient number of fields` error.

The definition spec §3.6 permits one non-mechanical edit:
`normalize-locations` in `tests/editor/source-locations/000-spans.rkt`.
The scratch run shows it is not needed. No datum in that file's
shared-grammar test has a list-shaped type. So each span tree there is
one `srcloc`, which normalizes to `#f`, the same as `parse-datum`'s `#f`.
Leave `normalize-locations` and every assertion in that file unchanged.

If any other existing test fails, stop and report it.

## Exact file scope

May edit:

- `aloe/parse.rkt`
- `aloe/type.rkt`
- `aloe/eval.rkt`, `aloe/private/expression-selection.rkt`, and
  `aloe/private/completion-selection.rkt`, only for the mechanical
  edits in the table
- the five existing test files in the table, only for the mechanical
  edits in the table
- `tests/editor/definition/000-spans.rkt` (new)
- `tests/editor/definition/fixtures/point.aloe` and
  `tests/editor/definition/fixtures/shapes.aloe` (new)
- `docs/editor/definition/README.md` and `docs/editor/README.md`, for
  the status lines below

Do not edit:

- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- `docs/editor/definition/spec.md`, `docs/editor/lsp/spec.md`,
  `docs/editor/expression-query/spec.md`,
  `docs/editor/source-locations/checkpoints/000-spans.md`, or any other
  spec, charter, or checkpoint
- `aloe/expression-query.rkt`, `aloe/completion-query.rkt`,
  `aloe/lsp.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/library.rkt`, `aloe/signature-catalog.rkt`, or
  `aloe/private/checker-observation.rkt`
- `lib/`, `examples/`, `editors/vscode/`, `gel/`, or `host/`
- any type-error, runtime-error, or parse-error text

Do not create `aloe/definition-query.rkt`,
`aloe/private/definition-selection.rkt`, or the fixtures `wide.aloe` and
`wide-user.aloe`. Later checkpoints add them.

## Fixtures

Both files are ASCII with one LF after every line. Later checkpoints of
this series reuse them unchanged.

`tests/editor/definition/fixtures/point.aloe`, 5 lines, 68 bytes:

```aloe
(define-class Point
  (fields
    (x Int)
    (y Int))
  (methods))
```

`tests/editor/definition/fixtures/shapes.aloe`, 52 lines, 1077 bytes:

```aloe
(load "point.aloe")
; Point and Box in a comment do not jump.

(define-protocol Mover
  (moved (by Point) Point))

(define-class (Box T)
  (fields
    (item T)
    (corner Point)
    (spare (Option Point)))
  (methods
    (fresh () Point
      (Point new 0 0))))

(define-class Segment Mover
  (constructors
    (Line (fields (from Point) (to Point)))
    (Dot (fields (at Point))))
  (methods
    (moved (by Point) Point
      by)))

(define-methods Point
  (methods
    (boxed (type A) (item A) (Box A)
      (Box new item self (Option None)))
    (nudge (m Mover) Point
      (m moved self))))

(define-methods Box
  (methods
    (item-of () T
      (self item))))

(define P Point)

(define-class Holder
  (fields
    (p P)
    (boxes (List (Box Point)))
    (maker (-> Int Point)))
  (methods))

(define origin (Point new 0 0))
(define ox (origin x))
(define alias-made (P new 3 4))
(define again ((fn (Point) (Point new 1 2)) call Point))
(define third (Point new* (x 5) (y 6)))
(define shifted (origin with (x 9)))
(define no-points (List empty))
(define label "Point")
```

Both files check and run on the tree at `3b77e99`.

## Required tests

Add `tests/editor/definition/000-spans.rkt`. It is three directories
below the repository root, so use `../../../aloe/...` for module paths.
Use `define-runtime-path` for the fixtures and for `lib/option.aloe`.

Locations are written `(line column position span)`. Lines are
one-based, columns zero-based, and positions one-based, as `srcloc`
reports them. Unless a test says otherwise, also check that every
location's `srcloc-source` is the path that was passed in. All values
below were measured on a prototype of this edit, and the whole-form
locations were also measured on the found tree.

1. **Header and target spans.** Read `shapes.aloe` with `read-program`
   from an input port, with `#:source-path` set to the fixture path.

   | Form | Field | Location |
   |---|---|---|
   | `define-class` `Box` (generic header) | `name-loc` | `(7 15 131 3)` |
   | `define-class` `Segment` (bare header, protocol slot) | `name-loc` | `(16 14 279 7)` |
   | `define-class` `Holder` | `name-loc` | `(38 14 702 6)` |
   | `define-methods` `Point` | `target-loc` | `(24 16 452 5)` |
   | `define-methods` `Box` | `target-loc` | `(31 16 615 3)` |

   The whole-form `loc` values are unchanged. They are
   `define-protocol` `Mover` `(4 0 64 50)`, `Box` `(7 0 116 147)`,
   `Segment` `(16 0 265 169)`, `define-methods` `Point`
   `(24 0 436 161)`, `define-methods` `Box` `(31 0 599 69)`, and
   `Holder` `(38 0 688 112)`.

2. **Span trees.** From the same read, each tree has exactly this shape
   and these locations. `[l c p s]` is a `srcloc`, and a parenthesized
   group is a Racket list:

   | Where | Type datum | Span tree |
   |---|---|---|
   | `Mover`'s `moved`, parameter `by` | `Point` | `[5 13 100 5]` |
   | `Mover`'s `moved`, return | `Point` | `[5 20 107 5]` |
   | `Box` field `item` | `T` | `[9 10 158 1]` |
   | `Box` field `corner` | `Point` | `[10 12 173 5]` |
   | `Box` field `spare` | `(Option Point)` | `([11 12 192 6] [11 19 199 5])` |
   | `Box`'s `fresh`, return | `Point` | `[13 14 233 5]` |
   | `Segment` constructor `Line`, field `from` | `Point` | `[18 24 333 5]` |
   | `Segment` constructor `Line`, field `to` | `Point` | `[18 35 344 5]` |
   | `Segment` constructor `Dot`, field `at` | `Point` | `[19 21 374 5]` |
   | `Segment`'s `moved`, parameter `by` | `Point` | `[21 15 410 5]` |
   | `Segment`'s `moved`, return | `Point` | `[21 22 417 5]` |
   | `define-methods Point`'s `boxed`, parameter `item` | `A` | `[26 26 495 1]` |
   | `define-methods Point`'s `boxed`, return | `(Box A)` | `([26 30 499 3] [26 34 503 1])` |
   | `define-methods Point`'s `nudge`, parameter `m` | `Mover` | `[28 14 561 5]` |
   | `define-methods Point`'s `nudge`, return | `Point` | `[28 21 568 5]` |
   | `define-methods Box`'s `item-of`, return | `T` | `[33 16 646 1]` |
   | `Holder` field `p` | `P` | `[40 7 726 1]` |
   | `Holder` field `boxes` | `(List (Box Point))` | `([41 12 741 4] ([41 18 747 3] [41 22 751 5]))` |
   | `Holder` field `maker` | `(-> Int Point)` | `([42 12 772 2] [42 15 775 3] [42 19 779 5])` |

   Also check that each `type` and `return-type` field still holds the
   datum in the Type datum column.

3. **Span-tree leaves that are not symbols.** Read this string with
   `read-program` and no `#:source-path`:

   ```racket
   "(define-class Odd\n  (fields (a 3) (b \"s\") (c (Option . Point)) (d #(Point)) (e (List 3)) (f (Option)))\n  (methods))\n"
   ```

   The `type-spans` of `a`, `b`, `c`, and `d` are `#f`. The tree of
   `e` is a two-element list: a `srcloc` `(2 62 81 4)`, then `#f`. The
   tree of `f` is a one-element list holding `(2 75 94 6)`. `name-loc`
   is `(1 14 15 3)`. Do not check the source here.

4. **Location-free datums.** Read every top-level datum of
   `shapes.aloe` with Racket's `read`, and parse each one twice with
   `parse-datum`. The two parses are `equal?`. In every
   `define-class-expr`, `name-loc` is `#f`. In every
   `define-methods-expr`, `target-loc` is `#f`. Every `type-spans`
   (class fields, constructor fields, and method and signature
   parameters) and every `return-type-spans` is `#f` as a whole field.
   `parse-program` of the same list of datums gives the same results.

5. **The class record.** Require
   `(submod "../../../aloe/type.rkt" class-name-span)` and
   `"../../../aloe/driver.rkt"`.

   - In a fresh driver, `driver-load-file!` `shapes.aloe`, with output
     to `(open-output-nowhere)`. Then `checker-class-name-loc` of the
     driver's type environment gives `(7 15 131 3)` for `Box`,
     `(16 14 279 7)` for `Segment`, and `(38 14 702 6)` for `Holder`,
     each with the shapes fixture path as its source.
   - In another fresh driver, `driver-load-file!` `point.aloe`. `Point`
     gives `(1 14 15 5)` with the point fixture path as its source.
   - `driver-eval!` of `'(define-class Q (fields (a Int)) (methods))`
     gives a class whose `checker-class-name-loc` is `#f`.
   - In a fresh driver, `Option` gives `(1 15 16 6)`. Check only line,
     column, position, and span. Its source is the path
     `aloe/library.rkt` passed to `read-program`, which is not
     simplified.
   - After the `shapes.aloe` load, `checker-class-name-loc` of `Mover`,
     a protocol, raises `exn:fail?`.

6. **Error text is unchanged.** For each pair below, `parse-datum` of
   the datum read from the source and `read-program` of the source
   string both raise `exn:fail?` with exactly this message. The messages
   were captured on the tree at `3b77e99`.

   ```racket
   '(("(define-class A (fields (x)) (methods))"
      "parse-datum: malformed field; expected (name Type)\n  field: '(x)")
     ("(define-class A (fields (x Int . y)) (methods))"
      "parse-datum: malformed field; expected (name Type)\n  field: '(x Int . y)")
     ("(define-class A (fields (x Int) (x Int)) (methods))"
      "parse-datum: field names must be unique\n  field: 'x\n  datum: '(define-class A (fields (x Int) (x Int)) (methods))")
     ("(define-class A (constructors (B)) (methods))"
      "parse-datum: malformed constructor; expected (Name (fields ...))\n  constructor: '(B)")
     ("(define-class A (constructors (B (fields . 3))) (methods))"
      "parse-datum: malformed constructor fields; expected (fields ...)\n  constructor: '(B (fields . 3))")
     ("(define-class A (constructors (B (fields (x Int) (x Int)))) (methods))"
      "parse-datum: field names must be unique\n  field: 'x\n  datum: '(B (fields (x Int) (x Int)))")
     ("(define-class A (constructors (B (fields)) (B (fields))) (methods))"
      "parse-datum: constructor selectors must be unique\n  selector: 'B\n  datum: '(define-class A (constructors (B (fields)) (B (fields))) (methods))")
     ("(define-class A (constructors) (methods))"
      "parse-datum: constructors section must be nonempty\n  datum: '(define-class A (constructors) (methods))")
     ("(define-methods A (methods (m (x Int) (y) Int 1)))"
      "parse-datum: malformed parameter; expected (name Type)\n  parameter: '(y)")
     ("(define-class A (fields) (methods (m () 3 1)))"
      "parse-datum: method return type must be a type expression\n  return type: 3\n  method: '(m () 3 1)")
     ("(define-protocol P 3)"
      "parse-datum: malformed protocol signature\n  signature: 3")
     ("(define-protocol P (ping))"
      "parse-datum: malformed protocol signature; expected parameters and a return type\n  signature: '(ping)")
     ("(define-protocol P (ping () Int Int))"
      "parse-datum: malformed zero-parameter protocol signature\n  signature: '(ping () Int Int)")
     ("(define-protocol P (ping (x Int) 3))"
      "parse-datum: protocol return type must be a type expression\n  return type: 3\n  signature: '(ping (x Int) 3)")
     ("(define-protocol P (ping (x) Int))"
      "parse-datum: malformed parameter; expected (name Type)\n  parameter: '(x)"))
   ```

7. **Hover is unchanged.** Through `query-expression-at` from
   `../../../aloe/expression-query.rkt`, query `shapes.aloe` at position
   680, the `Point` in `(define P Point)`. The result is:

   - type `'(Class Point)`;
   - signatures `(list (signature-spec 'new '(Int Int) 'Point))`;
   - pathed type `(list 'Class (string->symbol "Point@tests/editor/definition/fixtures/point.aloe"))`;
   - location `(36 10 680 5)`, whose source is the shapes fixture path,
     complete and simplified.

   This is the result on the found tree. In LSP hover terms, the text
   is `type: (Class Point)`, then
   `from: (Class Point@tests/editor/definition/fixtures/point.aloe)`,
   `messages:`, and `  new : (Int Int) -> Point`, with range LSP line
   35, characters 10 to 15.

The existing hover, completion, and LSP tests stay green without edits.
They are the rest of the "hover is unchanged" proof.

## Scratch run

On 2026-10-14 a prototype of this edit was applied to a copy of the
tree at `3b77e99`. It changed about 60 lines of `aloe/parse.rkt` and
about 20 of `aloe/type.rkt`, plus the mechanical table. Then:

- Every location in tests 1–3 and 5, and the hover result of test 7,
  came out as listed. Every message in test 6 was identical on the
  found tree and on the prototype, through both entry points.
- Before the two `check-match` patterns were migrated,
  `raco test -j 4 -y tests` stopped at a compile error in
  `tests/checkpoint-115.rkt` and printed no summary.
- With the ten files of the table migrated, the whole suite ran 3017
  tests under `-j 4`, and no file crashed. The one failure was
  `tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar (30.2 ms), a
  known flake under parallel load that does not touch the parser.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/definition/000-spans.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

All green. The whole suite is 3017 tests, plus this checkpoint's new
ones, plus one case per new fixture: `tests/modules/001-census.rkt`
makes a test for every `.aloe` file under `tests/`, so `point.aloe`
and `shapes.aloe` add two. At implementation that was 3026. If only `tests/aloemacs/window-pictures.rkt`'s timing bar fails
under `-j 4`, run that file alone, and it must pass there.

There is no hand check for this checkpoint. The editor shows nothing
new until the LSP layer.

Update the status lines:

- In `docs/editor/definition/README.md`, set the
  `checkpoints/000-spans.md` row to "Implemented *date*, awaiting
  review." Add the focused test count and the whole-suite count.
- In `docs/editor/README.md`, set project 8's cell to say
  editor-definition 000 is implemented and awaiting review.

Stop for review without committing. Do not write or start
editor-definition 001.

## Explicit non-goals

- `query-definition-at`, `aloe/definition-query.rkt`, token finding, a
  definition observer, or any change to `checker-observation.rkt`
- `textDocument/definition`, `definitionProvider`, or any edit to
  `aloe/lsp.rkt` or `editors/vscode/`
- Resolving a type symbol to a class, or deciding which symbols name
  classes
- Spans on any token in "What stays without spans"
- A span on the evaluator's `class-value`, or copying `target-loc` onto
  a class
- Location-bearing type or parse errors (source-locations 001)
- A change to how positions are counted (editor-lsp 010)
- The fixtures `wide.aloe` and `wide-user.aloe`
- A change to hover's text, range, or selection
