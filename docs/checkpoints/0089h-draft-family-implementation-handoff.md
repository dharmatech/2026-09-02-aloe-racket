# Checkpoint 0089H — Draft the durable family implementation handoff

Status: Proposed

Depends on: Checkpoint 0089G, including the accepted 90B/MPL ownership correction

## Goal

Create a separate implementation handoff that lets a fresh implementation task
orient itself from repository files, understand the approved design and
transition boundaries, and locate its next authorized checkpoint without
reconstructing the design conversations.

This is one documentation slice. The handoff explains how to use the audited
candidate and accepted roadmap; it does not duplicate their complete contents,
change the sequence, design internal APIs, or implement any roadmap entry.
Self-contained means usable from the repository without chat history. Precise
links to the specification, roadmap, examples, and evidence are expected.

The candidate remains incomplete and non-normative. `SPEC.md` remains law,
runtime behavior remains as implemented through checkpoint 88, and atomic
ratification remains later 89-series work. Completing this handoff does not
complete checkpoint 89 or authorize checkpoint 90A.

## Authority and starting point

Read `AGENTS.md`, `SPEC.md`, `CHECKPOINTS.md`, `docs/handoff.md`,
`docs/philosophy.md`, `docs/decisions.md`, and this checkpoint. Then read:

- `docs/unified-nominal-adts-spec-candidate.md`;
- `docs/unified-nominal-adts-design-audit.md`;
- `docs/unified-nominal-adts-reflection-resolution-proposal.md`;
- `docs/unified-nominal-adts-implementation-roadmap.md`; and
- Decision 10 and the cross-decision guardrails in
  `archive/unified-nominal-adts.md`.

Read the candidate and roadmap completely. Consult other archive decisions
and checkpoints 89A–89G for provenance or a specific boundary when needed.
The accepted candidate incorporates the user-approved U1 amendment, and the
89F audit is complete. The corrected 89G roadmap has been reviewed and
accepted as a plan, with no remaining review finding. In particular,
checkpoint 36's MPL observations belong to 90B; the Gel helper changes and
closure-sensitive migrations remain in 91C.

Record these dispositions in the handoff so a future reader need not ask for
the same decision again. Earlier checkpoint headers and historical reports
retain their stage-specific wording; they do not reopen completed work or
override the current starting point. Plan acceptance is not normative
ratification or evidence that its future entries have been implemented.

Use `README.md`, `docs/gel.md`, the checkpoint-88 hand check, and relevant
source/tests to verify the repository map and current commands. Reuse the
roadmap's evidence rather than conducting a second general design or code
audit. The transcripts in commit `8e6955c` and historical monolithic plan in
commit `8b2c155` remain non-normative; do not restore or depend on them.

Record the starting worktree state and distinguish existing accepted work
from this slice. Accepted documents may still be uncommitted. Do not require
a commit, revert them, or claim them as new 89H work.

## File scope

Create:

```text
docs/unified-nominal-adts-implementation-handoff.md
```

The only other permitted implementation artifact is:

```text
docs/unified-nominal-adts-spec-candidate.md
```

Limit candidate edits to status, links, and pending-artifact prose. Preserve
all semantic rules, examples, and validation obligations.

Keep the accepted roadmap, audit, approved U1 record, archive, and checkpoint
documents unchanged. Do not edit `SPEC.md`, `CHECKPOINTS.md`, `README.md`,
`docs/handoff.md`, `docs/philosophy.md`, `docs/decisions.md`, `docs/gel.md`,
source, tests, fixtures, libraries, examples, or applications. The new handoff
is a separate draft for the family transition; the existing `docs/handoff.md`
continues to describe the current implementation.

## Required handoff

### 1. Entry point, authority, and current state

Open with a prominent draft, non-normative status and a short reading order.
Distinguish the checkpoint-88 runtime baseline, completed 89F audit including
U1, accepted corrected 89G roadmap, and this handoff's review status. Record
the repository revision and any relevant uncommitted inputs as a dated
starting snapshot, not a claim that a commit contains all reviewed work.

Explain the documents' different roles: the current `SPEC.md` governs the
implemented language; the candidate specifies the audited target; the audit
and U1 record explain accepted decisions; the roadmap owns the proposed order
and prerequisites; individual checkpoint documents bound authorized changes.
The archive supplies design provenance and its original provisional sequence,
not a competing schedule or permission to reverse the approved U1 amendment.

Before runtime implementation, later work must reconcile and atomically ratify
the governing documentation, including the target language in `SPEC.md` and
the reviewed sequence in `CHECKPOINTS.md`. A future implementer must verify
that this happened and that its particular checkpoint is authorized. Preserve
the distinction between this prerequisite ratification and the final
documentation reconciliation after the language has been implemented.

