# aloemacs

Spoken **aloe macs**. A terminal editor written in Aloe. Local work.
Not Aloe language law. Not Gel. Not the global checkpoint spine
(`docs/checkpoints/`, `CHECKPOINTS.md`). Not
[`docs/editor/`](../../../editor/README.md) (that map is edit-Aloe
from the outside).

Identity is `(project, number)` or `(aloemacs-layer, number)`.
Spoken name is **aloemacs-text 000**. Process:
[`docs/workflow.md`](../../../workflow.md).

## Why this program

Grow Aloe from an application. Borrow Legmacs's machine (immutable
editor state, `handle-key` returns a new editor, the frame is a
`String`, Term only at the runner) and Chez Emacs's text algebra
(`Text`, positions, half-open spans, replace a span). Do not port
either editor.

## Paths

| What | Where |
|---|---|
| This map, charters, specs, checkpoints | `docs/design/implementation/aloemacs/` |
| High-level discussion continuation | [`discussion.md`](discussion.md) |
| Upcoming explorations (ranked) | [`explorations.md`](explorations.md) |
| Hands-on tour | [`demo.md`](demo.md) |
| Editor program | `examples/aloemacs/` (promote to `apps/aloemacs/` only if it outgrows examples) |
| General libraries the editor forces | `lib/` (`string.aloe`, later `text.aloe`) |
| Term host and runner | `host/racket/` |
| Tests | `tests/aloemacs/` |

No top-level `aloemacs/` directory.

## Process

Each layer is either a **charter** (open questions; a designer writes
`spec.md` and stops) or a **brief** (locked enough to slice). Do not
design or implement a later layer in an earlier layer's conversation.

## Locks (do not reopen in child conversations)

- Evaluation is send. No mutation, no macros, no inheritance.
- Nested edit is rebuild. Commands are `(Editor → Editor)` once a
  loop exists; they are not `set-box!`.
- Static first. No `Mirror`, no live `eval`, no hot reload, no
  config-as-running-image.
- ASCII, one cell per character, until a later layer says otherwise.
  Safe cells keeps this lock: a control paints as one space.
  Mode buttons is that later layer for three code points, each one
  cell: ↕, ↔, and ×.
- Host stays a typed injected capability. ANSI sequences are Aloe
  strings, not new Term methods, unless a slice proves otherwise.
- Do not mix these checkpoints into `CHECKPOINTS.md` unless the
  human promotes a kernel or host lift onto the language spine
  after review.

## Order

