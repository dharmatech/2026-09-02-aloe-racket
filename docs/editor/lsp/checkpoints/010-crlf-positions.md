# Editor LSP 010 — CR LF positions

**Status.** Issued 2026-10-14 as a standalone checkpoint from a
high-level discussion. Not implemented.

## Goal

Make every source position Aloe's parser records count characters of
the source text, with CR and LF counted as two characters. Hover,
completion, and the LSP converter already assume that coordinate. On a
file with CRLF line endings they are wrong today, because Racket's
reader counts CR LF as one position.

The fix is in the parser alone. The LSP adapter, the expression query,
and the completion query do not change.

The implementer receives only this document. Every rule for this slice
is below.

## What is wrong today

With `port-count-lines!` on, `read-syntax` treats CR LF as a single
position: the LF takes no position of its own. A lone CR and a lone LF
each take one, the same as their index in the text. So after the first
CR LF, every `srcloc-position` that `read-program` records is smaller
than the character's one-based index in the text. The difference is the
number of CR LF pairs before it. A span that covers a CR LF is one
character short per pair.

Everything that consumes these positions counts the text instead:

- `docs/editor/lsp/spec.md` §6 says CRLF "remains two Racket characters
  in the absolute position count", and `aloe/lsp.rkt` converts LSP
  positions and ranges by string index.
- `docs/editor/completion/spec.md` §1 defines a completion position as a
  boundary from `1` to `(add1 (string-length source))`.
  `aloe/private/completion-selection.rkt` inserts its cursor marker at
  string index `position - 1`, then compares that position with selector
  `srcloc`s and uses `start - 1` as a string index.
- Editor-lsp 001's specimen table and
  `tests/editor/completion/003-lsp-completion.rkt` ("CRLF ranges") both
  use string-index positions. Their tests use stub queries, so they never
  met the reader.

Probed on 2026-10-14 against the tree at `019cd18`:

| Input | Today | Text index |
|---|---|---|
| `read-program` of `"x\r\n(a b)"`: the send | position 3 | 4 |
| `read-program` of `"(a\r\n b) c"`: the first form | span 6 | 7 |
| Hover, real query, `(define x 1)\r\n(define y "s")\r\n(x + 2)\r\n` at LSP 2:1 (`x`) | range 1:14–2:5 | 2:1–2:2 |
| Hover, real query, `(define-class P\r\n  (fields (x Int))\r\n  (methods))\r\n(P new 1)\r\n` at LSP 3:1 (`P`) | `type: P`, range 2:11–3:6 | `type: (Class P)`, range 3:1–3:2 |
| `query-selector-completions` after `(define-class P (fields (x Int)) (methods))\r\n((P new 1) ` | no items | `x` |

The same texts with LF or with a lone CR are correct today. No `.aloe`
file in the repository uses CRLF, which is why nothing has failed.

## Authority, dependency, and identity

- `SPEC.md` is not amended. Aloe's meaning does not change.
- `docs/editor/lsp/spec.md` §6 is the rule this checkpoint makes true:
  a CRLF is one LSP line break and two characters in the absolute
  position count. The converter in `aloe/lsp.rkt` already implements
  that rule and stays as it is.
- `docs/editor/expression-query/spec.md` §1 says a query position "is a
  one-based character position in the source port". After this
  checkpoint that holds for CRLF text too.
- `docs/editor/completion/spec.md` §1 keeps its coordinate. Its
  positions now agree with the `srcloc`s it compares them to.
- This amends
  [editor-source-locations 000](../../source-locations/checkpoints/000-spans.md),
  which said `read-program` expressions "carry the source locations
  already reported by Racket's reader". Positions and spans now count
  the text. Lines, columns, and sources are still the reader's.
  Editor-source-locations 001 stays reserved for location-bearing
  errors and is not this checkpoint.

