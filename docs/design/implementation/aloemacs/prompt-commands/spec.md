# aloemacs prompt commands specification

**Status: Accepted for checkpoint work.** This file is the complete design input
for the **aloemacs-prompt-commands** checkpoint manager and implementers.
They do not need the charter or the design conversation. After human
acceptance, this file is their design authority.
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law;
[`docs/workflow.md`](../../../../workflow.md) governs the roles and review
boundaries.

Three named command values start the existing single-line prompt.
`C-x C-f` asks for a file to open while retaining the departing buffer;
`C-x C-w` asks where to save the current buffer; `C-x b` asks which
existing buffer name to select. Return stores the editable string, ends
the prompt, and completes the waiting command. Escape discards the line
and runs nothing. Direct `visit` continues to replace only the current
buffer, and a prompt started without a waiting command still only stores
its submission.

## 1. Series, predecessors, and authority

The series identity is **aloemacs-prompt-commands**. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Product code stays in
`examples/aloemacs/`; tests stay in `tests/aloemacs/`. This folder receives
design documents and later checkpoints, never program code.

There are exactly three checkpoints, in this order:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-prompt-commands 000** | `checkpoints/000-find-file.md` | The waiting slot and constructor migration; find-file, its label and `C-x C-f`; shared read policy and buffer reuse; unchanged direct prompt submission and direct visit. |
| **aloemacs-prompt-commands 001** | `checkpoints/001-save-as.md` | Save-as, its label and `C-x C-w`; successful path binding without editor replacement; refused writes and cancellation. Uses 000's slot. |
| **aloemacs-prompt-commands 002** | `checkpoints/002-select-buffer.md` | Exact derived-name selection, its label and `C-x b`; current-first and forward duplicate matching; misses. Uses 000's slot and lookup. |

Numbers are three digits, start at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. After the human accepts this
spec, the checkpoint manager writes **000 only**, then stops. Human review
of its implementation precedes issuing 001, and review of 001 precedes
issuing 002. Each implementer writes tests first, implements only the
approved checkpoint, runs verification, and stops when green. Do not
combine the layers, issue the documents as a batch, or add a fourth
checkpoint. If a layer cannot fit one implementer conversation, report
the size problem and stop for review.

Layers 1–15 in the [parent map](../README.md) are implemented. The required
seams are File's resolve/read/write and Option outcomes, Keymap's command
values and prefix consumption, Buffer's nonempty zipper and derived names,
and Minibuffer's prompt and submission. There is no runner prerequisite.

Authority for the preserved seams is:

- [`../README.md`](../README.md) and
  [`../explorations.md`](../explorations.md): layer order and Band 2 item 8;
  windows and the later bands stay outside this series.
- [`../file/spec.md`](../file/spec.md): filesystem resolution, missing and
  regular-file reads, write eligibility, exact contents, and host failures.
- [`../keymap/spec.md`](../keymap/spec.md): session `execute-command`,
  constructor dispatch, the one `C-x` prefix, and clearing that prefix
  before execution.
- [`../buffer/spec.md`](../buffer/spec.md): editor/path ownership, derived
  names, insertion after current, cycling switch, selection resets, and
  direct visit replacing only current.
- [`../minibuffer/spec.md`](../minibuffer/spec.md): start guards, prompt
  editing and key routing, row/cursor composition, submission lifetime,
  and direct-operation preservation.
- [`file.aloe`](../../../../../examples/aloemacs/file.aloe) and
  [`main.aloe`](../../../../../examples/aloemacs/main.aloe): the implemented
  application and reconstruction sites.
- [`term.rkt`](../../../../../host/racket/term.rkt): Ctrl-F already yields
  `"find"`, Ctrl-W already yields `"kill"`, and plain b yields `"b"`.
- [`SPEC.md`](../../../../../SPEC.md) §9: the lawful typed-None `if` form.

This spec extends command values, the nested prefix map, and the prompt's
Return/Escape results when a command is waiting. Predecessor rules for
direct visit, cycling switch, and a prompt with no waiting command remain
in force. The new field is threaded through their reconstructions;
successful visit additionally clears it. Do not amend predecessor
documents or language law to make their old inventories current.

## 2. Product, host, and file boundary

The product remains checked Aloe with one window, a nonempty buffer zipper,
and a prompt outside that zipper. The filesystem is the existing explicitly
injected thin `(Fs H)` capability. Tests use the unchanged checked driver,
`rackunit`, counted filesystem doubles, and scripted Term doubles. There
is no new module, dependency, capability, host interface row, or build step.
Keep the existing two loads and declaration order in `file.aloe`.

Product scope is:

