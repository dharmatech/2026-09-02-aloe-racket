# Checkpoint 117 — Gel Directory paging

**Branch.** Continue on `experiment/gel-directory-surface` after reviewed,
green checkpoint 116.

**Depends on.** Checkpoints 112–113 (live Directory surface and TOS text),
checkpoint 111 (shared item-key pool), and checkpoint 116 (hidden-name filter
and `.` toggle).

**Status.** Ready to implement.

## Goal

A live Directory listing is one page of item keys. Idle `n` / `p` move to the
next / previous page. `n` and `p` leave the item-key pool so they never collide
with entries.

This is a small Gel application change. The implementer receives only this
document. Directory only. Transcript replace. Same machine as hidden files.

Stop and return this checkpoint for revision before writing any code if the
work starts to do any of:

- add List `take` or `drop` to the kernel or to `lib/list.aloe`
- page List `gel-values` / any non-Directory menu
- keep `n` or `p` as item keys on any listing

## Required behavior

When TOS is a live `Directory`:

- `n` and `p` **leave the item pool**. Reindex the remaining letters as keys
  `1..22`:

```text
a b c d e f g h i j k l m o r s t v w x y z
```

  Page size is `(gel-item-keys len)` (22), not a copied `24`. `q` and `u`
  stay absent. `n` and `p` now join them: `(gel-item-keys index "n")` and
  `"p"` are `0`; `(GelKey new "n")` / `"p"` have `item-index` `0`.

- Pipeline: host entries → hidden-name filter (116) → **then** the current
  page window → **then** assign item keys. Do not cap inside
  `gel-directory-values` / `gel-directory-all-values` and then fail to page.

- Idle `n` advances one page when the next page has at least one remaining
  name; otherwise no-op. Idle `p` goes to `page - 1` when `page > 0`;
  otherwise no-op. Neither wraps. Neither push, pop, nor `parent`.
- `page` starts at `0` on `GelMain.start` / a fresh step.
- **Reset `page` to `0`** on push, pop, `u`, and hidden-name toggle. Copy
  `page` on pending, cancel, quit, and other no-ops. This is the opposite of
  `show-hidden`, which persists across folders.
- Pending `n` / `p` are no-ops (do not page, do not type).
- Point, List, File, and every non-Directory TOS: idle `n` / `p` remain
  no-ops. Do not page List `gel-values` in this slice. A long List still
  exposes only the first `(gel-item-keys len)` values and gains no `n` / `p`
  command lines.
- Exact lowercase `"n"` / `"p"` only. Uppercase, like uppercase `U`, is a
  no-op.
- Precedence when idle:

```text
q, Escape, u, ., n, p, then item/message keys
```

Item-row labels, TOS path text, hidden filter, and `.` toggle stay as in 116.
Living tests that treat `n` or `p` as item keys, or that assume 24 Directory
or List item slots, may update **only** those expected bytes / pool lengths.

## Chosen shape

Append `(page Int)` to `GelStep` after `show-hidden`. Add `GelKey` predicates
for the literals `"n"` and `"p"`. `GelMain.call` and every fresh constructor
pass `0`. Every later `GelStep new` in `gel/*.aloe` copies `(self page)` except:

| Successor | `page` |
| --- | --- |
| successful idle `n` | `(self page) + 1` |
| successful idle `p` | `(self page) - 1` |
| stack push (child, `u` parent, zero-arg send, pending invoke) | `0` |
| idle Escape pop (including the one-item floor) | `0` |
| successful idle `.` on a Directory | `0` (and toggle `show-hidden` as in 116) |

Keep the two zero-argument Directory selectors. They must yield the **full**
filtered or unfiltered labeled child list, not a pre-capped 24. Remove the
`(gel-item-keys len)` stop from `GelDirectoryRows.of` / the listing builder.

Gel applies the window of size `(gel-item-keys len)` starting at
`(page * page-size)` in **one** place used by both drawing and `handle-idle`:
after invoking the chosen Directory signature, `GelMenus.of` windows those
rows and rebuilds `GelValueRow` values with the same mirrors and labels,
indexes `1..k`. Preserve `of(Mirror)` as default-hidden page `0`, and
`of(Mirror, Bool)` as that Bool at page `0`. Thread `(state page)` from
`GelText.menu` and `handle-idle` into the three-argument `of`.

Idle `n` on a Directory asks that same `of` path for `(page + 1)` and
advances only when the window is nonempty. Guard with the existing
`directory?` seam first: List `of` ignores `page` and would still look
nonempty. Do not inspect `(top subject)`, parse a class name, or add a public
protocol.

Window with existing List `fold` / `len` / `first` / `rest`. Do not add List
`take` or `drop` to the kernel or to `lib/list.aloe`. Do not use String
`take` for lists.

Do not build a pager object, options menu, search, armed window, or GelFS.
Do not add a page argument to the Directory selectors. Point/List and
reflected-message fallbacks ignore `page` and remain unpaged.

## Menu text

An idle Directory menu still appends `u  up` and the 116 hidden command, then
always these two lines, even on one-page and empty listings:

```text
n  next
p  prev
```

Every command line ends in CRLF. In visible-byte notation the default block
is `u␠␠up␍␊.␠␠show␠hidden␍␊n␠␠next␍␊p␠␠prev␍␊`; the showing block substitutes
`hide` for `show`. If child rows are nonempty, retain exactly one blank CRLF
line between the last child and `u  up`. If no child rows remain, start
directly with `u  up`. There is no blank line between commands.

