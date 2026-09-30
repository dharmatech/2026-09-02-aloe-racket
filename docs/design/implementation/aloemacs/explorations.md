# aloemacs explorations

**Status.** High-level discussion record. Not a charter, spec, or
checkpoint. The human picks one increment; a later conversation
writes that increment's charter. Child conversations do not start
the next band on their own.

Spoken **aloe macs**. Aim: a **solid, idiomatic, scalable core**
so later features are programs on that core, not more branches in
`handle-key`. Chez Emacs, Legmacs, and GNU Emacs are seam
catalogs (keys, objects, layering). This program may diverge.
Directory browsers, language modes, notes, and org-like outline
are **extensions**. They are not hardcoded into the kernel of the
editor.

Process: [`docs/workflow.md`](../../../workflow.md). Map:
[`README.md`](README.md). Discussion assignment:
[`discussion.md`](discussion.md).

---

## Already built

The one-buffer machine: visit a path, edit, scroll, save, undo,
quit, echo row. Text zipper, stored viewport, snapshot undo,
linear load/save, safe control display. Idiom cleanups on Text/Int. Scale charter
withdrawn.

| Band | What | State |
|---|---|---|
| Core | Text, Term, Loop, File, Index, Viewport, Undo, Echo | Implemented |
| Language | `string-load-save` (`split-lines`, `joined-with`) | Implemented |
| Idiom | line-length, int-min, viewport-top, next-lines, visited-unchanged | Implemented |
| Display | safe cells (text rows and echo label) | Implemented |

---

## Band 0 — completed (display truth)

**Safe cells.** Implemented at [`safe-cells/`](safe-cells/).
A control (code below 32, and DEL) paints as one space, in the
clipped text and in the echo label. Character columns stay
character columns.

A Tab key, and a mode width that paints one tab out to a stop,
are Band 4. This band does not choose a stop width.

---

## Band 1 — finish the one-buffer editor

Still one buffer, still allowed to extend `handle-key`. These
make the core *usable* for sketching and reading. They are
deliberately small. They are not windows, modes, or M-x.

Recommended order after safe cells:

| # | Exploration | Why this soon | First consumer |
|---|---|---|---|
| 1 | **Search** (incremental, reuse the echo row) | **Chartered.** [`search/charter.md`](search/charter.md). Ctrl-F, query on the echo row, linear `String.find`. Ctrl-S stays save | A no-TTY test: type, search, point moves, wrap or fail is explicit |
| 2 | **Mark, region, kill/yank** | Daily edit; kill-ring is an Aloe list of strings, not an OS clipboard yet | Kill a span, yank, undo restores text and point |
| 3 | **Motion pack** | C-a / C-e, page up/down, beginning/end of buffer. Too thin as its own charter; attach to search or kill, or a standalone 000 | Existing frame goldens plus point |

Page-up/down alone is not a layer. Paste from the host clipboard
waits for a later capability; the kill-ring can be internal
first.

After this band the cond in `handle-key` will be crowded. That
crowding is the signal for Band 2, not a reason to skip Band 1.

---

## Band 2 — the extension core (do this before “Emacs product”)

This is the **idiomatic hinge**. Without it, every later feature
hardcodes another `cond` arm. With it, dired-like browsers,
language modes, and M-x are libraries.

| # | Exploration | Why it is core | Depends on |
|---|---|---|---|
| 4 | **Commands as objects** | A command is a named value `(Editor → Editor)` (or session), not a clause. M-x and keymaps have something to point at | Band 1 crowding, or C-x / M-x as the first extra binding |
| 5 | **Keymap as data** | Nested maps, prefix keys, self-insert as a default. First consumer: the keys we already have, plus one prefix (`C-x C-s` is enough) | Commands |
| 6 | **Buffer as an object** | Named Text + point + undo + optional path. Session holds a list and a current buffer. Switch and kill-buffer in one window | File session, commands |
| 7 | **Minibuffer** | A prompt that is a small editable buffer (or a window onto one), not a second ad-hoc string field. Completing-read can stay tiny | Buffer, echo, keymap |
| 8 | **Find-file / save-as / switch-buffer as commands** | These are the first *uses* of the minibuffer. They are not a directory UI | Minibuffer, Fs |

