# aloemacs explorations

**Status.** High-level discussion record. Not a charter, spec, or
checkpoint. The human picks one increment; a later conversation
writes that increment's charter. Child conversations do not start
the next band on their own.

Search is implemented (aloemacs-search 000–001). Mark, region,
kill, and yank is implemented (aloemacs-kill 000–002). The motion
pack is implemented (aloemacs-motion 000). Commands and keymap are
implemented and accepted (aloemacs-keymap 000–001) at [`keymap/`](keymap/).
The buffer series is implemented and accepted (aloemacs-buffer 000–001)
at [`buffer/`](buffer/). The minibuffer series is implemented and
accepted (aloemacs-minibuffer 000–001) at [`minibuffer/`](minibuffer/).
The prompt-command series is implemented and accepted
(aloemacs-prompt-commands 000–002) at
[`prompt-commands/`](prompt-commands/). The windows series is
implemented (aloemacs-windows 000–006) at [`windows/`](windows/).
Final human review of that series remains. The mode-line series is
implemented (aloemacs-mode-line 000–001) at
[`mode-line/`](mode-line/). Final human review of that series
remains. The idle-echo follow-on is ready to implement at
[`idle-echo/`](idle-echo/), aloemacs-idle-echo 000. The multi-window frame repair is implemented at
[`window-pictures/`](window-pictures/), aloemacs-window-pictures 000.
Path completion is back with the designer at
[`completion/`](completion/). The recursive scans move off
`(AloemacsSession H)`. aloemacs-completion 000 is not ready to
implement. That revision does not replace idle-echo. Paging the
painted list is chartered at [`completion-page/`](completion-page/).
The designer writes that spec. It is not a completion checkpoint.
Window bars are chartered at [`window-bars/`](window-bars/). The
designer writes that spec. The mode line becomes the horizontal
edge, with a lighter bar on the selected window. Window point is
chartered at [`window-point/`](window-point/). The designer writes
that spec. Each window showing a buffer keeps its own cursor, and
`C-x o` restores it before the fit.

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

Visit a path, edit, scroll, save, undo, quit, echo row,
incremental search, mark, kill, and yank. The session holds a
zipper of buffers and a tree of windows. A window is a view of a
buffer: split below, split right, other-window, delete, and lock.
A tall window's last row shows that window's buffer name. The
echo row stays the message row. Switch and kill-buffer are sends. Text zipper, stored viewport,
snapshot undo, linear load/save, safe control display. Idiom
cleanups on Text and Int. Scale charter withdrawn.

| Band | What | State |
|---|---|---|
| Core | Text, Term, Loop, File, Index, Viewport, Undo, Echo | Implemented |
| Language | `string-load-save` (`split-lines`, `joined-with`) | Implemented |
| Idiom | line-length, int-min, viewport-top, next-lines, visited-unchanged | Implemented |
| Idiom | safe-cell-scan ([`safe-cell-scan/`](safe-cell-scan/)) | Implemented. Standalone 000 |
| Idiom | safe-cell-controls ([`safe-cell-controls/`](safe-cell-controls/)) | Implemented. Standalone 000 |
| Idiom | runner-check ([`runner-check/`](runner-check/)) | Implemented. Standalone 000 |
| Display | safe cells (text rows and echo label) | Implemented |
| Search | Ctrl-F, query on the echo row ([`search/`](search/)) | Implemented. aloemacs-search 000–001 |
| Kill | Mark, kill, kill-line, yank ([`kill/`](kill/)) | Implemented. aloemacs-kill 000–002 |

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

Search, kill, and the motion pack are implemented. The Band 2
keymap is implemented and accepted at [`keymap/`](keymap/).

| # | Exploration | Why this soon | First consumer |
|---|---|---|---|
| 1 | **Search** (incremental, reuse the echo row) | **Implemented.** aloemacs-search 000–001 at [`search/`](search/). Ctrl-F, query on the echo row, linear `String.find`. Ctrl-S stays save | A no-TTY test: type, search, point moves, wrap or fail is explicit |
| 2 | **Mark, region, kill/yank** | **Implemented.** aloemacs-kill 000–002 at [`kill/`](kill/). Mark, kill the span, kill-line, yank. The ring is an Aloe list of strings. The host clipboard stays later | Kill a span, yank, undo restores text and point |
| 3 | **Motion pack** | **Implemented.** aloemacs-motion 000 at [`motion/`](motion/). Ctrl-A / Ctrl-E, Home / End, Page Up / Page Down, Ctrl-Home / Ctrl-End | Existing frame goldens plus point |

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
| 4 | **Commands as objects** | **Implemented and accepted** with item 5 at [`keymap/`](keymap/), aloemacs-keymap 000–001. A command is a named value; the session executes it. M-x stays later | Band 1 crowding |
| 5 | **Keymap as data** | **Implemented and accepted.** Immutable maps dispatch existing keys and one prefix: `C-x C-s`. Pending misses cancel and consume the key | Commands |
| 6 | **Buffer as an object** | **Implemented and accepted** at [`buffer/`](buffer/), aloemacs-buffer 000–001. A buffer holds the editor and optional path; the session holds a nonempty zipper. Addition, switch, and kill-buffer are checked sends in one window, with no new key binding | File session, commands |
| 7 | **Minibuffer** | **Implemented and accepted** at [`minibuffer/`](minibuffer/), aloemacs-minibuffer 000–001. The prompt is its own small editor on the echo row, outside the buffer zipper. A test types, submits or cancels, and reads the string. Completion stays a later series | Buffer, echo, keymap |
| 8 | **Find-file / save-as / switch-buffer as commands** | **Implemented and accepted** at [`prompt-commands/`](prompt-commands/), aloemacs-prompt-commands 000–002. Three commands start the existing prompt. Return runs the command. Escape runs nothing. Not a directory UI | Minibuffer, Fs |

