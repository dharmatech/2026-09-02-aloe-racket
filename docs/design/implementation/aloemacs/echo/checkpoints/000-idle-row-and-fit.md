# aloemacs-echo 000 — Idle row and text-height fit

**Status.** Ready to implement.

## Goal

Give `AloemacsSession` an idle echo field, paint the bound path or
`untitled` on the last terminal row, and fit its editor within the remaining
text rows. Preserve one complete frame and one Term write per runner
iteration.

Stop after the idle row and fit tests pass. Ctrl-S still leaves the echo idle
in this checkpoint. Save outcome messages and their lifetime belong to
aloemacs-echo 001.

## Authority and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-echo 000**, the first local checkpoint of the
  **aloemacs-echo** series. There is no predecessor echo checkpoint. The
  implemented File, Viewport, and Undo layers are predecessors.
- Governing sections are spec §1–3, §4's session field and idle transition
  rules, §5's text rectangle and frame contract, §6 “Layer 000,” and §7.
  The save-message transition in §4 and Layer 001 of §6 are later work.
- The project root for code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. `SPEC.md` governs Aloe
  syntax and checking. In particular, evaluation is message send, selectors
  are literal, and a function object runs only through `call`.
- The current session has three fields (`editor`, `fs`, `path`) and delegates
  its full-height frame and fit to the editor. The runner already gets Term
  dimensions, fits the session, writes one frame, and reads a key in that
  order. Keep the runner's order and API.

## Exact file scope

### May edit

- `examples/aloemacs/file.aloe`
- `examples/aloemacs/main.aloe`
- `tests/aloemacs/echo-session.rkt` (new)
- `tests/aloemacs/echo-runner.rkt` (new)
- `tests/aloemacs/file-session.rkt`
- `tests/aloemacs/runner.rkt`
- `tests/aloemacs/file-runner.rkt`
- `tests/aloemacs/viewport-editor.rkt` (session fixtures and session-frame
  assertions only)
- `tests/aloemacs/viewport-runner.rkt`
- `tests/aloemacs/undo-session.rkt`
- `tests/aloemacs/visited-unchanged.rkt`

In existing tests, change constructor fixtures and exact full-session or
runner frame goldens only where the fourth field or reserved row changes
them. Retain the old assertions about movement, undo, visit, save effects,
and ANSI byte order. Direct `AloemacsEditor.frame` goldens, including those
in `viewport-editor.rkt`, remain unchanged.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `host/racket/aloemacs-run.rkt`, every
  other host file, Term and Fs implementations, `lib/text.aloe`,
  `lib/string.aloe`, other libraries, Gel, and `aloe/eval.rkt`
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, the accepted echo spec,
  earlier aloemacs checkpoints, project maps, and `demo.md`
- All other product and test files

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager rather than widening the slice.

## Required session state and behavior

Append exactly one `String` field after `path` in `(AloemacsSession H)`:

```aloe
(fields
  (editor AloemacsEditor)
  (fs (Fs H))
  (path (Option Path))
  (echo String))
```

The checked constructor is
`(AloemacsSession new editor fs path echo)`. Initialize `echo` to `""` in
`main.aloe`; the empty string is idle, while the visible label is derived
from `path` at frame time. Every ordinary rebuild, including `with-editor`
and `ensure-visible`, preserves the exact echo payload. A successful `visit`
returns a new session with `echo = ""`, for both existing and eligible
missing files. A refused visit returns `None` without changing its receiver.
Direct `save` retains its existing `Option` contract and preserves all
session fields on success. The current `handle-key` save branch remains
unchanged in this slice; a successful or refused key save does not yet create
a status message. No editor field, editor send, or path copy is added.

For positive `columns` and `rows`, define `text-rows` as `rows - 1` when
`rows >= 2`, otherwise `rows`. `session.ensure-visible(columns, rows)` sends
`ensure-visible(columns, text-rows)` to its editor, then returns a rebuilt
session with the same `fs`, `path`, and `echo`. `session.frame(columns, rows)`
is pure and uses the already fitted editor. The runner continues to pass
full Term dimensions; no row arithmetic moves into the runner.

