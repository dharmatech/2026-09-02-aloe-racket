# aloemacs-loop 000 — Editor key transitions

**Status.** Ready to implement.

## Goal

Introduce the immutable `AloemacsEditor` application value and complete its
pure editing, movement, quit, and one-String key-transition behavior. The
editor composes the reviewed `Text` algebra: successful edits rebuild from
`EditResult`, movement changes only `Position`, and every transition returns a
new editor value without changing its receiver.

This checkpoint is the first pure consumer of the aloemacs Text layer. Stop
when it is green. Do not build frames, normalize host keys, inject Term, add
the starting `aloemacs-editor` binding, or create the iterative runner.

The implementer receives only this document. Every rule needed for this slice
is below.

## Depends on, authority, and identity

- Identity is `(aloemacs-loop, 000)`, spoken **aloemacs-loop 000**. This is a
  local project checkpoint, not a global Aloe checkpoint. Do not edit
  `CHECKPOINTS.md` or add a document under `docs/checkpoints/`.
- [`../../../../../../SPEC.md`](../../../../../../SPEC.md) is language law,
  especially send evaluation, typed immutable classes, `if`, parallel `let`,
  exhaustive `case`, `load`, and exact `Int`. Evaluation is send, not apply:
  the head of a list is the receiver and its second element is the literal
  selector. A function object runs only through `(f call ...)`.
- [`../spec.md`](../spec.md), especially sections 1–5 and 8.1–8.3, is the
  local design authority. This checkpoint implements the editor state and
  transition portion exactly; it intentionally leaves the section 2 starting
  binding and sections 5–7 host normalization, frame, and runner outside the
  slice.
- **aloemacs-text 000–003** are implemented and reviewed. Loading
  `lib/text.aloe` supplies `Option`, `Position`, `Span`, `Text`, and
  `EditResult`, including immutable `insert`, `delete`, and `newline` sends,
  exact LF-split lines, and position validity.
- **aloemacs-term 000** is implemented and reviewed, but this checkpoint does
  not load, inject, send to, or edit Term. Its existence does not move any
  transition policy into Racket.

Do not add a special form, mutation, inheritance, macro, implicit numeric
coercion, `Char`, host crossing, or second evaluation path.

## Starting point

There is no `examples/aloemacs/` directory and no `AloemacsEditor` binding in
a fresh driver. `lib/text.aloe` is the complete reviewed Text predecessor and
must remain unchanged.

Create `examples/aloemacs/editor.aloe`. Its first form is exactly:

```aloe
(load "../../lib/text.aloe")
```

The load is source-relative. Tests load only `editor.aloe`; they do not load
or repeat Text declarations separately. Loading the editor source into one
checked driver does not bootstrap it into another fresh driver or the default
environment.

## Exact file scope

### May edit

- `examples/aloemacs/editor.aloe` (new)
- `tests/aloemacs/editor-keys.rkt` (new)

### Must not edit

- `SPEC.md`, `CHECKPOINTS.md`, any global checkpoint document, or any file
  under `docs/editor/`
- `lib/text.aloe`, any other file under `lib/`, or any file under `aloe/` or
  `bin/`
- `host/racket/term.rkt`, any other host file, package metadata, or `tui-term`
- `examples/aloemacs/main.aloe`, any Gel source or runner, or another example
- any existing test, including the aloemacs Text and Term suites
- the aloemacs maps, charters, specifications, or earlier checkpoint
  documents
- any file not listed under **May edit**

If another file appears necessary, stop and send the checkpoint back for
correction rather than widening the slice.

## The editor value

After the Text load, declare exactly this application state class and field
order:

```aloe
(define-class AloemacsEditor
  (fields
    (text Text)
    (point Position)
    (quit Bool))
  (methods
    ...))
```

Construction is:

```aloe
(AloemacsEditor new text point quit)
```

The three fields are the entire persistent state. Do not add a path, dirty
bit, selection, mark, goal column, key prefix, viewport origin, dimensions,
window, terminal receiver, cached lines, or another state class or
constructor.

This checkpoint adds these public command methods with these exact checked
signatures:

