# Editor source locations 000 — Expression spans

**Status.** Ready to implement.

## Goal

Expressions produced by `read-program` carry the source locations already
reported by Racket's reader. Ordinary send nodes also retain the source
location of their selector token. `parse-datum` remains the location-free
entry point used by the REPL and existing tests.

This checkpoint only stores locations and proves them in tests. It does not
display locations in errors and does not expose an editor query.

The implementer receives only this document. Every rule for this slice is
below.

## Authority and starting point

- `SPEC.md` section 1 says that Aloe uses the Scheme/Racket reader.
  `read-syntax` is that reader with source information; do not introduce a
  second grammar or a character scanner.
- `docs/philosophy.md` motivates later editor questions. This checkpoint only
  preserves the spans those questions will consume.
- `aloe/parse.rkt` currently defines all expression structures, parses datums,
  and implements `read-program` with `read` followed by `parse-datum`.
- `docs/editor/README.md` keeps source locations separate from the later
  signatures, expression-query, and LSP projects.

Identity is `(editor-source-locations, 000)`, spoken **editor-source-locations
000**. This is a local editor checkpoint, not global checkpoint 118. Do not
edit `CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Locked representation

Add a final `loc` field to every `*-expr` structure in `aloe/parse.rkt`:

- `int-expr`, `float-expr`, `bool-expr`, `string-expr`, and `variable-expr`
- `load-expr`, `check-expr`, and `define-expr`
- `define-protocol-expr`, `define-class-expr`, and `define-methods-expr`
- `fn-expr`, `case-expr`, and `send-expr`

Each `loc` is either `#f` or a Racket `srcloc`. After its `loc` field,
`send-expr` has one additional final field, `selector-loc`, which is `#f` or
the `srcloc` of the selector identifier in source. Thus `send-expr` ends in:

```text
... arguments loc selector-loc
```

Do not use a wrapper node, side table, parallel syntax tree, structure
property, or new selector-expression type.

Do not add locations to `field-declaration`, `parameter-declaration`,
`constructor-declaration`, `method-declaration`, or `case-clause`. A method or
case-clause body is already an expression and carries its own location.

Export one function:

```racket
(expression-loc expression) ; -> (or/c srcloc? #f)
```

It returns the `loc` field of any Aloe `*-expr`. Continue exporting the
structures normally, which provides `send-expr-selector-loc`; tests use that
accessor for selector tokens.

## Datum compatibility

`parse-datum` remains public and keeps accepting the same datums with the same
Aloe meaning. Every `loc` and `selector-loc` anywhere in a tree produced by
`parse-datum` is `#f`. `parse-program`, which accepts datums, remains
location-free for the same reason.

Two independently produced `parse-datum` trees for the same datum must still
compare equal with `equal?`. Existing direct structure constructions and
matches may receive only the mechanical new `#f` fields needed for their
arity; do not redesign those callers.

## Syntax-aware reading

Change `read-program` to read each top-level form with `read-syntax`, not
`read`, and call `port-count-lines!` on the input port before reading so line
and column are populated. Preserve both supported input shapes: a string and
an input port.

When `#:source-path` is provided, pass that path as the source name used by
`read-syntax`. The resulting `srcloc-source` values must be that path, and the
existing source-directory behavior for `(load "...")` must continue to
resolve relative loads from that path's directory. Without `#:source-path`,
the source may be `#f`, but line, column, position, and span must still be
present.

Add a private syntax-aware parsing path for `read-program`. Walk the nested
syntax objects so each expression receives the `srcloc` for its own source
form. Do not call `syntax->datum` on a whole top-level form and then hand that
tree to `parse-datum`, because that discards all nested spans. Converting
individual non-expression pieces to their existing datum representation is
fine; declarations and raw datums such as the two stored `check` operands do
not become a parallel syntax tree.

The syntax-aware path must recognize exactly the grammar that `parse-datum`
recognizes. It must retain current send semantics: the first list element is
the receiver, the second is a literal selector, and only the receiver and
arguments are recursively parsed as expressions. Do not add a special form,
macro system, recovery parser, or alternate reader.

For an ordinary source send:

- the send's `loc` is the `srcloc` of the whole list;
- the receiver and each argument keep their own syntax-object locations;
- `selector-loc` is the `srcloc` of the source selector identifier.

All other directly represented expressions use the location of their whole
source form. Nested expression fields, especially definition values, method
bodies, function bodies, case scrutinees, clause bodies, and `else` bodies,
keep their own locations.

## Sugar mapping

`let`, `if`, and `cond` remain parser desugarings with exactly their current
meaning:

- Every recursively parsed source subexpression keeps its own `srcloc`.
- Every `fn-expr` or `send-expr` introduced by desugaring uses the whole sugar
  form's `srcloc` as its `loc`.
