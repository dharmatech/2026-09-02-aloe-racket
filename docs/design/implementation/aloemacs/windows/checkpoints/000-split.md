# aloemacs-windows 000 — Shared-buffer views and both splits

**Status.** Returned for scope review; do not implement.

The implementer stopped before edits or tests after estimating that this
slice would require compaction. The manager accepts that size finding.
See [the scope review](../scope-review.md) for the proposed separation
and the charter/spec constraints that must be revised first. The body
below records the issued assignment; it is not current authorization to
implement it. No replacement checkpoint has been issued.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Introduce stable buffer IDs and a binary tree of views, with one selected
leaf and independent display origins over shared buffer editors. Make
`C-x 2` split below and `C-x 3` split right. Fit only the selected view,
compose safe rows and dividers into one frame, and retain every accepted
single-view behavior and complete frame byte sequence. Existing buffer
operations must keep the tree and retarget its views as specified.

This is the independently testable foundation and split slice. Stop
before delete, other-window, and lock toggle: no sends, command
constructors, bindings, or focused tests from 001 or 002 belong here.
The lock bit exists now, and splits respect a constructed locked view;
the public toggle is later. Do not start the mode line or Boids.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 000**, filed as
  `checkpoints/000-split.md`. This is a local application checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
  Code and tests go in that root, not this design folder.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains language law. Evaluation is send with a literal
  selector; function objects execute only through `call`.
- The accepted [../spec.md](../spec.md) §§1–2 govern predecessors,
  authority, host, boundaries, and non-goals. §§3.1–3.4 govern all state
  and existing-buffer integration introduced here. §§4.1–4.4 govern
  geometry, explicit-origin rows, fit, and composition. §5 and §5.1
  govern split behavior and the complete focused proof. §8 governs echo
  and routing. §9's **000** commands, structural review, and acceptance
  conditions applicable to this slice govern completion. §§6–7 describe
  later checkpoints and are not implementation assignments.
- There is no predecessor in this series. Aloemacs layers 1–16 are
  implemented; in particular, [aloemacs-prompt-commands 002](../../prompt-commands/checkpoints/002-select-buffer.md)
  is implemented, reviewed, and accepted, as its
  [README](../../prompt-commands/README.md) records. Stored viewport,
  safe cells, echo, command/prefix dispatch, the nonempty buffer zipper,
  and prompt completion are installed. No runner change is a prerequisite.
- Start from [editor.aloe](../../../../../../examples/aloemacs/editor.aloe),
  [file.aloe](../../../../../../examples/aloemacs/file.aloe), and
  [main.aloe](../../../../../../examples/aloemacs/main.aloe). The session
  has thirteen fields, the buffer has editor/path, and the nested map
  has `"save", "find", "kill", "b"` in that order.

The predecessor documents named by the spec remain authority for
preserved behavior. This spec supersedes their constructor inventories
and viewport ownership only as explicitly stated. Do not amend them.
Existing `buffer-collection.rkt`, `buffer-session.rkt`,
`prompt-commands-select-buffer.rkt`, `viewport-editor.rkt`,
`minibuffer-session.rkt`, and runner tests under `tests/aloemacs/` provide
checked fixtures, independent expectations, counted Fs doubles, and
scripted Term examples.

## Exact file scope

### May create or edit

- `examples/aloemacs/editor.aloe`: add `with-origin` and `frame-rows`;
  internal row helpers may be added. If the direct editor frame shares
  a helper, preserve all its accepted byte results and raw-state branches.
  Keep the eight editor fields and four `UndoFrame` fields unchanged.
- `examples/aloemacs/file.aloe`: buffer ID and lookup/allocation changes;
  the four window classes; the one session field and its reconstruction
  threading; view synchronization and retargeting; geometry, fit, frame,
  split methods, command cases, and the two nested bindings specified here.
  Keep the two existing loads and the relative order of existing classes.
  New internal helpers belong within the permitted application classes.
