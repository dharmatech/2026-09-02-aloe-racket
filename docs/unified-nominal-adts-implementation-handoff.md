# Unified nominal algebraic families: implementation handoff

> **ACCEPTED 89H HANDOFF — UPDATED FOR 89I RATIFICATION REVIEW**
>
> Runtime baseline: checkpoint 88. The 89F audit with approved U1, corrected
> 89G roadmap, and 89H handoff are accepted with no findings. [SPEC.md][spec]
> contains the normative target and [CHECKPOINTS.md][index] the governing
> implementation order in the 89I ratification change submitted for review.
> Acceptance completes checkpoint 89; 90A requires its own checkpoint document
> and authorization. No runtime implementation is supplied by this change.

Read in this order before expanding or implementing a future slice:

1. The complete [SPEC.md][spec], [philosophy](philosophy.md),
   [decisions](decisions.md), [AGENTS.md](../AGENTS.md), governing
   [CHECKPOINTS.md][index], and [runtime handoff](handoff.md).
   Read [Gel's contract](gel.md) when touching Gel.
2. The complete [accepted corrected roadmap][roadmap] and this handoff.
3. Use the [historical candidate and promotion map][candidate], [completed
   audit][audit], [approved U1 record][u1], [Decision 10][decision10], and
   [cross-decision guardrails][guardrails] for design provenance.
4. Read the particular authorized document under `docs/checkpoints/`, its
   prerequisites, and the current session's scope. [89I][checkpoint89i]
   records accepted entry conditions and the current review boundary.

## Authority and starting snapshot

SPEC is the single normative target; it does not claim the checkpoint-88
runtime already implements it. CHECKPOINTS governs order, while the roadmap
supplies detailed prerequisites, allocation rationale and evidence. Individual
checkpoint documents bound authorized changes. The historical candidate,
audit, and U1 record explain the accepted design, not a second evolving spec.
The archive supplies provenance and its original provisional sequence, not a
competing schedule. U1's sealed-input permission is the specific approved
amendment to its earlier runtime-inference prohibition.

As recorded by [89I][checkpoint89i], checkpoint 36's MPL observations belong
to **90B**, while Gel helpers and closure-sensitive reflection/empty-list
migrations remain in **91C**. Earlier review-stage wording is historical and
does not reopen those decisions. The transcripts in commit `8e6955c` and
monolithic plan in `8b2c155` are non-normative and are not sources to restore.

### Historical 89H starting snapshot

The starting worktree on **2026-09-07**, on `codex/unified-nominal-adts` at
`c20ab1f801b08b354e0d3629232f379181f1f903`, contained:

```text
 M docs/unified-nominal-adts-spec-candidate.md
?? docs/checkpoints/0089g-draft-family-implementation-roadmap.md
?? docs/checkpoints/0089h-draft-family-implementation-handoff.md
?? docs/unified-nominal-adts-implementation-roadmap.md
```

The candidate's existing status edits and corrected roadmap are accepted
prior work; the checkpoint documents are supplied inputs. That revision alone
does not contain all reviewed work. 89H added this handoff and updated
only candidate status, links, and pending-artifact prose. The existing
`docs/handoff.md` continues to describe the checkpoint-88 implementation.

### Current ratification boundary

The handoff review is complete. [89I][checkpoint89i] now supplies final
reconciliation and atomic promotion into SPEC and CHECKPOINTS as one change
submitted for review. Acceptance completes checkpoint 89. Before implementation,
verify that acceptance and the authorization of the specific next checkpoint.
90A needs its own document; it is not created or implemented here. This
prerequisite ratification remains distinct from 106B's final reconciliation
with the implemented language.

## Repository map at checkpoint 88

These are navigation points, not required replacement module boundaries or
an internal API design. The roadmap's [repository evidence][repository-evidence]
explains the dependencies in more detail.

| Area | Existing files and why they matter |
| --- | --- |
| Parsing and checking | [aloe/parse.rkt](../aloe/parse.rkt) reads source and lowers `let` early; [aloe/type.rkt](../aloe/type.rkt) owns inference, nominal declarations, overloads, and checking. 90A must retain source alias provenance and checked decisions, including the written function annotations already specified by [SPEC §1, fn](../SPEC.md#fn). |
| Evaluation and bootstrap | [aloe/eval.rkt](../aloe/eval.rkt), [aloe/env.rkt](../aloe/env.rkt), and [aloe/library.rkt](../aloe/library.rkt) implement execution, environments, and List bootstrap. Construction currently reconstructs type arguments from values; empty lists and functions lack the retained closed types needed by U1. |
| Public entry points and loads | [aloe/main.rkt](../aloe/main.rkt) exposes source/datum/program helpers; [aloe/driver.rkt](../aloe/driver.rkt) supplies CLI/REPL, loads, and host injection; [bin/aloe](../bin/aloe) enters that driver. Checking precedes evaluation of parsed expressions, and evaluation reads loaded source again. The target finalized checked transaction is future work, including bootstrap and transitive loads. |
| Reflection | [aloe/mirror.rkt](../aloe/mirror.rkt), [aloe/signature.rkt](../aloe/signature.rkt), and evaluator/checker reflection paths describe and invoke rows. The current separate user nominal models, name-based compatibility, and flattened row indices must give way to shared opaque identities and exact row authority. Ordinary `subject`/`invoke` can currently leave inference unresolved; `invoke-mirrored` is not yet available. |
| Sealed host boundary | [aloe/host.rkt](../aloe/host.rkt) already guards exact interface/row ownership, scalar crossings, and failures. [Term](../host/racket/term.rkt) supplies the explicitly injected capability; [term-run.rkt](../host/racket/term-run.rkt) and [gel-run.rkt](../host/racket/gel-run.rkt) use checked drivers. Preserve this exact host authority while replacing user nominal machinery. |
| Library and domain applications | [lib/list.aloe](../lib/list.aloe) supplies `fold`, `reverse`, and `map` through the existing List extension route. [Point](../examples/point.aloe) and [Boids](../examples/boids.aloe) exercise immutable generic products, lists, and both trailing step sends. [MPL core](../examples/mpl/core.aloe) links open `Math` and its domain operations through loads and extensions. Kernel raw printing currently has special Sum/Prod cases; their removal belongs to 91A. |
| Gel layers | [menu.aloe](../gel/menu.aloe) builds reflected rows; [stack.aloe](../gel/stack.aloe) owns the immutable Mirror stack and three invocation helpers; [loop.aloe](../gel/loop.aloe) owns keys, typed picks, pending state, and text; [main.aloe](../gel/main.aloe) composes the Term interaction. Pending is currently `(List GelRow)`. [docs/gel.md](gel.md) records the current flows and host/application split. |
| Regression evidence | Historical `tests/checkpoint-*.rkt` files cover the implemented arcs. [Checkpoint 36](../tests/checkpoint-36.rkt) contains the unchecked MPL observations; [73](../tests/checkpoint-73.rkt) exercises Gel invocation; [87](../tests/checkpoint-87.rkt) and [88](../tests/checkpoint-88.rkt) cover host reflection and sealing. Run `raco test tests` and the exact [checkpoint-88 hand check][hand-check]. |

## Target boundaries to retain

The following summarizes SPEC; its linked sections govern details.
All future family examples in [§16][examples], including the target helper
fragments, are **unimplemented**, not checkpoint-88 runnable goldens.

The [expression model][expressions] remains receiver-first sends with literal
selectors and left-to-right arguments. Functions run through `call`; `let`
has parallel binding and its existing `fn`/`call` runtime meaning. Values stay
immutable and Int-to-Float conversion stays explicit through `(n float)`.

[One nominal family model][ontology] covers products and closed variants.
Constructors are explicitly declared; `new` is only a convention, not an
implicitly supplied constructor. Opaque family, constructor, protocol, and
row identities carry authority. Family arguments are invariant, and ordinary
construction receives checked instantiations. [Shallow refinements][refinements]
control local lookup; direct immutable aliases can preserve them, while
annotations, declared results, general function boundaries, payload/List
storage, protocol views, and contextual unwrapping lose them as specified.

[Case][case] checks every branch and its result constraints symmetrically,
requires exhaustive coverage, and evaluates the scrutinee once and only the
selected branch. [Callable surfaces][declarations] remain distinct: local
rows have singleton `self`; a uniform whole-family body has the family view
(inherently singleton for a product); a complete per-constructor body table
gives each body its named singleton `self`. Factories use the family type
object as `self` and return their declared unrefined result. [Protocols and
extensions][protocols] require nominal, uniform conformance, full required
domains, combined overload/result coherence, and atomic additive validation.

[Regular self-recursive payloads][recursion] use the same full ordered family
arguments, including beneath List or function types. [Kernel equality][equality]
compares family identity, arguments, constructor, and payload structure, with
identity for opaque leaves. [Raw printing][display] is structural and does
not execute user behavior; normal display may use `show`. [Reflection][reflection]
uses exact owned callable rows, not names or menu positions. Multi-constructor
instances expose no discriminator, payload query, or local row authority,
even when the source expression has a singleton refinement.

[Checked-unit finalization][checked] and [transactions][transactions] prevent
evaluation on static failure and leave no partial static installation. A
loaded unit includes transitive loads; a REPL datum is its own transaction.
Effects after successful checking are not rolled back. [Specialized built-ins
and host integration][integration] retain their contracts, including the
existing List extension route. Preserve paired injection preflight, exact
interface ownership and target state, only `Int`/`Bool`/`String` crossings,
immutable crossing strings, argument guards before execution, result guards
afterward, retained failure causes, propagated breaks, and public/internal
sealing. The family transition supplies no additional host authority.

The [exclusions][exclusions] and [rejection catalogue][rejections] remain part
of each admitted feature: no second nominal ontology, permissive inference
escape, structural or orphan conformance, general subtyping, GADTs, mutual
recursion, public type universe, expanded host crossing, or required algebraic
rewrite of specialized built-ins. Preserve the complete catalogues by reference.

### U1: mirrored invocation and closure

The approved [§14 operation][mirrored-invocation] takes exactly a `Signature`
and `(List Mirror)` and returns `Mirror`. It has no operation-local type
parameters and forwards no type header to the selected row. Each invocation
resolves fresh selected-row parameters only from its exact owner's fixed
instantiation and sealed, closed input evidence, before execution. All required
parameters must resolve, including those used only in the result; an expected
`Mirror` supplies none of the missing information.

Input mirrors unwrap exactly once. Exact owner, row, arity, instantiated
argument types, and generic resolution are guarded before the selected row
runs. Validate the ordinary result against its fully instantiated type before
wrapping it once or reusing an already-Mirror result unchanged. Explicitly
mirroring a Mirror still lets an argument pass that object after one unwrap.
Family instantiations, invariant List element types (including empty lists),
and checked function arrows retain the evidence. Metadata strings, payload
scans, or executed callbacks/results cannot supply it. Ordinary construction,
ordinary-result `invoke`, and contextual `subject` retain [source closure][closure],
even inside an enclosing `Mirror of`.

Use the existing [before/after Gel helpers and generic examples][gel-examples].
The zero-argument helper gets `(List Mirror)` context for its empty argument
list; the Mirror-argument helper passes its mirror directly in the list; the
generic ordinary-argument helper wraps and delegates. The closed Mirror result
selects the exact `push` overload. Application call sites remain unchanged.

`Some` can determine `T` from an Int input or an already checked empty
`(List Int)`; an `(Option Int).map` row can determine fresh `U` from a checked
`(-> Int String)` function before calling it. `None` lacks `T`; `Result.Ok`
with an Int still lacks `E`; a result-only factory lacks input evidence.
Those calls fail before construction or body execution, even if a parameter
`accepts?` query succeeds. Contextual ordinary invocation or explicit ordinary
construction supplies the alternative when its required evidence is available.

The [Mirror API enumeration rule][enumeration] intentionally appends
`invoke-mirrored` after `messages`, `signatures`, `invoke`, `subject`, and `raw`.
Explicitly browsing a Mirror object therefore gains a menu row. Ordinary
subject menus and existing valid Gel keys, results, and emitted text retain
their contracts with that stated exception. This does not promise that every
generic row has enough evidence to execute in Gel.

## Following the accepted transition

Use the governing [25-entry index][index] together with the roadmap's
[detailed sequence][sequence], [allocation notes][allocation], and
[validation/application ownership table][ownership].
The following highlights boundaries without defining another sequence.

| Owner | Boundary to carry into its authorized checkpoint |
| --- | --- |
| 90A–90B | Retain checked decisions and source alias provenance before activating checked transactions across every production entry point. **90B migrates checkpoint 36's unchecked MPL concrete-field observations to checked contextual reflection**, preserving their valid observations when the source result has a protocol view. |
| 90C–91B | Retain collection/function types, establish the common nominal model and checked construction, and seal exact row/input evidence before exposing mirrored invocation. This preparation does not itself establish universal inference closure. |
| 91C | Activate `invoke-mirrored`, all three Gel helper rewrites, and closure together. Migrate closure-sensitive reflection/empty-list observations and preserve defensive runtime failure coverage at the same boundary. No Gel exemption or unchecked production alternative remains. Follow the roadmap's [atomic transition notes][atomic-u1]. |
| Each feature's first admission | Supply constructor integrity, reflection exclusions, complete symmetric case checking, and applicable conformance/extension guards immediately. Later forms stay rejected; a later seal cannot excuse an unsafe earlier approximation. |
| 91A and 103A–103C | The temporary source bridge lowers legacy declarations into the same family model. 103A migrates Point/Boids/MPL; 103B migrates the remaining repository-owned executable sources, including embedded Racket datums/strings and non-`.aloe` inputs. 103C removes the bridge and all public legacy acceptance, with active syntax documentation reconciled there. |
| 104–106B | Validate canonical ordinary Option/Result, Gel pending Option, filesystem classification, and the final implementation. Earlier Tree and application evidence retains its owner; built-in rewrites and a further Gel state family remain optional. 106B reconciles final documentation with actual implementation. |

Keep 91C's helpers, 103B's Gel declaration migration, and 105's pending change
to `(Option GelRow)` separate. Further Gel state work is conditional on making
the application clearer. 101 already owns recursive Tree values, methods,
equality, raw printing, and nested case; 104 does not delay or repeat that
semantic admission. Required application evidence includes Point, both Boids
steps, MPL's open Math/domain equality/`show`, Tree, Gel, and Term, with final
aggregation in 106B. 106A's filesystem classification uses ordinary `Other`,
local capabilities, and exhaustive consumers/defaults. It chooses no OS API,
host selector, or crossing mechanism.

If an entry needs subdivision later, preserve its dependencies and guards
through a reviewed checkpoint document. This handoff does not split, renumber,
expand, or reassign any accepted entry.

## Procedure for a future implementation task

1. Inspect the worktree, governing files, and existing accepted work. Preserve
   uncommitted inputs; a clean worktree or commit is not a prerequisite to
   reading the plan.
2. Find the particular authorized checkpoint under `docs/checkpoints/` and
   verify acceptance of 89I and completed prerequisites against CHECKPOINTS
   and the supporting roadmap. A planned entry is not authorization. The
   present boundary is 89I review, followed by a separately documented and
   authorized 90A; do not start it from the plan alone.
3. Implement that one slice with relevant tests. Follow its admitted boundary,
   preserved behavior, and required rejections. Historical syntax/inference
   tests migrate at their assigned owner while retaining valid behavioral
   purpose; runtime guards must not disappear behind unrelated static errors
   or skipped tests. Keep malformed-value/forged-authority probes internal.
4. Run the full suite and the checkpoint's required hand observation. Check
   the diff and report actual results, environment adjustments, and limits.
   Future test counts are not fixed.
5. Stop for review when green. Follow current session authorization for commits;
   do not continue automatically into another checkpoint.

If a semantic rule is missing or a material contradiction appears, report the
exact SPEC and provenance/roadmap references before choosing a rule. Continue
unaffected work and identify any blocker explicitly; preserve the approved
audit and plan. Ordinary implementation choices within an authorized slice
remain the implementer's responsibility.

### Current validation commands

From the repository root, with Racket on `PATH`, run the unchanged full suite:

```sh
raco test tests
```

If Racket's default temporary directory is unwritable, use a fresh writable
directory for that run:

```sh
aloe_validation_tmp=$(mktemp -d /tmp/aloe-validation.XXXXXX)
TMPDIR="$aloe_validation_tmp" raco test tests
```

Run the exact public injection/driver expression in the
[checkpoint-88 Term hand check][hand-check] from the repository root in Racket.
It uses an in-memory output port and supplied reader; the expected result is:

```racket
'("sealed" "sealed\r\n")
```

The [README driver commands](../README.md#driver), implemented by
[bin/aloe](../bin/aloe) and [aloe/driver.rkt](../aloe/driver.rkt), provide
current application smoke checks:

```sh
./bin/aloe
./bin/aloe --quit examples/boids.aloe
```

The first opens the REPL; the second loads Boids and exits. Optional physical
terminal commands are verified in the corresponding runner sources:

```sh
racket host/racket/term-run.rkt path/to/program.aloe
racket host/racket/gel-run.rkt
```

The first takes the path of an Aloe program; both require a real TTY for live
input and the optional `tui-term` dependency. Core Aloe, Boids, and MPL do not
load that package. The full suite includes Term integration tests, and the
in-memory hand check requires the Term module, which itself imports `tui/term`;
these checks use supplied readers and need no physical TTY. The dependency
is already available for these documentation checks. No package installation
or live TTY session is required for the 89H/89I documentation slices. Later
Gel checkpoints retain their own required live interaction evidence.

## Validation of this documentation slice

### Historical 89H validation

The record below preserves checks and review status at the end of 89H.

The [89G report][baseline-validation] reports **1,297 passing tests** for the
unchanged baseline. That earlier run is separate from this slice's checks
and from future validation of unimplemented family semantics.

In 89H on 2026-09-07, the unchanged full suite was run again and passed:
**1,297 tests**. Racket's default `/var/tmp` was unwritable, so the run used a
fresh writable directory under `/tmp` through `TMPDIR`. The exact checkpoint-88
hand check passed with `'("sealed" "sealed\r\n")`. No package was installed
and no live TTY interaction was run. Other current command spellings were
verified against README and runner/driver source, not separately exercised.

Documentation checks passed for local links, heading targets, reference
definitions, code fences, and whitespace. The reader walkthrough verified
the runtime/design/plan dispositions, remaining ratification, checkpoint and
prerequisite lookup, validation instructions, and review stopping rule.
Cross-checks against the candidate and roadmap preserved U1, the 90B/91C
ownership distinction, bridge removal, and application boundaries.

The candidate's semantic body, examples, and validation obligations compare
unchanged to the starting snapshot. Checksums preserve every other pre-existing
repository file, including the accepted roadmap, audit, U1 record, archive,
governing documents, and supplied checkpoints. The new handoff and candidate
diff were inspected directly; `git diff --check`, `git status --short`, and
`git diff --name-only` confirm the permitted scope when accounting for the
initial uncommitted work.

These checks establish documentation integrity and checkpoint-88 preservation,
not future family validation or activation. This draft is submitted for review
without committing, ratifying the candidate, creating another checkpoint, or
starting 90A.

### 89I starting state and validation

89I began on 2026-09-07 at `616c0ceecd7d52d7f9c3e2c4df89e9037ed57aaa`
on `codex/unified-nominal-adts`. The index and tracked worktree were unchanged;
the sole untracked input was:

```text
?? docs/checkpoints/0089i-ratify-unified-family-design.md
```

That supplied checkpoint is preserved. Starting copies of the governing and
design documents, tracked/index diffs, status, and repository checksums were
recorded for comparison. Historical bare SPEC section numbers refer to that
revision. The current candidate [promotion map][candidate] records all 22
target sections and the dispositions of preserved and superseded old rules.

The unchanged full suite, `raco test tests`, passed **1,297 tests** for 89I.
A fresh writable directory under `/tmp` was supplied as `TMPDIR` because the
default `/var/tmp` is not writable in this environment. The exact
[checkpoint-88 Term hand check][hand-check] also passed with
`'("sealed" "sealed\r\n")`, using the installed `tui-term` package and supplied
reader, without a live TTY or package installation. These are preservation
results for the checkpoint-88 runtime, not acceptance of future syntax or
family semantics.

Documentation and preservation checks passed:

- Walked the promotion map in both directions against the starting candidate
  and old SPEC, including preserved forms, primitive operations, Point/Boids
  observations, typed-host rules, U1 examples, diagnostics, exclusions, and
  future validation obligations. No material contradiction or missing decision
  remained. Current authority/status searches distinguish historical wording
  from the normative target, unchanged runtime, and pending 89I review.
- Compared candidate sections 1–22 byte-for-byte with their starting text.
  All 25 detailed roadmap entries remain byte-for-byte unchanged; allocation
  and ownership differ only in authority labels. The governing index contains
  those entries once each in the accepted order, with preceding prerequisites
  and links to their specific support. Historical index text and the 89G/89H
  validation records are preserved.
- Checked local links, anchors, section labels, fences, table structure, and
  whitespace in all ten permitted documents. All original candidate Aloe
  blocks are retained exactly in SPEC; its 29 Aloe blocks pass the s-expression
  reader. That reader check establishes neither parser acceptance nor execution.
- Inspected the staged and unstaged diffs, status, and changed-file list against
  the starting state; `git diff --check` passed. Checksums confirm that every
  existing file outside the ten permitted documents, including the supplied
  untracked checkpoint, is unchanged. The index remains unchanged, and no new
  repository artifact was created.

Review remains pending. No staging, commit, next checkpoint, source migration,
or runtime implementation is part of 89I. Acceptance completes checkpoint 89;
90A still requires its own checkpoint document and authorization.

[candidate]: unified-nominal-adts-spec-candidate.md#promotion-map
[audit]: unified-nominal-adts-design-audit.md
[u1]: unified-nominal-adts-reflection-resolution-proposal.md
[roadmap]: unified-nominal-adts-implementation-roadmap.md
[checkpoint89h]: checkpoints/0089h-draft-family-implementation-handoff.md
[decision10]: ../archive/unified-nominal-adts.md#decision-10-static-and-implementation-consequences
[guardrails]: ../archive/unified-nominal-adts.md#cross-decision-guardrails
[repository-evidence]: unified-nominal-adts-implementation-roadmap.md#repository-evidence-that-affects-ordering
[expressions]: ../SPEC.md#1-preserved-expression-model
[ontology]: ../SPEC.md#2-one-nominal-family-ontology
[declarations]: ../SPEC.md#3-family-declarations-and-callable-surfaces
[case]: ../SPEC.md#4-exhaustive-receiver-anchored-case
[refinements]: ../SPEC.md#shallow-constructor-refinements
[recursion]: ../SPEC.md#6-direct-regular-recursion
[protocols]: ../SPEC.md#7-protocols-and-additive-extensions
[checked]: ../SPEC.md#8-checked-programs-and-elaboration
[closure]: ../SPEC.md#inference-closure-and-source-aliases
[transactions]: ../SPEC.md#9-shared-descriptors-linking-and-transactions
[equality]: ../SPEC.md#12-kernel-equality
[display]: ../SPEC.md#13-raw-and-user-facing-display
[reflection]: ../SPEC.md#14-family-aware-reflection
[mirrored-invocation]: ../SPEC.md#invocation-with-mirrored-arguments-and-result
[enumeration]: ../SPEC.md#argument-acceptance-and-enumeration
[integration]: ../SPEC.md#15-specialized-built-ins-and-typed-host-integration
[examples]: ../SPEC.md#16-target-examples
[gel-examples]: ../SPEC.md#gel-invocation-through-mirrors
[rejections]: ../SPEC.md#19-required-rejection-catalogue
[exclusions]: ../SPEC.md#20-consolidated-exclusions-and-deferrals
[sequence]: unified-nominal-adts-implementation-roadmap.md#proposed-sequence
[allocation]: unified-nominal-adts-implementation-roadmap.md#allocation-changes-and-dependency-closure
[ownership]: unified-nominal-adts-implementation-roadmap.md#validation-and-application-ownership
[atomic-u1]: unified-nominal-adts-implementation-roadmap.md#the-atomic-u1-and-closure-transition
[hand-check]: checkpoints/0088-seal-typed-host-boundary.md#hand-check
[baseline-validation]: unified-nominal-adts-implementation-roadmap.md#validation-of-this-documentation-slice

[spec]: ../SPEC.md
[index]: ../CHECKPOINTS.md#future-family-implementation
[checkpoint89i]: checkpoints/0089i-ratify-unified-family-design.md
