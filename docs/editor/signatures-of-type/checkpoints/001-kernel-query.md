# Editor signatures of a type 001 — Kernel type query

**Status.** Ready to implement.

## Goal

Add the public Racket query `type-signature-specs` for checker-native kernel
types: primitive instances, lists, functions, built-in class objects, rigid
numeric parameters, resolved and unresolved inference variables, and the
specified empty internal types.

The query must reuse the shared catalog completed in
editor-signatures-of-type 000 and must read environment-local `List` and
`String` method declarations from the supplied checker environment. It does
not parse, typecheck, evaluate, load, reflect a runtime value, or mutate the
environment.

User classes and instances, protocols, and injected host receivers are the
next declaration-backed slice. In 001 they must fail visibly as deferred
families rather than masquerading as legitimate empty catalogs.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependency, and identity

- `SPEC.md` remains Aloe language law. This checkpoint does not change sends,
  dispatch, types, generics, or `define-methods`.
- `docs/editor/signatures-of-type/spec.md` sections 1–5 and 7 define the
  public operation, kernel rows, ordering, substitutions, and required tests.
- Editor-signatures-of-type 000 is implemented. Its
  `aloe/signature-catalog.rkt` owns the transparent `signature-spec`, all
  kernel row tables, declaration converters, call-row construction, and
  recursive type-datum substitution. Do not copy any of those into
  `aloe/type.rkt`.
- `aloe/type.rkt` owns checker type structures, `resolve-type`, `type->datum`,
  and environment-local method tables. The new query belongs there.

Identity is `(editor-signatures-of-type, 001)`, spoken
**editor-signatures-of-type 001**. This is a local editor checkpoint, not
global checkpoint 118 and not editor-source-locations 001. Do not edit
`CHECKPOINTS.md` or add files under `docs/checkpoints/`.

## Public operation

Export this exact two-argument operation from `aloe/type.rkt`:

```racket
(type-signature-specs checker-type type-environment)
  ; -> (listof signature-spec?)
```

The normal call sequence is:

```racket
(define type (type-of expression environment))
(type-signature-specs type environment)
```

The environment must be the same checker environment in which the type was
obtained. This is a caller requirement because `List` and `String` extension
methods are environment-local. Do not add environment provenance to checker
types and do not guess or use a default environment.

The first argument is an internal checker type, not an Aloe type datum,
source string, expression, runtime value, or cursor position. The second
argument must satisfy `type-environment?`. Reject invalid arguments with a
Racket argument error whose `who` is `type-signature-specs`; do not let a
match failure or unrelated accessor exception escape.

Return a fresh proper list of the shared transparent `signature-spec` rows.
Rows contain Racket symbols and type datums only. Do not construct Aloe
`Signature`, `List`, or `Symbol` values.

The operation is observational and read-only:

- do not call `parse-datum`, `read-program`, `type-of`, `typecheck-program`,
  `eval-expr`, or any runtime reflection operation from it;
- do not load the List or String libraries;
- do not add, remove, reorder, or otherwise mutate environment bindings or
  method tables; and
- do not bind an unresolved inference variable or mark it numeric.

Following an already-bound inference variable through `resolve-type` is
required. Existing path compression while resolving a bound variable is not
a new type constraint.

Do not re-export the query from `aloe/main.rkt` in this checkpoint. The
specified public home is `aloe/type.rkt`.

## Kernel instance selection

For each resolved checker type below, select the matching rows from
`aloe/signature-catalog.rkt`. Preserve exact row order and overload
multiplicity; never sort or deduplicate.

| Checker type | Shared catalog result |
|---|---|
| `int-type` | exact `Int` instance rows |
| `float-type` | exact `Float` instance rows |
| `bool-type` | exact `Bool` instance rows |
| `symbol-type` | exact `Symbol` instance rows |
| `mirror-type` | exact `Mirror` instance rows |
| `signature-type` | exact `Signature` instance rows |

The exact tables remain pinned by checkpoint 000. The query selects those
same rows; it must not spell `+`, `if`, `messages`, or another kernel selector
in a second table in `type.rkt`.

### String

A `string-type` returns the shared four-row String kernel catalog followed by
every method in the supplied environment's `string-class-type` table, in
installation order. Convert the declarations with the shared catalog helper.
Every overload remains a row.

