# aloemacs-prompt-commands 002 — Select-buffer

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Make `C-x b` start the existing prompt and select an existing buffer by
its exact derived name on Return. Current wins among duplicate names;
otherwise the first forward match wins, including across wrap. Selection
preserves every buffer's editor and path and makes zero filesystem calls.
A miss keeps focus and shows `"failed"`; Escape preserves the previous
echo/submission and runs nothing.

Use the existing waiting slot, bounded lookup, and selection helper.
Stop after named selection and its proof pass. This is the final
checkpoint of the three-checkpoint series; do not issue 003 or start
completion, a buffer menu, windows, or another feature.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-prompt-commands 002**, filed as
  `checkpoints/002-select-buffer.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute only through `call`.
- The accepted [../spec.md](../spec.md) §§1–2 govern authority,
  predecessors, file boundaries, and non-goals. §§3.1–3.5 govern command
  values, the retained slot, start guards, completion order, echo, and
  preservation. §4.2 defines the implemented lookup reused here;
  §§6.1–6.2 specify this slice completely. §7's **002** commands and
  completed-series acceptance conditions govern completion. The
  implemented find-file and save-as behavior in §§4–5 stays in force.
- [000](000-find-file.md) and [001](001-save-as.md) are implemented,
  reviewed with no findings, and accepted by the user, as recorded in
  [the project README](../README.md). At 001 the manager independently
  verified 32 combined focused tests, 343 full aloemacs tests, and
  clean whitespace. There is no other prerequisite.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
  The command inventory ends with `FindFile`, then `SaveAs`; the nested
  map has `"save", "find", "kill"` and no default. `AloemacsBuffers`
  already has `find-name` and bounded `find-name-in`; the session has
  `selected-buffers` and the complete thirteen-field prompt protocol.
  The buffer name is exact path text for `Some(path)` and `"untitled"`
  for `None`.

The predecessor specs named in the accepted spec remain authority for
preserved seams. The earlier focused proofs and `buffer-session.rkt`
under `tests/aloemacs/` show independent full-value expectations, rich
buffer fixtures, counted Fs doubles, and scripted Term runs. Do not
amend predecessor documents or the language to update old inventories.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: only `SelectBuffer` construction/name,
  its session start/completion arms, the final nested binding, and
  `select-buffer-submitted`. Keep the existing two loads and declaration
  order. Reuse existing lookup and selection helpers unchanged.
- Create `tests/aloemacs/prompt-commands-select-buffer.rkt` before
  product edits. It owns the focused checked selection, preservation,
  duplicate/miss, protocol, zero-Fs-call, and scripted runner proof.
- Existing files under `tests/aloemacs/`: only exact constructor/map
  inventories that grow at this stage and newly bound `"b"` prefix-miss
  expectations. Include `keymap-session.rkt`, `buffer-session.rkt`,
  `prompt-commands-find-file.rkt`, and `prompt-commands-save-as.rkt`
  for inventories; `keymap-prefix.rkt` and both earlier focused proofs
  for `"b"` miss examples. Add positive `C-x b` coverage and retain
  every remaining consumed-miss proof. Search the aloemacs tests for
  other exact affected inventories.

### Must leave untouched

- `examples/aloemacs/main.aloe`, `examples/aloemacs/editor.aloe`, and
  all other product modules.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, other host
  files, capabilities, and Fs/Term interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, global checkpoints,
  predecessor documents, and this series' design documents/checkpoints.
- Session/prompt/editor/UndoFrame shapes and startup, fixture arities,
  prompt editing and routing, global map/default, search-key, frame/fit,
  buffer names and lookup, collection order/cycling/removal, existing
  selection/path helpers, shared read policy, direct visit/save,
  find-file, and save-as behavior.

Preserve substantive existing tests; do not delete stale inventory tests
or weaken file-effect, full-frame, editor, buffer, search, history, mark,
ring, prefix, or quit assertions. Add no module, load, dependency,
capability, build step, API beyond the additions below, new session
field, or fixture-arity migration. If another file or design change proves
necessary, stop and return this checkpoint to the manager instead of
widening the slice. If the layer cannot fit one implementer conversation,
report the size problem and stop for review; do not split or add a fourth
checkpoint yourself.

## Slice requirements

### 1. Command, start, and final binding

Append zero-payload `SelectBuffer` immediately after `SaveAs` in
`AloemacsCommand`. Add its exhaustive `name` arm returning exactly
`"select-buffer"`. Extend session `execute-command` with a constructor
arm sending `start-command-prompt` with the actual supplied command
value and exactly `"Buffer: "`, including the trailing space. Ignore
its `key : String` argument, even if it looks like a buffer name.
Return the receiver's concrete `(AloemacsSession H)`.

Append `(AloemacsBinding Command "b" (AloemacsCommand SelectBuffer))`
to `aloemacs-ctrl-x-keymap`. The final ordered keys are exactly
`"save", "find", "kill", "b"`; the save entry still uses
`aloemacs-save-command`, and the nested default stays `None`. Retain
the global map's 20 command bindings, final `"ctrl-x"` prefix, and
`Some SelfInsert` default. Add no binding for `SwitchBuffer` or a
command-name string.

Pending lookup clears the prefix before execution, so `C-x b` passes
the existing start gate. Plain b still inserts; during an active prompt
it is ordinary length-one prompt input. Plain Ctrl-F still searches,
plain Ctrl-W kills the region, and plain Ctrl-S/`C-x C-s` still save.
Other unbound second keys stay consumed without a global retry.

Reuse the four whole-session start refusals: current quit, active
search, pending prefix, and an already active prompt. Refusal preserves
the existing slot, echo, and submission. Successful start stores an
empty prompt at column 0 and the command in the existing slot, without
prefilling a name/path or making any Fs call. Typing, deletion, motion,
ignored keys, LF, fit, and frame retain the slot under existing rules.

Execution stays in session constructor cases. Commands retain only
`name`, with no executable payload or generic host parameter. Do not
case on command names, send computed selectors, or put the new arm on
the editor.

### 2. Exact submitted-name action

Add the ordinary session selector:

```text
select-buffer-submitted(submitted : String) -> (AloemacsSession H)
```

Send existing collection `find-name` with the typed string itself:

| Lookup result | Transition |
|---|---|
| `Some(buffers)` | Send existing `selected-buffers` with that focused collection. |
| `None` | Change only echo to `"failed"`; retain the exact collection and focus. |

No attempt resolves a name or performs an Fs call. Do not convert the
input to a Path, trim it, take a basename, fold case, canonicalize,
complete, or introduce stored/unique names. Compare exact whole strings
against the existing derived `buffer name`. A directly stored relative
path name matches only that unchanged text. Empty input is a miss,
including when a raw buffer's stored path text is empty.

Reuse 000's current-first, bounded forward-cycle lookup unchanged.
Current wins when its name matches; otherwise the first `focus-next`
match wins, including across wrap. A pathless buffer and one whose
literal stored path text is `"untitled"` have the same name, with no
preference for either kind. Distinct positions may have equal buffer
values; retain the countdown rather than using equality with the
starting buffer/name as a stopping rule. Add no second lookup policy,
stored count, or List index.

Success, including a current-name hit, applies existing `selected-buffers`
resets: echo `""`, searching/wrapped/failing `#f`, query `""`, origin
`(Position new 0 0)`, and pending `None`. Preserve Fs, ring, prompt,
submission, and slot, and every buffer/editor/path value. The collection
may focus a different position but retains logical order. Accept the
departing search-result point; do not restore its old search origin,
fit/rebuild an editor, or push history. The same resets apply when
inactive search fields have nondefault raw values.

