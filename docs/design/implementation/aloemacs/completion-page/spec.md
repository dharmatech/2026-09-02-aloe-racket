# aloemacs completion-page specification

**Status: Accepted for aloemacs-completion-page 000.** This file is the complete design
input for the **aloemacs-completion-page** checkpoint manager and
implementer. After human acceptance it becomes their design authority;
neither the charter nor this conversation supplies additional rules.
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law.
[`docs/workflow.md`](../../../../workflow.md) governs the roles and stops.

Tab on find-file or save-as still completes the last path component.
When it cannot extend an ambiguous prefix, the prompt retains every
matching display name and paints the first window. Page Down shows the
next window; Page Up shows the previous one. Both stop at their respective
ends. The names remain display data, with no selected row. Return
submits the typed text, including after paging.

## 1. Series, predecessors, and authority

The series identity is **aloemacs-completion-page**. Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Product code stays in
`examples/aloemacs/`; tests stay in `tests/aloemacs/`. This folder holds
design documents and later checkpoints, never program code.

There is exactly one checkpoint:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-completion-page 000** | `checkpoints/000-page-the-list.md` | Retain a Tab snapshot on the prompt, page its prepared window in either direction, preserve text/column and command outcomes, make no Fs call on paging, and paint the new window through existing fit/frame geometry. |

Numbers have three digits, start at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. The window remains independent
of terminal size, so there is no 001. After human acceptance, the manager
writes **000 only**, then stops. The implementer receives the approved
checkpoint and this spec, adds tests first, implements that slice, runs
verification, and stops when green. Human review follows implementation.
Do not use a global integer or add an entry to `CHECKPOINTS.md`.

The starting tree must contain completion 000 and 001: prefill, Tab's
prefix result, prepared names/notes, and list painting above the last-row
prompt. Those behaviors are present in the working tree. A stale status
in the completion README or parent map is not a prerequisite to repair.
Prompt commands, minibuffer, windows, mode line, keymap, and List's Aloe
`fold`, `map`, and `reverse` are also predecessors. Idle-echo and
checker-recursion are neither prerequisites nor assignments.

Authority for preserved seams is:

- [`../README.md`](../README.md): layer order; this is the completion-page
  layer after completion.
- [`../completion/spec.md`](../completion/spec.md): prefill, last-component
  splitting, guarded enumeration, filtering, prefix results, notes, raw
  display names, and list-aware fit/frame composition.
- [`../prompt-commands/spec.md`](../prompt-commands/spec.md): waiting
  command, submission/cancellation, find-file reuse/read/refusal,
  save-as writes/binding, and exact-name buffer selection.
- [`../minibuffer/spec.md`](../minibuffer/spec.md): prompt ownership,
  editing arithmetic, start guards, and cursor clamp.
- [`../windows/spec.md`](../windows/spec.md) and
  [`../mode-line/spec.md`](../mode-line/spec.md): tree, selection, origins,
  leaf text height, mode lines, global fallback, and the reserved echo row.
- [`../keymap/spec.md`](../keymap/spec.md): quit/search/pending/idle
  dispatch, including existing idle Page Up/Down commands.
- [`lib/fs.aloe`](../../../../../lib/fs.aloe) and
  [`host/racket/fs.rkt`](../../../../../host/racket/fs.rkt): `entries`
  and the unchanged thin filesystem boundary.
- [`lib/list.aloe`](../../../../../lib/list.aloe) and `SPEC.md` §6:
  available List sends; there is no List index or List `drop`.
- [`file.aloe`](../../../../../examples/aloemacs/file.aloe),
  [`main.aloe`](../../../../../examples/aloemacs/main.aloe), and
  [`term.rkt`](../../../../../host/racket/term.rkt): implementation and
  constructor starting points, and already available named page keys.

