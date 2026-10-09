# aloemacs-window-bars 001 — Split bars

**Status: Ready to implement.** Human review of this checkpoint precedes
its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice,
and stop when green.

## Goal

Make every tall split leaf's mode line its bar, and remove the Below rule
row.

- A Below split spends no row. Its top child gets the odd row.
- A below split needs at least four rows.
- Each split leaf at least two rows tall ends in a bar: LIGHT on the
  selected view, DARK on every other view.
- No `-` rule row and no `+` junction remain. A Right split keeps its one
  `|` column, painted on every row.
- A leaf shorter than two rows stays all text.

Fit, cursor, echo, and the fallback keep their rules. Their results
change only because Below leaves change height.

Migrate the existing split goldens. This completes the series. Stop when
both focused proofs and the full aloemacs suite pass.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec. The
checkpoint narrows the spec to one slice. It does not revise it.

- Identity: **aloemacs-window-bars 001**, filed as
  `checkpoints/001-split-bars.md`. This is a local editor checkpoint.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product
  edits. `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`.
- The accepted [../spec.md](../spec.md) governs:
  - §§1–3: predecessors, authority, the file boundary, exact shapes,
    non-goals, and the bar. §3.3 says where PLAIN sits; §3.4 says which
    bar is LIGHT.
  - §4: Below division, the below split minimum, the geometry example,
    and what is removed.
  - §5: fit, cursor, echo, and state.
  - §7: this layer, including its examples, migration rules, and focused
    proof.
  - §8: the 001 verification commands, the hand check, and the series
    acceptance list.

  §6 describes 000, which is done. Predecessor specs named in spec §1.1
  govern preserved behavior, especially
  [windows/spec.md](../../windows/spec.md) for Right allocation, locks,
  commands, and selection.
- [000-one-view-bar.md](000-one-view-bar.md) is implemented in the
  current working tree, uncommitted. `AloemacsModeLine.bar` and its
  `light`, `dark`, and `plain` helpers exist, `single-frame` paints the
  LIGHT bar, and `tests/aloemacs/window-bars-one-view.rkt` exists. Keep
  that work and its migrations. Do not redo 000 or edit its checkpoint.
  At issuance the full aloemacs suite passes (517 tests) and
  `git diff --check` is clean.

### Current tree

Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
Line numbers are approximate.

- `AloemacsWindowRect` (near line 485) has `divider (extent)` and
  `earlier (extent)`, which `top`, `bottom`, `left`, and `right` all use.
  Today `top` has `earlier(n)` rows, the rule row sits at
  `y + earlier(n)`, and `bottom` starts one row lower. It also has
  `divider-row` and `divider-column`, which only the tree's divider
  queries use.
- `AloemacsWindowTree` (near lines 580–660) has `horizontal-divider?`,
  `vertical-divider?`, `below-divider`, `right-rows (rect left-rows
  right-rows y)`, `blank-rows`, and `frame-rows (buffers rect)`.
  - A valid tall leaf ends in the plain name row
    `(editor safe-cells ((AloemacsModeLine new) row (buffer name)
    (rect columns)))`.
  - Below joins the top rows, a `below-divider` row, and the bottom rows.
  - Right joins each pair of rows with `+` or `|`, chosen by
    `horizontal-divider?`.
- `AloemacsWindows.split-allowed?` (near line 681) requires
  `(if below? (rect rows) (rect columns)) >= 3` on the selected nominal
  rectangle.
- Session `multi-frame` (near line 1646) sends
  `((windows tree) frame-rows (self buffers) root)`.
- Session `single-frame`, `echo-row`, `completion-frame`, `root-rect`,
  `fit-rect`, and `ensure-visible` already have their final 001
  behavior. Do not edit them.

### Size

The manager applied this slice's product change to a scratch copy and
ran the suite:

- 46 of 517 test cases failed, in the 12 existing files listed below.
- With every check allowed to run, about 180 distinct expectations fail.
- Four test cases in `mode-line-split-views.rkt` stop early on the old
  two-argument `frame-rows` send, so their real count is higher.

