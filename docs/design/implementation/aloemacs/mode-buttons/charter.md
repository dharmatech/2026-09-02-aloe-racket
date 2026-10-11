# Charter — aloemacs mode buttons

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Checkpoints will live in `checkpoints/`.
Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md). Project
root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Write the specification for **three buttons on the
right of a mode line, and a left press that runs the command that
window already has**. The series identity is
**aloemacs-mode-buttons**. The labels are ↕, ↔, and ×, in that
order. ↕ sends `split-below` (`C-x 2`). ↔ sends `split-right`
(`C-x 3`). × sends `delete-window` (`C-x 0`). The press selects
that window first. Those three session sends stay as they are.
Then **stop**. Do not write checkpoints. Do not implement.

This effort refuses drag-to-select, mode `1002`, painting the
mark, hover, wheel, the middle and right buttons, dragging a
divider, a click on a path component, the directory browser,
describe, jump to definition, any menu beyond these three, the
lock command `C-x l`, window-bars 001, and a general Unicode or
display-width change. It refuses a new command and a new face.
Those stay later or out, so this spec stays small enough to slice.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Do not reopen them.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-mode-buttons 000** under
   `docs/design/implementation/aloemacs/mode-buttons/checkpoints/`.
4. Stop. The human reviews the spec. Do not write those
   checkpoint files.

There are no open product questions. Keep the spec to the two
checkpoints in §4.7. A fourth glyph, a new split send, or a press
that places the point are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| [`../windows/`](../windows/) | aloemacs-windows 000–006 is implemented. The tree is `Leaf`, `Below`, and `Right`. Rectangles are 0-based `(x, y, columns, rows)`. Right reserves one column and paints a vertical bar. Session `split-below`, `split-right`, and `delete-window` exist. A refused split or delete answers with the echo token `failed` and leaves the tree |
| [`../mode-line/`](../mode-line/) | aloemacs-mode-line 000–001 is implemented. A leaf of height at least 2 paints `(buffer name)`, then a space when it fits, then `-` fill, on its last row. A shorter leaf is all text. The echo row stays the last screen row. `(AloemacsModeLine row)` is that text |
| [`../mouse/`](../mouse/) | aloemacs-mouse 000 is implemented and accepted, and it is the whole series. Do not issue 001. `(term read-event)` yields one string such as `mouse down left 4 22`. The TTY asks for button-only tracking, mode `1000` plus SGR `1006`. A left press in text selects that window and places its point. A left press on a mode line, the echo row, a completion row, or a vertical bar leaves the session unchanged. A release leaves the point. A prompt, a search, or a pending prefix refuses every mouse string before the cell is classified |
| [`../window-point/`](../window-point/) | aloemacs-window-point 000 is implemented and accepted. Entering a window stores the departing view, then installs the entered view's point and origin. The button uses that handoff and does not place a point |
| [`../safe-cells/`](../safe-cells/) | A control paints as one space. Every other character is copied. The three labels are not controls |

Final human review of windows and of the mode line remains that
work's business. This series reads the accepted specs and the
current program and does not wait. It does not edit those specs,
those charters, or those checkpoints. A defect there that blocks
a button stops this spec; the designer reports it and does not
patch the earlier series from here.

Window-bars 000–001 is implemented. Every tall leaf's row is
wrapped in the bar color, lighter on the selected view and darker
on the others, and a Below split spends no rule row. This series
reads that composer and does not edit that series. Idle echo,
completion, and completion page are not predecessors.

The parent map is already updated. This series does not edit
[`../README.md`](../README.md), [`../explorations.md`](../explorations.md),
or [`../discussion.md`](../discussion.md).