- `examples/aloemacs/main.aloe`: append startup buffer ID 0 and the
  specified initial configuration; retain every other starting value.
- Create `tests/aloemacs/windows-split.rkt` before product edits. It owns
  this slice's focused proof, including runs through the unchanged runner.
- Existing files under `tests/aloemacs/`: migrate affected buffer/session
  constructors and independent expected values; update exact class,
  field, method, command, map, and main inventories; replace newly bound
  `"2"` / `"3"` prefix-miss cases with positive chord coverage. Preserve
  substantive existing assertions and remaining consumed-miss proofs.

### Must leave untouched

- All other product modules, including `host/racket/aloemacs-run.rkt`,
  `host/racket/term.rkt`, other host files, and Fs/Term interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, global checkpoints,
  predecessor documents, and this series' design documents/checkpoints.
- Editor/undo field inventories, global keymap order/default, existing
  command meanings, the runner's arguments and `aloemacs-editor` binding,
  fit-then-frame order with the same dimensions, one write per iteration,
  and current-editor quit check.

Add no load, module, dependency, capability, language send, Text method,
List index, computed selector, Mirror, mutation, inheritance, delegation,
macro, or special form. No per-view editor, point, mark, history, ring,
path, page height, or stored rectangle; no mode/status row, buffer menu,
automatic split/delete, balance, weights, saved configuration, mouse,
scrollbar, highlighting, modes, completion, `M-x`, second prefix, Term
chord, or runner argument.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening the slice. If this slice
cannot fit one implementer conversation without compaction, report the
size problem and stop for review; do not split it or add a fourth slice.

## Slice requirements

### 1. Stable buffer identity

Append `id : Int` after the buffer's editor/path fields. Construction is
`(AloemacsBuffer new editor path id)`. Live IDs are nonnegative and
unique. Buffer names, paths, payload equality, collection position, and
host addresses are not identity. Equal editor/path payloads may have
different IDs; several views may share one ID.

`with-editor`, `with-path`, and successful `visited` / direct `visit`
preserve the current ID. `remove-current` preserves the ID when singleton
removal replaces its contents with fresh untitled defaults; removal from
a larger collection removes that ID and changes no survivor ID.

Keep the collection's ordered fields exactly `before`, `current-buffer`,
`after`. Add `fresh-id() -> Int`, one above the maximum live ID, computed
by folds over both sides and current. Both session `add-buffer` arities
take it before insertion. No counter or second collection is stored;
reuse of a removed ID is allowed after views have been retargeted.

Add `find-id(id : Int) -> (Option AloemacsBuffers)`: inspect current
first, then at most one forward cycle with countdown
`1 + before.len + after.len`. Match IDs and preserve logical order and
every buffer value; return `None` on a miss. Rendering may read the
temporary result but never install its focus. `find-name` keeps its
accepted current-first/forward policy, including duplicate names and
find-file reuse. Raw constructors do not add validation.

### 2. View/tree/configuration and startup

After `AloemacsBuffers`, before `AloemacsCommand`, declare these
non-generic classes in this dependency order, with exact ordered shapes:

```aloe
AloemacsView:
  (id Int)
  (buffer-id Int)
  (scroll-row Int)
  (scroll-col Int)
  (locked Bool)

AloemacsWindowTree:
  (Leaf (fields (view AloemacsView)))
  (Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree)))
  (Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree)))

AloemacsWindowRect:
  (x Int)
  (y Int)
  (columns Int)
  (rows Int)

AloemacsWindows:
  (tree AloemacsWindowTree)
  (selected Int)
  (columns Int)
  (rows Int)
```

These blocks specify inventories, not executable class declarations.
Use ordinary recursive constructors under `SPEC.md` §9. The tree is
nonempty and binary; repeated splits nest without flattening. View IDs
are nonnegative and unique within the live tree; origins are nonnegative.
Add tree `leaves() -> (List AloemacsView)` in depth-first top-before-bottom
and left-before-right order, and `find-view(id : Int) ->
(Option AloemacsView)`. Edits rebuild only the path to the affected leaf.
Rects are transient geometry; equality compares all four coordinates.

