# aloemacs window-point specification

**Status: Draft for human review.** Written by the designer
conversation from [`charter.md`](charter.md). After the human accepts
it, this file is the complete design input for the
**aloemacs-window-point** checkpoint manager and implementer. They do
not need the charter or the design conversation. This is application
design; [`SPEC.md`](../../../../../SPEC.md) remains Aloe language law,
and [`docs/workflow.md`](../../../../workflow.md) governs roles and
review boundaries.

Each window that shows a buffer remembers its own cursor there. The
editor still has one `point`. That point is the selected window's
cursor. An unselected window keeps the line and column it had. `C-x o`
installs the entered window's cursor and origin on its buffer's
editor, and the runner's existing fit then runs against that cursor.
An edit, including undo, moves the selected cursor as it does today
and leaves every other window on the numbers it stored. A window
remembers a cursor only while it shows that buffer.

Decisions this spec makes, in one place:

| Question | Decision | Section |
|---|---|---|
| Where the cursor lives | `AloemacsView` gains `(point Position)` after `scroll-col`. The editor gains no field | §3.1 |
| The install send | Editor `install(point, scroll-row, scroll-col) -> AloemacsEditor`: focus, clamp, then `with-text-and-point` and `with-origin` | §4 |
| Where clamp is spelled | Inside `install`, with `focus-at`, `focus-end`, `valid-position?`, `focus-line`, and `line-length`. No Text method | §4.2 |
| Text focus after entry | On the installed point's line. The last line when the stored line is past the end | §4.3 |
| How the entered view stores the installed point | `enter-view` sends `AloemacsWindows with-buffer` after selecting the view, through `with-view-buffer`, which now also copies the editor point | §5.2 |
| Search entry | Same buffer while `searching`: install the editor's own point (the match), not the view's | §5.3 |
| Split | Both leaves take the live editor point with the live origin, passed explicitly | §6.2 |
| Kill | `retarget-buffer` gains `(point Position)` after `scroll-col` | §6.3 |

## 1. Series, predecessors, and authority

The series identity is **aloemacs-window-point**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code stays in
`examples/aloemacs/`. Tests stay in `tests/aloemacs/`, plus the
constructor migration in `tests/parenthetical-construction/`. This
folder holds the specification and the later checkpoint, never the
program.

There is one checkpoint:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-window-point 000** | `checkpoints/000-window-point.md` | The view stores a point. Split copies it. Other-window and delete install it before the fit. The four-window end-of-buffer story, the nearby-lines story, sticky numbers across an edit and undo, clamp on entry, the buffer-switch return, the in-search send, the `ctrl-x` search ending, and kill against the one mark all hold. One view still frames and edits as today. |

000 is the whole series. It includes the constructor threading. A
point field that `C-x o` ignores is not a checkpoint. The handoff, the
entry clamp, and the same-buffer search branch are one change. Adding
`point` to the selected-view write that already stores the origin
gives switch, find, select, add, visit, and every edit and motion
their rule; `retarget-buffer` on kill goes with that write.

The manager writes 000, then stops. If 000 would not fit one
implementer conversation, the manager sends this spec back. It does
not split it into a second number. Numbers are three digits, start at
000, and are never renumbered. Do not take a global number or add a
`CHECKPOINTS.md` entry.

### 1.1 Predecessors

All of these are implemented in the tree this spec was written
against:

| What | The state this series starts from |
|---|---|
| [`../windows/`](../windows/) 000–006 | A window is a view of a buffer. Each view stores an origin. `other-window` and `delete-window` store the departing editor origin on the departing view through `AloemacsWindows with-buffer`, then `enter-view` installs the destination origin through editor `with-origin`. One editor point is shared by every view of a buffer. The next `ensure-visible` fits that point into the selected leaf |
| [`../window-pictures/`](../window-pictures/) 000 | `AloemacsView` ends with `(picture (Option AloemacsLeafPicture))`. A multi-window frame reuses a leaf's recorded rows when buffer id, history length, origin, rectangle, name, and selection are unchanged |
| [`../window-bars/`](../window-bars/) | A tall leaf's last row is its bar. A Below split reserves no divider row and needs four rows. A Right split reserves one `\|` column |
| [`../completion/`](../completion/), [`../completion-page/`](../completion-page/) | Completion rows shrink the root rectangle (`root-rect`) |
| [`../viewport/`](../viewport/) | `ensure-visible` moves the selected origin until the editor point lies in the selected leaf. It does not move point |
| [`../undo/`](../undo/) | An edit pushes `UndoFrame (text point scroll-row scroll-col)`. Undo restores those four fields and leaves the mark alone |
| [`../kill/`](../kill/) | One mark on the editor. Kill uses that mark and the editor point. The mark is not rebased |
| [`../search/`](../search/) | Search is one session cursor. A key whose length is not 1, including `ctrl-x`, ends the search, then dispatches |

