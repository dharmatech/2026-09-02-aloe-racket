# aloemacs-prompt-commands 000 — Find-file and the waiting command protocol

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Make `C-x C-f` start the existing prompt and open or reuse the submitted
resolved path on Return. A new file buffer retains the departing buffer's
complete value; an existing matching buffer wins before any inspection
or read. Escape runs nothing. Introduce the single waiting-command slot,
thread it through every reconstruction, and retain direct prompt
submission and direct visit behavior.

This is one independently testable command and its shared protocol.
Stop before save-as and named buffer selection: no `SaveAs`,
`SelectBuffer`, `"kill"` or `"b"` prefix binding, path-update helper,
or later focused test belongs to 000. Do not write or implement 001 or 002.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity: **aloemacs-prompt-commands 000**, filed as
  `checkpoints/000-find-file.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a literal
  selector; function objects execute only through `call`.
- The accepted [../spec.md](../spec.md) §§1–2 govern predecessors,
  authority, boundaries, and non-goals. §§3.1–3.5 govern the complete
  shared protocol introduced in 000; §4 governs find-file, lookup, and
  its focused proof. §7's **000** commands and acceptance conditions
  applicable to this slice govern completion. §§5–6 describe later
  checkpoints and are not implementation assignments.
- There is no previous prompt-commands checkpoint. Layers 1–15 are
  implemented. In particular, [aloemacs-minibuffer 001](../../minibuffer/checkpoints/001-type-submit-cancel.md)
  and [aloemacs-buffer 001](../../buffer/checkpoints/001-switch-and-kill-buffer.md)
  are implemented, reviewed, and accepted, as their READMEs record.
  File and Keymap provide the preserved filesystem and dispatch seams.
  There is no runner prerequisite.
- Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe)
  and [main.aloe](../../../../../../examples/aloemacs/main.aloe).
  The session currently has twelve fields, an editable storage-only
  prompt, a nonempty buffer zipper, constructor-based command execution,
  and a nested `C-x` map containing only `"save"`.

The predecessor specs named in the accepted spec remain authority for
their preserved seams. Do not amend them to update their old inventories.
Existing `minibuffer-session.rkt`, `buffer-session.rkt`, `keymap-prefix.rkt`,
and `file-runner.rkt` under `tests/aloemacs/` show checked fixtures,
independent expectations, counted Fs doubles, and scripted Term runs.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: only the command, binding, session field,
  helpers, completion/cancellation, reconstruction threading, pure lookup,
  shared read-policy extraction, and find-file action specified below.
  Keep the existing two loads and declaration order.
- `examples/aloemacs/main.aloe`: append the typed absent waiting-command
  field to startup; retain every existing starting value.
- Create `tests/aloemacs/prompt-commands-find-file.rkt` before product
  edits. It owns this slice's focused proof, including scripted runner
  input through the unchanged runner.
- Existing files under `tests/aloemacs/`: migrate valid session fixtures
  and independent expected reconstructions; update exact session,
  command, nested-map, and main/source inventories affected by 000;
  replace newly bound `"find"` prefix-miss examples with positive chord
  coverage. Preserve substantive prior assertions and all remaining
  consumed-miss proofs. The migration inventory below is a starting
  point; search the whole aloemacs test tree.

### Must leave untouched

- `examples/aloemacs/editor.aloe` and all other product modules.
- `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, other host files,
  capabilities, and Fs/Term interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, global checkpoints,
  predecessor documents, and this series' design documents/checkpoints.
- Editor and `UndoFrame` field shapes, prompt field shape/editing algebra,
  frame composition, search-key behavior, runner arguments and ordering,
  global bindings/default, and existing commands' meanings.

Add no module, load, dependency, capability, build step, or API beyond
the additions named here. If another file or design change proves
necessary, stop and return this checkpoint to the manager instead of
widening the slice. If this layer cannot fit one implementer
conversation, report the size problem and stop for review; do not split
or add a fourth checkpoint yourself.

## Slice requirements

### 1. Command and production binding

Append zero-payload `FindFile` after the installed `AloemacsCommand`
constructors. Add its exhaustive `name` arm returning exactly
`"find-file"`. Extend session `execute-command` with a constructor arm
that sends `start-command-prompt` with that command value and exactly
`"Find file: "`, including the trailing space. Its `key : String`
argument is ignored, never used as a path. Return the receiver's
concrete `(AloemacsSession H)`.

