# aloemacs-windows 006 — Window lock

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Add `toggle-window-lock` / `C-x l` to flip the selected view's existing
lock bit. Prove that a locked view cannot be split or deleted, and that
deleting another view cannot move or resize its rectangle. Prove that
locking preserves the existing editing, buffer, origin, prompt, and
resize behavior.

This is the **window lock** part of accepted spec §7, numbered 006 after
the permitted state separation. Identity, state synchronization, layout,
rendering, selected fit, both splits, delete, and other-window are
implemented prerequisites. Their lock bits and geometry guards already
exist; this slice adds public access and its proof.

Stop after the focused proof and full suite pass. This is the final part
of the accepted windows series. Add no mode line, lock marker, buffer
menu, or later exploration.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 006**, filed as `checkpoints/006-lock.md`.
  This is a local editor checkpoint, not a global Aloe number.
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
  boundaries, and non-goals. §§3.1–3.4 govern buffer/view identity, the
  existing lock field, one editor per buffer, origin mirroring/handoff,
  and all existing-operation retargeting rules. §3.7 explains the issued
  number mapping. §§4.1–4.4 govern nominal geometry, selected fit,
  composition, and resize fallback; §§5–6 govern the reviewed split,
  deletion, and entry behavior. **All of §7** and **§8** govern this slice.
  §9's **window lock** verification, completed-series acceptance, and
  individual completion rules apply. Predecessor specs named in §1
  govern retained behavior.
- [000-buffer-identity.md](000-buffer-identity.md),
  [001-state-foundation.md](001-state-foundation.md),
  [002-synchronization-completion.md](002-synchronization-completion.md),
  [003-layout-and-rendering.md](003-layout-and-rendering.md),
  [004-split.md](004-split.md), and
  [005-delete-and-other.md](005-delete-and-other.md) are implemented in
  the current checkout. Preserve their substantive proofs. Historical
  [000-split.md](000-split.md) remains returned, unimplemented, and
  unauthorized for resumption.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  `AloemacsView` already has its fifth field, `locked : Bool`. Pure tree
  traversal/replacement, `rect-for`, all-four-coordinate rectangle
  comparison, split refusal, and deletion guards already exist.
  `other-window` supplies public view entry and origin handoff.
  Commands end at `OtherWindow`; the nested map ends at `"o"`.
- The unchanged runner in
  [aloemacs-run.rkt](../../../../../../host/racket/aloemacs-run.rkt)
  fits, frames, writes once, then reads/handles a key at the queried
  dimensions. Its `run-aloemacs-with-hosts` seam supports production
  runner scenarios without changing startup, the runner, or hosts.

The [README](../README.md) records 006 as window lock. The spec's intended
005 does not renumber issued work. No constructor migration, foundational
guard work, or renderer change remains for this slice.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: append the one command constructor and
  its name/execution cases, add the zero-argument session send and nested
  binding, and add pure selected-leaf lock replacement helpers within
  the existing window classes/session as needed. Helper names are
  implementation choices. Keep the two loads, class order, existing
  field/constructor shapes, and reviewed state, geometry, rendering,
  fit, split, deletion, entry, and buffer-operation behavior. Add no
  class, module, field, store, language send, or alternate lock command.
- Create `tests/aloemacs/windows-lock.rkt` before product edits. It owns
  all of §7, including public locked transitions, preservation through
  existing operations, resize/fallback, and actual runner scenarios.
  Use the existing checked driver, `rackunit`, counted Fs doubles, and
  scripted Term doubles.