GNU-like keys (`C-x C-f`, `C-x C-s`, `C-x b`, `M-x`) are welcome
here as bindings of those commands. The implementation stays
data.

---

## Band 3 — frame layout

Emacs-like splitting. **After** buffers exist, so a window is a
view of a buffer, not a second copy of the editor class.

| # | Exploration | Note |
|---|---|---|
| 9 | **Windows** (split right, split below, delete, other-window) | GNU Emacs layout-smash is the defect to avoid. Include **window lock** (a window commands must not resize or delete) in the same design, even if lock is a later checkpoint |
| 10 | **Mode line** | Optional. Echo can stay the message row; a per-window line can show buffer name and mode once modes exist |

---

## Band 4 — reading code (display attributes)

Highlighting and folding need a display model richer than “each
character is one cell of the current line string.” Chez Emacs
spans are the seam to read; do not port `text.sls`.

| # | Exploration | Note |
|---|---|---|
| 11 | **Faces / attributes on spans** | Color or reverse as data on a half-open span. Frame consults attributes. This is the algebra; highlighting is a client |
| 12 | **Syntax highlighting** | Start lexical (the VS Code TextMate grammar is a catalog, not this implementation). Semantic tokens wait for in-editor analysis or LSP |
| 13 | **Language modes as libraries** | A mode is a keymap + highlighter and, later, indent and tab display. Scheme, C, Python, Aloe are packages. The editor does not `cond` on filename in the kernel. The mode owns the stop width. A spaces language inserts spaces to the next stop. Make and Go insert one tab byte, and that width paints the tab as blank cells out to the next stop. The buffer keeps the one tab. Until a mode supplies a width, safe cells paints it as one space |
| 14 | **Folding** | A fold is an overlay or a derived view of Text, not a second buffer representation. Needed for large-file browsing and for a later outline mode |

Unicode `wcwidth` / grapheme clusters sit in this band or just
after safe cells if real files demand it. It reopens “ASCII, one
cell per character.” Keep it a named exploration, not a silent
tweak inside highlighting.

---

## Band 5 — applications (extensions)

These should load like programs. If the design would require
editing `editor.aloe` for each new one, Band 2 is unfinished.

| # | Exploration | Note |
|---|---|---|
| 15 | **Directory browser** | One file-browser, not *the* file-browser. Dired is a GNU catalog. Other browsers are allowed |
| 16 | **Simple outline / org** | Headings, fold, maybe TODO. A subset, not Org-mode |
| 17 | **Notes mode** | May share outline, or be a thinner mode. Decide when Band 4 exists |

---

## Band 6 — later (reopen a lock or add a host)

| # | Exploration | Why later |
|---|---|---|
| 18 | **LSP inside aloemacs** | Needs a process/network capability, overlays, and a minibuffer for UI. VS Code LSP in `docs/editor/` already edits Aloe *from the outside*; that map stays separate until this editor hosts a client |
| 19 | **Live eval / running image** | Hallmark of Emacs. Reopens the **static first** lock (no Mirror, no live `eval` in the editor). Park until the core and modes are boring. Then a dedicated charter |
| 20 | **Host clipboard, mouse, PTY, daemon** | Extra capabilities. Kill-ring does not require them |

---

## Language residue (not editor features)

Leave these until a slice is blocked by them.

- Session send-forwarding / delegation
- Constructor arity on the editor
- Class methods and class-side `(String join …)`
- Vector or mutation for speed (Index already answered motion)

---

## Lean after safe cells

1. **Search** (Band 1) — chartered at
   [`search/charter.md`](search/charter.md). Echo shows the
   query. Still one buffer.
2. **Mark + kill/yank** (Band 1).
3. **Commands + keymap as data** (Band 2), with existing keys as
   the first consumer and `C-x C-s` as the first prefix.
4. **Buffer**, then **minibuffer**, then find-file / switch-buffer.
5. **Windows + lock**.
6. **Faces**, then highlighting, then modes as libraries.
7. Folding, then outline/notes, then a directory browser.
8. LSP, then live eval, each with its own charter.

The human may swap search and kill, or attach the motion pack to
whichever Band 1 charter comes first. The hinge that should not
slide later is Band 2 before windows, modes, org, dired, or M-x
as a hardcoded dispatcher.
