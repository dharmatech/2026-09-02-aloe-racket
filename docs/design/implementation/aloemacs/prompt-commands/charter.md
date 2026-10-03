# Charter — aloemacs prompt commands

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **find-file, save-as, and
named buffer selection**. The series identity is
**aloemacs-prompt-commands**. Each command starts the prompt that
already exists. Return runs that command on the submitted string.
Escape runs nothing. Then **stop**. Do not write checkpoints. Do
not implement.

This effort refuses completion, a directory listing, windows,
`M-x`, a stored buffer name, and any change to what a direct
`visit` does to the current buffer. Those stay later, so this
spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-prompt-commands 000** under
   `docs/design/implementation/aloemacs/prompt-commands/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the three checkpoints in §4.9. A basename match,
a completion list, a second copy of `visit` that destroys the
current buffer, or a new Term chord are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../file/`](../file/) | `visit` resolves, reads a regular file, and accepts a missing path as an empty buffer. A directory, symlink, or other node returns `None`. `save` writes the current text or returns `None` |
| [`../keymap/`](../keymap/) | Commands are values. `execute-command` performs them. `C-x` is the one prefix, and `C-x C-s` saves. A pending command clears the prefix before it runs |
| [`../buffer/`](../buffer/) | A buffer's name is the path text or `"untitled"`. `add-buffer` inserts after the current buffer and selects the new one. `switch-buffer` cycles. Direct `visit` still replaces only the current buffer |
| [`../minibuffer/`](../minibuffer/) | `start-prompt` opens an empty line on the echo row. Return stores `last-submission` and ends the prompt. Escape ends it and leaves the previous submission. No command reads the string yet |

Layers 1–15 are implemented. This series does not wait for a
runner change and does not edit the runner.

**Why this layer:** the prompt can read a line, and nothing in
the editor asks for one. Find-file, save-as, and a named
switch are the first commands that do. The cycling
`switch-buffer` stays a send with no key.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Idle keys match today.** Plain Ctrl-F still searches. Plain
   Ctrl-W still kills the region. A plain `b` still inserts.
   `C-x C-s` still saves. `C-x` then an unbound key still
   changes nothing and consumes the key. Direct `visit` still
   replaces the current buffer. `start-prompt` followed by
   Return still only stores the string.
2. **Find-file keeps the buffer you were in.** `C-x C-f`, a
   path, and Return select the opened buffer and leave the
   previous buffer's text, point, undo, mark, and path in the
   zipper. A missing path becomes an empty buffer bound to the
   resolved path and creates no file. A directory, symlink, or
   other node changes no buffer. Escape and an empty
   submission change no buffer and call no filesystem
   operation.
3. **Save-as writes this buffer.** `C-x C-w`, a path, and
   Return write the current text to the resolved path and bind
   this buffer to it. Point, undo, mark, and scroll stay.
   A failed write writes nothing and leaves the path as it
   was. Escape writes nothing.
4. **A name selects a buffer.** `C-x b` and the exact name of
   another buffer select it. The typed string is not resolved
   as a path. A miss or an empty string creates no buffer and
   does not switch. The cycling `switch-buffer` send still
   cycles and still has no key.
5. **The echo vocabulary stays three tokens.** Success and
   failure use `""`, `"saved"`, and `"failed"` as §4.8 says.
   Cancel does not set `"failed"`.
6. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

A directory browser is a later series. This bar is the no-TTY
test.

## 4. Locked decisions (record these; do not reopen 4.1–4.9)

### 4.1 Three commands, one waiting slot

Find-file, save-as, and named selection are new constructors of
`AloemacsCommand`. The session executes them through
`execute-command`. They are not arms of
`AloemacsEditor.handle-key`, and they are not dispatched by
matching the command's name string.

The constructor names and the exact `name` strings are:

| Constructor | Exact `name` |
|---|---|
| `FindFile` | `"find-file"` |
| `SaveAs` | `"save-as"` |
| `SelectBuffer` | `"select-buffer"` |

`SwitchBuffer` stays `"switch-buffer"` and still means cycle
forward. It gains no key. `Kill` stays the region command.

