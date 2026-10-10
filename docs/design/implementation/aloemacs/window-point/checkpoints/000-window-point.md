# aloemacs-window-point 000 — Per-window point

**Status: Ready to implement.** Human review of this checkpoint precedes
its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice, and
stop when green.

## Goal

Give each window its own cursor in the buffer it shows.

- `AloemacsView` stores a `point` after `scroll-col`.
- The editor still has one `point`. It is the selected window's cursor.
- `C-x o` and `C-x 0` install the entered window's stored point and
  origin on its buffer's editor before the runner's next fit. A stored
  point the text no longer contains is clamped on entry.
- A split copies the live point to both leaves.
- An edit, including undo, moves only the selected window's cursor.
  Every other window keeps the line and column it stored.
- A window that changes buffer takes the arriving editor's point.
  Kill retargets every view of the killed buffer to the replacement's
  point.

One view frames and edits byte for byte as today. Migrate the existing
constructors, fixtures, and the frame goldens listed below. This
checkpoint is the whole series. Stop when the focused proof and the
aloemacs suite pass.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec. The
checkpoint narrows the spec to one slice and adds the test inventory
the spec left to the manager. It does not revise the spec.

- Identity: **aloemacs-window-point 000**, filed as
  `checkpoints/000-window-point.md`. This is a local editor checkpoint.
  It takes no global number and gets no `CHECKPOINTS.md` entry. There
  is no 001.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product
  edits. `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`. No
  mutation, macros, inheritance, or new special forms.
- The accepted [../spec.md](../spec.md) governs all of this slice:
  - §1: predecessors and authority. §1.2 names the exact sentences of
    the windows spec this series supersedes. Do not edit that spec.
  - §2: the file boundary.
  - §3: the view field and the invariant.
  - §4: `install`, its clamp, its Text focus, and the §4.4 table.
  - §5: entry, the search branch, the prompt, the fit afterward, and
    the §5.6 examples.
  - §6: the selected-view write, split, buffer identity, kill, visit,
    what does not move, and the §6.5 examples.
  - §7: the frame is unchanged.
  - §8: migration rules. This checkpoint adds the inventory below.
  - §9: the focused proof.
  - §10: verification, hand checks, and the acceptance list.
- Predecessor specs named in spec §1.1 govern every behavior this
  series does not change, especially
  [windows/spec.md](../../windows/spec.md) for the tree, selection
  order, split, delete, lock, echo, and the buffer-ID resets, and
  [window-pictures 000](../../window-pictures/checkpoints/000-reuse-leaf-rows.md)
  for the picture field and its key.

### Current tree

Start from these places. Line numbers are approximate.

- [editor.aloe](../../../../../../examples/aloemacs/editor.aloe):
  `with-origin` (line 26) sets only the two origin fields.
  `with-text-and-point` (line 132) sets only `text` and `point`.
  `focus-end (focused Text)` (line 301) walks a Text down to its last
  line. Text already has `focus-at`, `indexed-value`, `focus-line`,
  `line-length`, and `valid-position?`.
- [file.aloe](../../../../../../examples/aloemacs/file.aloe):
  - `AloemacsView` (line 307) has `id`, `buffer-id`, `scroll-row`,
    `scroll-col`, `locked`, `picture`. No product code calls
    `AloemacsView new`. Every leaf update is a `view with` update.
  - `AloemacsWindowTree`: `with-split` (line 457) takes
    `id fresh-id scroll-row scroll-col below?` and builds both leaves
    with `view with`. `with-view-buffer` (line 497) writes `id`,
    `buffer-id`, `scroll-row`, `scroll-col` on the leaf with that id.
    `retarget-buffer` (line 522) takes
    `removed-id buffer-id scroll-row scroll-col` and rewrites every leaf
    whose `buffer-id` is `removed-id`.
  - `AloemacsWindows`: `with-split (scroll-row scroll-col below?)`
    (line 774), `with-buffer` (line 790) sends `with-view-buffer` for
    the selected id, `without-buffer (removed-id replacement)`
    (line 793) captures the replacement editor once and sends
    `retarget-buffer`.
  - Session `split-window` (line 1274) captures `(self editor)` and
    passes its origin to `with-split`, then fits once.
  - Session `enter-view` (line 1289) installs the view's origin through
    editor `with-origin`, applies the buffer-ID reset fields, and sets
    the tree and `selected`. It does not send `with-buffer`.
  - Session `other-window` (line 1314) and `delete-window` (line 1329)
    send `(windows with-buffer (self current-buffer))` before changing
    selection, then call `enter-view`.
  - `with-editor`, `with-kill-state`, `with-search`,
    `selected-buffers`, and `visited` already send `with-buffer`.
    `kill-buffer` sends `without-buffer`.
