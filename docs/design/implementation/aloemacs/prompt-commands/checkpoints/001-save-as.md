# aloemacs-prompt-commands 001 — Save-as

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Make `C-x C-w` prompt for a destination, write the current buffer's exact
text on Return, and bind only that buffer to the resolved path after a
successful write. Preserve the exact editor value, neighbors, focus,
search state, and ring. Refused writes retain the old binding; Escape
performs no filesystem call and retains the previous echo/submission.

Use 000's waiting-command protocol and thirteen-field session. Stop
after save-as and its proof pass. No `SelectBuffer`, `"b"` prefix
binding, named selection action, new session field, or fixture-arity
migration belongs to 001. Do not write or implement 002.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-prompt-commands 001**, filed as
  `checkpoints/001-save-as.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute only through `call`.
- The accepted [../spec.md](../spec.md) §§1–2 govern authority,
  predecessors, boundaries, and non-goals. §§3.1–3.5 govern command
  values, the retained slot, start guards, completion order, echo, and
  preservation. §§5.1–5.3 specify this slice completely. §7's **001**
  commands and acceptance conditions applicable to this slice govern
  completion. §4's implemented find-file behavior stays in force;
  §6 describes later 002 and is not an implementation assignment.
- [aloemacs-prompt-commands 000](000-find-file.md) is implemented,
  reviewed with no findings, and accepted by the user, as recorded in
  [the project README](../README.md). The manager independently verified
  15 focused tests, 326 full aloemacs tests, and clean whitespace.
  There is no other prerequisite.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe)
  and the retained [find-file proof](../../../../../../tests/aloemacs/prompt-commands-find-file.rkt).
  The command inventory ends with `FindFile`; the nested map has
  `"save", "find"` and no default. The session already stores and
  deactivates a submission before completion and clears the slot on
  the returned session. `AloemacsBuffer` currently has `name` and
  `with-editor`; the collection has `with-current-buffer`.

The existing thin Fs write policy provides overwrite, eligible missing
file creation, Option refusal, and raised host failures. The predecessor
specs named in the accepted spec remain authority for those seams.
Do not amend them or the language to update old inventories.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: only `SaveAs` construction/naming,
  its session start/completion arms and nested binding, buffer
  `with-path`, session `with-current-path`, and `save-as-submitted`.
  Keep the existing two loads and declaration order.
- Create `tests/aloemacs/prompt-commands-save-as.rkt` before product
  edits. It owns the focused checked save-as, preservation, filesystem,
  cancellation, and scripted runner proof.
- Existing files under `tests/aloemacs/`: only exact inventories that
  grow at this stage and the newly bound `"kill"` prefix-miss
  expectations. Include `keymap-session.rkt`, `buffer-session.rkt`,
  and `prompt-commands-find-file.rkt` for constructor/map inventories;
  `buffer-value.rkt` for the new buffer `with-path` method-signature
  inventory; and `keymap-prefix.rkt` and the find-file proof for
  `"kill"` miss examples. Add positive save-as chord coverage and
  retain the consumed-miss proof for every remaining unbound key.
  Search the aloemacs tests for other exact affected inventories.

### Must leave untouched

- `examples/aloemacs/main.aloe`, `examples/aloemacs/editor.aloe`, and
  all other product modules.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, other host
  files, capabilities, and Fs/Term interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, global checkpoints,
  predecessor documents, and this series' design documents/checkpoints.
- Session/prompt/editor/UndoFrame shapes and startup, existing fixture
  arities, prompt editing and routing, global map/default, search-key,
  frame/fit behavior, buffer lookup/order/selection rules, shared read
  policy, direct visit/save, and find-file behavior.

Preserve substantive existing tests; do not delete a stale inventory
test or weaken file-effect, full-frame, editor, buffer, search, history,
mark, ring, prefix, or quit assertions. No broad fixture migration is
needed. Add no module, load, dependency, capability, build step, or API
beyond the additions below. If another file or design change proves
necessary, stop and return this checkpoint to the manager instead of
widening the slice. If the layer cannot fit one implementer conversation,
report the size problem and stop for review; do not split or add a fourth
checkpoint yourself.

## Slice requirements

### 1. Save-as command, start, and binding

Append zero-payload `SaveAs` immediately after `FindFile` in
`AloemacsCommand`. Add its exhaustive `name` arm returning exactly
`"save-as"`. Extend session `execute-command` with a constructor arm
sending `start-command-prompt` with the actual supplied command value
and exactly `"Save as: "`, including the trailing space. Ignore its
`key : String` argument, even if it looks like a path. Return the
receiver's concrete `(AloemacsSession H)`.

Append `(AloemacsBinding Command "kill" (AloemacsCommand SaveAs))`
to `aloemacs-ctrl-x-keymap`. The ordered keys become exactly
`"save", "find", "kill"`; the save value stays
`aloemacs-save-command`, and the nested default stays `None`.
Retain the global map's 20 command bindings, final `"ctrl-x"` prefix,
and `Some SelfInsert` default.

Pending lookup still clears the prefix before execution, allowing
`C-x C-w` to pass the prompt-start gate. The existing host already
normalizes Ctrl-W as `"kill"`; no Term change is needed. Plain Ctrl-W
still kills the region, plain Ctrl-F searches, and plain b inserts.
Ctrl-S and `C-x C-s` retain their save behavior. Unbound second keys
are consumed without a global retry; `"b"` remains a prefix miss.

The existing start guards refuse current quit, active search, pending
prefix, and an active prompt with whole-session equality, including
the old slot, echo, and submission. Successful start is empty at
column 0, with no prefilled path/name and zero Fs calls. Prompt typing,
motion, deletion, ignored keys, LF, fit, and frame retain the waiting
value. Named `"kill"` remains ignored during an active prompt.

Execution belongs to session constructor cases. Commands retain only
`name`, with no executable payload or generic host parameter. Do not
dispatch by command names, send computed selectors, or put the arm
on the editor.

### 2. Pure path-update helpers

Add these ordinary methods with exactly these argument/result types:

| Receiver | Selector | Result |
|---|---|---|
| `AloemacsBuffer` | `with-path(path : Path)` | `AloemacsBuffer` |
| `(AloemacsSession H)` | `with-current-path(path : Path)` | `(AloemacsSession H)` |

Buffer `with-path` returns a buffer containing the receiver's exact
editor value and `Some(path)`. It does not resolve or write, construct
a fresh editor, copy only selected editor fields, or add an undo frame.
Its derived name follows the existing `name` method. There is no
Option argument, unbinding overload, or stored name. A directly supplied
relative Path is stored exactly; resolution belongs to the submitted
command boundary.

Session `with-current-path` uses buffer `with-path` and collection
`with-current-buffer`, then rebuilds the session with every unrelated
field preserved. Keep the exact current editor, neighbor lists and
payloads, focus/order, Fs, echo, all search fields, pending, prompt,
last submission, waiting command, and ring. The new reconstruction
threads the receiver's slot. Do not end search or invoke selection
resets. Both helpers make zero Fs calls, including with raw active
prompt/search/prefix fixtures.

### 3. Submitted write and binding update

Add session
`save-as-submitted(submitted : String) -> (AloemacsSession H)`:

| Input / thin write result | Transition |
|---|---|
| `""` | Change only echo to `"failed"`; make zero Fs calls. |
| Nonempty input, `Fs.write Some` | Bind only current to the resolved path through `with-current-path`; set echo `"saved"`. |
| Nonempty input, `Fs.write None` | Retain the original collection, focus, path, and editor; change only echo to `"failed"`. No host write. |

For nonempty input, resolve at the command boundary through
`(fs path submitted)`, then send exactly one thin
`(fs write resolved ((self text) to-string))`. Do not trim the input;
spaces are nonempty input. Thin Fs preflight may inspect the target
and parent and perform its existing resolution sends. Keep that
policy in the unchanged Fs wrapper rather than adding application
classification or extra writes.

Update the binding only after the thin write returns `Some`. Do not
tentatively bind, reuse direct save after rebinding, visit, reload,
add/switch a buffer, or call `selected-buffers`. Success preserves Text
including its focus, point, quit, history, mark, both origins, and
remembered rows exactly; it pushes no undo frame and changes no
search/prefix field or ring. Other buffers retain every value and path.

An existing regular file is overwritten; an eligible missing final
file is created. Missing/non-directory parent, directory, symlink,
other-node target, and other existing Fs refusals return `None`
without a host write. Same-path submission performs an ordinary write
even with no edits. Writing another buffer's path is allowed: current
takes that path and writes its own text, while its neighbor keeps its
own editor/text/path. Duplicate paths stay legal, with no deduplication
or reload. A subsequent plain save uses current's newly bound path.

Host write failures continue to raise through the host boundary. Do
not catch them as a returned `"failed"` session or promise rollback,
atomic replacement, or recovery from a partial host write. Add no
overwrite confirmation, backup, directory creation, or newline
conversion. Empty input and cancellation perform no resolve,
inspection, read, or write.

### 4. Completion and retained protocol

Add only the supported `SaveAs` completion arm to the existing
`run-submitted-command` constructor case. Send `save-as-submitted`
with the exact string read from `last-submission`, never a key or
label. Retain the `FindFile` arm and final non-prompt `else`.
Do not resend `execute-command`, which would start another prompt.

Keep 000's ordering: active Return first stores `Some(prompt.text)`
and makes prompt inactive, then completes the waiting command, then
clears the slot on the returned success/refusal session. The submitted
string remains readable, excludes the label, and is not clipped or
sanitized. Repeated inactive submit returns unchanged and cannot
write again. Direct start/Return with an absent slot remain
storage-only. Non-prompt slots and missing-submission fixtures retain
their existing consume-without-execution behavior.

Escape/direct cancel clears prompt and slot while preserving the
collection, focus, path, exact editor, echo, search fields, prefix,
ring, and previous submission. It never quits or sets `"failed"`.
An inactive submit does not consume an orphan; inactive cancel does.
If a caller directly selects another buffer during the prompt,
completion writes the buffer current at Return; store no target buffer
or callback.

The session remains the same ordered thirteen-field value, with only
one optional waiting command. Existing untyped absent-slot fixtures
keep the lawful `(if #t (Option None)
(Option Some (AloemacsCommand FindFile)))` form; no arity migration or
concrete-Option setter is needed. Ordinary reconstructions preserve
the slot; successful visit clears prompt/slot and retains its current-only
replacement/ring reset, while refusal preserves the source.

Retain quit, search, prompt, then pending/global idle precedence.
Commands neither fit nor redraw. Active frame still clips/safely
displays label plus text and clamps the prompt cursor; after Return
it shows saved/failed status and the text cursor. Cancel restores the
previous token/label. One-row operation adds no echo suffix. Keep the
runner's zero-or-one path argument, `aloemacs-editor` binding,
fit-then-frame order, one String/write per iteration, and current
editor quit flag. Find-file and direct save/visit/selection retain
accepted spec §§3.5–4 meanings.

### 5. Focused proof, written first

Create `tests/aloemacs/prompt-commands-save-as.rkt` before product
edits. Run the focused proof and observe missing behavior fail, then
implement this slice. Use the unchanged checked Aloe driver,
`rackunit`, counted Fs doubles, scripted Term doubles, independent
constructors/expectations, and snapshots of old values. No physical
TTY or repository file is scratch space. Prove spec §5.3:

1. Zero-payload `SaveAs` construction and exact name; both path-update
   signatures and submitted-action signature; argument/arity/receiver
   negatives, including Option arguments to path helpers. Session
   result types retain the concrete injected host type, with the same
   two-host checking approach as 000. Keep the exact thirteen session
   fields and unchanged editor/UndoFrame shapes. Assert nested order
   `"save", "find", "kill"`, absent default, unchanged global table/
   default, and the original region `Kill` constructor/name/action.
2. Direct command execution ignores a path-like key argument.
   `C-x C-w` starts exactly `"Save as: "`, empty at column 0, after
   clearing pending. No Fs call occurs before Return. Each start guard
   retains the entire receiver, including an earlier waiting command
   and submission. Prompt editing/ignored keys/redraw preserve `SaveAs`.
   Plain Ctrl-W retains its region result; remaining misses stay consumed.
3. Untitled and bound rich buffers saved to eligible missing and
   existing relative targets: exactly one host write of current text,
   resolved path/name, `"saved"`, inactive prompt/absent slot, and exact
   readable submission. Compare complete current editor and neighbor
   values/order, ring, and every unrelated session field; snapshot
   the source for immutability. Cover CRLF, BOM, Unicode, final-newline
   presence/absence, and text edited through existing commands.
4. Same-path write succeeds and a new submission writes again without
   edits. A second inactive submit makes no calls; an ordinary inactive
   Return key writes nothing and keeps its existing editing meaning.
   Writing a neighbor's path changes only current's binding and on-disk
   contents, retaining the neighbor's unsaved text and full editor/path. Subsequent plain
   save writes current's text to its new path. Direct selection during
   a prompt proves completion uses the buffer current at Return.
5. Empty input and Escape make zero Fs calls, including resolve and
   preflight. Missing/non-directory parents, directory, symlink, and
   other-node targets refuse with zero host writes, exact unchanged
   buffers/path/focus, stored submission, absent prompt/slot, and
   `"failed"`. Cancellation before/after submissions retains the old
   token and submission, including saved and failed states. Raised
   host-write failure remains a host failure, with no returned
   failed-session or atomicity promise.
6. Test each path helper independently with nontrivial editor/history/
   mark/origins/Text focus and raw prompt/slot/search/prefix fields.
   They preserve the exact editor and every unrelated field with zero
   Fs calls, add no undo frame, and store a supplied relative Path
   unchanged. Retain direct save, successful/refused visit, cycling/
   removal, and find-file behavior. Earlier focused results stay intact.
7. Scripted no-TTY runner input starts save-as, types a path through
   redraw, submits, edits, saves normally to the new path, cancels a
   later save-as, and quits. Assert exact host write targets/contents,
   full prompt/saved/cancel frames and cursor restoration, fit-before-
   frame, existing size/key/frame/write counts, and one-row behavior.

Update exact constructor/map inventories in earlier tests rather than
removing their assertions; `FindFile` remains installed before `SaveAs`.
Extend the buffer method-signature inventory for `with-path`. Remove only
the newly bound `"kill"` from prefix-miss examples and add the positive
save-as chord proof. Retain `"kill"` in active-prompt ignored-key and
plain-region tests. Keep `"b"` and every other remaining miss consumed.

Count every observable Fs send, including resolves during preflight,
separately from host write effects. Empty/cancel means zero calls,
not merely zero writes. Existing production Fs tests already prove
encoding and host eligibility; use doubles here. Do not construct an
expected result by sending the new transition under test. 001 must
pass without SelectBuffer or its `"b"` binding/test.

## Explicit non-goals

No SelectBuffer, named selection action, `C-x b`, fourth checkpoint,
new slot/field, fixture-arity migration, or change to cycling switch.
No completion/list, prompt history, prefilled path, directory browser,
wildcards, `mkdir`, overwrite confirmation, backups, dirty bit,
save-on-quit, newline conversion, reload/deduplication, stored/unique/
basename buffer names, untitled discard/reuse, or direct visit insertion.

No windows/splits, mode line, buffer menu, `M-x`, new Term chord,
runner argument, search-key change, Text method, List index, kernel
message, global checkpoint, dependency, Mirror, mutation, inheritance,
delegation, macro, implicit Int/Float coercion, new special form, or
Boids work belongs here.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/prompt-commands-find-file.rkt tests/aloemacs/prompt-commands-save-as.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y` on every agent test run. Do not commit
`compiled/`. No wider suite, benchmark, timing gate, or hand check is
required. The optional existing launch remains
`racket host/racket/aloemacs-run.rkt [path]`. After a `.rkt` edit, first
run the named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`;
launchers load existing bytecode without rebuilding. `.aloe` edits
alone need no rebuild.

Review source as well as results: execution/completion use session
constructor cases and the existing slot; one thin Fs write precedes
binding; path helpers preserve the exact editor/current position and
thread every unrelated field; no visit, addition, selection reset,
reload, or history frame participates in save-as. Retain the existing
shared read policy, lookup, global map, editor, Term, runner, host,
library, and language boundaries. Equality alone does not prove these
structural requirements.

Complete when both test commands pass, `git diff --check` is clean,
the focused proof covers this checkpoint and spec §5.3, source review
passes, and the scope is respected. Report changed files, the observed
initial focused failure, final verification results, and the structural
review. Stop when green for human review; do not start or issue 002.