Geometry is whatever the program does today: `root-rect`, the bars,
Below's `(n + 1) / 2` top, Right's one-column divider, and
`AloemacsWindowRect text-rows`. The windows spec's divider arithmetic
is not the geometry. The examples in this spec were evaluated against
the current program.

### 1.2 Authority

- This spec is the authority for the per-view cursor.
- [`../windows/spec.md`](../windows/spec.md) remains the authority for
  the tree, rectangles, selection order, the origin handoff, split,
  delete, other-window, lock, the buffer-id resets, and echo. Do not
  amend it. This series supersedes only its rule that every view of a
  buffer shares one point, in exactly these places:
  - §3.2 "A view contains no … point". A view now stores one.
  - §3.3 "Current-editor rebuilds also replace only the selected
    leaf's stored origin". They now replace the selected leaf's stored
    origin **and point**.
  - §3.4 "No second editor or point is created", and entry's install
    through `with-origin`. Entry now installs through `install` (§4),
    which refocuses Text and may clamp the point. There is still no
    second editor.
  - §6.1 "Only selection and the shared editor/selected-origin handoff
    change", and "Every buffer's text, Text focus, point … stay
    exact". The entered buffer's Text focus and point now follow §4
    and §5. Every other buffer stays exact.
  - §6.2 "Delete changes no text, Text focus, point". The surviving
    leaf's entry follows §5.
  - §6.3 "no second point appears, and shared edits remain shared".
    Text, history, mark, and ring remain shared. Points are per view.
  - §9 item 5 "Shared text/point/history/mark remain on one buffer".
    Text, history, and mark remain on one buffer. The point is per
    view.
- [`../window-pictures/checkpoints/000-reuse-leaf-rows.md`](../window-pictures/checkpoints/000-reuse-leaf-rows.md)
  remains the authority for the picture field and the reuse key. This
  series threads the new field and does not change the key.
- [`../undo/spec.md`](../undo/spec.md), [`../kill/spec.md`](../kill/spec.md),
  and [`../search/spec.md`](../search/spec.md) stay in force unchanged.

## 2. Product, host, and file boundary

The implementer may edit:

- `examples/aloemacs/editor.aloe`: add `install` (§4)
- `examples/aloemacs/file.aloe`: the view field, `with-split`,
  `with-view-buffer`, `retarget-buffer`, `AloemacsWindows with-split`
  and `without-buffer`, session `split-window` and `enter-view`
- `examples/aloemacs/main.aloe`: the startup view's point
- Every `AloemacsView new` and `AloemacsView` field list in
  `tests/aloemacs/` and `tests/parenthetical-construction/`, and the
  expectations §8 names
- The new focused test `tests/aloemacs/window-point.rkt`

The implementer must not edit `lib/` (Text, List, String, Option),
`aloe/`, `host/`, the runner, `SPEC.md`, `CHECKPOINTS.md`,
`archive/`, or any other design document. No new key, command, Term
method, kernel message, `SPEC.md` row, or Text method. No mutation,
mirror, macro, inheritance, or delegation. `UndoFrame`,
`AloemacsLeafPicture`, `record-pictures`, `frame`, `multi-frame`,
`single-frame`, `frame-rows`, `ensure-visible`, `other-window`, and
`delete-window` keep their code. Editor `with-origin` stays as it is.

## 3. State

### 3.1 The view's point

`AloemacsView` has exactly these ordered fields:

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
The view still has no methods. It still holds no editor, text, path,
mark, history, ring, remembered page height, or rectangle. There is
still one editor per buffer.

`AloemacsEditor` is unchanged. Its `point` is the selected window's
cursor. Commands, search, kill, yank, and undo read and write it as
they do today.

The startup view in `main.aloe` is:

```aloe
(AloemacsView new 0 0 0 0 (Position new 0 0) #f (Option None))
```

### 3.2 The invariant

