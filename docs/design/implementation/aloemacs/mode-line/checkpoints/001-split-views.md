# aloemacs-mode-line 001 — Split leaves and selected fit

**Status: Ready to implement.** Human review of this checkpoint precedes
its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice,
and stop when green.

## Goal

Paint the existing derived buffer-name row in every tall visible split
leaf. Fit the selected editor at that leaf's reduced text height and
migrate the independent split-frame and height expectations. Complete
the mode-line series without changing window geometry or commands.

Keep 000's one-view and global-fallback frame bytes. Height-one leaves
remain all text. Stop with the focused proofs and full aloemacs suite
green; add no face, language mode, buffer menu, or following exploration.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-mode-line 001**, filed as
  `checkpoints/001-split-views.md`. This is a local editor checkpoint,
  not a number in the language spine.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute through `call`. Use existing String,
  Int, and List sends and ordinary checked recursion.
- Accepted [../spec.md](../spec.md) §§1–4 govern authority, boundaries,
  the existing row helper, derived height, preserved geometry/state,
  echo, and the completed fit rule. All of §6 and §7's 001 verification
  govern this slice. §5 describes the completed predecessor and its
  one-view bytes; §5.2's temporary visible-split fit ends here.
  Predecessor specs named in §1 govern preserved behavior, especially
  [windows/spec.md](../../windows/spec.md).
- [000-one-view.md](000-one-view.md) is implemented in the current
  working tree. Its helper, rectangle send, one-view composer, fallback
  fit, focused tests, and regression migrations are the starting point.
  Preserve that work, including changes not yet committed. Do not redo
  000 or edit its checkpoint. The user's request for the next checkpoint
  advances planning to this slice. At issuance, the two 000 focused
  proofs pass (10 tests), the full aloemacs suite passes (447 tests),
  and `git diff --check` is clean.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  `AloemacsModeLine.row` and `AloemacsWindowRect.text-rows` already exist.
  Tree `frame-rows` still gives a valid leaf its full height of padded
  text. Session `ensure-visible` currently uses reduced height only for
  a single leaf/global fallback and full height for positive splits.
  Those are the two product seams this checkpoint changes.
- The unchanged [runner](../../../../../../host/racket/aloemacs-run.rkt)
  fits, frames, writes once, then reads at the queried full dimensions.
  Use its existing `run-aloemacs-with-hosts` seam and the checked driver
  for counted Fs/scripted Term proofs. No physical TTY is required.

This slice changes one product file, creates one focused proof, and
migrates six existing test files. It adds no constructor, class, command,
or test infrastructure. If finishing would require compaction, stop and
return the size finding to the manager; do not split or widen it yourself.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: change the valid `Leaf` branch of
  `AloemacsWindowTree.frame-rows` and complete
  `AloemacsSession.ensure-visible`'s text-height rule. Ordinary internal
  composition helpers may be used if needed. Keep the existing sends'
  signatures, the two loads, and all declaration order unchanged.
- Create `tests/aloemacs/mode-line-split-views.rkt` before product edits.
  Use the existing checked driver, `rackunit`, counted Fs doubles,
  scripted Term doubles, and independent raw tree/buffer constructors.
- The following **six existing test files**, only for split rows,
  height-driven fit/page consequences, and the explicit 000 staging
  expectation. Paths in the table are relative to `tests/aloemacs/`.

  | File | Permitted migration |
  |---|---|
  | `windows-layout-and-rendering.rkt` | Migrate complete mixed/shared-buffer/control/junction frames, selected origins and remembered heights, page outcomes, growth, and scripted split frames. Keep nominal geometry, direct editor `frame-rows`, one-view/fallback strings, inventories, and purity/effect assertions. |
  | `windows-split.rkt` | Migrate post-split fitted heights/origins, full T/cross/shared-edit frames, history origins captured after a changed fit, page consequences, and split/resize/save runner goldens. Retain minimums, allocation tables, IDs, original selection, fresh pre-fit child origins, locks, echo matrices, buffer operations, and Fs/Term counts. |
  | `windows-delete-and-other.rkt` | Migrate visible split frames and explicit selected fit, including prompt/search/token matrices, shared edits/undo, and runner steps. Entry and deletion still do not fit themselves. Keep promoted-tree geometry, locks, resets, IDs, one-view/fallback frames, and host effects. |
  | `windows-lock.rkt` | Migrate visible split frames, growth's remembered height and origins, and split runner steps. Keep bit-only toggle, lock guards over full nominal rectangles, prompt/retarget/kill behavior, direct raw page sends that had no new fit, one-view/fallback strings, and host effects. |
  | `windows-state.rkt` | Migrate only positive visible-layout remembered-height/fit expectations in the selected-rectangle/resize proof. Its `(80,24)` case currently remembers five rows for the selected leaf; it must remember four. Keep short/global-fallback cases, complete state reconstruction, selection/retarget rules, and the one-view golden. |
  | `mode-line-one-view.rkt` | Replace only the explicitly marked “000 staging for 001” growth height and visible-split full frame with the completed contract. Preserve its single-view/fallback goldens, state snapshots, inactive leaf/lock proof, and all other 000 requirements. |