This spec extends the prompt inventory and completion-state lifetime,
replaces the cap on retained names with a cap on the prepared window,
and permits the two prompt page keys. It adds pure List helpers to the
existing scanner. Tab still starts at the first window on every query;
it never advances a window. All other completion results, Return/Escape
outcomes, and no-list root/echo behavior remain governed by their
predecessors. Do not amend those documents to update old inventories or
remove their former paging non-goal.

## 2. Product, host, and file boundary

The product remains checked Aloe with immutable values and the injected
`(Fs H)` capability. Racket tests use the existing checked driver,
`rackunit`, counted readable Fs doubles, and scripted Term doubles without
a physical TTY. Evaluation is send; function objects run through `call`.
There is no new dependency, module, host interface, or build step.

000 may edit:

| File scope | Permitted work |
|---|---|
| `examples/aloemacs/file.aloe` | Prompt fields/helpers and constructor threading; retain Tab's full display list; scanner's pure window helpers; active-prompt paging. Existing fit/frame bodies need no new behavior. |
| `examples/aloemacs/main.aloe` | Only extend its typed absent-prompt witness to the new prompt arity. Keep all startup defaults. |
| `tests/aloemacs/completion-page-session.rkt` | New focused checked-state, paging, routing, effect, and command-outcome proofs. |
| `tests/aloemacs/completion-page-frame.rkt` | New focused page/frame/fit and scripted-runner proofs. |
| Existing `tests/aloemacs/*.rkt` with affected fixtures | Prompt-constructor/field inventory migration, new helper signatures, and full retained-list expectations. Preserve substantive predecessor assertions. The manager names the exact affected files after searching the inventory. |

Leave `editor.aloe`, `host/racket/term.rkt`,
`host/racket/aloemacs-run.rkt`, host capabilities, libraries, `aloe/`,
`SPEC.md`, `CHECKPOINTS.md`, predecessor designs/checkpoints, and the
idle-echo checkpoint untouched. Keep the two loads and existing class
declaration order in `file.aloe`. Add no class. Buffer, editor, history,
view, window, command, and keymap shapes stay exact.

The session retains these fourteen fields, in this order:
`buffers`, `fs`, `echo`, `searching`, `query`, `origin`, `wrapped`,
`failing`, `kill-ring`, `pending`, `prompt`, `last-submission`,
`waiting-command`, `windows`. All extra page state belongs to the prompt.

Plain Page Down already maps from Term's `next` with exactly no modifiers
to `"page-down"`; plain Page Up maps from `prior` likewise to `"page-up"`.
Use those strings. Add no mapping, Term method, command constructor, or
keymap binding. Modified forms keep their existing conversion path;
they receive no new completion meaning.

Explicit non-goals are a highlighted/selected row, a selection marker,
Up/Down traversal, cycling a name into text, live updating on typing,
fuzzy/substring/partial matching, sorting/filter changes, prefill changes,
buffer/command completion, `M-x`, a directory browser, or opening a
directory with Return. Also excluded: Tab paging/indentation, `~`,
wildcards, history, `mkdir`, symlink traversal, a dirty bit, prompt undo,
a new echo token, host/String/Text/Term methods, List indices, language
amendments, runner changes, session fields, Mirror, mutation,
inheritance, delegation, macros, or new special forms. Do not design a
later project here or skip ahead to Boids.

## 3. Layer 000 — retain and page one Tab's names

### 3.1 Prompt state and helpers

Append two fields to `AloemacsPrompt`, keeping its first five exact:

```aloe
(label String)
(text String)
(column Int)
(completion-note String)
(completion-lines (List String))
(completion-matches (List String))
(completion-start Int)
```

Construction is now
`(AloemacsPrompt new label text column note lines matches start)`.
Generated reads `completion-matches` and `completion-start` return
`(List String)` and `Int`. `completion-lines` remains the prepared
window paint already reads. `completion-matches` is the full ordered
list of **display Strings** from the last list-producing Tab, including
directory slashes. It contains neither Entry values nor generated
summary rows. `completion-start` is a zero-based count of retained
names before the current window, never a selected-row index.

