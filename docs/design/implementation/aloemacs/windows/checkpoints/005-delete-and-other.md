# aloemacs-windows 005 — Delete and other-window

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Make `other-window` / `C-x o` visit the next leaf in tree order, and
`delete-window` / `C-x 0` remove the selected leaf by promoting its
immediate sibling. Store the departing live origin, install the entered
view's origin on its shared buffer editor, and apply search, prefix, and
echo rules according to buffer identity. Refuse removal of the last or
a locked view, or a deletion that changes a surviving locked rectangle.

This is the **delete and other-window** part of accepted spec §6,
numbered 005 after the permitted state separation. Identity, state
synchronization, layout, rendering, selected fit, and both splits are
implemented prerequisites.

Stop after the focused proof and full suite pass. Add no lock toggle,
lock key, mode line, or later exploration. Public lock access follows
only after human review of this result.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 005**, filed as
  `checkpoints/005-delete-and-other.md`. This is a local editor
  checkpoint, not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute through `call`. Use ordinary
  recursive constructor cases, guarded List first/rest traversal, and
  lawful typed absent Options.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, staging, file
  boundaries, and non-goals. §§3.1–3.4 govern stable identity, tree visit
  order, single buffer ownership, origin handoff, reconstruction, and
  existing buffer operations. §3.7 explains the issued number mapping.
  §§4.1–4.4 supply nominal geometry, selected fit, composition, and
  fallback; §5 supplies the reviewed split behavior. **All of §6,
  including §6.3**, and **§8** govern this slice. §9's **delete and
  other-window** verification and individual completion rules apply.
  Predecessor specs named in §1 govern retained behavior.
- [000-buffer-identity.md](000-buffer-identity.md),
  [001-state-foundation.md](001-state-foundation.md),
  [002-synchronization-completion.md](002-synchronization-completion.md),
  [003-layout-and-rendering.md](003-layout-and-rendering.md), and
  [004-split.md](004-split.md) are implemented in the current checkout.
  Preserve their substantive proofs. Historical [000-split.md](000-split.md)
  remains returned, unimplemented, and unauthorized for resumption.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  The tree already supplies `leaves`, `find-view`, selected-only
  replacement, nominal `rect-for`, and positive-layout checks.
  `AloemacsWindows.text-rect` supplies the text root at a full terminal
  size. Buffer `find-id` focuses a matching ID without changing logical
  order. Editor `with-origin` changes only its two origin fields.
  Session fit and frame already support selected geometry and fallback.
  Commands end at `SplitRight`; the nested map ends at `"3"`.
- The unchanged runner in
  [aloemacs-run.rkt](../../../../../../host/racket/aloemacs-run.rkt)
  fits, frames, writes once, then reads/handles a key at the queried
  dimensions. Its `run-aloemacs-with-hosts` seam supports production
  runner scenarios without a startup, runner, or host change.

The [README](../README.md) records the mapping: 005 is delete and
other-window; window lock is the later unissued 006. The spec's intended
numbers do not renumber issued work. No constructor migration or renderer
work remains for this slice.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: append the two command constructors and
  name/execution cases, add the two session sends and nested bindings,
  and add pure traversal, entry, sibling-promotion, and geometry-guard
  helpers within the existing window classes and `AloemacsSession` as
  needed. Helper names are implementation choices. Keep the two loads,
  class order, all existing field/constructor shapes, and reviewed
  rendering, fit, split, and buffer-operation behavior. Add no new class,
  module, field, store, language send, or buffer-selection key.
- Create `tests/aloemacs/windows-delete-and-other.rkt` before product
  edits. It owns all of §6.3, including constructed-lock guards and actual
  runner scenarios. Use the existing checked driver, `rackunit`, counted
  Fs doubles, and scripted Term doubles.
