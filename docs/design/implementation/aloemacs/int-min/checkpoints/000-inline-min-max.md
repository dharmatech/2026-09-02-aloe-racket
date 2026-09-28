# aloemacs-int-min 000 — inline `min` / `max` in the editor

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Delete `AloemacsEditor`'s `clamp-column` and `max-zero` methods.
Call sites use `Int` `min` / `max` from `lib/int.aloe` (already in
default environments). Movement, viewport fit, and all goldens stay.
Stop.

Do not put `clamp-column` on `Text`. Do not add class methods. Do not
change `fit-origin`'s nested `if` beyond replacing `(self max-zero …)`
with `(… max 0)`. Do not edit `lib/int.aloe`.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. `SPEC.md` governs
sends. `Int` `min` / `max` are the accepted
[`../../int-methods/spec.md`](../../int-methods/spec.md) library
methods, installed by default (`int-methods` 000–001).

- Identity is **aloemacs-int-min 000**. Predecessors: int-methods 001
  and aloemacs-line-length 000 (`Text.line-length`).
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today, `examples/aloemacs/editor.aloe` defines:

  ```aloe
  (clamp-column (column Int) (text Text) Int
    (let ((length (text line-length)))
      (if (column > length)
          length
          column)))

  (max-zero (value Int) Int
    (if (value < 0)
        0
        value))
  ```

  `move-up` / `move-down` send `(self clamp-column (point column)
  previous)` (or `next`). `fit-origin` sends `(self max-zero …)`.
- `editor.aloe` loads `lib/text.aloe` only. Do **not** add
  `(load …/int.aloe)`: `make-driver` already installs `min` / `max`
  on `Int`, the same way `starts-with?` is available without loading
  `string.aloe` from the editor.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` only as specified below
- `tests/aloemacs/int-min.rkt` (new focused tests)
- Existing `tests/aloemacs/` files **only** if a method/type table
  names editor `clamp-column` or `max-zero` and must drop those
  names. Do not rewrite movement or frame goldens.

### Must leave untouched

- `lib/int.aloe`, `lib/text.aloe`, `aloe/*.rkt`, Term, Fs, Gel,
  runner, `SPEC.md`, `CHECKPOINTS.md`, int-methods docs
- Viewport / loop / index **specs**
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion.

## Required behavior

Remove both editor methods.

`move-up` / `move-down` clamp with:

```aloe
((point column) min (previous line-length))
```

(and `next` on down). Same `Position new` as today.

`fit-origin` keeps its nested `if`. Replace only the
`(self max-zero expr)` wrapper with `(expr max 0)`.

After the change, `(editor clamp-column column text)` and
`(editor max-zero n)` are unknown sends (type errors).
`fit-origin` may remain a method even if it no longer sends to
`self`; do not delete it in this slice.

Up/down still clamp a too-large column to the destination line
length. `ensure-visible` still refuses a negative origin.
Insert, undo, save, frame bytes, and keys are unchanged.

## Tests

New `tests/aloemacs/int-min.rkt`, checked `make-driver`, no TTY:

- Sending `clamp-column` or `max-zero` to an `AloemacsEditor` is a
  type error
- A two-line fixture `"ab\nc"`: point at column 2 of the first
  line, `move-down`, point column is `1` (length of `"c"`)
- `move-up` from that position restores column `1` on `"ab"`
  (does not invent a clamp onto `Text`)

Keep `raco test tests/aloemacs` green, including `editor-keys.rkt`
and `viewport-editor.rkt`.

## Verification and completion

From the project root:

```sh
raco test tests/aloemacs/int-min.rkt
raco test tests/aloemacs
```

If those are green, `raco test tests`. `git diff --check` clean.

Stop. Do not start a `fit-origin` rewrite. Do not issue 001.
