# aloemacs-loop 001 — Pure frame and viewport

**Status.** Ready to implement.

## Goal

Add the pure full-screen presentation send to the reviewed immutable
`AloemacsEditor`. `(editor frame columns rows)` derives a point-anchored
viewport, clips source lines without wrapping or padding, and returns the
complete ANSI `String` for one later `(term write ...)`.

This checkpoint completes frame construction without introducing effects.
Stop when it is green. Do not normalize physical keys, define the starting
`aloemacs-editor` binding, inject Term, write output, or create the iterative
runner.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-loop, 001)`, spoken **aloemacs-loop 001**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is language law,
  especially send evaluation, typed immutable classes, `define-methods`,
  parallel `let`, `if`, exact `Int`, `String` messages, and List folds.
  Evaluation is send, not apply: the head of a list is the receiver and its
  second element is the literal selector. A function object runs only through
  `(f call ...)`.
- [`../spec.md`](../spec.md), especially sections 1, 2, 6, 6.1, 6.2, 8.1,
  and 8.4, is the local design authority. This checkpoint implements only the
  pure frame and derived viewport behavior.
- **aloemacs-loop 000** is implemented and reviewed. Preserve its exact
  `AloemacsEditor` fields, edit/movement/quit/key semantics, helper methods,
  source-relative Text load, focused tests, and all immutability invariants.
- **aloemacs-text 000–003** and **aloemacs-term 000** remain reviewed
  predecessors. This checkpoint reads Text through its public messages but
  does not edit Text or use Term.

Do not add a special form, mutation, inheritance, macro, implicit numeric
coercion, host crossing, alternate evaluator, or presentation behavior in
Racket.

## Starting point

`examples/aloemacs/editor.aloe` already:

1. source-relatively loads `../../lib/text.aloe`;
2. declares `AloemacsEditor` with exactly `text : Text`,
   `point : Position`, and `quit : Bool`; and
3. implements the reviewed checkpoint-000 commands plus the pure
   `line-length` and `clamp-column` helpers.

`tests/aloemacs/editor-keys.rkt` contains 13 reviewed test cases. Its checked
surface deliberately records that `frame` is absent in checkpoint 000. That
single expectation is now obsolete. Update only the frame signature/arity
portion of that test; retain every existing load, field, transition,
invariant, no-op, and immutability assertion.

There is still no `examples/aloemacs/main.aloe`,
`host/racket/aloemacs-run.rkt`, `tests/aloemacs/key-mapping.rkt`, or
`tests/aloemacs/runner.rkt`.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe`
- `tests/aloemacs/frame.rkt` (new)
- `tests/aloemacs/editor-keys.rkt`, only to replace the superseded
  frame-absent assertions with the exact checked `frame` signature and its
  wrong-arity/wrong-type rejections; preserve all other coverage

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- `lib/text.aloe`, `lib/string.aloe`, `lib/list.aloe`, any other library, or
  any file under `aloe/` or `bin/`
- `host/racket/term.rkt`, any other host file, package metadata, or `tui-term`
- `examples/aloemacs/main.aloe`, any Gel source or runner, or another example
- any test except the exact two test files listed under **May edit**
- the aloemacs maps, charters, specifications, or earlier checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## Public send and purity

Extend the existing `AloemacsEditor` with exactly this presentation
signature:

```aloe
(frame (columns Int) (rows Int) String
  ...)
```

It may be added by appending `define-methods AloemacsEditor` or within the
existing declaration, provided no reviewed method changes behavior.

`columns` and `rows` have the design precondition that both are positive.
Production Term already guarantees it, and every test in this checkpoint
uses positive dimensions. Do not invent zero/negative-size behavior, an
Option result, clamping dimensions, or a host error contract.

`frame`:

- returns one `String`;
- reads only its `columns`, `rows`, and receiver fields;
- does not receive, look up, reflect, or send to `term`;
- does not write or flush output;
- does not edit Text, move point, change quit, or construct a replacement
  editor; and
- returns the same bytes for equal text, point, and dimensions regardless of
  the editor's quit fact.

Calling it leaves the receiver's exact Text source, Position fields, and quit
fact unchanged.

Small pure helper selectors on `AloemacsEditor` are permitted for list
walking, selecting a source line or `""`, rendering the requested screen
rows, integer max-at-zero, and ANSI concatenation. They must not add fields,
another class, a top-level binding, stored viewport state, or another public
presentation command. Tests do not depend on helper names.

## Derived viewport

There is no stored viewport. For each call, bind the receiver's point and
derive:

```text
top  = max(0, point.line   - (rows    - 1))
left = max(0, point.column - (columns - 1))
```

Because Aloe `let` bindings are parallel, use nested `let` forms when a later
calculation refers to `point`, `top`, `left`, or another local. Do not rely on
sequential binding behavior.

The vertical body has exactly `rows` logical screen rows. Screen row zero
uses source line `top`, row one uses source line `top + 1`, and so on through
source line `top + rows - 1`.

- A requested source line that exists uses that line's exact String.
- A requested source line beyond `((self text) lines)` is `""`.
- Source lines before `top` and after the requested interval do not appear.
- No source String, line List, or Position is changed.