**Why this layer:** a left press already distinguishes a mode
line from text and then leaves the session unchanged. The three
window commands already exist. The Chez editor at
`/home/dharmatech/src/e` paints ↕, ↔, and × flush right on the
status line and runs the matching command after focusing that
window. This series adds that paint and that hit.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **A wide mode line shows the three labels.** On every mode
   line whose width is at least 7, both on the selected window
   and on an unselected window, the text is today's name row at
   `width - 6` followed by the six-character group in §4.1. The
   one-view frame and a split leaf use that same text. The
   labels sit inside the bar color the row already has.
2. **A narrow line and a short leaf stay today's paint.** A mode
   line narrower than 7 columns equals today's `(row name width)`.
   A leaf shorter than two rows has no mode line and no labels.
   The echo row, a completion row, and a vertical bar gain no
   labels.
3. **A left press on a label runs the existing command after
   selection.** On an unselected window, the session matches
   entering that window and then `split-below`, `split-right`,
   or `delete-window`. On the selected window, it matches the
   send alone. The click column does not become the point.
4. **A refusal stays the send's refusal.** Delete of the only
   window, and delete of a locked window, match the session
   those sends already return, including the echo token
   `failed`. Selection still happens first.
5. **Every other mode-line press stays inert.** A left press on
   the name, the dash fill, or a space in the group leaves the
   session unchanged, including which window is selected. A
   release on a label leaves it unchanged. A press during a
   prompt, a search, or a pending prefix leaves that activity
   unchanged. Quit still wins before the string is examined.
6. **The labels stay visible while a command is pending.** A
   prompt, a search, or a pending prefix does not remove them.
7. **Tests are the proof.** The focused tests call `handle-event`
   with a `mouse down left` string and compare sessions. They
   do not open a TTY. The runner gains no bytes.

## 4. Locked decisions

### 4.1 The three labels

The group is these six characters, in this order: a space, ↕
(U+2195), a space, ↔ (U+2194), a space, × (U+00D7). Each arrow
and the multiplication sign is one character. `String` length
counts that character as one, and that length is the column
count. The spaces are ASCII spaces. A space is not a button.

The group occupies the last six columns of a mode line that
shows it. Within that row, ↕ is at index `width - 5`, ↔ is at
`width - 3`, and × is at index `width - 1`. The screen column
is the leaf rectangle's `x` plus that index. The row is the
leaf's last row when the leaf is at least two rows tall, the
same test the click already uses. An 80-by-24 one-view frame is
only a fixture: the formula puts the three labels at columns
75, 77, and 79 of the mode-line row that fixture already has.
Do not hard-code a row number.

The name occupies the columns before the group. It is clipped
by the row the mode line already builds, so a later press on
the path still has those cells. This series does not make that
press do anything.

The three characters are the whole Unicode exception. They are
ordinary cells of the row. `safe-cells` copies them. The
existing `bar` wrap colors the whole row, selected or not, with
the sequences it already uses. No per-button SGR is added. E's
`│` around the labels is not painted.

### 4.2 When the labels are painted

`(AloemacsModeLine row)` is the mode-line text.

- When `width <= 6`, the result equals today's row, including
  the empty result for a non-positive width.
- When `width >= 7`, the result equals today's row at
  `width - 6`, appended with the six-character group.

Today's row is `(name append " ")` taken to the requested
width, then `-` fill for whatever remains. Buffer names are
`"untitled"` or a path, so the leftmost column of a row that
shows the labels is a character of that name.

Pinned spellings of the new rows:

| Name | Width | Text |
|---|---:|---|
| `untitled` | 6 | today's row, `untitl` |
| `untitled` | 7 | `u ↕ ↔ ×` |
| `untitled` | 20 | `untitled ----- ↕ ↔ ×` |
| `/tmp/file.aloe` | 12 | `/tmp/f ↕ ↔ ×` |

Both paint paths already call `row`: the one-view frame in
`single-frame`, and each tall leaf in `built-rows`. Both keep
calling it. The width they already pass is the width this
formula uses: the screen width for the one-view row, and
`rect.columns` for a leaf. A right-hand leaf does not receive
the screen width. Its last column is the leaf's last column,
immediately before the vertical bar when a bar follows the
leaf.