Append `(AloemacsBinding Command "find" (AloemacsCommand FindFile))`
after the existing `"save"` entry in `aloemacs-ctrl-x-keymap`. Its exact
ordered keys become `"save", "find"`; the save value remains
`aloemacs-save-command` and the nested default remains `None`. The
global map retains its 20 command bindings, final `"ctrl-x"` prefix,
and `Some SelfInsert` default.

Pending lookup still clears the prefix before executing its command;
therefore `C-x C-f` can pass the unchanged prompt-start guard. An unbound
second key stays consumed without global retry. Plain Ctrl-F searches,
plain Ctrl-W kills the region, and plain b inserts. `SwitchBuffer` still
cycles forward with no binding. Commands still have only `name`, no
execution method or generic host parameter. Do not dispatch by command
name, put execution on the editor, or use computed selectors.

### 2. Single slot, startup, and constructor migration

Append `waiting-command : (Option AloemacsCommand)` after
`last-submission`. The complete ordered session fields become:

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

The generated read returns `(Option AloemacsCommand)`. Startup remains
empty and untitled, with prompt, submission, and slot absent, no Term
injection, and zero Fs calls. At every untyped absent-slot constructor
or expectation use the lawful inferable form:

```aloe
(if #t (Option None) (Option Some (AloemacsCommand FindFile)))
```

A bare `(Option None)` there is not lawful. A method's expected
constructor field type may supply the absent type directly. Add no
concrete-Option setter or checker/evaluator workaround for absent-Option
dispatch. The editor retains eight fields and `UndoFrame` four.

Thread the slot through all existing session reconstruction sites:

| Site | Slot argument |
|---|---|
| `with-active-prompt`; active `submit-prompt` before completion | Receiver's slot. |
| `cancel-prompt`, including inactive cancellation of an orphan | `None`. |
| Both `add-buffer` arities; `switch-buffer`; `kill-buffer` | Source session's slot. |
| `with-editor`, `with-kill-state`, `with-search`, `with-echo` | Receiver's slot. |
| `with-prefix`, `clear-prefix` | Receiver's slot. |
| Successful `visited` | `None`; also clear prompt and preserve submission. |
| `main.aloe` startup | Typed `None` above. |
| New `with-waiting-command`, `clear-waiting-command` | `Some(command)`, `None`, respectively. |
| New `selected-buffers` | Receiver's slot. |

Direct editor wrappers, search/kill helpers, `save-key`, prefix dispatch,
and `ensure-visible` inherit threading through existing helpers. Direct
save, add/switch/kill-buffer, fit, and frame never run the waiting command
and preserve it during an active prompt. `unchanged` and `frame` construct
no session. Refused visit leaves its entire source intact. Successful
visit retains its existing current-only replacement and ring reset.

Migrate fixtures and independent expectations in `buffer-value.rkt`,
`buffer-session.rkt`, `echo-session.rkt`, `file-session.rkt`,
`kill-session.rkt`, `motion-editor.rkt`, `runner.rkt`, `safe-cells.rkt`,
`search-session.rkt`, `undo-session.rkt`, `viewport-editor.rkt`,
`visited-unchanged.rkt`, `keymap-session.rkt`, `keymap-prefix.rkt`,
`minibuffer-value.rkt`, and `minibuffer-session.rkt`, all under
`tests/aloemacs/`. Update exact session inventories and main/source
expectations in `runner.rkt` and `file-runner.rkt`, plus command/map
inventories in keymap and buffer tests. Search all product and aloemacs
tests again for construction sites and stale inventories.

Keep intentional old-arity negatives as negatives. Other negative
fixtures retain their original field/type mistake at the new arity.
Editor-only fixtures stay editor-only. Preserve substantive buffer,
prompt, search, history, mark, ring, viewport, filesystem, and full-frame
assertions. Remove only `"find"` from old prefix-miss lists at this stage;
`"kill"` and `"b"` remain unbound.

### 3. Prompt start, submission, and cancellation

Introduce these ordinary session selectors, all returning the receiver's
concrete `(AloemacsSession H)`:

| Selector | Contract |
|---|---|
| `with-waiting-command(command : AloemacsCommand)` | Store `Some(command)`; preserve every other field. |
| `clear-waiting-command()` | Store `None`; preserve every other field. |
| `start-command-prompt(command : AloemacsCommand, label : String)` | Apply `start-prompt`'s eligibility gate; on success send `start-prompt label`, then `with-waiting-command command`. |
| `run-submitted-command()` | Complete the waiting supported constructor using `last-submission`, then clear the slot on the returned session. |

