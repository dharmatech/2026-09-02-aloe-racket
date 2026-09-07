# Checkpoint 0089F — Audit the unified family design

Status: In progress — U1 design resolution approved; adoption and audit recheck pending

Depends on: Checkpoint 0089E

## Goal

Audit the complete unified nominal ADT specification candidate against the
approved Decisions 1–10, the subsequently approved U1 resolution below, the
preserved current language, and the boundaries established by checkpoints
89A–89E. Establish whether its rules, examples, diagnostics, exclusions,
and validation obligations form a consistent and
sufficiently explicit account of the proposed language.

Produce a traceable audit record, make bounded, unambiguous candidate
corrections justified by the existing design, and incorporate the explicitly
approved U1 amendment. This checkpoint reviews and reconciles the
specification; it does not choose additional semantics, implement family
behavior, or prove that the proposed type system is sound.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
and runtime behavior remains exactly as implemented through checkpoint 88.
The implementation roadmap, durable handoff, and atomic ratification remain
later 89-series work. Passing this audit does not complete checkpoint 89.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, checkpoints 89A–89E,
`docs/unified-nominal-adts-spec-candidate.md`, and
`archive/unified-nominal-adts.md` completely before editing.

The accepted candidate through 89E is the audit baseline. Read all ten
decisions, including their later concrete syntax and implementation
consequences, rather than treating an early summary as the complete rule.
Also review the archive's cross-decision guardrails and completion criteria.

For resumption, also read the existing audit record and the complete
[approved U1 decision](../unified-nominal-adts-reflection-resolution-proposal.md).
The initial audit already produced corrections C1–C6 and finding U1. Preserve
that work and continue from it. The user approved U1's design resolution after
reviewing the Gel code comparison and generic rule; incorporating this
specific amendment is authorized. It supersedes the conflicting archived and
candidate reflection/closure wording only as specified in that decision.

Use the current specification and relevant repository evidence to verify
preserved behavior. Consult `docs/checkpoints/0088-seal-typed-host-boundary.md`,
`docs/handoff.md`, and `docs/gel.md`, and inspect implementation, tests, and
application examples where needed to resolve what currently exists. Current
implementation behavior does not override an intentional approved language
change or decide an unspecified future family behavior.

The transcripts in Git commit `8e6955c` and historical monolithic plan in
commit `8b2c155` remain non-normative. Do not restore them or make the candidate
depend on them. If the archive, accepted candidate, current specification,
and repository leave a material semantic ambiguity or contradiction, record
and report it before consulting transcripts or choosing a rule. Continue
independent audit work where possible, but do not mark the audit complete
while the issue requires a design decision.

Record the starting worktree state. Previously accepted documentation may
still be uncommitted; distinguish it from this checkpoint's changes without
requiring a commit, reverting it, or claiming it as new audit work.

## File scope

Create the audit record, or continue the existing record when resuming:

```text
docs/unified-nominal-adts-design-audit.md
```

The only other permitted implementation artifact is:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Limit candidate edits to the corrections, approved U1 adoption, and status
reconciliation described below. Keep the audit trail in the separate report
so that the candidate remains specification prose rather than a review
transcript. Treat the approved U1 decision record as read-only input.

Do not edit `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`, `docs/gel.md`,
the archive, checkpoint documents, source, tests, fixtures, libraries,
examples, or applications. Do not create a roadmap, implementation handoff,
test plan, migration patch, or additional checkpoint document.

## Resuming 89F with the approved U1 resolution

Resume this checkpoint; do not start a new 89-series slice. Adopt the complete
[approved decision](../unified-nominal-adts-reflection-resolution-proposal.md)
in the candidate, then recheck the affected audit conclusions. The decision
record includes the authoritative before-and-after Gel fragments, generic
examples, result policy, and future validation obligations.

Required adoption is:

- Add the ordinary `Mirror` operation
  `(receiver invoke-mirrored signature arguments)`, with fixed parameters
  `Signature` and `(List Mirror)`, result `Mirror`, no operation-local type
  parameters, and reflection role `operation`. It has no variadic signature
  convention or special forwarding of a type header to its selected row.
- Preserve exact owner/row authority and ordinary evaluation order. Unwrap
  each argument mirror exactly once within the guarded boundary. Validate
  the fully instantiated ordinary result before returning that same result
  if it is already a Mirror, or otherwise returning a mirror of it. Preserve
  explicit mirroring of a Mirror object and the existing host guards.
