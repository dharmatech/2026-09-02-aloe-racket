# aloemacs loop specification

**Status.** Design for the local **aloemacs-loop** project. This is not Aloe
language law, a checkpoint, or an implementation assignment. A later
checkpoint-manager conversation will slice `aloemacs-loop 000`, `001`, …
under `checkpoints/`. The authority for Aloe evaluation, checking, classes,
and immutability remains [`SPEC.md`](../../../../../SPEC.md).

This project is the first running aloemacs program: one immutable editor
value owns one `Text` and one point, single keys edit or move that value, and
one pure `frame` send returns the complete `String` written by the injected
Term capability. Files, windows, prefix maps, search, and live evaluation are
later projects.

The implemented aloemacs Text and Term layers are predecessors:
[`../text/spec.md`](../text/spec.md) supplies `Text`, `Position`, `Span`, and
`EditResult`; [`../term/spec.md`](../term/spec.md) supplies `write`,
`columns`, and `rows` in addition to the existing `read-key` and
`write-line`. This project composes those layers without reopening either
public table.

## 1. Scope and invariants

An `AloemacsEditor` is an ordinary immutable Aloe instance. Its `text`,
`point`, and `quit` payloads never change. A key transition returns another
`AloemacsEditor`; it never changes the receiver or its nested `Text` or
`Position`.

The supplied empty starting value satisfies the validity invariant below, and
every editor method preserves it when its receiver satisfies it:

```aloe
((editor text) valid-position? (editor point)) ; => #t
```

The raw class constructor remains an ordinary Aloe constructor and therefore
does not perform validation. Program code and normative tests construct only
valid editors except for the one deliberate failed-edit test in section 8.2.
Every edit method still exhaustively handles `Option`: `Some` rebuilds from
the returned `EditResult`, while an unexpected `None` returns an editor equal
to the receiver. No Option API is added.

Editor text in this layer is treated as printable one-cell characters plus
LF line separators. All layout tests use ASCII, and every character counted
by `String.len` occupies one cell. Tabs, control characters in `Text`,
graphemes, combining characters, and wide Unicode behavior have no special
layout semantics.

### 1.1 Project boundary

The complete new program surface is:

- `examples/aloemacs/editor.aloe` loads `../../lib/text.aloe` and defines the
  editor value and its pure transition and frame behavior;
- `examples/aloemacs/main.aloe` loads `editor.aloe` and defines the empty
  starting binding `aloemacs-editor`;
- `host/racket/aloemacs-run.rkt` injects Term, loads `main.aloe`, and owns the
  iterative session skin;
- focused tests are `tests/aloemacs/editor-keys.rkt`,
  `tests/aloemacs/frame.rkt`, `tests/aloemacs/key-mapping.rkt`, and
  `tests/aloemacs/runner.rkt`.

The only predecessor file this project may need to change is
`host/racket/term.rkt`, solely for the backspace normalization in section 5.
The local `tests/aloemacs/key-mapping.rkt` file owns the added mapping cases;
historical checkpoint tests need no semantic revision. No other Term behavior
or descriptor row changes.

Do not add an editor class to `lib/text.aloe` or a general `lib/editor.aloe`.
Do not change `SPEC.md`, `CHECKPOINTS.md`, Gel, either predecessor spec, the
Term descriptor, or a global checkpoint document.

## 2. Editor value and starting state

The implementation declares exactly this application state class. Field
order and types are normative.

```aloe
(define-class AloemacsEditor
  (fields
    (text Text)
    (point Position)
    (quit Bool))
  (methods ...))
```

Construction is:

```aloe
(AloemacsEditor new text point quit)
```

The fields are the entire persistent state. In particular there is no path,
dirty bit, selection, goal column, key prefix, viewport origin, window, or
host receiver in an editor.

The required command and presentation sends are:

| Send | Result | Meaning |
|---|---|---|
| `(editor insert string)` | `AloemacsEditor` | Insert `string` at point. |
| `(editor newline)` | `AloemacsEditor` | Insert one LF at point. |
| `(editor backward-delete)` | `AloemacsEditor` | Delete the character or LF immediately before point. |
| `(editor move-left)` | `AloemacsEditor` | Move according to section 4. |
| `(editor move-right)` | `AloemacsEditor` | Move according to section 4. |
| `(editor move-up)` | `AloemacsEditor` | Move according to section 4. |
| `(editor move-down)` | `AloemacsEditor` | Move according to section 4. |
| `(editor request-quit)` | `AloemacsEditor` | Preserve text and point and set `quit` to `#t`. |
| `(editor handle-key key)` | `AloemacsEditor` | Dispatch one `read-key` `String` according to section 3. |
| `(editor frame columns rows)` | `String` | Return the complete frame payload in section 6. |

Small helper selectors on this application class are permitted for list
walking, integer clamping, ANSI construction, and row rendering. They do not
add another state representation or another public command vocabulary.

`examples/aloemacs/main.aloe` defines the one initial session binding exactly
as:

```aloe
(define aloemacs-editor
  (AloemacsEditor new
    (Text from-string "")
    (Position new 0 0)
    #f))
```

There is no scratch banner and no initial file operation.

Every command send, including an edge or unknown-key no-op, returns a freshly
constructed `AloemacsEditor` with the required payloads. Aloe has no public
object-identity observation here; the semantic requirement is that no-op
results are structurally equal to the input and the input remains unchanged.
Once `quit` is `#t`, `handle-key` is absorbing: every key returns an equal
quit editor and performs no edit or movement.

## 3. Key dispatch

One `String` returned by `(term read-key)` is one complete command. Dispatch
uses this exact table, with named keys considered before the length-one
insertion fallback:

| Exact key `String` | Command |
|---|---|
| `"return"` | `newline` |
| `"backspace"` | `backward-delete` |
| `"left"` | `move-left` |
| `"right"` | `move-right` |
| `"up"` | `move-up` |
| `"down"` | `move-down` |
| `"escape"` | `request-quit` |
| any `String` whose `(key len)` is `1` | `insert key` |
| every other `String` | no-op |

The Term boundary emits a one-character `String` only for a printable key,
so `handle-key` needs no `Char` class or host character predicate. Synthetic
callers are expected to use the same key domain. In particular `"q"` inserts
the letter q; quit is `"escape"` so ordinary printable letters remain text.

There are no prefixes or modifier maps. Arrow modifiers currently collapse
to the same key name at the Term mapping boundary and therefore have the same
movement behavior in this layer. Unknown named keys such as `"home"`,
`"delete"`, or `"f1"` are equal no-ops and never cause an Aloe or host
error.

## 4. Editing and movement

### 4.1 Successful edits

`insert` sends:

```aloe
((self text) insert (self point) string)
```

and `newline` sends:

```aloe
((self text) newline (self point))
```

For `Some(result)`, both commands construct an editor from `(result text)`,
`(result position)`, and the receiver's `quit` fact. For `None`, they
construct an equal editor from the receiver's existing fields. They do not
derive the new point independently of `EditResult`.

### 4.2 Backward delete

At point `(line, column)`, `backward-delete` has exactly three cases:

1. If `column > 0`, delete the half-open span from
   `(Position new line (column - 1))` to the current point. This removes one
   character and the returned `EditResult.position` becomes the new point.
2. If `column = 0` and `line > 0`, let `previous-length` be the length of line
   `line - 1`. Delete the span from
   `(Position new (line - 1) previous-length)` to the current point. This
   span is exactly the intervening LF, so the two lines join and point becomes
   the old end of the previous line.
3. At `(Position new 0 0)`, return an equal editor.

The first two cases use `(text delete span)` and exhaustively select `Some`
or `None`; no source string is spliced a second time in the editor.

### 4.3 Horizontal movement

- Left with `column > 0` subtracts one from the column.
- Left at column 0 on a non-first line moves to the end of the previous line.
- Left at `(0, 0)` is a no-op.
- Right before end-of-line adds one to the column.
- Right at end-of-line on a non-final line moves to column 0 of the next line.
- Right at the end of the final line is a no-op.

