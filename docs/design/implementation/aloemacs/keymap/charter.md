# Charter — aloemacs keymap

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **commands as named
values and a keymap as data** on the one buffer. The series
identity is **aloemacs-keymap**. The session is the keymap's
receiver. Today's idle keys move into that table, and the first
new binding is `C-x C-s`. Then **stop**. Do not write
checkpoints. Do not implement.

This effort refuses M-x, the minibuffer, extra buffers,
find-file, save-as, switch-buffer, windows, and any prefix other
than the one `C-x` map. It also refuses the safe-cell-controls
cleanup. Those stay later, or in their own checkpoint, so this
spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-keymap 000** under
   `docs/design/implementation/aloemacs/keymap/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the two checkpoints in §4.8. An M-x dispatcher,
a prompt line, a second buffer, or a new `cond` arm for `C-x` on
the editor are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../loop/`](../loop/) | `AloemacsEditor.handle-key` returns an editor. Quit is absorbing |
| [`../file/`](../file/) | `AloemacsSession.handle-key`, visit, and save. Ctrl-S is `"save"` |
| [`../echo/`](../echo/) | The last row shows the path, or `saved:` / `failed:` plus the path |
| [`../search/`](../search/) | An active search handles its own keys, then falls through to idle |
| [`../undo/`](../undo/) | Successful edits cons one `UndoFrame`. Ctrl-Z is `"undo"` |
| [`../kill/`](../kill/) | Idle `"mark"`, `"kill"`, `"kill-line"`, and `"yank"` |
| [`../motion/`](../motion/) | Six editor motions. The session has no arms for them |
| Term | `tkeymsg->aloe-key` already names the idle chords |

Layers 1–12 are implemented. aloemacs-safe-cell-controls 000 is
**not** a predecessor. This series does not wait for it and does
not edit that checkpoint.

**Why this layer:** idle dispatch is two `cond`s. The editor's
`handle-key` is fourteen named arms plus self-insert. The
session's `idle-key` adds mark, kill, kill-line, yank, find, and
save, and sends every other key to the editor. The next feature
needs a table those clauses can move into. `C-x C-s` is the first
binding that table makes easy.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Idle keys keep today's results.** Text, point, quit, mark,
   kill-ring, undo history, search flags, and the echo token
   match the current session for every key in §4.2. A no-TTY
   test can show that without a new binding present.
2. **Dispatch is the keymap.** The session looks the key up in
   the map, then cases on that command value inside a session
   method. `C-x C-s` is a binding in a nested map. It is not a
   new arm of `AloemacsEditor.handle-key`.
3. **The session is the receiver of the keymap.** The session
   method that performs a command returns a session. Editor
   methods stay `Editor → Editor`. Point motion goes through a
   thin session wrapper.
4. **`C-x C-s` saves, and Ctrl-S still saves.** The same save
   result, including `saved:` / `failed:` on the echo row. A
   plain `x` still inserts. `C-x` followed by any other key
   cancels: that key is consumed, and the buffer does not
   change.
5. **The echo vocabulary does not grow.** The row is still the
   path, `saved:` / `failed:`, or the search row. Cancel adds
   no token.
6. **Search and quit stay ahead of the map.** An active search
   still owns its keys. A quit session still ignores the key.
7. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

## 4. Locked decisions (record these; do not reopen 4.1–4.8)

### 4.1 The session owns the keymap

`AloemacsSession` is the receiver that turns a key into a
command. The editor keeps text, point, quit, the viewport, undo
history, the mark, and the six motion methods. The session keeps
the path, the echo token, search, the kill-ring, and, in
checkpoint 001, the pending prefix.

A command is an object with a name. The keymap points at that
value. The session performs it by casing on the command inside
a session method, then sending the session selectors in §4.2.
That method returns a session. Self-insert still receives the
key string; the other commands ignore it. The command has no
`run` method and no method-level type parameter. It does not
use `call`. It does not use Mirror.

