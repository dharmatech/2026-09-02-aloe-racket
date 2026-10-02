# aloemacs-keymap 000 — Named commands and the session keymap

**Status.** Ready to implement. Reissued against the accepted revision of
[`../spec.md`](../spec.md).

Command execution belongs to the session:
`(session execute-command command key)`. Commands remain named values
with only a `name` method. Do not restore command `run` or add a checker
prerequisite. Revise the retained focused tests before product edits.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement only this slice,
and stop when green.

## Goal

Replace the session's idle string dispatch with an immutable global keymap
whose bindings contain named command values. Ordinary lookup and session
`execute-command` sends reproduce every existing idle key's session result,
echo, history, and filesystem effect.

This checkpoint adds 21 command constructors, 20 explicit bindings, and
the self-insert default. Stop before prefix work: no pending field, nested
map, `Prefix` constructor, Ctrl-X binding, or Term edit belongs to 000.
Do not write or implement 001.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec; the
checkpoint narrows the spec to one slice and does not revise it.

- Identity is **aloemacs-keymap 000**, filed as
  `checkpoints/000-session-keymap.md`. This is a local editor checkpoint,
  not a global Aloe number.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [`docs/workflow.md`](../../../../../workflow.md), root `AGENTS.md`,
  `SPEC.md`, and `CHECKPOINTS.md` before product edits. `SPEC.md` remains
  language law; this checkpoint changes no language rule.
- [`../spec.md`](../spec.md) §§1–2 set authority, predecessors, and product
  boundaries; §§3.1–3.7 govern all of this slice; §5's **000** verification
  and the acceptance conditions applicable to 000 govern completion.
  §4 describes later 001 and is not an implementation assignment.
- Text through Motion are implemented. In particular, Kill 000–002 and
  Motion 000 are present. There is no earlier keymap checkpoint. The
  safe-cell-controls cleanup is not a prerequisite; do not wait for it.
- The earlier 000 attempt was returned and its product edits reverted.
  The revised spec is accepted; this reissued file replaces that returned
  assignment. The retained `tests/aloemacs/keymap-session.rkt` still has
  command-owned execution expectations to revise first. Do not rely on a
  temporary reproduction or the earlier conversation.
- Start with `examples/aloemacs/file.aloe`, its existing session helpers
  and `idle-key`, and the preserved editor methods in
  `examples/aloemacs/editor.aloe`. Existing `kill-session.rkt`,
  `motion-editor.rkt`, `search-session.rkt`, `echo-session.rkt`, and
  `undo-session.rkt` under `tests/aloemacs/` show checked fixtures and
  preserved results. The spec names the predecessor design authorities.

Today `file.aloe` loads `editor.aloe` and `../../lib/fs.aloe`. Its idle
`cond` owns mark/kill/yank/find/save and otherwise sends editor
`handle-key`, then clears echo. The editor owns the remaining named keys
and length-one insertion. Session `handle-key` already absorbs quit before
search, and active search already exits through `idle-key` for other keys.
The refactor must remove the session's use of editor `handle-key` without
changing that direct editor method.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`: the declarations, values, wrappers,
  helpers, and idle dispatch specified below. Keep all application
  declarations in this existing module.
- `tests/aloemacs/keymap-session.rkt`: revise first, using the checked
  driver, rackunit, and Fs doubles. Replace command-owned execution
  expectations with session `execute-command` sends while preserving
  substantive behavior assertions.
- Existing files under `tests/aloemacs/`: only appropriate new session
  method/type checks. Preserve all substantive prior assertions. Existing
  fixtures need no constructor threading in 000.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`, and all
  other product modules.
- `host/racket/term.rkt`, `host/racket/aloemacs-run.rkt`, the runner's
  ordering and Term writes, and host interfaces.
- `aloe/`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`, and predecessor specs or
  checkpoints, including safe-cell-controls.
- Editor/session field lists and constructor arities, frame composition,
  safe-cells, and existing application names.

Do not add a keymap module, load cycle, package, capability, or dependency.
If another file or a public API change outside this scope proves necessary,
stop and return the checkpoint to the manager instead of widening it.

## Slice requirements

### 1. Immutable command, keymap, and binding values

Use this declaration order in `file.aloe`, after its existing loads:

1. Non-generic `AloemacsCommand`, its zero-payload constructors, and `name`.
2. Generic fields class `(AloemacsKeymap B)` and its lookup methods.
3. Non-generic `AloemacsBinding`, its one constructor and `key` method.
4. Existing `AloemacsSearchScan` and `(AloemacsSession H)`, including the
   session `execute-command`, helpers, and map dispatch.
5. Command constants and the global map before loading finishes.

The command constructors and their exact names are the table in requirement
3. `name() -> String` uses an exhaustive command `case`. There is no `new`
constructor accepting an arbitrary name, command registry, or second
name-to-command router. The command declaration is complete at step 1.
Its only instance method is `name`; add no execution method, method-level
type parameter, or later `define-methods AloemacsCommand` extension.

The keymap's ordered fields and method signatures are:

```aloe
(fields
  (bindings (List B))
  (default (Option AloemacsCommand)))

