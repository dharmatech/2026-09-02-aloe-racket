# aloemacs-windows 002 — Synchronization completion

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Complete the window-state contract for constructed multi-view sessions.
Mirror and retarget only the selected leaf during ordinary operations;
retarget every view of a killed buffer during removal. Preserve inactive
origins, locks, tree shape, selection, and remembered size exactly.

This is **synchronization completion** under spec §3.7. Buffer identity,
the window types, fourteen-field session migration, `with-origin`, and
complete one-leaf integration already exist. This slice generalizes that
state behavior without repeating a migration. Normal startup and all
current keys still produce one view. Tests construct multi-view trees
directly; those fixtures prove state, not final multi-view painting.

Stop after the state proof and full suite pass. Add no geometry, renderer,
view-entry operation, window command, or key. Layout follows only after
human review of this completed state contract.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 002**, filed as
  `checkpoints/002-synchronization-completion.md`. This is a local editor
  checkpoint, not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute through `call`. Use ordinary recursive
  constructor cases and lawful typed absent Options.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, order, scope,
  and non-goals. §§3.2–3.4 define the existing types and final state
  invariants. §§3.6–3.7 assign the remaining multi-view proof to this
  part. §8 preserves existing input precedence; it does not authorize
  window commands here. §9's **window state and synchronization**
  commands and individual-checkpoint completion rules govern verification.
  Predecessor specs named in §1 retain authority for existing behavior.
- [000-buffer-identity.md](000-buffer-identity.md) and
  [001-state-foundation.md](001-state-foundation.md) are implemented in
  the current checkout. Preserve their complete focused proofs and all
  existing regressions. The historical [000-split.md](000-split.md) is
  unimplemented, returned, and unauthorized for resumption.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  The four window classes and session field already have their final
  shapes. `AloemacsWindows.with-buffer` currently updates a Leaf and
  returns a split tree unchanged. Session editor replacements, selections,
  and `visited` use that helper; `kill-buffer` currently routes removal
  through `selected-buffers`. Generalize these state paths so constructed
  split-tree sessions satisfy the accepted rules.

The [README](../README.md) records 001 as state foundation and 002 as
synchronization completion. Later unissued parts retain their order:
layout, both splits, delete and other-window, then window lock. This
checkpoint adds no behavior beyond the accepted spec.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: generalize window-state traversal and
  reconstruction within `AloemacsWindowTree`, `AloemacsWindows`, and
  `AloemacsSession`. Internal application helpers may be added within
  those classes. Keep the two loads, existing class declaration order,
  field/constructor shapes, existing public signatures, command cases,
  keymaps, file effects, and renderer algorithms unchanged.
- Create `tests/aloemacs/windows-state.rkt` before product edits. It owns
  the complete remaining multi-view state proof below. Use existing
  checked-driver, Fs-double, and test facilities; add no shared test module.

Current inventory searches show no existing test needs an adjustment:
the class/field/command inventories already describe the final state
shapes and permit internal helpers. There is no constructor migration,
binding change, or one-view behavioral change in this part.

### Must leave untouched

- `examples/aloemacs/editor.aloe` and `examples/aloemacs/main.aloe`.
  `with-origin` and startup configuration are already implemented.
- Every existing test, including `windows-buffer-identity.rkt` and
  `windows-state-foundation.rkt`. Retain their independent expectations,
  substantive assertions, and complete ANSI goldens unchanged. Do not
  create a layout or command focused proof early.
- Every other product/host module, `host/racket/aloemacs-run.rkt`,
  `host/racket/term.rkt`, Fs/Term interfaces, `aloe/`, and `lib/`. Add
  no module, load, dependency, or capability.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  and this series' design/checkpoint documents. Buffer identity and
  allocation, name lookup, zipper operations, editor/UndoFrame shapes,
  command inventories, input precedence, and rendering are preserved.

If another file, inventory adjustment, or design change proves necessary,
stop and return this checkpoint to the manager instead of widening it.
If finishing would require compaction, report the size problem and stop
for review; do not split the assignment or start its successor yourself.

## Slice requirements

### 1. Selected-only mirroring and reconstruction

For every supported program-created returned session, the selected view's
`buffer-id` equals current's stable ID, and its stored origin mirrors the
current editor's origin. Selection is a view ID, never a leaf index,
buffer position, name, or numeric-order rank.

Generalize the existing selected-leaf update to traverse arbitrary
nonempty binary Leaf/Below/Right trees with ordinary constructor cases.
Replace only the path to the selected leaf. Retain the precise structure
and visit order; do not flatten or rebalance. Preserve every view's ID
and lock, configuration selection, and remembered dimensions.