The manager searched constructed `Right`/`Below` trees, real split/entry/
delete commands, exact frames, explicit fits, remembered heights, and page
expectations. `windows-state-foundation.rkt` constructs split trees only
for tree/value checks; its session fit/frame fixtures are single leaves.
`windows-buffer-identity.rkt`'s fit is also single-view. Neither needs
migration. Other session/runner proofs remain covered by the full suite.
No class or method inventory migration is required in 001.

### Must leave untouched

- The existing row helper and rectangle `text-rows` contract; session
  `single-frame`, `multi-frame` ANSI envelope, and frame routing; tree
  `Below`/`Right` joining, divider/junction queries, blank-on-lookup-miss
  behavior, nominal layout, `fit-rect`, and all window commands/guards.
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, every
  other product module, `host/racket/aloemacs-run.rkt`,
  `host/racket/term.rkt`, Fs/Term interfaces, all `aloe/` and `lib/` code.
  Add no dependency, load, host capability, runner argument, or build step.
- Existing fields/constructor arities: editor eight fields, session
  fourteen, buffer three, view five, windows four, rectangle four. Keep
  IDs, one editor per buffer, one point/history, and origins/lock per view.
  Store no helper, name row, second editor, or page-height field.
- `tests/aloemacs/mode-line-row.rkt` and every existing test not listed
  above. Create no shared helper module or later focused test file.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  the accepted design, and checkpoint documents during implementation.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening it. Preserve substantive
Text/focus, point/history, state, ownership, geometry, origin, lock, and
host-effect assertions. Do not use migration for unrelated test cleanup.

## Slice requirements

### 1. Per-leaf rows using the existing buffer name

Keep the tree send's signature:

```text
(tree frame-rows buffers rect) -> (List String)
tree : AloemacsWindowTree
buffers : AloemacsBuffers
rect : AloemacsWindowRect
```

In a valid leaf, use the existing lookup of `view.buffer-id` in a local
focused collection. Read that buffer's editor and derived `name`; never
install the temporary focus in the session zipper. Let `w = rect.columns`
and `h = rect.rows`.

- At `h >= 2`, request `h - 1` text rows through that editor's unchanged
  `frame-rows(w, h - 1, view.scroll-row, view.scroll-col)`. Right-pad each
  text row with spaces to width `w`. Append one completed mode row as
  the leaf's final row.
- At `h < 2`, retain the existing full-height all-text rows and padding.
  Every positive visible leaf returns exactly `h` rows of width `w`.
- On a raw dangling buffer-ID lookup miss, retain exactly `h` all-space
  rows; do not invent `untitled` or another label. For a valid inactive
  origin past EOF, text is blank but the buffer's mode row still appears.

The mode row comes from `(AloemacsModeLine new) row buffer.name w`,
followed by that buffer editor's `safe-cells`. The helper appends one
space to the exact stored name, prefix-clips to width, and fills only
the remaining cells with `-`. Names that fill/exceed width have no fill
or ellipsis. `name` is `untitled` for absent path, otherwise full
`path.text`, including legal identical names on different buffer IDs.
Controls 0–31 and 127 become one space after clipping; stored data stays
exact. No ANSI or row separator belongs in a leaf row.

Do not fit/clamp an inactive origin, rebuild a temporary editor, or
materialize the whole Text. Retain bounded `focus-at`/`next-lines`
rendering. Two views of one buffer use the same current name and Text
with their own stored origins.

### 2. Preserve tree geometry and the complete ANSI frame