- [main.aloe](../../../../../../examples/aloemacs/main.aloe): the
  startup view is `(AloemacsView new 0 0 0 0 #f (Option None))`.
- The runner in `host/racket/aloemacs-run.rkt` fits, records pictures,
  writes the frame, then reads and handles one key. It stays unchanged.

At issuance, `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
tests/parenthetical-construction` passes 584 tests in about 47 s. The
window-pictures medians were 2.4, 23.5, and 15.2 ms. `git status` is
clean.

### Size

The manager did not run a scratch copy. The test inventory below comes
from reading the tests.

- 107 `AloemacsView new` sites in 37 test files, most of them inside a
  few helpers per file (`leaf`, `views`, `selected-views`,
  `removed-views`, and the one-view session builders).
- Five exact field lists.
- Four frame goldens move. They are listed below.
- Session expectations in about ten files change because the selected
  view now carries the point after a send that moves it, or because an
  entered buffer's Text is refocused.

That is the same order of work as window-pictures 000, which threaded
one constructor argument through every test in one conversation. If you
cannot finish in this conversation, stop and report which files remain.
Do not split the slice or write 001.

## Exact file scope

### May create or edit

- `examples/aloemacs/editor.aloe`: add `install` beside `with-origin`.
  Nothing else.
- `examples/aloemacs/file.aloe`, only in these places:
  1. `AloemacsView`: the `point` field.
  2. `AloemacsWindowTree`: `with-split`, `with-view-buffer`,
     `retarget-buffer`.
  3. `AloemacsWindows`: `with-split`, `without-buffer`.
  4. Session `split-window` and `enter-view`.

  Update the comments next to those methods so they say point and
  origin where they say origin.
- `examples/aloemacs/main.aloe`: the startup view only.
- Create `tests/aloemacs/window-point.rkt` before the product edit, and
  watch it fail.
- Existing files under `tests/aloemacs/` and
  `tests/parenthetical-construction/`, only under the migration rules
  in this checkpoint.

### Must leave untouched

- `lib/` (Text, List, String, Option), `aloe/`, `host/` including the
  runner, `SPEC.md`, `CHECKPOINTS.md`, `archive/`
- Every document under `docs/`, including this checkpoint, the spec,
  this folder's `README.md`, and the parent aloemacs map
- The code of `UndoFrame`, `AloemacsLeafPicture`, `record-pictures`,
  `frame`, `multi-frame`, `single-frame`, `frame-rows`,
  `ensure-visible`, `other-window`, `delete-window`, and editor
  `with-origin`
- Every file not listed under **May create or edit**

Add no key, command, Term method, kernel message, `SPEC.md` row, or
Text method. Add no session helper for the clamp. Do not rebuild a leaf
with `AloemacsView new`; that drops its picture.

If another file or method is necessary, stop and send this checkpoint
back. Do not widen the slice.

## Required behavior

### The view field (spec §3.1)

`AloemacsView` has exactly these ordered fields and still no methods:

```aloe
(id Int)
(buffer-id Int)
(scroll-row Int)
(scroll-col Int)
(point Position)
(locked Bool)
(picture (Option AloemacsLeafPicture))
```