On every session a program send returns, the selected view's `point`
equals `(session point)`, its `scroll-row` and `scroll-col` equal the
current editor's, and its `buffer-id` equals the current buffer's id.
The origin half of this already holds. Section 6 extends the one write
that keeps it so the point half holds too.

An unselected view's point and origin are authoritative for that
view. Only entering that view or retargeting it on kill rewrites
them. They may name a position the text no longer contains.

## 4. The install send

### 4.1 Signature and fields

Add to `AloemacsEditor`, beside `with-origin`:

```text
install(point : Position, scroll-row : Int, scroll-col : Int)
  -> AloemacsEditor
```

`install` returns this editor with three changes:

1. `text` is the same characters focused on the installed line (§4.3).
2. `point` is the given point, clamped (§4.2).
3. `scroll-row` and `scroll-col` are the given origin, unchanged.

It preserves `quit`, `history`, `mark`, and `text-rows` exactly. It
does not change the characters, fit, validate or clamp the origin,
push an undo frame, or touch the mark. The origin precondition is
`with-origin`'s: nonnegative. Stored points are editor points and are
never negative.

The intended spelling is the two existing editor sends after one
focus:

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

The implementer may rearrange it, but the result, the focus, and the
use of `valid-position?` are fixed.

### 4.2 Clamp

Clamp is spelled inside `install`. There is no session helper and no
Text method. Use the focused Text's existing `valid-position?`. A
point that passes is installed unchanged.

- The point's line exists and its column is past that line's length:
  install that line at that line's length.
- The point's line is past the last line: install the last line at
  that line's length.

Line length is `line-length`, the column one past the last character,
which `valid-position?` already allows. In both failing cases the
focused Text is on the installed line, so the clamped point is
`(focused focus-line)`, `(focused line-length)`.

`valid-position?` runs on the already focused Text, so it walks no
lines. When the stored line is past the end, `focus-at` walks to the
end and fails, and `focus-end` walks again from the old focus. That
case is rare and is not tuned here.

### 4.3 Text focus after install

The Text zipper's focus sits on the installed point's line: the
stored line when it exists, otherwise the last line. This is chosen on
purpose:

- Every motion and edit already leaves the focus on the point's line.
  Entry now does the same, so the next key walks nothing.
- The clamp reads `valid-position?` and the line length from the
  focused line without a walk.
- After the fit, the entered leaf's origin is within its text rows of
  the cursor, so its first rebuild walks at most that many lines.

The cost is one walk at entry from the departed line to the entered
line. The departed leaf's next rebuild walks back to its own origin.
It rebuilds anyway, because its selection bit changed.

A moved focus is a different Text value, and session equality sees
it. When the focus is already on the installed line, `focus-at`
returns the same Text and `install` changes no Text. A `from-string`
Text becomes its `indexed` value, as the first motion would.

### 4.4 Examples

Take an editor whose Text is `"alpha"`, `"be"`, `"c"` focused on line
0, with point `(0, 0)`, origin `(4, 5)`, `quit` `#t`, some history, mark
`Some (0, 1)`, and `text-rows` 9.

| Send | Point | Text focus | Origin | Everything else |
|---|---|---|---|---|
| `install (0, 5) 1 2` | `(0, 5)` valid, unchanged | line 0, the same Text value | `(1, 2)` | unchanged |
| `install (2, 0) 0 0` | `(2, 0)` valid, unchanged | line 2 | `(0, 0)` | unchanged |
| `install (1, 4) 0 0` | `(1, 2)`: line 1 exists, `"be"` has length 2 | line 1 | `(0, 0)` | unchanged |
| `install (7, 1) 0 0` | `(2, 1)`: line 7 is past the end, `"c"` has length 1 | line 2 | `(0, 0)` | unchanged |
| `install (0, 0) 40 50` | `(0, 0)` | line 0 | `(40, 50)`, not fitted | unchanged |

In every row the characters, `quit`, history, mark, and `text-rows`
are exactly the receiver's.

## 5. Entry: other-window and delete

### 5.1 The departing write

`other-window` and `delete-window` keep their code. Each already sends
`AloemacsWindows with-buffer` with the current buffer before the
selection changes. Because `with-view-buffer` now also copies the
editor point (§6.1), that existing send stores the departing view's
live point with its live origin. The departing buffer's editor is not
touched. For a different-buffer entry, that buffer keeps the editor
point it had, which is the departing window's cursor.

