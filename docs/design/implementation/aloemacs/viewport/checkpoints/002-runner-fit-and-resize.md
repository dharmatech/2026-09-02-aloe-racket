# aloemacs-viewport 002 — Runner fit and resize

**Status.** Ready to implement.

## Goal

Fit the current immutable `AloemacsSession` with the current Term dimensions
before every full-frame write, including the first frame after startup.
Retain one queried `columns` value and one queried `rows` value for both fit
and frame in that iteration. Scripted Term and Fs doubles prove the ordering,
Up behavior, resize behavior, and unchanged visit, save, and quit boundaries.

This is the final planned viewport slice. Stop when the focused and full
repository suites are green. Do not add another viewport feature or begin a
new project.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-viewport 002**, the third local checkpoint in the
  **aloemacs-viewport** series. Its predecessors,
  [000](000-stored-origin-and-fit.md) and
  [001](001-frame-from-stored-origin.md), are implemented: the editor stores
  `scroll-row` and `scroll-col`, editor and session supply pure
  `ensure-visible`, and direct fitted `frame` renders from that stored origin
  with exact complete ANSI bytes.
- The governing spec sections are §1–6, §7 “Layer 3 — runner fit and resize,”
  and §8. [`../../file/spec.md`](../../file/spec.md) remains authority for
  startup visit, save, and runner effects except for this fit-before-frame
  sequence. `SPEC.md` remains Aloe language law: the list head is the
  receiver, its second element is a literal selector, and a function object
  runs only through `call`.
- The project root for code and tests is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. The starting runner in
  `host/racket/aloemacs-run.rkt` injects Term and Fs into a checked driver,
  loads `main.aloe`, optionally visits a path, then writes a frame before
  reading a key. It currently asks Term for size inside the frame expression
  and does not fit the session. The existing test files have scripted Term
  and Fs doubles and source-boundary assertions.

## Exact file scope

### May edit

- `host/racket/aloemacs-run.rkt`
- `tests/aloemacs/viewport-runner.rkt` (new)
- `tests/aloemacs/runner.rkt` and `tests/aloemacs/file-runner.rkt` only as
  needed for the fit-before-frame sequence and intentional new frame goldens

### Must leave untouched

- All Aloe product files, including `examples/aloemacs/editor.aloe`,
  `file.aloe`, and `main.aloe`
- Term and Fs implementations, other host capabilities, `lib/text.aloe`,
  other libraries, Gel, `aloe/eval.rkt`, and any kernel or compiler file
- Every other test, including `viewport-editor.rkt`, `frame.rkt`, and the
  Index timing driver
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, the accepted viewport
  spec, earlier viewport checkpoints, project maps, and any file not listed
  under **May edit**

If another file appears necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Required runner sequence

Keep the exports and arities of `run-aloemacs`, `run-aloemacs-with-term`, and
`run-aloemacs-with-hosts`. Keep their current startup visit rules, checked
driver, host injection, path handling, and quit behavior. For each iteration
of `run-aloemacs-with-hosts`, including the first one after any successful
startup visit, perform these actions in order:

1. Through the checked driver, query `(term columns)` exactly once and then
   `(term rows)` exactly once. Retain those two positive Aloe `Int` results
   for this iteration.
2. Through the checked driver, rebind `aloemacs-editor` to the
   `(aloemacs-editor ensure-visible columns rows)` session result. Use the
   queried values as Aloe `Int` literals; the fit must happen before frame.
3. Through the checked driver, compute
   `(aloemacs-editor frame columns rows)` from the **fitted** binding using
   the **same** two values. Send that one complete `String` to
   `(term write ...)` once. The existing Term write performs one flush.
4. Read one `(term read-key)`, send `handle-key` to the session, and rebind
   the immutable result. If it is quit, return without another size query,
   fit, frame, write, or key read. Otherwise repeat.

The runner may hold the two queried dimensions as Racket local integers
between checked `driver-eval!` calls and insert them as Aloe `Int` literals
in the fit and frame expressions. Do not query either dimension again
between fit and frame. Do not call the Term host implementation directly,
calculate a viewport origin in Racket, or use a second evaluation path. The
runner has no key table, edit policy, ANSI literal, new Term operation, or
new host crossing type.

