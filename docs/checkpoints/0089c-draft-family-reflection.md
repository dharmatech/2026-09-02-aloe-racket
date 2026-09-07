# Checkpoint 0089C — Draft family-aware reflection

Status: Proposed

Depends on: Checkpoint 0089B

## Goal

Extend the non-normative unified-family specification candidate with the
approved reflection contract for nominal families and exact signatures.

This is one documentation slice: describe which public rows a mirror exposes,
what a signature describes and authorizes, and how reflective invocation
preserves nominal ownership without bypassing exhaustive case analysis.
Checkpoint 89A supplies the language and static model; 89B supplies the checked
execution model, shared identities, and central runtime type relation.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
and runtime behavior remains exactly as implemented through checkpoint 88.
Built-in and host adaptation, the complete diagnostic and validation
catalogue, the final design audit, the roadmap, the durable handoff, and
ratification remain later 89-series work.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, checkpoints 89A and 89B,
`docs/unified-nominal-adts-spec-candidate.md`, and
`archive/unified-nominal-adts.md` completely before editing.

The accepted candidate through 89B is the base. Decision 8 is the primary
design source for this slice. Decision 9 supplies the reflection selector
spellings and result types; Decision 10 supplies the shared-row-descriptor and
checked-execution requirements. Use Decisions 1–7 and the existing candidate
to preserve construction, refinement, protocol, equality, and display rules.

Read the current reflection and typed-host sections of `SPEC.md` and the
relevant parts of `docs/gel.md`. Inspect the existing reflection implementation
and tests as needed to understand preserved behavior. Current implementation
details, including integer row indices, do not override the approved design.

The transcripts in Git commit `8e6955c` and the historical monolithic plan in
commit `8b2c155` are non-normative. Do not consult the transcripts unless the
archive, candidate, current specification, and repository leave a material
semantic ambiguity or contradiction. If they do, stop and report the exact
issue before consulting transcripts or inventing a rule.

## File scope and candidate status

Edit exactly one implementation artifact:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, `docs/gel.md`,
the archive, checkpoint documents, source, tests, fixtures, examples, or
applications.

Keep the prominent incomplete, non-normative status. Update its scope to say
that 89A–89C cover the proposed language/static model, checked execution and
runtime-value model, and family-aware reflection. It must continue to authorize
no implementation or compatibility change and to reserve completion, audit,
and atomic ratification for later work.

Write cohesive specification prose, a callable-surface table, and concise
examples. Integrate with the candidate rather than copying the archive's
decision-log structure. Renumber sections and repair cross-references where
needed; preserve accepted 89A/89B rules except for necessary reconciliation.

## Required candidate additions

### 1. Mirror boundary and dynamic receiver view

Preserve the existing public vocabulary and describe each operation's role:

```aloe
(Mirror of value)
(mirror messages)
(mirror signatures)
(mirror invoke signature argument ...)
(mirror subject)
(mirror raw)

(signature selector)
(signature params)
(signature return)
(signature accepts? candidate-mirror)
```

`messages` returns unique callable selectors as `(List Symbol)`;
`signatures` returns one opaque `Signature` per public overload row. Reflection
operations remain on `Mirror` and `Signature`, not on every ordinary value.
Selectors and reified type data describe operations; the opaque signature
grants exact-row invocation authority.

A mirror describes the actual runtime nominal receiver, including when the
source value was viewed through a protocol. It neither retains the original
static view nor captures a constructor refinement. Asking an existing mirror
for signatures describes its subject; `(Mirror of mirror)` explicitly
reflects the `Mirror` value itself.

`subject` returns the original ordinary value under the existing contextual
typing and runtime-checking rule. It does not recover an earlier singleton
refinement. A concrete family expectation permits subsequent ordinary
exhaustive case analysis. Preserve inference closure from 89B; do not turn
unwrapping into an unchecked cast or a source-level refinement annotation.

### 2. Callable surfaces and closed instance representation

Specify this subject-dependent surface:

| Mirrored subject | Callable rows |
| --- | --- |
| Multi-constructor family instance | Whole-family rows only |
| One-constructor family instance | Whole-family rows, sole-constructor local rows, and payload accessors |
| Family type object | Representation constructors and factories |
| Primitive value or type object | Its existing public primitive rows |
| Host capability | Rows declared by its exact host interface |
| A `Mirror` value | The reflection API of `Mirror` |

For a multi-constructor instance, exclude constructor-local rows and payload
accessors when forming both `messages` and `signatures`. Do not expose them and
merely reject invocation later. Constructing a mirror inside a refined branch
does not change this surface or create an escaping refinement certificate.

