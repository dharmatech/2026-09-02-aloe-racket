# Checkpoint 0089D — Draft built-in and typed host integration

Status: Proposed

Depends on: Checkpoint 0089C

## Goal

Extend the non-normative unified-family specification candidate with the
integration contract for specialized built-ins and typed host capabilities.

This is one documentation slice: explain how existing specialized values
participate in the proposed checked execution, type, equality, and reflection
model while preserving their established public behavior and the sealed host
boundary. The family design does not require rewriting built-ins as Aloe
families or turning opaque capabilities into algebraic representations.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
and runtime behavior remains exactly as implemented through checkpoint 88.
The complete diagnostic, exclusion, and validation catalogue, final design
audit, implementation roadmap, durable handoff, and atomic ratification remain
later 89-series work.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, checkpoints 89A–89C,
`docs/unified-nominal-adts-spec-candidate.md`, and
`archive/unified-nominal-adts.md` completely before editing.

The accepted candidate through 89C is the base. The built-in and host portions
of Decisions 1, 7, 8, and 10 govern this slice. In particular, use Decision 7's
opaque-leaf, runtime-type, and specialized-value rules and Decision 10's
adapter and guarded-host-boundary requirements. Preserve 89A's expression,
generic, and refinement rules, 89B's checked execution and value model, and
89C's exact reflection contract.

`SPEC.md` sections 4–7 and 13 supply the preserved function, collection,
primitive, and typed-host behavior. Read the accepted host-boundary record in
`docs/checkpoints/0088-seal-typed-host-boundary.md` and the relevant current
parts of `docs/handoff.md` and `docs/gel.md`. Inspect `lib/list.aloe`, the
driver, built-in and host implementation, and relevant tests as needed to
verify preservation claims. Do not promote an incidental internal structure
or an implementation limitation into a new language rule.

The transcripts in Git commit `8e6955c` and historical monolithic plan in
commit `8b2c155` remain non-normative. If the archive, candidate, current
specification, and repository leave a material semantic ambiguity or
contradiction, stop and report the exact issue before consulting transcripts
or inventing a rule.

## File scope and candidate status

Edit exactly one implementation artifact:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, `docs/gel.md`,
the archive, checkpoint documents, source, tests, fixtures, examples, or
applications.

Keep the prominent incomplete, non-normative status. Update its scope to
include 89D's specialized built-in and typed host integration alongside
89A–89C. The candidate must continue to authorize no runtime, source-language,
library, application, or compatibility change before later ratification.

Write cohesive specification prose with a compact value-kind table and
illustrative observations. Integrate with existing sections, repair numbering
and cross-references as needed, and preserve accepted rules. Specify semantic
obligations, not adapter algorithms, public Racket structure layouts, or a
component-by-component implementation plan.

## Required candidate additions

### 1. Specialized values within the family design

State that one `define-family` ontology governs user-defined nominal data.
Existing primitives, functions, collections, reflection values, and host
capabilities may retain specialized implementations. Internal adapters connect
them to common type and reflection relations where necessary; specialization
does not introduce another meaning for a list or another send rule.

Give a compact table covering at least:

| Value kind | Preserved boundary |
| --- | --- |
| `Int`, `Float`, and `String` | Existing scalar values and messages; numeric types remain distinct. |
| `Bool` | Existing Boolean values and lazy `if` behavior through function objects. |
| Functions | Arrow types and execution through `call`; closure representation remains opaque. |
| `List` | Homogeneous invariant element typing, immutable collection operations, and existing Aloe-defined methods. |
| `Symbol` | Interned names with the existing `intern`, `name`, and `=` messages. |
| `Mirror` and `Signature` | The explicit reflection boundary specified by 89C. |
| Host capabilities | Explicitly injected opaque nominal receivers with guarded declared operations. |

Do not invent representation constructors or payload schemas for these kinds.
Possible future algebraic descriptions for `Bool` or `List` remain optional,
not unfinished prerequisites of the family model. Having a built-in adapter
does not by itself make a value eligible for family `case`, create constructor
refinements, or publish a new constructor inventory.

Preserve existing expression receivers such as `List`, `Symbol`, and `Mirror`
without assuming every primitive type name is a bound type-object value.
Do not generate `new` for built-ins, expose a `Signature` constructor, add
protocol conformance claims, or generalize extension rights to every
specialized receiver. `Option` and `Result` remain ordinary user families in
the proposed design, not magical built-ins.

### 2. Preserved operations and library composition

Summarize the relevant established behavior without duplicating the complete
built-in API or redesigning it:

- Numeric operations preserve exact `Int`/`Float` separation, existing result
  types, and explicit `(n float)` conversion.
- `Bool.if` invokes exactly one of its two zero-argument function objects;
  `if`, `cond`, `fn`/`call`, and parallel `let` retain their defined behavior.
- `(List of ...)`, `(List empty)`, `empty?`, `first`, `rest`, `cons`, and
  `len` retain their collection meanings, including errors for `first` and
  `rest` on an empty list. `List of` retains its variadic construction shape.
