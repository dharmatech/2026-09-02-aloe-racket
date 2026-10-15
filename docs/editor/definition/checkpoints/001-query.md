# Editor definition 001 — Query for variables, class names, and targets

**Status.** Implemented 2026-10-15. Manager-reviewed 2026-10-15 against
this document: conforming. Accepted by the human 2026-10-15. Test 8 was
amended after implementation. It asked for `read-program`'s message,
but the test may require only the public module, so the message is now
written out.

## Goal

Add the public Racket query `query-definition-at`. Given a source file
and a position, it answers where the class named there is defined, or
`#f`. In this checkpoint it answers for three kinds of name token:

- **V**, a variable in an expression, such as `Point` in
  `(Point new 0 0)`;
- **C**, the class name in a `define-class` header;
- **M**, the target of a `define-methods` form.

The fourth kind, **T** (a symbol inside a type annotation), is
editor-definition 002. Until then a type symbol is no token, and the
query answers `#f` there. No LSP method is added in this checkpoint.

The implementer receives only this document. Every rule for this slice
is below.

## Depends on, identity

Identity is `(editor-definition, 001)`, spoken **editor-definition
001**. It is a local editor checkpoint. Do not edit `CHECKPOINTS.md` or
add a file under `docs/checkpoints/`.

The tree at `87c0844` (branch `experiment/2026-10-14-definition`) has
every predecessor:

- **Editor-definition 000.** `read-program` records `name-loc` (last
  field of `define-class-expr`) and `target-loc` (last field of
  `define-methods-expr`), the `srcloc`s of the class-name symbol and the
  target symbol. `class-info` in `aloe/type.rkt` ends in `name-loc`,
  copied from the form. It is `#f` for a class built from `parse-datum`.
  `class-info-defining-path` is the resolved path of the file that
  defined the class.
- **Editor-expression-query 000–003.** `aloe/expression-query.rkt` is
  the model this query copies. It checks its argument types, reads the
  file once, selects a node, and checks the buffer once with an observer
  active. It does this through the `query-base` submodule of
  `aloe/main.rkt`. The observer lives in
  `aloe/private/checker-observation.rkt`. `aloe/type.rkt` calls its
  hooks: `retain-expression-observation!` after each successful
  inference in `infer-expression`,
  `materialize-expression-observation-at-root-end!` after each root
  form in `typecheck-program`, and `selected-expression-in-method-body?`
  in `check-method-definition!`.
- **Modules layer 4.** Each base has a load cache from resolved path to
  `checker-load-entry`. Each entry holds the source bytes that were
  checked. The queried buffer's own entry is in the `running` state
  while it is checked, and it already holds its bytes. The four base
  libraries have seed entries. Their bytes are the ones
  `aloe/library.rkt` read when its promise was first forced.

## Authority

- `SPEC.md` is law and is not amended.
- [`docs/editor/definition/spec.md`](../spec.md) §4 is the design of
  this layer, and §6 and §7 give its cursors and coverage. Spec §2
  allows splitting the query layer: V, C, and M first, then T. This
  checkpoint is that first part. Every rule you need from the spec is
  restated below.
- The expression query's rules for reading, identity, deferred method
  bodies, and failure apply unchanged, with `who` set to
  `query-definition-at`. They are restated below.

## Required behavior

### Public function

A new module, `aloe/definition-query.rkt`, provides exactly:

```racket
(struct definition-query-result (location text) #:transparent)

(query-definition-at source-path position
                     #:document-path [document-path source-path])
  ; source-path   : path-string?
  ; position      : exact-positive-integer?
  ; document-path : path-string?
  ; -> (or/c definition-query-result? #f)
```

`position` is the coordinate `query-expression-at` uses: a one-based
character position, as `srcloc-position` counts it. A result is a jump.
`#f` is no jump. A position that does not jump is not an error.

### Reading and identity

Do exactly what `query-expression-at` does, in the same order:

1. Check the arguments: `source-path` is `path-string?`, `position` is
   `exact-positive-integer?`, `document-path` is `path-string?`. A
   failure is `raise-argument-error` with `who`
   `'query-definition-at`.
