# aloemacs-completion-page 000 — Page the list

**Status: Ready to implement.** Issued on 2026-10-05 after review and
acceptance of the completion-page spec.

## Goal

Retain every display name from a list-producing Tab on find-file or
save-as. Page Down and Page Up move a fixed window over that cached
snapshot without editing the prompt or querying Fs. Existing fit/frame
composition paints the changed prepared lines, and Return still submits
the typed text.

Stop when paging, state preservation, command outcomes, and the no-TTY
proof are green. This is the entire series: no 001, selected row, live
list, terminal-sized window, or adjacent feature follows.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-completion-page 000**. File:
  `checkpoints/000-page-the-list.md`. This is a local project number;
  do not add a global checkpoint or a `CHECKPOINTS.md` entry.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md),
  [`SPEC.md`](../../../../../../SPEC.md), and
  [`CHECKPOINTS.md`](../../../../../../CHECKPOINTS.md) before writing
  code. `SPEC.md` remains Aloe language law. Evaluation is send; selectors
  are literal; function objects execute only through `call`. No implicit
  Int/Float coercion or new special form is allowed.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, predecessors,
  file boundary, and non-goals. All of §§3.1–3.7 govern this slice. §4
  supplies the required proofs and commands; §5 governs acceptance and
  the stop. The charter and earlier conversation supply no extra rules.
- Predecessors are **aloemacs-completion 000 and 001**:
  [Complete file prompts on Tab](../../completion/checkpoints/000-complete-on-tab.md)
  and [Show prepared matches above the prompt](../../completion/checkpoints/001-show-matches.md).
  Their behavior is implemented in the starting tree. The manager ran
  `TMPDIR=/tmp raco test -y tests/aloemacs/completion-session.rkt tests/aloemacs/completion-frame.rkt`:
  **25 tests passed**. A stale status in predecessor documents or the
  parent map is not work to repair.
- `file.aloe` already has the five-field prompt, fieldless nongeneric
  scanner, full Tab prefix/filter algorithm, eight-row prepared list,
  prompt dispatch, and list-aware root/fit/frame helpers. Its current
  ambiguous-result branch discards names after preparing the first
  window. Extend that branch and prompt state; preserve the painter.
- Plain Term `next` and `prior` already become `"page-down"` and
  `"page-up"` with no modifiers. Add no converter or keymap binding.
  The runner already fits before framing and writes one String per
  drawn frame. List's Aloe `fold`, `map`, and `reverse` already exist.
- Prompt commands, minibuffer, windows, mode line, and keymap are
  preserved seams under the authorities named in spec §1. Idle-echo
  and checker-recursion are neither prerequisites nor assignments.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: append the two prompt fields, add its
  page helper, migrate its prompt constructors and lifetime handling;
  add the two pure scanner methods; retain Tab's complete display list;
  add session `page-completion` and the two active-prompt key arms.
  Keep the two loads and class declaration order. Add no class. Existing
  fit/frame bodies and other command behavior need no change.
- `examples/aloemacs/main.aloe`: only append `(List empty)` and `0` to
  its typed absent-prompt witness. Keep all startup defaults.
- Create `tests/aloemacs/completion-page-session.rkt` and
  `tests/aloemacs/completion-page-frame.rkt` before product edits. Keep
  focused fixture/double/expected-value helpers in these files; add no
  shared test infrastructure or dependency.
- The following existing tests, **only** for prompt-constructor and
  field/helper inventory migration and actual Tab's new full retained
  list expectations. Preserve substantive predecessor assertions,
  negative-test intent, complete frames, and no-list goldens:

