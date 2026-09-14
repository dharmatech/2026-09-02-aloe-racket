# Editor signatures of a type 002 — Declaration-backed types

**Status.** Implemented and reviewed. The combined 000–002 focused suite is
green with 29 tests, and the Pair hand check returns the specified rows. The
recursive suite passes 1,773 of 1,775 tests; its only failures are the two
pre-existing `tests/gel/presentations/003-doc-law.rkt` wording contradictions
already recorded by this series. This checkpoint introduces no additional
failure.

## Goal

Complete `type-signature-specs` for the checker types deliberately deferred by
editor-signatures-of-type 001:

- user class instances;
- user class objects;
- protocols; and
- injected host receivers.

All rows come from the shared declaration converters established in
editor-signatures-of-type 000. Remove 001's temporary deferred-family errors
and prove exact static/runtime row parity, including the protocol and nested
generic host exceptions named in the project specification.

This is the final implementation slice for the Signatures of a Type
specification. It does not add an expression query or any editor client.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law for classes, constructors, protocols,
  overloading, `define-methods`, reflection, and the typed host boundary.
- `docs/editor/signatures-of-type/spec.md` is the local design authority.
  Sections 2–7 define declaration sources, row order, generic substitution,
  parity, named exceptions, and final coverage.
- Editor-signatures-of-type 000 is implemented: one shared transparent
  `signature-spec`, one kernel catalog, declaration converters, recursive
  type-datum substitution, and constructor-correct runtime reflection.
- Editor-signatures-of-type 001 is implemented: the public read-only
  `type-signature-specs` operation and all kernel checker-type families.
- `aloe/type.rkt` already owns the exact `class-info`, `protocol-type`, and
  `host-receiver-type` objects from which this checkpoint selects rows.

Identity is `(editor-signatures-of-type, 002)`, spoken
**editor-signatures-of-type 002**. This is not global checkpoint 118 and is
not part of editor source locations. Do not edit `CHECKPOINTS.md` or add a
file under `docs/checkpoints/`.

## Public operation remains unchanged

Keep the exact operation introduced in 001:

```racket
(type-signature-specs checker-type type-environment)
  ; -> (listof signature-spec?)
```

It remains a two-argument export of `aloe/type.rkt`. The caller supplies the
same environment in which `checker-type` was obtained. Rows remain fresh
proper Racket lists of the shared transparent structure, containing only
selector symbols and type datums.

Preserve all 001 behavior for primitives, String, List, functions, built-in
class objects, rigid parameters, inference variables, and legitimate empty
types. Preserve its argument validation and read-only behavior. Do not
re-export the query from `aloe/main.rkt`.

Delete the temporary `deferred-signature-family` path. Every checker type
family accepted by 001's `checker-type?` now has its final specified result;
there must be no “deferred by editor-signatures-of-type 001” production
error after this checkpoint.

The query still must not parse, typecheck, evaluate, load, reflect a runtime
value, invoke a host implementation, or mutate its environment or checker
type constraints.

## User instance types

For `(instance-type class arguments)`:

1. Pair the class's declared type-parameter **names** with the instance's
   checker argument types in declaration order.
2. Convert each checker argument with the existing `type->datum` and use
   those datums as the receiver substitution.
3. Convert the class's legacy field declarations with the shared field-row
   helper and that substitution.
4. Convert the class's current method declarations with the shared method-row
   helper and the same substitution.
5. Append field rows before method rows.

Do not walk method bodies and do not run overload resolution. Every overload
is a separate row in declaration/installation order.

For a legacy generic class such as:

```aloe
(define-class (Point T)
  (fields (x T) (y T))
  (methods
    (move (other (Point T)) (Point T) self)))
```

the `(Point Int)` instance rows are:

```text
x    : ()          -> Int
y    : ()          -> Int
move : (Point Int) -> (Point Int)
```

Substitution is recursive through nested class, List, and function datums.
The class substitution must not replace method-local parameters such as `A`
or `U`; the checker already prevents a method-local name from shadowing a
class parameter.

An explicit `(constructors ...)` class has no legacy field sends. Its
instance catalog contains methods only—no constructor selectors and no
payload-field rows. Constructor payload is available through `case`, not as
instance messages.

`define-methods` updates `class-info-methods`. A later query must see the new
rows once, appended in installation order, without caching an earlier result
or naming the installed selector in production code.

## User class-object types

For `(class-type class)`, return one row per normalized constructor in
`class-info-constructors`, in declaration order, using the shared constructor
converter.

- A legacy `(fields ...)` class has exactly its implicit `new` constructor
  row.