- `with-editor`, `with-search`, `with-kill-state`, and their edit, motion,
  undo, quit, mark/kill/yank, search, and fit paths mirror the returned
  editor's origin onto the selected leaf only. Its buffer ID remains
  current's ID. Every unselected view remains exact, including views
  sharing that buffer with different stored origins.
- Echo/search-metadata/prefix/prompt/submission/slot-only reconstructions
  preserve the configuration exactly. Direct save and path-only changes
  also preserve it exactly, retaining accepted Option/echo outcomes.
- Buffers remain the sole owners of editors. A shared-buffer edit,
  motion, undo, quit, or visit changes that one buffer value; every view
  naming its ID consequently observes the same Text, point, history,
  mark, and quit state. An inactive origin is never installed into or
  fitted on the shared editor during these transitions.

Do not add a public view-entry or session-selection send. Storing a
departing origin and installing a different leaf's origin through
`find-id`/`with-origin` belongs to §6's delete and other-window part.
Existing buffer-selection operations retarget the selected leaf instead.

### 2. Existing operations retarget selected without selecting a leaf

Complete every ordinary operation row from spec §3.4 for constructed
mixed multi-view, shared-buffer, multi-buffer, and locked fixtures:

| Existing operation | Required window result |
|---|---|
| Both `add-buffer` arities; new-file find-file | Selected leaf shows the newly inserted fresh buffer ID at `(0,0)`. Departing buffer and all unselected views remain exact. |
| `switch-buffer`; `selected-buffers`; find-file reuse; select-buffer success | Selected leaf shows resulting current ID and that editor's existing origin. Do not borrow an inactive view's origin. Every unselected view remains exact. Existing selection resets apply even when current ID is unchanged. |
| Successful `visited` / direct `visit` | Keep current ID and tree; reset selected origin to the fresh editor's `(0,0)`. Inactive views of that ID keep their origins and observe replacement text through the shared buffer. |
| Refused `visit`, find-file refusal/name miss, save-as refusal | No window change. Keep accepted Option/echo/prompt results and exact effects. |
| Save-as success / `with-current-path` | Preserve the entire configuration, including every origin; update current path under its existing ID. |

In all cases preserve selected view ID, every lock, tree shape, and size.
Lock does not pin a buffer or block an existing operation. Preserve
accepted search/echo/prefix resets and ring/prompt/submission/slot rules:
the new window-command echo table does not change these older commands.
Successful direct visit retains its existing resets, including prompt,
slot, and ring clearing, while preserving last submission.

Direct selection during a waiting prompt keeps its line and command
slot. Return acts on the then-current buffer, with no saved old buffer
or view target. Assert current-name selection, duplicate-name reuse,
sparse IDs, preserved logical zipper order, and exact Fs targets/counts.

### 3. Kill retargets all matching views

Implement kill separately from ordinary selected-only retargeting:

- Nonsingleton removal uses the accepted successor-else-predecessor
  rule. Capture the removed current ID and the already chosen replacement
  editor's origin once, before tree traversal. Every view of the removed
  ID, including selected, takes the replacement ID and that same origin.
  All other views remain exact, including views already showing the
  replacement buffer with a different stored origin.
- Singleton removal keeps buffer ID and installs the accepted fresh
  untitled editor/path defaults. Reset every view of that ID to origin
  `(0,0)`, including unselected and locked views. Singleton means one
  buffer; the tree may still have several leaves.

Killing removes no view, changes no lock, shape, selection, or remembered
size, and performs no save or extra I/O. Every resulting view names a live
buffer. Preserve all surviving buffer IDs and exact editor/path payloads.
Keep existing kill-buffer selection resets and ring/prompt/submission/
slot preservation. A later legal reuse of a removed buffer ID cannot
leave an old view attached to the newly added buffer.

### 4. Keep the intermediate fit/frame boundary

State synchronization supports constructed multi-view transitions now;
geometry and multi-view composition remain unsupported until §4.
Rectangles remain typed values without layout/comparison algorithms.

Positive `ensure-visible(columns, rows)` still fits current editor to
the predecessor full text rectangle: width `columns`, height `rows - 1`
when `rows >= 2`, otherwise `rows`. It records the full terminal size,
mirrors only selected origin, and preserves every inactive view and lock.
This is temporary full-rectangle fit, not selected-rectangle page height.
All other operations retain remembered dimensions exactly, including
unknown `(0,0)` dimensions in valid constructed state fixtures.

Leave `frame` pure and its composer exact. Prove unchanged one-view
bytes through the completed foundation and regression suites; do not
assert a final split-tree frame, divider, cursor translation, or tiny-tree
fallback here. The unchanged runner keeps its fit/frame/write contract.

### 5. Focused proof, written first