Fresh prompts, notes, unique results, common-prefix edits, and cleared
completion state have empty matches and start `0`. A Tab snapshot has
note `""`, nonempty matches, and the canonical prepared window in §3.3.
For up to eight matches, start is `0`; for more than eight, valid starts
are `0, 7, 14, ...`, strictly less than the match count. Callers of raw
constructors/helpers supply these invariants. Add no validator, cached
length, page number, selection, or active flag.

Keep `row()` and `screen-column(columns)` unchanged: the prompt row is
label + text + note, and its cursor at positive width is
`min(columns, label.len + column + 1)`. Neither retained nor prepared
lines enter the row or cursor calculation. Raw controls remain stored;
painting clips first and replaces controls with one space.

Prompt helpers have these contracts:

| Send | Result | Contract |
|---|---|---|
| Existing `with-completion(text : String, note : String, lines : (List String))` | `AloemacsPrompt` | Keep its signature and existing label/text/column/note/prepared-line behavior. Additionally clear `completion-matches` and set start `0`. Tab uses this for its non-list results, all with empty `lines`. |
| New `with-completion-page(matches : (List String), start : Int, lines : (List String))` | `AloemacsPrompt` | Preserve label, text, and column exactly. Set note `""`, install the three page values. Callers supply §3.3's canonical prepared lines for that snapshot/start. Used both to install Tab's first window and to move a retained window. |
| Existing `clear-completion()` | `AloemacsPrompt` | Preserve label/text/column; clear note, prepared lines, retained matches, and start to `""`, empty, empty, `0`. |

An independently constructed painter fixture, or a direct legacy
`with-completion` send with supplied prepared lines, may have no retained
snapshot. It still paints those supplied lines as before and cannot page.
It does not count as a list-producing Tab. Do not infer a complete snapshot
from prepared lines: their final String might be a generated summary.

Valid insert clears all four completion fields before editing. Backspace
also clears them before deletion, **including at column zero**. Invalid
insert arguments and direct LF keep today's unchanged result. Left,
right, line-start, and line-end preserve note, prepared lines, matches,
and start exactly, including at boundaries. Ignored keys preserve the
whole prompt. Return and Escape discard all page state by ending it.

Existing session `completion-note()` and `completion-lines()` keep their
signatures and no-prompt results (`""` and empty). No new session read
or field is needed for retained state; it is available on the prompt.
Reconstruction, direct buffer/window operations, fit, and frame preserve
the whole prompt value under their existing rules. A successful direct
visit still drops the prompt; a refused visit preserves it.

### 3.2 Tab retains the snapshot and always resets to its first window

Keep `complete-prompt()` and its eligibility: only an active prompt with
a waiting `FindFile` or `SaveAs` completes. Case on command constructors,
not labels or name strings. The session owns all Fs queries, the prefix
decision, Entry classification, filtering, and installation of results.

Every Tab still splits the **whole text** at its last slash, independent
of column, and uses the typed directory spelling for any replacement.
No slash uses `Fs.current`; otherwise lookup uses `Fs.path` for that
directory string. Only an inspected Directory permits `entries`.
Missing/regular/symlink/Other directory candidates do not enumerate.
Host failures retain their existing propagation.

The filter remains case-sensitive prefix of the leaf. Names beginning
with `.` are retained only when the leaf starts with `.`. Keep the order
`entries` returns, with no extra sorting. Longest common prefix uses raw
base names. Display lines append `/` only for Directory entries and keep
spaces, controls, case, and all other raw name characters. Never follow
a symlink to decide its slash or list inside it.

The result table stays:

| Matches | Result |
|---|---|
| Zero | Unchanged text/column; note `" [No match]"`; prepared/retained lists empty; start `0`. |
| One, replacement differs | Original typed directory + name, with `/` only for Directory; column at new text end; no note/list; start `0`. |
| One, replacement equals text | Unchanged text/column; note `" [Sole completion]"`; no list; start `0`. |
| Two or more, common prefix extends leaf | Original typed directory + common prefix, no added slash; column at new end; no note/list; start `0`. |
| Two or more, common prefix cannot extend leaf | Unchanged text/column; retain **all** filtered display lines; note `""`; start `0`; prepare §3.3's first window. |

In the final arm, build the full display list as today, send the scanner
`window-lines matches 0`, and install it through prompt
`with-completion-page matches 0 prepared`. Remove only the old local
truncation that discarded names beyond the first prepared window.

Every eligible Tab re-queries the directory, even from a later page or
after a horizontal motion. It replaces the old snapshot and starts at
`0` when it again produces a list. If the fresh result is a note or text
extension, it clears the snapshot. A changed filesystem/double can
therefore yield different names or no list. Paging never refreshes it.
Ordinary typing, motion, paging, fitting, and painting make no completion
query. Completion still reads/writes no file contents.

### 3.3 Fixed windows, exact summary, and end behavior

The prepared window has at most **eight rows**, independent of terminal
dimensions. No size read participates in preparation or page movement.
An unused terminal row stays with the file's root.

Let `n` be retained display-line count and `s` a valid window start:

| Snapshot | Prepared window |
|---|---|
| Empty | Empty; start `0`. |
| `1 <= n <= 8` | All `n` names, start `0`, no summary. Both page keys return the session unchanged. |
| `n > 8` | Skip `s` retained names, then prepare the next `m = min(7, n - s)` names, followed by exactly one summary. |

The summary is exactly `...(+N)`, with base-ten Int text and no spaces,
position suffix, or other decoration. `N = n - m`: **every retained
line outside this window**, including names before it as well as after
it. It is neither a match nor typed data and starts with `...(+`.
Only generated summaries are excluded from the retained snapshot;
do not filter a real raw name merely by its painted spelling.

A window hiding nothing has only name rows; one hiding any retained
line has exactly one summary. For `n > 8`, even the last window hides
earlier names and therefore has a summary. A nonempty valid window
never has zero names or two summaries. Eight matches still prepare
eight names. Nine still start with seven names and `...(+2)`.

For an 18-line snapshot, let `a01` through `a18` denote its ordered
display lines; these labels add no production sorting rule:

| Window | Start | Name rows | Summary | Total prepared rows |
|---|---|---|---|---|
| First | 0 | `a01`–`a07` | `...(+11)` | 8 |
| Middle | 7 | `a08`–`a14` | `...(+11)` | 8 |
| Last | 14 | `a15`–`a18` | `...(+14)` | 5 |

Page Down advances to `s + 7` only when that value is less than `n`.
Otherwise it returns the whole session unchanged. Page Up moves to
`max(0, s - 7)`; at `s = 0` it returns the whole session unchanged.
Neither key wraps. Backward movement uses the same seven-name step.
Forward windows are disjoint consecutive slices; the last is the tail.
Reversing one step restores the previous prepared window exactly.

This rule reaches every retained name, including in lists longer than
two full windows. After the last window a further Page Down is a specified
no-op; after the first window a further Page Up is likewise a no-op.
The step is the number of **name** rows in a full window, never eight
including the summary or the number of rows currently painted.

### 3.4 Pure skip walk on the existing scanner

Add these typed methods to the existing fieldless nongeneric
`AloemacsCompletionScan`, retaining its character/prefix methods:

| Send | Result | Contract |
|---|---|---|
| `drop-lines(lines : (List String), count : Int)` | `(List String)` | If count is nonpositive or lines are empty, return lines. Otherwise recurse **on this scanner** with `lines.rest` and `count - 1`. Returns the remaining tail; dropping beyond the end safely returns empty. |
| `window-lines(matches : (List String), start : Int)` | `(List String)` | For an empty snapshot return empty. For at most eight matches with start `0`, return all names. Otherwise, for a valid start under §3.1, use `drop-lines`, retain the first at most seven tail names in order, and append §3.3's summary using the full match count. |

