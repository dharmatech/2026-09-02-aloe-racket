# aloemacs-mode-buttons 000 — Paint

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice,
and stop when green.

## Goal

A mode line at least seven columns wide ends with the six characters
` ↕ ↔ ×`. The buffer name and its dash fill stop six columns early to
make room. A narrower mode line keeps today's text.

- `AloemacsModeLine` gains `buttons`, `buttons?`, and `name-row`.
  `name-row` is today's `row` under a new name. `row` keeps its
  signature and its two call sites and gains the new body: `name-row`
  at `width - 6` followed by `buttons` when `width >= 7`, `name-row`
  at `width` otherwise.
- Both paint paths already send `row` and keep doing so, so the
  one-view frame, the too-small-tree fallback, and every tall split
  leaf at least 7 columns wide end with the group, inside the LIGHT or
  DARK bar the row already has.
- The echo row, a completion row, a vertical bar, and a leaf shorter
  than two rows gain no labels.
- A left press on a label still leaves the session unchanged. The
  press is 001.

Migrate the existing goldens. Stop when the focused proof and the
full aloemacs suite pass.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec. The
checkpoint narrows the spec to one slice and restates the migration
inventory from a scratch run. It does not revise the spec.

- Identity: **aloemacs-mode-buttons 000**, filed as
  `checkpoints/000-paint.md`. This is a local editor checkpoint. It
  takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md), and
  [SPEC.md](../../../../../../SPEC.md) before product edits.
  `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`.
- The accepted [../spec.md](../spec.md) governs:
  - §§1–4: predecessors, the product boundary, the file boundary,
    exact shapes, and non-goals.
  - §5.1–§5.3: the group, the row, and where the labels are painted.
  - §6: this layer, including its examples, migration, and focused
    proof.
  - §8: the 000 verification commands.

  §5.4, §5.5, §5.6, and §7 describe the press. They are 001. In 000
  the session is not edited at all.

### Current tree

Start from
[file.aloe](../../../../../../examples/aloemacs/file.aloe). Line
numbers are approximate.

- `AloemacsModeLine` (near line 251) is declared after
  `AloemacsBuffers` and before `AloemacsLeafPicture`, with `(fields)`.
  Its methods are `row (name width)`, `fill (remaining)`,
  `bar (row selected?)`, and the zero-argument `light`, `dark`, and
  `plain`. The body of `row` today is:

  ```aloe
  (row (name String) (width Int) String
    (if (width <= 0)
        ""
        (let ((clipped ((name append " ") take width)))
          (clipped append (self fill (width - (clipped len)))))))
  ```

- `built-rows` (near line 678) paints each tall split leaf. When
  `(rect rows) >= 2` it conses, as the leaf's last row,
  `((AloemacsModeLine new) bar (editor safe-cells ((AloemacsModeLine new) row (buffer name) (rect columns))) ((view id) = selected))`.
- `single-frame` (near line 1898) paints the one-view frame and the
  too-small-tree fallback. When `(root rows) >= 2` it appends
  `((AloemacsModeLine new) bar (editor safe-cells ((AloemacsModeLine new) row ((self current-buffer) name) columns)) #t)`
  after the `ESC[h;1H` address.
- `press-at` (near line 2047) classifies a left press. Its mode-line
  arm is `(self unchanged)`. **Nothing in the session changes in
  000.**
- String `len`, `take`, `append`, `=`, and `>=` on `Int` are the only
  sends the new methods need. The Aloe reader is Racket's reader, so
  `"\u2195"` in `file.aloe` is the one character U+2195.

### Size

One conversation. The product edit is one class in one file: three
short methods and a new three-line body for `row`. The focused file
is new.

The manager applied exactly the §5.2 product edit to a scratch copy
of the tree and ran `TMPDIR=/tmp raco test -j 4 -y tests/aloemacs`.
It reported 102 failures in exactly the 33 files listed below. Every
failure's actual String equals its expected String once the mode row
is respelled by the §5.2 formula; no fit, rectangle, refusal, cursor,
echo, or Fs count differs. Twenty-eight of those files are fixed by
one edit to a test-local row helper. The rest are literal rows, most
of them in `windows-split.rkt` and `window-bars-one-view.rkt`. This
is the size of aloemacs-window-bars 000, which fit one conversation,
so the spec's §6.5 paint split is **not** applied. If you cannot
finish in this conversation, stop and report which files remain. Do
not split the slice yourself and do not write 001.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, in `AloemacsModeLine` only: add
  `buttons`, `buttons?`, and `name-row`, and replace the body of
  `row`. You may add a comment above the new methods. No other class
  and no other method changes.
