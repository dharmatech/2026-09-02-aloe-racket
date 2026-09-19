# Editor LSP 001 — UTF-16 positions and line breaks

**Status.** Implemented and reviewed. The focused 8-test suite, the retained
7-test editor-lsp 000 suite, and the required hand check are green. The
recursive suite passes 1,912 of 1,914 tests; its only failures are the two
pre-existing `tests/gel/presentations/003-doc-law.rkt` wording
contradictions. This checkpoint introduces no additional failure.

## Goal

Replace editor-lsp 000's temporary ASCII/LF-only coordinate layer with the
complete position conversion required by the LSP specification. Hover
positions must convert from zero-based UTF-16 line/character pairs to
one-based Racket character positions, and expression-query locations must
convert back to exclusive LSP ranges across LF, CRLF, lone CR, BMP, and
supplementary-plane text.

This checkpoint changes only position eligibility and conversion. It keeps
000's successful protocol lifecycle, exact hover rendering, unchanged-disk
requirement, and thin Expression Query boundary. It does not add document
changes, dirty-buffer snapshots, protocol error handling, query-failure
mapping, or the command-line launcher.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependency, and identity

- `SPEC.md` remains Aloe language law. This adapter does not parse, check,
  evaluate, or change send semantics.
- `docs/editor/lsp/spec.md` is the local design authority. Section 6 is
  decisive for this checkpoint; sections 1–5 and 7–8 retain their existing
  boundaries.
- Editor-lsp 000 is implemented and reviewed. `aloe/lsp.rkt` already provides
  `run-lsp-server`, valid canonical framing, the successful lifecycle,
  didOpen state, local file URI conversion, unchanged-disk protection, one
  public Expression Query call, and deterministic Hover rendering.
- The private `run-lsp-server/with-query` test-support seam from 000 remains
  the way tests observe converted query positions and supply controlled
  result locations. It must not become a normal module export.

Identity is `(editor-lsp, 001)`, spoken **editor-lsp 001**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit
`CHECKPOINTS.md`, add a file under `docs/checkpoints/`, or reopen the
Expression Query series.

## Preserve the 000 boundary

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

Keep its arity, test-support submodule, imports, framing, response shapes,
initialize capabilities, request-id retention, open-document state, local
file URI conversion, successful lifecycle, caller-port ownership, and clean
protocol output unchanged.

One valid hover still calls the supplied two-argument query procedure exactly
once. Type text, signature rows, and the returned `srcloc` remain the sole
sources of the Hover. Do not import another Aloe module, call
`type-signature-specs`, inspect declarations, or add a parser, checker,
evaluator, or method catalog.

The synchronized string's UTF-8 bytes must still exactly equal the bytes at
the URI's local regular-file path before any query. A differing buffer still
returns JSON null without a query in 001. This checkpoint must not create a
temporary file or query stale disk.

All tests from `tests/editor/lsp/000-hover.rkt` remain green without weakening
their assertions.

## Remove the temporary character restriction

Remove 000's `ascii/lf-text?` gate and any equivalent rejection of non-ASCII
or CR-containing synchronized text. Every Racket string whose UTF-8 bytes
match its local file is eligible for position conversion, subject only to the
validity rules below.

Position arithmetic is over Racket characters, not bytes. A Racket character
whose scalar value is at or below `#xFFFF` occupies one UTF-16 code unit. A
character above `#xFFFF` occupies two UTF-16 code units. Do not encode the
whole string to UTF-16 and use byte indices, and do not count a supplementary
character as two Racket characters.

For line structure, recognize exactly:

- LF as one line break;
- CRLF as one line break even though it occupies two Racket characters; and
- a lone CR as one line break.

No other character, including Unicode line separator characters, is an LSP
line break in this adapter.

## Incoming LSP position conversion

Convert an incoming well-shaped LSP `Position` against the exact synchronized
string. Its `line` and `character` are exact nonnegative integers. JSON values
that violate the protocol's `Position` shape belong to the later protocol-
validation checkpoint and are not assigned a response in 001.

For a valid position:

1. Scan the synchronized string by Racket character.
2. Find the zero-based Racket-character offset immediately after every
   preceding LF, CRLF, or lone-CR terminator. CRLF advances the Racket offset
   by two but advances the LSP line by one.
