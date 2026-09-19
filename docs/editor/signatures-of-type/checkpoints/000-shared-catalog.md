# Editor signatures of a type 000 — Shared signature catalog

**Status.** Implemented and reviewed. The focused 11-test suite and hand check
are green. The recursive suite has only the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` wording failures already present in
`HEAD`; this checkpoint does not edit that unrelated Gel documentation test.

## Goal

Create the shared Racket signature-catalog substrate required by the static
type query. Move the existing runtime reflection rows onto that substrate so
`Mirror` no longer owns a private row type or private copies of the kernel
tables. While moving class-object rows, fix the specified constructor gap:
an explicit-constructor class reflects each declared constructor instead of a
fabricated `new` row.

This checkpoint establishes one row representation and one declarative
catalog with a working runtime consumer. It does **not** add
`type-signature-specs`; the checker-side query is the next slice.

The implementer receives only this document. Every rule for this slice is
below.

## Authority and identity

- `SPEC.md` remains Aloe language law, especially sends, classes,
  constructors, `define-methods`, `Mirror`, `Signature`, and the typed host
  boundary.
- `docs/editor/signatures-of-type/spec.md` is the design authority for this
  local experiment. Sections 1–6 define the row shape, catalog ownership,
  order, substitutions, and the explicit-constructor correction.
- `aloe/eval.rkt` is the starting runtime implementation. It currently owns a
  private `signature-spec`, conversion helpers, kernel tables, and
  `value-signature-specs`.
- `aloe/type.rkt` is the eventual static consumer. In 000 it only re-exports
  the new public row structure; it does not select rows yet.

Identity is `(editor-signatures-of-type, 000)`, spoken
**editor-signatures-of-type 000**. This is not global checkpoint 118 and is
independent of the editor-source-locations numbering. Do not edit
`CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Public row representation

Add `aloe/signature-catalog.rkt`. It owns and exports this exact transparent
Racket structure:

```racket
(struct signature-spec (selector parameters return) #:transparent)
```

- `selector` is a Racket symbol.
- `parameters` is an ordered proper list of type datums.
- `return` is one type datum.
- A simple type datum is a symbol such as `Int`; a compound datum is a proper
  list such as `(List String)`, `(Point Int)`, or `(-> T U)`.
- Rows contain no Aloe runtime values, signature owner, row index, invocation
  procedure, source location, or checker type object.

Remove the private structure declaration from `aloe/eval.rkt` and import the
catalog structure there. Re-export the same structure binding from
`aloe/type.rkt` with its constructor, predicate, and accessors. A row made
through the `aloe/type.rkt` export must satisfy the predicate imported
directly from `aloe/signature-catalog.rkt`; do not create a lookalike second
structure.

The catalog module may export narrowly named helper operations needed by both
the evaluator and the later checker query. Do not expose evaluator values,
checker structures, or mutable tables through it.

## Catalog ownership

Move every hand-written kernel signature row out of `aloe/eval.rkt` and into
`aloe/signature-catalog.rkt`. The new module also owns reusable operations
that:

- turn field declarations into zero-parameter rows;
- turn constructor declarations into class-object rows;
- turn method declarations into rows without collapsing overloads;
- turn validated host method declarations into rows;
- construct a `call` row from supplied parameter and return type datums; and
- recursively substitute type datums throughout a row.

The module may require declaration-only modules such as `parse.rkt` and
`host.rkt`. It must not require `eval.rkt` or `type.rkt`; avoid a dependency
cycle and keep runtime/checker object selection outside the catalog.

`value-signature-specs` may remain private in `aloe/eval.rkt`. Its job after
this checkpoint is only to recognize a runtime value, choose shared catalog
rows, and supply runtime declarations, environment-local methods, or a
runtime substitution. It must not retain its own kernel row literals or
conversion implementation. The evaluator remains responsible for turning a
`signature-spec` into an Aloe `Signature` value with owner and row-index
metadata.

Do not make the catalog drive ordinary send dispatch or overload selection.
Those procedural paths remain unchanged.

## Exact kernel rows

The shared catalog contains these rows in exactly this order. It never sorts
or deduplicates them.

`Int` instance:

```text
+     : (Int) -> Int
-     : (Int) -> Int
*     : (Int) -> Int
/     : (Int) -> Int
<     : (Int) -> Bool
>     : (Int) -> Bool
<=    : (Int) -> Bool
>=    : (Int) -> Bool
=     : (Int) -> Bool
float : ()    -> Float
text  : ()    -> String
```

`Float` instance:

```text
+  : (Float) -> Float
-  : (Float) -> Float
*  : (Float) -> Float
/  : (Float) -> Float
<  : (Float) -> Bool
>  : (Float) -> Bool
<= : (Float) -> Bool
>= : (Float) -> Bool
=  : (Float) -> Bool
```

Other primitive instances:

```text
Bool:
  if : ((-> T) (-> T)) -> T

String:
  =      : (String) -> Bool
  append : (String) -> String
  len    : ()       -> Int
  take   : (Int)    -> String

Symbol:
  name : ()       -> String
  =    : (Symbol) -> Bool

Mirror:
  messages   : ()          -> (List Symbol)
  signatures : ()          -> (List Signature)
  invoke     : (Signature) -> U
  subject    : ()          -> U
  raw        : ()          -> String

Signature:
  selector : ()       -> Symbol
  params   : ()       -> (List TypeData)
  return   : ()       -> TypeData
  accepts? : (Mirror) -> Bool
```

The `(List T)` instance template is:

```text
empty? : ()  -> Bool
first  : ()  -> T
rest   : ()  -> (List T)
cons   : (T) -> (List T)
len    : ()  -> Int
```

Its runtime view substitutes the reflected list's element type, then appends
the methods installed on that exact runtime `List` class in installation
order. An erased empty runtime list retains today's `T` representation.

A runtime function retains the existing erased row: one `T` parameter for
each source parameter and return `U`. The shared function-row builder must
accept concrete parameter and return datums as inputs so the later static
consumer can use exact checker types without inventing another `call` table.

Built-in class-object rows are distinct from instance rows:

```text
List:
  of    : (T) -> (List T)
  empty : ()  -> (List T)

Symbol:
  intern : (String) -> Symbol

Mirror:
  of : (T) -> Mirror
```

`List.of` deliberately remains a unary reflected row although the ordinary
send is variadic. The runtime `String` class object has no rows. There are no
runtime class objects for `Int`, `Float`, `Bool`, or `Signature`.

## Declaration rows and substitution

For a legacy `(fields ...)` instance, list field rows in declaration order,
then method rows in declaration/installation order. For an explicit
`(constructors ...)` instance, list no payload fields; list only its methods.
Every overload remains a separate row.

Substitute receiver-level generic arguments recursively through fields and
methods. For example, a runtime `(Point Int)` row replaces class parameter
`T` with `Int` inside direct, class, list, and function type datums.
Method-local parameters such as `A` or `U` remain symbolic. The checker
already rejects a method-local parameter that shadows a class parameter; do
not add a new generic rule here.

`String` appends methods installed through `define-methods String` after its
four kernel rows. `List` does the same after its five kernel rows with its
element substitution. A user class appends methods in installation order.
The catalog must read the declarations supplied by the runtime environment;
it must not know library selectors such as `fold`, `map`, `reverse`, or
`starts-with?`.

Host rows come directly from the exact `host-interface` method declarations
in interface order. Inspection must not call an implementation or inspect
receiver state.

Preserve the current runtime limitation for host types nested in generic
instances: their runtime type datum may remain `Object` or `?`. Repairing that
representation is outside 000.

## Class-object constructor correction

A user class object now has one row per declaration-ordered constructor:

- a legacy `(fields ...)` class has its single implicit `new` row;
- an explicit `(constructors ...)` class has exactly its declared selector
  rows and no fabricated `new`;
- constructor parameters are that constructor's payload field types in order;
  and
- the return datum is the class instance type, preserving declared generic
  parameters.

For example, class object `Option` must expose:

```text
None : ()  -> (Option T)
Some : (T) -> (Option T)
```

`Mirror.messages` obtains `None`, then `Some`, without a `new`. The matching
`Mirror.signatures` rows have the exact parameters and return datums above.
Exact-row `Mirror.invoke` must invoke either selected constructor against the
class mirror. Keep signature ownership and row indices as evaluator-private
metadata.