A multi-constructor instance mirror must not expose its current constructor
identity or authoritative tag, constructor predicates, payload values, indexed
payload access, constructor refinements, opaque nominal identity tokens,
conformance lists, method bodies, dispatch tables, source locations, or closure
representation.

The type object instead exposes the complete public construction schema:
constructor selectors, ordered payload types, family result types, generics,
and constructor/factory roles. Payload position names do not become reflective
data, and there is no separate first-class `Constructor` token.

Whole-family overloads with `per-constructor` bodies contribute one signature
per overload, not one per implementation body. The `case` form is syntax and
never appears in reflected messages or signatures.

### 3. Signature metadata and descriptive type data

Add the exact proposed queries:

```text
(signature role)        : Symbol
(signature type-params) : (List Symbol)
```

`role` returns an interned symbol named `constructor`, `factory`, `family`,
`local`, or `operation`. Explain each role. Primitive, reflection, and host
rows outside algebraic family/type-object surfaces use `operation`.

Describe generic constructor parameters from the family declaration. For an
instance row, substitute the receiver's fixed family arguments into parameter
and result descriptions; fresh row-local generic parameters remain visible as
presentation symbols. Relate type-object row instantiation to the existing
family-then-row parameter order without adding a second instantiation syntax.

Keep `selector`, `params`, and `return`. Simple type descriptions are `Symbol`
values; compound type grammar is nested `List`/`Symbol` data. It is descriptive
data, not a first-class type, cast token, source annotation, or proof of nominal
identity. Same-spelled unrelated declarations can have identical descriptions.
Constructor-set refinements do not appear in ordinary reflected type data.

All metadata and hidden authority derive from the shared descriptors specified
by 89B. Specify semantic contents, not new public Racket structures or physical
storage layouts.

### 4. Exact signature ownership

A signature is an unforgeable capability for one exact dispatch row. Ownership
records the exact family instantiation for instance rows, family type object
for constructors and factories, appropriate constructor identity for
reflectable local rows, or exact primitive/host-interface identity, together
with the exact row identity.

A family row may be invoked on any constructor of its owning family at the
same generic instantiation. It cannot transfer from `(Option Int)` to
`(Option String)` or to an unrelated same-named family. A constructor row
belongs to its owning type object's mirror. Host ownership follows the exact
interface, not its diagnostic name or one receiver's allocation identity.

Signatures retain opaque row descriptors rather than using a flattened menu
index as authority. Storage and copying are allowed, but do not promise
user-visible signature equality, ordering, hashing, allocation identity, or
stable serialization. Keep this distinct from 89B's internal kernel equality.

### 5. Checked exact-row invocation and generics

`Mirror.invoke` invokes the selected descriptor directly. It never converts
the selector description into `perform` or repeats overload resolution.

Specify validation of owner, argument count, instantiated argument types,
complete generic resolution, and the ordinary result against the instantiated
return type. Use 89B's central nominal relation and its checked-program
boundary, including any contextual result obligation.

Instance family arguments are already fixed. Generic constructor and factory
rows are freshly instantiated for each invocation using the approved direct-
send constraints: explicit static information, expected result, arguments,
and the enclosing expression. Preserve fresh row-local method parameters too.
Reflection does not make an otherwise ambiguous nullary `None` constructible.

When a signature variable hides the selected row from the checker, preserve
the existing expected-result route and validate against the opaque row at
runtime. Reconcile that route with complete inference resolution and checked
construction. Do not infer a constructed family's arguments from its runtime
payload or result, treat reflected type spellings as authority, or invent a
signature-specialization API, runtime type token, or additional send form.

### 6. Argument acceptance and deterministic enumeration

`Signature.accepts?` keeps its deliberately narrow one-parameter contract. It
checks the candidate mirror's subject with the invocation type relation,
performs no invocation or overload search, and returns `#f` for other arities.

For a generic one-parameter row, input variables may be solved freshly from
the candidate. Success proves only parameter compatibility; it does not
resolve unrelated result-only variables or guarantee that invocation needs no
further context. It supplies no constructor refinement. Do not generalize it
to arbitrary argument lists.

Give Decision 8's deterministic ordering rules within a finalized image:
constructors follow declaration order, declaration-owned method and factory
rows follow textual order, and extension rows follow finalized program-
definition order. Overloads remain separate signatures. `messages` removes
duplicate selectors while preserving their first signature occurrence.
Additions may change later menu positions; indices are not stable identities.

### 7. Presentation and existing-client boundaries

