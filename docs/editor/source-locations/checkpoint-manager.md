# Checkpoint manager — Editor source locations

**Status.** Assignment for a **checkpoint-manager conversation**.
Not Aloe law. Not a checkpoint. Not an implementer assignment.
Index: [`README.md`](README.md). Parent map:
[`docs/editor/README.md`](../README.md).

**Your job.** Write **editor-source-locations 000 only**: expressions
produced from `read-program` carry Racket `srcloc`; `parse-datum`
still works and those locations are `#f`. Then **stop**. Do not
implement. Do not change type-error or runtime-error strings. Do not
write 001. Do not write LSP, signatures-of-type, or expression-query.
Do not write global checkpoint 118.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this file and the authority in §3.
2. Write `docs/editor/source-locations/checkpoints/000-spans.md`
   (slug may be `spans` or a tighter word).
3. Stop. The human reviews it.

The implementer will not have this file. Put every rule they need in
the checkpoint itself.

Keep the checkpoint **small**. A language server, a new parser, or
rewriting `parse-datum` into a character scanner is a defect.

## 2. Why this slice exists

Editor completion is "byte offset in this buffer." Today's reader
calls Racket `read`, then `parse-datum`. Datums have no source,
line, column, or span. The AST cannot answer "which expression is
here?"

Racket already has the locations. `read-syntax` is the same
Scheme/Racket reader the spec names; it returns syntax objects with
`srcloc` on every nested form. This project keeps those spans on
Aloe expression nodes.

000's consumer is tests that inspect locations. User-facing
`path:line:column` on type errors is **001**, issued only after 000
is green. Do not combine those. Do not leave `read-program` unable
to load a real file.

## 3. Authority

- `SPEC.md` §1 — the reader is the Scheme/Racket reader. `read-syntax`
  is that reader. Do not write a second grammar. Do not amend `SPEC.md`
  in 000.
- `docs/philosophy.md` — editor questions are why send plus types
  exist. This slice does not answer them yet; it stores the spans
  those questions will use.
- `aloe/parse.rkt` — `read-program`, `parse-datum`, expression structs
- `docs/editor/README.md` — later projects are other folders

If macros, incomplete buffers, or LSP want to change this slice,
**stop** and send the human back to the brainstorm. Do not invent
them here.

## 4. Project locks (put these in 000)

These are law for the whole source-locations series, not just 000.
The implementer must not choose a different representation.

### 4.1 Where locations live

Every `*-expr` struct in `aloe/parse.rkt` gains a last field `loc`.
Its value is `#f` or a Racket `srcloc`.

`send-expr` also gains `selector-loc` after `loc`: `#f` or the
`srcloc` of the selector identifier. Completion will sit on that
token. Do not encode the selector as a new expression type.

Do not use a side table, a wrapper node, or a parallel syntax tree.
Do not put `loc` on `field-declaration`, `parameter-declaration`,
`constructor-declaration`, `method-declaration`, or `case-clause`.
Method **bodies** are expressions and already have `loc`.

`parse-datum` still exists. Every `loc` and `selector-loc` it
produces is `#f`. REPL and tests that parse datums stay valid.
`equal?` of two `parse-datum` trees must keep working.

### 4.2 How they are filled

`read-program` reads with `read-syntax`, not `read`. Call
`port-count-lines!` so line and column exist. When
`#:source-path` is present, that path is the syntax source.

Walk syntax objects. Do not `syntax->datum` on a whole form and then
`parse-datum` — that drops inner spans.

Sugar (`let`, `if`, `cond`) stays desugaring in the parser:

- Recursively parsed subexpressions keep their own `loc`.
- Nodes the desugarer **introduces** (`fn-expr` / `send-expr` for
  `let` / `if` / `cond`) use the **sugar form's** `srcloc`.

That is the mapping a later expander must preserve. Do not implement
macros.

### 4.3 Matches and accessors

