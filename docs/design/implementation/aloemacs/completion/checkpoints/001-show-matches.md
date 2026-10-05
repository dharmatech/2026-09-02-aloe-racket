# aloemacs-completion 001 — Show prepared matches above the prompt

**Status: Ready to implement.** Issued on 2026-10-04 against the
accepted completion spec, after review of 000's implementation.

## Goal

Paint the prompt's prepared matching names in full-width rows immediately
above the last-row prompt. Derive one shorter session root for rendering
and selected fit, including split layouts, global fallback, and resize.
Keep the prepared strings intact and leave completion decisions on the
existing session algorithm.

Stop with list painting, geometry, selected fit, and their no-TTY proof
green. This is the last checkpoint in this series. Do not add a live
list, selection, candidate movement, or another exploration.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity is **aloemacs-completion 001**. Its predecessor is
  [000 — Complete file prompts on Tab](000-complete-on-tab.md), implemented
  in the current working tree and reviewed before this checkpoint was
  issued. Its focused proofs and the full aloemacs suite pass. The old
  ready-to-implement status in 000 records its original assignment;
  this folder's README records the current handoff.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), `SPEC.md`, and
  `CHECKPOINTS.md` before writing code. `SPEC.md` remains Aloe language
  law. Evaluation is send, selectors are literal, and function objects
  execute only through `call`.
- Accepted [../spec.md](../spec.md) §§1–2 govern the predecessors,
  authority, host, and product boundary. §§3.1 and 3.4–3.6 govern the
  existing metadata, preparation, cursor, and lifetime rules to preserve.
  All of §4, §5's 001 verification, and §5's acceptance conditions govern
  this slice. Do not reimplement §3's completion algorithm.
- Start from `examples/aloemacs/file.aloe`. The five-field
  `AloemacsPrompt`, fieldless nongeneric `AloemacsCompletionScan`, prefill,
  named Tab routing, notes, and prepared-line reads already exist. Normal
  ambiguous results hold at most eight raw lines; counts above eight
  produce seven names followed by the existing `...(+N)` summary.
- Current session `frame` and `single-frame` derive their root from
  `AloemacsWindows.text-rect`. `multi-frame` and `ensure-visible` use
  `AloemacsWindows.fit-rect`. These are the seams to change to the new
  session helpers. The window methods themselves remain command geometry.
- The current one-view composer retains the complete editor frame, then
  hides the cursor for its mode/echo suffix. Visible splits retain one
  ANSI envelope over padded root rows. Mode lines already use each leaf's
  last row only when its height is at least two.
- Idle echo is already implemented here: `echo-row`'s idle branch is
  empty when the selected displayed leaf has a mode line, and otherwise
  uses the current path or `untitled`. Preserve those bytes. Idle-echo 000
  and checker-recursion are not dependencies or assignments.
- The unchanged `run-aloemacs-with-hosts` seam in
  `host/racket/aloemacs-run.rkt` queries full dimensions, fits, writes one
  frame String, and reads one key. It already supports the required
  counted Fs and scripted Term proofs without a TTY.

This slice has one product file, one new focused test file, and one
existing test file to migrate. The window algorithms, editor renderer, runner,
scanner, and completion result algorithm are already present. If the
slice proves too large for one implementer conversation without
compaction, stop and return the size finding to the checkpoint manager.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, only within `(AloemacsSession H)`:
  add the three typed geometry helpers below and change `frame`,
  `single-frame`, `multi-frame`, and `ensure-visible` for prepared-line
  composition and list-aware fit. Ordinary nonrecursive pure helper
  methods for that composition may live here if needed. Use existing
  List sends/local values, not recursive sends on this legacy generic
  receiver. Preserve all existing signatures and session fields.
- Create `tests/aloemacs/completion-frame.rkt` before product edits.
  Keep its readable fixture/double/expected-frame helpers in that file;
  do not create shared test infrastructure.
- `tests/aloemacs/completion-session.rkt`, only these two tests:
  the test currently named
  **"notes use unchanged single-row safe painting and lists do not change
  fit or frames"**. Update its title/comments and the two prepared-list
  loops that compare listed sessions to plain sessions, for one view
  and a split. Replace the superseded assertions with independently
  derived list-aware fit and complete frame expectations. Preserve its
  no-list note/raw-control goldens, Fs purity assertions, and substantive
  payload checks. Do not delete the list scenarios or weaken equality
  checks. Also migrate the two runner frames identified below. All other
  tests and helpers in this file stay unchanged.

The inventory comes from searching the full aloemacs suite for
`completion-lines`, `with-completion`, `complete-prompt`, and list-bearing
frame/fit fixtures. `minibuffer-value.rkt` has prompt metadata inventories
but no list-aware frame expectation to migrate. The completion runner
also draws stored lists at height three and needs this exact migration
in `completion-session.rkt`:

- In **"production runner fits at full size and draws once through
  prefill, Tab, Return and cancel"**, replace only the two frames drawn
  with an ambiguous list: after the second Tab on `/cwd/alp`, and after
  Tab on the later restarted `/cwd/` prompt. These are the second
  `grown` and second `restarted` entries in its expected frame list.
  Terminal height three reserves one list row, leaves root height one,
  removes its mode line, and paints `alpha.txt` on row two. Keep its
  keys, event/iteration counts, Fs snapshots, prefill, notes, submission,
  Return/cancel outcomes, and every other complete frame unchanged.
  Local independent frame expectations for these two results are permitted;
  do not change the existing no-list frame builder.

Search again before completing the slice. A no-list expectation changing
is a regression, not an additional migration.

### Must leave untouched

- Every other existing test, including
  `tests/aloemacs/completion-key-mapping.rkt`, all mode-line/windows tests,
  prompt-command tests, direct editor frames, and idle-echo goldens.
- Every declaration outside `(AloemacsSession H)` in `file.aloe`, including
  the prompt, scanner, buffer, view, tree, rectangle, windows, command,
  and keymap classes; its two loads and declaration order stay exact.
- Existing prefill/completion decisions, metadata reads, prompt editing,
  routing, command dispatch, submission/cancellation, buffer/window
  operations, and session reconstruction methods. The existing
  post-split call to `ensure-visible` acquires the new geometry without
  an edit to the split command.
- `examples/aloemacs/main.aloe`, `examples/aloemacs/editor.aloe`,
  `host/racket/term.rkt`, `host/racket/aloemacs-run.rkt`,
  `host/racket/fs.rkt`, every other product/host file, `aloe/`, and `lib/`.
- `SPEC.md`, `CHECKPOINTS.md`, the global checkpoint spine, this folder's
  spec/charter/README/checkpoints, and predecessor documents during
  implementation. Do not repair or reset unrelated working-tree edits.

If another file or behavior change appears necessary, stop and send this
checkpoint back to the manager instead of widening its scope.

## Slice requirements

### 1. Shared session geometry

Add exactly these required ordinary typed sends, without adding fields:

| Send | Result | Contract |
|---|---|---|
| `completion-row-count(rows : Int)` | `Int` | `0` when `rows < 2`; otherwise `min(completion-lines.len, max(0, rows - 2))`. |
| `root-rect(columns : Int, rows : Int)` | `AloemacsWindowRect` | `(0, 0, columns, rows)` when `rows < 2`; otherwise `(0, 0, columns, rows - 1 - completion-row-count(rows))`. |
| `fit-rect(columns : Int, rows : Int)` | `AloemacsWindowRect` | Derive that root. If the entire tree has positive nominal layout, return the selected nominal leaf rectangle, falling back to the root when selected lookup is absent. Otherwise return the root. |

Use the existing session `completion-lines` read: it yields the active
prompt's stored list or empty when no prompt exists. Geometry never
queries Fs, recomputes completion, or rewrites the list. Positive terminal
dimensions remain the normative fit/frame contract; helper formulas
retain their stated `rows < 2` branch without a new validation policy.

Let `k` be the painted count and `h` the root's height. At positive sizes
the root retains at least one row. With eight stored lines:

| Terminal rows | `k` | `h` | Prompt row |
|---|---|---|---|
| 1 | 0 | 1 | Absent |
| 2 | 0 | 1 | 2 |
| 3 | 1 | 1 | 3 |
| 5 | 3 | 1 | 5 |
| 10 | 8 | 1 | 10 |
| 12 | 8 | 3 | 12 |

For example, at width nine, height eight, and two prepared lines the
root is `(0, 0, 9, 5)`. A Right split has `(0, 0, 4, 5)` and
`(5, 0, 4, 5)`, with four text rows per leaf. A Below split has
`(0, 0, 9, 2)` and `(0, 3, 9, 2)`, with one text row per leaf.
At height four with those same lines the root has height one: Right
remains visible at width nine with no leaf mode lines; Below triggers
the whole-root fallback. These are independent test witnesses, not a
new layout algorithm.

Session `frame`, both composers, and `ensure-visible` use this shared
root and selected rectangle. Reuse the existing tree layout, row,
divider, and junction algorithms within the shorter root. If any leaf
has a zero axis, fit and paint the current buffer in the whole root,
even when the selected nominal leaf alone is positive. Keep the tree,
selection, IDs, locks, and inactive origins intact.