Each of these three executions starts a prompt and remembers
that command in one new session slot. The slot is absent at
startup, after `main.aloe` builds a session, and whenever no
prompt command is waiting. Append the slot after
`last-submission`. Introduce it in checkpoint 000. Checkpoints
001 and 002 must not add another session field to tell the
three commands apart.

`start-prompt` does not fill the slot and does not clear it.
Return runs the waiting command only when a prompt was active
and the slot is present, and only after the submitted text is
stored and the prompt is inactive. It then clears the slot,
whether the command succeeds or fails. A `submit-prompt` on an
inactive session does not run the command. Escape clears the
slot and does not run it. The previous `last-submission` stays
on Escape. Typing, motion, and ignored prompt keys preserve
the slot.

A direct `start-prompt`, with the slot absent, still only
stores the string on Return. Existing minibuffer tests keep
that result.

The key string passed to `execute-command` is not a path and
not a buffer name. The command reads the path or the name from
`last-submission` when Return runs it.

The spec names the slot, its Aloe type, and the helpers. An
`Option` of `AloemacsCommand` is a lawful type. A bare
`(Option None)` at an untyped constructor still uses the `if`
form from `SPEC.md` §9.

### 4.2 The chords use today's key strings

Term already names the keys. This series does not edit
`host/racket/term.rkt` and does not add a Term method.

| Chord | Second key string | Command |
|---|---|---|
| `C-x C-f` | `"find"` | `FindFile` |
| `C-x C-w` | `"kill"` | `SaveAs` |
| `C-x b` | `"b"` | `SelectBuffer` |

`"find"` is the string plain Ctrl-F already produces, and
`"kill"` is the string plain Ctrl-W already produces. In the
global map those strings still search and kill. The new
bindings sit in `aloemacs-ctrl-x-keymap` beside the existing
`"save"` binding. The global map gains no binding. The prefix
map's default stays absent, so an unknown `C-x` key is still
consumed.

The keymap clears a pending prefix before `execute-command`.
The command therefore starts its prompt with `start-prompt`
after that clear. `start-prompt` still leaves the session
unchanged when the editor has quit, search is active, a prefix
is pending, or a prompt is already active. This series does
not change search's keys or the prompt's insert, motion, and
cancel table, except the Return and Escape results in §4.1.

The prompt labels, including the trailing space, are:

| Command | Label |
|---|---|
| `FindFile` | `"Find file: "` |
| `SaveAs` | `"Save as: "` |
| `SelectBuffer` | `"Buffer: "` |

The prompt joins the label to the text with no extra
separator. Each prompt starts empty. The current path and the
current name are not prefilled.

### 4.3 Find-file reads, and it does not call `visit`

`visit` replaces the current buffer. Find-file must not send
`visit`. The previous buffer stays in the zipper with its
editor and path untouched.

Resolve the submitted string with `(fs path string)`, the same
resolve `visit` uses. Compare and store that resolved path.
Do not store the unresolved typed text.

| Submitted string | Result |
|---|---|
| `""` | No filesystem call. No buffer change. Echo `"failed"` |
| Resolved path whose text equals the current buffer's name | Stay on that buffer. Do not read. Echo `""` |
| Resolved path whose text equals another buffer's name | Select the first such buffer in `focus-next` order. Do not read. Do not change its text, point, undo, mark, or scroll. Echo `""` |
| Missing path | Add an empty buffer bound to the resolved path. Create no file. Select it. Echo `""` |
| Regular file that reads | Add a buffer with those exact contents and the resolved path. Select it. Echo `""` |
| Directory, symlink, other node, or a read that returns `None` | No buffer change. Echo `"failed"` |

A new buffer is inserted after the buffer that was current and
becomes current, the same placement as `add-buffer`. Its point
is `(0, 0)`, its history is empty, and it has no mark. An
untitled buffer is not reused and is not removed. Two buffers
may still share a path when they were created that way
earlier; find-file itself does not add a second buffer for a
resolved path that is already a buffer name.

Host failures still raise. A relative string resolves from the
filesystem's current directory, as `visit` already does.

### 4.4 Save-as writes this buffer

