# aloemacs windows specification

**Status: Accepted revised checkpoint partition.** The user authorized
the checkpoint manager to proceed if this revision was ready. The manager
found it ready; behavior, interfaces, and partition are accepted. The
checkpoint-count cap has been relaxed by explicit user approval. This
revision changes packaging and staging, not the accepted product.

This file is the complete design input for the **aloemacs-windows**
checkpoint manager and implementers. They do not need the charter or
this conversation. This accepted file is their design authority. This is
application design;
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law and
[`docs/workflow.md`](../../../../workflow.md) governs the review boundaries.

A window is a view of a buffer. The session holds a binary tree of views
and selects one leaf. `C-x 2` splits that leaf below, `C-x 3` splits it to
the right, `C-x 0` deletes it, `C-x o` selects the next leaf, and `C-x l`
toggles its lock. Buffers own editors; views share those editors and retain
separate display origins. Other commands keep the tree where the user put
it. The echo and prompt remain one full-width row below the tree.

## 1. Series, predecessors, and authority

The series identity is **aloemacs-windows**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code stays in
`examples/aloemacs/`; tests stay in `tests/aloemacs/`. This folder holds
the specification and later checkpoint documents, never product code.

The intended partition is below. Its order is fixed; its count is not
a maximum. The window-state part may be separated further under §3.7
if it still cannot fit one implementer conversation. The numbered paths
below apply when that part fits as one checkpoint:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-windows 000** | `checkpoints/000-buffer-identity.md` | Buffer identity (§3.1, §3.5): IDs, allocation, lookup, buffer constructor migration. Session remains thirteen fields; fit/frame/keys stay exact. |
| **aloemacs-windows 001** | `checkpoints/001-window-state.md` | Window state and synchronization (§3.2–§3.4, §3.6): types, session field/migration, origin mirroring, existing-operation retargeting. Normal sessions still have one view; constructed trees prove state without multi-view painting. |
| **aloemacs-windows 002** | `checkpoints/002-layout-and-rendering.md` | Layout, rendering, and fit (§4): nominal geometry, explicit-origin rows, full composition, selected-only fit, and resize fallback. Constructed trees supply multiple views; no window command exists yet. |
| **aloemacs-windows 003** | `checkpoints/003-split.md` | Both splits (§5): sends, constructors, keys, geometry/refusals, shared ownership, and echo rules. Earlier migrations and rendering are prerequisites. |
| **aloemacs-windows 004** | `checkpoints/004-delete-and-other.md` | Delete and other-window (§6): sends/keys, origin handoff, wrapping, sibling promotion, resets, and constructed-lock guards. |
| **aloemacs-windows 005** | `checkpoints/005-lock.md` | Window lock (§7): toggle and key, exact-bit-only change, and user-reachable protection using existing lock bits and geometry. |

The returned `checkpoints/000-split.md` was not implemented. It stays
historical, unedited, and unauthorized for resumption. **Replacement
000 is `checkpoints/000-buffer-identity.md`**, not a revision of that
omnibus body. This spec names the replacement; the manager creates it
only after human acceptance of this revision. No later number has been
issued or implemented. [scope-review.md](scope-review.md) records the
size finding as background; it is not the design authority.

Numbers are three digits, start at 000, and are never renumbered once
issued or implemented. The approved replacement of returned 000 is
the explicit exception above. Slugs are lowercase words separated by
hyphens. A further window-state separation takes the next unissued
numbers before layout; later unissued parts then take successive
numbers in the same order. Section references, part names, and focused
test paths below remain stable even if those later numbers change.
The manager records any such assignment in the README before issuing
the affected checkpoint; it does not create placeholder checkpoints.

After human acceptance, the manager writes **replacement 000 only**,
then stops. Human review of each implementation precedes issuing its
successor. Each implementer writes tests first, implements only the
approved slice, runs verification, and stops when green. Do not combine
the ordered parts or issue them as a batch. Further window-state
separation must fit one conversation per slice, leave the full suite
green at every stop, and add no behavior. There is no maximum count.
Report any size problem that cannot be resolved within this staging
contract for design review.

Layers 1–16 in the [parent map](../README.md) are implemented. Required
seams are the stored viewport origin, echo/text-row allocation, command
values and prefix consumption, nonempty buffer zipper, active prompt,
and completed find-file/save-as/select-buffer commands. No runner change
is a prerequisite.

Authority for preserved behavior is:

- [`../README.md`](../README.md) and
  [`../explorations.md`](../explorations.md): layer order and Band 3 item 9.
  The mode line remains the following exploration.
- [`../viewport/spec.md`](../viewport/spec.md): minimal origin fit and
  bounded rendering from focused Text.
- [`../echo/spec.md`](../echo/spec.md): the full-width last row, its three
  stored tokens, and the one-row fallback.
- [`../keymap/spec.md`](../keymap/spec.md): session `execute-command`,
  the one `C-x` prefix, clearing pending before execution, consumed misses.
- [`../buffer/spec.md`](../buffer/spec.md): the nonempty zipper, insertion,
  cycling, removal, current-buffer access, and direct visit replacement.
- [`../minibuffer/spec.md`](../minibuffer/spec.md): prompt ownership,
  input precedence, safe/clipped echo composition, and prompt cursor.
- [`../prompt-commands/spec.md`](../prompt-commands/spec.md): Return/Escape,
  exact-name selection and reuse, find-file addition, and save-as binding.
- [`file.aloe`](../../../../../examples/aloemacs/file.aloe),
  [`editor.aloe`](../../../../../examples/aloemacs/editor.aloe), and
  [`main.aloe`](../../../../../examples/aloemacs/main.aloe): starting code.
- [`term.rkt`](../../../../../host/racket/term.rkt): printable keys already
  arrive as one-character strings. This series adds no Term chord.
- `legmacs/windows.lg` and the window section of `legmacs/render.lg` in
  `/home/dharmatech/src/legmacs`: catalogs for a pure tree, view lookup,
  layout, and killed-buffer retargeting. Do not port their weights,
  multi-child splits, atoms, per-view point, modes, or renderer.
- [`SPEC.md`](../../../../../SPEC.md) §9: recursive constructor classes
  and lawful typed absent Options.

For existing commands in a one-view session, predecessor behavior wins
for keys, files, selection resets, echo, search, prompt, and exact frame
bytes. This spec governs the new window commands, including §8's echo
preservation rule when they leave an active prompt or search in place.
This spec supersedes their old buffer/session constructor inventories, their
single-viewport ownership restriction, and their multi-view layout
descriptions only as specified below. Buffer IDs extend the buffer value;
names still have their accepted matching policy. Do not amend predecessor
documents or language law to update their old inventories.

## 2. Product, host, and file boundary

The implementation is checked Aloe. Racket tests use the existing checked
driver, `rackunit`, counted Fs doubles, and scripted Term doubles. No
physical TTY, dependency, host capability, library change, or new module
is required. Keep the two existing loads in `file.aloe`. Put the new
non-generic application classes there after `AloemacsBuffers` and before
`AloemacsCommand`, in the dependency order in §3. Keep the existing class
declarations in their relative order. Internal helper methods may be
added within the permitted classes; no helper needs a new language send.

