# aloemacs echo specification

**Status: Accepted.** This file is the complete design input for the
aloemacs-echo checkpoint manager and implementers. It is local editor design,
not Aloe language law; `SPEC.md` remains the authority for Aloe syntax and
evaluation.

The session reserves the last terminal row for an echo of its path and the
outcome of the most recent Ctrl-S. The editor continues to paint only text.
The session composes one complete ANSI frame, and the runner still writes
that frame through Term once per iteration.

## 1. Checkpoint series

The identity is **aloemacs-echo**. The first checkpoint is spoken
**aloemacs-echo 000** and filed as `checkpoints/000-slug.md`; following
numbers have three digits, begin at 000, are never renumbered, and use
lowercase hyphenated slugs. The checkpoint manager writes only the next
checkpoint and stops. Each implementer builds and tests only that slice,
then stops when its tests pass. Product code and tests belong in the project
root `/home/dharmatech/journal/2026-09-02-aloe-racket`, never in this
design folder.

The intended order is:

1. **Row and fit (000).** Add the session's idle echo field, compose its
   idle row in `session.frame`, and fit the nested editor to the text rows.
   Direct no-TTY session and runner tests prove untitled/path display,
   clipping, cursor safety, and old viewport behavior with one fewer text
   row. Update constructor fixtures and affected full-frame goldens.
2. **Save messages (001).** Make `handle-key "save"` record success or
   failure, clear that message on the next non-save key, and test both
   outcomes and lifetime. Update affected save goldens and the short demo
   description.

Each layer is independently testable after its predecessor. A manager may
split an oversized layer into additional consecutive numbers, preserving
this order and adding no features. The manager must not issue both
checkpoints in one conversation.

## 2. Product boundary and authority

This remains a one-buffer terminal editor. The session owns the optional
resolved `Path`, filesystem capability, and new echo state. The nested
`AloemacsEditor` still owns text, point, quit, origin, and undo history; it
gets no echo field or send. The current `save` API and `Option` outcome remain
unchanged. There is no dirty bit, automatic save, prompt, mode line, or
second buffer. No file text or pathname sanitization is introduced here;
control-character display needs its separate design.

`../file/spec.md` governs path resolution, visit, `Fs.write`, `save`, and
key-to-save dispatch except for the visible status after the key. In
particular, direct `(session save)` retains its `Option` behavior and its
successful result preserves the session's field payloads. `../viewport/spec.md`
governs the minimal fit rule and editor text frame; this spec changes the
height passed through the session from full rows to text rows. The parent
`../README.md` governs the aloemacs project boundary. `SPEC.md` wins for Aloe
language behavior. Existing `examples/aloemacs/file.aloe`,
`editor.aloe`, `main.aloe`, and `host/racket/aloemacs-run.rkt` are the
implementation starting points. When earlier specs describe the old
session constructor, direct frame delegation, or a full-height session
text rectangle, this spec supersedes those clauses only.

The File, Viewport, and Undo layers are implemented predecessors. Text
rendering, movement, undo, visit, save effects, and key bindings keep their
current meanings. This series does not amend `SPEC.md`, `CHECKPOINTS.md`,
Term, Fs host, Gel, `lib/text.aloe`, `lib/string.aloe`, or `aloe/eval.rkt`.
It does not start Boids, safe control-character display, tab-width policy,
faster string load/save, minibuffer input, `C-x`, windows, or mode names.

## 3. Host, layout, and commands

The implementation is checked Aloe 0.1 in
`examples/aloemacs/file.aloe` and `examples/aloemacs/main.aloe`. The
Racket runner stays the effect skin and retains its current arities and
fit-then-frame order; no runner edit is required. `editor.aloe` also remains
unchanged. Tests use checked drivers, Fs and Term doubles, and no TTY, under
`tests/aloemacs/`. The existing terminal run commands are
`racket host/racket/aloemacs-run.rkt` and
`racket host/racket/aloemacs-run.rkt path` from the project root. There is no
new build step or dependency.

Write tests before product edits in each checkpoint. Run
`raco test tests/aloemacs` after each slice and `raco test tests` after the
last. A manual TTY look is useful but is not acceptance evidence.

## 4. Session state and transition contract

Append one `String` field to `AloemacsSession` after `path`:

```aloe
(define-class (AloemacsSession H)
  (fields
    (editor AloemacsEditor)
    (fs (Fs H))
    (path (Option Path))
    (echo String))
  (methods ...))
```