Thus left and right traverse the LF boundary without editing it. They always
produce a valid `Position`.

### 4.4 Vertical movement

- Up on the first line is a no-op. Otherwise it moves to the previous line at
  `min(current-column, previous-line-length)`.
- Down on the final line is a no-op. Otherwise it moves to the next line at
  `min(current-column, next-line-length)`.

There is no remembered goal column. A later vertical move uses the editor's
current, possibly clamped, column. All movement preserves the exact result of
`(text to-string)` and preserves `quit`.

## 5. Term key normalization

Return and every arrow already reach Aloe through
`tkeymsg->aloe-key`: Return is `"return"`, and the `tui-term` symbols `up`,
`down`, `left`, and `right` pass through `symbol->string` with those exact
spellings. No Term change is needed for them.

A physical Backspace commonly reaches the current `tui-term` decoder as the
non-printable key character `#\rubout` (U+007F), which the present mapping
rejects as `unsupported key`. This project makes the smallest required
mapping change. Before the printable-character cases,
`tkeymsg->aloe-key` maps each of these decoded forms to the one Aloe string
`"backspace"`:

```racket
(make-tkeymsg 'backspace)
(make-tkeymsg #\backspace)
(make-tkeymsg #\rubout)
(make-tkeymsg #\h '(ctrl) #f)
```

The symbolic case covers a named decoder result, the two control characters
cover direct BS and DEL spellings, and the final form covers `tui-term`'s
decoded control-H shape. Modifiers otherwise retain their current treatment.
`tkeymsg->aloe-key` otherwise retains its current behavior, including the
error for unsupported non-printable, non-symbolic keys. This is not a new Term
method, crossing type, or event variant.

Focused mapping tests construct `tkeymsg` values for all four backspace forms
and for all four arrow symbols and assert the exact strings above. They also
retain the existing Return, Escape, printable, and unknown-symbol behavior.

## 6. Frame and viewport

`(editor frame columns rows)` is pure and returns one `String`. `columns` and
`rows` must be positive; the production Term capability guarantees that
precondition, and normative tests use positive dimensions. The send does not
receive or access `term`, does not write output, and does not modify editor
state.

There is no stored viewport. Each frame derives a point-anchored origin:

```text
top  = max(0, point.line   - (rows    - 1))
left = max(0, point.column - (columns - 1))
```

The vertical body contains source lines `top` through `top + rows - 1`.
Lines before `top` and after that interval are clipped. If the `Text` has no
source line for a requested screen row, that screen row is empty.

Every displayed source line uses the same horizontal origin and is exactly:

```aloe
((line drop left) take columns)
```

Characters before `left` and after the resulting prefix are clipped. There
is no wrapping. The formulas guarantee that point maps to a visible terminal
cell even at end-of-line:

```text
cursor-row    = point.line   - top  + 1
cursor-column = point.column - left + 1
```

Both cursor coordinates are one-based and fall within the supplied positive
dimensions. Scrolling is derived afresh from point; moving back toward the
upper-left may therefore move `top` or `left` back toward zero immediately.

### 6.1 Exact frame bytes

The frame concatenates these parts in order, with no other bytes:

1. `"\u001b[?25l"` — hide the cursor;
2. `"\u001b[2J"` — clear the screen;
3. `"\u001b[H"` — move to home;
4. exactly `rows` rendered row strings, joined by `"\r\n"` with no CRLF
   after the final row;
5. `"\u001b["`, decimal `cursor-row`, `";"`, decimal `cursor-column`, and
   `"H"` — place the cursor at point; and
6. `"\u001b[?25h"` — show the cursor.

Decimal coordinates use the existing `(Int text) -> String` behavior already
used by Gel. ANSI is ordinary Aloe string construction; no terminal-control
host selector or Racket renderer is added. Clearing first means short and
empty rows need no space padding. The body always has exactly `rows` logical
rows even when its final row contributes no characters.

The complete frame is passed to `(term write frame)` once. The editor loop
never sends `write-line`.

