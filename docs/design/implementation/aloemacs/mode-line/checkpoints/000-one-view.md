# aloemacs-mode-line 000 — Name row and one-view session

**Status: Ready to implement.** Human review of this checkpoint precedes
its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice,
and stop when green.

## Goal

Add the pure buffer-name row and derived leaf text height. Reserve and
paint that row in a tall one-view session and in the existing globally
too-small-tree fallback. Fit the selected buffer at the matching reduced
text height and migrate the existing independent expectations.

Terminal heights one and two retain their complete frame bytes. Direct
editor frames retain their bytes at every size. Visible splits retain
their existing all-text leaf rows and selected full-leaf-height fit for
this checkpoint. Their mode lines and reduced fit belong to 001.

Stop after the focused proofs and full aloemacs suite pass. Add no
window command, language mode, face, or following exploration.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-mode-line 000**, filed as
  `checkpoints/000-one-view.md`. This is a local editor checkpoint.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute through `call`. Use existing String,
  Int, and List sends and ordinary checked recursion.
- Accepted [../spec.md](../spec.md) §§1–2 govern predecessors, authority,
  the two-part partition, file boundaries, and non-goals. All of §3,
  §4 subject to §5.2's staging, all of §5, and §7's 000 verification
  govern this slice. §6 describes 001 and supplies no implementation
  work here. Predecessor specs named in §1 govern preserved behavior.
- Windows 000–006 is implemented in the current checkout, ending at
  [006-lock.md](../../windows/checkpoints/006-lock.md). Its final human
  review remains; this series uses the accepted
  [windows geometry](../../windows/spec.md) without waiting for it.
  Report a blocking windows defect for that series instead of repairing
  it here. Text through Prompt commands are implemented predecessors.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  `AloemacsBuffer.name` already derives `"untitled"` or full `path.text`.
  `frame` routes a single tree or a globally nonpositive layout to
  `single-frame`; positive split layouts use `multi-frame`. `fit-rect`
  already returns the selected rectangle or the full fallback root.
  `ensure-visible` currently sends that rectangle's full height to the
  current editor, mirrors its origin, and records full terminal size.
- The unchanged [runner](../../../../../../host/racket/aloemacs-run.rkt)
  fits, frames, writes once, then reads at the queried full dimensions.
  Use its existing `run-aloemacs-with-hosts` seam for runner proofs.

The inventory below makes this one slice: one product file, two focused
test files, and bounded migrations through existing frame builders,
literal goldens, fit fixtures, and ten class inventories. There is no
constructor migration or new test infrastructure. If finishing would
require compaction, stop and return the size finding to the manager;
do not divide or widen the assignment yourself.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: declare `AloemacsModeLine`, add
  `AloemacsWindowRect.text-rows`, and change only single-view composition
  and its session fit branch, with ordinary internal helpers as needed.
  Keep the two loads and relative order of every existing declaration.
- Create `tests/aloemacs/mode-line-row.rkt` and
  `tests/aloemacs/mode-line-one-view.rkt` before product edits. Use the
  existing checked driver, `rackunit`, counted Fs doubles, and scripted
  Term doubles. These files own new behavior and preservation proofs.
