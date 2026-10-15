# Editor definition 002 — Type symbols

**Status.** Implemented 2026-10-15. Manager-reviewed 2026-10-15 against
this document: conforming. Accepted by the human 2026-10-15.

## Goal

`query-definition-at` also answers on **T** tokens, the symbols inside
type annotations. Examples are `Point` in a field type `(corner Point)`,
`Option` and `Point` in `(Option Point)`, and `Point` in a method's
return type. A type symbol jumps when the checker resolved it to a class,
in the environment and type-parameter scope where its annotation was
written, and its name is that class's own name.

This completes the query layer (definition spec §4). No LSP method is
added. That is the next layer.

The implementer receives only this document. Every rule for this slice
is below.

## Depends on, identity

Identity is `(editor-definition, 002)`, spoken **editor-definition
002**. It is a local editor checkpoint. Do not edit `CHECKPOINTS.md` or
add a file under `docs/checkpoints/`.

The tree at `a727aaa` (branch `experiment/2026-10-14-definition`) has
every predecessor:

- **Editor-definition 000.** `read-program` gives every
  `field-declaration` and `parameter-declaration` a `type-spans` field,
  and every `method-declaration` a `return-type-spans` field. Each is a
  *span tree* with the same shape as the type datum. A symbol's tree is
  its `srcloc`. A proper list's tree is a list of its elements' trees.
  Anything else is `#f`. For example, `(Option Point)` has the tree
  `([Option] [Point])`. A form built by `parse-datum` has `#f` for the
  whole field.
- **Editor-definition 001.** `aloe/definition-query.rkt` provides
  `query-definition-at`. The pieces behind it:
  - `aloe/private/definition-selection.rkt` finds the name token at the
    position: a `name-token` with an owner, a symbol, and a `srcloc`.
  - The definition observer in `aloe/private/checker-observation.rkt`
    waits for that owner in the one checker pass.
  - The `definition-query-observation` submodule of `aloe/type.rkt`
    applies the three jump rules (the symbol is the class's name; the
    class has a defining path; it has a `name-loc`). It returns the
    `name-loc`, the defining path, and the load-cache bytes.
  - Kinds V (variables), C (`define-class` names), and M
    (`define-methods` targets) jump today.
  - The test-case `"type symbols are not tokens before editor-definition 002"`
    in `tests/editor/definition/001-query.rkt` pins every T cursor of
    `shapes.aloe` at `#f`.
- **The checker.** `type-from-sexpr` in `aloe/type.rkt` turns a type
  datum into a checker type. Exactly two places call it for an
  annotation at its declaration:
  - the field loop in `check-class-definition!`, which covers the
    `fields` section and every constructor's fields;
  - `check-method-types!`, which covers each parameter and the return
    type. It is called for every method of a `define-class`, of a
    `define-methods` on a class (through `check-method-definition!`) or
    on `List`, `String`, or `Int`, and for every signature of a
    `define-protocol`.

  Every other call of `type-from-sexpr` is a later resolution. Examples
  are `check-method-body!`, `case` payloads, protocol conformance, and
  sends. Those are not declarations.

## Authority

- `SPEC.md` is law and is not amended.
- [`docs/editor/definition/spec.md`](../spec.md) §4.3–§4.6 and §4.8 are
  the design. §6.2 lists the T cursors, and §7 lists the coverage.
  Spec §2 splits the query layer into V, C, and M (001) and then T
  (this checkpoint). Spec §4.5 allows factoring `type-from-sexpr`'s cases
  so the checker and the query use one copy. This checkpoint takes that
  option. Every rule you need is restated below.

## Required behavior

### T tokens

Add kind T to the token walk in `aloe/private/definition-selection.rkt`.
Its tokens are every `srcloc` in these span trees:

- in a `define-class-expr`: the `type-spans` of every field in its
  `fields` section and of every field of every constructor. Also the
  `type-spans` of every parameter and the `return-type-spans` of every
  method;
- in a `define-methods-expr`: the `type-spans` of every parameter and the
  `return-type-spans` of every method;
- in a `define-protocol-expr`: the `type-spans` of every parameter and the
  `return-type-spans` of every signature.

Pair each `srcloc` with its symbol by walking the type datum and its span
tree together. A symbol meets a `srcloc`, and a list meets a list of the
same length. Anything else holds no token.

A T token's owner is the form that holds it (the `define-class-expr`,
`define-methods-expr`, or `define-protocol-expr`). Its symbol is that
symbol, and its `srcloc` is the one from the span tree. The token also
records that it is kind T. Containment is 001's: `s <= p < s + n`. A T
token never overlaps a C, M, or V token.

### Where a T token is observed

A type symbol resolves in the environment that wrote its annotation,
with the type parameters in scope there. Those are the arguments the
checker already passes at the declaration:

