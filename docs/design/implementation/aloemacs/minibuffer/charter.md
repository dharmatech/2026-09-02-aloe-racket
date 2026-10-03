# Charter — aloemacs minibuffer

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **a prompt as its own
small editor on the echo row**. The series identity is
**aloemacs-minibuffer**. A test can start that prompt, type a
string, submit it or cancel, and read a submission back. The
current buffer stays as it was. Then **stop**. Do not write
checkpoints. Do not implement.

This effort refuses find-file, save-as, a named switch-buffer,
completion, `C-x C-f`, `C-x C-w`, `C-x b`, `M-x`, windows, and a
rewrite of search onto this prompt. Those stay later series, so
this spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-minibuffer 000** under
   `docs/design/implementation/aloemacs/minibuffer/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the two checkpoints in §4.9. A path command, a
completion list, a prompt stacked in the buffer zipper, or a
second window are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../echo/`](../echo/) | The last row shows the path, `untitled`, or `saved:` / `failed:` plus that label. Fit uses `rows - 1` when `rows >= 2`. The cursor ends in the text rectangle |
| [`../safe-cells/`](../safe-cells/) | The echo label passes through `safe-cells` after clipping |
| [`../search/`](../search/) | An active search owns the keys and replaces the echo row. Escape and Return end search. The stored echo token stays put |
| [`../keymap/`](../keymap/) | Quit, then search, then the map. `C-x` is the one pending prefix. `C-x C-s` saves. A pending miss cancels and consumes the key |
| [`../buffer/`](../buffer/) | A buffer holds the editor and the optional path. The session holds a nonempty zipper. Switch and kill-buffer are sends |

Layers 1–14 are implemented. aloemacs-runner-check 000 is **not**
a predecessor. This series does not wait for it and does not edit
that checkpoint.

**Why this layer:** find-file, save-as, and a named switch-buffer
need somewhere to type. The buffer name is already the path text
or `"untitled"`, and nothing looks a buffer up by that name.
Search already types into an append-only query. This series adds
the editable line those later commands will read. It does not add
the commands.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Idle sessions match today.** With the prompt inactive, every
   existing key, search, quit, visit, save, switch, kill-buffer,
   and `C-x C-s` keeps today's text, point, quit flag, mark,
   kill-ring, undo history, search flags, echo token, pending
   map, and written file. The idle frame still ends with the
   cursor in the text rectangle.
2. **The prompt is editable on the echo row.** A no-TTY test can
   start a prompt, insert characters at a cursor, move inside the
   line, and see that line on the last row. The frame is still
   one string. The text rows still show the current buffer.
3. **Submit and cancel leave the buffer alone.** After either
   one, the current buffer's text, point, undo history, mark,
   scroll, path, and name are unchanged. The session has not
   quit, searched, saved, switched, or armed `C-x`. Return does
   not insert a newline. Escape does not quit. The one-character
   string `"\n"` leaves an active prompt unchanged. A successful
   direct `visit` from an active prompt returns an inactive
   prompt, drops the in-progress line, and keeps the last
   submission. A refused `visit` leaves that active prompt in
   place.
4. **A test can read the submission.** The session returned by
   submit answers with the prompt's text, without the label.
   Cancel does not replace that stored text. No command in this
   series visits a path, writes a file, or selects a buffer from
   it.
5. **Search and the keymap stay in force when the prompt is
   down.** An active search still handles its own keys. A pending
   prefix still consumes the next key. The start send does
   nothing while search is active, a prefix is pending, the
   editor has quit, or a prompt is already active.
6. **Tests first**, no TTY. On this machine, Racket tests need
   `TMPDIR=/tmp`, and the command includes `-y`:
   `TMPDIR=/tmp raco test -y tests/aloemacs`.

A hands-on tour that opens a file from the prompt is the
find-file series. This bar is the no-TTY test.

## 4. Locked decisions (record these; do not reopen 4.1–4.9)

### 4.1 The prompt is its own value

The prompt is a new immutable value. It carries a label string,
the editable text, and a cursor into that text. It is one line.
The text never contains a newline.

It is not an `AloemacsBuffer`, an `AloemacsEditor`, or an
`AloemacsSession`. It does not enter the buffer zipper. It is
not a window. `editor.aloe` does not gain this type. The editor
constructor does not grow.