- Create `tests/aloemacs/mode-buttons-paint.rkt` before the product
  edit, and watch it fail.
- The **33 existing test files** in the migration table below, only
  as that table says.

### Must leave untouched

- In `file.aloe`: every class other than `AloemacsModeLine`; on
  `AloemacsModeLine`, the `fill`, `bar`, `light`, `dark`, and `plain`
  methods and their results; the two `row` call sites in `built-rows`
  and `single-frame`, which keep sending `row` with the arguments they
  pass today; `press-at`, `place-in`, `place-at`, `handle-event`,
  `handle-mouse`, `view-at`, `rect-for`, `root-rect`,
  `completion-row-count`, `frame`, `multi-frame`, `right-rows`,
  `record-pictures`, `with-pictures`, `AloemacsLeafPicture.matches?`,
  the keymap tables, and the two loads. Do not change the order of
  declarations.
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`,
  everything under `host/racket/`, `lib/`, `aloe/`, `bin/`, `SPEC.md`,
  and `CHECKPOINTS.md`. Add no dependency, load, host capability,
  runner argument, Term method, mouse mode, or build step.
- Shapes. The ordered `define-class` list of `file.aloe` is
  unchanged, so the fifteen tests that pin it need no edit.
  `AloemacsModeLine` keeps `(fields)` and its position. `AloemacsView`,
  `AloemacsLeafPicture`, `AloemacsWindowRect`, `AloemacsWindows`,
  `AloemacsBuffer`, `AloemacsEditor`, and the session keep their
  fields. `AloemacsCommand` keeps its constructors. Add no class,
  field, command, key, keymap entry, or kernel message.
- Every existing test not in the migration table. In particular
  `buffer-session.rkt` passes unedited in the scratch run (its frames
  are 2 and 4 columns wide); leave its helper alone. `mouse.rkt`,
  `window-pictures.rkt`, `file-session.rkt`, `windows-state.rkt`'s
  other cases, `completion-page-session.rkt`,
  `windows-buffer-identity.rkt`, `keymap-session.rkt`,
  `undo-session.rkt`, and every other file pass unedited. Create no
  shared helper module. Do not create `mode-buttons-press.rkt`.
- Every document: this checkpoint, `spec.md`, `charter.md`, and
  `README.md` in this folder; the mouse, mode-line, window-bars,
  window-point, windows, and safe-cells documents; and the parent
  `aloemacs/README.md`, `discussion.md`, and `explorations.md`.

If another file, another class, a fixture change, a fit change, or a
geometry change seems necessary, stop and report it. Do not widen
this checkpoint.

## Required behavior

### 1. The group (spec §5.1)

The group is six characters, in this order:

| Index in group | Character | Code point |
|---:|---|---|
| 0 | space | U+0020 |
| 1 | ↕ | U+2195 |
| 2 | space | U+0020 |
| 3 | ↔ | U+2194 |
| 4 | space | U+0020 |
| 5 | × | U+00D7 |

Each arrow and the multiplication sign is one character and one cell.
Aloe `String` `len` counts it as one, `take` and `drop` step over it
as one, and that count is the column count. The three characters are
ordinary cells: not controls, so `safe-cells` copies them, and inside
the bar wrap, so no per-button sequence is added. No `│` is painted
around them. No width table is added.

In `file.aloe`, spell every label literal with escapes so the file
stays ASCII bytes:

```aloe
(buttons () String
  " \u2195 \u2194 \u00d7")
```

The reader produces the same `String` from that spelling and from
the literal glyphs: `(" \u2195 \u2194 \u00d7" = " ↕ ↔ ×")` is true.
Racket tests may use either spelling. Racket `string-length` and
`substring` count characters, and the runner doubles already decode
output with `bytes->string/utf-8`, so a row of width `w` is `w`
characters on both sides.

### 2. The three sends and the new `row` (spec §5.2)

`AloemacsModeLine` keeps `(fields)` and its declared position. Add
three sends and give `row` a new body. Nothing else on the class
changes.

```text
(line buttons)  -> String   ; the six characters above
(line buttons? width) -> Bool
(line name-row name width) -> String
(line row name width) -> String
```

```text
buttons?(width) = width >= 7

name-row(name, width) = ""                                    when width <= 0
                      = clipped ++ fill(width - clipped.len)  otherwise,
                        where clipped = (name ++ " ") take width

