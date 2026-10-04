# aloemacs-windows 000 — Buffer identity

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Give each live buffer a stable integer identity. Add allocation and
bounded identity lookup to the existing nonempty buffer zipper, migrate
buffer constructors and independent test expectations, and preserve all
existing single-view behavior.

Stop after buffer identity and its proof pass. The session still has
thirteen fields. This checkpoint adds no window type, configuration,
session field, origin helper, geometry, rendering helper, command, or key.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 000**, filed as
  `checkpoints/000-buffer-identity.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute only through `call`.
- The accepted [../spec.md](../spec.md) §§1–2 govern authority,
  predecessors, file boundaries, and non-goals. §3.1 defines identity,
  allocation, and lookup; §3.5 defines the migration and focused proof.
  §9's **buffer identity (replacement aloemacs-windows 000)** commands
  and individual-checkpoint completion rules govern verification.
  The state, layout, and command parts are later work.
- Layers 1–16 are implemented, including aloemacs-prompt-commands 002
  (select-buffer), as recorded in the [parent map](../../README.md).
  There is no implemented predecessor within aloemacs-windows. The
  historical [000-split.md](000-split.md) was returned unimplemented;
  it is not this assignment and must remain unchanged.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe)
  and [main.aloe](../../../../../../examples/aloemacs/main.aloe).
  `AloemacsBuffer` currently has editor/path fields. `AloemacsBuffers`
  has before/current-buffer/after, bounded `find-name`, forward/backward
  cycling, insertion, and removal. Session has both `add-buffer` arities,
  current-buffer replacement, visit/save, and the completed prompt
  commands. Its last field is `waiting-command`.

The predecessor specs named in accepted spec §1 remain authority for
preserved behavior. This slice supersedes only their two-field buffer
inventories. Do not amend predecessor documents or language law.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: append the buffer ID; preserve it in
  buffer replacement and singleton removal; add collection allocation
  and lookup with any necessary internal helpers; thread IDs through
  both existing session additions and current-buffer visit replacement.
  Keep the existing two loads and class declaration order. Existing
  session operations may change only as needed to carry/allocate IDs.
- `examples/aloemacs/main.aloe`: append ID 0 to its buffer constructor.
  Preserve its session constructor and every existing startup default.
- Create `tests/aloemacs/windows-buffer-identity.rkt` before product
  edits. It owns the focused identity, allocation, lookup, preservation,
  checked-type, startup, and file-effect proof below.
- These exact existing files under `tests/aloemacs/`, only for affected
  buffer constructors, independent expected values, fixture IDs,
  buffer/collection inventories, and constructor negatives:

  ```text
  buffer-collection.rkt
  buffer-session.rkt
  buffer-value.rkt
  echo-session.rkt
  file-session.rkt
  keymap-prefix.rkt
  keymap-session.rkt
  kill-session.rkt
  minibuffer-session.rkt
  minibuffer-value.rkt
  motion-editor.rkt
  prompt-commands-find-file.rkt
  prompt-commands-save-as.rkt
  prompt-commands-select-buffer.rkt
  runner.rkt
  safe-cells.rkt
  search-session.rkt
  undo-session.rkt
  viewport-editor.rkt
  visited-unchanged.rkt
  ```

This list comes from buffer-constructor and inventory searches, not a
blanket allowance to edit the aloemacs suite. Existing test behavior
and assertions stay substantive; the new focused file owns new proofs.

### Must leave untouched

- `examples/aloemacs/editor.aloe` and every other product module.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, other host
  files/capabilities, Fs/Term interfaces, `aloe/`, and `lib/`.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  this series' design documents, and the historical `000-split.md`.
- Every existing test outside the exact list above; all later windows
  focused tests, which must not be created early.
- Session arity/field order, editor's eight fields, UndoFrame's four
  fields, prompt shape, command/map inventories, all keys, fit/frame
  algorithms and complete frame goldens, and the runner contract.

Add no module, load, dependency, capability, next-ID counter, new store,
or API beyond this slice. If another file or a design change is necessary,
stop and return this checkpoint to the manager instead of widening it.
If finishing would require compaction, report the size problem and stop
for review; do not split the assignment or begin window state yourself.

## Slice requirements

### 1. Stable buffer value and ID preservation

Append `id : Int` after the existing fields, in exactly this order:

```aloe
(editor AloemacsEditor)
(path (Option Path))
(id Int)
```

Construction is `(AloemacsBuffer new editor path id)`. The generated
`id` selector returns `Int`. IDs are nonnegative and unique among live
buffers in a valid session, including buffers with equal editor/path
payloads or duplicate names. An ID is not a path, name, list position,
editor equality, or host object address. Raw constructors are not
validators; do not add runtime validation or identity setters.

- Buffer `with-editor` replaces only editor and preserves path/ID.
  Buffer `with-path` replaces only path and preserves editor/ID.
- Successful session `visited` and direct `visit` replace the current
  editor/path under its existing ID. Keep their accepted reset and
  submission rules. Refusals preserve their existing result exactly.
- Collection singleton `remove-current` keeps current's ID while
  installing the accepted fresh untitled editor/path defaults. Larger
  removal removes only current's ID and changes no surviving buffer.
  Keep successor-else-predecessor focus and all existing session kill
  resets/preservation, with no save-on-kill.
- Every ordinary session editor/path reconstruction preserves current's
  ID. Editing, motion, undo, search, quit, fit, save, successful save-as,
  selection, and prompt transitions must not rewrite existing IDs.
  Switching/selection retain every buffer value and logical order;
  current-buffer focus may change under their existing policy.

`AloemacsBuffers` remains exactly before/current-buffer/after, in that
order. `with-current-buffer` remains the ordinary replacement helper;
session replacements preserve current's ID. The session retains its
exact ordered thirteen fields, including the existing prompt, submission,
and waiting-command fields; no session-constructor migration occurs.

### 2. Live-maximum allocation and startup

Add collection `fresh-id() -> Int`: one more than the largest live ID.
Compute the maximum with folds over before/after and current. Sparse,
out-of-order IDs and maxima on either zipper side must work. Allocation
does not change the collection, focus, editor, or any other payload.

Both session `add-buffer` arities compute this ID from the existing
live collection before `insert-after` and give it to the new buffer.
Keep existing insertion order, fresh editor defaults, path behavior,
search/echo/prefix resets, and ring/prompt/submission/slot preservation.
New-file find-file uses this existing addition path. No addition adds
an Fs call.

Startup's sole buffer has ID 0. Append it in `main.aloe`, preserving
the existing cold empty Text and all defaults. At untyped sites retain
lawful inferable absent Options, such as
`(if #t (Option None) (Option Some typed-value))`; do not replace them
with a checker change, reflective construction, or an Option setter.

No counter is stored. Reuse after removal is permitted: for live IDs
0 and 1, removal of 1 followed by addition may allocate 1 again.
IDs identify live values in one immutable session lineage, not external
durable or cross-session handles. There are no views to retarget in 000.

### 3. Current-first bounded identity lookup

Add collection `find-id(id : Int) -> (Option AloemacsBuffers)`.
Check current first, then at most one forward cycle with a countdown of
`1 + before.len + after.len`, following the existing `find-name` pattern.
Compare integer IDs, not names or payload equality. A hit returns the
focused collection as `Some`; a miss returns `None`.

A hit changes only zipper focus/representation and preserves logical
order and every complete buffer value. Lookup is pure: neither a hit
nor a miss installs a session focus or modifies its source collection.
Use ordinary application helpers and guarded traversal as needed;
do not use a List index, a second collection store, or computed selectors.

Keep `find-name` and its bounded current-first/forward policy unchanged.
Names are still derived from exact stored path text or `"untitled"`.
Find-file still reuses by name, including duplicate paths and untitled
collisions; a reuse keeps that buffer's ID and allocates nothing. Typed
ID lookup does not become a new command or replace name selection.

### 4. Constructor and expectation migration

Search before and after migration, including independent reconstructions:

```sh
rg -n -U 'AloemacsBuffer\s+new' examples/aloemacs tests/aloemacs
rg -n 'AloemacsBuffer|AloemacsBuffers' tests/aloemacs
```

Append explicit nonnegative IDs to valid constructors. Use ID 0 for
startup and appropriate explicit IDs for independent expectations.
Every valid live multi-buffer fixture needs distinct IDs. When an old
fixture repeats equal buffer values, preserve equal editor/path payloads
and names in separately identified buffers; retain its positional,
duplicate-name, bounded-scan, and immutability purpose. Do not evade
these cases by assigning distinct paths or content.

Expected reconstructions carry the ID of the buffer being replaced,
not an unconditional 0. Singleton replacement expectations retain the
removed current's ID. Addition expectations compute an independent
maximum or use explicit expected IDs, never `fresh-id` under test.
Lookup expectations use an independent positional model, not `find-id`
or the selection transition being tested.

Preserve intentional old-arity negatives; migrate other negatives so
they still fail for their original reason. A former extra-argument
case that now matches the three-field constructor must remain an
extra-argument negative with the new arity. Keep wrong editor/path cases
focused on those errors, and add ID-type negatives in the focused proof.
Retain raw-state fixtures and the rule that constructors are not
validators. Extend exact buffer/collection inventories for this slice
and its internal helpers; do not weaken or delete structural checks.
Keep all editor/UndoFrame/session and command/map inventories exact.

Do not rewrite expected frames or change existing file effects, search,
prompt/slot, history, mark, ring, prefix, or quit assertions. No migration
or regression failure is left for a successor.

### 5. Focused proof, written first

Create `tests/aloemacs/windows-buffer-identity.rkt` and observe the new
behavior fail before product edits. Use the existing checked Aloe driver,
`rackunit`, independent expected constructors/positional models, snapshots
of source values, and counted Fs doubles. Prove accepted spec §3.5:

1. Exact three-field buffer shape/order; typed constructor and `id`,
   `fresh-id`, and `find-id` results. Reject wrong arguments, receivers,
   and arities, including non-Int IDs and the former two-field buffer
   construction. Retain the collection's three fields and session's
   thirteen fields. No new class, command, key, or editor method appears.
2. Live-maximum allocation with maxima on before, current, and after;
   sparse IDs in nonascending order, singleton allocation, and both
   session addition arities. Compare exact insertion focus/order, new defaults,
   independent expected IDs, retained neighbors, and source immutability.
   Larger removal preserves every survivor ID; removal followed by
   addition permits legal reuse. Singleton removal retains its ID while
   resetting editor/path, including a nonzero singleton ID.
3. Current-first bounded lookup, forward hits, wrap into before, last
   possible hit, and miss. Include non-ordered IDs and equal editor/path
   payloads with distinct IDs. Compare complete focused collections,
   logical order, unchanged buffer values, and untouched source values.
   The countdown must bound misses; equality with a starting value is
   not a termination test. Identity lookup makes no Fs call.
4. ID preservation through buffer `with-editor`/`with-path`, session
   editor/path rebuilds, `visited`, direct visit, save-as, cycling and
   named selection, and singleton removal/kill. Use rich editor and
   session payloads with nonzero IDs so an accidental reset to 0 fails.
   Preserve Text focus, point, origins, history, mark, remembered rows,
   search, echo, ring, pending, prompt, submission, and slot according
   to each operation's accepted contract; its existing resets still
   apply. Assert unchanged neighbors and exact complete results.
5. Duplicate-name `find-name` and find-file reuse keep their accepted
   current-first/first-forward policy, even for equal editor/path
   payloads with distinct IDs. Reuse does not allocate or read again;
   a genuinely added file buffer gets the live maximum plus one. Visit
   still replaces current rather than adding. Save-as binds the same ID.
   Count all Fs operations and retain exact targets and success/refusal
   effects; identity work introduces zero extra calls.
6. Fresh checked `file.aloe` load needs no Fs/Term injection and causes
   no effects. `main.aloe` still needs only Fs and starts with ID 0 and
   the exact thirteen-field session/defaults. Existing complete frame,
   fit, safe-cell, keymap, search, prompt, selection, and scripted runner
   proofs remain green after only their permitted fixture migrations.

The new focused proof must not create a window fixture/configuration or
test a later part. Source review, not output equality alone, establishes
fold-based allocation and bounded integer-ID lookup.

## Explicit non-goals

No view/tree/rectangle/windows class, session `windows` field, session
arity migration, editor `with-origin` or `frame-rows`, origin handoff,
multi-view synchronization, layout, selected-rectangle fit, fallback,
divider, split/delete/other-window/lock command, constructor, send, or key.
These belong to later parts in the accepted order.

No mode line, buffer menu, completion, unique/stored names, path-policy
change, persistent identity registry, counter, extra editor/point/history,
automatic operation, new Fs/Term effect, runner change, Text method,
List index, kernel message, Mirror, mutation, inheritance, delegation,
macro, implicit Int/Float coercion, new special form, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-buffer-identity.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes this focused proof and every predecessor. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or physical TTY
hand check is required. Launching the runner is optional; after a `.rkt`
edit, first run the named tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe`, because the launchers
load existing bytecode without rebuilding. `.aloe` edits need no rebuild.

Review source as well as results: IDs are appended and preserved at
every buffer reconstruction; both additions allocate before insertion;
allocation folds over all live IDs without a counter; identity lookup
uses integer comparison and a bounded forward countdown; name lookup,
session shape, command cases/maps, rendering, runner, Term, host,
libraries, and language retain their boundaries. Repeat the constructor
and inventory searches and check independent expectations and negative
cases. Confirm that only the permitted files changed.

Complete when the focused proof and full aloemacs suite pass,
`git diff --check` is clean, spec §§3.1/3.5's intermediate contract and
source review pass, and no migration or regression remains. Report the
initial missing-behavior failure, final verification results, changed
files, and structural review. Stop when green for human review. Do not
implement or issue the next window-state checkpoint.
