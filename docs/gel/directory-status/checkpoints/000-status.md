# gel-directory-status 000 — listing status

**Spoken name.** gel-directory-status 000. Not “checkpoint 118” and not
“gel 000”.

**Branch.** Continue on `experiment/2026-09-11-gel-presentations` after
green gel-presentations 003. Do not start from `main` and do not merge to
`main`.

**Depends on.** Global 112–117 (frozen Directory UX) and gel-presentations
000/002/003 (Gel-owned List and Directory presentations).

**Status.** Ready to implement.

**Authority.** `SPEC.md` is Aloe language law. Frozen Directory behavior is
`docs/gel-directory-surface.md` and global checkpoints 112–117. The
presentation ownership established by gel-presentations 000/002/003 stays
unchanged.

The implementer receives only this document.

## Goal

Add a small status block to the live Directory menu. It reports how many
names are in the filtered listing and, only when that listing spans more than
one page, the current page and total page count.

The block sits after the child rows and before the existing `u`, `.`, `n`,
and `p` command lines. This slice does not change any key or page transition.

## Required behavior

Count the unwindowed `GelValueRows` produced by the selected Directory
presentation:

```text
host listing -> hidden-name filter -> count -> current 22-row window
```

The count is therefore the number of names in **this listing**, after the
current hidden-name filter and before the page window. Toggling `.` changes
the count. Use the rows Gel already obtained for this draw; do not list the
host again and do not call `Directory.entries` from `GelText`.

For an empty or one-page listing (page count `<= 1`), print only:

```text
0 entries\r\n
```

or, for example:

```text
12 entries\r\n
```

For a listing with more than one page, append a second line:

```text
180 entries\r\n
page 1 of 9\r\n
```

The last page in that example says:

```text
180 entries\r\n
page 9 of 9\r\n
```

The displayed page is 1-based. `GelStep.page` remains 0-based, so display
`page + 1`. Let `page-size` be `(gel-item-keys len)` (currently 22), not a
copied integer. Compute the page count with existing `Int` sends:

```text
((count + (page-size - 1)) / page-size)
```

Use `(n text)` for each displayed `Int`. Do not add arithmetic or formatting
to the kernel. When `count` is `0`, omit the page line; never print
`page 1 of 0`. When the page count is `1`, omit it; never print
`page 1 of 1`. The word is exactly `entries`, including for `1`.

Keep the existing transcript spacing. If child rows are nonempty, retain one
blank CRLF line between the last child and the status block. If the visible
page is empty, begin directly with the count line. Put no blank line inside
the status block or between the status block and `u  up`. For example:

```text
a  alpha\r\n
b  bravo/\r\n
\r\n
23 entries\r\n
page 1 of 2\r\n
u  up\r\n
.  show hidden\r\n
n  next\r\n
p  prev\r\n
```

An empty listing is exactly the status followed by the unchanged commands:

```text
0 entries\r\n
u  up\r\n
.  show hidden\r\n
n  next\r\n
p  prev\r\n
```

Keep `n  next` and `p  prev` visible on empty, one-page, first, middle, and
last pages. Do not hide, dim, recolor, or change their no-op-at-boundary
behavior.

Only a live Directory TOS gets this block. List menus remain unpaged and get
no count or page text. File, SymbolicLink, Other, Point, Int, derived-message
menus, and pending menus remain byte-for-byte unchanged.

## Chosen shape

Keep the existing Directory presentation methods on
`GelDirectoryPresentations`; do not move or add methods on disk classes.
Keep `GelMenu`, `GelStep`, and the stack representation unchanged.

Refactor the Directory branch of `GelMenus` so one internal path selects
`directory-values` or `directory-all-values`, invokes that presentation once,
and returns the full filtered `GelValueRows`. Both menu handling and drawing
use that path. `GelMenus.of` applies its existing `window` to those rows and
continues to return `(GelMenu Values ...)` as today.

For Directory drawing, `GelText.menu` obtains those full rows once, binds
`count` from `(rows len)`, applies the existing `GelMenus.window`, renders the
visible child rows, and inserts the status text before the unchanged command
block. Do not obtain a windowed `GelMenu` and then invoke the Directory
presentation a second time for the count.