Construction is
`(AloemacsView new id buffer-id scroll-row scroll-col point locked picture)`.
The startup view in `main.aloe` is:

```aloe
(AloemacsView new 0 0 0 0 (Position new 0 0) #f (Option None))
```

`AloemacsEditor` gains no field. There is still one editor per buffer.

### Editor `install` (spec §4)

Add to `AloemacsEditor`, beside `with-origin`:

```aloe
;; Clamp a stored window point into this text and focus its line.
(install (point Position) (scroll-row Int) (scroll-col Int) AloemacsEditor
  (let ((focused
          (((self text) focus-at (point line)) case
            (Some (focused) focused)
            (None () (self focus-end ((self text) indexed-value))))))
    ((self with-text-and-point focused
       (if (focused valid-position? point)
           point
           (Position new (focused focus-line) (focused line-length))))
     with-origin scroll-row scroll-col)))
```

You may rearrange it. The result, the focus, and the use of
`valid-position?` on the focused Text are fixed:

- The Text keeps its characters and is focused on the installed line:
  the stored line when it exists, otherwise the last line. When the
  focus is already there, `focus-at` returns the same Text value. A
  `from-string` Text becomes its `indexed` value.
- A point that passes `valid-position?` is installed unchanged. A point
  whose line exists but whose column is past the end installs that line
  at its `line-length`. A point whose line is past the last line
  installs the last line at its `line-length`.
- `scroll-row` and `scroll-col` are the given origin, not fitted, not
  clamped.
- `quit`, `history`, `mark`, and `text-rows` are exactly the
  receiver's. No undo frame is pushed. The mark is not touched.

The spec §4.4 table is the exact expectation, with the editor whose
Text is `"alpha"`, `"be"`, `"c"` focused on line 0:

| Send | Point | Text focus | Origin |
|---|---|---|---|
| `install (0, 5) 1 2` | `(0, 5)` | line 0, the same Text value | `(1, 2)` |
| `install (2, 0) 0 0` | `(2, 0)` | line 2 | `(0, 0)` |
| `install (1, 4) 0 0` | `(1, 2)` | line 1 | `(0, 0)` |
| `install (7, 1) 0 0` | `(2, 1)` | line 2 | `(0, 0)` |
| `install (0, 0) 40 50` | `(0, 0)` | line 0 | `(40, 50)` |

### The selected-view write (spec §6.1)

The `with-view-buffer` leaf arm writes one more field, still in the
same `view with` update:

```aloe
(view with
  (id id)
  (buffer-id (buffer id))
  (scroll-row (editor scroll-row))
  (scroll-col (editor scroll-col))
  (point (editor point)))
```

Its signature and `AloemacsWindows with-buffer` stay as they are. Every
session path that already sends `with-buffer` now stores the editor
point on the selected view with the origin: `with-editor` (insert,
newline, backward-delete, every motion, undo, request-quit,
`ensure-visible`), `with-kill-state`, `with-search` (find, every search
key, `end-search`), `selected-buffers` (switch-buffer, both
`add-buffer` arities, find-file reuse, select-buffer), and `visited`.
Unselected views keep what they stored.

### Split (spec §6.2)

```text
AloemacsWindows with-split(scroll-row, scroll-col, point, below?)
AloemacsWindowTree with-split(id, fresh-id, scroll-row, scroll-col, point, below?)
```

`point` is a `Position` and sits after `scroll-col`. Both new leaves
take `(point point)` in the `view with` update each already uses. The
recursive arms pass it through. `split-window` passes `(editor point)`
beside `(editor scroll-row)` and `(editor scroll-col)`. Selection stays
on the original leaf, and the post-split fit writes only the original.

### Kill (spec §6.3)

```text
AloemacsWindowTree retarget-buffer(removed-id, buffer-id, scroll-row, scroll-col, point)
```