### 6.2 Normative 8 by 4 frames

Vertical clipping for:

```aloe
(AloemacsEditor new
  (Text from-string "zero\none\ntwo\nthree\nfour\nfive")
  (Position new 5 4)
  #f)
```

at 8 columns by 4 rows returns exactly:

```text
\u001b[?25l\u001b[2J\u001b[Htwo\r\nthree\r\nfour\r\nfive\u001b[4;5H\u001b[?25h
```

Horizontal clipping for text `"0123456789"` at point `(0, 10)` and the same
size returns exactly:

```text
\u001b[?25l\u001b[2J\u001b[H3456789\r\n\r\n\r\n\u001b[1;8H\u001b[?25h
```

The displayed forms above spell ESC as `\u001b`; the resulting Aloe strings
contain the single ESC character. These examples prove vertical clipping,
horizontal scrolling, blank rows, and a visible point without a TTY.

## 7. Iteration and runner

Iteration is a Racket `let`/named loop in
`host/racket/aloemacs-run.rkt`, not recursive Aloe. This avoids making stack
overflow the normal lifetime limit of an editor session. The editor state and
all edit, movement, viewport, and ANSI policy remain Aloe values and methods;
the runner is only the effect and iteration skin.

The module provides `run-aloemacs` and `run-aloemacs-with-term`.
`run-aloemacs` uses `call-with-tty-term-receiver` and passes that receiver to
`run-aloemacs-with-term`. The latter performs exactly this setup:

1. make one checked driver;
2. inject the supplied receiver as `term` with `driver-inject-host!`; and
3. load `examples/aloemacs/main.aloe` with `driver-load-file!`.

It then repeats this sequence while the current editor is not quit:

```aloe
(term write
  (aloemacs-editor frame (term columns) (term rows)))

(define aloemacs-editor
  (aloemacs-editor handle-key (term read-key)))

(aloemacs-editor quit)
```

The first expression reads both dimensions anew and performs exactly one
flushing `term write`. The second reads exactly one key and rebinds the
driver's session name to the newly returned immutable Aloe editor. The third
is the loop condition. A quit transition ends the runner without drawing a
second frame. This top-level session rebinding is runner bookkeeping; it does
not mutate an editor or `Text` instance and does not move application policy
into Racket.

The runner contains no key table, text operation, movement calculation,
viewport calculation, or ANSI literal. It does not call Aloe evaluator
internals directly, add a second runtime environment, use `write-line`, or
change either Gel runner. Its main-module error handling may match
`gel-run.rkt`, with the diagnostic prefix `aloemacs`.

`run-aloemacs-with-term` exists so a no-TTY test can inject an ordinary
`make-term-receiver` double whose first key is `"escape"`, whose size is 8 by
4, and whose output is a string port. That run writes exactly the initial
empty frame, reads one key, and returns without opening a physical terminal.

## 8. Required tests

All new tests live under `tests/aloemacs/`, use the ordinary checked driver,
and require no physical TTY. Their names do not reuse Text's `000` through
`003` or `term-capability.rkt`. Pure editor and frame tests are the first
consumer and must be green before the runner is introduced.

### 8.1 Checked surface

`editor-keys.rkt` loads `examples/aloemacs/editor.aloe` through a checked
driver and proves the class field types, constructor, command result types,
`handle-key : (String) -> AloemacsEditor`, and
`frame : (Int Int) -> String`. A fresh driver still has none of the editor
bindings until it loads the file. The source load brings in `lib/text.aloe`
through its relative `load`; tests do not duplicate those definitions.

### 8.2 Editing, quit, no-op, and immutability

At minimum `editor-keys.rkt` proves:

- `"x"` in the empty editor produces text `"x"` at `(0, 1)`;
- `"return"` after `"a"` produces text `"a\n"` at `(1, 0)`;
- `"backspace"` at `(0, 2)` in `"ab"` produces `"a"` at `(0, 1)`;
- `"backspace"` at `(1, 0)` in `"ab\ncd"` produces `"abcd"` at
  `(0, 2)`;