- The following **26 existing test files**, only for the listed
  mode-line class inventory, independent frame, or height-driven fit
  migration. Paths in the table are relative to `tests/aloemacs/`.

  | File | Permitted migration |
  |---|---|
  | `buffer-value.rkt` | Insert the helper in the exact class list; migrate singleton fit formulas, remembered heights, frame builder, and tall saved/failed/idle goldens. |
  | `buffer-session.rkt` | Migrate the frame builder, selected-buffer tall frames, fitted editor height/origin, and next frames after switch, addition, and kill. |
  | `echo-session.rkt` | Migrate the frame builder and tall frames, minimal fit, resize, and page results. Keep short frames and echo-token transitions. |
  | `echo-runner.rkt` | Migrate independent full runner strings and height-driven scrolling; retain every Term event and save effect. |
  | `file-session.rkt` | Migrate the final tall session golden, including an independent shorter editor prefix and separate buffer-name/echo rows. Retain file/key/save assertions. |
  | `file-runner.rkt` | Migrate the literal initial, visited, edited, and saved frames and derived expected strings; retain all startup/refusal/Fs/Term assertions. |
  | `keymap-prefix.rkt` | Migrate the frame builder and tall arm/cancel/resize goldens; preserve prefix state, history, and short frames. |
  | `keymap-session.rkt` | Migrate the explicit remembered-height assertion in `rich!` and any consequences of that preceding one-view fit. Command/map inventories and dispatch rules stay exact. |
  | `keymap-runner.rkt` | Migrate the frame builder and tall scripted expectations with a separate buffer name during saved/failed echoes. Retain prefix, one-row, and effect proofs. |
  | `runner.rkt` | Migrate `empty-frame` and `x-frame`; retain source/order, injection, checked startup, write/flush, rebinding, and quit proofs. |
  | `runner-check.rkt` | Migrate the independent frame builder and fixed-size Down-cycle golden. Keep preparation counts, resize assertions, and the existing timing threshold. |
  | `viewport-runner.rkt` | Migrate its frame builder, explicit ANSI strings, and height-driven vertical/resize/horizontal runner expectations. Retain complete event order. |
  | `safe-cells.rkt` | Migrate its tall visited-session golden and builder. Direct editor control goldens and height-two echo goldens stay exact. |
  | `search-session.rkt` | Migrate tall search/wrapped/failing/status frames and builder with the buffer name supplied separately. Preserve flags, query, origin, token, and short-frame assertions. |
  | `minibuffer-value.rkt` | Insert the helper in the exact class list; migrate the fit formula, remembered heights/origins, and tall prompt/inactive/status frames and builder. Keep direct editor proof at its actual supplied height. |
  | `minibuffer-session.rkt` | Migrate tall active/control/preservation frames and builder; retain prompt, submission, waiting-command, and one-row proofs. |
  | `prompt-commands-find-file.rkt` | Insert the helper in the class list; migrate tall prompt/result frames, runner builder, and scripted goldens, passing each actual buffer name independently. Retain command/constructor-tail inventories and all Fs effects. |
  | `prompt-commands-save-as.rkt` | Migrate tall prompt/saved/refused/canceled frames, runner builder, and scripted goldens, including old/new bound names. Retain commands, targets, saved text, and effect counts. |
  | `prompt-commands-select-buffer.rkt` | Migrate tall prompt/selected/refused/canceled frames, runner builder, and scripted goldens with source/destination names. Retain exact-name matching, zipper order, command inventories, and zero extra effects. |
  | `windows-buffer-identity.rkt` | Insert only the helper in the exact class list. Buffer IDs, fields, constructors, and identity/retargeting assertions stay exact. |
  | `windows-state-foundation.rkt` | Insert the helper in the exact class list; migrate one-view fit heights and the independent one-view frame builder/goldens. Preserve all field shapes, origin mirrors, and size/state proofs. |
  | `windows-state.rkt` | Insert the helper in the class list; migrate its explicit one-view golden and any global-fallback fit fixture. Preserve positive visible-split fit results. |
  | `windows-layout-and-rendering.rkt` | Insert the helper in the class list; migrate the single-frame builder, lone-leaf and tall global-fallback frames/heights. Keep direct editor rows, nominal geometry, visible split rows, and visible split fit/page results. |
  | `windows-split.rkt` | Insert the helper in the class list; migrate only one-view/fallback frames and consequences of preceding one-view fit in split/runner fixtures. Keep visible split composition and post-split full-leaf-height fit. |
  | `windows-delete-and-other.rkt` | Insert the helper in the class list; migrate one-view frames after deletion and one-view/fallback runner steps. Preserve entry/delete fit timing, visible splits, locks, resets, and effects. |
  | `windows-lock.rkt` | Insert the helper in the class list; migrate one-view frames before/after split/delete and tall fallback frame/height fixtures. Keep visible split composition/fit, lock geometry, and command outcomes. |

The search includes exact ANSI literals, session/runner frame builders,
`ensure-visible`, remembered `text-rows`, page results, and declaration
inventories. The ten exact class lists are in `buffer-value`,
`minibuffer-value`, `prompt-commands-find-file`, and the seven named
`windows-*` files. No additional migration was found in direct-editor
proofs, `kill-session.rkt`, or `undo-session.rkt`: their relevant checks
use short frames or compare unchanged session transitions.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, every
  other product module, and the tree's existing `frame-rows`/divider
  composer in `file.aloe`. Do not change visible-split fit in 000.
- Every existing test not named above. Create no split-focused test,
  shared helper module, or later focused file.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, Fs/Term
  interfaces, all `aloe/` and `lib/` code. Add no dependency, load,
  host capability, runner argument, or build step.
- Existing fields and constructors: editor eight fields, session
  fourteen, buffer three, view five, windows four, rectangle four;
  the tree, commands, keymaps, and constructor arities stay exact.
  The only new class is the fieldless helper. Add no editor method.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor documents,
  the accepted design, and checkpoint documents during implementation.

