# aloemacs keymap specification

**Status: Accepted revision.** Execution belongs to the session, which
cases on a named command value. This file is the complete design input
for the checkpoint manager and implementers. aloemacs-keymap 000 and 001
are implemented, reviewed, and accepted as the completed series. There is
no checker prerequisite.
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law.

The one-buffer session dispatches idle keys through immutable keymap data.
A successful lookup yields a named command value. The ordinary send
`(session execute-command command key)` performs its transition and returns
a session. The first new binding is `C-x C-s`: the global `C-x` binding
holds a nested map whose only binding runs the same save command as Ctrl-S.

## 1. Series, predecessors, and authority

The identity is **aloemacs-keymap**. There are exactly two checkpoints,
in this order:

| Identity | File | Independent result |
|---|---|---|
| **aloemacs-keymap 000** | `checkpoints/000-session-keymap.md` | Command values and the session keymap reproduce all existing idle keys. No pending field, prefix binding, or Term edit. |
| **aloemacs-keymap 001** | `checkpoints/001-prefix-and-ctrl-x.md` | Pending-map state, the nested `C-x` binding, `C-x C-s`, consumed cancellation, and plain Ctrl-X normalization. |

Numbers are three digits, start at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. The checkpoint manager writes
**000 only**, then stops. After human review of its implementation, a later
manager turn may write 001. Each implementer adds tests first, completes
only the assigned checkpoint, runs verification, and stops when green.
Do not combine these checkpoints or issue them as a batch. If either cannot
fit one implementer conversation, return the size problem for review.

The implemented Text through Motion layers are predecessors. In particular,
Loop provides absorbing editor key handling; File provides visit/save and
the session; Echo provides the saved/failed token; Search owns active search
keys and idle fall-through; Undo provides edit history; Kill provides mark,
kill, kill-line, yank, and the ring; Motion provides six motions and the
remembered text-row count. The safe-cell-controls cleanup is **not** a
predecessor. Do not wait for it or edit its checkpoint.

The authority for preserved command behavior is:

- [`../README.md`](../README.md): the one-buffer application and layer order.
- [`../file/spec.md`](../file/spec.md): path binding, visit, direct save,
  exact file contents, and filesystem effects.
- [`../echo/spec.md`](../echo/spec.md): echo tokens, fit, frame composition,
  and save outcome lifetime, as subsequently extended by Search.
- [`../search/spec.md`](../search/spec.md): search input, point motion,
  exit/reset, and preservation of the stored idle echo.
- [`../kill/spec.md`](../kill/spec.md): mark, ring, kill, kill-line, yank,
  mark validity, and edit history.
- [`../undo/spec.md`](../undo/spec.md): successful edit frames and undo,
  with current mark and text-rows preservation from Kill and Motion.
- [`../motion/checkpoints/000-motion-pack.md`](../motion/checkpoints/000-motion-pack.md):
  the six motions and remembered page distance; no motion spec exists.

The implementation starting points are
[`editor.aloe`](../../../../../examples/aloemacs/editor.aloe),
[`file.aloe`](../../../../../examples/aloemacs/file.aloe),
[`main.aloe`](../../../../../examples/aloemacs/main.aloe),
[`term.rkt`](../../../../../host/racket/term.rkt), and
[`kill-key-mapping.rkt`](../../../../../tests/aloemacs/kill-key-mapping.rkt).
This spec supersedes predecessor descriptions of idle `cond` dispatch
only. Their command results remain in force. `SPEC.md` wins on sends,
constructors, types, and immutability. After human acceptance, this file is
the design authority for both checkpoints; the charter is the designer's
assignment only.

## 2. Product boundary, host, and layout

Work is rooted at
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Product code remains
checked Aloe in `examples/aloemacs/`; Term normalization is Racket in
`host/racket/term.rkt`. Tests use the checked driver, rackunit, filesystem
and scripted Term doubles under `tests/aloemacs/`. The design folder holds
this spec and later checkpoint documents, never program code.

