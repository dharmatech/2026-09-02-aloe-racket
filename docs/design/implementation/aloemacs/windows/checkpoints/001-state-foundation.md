# aloemacs-windows 001 — State foundation

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Introduce the window value types and append the session configuration.
Complete the session-constructor migration, origin mirroring, size
bookkeeping, and existing-operation integration for one-leaf sessions.
Keep every existing key, file effect, editor fit result, and complete
frame exact.

This is the **state foundation** separation permitted by spec §3.7.
One leaf may show any current buffer in a multi-buffer zipper; one leaf
does not mean one buffer. Pure constructed trees can have several leaves
for tree traversal tests. Multi-view session transitions and painting are
not supported at this intermediate stop. They are later assignments.

Stop after the foundation proof and full suite pass. Add no layout,
multi-view synchronization, window-entry operation, window command, or key.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-windows 001**, filed as
  `checkpoints/001-state-foundation.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law, including §9's recursive
  constructor classes and lawful typed absent Options. Evaluation is
  send with a literal selector; function objects execute through `call`.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, scope,
  introduction order, and non-goals. §§3.2–3.4 define the types,
  configuration, origin helper, and existing-operation rules. Apply
  §§3.6–3.7 to the foundation's one-leaf subset; §9's **state foundation**
  commands and individual-checkpoint completion rules govern verification.
  Predecessor specs in §1 retain authority for preserved behavior.
- [000-buffer-identity.md](000-buffer-identity.md) is implemented; the
  user has requested its successor. Buffer IDs, `fresh-id`, and bounded
  `find-id` already exist. Preserve their proofs and semantics.
  The historical [000-split.md](000-split.md) remains unimplemented and
  must not be resumed or edited.
- Start from [editor.aloe](../../../../../../examples/aloemacs/editor.aloe),
  [file.aloe](../../../../../../examples/aloemacs/file.aloe), and
  [main.aloe](../../../../../../examples/aloemacs/main.aloe).
  Editor has eight fields; UndoFrame has four; buffer has editor/path/id;
  the collection has before/current-buffer/after. Session currently has
  thirteen fields, ending with `waiting-command`, and no window types.

The manager has recorded this separation in the [README](../README.md):
001 is state foundation; the next unissued part is synchronization
completion, before layout. No later checkpoint is part of this assignment.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: introduce the four classes below,
  append `windows`, migrate every session reconstruction, integrate
  one-leaf mirroring/retargeting, and remember positive fit dimensions.
  Keep its two existing loads and the relative order of existing classes.
  Internal application helpers may be added within the permitted classes.
- `examples/aloemacs/editor.aloe`: add only `with-origin` with the exact
  semantics below. Do not change any existing editor algorithm or field.
- `examples/aloemacs/main.aloe`: append only the initial configuration
  to its session constructor. Keep buffer ID 0, cold empty Text, and all
  other startup defaults exact.
- Create `tests/aloemacs/windows-state-foundation.rkt` before product
  edits. It owns the focused foundation proof below.
- These exact existing files under `tests/aloemacs/`, only for session
  constructors, matching fixtures and independent expected values,
  affected class/field/method inventories, constructor negatives, and
  remembered-fit expectations:

  ```text
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
  windows-buffer-identity.rkt
  ```

This list comes from current session-constructor and inventory searches.
Preserve substantive ownership, buffer identity, bounded duplicate-name
lookup, effects, search/prompt/slot behavior, and all complete frame
assertions. The earlier identity proof receives only the matching
migration/inventory adjustments; do not weaken its behavioral tests.

### Must leave untouched

- Every other product module, `host/racket/aloemacs-run.rkt`,
  `host/racket/term.rkt`, other host files/capabilities, Fs/Term interfaces,
  `aloe/`, and `lib/`. Add no module, load, dependency, or capability.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  this series' design documents, and both 000 checkpoint files.
- Every existing test outside the exact list above. Do not create
  `windows-state.rkt` or any layout/command focused proof early.
- Buffer/collection/editor/UndoFrame/prompt shapes; all command
  constructors, names, execution cases, map inventories, and bindings;
  all existing renderer algorithms and complete frame bytes.

If another file or a design change is necessary, stop and return this
checkpoint to the manager instead of widening it. If finishing would
require compaction, report the size problem and stop for review; do not
split the assignment or implement the next part yourself.

## Slice requirements

### 1. Window value types and pure tree traversal

After `AloemacsBuffers` and before `AloemacsCommand`, declare these four
non-generic classes in exactly this order:

```aloe
AloemacsView
  (fields (id Int) (buffer-id Int)
          (scroll-row Int) (scroll-col Int) (locked Bool))