- These nine existing test files, only for matching command/map
  inventories, newly bound prefix-miss examples, and the now-owned
  entry/command absence checks:

  | File | Permitted adjustment |
  |---|---|
  | `tests/aloemacs/keymap-session.rkt` | Append DeleteWindow/OtherWindow to the independent command inventory and expected nested bindings. Retain command names, concrete-host execution types, global map/default, shared save, and old dispatch proofs. |
  | `tests/aloemacs/buffer-session.rkt` | Append the two expected nested bindings. Preserve buffer transitions, effects, idle misses, and global-map assertions. |
  | `tests/aloemacs/prompt-commands-find-file.rkt` | Extend command/nested-binding inventories. Adjust the constructor-tail offset so the independent assertion still proves the exact ordered zero-payload FindFile/SaveAs/SelectBuffer declarations before the four window constructors. Preserve lookup, prompt, submission, reuse, runner, and effect proofs. |
  | `tests/aloemacs/prompt-commands-save-as.rkt` | Extend only command/nested-binding inventories; retain every save-as behavior, target, and effect assertion. |
  | `tests/aloemacs/prompt-commands-select-buffer.rkt` | Extend only command/nested-binding inventories; retain every selection, name scan, prompt/slot, runner, and effect assertion. |
  | `tests/aloemacs/windows-state-foundation.rkt` | Extend the command inventory; remove newly owned delete/other-window sends and constructors from absence checks. Restrict its prefix-miss loop to the still-unbound `"l"`. Preserve all types, fields, startup, origin, one-leaf operations, fit/frame, and effect proofs. |
  | `tests/aloemacs/windows-state.rkt` | Extend command/nested-map inventories and remove newly owned command absences. Replace the consumed-prefix example's `"0"` with `"l"`, preserving its complete independent expected session. Retain every synchronization, origin, retarget, kill, reset, fit, frame, and effect proof. |
  | `tests/aloemacs/windows-layout-and-rendering.rkt` | Extend command/nested-map inventories and remove newly owned command absences. Restrict the unbound-prefix loop to `"l"`; retain plain insertion for all five characters. Preserve every geometry, complete ANSI golden, row-helper, selected-fit, fallback, purity, and effect assertion. |
  | `tests/aloemacs/windows-split.rkt` | Extend command/nested-map inventories; remove delete/other-window absences and newly bound `"0"`/`"o"` from prefix-miss/absent-binding loops. Keep plain insertion checks. Preserve all split guards, fresh IDs, shared ownership, origins, fits, frames, echo, routing, runner, resize, and effect proofs. |

  In the four earlier window proofs, an absence assertion for `select-view`
  or `enter-view` may be removed only if that selector is used for the
  origin-entry helper now owned by §6. This permits the specified handoff,
  not another command or key. Retain lock-toggle absence checks and all
  unrelated type negatives. Put the new entry proof in the new focused file.

Current searches find no matching adjustment in `keymap-prefix.rkt`,
`windows-buffer-identity.rkt`, or another existing test. Earlier proofs
receive only the adjustments above; do not weaken their behavior or
derive their expected sessions through a new command under test.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, startup,
  and every other product module. Keep one editor/point/history/mark per
  buffer and one session ring; views retain only their existing fields.
- Every existing test not named above, including `tests/aloemacs/runner.rkt`
  and `windows-buffer-identity.rkt`. Put new runner scenarios in
  `windows-delete-and-other.rkt`. Do not create `windows-lock.rkt` early.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, Fs/Term
  interfaces, `aloe/`, and `lib/`, including Text and List. Add no load,
  dependency, host capability, runner argument, or supplied-session seam.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  and this series' design/checkpoint documents.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening it. If finishing would
require compaction, report the size problem and stop for review; do not
split this assignment or start its successor yourself.

## Slice requirements

### 1. Add exactly two session commands and keys

Append zero-payload `DeleteWindow`, then `OtherWindow`, after `SplitRight`
in `AloemacsCommand`. Their exact names are `"delete-window"` and
`"other-window"`. Extend `name` and session `execute-command` constructor
cases; execution calls the corresponding send and ignores its key.

```text
delete-window() -> (AloemacsSession H)
other-window()  -> (AloemacsSession H)
```

Retain the receiver's concrete host type. Execution stays in session
constructor cases. Add no editor key arm, command-owned execution method,
string command router, or general direct-execution input guard.

Append `"0" -> DeleteWindow`, then `"o" -> OtherWindow`. Exact nested order:

```text
"save", "find", "kill", "b", "2", "3", "0", "o"
```

The nested default remains `None`. The global map, one prefix, command
order, shared save value, and `Some SelfInsert` default stay exact.
Plain `0` and `o` insert; `C-x l` remains an unbound consumed second key.
No ToggleWindowLock constructor, send, or binding exists yet.

### 2. Other-window and origin handoff

Use depth-first top-before-bottom / left-before-right leaf order. Select
the next leaf after the selected view ID; wrap last to first. Do not
sort IDs or follow buffer order. Guard List head/rest traversal. With
one leaf, return the complete session unchanged, including rich raw state.

