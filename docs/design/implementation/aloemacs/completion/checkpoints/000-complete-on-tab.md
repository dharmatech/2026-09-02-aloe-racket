# aloemacs-completion 000 — Complete file prompts on Tab

**Status: Ready to implement.** Rewritten on 2026-10-04 against the
accepted spec revision. Recursive scans and the common-prefix fold
belong to the fieldless nongeneric `AloemacsCompletionScan`; the
session keeps Fs queries and completion results. The earlier attempt
was reverted and did not complete this checkpoint. Start from the
current predecessor implementation, with no partial completion code
assumed.

## Goal

Find-file and save-as start with editable directory/path text. Plain Tab
completes the last component using the injected Fs, with exact prompt-row
notes and readable prepared matching names. Extend the prompt value and
migrate its constructors in the same slice. Return and Escape keep their
accepted command results.

Stop with metadata, prefill, Tab conversion, completion, notes, and
prepared lines proved. Do not paint the prepared lines or reserve space
for them. Frame/fit geometry, mode-line allocation, and idle echo retain
their current behavior. List painting belongs to 001, which is not issued.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity is **aloemacs-completion 000**. There is no predecessor
  checkpoint in this series. Do not use a global checkpoint number.
- The accepted revision places recursive work on the nongeneric
  scanner. **checker-recursion is not a predecessor or an assignment.**
  Leave the checker unchanged and do not add recursive completion sends
  to a legacy generic `(fields ...)` receiver, including the session.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), `SPEC.md`, and
  `CHECKPOINTS.md` before writing code. `SPEC.md` remains Aloe language
  law: evaluation is send, selectors are literal, and function objects
  execute only through `call`.
- Accepted [../spec.md](../spec.md) §§1–2 govern authority, predecessors,
  product/host boundaries, and scope. All of §3, §5's 000 verification,
  and §5's acceptance conditions as applicable to this slice govern the
  work. §4 describes 001 and adds no implementation work here.
- Text through Mode line (parent layers 1–18) are implemented. Prompt
  commands, editing, windows, mode lines, echo, safe cells, and keymap
  retain the contracts cited by spec §1 except its explicit supersessions.
  Final windows/mode-line review is not a prerequisite. Report blocking
  predecessor defects instead of repairing those layers.
- Idle echo is implemented in this checkout: both frame composers send
  `echo-row(columns, leaf-rows)`, whose idle branch is empty when the
  selected displayed leaf has a mode line. Preserve it. Idle-echo 000
  is not a dependency and its document/payload must not change here.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  `AloemacsPrompt` currently has label/text/column. The session has
  fourteen fields, an active prompt and waiting-command slot, command
  start guards, and `prompt-key`. Both frame composers already paint
  `prompt.row` through clipping and safe cells; notes need no geometry
  change. Keep the two loads and all existing declarations in their
  relative order; insert only `AloemacsCompletionScan` immediately after
  `AloemacsPrompt` and before `AloemacsBuffer`, as spec §2 requires.
- [main.aloe](../../../../../../examples/aloemacs/main.aloe) has an
  untyped absent-prompt witness. The unchanged
  [runner](../../../../../../host/racket/aloemacs-run.rkt) supplies the
  existing `run-aloemacs-with-hosts` seam, fits at full terminal size,
  frames/writes once, then reads a key.
- [term.rkt](../../../../../../host/racket/term.rkt) currently rejects
  a plain non-printable Tab. Add only the specified conversion.
  [Fs](../../../../../../lib/fs.aloe) already supplies `current`,
  `path`, `parent`, `name`, `inspect`, and `entries`; `entries` sends
  the directory-only host `names`, then child inspection, retaining
  enumeration order. String `starts-with?` is already installed in
  default checked environments; no additional load is needed.

The inventory below makes this a bounded slice: three product files,
two new focused proofs, and 30 existing test files. Most existing edits
append two constructor arguments or insert the scanner in an exact
class-order expectation; behavior migration is limited to the named
prefill/start/submission and runner expectations. Session arities do not
change. Keep the spec's two-checkpoint partition. If the slice
proves too large for one implementer conversation without compaction,
stop and return the size finding to the manager rather than splitting
or widening the assignment yourself.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: prompt fields/helpers/editing and
  witnesses; the one fieldless nongeneric scanner and its five methods;
  session metadata reads, prefilled command start, shared completion
  algorithm, and the named Tab arm in `prompt-key`. Only the scanner
  owns self-recursive completion scans/folds. Filtering, preparation,
  and result application remain on the session using existing List
  sends and local values. Existing `prompt.row` painting displays notes;
  do not change either frame composer or fit/geometry method in this slice.