The start gate refuses current quit, active search, pending prefix, or an
already active prompt by returning the whole receiver unchanged, slot
included. It makes zero Fs calls and preserves echo and old submission.
An existing prompt cannot be mistaken for a successful new start.
Successful start may replace an orphaned slot when no prompt is active
and the guards permit it. Start uses empty text and column 0; no path
or name is prefilled.

Direct `start-prompt` neither fills nor clears the slot. Prompt editing,
motion, deletion, LF, and ignored keys preserve it exactly. Retain
`handle-key` precedence: quit, search, active prompt, then pending/global
idle routing. Active prompt input consults no keymap; named
save/find/prefix/kill keys stay ignored. Search remains first in mixed
raw fixtures. Only Return and Escape's completion/clearing results change.

Active `submit-prompt` must perform these steps in order:

1. Inactive prompt: return the whole receiver unchanged, even with a
   prior submission or orphaned slot. Do not complete or consume it.
2. Active prompt: rebuild with prompt `None` and last submission
   `Some(prompt.text)`, preserving everything else including the slot.
3. Send `run-submitted-command` on that rebuilt session. With
   `Some FindFile` and a stored string, send `find-file-submitted` with
   that exact string. Never send `execute-command` again, use a label
   or key as the input, or case on a command-name string.
4. Clear the slot on the action's returned session, success or Option
   refusal. Keep prompt inactive and submission readable. A second
   inactive submit cannot repeat any filesystem effect.

With no waiting command, completion returns unchanged and direct Return
remains storage-only, including `Some("")`. For a raw slot containing a
non-prompt command, or no stored submission, consume the slot without
running an ordinary command or changing echo. Use a final `else` for
non-prompt constructors. This helper expects the freshly submitted
inactive session; it is not a command registry.

`cancel-prompt` clears prompt and slot while preserving buffers, echo,
search fields, pending prefix, ring, and previous submission. Direct
inactive cancel clears an orphaned slot; with neither prompt nor slot it
keeps the existing unchanged result. Escape never quits or sets
`"failed"` and makes zero Fs calls.

If a caller directly selects another buffer during a prompt, completion
acts on whichever buffer is current at Return. Store no target buffer,
callback, command-name string, or second waiting flag.

### 4. Pure name lookup and selection results

Add these collection selectors to `AloemacsBuffers`:

| Selector | Result |
|---|---|
| `find-name(name : String)` | `(Option AloemacsBuffers)` |
| `find-name-in(name : String, remaining : Int)` | `(Option AloemacsBuffers)` |

`find-name` rejects empty input. Otherwise compute the initial budget
once as `1 + before.len + after.len` through existing List/Int sends.
The bounded scan rejects a nonpositive budget, compares exact current
`(buffer name)` text, returns `Some` of that focused collection on a hit,
and otherwise advances with `focus-next` while another candidate remains,
decreasing the budget by one. Inspect each position at most once.

Current wins among duplicates; otherwise the first forward match wins,
including across wrap. Preserve logical buffer order and every value.
A miss returns `None`, never a rotated collection to install. Do not
stop by comparing buffer values or names with the starting buffer:
distinct positions may contain equal values. No Fs call, resolution,
stored count, List index, new name policy, or stored/unique name belongs
to lookup. Names stay exact derived path text or `"untitled"`.

Introduce session `selected-buffers(buffers : AloemacsBuffers)` returning
`(AloemacsSession H)`. Install that collection and set echo `""`,
searching/wrapped/failing `#f`, query `""`, origin `(Position new 0 0)`,
and pending `None`. Preserve Fs, ring, prompt, submission, and slot.
These resets also apply to a current-name hit and nondefault inactive
search fixtures. Do not rebuild/fit any editor, restore the departing
search origin, or push history. Retain the departing search-result point.

### 5. Shared read policy and submitted find-file

Add session `file-contents(path : Path) -> (Option String)`. Its path
is already resolved; it changes no session or buffer. Encode the
existing visit eligibility policy exactly once:

| First `(fs inspect path)` | Result |
|---|---|
| `None` | `Some("")`; no read or creation. |
| `Some RegularFile` | Existing `(fs read path)` result, including second-inspection `None`. |
| `Some Directory`, `Some SymbolicLink`, `Some Other` | `None`; no read. |