Append `windows : AloemacsWindows` after session `waiting-command`.
The complete fourteen-field order is:

```text
buffers, fs, echo, searching, query, origin, wrapped, failing,
kill-ring, pending, prompt, last-submission, waiting-command, windows
```

Retain all existing field types and computed current-buffer/editor/path/
text/point/quit sends. Search `origin : Position` keeps its existing
meaning. The configuration is the only window store. `selected` is a
view ID; configuration columns/rows remember the full terminal size from
fit. Frame never stores size. All other operations preserve it.

Startup appends buffer ID 0 and:

```aloe
(AloemacsWindows new
  (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f))
  0 0 0)
```

Retain main's cold empty Text and every existing default. `(0,0)` means
not fitted; do not guess a terminal size. At untyped sites retain lawful
`(if #t (Option None) (Option Some typed-value))` forms for absent path,
mark, pending, prompt, submission, and waiting command. An expected
constructor field type inside a method may supply `None`.

### 3. Reconstruction and existing buffer operations

The selected view's buffer ID must equal current's ID, and its stored
origin must mirror the live editor origin on every program-created
returned session. Unselected origins remain authoritative, including
views sharing current's buffer. Thread the configuration through every
session reconstruction. Echo/search/prefix/prompt/submission/slot-only
changes retain it exactly; editor changes mirror only the selected leaf's
origin. This includes `with-editor`, `with-search`, `with-kill-state`,
and their edit, motion, undo, quit, search, and fit callers. Direct save
and path-only changes preserve the complete configuration.

Add editor `with-origin(scroll-row : Int, scroll-col : Int) ->
AloemacsEditor`, replacing only its two origin fields. Preserve exact
Text, point, quit, history, mark, and remembered `text-rows`; do not fit,
clamp, focus/rebuild Text, or push undo. Valid origins are nonnegative.
The origin-handoff contract in spec §3.4 governs later view selection;
do not install other-window or delete entry methods in 000.

Integrate existing operations now, with their accepted session resets and
Fs behavior unchanged:

| Operation | Window result |
|---|---|
| Both add-buffer arities / new-file find-file | Preserve departing buffer and all unselected views. Retarget selected to fresh ID and origin `(0,0)`. |
| switch-buffer / selected-buffers / find-file reuse / select-buffer success | Retarget selected to resulting current ID and that buffer editor's existing origin, without borrowing another view's origin. Keep accepted selection resets even when the ID stays the same. |
| Successful visited / direct visit | Keep current ID and tree; selected origin becomes `(0,0)`. Other views of that ID retain origins and see replacement text. Preserve submission and accepted visit resets. |
| Refused visit / find-file refusal or name miss / save-as refusal | No window change; retain accepted Option, echo, and prompt outcomes. |
| Save-as success / with-current-path | Preserve all views and origins; update only current path under its existing ID. |
| Nonsingleton kill-buffer | Remove current ID with the existing successor-else-predecessor rule. Retarget every view of the killed ID to that chosen replacement ID and its editor origin. Other views stay exact. |
| Singleton kill-buffer | Keep ID, install fresh untitled editor/path defaults, and reset every view of that ID to `(0,0)`. |

For kill, capture the replacement origin once before traversing views.
Leave no dangling ID. A view already showing the replacement keeps its
own origin. Killing removes no view, performs no save, and changes no
lock, rectangle, selected view ID, tree shape, or remembered size.

Preserve the accepted kill/selection prompt, waiting-command, submission,
and ring rules. Direct buffer selections during a waiting prompt retain
the prompt and slot; Return acts on the then-current buffer, with no
stored old buffer/view target. Locked views obey these same operations.

### 4. Geometry and selected fit

