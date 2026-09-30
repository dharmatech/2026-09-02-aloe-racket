# aloemacs-search 001 — Session search

**Status.** Ready to implement.

## Goal

Make plain Ctrl-F enter incremental forward search in `AloemacsSession`.
Show the query and search outcome on the existing echo row, move point to
matches, wrap at most once, and restore the prior idle echo on acceptance.
Use the String `find` send from aloemacs-search 000.

This is the last planned checkpoint in the aloemacs-search series. Stop after
its tests and full suite pass; do not start another editor feature.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted
[`../spec.md`](../spec.md); the checkpoint narrows the spec to one slice and
does not revise it.

- Identity is **aloemacs-search 001**, the second local checkpoint of the
  **aloemacs-search** series. Its predecessor,
  [`000-string-find.md`](000-string-find.md), is implemented and reviewed:
  `(String find String Int)` returns `(Option Int)`, is checked and reflected,
  and met the 50× hit and miss timing bar.
- The accepted spec's §§1–2, §4, and §5 govern this slice. The accepted
  [`../../file/spec.md`](../../file/spec.md),
  [`../../echo/spec.md`](../../echo/spec.md), and
  [`../../safe-cells/spec.md`](../../safe-cells/spec.md) continue to govern
  visit/save, the idle echo row, and clipped display. `SPEC.md` governs Aloe
  syntax and message sends. Evaluation is send, not function application;
  `(f call x)` invokes a function object.
- The project root for code, tests, and commands is
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. The session is
  `examples/aloemacs/file.aloe`; the empty starting session is
  `examples/aloemacs/main.aloe`; `host/racket/term.rkt` maps physical keys.
  The editor already has `with-text-and-point`, `safe-cells`, and
  `ensure-visible`. The existing runner fits the session before framing.

## Exact file scope

### May edit or create

- `examples/aloemacs/file.aloe` — session fields, reconstruction, search
  transitions, scanning, and echo row.
- `examples/aloemacs/main.aloe` — supply the five new idle fields in the
  empty session constructor.
- `host/racket/term.rkt` — map plain Ctrl-F to `"find"`.
- `tests/aloemacs/search-session.rkt` (new) — checked no-TTY session and
  exact-frame tests using an Fs double.
- `tests/aloemacs/search-key-mapping.rkt` (new) — Ctrl-F key mapping and
  exclusion tests.
- Only where the new `AloemacsSession` constructor fields or exact
  `main.aloe` form require updates, these existing fixtures:
  `tests/aloemacs/file-session.rkt`,
  `tests/aloemacs/viewport-editor.rkt`,
  `tests/aloemacs/echo-session.rkt`,
  `tests/aloemacs/safe-cells.rkt`,
  `tests/aloemacs/undo-session.rkt`,
  `tests/aloemacs/visited-unchanged.rkt`, and
  `tests/aloemacs/runner.rkt`.

Preserve the existing fixtures' visit/save, edit, undo, viewport, path,
safe-cells, runner, and exact idle-frame assertions. Add the five idle
arguments to constructors and adjust arity expectations; do not weaken
unrelated checks.

### Must leave untouched

- `examples/aloemacs/editor.aloe`, `lib/text.aloe`, `lib/string.aloe`, the
  Term interface, `host/racket/aloemacs-run.rkt`, Fs, and the other libraries.
- `SPEC.md`, `CHECKPOINTS.md`, `aloe/` kernel and checker files, the accepted
  spec, earlier checkpoints, and all other product, test, and design files.
- The `AloemacsEditor` fields and constructor, text editing and undo
  implementation, existing String messages, and the Ctrl-S binding.

If another file is necessary, stop and send this checkpoint back to the
checkpoint manager instead of widening the slice.

## Session state and reconstruction

Append these fields to `AloemacsSession` after `editor`, `fs`, `path`, and
`echo`, in this order:

| Field | Type | Idle default |
|---|---|---|
| `searching` | `Bool` | `#f` |
| `query` | `String` | `""` |
| `origin` | `Position` | `(Position new 0 0)` |
| `wrapped` | `Bool` | `#f` |
| `failing` | `Bool` | `#f` |

`echo` remains the stored idle token (`""`, `"saved"`, or `"failed"`);
search display does not overwrite it. Supply all fields at every session
constructor site, including `with-editor`, `visited`, save outcomes, normal
key forwarding, and `main.aloe`. Ordinary rebuilds and `ensure-visible`
preserve the five fields exactly. A new visit starts idle with these defaults.
Direct session sends such as `save` and editor commands retain their current
semantics.

To move to a match, focus the existing Text at the match line and send the
existing `(editor with-text-and-point focused-text position)`. Keep the
editor's text content, quit flag, scroll origins, and exact history. Search
motion never calls `from-edit` or pushes an undo frame. The existing fit step
makes the new point visible before framing.

## Keys and transitions

In `host/racket/term.rkt`, map a `tkeymsg` to `"find"` when its key is
`#\f`, its modifiers are exactly `'(ctrl)`, and its decoded character is
`#f` or `#\f`. Check this before the printable fallbacks, following the
plain Ctrl-S rule. Printable `f`, Ctrl-Shift-F, and Alt-F retain their current
paths. Ctrl-S remains `"save"`; Ctrl-Z remains `"undo"`; Escape remains
`"escape"`. Add no Term method or keymap data structure.

`AloemacsSession.handle-key` remains absorbing when its nested editor has
quit. Otherwise:

| State and key | Result |
|---|---|
| Idle, `"find"` | Enter search at the current point: capture `origin`, set empty `query`, clear `wrapped` and `failing`, retain `echo` and point. |
| Active, one printable character including space | Append to `query`; seek from `origin` inclusive. No buffer edit. |
| Active, `"backspace"` | Remove the final query character if present; seek afresh from `origin`. An empty query returns to `origin` and shows `search: `. |
| Active, `"find"` with empty query | Stay put. |
| Active, `"find"` after an unwrapped match | Seek from one character after that match's start on the same line; overlapping matches are eligible. |
| Active, `"find"` after a wrapped match | Do not scan; retain point and set `failing`. |
| Active, `"find"` after a miss | Do not scan; retain point and the failing state. |
| Active, `"escape"` or `"return"` | Exit search, retain point and stored `echo`; do not quit or insert newline. |
| Active, any other key | Exit search, then dispatch that key through the existing idle session rule. Save saves; arrows move; undo undoes. |
| Idle, any other key | Keep the existing session rule, including Ctrl-S save, non-save echo clearing, and Escape quit. |

Exiting search resets `searching` to `#f`, `query` to `""`, `origin` to
`(Position new 0 0)`, and `wrapped` and `failing` to `#f`. Escape and Return
leave `echo` untouched; a forwarded key applies the ordinary idle rule to
it. The session consumes `"find"`, so normal session dispatch never sends
it to `AloemacsEditor.handle-key`.

Every query edit discards the previous match/failure status and seeks from
the captured origin. On a hit, put point at the first character of the
match and record whether this attempt wrapped. On a miss, return point to
`origin`, set `wrapped = #f`, and set `failing = #t`. An edit can recover
from failure. Backspacing an already empty query stays at the origin. Only
printable one-character keys enter the query, so it contains no LF.

## Ordered search

For a query edit, start at `origin`. For Ctrl-F after an unwrapped hit,
start at `(current.line, current.column + 1)`. Search the start line at its
start column, then later lines at column 0. If none matches, make one wrap
pass: search lines from line 0 up to the line before the start line, then
eligible match starts strictly before the start column on the start line.
The first hit in that order wins. Do not match across a line break. A
wrapped hit sets `wrapped = #t`; a later Ctrl-F fails without scanning.

