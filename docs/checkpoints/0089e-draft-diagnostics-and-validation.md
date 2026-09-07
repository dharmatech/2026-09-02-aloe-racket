# Checkpoint 0089E — Draft diagnostics, exclusions, and validation

Status: Proposed

Depends on: Checkpoint 0089D

## Goal

Complete the non-normative candidate's diagnostic, exclusion, and validation
catalogue for the already proposed unified-family design.

This is one documentation slice: collect the required rejection conditions,
distinguish the boundaries that detect them, state the deliberate exclusions,
and describe the observable evidence that a future implementation must supply.
The catalogue organizes existing semantic obligations; it does not introduce
language features, implement tests, or certify the whole candidate.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
and runtime behavior remains exactly as implemented through checkpoint 88.
The final whole-candidate Decision 1–10 audit, implementation roadmap, durable
handoff, and atomic ratification remain later 89-series work.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, checkpoints 89A–89D,
`docs/unified-nominal-adts-spec-candidate.md`, and
`archive/unified-nominal-adts.md` completely before editing.

The accepted candidate through 89D is the base. Decisions 1–9 supply the
semantic rules and exclusions. Decision 10's `Validation applications`,
`Required negative tests`, `Checkpoint discipline`, and `Completion criteria`
provide the validation coverage. Use the remaining parts of Decision 10 for
checked execution, finalization, transactions, and migration boundaries.

Preserve the current specification's unaffected expression rules, its
`check` diagnostic contract, and the typed-host boundary sealed at checkpoint
88. Inspect relevant current tests and application documentation as needed to
understand existing coverage. Do not treat today's missing family features as
accepted exclusions from the completed proposed language.

The transcripts in Git commit `8e6955c` and historical monolithic plan in
commit `8b2c155` remain non-normative. If the archive, candidate, current
specification, and repository leave a material semantic ambiguity or
contradiction, stop and report the exact issue before consulting transcripts
or inventing a rule. A validation example must not silently settle an open
language choice.

## File scope and candidate status

Edit exactly one implementation artifact:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, `docs/gel.md`,
the archive, checkpoint documents, source, tests, fixtures, examples, or
applications. Do not create a separate test plan or audit artifact.

Keep the prominent incomplete, non-normative status. Update its scope to
include 89E's diagnostic, exclusion, and validation catalogue alongside
89A–89D. Completing this catalogue is not final design approval, ratification,
or authorization to accept family syntax in the implementation.

Write concise specification prose and grouped tables. Each catalogue entry
must connect to an existing semantic rule in the candidate; repair section
numbers and cross-references as needed. Prefer references over repeating
complete grammar or runtime algorithms. Preserve accepted semantics except
for necessary reconciliation; this slice does not rewrite earlier sections
under the guise of adding examples.

## Required candidate additions

### 1. Diagnostic meaning and detection boundaries

Describe required errors by the condition they diagnose and the information
needed to understand that condition. Distinguish:

- source grammar, name resolution, and static checking failures;
- combined declaration, extension, and whole-unit finalization failures;
- Racket host declaration and driver-injection failures; and
- guarded runtime validation and ordinary evaluation failures.

These are semantic detection boundaries, not mandatory error-code names or
public exception classes. Do not invent exact diagnostic wording, numeric
codes, source-span formats, error aggregation, recovery behavior, or a global
precedence between independent errors. Where the design specifies only that
a condition is rejected before evaluation, do not require one particular
parser/linker/checker implementation phase to report it.

Preserve the diagnostic information already required by the design:

- Missing case constructors are reported in family declaration order.
- Type presentation uses the base family type rather than source-like
  constructor-set annotations. When an exact generic instantiation matters,
  show it separately from concise raw value text, especially for nullary
  constructors.
- Names and raw spellings remain descriptions; a same-name ownership mismatch
  is still a nominal mismatch, not evidence that two owners are compatible.
- When same-typed values fail comparison, `check` reports both original source
  datums and resulting values; its trusted comparison remains kernel equality.
