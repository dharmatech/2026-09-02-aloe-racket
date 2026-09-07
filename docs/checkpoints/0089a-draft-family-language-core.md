# Checkpoint 0089A — Draft the unified family language core

Status: Proposed

Depends on: Checkpoint 0088

Supersedes in the active tree: the monolithic checkpoint-89 plan preserved in
Git commit `8b2c155`

## Goal

Create the first half of a non-normative candidate specification for Aloe's
approved unified nominal algebraic family design.

This checkpoint drafts only the language surface and static semantics:

- the unified family ontology;
- declarations, constructors, factories, and method surfaces;
- exhaustive receiver-anchored `case`;
- types, generic inference, and constructor refinements;
- direct regular recursion;
- multiple family-wide protocol conformances; and
- additive whole-family and factory extensions.

The candidate is preparation for later ratification. `SPEC.md` remains the
normative specification, and the runtime remains complete through checkpoint
88. Do not update the implementation roadmap or handoff yet.

## Authority and design source

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, and
`archive/unified-nominal-adts.md` completely. The archive is the approved but
non-normative design source through Decisions 1–10. Decisions 1–6 and 9 are
primary here; use only the static portions of Decision 10 needed for accuracy.

The discussion transcripts in Git commit `8e6955c` remain historical and
non-normative. Do not read or restore them unless the archive, current
specification, and repository leave a material semantic ambiguity. If that
happens, stop and report the exact ambiguity before consulting them or
inventing a rule.

The historical monolithic plan in commit `8b2c155` is background only. This
checkpoint, the archive, and the current normative specification are the
active contract.

## File scope and candidate status

Create exactly one implementation artifact:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, the archive,
historical checkpoints, Racket or Aloe files, fixtures, examples, or tests.

Begin the candidate with a prominent status block stating that it is
incomplete, non-normative, and authorizes no implementation change; that
`SPEC.md` remains law; that 89A covers only language surface and static
semantics; and that later 89-series checkpoints will complete, audit, and
atomically ratify or reject it.

Write cohesive specification prose with grammar, rules, examples, and
exclusions. Do not copy the archive's conversational decision structure or
make the candidate depend on the absent transcripts.

## Required candidate content

### 1. Preserved expression model

Retain Aloe's atoms, lexical lookup, and receiver-first send:

```text
(receiver-expr selector argument-expr ...)
```

The selector is literal and unevaluated. Function objects run only through
`call`; `(f x)` does not call `f`. Preserve `define`, `fn`, parallel `let`,
`if`, `cond`, `load`, `check`, and explicit `Int` to `Float` conversion.

Specify, without implementing, `(receiver case ...)` as exhaustive syntax and
a post-selector `(type Type ...)` as static send metadata. Give the exact
reservation scopes of `case`, `else`, `per-constructor`, and `type`. Do not add
application, constructor-call syntax, computed selectors, or another send rule.

### 2. Unified nominal ontology

One `define-family` introduces one opaque nominal family, one ordinary family
type object, and a finite nonempty ordered set of opaque representation
constructors. A one-constructor product and multi-constructor variant are the
same entity.

A family value records its family, resolved invariant generic arguments,
actual constructor, and immutable ordered payload. Constructors are not types,
subtypes, global bindings, or first-class functions. Names are source and
presentation labels, not identities.

Separate explicit whole-family messages from constructor-local methods and
payload accessors. Repeated local selectors do not become family messages.
Conformance belongs to the whole family. Constructor-set refinement is
internal checker knowledge, not source syntax or nominal identity.

### 3. Declarations and method surfaces

Give Decision 9's complete fixed-order grammar: optional nonempty `conforms`,
required nonempty `constructors`, optional `factories`, and optional
whole-family `methods`. Each constructor has a required `fields` section,
including `(fields)` when nullary, and may have local `methods`. Preserve the
current method-row grammar, including zero-argument and row-generic forms.

Specify all declaration invariants. Constructor selectors are unique,
non-overloaded, and reserved throughout their family. Payload names are unique;
payload accessors cannot collide with local methods; whole-family and local
selector partitions are disjoint; valid local overloads may share a selector;
and constructors are public.

There is no generated `new`. A product explicitly declares its sole
constructor, conventionally named `new`.

Constructor rows are bodyless, freshly polymorphic type-object rows returning
their owning family singleton-refined to that constructor. Factories are
ordinary, possibly overloaded type-object methods; their `self` is the family
type object, and callers see only their declared unrefined result.

Each whole-family overload has either one uniform expression body or one
complete `per-constructor` body table. Uniform `self` is unrefined except for
an inherently singleton family; table bodies receive singleton-refined `self`.
There is no default-plus-override mode, and local methods and factories cannot
use `per-constructor`.

### 4. Exhaustive `case`

Give the exact flat grammar from Decision 9 for explicit constructor clauses,
optional refined whole-value binders, payload binders, and final `else` with an
optional residual whole-value binder.

Specify once-only scrutinee evaluation, lazy single-branch evaluation, literal
labels resolved within the scrutinee family, exact payload arity, and
opaque-identity runtime selection.

Case requires a concrete family and possible-constructor set `S`. Without
`else`, explicit clauses equal `S`. Reject missing, duplicate, unknown, and
impossible constructors, wrong binders, misplaced or empty-residual defaults,
and incompatible results. Report missing constructors in declaration order.
A constructor named `Other` is unrelated to `else`; choosing `else` explicitly
opts that consumer out of future missing-constructor diagnostics.