- Permit this new operation to instantiate its opaque selected row using
  fixed owner arguments and sealed, closed type evidence for mirrored
  inputs. Require complete, consistent resolution before running the row.
  Existing checked types, not descriptive symbols, payload scans, or executed
  callbacks/results, supply that evidence. Invariance, nominal compatibility,
  and fresh invocation bindings remain in force.
- Keep ordinary constructor elaboration, contextual `subject`, and
  ordinary-result `invoke` subject to the existing closure requirements.
  An outer result type of `Mirror` supplies no missing target-row parameter.
  `Option.None` with no evidence and `Result.Ok` with only an Int argument
  still fail on this path; input-determined `Some` and `map` remain useful.
- Include the approved Gel before-and-after comparison and unchanged
  application call sites as future examples. Explain the contextual
  `(List Mirror)` empty list and the shorter ordinary-argument delegation.
  Preserve already-Mirror results rather than accidentally double wrapping
  them. Do not edit Gel source in this checkpoint.
- Add the operation after existing Mirror API rows and document its exact
  metadata. Ordinary subjects gain no new row; explicitly browsing Mirror's
  own API gains the new entry. Reconcile preservation wording accordingly,
  without claiming that the extended API's introspection text is unchanged.

Reconcile all affected rules and references together, particularly sections
8, 14, 16, and 18–22 and any integration or generic statements they depend
on. The exception is the explicit guarded reflection operation; do not turn
it into a general runtime inference fallback or a source dynamic/type-token
facility. Make the candidate self-contained rather than relying on the
decision record to supply omitted semantics.

Update the audit's decision coverage, interaction conclusions, examples,
validation obligations, and status to reflect the adopted text. Preserve U1's
original evidence and distinguish its approved semantic amendment from
bounded corrections C1–C6. Record the approval source and final disposition;
do not erase the finding or keep reporting its already answered question as
an unresolved user decision. New material issues must still be reported.

Reuse unaffected audit work. Recheck every conclusion touched by the amendment,
including the absence of unknown intermediate source types in Gel's revised
helpers, generic failures before row execution, Mirror-result handling, and
reflective metadata/ownership. Complete the remaining validation below and
mark the audit complete only when those checks support it. Approval of U1
does not itself complete 89F or ratify the candidate.

## Required audit

### 1. Decision coverage and specification completeness

Build a compact coverage table in the audit record. For every decision,
identify its governing archive subsections, the candidate sections that
express it, and the audit conclusion. Link to document headings where
practical. A section number alone is a locator, not evidence of agreement:
state what was checked and record discrepancies where present.

Use the following subjects as the minimum coverage, not as a replacement for
reading each decision:

| Decision | Required audit coverage | Starting candidate sections |
| --- | --- | --- |
| 1: Ontology | One nominal family identity; one-constructor products and closed variants; constructor sets as internal knowledge; separation of family and local surfaces. | 2–5, 10–11 |
| 2: Construction and type objects | One type object per declaration; explicit constructors, including product `new`; ordinary factories; generic evidence and unresolved construction. | 2–3, 5, 8, 10, 14 |
| 3: Messages and refinement | Explicit whole-family rows; uniform and complete per-constructor bodies; singleton local access; preservation and loss of shallow refinement. | 3–5, 8, 10, 14 |
| 4: Elimination | Receiver-anchored flat `case`; eligible scrutinees; explicit and residual binders; exhaustive coverage; defaults; branch typing and lazy execution. | 1, 4–5, 8–11 |
| 5: Generics and recursion | Invariance; fresh variables and complete explicit headers; contextual and branch inference; closure; direct regular recursion and its limits. | 3, 5–6, 8–11, 14 |
| 6: Protocols and closed data | Multiple nominal family conformances; required-domain coverage; overload specificity and result coherence; additive extensions; closed representation and open implementation axes. | 3, 7, 9–11, 14 |
| 7: Runtime behavior | Opaque identities and instantiated values; immutable structural family data and opaque leaves; exact dispatch; central runtime relation; equality; raw and user display; specialized values. | 8–13, 15 |
| 8: Reflection | Exact callable surfaces, roles and descriptive metadata; owner and row authority; contextual invocation; limited acceptance queries; enumeration; hidden multi-constructor representation. | 5, 8, 11, 14–15 |
| 9: Concrete syntax | Complete declarations, source types, send headers, body modes, case clauses, extensions, conformance, reserved-word scopes, reflection spellings, raw forms, and source transition. | 1–7, 13–17 |
| 10: Static and implementation consequences | Checked execution; shared descriptors; linking, finalization and transactions; integration and validation obligations; migration and completion boundaries. Audit consistency with provisional sequencing without drafting the roadmap. | 8–15, 17–22 |