The editor retains text, point, quit, both viewport origins, undo history,
mark, and text-rows. Its constructor does not grow. The session retains
the filesystem capability, path, echo token, search state, and kill-ring.
001 adds one pending-map field. There is no second history or buffer.
Page commands read the text-row count already remembered by editor
`ensure-visible`; session `execute-command` takes no columns or rows.
The runner's fit-before-frame order, one frame string, and one Term write
stay unchanged.

This series excludes M-x and command-name input; the minibuffer; find-file,
save-as, switch-buffer, extra buffers, windows, splits, and a mode line;
any additional prefix or binding such as `C-x C-f`, `C-x b`, or `C-x u`;
prefix/cancel echo tokens; rebinding Ctrl-S; changes to search keys, region
painting, clipboard, mark rebasing, or edit grouping; mutable maps,
configuration loading, Mirror, command execution through `call`,
class-side methods, delegation, inheritance, macros, or new special forms.
It adds no Text method, kernel message, Term/Fs interface row, `SPEC.md`
amendment, `CHECKPOINTS.md` entry, or global checkpoint. The frame and
`safe-cells` stay unchanged. Do not rename `safe-cell-controls` or start
Boids.

All new application names use `Aloemacs` or `aloemacs-` prefixes. The shared
load environment must retain every existing name, including
`safe-cell-controls`, `UndoFrame`, and `AloemacsSearchScan`, without a clash.
There is no new load cycle, capability, package, or build dependency.

## 3. Layer 000 — named commands and the idle table

### 3.1 Command values

Declare **`AloemacsCommand`**, a non-generic immutable class with the
zero-payload constructors in the table in §3.5. Each constructor denotes
one command. `(command name) -> String` returns that row's exact name.
The name is supplied by an exhaustive `case` on the command; it is not
an arbitrary string accepted by a `new` constructor. This gives each
command a fixed name without a second string-to-command router or a
command registry.

The command contains no filesystem host or executable payload. Its only
instance method is `name`; it has no `run` method or method-level type
parameter.

Declare this instance method inside the existing generic fields class
`(AloemacsSession H)`:

```aloe
(execute-command (command AloemacsCommand) (key String) (AloemacsSession H)
  ...)
```

Perform a command as `(session execute-command command key)`. `H` is the
receiver's class parameter, not a method-local parameter or another
argument. Case exhaustively on `command` itself, covering all 21
constructors in §3.5. Each arm sends ordinary literal selectors to `self`,
using the session helpers in §3.4 and the transitions in §3.5. Do not case
on command-name strings, send a computed selector, use a function payload,
use `call`, or invoke Mirror. Only the `SelfInsert` arm uses `key`, by
sending `(self insert key)`; the other arms ignore it.

`execute-command` carries out the command transition, including its echo
result, and returns `(AloemacsSession H)`. It does no key lookup or length
check. Key event routing, quit absorption, active-search precedence, and
prefix consumption belong to session key handling. Existing direct
session sends retain their separate semantics; a direct `save` still
returns `Option`.

Execution must stay on the session because its generic fields-class bodies
are checked at a concrete receiver. The rejected command-owned execution
method introduced a rigid method-local `H` on a non-generic constructor
class. Its `Save` arm reached session save, `Fs.write`, and host `kind`,
which is available only for the concrete injected host. The session method
uses that concrete host in the same way today's `save` does. Do not add a
command execution method, make commands generic, or change `aloe/type.rkt`
or `SPEC.md` to accommodate dispatch.

### 3.2 Keymap, binding, and lookup result

Declare **`AloemacsKeymap`** with one type parameter for its binding type:

```aloe
(define-class (AloemacsKeymap B)
  (fields
    (bindings (List B))
    (default (Option AloemacsCommand)))
  (methods
    (lookup (key String) (Option B) ...)
    (lookup-in (bindings (List B)) (key String) (Option B) ...)))
```

In this application, `B` is always `AloemacsBinding`. The parameter permits
declaring the map before the binding that will contain a nested map; it
does not introduce a protocol, a reusable library, or another application
binding type. Constructor order is `bindings`, then `default`.

Declare **`AloemacsBinding`** with this one constructor in 000:

```aloe
(define-class AloemacsBinding
  (constructors
    (Command (fields (key String) (command AloemacsCommand))))
  (methods
    (key () String ...)))
```