- Host implementation failures preserve Aloe host-failure context and their
  original Racket cause; breaks pass through unchanged.

Static failure commits no partial checker state and begins no evaluation.
For hidden reflective rows and host crossings, specify the guarded runtime
obligation rather than pretending every failure can be known statically.
Owner, arity, argument, and required generic-resolution failures prevent the
selected row from running. Result validation occurs after execution and does
not undo effects. Keep atomic injection, static transactions, and runtime
nonrollback distinct.

### 2. Required rejection catalogue

Produce a grouped catalogue with the invalid condition, applicable detection
boundary, and a reference to the governing candidate rule. Cover all rejection
conditions already specified by 89A–89D and Decision 10, including these groups:

| Group | Required coverage |
| --- | --- |
| Expressions and types | Malformed ordinary combinations and declarations, invalid selectors, unbound names, malformed or unresolved source types, wrong generic arity, and unsupported source forms. Preserve the distinction between expression sends and annotation/type-header grammar. |
| Family declarations | Missing required sections, malformed section order/cardinality, empty constructor sets or present-but-empty conformances, invalid method rows, duplicate constructor selectors or payload names, reserved markers in their exact scopes, constructor/factory, constructor/instance, family/local, and payload/local collisions, and duplicate exact overloads. |
| Construction and generic sends | Wrong payload arity or type; malformed, incomplete, or conflicting explicit type evidence; unresolved nullary or partially determined constructors; invariant family mismatch; escaped inference variables at the specified boundaries. |
| Method surfaces and body modes | Unknown or unavailable messages; local access without singleton knowledge; repeated locals mistaken for family messages; incomplete, duplicate, unknown, or otherwise malformed `per-constructor` tables; forbidden body modes on factories or local methods. |
| Exhaustive case | Ineligible scrutinees; missing, duplicate, unknown, or currently impossible constructors; invalid binder shapes or payload arity; misplaced or empty-residual `else`; incompatible results. |
| Protocols and overloads | Missing or incompatible requirements, requirements supplied only by constructors/factories/accessors/locals, per-constructor or nonuniform generic claims, unsupported conformance forms, ambiguity, and incoherent narrower results. |
| Additive extensions | Invalid targets or sections, exact replacement, reserved selector collisions, incoherent combined rows, and attempts to add representation, local tables, per-constructor tables, or conformance claims. Preserve the separately specified `List` extension route. |
| Recursion | Wrong self arity or arguments, reordered parameters, nonregular/polymorphic recursion, mutual or unresolved forward references. |
| Nominal runtime integrity | Foreign constructor ownership, malformed payload count or substituted payload type, unresolved construction arguments, and exact family/protocol/instantiation mismatches at dynamic boundaries. |
| Reflection | Wrong signature owner, argument count or type, insufficient/conflicting generic information, invalid results or contextual subjects, and attempted invocation from descriptive symbols or forged authority. Preserve the absence of multi-constructor locals and representation queries. |
| `check` | Incompatible operand types during checking, and unequal same-typed values during evaluation; preserve the specified failure information and return of the right-hand value on success. |
| Specialized values and host access | Existing numeric/collection failures, invalid host declarations and implementation call shape, duplicate host selectors, injection conflicts, unsupported crossing types, bad crossing values, same-name interface confusion, and absent optional authority. |
| Completed source transition | Legacy `define-class`, positional conformance, family-level fields, assumed generated `new`, and permanent dual declaration syntax. Distinguish the completed language from any later temporary migration bridge. |

State context-sensitive conditions precisely. An explicit type header filters
overloads by applicable generic arity; one rejected candidate does not make the
send invalid if another valid row applies. An expected protocol cannot alone
resolve a family instantiation. Ordinary results and generic storage forget
refinement without changing the stored value's constructor or nominal type.
An empty `(fields)` section is required for a nullary constructor, not an
invalid empty constructor set. Preserve optional empty sections where the
grammar permits them and each contextual marker's exact reservation scope.