The inactive bar adds almost nothing to that work. With every split bar
LIGHT, the same expectations would fail for the same reasons: geometry,
the removed rule row, and the new bars. Spec §1 allows a separate 002
only when the inactive bar is the size driver, so this checkpoint is not
split. That is about as large as aloemacs-mode-line 001, which also
migrated split frames and fit heights in these windows files.

If you cannot finish in this conversation, stop and report which files
remain. Do not split the slice or write 002 yourself.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe` only, in these places:
  1. `AloemacsWindowRect`: `top` and `bottom` follow §4.1 of this
     checkpoint. Remove `divider-row` and `divider-column`. `left` and
     `right` keep their results. You may keep or reshape `divider` and
     `earlier` as long as Right is unchanged.
  2. `AloemacsWindows.split-allowed?`: the below check needs four rows.
     The right check is unchanged.
  3. `AloemacsWindowTree`:
     - remove `horizontal-divider?`, `vertical-divider?`, and
       `below-divider`
     - `right-rows` paints `|` on every row and drops the `rect` and `y`
       parameters
     - `frame-rows` gains the selected view ID
  4. Session `multi-frame`: pass `(windows selected)` to `frame-rows`.
     Nothing else in it changes.

  Update comments that describe the removed divider or junction rules.
- Create `tests/aloemacs/window-bars-split.rkt` before the product edit,
  and watch it fail.
- The **12 existing files** below, under the migration rules in this
  checkpoint. Paths are relative to `tests/aloemacs/`. The failing test
  cases are the ones the probe found; search each file again.

  | File | Failing cases | What changes |
  |---|---|---|
  | `windows-split.rkt` | 9 of 11 | The allocation table splits by orientation: Below at extent three now refuses, and four through eight take §4.1. The guard and fallback fixtures, live origin capture, T/cross frames, and shared edit/undo/page origins change, including origins recorded in undo frames. Buffer operations after splits, the echo matrix's refusals, the chord equivalence, and runner frames also change. |
  | `windows-layout-and-rendering.rkt` | 7 of 10 | The nominal rectangle table's Below rows change, and a Below at extent two is now positive. Also changes: the mixed and junction frames, the shared edit/visit frames, page motion at the new heights, the fallback fixture, and the scripted Term loop. |
  | `windows-delete-and-other.rkt` | 6 of 14 | Explicit fit cursors, shared edit/undo origins, nested promotion rectangles, locked deletion guards including the zero-axis fallback, runner frames, and the token-matrix frames. |
  | `windows-lock.rkt` | 4 of 9 | Locked edit/fit/resize origins, runner refusals and frames, descendant lock guards over nominal coordinates under the new division, and the token matrix. |
  | `windows-state.rkt` | 1 of 12 | Remembered heights and origins for Below leaves in the selected-rectangle/fallback fit proof. |
  | `mode-line-split-views.rkt` | 8 of 9 | Direct tree `frame-rows` sends gain the selected ID. Four cases stop on that arity today. Every split frame, the fallback fixture, page travel at text heights one, two, and three, and the runner also change. |
  | `completion-frame.rkt` | 4 of 11 | Split rows in the shortened root, the fallback fixture, the direct split with its list-aware fallback, and the no-list split frames. |
  | `completion-page-frame.rkt` | 1 of 4 | Shared split frames and the list-induced fallback fixture. |
  | `completion-session.rkt` | 1 of 14 | The split branch of the inline `prefix` (`"unti|unti"`) gains LIGHT and DARK bars. Its one-view branch stays. |
  | `idle-echo.rkt` | 2 of 10 | Below split frames and their idle echo payloads under the new heights. |
  | `mode-line-one-view.rkt` | 1 of 7 | Only the growth split frame in the global-fallback case. |
  | `window-bars-one-view.rkt` | 2 of 7 | Only its assertions of today's split frames: the growth frame and the positive split frames. Replace them with the completed contract. You may rename those two test cases and their staging comments. Keep every one-view and fallback assertion. |

The probe also found one-view **fallback** fixtures that now lay out
positively, because a Below at extent two has rows one and one. They are
in `completion-frame.rkt`, `completion-page-frame.rkt`,
`mode-line-split-views.rkt`, `windows-delete-and-other.rkt`,
`windows-layout-and-rendering.rkt`, and `windows-split.rkt`. Treat them
under the fallback rule in Migration below.

These files construct Below trees or below splits but pass under the
probe unchanged, so they must stay unedited: `buffer-session.rkt`,
`completion-page-session.rkt`, `keymap-session.rkt`, the three
`prompt-commands-*.rkt` files, `windows-state-foundation.rkt`, and
`windows-buffer-identity.rkt`. The same applies to every other test
file.

### Must leave untouched

- In `file.aloe`:
  - `AloemacsModeLine` (`row`, `fill`, `bar`, and its helpers)
  - session `single-frame`, `echo-row`, `completion-frame`,
    `completion-row-count`, `root-rect`, `fit-rect`, `ensure-visible`,
    and `frame`'s routing
  - `multi-frame`'s envelope and cursor
  - every command and guard other than the below minimum
  - `positive-layout?`, `rect-for`, locks, delete, `with-split`,
    `fresh-id`, and leaf traversal, except through the new
    `top`/`bottom` results
  - the two loads and the order of declarations
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`,
  `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, `lib/`, `aloe/`,
  `SPEC.md`, and `CHECKPOINTS.md`. Add no dependency, load, host
  capability, runner argument, or build step.
- Shapes:
  - `AloemacsEditor` keeps its eight fields and gains no method.
  - The session keeps fourteen fields, the buffer three, the view five,
    the rectangle four, and the windows four.
  - `AloemacsModeLine` keeps `(fields)` and its position.
  - The class list and its order stay exact.
  - Add no class, constructor, command, key, keymap entry, or Term
    method.
- Every document: this checkpoint and 000, `spec.md`, `charter.md`, and
  `README.md` in this folder; predecessor and neighbor documents; and the
  parent `aloemacs/README.md`, `discussion.md`, and `explorations.md`.
  The parent files may carry uncommitted edits from the discussion.
  Leave them exactly as you find them.

If another product change seems necessary, stop and report it. Do not
widen this checkpoint.

## Required behavior

### 1. Below division (spec §4.1)

Right is unchanged. For an extent `n`, `divider = min(1, n)`,
`available = n - divider`, `earlier = (available + 1) / 2`,
`later = available - earlier`. The right child's x is
`x + earlier + divider`, and `|` sits at `x + earlier`.

Below reserves no row. For every nonnegative extent `n`:

```text
earlier = (n + 1) / 2          [integer division]
later   = n - earlier
top     = (x, y,           columns, earlier)
bottom  = (x, y + earlier, columns, later)
```

| `n` | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| top rows | 0 | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 | 5 |
| bottom rows | 0 | 0 | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 |

- `n = 0` gives a zero axis to both children, and `n = 1` gives one to
  the bottom.
- A Below lays out positively when `n >= 2`.
- The global fallback rule is unchanged. When any nominal leaf has a zero
  axis, the session paints the selected buffer in the whole root through
  `single-frame`, with no dividers, even when the selected leaf alone is
  positive.

A new split changes only the selected leaf's rectangle. Ancestors and
siblings stay exact. Lock comparisons still compare all four nominal
coordinates, under this division. Delete still recomputes the promoted
sibling in the old parent's rectangle, under this division. Rectangles
are still derived, never stored. `text-rows` is unchanged.

### 2. Below split minimum (spec §4.2)

A below split is allowed when all of these hold:

- a positive size is remembered
- the selected view is unlocked
- its nominal rectangle is positive
- that rectangle has at least four rows

A right split still needs at least three columns.

Refusals keep their outcomes. A refused split stores `"failed"` when
neither a prompt nor a search is active. While either is active, it
leaves the whole session unchanged.

A later shrink can still leave a leaf one row tall, at Below extents two
and three. That leaf is all text, with no bar and no substitute rule.

### 3. Split composition (spec §7.1)

```text
(tree frame-rows buffers rect selected) -> (List String)
tree     : AloemacsWindowTree
buffers  : AloemacsBuffers
rect     : AloemacsWindowRect
selected : Int        ; the window configuration's selected view ID
```

Let `w = rect.columns` and `h = rect.rows`.

- **Leaf, buffer lookup miss** (a raw dangling ID): `h` blank rows of
  width `w`, with no name and no bar. This is unchanged.
- **Leaf, `h >= 2`**: `h - 1` text rows from that buffer editor's
  `frame-rows(w, h - 1, view.scroll-row, view.scroll-col)`, each padded
  to `w`, then the bar:

  ```text
  raw   = (AloemacsModeLine new) row (buffer name) w
  shown = editor safe-cells raw
  paint = (AloemacsModeLine new) bar shown ((view id) = selected)
  ```

- **Leaf, `h < 2`**: today's all-text rows, unchanged.
- **Below**: the top's rows, then the bottom's rows, with no row between.
- **Right**: each row is the left row, `|`, then the right row, on every
  row of the rectangle.

Pass `selected` unchanged to every child.

`selected?` is true exactly when the leaf's view ID equals the window
configuration's `selected`. Several views of one buffer paint one LIGHT
bar, on the selected view, and DARK bars on the others. An active
prompt, search, or completion list changes no bar.

Find buffers through the existing temporary focused collection, and never
install that focus. Keep the bounded `focus-at` / `next-lines`
traversal. Do not clamp an inactive origin or build a temporary editor.

Each leaf returns exactly `h` rows of visible width `w`. A row's visible
width counts cells with every LIGHT, DARK, and PLAIN removed. The joined
root has exactly `root.rows` rows of visible width `columns`, joined with
CRLF and no trailing CRLF.

The multi-view envelope is unchanged:

```text
ESC[?25l ESC[2J ESC[H joined-root-rows completion-rows
[ESC[rows;1H shown-echo, only when rows >= 2]
ESC[final-row;final-columnH ESC[?25h
```

Each bar's PLAIN comes right after its last visible cell, inside its row
String, so it always precedes the `|` divider, the next CRLF, list rows,
the echo address, and the cursor. Every frame ends in default
attributes.

### 4. Fit, cursor, echo, and state (spec §5)

There is no code change here. Results change only through Below heights.

- **Fit.** Session `ensure-visible` fits the current editor at
  `fit-rect`'s width and `text-rows`, mirrors the origin onto the
  selected view, and remembers the full terminal size. Unselected
  origins stay until that view is selected and fitted. Page motion uses
  the remembered text height. A successful split fits once, at the
  selected child's text height. The fresh child keeps the pre-split
  origin.
- **Cursor.** It is `selected.y + point.line - scroll-row + 1` and
  `selected.x + point.column - scroll-col + 1`. With an active prompt
  and `rows >= 2`, it is on the echo row at
  `prompt.screen-column(columns)`. It is never on a bar.
- **Echo.** It is `echo-row(columns, selected.rows)`. A selected Below
  leaf that grows from one row to two now gets the empty idle payload.
  That is geometry, not an echo change.
- **State.** Frame stays pure. The only command-visible changes are the
  Below rectangles and the below minimum. Every other state transition
  and file effect is unchanged.

### 5. Exact examples

These are from spec §4.3 and §7.2. The manager checked each one against
the scratch probe.

**Geometry.**

- A 9-by-5 text rectangle (terminal 9 by 6) split right, then its left
  view split below, gives `(0,0,4,3)`, `(0,3,4,2)`, and `(5,0,4,5)`.
  The `|` is at x=4.
- Visit order is original-left-top, new-left-bottom, original-right.
- A below split of `(0,3,4,2)` refuses. A right split of it is allowed.
- A one-view session at terminal 9 by 4 refuses `C-x 2`.
- At terminal 9 by 5, `C-x 2` gives `(0,0,9,2)` and `(0,2,9,2)`.

**Two stacked views of one buffer.**

- Terminal 8 by 6, root 8 by 5.
- One buffer, ID 0, path `/a`, lines `one`, `two`, `three`, `four`.
- Tree `Below(Leaf view 0, Leaf view 1)`, both views showing buffer 0.
- View 0 is selected, at origin `(0,0)` with point `(0,0)`. View 1 is at
  origin `(2,0)`.

```text
"\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a -----\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a -----\e[0m\e[6;1H\e[1;1H\e[?25h"
```

**Mixed nesting.**

- Terminal 9 by 6. Tree `Right(Below(view 0, view 1), view 2)`.
- Buffer A, ID 0, path `/a`, lines `abcdef`, `ghijkl`, `mnopqr`,
  `stuvwx`, `yz0123`.
- Buffer B, ID 1, path `/b`, lines `ABCDE`, `FGHIJ`, `KLMNO`, `PQRST`,
  `UVWXY`.
- View 0 shows A at origin `(0,0)`. View 1 shows A at `(3,1)`. View 2
  shows B at `(1,2)`.
- View 1 is selected. A's editor has origin `(3,1)` and point `(3,2)`.

```text
"\e[?25l\e[2J\e[Habcd|HIJ \r\nghij|MNO \r\n\e[38;5;252;48;5;239m/a -\e[0m|RST \r\ntuvw|WXY \r\n\e[38;5;16;48;5;250m/a -\e[0m|\e[38;5;252;48;5;239m/b -\e[0m\e[6;1H\e[4;2H\e[?25h"
```

Selecting view 0 instead, with A's editor at origin and point `(0,0)`,
makes view 0's bar LIGHT and view 1's DARK. The visible rows stay the
same, and the cursor is at `(1,1)`.

## Tests

### Focused proof: `tests/aloemacs/window-bars-split.rkt`

Write this file first and watch it fail. It needs no TTY. Use the
checked driver, `rackunit`, counted Fs doubles, and a scripted Term
double, following the patterns in `window-bars-one-view.rkt`,
`mode-line-split-views.rkt`, and `windows-split.rkt`. Copy any helper
you need into this file. Do not `require` another test module.

Expected Strings use test-local literals for LIGHT, DARK, and PLAIN, plus
independently computed rows and rectangles. Never build an expectation by
sending `bar`, `row`, `frame-rows`, a rectangle send, or a composer under
test. Keep whole-frame assertions.

Prove:

1. **Geometry.** Show §1's table for `n` from 0 to 9 through `rect-for`
   and `positive-layout?`, and Right's unchanged table. Show §5's
   rectangles, and that ancestors and siblings are unchanged after a new
   split.
2. **Splits, refusals, delete, and locks.**
   - A below split at extent three refuses. At extent four it succeeds
     with two rows each. Cover odd and even larger extents.
   - A right split at three columns succeeds.
   - Unfitted and locked refusals are unchanged.
   - Echo outcomes for each initial token (`""`, `"saved"`,
     `"failed"`), with and without an active prompt or search.
   - Delete promotion and lock comparisons under the new division,
     including a locked descendant that would move and one that would
     not.
3. **Frames.** Cover:
   - both §5 frame examples byte for byte, in both orientations
   - deeper mixed nesting
   - two views of one buffer at distinct origins
   - identical names on distinct buffer IDs
   - width-one leaves, long names, and safe controls
   - a valid inactive origin beyond EOF that still paints its bar
   - a raw dangling buffer ID, which paints blank rows and no bar

   For every frame, assert the row count and visible width. No row is
   made only of `-` and `+`, and no `+` appears outside buffer text. `|`
   appears on every row of every Right rectangle, including beside bars,
   always after PLAIN. A name holding `-`, `|`, or `+` stays inside its
   bar.
4. **Bar counts.** A frame has exactly one LIGHT when the selected leaf
   is tall and none when it is short. It has one DARK per other tall
   leaf. Short leaves next to tall leaves paint only text. An all-short
   positive layout has no sequence.
5. **Selection, prompt, search, and list.** Other-window and delete move
   the LIGHT bar. An active prompt keeps the bar on the selected view,
   with the cursor on the echo row. Search keeps the text cursor. A
   painted completion list sits below the root, after the last PLAIN.
6. **Fit.** Selected fit at the new text heights is minimal and
   idempotent. Cover page motion at text heights one, two, and three,
   post-split fit, and unchanged unselected origins. Frame is pure.
7. **Fallback and growth.** Shrinking to a zero axis paints the one-view
   frame with one LIGHT bar, and no sequence at root height one. Growth
   restores the split bars. The tree, selection, locks, and inactive
   origins persist.
8. **Runner.** A scripted Term drives the production runner through
   `run-aloemacs-with-hosts`:
   - split below and split right
   - other-window
   - an edit
   - a prompt
   - save
   - delete
   - resize
   - quit

   The runner contract is unchanged: fit, frame, and one write before
   each read. Assert the exact event list, including full frame
   Strings, and the exact read, write, and Fs counts.

### Migration (spec §7.3)

Apply these rules to the 12 files in the table:

- **Geometry.** Rectangle tables, `rect-for`, `positive-layout?`, lock
  comparisons, and delete promotion take §1's division. A Below at
  extent two is now positive.
- **Refusals.** A below split that succeeded at extent three now
  refuses. Give that scenario more rows to keep its success, and prove
  the refusal at three separately.
- **Fallback fixtures.** A fixture whose purpose was a zero-axis fallback
  through a Below at extent two now lays out as one row and one row.
  Rebuild it so the same fallback is still proved, for example with a
  Below at extent one or a Right below three columns. Keep its
  assertions' intent. Extent three was already positive, and extent one
  is still a fallback. A fixture whose purpose was not the fallback
  instead takes the new positive frame.
- **Named heights.** Some tests are named for a specific leaf height,
  such as an uneven split whose selected leaf is one row. When that
  height no longer arises at the same size, choose a size that produces
  it and keep the assertions. A Below at extent three gives two rows and
  one row. Otherwise recompute at the same size.
- **Split frames.** Split frames lose their rule rows, and `+` becomes
  `|`. Each tall split leaf's name row is wrapped in LIGHT (selected
  view) or DARK (every other view). Wrap only non-empty rows. Recompute
  text rows, fitted origins, origins recorded in undo frames, page
  results, cursors, and idle echo payloads for the new heights, by hand.
- **Direct sends.** Direct tree `frame-rows` sends gain the selected ID.
- **Unchanged.** One-view and fallback frames, Right rectangles, short
  frames, and every non-geometry assertion stay byte for byte. Do not
  turn a whole-frame assertion into a substring check.

Expected Strings use test-local literals for LIGHT, DARK, and PLAIN, plus
independently computed rows. Where a file's split helper shares a
name-row function with its one-view helper, keep that function returning
visible cells, and wrap at each call site. Never build an expectation
with `bar`, `frame-rows`, or a composer under test.

A failure that is not explained by Below division, the below minimum,
the removed rule row, the bars, or their fit, cursor, and echo
consequences is a stop condition. Report it.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-bars-one-view.rkt tests/aloemacs/window-bars-split.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp`, `-j 4`, and `-y`. Do not
commit `compiled/`. The product edit is `.aloe` only and needs no rebuild
before launch. The implementer needs no TTY.

The checkpoint is complete when:

- both commands pass and `git diff --check` is clean
- the product diff is limited to this checkpoint's four `file.aloe`
  places, plus removed helpers and their comments
- the existing-test changes are limited to the 12 files above

Report the files changed and the verification output. Then stop.

**Hand check, for the human reviewer** (spec §8). On a real TTY with 256
colors, at least 80 by 24:

```sh
cp SPEC.md /tmp/window-bars.txt
```

```sh
racket host/racket/aloemacs-run.rkt /tmp/window-bars.txt
```

1. Type `C-x 2`, `C-x 3`, `C-x o`, `C-x o`, `C-x 3`. There are four
   windows on one file, and the lower-left window is selected.
2. Its whole mode line is the lighter bar. The other three mode lines are
   the darker bar.
3. No row of dashes sits under the upper mode lines; the next row is
   buffer text. The vertical stroke is `|` on every row, including beside
   the bars. The echo row is not colored.
4. `C-x o` moves the lighter bar to the lower right, then to the upper
   left.
5. `C-x C-f` puts the cursor on the echo row while the upper-left bar
   stays lighter.
6. Escape cancels the prompt. Escape again quits. Nothing is written.

The series is accepted against spec §8's eight conditions after this
review.

## Non-goals

- Spec §2's non-goals: line-drawing characters or any replacement of
  `|`; faces or span attributes; recoloring buffer text, the echo row,
  the prompt, or a completion list; mode names, dirty marks, readouts,
  lock marks, window numbers, or badges; a blank separator in place of
  the removed rule; terminal color detection; Right allocation, the
  three-column minimum, lock policy, or echo changes; a second editor or
  origin per view; kernel messages; mutation, inheritance, macros, or
  new special forms.
- Do not write 002 or any later checkpoint. This is the final checkpoint
  of the series.
- Do not edit a spec, a charter, a README, or another checkpoint. Do not
  start faces, language modes, or Boids.