3. Within the requested line's content, excluding its terminator, accumulate
   each character's UTF-16 width until the sum equals the requested
   `character`.
4. Add the number of Racket characters consumed within the line to its
   Racket-character start offset, then add one to produce the
   `query-expression-at` position.

The boundary at the end of line content, immediately before its terminator,
is valid. When the source ends with any recognized line break, the empty line
after that terminator also exists and accepts character zero. The boundary at
the end of the complete string is valid and maps to one position beyond its
last Racket character.

Return JSON null without calling the query when:

- the requested line does not exist;
- the requested character is past the line-content boundary;
- a UTF-16 count cannot equal the requested character exactly because it
  would split a supplementary character's surrogate pair.

Do not clamp, round, count the terminator as line content, accept the middle
of a surrogate pair, or use `srcloc-line`/`srcloc-column`.

## Outgoing expression range conversion

Continue to derive the range only from the returned expression location. For
one-based start `s` and span `n`, convert these absolute Racket-character
offsets against the synchronized string:

```text
start offset = s - 1
end offset   = s - 1 + n
```

The returned LSP end remains exclusive. Scan from the beginning of the exact
synchronized string, counting the same line breaks and UTF-16 widths as the
incoming converter:

- an offset before a terminator is the preceding line's end position;
- an offset after a complete LF, CRLF, or lone CR is the following line at
  character zero;
- supplementary characters add two to the LSP character count; and
- BMP characters add one.

A Racket offset between the CR and LF of a CRLF pair is inside one logical
line break and has no LSP position. If either range endpoint is that offset,
return JSON null for the hover. The query has already occurred once in this
case; do not call it again to seek a different location.

Also return JSON null after the one query call when either derived offset is
outside the synchronized string. Do not repair, truncate, or replace an
invalid result range and do not expose `srcloc-source`. Malformed values that
cannot be returned by the public Expression Query contract are not a test
surface for this checkpoint.

The two conversion directions must use the same character-width and
line-break rules. Prefer one shared internal scanner or narrowly shared
helpers over independent rule tables that can drift. The helpers remain
private and are not added to the normal module surface.

## Normative mixed-text specimen

Use this exact Racket string in the new tests and write its UTF-8 bytes to one
temporary local file before opening it through LSP:

```racket
"a😀b\r\nλz\rq\n尾"
```

The string contains eleven Racket characters. Its absolute Racket-character
boundaries and LSP positions are:

| offset | meaning | LSP position |
|---:|---|---|
| 0 | before `a` | 0:0 |
| 1 | before `😀` | 0:1 |
| 2 | after `😀`, before `b` | 0:3 |
| 3 | before CRLF | 0:4 |
| 4 | between CR and LF | invalid |
| 5 | after CRLF, before `λ` | 1:0 |
| 6 | before `z` | 1:1 |
| 7 | before lone CR | 1:2 |
| 8 | after lone CR, before `q` | 2:0 |
| 9 | before LF | 2:1 |
| 10 | after LF, before `尾` | 3:0 |
| 11 | end of string | 3:1 |

Incoming LSP positions map to one-based query positions by adding one to the
corresponding valid offset. In particular:

- `0:1` maps to query position `2`, before `😀`;
- `0:2` is invalid because it splits `😀`'s UTF-16 pair;
- `0:3` maps to query position `3`, before `b`;
- `0:4` maps to query position `4`, immediately before CRLF;
- `1:0` maps to query position `6`;
- `2:0` maps to query position `9`; and
- `3:1` maps to query position `12`, the valid end-of-file boundary.