row(name, width) = name-row(name, width - 6) ++ buttons   when buttons?(width)
                 = name-row(name, width)                    otherwise
```

`name-row` is today's `row`, body and all, under a new name. Every
result the mode-line spec pins for `row` is now a result of
`name-row`, at every width. This sketch can be pasted as it is:

```aloe
(buttons? (width Int) Bool
  (width >= 7))

(name-row (name String) (width Int) String
  (if (width <= 0)
      ""
      (let ((clipped ((name append " ") take width)))
        (clipped append (self fill (width - (clipped len)))))))

(row (name String) (width Int) String
  (if (self buttons? width)
      ((self name-row name (width - 6)) append (self buttons))
      (self name-row name width)))
```

All four are pure. They perform no effect, accept any `String` name
and any `Int` width, and never raise. For a positive width the result
of `row` has exactly `width` characters. At `width >= 7` the last six
characters are the group, so ↕ is at index `width - 5`, ↔ at
`width - 3`, and × at `width - 1`. The name's first character, or a
space for an empty name, is at index 0.

Controls stay raw in `name-row` and in `row`; the paint site applies
safe cells to the whole row, as today. A control in a name cannot
move or recolor a label.

Do not add `label-at`. Do not store an `AloemacsModeLine` anywhere.

### 3. Pinned rows (spec §5.2)

Quotes delimit the row and are not painted. These are raw rows,
before safe cells.

| Name | Width | `row` |
|---|---:|---|
| `untitled` | 6 | `untitl` (today's row) |
| `untitled` | 7 | `u ↕ ↔ ×` |
| `untitled` | 8 | `un ↕ ↔ ×` |
| `untitled` | 9 | `unt ↕ ↔ ×` |
| `untitled` | 12 | `untitl ↕ ↔ ×` |
| `untitled` | 14 | `untitled ↕ ↔ ×` |
| `untitled` | 15 | `untitled  ↕ ↔ ×` |
| `untitled` | 16 | `untitled - ↕ ↔ ×` |
| `untitled` | 20 | `untitled ----- ↕ ↔ ×` |
| `/tmp/file.aloe` | 12 | `/tmp/f ↕ ↔ ×` |
| `/cwd/a.txt` | 8 | `/c ↕ ↔ ×` |
| `/cwd/a.txt` | 80 | `/cwd/a.txt `, then 63 dashes, then ` ↕ ↔ ×` |
| `/a` | 8 | `/a ↕ ↔ ×` |
| `/a` | 9 | `/a  ↕ ↔ ×` |
| `-\|+` | 7 | `- ↕ ↔ ×` |
| `` (empty) | 7 | `  ↕ ↔ ×` |

At width 15 the name's separator space and the group's leading space
are adjacent. At width 14 the separator does not survive the clip, so
one space separates `untitled` from ↕. Both follow from the formula
and are not defects. Do not reserve a dash, trim a space, or move the
group.

`name-row` keeps every row the mode-line spec pins, at every width:

| Name | Width | `name-row` |
|---|---:|---|
| `untitled` | 0 | `` (empty) |
| `untitled` | -8 | `` (empty) |
| `untitled` | 1 | `u` |
| `untitled` | 8 | `untitled` |
| `untitled` | 9 | `untitled ` |
| `untitled` | 12 | `untitled ---` |
| `/cwd/a.txt` | 8 | `/cwd/a.t` |
| `/a` | 4 | `/a -` |
| `` (empty) | 4 | ` ---` |

With the name `"a\u001b[31m\t\r\n\u0001\u007fZ"`: at width 15,
`name-row` is `"a\u001b[31m\t\r\n\u0001\u007fZ --"` as today, the
raw `row` is `"a\u001b[31m\t\r\n ↕ ↔ ×"`, and the painted row after
`safe-cells` is `"a [31m    ↕ ↔ ×"`: nine cells of name, then the
group.

### 4. Where the labels are painted (spec §5.3)

Both paint paths already send `row` and keep sending it with the
arguments they pass today. **Do not edit either call site.**

- `single-frame` sends `row` with the buffer name and the screen
  width, then `safe-cells`, then `bar` with `#t`.
- `built-rows` sends `row` with the buffer name and `(rect columns)`,
  then `safe-cells`, then `bar` with `((view id) = selected)`.