Use existing `List` `empty?`, `first`, `rest`, `cons`, `len`, and its
Aloe `fold`, `reverse`, and `map` methods, plus existing Int/String
sends. A bounded fold can collect seven names by `cons`, add the summary
to that reversed accumulator, and reverse once for display order.
There is no List index, new host helper, String/Text method, or callback
interface. Check empty before sending `rest` or `first`.

The skip walk consumes a shorter list and a smaller positive countdown
on each recursive send. This scanner is checked once at definition.
`(AloemacsSession H)` is a legacy generic `(fields ...)` class whose
method body is checked again on each send; a recursive send on it does
not finish checking. Keep the recursion on the nongeneric scanner, not
on that session or another legacy generic. Add no generic helper class
and make no checker change. The session constructs a local scanner as
needed, stores none, and continues to own all Fs operations and prompt
result application. The scanner receives only String/Int/List data,
with no Fs/session/prompt/buffer payload or effects.

### 3.5 Active-prompt routing and preservation

Add `page-completion(key : String) -> (AloemacsSession H)`. It performs
no filesystem or Term send. Called directly, it acts only for
`"page-down"` or `"page-up"`, with an active prompt, a waiting `FindFile`
or `SaveAs`, empty completion note, nonempty prepared lines, and more
than eight retained matches. Every other case returns the whole
receiver unchanged. For eligible movement, derive the new start under
§3.3. At a stopped boundary return the whole receiver unchanged;
otherwise prepare from the cached matches on the scanner and replace
only the active prompt through `with-completion-page` and
`with-active-prompt`.

`handle-key` keeps its existing precedence: quit, active search, active
prompt, pending prefix, idle map. As with the existing prompt helpers,
that entry point owns quit/search routing; direct `page-completion` has
the eligibility gate above and does not dispatch another state machine.
Add the two named keys to `prompt-key`, both sending `page-completion`.
No active-prompt page key is forwarded to a keymap, an editor motion,
`execute-command`, or the session's idle `page-up`/`page-down` methods.

| State at `handle-key` | Result for a page key |
|---|---|
| Already quit | Whole session unchanged, no effects. |
| Active search | Existing search other-key rule ends search, then goes through idle dispatch; it never retries completion paging through a retained prompt. |
| Active eligible file prompt showing a snapshot | Move or stop by §3.3; text and column unchanged. |
| Active select-buffer, bare prompt, other waiting command, or file prompt without a pageable snapshot | Whole session unchanged. |
| Pending prefix, with no active search/prompt | Existing consumed miss: clear prefix and echo; do not page either names or buffer. |
| Idle | Existing global Page Up/Down buffer command and echo behavior. No completion paging. |

Ignoring paging in search/idle means no movement of the completion
window. Existing buffer page commands are preserved: a search key's
idle fall-through can still run them. In a raw fixture with both prompt
and pending state, the active prompt wins and paging preserves pending.
With search and prompt together, search wins and leaves the cached page
unchanged even if its inherited idle action moves the buffer.

Tab still recomputes the first window. Up/Down and other ignored named
prompt keys stay ignored. Printable characters still insert; Return
still submits; Escape still cancels. Page keys do not set a highlighted
row, copy a name into text, or change the editable cursor.

Successful paging changes only prompt `completion-start` and
`completion-lines`. It preserves its label/text/column/note/matches,
the buffer collection and focus, every buffer/editor value (Text and
its focus, point, quit, undo/history, mark, both origins, remembered text
rows, path/name/ID), Fs, echo, all search fields, ring, pending,
submission, waiting command, and complete window configuration.
No edit, fit, scroll, buffer selection, read, or write is part of paging.
It sends none of Fs `current`, `path`, `parent`, `name`, `inspect`,
`entries`, `read`, or `write`, and therefore no underlying host method.