```text
tests/aloemacs/buffer-session.rkt
tests/aloemacs/buffer-value.rkt
tests/aloemacs/completion-frame.rkt
tests/aloemacs/completion-session.rkt
tests/aloemacs/echo-session.rkt
tests/aloemacs/file-session.rkt
tests/aloemacs/idle-echo.rkt
tests/aloemacs/keymap-prefix.rkt
tests/aloemacs/keymap-session.rkt
tests/aloemacs/kill-session.rkt
tests/aloemacs/minibuffer-session.rkt
tests/aloemacs/minibuffer-value.rkt
tests/aloemacs/mode-line-one-view.rkt
tests/aloemacs/mode-line-split-views.rkt
tests/aloemacs/motion-editor.rkt
tests/aloemacs/prompt-commands-find-file.rkt
tests/aloemacs/prompt-commands-save-as.rkt
tests/aloemacs/prompt-commands-select-buffer.rkt
tests/aloemacs/runner.rkt
tests/aloemacs/safe-cells.rkt
tests/aloemacs/search-session.rkt
tests/aloemacs/undo-session.rkt
tests/aloemacs/viewport-editor.rkt
tests/aloemacs/visited-unchanged.rkt
tests/aloemacs/windows-buffer-identity.rkt
tests/aloemacs/windows-delete-and-other.rkt
tests/aloemacs/windows-layout-and-rendering.rkt
tests/aloemacs/windows-lock.rkt
tests/aloemacs/windows-split.rkt
tests/aloemacs/windows-state-foundation.rkt
tests/aloemacs/windows-state.rkt
```

This inventory comes from searching all of `examples/aloemacs/` and
`tests/aloemacs/` for `AloemacsPrompt`, its constructors, completion
fields/helpers, and `AloemacsCompletionScan`. `mode-line-row.rkt` mentions
only the unchanged class order and requires no migration. Keep it and
`completion-key-mapping.rkt` untouched. Search again before completing;
do not widen the inventory silently.

### Must leave untouched

- Every other product/test file, including `examples/aloemacs/editor.aloe`,
  `host/racket/term.rkt`, `host/racket/aloemacs-run.rkt`, host capabilities,
  `aloe/`, and `lib/`.
- Buffer, editor, history, view, window, command, and keymap shapes; all
  fourteen session fields in their existing order; scanner fields (none),
  prefill, Fs boundary, converter, idle maps, and fit/frame algorithms.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, predecessor designs and
  checkpoints, the idle-echo checkpoint, and this feature's design
  documents during implementation. Do not repair unrelated working-tree
  changes or stale status lines.

If another file or behavior change appears necessary, stop and send this
checkpoint back to the manager instead of widening its scope. If this
slice cannot finish in one implementer conversation without compaction,
stop and return the size finding to the manager.

## Slice requirements

### 1. Prompt state, helpers, and migration

Keep the first five fields exact and append the last two, in this order:

```aloe
(label String)
(text String)
(column Int)
(completion-note String)
(completion-lines (List String))
(completion-matches (List String))
(completion-start Int)
```

`completion-lines` remains the prepared painter input.
`completion-matches` retains every raw display String from the last
list-producing Tab, including Directory slashes, without Entry objects
or generated summary rows. `completion-start` counts names before the
window; it is never a selected-row index. Valid starts are `0` for at
most eight matches and `0, 7, 14, ... < count` for longer snapshots.
Callers supply canonical state; add no validator, cached length, page
number, active flag, or selection.

| Prompt send | Required behavior |
|---|---|
| Existing `with-completion(text : String, note : String, lines : (List String)) -> AloemacsPrompt` | Keep its signature and existing text/column behavior; additionally clear matches and set start `0`. A changed text moves column to its end; unchanged text keeps column. |
| New `with-completion-page(matches : (List String), start : Int, lines : (List String)) -> AloemacsPrompt` | Preserve label/text/column exactly; set note `""` and install matches/start/prepared lines. Callers provide the canonical window. |
| Existing `clear-completion() -> AloemacsPrompt` | Preserve label/text/column; clear note, lines, matches, and start to `""`, empty, empty, `0`. |