2. Normalize the source path with
   `(simplify-path (path->complete-path source-path) #f)`. If it does not
   name a regular file, raise
   `(raise-arguments-error 'query-definition-at "source path does not name a regular file" "source path" normalized-path)`.
3. Read its bytes once, and parse them with `read-program` from a bytes
   port with that normalized path as `#:source-path`. Loads then resolve
   from the source path's directory and are read from disk.
4. Find the token at the position (below).
5. Check the buffer once, with the observer active. When
   `(base-library-path document-path)` is a path, use
   `typecheck-base-library-buffer`. Otherwise use
   `typecheck-file-module-buffer` with `document-path`. Both come from
   `(submod "main.rkt" query-base)`, which you do not edit. The document
   path is the buffer's identity. The file you read may be a temporary
   sibling of it.

### Name tokens

Walk every expression node that `expression-children` in
`aloe/private/expression-selection.rkt` reaches from the root
expressions. That function is private today. Export it, and make no
other change to that module. Collect these tokens:

| Kind | Token | Where | Symbol |
|---|---|---|---|
| V | `variable-expr`'s `loc` | every `variable-expr` | its name |
| C | `name-loc` | every `define-class-expr` | the class name |
| M | `target-loc` | every `define-methods-expr` | the target |

A token whose `srcloc` starts at `s` with span `n` answers position `p`
when `s <= p < s + n`. That is the expression query's containment.
Tokens are symbols and never overlap, so at most one answers. A token
records its owner (the node above), its symbol, and its `srcloc`. Put
the token finding in a new private module,
`aloe/private/definition-selection.rkt`.

When no token answers, there is no owner. The buffer is still checked,
and the answer is `#f` after the check succeeds. This covers selectors,
constructor selectors, `new*`, `with`, binding sites, case payload names,
header type parameters, protocol slots, `define-protocol` names,
parentheses, whitespace, comments, strings, numbers, `load` paths, and,
until 002, every symbol of a type annotation.

### Resolving a token

The token resolves to a class record (a `class-info`) or to nothing, in
the one checker pass that checks the buffer. Do not run a second pass,
and do not replay a send.

- **V.** Retain the variable's type at each successful inference, in
  its real context, where `retain-expression-observation!` runs. At the
  end of the enclosing root form, where
  `materialize-expression-observation-at-root-end!` runs and at the same
  root depth, resolve that type with `resolve-type`. A `class-type`
  names its record (`class-type-class`). Anything else is nothing. This
  is the type hover reports. Resolving at the root end matters:
  `((fn (Point) (Point new 1 2)) call Point)` gives the body's `Point` a
  type variable that resolves to `Point`'s class only after the `call`
  argument is checked.
- **C.** The record `check-class-definition!` built for that form.
  Observe it in the `define-class-expr` arm of `infer-expression`, after
  the record is built and bound. The record observed must be `eq?` to
  the one built.
- **M.** The binding of the target symbol in the environment the
  `define-methods` form is checked in. This is the binding
  `check-method-definitions!` reads. A `class-type` names its record.
  Anything else is nothing, including the `List`, `String`, and `Int`
  class objects. Observe it in the `define-methods-expr` arm of
  `infer-expression`.

### When a resolved class jumps

A token whose record is `c` jumps when all of these hold:

1. The token's symbol is `eq?` to `c`'s name. An alias fails here.
   After `(define P Point)`, `P` resolves to `Point`'s record, but `P`
   is not its name. A local that reuses the class's own name passes. In
   `((fn (Point) (Point new 1 2)) call Point)`, the body's `Point`
   jumps.
2. `c` has a defining path.
3. `c` has a `name-loc`.

Otherwise the answer is `#f`. A C token always meets rule 1.

### The answer

For a jump to record `c`:

- `location` is a new `srcloc`. Its source is `c`'s defining path, and
  its line, column, position, and span are those of `c`'s `name-loc`.
  Never use the `name-loc`'s own source. For a queried buffer it is the
  file that was read, which may be the LSP's temporary sibling. For the
  base's `Option` it is the unsimplified path `aloe/library.rkt` read.
- `text` is the source bytes of the load-cache entry under `c`'s defining
  path, in the query's base, decoded by `bytes->string/utf-8` with
  U+FFFD as the error character (`(integer->char #xFFFD)`). Those are
  the bytes `c`'s `define-class` was parsed from:

| Class | Defining path | `text` |
|---|---|---|
| defined by the queried buffer | the identity path | the buffer, as read from the source path |
| defined by a nested load | that file's resolved path | the bytes read for that load |
| the base's `Option`, used from another file | `lib/option.aloe` | the seed's bytes |
| defined by a queried base-library buffer | the identity path | the buffer |

Read the entry once the complete file has checked, inside the same
query. The queried buffer's entry is `running` at that point and holds
the buffer's bytes. Every jump's defining path has an entry. If one is
missing, raise an internal error. Do not add a fallback.

### One pass, deferred bodies, and failure

- Add a **definition observer** to
  `aloe/private/checker-observation.rkt`, in its own parameter, beside
  the expression observer. It records the owner it waits for, the root
  depth, the retained V type, and whether it has observed the owner,
  with the record or nothing.
- Ignore every observation made while
  `current-legacy-deferred-generic-instantiation?` is true. Those
  observations come from re-checking a deferred body for a concrete send.
  Also ignore observations once the owner has been observed.
- A legacy generic class with a `fields` section, such as `(Box T)`,
  defers its method bodies. `selected-expression-in-method-body?` must
  also consider the definition observer's owner. When a deferred
  method body contains the owner, that body is checked at its
  declaration, as the expression query already does for a selected
  expression. With no definition observer active, the function answers
  exactly as today, for hover and for completion. The V cursor in
  `Box`'s `fresh` body (shapes.aloe line 14) depends on this. Without
  it, the body is never checked and the owner is never observed.
- The answer is built only after the complete file has checked,
  including protocol conformance.
- If the complete file checks but an owner was never observed, raise an
  internal error, as `typecheck-program/observe` does for a selected
  expression.
- Failures, as `query-expression-at`:
  - argument errors are as in step 1;
  - a missing source file raises as in step 2;
  - reader and parser failures raise with their existing text;
  - Aloe checker failures raise `exn:fail:aloe-type?` with their
    existing text. A type error anywhere in the file raises, including
    at a cursor that would otherwise jump. A later error suppresses an
    earlier observation;
  - a valid position that does not jump returns `#f` after the
    complete file checks.
- Repeated calls are independent. A query keeps no classes, bindings,
  or load state for the next call.

### Boundary

- `aloe/definition-query.rkt` is the public boundary. It is not
  re-exported from `aloe/main.rkt`. It is not added to `driver.rkt`,
  and it is not an Aloe message or runtime binding. It does not evaluate
  the program, and it has no host-injection parameter. It requires
  nothing from `aloe/expression-query.rkt`.
- The checker side is a narrow bridge, like the expression query's. It
  is a new `aloe/type.rkt` submodule named `definition-query-observation`.
  It checks the program with the definition observer active and applies
  the three jump rules. It returns the jump's `name-loc`, defining path,
  and cache bytes, or `#f`. The public module turns that into the
  result. Internal names are yours.
- The definition result is not `expression-query-result`. Do not add a
  field to that struct, and do not make hover call this query.
  `aloe/expression-query.rkt` does not change.
- Editor-definition 002 adds kind T to this same token walk and this
  same bridge. Do not add it here.

## Exact file scope

May edit:

- `aloe/type.rkt`: the observer calls in `infer-expression` (beside
  `retain-expression-observation!`, and in the `define-class-expr` and
  `define-methods-expr` arms), the `make-checker-observation-api` call,
  and the new `definition-query-observation` submodule. Nothing else
  in this file changes.
- `aloe/private/checker-observation.rkt`
- `aloe/private/expression-selection.rkt`, only to export
  `expression-children`
- `aloe/definition-query.rkt` and
  `aloe/private/definition-selection.rkt` (new)
- `tests/editor/definition/001-query.rkt` (new)
- `tests/editor/definition/fixtures/wide.aloe` and
  `tests/editor/definition/fixtures/wide-user.aloe` (new)
- `docs/editor/definition/README.md` and `docs/editor/README.md`, for
  the status lines below

Do not edit:

- `aloe/parse.rkt`, `aloe/eval.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/library.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/lsp.rkt`,
  `aloe/signature-catalog.rkt`, or
  `aloe/private/completion-selection.rkt`
