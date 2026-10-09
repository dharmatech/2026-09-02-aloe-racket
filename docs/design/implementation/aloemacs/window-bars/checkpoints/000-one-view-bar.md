# aloemacs-window-bars 000 — One-view bar

**Status: Ready to implement.** Human review of this checkpoint precedes
its implementation.

If you have been told to read this file, it is the whole assignment.
Read the accepted spec sections named below, implement this slice,
and stop when green.

## Goal

Add the `bar` send to `AloemacsModeLine`. Paint the name row of a tall
one-view frame, and of the too-small-tree fallback, as the lighter bar:
LIGHT, the visible name row, then PLAIN. Text rows, completion rows, and
the echo row stay outside the bar.

Short one-view frames and direct editor frames keep their bytes. Every
split frame keeps today's bytes: plain leaf name rows, the `-` / `+` rule
row, and the `|` column. Below division, the below split minimum, fit,
cursor, and echo do not change. They belong to 001.

Migrate the existing one-view and fallback goldens. Stop when the focused
proof and the full aloemacs suite pass.

## Authority, identity, and starting point

The implementer receives this checkpoint and the accepted spec. The
checkpoint narrows the spec to one slice. It does not revise it.

- Identity: **aloemacs-window-bars 000**, filed as
  `checkpoints/000-one-view-bar.md`. This is a local editor checkpoint.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../../workflow.md), root
  [AGENTS.md](../../../../../../AGENTS.md),
  [SPEC.md](../../../../../../SPEC.md), and
  [CHECKPOINTS.md](../../../../../../CHECKPOINTS.md) before product
  edits. `SPEC.md` remains Aloe language law. Evaluation is send with a
  literal selector. Function objects run only through `call`.
- The accepted [../spec.md](../spec.md) governs:
  - §§1–2: predecessors, authority, the file boundary, exact shapes, and
    non-goals.
  - §3: the bar, its sequences, the `bar` send, paint order, and where
    PLAIN sits. In 000 only the one-view and fallback bar is painted,
    and it is always LIGHT.
  - §6: this layer, including its examples, migration rule, and focused
    proof.
  - §8: the 000 verification commands.

  §4, §5, and §7 describe the finished series and 001. In 000, Below
  geometry, the split minimum, fit, cursor, echo, and split composition
  stay exactly as they are in the current tree. Predecessor specs named
  in spec §1.1 govern preserved behavior.

### Current tree

Start from [file.aloe](../../../../../../examples/aloemacs/file.aloe).
Line numbers are approximate.

- `AloemacsModeLine` (near line 251) is declared after `AloemacsBuffers`
  and before `AloemacsView`, with `(fields)`. It has `row (name width)`,
  which returns the accepted spelling, and `fill (remaining)`.
- Session `frame` sends `single-frame` when the tree is a single leaf or
  when `positive-layout?` of the root is false. Otherwise it sends
  `multi-frame`. The too-small-tree fallback is therefore `single-frame`.
- `single-frame` (near line 1663) builds `editor frame columns
  (root text-rows)` as its prefix. At `rows < 2` it returns that prefix.
  Otherwise it appends the following, in order:
  1. `ESC[?25l`
  2. `ESC[h;1H` with `(editor safe-cells ((AloemacsModeLine new) row
     ((self current-buffer) name) columns))`, only when `root.rows >= 2`
  3. `completion-frame`
  4. `ESC[rows;1H` and `echo-row(columns, root.rows)`
  5. the final cursor and `ESC[?25h`
- `multi-frame` and the tree's `frame-rows` paint split leaves. A tree
  leaf paints its name row through `(editor safe-cells ((AloemacsModeLine
  new) row ...))`. Below rows go through `below-divider`. Right rows go
  through `right-rows`. **None of this changes in 000.**
- `root-rect`, `completion-row-count`, `completion-frame`, and
  `echo-row` are as described in spec §1.2.

## Exact file scope

### May create or edit

- `examples/aloemacs/file.aloe`, in exactly two places:
  1. `AloemacsModeLine` gains `bar`. It may also gain zero-argument
     helper methods that return the three sequence Strings. Aloe has no
     visibility modifier. The spec's "private" means that only
     `AloemacsModeLine`'s own methods send them.
  2. `single-frame`'s name-row piece sends the safe row through
     `bar ... #t`. You may adjust the comment directly above
     `single-frame` to mention the bar.