If another file or design change proves necessary, stop and return this
checkpoint to the manager instead of widening it. Preserve substantive
Text/focus, state, ownership, origin, geometry, and host-effect assertions
in all migrated tests; no unrelated cleanup belongs here.

## Slice requirements

### 1. Pure name row and derived height

Declare non-generic `AloemacsModeLine` immediately after `AloemacsBuffers`
and before `AloemacsView`, with exactly `(fields)` and ordinary
zero-argument construction `(AloemacsModeLine new)`. Store no instance
on another object. Its send is:

```text
(line row name width) -> String
line : AloemacsModeLine; name : String; width : Int
```

At `width <= 0`, return `""`. At positive width, append one space to
`name`, take that String's prefix of at most `width` characters, then
append exactly the remaining number of `-` characters. The result has
exactly `width` characters. A full-width name consumes the whole row;
no fill is reserved. Do not add ANSI, CRLF, ellipsis, leading chrome,
basename/unique-name decoration, trimming, or effects. Generate only the
needed fill with existing sends. Controls remain raw in this helper.

Add `(rect text-rows) -> Int` with no arguments or fields to
`AloemacsWindowRect`: return `rows - 1` for `rows >= 2`, otherwise
`rows`. Keep `rect.rows` and all geometry/lock/split checks unchanged.

Write `mode-line-row.rkt` first and observe the missing behavior fail.
Prove both checked result types, wrong receivers/types/arities rejected,
fieldless construction, exact declaration placement, unchanged existing
fields/arities, fresh loads without injected Fs/Term or effects, and the
height rule including zero, one, two, and taller rectangles. Independently
assert each §3.1 example, negative width, empty name, full-width name,
one spare cell, fill, and a long clipped prefix, including exact lengths.

### 2. One-view frame and existing global fallback

Compute the existing root from full supplied terminal dimensions:
`(0, 0, columns, rows - 1)` when `rows >= 2`, otherwise
`(0, 0, columns, rows)`. Let `h = root.rows` and `t = root.text-rows`.
The existing single-leaf/global-positive-layout routing stays exact.

For `h < 2`, keep the complete predecessor `single-frame` bytes,
including intermediate cursor sequences. For `h >= 2`, keep the complete
`editor.frame(columns, t)` String as the prefix. Its text is unpadded,
including existing blank/raw-state branches. Derive the name row from
the current buffer's `name`, then send the finished clipped-and-filled
row through the current editor's existing `safe-cells`.

Insert its absolute address and content into the existing session suffix
after the suffix hide and before the echo address. The suffix is exactly:

```text
ESC[?25l ESC[h;1H shown-mode
ESC[rows;1H shown-echo
ESC[final-row;final-columnH ESC[?25h
```

Spaces/newlines above separate pieces and add no bytes. Keep the editor
prefix's intermediate show, one clear overall, the suffix hide while
painting both rows, and its final restoration/show. Add no CRLF or extra
cursor restoration, clear, frame, or Term write. Keep one single-view
composer, including its short branch.

The final text cursor remains point minus stored origin plus one on each
axis. At terminal height at least two, an active prompt instead finishes
at `(rows, prompt.screen-column(columns))`. Height one finishes on text
even with a prompt. Do not clamp a raw, unfitted fixture's cursor.

Keep echo priority: prompt, then active search, then saved/failed/idle
label. Clip the echo at full terminal width and apply safe cells. Keep
the three stored tokens `""`, `"saved"`, and `"failed"`, all command
preservation/reset rules, and existing input dispatch exact. The name row
always reads the buffer name, including during search, prompt, or status.

Painted controls 0–31 and 127 become one space after clipping; other
characters copy through under the existing one-character-per-cell
policy. Prove ESC followed by `[31m`, tab, CR, LF, another low control,
and DEL within and beyond the clip. Compare raw helper output, independent
painted bytes, and exact unchanged stored path/name.

### 3. Fit at the matching text height

Session `ensure-visible` still uses `windows.fit-rect`. For a lone leaf
or a globally too-small tree, send its width and `rect.text-rows` to the
current editor's existing `ensure-visible`. For several positive visible
leaves, send its width and full `rect.rows`, as before. Determine this
distinction through the same existing tree `single?` and global
`positive-layout?` decisions used by `frame`. A positive selected leaf
alone does not suppress global fallback.

Keep fit timing, selected origin mirroring, and remembered full terminal
dimensions. Only the selected editor's origins/remembered text height,
selected view origin, and full-size bookkeeping may change. Preserve
inactive origins, including shared-buffer views, tree, locks, selection,
IDs, zipper, exact Text/focus, point, quit, history, mark, paths, and every
echo/search/ring/prefix/prompt/submission/waiting-command payload.

