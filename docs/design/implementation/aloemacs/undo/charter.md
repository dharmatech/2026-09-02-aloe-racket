# Charter — aloemacs undo

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for **one-step
undo of edits** on the immutable zipper `Text`, with a single extra
key. Then **stop**. Do not write checkpoints. Do not implement.
Do not specify redo, an undo tree, a minibuffer, prefix maps, or
mutation.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.8.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-undo 000**, … under
   `docs/design/implementation/aloemacs/undo/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. e's attributed undo /
rebase, Legmacs snapshot-of-whole-buffer-as-vectors, grouping
every insert into a word, and `C-x u` as a prefix map are
defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../text/`](../text/) / [`../index/`](../index/) | Focused `Text`, `replace` / `insert` / `delete` / `newline` |
| [`../loop/`](../loop/) | `handle-key` for insert, Return, Backspace, arrows, Escape |
| [`../file/`](../file/) | Session `"save"`; Ctrl-S Term mapping |
| [`../viewport/`](../viewport/) | `scroll-row` / `scroll-col`; `ensure-visible` before `frame` |

The zipper already shares unchanged line strings and list tails.
Undo should use that, not resplit the source.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. After an insert, newline, or backward-delete, one **undo**
   command restores the previous `Text` and point (and a
   documented viewport policy). A second undo restores the
   state before that, or is a no-op at the bottom of the
   history. The pre-undo editor values remain equal to
   themselves (immutability).
2. Movement, `ensure-visible`, save, quit, and unknown keys
   **do not** push history. Undo of “only moved the cursor”
   is out.
3. **Unit tests first**, no TTY, under `tests/aloemacs/` with
   names that do not reuse Viewport/Index files. At least:
   insert then undo; newline then undo; backspace then undo
   (including join-at-column-0); two edits then two undos;
   undo on a fresh editor is a no-op; arrows then undo does
   not revert the arrows; visit starts with empty history.
4. One extra `read-key` string (not a prefix map). Printable
   `z` still inserts. Same Term-mapping style as Ctrl-S
   (live `tkeymsg` `char` may default to the key).
5. No redo, no undo tree, no `set!`, no change to `Text`
   public replace semantics unless §4.6 chooses invert and
   names it.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Persistence, not mutation

History is an immutable `List` (or a small class of frames).
Undo rebuilds the editor. Nested edit is still rebuild. Do
not mutate `Text` in place.

### 4.2 Prefer snapshots; invert is optional

**Default:** each pushed frame is enough to restore focused
`Text` and `Position` (zipper sharing makes this cheap). Do
not store a whole editor that **contains** the history list
inside each frame (infinite / quadratic nesting).

e-style invert/rebase of spans is allowed only if you can
show it is smaller than snapshots **and** keep File
`to-string` exact. If you cannot, snapshots.

### 4.3 One key, File unchanged

`"undo"` (or the name you pin) is handled like `"save"`:
session or editor `handle-key` dispatches it. Visit/save
strings and Ctrl-S stay. Untitled save is still a no-op.
Undo does not write the filesystem.

### 4.4 Where code may live

- `examples/aloemacs/editor.aloe` (history, undo send,
  which keys push)
- `examples/aloemacs/file.aloe` if the session dispatches
  `"undo"` or visit must reset history
- `examples/aloemacs/main.aloe` if a constructor arity
  changes
- `host/racket/term.rkt` and a focused key-mapping test
  **only** for the undo chord, parallel to Ctrl-S
- Tests under `tests/aloemacs/`
- Not `lib/text.aloe` unless §4.6 names a new `Text`
  invert send; not the runner unless you prove handle-key
  cannot do it; not Gel, Fs host, `aloe/eval.rkt`

### 4.5 Out of this layer

- Redo, undo-in-region, undo tree, `C-x u`
- Grouping consecutive self-inserts into one step
- Dirty flags, backup files
- Minibuffer, prefix maps, search, kill ring
- Windows, `scroll-margin`, paint cache
- Mutation, compiler, `Vector`

### 4.6 What a frame stores (resolve this)

Name the history payload and who owns the list:

1. On `AloemacsEditor`, a `List` of a small frame class
   (`text`, `point`, maybe scroll), **or**
2. On `AloemacsSession` only.

Pick one. Visit (new file or existing) starts empty
history. `main.aloe` empty start is empty history.

Does a frame include `scroll-row` / `scroll-col`? If yes,
undo restores the view. If no, undo restores text+point
and the next `ensure-visible` fits. Pick one and test it.

### 4.7 When to push (resolve this)

Lock the set of commands that cons a frame **before**
applying the edit (so undo returns to the pre-edit
state). Must include insert, newline, backward-delete.
Must exclude arrows, Escape, save, `ensure-visible`.

Failed edits (`Option None`) must not push. Post-quit
keys must not push.

Cap: unbounded `List` is acceptable for this layer if
you say so. A documented max length is allowed; dropping
the oldest frame is rebuild of the list, not mutation.

### 4.8 The key (resolve this)

Name the Aloe string (`"undo"`) and the exact `tkeymsg`
shapes, including the live decoder defaulting `char` to
the key (Ctrl-S taught this). Prefer **Ctrl-Z** if Term
can name it without stealing printable `z`. If Ctrl-Z is
the suspend character **after** raw mode, check that
`tui-term` raw mode actually delivers it; if it cannot,
pick another chord and say why. Tests construct
`make-tkeymsg` as File 002 did; a TTY hand check is
optional and not the bar.

## 5. Authority

- [`../README.md`](../README.md) — no mutation, no eval
- [`../text/spec.md`](../text/spec.md) / [`../index/spec.md`](../index/spec.md)
  — `Text` behavior; zipper sharing
- [`../loop/spec.md`](../loop/spec.md) — keys
- [`../file/spec.md`](../file/spec.md) — `"save"` dispatch;
  Ctrl-S mapping as the template
- [`../viewport/spec.md`](../viewport/spec.md) — origin
  fields; fit-before-frame
- [`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
- Legmacs buffer undo (prior line vectors) and Chez Emacs
  invert — catalogs, not law

`SPEC.md` remains language law. This spec is not language
law.

## 6. Non-goals

- Redo
- Prefix keymaps, minibuffer, search
- Inverse-span rebase across foreign marks
- Changing Zipper/`replace` unless invert is chosen
- Host methods beyond a `tkeymsg->aloe-key` clause
- A status line that says “Undo!”
