# Editor expression query 000 — Expression selection

**Status.** Implemented and reviewed. The focused 82-assertion suite and exact
hand check are green. The recursive suite passes 1,855 of 1,857 tests; its
only failures are the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` wording contradictions. This
checkpoint introduces no additional failure.

## Goal

Add the internal, read-only operation that selects the expression owning a
one-based source position from the location-bearing expression trees returned
by `read-program`.

This checkpoint implements only tree traversal and the specification's
containment and tie rules. It does not open a file, typecheck or evaluate a
program, inspect signatures, or add the public `query-expression-at`
operation.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. In particular, the head of a list is
  the receiver and the second element is a literal selector; this checkpoint
  must not reinterpret either as function application.
- `docs/editor/expression-query/spec.md` is the local design authority.
  Sections 1–3 define positions, expression ownership, traversal, and
  location-less trees.
- Editor-source-locations 000 is implemented. `read-program` returns the
  existing `*-expr` structures with Racket `srcloc` values, while
  `parse-datum` and `parse-program` return the same structures with `#f`
  locations.
- Editor-signatures-of-type 000–002 are implemented, but this checkpoint does
  not call `type-signature-specs` or edit its catalog.
- `aloe/parse.rkt` owns the expression structures and the public
  `expression-loc` accessor. This checkpoint consumes those structures; it
  does not change the parser or their representation.