| Checkpoint | Product files it may edit | Tests |
|---|---|---|
| 000 | `examples/aloemacs/file.aloe`, `examples/aloemacs/main.aloe` | Add `tests/aloemacs/prompt-commands-find-file.rkt`; migrate affected existing aloemacs fixtures and inventories as §3.5 requires. |
| 001 | `examples/aloemacs/file.aloe` | Add `tests/aloemacs/prompt-commands-save-as.rkt`; extend exact command/map inventories in existing tests. No new session field or fixture-arity migration. |
| 002 | `examples/aloemacs/file.aloe` | Add `tests/aloemacs/prompt-commands-select-buffer.rkt`; extend exact command/map inventories in existing tests. No new session field or fixture-arity migration. |

Leave `examples/aloemacs/editor.aloe`, `host/racket/aloemacs-run.rkt`,
`host/racket/term.rkt`, host capabilities, libraries, language implementation,
`SPEC.md`, `CHECKPOINTS.md`, and predecessor documents untouched. The
eight-field editor and four-field `UndoFrame` retain their shapes.

The runner retains zero or one path argument, the `aloemacs-editor` binding,
fit-then-frame order, one String and one `term write` per iteration, and
the current editor's quit flag. Commands neither fit nor redraw themselves.
The runner's next fit may update the selected editor's origins and remembered
rows under the existing rules; it never changes another buffer.

Explicit non-goals are completion, a completion list, prompt history,
prefilled text, a directory listing/browser, wildcards, `mkdir`, overwrite
confirmation, backups, windows, splits, a mode line, buffer menu, `M-x`, a
new Term chord, runner argument, search-key change, stored/unique/basename
buffer names, reusing or discarding an untitled buffer on find-file, making
direct visit insert a buffer, or binding cycling switch. No dirty bit,
save-on-quit, Text method, List index, kernel message, global checkpoint,
Mirror, mutation, inheritance, delegation, macro, or new special form
belongs here. Evaluation remains send; function objects run only through
`call`.

## 3. Shared protocol — introduced entirely in 000

### 3.1 Command values and bindings

Append each zero-payload constructor to `AloemacsCommand` in its assigned
checkpoint, after the previously installed constructors. Extend both the
command's exhaustive `name` case and the session's `execute-command` case.

| Checkpoint | Constructor | Exact `name` | Start label | Prefix-map key |
|---|---|---|---|---|
| 000 | `FindFile` | `"find-file"` | `"Find file: "` | `"find"` |
| 001 | `SaveAs` | `"save-as"` | `"Save as: "` | `"kill"` |
| 002 | `SelectBuffer` | `"select-buffer"` | `"Buffer: "` | `"b"` |

Each new execution sends session `start-command-prompt` with the actual
command value and its fixed label. It returns the receiver's concrete
`(AloemacsSession H)`. `key : String` remains in `execute-command`'s
signature but is ignored by these arms: it is neither a path nor a name.
Only `SelfInsert` uses it. Commands still have only their naming method,
with no execution method or generic host parameter. Do not dispatch by
`name`, put these arms on `AloemacsEditor.handle-key`, or use computed
selectors.

Keep `"save"` first in `aloemacs-ctrl-x-keymap` and append each new binding:
000 has keys `"save", "find"`; 001 has `"save", "find", "kill"`; 002 has
`"save", "find", "kill", "b"`. New entries are ordinary
`AloemacsBinding Command` values containing the corresponding constructor.
The existing save entry still uses `aloemacs-save-command`. The nested
map's default stays `None`. The global map keeps its 20 command bindings,
then its `"ctrl-x"` prefix, and its `Some SelfInsert` default unchanged.

Pending lookup still clears the prefix **before** `execute-command`, so
these chords can start a prompt without changing `start-prompt`'s guard.
An unbound second key is consumed with no global retry. Plain Ctrl-F still
searches, plain Ctrl-W still kills the region, and plain b still inserts.
`SwitchBuffer` remains `"switch-buffer"`, means cycle forward, and gains
no key. `Kill` remains `"kill"` and means kill the region.

Each label includes its trailing space. The prompt joins label and text
without another separator and starts with text `""`, column 0. Neither
the current path nor its name is prefilled.

### 3.2 Only one new session field

Append **`waiting-command : (Option AloemacsCommand)`** after
`last-submission`. The complete ordered fields, from 000 onward, are:

```aloe
(buffers AloemacsBuffers)
(fs (Fs H))
(echo String)
(searching Bool)
(query String)
(origin Position)
(wrapped Bool)
(failing Bool)
(kill-ring (List String))
(pending (Option (AloemacsKeymap AloemacsBinding)))
(prompt (Option AloemacsPrompt))
(last-submission (Option String))
(waiting-command (Option AloemacsCommand))
```

The generated `waiting-command` read returns `(Option AloemacsCommand)`.
`None` means no prompt command is waiting. Normal execution stores only
an installed prompt-command constructor in `Some`. The session stores
no command name string, second waiting flag, callback, saved target
buffer, or additional field in 001 or 002. If a caller uses a direct
selection send during a prompt, completion acts on the buffer current
at Return; the prompt command does not remember the earlier focus.