- Create `tests/aloemacs/window-bars-one-view.rkt` before the product
  edit, and watch it fail.
- The **30 existing test files** below, only to wrap a one-view or
  fallback name row. Paths are relative to `tests/aloemacs/`. Line
  numbers are approximate.

  | File | Wrap here | Leave plain |
  |---|---|---|
  | `buffer-session.rkt` | `frame` helper's `mode-row` piece (near 453) | |
  | `buffer-value.rkt` | `frame` helper's `mode-row` piece (near 460) | |
  | `completion-frame.rkt` | `single` helper's `mode` piece (near 123); one-view literals near 283, 440, 451 | `leaf-cells`, `multi`, height-two literals near 439 and 455 |
  | `completion-page-frame.rkt` | `single` helper's `mode` piece (near 125); one-view literal near 164 | `leaf-cells`, `multi` |
  | `completion-session.rkt` | `frame` helper (near 166); the one-view branch of the inline `prefix` (near 698) | the split branch of that `prefix` (`"unti|unti"`) |
  | `echo-runner.rkt` | `frame` helper (near 27) | |
  | `echo-session.rkt` | `session-frame` helper (near 114) | |
  | `file-runner.rkt` | the four literal frame constants (near 17–26) | |
  | `file-session.rkt` | the literal expected frame (near 546) | |
  | `idle-echo.rkt` | `single` helper's `mode` piece (near 49) | `mode` inside split `lines` lists (near 132, 140), `multi` |
  | `keymap-prefix.rkt` | `frame` helper (near 156) | |
  | `keymap-runner.rkt` | `frame` helper (near 28) | |
  | `minibuffer-session.rkt` | `frame` helper (near 174) | |
  | `minibuffer-value.rkt` | `frame` helper (near 155) | |
  | `mode-line-one-view.rkt` | `frame` helper's `name-row` piece (near 59) | `direct` |
  | `mode-line-split-views.rkt` | `single` helper's `mode` piece (near 95) | leaf rows (near 84), `multi` |
  | `prompt-commands-find-file.rkt` | `frame` helper (near 149); `runner-frame` reaches it | |
  | `prompt-commands-save-as.rkt` | `frame` helper (near 161); `runner-frame` reaches it | |
  | `prompt-commands-select-buffer.rkt` | `frame` helper (near 153); `runner-frame` reaches it | |
  | `runner.rkt` | the literals near 98 and 101 | |
  | `runner-check.rkt` | `frame` helper (near 134) | |
  | `safe-cells.rkt` | `session-frame` helper (near 57) | |
  | `search-session.rkt` | `frame` helper (near 108) | |
  | `viewport-runner.rkt` | `complete-frame` helper (near 30); literals near 148 and 150 | |
  | `windows-delete-and-other.rkt` | `single` helper (near 126) | every split golden |
  | `windows-layout-and-rendering.rkt` | `single` helper (near 116) | every split golden |
  | `windows-lock.rkt` | `single` helper (near 126) | every split golden |
  | `windows-split.rkt` | `single` helper (near 126) | every split golden |
  | `windows-state-foundation.rkt` | `ansi` helper (near 446) | |
  | `windows-state.rkt` | the one-view literal near 591 | |

**How this list was found.** The manager applied exactly this slice's
two product edits to a scratch copy of the tree and ran the aloemacs
suite. It reported 90 failures in exactly these 30 files. Each failure's
actual String equals its expected String once LIGHT and PLAIN are
removed. A test case stops at its first failure, so the sites above show
where to start. They are not a complete line list. Search each file
again for one-view and fallback name rows.

No migration was found in `completion-page-session.rkt`,
`windows-buffer-identity.rkt`, `mode-line-row.rkt`, `keymap-session.rkt`,
`kill-session.rkt`, `undo-session.rkt`, or any other file. They must pass
unedited.

### Must leave untouched

- In `file.aloe`: `multi-frame`, the tree's `frame-rows`, `right-rows`,
  `below-divider`, `horizontal-divider?`, `vertical-divider?`,
  `blank-rows`, `AloemacsWindowRect` (`top`, `bottom`, `left`, `right`,
  `divider-row`, `divider-column`, `text-rows`), the windows' split
  checks, `fit-rect`, `ensure-visible`, `root-rect`,
  `completion-row-count`, `completion-frame`, `echo-row`, and `frame`'s
  routing. Do not change the two loads or the order of declarations.
