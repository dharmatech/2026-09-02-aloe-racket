# aloemacs-windows 004 — Both splits

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Make the reviewed window tree, renderer, and selected-view fit reachable
through `split-below` / `C-x 2` and `split-right` / `C-x 3`. Split only the
selected leaf, retain its selection and shared buffer, give the new leaf
the live pre-split origin, and fit the original child once at the
remembered terminal size. Refuse unknown-size, locked, or too-small
selected rectangles with the accepted echo outcome.

This is the **both splits** part of accepted spec §5, numbered 004 after
the permitted state separation. Identity, synchronization, geometry,
rendering, and resize fallback are prerequisites already implemented.

Stop after the focused proof and full suite pass. Add no delete,
other-window, view-entry, or toggle command. Those parts follow only
after human review of this result.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 004**, filed as `checkpoints/004-split.md`.
  This is a local editor checkpoint, not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute through `call`. Use ordinary recursive
  constructor cases and lawful typed absent Options.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, staging, file
  boundaries, and non-goals. §§3.1–3.4 govern stable identity, single
  buffer ownership, origins, reconstruction, and existing buffer
  operations. §3.7 explains the issued number mapping. §§4.1–4.4 supply
  the reviewed geometry, fit, composition, and fallback contracts.
  **All of §5, including §5.1**, and **§8** govern this slice. §9's
  **both splits** verification and individual-checkpoint completion rules
  apply. Predecessor specs named in §1 govern retained behavior.
- [000-buffer-identity.md](000-buffer-identity.md),
  [001-state-foundation.md](001-state-foundation.md),
  [002-synchronization-completion.md](002-synchronization-completion.md),
  and [003-layout-and-rendering.md](003-layout-and-rendering.md) are
  implemented in the current checkout. Preserve their substantive proofs.
  The historical [000-split.md](000-split.md) remains returned,
  unimplemented, and unauthorized for resumption.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  `AloemacsWindowTree` already supplies ordered leaves, view lookup,
  selected-only replacement, nominal `rect-for`, and positive-layout
  checks. `AloemacsWindows.text-rect` derives the text root; `fit-rect`
  chooses selected geometry or full-screen fallback. Session fit mirrors
  selected only and remembers the full terminal dimensions. Session
  frame already composes constructed trees and preserves one-view bytes.
  Commands end at `SelectBuffer`; the nested map ends at `"b"`.
- The existing runner in
  [aloemacs-run.rkt](../../../../../../host/racket/aloemacs-run.rkt)
  already fits, frames, writes once, then reads/handles one key, using
  the same queried dimensions. Its `run-aloemacs-with-hosts` seam supports
  actual split-key scenarios without a runner or startup change.

The [README](../README.md) records the mapping: 004 is both splits;
the later unissued parts are delete and other-window (005), then window
lock (006). The spec's intended numbers do not renumber issued work.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: append the two command constructors and
  name/execution cases, add the two session sends and ordinary nested
  bindings, and add pure split/allocation helpers within the existing
  `AloemacsWindowTree`, `AloemacsWindows`, and `AloemacsSession` classes
  as needed. Keep the two loads, class order, every existing field and
  constructor shape, and the reviewed renderer/fit behavior. Helper names
  are implementation choices; no new class, module, or language send
  is required.
- Create `tests/aloemacs/windows-split.rkt` before product edits. It owns
  all of §5.1's split proof, including the actual runner scenarios. Use
  the existing checked driver, `rackunit`, counted Fs doubles, and
  scripted Term doubles.