Every leaf whose `buffer-id` is `removed-id`, selected or not, takes
the replacement's id, origin, and `(point point)` in its existing
`view with` update. The recursive arms pass it through.
`AloemacsWindows without-buffer` keeps its signature and passes
`(editor point)` from the replacement editor it already captures once.
A view that already showed the replacement keeps its own point and
origin. Killing the only buffer keeps its id and installs the empty
untitled editor, so every view of it ends at `(0, 0)` and origin
`(0, 0)`.

### Entry (spec §5)

`other-window` and `delete-window` keep their code. Their existing
`with-buffer` send now stores the departing view's live point with its
origin. The departing buffer's editor is not touched.

`enter-view(tree, view)` keeps its signature and its `find-id` lookup,
and its `None` arm still returns `self`. For the found buffer:

1. Choose the point. When the destination buffer id equals the current
   buffer's id **and** `searching` is true, it is the destination
   editor's own point, the match. Otherwise it is `(view point)`.
2. Replace that buffer's editor with
   `(editor install chosen (view scroll-row) (view scroll-col))`.
3. Focus the buffer zipper on that buffer, as today.
4. Keep today's echo, searching, query, origin, wrapped, failing, and
   pending rules for same-buffer and different-buffer entry.
5. Set the windows' tree and `selected` to the entered view, then send
   `with-buffer` with the buffer that holds the installed editor.

```aloe
;; The callers store the departing live point and origin before changing
;; selection. Entry installs the entered view's place, stores it on that
;; view, and applies the buffer-ID reset fields.
(enter-view (tree AloemacsWindowTree) (view AloemacsView) (AloemacsSession H)
  (((self buffers) find-id (view buffer-id)) case
    (None () self)
    (Some (focused)
      (let ((same-buffer? (((self current-buffer) id) = (view buffer-id)))
            (buffer (focused current-buffer)))
        (let ((entered
                (buffer with-editor
                  ((buffer editor) install
                    ;; A same-buffer entry during search keeps the match.
                    (if (if same-buffer? (self searching) #f)
                        ((buffer editor) point)
                        (view point))
                    (view scroll-row) (view scroll-col)))))
          (self with
            (buffers (focused with-current-buffer entered))
            ;; echo, searching, query, origin, wrapped, failing, pending: as today
            (windows
              (((self windows) with (tree tree) (selected (view id)))
               with-buffer entered))))))))
```

Entry does not fit. The `with-buffer` in step 5 stores the installed
point on the entered view, including a clamped point or a search match.
The origin it writes is the one just installed. When the installed
point equals the stored point, the entered view does not change.

A key whose length is not 1, including `ctrl-x`, still ends a search
before it dispatches, so `C-x o` during search is an ordinary entry.
Only a direct session send enters while `searching` is true. An active
prompt does not block a direct entry; the frame cursor stays on the
echo row while the prompt is active.

### Invariant and what does not move (spec §3.2, §6.4, §7)

On every session a program send returns, the selected view's `point`,
`scroll-row`, `scroll-col`, and `buffer-id` equal the current editor's
point and origin and the current buffer's id.

- No edit adds a line or column delta to any other view.
- Undo restores the selected editor from its frame, including a point
  and origin recorded while another view was selected, and writes them
  onto the selected view only. `UndoFrame` is unchanged.
- An unselected view is never clamped, fitted, or scrolled. It may
  store a point its text no longer contains.
- The mark, kill ring, and history stay one per buffer. The mark is not
  rebased. There is no goal column.
- The picture key is unchanged. Point is not part of it.
- Painting is unchanged. One cursor is drawn, in the selected leaf,
  from the editor point.

## Test migration (spec §8)

Every changed expectation must follow from one of these rules. If an
existing test fails for a reason none of them explains, the product is
wrong. Fix the product. Do not edit that expectation.