So the painted mode line is LIGHT or DARK, the name cells, the group,
then PLAIN, and the only change in the bytes is inside the visible
cells. A right-hand leaf receives `rect.columns`, not the screen
width, so its × is in the leaf's last column, immediately before the
`|` that `right-rows` appends after PLAIN.

The labels are painted on the selected bar and on every unselected
bar, and while a prompt, a search, or a prefix is pending, because
the row never reads those. The echo row, a completion row, and the
vertical bar are not mode lines and are unchanged. A leaf shorter
than two rows has no mode line and no labels. A mode line narrower
than 7 columns is today's row. The fallback frame is the one-view
frame of the selected buffer at the full screen width, as today, so
it shows one group at the screen's right edge. Direct editor `frame`
still has no mode line.

The buttons are derived from the name and the width.
`AloemacsLeafPicture.matches?` already keys on `name` and `columns`,
so a recorded leaf picture stays valid exactly when its row would be
the same. The picture gains no field. `record-pictures` and
`with-pictures` are unchanged.

### 5. Exact examples (spec §6.2)

The manager checked each of these against the scratch run. LIGHT is
`\e[38;5;16;48;5;250m`, DARK is `\e[38;5;252;48;5;239m`, PLAIN is
`\e[0m`.

An empty untitled buffer at 12 columns and 4 terminal rows, idle.
Today's bytes and 000's bytes differ only in the mode row's cells:

```text
today: "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[1;1H\e[?25h"
000:   "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitl ↕ ↔ ×\e[0m\e[4;1H\e[1;1H\e[?25h"
```

The same buffer at 7 columns and 4 rows, and at 6 columns and 4 rows:

```text
7 by 4: "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250mu ↕ ↔ ×\e[0m\e[4;1H\e[1;1H\e[?25h"
6 by 4: "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitl\e[0m\e[4;1H\e[1;1H\e[?25h"   (today's bytes)
```

Two stacked views of one buffer, from the window-bars spec and
`tests/aloemacs/window-bars-split.rkt` (near line 450): terminal 8 by
6, root 8 by 5, path `/a`, lines `one`, `two`, `three`, `four`,
`Below(Leaf view 0, Leaf view 1)`, view 0 selected at origin `(0,0)`
with point `(0,0)`, view 1 at origin `(2,0)`. Rectangles are
`(0,0,8,3)` and `(0,3,8,2)`. Each bar is `/a ↕ ↔ ×`:

```text
today: "\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a -----\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a -----\e[0m\e[6;1H\e[1;1H\e[?25h"
000:   "\e[?25l\e[2J\e[Hone     \r\ntwo     \r\n\e[38;5;16;48;5;250m/a ↕ ↔ ×\e[0m\r\nthree   \r\n\e[38;5;252;48;5;239m/a ↕ ↔ ×\e[0m\e[6;1H\e[1;1H\e[?25h"
```

The window-bars spec's mixed nesting at 9 by 6,
`Right(Below(view 0, view 1), view 2)`, has leaves 4 columns wide.
Its frame is unchanged, byte for byte (`window-bars-split.rkt` near
line 475):

```text
"\e[?25l\e[2J\e[Habcd|HIJ \r\nghij|MNO \r\n\e[38;5;252;48;5;239m/a -\e[0m|RST \r\ntuvw|WXY \r\n\e[38;5;16;48;5;250m/a -\e[0m|\e[38;5;252;48;5;239m/b -\e[0m\e[6;1H\e[4;2H\e[?25h"
```

One view at 80 by 24 on `/cwd/a.txt`, with `s0` as defined under
Tests below: row 22 is LIGHT, `/cwd/a.txt `, 63 dashes, ` ↕ ↔ ×`,
PLAIN. ↕ is at column 75, ↔ at 77, × at 79. After `(s0 split-right)`,
the left leaf is `(0,0,40,23)` and its row 22 is `/cwd/a.txt `, 23
dashes, ` ↕ ↔ ×`, with × at column 39; the right leaf is
`(41,0,39,23)` and its row is `/cwd/a.txt `, 22 dashes, ` ↕ ↔ ×`,
with × at column 79. The whole row 22 of that frame, between the
`\r\n` before it and the echo address after it, is:

```text
LIGHT "/cwd/a.txt ----------------------- ↕ ↔ ×" PLAIN "|" DARK "/cwd/a.txt ---------------------- ↕ ↔ ×" PLAIN
```

After `(s0 split-below)` instead, both leaves are 80 wide; row 11 is
LIGHT and row 22 is DARK, and each ends with the group at columns
75, 77, 79.