The labels are painted on a selected bar and on an unselected
bar. They are painted while a prompt, a search, or a prefix is
pending. The echo row, a completion row, and a vertical bar are
not mode lines.

The buttons are derived from the name and the width. The picture
cache already matches on those inputs. It gains no field.

### 4.3 The press

A left press is a button press only when the cell is one of the
three labels on a mode line that painted them. The session then
runs one existing send:

| Label | Send | Keys |
|---|---|---|
| ↕ | `split-below` | `C-x 2` |
| ↔ | `split-right` | `C-x 3` |
| × | `delete-window` | `C-x 0` |

The window that already is selected runs that send and no
selection handoff. Any other window uses the handoff the click
already uses to enter a window, and then runs the send. Store
the departing view, find the pressed view in that stored tree,
and `enter-view`. Do not send `place-at`. The click column is
not installed as the point.

The session after the press equals the session that sequence
returns. That includes the fit a successful split already
performs, the window the send leaves selected, and the echo
token `failed` when the send refuses. Delete of the only
window, delete of a locked window, and a split the tree
refuses are those existing refusals. Selection still happens
before a refusal. When the handoff's view cannot be found, the
session is unchanged and the send does not run, as the click's
missing-view path already returns the receiver.

No new command constructor is added. The keymap bindings stay
as they are. `C-x l` is not sent. A locked window's × is
`delete-window` on that window, and the lock rule inside that
send stays as it is.

### 4.4 Presses that leave the session

These leaves match the session from before the event:

- a left press on the name, the dash fill, or either space in
  the group, including the name of a window that is not selected
- a left release on a label
- a middle or right button anywhere
- a mouse string while a prompt is present, while searching, or
  while a prefix is pending, including a string aimed at a label
- a mouse string after quit

The prompt, search, and prefix refusals stay where they are,
in front of the cell test. Text, the echo row, a completion
row, and a vertical bar stay on the paths the mouse spec
already gives them. A mode line narrower than 7 columns has no
label cells, so a press on it stays inert.

### 4.5 Where the work lives

The row formula lives on `AloemacsModeLine`. The hit is a
branch of the session's existing press classification, using
the leaf rectangle `press-at` already finds. No new class is
added. The ordered `define-class` inventory stays as it is. No
editor field, picture field, or stored mode-line field is
added. Term, the runner, and `safe-cells` stay as they are.
The runner does not enable a new mouse mode.

### 4.6 What this series leaves alone

`Text` gains no method. `SPEC.md` gains no row. The kernel
gains no message. The mouse string, mode `1000`, and SGR
`1006` stay as the accepted mouse spec left them. Window
commands stay the same sends. The echo token keeps the values
those sends already write. Bar colors and the Below rule stay
with window bars. Direct editor `frame` still has no mode line.

### 4.7 Two checkpoints

| Checkpoint | What it proves |
|---|---|
| **aloemacs-mode-buttons 000** | The row formula in §4.2, on the pure `row` send and in a one-view frame and a split frame. Widths below 7 keep the row strings already pinned. A wide row shows the six-character group inside the current bar wrap. A left press on a label still leaves the session unchanged |
| **aloemacs-mode-buttons 001** | A left press on each label of an unselected window matches entering that window and then the send. One label on the selected window matches the send alone. A refused delete matches that send. A press off a label, a release on a label, and a press during a prompt, a search, and a pending prefix each leave the session unchanged |

000 is testable from the row text and does not make a label
run a command. 001 is testable once those cells exist. The
manager writes 000 only, then stops.

If 000's frame migration would not fit one implementer
conversation, the spec splits paint into the one-view frame and
then the split leaves, in that order, and the press stays the
last checkpoint. The added number introduces no second feature.

## 5. Authority

- [`../README.md`](../README.md) — layer order. This layer is
  the mode buttons