- any existing test or fixture, including
  `tests/editor/definition/000-spans.rkt`, `point.aloe`, and
  `shapes.aloe`
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or any spec,
  charter, or checkpoint document, this one included
- `lib/`, `examples/`, `editors/vscode/`, `gel/`, or `host/`
- any error text

If an existing test fails, or the slice seems to need a file outside
this list, stop and report it. The scratch run below needed none.

## Fixtures

Add two files. Later checkpoints reuse them unchanged. Each has one LF
after every line. `wide.aloe` is one line. Its string holds U+1F600, the
UTF-8 bytes `F0 9F 98 80`, and that is its only non-ASCII character. It
is 65 characters and 68 bytes.

`tests/editor/definition/fixtures/wide.aloe`:

```aloe
(define wide "😀") (define-class Wide (fields (n Int)) (methods))
```

`tests/editor/definition/fixtures/wide-user.aloe`, 2 lines, 43 bytes:

```aloe
(load "wide.aloe")
(define w (Wide new 1))
```

`point.aloe` and `shapes.aloe` already exist from 000. For reference
while writing tests, these are the lines of `shapes.aloe` that the
cursors below name:

```text
 5    (moved (by Point) Point))
 7  (define-class (Box T)
14        (Point new 0 0))))
16  (define-class Segment Mover
24  (define-methods Point
27        (Box new item self (Option None)))
31  (define-methods Box
36  (define P Point)
38  (define-class Holder
45  (define origin (Point new 0 0))
47  (define alias-made (P new 3 4))
48  (define again ((fn (Point) (Point new 1 2)) call Point))
49  (define third (Point new* (x 5) (y 6)))
```

## Required tests

Add `tests/editor/definition/001-query.rkt`. It is three directories
below the repository root, so use `../../../aloe/...` for module paths.
Use `define-runtime-path` for the fixtures and for `lib/option.aloe`.
Require the public module only, plus `exn:fail:aloe-type?` from
`aloe/main.rkt`. Every temporary file goes in a directory made under
`(find-system-path 'temp-dir)` and is removed unconditionally.

Lines are one-based, columns zero-based, and positions one-based, as
`srcloc` reports them. "Path" below means a complete, simplified path:
`(simplify-path (path->complete-path p) #f)`. All values below were
measured on a prototype of this checkpoint.

### Targets

| Target | File | Line | Column | Position | Span |
|---|---|---:|---:|---:|---:|
| Point | `point.aloe` | 1 | 14 | 15 | 5 |
| Box | `shapes.aloe` | 7 | 15 | 131 | 3 |
| Segment | `shapes.aloe` | 16 | 14 | 279 | 7 |
| Holder | `shapes.aloe` | 38 | 14 | 702 | 6 |
| Option | `lib/option.aloe` | 1 | 15 | 16 | 6 |
| Wide | `wide.aloe` | 1 | 32 | 33 | 4 |

A jump to a target means:

- the location's source is that file's path;
- its line, column, position, and span are the table's;
- `text` is `equal?` to `(file->string <that file>)`.

1. **Jumps.** Each cursor in `shapes.aloe` is the token's first
   character, and each jumps to its target:

   | Kind | Line | Col | Position | Token | Target |
   |---|---:|---:|---:|---|---|
   | C | 7 | 15 | 131 | `Box` in the generic header | Box |
   | V | 14 | 7 | 246 | `Point` in a deferred generic body | Point |
   | C | 16 | 14 | 279 | `Segment` in a bare header | Segment |
   | M | 24 | 16 | 452 | `Point`, a target from another file | Point |
   | V | 27 | 7 | 513 | `Box` as a receiver | Box |
   | V | 27 | 26 | 532 | `Option` as a receiver | Option |
   | M | 31 | 16 | 615 | `Box`, a target in the same file | Box |
   | V | 36 | 10 | 680 | `Point` in `(define P Point)` | Point |
   | C | 38 | 14 | 702 | `Holder` | Holder |
   | V | 45 | 16 | 818 | `Point` in `(Point new 0 0)` | Point |
   | V | 48 | 28 | 917 | the body's `Point` in `((fn (Point) ...) call Point)` | Point |
   | V | 48 | 49 | 938 | the argument `Point` | Point |
   | V | 49 | 15 | 961 | `Point` before `new*` | Point |

   Also, in `wide-user.aloe`, the V cursor at line 2, column 11,
   position 31 jumps to Wide. Its `text` contains
   `(string (integer->char #x1F600))`. The target's column and position
   count that emoji as one character.