For positive terminal dimensions, reserve the final row when `rows >= 2`:
`text-rows = rows - 1`; otherwise `text-rows = rows`. The root rectangle
is `(0,0,columns,text-rows)`. Below divides height; Right divides width.
For split extent `n >= 3`, allocate:

```text
available = n - 1
earlier   = (available + 1) / 2   [integer division]
later     = available - earlier
```

The divider occupies one cell; the earlier top/left side gets the
leftover. Bottom/right starts at parent position plus `earlier + 1`;
the other axis stays exact. Layout is recursive and unweighted, with
one cell on each axis the minimum visible rectangle. Splitting one leaf
changes no ancestor or sibling rectangle.

A 9-by-5 text rectangle split right yields `(0,0,4,5)` and `(5,0,4,5)`;
splitting the left below yields `(0,0,4,2)` and `(0,3,4,2)`, leaving
right exact. Visit order is left-top, left-bottom, right, regardless of
numeric IDs.

On external resize preserve tree, selection, and locks. If the tree
cannot give every leaf positive dimensions, compute its nominal layout
with `divider = min(1,n)`, `available = n-divider`, and the same division
for nonnegative extents. For that frame/fit use the selected buffer in
the whole text rectangle with the single-view composer and no dividers.
Do not delete or rewrite the tree. Growth restores its display. Window
commands use nominal rectangles, not the temporary full-screen fallback.

Session `ensure-visible(columns, rows)` keeps its signature/concrete
result. Remember the positive full terminal size, derive layout, fit
only current using the selected rectangle's dimensions, and mirror its
origin. Its remembered editor `text-rows` is that selected height for
page motion. In fallback use the full text rectangle. All unselected
views, including those sharing current, stay exact. Repeated fit at the
same size/point is idempotent. Normative frames follow fit with the same
dimensions. There is no runner arithmetic or new event.

### 5. Pure rows and complete composition

Add editor `frame-rows(columns : Int, rows : Int, scroll-row : Int,
scroll-col : Int) -> (List String)`. For positive width/height and
nonnegative origins return exactly `rows` strings. From `scroll-row`,
drop `scroll-col`, take `columns`, then apply existing `safe-cells` to
each line. Missing rows are `""`, including when the entire origin is
beyond EOF after a shared edit or visit. Do not pad, generate ANSI,
chase point, or clamp an inactive origin.

Use existing Text `focus-at` / `next-lines` and bounded visible-row
traversal. Failed focus at the explicit origin yields blank rows. Do
not materialize Text with `lines` / `to-string`, seek from line zero on
every frame, add a Text method, install a temporary focus/origin, or
construct an editor for an inactive view. Rendering preserves the entire
session, every buffer, exact Text focus, and all origins.

One-leaf session frame calls the existing full-screen editor frame once
and appends today's echo suffix. Preserve complete bytes, including
intermediate hide/show sequences and unpadded editor strings. One row
has no echo suffix or prompt cursor override. The too-small-tree
fallback uses this same composer.

Several visible leaves call `frame-rows`, never full editor frame per
view. Pad their rows on the right to view width and compose exactly:

```text
ESC[?25l ESC[2J ESC[H joined-text-rows
[ESC[rows;1H shown-echo-row, only when rows >= 2]
ESC[cursor-row;cursor-columnH ESC[?25h
```

The displayed separating spaces add no bytes. Text has exactly
`text-rows` full-width safe rows, joined by CRLF without trailing CRLF.
One clear and one hide/show pair surround the whole composition. Keep
the result one String with one selected/prompt cursor and one full-width
echo; add no per-view ANSI, echo, or status row.

Right dividers are `|`, Below dividers `-`; perpendicular meetings are
`+`, including T and cross junctions. A child divider reaching its
parent divider extends through that parent-divider cell. Compute these
from geometry, never punctuation in text. The mixed 9-by-5 example's
horizontal divider row starts `----+`, then the right view's four cells.

The selected cursor is one-based:

```text
row    = selected.y + point.line   - editor.scroll-row + 1
column = selected.x + point.column - editor.scroll-col + 1
```