Do not change ordinary named construction, instance `case`, or the meaning of
legacy `new`.

Any evaluator offset that separates a kernel prefix from appended methods
must be derived from the shared catalog length or a shared helper, not from a
second copied table size. Exact-row invocation and method-local type-parameter
lookup must continue to address the same row seen by `Mirror.signatures`.

## Exact file scope

Implementation may edit only:

- `aloe/signature-catalog.rkt` (new)
- `aloe/eval.rkt` (consume the catalog and fix class constructor rows)
- `aloe/type.rkt` (require and re-export `signature-spec` only)
- `tests/editor/signatures-of-type/000-shared-catalog.rkt` (new)
- an existing reflection test only if its expected explicit-constructor class
  rows encoded the old bug

Do not edit:

- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- `aloe/parse.rkt`, `aloe/driver.rkt`, `aloe/main.rkt`, `aloe/host.rkt`, or
  the runtime `Signature` value representation
- `gel/`, `lib/`, `host/`, or another editor project
- the signature-of-type design documents or a later checkpoint

If the catalog cannot be made independent of both evaluator and checker
modules, or constructor rows require changing `Signature` ownership, stop and
return the checkpoint for design review.

## Required tests

Add `tests/editor/signatures-of-type/000-shared-catalog.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in
`require` and `define-runtime-path` paths.

Cover at least:

1. The public `signature-spec` constructor, predicate, accessors,
   transparency, structural equality, and field order. Prove that the binding
   re-exported by `aloe/type.rkt` is the same structure type as the direct
   `aloe/signature-catalog.rkt` export.
2. The exact row triples and order for every kernel instance and built-in
   class-object table listed above, including the deliberately unary
   `List.of` row and the empty `String` class-object catalog.
3. Recursive substitution through at least `(List T)`, `(Point T)`, and an
   arrow datum, with a method-local parameter left unchanged.
4. A generic legacy `Point` instance whose mirror lists fields before methods
   with `Int` substituted, plus a `Point` class mirror with one `new` row.
5. A generic explicit-constructor `Option` class whose class mirror contains
   exactly `None` then `Some`, has no `new`, reports the parameter and return
   datums above, and can invoke both exact constructor rows. Its instance
   mirror has no constructor or payload-field rows.
6. A unique test method installed through `define-methods` appears once at the
   end of the relevant `List` or `String` runtime catalog. The test and
   production catalog code must not depend on the names of existing library
   extension methods.
7. A test host interface preserves exact declaration order and type datums,
   and catalog inspection performs no implementation call.
8. Runtime function reflection keeps selector `call`, source arity, erased
   `T` parameters, and `U` return.
9. Existing `Mirror.messages` first-occurrence deduplication, overload rows,
   exact-row invocation, direct sends, named construction, and library
   methods remain green.

Compare Racket `signature-spec` values or extracted selector/parameter/return
triples. Do not compare only selector sets or formatted display strings.

This checkpoint intentionally has no `type-signature-specs` test. Do not add
the query early.

## Hand check and acceptance

After the automated tests, run one expression by hand in `racket bin/aloe`.
Define the generic `Option` class from `SPEC.md`, then evaluate:

```aloe
(define option-rows ((Mirror of Option) signatures))
((((option-rows rest) first) selector) name)
```

The result is `"Some"`; the first row similarly reports `"None"`, and there
is no `new` row.

Run exactly:

```sh
raco test tests/editor/signatures-of-type/000-shared-catalog.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when the shared public row structure exists, all
runtime catalogs come from the new module, explicit constructors reflect and
invoke in declaration order, the hand check succeeds, and the recursive test
suite is green. Stop for review without committing and without implementing
editor-signatures-of-type 001.

## Explicit non-goals

- No `type-signature-specs` or other checker query
- No expression, source-span, cursor, completion, hover, CLI, LSP, JSON-RPC,
  or VS Code operation
- No Aloe syntax, special form, macro, or type-datum representation change
- No change to ordinary send dispatch, overload resolution, construction,
  `case`, or `define-methods`
- No variadic signature representation
- No runtime retention of inferred function types
- No repair of nested generic host-type reification
- No editor-private table, duplicate kernel table, or hardcoded library
  selector
- No Gel or Boids work