The tests may build other short specimens to isolate empty lines and trailing
LF, CRLF, or lone-CR behavior, but this mixed specimen is the normative
cross-direction case.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/001-utf16-positions.rkt` (new).

The new tests may create and unconditionally remove exact temporary files or
directories under the system temporary directory. No checked-in fixture is
needed for this slice.

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, or 000 tests/fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

If correct conversion requires changing Racket reader positions, altering
Expression Query's one-based character contract, using a byte offset, or
introducing a client-selected position encoding, stop and return the
checkpoint for design review.

## Required tests

Add `tests/editor/lsp/001-utf16-positions.rkt`. It is three directories below
the repository root, so use `../../../aloe/...` for repository-root module
paths. Exercise conversion through framed LSP messages and
`run-lsp-server/with-query`; do not export private converters just to test
them.

Write each synchronized test string as exact UTF-8 bytes to a uniquely named
temporary regular file, construct its absolute local `file:` URI with
standard URI operations, and send exactly the same Racket string in
`didOpen`. Use `dynamic-wind` or an equivalent unconditional cleanup action.
Never change the process-wide current directory without restoring it.

Cover at least:

1. The normative mixed specimen's valid incoming positions map to the exact
   one-based query positions listed above. Include the beginning of the file,
   both sides of the supplementary character, every line start, every line
   end, and the end-of-file boundary. Each valid hover calls the stub exactly
   once.
2. Incoming `0:2` splits `😀` and therefore returns JSON null with zero query
   calls. A character past a line end and a nonexistent line likewise return
   null with zero calls. Each exchange still reaches clean shutdown and exit.
3. Controlled query results with zero-span locations at every valid offset in
   the table convert back to the exact listed LSP position for both range
   endpoints. Supply deliberately false `srcloc-line` and `srcloc-column`
   values so the test proves they are ignored.
4. One nonzero range starts at offset 1 before `😀` and ends at offset 6
   before `z`. Its Racket span is five characters, while its LSP range is
   exactly `0:1` through `1:1`. This proves supplementary width and CRLF
   handling in one returned range.
5. Returned locations whose start or end is offset 4, between the CR and LF,
   yield JSON null after exactly one query call. Cover both the invalid-start
   and invalid-end cases.
6. Returned locations whose start or end is outside the synchronized string
   yield JSON null after exactly one query call and no server termination.
7. Separate short strings prove that a trailing LF, CRLF, and lone CR each
   creates one final empty LSP line at character zero. CRLF must create only
   one line, never two.
8. BMP characters, including `λ` and `尾`, occupy one UTF-16 unit; `😀`
   occupies two. Include a Unicode character such as U+2028 in line content
   and prove it changes the character count but does not create an LSP line.
9. The synchronized non-ASCII and mixed-line-break text is now queryable when
   its bytes equal disk. A one-byte mismatch still returns JSON null with zero
   query calls, leaves the file unchanged, and creates no sibling file.
10. `tests/editor/lsp/000-hover.rkt` remains green, including its exact ASCII
    Point result, framing, capabilities, call count, stale-disk protection,
    and normal module surface.

Inspect decoded Hover ranges and query-stub calls. Do not settle for testing a
standalone copy of the conversion formula in the test.

## Baseline suite note

The current branch has two unrelated failures already present before this
checkpoint, both in `tests/gel/presentations/003-doc-law.rkt`. They assert
older Gel-presentations handoff wording and experiment shape.

Do not edit or weaken those tests or their documentation. Require the focused
LSP suites to be completely green and the recursive suite to retain exactly
those two failures with no new failure. If that baseline contradiction has
been repaired before implementation starts, require a completely green
recursive suite.

## Hand check and acceptance

After the automated tests, run one framed interaction by hand from a Racket
REPL at the repository root using the normative mixed specimen and the
test-support query seam:

- open the exact synchronized temporary file;
- hover at LSP `0:3` and observe one query call at Racket position `3`;
- return a location spanning offsets 1 through 6; and
- inspect the Hover range `0:1` through `1:1`.

Then hover at `0:2` and confirm JSON null with no query call. Cleanly shut
down and exit both exchanges and remove the exact temporary file.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when the full UTF-16 and LF/CRLF/lone-CR rules are
proved in both directions through framed hover requests, invalid coordinates
never call the query, invalid returned ranges never leak misleading
positions, 000 remains green, and the recursive suite has no new failure.
Stop for review without committing. Do not begin editor-lsp 002.

## Explicit non-goals

- No `didChange`, `didClose`, incremental synchronization, or version policy
- No dirty-buffer sibling snapshot, loaded-document overlay, or source-file
  mutation
- No malformed framing/JSON recovery or JSON-RPC/LSP error matrix
- No complete invalid lifecycle, cancellation, or unsupported-request matrix
- No query/parser/checker/load failure classification or `RequestFailed`
- No empty-signature or overload rendering checkpoint
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No completion, diagnostics, diagnostic publication, or other LSP feature
- No client-selected encoding, UTF-8 position mode, VS Code extension, or
  editor-specific configuration
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