(lookup (key String) (Option B) ...)
(lookup-in (bindings (List B)) (key String) (Option B) ...)
```

Constructor order is `bindings`, then `default`. In application values,
`B` is always `AloemacsBinding`. This parameter permits the declaration
order needed by the later nested binding; it adds no protocol or library.

`AloemacsBinding` has exactly one constructor in 000:

```aloe
(Command (fields (key String) (command AloemacsCommand)))
```

`key() -> String` extracts the string through an exhaustive binding `case`.
The lookup result is `(Option AloemacsBinding)` for application maps; add
no separate result class.

`lookup` and `lookup-in` scan the list in order and compare whole key strings
with `=`. The first equal binding wins, including duplicate keys. A miss
returns `None`. Lookup never runs a command, consults the default, changes
the list or session, or routes by a command's name.

Declare this instance method inside the existing generic fields class
`(AloemacsSession H)`:

```aloe
(execute-command (command AloemacsCommand) (key String) (AloemacsSession H)
  ...)
```

Execute as `(session execute-command command key)`. `H` is the receiver's
class parameter, not a method-local type parameter or another argument.
Case exhaustively on `command` itself, covering all 21 constructors in
requirement 3. Each arm sends ordinary literal selectors to `self`. Only
`SelfInsert` uses `key`, by sending `(self insert key)`; every other arm
ignores it. Commands contain no filesystem host or executable payload.

The method performs the specified transition, including echo, and returns
the receiver's concrete `(AloemacsSession H)`. It does no lookup or key
length check. Key routing, quit absorption, and active-search precedence
remain in session key handling. Existing direct session sends keep their
own semantics, including direct `save` returning Option.

Execution stays on the session so its generic fields-class body is checked
at a concrete receiver, including the injected Fs host used by save. Do
not move execution to the non-generic command class, restore command
`run`, make commands generic, or amend `aloe/type.rkt` or `SPEC.md`.
Do not case on command-name strings, send computed selectors, or execute
function payloads, `call`, Mirror, or class-side methods. Use the existing
checker unchanged for loading and runtime sends.

### 2. Session helpers and preservation

The session's ordered fields remain exactly:

```aloe
(editor AloemacsEditor)
(fs (Fs H))
(path (Option Path))
(echo String)
(searching Bool)
(query String)
(origin Position)
(wrapped Bool)
(failing Bool)
(kill-ring (List String))
```

The editor retains text, point, quit, both scroll origins, history, mark,
and remembered text-rows. Neither constructor grows. The global keymap is
static top-level data, not a session field.

Keep session `insert`, `newline`, `backward-delete`, the four `move-*`
methods, and `request-quit` as thin `with-editor` wrappers. Add identical
zero-argument wrappers for `line-start`, `line-end`, `page-up`, `page-down`,
`buffer-start`, `buffer-end`, and `undo`. Each sends the same selector to
the editor and returns `(AloemacsSession H)` through `with-editor`.
Direct wrappers preserve echo, search fields, fs, path, and ring and add
no history of their own. Page motion uses the text-row count already
remembered by `ensure-visible`; `execute-command` takes no terminal
dimensions.

Add these helpers, each returning `(AloemacsSession H)`:

| Method | Transition |
|---|---|
| `with-echo(token : String)` | Rebuild with only echo replaced; preserve every other field. |
| `find()` | Existing `with-search` transition: same editor, searching `#t`, query `""`, origin current point, wrapped/failing `#f`; preserve stored echo. |
| `save-key()` | Send direct `save` once. `Some(session)` gets `"saved"` through that returned session; `None` gets `"failed"` through the receiver. Preserve every other field. |

Direct `save` retains `(Option (AloemacsSession H))`, writes exact
`(text to-string)` on each bound success, and preserves all session payloads
on success. Untitled and ineligible `Fs.write None` cases produce the key
command's failed token. Raised host failures still raise; do not catch and
convert them into failed sessions. Save never adds an undo frame.

Keep mark/kill/kill-line/yank and their `with-kill-state` behavior unchanged.
Their command sends already clear echo. Keep search helpers, fitting,
framing, visiting, and editor `handle-key` unchanged. In particular, do
not add kill-style mark validation to ordinary insertion or undo.

### 3. Exact production table and command transitions

Define these immutable top-level values:

- `aloemacs-self-insert-command = (AloemacsCommand SelfInsert)`.
- `aloemacs-save-command = (AloemacsCommand Save)`.
- `aloemacs-global-keymap = (AloemacsKeymap new bindings default)`, with
  exactly the first 20 table rows below, in that order, and
  `default = (Option Some aloemacs-self-insert-command)`.

Each explicit row is `(AloemacsBinding Command key command)`.
Use `aloemacs-save-command` in the save binding. Other command values may
be constructed directly in their bindings. The final table row is the
default command, not an explicit binding.

| Key | Command constructor | Exact `name` | Session `execute-command` transition |
|---|---|---|---|
| `"return"` | `Newline` | `"newline"` | Session `newline`, then `with-echo ""` |
| `"backspace"` | `BackwardDelete` | `"backward-delete"` | Session `backward-delete`, then `with-echo ""` |
| `"left"` | `MoveLeft` | `"move-left"` | Session `move-left`, then `with-echo ""` |
| `"right"` | `MoveRight` | `"move-right"` | Session `move-right`, then `with-echo ""` |
| `"up"` | `MoveUp` | `"move-up"` | Session `move-up`, then `with-echo ""` |
| `"down"` | `MoveDown` | `"move-down"` | Session `move-down`, then `with-echo ""` |
| `"line-start"` | `LineStart` | `"line-start"` | Session `line-start`, then `with-echo ""` |
| `"line-end"` | `LineEnd` | `"line-end"` | Session `line-end`, then `with-echo ""` |
| `"page-up"` | `PageUp` | `"page-up"` | Session `page-up`, then `with-echo ""` |
| `"page-down"` | `PageDown` | `"page-down"` | Session `page-down`, then `with-echo ""` |
| `"buffer-start"` | `BufferStart` | `"buffer-start"` | Session `buffer-start`, then `with-echo ""` |
| `"buffer-end"` | `BufferEnd` | `"buffer-end"` | Session `buffer-end`, then `with-echo ""` |
| `"escape"` | `RequestQuit` | `"request-quit"` | Session `request-quit`, then `with-echo ""` |
| `"undo"` | `Undo` | `"undo"` | Session `undo`, then `with-echo ""` |
| `"mark"` | `SetMark` | `"set-mark"` | Session `set-mark`, already clears echo |
| `"kill"` | `Kill` | `"kill"` | Session `kill`, already clears echo |
| `"kill-line"` | `KillLine` | `"kill-line"` | Session `kill-line`, already clears echo |
| `"yank"` | `Yank` | `"yank"` | Session `yank`, already clears echo |
| `"find"` | `Find` | `"find"` | Session `find`; preserve stored echo |
| `"save"` | `Save` | `"save"` | Session `save-key`; saved/failed token |
| Unbound length-one key | `SelfInsert` | `"self-insert"` | Session `insert key`, then `with-echo ""` |

For example, the `MoveLeft` arm sends `((self move-left) with-echo "")`;
the `SelfInsert` arm sends `((self insert key) with-echo "")`. Command
names are metadata. Lookup compares binding keys only.

### 4. Idle dispatch, search, and quit

Replace the key-specific `cond` in session `idle-key` with global map
lookup and Option/binding `case`. A found `Command` runs
`(self execute-command command key)`. The session idle path contains no
key-specific save, kill, motion, find, or prefix arms and never sends
editor `handle-key`.

Lookup precedes the length check. On a miss, run the map's `Some(default)`
through `(self execute-command default key)` only when `(key len) = 1`.
A missing default, empty key, or unknown named key is a no-op except for
echo becoming `""`. A bound one-character key
would take its command before the default; the production table binds no
such key. Plain `"x"`, `"s"`, `"q"`, and space insert. Do not add an idle
safe-cells filter; direct length-one inputs keep existing insert behavior.

Keep `AloemacsSession.handle-key` precedence exactly:

1. Already quit: return the unchanged session before lookup or effects.
2. Active search: send `search-key key`.
3. Otherwise: send `idle-key key`.

`search-key` remains the existing state machine. Search Escape and Return
end/reset search without quitting or inserting; Backspace edits the query;
`"find"` continues search. An accepted safe length-one string appends to
the query. Every other key, including a rejected length-one query input,
ends search and goes through the new `idle-key`. Ending search resets
searching/query/origin/wrapped/failing as today and preserves stored echo
until idle dispatch changes it. Save during search still saves. Idle
Escape requests quit and clears echo; search Escape restores the stored
echo and does not quit.

Every old command keeps its text, point, quit, scroll origins, text-rows,
mark, ring, history, search fields, fs, path, and echo results. Successful
insert/newline/delete/kill/yank add only existing edit frames; undo pops;
set-mark, motion, and echo changes add none. No-op commands retain the
existing no-op decisions, including mark and history preservation.

### 5. Focused tests, written first