Leave `AloemacsWindows.text-rect`, `fit-rect`, and command/lock geometry
unchanged. They continue to use the remembered full terminal dimensions
and echo reservation. Direct window/buffer sends retain their existing
transitions and preserve the whole active prompt; this slice introduces
no split refusal or list-owned command state.

### 2. Selected fit and restoration

`ensure-visible(columns, rows)` retains its concrete
`(AloemacsSession H)` result. Fit only the current editor using the new
session fit rectangle's width and existing `text-rows`: a height of at
least two reserves its last row for its buffer name; a shorter leaf uses
its whole height as text. Single-view and fallback use `root.text-rows`.

Only the existing fit changes are allowed: current editor origins and
remembered text height, their selected-view origin mirror, and remembered
**full terminal** dimensions. Preserve every other editor/buffer payload,
Text/focus, point, quit, history, mark, path/name/ID, buffer order/focus,
inactive origin, tree/selection/lock, Fs, ring, search, echo, prefix,
prompt/metadata, previous submission, and waiting command.

Fit remains minimal and idempotent. Shrink/growth uses the shorter root
on the next explicit fit, including the runner's normal iteration.
Insert/backspace clearing restores normal available height on the next
fit. A previously needed selected origin may remain under minimal fit;
do not save/restore an old origin specially. Page distance continues to
use the editor's remembered selected text height. Frame never fits,
records dimensions, updates origins, or pushes undo.

### 3. Exact full-width composition

Paint only the first `k` stored lines, in order. For `j` in `1..k`,
address terminal row `h + j`, column one, then append:

```text
current-editor.safe-cells(prepared-line.take(columns))
```

Clip before safe cells. Controls 0–31 and 127, including raw LF/CR/Tab/ESC,
become one space; printable text after ESC remains printable. Stored
lines stay raw. No marker, padding, selection, extra ellipsis, newline,
per-line cursor sequence, or recalculated summary is added. The existing
single clear blanks unused cells. A clipped terminal shows the first
lines as stored, even when the summary line does not fit.

For one leaf or global fallback, keep the **complete**
`editor.frame(columns, root.text-rows)` prefix, including its intermediate
cursor show. At `rows >= 2`, append in exactly this order:

```text
ESC[?25l
[ESC[h;1H shown-mode, only when h >= 2]
[ESC[h+j;1H shown-line-j, for j = 1..k in order]
ESC[rows;1H shown-echo
ESC[final-row;final-columnH ESC[?25h
```

For visible split leaves, retain the one envelope:

```text
ESC[?25l ESC[2J ESC[H joined-root-rows
[ESC[h+j;1H shown-line-j, for j = 1..k in order]
[ESC[rows;1H shown-echo, only when rows >= 2]
ESC[final-row;final-columnH ESC[?25h
```

Spaces, brackets, and line breaks in this notation add no bytes.
`joined-root-rows` has exactly `h` full-width rows joined with CRLF,
without trailing CRLF. Single/fallback keeps unpadded editor text and
the existing derived name row. Use existing safe/clipped echo selection,
including prompt notes, with no new echo token or idle-payload change.

With a visible prompt, the final cursor stays at terminal row `rows`,
column `prompt.screen-column(columns)`. Completion lines own no cursor;
notes/lines do not contribute to that column. Without a visible prompt,
retain the selected text cursor formula. At height one paint no list,
echo, or mode row and keep the predecessor frame and text cursor.

With no stored list, all geometry, fit results, and **complete frame
bytes** match 000, including intermediate show/hide sequences, short
leaves, fallback, notes, search, saved/failed status, and idle echo.
Direct editor frames remain exact. The result is one String written by
the unchanged runner through one `term write` per drawn iteration.

## Focused proof and migration

Write `tests/aloemacs/completion-frame.rkt` first. Observe a focused
failure for the missing helper/list behavior before product edits.
Use checked driver sends, `rackunit`, counted readable Fs doubles, and
scripted Term doubles. Construct prepared prompts for pure geometry and
painter proofs, then drive actual Tab for integration. Derive expected
rectangles, fitted sessions, row data, and complete ANSI strings from
independent literals/fixture arithmetic, never the production geometry
or composer under test. Expected-frame helpers must remain independent
of the product and include literal goldens for representative layouts
and complete envelopes.

Prove the following in this bounded file:

1. Exact signatures and checked result types for the three new session
   sends, plus argument/arity/receiver negatives. Retain the fourteen
   session fields and existing class order. Check concrete session fit
   results with two injected nominal Fs host identities. Helper reads,
   fit, and frame make zero Fs calls.