AloemacsWindowTree
  (constructors
    (Leaf (fields (view AloemacsView)))
    (Below (fields (top AloemacsWindowTree) (bottom AloemacsWindowTree)))
    (Right (fields (left AloemacsWindowTree) (right AloemacsWindowTree))))

AloemacsWindowRect
  (fields (x Int) (y Int) (columns Int) (rows Int))

AloemacsWindows
  (fields (tree AloemacsWindowTree) (selected Int)
          (columns Int) (rows Int))
```

These inventories specify the fields/constructors; implement them with
ordinary `define-class` syntax. Retain existing class declaration order.
The tree is nonempty and binary; nested splits never flatten. Valid view
IDs are nonnegative and unique within a live tree. `selected` is a view
ID, and `buffer-id` is a stable buffer ID, never a list position or name.
Valid stored origins are nonnegative. Raw constructors are not validators.

Add tree `leaves() -> (List AloemacsView)` in depth-first
top-before-bottom / left-before-right order, and
`find-view(id : Int) -> (Option AloemacsView)`. Use constructor cases
and ordinary pure traversal, with lawful absent Options. A miss is
`None`. Prove mixed nesting whose visit order differs from numeric ID
order. Traversal does not install session selection or buffer focus.

Views contain no editor, Text, point, path, mark, history, ring, remembered
page height, or rectangle. Rectangles are transient typed values; layout
and rectangle comparison algorithms are absent in this slice. Configuration
contains the whole window store. Add no counter, secondary registry,
List index, computed selector, or reflective construction.

### 2. Session field, startup, and full migration

Append `(windows AloemacsWindows)` after `waiting-command`. The exact
fourteen-field session order is:

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

This is the only new session field in the series. The existing search
`origin` remains its saved Position. Keep computed `current-buffer`,
`editor`, `path`, `text`, `point`, and `quit` sends unchanged in meaning.

Append this exact initial value to `main.aloe`:

```aloe
(AloemacsWindows new
  (AloemacsWindowTree Leaf (AloemacsView new 0 0 0 0 #f))
  0 0 0)
```

The startup view is unlocked and shows buffer 0. Remembered size `(0,0)`
means not fitted; do not guess terminal dimensions or query Term.
Keep startup's cold Text and lawful untyped absent-Option forms such as
`(if #t (Option None) (Option Some typed-value))`. Inside methods an
expected constructor field type may supply `None`. Add no Option setter
or checker change.

Search every `AloemacsSession new` in product and `tests/aloemacs/`,
including independently constructed expected sessions. Append a
consistent configuration: ordinary fixtures have selected view 0, their
current buffer's actual ID, and that editor's actual stored origin.
Do not assign `(0,0)` blindly to scrolled fixtures. Before fit the size
is `(0,0)`; expected positive fitted sessions remember the full terminal
dimensions. Preserve intentional old-arity negatives; migrate other
negatives so they still fail for their original reason. Add a focused
negative for the former thirteen-field constructor.

Retain the existing buffer IDs and constructor shape; this is not a
second buffer migration. Repeat constructor and inventory searches after
edits. No reconstruction or existing regression is left for a successor.

### 3. Origin helper and one-leaf reconstruction invariants

Add editor
`with-origin(scroll-row : Int, scroll-col : Int) -> AloemacsEditor`.
Replace only those two fields. Preserve exact Text, point, quit, history,
mark, and remembered `text-rows`. It does not fit, clamp point, focus or
rebuild Text, or push an undo frame, including for origins beyond EOF.
Valid callers supply nonnegative origins.

In every supported returned session, the selected leaf's buffer ID
equals current's ID and its origin mirrors current editor's origin.
Support nonzero view/buffer IDs, nonzero origins, a locked leaf, and
nonzero remembered dimensions in constructed one-leaf fixtures.

- Echo/search-metadata/prefix/prompt/submission/slot-only reconstructions
  preserve the entire configuration exactly, while retaining their
  accepted effects on the corresponding session fields.
- Current-editor rebuilds, including `with-editor`, `with-search`, and
  `with-kill-state`, mirror the returned editor's origin on the selected
  leaf. Preserve that leaf's ID, buffer ID, lock, and remembered size.
  Exercise edit, motion, undo, quit, search, and fit through these paths.
- Direct save preserves the entire configuration. `with-current-path`
  and successful save-as preserve every view field and remembered size.
  Path/editor replacements keep current's buffer ID.

Do not implement a view-entry/session-selection send. Installing another
leaf's origin and choosing its buffer through `find-id` belongs to delete
and other-window. This checkpoint's origin helper is independently tested.

### 4. Existing buffer operations with one leaf

Integrate every spec §3.4 operation for one-leaf sessions, including
sessions with several buffers. Preserve selected view ID, Leaf shape,
lock bit, and remembered size in every case. Lock does not pin a buffer
or prevent existing operations.

| Existing operation | Required leaf result |
|---|---|
| Both `add-buffer` arities; new-file find-file | Show the newly inserted fresh buffer ID at its fresh `(0,0)` origin. Preserve the departing buffer. |
| `switch-buffer`; `selected-buffers`; find-file reuse; select-buffer success | Show resulting current ID and that editor's existing origin. Existing selection resets apply even if the ID stays the same. |
| Successful `visited` / direct `visit` | Keep current buffer ID and reset leaf origin to the fresh editor's `(0,0)`. |
| Refused `visit`, find-file refusal/name miss, save-as refusal | Preserve configuration exactly; keep accepted Option/echo/prompt outcomes. |
| Save-as success / `with-current-path` | Preserve configuration exactly while replacing only current path under its existing ID. |
| Nonsingleton `kill-buffer` | Show the accepted successor-else-predecessor replacement ID and its editor's existing origin. Remove only the killed buffer ID. |
| Singleton `kill-buffer` | Keep buffer ID, install the accepted fresh untitled defaults, and reset leaf origin to `(0,0)`. |

Keep accepted search/echo/prefix resets and ring/prompt/submission/slot
preservation for addition, selection, and kill. Successful direct visit
retains its accepted resets and submission preservation. There is no
save-on-kill or new I/O. No operation deletes a view or changes its lock.

Direct selection during a waiting prompt preserves its line and command
slot. Return acts on the buffer current then, with no stored old target.
Test same-current name selection, duplicate-name reuse, and nonzero IDs.
Do not change existing name matching, allocation, zipper order, or effects.

All-view killed-ID retargeting and inactive-view preservation are deferred
to synchronization completion. Do not construct multi-view sessions to
claim those behaviors here; pure tree traversal remains in scope.

### 5. Positive fit bookkeeping with the existing composer

For positive session `ensure-visible(columns, rows)`, store the full
terminal dimensions in `windows`. Continue fitting current editor to
width `columns` and height `rows - 1` when `rows >= 2`, otherwise `rows`.
Mirror its resulting origin onto the sole selected leaf. Preserve its
IDs, lock, and all other accepted session/editor payloads.

This retains predecessor full-text-rectangle fit and page-motion height.
No selected-rectangle algorithm belongs here. Repeated fit at the same
size/point is idempotent. All non-fit operations preserve remembered size.

Leave `frame` pure and its existing single-view composer exact. It never
remembers size, fits, or changes an origin. Retain complete blank/narrow/
safe-row, scrolling, idle-token, search, prompt, and one-row cursor goldens,
including intermediate cursor sequences. Echo remains one full-width row.
The unchanged runner fits and frames with the same queried dimensions,
writes one String per drawn iteration, and checks current editor quit.

### 6. Focused proof, written first

Create `tests/aloemacs/windows-state-foundation.rkt` and observe missing
behavior fail before product edits. Use the existing checked driver,
`rackunit`, independently constructed expected values, source snapshots,
counted Fs doubles, and existing scripted Term fixtures where relevant.
Do not build expectations through the helper or transition under test.

Prove the one-leaf subset of §§3.6–3.7:

1. Exact new class order, field/constructor inventories, recursive checked
   tree loading, concrete typed selectors, `leaves`, and `find-view`.
   Include Leaf/Below/Right, mixed nesting, nonnumeric visit order,
   selected/nonselected lookup hits, and misses. Reject wrong field and
   argument types, receivers, and arities. Keep existing class shapes
   exact and all new window commands/sends/keys absent.
2. Fourteen-field session shape and lawful cold startup, with view/buffer
   ID 0, origin `(0,0)`, unlocked state, and unknown size. Fresh checked
   file load needs no injected Fs/Term and causes no effects. Main still
   needs only Fs. Reject missing/extra/wrong-type configuration and the
   former session arity without weakening other constructor negatives.
3. `with-origin` changes exactly two fields on rich cold/indexed editors,
   including a focused Text zipper and an origin beyond EOF. Compare
   exact Text, point, quit, history, mark, and remembered rows. Assert
   source immutability, no undo push, and no fit or Text refocusing.
4. Every one-leaf preserving reconstruction and editor wrapper. Use rich
   search/echo/ring/pending/prompt/submission/slot payloads, sparse buffer
   IDs, a nonzero view ID, a locked leaf, and remembered dimensions.
   Assert exact configuration preservation or only the required origin
   mirror for edit/motion/undo/quit/search and prompt/slot transitions.
5. Every operation row above with singleton and multi-buffer zippers.
   Assert complete independent results, IDs, logical order, exact rich
   editor payloads, leaf origin/lock/selection/size, accepted resets, and
   exact Fs targets/counts. Include current-name selection, duplicate-name
   reuse, misses/refusals, both add arities, singleton/non-singleton kill,
   direct selection while waiting, and Return on the then-current buffer.
6. Positive full-size fit bookkeeping, minimal/idempotent origin fitting,
   mirrored origin, remembered full size versus reserved text-row height,
   one-row fit, and resize. Non-fit transitions preserve remembered size;
   direct frame changes no state. Preserve complete one-view ANSI goldens
   for all idle tokens, active search/prompt, controls, clipping, stored
   origins, and one-row prompt/cursor behavior.
7. The complete migrated suite retains identity, all current command/map
   inventories and keys, prompt precedence, consumed prefix misses, and
   the unchanged runner's fit/write/read and exact file-effect proofs.
   Normal startup and every current key still produce one leaf.

## Explicit non-goals

No multi-view session transitions/paint, inactive-origin synchronization,
all-view killed-ID retargeting, view entry, layout, rectangle comparison,
`frame-rows`, selected-rectangle fit, resize fallback, divider, or public
split/delete/other-window/lock constructor/send/key. The lock bit exists
as stored state only. No fresh-view allocation is needed before split.

No extra editor/point/mark/history/ring per view, mode line, buffer menu,
completion, automatic operation, identity registry/counter, new Fs/Term
effect, runner change, Text method, List index, kernel message, Mirror,
mutation, inheritance, delegation, macro, implicit Int/Float coercion,
new special form, next exploration, or Boids work.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/windows-state-foundation.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`. The full suite
includes buffer identity and every predecessor proof. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or physical TTY
hand check is required. Launching the existing runner is optional;
after a `.rkt` edit, run the named tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching because
the launchers load existing bytecode. `.aloe` edits need no rebuild.

Review source as well as results: the four classes have the specified
shape/order, configuration is the only window store, each buffer owns one
editor, `with-origin` preserves exact Text, every session reconstruction
threads configuration, supported editor replacements mirror origins,
one-leaf selections/kills retarget correctly, and only fit records size.
Repeat constructor/inventory searches. Rendering, commands/maps, runner,
Term, host, libraries, and language remain untouched. Confirm only the
permitted files changed; behavior equality alone cannot prove these rules.

Complete when the focused proof and full suite pass, `git diff --check`
is clean, the supported one-leaf intermediate contract and source review
pass, and no migration or regression remains. Report the initial
missing-behavior failure, final verification results, changed files, and
structural review. Stop when green for human review. Do not implement or
issue synchronization completion or any later checkpoint.