The class name starts with `Aloemacs`. The spec chooses the name,
the selectors, and whether the line is a `String` plus a column
or a one-line `Text`. It adds no `Text` method either way.

The session stores the prompt state and the last submitted text.
Both are new. Append them after `pending`, so the existing field
order stays a prefix. The spec chooses the Aloe shape. An inactive
prompt is the default at startup and on the session `main.aloe`
builds. A successful `visit` returns an inactive prompt under
§4.3. A refused `visit` leaves the receiver unchanged.

`editor.aloe` and `file.aloe` share a load environment. A new
top-level name must not clash with `safe-cell-controls`,
`UndoFrame`, or the classes already defined there. The spec may
put the class in `file.aloe` or in a new file that the existing
load chain includes. Code stays in `examples/aloemacs/`.

Untyped `AloemacsSession new` still cannot take a bare
`(Option None)`. The spec uses the lawful `if` form already
required at untyped sites, including `main.aloe`, whenever a new
field is an `Option`. A method whose expected type supplies `T`
may write `(Option None)` directly. Do not change the type
checker.

The spec shows the lawful constructor once. Checkpoint 000
updates every untyped `AloemacsSession new` that the new fields
break. Editor-only tests stay on `AloemacsEditor`.

### 4.2 The active prompt occupies the echo row

While the prompt is active and `rows >= 2`, the session frame
still uses the echo spec's single suffix. The shown row is the
prompt, composed from the label and the text. The spec chooses
the join. Clipping is `String.take` of `columns`, with no
ellipsis. The clipped row then goes through `safe-cells`, as the
echo label already does. Safe cells change the painted row only.
The stored prompt text and the submitted string keep their
characters.

The visible cursor is on that echo row, at the prompt cursor's
screen column, and that column lies inside `1` through
`columns`. This is the one case that supersedes the echo spec's
rule that the finished frame leaves the cursor in the text
rectangle. When the prompt is inactive, that echo rule stands,
including during search.

At `rows = 1`, do not steal the only text row. Prompt transitions
still work, and no prompt row is drawn. `rows = 0` stays outside
the existing frame contract.

The stored echo token stays `""`, `"saved"`, or `"failed"`.
Showing the prompt does not overwrite it. Search's rule is the
model: the active row is a display choice, and the token is still
there when the prompt ends. Submit and cancel do not set
`"saved"` or `"failed"`. The echo vocabulary does not grow.

An inactive prompt leaves the row to the specs that already own
it: search while search is active, otherwise the path,
`untitled`, or `saved:` / `failed:` plus that label.

### 4.3 The current buffer stays current

Start, insert, backspace, left, right, submit, and cancel do not
change the current buffer's text, point, quit flag, undo history,
mark, scroll, path, or name. They do not push an `UndoFrame`.
They do not change the kill-ring. They do not switch, add, or
kill a buffer. They do not call `visit` or `save`. They do not
arm or clear a pending prefix except by leaving it as it was.

The prompt has no undo of its own in this series. Backspace is
how a character comes out.

Direct `save`, `switch-buffer`, `kill-buffer`,
`ensure-visible`, and `frame` keep the buffer meanings their
specs already give them. They do not read the prompt text as a
path or a buffer name. They preserve prompt activity, the
in-progress line, and the last submission.

A successful `visit` keeps the buffer meaning in the buffer
spec. It replaces the current buffer and resets echo, search,
the kill-ring, and pending as that spec already requires. It
also deactivates the prompt and drops the in-progress line. That
line is not stored as a submission. The last submitted text
stays. An active prompt does not survive a successful visit. A
refused `visit` returns `None` and leaves the receiver
unchanged, so an active prompt stays active.

The runner's argv shape, fit-then-frame order, one `term write`,
and `(aloemacs-editor quit)` stay. This series does not edit
`host/racket/aloemacs-run.rkt`.

### 4.4 Who receives a key

`AloemacsSession.handle-key` keeps this order:

1. Already quit: return the session unchanged.
2. Active search: today's search transition.
3. Active prompt: the prompt transition in §4.5.
4. Pending prefix, then the idle map: today's keymap rules.