### 5.2 `enter-view`

`enter-view(tree, view)` keeps its signature and its `find-id` lookup.
For the destination buffer found:

1. Choose the point to install. If the destination buffer id equals
   the departing id **and** `searching` is true, it is the destination
   editor's own point (the match, §5.3). Otherwise it is the view's
   stored `point`.
2. Replace that buffer's editor with
   `(editor install chosen (view scroll-row) (view scroll-col))`.
3. Focus the buffer zipper on that buffer, as today.
4. Apply today's echo, search, origin, wrapped, failing, and pending
   rules for same-buffer and different-buffer entry, unchanged.
5. Set the windows' tree and `selected` to the entered view, then send
   `with-buffer` with the buffer holding the installed editor. That is
   the same selected-view write that stores the origin everywhere else.
   It stores the installed point on the entered view, including a
   clamped point and a search match. The origin it writes is the
   origin just installed, so the view's origin is unchanged.

Entry does not fit. When the installed point equals the view's stored
point, step 5 leaves the entered view unchanged and only the editor
and selection move. Every other view, buffer, and field stays exact.

A sketch:

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

`delete-window` reaches the surviving leaf through this same entry. A
round trip through `other-window` with no fit, no edit, and search
off restores each view's point and origin. A same-buffer round trip
while searching leaves each visited view on the match.

### 5.3 Search

`search-key` is unchanged. A key whose length is not 1, including
`ctrl-x`, still ends the search and then dispatches. Ending the search
goes through `with-search`, which writes the editor point onto the
selected view and no other view. The `o` after `ctrl-x` is then an
ordinary entry: the entered window shows the cursor it stored, and the
window left keeps the match.

Entry can run while `searching` is true only through a direct session
send. When it does and the destination buffer id equals the departing
id, the editor point stays on the match. The entered view stores that
match. The departing view stores the match through §5.1, which it
already had because search writes the selected view. Other views of
that buffer keep their points. The search `origin`, query, wrapped,
and failing are preserved as today. The following fit may scroll the
entered view to show the match.

A different-buffer entry while searching applies the windows search
reset, then installs the destination view's own stored point.

### 5.4 Prompt

An active prompt does not block a direct entry. Echo follows the
windows rule. The frame's cursor stays on the echo row while the
prompt is active. The editor point becomes the entered view's cursor,
so after the prompt ends the frame shows that window's place.

### 5.5 The fit afterward

The runner's existing order is fit, record, frame, read key. After
`C-x o` the next iteration's `ensure-visible` fits the installed
point. If that point already lies in the installed origin and inside
the leaf's width and text rows, the fit leaves the origin unchanged.
Otherwise it moves only the entered view's origin, as it does today.
A direct `frame` after an entry without a fit draws the cursor from
the installed point and origin, as today.

### 5.6 Examples

All examples use an 80×24 session and a 100-line buffer whose lines
are `"line 0"` … `"line 99"`, shown by one view with id 0 at point
`(0, 0)` and origin `(0, 0)`, fitted once with `ensure-visible 80 24`.
No completion rows are showing, so the root text rectangle is
`(0, 0, 80, 23)`.

**Four columns.** `split-right` three times. The tree's visit order
is views 0, 3, 2, 1. Their rectangles are `(0, 0, 10, 23)`,
`(11, 0, 9, 23)`, `(21, 0, 19, 23)`, and `(41, 0, 39, 23)`, each with
22 text rows. All four store point `(0, 0)` and origin `(0, 0)`.

1. `buffer-end`, then `ensure-visible 80 24`. Point `(99, 7)`. View 0
   origin `(78, 0)`.
2. `other-window`. Selected is view 3. The editor point is `(0, 0)`
   and the origin `(0, 0)`. View 0 still stores `(99, 7)` and
   `(78, 0)`.
3. `ensure-visible 80 24` changes nothing. The frame's cursor is
   `ESC[1;12H`. View 3's first row is `"line 0"` padded to nine
   cells. Today's program instead scrolls view 3 to origin 78 and
   puts the cursor at `ESC[22;19H`.
4. `other-window` and `ensure-visible` three more times: views 2, 1,
   then 0. Each of 2 and 1 shows the top with point `(0, 0)`. Back on
   view 0, the point is `(99, 7)`, the origin `(78, 0)`, and the
   cursor `ESC[22;8H`.