Identity is `(editor-lsp, 010)`, spoken **editor-lsp 010**. It belongs to
the LSP series because the LSP spec owns the position rule it makes
true; its one product edit is in the parser. Do not edit
`CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

The editor-definition series (`docs/editor/definition/spec.md`, awaiting
review) also edits `aloe/parse.rkt`, to add name spans. The two do not
depend on each other in either order. Every span the parser records goes
through the one location helper below, so a span field that series adds
gets the same counting with no extra rule.

## Required behavior

### The rule

For every `srcloc` that `read-program` records, including each
expression's `loc` and each send's `selector-loc`:

- `srcloc-position` is the one-based index, in the source text, of the
  first character the location covers;
- `srcloc-span` is the number of characters of the source text it
  covers;
- `srcloc-line`, `srcloc-column`, and `srcloc-source` are what
  `read-syntax` reports, unchanged.

The source text is the input as characters:

- a string input is that string;
- an input port is read to end of file as a string (`port->string`,
  which decodes UTF-8 the way the reader does), and the program is then
  read from a string port over that text with line counting on, as
  today.

`read-program` already reads its input to end of file, so reading the
text first changes no caller. Positions count from the first character
`read-program` reads, which for every current caller is the start of the
file or buffer.

### The translation

The reader counts the text in units: every character is one unit,
except a CR immediately followed by LF, which together are one unit.
Reader position `r` names the `r`-th unit. Its text position is the
one-based index of that unit's first character. Position one past the
last unit maps to `(add1 (string-length text))`.

For a location with reader position `p` and reader span `n`, the
recorded position is the text position of `p`, and the recorded span is
the text position of `p + n` minus the text position of `p`.

When the text contains no CR LF pair, the two counts agree, and the
positions are exactly today's. The implementation may skip building any
table in that case.

The translation lives in the parser's one location helper
(`syntax-location` in `aloe/parse.rkt`), applied while `read-program`
reads. It is not repeated in callers. A token never starts inside a CR
LF pair, and a form never ends between its CR and LF, so every reader
position the parser sees has a text position.

### What does not change

- `parse-datum` and `parse-program` remain location-free. Two parses of
  one datum still compare `equal?`.
- The grammar, every parse error and its text, every type and runtime
  error and its text, evaluation, and loads.
- Lines and columns.
- `aloe/lsp.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, and everything under `aloe/private/`.
- Every LF and lone-CR position in every existing fixture and test.

## Exact file scope

Implementation may edit only:

- `aloe/parse.rkt`;
- `tests/editor/lsp/010-crlf-positions.rkt` (new);
- `docs/editor/lsp/spec.md`, to add the one sentence below; and
- `docs/editor/source-locations/README.md`, to add the one line below.

Do not edit:

- `aloe/lsp.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/private/`, `aloe/type.rkt`,
  `aloe/eval.rkt`, or any other product module;
- any existing test or fixture;
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, any other spec,
  charter, or checkpoint document, including source-locations 000 and
  editor-lsp 001;
- `editors/vscode/`, `lib/`, `examples/`, `gel/`, or `host/`.

The new test may create temporary files and directories under the
system temporary directory and must remove them unconditionally. No
checked-in fixture is needed.

If any existing test fails after the parser change, or the fix seems to
need a change in the adapter or a query, stop and report it. The scratch
run below found none.

### Document edits

In `docs/editor/lsp/spec.md` §6, after the sentence "CRLF is one LSP
line break but remains two Racket characters in the absolute position
count.", add:

> Aloe source positions count it the same way: `read-program` records
> each position as the one-based index of a character in the source
> text, although Racket's reader counts CR LF as one position
> (editor-lsp 010).

In `docs/editor/source-locations/README.md`, after the paragraph that
says 001 remains unissued, add:

> Editor-lsp 010 amends 000: `read-program` positions and spans count
> CR and LF as two characters of the source text. Lines, columns, and
> sources are still the reader's.

## Required tests

Add `tests/editor/lsp/010-crlf-positions.rkt`. It is three directories
below the repository root, so use `../../../aloe/...` for module paths.
Locations are written `(line column position span)`.

1. **Parser, one line break.** For `"x\n(a b)"` and `"x\r(a b)"`, the
   second form's send is `(2 0 3 5)`, its receiver `a` is `(2 1 4 1)`,
   and its `selector-loc` is `(2 3 6 1)`, as today. For `"x\r\n(a b)"`
   they are `(2 0 4 5)`, `(2 1 5 1)`, and `(2 3 7 1)`.