| Send | Result |
|---|---|
| `(editor insert string)` | `AloemacsEditor` |
| `(editor newline)` | `AloemacsEditor` |
| `(editor backward-delete)` | `AloemacsEditor` |
| `(editor move-left)` | `AloemacsEditor` |
| `(editor move-right)` | `AloemacsEditor` |
| `(editor move-up)` | `AloemacsEditor` |
| `(editor move-down)` | `AloemacsEditor` |
| `(editor request-quit)` | `AloemacsEditor` |
| `(editor handle-key key)` where `key : String` | `AloemacsEditor` |

`frame` is deliberately absent in this slice. Do not add a placeholder,
dummy frame, ANSI helper, top-level frame function, or terminal argument.

Small helper selectors on `AloemacsEditor` are permitted only when they walk
the Text line list, select a line length, or clamp an integer for the command
implementations above. Such helpers are implementation details: they must be
pure, must not add state or command behavior, and tests must not depend on
their names. A local fold is equally acceptable. Do not add a helper class or
top-level helper binding.

## Transition invariant and no-op construction

For every valid receiver, every command method in this checkpoint returns an
editor whose point remains valid for its text:

```aloe
((result text) valid-position? (result point)) ; => #t
```

The edit and movement commands preserve the receiver's `quit` field.
`request-quit` sets it to `#t`, and `handle-key` changes it only by
dispatching `"escape"` to `request-quit`. The raw constructor itself performs
no validation; the deliberately invalid failed-edit test below is the only
invalid editor this checkpoint constructs.

Every command send returns a freshly constructed `AloemacsEditor`, including
an edge no-op, an unknown-key no-op, an edit that returns `None`, and an
already-quit `handle-key`. Aloe exposes no identity predicate here, so tests
prove this semantic requirement by structural equality and unchanged input
payloads. Do not return `self` from a no-op branch.

No method mutates or replaces a field of its receiver. After a transition,
the original editor, its Text, and its Position retain their original
payloads.

## Insert and newline

`insert` sends exactly:

```aloe
((self text) insert (self point) string)
```

and selects the resulting `Option` exhaustively:

- `Some(result)` constructs an editor from `(result text)`,
  `(result position)`, and `(self quit)`;
- `None` constructs an equal editor from `(self text)`, `(self point)`, and
  `(self quit)`.

`newline` follows the same rule around exactly:

```aloe
((self text) newline (self point))
```

Do not calculate the successful result point in the editor, splice the source
again, use `present?` without extracting the result, or add an Option unwrap
helper. The Text operation is the single edit path, and the editor trusts the
returned `EditResult.position`.

Required results include:

```aloe
(AloemacsEditor new
  (Text from-string "")
  (Position new 0 0)
  #f)
```

after `(editor insert "x")`: text `"x"`, point `(0, 1)`, quit `#f`.

Starting with text `"a"` at `(0, 1)`, `newline` returns text `"a\n"` at
`(1, 0)`. Both original editors remain unchanged.

On this deliberately invalid raw editor:

```aloe
(AloemacsEditor new
  (Text from-string "abc")
  (Position new 0 4)
  #f)
```

`insert "x"` receives `None` from Text and returns an editor structurally
equal to that invalid receiver. It does not clamp, raise a list/substring
error, or construct a different point. This exception proves the exhaustive
failure branch; it does not weaken the valid-editor invariant.

## Backward delete

`backward-delete` has exactly three coordinate cases.

### Within a line

When `(point column) > 0`, construct:

```aloe
(Span new
  (Position new (point line) ((point column) - 1))
  point)
```

and send `(text delete span)`. For `Some(result)`, rebuild from the result
Text and Position; for `None`, construct an equal editor.

Thus text `"ab"` at `(0, 2)` becomes `"a"` at `(0, 1)`.

### Across an LF

When `(point column) = 0` and `(point line) > 0`, find the exact length of
the preceding line in `(text lines)`. Construct a span from:

```aloe
(Position new ((point line) - 1) previous-length)
```

to the current point, then use the same exhaustive `(text delete span)` path.
That half-open span contains exactly the LF separator.

Thus text `"ab\ncd"` at `(1, 0)` becomes `"abcd"` at `(0, 2)`.

### Beginning of text

At `(0, 0)`, construct an editor equal to the receiver. Do not send an
invalid span to Text and do not return `self`.

No branch splices `(text to-string)` directly, invents another delete
operation, or derives a successful point independently of `EditResult`.

## Movement

Movement never edits or reconstructs Text. It constructs an editor with the
same Text and quit fact and the position below. An edge no-op still constructs
an equal editor.

### Horizontal