- The following seven existing test files, only for the matching
  command/map inventory or newly bound prefix-miss adjustments:

  | File | Permitted adjustment |
  |---|---|
  | `tests/aloemacs/keymap-session.rkt` | Append the two entries to the independent command inventory and expected nested bindings. Retain the command-name, concrete-host execution-type, global-map/default, shared-save, and old-dispatch proofs. |
  | `tests/aloemacs/buffer-session.rkt` | Append the two expected nested bindings in the production-map test. Preserve every buffer transition, effect, idle miss, and global-map assertion. |
  | `tests/aloemacs/prompt-commands-find-file.rkt` | Extend command and nested-binding inventories. Adjust the assertion that the three prompt commands occupy the constructor tail so it still proves their exact ordered zero-payload declarations before the two new split constructors. Preserve all lookup, prompt, submission, reuse, runner, and effect assertions. |
  | `tests/aloemacs/prompt-commands-save-as.rkt` | Extend only command and nested-binding inventories. Keep every save-as behavior, target, and effect assertion. |
  | `tests/aloemacs/prompt-commands-select-buffer.rkt` | Extend only command and nested-binding inventories. Keep every selection, name scan, prompt/slot, runner, and effect assertion. |
  | `tests/aloemacs/windows-state-foundation.rkt` | Extend the command inventory; remove only split sends/constructors from future-command absence checks. Restrict any prefix-miss examples to keys still unbound (`"0"`, `"o"`, `"l"`). Keep all field/class/type, startup, origin, synchronization, one-view fit/frame, and effect proofs. |
  | `tests/aloemacs/windows-state.rkt` | Extend command/nested-map inventories; remove only split sends/constructors from future-command absence checks. Replace `"2"` with a still-unbound key such as `"0"` in the existing consumed-prefix example, keeping its complete independent expected session. Preserve all multi-view synchronization, geometry-fit expectations, frame, origin, retarget, kill, reset, and effect assertions. |
- `tests/aloemacs/windows-layout-and-rendering.rkt`: inventory adjustments
  only. Append the two constructors/bindings; remove only the now-owned
  split sends/constructors from future-command absence checks. Retain
  plain insertion checks for all five characters. Restrict the former
  unbound-prefix loop to `"0"`, `"o"`, `"l"`; prove `"2"`/`"3"` in the
  new split file instead. Keep every complete ANSI golden, geometry,
  row-helper, selected-fit, fallback, purity, and effect assertion exact.

Current searches find no matching adjustment in `keymap-prefix.rkt`,
the earlier buffer-identity proof, or any other existing test. No
constructor migration remains. Earlier focused tests receive only the
inventory changes just named; do not replace their behavior with calls
to the split under test or weaken their assertions to make them pass.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, startup,
  and every other product module. Add no second editor or per-view point,
  mark, history, ring, page height, or stored rectangle.
- Every existing test not named above, including runner tests and
  `windows-buffer-identity.rkt`. Put new runner scenarios in
  `windows-split.rkt`; create no later part's focused test early.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, Fs/Term
  interfaces, `aloe/`, and `lib/`, including Text and List. Add no load,
  dependency, capability, runner argument, or supplied-session entry point.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  and this series' design/checkpoint documents.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening it. If finishing would
require compaction, report the size problem and stop for review; do not
split the assignment or start its successor yourself.

## Slice requirements

### 1. Add exactly two session commands and keys

Append zero-payload `SplitBelow`, then `SplitRight`, after `SelectBuffer`
in `AloemacsCommand`. Their exact names are `"split-below"` and
`"split-right"`. Extend its `name` case and session `execute-command`
case; execution calls the corresponding zero-argument session send and
ignores its `key` argument.

```text
split-below() -> (AloemacsSession H)
split-right() -> (AloemacsSession H)
```

Retain the receiver's concrete host type. Do not add an editor key arm,
command-owned execution method, general input guard, or string command
router. Direct execution retains its existing ability to run on a raw
session with pending, prompt, search, or quit state; `handle-key` retains
its accepted precedence.

Keep existing nested bindings first; append `"2" -> SplitBelow`, then
`"3" -> SplitRight`. Exact nested order is now:

```text
"save", "find", "kill", "b", "2", "3"
```

Nested default remains `None`. Keep the global binding order, its one
`C-x` prefix, the shared save command, and `Some SelfInsert` default.
Plain `2`, `3`, `0`, `o`, and `l` still insert on the idle global path.
`C-x 0`, `C-x o`, and `C-x l` remain consumed misses here. Every other
unbound second key remains consumed once without retry on the global map.

### 2. Guard using remembered nominal geometry

Both direct sends use only the full terminal size already remembered
inside `windows`. Query no Term or Fs and guess no initial size. Refuse
unless both remembered dimensions are positive. At positive size, derive
the root text rectangle under §4.1 and the selected leaf's **nominal**
rectangle from the existing tree.

Refuse if selected is locked, either nominal axis is zero, or the split
direction has fewer than three cells: height for Below, width for Right.
Apply §8's echo rule below. No other state changes on refusal; with an
active prompt or search, return a completely unchanged session.