A miss creates nothing, returns no rotated collection to install, and
does not invoke selection resets. The direct submitted-action send
preserves search, pending, prompt, submission, and slot on a miss while
changing echo. Normal completion separately ends the prompt and clears
the slot as below. No save, read, write, creation, reload, buffer removal,
or path rebinding participates in either outcome.

### 3. Completion, cancellation, and retained direct behavior

Add only the supported `SelectBuffer` arm to the existing
`run-submitted-command` constructor case, sending
`select-buffer-submitted` with the exact string read from
`last-submission`. Retain FindFile, SaveAs, and the final non-prompt
`else`. Do not resend `execute-command`, which would start another
prompt, or use a key/label as the submitted name.

Keep the existing order: active Return stores `Some(prompt.text)` and
deactivates prompt, completes the waiting command, then clears the slot
on the returned success/miss session. The exact unclipped, unsanitized
string remains readable and excludes the label. Repeated inactive
submit returns the whole session unchanged and cannot select again.
An ordinary inactive Return key keeps its normal editing meaning.

Escape/direct cancel clears prompt/slot while preserving all buffers,
focus, echo, search, pending, ring, and the previous submission. It
makes zero Fs calls, never sets `"failed"`, and never quits. Inactive
submit does not consume an orphan; inactive cancel does. Direct
start/Return with an absent slot remains storage-only. Non-prompt slots
and missing-submission fixtures keep their existing consume-without-
execution behavior. Store no target buffer, callback, command-name
string, or second waiting flag.