`(command run session key)` with method-level `H` cannot
typecheck, and a checker change is not the prerequisite.
`AloemacsCommand` is a non-generic constructor class, so the
checker typechecks `run` at the definition while `H` is still a
rigid parameter. `Save` reaches `save-key`, then `Fs.write`,
then host `kind`. That message exists only when `H` is the
injected host. `AloemacsSession` is a generic fields class, so
its bodies are checked later, at a concrete session, which is
why `save` typechecks there today. Keep the transition on the
session. Do not edit `aloe/type.rkt` or `SPEC.md` for this
series.

A keymap is an object. Lookup is an ordinary send to that map.
A binding's value is a command or a nested keymap. Checkpoint
000 uses command values only. The spec chooses a binding shape
that checkpoint 001 can extend with a nested keymap without
replacing the command object.

The global map's default is the self-insert command. It runs
only when lookup misses and the key's length is 1. A longer
miss leaves the editor unchanged and sets the echo token to
`""`.

The editor constructor does not grow. `handle-key` on the
editor is not the extension point. The open question in §5 is
only whether that method remains for editor tests.

The session method that performs a command does not take
columns or rows. Page motion still reads the row count
remembered by `ensure-visible`.

### 4.2 Today's keys are the first consumer

These are the idle bindings. The name is the string the command
carries. The key is the Aloe string the map matches.

| Key | Command name | Result the session already has |
|---|---|---|
| `"return"` | `newline` | Editor newline. Echo token `""` |
| `"backspace"` | `backward-delete` | Editor backward-delete. Echo token `""` |
| `"left"` | `move-left` | Editor move-left. Echo token `""` |
| `"right"` | `move-right` | Editor move-right. Echo token `""` |
| `"up"` | `move-up` | Editor move-up. Echo token `""` |
| `"down"` | `move-down` | Editor move-down. Echo token `""` |
| `"line-start"` | `line-start` | Editor line-start. Echo token `""` |
| `"line-end"` | `line-end` | Editor line-end. Echo token `""` |
| `"page-up"` | `page-up` | Editor page-up. Echo token `""` |
| `"page-down"` | `page-down` | Editor page-down. Echo token `""` |
| `"buffer-start"` | `buffer-start` | Editor buffer-start. Echo token `""` |
| `"buffer-end"` | `buffer-end` | Editor buffer-end. Echo token `""` |
| `"escape"` | `request-quit` | Editor request-quit. Echo token `""` |
| `"undo"` | `undo` | Editor undo. Echo token `""` |
| `"mark"` | `set-mark` | Session set-mark. Echo token `""` |
| `"kill"` | `kill` | Session kill. Echo token `""` |
| `"kill-line"` | `kill-line` | Session kill-line. Echo token `""` |
| `"yank"` | `yank` | Session yank. Echo token `""` |
| `"find"` | `find` | Enter search as today. Echo token stays |
| `"save"` | `save` | Save as today. Echo token `"saved"` or `"failed"` |
| length 1, no binding | `self-insert` | Editor insert of that key. Echo token `""` |

`"find"` keeps the echo token because `with-search` keeps it.
The search row hides it, and ending the search shows it again.
The other rows set `""` on purpose. The session already has
`insert`, `newline`, `backward-delete`, the four `move-*`
wrappers, and `request-quit`, and those go through `with-editor`,
which preserves the token. Idle dispatch today does not use
those wrappers. The spec keeps the echo column above.

Line-start, line-end, page-up, page-down, buffer-start,
buffer-end, and undo have editor methods and no session methods
yet. The spec adds the thin wrappers.

Mark, kill, kill-line, yank, find, and save keep the behavior in
the kill, search, echo, and file specs. Motion keeps the
behavior in the motion checkpoint. Undo still pushes only where
those specs already push. Set-mark still pushes nothing. A
search move still pushes nothing.

