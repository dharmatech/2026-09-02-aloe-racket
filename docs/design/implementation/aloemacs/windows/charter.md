# Charter — aloemacs windows

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

The echo rule is §4.8. A window command that leaves an active
prompt or an active search in place keeps the stored token.
Product behavior and non-goals are accepted and closed. The approved
packaging revision replaces §4.9's count cap with the ordered parts
below. Revise [`spec.md`](spec.md) for that partition; preserve §4.8
and every other accepted product decision.

**Your job.** Write the specification for **split, delete,
other-window, and window lock**. The series identity is
**aloemacs-windows**. A window is a view of a buffer. The user
splits and deletes views; other commands leave the tree where
the user put it. Then **stop**. Do not write checkpoints. Do
not implement.

This effort refuses a mode line, a buffer menu, a second
editor per view, automatic splits, and `delete-other-windows`.
Those stay later or out, so this spec stays small enough to
slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the accepted product decisions in §4. Do not reopen them.
3. Preserve the resolved interfaces from the existing spec. §5 records
   the original design questions, not permission to reopen them.
4. Write `spec.md` in this folder. The draft already beside
   this charter carries the accepted behavior and interfaces. Revise
   the series, introduction points, file scopes, focused tests, and
   verification to match §4.9, preserving the echo rule in §4.8. A
   later checkpoint-manager conversation slices
   **aloemacs-windows 000** under
   `docs/design/implementation/aloemacs/windows/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the parts in §4.9's order, at one implementer conversation per
checkpoint, with no maximum checkpoint count. A mode line, a
second point, a command that splits on its own, or a new Term
chord are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../viewport/`](../viewport/) | The editor stores `scroll-row` and `scroll-col`. `ensure-visible` fits that origin to a rectangle. `frame` paints the text rows at that origin |
| [`../echo/`](../echo/) | The last row is the echo row when `rows >= 2`. The text rectangle is `rows - 1`. One `term write` paints the screen |
| [`../keymap/`](../keymap/) | Commands are values. `execute-command` performs them. `C-x` is the one prefix. A pending command clears the prefix before it runs. Printable keys arrive as one-character strings |
| [`../buffer/`](../buffer/) | A buffer holds one editor and an optional path. The session holds a nonempty zipper. `switch-buffer` cycles. `kill-buffer` removes the current buffer, or replaces the singleton with a fresh untitled buffer. Direct `visit` replaces the current buffer in place |
| [`../minibuffer/`](../minibuffer/) | The prompt occupies the echo row and the cursor while it is active. `switch-buffer` and `kill-buffer` preserve an active prompt |
| [`../prompt-commands/`](../prompt-commands/) | `C-x C-f`, `C-x C-w`, and `C-x b` run find-file, save-as, and select-buffer. Find-file leaves the previous buffer in the zipper |

Layers 1–16 are implemented. This series does not wait for a
runner change and does not edit the runner.

**Why this layer:** the session can hold several buffers and
show one of them. A window is the view that makes two of those
buffers visible at once. Lock is part of the same design so a
later command cannot resize a view the user meant to keep.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **One view matches today.** With a single view, idle keys,
   `C-x C-s`, `C-x C-f`, `C-x C-w`, `C-x b`, direct `visit`,
   `switch-buffer`, `kill-buffer`, search, and the prompt behave
   as they do now. The frame bytes for that single view match
   the current composer. Plain `2`, `3`, `0`, `o`, and `l` still
   insert. `C-x` then an unbound key still changes nothing and
   consumes the key.
2. **Split shows two views of the current buffer.** `C-x 2`
   splits the selected view below. `C-x 3` splits it to the
   right. Both views show that buffer's text. The original view
   stays selected and keeps the cursor. The new view shows the
   same origin and draws no cursor. A one-cell divider lies
   between them. A split that does not fit changes nothing.
3. **Delete and other-window move among views.** `C-x o` selects
   the next view and wraps. `C-x 0` removes the selected view
   and gives its rectangle to the sibling. The last view cannot
   be deleted. Neither command splits a view on its own.
4. **A locked view keeps its rectangle.** `C-x l` toggles the
   selected view's lock. A later split or delete that would
   resize or remove a locked view changes nothing.
5. **Other commands do not rearrange views.** Find-file,
   save-as, select-buffer, `switch-buffer`, and `visit` do not
   split, delete, or resize. The selected view shows whichever
   buffer is current afterward. Killing a buffer retargets a
   view that showed it and does not remove that view.
6. **The echo vocabulary stays three tokens.** Success and
   failure use `""`, `"saved"`, and `"failed"` as §4.8 says.
   The echo row stays one full-width row. The prompt and search
   still use it.
7. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

A mode line is a later exploration. This bar is the no-TTY test.