Keep the root rectangle `(0,0,columns,rows - 1)` at terminal heights
at least two, otherwise `(0,0,columns,rows)`. Full leaf rectangles,
split extent-three minimums, odd/even allocation, divider cells, and
locks stay exact. `-`, `|`, and `+` inside a name or mode fill never
affect junction discovery.

Join the new leaf rows through the existing `Below`/`Right` algorithms.
The joined root has exactly its full height of full-width rows, joined
with CRLF and no trailing CRLF. Keep the multi-view frame exactly:

```text
ESC[?25l ESC[2J ESC[H joined-root-rows
[ESC[rows;1H shown-echo, only when rows >= 2]
ESC[final-row;final-columnH ESC[?25h
```

Notation separators add no bytes. There is one clear, one hide/show
pair, one final selected/prompt cursor address, and one Term write per
drawn iteration. No leaf emits chrome, a cursor, echo, or clear.

Reproduce spec §6.1 independently at 9 columns/6 terminal rows:
`Right(Below(A-top,A-bottom),B)`. A is `/a` with lines `abcdef`,
`ghijkl`, `mnopqr`, `stuvwx`, `yz0123`; B is `/b` with `ABCDE`,
`FGHIJ`, `KLMNO`, `PQRST`, `UVWXY`. Origins are `(0,0)`, `(3,1)`,
and `(1,2)` respectively. Its five root rows are:

```text
"abcd|HIJ "
"/a -|MNO "
"----+RST "
"tuvw|WXY "
"/a -|/b -"
```

Quotes delimit Strings; trailing spaces in the first four rows count.
Selecting A-bottom at point `(3,2)` finishes at terminal `(4,2)`.
With idle echo, append the row-6 echo address and `/a`, then the final
cursor/show. Assert that whole independent frame, not just these rows.

### 3. Complete selected-only fit and page behavior

Session `ensure-visible(columns,rows)` obtains `windows.fit-rect` as
before. Send that rectangle's width and **`rect.text-rows`** to the
current editor's unchanged `ensure-visible` for every layout. Remove
000's temporary single-view/positive-split height distinction. Keep
`fit-rect`'s global layout decision and fallback; do not replace them
with a selected-rectangle-only test.

`rect.text-rows` is `h - 1` for `h >= 2`, otherwise `h`. The editor
remembers that text height; windows still remembers the full queried
terminal dimensions. Mirror the fitted origin only onto the selected
view. Preserve every unselected origin, including views of that buffer,
and every inactive editor. Repeated fit at the same size/point is
idempotent and moves origins only as far as required.

Fit preserves exact Text/focus, point, quit, history, mark, paths, IDs,
buffer zipper, tree shape, selection, locks, echo/search/ring/pending/
prompt/submission/waiting-command payloads. Only selected origins,
selected editor remembered height, and full-size bookkeeping change.
Subsequent existing edits may capture the newly fitted origin in their
UndoFrame; retain that history proof when migrating fixtures.

Page Up/Down retain the existing distance: `t - 1` at remembered text
height `t >= 2`, otherwise `t`. Prove selected text heights one, two,
and three and their resulting point/origin behavior. Change no key,
motion algorithm, or independent raw page send without a preceding fit.

Real successful splits still keep the original selected view, capture
the fresh child's origin before fitting, and perform the existing one
post-split fit. That fit now uses the selected child's text height.
Short children remain legal; add no mode-line split refusal or lock
condition. Entry/delete/lock/buffer operations retain their fit timing.

After fit at the same dimensions, the selected text cursor remains:

```text
row    = selected.y + point.line   - editor.scroll-row + 1
column = selected.x + point.column - editor.scroll-col + 1
```

It lies on text, never the mode line. Frame never fits or clamps an
unfitted raw fixture, remembers size, changes names, installs origins/
focus, or performs Fs/Term effects. Test repeated redraw and redraw at
a different supplied size without changing any stored state.

### 4. Echo, prompt, fallback, and growth

All tall leaves retain their own names during prompt/search/status.
Echo remains one full-width bottom row: prompt first, then active search
(`search:`, `wrapped:`, `failing:`), then saved/failed/idle current name.
Clip at terminal width, then apply safe cells. Rendering preserves the
three stored tokens `""`, `"saved"`, and `"failed"`.

At `rows >= 2`, an active prompt owns the final cursor at
`(rows,prompt.screen-column(columns))`; search keeps the selected text
cursor. At terminal height one, neither echo nor mode row is visible,
even with a prompt. One-row splits and all-short positive layouts retain
their complete predecessor frame and fit results. Preserve existing
input precedence and all command token/reset/prompt/search rules.

