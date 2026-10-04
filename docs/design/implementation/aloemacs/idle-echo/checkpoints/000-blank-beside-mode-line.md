# aloemacs-idle-echo 000 — Blank idle echo beside a mode line

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Stop repeating the buffer name on the echo row when the selected
window already paints it on a mode line.

An idle echo payload is empty when the selected leaf's rectangle
is at least two rows tall. The echo address stays. The row stays
reserved. The mode line stays. A selected leaf shorter than two
rows still shows today's idle name, because that leaf has no mode
line. `saved:` and `failed:` stay. An active search stays. An
active prompt stays.

Do not add a face, a dirty mark, a position, a mode name, or a
key. Do not give the text area the echo row. Do not issue 001.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs Aloe sends and types.

This checkpoint supersedes the idle echo label in
[`../../echo/spec.md`](../../echo/spec.md) and
[`../../mode-line/spec.md`](../../mode-line/spec.md). Those files
still say an idle echo paints the path or `untitled`, including
the mode-line example of `"untitled ---"` above `"untitled"`.
That disagreement is the assignment. Do not send the checkpoint
back for it, and do not edit either spec.

- Identity is **aloemacs-idle-echo 000**. No predecessor in this
  folder. This is not aloemacs-mode-line 002 and not a global
  checkpoint.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Mode line and echo behavior already land in
  `examples/aloemacs/file.aloe`. `AloemacsModeLine.row` paints
  `(buffer name)`, a space, and `-` fill. A leaf paints that row
  when its rectangle height is at least 2. Terminal height 1 has
  no echo row. Terminal height 2 has an echo row and a one-row
  text rectangle, so it has no mode line.
- `AloemacsSession.frame` uses `single-frame` for one leaf and for
  the too-small-tree fallback. It uses `multi-frame` for a
  positive split. `single-frame` inlines echo selection.
  `multi-frame` sends `shown-echo`. Both idle branches paint the
  label from `(self path)`: `None` is `"untitled"`, and `Some` is
  `(path text)`. `(self path)` is the current buffer's path.
- Echo selection today is prompt, then active search
  (`failing: `, `wrapped: `, or `search: `, plus the query), then
  `saved: ` or `failed: ` plus the label, then the bare label.
  Clipping is `String.take` of the terminal width. Safe cells
  follow. Unused echo cells stay blank because the frame already
  cleared the screen.
- The stored tokens remain `""`, `"saved"`, and `"failed"`. `""`
  means idle. This slice does not change a token, a transition,
  or a lifetime.

## Exact file scope

### May edit

- `examples/aloemacs/file.aloe` — the echo payload only, as
  specified below
- `tests/aloemacs/idle-echo.rkt` (new)
- Existing files in `tests/aloemacs/` **only** to change an
  expected idle echo payload from the buffer name, or from a
  clipped prefix of that name, to `""` when that frame's selected
  leaf paints a mode line. A helper default such as
  `[echo "untitled"]` may change only for callers whose selected
  leaf paints a mode line. Callers whose selected leaf has no
  mode line keep the name, passed explicitly if the default
  changes.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `main.aloe`, and every other
  product file
- `lib/`, `host/`, `SPEC.md`, `CHECKPOINTS.md`, and every
  `spec.md`, `charter.md`, and checkpoint outside this folder
- Mode-line bytes, window geometry, fit, cursor rules, commands,
  and echo tokens

If another product file is necessary, stop and send this
checkpoint back. Do not widen the slice. A test failure whose
expected bytes differ by anything other than that idle payload
stops the slice too. Report it. Do not edit geometry or a
non-idle message to force the suite green.

## Required behavior

Replace `shown-echo` with one method both composers send. Do not
leave a second method that still paints the idle name.

```aloe
(echo-row (columns Int) (leaf-rows Int) String
  ...)
```

`leaf-rows` is the height of the rectangle whose mode line is
the selected window's mode line:

- `single-frame`, including the too-small-tree fallback, passes
  `(root rows)` from `text-rect`. That is terminal rows minus one
  when the terminal is at least two rows tall.
- `multi-frame` passes `(selected rows)` from `fit-rect` of the
  same columns and rows. That is the leaf height `frame-rows`
  already uses to decide that leaf's mode line.

Do not read the windows' remembered size. The frame arguments
decide.

Inside the method, keep today's prompt, search, `saved:`, and
`failed:` branches byte for byte, including the label, the
prefixes, `take`, and safe cells. Change only the remaining idle
branch:

- `leaf-rows >= 2`: the text before `take` is `""`.
- `leaf-rows < 2`: the text before `take` is today's label.

`""` taken and passed through safe cells is `""`. Write no
spaces and no dashes on that idle row. The composers still write
`ESC[rows;1H` before the payload whenever the terminal is at
least two rows tall, then the same cursor address they write
today. Terminal height 1 still returns the body with no echo and
no mode line.

A tall idle frame therefore matches today's frame except that
the echo payload is empty. The mode-line address and text stay.
The echo address stays. The final cursor stays in the text.

`saved:`, `failed:`, search, and prompt frames match today at
every size, including a tall window. A prompt still finishes on
the echo row. Search still finishes in the text.

## Tests

Write `tests/aloemacs/idle-echo.rkt` before the product edit, and
watch the tall idle cases fail. No TTY. A local frame builder is
fine. Do not require another test module. `mode-line-one-view.rkt`
and `mode-line-split-views.rkt` show the current chrome: the mode
line is separate from the echo payload, and a one-view mode line
is present only when the terminal height is at least 3.

Prove these frames:

1. One view, 12 columns by 4 rows, idle untitled. The mode line
   is today's name row. The echo payload is empty. The cursor
   stays in the text.
2. The same size after the current buffer has a path. The mode
   line shows that path. The echo payload is empty.
3. One view, 12 by 2, idle. No mode line. The echo payload is
   `untitled`, or the path text when a path is bound.
4. One view, 4 by 2, idle untitled. The echo payload is `unti`.
5. One view, height 1. The frame has no echo payload and no mode
   line.
6. One view, 20 by 4, tokens `"saved"` and `"failed"`. The echo
   payloads are `saved: ` and `failed: ` plus the label. The mode
   line is still the name.
7. One view, 20 by 4, active search and, separately, an active
   prompt. Those echo payloads match today. The mode line remains
   the name. The prompt cursor remains on the echo row.
8. A vertical split of a 4-row text rectangle, so the terminal is
   5 rows. The existing split arithmetic gives the top leaf 2
   rows and the bottom leaf 1 row. Give the two leaves different
   buffer names. With the top selected, the idle echo payload is
   empty and the top mode line shows the top name. With the
   bottom selected, the idle echo payload is the bottom buffer's
   name and the top mode line still shows the top name.
9. A vertical split whose text rectangle is 5 rows, so the
   terminal is 6 rows. Both leaves are 2 rows tall. The idle echo
   payload is empty. Each mode line shows its own buffer name.

Painting the same session twice leaves buffers, windows, text,
and the echo token unchanged.

Then update existing expectations under the file-scope rule.
Height 2 and height 1 idle names stay. `saved:`, `failed:`,
`search:`, `wrapped:`, `failing:`, and prompt text stay, including
their clipped forms.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/idle-echo.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
```

The checkpoint is complete when both commands pass and the tall
idle echo no longer repeats the name. Stop. Do not issue 001. Do
not edit a spec. Do not mark mode line or windows accepted. Do
not start faces or another feature.