Do not use the full-screen fallback `fit-rect` as the selected nominal
rectangle for the guard. Another leaf may force global painting fallback
while selected remains positive. The command still judges the selected
nominal rectangle; the existing post-split fit independently follows
§4.3's selected-rectangle or global-fallback rule. No blanket refusal for
an unselected lock or another zero-sized leaf is added.

The geometry stays recursive and unweighted. The divider consumes one
cell, with any leftover assigned to top/left. Splitting only selected
does not move or resize any ancestor/sibling view, including locked
views outside the replaced leaf. Lock toggle and deletion geometry
comparisons belong to later parts.

### 3. Replace one leaf, then fit selected once

On success, capture current editor's live `(scroll-row, scroll-col)`
immediately before the split. Allocate the new view ID as one more than
the largest live view ID over the complete tree; use no stored counter,
leaf count, buffer ID, or selected-ID assumption. Sparse IDs and visit
order distinct from numeric order remain lawful. Reuse after deletion
is permitted by the spec, but this slice adds no deletion operation.

Replace only selected's leaf with `Below(original, new)` or
`Right(original, new)`, preserving the path and every other subtree.
Both children show the original buffer ID, start with the captured live
origin, and are unlocked. The original retains its ID, stays selected,
and occupies top/left; the fresh leaf occupies bottom/right. Repeated
splits nest binary constructors; do not flatten or balance.

With the candidate tree installed and the same remembered dimensions,
perform one explicit session `ensure-visible`. It fits only the original
selected child and the one shared buffer editor, changing only its
origin and remembered `text-rows` as needed and mirroring that origin to
selected. The fresh child keeps the **pre-split** origin even when fit
scrolls the original child. Every inactive view, including other views
of the same buffer, remains exact. Remembered full size is unchanged.

Apart from tree replacement, permitted fit changes, and echo, preserve
the buffer zipper/order, IDs, paths, exact Text value/focus, shared point,
quit, history, mark, Fs, ring, every search field, pending, prompt, last
submission, and waiting command. Do not push undo, run a waiting prompt
command, read/write a file, start a prompt, request quit, or arm a prefix.
The existing single-editor ownership and §3.4 retargeting rules apply
after real splits without reimplementation.

### 4. Preserve echo and input ownership

The stored tokens remain exactly `""`, `"saved"`, and `"failed"`.

| Split result | Active prompt or search remains | Neither remains |
|---|---|---|
| Success | Keep the initial token | Store `""` |
| Refusal | Keep the initial token; whole session unchanged | Store `"failed"` |

Direct splits preserve prompt and every search field. Their painting
continues to hide the stored token behind the active prompt/search row.
Do not overwrite it and then reconstruct an apparent equivalent row.
An orphan waiting slot is preserved but does not itself trigger token
preservation. Direct splits preserve a pending map; ordinary chord
dispatch has already cleared it before executing the split command.

`handle-key` remains quit, search, prompt, then pending/global idle
dispatch. A prompt owns its input, ignores `ctrl-x`, and treats printable
digits as prompt text. Search uses printable digits as query text and
ends before forwarding named `ctrl-x`; a later split chord consequently
uses the echo rule for the state then present. No window chord bypasses
these owners.

Reuse the reviewed composer. Multi-view frames retain full-width clipped
safe echo, one clear/hide/show pair, padded rows, geometry-derived
dividers/junctions, and the translated selected or prompt cursor. One-leaf
and too-small-tree fallback bytes remain exact.

### 5. Focused proof, written first

Write `tests/aloemacs/windows-split.rkt` and observe missing behavior fail
before product edits. Build expected trees, sessions, editor payloads,
rectangles, and **complete ANSI Strings** independently of the split,
dispatch, allocation, fit, or composer under test. Raw constructors and
selectors may describe expected values; do not add a future entry or
selection API to arrange fixtures.

Complete all of accepted spec §5.1:

1. Exact zero-payload constructor/name order, both typed sends with
   concrete host results, execution ignoring key, and nested bindings.
   Reject wrong receivers, types, and arities. Fresh checked file load
   needs no Fs/Term injection or effect; main retains its cold startup,
   one unlocked view, fourteen session fields, and unknown size.