## 4. Accepted decisions (product behavior closed; packaging revised in 4.9)

### 4.1 Five commands, one tree

The window configuration is a tree of views. A leaf is a view.
An internal node is either a below-split or a right-split of
exactly two children. Startup is one unlocked view showing the
one buffer.

These commands are new constructors of `AloemacsCommand`. The
session executes them through `execute-command`. They are not
arms of `AloemacsEditor.handle-key`.

| Constructor | Exact `name` | Chord | Second key string |
|---|---|---|---|
| `SplitBelow` | `"split-below"` | `C-x 2` | `"2"` |
| `SplitRight` | `"split-right"` | `C-x 3` | `"3"` |
| `DeleteWindow` | `"delete-window"` | `C-x 0` | `"0"` |
| `OtherWindow` | `"other-window"` | `C-x o` | `"o"` |
| `ToggleWindowLock` | `"toggle-window-lock"` | `C-x l` | `"l"` |

`C-x o` is the letter o. `C-x 0` is the digit zero. The second
key is the printable string Term already produces. This series
adds no Term chord and does not edit `host/racket/term.rkt`.

Each command acts on the selected view. Split replaces that
view with a two-child node. Delete removes that view. The other
three commands leave the tree shape unchanged.

### 4.2 A view is not an editor

A view stores three facts: which buffer it shows, the origin
(`scroll-row`, `scroll-col`) it paints, and whether it is
locked. It does not store text, point, mark, undo, path, or a
second `AloemacsEditor`.

Those stay on the buffer. Two views may show the same buffer.
They then share that editor and keep separate origins. The
cursor is drawn in the selected view only.

The selected view's origin is the editor's `scroll-row` and
`scroll-col`. On leaving a view, store the editor's origin onto
that view. On entering a view, make its buffer the zipper's
current buffer and install that view's origin onto the editor.
Do not reorder the zipper to do it.

Visit replaces the current buffer's editor and path and keeps
that buffer's identity. Every view of it sees the new text. The
selected view takes the fresh editor origin. An unselected view
keeps the origin it stored.

Killing the singleton buffer keeps that buffer's identity and
replaces its editor and path, as the buffer spec requires.
Killing any other buffer removes it. Each view that showed it
then shows the buffer `kill-buffer` already selected, and takes
that editor's origin. Kill does not remove a view or change a
rectangle.

`add-buffer`, find-file, select-buffer, and `switch-buffer`
leave every unselected view's buffer and origin alone. After
they return, the selected view shows the zipper's current
buffer.

### 4.3 The frame

The echo row is unchanged: the last terminal row when
`rows >= 2`, full width, one session token, prompt and search
above the path label. Windows divide only the text rectangle.
The runner still calls `ensure-visible` and `frame` with the
terminal size, then one `term write`. This series does not edit
`host/racket/aloemacs-run.rkt`.

A single view produces the same frame bytes as the current
session composer, including the editor's full-screen `frame`
for that text rectangle.

Several views produce one screen: one clear, the joined text
rectangle, the echo row, and one cursor. The session does not
concatenate full editor frames. Each view contributes the same
clipped, safe-celled rows the editor would paint for that
view's rectangle and origin. The selected cursor is that view's
local cursor plus the view's top-left in the text rectangle.
An active prompt still places the cursor on the echo row.

`ensure-visible` fits the selected view only, using that view's
width and height. Unselected views are not fitted. Page motion
therefore uses the selected view's height, because that is the
text-row count `ensure-visible` already stores.

The divider is one cell: `|` in a right-split, `-` in a
below-split, and `+` where those dividers cross. Dividers are
drawn by the session. They are not a mode line and they are not
a second echo.

### 4.4 Split

Split applies only to the selected view's rectangle. Ancestors
and siblings keep their rectangles.

| Condition | Result |
|---|---|
| The selected view is locked | No change. Echo per §4.8 |
| Fewer than 3 cells in the split direction | No change. Echo per §4.8 |
| Otherwise | Replace the selected view with a two-child split. Echo per §4.8 |

The divider takes one cell. The earlier side, top or left,
receives any leftover cell. Each child is at least one cell in
that direction. Both children show the selected buffer, carry
the origin from before the split, and are unlocked. The
original view remains selected and occupies the earlier side.
The new view occupies the later side and is not selected.

After the tree changes, fit the selected view into its new
rectangle. The new view keeps the pre-split origin.

A successful split preserves text, point, undo, mark,
kill-ring, search, prompt, pending prefix, and every other
view's buffer and origin. It does not read or write a file.
A refusal changes nothing, so an active prompt or search
remains. In both cases the stored echo token is §4.8.

### 4.5 Delete and other-window

