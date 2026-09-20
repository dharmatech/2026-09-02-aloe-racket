# Charter — aloemacs loop

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for the **first
running aloemacs program**: one immutable editor value, keys that
insert / move / quit, and a full-screen frame `String` written with
`(term write …)`. Then **stop**. Do not write checkpoints. Do not
implement. Do not specify files, windows, prefix keymaps, search,
or live eval.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Confirm predecessors in §2 exist. If not, **stop**.
3. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.9.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-loop 000**, `001`, … under
   `docs/design/implementation/aloemacs/loop/checkpoints/` (not
   `docs/checkpoints/0116`, not `docs/editor/`).
5. Stop. The human reviews it. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A keymap table for `C-x`,
load/save, multiple buffers, a VT emulator, and a port of Legmacs
`main.lg` are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../text/`](../text/) | aloemacs-text 000–003: `Text`, `Position`, `Span`, `insert` / `delete` / `newline`, `valid-position?` |
| [`../term/`](../term/) | aloemacs-term 000: `(term write s)`, `(term columns)`, `(term rows)`, existing `read-key` / `write-line` |
| Gel loop | [`gel/main.aloe`](../../../../../gel/main.aloe) + [`gel/loop.aloe`](../../../../../gel/loop.aloe): immutable step, runner injects `term` |

This layer **composes** Text and Term. It does not reopen their
specs. Do not add `Char`, a second text representation, or a new
Term method unless §4.7 proves `read-key` cannot name a required
key.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. There is an immutable Aloe editor value (one class, or a
   closed set named in the spec) that holds a `Text` and a point
   `Position`. `(editor handle-key key)` returns a **new** editor.
   Nested edit is rebuild.
2. **Unit tests are the first consumer**, under `tests/aloemacs/`,
   with names that do not reuse `000`–`003` or
   `term-capability.rkt`. They load Aloe through a checked driver
   and do not require a TTY. At least:
   - insert a printable character into empty text;
   - newline splits a line;
   - backward delete joins or removes a character (name the key);
   - movement changes point without changing `(text to-string)`;
   - a quit key sets a documented quit fact;
   - an unknown key is a no-op, not a host error;
   - the input editor is unchanged after the send (immutability).
3. `(editor frame columns rows)` (or an equivalent send whose
   arguments are those two `Int`s) returns one `String`. That
   string is exactly what a later loop passes to `(term write …)`.
   Tests assert properties of that string at a documented small
   size (for example 8×4) without a TTY. Point is visible in the
   frame at that size.
4. A runner, analogous to `gel-run.rkt`, injects Term, loads
   `examples/aloemacs/`, and starts the loop. The runner is a
   skin: it does not implement insert, movement, or ANSI. Gel
   runners stay unchanged.
5. Files, windows, prefix chords (`C-x`), minibuffer, search,
   `Mirror`, and eval of buffer text are **out**.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Machine

Legmacs's pipeline, Gel's step:

```text
frame String  --term write-->  screen
read-key      --handle-key-->  new editor
```

Commands are methods (or a closed send list) on the editor value.
They are not `set-box!`, atoms, or host mutation of `Text`.

### 4.2 Start empty, in memory

The first program starts as `(Text from-string "")` with point
`(Position new 0 0)`. No path, no Fs, no `*scratch*` banner
requirement. A test may construct a non-empty `Text` directly.

### 4.3 Where code lives

- Editor program: `examples/aloemacs/` (Aloe sources; `load`
  `lib/text.aloe` through existing relative load)
- Runner: `host/racket/aloemacs-run.rkt` (or a name the spec
  pins), using `call-with-tty-term-receiver` and
  `driver-inject-host!` like Gel
- Tests: `tests/aloemacs/`
- Do not put editor classes in `lib/text.aloe`. Text stays the
  algebra. Do not add `lib/editor.aloe` unless the spec argues
  the loop types are a general library — default is
  `examples/aloemacs/` only
- Do not invent `docs/checkpoints/0116-…`

### 4.4 Keys in this layer

A **single** `read-key` `String` is one command. No prefix maps.

Required behaviors, not required Emacs names:

| Behavior | Notes |
|---|---|
| Insert | length-1 printable keys insert that `String` at point |
| Newline | the existing `read-key` name for Return (today `"return"`) |
| Backward delete | one key; uses `Text` delete of a one-character or LF span |
| Move | left, right, up, down; point stays a valid `Position` |
| Quit | one key; Gel uses `"q"` — that is allowed here |

Do not specify `C-x C-c`, `C-f`, or a keymap tree. Those are a
later layer.

### 4.5 Out of this layer

- Load, save, Fs, encoding, CRLF files
- Windows, splits, multiple buffers, a scratch banner
- Prefix keymaps, `M-x`, minibuffer, search, replace
- Undo, marks, selection, kill ring
- Goal column, tabs-as-columns, Unicode width
- Mouse, paste, PTY
- `Mirror`, eval of buffer text, hot reload
- Changing `write-line`, Gel, or the Text algebra's public table

### 4.6 Editor fields and movement (resolve this)

Specify the class, fields, constructors, and movement rules.

- Besides `text` and point, is `quit` a `Bool` field (Gel
  `GelStep`) or a constructor (`Running` / `Quit`)? Pick one.
- Is a viewport origin (first visible line) a field, or is it
  derived each `frame`? Point **must** remain visible in the
  tested frame sizes. If the text has more lines than `rows`,
  name clip-vs-scroll. Scroll-to-keep-point-visible is in scope;
  multiple windows are not.
- Left at column 0: previous line's end, or no-op? Right at
  end-of-line: next line column 0, or no-op? Up/down: same
  column clamped to line length (no remembered goal column).
- Failed `insert` / `delete` (`Option None`) must not happen for
  keys this spec binds; if it did, the editor is unchanged.
  Unwrap `Some` with `case`. Do not add a new Option API.

### 4.7 Key strings and Term mapping (resolve this)

`read-key` returns Aloe `String`s from
[`host/racket/term.rkt`](../../../../../host/racket/term.rkt)
(`tkeymsg->aloe-key`). Printable keys are one-character strings;
Return is `"return"`. Other named keys are `symbol->string` of
the `tui-term` key, or they currently **error**
(`unsupported key`).

Name every bound key as the exact `String` tests will send to
`handle-key`. Then pick one:

1. Those strings already come out of `tkeymsg->aloe-key` — only
   document them.
2. Backspace or arrows currently error — this layer may add the
   **smallest** mappings in `tkeymsg->aloe-key` (still not a new
   Term method). List the symbols and the Aloe strings.
3. Do not wait for Term: bind movement to keys that already
   work (for example `"h"` `"j"` `"k"` `"l"`) **in addition to**
   or **instead of** arrows. If instead, say so; an arrow-only
   spec that crashes on a real TTY is a defect.

Unknown keys (including `"escape"` if unbound) leave the editor
equal to the input. They must not call `error`.

### 4.8 Frame bytes (resolve this)

`frame` returns the exact payload of one `(term write …)`.

- ANSI (clear, cursor position, hide/show cursor) is an Aloe
  `String`, not a Term method. Name the sequences you emit, or
  name a tiny helper in `examples/aloemacs/` that builds them.
- Columns and rows are arguments to `frame` so tests do not
  inject Term. The interactive loop reads `(term columns)` and
  `(term rows)` each iteration (resize is still not a
  `read-key` event).
- ASCII, one cell per character. Do not clip graphemes. A line
  longer than `columns` needs a named rule (clip the line, no
  horizontal scroll in this layer is acceptable if point stays
  on a visible cell — if point is past `columns`, you must
  scroll horizontally **or** clamp movement; pick one and test
  it).
- Do not emit `write-line` in the editor loop. Gel keeps
  `write-line`; aloemacs uses `write` for the frame.

### 4.9 Who iterates (resolve this)

Gel's `GelMain` recurses in Aloe: write, `read-key`,
`handle-key`, loop. An editor session is longer and may overflow
that recursion.

Pick one:

1. **Aloe recursion**, Gel-style. Honest "the program is Aloe."
   Document stack overflow as an accepted limit of this layer.
2. **Runner `do` loop** in `aloemacs-run.rkt` that only
   `driver-eval!`s `frame` and `handle-key` (and `term`
   sends). The editor object stays Aloe; iteration is the skin.

Do not mix: no Racket insert/move. If you pick (2), the spec
still tests `handle-key` and `frame` in Aloe; the runner is
specified as a short sequence, not a second editor.

## 5. Authority

- [`../README.md`](../README.md) — locks, paths, non-goals
- [`../text/spec.md`](../text/spec.md) — `Text` / `Position` /
  `EditResult`; do not amend that table
- [`../term/spec.md`](../term/spec.md) — `write`, `columns`,
  `rows`; `read-key` still ignores mouse and resize
- `SPEC.md` — send, classes, `Option` / `case`, no mutation
- `docs/philosophy.md` — grow from applications
- [`gel/main.aloe`](../../../../../gel/main.aloe) — injected
  `term`, immutable step
- [`host/racket/gel-run.rkt`](../../../../../host/racket/gel-run.rkt)
  — runner shape
- Legmacs `main.lg` / `render.lg` / `dispatch.lg` — seam
  catalog, not law

`SPEC.md` remains Aloe language law. This spec is not language
law.

## 6. Non-goals

- Files, visit, save, dirty flags
- Windows, status/mode line as a product feature (a one-line
  leftover row in the frame is allowed only if the spec needs
  it to place the cursor; it is not a minibuffer)
- Prefix keymaps, chords, `M-x`
- Undo, search, indent, syntax
- `Mirror`, evaluating Aloe from the buffer
- Unicode width, mouse, paste, PTY
- Changing Gel or promoting Term to the language spine
- Porting Chez Emacs `head` or Legmacs `commands.lg`
