# aloemacs-kill 001 — Mark, kill, and yank

**Status.** Ready to implement.

If you have been told to read this file, it is the whole assignment.

## Goal

Add the editor mark, the session kill ring, and the `"mark"`, `"kill"`,
`"kill-line"`, and `"yank"` command transitions. Prove them through checked
Aloe session tests without a TTY. Stop when the focused test and full
aloemacs suite pass. Physical Ctrl-W, Ctrl-Y, Ctrl-K, and Ctrl-Space
conversion belongs to aloemacs-kill 002, after review of this checkpoint.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); this checkpoint narrows the spec to one slice and
does not revise it. Sections 1–2, 4–5, 7–8 of that spec govern this work.
Its §6 is reserved for 002. [`../../../../../../SPEC.md`](../../../../../../SPEC.md)
governs Aloe syntax, checked types, constructors, sends, and immutable values.
The accepted sibling `text`, `undo`, `search`, and `echo` specifications
govern their existing behavior where this checkpoint does not extend it.

- Identity: **aloemacs-kill 001**, a local checkpoint, not global 116.
- **aloemacs-kill 000** is implemented and reviewed. `Text.excerpt` exists;
  keep its contract and tests green. Do not edit it in this slice.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Current seams are `examples/aloemacs/editor.aloe`, `file.aloe`, and
  `main.aloe`. `AloemacsEditor` owns immutable text, point, scroll origins,
  quit, and undo history. `AloemacsSession` owns fs, path, echo, and search
  state. `UndoFrame` has exactly text, point, scroll-row, and scroll-col.