- Left with `column > 0` moves to `(line, column - 1)`.
- Left at column 0 on a non-first line moves to the previous line at that
  line's exact length.
- Left at `(0, 0)` is an equal no-op.
- Right before the current line's end moves to `(line, column + 1)`.
- Right at end-of-line on a non-final line moves to `(line + 1, 0)`.
- Right at the end of the final line is an equal no-op.

Left and right traverse an LF boundary without deleting or inserting it.

### Vertical

- Up on line 0 is an equal no-op.
- Otherwise up moves to the preceding line at
  `min(current-column, preceding-line-length)`.
- Down on the final line is an equal no-op.
- Otherwise down moves to the following line at
  `min(current-column, following-line-length)`.

There is no remembered goal column. For example, in text
`"abcd\nx\nwxyz"`, down from `(0, 4)` reaches `(1, 1)`, and a second down
reaches `(2, 1)`, not `(2, 4)`. The analogous upward path from `(2, 4)`
through a shorter middle line also continues from the clamped column.

Use ordinary Aloe `Int` comparisons and arithmetic. Do not introduce a
mutable cursor, offset representation, implicit `Int`/`Float` conversion, or
movement method on `Text` or `Position`.

## Quit and key dispatch

`request-quit` constructs an editor with the exact existing Text and Point
and `quit = #t`. Calling it on an already-quit editor constructs an equal quit
editor.

`handle-key` accepts one complete key `String`. If `(self quit)` is already
`#t`, it immediately constructs an equal editor and performs no edit or
movement. Otherwise it dispatches in this exact precedence order:

| Exact key String | Send to `self` |
|---|---|
| `"return"` | `(self newline)` |
| `"backspace"` | `(self backward-delete)` |
| `"left"` | `(self move-left)` |
| `"right"` | `(self move-right)` |
| `"up"` | `(self move-up)` |
| `"down"` | `(self move-down)` |
| `"escape"` | `(self request-quit)` |
| any other String with `(key len) = 1` | `(self insert key)` |
| every other String | a freshly constructed equal editor |

Named keys are checked before the length-one fallback. In particular, `"q"`
inserts the printable letter q; it does not quit. `"escape"` is the only quit
key. `"home"`, `"delete"`, `"f1"`, `""`, and other unbound names are
no-ops and never cause an Aloe or host error.

This method dispatches only already-normalized Strings. Do not require
`host/racket/term.rkt`, construct `tkeymsg` values, interpret modifiers, add a
prefix map, or special-case physical key encodings in this checkpoint.

## Required focused tests

Add `tests/aloemacs/editor-keys.rkt`. Locate
`../../examples/aloemacs/editor.aloe` with `racket/runtime-path`, then load it
through an ordinary checked Aloe driver using `make-driver` and
`driver-eval!`. All production behavior under test is Aloe code; Racket may
provide assertion helpers but must not duplicate editor transitions.

Cover all of the following:

1. A fresh driver has no `AloemacsEditor`. Loading `editor.aloe` binds
   `AloemacsEditor` and its Text dependencies only in that driver; a second
   fresh driver remains unaffected.
2. `AloemacsEditor` construction and its `text`, `point`, and `quit` field
   sends have exactly the declared types. Wrong arity and wrong field types
   are rejected. No alternate constructor or fourth state field exists.
3. Every command method in the signature table has the exact checked result
   type and rejects wrong argument types and arities. `frame` is still an
   unknown message in this slice.
4. Direct `insert` into empty text and direct `newline` after `"a"` produce
   the exact Text, Position, and quit payloads stated above, selected from
   `EditResult` by the production Aloe methods.
5. Direct `backward-delete` removes a character, joins lines across an LF,
   and is an equal no-op at `(0, 0)`, with the exact results above.
6. Direct insertion on the deliberately invalid raw editor takes the `None`
   branch and returns a structurally equal invalid editor without an Aloe or
   host failure.
7. Horizontal movement covers an ordinary step, left from column 0 to the
   previous line end, right from end-of-line to the next line's column 0, and
   equal no-ops at the beginning and final end.
8. Vertical movement covers up and down with a fitting column, clamping in
   each direction to a shorter line, equal edge no-ops, and a second vertical
   move from a clamped column proving there is no goal-column memory.
9. Every movement case preserves the exact `(text to-string)` result and
   quit fact, and every result from a valid editor satisfies
   `valid-position?`.
