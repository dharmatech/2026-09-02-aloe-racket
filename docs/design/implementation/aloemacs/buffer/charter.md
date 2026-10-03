# Charter — aloemacs buffer

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **a buffer as a value**.
The series identity is **aloemacs-buffer**. A buffer holds the
editor and the optional path. The session holds the collection and
knows which buffer is current. Switch and kill-buffer run in the
one window that already exists. Then **stop**. Do not write
checkpoints. Do not implement.

This effort refuses the minibuffer, find-file, save-as, a typed
switch-buffer, `C-x C-f`, `C-x b`, `M-x`, windows, a buffer menu,
and a prompt that asks before killing. Those stay later series, so
this spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-buffer 000** under
   `docs/design/implementation/aloemacs/buffer/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the two checkpoints in §4.9. A prompt, a second
window, a buffer menu, or a path field left on the session beside
the buffer are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../file/`](../file/) | `AloemacsSession` visits and saves one path. `visit` replaces that buffer. Untitled save fails |
| [`../echo/`](../echo/) | The last row shows the path, `untitled`, or `saved:` / `failed:` plus that label |
| [`../undo/`](../undo/) | Undo history lives on the editor. Successful edits cons one `UndoFrame` |
| [`../kill/`](../kill/) | The mark lives on the editor. The kill-ring lives on the session |
| [`../search/`](../search/) | Search state lives on the session and stays ahead of the keymap |
| [`../viewport/`](../viewport/) | `scroll-row` and `scroll-col` live on the editor. The runner fits, then frames |
| [`../keymap/`](../keymap/) | `execute-command` cases on `AloemacsCommand`. `C-x C-s` saves. Ctrl-S still saves |

Layers 1–13 are implemented. aloemacs-runner-check 000 and
aloemacs-safe-cell-controls 000 are **not** predecessors. This
series does not wait for them and does not edit those checkpoints.

**Why this layer:** the session stores one `AloemacsEditor` and one
`(Option Path)` as siblings. Text, point, undo, mark, and scroll
already travel with the editor. The path does not. The next
commands need one value that carries the editor and the path, and a
session that can hold more than one of those values. Find-file and
the minibuffer are uses of that value. They are not this series.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **One buffer still behaves.** With a single buffer, every idle
   key, search, quit, visit, save, and `C-x C-s` keeps today's
   text, point, quit flag, mark, kill-ring, undo history, search
   flags, echo token, and written file.
2. **The buffer is the store.** The session has no editor field and
   no path field beside the collection. Frame, save, echo label,
   and edit commands all read the current buffer.
3. **Two buffers are testable with no TTY.** A test can build a
   second buffer without a prompt and without a new runner
   argument. Switch shows the other text. The echo label is that
   buffer's path, or `untitled`. Kill leaves a current buffer.
   Save writes the current buffer's path and leaves the other
   buffer's text alone.
4. **What belongs to a buffer survives a switch.** Point, undo
   history, mark, and scroll of the buffer you leave are still
   there when you switch back. The kill-ring is the session's one
   ring, so yank after a switch inserts into the buffer that is
   now current.
5. **Switch and kill-buffer are commands.** They are constructors
   of the existing `AloemacsCommand` class, performed by
   `execute-command`. They are not arms of
   `AloemacsEditor.handle-key`.
6. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

A hands-on tour that opens two files is the find-file series. This
bar is the no-TTY test.

## 4. Locked decisions (record these; do not reopen 4.1–4.9)

### 4.1 A buffer holds the editor and the path

A buffer is a new immutable value. It holds one `AloemacsEditor`
and one `(Option Path)`. The editor keeps text, point, quit, both
scroll origins, undo history, the mark, and `text-rows`. The
editor constructor does not grow. `editor.aloe` does not gain a
buffer type.

The session keeps the filesystem capability, the echo token, the
search flags and query and origin, the kill-ring, and the pending
keymap. It drops the sibling editor field and the sibling path
field. The collection is the only copy of the editors. Current is
a position in that collection, not a second editor stored beside
it.

`text`, `point`, and `quit` keep their session meanings by reading
the current buffer's editor. `save` writes that buffer's text to
that buffer's path. The echo label reads that path, or
`untitled`, under the echo spec. `with-editor` writes the new
editor back into the current buffer and leaves every other buffer
alone.

The class name starts with `Aloemacs`. It is not
`AloemacsEditor` or `AloemacsSession`. The spec chooses the name
and the selectors.

### 4.2 The session always has a current buffer