- An explicit `(constructors ...)` class has exactly its declared constructor
  rows and no fabricated `new`.
- A constructor row's parameters are its payload field type datums in order.
- Its return datum is the class instance type with the class's declared
  generic parameters preserved symbolically.
- Instance methods do not become class-object rows.

For generic class object `Option`:

```text
None : ()  -> (Option T)
Some : (T) -> (Option T)
```

Construct the return datum from the checker's own class and rigid parameter
types—for example via `type->datum` on the corresponding generic
`instance-type`—rather than maintaining a second spelling rule.

Checkpoint 000 already corrected runtime class mirrors and exact constructor
invocation. Static class-object rows must now match those runtime triples and
positions exactly.

## Protocol types

For a `protocol-type`, convert exactly its
`protocol-type-signatures` declarations with the shared method-row helper:

- preserve protocol declaration order;
- preserve every overload;
- use the declared parameter and return type datums;
- do not search for an implementing class;
- do not merge concrete class methods; and
- return an empty list for an empty marker protocol.

A static protocol catalog is the set of sends the checker permits through
that protocol type. Protocols remain types, not runtime method tables, and
this query does not change protocol conformance or runtime dispatch.

This family has the named **protocol erasure** parity exception. When an
expression has static protocol type but evaluates to a concrete instance,
`type-signature-specs` reports the protocol declaration while the value's
`Mirror` reports its concrete class fields and methods. Test both facts; do
not force either view to imitate the other.

## Injected host-receiver types

For `(host-receiver-type interface)`, convert the methods of that exact
carried `host-interface` with the shared host declaration helper.

- Preserve interface declaration order and every declared crossing parameter
  and return datum.
- Use the interface object carried by the checker type directly. Do not look
  up an interface by its display name or by structural shape.
- Do not invoke an implementation or inspect receiver state.
- Do not add the interface identity or name as a field of `signature-spec`.
- Do not make the host interface name legal in Aloe annotation syntax.

Two independently constructed interfaces may have the same display name.
Their checker types remain nominally distinct even though identical
declarations legitimately produce equal row triples. A same-name pair with
different declarations must prove that the query selects from the carried
interface rather than a name-keyed registry.

For a directly injected host receiver, static rows and its runtime
`Mirror.signatures` rows must match exactly. Inspection on either side is
effect-free. Ordinary guarded host sends and exact reflected invocation remain
unchanged.

## Named nested-generic-host exception

Preserve and test the existing runtime reification limitation when an exact
host type is used as a generic class argument.

For a generic wrapper constructed around an injected host receiver:

- the checker retains the exact `host-receiver-type` as the instance
  argument;
- the static wrapper catalog substitutes the checker's `type->datum` spelling
  of that nominal host type into its field and method rows;
- the runtime wrapper catalog may substitute `Object` or `?` because runtime
  generic type data currently erase nested host identity; and
- selector order and arity still agree between the two views.

Record that difference as the named exception. Do not repair runtime generic
host type retention, change `runtime-type-of`, change `Signature.accepts?`,
or weaken exact-row invocation. Direct host receiver rows are not part of
this exception and must have full parity.

## One catalog and ordering locks

All four families must use the converters in
`aloe/signature-catalog.rkt`. Do not construct declaration-derived
`signature-spec` rows by hand in `type.rkt`, and do not add another table.

The query never sorts or deduplicates:

1. Legacy instance fields precede methods.
2. Explicit-constructor instances have methods only.
3. User class constructors retain declaration order.
4. Protocol signatures retain declaration order.
5. Host methods retain interface declaration order.
6. Installed methods retain installation order.
7. Repeated method selectors remain separate overload rows.

`Mirror.messages` may continue deduplicating selector names by first
occurrence. Do not change it.

## Exact file scope

Implementation may edit only:

- `aloe/type.rkt`
- `tests/editor/signatures-of-type/002-declaration-query.rkt` (new)
- `tests/editor/signatures-of-type/001-kernel-query.rkt` only to remove the
  temporary deferred-family helper/test or replace those assertions with the
  now-final behavior

No change to `aloe/signature-catalog.rkt` should be necessary. If a shared
declaration converter is incorrect, stop and return the checkpoint for review
rather than silently redesigning the accepted 000 substrate.

Do not edit:

- `aloe/eval.rkt`, `aloe/parse.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/host.rkt`, or the runtime `Signature` representation
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- `gel/`, `lib/`, `host/`, or another editor project
- project design documents, prior checkpoint semantics, or a later checkpoint
  except status/index updates made by the checkpoint manager