A raw environment from `aloe/type.rkt` has no installed String library method
until the caller typechecks a `define-methods String` form. A normal
bootstrapped environment from `aloe/main.rkt` has its installed library
method(s). The query reports whichever state the supplied environment
actually has; it must not know `starts-with?` by name.

### List

For `(list-type element)`, recursively convert `element` with the existing
checker `type->datum`, substitute that datum for `T` through the shared five
List kernel rows, then append the supplied environment's installed List
method declarations with the same receiver substitution.

Examples of required substitution:

```text
(List String):
  first : ()       -> String
  rest  : ()       -> (List String)
  cons  : (String) -> (List String)
```

For an installed method with a method-local `A`, substitute the receiver's
element type for `T` but preserve `A`. Do not infer or instantiate a
method-local parameter while inspecting it.

If a nested element type contains a currently unresolved inference variable,
use the existing `type->datum` spelling for that nested type. The List
receiver still has a stable catalog. This differs from querying an unresolved
inference variable as the receiver itself, which returns no rows.

### Functions

For `(function-type parameters result)`, return exactly one row built by the
shared call-row helper:

```text
call : (P ...) -> R
```

Convert every parameter and the result through `type->datum`. Preserve zero
arity and parameter order. Static function rows are exact; do not use the
runtime mirror's erased `T ... -> U` representation.

This is the named function parity exception from the project spec. Static and
runtime rows must have selector `call` and the same arity, while their type
datums may differ.

## Built-in class objects

Select the distinct shared class-object catalogs:

```text
list-class-type:
  of    : (T) -> (List T)
  empty : ()  -> (List T)

symbol-class-type:
  intern : (String) -> Symbol

mirror-class-type:
  of : (T) -> Mirror

string-class-type:
  no rows
```

Do not merge instance and class-object catalogs. Installed List and String
instance methods are not class sends. `List.of` remains the shared unary row
even though ordinary List construction is variadic.

`Int`, `Float`, `Bool`, and `Signature` have no bound class-object checker
types, so no additional case is needed for them.

## Variables, rigid parameters, and empty types

Resolve a bound `type-variable` and query the resolved checker type. An
unbound `type-variable` returns an empty list without gaining a binding,
numeric flag, or other constraint.

A rigid `parameter-type` uses the checker's current generic numeric receiver
catalog. If its displayed name is `T`, return these rows in order:

```text
+  : (T) -> T
-  : (T) -> T
*  : (T) -> T
/  : (T) -> T
<  : (T) -> Bool
>  : (T) -> Bool
<= : (T) -> Bool
>= : (T) -> Bool
=  : (T) -> Bool
```

It has no `float` or `text` row. Build this from shared numeric kernel rows
and substitution, or add one general catalog helper if necessary; do not put
a second nine-row literal in `type.rkt`.

These resolved types have legitimate empty catalogs:

- `void-type`
- `type-data-type`
- `opaque-type`
- an unresolved `type-variable`
- `string-class-type`

Return `'()` for them. Do not confuse a legitimate empty catalog with a
deferred declaration-backed type family.

## Deferred type families in 001

The following are deliberately not implemented in this checkpoint:

- `instance-type`
- user `class-type`
- `protocol-type`
- `host-receiver-type`

If queried in 001, raise a clear Racket error whose `who` is
`type-signature-specs` and which says that the checker type family is deferred
by this checkpoint. Do not return `'()` for these families, because an empty
list would falsely claim the type has no catalog. Do not make the exact prose
of this temporary error a long-term public contract; the next slice removes
the deferred cases.

Do not partially implement one declared family, look up a runtime value, or
hardcode a user class or host interface name.

## Exact file scope

Implementation may edit only:

- `aloe/type.rkt`
- `aloe/signature-catalog.rkt` only if one small general helper is needed for
  rigid numeric parameter rows
- `tests/editor/signatures-of-type/001-kernel-query.rkt` (new)

Do not edit:

- `aloe/eval.rkt` or the runtime reflection/value representation
- `aloe/parse.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`, or `aloe/host.rkt`
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- `gel/`, `lib/`, `host/`, or another editor project
- checkpoint 000, the project spec, or a later checkpoint document except for
  status/index updates made by the checkpoint manager

If implementing the read-only query requires exporting mutable checker
internals, adding environment provenance, or changing type inference, stop
and return the checkpoint for design review. Do not export `parameter-type`
or mutable `type-variable` constructors merely to make a test convenient.