Startup remains empty and untitled, with no active prompt, submission, or
waiting command. With `file.aloe` loaded and `fs-host` injected, the lawful
untyped constructor is shown once:

```aloe
(define aloemacs-editor
  (AloemacsSession new
    (AloemacsBuffers new
      (List empty)
      (AloemacsBuffer new
        (AloemacsEditor new
          (Text from-string "")
          (Position new 0 0) #f 0 0 (List empty)
          (if #t (Option None) (Option Some (Position new 0 0)))
          0)
        (if #t (Option None) (Option Some (Path new "/typed-none"))))
      (List empty))
    (Fs new fs-host)
    "" #f "" (Position new 0 0) #f #f (List empty)
    (if #t (Option None) (Option Some aloemacs-global-keymap))
    (if #t (Option None) (Option Some (AloemacsPrompt new "" "" 0)))
    (if #t (Option None) (Option Some ""))
    (if #t (Option None) (Option Some (AloemacsCommand FindFile)))))
```

The unselected branches provide the concrete empty Option types under
`SPEC.md` §9. Use the final `if` form at every untyped absent-slot fixture,
including test expectations. A bare `(Option None)` there is not lawful.
Inside a method, an expected constructor field type may supply the type
directly. No helper takes a concrete Option to set or clear the field;
the existing absent-Option runtime dispatch limitation is unchanged.
Loading main still needs only the injected Fs, no Term, and makes no
filesystem call.

### 3.3 Session helpers and completion order

Introduce these ordinary session selectors in 000. All return the
receiver's concrete `(AloemacsSession H)`:

| Selector | Contract |
|---|---|
| `with-waiting-command(command : AloemacsCommand)` | Store `Some(command)`; preserve every other field. |
| `clear-waiting-command()` | Store `None`; preserve every other field. |
| `start-command-prompt(command : AloemacsCommand, label : String)` | Apply the same eligibility gate as `start-prompt`. On refusal return the whole receiver unchanged, slot included. Otherwise send `start-prompt label`, then store the supplied command through `with-waiting-command`. |
| `run-submitted-command()` | The completion helper called by the active branch of `submit-prompt` after storing the submission and ending the prompt. Case on the waiting command and read the string from `last-submission`; perform the matching submitted-action selector, then clear the slot on its returned session. With no waiting command, return unchanged. |

The start gate refuses current quit, active search, pending prefix, or an
already active prompt. It performs no filesystem call and does not clear
the old submission or echo. A refused new command cannot replace an
already waiting command. Do not infer successful start merely from the
presence of a prompt after calling `start-prompt`: a preexisting prompt
is a refusal. A successful start may replace an orphaned waiting slot
when no prompt is active and all guards permit start.

Direct `start-prompt` is unchanged: it neither fills nor clears the slot.
With an absent slot, its Return remains storage-only. Typing, deletion,
motion, LF, and every ignored prompt key preserve the slot exactly.

`submit-prompt` uses this sequence:

1. If the receiver's prompt is inactive, return the whole receiver
   unchanged, even with a stored submission or an orphaned waiting slot.
2. If active, rebuild with prompt `None` and last submission
   `Some(prompt.text)`. Preserve all other fields, including the slot.
3. Send `run-submitted-command` on that rebuilt session. `FindFile` sends
   `find-file-submitted`; 001 adds `SaveAs` sending `save-as-submitted`;
   002 adds `SelectBuffer` sending `select-buffer-submitted`. Each takes
   the string read from `last-submission`, never a key or the label.
4. Clear the slot after any returned success or failure. The prompt stays
   inactive and the submitted string remains readable. A second inactive
   submit does nothing and cannot repeat the filesystem effect.

Completion cases on constructor values, not strings, and does not resend
`execute-command`, which would start another prompt. The helper is an
internal convention, not a command registry. Its expected input is the
inactive, freshly submitted session from step 2. For a raw fixture with
a non-prompt command in the slot, or no stored submission, consume the
slot without running an ordinary command or changing the echo. Use a
final `else` for non-prompt constructors; later checkpoints add only
their supported completion arms.

`cancel-prompt` deactivates the prompt and clears the slot, preserving the
complete buffers, echo, search state, prefix, ring, and previous submission.
It clears an orphaned slot even when called directly on an inactive prompt;
with neither prompt nor slot it retains today's unchanged result. In the
active-prompt key table, Escape sends this cancel and never quits. It
performs zero Fs calls and does not set `"failed"`.

`handle-key` retains quit, search, active prompt, then pending/global idle
routing in that order. Search remains ahead of prompt input in mixed raw
fixtures. Named save/find/prefix/kill keys remain ignored by an active
prompt, and no prompt input is forwarded to a keymap. The table changes
only Return's completion and Escape's slot clearing.

### 3.4 Echo and selection results

The stored vocabulary remains exactly `""`, `"saved"`, and `"failed"`:

| Event | Echo token |
|---|---|
| Start, active prompt editing, ignored keys, redraw | Unchanged; the prompt row hides it. |
| Escape / direct cancel | Unchanged. |
| Find-file success or select-buffer success, including staying on current | `""`. |
| Save-as success | `"saved"`. |
| Empty command input, refused file/write, or missed name | `"failed"`. |
| Direct prompt Return with no waiting command | Unchanged. |

Introduce `selected-buffers(buffers : AloemacsBuffers)` in 000 for the
find-file reuse path and 002's named selection. It installs the supplied
collection, sets echo `""`, searching/wrapped/failing `#f`, query `""`,
origin `(Position new 0 0)`, and pending `None`. Preserve Fs, kill-ring,
prompt, submission, and waiting slot. These are the existing cycling
switch resets, including on a current-name match. No editor is rebuilt
or fitted, no departing search origin is restored, and no history frame
is pushed. The departing buffer retains its current search-result point.

Find-file addition uses existing `add-buffer contents resolved-path`,
with these same selection resets and preservation. Failure changes only
the echo on the already submitted session; its collection and focus stay
exactly as they were. Save-as changes no selection/search/prefix field.
All normal completions end with prompt and waiting slot absent.

Frame stays unchanged: while active it shows the label/text with the
existing clipping, safe cells, and clamped prompt cursor; after completion
or cancel it shows the current label/status and returns the cursor to text.
At one row there is no echo suffix, but command transitions still work.

### 3.5 Every reconstruction threads the slot

000 appends the field at all session construction sites. The current
product inventory is:

| Site in `file.aloe`, unless stated otherwise | Slot argument |
|---|---|
| `with-active-prompt` | Receiver's slot. |
| Active `submit-prompt` reconstruction, before completion | Receiver's slot. |
| `cancel-prompt` | `None`, including inactive cancellation of an orphan. |
| Both `add-buffer` arities | Source session's slot. |
| `switch-buffer`, `kill-buffer` | Source session's slot. |
| `with-editor`, `with-kill-state`, `with-search`, `with-echo` | Receiver's slot. |
| `with-prefix`, `clear-prefix` | Receiver's slot. |
| `visited` | `None`; successful visit also deactivates the prompt and preserves the last submission. |
| `main.aloe`: initial `aloemacs-editor` | Typed `None` from §3.2. |
| New `with-waiting-command`, `clear-waiting-command` | `Some(command)`, `None`, respectively. |
| New `selected-buffers`; 001's `with-current-path` | Receiver's slot. |

Direct editor wrappers, search and kill helpers, `save-key`, prefix
dispatch, and `ensure-visible` inherit this threading through their
existing helpers. Direct `save` returns an equal session on success;
`unchanged` and `frame` construct no session. None of direct save,
switch-buffer, kill-buffer, add-buffer, fit, or frame runs the waiting
command. They preserve it even with an active prompt. A refused visit
returns `None` and leaves its whole receiver unchanged, slot included.
Successful visit replaces only current and performs its existing resets,
including clearing the session ring; find-file never uses those resets.

Migrate valid untyped constructors and independent expected reconstructions
in `tests/aloemacs/buffer-value.rkt`, `buffer-session.rkt`,
`echo-session.rkt`, `file-session.rkt`, `kill-session.rkt`,
`motion-editor.rkt`, `runner.rkt`, `safe-cells.rkt`, `search-session.rkt`,
`undo-session.rkt`, `viewport-editor.rkt`, `visited-unchanged.rkt`,
`keymap-session.rkt`, `keymap-prefix.rkt`, `minibuffer-value.rkt`, and
`minibuffer-session.rkt`. Update exact session inventories, main/source
expectations in `runner.rkt` and `file-runner.rkt`, and command/map
inventories in keymap and buffer tests. Search all product and aloemacs
tests again; this inventory is a starting point, not an exemption.

Keep intentional old-arity negatives as negatives. Other negative fixtures
must retain the original type/field mistake with the new arity. Editor-only
fixtures stay on `AloemacsEditor`. Preserve substantive buffer, prompt,
search, history, mark, ring, viewport, file-effect, and full-frame assertions.
Remove only the newly bound keys from old prefix-*miss* examples in their
assigned checkpoint; retain the consumed-miss proof for every remaining
unbound key and add the new positive chord proof. Do not merely delete
the tests whose exact inventories become stale.

## 4. Layer 000 — find-file

### 4.1 One shared read policy

Introduce the session helper
`file-contents(path : Path) -> (Option String)`. Its argument is already
resolved by its caller. It makes no session or buffer change and encodes
the existing visit eligibility policy once:

| First `(fs inspect path)` | Result |
|---|---|
| `None` (missing) | `Some("")`; no read and no creation. |
| `Some RegularFile` | Return the existing `(fs read path)` result, including a live second-inspection `None`. |
| `Some Directory`, `Some SymbolicLink`, `Some Other` | `None`; no read. |