Save-as does not add a buffer and does not send `visit`. It
writes the current buffer's exact `(text to-string)`.

Resolve a nonempty string with `(fs path string)`. Write that
resolved path through the existing `Fs.write`. On success, the
current buffer's path becomes that resolved path and its name
becomes the resolved text. The editor value stays: text,
point, quit, undo, mark, scroll, and remembered rows. Echo
`"saved"`. On `None`, write nothing, leave the path as it was,
and set echo `"failed"`.

`""` makes no filesystem call, leaves the path, and sets echo
`"failed"`. A write to the path this buffer already has is an
ordinary successful write. A resolved path that another buffer
already has is still written, and this buffer takes that path
too. The other buffer stays put, with its own text. Duplicates
remain legal. There is no overwrite confirmation, no backup,
and no directory creation. `Fs.write` already refuses a
missing parent, a directory, a symlink, and any other
non-file.

Save-as pushes no undo frame. It does not change the
kill-ring.

### 4.5 Select-buffer matches the derived name

The typed string is compared with `(buffer name)` as an exact
string. It is not resolved, not taken as a basename, and not
completed. A buffer with no path and a buffer whose stored path
text is `"untitled"` share that name. Matching does not prefer
either one. The current buffer wins when its name is equal;
otherwise the first `focus-next` match wins.

| Submitted string | Result |
|---|---|
| `""` | No switch. No new buffer. Echo `"failed"` |
| Equal to the current buffer's name | Stay. Echo `""` |
| Equal to a later buffer's name | Select the first match in `focus-next` order. Echo `""` |
| Equal to no name | No switch. No new buffer. Echo `"failed"` |

A selected buffer keeps the text, point, undo, mark, and
scroll it already had. The selection ends search, clears a
pending prefix, preserves the kill-ring, and sets echo `""`,
the same session resets as the cycling `switch-buffer`. It
does not read or write the filesystem. A miss creates nothing:
a fresh buffer would be named `"untitled"` or a path, and it
cannot wear an arbitrary typed name. This series adds no
stored name field.

### 4.6 What the commands leave alone

None of the three commands set quit, arm a prefix, or change
the kill-ring. Find-file and select-buffer do not write.
Save-as does not switch buffers. Cancel leaves every buffer,
the echo token, and `last-submission` as the prompt series
already requires, and it clears the waiting slot.

Direct `save`, `switch-buffer`, `kill-buffer`, `add-buffer`,
`ensure-visible`, and `frame` keep their current meanings.
They do not run the waiting command. They preserve the slot.
A successful `visit` still replaces the current buffer, still
deactivates a prompt, and also clears the waiting slot, so a
replaced buffer cannot later run a command that was waiting.
A refused `visit` leaves the receiver unchanged, slot
included.

The runner's arguments, fit-then-frame order, and one
`term write` stay. This series does not edit
`host/racket/aloemacs-run.rkt` or `examples/aloemacs/editor.aloe`.

After a command finishes, the waiting slot is absent. The
submitted string remains readable. Nothing in this series
clears `last-submission` on success.

### 4.7 Reconstruction

Checkpoint 000 updates every untyped `AloemacsSession new`
that the new slot breaks, including `main.aloe` and the
session tests. Search the product and the tests again. The
spec shows the lawful constructor once. Editor-only tests stay
on `AloemacsEditor`.

Every session reconstruction threads the slot. Prompt editing
preserves it. The finished command clears it. The spec lists
those sites the way the minibuffer spec listed its new fields.

### 4.8 Echo, in one place

The stored tokens remain `""`, `"saved"`, and `"failed"`.

| Event | Echo token |
|---|---|
| Prompt active | Unchanged. The prompt row hides it |
| Escape | Unchanged |
| Find-file success, or select-buffer success | `""` |
| Save-as success | `"saved"` |
| Empty input, a refused file, a refused write, or no matching name | `"failed"` |
| `start-prompt` with no waiting command | Unchanged, including on Return |