Page motion uses the existing editor distance: `t - 1` when remembered
text height `t >= 2`, otherwise `t`. Change no key or motion algorithm.
Splits keep their extent-three minimum, guards, pre-fit fresh-child
origin capture, and existing post-split fit at full visible leaf height.
Do not edit split/delete/entry/lock commands to implement the row rule.

Frame remains read-only: it never fits, remembers size, installs focus
or origins, changes a name, or performs Fs/Term effects. Repeated fit at
the same point/size is idempotent. Shrink/growth preserves the full tree
and restores predecessor visible-split composition after fallback.

### 4. Focused frame, state, and runner proof

Write `mode-line-one-view.rkt` before product edits and observe the
missing tall-frame/fit behavior fail. It owns all of spec §5.3's focused
one-view requirements:

1. Independent complete frames at width one, narrow, and wide; empty,
   text, and blank buffers; untitled and bound full names; nonzero
   vertical/horizontal origins; idle/saved/failed/search/prompt states.
   Prove name and echo can differ, shorter editor prefix, absolute row
   addresses, intermediate show/hide bytes, one clear, and final cursor.
2. Exact predecessor height-one/two strings through prompt/search/status,
   unchanged direct editor frames including raw branches, and height
   three's one text row, one mode row, and echo. Fill is distinct from
   blank text. Existing direct-editor goldens remain substantive.
3. Minimal/idempotent fit and remembered heights one, two, and three with
   page distances. At 12 columns/4 terminal rows, empty untitled has two
   blank text rows, `"untitled ---"` at row 3, and `"untitled"` at row 4.
   For `zero\none\ntwo\nthree` at point `(3,0)`, fit yields origin row 2,
   body `"two\r\nthree"`, and text cursor `(2,1)`. Up holds origin 2
   and finishes at `(1,1)`.
4. Full preserved-state snapshots around fit and redraw. Frame twice and
   at a different size without changing remembered size/state. Prove
   fallback even with a positive selected rectangle, selected-only origin
   mirroring, locks/inactive origins retained through growth, and visible
   splits still using predecessor rows/full-height fit. Any explicit
   temporary split expectation is identified as 000 staging for 001.
5. Next frames after save-as, visit, find-file, select/switch, and kill
   read the existing operation's resulting name with no extra effect.
   Include a refused operation and singleton kill to untitled. Snapshot
   the complete state and counted Fs effects.
6. A scripted production runner sequence fits and paints/writes once
   before each read, shrinks tall to short and grows again, and preserves
   save, active prompt, and quit with exact full strings and read/write/
   Fs counts. Use existing seams; no runner/Term product edit.

### 5. Independent regression migration

Frame builders take the displayed buffer name separately from the echo
label, and enough width/height information to compute independent chrome.
Never infer the name from `saved:`, a search label, or a prompt. Expected
rows/frames use literal data or independent Racket computation, never the
production name-row/session/tree composer under test. Preserve whole-frame
assertions rather than reducing them to substrings or comparing two
production calls.

Migrate tall session expectations, fitted origins, remembered heights,
and resulting page distances. A fixture for an unrelated earlier text
scenario may gain one terminal row, with its full expected frame including
the mode line. Do not blanket-change direct-editor heights. In particular,
an explicit direct-editor prefix assertion uses that editor's actual
requested height; it is not a session height. Preserve raw-state proof
without adding cursor clamps.

Window tests receive only one-view/fallback frame/fit migration, class
inventory, and consequences of an earlier one-view fit. Keep all positive
visible-split goldens and full-height fits for 001. Retain their geometry,
origin, lock, ownership, command, reset, and host-effect assertions.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/mode-line-row.rkt tests/aloemacs/mode-line-one-view.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test invocation includes `TMPDIR=/tmp` and `-y`. The latter
rebuilds changed Racket bytecode and dependents. Do not commit `compiled/`.
Launchers load bytecode without rebuilding: after a `.rkt` edit, run the
tests or `raco make host/racket/aloemacs-run.rkt bin/aloe` before launching.
Editing only `.aloe` files needs no rebuild. No physical TTY, wider suite,
new timing gate, benchmark, or hand check is required.

Complete when both focused proofs and the full aloemacs suite pass, the
diff has no whitespace errors, and source review confirms only the named
helper/derived height and one-view composer/fit changes, unchanged existing
fields/arities/commands/runner, pure frame/name derivation, selected-only
fit, bounded Text rendering, and no extra host effect. Report files changed
and verification results. Stop when green; do not implement 001, write
another checkpoint, or start faces, language modes, or Boids.
