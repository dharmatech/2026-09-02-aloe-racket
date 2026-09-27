# Charter — aloemacs viewport

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification that
**remembers the visible origin and scrolls only when point would
leave the window**, so Up from the last screen row moves the
cursor up the screen. Then **stop**. Do not write checkpoints.
Do not implement. Do not specify windows, `scroll-margin`,
recenter, wrap, or a paint cache.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.7.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-viewport 000**, … under
   `docs/design/implementation/aloemacs/viewport/checkpoints/`.
4. Stop. The human reviews it. Do not write those checkpoint files.

Keep the spec **small enough to slice**. e's wrap-aware
`scroll-window!`, Legmacs `C-l` / scroll-anchor, and a second
window are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../loop/`](../loop/) | Point-anchored `frame`: `top = max(0, point.line - (rows - 1))` |
| [`../index/`](../index/) | Zipper `Text`; `frame` walks visible rows; **no stored viewport** on the editor |
| [`../file/`](../file/) | Session forwards editor commands; runner frames then `handle-key` |

**Observed (do not re-litigate):** After Down has placed point on
the last screen row, Up still keeps it there. Loop §6 derives
`top` from point every frame, so the cursor never walks the
interior. Index reused that formula. Horizontal `left` is the
same shape.

This layer **reopens** Index's "no persistent viewport" and
Loop's derived origin. Movement, zipper, File, and full-frame
bytes (ANSI, clip, pad) stay. Only *which* origin `frame` uses
changes.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Stored origin.** The editor (or a documented wrapper) holds
   an immutable first-visible line and column. Nested edit is
   rebuild. Initial origin is `(0, 0)` for an empty or visited
   buffer at point `(0, 0)`.
2. **Legmacs `ensure-visible`.** Given positive `columns` and
   `rows`:
   ```text
   if point.line < top:           top := point.line
   if point.line >= top + rows:   top := point.line - rows + 1
   else:                          keep top
   ```
   Same for `point.column` and `left`. Then clamp `top`/`left`
   so they are nonnegative. Do **not** use Loop's
   `point.line - (rows - 1)` as the steady-state origin. Do
   **not** keep a `scroll-margin` (e's default 8).
3. **Fit when size is known.** Commands stay
   `(handle-key key) -> editor`. They do not receive
   `columns`/`rows`. A separate pure send (name it) takes those
   `Int`s and returns a new editor with the origin adjusted.
   `frame` paints from that origin. The runner (or Aloe main)
   fits, then writes the frame, then reads a key — same order
   as Legmacs `scroll-to-fit` then render.
4. **The reported Up path.** On a small fixture (for example
   4 rows, more lines than that), Down until point is on the
   last screen row, then Up: **screen cursor row decreases**
   and `top` stays until point would leave the top. Existing
   Index/Loop **behavior** tests that encode the old origin
   formula must be updated to the new goldens; do not keep the
   old frames as law.
5. No TTY required for tests. No windows, wrap, `C-l`, paint
   cache, mutation, or kernel `Vector`.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Copy Legmacs `ensure-visible`, not e's window

Seam: stored `:scroll-row` / `:scroll-col`, adjust only if the
cursor is outside `[origin, origin + size)`. Paint from that.
Do not copy minibuffer `:scroll-anchor`, `C-l` recenter, tab
display-columns, wrap segments, sticky rows, or `scroll-margin`.

### 4.2 Full frame, zipper, File, keys

`(term write (editor frame columns rows))` stays one `String`.
Index `Text` still owns line focus. Visit/save/`to-string`
unchanged. `"up"` / `"down"` still move **point**; the view
follows only via ensure-visible.

### 4.3 Immutability

New origin fields are ordinary constructor payloads. No `set!`.
The runner may rebind `aloemacs-editor` after fit, as it already
does after `handle-key`.

### 4.4 Where code may live

- `examples/aloemacs/editor.aloe` (fields, ensure-visible,
  `frame` origin)
- `examples/aloemacs/file.aloe` if the session must forward
  new fields or the fit send
- `examples/aloemacs/main.aloe` — it constructs the starting
  `AloemacsEditor` / `AloemacsSession`; any constructor arity
  change must be applied there
- `host/racket/aloemacs-run.rkt` and tests that drive the
  runner loop, so fit happens before `frame` with Term size
- Tests under `tests/aloemacs/`
- Not `lib/text.aloe`, Term, Fs, Gel, `aloe/eval.rkt`

### 4.5 Out of this layer

- Windows / per-pane views
- `scroll-margin`, recenter, page-up/page-down as new keys
  (if those keys already exist, they still only move point;
  fit still runs before paint)
- Incremental paint, wrap, `wcwidth`
- Mutation, compiler, `Vector`

### 4.6 Sends and fields (resolve this)

Name the origin fields (`top`/`left` vs `scroll-row`/`scroll-col`)
and the fit selector (`ensure-visible`, `fit`, …). Arity is
`(columns Int) (rows Int) -> same editor class`.

The session currently wraps the editor. Either:

1. Origin lives on `AloemacsEditor`; the session forwards fit
   and `frame`, **or**
2. Origin lives on `AloemacsSession` only.

Pick one. Do not store origin in two places. `AloemacsEditor`
constructor arity will change if (1); the session constructor
will change if (2). Update `examples/aloemacs/main.aloe` and
every test that sends those constructors.

`frame` remains `-> String` and does **not** itself return a
new editor. Fit is a prior send. Do not hide fit inside `frame`
without a new editor value — then the origin would never stick.

### 4.7 Runner and resize (resolve this)

The Racket loop today is: write `frame`, `handle-key`, until
quit. Specify the new sequence, including the first frame
before any key (fit with current Term size, then write).

On SIGWINCH-as-query (size is read each iteration, resize is
still not a `read-key` event): the next fit uses the new
`columns`/`rows`. If point is still in the new window, keep
origin (clamped). If not, ensure-visible shifts it. Name that.

Tests that inject a Term double and drive the runner must fit
too, or they will keep the old “cursor glued to the bottom”
frames.

## 5. Authority

- [`../README.md`](../README.md)
- [`../loop/spec.md`](../loop/spec.md) §6 — **supersede the
  origin formulas only**; keep ANSI, clip, pad, cursor
  one-based
- [`../index/spec.md`](../index/spec.md) — zipper; reopen
  “no persistent viewport”
- [`../file/spec.md`](../file/spec.md) — session / runner skin
- [`examples/aloemacs/editor.aloe`](../../../../../examples/aloemacs/editor.aloe)
- [`host/racket/aloemacs-run.rkt`](../../../../../host/racket/aloemacs-run.rkt)
- Legmacs `buffer.lg` `ensure-visible` and `render.lg`
  `scroll-to-fit` — seam catalog
- Chez Emacs `paint.sls` `scroll-window!` — catalog only;
  do not take `scroll-margin` or wrap

`SPEC.md` remains language law. This spec is not language law.

## 6. Non-goals

- Multiple windows
- Emacs recenter / `scroll-conservatively` / `scroll-margin`
- Horizontal wrapping
- Faster zipper (Index already did that)
- Paint cache, dirty rectangles
- Changing Ctrl-S, Escape, or visit/save