Do not turn ordinary negative answers into errors. `Signature.accepts?`
returns `#f` for non-one-parameter rows and incompatible candidate subjects;
it does not invoke a row. Unequal values at kernel comparison are distinct
from `check` failing its equality requirement. A final nonempty-residual
`else` is legal, and an ordinary domain constructor named `Other` is unrelated
to it.

Describe malformed nominal values or forged signatures as defensive boundary
validation scenarios. Do not invent Aloe syntax that can create such values,
publish descriptor constructors, or require a new public testing API merely
to express the negative case.

### 3. Consolidated exclusions and deferrals

Organize the deliberately absent features by subject, drawing from the
accepted candidate and archive rather than blindly copying `SPEC.md`'s
historical out-of-scope list. In particular, required protocol signatures and
multiple family conformances are part of the proposed design.

Cover at least:

- Preserved small language: no inheritance, mutation/setters, macros, implicit
  numeric coercion, computed selector send, Scheme application, or second
  dispatch/evaluation rule; retain the other applicable existing exclusions.
- Family representation: no constructor types/subtypes or implicitly bound
  constructor functions, constructor-specific generics/results, existential
  payloads, GADTs, visibility syntax, open constructor extension, or permanent
  parallel class ontology. Constructors are not first-class values; explicitly
  wrapping a constructor send in `fn` remains permitted.
- Refinement and elimination: no source-written or deep stored constructor
  refinements, predicate/equality/reflection-derived refinement, partial case,
  nested patterns, guards, alternatives, fallthrough, or wildcard payload
  patterns. Nested case expressions and ordinary lexical binders remain legal.
- Generic and recursive machinery: no partial type headers, constructor-specific
  let polymorphism, general subtyping expansion, mutual/forward declaration
  groups, nonregular recursion, positivity or termination checking, or claims
  of a full inductive type theory.
- Protocols and methods: no structural, conditional, per-constructor, or orphan
  conformance; generic protocols, protocol inheritance/intersections/defaults,
  and default-plus-override family bodies remain absent. Preserve allowed
  additive uniform methods and factories.
- Runtime and reflection: no name-based identity, observable allocation
  identity for ordinary family data, protocol wrappers, factory provenance,
  user-overridable kernel equality, `show`-driven raw output, multi-constructor
  instance representation queries, escaping refinement certificates, user-created
  signatures, first-class type universe, or selector-based `perform`.
- Built-ins and host integration: no forced built-in algebraic rewrite, newly
  invented built-in constructor/case surface, general heterogeneous `List`,
  broadened host crossings, source-written host types, opaque handle/callback
  marshalling, ambient capability, arbitrary Racket access, or general FFI.

Distinguish an unsupported proposed-language construct from an implementation
strategy that violates the model, an unpromised property such as stable
cross-execution identity, and optional future work such as built-in algebraic
rewrites. Do not declare an excluded feature impossible forever or design its
future syntax. Permitted opaque stateful leaves do not introduce Aloe mutation.

### 4. Semantic validation catalogue

Specify future validation obligations as observable scenarios with their
expected result, relevant type/refinement context, and governing rule. Use
grouped entries, not runnable fixture files or a test-harness design. Pair
rejections with representative permitted cases so the catalogue protects both
sound rejection and useful expressiveness.

Include positive and behavioral coverage for:

- Products and variants: explicit construction, payload order, public
  constructor rows, factories with type-object `self`, and uniform versus
  complete per-constructor behavior.
- Inference: explicit and contextual nullary construction, fresh parameters
  per send, two-parameter `Result` constraints across alternatives, invariant
  arguments, and branch-order-independent results. An expected exact family
  such as `(Option Math)` may guide construction from a conforming payload;
  an existing `(Option Sym)` does not convert covariantly to `(Option Math)`.
