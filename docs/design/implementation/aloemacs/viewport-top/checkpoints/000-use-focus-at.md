# aloemacs-viewport-top 000 — `frame` uses `Text.focus-at`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Delete `AloemacsEditor.viewport-top`. `frame` walks to
`scroll-row` with `(focused focus-at top)`, which already exists
on `Text`. Keep ANSI goldens. Stop.

Do not add `viewport-top` on `Text`. Do not rewrite `render-rows`
or `frame-ansi`. Do not change `ensure-visible` or movement.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. `SPEC.md`
governs sends. `Text.focus-at` is
[`../../index/spec.md`](../../index/spec.md) / `lib/text.aloe`:
`(text focus-at line) -> (Option Text)`, walking `focus-up` /
`focus-down` from the current focus. Viewport `frame` paints from
stored `scroll-row` after a prior `ensure-visible`
([`../../viewport/spec.md`](../../viewport/spec.md)).

- Identity is **aloemacs-viewport-top 000**. Predecessors: Index
  zipper and Viewport stored origin.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today, `examples/aloemacs/editor.aloe` has:

  ```aloe
  (viewport-top (text Text) (top Int) Text
    (if ((text focus-line) = top)
        text
        (self viewport-top (text focus-up) top)))
  ```

  `frame` sends `(self viewport-top focused top)` then
  `render-rows`. That helper never reads editor fields; `self` is
  only the recursive call. If `top` is below the current focus,
  `focus-up` eventually returns `self` and the recursion does not
  terminate. `focus-at` returns `None`.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` — delete `viewport-top`; change
  `frame` only as specified
- `tests/aloemacs/viewport-top.rkt` (new focused tests)
- Existing `tests/aloemacs/` files **only** if a method/type table
  names editor `viewport-top` and must drop it. Do not rewrite
  frame goldens that still hold.

### Must leave untouched

- `lib/text.aloe`, `lib/int.aloe`, `aloe/*.rkt`, Term, Fs, Gel,
  runner, `SPEC.md`, Index/Viewport **specs**
- `render-rows`, `frame-ansi`, `fit-origin` (except that `frame`
  still calls `render-rows`)
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion.

## Required behavior

Remove `viewport-top`.

In `frame`, after a successful `(focus-at (point line))`, do not
send `viewport-top`. Send `(focused focus-at top)` and `case`:

- `None` — same empty-body `frame-ansi` already used when
  focusing point fails
- `Some (at-top)` — existing `(self render-rows at-top left
  columns rows #t)` then `frame-ansi`

`top` remains `(self scroll-row)`. After `ensure-visible`,
`top <= point.line` and `focus-at` of that line succeeds. Do not
add a second `ensure-visible` inside `frame`.

`(editor viewport-top text top)` is an unknown send (type error).

Fitted-frame ANSI, cursor math, clip, pad, and keys stay. Do not
“fix” unfitted frames beyond using `None` instead of diverging.

## Tests

New `tests/aloemacs/viewport-top.rkt`, checked `make-driver`, no
TTY:

- Sending `viewport-top` to an `AloemacsEditor` is a type error
- A fitted 4-row frame of several lines still matches the
  existing Up-from-last-row golden path (or an equivalent small
  fixture already in `viewport-editor.rkt` / `frame.rkt` — do not
  duplicate a huge ANSI string if you can `check-equal?` against
  the same construction those files use)
- **Must not hang:** construct an editor whose `scroll-row` is
  **greater** than `point.line` (raw constructor is allowed).
  `frame` of positive size must return a `String` (the empty-body
  ANSI), not loop. That is the `focus-at` `None` arm.

Keep `raco test tests/aloemacs` green, especially
`viewport-editor.rkt`, `frame.rkt`, and `index-002-frame.rkt`.

## Verification and completion

From the project root:

```sh
raco test tests/aloemacs/viewport-top.rkt
raco test tests/aloemacs
```

If those are green, `raco test tests`. `git diff --check` clean.

Stop. Do not start `render-rows`. Do not issue 001.