2. Both orientations at minimum extent three and odd/even larger
   extents; unknown-size, extent-one/two, zero-nominal-axis, and selected
   constructed-lock refusals. Prove exact selection, IDs, geometry,
   captured origins, permitted post-fit changes, and zero Fs effects.
   Include sparse IDs with the maximum away from selected. Distinguish
   nominal geometry from fallback display geometry, including a zero
   selected axis despite a positive full-screen fallback and a positive
   selected rectangle while another leaf forces fallback.
3. Repeated and mixed splits preserve binary shape, depth-first visit
   order, ancestor/sibling rectangles, locks, and inactive state. Use
   nonzero pre-split origins and a point that forces post-split scrolling
   to distinguish the fresh child's origin from the selected fit. Compare
   full padded frames for both dividers, T/cross junctions, one cursor,
   and one full-width echo. Fit/frame preserve their existing purity
   and bounded-rendering contracts.
4. Shared edit/undo redraws all views from one buffer's text, point,
   history, and mark; origins remain independent. Selected-height page
   motion follows post-split fit. Shortened text or direct visit leaves
   inactive beyond-EOF origins unchanged and paints their blank rows.
   Exercise existing buffer operations after real splits, preserving
   §3.4's selected-only retargeting and all-view killed-ID replacement;
   the exhaustive constructed-state proof remains in `windows-state.rkt`.
5. Direct-send, execute-command, and chord equivalence through redraw,
   comparing equivalent starting prefix/echo state and explicitly
   accounting for direct pending preservation versus chord consumption.
   Prove all five plain characters still insert, still-unbound second
   keys are consumed, and quit/search/prompt ownership stays exact.
   With each initial token (`""`, `"saved"`, `"failed"`), test successful
   and refused direct splits with prompt, search, both, and neither.
   Compare complete sessions on guarded refusals, the hidden token,
   active row, and cursor. Prove no waiting command runs. Include search
   exit through `ctrl-x` before the split chord.
6. Call the unchanged production `run-aloemacs-with-hosts` with scripted
   Term sizes/keys and counted Fs: split in both orientations, edit,
   save to the exact expected target/content, and quit. Assert complete
   frames and the existing fit-before-frame, one write per drawn
   iteration, read/handle, and quit-stop contract. Shrink triggers
   full-screen fallback; growth restores the split tree. Pair observable
   runner frames with direct state assertions for remembered size,
   selection, inactive origins, and tree preservation. Window commands
   add no Fs calls. Existing runner tests stay unchanged.

Retain all earlier focused proofs and existing-suite assertions except
the exact inventory/prefix adjustments scoped above. In the new proof,
assert delete/other/toggle constructors, sends, and bindings remain
absent, along with public view entry/selection. Source review also proves
ownership and implementation boundaries; equality alone cannot do so.

## Explicit non-goals

No DeleteWindow, OtherWindow, ToggleWindowLock, corresponding session
send/key, view entry, sibling promotion, deletion guard, public lock
toggle, or extra selection API. The existing lock bit is used only for
split refusal on a constructed selected view.

No constructor migration, new class/field/store, next-ID counter,
renderer rewrite, automatic split/delete, balance/resize command, mode
line, buffer menu, saved configuration, weights, per-view editor/point/
mark/history/ring/page height, face, highlight, or paint cache.

No runner/Term/Fs change, Text method, List index, kernel message, Mirror,
mutation, inheritance, delegation, macro, implicit Int/Float coercion,
new special form, next exploration, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-split.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes all completed identity, state, layout, and predecessor proofs.
Do not commit `compiled/`. No wider suite, benchmark, timing gate, or
physical TTY hand check is required. Optional launch remains
`racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt` edit, run
the named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`
first. Launchers load existing bytecode; `.aloe` edits need no rebuild.

Review source and results: the existing configuration is the only window
store; fresh IDs come from all live leaves; split replaces only the path
to selected; guards use nominal remembered geometry; both child origins
are captured before one selected fit; each buffer owns one editor;
rendering remains bounded and never installs an inactive origin; command
execution stays in session constructor cases; echo follows §8; no later
command or runner/Term/language change appears. Confirm only the named
files changed and existing proofs received only their scoped adjustments.

Complete when both splits are independently proved against all of §5,
focused and full suites pass, and source/whitespace review confirms the
boundary. Report the initial missing-behavior failure, final verification
results, changed files, and structural review. Stop when green for human
review. Do not implement or issue delete and other-window or any later
checkpoint.