Connect `raw` to 89B's structural renderer. Diagnostic text may show
`Family.Constructor`, but grants no constructor identity, payload value,
signature authority, refinement, or exhaustive-discrimination contract.
Parsing `raw` or branching on `show` remains presentation-text processing and
receives no missing-case diagnostics. Do not claim string inspection is
physically impossible or change the established raw spelling.

Record the compatibility obligations for existing clients: Gel retains its
`Mirror` stack, exact overload menus, `accepts?`, `invoke`, `subject`, and
`raw`; MPL retains reflection of the concrete family's public surface through
a protocol view; host reflection retains exact interface ownership and the
ordinary guarded invocation boundary.

Primitive and host rows in this section are preservation constraints only.
Do not draft adapter internals, enumerate a new built-in schema, broaden host
crossings, or redesign Gel. Specialized built-in and typed host integration
remain a separate later slice.

## Examples and reconciliation

Add a compact set of illustrative observations, using the candidate's existing
families where practical:

- A one-constructor `Point` mirror exposes `x` and `y`.
- `None` and `Some` instances of `(Option Int)` expose the same whole-family
  surface, including when mirrored inside a singleton-refined branch.
- The `Option` type-object mirror exposes `None`, `Some`, and its declared
  factory, with the appropriate roles and generic descriptions.
- A family-row signature works across constructors at the same instantiation
  and is rejected for a different instantiation or unrelated nominal owner.
- A generic one-parameter row can accept an argument while still needing
  context to resolve a result-only parameter.
- Unwrapping a mirror does not recover local access without the ordinary
  family/refinement rules.

These are candidate examples and observations, not executable 89C goldens.
Use prose or tables where runnable code would imply an unapproved mechanism.
Do not add tests for syntax that the implementation does not yet accept.

Audit the additions against Decision 8, the relevant parts of Decisions 9–10,
and 89A/89B. Reconcile existing references that still call all family-aware
reflection pending, while leaving built-in and host integration pending.
Avoid duplicating or weakening the central type relation, inference closure,
refinement erasure, kernel equality, or raw-display rules.

Update `Pending completion` to mark the boundary after 89C and reserve:

- specialized built-ins and typed host-capability integration;
- the complete diagnostic, exclusion, and validation catalogue;
- the final whole-candidate Decision 1–10 audit;
- the implementation roadmap and durable handoff; and
- atomic ratification into `SPEC.md`.

Reflection-specific errors and exclusions belong in this slice; the complete
cross-language catalogue and final audit do not. Do not draft detailed later
checkpoints or treat the candidate as semantically complete.

## Validation and acceptance

Before review:

- confirm only `docs/unified-nominal-adts-spec-candidate.md` changed in this
  implementation slice and all governing, checkpoint, runtime, application,
  fixture, and test files remain unchanged;
- confirm the candidate remains incomplete, non-normative, and unimplemented;
- verify all seven content areas, illustrative observations, cross-references,
  and the revised pending boundary;
- check for accidental multi-constructor local exposure, reflected refinement
  certificates, name-based ownership, selector redispatch, runtime family-type
  reconstruction, or unapproved type/signature APIs;
- run `git diff --check`, `git status --short`, and `git diff --name-only`; and
- run the established full regression suite (`raco test tests`) and the
  existing checkpoint-88 hand check without modifying tests.

The hand check is the public driver/Term example under `Hand check` in
`docs/checkpoints/0088-seal-typed-host-boundary.md`; its result remains
`'("sealed" "sealed\r\n")`. It uses an in-memory output port and requires no
physical terminal interaction. These are regression checks of the unchanged
baseline, not execution of the proposed reflection additions.

If Racket's default temporary directory is unwritable in the sandbox, use a
fresh writable temporary directory and report that environment adjustment
separately.

Accept 89C only when the reflection contract is cohesive, consistent with the
approved archive and accepted candidate, self-contained for this slice, and
contains no invented material semantic choice. Required documentation checks,
the unchanged suite, and the existing hand check must be green.

Stop for review without committing. Do not implement family reflection,
complete another pending subject, create the next checkpoint, ratify the
candidate, or begin checkpoint 90.

## Explicit non-goals

- Do not change normative or status documents, the archive, or transcripts.
- Do not change parser, checker, elaborator, evaluator, descriptors, reflection,
  host, library, application, fixture, or test behavior.
- Do not add source-written host types, crossing types, opaque handles, a
  first-class type universe, constructor tokens, or signature constructors.
- Do not add `perform`, instance constructor queries, payload inspection,
  reflective case analysis, or captured refinement authority.
- Do not rewrite built-ins, design filesystem capabilities, migrate Gel state,
  or add a legacy compatibility bridge.
- Do not update the roadmap or handoff, perform the final ratification audit,
  or write detailed later 89-series or 90–106 checkpoints.