10. `handle-key` covers each of the seven named keys, the one-character
    insertion fallback (including `"q"`), and a representative unknown named
    key such as `"home"`. Named behavior must agree with its corresponding
    direct command send.
11. `"escape"` preserves text and point and sets quit. A subsequent printable,
    movement, Return, and Backspace key sent through `handle-key` each produce
    an equal quit editor, proving the state is absorbing at this boundary.
12. Empty and multi-character unknown keys are equal no-ops and do not raise.
13. For every edit, movement, quit, failure, and no-op category above, retain
    a binding for the input editor and prove afterward that its source String,
    point fields, and quit fact are unchanged.

Use Aloe's structural `check` form or exact field assertions for equal-editor
claims. Do not add an equality method, test-only Aloe helper, Option API,
parallel Racket editor struct, or direct interpreter bypass.

## Verification and hand check

Run the new focused suite first:

```sh
raco test tests/aloemacs/editor-keys.rkt
```

Then run the recursive suite; `tests/*.rkt` is not an acceptable substitute
because it skips nested aloemacs and editor tests:

```sh
raco test tests
```

Run this checked hand exercise from the repository root:

```racket
(require racket/runtime-path
         "aloe/driver.rkt")

(define-runtime-path editor-path "examples/aloemacs/editor.aloe")
(define state (make-driver))
(driver-eval! state `(load ,(path->string editor-path)))
(driver-eval! state
  '(define start-000
     (AloemacsEditor new
       (Text from-string "")
       (Position new 0 0)
       #f)))
(driver-eval! state '(define a-000 (start-000 handle-key "a")))
(driver-eval! state '(define newline-000 (a-000 handle-key "return")))
(driver-eval! state '(define b-000 (newline-000 handle-key "b")))
(driver-eval! state '(define left-000 (b-000 handle-key "left")))

(list
 (driver-eval! state '((left-000 text) to-string))
 (driver-eval! state '((left-000 point) line))
 (driver-eval! state '((left-000 point) column))
 (driver-eval! state '(left-000 quit))
 (driver-eval! state '((start-000 text) to-string))
 (driver-eval! state '((start-000 point) column)))
```

The result is:

```racket
'("a\nb" 1 0 #f "" 0)
```

No physical-TTY hand check is required.

## Acceptance

This checkpoint is complete only when:

1. `AloemacsEditor` has exactly the three immutable persistent fields and the
   command signatures specified here.
2. Insert, newline, and backward delete use only the Text edit API, exhaust
   `Some`/`None`, and rebuild successful state from `EditResult`.
3. Horizontal and vertical movement produce the exact valid positions,
   including LF traversal, edge no-ops, clamping, and no remembered goal
   column, while preserving Text and quit.
4. `handle-key` implements the exact precedence table, uses `"escape"` for
   quit, leaves unknown names safe, and is absorbing once quit is true.
5. Every transition returns a newly constructed immutable editor semantic,
   every valid input yields a valid point, and all input values remain
   unchanged.
6. No frame, starting binding, Term behavior, host mapping, runner, language
   feature, Text change, or out-of-scope editor feature has been added.
7. The focused test and full recursive suite are green, and the hand check
   returns the exact stated result.

Stop for human review. Do not begin another aloemacs-loop checkpoint.

## Explicit non-goals

- frame construction, ANSI, clipping, scrolling, viewport storage, terminal
  dimensions, status or mode lines, wrapping, tabs, Unicode display width, or
  grapheme handling
- `examples/aloemacs/main.aloe`, the `aloemacs-editor` starting binding,
  `host/racket/aloemacs-run.rkt`, iteration, Term injection, a TTY, output, or
  size queries
- physical Backspace normalization, `tkeymsg->aloe-key`, modifier decoding,
  arrow mapping tests, host changes, a new Term selector, or a new crossing
  type
- files, paths, load/save, dirty state, final-newline policy, encodings, CRLF
  conversion, multiple buffers, windows, splits, or a scratch banner
- prefix keys, configurable keymaps, `C-x`, `M-x`, minibuffer, search,
  replace, undo, marks, selection, kill ring, indentation, syntax, or modes
- mutable editor or cursor state, setters, goal-column memory, a second text
  representation, public offsets, `Char`, `Mirror`, eval of buffer text, live
  eval, hot reload, or a Legmacs/Chez Emacs port