### 6. The press stays inert

`press-at`'s mode-line arm stays `(self unchanged)`. On `s0`,
`handle-event` of `mouse down left 75 22`, `mouse down left 77 22`,
and `mouse down left 79 22` each return a session equal to the
receiver. 001 makes these presses run commands and replaces that one
item of the focused file.

## Tests

### Focused proof: `tests/aloemacs/mode-buttons-paint.rkt`

Write this file first and watch it fail. It needs no TTY. Use the
checked driver and `rackunit`, following the patterns in
`mode-line-row.rkt` (reading `file.aloe` as data, the fresh checked
load with no host, type and arity rejections), `window-bars-one-view.rkt`
(frames and the method-shape loop), `window-pictures.rkt`
(`record-pictures`), `mouse.rkt` (`s0` and `handle-event`), and
`runner.rkt` or `echo-runner.rkt` (`make-term-receiver` and
`run-aloemacs-with-hosts`). Copy any helper you need into this file.
Do not `require` another test module.

Load `file.aloe` directly where no host is needed. Where a session
is framed, load `main.aloe` through `driver-load-file!` with an
`fs-host` injected first. The fs double is the one `mouse.rkt` uses:

```racket
(make-fs-double "/cwd"
  (hash "/cwd" 'directory "/cwd/a.txt" 'file "/cwd/b.txt" 'file)
  (hash "/cwd/a.txt" "hello\nworld\nxyz" "/cwd/b.txt" "b"))
```

and `s0` is
`((aloemacs-editor visited "hello\nworld\nxyz" (Path new "/cwd/a.txt")) ensure-visible 80 24)`.
Session equality is `(check actual expected)` through the driver, as
`mouse.rkt` spells `same`.

Expected rows and frames are test-local literals. Spell the group as
`" ↕ ↔ ×"` or `" \u2195 \u2194 \u00d7"`. Never build an expectation
by sending `row`, `name-row`, `buttons`, `bar`, `frame-rows`, or a
session composer. Keep whole-frame assertions.

Prove:

1. **Types and arities.** `((AloemacsModeLine new) buttons)` types as
   `String` and rejects an argument. `buttons?` types as `Bool` and
   rejects zero and two arguments and a `String` argument. `name-row`
   types as `String` and rejects the same shapes `mode-line-row.rkt`
   rejects for `row`: zero, one, and three arguments, an `Int` name, a
   `String` or `Float` width, and a wrong receiver. `row` still types
   as `String`. Read as data with `port->list read`, `name-row` is
   declared `(name-row (name String) (width Int) String)`, `buttons?`
   is `(buttons? (width Int) Bool)`, and `buttons`, `light`, `dark`,
   and `plain` each take `()` and return `String`. A fresh checked
   load of `file.aloe` binds neither `fs-host` nor `term`, writes
   nothing to output or error, keeps `AloemacsModeLine`'s `(fields)`,
   and keeps the ordered `define-class` list exactly as
   `mode-line-row.rkt` pins it:
   `AloemacsPrompt AloemacsCompletionScan AloemacsBuffer AloemacsBuffers AloemacsModeLine AloemacsLeafPicture AloemacsView AloemacsWindowTree AloemacsWindowRect AloemacsWindows AloemacsCommand (AloemacsKeymap B) AloemacsBinding AloemacsSearchScan AloemacsMouse (AloemacsSession H)`.
2. **The group.** `buttons` has length 6; its characters at indices
   1, 3, 5 are U+2195, U+2194, U+00D7 and at 0, 2, 4 are spaces;
   `(ed safe-cells (buttons))` equals it for an editor `ed`; and the
   escape spelling equals the literal spelling.
3. **The threshold.** `buttons?` is false at -1, 0, 1, 6 and true at
   7, 8, 12, 80.
4. **Rows.** `name-row` equals every row in the `name-row` table
   above and the control case at 15. `row` equals `name-row` at
   widths -8, 0, 1, 3, 4, 6. `row` equals every row in the `row`
   table; assert each string and its length independently. For widths
   7, 8, 15, 20, and 80, the last six characters of `row` equal
   `buttons` and the character at index 0 is the name's first
   character. The control name at 15 paints as `"a [31m    ↕ ↔ ×"`
   through `safe-cells`, and the stored name stays raw.
