# aloemacs mode-line specification

**Status: Accepted for checkpoint planning.** The user authorized the
manager to proceed if the spec was ready. The manager reviewed its code
seams, migration inventory, and checkpoint size and found it ready.
Behavior, interfaces, and the two-part partition are accepted.

This file is the complete design
input for the **aloemacs-mode-line** checkpoint manager and implementers.
They do not need the charter or the design conversation. This accepted
file is their design authority. This is application
design; [`SPEC.md`](../../../../../SPEC.md) remains Aloe language law,
and [`docs/workflow.md`](../../../../workflow.md) governs the roles and
review boundaries.

A window at least two rows tall reserves its last row for its buffer's
name. The name begins at the leaf's left edge, followed by one space and
`-` fill when there is room. A shorter leaf remains entirely text. The
echo row remains one full-width message or prompt row below the window
tree. The mode line is derived display data, never stored state.

## 1. Series, predecessors, and authority

The series identity is **aloemacs-mode-line**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code stays in
`examples/aloemacs/`; tests stay in `tests/aloemacs/`. This folder holds
the specification and later checkpoint documents, never the program.

There are two intended checkpoints, in this order:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-mode-line 000** | `checkpoints/000-one-view.md` | Pure name row, derived text height, and the one-view session composer and fit, including its existing too-small-tree fallback. Tall frames show the name above the echo. Short frames and direct editor frames retain their bytes. Visible split composition remains the predecessor behavior. |
| **aloemacs-mode-line 001** | `checkpoints/001-split-views.md` | The same row in each tall leaf of a constructed split, selected-only fit at the reduced height, and complete divider/cursor/echo/resize proof. Short leaves remain text. |

Numbers are three digits, start at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. After the human accepts this
spec, the manager writes **000 only**, then stops. Human review of its
implementation precedes issuing 001. Each implementer writes focused
tests first, implements only the approved slice, runs verification, and
stops when green. Do not issue both checkpoints together or take a global
number in `CHECKPOINTS.md`.

The two-part partition is appropriate: 000 changes one product file,
adds no constructor migration, and migrates expectations through the
existing per-file frame helpers and explicit fit fixtures. 001 is a
separate, meaningful compositor and shared-view proof. If the manager's
exact inventory shows that 000 cannot fit one implementer conversation,
return that size finding for a revised spec before issuing it. The only
permitted revision is row rule, then one-view frame and golden migration,
then split views, with no added behavior. Do not issue a checkpoint that
leaves existing tests broken for its successor.

Text through Prompt commands are implemented predecessors. Windows
000–006 is implemented; its final human review remains. This series uses
the accepted windows geometry now and does not wait for that review.
A blocking window defect is reported for that series; it is not repaired
inside this series.

Authority for preserved seams is:

- [`../README.md`](../README.md) and
  [`../explorations.md`](../explorations.md): layer order, Band 3 item 10,
  and the boundary before faces and language modes.
- [`../windows/spec.md`](../windows/spec.md): buffer/view ownership,
  IDs, layout, dividers, locks, selection, fit, fallback, commands,
  and echo/input rules. This spec supersedes only its all-text leaf
  height and its tall one-view/multi-view frame bytes as specified below.
- [`../echo/spec.md`](../echo/spec.md): reserved last screen row,
  three tokens, idle label, and short-terminal suffix behavior.
- [`../buffer/spec.md`](../buffer/spec.md): derived `buffer.name`,
  nonempty zipper, editor/path ownership, and buffer operations.
- [`../safe-cells/spec.md`](../safe-cells/spec.md): control replacement
  after clipping, leaving stored data unchanged.
- [`../minibuffer/spec.md`](../minibuffer/spec.md): active prompt row
  and cursor, submission, and one-row exception.
- [`file.aloe`](../../../../../examples/aloemacs/file.aloe) and
  [`editor.aloe`](../../../../../examples/aloemacs/editor.aloe): current
  implementation and the unchanged direct editor frame.

