# Checkpoint 0089I — Reconcile and ratify the unified family design

Status: Proposed

Depends on: accepted 0089H handoff, corrected 0089G roadmap, and completed
0089F audit including the approved U1 amendment

## Goal

Finish checkpoint 89's documentation work by promoting the audited design
into `SPEC.md`, promoting the accepted implementation sequence into
`CHECKPOINTS.md`, and reconciling the documents that direct future work.
Submit one coherent ratification change for review.

This slice integrates decisions already made. It introduces no new language
choice, source acceptance, runtime behavior, migration, or test change.
The larger edit belongs in `SPEC.md`; the other edits are bounded authority,
status, navigation, and historical-reconciliation updates. Do not repeat the
89F design audit or expand the 89G roadmap into detailed future checkpoints.

Ratification establishes the normative target for implementation. The runtime
remains complete through checkpoint 88 and does not yet implement the family
model. A ratified plan does not authorize executing all of its entries.
Acceptance of this slice completes checkpoint 89's design/documentation arc;
90A remains the next planned implementation slice, requiring its own checkpoint
document and authorization. Do not create or implement that document here.

## Authority and starting point

Read these documents completely before editing:

- `AGENTS.md`, `SPEC.md`, and `CHECKPOINTS.md`;
- `docs/unified-nominal-adts-spec-candidate.md`;
- `docs/unified-nominal-adts-design-audit.md`;
- `docs/unified-nominal-adts-reflection-resolution-proposal.md`;
- `docs/unified-nominal-adts-implementation-roadmap.md`; and
- `docs/unified-nominal-adts-implementation-handoff.md`.

Also read `docs/handoff.md`, `docs/philosophy.md`, `docs/decisions.md`,
`README.md`, `docs/gel.md`, and the checkpoint-88 hand check. Consult
candidate section 17 and the archive's Decision 10, compatibility boundary,
checkpoint discipline, and completion criteria for the promotion's context.
Earlier checkpoint documents and other archive decisions supply provenance
when needed; conversation transcripts are not required inputs.

The starting dispositions are settled:

- 89F's audit is complete; U1 was approved, adopted, and rechecked.
- The corrected 89G roadmap is accepted with no remaining finding.
  Checkpoint 36's MPL observations move to checked contextual reflection in
  **90B**. Gel helpers and closure-sensitive reflection/empty-list migrations
  remain in **91C**.
- The 89H implementation handoff is accepted with no findings. Its remaining
  boundary is this final reconciliation and ratification.

Historical “proposed,” “in progress,” or “drafted for review” text records
earlier stages and does not require those decisions to be approved again.
This checkpoint records the accepted entry conditions for a fresh task.
The transcripts in commit `8e6955c` and monolithic plan in `8b2c155` remain
non-normative; do not restore them or use them to supply a missing rule.

Record the starting revision, working-tree and index state, and the content
of inputs needed for comparison. Preserve existing staged and unstaged work;
compare this slice with that starting state, not merely with `HEAD`. Do not
require a clean worktree or stage, unstage, or commit changes as part of this
checkpoint.

If reconciliation exposes a material semantic contradiction or missing
decision, report the exact sources before choosing a rule. Continue unaffected
preparation, but do not present a partial promotion as completed ratification.
Ordinary editorial organization, terminology, and link repair within the
approved semantics are authorized work.

## File scope

Only these files may change:

| File | Permitted change |
| --- | --- |
| `SPEC.md` | Integrate the complete normative target and all unaffected existing contracts. |
| `CHECKPOINTS.md` | Record the 89-series documentation arc and promote the reviewed future sequence, preserving historical entries. |
| `docs/unified-nominal-adts-spec-candidate.md` | Update current status/pending prose and add a concise promotion map outside the preserved semantic body. Retain it as a non-normative historical candidate. |
| `docs/unified-nominal-adts-implementation-roadmap.md` | Reconcile current authority/status and links after promotion; preserve every entry's substance and allocation. |
| `docs/unified-nominal-adts-implementation-handoff.md` | Reconcile current authority, reading order, links, remaining boundary, and this slice's validation record. Preserve its implementation guidance and historical observations. |
| `docs/handoff.md` | Distinguish the normative target from the current runtime and direct future tasks to the accepted implementation handoff and checkpoint index. |
| `docs/decisions.md` | Add a concise dated ratification decision and identify superseded experimental decisions without rewriting their history. |
| `docs/philosophy.md` | Reconcile current nominal terminology and kernel summary with the approved design while preserving the existing principles. |
| `README.md` | Update status/navigation and identify the current runtime examples as such. Preserve working commands and current application claims. |
| `docs/gel.md` | Add the bounded target-transition/authority note described below; retain current key, state, output, and runner documentation. |

Do not edit the archive, 89F audit, approved U1 record, `AGENTS.md`, historical
checkpoint files, release journals, or any source, tests, fixtures, libraries,
applications, scripts, dependencies, or host modules. Create no new report,
specification alternative, checkpoint, or release/version tag. Keep the current
candidate path and anchors available for historical references.

## Required reconciliation

### 1. One normative specification

Make `SPEC.md` the complete normative language target, integrating the
candidate's sections 1–22 with the unaffected existing specification. Preserve
the approved contract, examples, diagnostics, exclusions, and validation
obligations; do not merely link readers to a still-non-normative candidate
for the definition of a language rule.

Organize the material for a reader implementing the language. Reuse approved
text where useful, replace candidate-only wording with normative wording, and
repair internal section references. Keep implementation layout choices open.
Implementation-specific navigation belongs in the handoff; the detailed
sequence belongs in the roadmap/index, not in the language's grammar.

Replace superseded normative rules rather than appending a contradictory new
chapter. In particular, reconcile:

- class declarations, class-level fields, generated `new`, and positional
  single-protocol claims with explicit family/constructor grammar;
- source type grammar, constructor inference, full send type headers, fresh
  row parameters, refinement propagation/loss, and inference closure;
- selector-based ordinary overload selection with checked row obligations,
  constructor-local authority, and exact reflected invocation;
- early `let` lowering and the old parse/check/interpreter sketch with source
  alias provenance, checked elaboration, linking, and transactional finalization;
- permissive descriptions of `subject`, ordinary `invoke`, and unconstrained
  empty lists with the approved closure rules and explicit U1 operation; and
- outdated exclusions for required protocol rows or multiple conformances,
  and branch-specific/version-experiment declarations of what is normative.

Preserve all unaffected details that the candidate summarizes rather than
fully spells out. This includes the existing `define`/`fn` syntax and optional
annotations, function `call`, parallel `let`, lazy `if`/`cond`, protocol
declaration signatures and empty markers, `load` path/shared-environment rules,
and `check` evaluation order, returned value, and failure observations. Retain
numeric and List operations, explicit conversion, Symbol behavior, existing
String/display contracts, and the complete typed-host boundary. Do not invent
new primitive messages, inference constraints, protocol syntax, or host APIs
while filling in preserved material.

Keep U1 exact: the fixed `Signature`/`(List Mirror)` operation returns `Mirror`
with zero operation-local parameters and no header forwarding. Selected-row
parameters resolve only from fixed owner and sealed closed input evidence
before execution; arguments unwrap once and results are validated before
wrapping or Mirror reuse. Ordinary construction, `subject`, and ordinary-result
`invoke` retain closure. Preserve generic success/failure examples, exact
metadata, the three approved Gel helpers, and the Mirror API menu addition.

Preserve kernel equality versus user domain `=`, structural raw versus `show`,
opaque identity versus descriptive names, family versus protocol views, and
the exclusion of multi-constructor locals from reflection. Preserve specialized
built-ins, the List extension route, host ownership/injection/guards, and the
deliberately limited crossing vocabulary. Required application evidence still
includes both Boids steps, MPL, ordinary Option/Result, Tree, Gel, filesystem
classification, and Term; none is newly claimed implemented.

