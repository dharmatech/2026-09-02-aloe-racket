# Editor LSP 000 — End-to-end Point hover

**Status.** Implemented and reviewed. The focused 7-test suite and recorded
hand check are green. The recursive suite passes 1,904 of 1,906 tests; its
only failures are the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` wording contradictions. This
checkpoint introduces no additional failure.

## Goal

Establish the first complete vertical slice of the Aloe language server. A
Racket caller supplies one stream containing a valid LSP initialize, open,
hover, shutdown, and exit exchange. The server reads framed JSON-RPC from
that stream, queries the public Expression Query exactly once for the hover,
and writes the exact Point type, ordered message rows, and expression range as
framed LSP responses.

This checkpoint deliberately supports only unchanged, local, ASCII source
text with LF line endings. That narrow domain is enough to prove the adapter
boundary without implementing stale-disk behavior. Later checkpoints add
dirty-buffer sibling snapshots, complete UTF-16 and line-break conversion,
document changes, protocol failure behavior, and the command-line launcher.

This is not a transport-only checkpoint. It is incomplete unless the recorded
hover request reaches `query-expression-at` and returns its real result.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. Evaluation is send, the head of a list
  is the receiver, and the second element is a literal selector. This adapter
  does not parse, check, evaluate, or reinterpret Aloe.
- `docs/editor/lsp/spec.md` is the local design authority. In particular,
  sections 1–3 define the module and protocol boundary, sections 4–7 define
  initialization, synchronization, coordinate conversion, and hover, and
  section 8 defines eventual launch and exit behavior.
- Editor-expression-query 000–003 are implemented and reviewed before this
  checkpoint begins. `aloe/expression-query.rkt` provides
  `query-expression-at`, `expression-query-result`, and the re-exported
  `signature-spec`. They are the only Aloe query and row sources used here.
- The normative Point fixture and expected result come from the Expression
  Query and LSP specifications. Production LSP code must not contain that
  fixture's declarations or rows.

Identity is `(editor-lsp, 000)`, spoken **editor-lsp 000**. This is a local
editor checkpoint, not a global Aloe checkpoint and not another Expression
Query checkpoint. Do not edit `CHECKPOINTS.md` or add a file under
`docs/checkpoints/`.

## Exact public module boundary

Add `aloe/lsp.rkt`. Its normal module surface provides exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

The three arguments are the byte input port, framed protocol output port, and
logging/error output port. `run-lsp-server` processes messages serially until
the `exit` notification in this checkpoint's successful lifecycle, then
returns status `0`. End of input before `exit` returns a nonzero exact integer.
It never closes any caller-owned port.

Requiring `aloe/lsp.rkt` must not read a port, write output, start a server, or
exit the process. Do not add the `main` submodule in 000; the documented
`racket -l aloe/lsp` launcher, argument rejection, and process-level exit
tests belong to a later checkpoint.

The LSP module imports the following Aloe bindings only from
`aloe/expression-query.rkt`:

- `query-expression-at`;
- the `expression-query-result` predicate and accessors; and
- the `signature-spec` accessors.

It must not import the parser, evaluator, checker, signature catalog, private
selection or observation modules, driver, host boundary, or `aloe/main.rkt`.
It must not call `type-signature-specs`, inspect declarations, or contain a
second type or method table.

For a direct runtime proof of call count, keep the server loop behind a
private four-argument helper that accepts the query procedure. The normal
`run-lsp-server` calls that helper with the imported
`query-expression-at`. Expose the helper only through a `(module* test-support
#f ...)` submodule as:

```racket
(run-lsp-server/with-query input output error-output query) ; -> exact-integer?
```

It is not part of the normal module's public surface. The helper changes only
which two-argument query procedure is invoked; it must exercise the same
framing, lifecycle, document, conversion, and rendering path as production.

## Valid framing in this slice

Read and write bytes, not character-counted protocol bodies. A valid input
frame in 000 has the canonical form:

```text
Content-Length: <nonnegative decimal UTF-8 byte count>\r\n
\r\n
<one UTF-8 JSON value>
```

Read exactly the declared body byte count, decode one JSON value, process it,
and continue immediately with the next frame. The recorded test supplies all
six frames concatenated in one byte input port, so consuming only one frame
or reading through a following frame is a failure.

Every response is one JSON-RPC 2.0 object encoded as UTF-8 bytes with its own
canonical `Content-Length` header and blank line. The declared length is the
body's byte length, not a Racket character count and not the complete frame
length. Flush the protocol output after each response. Standard output
contains only these framed protocol messages; write no banner, debug datum,
exception, or test trace there. Successful 000 operation writes nothing to
the supplied error port.

000 needs to accept only correctly framed, well-formed JSON objects in the
specified successful order. Multiple headers, malformed headers or lengths,
partial frames, malformed JSON, invalid JSON-RPC shapes, and their specified
error responses or failure statuses are later work. Do not add a competing
framing format or newline-delimited JSON fallback.

## Successful lifecycle and messages

Implement this exact successful serial lifecycle:

1. An `initialize` request receives the exact result below and enters the
   initialized state.
2. An `initialized` notification is accepted with no work and no response.
3. A `textDocument/didOpen` notification stores its document and receives no
   response.
4. A `textDocument/hover` request in the narrow domain below receives a Hover
   or JSON null.
5. A `shutdown` request receives a JSON null result and enters the shutdown
   state.
6. An `exit` notification receives no response and makes
   `run-lsp-server` return `0`.

Every response contains `"jsonrpc": "2.0"` and preserves the request's
number or string `id` without converting it. Notifications produce no
response. The initialize result is exactly:

```json
{
  "capabilities": {
    "positionEncoding": "utf-16",
    "textDocumentSync": {
      "openClose": true,
      "change": 1
    },
    "hoverProvider": true
  },
  "serverInfo": {
    "name": "aloe-lsp"
  }
}
```

Do not advertise completion, diagnostics, incremental synchronization, or
any other capability. Unsupported-message errors, requests before
initialization, repeated initialization, post-shutdown rejection,
`$/cancelRequest`, and `exit` before shutdown are not part of 000. Do not
invent alternate lifecycle messages while those cases are deferred.

## Open-document state and local file URI

`textDocument/didOpen` stores the exact `uri`, `version`, and `text` from its
`TextDocumentItem`, keyed by the exact URI string. Store `languageId` only if
convenient; it never changes Aloe semantics and is not used to filter a
document. Do not read Aloe from disk during `didOpen`.

For hover, accept only an opened URI that is an absolute local `file:` URI.
Use Racket's standard URI operations, such as `string->url` and `url->path`
from `net/url`, so percent escapes are decoded by the library. Reject a URL
whose scheme is not `file`, whose authority/host is nonempty, whose path is
not absolute, or which cannot be converted to a local filesystem path. Do not
splice, replace, or percent-decode URI text by hand and do not require an
`.aloe` filename extension.

If `net/url` introduces an undeclared package dependency, edit `info.rkt`
only to retain `"base"` and add `"net-lib"`. Add no third-party package or
network dependency.

The 000 queryable domain is intentionally narrower than the final adapter:

- every synchronized character is ASCII;
- line breaks are LF only, with no CR characters;
- the synchronized string's UTF-8 bytes exactly equal the bytes currently at
  the URI's local regular-file path; and
- the requested position converts validly under the rules below.

When an opened document is dirty, non-ASCII, contains CR, has no readable
matching regular file, uses an unsupported URI, or has an invalid position,
return JSON null for hover without calling the query. In particular, never
query a mismatching disk file. Dirty local buffers eventually use sibling
snapshots; null is the explicit safe checkpoint boundary until that slice.

Do not implement `textDocument/didChange` or `textDocument/didClose` in 000.
Do not write, rename, remove, or create a source or temporary file.

## ASCII/LF coordinate conversion

The client still speaks positions labeled `utf-16`, but every queryable 000
buffer is ASCII, so each source character is exactly one UTF-16 code unit.
Convert the incoming zero-based LSP `line` and `character` against the exact
synchronized string:

1. Split lines only at LF while retaining their absolute character offsets.
2. Find the zero-based character offset at the requested line's start.
3. Require `character` to be between zero and that line's content length,
   inclusive. The boundary immediately before LF is valid.
4. Add the line start and character offset, then add one for the one-based
   `query-expression-at` position.

An out-of-range or non-exact/nonnegative line or character returns JSON null
without a query call.

For a non-`#f` query result, derive the Hover range only from its returned
location's one-based `srcloc-position` `s` and span `n`. Convert absolute
zero-based offsets `s - 1` and `s - 1 + n` back to LSP line and character
against the synchronized text. The end is exclusive. If the start, span, or
either offset is invalid for that text, return JSON null rather than emitting
a misleading range. Never expose `srcloc-source` or a filesystem path.

Do not use `srcloc-line` or `srcloc-column` for either conversion. Do not
implement a byte-offset conversion. BMP, supplementary-plane characters,
split-surrogate rejection, CRLF, and lone CR are explicitly deferred; 000
must reject those buffers before applying its ASCII/LF converter.

For the normative ASCII fixture, LSP line `9`, character `7` addresses the
`n` in the final `new` selector and converts to expression-query position
`170`. The query selects the whole send at Racket position `163`, span `15`,
which converts back to LSP range line 9, characters 0 through 15.

## Query and Hover rendering

For one hover request in the queryable domain, call the supplied query
procedure exactly once with the converted local path and one-based position.
Do not query separately for type, rows, or range. Do not call it during open,
initialize, shutdown, or exit.

If the query returns `#f`, return JSON null. For an
`expression-query-result`, construct this LSP Hover:

```json
{
  "contents": {
    "kind": "plaintext",
    "value": "type: (Point Int)\nmessages:\n  x : () -> Int\n  y : () -> Int\n  + : ((Point Int)) -> (Point Int)\n  dist2 : ((Point Int)) -> Int"
  },
  "range": {
    "start": { "line": 9, "character": 0 },
    "end": { "line": 9, "character": 15 }
  }
}
```

The rendering is data-driven and deterministic:

1. Write the result type datum with Racket `write` after `type: `.
2. Append a newline and `messages:`.
3. For each returned `signature-spec` in existing order, append a newline,
   two spaces, its selector written with `write`, ` : `, its entire parameter
   list datum written with `write`, ` -> `, and its return datum written with
   `write`.

Do not sort, deduplicate, group, substitute, or invoke rows. Although the
Point fixture has four rows, production code must work from the returned
list and must not name Point, its selectors, or any List, String, or kernel
catalog entry. The final empty-row spelling `messages: none` is deferred from
000; do not add a special Point-shaped fallback.

Query/parser/checker/load exception classification and the final
`RequestFailed` behavior are not part of this happy-path checkpoint. Do not
add a broad exception handler that silently turns arbitrary adapter failures
into null. The recorded real query is complete and valid and does not raise.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt` (new);
- `info.rkt`, only if needed to add the `net-lib` dependency;
- `tests/editor/lsp/000-hover.rkt` (new); and
- `tests/editor/lsp/fixtures/point.aloe` (new).

Do not edit:

- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`;
- the LSP specification, charter, README, or another LSP checkpoint;
- `aloe/expression-query.rkt` or any parser, checker, evaluator, catalog,
  driver, host, or private Expression Query module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

If a real Point hover cannot be produced solely through the public Expression
Query result, if local file URI conversion requires manual decoding, or if
the successful exchange requires changing Aloe or the query, stop and return
the checkpoint for design review.

## Normative fixture

Add `tests/editor/lsp/fixtures/point.aloe` with exactly these ASCII bytes and
one LF after every shown line:

```aloe
(define-class (Point T)
  (fields
    (x T)
    (y T))
  (methods
    (+ (other (Point T)) (Point T)
      self)
    (dist2 (other (Point T)) T
      (self x))))
(Point new 1 2)
```

Do not load a fixture from another editor project's test directory. The local
copy makes this LSP slice's recorded protocol test self-contained.

## Required tests

Add `tests/editor/lsp/000-hover.rkt`. It is three directories below the
repository root, so use `../../../aloe/...` for repository-root module paths.
A fixture beside it may use `fixtures/point.aloe`.

Build test input as bytes from JSON values and canonical LSP headers; do not
call the server's private frame writer to construct its own test oracle.
Likewise, independently split and decode the server's output frames and
assert every declared Content-Length against the actual body byte count.

Cover at least:

1. The normal module exports `run-lsp-server` with arity three and does not
   export the test helper, query, result structures, row structures, framing
   helpers, document state, or converters. Requiring the module produces no
   output and starts no server.
2. One byte input port contains, without separators outside their framing:
   an `initialize` request with numeric id `1`, an `initialized`
   notification, a `didOpen` notification for the runtime Point fixture, a
   `textDocument/hover` request with string id `"point-hover"` at line 9,
   character 7, a `shutdown` request with numeric id `2`, and an `exit`
   notification.
3. The real `run-lsp-server` returns `0`, leaves all three caller ports open,
   writes nothing to the error port, and emits exactly three frames: the
   exact initialize result with id `1`, the exact Hover above with id
   `"point-hover"`, and a JSON null shutdown result with id `2`. There is no
   response for any notification and no unframed byte before, between, or
   after the responses.
4. The initialize capabilities contain exactly UTF-16, full sync, and hover.
   Prove completion and diagnostic capabilities are absent.
5. Through the test-support submodule, run the same successful exchange with
   a counting query stub. It is called exactly once, receives the local path
   represented by the percent-encoded file URI and position `170`, and its
   result alone supplies the rendered type, ordered rows, and range. In the
   test URI, encode at least one character of the final `point.aloe` segment
   (for example, `%70oint%2Ealoe`) so the standard URI-decoding boundary is
   observable even when the checkout path contains no spaces.
6. A hover for the same opened URI with an out-of-range line or character
   returns JSON null and makes zero stub calls. Keep the remaining shutdown
   and exit messages in the stream to prove the server continues.
7. Open text that differs by one byte from the Point file returns JSON null
   and makes zero stub calls. Assert the fixture's bytes are unchanged after
   the server returns; 000 must never query stale disk contents or create a
   sibling snapshot.
8. An unopened URI, a non-`file:` URI, and a remote-authority `file:` URI
   each yield JSON null with zero stub calls and do not kill the successful
   shutdown/exit lifecycle.
9. Read `aloe/lsp.rkt` as text and prove it has no require of the parser,
   checker, evaluator, driver, host, signature catalog, or Expression Query
   private modules. Prove it contains no Point row, kernel row, or library
   extension catalog. This architectural check must not ban the required
   public structure and accessor names.

Tests compare decoded JSON data, exact plaintext, exact row order, and exact
ranges rather than relying on object-key serialization order. At least the
real recorded exchange must inspect outbound framing at the byte level.

## Baseline suite note

The current branch has two unrelated failures already present before this
checkpoint, both in `tests/gel/presentations/003-doc-law.rkt`. They assert
older Gel-presentations handoff wording and experiment shape.

Do not edit or weaken those tests or their documentation. Require the focused
LSP suite to be completely green and the recursive suite to retain exactly
those two failures with no new failure. If that baseline contradiction has
been repaired before implementation starts, require a completely green
recursive suite.

## Hand check and acceptance

After the automated test, run one recorded interaction by hand from a Racket
REPL at the repository root. Construct the six canonical frames listed above
with the Point fixture's local file URI, pass byte ports to
`run-lsp-server`, and decode the three response bodies independently. Inspect
the hover response and confirm exactly:

```text
id: "point-hover"
type: (Point Int)
range: 9:0 through 9:15
rows: x, y, +, dist2 in that order
status: 0
```

Do not call `query-expression-at` separately as the hand check; the point is
to cross the framed LSP boundary.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when the real public query supplies the exact
Point Hover through concatenated framed messages, the counting path proves
one query call at position 170, unsafe inputs in the explicit 000 boundary do
not query stale disk, the focused suite is green, and the recursive suite has
no new failure. Stop for review without committing. Do not begin editor-lsp
001 or update the LSP README.

## Explicit non-goals

- No dirty-buffer sibling snapshot or file mutation of any kind
- No `didChange`, `didClose`, incremental synchronization, or cross-document
  overlay
- No non-ASCII, BMP, supplementary-plane, split-surrogate, CRLF, or lone-CR
  conversion
- No malformed framing/JSON recovery or JSON-RPC/LSP error matrix
- No complete invalid lifecycle, cancellation, or unsupported-request matrix
- No query/parser/checker/load failure classification or `RequestFailed`
- No empty-signature special rendering or overload-specific test
- No `main` submodule, installed-package launch, command-line arguments, or
  process-level smoke client
- No completion, diagnostics, diagnostic publication, or other LSP feature
- No VS Code extension or editor-specific client/configuration
- No second Aloe parser, checker, evaluator, dispatch rule, method table, or
  direct `type-signature-specs` call
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