1. **Constructors.** Every `AloemacsView new` takes the point after
   `scroll-col` and before `locked`. A helper that builds leaves gains
   the argument once, inside the helper. The one-view session builders
   that spell `(AloemacsView new 0 (buffer id) ((buffer editor)
   scroll-row) ((buffer editor) scroll-col) …)` pass
   `((buffer editor) point)`. `archive/` and `docs/` are not edited.
2. **Field lists.** Insert `(point Position)` after `(scroll-col Int)`
   in the five `AloemacsView` field lists:
   `window-bars-one-view.rkt`, `windows-layout-and-rendering.rkt`,
   `mode-line-row.rkt`, `windows-state-foundation.rkt`, and
   `windows-state.rkt`. In
   `tests/parenthetical-construction/session.rkt`, add the startup
   view's point to the positional fixture and check that its line and
   column are 0.
3. **Negative checks.** Six arguments to `AloemacsView new` are too
   few, eight too many, and a non-`Position` fifth argument is a type
   error. Update the bad-constructor list in
   `windows-state-foundation.rkt` (near line 188) to say so. The two
   picture checks in `window-pictures.rkt` (near line 219) keep their
   meaning with a point in place: a missing picture and an `Int`
   picture are still rejected. In `windows-state.rkt` (near lines
   176–193), `retarget-buffer` takes five arguments; four is too few,
   six too many, and a non-`Position` fifth argument is rejected.
4. **Fixture points.** When the migration adds a point to an existing
   fixture view, the view stores its buffer's editor point in that
   fixture. A view whose buffer id names no buffer stores `(0, 0)`. A
   helper may default the point only where every caller's buffer point
   is that default. Pass it explicitly everywhere else.
5. **The selected view after a send.** An expected selected view
   carries the point these rules give it. A `rebuild` that keeps the
   source session's `windows` after a send that moves the editor point
   now names the selected view's new point. Known places:
   `windows-split.rkt` (`edited` after the insert) and
   `windows-lock.rkt` ("locked edits, undo, scrolling, fit and resize…":
   the insert, `page-up`, and `page-down`). The same `rebuild` shape
   follows search keys, kill, yank, `with-editor`, `with-search`, and
   `with-kill-state` sends in `windows-state.rkt`,
   `windows-state-foundation.rkt`, `windows-buffer-identity.rkt`,
   `buffer-session.rkt`, `minibuffer-session.rkt`, and
   `minibuffer-value.rkt`. Each of those changes only when its send
   moves the editor point. A send that does not move the point, such as
   a rename, a save, `set-mark`, or a prompt key, changes nothing here.
6. **Split.** A split's fresh view holds the point from the moment of
   the split. The `find-view 8` expectation in `windows-split.rkt`
   (near line 434) becomes
   `(AloemacsView new 8 41 1 1 (Position new 3 2) #f (Option None))`.
   The `find-view 8` expectation in `mode-line-split-views.rkt` (near
   line 339) takes `(Position new 3 2)` too, the raw editor's point.
7. **Text focus after entry.** The entered buffer's expected Text is
   focused on the installed line. Buffers that were not entered keep
   their Text exactly. Either expect the refocused Text, or move the
   fixture's focus to the point's line where the test is not about
   focus. Known places:
   - `windows-delete-and-other.rkt`: "singleton preserves complete raw
     state…" (point line 1, fixture focus 2, also after the return
     entry), "mixed tree order and zipper order differ…" (each entered
     buffer moves from focus 2 to line 1), "delete each side of either
     orientation…" (buffer 12 at point line 2, fixture focus 1, when
     the survivor shows 12), and "nested deletion promotes only the
     immediate sibling…" (buffer 12 at point line 0, fixture focus 1).
   - `windows-lock.rkt`: "public locks survive selected-only
     retargeting…" (buffer 12 at point `(1, 1)`, fixture focus 0, after
     the cycle enters view 40).