Identity is `(editor-expression-query, 000)`, spoken
**editor-expression-query 000**. This is a local editor checkpoint, not a
global checkpoint and not part of either predecessor series. Do not edit
`CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Internal selection operation

Add `aloe/private/expression-selection.rkt` with this exact internal export:

```racket
(select-expression-at-position expressions position)
  ; expressions : (listof Aloe-expression)
  ; position    : exact-positive-integer?
  ; -> (or/c Aloe-expression #f)
```

The operation accepts the already parsed root expressions in source order.
It returns the exact expression object present in that tree, not a copy,
wrapper, datum, syntax object, or reconstructed equivalent. Object identity
is required because a later checker-observation slice will recognize this
same node while checking its enclosing program.

The operation is an internal substrate for the eventual
`aloe/expression-query.rkt`. Its arguments are a caller precondition in this
slice; do not create a second public validation contract. The final public
operation will validate its path and position with `query-expression-at` as
the reported `who`.

Do not add `aloe/expression-query.rkt`, `expression-query-result`, or
`query-expression-at` in this checkpoint. Do not re-export the internal
selector from `aloe/main.rkt`, `aloe/driver.rkt`, or another public module.

## Containment and winner

An expression whose `srcloc` starts at one-based position `s` and has span
`n` contains `position` `p` exactly when:

```text
s <= p < s + n
```

The start is inclusive and the end is exclusive. Use `srcloc-position` and
`srcloc-span` directly. This layer performs no byte, line/column, UTF-16, or
editor-offset conversion.

Among all containing expression nodes, return the node with the smallest
span. For equal spans, retain the first candidate in preorder, which is the
outermost node in the parsed expression tree. Concretely:

1. Visit root expressions in source order.
2. Consider a node before visiting any of its children.
3. Replace the current winner only for a strictly smaller span.
4. Never replace it merely for an equal span.

This equal-span rule is observable for parser sugar. The `send-expr`
introduced for a source `let` and its introduced receiver `fn-expr` share the
whole `let` location. A position on `let` therefore selects the outer send,
whose literal selector is `call`, rather than the synthetic function.

An expression with `expression-loc` equal to `#f` is not a candidate. Do not
guess a location from a parent, child, sibling, selector, datum, or traversal
order. Continue traversing its expression children, if any, but never select
the location-less node itself. If every node is location-less, return `#f`.

## Exact expression traversal

Traverse only expression-valued fields and in this order:

- `int-expr`, `float-expr`, `bool-expr`, `string-expr`, `variable-expr`,
  `load-expr`, and `define-protocol-expr` have no expression children;
- `check-expr` visits its left expression, then its right expression;
- `define-expr` visits its value;
- `define-class-expr` visits each method body in method declaration order;
- `define-methods-expr` visits each method body in method declaration order;
- `fn-expr` visits its body;
- `case-expr` visits its scrutinee, each named clause body in clause order,
  then its optional `else` body; and
- `send-expr` visits its receiver, then each argument in source order.

The node itself is considered before the children listed above. Do not treat
any of these as expression nodes:

- a send's literal selector or `selector-loc`;
- protocol signatures;
- class type parameters or protocol name;
- field or constructor declarations;
- method selectors, type parameters, parameter declarations, or return
  annotations;
- function parameter names;
- case constructor selectors or payload names; or
- the plain source datums retained by `check-expr`.

For positions on such syntax, the smallest enclosing expression remains the
candidate. For example, a send selector selects the send, a function
parameter name selects the function, a case payload name selects the case,
and declaration syntax outside a method body selects the enclosing
declaration expression.

A `load-expr` is a leaf. This operation receives only the named root file's
parsed expressions and must not open, parse, append, or traverse a loaded
file.

## Consequences to preserve

The implementation must follow directly from containment and traversal:

- A position on an atom selects that atom.
- A position on the opening or closing parenthesis of a nested form selects
  that nested expression when its span is smaller than its parent's.
- Whitespace or a comment inside a list selects the smallest enclosing
  expression when no child expression covers it.
- A position on a send selector selects the whole send.
- Whitespace or a comment between top-level expressions, the newline after a
  complete top-level form, and a position one character beyond end of file
  select nothing.
- Parser-introduced `let`, `if`, and `cond` nodes participate exactly like
  all other nodes; no source form is reconstructed and no sugar meaning is
  changed.

Do not use textual token scanning or `selector-loc` to special-case these
results. They arise from the existing expression `srcloc` values and the
tree walk.

## Exact file scope

Implementation may add only:

- `aloe/private/expression-selection.rkt`
- `tests/editor/expression-query/000-selection.rkt`
- `tests/editor/expression-query/fixtures/point.aloe`

Do not edit:

- `aloe/parse.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/driver.rkt`, or
  `aloe/main.rkt`
- `aloe/signature-catalog.rkt` or either predecessor project
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- the expression-query specification, charter, README, this checkpoint's
  semantics, or a later checkpoint document
- `gel/`, `lib/`, `host/`, or another editor project

If the existing AST accessors are insufficient for this traversal, if
selection appears to require a parser change or side table, or if object
identity cannot be preserved, stop and return the checkpoint for design
review.

## Normative Point fixture

Add `tests/editor/expression-query/fixtures/point.aloe` with exactly these
ASCII bytes and one LF after every shown line:

```aloe
(define-class (Point T)
  (fields
    (x T)
    (y T))
  (methods
    (+ (other (Point T)) (Point T)
      self)
    (dist2 (other (Point T)) T
      (self x))))
(Point new 1 2)
```

Read the fixture through `read-program`, passing its runtime path as
`#:source-path`, then use the internal selector on the returned roots. Pin at
least these results:

- Position 170, the `n` in the final literal `new` selector, selects the final
  `send-expr`, whose location is line 10, column 0, position 163, span 15.
- Positions 163 and 177, the final send's opening and closing parentheses,
  also select that send.
- Position 169, whitespace between `Point` and `new`, selects that send.
- Position 174 selects the literal `1` atom rather than the enclosing send.
- Position 108 selects the `self` variable in the generic `+` method body.
- Position 157, the selector `x` in `(self x)`, selects that inner send, whose
  location starts at position 151 with span 8.
- Position 40, declaration syntax in field `(x T)`, selects the enclosing
  `define-class-expr`; the field declaration is not an expression candidate.
- Position 178, the LF after the final form, and position 179, one character
  beyond end of file, return `#f`.

For returned children, assert `eq?` with the node reached through the parsed
root's existing accessors. Do not settle for structural `equal?`; the helper
must return the original object.

## Additional required tests

Add `tests/editor/expression-query/000-selection.rkt`. It is three directories
below the repository root, so use `../../../aloe/...` in `require` and
`define-runtime-path` paths.

In addition to the Point fixture, cover at least:

1. For `((1 + 2) * 3)`, an inner atom, the inner send's selector, opening
   parenthesis, and whitespace select the appropriate atom or inner send;
   the outer selector, closing parenthesis, and uncovered inner whitespace
   select the outer send as dictated by the spans.
2. A top-level comment and whitespace between two forms select nothing,
   while a comment inside a list selects that list's send.
3. A source `let` proves the equal-span rule: the introduced outer
   `send-expr` and receiver `fn-expr` share the whole form's location, and a
   position on `let` returns the outer send. Its binding value and body
   expressions still win at positions inside their smaller spans.
4. Source forms exercise every traversal edge listed above: `check` left and
   right, a `define` value, class and `define-methods` method bodies, a
   function body, a case scrutinee, every named clause body, an optional
   `else` body, and send receiver and arguments. Positions on their
   non-expression declaration or binder syntax select the enclosing
   expression instead.
5. Atom roots, `load`, and `define-protocol` behave as leaves. Testing a
   `load` must not require the named file to exist, because selection never
   performs the load.
6. A complex tree produced by `parse-datum` or `parse-program` returns `#f`
   for every tested positive position. No location is synthesized and the
   tree is not rewritten.
7. A position outside every root returns `#f`, including the exact end
   boundary `s + n` of a root expression.

Tests may derive positions of nested children from their asserted `srcloc`
values, but they must use literal positions for the normative Point cases and
for at least one top-level gap. Test returned structure kinds and object
identity, not printed representations.

This checkpoint has no type, signature, environment, load-processing,
evaluation, filesystem-validation, or public-result assertion.

## Hand check and acceptance

After the automated tests, run this from a Racket REPL at the repository
root:

```racket
(require "aloe/parse.rkt"
         "aloe/private/expression-selection.rkt")

(define roots (read-program "(1 + 2)"))
(define selected (select-expression-at-position roots 4))
(list (send-expr-selector selected)
      (srcloc-position (expression-loc selected))
      (srcloc-span (expression-loc selected)))
```

Position 4 is the literal `+` selector, so the exact result is:

```racket
'(+ 1 7)
```

Run:

```sh
raco test tests/editor/expression-query/000-selection.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when selection returns the exact innermost source
node under the locked tie rule, location-less trees and top-level gaps return
`#f`, the hand check succeeds, and both test commands are green. Stop for
review without committing. Do not begin the public query or checker
observation work.

## Explicit non-goals

- No `query-expression-at` or `expression-query-result`
- No source-path normalization, file opening, argument validation, or public
  module boundary
- No checker observation, `type-of`, `typecheck-program`, type materializing,
  or `type-signature-specs`
- No fresh default environment or List/String bootstrap
- No processing of `load`, protocol conformance, or complete-file failure
  policy
- No evaluation, runtime environment, host injection, or host implementation
  call
- No selector as an expression and no second parser or text scanner
- No incomplete-buffer recovery, selector holes, incremental parsing, CLI,
  LSP, JSON-RPC, VS Code, completion, or hover
- No Aloe syntax, special form, macro, mutation, inheritance, coercion, or
  dispatch change
- No Gel or Boids work
