# Gel directory surface

**Status.** First live slice implemented through checkpoint 112 on
`experiment/gel-directory-surface`. Not Aloe language law. Later work still
requires checkpoints, one at a time. All five first-progression items are now
implemented: application-supplied start values, stack back, authored value
rows, the collision-free 24-letter item-key pool, and a filesystem-capable
runner whose application starts on a live `Directory`.

`SPEC.md` remains law. Disk objects remain
[`docs/filesystem-oo-vocabulary.md`](filesystem-oo-vocabulary.md).
Gel's current Point sketch remains [`docs/gel.md`](gel.md); this
experiment may amend Gel once it has pressure.

This branch is stacked on `experiment/filesystem`. Do not merge to
`main`. Do not start from `main`. Checkpoint 107 is the last required
OO-filesystem slice; do not grow `lib/disk.aloe` unless this surface
blocks on a missing message.

## 1. Job

Put a live `Directory` on Gel's stack and navigate it from the keyboard
the way one uses `ls` and `cd`, not the way one inspects a reflected
`Point`.

North star:

```text
3  #<Directory "/home/dharmatech">
2  #<Directory ".../journal">
1  #<Directory ".../2026-09-02-aloe-racket">

a  gel/
b  lib/
c  SPEC.md

u  up
esc  back
q  quit
```

Choosing `b` pushes that live `Directory`. Choosing `c` pushes that
`File`. `u` sends `parent`. Escape pops. `q` leaves.

This is a **focused directory browser**. It is not a Git Menu workspace,
not a GelFS framework, and not a file manager clone.

## 2. Why this experiment exists

Git Menu (Python) proved a feeling: one key, visible choices, context
that lights up, directory as a place. That program is a **workspace
command palette** around process-wide `cwd`. Its home screen does not
list children; `3` opens a directory picker, `4` opens a file picker,
`1` shells out to `ls`.

Gel's thesis is different: **a stack interface on a reflective object
language**. TOS is the object. A key either sends a message or chooses
a contained value. Results are pushed. Back pops.

The Point demo is only a sketch of that thesis. Derived numbered
signature rows will not produce muscle memory, and they will not make
`(dir entries)` usable: the user would `first`/`rest` through a list.
A directory is the first object that forces:

- an authored surface (stable command keys)
- value-item rows (children you can choose)
- pop as navigation
- a start value other than `Point`

Point and MPL are cleaner toys. They will not make anyone put Gel in
the way of `ls` and `cd`. This surface will. Explore Point, Boids, and
MPL as Gel personalities after the machine has been used for something
daily.

## 3. Locked for the first slice

1. **Children on the main screen.** The listing *is* the menu. Do not
   start with command-then-picker (`c` then a directory list, `o` then
   a file list). Those can be later filters. They are not the home view.
2. **Single-key items on the current page.** One key chooses a visible
   child. No two-key addressing, no prefix chords, no avy-style labels.
3. **Command keys never become item keys.** Reserved for the first
   slice: `q` quit, Escape back, `u` up. The item-key pool is whatever
   remains after that reservation. Git Menu assigned `n`/`p` to entries
   while those keys meant next/prev; do not repeat that.
4. **Overflow is later.** Paging (`n`/`p`) and search (`/`) wait until
   a real directory is too long. Do not design two-key entry or a
   multi-column TUI in the first checkpoints.
5. **No workspace keys.** No apps, git, processes, editors, or shell
   launchers on this slice.

Also locked:

- Everyday objects come from `lib/disk.aloe` (`Disk`, `Location`,
  `Directory`, `File`, `Item`). Thin `lib/fs.aloe` stays as the other
  library. Gel must not speak both.
- `lib/disk.aloe` stays Gel-ignorant. Authored keys live in Gel, not in
  the disk vocabulary.
- Default `bin/aloe` stays capability-free. A Gel directory runner may
  inject `term` and `fs-host`. Ordinary Gel may keep injecting only
  `term`.
- Do not add `read`, `size`, `enter`, copy, `(here entries)`, or Git to
  the disk library unless a locked screen cannot be built without them.
  Selecting a live `Item` already *is* enter.

## 4. Architecture

Gel hosts ordinary Aloe objects. There is no GelFS package, no disk
module *in* Gel, and no plugin/hook/pane/extension API.

```text
Aloe     Disk / Location / Directory / File / Item
Host     fs-host (paths, names, inspect) and term (keys, lines)
Gel      stack, menu, send, choose-value, pop
Runner   injects capabilities and supplies the start value
```

When TOS is a `Directory`, Gel presents an authored surface. When TOS
is an unfamiliar object, Gel may still fall back to derived signature
rows. A `File` on TOS can use the derived menu for the first slice.

The stack is the place and the history. There is no process-wide
`chdir` inside Gel. TOS is where you are. Deeper items are how you got
there. `u` is a send (`parent`). Escape is a stack pop. Those are
different: `parent` computes a location; pop returns to the previous
object, which might not be the parent (for example after pushing a
`File`).