For a different leaf, store the departing live editor origin on that
view before entry. Focus the destination buffer through `find-id`, then
install the destination view's stored origin through editor `with-origin`.
Preserve logical buffer order and IDs. Keep all text, exact Text focus,
points, quit flags, histories, marks, paths, and remembered editor text
rows; only the required editor origins and zipper focus may change.
Origins are not clamped or fitted during entry. A shared buffer still
owns one editor and one point. Unselected views keep their origins;
locks, tree shape, and remembered full terminal size stay exact.

Compare destination and departing **buffer IDs** for resets:

- Same ID: preserve echo, all search fields, pending, prompt, submission,
  waiting command, ring, and Fs exactly. Only selection and the origin
  handoff change. Search retains its one point and saved Position.
- Different ID: accept the departing search-result point, then set
  searching/wrapped/failing to `#f`, query to `""`, search origin to
  `Position(0,0)`, and pending to `None`. Preserve Fs, ring, active prompt,
  last submission, and waiting command. Retain echo if a prompt remains;
  otherwise store `""`. Names and equal editor/path values do not decide
  this reset.

Do not use existing `selected-buffers` blindly: it retargets selected and
resets even on the same buffer. This slice changes selected view instead.
The caller/runner performs the next explicit `ensure-visible`; entry
itself never fits. A normative frame after entry follows that fit.

### 3. Delete, sibling promotion, and locked geometry

Refuse if selected is the sole leaf or is locked. Otherwise replace its
immediate parent split with the surviving sibling, which may be a leaf
or subtree. Rebuild only the affected ancestor path. Keep the sibling's
structure, IDs, origins, and lock bits; derive its descendant layout in
the old parent's rectangle. All geometry outside that parent stays
exact. Never flatten, balance, kill a buffer, or remove another view.

Before installing the candidate tree, compare old and candidate nominal
rectangles for every surviving locked view under the same remembered
full terminal size. Refuse if any of `x`, `y`, `columns`, or `rows`
changes. Use tree geometry, including during the display fallback, not
the temporary full-screen selected display. A lock outside the affected
parent does not block deletion; a locked surviving rectangle that stays
exactly equal does not block it either. Do not reject merely because
the sibling subtree contains a lock.

For a raw multi-view fixture with unknown size, conservatively refuse
when any surviving sibling descendant is locked. Unlocked deletion
requires no fit or known size. Normal split-created trees have a size.

On success select the sibling leaf, or the subtree's first leaf in
visit order. Apply the same origin handoff and buffer-ID-dependent
resets as other-window. Preserve Fs, prompt/slot/submission/ring, all
buffer IDs and logical order, text, Text focus, points, quit, histories,
marks, and paths. Remembered size stays exact; do not fit automatically.
Views elsewhere of the removed leaf's buffer stay intact, and a buffer
with no remaining view stays in the collection. Delete performs no I/O.

### 4. Echo and input precedence

Stored vocabulary remains `""`, `"saved"`, `"failed"`. Apply §8:

| Outcome | Stored echo |
|---|---|
| Same-buffer entry through other-window or successful delete | Unchanged, with or without prompt/search |
| Different-buffer entry, active prompt retained | Unchanged; clear search and pending as above |
| Different-buffer entry, no active prompt | `""`; clear search and pending as above |
| Refused delete, active prompt or search | Unchanged; complete session unchanged |
| Refused delete, neither active | `"failed"`; every other field unchanged |
| Singleton other-window | Complete session unchanged |

Direct sends do not cancel prompts or search before executing, and
preserve raw pending on same-buffer entry. A buffer change clears it.
Chord dispatch consumes pending before execution. Retain `handle-key`'s
quit, search, prompt, then pending/global idle precedence and the existing
prefix-installation echo behavior. Prompts own their input and ignore
`ctrl-x`; search treats printable characters as query text and exits
before forwarding named `ctrl-x`. Unknown idle command-name strings
remain misses. Neither new command starts a prompt, arms a prefix, or
requests quit. Prompt/search paint can hide the stored token; test both.

### 5. Focused proof

Write the focused file first and observe missing behavior fail before
product edits. Build expected trees, sessions, rectangles, and complete
ANSI Strings independently of entry, deletion, dispatch, layout, and
composition under test. No physical TTY is required. Prove all of §6.3:

1. Exact ordered zero-payload constructors, names, typed sends retaining
   concrete host types, name/execution cases, and nested bindings. Reject
   wrong receiver/argument/arity uses. Fresh checked file load needs no
   injected Fs/Term and has no effects; startup retains prior defaults.
   Prove direct/execute-command/chord behavior on equivalent command-entry
   states, plain `0`/`o` insertion, consumed misses, idle command-name
   misses, and unchanged quit/search/prompt precedence.