| # | Layer | Path | This conversation | Depends on |
|---|---|---|---|---|
| 1 | Text | [`text/`](text/) | **Implemented.** Spec and aloemacs-text 000–003. | String messages the tests force |
| 2 | Term | [`term/`](term/) | **Implemented.** Spec and aloemacs-term 000. | Existing Term capability |
| 3 | Loop | [`loop/`](loop/) | **Implemented.** Spec and aloemacs-loop 000–003. | 1, 2 |
| 4 | File | [`file/`](file/) | **Implemented.** Spec and aloemacs-file 000–003. | 3, existing Fs |
| 5 | Index | [`index/`](index/) | **Implemented.** Spec and aloemacs-index 000–002. | 3–4 (editor + `Text` / File strings) |
| 6 | Viewport | [`viewport/`](viewport/) | **Implemented.** Spec and aloemacs-viewport 000–002. | 5 (stored origin; reopen Loop §6) |
| 7 | Undo | [`undo/`](undo/) | **Implemented.** Spec and aloemacs-undo 000. | 3–6 (edits + zipper sharing) |
| 8 | Echo | [`echo/`](echo/) | **Implemented.** Spec and aloemacs-echo 000–001. | 4, 6 (path + text rectangle) |
| 9 | Safe cells | [`safe-cells/`](safe-cells/) | **Implemented.** Spec and aloemacs-safe-cells 000. | 3, 8 (frame bytes + echo label) |
| 10 | Search | [`search/`](search/) | **Implemented.** aloemacs-search 000–001. | 4, 8, 9 (session keys, echo row, safe cells) |
| 11 | Kill | [`kill/`](kill/) | **Implemented.** aloemacs-kill 000–002. | 7, 10 (undo frames, session keys) |
| 12 | Motion | [`motion/`](motion/) | **Implemented.** aloemacs-motion 000. | 6, 11 (fitted rows, editor keys) |
| 13 | Keymap | [`keymap/`](keymap/) | **Implemented and accepted.** aloemacs-keymap 000–001. | 4, 8, 10–12 (session dispatch, echo, search, kill, motion) |
| 14 | Buffer | [`buffer/`](buffer/) | **Implemented and accepted.** aloemacs-buffer 000–001. | 4, 13 (file session, commands) |
| 15 | Minibuffer | [`minibuffer/`](minibuffer/) | **Implemented and accepted.** aloemacs-minibuffer 000–001. | 8–10, 13–14 (echo row, safe cells, search, keymap, buffer) |
| 16 | Prompt commands | [`prompt-commands/`](prompt-commands/) | **Implemented and accepted.** aloemacs-prompt-commands 000–002. | 4, 13–15 (Fs, keymap, buffer, minibuffer) |
| 17 | Windows | [`windows/`](windows/) | **Implemented.** aloemacs-windows 000–006. Final human review remains. | 6, 8, 13–16 (viewport, echo, keymap, buffer, minibuffer, prompt commands) |
| 18 | Mode line | [`mode-line/`](mode-line/) | **Implemented.** aloemacs-mode-line 000–001. Final human review remains. | 8, 14, 17 (echo, buffer name, windows) |
| 19 | Completion | [`completion/`](completion/) | **Spec accepted.** aloemacs-completion 000 is ready to implement; 001 waits for review of 000. | 16–18 (prompt commands, windows, mode line) |
| 20 | Completion page | [`completion-page/`](completion-page/) | **Charter.** Designer writes `spec.md`. | 19 (painted completion list) |
| 21 | Window bars | [`window-bars/`](window-bars/) | **Implemented.** aloemacs-window-bars 000–001. Final human review remains. | 17, 18 (windows, mode line) |
| 22 | Window point | [`window-point/`](window-point/) | **Implemented and accepted.** aloemacs-window-point 000. | 17 (windows), window-pictures 000 |
| 23 | Mouse | [`mouse/`](mouse/) | **Implemented and accepted.** aloemacs-mouse 000, the whole series. Do not issue 001. | 2, 17, 22 (Term, windows, window point) |
| 24 | Mode buttons | [`mode-buttons/`](mode-buttons/) | **Implemented and accepted.** aloemacs-mode-buttons 000–001, the whole series. Do not issue 002. | 17, 18, 23 (windows, mode line, mouse) |
| 25 | Split drag | [`split-drag/`](split-drag/) | **In progress.** Spec accepted for checkpoint planning. aloemacs-split-drag 000, 001, and 002 of four are committed (bf1d1e8, ad62bf5, 80e0fd2); 003 is next. | 17, 21, 23, 24 (windows, window bars, mouse, mode buttons) |