Startup is still one buffer: empty and untitled in `main.aloe`, or
the file the runner visits. `visit` still replaces the current
buffer. A missing file still becomes an empty buffer bound to that
path. A directory, symlink, or other non-file still yields
`None`. `visit` does not append a buffer.

The runner's argv shape, fit-then-frame order, and
`(aloemacs-editor quit)` stay. This series does not edit
`host/racket/aloemacs-run.rkt`. Quit remains the flag on the
current buffer's editor. The runner still stops when that flag is
true.

Kill-buffer never leaves the collection empty. Killing the only
buffer does not quit and does not write a file. Switch on a
one-buffer session leaves that buffer's text and point in place.
§5 chooses the rest of those two results.

### 4.3 Edits, undo, mark, and scroll stay with the buffer

An edit command changes the current buffer's editor and pushes
undo only where the undo, kill, and search specs already push.
Switch pushes no undo frame. Kill-buffer pushes none on the
buffers that remain. The discarded buffer's history disappears
with it.

The mark stays on that buffer's editor. Switching away does not
clear it. The kill-ring stays one list on the session, newest
first. Yank inserts the front string into the current buffer.

Scroll stays on the editor. Switch does not fit. The next
`ensure-visible`, which the runner already sends before the next
frame, fits whichever buffer is current. A test that frames
without fitting sees the scroll stored on that buffer.

### 4.4 Search stays on the session

Search flags, query, and origin stay session fields. Search still
runs ahead of the keymap. An active search is not retargeted into
another buffer's text. The origin is a position in the buffer
that was current when the search started. §5 chooses what switch
and kill-buffer do while a search is active, inside that rule.

The echo vocabulary does not grow. The row is still the path or
`untitled`, `saved:` / `failed:` plus that label, or the search
row. Switch and kill-buffer set the echo token to `""`, the same
way motion does. `find` still keeps the token. `save` still sets
`"saved"` or `"failed"`.

### 4.5 Commands go through the keymap that exists

Switch and kill-buffer are new zero-field constructors of
`AloemacsCommand`, with `name` strings, cased in
`execute-command`. `AloemacsCommand` already has `Kill` for the
region. The buffer command is a different constructor. The spec
names it.

Self-insert is still the only arm that uses the key string.

A binding, if §5 adds one, goes in the existing global map or the
existing `C-x` map. `C-x` then `"save"` still saves. Ctrl-S still
saves. A pending miss still cancels and consumes the key. This
series adds no second prefix and no binding that needs a typed
argument.

A new Term chord is in scope only for a plain Ctrl letter that
follows the Ctrl-S predicate shape, and only if §5 binds one.
The bar does not require a Term change. No new Term method.

### 4.6 How a test builds the second buffer

The spec names one session send that adds a buffer from text and
an optional path the test already has. The send does not prompt,
does not read the filesystem, and does not change the runner.
`visit` is not that send.

Two buffers may carry the same path. This series does not reject
a duplicate path. Save writes the current buffer's path.

### 4.7 What this series leaves alone

One window. The frame is still one string for the current buffer,
plus the echo row. Safe cells stay. `Text` gains no method.
`SPEC.md` gains no row. The kernel gains no message. List gains
no index message. No `Vector`, no mutation, no class methods, no
delegation, no Mirror.

There is no dirty bit. Kill-buffer does not ask to save.

`editor.aloe` and `file.aloe` share a load environment. A new
top-level name must not clash with `safe-cell-controls`,
`UndoFrame`, or the classes already defined there.

Untyped `AloemacsSession new` and an untyped buffer whose path is
absent still cannot take a bare `(Option None)`. The spec uses
the lawful `if` form already required at untyped sites, including
`main.aloe`. A method whose expected type supplies `T` may write
`(Option None)` directly. Do not change the type checker.

The spec shows the lawful constructor once. Checkpoint 000 updates
every untyped `AloemacsSession new` that the new shape breaks,
including `main.aloe` and the session tests. Editor-only tests
stay on `AloemacsEditor`.

### 4.8 Echo, in one place

| Event | Echo token |
|---|---|
| Idle commands except `find` and `save` | `""`, as the keymap spec already has |
| Switch, kill-buffer | `""` |
| `find` | unchanged; the search row takes the screen |
| `save`, from Ctrl-S or from `C-x C-s` | `"saved"` or `"failed"` |
| The label under a path | that path's text |
| The label under no path | `untitled` |

### 4.9 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-buffer 000** | The buffer value. The session holds a collection of one. The path lives on that buffer. Visit, save, echo, and the existing keys match today. No switch, no kill-buffer, no second buffer |
| **aloemacs-buffer 001** | The test send that adds a buffer. Switch and kill-buffer. Two buffers, per-buffer undo, mark, and scroll, one kill-ring, save of the current path |