| Part (intended number) | Product files it may edit | Focused tests to add |
|---|---|---|
| Buffer identity (000) | `examples/aloemacs/file.aloe`, `examples/aloemacs/main.aloe` | `tests/aloemacs/windows-buffer-identity.rkt` |
| Window state and synchronization (001) | `examples/aloemacs/editor.aloe`, `examples/aloemacs/file.aloe`, `examples/aloemacs/main.aloe` | `tests/aloemacs/windows-state.rkt` |
| Layout, rendering, and fit (002) | `examples/aloemacs/editor.aloe`, `examples/aloemacs/file.aloe` | `tests/aloemacs/windows-layout-and-rendering.rkt` |
| Both splits (003) | `examples/aloemacs/file.aloe` | `tests/aloemacs/windows-split.rkt` |
| Delete and other-window (004) | `examples/aloemacs/file.aloe` | `tests/aloemacs/windows-delete-and-other.rkt` |
| Window lock (005) | `examples/aloemacs/file.aloe` | `tests/aloemacs/windows-lock.rkt` |

Buffer identity migrates affected buffer constructors, independent
expectations, and buffer inventories in existing `tests/aloemacs/*.rkt`;
it does not migrate session arity or edit `editor.aloe`. Window state
migrates session constructors, independent expectations, and new
type/method/field inventories there; its only editor change is
`with-origin`. Layout may update affected editor/session method
inventories and remembered-fit expectations there, preserving complete
single-view goldens. It does not edit startup or either constructor
shape. Command parts may update command/map inventories and newly bound
prefix-miss examples in existing tests, retaining their substantive
assertions. Earlier focused tests may receive only matching fixture or
inventory adjustments; do not weaken their behavioral proofs. A further
state separation follows §3.7's narrower scopes and focused paths.

No slice edits a later part's focused test or creates it early. Each
checkpoint names its exact subset of the permitted existing test files;
discover it by the constructor/inventory searches in §§3.5–3.6 rather
than granting blanket unrelated test edits. No slice leaves a migration
or existing regression failure for a successor to fix.

Leave `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, host
capabilities, libraries, language implementation, `SPEC.md`,
`CHECKPOINTS.md`, predecessor documents, and the global checkpoint spine
untouched. `AloemacsEditor` keeps its eight fields; `UndoFrame` keeps its
four. The runner retains its arguments, `aloemacs-editor` binding,
fit-then-frame order with the same queried dimensions, one `term write`,
and current-editor quit check. Window commands do no file I/O.

Explicit non-goals are a mode line or per-view status row, buffer menu,
second editor/point/mark/history/ring per view, `delete-other-windows`,
balance/enlarge/shrink, saved configurations, automatic splits/deletes,
pinning a buffer with lock, mouse, dragging, weights, scrollbars, faces,
highlighting, modes, folding, completion, `M-x`, another prefix, a Term
method/chord, or runner argument. No Text method, List index, kernel
message, Mirror, mutation, inheritance, delegation, macro, or new special
form belongs here. Evaluation is send. Function objects execute only
through `call`. Do not start the next exploration or Boids.

## 3. Buffer identity, then window state and synchronization

§3.1 and §3.5 belong to buffer identity (replacement 000). §3.2–§3.4
and §3.6 belong to the following window-state part; §3.7 governs any
further separation of that part. The final interfaces below are closed.

### 3.1 Stable buffer identity

Introduced and fully proved in buffer identity (000). No window class,
session field, geometry, renderer helper, or command belongs to 000.

Append `id : Int` to `AloemacsBuffer`, leaving its existing fields first:

```aloe
(editor AloemacsEditor)
(path (Option Path))
(id Int)
```

Construction is `(AloemacsBuffer new editor path id)`. The generated `id`
selector is the identity used by a view. IDs are nonnegative and unique
among live buffers in a session. They are not a name, path, list offset,
editor equality, or host object address. Two buffers with identical
editor/path payloads still have different IDs. Several views may name
the same ID, and consequently read the same buffer value.

Buffer `with-editor` and `with-path` preserve `id`. Successful direct
`visited`/`visit` replaces the editor and path under the current ID.
Collection `remove-current` preserves the ID when it replaces a singleton
with a fresh untitled buffer; removing from a larger collection removes
that ID. No other surviving buffer changes ID.

Startup uses ID 0. Add collection `fresh-id() -> Int`: one more than the
largest live ID, computed by folds over before/after and current. Both
session `add-buffer` arities use it before `insert-after`. No counter or
second collection is stored. Reuse of a removed ID in a later addition
is permitted: killing has already retargeted every view of the removed
buffer. IDs identify live values within one immutable session lineage,
not durable external handles or cross-session identities.

Add collection `find-id(id : Int) -> (Option AloemacsBuffers)`. Like
`find-name`, scan current first, then at most one forward cycle with a
countdown of `1 + before.len + after.len`. Compare integer IDs and return
the matching focused collection; a miss returns `None`. A hit preserves
logical order and every buffer value. Rendering may inspect this temporary
result's current buffer; it never installs its focus. Window selection
installs it to focus a buffer without reordering the zipper.

The collection retains exactly `before`, `current-buffer`, `after`, in
that order. Raw constructors are not validators; valid multi-buffer
fixtures must supply distinct IDs. `with-current-buffer` remains the
ordinary replacement helper; session replacements preserve the current
ID. Existing `find-name` still matches derived names current-first and
forward, including duplicate paths and untitled names. Stable identity
does not change find-file's name-based reuse policy.

### 3.2 View, tree, rectangle, and configuration

Introduced in window state, after buffer identity is reviewed. This
part adds the lock bit with the view type; the public toggle is last.

Declare these four classes in this order, after `AloemacsBuffers`:

**`AloemacsView`**, with exactly these ordered fields:

```aloe
(id Int)
(buffer-id Int)
(scroll-row Int)
(scroll-col Int)
(locked Bool)
```

Construction is `(AloemacsView new id buffer-id scroll-row scroll-col locked)`.
The first ID identifies the leaf; `buffer-id` identifies its buffer.
View IDs are nonnegative and unique within a live tree. Origins are
zero-based and nonnegative. A view contains no editor, text, path, point,
mark, history, ring, remembered page height, or stored rectangle.

**`AloemacsWindowTree`**, with these ordered constructors:

```aloe
(Leaf (fields (view AloemacsView)))
(Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree)))
(Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree)))
```

The recursive class is lawful under `SPEC.md` §9. Each split has exactly
two children. Repeated splits nest; they do not flatten into several
siblings. The tree is always nonempty. Add pure `leaves() ->
(List AloemacsView)` in depth-first top-before-bottom / left-before-right
order, and `find-view(id : Int) -> (Option AloemacsView)`. Tree edits use
ordinary constructor cases, replacing only the path to the affected leaf.
Internal replacement/layout helpers are application methods, not List
indices or computed selectors.

**`AloemacsWindowRect`**, with exactly these ordered fields:

```aloe
(x Int)
(y Int)
(columns Int)
(rows Int)
```

These are transient zero-based geometry values, relative to the text
rectangle. Normal view rectangles have positive width/height. Equality
for lock checks compares all four integer coordinates, including the
top-left position; moving a locked rectangle counts as changing it.
Rectangles are derived from the tree and size, never stored in views.

**`AloemacsWindows`**, with exactly these ordered fields:

```aloe
(tree AloemacsWindowTree)
(selected Int)
(columns Int)
(rows Int)
```

Construction is `(AloemacsWindows new tree selected columns rows)`.
`selected` is a view ID, not an index. `columns` and `rows` remember the
last full terminal size supplied to session `ensure-visible`. This lets a
zero-argument split use known geometry without a Term send or extra
session size fields. Startup size is `(0,0)`, meaning not yet fitted.
It is not a guessed terminal size. Split before the first positive fit
refuses, with its echo token determined by §8. Frame is pure and never
remembers size.

Window state introduces positive-size bookkeeping now: session fit
stores full terminal dimensions in this configuration, while retaining
the predecessor's full-text-rectangle editor fit and exact composer.
Selected-rectangle geometry, fit, and multi-view composition begin only
in the following layout part (§4). Normal sessions cannot split yet.
Constructed multi-view state fixtures may retain any valid remembered
size but do not claim selected-rectangle fit/frame behavior at this stage.

View 0 initially shows buffer 0, origin `(0,0)`, unlocked. The initial
configuration is:

```aloe
(AloemacsWindows new
  (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f))
  0 0 0)