When `rows >= 2`, send `frame(columns, text-rows)` to the editor. Its exact
complete frame is the prefix of the session frame. Append this suffix, with
no extra CRLF or second terminal write:

```text
ESC[?25l  ESC[rows;1H  shown-row  ESC[text-cursor-row;text-cursor-colH  ESC[?25h
```

Here `label` is `"untitled"` when `path` is `None`; otherwise it is the
stored, resolved `(path text)`. Application transitions produce only the idle
echo in this checkpoint, so their `shown-row` is the first `columns`
characters of `label`, clipped on the right with `String.take`. The status
prefix mapping for non-idle echo values is completed in aloemacs-echo 001.
The echo has no fill character, ellipsis, inverse video, or extra path
state. The prior full-screen clear leaves remaining cells blank.
`text-cursor-row = point.line - editor.scroll-row + 1` and
`text-cursor-col = point.column - editor.scroll-col + 1`, using the fitted
editor. The cursor ends inside the text rectangle. At `rows = 1`, pass the
single row to editor fit and frame and append no suffix; the echo payload
survives for a later resize.

## Focused tests

Write the new tests and update affected fixtures before changing product
code. Use checked Aloe drivers, Fs and Term doubles, and no physical TTY.

In `echo-session.rkt`, prove:

1. The checked four-field constructor accepts a `String` echo and rejects
   the old three-field arity and a non-String fourth argument. The initial
   session's echo is `""`, and both untitled and bound sessions have the
   expected checked type.
2. `with-editor`, direct editing, `ensure-visible`, and direct `save` preserve
   the echo payload and other session fields; the original immutable session
   remains unchanged. Successful visits to a regular file and an eligible
   missing location reset a prior echo to `""`; refused visits leave the
   receiver unchanged.
3. Compare complete frames for idle `untitled`, the stored resolved path,
   right clipping at narrow width, exact row addressing and cursor restore,
   and blank text-row padding. At 8 columns, `untitled` is complete and
   `/cwd/a.txt` appears as `/cwd/a.t`.
4. At 8 columns by 4 rows, Down to source line 3 fits into three text rows:
   scroll row is 1, text cursor row is 3, and the echo is on row 4. Up to
   source line 2 retains scroll row 1 and moves the text cursor to row 2.
   At one terminal row, the session frame equals the editor frame, leaves
   text visible, and adds no echo suffix.
5. At this checkpoint, both successful and refused `handle-key "save"`
   leave the idle echo unchanged while keeping their prior filesystem and
   editor behavior.

In `echo-runner.rkt`, use a scripted Term double to prove first frames for
untitled and visited sessions, one write of one complete ANSI string per
iteration, one `columns` and one `rows` query per iteration, full Term
dimensions passed through the runner, and the reserved row's effect on
viewport movement. The double does not need a TTY. Update existing runner
frame goldens to the three-text-row body and appended echo suffix. If a
predecessor test needs its former four-text-row scenario, give it one extra
terminal row rather than weakening its movement assertion.

Update every permitted direct session constructor fixture with the fourth
argument, including checked negative arity tests and exact `main.aloe`
source expectations. Keep direct editor goldens unchanged. Do not assert
`saved: `, `failed: `, or save-message clearing yet.

## Verification and completion

From the project root, run:

```sh
raco test tests/aloemacs/echo-session.rkt tests/aloemacs/echo-runner.rkt
raco test tests/aloemacs
```

The checkpoint is complete when its checked session and runner tests pass,
the existing aloemacs suite is green with full-frame and predecessor
assertions intact, and only the permitted files changed. A manual TTY look
is optional and does not replace automated evidence. Report test results
and files changed, then stop for human review. Do not start
aloemacs-echo 001.

## Explicit non-goals

- Save outcome messages, message lifetime, a dirty bit, or automatic save
- A second Term write, a runner API change, ANSI assembly in the runner, or
  a change to the editor's direct frame behavior
- Safe control-character display, pathname sanitization, tab-width policy,
  or faster string load/save
- Minibuffer input, `C-x`, additional buffers or windows, mode names, Boids,
  language forms, kernel changes, or global checkpoints
