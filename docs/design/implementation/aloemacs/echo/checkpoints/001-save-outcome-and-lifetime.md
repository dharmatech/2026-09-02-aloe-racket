# aloemacs-echo 001 — Save outcome and lifetime

**Status.** Ready to implement.

## Goal

Show `saved: ` or `failed: ` before the session's path label after Ctrl-S.
Keep that outcome visible through frames and resizes, then clear it on the
next non-save key handled by an active session. Update the short demo
description to match the completed echo behavior.

Stop when the save-message tests and full repository suite pass. This is the
last planned checkpoint of the aloemacs-echo series; do not start a later
editor or language feature.

## Authority and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-echo 001**, the second local checkpoint of the
  **aloemacs-echo** series. **aloemacs-echo 000** is the implemented
  predecessor: the four-field session has an idle echo row, frames the
  resolved path or `untitled`, and fits the editor to the text rows.
- Governing sections are spec §1–3, §4's save and key transition contract,
  §5's row prefix and clipping rules, §6 “Layer 001,” and §7. The accepted
  File and Viewport specs continue to govern `save`, path resolution, and
  editor fitting wherever this checkpoint is silent.
- The project root for code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. `SPEC.md` governs Aloe
  syntax and checking: evaluation is message send, a selector is literal,
  and function objects run only through `call`. No mutation, inheritance,
  or implicit `Int`/`Float` conversion is introduced.
- The runner already frames before reading a key and writes one complete
  frame per iteration. The frame after a Ctrl-S therefore displays the
  outcome of that key. The runner's order, Term calls, and entry arities
  remain unchanged.

## Exact file scope

### May edit

- `examples/aloemacs/file.aloe`
- `tests/aloemacs/echo-session.rkt`
- `tests/aloemacs/echo-runner.rkt`
- `tests/aloemacs/file-session.rkt`
- `tests/aloemacs/undo-session.rkt`
- `tests/aloemacs/viewport-editor.rkt`
- `tests/aloemacs/file-runner.rkt`
- `docs/design/implementation/aloemacs/demo.md` (brief description only)

In the existing tests, adjust assertions that equate a key-save result to
its input session or expect an idle frame immediately after Ctrl-S. Keep
their editor, filesystem, path, history, movement, visit, and direct-save
assertions. Do not weaken full-frame ANSI comparisons.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`,
  `host/racket/aloemacs-run.rkt`, every other host file, Term and Fs
  implementations, `lib/text.aloe`, `lib/string.aloe`, other libraries, Gel,
  and `aloe/eval.rkt`
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, this accepted spec,
  aloemacs-echo 000, earlier aloemacs checkpoints, and project maps
- All other product, test, and design files

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager rather than widening the slice.

## Required save and key behavior

Keep the existing `(session save)` send and its
`(Option (AloemacsSession H))` result. A direct save remains an explicit
filesystem action, not a key event. Its successful `Some` result preserves
the receiver's editor, fs, path, and echo payloads; a returned `None` does
not create a new session or status message. Do not add a dirty bit or catch
host failures.

For an active session, `(session handle-key "save")` sends the existing
`(session save)` exactly once:

- `Some(saved-session)` returns a new session with the saved session's
  editor, fs, and path and `echo = "saved"`.
- `None` returns a new session with the receiver's editor, fs, and path and
  `echo = "failed"`. This includes untitled saves and an ineligible bound
  path for which `Fs.write` returns `None`.

A host failure that raises still raises; it does not become a returned
`"failed"` session. Another save replaces the previous outcome. The next
non-save key handled by an active session delegates to the editor and
returns a rebuilt session with `echo = ""`. This includes movement, edit,
undo, unknown keys, and Escape. The outcome remains visible through any
number of frames and `ensure-visible`/resize calls before that key. Direct
session sends such as `insert`, `newline`, `request-quit`, or `save` preserve
the echo because they are not key events. `handle-key` on an already quit
session remains a no-op and does not clear or replace the echo.

At `rows >= 2`, compose the row before right clipping to `columns`:

```text
label = "untitled" when path is None; otherwise stored (path text)
row   = "saved: "  + label when echo is "saved"
      = "failed: " + label when echo is "failed"
      = label otherwise