### 2. A compact repository map

Identify the existing files a new implementer needs and why they matter:

- parsing and source provenance; checking, inference, and nominal declarations;
- evaluation, environments, library bootstrap, public helpers, driver, and loads;
- Mirror/Signature and the sealed host boundary, including optional runners;
- `lib/list.aloe`, Point/Boids, MPL, and Gel's application layers; and
- historical tests, the full-suite command, and the checkpoint-88 hand check.

Use concrete paths and links verified against the repository. Highlight the
current checked-then-raw evaluation seam, early source-`let` lowering,
inference/type-retention gaps, nominal/row identity replacement, and existing
host guards only far enough to explain the roadmap's dependencies. Describe
current behavior separately from future guarantees; do not present the target
checked pipeline or `invoke-mirrored` as already available.

This map is navigation, not a function-by-function inventory or edit plan.
Existing internal structure names and file boundaries do not constrain the
redesign. Do not invent replacement module layouts, structures, algorithms,
testing APIs, or future fixture filenames.

### 3. The semantic boundaries an implementer must retain

Summarize the contract concisely, with governing candidate section links:

- Receiver-first literal-selector sends, functions through `call`, parallel
  `let`, immutability, and explicit Int-to-Float conversion remain intact.
- One nominal family model covers products and closed variants. Construction
  is explicit; opaque family/constructor/row identities carry authority.
  Family arguments are invariant and ordinary construction receives checked
  arguments. Shallow refinements govern local lookup and are lost at the
  specified boundaries.
- Admitted `case` is exhaustive, checks all branches symmetrically, and
  evaluates one scrutinee and one selected branch. Whole-family rows,
  per-constructor bodies, local rows, factories, and type-object `self` retain
  their distinct contracts. Protocol conformance is nominal and uniform;
  combined overload/coherence and atomic extension rules apply on admission.
- Regular recursive payloads, structural equality, and raw/display separation
  follow the candidate. Reflection uses exact callable rows and exposes no
  multi-constructor instance discriminator, payload query, or local authority.
- Checked-unit finalization prevents evaluation on static failure; runtime
  effects are not rolled back. Specialized built-ins retain their contracts,
  and the existing List extension route remains available. Host injection,
  exact ownership, scalar crossings, immutable strings, causes, breaks, and
  public/internal sealing survive the transition.

Give U1 its own short, accurate account: `invoke-mirrored` takes exactly a
`Signature` and `(List Mirror)`, returns `Mirror`, and has no operation-local
type parameters or forwarded header. Its selected row resolves fresh
parameters only from the fixed owner and sealed, closed input evidence before
execution. Inputs unwrap once; validate the result before wrapping it or
reusing an existing Mirror. Retained family/List/function types supply that
evidence; metadata strings, payload scans, and executed behavior do not.
Ordinary `subject`, ordinary-result `invoke`, and construction retain closure.

Link the existing before/after Gel helpers and generic examples rather than
creating another competing example set. State why Some/map can obtain enough
evidence while None, partially known Result.Ok, and result-only factories may
fail before execution. Keep the intentional Mirror API menu addition distinct
from preservation of existing valid Gel flows. Label referenced future Aloe
examples as unimplemented; they are not checkpoint-88 runnable goldens.

Include a compact exclusions paragraph with links: no alternate nominal
ontology, permissive inference escape, structural/orphan conformance, general
subtyping, GADTs, mutual recursion, public type universe, expanded host
crossing, or required built-in algebraic rewrite. Preserve the full catalogue
by reference rather than restating every rejection.

### 4. How to follow the accepted transition

Point to the roadmap for the complete 25-entry sequence and its application
and validation ownership tables. Do not reproduce all entries or create a
second dependency graph. Explain the critical boundaries a new task must not
lose when expanding one entry:

| Owner | Boundary to carry into implementation |
| --- | --- |
| 90A–90B | Retain checked decisions and source provenance before activating checked transactions. Migrate checkpoint 36's unchecked MPL field observations to checked contextual reflection in 90B. |
| 90C–91B | Retain collection/function types, establish the shared nominal model and checked construction, and seal exact row/input evidence before exposing mirrored invocation. Preparatory work is not a completed inference-closure guarantee. |
| 91C | Activate `invoke-mirrored`, all three Gel helper rewrites, and closure together. Migrate closure-sensitive reflection/empty-list observations and preserve defensive failure coverage at this boundary. Do not exempt Gel or keep an unchecked production alternative. |
| Each feature's first admission | Supply its required integrity, reflection exclusions, complete case checking, and conformance/extension guards immediately. Later syntax stays rejected; a later seal does not excuse an earlier unsafe approximation. |
| 91A and 103A–103C | Introduce only a source bridge lowering legacy declarations into the same family model. Migrate all repository-owned executable sources, including embedded inputs; remove the bridge and legacy acceptance in 103C. |
| 104–106B | Validate canonical Option/Result, Gel pending Option, filesystem classification, and the final unified implementation. Earlier Tree/application evidence retains its roadmap owner; built-in rewrites and a further Gel state family remain optional. |