With an expected result, check every branch against it. Otherwise use a
symmetric, branch-order-independent join. Same-family results unify invariant
arguments and union only outer refinements; unrelated conforming families do
not infer a protocol result.

Exclude nested patterns, guards, alternatives, fallthrough, wildcard payload
patterns, and partial case analysis.

### 5. Types, generics, and refinements

Use a general source grammar for primitives, `List`, arrows, nominal family
applications, protocol names, and bound type variables. Constructor names,
constructor sets, and host interface names are not source types.

Family parameters are invariant. Construction constraints may come from a
complete explicit type header, an expected exact family, payload arguments,
and the enclosing expression, including sibling branches. An expected protocol
alone does not identify a family instantiation.

For type-object sends, an explicit header supplies all family parameters then
all row-local parameters. For instance sends, family arguments are fixed and
the header supplies all row-local parameters. There are no partial headers.
Inference variables may exist temporarily but cannot escape a checking-unit
boundary; a context-free generic nullary constructor therefore fails.

Specify shallow refinement introduction, intersection, subtraction, union,
and widening. Direct construction, case branches, per-constructor bodies, and
immutable direct aliases may preserve outer refinement. Protocol conversion,
declared results, general function boundaries, generic storage, family-typed
payloads, source annotations, and reflective unwrapping forget it. Runtime
`let` retains its established `fn`/`call` behavior.

### 6. Direct regular recursion

Register the current family and its constructors before resolving payloads.
Recursive occurrences use the same parameters at full arity and in the same
order, including beneath ordinary container or function types. Previously
declared families remain available.

Reject nonregular or polymorphic recursion, reordered parameters, mutual
recursion, and unresolved forward families. Do not add positivity,
termination, GADT, existential, or full inductive-type claims.

### 7. Protocols and additive extensions

Specify zero or more family-wide conformances through `(conforms P ...)`.
Conformance is nominal, uniform across generic instantiations, and satisfied by
whole-family rows only. Parameters cover the protocol domain; results may be
more specific only when usable as the protocol result. Narrower overloads obey
return coherence. Required rows may be supplied by allowed extensions before
the complete source unit is finalized. One row may satisfy identical
requirements from several protocols; incompatible obligations at the same
parameter shape are rejected.

Protocol widening allocates no wrapper, forgets refinement, and exposes only
protocol rows. Keep protocols non-generic and without inheritance,
intersections, defaults, conditional or structural conformance,
per-constructor conformance, or retroactive orphan claims.

Extend `define-methods` with optional factories followed by optional uniform
whole-family methods, requiring at least one section. Extensions cannot add
constructors, payloads, locals, per-constructor tables, conformances, or
replacement rows. Stage and commit all proposed rows atomically after checking
their combined coherence.

## Examples, audit, and pending boundary

Include concise family-syntax examples for `Point`, `Option`, `Result`, and
`Tree`. They are specification examples, not runnable 89A goldens. Preserve
receiver-first sends, explicit `call`, and explicit numeric conversion.

Audit these sections against the corresponding archive decisions and current
`SPEC.md`. Deliberately reconcile `define-class`, generated `new`, one
positional protocol, class fields, generic construction, and the current type
grammar. Preserve unaffected language behavior without carrying contradictory
class rules into the candidate.

End with a marked “Pending completion” section reserving linked checking and
elaboration, runtime representation and dispatch, equality, raw printing,
reflection, built-ins, typed host capabilities, complete diagnostics and
exclusions, and the final reconciliation audit. Do not draft those subjects.

## Validation and acceptance

Before review:

- confirm the candidate is the only implementation artifact added;
- confirm `SPEC.md` and every runtime or application file are unchanged;
- confirm the candidate never presents itself as implemented or normative;
- confirm all seven content areas and the pending boundary are present;
- inspect grammar and examples for accidental application or unapproved syntax;
- run `git diff --check`, `git status --short`, and `git diff --name-only`; and
- run the established full suite and one current-syntax checkpoint-88 hand
  check without changing tests.

If sandboxed Racket cannot write its default temporary directory, use a
writable temporary directory and report that environment adjustment separately.

Accept 89A only when `docs/unified-nominal-adts-spec-candidate.md` is cohesive,
self-contained for this slice, explicitly incomplete and non-normative, and
contains no silently invented material choice. `SPEC.md`, `CHECKPOINTS.md`,
`docs/handoff.md`, the archive, implementation, applications, fixtures, and
tests must remain unchanged, with the suite, hand check, and documentation
checks green.

Stop for review without committing. Do not design or write checkpoint 89B,
complete the pending candidate sections, or begin checkpoint 90.

## Explicit non-goals

- Do not ratify or replace `SPEC.md`.
- Do not update the implementation sequence or durable handoff.
- Do not implement any family syntax or semantic rule.
- Do not change parsing, checking, elaboration, evaluation, runtime identity,
  equality, printing, reflection, host behavior, or applications.
- Do not create detailed checkpoints 89B–89D or 90–106.
- Do not rewrite built-ins, design filesystem capabilities, broaden host
  crossings, or add compatibility behavior.
- Do not edit, restore, or delete the consolidated archive or transcripts.
