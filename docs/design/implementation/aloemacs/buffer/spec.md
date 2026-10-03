# aloemacs buffer specification

**Status: Accepted.** aloemacs-buffer 000 and 001 are implemented,
reviewed, and accepted as the completed series. There is no 002.
This file is the complete design input
for the **aloemacs-buffer** checkpoint manager and implementers. They do
not need the charter or the design conversation. After human acceptance,
this file is their design authority. It is application design;
[`SPEC.md`](../../../../../SPEC.md) remains Aloe language law.
The conversation roles and human review boundaries follow
[`docs/workflow.md`](../../../../workflow.md).

A buffer is an immutable value containing an editor and its optional path.
The session stores a nonempty zipper of buffers, with one focused buffer.
All editing, fitting, framing, and saving use that buffer. Two commands
cycle to the next buffer and discard the current buffer in the existing
single window. A direct session send supplies additional buffers from text
already held by a caller; it does no filesystem operation or prompting.

## 1. Series, authority, and review boundaries

The series identity is **aloemacs-buffer**. Work is rooted at
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code remains under
`examples/aloemacs/`; tests remain under `tests/aloemacs/`. This folder
holds design documents and later checkpoints, never the program.

There are exactly two checkpoints, in this order:

| Identity | File | Independently testable result |
|---|---|---|
| **aloemacs-buffer 000** | `checkpoints/000-buffer-value.md` | Buffer value, singleton collection, current-buffer access, constructor migration, and unchanged visit, save, echo, search, and keys. No addition, switching, or buffer killing. |
| **aloemacs-buffer 001** | `checkpoints/001-switch-and-kill-buffer.md` | Buffer addition, zipper movement and removal, command values and execution, and preservation across multiple buffers. No new binding or Term change. |

Numbers are three digits, begin at 000, and are never renumbered. Slugs
are lowercase words separated by hyphens. The manager writes **000 only**,
then stops. After human review of that implementation, a later manager
turn may write 001. Each implementer writes tests first, implements only
the approved checkpoint, runs verification, and stops when green. Do not
combine the two checkpoints or issue them as a batch. This design chooses
no optional bindings, so there is no 002. If either slice cannot fit one
implementer conversation, return the size problem for review.

The implemented Text through Keymap layers are predecessors. In
particular, File supplies visit/save; Echo supplies the last row; Undo and
Kill put history and mark on the editor and the ring on the session;
Search owns active-search input; Viewport supplies stored origins and the
fit-before-frame order; Keymap supplies session `execute-command` and
`C-x C-s`. Neither aloemacs-runner-check 000 nor
aloemacs-safe-cell-controls 000 is a prerequisite. Do not wait for or edit
those checkpoints.

Authority for the preserved seams is:

- [`../README.md`](../README.md) and
  [`../explorations.md`](../explorations.md): layer order, Band 2 item 6,
  and the boundary before the minibuffer and find-file.
- [`../file/spec.md`](../file/spec.md): resolution, eligibility, exact
  file contents, visit, direct save, and host failures.
- [`../echo/spec.md`](../echo/spec.md): tokens, row allocation, clipping,
  ANSI composition, and save outcome lifetime.
- [`../keymap/spec.md`](../keymap/spec.md): command execution, static maps,
  prefix consumption, search precedence, and existing idle commands.
- [`../kill/spec.md`](../kill/spec.md) and
  [`../undo/spec.md`](../undo/spec.md): mark, ring, edit frames, and undo.
- [`../search/spec.md`](../search/spec.md): query, origin, match movement,
  exit/reset, and search echo.
- [`../viewport/spec.md`](../viewport/spec.md): origins and minimal fit.

The implementation starting points are
[`editor.aloe`](../../../../../examples/aloemacs/editor.aloe),
[`file.aloe`](../../../../../examples/aloemacs/file.aloe), and
[`main.aloe`](../../../../../examples/aloemacs/main.aloe).
[`lib/text.aloe`](../../../../../lib/text.aloe) supplies the zipper
pattern only. This spec supersedes predecessor descriptions of a stored
session editor/path and successful visit replacing the whole collection.
It retains their command and filesystem results, including the session
resets on successful visit. The buffer transitions below extend those
results. `SPEC.md` wins on language behavior; do not amend predecessors
to make their old state diagrams current.