`(binding key)` obtains the string through an exhaustive binding `case`.
001 adds the `Prefix` constructor in §4.1 to this same class. The existing
`Command` payload and `AloemacsCommand` class remain unchanged.

The **lookup result** is the existing **`(Option AloemacsBinding)`** when
the application map is used. `None` means miss; `Some(binding)` carries
the command or, in 001, the nested map. No extra result class is needed.

`(map lookup key)` scans `bindings` in list order, comparing whole strings
by `=`. The first equal key wins, including when keys are duplicated.
`lookup-in` performs that scan over the remaining list. A miss returns
`None`. Lookup is pure: it neither runs the command nor consults `default`,
searches a nested map, edits the session, or changes the list. Only session
dispatch decides whether a default may run.

### 3.3 Definitions and the global map

Keep these declarations and values in `examples/aloemacs/file.aloe`,
which already loads `editor.aloe` and `lib/fs.aloe`. Do not add a keymap
module or load `file.aloe` back from another application file.

Use this declaration order to avoid forward type references:

1. `AloemacsCommand`, with its constructors and `name` method.
2. `(AloemacsKeymap B)`, with its fields and lookup methods.
3. `AloemacsBinding`, with its constructor(s) and `key` method.
4. The existing `AloemacsSearchScan` and `(AloemacsSession H)` declarations,
   including `execute-command`, the session helpers, and idle dispatch.
5. The command constants and maps below, before `file.aloe` finishes loading.

The command declaration is complete at step 1; no later `define-methods`
extension of `AloemacsCommand` is needed or permitted. The session remains
the existing generic fields class; its idle method uses the completed
top-level map when invoked after loading. All load/typecheck and runtime
send tests must use the existing checker unchanged.

Define these immutable top-level values:

| Name | Value |
|---|---|
| `aloemacs-self-insert-command` | `(AloemacsCommand SelfInsert)` |
| `aloemacs-save-command` | `(AloemacsCommand Save)` |
| `aloemacs-global-keymap` | `(AloemacsKeymap new bindings default)` with exactly the 20 explicit §3.5 bindings in that order, and `default = (Option Some aloemacs-self-insert-command)` |

Other command values may be constructed directly in their table bindings.
Use `aloemacs-save-command` for the global save binding and, in 001, for
the nested save binding. The map is static data and is **not** a session
field. No session constructor changes in 000.

### 3.4 Session helpers and retained editor handling

Keep existing session `insert`, `newline`, `backward-delete`, the four
`move-*` methods, and `request-quit` as thin `with-editor` wrappers. Add the
same zero-argument wrapper for `line-start`, `line-end`, `page-up`,
`page-down`, `buffer-start`, `buffer-end`, and `undo`. Each sends the
same selector to the editor and returns `(AloemacsSession H)` through
`with-editor`. Direct wrappers preserve echo, search, ring, and, after 001,
pending state. They add no history of their own.

Add these session helpers:

| Selector | Contract |
|---|---|
| `with-echo(token : String)` | Return `(AloemacsSession H)` with only the echo field replaced. Preserve every other field. |
| `find()` | Return `(AloemacsSession H)` by the existing `with-search` transition: current editor, searching `#t`, query `""`, origin current point, wrapped/failing `#f`. Preserve the stored echo. |
| `save-key()` | Send direct `save` exactly once. On `Some(session)`, rebuild that returned session with echo `"saved"`; on `None`, rebuild the receiver with echo `"failed"`. Preserve every other field. Return `(AloemacsSession H)`. |

`save-key` moves the existing save-outcome behavior out of `idle-key`.
Untitled or ineligible `Fs.write None` produces `"failed"`. A raised host
failure still raises; it does not become a returned failed session. Direct
`save` keeps its existing Option result and preserves all field payloads
on success. Save still writes exact `(text to-string)` on each bound
success and never pushes an undo frame.

Keep `AloemacsEditor.handle-key` **unchanged** for direct editor callers
and tests, with its current named arms, self-insert, and quit guard.
The session's idle path never sends that method. It uses `execute-command`,
including for self-insert, so all application idle bindings are in the
session map. No `"ctrl-x"` arm is added to the editor. Editor methods
remain `AloemacsEditor -> AloemacsEditor`.