### 3.6 Return, Escape, and unchanged paint/fit

Return stores **only `prompt.text`**, ends the prompt before running the
waiting command, and clears that command after a returned outcome.
Displayed names, summary, and offset never enter submission. The exact
typed string remains unclipped and unsanitized. Find-file retains
resolved-name reuse before reading, regular-file opening, missing-file
empty-buffer addition without creation, and directory/symlink/Other/read
refusal. Save-as writes the current exact buffer text and changes its
binding only on success; refusals preserve its editor/binding. Empty file
submission still fails without any Fs call. Host failures propagate as
before. Select-buffer still uses the typed exact derived name without
Fs. A prompt with no waiting command still only stores its submission.
An inactive second submit does nothing.

Escape ends the prompt, clears the waiting slot, retains the previous
submission and echo, makes no Fs call, runs no command, and does not
quit. Direct inactive cancel still clears an orphaned waiting slot.
Return acts on the buffer current at submission, including after an
existing direct selection that preserved the prompt.

Paint reads only `completion-lines`. At positive dimensions:

```text
k = 0                                      when rows < 2
k = min(prepared-line count, rows - 2)      when rows >= 2
root height = rows                         when rows < 2
root height = rows - 1 - k                 when rows >= 2
```

The root retains at least one row. For `rows >= 2`, the prompt stays on
terminal row `rows`; list rows occupy `root height + 1` through
`root height + k`, full width, immediately below the root and above the
prompt. Each uses `prepared-line.take(columns)`, then `safe-cells`.
Controls paint as one space; there is no name ellipsis, row marker,
selection, or list cursor. At one row, no list or echo row paints.

The renderer paints the first `k` prepared lines without changing the
snapshot, start, or summary. A short terminal can hide some prepared
names and the summary; it does not change page boundaries. Every name
is reachable in a prepared window, and every name in that window is
visible when at least ten terminal rows allow all eight prepared rows.
Growing the terminal reveals the rest of the same window without a new
query. Do not compensate for clipping by overlapping/shortening steps.

For the 18-line snapshot above:

| Terminal rows / window | Prepared rows | Painted list | Root height | Prompt row |
|---|---|---|---|---|
| 12 / first | 8 | `a01`–`a07`, `...(+11)` | 3 | 12 |
| 12 / middle | 8 | `a08`–`a14`, `...(+11)` | 3 | 12 |
| 12 / last | 5 | `a15`–`a18`, `...(+14)` | 6 | 12 |
| 5 / first | 8 | `a01`–`a03` | 1 | 5 |
| 5 / middle | 8 | `a08`–`a10` | 1 | 5 |
| 5 / last | 5 | `a15`–`a17` | 1 | 5 |

The shorter last window returns spare rows to the file. Mode-line leaves,
split dividers/junctions, global fallback, selected fit, cursor clamp,
ANSI envelope, and idle echo keep completion's current rules. A page
key itself never fits or scrolls. The runner's next inherited fit may
adjust only selected origins/remembered height under the existing
minimal-fit rule; no special origin save/restore is added. Fit preserves
the full prompt snapshot. Frame is pure. With no list, complete frames
and root/fit values remain unchanged. The runner still fits before
framing, builds one String, and issues one `term write` per drawn frame;
this series does not edit it.

### 3.7 Constructor and fixture migration

Every valid `AloemacsPrompt new` gains the two final arguments, including
independent expected values and typed absent-prompt witnesses. Empty or
display-only predecessor fixtures use `(List empty)` and `0`. New
pageable fixtures supply the full raw display list and a valid start,
with the corresponding prepared window. Do not use a first-window
summary as a retained match or invent hidden names for a painter fixture.
Actual Tab expectations now retain the full list even when only seven
names and a summary are prepared. Preserve old frame assertions.