GNU-like keys (`C-x C-f`, `C-x C-s`, `C-x b`, `M-x`) are welcome
here as bindings of those commands. The implementation stays
data. `C-x C-s` is implemented by the keymap series.
`C-x C-f`, `C-x C-w`, and `C-x b` are implemented by the
prompt-command series. `M-x` stays later.

---

## Band 3 — frame layout

Emacs-like splitting. **After** buffers exist, so a window is a
view of a buffer, not a second copy of the editor class.

| # | Exploration | Note |
|---|---|---|
| 9 | **Windows** (split right, split below, delete, other-window) | **Implemented.** aloemacs-windows 000–006 at [`windows/`](windows/). A window is a view of a buffer. Split below (`C-x 2`), split right (`C-x 3`), other-window (`C-x o`), delete (`C-x 0`), and lock (`C-x l`). Final human review remains. The mode line is the separate item 10. **Window point** is chartered at [`window-point/`](window-point/): each window showing a buffer keeps its own cursor, and `C-x o` restores that cursor before the fit. The designer writes `spec.md` |
| 10 | **Mode line** | **Implemented.** aloemacs-mode-line 000–001 at [`mode-line/`](mode-line/). A per-window row shows the buffer name on a dash fill. The echo row stays the message row. A leaf shorter than two rows keeps today's text frame. Final human review remains. A mode name waits until language modes exist. **Window bars** is chartered at [`window-bars/`](window-bars/): that row is the horizontal edge, the Below dash rule goes away, and the selected bar is lighter than the others. The designer writes `spec.md`. The vertical-bar character stays |

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

## Lean from here

1. **Search** (Band 1) — implemented at [`search/`](search/).
   aloemacs-search 000–001. Echo shows the query. Still one
   buffer.
2. **Mark + kill/yank** (Band 1) — implemented at
   [`kill/`](kill/). aloemacs-kill 000–002.
3. **Commands + keymap as data** (Band 2) — implemented and accepted at
   [`keymap/`](keymap/), aloemacs-keymap 000–001. Existing keys are the
   first consumer, and `C-x C-s` is the first prefix.
4. **Buffer** — implemented and accepted at [`buffer/`](buffer/),
   aloemacs-buffer 000–001. **Minibuffer** — implemented and accepted at
   [`minibuffer/`](minibuffer/), aloemacs-minibuffer 000–001.
   **Find-file / save-as / named switch-buffer** — implemented and
   accepted at [`prompt-commands/`](prompt-commands/),
   aloemacs-prompt-commands 000–002.
5. **Windows + lock** — implemented at [`windows/`](windows/),
   aloemacs-windows 000–006. A window is a view of a buffer.
   Final human review remains. **Window point** is chartered at
   [`window-point/`](window-point/). The designer writes `spec.md`.
6. **Mode line** — implemented at [`mode-line/`](mode-line/),
   aloemacs-mode-line 000–001. A per-window row shows the buffer
   name. The echo row stays the message row. Final human review
   remains. The idle name leaves that row in the standalone
   checkpoint [`idle-echo/`](idle-echo/), aloemacs-idle-echo 000,
   which is ready to implement. **Window bars** is chartered at
   [`window-bars/`](window-bars/). The designer writes `spec.md`.
7. **Path completion** — back with the designer at
   [`completion/`](completion/). Tab completes find-file and
   save-as. The recursive scans move off `(AloemacsSession H)`.
   aloemacs-completion 000 is not ready to implement. Paging the
   painted list is chartered at
   [`completion-page/`](completion-page/). Faces stay after that.
8. **Faces**, then highlighting, then modes as libraries.
9. Folding, then outline/notes, then a directory browser.
10. LSP, then live eval, each with its own charter.

The motion pack is implemented (aloemacs-motion 000). Band 2 is
implemented. Windows is implemented (aloemacs-windows 000–006);
final human review remains. Mode line is implemented
(aloemacs-mode-line 000–001) at [`mode-line/`](mode-line/);
final human review remains. aloemacs-idle-echo 000 at
[`idle-echo/`](idle-echo/) stays ready to implement. Path
completion is back with the designer at
[`completion/`](completion/). Paging the painted list is chartered at
[`completion-page/`](completion-page/). Faces stay after that revision. Modes, org, dired, and `M-x` stay later.