Revise the existing `tests/aloemacs/keymap-session.rkt` from the returned
attempt before product edits. Replace positive command `run` sends and
their type expectations with session `execute-command` sends, preserve
substantive behavior assertions, and add the negative command `run` check.
Run the revised file and observe missing behavior fail, then implement.
Use the checked driver and existing rackunit/Fs-double patterns. All
acceptance is without a TTY.

The focused file must prove:

- Loading `file.aloe` without injecting Term or Fs defines the classes and
  constants, creates no host effect, and succeeds in a second fresh driver.
  Inject an Fs double only when constructing sessions.
- Every constructor's exact command name; checked session
  `execute-command`, lookup, binding `key`, and new wrapper/helper types.
  Execution returns the receiver's concrete `(AloemacsSession H)`,
  including with two distinct injected Fs host types. Application lookup
  returns `(Option AloemacsBinding)`. Wrong receivers, command/key
  argument types, and arities are rejected. A command `run` send is
  rejected by the unchanged checker.
- The exact ordered 20 bindings, their command values, and the `Some
  SelfInsert` default. There is no pending field or Ctrl-X binding.
  Ordinary lookup misses return `None` without using the default.
- Independent small maps prove first-match duplicate behavior, pure misses,
  and unchanged source lists. A binding whose key differs from its command
  name still returns that command.
- Every row in requirement 3 reproduces prior idle behavior with
  nontrivial editor, mark, ring, history, viewport, path, and echo fixtures.
  Derive expected values from existing direct editor/session operations
  plus the specified echo/search transition, not from the new dispatcher.
  Compare session/editor fields, mark, ring, and actual history frames as
  well as rendered text. Save cases verify exact written contents through
  the Fs double.
- Successful and no-op insert/newline/delete operations; all six motions
  after a fit and remembered page rows; undo with history and at its bottom;
  set-mark/kill/kill-line/yank, including no mark and an empty ring; find
  retaining both `"saved"` and `"failed"`; both save outcomes; self-insert;
  and empty/unknown named misses. Preserve source values across transitions.
- Representative direct `(session execute-command command key)` results
  equal the corresponding idle dispatch on an idle session. SelfInsert uses its
  supplied key. Direct thin edit/motion wrappers preserve echo while their
  key commands clear it, including at a no-op boundary.
- Quit absorbs edits, save, search, motion, and unknown keys without host
  effects. Active search owns Escape/Return/query/next-match; motion, save,
  undo, and kill keys exit/reset search before the new idle transition.
  Search point motion adds no undo frame. Existing exact frame and
  safe-cells assertions remain green.

Review the source separately: lookup and session `execute-command` must
actually be the idle dispatch authority. Execution is an exhaustive
constructor `case` inside that session method; the command class has only
its naming method. There must be no send to editor `handle-key` in the idle
path and no retained key-string dispatcher hidden by equal test results.
Existing direct editor tests still exercise its unchanged `handle-key`.

## Non-goals

Do not add pending state, `Prefix`, nested maps, Ctrl-X normalization,
prefix/cancel echo, or any 001 tests or behavior. Do not add M-x,
command-name input, minibuffers, configuration, rebinding, find-file,
save-as, buffers, windows, splits, or a mode line. Do not change search
keys, region painting, clipboard, mark rebasing, or edit grouping. Add no
Text method, kernel message, Term/Fs interface row, language amendment,
or global checkpoint.

No inheritance, mutation, macros, implicit Int/Float coercion, delegation,
Mirror, or new special forms. Evaluation remains send; a list's second
element is a literal selector. Perform command transitions exclusively
through `(session execute-command command key)`; commands gain no `run`
method or executable payload. All new application names use `Aloemacs`
or `aloemacs-`; preserve existing names including
`safe-cell-controls`, `UndoFrame`, and `AloemacsSearchScan`. Do not rename
safe-cell-controls or start Boids.

## Verification and completion

From the project root, run in this order:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

Keep `TMPDIR=/tmp` and `-y`, even if an older document omits them.
Do not commit `compiled/`. No wider suite, benchmark, timing gate, or
physical TTY is required for this slice.

An optional interactive check is `racket host/racket/aloemacs-run.rkt
[path]`. Launchers load existing bytecode. If any `.rkt` was edited, run
the tests above or `raco make host/racket/aloemacs-run.rkt bin/aloe` before
launching; `.aloe` edits alone need no rebuild. The automated suite is
the acceptance evidence.

Complete when both test commands pass, `git diff --check` is clean, the
structural review confirms map/session `execute-command` dispatch, all
prior session results and filesystem effects are preserved, and the file
scope is respected.
Report changed files, the observed initial focused failure, final
verification, and the structural review. Stop when green. Human review
precedes the manager writing 001; do not start that checkpoint.