### 4.3 Search and quit stay in front

`AloemacsSession.handle-key` still returns unchanged when the
session has quit. It still sends an active search to
`search-key`. The keymap runs only on the idle path.

`search-key` stays the search state machine: Escape and Return
end the search, backspace edits the query, `"find"` finds the
next match, and a length-1 key that survives `safe-cells`
appends to the query. Any other key ends the search and then
takes the idle path. Ctrl-S during a search therefore still
saves. The prefix key during a search ends the search and then
arms the prefix.

`"escape"` on the idle path still quits. `"escape"` as the key
after `C-x` is §4.4, and it does not quit.

### 4.4 One prefix: `C-x`, then `C-s`

Checkpoint 001 adds one nested map and one slot of session
state: the prefix the session is holding, or none. A fresh
session and a successful visit hold none.

When nothing is pending, lookup uses the global map.

- A command binding runs that command and leaves the slot empty.
- A keymap binding stores that map in the slot, sets the echo
  token to `""`, and does not edit. This is what the `C-x` key
  does.
- A length-1 miss runs `self-insert`.
- A longer miss leaves the editor unchanged and sets the echo
  token to `""`.

When a map is pending, lookup uses that map and ignores the
global map.

- A command binding runs it and clears the slot. `C-x` then
  `"save"` runs the same save command as idle `"save"`.
- A keymap binding replaces the slot with that map. This series
  binds no such chain.
- A miss clears the slot, leaves the buffer, point, mark, ring,
  undo history, and search flags alone, and leaves the echo
  token `""`. The key is not inserted, and it is not looked up
  again. `C-x` then `"x"`, `"left"`, `"escape"`, or `"find"`
  all cancel.

The only new global binding is the `C-x` key, and its value is
the nested map. That map's only binding is `"save"` → the save
command. Ctrl-S is still the global `"save"` binding. Both run
the same save behavior.

Installing the prefix pushes no undo frame. Cancel pushes none.

### 4.5 The Term chord

Checkpoint 001 decodes plain Ctrl-X to the Aloe string §5
chooses. The predicate matches the Ctrl-S shape: key `#\x`, mods
exactly `'(ctrl)`, and char either `#f` or `#\x`. The clause
stands before the printable-character branches.

These stay printable `"x"`:

- `(make-tkeymsg #\x)`
- mods `(ctrl shift)`, char `#f` or `#\x`
- mods `(alt)`

The string itself is longer than one character, so it is not
self-insert. It is not `"x"`, `"save"`, or any string already
in §4.2.

### 4.6 What this series leaves alone

One buffer. The frame, safe cells, and the echo vocabulary stay.
`Text` gains no method. `SPEC.md` gains no row. The kernel gains
no message. Class methods, delegation, and Mirror stay parked.

`editor.aloe` and `file.aloe` share a load environment. A new
top-level name must not clash with `safe-cell-controls` or with
the classes already defined there. This series does not rename
that literal and does not change `safe-cells`.

Untyped `AloemacsSession new` still cannot take a bare
`(Option None)`. When a new field is an Option, the spec uses
the lawful `if` form already required at untyped sites, and a
method whose expected type supplies `T` may write `(Option None)`
directly. Do not change the type checker.

### 4.7 Echo, in one place

| Event | Echo token |
|---|---|
| Any §4.2 command except `find` and `save` | `""` |
| `find` | unchanged; the search row takes the screen |
| `save`, from Ctrl-S or from `C-x C-s` | `"saved"` or `"failed"` |
| The key that installs the `C-x` map | `""` |
| Cancel | stays `""` |

### 4.8 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-keymap 000** | Named command objects and a session keymap that reproduces §4.2. No pending prefix, no `C-x` binding, no Term change |
| **aloemacs-keymap 001** | The pending slot, the nested `C-x` map, `C-x C-s`, cancel, and the Term chord in §4.5 |