2. **Type symbols are not tokens yet.** Put these in their own
   `test-case` named `"type symbols are not tokens before editor-definition 002"`.
   002 replaces it. Each position in `shapes.aloe` returns `#f`: 100,
   107, 173, 192, 199, 233, 333, 410, 499, 568, 747, 751, and 779.

3. **Misses.** Each position in `shapes.aloe` returns `#f`:

   | Line | Col | Position | What is there |
   |---:|---:|---:|---|
   | 2 | 2 | 23 | `Point` in a comment |
   | 4 | 17 | 81 | `Mover`, a `define-protocol` name |
   | 7 | 19 | 135 | `T`, a header type parameter |
   | 9 | 10 | 158 | `T`, a field type that is a type parameter |
   | 14 | 6 | 245 | the parenthesis before `Point` |
   | 14 | 12 | 251 | the space just after `Point` |
   | 14 | 13 | 252 | `new`, a selector |
   | 16 | 22 | 287 | `Mover`, a protocol slot |
   | 18 | 5 | 314 | `Line`, a constructor selector |
   | 26 | 26 | 495 | `A` in `(item A)`, a method type parameter |
   | 26 | 34 | 503 | `A` in `(Box A)` |
   | 27 | 20 | 526 | `self`, an instance |
   | 27 | 33 | 539 | `None`, a selector |
   | 28 | 14 | 561 | `Mover`, a protocol in a type |
   | 33 | 16 | 646 | `T`, the target's type parameter in `define-methods` |
   | 36 | 8 | 678 | `P`, a `define` name |
   | 40 | 7 | 726 | `P`, an alias in a field type |
   | 41 | 12 | 741 | `List`, a kernel name in a type |
   | 42 | 12 | 772 | `->` |
   | 42 | 15 | 775 | `Int`, a kernel name in a type |
   | 46 | 12 | 846 | `origin`, an instance |
   | 46 | 19 | 853 | `x`, a field-read selector |
   | 47 | 20 | 877 | `P`, an alias in an expression |
   | 48 | 20 | 909 | `Point`, the `fn` parameter |
   | 48 | 44 | 933 | `call` |
   | 49 | 21 | 967 | `new*` |
   | 50 | 24 | 1010 | `with` |
   | 51 | 19 | 1042 | `List`, a kernel class in an expression |
   | 52 | 15 | 1070 | `Point` inside a string |

   Also, `Int` in `point.aloe` (position 38) returns `#f`, and
   `shapes.aloe` at position 5000, past the end, returns `#f`.

4. **Token edges.** Every position from 279 to 285 (all of `Segment`)
   answers the same result. Position 133, the last character of `Box`
   at line 7, jumps; 134 does not. Position 822, the last character of
   `Point` at line 45, jumps; 823 does not.

5. **Kernel targets and receivers.** In a temporary file holding

   ```aloe
   (define-methods String
     (methods
       (shout () String self)))
   (define s String)
   ```

   the M token `String` at position 17 returns `#f`. So does the V token
   `String` in `(define s String)`, at line 4, column 10.

6. **Option.** The V cursor at position 532 of `shapes.aloe` jumps to
   Option in `lib/option.aloe`. Querying `lib/option.aloe` itself at
   position 16 (its header) also jumps to Option. Then write a copy of
   `lib/option.aloe` with `"; edited\n"` prepended to a temporary
   directory, and query the copy at position 25 with `#:document-path`
   set to `lib/option.aloe`. The answer is line 2, column 15, position
   25, span 6. Its source is the path of `lib/option.aloe`, not the
   copy, and its `text` is the copy's text.