- `examples/aloemacs/editor.aloe`, `examples/aloemacs/main.aloe`,
  `host/racket/aloemacs-run.rkt`, `host/racket/term.rkt`, `lib/`, `aloe/`,
  `SPEC.md`, and `CHECKPOINTS.md`. Add no dependency, load, host
  capability, runner argument, or build step.
- Shapes. `AloemacsEditor` keeps its eight fields and gains no method.
  The session keeps fourteen fields, the buffer three, the view five,
  the rectangle four, and the windows four. `AloemacsModeLine` keeps
  `(fields)` and its position. Add no class, constructor, command, key,
  keymap entry, or Term method. `row` and `fill` keep their results.
- Every existing test not named above. Create no shared helper module
  and no split-focused test. Do not create `window-bars-split.rkt`.
- Every document: this checkpoint, `spec.md`, `charter.md`, and
  `README.md` in this folder; predecessor and neighbor documents; and the
  parent `aloemacs/README.md`, `discussion.md`, and `explorations.md`.
  The parent files may carry uncommitted edits from the discussion.
  Leave them exactly as you find them.

If another file, a fixture change, a fit change, or a geometry change
seems necessary, stop and report it. Do not widen this checkpoint.

## Required behavior

### 1. The `bar` send

The bar uses three ANSI Strings. ESC is U+001B, written `\u001b` in Aloe
and `\e` in Racket test strings.

| Name | Aloe spelling | Meaning |
|---|---|---|
| LIGHT | `"\u001b[38;5;16;48;5;250m"` | black on grey 250 |
| DARK | `"\u001b[38;5;252;48;5;239m"` | grey 252 on grey 239 |
| PLAIN | `"\u001b[0m"` | reset to default attributes |

Add this method to `AloemacsModeLine`:

```aloe
(bar (row String) (selected? Bool) String
  ...)
```

```text
bar(row, selected?) = ""                      when row.len = 0
                    = LIGHT ++ row ++ PLAIN   when selected?
                    = DARK  ++ row ++ PLAIN   otherwise
```

`bar` is a pure display send. It does not clip, pad, inspect `row`, or
apply safe cells, and it performs no effect. Store no `AloemacsModeLine`
on the session, buffer, editor, or view. No other class gains a bar
method. DARK is implemented and proved in 000, but no 000 frame paints
it.

### 2. The one-view and fallback frame

In `single-frame`, paint the name row in this order:

```text
raw   = (AloemacsModeLine new) row name columns   ; unchanged spelling
shown = editor safe-cells raw                     ; unchanged
paint = (AloemacsModeLine new) bar shown #t
```

Safe cells sees only the name row, never the sequences. A name holding
ESC cannot open, close, or recolor the bar. `selected?` is the literal
`#t`, because the one-view frame and the fallback always paint their
single bar LIGHT (spec §3.4). An active prompt, search, or completion
list does not change it.

With `h = root.rows` and `t = root.text-rows`, a frame at `rows >= 2` and
`h >= 2` is:

```text
editor.frame(columns, t)
ESC[?25l
ESC[h;1H LIGHT shown PLAIN
completion rows                        unchanged; only when painted
ESC[rows;1H shown-echo
ESC[final-row;final-columnH ESC[?25h
```

The spaces and line breaks above separate pieces and add no bytes. PLAIN
comes right after the bar's last visible cell, before any list-row
address, the echo address, or the cursor address. Every other byte stays
as it is today.

- At `rows < 2`, `single-frame` returns today's complete body.
- At `rows >= 2` with `h < 2`, it keeps today's bytes and contains no
  sequence. This includes a root shortened to one row by a completion
  list.
- The too-small-tree fallback composes through `single-frame`, so its
  bar is LIGHT with no further change.
- `multi-frame` and the tree's composition stay exactly as they are.
  000 never paints a colored bar above a dash rule, because the fallback
  draws no dividers.

Frame stays pure. It never fits, remembers a size, changes point,
installs a focus or an origin, or writes a token. The runner still fits,
then frames, then writes one String per drawn iteration.