000 is testable with the keys the editor already has. 001 is
testable once 000 is green. The manager writes 000 only, then
stops. Do not collapse them into one checkpoint: the table has
to exist before the prefix is a binding in it.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **Class shape.** Name the command class, the keymap class,
   the binding, and the lookup result. Name the session
   selector that cases on a command and performs it. Ordinary
   sends only. A list scanned in order is enough for this many
   bindings. The command class has no `run` method.
2. **The Aloe string for the `C-x` key.** It meets §4.5.
3. **`AloemacsEditor.handle-key`.** Keep it or remove it. If it
   stays, it is only the editor's existing arms for direct
   editor tests. The session's idle path does not send it for
   a key the map binds, and `C-x` is not an arm on it.
4. **Where the global map lives.** A top-level value or a
   session field. The pending prefix is session state either
   way. Name every `AloemacsSession new` that grows when the
   pending field appears, including `main.aloe`.

## 6. Authority

- [`../README.md`](../README.md) — one buffer; this layer is
  the keymap
- [`../file/spec.md`](../file/spec.md) — session `handle-key`
  and save
- [`../echo/spec.md`](../echo/spec.md) — echo tokens and the
  last row
- [`../search/spec.md`](../search/spec.md) — search keys and
  the idle fall-through
- [`../kill/spec.md`](../kill/spec.md) — mark, kill, kill-line,
  yank, the ring, and undo
- [`../undo/spec.md`](../undo/spec.md) — which edits push an
  `UndoFrame`
- [`../motion/checkpoints/000-motion-pack.md`](../motion/checkpoints/000-motion-pack.md)
  — the six motions; there is no motion `spec.md`
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — `handle-key`, the motion methods, `undo`
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — session fields, `idle-key`, `search-key`, `with-editor`
- [`examples/aloemacs/main.aloe`](../../../../../examples/aloemacs/main.aloe)
  — the lawful `(Option None)` spelling
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — `tkeymsg->aloe-key` and `plain-ctrl-s-key?`
- [`tests/aloemacs/kill-key-mapping.rkt`](../../../../../tests/aloemacs/kill-key-mapping.rkt)
  — the neighbor pattern for a plain Ctrl letter
- [`SPEC.md`](../../../../../SPEC.md) §9 — bare `(Option None)`
  is rejected; the `if` form is the golden

`SPEC.md` remains language law. This series does not amend it.
The accepted layer specs remain the authority for what those
commands do. This charter is the authority for dispatch. Where
a layer spec describes today's `cond`, the keymap spec replaces
that dispatch and leaves the command's result alone. After the
human accepts `spec.md`, that file is the design authority for
the checkpoint manager and the implementers.

## 7. Non-goals

- M-x, or a prompt that reads a command name
- The minibuffer, find-file, save-as, switch-buffer, or a second buffer
- Windows, splits, or a mode line
- A prefix other than the one `C-x` map, including `C-x C-f` and `C-x b`
- An echo token for the prefix or for cancel
- Rebinding Ctrl-S away from save
- Painting the region, a host clipboard, or a change to search keys
- A kernel message, a `SPEC.md` row, a `Text` method, or class methods
- Mirror, `call` as the way a command runs, or a mutable map
- The safe-cell-controls rename
- A `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-keymap`.
- Checkpoint 000 is spoken **aloemacs-keymap 000** and filed as
  `checkpoints/000-session-keymap.md`. Checkpoint 001 is spoken
  **aloemacs-keymap 001** and filed as
  `checkpoints/001-prefix-and-ctrl-x.md`. Numbers are three
  digits, start at 000, and are never renumbered. The slug is
  lowercase words separated by hyphens. The checkpoint manager
  writes one checkpoint, then stops.
- Intended order: §4.8. 000 first.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/` and, for 001,
  `host/racket/term.rkt`. Tests stay in `tests/aloemacs/`.
  The design folder receives `spec.md` and later checkpoints,
  not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
