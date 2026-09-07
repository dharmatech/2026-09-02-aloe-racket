# Checkpoint 0089B — Draft the checked family execution model

Status: Proposed

Depends on: Checkpoint 0089A

## Goal

Extend the non-normative unified-family specification candidate with the
approved checked-execution and runtime-value model.

This checkpoint covers only:

- linked checking and elaboration;
- shared nominal descriptors and transactional finalization;
- runtime family values, type checks, and dispatch; and
- kernel equality and structural printing.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
and runtime behavior remains exactly as implemented through checkpoint 88.
Reflection, specialized built-ins, typed host integration, the complete
diagnostic and exclusion catalogue, the roadmap, the durable handoff, and
ratification remain later 89-series work.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, checkpoint 89A,
`docs/unified-nominal-adts-spec-candidate.md`, and
`archive/unified-nominal-adts.md` completely before editing.

The accepted 89A candidate is the base of this change. Decision 7 and the
checked-program, descriptor, linking, finalization, runtime, equality, printing,
compatibility, and transaction portions of Decision 10 govern the new material.
Use Decisions 1–6 and 9 to check consistency with the existing candidate and
exact raw spelling.

The transcripts in Git commit `8e6955c` and the historical monolithic plan in
commit `8b2c155` are non-normative. Do not consult the transcripts unless the
candidate, archive, current specification, and repository leave a material
contradiction. Report that contradiction before consulting them or inventing a
semantic rule.

## File scope and candidate status

Edit exactly one implementation artifact:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, the archive,
checkpoint documents, source, tests, fixtures, examples, or applications.

Keep the prominent “incomplete and non-normative” status. Update its scope
sentence to say that checkpoints 89A and 89B cover the proposed language/static
model and checked runtime model, while later work must complete and audit the
remaining subjects before atomic ratification. It must continue to authorize
no implementation change.

Replace the current `Pending completion` list only after the new sections are
written. Its revised list must reserve every subject still deferred by this
checkpoint.

## Required candidate additions

### 1. Checked program and elaboration boundary

Specify this required pipeline:

```text
source
  -> parsed source AST
  -> linked nominal declarations and opaque identities
  -> type checking and elaboration
  -> globally validated checked program
  -> evaluation
```

The checked program carries all runtime-relevant static decisions: resolved
family, constructor, protocol, and dispatch-row identities; resolved send type
arguments; and resolved case-clause constructors. Constructor refinements used
only during checking need not become runtime fields.

Only a successfully checked and finalized unit is evaluated. Production
evaluation cannot accept unresolved construction semantics or infer generic
arguments from runtime payloads. Public source-checking and evaluation helpers
may retain their broad roles, but evaluation helpers and drivers evaluate
checked programs; a type-only caller may discard the elaboration.

No unresolved inference variable survives a top-level expression or
definition, method or factory body, explicitly typed function body, or complete
program transaction. Ordinary type presentation exposes the base family type,
not its internal constructor set.

Source `let`, or equivalent provenance, remains available through checking so
an immutable direct alias can preserve outer refinement. Runtime `let` keeps
its existing `fn`/`call` definition.

### 2. Shared nominal descriptors

Specify one linked program-image graph with opaque protocol, family,
constructor, and dispatch-row identities shared by checking, evaluation,
conformance, runtime validation, equality, printing, and later reflection.
Descriptors are implementation metadata, not Aloe-visible objects.

A family descriptor owns its name, parameters, conformances, ordered
constructors, factories, and whole-family rows. A constructor descriptor owns
its exact family, selector label, ordered payload declarations, local rows, and
declaration position. A row descriptor owns its selector, generic parameters,
parameter and result types, semantic role, body mode, and exact identity.

The candidate specifies semantic contents and shared identity, not public
Racket structs or physical layout. The implementation may optimize these
representations without changing observations.

### 3. Linking, finalization, and transactions

Give the three family-linking phases:

1. bind the family, mint its identity and type object, bind its parameters, and
   register every constructor identity;
2. resolve payloads, accessors, local/factory/family signatures, and
   conformance names; and
3. install all signatures before checking local, uniform, per-constructor, and
   factory bodies under their specified `self` views.

The first phase permits direct regular self-reference. The second enforces the
declaration and selector invariants already specified by 89A. The third permits
rows in one declaration to call one another.

After a complete source unit and its transitive loads are checked, finalization
validates every conformance, complete per-constructor table, overload set,
return-coherence obligation, selector partition, extension owner, and
unresolved inference variable. Rows supplied by later allowed extensions in
the same source unit participate.

A loaded unit is one staging transaction: link, check, finalize, commit static
descriptors, then evaluate. A REPL datum is its own smaller transaction. A
static failure does not partially mutate a live checker environment or begin
evaluation. Runtime effects after successful checking are not rolled back.

Retain the 89A rule that one extension stages and commits all its proposed rows
atomically. Do not duplicate or weaken that rule in this section.

### 4. Runtime family values and dispatch

Specify the semantic value as:

```text
<family identity, resolved type arguments, constructor identity, payloads>
```

There is one family type object per declaration, not per generic instantiation.
A value contains data rather than method tables, closures, protocol wrappers,
or factory provenance. Family, type arguments, constructor, and payload
positions are fixed at creation.

Opaque nominal identity is guaranteed within one linked program image. The
candidate promises no stable identity across executions, recompilation,
serialization, or a future reloading system.

Immutability is shallow. Functions and identity-bearing host capabilities may
remain opaque stateful leaves, but the family cannot replace them. Ordinary
family values expose no allocation identity; equivalent family data may be
shared, copied, interned, or separately allocated. Constructor refinement is
therefore stable. Ordinary immutable construction produces finite, acyclic
family data; opaque functions and capabilities are leaves for that purpose.

After overload selection, dispatch follows the disjoint surfaces established
by 89A:

- a family type object consults constructor and factory rows;
- a whole-family send uses the selected family row and its uniform or
  actual-constructor-indexed body; and
- an authorized local send uses the actual constructor's local table.

Protocol conversion and refinement widening do not wrap, copy, or alter a
value. A statically broader protocol call may retain Aloe's concrete runtime
overload selection, subject to the specified return-coherence rule.

### 5. Central runtime type relation and constructor integrity

Define one nominal relation for every dynamic boundary. An expected concrete
family requires exact family identity and invariant resolved arguments. A
refined expectation additionally requires the actual constructor to belong to
the permitted set. An expected protocol requires explicit conformance to the
exact protocol identity; constructor identity is irrelevant there.

Names, reified type data, printed output, equal layouts, and similarly named
messages never establish type compatibility. Apply the same relation to
constructor payloads, factory results, dynamic overload arguments and results,
later reflective invocation, and host crossings.

Defensive construction or injection rejects a constructor owned by another
family, wrong payload arity, a payload failing its substituted declared type,
or unresolved generic arguments at the boundary that introduced the value.
Case evaluation may rely on these invariants and reject malformed foreign data
instead of routing it through `else`.

### 6. Kernel equality

Kernel equality used by `check` compares exact family identity, resolved
generic arguments, constructor identity, and recursively kernel-equal payloads.
Separately allocated equal `Point` or `Some` values compare equal; same-shaped
values from distinct family declarations do not; and `None` at different
generic instantiations does not.

Scalar and algebraic leaves retain value equality. Functions, type objects,
host capabilities, and other identity-bearing leaves use established opaque
identity unless their built-in kind already defines value semantics.

Kernel equality is total and non-overridable. A family or protocol `=` row is
an ordinary domain message and does not redefine `check` or trusted runtime
comparison.

### 7. Raw and user-facing display

Specify the exact concise raw forms:

```text
#<Point 1 2>
#<Option.None>
#<Option.Some 1>
#<Tree.Branch #<Tree.Leaf 1> #<Tree.Leaf 2>>
```

A one-constructor family omits the redundant constructor label. A
multi-constructor family uses `Family.Constructor`; payloads follow declaration
order. Names are presentation labels only.

Raw rendering never invokes Aloe methods and is neither source nor a
serialization format. Type-aware diagnostics show exact generic instantiation
separately when necessary, especially for parameterless constructors. Display
limits may elide presentation only, never equality or behavior.

Normal interactive display may use an applicable whole-family, zero-argument
`show` returning `String`; otherwise it falls back to structural display. The
raw path remains independently available even when `show` fails or recurses.

### 8. Compatibility boundary for later implementation

State that the completed language rejects `define-class`, positional
conformance, family-level fields, generated `new`, and permanent class/family
aliases. All user nominal source ultimately uses `define-family`.

A temporary legacy declaration may later lower internally to a one-constructor
`new` family solely to keep the historical suite green during migration. This
is implementation sequencing, not normative syntax, and must have an explicit
removal checkpoint. Checkpoint 89B does not add or authorize that bridge.

## Reconciliation and pending boundary

Integrate the new material into the candidate as cohesive specification
sections rather than copying Decision 7 or 10 as a design log. Preserve 89A's
accepted rules except for necessary corrections or cross-references.

Audit the whole candidate for contradictions involving nominal identity,
invariant arguments, refinement erasure, factory results, protocol widening,
case dispatch, extension atomicity, generated `new`, or runtime inference.
Every remaining use of “class” must be deliberate historical or compatibility
language, not a parallel ontology.

Replace `Pending completion` with a new marked list reserving:

- family-aware reflection and exact signature behavior;
- specialized built-ins and typed host-capability integration;
- the complete diagnostic, exclusion, and validation catalogue;
- the final whole-candidate Decision 1–10 audit;
- the implementation roadmap and durable handoff; and
- atomic ratification into `SPEC.md`.

Do not draft those subjects or present the candidate as semantically complete.

## Validation and acceptance

Before review:

- confirm only `docs/unified-nominal-adts-spec-candidate.md` changed;
- confirm `SPEC.md`, the archive, checkpoint documents, production code,
  applications, fixtures, and tests are unchanged;
- confirm the status remains incomplete, non-normative, and unimplemented;
- confirm all eight required additions are present and the revised pending
  boundary is accurate;
- search for name-based identity, runtime generic reconstruction, reference
  equality for family data, user-overridable kernel equality, `show`-driven raw
  output, or a permanent legacy alias;
- run `git diff --check`, `git status --short`, and `git diff --name-only`; and
- run the full suite plus one existing checkpoint-88 hand check without
  changing tests.

If Racket's default temporary directory is unwritable in the sandbox, use a
fresh writable temporary directory and report that adjustment separately.

Accept 89B only when the candidate's checked-execution and runtime-value model
is cohesive, self-contained for this slice, consistent with 89A and the
approved archive, explicitly incomplete, and contains no invented material
choice. All behavioral regression and documentation checks must be green.

Stop for review without committing. Do not design or write the next 89-series
checkpoint, complete the remaining candidate sections, update normative or
status documents, implement candidate behavior, or begin checkpoint 90.

## Explicit non-goals

- Do not ratify, replace, or append to `SPEC.md`.
- Do not update `CHECKPOINTS.md` or `docs/handoff.md`.
- Do not specify reflection, built-in adaptation, host integration, or the
  final diagnostic and exclusion catalogue in this slice.
- Do not change parser, AST, checker, evaluator, driver, runtime, equality,
  printer, reflection, host, library, application, fixture, or test behavior.
- Do not add the temporary legacy bridge or any implementation scaffold.
- Do not create a later detailed checkpoint document.
- Do not edit or restore the archived design or transcripts.