2. Row-count/root formulas for empty, one, several, and eight stored
   lines; every small-height witness above; `rows < 2` helper branches;
   absent prompt; and the selected-lookup/global fallback rules. Drive
   Tab with candidate counts below, at, and above eight to prove the
   stored preparation limit/summary and its later terminal truncation.
3. Full one-view/fallback and split ANSI goldens at width one, narrow,
   and wide widths. Check directory slashes, summary clipping, raw
   ESC followed by printable `[31m`, LF/CR/Tab/another low control/DEL,
   and a control beyond the clip. Compare list/echo addresses and cursor
   sequences, and assert raw prompt/lines unchanged after paint.
4. One leaf, Right, Below, mixed trees with T and cross junctions,
   tall/short leaf mode lines, shared buffers at distinct origins,
   locked leaves, and list-induced global fallback. Include a tree
   whose selected leaf is positive but another leaf has a zero axis.
   Independently check layout within the shorter root; normal command
   geometry retains the full remembered dimensions.
5. Shrink/grow and list clearing preserve the full tree, IDs, selection,
   locks, inactive origins, and other buffer/editor payloads. Fit is
   minimal/idempotent, uses the shorter selected text height, mirrors
   only the selected origin, and remembers the full size. Check page
   distance through the existing editor rule. Frame twice, and frame at
   another size without fitting, to prove purity and no dimension write.
6. Horizontal motions retain the list. Insert and backspace, including
   at column zero, clear it and restore normal root height on next fit.
   Ignored prompt keys preserve it. Return/Escape discard it with the
   prompt, restore normal geometry, and retain exact inherited command
   effects/submission/cancellation. No extra lookup accompanies painting,
   fit, resize, edit, motion, or clearing.
7. Actual ambiguous Tab through the production runner, redraw, short/tall
   resize, clear, repeated lookup, submission/cancel, and quit. Use
   distinctive text rows/points so complete frames prove fit-before-frame.
   Check the prompt's last-row cursor, full dimension queries, one write
   per drawn iteration, lookup snapshots, and no read/write until a
   submitted file action. Repeated Tab can see changed names; resizing
   cannot. Do not modify the runner to inject or paint a list.
8. Complete no-list goldens remain identical for one view, visible splits,
   fallback, height one/two, notes, search, saved/failed, and current idle
   payload. Keep 000's scanner, metadata, prefill, converter, command,
   routing, preservation, and Fs-effect proofs green.

Migrate only the prepared-list expectations identified in the exact
scope. Keep no-list frame builders and goldens unchanged. The inherited
full suite supplies additional buffer/editor/window/command regression
proof; do not weaken it or repair an unrelated predecessor defect here.

## Explicit non-goals

No live lookup/list, fuzzy or substring matching, selected/highlighted
row, Up/Down candidate movement, cycling/paging, buffer-name or command
completion, `M-x`, history, `~` expansion, wildcards, directory browser,
opening a directory with Return, `mkdir`, symlink traversal, indentation,
prompt undo, dirty bit, new echo token, or new state field.

No host/library/language method, List index, new class/result object,
dependency/module/load, runner/Term conversion change, window algorithm
or command/lock policy change, checker-recursion work, recursive send on
a legacy generic `(fields ...)` receiver, Mirror, mutation, inheritance,
delegation, macro, implicit Int/Float coercion, new special form, global
checkpoint, later exploration, or Boids belongs here.

## Verification and completion

From the project root, after implementation run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/completion-session.rkt tests/aloemacs/completion-key-mapping.rkt tests/aloemacs/completion-frame.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test command includes `TMPDIR=/tmp` and `-y`. Do not commit
`compiled/`. Launchers load existing bytecode: after a `.rkt` edit, run
the tests above or `raco make host/racket/aloemacs-run.rkt bin/aloe`
before an optional `racket host/racket/aloemacs-run.rkt [path]` launch.
`.aloe` edits alone need no rebuild. Add no per-launch build step.
No wider suite, physical TTY hand check, benchmark, timing gate, or
unreadable-directory recovery test is required.

Review source as well as tests: all session display/fit paths derive
the same list-aware root and selected rectangle; global positivity
still governs fallback; window command geometry stays unchanged;
paint clips before safe cells and reads only stored data; no recursive
generic helper, Fs query, completion recomputation, state write, or
extra host/String/Text send appears; the runner, inventories, and
complete no-list frames remain exact.

Complete when the new focused proof, 000's focused proofs, and the full
aloemacs suite are green; `git diff --check` is clean; all §4 requirements
and the applicable §5 acceptance conditions are covered; structural
review passes; and scope is respected. Report changed files, the initial
focused failure, final verification, and structural review. Stop when
green for human review. Do not write another checkpoint, a demo, or
implementation for a following exploration.

If you have been told to read this file, it is the whole assignment.
