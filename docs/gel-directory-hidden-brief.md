# Checkpoint-manager brief — Gel Directory hidden names

**Status.** Working handoff for **one** checkpoint-manager conversation.
Not law. Not a checkpoint. Not an implementer assignment.

**Depends on.** Checkpoint 115 (`lib/string.aloe` `starts-with?`)
already green. Do not start this conversation before that lands. Do not
add String messages in this slice.

**Your job.** Write **checkpoint 116 only**: Directory listings hide
names that start with `"."` by default, and idle `"."` toggles that
filter. Then **stop**. Do not implement. Do not write paging, search,
or an options menu.

If you have been told to read this file, this is the whole assignment.

## 1. How this conversation works

1. Read this brief and the authority files in §3.
2. Write `docs/checkpoints/0116-gel-directory-hidden.md`.
3. Stop. The human reviews it.

The implementer will not have this brief. Put every rule they need in
the checkpoint itself.

Checkpoint shape follows 108–113, but this slice must stay **small**.
A 600-line checkpoint is a defect. Do not produce another 112.

## 2. Why this slice exists

First live use of a home directory spent the whole 24-key page on
dotfiles. `journal/` never appeared. Paging would not fix page one.
Hide leading-dot names by default; let `.` show them.

## 3. Authority

- `docs/gel-directory-surface.md` ranked follow-up item 2.
- Checkpoint 112/113 Directory surface: `gel/directory.aloe`,
  `gel-directory-values`, 24-letter item pool, `u` / Escape / `q`.
- `lib/disk.aloe` stays Gel-ignorant. Host `names` already omits `.`
  and `..`; do not change the host.
- `(name starts-with? ".")` comes from `lib/string.aloe` (checkpoint
  115). Do not reimplement it.
- `SPEC.md` is law. Parent branch: `experiment/gel-directory-surface`
  after checkpoint 115.

## 4. Required observable

When TOS is a live `Directory` and hidden names are off (default):

- Child rows omit every item whose `name` answers true to
  `(name starts-with? ".")`
- Filter **before** the 24-key cap, so a home directory shows ordinary
  names on page one
- Idle `.` toggles the filter on the same TOS (does not push, pop, or
  send `parent`)
- The flag persists across push, pop, `u`, and pending cancel until
  toggled again; `GelMain.start` / a fresh step default to hidden
- Pending `.` is a no-op (does not toggle, does not type)
- `.` is not an item key and does not steal `q`, Escape, or `u`
- Precedence when idle: `q`, Escape, `u`, `.`, then item keys
- Discoverable command line next to `u  up`, state-dependent:

```text
.  show hidden
.  hide hidden
```

  First form while hiding (default); second form while showing.

Non-directory TOS (Point, List, File, …) ignores `.` as today aside
from existing no-op / pending rules. File derived menus are unchanged.

TOS path text from 113 is unchanged. Child labels still use `name/` and
`name@` for names that remain visible.

## 5. Preferred shape

Do not build an options object or menu framework.

Keep `gel-directory-values` as the default zero-argument listing
(filter then cap). Add a second zero-argument selector
`gel-directory-all-values` (no name filter, then the same cap). Gel
chooses which owned signature to invoke from a Bool on `GelStep`.

Thread that Bool from the step into menu construction **and** into
`handle-idle` so displayed keys match the handler. A `GelMenus.of`
overload that takes the Bool is fine; Point/List paths ignore it.

If `GelStep` gains a field, every `GelStep new` in `gel/*.aloe` must
copy the flag; living tests that construct five-argument `GelStep new`
may pass a sixth `#f` and must not be otherwise rewritten.

Do not call `(top subject)` into a new generic method. Do not edit
`aloe/`. Do not edit `lib/disk.aloe` or `host/`.

## 6. Explicit non-goals

- Paging, search, armed window, multi-column
- Options object, home `~`, root jump
- Color / AS400 TUI, visible stack history
- File contents, refresh, workspace, processes
- GelFS, hooks, plugins, keymaps
- Further string library methods
- Changing which names the host returns

## 7. Stop condition

The conversation is done when `docs/checkpoints/0116-gel-directory-hidden.md`
exists. Do not implement it. Do not write checkpoint 117.