**Nearby lines.** From the same start, `split-below`. View 0 is
`(0, 0, 80, 12)` with 11 text rows. View 1 is `(0, 12, 80, 11)` with
10 text rows.

1. `other-window`, then `move-down` three times. View 1 is at
   `(3, 0)`.
2. `other-window`. View 0 at `(0, 0)`, origin `(0, 0)`, cursor
   `ESC[1;1H`. View 1 stores `(3, 0)` and `(0, 0)`.
3. `other-window`. View 1 at `(3, 0)`, origin `(0, 0)`, cursor
   `ESC[16;1H`. Each fit along the way changes nothing.

## 6. Every other write

### 6.1 The selected-view write

`AloemacsWindowTree with-view-buffer(id, buffer)` writes four fields
on the selected leaf: `buffer-id`, `scroll-row`, `scroll-col`, and now
`point`, all from that buffer and its editor. `AloemacsWindows
with-buffer` keeps calling it. Its signature is unchanged.

Every session path that already sends `with-buffer` therefore stores
the point with the origin:

- `with-editor`: insert, newline, backward-delete, every motion, undo,
  request-quit, and `ensure-visible`
- `with-kill-state`: set-mark, kill, kill-line, yank
- `with-search`: find, every search key, `end-search`
- `selected-buffers`: switch-buffer, both `add-buffer` arities,
  find-file reuse, select-buffer
- `visited`

Unselected views keep the point and origin they last stored.

`with-view-buffer`, both leaves of `with-split`, and `retarget-buffer`
stay `view with` updates. `point` is one more field on that same
update. Do not rebuild a leaf with `AloemacsView new`: that would drop
the leaf's `picture`, which these updates keep today.

### 6.2 Split

The fresh leaf copies the selected view's point and origin at the
moment of the split. Pass the point explicitly with the origin that
`split-window` already captures:

```text
AloemacsWindows with-split(scroll-row, scroll-col, point, below?)
AloemacsWindowTree with-split(id, fresh-id, scroll-row, scroll-col, point, below?)
```

Both new leaves take that `point`, as they take that origin, in the
`view with` update each leaf already uses (§6.1). In
`split-window` the argument is `(editor point)` beside
`(editor scroll-row)` and `(editor scroll-col)`. Selection stays on
the original leaf. The post-split fit writes the selected original
only. Later motion updates the selected view only, so the two cursors
diverge when one moves.

### 6.3 Buffer identity changes

**Switch, add, find, select.** Through `selected-buffers`, the
selected view takes the arriving editor's point and origin. The
departed buffer's editor keeps its point: the cursor of the window
that was selected there. A view that comes back to a buffer takes
that buffer's editor point, including when another view of it was
selected in between and moved. Views that already showed the arriving
buffer, and whose buffer id does not change, keep their own points
and origins. No view keeps a cursor for a buffer it stopped showing.

**Kill.** `retarget-buffer` gains a point:

```text
AloemacsWindowTree retarget-buffer(removed-id, buffer-id, scroll-row, scroll-col, point)
```

Every view of the killed id, including the selected view, takes the
replacement's id, origin, and point, in the `view with` update the
leaf already uses (§6.1). `AloemacsWindows without-buffer` keeps its
signature and passes `(editor point)` beside the replacement origin it
already captures once before traversal. A view that already showed the
replacement, and was not retargeted, keeps its point and origin.
Retargeting is decided by the killed id alone. Killing the only buffer
keeps its id and installs the empty untitled editor, so every view of
that id is retargeted and takes point `(0, 0)` and origin `(0, 0)`.

**Visit.** A successful visit replaces the selected editor as today,
at point `(0, 0)` and origin `(0, 0)`, and `with-buffer` writes those
onto the selected view. Other views of that buffer id keep their
stored points and origins, which may now be invalid. Entering one of
them later clamps under §4.2.

### 6.4 What does not move

- No insertion, newline, deletion, kill, or yank adds a line or column
  delta to any other view. Positions are line and column numbers, not
  marks that chase text.
- Undo restores the selected editor from its frame, including a point
  and origin recorded while another view was selected, and writes that
  restored point and origin onto the selected view only. `UndoFrame`
  stays `(text point scroll-row scroll-col)`.
- An unselected view is never clamped, fitted, or scrolled. A stored
  origin past the end still paints blank rows, as today, until that
  view is entered.
