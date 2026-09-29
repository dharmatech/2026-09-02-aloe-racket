# Charter — aloemacs echo

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for a
**reserved echo row**: the user can see the bound path and whether
the last save worked. Then **stop**. Do not write checkpoints. Do
not implement. Do not specify escaping `ESC` in file text, tab
width, or faster load/save.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.8.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-echo 000**, … under
   `docs/design/implementation/aloemacs/echo/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. Minibuffer input, `C-x`,
mode lines with major-mode names, and sanitizing file bytes for
the terminal are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../file/`](../file/) | Session has `(Option Path)`, `"save"`, visit; untitled save is `None` |
| [`../viewport/`](../viewport/) | `ensure-visible` then `frame`; runner passes Term `columns` / `rows` |
| [`../undo/`](../undo/) | Ctrl-Z; history on the editor |
| Demo | [`../demo.md`](../demo.md) — save is silent; no status line |

**Why this layer:** you cannot see the path or tell Ctrl-S from a
no-op. That is the sharp edge for *using* the editor. Safe
display of `ESC`/tab and quadratic `split-lines` are **separate**
explorations after this spec exists.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **One reserved row** (last row of the screen, unless you
   justify the first). Text, point, and `ensure-visible` use the
   remaining rows (`rows - 1` when `rows >= 2`). The cursor never
   sits on the echo row.
2. The echo shows, at least:
   - untitled vs the bound path's `text`
   - a distinct indication after a **successful** save
   - a distinct indication after a **failed** save (untitled
     Ctrl-S or `Fs.write` `None`)
3. **Tests first**, no TTY, under `tests/aloemacs/`. At least:
   - untitled frame contains a documented untitled label
   - visit then frame contains the path string (clipped if you
     clip)
   - `"save"` of a bound session then frame contains the success
     indication
   - untitled `"save"` then frame contains the failure
     indication, not the success one
   - after Down until the old last screen row, the cursor is
     still in the **text** region (echo did not steal that row
     from `ensure-visible`)
   - existing movement/undo/visit goldens that assume the full
     window is text are updated or given `rows` that still fit
4. No minibuffer typing, no prefix map, no dirty `*` unless §4.7
   adds it. No Term method changes. No `lib/string.aloe` rewrite.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Session owns path; echo is a view of the session

`AloemacsSession` already has `path` and `save`. The echo line
is painted when the **session** frames, not as a second Term
write. The editor still paints the text rectangle. Do not
duplicate `Path` onto `AloemacsEditor`.

### 4.2 Fit against the text rectangle

The runner still queries full Term `columns` / `rows` and
`ensure-visible` then `frame`. Those session sends must treat
**text rows** as `rows - 1` (when `rows >= 2`) so point cannot
be fitted onto the echo row. Horizontal origin is unchanged
(full `columns`, or clip the echo independently — §4.6).

### 4.3 Full frame, one `write`

Still one `(term write …)` of the whole ANSI string. Echo is
more lines in that string, not a host status API.

### 4.4 Where code may live

- `examples/aloemacs/file.aloe` (session frame, save messages,
  constructor)
- `examples/aloemacs/editor.aloe` only if the text `frame` must
  take an explicit text-row count already implied by the
  session (prefer **not** adding echo fields on the editor)
- `examples/aloemacs/main.aloe` if the session constructor
  gains a field
- `host/racket/aloemacs-run.rkt` only if the fit/frame order
  must pass different sizes (prefer session hiding `rows - 1`)
- Tests under `tests/aloemacs/`
- [`../demo.md`](../demo.md) — one short note: echo row, what
  save prints (the human may do this in the same series)
- Not `lib/text.aloe`, `lib/string.aloe`, Term, Fs host, Gel,
  `aloe/eval.rkt`

### 4.5 Out of this layer

- Rendering `ESC` / tab / `CR` as visible cells (next display
  exploration)
- Faster `split-lines` / `to-string` (string load/save
  exploration)
- Minibuffer, `find-file`, prefix `C-x`, windows
- Dirty bit unless §4.7 explicitly adds a one-character mark
- `scroll-margin`, mode names, line/col in the echo (optional
  in §4.6, not required)

### 4.6 What the row contains (resolve this)

Name the exact strings (and clipping):

- Untitled label (e.g. `"untitled"` or `"**scratch**"` — pick
  one; not a Gel/Emacs clone requirement)
- Bound path: `(path text)` as stored (resolved). If longer
  than `columns`, clip (left, right, or ellipsis — name it)
- Success save vs failed save vs idle (path only). Idle after
  visit should show the path without claiming `"saved"`

ANSI: the echo may be plain text on the last row after the
text body and `"\r\n"`. Inverse video is allowed if you specify
the bytes; not required.

`rows = 1`: only echo, or refuse to steal the only row? Pick
one. Tests may use 4×8 as today plus one extra row for echo.

### 4.7 Message lifetime and dirty (resolve this)

After a successful save, does `"saved"` (or your token) stay
until the next **edit**, the next **any key**, or until the
next save? Failed untitled save: same question.

File spec has **no dirty bit**. Default: do not add `*` dirty.
If you add it, it is one character on the echo, set on
insert/newline/backspace, cleared on successful save, and tests
must show it. Prefer **no dirty** unless the row is empty
without it.

Undo after save: if there is no dirty bit, do not invent one
for undo.

### 4.8 Constructor and forwarding (resolve this)

If the session grows an echo `String` (or `Option String`)
field, `main.aloe` and every `AloemacsSession new` in tests
change. Name the default (empty or untitled label).

`handle-key` `"save"` already cases `save`. Set the echo on
both `Some` and `None`. Other keys: §4.7.

Do not add echo sends on `AloemacsEditor` unless you cannot
compose in `session.frame`.

## 5. Authority

- [`../README.md`](../README.md)
- [`../file/spec.md`](../file/spec.md) — path, save `Option`,
  no dirty (unless §4.7)
- [`../viewport/spec.md`](../viewport/spec.md) — fit then frame
- [`../demo.md`](../demo.md) — current silent save
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
- [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt)

`SPEC.md` remains language law. This spec is not language law.

## 6. Non-goals

- Safe control-character display
- `String.split-lines` / `to-string` performance
- Minibuffer, search, prefix maps, windows
- Changing Ctrl-S / Escape / Ctrl-Z bindings
- Kernel or Term changes