8. **Proof rewritten.** In `windows-delete-and-other.rkt`, the test
   "shared edits and undo use one point and history across origin
   handoffs" becomes the per-view rule. Rename it to say so. Both views
   store `(0, 1)` in the migrated fixture:

   | Step | Editor point, origin | View 7 | View 3 |
   |---|---|---|---|
   | `other-window` | `(0, 1)`, `(1, 1)` | `(0, 1)`, `(0, 0)` | `(0, 1)`, `(1, 1)` |
   | `insert "X"` | `(0, 2)`, `(1, 1)` | `(0, 1)`, `(0, 0)` | `(0, 2)`, `(1, 1)` |
   | `other-window` | `(0, 1)`, `(0, 0)` | `(0, 1)`, `(0, 0)` | `(0, 2)`, `(1, 1)` |
   | `undo` | `(0, 1)`, `(1, 1)` | `(0, 1)`, `(1, 1)` | `(0, 2)`, `(1, 1)` |

   The text and history expectations stay. Edits and undo are still
   shared.
9. **Other expected views.** `window-pictures.rkt`, "a skipped record
   drops pictures before a later split copies them": the surviving leaf
   is `(AloemacsView new 1 <id> 0 0 (Position new 0 1) #f (Option None))`.
   The survivor stored `(0, 1)` at the split after the insert. In
   `windows-lock.rkt`, "public locks survive…", the views of 41 that
   switch, select, or are retargeted to buffer 12 take 12's point
   `(1, 1)`. View 40 keeps its own. Killing the only buffer puts every
   view of it at `(0, 0)`.

### Frame goldens

Exactly these four frame expectations move. Each moves because the
entered window now installs its own stored point. Any other golden
change is a product defect. Do not edit those bytes.

1. `windows-delete-and-other.rkt`, the rewritten shared-edits test: the
   fitted paint after the second `other-window` keeps its rows. Its
   cursor moves from row 1 column 3 to row 1 column 2.
2. `windows-delete-and-other.rkt`, "production runner: split, select a
   different rectangle, edit, delete, resize and quit": view 0 stored
   `(0, 0)` when `C-x o` left it. `C-x 0` enters it there. The last
   frame is `(single '("xabc" "def" "" "" "") 1 1 6 "" …)` instead of
   `1 2`. In the direct-state loop, the point check is `(0, 1)` only at
   frames 5 and 6 and `(0, 0)` at frame 7. The selection check is
   unchanged.
3. `mode-line-split-views.rkt`, "production runner
   splits/selects/edits/saves/prompts/deletes/resizes and quits": the
   last frame is `(single "Xabc\r\ndef\r\n\r\n" 1 1 9 6 "/cwd/a" "")`
   instead of `1 2`.
4. `window-bars-split.rkt`, "the production runner splits, selects,
   edits, prompts, saves, deletes, resizes and quits": the last frame
   is `(multi deleted 1 1 9 6 "")` instead of `1 2`.

`windows-lock.rkt`'s runner and every other entry in the existing tests
install the point the editor already had, so their frames do not move.
`completion-page-session.rkt`'s `(tail other-window)` compares only
the prompt.

## Focused proof: `tests/aloemacs/window-point.rkt`

Write it first and watch it fail. Use the conventions of
`tests/aloemacs/windows-delete-and-other.rkt`: a checked driver,
`examples/aloemacs/main.aloe` loaded, the filesystem double injected,
raw constructors for expected values, and no TTY. Product sends never
build an expected value.

Unless a case says otherwise, the session is 80 by 24 with a 100-line
buffer whose lines are `"line 0"` … `"line 99"`, joined with `"\n"`,
shown by one view with id 0 at point `(0, 0)` and origin `(0, 0)`, and
fitted once with `ensure-visible 80 24`. No completion rows are
showing, so the root text rectangle is `(0, 0, 80, 23)`.

1. **Types.** `AloemacsView`'s seven ordered fields. `install` is
   `(Position Int Int) -> AloemacsEditor` and rejects missing, extra,
   and wrongly typed arguments, and a non-editor receiver. The new
   `with-split` arities on the tree and on `AloemacsWindows`, and the
   five-argument `retarget-buffer`, with their wrong arities and a
   non-`Position` point rejected.