2. **Span across a line break.** For `"(a\r\n b) c"`, the first form is
   `(1 0 1 7)` and `c` is `(2 4 9 1)`.
3. **Characters, a string literal, and a port.** For the text
   `(define s "😀\r\nx")\r\ns` (U+1F600, then a raw CR LF inside the
   string literal), the string literal is `(1 10 11 6)` and the final
   `s` is `(3 0 20 1)`. The same locations come back when the text is
   given as a string, and when its UTF-8 bytes are given as an input
   port.
4. **Hover, real query.** Through `run-lsp-server` with the real
   `query-expression-at` (no stub), open a temporary file whose disk
   bytes equal the synchronized text. For
   `(define x 1)\r\n(define y "s")\r\n(x + 2)\r\n`:

   | LSP position | First line of hover text | Range |
   |---|---|---|
   | 2:1 | `type: Int` | 2:1–2:2 |
   | 2:0 | `type: Int` | 2:0–2:7 |
   | 1:9 | `type: Void` | 1:0–1:14 |

   For `(define-class P\r\n  (fields (x Int))\r\n  (methods))\r\n(P new 1)\r\n`:

   | LSP position | First line of hover text | Range |
   |---|---|---|
   | 0:1 | `type: Void` | 0:0–2:12 |
   | 3:1 | `type: (Class P)` | 3:1–3:2 |

   Write the same text with LF line endings to the same path, and hover
   at the same LSP positions: the whole hover result, text and range,
   equals the CRLF result.
5. **Completion, real query.** For
   `(define-class P (fields (x Int)) (methods))\r\n((P new 1) `,
   `query-selector-completions` at the end-of-buffer position returns
   exactly one item, label `x`, replacement start 57, span 0. With `x`
   appended, at the new end it returns label `x`, start 57, span 1.
   Through `run-lsp-server` with the real completion query, completion
   at LSP 1:11 returns one item `x` whose text edit range is 1:11–1:11.
   The LF and lone-CR versions of the same text return the same labels
   and LSP ranges, with replacement start 56.
6. **Unchanged.** `tests/editor/source-locations/000-spans.rkt`,
   `tests/editor/lsp/001-utf16-positions.rkt`, and
   `tests/editor/completion/003-lsp-completion.rkt` pass without edits.

Run each case through framed LSP messages where it says LSP. Do not test
a copy of the translation formula.

## Scratch run

On 2026-10-14 a prototype of this edit (about 30 lines in
`aloe/parse.rkt`: a per-read table from reader positions to text
positions, built only when the text contains CR LF, and applied in
`syntax-location`) was applied to a copy of the repository. The cases
above produced exactly the values listed. With no existing test edited,
the whole suite ran 3012 tests under `-j 4`, and no file crashed. The one
failure was `tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar
(30.02 ms), which passed alone, twice. That bar is a known flake under
parallel runs and does not touch the parser.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/lsp/010-crlf-positions.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

All green, with no existing test changed. If only
`tests/aloemacs/window-pictures.rkt`'s timing bar fails under `-j 4`,
rerun that file alone; it must pass there.

Hand check in VS Code with the extension running `racket -l aloe/lsp`:

1. Open a copy of `tests/editor/lsp/fixtures/point.aloe` outside the
   repository and switch its line endings to CRLF from the status bar.
2. Hover the final `(Point new 1 2)` on line 10. The highlight covers
   exactly that form.
3. Add a line `((Point new 1 2) ` at the end. Completion offers the Point
   messages.

Stop for review without committing.

## Explicit non-goals

- A change to the LSP converter, the expression query, the completion
  query, or completion's position contract
- A change to lines or columns, or to how tabs count
- Unicode line separators as line breaks
- Byte positions, or positions for text that is not read through
  `read-program`
- Diagnostics or location-bearing errors (source-locations 001)
- A rewrite of editor-lsp 001's tests or specimen
- Normalizing line endings in source files, or CRLF handling in Aloemacs
- Any editor-definition work