## 2. Product, host, and file boundary

The product still draws one buffer in one window as one complete frame
string plus the existing echo row. Startup is one empty untitled buffer,
or the one path visited by the existing runner. `visit` replaces the
current buffer; it never appends. Additional buffers are available through
checked sends in no-TTY tests, without a new runner argument.

The product is checked Aloe. Racket tests use the existing driver,
`rackunit`, filesystem doubles, and, for existing runner regressions,
scripted Term doubles. There is no new dependency, capability, build step,
or module. Keep the two existing loads in `file.aloe`. Declare
`AloemacsBuffer`, then `AloemacsBuffers`, before `AloemacsSession`, after
those loads. Retain the existing relative order of the command, keymap,
binding, search-scan, session, and map declarations. The new classes are
non-generic. Their names do not collide with `safe-cell-controls`,
`UndoFrame`, or existing classes in the shared load environment.

Both checkpoints may edit `examples/aloemacs/file.aloe` and tests under
`tests/aloemacs/` within their layer scopes. Only 000 needs to edit
`examples/aloemacs/main.aloe`. Leave `editor.aloe`,
`host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, host capabilities,
all libraries, language implementation, `SPEC.md`, `CHECKPOINTS.md`, and
predecessor documents untouched. The designer writes this spec and updates
this folder's README status, then stops without checkpoints or code.

Explicit non-goals are the minibuffer, find-file, save-as, typed buffer
selection, `C-x C-f`, `C-x b`, `M-x`, another prefix, windows, splits, a
mode line, a buffer menu, a dirty bit, confirmation before killing,
save-on-kill, a two-file interactive tour, region painting, clipboard,
search-key changes, and a new editor field. No Text method, List index,
kernel message, `Vector`, mutation, inheritance, macros, class methods,
delegation, Mirror, or new special form belongs here. Function objects
still run only through `call`; this design uses ordinary literal sends.

## 3. Layer 000 — the buffer and singleton session

### 3.1 Buffer value and name

Declare `AloemacsBuffer` with exactly these ordered fields:

```aloe
(editor AloemacsEditor)
(path (Option Path))
```

Its constructor is `(AloemacsBuffer new editor path)`. Its generated
`editor` and `path` selectors read those fields. Add these methods:

| Send | Result | Contract |
|---|---|---|
| `(buffer name)` | `String` | For `Some(path)`, exactly `(path text)`; for `None`, exactly `"untitled"`. |
| `(buffer with-editor editor)` | `AloemacsBuffer` | Replace only the editor, preserving the exact optional path. |

The name is derived on demand, with no stored name field. It is the full
stored path spelling, including a relative spelling if a caller supplies
one directly. It is not a basename, resolved again, sanitized, or
uniquified. Two buffers may have the same path or name; multiple untitled
buffers all have the name `"untitled"`. Names are metadata, not buffer
identity or a selector for this series. No lookup by name is added. The
echo continues to derive its label from the path, independently of `name`.

The editor remains exactly the current eight-field value, in this order:
`text`, `point`, `quit`, `scroll-row`, `scroll-col`, `history`, `mark`,
`text-rows`. The buffer does not duplicate any of them. `UndoFrame` remains
`text`, `point`, `scroll-row`, `scroll-col`; its shape does not change.

### 3.2 Buffer collection

Declare `AloemacsBuffers` with exactly these ordered fields:

```aloe
(before (List AloemacsBuffer))
(current-buffer AloemacsBuffer)
(after (List AloemacsBuffer))
```

The constructor is `(AloemacsBuffers new before current-buffer after)`.
`before` holds predecessors nearest first, in reverse logical order;
`after` holds successors nearest first, in forward logical order.
Logical order is `reverse(before)`, then `current-buffer`, then `after`.
That description does not require constructing a joined list. Current is
the zipper focus, not an Int index or a cached editor beside the zipper.
The mandatory middle value makes an empty collection unrepresentable.

In 000 add only
`(buffers with-current-buffer buffer) -> AloemacsBuffers`. It replaces
the middle value and preserves both neighbor lists. The generated
`current-buffer` field selector supplies the current value. Startup,
visit, and all valid session fixtures in 000 use empty neighbor lists.
There is no addition, focus movement, or removal method in 000, and no
multi-buffer behavior to prove at that checkpoint.

The raw constructor is not a validator of buffer names, path eligibility,
or editor point validity. Existing editor/Text preconditions remain.
Every transition preserves logical order except the insertion or removal
explicitly specified in 001. Old buffers and lists remain immutable.

### 3.3 Session shape and access

Replace the sibling editor/path fields of `(AloemacsSession H)` with the
collection. The complete ordered fields, for both checkpoints, are:

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
```