- The mark, kill ring, and undo history stay one per buffer. The mark
  is not rebased. No goal column. `scroll-col` gets no separate
  adjustment rule.
- The picture key stays buffer id, history length, origin, rectangle,
  name, and selection. Point is not added to it.

### 6.5 Examples

Continue the nearby-lines example with view 0 selected at `(0, 0)` and
view 1 storing `(3, 0)` and origin `(0, 0)`.

**Sticky numbers.**

1. `newline` in view 0. View 0 is at `(1, 0)`. View 1 still stores
   `(3, 0)` and `(0, 0)`. Its rows now begin `""`, `"line 0"`,
   `"line 1"`, `"line 2"`.
2. `other-window`. The editor point is `(3, 0)`, on `"line 2"`, one
   line above `"line 3"`, the text it was on. Cursor `ESC[16;1H`.
3. `undo` in view 1. The text is restored. The point and origin come
   from the frame recorded by view 0's newline: `(0, 0)` and `(0, 0)`.
   View 1 stores them. View 0 still stores `(1, 0)`.

A deletion above another view behaves the same: `backward-delete` at
the start of a line in view 0 joins two lines and leaves view 1's
stored line and column unchanged.

**Clamp on entry.** Take a buffer `"abc"`, `"defgh"`, `"ij"` in two
views from `split-below`.

- View 1 stores `(1, 5)`, the end of `"defgh"`. In view 0 at `(1, 0)`,
  `kill-line` leaves line 1 `""`. View 1 still stores `(1, 5)` and its
  origin, and it paints from that origin. `other-window`: line 1
  exists with length 0, so the editor point and view 1's stored point
  are both `(1, 0)` on the session entry returns. The fit runs after.
- View 1 stores `(2, 2)`, the end of `"ij"`. In view 0 at `(1, 5)`,
  `kill-line` joins the lines: `"abc"`, `"defghij"`. `other-window`:
  line 2 is past the end, so the point is `(1, 7)`, and the Text is
  focused on line 1.

**Buffer-switch return.** Buffers A (the 100-line buffer) and B in
the zipper, two views of A from `split-below`.

1. In view 0, `move-down` five times: `(5, 0)`. `switch-buffer`. View 0
   shows B at B's editor point and origin. A's editor keeps `(5, 0)`.
2. `other-window` into view 1 (A). It installs view 1's own `(0, 0)`.
   `move-down` twice: `(2, 0)`.
3. `other-window` into view 0 (B). It installs view 0's stored B point.
4. `switch-buffer` back to A. View 0 takes A's editor point `(2, 0)`,
   not `(5, 0)`. View 1 still stores `(2, 0)`.

**Kill against the one mark.** In the nearby-lines layout with view 0
at `(0, 1)`: `set-mark`, then `other-window` into view 1 at `(3, 0)`,
then `kill`. The span is `(0, 1)` to `(3, 0)`: the one mark and the
entered window's cursor. The ring's head is that excerpt,
`"ine 0\nline 1\nline 2\n"`. Separately, with the mark set at
`(2, 0)`, inserting at `(0, 0)` in either view leaves the mark at
`(2, 0)`.

**Search.** Two views of the 100-line buffer from `split-below`, view
1 storing `(4, 0)`. In view 0, `find`, then type `n`, `e`, space,
`2`. The match is `(2, 2)`.

- A direct `other-window` send: `searching` stays `#t` with query
  `"ne 2"`. The editor point is `(2, 2)`. Both views store `(2, 2)`.
  A third view of the buffer would keep its own point.
- Instead, `handle-key "ctrl-x"`, then `handle-key "o"`: the search
  ends with view 0 storing `(2, 2)`, then entry installs view 1's
  `(4, 0)`.

## 7. Frame

Painting is unchanged. The frame draws one cursor, in the selected
leaf, from the editor point and the selected leaf's rectangle, or on
the echo row while a prompt is active. An unselected leaf draws no
cursor and paints from its stored origin. Direct editor `frame` stays
the one-view frame. One view frames and edits byte for byte as today.

## 8. Migration

**Constructors.** Every `AloemacsView new` in `examples/` and
`tests/`, including
[`tests/parenthetical-construction/session.rkt`](../../../../../tests/parenthetical-construction/session.rkt),
takes `point` after `scroll-col` and before `locked`. Test helpers
that build leaves (`leaf`, `views`, `selected-views`,
`removed-views`, the `(AloemacsView new 0 (buffer id) …)` session
builders) gain that argument. `archive/` is not edited.