2. **`install`.** The table above, each row against a raw expected
   editor with origin `(4, 5)`, `quit` `#t`, a non-empty history, mark
   `Some (0, 1)`, and `text-rows` 9. Check the characters, `quit`,
   history, mark, and `text-rows` are the receiver's in every row. Add
   one `from-string` receiver: its installed Text is the `indexed`
   value focused on the installed line.
3. **Four columns** (spec §5.6). `split-right` three times. Visit order
   is views 0, 3, 2, 1, with rectangles `(0, 0, 10, 23)`,
   `(11, 0, 9, 23)`, `(21, 0, 19, 23)`, `(41, 0, 39, 23)`.
   - `buffer-end`, then `ensure-visible 80 24`: point `(99, 7)`, view 0
     origin `(78, 0)`.
   - `other-window`: selected view 3, editor point `(0, 0)`, origin
     `(0, 0)`. View 0 still stores `(99, 7)` and `(78, 0)`.
   - `ensure-visible 80 24` changes nothing. The frame ends with the
     cursor `ESC[1;12H`. View 3's first row is `"line 0"` padded to
     nine cells.
   - `other-window` and `ensure-visible` three more times: views 2 and
     1 show the top with point `(0, 0)`. Back on view 0, point
     `(99, 7)`, origin `(78, 0)`, cursor `ESC[22;8H`.
4. **Nearby lines** (spec §5.6). `split-below`: view 0
   `(0, 0, 80, 12)`, view 1 `(0, 12, 80, 11)`. `other-window`,
   `move-down` three times: view 1 at `(3, 0)`. `other-window`: view 0
   at `(0, 0)`, origin `(0, 0)`, cursor `ESC[1;1H`; view 1 stores
   `(3, 0)` and `(0, 0)`. `other-window`: view 1 at `(3, 0)`, origin
   `(0, 0)`, cursor `ESC[16;1H`. Each fit along the way leaves point,
   origin, Text, and both views unchanged, and records that leaf's
   text-row count, 11 on view 0 and 10 on view 1.
5. **Sticky numbers** (spec §6.5). From the nearby-lines layout with
   view 0 selected: `newline` puts view 0 at `(1, 0)`; view 1 still
   stores `(3, 0)` and `(0, 0)`, and its painted rows begin `""`,
   `"line 0"`, `"line 1"`, `"line 2"`. `other-window`: the point is
   `(3, 0)`, on `"line 2"`, cursor `ESC[16;1H`. `undo` in view 1: text
   restored, point and origin `(0, 0)` and `(0, 0)` from the frame view
   0's newline recorded; view 1 stores them; view 0 still stores
   `(1, 0)`. Separately, `backward-delete` at the start of a line in
   view 0 joins two lines and leaves view 1's stored line and column
   unchanged.
6. **Clamp on entry** (spec §6.5). A buffer `"abc"`, `"defgh"`,
   `"ij"` in two views from `split-below`.
   - View 1 stores `(1, 5)`. In view 0 at `(1, 0)`, `kill-line` leaves
     line 1 `""`. While view 0 is selected, view 1 still stores `(1, 5)`
     and its origin, and its painted rows are those of that origin.
     `other-window`: the returned session's editor point and view 1's
     stored point are both `(1, 0)`, before any fit.
   - View 1 stores `(2, 2)`. In view 0 at `(1, 5)`, `kill-line` joins
     the lines into `"abc"`, `"defghij"`. `other-window`: the point is
     `(1, 7)` and the Text is focused on line 1, before any fit.
7. **Split.** `split-below` and `split-right` each copy the point and
   origin to the fresh leaf. After `move-down` in one view, the two
   stored points differ.
8. **Delete.** Deleting the selected view enters the survivor at its
   stored point and origin, once where the survivor shows the same
   buffer and once where it shows a different buffer.