Keep `row`, `screen-column`, and session `completion-note` and
`completion-lines` signatures/results. Page state contributes nothing
to row text or cursor arithmetic. Add no session field/read for it.

Valid insert and backspace clear all four completion values, including
backspace at column zero. Invalid insertion strings and direct LF
remain unchanged. Horizontal motions, including boundary motions,
preserve all completion values. Ignored keys preserve the prompt.
Return/Escape discard the state by ending the prompt. Reconstruction,
fit, frame, and direct buffer/window operations preserve the whole
prompt under their existing rules; successful direct visit still drops
it, refused visit preserves it.

Every valid prompt construction gains matches/start, including expected
values and absent-prompt witnesses. Empty/display-only fixtures append
`(List empty)` and `0`. Pageable fixtures provide a full snapshot,
valid start, and canonical prepared lines. Do not infer hidden names
from a display-only fixture or retain its summary as a match.

The untyped absent-prompt witness is:

```aloe
(if #t
    (Option None)
    (Option Some
      (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
```

Bare `None` remains lawful where expected field types supply inference.
Keep intentional old-arity negatives; migrate other negatives to seven
arguments so they still isolate their original wrong type/field.
Preserve `with-completion`'s signature and its negative tests. Update
exact inventories in `completion-session.rkt` and `minibuffer-value.rkt`
for the new prompt helper/fields, and the former's scanner signatures.
Actual Tab expectations retain the full list; predecessor painter-only
fixtures retain no snapshot. No previous complete frame needs changing.

### 2. Tab installs a fresh full snapshot

Keep `complete-prompt` eligible only for an active prompt with waiting
`FindFile` or `SaveAs`, by constructor case. Preserve the entire
last-component split, whole-text query independent of column, typed
directory spelling, guarded Directory enumeration, raw-name longest
common prefix, case-sensitive prefix filter, dotfile rule, entry order,
and slash only for Directory display names. Do not follow symlinks.

Zero matches still set `" [No match]"`; an identical sole result sets
`" [Sole completion]"`; a differing unique result or extending common
prefix replaces text and moves column to its end. All these outcomes
use the existing helper with empty lines/matches and start `0`.

Only when at least two matches cannot extend the leaf, build **all**
display lines, prepare `(scanner window-lines matches 0)`, and install
`(prompt with-completion-page matches 0 prepared)`. Text/column stay;
note is empty. Replace only the old truncation/application in this arm.

Every eligible Tab re-queries and replaces the snapshot, resetting a
new list to start `0`, even after paging or horizontal motion. A fresh
note or text extension clears it. Paging, typing, motion, fit, and frame
never refresh completion; no completion reads/writes file contents.
Keep existing host-failure propagation.

### 3. Pure scanner windows and exact stops

Add two typed methods to the existing fieldless nongeneric scanner,
retaining all its existing character/prefix methods:

| Scanner send | Contract |
|---|---|
| `drop-lines(lines : (List String), count : Int) -> (List String)` | Return lines for nonpositive count or empty input. Otherwise recurse on **this scanner** with `lines.rest` and `count - 1`. Dropping to/beyond the end yields empty. |
| `window-lines(matches : (List String), start : Int) -> (List String)` | Empty yields empty; up to eight matches at start `0` yield every name with no summary. For longer snapshots at a valid start, skip to that start, prepare at most seven tail names in order, then one summary. |

For `n > 8` and start `s`, name count is `m = min(7, n - s)`.
The summary is exactly `...(+N)`, where `N = n - m`, counting **all**
names outside this window, before and after it. No position suffix or
spaces. Even the last window has a summary because earlier names remain
hidden. Never filter a real raw name because it resembles that spelling.

| Retained count / start | Name rows | Summary |
|---|---|---|
| 8 / 0 | All eight | None |
| 9 / 0 | First seven | `...(+2)` |
| 9 / 7 | Last two | `...(+7)` |
| 14 / 7 | Last seven | `...(+7)` |
| 18 / 0 | Names 1–7 | `...(+11)` |
| 18 / 7 | Names 8–14 | `...(+11)` |
| 18 / 14 | Names 15–18 | `...(+14)` |