- A selector synthesized by desugaring has no selector token in the source,
  so its `selector-loc` is `#f`.

In particular, `let` still becomes an introduced function sent literal
`call`; `if` still becomes the existing Bool `if` send; and each nested send
and function introduced for `cond` uses the outer `cond` form's location.
Do not change the desugared expression shape or implement macros.

## Match and constructor migration

Update `aloe/type.rkt`, `aloe/eval.rkt`, and every other Racket match or direct
constructor affected by the extra structure fields. In this checkpoint,
consumers that do not use locations should match those fields with `_`.

This migration is mechanical only. Type checking, evaluation, reflection,
printing, loads, and error behavior remain the same. Do not change any
`typecheck:` or `eval-aloe:` error text and do not prefix errors with a path,
line, or column. Location-bearing type errors belong to source-locations 001,
which is not part of this checkpoint.

## Exact file scope

Implementation may edit:

- `aloe/parse.rkt`
- `aloe/type.rkt` and `aloe/eval.rkt`
- another existing Racket source or test only for a mechanical `*-expr`
  constructor or match-arity update
- `tests/editor/source-locations/000-spans.rkt` (new)
- fixtures under `tests/editor/source-locations/fixtures/` (new)

Do not edit:

- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- `gel/`, `lib/`, `host/`, or `docs/gel/`
- type-error or runtime-error formats
- the editor project charters or any later source-locations checkpoint
- a new public language-service, signatures, expression-query, or LSP module

If preserving spans through current sugar requires a different representation,
if match migration suggests a structure-property redesign, or if parse-error
locations become necessary, stop and return the checkpoint for design review.

## Fixture and required tests

Add an ASCII fixture at
`tests/editor/source-locations/fixtures/000-spans.aloe` with exactly these
bytes, including one LF after each line:

```aloe
42
((Point new 1 2) + p)
(let ((x 1)) (x + 2))
```

Load it through an input port with `read-program` and pass its runtime path as
`#:source-path`. Assert `srcloc?` before inspecting fields, and prove at least
the following locations. Columns are zero-based; positions are one-based.

| Expression/token | line | column | position | span |
|---|---:|---:|---:|---:|
| top-level `42` | 1 | 0 | 1 | 2 |
| outer `((Point new 1 2) + p)` send | 2 | 0 | 4 | 21 |
| inner `(Point new 1 2)` send | 2 | 1 | 5 | 15 |
| inner selector `new` | 2 | 8 | 12 | 3 |
| argument `1` | 2 | 12 | 16 | 1 |
| argument `2` | 2 | 14 | 18 | 1 |
| outer selector `+` | 2 | 17 | 21 | 1 |
| argument `p` | 2 | 19 | 23 | 1 |
| whole `let` / introduced `call` send | 3 | 0 | 26 | 21 |
| `let` body `(x + 2)` | 3 | 13 | 39 | 7 |

For every fixture location above, also check that `srcloc-source` equals the
fixture path. For the `let`, check separately that:

- the introduced outer `send-expr` and introduced `fn-expr` both have the
  whole `let` location;
- the introduced send's selector is literal `call` and its `selector-loc` is
  `#f`;
- the parsed body send has its own line 3, column 13, position 39, span 7
  location rather than the `let` location;
- the body's `+` selector and source arguments have their own token spans.

Parse the send and `let` fixture forms as ordinary datums through
`parse-datum`. Walk their expression nodes and prove every `expression-loc`
and `send-expr-selector-loc` is `#f`. Also assert that two parses of the same
datum are `equal?`.

Call `read-program` on a string without `#:source-path` and prove its root and
nested expressions still have `srcloc` values with line, column, position,
and span. Its source is allowed to be `#f`.

The test file is three directories below the repository root. Use
`../../../aloe/...` for `require` paths and for any `define-runtime-path` that
targets a repository-root file; a fixture beside the test may use
`fixtures/000-spans.aloe`.

Existing global tests must remain green, including real file loading and all
current parser, checker, evaluator, and error-string expectations.

## Acceptance

Run exactly the local test and then the recursive suite:

```sh
raco test tests/editor/source-locations/000-spans.rkt
raco test tests
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when syntax-read expressions carry the specified
locations, datum-parsed expressions remain location-free, real source files
still load, and the recursive suite is green. Stop for review without
committing. Do not write or implement source-locations 001.

## Explicit non-goals

- Path/line/column prefixes on type or runtime errors
- `messages-at`, signatures of a type, hover, completion, or expression query
- LSP, JSON-RPC, VS Code, or another editor client
- Incomplete-buffer recovery, incremental parsing, or comment nodes
- UTF-16/LSP position conversion
- A new parser, `#lang aloe`, macros, or a change to sugar meaning