The constructor is
`(AloemacsSession new buffers fs echo searching query origin wrapped failing kill-ring pending)`.
There is no stored session editor, path, buffer name, numeric current
index, second history, or second ring. Preserve the existing session
selectors `editor` and `path` as zero-argument **methods**, and add
`current-buffer`:

| Session send | Result | Source |
|---|---|---|
| `current-buffer` | `AloemacsBuffer` | `(self buffers)`'s `current-buffer`. |
| `editor` | `AloemacsEditor` | `(self current-buffer)`'s editor. |
| `path` | `(Option Path)` | `(self current-buffer)`'s path. |
| `text` | `Text` | The current editor's text. |
| `point` | `Position` | The current editor's point. |
| `quit` | `Bool` | The current editor's quit flag. |

Keeping computed `editor`/`path` selectors preserves existing caller
sends and keeps the ownership migration small. They hold no copy.
All command, search, kill, save, label, and frame paths must obtain the
editor/path through these current-buffer reads.

Session `with-editor` replaces the editor through buffer `with-editor`,
then collection `with-current-buffer`, and rebuilds the session. It
preserves both neighbor lists, the current path/name, fs, echo, all search
fields, ring, and pending. It never rebuilds an unrelated editor.

### 3.4 Lawful startup and constructor migration

Update `main.aloe` to this shape, preserving its existing empty cold Text:

```aloe
(load "file.aloe")

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
    (if #t (Option None) (Option Some aloemacs-global-keymap))))
```

The unselected `Some` branches supply the concrete types of empty mark,
path, and pending. Do not put bare `(Option None)` at untyped construction
sites, including an untitled buffer fixture. A method whose expected
constructor field type supplies `T` may construct `None` directly.
Store cleared Options in rebuilt constructors; do not add Option-taking
setters or change the checker/evaluator. Loading main still needs an
explicit `fs-host` and no Term, and performs no filesystem operation.

Checkpoint 000 migrates **every** valid untyped `AloemacsSession new`
site: wrap its old editor/path in a singleton collection and remove the
old session path argument. Search the product and tests again instead of
treating this inventory as exhaustive:

- Product: all session rebuilds in `file.aloe` and startup in `main.aloe`.
- Test constructors/rebuilds: `echo-session.rkt`, `file-session.rkt`,
  `kill-session.rkt`, `motion-editor.rkt`, `runner.rkt`, `safe-cells.rkt`,
  `search-session.rkt`, `undo-session.rkt`, `viewport-editor.rkt`,
  `visited-unchanged.rkt`, `keymap-session.rkt`, and `keymap-prefix.rkt`.
- Exact main/source expectations and surface negatives: `runner.rkt`,
  `file-runner.rkt`, and session API tests. In particular, `buffers` is
  now a valid session send; remove its old unknown-selector negative and
  assert its new type. Update exact stored-field inventories to §3.3.