### 2. Normative target versus implemented state

Give `SPEC.md` a prominent implementation-status note: this change specifies
the unified target; executable behavior remains at checkpoint 88. Separate
normative requirements and future acceptance examples from current runnable
observations. Do not invent a release number or claim the prototype now
accepts `define-family`, `case`, send headers, or `invoke-mirrored`.

The completed language rejects `define-class`. Its temporary bridge is
development sequencing only: introduction in 91A, migration in 103A/103B,
removal in 103C, and no second user nominal runtime. Describe that boundary
without adding legacy syntax to the target grammar or requiring its rejection
by the unchanged checkpoint-88 parser today.

Retain the existing Point/Boids positive and negative observations under
their stated definitions/type context. Normative target examples use explicit
family declarations; existing repository examples remain current runtime
programs until their assigned migration. Do not rewrite those source files
or erase their validation obligations to make the documentation appear done.

The distinction also applies to known implementation gaps such as written
function annotations, retained value types, and strict closure. Their approved
roadmap owners remain responsible. A passing old suite does not demonstrate
that the new normative target is implemented.

### 3. Promote the accepted implementation sequence

Extend `CHECKPOINTS.md` without renumbering or rewriting completed historical
entries. Label the historical portion and its stage-specific terminology.
Add a compact account of checkpoint 89 and its 89A–89I documentation slices,
with links to the checkpoint documents and durable artifacts. Distinguish
accepted 89A–89H work from this ratification change's pending review.

Promote all **25** roadmap entries, preserving their identifiers, order,
prerequisites, coherent outcomes, and migration/activation/removal boundaries.
Each index entry must identify its outcome and prerequisite relationship and
link to its detailed roadmap entry. Shared validation requirements may be
stated once; do not paste the roadmap's full evidence tables into the index.

`CHECKPOINTS.md` becomes the governing implementation order; the accepted
roadmap retains the supporting allocation rationale and evidence. Keep the
two consistent. Do not re-split checkpoints, silently move obligations, or
turn planned entries into completed work or blanket execution permission.
Preserve the 90B/MPL correction, 90C–91B evidence prerequisites, atomic 91C
U1/Gel/closure transition, immediate feature guards, and explicit 103C removal.
Preserve later application owners and 106B's final implementation seal.

### 4. Reconcile authority and preserve design provenance

Retain the candidate's semantic body, examples, and validation catalogues as
the accepted pre-ratification record. Change its front status and pending
prose to identify the promotion into `SPEC.md` and its historical,
non-normative role. Do not silently maintain two evolving normative specs.
Stage-specific statements within its preserved body remain historical.

Add a compact promotion map in the candidate's closing metadata: map every
candidate section 1–22 to its new normative location, and account for preserved
old-SPEC material and deliberately superseded rules. Use meaningful links and
brief dispositions, not copied rules or a second audit report. This map must
make omissions and changes of meaning reviewable.

Update the roadmap and implementation handoff's current banners, authority
descriptions, reading order, and pending instructions. Language-law references
should lead to the promoted `SPEC.md`; the candidate, audit, and U1 record
remain available as provenance. Adjust visible section labels as well as
link destinations when numbering changes. Preserve roadmap entries, allocation
and evidence, handoff transition guidance, historical worktree snapshots, and
the records of checks actually performed in 89G/89H.

The 89F audit and U1 record remain unchanged. Do not reinterpret their old
“later work” text as a reopened decision. Do not erase the before/after Gel
examples or require conversation access to recover U1's approved resolution.

Use consistent review status across the changed documents: this ratification
change is submitted for review, not already accepted by a reviewer. Its
acceptance completes checkpoint 89. Replace instructions that say another
unspecified 89-series artifact still needs to supply the same ratification;
retain the ordinary review boundary and the requirement for a separately
authorized 90A checkpoint. No new approval ceremony or commit is required
inside this documentation slice.

### 5. Reconcile the surrounding entry documents

Keep these edits short and tied to the promotion:

- In `docs/handoff.md`, separate runtime-through-88 facts from the normative
  family target and completed design work. Link the detailed family handoff
  and governing checkpoint order. Preserve current host and workflow guidance.
- In `docs/decisions.md`, add one dated decision explaining the unified model,
  U1, staged migration/removal, and specification-before-implementation rule.
  Identify superseded experimental class/protocol limitations as historical;
  retain their original rationale and the unchanged host-capability decision.
- In `docs/philosophy.md`, reconcile the kernel/nominal summary with explicit
  families, constructors, and approved case syntax while retaining send/call,
  immutability, application-driven growth, and the host/application boundary.
- In `README.md`, make the target/runtime distinction and navigation clear.
  Keep existing commands and current class-based examples runnable and label
  their baseline instead of replacing them with unimplemented syntax.
- In `docs/gel.md`, record the approved future mirrored helper transition,
  later pending `Option GelRow`, and intentional Mirror API menu addition,
  with their roadmap owners. Preserve current application documentation and
  explicitly keep additional state restructuring optional. Clarify that this
  documentation slice needs the suite and in-memory Term check, not a new
  live TTY session. Do not redesign keys, output, host capabilities, or UI.

Check inbound references before restructuring `SPEC.md`. Repair links in
permitted files and preserve meaningful existing anchors where historical
documents depend on them. A compatibility anchor may identify the relevant
preserved rule or clearly scoped historical transition; it must not silently
point at an unrelated new section. Historical bare section numbers refer to
the pre-ratification specification; record its revision for provenance rather
than rewriting old checkpoints or journals.

## Validation and acceptance

Before review:

- Confirm the change is confined to the ten permitted documents, accounting
  for existing work and staged content. Compare candidate semantics and
  roadmap substance to the starting snapshots; explain only authorized
  status/link/promotion changes. No source or test changes are permitted.
- Walk the promotion map in both directions: every candidate obligation has
  a normative home, every retained old-SPEC contract is covered, and no
  promoted rule lacks an approved source. Check examples, rejection timing,
  exclusions, and future validation obligations as well as prose summaries.
- Verify all 25 future identifiers occur once in the governing index in the
  accepted order, with satisfiable prerequisites and unchanged ownership.
  Historical entries remain historical, and no future entry is marked done.
- Read the changed documents as a fresh task. Confirm one normative language
  source, one governing implementation order, clear provenance, the unchanged
  runtime baseline, and the post-review boundary at a separately authorized
  90A. Search for stale authority claims without deleting historical uses.
- Check links, anchors, section labels, code fences, whitespace, and the
  distinction between runnable current examples and future normative examples.
  Reader/grammar checks of future examples do not establish runtime acceptance.
- Run `git diff --check`, inspect staged and unstaged diffs as applicable,
  `git status --short`, and `git diff --name-only`; inspect changes against
  the recorded starting state and account for any new/untracked inputs.
- Run the unchanged full suite (`raco test tests`) and the exact
  [checkpoint-88 Term hand check](0088-seal-typed-host-boundary.md#hand-check).
  Its in-memory result remains `'("sealed" "sealed\r\n")`. Use a fresh
  writable `TMPDIR` if needed and report that environment adjustment.

The baseline report is 1,297 passing tests; record this slice's actual result
separately in the implementation handoff. Preserve prior validation records.
The Term module and integration tests need the installed `tui-term` package,
but supplied readers avoid a physical TTY. No package installation or live
terminal run is required for this documentation change.

Accept 89I when the complete approved design is expressed coherently in
`SPEC.md`, the accepted sequence is promoted, the entry documents and handoffs
agree, preservation/documentation checks pass, and no semantic issue remains
unresolved. Acceptance completes checkpoint 89, not implementation of the
family model. The unchanged tests provide preservation evidence only.

Stop for review without committing. Do not create the 90A checkpoint, begin
runtime implementation, migrate source, change tests, or proceed to a later
checkpoint. If a material contradiction prevents promotion, report it and
leave completion explicitly pending rather than ratifying only part of the
document set.