- `examples/aloemacs/main.aloe`: only migrate its absent-prompt witness.
- `host/racket/term.rkt`: only plain Tab normalization in
  `tkeymsg->aloe-key`, with an ordinary predicate if needed.
- Create `tests/aloemacs/completion-session.rkt` and
  `tests/aloemacs/completion-key-mapping.rkt` before product edits.
- The following **30 existing test files**, only for the migrations
  listed. Paths in the table are relative to `tests/aloemacs/`.

  | File | Permitted migration |
  |---|---|
  | `buffer-session.rkt` | Append empty prompt metadata to absent-prompt witnesses. |
  | `buffer-value.rkt` | Append empty metadata to absent-prompt witnesses and independent constructors. |
  | `echo-session.rkt` | Append empty metadata to absent-prompt witnesses. |
  | `file-session.rkt` | Append empty metadata to the absent-prompt witness. |
  | `idle-echo.rkt` | Append empty metadata to the active prompt fixture; preserve every idle payload and full frame. |
  | `keymap-prefix.rkt` | Migrate constructors and exact FindFile/SaveAs start text/column and allowed prefill Fs counts. SelectBuffer stays empty and effect-free; keep bindings and prefix rules. |
  | `keymap-session.rkt` | Migrate absent-prompt witnesses; keep command/map inventories, dispatch, and concrete receiver types. |
  | `kill-session.rkt` | Append empty metadata to the absent-prompt witness. |
  | `minibuffer-session.rkt` | Migrate active/absent/expected prompt constructors. Bare start and the five existing filtered method signatures remain unchanged. |
  | `minibuffer-value.rkt` | Migrate constructors, exact prompt field/method inventories, generated reads, and type/arity negatives. Keep the original editing, raw-value, frame, and fit proofs. |
  | `mode-line-one-view.rkt` | Migrate constructors and the runner's prefilled FindFile prompt frame/cursor and allowed Fs queries. Preserve geometry, fit, mode-line bytes, idle payload, and save effects. |
  | `mode-line-row.rkt` | Insert the scanner in its exact class-order expectation only; preserve all mode-line, payload, capability, type, and geometry proofs. |
  | `mode-line-split-views.rkt` | Migrate constructors and the runner's prefilled FindFile strings/cursors, submission spelling/Fs counts, and any explicit replacement keys/iterations. Preserve the target buffer, split geometry/origins, and complete frames. |
  | `motion-editor.rkt` | Append empty metadata to the absent-prompt witness. |
  | `prompt-commands-find-file.rkt` | Migrate constructors, prefill starts/columns/calls, command scenarios that typed into an empty file prompt, empty-submission setup, and scripted runner inputs/frames/effect counts. Preserve exact Return targets/results and all reuse/read/refusal proofs. |
  | `prompt-commands-save-as.rkt` | Migrate constructors, bound/pathless prefill starts/columns/calls, replacement input and empty-submission setup, and scripted runner expectations/counts. Preserve write targets, exact saved text, binding/editor retention, and refusals. |
  | `prompt-commands-select-buffer.rkt` | Migrate constructors and the runner's introductory FindFile segment, including prefill, replacement/submission spelling, frames/iterations/Fs snapshots. SelectBuffer still starts empty and its own segment makes zero Fs calls. |
  | `runner.rkt` | Append empty metadata to the startup witness; retain injection, startup, binding, and runner inventories. |
  | `safe-cells.rkt` | Append empty metadata to the absent-prompt witness; keep existing raw-control frames. |
  | `search-session.rkt` | Append empty metadata to the absent-prompt witness; keep search state/routing. |
  | `undo-session.rkt` | Append empty metadata to the absent-prompt witness; keep history/editor proofs. |
  | `viewport-editor.rkt` | Append empty metadata to session witnesses/constructors; keep viewport and direct-editor proof. |
  | `visited-unchanged.rkt` | Append empty metadata to absent-prompt witnesses; keep exact unchanged visit behavior. |
  | `windows-buffer-identity.rkt` | Migrate active/absent/expected prompt constructors only; retain IDs and retargeting. |
  | `windows-delete-and-other.rkt` | Migrate active/absent/expected prompt constructors only; retain command effects, focus/tree/geometry, and runner assertions. |
  | `windows-layout-and-rendering.rkt` | Migrate active/absent/expected prompt constructors only; all existing geometry, fit, and full frame bytes remain unchanged. |
  | `windows-lock.rkt` | Migrate constructors and permitted file-command start text/columns/queries under the lock. Keep direct submitted targets, all lock rules, and zero effects on guarded starts. |
  | `windows-split.rkt` | Migrate active/absent/expected prompt constructors only; retain split guards, origins, geometry, and frames. |
  | `windows-state-foundation.rkt` | Migrate constructors and its permitted FindFile start text/column/Fs counts. Preserve fourteen-field reconstruction, ownership/origins, fit, and frames. |
  | `windows-state.rkt` | Migrate constructors and its permitted FindFile execution/start text/column/Fs counts. Preserve mixed-state routing, selection, geometry, and direct submitted actions. |

