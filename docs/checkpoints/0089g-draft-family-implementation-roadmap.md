# Checkpoint 0089G — Draft the family implementation roadmap

Status: Proposed

Depends on: Checkpoint 0089F, including the adopted U1 resolution

## Goal

Turn the audited unified nominal ADT design into a small-step implementation
roadmap. Specify the order, prerequisites, observable completion evidence,
and temporary migration boundaries of the future implementation checkpoints.

This is one documentation slice. It produces a proposed sequence, not the
detailed instructions for implementing every future checkpoint. The durable
implementation handoff and atomic ratification remain later 89-series work.
Do not implement the roadmap or populate the active `CHECKPOINTS.md` yet.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
and runtime behavior remains exactly as implemented through checkpoint 88.
The accepted 89F audit establishes the semantic baseline; planning its
implementation does not authorize additional language choices.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, checkpoints
89A–89F, and these documents before drafting:

- `docs/unified-nominal-adts-spec-candidate.md`;
- `docs/unified-nominal-adts-design-audit.md`;
- `docs/unified-nominal-adts-reflection-resolution-proposal.md`; and
- `archive/unified-nominal-adts.md`.

Read the candidate and the archive completely. Decisions 1–10, as amended by
the user-approved U1 decision and adopted in 89F, supply the semantic contract.
Decision 10's provisional checkpoints 90–106, checkpoint discipline,
completion criteria, and implementation nucleus supply the starting sequence.
The archived blanket prohibition on runtime generic inference is qualified
only by U1's explicit sealed-input invocation rule.

Inspect the current parser, checker, evaluator, public source helpers,
driver, reflection, and host boundary enough to ground the transition plan.
Review the relevant historical tests and `lib/list.aloe`, `examples/point.aloe`,
`examples/boids.aloe`, `examples/mpl/`, and Gel's helpers and runners as needed.
Use actual repository evidence to identify prerequisites and migration
pressures; do not perform a new general code audit or design internal APIs.

The 89F audit and its accepted review are the completion evidence for that
slice. Historical instructions or checkpoint headers need not be rewritten
to make the roadmap's starting point clear. Record the initial worktree state
and preserve pre-existing changes without requiring a commit.

The transcripts in Git commit `8e6955c` and historical monolithic plan in
commit `8b2c155` remain non-normative. Do not restore or depend on them. If
planning exposes a material missing semantic rule or contradiction, report
the exact issue before choosing a rule or consulting transcripts. Continue
unaffected planning where possible. Ordinary subdivision and dependency
planning within the approved semantics do not require a new design decision.

## File scope

Create the proposed roadmap:

```text
docs/unified-nominal-adts-implementation-roadmap.md
```

The only other permitted implementation artifact is:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Limit candidate edits to its status, links, and pending-artifact references.
Do not change its semantic rules, examples, or validation obligations.
The roadmap must agree with the audited candidate; it cannot silently repair
or weaken it to make a sequence convenient.

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, `docs/gel.md`,
the audit report, the approved U1 decision, the archive, checkpoint documents,
source, tests, fixtures, libraries, examples, or applications. Do not create
the durable implementation handoff or detailed future checkpoint documents.

## Required roadmap

### 1. Status, entry conditions, and planning level

Give the roadmap a prominent proposed, non-normative status. State that the
runtime baseline is checkpoint 88 and the design baseline is the accepted
89F candidate including U1. Its entries are future work, not completed or
currently authorized implementation checkpoints.

Implementation requires completion of the remaining 89-series documentation
and later atomic ratification. The roadmap is intended for eventual promotion
into `CHECKPOINTS.md`, but that promotion does not happen in 89G. A plan's
existence is not authority to accept new syntax or begin checkpoint 90.

Use concise entries that a designer can later expand into individual checkpoint
documents. Every proposed implementation checkpoint needs:

- a stable provisional identifier and short outcome-based title;
- explicit prerequisites, including any supporting work allocated earlier;
- one coherent observable outcome and the boundary of the change;
- representative positive and rejection/preservation evidence, with links
  to the candidate's governing rules or validation obligations; and
- any migration, activation, or removal obligation needed for that slice.

State shared requirements once and reference them from entries. Do not repeat
the full specification or all validation tables for every checkpoint. Avoid
implementation algorithms, invented internal structure names, line-by-line
edit plans, future fixture filenames, or complete runnable test scripts.
Repository areas may be named where they explain a dependency or transition.

### 2. Cover the complete implementation arc

Account for every obligation in the archived 90–106 sequence through final
implementation validation. Preserve its broad dependency structure while
making necessary subdivisions and U1 dependencies explicit. Use these groups
as a coverage check, not as a mandatory one-checkpoint-per-row allocation:

| Implementation group | Required roadmap coverage |
| --- | --- |
| Checked execution | Checked/elaborated results, production drivers and source helpers, retained type information, inference closure, and checking transactions that prevent evaluation on failure. |
| Nominal foundation | Shared family, constructor, protocol, and row descriptors; exact identities and one runtime relation; temporary legacy lowering with no separate permanent ontology. |
| Product and variant core | Explicit one-constructor `new`, fields and uniform methods, multiple constructors and payloads, constructor integrity, structural equality, and raw/display separation. |
| Generics and refinement | Complete send headers, contextual construction, invariant arguments, fresh row parameters, branch constraints, closure, singleton knowledge, aliases, local surfaces, joins, and loss points. |
| Exhaustive elimination | Concrete scrutinees, explicit clauses and binders, exact coverage, one evaluation and one lazy branch, residual `else`, and coherent branch results. |
| Family behavior and extension | Complete per-constructor bodies, factories, type-object `self`, combined row validation, atomic additive extensions, and selector partitions. |
| Protocols and recursion | Multiple uniform family conformances, whole-domain coverage, overload/result coherence, complete-unit finalization, regular recursive payloads, and recursive values and consumers. |
| Reflection and host integration | Exact row authority and metadata, permitted family/type-object surfaces, closed multi-constructor representation, ordinary contextual operations, U1's `invoke-mirrored`, and preserved host guards. |
| Source migration and bridge removal | All repository-owned Aloe sources, fixtures, examples, tests, and applications; positional claims; source rejection after removal; one user nominal model internally and publicly. |
| Application validation and final seal | Point, both Boids steps, MPL, canonical Option/Result, Tree, Gel, filesystem classification, Term/host checks, migrated regressions, removal of transitional duplication, and final documentation reconciliation. |

Use the existing numeric anchors 90–106 where useful. Lettered subdivisions
may make an oversized checkpoint reviewable. For any split, moved prerequisite,
or changed allocation, record its reason and correspondence to the archived
sequence. Do not silently copy an unsafe ordering, create duplicate owners
for one deliverable, or leave work unassigned between entries.

Moving prerequisite support earlier does not require completing an entire
later feature there. Identify the minimum coherent capability and leave the
remaining feature work in its appropriate place. The resulting dependency
graph must be acyclic, with all prerequisites supplied before use. If a
transition must be atomic, explain why and keep its preparatory work bounded.

Do not renumber completed historical checkpoints, claim checkpoint 89 is
finished, or draft detailed later 89-series documents. The roadmap is a
proposal for review, not a replacement history of the project.

### 3. Resolve the U1 and inference-closure ordering

The roadmap must explicitly address the interaction that motivated U1.
Current Gel uses ordinary-result `invoke` and `subject` where source context
does not fix the intermediate types. The accepted design requires those
types to close and supplies `invoke-mirrored` for Gel's opaque flow.

Allocate the prerequisites, first usable invocation path, client transition,
and closure enforcement so the plan is executable. In particular:

- Sealed closed type evidence for families, collections including empty
  lists, and functions must be available before mirrored invocation relies
  on it. Exact owner/row identity and pre-execution guards are prerequisites,
  not obligations postponed until after calls are exposed.
- The fixed `Signature`/`(List Mirror)` operation, its Mirror result policy,
  and the three approved Gel helper rewrites must be available when enforcing
  closure would otherwise invalidate those helpers. Do not postpone this
  dependency automatically to the archived family-reflection checkpoint 102
  or Gel state checkpoint 105.
- Distinguish the small helper transition from the later nominal source
  migration and pending-state refactor. An earlier helper adaptation does
  not authorize redesigning Gel's state, keys, or UI.
- Account for historical tests and source expressions that rely on the old
  permissive reflection or empty-list inference. Preserve their valid
  behavioral intent with the approved mirrored or explicitly contextual
  route, and update rejection expectations where the approved language
  intentionally rejects the old form. Schedule those changes with the
  relevant enforcement step, not after knowingly breaking the suite.
- State when each guarantee becomes enforced. Preparatory work must not be
  reported as a completed checked boundary. Do not keep the transition green
  by exempting Gel, disabling required guards, accepting unresolved ordinary
  constructors, skipping tests, or maintaining a second permissive production
  path as the solution.

The new operation still has two fixed arguments and no operation-local type
parameters or type-header forwarding. Fresh selected-row parameters may
resolve only from the fixed owner and sealed, closed input evidence, before
execution. Missing result-only parameters still fail. Ordinary constructor
sends carry their resolved checked arguments; `subject` and ordinary-result
`invoke` retain closure. Metadata strings, payload scans, and executed results
are never substitutes for the approved evidence.

Plan useful input-determined generic coverage when its family/row support is
available, including `Some` and `map`, together with `None` and `Result.Ok`
insufficient-evidence rejection. Do not demand future family syntax in an
earlier primitive/legacy preservation test, or claim a generic guarantee from
only nongeneric examples.

### 4. Make all intermediate boundaries explicit

Audit the proposed sequence for dependencies beyond U1:

- Product construction must support the field/local behavior needed by its
  own validation. Distinguish inherently singleton products from the later
  general propagation of multi-constructor refinements.
- Once multiple constructors are admitted, identity, constructor integrity,
  structural equality, raw form, and the exclusion of local reflection must
  already be correct. A later reflection milestone cannot excuse an earlier
  representation leak or name-based owner check.
- Every admitted `case` is exhaustive and checks its branches. A split that
  adds defaults or richer joins later must reject unavailable forms rather
  than provide partial case or an order-dependent approximation. Coordinate
  generic branch constraints with the existing conditionals and later case
  forms that exercise them.
- Admitted conformance claims and extensions must have their required
  combined validation and transaction semantics. Do not temporarily accept
  missing obligations, replacement rows, or incoherent narrower results.
- Preserve exact host identity, injection preflight, guarded arguments and
  results, immutable crossing strings, causes, and breaks through descriptor
  changes. Specialized built-ins and the `List` extension route retain their
  contracts without a forced algebraic rewrite or expanded host crossing.

For each step, distinguish newly supported forms from later forms that remain
unavailable and rejected. Plan tests of the relevant boundary alongside the
feature. Required obligations may be delivered together when inseparable;
do not split them merely to make a checkpoint's description look smaller.

### 5. Bound migration and final completion

Give the temporary `define-class` bridge an explicit introduction point,
allowed role, and removal checkpoint. It lowers legacy declarations into the
same family model; it is not a second class runtime or a permanent source
compatibility promise. Identify what must be migrated before removal and how
the removal will be verified across public source entry points and repository
sources. A source bridge does not authorize retaining unrelated unsafe
inference behavior.

Schedule migrations where their dependencies require them. Explain how early
targeted adjustments relate to the later repository-wide conversion, without
doing the same migration twice or using a flag-day rewrite. Finish with
`define-family` as the sole user nominal declaration and explicit rejection
of legacy syntax; no indefinite bridge or dual ontology remains.