### 3.5 Normative bindings and command transitions

Each explicit row constructs
`(AloemacsBinding Command key command)`. The command column gives its
zero-payload constructor selector; `name` returns the next column.

| Key | Command constructor | Name | Session `execute-command` transition |
|---|---|---|---|
| `"return"` | `Newline` | `"newline"` | Session `newline`, then echo `""` |
| `"backspace"` | `BackwardDelete` | `"backward-delete"` | Session `backward-delete`, then echo `""` |
| `"left"` | `MoveLeft` | `"move-left"` | Session `move-left`, then echo `""` |
| `"right"` | `MoveRight` | `"move-right"` | Session `move-right`, then echo `""` |
| `"up"` | `MoveUp` | `"move-up"` | Session `move-up`, then echo `""` |
| `"down"` | `MoveDown` | `"move-down"` | Session `move-down`, then echo `""` |
| `"line-start"` | `LineStart` | `"line-start"` | Session `line-start`, then echo `""` |
| `"line-end"` | `LineEnd` | `"line-end"` | Session `line-end`, then echo `""` |
| `"page-up"` | `PageUp` | `"page-up"` | Session `page-up`, then echo `""` |
| `"page-down"` | `PageDown` | `"page-down"` | Session `page-down`, then echo `""` |
| `"buffer-start"` | `BufferStart` | `"buffer-start"` | Session `buffer-start`, then echo `""` |
| `"buffer-end"` | `BufferEnd` | `"buffer-end"` | Session `buffer-end`, then echo `""` |
| `"escape"` | `RequestQuit` | `"request-quit"` | Session `request-quit`, then echo `""` |
| `"undo"` | `Undo` | `"undo"` | Session `undo`, then echo `""` |
| `"mark"` | `SetMark` | `"set-mark"` | Session `set-mark`, echo `""` |
| `"kill"` | `Kill` | `"kill"` | Session `kill`, echo `""` |
| `"kill-line"` | `KillLine` | `"kill-line"` | Session `kill-line`, echo `""` |
| `"yank"` | `Yank` | `"yank"` | Session `yank`, echo `""` |
| `"find"` | `Find` | `"find"` | Session `find`; preserve echo |
| `"save"` | `Save` | `"save"` | Session `save-key`; echo `"saved"` or `"failed"` |
| No binding, key length 1 | `SelfInsert` | `"self-insert"` | Session `insert key`, then echo `""` |

For example, the `MoveLeft` arm sends `((self move-left) with-echo "")`;
the `SelfInsert` arm sends `((self insert key) with-echo "")`. Mark/kill
methods already clear echo through `with-kill-state`. Those methods and
their successful/no-op edit decisions are unchanged.

There are 21 command constructors, 20 explicit bindings, and one default
command. Lookup precedes the length check, so a bound one-character key
would run its command. The production map binds no one-character key.
On a miss, run the global map's `Some(default)` only if `(key len) = 1`.
Otherwise preserve all fields except setting echo to `""`. This includes
the empty key and all unknown named keys. A missing default also produces
that cleared no-op. Plain `"x"`, `"s"`, `"q"`, and space still insert.
Do not introduce an idle safe-cells filter: direct length-one key strings
retain the editor's existing insert behavior.

Replace `idle-key`'s key-specific `cond` with lookup, Option/binding
`case`, and this default/miss rule. It runs a found command as
`(self execute-command command key)`. An eligible default uses the same
session method. There are no save, kill, motion, find, or prefix
string arms in session idle dispatch. The command name is metadata;
lookup compares binding keys and never compares command names.

Text, point, quit, both origins, remembered rows, mark, ring, history,
search fields, fs, path, and echo must match the old idle dispatch.
Successful insert/newline/delete/kill/yank push only the frames their
existing methods push. Undo pops, set-mark and motion push nothing, and
clearing echo creates no frame. Ordinary edits keep today's mark policy;
do not add kill-style mark validation to self-insert or undo.

### 3.6 Search and quit precedence

`AloemacsSession.handle-key` keeps this order in both checkpoints:

1. Already quit: return the unchanged session before any lookup or effect.
2. Active search: send `search-key key`.
3. Otherwise: send `idle-key key` for map dispatch.

`search-key` remains the existing state machine. Escape and Return end
search without quitting or inserting. Backspace edits the query; `"find"`
continues search. A length-one string that survives the existing
`safe-cells` equality test appends to the query. Every other key ends
search, then goes through `idle-key`; this includes a rejected length-one
query character. Ending search resets searching/query/origin/wrapped/
failing as today and preserves the stored echo until idle dispatch changes
it. Ctrl-S during search therefore still saves. In 001, `"ctrl-x"` during
search ends search, then installs the pending map.

An idle Escape requests quit and clears echo. Active-search Escape restores
the stored echo and does not quit. Escape while a prefix is pending is the
consumed cancellation in §4.3. No new search-key arm is required.

### 3.7 File scope and tests for 000

Product edits are confined to `examples/aloemacs/file.aloe`. Do not edit
`editor.aloe`, `main.aloe`, `term.rkt`, the runner, libraries, or language
files. Existing `tests/aloemacs/` assertions may gain the new session
method/type checks where appropriate; they retain their substantive
results and need no constructor threading in 000.

Revise the existing `tests/aloemacs/keymap-session.rkt` from the returned
attempt before product edits. Replace its command-owned execution
expectations with session `execute-command` sends; preserve its substantive
behavior assertions. It must prove:

- Loading `file.aloe` in a checked driver defines the classes and constants
  without Term or Fs injection, creates no host effect, and succeeds again
  in a fresh driver. Inject an Fs double only when constructing sessions.
- Every command's exact name, the checked session `execute-command`
  signature, the application lookup type `(Option AloemacsBinding)`, and
  the new wrapper/helper types. Execution returns the receiver's concrete
  `(AloemacsSession H)`, including with two distinct injected Fs host types.
  Wrong receivers, command/key argument types, and arities are rejected.
  A command `run` send is rejected by the unchanged checker.
- The global table contains exactly the 20 keys in order, with the correct
  command values, and a `Some SelfInsert` default. 000 has no prefix field
  or `"ctrl-x"` binding. Ordinary lookup does not apply the default.
- Independent small maps prove first-match duplicate handling and misses
  without changing their source lists. A binding key different from its
  command's name still looks up that command correctly.
- All §3.5 idle keys, without any new binding installed, return the same
  session field values as the previous behavior. Use nontrivial editor,
  mark, ring, history, viewport, path, and echo fixtures. Expected results
  come from existing direct editor/session operations plus the specified
  echo/search transition, rather than from the new dispatcher itself.
  Fs save cases use a double and verify the written text.
- Exercise successful and no-op edits, all six motions after a fit,
  remembered page rows, undo with history and at its bottom, mark/kill/
  kill-line/yank including empty ring and no mark, find retaining both
  `"saved"` and `"failed"`, both save outcomes, self-insert, and empty and
  unknown named misses. Compare mark, ring, and frames as well as text.
- For representative commands, direct
  `(session execute-command command key)` equals the corresponding idle-key
  result on an idle session. Self-insert uses its supplied key. Thin direct
  edit/motion wrappers still preserve echo,
  while their key commands clear it, including at a no-op boundary.
- Quit absorbs edit, save, search, motion, and unknown keys without effects.
  Active search owns Escape/Return/query/next-match; a motion, save, undo,
  or kill key exits search then takes the new idle path. Search motion
  adds no undo frame. Existing frame bytes and safe-cells tests stay green.

Review the idle path to confirm its dispatch authority is the map and no
send to editor `handle-key` remains there. Command execution is the
exhaustive constructor `case` inside session `execute-command`; the command
class has only its naming method. This structural review complements the
result comparisons; equal behavior alone could hide retained string
dispatch. Existing direct editor tests continue to prove the retained method.

## 4. Layer 001 — one pending map and Ctrl-X

### 4.1 Nested binding and static maps

Add exactly this constructor to `AloemacsBinding` after `Command`:

```aloe
(Prefix
  (fields
    (key String)
    (map (AloemacsKeymap AloemacsBinding))))
```