In addition to the per-file migrations, these eleven files assert the
exact `file.aloe` class order: `buffer-value.rkt`,
`minibuffer-value.rkt`, `mode-line-row.rkt`,
`prompt-commands-find-file.rkt`, `windows-buffer-identity.rkt`,
`windows-delete-and-other.rkt`, `windows-layout-and-rendering.rkt`,
`windows-lock.rkt`, `windows-split.rkt`,
`windows-state-foundation.rkt`, and `windows-state.rkt`.
Insert `AloemacsCompletionScan` immediately after `AloemacsPrompt`
in those independent expectations. Retain every other declaration and
its order, and every non-prompt payload/signature inventory. This is
the sole new class allowed by the spec, not permission to loosen an
inventory assertion. `runner.rkt` may include the scanner in its
existing fresh-driver bound/unbound checks as well as migrate its
startup witness.

This inventory comes from searching product and the whole aloemacs suite
for `AloemacsPrompt new`, prompt inventories, file-command starts,
FindFile/SaveAs dispatch, and scripted runner inputs/full frames. Existing
`key-mapping.rkt` has no Tab-specific expectation to migrate; keep it
unchanged and add the separate converter proof. Search again after the
migration; intentional old-arity negatives remain old-arity negatives.

### Must leave untouched

- Every existing test not named above; no shared helper module, later
  focused file, or test infrastructure change.
- `examples/aloemacs/editor.aloe`, `host/racket/aloemacs-run.rkt`,
  `host/racket/fs.rkt`, every other product/host file, `aloe/`, and
  `lib/`. No new dependency, host interface/capability, load, runner
  argument, or build step.
- `SPEC.md`, `CHECKPOINTS.md`, global checkpoints, accepted spec,
  charter/README/checkpoints, and predecessor documents during
  implementation.
- Session fields/arity/order, editor/UndoFrame/buffer/view/window/tree
  shapes, command constructors, both keymaps, and all frame/fit/window
  command geometry. Only the prompt constructor grows.

If another file or design change is necessary, stop and send this
checkpoint back to the manager. Preserve substantive buffer/editor,
Text/focus, history, search, prefix, file-effect, window, and full-frame
assertions; no unrelated cleanup belongs in a fixture migration.

## Slice requirements

### 1. Prompt-owned completion metadata

Append `(completion-note String)` and
`(completion-lines (List String))` after label/text/column. Construction
is `(AloemacsPrompt new label text column note lines)`. Normal starts
and migrated fixtures supply `""` and `(List empty)`. No validator or
additional active flag is introduced. Normal results have either no
display state, one exact note below, or at most eight prepared lines;
a nonempty list and note never coexist.

Add these ordinary prompt sends:

| Send | Result and behavior |
|---|---|
| `with-completion(text : String, note : String, lines : (List String))` | `AloemacsPrompt`: preserve label, install the three arguments; changed text sets column to the new length, unchanged text retains column. |
| `clear-completion()` | `AloemacsPrompt`: preserve label/text/column, set empty note/list. |

`row` concatenates label, editable text, and note. The note is never
editable or submitted. `screen-column` remains
`min(columns, label.len + column + 1)` at positive widths, independent
of the note. Existing painting clips the combined row before safe cells.

Valid one-character insert clears completion before editing. Backspace
clears before deleting, even at column zero. All four horizontal motions
preserve metadata, including boundary motions. Invalid insert arguments
and direct LF are unchanged and do not clear metadata. Direct raw `"\t"`
remains an editable character distinct from named `"tab"`. Completion
may copy raw LF/other controls from a name; retain those characters and
paint them safely on the single prompt row without `split-lines`.