shown-row = first columns characters of row
```

Use `String.take` for clipping. The status prefix takes priority when the
screen is narrow: at eight columns, `saved: untitled` becomes `saved: u`
and `failed: untitled` becomes `failed: `. A bound label is the stored
resolved `Path.text`; do not use the startup argument or a basename. Retain
the exact editor-frame prefix and session ANSI suffix from 000, with one
string and one Term write. At `rows = 1`, append no echo suffix, preserve
the stored outcome, and show it if a later fit/frame has at least two rows.
The text cursor must still finish inside the text rectangle.

## Focused tests

Write and adjust tests before changing product code. Use checked Aloe
drivers and Fs/Term doubles; no physical TTY is needed.

Extend `echo-session.rkt` to prove:

1. Bound Ctrl-S writes the exact current text and returns `echo = "saved"`;
   untitled Ctrl-S returns `echo = "failed"` without writing; an ineligible
   bound path whose `Fs.write` returns `None` also returns `"failed"` and
   does not claim success. Check editor, fs, path, origin, and history
   preservation in these results.
2. A further save replaces either prior outcome. Cover both success after
   a pre-existing failure and failure after a pre-existing success, as well
   as repeated frames that retain an outcome. No returned `None` may display
   `saved: `.
3. Movement, edit, undo, unknown key, and Escape each clear a prior
   outcome on an active session while preserving the editor's existing key
   behavior. An already quit session ignores both save and non-save keys.
   Direct editor/session sends and `ensure-visible` preserve a status; a
   one-row frame hides it without clearing it, and a later larger frame
   shows it again.
4. Direct `save` still returns `Option`, writes when eligible, preserves an
   existing echo in its `Some` payload, and returns `None` for untitled or
   ineligible paths without creating a failure message.
5. Compare complete ANSI frames at a width that shows the full status and
   bound path, and at eight columns for `saved: u`, `failed: `, and a
   clipped bound path. Check the exact suffix, cursor restoration, and
   unchanged text-frame prefix.

Extend `echo-runner.rkt` with scripts whose next frame follows a key-save.
Check bound success, untitled failure, and ineligible bound failure; each
frame is still one complete Term write. Verify the status persists until
the next key and clears on a following active non-save key. The runner must
not acquire save policy, row arithmetic, or a second write.

Update the permitted predecessor tests so structural comparisons of
key-save results compare the unchanged editor/fs/path/history payloads and
the new echo value. Keep direct-save assertions unchanged. In `demo.md`,
replace the claims that there is no status line or save echo with a short,
accurate note about the bottom echo row, bound path, and distinct Ctrl-S
success/failure messages. Keep the existing tour and commands; do not add a
new step or feature.

## Verification and completion

From the project root, run:

```sh
raco test tests/aloemacs/echo-session.rkt tests/aloemacs/echo-runner.rkt
raco test tests/aloemacs
raco test tests
```

The checkpoint is complete when the focused tests, Aloemacs suite, and full
repository suite pass, the demo matches the running program, and only the
permitted files changed. A manual TTY look is optional and is not
acceptance evidence. Report test results and files changed, then stop for
human review. Do not start another checkpoint or later feature.

## Explicit non-goals

- A dirty bit, autosave, prompt, second buffer, mode line, or new key binding
- New Term or Fs methods, runner changes, a second terminal write, or a
  different text rectangle and cursor policy
- Safe control-character display, pathname sanitization, tab-width policy,
  or faster string load/save
- Minibuffer input, `C-x`, windows, Boids, new language forms, kernel
  changes, or a global checkpoint