- `fold`, `reverse`, and `map` remain Aloe methods in `lib/list.aloe`; callbacks
  execute through `call`.
- Interning does not change expression-symbol lookup, literal selectors, or
  grant dynamic invocation authority.

Explicitly reconcile the candidate's family extension grammar with the
preserved `(define-methods List (methods ...))` route. Its element parameter
`T` remains in scope, and method-local parameters retain their ordinary
meaning. Keeping this existing built-in receiver extension does not require a
source-defined `List` family or authorize new built-in factories, constructors,
local tables, or conformance declarations.

Keep `List` homogeneous and invariant. Storing family values retains their
base element type, not nested constructor refinements. Forgetting that checker
knowledge does not erase an element's actual family, resolved type arguments,
constructor, or payload. Contextual empty-list typing must remain consistent
with 89A/89B's inference-closure rules; do not add an exception that permits
unresolved variables to escape or reconstructs missing generic arguments from
runtime elements.

Reflection's existing `Symbol`/`List` type-description data does not establish
a general heterogeneous collection type or add a source-written `TypeData`,
`Any`, or `Object` type. Preserve 89C's descriptive-data boundary.

### 3. Common checked and runtime obligations

Connect specialized kinds to the candidate's existing checked-program and
descriptor model. One consistent runtime type relation covers primitives,
functions, lists, exact family instantiations, protocols, and host-interface
identities. Specialized cases within that relation are permitted; independent
name-based substitutes for it are not.

The checker, direct sends, reflective invocation, argument acceptance, and
boundary validation must agree on the relevant types and exact owners.
Preserve the existing function and collection typing rules rather than
inventing a new subtyping or variance system. Descriptive symbols, equal
layouts, or matching method names never supply nominal compatibility.

Checked execution must retain the static information needed by specialized
operations under 89B's rules. Adapters do not authorize runtime reconstruction
of missing family arguments, unchecked evaluation of parsed source, or a
second elaboration path with weaker guarantees.

Use 89C's existing primitive/host callable surfaces and `operation` role for
rows outside algebraic family/type-object surfaces. Preserve exact-row
ownership and guarded invocation. Do not duplicate the reflection section,
invent additional metadata queries, or require built-ins to reveal their
physical representation to participate.

Retain 89B's kernel equality and display distinctions. Scalars and algebraic
values keep their established value semantics; functions, type objects, host
capabilities, and other identity-bearing opaque leaves follow the already
specified identity rules. Do not compare host state structurally, deep-freeze
opaque leaves, add universal `=` messages, or make raw printing invoke Aloe
methods. Adapter details remain internal.

### 4. Host declarations and the scalar crossing boundary

Restate the accepted typed-host contract as part of the candidate's integration
model. A Racket-created receiver holds an opaque nominal `host-interface` and
private state. One interface descriptor owns ordered `host-method`
declarations with unique selectors. Each declaration supplies the selector,
fixed parameter types, result type, and Racket implementation used by checking,
dispatch, and reflection.

Preserve the exact implementation call shape: one private state argument
followed by the declared positional arguments, with no optional, variadic, or
keyword shape. The private state is not an extra Aloe argument or an exposed
payload. User-family overloading does not introduce host overloads.

The complete method-argument and method-result crossing vocabulary remains
`Int`, `Bool`, and `String`. Arguments are validated before the implementation
runs, and results before entering Aloe. Strings are normalized to immutable
values in both directions. Implementation failures retain consistent Aloe
host-failure context and their original Racket cause; breaks pass through.

Using one central type relation does not admit every Aloe type at a host
crossing. In particular, this design adds no `Float`, collection, family,
function/callback, reflection value, or opaque handle to that vocabulary.
Explicit capability injection is distinct from returning a capability as a
host-method result. No family marshalling or general FFI is introduced.

### 5. Injection, nominal ownership, and opaque composition

An optional capability enters Aloe only through explicit driver injection.
Preflight both runtime and checker environments and install the receiver and
its type as one logical operation without overwriting an existing binding.
The checker and runtime refer to the same exact interface identity, not
separately manufactured descriptors that happen to share a name.

Interface names remain diagnostic labels, not source-written host types.
Keep them out of annotations and explicit send type headers. Possessing an
injected value permits the existing typed use of that value; its printed name
does not grant authority. Default environments contain no optional capability.

Host reflection derives messages, signatures, type descriptions, and ownership
from that same descriptor and uses the ordinary guarded exact-row boundary.
A signature can target another receiver of the same exact interface, using
that receiver's state. A same-named distinct interface is incompatible. Refer
to 89C for the full reflection contract rather than specifying it again.

Where ordinary typing permits a family payload to contain a capability or
function, that leaf stays opaque. The family fixes the payload position but
does not freeze external state or reveal the leaf's representation. Carrying
such a value inside Aloe data does not expand the host crossing vocabulary,
make the capability an algebraic constructor, or expose host state through
`case` or a mirror.