Call `String.find` at most once per candidate line per attempt. The start
line has both a suffix and a deferred prefix candidate. The accepted spec
§4.3 permits one temporary String made of the suffix, an LF sentinel, and
the prefix through `start-column + query-length - 1` characters (clamped to
the line length). The query contains no LF, so no hit crosses the sentinel.
A hit before it maps to `start-column + hit-index`; a hit after it maps to
`hit-index - suffix-length - 1` and is held until later and earlier lines
have been checked. This prefix includes a match that starts before the
column and extends past it. Equivalent single-call logic is allowed. Do not
repeatedly `drop` and retry on one line.

## Echo and frame

For `rows >= 2`, select the echo row before clipping:

| Search state | Row |
|---|---|
| Active with empty query or unwrapped hit | `"search: " append query` |
| Active with wrapped hit | `"wrapped: " append query` |
| Active with failed attempt | `"failing: " append query` |

`failing` takes priority over `wrapped`. An inactive session uses the
existing path / `saved: ` / `failed: ` row. Search failure is distinct from
the saved idle token `"failed"`. Clip the selected row with `take columns`,
then send it through the stored editor's `safe-cells` method and the
existing ANSI suffix. Keep row allocation and the final text cursor exact.
At `rows = 1`, draw no echo row while search and point transitions still
work. Search does not change buffer text.

## Focused tests

Write failing focused tests before product edits. Use checked Aloe loads,
an Fs double, and no physical TTY.

`tests/aloemacs/search-key-mapping.rkt` proves both plain Ctrl-F message
shapes (`char = #f` and `char = #\f`), unchanged Ctrl-S, Ctrl-Z, and Escape,
and exclusion of printable `f`, Ctrl-Shift-F, and Alt-F.

`tests/aloemacs/search-session.rkt` proves:

1. The field order, idle defaults, entry capture, exit reset, visit reset,
   and preservation through ordinary rebuilds and `ensure-visible`.
2. Query typing including space, forward first hit, overlapping next hit,
   ordered wrap, and a wrapped start-line match that begins before the start
   column but extends past it. Verify no line is searched with `find` more
   than once per attempt by inspection of the search path.
3. Post-wrap failure, ordinary miss, recovery by edit, backspace, empty
   query, Escape and Return acceptance, and restoration of a prior `"saved"`
   echo without quit or newline.
4. An arrow, Ctrl-S, and Ctrl-Z forwarded from active search; idle Ctrl-S
   still saving; idle Escape still quitting. Check unchanged text and exact
   undo history throughout search motion.
5. Exact `search: `, `wrapped: `, and `failing: ` rows, right clipping,
   `safe-cells`, ANSI suffix, and final text cursor with no TTY. Include
   `rows = 1`, where search still moves point without drawing an echo row.

Keep existing session, key mapping, frame, and runner tests green. Update
only the seven named constructor/source fixtures as needed for the new
fields; preserve their existing behavioral assertions and frame goldens.

## Verification and completion

From the project root, run:

```sh
TMPDIR=/tmp raco test tests/aloemacs/search-session.rkt tests/aloemacs/search-key-mapping.rkt
TMPDIR=/tmp raco test tests/aloemacs
TMPDIR=/tmp raco test tests
git diff --check
```

Completion requires the focused tests, aloemacs suite, and full repository
suite to pass. Inspect the completed scan for the one-`find`-per-line limit
and the editor rebuilds for unchanged text and undo history. Report the
changed files and test results, then stop for human review. Do not issue a
further search checkpoint.

## Explicit non-goals

- A new String or Term message, a new editor field, a Text change, or a
  runner protocol change.
- Reverse search, case folding, regular expressions, replace, highlighting,
  remembered queries, or a minibuffer/query cursor.
- A keymap data structure, prefix commands, new motion commands, mutation,
  inheritance, macros, special forms, or implicit numeric coercion.