Refactor direct `visit` to resolve with `(fs path (path text))`, send this
helper, and on `Some(contents)` return `Some(self visited contents resolved)`.
On `None`, return `None`. Its replacement/reset behavior stays exactly
the current `visited` behavior, extended only to clear the waiting slot.
Do not implement find-file by sending `visit`, using a temporary session
that visits and then copies its result, or repeating the classification
policy in a second method. A thin `Fs.read None` alone cannot distinguish
missing from a refused non-file; keep the first inspect in this helper.

Filesystem state remains live. A path that becomes missing or ineligible
at the second inspection refuses the read; a race after preflight, invalid
UTF-8, permission error, or other host failure still raises through the
unchanged host boundary. Do not translate host failures to a returned
`"failed"` session. This series promises no transactional I/O recovery.

### 4.2 Exact name lookup over the existing zipper

Add these pure collection selectors to `AloemacsBuffers` in 000:

| Selector | Result | Contract |
|---|---|---|
| `find-name(name : String)` | `(Option AloemacsBuffers)` | Empty string returns `None`. Otherwise search current first, then one forward cycle, returning the first matching focused collection or `None`. |
| `find-name-in(name : String, remaining : Int)` | `(Option AloemacsBuffers)` | Internal bounded scan used by `find-name`; budget at most the collection's size. |

Compute the initial budget once as `1 + before.len + after.len`, using
existing List/Int sends. At each step, compare the exact current
`(buffer name)` string. On equality return `Some` of that collection;
otherwise, when another candidate remains, send `focus-next` and recurse
with one less remaining. A nonpositive budget returns `None`. Inspect each
position at most once. This uses a local countdown, not a stored count or
List index. Do not use buffer equality or name equality with the starting
buffer as the stopping test: distinct positions can have equal values.

Current wins among duplicates. Otherwise the first `focus-next` match wins,
including across the last-to-first wrap. A hit keeps logical buffer order
and every buffer/editor/path value intact. A miss returns no rotated
collection for the session to install. Neither selector resolves a string
or performs an Fs call. 002 reuses this exact lookup rather than introducing
another name policy.

### 4.3 Submitted find-file action

Add session
`find-file-submitted(submitted : String) -> (AloemacsSession H)` as the
completion action. On `""`, set echo `"failed"` without any Fs call or
collection change. Do not trim input; a nonempty string of spaces is input.

For nonempty input, resolve once at the command boundary with
`(fs path submitted)`. Compare and store this resolved `Path`; never
store the typed relative spelling. Send collection `find-name` with the
resolved path's text **before** any inspection or read:

| Result | Transition |
|---|---|
| Current name matches | Keep current; use `selected-buffers` resets and echo `""`. No inspect/read/write. |
| Another name matches | Install the first matching focused collection through `selected-buffers`. No inspect/read/write. |
| No name matches, shared `file-contents` returns `Some(contents)` | Send existing `add-buffer contents resolved`. Select the new buffer and echo `""`. |
| No name matches, shared `file-contents` returns `None` | Keep the entire collection/focus; echo `"failed"`. |

Reuse needs the initial resolve but no other filesystem query or effect.
It succeeds even if the underlying file has since disappeared or become
a non-file: the existing buffer wins before inspection. Do not reload it.
Relative input resolves against the Fs receiver's current directory, as
direct visit does. Resolved text equality is the only identity rule; no
basename, canonical-file identity, or resolution of stored buffer names.

A new buffer is inserted immediately after departing current and becomes
current, as `add-buffer` specifies. It has indexed Text with the exact
contents, point `(0,0)`, quit `#f`, scroll `(0,0)`, empty history, no mark,
and remembered rows 0. A missing path produces those defaults with empty
text and a bound resolved path, and creates no file. The departing buffer
and all neighbors keep their exact values. Do not reuse/remove an untitled
buffer, even when empty, and do not push an undo frame or clear the ring.
Duplicate paths created by earlier direct operations remain legal;
find-file adds none when a name already matches the resolved text.

### 4.4 Proof for 000

Add `tests/aloemacs/prompt-commands-find-file.rkt` before product edits.
Use independent constructors/expectations and snapshot old values. It must
prove:

1. Checked 13-field session shape, slot read/helper types, `FindFile` name
   and zero-payload construction, start/completion/helper result types,
   and unchanged concrete host typing with two injected Fs interface types.
   Wrong arguments, receivers, and arities fail checking. Loading
   `file.aloe` in fresh checked drivers needs no Fs/Term injection or effect;
   main initializes an absent slot without Fs calls.
2. Direct command execution ignores its key string and starts exactly
   `"Find file: "` with empty text at column 0. `C-x C-f` consumes and clears
   the pending prefix before start; neither key performs I/O. Quit, active
   search, pending prefix, and an active prompt refuse direct command start
   with full-session equality, including any earlier slot/submission.
