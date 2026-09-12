# Checkpoint manager — Gel Directory dim unavailable paging

**Status.** Assignment for a **checkpoint-manager conversation**.
Not Aloe law. Not a checkpoint. Not an implementer assignment.
Index: [`README.md`](README.md).

**Your job.** Write **gel-directory-dim 000 only**: on a live
Directory menu, print `n  next` and `p  prev` with ANSI faint (SGR
`2`) when that move is a no-op; print them normally when the move
works. Then **stop**. Do not implement. Do not hide the lines. Do
not add a color system, a Term capability, or search.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this file and the authority in §3.
2. Write `docs/gel/directory-dim/checkpoints/000-dim-paging.md`
   (slug may be tighter).
3. Stop. The human reviews it.

The implementer will not have this file. Put every rule they need in
the checkpoint itself.

Keep the checkpoint **small**. This is two command lines in
`GelText`. A style library, `NO_COLOR` host flag, or pager object is
a defect.

## 2. Why this slice exists

Status already says `page 1 of 9`. `p  prev` on page one still looks
live. Dimming keeps the command block’s layout (unlike hiding) and
marks the dead move. Term `write-line` is Racket `display` of a
String; CSI in that string already reaches the TTY. No new host
method.

## 3. Authority

- Frozen Directory UX: global 112–117, gel-presentations,
  gel-directory-status 000
- `host/racket/term.rkt`: `(term write-line string)` displays the
  string then `\r\n`. Not a tui-term drawing API
- Aloe `.aloe` files use Racket `read`, so `"\x1b[2m"` is a legal
  String
- Do not patch `Directory`. Presentations stay Gel-owned
- `SPEC.md` is law
- Parent branch: `experiment/2026-09-11-gel-presentations`

If this wants a color capability, hiding instead of dimming, or
kernel string escapes, **stop** and send the human back to the
brainstorm.

## 4. Where files go (local series)

Identity is `(gel-directory-dim, 000)`, not the next global integer.

| | Path |
|---|---|
| Checkpoint | `docs/gel/directory-dim/checkpoints/000-dim-paging.md` |
| Test | `tests/gel/directory-dim/000-dim-paging.rkt` |

Spoken name: **gel-directory-dim 000**. Do **not** write
`docs/checkpoints/0118-….md` or `tests/checkpoint-118.rkt`. Do not
append root `CHECKPOINTS.md`.

From `tests/gel/directory-dim/` use `../../../aloe/…` in `require`
and `define-runtime-path`.

```sh
raco test tests/gel/directory-dim/000-dim-paging.rkt
raco test tests
```

Do **not** tell the implementer to run `raco test tests/*.rkt`.
After the slice exists, list it in [`README.md`](README.md).

## 5. Required observable

When TOS is a live `Directory`, the command block still always
contains `n  next` and `p  prev` (and `u` / `.` as today).

Wrap **only** a dead paging line in faint SGR, then reset:

```text
ESC [ 2 m   n  next   ESC [ 0 m
ESC [ 2 m   p  prev   ESC [ 0 m
```

In Aloe source that is `"\x1b[2m"` and `"\x1b[0m"`. The `\r\n` after
the line is **not** inside the SGR span.

When the move is legal, those two lines are exactly today’s bytes
(`n  next\r\n`, `p  prev\r\n`) with no CSI.

Dead vs live uses the same rules as `handle-next` / `handle-prev`:

- `p` is dead iff `page` is `0`
- `n` is dead iff there is no remaining name after this page
  (same test as advancing to `page + 1` and finding an empty
  window, or `page + 1 >= page-count`)
- One-page listings: **both** lines print, both faint. That is
  the point of dim versus hide: layout does not jump

`u` and `.` are never dimmed in this slice. Non-Directory TOS is
unchanged. Pending `n` / `p` stay no-ops. Keys stay reserved; they
do not become item keys. No-op behavior of idle `n` / `p` does not
change.

Do not emit color (SGR 3x / 9x) in this slice. Faint `2` only.
Scripted tests assert the CSI bytes in `GelText` output; do not add
a TTY-only branch or a new Term method.

Physical TTY hand check: `/etc` page 1 shows a faint `p  prev` and
a normal `n  next`. Last page reverses that.

Living tests that snapshot Directory command lines may update **only**
the CSI on dead `n` / `p` lines.

## 6. Preferred shape

A tiny Gel helper that wraps a command line, used from the existing
Directory command block in `gel/loop.aloe`. Compute dead/live from
the same unwindowed row count status already has. Do not re-list the
host. Do not add fields on `Directory` or `GelStep`.

No `aloe/`, `lib/disk.aloe`, `host/`, or `tui-term` API.

## 7. Explicit non-goals

- Hiding `n` / `p` when dead
- Color, bold, underline, alt-screen, cursor addressing
- `NO_COLOR`, Term style capability, full-screen TUI
- Search, armed window, options, home `~`
- Dimming `u`, `.`, or item rows
- Kernel changes, disk patches
- Global checkpoint 118
- gel-directory-dim 001

## 8. Stop condition

The conversation is done when
`docs/gel/directory-dim/checkpoints/000-dim-paging.md` exists and
[`README.md`](README.md) lists it. Do not implement it.