2. One, two, and at least three leaves with mixed nested splits and view
   IDs deliberately out of numeric order. Assert next/wrap order
   independently of buffer order; singleton whole-session equality;
   storage of the departing live origin; destination installation;
   same-buffer preservation and different-ID resets even with duplicate
   names/equal content. Rich editors prove exact Text focus, point,
   history, mark, quit, path, and remembered text-row preservation.
3. A round trip without fit/edit restores each view's origin. No second
   point appears; shared edits/undo remain visible through shared views.
   Fit only after entry and compare complete ANSI frames with translated
   selected cursor, full-width echo, and prompt cursor priority. Keep
   inactive origins, locks, dimensions, and other buffers exact.
4. Delete either side of each orientation, a nested selected leaf, and a
   leaf with a subtree sibling. Prove promotion into the old parent
   rectangle, first-leaf selection, exact outside geometry, logical
   buffer order, permitted origin changes, preserved rich state, and
   zero Fs calls. The buffer set remains intact, including an unshown
   buffer and other views of the deleted leaf's buffer. Delete must not
   send kill-buffer. Include deletion that restores displayable layout
   from a too-small-tree fallback.
5. Last-view, selected-lock, and surviving-lock move/resize refusals.
   Compare all four coordinates; include a position change and an
   unaffected outside lock. Prove an exactly unchanged locked rectangle
   permits deletion rather than a blanket subtree-lock ban. Include
   unknown-size raw fixtures with a locked sibling descendant and an
   unlocked permitted deletion. Refusal preserves every other field;
   with prompt or search the entire session stays equal. Construct lock
   bits directly; no toggle is needed for this proof.
6. For every initial token (`""`, `"saved"`, `"failed"`), cover same-buffer
   entry with/without prompt/search, different-buffer entry with/without
   prompt (including active search), and refused deletion with/without
   prompt/search. Assert hidden stored token as well as complete active
   row and cursor bytes. Same-buffer entry keeps pending/search; buffer
   change clears them. Preserve prompt line, waiting slot, submission,
   and ring. Chord comparisons account for pending consumption and
   existing prefix echo clearing before command execution.
7. Existing prompt commands retarget only selected without changing tree
   shape. Direct window selections while a prompt is waiting keep its
   line/slot; Return acts on the then-current buffer. Count only the
   accepted prompt-command file effects; window commands make none.
8. Use the actual production runner to split, select another view, edit
   in its different rectangle, delete, and quit. Compare complete frames
   and the unchanged fit/frame/write/read ordering and counts, using
   scripted Term dimensions/keys and counted Fs doubles. No runner,
   startup, or host seam edit is permitted. Every earlier proof stays
   green, and this proof passes without ToggleWindowLock or `C-x l`.

## Explicit non-goals

No public lock toggle, lock binding, status marker, mode line, buffer
menu, `delete-other-windows`, balance/enlarge/shrink, saved configuration,
automatic window operation, buffer pinning, mouse, weights, scrollbar,
face, highlighting, mode, folding, completion, `M-x`, or another prefix.

No constructor migration, new class/field/store, per-view editor/point/
mark/history/ring/page height/rectangle, renderer rewrite, paint cache,
runner/Term/Fs change, Text method, List index, kernel message, Mirror,
mutation, inheritance, delegation, macro, implicit Int/Float coercion,
new special form, next exploration, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-delete-and-other.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes completed identity, state, layout, split, and predecessor proofs.
Do not commit `compiled/`. No wider suite, benchmark, timing gate, or
physical TTY hand check is required. Optional launch remains
`racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt` edit, run
the named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`
first. Launchers load existing bytecode; `.aloe` edits need no rebuild.

Review source as well as results: the configuration is the only window
store; selection follows tree order and IDs; handoff changes only origins
and permitted focus/state; deletion promotes only the immediate sibling;
lock guards compare nominal old/new rectangles; each buffer owns one
editor; rendering remains bounded and never installs inactive origins;
commands execute in session constructor cases; echo follows §8. Confirm
only named files changed and earlier proofs received only scoped
adjustments. No toggle or runner/Term/language change appears.

Complete when all of §6 is independently proved, focused and full suites
pass, and source/whitespace review confirms the boundary. Report the
initial missing-behavior failure, final verification, changed files, and
structural review. Stop when green for human review. Do not implement or
issue window lock or any later checkpoint.