- `"backspace"` at `(0, 0)` is an equal no-op;
- `"escape"` sets `quit` to `#t` without changing text or point, and a
  subsequent key is an equal no-op;
- an unknown named key such as `"home"` is an equal no-op and raises no
  host or Aloe error;
- on a deliberately invalid raw editor, a length-one insertion whose Text
  operation returns `None` produces an equal editor, proving the exhaustive
  failure branch; and
- after every send above, the original editor's text, point, and quit fields
  still have their original values.

Tests select `Some` with `case`; neither production source nor tests add an
Option unwrap helper.

### 8.3 Movement

Movement tests cover all four directions, including:

- left from column 0 to the previous line's end;
- right from end-of-line to the next line's column 0;
- left at the beginning and right at the final end as no-ops;
- up and down preserving a column when it fits;
- up and down clamping to a shorter target line; and
- a second vertical move starting from the clamped column, proving there is
  no remembered goal column.

Every movement assertion also proves `(text to-string)` is unchanged and the
new point satisfies `valid-position?`.

### 8.4 Frame

`frame.rkt` asserts the two complete 8 by 4 strings in section 6.2, plus the
empty editor's complete 8 by 4 frame. It proves:

- the frame result type is `String` and no Term receiver is injected;
- the body has the required clipping, CRLF separators, and empty rows;
- the final cursor address is within the supplied dimensions and identifies
  point after vertical and horizontal scrolling;
- the cursor is hidden before drawing and shown after its final address; and
- calling `frame` leaves text, point, and quit unchanged.

### 8.5 Mapping and runner

`key-mapping.rkt` proves the exact mappings in section 5 without a TTY.

`runner.rkt` calls `run-aloemacs-with-term` with a string output port, an
injected reader that returns `"escape"`, and an 8 by 4 size reader. It proves
one key read, one size query per dimension, and exactly one initial empty
frame in the output. It does not call `call-with-tty-term-receiver`.

The full existing test suite, including all Text, Term, and Gel tests, must
remain green.

## 9. Acceptance

The design is implemented when all of the following are true:

1. `AloemacsEditor` has exactly the persistent fields and starting state in
   section 2, and every transition preserves the validity and immutability
   invariants.
2. The exact key strings in section 3 produce the editing, movement, quit,
   and no-op behavior in sections 3 and 4. No prefix or host keymap exists.
3. Backspace, Return, and arrow keys reach those strings through the existing
   Term mapping with only the small normalization in section 5.
4. `frame` is pure and returns the exact payload defined in section 6,
   including derived clipping/scrolling and a visible cursor at point for
   positive sizes.
5. The runner performs only the checked setup and three-expression iteration
   in section 7; editor semantics and ANSI construction remain in Aloe.
6. The checked, no-TTY tests in section 8 pass, and existing non-aloemacs and
   predecessor tests remain green.
7. No language feature, Text public method, Term descriptor method, alternate
   editor representation, or application feature outside this specification
   has been added.

## 10. Explicit non-goals

- Loading, visiting, saving, paths, Fs, encoding, CRLF file conversion,
  final-newline policy, or dirty state
- Multiple buffers, windows, splits, a status line, mode line, scratch
  banner, minibuffer, or remembered viewport
- Prefix keys, `C-x`, modifier-aware maps, `M-x`, configurable bindings, or a
  general keymap value
- Search, replace, undo, marks, selection, kill ring, indentation, syntax, or
  modes
- Goal columns, tabs as columns, wrapping, grapheme segmentation, `wcwidth`,
  or correct wide-Unicode display
- Mouse, paste, PTY, resize events as keys, polling, alternate-screen policy,
  or a VT emulator
- `Mirror`, evaluating buffer text, live eval, hot reload, or a port of
  Legmacs `main.lg`, `render.lg`, or `dispatch.lg`
- Host mutation of editor state, Racket implementations of edit/movement or
  ANSI policy, a new Term method, or changes to `write-line`
- Changes to Gel, `lib/text.aloe`, the language specification, global
  checkpoints, or work under `docs/editor/`
