# aloemacs-windows 003 — Layout, rendering, and fit

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Give constructed multi-view sessions their final geometry, pure rendering,
and selected-view fit. Derive nominal rectangles from the binary tree,
render each view from its own stored origin, compose one complete frame,
and fall back to the selected buffer at full screen when a terminal shrink
makes the tree impossible to display. Preserve complete one-view bytes.

This is the **layout, rendering, and fit** part of accepted spec §4,
numbered 003 after the permitted state separation. Buffer identity and
complete state synchronization already exist. Startup and current keys
still produce one view; focused tests construct split trees directly.

Stop after the focused proof and full suite pass. Add no window command,
key, view-entry operation, field, or constructor migration. Both splits
follow only after human review of this result.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 003**, filed as
  `checkpoints/003-layout-and-rendering.md`. This is a local editor
  checkpoint, not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute through `call`. Use ordinary recursive
  constructor cases and lawful typed absent Options.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, staging, file
  boundaries, and non-goals. §§3.1–3.4 give the existing buffer/view types
  and state invariants; §3.7 explains the issued number mapping. **All of
  §§4.1–4.5** governs this slice. §8 retains echo vocabulary and input
  precedence; it does not authorize window commands here. §9's **layout,
  rendering, and fit** verification and individual-checkpoint completion
  rules apply. Predecessor specs named in §1 govern retained one-view
  behavior, including viewport fit, echo, prompt, and exact frame bytes.
- [000-buffer-identity.md](000-buffer-identity.md),
  [001-state-foundation.md](001-state-foundation.md), and
  [002-synchronization-completion.md](002-synchronization-completion.md)
  are implemented in the current checkout. Preserve their ownership,
  synchronization, effects, and substantive proofs. The historical
  [000-split.md](000-split.md) remains returned, unimplemented, and
  unauthorized for resumption.
