# Charter — aloemacs window point

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **a cursor remembered by
each window that is showing a buffer**. The series identity is
**aloemacs-window-point**. The live editor point is the selected
window's cursor. An unselected window keeps the line and column it
had. `C-x o` restores that cursor and that window's origin, and the
existing fit then runs against the restored cursor. An edit, including
undo, moves the selected cursor as it does today and leaves every
other window's stored line, column, and origin on the numbers they
already had. A window remembers a cursor only while it is showing
that buffer. Then **stop**. Do not write checkpoints. Do not
implement.

This effort refuses a cursor that follows inserted or deleted text,
a saved place for a buffer the window is no longer showing, a second
editor, a second mark, a second undo history, and a second kill ring.
Those stay later or out, so this spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-window-point 000** under
   `docs/design/implementation/aloemacs/window-point/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the checkpoint in §4.9. A cursor that moves when
text is inserted above it, or a place remembered after the window
has switched to another buffer, is a defect in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 is implemented. A window is a view of a buffer. Each view stores an origin. `C-x o` stores the departing origin and installs the destination origin. The editor keeps one point. The next `ensure-visible` fits that point into the selected leaf. The accepted windows spec is the law this series amends only as §4 says |
| [`../window-pictures/`](../window-pictures/) | aloemacs-window-pictures 000 is implemented. `AloemacsView` ends with `(picture (Option AloemacsLeafPicture))`. A multi-window frame reuses a leaf's recorded rows when that leaf's recorded inputs are unchanged. This series does not retune that key |
| [`../viewport/`](../viewport/) | `ensure-visible` moves the selected origin until the editor point lies in the selected leaf. It does not move point |
| [`../undo/`](../undo/) | An edit pushes an `UndoFrame` of `(text point scroll-row scroll-col)`. Undo restores those four fields on the editor and leaves the mark as it was |
| [`../kill/`](../kill/) | One mark on the editor. Kill uses that mark and the editor point. The mark is not rebased when text is inserted before it |
| [`../search/`](../search/) | Search is one session cursor. `ctrl-x` during search ends the search, then the prefix runs |

Final human review of windows remains. This series reads that
accepted spec and does not wait for that review. It does not edit
that spec, that charter, or those checkpoints. A defect there that
blocks a per-window cursor stops this spec; the designer reports
it and does not patch the earlier series from here.

Mode line, window bars, idle echo, completion, and completion page
stay out of this series. Do not edit their documents.
Their geometry is already in the program: a tall leaf gives its
last row to the bar, a Below split reserves no divider row and
needs 4 rows, and completion rows shrink the root rectangle. The
designer takes "on screen" and the fit's text rows from that code.
The windows spec's divider arithmetic is not the geometry.

A frame golden already in the tree moves only when this contract
changes the cursor address or which rows a leaf shows. A session
test that proves one shared point across views of one buffer is
rewritten to the per-view rule. The known proof is
[`tests/aloemacs/windows-delete-and-other.rkt`](../../../../../tests/aloemacs/windows-delete-and-other.rkt),
including the test "shared edits and undo use one point and
history across origin handoffs". Fixtures in that file carry each
view's own point. A fixture that leaves a view's point at
`(0, 0)` while its editor point is somewhere else is wrong.

The constructor migration covers every `AloemacsView new` in
`examples/` and `tests/`, including
[`tests/parenthetical-construction/session.rkt`](../../../../../tests/parenthetical-construction/session.rkt),
and the five `AloemacsView` field lists. `point` is inserted after
`scroll-col` and before `locked`. Negative-arity checks move with
that argument.

**Why this layer:** four views of one long file share one editor
point. `buffer-end` in the selected view, then `C-x o`, installs
the next view's saved origin and then `ensure-visible` scrolls
that view until the shared point is on screen. The next view's
memory of the top is discarded. The same sharing leaves two views
a few lines apart on one cursor. Each window needs the cursor it
had, and the fit needs to run after that cursor is restored.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Each visible window has its own cursor.** Two or more views
   of one buffer can hold different lines and columns at the same
   time. The editor's point equals the selected view's cursor on
   every program-returned session. The frame still draws one
   cursor, in the selected leaf, from that editor point. An
   unselected leaf draws no cursor.
2. **`C-x o` restores the window you enter.** After `buffer-end`
   in one view of a buffer that starts at the top, `other-window`
   followed by `ensure-visible` leaves the entered view at its
   former origin and puts the editor point at that view's former
   cursor. The view you left still stores the end. A round trip
   without a further edit restores that end and that view's
   origin. Two views whose cursors are a few lines apart, both
   already on screen, each show the cursor it stored and keep
   their origins.
3. **A split copies the cursor.** The fresh view starts with the
   selected view's point and origin. The two cursors diverge when
   one of them moves.
4. **An edit leaves the other windows on their numbers.** An
   insertion or deletion above another view of the same buffer
   does not change that view's stored line, column, or origin.
   Undo restores the selected view's text, point, and origin from
   the undo frame and does not change the other views' stored
   cursors or origins.
5. **Entry clamps a cursor the text no longer contains.** When
   the stored point fails `valid-position?`, entry moves it
   before the fit. If its line still exists, the column is pulled
   back to that line's length. If its line does not exist, the
   point becomes the end of the last line: that line's index and
   that line's length. The session entry returns already stores
   that adjusted point on the entered view. The fit then runs on
   the adjusted point.
   An unselected view is not clamped and is not scrolled on its
   own. A stored origin past the end still paints as it does
   today until that view is entered.
6. **Leaving a buffer forgets the window's private cursor
   there.** When the selected view's buffer id changes, that view
   takes the arriving editor's point and origin. The buffer just
   left keeps the editor point it had, which is the cursor of the
   window that last had it selected. A view that comes back takes
   that editor point, including when another view of the buffer
   was selected in between and moved. Views that already showed
   the arriving buffer, and whose buffer id does not change, keep
   their own cursors and origins.
7. **Search keeps one cursor.** A same-buffer entry while
   `searching` is true installs the destination origin and stores
   the match on the entered view. The editor point stays on the
   match. Other views of that buffer keep the points they stored.
   The following fit may still change the entered view's origin.
   `ctrl-x` during search still ends the search before the prefix
   runs, so the `o` that follows is an ordinary entry: the window
   you enter shows the cursor it stored, and the window you left
   keeps the match.
8. **The mark stays one position on the buffer.** After
   other-window, kill uses the entered window's cursor and the
   same mark. The mark does not move when text is inserted before
   it.
9. **A person can see both stories.** The spec names two hand
   checks, separate from the no-TTY tests.

   Four columns. From one window on a long file, `C-x 3` three
   times. The cursor starts at the top. `Ctrl-End` in the first
   column, then one `C-x o`. The second column still shows the
   top of the file, with its cursor there. Three more `C-x o`
   presses return to the first column and show the end again.

   Sticky line numbers. `C-x 2` makes a lower view of the same
   buffer, with its cursor a few lines below the upper cursor.
   A newline typed in the upper view, above that lower cursor,
   leaves the lower view's stored line where it was. Entering
   the lower view puts the cursor on the following line's text.

## 4. Locked decisions

### 4.1 Where the cursor lives

`AloemacsEditor` keeps one `point`. That field is the selected
window's cursor. Commands, search, kill, yank, and undo read and
write it. The editor gains no field.

`AloemacsView` gains one field, `(point Position)`, immediately
after `scroll-col` and before `locked`. The picture field stays
last. The startup view in `main.aloe` uses `(Position new 0 0)`.
The selected view's stored point matches the editor point on
every program-returned session, the same way its stored origin
already matches the editor origin.

The view still holds no editor, text, path, mark, history, ring,
or rectangle. There is still one editor per buffer.

### 4.2 The handoff

Save the departing view's live point and origin before the
selection changes. Install the destination view's stored point
and origin on its buffer's editor. §4.5 writes a clamped point
back onto the entered view. §4.6, a same-buffer search entry,
leaves the editor on the match and stores that match on the
entered view. Otherwise the entered view keeps the point it
stored. `ensure-visible` runs after that install, as the runner
already does, and fits the installed point. If that point
already lies in the destination origin and in the leaf, the fit
leaves the origin unchanged.

Same-buffer and different-buffer entry use this install. The
windows rules for echo, search reset, prompt, pending, and the
kill ring stay. Same-buffer entry still preserves search, under
§4.6. Different-buffer entry still applies the windows search
reset, then shows the destination view's cursor.

Delete selects the surviving leaf with this same entry. A round
trip through other-window, with no fit, no edit, and search off,
restores each view's point and origin. A same-buffer round trip
while searching leaves each visited view on the match.

An active prompt does not block the handoff. The prompt cursor
stays on the echo row. The buffer cursor becomes the entered
view's cursor, so leaving the prompt shows that window's place.

### 4.3 Split

The fresh leaf copies the selected view's point and origin at the
moment of the split. Selection stays on the original leaf, as it
does today. Later motion updates the selected view only.

### 4.4 Sticky numbers

Motion and edits update the selected view's stored point when
they update the editor, through the same selected-view write that
already stores the origin. Unselected views keep the point and
origin they last stored.

An insertion, newline, deletion, kill, or yank does not add a
line or column delta to any other view. Undo restores the
selected editor from the undo frame and writes that restored
point and origin onto the selected view only. `UndoFrame` stays
`(text point scroll-row scroll-col)`.

This is the whole adjustment rule. Positions are line and column
numbers, not marks that chase text.

### 4.5 Clamp on entry

Clamp only while entering a view, after reading its stored point
and before `ensure-visible`. Use the buffer text's existing
`valid-position?`. A point that passes is installed unchanged.

A point whose line exists and whose column is past that line's
length is installed at that line and at that line's length. A
point whose line is past the last line is installed at the last
line and at that line's length. Line length is the valid column
one past the last character, the column `valid-position?` already
allows.

Entry writes that installed point onto the entered view before
it returns. The editor point and the entered view's stored point
already match on that session. The fit runs afterward and may
change the origin.

Do not clamp an unselected view while another view is edited,
fitted, or painted. Do not scroll an unselected view to bring its
stored point on screen.

### 4.6 Search

`search-key` is unchanged. A key whose length is not 1, including
`ctrl-x`, still ends the search and then dispatches. The `o`
after that prefix is §4.2's ordinary handoff.

When entry runs while `searching` is true and the destination
buffer id equals the departing id, the editor point stays on the
match. The entered view stores that match. Other views of that
buffer keep the points they stored. The departing view stores
the match, which it already had if search updated the selected
view. Origin handoff and the following fit behave as they do
today, so the entered view may scroll to show the match. Ending
the search writes the editor point onto the selected view and
does not rewrite any other view's stored point.

### 4.7 Buffer identity changes

Switching the selected view to another buffer, finding a file,
and selecting a buffer by name leave the departed buffer's editor
point as the cursor of the window that was selected. The selected
view then stores the arrived editor's point and origin. It does
not keep a cursor for the buffer it stopped showing.

Killing a buffer retargets every view of the killed id onto the
replacement buffer. Each retargeted view takes the replacement
editor's point and origin. A view that already showed the
replacement, and was not retargeted, keeps its point and origin.
Killing the only buffer keeps that buffer's id and replaces its
editor with the empty untitled editor at point `(0, 0)` and
origin `(0, 0)`. Every view of that id is retargeted, and every
one of them takes `(0, 0)`.

A successful visit replaces the selected editor as it does today,
including point `(0, 0)` and origin `(0, 0)`, and writes those
onto the selected view. Other views of that buffer id keep their
stored points and origins. Entering one of them later applies
§4.5.

### 4.8 What this series leaves alone

The frame still paints an unselected leaf from its origin. The
picture match stays buffer id, history length, scroll, rectangle,
name, and selection. Do not add point to that key. Do not change
`record-pictures`, Text, List, or the runner. `ensure-visible`
remains the runner's fit, still before the frame.

The mark, the kill ring, and undo history stay one per buffer.
No goal column is added. `scroll-col` is not given a separate
adjustment rule. Direct editor `frame` stays the one-view frame.

### 4.9 One checkpoint

| Checkpoint | What it proves |
|---|---|
| **aloemacs-window-point 000** | The view stores a point. Split copies it. Other-window and delete restore it before the fit. The four-window end-of-buffer story, the nearby-lines story, sticky numbers across an edit and undo, clamp on entry, the buffer-switch return, the in-search send, the `ctrl-x` search ending, and kill against the one mark all hold. One view still frames and edits as today |

000 includes the constructor threading. A point field that
`C-x o` ignores is not a checkpoint. The manager writes 000
only, then stops.

000 is one checkpoint. The spec adds a later number only when
that conversation would not fit, and only by moving work that
can land after a working handoff. The handoff, the entry clamp,
and the same-buffer search branch stay in the same checkpoint.
A later number introduces no following cursor and no per-buffer
memory on the view. Adding `point` to the selected-view write
that already stores the origin also makes the selected view take
the arrived editor's point on switch, find, and visit.
`retarget-buffer` on kill belongs with that write. It is not a
checkpoint by itself. The spec does not leave a handoff that
restores a cursor and then lets the old shared fit discard the
origin, and it does not leave a handoff that can install an
invalid point or move the search point.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The install send.** The editor send, or the pair of sends,
   that entry uses to replace point and origin together. It
   preserves quit, history, mark, and remembered `text-rows`.
   It does not replace the buffer's characters, fit, or push an
   undo frame. Name it. Say how the entered view stores the
   point entry installed, including a clamped point and the
   match §4.6 stores, on the same path that already writes the
   origin. Say where the Text zipper's focus sits after entry.
   A focus left on the departed line makes `valid-position?` and
   the entered leaf's rebuild each walk from that line to the
   entered line. The spec chooses the focus on purpose. A moved
   focus is a different Text value, and session equality will
   see it.
2. **Where clamp is spelled.** An editor send or a session
   helper, using `valid-position?` and the current line's length.
   No new `Text` method. Show one point whose column is past the
   line and one whose line is past the end.

## 6. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  the window point
- [`../windows/spec.md`](../windows/spec.md) — the view, the
  origin handoff, split, delete, other-window, visit, kill, and
  selected-only fit. §4 of this charter supersedes only that
  spec's rule that every view of a buffer shares one point, and
  only for the stored per-view cursor described here. One
  editor, one mark, one history, and one ring remain. Do not
  amend that spec
- [`../window-pictures/checkpoints/000-reuse-leaf-rows.md`](../window-pictures/checkpoints/000-reuse-leaf-rows.md)
  — the picture field and the reuse key. This series threads the
  new view field through constructors and does not change the key
- [`../undo/spec.md`](../undo/spec.md) — the undo frame and the
  selected editor's restored point and origin
- [`../kill/spec.md`](../kill/spec.md) — one mark, no rebasing
- [`../search/spec.md`](../search/spec.md) — one search cursor,
  and which keys end the search
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `AloemacsView`, `with-view-buffer`, `enter-view`,
  `other-window`, and `ensure-visible`
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `point`, `with-origin`, `ensure-visible`, `from-edit`, and
  `undo`
- Legmacs at `/home/dharmatech/src/legmacs` (`legmacs/windows.lg`,
  `legmacs/buffers.lg`, `legmacs/render.lg`) and `e` at
  `/home/dharmatech/src/e` (`lib/head/head.sls`,
  `lib/foundation/text.sls`) — seam catalogs. Legmacs supplies
  the per-window cursor and scroll, laid over one buffer and
  folded back on the way out, with other windows left on their
  line and column and clamped only back into the text. `e`
  supplies a cursor stored on the window. Its delta rebase, its
  mark rebase, and its single saved spot for a hidden buffer
  supply no requirement

`SPEC.md` remains language law. This series does not amend it.
The accepted windows spec remains the authority for the tree,
the origin handoff, the commands, and echo. Fit rows, the mode
line bar, and completion rows are whatever the current program
does. The windows spec's divider arithmetic is not that
geometry. This charter is the authority for the per-view cursor.
After the human accepts `spec.md`, that file is the design
authority for the checkpoint manager and the implementers.

## 7. Non-goals

- Moving an unselected cursor or origin when text is inserted or
  deleted above it
- Remembering a cursor for a buffer the window is no longer
  showing
- A second editor, mark, undo history, or kill ring per view
- Rebasing the mark
- A goal column
- Clamping or scrolling a window that is not being entered
- A cursor drawn in an unselected window
- A change to which keys end search, or a second search cursor
- A change to the picture reuse key, `record-pictures`, Text,
  List, `UndoFrame`, or the runner
- A new key, a new command, or a new Term method
- Implementing mode line, window bars, idle echo, completion, or
  completion page
- A kernel message, a `SPEC.md` row, or a `Text` method
- Mirror, mutation, or delegation
- A `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-window-point`.
- Checkpoint 000 is spoken **aloemacs-window-point 000** and
  filed as `checkpoints/000-window-point.md`. Numbers are three
  digits, start at 000, and are never renumbered. The slug is
  lowercase words separated by hyphens. The checkpoint manager
  writes one checkpoint, then stops.
- Intended order: §4.9. 000 first. A later number exists only
  for the size split §4.9 allows.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. New tests stay in
  `tests/aloemacs/`. The constructor migration also edits
  `tests/parenthetical-construction/session.rkt` and every
  `AloemacsView` constructor and field list already in
  `tests/`. The spec names the focused test file, names
  `tests/aloemacs/windows-delete-and-other.rkt` as a proof to
  rewrite, and names the standing command
  `TMPDIR=/tmp raco test -j 4 -y`. The design folder receives
  `spec.md` and later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