Add session reads `completion-note() -> String` and
`completion-lines() -> (List String)`: delegate to the active prompt,
otherwise return empty values, without Fs operations or recomputation.
Reconstructions preserve the whole prompt. Successful direct visit
discards it as before; a refused visit retains it exactly.

For an untyped absent-prompt constructor, use the lawful witness:

```aloe
(if #t
    (Option None)
    (Option Some (AloemacsPrompt new "" "" 0 "" (List empty))))
```

Do not replace it with bare `None`, change checking, or add an Option
setter. Method constructor positions with an expected type keep lawful
direct `None`. Session fields remain, in order: buffers, fs, echo,
searching, query, origin, wrapped, failing, kill-ring, pending, prompt,
last-submission, waiting-command, windows.

### 2. Prefill through the existing command starter

Retain `start-command-prompt(command : AloemacsCommand, label : String)
-> (AloemacsSession H)`. Apply the existing quit/search/pending/prompt
gate before any Fs query. Refusal returns the whole receiver unchanged,
including metadata/slot/submission/echo. The normal chord clears its
prefix before dispatch. Case on command constructors, never labels or
command-name strings; `execute-command`'s key does not supply a path.

| Permitted command start | Editable text |
|---|---|
| FindFile with bound path | Its parent-directory text with trailing `/`. |
| FindFile or SaveAs, pathless | `(fs current)` text with trailing `/`. |
| SaveAs with bound path | Exact stored path text. |
| SelectBuffer or another constructor passed directly | Empty, as before. |

Add `file-prompt-directory() -> String`: for a bound path send Fs
`parent`, using the Some parent's text or stored path text on None;
otherwise use Fs `current`. Keep a final `/` already present; append
one otherwise. Root stays `/`. Bound SaveAs does not call this helper.
Start with column `text.len`, empty metadata, and the actual waiting
command; preserve other state and the previous echo/submission. A
permitted start may replace an orphaned slot.

Prefill may use current/parent only. It does not resolve through `path`,
inspect, enumerate, obtain names, read, or write. Bound SaveAs,
SelectBuffer, bare start, and all refusals make zero Fs calls.
`start-prompt(label)` remains an empty-text, zero-column start with its
old gate and no Fs calls; it neither fills nor clears the waiting slot.
Keep exact chords/labels: `C-x C-f` / `"Find file: "`, `C-x C-w` /
`"Save as: "`, and `C-x b` / `"Buffer: "`.

### 3. One shared session completion algorithm

Add `complete-prompt() -> (AloemacsSession H)`. With no prompt, or a
waiting constructor other than FindFile/SaveAs (including None), return
the whole session unchanged with zero Fs calls. The active-prompt key
table sends it for named `"tab"`; add no keymap binding.

For either eligible command, operate on the whole editable text,
independently of its cursor. Split at the last `/`: the prefix includes
the slash and the leaf follows it. Slashless input has empty prefix and
the whole text as leaf; a trailing slash has an empty leaf. Empty prefix
looks up Fs `current`; otherwise resolve the prefix with Fs `path`.
Inspect that directory Path. Only Some Directory permits exactly one
Fs `entries`; missing, regular, symlink, Other, and None supply no
candidates without enumeration. Host failures still propagate.

For each returned Entry obtain its raw Fs name. Retain names starting
with the leaf, case-sensitively. Exclude names beginning with `.` unless
the leaf begins with `.`. Keep entries order; do not sort again. Use the
Entry's classification for the directory slash without following links.
Use the typed prefix for replacements, preserving `./`, repeated slashes,
`src/../src/`, and slashless spelling instead of resolved absolute text.

Compute the common prefix from raw names without display slashes. Every
Tab recomputes from current text and replaces the old note/list:

| Result | Replacement text | Note | Prepared lines |
|---|---|---|---|
| No candidates, including ineligible directory | Unchanged | `" [No match]"` | Empty |
| One candidate, replacement differs | Typed prefix + raw name + `/` only for Directory | Empty | Empty |
| One candidate, replacement equals text | Unchanged | `" [Sole completion]"` | Empty |
| Multiple candidates, raw common prefix longer than leaf | Typed prefix + common prefix; no extra slash | Empty | Empty |
| Multiple candidates, cannot extend leaf | Unchanged | Empty | Prepared as below |