### 3. Exact examples

These are spec §6.2. The manager checked each one against the scratch
probe.

An empty untitled buffer, 12 columns by 4 rows, idle:

```text
today: "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1Huntitled ---\e[4;1H\e[1;1H\e[?25h"
000:   "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[1;1H\e[?25h"
```

Untitled text `zero\none\ntwo\nthree`, point at line 3, column 0, fitted
at 12 by 4 (origin row 2):

```text
000:   "\e[?25l\e[2J\e[Htwo\r\nthree\e[2;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250muntitled ---\e[0m\e[4;1H\e[2;1H\e[?25h"
```

The empty buffer at width 1, 4 rows:

```text
000:   "\e[?25l\e[2J\e[H\r\n\e[1;1H\e[?25h\e[?25l\e[3;1H\e[38;5;16;48;5;250mu\e[0m\e[4;1H\e[1;1H\e[?25h"
```

Short frames keep today's bytes:

```text
12 by 2: "\e[?25l\e[2J\e[H\e[1;1H\e[?25h\e[?25l\e[2;1Huntitled\e[1;1H\e[?25h"
12 by 1: "\e[?25l\e[2J\e[H\e[1;1H\e[?25h"
```

`bar` examples, from spec §3.2. Quotes delimit visible cells.

| Name | Width | `selected?` | Painted |
|---|---|---|---|
| `"/a"` | 4 | `#t` | LIGHT `"/a -"` PLAIN = `"\e[38;5;16;48;5;250m/a -\e[0m"` |
| `"/a"` | 4 | `#f` | DARK `"/a -"` PLAIN = `"\e[38;5;252;48;5;239m/a -\e[0m"` |
| `"untitled"` | 12 | `#t` / `#f` | LIGHT / DARK `"untitled ---"` PLAIN |
| `"untitled"` | 1 | `#t` / `#f` | LIGHT / DARK `"u"` PLAIN |
| `"untitled"` | 0 | either | `""`, not a painted row |
| `"a\u001b[31m"` | 8 | `#t` | LIGHT `"a [31m -"` PLAIN (after safe cells) |

## Tests

### Focused proof: `tests/aloemacs/window-bars-one-view.rkt`

Write this file first and watch it fail. It needs no TTY. Use the
checked driver, `rackunit`, counted Fs doubles, and a scripted Term
double, following the patterns in `mode-line-row.rkt` and
`mode-line-one-view.rkt`. Copy any helper you need into this file. Do
not `require` another test module.

Expected Strings use test-local literals for LIGHT, DARK, and PLAIN, plus
independently computed visible rows. Never build an expectation by
sending `bar`, `row`, `frame-rows`, or a session composer. Keep
whole-frame assertions.

Prove:

1. **Types and shapes.** `((AloemacsModeLine new) bar "x" #t)` is typed
   `String`. Checking rejects:
   - wrong arity: zero, one, and three arguments
   - an Int row
   - a String or Int `selected?`
   - a wrong receiver, such as `("x" bar "x" #t)`

   A fresh checked load of `file.aloe` needs no Fs or Term and has no
   output or effect. The `file.aloe` class list and order, the two
   loads, `AloemacsModeLine`'s `(fields)`, and every field inventory
   listed above are unchanged.
2. **`bar` values.** Cover:
   - every example in the `bar` table above
   - both selections at width 1 and with fill
   - the empty row and an empty name (`" ---"` at width 4)
   - controls inside and beyond the clip, through the paint order
     raw → `safe-cells` → `bar`: ESC followed by `[31m`, tab, CR, LF,
     and DEL

   Also prove that `bar` alone passes a control through unchanged. For
   each case, assert the exact painted String. Separately assert its
   visible row (the String with every LIGHT, DARK, and PLAIN removed)
   and that row's width.
3. **Complete one-view frames.** Cover widths 1, narrow, and wide; empty,
   text, and blank-row buffers; untitled and bound names; nonzero
   vertical and horizontal origins; saved, failed, idle, search, and
   prompt echo states; and a painted completion list. Each frame has
   exactly one LIGHT, one PLAIN, and no DARK. List-row addresses and the
   echo address come after PLAIN. The editor frame prefix is exact.
   Include the three `000:` examples above byte for byte.