- Evaluation is send, not application: `(f x)` does not call `f`;
  `(f call x ...)` does. `let` has parallel bindings. Do not add forms absent
  from `SPEC.md`.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` — mark field, preservation, and named
  editor helpers in the spec
- `examples/aloemacs/file.aloe` — ring field, preservation, visit reset,
  and the four session command paths
- `examples/aloemacs/main.aloe` — construct the two new fields
- `tests/aloemacs/kill-session.rkt` — new focused checked Aloe tests
- Existing constructor fixtures in these `tests/aloemacs/` files, solely to
  add the new mark and ring arguments while keeping their prior assertions:
  `echo-session.rkt`, `editor-keys.rkt`, `file-session.rkt`, `frame.rkt`,
  `index-001-editor-movement.rkt`, `index-002-frame.rkt`,
  `index-002-timing.rkt`, `int-min.rkt`, `next-lines.rkt`, `runner.rkt`,
  `safe-cell-scan.rkt`, `safe-cells.rkt`, `search-session.rkt`,
  `text-line-length.rkt`, `undo-editor.rkt`, `undo-session.rkt`,
  `viewport-editor.rkt`, `viewport-top.rkt`, and `visited-unchanged.rkt`.
- `tests/aloemacs/file-runner.rkt` and `runner.rkt` source-shape assertions,
  only if the new constructor shape requires a change. Do not weaken their
  behavior assertions.

Recheck every product and aloemacs test occurrence of `AloemacsEditor new`
and `AloemacsSession new`; the file list above records the current search,
not permission to edit an unrelated test. Keep intentional wrong-arity
constructor cases wrong-arity. Give other negative cases the added field so
they still test their original type error.

### Must leave untouched

- `lib/text.aloe`, `tests/aloemacs/kill-excerpt.rkt`, all other libraries,
  the kernel, and the evaluator/type checker
- `host/racket/term.rkt`, Term tests, `host/racket/aloemacs-run.rkt`,
  and the Fs implementation
- `SPEC.md`, `CHECKPOINTS.md`, earlier specs or checkpoint documents
- `UndoFrame` field order and shape; `Text.delete` and `EditResult` contracts
- every file not listed under **May edit**

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## State and reconstruction

Append `(mark (Option Position))` after `history` in `AloemacsEditor`.
Its constructor becomes:

```aloe
(AloemacsEditor new text point quit scroll-row scroll-col history mark)
```

Fresh editors and successful visits start with no mark. At an untyped
construction site such as `main.aloe`, use an inferable empty value:

```aloe
(if #t (Option None) (Option Some (Position new 0 0)))
```

A bare `(Option None)` is valid as the mark field of
`AloemacsEditor new` when that field's type is already
`(Option Position)`. It is not a valid argument of `with-mark`: bare
None fails the checker, and the `if` form fails at runtime with
`unknown message: with-mark`. `ensure-visible`, `with-text-and-point`,
`from-edit`,
`request-quit`, and every other editor rebuild retain the current mark
unless the command below changes it. `unchanged` returns it untouched.
`undo` restores text, point, and both scroll origins from the popped frame,
but retains the receiver's current mark. The frame does not gain a mark.
Neither `frame` nor `safe-cells` reads it.

Append `(kill-ring (List String))` after `failing` in `AloemacsSession`.
Its constructor gains the ring as its final argument. `main.aloe` supplies
`(List empty)`. A successful `visit` starts a new empty ring, as well as a
new empty mark. Every other session reconstruction, including
`with-editor`, `with-search`, `end-search`, save outcomes, idle fallback,
and `ensure-visible`, retains the receiver's ring unless a successful kill
conses a string to its front. Search and save add no history.

Add and use these ordinary Aloe methods with the signatures and roles in
spec §4:

- `AloemacsEditor.with-mark(mark)` rebuilds only the mark. The argument
  is `(Option Some position)`. Do not pass None.
- `AloemacsEditor.clear-mark()` takes no arguments and rebuilds the
  editor with `(Option None)` in the mark field.
- `AloemacsEditor.keep-valid-mark()` checks the stored mark against the
  edited Text, retaining the exact valid Position or sending
  `clear-mark`.
- `AloemacsSession.with-kill-state(editor, kill-ring)` preserves fs, path,
  and search state, sets echo to `""`, and supplies the given editor/ring.
- `AloemacsSession.set-mark()`, `kill-span(span, clear-mark)`, `kill()`,
  `kill-line()`, and `yank()` implement the command transitions below.

Do not add a mark to the frame, a second edit history, a mutable clipboard,
or rendering of the region.

## Command transitions

In session `idle-key`, consume the exact strings `"mark"`, `"kill"`,
`"kill-line"`, and `"yank"` before the editor fallback. Do not add them to
editor `handle-key`; a direct `(editor handle-key "kill")` remains unchanged.
`session.handle-key` still absorbs every key after quit. Each command,
including a no-op, clears the stored echo token through `with-kill-state`.
The idle row then shows its existing path or `untitled`; at `rows < 2` the
command still runs without an echo row. No mark status message is added.

- **Mark:** Set `Some` of the current point, replacing any previous mark.
  Keep text, point, history, and ring. Push no undo frame.
- **Region kill:** Without a mark, clear echo only. With a mark, order it and
  the point using `Position.before?`, build the half-open `Span` from earlier
  to later, and send `kill-span(span, #t)`. Both directions behave alike.
- **Kill-line:** Ignore the mark when choosing the span. For point `(r,c)`
  on a focused line of length `n`, use point to `(r,n)` if `c < n` (keep the
  LF); use point to `(r+1,0)` if `c = n` and a following line exists (kill
  exactly LF). If `c = n` on the last line, `c > n`, or no line can be
  focused, clear echo only. A trailing LF's final empty line is last line.
  Send a chosen span to `kill-span(span, #f)`.
- **Yank:** With an empty ring, clear echo only. Otherwise insert the front
  string at point through the existing editor `insert` path. A valid point
  creates one undo frame and then `keep-valid-mark` checks the new text.
  Invalid point or failed insertion leaves editor and ring unchanged apart
  from echo clearing. Do not consume or reorder the ring entry.

`kill-span` first sends `(text excerpt span)`. `None` and `Some ""` leave
text, point, history, mark, and ring unchanged, clearing only echo. For a
nonempty excerpt, send `(text delete span)`. A deletion `None` has that same
no-op behavior. On `Some EditResult`, call the existing `editor.from-edit`
exactly once, put the excerpt at the ring front, and use the result's
position, which is the span start. When the Bool is `#t`, send
`(edited clear-mark)`. Otherwise send `(edited keep-valid-mark)`.
Never call
`from-edit` on a no-op.

Each successful kill, kill-line, or yank adds exactly one `UndoFrame` of the
pre-edit text, point, and scroll origins. Mark, no-ops, search motion, and
echo clearing add none. Undo restores those frame fields while preserving
the current mark and ring. In particular, undo of a region kill leaves its
mark empty and its killed string at the ring front; yank afterward can
insert that same string into the restored text. Marks are never rebased to
track moved content. Successful kill-line and yank merely retain a still
valid mark or clear one made invalid; no-op commands leave it untouched.

While search is active, these strings follow the existing `search-key`
“anything else” path: end search, then dispatch through `idle-key`. Do not
add search-key arms. That path initially retains echo; the idle command
clears it. Search Escape still ends search without quitting; idle Escape
still requests quit.

## Required focused tests

Write `tests/aloemacs/kill-session.rkt` first and observe failure for the
missing state/behavior. Use `rackunit` and the checked Aloe driver, with no
TTY. Exercise the four command strings through `session.handle-key`.
Test both state values and their checked field/method types where useful.

Prove:

1. The new fields have checked types `(Option Position)` and
   `(List String)` in the specified order; constructor arity/type failures
   remain meaningful. Fresh/visited mark and ring are empty; mark can be
   set and replaced after motion without editing; ordinary editor and
   session rebuilds preserve mark/ring, and successful visit resets both.
2. Forward and backward multiline region kills remove identical half-open
   text, leave point at span start, clear the mark, and place the removed
   string at the ring front. No-mark and empty-region kills are no-ops.
3. Kill-line kills a suffix without LF, kills LF alone at end of a line,
   and is a no-op at end of the final line, on the final empty line after
   trailing LF, beyond line length, and when no line is focusable.
4. Multiple successful kills make the ring newest first. Empty/invalid
   spans and no-op kill-line do not add entries or frames.
5. Successful yank inserts the front entry, retains it, moves point through
   the existing insertion result, and creates one frame. Empty-ring and
   invalid-point yank create none.
6. Successful region kill clears its mark. Kill-line and yank keep an exact
   stored mark when still valid in new text and clear it when invalid.
   No-op commands preserve the mark even if it was already invalid.
7. Undo of a kill restores text, point, and both scroll origins, leaves the
   ring alone, and retains the current mark. Yank after that undo uses the
   same front entry. Each successful edit adds exactly one frame; mark and
   no-ops add none.
8. Quit absorption, echo clearing after all four keys including no-ops,
   idle row path/untitled behavior, active-search fall-through, and command
   execution when `rows < 2`.
9. Exact existing frame bytes for a representative editor without a mark
   remain unchanged. A direct editor `handle-key "kill"` remains unchanged.

Update constructor fixtures only as needed for the new fields. Keep all
existing movement, undo, visit, save, search, echo, and frame goldens;
source-shape assertions may be updated only for the constructor change.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test -y tests/aloemacs/kill-session.rkt
TMPDIR=/tmp raco test -y tests/aloemacs
git diff --check
```

`-y` rebuilds changed `.rkt` bytecode and dependent modules. Do not commit
`compiled/`. No physical TTY hand check is required. If the implementer
launches the editor after a `.rkt` edit, first run the test command or
`raco make host/racket/aloemacs-run.rkt bin/aloe`. An `.aloe`-only edit
needs no rebuild before launch.

Complete this checkpoint when the checked command transitions, ring and
mark preservation, visit reset, one-frame edit behavior, no-op behavior,
search and echo interactions, and existing frame bytes all pass, and the
full aloemacs suite is green. Report the changed files and results, then
stop for human review. Do not implement the physical chords or issue 002.
