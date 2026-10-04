# aloemacs windows — Checkpoint 000 scope review

**Status: Manager accepts the size return. Proposed partition awaits
human approval of the charter constraint and a revised spec.**

Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
Series identity: **aloemacs-windows**. This is a scope review, not a
checkpoint, replacement spec, or implementation assignment.

## Finding

The manager underestimated [000-split.md](checkpoints/000-split.md).
The implementer stopped before product edits, test edits, or test runs
after estimating that finishing its scope would require compaction.
That is a valid return under the repository's one-conversation size bar.
No implementation exists to review, and no product defect was reported.

The current source has 18 explicit `AloemacsSession new` reconstructions
in `examples/aloemacs/file.aloe`, plus startup in `main.aloe`.
Buffer/session constructor references occur across 21 existing files in
`tests/aloemacs/`. The migration is not merely appending constants:
independent expected sessions must mirror the selected origin and fitted
dimensions, and equal-payload live-buffer fixtures need distinct IDs.

The same assignment also introduces four recursive/configuration classes,
all existing buffer-operation integration, explicit-origin row rendering,
nominal layout and tiny-terminal fallback, full multi-view composition
with junctions and cursor translation, both commands and keys, and focused
Fs/Term/resize/echo proofs. Shortening the checkpoint prose would leave
that implementation and verification burden intact.

## Sections that need revision

| Authority | Size or packaging issue |
|---|---|
| [Charter §4.9](charter.md#49-three-checkpoints) | Locks the work to three checkpoints and explicitly prohibits a fourth even if a checkpoint cannot fit. This constraint must be relaxed before a spec writer can separate the foundation. |
| [Spec §1](spec.md#1-series-predecessors-and-authority) | Assigns all foundation and splits to 000, fixes the later numbers, and prohibits a fourth checkpoint. The current manager cannot issue a smaller foundation under that assignment. |
| [Spec §2](spec.md#2-product-host-and-file-boundary) | Groups all three product files, both constructor migrations, and one large focused proof into 000. A revised partition needs per-slice scopes and focused proof files. |
| [Spec §§3–4](spec.md#3-state-and-interfaces--introduced-in-000) | Introduces identity, window state, synchronization, geometry, fit, and rendering together. Their introduction points and independently testable intermediate states need to be separated. |
| [Spec §5.1](spec.md#51-migration-and-proof-for-000) | Couples every migration and existing-operation proof to the split, composer, echo, and runner proof. Each requirement needs one owning slice without dropping regression assertions. |
| [Spec §9](spec.md#9-verification-acceptance-and-stop) | Verification paths, the three-proof acceptance wording, and the no-fourth-slice stop must match the revised partition. The final behavioral bar can stay intact. |

This is a charter-level checkpoint-count constraint followed by a
spec-level repartitioning task. The accepted behavior, interfaces, shared
ownership, echo decisions, and product boundaries need no change to
resolve the reported problem.

## Proposed separation for review

Use six independently tested parts in this dependency order. These are
proposed responsibilities, not issued numbers or checkpoint files.

| Part | Scope and independent proof | Deferred work |
|---|---|---|
| Buffer identity | Add/preserve IDs, `fresh-id`, and bounded `find-id`; update startup and buffer constructors/expectations throughout the existing suite. Prove lookup, allocation, visit/path/editor replacement, singleton removal, and equal-payload distinction. Keep the current session shape and frame behavior. | Window classes/field, session migration, geometry, rendering, and commands. |
| Window state and synchronization | Introduce view/tree/rect/configuration types and the one session field; migrate session constructors; thread configuration through all reconstructions and existing operations. Prove selected-origin mirroring, retargeting, kill without dangling IDs, prompt/slot retention, and unchanged one-view frames. Constructed trees can prove pure state behavior without window commands. | Multi-view frame composition, selected-rectangle fit, and public window commands. |
| Layout, rows, rendering, and fit | Implement binary/nominal geometry, explicit-origin rows, safe padded composition, junctions, cursor/echo rules, selected-only fit, and shrink/growth fallback. Prove complete frames and resize using constructed trees through the unchanged runner. | Split/delete/other/lock commands and bindings. |
| Both splits | Add the two constructors, session sends, name/execute cases, and keys. Prove success/refusal geometry, pre/post-fit origins, shared edit/undo, stored echo preservation, prefix behavior, and split/edit/save/quit runner scenarios. Earlier migrations and rendering are prerequisites, not repeated implementation. | Delete, other-window, and public lock toggle. |
| Delete and other-window | Retain the current spec's ordered selection, origin handoff, same/different-buffer resets, sibling promotion, last-view refusal, and constructed-lock geometry guard, with their focused proof. | Public lock toggle. |
| Window lock | Retain the current public toggle, its key, exact-bit-only change, user-reachable refusal/unlock cases, and locks surviving existing operations and resize. | Every current non-goal remains outside the series. |

Every part must finish with its focused proof and
`TMPDIR=/tmp raco test -y tests/aloemacs` green. Intermediate work cannot
leave old tests failing for a later checkpoint. Separate buffer and
session migrations so neither is bundled with renderer implementation.
Command introduction order and the final constructor/key order stay as
currently accepted. The manager still issues one checkpoint at a time,
after acceptance of the revised spec and review of each predecessor.

The spec writer must make the intermediate stages explicit. In
particular, before the rendering part, normal user sessions still have
one view and keep the existing full-screen fit/frame behavior;
constructed multi-view fixtures prove state operations without asserting
an unfinished renderer. The rendering part installs the final geometry
and fit rules before the split commands make multiple views reachable
through keys. Specify when size bookkeeping and helpers are introduced,
which tests cover each stage, and each stage's exact stop. These staging
contracts belong in the revised spec, not an inference by an implementer.

Preserve the issued number 000 as the first position; do not renumber a
completed checkpoint. No later number has been issued or implemented.
The revised spec must decide the replacement 000 filename and update its
maps consistently, with one authoritative assignment per number. The
current returned file remains historical until that decision is accepted.

## Next handoff

First obtain human approval to relax charter §4.9's three-checkpoint cap.
Then have the design conversation amend that packaging constraint and
revise `spec.md` to carry the complete new series, introduction points,
file scopes, focused tests, and verification commands. Keep all accepted
product behavior and non-goals closed. Stop for human review of the
revised spec. After acceptance, the manager replaces the returned 000
with only the first smaller assignment and stops.

The manager has marked 000 returned and updated the maps. `charter.md`
and `spec.md` are unchanged; no replacement checkpoint or product/test
edit has been made. Do not resume the original 000 assignment.