Write `tests/aloemacs/windows-state.rkt` and observe the missing multi-view
behavior fail before product edits. Complete spec §3.6's remaining proof
using the checked driver, `rackunit`, independently constructed expected
sessions/trees/editors, source snapshots, and counted Fs doubles. Do not
build expectations through window/session helpers or transitions under
test. Keep concrete typed-send checks and relevant wrong-argument,
receiver, and arity negatives for new internal sends.

Use nested mixed Below/Right trees, a selected leaf below the root and
away from the first visit position, sparse/nonordered view and buffer
IDs, duplicate names/equal content, shared buffers, distinct nonzero
inactive origins, mixed locks, and rich cold/focused-indexed editor
payloads. Test several selected positions by independently constructing
consistent sessions, without introducing a view-selection command.
Fixtures must start with selected/current ID and origin consistent.

Prove these complete results, comparing all fourteen session fields,
tree shape/visit order, view fields, logical zipper order, and editor
payloads rather than only a changed selector:

1. Every preserving reconstruction and selected-only editor update from
   requirement 1, including successful and failed search, edit/motion/
   undo/quit, kill/yank, prompt edit/submit/cancel, prefix, and command-slot
   transitions. Inactive views sharing the edited buffer retain their
   different origins; resolving their ID yields the one updated editor.
2. Every ordinary operation row in requirement 2, including both add
   arities, selection of current and another buffer, duplicate-name
   reuse, successful/rejected direct visit, new and reused find-file,
   select-buffer miss, direct save, and save-as success/refusal.
   Assert accepted resets/preservations and exact existing I/O targets;
   state traversal introduces no effects.
3. Nonsingleton kill with replacement from after and from before;
   multiple views of killed ID and an existing replacement view with a
   different origin. Put those leaves in different traversal positions
   to prove replacement-origin capture is independent of traversal.
   Unrelated views and surviving editors remain exact; no ID dangles.
   Add after removal with legal ID reuse and prove no old view follows it.
4. Singleton kill with several matching views, shared rich editor state,
   nonzero origins, and mixed locks. Keep the sole buffer ID, reset every
   matching origin, retain exact locks/shape/selection/size, and assert
   fresh untitled payload plus all accepted session resets/preservations.
5. Direct selection/kill during a waiting prompt preserves line/slot;
   subsequent Return completes against the buffer current then. Cover
   both an existing destination and a newly inserted buffer, retaining
   last-submission and ring according to the accepted command rules.
6. Positive fit and resize at the temporary full-rectangle dimensions,
   selected-only mirroring, repeated-fit idempotence, full-size bookkeeping,
   and exact inactive origins/locks. Non-fit operations preserve known
   and unknown size. Direct frame remains pure; retain all complete
   one-view goldens and runner/effect assertions through the full suite.
7. Existing class/field/constructor shapes and command/key inventories
   remain exact. The foundation proof continues to cover lawful checked
   loading/startup, tree traversal/types, constructor negatives, and
   `with-origin` purity. Together the two state proofs satisfy all of
   spec §3.6 without importing layout or commands early.

## Explicit non-goals

No constructor migration, editor/startup change, additional field/store,
view-entry operation, layout, rectangle comparison, `frame-rows`, divider,
selected-rectangle fit/page motion, multi-view frame, or resize fallback.
No fresh-view allocation, SplitBelow/SplitRight/DeleteWindow/OtherWindow/
ToggleWindowLock constructor, session send, execution case, or binding.

No per-view editor, point, mark, history, or ring; mode line, buffer menu,
completion, automatic split/delete, registry/counter, runner/Term/Fs
change, Text method, List index, kernel message, Mirror, mutation,
inheritance, delegation, macro, implicit Int/Float coercion, new special
form, next exploration, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-state.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes buffer identity, state foundation, and every predecessor proof.
Do not commit `compiled/`. No wider suite, benchmark, timing gate, or
physical TTY hand check is required. Optional launch remains
`racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt` edit, run the
named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe` first.
Launchers load existing bytecode; `.aloe` edits need no rebuild.

Review source as well as results: configuration is the only window store;
each buffer owns one editor; selected updates replace only their leaf
path; inactive origins are never installed/fitted; kill captures one
replacement origin and updates every matching buffer ID; reconstructions
thread configuration; only positive fit records size. Check all session
rebuilds and state-helper call sites. The unchanged one-view behavior,
renderer, commands/maps, runner, and host/language boundaries remain
intact. Confirm changes are limited to the two permitted files.

Complete when the focused proof and full suite pass, whitespace/source
review passes, every §3.6 state obligation is implemented, and no
migration or regression remains. Report the initial missing-behavior
failure, final verification results, changed files, and structural review.
Stop when green for human review. Do not implement or issue layout or
any later checkpoint.
