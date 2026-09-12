# gel-directory-dim 000 — dim unavailable paging

**Spoken name.** gel-directory-dim 000. Not “checkpoint 118” and not
“gel 000”.

**Branch.** Continue on `experiment/2026-09-11-gel-presentations` after
green gel-directory-status 000. Do not start from `main` and do not merge to
`main`.

**Depends on.** Global 112–117 (frozen Directory UX), gel-presentations
000/002/003 (Gel-owned presentations), and gel-directory-status 000 (the
filtered count and optional `page N of M` block).

**Status.** Ready to implement.

**Authority.** `SPEC.md` is Aloe language law. Frozen Directory behavior is
`docs/gel-directory-surface.md` and global checkpoints 112–117. Presentation
ownership stays as established by gel-presentations 000/002/003. The existing
status and its single unwindowed listing path stay as established by
gel-directory-status 000.

The implementer receives only this document.

## Goal

Keep both paging commands in every live Directory menu, but render a command
with ANSI faint (SGR `2`) when pressing it would be a no-op at the current
page boundary. A legal move retains today's exact plain bytes.

This is a two-line presentation change in `GelText`. It does not change key
handling, page state, Directory presentations, or the terminal capability.

## Required behavior

For an idle live `Directory` TOS, keep the existing command order:

```text
u  up
.  show hidden
n  next
p  prev
```

The `.` line still says `hide hidden` while hidden names are shown. Only the
`n  next` and `p  prev` lines are eligible for faint styling. Never hide
either line.

A paging line is dead under exactly the same boundary rule as its existing
idle transition:

- `p` is dead iff `GelStep.page` is `0`; it is live whenever `page > 0`.
- `n` is dead iff the next 22-row window would be empty. Equivalently, with
  `page-count` computed from the current full filtered row count,
  `n` is live iff `page + 1 < page-count`.

Derive page size from `(gel-item-keys len)`, not a copied `22`. Derive the
count from the same unwindowed `GelValueRows` already obtained once for the
Directory draw and used by the status block. Do not invoke a presentation or
list the host again.

The visible cases are:

- Empty and one-page listings: both paging lines remain present and both are
  faint.
- First page of a multi-page listing: `n` is plain and `p` is faint.
- A middle page with names on both sides: both lines are plain.
- Last page: `n` is faint and `p` is plain.

The selected hidden-name presentation determines the count. Therefore a `.`
toggle may change which paging lines are live after it resets the page to
zero. Existing row order, count text, page text, page resets, and navigation
semantics do not otherwise change.

### Exact bytes

For a dead line, emit the ESC byte (`0x1b`), `[2m`, the existing command text,
ESC, `[0m`, and only then CRLF:

```text
ESC [ 2 m n  next ESC [ 0 m CR LF
ESC [ 2 m p  prev ESC [ 0 m CR LF
```

In Aloe source the two control strings are exactly `"\x1b[2m"` and
`"\x1b[0m"`. Thus the logical String assembly is:

```text
"\x1b[2m" + "n  next" + "\x1b[0m" + "\r\n"
"\x1b[2m" + "p  prev" + "\x1b[0m" + "\r\n"
```

The reset must precede `\r\n`; the line ending is not inside the SGR span.
Do not emit bold, underline, or foreground/background color (SGR `3x` /
`9x`). Do not combine faint with another SGR parameter.

For a live move, preserve today's bytes exactly, with no CSI before or after:

```text
n  next\r\n
p  prev\r\n
```

The existing child rows, blank line, count, optional `page N of M`, `u`, and
`.` bytes are unchanged. `u` and `.` are never dimmed in this slice. For
example, a one-entry default-hidden Directory ends with:

```text
1 entries\r\n
u  up\r\n
.  show hidden\r\n
\x1b[2mn  next\x1b[0m\r\n
\x1b[2mp  prev\x1b[0m\r\n
```

Pending menus remain byte-for-byte unchanged; pending `n` / `p` remain
no-ops. List, File, SymbolicLink, Other, Point, Int, and every other
non-Directory TOS remain byte-for-byte unchanged. Non-Directory idle `n` /
`p` remain no-ops. The keys stay reserved and never become item keys.

## Chosen shape

Add one small `GelText` helper that accepts a paging command's plain text and
whether the move is live, returning either the plain command plus CRLF or the
faint-wrapped command, reset, and CRLF. Use it for the two existing paging
lines in the Directory command block in `gel/loop.aloe`.

