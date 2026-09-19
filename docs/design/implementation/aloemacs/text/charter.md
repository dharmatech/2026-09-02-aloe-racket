# Charter — aloemacs text

**Status.** Handoff from the aloemacs high-level discussion into a
**design conversation**. Not Aloe law. Not a checkpoint. Not an
implementer assignment. Specification will live beside this file as
[`spec.md`](spec.md). Parent map:
[`docs/design/implementation/aloemacs/README.md`](../README.md).
Process: [`docs/workflow.md`](../../../../workflow.md).

**Your job.** Turn this charter into a specification for a **pure
Aloe text algebra**: immutable lines, positions, half-open spans,
and replacing a span with a string (including newlines). Then
**stop**. Do not write checkpoints. Do not implement. Do not
specify Term, the editor loop, keymaps, windows, undo history, or
file I/O.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, the parent map, and the authority in §5.
2. Record the locked decisions in §4. Resolve the open questions
   in §4.6–§4.9.
3. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **aloemacs-text 000**, `001`, … under
   `docs/design/implementation/aloemacs/text/checkpoints/` (not
   `docs/checkpoints/0116`, not `docs/editor/`).
4. Stop. The human reviews it. Do not write those checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Keep the spec **small enough to slice**. A screen editor, a Term
capability, rebase-across-actors, Unicode width, and a port of
`text.sls` or `buffer.lg` are defects in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| `SPEC.md` §7.5 | `String` kernel is `=`, `append`, `len`, `take` |
| [`lib/string.aloe`](../../../../../lib/string.aloe) | `starts-with?` is an Aloe method |
| [`lib/list.aloe`](../../../../../lib/list.aloe) | `fold`, `reverse`, `map` |
| Constructors / `case` | Already in the language; use them if a sum type earns its keep |

No aloemacs layer has to be green first. Term is a sibling, not a
predecessor. Do not wait for it. Do not specify it.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. **Aloe classes, not a Racket API.** The public surface is
   `define-class` / `define-methods` (and String methods if
   required). Unit tests in `tests/aloemacs/` load Aloe source and
   check results. A Racket helper is allowed only as the test
   driver, the way other Aloe library tests already work.
2. A `Text` is an ordered sequence of lines. A line is a `String`
   that contains no newline. Empty input is still one empty line,
   not zero lines.
3. A `Position` is a line and a column. A `Span` is half-open:
   `[start, end)`. Replacing a span with a string (which may
   contain newlines) yields a **new** `Text` and a **new**
   `Position` (the end of the insertion). Insert, delete, and
   newline are defined in terms of that replace, or the spec
   names an equivalent closed set and proves they compose.
4. There are documented goldens, at least:
   - empty / single empty line
   - insert a character in the middle of a line
   - insert a newline (split a line)
   - delete a character; delete at end-of-line joins with the
     next line
   - replace a multi-line span with a shorter or longer string
   - `from-string` / `to-string` round-trip for a small fixture
     that includes a trailing newline and one that does not, if
     the spec tracks that fact; if it does not, say so and still
     round-trip the chosen normal form
5. **First consumer is tests.** No TTY, no `term`, no
   `examples/aloemacs/` loop in this project.
6. Anything this algebra needs from `String` that `=`, `append`,
   `len`, and `take` cannot express is **named**. Prefer
   `define-methods String`. A new kernel message is allowed only
   when Aloe cannot write it from those four. Do not add `Char`.

## 4. Locked decisions (record these; do not reopen 4.1–4.5)

### 4.1 Machine

Immutable values. No setters, no boxes, no in-place line vector.
`(text replace …)` returns a new text. This is the Legmacs buffer
discipline and Chez Emacs's `text.sls` payload, not Chez Emacs's
mutable store.

### 4.2 Not a port

Read [`/home/dharmatech/src/e/lib/foundation/text.sls`](/home/dharmatech/src/e/lib/foundation/text.sls)
and [`/home/dharmatech/src/legmacs/legmacs/buffer.lg`](/home/dharmatech/src/legmacs/legmacs/buffer.lg)
as catalogs of seams (lines, point, span replace). Do not
translate Scheme or let-go into Aloe. Names, helpers, rebase, and
snapshot-undo from those files are not requirements.