`other-window` walks the leaves in visit order and wraps. Visit
order is depth-first: the top child before the bottom child,
and the left child before the right child. One view stays put.
The tree does not change.

Entering a different buffer uses the `switch-buffer` session
resets and preserves an active prompt. Those resets clear
search and the pending prefix. The echo token is §4.8: an
active prompt that remains keeps the stored token; with no
active prompt remaining, the token becomes `""`. Entering the
same buffer preserves echo, search, prompt, and the pending
prefix. Text, point, undo, and mark of every buffer stay.

`delete-window` removes the selected view.

| Condition | Result |
|---|---|
| It is the only view | No change. Echo per §4.8 |
| The selected view is locked | No change. Echo per §4.8 |
| Promoting the sibling would resize a locked view | No change. Echo per §4.8 |
| Otherwise | Replace the parent split with the surviving sibling. Echo per §4.8 |

The surviving sibling may be a leaf or a subtree. It takes the
parent's rectangle. Its descendant views keep their relative
layout inside that rectangle. The selected view becomes the
surviving leaf, or the first leaf of the surviving subtree in
the `other-window` order. A buffer change uses the same resets
as `other-window`, including the §4.8 echo rule. A refusal
changes nothing, so an active prompt or search remains. Delete
does not read or write a file and does not change text, point,
undo, or mark.

### 4.6 Lock

`toggle-window-lock` flips the selected view's lock bit and
changes nothing else: tree shape, rectangles, buffers, origins,
echo, search, prompt, and pending prefix. A new session's only
view is unlocked. Both children of a successful split are
unlocked.

Lock protects existence and rectangle. It does not pin the
buffer. Find-file, save-as, select-buffer, `switch-buffer`,
`visit`, and `kill-buffer` may still change what a locked view
shows. They may not change its rectangle or remove it.

The view carries the lock bit from the window-state part. The final
window-lock part adds the command and the key, not a new session field.

### 4.7 What the commands leave alone

No window command starts a prompt, sets quit, or arms a prefix.
Find-file, save-as, select-buffer, direct `visit`,
`switch-buffer`, `kill-buffer`, `add-buffer`, `save`, search,
and the prompt keep their accepted meanings. They preserve the
tree shape and every view's rectangle.

A direct send of a window command obeys the same tree,
selection, and echo rules as a chord that reaches that
command. The send does not cancel an active prompt or exit an
active search first. Its echo token is §4.8. The runner's
arguments, fit-then-frame order, and one `term write` stay.

### 4.8 Echo, in one place

The stored tokens remain `""`, `"saved"`, and `"failed"`.

When a window command runs, the stored echo token follows this
table. A direct send runs on the session as it stands. It does
not cancel an active prompt or exit an active search first. A
key that exits search before the command runs does not leave
that search in place; the command then uses a later row.

| Event | Echo token |
|---|---|
| The command leaves an active prompt in place, or leaves an active search in place | Unchanged |
| Split success, when the first row does not apply | `""` |
| Split or delete refusal, when the first row does not apply | `"failed"` |
| `other-window` or successful delete changes the current buffer, when the first row does not apply | `""` |
| `other-window` or successful delete keeps the current buffer | Unchanged |
| Toggle lock | Unchanged |

The first row is the preservation rule. The later rows apply
only when it does not. Split, successful or refused, preserves
search and prompt, so it keeps the token while either is
active. A refused delete changes nothing, so it keeps the
token while either is active. `other-window` and a successful
delete preserve an active prompt. On a buffer change they clear
search; they write `""` only when no active prompt remains.
The same buffer leaves the token unchanged. Toggle lock leaves
the token unchanged.

Prompt and search continue to paint the echo row while they
are active. This section adds no token and no per-window echo.

### 4.9 Ordered checkpoint parts

| Part, in dependency order | What it proves |
|---|---|
| **Buffer identity** | Stable buffer IDs, allocation and bounded lookup; buffer constructor and fixture migration. Session shape, fitting, frames, and keys stay as today |
| **Window state and synchronization** | View/tree/rectangle/configuration types, the one new session field, session constructor migration, selected-origin mirroring, and existing buffer-operation retargeting. Constructed trees prove state behavior; normal sessions still have one view |
| **Layout, rendering, and fit** | Binary and nominal layout, pure rows at stored origins, safe multi-view composition, dividers, one cursor, selected-only fit, and resize fallback. Constructed trees make this independently testable before commands |
| **Both splits** | `split-below`, `split-right`, `C-x 2`, and `C-x 3`; shared text, pre-split and fitted origins, exact geometry, refusals, and §4.8 echo behavior |
| **Delete and other-window** | `delete-window`, `other-window`, `C-x 0`, and `C-x o`; last-view refusal, sibling promotion, visit-order wrapping, origin handoff, and constructed-lock guards |
| **Window lock** | `toggle-window-lock` and `C-x l`; exact bit-only toggle and user-reachable split/delete protection |