In the Directory branch of `GelText.menu`, bind the full rows and their
`count` once. Continue to use those rows for the current window and the
existing status. Compute paging availability from that same count, current
page, and `(gel-item-keys len)`. A tiny `GelText` helper for the existing
ceiling page-count arithmetic is acceptable; a style library, pager object,
or new state object is not.

Do not change `GelStep.handle-next` or `handle-prev`. Their behavior is the
authority for the display predicates, and their current no-op identity,
non-wrapping movement, and precedence remain intact. Do not add fields to
`Directory`, `GelStep`, `GelMenu`, or `GelValueRows`.

`Term.write-line` already uses Racket `display` on the supplied String and
then writes `\r\n`. Keep the CSI bytes in the String produced by `GelText`;
do not add a Term method, terminal-mode test, TTY-only branch, or capability
probe.

## Exact file scope

Implementation may edit only:

- `gel/loop.aloe` (`GelText` paging-line formatting and availability)
- `tests/gel/directory-dim/000-dim-paging.rkt` (new)
- living tests that snapshot complete Directory command lines, only to add or
  remove the required faint/reset CSI around dead `n` / `p` text

Do not edit `gel/menu.aloe`, `gel/directory.aloe`, `gel/main.aloe`, or
`gel/stack.aloe`. Do not edit anything under `aloe/`, `lib/`, or `host/`.
Do not edit `SPEC.md`, root `CHECKPOINTS.md`, prior checkpoint documents, or
the gel-presentations / gel-directory-status series. Do not add
`docs/checkpoints/0118-*.md` or `tests/checkpoint-118.rkt`.

Tests sit one directory deeper than the global suite. In the new test use
`../../../aloe/...` in `require` and `define-runtime-path` paths.

## Tests and acceptance

Use controlled filesystem doubles rather than repository contents. Cover at
least:

1. Exact `GelText` output for `0`, `1`, and `22` names on page zero: both
   paging lines are present, faint, reset, and terminated by CRLF outside the
   SGR span.
2. Exact first- and last-page output for `23` names: page zero has plain `n`
   and faint `p`; page one has faint `n` and plain `p`. A three-page fixture's
   middle page has both lines plain. Plain lines contain no CSI.
3. The command order and all surrounding bytes remain unchanged: child rows,
   blank-line rule, filtered count, optional page status, `u`, and both forms
   of the `.` command. ANSI occurs only around dead paging text; no SGR color
   code appears.
4. A hidden-name fixture proves availability uses the selected full filtered
   rows before the window. Toggling `.` can change a one-page listing into a
   multi-page listing while retaining the existing page-zero reset.
5. One Directory draw still invokes the selected listing presentation once.
   An instrumented filesystem double proves dimming does not cause a second
   host `names` call.
6. The displayed live/dead state agrees with `handle-next` / `handle-prev` on
   first, middle, and last pages. Successful moves, no-op identity, stack
   contents, page numbers, item selection, and reset rules remain unchanged.
7. Empty and one-page `n` / `p`, pending `n` / `p`, and non-Directory idle
   `n` / `p` keep their existing no-op behavior. Pending and non-Directory
   menu bytes remain unchanged and gain no CSI.
8. Directory presentation ownership, the 22-letter key pool, status
   calculation, and Term interface remain unchanged. No color/style system,
   `NO_COLOR`, pager, search, armed window, TTY branch, or new Term method is
   introduced. Global 112–117, gel-presentations 000/002/003,
   gel-directory-status 000, and the full suite remain green.

When a physical TTY and `tui-term` are available, run:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

From an overflowing directory such as `/etc` or `/usr/bin`, confirm page one
shows faint `p  prev` and plain `n  next`; navigate to the last page and
confirm the reverse. A one-page Directory shows both lines faint, without a
layout change.

Run:

```sh
raco test tests/gel/directory-dim/000-dim-paging.rkt
raco test tests
git diff --check
```

Do not run `raco test tests/*.rkt`; that glob skips this folder.

The checkpoint is complete when the exact faint/reset bytes, boundary
predicates, single-listing behavior, and unchanged surrounding Gel behavior
are green. Stop for review without committing and without starting
gel-directory-dim 001 or global checkpoint 118.

## Explicit non-goals

- No hiding `n` / `p`
- No color, bold, underline, style library, `NO_COLOR`, or terminal capability
- No dimming `u`, `.`, item rows, TOS text, status text, or non-Directory text
- No full-screen TUI, alternate screen, cursor addressing, or terminal probing
- No search, armed window, options, home `~`, root jump, or multi-column UI
- No key, transition, page-reset, stack, presentation, or filesystem change
- No kernel, checker, evaluator, library, disk, host, or runner change
- No global checkpoint 118 and no gel-directory-dim 001