The keymap is not consulted while the prompt is active. Search
is not retargeted into the prompt, and the prompt is not a search
query. Ctrl-F keeps today's meaning when the prompt is inactive.
This series does not move search onto the prompt value.

The start send leaves the session unchanged when the editor has
quit, search is active, a prefix is pending, or a prompt is
already active. There is no stack of prompts.

No keymap binding starts the prompt. `AloemacsCommand` gains no
constructor. `execute-command` gains no arm. No new Term chord
and no new Term method. `C-x` then `"save"` still saves. Ctrl-S
still saves. A pending miss still cancels and consumes the key.

### 4.5 Typing, submit, and cancel

The spec names one session send that starts a prompt. Its
argument is the label. The editable text starts empty, and the
cursor starts at the beginning of that text. The send does not
read the filesystem and does not change the runner.

While the prompt is active:

| Key | Result |
|---|---|
| A length-one string other than `"\n"`, including space | Insert that character at the cursor |
| `"\n"` | Ignore. The prompt stays active. Text, cursor, buffer, and the stored submission stay |
| `"backspace"` | Delete the character before the cursor. At column 0, leave the text |
| `"left"` / `"right"` | Move one column inside the text. At either end, stay |
| `"return"` | Submit. Deactivate the prompt. Store the editable text, without the label. An empty text is a submission |
| `"escape"` | Cancel. Deactivate the prompt. Leave the stored submission as it was |

Length-one means `(key len) = 1`, the keymap's test for
self-insert. The one-character line feed `"\n"` is the
exception, and it is inside the input contract. `"return"` is a
different key and submits. `"find"`, `"save"`, `"ctrl-x"`, and
every other named key are not length-one inserts. §5 chooses
those other keys. While the prompt is inactive, a direct
`"\n"` keeps today's idle self-insert.

Return does not insert a newline into the prompt or the buffer.
Escape does not quit and does not insert. Neither key edits the
buffer. After either key the prompt is inactive, so the next
frame uses the idle row and returns the cursor to the text
rectangle. The stored echo token is the one the prompt preserved.

### 4.6 What the test reads

The session exposes the last submitted text by a send the spec
names. The value is the editable text only. The label is display
data and is not part of the submission.

Cancel does not write a new submission. Idle keys, search, save,
switch, kill-buffer, and both outcomes of `visit` do not erase
the stored submission. A successful `visit` drops only the
in-progress line.
Nothing in this series consumes it. A later series may read it
inside a command. This series stops at the stored string.

Before any submit, the spec chooses what that send returns. The
choice has to typecheck at every untyped session constructor.

### 4.7 What this series leaves alone

One window. The frame is still one string for the current buffer
plus the echo row. `Text` gains no method. `SPEC.md` gains no
row. The kernel gains no message. List gains no index message.
No `Vector`, no mutation, no class methods, no delegation, no
Mirror.

There is no dirty bit, no prompt history, and no completion list.
The buffer name stays the derived path text or `"untitled"`.
This series adds no lookup by name.

Search keeps its query, its row, and its keys. The echo token
keeps its three values. The kill-ring stays the session's one
ring.

### 4.8 Echo, in one place

| Event | Echo token | Row |
|---|---|---|
| Prompt inactive, search inactive | unchanged | Today's path, `untitled`, or `saved:` / `failed:` |
| Prompt inactive, search active | unchanged | Today's `search:` / `wrapped:` / `failing:` row |
| Prompt active, `rows >= 2` | unchanged | The prompt's label and text |
| Prompt active, `rows = 1` | unchanged | No echo row, as today |
| Submit or cancel | unchanged | Back to the inactive row |

### 4.9 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-minibuffer 000** | The prompt value and the session fields. A test builds an active prompt and the frame shows it on the echo row, cursor included. An inactive session still frames as today. No start send, no typing, no submit |
| **aloemacs-minibuffer 001** | The start send. Insert, backspace, left, right, submit, and cancel. The submitted string is readable. The buffer is unchanged. Existing idle keys still behave when the prompt is down |

000 is testable once constructors and the frame match. 001 is
testable once 000 is green. The manager writes 000 only, then
stops. Do not collapse them: the row has to be specified before
the keys are worth a checkpoint.

