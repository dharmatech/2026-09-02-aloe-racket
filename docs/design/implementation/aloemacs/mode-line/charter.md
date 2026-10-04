# Charter — aloemacs mode line

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **a per-window mode
line that shows the buffer name**. The series identity is
**aloemacs-mode-line**. The echo row stays the message row. A
window tall enough to spare a row paints its buffer name there.
Then **stop**. Do not write checkpoints. Do not implement.

This effort refuses a language mode, a mode name, faces, a
buffer menu, a dirty mark, a position readout, and any new key.
Those stay later or out, so this spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §6.
2. Record the locked decisions in §4. Do not reopen them.
3. Resolve the open questions in §5.
4. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-mode-line 000** under
   `docs/design/implementation/aloemacs/mode-line/checkpoints/`.
5. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the checkpoints in §4.7. A mode object, a face,
a second message row, or a new command are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../echo/`](../echo/) | The last screen row is the echo row when `rows >= 2`. The text rectangle is `rows - 1`. One `term write` paints the screen. The stored tokens are `""`, `"saved"`, and `"failed"` |
| [`../safe-cells/`](../safe-cells/) | A control paints as one space after clipping, in text rows and on the echo label |
| [`../buffer/`](../buffer/) | `(buffer name)` is `"untitled"` or `(path text)`. The session holds a nonempty zipper |
| [`../minibuffer/`](../minibuffer/) | An active prompt owns the echo row and the cursor |
| [`../windows/`](../windows/) | A window is a view of a buffer. The leaf rectangle, dividers, selected-only fit, one-view byte path, and echo rule in the accepted windows spec are implemented |

aloemacs-windows 000–006 is implemented. Final human review of
that series remains. This series reads the accepted windows spec
as geometry law and does not wait for that review. A window
defect that blocks the mode line stops this spec; the designer
reports it and does not patch the windows series from here.

**Why this layer:** several views can show several buffers, and
the only name on screen is the echo row, which search and the
prompt replace. Each tall view needs its own name. The mode
name waits until a language mode exists to supply one.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **State matches today.** Idle keys, search, quit, visit, save,
   switch, kill-buffer, find-file, save-as, select-buffer, splits,
   delete, other-window, and lock keep today's text, point, quit
   flag, mark, kill-ring, undo history, search flags, echo token,
   pending map, prompt, submission, buffer zipper, window tree,
   locks, and written file. The selected origin is whatever the
   existing fit produces for the text height in §4.4. Unselected
   origins stay until that view is fitted.
2. **A tall window shows its buffer name.** In a no-TTY frame
   whose text rectangle is at least two rows, the last row of
   that rectangle contains the current buffer's name, and the
   rows above it are buffer text. The echo row is still the last
   screen row.
3. **A short window stays text.** A leaf shorter than two rows
   paints buffer text in the whole rectangle and has no mode line.
   A terminal with one text row keeps today's frame bytes,
   including the one-row terminal with no echo row.
4. **Each view has its own line.** Two tall views show the name
   of the buffer each view displays. Two views of one buffer show
   that same name. Dividers stay dividers. The echo row stays one
   full-width row under the tree.
5. **The line is display.** It is derived when the frame is built.
   A control in the name paints as one space. The painted line is
   exactly the leaf width. The cursor stays in the text rows, or
   on the echo row while a prompt is active. It never sits on the
   mode line.

## 4. Locked decisions

### 4.1 What it is

A mode line is one display row of a leaf. It is session display,
in the same sense as a divider. `AloemacsEditor` gains no field
and no mode-line method. Its direct `frame` keeps today's bytes.
The session has no stored mode-line field. The line cannot drift
from the buffer name.

### 4.2 Where it sits

The windows leaf rectangle is unchanged. Split arithmetic, the
three-cell minimum, divider characters, junction rules, lock, and
the too-small-tree fallback stay as the accepted windows spec
wrote them.

Inside a leaf of height `h` and width `w`:

| Leaf height | Text | Mode line |
|---|---|---|
| `h >= 2` | The top `h - 1` rows, width `w` | The leaf's last row, width `w` |
| `h < 2` | The whole leaf | Absent |

The line occupies leaf cells only. A `|`, `-`, or `+` divider
stays a divider, including beside a mode line and between two
stacked views. The too-small-tree fallback uses the one-view
composer, so a fallback whose text rectangle is at least two rows
shows one mode line.

A terminal of `rows >= 2` still reserves the last screen row as
the echo row. The root text rectangle is still `rows - 1` tall.
This series adds no second screen-level row.

### 4.3 What it shows

The only variable text is `(buffer name)`: `"untitled"`, or the
stored path's text. Every tall view of that buffer shows the name
from the buffer as it is when the frame is built. Save-as, visit,
find-file, and select-buffer change the line only because they
already change which buffer a view displays or what `(buffer name)`
returns. This series adds no name update of its own.

The fill is `-`, so the row is visible beside a blank text row.
The spec spells the characters around the name (§5). There is no
mode name, major mode, minor mode, filename dispatch, or keymap
per mode. There is no dirty mark, line or column count, file
percentage, lock mark, window number, pending-key badge, or
unique-name decoration.

### 4.4 Fit, cursor, and echo

Fit the selected view with the text rectangle from §4.2, through
the existing `ensure-visible`. Page up and page down use that text
height. The windows cursor formula still addresses the text
rectangle, whose top is the leaf's top. A visible point lands in
those text rows.

Echo selection, clipping, and the windows echo rule stay. Prompt
first, then active search, then `saved:` / `failed:` / the idle
path or `untitled`. An active prompt or search still owns the echo
row and, for a prompt, the cursor. The mode line remains painted
while either is active. A one-row terminal still has no echo row.

### 4.5 One view and a split

For one leaf whose text rectangle is at least two rows, the
session frame is the text rows for the shorter height, then the
mode line, then today's echo suffix. The rows above the mode line
are the text that today's editor paints for that shorter height
at the fitted origin.

For one leaf shorter than two rows, session `frame` keeps today's
complete string.

For several leaves, compose as the accepted windows spec composes,
with each tall leaf's last row replaced by its mode line. A short
leaf is still all buffer text. Padding, safe cells, one clear, one
write, and one cursor sequence stay.

### 4.6 What this series leaves alone

`Text` gains no method. `SPEC.md` gains no row. The kernel gains
no message. List gains no index message. The runner, Term, and
`AloemacsEditor`'s eight fields stay. Window commands stay. The
echo token keeps its three values. The buffer name stays the
derived path text or `"untitled"`.

### 4.7 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-mode-line 000** | The row for a name and a width, and the one-view session frame and fit. A tall one-view frame shows the name on the last text row and today's echo under it. A short one-view frame matches today. Direct editor `frame` bytes match today. No split composition |
| **aloemacs-mode-line 001** | The same row in a constructed split. Each tall leaf shows its buffer's name. A short leaf shows text. Dividers, the cursor, the echo row, and the too-small fallback follow §4 |

000 is testable once the one-view frame matches. 001 is testable
once 000 is green. The manager writes 000 only, then stops.

If 000's golden migration would not fit one implementer
conversation, the spec splits that migration into the next number
and keeps this order: the row rule, then the one-view frame, then
split views. That split adds no behavior. If split composition is
too thin to stand alone, the spec says why and joins it to the
one-view checkpoint.

## 5. Open questions

Resolve these in the spec. Do not reopen §4.

1. **The spelling.** Where the name sits in a row of `-`, and
   which characters separate it from the fill. The result is
   exactly `width` characters before display clipping is done.
   A name that does not fit is clipped by prefix, with no
   ellipsis, and `safe-cells` runs after that clip. Give the row
   for width 1, for a name that fits, and for a name longer than
   the width. An empty width is not a painted line.
2. **The helper.** The class or session selector that builds the
   row from a name and a width. It is a pure display send. It is
   not a stored field and not an `AloemacsEditor` method.

## 6. Authority

- [`../README.md`](../README.md) — layer order; this layer is
  the mode line
- [`../explorations.md`](../explorations.md) — Band 3 item 10.
  Faces stay the following exploration
- [`../windows/spec.md`](../windows/spec.md) — leaf geometry,
  dividers, selected-only fit, one-view and multi-view
  composition, and the echo rule. §4.2–§4.5 of this charter
  supersede only the claim that a leaf's rectangle is all buffer
  text
- [`../echo/spec.md`](../echo/spec.md) — the reserved screen
  row, the three tokens, and the idle label
- [`../buffer/spec.md`](../buffer/spec.md) — `(buffer name)`,
  and what a buffer owns
- [`../safe-cells/spec.md`](../safe-cells/spec.md) — controls
  paint as one space after clipping
- [`../minibuffer/spec.md`](../minibuffer/spec.md) — the prompt
  owns the echo row and the cursor while it is active
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `(buffer name)`, session `frame`, and `ensure-visible`
- GNU Emacs mode line, Legmacs `legmacs.modeline`, and the Chez
  Emacs status line in `/home/dharmatech/src/e` — seam catalogs.
  Legmacs shows a buffer label on a per-window bar and also
  shows a mode name, modified state, position, pending keys, and
  a segment registry. Chez Emacs leads its status line with a
  window number and paints mouse buttons. This series takes the
  per-window name row and the `-` fill. It leaves the rest

`SPEC.md` remains language law. This series does not amend it.
The accepted windows spec remains the authority for the tree,
the dividers, and the echo token. This charter is the authority
for the mode line. After the human accepts `spec.md`, that file
is the design authority for the checkpoint manager and the
implementers. Where the windows spec says a leaf is all buffer
text, this charter wins.

## 7. Non-goals

- A language mode, a mode name, or a filename-based keymap
- Faces, reverse video, or a selected-window style
- A buffer menu, a dirty bit, or a modified marker
- Line, column, percentage, lock state, or a window number
- Clickable buttons, mouse actions, or a segment registry
- A stored format string or a user-arranged mode line
- A new key, a new command, or a new Term chord
- Changing split minimums, divider characters, lock, or the
  windows echo rule
- A second editor, point, or origin per view
- A kernel message, a `SPEC.md` row, a `Text` method, or a
  change to `AloemacsEditor`'s fields
- A runner change, or an edit to `host/racket/aloemacs-run.rkt`
- Mirror, mutation, or delegation
- A `CHECKPOINTS.md` entry

## 8. Handoff

- Series identity: `aloemacs-mode-line`.
- Checkpoint 000 is spoken **aloemacs-mode-line 000** and filed
  as `checkpoints/000-one-view.md`. Checkpoint 001 is spoken
  **aloemacs-mode-line 001** and filed as
  `checkpoints/001-split-views.md`. Numbers are three digits,
  start at 000, and are never renumbered. The slug is lowercase
  words separated by hyphens. The checkpoint manager writes one
  checkpoint, then stops.
- Intended order: §4.7. 000 first. A later number exists only
  for the golden-migration split §4.7 allows.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/`. Tests stay in
  `tests/aloemacs/`. The design folder receives `spec.md` and
  later checkpoints, not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