The lawful absent-prompt witness at untyped sites becomes:

```aloe
(if #t
    (Option None)
    (Option Some
      (AloemacsPrompt new "" "" 0 "" (List empty) (List empty) 0)))
```

Expected constructor field types may still supply bare `None` inside
methods. Do not change Option inference or session constructor arity.

Search `examples/aloemacs/` and all `tests/aloemacs/` for prompt
constructors, exact prompt inventories, and helper signatures. Current
sites include `main.aloe`, prompt start/edit/motion/submission helpers in
`file.aloe`, `completion-session.rkt`, `completion-frame.rkt`,
`minibuffer-*.rkt`, `prompt-commands-*.rkt`, `windows-*.rkt`,
`mode-line-*.rkt`, `buffer-*.rkt`, and runner, motion, search, keymap,
file, safe-cells, idle-echo, kill, echo, viewport, undo, and
visited-unchanged tests. Do not treat this inventory as exhaustive.
Keep intentional old-arity negatives; update other negatives so they
still test their original wrong field/type at the new arity. Preserve
the existing `with-completion` signature and its negative tests.

## 4. Verification

The implementer writes focused tests first and observes missing behavior
fail before product changes. All tests use checked sends, literal expected
windows, independent frame expectations, and counted effects. Required
proofs are:

1. **Checked state and recursion.** Exact seven-field prompt and generated
   read/helper types; unchanged fourteen-field session, commands, maps,
   and zero-field nongeneric scanner. Wrong receivers, argument types,
   and arities fail checking. Fresh checked loads remain effect-free
   without injected Fs/Term. Scanner drop cases include zero/negative
   counts, empty, dropping within/to/beyond the end, and checked recursive
   calls. Window expectations cover 0, 1, 7, 8, 9, 14, 15, and 18 retained
   Strings, first/middle/tail, literal summaries, order, directory slashes,
   and raw controls. Add no hanging legacy-generic recursion test.
2. **Reachability and stops.** On actual find-file and save-as sessions
   after an ambiguous Tab, an intentionally unsorted Fs listing has 18
   filtered matches, more than two full windows. Page Down yields starts
   `0 -> 7 -> 14 -> 14`; Page Up yields `14 -> 7 -> 0 -> 0`. Assert exact
   prepared names/summaries, every retained name reached in order without
   skipped/overlapping forward windows, whole-session equality at stops,
   unchanged typed text and an interior column, and no selection. For
   eight matches, both keys are whole-session no-ops. Include a nine-name
   tail and exact full seven-name tail to rule out off-by-one/empty pages.
3. **Snapshot and lifetimes.** Record every Fs host call, then change the
   listing after Tab. Paging, horizontal motion, fit, and frame add zero
   calls and still use the old snapshot. Tab queries again, replaces it,
   and resets to the first window. Exercise fresh list, no-match, sole,
   unique, and common-prefix outcomes from a later page. Insert and
   backspace (also column zero) clear all page state; motions preserve it;
   invalid insertion/LF and ignored named keys preserve it. Keep the
   existing case/dotfile/prefix/slash and typed-spelling assertions.
4. **Routing and rich preservation.** Both keys on select-buffer, bare
   prompt, another waiting command, no-list file prompt, note, and absent
   snapshot change nothing. Quit absorbs both. Pending prefix consumes
   both as existing misses. Idle still runs existing buffer page commands;
   search still exits and takes its inherited idle path. Mixed raw fixtures
   prove precedence without changing the cached prompt page. Eligible
   paging compares complete buffer collection/editor and window values,
   with nontrivial focus, text zipper, point, undo, mark, origins, remembered
   sizes, shared views/locks, paths/names/IDs, ring, echo, search payloads,
   previous submission, and waiting command. Only prepared lines/start
   may differ. Prove concrete session result types with two Fs host types.