The status formatting belongs to `GelText`; Directory recognition,
presentation selection, and windowing remain in `GelMenus`. Do not add a
field to `Directory`, `GelStep`, `GelMenu`, or `GelValueRows`. Do not add a
pager/status object, cache, snapshot, or second host-listing path. Existing
reachable page bounds and reset rules remain sufficient; do not clamp or
mutate page state while drawing.

## Exact file scope

Implementation may edit only:

- `gel/menu.aloe` (`GelMenus` reuse of the unwindowed Directory rows)
- `gel/loop.aloe` (`GelText` status formatting and Directory menu assembly)
- `tests/gel/directory-status/000-status.rkt` (new)
- living tests that snapshot a complete Directory menu: only insert the new
  status bytes into those expectations

Do not edit `gel/directory.aloe`, `gel/presentations.aloe`, `gel/main.aloe`,
or `gel/stack.aloe`. Do not edit anything under `aloe/`, `lib/`, or `host/`.
Do not edit `SPEC.md`, root `CHECKPOINTS.md`, prior checkpoint documents, or
the gel-presentations series. Do not add `docs/checkpoints/0118-*.md` or
`tests/checkpoint-118.rkt`.

Tests sit deeper than the global suite. In the new test use the extra `../`
in `require` and `define-runtime-path` paths (`../../../aloe/...` from
`tests/gel/directory-status/`).

## Tests and acceptance

Use controlled filesystem doubles rather than repository contents. Cover at
least:

1. Exact CRLF bytes and placement for `0`, `1`, `22`, `23`, and `180`
   entries. `0`, `1`, and `22` have no page line; `23` reports pages 1 and 2
   of 2; `180` reports page 1 and page 9 of 9.
2. A hidden-name fixture proves the count is after filtering and before the
   window. Toggling `.` changes the count and can change whether the page line
   exists; existing page reset and row order remain unchanged.
3. Rendering one Directory menu invokes the selected listing presentation
   once. An instrumented filesystem double proves status calculation does not
   make a second host `names` call.
4. Empty and one-page Directories still show `n  next` and `p  prev` with
   their existing no-op behavior. Multi-page navigation, item selection,
   0-based `GelStep.page`, and page resets are unchanged.
5. List, File, SymbolicLink, Other, Point, Int, derived-message, and pending
   menu bytes have no `entries` or `page N of M` status.
6. Directory presentation methods remain on the Gel-owned host-holding class;
   disk and List method tables do not grow. No ANSI/CSI, color, Term method,
   pager object, search, or armed-window machinery appears.
7. Global 112–117, gel-presentations 000/002/003, and the full suite remain
   green. Existing full-Directory snapshots change only by insertion of the
   required footer bytes.

When a physical TTY and `tui-term` are available, run:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

From an overflowing directory such as `/etc` or `/usr/bin`, confirm the
filtered count, `page 1 of M`, a correct last-page number, and a changed count
after `.`. Confirm `n` / `p` remain visible at both boundaries.

Run:

```sh
raco test tests/gel/directory-status/000-status.rkt
raco test tests
git diff --check
```

Do not run `raco test tests/*.rkt`; that glob skips this folder.

The checkpoint is complete when the exact Directory status bytes, filtered
unwindowed count, page arithmetic, single-listing behavior, and unchanged
surrounding Gel behavior are green. Stop for review without committing and
without starting gel-directory-status 001 or global checkpoint 118.

## Explicit non-goals

- No hiding or dimming `n` / `p`
- No ANSI, color, terminal capability, or full-screen TUI work
- No search `/`, armed window, multi-column layout, or two-key addressing
- No options object, home `~`, root jump, visible stack, or file contents
- No List paging or status, and no status on non-Directory TOS values
- No disk-class, filesystem-host, kernel, evaluator, checker, or library work
- No pager/status object, cache, or new `GelStep` state
- No gel-presentations 001 or 004 and no global checkpoint 118