Keep intentional old-arity negatives as negatives. Other type-negative
fixtures must use the new shape so they still test their original mistake.
Expected session reconstructions in dispatch tests must independently
wrap the expected editor/path; do not replace those expectations with
the new dispatcher. Editor-only constructors and assertions stay as
they are. Preserve all substantive keys, search, mark, ring, history,
viewport, file-effect, and exact-frame assertions.

### 3.5 Existing rebuilds, visit, and save

Every reconstruction threads the collection. The preservation rules are:

| Operation | Collection change | Other session fields |
|---|---|---|
| `with-editor`, direct edit/motion/undo/quit wrappers, `ensure-visible` | Replace only current editor by the existing editor result. | Preserve all. |
| `with-kill-state(editor, ring)` | Replace only current editor. | Use the supplied ring and echo `""`; preserve fs, search, pending. |
| `with-search(editor, searching, query, origin, wrapped, failing)` | Replace only current editor. | Use supplied search fields; preserve fs, echo, ring, pending. |
| `with-echo` | Preserve all buffers and focus. | Replace only echo. |
| `with-prefix`, `clear-prefix` | Preserve all buffers and focus. | Keep their existing pending/echo rules; preserve the rest. |
| `unchanged`, direct successful `save` | Preserve all buffers and focus. | Preserve all. |
| Successful `visited`/`visit` | Replace only current buffer with fresh editor and `Some(resolved-path)`. | Preserve fs; reset echo/search/ring/pending as below. |

`visit(path) -> Option (AloemacsSession H)` still resolves through the
session Fs, inspects without following symlinks, and reads only a regular
file. Missing succeeds with empty text bound to the resolved path and
creates no file. A directory, symlink, other node, or a read returning
`None` yields `None`; its source session is unchanged. Host failures still
raise. `visit` never inserts into or reorders the collection.

A successful visit uses indexed Text from the loaded contents, point
`(0,0)`, quit `#f`, both origins zero, empty history, no mark, and
`text-rows = 0`, matching today's `visited`. Replace the current path with
`Some(resolved-path)`, from which the new name follows. Set echo `""`,
searching `#f`, query `""`, origin `(0,0)`, wrapped/failing `#f`, ring
empty, and pending `None`. Resetting the session ring is the existing
visit behavior, even after 001 provides neighbors. Other buffers retain
every payload. A refused visit resets nothing.

`save() -> Option (AloemacsSession H)` uses the current buffer's path and
exact current `(text to-string)`. Untitled returns `None` without writing.
A bound `Fs.write None` returns `None`; a successful write returns `Some`
of an equal session. Direct save preserves echo/search/pending and every
buffer. Each successful explicit save still writes even without an edit.
Host failures still raise. There is no implicit save on visit, switch,
kill, or quit. Strict UTF-8 and CR/LF, BOM, and final-newline preservation
remain the File contract.

Existing command execution and keymaps retain their results. Successful
edits push exactly the frames their existing editor methods push; motion,
search, mark, fit, save, and echo clearing add none. Undo pops only the
current editor's history and retains its current mark and `text-rows`.
The ring remains on the session. No new mark rebasing or validation is
added to self-insert, motion, or undo.

### 3.6 Frame and echo

`ensure-visible(columns, rows)` fits only the current editor with
`rows - 1` text rows when `rows >= 2`, otherwise the existing one-row
fallback. It writes that editor back through `with-editor`. `frame`
reads the current editor's stored origins and appends the existing echo
suffix. It is pure and does not fit. Positive dimensions, right clipping,
safe-cell rendering, blank padding, final text-cursor placement, and one
string per Term write retain their contracts.

The echo vocabulary does not grow:

| Event/state | Token or displayed row |
|---|---|
| Idle commands other than `Find`/`Save`, and later switch/kill | Token `""`. |
| `Find` | Retain token; active search displays its search row. |
| Ctrl-S or `C-x C-s` | Token `"saved"` or `"failed"`. |
| Idle token | Current path's exact text, or `untitled`. |
| Saved/failed token | `saved: ` / `failed: ` plus that current label. |
| Active search | Existing `search: `, `wrapped: `, or `failing: ` row. |