| Annotation | Checked by | Environment | Type parameters in scope |
|---|---|---|---|
| a field type, in `fields` or a constructor | `check-class-definition!` | the `define-class` form's | the class's |
| a parameter or return type in `define-class` | `check-method-types!` | the form's | the class's, plus the method's `(type ...)` |
| a parameter or return type in `define-methods` | `check-method-types!` | the form's | the target's (a class's type parameters; `T` for `List`; none for `String` and `Int`), plus the method's `(type ...)` |
| a parameter or return type in a protocol signature | `check-method-types!` | the `define-protocol` form's | none |

Observe the token **inside `type-from-sexpr`, at the declaration only**:

- `type-from-sexpr` gains an optional fourth argument, `spans`, which
  defaults to `#f`. When it is not `#f`, it is the span tree of `datum`.
  The recursive calls pass each argument's subtree.
- The two declaration sites pass it. The field loop in
  `check-class-definition!` passes `(field-declaration-type-spans field)`.
  `check-method-types!` passes `(parameter-declaration-type-spans parameter)`
  and `(method-declaration-return-type-spans method)`.
- No other call of `type-from-sexpr` passes `spans`. That includes
  `check-method-body!`, which resolves the same annotations again right
  after. So a later resolution, such as a deferred body re-checked for a
  send, never observes a type symbol.
- When `spans` is `#f`, `type-from-sexpr` does exactly what it does
  today. Whatever `spans` is, it accepts exactly the same datums and
  raises the same errors with the same text.

As `type-from-sexpr` walks the datum, it reports each symbol's `srcloc`
with a class record or with nothing, case by case:

| Where the symbol sits | Report |
|---|---|
| the whole type, or an argument that is resolved (below) | `Int`, `Float`, `Bool`, `String`, `Symbol`, `Mirror`, `Signature`: nothing. A key of `substitution` (a type parameter in scope): nothing. Otherwise its binding in `environment`: a `class-type` reports its record (`class-type-class`); a protocol or anything else reports nothing. |
| the head of a list | `->`: nothing. `List`: nothing. Otherwise the head's binding, which `type-from-sexpr` already requires to be a `class-type`: its record. |
| an argument of `->` or `List`, or of a head bound to a generic class | resolved by the first row, recursively |
| an argument of a head bound to a class with no type parameters | every `srcloc` in that argument's subtree reports nothing. The checker accepts `(Point Int)`, and even `(Point Nope)`, on a non-generic `Point` without reading the arguments. |

The order of the checks in the first row is the order `type-from-sexpr`
uses today. The kernel names come first, then the substitution, then the
environment. So a type parameter named `T` shadows a class named `T`.
You may move the kernel-name chain into a helper. Do not change which
names it lists.

### The observer

Extend the definition observer in `aloe/private/checker-observation.rkt`:

- It also records the T token's `srcloc`, or `#f` when the token is V,
  C, or M.
- A new hook, called from `type-from-sexpr`, takes a reported `srcloc`
  and a record or `#f`. It observes when all of these hold:
  - the observer waits for a T token, and the reported `srcloc` is `eq?`
    to that token's;
  - the observer has not observed yet;
  - `current-legacy-deferred-generic-instantiation?` is false.
- The C and M hooks (`observe-definition-binding!`) and the V hooks must
  not fire for a T token. A T token's owner is the same `define-class`
  or `define-methods` form those hooks look for. Without this rule, the
  C hook would observe the class being defined for every type symbol in
  its fields.
- `selected-expression-in-method-body?` still considers the observer's
  owner, for every kind.
- Every annotation is checked at its declaration, and a non-generic
  head's arguments report nothing. So once the complete file checks,
  every T token has been observed. The existing internal error for an
  unobserved owner stays.

### The answer

001's rules apply unchanged. The bridge applies the three jump rules to
the observed record and the token's symbol. The answer's location is
built from the defining path and the `name-loc`, and its `text` comes
from the load-cache entry. The bridge and `query-definition-at` gain
only what they need to carry the T token's `srcloc` to the observer.

So, for example:

- `(p P)` after `(define P Point)` resolves `P` to `Point`'s record but
  does not jump. `P` is not the class's name.
- `(spare (Option Point))` jumps from `Option` to `lib/option.aloe` and
  from `Point` to `point.aloe`.
- `Mover` in `(m Mover)` is a protocol and does not jump.

## Exact file scope

May edit:

- `aloe/type.rkt`: `type-from-sexpr` (including a kernel-name helper),
  the field loop in `check-class-definition!`, `check-method-types!`,
  the `make-checker-observation-api` call, and the
  `definition-query-observation` submodule. Nothing else in this file
  changes.
- `aloe/private/checker-observation.rkt`
- `aloe/private/definition-selection.rkt`
- `aloe/definition-query.rkt`, only to pass the T token's `srcloc` to
  the bridge
- `tests/editor/definition/002-type-symbols.rkt` (new)
- `tests/editor/definition/001-query.rkt`, only to delete the test-case
  `"type symbols are not tokens before editor-definition 002"`. Nothing
  else in that file changes.
- `docs/editor/definition/README.md` and `docs/editor/README.md`, for
  the status lines below

Do not edit:

- `aloe/parse.rkt`, `aloe/eval.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/library.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/lsp.rkt`,
  `aloe/signature-catalog.rkt`,
  `aloe/private/expression-selection.rkt`, or
  `aloe/private/completion-selection.rkt`
- any other existing test, and any fixture. This checkpoint adds no
  fixture file. Its extra cases use temporary files
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or any spec,
  charter, or checkpoint document, this one included
- `lib/`, `examples/`, `editors/vscode/`, `gel/`, or `host/`
- any error text

If an existing test other than the deleted test-case fails, or the slice
seems to need a file outside this list, stop and report it.

## Required tests

Add `tests/editor/definition/002-type-symbols.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` for
module paths and `define-runtime-path` for the fixtures and
`lib/option.aloe`. Require the public module, plus `exn:fail:aloe-type?`
from `aloe/main.rkt`. Temporary files go in a directory made under
`(find-system-path 'temp-dir)` and are removed unconditionally.

Lines are one-based, columns zero-based, and positions one-based. "Path"
means `(simplify-path (path->complete-path p) #f)`. A jump to a target
means the location's source is the target file's path, its line,
column, position, and span are the target's, and `text` is `equal?` to
`(file->string <that file>)`. All values were measured on a prototype
of this checkpoint.

| Target | File | Line | Column | Position | Span |
|---|---|---:|---:|---:|---:|
| Point | `point.aloe` | 1 | 14 | 15 | 5 |
| Box | `shapes.aloe` | 7 | 15 | 131 | 3 |
| Option | `lib/option.aloe` | 1 | 15 | 16 | 6 |

1. **Type symbols jump.** Each cursor in `shapes.aloe` is the token's
   first character:

   | Line | Col | Position | Token | Target |
   |---:|---:|---:|---|---|
   | 5 | 13 | 100 | `Point` in a protocol parameter type | Point |
   | 5 | 20 | 107 | `Point` as a protocol return type | Point |
   | 10 | 12 | 173 | `Point`, a field type | Point |
   | 11 | 12 | 192 | `Option` in `(Option Point)` | Option |
   | 11 | 19 | 199 | `Point` in `(Option Point)` | Point |
   | 13 | 14 | 233 | `Point`, a method return type | Point |
   | 18 | 24 | 333 | `Point`, a constructor payload type | Point |
   | 21 | 15 | 410 | `Point`, a method parameter type | Point |
   | 26 | 30 | 499 | `Box` in `(Box A)` in `define-methods` | Box |
   | 28 | 21 | 568 | `Point`, a return type in `define-methods` | Point |
   | 41 | 18 | 747 | `Box` in `(List (Box Point))` | Box |
   | 41 | 22 | 751 | `Point` in `(List (Box Point))` | Point |
   | 42 | 19 | 779 | `Point` in `(-> Int Point)` | Point |

   Every position from 192 to 197 (all of `Option` at line 11) gives
   the same answer, and 198 gives `#f`.

2. **Type symbols that resolve to nothing.** Each of these positions in
   `shapes.aloe` returns `#f`: 158 (`T`, a class type parameter), 495
   and 503 (`A`, a method type parameter), 561 (`Mover`, a protocol),
   646 (`T`, the target's type parameter in `define-methods`), 726 (`P`,
   an alias of `Point`), 741 (`List`), 772 (`->`), and 775 (`Int`).
   Position 38 of `point.aloe` (`Int`) also returns `#f`. 001's misses
   test already lists these positions and stays as it is. Here they
   are T tokens.

3. **Cases outside the fixtures.** Write each text to a temporary file
   and query it there. Each `"\n"` is one LF, and each text ends with
   one. A jump below names a span in the same temporary file, whose
   path is the source, and whose `text` is the file's text.

   | Text | Position | Token | Answer |
   |---|---:|---|---|
   | A | 74 | head `Pt` in `(Pt Pt)` | line 1, column 14, position 15, span 2 |
   | A | 77 | argument `Pt` in `(Pt Pt)`, a non-generic head | `#f` |
   | A | 89 | `Nope` in `(Pt Nope)`, never resolved | `#f` |
   | B | 79 | `T` in `(v T)`, the class type parameter of `(Wrap T)` | `#f` |
   | B | 125 | `T` in `(t T)`, the class `T` | line 1, column 14, position 15, span 1 |
   | B | 154 | `T` in `(x T)`, the method's `(type T)` | `#f` |
   | B | 157 | `T`, the method's return type | `#f` |
   | C | 49 | `String`, a kernel return type | `#f` |
   | D | 131 | head `Pair` of a generic class | line 1, column 15, position 16, span 4 |
   | D | 136 | `Pt`, an argument of `Pair` | line 2, column 14, position 72, span 2 |
   | D | 145 | `Pt` in `(List Pt)` inside `Pair` | line 2, column 14, position 72, span 2 |
   | E | 93 | `T` in `(List T)` in `define-methods List` | `#f` |
   | E | 110 | `Pt`, a parameter type in `define-methods List` | line 1, column 14, position 15, span 2 |
   | F | 73 | `Pt` in `(p Pt)` | line 1, column 14, position 15, span 2 |

   The texts:

   ```racket
   ;; A
   "(define-class Pt (fields (x Int)) (methods))\n(define-class Q (fields (p (Pt Pt)) (r (Pt Nope))) (methods))\n"
   ;; B
   "(define-class T (fields (n Int)) (methods))\n(define-class (Wrap T) (fields (v T)) (methods))\n(define-class Plain (fields (t T)) (methods (id (type T) (x T) T x)))\n"
   ;; C
   "(define-methods String\n  (methods\n    (shout () String self)))\n"
   ;; D
   "(define-class (Pair A B) (fields (a A) (b B)) (methods))\n(define-class Pt (fields (x Int)) (methods))\n(define-class U (fields (p (Pair Pt (List Pt)))) (methods))\n"
   ;; E
   "(define-class Pt (fields (x Int)) (methods))\n(define-methods List (methods (firsts () (List T) self) (pts (p Pt) (List Pt) (List empty))))\n"
   ;; F
   "(define-class Pt (fields (x Int)) (methods))\n(define-class Q (fields (p Pt)) (methods))\n"
   ```

   Then append `(define oops (1 + "x"))` and a LF to text F. Position 73
   now raises `exn:fail:aloe-type?` with the message
   `"typecheck: Int + expects an Int argument"`.

4. **001's placeholder is gone.** Delete the test-case
   `"type symbols are not tokens before editor-definition 002"` from
   `tests/editor/definition/001-query.rkt`. Every other test in that
   file passes unchanged. That includes its misses, its dirty buffer,
   its Option cases, and its failures.

The existing hover, completion, and LSP tests stay green without edits.
That proves `type-from-sexpr` without `spans` is unchanged.

## Scratch run

On 2026-10-15 a prototype of this checkpoint was applied to a copy of
the tree at `a727aaa`. It changed about 50 lines of `aloe/type.rkt`, 15
of `checker-observation.rkt`, 50 of `definition-selection.rkt`, and 3 of
`definition-query.rkt`. Then:

- All 26 jump cursors of `shapes.aloe` (001's 13 and the 13 above) and
  all 29 of 001's misses gave the listed answers. So did every case in
  test 3.
- The whole suite ran 3037 tests under `-j 4`. The one failure was the
  placeholder test-case in `001-query.rkt` that test 4 deletes. No file
  crashed, and no other test changed.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/definition/002-type-symbols.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

All green. The whole suite is 3037 tests, minus the deleted test-case,
plus this checkpoint's new test-cases. No fixture is added, so the
census count does not change. If only
`tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar fails under
`-j 4`, run that file alone, and it must pass there.

There is no hand check for this checkpoint. The editor shows nothing
new until the LSP layer.

Update the status lines:

- In `docs/editor/definition/README.md`, add a row for
  `checkpoints/002-type-symbols.md`: "Implemented *date*, awaiting
  review", with the focused test count and the whole-suite count.
- In `docs/editor/README.md`, set project 8's cell to say
  editor-definition 002 is implemented and awaiting review.

Stop for review without committing. Do not write or start the LSP
checkpoint.

## Explicit non-goals

- `textDocument/definition`, `definitionProvider`, or any edit to
  `aloe/lsp.rkt` or `editors/vscode/`
- Protocols as jump targets, or jumps from a binding site, a selector,
  or an alias
- Resolving the arguments of a non-generic head, or any change to what
  `type-from-sexpr` accepts or to its error text
- Observing a type symbol anywhere but its declaration (not in
  `check-method-body!`, conformance, sends, or `case` payloads)
- Spans on header type parameters, a method's `(type ...)` names, or a
  class's protocol slot
- A change to hover, completion, `expression-query-result`, or
  `aloe/expression-query.rkt`
- Any change to `aloe/parse.rkt` or to how positions are counted