3. Prompt typing/deletion/motion, ignored keys and LF, fit, and frame retain
   the waiting command. Return stores the exact unclipped editable string
   without the label, deactivates before completion, and ends with slot
   absent. A second inactive submit makes no calls. Escape before/after a
   prior submission preserves echo and submission, cancels without quit,
   and makes zero Fs calls. Direct start does not fill or clear the slot;
   with it absent, direct Return still only stores, including `Some("")`.
4. Every preserving reconstruction in §3.5 retains a nontrivial slot,
   active prompt, and previous submission while keeping its existing result.
   Inactive submit cannot consume an orphan; direct inactive cancel clears
   it. Successful existing/missing-file visit clears slot/prompt and replaces
   only current; refusal preserves the entire source. Visit preserves the
   last submission and retains its existing ring reset on success.
5. Name lookup handles singleton and three-or-more-buffer collections,
   current-first duplicates, a match in `after`, wrap into `before`, empty
   input, and a miss. Use duplicate names with different editors and two
   distinct positions containing equal-valued buffers. Assert exact focus,
   neighbor lists/order, immutability, and termination without Fs calls.
6. Existing regular-file find-file reads once and adds exact contents;
   missing relative input resolves and adds an empty bound buffer without
   read/write/creation. Test insertion from middle and last focus. Keep the
   departing buffer's Text focus, point, history, mark, both origins, rows,
   and path/name, with nontrivial neighbor and kill-ring fixtures.
7. Current and other-buffer reuse select the specified first name, retain
   unsaved in-memory text and all editor fields, and make only the resolve
   call. Include a vanished or now-ineligible on-disk target and duplicate
   paths. Empty input/cancel make zero Fs calls. Directory, symlink, other
   node, and a second-inspection read refusal add/switch nothing and show
   `"failed"`; no refusal writes. A raised read host failure still raises.
8. Exact CR/LF, final-newline, BOM, and Unicode contents survive opening.
   Prompt display is clipped/safe without changing submission. Full ANSI
   frames show the specified active label/cursor and the selected path or
   failed departing label after Return; one-row commands also work.
9. Scripted Term/Fs doubles drive prefix, redraw, prompt typing, Return,
   an ordinary edit, save, cancellation, and quit through the unchanged
   runner. Missing-file open creates nothing until save; existing-file
   open displays its contents. Redraw between keys preserves prefix/slot,
   and frame/write/key counts and fit-before-frame keep their contracts.
   Plain Ctrl-F, Ctrl-W, b, Ctrl-S, `C-x C-s`, remaining prefix misses,
   search precedence, and quit absorption keep their existing results.

The new buffer round trip is a direct no-TTY switch proof: return to the
departing buffer without fit or edit and compare its complete value. 000
must pass without SaveAs or SelectBuffer constructors, bindings, or tests.

## 5. Layer 001 — save-as

### 5.1 Path replacement with the exact editor value

Add `with-path(path : Path) -> AloemacsBuffer` to `AloemacsBuffer`. It
returns a buffer with the receiver's **exact editor value** and
`Some(path)`. It neither resolves nor writes. The name follows from the
existing derived-name method. There is no Option argument, stored name,
unbinding overload, or editor reconstruction.

Add session
`with-current-path(path : Path) -> (AloemacsSession H)`. Replace only
current through buffer `with-path` and collection `with-current-buffer`,
then rebuild the session preserving every other field, including echo,
search, pending, prompt, submission, waiting command, and ring. Neighbor
lists, focus, and every neighbor payload stay exact. This helper makes
the successful write's binding update independent of fresh-buffer/visit
construction.

### 5.2 Submitted save-as action

Install `SaveAs`, its name/start/completion arms, and the `"kill"` binding
as §3.1 specifies. No session field is added. Add session
`save-as-submitted(submitted : String) -> (AloemacsSession H)`:

| Submitted input / result | Transition |
|---|---|
| `""` | No Fs call; preserve path/editor/collection; echo `"failed"`. |
| Nonempty input, `Fs.write Some` | Bind current to the resolved path through `with-current-path`; echo `"saved"`. |
| Nonempty input, `Fs.write None` | Preserve original path/editor/collection; echo `"failed"`. No host write. |

For nonempty input, resolve with `(fs path submitted)` and send exactly
one thin `(fs write resolved ((self text) to-string))`. Its preflight
may inspect the target and parent under the existing Fs rules. Store the
resolved path only after `Some`; do not tentatively bind before writing.
The submitted text is not trimmed. Host failures still raise; no rollback,
atomic replacement, or recovery from a partial host write is added.

An existing regular file is overwritten; an eligible missing final file
is created. Missing/non-directory parent, directory, symlink, or other
non-file target produces the existing `None` refusal without a host write.
There is no confirmation, backup, directory creation, or newline conversion.
Writing the buffer's current path is an ordinary write, even without edits.
Writing another buffer's path is also permitted: current takes that path,
while the other buffer keeps its own text, editor, and path. Duplicates
remain legal, with no reload or deduplication.