The echo row never uses a cached path or a unique buffer name. At one row
the same transitions work and no echo suffix is drawn. The runner keeps
its argv, `aloemacs-editor` binding, fit-then-frame sequence, and
`(aloemacs-editor quit)` send. It stops on the current editor's quit flag.
No runner change belongs to either checkpoint.

### 3.7 Layer 000 proof

Add `tests/aloemacs/buffer-value.rkt` before product edits. Prove checked
class fields, constructor arities/types, derived names for path/untitled,
computed session accessors, singleton structure, and immutable buffer and
current-editor replacement. Reject wrong editor/path/collection argument
types. Loading `file.aloe` in a fresh checked driver must define the new
classes without requiring injected Fs or Term or causing host effects.
Construct sessions with an injected Fs double when testing their sends.

Prove startup, successful existing/missing-path visit defaults, refused
visit preservation, untitled and bound save outcomes, and current-buffer
rebuilds with nontrivial history, mark, origin, remembered rows, ring,
echo, search, and pending fixtures. Keep the migrated existing suite's
single-buffer results and complete ANSI goldens. Direct save and key save
retain their different echo contracts. Prefix survives ordinary rebuilds,
fit, and frame; `C-x C-s` still matches Ctrl-S. No test or production send
adds, switches, or kills a second buffer in 000.

## 4. Layer 001 — multiple buffers and two commands

### 4.1 Zipper operations and edges

Extend `AloemacsBuffers` with these sends:

| Send | Result | Rule |
|---|---|---|
| `focus-next` | `AloemacsBuffers` | Select the next buffer in logical order, wrapping last to first. |
| `focus-previous` | `AloemacsBuffers` | Select the previous buffer, wrapping first to last. |
| `insert-after(buffer : AloemacsBuffer)` | `AloemacsBuffers` | Insert immediately after current in logical order and make the inserted buffer current. |
| `remove-current` | `AloemacsBuffers` | Discard current; prefer a following neighbor, otherwise a preceding neighbor, otherwise a fresh untitled buffer. |

`current-buffer` is the generated field selector from 000. The movement
selectors return a new **collection**, not an Option or just a buffer.
Let `B` be the reversed before list, `C` current, and `A` after:

- Next with nonempty `A`: new before is `B cons C`, current is `A first`,
  and after is `A rest`. With no `A`, reverse `B cons C`; its first is
  the new current and its rest is after, with empty before.
- Previous with nonempty `B`: before is `B rest`, current is `B first`,
  and after is `A cons C`. With no `B`, reverse `A cons C`; its first
  is current and its rest is before, with empty after.
- Insert after: before is `B cons C`, current is the inserted buffer,
  and after is `A`.
- Remove with nonempty `A`: keep `B`, select `A first`, keep `A rest`.
  With empty `A` and nonempty `B`: keep `B rest`, select `B first`, and
  keep empty after. With both lists empty, use a singleton fresh buffer.

Guard every `first`/`rest` by a proven nonempty list. On a singleton,
either focus send preserves the entire buffer and collection. Adjacent
movement, insertion, and removal use the existing list head operations;
wrapping uses one reversal of the buffers in order. Do not add a list
index, cached count, materialized second collection, or Text operation.

For logical order `[A, B, C]`, next cycles `A → B → C → A` and previous
cycles in reverse. Killing B selects C and leaves `[A, C]`; killing C
selects B and leaves `[A, B]`; killing A selects B and leaves `[B, C]`.
Killing the singleton replaces its contents and path, rather than leaving
the old buffer or quitting.

The fresh fallback buffer, and every buffer created by the addition send,
have indexed Text from their supplied contents, point `(0,0)`, quit `#f`,
origins `(0,0)`, empty history, no mark, and `text-rows = 0`. Fallback
contents are `""`, path is `None`, and name is `"untitled"`. It reads and
writes no file. Surviving buffers keep their exact editor/path values;
no movement or removal adds a history frame, clears a surviving mark,
fits a viewport, or changes a surviving editor's quit flag.

