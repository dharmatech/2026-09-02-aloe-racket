# Checkpoint-manager brief — Gel Directory paging

**Status.** Working handoff for **one** checkpoint-manager conversation.
Not law. Not a checkpoint. Not an implementer assignment.

**Depends on.** Checkpoint 116 (hidden names) already green.

**Your job.** Write **checkpoint 117 only**: a live Directory listing
is a page of item keys; idle `n` / `p` move to the next / previous
page. Then **stop**. Do not implement. Do not write search, an armed
window, or an options menu.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this brief and the authority files in §3.
2. Write `docs/checkpoints/0117-gel-directory-paging.md`.
3. Stop. The human reviews it.

The implementer will not have this brief. Put every rule they need in
the checkpoint itself.

Keep the checkpoint **small**. A 600-line file or a generic collection
pager is a defect. Directory only, transcript replace, same machine as
hidden files.

## 2. Why this slice exists

Hidden names fixed page one of a home directory. `/etc` and `/usr/bin`
still overflow one screen. Git Menu paged its pickers with `n` / `p`
and then assigned those keys to entries. Do not repeat that collision.

## 3. Authority

- `docs/gel-directory-surface.md` ranked follow-up item 3.
- Checkpoints 112–116: `gel/directory.aloe`, hidden filter, 24-letter
  pool that still includes `n` and `p`, `u` / `.` / Escape / `q`.
- `lib/disk.aloe` stays Gel-ignorant. Do not edit `aloe/` or `host/`.
- List has no kernel `take`. Window the listing with existing List
  `fold` / `len` / `first` / `rest`. Do not add List `take` to the
  kernel to get paging.
- `SPEC.md` is law. Parent: `experiment/gel-directory-surface` after
  116.

## 4. Required observable

When TOS is a live `Directory`:

- `n` and `p` **leave the item pool**. Reindex the remaining letters
  `a`–`m`, `o`, `r`–`t`, `v`–`z` as keys 1..22. Page size is that
  pool’s length (22), not 24.
- Pipeline: host entries → hidden-name filter (116) → **then** the
  current page window → **then** assign item keys. Do not cap inside
  `gel-directory-values` at 24 and then fail to page.
- Idle `n` advances one page when more names remain after this page;
  otherwise no-op. Idle `p` goes back one page when `page > 0`;
  otherwise no-op. Neither push, pop, nor `parent`.
- `page` starts at 0 on `GelMain.start` / a fresh step.
- **Reset `page` to 0** on push, pop, `u`, and hidden-name toggle.
  Copy `page` on pending, cancel, quit, and other no-ops. This is the
  opposite of `show-hidden`, which persists across folders.
- Pending `n` / `p` are no-ops (do not page, do not type).
- Point, List, File, and every non-Directory TOS: idle `n` / `p`
  remain no-ops. Do not page List `gel-values` in this slice.
- Precedence when idle:

```text
q, Escape, u, ., n, p, then item/message keys
```

- Discoverable command lines on Directory menus, always (even one-page
  listings), next to `u` / `.`:

```text
n  next
p  prev
```

  No “page 2/17” chrome. No two-key labels. No multi-column.

Item-row labels, TOS path text, hidden filter, and `.` toggle stay as
in 116. Living tests that treat `n` or `p` as item keys, or that assume
24 Directory item slots, may update **only** those expected bytes /
pool lengths.

## 5. Preferred shape

Add `(page Int)` to `GelStep`. Every `GelStep new` in `gel/*.aloe`
copies `(self page)` except the reset cases above and the `n` / `p`
successors (`page + 1` / `page - 1`). Living constructors may pass `0`.

Keep the two zero-argument Directory selectors. They should yield the
**full** filtered or unfiltered child list (still labeled), not a
pre-capped 24. Gel applies the window of size `(gel-item-keys len)`
starting at `(page * page-size)` in **one** place used by both drawing
and `handle-idle`.

Do not build a pager object, options menu, search, armed window, or
GelFS. Do not call `(top subject)` into a new generic method.

## 6. Explicit non-goals

- Search `/`, two-key / prefix addressing, armed window, multi-column
- Options object, home `~`, root jump
- Color, visible stack history, File contents
- Paging List or derived message menus
- Kernel List `take` / `drop`
- GelFS, hooks, plugins, keymaps

## 7. Stop condition

The conversation is done when `docs/checkpoints/0117-gel-directory-paging.md`
exists. Do not implement it. Do not write checkpoint 118.