If correct rows require changing dispatch, class/protocol declarations, host
identity, runtime type retention, or source type grammar, stop and return the
checkpoint for design review.

## Required tests

Add `tests/editor/signatures-of-type/002-declaration-query.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in
`require` and `define-runtime-path` paths.

Use exact `signature-spec` equality or extracted selector/parameter/return
triples, including row positions. Do not compare only selector sets or printed
strings. Use paired driver environments for static/runtime comparisons.

Cover at least:

1. A generic legacy class instance lists fields before methods, recursively
   substitutes a concrete class argument through direct, List, class, and
   function datums, preserves a method-local parameter, and retains overload
   multiplicity and order. Its class object has exactly one generic `new` row.
2. A generic explicit-constructor `Option` class object returns exactly
   `None`, then `Some`, with the specified payloads and `(Option T)` returns,
   matching its runtime class mirror. Its concrete instance returns methods
   only, with no `None`, `Some`, `new`, or payload-field row.
3. A unique method added to a user class with `define-methods` appears exactly
   once in the final appended position in both static and runtime rows.
   Querying before and after installation proves there is no cache. Production
   query code must not mention the test selector.
4. A protocol with multiple declared signatures and an overload preserves
   exact declaration rows. An empty marker protocol returns empty.
5. A concrete value flowing through a protocol-typed expression proves the
   protocol-erasure exception: the static query returns protocol rows while
   its runtime mirror remains the concrete class catalog.
6. A direct injected host receiver returns exact interface rows and matches
   its runtime mirror without any implementation call. Include all current
   crossing datum shapes needed here, including `(List String)`.
7. Two exact interfaces with the same display name are still distinct
   checker types. Use a same-name pair with different declarations to prove
   each query reads its carried interface, not a name registry; also confirm
   that equal declarations can yield equal row triples without adding
   identity to `signature-spec`.
8. A generic wrapper around an injected host receiver proves the named nested
   host exception: static rows retain the nominal host datum, runtime rows use
   today's `Object`/`?` spelling, and selector order/arity remain equal.
9. The temporary deferred-family error and its 001 test are gone. Invalid
   non-checker arguments still receive the deliberate 001 argument error, and
   all legitimate empty catalogs remain unchanged.
10. Direct sends, overload selection, construction, `case`, protocol
    dispatch, host guards, `Mirror.messages`, `Mirror.signatures`, and exact
    row invocation remain unchanged. Checkpoints 000 and 001 remain green.

Tests must obtain checker types through `type-of` and the same checker
environment used for the query. Host types must enter through normal driver
injection; do not construct or export private checker host types just for the
test.

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

After the automated tests, run this in a Racket REPL from the repository root:

```racket
(require "aloe/parse.rkt"
         (prefix-in type: "aloe/type.rkt"))

(define environment (type:make-type-environment))
(type:typecheck-program
 (list
  (parse-datum
   '(define-class (Pair T)
      (fields (left T) (right T))
      (methods
        (swap () (Pair T)
          (Pair new (self right) (self left)))))))
 environment)

(define pair-type
  (type:type-of (parse-datum '(Pair new 1 2)) environment))

(for/list ([row (in-list
                 (type:type-signature-specs pair-type environment))])
  (list (type:signature-spec-selector row)
        (type:signature-spec-parameters row)
        (type:signature-spec-return row)))
```

The exact result is:

```racket
'((left () Int)
  (right () Int)
  (swap () (Pair Int)))
```

Run:

```sh
raco test tests/editor/signatures-of-type/002-declaration-query.rkt
raco test tests/editor/signatures-of-type/000-shared-catalog.rkt
raco test tests/editor/signatures-of-type/001-kernel-query.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when every internal checker type accepted by the
public query has its specified final catalog, all ordinary parity cases and
three named exceptions are tested, the hand check succeeds, every focused
test passes, and no recursive-suite failure is introduced. Stop for review
without committing. Do not begin expression-query, LSP, or any other editor
project.

## Explicit non-goals

- No expression-level query, source/cursor lookup, parsing, CLI, LSP,
  JSON-RPC, VS Code, completion, or hover
- No Aloe syntax, type grammar, dispatch, overload, protocol, constructor,
  `case`, inference, or error-format change
- No evaluation or construction of Aloe `Signature` values by the static
  query
- No runtime reflection or runtime type-reification repair
- No source-written host interface name or host registry
- No variadic signature representation
- No runtime retention of inferred function types
- No caching or editor-private method table
- No hardcoded library, class, protocol, or host selector
- No Gel or Boids work