Use `with-completion`: changed text moves the cursor to its end;
unchanged text retains its old column, even when display state changes.
A unique directory's next Tab looks inside it. A unique symlink gets no
slash; `link/` is ineligible for listing. Neither completion nor prefill
performs a file read/write.

For the multiple-candidate unchanged-text arm only, prepare raw base
names in entries order, appending `/` only for Directory. With at most
eight matches, store all names. Above eight, store the first seven and
`...(+N)` with `N = matches - 7`; nine gives `...(+2)`. Use existing Int
`text`/String concatenation for the summary. Do not add paths, markers,
padding, ANSI, clipping, sanitization, or terminal-size decisions.

#### Nongeneric recursive scanner

Add exactly one fieldless nongeneric class, `AloemacsCompletionScan`,
immediately after `AloemacsPrompt` and before `AloemacsBuffer`. Its
data section is `(fields)`, with no type parameters, and its ordinary
constructor is `(AloemacsCompletionScan new)`. Keep these exact typed
ordinary sends and their declared result types:

| Send | Result and behavior |
|---|---|
| `split-offset(text : String)` | `Int`: offset immediately after the last `/`, or `0`. Start `scan-slashes(text, 0, 0)`. |
| `scan-slashes(remaining : String, offset : Int, latest : Int)` | `Int`: for `0 <= latest <= offset`, an empty remainder returns `latest`. Otherwise consume one character, advance `offset`, update `latest` to the advanced offset only for `/`, and recurse on this scanner. |
| `common-prefix(names : (List String))` | `String`: an empty list returns `""`; otherwise start `prefix-in` with its first raw name and rest. |
| `prefix-in(prefix : String, names : (List String))` | `String`: an empty list returns `prefix`; otherwise reduce it with `shared-prefix(prefix, first name)`, then recurse on this scanner with the rest. |
| `shared-prefix(prefix : String, name : String)` | `String`: return `prefix` when `name starts-with? prefix`; otherwise remove the final prefix character with `take` and recurse on this scanner. The empty prefix matches and terminates shortening. |

Use existing String `take`, `drop`, `len`, `=`, `append`, and
`starts-with?`, and existing Int/List sends. Recursive steps shorten
the remaining String, remaining List, or prefix respectively.
The scanner accepts only String, Int, and `(List String)` data and
returns only Int/String. It owns no Fs, host, session, prompt, buffer,
Entry classification, note, or prepared-line state.

For each eligible Tab, `complete-prompt` constructs a local scanner,
sends `split-offset` the whole editable text, then derives the typed
directory with `text.take(offset)` and leaf with `text.drop(offset)`.
After the session's guarded Fs enumeration and filtering, send the
scanner `common-prefix` the raw matching names when at least two remain.
The session applies the result table and prepares lines through the
prompt's `with-completion`. Cache neither scanner nor prefix between
Tabs; add no session field or self-recursive session wrapper. Filtering
and prepared-line assembly use existing List sends/local values.

Add no other completion class/result, callback interface, host helper,
String/Text method, List index, or materialization of buffer Text. Do not replace
the scanner with a generic `(Name H)` `(fields ...)` class. Do not call
host `names` directly; count its use through unchanged Fs `entries`.

### 4. Routing, command outcomes, and unchanged geometry

Keep `handle-key` precedence: quit, search, prompt, pending, idle.
Quit absorbs Tab; search applies its existing other-key exit and idle
fall-through without retrying through a preserved raw prompt. Eligible
file prompts complete; all other/bare prompts ignore Tab. With a pending
prefix and no search/prompt, consume the miss and clear prefix/echo
without retry. Idle Tab is the named-key miss: clear echo, insert nothing.

Insert/backspace clear metadata without lookup; horizontal motions keep
it. LF/other ignored prompt keys, including Up/Down, retain the whole
session. Return stores only exact `prompt.text`, deactivates the prompt,
runs the waiting action, then clears its slot. Escape discards prompt/
metadata and slot, preserves echo and previous submission, performs no
command, and does not quit. Preserve orphan/inactive protocol rules.

Find-file keeps exact-name reuse, regular reads, empty missing-file buffer
without creation, and directory/symlink/Other/read refusals. Save-as keeps
exact writes and binding change on success, binding/editor retention on
refusal. Empty input still fails a file action without Fs calls. Selection
keeps exact derived names and zero Fs calls. Return acts on the buffer
current then; direct buffer/window operations retain the whole prompt/slot.