The first-product ladder is Text through File. Index, Viewport,
and Undo are follow-ons. Echo is implemented. Faster
`split-lines` / `to-string` is completed as a **language-library**
series ([`../string-load-save/`](../string-load-save/)).
**Safe cells** is implemented at [`safe-cells/`](safe-cells/).
**Search** is implemented at [`search/`](search/).
**Kill** is implemented at [`kill/`](kill/). aloemacs-kill 000–002.
**Motion** is implemented at [`motion/`](motion/). aloemacs-motion 000.
**Keymap** is implemented and accepted at [`keymap/`](keymap/).
aloemacs-keymap 000–001 uses session `execute-command` and adds `C-x C-s`.
**Buffer** is implemented and accepted at [`buffer/`](buffer/).
aloemacs-buffer 000–001. **Minibuffer** is implemented and accepted at
[`minibuffer/`](minibuffer/), aloemacs-minibuffer 000–001.
**Prompt commands** are implemented and accepted at
[`prompt-commands/`](prompt-commands/), aloemacs-prompt-commands
000–002. **Windows** is implemented at [`windows/`](windows/),
aloemacs-windows 000–006: buffer identity, window state, layout
and rendering, both splits, delete and other-window, and lock.
The returned `000-split.md` stays historical. Final human review
remains. **Mode line** is implemented at [`mode-line/`](mode-line/),
aloemacs-mode-line 000–001. A tall window's last row shows that
window's buffer name. The echo row stays the message row. A leaf
shorter than two rows keeps today's text frame. Final human review
remains. **Idle echo** is implemented at
[`idle-echo/`](idle-echo/), aloemacs-idle-echo 000. When the
selected window paints a mode line, an idle echo row is blank. A
selected window with no mode line still shows the name there.
Save, search, and prompt messages stay. **Window pictures** is implemented at
[`window-pictures/`](window-pictures/), aloemacs-window-pictures 000.
A multi-window frame reuses a leaf's recorded rows when that leaf's
inputs are unchanged. One window still uses the editor frame. **Completion** has an accepted spec at
[`completion/`](completion/). Tab completes find-file and save-as;
recursive scans belong to the nongeneric `AloemacsCompletionScan`,
while Fs queries and results stay on `(AloemacsSession H)`.
aloemacs-completion 000 is ready to implement. Prepared-list painting
waits for 001, after human review of 000. This series does not replace
idle-echo. **Completion page** is chartered at
[`completion-page/`](completion-page/). It pages the list completion
paints. The designer writes `spec.md`. **Window bars** is implemented at
[`window-bars/`](window-bars/), aloemacs-window-bars 000–001. The
mode line is the horizontal edge of a window. A Below split spends no
dash-rule row. The selected mode line is a lighter bar and the others
are darker. Final human review remains. **Window point** is
implemented and accepted at
[`window-point/`](window-point/), aloemacs-window-point 000. Each
window showing a buffer keeps its own cursor. `C-x o` restores that
cursor and that window's origin before the fit. An edit leaves the
other windows on their stored line and column. A window that leaves a
buffer and returns takes the buffer's current cursor. Do not issue
001. **Mouse** is implemented and accepted at [`mouse/`](mouse/),
aloemacs-mouse 000. A press and a release reach Aloe on the read the
editor already blocks on. A left press in a window's text selects
that window and places its point. Do not issue 001. Paste, the host
clipboard, PTY, and daemon stay outside this series. **Mode buttons**
is implemented and accepted at [`mode-buttons/`](mode-buttons/),
aloemacs-mode-buttons 000–001. A mode line at
least seven columns wide ends with ↕, ↔, and ×. A left press on
one selects that window and sends the split or delete that window
already has. The hand check passed. Do not issue 002. **Alternate screen** is
implemented at [`alternate-screen/`](alternate-screen/), standalone
aloemacs-alternate-screen 000. The runner enters the terminal's
alternate screen before the first frame and leaves it at exit, so a
VTE scrollbar stays hidden and the shell comes back unchanged. The
hand check passed. Do not issue 001. **Split drag** is in progress at
[`split-drag/`](split-drag/). A split remembers two weights. A left
drag on a vertical bar, or on the mode line between an upper and a
lower window, rewrites them. A fresh split stays today's even cut. A
terminal resize keeps the weights. The TTY entry asks for motion
while a button is held. The spec is accepted for checkpoint planning.
aloemacs-split-drag 000, the weights and the division, 001, the
motion and the field, and 002, the bar, are committed; 003, the mode
line, is next. Ranked later
work lives in
[`explorations.md`](explorations.md).
The Scale charter stays withdrawn. The running program remains
`examples/aloemacs/` plus `host/racket/aloemacs-run.rkt`.

## Related language work

Visit and save use the linear String sends from the completed series beside
this map.

| Identity | Path | This conversation |
|---|---|---|
| string-load-save | [`../string-load-save/`](../string-load-save/) | **Implemented and accepted.** Checkpoints 000–001. |

## Idiom cleanups

Locked one-slice cleanups. Each folder is a **standalone
checkpoint** (no charter, no spec, no manager) unless it grows.

| Identity | Path | This conversation |
|---|---|---|
| line-length | [`line-length/`](line-length/) | **Implemented.** aloemacs-line-length 000 |
| int-min | [`int-min/`](int-min/) | **Implemented.** aloemacs-int-min 000 |
| viewport-top | [`viewport-top/`](viewport-top/) | **Implemented.** aloemacs-viewport-top 000 |
| next-lines | [`next-lines/`](next-lines/) | **Implemented.** aloemacs-next-lines 000 |
| visited-unchanged | [`visited-unchanged/`](visited-unchanged/) | **Implemented.** aloemacs-visited-unchanged 000 |
| safe-cell-scan | [`safe-cell-scan/`](safe-cell-scan/) | **Implemented.** aloemacs-safe-cell-scan 000 |
| safe-cell-controls | [`safe-cell-controls/`](safe-cell-controls/) | **Implemented.** aloemacs-safe-cell-controls 000 |
| runner-check | [`runner-check/`](runner-check/) | **Implemented.** aloemacs-runner-check 000 |

## Follow-on

Locked display change. A standalone checkpoint, not a new layer.

| Identity | Path | This conversation |
|---|---|---|
| idle-echo | [`idle-echo/`](idle-echo/) | **Implemented.** aloemacs-idle-echo 000 |
| alternate-screen | [`alternate-screen/`](alternate-screen/) | **Implemented.** aloemacs-alternate-screen 000 |

## Performance

Locked frame-cost repair. A standalone checkpoint, not a new layer.

| Identity | Path | This conversation |
|---|---|---|
| window-pictures | [`window-pictures/`](window-pictures/) | **Implemented.** aloemacs-window-pictures 000 |

## Not in this map

Easy to smuggle in. They are not.