### 4.9 Three checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-prompt-commands 000** | The waiting slot. Find-file, its label, and `C-x C-f`. Open, missing, reuse, refusal, empty input, and cancel. `start-prompt` alone still only stores a string. Direct `visit` still replaces the current buffer |
| **aloemacs-prompt-commands 001** | Save-as, its label, and `C-x C-w`. A successful write binds the path and keeps the editor. A failed write and a cancel write nothing |
| **aloemacs-prompt-commands 002** | Select-buffer, its label, and `C-x b`. Exact names, the current buffer, the `focus-next` duplicate, and a miss. Cycling `switch-buffer` still has no key |

000 is testable on its own. 001 needs the slot from 000. 002
needs that slot too. The manager writes 000 only, then stops.
Do not collapse them: opening a file, writing a path, and
selecting a name are three proofs.

If a checkpoint cannot fit one implementer conversation, stop
and report that. Do not add a fourth checkpoint in the spec.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The slot.** Its field name and Aloe type, and the helper
   selectors. Checkpoint 000 introduces the only new session
   field. Later checkpoints add command constructors, not
   fields.
2. **The read.** How find-file performs the same missing-file,
   regular-file, and refusal cases as `visit` without sending
   `visit`. A private helper is lawful. A second copy of the
   policy, drifted from `visit`, is not.
3. **The path update.** How save-as replaces the current
   buffer's path while keeping the same editor value. Name the
   selector if it adds one.
4. **Binding order.** The order of the new `"find"`, `"kill"`,
   and `"b"` bindings in `aloemacs-ctrl-x-keymap`. `"save"`
   stays. The keys are §4.2, whatever the list order is.

## 6. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  the prompt commands
- [`../explorations.md`](../explorations.md) — Band 2 item 8.
  Windows stay the following band
- [`../file/spec.md`](../file/spec.md) — resolve, read, write,
  and the visit and save outcomes
- [`../keymap/spec.md`](../keymap/spec.md) — `execute-command`,
  the `C-x` prefix, and clearing that prefix before a command
- [`../buffer/spec.md`](../buffer/spec.md) — derived names,
  `add-buffer`, cycling `switch-buffer`, and direct `visit`
- [`../minibuffer/spec.md`](../minibuffer/spec.md) — the prompt,
  `start-prompt`, submit, cancel, and `last-submission`.
  §4.1 extends only Return and Escape when a command is waiting
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — session commands, `visit`, `save`, and the ctrl-x map
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
  — Ctrl-F is already `"find"` and Ctrl-W is already `"kill"`
- [`SPEC.md`](../../../../../SPEC.md) §9 — the lawful `Option`
  form

`SPEC.md` remains language law. This series does not amend it.
Where an accepted spec describes direct `visit`, cycling
`switch-buffer`, or a prompt with no waiting command, that spec
wins. Where this charter describes find-file, save-as,
select-buffer, and Return with a waiting command, this charter
wins. After the human accepts `spec.md`, that file is the
design authority for the checkpoint manager and the
implementers.

## 7. Non-goals

- Completion, a prompt history, or a prefilled path or name
- A directory listing, wildcards, backup files, or `mkdir`
- An overwrite confirmation
- Windows, splits, a mode line, or a buffer menu
- `M-x`, or a binding for the cycling `switch-buffer`
- A stored, uniquified, or basename buffer name
- Reusing or discarding the current untitled buffer on find-file
- Making direct `visit` insert a buffer instead of replacing
  the current one
- A new Term chord, a runner argument, or a change to search
  keys
- A kernel message, a `SPEC.md` row, a `Text` method, or a
  `List` index
- Mirror, mutation, delegation, or a `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-prompt-commands`.
- Checkpoint 000 is spoken **aloemacs-prompt-commands 000** and
  filed as `checkpoints/000-find-file.md`. Checkpoint 001 is
  spoken **aloemacs-prompt-commands 001** and filed as
  `checkpoints/001-save-as.md`. Checkpoint 002 is spoken
  **aloemacs-prompt-commands 002** and filed as
  `checkpoints/002-select-buffer.md`. Numbers are three digits,
  start at 000, and are never renumbered. The slug is lowercase
  words separated by hyphens. The checkpoint manager writes one
  checkpoint, then stops.
- Intended order: §4.9. 000 first.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md` and
  later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
