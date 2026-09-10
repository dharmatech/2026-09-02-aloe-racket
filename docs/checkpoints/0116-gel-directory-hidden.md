# Checkpoint 116 — Gel Directory hidden names

**Branch.** Continue on `experiment/gel-directory-surface` after reviewed,
green checkpoint 115.

**Depends on.** Checkpoints 112–113 (live Directory surface and TOS text) and
checkpoint 115 (`String.starts-with?` in `lib/string.aloe`).

**Status.** Ready to implement.

## Goal

A live Directory menu hides leading-dot names by default so ordinary children
reach the 24-key page. While idle on a Directory, `.` toggles hidden-name
visibility and the menu says what the next `.` will do.

This is a small Gel application change. The implementer receives only this
document. Do not edit the Aloe language, String library, disk vocabulary, or
host listing behavior.

## Required behavior

With a live `Directory` on TOS and `show-hidden = #f` (the default):

- omit every child whose raw name answers true to
  `(name starts-with? ".")`;
- filter before assigning item keys and before the 24-row cap, preserving the
  relative source order of the remaining children;
- keep row indexes compact from 1, using the unchanged 24-letter key pool;
- keep existing labels, including `name/` for directories and `name@` for
  symbolic links.

With `show-hidden = #t`, include leading-dot names in their original source
order, then apply the same 24-row cap. The host already omits the exact `.` and
`..` entries; do not change or reproduce that host policy.

Idle `.` toggles the flag only when TOS has the live Directory adapter. It does
not push, pop, invoke `parent`, change TOS, or alter the stack. The flag
persists across child selection, reflected sends, `u`, Escape pop, pending
entry, pending cancellation, successful pending invocation, no-op keys, and
quit until toggled again. `GelMain.start` and every fresh interactive step
begin with `show-hidden = #f`.

Pending `.` remains a no-op: it neither toggles the flag nor contributes a
digit or stack pick. On Point, List, File, and every other non-Directory TOS,
idle `.` remains a no-op. It is not an item key. `q`, Escape, and `u` retain
their current meanings and precedence. Idle precedence is exactly:

```text
q, Escape, u, ., item/message keys
```

## Chosen shape

Append `(show-hidden Bool)` to `GelStep`. Add a `GelKey` predicate for the
literal `"."`. Every `GelStep new` in `gel/*.aloe` must either initialize the
new field to `#f` at `GelMain.call` or copy `(self show-hidden)` from the prior
step; only the valid idle Directory toggle negates it.

Keep the existing private zero-argument Directory selector as the default
filtered listing:

```aloe
(gel-directory-values () GelValueRows ...)
```

Add one second private zero-argument selector:

```aloe
(gel-directory-all-values () GelValueRows ...)
```

The first filters leading-dot names and then caps; the second skips only that
name filter and then applies the same cap. Share the existing Directory row
builder and label logic rather than duplicating a second menu implementation.
Use checkpoint 115's ordinary `(name starts-with? ".")` send. Do not implement
prefix logic locally or add another String method.

Thread `show-hidden` from `GelStep` into both menu construction and
`handle-idle`, so the displayed command and the key handler always use the
same state. Add a Bool-taking `GelMenus.of` path that selects and exactly
invokes the owned `gel-directory-values` or `gel-directory-all-values`
signature. Preserve the existing `of(Mirror)` entry point with default-hidden
behavior for callers that do not have a step. Point/List and reflected-message
fallbacks ignore the Bool and remain unchanged.

Recognize Directory through its existing private reflected seams; do not pass
`(top subject)` to a generic method, inspect raw text, parse a class name, or
add a public protocol. Both Directory-value selectors, `gel-up`, and
`gel-tos-text` remain private implementation seams and are not selectable menu
rows.

## Menu text

An idle Directory menu appends `u  up` and then one state-dependent command:

| State | Second command |
| --- | --- |
| `show-hidden = #f` | `.  show hidden` |
| `show-hidden = #t` | `.  hide hidden` |

Every command line ends in CRLF. In visible-byte notation, the default block
is `u␠␠up␍␊.␠␠show␠hidden␍␊`; the showing block substitutes
`hide` for `show`. If child rows are nonempty, retain exactly one blank CRLF
line between the last child and `u  up`. If no child rows remain, start
directly with `u  up`. There is no blank line between the two commands.

