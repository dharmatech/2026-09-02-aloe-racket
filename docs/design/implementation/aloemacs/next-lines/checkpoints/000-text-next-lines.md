# aloemacs-next-lines 000 — `Text.next-lines`, drop `render-rows`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Walk visible zipper lines on `Text`. Clip, pad-as-slots, and
`"\r\n"` stay in `frame`. Delete `AloemacsEditor.render-rows`.
ANSI goldens stay. Stop.

Do not add `"\r\n"` or CSI on `Text`. Do not add class methods.
Do not rewrite `frame-ansi`, `fit-origin`, or `ensure-visible`.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. `SPEC.md`
governs sends. `Text` zipper is Index (`focus-down`,
`current-line`, `has-next?`). Viewport `frame` paints `rows`
from `scroll-row` after `focus-at`. `List` `map` / `fold` are
`lib/list.aloe`.

- Identity is **aloemacs-next-lines 000**. Predecessor:
  **aloemacs-viewport-top 000** (landed: `frame` uses
  `(focused focus-at top)`, then `render-rows`).
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today `render-rows` on the editor never reads editor fields;
  `self` is the row loop. It clips with `drop`/`take`, pads with
  `""` when `has-next?` is false, and joins with `"\r\n"`.

## Exact file scope

### May edit

- `lib/text.aloe` — add `(next-lines (n Int) (List String))` only
- `examples/aloemacs/editor.aloe` — delete `render-rows`; change
  `frame` only as specified
- `tests/aloemacs/next-lines.rkt` (new)
- Existing `tests/aloemacs/` files **only** if a method table
  names `render-rows` and must drop it. Do not rewrite frame
  goldens that still hold.

### Must leave untouched

- `lib/int.aloe`, `lib/list.aloe`, `aloe/*.rkt`, Term, Fs, Gel,
  runner, `SPEC.md`, Index/Viewport specs
- `frame-ansi`
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion.

## Required behavior

### `Text.next-lines`

```aloe
(next-lines (n Int) (List String) ...)
```

- `n <= 0` → `(List empty)`.
- `n > 0` → **exactly `n` strings.** Current line first, then
  `focus-down`. After EOF, remaining elements are `""` (window
  slots, not `"\r\n"`). A cold `from-string` value indexes the
  same way `current-line` does (`indexed-value`).
- Do not `split-lines` the whole source on an indexed value.
- Do not append `"\r\n"` or clip with `drop`/`take`.

Empty document: one empty line, then `""` pads. Example:
`(Text from-string "") next-lines 3` → `""`, `""`, `""`.
`(Text from-string "ab\nc") next-lines 4` → `"ab"`, `"c"`,
`""`, `""`. After `(focus-at 1)` of that text, `next-lines 2`
→ `"c"`, `""`.

### `frame`

After `Some (at-top)`:

1. `(at-top next-lines rows)` (Term / tests use `rows >= 1`;
   if `rows < 1`, empty body and skip `next-lines`).
2. `map` each string with
   `(fn (line) ((line drop left) take columns))`.
3. Join with `"\r\n"` via `fold` on `rest` with `first` as the
   seed (one row → just `first`; `rows >= 1` so the list is
   nonempty).
4. Existing `frame-ansi`.

No `render-rows`. `(editor render-rows …)` is a type error.

Fitted-frame bytes, cursor math, keys, undo, and visit stay.

## Tests

New `tests/aloemacs/next-lines.rkt`, checked `make-driver`, no
TTY:

- `next-lines` types `(Int) -> (List String)`
- Goldens above (`""`, `"ab\nc"`, `focus-at`, `n <= 0`)
- Indexed value does not depend on rebuilding `(text lines)`
  for the check (compare element strings)
- Sending `render-rows` to an `AloemacsEditor` is a type error
- One small fitted `frame` still matches an existing golden
  (reuse a fixture from `viewport-editor.rkt` / `frame.rkt` if
  easy; do not duplicate a huge ANSI literal unless needed)

Keep `raco test tests/aloemacs` green, especially
`viewport-editor.rkt`, `frame.rkt`, `index-002-frame.rkt`,
`viewport-top.rkt`.

## Verification and completion

From the project root:

```sh
raco test tests/aloemacs/next-lines.rkt
raco test tests/aloemacs
```

If those are green, `raco test tests`. `git diff --check` clean.

Stop. Do not start `frame-ansi`. Do not issue 001.