The checked constructor is `(AloemacsSession new editor fs path echo)`.
The initial session in `main.aloe` uses `""` for `echo`. Every direct test
constructor gains the same fourth argument unless the test deliberately
constructs a saved or failed state. The empty string means **idle**, not the
untitled label; the row derives its label from `path` at frame time.
Successful `visit` returns a session with `echo = ""`, including a visit to
a missing new-file location. A refused visit returns `None` and leaves its
receiver unchanged. Every ordinary session rebuild, including
`with-editor` and `ensure-visible`, carries `echo` unchanged unless the
transition below explicitly replaces it. There is no echoed copy of `Path`.
The field is immutable like the other session fields.

Only three echo values are produced by application transitions:

| Value | Meaning | Row prefix |
|---|---|---|
| `""` | Idle: no reported key-save outcome | none |
| `"saved"` | Most recent Ctrl-S succeeded | `saved: ` |
| `"failed"` | Most recent Ctrl-S returned `None` | `failed: ` |

For a non-quit session, `(session handle-key "save")` calls the existing
`(session save)` exactly once. `Some(saved-session)` returns a new session
with that saved session's editor, fs, and path and `echo = "saved"`.
`None` returns a new session with the receiver's editor, fs, and path and
`echo = "failed"`. Thus untitled Ctrl-S and an ineligible bound
`Fs.write` `None` are both visible failures, with no invented exception
handling. A host failure that raises remains a host failure and does not
produce a returned frame or `"failed"` session.

The next **non-save key handled by an active session** sets `echo = ""`
while delegating that key to the editor. This includes movement, edit,
undo, unknown keys, and Escape. Another save replaces the old outcome with
the new one. A save result therefore appears on the frame immediately
following Ctrl-S and remains visible through repeated frames or resize
until another key. Direct session sends such as `insert`, `undo` through
the editor, or `save` are not key events: their existing semantics and the
echo field are preserved. In particular, direct `(session save)` still
returns `Option` and does not create a failure message when it returns
`None`. As before, `handle-key` on an already quit session is a no-op.
No dirty mark is inferred from a later edit or undo.

## 5. Text rectangle and exact echo row

For positive `columns` and `rows`, define:

```text
text-rows = if rows >= 2 then rows - 1 else rows
label     = if path is None then "untitled" else (path text)
row       = if echo is "saved" then "saved: " + label
            else if echo is "failed" then "failed: " + label
            else label
shown-row = first columns characters of row
```

The bound label uses the already resolved stored `Path.text`, not the
startup argument, basename, or a second path field. Clipping is on the
**right** using `String.take`; there is no ellipsis. Status precedes the
label so a narrow screen still shows which save outcome occurred. There
is no inverse video or fill character. The full-screen clear makes unused
cells of the echo row blank. For example, at 8 columns the idle untitled
row is `untitled`, `saved: untitled` appears as `saved: u`, and
`failed: untitled` appears as `failed: `; at wider widths the entire
string appears. At 8 columns, `/cwd/a.txt` appears idle as `/cwd/a.t`.
The status prefixes deliberately take priority over the path when both
cannot fit.

For `rows >= 2`, `session.ensure-visible(columns, rows)` passes
`(columns, text-rows)` to the nested editor's `ensure-visible` and rebuilds
the session. `session.frame(columns, rows)` passes those same sizes to the
nested editor's existing `frame`. Its caller must already have fitted the
session to those dimensions, as in the runner. The editor's frame paints
exactly `text-rows` text rows, including blank padding, and places its
cursor within them. The session then appends this ANSI suffix to that
complete editor frame:

```text
ESC[?25l  ESC[rows;1H  shown-row  ESC[text-cursor-row;text-cursor-colH  ESC[?25h
```

`text-cursor-row = point.line - editor.scroll-row + 1` and
`text-cursor-col = point.column - editor.scroll-col + 1`, the Viewport
one-based coordinates after fit. The cursor is hidden while writing the
echo and ends in the text rectangle. The appended row is addressed by
absolute ANSI cursor position, so there is no extra CRLF after the text
body and no extra terminal write. The preceding editor frame already
hides, clears, homes, positions the text cursor, and shows it; that exact
frame is a prefix of the session result. This composition permits a brief
show/hide pair inside the single string but leaves the cursor visibly on
text when the write completes. `session.frame` remains pure.