The session remains the same ordered thirteen-field value. Existing
untyped absent-slot fixtures keep their lawful inferable `if` form;
no constructor migration or concrete-Option setter is needed. Ordinary
rebuilds keep the slot. Successful visit still replaces only current,
clears prompt/slot, preserves submission, and resets the ring; refusal
leaves its entire source intact. Find-file and save-as retain their
accepted behavior and effects.

Direct `switch-buffer` remains a zero-argument forward cycle with the
`SwitchBuffer` command and no production key. It preserves prompt/slot
on direct use and is not overloaded with a typed-name argument. Idle
unknown command-name strings, including `"select-buffer"`, remain map
misses rather than synthetic named commands.

Retain quit, search, prompt, then pending/global idle precedence,
including mixed raw fixtures. Commands neither fit nor redraw. Active
frame still shows clipped/safe label plus text with the clamped prompt
cursor; completed/canceled frame shows the current label/status and
text cursor. At one row no echo suffix is added, but selection works.
Keep the runner's zero-or-one path argument, `aloemacs-editor` binding,
fit-then-frame order, one String/write per iteration, and current editor
quit flag. A later fit may update only the selected editor's origins
and remembered rows under existing rules.

### 4. Focused proof, written first

Create `tests/aloemacs/prompt-commands-select-buffer.rkt` before product
edits. Run the focused proof and observe missing behavior fail, then
implement this slice. Use the unchanged checked Aloe driver, `rackunit`,
counted Fs doubles, scripted Term doubles, independent constructors/
expectations, and snapshots of old values. No physical TTY or repository
file is scratch space. Prove accepted spec §6.2:

1. Zero-payload SelectBuffer construction/exact name; submitted-action
   signature, argument/arity/receiver negatives, and concrete session
   results with the two-host checking approach used in earlier proofs.
   Retain the thirteen-field session and editor/UndoFrame shapes.
   Assert final nested order `"save", "find", "kill", "b"`, no default,
   unchanged global table/default, and no SwitchBuffer binding.
2. `C-x b` starts exactly `"Buffer: "`, empty at column 0, after clearing
   pending. Direct execution ignores its key string. Each start refusal
   retains the whole session, including earlier slot/submission. Plain
   b still inserts; active prompt b edits the prompt. Prompt editing,
   ignored keys, LF, redraw, search precedence, and quit absorption retain
   the shared contracts, with zero Fs calls for selection prompt work.
3. Select another buffer by exact full path and by `"untitled"`, with
   independently expected focus, lists/order, paths, complete editors,
   retained ring, readable submission, and absent prompt/slot. A current
   hit stays current but applies every selection reset, including
   nondefault inactive search fields. Use rich Text focus, point,
   history, mark, both origins, and remembered rows; snapshot all source
   values for immutability. Do not fit/edit between round-trip selections
   when proving exact editor retention.