- These ten existing test files, only for matching command/map
  inventories, newly bound prefix-miss examples, and now-owned lock
  absence assertions:

  | File | Permitted adjustment |
  |---|---|
  | `tests/aloemacs/keymap-session.rkt` | Append ToggleWindowLock to the independent command inventory and `"l"` binding expectation. Retain command names, concrete-host execution types, global map/default, shared save, and old dispatch proofs. |
  | `tests/aloemacs/buffer-session.rkt` | Append only the expected nested binding. Preserve all buffer transitions, effects, idle misses, and global-map assertions. |
  | `tests/aloemacs/prompt-commands-find-file.rkt` | Extend command/nested-binding inventories. Change the constructor-tail offset from four to five so the independent assertion still proves the exact zero-payload FindFile/SaveAs/SelectBuffer declarations before the five window constructors. Preserve lookup, prompt, submission, reuse, runner, and effect proofs. |
  | `tests/aloemacs/prompt-commands-save-as.rkt` | Extend only command/nested-binding inventories; retain every save-as behavior, target, and effect assertion. |
  | `tests/aloemacs/prompt-commands-select-buffer.rkt` | Extend only command/nested-binding inventories; retain every selection, name scan, prompt/slot, runner, and effect assertion. |
  | `tests/aloemacs/windows-state-foundation.rkt` | Extend the command inventory. Replace the consumed-prefix loop's now-bound `"l"` with an unbound printable key such as `"x"`, preserving its existing text/windows expectations. Retain every type, field, startup, origin, one-leaf transition, fit/frame, and effect proof. |
  | `tests/aloemacs/windows-state.rkt` | Extend command/nested-map inventories and remove ToggleWindowLock constructor absence. Replace the consumed-prefix example's `"l"` with `"x"`, preserving its complete independent expected session. Retain all synchronization, retargeting, kill, origin, reset, fit, frame, and effect proofs. |
  | `tests/aloemacs/windows-layout-and-rendering.rkt` | Extend command/nested-map inventories and remove toggle send/constructor absence checks. Replace the consumed-prefix loop's `"l"` with `"x"`; retain plain insertion for all five window characters. Preserve every geometry, complete ANSI golden, row helper, fit, fallback, purity, and effect assertion. |
  | `tests/aloemacs/windows-split.rkt` | Extend command/nested-map inventories; remove only toggle send/constructor absence and the absent `"l"` binding assertion. Remove `"l"` from the prefix-miss loop, retaining its other keys and plain insertion checks. Preserve all split guards, fresh IDs, shared ownership, origins, fits, frames, echo, routing, runner, resize, and effect proofs. |
  | `tests/aloemacs/windows-delete-and-other.rkt` | Extend command/nested-map inventories; remove toggle send/constructor absence and the absent `"l"` binding assertion. Remove `"l"` from the prefix-miss loop, retaining its other keys. Preserve every entry, handoff, deletion, lock-geometry guard, echo, reset, prompt, runner, fallback, and effect proof. |

  Test names describing removed lock absences may be updated to match
  the remaining assertions. Retain unrelated negatives, including
  `select-view`, `lock-window`, and `LockWindow`; this slice introduces
  only the specified toggle. Expected state changes are built
  independently, never by calling the new toggle or dispatch under test.

Current inventory searches find no matching adjustment in
`keymap-prefix.rkt`, `windows-buffer-identity.rkt`, or another existing
test. Earlier proofs receive only the adjustments above; put new lock
behavior and runner scenarios in the new focused file.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, startup,
  and every other product module. Buffers still own one editor, point,
  mark, and history; the session owns one ring. Views keep five fields,
  the configuration four, and the session fourteen.
- Every existing test not named above, including `tests/aloemacs/runner.rkt`
  and `windows-buffer-identity.rkt`. Add no later focused test.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, Fs/Term
  interfaces, `aloe/`, and `lib/`, including Text and List. Add no load,
  dependency, host capability, runner argument, or supplied-session seam.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  and this series' design/checkpoint documents.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening it. If finishing would
require compaction, report the size problem and stop for review; do not
split this assignment or start another exploration yourself.

## Slice requirements

### 1. Add exactly one session command and key

Append zero-payload `ToggleWindowLock` after `OtherWindow` in
`AloemacsCommand`, with exact name `"toggle-window-lock"`. Extend `name`
and session `execute-command` constructor cases; execution sends the
zero-argument method and ignores its key. The signature is:

```text
toggle-window-lock() -> (AloemacsSession H)
```

Retain the receiver's concrete host type. Add no command-owned execution
method or editor key arm. The final five window constructors are, in
order, SplitBelow, SplitRight, DeleteWindow, OtherWindow, ToggleWindowLock.

Append `"l" -> ToggleWindowLock` to the ordinary nested command bindings.
The final nested order is exactly:

```text
"save", "find", "kill", "b", "2", "3", "0", "o", "l"
```

The nested default remains `None`. Keep the global map, its command
order, its one prefix, shared save value, and `Some SelfInsert` default
exact. Plain `l` inserts through the idle global path; unknown idle
`"toggle-window-lock"` remains a miss, not a command-name router.
Remaining unbound second keys are consumed once without global retry.