Preserve the guarded public host declaration and driver-injection boundary
sealed at checkpoint 88. Internal descriptors may be adapted to the linked
program image; adaptation must not bypass the guards or expose raw host state
or arbitrary Racket procedures to Aloe. Do not require a new registry, loader,
capability declaration form, ownership/lifetime system, or Racket API redesign.

Static failures obey 89B's transaction rules and prevent evaluation. Host
effects after successful checking are not rolled back. Keep that distinction
separate from atomic injection and its preflight guarantees.

### 6. Existing Term and application boundaries

Record Term as the existing production example, with exactly:

```text
read-key   : () -> String
write-line : (String) -> String
```

`write-line` writes its string and CRLF, flushes output, then returns the string.
Both optional terminal runners explicitly inject Term into a checked driver;
ordinary Aloe startup, Boids, and MPL remain free of optional Term authority
and terminal dependencies. Preserve the current host/application division:
Racket supplies host facts and effects, and Aloe owns domain policy and
composition, including Gel's key handling and state transitions.

This is a preservation example, not a new terminal specification. Do not
redesign key mapping, expose `tui-term` as an Aloe API, specify filesystem
capabilities, or migrate Gel state in this slice.

## Illustrations, reconciliation, and pending boundary

Add a compact set of examples or prose observations establishing:

- same-type numeric sends and explicit conversion remain valid, while mixed
  `Int`/`Float` arithmetic is rejected;
- a `List` of family values retains base element typing and supports the
  existing Aloe collection methods without storing constructor refinements;
- contextual empty-list typing and ordinary function calls obey the accepted
  checking rules;
- separate same-named host interfaces do not share signature authority,
  whereas receivers of the same exact interface use their own target state;
- invalid crossing arguments are rejected before the host implementation, and
  invalid results are rejected on return; and
- an opaque leaf inside family data remains opaque and does not enlarge the
  host method vocabulary.

Mark proposed family examples as illustrative rather than executable 89D
goldens. Use prose where code would require an unapproved host annotation,
marshalling operation, constructor schema, or new API. Do not add fixtures or
tests for unimplemented syntax.

Audit this slice against the archive, the current host contract, and 89A–89C.
Reconcile references that still reserve all built-in and typed host integration
for later work, including the central type-relation and reflection sections.
Preserve the distinction between completing their integration contract now and
leaving optional built-in algebraic rewrites deferred.

Update `Pending completion` to mark the boundary after 89D and reserve:

- the complete diagnostic, exclusion, and validation catalogue;
- the final whole-candidate Decision 1–10 audit;
- the implementation roadmap and durable handoff; and
- atomic ratification into `SPEC.md`.

Integration-specific exclusions and failures belong here; the full language
catalogue, application validation plan, and final audit do not. Do not draft
later checkpoints or present the candidate as ready for implementation.

## Validation and acceptance

Before review:

- confirm only `docs/unified-nominal-adts-spec-candidate.md` changed in this
  implementation slice, with governing documents, checkpoint documents,
  production code, libraries, applications, fixtures, and tests unchanged;
- confirm the candidate remains incomplete, non-normative, and unimplemented;
- verify all six required content areas, the illustrations, cross-references,
  preserved `define-methods List` route, and revised pending boundary;
- check for invented built-in constructors or `case` eligibility, new primitive
  type-object bindings, broadened host crossings, source-written host types,
  name-based ownership, unguarded invocation, and runtime generic fallback;
- run `git diff --check`, `git status --short`, and `git diff --name-only`; and
- run the established full regression suite (`raco test tests`) and the
  existing checkpoint-88 hand check without changing tests.

The hand check is the public driver/Term example under `Hand check` in
`docs/checkpoints/0088-seal-typed-host-boundary.md`. Its result remains
`'("sealed" "sealed\r\n")`. It uses an in-memory output port and requires no
physical terminal interaction. These checks validate the unchanged baseline,
not execution of the candidate's future integration model.

If Racket's default temporary directory is unwritable in the sandbox, use a
fresh writable temporary directory and report that environment adjustment
separately.

Accept 89D only when the integration contract is cohesive, self-contained for
this slice, consistent with the approved design and sealed host boundary, and
contains no invented material semantic choice. Required documentation checks,
the unchanged suite, and the existing hand check must be green.

Stop for review without committing. Do not implement adapters, complete another
pending subject, create the next checkpoint, ratify the candidate, or begin
checkpoint 90.

## Explicit non-goals

- Do not change normative or status documents, the archive, or transcripts.
- Do not change built-in, parser, checker, elaborator, evaluator, driver, host,
  reflection, library, application, fixture, or test behavior.
- Do not add built-in family declarations, constructor inventories, protocol
  claims, factories, new extension targets, or a legacy compatibility bridge.
- Do not add host crossing types, source-written host types, opaque handles,
  callbacks, family marshalling, arbitrary Racket access, or ambient authority.
- Do not redesign Term, Gel, filesystem access, or capability lifetimes.
- Do not write the complete validation catalogue, final audit, roadmap,
  handoff, ratification text, or detailed later checkpoint documents.
