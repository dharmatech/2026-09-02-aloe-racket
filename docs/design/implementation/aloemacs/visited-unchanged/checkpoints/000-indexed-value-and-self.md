# aloemacs-visited-unchanged 000 — `indexed-value` and `unchanged` as `self`

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Two tiny idiom fixes, then stop:

1. `AloemacsSession.visited` builds the buffer with
   `((Text from-string contents) indexed-value)`, not
   `focus-at 0` plus a `None` arm that reconstructs
   `from-string`.
2. `AloemacsEditor.unchanged` and `AloemacsSession.unchanged`
   return `self`. Do not rebuild an equal object field-by-field.

Do not change visit/save behavior, movement, frame, or undo.
Do not add `eq?`. Do not touch `with-editor` / `with-text-and-point`
(those still rebuild because fields change).

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. `SPEC.md`
governs sends. `Text.indexed-value` is Index / `lib/text.aloe`.
Immutable objects may return the receiver.

- Identity is **aloemacs-visited-unchanged 000**.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today `examples/aloemacs/file.aloe` `visited` is:

  ```aloe
  (AloemacsEditor new
    (((Text from-string contents) focus-at 0) case
      (None () (Text from-string contents))
      (Some (focused) focused))
    ...)
  ```

  Line 0 always exists on a `Text`, so `None` is dead.
  `indexed-value` is the conversion `focus-at 0` was faking.

- Today both `unchanged` methods copy every field into `new`.

## Exact file scope

### May edit

- `examples/aloemacs/file.aloe` — `visited` and session
  `unchanged` only
- `examples/aloemacs/editor.aloe` — editor `unchanged` only
- `tests/aloemacs/visited-unchanged.rkt` (new, optional if
  existing tests already cover visit at line 0 and no-op keys)
- Existing `tests/aloemacs/` **only** if a structural expectation
  assumed `unchanged` allocated a distinct object (unlikely).
  Keep visit/save/movement goldens.

### Must leave untouched

- `lib/text.aloe`, `lib/int.aloe`, `aloe/*.rkt`, Term, Fs, Gel,
  runner, `SPEC.md`, other editor methods
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion.

## Required behavior

`visited`:

```aloe
(AloemacsEditor new
  ((Text from-string contents) indexed-value)
  (Position new 0 0)
  #f
  0
  0
  (List empty))
```

(Keep the same `fs` / `path` wrapping as today.)

Editor and session:

```aloe
(unchanged () ...
  self)
```

Return type unchanged (`AloemacsEditor` / `(AloemacsSession H)`).
No-op keys, failed edits, and post-quit `handle-key` still send
`unchanged`; behavior stays. Visit of empty or nonempty contents
still focuses line 0.

## Tests

Existing `file-session.rkt` visit goldens (`focus-line` 0,
`to-string`) and editor no-op / `frame` “leaves source
unchanged” checks must stay green.

New `tests/aloemacs/visited-unchanged.rkt` only if useful:

- `(e unchanged)` has the same `text` / `point` / `quit` /
  origin / `(history len)` as `e`
- `visited` of `"a\nb"` has `focus-line` 0 and
  `current-line` `"a"`

Do not require pointer identity unless Aloe already exposes it
in these tests.

## Verification and completion

From the project root:

```sh
raco test tests/aloemacs
```

If green, `raco test tests`. `git diff --check` clean.

Stop. Do not start session-forwarding or `fit-origin`. Do not
issue 001.