Every body row uses the one shared `left` value and is exactly:

```aloe
((line drop left) take columns)
```

This order is normative. Characters before `left` and after the first
`columns` remaining characters are clipped. Do not wrap, pad with spaces,
truncate based on another line's length, or give each line its own horizontal
origin.

The implementation may recursively walk a `(List String)` and an `Int` index
to return the requested source line or `""`, and may recursively render a
positive remaining-row count. Such recursion is an ordinary Aloe method send.
Do not add List indexing, a range class, a new String/List method, or a
parallel Racket renderer.

## Cursor coordinates

After deriving `top` and `left`, calculate:

```text
cursor-row    = point.line   - top  + 1
cursor-column = point.column - left + 1
```

Coordinates are one-based. For a valid editor and positive dimensions, the
formulas keep both coordinates within the requested terminal rectangle,
including when point is at end-of-line.

Convert each coordinate using the existing `(Int text) -> String` message.
Do not write decimal conversion tables, use Float, add a formatting class, or
cross into Racket.

## Exact body separators

Join the exactly `rows` rendered row Strings with exactly `"\r\n"`:

- there are `rows - 1` CRLF separators;
- there is no CRLF before the first body row;
- there is no CRLF after the final body row;
- an empty body row contributes no characters but still participates in the
  separator count; and
- there is no padding or implicit final newline.

For four empty logical rows, the body is exactly:

```text
\r\n\r\n\r\n
```

The displayed spelling above contains three CRLF pairs; it is not a literal
backslash sequence in the result.

## Exact frame bytes

Concatenate these parts in this order with no other bytes:

1. `"\u001b[?25l"` — hide cursor;
2. `"\u001b[2J"` — clear screen;
3. `"\u001b[H"` — move home;
4. the exact body described above;
5. `"\u001b["`;
6. `(cursor-row text)`;
7. `";"`;
8. `(cursor-column text)`;
9. `"H"` — place cursor;
10. `"\u001b[?25h"` — show cursor.

The Aloe String literals contain the one ESC character U+001B. Do not emit
the six visible characters `\u001b`, a second clear/home sequence,
alternate-screen control, a trailing newline, padding, or terminal-specific
Racket data.

ANSI is ordinary Aloe String concatenation. There is no terminal-control host
selector and no call to `write` or `write-line` in this checkpoint.

## Normative frames

All examples below use 8 columns by 4 rows.

### Empty editor

```aloe
(AloemacsEditor new
  (Text from-string "")
  (Position new 0 0)
  #f)
```

returns exactly:

```text
\u001b[?25l\u001b[2J\u001b[H\r\n\r\n\r\n\u001b[1;1H\u001b[?25h
```

This proves four logical blank rows, exactly three separators, no trailing
CRLF, and one-based cursor origin.

### Vertical clipping

```aloe
(AloemacsEditor new
  (Text from-string "zero\none\ntwo\nthree\nfour\nfive")
  (Position new 5 4)
  #f)
```

returns exactly:

```text
\u001b[?25l\u001b[2J\u001b[Htwo\r\nthree\r\nfour\r\nfive\u001b[4;5H\u001b[?25h
```

Here `top = 2`, `left = 0`, and the point is terminal cell `(4, 5)`.

### Horizontal clipping and blank rows

```aloe
(AloemacsEditor new
  (Text from-string "0123456789")
  (Position new 0 10)
  #f)
```

returns exactly:

```text
\u001b[?25l\u001b[2J\u001b[H3456789\r\n\r\n\r\n\u001b[1;8H\u001b[?25h
```

Here `top = 0`, `left = 3`, the displayed source line is not space-padded,
three requested source lines are absent and therefore blank, and end-of-line
point remains visible at terminal cell `(1, 8)`.

### One shared horizontal origin

This additional two-row case prevents line-specific horizontal origins:

```aloe
(AloemacsEditor new
  (Text from-string "0123456789\nabcdefghij")
  (Position new 1 10)
  #t)
```

at 8 columns by 2 rows returns exactly:

```text
\u001b[?25l\u001b[2J\u001b[H3456789\r\ndefghij\u001b[2;8H\u001b[?25h
```

The same `left = 3` clips both lines. The `#t` quit field does not change the
frame or cause an effect.

## Required tests

Add `tests/aloemacs/frame.rkt`. Locate
`../../examples/aloemacs/editor.aloe` with `racket/runtime-path`, then load it
through an ordinary checked Aloe driver using `make-driver` and
`driver-eval!`. Do not inject a Term receiver. Frame construction and every
operation under test remain Aloe sends through the checked driver.

Cover all of the following:

1. Update `editor-keys.rkt` so `(editor frame 8 4)` has checked type `String`.
   Reject frame sends with argument counts of zero, one, and three, plus
   non-`Int` arguments. Remove only the obsolete assertion that the correct
   two-`Int` send is unknown; preserve all 13 reviewed test cases and every
   non-frame assertion.