Audit in both directions: every accepted obligation must be represented or
explicitly reserved for an appropriate later artifact, and every candidate
rule must have authority in the approved design or preserved language. Trace
the diagnostics, exclusions, and validation catalogues back to their semantic
rules as well as checking that they cover those rules.

Distinguish an intended replacement of current `SPEC.md` behavior from an
accidental preservation regression. In particular, generated `new`, class
fields, positional single conformance, and legacy declaration syntax are
intentional transition subjects, not reasons to restore the old ontology.
Required protocol signatures and multiple family conformances are accepted
parts of the destination language.

The candidate should explain its proposed language without requiring the
reader to reconstruct a rule from historical discussion. Do not mistake an
omitted language rule for an implementation freedom, or require a physical
representation, algorithm, or public API where only observable behavior was
specified. The report need not reproduce the design or create a row for
every sentence.

### 2. Consistency across the checkpoint boundaries

Check interactions across 89A–89E, not merely the completeness of each slice
in isolation. Record concise conclusions and supporting references for at
least these interactions; combine related checks where that improves clarity:

- **Syntax and evaluation:** sends, literal selectors, explicit `call`,
  parallel `let`, lazy conditionals, and `check` remain coherent with the
  new `case` form and static send header. Contextual markers retain exactly
  their specified scopes; type grammar does not become expression syntax.
- **Construction and inference:** constructors, factories, expected types,
  overload filtering, and sibling branch constraints agree on fresh generic
  variables, full resolution, invariance, and closure. Ordinary construction
  receives checked arguments; hidden reflective rows retain their specified
  guarded contextual resolution. Apply U1's approved sealed input type
  evidence rule without reconstructing generic arguments from payload
  contents or results.
- **Refinement and local authority:** all introductions, direct aliases,
  joins, residual binders, and loss points agree. Stored data and protocol
  views do not preserve hidden refinement. A one-constructor family remains
  inherently singleton; a multi-constructor local never becomes an escaping
  reflective capability.
- **Declarations and global coherence:** signature installation, regular
  recursion, extension batching, complete loaded units, protocol coverage,
  and dynamic overload results agree. Later permitted extension rows may
  satisfy conformance without permitting replacement, orphan claims, or
  constructor/local additions.
- **Static and dynamic obligations:** the linked descriptors and central
  runtime relation preserve the same exact identities and instantiations
  across construction, case, protocols, equality, reflection, and host use.
  Static transaction failure, injection preflight, pre-execution guards,
  post-execution result checks, and runtime effects remain distinct.
- **Equality, text, and reflection:** structural family equality and opaque
  leaf behavior agree with kernel `check`; user `=` and `show` do not override
  trusted operations. Names, type data, raw text, and menu positions remain
  descriptions rather than identities, refinements, or invocation authority.
- **Built-ins and host composition:** specialized values use the common
  language obligations without acquiring invented constructors, case
  eligibility, source type-object bindings, or extension rights. Typed opaque
  composition does not broaden the sealed host crossings or expose state.
- **Diagnostics and validation:** each rejection has the right condition and
  boundary; ordinary negative answers remain legal results. Examples state
  enough type and refinement context. Current regression results, future
  semantic/application obligations, and later implementation completion are
  never treated as interchangeable evidence.

Review every candidate example and validation scenario against the governing
rules, including `Point`, `Option`, `Result`, `Tree`, reflection, and preserved
built-in/host observations. Check that the examples exercise the claimed
context rather than accidentally fixing an unresolved variable or making a
case branch impossible. Kernel comparisons across distinct instantiations
must not imply that source `check` accepts incompatible operand types.

Reconcile the application obligations with the archive: Boids and both step
sends; MPL's open protocol and domain operations; closed filesystem
classification with ordinary `Other`; Gel's later pending `Option` and
conditional further state refactor; and unchanged Term/host boundaries.
Preserve Gel keys and emitted text for existing valid flows, accounting for
the explicit Mirror API menu addition specified by the approved U1 decision.
These are audit subjects, not application migrations or a request to design
an OS capability API.

### 3. Findings and bounded corrections

For each discrepancy, record the exact source and candidate locations, the
conflicting or missing obligation, its consequence, and its disposition.
Distinguish:

- a small correction whose intended meaning follows unambiguously from the
  accepted design, including an omitted explicit rule, misleading example,
  stale cross-reference, or inconsistent statement;
- a material conflict, ambiguity, or missing choice requiring user design
  review; and