If the other-key rule or the wide-row cursor would make 001 too
big, the spec may split that display detail into
**aloemacs-minibuffer 002** and add no command. The manager still
writes one checkpoint at a time.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The line.** A `String` and an `Int` column, or a one-line
   `Text`. Name the class and the selectors. Name the session
   fields that hold the active prompt and the last submission,
   and what the read send returns before any submit.
2. **The row spelling.** How label and text join, and the screen
   column of the cursor. The cursor addresses a cell of the
   editable text, after the label. A row wider than `columns`
   still clips with `take` and no ellipsis, and the cursor cell
   stays on the echo row inside those columns. Give the rule
   that keeps it there.
3. **Other keys.** While the prompt is active, a key other than
   the rows in §4.5 is either ignored, or it cancels and then
   follows today's idle rule. It is not inserted into the
   prompt. The one-character `"\n"` is one of those rows, so
   this question does not choose it. If another key cancels and
   then dispatches, the dispatch sees an inactive prompt and may
   then edit the buffer under the idle rule. Insert, backspace,
   left, right, submit, and cancel themselves still obey §4.3.
4. **Line ends.** Whether `"line-start"` and `"line-end"` move
   the prompt cursor. Up, down, page, and buffer motions are
   other keys under question 3. They are not prompt motions.
5. **The start selector.** Its name. The label argument may be
   empty. An empty label is display data, not a missing command.

## 6. Authority

- [`../README.md`](../README.md) — layer order; this layer is
  the minibuffer
- [`../explorations.md`](../explorations.md) — Band 2 item 7.
  Item 8 stays the following series
- [`../echo/spec.md`](../echo/spec.md) — the reserved row, the
  token, fit height, and the cursor while the prompt is inactive.
  §4.2 supersedes only the finished cursor position while the
  prompt is active
- [`../search/spec.md`](../search/spec.md) — search keys, the
  search row, and the preserved echo token
- [`../keymap/spec.md`](../keymap/spec.md) — quit, search, the
  pending prefix, and idle dispatch while the prompt is inactive
- [`../buffer/spec.md`](../buffer/spec.md) — what a buffer owns,
  and switch and kill-buffer
- [`../safe-cells/spec.md`](../safe-cells/spec.md) — controls
  paint as one space after clipping
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — session fields, `handle-key`, and `frame`
- [`examples/aloemacs/main.aloe`](../../../../../examples/aloemacs/main.aloe)
  — the lawful `(Option None)` spelling at startup
- [`SPEC.md`](../../../../../SPEC.md) §9 — bare `(Option None)`
  is rejected; the `if` form is the golden

`SPEC.md` remains language law. This series does not amend it.
The accepted layer specs remain the authority for the current
buffer, search, the keymap, and the idle echo row. This charter
is the authority for what the prompt owns and for submit and
cancel. After the human accepts `spec.md`, that file is the
design authority for the checkpoint manager and the implementers.
Where an accepted spec and this charter both speak to an active
prompt, this charter wins.

## 7. Non-goals

- Find-file, save-as, or a switch-buffer that reads a name
- Completion, a prompt history, or an initial path or buffer name
- `C-x C-f`, `C-x C-w`, `C-x b`, `M-x`, or a second prefix
- A keymap binding that starts the prompt
- Windows, splits, a mode line, or a buffer menu
- Moving search, its query, or its keys onto the prompt
- A prompt before kill-buffer, or a dirty bit
- Painting the region, a host clipboard, or prompt undo
- A kernel message, a `SPEC.md` row, a `Text` method, a `List`
  index, `Vector`, or class methods
- A runner change, a new Term method, or a change to
  `AloemacsEditor`'s fields
- Mirror, mutation, or delegation
- A `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-minibuffer`.
- Checkpoint 000 is spoken **aloemacs-minibuffer 000** and filed
  as `checkpoints/000-prompt-value.md`. Checkpoint 001 is spoken
  **aloemacs-minibuffer 001** and filed as
  `checkpoints/001-type-submit-cancel.md`. Numbers are three
  digits, start at 000, and are never renumbered. The slug is
  lowercase words separated by hyphens. The checkpoint manager
  writes one checkpoint, then stops.
- Intended order: §4.9. 000 first. 002 exists only if the spec
  splits the wide-row cursor, or the other-key rule, out of 001.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md` and
  later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
