# aloemacs-alternate-screen 000 — Enter and leave the alternate screen

**Status: Ready to implement.**

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Run the editor on the terminal's alternate screen. The runner enters
it before the first frame and leaves it when the editor returns, on
normal quit and when an exception leaves the editor.

Why: Ptyxis, the Ubuntu default terminal, is built on VTE. VTE gives
the alternate screen no scrollback, and its overlay scrollbar appears
on hover only when there is something to scroll. Today the editor
paints on the main screen with the shell's history still above the
frame, so the bar appears as soon as the pointer enters the pane.
Leaving the alternate screen also puts the shell back as it was
before launch and keeps the editor's frames out of its history.

Do not add a reset-attributes byte, a cursor byte, bracketed paste,
or any other mode. Do not clear the screen from the runner. Do not
start wheel scrolling. Do not issue 001.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs Aloe sends and types.

- Identity is **aloemacs-alternate-screen 000**. No predecessor in
  this folder. This is not aloemacs-mouse 001, not a loop
  checkpoint, and not a global checkpoint.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- The term charter at [`../../term/charter.md`](../../term/charter.md)
  refused an alternate-screen host method and left the policy out of
  its layer. The loop spec at [`../../loop/spec.md`](../../loop/spec.md)
  lists alternate-screen policy as a non-goal. The mouse spec at
  [`../../mouse/spec.md`](../../mouse/spec.md) settled where a mode
  that brackets the run lives: in the runner, as terminal setup,
  outside the frame string and outside any Aloe send. This checkpoint
  follows the mouse rule. Do not send it back for the loop non-goal.
- `run-aloemacs` in `host/racket/aloemacs-run.rkt` wraps
  `run-aloemacs-with-term` in a `dynamic-wind` inside the procedure
  `call-with-tty-term-receiver` runs. Its before thunk writes
  `\e[?1000h\e[?1006h` and flushes. Its after thunk writes
  `\e[?1000l\e[?1006l` and flushes. The after thunk does not catch
  the editor's exception.
- `call-with-tty-term-receiver` in `host/racket/term.rkt` is
  `with-term` of `make-tty-term`. `make-tty-term` only puts the
  terminal into raw mode. `with-term` writes nothing on entry. On the
  way out, normal or exceptional, its cleanup writes mouse off
  (`1003` and `1006`), show cursor, and `\e[?1049l`, through
  tui-term's `term-disable-mouse`, `term-show-cursor`, and
  `term-normal-screen`. It never writes `\e[?1049h`. The missing half
  is the enable.
- Every frame begins with hide cursor, `\e[2J`, and home, and ends
  with show cursor. `2J` erases the visible display and does not touch
  scrollback. The frame string does not change in this slice.
- The runner source today contains no `1049`, no `[2J`, no
  `term-alternate-screen`, and no `term-normal-screen`.

## Exact file scope

### May edit

- `host/racket/aloemacs-run.rkt` — the before and after thunks of
  that `dynamic-wind`, and the comment above `run-aloemacs`, only
- `tests/aloemacs/alternate-screen.rkt` (new)

### Must leave untouched

- `examples/aloemacs/file.aloe`, `editor.aloe`, `main.aloe`, and
  every other product file
- `host/racket/term.rkt`, `host/racket/gel-run.rkt`,
  `host/racket/term-run.rkt`, `lib/`, `SPEC.md`, `CHECKPOINTS.md`,
  and every `spec.md`, `charter.md`, and checkpoint outside this
  folder
- tui-term, including `term-syntax.rkt` and `vt-output-port.rkt`
- `run-aloemacs-with-hosts`, `run-aloemacs-with-term`, and
  `call-with-tty-term-receiver`
- Every existing test, including `tests/aloemacs/mouse.rkt`,
  `tests/aloemacs/runner.rkt`, and `tests/aloemacs/file-runner.rkt`

If another file is necessary, stop and send this checkpoint back.
Do not widen the slice. A failure in an existing test stops the slice
too. Report it. Do not edit a test to force the suite green.

## Required behavior

The before thunk writes these bytes in this order, then flushes:

```text
ESC [ ? 1 0 4 9 h ESC [ ? 1 0 0 0 h ESC [ ? 1 0 0 6 h
```

The after thunk writes these bytes in this order, then flushes:

```text
ESC [ ? 1 0 0 0 l ESC [ ? 1 0 0 6 l ESC [ ? 1 0 4 9 l
```

The alternate screen is entered first and left last. The runner's
mouse modes are set and cleared inside it, and the runner leaves the
mode it turned on. One `write-string` per thunk or one per sequence
are both fine; the order of the bytes on the port is what is
specified. Spell ESC as `\e` or `\x1b` in the Racket string. The
runner tests forbid the backslash-u spelling of ESC and forbid
`write-line` anywhere in the runner source. Write with `write-string`
or `display`, then `flush-output`.

`with-term` then repeats its own cleanup: mouse off, show cursor,
`\e[?1049l`. That second `\e[?1049l` arrives on the normal screen
with the cursor unmoved since the first and does nothing visible. It
is the same doubling the `1006` disable already has. Leave it.

Write the bytes by hand. Do not call `term-alternate-screen` or
`term-normal-screen`. Do not write `\e[2J` or any other clear in a
thunk; the first frame clears the alternate screen. Do not add bytes
to the frame string. Scripted runs through `run-aloemacs-with-hosts`
never enter the `dynamic-wind` and write no `1049` bytes.

The order on the port at entry is therefore: raw mode from
`make-tty-term`, nothing from `with-term`, the before thunk, then the
first frame. The main screen is not cleared on the way in. The crash
printer in the `main` submodule runs after both the after thunk and
`with-term`'s cleanup, so its message lands on the restored shell
screen.

Update the comment above `run-aloemacs` so it names the alternate
screen along with button tracking. Name the modes by number in that
comment. Do not spell the bracket sequences there, so each bracket
phrase below occurs exactly once in the source.

## Tests

Write `tests/aloemacs/alternate-screen.rkt` before the product edit,
and watch it fail. No TTY. It reads source files with
`define-runtime-path` and `file->string`, in the shape of the source
test in `tests/aloemacs/mouse.rkt`. `tests/aloemacs/mouse.rkt` stays
as it is. Use `regexp-quote` for every phrase and
`regexp-match-positions` for order.

Prove, over the runner source:

1. `[?1049h` occurs exactly once and `[?1049l` occurs exactly once.
2. The position of `[?1049h` is before the position of `[?1000h`.
   This is the before thunk's order.
3. The position of `[?1049l` is after the position of `[?1000l`.
   This is the after thunk's order.
4. The position of `[?1049h` is before the position of `[?1049l`.
5. None of `term-alternate-screen`, `term-normal-screen`, or `[2J`
   occurs.

Prove, over `host/racket/term.rkt`, `host/racket/gel-run.rkt`, and
`host/racket/term-run.rkt`: `1049` does not occur in any of them.

Presence alone is not enough. Checks 2 and 3 are what fail if the
sequences land on the wrong side of the mouse modes.

## Hand check

The hand check is the human's, after the tests are green. The
implementer does not run it and does not report it. Run it in Ptyxis,
on a terminal at least 80 by 24, from the project root.

Rebuild first, then make a scratch file. A missing path errors inside
the editor's startup, after the alternate screen is entered and before
a frame is painted, so the file must exist before launch:

```sh
TMPDIR=/tmp raco make host/racket/aloemacs-run.rkt
```

```sh
cp SPEC.md /tmp/alternate-screen.txt
```

1. Run `ls` a few times so the shell has history. Move the pointer to
   the right edge of the pane and confirm the overlay scrollbar
   appears. That is the main-screen behavior before launch.
2. Launch:

   ```sh
   racket host/racket/aloemacs-run.rkt /tmp/alternate-screen.txt
   ```

3. Move the pointer over the mode line's `×` and along the right edge
   of the pane. No scrollbar appears.
4. Left-press `↕` on the mode line, then left-press `↔`. Each press
   splits the window. After each press, move the pointer over the new
   mode lines and the right edge. The bar stays hidden.
5. Quit with Escape. The shell's history and prompt are back exactly
   as they were before launch. No editor frame remains. The cursor is
   visible and the prompt accepts typing.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/alternate-screen.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

`git diff --check` is clean. The checkpoint is complete when both
commands pass and the diff check is clean. The hand check is the
human's and is not a completion condition. Stop. Do not issue 001. Do
not add a reset-attributes byte, cursor policy, bracketed paste, or
wheel scrolling. Do not edit tui-term, the frame string, or a spec.