7. **A dirty buffer.** In a temporary directory, write `shapes.aloe`
   with one LF prepended, and `point.aloe` with `"; copied\n"`
   prepended, under the same two names. Query the shapes copy with
   `#:document-path` set to the real `shapes.aloe`:

   | Position | Token | Answer |
   |---:|---|---|
   | 132 | C `Box` | line 8, column 15, position 132, span 3; source the real `shapes.aloe` path; `text` the shapes copy's text |
   | 514 | V `Box` | the same |
   | 819 | V `Point` | line 2, column 14, position 24, span 5; source the path of the copied `point.aloe`, which the load read; `text` the point copy's text |

8. **Failures.**
   - `(query-definition-at 3 1)`, `(query-definition-at shapes 0)`, and
     `(query-definition-at shapes 1 #:document-path 'x)` each raise
     `exn:fail:contract?`, and each message starts with
     `"query-definition-at: "`.
   - A missing file raises, and the message contains
     `"source path does not name a regular file"`.
   - A temporary file holding `"(define-class Point\n"` raises
     `exn:fail:read?`. A temporary file holding `"(define-class)\n"`
     raises `exn:fail?` with exactly the message `read-program` raises
     for that text on the found tree:

     ```racket
     "parse-datum: malformed define-class; expected a name, optional protocol, fields or constructors, and methods\n  datum: '(define-class)"
     ```
   - A temporary file holding

     ```aloe
     (define-class Bad (fields (n Int)) (methods))
     (define b (Bad new 1))
     ```

     jumps to `Bad` (line 1, column 14, position 15, span 3) from
     position 15 (C) and from position 58 (V). The same text with
     `(define oops (1 + "x"))` appended as a third line raises
     `exn:fail:aloe-type?` from both positions, with the message
     `"typecheck: Int + expects an Int argument"`.

9. **Independence.** Two calls in a row at position 532 of
   `shapes.aloe` return `equal?` results, and so do two at position 131.

The existing hover, completion, and LSP tests stay green without edits.
That is the proof that `selected-expression-in-method-body?` and the
expression observer are unchanged without a definition observer.

## Scratch run

On 2026-10-15 a prototype of this checkpoint was applied to a copy of
the tree at `87c0844`. It added about 40 lines to `aloe/type.rkt` and
about 50 to `aloe/private/checker-observation.rkt`, exported
`expression-children`, and added two new modules of about 90 lines
together. Then:

- Every cursor in tests 1–9 gave the answer listed.
- With the definition owner removed from
  `selected-expression-in-method-body?`, the cursor at position 246
  raised the "never observed" internal error, because `Box`'s `fresh`
  body was never checked.
- With the two new fixtures in place and no existing test edited, the
  whole suite ran 3028 tests under `-j 4`, all passing, and no file
  crashed. That is 3026 plus one modules-census case for each new
  fixture. `tests/modules/001-census.rkt` makes a test for every
  `.aloe` file under `tests/`, and both new fixtures pass it.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/definition/001-query.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

All green. The whole suite is 3026 tests, plus this checkpoint's new
ones, plus 2 census cases for `wide.aloe` and `wide-user.aloe`. If only
`tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar fails under
`-j 4`, run that file alone, and it must pass there.

There is no hand check for this checkpoint. The editor shows nothing
new until the LSP layer.

Update the status lines:

- In `docs/editor/definition/README.md`, add a row for
  `checkpoints/001-query.md`: "Implemented *date*, awaiting review",
  with the focused test count and the whole-suite count.
- In `docs/editor/README.md`, set project 8's cell to say
  editor-definition 001 is implemented and awaiting review.

Stop for review without committing. Do not write or start
editor-definition 002.

## Explicit non-goals

- Kind T: resolving a symbol inside a type annotation, the walk that
  agrees with `type-from-sexpr`, or observing annotation checks
  (editor-definition 002)
- `textDocument/definition`, `definitionProvider`, or any edit to
  `aloe/lsp.rkt` or `editors/vscode/`
- Jumps for method selectors, constructor selectors, `new*`, `with`,
  protocols, a binding site of `define`, `let`, or `fn`, or an instance
- Go-to-type-definition on an instance
- A change to hover, completion, `expression-query-result`, or
  `aloe/expression-query.rkt`
- Host injection, evaluation, an Aloe message, or a driver export for
  the query
- A workspace index, a dirty overlay for a nested load, or reading a
  nested load from anywhere but disk
- Any change to `aloe/parse.rkt` or to how positions are counted