**Field lists.** The five `AloemacsView` field lists in
`window-bars-one-view.rkt`, `windows-layout-and-rendering.rkt`,
`mode-line-row.rkt`, `windows-state-foundation.rkt`, and
`windows-state.rkt` insert `(point Position)` after
`(scroll-col Int)`. The parenthetical-construction startup check also
observes the startup view's point as `(0, 0)`.

**Negative checks.** Arity and type checks move with the new argument.
`AloemacsView new` with six arguments is now too few, eight too many,
and a non-`Position` in the fifth slot is a type error. The
`window-pictures.rkt` picture checks keep their meaning with the point
in place. `retarget-buffer` checks move to five arguments, with a
non-`Position` fifth argument rejected.

**Fixture points.** When the migration adds `point` to an existing
fixture, every view stores its buffer's editor point. An entry then
still installs that shared point, so a proof that a point survived
entry keeps its meaning. An expected view carries the point these
rules give it. A split's fresh view holds the point from the moment of
the split: the `find-view 8` expectation in
[`tests/aloemacs/windows-split.rkt`](../../../../../tests/aloemacs/windows-split.rkt)
becomes `(AloemacsView new 8 41 1 1 (Position new 3 2) #f (Option None))`.
New per-view tests choose unselected points on purpose.

**Text focus.** After an entry, the entered buffer's expected Text is
focused on the installed line (§4.3). Fixtures built with a focus off
the point's line, such as `(indexed lines 2)` with point `(1, 5)`,
either expect the refocused Text after entry or move the fixture's
focus to the point's line where the test is not about focus. Buffers
that were not entered keep their Text exactly.

**Proofs rewritten.** A session test that proves one shared point
across views of one buffer is rewritten to the per-view rule. The
known one is "shared edits and undo use one point and history across
origin handoffs" in
[`tests/aloemacs/windows-delete-and-other.rkt`](../../../../../tests/aloemacs/windows-delete-and-other.rkt).
With its fixture migrated so both views store `(0, 1)`:

| Step | Editor point, origin | View 7 | View 3 |
|---|---|---|---|
| `other-window` | `(0, 1)`, `(1, 1)` | `(0, 1)`, `(0, 0)` | `(0, 1)`, `(1, 1)` |
| `insert "X"` | `(0, 2)`, `(1, 1)` | `(0, 1)`, `(0, 0)` | `(0, 2)`, `(1, 1)` |
| `other-window` | `(0, 1)`, `(0, 0)` | `(0, 1)`, `(0, 0)` | `(0, 2)`, `(1, 1)` |
| `undo` | `(0, 1)`, `(1, 1)` | `(0, 1)`, `(1, 1)` | `(0, 2)`, `(1, 1)` |

The fitted paint after the second `other-window` keeps its rows and
moves its cursor from `ESC[1;3H` to `ESC[1;2H`. The text and history
expectations stay: edits and undo are still shared.

**Goldens.** A frame golden already in the tree moves only when this
contract changes the cursor address or which rows a leaf shows. Known
moves: the production-runner scripts in `mode-line-split-views.rkt`
and `window-bars-split.rkt` insert `X` in the second view and later
delete it with `C-x 0`. The surviving view now installs its own stored
`(0, 0)`, so the final frame's cursor column drops by one. The manager
inventories the rest, including `windows-lock.rkt` and
`window-pictures.rkt`.

## 9. Focused proof

Write `tests/aloemacs/window-point.rkt` before the product edits. It
proves, without a TTY:

1. **Types.** `AloemacsView`'s seven ordered fields. `install` is
   `(Position Int Int) -> AloemacsEditor` and rejects wrong arity and
   types. The new `with-split` and `retarget-buffer` arities.
2. **`install`.** The §4.4 table, each row against a raw expected
   editor: valid points unchanged, the column clamp, the past-the-end
   clamp, focus on the installed line, a `from-string` Text indexed,
   the origin taken unfitted, and `quit`, history, mark, and
   `text-rows` exact.
3. **Four columns.** §5.6 end to end, with the frame cursor and view
   3's first row after the first `other-window`, view 0 storing the
   end throughout, and the round trip back to the end.
4. **Nearby lines.** §5.6, both cursors and both origins kept.
5. **Sticky numbers.** §6.5 across `newline`, a joining
   `backward-delete`, and `undo`.