### 4.2 One addition selector with an optional path

Add the session selector **`add-buffer`** with two ordinary overloads:

| Send | Meaning |
|---|---|
| `(session add-buffer contents)` | `contents : String`; fresh untitled buffer. |
| `(session add-buffer contents path)` | `contents : String`, `path : Path`; fresh buffer bound to exactly this path. |

Both return `(AloemacsSession H)`. Optionality is expressed by the absent
second argument, under the existing method-arity rules. The caller's
already held `(Option Path)` can be consumed lawfully as follows:

```aloe
(known-path case
  (None () (session add-buffer "second"))
  (Some (path) (session add-buffer "second" path)))
```

Do not declare a concrete `(Option Path)` argument to `add-buffer`.
Although the `if` form gives an absent Option its checked type, its runtime
type argument can remain unknown and it cannot match that parameter,
as with the existing Kill spec's `with-mark` limitation. The two arities
avoid that dispatch seam without a new input class or language change.
The untitled overload constructs the absent path directly in the new
buffer's constructor; the bound overload stores `Some(path)`. Sending a
String or Option in place of the optional `Path` is a type error.

Construct the fresh editor described in §4.1, insert its buffer through
`insert-after`, and select it. The old current buffer becomes its immediate
predecessor; other buffers keep their order. For example, adding D while
B is current in `[A, B, C]` yields `[A, B, D, C]` with D current.
Neither overload resolves, inspects, reads, writes, rejects, or deduplicates
a path. A supplied relative path is stored unchanged; only `visit`
guarantees a resolved stored path. Duplicate paths and names are accepted.
This is an ordinary send, with no command constructor, prompt, new runner
argument, or find-file behavior. It pushes no undo frame anywhere.

### 4.3 Session switch/kill and selection state

Add zero-argument session methods:

| Send | Collection result |
|---|---|
| `(session switch-buffer)` | Send collection `focus-next`. |
| `(session kill-buffer)` | Send collection `remove-current`. |

Both return `(AloemacsSession H)`. `switch-buffer` always means cycle
forward; it reads no name or key string. The previous-focus selector is
available on the collection for its algebra and tests, with no additional
session command in this series.

All three selection operations — add, switch, kill — first end any active
search, accepting the current search point. They never restore `origin`
or run a search against another buffer. They then perform the collection
transition and return this exact session state:

| Field | Result |
|---|---|
| `buffers` | The operation's collection result. |
| `fs`, `kill-ring` | Preserve receiver's exact values. |
| `echo` | `""`. |
| `searching`, `wrapped`, `failing` | `#f`. |
| `query` | `""`. |
| `origin` | `(Position new 0 0)`. |
| `pending` | `None`. |

These resets also apply when switch has only one buffer, and when inactive
search fields have nondefault fixture values. Thus a pending prefix and an
origin never travel across a selection boundary. The preserved departing
editor keeps its search-result point, history, mark, scroll, and remembered
rows. Killing discards that editor and its history. Killing the only buffer
keeps the session Fs and ring while creating the fresh untitled fallback.
It does not save or request quit.

Direct selection sends perform these transitions just like other direct
session helpers. `execute-command` does not gain a general quit guard.
`handle-key` retains its existing absorbing guard on the current editor's
quit flag before search and keymap dispatch. Surviving editors' quit flags
are never rewritten; `quit` reports the selected editor's exact flag.
Ordinary live collections use live editors, and singleton kill always
creates one with quit `#f`.

Switch and kill do not fit. The runner's next `ensure-visible` fits only
the newly current editor before framing. A frame without a new fit reads
that buffer's stored scroll, as before. A round trip without fitting or
editing preserves every field of both editors. A fit after switching may
change the selected buffer's origins and remembered row count according
to Viewport/Motion; it does not alter any other buffer.

### 4.4 Command values, dispatch, and unchanged bindings

Append these zero-field constructors to the existing `AloemacsCommand`
after its current constructors, and extend its exhaustive `name` case:

| Constructor | Exact `name` | `execute-command` action |
|---|---|---|
| `SwitchBuffer` | `"switch-buffer"` | Send session `switch-buffer`. |
| `KillBuffer` | `"kill-buffer"` | Send session `kill-buffer`. |

`Kill` remains the region command with name `"kill"`. The command class
now has 23 constructors, and still only its naming method. Extend the
existing constructor case inside session `execute-command`; execution
belongs there, using the receiver's concrete Fs host type. Only
`SelfInsert` uses the supplied key string. The new arms ignore it, including
when it has length one, and use the selection methods' clearing/reset
rules. Do not dispatch by name, add command execution methods, or add any
editor `handle-key` arm.

No production binding is added. Tests can perform the commands as ordinary
sends, for example:

```aloe
(session execute-command (AloemacsCommand SwitchBuffer) "")
(session execute-command (AloemacsCommand KillBuffer) "")
```

The global map retains its exact 20 command bindings followed by its one
`ctrl-x` prefix and its `Some SelfInsert` default. The existing C-x map
still contains only the `save` binding and a `None` default. Ctrl-S and
`C-x C-s` still use the same save value. A pending miss still cancels and
consumes the key with no global retry. Plain x still inserts. There is no
new Term chord or synthetic production binding for the command names;
idle unknown strings `"switch-buffer"` and `"kill-buffer"` remain map
misses. No second prefix is installed.

Search still runs ahead of key lookup: printable query input, Backspace,
Find, Escape, Return, and forwarding of other keys retain their existing
rules. A direct switch/kill command during search performs §4.3. A
test-only existing-map binding to such a command follows ordinary search
exit/idle dispatch and prefix consumption, without new `search-key`
arms. Entering search after selection captures the newly current point.

### 4.5 Layer 001 proof

Add `tests/aloemacs/buffer-collection.rkt` and
`tests/aloemacs/buffer-session.rkt` before product edits. Extend
`buffer-value.rkt` and `keymap-session.rkt` where their method/command
inventory gains these interfaces. No constructor shape changes in 001.
Use checked sends, Fs doubles with counted effects, and distinct editors
with nontrivial state; no physical TTY or production files are needed.

The collection tests prove logical order and exact focus for next and
previous, both wrap edges, singleton movement, insertion at the first,
middle, and last focus, each neighbor choice on removal, singleton
fallback, and repeated removal never yielding an empty collection.
Exercise three buffers as well as two, so insertion order and the fallback
to the preceding neighbor cannot be hidden by a two-buffer cycle. Compare
complete buffer values and both list orders, not just names. Duplicate
paths/names and equal-valued buffers must not cause deduplication or
removal of the wrong position. Old collection values remain unchanged.

The session tests must prove:

- Both `add-buffer` arities and all new method/command types and names,
  plus wrong receivers, argument types, and arities. Addition stores
  supplied text/path exactly, creates the §4.1 defaults, becomes current
  immediately after the old focus, and causes zero Fs calls. Execute the
  §4.2 caller-side case with both an absent and a present optional path.
- Switch, kill, and direct `execute-command` produce the same specified
  selections and resets. Singleton switch preserves its entire buffer;
  singleton kill discards text, bound path, history, mark, and scroll for
  the fresh untitled editor, preserves the ring, and neither quits nor
  writes. Repeated kill continues to leave a current buffer.
- Point, exact Text including its focus, history, mark, both origins,
  remembered rows, and path/name survive a switch round trip. Edits and
  undo affect only the current editor. Switch/kill/add push no frame, and
  surviving histories are unchanged by another buffer's removal.
- Kill text in one buffer, switch, yank into the other, and undo there.
  The one session ring remains newest first and is not consumed by yank
  or undo. Killing the source buffer leaves its ring entry usable. Mark
  stays with its editor; existing post-kill/yank validity rules still
  apply only where they already applied.
