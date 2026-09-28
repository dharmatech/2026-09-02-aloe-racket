# aloemacs-line-length 000 — `line-length` on `Text`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Move focused-line length off `AloemacsEditor` and onto `Text`.
`(text line-length)` is `((self current-line) len)`. Editor call
sites send that to a focused `Text`, not `(self line-length text)`.
Remove the editor method that never uses `self`. Tests, then stop.

Do not move `clamp-column`, `max-zero`, or other helpers. Do not
add `Char`. Do not change zipper storage, `current-line`, or
movement rules.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs Aloe sends and types. `Text`
behavior stays as in
[`../../text/spec.md`](../../text/spec.md) and
[`../../index/spec.md`](../../index/spec.md): `current-line` is
the focused line `String` (via `indexed-value` on a cold value).
Column units remain `(s len)`.

- Identity is **aloemacs-line-length 000**. No predecessor in this
  folder. Text, Index, and the editor are implemented.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today, `examples/aloemacs/editor.aloe` has
  `(line-length (text Text) Int …)` whose body is
  `((text current-line) len)`, and call sites
  `(self line-length previous)` / `(self line-length focused)`
  / `clamp-column`'s `(self line-length text)`.
- `lib/text.aloe` already has `current-line`. It does not have
  `line-length`.

## Exact file scope

### May edit

- `lib/text.aloe` — add `(line-length () Int)` on `Text` only
- `examples/aloemacs/editor.aloe` — delete editor `line-length`;
  send `(text line-length)` from `clamp-column` and the movement /
  backspace sites that currently send `(self line-length …)`
- `tests/aloemacs/text-line-length.rkt` (new focused tests)
- Existing `tests/aloemacs/` files **only** if a type or method
  table names editor `line-length` and must drop it, or must name
  `Text.line-length`. Do not rewrite movement goldens.

### Must leave untouched

- Runner, Term, Fs, Gel, `aloe/eval.rkt`, `SPEC.md`,
  `CHECKPOINTS.md`, global checkpoints, other `lib/` files
- Viewport, undo, file, and index **specs** (prose that says
  “line-length helper” may stay stale until a later doc pass)
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion. Do not widen the slice.

## Required behavior

On `Text`:

```aloe
(line-length () Int
  ((self current-line) len))
```

It uses `self`. It must go through `current-line` (so a cold
`from-string` value is indexed the same way `current-line` already
does). Do not call `lines` or `to-string`.

On `AloemacsEditor`: **no** `line-length` method. After the
change, `(editor line-length text)` is an unknown send (type
error). `clamp-column` becomes:

```aloe
(clamp-column (column Int) (text Text) Int
  (let ((length (text line-length)))
    ...))
```

Call sites that had `(self line-length previous)` become
`(previous line-length)`. Same for `focused`.

Movement, backspace join-at-column-0, insert, frame, undo, visit,
and save **behavior** stay. This is a home for a send, not a new
feature.

## Tests

New `tests/aloemacs/text-line-length.rkt`, checked driver, no TTY:

- `(line-length () Int)` on `Text`
- empty focused line → `0`
- `"abc"` as current line → `3`
- after `focus-down` / `focus-at`, the length is the **new**
  current line
- cold `(Text from-string "ab\ncd")` `line-length` matches
  `current-line` then `len` (first line `2`, not the whole
  source)
- `(Text from-string "a\n")` current empty last line after
  `focus-at` of that line → `0`

Keep existing `tests/aloemacs/editor-keys.rkt` (and any other
movement tests) green. Optionally assert that sending
`line-length` to an `AloemacsEditor` is a type error.

## Verification and completion

From the project root:

```sh
raco test tests/aloemacs/text-line-length.rkt
raco test tests/aloemacs
```

If those are green, `raco test tests`. `git diff --check` clean.

Stop. Do not start `clamp-column`. Do not issue 001.