- [`../windows/spec.md`](../windows/spec.md) — leaf geometry,
  the vertical bar, `split-below`, `split-right`,
  `delete-window`, and the lock refusal inside delete
- [`../window-point/spec.md`](../window-point/spec.md) —
  storing the departing view and `enter-view`
- [`../mode-line/spec.md`](../mode-line/spec.md) — the name
  row, the short leaf, and the echo row. This charter is the
  authority for `(row name width)` when `width >= 7`. Widths
  below 7 stay that spec's spelling. Do not amend that spec
- [`../mouse/spec.md`](../mouse/spec.md) — the mouse string,
  `handle-event`, the prompt, search, and prefix refusals, and
  the cell classification. This charter is the authority for a
  left press on the three label cells. Every other mouse
  result stays that spec. Do not amend that spec, and do not
  issue aloemacs-mouse 001
- [`../safe-cells/spec.md`](../safe-cells/spec.md) — controls
  become one space; every other character is copied
- [`../window-bars/spec.md`](../window-bars/spec.md) — the bar
  wrap around the row. Colors and the Below rule stay there.
  Checkpoint 001 of that series is out of bounds
- [`examples/aloemacs/file.aloe`](../../../../../examples/aloemacs/file.aloe)
  — `AloemacsModeLine`, `built-rows`, `single-frame`,
  `handle-mouse`, `press-at`, and the three sends
- `/home/dharmatech/src/e`, `lib/head/head.sls`,
  `window-buttons` — a seam catalog for the three labels and
  their order. The `│` bars and the divider drag supply no
  requirement

`SPEC.md` remains language law. This series does not amend it.
When this charter and the mouse spec disagree about a left
press on a label cell, this charter wins. When this charter
and the mode-line spec disagree about a row of width 7 or
more, this charter wins. After the human accepts `spec.md`,
that file is the design authority for the checkpoint manager
and the implementers.

## 6. Non-goals

- Drag-to-select, mode `1002`, or painting the mark
- Hover, wheel, or the middle and right buttons
- Dragging a divider, or painting `│` around the labels
- A click on a path component, the directory browser,
  describe, jump to definition, or a menu beyond these three
- A new command, a keymap change, or sending `C-x l`
- Changing what `split-below`, `split-right`, or
  `delete-window` do, including the lock refusal
- Placing the point from a mode-line press
- A new face, a per-button color, or a change to bar colors
- Window-bars 001, idle echo, completion, or completion page
- A display-width table, `wcwidth`, or a grapheme rule
- A new class, a stored mode-line field, or a picture field
- A Term method, a runner change, or a new mouse mode
- Editing the mouse, mode-line, or window-bars specs, or the
  parent map
- A kernel message, a `SPEC.md` row, or a `CHECKPOINTS.md`
  entry

## 7. Handoff

- Series identity: `aloemacs-mode-buttons`.
- Checkpoint 000 is spoken **aloemacs-mode-buttons 000** and
  filed as `checkpoints/000-paint.md`. Checkpoint 001 is
  spoken **aloemacs-mode-buttons 001** and filed as
  `checkpoints/001-press.md`. Numbers are three digits, start
  at 000, and are never renumbered. The slug is lowercase
  words separated by hyphens. The checkpoint manager writes
  one checkpoint, then stops.
- Intended order: §4.7. Paint first, then the press. A later
  number exists only for the size split §4.7 allows, and the
  press stays last.
- Project root:
  `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Code stays in `examples/aloemacs/file.aloe`. Tests stay in
  `tests/aloemacs/`. The spec names the focused test files and
  the standing command `TMPDIR=/tmp raco test -j 4 -y`. The
  design folder receives `spec.md` and later the checkpoints,
  not the program.
- After the human accepts `spec.md`, that file is the design
  authority for the checkpoint manager and the implementer.
  This charter is the assignment for the spec writer only.

If you have been told to read this file, this is the whole assignment.