4. **Short frames.** Terminal heights one and two, and a root shortened
   below two rows by a completion list (for example 12 by 4 with two or
   more completion lines), keep today's complete bytes with no
   sequence. Direct editor `frame` and `frame-ansi` Strings are
   unchanged and contain no sequence.
5. **Fallback.** A too-small tree at root height two or more frames
   exactly as the one-view frame for the selected buffer, with one
   LIGHT bar. Cover the case where the selected leaf alone is positive.
   At root height one it keeps today's bytes. Growth restores today's
   split frame, with its `-` rule row and no sequence. The tree,
   selection, locks, and inactive origins persist.

   Build the fallback from a zero axis that 001's Below division keeps:
   a Right below three columns, or a Below at extent one. For example,
   `Below(Right(v0, v1), v2)` at width 2 falls back through the Right,
   and at 9 by 6 it shows a rule row. Do not rely on a Below at extent
   two. 001 makes that layout positive, and 001 may change this file
   only where it asserts today's split frames.
6. **Splits and prompts.** A positive split frame, both Below and Right,
   equals an independent expectation of today's bytes, with plain name
   rows, the rule row, and no sequence. A one-view active prompt keeps
   the LIGHT bar and puts the cursor on the echo row.
7. **Purity and runner.** Framing twice, and at another size, leaves the
   session unchanged and has no Fs or Term effect. Then drive the
   production runner through `run-aloemacs-with-hosts` with a scripted
   `make-term-receiver` and a counted Fs. It must fit, frame, and write
   once before each read. Resize from tall to short and back. Save and
   quit. Assert the exact event list, including full frame Strings, and
   the exact read and write counts.

### Migration of existing files

Apply this rule to the 30 files in the table:

- **Wrap at the one-view or fallback call site.** For example, use
  `(string-append LIGHT (mode-row name width) PLAIN)` inside the one-view
  helper. Keep `mode-row`, `mode`, and `name-row` returning visible cells
  only. Several files share that function with split leaf rows, and
  split rows must stay plain in 000.
- **Wrap only a non-empty visible row.** An empty row stays `""`, as
  `bar` returns it. This matters for helpers whose `#:width` defaults to
  0.
- **Literal goldens.** Insert LIGHT immediately before the visible name
  row and PLAIN immediately after it. Change no other byte.
- **Keep everything else byte for byte.** That includes every
  split-frame expectation, rule row, Below rectangle, fit result, page
  result, refusal, and Fs/Term assertion. Do not turn a whole-frame
  assertion into a substring check.

A failure that differs by anything other than LIGHT and PLAIN around a
one-view or fallback name row is a stop condition. Report it. Do not
edit a fixture, geometry, or another expectation to force the suite
green.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs/window-bars-one-view.rkt
TMPDIR=/tmp raco test -j 4 -y tests/aloemacs
git diff --check
```

Every agent test run includes `TMPDIR=/tmp`, `-j 4`, and `-y`. Do not
commit `compiled/`. The product edit is `.aloe` only and needs no rebuild
before launch. No TTY, timing gate, or hand check is part of 000. The
series hand check follows 001 (spec §8).

The checkpoint is complete when:

- both commands pass and `git diff --check` is clean
- the only product change is `bar` (and any sequence helpers) on
  `AloemacsModeLine` plus the wrapped name row in `single-frame`
- the existing-test changes are limited to the 30 files above, and each
  one only wraps a one-view or fallback name row

Report the files changed and the verification output. Then stop.

## Non-goals

- Anything in 001: Below division, the four-row below minimum, bars on
  split leaves, DARK in a frame, the selected argument to `frame-rows`,
  and removing the rule row, the `+` junction, or the divider helpers.
  Do not create `checkpoints/001-split-bars.md` or
  `window-bars-split.rkt`.
- Spec §2's non-goals: line-drawing characters; faces or span
  attributes; recoloring buffer text, the echo row, the prompt, or a
  completion list; mode names, dirty marks, readouts, or badges;
  terminal color detection; stored format strings; Right allocation,
  lock, or echo changes; kernel messages; mutation, inheritance,
  macros, or new special forms.
- Do not edit a spec, a charter, a README, or another checkpoint. Do not
  start faces, language modes, or Boids.