6. **Clamp on entry.** Both §6.5 cases. The session entry returns
   already stores the clamped point on the entered view, before any
   fit. While view 0 is selected, view 1's invalid stored point is
   unchanged and its painted rows are those of its stored origin.
7. **Split.** Both orientations copy point and origin to the fresh
   leaf. The cursors diverge after one moves.
8. **Delete.** Deleting the selected view enters the survivor at its
   stored point and origin, same buffer and different buffer.
9. **Buffer identity.** The §6.5 switch return. `select-buffer` and
   find-file reuse take the arriving editor's point. `visit` writes
   `(0, 0)` on the selected view and leaves other views of the id on
   their stored points until entered. Kill-buffer retargets views of
   the killed id to the replacement's point and leaves views already
   on the replacement alone. Killing the only buffer puts every view
   of it at `(0, 0)`.
10. **Search.** The §6.5 direct send and the `ctrl-x` ending.
11. **Mark.** The §6.5 kill against the one mark.
12. **Prompt.** A direct `other-window` with an active prompt installs
    the entered view's point. The frame cursor stays on the echo row.
    After Escape the cursor is at the entered window's place.
13. **One view.** A one-view session's frames and edits are unchanged,
    and its view's point follows the editor point.
14. **Invariant.** After every program step above, the selected view's
    point and origin equal the editor's.
15. **Runner.** A scripted runner with a Term double at 80×24 on a
    100-line file: `ctrl-x 3` three times, `buffer-end`, `ctrl-x o`,
    `escape`. The frame written after `o` shows `"line 0"` at the top of
    the second column with the cursor at `ESC[1;12H`. The runner code
    is unchanged.

## 10. Verification, hand checks, and acceptance

The implementer writes the focused test first, sees it fail,
implements, and verifies from the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-point.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/windows-delete-and-other.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs tests/parenthetical-construction
git diff --check
```

The aloemacs suite, including the window-pictures timing bar, is the
regression bar. Do not commit `compiled/`. Product edits are `.aloe`
only and need no rebuild before launch.

**Hand checks.** The human reviewer runs these on a real TTY at least
80 by 24. The implementer does not need a TTY.

```sh
cp SPEC.md /tmp/window-point.txt
racket host/racket/aloemacs-run.rkt /tmp/window-point.txt
```

*Four columns.* `C-x 3` three times. The cursor is at the top. Press
`Ctrl-End` in the first column; it shows the end of the file. Press
`C-x o` once. The second column still shows the top of the file, with
its cursor there. The first column still shows the end. Press `C-x o`
three more times. The first column is selected again and the cursor is
at the end of the file. Escape quits.

*Sticky line numbers.* Start the editor again. `C-x 2`, then `C-x o`,
Down three times, and `C-x o` back. The lower window's cursor is
stored three lines below the upper one. Press Return in the upper
window. The lower window's text moves down one row. Press `C-x o`. The
cursor sits on the fourth row of the lower window, one line above the
text it was on. Escape quits. Nothing is saved.

The series is accepted when all of these are true:

1. Two or more views of one buffer hold different points at once. The
   selected view's point equals the editor point on every
   program-returned session. One cursor is drawn, in the selected
   leaf. An unselected leaf draws none.
2. `other-window` and `delete-window` install the entered view's point
   and origin before the fit. The four-column and nearby-lines stories
   hold, and a round trip with no further edit restores each view.
3. A split copies point and origin to the fresh leaf.
4. An edit or undo never changes another view's stored point or
   origin. Undo restores the selected view from its frame.
5. Entry clamps an invalid stored point under §4.2 and stores the
   clamped point on the entered view before the fit. No unselected
   view is clamped or scrolled.
6. A view that changes buffer takes the arriving editor's point and
   origin. Views that did not change buffer keep theirs. Kill and
   visit follow §6.3.
7. A same-buffer entry while searching keeps the match and stores it
   on the entered view. `ctrl-x` still ends the search first.
8. Kill uses the entered window's cursor and the one mark. The mark
   does not move.
9. One view frames and edits as today. The picture key, Text, List,
   `UndoFrame`, the runner, and Term are unchanged.
10. The focused proof and the suites in §10 pass without a TTY, and
    both hand checks look as described.

The manager writes **aloemacs-window-point 000 only**, then stops.
000 is the whole series. If you have been told to read this file as
the manager assignment, it is the whole assignment.