000 is testable by the suite that already exists, once the
constructors match. 001 is testable once 000 is green. The
manager writes 000 only, then stops. Do not collapse them: the
value has to exist before two of them can switch.

If 001's optional key bindings would make that conversation too
big, the spec may split the bindings into **aloemacs-buffer 002**
and add no other behavior. The manager still writes one checkpoint
at a time.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The collection.** A zipper of buffers, in the shape of
   indexed `Text` (before, current, after), or a list walked
   from the front. Aloe has no list index. Do not add one. Name
   the selectors for the current buffer, the next one, and the
   previous one.
2. **The buffer's name.** Each buffer has a name string for a
   later switch-buffer. Give the rule that produces it from the
   path or from `untitled`. The echo label stays §4.8.
3. **The test send.** Its selector, whether the new buffer
   becomes current, and where it sits relative to the buffer
   that was current.
4. **The edges.** Switch with one buffer, beyond "text and point
   stay." Kill of the current buffer: which neighbor becomes
   current. Kill of the only buffer: what the remaining buffer
   contains. The result is still a session with a current
   buffer, it has not quit, and it has not saved.
5. **Search in progress.** What switch and kill-buffer do while
   search is active, so the origin is never read against a
   different buffer's text.
6. **Keys.** Bind the two commands, or leave them as sends for
   001. A binding uses an Aloe string the keymap can already
   hold, or one new plain Ctrl letter under §4.5. No typed
   argument. `C-x C-s` stays save.

## 6. Authority

- [`../README.md`](../README.md) — layer order; this layer is
  the buffer
- [`../explorations.md`](../explorations.md) — Band 2 item 6.
  Items 7 and 8 stay later
- [`../file/spec.md`](../file/spec.md) — visit and save. Where
  that spec stores one path on the session, this series moves
  the path onto the current buffer and keeps the visit and save
  results
- [`../echo/spec.md`](../echo/spec.md) — echo tokens and the
  last row
- [`../keymap/spec.md`](../keymap/spec.md) — `execute-command`,
  the maps, and `C-x C-s`
- [`../kill/spec.md`](../kill/spec.md) — mark on the editor,
  kill-ring on the session
- [`../undo/spec.md`](../undo/spec.md) — which edits push an
  `UndoFrame`
- [`../search/spec.md`](../search/spec.md) — search ahead of
  the keymap
- [`../viewport/spec.md`](../viewport/spec.md) — scroll on the
  editor; fit before frame
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
  — the editor fields this series wraps
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — session fields, `visit`, `save`, `execute-command`
- [`examples/aloemacs/main.aloe`](../../../../../examples/aloemacs/main.aloe)
  — the lawful `(Option None)` spelling at startup
- [`lib/text.aloe`](../../../../../lib/text.aloe) — the indexed
  zipper, as a pattern only
- [`SPEC.md`](../../../../../SPEC.md) §9 — bare `(Option None)`
  is rejected; the `if` form is the golden

`SPEC.md` remains language law. This series does not amend it.
The accepted layer specs remain the authority for what the
existing commands do to the current buffer. This charter is the
authority for what a buffer owns and for switch and kill-buffer.
After the human accepts `spec.md`, that file is the design
authority for the checkpoint manager and the implementers.

## 7. Non-goals

- The minibuffer, find-file, save-as, or a switch-buffer that
  reads a name
- `C-x C-f`, `C-x b`, `M-x`, or a second prefix
- Windows, splits, a mode line, or a buffer menu
- A prompt before kill-buffer, or a dirty bit
- Painting the region, a host clipboard, or a change to search
  keys
- A kernel message, a `SPEC.md` row, a `Text` method, a `List`
  index, `Vector`, or class methods
- A runner change, a new Term method, or a change to
  `AloemacsEditor`'s fields
- Mirror, mutation, or delegation
- A `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-buffer`.
- Checkpoint 000 is spoken **aloemacs-buffer 000** and filed as
  `checkpoints/000-buffer-value.md`. Checkpoint 001 is spoken
  **aloemacs-buffer 001** and filed as
  `checkpoints/001-switch-and-kill-buffer.md`. Numbers are three
  digits, start at 000, and are never renumbered. The slug is
  lowercase words separated by hyphens. The checkpoint manager
  writes one checkpoint, then stops.
- Intended order: §4.9. 000 first. 002 exists only if the spec
  splits key bindings out of 001.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`. A Term chord, if the spec binds one, may
  also touch `host/racket/term.rkt`. The design folder receives
  `spec.md` and later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