Map the candidate's section 22 application evidence to roadmap owners. In
particular, retain both Boids step sends, MPL's domain equality and open
protocol behavior, ordinary Option/Result families, regular Tree recursion,
Gel's pending `Option GelRow`, and the sealed Term boundary. A further Gel
state family is conditional on clarity. Preserve valid Gel flows and output
with the approved Mirror API menu addition stated explicitly.

The filesystem milestone validates a closed domain classification with
ordinary `Other`, local capabilities, and exhaustive consumers. It does not
choose an OS API, new host selectors, compound crossings, or opaque handles.
Built-in algebraic rewrites remain optional, not hidden completion debt.

End the roadmap with concrete evidence for the unified model: migrated
historical and new tests, required application runs, checked execution and
exact boundaries, removal of legacy acceptance and transitional duplication,
and documentation reflecting the implemented language. This later final seal
does not replace the prerequisite normative ratification before implementation.

## Candidate status and remaining boundary

Link the proposed roadmap from the candidate's status and pending-artifact
references. Record that 89G has drafted it while preserving 89F's completed
semantic audit, the incomplete/non-normative status, and the checkpoint-88
runtime baseline. Do not claim that roadmap review implements any semantic
validation obligation or reopens U1's already approved decision.

Reserve the durable implementation handoff and atomic ratification, including
eventual promotion of the reviewed sequence into `CHECKPOINTS.md`. Keep the
distinction between a drafted roadmap and an activated implementation plan.
Do not fill in the handoff or amend governing documents in this checkpoint.

If planning uncovers a new material semantic issue, report it with the affected
candidate/audit references. Do not change the audit's conclusions or silently
add an exception through a roadmap entry. Acceptance of 89G requires a coherent
plan under the approved design.

## Validation and acceptance

Before review:

- confirm this slice changes only the new roadmap and the candidate's
  status/links/pending-artifact prose, accounting for pre-existing changes;
- check complete mapping of the archived sequence, the candidate's validation
  obligations, U1, and required application evidence to proposed owners;
- verify unique identifiers, dependency order, explanations for subdivisions
  or moved prerequisites, safe transitions, and explicit bridge removal;
- verify the U1/helper/closure transition and other intermediate boundaries
  against actual current clients and the audited candidate;
- check that the roadmap is concise, non-normative, and contains no new
  semantic decision, internal API design, detailed checkpoint implementation,
  or already-completed claim for future work;
- check links, section references, status statements, and the revised pending
  boundary;
- run `git diff --check`, `git status --short`, and `git diff --name-only`,
  inspecting the new roadmap as well as the tracked diff; and
- run the established full regression suite (`raco test tests`) and the
  existing checkpoint-88 hand check without changing tests.

The hand check is the public driver/Term example under `Hand check` in
`docs/checkpoints/0088-seal-typed-host-boundary.md`. Its result remains
`'("sealed" "sealed\r\n")`, using an in-memory output port. If Racket's
default temporary directory is unwritable, use a fresh writable temporary
directory and report that environment adjustment separately.

The unchanged suite and hand check establish preservation for this
documentation slice; they do not validate future implementation entries.
Each later implementation checkpoint must add its relevant tests, run the
full suite and required hand observation, and stop for review when green.
The future test count is not fixed at the current baseline count.

Accept 89G only when the proposed sequence covers the entire approved arc,
has explicit and satisfiable prerequisites, keeps each step reviewable,
preserves semantic boundaries through migration, leaves no required work
unassigned, and passes the documentation checks, unchanged suite, and hand
check. No material design issue may be hidden in a deferral or ordering note.

Stop for review without committing. Do not implement the roadmap, author the
next checkpoint, write the durable handoff, promote the plan to
`CHECKPOINTS.md`, ratify the candidate, or begin checkpoint 90.