2. A fresh driver has no `AloemacsEditor`; loading `editor.aloe` remains the
   only setup and brings Text dependencies source-relatively. No runtime or
   checker binding named `term` is injected.
3. The empty editor frame is byte-for-byte the exact String above.
4. The vertical clipping frame is byte-for-byte the exact String above.
5. The horizontal clipping/blank-row frame is byte-for-byte the exact String
   above.
6. The shared-horizontal-origin frame is byte-for-byte the exact two-row
   String above and is identical when the same editor differs only in quit.
7. At least one additional positive size proves the cursor row and column are
   one-based and within the supplied dimensions when no scrolling is needed.
   Keep the text ASCII and use exact complete-frame equality rather than a
   regex-only assertion.
8. Exact results prove hide occurs before clear/home/body, cursor placement
   occurs after the final body row, show is last, the body has exactly
   `rows - 1` CRLF pairs, and there is no final CRLF or space padding.
9. Retain bindings for representative source editors before calling `frame`
   and prove afterward that `(text to-string)`, point line/column, and quit
   are unchanged.
10. Repeated `frame` calls on the same editor and dimensions return equal
    Strings and require no host authority.
11. All checkpoint-000 edit, movement, quit, key, failure, no-op, validity,
    and immutability tests remain green without weakening or duplicating their
    production behavior in Racket.

Racket may provide test assertion helpers and exact expected String literals.
It must not calculate the production viewport, render rows, build ANSI,
simulate Term, or use evaluator internals directly.

## Verification and hand check

Run the two directly affected suites first:

```sh
TMPDIR=/tmp raco test tests/aloemacs/editor-keys.rkt
TMPDIR=/tmp raco test tests/aloemacs/frame.rkt
```

Then run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
TMPDIR=/tmp raco test tests
```

Run this checked no-Term hand exercise from the repository root:

```racket
(require racket/runtime-path
         "aloe/driver.rkt")

(define-runtime-path editor-path "examples/aloemacs/editor.aloe")
(define state (make-driver))
(driver-eval! state `(load ,(path->string editor-path)))
(driver-eval! state
  '(define frame-source-001
     (AloemacsEditor new
       (Text from-string "zero\none\ntwo\nthree\nfour\nfive")
       (Position new 5 4)
       #f)))

(define frame-001
  (driver-eval! state '(frame-source-001 frame 8 4)))

(list
 (equal?
  frame-001
  "\u001b[?25l\u001b[2J\u001b[Htwo\r\nthree\r\nfour\r\nfive\u001b[4;5H\u001b[?25h")
 (driver-eval! state '((frame-source-001 text) to-string))
 (driver-eval! state '((frame-source-001 point) line))
 (driver-eval! state '((frame-source-001 point) column))
 (driver-eval! state '(frame-source-001 quit)))
```

The result is:

```racket
'(#t "zero\none\ntwo\nthree\nfour\nfive" 5 4 #f)
```

No physical-TTY hand check is required.

## Acceptance

This checkpoint is complete only when:

1. `AloemacsEditor.frame` has exact checked type `(Int Int) -> String` and no
   correct-arity call requires Term.
2. Every positive-size call on a valid editor derives `top` and `left` afresh
   from point and dimensions, uses the same horizontal origin for all rows,
   clips with `drop` then `take`, and keeps point visible.
3. The body contains exactly the requested logical rows joined by exactly
   `rows - 1` CRLF pairs, using `""` beyond available source lines, with no
   wrapping, padding, or trailing CRLF.
4. The returned String has the exact hide/clear/home/body/cursor/show bytes
   and one-based decimal coordinates specified here.
5. `frame` is pure, repeatable, independent of quit, and leaves editor, Text,
   Position, and all checkpoint-000 behavior unchanged.
6. No stored viewport, Term access, host behavior, runner, starting binding,
   language/library change, or out-of-scope editor feature has been added.
7. Both focused suites and the full recursive suite are green, and the hand
   check returns the exact stated result.

Stop for human review. Do not begin another aloemacs-loop checkpoint.

## Explicit non-goals

- `examples/aloemacs/main.aloe`, the `aloemacs-editor` starting binding,
  `host/racket/aloemacs-run.rkt`, iteration, Term injection, a TTY, output,
  flush, or terminal size queries inside Aloe
- physical Backspace normalization, `tkeymsg->aloe-key`, modifier decoding,
  arrow mapping tests, host changes, a new Term selector, or a crossing type
- stored viewport origin, resize events, polling, alternate screen, status or
  mode lines, wrapping, space padding, tabs, control-character sanitizing,
  Unicode display width, graphemes, combining characters, or `wcwidth`
- files, paths, load/save, dirty state, encodings, CRLF file conversion,
  final-newline policy, buffers, windows, splits, or a scratch banner
- prefix keys, configurable keymaps, `C-x`, `M-x`, minibuffer, search,
  replace, undo, marks, selection, kill ring, indentation, syntax, or modes
- mutable state, setters, another editor or renderer class, a public viewport
  value, new String/List/Int behavior, `Char`, `Mirror`, eval of buffer text,
  live eval, hot reload, or a Legmacs/Chez Emacs port
