# Checkpoint manager — Gel Directory listing status

**Status.** Assignment for a **checkpoint-manager conversation**.
Not Aloe law. Not a checkpoint. Not an implementer assignment.
Index: [`README.md`](README.md).

**Your job.** Write **gel-directory-status 000 only**: a live
Directory menu shows how many names this listing contains, and
`page N of M` when there is more than one page. Then **stop**. Do
not implement. Do not hide or dim `n` / `p`. Do not add ANSI,
search, or an armed window. Do not write global checkpoint 118.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this file and the authority in §3.
2. Write `docs/gel/directory-status/checkpoints/000-status.md`
   (slug may be `status` or a tighter word).
3. Stop. The human reviews it.

The implementer will not have this file. Put every rule they need in
the checkpoint itself.

Keep the checkpoint **small**. This is footer text on the existing
Directory menu. A color system, Term capability, or pager object is a
defect.

## 2. Why this slice exists

Paging works, but `/etc` does not say where you are or how big the
directory is. Progress text is the information; hiding or dimming
dead `n` / `p` is a later slice. Do not combine those.

## 3. Authority

- `docs/gel-directory-surface.md` — Directory UX after paging
- Frozen from global 112–117 except this footer: 22-key pages, hidden
  filter, `u` / `.` / `n` / `p`, TOS path text
- gel-presentations 000/002/003: Gel-owned methods, not
  `define-methods Directory`. Do not put status methods on disk
  classes. Do not implement presentations 001.
- `(n text)` prints an `Int`. Int `/` `+` `-` `*` exist. Do not add
  kernel math.
- `SPEC.md` is law
- Parent branch: `experiment/2026-09-11-gel-presentations`

If paging, hidden names, or presentations want to change, **stop**
and send the human back to the brainstorm. Do not reopen those here.

## 4. Where files go (local series)

Identity is `(gel-directory-status, 000)`, not the next global integer.

| | Path |
|---|---|
| Checkpoint | `docs/gel/directory-status/checkpoints/000-status.md` |
| Test (implementer writes) | `tests/gel/directory-status/000-status.rkt` |

Spoken name: **gel-directory-status 000**. Zero-pad to three digits.
Do **not** write `docs/checkpoints/0118-….md` or
`tests/checkpoint-118.rkt`. Do not append to root `CHECKPOINTS.md`.

Tests sit deeper than the global suite. The checkpoint must tell the
implementer to use extra `../` in `require` and
`define-runtime-path` (`../../../aloe/…` from
`tests/gel/directory-status/`).

**How to run tests** (write these commands into the checkpoint):

```sh
raco test tests/gel/directory-status/000-status.rkt
raco test tests
```

Do **not** tell the implementer to run `raco test tests/*.rkt`; that
glob skips this folder.

After the slice file exists, list it in [`README.md`](README.md).

## 5. Required observable

When TOS is a live `Directory`, after the child rows and before the
command lines (`u`, `.`, `n`, `p`), print a status block.

Count is the number of names in **this listing**: after the hidden
filter, before the page window. Toggle `.` and the count must change.

Exact bytes, `\r\n` as in the rest of GelText:

**One page or empty** (page count `<= 1`) — count only, no page line:

```text
12 entries
```

```text
0 entries
```

**More than one page** — count, then page, 1-based on screen:

```text
180 entries
page 1 of 9
```

On the last page the second line is `page 9 of 9`. Internal
`GelStep.page` stays 0-based. Display page is `(page + 1)`. Page
count is

```text
((count + (page-size - 1)) / page-size)
```

with existing Int `/`. `page-size` is `(gel-item-keys len)` (22).
If `count` is 0, omit the page line (do not print `page 1 of 0`).

Locks:

- Do not change `n` / `p` visibility or no-op rules
- Do not emit ANSI / CSI / dim / color
- Do not page List menus. Non-Directory TOS has no status block
- Do not add `page 1 of 1`
- Word is `entries`, not `files`
- Living tests that snapshot a full Directory menu may update **only**
  the new footer bytes

Compute count from the unwindowed `GelValueRows` Gel already has
before `window`. Do not re-list the host. Do not add a field on
`Directory`. GelText / GelMenus only. No `aloe/`, `lib/disk.aloe`,
`host/`, or new Term method.

## 6. Explicit non-goals

- Hiding or dimming `n` / `p`
- ANSI, color, Term capability, full-screen TUI
- Search `/`, armed window, multi-column
- Options, home `~`, root jump
- Patching disk classes or `List`
- Kernel changes
- gel-presentations 001 / 004
- Global checkpoint 118

## 7. Stop condition

The conversation is done when
`docs/gel/directory-status/checkpoints/000-status.md` exists and
[`README.md`](README.md) lists it. Do not implement it. Do not write
gel-directory-status 001.