Extend `binding.key` to cover it. The lookup result type stays
`(Option AloemacsBinding)`. A `Prefix` binding's value is a nested keymap
object; it is not a command name, function, or string instruction.

Define `aloemacs-ctrl-x-keymap` before `aloemacs-global-keymap`. It contains
exactly one binding:
`(AloemacsBinding Command "save" aloemacs-save-command)`. Its `default`
is `None`; for this untyped generic constructor, spell that argument:

```aloe
(if #t
    (Option None)
    (Option Some aloemacs-self-insert-command))
```

Append one global binding after the existing 20:
`(AloemacsBinding Prefix "ctrl-x" aloemacs-ctrl-x-keymap)`.
The global default remains `Some SelfInsert`. No other binding changes.
Ctrl-S and `C-x C-s` use the same `aloemacs-save-command` value.
Neither map is stored as a new global-map session field.

### 4.2 Session state and constructor inventory

Append this field after `kill-ring`:

```aloe
(pending (Option (AloemacsKeymap AloemacsBinding)))
```

The complete ordered session fields after 001 are:

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
(pending (Option (AloemacsKeymap AloemacsBinding)))
```

The constructor is
`(AloemacsSession new editor fs path echo searching query origin wrapped failing kill-ring pending)`.
A fresh session and every successful visit hold `None`. A rejected visit
retains its unchanged source, including pending state.

Add session `with-prefix(map : (AloemacsKeymap AloemacsBinding))`, which
stores `Some(map)`, sets echo to `""`, preserves all other fields, and
returns `(AloemacsSession H)`. Add zero-argument `clear-prefix()`, which
stores `None`, preserves every other field including echo, and returns
the same session type. Do not add a setter taking `Option`; write the
cleared Option directly into the rebuilt constructor in `clear-prefix`.

Every `AloemacsSession new` introduced or retained by 000 gains the final
argument. The product inventory is:

| Site | Pending argument |
|---|---|
| `file.aloe`: `with-editor` | Receiver's pending |
| `file.aloe`: `with-kill-state` | Receiver's pending |
| `file.aloe`: `with-search` | Receiver's pending |
| `file.aloe`: `with-echo` | Receiver's pending |
| `file.aloe`: `save-key`, `None` branch | Receiver's pending |
| `file.aloe`: `save-key`, `Some(session)` branch | Returned session's pending |
| `file.aloe`: `visited` | None, resetting prefix along with the other visit defaults |
| `main.aloe`: initial `aloemacs-editor` | None |
| `file.aloe`: new `with-prefix` | `(Option Some map)` |
| `file.aloe`: new `clear-prefix` | None |

If `save-key` uses `with-echo` for its two branches, those branches have
no separate constructor; they inherit the corresponding preservation
through that helper. The old `idle-key` fallback constructor has moved
to `with-echo`. The old save-outcome constructors belong to `save-key`.
Direct `save` uses `unchanged` and introduces no construction site.

At untyped sites, notably `main.aloe` and direct test fixtures, use this
inferable empty pending value:

```aloe
(if #t
    (Option None)
    (Option Some aloemacs-global-keymap))