## Required tests

Add `tests/editor/signatures-of-type/001-kernel-query.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in
`require` and `define-runtime-path` paths.

Use exact `signature-spec` equality or exact selector/parameters/return
triples. Do not compare only selector sets or printed strings. Cover at least:

1. `type-signature-specs` is exported from `aloe/type.rkt`, returns only the
   shared row structure, requires exactly a checker type plus checker
   environment, and reports deliberate argument errors for invalid values.
2. Exact static rows and order for `Int`, `Float`, `Bool`, `String`, `Symbol`,
   `Mirror`, and `Signature`. With paired checker/runtime environments, these
   rows equal their `Mirror.signatures` triples.
3. `(List String)` substitutes through all five kernel rows and through an
   installed method whose row mentions both receiver `T` and method-local
   `A`. The static rows equal runtime mirror rows when both sides have
   processed the same `define-methods` form.
4. Two checker environments with different unique String or List extension
   methods return their own rows only. Repeated queries do not duplicate or
   reinstall a method. Production query code does not mention any library
   extension selector.
5. Exact zero-, one-, and multi-parameter function rows. Compare an annotated
   function's exact static row with its runtime mirror and prove the named
   exception: same `call` selector and arity, exact static datums versus
   runtime `T ... -> U`.
6. Exact and distinct class-object catalogs for `List`, `String`, `Symbol`,
   and `Mirror`, including unary `List.of` and empty `String`.
7. A rigid parameter has the nine ordered same-parameter numeric rows and no
   `float` or `text`. Obtain the internal value in test code without widening
   the production exports.
8. An unbound inference variable returns empty and remains unbound/non-numeric;
   a bound inference variable resolves and returns its concrete catalog.
9. `Void`, `TypeData`, `Dummy`/another opaque type, and a nested unresolved
   List element follow the empty-versus-containing rules above.
10. At least one instance, user class object, protocol, and host receiver are
    rejected as visibly deferred rather than reported as empty. Creating a
    host receiver for this assertion must not call its implementation.
11. Querying performs no parse, evaluation, load, runtime reflection, or
    environment mutation. Existing checker inference, direct sends, Mirror
    rows, and checkpoint 000 remain green.

For static/runtime parity, use one `driver` or otherwise paired environments
that have processed the same definitions. Do not compare a bootstrapped
runtime environment with a raw checker environment.

## Baseline suite note

On the current branch, `raco test tests` has two unrelated failures already
present in `HEAD`, both in `tests/gel/presentations/003-doc-law.rkt`. That test
expects pre-003 phrases while the checked-in handoff and experiment spec say
gel-presentations 003 is complete.

Do not edit or weaken that Gel test or its documents in this checkpoint. Run
the recursive suite and require every other test to pass with exactly those
same two failures and no new failure. If the baseline contradiction has been
repaired before implementation starts, require a completely green recursive
suite.

## Hand check and acceptance

After the automated tests, run this by hand in a Racket REPL from the
repository root:

```racket
(require "aloe/parse.rkt"
         (prefix-in type: "aloe/type.rkt"))

(define environment (type:make-type-environment))
(define list-of-string
  (type:type-of (parse-datum '(List of "a")) environment))

(map type:signature-spec-selector
     (type:type-signature-specs list-of-string environment))
```

The raw environment has no library extensions, so the exact result is:

```racket
'(empty? first rest cons len)
```

Run:

```sh
raco test tests/editor/signatures-of-type/001-kernel-query.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when the public read-only query returns exact
shared rows for every in-scope kernel checker type, observes only the supplied
environment's extensions, preserves the function exception and unresolved
variable behavior, rejects deferred declared families visibly, passes its
focused tests and hand check, and introduces no recursive-suite failure.
Stop for review without committing and without implementing the
declaration-backed follow-up.

## Explicit non-goals

- No user instance or user class-object catalog
- No protocol catalog
- No injected host-receiver catalog
- No expression-level query, source/cursor lookup, parsing, CLI, LSP,
  JSON-RPC, VS Code, hover, or completion
- No Aloe syntax, type grammar, dispatch, inference, or error-format change
- No evaluation or construction of Aloe `Signature` values
- No runtime reflection change
- No variadic signature representation
- No runtime retention of inferred function types
- No hardcoded library extension selector or second kernel table
- No Gel or Boids work