5. **One-view frames.** Byte for byte: both 12 by 4 frames above
   (today's with `untitled ---` must no longer be produced), the 7
   column frame, and the unchanged 6 column frame. One view at 80 by
   24 on `/cwd/a.txt` with the group at columns 75, 77, 79 inside
   LIGHT and PLAIN; the same with echo `saved`, during a search, and
   during a prompt with the cursor on the echo row; and a nonzero
   origin. Each frame has one LIGHT, one PLAIN, and no DARK. On the
   frames at least 7 columns wide, PLAIN immediately follows ×; the 6
   column frame has no label.
6. **Split frames.** The 8 by 6 stacked frame above, byte for byte.
   The 9 by 6 mixed frame above, unchanged. `(s0 split-right)` at 80
   by 24, whose row 22 is the string above: × at column 39 followed by
   PLAIN and `|`, and × at column 79. `(s0 split-below)`, whose row
   11 is LIGHT and row 22 is DARK, each ending with the group. An
   unselected leaf's group is inside DARK. A Below split whose lower
   leaf is one row tall paints that leaf as text with no group and no
   bar; build the tree with raw constructors as `window-bars-split.rkt`
   builds its short case, at a width of at least 7 so the upper leaf's
   bar shows the group, and derive the rows from the live `top` and
   `bottom` rather than hard-coding them. Every composed row's visible
   width (the row with LIGHT, DARK, and PLAIN removed) is the root
   width.
7. **Pictures.** On a split session, `record-pictures` then `frame`
   yields the same bytes as `frame` before recording, and a second
   `frame` yields them again; the session apart from the pictures is
   unchanged and there is no Fs effect.
8. **Labels still inert.** On `s0`, `handle-event` of
   `mouse down left 75 22`, `mouse down left 77 22`, and
   `mouse down left 79 22` each return a session equal to the
   receiver. Keep this as its own test case; 001 replaces it with the
   press contract and changes nothing else in this file.
9. **Runner.** A scripted Term double at 12 by 4 drives `x` then
   `escape` through `run-aloemacs-with-hosts` with a counted Fs
   double. Two frames are written, decoded with
   `bytes->string/utf-8`: the 000 12 by 4 frame above, then
   `"\e[?25l\e[2J\e[Hx\r\n\e[1;2H\e[?25h\e[?25l\e[3;1H" LIGHT "untitl ↕ ↔ ×" PLAIN "\e[4;1H\e[1;2H\e[?25h"`.
   Assert the exact event list, with one write per key, and the
   exact read and write counts.

### Migration of existing files

The product edit changes cells only. Apply one rule everywhere: a
mode row of width `w >= 7` is today's spelling at `w - 6` followed
by the group; a row of width `w <= 6` is today's spelling. Keep
every fit result, rectangle, refusal, cursor, echo, and Fs count
unchanged. Keep every whole-frame assertion; do not replace one with
a substring check. A failure that differs by anything other than the
cells of a mode row is a stop condition. Report it. Do not edit a
fixture, geometry, or another expectation to force the suite green.

**Row helpers.** Each file below builds its expected mode row with a
local helper: `label = clip(name ++ " ", w)`, then `-` fill, some
with safe cells applied. The helper gains the group: when `w >= 7`,
that spelling at `w - 6` followed by the group; otherwise as today.
One edit per helper. Spell the group as a test-local literal. Safe
cells may be applied before or after appending the group; the group
has no control.

**Method shapes.** `window-bars-one-view.rkt` (near lines 187–193)
reads `file.aloe` as data, pins the declared shapes of `bar`, `row`,
and `fill`, and then requires every other `AloemacsModeLine` method
to take no arguments and return `String`. Retarget it: pin
`(name-row (name String) (width Int) String)` and
`(buttons? (width Int) Bool)` beside `row` and `fill`, exclude
`name-row` and `buttons?` from the zero-argument loop, and keep that
loop for `buttons`, `light`, `dark`, and `plain`. The `bar` ownership
loop in the same test is unchanged.

**Literal rows.** Each literal becomes the §5.2 spelling at its
width. Rows narrower than 7 stay: `unti`, `/a -`, `unt`, `/cwd`,
`/sho`, `/cwd/`, and every width-4 split row.

Paths are relative to `tests/aloemacs/`. Line numbers are
approximate. The scratch run's first failure per test case is where
to start; search each file again for every mode row of width 7 or
more.

| File | Helper to edit | Literal rows to respell |
|---|---|---|
| `buffer-value.rkt` | `mode-row` near 447 | |
| `completion-frame.rkt` | `mode` near 98 | near 275: `/a ------` → `/a  ↕ ↔ ×`; near 472 and 483, inside whole 9 by 4 frames: `untitled ` → `unt ↕ ↔ ×` |
| `completion-page-frame.rkt` | `mode` near 100 | near 176, inside a whole 9 by 12 frame: `untitled ` → `unt ↕ ↔ ×` |
| `completion-session.rkt` | `mode-row` near 152 | |
| `echo-runner.rkt` | `mode-row` near 11 | |
| `echo-session.rkt` | `mode-row` near 99 | |
| `file-runner.rkt` | | near 17, 20, 23, 26, inside whole frames at width 8: `untitled` → `un ↕ ↔ ×`; `/cwd/a.t` → `/c ↕ ↔ ×`; `/cwd/new` → `/c ↕ ↔ ×` (twice) |
| `idle-echo.rkt` | `mode` near 42 | |
| `keymap-prefix.rkt` | `mode-row` near 142 | |
| `keymap-runner.rkt` | `mode-row` near 12 | |
| `kill-session.rkt` | | near 326: `(regexp-match? #rx"untitled" (ev st '(marked frame 12 3)))` no longer matches, because the 12-column row is `untitl ↕ ↔ ×`; match that row instead. The `/cwd/a.txt` match near 330 at width 30 still holds; leave it |
| `minibuffer-session.rkt` | `mode-row` near 160 | |
| `minibuffer-value.rkt` | `mode-row` near 141 | |
| `mode-line-one-view.rkt` | `name-row` near 50 | near 116–119, the inline clip-and-dash recomputation of `row` on the control name at widths 1, 3, 6, 10, 15: widths 1, 3, 6 stay; at 10 and 15 the expected raw row is the clip at `width - 6` plus the group, `"a\u001b[3 ↕ ↔ ×"` and `"a\u001b[31m\t\r\n ↕ ↔ ×"`. Near 123, `(name-row name 15)` is `"a [31m    ↕ ↔ ×"` |
| `mode-line-row.rkt` | | near 68–69, 74: `("untitled" 8 "un ↕ ↔ ×")`, `("untitled" 9 "unt ↕ ↔ ×")`, `("untitled" 12 "untitl ↕ ↔ ×")`, `("/cwd/a.txt" 8 "/c ↕ ↔ ×")`, and the control name at 15 → `"a\u001b[31m\t\r\n ↕ ↔ ×"`. The length assertion still holds |
| `mode-line-split-views.rkt` | `mode` near 76 | near 186: `-\|+ ---` → `- ↕ ↔ ×`; near 345: `/a ------` → `/a  ↕ ↔ ×` |
| `prompt-commands-find-file.rkt` | `mode-row` near 135 | |
| `prompt-commands-save-as.rkt` | `mode-row` near 147 | |
| `prompt-commands-select-buffer.rkt` | `mode-row` near 139 | |
| `runner-check.rkt` | `mode-row` near 118 | |
| `runner.rkt` | | near 99, 102, inside whole frames at width 8: `untitled` → `un ↕ ↔ ×` |
| `safe-cells.rkt` | `mode-row` near 41 | |
| `search-session.rkt` | `mode-row` near 93 | |
| `viewport-runner.rkt` | `mode-row` near 15 | near 154–158, two whole frames at width 8: `/cwd/a.t` → `/c ↕ ↔ ×` |
| `window-bars-one-view.rkt` | `spelled` near 97 | the method-shape retarget near 187–193; near 228–229: `untitled ---` → `untitl ↕ ↔ ×` in both bar colors; near 234: `a [31m -` → `a  ↕ ↔ ×` inside LIGHT and PLAIN; near 251: `(mode control 15)` → `a [31m    ↕ ↔ ×`; near 263, 270: `untitled ---` → `untitl ↕ ↔ ×`; near 314, 474: `/cwd/a -----` → `/cwd/a ↕ ↔ ×`; near 387, 391, 428–429: `/a ------` → `/a  ↕ ↔ ×` |
| `window-bars-split.rkt` | `mode` near 107 | near 450: `/a -----` → `/a ↕ ↔ ×` (both bars); near 506: `/b ------` → `/b  ↕ ↔ ×`; near 736–749: `/cwd/a --` → `/cw ↕ ↔ ×` |
| `window-point.rkt` | `mode-row` near 98 (it does not clip today; add the group when `width >= 7`) | |
| `windows-delete-and-other.rkt` | `mode-row` near 110 | near 519 and 525, the name passed to the local `bars` helper: `/cwd/a.tx` → `/cw ↕ ↔ ×`. The `/cwd` passed to it for the 4-wide Right case stays |
| `windows-layout-and-rendering.rkt` | `mode-row` near 100 | near 281–282, 383–384: `untitle` → `u ↕ ↔ ×`. The `untitle` near 378 is the idle echo of a 7 by 2 frame, not a bar; leave it |
| `windows-lock.rkt` | `mode-row` near 110 | near 372: `/cwd/a.tx` → `/cw ↕ ↔ ×` |
| `windows-split.rkt` | `mode-row` near 110 | near 376, 391, 398–400, 413, 422, 426, 437, 459: `untitle` → `u ↕ ↔ ×`; near 465: `/short ` → `/ ↕ ↔ ×`; near 570, 598: `untitled ` → `unt ↕ ↔ ×`; near 671, 675, 679: `/cwd/a.tx` → `/cw ↕ ↔ ×` |
| `windows-state-foundation.rkt` | `mode-row` near 444 | |
| `windows-state.rkt` | | near 619, inside a whole 8 by 3 frame: `/cwd/b.t` → `/c ↕ ↔ ×` |

**How this list was found.** The manager applied exactly the §5.2
product edit to a scratch copy of the tree and ran the aloemacs
suite. It reported 102 failures in exactly these 33 files. The spec's
§6.3 inventory named `buffer-session.rkt`, which passes unedited, and
omitted `windows-state.rkt` and `kill-session.rkt`, which fail; the
table above is the corrected inventory, as §6.3 asks. Visible width
assertions, such as `rows!` in `mode-line-split-views.rkt`, still
hold because each row keeps exactly `w` characters.

The implementation on 2026-10-11 found four literal sites the table
as issued did not list, in `completion-frame.rkt`,
`completion-page-frame.rkt`, `viewport-runner.rkt`, and
`windows-delete-and-other.rkt`. Each is a mode row of width 7 or
more inside a file the table already named, so each is inside the
rule above. The table now lists them. The manager reviewed the diff
against this checkpoint and found it conforming.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/mode-buttons-paint.rkt
```

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
```

```sh
git diff --check
```

Every agent test run includes `TMPDIR=/tmp`, `-j 4`, and `-y`. Do
not commit `compiled/`. The product edit is `.aloe` only and needs no
rebuild before launch. No TTY, timing gate, or hand check is part of
000. The series hand check follows 001 (spec §8).

The checkpoint is complete when:

- both test commands pass and `git diff --check` is clean
- the only product change is `buttons`, `buttons?`, `name-row`, and
  the new body of `row` on `AloemacsModeLine`, plus at most a comment
- `file.aloe` is still ASCII bytes
- the existing-test changes are limited to the 33 files above, and
  each one only respells mode rows of width 7 or more, or retargets
  the one method-shape assertion
- `tests/aloemacs/mode-buttons-paint.rkt` exists and covers the nine
  items above

Report the files changed and the verification output. Then stop.

## Non-goals

- Anything in 001: `label-at`, `press-mode-line`, `select-view`,
  `button-send`, the mode-line arm of `press-at`, and
  `tests/aloemacs/mode-buttons-press.rkt`. A left press on a label
  stays inert. Do not create `checkpoints/001-press.md`.
- The spec's §6.5 paint split. It is not applied; do not create
  `checkpoints/001-split-paint.md`.
- Spec §3's non-goals: drag-to-select, mode `1002`, painting the
  mark, hover, wheel, the middle and right buttons; dragging a
  divider, painting `│` around the labels, or any fourth glyph; a
  click on a path component, the directory browser, describe, jump to
  definition, or a menu; a new command constructor, a keymap change,
  or sending `C-x l`; changing `split-below`, `split-right`, or
  `delete-window`; placing the point from a mode-line press; a new
  face, a per-button color, or a change to LIGHT, DARK, or PLAIN;
  window-bars 001's documents, idle echo, completion, or completion
  page; a display-width table, `wcwidth`, a grapheme rule, or any
  Unicode exception beyond these three code points; a new class, a
  stored mode-line field, a picture field, or an editor field; a Term
  method, a runner change, a new mouse mode, or a change to the mouse
  string; a kernel message, a `SPEC.md` row, a `lib/` method, a Text
  method, or a `CHECKPOINTS.md` entry.
- Do not edit a spec, a charter, a README, or another checkpoint. Do
  not start Boids.
