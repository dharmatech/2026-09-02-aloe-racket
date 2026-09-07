# Unified nominal algebraic families: implementation roadmap

> **PROPOSED — NON-NORMATIVE — DRAFTED IN CHECKPOINT 89G**
>
> Runtime baseline: checkpoint 88. Design baseline: the accepted
> [89F candidate][candidate] and [completed audit][audit], including the
> [approved U1 amendment][u1]. Every implementation entry below is future
> work, neither completed nor currently authorized. `SPEC.md` remains law.
> The candidate remains incomplete and non-normative; checkpoint 89 as a
> whole is not finished.

Implementation requires the remaining 89-series documentation, a durable
implementation handoff, and later atomic ratification. That ratification must
reconcile the governing documents and promote the reviewed sequence into
`CHECKPOINTS.md` before implementation begins. This draft neither performs
that promotion nor authorizes checkpoint 90 or new source syntax. Later final
implementation documentation is a different obligation from this prerequisite
normative ratification.

## Basis and planning level

This plan expands [Decision 10's provisional 90–106 sequence][sequence] into
reviewable outcomes. Decisions 1–10, as audited in 89F and amended only by U1,
supply the semantics. The archive's blanket runtime-inference prohibition is
qualified solely by U1's sealed-input selected-row invocation rule. Planning
does not reopen that decision or add an exception elsewhere.

The initial worktree on 2026-09-07, at
`c20ab1f801b08b354e0d3629232f379181f1f903` on
`codex/unified-nominal-adts`, contained only:

```text
?? docs/checkpoints/0089g-draft-family-implementation-roadmap.md
```

That user-supplied checkpoint is preserved as input. The only work artifacts
of 89G are this roadmap and candidate status/link/pending-artifact prose.
The accepted 89F audit and review establish the starting design; historical
checkpoint headers need no repair. Neither the transcripts nor the historical
monolithic plan were consulted or restored.

Entries state prerequisites, one outcome, its admitted boundary, and
representative positive and rejection/preservation evidence. They are intended
for later expansion by a designer, not detailed checkpoint instructions,
algorithms, internal API designs, or fixture specifications.

### Repository evidence that affects ordering

| Current evidence | Planning consequence and owner |
| --- | --- |
| [Driver][driver] and [public helpers][main] check parsed expressions, then evaluate them without retaining elaboration. List bootstrap and transitive loads also use this separation. [Evaluator][eval] reloads source during evaluation. | 90A retains checked decisions; 90B routes all production entry points, bootstrap, and loaded units through the checked result. The complete candidate boundary is not claimed until 91C. |
| [Parser][parse] lowers source `let` immediately; its `fn` branch currently accepts only untyped parameter names, although [SPEC §4.2](../SPEC.md#42-fn) specifies written annotations. | 90A retains alias provenance and supplies the already specified annotation/expected-arrow support needed to check and retain function types. 95 adds multi-constructor alias propagation. No new annotation syntax is chosen. |
| [Checker][type] creates fresh types for `subject`, `invoke`, and context-free empties; it installs class and extension bindings while checking. Generic class bodies use the existing instantiation checking strategy. | 90B supplies staging; 91A supplies combined validation for the bridge; 91C closes all specified inference boundaries. Bound parameters remain legal; this plan adds no generic-constraint language. |
| [Evaluator][eval] infers construction arguments from values, gives empty lists no element type, represents functions without checked arrows, and has name-based type matching. [Signature][signature] retains a flattened row index. | 90C retains collection/function types before 91A's exact relation relies on them; 91A replaces the user nominal model. 91B seals input evidence and exact row authority before 91C exposes U1. |
| [GelStack][stack] has the three ordinary-result invocation helpers from U1. [Gel menu][menu] and [loop][loop] use contextual empty lists; pending state is `(List GelRow)`. | 91C rewrites only the three helpers and required closure-sensitive observations. 103B converts nominal declarations; 105 changes pending to `(Option GelRow)`. |
| [Test 36][t36] uses unchecked evaluation to inspect concrete MPL fields when the source result has a protocol view. | 90B preserves these observations through checked contextual reflection as part of the checked-evaluation transition. |
| [Tests 57][t57], [60][t60], [73][t73], and [87][t87] use uncontextualized reflection; [8][t8] and [16][t16] observe empties without determining an element type. Test 73 injects a bad body through unchecked evaluation. | 91C migrates closure-sensitive observations to a checked contextual or mirrored route and preserves defensive failure coverage internally. Closure must not turn intended runtime-guard tests into unrelated static failures. |
| [List library][list] defines `fold`, `reverse`, and `map` with contextual accumulators and `call`. [MPL core][mpl] supplies protocol rows through later extensions and loads. The evaluator has special raw cases for `Sum` and `Prod`, reflected in tests 38–41, 44, and 46. | 90B/91A must support complete-unit finalization and the List extension route. 91A changes raw goldens to the candidate's descriptor-based product form while preserving MPL domain operations and `show`. |
| [Point][point], [Boids][boids], [Gel runner][gel-run], and [Term runner][term-run] exercise generic products, both step sends, and explicitly injected checked drivers. [Host][host] and [Term][term] already share guarded exact interface declarations. | Preserve them throughout; 103 owns broad source conversion. Descriptor work must preserve host preflight, exact state/row ownership, crossings, causes, breaks, and public sealing immediately. |

### Shared completion and transition requirements

Every future entry includes relevant tests in its own change, the full
`raco test tests` suite, and its required hand observation, then stops for
review when green. Test counts are not fixed. Positive examples must supply
their stated type/refinement context; laziness examples have well-typed
branches. Defensive malformed values and forged authority are tested through
internal boundaries, without publishing constructors or a new testing API.

[Diagnostics][diagnostics], [rejections][rejections], and [exclusions][exclusions]
apply with each feature's first admission. Later forms remain explicitly
unavailable and rejected. No checkpoint may approximate them with partial case,
name-based identity, reflected multi-constructor locals, inferred family rows,
structural conformance, or unresolved ordinary construction. A prerequisite
implemented early is not implemented again at its archived milestone.

The baseline's existing gaps are removed by the named early steps below;
preparation is not evidence of a completed candidate boundary. There is one
production path during transition, with no permanent permissive alternative,
Gel exemption, disabled guard, or skipped test. Any newly exposed capability
has all of its own required guards from its first usable release.

Across descriptor and driver changes, preserve [§15][integration]: exact host
interface identity, paired injection preflight, target receiver state,
`Int`/`Bool`/`String` crossings, immutable strings in both directions, argument
guards before execution, result guards afterward, retained causes and breaks,
and the checkpoint-88 public/internal boundary. Static transactions and
injection are atomic; effects after successful checking are not rolled back.
Specialized values keep their contracts and do not acquire family constructors,
case eligibility, source host types, or general extension rights. The existing
`define-methods List` route and its `T` scope remain available.

## Proposed sequence

Execution order is the order below:
**90A → 90B → 90C → 91A → 91B → 91C → 92 → 93 → 94 → 95 → 96 → 97 → 98 →
99A → 99B → 100 → 101 → 102 → 103A → 103B → 103C → 104 → 105 → 106A → 106B**.
Each entry requires the preceding entry and therefore all its transitive
prerequisites, in addition to the specific support named in its text. 90A
requires the completed later 89-series handoff and atomic ratification.
This is an acyclic proposal; numbers are stable provisional anchors, not
amendments to completed checkpoint history.

### 90A — Retain the static decisions needed by execution

**Prerequisite:** ratification and implementation handoff. Produce checked
results retaining source provenance, resolved send information, contextual
obligations, and function typing for the currently supported language
([§8][checked]). Retain source `let` through checking and support the written
`fn` annotations already specified by the preserved language, alongside
inferred arrows. This is preparation, not production activation or a closure
claim; no family, case, or send-header syntax is admitted.

**Evidence:** inferred and annotated functions agree, execute only through
`call`, and reject contradictory annotations; parallel `let` preserves lexical
scope. Checked information survives checking without running user behavior.
Existing public behavior remains under regression coverage.

### 90B — Evaluate one checked source transaction

**Prerequisite support:** 90A's retained checked result. Route the driver,
public datum/program/source helpers, CLI/REPL, List bootstrap, and both
optional runners through it. A loaded unit includes its transitive loads;
evaluation consumes that checked content. Stage static state and finalize
the currently supported obligations before commit and evaluation
([§§8–9][transactions]). Type-only callers may discard elaboration.

**Evidence:** a failed declaration, extension, later file expression, or
transitive load leaves the live driver unchanged and produces no effect;
a successful load preserves path resolution and results. A REPL datum is a
separate transaction; later runtime failure does not undo effects. Migrate
public parse/evaluate test uses now, including [checkpoint 36][t36]'s unchecked
MPL concrete-field observations. Preserve those field observations through
the existing checked contextual reflection route when the source result has
a protocol view. Explicitly internal defensive probes may remain.
Exact unified identity and universal closure are completed in 91A–91C,
so this step alone is not the finished checked-execution guarantee.

### 90C — Retain checked collection and function types in values

**Prerequisite support:** 90A's type information and 90B's checked production
route. Preserve resolved invariant List element types, including contextual
empties, and checked function arrows when values are created and used through
generic rows ([§15][integration]). This supports the exact relation in 91A;
it cannot wait until mirrored calls arrive. No new nominal syntax or mirrored
operation is exposed, and universal source closure still waits for 91C.

**Evidence:** contextual empty lists retain their element type without scanning
elements; functions retain their checked arrow with bound arguments resolved
at use without executing callbacks to discover it. List `map`/`fold`/`reverse`,
typed collection results, and generic function arguments preserve their
specified types. Incompatible invariant types fail. A source occurrence whose
type is still unresolved supplies no sealed closed evidence; no placeholder
may pass as one. Closure-sensitive historical source is migrated in 91C.

### 91A — Use one nominal model behind the legacy declaration bridge

**Prerequisite support:** retained decisions and transactional checking from
90A–90B and retained specialized types from 90C. Introduce the temporary
`define-class` lowering into one-constructor
`new` families and replace the separate checker/runtime user nominal models
with shared family, constructor, protocol, and row identities. Ordinary
construction receives checked arguments; remove payload-based reconstruction.
Provide the singleton fields/uniform methods, structural equality, raw/display
separation, and one exact runtime relation needed by existing products
([§§9–13][values], [§17][migration]).

Legacy single conformance and uniform extensions must already receive combined
row uniqueness, full-domain coverage, uniform generic conformance,
narrower-result coherence, and atomic
validation over complete units. Signatures precede body checking. This moves
the necessary subset of 99/100 earlier for MPL; it admits no new family syntax,
factory extension, multiple claim, or recursive-family feature.

**Evidence:** legacy Point/Boids and MPL run through the shared model; same-named
distinct owners fail exact checks; wrong constructor owner/arity/payload and
unresolved construction arguments fail at introduction. Equal product data
compares structurally; opaque leaves keep identity. Remove the Sum/Prod raw
special cases and update their structural-text expectations here. A failing
extension installs nothing; local/accessor rows cannot satisfy conformance.
The source-only bridge remains until 103C, with no second class runtime.

### 91B — Seal reflected input evidence and exact signature authority

**Prerequisite support:** 90C's retained collection/function types and 91A's
common identities/relation and checked construction. Make this already closed
evidence, including exact family instantiations, available inside the sealed
reflection boundary. Supply exact owner/row authority and guarded row execution,
including ordinary contextual result obligations, before U1 calls are exposed
([§§11, 14–15][reflection]). Move `role`, `type-params`, and descriptor-based
enumeration support from 102 here; existing surfaces receive their specified
roles. This does not yet expose `invoke-mirrored` or assert universal closure.

**Evidence:** closed legacy-product, empty-list, and function inputs retain
their evidence without payload scans or executing callbacks. Known contextual
`subject`/`invoke` mismatches fail their boundary checks. Same-named unrelated
owners and alien rows fail, while an exact host row uses the target's state.
Stored signatures retain their row across additive enumeration changes;
metadata remains descriptive. Missing or invalid evidence fails the prepared
guarded path; it is never filled from a result. Current clients remain covered
until the atomic closure transition in 91C.

### 91C — Close production inference with usable mirrored invocation

**Prerequisite support:** 90B's source transactions, 91A's exact nominal model,
and 91B's sealed closed input evidence and guarded exact rows. Activate U1's
fixed `Signature`/`(List Mirror)` operation returning `Mirror`, rewrite all
three [approved Gel helpers][gel-examples], and enforce closure at every
boundary in [§8][closure] in this one transition. The checked pipeline now
meets the full boundary for admitted forms; no production raw-AST route or
ordinary-construction inference fallback remains.

**Evidence:** zero, plain-argument, and Mirror-argument Gel calls preserve
their results and exact `push` overload; contextual `List empty` closes as
`(List Mirror)`. Inputs unwrap once, results are validated before wrapping
once or reusing an existing Mirror, and an explicitly mirrored Mirror passes
that object. Wrong owner, arity, argument, or missing generic evidence prevents
execution; bad results fail afterward. Exercise fresh input-determined legacy
generic rows using checked lists/functions, and unresolved result-only rows;
future `Some`/`map` coverage belongs to 94/96.

Append the exact fixed row after existing Mirror API rows; it has zero local
type parameters and forwards no header. Ordinary subject menus stay unchanged;
explicit Mirror browsing gains this row. Migrate closure-sensitive historical
reflection/empty-list tests and defensive probes **in this change**, as detailed
below. Preserve valid Gel keys/output and host guards. No nominal source or
pending-state refactor occurs here; all new family syntax remains rejected.

### 92 — Construct and use explicit product families

**Prerequisite support:** the closed checked pipeline and singleton product
behavior from 91A–91C. Admit non-generic one-constructor `define-family`, its
explicit constructor (conventionally `new`), fields, local methods, and uniform
whole-family methods ([§3][declarations]). The already validated uniform
`define-methods` route can target these products too. Validate the admitted declaration
sections and selector partitions together. Locals and uniform `self` are
inherently singleton; this needs no general variant-flow propagation.

**Evidence:** a non-generic Point-shaped product constructs, reads fields,
calls a local from a uniform method, compares, prints, and reflects its sole
locals. Reject malformed/empty constructor sections, collisions, and a send
of `new` when no such constructor was declared. Native generic declarations,
multiple constructors, conforms, factories, case, and per-constructor bodies
remain unavailable; existing generic products use the temporary bridge.

### 93 — Construct closed variants without representation leaks

**Prerequisite support:** shared identity/integrity/equality/raw behavior from
91A, exact reflected rows from 91B, and product declarations from 92. Admit
multiple non-generic constructors and immutable payloads. Direct construction
supplies the singleton knowledge needed for its payload accessors. Apply the
multi-constructor instance reflection exclusion immediately
([§§2–3, 10–14][surfaces]).

**Evidence:** construct distinct nullary/payload variants, distinguish their
kernel structure and `Family.Constructor` raw form, and reject foreign owners,
bad payloads, and same-name authority substitution. Both `messages` and
`signatures` omit locals/accessors even for a direct singleton; type objects
expose constructor rows. No tag/payload query appears. Multi-constructor local
method declarations and alias-based local sends wait for 95; generic variants,
case, factories, and per-constructor tables remain rejected.

### 94 — Resolve generic sends across their enclosing expression

**Prerequisite support:** checked arguments/closure from 91C, variants from
93, and exact row schemas from 91B. Admit generic family declarations and
complete post-selector send headers, including fresh instance-row parameters.
Support contextual construction and symmetric constraints across existing
`if`/`cond` branches before adding case ([§5][generics]). Preserve invariance
and existing generic method checking without adding constraint syntax.

**Evidence:** explicit/contextual `None`, payload-inferred `Some`, independent
sends, and `Ok 1`/`Error "x"` alternatives in both conditional orders close
correctly. Reject partial/conflicting headers, unresolved nullary/partial
construction, invariant mismatch, and protocol-only inference. Generic arity
filters overload candidates without rejecting an otherwise valid send.
U1 now covers `Some` with Int and an already checked empty `(List Int)`, plus
pre-construction `None`/`Result.Ok` insufficient-evidence rejection, even after
`accepts?` succeeds. No outer Mirror expectation or header supplies missing
target parameters. Case-based `map` waits for 96; factories wait for 99A.

### 95 — Preserve shallow refinement and restrict local authority

**Prerequisite support:** source alias provenance from 90A, direct singleton
access from 93, and generic/conditional constraints from 94. Admit
multi-constructor local methods and propagate constructor sets through direct
immutable `define`/source-`let` aliases and existing conditional joins
([§5 refinements][refinements]). Broader views expose only whole-family rows.

**Evidence:** direct Some aliases use `value`; repeated local selectors never
become family rows. Branch reorderings union only outer knowledge. Test loss
through declared method results, annotations, general function parameters and
results, payloads, List storage, and contextual
unwrapping. Stored values retain their actual constructor; ordinary type
presentation omits sets. Factory loss is tested in 99A; loss on conversion of
a multi-constructor family to a protocol is tested with native conforms in 100.
Mirrors made from refined aliases still expose no variant locals. Case and
per-constructor bodies remain unavailable.

### 96 — Eliminate families with fully checked explicit case

**Prerequisite support:** 94's symmetric generic constraints, 95's joins/local
authority, and 91A's defensive constructor integrity. Admit explicit flat
case clauses, payload binders, and optional singleton whole binders
([§4][case]). Every accepted case exactly covers the scrutinee's possible
constructors, checks every branch, and elaborates opaque clause identities.
Defaults remain rejected until 97; result checking is already complete.

**Evidence:** one scrutinee evaluation and one lazy branch; reject ineligible
scrutinees, missing/duplicate/unknown/impossible constructors, bad binders,
incompatible or ill-typed unselected branches, and unsupported patterns.
Report missing constructors in declaration order. In unrefined Option cases,
Result alternatives infer symmetrically; unrelated conformers need an expected
protocol result. Implement a small case-based generic Option `map` for tests:
U1 fixes the owner and resolves fresh `U` from a checked arrow before callback
execution, including independent calls with different result types.

### 97 — Cover residual constructors with an explicit default

**Prerequisite support:** complete explicit cases and joins from 94–96. Admit
only final, nonempty-residual `else`, with optional residual whole binding
([§4 coverage][coverage]). Defaults participate in the same result constraints
and outer joins already in use, including generic alternatives.

**Evidence:** a singleton residual enables its local accessor; a larger residual
does not. Ordinary `Other` works as an explicit constructor. Reject empty
residuals, misplaced defaults, payload binders on defaults, and incompatible
results. Recheck a declaration after adding a constructor: explicit consumers
need coverage while a still-valid default opts out. No partial case, guards,
or nested pattern syntax is admitted.

### 98 — Execute complete per-constructor family bodies

**Prerequisite support:** singleton local checking, combined row validation,
and exact row identity already supplied. Admit one complete `per-constructor`
table as a whole-family overload's body mode ([§3][declarations]). Each body
gets the corresponding singleton `self`; invocation selects the actual
constructor's body within that one row.

**Evidence:** `present?` handles every variant and reflects one family row;
ordinary uniform bodies still work. Reject missing/duplicate/unknown entries,
extra binders/defaults, ill-typed bodies, partition collisions, and this mode
on locals. Editing the constructor set rechecks tables. Factories remain
unavailable and will reject this mode when admitted.

### 99A — Construct through ordinary declared factories

**Prerequisite support:** fresh family/row inference from 94, declaration-wide
signature availability and coherence from 91A, and family behavior from 98.
Admit declaration factories with family type-object `self`, ordinary bodies,
overloads, and complete family-then-row headers ([§3 factories][factories]).

**Evidence:** `Option.when` constructs both outcomes and calls other declared
type-object rows; callers see only its declared unrefined result. Reject
constructor collisions, invalid body modes, incoherent overloads, and incomplete
instantiation. U1 factory parameters determined by inputs succeed; a result-only
parameter fails before the factory runs. Factory provenance and local authority
do not escape. Factory extensions remain unavailable until 99B.

### 99B — Extend family and type-object behavior atomically

**Prerequisite support:** the extension transaction/coherence machinery from
91A and factory checking from 99A. Admit the full factories-then-methods
`define-methods` surface for native families ([§7][extensions]). The early
uniform-extension support is reused, not delivered a second time.

**Evidence:** new rows call one another, use target family parameters, and
extend existing values without changing their representation; an external
uniform method can case-analyze `self`. A bad row causes the entire extension
to fail. Reject exact replacement, wrong sections/targets, collisions,
constructor/payload/local/table additions, and conformance claims. Preserve
List's existing methods-only contract without adding built-in factory rights.

### 100 — Validate multiple uniform family conformances

**Prerequisite support:** 91A's single-claim complete-unit validation and
99B's full extension surface. Admit native `(conforms P ...)` with multiple
exact protocol identities. Finalize required whole-family coverage and
overload/result coherence across declarations and allowed extensions over
the complete loaded unit ([§§7, 9][protocols]).

**Evidence:** one row satisfies compatible identical requirements, coherent
narrower overloads preserve broader result promises, and a later extension in
the same loaded unit supplies a requirement. An incomplete REPL declaration
fails its own transaction. Reject narrow-only coverage, incompatible results,
nonuniform/per-constructor/orphan/structural claims, and requirements supplied
by locals, accessors, constructors, factories, or reflection. New conforming
families remain open; new protocol requirements recheck conformers. Revalidate
MPL and contextual `(Option Math)` construction without covariance. Recursive
family payloads remain unavailable until 101. A multi-constructor conformer's
protocol view loses singleton authority and exposes only protocol rows; a
mirror still describes its actual family's permitted public surface.

### 101 — Construct and consume regular recursive families

**Prerequisite support:** shared header identities and signature linking from
91A, generics, complete case, and body modes. Admit regular self-recursive
payloads after registering the current family and all constructors
([§6][recursion]). Existing method recursion does not substitute for this
payload capability.

**Evidence:** finite `Tree` data supports recursive methods, nested cases,
kernel equality, and the specified nested raw form. Test regular occurrences
beneath List and function types, plus previously declared families. Reject
changed/reordered/incomplete self arguments, mutual recursion, and unresolved
forward families. The restriction concerns payload occurrences, not ordinary
`Option.map` results at `U`; no positivity or termination requirement is added.

### 102 — Seal the complete family reflection surface

**Prerequisite support:** exact rows/metadata and U1 from 91B–91C, generic
construction/map from 94/96, and factories/extensions/protocols from 99–100.
Complete the cross-feature reflection evidence ([§14][reflection]); this is
not the first owner check or first exclusion of variant locals.

**Evidence:** every admitted receiver kind has its specified surface;
constructors/factories expose ordered schema, fixed instance arguments are
substituted, and fresh row parameters stay descriptive. One family signature
works across its constructors at one instantiation but not another or an
unrelated same-named owner. Hidden `None` succeeds through checked contextual
ordinary `invoke`; insufficient context fails. Contextual `subject` forgets
refinement, followed by ordinary exhaustive case when needed. Enumeration,
generic `accepts?` limits, raw independence, and no escaping local authority
hold together. Rerun Gel and all host reflection routes; no type/tag/payload
query or selector-based invocation is added.

### 103A — Migrate Point, Boids, and MPL sources

**Prerequisite support:** all family features and sealed reflection through
102. Convert these application declarations to explicit products and move
positional protocol claims to `conforms` ([§17][migration], [§22][applications]).
Preserve domain operations and application organization; adapt their associated
source fixtures/assertions in the same slice. Early raw and checked-observation
changes remain in place.

**Evidence:** migrated Point construction, fields, methods, equality, raw, and
local reflection; both Boids `(demo step)` sends produce the required Sim
results with nested generics and explicit conversion. MPL keeps open Math,
additive rows, specificity/coherence, domain equality and identities, and
`show` independent of kernel comparison. Reject mixed numeric/invariant types
and invalid claims. The bridge still serves remaining repository sources.

### 103B — Migrate Gel and the remaining repository-owned source

**Prerequisite support:** 103A's migrated applications and 91C's helper changes.
Convert remaining nominal declarations and positional claims in Gel, library
sources where applicable, fixtures, historical/new tests, and Aloe datums or
strings embedded in Racket runners/helpers. Inventory all repository-owned
executable sources, including non-`.aloe` inputs; inspect the existing List
library route without forcing a family rewrite ([§17][migration]).

**Evidence:** all positive source paths work using `define-family`; tests retain
their behavioral purpose instead of preserving incidental class internals.
Gel's three invocation paths, menu/stack flows, typed picks, integer entry,
cancellation, and checked Term runner remain valid, with the approved Mirror
API menu addition. This slice changes declaration syntax, not pending state.
Leave deliberate legacy-negative inputs recognizable for 103C.

### 103C — Remove the source bridge and all legacy acceptance

**Prerequisite support:** 103A–103B's complete source inventory and migration.
Delete the bridge introduced in 91A. `define-family` becomes the sole user
nominal declaration internally and publicly ([§17][migration]). Reconcile
active syntax documentation and remove bridge-specific scaffolding now.

**Evidence:** every public parser, checker, evaluation helper, driver/REPL,
file/load path, and optional runner rejects legacy `define-class`. Reject
positional family conformance, family-level fields, and assumed generated
`new`. Search executable sources for lingering acceptance/dependencies;
distinguish negative tests and historical quotations. No class/family alias,
fallback runtime, or migration switch survives. The earlier closure guarantees
remain active throughout removal.

### 104 — Validate canonical ordinary Option and Result examples

**Prerequisite support:** complete family semantics and bridge removal.
Provide small readable canonical examples of ordinary `Option` and `Result`,
using the mechanisms already tested in 94–102 ([§16][examples], [§22][applications]).
This owns the reusable application examples, not another kernel implementation.

**Evidence:** explicit/contextual nullary construction, two independent Result
parameters inferred across alternatives in either order, factories, exhaustive
consumers/defaults, and reflection. Include mirrored Some/map and contextual
None, paired with unresolved None/Ok and invariant mismatch rejection. Neither
family receives privileged syntax or built-in status.

### 105 — Replace Gel's pending sentinel with Option

**Prerequisite support:** stable case/reflection, 103B's nominal migration, and
104's ordinary Option vocabulary. Replace the empty-or-singleton pending list
with `(Option GelRow)` and update its exhaustive consumers ([§22][applications]).
A further Gel state family is conditional on making the code clearer; deciding
to retain the remaining state representation is not unfinished required work.

**Evidence:** empty/pending transitions, valid typed picks, integer accumulation,
return, cancel, no-ops, and quit preserve keys, stack results, menus, and emitted
text, including the approved explicit Mirror-browsing addition. Verify a real
TTY path and checked runner behavior. Incomplete pending consumers fail, and
pending Option mirrors expose no locals. This does not redesign keys or UI,
redo the 91C helpers, or promise that rows with missing generic evidence run.

### 106A — Validate a closed filesystem classification

**Prerequisite support:** the completed language, canonical examples, and
application validation through 105. Build an ordinary closed domain model
exercising explicit `Other`, constructor-local capabilities, uniform behavior,
and exhaustive external consumers/defaults ([§22][applications]).

**Evidence:** classified values support their justified local operations;
unrefined values need case. Declaration growth exposes missing consumers;
`Other` remains an ordinary constructor and `else` covers only a nonempty
residual. Use ordinary Aloe values and already permitted opaque composition.
This milestone chooses no OS API, new host selector, compound crossing,
callback marshalling, or opaque handle. Such capability design is not required
to validate classification.

### 106B — Seal the implemented unified model

**Prerequisite support:** every preceding entry, including 106A. Establish
[§22 completion][applications] with the migrated historical and new suite,
required application runs, checked execution, and exact reflection/host
boundaries. Reconcile normative documentation, implementation notes, and the
durable handoff with actual behavior. Review implementation size and remove
any remaining transitional duplication; do not postpone bridge removal here.

**Evidence:** Point, both Boids steps, MPL, Option/Result, recursive Tree,
filesystem classification, Gel's TTY path, and the sealed Term route pass.
Verify no legacy source acceptance, unchecked production evaluation,
construction inference fallback, independent nominal compatibility model, or
index/name-based invocation authority remains. Recheck all required rejections
and public/internal host surfaces. Documentation describes one implemented
user nominal model. Built-in algebraic rewrites remain explicitly optional.

## Allocation changes and dependency closure

| Archived anchor | Proposed owners and reason for subdivision or movement |
| --- | --- |
| 90 — checked seam | 90A retains information; 90B installs checked transactions and migrates checkpoint 36's unchecked MPL field observations to checked contextual reflection; 90C retains specialized value types before exact validation needs them. 91C finishes inference closure and removes remaining permissive behavior. Full closure cannot precede U1's evidence and client transition. |
| 91 — nominal nucleus | 91A owns shared identity and the legacy bridge. 91B supplies sealed types and exact rows needed by 91C. These are bounded prerequisites before admitting family source. |
| 92 — product syntax | 92; minimum singleton field/local/uniform behavior is supplied by 91A and exposed together. Generic native products join 94. |
| 93 — variants | 93; opaque identity/integrity/equality/raw foundations move to 91A. Direct singleton payload access moves forward from 95, and local reflection exclusion from 102, because both apply at first variant admission. |
| 94 — headers/generics | 94; checking-unit closure moves to 91C. Symmetric type constraints for existing conditionals move forward from 97; generic case uses them in 96. |
| 95 — refinements/locals | 95 owns general aliases, variant local methods, loss points, and outer conditional joins. Products/direct payload access are earlier prerequisites; factory loss is completed with 99A. |
| 96 — explicit case | 96 includes complete result checking and joins using 94–95; it never accepts partially checked cases. |
| 97 — defaults/joins | 97 owns residual defaults and their joins; shared type/refinement joins have already moved to 94–96 to avoid order-dependent conditionals or cases. |
| 98 — body modes | 98 owns complete tables; basic selector partitions/coherence are enforced with declarations from 91A–93, not delayed until tables arrive. |
| 99 — factories/extensions | 99A owns declaration factories; 99B owns full native extension grammar. Existing uniform extension staging/coherence moves to 91A for MPL and bridge preservation. |
| 100 — protocols/coherence | 100 owns native multiple conformances. Full validation for admitted legacy single claims and extension sets moves to 91A; transactions start in 90B. No interim incomplete conformance is accepted. |
| 101 — recursion | 101 owns regular recursive payload acceptance and Tree validation. Header identity preparation from 91A does not activate recursive syntax early. |
| 102 — reflection | Exact rows, metadata support, and U1 prerequisites move to 91B–91C; each later feature adds its own correct surface immediately. 102 owns the complete cross-feature reflection seal. |
| 103 — migration/removal | 103A migrates Point/Boids/MPL; 103B migrates remaining sources; 103C removes the bridge and reconciles active syntax docs. Earlier work assigns checked evaluation and checkpoint 36's MPL observations to 90B, raw observations to 91A, and Gel helpers plus closure-sensitive reflection/empty-list migrations to 91C; none is a second nominal migration. |
| 104 — Option/Result | 104 owns canonical application examples after small semantic test families in 94/96. |
| 105 — Gel state | 105 owns pending Option and conditional further state work. The U1 helper transition moves to 91C; nominal source conversion belongs to 103B. |
| 106 — filesystem/final seal | 106A isolates domain classification from 106B's final validation, documentation reconciliation, and removal of residual duplication. |

### The atomic U1 and closure transition

91C is the first public usable mirrored invocation path. Its prerequisites
already provide family evidence via the legacy lowering, closed List evidence
even for empty collections, checked arrows, exact owners/rows, and guards.
91C connects that support to the fixed operation, helper changes, and closure
enforcement together. Until then the early work is preparation for the complete
boundary, not a claim that unresolved source types are already forbidden.

The selected row has fresh bindings determined only by its fixed owner and
sealed closed inputs before execution. A source expected `Mirror`, metadata
strings, payload scans, executed callbacks/results, or a forwarded type header
cannot fill a missing parameter. Ordinary sends carry checked arguments;
ordinary-result `invoke` and `subject` must close even inside `Mirror of`.
91C covers currently expressible generic rows; 94 adds real Some/None/Ok
coverage, 96 the case-based map, and 99A result-only factories. Nongeneric
primitive success alone never establishes the generic guarantee.

Schedule the following historical migrations with 91C, not with 103 or 105:

- For uncontextualized `invoke`/`subject` observations in reflection, Gel, and
  host tests, preserve the intended value/guard observation using a checked
  expected type or mirrored result. For opaque host subjects, use existing
  inferred capability context or internal identity observation, never a
  source-written host type.
- Turn genuinely unresolved ordinary forms into closure-rejection tests.
  Supply context when testing runtime owner, arity, argument, result, cause,
  or break guards so a prior static error does not accidentally replace them.
- Give empty-list observations an element type within their checking unit.
  Keep context through `cons`, typed fields/parameters/results, and callbacks
  working, including List library accumulators and Gel's empty stack/pending
  fields. Preserve `first`/`rest` runtime failures using typed empties. Add
  rejection for empties still unresolved even when only `len`/`empty?` is used.
- Keep malformed-result and forged-authority tests at internal defensive
  boundaries; no production unchecked evaluator remains to support tests.

90B owns the migration of checkpoint 36's valid MPL concrete-field observations
to checked contextual reflection alongside the checked-evaluation transition.
The migrations in 91C remain the closure-sensitive reflection and
empty-list observations, together with the three Gel helper rewrites.

91C also exercises receiver/signature/list evaluation order, homogeneous Mirror
arguments, exact fixed metadata, once-only unwrapping, Mirror result reuse,
fresh generic invocations, and all host failure boundaries from
[§21's U1 obligations][u1-tests]. Neither helper adaptation nor test migration
authorizes a Gel state/key/UI change. Existing valid flows retain output except
for the explicitly added row when browsing Mirror's own API.

### Validation and application ownership

Every catalogue obligation is owned by its admitting feature, with final
aggregation in 106B. These groups map [§§18–22][diagnostics] without copying
their full validation tables:

| Candidate obligations | Implementation owners |
| --- | --- |
| §18 detection timing and transactions; §19 preserved expressions/types | 90A–90B, 91C; each new form supplies its diagnostics on admission. |
| §19 declaration/selector/body grammar and exclusions | 92–95, 98–100; 91A for bridge invariants, 103C for completed source rejection. |
| §21 construction/inference | 91A/91C checked boundaries, 92–94 products/variants/headers, 96 generic case alternatives, 99A factories, 100 protocol-guided construction. |
| §21 refinement/exhaustive control flow | 93 direct singleton payload access; 95 aliases/losses/joins; 96 explicit case; 97 defaults and growth; 98 table growth; 99A factory loss; 100 protocol-view loss and conformance rechecking. |
| §21 open protocols/extensions/transactions | 90B staging; 91A admitted single-claim/extension coherence; 99B full extensions; 100 multiple claims and open/closed growth. |
| §21 recursive values/equality/display/reflection | 90C specialized type retention; 91A product values; 91B exact authority/metadata; 93 closed variants; 94 instantiated nullaries; 101 Tree; 102 combined reflection evidence. |
| §21 mirrored invocation/Gel closure | 90C/91A retained value types; 91B sealed evidence/exact rows; 91C usable operation/all helpers/closure/host paths; 94 Some/None/Ok and typed empty inputs; 96 generic map; 99A factories; 102 cross-feature seal. |
| §21 preserved expressions/built-ins/host; §20 exclusions | Shared requirements throughout, initially 90A–91C. No optional built-in rewrite or expanded crossing is completion debt. |
| §22 Point and Boids | 92/94 semantic product examples; 103A migrated Point and both Boids step sends; 102 local-reflection seal; final runs in 106B. |
| §22 MPL | 90B checkpoint 36's concrete-field observations through checked contextual reflection; 91A combined coherence and raw migration; 100 protocol behavior; 103A application conversion, domain equality/identities and open Math; 106B final run. |
| §22 Option/Result and Tree | 104 canonical Option/Result; semantic prerequisites 94, 96–102. 101 owns recursive Tree values, methods, equality, raw, and nested elimination. |
| §22 Gel, filesystem, and Term | 91C helpers; 103B nominal Gel conversion; 105 pending Option; 106A filesystem classification. Host/Term preserved throughout, all guarded invocation routes covered in 91C/102 and sealed in 106B. |
| §22 migration, completion, and documentation | 103A–103B all executable source; 103C bridge removal/active syntax docs; 106B complete regressions, application observations, unified implementation and final documentation reconciliation. |

No required semantic choice was found missing during this dependency review.
If later expansion reveals a material contradiction, report it against the
candidate/audit before choosing a rule; an ordering note is not semantic
authority. The durable handoff and atomic ratification remain later 89-series
work. This roadmap awaits review and activates no implementation entry.

## Validation of this documentation slice

For the initial draft, the unchanged `raco test tests` suite passed:
**1,297 tests**. The exact
[checkpoint-88 Term hand check](checkpoints/0088-seal-typed-host-boundary.md#hand-check)
returned `'("sealed" "sealed\r\n")` using an in-memory output port.
Racket's default `/var/tmp` was unwritable; the suite used a fresh writable
directory under `/tmp` through `TMPDIR`. This was an environment adjustment.

Documentation checks verified local links and heading targets, reference
definitions, balanced fences, whitespace, 25 unique identifiers in dependency
order, and prerequisites/evidence for every entry. Review mapped the archived
arc and candidate obligations to owners, including moved prerequisites,
intermediate exclusions, U1 activation, migration, and bridge removal.
The candidate's semantic body, examples, and validation obligations are
unchanged; its diff is confined to status and pending-artifact references.
The initial untracked checkpoint's checksum is unchanged. `git diff --check`,
`git status --short`, and `git diff --name-only` confirm only the two allowed
work artifacts alongside that pre-existing input, with the new roadmap also
inspected directly.

The checkpoint-36 ownership correction reran documentation and diff checks.
Only this roadmap changed in that correction; the candidate and pre-existing
checkpoint input are unchanged. The regression suite and hand check results
above are from the initial draft and were not rerun for this correction.

These checks establish checkpoint-88 preservation and documentation integrity,
not execution of the future roadmap or validation of family semantics. The
draft is submitted for review without committing; handoff, ratification, and
implementation remain unperformed.

[candidate]: unified-nominal-adts-spec-candidate.md
[audit]: unified-nominal-adts-design-audit.md
[u1]: unified-nominal-adts-reflection-resolution-proposal.md
[sequence]: ../archive/unified-nominal-adts.md#safe-checkpoint-sequence
[declarations]: unified-nominal-adts-spec-candidate.md#3-family-declarations-and-callable-surfaces
[factories]: unified-nominal-adts-spec-candidate.md#factories
[case]: unified-nominal-adts-spec-candidate.md#4-exhaustive-receiver-anchored-case
[coverage]: unified-nominal-adts-spec-candidate.md#coverage-and-validity
[generics]: unified-nominal-adts-spec-candidate.md#5-types-generic-inference-and-constructor-refinements
[refinements]: unified-nominal-adts-spec-candidate.md#shallow-constructor-refinements
[recursion]: unified-nominal-adts-spec-candidate.md#6-direct-regular-recursion
[protocols]: unified-nominal-adts-spec-candidate.md#7-protocols-and-additive-extensions
[extensions]: unified-nominal-adts-spec-candidate.md#additive-define-methods
[checked]: unified-nominal-adts-spec-candidate.md#8-checked-programs-and-elaboration
[closure]: unified-nominal-adts-spec-candidate.md#inference-closure-and-source-aliases
[transactions]: unified-nominal-adts-spec-candidate.md#9-shared-descriptors-linking-and-transactions
[values]: unified-nominal-adts-spec-candidate.md#10-runtime-family-values-and-dispatch
[surfaces]: unified-nominal-adts-spec-candidate.md#callable-surfaces-and-closed-instance-representation
[reflection]: unified-nominal-adts-spec-candidate.md#14-family-aware-reflection
[integration]: unified-nominal-adts-spec-candidate.md#15-specialized-built-ins-and-typed-host-integration
[examples]: unified-nominal-adts-spec-candidate.md#16-candidate-examples
[gel-examples]: unified-nominal-adts-spec-candidate.md#gel-invocation-through-mirrors
[migration]: unified-nominal-adts-spec-candidate.md#17-reconciliation-and-compatibility-boundary
[diagnostics]: unified-nominal-adts-spec-candidate.md#18-diagnostics-and-detection-boundaries
[rejections]: unified-nominal-adts-spec-candidate.md#19-required-rejection-catalogue
[exclusions]: unified-nominal-adts-spec-candidate.md#20-consolidated-exclusions-and-deferrals
[u1-tests]: unified-nominal-adts-spec-candidate.md#mirrored-invocation-and-gel-inference-closure
[applications]: unified-nominal-adts-spec-candidate.md#22-application-validation-and-eventual-completion-evidence
[driver]: ../aloe/driver.rkt
[main]: ../aloe/main.rkt
[parse]: ../aloe/parse.rkt
[type]: ../aloe/type.rkt
[eval]: ../aloe/eval.rkt
[signature]: ../aloe/signature.rkt
[host]: ../aloe/host.rkt
[term]: ../host/racket/term.rkt
[term-run]: ../host/racket/term-run.rkt
[gel-run]: ../host/racket/gel-run.rkt
[list]: ../lib/list.aloe
[point]: ../examples/point.aloe
[boids]: ../examples/boids.aloe
[mpl]: ../examples/mpl/core.aloe
[stack]: ../gel/stack.aloe
[menu]: ../gel/menu.aloe
[loop]: ../gel/loop.aloe
[t8]: ../tests/checkpoint-8.rkt
[t16]: ../tests/checkpoint-16.rkt
[t36]: ../tests/checkpoint-36.rkt
[t57]: ../tests/checkpoint-57.rkt
[t60]: ../tests/checkpoint-60.rkt
[t73]: ../tests/checkpoint-73.rkt
[t87]: ../tests/checkpoint-87.rkt