Pop of a one-item stack is a no-op. `q` still quits. Do not dump the
user onto an empty Gel with no directory.

Gel is not a concatenative language. Aloe evaluation stays
`(receiver selector argument ...)`. The stack is an interface to that,
not a second dispatch rule, and not a consumptive Forth data stack by
default. Deeper items remain history and available context.

## 5. Feel

Inspiration, not a feature checklist:

- **Factor / Forth** — the thing you just made sits there, ready. The
  next key operates on it. Gel is that feeling applied to Aloe, not a
  Forth.
- **HP-48G / 48GX** — objects on a visible stack, a menu that belongs
  to level 1, soft keys under the labels. The 48 is a tiny RPL Lisp
  machine. That is the spirit: live objects, menus for the current
  one, the environment feels alive.
- **Git Menu** — one-keystroke, discoverable, directory as a place.
  Keep it as a sketch of a *workspace*. Do not port its nested menu
  loops, process-wide `chdir`, or home command palette into this
  surface.

Spatial keys and mnemonic keys are different jobs:

- **Item keys** want to be spatial (soft keys under the listing). First
  visible child is always the same physical place.
- **Command keys** want to be mnemonic and stable on QWERTY: `u`, `q`,
  Escape.

Item keys use the fixed lowercase pool
`a b c d e f g h i j k l m n o p r s t v w x y z`. The pool is assigned in
that order to each listing and excludes active `q` and reserved `u`; reflected
message rows and pending input keep digits.

A few visible stack levels are closer to the 48 than printing TOS only.
Recommended for the first slice if it stays cheap; not a lock. Stack
*manipulation* (drop, swap, a stack-editing mode, `>R`/`R>`) is
deferred. A Forth return stack is rejected: Aloe already has objects
and fields. If a holding area is needed later, it should be an ordinary
object on the stack.

## 6. The Point demo is disposable

Keep Gel's *concept*. Do not treat `gel/*.aloe` as law.

Keep as the hypothesis to test:

1. One stack. TOS is the object.
2. A key either sends a message or chooses a contained value.
3. Results are pushed. Back pops.
4. Unfamiliar objects can get a derived menu.
5. Important objects can get a human-designed surface.

Fair game to replace as soon as the directory screen needs it:

- digits `1`–`9` as the only keys
- menus generated only from signature order
- hard-coded `Point` start in `host/racket/gel-run.rkt`
- no pop
- no value-item rows
- current pending-send / int-entry details if they get in the way
- rewriting `gel/menu.aloe` and `gel/loop.aloe` rather than extending
  them awkwardly

Do not take that permission to mean "rewrite Gel as Git Menu." The
Python control flow is the wrong structure.

## 7. First progression

Prove the Gel mechanics with an in-memory list if that keeps the first
checkpoints off `fs-host`. Do not turn that harness into an MPL or
Point project. As soon as value choice and pop work, put a real
`Directory` on the stack.

Suggested order, one checkpoint at a time:

1. **Implemented in checkpoint 108:** application-supplied start value. The
   runner no longer hard-codes `Point`; an Aloe application owns its start
   value. Constructing a live directory application remains deferred.
2. **Implemented in checkpoint 109:** back / pop. Escape cancels a pending
   send first; if idle, it pops while preserving a one-item floor.
3. **Implemented in checkpoint 110:** value-item rows. A List presents
   choosable values, not just `first` / `rest`.
4. **Implemented in checkpoint 111:** collision-free key policy. The exact
   24-letter pool omits `q` and `u`; item keys are rebound per listing and
   reflected and pending surfaces retain digits.
5. **Implemented in checkpoint 112:** the separate directory-aware runner
   injects `fs-host` alongside `term`; `examples/gel-directory.aloe` starts at
   the process's live current `Directory`. Gel-authored rows label and push
   immediate live children, `u` pushes a live parent, and Escape remains stack
   back.

Hand check for the live slice: from the project directory, enter
`lib/`, see `disk.aloe`, Escape back, `u` to the parent, `q` to leave.

## 8. Open on this slice

- **Resolved item-key alphabet.** Authored rows use
  `a b c d e f g h i j k l m n o p r s t v w x y z`; `q` and `u` are
  excluded, and digits remain tied to derived and pending rows. If paging
  later claims `n` or `p`, that key must first leave the item pool.
- **How many stack levels to print.** TOS-only is the current sketch.
  A few levels would make Escape intelligible. Full stack manipulation
  is out.
- **Snapshot vs live listing.** `(dir entries)` talks to the host.
  Checkpoint 112 captures immutable rows within each `GelMenus.of` call, but a
  later redraw or key step may construct the menu again. Persistent per-TOS
  snapshots and an explicit refresh command remain open.
- **Resolved exact files.** Authored Directory presentation lives in
  `gel/directory.aloe`, not `lib/`. The filesystem-capable application uses
  the separate `host/racket/gel-directory-run.rkt`; the ordinary Term-only
  runner remains unchanged.
- **`File` surface.** Derived menu is enough. No edit, no pager, no
  text reading.