Resize is observed on the **next iteration's** size queries; it is not a
`read-key` event. `ensure-visible` keeps each existing origin if point is
within that axis's new half-open window, or moves it by the minimal §5 fit
rule if point exits. A larger window does not pull origin toward zero merely
to fill it. A smaller window leaves an origin alone if point remains
visible. Both fit and frame use the same newly queried dimensions. No
resize-specific state is stored in Racket or Aloe.

Preserve one complete `term write` and flush per drawn iteration, before
its one key read. A rejected startup visit performs no size query, fit,
write, or key read. An Escape key still draws its preceding frame but causes
no following frame or size query. Visit and save remain Aloe session sends;
quit never saves.

## Focused tests

Create `tests/aloemacs/viewport-runner.rkt` with a scripted Term receiver
and Fs double. The Term double may record ordered callbacks for size reads,
output bytes, flushes, and key reads. `make-term-receiver` invokes its size
reader once for `columns` and once for `rows`, so a size script should
return the same pair for both calls in one iteration and a new pair for the
next iteration. Compare full output strings, including ANSI prefix, body,
cursor position, and suffix; do not assert only a cursor suffix. Cover:

1. **First-frame order.** A pathless run and a successful startup visit
   query size twice, fit, write one complete frame, flush, then read the
   first key. Since a fresh editor starts at point and origin `(0, 0)`, the
   first frame bytes alone cannot prove that fit ran. Add a runner-source
   order assertion that locates one `term columns` and one `term rows`
   query before `aloemacs-editor ensure-visible`, then `aloemacs-editor
   frame`/`term write`, then `term read-key` in the iteration. Retain the
   existing thin-skin source assertions.
2. **Down then Up.** Visit a file with
   `"zero\none\ntwo\nthree\nfour\nfive"`, use size 8 by 4, and script
   three `"down"` keys, one `"up"`, then `"escape"`. At point line 3 the
   origin is row 0 and the frame body is
   `zero\r\none\r\ntwo\r\nthree` with cursor `[4;1H`; after Up the same
   body remains and the cursor is `[3;1H`. Check both **complete** strings
   against §5's goldens, as well as the first and intervening frames, the
   exact size-read/write/flush/key callback order, and no frame after
   Escape.
3. **Resize on the next iteration.** Script sizes and keys so point reaches
   line 3 at an 8-by-4 frame, then stays put for a shrink to 8 by 3. That
   shrink moves origin from row 0 to 1 and puts the cursor on screen row 3.
   Move Up to point line 2, then shrink to 8 by 2: point remains in
   `[1, 3)`, so origin stays 1 and the cursor is row 2. Grow to 8 by 5
   while point remains there: origin stays 1 and the body extends through
   source line 5 instead of pulling the view back to row 0. Use no-op keys
   where needed to advance iterations without moving point. Check the full
   frame at each size and exactly one query of each dimension per frame.
   The recorded pair for any frame must be the pair used by its fit. Also
   cover a width-only resize on a long source line: shrinking past point
   moves `scroll-col` without moving `scroll-row`, and later growth keeps
   that shifted column while point remains visible. Compare complete frames.
4. **Quit and visit boundary.** Escape after the first frame leaves no extra
   size query or redraw. Rejecting a directory, symlink, or other non-file
   startup visit leaves the key script untouched and records zero size
   reads, writes, flushes, and key reads. Existing visit/save tests must
   retain their filesystem and exact source-string assertions.

Adjust `runner.rkt` and `file-runner.rkt` only for observations that change
because of the new fit-before-frame sequence. Keep their entry-point arity,
main-source, Term write/flush, visit/save, and checked-boundary assertions.
Do not weaken existing ANSI, key, or source-string assertions. No test needs
a physical TTY.

## Verification and completion

From the project root, run:

```sh
raco test tests/aloemacs/viewport-runner.rkt
raco test tests/aloemacs
raco test tests
```

This final slice is complete when all three commands pass; every drawn
iteration fits with one retained positive size pair before its complete
frame write; Down/Up and resize show the required held and shifted origins;
quit and failed visit cause no extra Term effects; and Text, Loop, File,
Index, Term, Gel, and host behavior stays green. A manual interactive Up
check may be reported, but the automated no-TTY tests are the acceptance
evidence. Report results and changed files, then stop for human review. Do
not start another viewport checkpoint.