- A buffer menu and modes
- Paste, PTY, VT emulator, daemon, multi-head
- Unicode clusters, `wcwidth`, grapheme width
- `M-x` eval, Gel's `Mirror`, hot reload
- A Chez Emacs or Legmacs source port
- Global checkpoint numbers 116, 118, …
- LSP / VS Code (`docs/editor/`)

## First consumer of each layer

| Layer | Consumer that is not a running editor |
|---|---|
| Text | Unit tests: insert, delete, newline, no TTY |
| Term | Tests and a host double; optional one-shot write of a frame |
| Loop | One-buffer insert / move / quit, full redraw |
| File | Load and save through existing Fs |
| Index | No-TTY Down + frame at the start **and** end of a many-line fixture |
| Viewport | Down to last screen row, then Up: cursor row decreases, `top` holds |
| Undo | Insert/newline/backspace then undo restores prior text and point |
| Echo | Frame shows untitled or path; save success vs failure |
| Safe cells | No-TTY frame: ESC, tab, CR, and DEL in text and in the echo label display as spaces; save writes the original bytes |
| Search | No-TTY: Ctrl-F, type a query, point moves; wrap and failure show on the echo; Escape restores the previous echo and does not quit |
| Kill | No-TTY: set a mark, move, kill; the ring holds the string; undo restores text and point; yank inserts it again. Kill-line with no mark. Yank on an empty ring leaves the text alone |
| Motion | No-TTY: line start and end, page-down after a fit, buffer start and end. Undo history stays |
| Keymap | No-TTY: the existing idle keys still insert, move, save, search, kill, and quit. `C-x C-s` saves. An unbound `C-x` second key is consumed and leaves the buffer unchanged. A plain `x` still inserts |
| Buffer | No-TTY: two buffers, switch shows the other text and that buffer's path or `untitled`. Kill leaves a current buffer. Save writes the current path. Undo, mark, and scroll survive a round trip. Existing keys still behave on the current buffer |
| Minibuffer | No-TTY: start a prompt, type, submit, and read the string back. Cancel leaves the buffer and the previous submission. While the prompt is active the cursor sits on the echo row; when it ends, the cursor returns to the text. The current buffer's text, point, undo, path, and name stay |
| Prompt commands | No-TTY: `C-x C-f` opens a path and leaves the previous buffer in the zipper. `C-x C-w` writes the current text and binds the path. `C-x b` selects a buffer by its exact name. A refused path, a missed name, and Escape leave the buffers as they were |
| Windows | No-TTY: `C-x 2` and `C-x 3` show two views of the current buffer. `C-x o` moves between views. `C-x 0` deletes the selected view. `C-x l` locks a view so a later split or delete leaves it in place. One view still frames as before |
| Mode line | No-TTY: a tall window's last text row shows that window's buffer name. The echo row still shows the path, `untitled`, or `saved:` / `failed:`. A one-text-row window stays today's frame. Two tall views show two names |
| Window pictures | No-TTY: four columns of one buffer paint the same bytes after their leaf rows are recorded. A later Down still paints those bytes. The recorded paint stays under the key-repeat interval at the first screen and deep in the file |
| Window bars | No-TTY: a tall one-view frame paints the lighter bar on the name row and leaves the echo row outside it. Two tall views stacked have no dash-rule row between them. The selected bar is lighter and the other is darker. A right split still has its vertical bar |
| Window point | No-TTY: four views of one long buffer. End of buffer in the first, then other-window: the next view stays at its former place and its cursor is the cursor it stored. The first view still has the end. An insertion above another view leaves that view's line and column unchanged |
| Mouse | No-TTY: a left press in another window's text selects that window and places its point. The window left behind keeps its point. A press on the mode line, the echo row, or a vertical bar leaves the point. A release leaves the point |
| Mode buttons | No-TTY: a mode line at least 7 columns wide ends with ` ↕ ↔ ×`, and the name stops before that group. A left press on ↕, ↔, or × matches selecting that window and then `C-x 2`, `C-x 3`, or `C-x 0`. A press on the name, and a release on a button, leave the session as it was |
| Split drag | No-TTY: `C-x 3`, press the bar, move, release: both rectangles read the new cut and the weights read the cell counts, and a later `ensure-visible` at another width scales them. The same tree built with weights `1 1` has today's rectangles. A press on a handle beside a locked window, and a move with nothing armed, leave the session as it was |
| Completion | No-TTY: `C-x C-f` opens in the current directory. Tab finishes a unique name, adds `/` on a directory, and lists the fork above the prompt when it cannot extend. Return still opens the typed path |

If a proposed slice has no consumer besides "the editor will need
this," it is too early.