Windows are independent of terminal dimensions, at most eight prepared
rows. Page Down advances by seven only when `s + 7 < n`; otherwise
return the whole session unchanged. Page Up uses `max(0, s - 7)`;
at zero return the whole session unchanged. No wrap, overlap, skipped
name, empty tail page, or eight-row step. Reversing a step restores the
exact previous window.

Use existing List `empty?`, `first`, `rest`, `cons`, `len`, `fold`,
`reverse`, and `map`, plus Int/String sends. Check empty before first/rest.
A bounded fold may collect seven names in reverse, cons the summary,
and reverse for display. No List index/drop, host helper, or new class.

The decreasing skip recursion lives only on `AloemacsCompletionScan`.
Never recurse on legacy generic `(AloemacsSession H)` or another legacy
generic `(fields ...)` receiver: its per-send method checking does not
finish. Add no checker change or hanging generic-recursion test. The
scanner consumes only String/Int/List data; the session constructs it
locally, stores none, owns Fs operations, and applies prompt results.

### 4. Prompt routing and complete preservation

Add `page-completion(key : String) -> (AloemacsSession H)`. Its direct
eligibility gate requires all of:

- Key is `"page-down"` or `"page-up"`.
- Active prompt and waiting `FindFile` or `SaveAs`, by constructor case.
- Empty completion note, nonempty prepared lines, and more than eight
  retained matches.

Every other case, and a stopped boundary, returns the whole receiver
unchanged. Eligible movement prepares cached matches on the scanner,
then replaces only the active prompt through `with-completion-page`
and `with-active-prompt`. No Fs or Term send, fit, or buffer motion.

Add the two named keys to `prompt-key`, both sending `page-completion`.
Leave `handle-key` precedence intact: quit, search, active prompt,
pending prefix, idle map. The direct helper does not dispatch search
or quit; `handle-key` owns that precedence as before.

| `handle-key` state | Page-key result |
|---|---|
| Quit | Whole session unchanged, no effects. |
| Search | Existing other-key search exit and inherited idle dispatch; never retry through prompt paging. Its idle action may still page the buffer. |
| Eligible file prompt | Move or stop the cached window. |
| Other/bare/no-list/note/display-only prompt | Whole session unchanged. |
| Pending prefix without search/prompt | Consume miss, clear prefix and echo; page neither names nor buffer. |
| Idle | Existing buffer Page Up/Down command and echo behavior. |

With prompt and pending together, prompt wins and pending is preserved.
With search and prompt together, search wins and the cached page stays
unchanged. Up/Down and other ignored prompt keys stay ignored;
printable input, Tab, Return, and Escape keep their specified behavior.
An active-prompt page key never falls through to the idle page commands,
keymap, editor motion, or `execute-command`.

Successful paging changes **only** prompt `completion-start` and
`completion-lines`. Preserve its label/text/column/note/matches and
all other session, buffer/editor, Fs, and window values, including
focus/order, Text zipper/focus, point, quit, undo/history, mark, both
origins, remembered sizes, paths/names/IDs, shared views/locks, echo,
search fields, ring, pending, previous submission, and waiting command.
No Fs `current`, `path`, `parent`, `name`, `inspect`, `entries`, `read`,
or `write`, and no underlying host operation belongs to paging.

### 5. Return/Escape and existing frame/fit geometry

Return submits only exact raw `prompt.text`, ends the prompt before
running the waiting command, and clears the command after a returned
outcome. Find-file keeps resolved-name reuse before read, regular-file
open, missing-file empty-buffer addition without creation, and all
refusals. Save-as writes the current exact contents and binds only on
success. Empty file input fails without Fs calls. A second inactive
submit does nothing. Keep exact-name select-buffer, bare-prompt,
submission-time current-buffer selection, and host-failure behavior.