Follow-up pressure is recorded from first live use (2026-09-10), not from
the original five-item progression. Ranked next, still one checkpoint at
a time, still not a workspace or GelFS framework:

1. **Implemented in checkpoint 113: TOS path text.** The live screen now
   prints `#<Directory "/home/dharmatech">` through a private Gel adapter;
   no keys or public disk messages changed, and non-disk TOS values retain
   their structural text.
2. **Hidden names.** A home directory spends the whole 24-key page on
   dotfiles; `journal/` never appears. Paging does not fix that until
   the user pages through `.cache` and friends. Hide names that start
   with `.` by default; idle `.` toggles them. String support is three
   checkpoints, not a kernel `starts-with?`:
   `docs/string-len-take-brief.md` (114: `len`, `take`,
   `define-methods String`),
   `docs/string-starts-with-library-brief.md` (115: `lib/string.aloe`),
   then `docs/gel-directory-hidden-brief.md` (116). Do not combine
   language and Gel in one checkpoint.
3. **Paging.** Needed for `/etc`, `/usr/bin`, and any listing that is
   still long after dots are hidden. If `n` / `p` become page keys they
   must leave the item pool first (see the alphabet note above). Dumb
   transcript paging, not the sliding armed window.
4. **Search `/`.** Jump in a huge listing. `/` is not in the letter
   pool, so it does not steal an item key. Do not implement before
   paging unless use shows jump-to-name hurting more than next-page.

Parked, still wanted:

- **Home / root jumps.** Useful. `~` is not an item letter and can be
  home without a submenu. Root must not fight `/` if `/` is search.
  Infrequent jumps may instead live on a small object pushed by one
  extra command key. That is TOS-as-mode, not a menu framework.
- **Options object.** A pushed object with toggle-hidden, maybe home
  and root, then Escape back. Allowed later. Do not build a general
  bottom-chrome menu system, keymap, or plugin table to get a hidden
  toggle.
- **Armed window / multi-column.** Still a redrawing TUI skin after
  paging exists.
- **Color / AS400-style TUI.** A skin over Gel events. Do not put ANSI
  in `Directory` or `lib/disk.aloe`. Pretty colors on the current TOS
  printer and 24-dotfile wall would not make it feel finished.
- **Visible stack levels.** Still wanted so Escape vs `u` is obvious.
  TOS path text first.

## 9. Non-goals and deferred

Do not build these in the first slice. They are recorded so later Gel
experiments can return here instead of replaying the brainstorm.

| Idea | Status |
|---|---|
| GelFS / gel-disk as a framework or package | Rejected. Task name only. |
| Hooks, plugins, panes, extension APIs | Rejected until a second personality is fighting the first. |
| Standalone Git Menu clone in Aloe | Rejected. |
| Expand Gel as a generic framework first (MPL, Boids, keymaps) | Rejected as the next move. |
| Command-then-picker as the home view | Deferred. Later filter, not v0. |
| Paging `n`/`p` and search `/` | Deferred until a listing overflows. |
| Two-key / prefix-tree item addressing | Deferred. |
| Armed window over a larger viewport (many names visible, only ten labeled, `n` slides the labels, screen pages only at the edge) | Deferred. Good later collection presentation. Wants a redrawing TUI, not the transcript skin. Same widget should later serve processes. |
| Multi-column drawing | Deferred. Presentation, not key grammar. Do not couple columns to prefix keys. |
| Workspace object (Git Menu home palette) | Deferred as a separate personality. The directory browser may later sit *on* a workspace; do not wrap this slice in one. |
| Process browser, then a live `top` | Strong follow-on after this surface, not part of it. |
| Git repo commands | A future `GitRepo` object, not keys on `Directory`. |
| Copy, selections, plans, chmod | After one-directory navigation feels good. |
| Editors, shells, terminal launchers | Out. |
| Stack drop/swap, stack-editing mode, Forth return stack | Out. Visible stack is enough to try. |
| HP-48 variable store/recall menus | Later: an ordinary bindings object, same collection surface. |
| Semantic color, LazyGit panels, full-screen TUI | Skins. Transcript first. |
| Stack-pattern dispatch ("URL + identity lights up login") | Rejected. Types say what is legal, not what is intended. |
| Image-wide class browser | A start value is enough. |
| Calling the app Git Menu | The name is a lie. No replacement product name yet. Working name: Gel directory surface. |

## 10. How to work

Same split as the rest of Aloe.

- This file is the design. Informal chat amends it.
- A later conversation writes **one** checkpoint at a time under
  `docs/checkpoints/`. That conversation does not implement.
- An implementer conversation implements only the approved checkpoint,
  adds tests, runs the named verification, and stops when green.
- Do not add inheritance, mutation, macros, implicit numeric
  coercions, new special forms, or a second dispatch rule.
- Do not shell out to `ls`, `find`, or `stat`.
- Do not expose Racket procedures, ports, or path objects to Aloe.

The originating brainstorm for this experiment is the 2026-09-09 Gel
directory-surface conversation. Return there after a first live screen
exists, and for later Gel experiments (processes, workspace, armed
window).