```

The unselected branch supplies the concrete map type. A bare `(Option None)`
there is rejected under `SPEC.md` §9. A method's expected constructor field
type may supply that argument directly. Preserve the existing lawful None
spellings for path and mark; do not change the checker or use Mirror to
construct an empty Option.

Update valid session fixtures in `tests/aloemacs/echo-session.rkt`,
`file-session.rkt`, `kill-session.rkt`, `motion-editor.rkt`, `runner.rkt`,
`safe-cells.rkt`, `search-session.rkt`, `undo-session.rkt`,
`viewport-editor.rkt`, `visited-unchanged.rkt`, and the new keymap tests.
Search all `AloemacsSession new` occurrences again rather than treating this
inventory as exhaustive. Intentional old-arity negatives may remain errors;
other negative tests must still test their original field/type mistake.
Source-shape assertions in runner tests are not constructor sites.

Ordinary direct editor wrappers, `with-editor`, search helpers, kill
helpers, fitting, framing, and direct save preserve pending. Successful
visit resets it. Rendering and fitting must retain the armed prefix across
the runner iteration before the next key; no resize or redraw cancels it.

### 4.3 Dispatch and consumed cancellation

Quit and active search still precede idle dispatch (§3.6). On the idle path,
choose the map from `pending` and use the following table. Lookup is exactly
one send to the selected map; a miss is never retried in the global map.

| Pending before key | Lookup result | Session transition |
|---|---|---|
| None | `Some Command(key, command)` | `(self execute-command command key)`; pending stays None. |
| None | `Some Prefix(key, map)` | `with-prefix map`; clear echo, no edit. |
| None | None | Apply the global length-one default/miss rule in §3.5; pending stays None. |
| Some(map) | `Some Command(key, command)` | Clear pending **before** execution: `((self clear-prefix) execute-command command key)`. |
| Some(map) | `Some Prefix(key, next-map)` | Replace pending through `with-prefix next-map`; clear echo, no edit. |
| Some(map) | None | Clear pending and set echo to `""`; preserve every other field. Consume the key. |

The generic Prefix-to-Prefix transition is defined by the value shape, but
this series installs no such chain and no additional prefix. Pending lookup
ignores both the global map and any selected map's default.

`"ctrl-x"` followed by `"save"` runs `Save` after clearing pending and
therefore produces `"saved"` or `"failed"` by precisely the Ctrl-S rule.
Installing and cancelling a prefix do not write, edit, move point, set or
clear mark, touch the ring, push/pop history, or alter search fields. The
only new session field is pending. The same preservation holds when a
command boundary is a no-op. Old session and map values remain immutable.

Every other key after `"ctrl-x"` cancels, including `"x"`, `"s"`,
`"left"`, `"escape"`, `"find"`, `"undo"`, `"return"`, `"mark"`,
an unknown name, the empty string, and another `"ctrl-x"`. That key is
consumed: no insertion, global command, quit, search entry, or re-arming.
The next key then uses the global map normally. In particular, two
successive Escapes after Ctrl-X cancel then quit.

The echo vocabulary remains exactly the path/untitled row, `saved:`/
`failed:` plus the path, and existing search rows. Installing a prefix
clears a prior saved/failed token; cancelling leaves the empty token.
There is no `C-x-` prompt or cancellation label. `find` still retains the
stored token; Save still replaces it with its outcome. Frame and safe-cells
do not inspect pending.

### 4.4 Term chord

In `host/racket/term.rkt`, add one plain Ctrl-X clause before both printable
character branches of `tkeymsg->aloe-key`, matching Ctrl-S's predicate shape:

| tkeymsg key | mods | char | Aloe key |
|---|---|---|---|
| `#\x` | exactly `'(ctrl)` | `#f` | `"ctrl-x"` |
| `#\x` | exactly `'(ctrl)` | `#\x` | `"ctrl-x"` |

A small `plain-ctrl-x-key?` predicate parallel to `plain-ctrl-s-key?` may
name this guard. `(make-tkeymsg #\x)` remains `"x"`. With mods `(ctrl shift)` or `(alt)`,
and char `#f` or `#\x`, the printable result is also `"x"`. A mismatched
printable decoded character retains the current character-first result;
it is not accepted as Ctrl-X. Return, Backspace, arrows, motion keys,
Escape, Ctrl-S, Ctrl-F, Ctrl-Z, and kill chords keep their current mappings.
The new key string is longer than one character, differs from every §3.5
key, and cannot become self-insert. Term gains no message or prefix state.

### 4.5 File scope and tests for 001

Product edits are confined to `examples/aloemacs/file.aloe`,
`examples/aloemacs/main.aloe`, and `host/racket/term.rkt`. Existing tests
under `tests/aloemacs/` may change only for pending construction/type
checks and consequences specified here. Preserve their prior assertions.
`editor.aloe`, `host/racket/aloemacs-run.rkt`, libraries, language files,
and predecessor specs/checkpoints stay untouched.

Add tests before product edits:

- `tests/aloemacs/keymap-session.rkt`: extend 000's tests for the Prefix
  payload/type, exact new global/nested bindings and defaults, the shared
  save command value, initial pending None, ordinary rebuild preservation,
  and successful existing/missing-file visits resetting pending while a
  rejected visit preserves the source. Exercise a pending `ensure-visible`
  and frame before the second key, and direct save preserving pending.
- `tests/aloemacs/keymap-prefix.rkt`: armed state changes only pending/echo;
  C-x then save clears pending, writes exact contents, and produces the same
  session payloads and echo frame as plain save. Use success, untitled
  failure, and ineligible bound-path failure. Count writes so the prefix
  writes zero and the save key writes once. Test every cancellation example
  in §4.3 with nontrivial mark/ring/history/origin fixtures; compare all
  preserved fields, ensure zero writes, and verify the following key acts
  globally. No cancel inserts, moves, enters search, quits, undoes, or
  re-arms. Active search still owns its keys; Ctrl-X during search resets
  search before arming, then save works. Already quit sessions absorb
  Ctrl-X and save. A test-only nested binding may prove replacement of an
  already pending map without adding a production chain or binding.
- `tests/aloemacs/keymap-key-mapping.rkt`: both plain Ctrl-X shapes,
  printable x, Ctrl-Shift-X/Alt-X with both char variants, mismatched char,
  and representative existing control/motion/special keys. Call the
  converter directly without a TTY.
- `tests/aloemacs/keymap-runner.rkt`: scripted Term and Fs doubles drive
  plain x, `"ctrl-x"`, `"save"`, cancellation, and quit through the existing
  runner. Save writes the expected text; the frame after prefix or cancel
  shows only the path, the frame after save shows `saved:`, and the next
  ordinary key clears it. One write per frame, fit-before-frame, key-read
  counts, and stop-on-quit retain their existing contracts. The redraw
  between the two prefix keys must preserve pending.

Exact echo frames must retain clipping, text-row allocation, safe-cell
rendering, and final text-cursor placement. Include a one-row session,
where prefix/save/cancel still work without an echo suffix. No test or
acceptance condition depends on a physical TTY.

## 5. Verification and acceptance

Run tests from the project root with `TMPDIR=/tmp` and `-y`. Write the focused
tests first, observe the missing behavior fail, implement the assigned
checkpoint, then run its verification:

For **aloemacs-keymap 000**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-keymap 001**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/keymap-session.rkt tests/aloemacs/keymap-prefix.rkt tests/aloemacs/keymap-key-mapping.rkt tests/aloemacs/keymap-runner.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

These are application and Term-converter changes; a wider suite is needed
only if a checkpoint names a concrete additional dependency. No timing gate
or benchmark is added. Do not commit `compiled/`.

An optional interactive check is
`racket host/racket/aloemacs-run.rkt [path]`. After a `.rkt` edit, first run
the tests above or `raco make host/racket/aloemacs-run.rkt bin/aloe`; the
runner loads existing bytecode and does not rebuild it. `.aloe` edits need
no rebuild. A TTY check may confirm the visible save result, but the no-TTY
suite is the acceptance evidence.

The completed series is accepted when:

1. All original idle keys have their specified field results, echo tokens,
   and filesystem effects through the command table; the default alone
   self-inserts unbound length-one strings.
2. Ordinary map `lookup` and session `execute-command` sends control idle
   dispatch. The session cases on the command value and returns a session;
   commands remain named values with no execution method. Thin motion
   wrappers preserve the editor boundary, and no session idle key goes
   through editor `handle-key`.
3. Ctrl-S and `C-x C-s` run the same save command with the same saved/failed
   result, exact contents, and history. Plain x still inserts.
4. Every other key after C-x cancels once and is consumed, preserving
   text, point, mark, ring, history, search fields, and viewport state;
   prefix installation, redraw, and cancellation add no undo frame.
5. Quit absorption and active-search precedence remain ahead of map
   dispatch, including search exit before Ctrl-X arms the prefix.
6. The echo vocabulary, frame, safe-cells, editor constructor, Text,
   language law, capabilities, and runner stay within the unchanged
   boundaries above, and the required no-TTY tests pass.

The implemented 000 and 001 have been reviewed against their checkpoints
and accepted by the user as the completed series. The manager stops.