Escape discards prompt/page/command, retains previous submission/echo,
runs nothing, sends nothing to Fs, and does not quit. Direct inactive
cancel still clears an orphaned waiting slot. No displayed name,
summary, slash, or start becomes typed submission data.

The existing painter reads only prepared `completion-lines`. At positive
dimensions, `k = 0` when `rows < 2`, otherwise
`k = min(prepared count, rows - 2)`. Root height is `rows` below two,
otherwise `rows - 1 - k`. The prompt remains on row `rows` for
`rows >= 2`; list rows sit full width immediately above it, below root.
Clip each prepared String to columns **before** safe-cells, keeping
raw stored names and replacing controls by one space. Add no marker,
ellipsis, list cursor, padding policy, or recalculated summary.

For 18 matches, heights 12 and 5 have these independent witnesses:

| Height / start | Prepared count | Painted names / summary | Root height |
|---|---|---|---|
| 12 / 0 | 8 | Names 1–7, `...(+11)` | 3 |
| 12 / 7 | 8 | Names 8–14, `...(+11)` | 3 |
| 12 / 14 | 5 | Names 15–18, `...(+14)` | 6 |
| 5 / 0 | 8 | Names 1–3 | 1 |
| 5 / 7 | 8 | Names 8–10 | 1 |
| 5 / 14 | 5 | Names 15–17 | 1 |

Short terminals clip the current prepared window and do not change
snapshot/start/step/summary. At ten or more rows all eight prepared
rows can paint. Growth reveals the same window without lookup. The
last window returns spare rows to root. Preserve mode lines, dividers,
junctions, selected fit, global fallback, cursor clamp, ANSI envelope,
and idle echo. Fit may minimally adjust only its inherited selected
origins/remembered geometry; page keys themselves never fit or scroll.
Frame is pure. No-list frames/fit remain exact. The unchanged runner
fits before frame and writes one String per drawn frame.

## Focused tests

Write the two new focused files first and observe missing behavior fail
before product changes. Use checked driver sends, `rackunit`, counted
readable Fs doubles, and scripted Term doubles without a physical TTY.
Expected windows are literal; expected sessions and complete ANSI frames
are independent of product helpers under test. Adapt the existing
completion tests' fixture patterns locally, preserving their old proofs.

`completion-page-session.rkt` must prove:

1. Exact seven-field prompt and read/helper types, unchanged fourteen-field
   session/commands/maps, fieldless nongeneric scanner and checked new
   methods, plus argument/arity/receiver negatives. Fresh checked loads
   are effect-free without injected Fs/Term; concrete session result
   types hold with two nominal Fs host types.
2. Drop with zero/negative counts, empty input, within/to/beyond the end;
   windows for counts 0, 1, 7, 8, 9, 14, 15, and 18 with literal summaries,
   ordered raw names, slashes, and controls. Checked recursion finishes
   on the scanner. Do not test a hanging legacy generic call.
3. Actual FindFile and SaveAs ambiguous Tab over an intentionally unsorted
   listing with 18 filtered names; starts `0 -> 7 -> 14 -> 14` and
   `14 -> 7 -> 0 -> 0`, exact windows, every name reached in order with
   disjoint forward slices, interior column/text preserved, and whole
   session equality at stops. Include eight-name no-ops, nine-name tail,
   and a full seven-name tail.
4. Count **every** Fs host call. Change the listing after Tab: paging,
   motion, fit, and frame use the old snapshot and add zero calls. New
   Tab refreshes/reset-starts; from a later page exercise fresh list,
   no-match, sole, unique, and common-prefix outcomes. Edits/backspace
   at zero clear state; motions/invalid insert/LF/ignored keys preserve
   it. Preserve existing filter/dotfile/slash/typed-spelling assertions.