The [GNU Emacs mode-line description](https://www.gnu.org/software/emacs/manual/html_node/elisp/Mode-Line-Format.html),
`/home/dharmatech/src/legmacs/legmacs/modeline.lg` and its per-window
composer in `legmacs/render.lg`, and the status-line painter in
`/home/dharmatech/src/e/lib/head/paint.sls` are seam catalogs. This design
takes a per-window buffer label. Their modes, segment registries, state
markers, position readouts, styles, and buttons supply no requirements.
The row spelling below is this project's decision.

Language law wins on sends, types, and evaluation. The windows spec wins
on tree geometry and commands. This spec wins on the allocation of text
and mode-line rows within a leaf. Older constructor inventories and
all-text descriptions are historical; do not amend predecessor specs.

## 2. Product, host, and file boundary

The implementation is checked Aloe. Racket tests use the existing checked
driver, `rackunit`, counted Fs doubles, and scripted Term doubles without
a physical TTY. Keep `file.aloe`'s existing two loads. No dependency,
host capability, module, or build step is needed.

Both checkpoints may edit **`examples/aloemacs/file.aloe` only** for
product changes. 000 introduces the row helper, derived leaf text-height
send, single-view composition, and its fit branch. 001 changes the tree's
leaf row composer and completes the fit rule for visible splits. Internal
helpers may use ordinary String, Int, and List sends. Commands, keymaps,
buffer transitions, field inventories, and constructor arities stay exact.

Focused tests are:

| Part | New tests |
|---|---|
| 000 | `tests/aloemacs/mode-line-row.rkt`, `tests/aloemacs/mode-line-one-view.rkt` |
| 001 | `tests/aloemacs/mode-line-split-views.rkt` |

Affected existing tests under `tests/aloemacs/` may receive independent
golden, fitted-origin, remembered-height, and class/method-inventory
updates for the owning part (§5.3, §6.3). Each checkpoint names its exact
subset after searching. This permission is not an unrelated test cleanup.
001 may update 000's focused tests only to replace temporary visible-split
expectations with the completed contract, if they explicitly assert them.

Leave `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`,
`host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, all libraries and
language implementation, `SPEC.md`, `CHECKPOINTS.md`, and predecessor
documents untouched. `AloemacsEditor` retains exactly its eight fields
and gains no mode-line method. Direct editor `frame`, `frame-rows`,
`ensure-visible`, and page-motion methods remain unchanged. Every buffer
still owns one editor; each view still stores only IDs, origins, and lock.
The session retains its fourteen fields, including the one window tree.

The runner keeps zero or one path argument, the `aloemacs-editor` binding,
fit-before-frame using the same queried full terminal dimensions, one
frame String and one `term write` per drawn iteration, and the existing
current-editor quit check. The optional launch from the project root is:

```sh
racket host/racket/aloemacs-run.rkt [path]
```

Explicit non-goals are a language mode or mode name, filename dispatch,
faces or reverse video, selected-window styling, buffer menu, dirty mark,
position/percentage readout, lock marker, window number, pending-key
badge, unique-name decoration, mouse/buttons, segment registry, stored
format string, user-arranged mode line, second message row, new command,
key or Term chord, changed split minimums or lock policy, and another
editor/point/origin per view. No Text method, List index, kernel message,
Mirror, mutation, inheritance, macro, delegation, or new special form
belongs here. Evaluation is send; function objects run only through
`call`. Do not start faces, language modes, or Boids.

## 3. Closed display interfaces

### 3.1 Name row

Declare non-generic **`AloemacsModeLine`** in `file.aloe` immediately
after `AloemacsBuffers` and before `AloemacsView`, retaining the relative
order of every existing declaration. It has exactly `(fields)` and an
ordinary zero-argument constructor `(AloemacsModeLine new)`. It is a
fieldless display helper, not a language mode or a session component.
No instance is stored on the session, buffer, editor, or view.

Its display send is:

```text
(line row name width) -> String
line  : AloemacsModeLine
name  : String
width : Int
```

For `width <= 0`, return `""`; this is not a painted row. For positive
width, the exact character rule before safe cells is:

```text
label   = name append " "
clipped = label take width
row     = clipped append (width - clipped.len copies of "-")
```

There is no leading dash or space. The single separator after the name
is included only if it survives prefix clipping. If the name fills or
exceeds the width, only its prefix appears, with no separator, fill, or
ellipsis. No minimum fill is reserved at the expense of the name. Do not
trim, take a basename, resolve a path, center, scroll, or escape the name.
Use existing sends to generate only the needed hyphens; no library or
kernel repetition message is introduced.

| Name | Width | Raw row |
|---|---|---|
| `"untitled"` | 0 | `""` (not painted) |
| `"untitled"` | 1 | `"u"` |
| `"untitled"` | 8 | `"untitled"` |
| `"untitled"` | 9 | `"untitled "` |
| `"untitled"` | 12 | `"untitled ---"` |
| `"/cwd/a.txt"` | 8 | `"/cwd/a.t"` |
| `"/a"` | 4 | `"/a -"` |
| `""` | 4 | `" ---"` |

The helper accepts any String, including empty names and controls. Its
positive-width result has exactly `width` characters. It adds no ANSI
chrome or row separator and performs no effect. Rendering then sends
the completed clipped-and-filled row through existing `safe-cells`.
Every code 0–31 or 127 in the row becomes one space; other characters
copy through. For example, raw `"a\u001bb --"` at width 6 paints
`"a b --"`. Controls past the clip are never displayed. Row data is never
interpreted as ANSI. The existing ASCII, one-character-per-cell policy
stays; this adds no Unicode width model.

### 3.2 Derived text height

Add **`(rect text-rows) -> Int`** to `AloemacsWindowRect`, with no
arguments or fields:

```text
h = rect.rows
text-rows = if h >= 2 then h - 1 else h
```

This derived display height is distinct from `rect.rows`, which stays
the full leaf height for layout, split checks, locks, and divider work.
At a nominal zero height it returns zero; no such leaf is painted in a
visible layout. It does not change `x`, `y`, `columns`, or `rows`.

## 4. Geometry, fit, state, and echo

For positive terminal dimensions, the root rectangle remains
`(0, 0, columns, rows - 1)` when `rows >= 2`, otherwise
`(0, 0, columns, rows)`. The echo is still the terminal's last row when
reserved. Split arithmetic still reserves one divider cell, gives the
earlier child the leftover cell, and permits a new split at extent three.
Nominal layout, global positive-layout test, and locks are unchanged.

Within a leaf of width `w` and full height `h`:

| Height | Buffer text | Mode line |
|---|---|---|
| `h >= 2` | Top `h - 1` rows, width `w` | Last row, width `w` |
| `h < 2` | Whole leaf | Absent |

A mode line occupies only leaf cells. `|`, `-`, and `+` divider cells
remain exactly those produced by tree geometry, including next to a
mode line and between stacked views. A `-` in a name or in mode-line
fill is not evidence of a divider or junction.

Session `ensure-visible(columns, rows)` still obtains the selected leaf
rectangle from `windows.fit-rect`. In the completed series it sends
its width and **`rect.text-rows`** to the current editor's existing
`ensure-visible`. A too-small tree still fits the selected buffer in
the whole root rectangle; its text height follows the same rule. Mirror
the fitted origin only onto the selected view and remember the same full
terminal dimensions on `windows`. Unselected origins, including those
sharing the current buffer, stay exact until that view is selected and
fitted. No inactive editor is fitted or rebuilt for display.

Only fit's existing changes to the selected editor's origins and
remembered `text-rows`, the selected origin mirror, and remembered full
size are permitted. Fit preserves exact Text/focus, point, quit, history,
mark, paths, buffer order and IDs, locks, selection, tree shape, and all
echo/search/ring/pending/prompt/submission/waiting-command state.
Repeated fit at the same point and size remains idempotent.

Page Up/Down still use the editor's existing `page-distance`: `t - 1`
for remembered text height `t >= 2`, otherwise `t`. Thus fitting at the
new height can change their travel distance and fitted origin. No key,
motion algorithm, or second page-height store is added. A successful split
still invokes its existing one post-split fit; it acquires this same
text-height rule in 001. Other window/buffer commands retain their
existing fit timing and state transitions.

The normative frame follows fit at the same positive full dimensions,
as in the runner. Frame itself never fits, remembers size, changes point,
focuses the session zipper, installs an origin, or updates a name. The
selected cursor formula remains:

```text
text-row    = selected.y + point.line   - editor.scroll-row + 1
text-column = selected.x + point.column - editor.scroll-col + 1
```

For a single view or fallback, selected x/y for display are zero. After
fit the text cursor lies within that view's text rows, never its mode
line. With `rows >= 2` and an active prompt, finish instead at terminal
row `rows`, column `prompt.screen-column(columns)`. At terminal height
one, there is no echo or mode line, even with a prompt; finish on text.
Do not add a cursor clamp to compensate for an unfitted raw fixture.

The mode line reads exactly the displayed buffer's current `name`:
`"untitled"` for absent path, otherwise the full stored `path.text`.
Save-as, visit, find-file, selection, and kill/retarget change the line
only through their existing buffer results. Two views of one buffer
read the same name even at different origins; different buffers may
legally have identical names. No stored label, name-update transition,
filesystem call, or uniqueness policy is introduced.

Echo selection remains prompt first, then active search (`search:`,
`wrapped:`, or `failing:`), then `saved:` / `failed:` / idle current path
or `untitled`. Clip at full terminal width, then apply safe cells. Unused
echo cells stay blank from the clear. The mode line remains painted
during prompt and search, using neither their text nor the echo token.
Prompt owns the finished cursor when visible; search retains the text
cursor. Rendering never changes the three stored tokens `""`, `"saved"`,
and `"failed"`.

Window-command echo rules also stay exact: a command that leaves an
active prompt or search preserves its token; otherwise a successful
split stores `""`, a refused split/delete stores `"failed"`, and
other-window/successful delete clears the token only on buffer-ID change.
Same-buffer entry and lock toggle preserve it. On buffer change, entry
still clears search and preserves an active prompt. Input dispatch
remains quit, search, prompt, then pending/global idle map. All existing
save, visit, buffer, search, prefix, prompt, and window effects and resets
remain those of the predecessors. The new display and fit add no state
transition of their own beyond the height-dependent fit described above.

## 5. Layer 000 — row and one-view session

### 5.1 Exact one-view composition

For one leaf, or the existing too-small-tree fallback, let `h` be the
root rectangle's height, `t = root.text-rows`, and `editor` the current
editor. At `h < 2`, retain today's **complete** `single-frame` result,
including every intermediate cursor sequence. Terminal heights one and
two therefore keep their present frame bytes; height two still has its
echo row. Direct editor frames at every size keep their bytes.

At `h >= 2`, retain the complete `editor.frame(columns, t)` String as
the prefix of the session frame. Text rows remain that editor's unpadded
rows for the shorter height at its stored origin, including its existing
blank/raw-state branches. Derive `shown-mode` from current buffer `name`
and terminal width through §3.1, then safe cells. Append exactly:

```text
ESC[?25l ESC[h;1H shown-mode
ESC[rows;1H shown-echo
ESC[final-row;final-columnH ESC[?25h
```

The spaces and line breaks above separate pieces and add no bytes. The
mode-row address/write is inserted into the existing session suffix
after its hide and before its echo address. The existing echo selection,
address, final cursor restoration, and show stay. There is no extra
CRLF, clear, cursor restoration between mode and echo, or terminal write.
The cursor is hidden while painting both rows. The editor frame prefix
still contains its original intermediate show; the suffix hides it again.

For example, an empty untitled buffer at 12 columns and 4 terminal rows
has two blank text rows, `"untitled ---"` on row 3, and `"untitled"`
on row 4. With point at source line 3, column 0 in `zero\none\ntwo\nthree`,
fit at that size yields origin row 2, body `"two\r\nthree"`, mode row 3,
and text cursor `(2,1)`. Up to source line 2 holds origin 2 and moves
the cursor to `(1,1)`.

### 5.2 Intermediate fit boundary

Introduce both §3 sends in 000. Use the reduced text height for every
frame routed through the single-view composer: a lone leaf or a globally
too-small tree. For **several visible leaves**, leave the current tree
row composer and selected full-leaf-height fit unchanged until 001.
Determine that distinction by the existing single-leaf/positive-layout
decisions, not by counting mode-line-looking strings or the selected
rectangle alone. The fallback already composes only the selected buffer;
000 adds no split-row composition.

This staging permits the existing split commands to keep working while
000 is reviewed. Their geometry/echo/retarget rules are unchanged; tests
must account for any preceding one-view fit under the new height. 001
completes the fit rule for visible splits and removes that temporary
height distinction. Do not keep a second legacy single-view composer.

### 5.3 Migration and proof

Search existing exact session/runner frames, fit expectations, and class
inventories before the manager fixes its test scope. Current likely
sites include `echo-session.rkt`, `echo-runner.rkt`, `buffer-value.rkt`,
`buffer-session.rkt`, `file-session.rkt`, `keymap-prefix.rkt`,
`keymap-session.rkt`, `keymap-runner.rkt`, `runner-check.rkt`,
`safe-cells.rkt`, `search-session.rkt`, `minibuffer-value.rkt`,
`minibuffer-session.rkt`, the three `prompt-commands-*.rkt` proofs, and
the `windows-*.rkt` proofs. Search again; this is not an exhaustive list.
Many direct-editor or one-text-row tests require no change.

Update independent frame builders to take the displayed buffer name
separately from the echo label: during save/search/prompt those strings
can differ. Do not extract a name from `saved:` or a prompt. Expected
Strings must use literal independently computed rows/chrome, never the
production row/composer under test. Retain exact whole-frame assertions,
including text cursor and intermediate show/hide bytes. Do not replace
them with a name substring check or production-to-production comparison.

Migrate tall session expectations and their fit/page results to the new
text height. An unrelated old test may gain one terminal row to retain
its original text scenario, but its complete expected frame must include
the mode line. Keep existing assertions on point, text, exact Text focus,
history, mark, ring, prefix, search flags, prompt, submission, waiting
command, buffer/window ownership, and Fs/Term effects. Do not blanket
replace height literals in direct-editor fixtures. No constructor, key,
or command migration is required.

000's focused no-TTY tests must prove:

1. Fieldless helper construction, typed `row` and `rect.text-rows`
   results, and wrong arguments/receivers/arities rejected by checking.
   Fresh checked loads of `file.aloe` need no injected Fs/Term and cause
   no effect. Existing field and constructor inventories stay exact;
   class inventories gain only the named helper in its declared place.
2. Every §3.1 example, negative width returning empty, empty name,
   exact-width/one-spare-cell/fill cases, and long-name prefix clipping.
   Assert length and the raw row independently. Controls remain raw in
   the helper and become one space only in the painted row; cover ESC
   followed by `[31m`, tab, CR, LF, another low control, and DEL, with
   controls within and beyond the clip. Stored name/path remain exact.
3. Complete tall frames at widths 1, narrow, and wide, empty/text/blank
   buffers, untitled and bound names, nonzero vertical/horizontal
   origins, and saved/failed/idle/search/prompt echo states. Show that
   name and echo differ while search/prompt/status is active. Assert
   the exact editor prefix for the shorter height, absolute mode/echo
   addresses, one clear, and final text or prompt cursor.
4. Height-one and height-two terminal frames exactly matching their
   predecessor strings, including active prompt/search and stored
   outcomes; all direct editor goldens, including raw-state branches,
   unchanged. At height three, one buffer-text row and one mode row
   precede the echo. Mode-line fill remains distinct from blank text.
5. Minimal/idempotent fit and the example in §5.1; remembered `text-rows`
   and page distances at text heights one, two, and three. Snapshot all
   preserved payloads. Frame twice and at a different size to prove it
   reads only and does not fit or remember that size. Full terminal
   dimensions, selected origin mirroring, and fallback state retention
   remain correct; visible split rows/fit still follow the predecessor.
6. Existing save-as/visit/find-file/select/switch/kill results immediately
   supply the derived new name on the next frame without an extra
   effect. Include a refused operation and singleton kill to untitled.
   Existing regression proofs retain their full state and file effects.
7. A scripted runner double fits then paints/writes once before each
   read, observes resize from tall to short and back, and preserves save,
   prompt, quit, and exact effect counts. No runner product edit is used.

Stop with these focused tests and the full aloemacs suite green. Do not
paint mode lines in visible split leaves or change their fit in 000.

## 6. Layer 001 — split leaves and selected fit

### 6.1 Leaf rows and full composition

Keep tree `frame-rows(buffers, rect) -> (List String)`'s signature.
In each valid leaf, locate its buffer by the existing `view.buffer-id`
lookup in a temporary focused collection; do not install that focus.
For `h >= 2`, obtain exactly `h - 1` text rows through that buffer
editor's existing `frame-rows(w, h - 1, view.scroll-row, view.scroll-col)`.
Pad each text row on the right with spaces to width `w`. Append the
single §3.1 name row, passed through safe cells using that buffer's
editor. For `h < 2`, retain the existing all-text leaf rows. Every
visible leaf returns exactly `h` rows of exactly `w` characters.

Retain the current blank-leaf behavior on a raw dangling buffer-ID
lookup miss: all `h` rows are spaces, with no invented buffer name.
Program-created valid trees have no such miss. Missing/beyond-EOF text
at a valid inactive origin remains blank, but that buffer's mode line
still appears. Do not clamp an inactive origin or rebuild a temporary
editor. Preserve bounded `focus-at`/`next-lines` traversal without whole
Text materialization.

Below and Right compose these rows through the existing divider and
junction algorithms. The joined root still has exactly its full height
in rows of full terminal width, joined with CRLF and no trailing CRLF.
The complete multi-view ANSI frame stays:

```text
ESC[?25l ESC[2J ESC[H joined-root-rows
[ESC[rows;1H shown-echo, only when rows >= 2]
ESC[final-row;final-columnH ESC[?25h
```

These separators in the notation add no bytes. There is one clear, one
hide/show pair, one final selected/prompt cursor sequence, and one Term
write. No leaf emits ANSI chrome, a cursor, an echo row, or a clear.

An independent mixed example at 9 columns and 6 terminal rows uses
`Right(Below(A-top, A-bottom), B)`. A is named `/a`, with source lines
`abcdef`, `ghijkl`, `mnopqr`, `stuvwx`, `yz0123`; B is named `/b`, with
`ABCDE`, `FGHIJ`, `KLMNO`, `PQRST`, `UVWXY`. Origins are `(0,0)` for
A-top, `(3,1)` for A-bottom, and `(1,2)` for B. The composed root is:

```text
"abcd|HIJ "
"/a -|MNO "
"----+RST "
"tuvw|WXY "
"/a -|/b -"
```

Quotes delimit row Strings; they are not painted. Each row is nine
characters, including the trailing space in the first four rows.
A-bottom selected with point `(3,2)` finishes at `(4,2)`;
the echo is addressed separately on terminal row 6. The two left leaves
are height two, the right leaf height five; the horizontal divider and
its `+` remain geometry even next to filled mode rows.

### 6.2 Complete fit and resize behavior

Apply §4's `rect.text-rows` fit to every selected visible leaf in 001.
The full leaf rectangle and its top-left position remain unchanged.
Height-one leaves still fit at one row. Page motion follows that reduced
remembered text height. Successful splits use the existing post-split
fit at the new selected child's text height. The fresh child's origin
remains the captured pre-split origin, as the windows series specifies.
Entry/delete/lock/buffer operations retain their existing fit timing.

When any nominal leaf has a zero axis, use the existing global fallback
to §5's one-view composer and fit for the selected buffer. A fallback
root height at least two shows one mode line; a short root retains its
old frame. Preserve the full tree, selection, locks, and unselected
origins. Growth restores the tree's per-leaf lines and dividers. Recompute
geometry from the supplied size; frame does not record it. A positive
selected rectangle alone does not suppress a global fallback.

### 6.3 Migration and proof

001 migrates split-frame and selected-height expectations in
`windows-layout-and-rendering.rkt`, `windows-split.rkt`,
`windows-delete-and-other.rkt`, and `windows-lock.rkt`, plus any additional
affected split expectation discovered by search. Keep 000's completed
single-view bytes. Preserve all existing geometry, lock, ID, selected-
origin, buffer ownership, echo, and effect proofs; only the height-driven
fit/page outcomes and painted leaf rows change.

The focused tests construct trees directly, with independently computed
rectangles and full frames. No new command or key is needed. Prove:

1. Two tall leaves showing distinct buffers/names and two views of the
   same buffer at distinct origins. Include identical names on distinct
   IDs, width one, long names, safe controls, and a valid inactive origin
   beyond EOF that still paints its name. Snapshot all buffers, exact
   Text/focus, paths, origins, and the complete session around redraw.
2. Both split directions, mixed nesting including §6.1, T and cross
   junctions, odd/even extents, all-short leaves, and a tall/short pair.
   Height-one leaves paint only text; height-two leaves have one text
   row and one mode row. Dividers remain geometry when a buffer name
   contains `-`, `|`, or `+`. Assert exact row count/width and full ANSI.
3. Different selected leaves translate the one cursor correctly. A
   bottom/right selection requiring scrolling is fitted within its
   reduced text rows. Only selected origin, its editor's remembered
   height, and full-size bookkeeping change. Include shared-buffer
   views with different origins, locked views, minimal/idempotent fit,
   and page motions at selected text heights one, two, and three.
4. Prompt/search/status keep all per-view names visible, the echo at
   full width, prompt cursor on the echo, and search cursor on selected
   text. One-row split layouts retain their complete predecessor bytes
   and have no mode lines or echo. All-short positive layouts likewise
   retain their previous frame and fit results.
5. Shrink triggers the global fallback even with a positive selected
   leaf, at root heights one and at least two; grow restores the same
   tree. Compare fallback bytes with the single-view composer for the
   same selected buffer/state. Verify locks and inactive origins persist.
   Include the existing raw dangling-ID blank behavior without giving
   it a fictitious name.
6. Existing split/other/delete/lock, buffer retarget, save-as, visit,
   find-file/select, and shared edit/undo regressions keep their state
   and Fs effects while their next frames derive the right names.
   Real split commands retain their extent-three minimum, echo outcomes,
   original selection and fresh pre-fit origin; mode lines impose no
   extra split refusal or lock condition.
7. A scripted Term sequence drives the existing split/select/edit/
   prompt/save/delete/resize/quit paths with fit before each frame and
   one write per drawn iteration. Compare independent full strings and
   exact read/write/Fs counts. Keep the runner and Term untouched.

Stop with the focused split proof, all earlier focused proofs, and the
full aloemacs suite green. No following exploration belongs to 001.

## 7. Verification and acceptance

Each implementer writes focused tests first, observes the missing
behavior fail, implements its one slice, and verifies from the project
root. Every agent test command includes `TMPDIR=/tmp` and `-y`, even
when a predecessor omits them.

For **aloemacs-mode-line 000**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/mode-line-row.rkt tests/aloemacs/mode-line-one-view.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-mode-line 001**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/mode-line-row.rkt tests/aloemacs/mode-line-one-view.rkt tests/aloemacs/mode-line-split-views.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

The aloemacs suite is the required regression bar. No new timing gate,
benchmark, wider suite, or physical TTY hand check is required. Retain
existing tests and their substantive assertions. Source review also
confirms unchanged existing fields/constructors/commands/runner, derived rows only,
selected-only fit, no installed inactive focus/origin, bounded Text
rendering, and no extra host effect. Do not commit `compiled/`. After a
`.rkt` edit, run the tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching;
launchers do not rebuild bytecode. `.aloe` edits need no rebuild.

The completed series is accepted when all of these are true:

1. Every tall view paints its displayed buffer's exact derived name
   with the specified prefix clipping, separator, safe cells, and
   hyphen fill in its last leaf row. A short view uses all its rows
   for text. Each painted mode row is exactly the leaf width.
2. One-view terminal heights one and two retain their complete prior
   frame bytes; direct editor frames remain exact at every size. Tall
   one-view frames contain the shorter editor frame prefix, mode line,
   and specified session suffix. Split frames retain one ANSI envelope.
3. Leaf rectangles, split arithmetic/minimums, dividers/junctions, and
   locks stay exact. Each tall leaf gets its own name, including shared
   buffers. A too-small tree shows only selected with the same row rule
   and restores the tree display when it grows.
4. Selected fit and page motion use the leaf's buffer-text height;
   unselected origins stay until selected fit. The fitted finished
   cursor is on text or a visible active prompt, never a mode line.
   Frame is pure and uses no filesystem or terminal effect itself.
5. Idle keys, search, quit, visit, save, switch, kill-buffer, prompt
   commands, prefixes, splits, entry, delete, and lock keep their
   existing transition rules and file effects, with only the specified
   height-dependent fit/page results. Text, point except existing motion,
   quit, history, mark, ring, search flags, echo tokens, pending, prompt,
   submission, waiting command, buffer zipper, IDs, tree, and locks
   acquire no mode-line state or extra update.
6. The echo remains the one message row under the tree with its existing
   priority, safe clipping, three tokens, window-command preservation,
   and prompt cursor. Search/prompt/status cannot replace a mode line.
7. All focused proofs and `TMPDIR=/tmp raco test -y tests/aloemacs` pass
   at each checkpoint stop without a TTY or product changes beyond
   `file.aloe` and the permitted tests. No later feature, language law,
   runner/Term change, or global checkpoint is introduced.

This spec is accepted. The checkpoint manager writes
**aloemacs-mode-line 000 only**, then stops for its own review boundary.
If you have been told to read this file as the manager assignment, it
is the whole assignment; do not write later checkpoints in advance.