```

On successful split, the fresh view ID is one more than the largest ID
in the existing tree. The original leaf keeps its ID. As with buffer IDs,
reuse after deletion is permitted; no deleted leaf remains referenced
by the returned configuration. No next-ID counter is needed.

### 3.3 The one new session field

Append **`windows : AloemacsWindows`** after `waiting-command` in window
state. Buffer identity leaves the predecessor's thirteen fields exact.
The complete ordered fields after the state migration are:

```aloe
(buffers AloemacsBuffers)
(fs (Fs H))
(echo String)
(searching Bool)
(query String)
(origin Position)
(wrapped Bool)
(failing Bool)
(kill-ring (List String))
(pending (Option (AloemacsKeymap AloemacsBinding)))
(prompt (Option AloemacsPrompt))
(last-submission (Option String))
(waiting-command (Option AloemacsCommand))
(windows AloemacsWindows)
```

There are 14 fields. This is the only new session field in the series;
layout and all command parts add no fields. `windows` contains the whole
configuration, including selection and remembered dimensions. The search `origin` is
still its accepted saved Position; it is not a window origin.

Preserve the computed session `current-buffer`, `editor`, `path`, `text`,
`point`, and `quit` sends. The selected view's `buffer-id` equals current's
ID. Its stored origin mirrors the current editor's origin on every
program-created returned session. Unselected origins are authoritative
for those views even when another view shares their buffer.

All reconstructions thread the configuration. Echo/search/prefix/prompt/
submission/slot-only reconstructions preserve it exactly. Current-editor
rebuilds also replace only the selected leaf's stored origin with the
returned editor's origin. This includes `with-editor`, `with-search`,
`with-kill-state`, and therefore edit, motion, undo, quit, search, and fit.
They preserve every unselected view, selection, locks, tree shape, and
remembered dimensions. Direct save preserves the entire configuration.
Changing only the current path preserves it exactly.

Buffer identity appends ID 0 to `main.aloe`'s buffer constructor. Window
state later appends the §3.2 initial configuration to its session
constructor. Each migration retains the existing
cold empty Text and every existing default. At untyped sites retain the
lawful `(if #t (Option None) (Option Some typed-value))` forms for absent
path, mark, pending, prompt, submission, and waiting command. No new
Option setter, checker change, or reflective construction is permitted.
Inside methods, an expected constructor field type may supply `None`.

### 3.4 Origin handoff and existing buffer operations

Add editor `with-origin(scroll-row : Int, scroll-col : Int) ->
AloemacsEditor`. Replace only those two fields. Preserve the exact Text
value, point, quit, history, mark, and remembered `text-rows`. It does not
fit, clamp point, focus/rebuild Text, or push an undo frame. Valid view
origins satisfy its nonnegative precondition.

Window state introduces and tests this pure editor send. The
view-entry operation described next belongs to delete and other-window;
do not add an entry/session-selection send early just to test it. The
state part implements the existing-operation table below, tested with
constructed trees, without selecting another leaf.

Before leaving a view, store the live editor origin on that leaf. When
entering another view, focus its buffer through `find-id`, then install
the destination view's origin through `with-origin`. Rebuild only that
buffer's editor and keep all other editor fields. No second editor or
point is created. There is no automatic fit on entry; the next explicit
`ensure-visible` fits that selected view and records its height for page
motion. A direct frame's caller must fit after an entry that leaves point
outside its destination origin.

Existing buffer-selection operations retarget the selected leaf rather
than select a different leaf. They take the resulting current editor's
origin, not the origin of another view that happens to show that buffer.
This preserves the accepted single-view round-trip behavior.

| Existing operation | Window result |
|---|---|
| Both `add-buffer` arities; new-file find-file | Preserve the departing buffer and all unselected views. Selected leaf shows the inserted buffer with its fresh `(0,0)` origin. |
| `switch-buffer`; `selected-buffers`; find-file reuse; select-buffer success | Selected leaf shows resulting current ID and that editor's existing origin. All unselected views stay exact. Existing selection resets still apply even if current ID stays the same. |
| Successful `visited` / direct `visit` | Preserve current ID and tree. Selected origin becomes the fresh editor's `(0,0)`. Unselected views of that ID keep their stored origins and see the replacement text. Existing echo/search/ring/pending/prompt/slot resets and submission preservation still apply. |
| Refused `visit`, find-file refusal/name miss, save-as refusal | No window change. Keep the accepted Option/echo/prompt results. |
| Save-as success / `with-current-path` | Keep every view and origin exact; update only current path under its existing ID. |
| `kill-buffer`, nonsingleton | Remove current ID using the accepted successor-else-predecessor rule. Every view of that ID, including selected, shows the already chosen replacement ID and takes that replacement editor's origin. All other views stay exact. |
| `kill-buffer`, singleton | Keep buffer ID, replace its editor/path with the accepted fresh untitled defaults, and reset every view of it to origin `(0,0)`. |

Killing never removes a view, changes a lock, or changes a rectangle.
Take the replacement origin once, before retargeting, so traversal order
cannot change it. The killed ID is never left dangling. Views of the
replacement buffer that were not views of the killed ID keep their own
stored origins. Existing kill-buffer selection resets and prompt/slot/
submission/ring preservation stay in force; there is no save-on-kill.

Direct selections during a waiting prompt still preserve the prompt and
slot. Completion at Return acts on the buffer current then. It stores no
old buffer/view target. None of these operations changes the selected
view ID, tree shape, remembered size, or any rectangle, including when
the selected view is locked.

### 3.5 Buffer-identity migration and focused proof

Write `tests/aloemacs/windows-buffer-identity.rkt` before product edits.
Search every `AloemacsBuffer new` in product and existing tests, including
independent expected reconstructions. Append a nonnegative ID; use ID 0
for startup and distinct IDs for every live multi-buffer fixture, even
when editor/path values are equal. Preserve intentional old-arity
negatives; migrate other negatives to retain their original reason for
failure. Retain editor and UndoFrame inventories, session arity, and
every old frame/key assertion. Search again after migration.

Prove the exact three-field buffer shape and typed `id`, `fresh-id`, and
`find-id` results, plus wrong argument/receiver/arity rejection. Exercise
maxima on both zipper sides and current, sparse/non-ordered IDs, both
session add arities, removal followed by legal reuse, and preservation
through with-editor, with-path, visited/direct visit, save-as, selection,
and singleton removal. Larger removal changes no survivor ID. Check
current-first bounded lookup, hit/miss/wrap, preserved logical order and
payloads, and distinction between equal-content/duplicate-name buffers.
Name lookup and find-file reuse retain their accepted policy.

Use counted Fs doubles for exact existing I/O targets and zero extra
effects. Checked file load needs no Fs/Term injection; main still needs
only Fs and starts with ID 0 and thirteen session fields. Independent
expected values must not call the allocation or lookup being tested.
The full existing suite proves unchanged fitting, complete composer
bytes, search/prompt/slot behavior, and command/map inventories. No
window fixture/configuration or session-constructor migration belongs
here. Stop with this focused file and the full suite green (§9).

### 3.6 Window-state migration and focused proof

Write `tests/aloemacs/windows-state.rkt` before product edits. Search
every `AloemacsSession new`, including product startup and independent
expected sessions throughout `tests/aloemacs/`. Append a consistent
configuration: an ordinary fixture has one leaf, selected view 0, its
current buffer ID, and that editor's actual origin, not always `(0,0)`.
Use `(0,0)` remembered size before fit; expected fitted sessions record
the positive full terminal size now. Keep intentional old-arity
negatives; other negative fixtures still fail for their original reason.
Buffer IDs already exist and are not migrated again.

Inspect buffer, keymap, minibuffer, prompt-command, echo, file, kill,
motion, safe-cells, search, undo, viewport, visited-unchanged, and runner
proofs for constructor/inventory changes; this is not an exhaustive
list. Preserve substantive ownership, effects, exact bytes, bounded
duplicate-name scans, and independently built expectations. Search
again after edits. Do not derive expectations with session helpers
under test.

The focused proof owns these requirements:

1. Exact four new class inventories/order, recursive tree loading,
   leaves/find-view including mixed nesting and nonnumeric visit order,
   fourteen-field session shape, startup defaults, and concrete typed
   sends. Reject wrong arguments/receivers/arities. Checked file load
   has no effects or injected Fs/Term requirement; main needs only Fs.
2. `with-origin` changes exactly its two fields, including an origin
   beyond EOF, without fitting, focusing Text, or pushing undo. Preserve
   exact Text, point, quit, history, mark, and remembered text rows.
3. Every session reconstruction preserves configuration or mirrors only
   the selected origin as §3.3 requires. Use rich sessions with search,
   echo, ring, pending, prompt, submission, waiting command, and locks.
   Exercise edit/motion/undo/quit/search and prompt/slot transitions.
   Fitting still uses the full text rectangle; it stores full terminal
   size and mirrors the resulting selected origin. Frame stays pure.
4. Every §3.4 existing-operation row with constructed mixed multi-view,
   shared-buffer, multi-buffer, and locked fixtures. Assert IDs, zipper
   order, rich editor payloads, stored origins, selected view, locks,
   tree shape, size, accepted resets, and exact Fs targets. Kill captures
   replacement origin once, leaves no dangling ID, and preserves a
   surviving replacement view's different origin. Include singleton
   kill, current-name selection, and refused visit/save-as/name misses.
5. Direct selections during a waiting prompt retain its line/slot;
   Return acts on the then-current buffer. All one-view complete frame
   goldens remain exact: blank/narrow/safe rows, stored-origin scrolling,
   all three idle tokens, search, prompt, and one-row cursor rules. The
   unchanged runner still fits and writes once per drawn iteration.

Constructed multi-view fixtures prove state operations only here. Do
not assert their final geometry/frame/selected-height page motion until
§4, or add split/delete/other/lock commands to reach them. Normal startup
and all current keys still keep a single leaf. Rect values exist as
typed values, but layout and rectangle comparison algorithms for
commands arrive in their owning parts. Stop after migration and state
proof, with the full suite green.

### 3.7 Further separation of window state when needed

This part may be split further for conversation size, without adding
behavior or a maximum count. Decide before issuing the affected number,
record the narrower files/proofs and number-to-part mapping in the
README and that checkpoint, and preserve the following safe boundary:

- **State foundation.** Introduce §3.2's classes/pure tree lookup,
  §3.3's field/startup and entire session-arity migration, `with-origin`,
  positive-size bookkeeping, and all reconstruction/operation rules for
  one-leaf sessions. It may edit the window-state product files in §2,
  with `editor.aloe` limited to `with-origin` and `main.aloe` limited to
  startup configuration. Add `tests/aloemacs/windows-state-foundation.rkt`
  for inventories, helper purity, selected mirroring, one-leaf
  retarget/kill, fit bookkeeping, and exact old frames. Pure constructed
  trees are testable, but multi-view session transitions/paint are not
  supported yet. Every normal session remains valid and the existing
  suite must pass; no reconstruction or one-leaf operation is left
  broken for a successor.
- **Synchronization completion.** Generalize the state operations to
  constructed multi-view sessions: selected-only mirror/retarget,
  all-view killed-ID retargeting, singleton reset of all matching views,
  and exact inactive origins/locks/size. Edit only `file.aloe`, add
  `tests/aloemacs/windows-state.rkt`, and complete §3.6's multi-view
  obligations. Earlier focused tests may receive inventory adjustments
  only. No constructor migration, editor/startup change, geometry, or
  new command belongs here.

The manager may refine that separation if necessary, but each issued
slice must name a complete, independently tested subset of these
obligations and its supported intermediate state; do not defer failures.
Use a distinct `tests/aloemacs/windows-state-<slug>.rkt` for any further
state proof. The final state checkpoint completes all of §3.6 in
`windows-state.rkt`. Layout starts only after all state obligations are
reviewed. The types, final invariants, product behavior, and introduction
order are unchanged; public view entry stays in §6. Verification uses
the owning focused file, the full suite, and whitespace check (§9).

## 4. Layout, rendering, and fit — after window state

This part (intended 002) implements all of §4 after complete state
synchronization. It adds no field, constructor migration, or window
command. Its tests construct fitted configurations directly. It
replaces §3.2's temporary full-text-rectangle fit/frame path for multiple
views with the final selected-only fit and composition below, while
retaining exact one-view behavior. Startup and current keys still
produce one view until both splits are introduced.

### 4.1 Binary layout

For positive terminal `columns` and `rows`, let
`text-rows = rows - 1` when `rows >= 2`, otherwise `rows`. The root
rectangle is `(x=0, y=0, columns, text-rows)`. A leaf receives that
rectangle. Below divides height; Right divides width. For an extent
`n >= 3`:

```text
available = n - 1
earlier   = (available + 1) / 2   [integer division]
later     = available - earlier
```

The divider takes one cell; top/left gets the leftover cell. Below's
children keep the parent's width and x; bottom y is `y + earlier + 1`.
Right's children keep height and y; right x is `x + earlier + 1`.
The divider spans the parent's other axis. Geometry is recursive and
unweighted. There is no minimum beyond one cell on each axis for a
visible view, no automatic balancing, and no flattened same-direction
split. A new split changes only the selected leaf's rectangle; ancestor
and sibling rectangles stay exact.

For example, splitting a 9-by-5 text rectangle to the right gives
rectangles `(0,0,4,5)` and `(5,0,4,5)` with the divider at x=4.
Splitting its left view below gives `(0,0,4,2)` and `(0,3,4,2)`;
the right view remains `(5,0,4,5)`. Leaf order is original-left-top,
new-left-bottom, then original-right, regardless of numeric view IDs.

For a terminal resize, recompute geometry with the new size, preserving
the tree and locks. Lock protects against window commands, not an
external change to the terminal's available cells.

If an external shrink makes the existing tree impossible to display
with all positive rectangles, keep the tree and selection intact. Define
its nominal layout with `divider = min(1,n)`, `available = n-divider`,
and the same earlier/later division for every nonnegative extent. This
can give zero-width/height leaves. For that frame only, fit and paint
the selected buffer in the whole text rectangle using the single-view
composer; draw no dividers. Growing back restores the tree display.
This is a rendering fallback, not a deletion or a saved configuration.
Unselected origins do not change. Lock comparisons and window edits use
the nominal tree rectangles, not the temporary full-screen display.
Split still requires a positive selected rectangle and at least three
cells in its split direction. Delete may reduce the tree until it fits.

### 4.2 Pure rows at an explicit origin

Add editor:

```text
frame-rows(columns : Int, rows : Int, scroll-row : Int, scroll-col : Int)
  -> (List String)
```

For positive width/height and nonnegative origins, it returns exactly
`rows` strings. For each source line starting at `scroll-row`, first
drop `scroll-col`, then take `columns`, then apply existing `safe-cells`.
Missing source rows are `""`, including when the entire stored origin
is beyond the shortened buffer's last line. It does not chase point,
clamp a stored origin to EOF, horizontally pad, or generate ANSI.

Read from the existing Text zipper using `focus-at` and `next-lines`.
Keep bounded visible-row traversal; do not send `Text.lines` or
`Text.to-string` to render, seek from line zero on every frame, or add a
Text method. Failed focus at the explicit origin yields blank rows.
Traversal uses temporary immutable Text values. It never installs an
origin or focused Text on the editor/buffer, especially an unselected
buffer. No temporary `AloemacsEditor` is constructed for another view.

The direct editor's existing `frame` may share this row helper, but must
retain its exact byte results and existing raw-state branches. In
particular, direct editor frames retain their unpadded strings. The
session's one-view path continues to call that full-screen `frame` once
and append today's echo suffix. A multi-view path calls `frame-rows`,
never full-screen editor `frame` per view, and pads each row on the right
with spaces to its view's width before composing it.

### 4.3 Selected-view fit

Session `ensure-visible(columns, rows)` retains its signature and result
`(AloemacsSession H)`. Store those positive **full terminal** dimensions
inside `windows`; derive the text rectangle and selected rectangle.
Fit only the current editor with the selected rectangle's width and
height through its existing minimal `ensure-visible`. Mirror the fitted
origin onto the selected leaf. Preserve every unselected leaf exactly,
even those showing current's buffer. The fit's existing `text-rows`
payload is the selected rectangle height, so Page Up/Down use that view's
height. In the too-small-tree rendering fallback, use the full text
rectangle's positive dimensions instead.

The remembered size is configuration bookkeeping, not an editor origin
or a stored page height. All non-fit operations preserve it. A successful
split performs one fit with the remembered size after replacing the leaf;
this is the explicit post-split fit required in §5. Other window commands
install origins but leave fitting to the caller/runner. Frame reads only
and never changes the remembered size, any origin, or the selected buffer.

As before, a normative frame follows `ensure-visible` for the same
positive terminal size, especially after a key that moves point. Repeated
fit at the same size/point is idempotent. Resize is observed on the next
runner iteration, with no new event or runner arithmetic.

### 4.4 Composition and dividers

For **one leaf**, session `frame` retains today's complete String exactly:
the selected editor's `frame(columns, text-rows)` followed by the existing
echo suffix when `rows >= 2`. Preserve the intermediate cursor show/hide
sequences as well as final cursor placement. At one row there is no echo
suffix, even with an active prompt. The too-small-tree fallback uses this
same composer and has the same one-row prompt rule.

For **several visible leaves**, compose exactly:

```text
ESC[?25l ESC[2J ESC[H joined-text-rows
[ESC[rows;1H shown-echo-row, only when rows >= 2]
ESC[cursor-row;cursor-columnH ESC[?25h
```

The spaces above separate pieces and add no bytes. `joined-text-rows`
contains exactly `text-rows` rows of exactly `columns` safe cells, joined
by CRLF with no trailing CRLF. One clear and one hide/show pair surround
the complete multi-view composition. There is no per-view cursor sequence,
clear, echo, or status row. The one resulting String is still written once.

Right uses `|`; Below uses `-`. At a perpendicular divider meeting use
`+`, including a T junction. Treat a child divider reaching a parent
divider as extending through that one parent-divider cell: both
orientations then occupy it. Aligned child dividers on both sides make a
cross. Determine junctions from tree geometry, never from punctuation in
buffer text. All divider cells are session display data. For the §4.1
example, the horizontal divider row is `----+` followed by the right
view's four cells; other rows contain `|` at x=4.

The selected text cursor is one-based:

```text
cursor-row    = selected.y + point.line   - editor.scroll-row + 1
cursor-column = selected.x + point.column - editor.scroll-col + 1
```

Only the selected view supplies it, even when several views show that
same buffer and point. No cursor is drawn in an unselected view. With an
active prompt and a reserved echo row, the final cursor instead uses
`row=terminal rows` and `prompt.screen-column(columns)`. The text cursor
is restored when the prompt ends.

Echo row selection and clipping stay exactly as accepted: prompt first,
then active search, then `saved:` / `failed:` / idle path or `untitled`.
Take at most terminal `columns` characters and apply safe cells. The row
is full terminal width, not selected-view width, with unused cells blank
from the clear. Framing never writes the stored echo token.

### 4.5 Focused proof for layout, rendering, and fit

Write `tests/aloemacs/windows-layout-and-rendering.rkt` before product
edits. Construct trees/configurations and independent expected
rectangles/complete frame Strings; do not use future split/selection
commands or the layout/composer under test to build expectations.

1. Prove Below/Right allocation at minimum extent three and odd/even
   larger sizes, mixed nesting, unchanged sibling geometry, and
   depth-first order distinct from numeric IDs. Nominal zero axes and
   deep subdivisions follow §4.1; no tree is flattened or balanced.
2. `frame-rows` has the typed signature and argument/arity/receiver
   negatives, exact row count, vertical/horizontal clipping, safe
   controls, and missing/beyond-EOF blank rows. Use inactive origins
   beyond EOF after a shared edit or visit. Preserve the complete
   session, every buffer, exact Text focus, and every origin. Inspect
   bounded traversal, with no full Text materialization, temporary
   editor, installed inactive origin, or new Text method.
3. Retain every complete single-view and direct-editor frame golden,
   including raw-state branches, blank/narrow/safe rows, unpadded
   strings, scrolling, all idle tokens, search, prompt, and one-row
   behavior. Compare full multi-view ANSI Strings with exactly padded
   rows, one clear/hide/show pair, both dividers, T/cross junctions,
   punctuation independence, full-width echo, and one translated
   selected cursor. Select different leaves in constructed fixtures
   to prove cursor offsets; active prompt overrides it on the echo row.
4. Fit changes only current's origin/remembered text rows, selected
   origin mirror, and full remembered size. Include inactive views
   sharing that buffer with distinct origins and locked fixtures.
   Assert minimal/idempotent fit and selected-height page motion.
   Frame never records size or changes any state.
5. Drive a constructed multi-view session through the checked driver
   with scripted Term dimensions/keys and explicit session fit, frame,
   one Term write, then key handling. This proves the composition/resize
   contract before public splits exist; it does not require an actual
   runner entry point for a supplied session. Shrink triggers full-screen
   fallback without rewriting tree/selection/locks/inactive origins;
   growth restores dividers. Retain prefix/prompt/slot and exact Fs
   counts. Existing scripted runner tests still prove its one-view
   fit/write/read order here. §5.1 adds actual multi-view runner scenarios
   once its keys can create the tree. Do not edit startup/runner or add
   a fixture host capability to make those scenarios available early.

Source review must also confirm the structural rules in §9. No split,
delete, other-window, or toggle constructor/send/key is installed in
this part. Those absences, unchanged current keys, checked load without
injected Fs/Term, and complete existing-suite success are the stop bar.

## 5. Both splits — after layout, rendering, and fit

This command part is intended 003. Buffer identity, complete window
state/synchronization, and §4's layout/renderer/fit are reviewed
prerequisites, not implementation work to repeat here.

Append zero-payload `SplitBelow` and `SplitRight` constructors after
`SelectBuffer` in `AloemacsCommand`, in that order. Names are exactly
`"split-below"` and `"split-right"`. Extend the command `name` case and
session `execute-command` case; execution sends the corresponding
zero-argument session method and ignores `key`. No editor key arm or
command-owned execution method is added.

The new session sends are `split-below()` and `split-right()`, both
returning the receiver's concrete `(AloemacsSession H)`. Geometry comes
from the remembered size; commands query no Term or Fs.

| Condition | Result |
|---|---|
| No positive size has been remembered | Preserve configuration, buffers, and all other state; echo per §8. |
| Selected view is locked | Same refusal. |
| Selected nominal rectangle has a zero axis, or fewer than three cells in the split direction | Same refusal. |
| Otherwise | Replace selected leaf with Below or Right; echo per §8; fit the selected child into its new rectangle. |

Both children show the original buffer ID and start with the original
live editor origin from immediately before the split. Both are unlocked.
The original leaf ID stays selected on the earlier side; the fresh ID
occupies the later side. Post-split fit changes only the original child's
origin and the shared buffer editor's origin/remembered rows. The new
child keeps the pre-split origin. No other buffer/editor/view changes.

Successful split preserves text, Text focus, point, quit, history, mark,
ring, search, prompt, submission, waiting command, and pending prefix.
Refusal preserves all state except for the echo outcome specified in §8;
with an active prompt or search, the whole session stays unchanged. A
split never runs a waiting prompt command. A direct split with pending
present preserves it; the normal chord has
already consumed it before execution. No split pushes an undo frame,
reads, writes, starts a prompt, requests quit, or arms a prefix.

Keep existing nested bindings first, then append `"2" -> SplitBelow`
and `"3" -> SplitRight`. This part's exact nested order is:

```text
"save", "find", "kill", "b", "2", "3"
```

The nested default remains `None`. The global map, its command order,
its one prefix, its shared save value, and `Some SelfInsert` default stay
unchanged. Plain `2` and `3` insert; `0`, `o`, and `l` remain prefix
misses in this part. All unbound second keys are still consumed without retry.

Other-window and delete sends/constructors/bindings are absent until the
following part (§6). The view lock bit already exists. Split respects a
directly constructed locked fixture, but no toggle send/command/key
exists until the final window-lock part (§7).

### 5.1 Focused proof for both splits

Write `tests/aloemacs/windows-split.rkt` before product edits. Search
command/map inventories and newly bound prefix-miss examples in existing
tests; update only those affected assertions. No buffer/session
constructor migration or renderer implementation belongs here. Build
expected sessions/trees/frames independently of dispatch and split.

No-TTY tests prove:

1. Exact SplitBelow/SplitRight constructors, names, typed session sends,
   execute-command cases, and binding order; reject wrong arguments,
   receivers, and arities. Fresh checked load needs no Fs/Term injection
   or effect, and main retains the prior startup state.
2. Both orientations at extent three and odd/even larger extents;
   refuse before fit, at extents one/two, for a zero nominal axis, and
   for a locked constructed view. Assert exact tree, fresh IDs,
   rectangles, selection, origins, permitted fit changes, and zero Fs
   calls. Refusal preserves all state except §8's echo result; with an
   active prompt or search the complete session is unchanged.
3. Repeated and mixed splits retain ancestor/sibling geometry and
   inactive state, preserve visit order, and redraw complete padded ANSI
   frames with both dividers, T/cross junctions, and one cursor/echo.
   Start both children at pre-split origin; post-split fit may change
   only the original child/shared editor origin and remembered rows.
4. Shared edit/undo redraws both views from one buffer's text, point,
   history, and mark. Separate origins remain, selected-height page
   motion works, and shortened text/visit beyond inactive EOF paints
   blank rows. Retain §3.4's existing-operation behavior after real
   splits; its full constructed-state proof remains owned by §3.6.
5. Direct/chord equivalence through redraw, plain `2`, `3`, `0`, `o`,
   `l` insertion, consumed unbound prefix keys, and quit/search/prompt
   routing. Direct execution preserves a raw pending map and active
   prompt/search. For each initial token (`""`, `"saved"`, `"failed"`),
   successful/refused direct splits keep it while prompt or search
   remains; with neither, success stores `""` and refusal `"failed"`.
   Assert hidden stored token and complete row/cursor bytes. A `ctrl-x`
   key that exits search before command execution uses the later rule.
6. The unchanged scripted runner splits, edits, saves, and quits with
   fit before frame, one frame write per drawn iteration, exact Fs
   targets/counts, and resize/shrink/growth behavior from §4. All earlier
   focused proofs and the existing suite remain green.

Stop before delete/other-window/toggle sends, constructors, or keys.

## 6. Delete and other-window — after both splits

This part is intended 004; it adds no field, constructor migration, or
renderer. It uses the already reviewed identity/state/layout/split work.

Append zero-payload `DeleteWindow`, then `OtherWindow`, with names
`"delete-window"` and `"other-window"`. Execution sends session
`delete-window()` or `other-window()` and ignores its key argument.
Both return `(AloemacsSession H)`. Append their ordinary command bindings
in that order: `"0"`, then `"o"`. The nested order is now:

```text
"save", "find", "kill", "b", "2", "3", "0", "o"
```

### 6.1 Other-window and selection resets

Other-window selects the next leaf in §3.2's depth-first order and wraps
last to first. Obtain the order from the tree, not numeric ID order or
buffer order. Use guarded list head/rest traversal; there is no List
index. A one-leaf configuration returns the whole session unchanged.

For a different leaf, perform §3.4's origin handoff. If the destination
buffer ID equals the departing ID, preserve echo, every search field,
prompt, submission, waiting command, ring, and pending exactly. Only
selection and the shared editor/selected-origin handoff change. Search
does not acquire a second point or a second saved origin.

If the buffer ID changes, accept the departing search-result point and
apply the existing `switch-buffer` search and prefix resets, with the
window-command echo rule from §8:

```text
echo = unchanged if an active prompt remains, otherwise ""
searching = wrapped = failing = #f
query = ""
origin = Position(0,0)
pending = None
```

Preserve Fs, ring, active prompt, last submission, and waiting command.
Focus the destination buffer without reordering the zipper and install
that view's stored origin. Every buffer's text, Text focus, point, quit,
history, and mark stay exact. No fit occurs until `ensure-visible`.
Buffer IDs, not names or equal editor/path payloads, decide this reset.

### 6.2 Delete and sibling promotion

Delete removes the selected leaf. If it is the sole leaf or it is locked,
refuse with echo per §8. Otherwise construct the candidate tree by
replacing its immediate parent split with the surviving sibling. The
sibling may be a leaf or subtree; keep its structure, view IDs, buffer
IDs, stored origins, and lock bits. Recompute its descendant layout in
the old parent's rectangle using §4.1. All geometry outside that parent
stays exact. Descendants keep their relative binary layout; no balance
or flattening is performed.

Before installing the candidate, compare each locked surviving view's
old and new rectangle under the same remembered size. Refuse with echo
per §8 if any locked view would move or resize. The removal of a
locked selected view has already been refused. This is an exact geometry
comparison, not a blanket ban whenever a sibling subtree contains a lock.
With an unknown size in a raw multi-view fixture, conservatively refuse
if any surviving sibling descendant is locked; normal split-created
trees already have a remembered size. Unlocked deletion requires no fit.

On success select the sibling leaf or, for a subtree, its first leaf in
visit order. Use the same entry/origin handoff and buffer-ID-dependent
resets as other-window. Echo becomes `""` only on a buffer change with
no active prompt remaining; otherwise retain it. Preserve search/pending
on same-buffer deletion. Preserve active prompt, slot, submission, and
ring in either case. No
buffer is killed; views elsewhere of the deleted leaf's buffer remain.
Delete changes no text, Text focus, point, quit, history, mark, or path,
performs no file I/O, and leaves the remembered size unchanged.

This part includes the deletion lock guard for constructed fixtures;
the final window-lock part adds the public toggle and proves
user-reachable locked transitions. There is no lock command/key or
new field here.

### 6.3 Focused proof for delete and other-window

Write `tests/aloemacs/windows-delete-and-other.rkt` before product edits.
Prove the new command names, typed sends, direct/chord equivalence,
inventory order, and that plain `0` / `o` still insert.

Exercise one, two, and at least three leaves with nested mixed splits.
Assert next/wrap order independently of numeric IDs and buffer order,
the singleton no-op, original-origin storage and destination installation,
same-buffer state preservation, and different-buffer resets even for
duplicate names and equal content. Fit after entry and compare complete
ANSI frames with the cursor translated to the selected rectangle. A
round trip without fit/edit restores each view's origin; no second point
appears, and shared edits remain shared.

Test deleting either side of each orientation, a nested selected leaf,
and a leaf whose sibling is a subtree. Assert exact promoted geometry,
selection of its first leaf, unchanged outside rectangles and buffer
zipper, echo rules, prompt/slot/submission/ring preservation, and no Fs
calls. Last-view and constructed-lock refusals preserve all state except
the §8 echo outcome; with an active prompt or search, the complete session
stays unchanged. Delete never sends kill-buffer or removes the unshown
buffer. A deletion
from a too-small-tree fallback can restore a displayable tree.

For other-window and successful delete, assert the stored echo with each
initial token (`""`, `"saved"`, `"failed"`). Same-buffer entry retains it
with or without a prompt/search. Different-buffer entry preserves an
active prompt and the token, while clearing search; with no prompt
remaining it clears search and stores `""`. Refused delete retains the
token while a prompt or search is active, and stores `"failed"` otherwise.
Assert the active row and cursor as well as the hidden stored token.

Scripted runner tests exercise split, other-window, an edit in a different
selected rectangle, delete, and quit with unchanged fit/write/read
counts. Existing prompt commands retarget selected without changing tree
shape; direct selections during a prompt keep its line/slot and Return
acts on the then-current buffer. Earlier tests stay green. This part must pass
without ToggleWindowLock or its binding.

## 7. Window lock — after delete and other-window

This part is intended 005. The view's lock bit, split lock refusal, and
delete geometry guard already exist; this part adds public access and
its proof, with no new field or foundation work.

Append zero-payload `ToggleWindowLock`, exact name
`"toggle-window-lock"`. Session `toggle-window-lock() ->
(AloemacsSession H)` flips only the selected view's `locked` bit.
Execution ignores its key argument. Append `"l"` to the nested map;
the final binding order is:

```text
"save", "find", "kill", "b", "2", "3", "0", "o", "l"
```

The constructor order of the five new commands is SplitBelow,
SplitRight, DeleteWindow, OtherWindow, ToggleWindowLock. Plain `l`
inserts. The nested default and the global map stay unchanged.

Toggle changes no tree shape, rectangle, buffer, origin, editor, echo,
search, prompt, submission, slot, pending, ring, remembered size, or quit
flag. A direct toggle preserves a pending map; chord dispatch consumes
it before execution. No status label, marker, mode line, file effect, or
automatic operation is added. Lock protects existence and rectangle,
including position. It does not pin the buffer or prevent editing,
scrolling, fitting, changing path, visiting, selecting, or killing a
buffer. Other-window may select a locked view. All §3.4 retargeting rules
apply to locked views.

Write `tests/aloemacs/windows-lock.rkt` before product edits. Prove the
name/type/key, exact toggle-only change and toggle-twice equality, initial
unlocked state, and unlocked children of an ordinary successful split.
Lock selected, then refuse both splits and delete with the §8 echo
outcome and complete preservation of all other state. With neither a
prompt nor search active, refusal stores `"failed"`; with either active,
it retains each initial token and the complete session. Toggle itself
preserves the token in every case. Unlock and prove those commands can
succeed when geometry permits.

Use mixed nested trees to lock an unselected descendant in the surviving
sibling: deletion must refuse if its rectangle would move or resize.
Also prove a lock outside the affected parent does not block a local
split or delete. Use a deep sibling subdivision in which a locked
descendant's rectangle stays exactly equal despite promotion; that
deletion is allowed. Compare all four rectangle coordinates, not just
width/height. Successful/refused commands retain their §8 echo rules.

Prove locks survive other-window, buffer addition/switch/selection,
find-file, save-as, direct visit, buffer kill/retarget, edits/undo, fit,
prompt/submission/cancel, and redraw. Include singleton kill under a
locked tree. Terminal resize/fallback may change available geometry;
it preserves tree/lock bits and does not prevent the next frame. A
scripted runner drives lock, refused split/delete, unlock, successful
split/delete, and quit with the existing iteration contract. Count Fs
calls: the window commands make none.

## 8. Echo and input rules for all slices

The stored vocabulary remains exactly `""`, `"saved"`, and `"failed"`.
When a window command runs, its stored echo token follows this table.
A direct send runs on the session as it stands; it does not cancel an
active prompt or exit an active search first. A key that exits search
before the command runs does not leave that search in place, so the
command uses the later applicable row.

| Event | Stored token |
|---|---|
| Command leaves an active prompt in place, or leaves an active search in place | Unchanged |
| Successful split, when the first row does not apply | `""` |
| Refused split or delete, when the first row does not apply | `"failed"` |
| Other-window or successful delete changes buffer ID, when the first row does not apply | `""` |
| Other-window or successful delete keeps buffer ID | Unchanged |
| Toggle lock | Unchanged |

The first row is the preservation rule; later rows apply only when it
does not. Successful and refused splits preserve search and prompt, so
they retain the stored token while either is active. A refused delete
changes nothing while either is active. Other-window and successful
delete preserve an active prompt. On a buffer change they clear search,
and store `""` only when no active prompt remains. Same-buffer entry
retains the token, search, and prompt. Toggle lock always retains the token.

Prompt and search continue to paint the echo row while active, hiding
the stored idle token. This adds no token and no per-window echo.

`handle-key` keeps current quit, search, active prompt, then pending/global
idle dispatch in that order. A prompt owns its input and ignores `ctrl-x`;
it does not interpret a window chord. Search still treats printable
characters as query text and ends before forwarding named `ctrl-x`.
The pending map clears before a bound command runs. Plain `2`, `3`, `0`,
`o`, and `l` insert on the idle global path; unbound second keys change
no buffer and are consumed. Unknown idle command-name strings are still
misses, not a command router. Direct execution retains the existing
absence of a general quit/search/prompt guard and uses the rules above.
No window command starts a prompt, sets quit, or arms a prefix.

## 9. Verification, acceptance, and stop

Each implementer writes the focused tests first, observes the missing
behavior fail, implements only its assigned slice, and runs verification
from the project root. Every agent test command includes `TMPDIR=/tmp`
and `-y`, even when a predecessor omits them.

For **buffer identity (replacement aloemacs-windows 000)**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-buffer-identity.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **window state and synchronization (intended 001)**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-state.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **layout, rendering, and fit (intended 002)**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-layout-and-rendering.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **both splits (intended 003)**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-split.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **delete and other-window (intended 004)**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-delete-and-other.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **window lock (intended 005)**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-lock.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

If §3.7's further state separation is used, state foundation runs:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-state-foundation.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Synchronization completion uses the `windows-state.rkt` commands above.
For any finer state part, the manager writes the exact command for its
named `tests/aloemacs/windows-state-<slug>.rkt`, then the same full-suite
and whitespace commands. Verification is attached to the part and test
path, independent of later number shifts. The full suite includes every
completed focused proof; no later test file is created to satisfy an
earlier command.

The aloemacs suite is the required regression bar. No timing gate,
benchmark, or physical TTY hand check is required. A checkpoint may name
wider tests only for a concrete dependency. Do not commit `compiled/`.
The optional existing launch is
`racket host/racket/aloemacs-run.rkt [path]`. After a `.rkt` edit, run the
named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe` before
launching; the launchers load existing bytecode without rebuilding it.
`.aloe` edits need no rebuild.

Review source as well as results, applying only rules introduced by the
current part and its predecessors: the tree/configuration is the only
window store, each buffer owns one editor, rendering never installs an
inactive origin, command execution belongs to session constructor cases,
no List index or whole-Text rendering shortcut appears, all rebuilds
thread IDs/configuration, and the runner and Term remain untouched.
Behavioral equality alone cannot prove these structural rules.

The completed series is accepted when all of these are true:

1. One view retains today's idle keys, saves, find-file/save-as/select-
   buffer, direct visit, cycling switch, kill-buffer, search, prompt,
   prefix consumption, filesystem effects, and exact composer bytes.
2. Both splits show the current buffer through two views, preserve the
   original selection/point, give the new view the pre-split origin,
   draw safe/clipped rows and dividers, and refuse a split that cannot
   fit. Other ancestors/siblings keep their rectangles.
3. Other-window wraps in visit order, stores/installs view origins,
   changes zipper focus without changing order, and applies search/
   prefix resets only on a buffer-ID change. Its echo follows §8,
   preserving the token while a prompt or search remains active. Delete
   preserves the last view and promotes the sibling with the specified
   selection and the same buffer-change and echo rules.
4. Lock toggles only its bit. Split/delete cannot remove, move, or resize
   a locked view. Lock does not pin its buffer. Existing commands may
   retarget it while keeping the tree and geometry.
5. Stable IDs survive editor/path replacement, distinguish equal-content
   buffers, and let kill-buffer retarget every affected view without
   deleting one. Shared text/point/history/mark remain on one buffer;
   inactive origins remain independent and are never fitted during paint.
6. Echo stays full width with three stored tokens, §8's preservation and
   outcome rules, prompt/search priority, and accepted cursor rules.
   Several visible views produce one clear, one composed text rectangle,
   one echo, and one selected/prompt cursor
   in one String. Resize preserves the tree and has the defined tiny-size
   rendering fallback.
7. Every owning focused proof and `TMPDIR=/tmp raco test -y tests/aloemacs`
   pass without a TTY at each checkpoint stop. The ordered parts and any
   further window-state separation add no behavior beyond this spec.
   No later feature, runner/Term/language change, or global checkpoint
   is added. There is no maximum checkpoint count.

An individual checkpoint is complete when its introduction/migration
and owning proof meet their section's intermediate contract, the full
suite passes, and source/whitespace review confirms its file boundary.
Later-part behavior is neither required nor permitted early. Report the
initial missing-behavior failure, final verification results, and files
changed; stop without starting its successor.

The revised partition is accepted. The manager writes
**replacement aloemacs-windows 000 only**, and stops. The
historical `000-split.md` remains unedited and must not be resumed. If
you have been told to read this file as the manager assignment, it is
the whole assignment; do not
write later checkpoints in advance.