Refactor direct `visit` to resolve through `(fs path (path text))`, send
this helper, and return `Some(self visited contents resolved)` only for
`Some(contents)`, otherwise `None`. Preserve current-only replacement,
successful visit resets, and host failure propagation. Do not implement
find-file through visit or a temporary visiting session. Do not duplicate
classification policy or use thin `Fs.read None` to treat refusals as
missing files.

Add session `find-file-submitted(submitted : String)` returning
`(AloemacsSession H)`. Empty input changes only echo to `"failed"`
with zero Fs calls. Nonempty input is not trimmed, including spaces:

1. Resolve once at the command boundary with `(fs path submitted)`.
   Compare and store that resolved Path, not the typed relative spelling.
2. Send collection `find-name` with resolved path text before inspecting
   or reading anything. A hit uses `selected-buffers`; current wins,
   otherwise the first forward duplicate wins. Reuse makes only the
   resolve call, retains unsaved text and every editor field, and succeeds
   even if the disk target has vanished or become ineligible.
3. On a lookup miss, send shared `file-contents`. `Some(contents)` sends
   existing `add-buffer contents resolved`. The new buffer is inserted
   immediately after departing current and becomes current. `None`
   changes only echo to `"failed"`, preserving collection and focus.

New buffers use indexed Text with exact contents, point `(0,0)`, quit
`#f`, origins `(0,0)`, empty history, no mark, and remembered rows 0.
Missing input creates an empty bound buffer and no file. Retain the
entire departing buffer, neighbors, and ring; do not reuse/remove an
empty untitled buffer or clear the ring. Duplicate paths remain legal.
Stored names are not resolved, and resolved text equality is the only
identity rule; there is no basename or canonical-file comparison.

Find-file success shows `""`; empty input or read refusal shows
`"failed"`. Start/edit/ignored keys/redraw/cancel and direct storage-only
Return retain echo. Keep the vocabulary exactly `""`, `"saved"`, and
`"failed"`. Raised host read failures still raise; add no failed-session
translation, transactional recovery, or atomicity promise.

### 6. Retained rendering and runner seams

Commands neither fit nor redraw themselves. Active frame still shows
label plus editable text through existing clipping/safe cells and the
clamped prompt cursor. After completion/cancel it shows the selected
path/status and text cursor. At one row no echo suffix is added, but
all command transitions work. Stored submission excludes the label and
retains unclipped, unsanitized editable text.

Keep the runner's zero-or-one path argument, `aloemacs-editor` binding,
fit-then-frame order, one String and one `term write` per iteration,
and current editor's quit flag. A subsequent fit may change only the
selected editor's origins/remembered rows under existing rules. The
host already maps Ctrl-F to `"find"`; add no Term chord or runner edit.

### 7. Focused proof, written first

Create `tests/aloemacs/prompt-commands-find-file.rkt` before product
edits. Run its focused command and observe missing behavior fail, then
implement this slice. Use the unchanged checked Aloe driver, `rackunit`,
counted Fs doubles, scripted Term doubles, independent constructors and
expectations, and snapshots of old values. No physical TTY or repository
file is scratch space. The proof must cover accepted spec §4.4:

1. Exact thirteen-field session shape; slot read and all new helper
   signatures/types; zero-payload `FindFile` construction/name; exact
   nested binding order/default and unchanged global table/default.
   Session results retain concrete host types with two injected Fs
   interface types. Wrong arguments, receivers, and arities fail checking.
   Fresh checked drivers load `file.aloe` without Fs/Term injection or
   effects; main initializes an absent slot without Fs calls.
2. Direct execution ignores a path-like key string and starts exactly
   `"Find file: "`, empty at column 0. `C-x C-f` consumes and clears
   pending before start; neither key performs I/O. Quit, active search,
   pending, and active prompt refuse start with whole-session equality,
   including earlier slot/submission. Cover orphan replacement on a
   permitted start.
3. Typing, deletion/motions, LF, ignored keys, fit, and frame retain the
   slot. Return stores exact editable text, deactivates before completion,
   then clears the slot; repeated inactive submit makes no calls. Escape
   before/after prior submission preserves echo/submission and never quits.
   Direct start preserves the slot; with it absent, Return only stores,
   including empty text. Non-prompt slots and missing-submission completion
   fixtures consume the slot without ordinary command execution.