If any nominal leaf has a zero axis, use the existing global fallback
to 000's one-view composer and fit for the selected buffer. A positive
selected leaf alone does not suppress fallback. A fallback root of
height at least two has its mode row; short roots keep their old bytes.
Preserve the whole tree, selection, locks, IDs, and inactive origins.
Growth restores the same tree with per-leaf names and dividers.

### 5. Focused proof and independent regression migration

Write `mode-line-split-views.rkt` first and observe missing leaf-row and
visible-split-fit behavior fail before product edits. It owns all of
spec §6.3's focused proof:

1. Distinct buffers/names and shared-buffer views at different origins;
   distinct IDs with identical names; width one, long prefix clipping,
   safe controls within/beyond the clip, and valid inactive origins
   beyond EOF. Snapshot all buffers, exact Text/focus, paths, origins,
   zipper, and complete session around redraw. Include the raw
   dangling-ID all-blank leaf.
2. Both split directions, the exact mixed example above, T/cross
   junctions, odd/even sizes, all-short layouts, and a tall/short pair.
   Height two means one text row plus one mode row; height one is all
   text. Include names containing divider punctuation. Assert independent
   full rows, exact row count/width, and complete ANSI strings.
3. Different selected leaves and translated cursors, bottom/right
   scrolling at reduced text height, shared-buffer/locked views,
   minimal/idempotent fit, selected-only state changes, and page behavior
   at text heights one/two/three. Keep full terminal size bookkeeping.
4. Prompt/search/saved/failed/idle frames with per-view names, full-width
   echo, exact prompt/text cursor, and preserved tokens. Keep exact
   predecessor one-row and all-short positive frames/fit.
5. Shrink into global fallback despite positive selected geometry at
   root height one and at least two; grow to the same tree. Assert
   independent fallback strings and equality with the retained one-view
   composer for that selected buffer/state. Keep locks and inactive
   origins; production-to-production equality is only a supplementary
   routing check, never the golden oracle.
6. Next frames after existing split/other/delete/lock, retarget, save-as,
   visit, find-file/select, and shared edit/undo results. Assert names
   follow buffer results with no extra Fs effect. Keep command minimums,
   selection, fresh pre-fit origins, echo outcomes, and full state proofs.
7. A scripted Term sequence through existing split/select/edit/prompt/
   save/delete/resize/quit paths, fitting before each frame, with one
   write per drawn iteration. Compare independent complete strings and
   exact read/write/Fs counts through existing host seams. Keep runner
   and Term product code untouched.

Compute expected rectangles, text rows, names, safe cells, and ANSI in
Racket from explicit fixture data, independently of production helpers.
Builders take each displayed buffer name separately from the echo; do
not extract a name from a saved/search/prompt label. Preserve whole-frame
goldens and substantive state/effect assertions rather than replacing
them with substrings or production-to-production comparisons.

Migrate only painted split rows and consequences of the reduced selected
fit/page height in the six named files. Do not blanket-change terminal
sizes or direct-editor fixtures. If an unrelated text scenario needs
more height, its new full expected frame must include all leaf mode rows
and retain its original state/geometry purpose. Keep 000's single-view
and global-fallback bytes, helper/type/field inventories, and direct
editor frame/row proofs exact.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/mode-line-row.rkt tests/aloemacs/mode-line-one-view.rkt tests/aloemacs/mode-line-split-views.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test invocation includes `TMPDIR=/tmp` and `-y`. The latter
rebuilds changed Racket bytecode and dependents. Do not commit `compiled/`.
After a `.rkt` edit, run tests or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before launching;
launchers do not rebuild. `.aloe` edits need no rebuild. No physical TTY,
wider suite, new timing gate, benchmark, or hand check is required.

Complete when the new split proof, both 000 focused proofs, and the full
aloemacs suite pass; the diff has no whitespace errors; and source review
confirms the two bounded product changes, pure derived rows, selected-only
fit, unchanged existing fields/constructors/commands/runner, bounded Text
rendering, no installed inactive focus/origin, and no extra host effect.
Apply spec §7's completed-series acceptance conditions. Report files
changed and verification results. Stop when green; do not write another
checkpoint or start faces, language modes, a buffer menu, or Boids.