- Refinement: direct construction and immutable `define`/source-`let` aliases;
  explicit and residual case binders; branch unions; and every specified loss
  point, including factories, annotations, general function boundaries,
  payloads, containers, protocols, and reflective unwrapping.
- Case execution: once-only scrutinee evaluation, exactly one lazy branch,
  payload binding order, residual defaults, and explicit `Other`. All branch
  bodies must satisfy the static rules; an ill-typed unselected branch is not
  a valid demonstration of runtime laziness.
- Closed and open axes: revising a family declaration to add a constructor
  rechecks exhaustive consumers, per-constructor bodies, and conformance;
  `else` deliberately opts its consumer out of missing-case diagnostics.
  New conforming families remain possible without changing a protocol, while
  adding a protocol requirement rechecks its conformers.
- Protocols and extensions: multiple compatible family conformances,
  whole-domain coverage, narrower coherent dynamic overloads, signatures
  installed before bodies, and later allowed extension rows satisfying a
  conformance within one complete source unit.
- Transactions: a static failure in a declaration, extension, or transitive
  load leaves no partial live static state and performs no evaluation; a REPL
  datum forms its own transaction. Successful checking followed by runtime
  failure does not promise effect rollback.
- Recursion and values: direct regular self-reference, including beneath
  existing containers or function types; finite recursive data; exact nominal
  and instantiated equality; separately allocated equal data; nullary values
  at distinct instantiations; and opaque leaves.
- Display and reflection: concise raw forms and separate type context,
  independence from `show`, one-constructor locals, hidden multi-constructor
  locals, constructor/factory roles, substituted and fresh generics, exact
  row ownership, deterministic enumeration, contextual invocation, and the
  limited meaning of a successful generic `accepts?`.
- Preserved integration: literal selectors, explicit `call`, parallel `let`,
  lazy conditionals, numeric separation, invariant collections and contextual
  empties, `define-methods List`, exact host identity, guarded crossings,
  immutable crossing strings, retained host causes, and unchanged Term output.

Reusing a scenario for several obligations is fine when its observations are
explicit. A declaration-growth scenario edits the owning declaration and
rechecks consumers; it is not permission for a runtime constructor extension.
Same-name nominal and malformed-boundary scenarios must not depend on invented
module, serialization, or identity-token facilities.

Kernel comparisons across different instantiations do not imply that source
`check` accepts differently typed operands; state which source rejection or
internal runtime observation a scenario is intended to establish.

### 5. Application validation and eventual completion evidence

Include Decision 10's application coverage table, with the future evidence
each application supplies:

| Application | Required evidence |
| --- | --- |
| `Point` | Product construction, fields, methods, equality, raw display, and local reflection. |
| Boids | Nested generics, immutable products, lists, numeric sends, explicit conversion, and both step sends. |
| MPL | Open `Math`, additive operations, overload specificity and return coherence, domain equality, and `show`. |
| `Option` | Nullary/unary generics, contextual and explicit construction, factories, exhaustive consumers, and reflection. |
| `Result` | Two independent parameters, constraints across alternatives, and insufficient-context rejection. |
| `Tree` | Regular recursion, recursive payloads and methods, equality, printing, and nested case. |
| Filesystem model | Closed classification with ordinary `Other`, local capabilities, defaults, and exhaustive consumers. |
| Gel | Exact reflection remains useful while pending/state representations can use families; existing keys and emitted text are preserved. |
| Term and host tests | Exact interface ownership, explicit injection, guarded direct/reflected invocation, and the sealed public boundary. |

These are future validation obligations, not instructions to build or migrate
the applications in 89E. Preserve the archived Gel expectation of replacing
the pending sentinel list with `Option` during later implementation; a further
state family is conditional on clarifying the application. Do not select a
state schema or change its UI behavior. Filesystem coverage does not specify
an OS capability API or authorize broader host crossings.