With an active prompt and reserved echo row, final cursor is at terminal
`rows` and `prompt.screen-column(columns)` instead. Echo precedence stays
prompt, search, saved/failed/idle path or untitled. Clip to full terminal
width and apply safe cells; unused cells stay blank from the clear.
Frame never changes the stored token.

### 6. Splits, commands, keys, and echo

Append zero-payload `SplitBelow`, then `SplitRight`, after `SelectBuffer`.
Their exact names are `"split-below"` and `"split-right"`. Extend command
`name` and session `execute-command` constructor cases. Execution sends
zero-argument session `split-below()` / `split-right()`, ignores `key`,
and returns the receiver's concrete `(AloemacsSession H)`. Geometry comes
from remembered size; there is no Term/Fs query, editor key arm, or
command-owned execution method.

Refuse if no positive size is remembered, selected is locked, selected's
nominal rectangle has a zero axis, or its split direction has fewer than
three cells. Otherwise replace selected leaf with Below/Right. Both
children show its buffer ID and begin at the live editor's pre-split
origin, unlocked. Original ID remains selected on the earlier side;
later side takes one above the maximum live view ID. Store no ID counter.

After replacement perform one fit with the remembered size. Only the
original child's origin and shared editor origin/remembered height may
change in that fit; the new child retains the pre-split origin. Other
views, ancestors, siblings, and buffers stay exact. Preserve text, Text
focus, point, quit, history, mark, ring, all search fields, prompt,
submission, waiting command, and pending. No undo push, prompt action,
read/write, quit request, or new prefix occurs.

Both successful and refused direct splits retain stored echo while an
active prompt or search remains. Otherwise success stores `""` and
refusal stores `"failed"`. Refusal changes nothing else; with an active
prompt/search the complete session stays unchanged. Stored vocabulary
is still exactly `""`, `"saved"`, `"failed"`; painting may hide the token.

Append ordinary nested bindings `"2" -> SplitBelow`, then
`"3" -> SplitRight`. Exact nested order is:

```text
"save", "find", "kill", "b", "2", "3"
```

Nested default stays `None`; global command order, shared save value,
one prefix, and `Some SelfInsert` default stay unchanged. Plain
`2`, `3`, `0`, `o`, and `l` insert. Prefix `0`, `o`, and `l` remain
consumed misses in 000. Pending clears before bound chord execution;
a direct split retains a raw pending map. Quit/search/prompt/idle routing
keeps its current precedence. Prompts own input and ignore `ctrl-x`;
search printable input remains query text, and named `ctrl-x` exits
search before forwarding. Unknown idle command names remain misses.
Do not introduce a general direct-execution guard.

### 7. Fixture migration and focused proof

Write `tests/aloemacs/windows-split.rkt` first and observe the missing
behavior fail before product edits. Use checked driver/rackunit tests,
counted Fs doubles, and scripted Term; no TTY is required. Independently
construct expected buffers/configurations/sessions and complete frame
goldens rather than deriving them with the dispatcher or split under test.

Search every product/test `AloemacsBuffer new` and `AloemacsSession new`,
including independent expected reconstructions. Append IDs and consistent
configurations. A singleton uses selected view 0, its current buffer ID,
and that editor's existing origin, which need not be `(0,0)`. Valid
multi-buffer fixtures need distinct IDs, even with equal editor/path
payloads. Unless explicitly multi-view, initialize one leaf on current.
Update expected selected-origin mirrors and remembered fit dimensions.

Inspect buffer, keymap, minibuffer, prompt-command, echo, file, kill,
motion, safe-cells, search, undo, viewport, visited-unchanged, and runner
proofs; this is not an exhaustive migration list. Search again after
edits. Keep intentional old-arity negatives; migrate other negative
fixtures so they still fail for their original reason. Retain ownership,
effects, exact single-view byte assertions, and bounded duplicate-name
scan proofs. Use distinct IDs for equal-payload live buffers.