4. With at least three buffers, prove current-first and first-forward
   duplicate matching before and across wrap. Distinct editor payloads
   identify the winning position. Include multiple untitled buffers,
   pathless/literal-`"untitled"` collisions in both orders, and distinct
   positions holding equal-valued buffers. Retain exact neighbor values
   and logical order and prove lookup terminates without Fs calls.
5. Empty input, including a raw empty stored path name; basename-only
   input; a relative spelling of an absolute name; case/space differences;
   and unknown names fail without creation, focus change, or selection
   resets. A directly stored relative name succeeds only on that exact
   text. Assert `"failed"` and retained buffers/search/prefix on direct
   misses, then exact prompt/submission/slot changes on completed misses.
   Successes, misses, edits, and cancels all make zero Fs calls. Cancel
   before/after a submission retains the old token and submission,
   including saved and failed states. Repeated inactive submit cannot
   select again; direct cycling still works and preserves prompt/slot.
6. Scripted runner input opens a second buffer through find-file, selects
   the original by name, edits/saves there, and quits. Check destination
   text/path, retained neighbor text, full active/inactive cursor frames,
   existing size/key/frame/write counts, fit-before-frame, and one-row
   selection. Count Fs calls by operation: find-file and save retain
   their specified effects; the selection segment makes none. Unknown
   idle command-name strings stay misses, and all remaining prefix
   misses are consumed. Keep earlier focused results and full frames.

Extend exact constructor/map inventories in earlier proofs instead of
deleting structural assertions: FindFile and SaveAs remain installed
before SelectBuffer. Remove only the newly bound `"b"` from prefix-miss
examples and add positive `C-x b` coverage. Keep plain/active-prompt b
insertion tests and every other remaining miss.

Count every observable Fs call, including resolve/current/inspection,
not merely reads/writes. Named selection, empty input, and cancellation
promise zero calls even with a bound buffer or a miss. Existing Fs
production tests already prove encoding/eligibility; use doubles here.
Do not derive an expected result by sending the new transition under
test. Compare complete values and frames, not only names or visible text.

## Explicit non-goals

No completion/list, prompt history, prefilled name/path, directory browser,
wildcards, stored/unique/basename names, trimming, case folding, Path
resolution for selection, lookup rewrite, new session field, fixture-arity
migration, cycling-switch binding/overload, buffer creation on a miss,
untitled reuse/discard, direct visit insertion, or fourth checkpoint.

No windows/splits, mode line, buffer menu, `M-x`, new Term chord,
runner argument, search-key change, dirty bit, save-on-quit, overwrite
confirmation, backups, `mkdir`, Text method, List index, kernel message,
global checkpoint, dependency, Mirror, mutation, inheritance, delegation,
macro, implicit Int/Float coercion, new special form, or Boids work
belongs here.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/prompt-commands-find-file.rkt tests/aloemacs/prompt-commands-save-as.rkt tests/aloemacs/prompt-commands-select-buffer.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or hand check is
required. The optional existing launch remains
`racket host/racket/aloemacs-run.rkt [path]`. After a `.rkt` edit, first
run the named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`;
launchers load existing bytecode without rebuilding. `.aloe` edits alone
need no rebuild.

Review source as well as results: session constructor cases own execution
and completion; one existing slot controls all three prompts; selection
sends existing `find-name` with the typed string and uses existing
`selected-buffers`; names remain exact/derived and no Fs call enters the
selection path. Lookup, shared read policy, save-as write/binding order,
global map, editor, Term, runner, host, library, and language retain their
boundaries. Behavioral equality alone does not prove structural rules.

Complete when all three focused proofs and the full aloemacs suite pass,
`git diff --check` is clean, the focused proof covers this checkpoint
and spec §6.2, source review passes, the scope is respected, and the
completed series meets accepted spec §7's acceptance conditions. Report
changed files, the observed initial focused failure, final verification,
and the structural review. Stop when green for human review. 002 ends
this series; do not issue 003 or start another feature.