At `rows = 1`, do **not** steal the only text row. Pass one row through
to editor fit and frame and append no echo suffix. The stored outcome
survives and appears if the terminal later has at least two rows. This
is the exception to reserving a row; `rows = 0` is outside the existing
positive-dimension frame contract. At every size with a reserved echo row,
the screen cursor is never left on that row. Width is still the full
terminal `columns`; horizontal origin and clipping of text remain under
the editor's existing rules.

The runner still queries Term `columns` and `rows` once per iteration,
calls session `ensure-visible`, calls session `frame` with those same full
sizes, sends the resulting **one** string with one `(term write ...)`,
then reads and handles one key. Resize is seen on the next iteration.
The runner performs no row arithmetic, ANSI assembly, or save policy.

## 6. Layer file scope and verification

### Layer 000 — idle row and text-height fit

Product files: `examples/aloemacs/file.aloe` and
`examples/aloemacs/main.aloe` only. Add focused
`tests/aloemacs/echo-session.rkt` and
`tests/aloemacs/echo-runner.rkt`. Update existing test fixtures
and exact frame goldens under `tests/aloemacs/` where they assume the
three-field session, full-height text, or exact old session frame.
Known sites include `file-session.rkt`, `runner.rkt`, `file-runner.rkt`,
`viewport-editor.rkt`, `viewport-runner.rkt`, `undo-session.rkt`, and
`visited-unchanged.rkt`. Do not revise direct `AloemacsEditor.frame` goldens:
the editor's own full-height API is unchanged. Do not weaken movement,
undo, save, visit, or ANSI assertions to make the new frame fit.

No-TTY tests first prove the fourth constructor field and `String` type,
idle startup, `visit` resetting the field, immutability, and preservation
through ordinary rebuilds. Compare complete frames: untitled at first
frame, a visited path's resolved text, right clipping, exact ANSI echo
position and text-cursor restoration, one-row fallback, and blank text-row
padding. With an 8-column by 4-row terminal, point moved Down to source
line 3 must fit into **three** text rows: origin row 1 and text cursor row 3,
with the echo on row 4. An Up from line 3 to line 2 holds origin row 1 and
moves text cursor to row 2. A scripted runner double proves one write per
frame and full Term dimensions still reaching the session. Existing
movement/undo/visit goldens are updated to the new text height or given
one extra terminal row when that preserves their intended text scenario.
At this checkpoint, Ctrl-S still produces the idle echo; save messages
belong to 001.

Run `raco test tests/aloemacs` and stop.

### Layer 001 — save outcome and lifetime

Product file: `examples/aloemacs/file.aloe` only. Extend
`tests/aloemacs/echo-session.rkt` and
`tests/aloemacs/echo-runner.rkt`; adjust affected assertions under
`tests/aloemacs/file-session.rkt`, `undo-session.rkt`,
`viewport-editor.rkt`, and `file-runner.rkt` that formerly required a
key-save result to be structurally equal to its input. Their editor,
filesystem, path, and history assertions retain their meaning. Direct
`save` expectations remain unchanged. Update `docs/design/implementation/aloemacs/demo.md`
briefly so its description of the echo row and Ctrl-S outcome matches the
running program; do not add a new tour or feature.

No-TTY tests first prove successful bound Ctrl-S both writes the expected
file text and frames with `saved: `, while untitled Ctrl-S frames with
`failed: ` and never writes. An ineligible bound path yielding
`Fs.write None` also frames with `failed: `. Test successive save outcomes,
non-save movement, edit, undo, unknown key, and Escape clearing the status,
plus direct `save` retaining its `Option` contract and no status message.
Compare complete ANSI frames at a width that can show both status and path,
and a narrow width that clips the path while retaining the status prefix.
Check that no row ever reports success for a returned `None`.

Run `raco test tests/aloemacs` and `raco test tests`; stop without starting
another checkpoint.

## 7. Acceptance

The finished session frames `untitled` or its bound resolved path on the
last row whenever at least two rows are available. It reports distinct
`saved:` and `failed:` outcomes from Ctrl-S, with the specified lifetime.
It fits and paints text in `rows - 1`, so Down to the former last screen
row scrolls text and leaves the cursor above the echo. Frames are single
ANSI strings written once through the existing Term method. Existing
visit, save effects, movement, undo, and text-frame behavior continue to
pass their focused tests. Tests run without a TTY, and the full repository
suite is green. No later editor or language feature is added in this series.