Save-as does not send visit, add a buffer, or switch. Its success keeps
Text including its focus, point, quit, history, mark, scroll, and remembered
rows exactly. It pushes no history frame and leaves search state, prefix,
Fs, and ring alone. The protocol alone changes prompt/submission/slot;
the saved string remains readable after completion. Escape performs no
resolve, inspection, or write and preserves the old path and echo.

### 5.3 Proof for 001

Add `tests/aloemacs/prompt-commands-save-as.rkt` before product edits:

1. Check `SaveAs` construction/name, both path-update signatures and
   their argument/arity negatives, concrete session result types, and
   the unchanged 13-field session. The nested map now has exactly
   `"save", "find", "kill"`; global keys/default and region `Kill` stay.
2. `C-x C-w` starts `"Save as: "`, empty at column 0 with pending absent,
   and makes zero Fs calls until Return. Direct execution ignores a
   path-like key argument. All start guards retain whole-session equality.
   Plain Ctrl-W still performs the region command.
3. Save an untitled and a bound rich buffer to an eligible missing and an
   existing relative target. Assert one exact host write, resolved binding
   and name, echo `"saved"`, inactive prompt/absent slot, and exact stored
   submission. Compare complete editor values, neighbor order/payloads,
   ring and other session fields. Cover CRLF, BOM, Unicode, final-newline
   presence/absence, and text edited through the existing commands.
4. Same-path write succeeds and writes again on a new submission, even
   without edits. A second inactive Return/submit writes nothing. Writing
   another buffer's path changes only current's binding and on-disk text;
   its neighbor retains unsaved text and every editor field. A subsequent
   plain save uses the new current path and writes its current exact text.
5. Empty input and Escape make zero Fs calls. Missing/non-directory parent,
   directory, symlink, and other-node refusals cause zero host writes,
   leave all buffer values/path/focus exact, retain the submitted string,
   clear the slot, and show `"failed"`. Cancel retains both a previous
   submission and saved/failed token. A raised host-write failure remains
   a host failure, with no returned failed-session/atomicity promise.
6. Test buffer/session path helpers independently: they preserve the
   editor and every unrelated field, including active prompt and slot,
   with zero Fs calls. The path update adds no undo frame. Direct save,
   visit, selections, and find-file retain their §3.5/§4 meanings.
7. Scripted no-TTY runner input starts save-as, types a path through a
   redraw, submits, edits, saves, cancels a later save-as, and quits.
   Assert written contents/target and exact prompt/saved/cancel frames,
   existing fit/write/key counts, and one-row behavior. The no-TTY full
   suite remains green after the `"kill"` prefix-miss expectation becomes
   the new positive chord test; all remaining misses stay consumed.

001 must pass without SelectBuffer or its `"b"` binding.

## 6. Layer 002 — select-buffer

### 6.1 Submitted exact-name action

Install `SelectBuffer`, its name/start/completion arms, and the `"b"`
binding as §3.1 specifies. Add session
`select-buffer-submitted(submitted : String) -> (AloemacsSession H)`.
It sends the existing collection `find-name` with the **typed string**,
not a resolved Path. `Some(buffers)` sends `selected-buffers`; `None`
sets echo `"failed"` on the submitted session, preserving the entire
collection and focus. Empty input is a miss even if a raw buffer has a
stored path with empty text. No selection attempt performs any Fs call.

Matching is exact whole-string equality with the derived `(buffer name)`:
no trim, resolution, basename, case folding, completion, or new stored name.
Current wins when equal; otherwise the first `focus-next` match wins.
A pathless buffer and a buffer whose stored path text is `"untitled"`
have the same name and neither kind gets preference. Directly stored
relative path text is compared unchanged, just like any other name.

A success, including current-name selection, clears echo/search/prefix
through `selected-buffers`, accepts the departing search point, preserves
the ring, and keeps every buffer/editor/path value. A miss creates nothing,
does not switch/reset selection state, and shows `"failed"`. The prompt
protocol still ends the prompt, retains the string, and clears the slot.
Escape leaves buffers, echo, and the previous submission unchanged.

Cycling `switch-buffer` remains an independent zero-argument send and
`SwitchBuffer` command with no binding. It still cycles and preserves
the prompt/slot on direct use. There is no session selector that overloads
it with a typed name, and no synthetic global binding for command names.

### 6.2 Proof for 002

Add `tests/aloemacs/prompt-commands-select-buffer.rkt` before product edits:

1. Check `SelectBuffer` construction/name, submitted-action argument/arity
   types, concrete host result types, unchanged session shape, and final
   nested binding order `"save", "find", "kill", "b"` with absent default.
   The global table/default is unchanged; SwitchBuffer still has no key.
2. `C-x b` starts exactly `"Buffer: "`, empty at column 0, after clearing
   the prefix. Plain b still inserts. Direct execution ignores its key
   string; start guards and active prompt ignored-key behavior still hold.