### 2. Change only the selected lock bit

A direct toggle flips only the selected leaf's `locked` Bool. Replace
that leaf along its tree path; preserve every other leaf exactly.
Preserve selected view ID, buffer ID, stored origins, tree shape, nominal
rectangles, remembered full dimensions, and every session field outside
the configuration, including the entire buffer zipper and editors.

Do not call a buffer/origin mirroring helper, entry, fit, selection,
search reset, or echo setter to perform the toggle. It does not clamp an
origin, focus Text, push history, query Term, or perform file I/O.
Two direct toggles restore the entire original session, including rich
search/prompt/prefix/slot state and origins beyond EOF. Initial startup
and both children of an ordinary successful split remain unlocked.

Direct execution retains the existing absence of a general
quit/search/prompt guard. A direct toggle preserves a pending map;
normal chord dispatch clears it before execution. Starting `C-x` keeps
its existing echo clearing behavior. Compare direct/execute/chord
results on equivalent command-entry states, accounting for that
prefix consumption and prior echo change.

### 3. Prove protection through the existing guards

Lock the selected view, then refuse both splits and deletion. Unlock it
and prove those operations can succeed when their existing size and
last-view conditions permit. Use public toggle sends/chords to establish
the lock in this proof; do not prove public access solely with raw
already-locked fixtures.

Select and lock an unselected descendant of the subtree that would
survive another leaf's deletion. Refuse deletion if its nominal old/new
rectangle moves or resizes. Compare all four coordinates under the same
remembered full terminal size, including position-only changes in
zero-axis fallback. A lock outside the affected parent does not block
local split or deletion. A deep surviving locked descendant whose
nominal rectangle is exactly unchanged permits deletion. Cover the
accepted zero-extent nominal case rather than imposing a blanket ban on
locked sibling subtrees. Initially unlocked constructed mixed trees may
control geometry; establish their tested locks through public access.

Keep the unknown-size sibling-lock guard and last-view refusal from §6.
Normal command-created trees remember size. Commands continue to use
nominal rectangles during fallback, never the temporary full-screen
display rectangle. No new balancing, restriction, or guard algorithm
belongs here.

### 4. Preserve buffer operations, resize, echo, and input rules

Lock protects existence and rectangle. Other-window can enter a locked
view. Editing, scrolling, undo, fit, save/path changes, direct visit,
buffer addition/switch/selection, find-file, save-as, and buffer kill all
retain their accepted behavior under locks. Apply every §3.4 retargeting
row: selected-only operations leave inactive views exact; killing a
buffer retargets all its views without changing any lock or geometry;
singleton kill retains its ID and resets matching origins to `(0,0)`.

Prompt/submission/cancel and waiting-command behavior remain exact,
including Return acting on the then-current buffer after direct buffer
selection during a waiting prompt. Lock introduces no old target or
buffer pinning. Only accepted file operations make Fs calls.

Resize may move or resize rectangles independently of locks. Fit records
the supplied positive size and updates only the selected editor/origin
as before. Shrink may enter fallback; growth restores tree composition.
Neither changes tree shape, IDs, selection, or lock bits. Frame stays
pure, with the existing full-width echo and selected/prompt cursor.

Stored echo tokens remain exactly `""`, `"saved"`, and `"failed"`.
Toggle always preserves the stored token, even with an active prompt or
search. A refused split/delete stores `"failed"` only when neither is
active; with either active it preserves the whole session. Successful
commands retain §8's outcome rules, including same/different-buffer
entry and active-prompt preservation. Assert the hidden token as well as
the displayed active row and complete cursor bytes.

`handle-key` retains quit, search, prompt, then pending/global idle
precedence. A prompt ignores `ctrl-x` and owns printable `l`; search
treats it as query text and ends before forwarding named `ctrl-x`.
No toggle starts a prompt, arms a prefix, changes quit, or runs a waiting
command. Add no visual lock indicator.

### 5. Focused proof

Write the focused file first and observe missing behavior fail before
product edits. Use independently constructed expected sessions, trees,
rectangles, and complete ANSI Strings. Never call toggle, dispatch,
layout, or composition under test to build an expected value. No physical
TTY is required. Prove all of §7:

1. Exact zero-payload constructor, name and execution case, concrete typed
   send, final constructor/binding order, and wrong receiver/argument/
   arity rejection. Checked file load needs no injected Fs/Term and has
   no effects; main retains the accepted cold startup and unlocked view.
2. Exact bit-only change for sole and mixed nested trees with nonnumeric
   visit order, unlocked and locked selected views, shared/distinct buffer
   IDs, rich editor payloads, inactive origins beyond EOF, and remembered
   or unknown sizes. Toggle twice restores the whole session. Complete
   frames before/after toggle are equal when no intervening fit is needed.
3. Direct/execute/chord behavior, pending preservation versus consumption,
   plain `l` insertion, consumed misses, unknown command-name misses, and
   quit/search/prompt precedence. For each token, cover idle, search,
   prompt, and simultaneous prompt/search fixtures; assert exact active
   row and cursor and unchanged prompt line/slot/submission/ring.
4. Public locking followed by both split refusals and delete refusal,
   with complete preservation except the applicable §8 echo outcome.
   Cover every token with and without prompt/search; toggle itself always
   preserves it. Unlock and demonstrate successful splits/deletion and
   unlocked split children, preserving all reviewed geometry/origin rules.
5. Mixed trees with surviving descendant move/resize refusal, position-only
   fallback changes, unaffected outside locks, and permitted promotion
   with an exactly unchanged deep locked rectangle. Record independent
   old/new `(x,y,columns,rows)` values and expected candidate trees.
   Exercise other-window to leave/reenter locked views and retain the
   existing unknown-size guard; count zero window-command Fs calls.
6. Locks survive every operation named in §7: other-window, add/switch/
   selection, find-file reuse/addition, save-as, direct visit, nonsingleton
   kill/retarget and singleton kill, edits/undo, scrolling/fit, prompt
   submission/cancel, and redraw. Assert permitted retarget/origin/reset
   changes independently, exact untouched views/buffers, shared ownership,
   and exact accepted Fs targets/counts. Include a waiting prompt whose
   Return acts on the then-current buffer while the view remains locked.
7. Locked multi-view resize/shrink/fallback/growth preserves the tree and
   bits while selected fit and complete frames follow §§4/8. Preserve
   inactive origins; frame makes no state changes or extra file calls.
8. Use the actual production runner to drive lock, refused split/delete,
   unlock, successful split/delete, and quit. Exercise both split
   orientations across scripted scenarios. Compare complete frames and
   the unchanged size-query, fit/frame, one-write, then read/handle order
   and counts. Use counted Fs doubles to distinguish startup/accepted
   file effects from the zero effects of window commands. Add no runner,
   startup, Term, or host seam; all earlier proofs remain green.

## Explicit non-goals

No lock status label, marker, mode line, per-view row, buffer menu,
buffer pinning, `delete-other-windows`, balance/enlarge/shrink, saved
configuration, automatic window operation, mouse, weights, scrollbar,
face, highlighting, mode, folding, completion, `M-x`, or another prefix.

No constructor migration, new class/field/store, per-view editor/point/
mark/history/ring/page height/rectangle, renderer rewrite, paint cache,
runner/Term/Fs change, Text method, List index, kernel message, Mirror,
mutation, inheritance, delegation, macro, implicit Int/Float coercion,
new special form, next exploration, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-lock.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes completed identity, state, layout, split, delete/other-window,
and predecessor proofs. Do not commit `compiled/`. No wider suite,
benchmark, timing gate, or physical TTY hand check is required. Optional
launch remains `racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt`
edit, run the named tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe` first. Launchers load
existing bytecode; `.aloe` edits need no rebuild.

Review source as well as results: toggle changes only the selected bit;
the configuration is the only window store; locked geometry guards use
nominal old/new rectangles and all four coordinates; each buffer owns
one editor; reconstruction/retargeting retains locks; rendering remains
bounded and never installs inactive origins; command execution stays in
session constructor cases; echo follows §8. Confirm only named files
changed and earlier proofs received only scoped adjustments. No visual
marker, runner/Term/language change, or later exploration appears.

Complete when all of §7 is independently proved, the focused and full
suites pass, and source/whitespace review confirms the boundary. Apply
§9's completed-series acceptance across this proof and its predecessors.
Report the initial missing-behavior failure, final verification results,
changed files, and structural review. Stop when green for human review.
Do not implement or issue another checkpoint or start the mode line.