The focused file must prove all of spec §5.1, including:

1. Exact new types, ordered shapes, lawful recursive loading, fourteen
   session fields, ID allocation/preservation, bounded current-first
   ID lookup, and concrete host result types. Reject wrong arguments,
   receivers, and arities. Fresh checked file loads need no injected
   Fs/Term and cause no effects; main needs only Fs and initializes the
   specified tree.
2. Unchanged complete single-view frames for blank/narrow/safe rows,
   stored-origin scrolling, all idle status tokens, search, prompt, and
   one-row behavior. Preserve direct editor frames, old keys, and editor/
   undo shapes alongside the existing suite.
3. Both orientations at extent three and odd/even larger sizes;
   before-fit, one/two-cell, zero-axis, and constructed-lock refusals.
   Compare exact trees, IDs, nominal rectangles, selection, origins,
   permitted fit changes, and zero Fs calls.
4. Repeated/mixed nested splits: unchanged outside geometry, depth-first
   visit order distinct from numeric IDs, complete padded ANSI goldens,
   one clear/hide/show pair, dividers and T/cross junctions, punctuation
   independence, full-width echo, and translated selected/prompt cursor.
5. Pre-split origin on both children before fit, selected-only post-fit
   change, selected height for page motion, shared edits and undo, and
   one buffer point/history/mark. Pure explicit-origin rows have the
   exact count and safe clipping, with blank inactive origins beyond EOF
   after shared edits or visit. Frame preserves all state and Text focus.
6. Every §3.4 existing operation with constructed multi-view fixtures,
   shared IDs, and locked views: preserve zipper order and rich editor
   payloads, origins, locks, prompt/slot/submission, accepted resets, and
   exact I/O targets. Cover singleton kill, no dangling ID, and a
   survivor already displaying the replacement at another origin.
7. Direct/chord split equivalence through redraw, plain insertion and
   consumed prefix misses, quit/search/prompt routing, and direct raw
   pending preservation. For each initial echo token, test successful
   and refused direct splits with prompt, search, and neither: active
   row retains the token; otherwise use success `""` / refusal `"failed"`.
   Assert hidden stored echo and complete row/cursor results. A key path
   that exits search uses the subsequent applicable echo rule.
8. The unchanged runner splits, edits, saves, and quits with fit before
   frame and one frame write per drawn iteration. Resize preserves tree,
   unselected origins/locks, prefix/prompt/slot, and selected-only fit;
   shrink invokes the specified fallback and growth restores dividers.

Use constructed trees/configurations for unselected, locked, and
multi-buffer cases in 000. Do not install later commands to make these
tests reachable. 000 must pass independently of 001 and 002.

## Verification and completion

From `/home/dharmatech/journal/2026-09-02-aloe-racket`, run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-split.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test invocation includes `TMPDIR=/tmp` and `-y`. No timing
gate, benchmark, physical TTY hand check, or broader suite is required.
Do not commit `compiled/`. The optional existing launch is
`racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt` edit run the
named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe` before
launching. `.aloe` edits need no bytecode rebuild.

Review source as well as passing tests. Confirm one configuration is
the whole window store, each buffer owns one editor, every reconstruction
threads IDs/configuration, inactive rendering never installs origin or
Text focus, and command execution remains session constructor cases.
Rule out List indexing, full Text rendering, temporary editors, and
per-view full-screen frames. Confirm runner/Term/language/library files
are untouched. Equality tests alone do not prove these structural rules.

Complete when the focused proof and full aloemacs suite pass, diff
whitespace is clean, all required migrations retain their substantive
proofs, exact one-view frames remain, both splits obey shared ownership/
origin/geometry/echo rules, existing buffer operations preserve valid
views, and source review confirms the boundaries. Report the initial
missing-behavior failure, final results, and files changed.

Then stop. Do not implement, write, or start **aloemacs-windows 001** or
002. Human review of 000 precedes the manager issuing the next checkpoint.