- Start from [editor.aloe](../../../../../../examples/aloemacs/editor.aloe)
  and [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  `AloemacsEditor.frame` already uses safe clipped rows and stored origin;
  `with-origin` is pure. Tree lookup, selected-only mirroring, all-view
  killed-buffer retargeting, and positive full-size bookkeeping exist.
  Rectangles currently have fields without layout. Session `frame` still
  uses the one-view composer, and `ensure-visible` still fits the full
  text rectangle. This slice replaces that temporary multi-view boundary.

The [README](../README.md) records the mapping: 003 is layout; later
unissued parts are both splits, delete and other-window, then window lock.
Those later parts are neither prerequisites nor this assignment.

## Exact file scope

### May create or edit

- `examples/aloemacs/editor.aloe`: add `AloemacsEditor.frame-rows` and
  internal row helpers. The existing direct `frame` may share them only
  while retaining every exact byte result and raw-state branch. Keep all
  eight editor fields, all four `UndoFrame` fields, and existing editor
  transitions/signatures unchanged.
- `examples/aloemacs/file.aloe`: implement nominal layout and pure
  composition helpers within `AloemacsWindowTree`, `AloemacsWindowRect`,
  `AloemacsWindows`, and `AloemacsSession`; update session `frame` and
  `ensure-visible`. Reuse the existing state helpers. Keep class order,
  the two loads, all fields/constructors, buffer operations, command
  execution, keymaps, file effects, and input precedence unchanged.
  Helper names are implementation choices, not additional product design.
  No new class or module is needed.
- Create `tests/aloemacs/windows-layout-and-rendering.rkt` before product
  edits. It owns all of §4.5's focused proof, using the existing checked
  driver, `rackunit`, Fs doubles, and scripted Term doubles.
- `tests/aloemacs/windows-state.rkt`: adjust only the temporary
  full-rectangle fit test's name/comments and independent expected fit
  payloads to the final selected-rectangle/fallback rules. Preserve its
  complete-session comparisons, idempotence, size preservation, inactive
  origins/locks, frame purity, one-view golden, and effect assertions.
  For its current five-leaf fixture, terminal size `(80,24)` gives selected
  view 55 rectangle `(41,6,39,5)`: remembered editor `text-rows` becomes
  5, replacing 23; origin remains `(2,3)`. Its `(1,2)`, `(2,1)`, and
  `(12,4)` sizes trigger fallback and retain their existing fit results.

Current constructor/inventory searches show no other existing test needs
an adjustment. New geometry and row-helper signatures belong in the new
focused proof; existing inventories permit internal helpers.

### Must leave untouched

- `examples/aloemacs/main.aloe`, startup defaults, and every other
  product module. No buffer/session constructor migration remains.
- Every other existing test, including `windows-buffer-identity.rkt`,
  `windows-state-foundation.rkt`, direct-editor/one-view frame goldens,
  and runner proofs. Do not create a later command proof early.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, Fs/Term
  interfaces, `aloe/`, and `lib/`, including Text and List. Add no module,
  load, dependency, capability, or runner entry point.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  and this series' design/checkpoint documents.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening it. If finishing would
require compaction, report the size problem and stop for review; do not
split the assignment or start its successor yourself.

## Slice requirements

### 1. Derive binary and nominal geometry

For positive terminal dimensions, use `text-rows = rows - 1` when
`rows >= 2`, otherwise `rows`. The root text rectangle is
`(0,0,columns,text-rows)`. A Leaf receives its rectangle. Below divides
height; Right divides width. For every nonnegative extent `n`, compute:

```text
divider = min(1,n)
available = n - divider
earlier = (available + 1) / 2     [integer division]
later = available - earlier
```

At `n >= 3` this gives one divider cell and two positive children, with
the leftover cell assigned to top/left. Below preserves x/width and puts
bottom y at `y + earlier + divider`. Right preserves y/height and puts
right x at `x + earlier + divider`. Each divider spans the parent's
other axis. Follow the exact tree recursively; do not flatten, balance,
weight, reorder, or select by numeric ID. Rectangles are transient,
relative to the text rectangle, and never stored in views.

Prove the spec's 9-by-5 example: Right yields `(0,0,4,5)` and
`(5,0,4,5)`; subdividing left Below yields `(0,0,4,2)` and `(0,3,4,2)`
while right remains exact. Use raw tree construction, not a split command.

Recompute nominal geometry from each supplied size. If **any** leaf has
zero width or height, use the whole text rectangle for selected-buffer
fit and the one-view composer for that frame; draw no dividers. Preserve
tree, selection, locks, and inactive origins. Growth restores tree
display. The fallback does not replace nominal rectangles with display
rectangles or save another configuration. Lock bits do not prevent resize.
Command geometry/refusal/lock guards belong to later parts.

### 2. Render pure rows from an explicit origin

Add exactly the editor interface from §4.2:

```text
frame-rows(columns : Int, rows : Int, scroll-row : Int, scroll-col : Int)
  -> (List String)
```

For positive width/height and nonnegative origins, return exactly `rows`
strings starting at `scroll-row`. For each source line, drop `scroll-col`,
take `columns`, then apply existing `safe-cells`. Missing source rows
are empty strings, including an origin wholly beyond EOF. This helper
does not chase point, clamp origin, horizontally pad, or emit ANSI.

Use the existing Text zipper's `focus-at` and bounded `next-lines` walk;
failed origin focus gives blank rows. Temporary immutable Text values
remain local. Do not materialize `Text.lines`/`Text.to-string`, seek from
line zero on every frame, add a Text method, construct another editor for
a view, or install any inactive origin/focused Text into a buffer.

Resolve each view's buffer by stable `buffer-id` using `find-id`; reading
its temporary focused collection must never install that zipper focus.
Views of one buffer read its one shared editor with separate explicit
origins. Multi-view rendering calls `frame-rows`, never full-screen editor
`frame` once per view. Pad each returned row on the right to its view's
width only in session composition. Keep direct editor frames unpadded
and preserve their existing raw-state behavior.

### 3. Fit only the selected view

Keep session `ensure-visible(columns, rows) -> (AloemacsSession H)`.
For positive full terminal dimensions, remember those dimensions in
`windows`, derive nominal geometry, and fit only current editor at the
selected rectangle's width/height through its existing minimal fit.
Use full text dimensions instead when any leaf is nonpositive.

Mirror the fitted origin onto selected only. The only permitted state
changes are current editor's origin and remembered `text-rows`, selected
origin mirror, and full remembered size. Preserve exact Text focus, point,
history, mark, quit, buffer IDs/paths/order, all other editors and views,
locks, shape, selection, and all echo/search/prefix/prompt/slot/ring fields.
Page Up/Down consequently use selected rectangle height, or fallback
height. Repeated fit at the same size/point is idempotent.

Frame is pure: it records neither dimensions nor origins and performs no
fit. Its normative caller fits first at the same positive size, especially
after motion. Non-fit operations retain remembered dimensions. This slice
adds no post-split fit or view entry; those operations do not exist yet.

### 4. Compose one complete frame

For a single leaf or fallback, retain today's **complete** session String:
one editor `frame(columns,text-rows)` followed by the existing echo suffix
when `rows >= 2`, including its intermediate cursor sequences. At one
row, draw no echo suffix and use the text cursor even with a prompt.

For several positive leaves, compose exactly:

```text
ESC[?25l ESC[2J ESC[H joined-text-rows
[ESC[rows;1H shown-echo-row, only when rows >= 2]
ESC[cursor-row;cursor-columnH ESC[?25h
```

Spaces above separate pieces; they add no bytes. The text body has
exactly `text-rows` rows of exactly `columns` safe cells, joined by CRLF
without a trailing CRLF. Emit one clear and one hide/show pair for the
whole multi-view frame, with no per-view cursor, clear, echo, or status.
Return one String for the existing single Term write.

Right dividers use `|`; Below dividers use `-`. Geometry determines `+`
at perpendicular meetings, including T junctions: extend a child divider
through the one parent-divider cell it reaches. Aligned child dividers
on both sides make a cross. Buffer punctuation never creates a junction.
In the 9-by-5 example, the horizontal divider row is `----+` followed by
the right view's four cells; the other rows contain `|` at x=4.

Selected text cursor coordinates are one-based:

```text
cursor-row = selected.y + point.line - editor.scroll-row + 1
cursor-column = selected.x + point.column - editor.scroll-col + 1
```

Only selected supplies a text cursor, including shared-buffer views.
When a prompt is active and an echo row is reserved, final cursor instead
uses terminal `rows` and `prompt.screen-column(columns)`. Ending the
prompt restores the translated text cursor.

Keep echo selection exactly: prompt first, then active search, then
`saved:` / `failed:` / idle path or `untitled`. Clip to full terminal
width and apply safe cells; unused echo cells are blank from the clear.
Echo is not restricted to selected-view width. Frame never changes the
stored token, whose vocabulary remains `""`, `"saved"`, and `"failed"`.

### 5. Focused proof, written first

Write `tests/aloemacs/windows-layout-and-rendering.rkt` and observe the
missing behavior fail before product edits. Construct expected rectangles,
sessions, editors, rows, and **complete ANSI Strings** independently of
layout/composition/fit helpers under test. Use direct tree/configuration
constructors; do not add a command or session-selection API for fixtures.

Complete all of spec §4.5:

1. Minimum extent three, odd/even larger allocations, both orientations,
   mixed/deep nesting, exact sibling rectangles, visit order distinct from
   numeric IDs, nominal zero axes, and global fallback when any leaf fails.
2. Checked `frame-rows` signature and wrong receiver/type/arity negatives;
   exact row counts, vertical/horizontal clipping, safe controls, trailing
   blanks, and beyond-EOF origins. Include inactive origins beyond EOF
   after shared edit or visit. Snapshot the complete session, every buffer,
   exact Text focus, and all origins before/after paint.
3. Complete multi-view Strings with padded rows, both dividers, T/cross
   junctions, punctuation independence, full-width clipped/safe echo, and
   exactly one clear/hide/show pair. Independently construct different
   selected leaves for cursor offsets. Cover all idle tokens, active
   search, prompt priority/cursor, prompt end, and one-row rules. Existing
   direct-editor and one-view goldens remain byte-for-byte unchanged.
4. Minimal selected-only fit of both axes, idempotence, selected-height
   page motion, full-size bookkeeping, and purity of frame at a supplied
   size different from the remembered size. Use shared buffers, distinct
   nonzero inactive origins, rich editor/session state, and mixed locks;
   compare every preserved payload rather than only the fitted selectors.
5. A constructed multi-view session driven through the checked driver
   with scripted Term sizes/keys: explicit fit, frame, one Term write,
   then key handling. Shrink triggers the single-view fallback; growth
   restores dividers without rewriting tree/selection/locks/inactive
   origins. Preserve prefix/prompt/slot and exact Fs counts. Use existing
   host doubles without editing the actual runner or adding an entry point
   for a supplied session. Existing runner tests retain their one-view
   fit/write/read proof; actual multi-view runner scenarios await split keys.
6. Checked file load without injected Fs/Term, unchanged fields/classes,
   commands/maps/current keys, and absence of split/delete/other/lock or
   view-entry sends. Assert rendering/fit add no Fs effect.

Retain the synchronization proof's state guarantees while making its
scoped fit expectation adjustment. Source review must prove bounded
rendering and single ownership; result equality alone cannot prove them.

## Explicit non-goals

No SplitBelow/SplitRight/DeleteWindow/OtherWindow/ToggleWindowLock
constructor, execution case, session send, or key; fresh-view allocation,
view entry, lock guard, command rectangle comparison, or command echo rule.
No new field/class/store, constructor migration, automatic split/delete,
balance/resize command, mode line, buffer menu, per-view editor/point/mark/
history/ring, saved configuration, weight, face, highlight, or paint cache.

No runner/Term/Fs change, Text method, List index, kernel message, Mirror,
mutation, inheritance, delegation, macro, implicit Int/Float coercion,
new special form, next exploration, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-layout-and-rendering.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes all completed identity/state and predecessor proofs. Do not
commit `compiled/`. No wider suite, benchmark, timing gate, or physical
TTY hand check is required. Optional launch remains
`racket host/racket/aloemacs-run.rkt [path]`; after a `.rkt` edit, run
the named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`
first. Launchers load existing bytecode; `.aloe` edits need no rebuild.

Review source and results: nominal geometry derives from the exact tree;
configuration is the only window store; each buffer owns one editor;
rendering uses bounded Text walks and never constructs an inactive editor,
installs an inactive origin, or changes zipper focus; fit mirrors selected
only and remembers full dimensions; fallback preserves the tree; old
single-view composition and runner remain exact. Confirm only the four
permitted files changed, with the earlier proof edited only as scoped.

Complete when all of §4 is implemented and independently proved, focused
and full suites pass, and source/whitespace review confirms the boundary.
Report the initial missing-behavior failure, final verification results,
changed files, and structural review. Stop when green for human review.
Do not implement or issue both splits or any later checkpoint.