Prompt start/completion/clear changes only the allowed prompt/slot state.
Preserve buffers/focus/IDs, complete editors/Text, point/quit/history/mark,
origins/remembered rows, paths/names, windows/tree/selection/locks, Fs,
ring, search, pending, submission, and echo except inherited key-table
transitions. Push no UndoFrame, fit no buffer, and create/switch/kill none.

Prepared lines are readable but unused by fit/frame. Root height remains
`rows - 1` when an echo row exists and `rows` at height one. Mode lines,
selected fit, fallback, and full no-list frames remain unchanged; notes
paint through the existing clipped/safe prompt row. At height one no
prompt echo is painted. Frame writes no stored token or state and makes
no Fs call. Keep existing `""`, `"saved"`, and `"failed"` tokens and
the current idle payload.

### 5. Plain Tab conversion only

Before both printable branches of `tkeymsg->aloe-key`, map key `#\tab`
with mods exactly `'()` and decoded char either `#f` or `#\tab` to
`"tab"`. Shift-Tab remains unsupported. Other modifiers and mismatched
decoded characters retain their current conversion/error behavior,
including an existing printable-character fallback. Add no Ctrl-I alias,
decoder change, Term message, or second representation.

### 6. Focused proof, written first

Use the existing checked driver, `rackunit`, counted readable Fs doubles,
independent constructors/expected values/full ANSI strings, and scripted
Term doubles without a TTY. Write both new proofs before product edits
and observe missing behavior fail. Do not require another test module.

`completion-session.rkt` proves all of spec §3.6's focused requirements:

1. Exact five-field prompt, generated read/helper signatures and results,
   wrong receiver/type/argument/arity negatives, changed versus unchanged
   columns, metadata editing/motion lifetimes, raw controls/LF, and
   immutability. Prove fieldless nongeneric scanner construction, exact
   placement and all five signatures, wrong receiver/type/argument/arity
   negatives, and checked recursive results without Fs injection.
   Direct scanner cases include empty/slashless/root/trailing/repeated/
   multiple-slash strings and raw controls; empty/single/multiple name
   lists, equal names, an empty name, no shared prefix, and successive
   names that shorten the prefix more than once. Expected offsets and
   prefixes are independent literals. Exercise recursion through checked
   sends, not an unchecked evaluator or a host implementation; add no
   hanging legacy-generic negative test. Prove new session signatures
   and concrete results with two injected Fs host identities. Preserve
   session/command/map inventories, the two loads and old declaration
   order apart from the scanner insertion, effect-free fresh checked
   loads, and startup.
2. Every bound/pathless/root/parent-None/start/gate case, including custom
   labels, ignored execution key, bare start, other constructors, and
   orphan replacement. Count permitted prefill queries separately;
   refused starts, bound SaveAs, and bare/selection starts make none.
   No start enumerates or reads/writes.
3. All completion-result arms with changed/unchanged text and a cursor
   before the end. Cover empty/slashless/root/multiple-slash/relative
   prefixes, empty leaf, literal spelling retention, case sensitivity,
   hidden-name inclusion/exclusion, and each Entry classification.
   No-match/sole notes include their exact leading spaces.
4. Every non-directory inspection result and None performs no host
   `names`; each eligible Tab enumerates exactly once through `entries`.
   Count underlying resolve/child/kind/name/current operations rather
   than pretending Fs is a one-call listing. `inspect` may resolve and
   `entries` may inspect children. Assert no file read/write before
   Return and no symlink traversal for completion classification.
5. Zero/one/eight/nine-or-more candidates, raw common prefixes, unique
   directory versus non-directory slashes, summary count, and an
   intentionally unsorted names double proving enumeration order. Include
   spaces, Unicode, case, ESC/LF/CR/Tab/other low controls/DEL as raw data.
   Repeated Tab queries again and can replace old display state after
   the double changes; no cycling/paging or live lookup occurs.
6. Rich multi-buffer/shared-view snapshots around prefill, Tab, editing,
   clearing, and motions. Cover every routing-table state including
   mixed raw search/prompt/prefix and quit, preserving exact tokens,
   full session/editor/window payloads, source values, and slot/submission.
7. Independent complete ANSI frames with notes, clipping, safe cells,
   and clamped prompt cursor. Prepared lists stay readable but produce
   no list row or height change at small/tall sizes, visible splits, and
   global fallback. Existing mode-line and idle echo bytes stay exact.