No “page 2/17” chrome. No two-key labels. No multi-column.

Pending menus do not show paging or hidden commands. Non-Directory menus gain
no `n` / `p` line. Checkpoint 113 TOS path bytes, File-derived menus, item
labels, key echo, and terminal line handling are unchanged.

## Exact file scope

Implementation may edit only:

- `gel/directory.aloe` (drop the pre-window cap so the two selectors return
  the full labeled list)
- `gel/menu.aloe` (22-letter pool, Directory window in `of`, List still capped
  at `(gel-item-keys len)` with no paging)
- `gel/loop.aloe`
- `gel/main.aloe` (fresh `page` `0`)
- `tests/checkpoint-117.rkt` (new)
- existing tests that construct six-field `GelStep` values, only to append a
  seventh `0`: checkpoints 62, 67, 69, 70, 72–76, 78–82, and 109–112, 116
- living pool / 24-slot / Directory command-byte expectations in checkpoints
  110, 111, 112, and 116, only for the new 22-letter pool, `n`/`p` as non-item
  keys, and the two new command lines
- `CHECKPOINTS.md` (append checkpoint 117 only)
- `docs/gel.md` (current Directory paging, 22-letter pool, List still unpaged)
- `docs/gel-directory-surface.md` (mark ranked follow-up item 3 complete only)
- `docs/handoff.md` (current state only)

When a listed historical test needs constructor migration and new Directory or
pool bytes, make only those narrow expectation changes. Do not otherwise
rewrite prior tests.

Do not edit anything under `aloe/`; any `lib/` file, especially
`lib/list.aloe` and `lib/disk.aloe`; `host/`; `bin/`; runners; examples;
`SPEC.md`; `docs/decisions.md`; prior checkpoint documents; or unrelated
tests. Do not add List `take` / `drop`. Do not add hidden files.

## Tests and acceptance

Add `tests/checkpoint-117.rkt`. Use controlled filesystem doubles rather than
repository contents. Cover at least:

1. The shared pool is exactly the 22 letters above, indexes `1`–`22`. `n`,
   `p`, `q`, and `u` have item index `0`. List menus of length `0`, `1`, `22`,
   and greater than `22` still expose at most the pool length, with no `n` /
   `p` command text and with idle `n` / `p` no-ops.
2. The two Directory selectors return the **full** filtered / unfiltered
   labeled lists (more than 22 rows when the fixture has more). `gel-menus of`
   at page `0` / `1` windows to at most 22, reindexes from `1`, and keeps
   `/` and `@` labels. A fixture with more than 22 hidden names before
   ordinary names still filters before the window.
3. A Directory of 25 ordinary names: page `0` shows names `1`–`22` as `a`–`z`
   with `n`/`p`/`q`/`u` skipped; idle `n` then `a` pushes name `23`; a further
   `n` is a no-op on the last page. Idle `p` returns to page `0`; `p` on page
   `0` is a no-op. Neither changes the stack.
4. Exact command bytes, including the blank-line rule, for nonempty, empty,
   default-hidden, and showing-hidden Directory menus. One-page listings still
   show `n  next` and `p  prev`.
5. `page` is `0` after child push, Escape pop, successful `u`, and `.`
   toggle. `n` to page `1` then `.` shows page `0` of the other filter, not
   page `1`. `show-hidden` still persists across push, pop, and `u`. `page`
   is copied on quit, pending entry/cancel, and other no-ops.
6. Pending `n` / `p` leave Int input and typed stack-pick states unchanged.
   Non-Directory idle `n` / `p` are no-ops and add no command line.
7. `q`, Escape, `u`, `.`, and remaining item keys retain checkpoints 112 and
   116. Private selectors never become rows. TOS path text and File menus
   remain byte-for-byte unchanged.
8. A fresh `GelMain.start` is page `0`. A scripted session echoes `key n` /
   `key p`, redraws the next / previous Directory page, and preserves the
   final stack.
9. Source assertions enforce no changes under `aloe/`, `lib/`, or `host/`;
   no List `take` / `drop`; no List paging; and no search / armed-window /
   options machinery. Checkpoints 111, 112, 113, and 116 plus the full suite
   remain green.

When a physical TTY and `tui-term` are available, run:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

From a directory that still overflows after dots are hidden (`/etc` or
`/usr/bin`), confirm page one is 22 ordinary names, `n` shows the next names
with `a` rebound, `p` returns, and `q` leaves. List applications must not
page.

Append only this entry to `CHECKPOINTS.md`:

```text
## 117. [Gel Directory paging](docs/checkpoints/0117-gel-directory-paging.md)

- Live Directory menus page through children with idle `n` / `p` after those
  keys leave the 22-letter item pool. List menus stay unpaged. Pending and
  non-Directory `n` / `p` remain no-ops.
```

Run:

```sh
raco test tests/checkpoint-117.rkt
raco test tests/*.rkt
git diff --check
```

The checkpoint is complete when the Directory window, pool change, exact
command text, page-reset rules, and unchanged surrounding Gel behavior are
green. Stop for review without committing and without starting checkpoint
118.

## Explicit non-goals

- No search `/`, two-key / prefix addressing, armed window, or multi-column.
- No options object, home `~`, root jump, color, visible stack history, or
  File contents.
- No paging List or derived message menus.
- No kernel or library List `take` / `drop`.
- No GelFS, hooks, plugins, keymaps, pager object, or page chrome.
- No change to host `names`, disk objects, String messages, capability
  injection, or runners.
- No Aloe evaluator, checker, parser, reflection, syntax, or inference change.