5. **Command outcomes after paging.** Return submits the exact typed
   path rather than any page name; find-file keeps reuse, regular/missing,
   refusal, and no-creation results; save-as writes exact contents once
   to the typed target and changes binding only on success. Include
   directory refusal despite a displayed directory slash, empty submitted
   text, failure, and inactive second submit. Escape after paging retains
   previous submission/echo, clears prompt/slot, runs nothing, and makes
   zero calls. Retain select-buffer/bare prompt and host-failure proofs.
6. **Prepared-window paint and runner.** Compare complete frames for first,
   middle, and tail pages at heights 12 and 5, plus heights 1, 2, and 10
   and narrow widths/width one. Count root/list rows independently;
   clipping never recomputes the summary. Include raw LF/CR/Tab/ESC/DEL,
   clipping before safe cells, directory slashes, and summary clipping.
   Exercise one view, visible splits/shared views, and list-induced global
   fallback. Fit/frame preserve matches/start; the last window's spare
   rows rejoin the root, and clearing the list restores the no-list
   geometry. A scripted Term/Fs run drives Tab, forward/backward pages,
   redraw/resize, fresh Tab, Return/cancel, and quit through the unchanged
   runner. Assert fit-before-frame, last-row prompt cursor, one String/write
   per drawn frame, no Fs calls between Tabs except submitted actions,
   and visible last match at a size that paints the full window.

Run from the project root:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/completion-page-session.rkt tests/aloemacs/completion-page-frame.rkt tests/aloemacs/completion-session.rkt tests/aloemacs/completion-frame.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

`TMPDIR=/tmp` and `-y` are required for agent runs. The no-TTY suite is
the acceptance evidence; no benchmark, wider suite, or physical-terminal
tour is required. A hands-on tour can wait until 000 is green. Review
source for the nongeneric recursive receiver, complete snapshot retention,
no page-key Fs/Term sends or idle-command fall-through, unchanged runner/
checker/keys/maps, and prompt-only page state.

Do not commit `compiled/`. The optional existing launch is
`racket host/racket/aloemacs-run.rkt [path]`. After any `.rkt` edit, run
the tests above or `raco make host/racket/aloemacs-run.rkt bin/aloe`
before launching; launchers do not rebuild bytecode. `.aloe` edits need
no rebuild. Do not add a build on every launch.

## 5. Acceptance and stop

000 is complete only when:

1. Every filtered display name from a Tab has a reachable prepared window;
   repeated forward presses reach the last match and then stop. Backward
   presses restore the first window and then stop. Neither edits text or
   column, selects a row, queries Fs, or scrolls the current buffer.
2. Tab retains its prefix results and always re-queries/reset-starts a list;
   notes and edits clear the snapshot, horizontal motions preserve it,
   and the first eight/seven-plus-summary windows match completion today.
3. Paging is owned by eligible active file prompts. Other prompts ignore
   it; quit, search, prefix, and idle retain their existing dispatch effects
   without completion paging. Return/Escape keep every inherited outcome.
4. Prompt-only state preserves the current buffer, collection, and windows;
   no new session field, host method, Term mapping, List index, or checker
   change appears. The skip recursion checks and runs on the existing
   nongeneric scanner.
5. The prepared window paints through the existing last-row prompt,
   clipped/safe rows, shortened root, mode lines, splits/fallback, and
   fit-before-frame single-write runner. Short terminals clip the current
   window; no-list frames/fit and idle echo stay unchanged.
6. Focused tests and `TMPDIR=/tmp raco test -y tests/aloemacs` pass without
   a TTY, and changes stay within §2's scope. The implementer stops when
   green; no second checkpoint or adjacent feature follows.

The designer stops at this specification and this folder's README status update.
Human acceptance precedes checkpoint work. The manager writes
**aloemacs-completion-page 000 only**, then stops.

If you have been told to read this file as the checkpoint-manager
assignment, it is the whole assignment.
