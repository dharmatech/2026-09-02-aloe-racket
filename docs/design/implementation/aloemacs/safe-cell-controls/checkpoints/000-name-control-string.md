# aloemacs-safe-cell-controls 000 — Name the control string

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.
There is no `spec.md`. This discussion wrote this checkpoint.

## Goal

Give the 33-character control string in `AloemacsEditor.safe-cells`
a name, and keep that name outside the per-character walk.

The displayed characters stay as they are. Codes 0–31 and 127 still
paint as one space. Length stays the same. Save bytes, cursor
columns, and frame ANSI and CRLF stay unchanged.

Do not build the string from pieces. Do not add a kernel message.
Do not rewrite `take`, `drop`, or `append`.

## Why this shape

The literal is one membership set: U+0000 through U+001F, then
U+007F. Aloe has no code-point range, so the value stays one
string literal. A comment names the two runs.

`safe-cells` calls itself once per character. A `let` in that body
runs on every character. Evaluating a string literal returns the
string stored on the syntax object, so the current line does not
rebuild those 33 characters per cell. The name is for the reader.
The binding belongs where the file is loaded, once, before the
class is typechecked. The method then looks the name up.

Joining pieces with `append` inside `safe-cells` would copy a new
haystack on every character. That is the cost
[`../../safe-cell-scan/checkpoints/000-find-control-string.md`](../../safe-cell-scan/checkpoints/000-find-control-string.md)
removed. This slice does not put it back.

## Authority, identity, and starting point

The implementer receives **this checkpoint only**. It is the design
and the slice. `SPEC.md` governs sends. The observable display
contract remains
[`../../safe-cells/spec.md`](../../safe-cells/spec.md): after
clipping, codes 0–31 and 127 paint as one space, every other
character is copied, and the result has the same `len`. Do not
edit that spec. `find` is already a kernel String message.

aloemacs-safe-cell-scan 000 put this literal inline as the receiver
of `find`. This slice moves that same literal to a top-level name.
Do not edit the safe-cell-scan checkpoint. It records the repair
that landed. This checkpoint is the source shape from here.

- Identity is **aloemacs-safe-cell-controls 000**. No predecessor
  in this folder. Safe cells 000, safe-cell-scan 000, and search
  000–001 are implemented. This is not safe-cells 001 and not
  safe-cell-scan 001.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Today `examples/aloemacs/editor.aloe` defines `safe-cells` with
  the 33-character literal as the receiver of `find`, then
  `(self safe-cells (clipped-string drop 1))`.
- `examples/aloemacs/editor.aloe` is loaded into the same
  environment as `examples/aloemacs/file.aloe`. The name must be
  `safe-cell-controls`, not a generic `controls`.
- The class is typechecked when it is read. The define must appear
  textually before `(define-class AloemacsEditor`. A define after
  the class is not in scope for that check.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` — add the top-level define, and
  replace only the body of `safe-cells`. The method name, argument,
  and result type stay
  `(safe-cells (clipped-string String) String`.

### Must leave untouched

- `examples/aloemacs/file.aloe`, `main.aloe`, the runner, Term, Fs
- `lib/`, `aloe/`, `SPEC.md`, `CHECKPOINTS.md`
- [`../../safe-cells/spec.md`](../../safe-cells/spec.md) and the
  rest of that folder
- [`../../safe-cell-scan/`](../../safe-cell-scan/)
- `tests/aloemacs/safe-cells.rkt`,
  `tests/aloemacs/safe-cell-scan.rkt`, and every other test
- `frame`, `frame-ansi`, `next-lines`, scroll, point, and history
- This folder's `README.md`, the parent aloemacs map, and this
  checkpoint
- Every file not listed under **May edit**

If another file is necessary, stop and send this checkpoint back
to the high-level discussion. Do not widen the slice.

## Required behavior

After `(define-class UndoFrame …)` and before
`(define-class AloemacsEditor`, add this define. The string is one
literal. Its characters are U+0000 through U+001F and then U+007F,
in that order, the same characters as today's receiver of `find`.

```aloe
;; Codes 0–31, then 127. find uses this as a set.
(define safe-cell-controls
  "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\u0009\u000a\u000b\u000c\u000d\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f\u007f")
```

Replace the `safe-cells` body with this. `safe-cell-controls` is
the top-level name, in the receiver position of `find`. The pattern
is the one-character `cell`. The start index is `0`.

```aloe
(safe-cells (clipped-string String) String
  (if ((clipped-string len) = 0)
      ""
      (let ((cell (clipped-string take 1)))
        ((if ((safe-cell-controls find cell 0) present?)
             " "
             cell)
         append
         (self safe-cells (clipped-string drop 1))))))
```

The 33-character literal appears only as the value of
`safe-cell-controls`. It does not appear inside `safe-cells`. The
`let` binds `cell` only.

`""` still returns `""`. A printable character, including codes
128 and above, is still appended unchanged. `ESC` followed by
`[31m` is still a space followed by those four characters. The
frame still sanitizes only the clipped row, then joins with
`"\r\n"`. The echo label and the one-character search key still
use this same method.

## Tests

Do not add a test file. Behavior stays with
`tests/aloemacs/safe-cells.rkt`: all 33 controls, length, clipping,
the echo label, and a printable kept unchanged. The wide-frame bar
stays with `tests/aloemacs/safe-cell-scan.rkt`: the median of five
`(editor frame 80 24)` samples is strictly under 80 ms.

Do not weaken either file. Do not move cases between them. A `let`
of the literal inside `safe-cells` can still pass those tests. It
is the wrong shape. Follow the required source above.

If the median on this machine is 80 ms or more, stop and report the
number. Do not raise the bar. Do not start the `take` / `drop` /
`append` rewrite.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/safe-cell-scan.rkt
TMPDIR=/tmp raco test -y tests/aloemacs/safe-cells.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
```

If those are green, `TMPDIR=/tmp raco test -y tests`.
`git diff --check` clean.

The timing file's printed median is part of the result. Record it.

Stop. Do not issue 001. Do not issue safe-cells 001. Do not issue
safe-cell-scan 001.

## Non-goals

- Splitting the literal, or building it with `append`, `List of`,
  or `fold`
- Binding the literal with `let` inside `safe-cells`
- A field on `AloemacsEditor`, or a method whose body only returns
  the literal
- A new String or character-code message
- Replacing the recursive `take` / `drop` / `append` walk
- Changing `file.aloe`, the echo row, or search keys
- Editing the safe-cells spec, or the safe-cell-scan checkpoint
- A new test file, or a test that reads the method source
- `raco demod`, a resident process, or a change to launch commands