### 4.3 Display and I/O are out

No cell width, no tabs-as-columns, no ANSI, no `term`. Columns in
this algebra are string indices (character counts as `len`
defines them). Load/save is the File layer.

### 4.4 Where code lives

- `lib/text.aloe` for the algebra (general library, like
  `lib/option.aloe`)
- `lib/string.aloe` for Aloe `String` methods this spec adds
- Kernel `String` changes, if any, in the files `SPEC.md` §7.5
  already implies (`aloe/eval.rkt` / type / tests as the
  checkpoint will name)
- Tests under `tests/aloemacs/`
- Do not put this algebra in `examples/aloemacs/`. That directory
  is the later loop.

### 4.5 Out of this layer

- Undo stacks, invert-for-undo, rebase of foreign positions
- Marks, selections as editor features (a `Span` value is in;
  a mark ring is out)
- Keymaps, commands, point-as-editor-state
- Term `write` / `size`, alternate screen
- Unicode graphemes, `wcwidth`
- `Mirror`, `eval` of buffer text
- Global checkpoint numbering

### 4.6 Representation (resolve this)

Specify the classes, fields, and constructors.

- Is `Text` a class whose lines are `(List String)`, or another
  shape that still meets §3.2?
- Are `Position` and `Span` classes? Constructor selectors?
- Zero-based vs one-based line and column. Pick one. Tests use
  that convention only.
- Illegal positions (column past line end, line past last line):
  error, clamp, or `Option`? Name the rule. Do not silently
  invent a fourth.

### 4.7 String hole (resolve this)

Today a program cannot take a suffix of a `String`: `take` only
yields prefixes, and there is no character walk. Span replace
needs a prefix and a suffix.

Name the smallest extension. Likely a kernel `drop` (or a slice)
plus Aloe `insert` / `delete` built from `take`, `drop`, and
`append`. If you choose something else, say why it is smaller.

If a kernel message is required:

- Give its exact send, types, and clamping rules in the spec
  (parallel to `take` in `SPEC.md` §7.5).
- Implementation of that message is in this project's checkpoint
  series unless the human promotes it to the language spine after
  review. Do not invent `docs/checkpoints/0116-…` in the spec.
- Do not add `Char`, string-ref of a non-`String`, or mutation.

### 4.8 Newline and files (resolve this)

- What character splits lines? `"\n"` only? Does `"\r\n"` appear
  in `from-string`, or is that File's problem later?
- Does `Text` store a trailing-newline fact (Chez Emacs) or is a
  trailing newline just whether `to-string` ends in `"\n"`?
- `from-string` / `to-string` are in this spec (bar §3.4). Name
  them as Aloe messages.

### 4.9 Edit result (resolve this)

Replacing a span returns a new `Text`. Also specify what happens
to positions:

- The spec **must** say where point is after the replace (end of
  the inserted text is the usual editor rule; if you pick another,
  tests show it).
- Rebasing *other* positions across an edit is **out**. Do not
  specify Chez Emacs `rebase-position`. A later undo/mark layer
  may ask for invert; do not add it here in order to look complete.

## 5. Authority

- [`../README.md`](../README.md) — locks, paths, non-goals
- `SPEC.md` — send, classes, `List`, `String` §7.5, no mutation
- `docs/philosophy.md` — grow from applications; keep the kernel
  small
- `docs/decisions.md` — `define-methods String`; host crossing is
  not this project
- `lib/string.aloe`, `lib/list.aloe`, `lib/option.aloe` — library
  shape
- Chez Emacs `text.sls` and Legmacs `buffer.lg` — seam catalogs,
  not law

`SPEC.md` remains Aloe language law. This spec is not language
law except for any kernel `String` send it explicitly adds, which
the human may later ratify onto `SPEC.md` through the checkpoint
that implements it.

## 6. Non-goals

- A runnable editor
- Term, paint, keymap, minibuffer
- Incremental screen cache
- Search, indent, syntax
- Porting `glyph.sls` or Legmacs render
- Changing `List` kernel messages
- Gel, LSP, VS Code