`aloe/type.rkt` and `aloe/eval.rkt` (and any other `match` on these
structs) must accept the new fields. Prefer `_` for `loc` in 000.
Export `expression-loc` (and `send-expr-selector-loc`, which the
struct already provides) so tests do not reach through undocumented
layout.

Existing global tests must stay green. They use predicates and
accessors more than full struct equality; do not break that. Do not
change type-error or `eval-aloe` message text in 000.

### 4.4 What 000 must prove

A fixture file with known contents, loaded through `read-program`
with `#:source-path`:

- A top-level atom has a `srcloc` whose source is that path, with
  line / column / position / span matching the atom.
- In `((Point new 1 2) + p)`, the outer send's `selector-loc` covers
  `+`, the inner send's `selector-loc` covers `new`, and `1` / `2` /
  `p` have their own spans.
- A `let` body's inner expression has the body's span, not the
  `let`'s span. The introduced `call` send's `loc` is the `let`
  form.

The same program as a datum through `parse-datum` has `#f` locations.

`read-program` on a string (no path) still produces `srcloc` values
with line and column; source may be `#f`.

## 5. Where files go (local series)

Identity is `(editor-source-locations, 000)`, not the next global
integer.

| | Path |
|---|---|
| Checkpoint | `docs/editor/source-locations/checkpoints/000-spans.md` |
| Test (implementer writes) | `tests/editor/source-locations/000-spans.rkt` |
| Fixture if needed | `tests/editor/source-locations/fixtures/` |

Spoken name: **editor-source-locations 000**. Zero-pad to three
digits. Do **not** write `docs/checkpoints/0118-….md` or
`tests/checkpoint-118.rkt`. Do not append to root `CHECKPOINTS.md`.
Do not put files under `docs/gel/`.

Tests sit deeper than the global suite. The checkpoint must tell the
implementer to use extra `../` in `require` and
`define-runtime-path` (`../../../aloe/…` from
`tests/editor/source-locations/`).

**How to run tests** (write these commands into the checkpoint):

```sh
raco test tests/editor/source-locations/000-spans.rkt
raco test tests
```

Do **not** tell the implementer to run `raco test tests/*.rkt`; that
glob skips this folder.

After the slice file exists, list it in [`README.md`](README.md).

## 6. File scope for 000

May edit:

- `aloe/parse.rkt` (structs, `read-program`, parse from syntax)
- `aloe/type.rkt`, `aloe/eval.rkt`, and any other Racket file that
  `match`es or constructs `*-expr` structs (mechanical field only)
- new tests and fixtures under `tests/editor/source-locations/`

Must not edit:

- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`
- `gel/`, `lib/`, `host/`, `docs/gel/`
- type-error format, runtime error format
- a new public "language service" module

## 7. Non-goals for 000

- Reporting `path:line:column` in errors (001)
- `messages-at`, signatures-of-type, hover, completion
- LSP, JSON-RPC, VS Code
- Unclosed buffers, error recovery, incremental parse
- UTF-16 / LSP position encoding
- Comment nodes
- Changing `let` / `if` / `cond` desugar **meaning**
- `#lang aloe`, macros

## 8. After 000 (do not write these files now)

001 is expected: when `loc` is a `srcloc` with source, line, and
column, type errors are

```text
path:line:column: typecheck: …
```

When `loc` is `#f`, today's `typecheck: …` string stays. That is
the first user-facing consumer. Issue 001 only after 000 is green
and the human asks. Runtime errors with location are not 000 and
not automatic 001.

## 9. Design issues leave this conversation

If any of these happen, do not invent a new design here:

- `read-syntax` cannot preserve spans through today's sugar
- a match-update blast radius that wants a struct-property redesign
- parse errors needing locations in 000
- project 2, 3, or 4 (signatures, expression query, LSP) leaking in

Tell the human to take it back to the brainstorm. Do not nest
unrelated work under `docs/editor/source-locations/`.