- an intentional exclusion, unpromised property, permitted implementation
  choice, or subject explicitly reserved for later work.

U1 now has an explicitly approved amendment. Record its adoption and evidence
under the resumption instructions above rather than treating it as a small
editorial correction or requesting the same design approval again.

Make small justified corrections directly in the candidate and record their
before/after meaning and authority in the report. Fix affected examples,
catalogue entries, and references together, then audit the affected
interactions again. Do not broadly rewrite sound sections or copy the archive
into the candidate merely to make coverage visible.

Do not silently resolve a substantive conflict between approved sources,
invent a new language choice, or use an example to settle an open question.
Present enough evidence and the exact decision needed for user review. Leave
the audit incomplete when such an issue remains; labeling a required semantic
decision “later work” does not make it acceptable. Continue unrelated checks
and preserve their results so a subsequent review can resume from concrete
findings.

Do not require decisions on deliberately unpromised properties such as
cross-execution identity stability or raw-text round-tripping. Optional
algebraic rewrites of built-ins remain optional. Roadmap and handoff content
is expected to be pending, although the candidate's existing migration and
completion boundaries must already be consistent with Decision 10.

### 4. Audit record and candidate status

Keep the report self-contained as a review artifact, with:

- its non-normative purpose, the baseline reviewed, and its actual outcome;
- the Decision 1–10 coverage table and interaction conclusions;
- findings, applied corrections, and any unresolved design decisions;
- validation actually performed, separately from future family obligations;
  and
- the remaining roadmap, handoff, and ratification boundary.

Record a no-findings result explicitly if warranted; do not manufacture
corrections. Support conclusions with specific references and explain their
limits. The report is not a soundness proof, implementation certification,
new semantic authority, or guarantee about future edits to the candidate.

If all required audit checks are complete and no material issue remains,
update the candidate's status and `Pending completion` boundary to identify
89F's completed audit and link to the report. Retain the prominent
**incomplete and non-normative** status and checkpoint-88 implementation
boundary. Reserve:

- the implementation roadmap and durable handoff; and
- atomic ratification into `SPEC.md`.

Reconcile statements that still reserve the whole-candidate audit for later
work, without changing the historical scope of 89A–89E or implying that 89E's
catalogue itself performed the audit. If an unresolved issue prevents
completion, keep the final audit pending and link to the report's findings
instead of asserting completion.

The audit result applies to the final candidate text reviewed in this slice,
including its recorded corrections. Later substantive changes require review
of the affected conclusions before ratification. Do not add a blanket “ready
for implementation” or “ratified” claim.

## Validation and acceptance

Before review:

- confirm this slice changes only the audit record and the candidate, with
  any pre-existing worktree changes accounted for separately;
- verify complete Decision 1–10 coverage, the interaction checks, all
  candidate examples, and traceability of any corrections;
- verify complete adoption of the approved U1 decision and recheck all
  affected conclusions, including the new future validation obligations;
- check that every finding has an honest disposition and no unresolved
  semantic choice has been hidden in a deferral or editorial correction;
- check links, section references, status statements, and the pending
  boundary against the final candidate;
- confirm no runtime feature, source acceptance, test fixture, roadmap,
  handoff, or normative specification change was introduced;
- run `git diff --check`, `git status --short`, and `git diff --name-only`,
  and inspect the new untracked audit file as well as the tracked diff; and
- run the established full regression suite (`raco test tests`) and the
  existing checkpoint-88 hand check without changing tests.

The hand check is the public driver/Term example under `Hand check` in
`docs/checkpoints/0088-seal-typed-host-boundary.md`. Its result remains
`'("sealed" "sealed\r\n")`. It uses an in-memory output port and requires no
physical terminal interaction. If Racket's default temporary directory is
unwritable, use a fresh writable temporary directory and report that
environment adjustment separately.

Do not create executable family tests or try to run unimplemented family
examples against the checkpoint-88 parser. Passing the unchanged suite and
hand check establishes regression preservation, not the correctness of future
family behavior. Review that behavior against the approved design.

Accept 89F only when the complete audit is recorded, all bounded corrections
are justified and rechecked, the approved U1 amendment is incorporated and
audited, no material semantic issue remains unresolved,
the candidate's status accurately reflects the result, and the documentation
checks, unchanged suite, and hand check are green. A report containing an
unresolved required design decision is useful review output, but is not a
completed checkpoint.

Stop for review without committing. Do not create the next checkpoint,
allocate the provisional 90–106 sequence, draft the implementation roadmap
or durable handoff, ratify the candidate, or begin implementation.