Keep the later Gel pending-state change separate from 91C's helper transition
and 103B's nominal source migration. Filesystem classification validates
ordinary `Other`, local capabilities, and exhaustive consumers; it chooses
no OS API or new crossing mechanism. Required application evidence still
includes Point, both Boids steps, MPL's domain behavior, Tree, Gel, and Term.

If a roadmap entry later needs subdivision, preserve its dependencies and
guards through a reviewed checkpoint document. Do not split, renumber, expand,
or reassign roadmap entries while writing this handoff.

### 5. Working and validation instructions

Provide a short procedure for a future implementation task: inspect the
worktree and governing files; identify its authorized checkpoint and completed
prerequisites; implement that one slice with relevant tests; run the full
suite and its required hand observation; report evidence and stop for review.
Preserve existing work and follow session authorization for commits rather
than making a clean worktree or a commit a prerequisite to reading the plan.

Include `raco test tests` and link the exact checkpoint-88 Term hand check
with its expected result. Explain the fresh writable `TMPDIR` workaround if
Racket's default directory is unwritable. Verify any other documented current
command from its repository source; distinguish optional TTY/package needs
from the core suite and in-memory hand check. No package installation or live
TTY session is required to draft this handoff.

Separate the baseline's reported 1,297 passing tests from checks actually run
in 89H and from future family validation. Future counts are not fixed. Tests
for intentionally rejected old syntax or inference must preserve their valid
behavioral purpose through the assigned migration; unrelated runtime guards
must not disappear behind earlier static errors or skipped tests.

A missing semantic rule or material contradiction must be reported with its
source references before choosing a rule. Continue unaffected work, preserve
the approved audit/plan, and identify any blocker explicitly. Ordinary
implementation choices within a later authorized checkpoint remain the
implementer's responsibility.

## Candidate status and remaining boundary

Link the drafted handoff from the candidate's status and pending-artifact
references. Record the completed 89F audit, acceptance of the corrected 89G
roadmap, and 89H handoff drafted for review. Keep the candidate incomplete and
non-normative and the runtime at checkpoint 88.

After handoff review, the remaining 89-series work is final reconciliation and
atomic ratification, including promotion of the reviewed sequence into
`CHECKPOINTS.md`. Do not write that checkpoint, perform ratification, alter
the audit or roadmap, or claim that future semantic validation has passed.
Historical status prose in read-only documents remains scoped to its stage;
the candidate and new handoff supply the current artifact status.

## Validation and acceptance

Before submitting this documentation slice:

- Check that only the new handoff and permitted candidate prose changed,
  accounting for the initial worktree. Inspect the new file as well as the
  tracked diff; preserve candidate semantics and all read-only inputs.
- Walk through the handoff as a reader without chat history. Verify that it
  identifies the current runtime, accepted design and corrected roadmap,
  remaining ratification, where to find the next authorized checkpoint, its
  prerequisites, validation commands, and the stopping rule. No fresh task
  or subagent needs to be created for this check.
- Cross-check the semantic summary and U1 account against the candidate, and
  migration ownership against the accepted roadmap, especially 90B versus
  91C. Verify the bridge removal and application boundaries. Report any
  material contradiction rather than silently repairing another artifact.
- Check local links, heading targets, code-fence balance, whitespace, command
  provenance, and status wording. Avoid chat-only references, duplicate
  specifications/sequences, or unimplemented examples presented as current.
- Run `git diff --check`, `git status --short`, and `git diff --name-only`.
- Run the unchanged full suite (`raco test tests`) and the
  [checkpoint-88 hand check](0088-seal-typed-host-boundary.md#hand-check),
  whose in-memory result remains `'("sealed" "sealed\r\n")`. If a fresh
  writable temporary directory is needed, report that environment adjustment.

Record validation actually performed and its limits. Passing the unchanged
suite establishes preservation, not implementation of family semantics or
permission to activate the roadmap.

Accept 89H when the handoff is usable without conversation history, agrees
with the audited candidate and corrected roadmap, makes the next boundary
unambiguous, and passes the required checks. Stop for review without committing.
Do not implement the handoff's instructions, create a later checkpoint,
change governing documents, ratify the candidate, or begin checkpoint 90A.