8. Return reuse, fresh regular/missing-file outcomes, save-as writes and
   refusals, deliberately emptied prefill, exact selection, cancellation,
   and direct-operation prompt retention. Assert exact editable submission
   and Fs effects; notes/names never enter it. Return/cancel drop metadata
   and retain their existing protocol/command state transitions.
9. A production no-TTY runner sequence through prefill, Tab, redraw,
   Return/cancel, and quit using `run-aloemacs-with-hosts`. Compare complete
   strings and Term/Fs event counts, fit-before-frame at queried full
   size, one write per drawn iteration, and no lookup during draw/edit/
   motion. Prepared lines remain unpainted. Include a size where a
   scrolling point proves fit occurred before paint.

`completion-key-mapping.rkt` proves both allowed plain Tab shapes,
Shift-Tab, each modifier/decoded-character exclusion and its existing
fallback/error, repeatability, and representative existing Return,
Escape, Backspace, arrow, control, and printable conversions.

### 7. Independent regression migration

Append empty metadata to every valid prompt constructor, including
independent expected values and unselected None witnesses. Keep old-arity
negative cases intentionally old; update other negative constructors to
the new arity so their original field/type error remains meaningful.
Extend exact prompt inventories; do not loosen or remove them.
Migrate the eleven exact class-order assertions above by inserting only
the named scanner. There is no session-arity migration.

Never concatenate an old full-path input onto prefill. For a relative
submission, send `line-end`, then one `backspace` per initial-text
character, then type the original relative string. Empty-input proofs
delete all prefill before Return. When start is not under test, a direct
fixture may install its intended five-field prompt with `with-active-prompt`
while preserving the actual waiting slot. A runner may deliberately
retain absolute prefill and expect that exact absolute submission.

Runner replacement keys add drawn iterations; account for every one in
full frames/events/Fs snapshots. If a deliberate absolute submission
replaces a relative spelling, update resolve expectations explicitly
without changing the intended target/result. Count newly permitted
prefill calls separately from submission effects. Keep every zero-call
assertion outside the permitted prefill starts, all read/write targets,
and substantive exact-frame, buffer, window, editor, and command proofs.

## Explicit non-goals

No prepared-line painting/reservation, session root/fit helper from §4,
geometry/runner/window-command change, live list, selection/highlight,
Up/Down candidate movement, paging/cycling, fuzzy/substring matching,
buffer/command completion, `M-x`, history, `~` expansion, wildcards,
directory browser/Return opening, `mkdir`, symlink traversal, indentation,
prompt undo, dirty bit, or new echo token.

No host/library/language method, List index, further completion class,
result object, new dependency/module/load, checker change or
checker-recursion work, Mirror, mutation, inheritance, delegation,
macro, implicit Int/Float coercion, new special form, global checkpoint,
later exploration, or Boids belongs here.

## Verification and completion

From the project root, after implementation run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/completion-session.rkt tests/aloemacs/completion-key-mapping.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp` and `-y`; rebuild changed
Racket bytecode and dependents. Do not commit `compiled/`. Launchers
load existing bytecode: after a `.rkt` edit, run the tests above or
`raco make host/racket/aloemacs-run.rkt bin/aloe` before an optional
`racket host/racket/aloemacs-run.rkt [path]` launch. `.aloe` edits alone
need no rebuild. Add no per-launch build step. No wider suite, physical
TTY hand check, benchmark, timing gate, or unreadable-directory recovery
test is required; unreadable-directory host failures still propagate.

Review source as well as tests: prefill gate precedes queries; one shared
session algorithm guards enumeration; common prefixes use raw names;
the five typed scanner helpers live on the fieldless nongeneric
scanner, with no recursive completion send on a legacy generic
`(fields ...)` receiver; typed directory spelling and Entry
classifications survive; no extra
host/String/Text sends appear; command/runner/keymap/session shapes stay
exact; frame/fit geometry and idle payload remain unchanged; paint writes
no state and prepared lines remain unused by frame/fit.

Complete when both focused proofs and the full aloemacs suite are green,
`git diff --check` is clean, all §3 requirements and the acceptance bar
for 000 are covered, structural review passes, and scope is respected.
Report changed files, the observed initial focused failure, final
verification, and structural review. Stop when green for human review.
Do not write or implement 001; human review of this implementation
precedes a later manager assignment.

If you have been told to read this file, it is the whole assignment.