The spec names replacement **aloemacs-windows 000** for buffer identity.
The returned `checkpoints/000-split.md` remains historical and must not
be resumed. No later checkpoint has been issued or implemented.

Each checkpoint must be independently testable and leave the aloemacs
suite green. The window-state part may be split further if it still
does not fit one implementer conversation. Any further separation
preserves this order and adds no behavior. There is no maximum count.
The spec must carry the intermediate contracts, introduction points,
file scopes, focused tests, and verification for the chosen partition.
The manager writes replacement 000 only after spec review, then stops;
human review of each implementation precedes issuing its successor.

## 5. Open questions

These original questions are resolved in the accepted spec. Preserve
their answers and change only their introduction points for §4.9.

1. **The types.** The session field name, the tree and view
   types, and the buffer identity a view stores. Buffer identity
   comes first. The window-state part introduces the only new session
   field and the view's identity, origin, and lock bit together.
2. **The rows.** The helper that paints one view's clipped rows
   at a stored origin. It must not write that origin onto an
   unselected buffer, and a multi-view frame must not call the
   full-screen editor `frame` once per view.
3. **The identity.** How a view names a buffer through
   `add-buffer`, `switch-buffer`, visit-in-place, and
   `kill-buffer`. A derived name is not an identity. A `List`
   index message is not available.
4. **Binding order.** The order of the new `"2"`, `"3"`, `"0"`,
   `"o"`, and `"l"` bindings in `aloemacs-ctrl-x-keymap`. The
   existing `"save"`, `"find"`, `"kill"`, and `"b"` bindings
   stay. The keys are §4.1, whatever the list order is.

## 6. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  the windows
- [`../explorations.md`](../explorations.md) — Band 3 item 9.
  The mode line stays the following exploration
- [`../viewport/spec.md`](../viewport/spec.md) — stored origin
  and `ensure-visible`
- [`../echo/spec.md`](../echo/spec.md) — the echo row and the
  text rectangle above it
- [`../keymap/spec.md`](../keymap/spec.md) — `execute-command`
  and the `C-x` prefix
- [`../buffer/spec.md`](../buffer/spec.md) — the zipper,
  `add-buffer`, `switch-buffer`, `kill-buffer`, and direct
  `visit`
- [`../minibuffer/spec.md`](../minibuffer/spec.md) — the prompt
  on the echo row
- [`../prompt-commands/spec.md`](../prompt-commands/spec.md) —
  find-file, save-as, and select-buffer
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — the session frame and the ctrl-x map
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `frame`, `frame-ansi`, and `ensure-visible`
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — a printable key is already its one-character string
- Legmacs (`/home/dharmatech/src/legmacs`) — a catalog of a
  pure window tree with per-view origins. Do not port its
  weights, atoms, modes, or rendering
- [`SPEC.md`](../../../../../SPEC.md) §9 — the lawful `Option`
  form

`SPEC.md` remains language law. This series does not amend it.
Where an accepted spec describes a single view, the echo row,
the prompt, `visit`, `switch-buffer`, `kill-buffer`, or the
prompt commands, that spec wins for a session whose tree is
still one view. Where this charter describes the tree, split,
delete, other-window, and lock, this charter wins. After the
human accepts `spec.md`, that file is the design authority for
the checkpoint manager and the implementers.

## 7. Non-goals

- A mode line, a per-view status row, or a buffer menu
- `delete-other-windows`, balance, enlarge, shrink, or a saved
  window configuration
- A command that splits, deletes, or resizes because a buffer
  was opened or displayed
- A second editor, point, mark, undo, or kill-ring per view
- Pinning a locked view to one buffer
- Mouse, drag, weights, or a scrollbar
- Faces, highlighting, modes, folding, or `M-x`
- A new Term method, a new Term chord, or a runner argument
- A kernel message, a `SPEC.md` row, a `Text` method, or a
  `List` index
- Mirror, mutation, delegation, or a `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-windows`.
- Checkpoint 000 is spoken **aloemacs-windows 000** and filed
  under the replacement filename named by the revised spec. The old
  `checkpoints/000-split.md` records returned, unimplemented work and
  is not that replacement. Numbers are three digits, start at 000,
  and are never renumbered once issued or implemented; replacing the
  returned, unimplemented 000 is the approved exception. Any further
  window-state separation assigns successive unissued numbers before
  layout and commands. Slugs are lowercase words separated by hyphens.
  The checkpoint manager writes one checkpoint, then stops.
- Intended order: §4.9. 000 first.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md` and
  later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