4. Every preserving reconstruction retains a nontrivial slot, active
   prompt, and prior submission while keeping its existing result.
   Inactive submit preserves an orphan; inactive cancel clears it.
   Existing/missing-path successful visit clears prompt/slot, replaces
   only current, preserves submission, and retains its ring reset.
   Refusal preserves the entire source. No direct preserving operation
   runs the waiting command.
5. Pure lookup on singleton and three-or-more-buffer collections:
   current-first duplicates, a hit in `after`, wrap into `before`, empty
   input, misses, and nonpositive budgets. Include duplicate names with
   distinct editors and distinct positions holding equal-valued buffers.
   Assert exact focus/neighbor lists/order, immutability, termination,
   and zero Fs calls. Check selection resets on current and other hits.
6. Regular-file open reads once and adds exact contents; missing relative
   input resolves to an empty bound buffer without read/write/creation.
   Prove middle and last-focus insertion, indexed fresh defaults, and
   retained departing Text focus, point, history, mark, both origins,
   remembered rows, path/name, neighbors, and ring. Switch back without
   fitting/editing and compare the departing buffer's complete value.
7. Current and other-buffer reuse retain unsaved text/all editor fields
   and make only the resolve call, including vanished/ineligible disk
   targets and duplicate paths. Empty input/cancel make zero Fs calls.
   Directory, symlink, other node, and live second-inspection read refusal
   add/switch nothing and show `"failed"`, with zero writes. Raised host
   read failure still raises. Test shared read policy and direct visit's
   preserved outcomes as well as find-file.
8. Exact CR/LF, final-newline, BOM, and Unicode contents survive opening.
   Clipping/safe display leaves submission intact. Compare full ANSI
   active label/cursor frames and inactive selected-path or failed
   departing-label frames after Return, plus cancellation and one-row
   behavior. Frame tests use independent expected strings.
9. Scripted runner input exercises prefix, redraw, prompt typing, Return,
   ordinary edit/save, cancellation, and quit. Missing-file open creates
   nothing until save; regular-file open displays contents. Redraw
   preserves prefix/slot. Assert fit-before-frame, exact frames and
   frame/write/key counts, and one-row operation. Plain Ctrl-F, Ctrl-W,
   b, Ctrl-S, `C-x C-s`, all remaining prefix misses, search precedence,
   and quit absorption retain their existing results.

Count every observable Fs call, distinguishing resolve/inspect preflight
from host read/write effects. Empty input and cancellation promise zero
calls, not merely zero writes. Existing production Fs tests already prove
encoding/eligibility; use doubles here. Keep migrated tests' substantive
assertions and independent expectations. Do not obtain an expected value
by sending the transition being tested.

## Explicit non-goals

No `SaveAs`, `SelectBuffer`, `C-x C-w`, `C-x b`, named selection action,
`with-path`, `with-current-path`, or later focused tests. The pure lookup
introduced here is for find-file reuse; it does not bind cycling switch
or install another name policy.

No completion/list, prompt history, prefilled text, directory browser,
wildcards, `mkdir`, overwrite confirmation, backups, windows/splits,
mode line, buffer menu, `M-x`, new Term chord, runner argument, search-key
change, stored/unique/basename names, untitled reuse/discard, or direct
visit insertion. No dirty bit, save-on-quit, Text method, List index,
kernel message, global checkpoint, Mirror, mutation, inheritance,
delegation, macro, implicit Int/Float coercion, new special form, or
Boids work belongs here.

## Verification and completion

From the project root, run in this order after implementation:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/prompt-commands-find-file.rkt
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

Review source as well as results: execution stays in session constructor
cases; one shared read policy serves visit and find-file; find-file never
sends visit; exact pure lookup uses a bounded forward scan; the one slot
is threaded everywhere; submission deactivates before completion and
clears the slot afterward. The global map, Term, editor, runner, host,
libraries, and language retain their boundaries. Behavioral equality
alone does not prove these structural requirements.

Complete when both test commands pass, `git diff --check` is clean, the
focused proof covers this checkpoint and spec §4.4, source review passes,
and the scope is respected. 000 must pass without SaveAs or SelectBuffer
constructors, bindings, helpers, or tests. Report changed files, the
observed initial focused failure, final verification results, and the
structural review. Stop when green for human review; do not start or
issue 001 or 002.