5. Both keys and direct-helper gates for select-buffer, bare/other/no-list/
   note/absent-snapshot prompts, unsupported key, and absent prompt;
   quit, pending, idle, search, and mixed-state precedence. Eligible
   paging preserves rich complete buffers/editors/windows and other
   session values; only prepared lines/start may differ. Ineligible
   active prompts do not run idle page commands.
6. Return after paging submits typed data with find-file reuse,
   regular/missing/refusal/no-creation outcomes and save-as success/
   refusal/failure behavior. Prove exact contents written once to the
   typed target, success-only binding, displayed-directory refusal,
   empty submission, inactive second submit, and submission-time focus.
   Escape keeps previous submission/echo and adds zero calls. Retain
   select-buffer, bare prompt, and host-failure proofs.

`completion-page-frame.rkt` must prove:

1. Complete frames for first/middle/tail at heights 12 and 5; heights
   1, 2, and 10; narrow widths and width one. Independently count root/
   list rows and prompt cursor; clipping does not recompute summaries.
   Include LF/CR/Tab/ESC/DEL, controls beyond clipping, directory slashes,
   and clipped summaries. Raw snapshot/start remain exact.
2. One view, visible splits/shared views, and list-induced global fallback;
   existing mode lines and fit-before-frame geometry. Fit/frame preserve
   the whole prompt; the tail returns spare rows to root, and clearing
   restores no-list geometry with inherited minimal fit and no Fs calls.
3. A scripted unchanged production runner drives Tab, both page directions,
   redraw/resize, a fresh Tab, Return/cancel, and quit. Assert full-size
   fit before each drawn frame, last-row prompt cursor, one String/write,
   no Fs calls between Tabs except submitted actions, changed snapshot
   only on fresh Tab, and visible last match at a size painting the whole
   window. Keep predecessor complete no-list frames/fit green.

These proofs are spec §4's acceptance evidence. No physical-terminal
tour, benchmark, or wider suite is required. A demo is later work.

## Verification and completion

Run from the project root:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/completion-page-session.rkt tests/aloemacs/completion-page-frame.rkt tests/aloemacs/completion-session.rkt tests/aloemacs/completion-frame.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

`TMPDIR=/tmp` and `-y` are required for every agent test run. Do not
commit `compiled/`. Launchers load existing bytecode: after a `.rkt`
edit, run the tests above or `raco make host/racket/aloemacs-run.rkt bin/aloe`
before an optional `racket host/racket/aloemacs-run.rkt [path]` launch.
`.aloe` edits alone need no rebuild; add no per-launch build step.

Review source as well as tests: complete snapshot retention; pure
scanner recursion; prompt-only page state; no page-key Fs/Term sends
or active-prompt idle fall-through; untouched checker, runner, converter,
maps, libraries, and fit/frame algorithms. Preserve complete no-list
frames and substantive predecessor assertions; an unrelated failing
predecessor is a stop, not permission to widen this slice.

Complete only when the focused tests and full aloemacs suite pass,
`git diff --check` is clean, spec §5's acceptance conditions hold, and
changes stay inside the exact scope. Report verification and changed
files. **Stop when green.** Do not implement another feature, merge,
write a demo, amend the design, or start another checkpoint.

## Explicit non-goals

No selected/highlighted row, marker, Up/Down traversal, candidate cycling
into text, live lookup, fuzzy/substring matching, changed filter/order/
prefill, buffer/command completion, `M-x`, directory browser, opening a
directory with Return, Tab paging/indentation, `~`, wildcards, history,
`mkdir`, symlink traversal, dirty bit, prompt undo, or new echo token.

No terminal-dependent window, session field, cached length, List index,
host/String/Text/Term method, converter/map/command change, runner edit,
new class/module/dependency, language amendment, checker fix, generic
recursive helper, Mirror, mutation, inheritance, delegation, macro,
new special form, global checkpoint, later exploration, or Boids.

If you have been told to read this file, this is the whole assignment.