Pending menus do not show the hidden command. Non-Directory menus gain no
command line. Checkpoint 113 TOS path bytes, File-derived menus, item labels,
key echo, and terminal line handling are unchanged.

## Exact file scope

Implementation may edit only:

- `gel/directory.aloe`
- `gel/menu.aloe`
- `gel/loop.aloe`
- `gel/main.aloe`
- `tests/checkpoint-116.rkt` (new)
- existing tests that construct five-field `GelStep` values, only to append a
  sixth `#f`: checkpoints 62, 67, 69, 70, 72–76, 78–82, and 109–112
- `tests/checkpoint-112.rkt` and `tests/checkpoint-113.rkt`, only for Directory
  signatures/menu bytes intentionally changed here
- `CHECKPOINTS.md` (append checkpoint 116 only)
- `docs/gel.md` (current hidden-name behavior and `.` command only)
- `docs/gel-directory-surface.md` (mark ranked follow-up item 2 complete only)
- `docs/handoff.md` (current state only)

When a listed historical test needs both constructor migration and new
Directory bytes, make only those narrow expectation changes. Do not otherwise
rewrite prior tests.

Do not edit anything under `aloe/`; any `lib/` file, especially
`lib/string.aloe` and `lib/disk.aloe`; `host/`; `bin/`; runners; examples;
`SPEC.md`; `docs/decisions.md`; prior checkpoint documents; or unrelated
tests. Do not add hidden files.

## Tests and acceptance

Add `tests/checkpoint-116.rkt`. Use controlled filesystem doubles rather than
repository contents. Cover at least:

1. Default Directory rows omit all leading-dot names, retain ordinary names
   in source order, keep their existing `/` and `@` labels, and use compact
   item keys.
2. More than 24 hidden names before ordinary names proves filtering occurs
   before the cap. Showing hidden restores source order and caps only after
   inclusion.
3. The default menu ends with `u  up` then `.  show hidden`; one idle `.`
   changes the same TOS menu to `.  hide hidden`, and a second changes it back.
   Verify exact CRLF and blank-line bytes for nonempty and empty directories.
4. Toggling changes no stack item or TOS. Visibility persists through child
   push, Escape pop, `u`, a successful send, pending creation/cancel, and
   no-op keys.
5. Pending `.` leaves Int input and typed stack-pick states exactly unchanged.
   Non-Directory idle `.` is also a no-op and adds no command line.
6. `q`, Escape, `u`, and every item key retain their checkpoint-112 behavior;
   `.` is absent from the item-key pool.
7. The filtered and all-values rows come from the two exact owned Directory
   signatures. Private selectors never become selectable rows; TOS path text
   and File menus remain byte-for-byte unchanged.
8. A fresh `GelMain.start` hides leading-dot names. A scripted toggle redraws
   on the same Directory, echoes `key .`, shows hidden names, and preserves
   the final stack.
9. Checkpoints 112, 113, and 115 plus the full suite remain green. Source
   assertions enforce no changes under `aloe/`, `lib/`, or `host/` and no
   paging, search, or options machinery.

When a physical TTY and `tui-term` are available, run:

```sh
racket host/racket/gel-directory-run.rkt examples/gel-directory.aloe
```

From a home directory, confirm dot names are initially absent, press `.` to
show them, press `.` again to hide them, then press `q`. Ordinary names should
occupy the first page while hidden names are off.

Append only this entry to `CHECKPOINTS.md`:

```text
## 116. [Gel Directory hidden names](docs/checkpoints/0116-gel-directory-hidden.md)

- Live Directory menus hide leading-dot names before the 24-row cap by
  default; idle `.` persistently toggles visibility and its state-dependent
  command line. Non-Directory and pending `.` remain no-ops.
```

Run:

```sh
raco test tests/checkpoint-116.rkt
raco test tests/*.rkt
git diff --check
```

The checkpoint is complete when the filtered and all-values Directory menus,
persistent toggle, exact command text, and unchanged surrounding Gel behavior
are green. Stop for review without committing and without starting checkpoint
117.

## Explicit non-goals

- No paging, search, armed window, multi-column UI, or options object/menu.
- No home/root jump, color, visible stack history, file content, refresh,
  workspace, process, Git, shell, GelFS, hook, plugin, pane, or keymap work.
- No change to host `names`, disk objects, String messages/library, item-key
  alphabet, TOS presentation, capability injection, or runners.
- No Aloe evaluator, checker, parser, reflection, syntax, or inference change.