9. **Buffer identity.**
   - The spec §6.5 buffer-switch return: buffers A (the 100-line
     buffer) and B, two views of A from `split-below`. View 0
     `move-down` five times, `switch-buffer`: view 0 shows B at B's
     point and origin, A's editor keeps `(5, 0)`. `other-window` into
     view 1: `(0, 0)`, then `move-down` twice: `(2, 0)`.
     `other-window` into view 0: B's stored point. `switch-buffer` back
     to A: view 0 takes `(2, 0)`, not `(5, 0)`; view 1 still stores
     `(2, 0)`.
   - `select-buffer-submitted` and find-file reuse take the arriving
     editor's point on the selected view.
   - `visited` writes `(0, 0)` on the selected view and leaves other
     views of that id on their stored points. Entering one of them
     afterwards clamps.
   - `kill-buffer` retargets every view of the killed id to the
     replacement's point and origin, and leaves a view that already
     showed the replacement on its own point and origin. Killing the
     only buffer puts every view of it at `(0, 0)`.
10. **Search** (spec §6.5). Two views from `split-below`, view 1
    storing `(4, 0)`. In view 0: `find`, then `n`, `e`, space, `2`. The
    match is `(2, 2)`.
    - A direct `other-window` send: `searching` stays `#t`, query
      `"ne 2"`, editor point `(2, 2)`, both views store `(2, 2)`. A
      third view of the buffer keeps its own point.
    - Instead, `handle-key "ctrl-x"`, then `handle-key "o"`: the search
      ends with view 0 storing `(2, 2)`, then entry installs view 1's
      `(4, 0)`.
11. **Mark** (spec §6.5). Nearby-lines layout, view 0 at `(0, 1)`:
    `set-mark`, `other-window` into view 1 at `(3, 0)`, `kill`. The
    ring's head is `"ine 0\nline 1\nline 2\n"`. Separately, with the
    mark at `(2, 0)`, inserting at `(0, 0)` in either view leaves the
    mark at `(2, 0)`.
12. **Prompt.** Two views with different stored points, a prompt
    active. A direct `other-window` installs the entered view's point.
    The frame cursor stays on the echo row. After `escape` the frame
    cursor is at the entered window's place.
13. **One view.** A one-view session's frames and edits match a
    session built the same way before this slice: compare frame bytes
    after a few edits and motions to fixed expected strings. The view's
    point follows the editor point after each send.
14. **Invariant.** After every program step in this file, the selected
    view's point and origin equal the editor's, and its buffer id is
    the current buffer's id. Use one helper for this check.
15. **Runner.** `run-aloemacs-with-hosts` with a Term double at 80 by
    24 and the 100-line file, as the production-runner tests in
    `mode-line-split-views.rkt` drive it. Keys: `ctrl-x` `3` three
    times, `buffer-end`, `ctrl-x` `o`, `escape`. The frame written
    after `o` shows `"line 0"` at the top of the second column, with
    the cursor at `ESC[1;12H`. The runner code is unchanged.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-point.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/windows-delete-and-other.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction
git diff --check
```

The aloemacs suite, including the window-pictures timing bar, is the
regression bar. Report the test count and the three printed medians. Do
not commit `compiled/`. Product edits are `.aloe` only and need no
rebuild before launch.

The human reviewer runs the two hand checks in spec §10 on a real TTY.
The implementer does not need a TTY.

Stop when green. Do not write 001. Do not edit the README or the map.

## Non-goals

- A view `point` that follows edits made in another view, a mark that
  chases text, or a goal column
- Clamping, fitting, or scrolling an unselected view
- A second editor per view, or a per-view mark, kill ring, or history
- Adding point to the picture key or to `UndoFrame`
- Drawing a cursor in an unselected leaf
- A new key, command, Text method, Term method, or `SPEC.md` row
- Changing the runner, `ensure-visible`, `other-window`,
  `delete-window`, or the frame code
- Tuning the rare double walk when a stored line is past the end
