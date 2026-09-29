# aloemacs-safe-cells 000 — One-cell control display

**Status.** Ready to implement.

## Goal

Paint each control character in a clipped editor text row or clipped session
echo label as one ordinary space. Keep the source text, path, saved content,
character columns, and the frame's own ANSI chrome and CRLF separators intact.

Stop when both call sites and their tests pass. This checkpoint adds no Tab
key, tab stops, caret notation, display-column model, or other editor feature.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-safe-cells 000**, the first local checkpoint of the
  **aloemacs-safe-cells** series. There is no earlier safe-cells checkpoint.
  The Loop, Echo, Index, and string-load-save layers are implemented.
- The accepted spec's §§1–6 govern this entire slice. `SPEC.md` governs Aloe
  syntax, checking, and message sends. The safe-cells spec supersedes the
  earlier lack of a control-display rule only at the two frame call sites.
- The project root for code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. The current editor frame
  clips each line with `((line drop left) take columns)`, joins shown rows with
  `"\r\n"`, and adds ANSI chrome. The session frame computes an Echo-layer
  label/status row, clips it with `(row take columns)`, and appends its ANSI
  suffix when there are at least two rows.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` — add the checked `safe-cells` method and
  send it for each clipped text row before joining rows.
- `examples/aloemacs/file.aloe` — send the clipped echo row to the stored
  editor's `safe-cells` method before inserting it in the session suffix.
- `tests/aloemacs/safe-cells.rkt` (new) — focused checked-driver and Fs-double
  tests for the complete slice.
- `tests/aloemacs/frame.rkt`, `tests/aloemacs/echo-session.rkt`, and
  `tests/aloemacs/file-session.rkt` only if adding focused assertions is
  clearer than placing them in the new test file. Preserve their existing
  printable-frame goldens and predecessor assertions.

### Must leave untouched

- The kernel, `SPEC.md`, `CHECKPOINTS.md`, `lib/string.aloe`, `lib/text.aloe`,
  `host/racket/term.rkt`, the runner, the key map, other libraries, and Gel.
- Visit/save paths and behavior, the editor's point and scroll fields,
  `ensure-visible`, both cursor-column formulas, and the existing Echo-layer
  label and status-prefix rules.
- All other product, test, and design files.

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Required behavior

Add this method to `AloemacsEditor`:

```aloe
(safe-cells (clipped-string String) String
  ...)
```

The checked send `(editor safe-cells clipped-string)` returns a `String` of
the same `len`. Walk left to right. Replace each one-character String whose
code is 0–31 inclusive or 127 with exactly one ordinary space (code 32);
copy every other character, including codes 128 and above, unchanged. The
empty String stays empty. An `ESC` followed by `[31m` becomes ` [31m`.
Compare each character for equality against the 33 literal one-character
controls (`\u0000` through `\u001f`, plus `\u007f`) using existing Aloe
sends, `if`, and/or List operations. The String API has no character-code or
ordering send. Add no host helper, primitive, or special form.

In `AloemacsEditor.frame`, apply `safe-cells` to each result of
`((line drop left) take columns)`. Join those shown rows with the existing
`"\r\n"` separator and pass the body through the existing ANSI frame
constructor. Do not scan the full source line, joined body, or completed
frame.

In `AloemacsSession.frame`, preserve the Echo-layer label, status-prefix,
clipping, and cursor rules. After computing `row`, apply the stored editor's
`safe-cells` method to `(row take columns)` and insert that shown String in
the existing last-row ANSI suffix. A one-row session still returns the editor
frame without an echo label. `Path.text`, `echo`, and source `Text` remain
unchanged.

Point, `scroll-col`, `ensure-visible`, and both cursor-column formulas count
source characters as before. A tab paints as one space and still occupies one
source character. CR in CRLF input stays at the end of its source line and
paints as one space. The frame's own ANSI `ESC` bytes and `"\r\n"` row
separators remain exact.

## Tests

Write failing tests before product edits. Use checked Aloe loads and the
existing Fs double; no physical TTY. In the focused test file, prove:

1. A direct checked send of `safe-cells` has result type `String`, replaces
   all 33 specified controls, preserves length, copies printable characters
   and characters with codes 128 and above, and maps `""` to `""`.
2. An exact editor frame with `ESC`, tab, CR, one other code below 32 (NUL or
   bell), and DEL in a shown line has one space at each position without
   shortening the row. `ESC` followed by printable `[31m` displays as
   ` [31m`. A control left of `scroll-col` and one beyond the right clip
   produce no character in the shown body; an empty clip remains empty. A
   point on a tab retains its current one-based source-character cursor
   column.
3. An exact session frame with `ESC` and tab in the path label shows spaces
   after clipping to `columns`; the stored path is unchanged. Check idle and
   status-prefixed rows so the Echo-layer prefix order and clipping remain
   intact. At one row, no echo suffix is added.
4. Exact frame expectations keep the editor's ANSI chrome, the session's
   cursor sequences, and the editor's `"\r\n"` row separators. Inspect only
   displayed regions when asserting that no source control remains; the
   complete frame legitimately contains ANSI `ESC`. The existing printable
   ASCII frame goldens must remain exact.
5. Visit a file containing tab, CR, and ESC through the Fs double, render
   it, then save it and read back the original characters. Include CRLF input
   and check that each CR remains before its LF on save. Rendering must not
   change the editor/session payload.

For displayed-region checks, the editor body lies after the fixed
`\u001b[?25l\u001b[2J\u001b[H` prefix and before the next editor cursor
address `ESC[` marker. The echo label lies after `ESC[rows;1H` and before
the next cursor-address marker. Full exact-frame comparisons are also valid.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test tests/aloemacs/safe-cells.rkt
TMPDIR=/tmp raco test tests/aloemacs
TMPDIR=/tmp raco test tests
git diff --check
```

The checkpoint is complete when the focused tests, existing aloemacs tests,
and full repository suite pass, and its implementation edits stay within the
permitted product and test files. Report test results and changed files, then
stop for human review.
Do not issue or implement another checkpoint.

## Explicit non-goals

- A Tab key or insertion command, indentation, tab stops, caret notation,
  display-column expansion, Unicode-width rules, or ANSI interpretation of
  file text.
- CR stripping, newline conversion, changes to `split-lines`,
  `joined-with`, `to-string`, visit, or save.
- A mode, minibuffer, search, window, Boids behavior, kernel change, or
  global checkpoint.