State the eventual evidence boundary: the migrated historical suite and these
application scenarios must pass, checked evaluation must carry the required
static information, exact nominal/reflection/host guarantees must hold, and
the temporary legacy bridge and dual user nominal model must be gone. Built-in
rewrites remain optional. This records what future completion must establish,
not a claim that those outcomes have been achieved.

Do not copy or allocate the provisional 90–106 sequence, assign future test
filenames, decide implementation algorithms, or draft the roadmap and handoff.
Those remain separate artifacts of later 89-series work.

## Catalogue review and pending boundary

Keep the catalogue complete for the already specified rules without repeating
the entire specification. Use compact examples only where they clarify a
distinction; there is no required example count or combinatorial test matrix.
Every example must state enough declarations, expected type, and refinement
context to support its claimed outcome. In particular, use an unrefined
scrutinee when an example needs several possible constructors, and identify
an intended missing inference constraint rather than accidentally supplying it.

Mark future family scenarios as candidate validation obligations. Keep them
distinct from existing runnable preservation examples and from the regression
checks performed to accept this documentation slice.

Check catalogue coverage against the candidate and the archive's required
negative tests and validation applications. This is a coverage check for 89E,
not the final whole-candidate Decision 1–10 consistency audit or a certificate
that the proposal is ready for ratification. Report substantive contradictions
rather than silently repairing the underlying design in the catalogue.

Update `Pending completion` to mark the boundary after 89E and reserve:

- the final whole-candidate Decision 1–10 audit;
- the implementation roadmap and durable handoff; and
- atomic ratification into `SPEC.md`.

Retain the incomplete status and the fact that optional built-in algebraic
rewrites are not unfinished requirements. Completing the catalogue does not
authorize another checkpoint, migration, or family implementation.

## Validation and acceptance

Before review:

- confirm only `docs/unified-nominal-adts-spec-candidate.md` changed in this
  implementation slice, with governing documents, checkpoint documents,
  production code, libraries, applications, fixtures, and tests unchanged;
- confirm the status remains incomplete, non-normative, and unimplemented;
- verify all five content areas, semantic references, example contexts, and
  the revised pending boundary;
- verify that static errors, boundary failures, ordinary negative answers,
  exclusions, optional future work, and unachieved validation obligations are
  distinguished correctly;
- check that no new syntax, type relation, error API, host capability, test
  harness, roadmap, or ratification claim was introduced;
- run `git diff --check`, `git status --short`, and `git diff --name-only`; and
- run the established full regression suite (`raco test tests`) and the
  existing checkpoint-88 hand check without changing tests.

The hand check is the public driver/Term example under `Hand check` in
`docs/checkpoints/0088-seal-typed-host-boundary.md`. Its result remains
`'("sealed" "sealed\r\n")`. It uses an in-memory output port and requires no
physical terminal interaction. The passing baseline suite is not evidence
that the proposed family validation catalogue has been implemented.

If Racket's default temporary directory is unwritable in the sandbox, use a
fresh writable temporary directory and report that environment adjustment
separately.

Accept 89E only when the catalogue is cohesive, complete for the specified
design, traceable to its governing rules, and contains no invented material
semantic choice. Required documentation checks, the unchanged suite, and the
existing hand check must be green.

Stop for review without committing. Do not implement the catalogue's tests,
perform the final design audit, complete another pending subject, create the
next checkpoint, ratify the candidate, or begin checkpoint 90.

## Explicit non-goals

- Do not change normative or status documents, the archive, or transcripts.
- Do not change parser, checker, elaborator, evaluator, descriptors, runtime,
  reflection, host, library, application, fixture, or test behavior.
- Do not invent diagnostic codes, source-location infrastructure, exception
  hierarchies, error recovery, nominal forging syntax, or public test hooks.
- Do not implement or migrate `Option`, `Result`, `Tree`, Boids, MPL, Gel,
  filesystem models, or host capabilities.
- Do not alter accepted semantics to make an example or coverage table work.
- Do not write the final audit, implementation roadmap, durable handoff,
  ratification text, or detailed later checkpoint documents.