- Save with two different bound paths writes only the current path's
  exact contents. Switching changes the next save target; another buffer's
  text, point, history, and path remain untouched. Include untitled
  failure, an ineligible bound path, and two buffers sharing a path: save
  overwrites the file from current text without replacing the other
  buffer's in-memory value. Test direct save, Ctrl-S, and `C-x C-s`.
- Successful existing/missing-path visit replaces only the current slot,
  retains neighbors/order, and performs the §3.5 session resets. Refused
  visit preserves the whole source, including all buffers and pending.
- A switch or kill while search has a nonzero origin accepts the old
  point and clears all search fields before another buffer is selected.
  Use a shorter destination where the old origin would be invalid. Test
  singleton switch, addition during search, and subsequent Find capturing
  the new point. No search move or selection operation adds history.
- Saved and failed echo tokens become `""` after selection; the frame
  shows the newly current path or untitled. Compare complete clipped,
  safe-cell ANSI frames and cursor placement, including a one-row frame.
  Framing without fitting reads the stored origin; subsequent fitting
  changes only current according to the existing minimal rule.
- Pending clears on direct addition/switch/kill, even singleton switch.
  A test-only pending map may bind a key to either new command to prove
  the existing lookup/consume/execute path. Production maps and defaults
  remain exactly as specified. All old prefix cancellation and search
  precedence tests stay green, and already quit sessions absorb keys
  before lookup or effects.

Do not weaken existing behavior or frame assertions to pass these tests.
Review the source to confirm the collection is the sole store and the
new command arms are inside session `execute-command`. Behavioral equality
alone cannot prove that no sibling editor/path was retained.

## 5. Verification and acceptance

From the project root, each implementer writes the focused tests first,
observes the missing behavior fail, implements the assigned slice, runs
its verification, and stops. Use `TMPDIR=/tmp` and `-y` on every agent
`raco test` command, even where an older predecessor omits them.

For **aloemacs-buffer 000**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/buffer-value.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

For **aloemacs-buffer 001**:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/buffer-value.rkt tests/aloemacs/buffer-collection.rkt tests/aloemacs/buffer-session.rkt tests/aloemacs/keymap-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

The aloemacs suite is the required regression bar. A checkpoint may name
wider tests only for a concrete dependency; no benchmark or timing gate
is added. Do not commit `compiled/`. No hand check is required. The
existing optional launch is `racket host/racket/aloemacs-run.rkt [path]`;
its argv still accepts zero or one path. After a `.rkt` edit, first run the
test command or `raco make host/racket/aloemacs-run.rkt bin/aloe`; these
launchers load existing bytecode and do not rebuild it. `.aloe` edits
need no rebuild. Opening two files interactively belongs to find-file.

The completed series is accepted when all of these are true:

1. A singleton session retains today's idle keys, search, quit, visit,
   save, Ctrl-S, and `C-x C-s` results, including editor state, ring,
   pending behavior, echo tokens, exact frame bytes, and written contents.
2. Buffer owns the only editor/path pair; session owns the only collection
   and Fs/echo/search/ring/pending state. Every read and current-editor
   rebuild follows the focus, with no sibling editor/path storage.
3. Checked no-TTY sends create and exercise multiple buffers without a
   prompt, filesystem read, Term chord, runner edit, or new argv. Switching
   frames the other buffer and its label; killing always leaves a current
   buffer and does not save or request quit.
4. Point, history, mark, and scroll remain per buffer. Edits and undo act
   on current; the session's one ring supports yank after switching and
   after removal of the buffer that supplied a kill.
5. New commands are named zero-field values executed through session
   `execute-command`. Existing maps, prefix consumption, self-insert,
   active-search precedence, and editor key handling retain their scope.
6. Selection ends search before another editor can use its origin and
   clears echo/pending by §4.3. The runner still fits then frames only
   current and stops on that editor's quit flag.
7. Both focused layers and `TMPDIR=/tmp raco test -y tests/aloemacs` pass,
   with no later feature, language change, or global checkpoint added.

The specification is accepted for checkpoint work. The checkpoint manager
writes **aloemacs-buffer 000 only**, then stops.