3. Select another buffer by its exact full path or `"untitled"`; keep
   every editor field and all paths/order exact, perform no Fs call, and
   leave the new submission readable with prompt/slot absent. A current
   match stays current with the same selection resets as cycling switch,
   including nondefault inactive search fields in a fixture.
4. With at least three buffers, prove the first forward duplicate match
   wins both before and across wrap. Distinct editor payloads identify
   which position won. Include multiple untitled buffers, the pathless/
   literal-`"untitled"` collision in both orders, and equal-valued positions.
   Round-trip selection without fitting/editing retains the full editors.
5. Empty input, basename-only input, a relative spelling for an absolute
   stored name, case/space differences, and an unknown name fail without
   creation or focus change. A directly stored relative name succeeds
   only on that exact text. All successes, misses, edits, and cancels make
   zero Fs calls. Miss sets `"failed"`; cancel retains the previous token
   and submission. Repeated inactive submit cannot select again.
6. A scripted runner sequence opens a second buffer using find-file,
   selects the original by name, edits/saves there, and quits. Check
   destination text and path, exact active/inactive cursor frames, retained
   neighbor text, existing iteration counts, and one-row selection. Direct
   cycling still works, unknown idle command-name strings remain misses,
   and all remaining prefix misses are consumed.

## 7. Verification and acceptance

Each implementer writes its focused tests first, observes the missing
behavior fail, implements that assigned slice, runs verification, and
stops when green. From the project root, every agent test command includes
`TMPDIR=/tmp` and `-y`, even when a predecessor omits them.

For **aloemacs-prompt-commands 000**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/prompt-commands-find-file.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-prompt-commands 001**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/prompt-commands-find-file.rkt tests/aloemacs/prompt-commands-save-as.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-prompt-commands 002**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/prompt-commands-find-file.rkt tests/aloemacs/prompt-commands-save-as.rkt tests/aloemacs/prompt-commands-select-buffer.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Earlier focused tests retain their substantive results; update only the
exact constructor/map inventories that grow at the assigned stage. Test
all observable Fs calls, distinguishing resolve/preflight from read/write
effects. Empty input and cancel promise **zero calls**, not merely zero
writes. Existing Fs production tests already prove encoding and host
eligibility; this series uses doubles and no physical TTY or repository
file as scratch space. No benchmark, timing gate, or hand check is required.

Review the source as well as results: command execution belongs to session
constructor cases; one read policy serves visit and find-file; find-file
never sends visit; one session slot is threaded everywhere; names are
derived and exact; the global map, Term, editor, and runner keep their
boundaries. Behavioral equality alone cannot prove those structural rules.

Do not commit `compiled/`. The optional existing launch is
`racket host/racket/aloemacs-run.rkt [path]`. After a `.rkt` edit, first
run the named tests or `raco make host/racket/aloemacs-run.rkt bin/aloe`;
the launchers load existing bytecode without rebuilding it. `.aloe` edits
need no rebuild.

The completed series is accepted when all of these are true:

1. Idle Ctrl-F still searches, Ctrl-W still kills the region, and b still
   inserts. Ctrl-S and `C-x C-s` still save; an unbound `C-x` second key
   changes no buffer and is consumed. Direct visit still replaces only
   current. A direct prompt with no waiting command only stores on Return.
2. `C-x C-f` opens or reuses a resolved path, preserving the departing
   buffer's complete value. Missing makes an empty bound buffer without
   file creation. Reuse reads nothing; directory/symlink/other/read refusal
   changes no buffer. Empty/cancel make zero Fs calls.
3. `C-x C-w` writes current exact text and binds only that buffer to the
   resolved path on success, keeping the editor value. An Option refusal
   writes nothing and leaves the path; cancellation makes no Fs call.
   Duplicate paths stay legal and other buffers remain unchanged.
4. `C-x b` selects only an exact derived name, current first and otherwise
   the first forward match. It never resolves, creates, or reads/writes.
   Empty or missed names retain focus; cycling switch still has no key.
5. One optional waiting-command field controls all three prompts. Return
   stores and deactivates before completion and clears the slot afterward;
   inactive submit cannot repeat an action. Cancel clears the slot and
   retains echo/submission. Ordinary rebuilds preserve it; successful
   visit clears it, and refusal leaves it untouched.
6. Echo tokens remain exactly `""`, `"saved"`, and `"failed"` with §3.4's
   outcomes. Prompt/frame behavior, search precedence, quit absorption,
   per-buffer history/mark/scroll, session ring, and runner iteration stay
   within their existing contracts.
7. All three focused proofs and `TMPDIR=/tmp raco test -y tests/aloemacs`
   pass without a TTY, and no later feature, host/language change, global
   checkpoint, or fourth slice is added.

The designer stops at this draft and this folder's README status update.
Human acceptance is required before checkpoint work. The manager then
writes **aloemacs-prompt-commands 000 only**, and stops. If you have been
told to read this file as the manager assignment, it is the whole
assignment; do not write later checkpoints in advance.
