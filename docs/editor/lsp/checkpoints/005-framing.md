# Editor LSP 005 — Byte framing and JSON parse recovery

**Status.** Implemented and reviewed. The focused 13-test suite, the retained
42 tests from editor-lsp 000–004, and both required raw-byte hand checks are
green. The recursive suite passes 1,952 of 1,954 tests; its only failures are
the two pre-existing `tests/gel/presentations/003-doc-law.rkt`
contradictions. This checkpoint introduces no additional failure.

## Goal

Complete the LSP byte-message boundary without changing JSON-RPC dispatch or
language behavior. The server accepts the LSP 3.17 header block, reads exactly
one declared UTF-8 body at a time, and continues across concatenated frames.
Once a complete body boundary is known, malformed UTF-8 or malformed JSON
receives the JSON-RPC Parse Error `-32700` with a null id and the server remains
available for the next frame.

A malformed header, invalid length, premature end of a header, or short body
cannot be safely recovered in this serial stream. It writes no speculative
protocol response, ends the server, and makes `run-lsp-server` return a
nonzero exact integer rather than raising to its caller.

This checkpoint handles framing and JSON decoding only. A complete, valid JSON
value that is not a valid JSON-RPC request or notification remains for the next
checkpoint, as do method/parameter validation and the lifecycle error matrix.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. Framing changes no Aloe source,
  selection, checking, loading, type, signature, or evaluation behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 3 defines
  byte framing, recoverable malformed JSON, unrecoverable header/length
  failure, protocol-only output, and continued service. Section 8 defines
  nonzero status for lost framing or premature input end.
- The LSP 3.17 base protocol linked by the local spec defines the ASCII header
  part, required `Content-Length`, optional UTF-8 `Content-Type`, CRLF
  separators, and UTF-8 JSON content.
- Editor-lsp 000–004 are implemented and reviewed. Their public query,
  synchronization, position, snapshot, Hover, successful-lifecycle, and
  caller-port behavior remain the payload consumer behind this boundary.

Identity is `(editor-lsp, 005)`, spoken **editor-lsp 005**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit `CHECKPOINTS.md`,
add a file under `docs/checkpoints/`, or reopen a predecessor editor series.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

The private `run-lsp-server/with-query` test-support operation retains its
four-argument arity and uses the same frame reader, decoder, writer, and
failure statuses as the normal server. Neither operation closes a caller-owned
port.

Keep the exact initialization result, successful initialize/open/hover/
shutdown/exit exchange, request-id retention, document synchronization,
UTF-16 conversions, original/snapshot query choice, cleanup, query-failure
translation, and Hover rendering unchanged. A valid queryable Hover still
calls Expression Query exactly once.

All 42 tests from editor-lsp 000–004 must remain green without editing a
predecessor test or checkpoint document. No accepted behavior is intentionally
superseded by 005.

## Input is a byte stream

Read the supplied input as bytes. One input message has:

```text
<one or more ASCII header fields terminated by CRLF>
CRLF
<exactly Content-Length body bytes>
```

Do not use character ports, `read-line` on decoded text, newline-delimited
JSON, s-expressions, or an EOF read of the whole protocol stream. Do not search
inside a body for a following header. The only body boundary is its declared
byte count.

Read and finish exactly one frame before dispatching it. After a recoverable
JSON parse error or a normally processed message, begin the next header at the
immediately following byte. Concatenated frames need no whitespace or other
separator after the preceding body.

An EOF encountered before the next frame begins is premature lifecycle input
and returns nonzero as already required. EOF after any partial header line,
inside the header block, or before all declared body bytes arrive is an
unrecoverable framing failure and also returns nonzero.

## Header block

Every header line and the empty line ending the header block must use the
two-byte sequence CRLF. LF alone, CR alone, or EOF is not a valid terminator.
Header bytes must be ASCII. Each nonempty line has exactly a field name, colon,
one ASCII space, and value. Do not accept a body before the empty CRLF line.

Header field names are ASCII case-insensitive. Accept exactly these fields:

- `Content-Length`, required exactly once; and
- `Content-Type`, optional at most once.

The fields may appear in either order. A missing or duplicate
`Content-Length`, duplicate `Content-Type`, unknown field, non-ASCII header,
missing `: ` separator, empty name/value, or extra malformed header line is an
unrecoverable framing failure.

The `Content-Length` value consists of one or more ASCII decimal digits and
denotes a nonnegative exact integer number of body bytes. Leading zeroes are
allowed. Do not accept a sign, decimal point, exponent, Racket numeric prefix,
surrounding whitespace, trailing text, negative value, or non-number. Do not
infer the length from a closing brace or the next apparent header.

Absent `Content-Type` means UTF-8. When present, accept the LSP UTF-8 media type
with either current or legacy charset spelling, compared ASCII
case-insensitively:

```text
application/vscode-jsonrpc; charset=utf-8
application/vscode-jsonrpc; charset=utf8
```

Any other media type, charset, or malformed `Content-Type` is an unrecoverable
header failure. The server does not transcode UTF-16, UTF-32, Latin-1, or a
locale encoding.

Production output remains simpler and canonical: write exactly one
`Content-Length: <decimal>\r\n` field, one empty CRLF line, and the UTF-8 JSON
body. Do not add `Content-Type` to output.

## Exact body reads

After a valid header block, read exactly the declared number of bytes:

- fewer bytes before EOF is unrecoverable framing failure;
- exactly zero bytes is a complete frame whose empty body is malformed JSON;
- bytes that resemble CRLF or `Content-Length:` inside the body are ordinary
  body bytes;
- bytes after the declared count begin the next frame, even when the current
  body is malformed JSON; and
- a valid non-ASCII JSON string is counted by UTF-8 bytes, not Racket
  characters or UTF-16 units.

Do not impose a source-file encoding rule here. This body is protocol JSON;
the synchronized Aloe `text` member becomes a Racket string only after JSON
decoding and retains the behavior established by earlier checkpoints.

## Recoverable JSON parse error

Once the header and exact body length have been consumed, decode that body as
one UTF-8 JSON value. Treat each of these as a JSON parse failure:

- invalid UTF-8;
- an empty body;
- truncated or syntactically malformed JSON wholly contained in the body;
- trailing non-whitespace text after an otherwise complete JSON value; or
- any ordinary decoder failure while reading that bounded body.

Respond with exactly:

```json
{
  "jsonrpc": "2.0",
  "id": null,
  "error": {
    "code": -32700,
    "message": "Parse error"
  }
}
```

The error has no `result` or `data`. Frame and flush it through the ordinary
protocol writer. Do not quote the bad bytes, decoder exception, source path,
or request text in the response.

Parsing happens before JSON-RPC lifecycle and request validation. Therefore a
parse error has a null id even if the malformed bytes visibly contain an
`"id"` fragment, and it receives the same response before initialization,
after initialization, or before shutdown. It does not initialize, shut down,
open/change/close a document, call the query, or otherwise mutate state.

After writing the Parse Error, immediately read the next frame in the same
server state. A following valid initialize, synchronization, Hover, shutdown,
or exit message is processed normally. Multiple complete malformed bodies
produce one Parse Error apiece.

Catch only ordinary failures from decoding the already bounded body. Do not
catch `exn:break?`, a dispatcher failure, an adapter failure, a query break, a
snapshot failure, a response-write failure, or an exception from reading an
unbounded/short frame and call it a Parse Error.

## Unrecoverable framing failure

Represent header/body-boundary failure privately so the server entry point can
return a nonzero exact integer without leaking an exception to its caller. A
framing failure produces no JSON-RPC response because no reliable request
boundary or id exists. It does not scan, discard, or retry in search of a later
`Content-Length` line.

Responses successfully written for earlier frames remain intact. Do not append
an unframed error, partial JSON object, guessed Parse Error, or status text to
the protocol output. Concise logging may go only to `error-output`, but no test
or client behavior may depend on exact log wording and no body contents should
be copied there.

Return a nonzero exact integer for at least:

- EOF before `exit`, whether it occurs at a frame boundary or mid-frame;
- invalid, missing, duplicated, or unsupported headers;
- an invalid `Content-Length` value;
- a missing CRLF header terminator or missing empty line; and
- a body shorter than its declared byte length.

Use one failure status consistently; status `1` is the established value. Do
not close the input, output, or error-output port on this path. Do not call the
query or mutate document state for an incomplete frame.

## Valid JSON is not request validation

A complete body that decodes to a JSON value has passed this checkpoint's
parser, even if the value is an array, scalar, or object with a missing or
wrong-shaped `jsonrpc`, `id`, `method`, or `params` member. Those values are not
Parse Errors. Their `InvalidRequest`, `InvalidParams`, `MethodNotFound`, and
lifecycle handling belongs to the next checkpoint.

Do not add piecemeal dispatch validation in 005. Tests for 005 may send only
the already accepted well-shaped messages after successful decoding. This
keeps transport recovery independent of the later request state machine.

Likewise, do not change malformed synchronization notification behavior:
after a well-shaped JSON-RPC notification reaches the existing sync reducer,
the reducer still ignores malformed document parameters atomically and emits
no response.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/005-framing.rkt` (new).

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, any prior LSP test, or
  the Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

No checked-in fixture is needed. Tests may construct protocol bytes directly
and may use existing fixtures read-only. If framing requires an external
package, changing a public export, changing Expression Query, weakening a
prior test, or decoding beyond a declared body boundary, stop and return the
checkpoint for design review.

## Required tests

Add `tests/editor/lsp/005-framing.rkt`. It is three directories below the
repository root, so use `../../../aloe/...` for repository-root module paths.
Construct every input frame independently of production. Decode every output
frame independently and compare each declared length to the actual UTF-8 body
byte count.

Cover at least:

1. The complete accepted Point exchange still arrives as six immediately
   concatenated canonical frames and produces the same three responses and
   status 0. This is retained behavior, not a replacement for 000.
2. A successful exchange accepts an optional canonical `Content-Type` before
   or after `Content-Length`, accepts the legacy `charset=utf8`, and treats
   field names case-insensitively. Output still contains only canonical
   `Content-Length` headers.
3. Use a string request id and JSON parameter containing BMP and
   supplementary characters. Prove input and output lengths are UTF-8 byte
   counts, the next concatenated frame starts at the exact boundary, and the
   id is retained.
4. Put actual CRLF whitespace between tokens inside a valid JSON body and put
   the ASCII text `Content-Length:` inside one of its JSON strings. Prove
   neither terminates or reframes the body.
5. Send a complete syntactically malformed JSON body followed immediately by
   valid initialize, shutdown, and exit frames. Assert the exact Parse Error
   above comes first, then the ordinary initialize and shutdown responses,
   and status is 0.
6. In an initialized exchange, send separate bounded frames containing an
   empty body, invalid UTF-8, truncated JSON, and valid JSON followed by junk.
   Assert one exact Parse Error per body, continued service after each, a
   later valid request response, and clean shutdown/exit.
7. Put an `"id"` fragment in malformed JSON and prove the Parse Error id is
   still JSON null. Use both initialized and uninitialized states and prove a
   parse error does not change the state.
8. Table-drive fatal headers: LF-only and CR-only endings, missing empty line,
   missing/duplicate `Content-Length`, duplicate `Content-Type`, unknown
   header, non-ASCII header bytes, missing `: `, empty length, signed/negative/
   decimal/exponent/prefixed/trailing-junk lengths, and unsupported charset.
   Each run returns status 1, calls the query zero times, and writes no response
   for the bad frame.
9. Table-drive premature EOF before a header, within a header line, after a
   completed header but before the declared body, and partway through a body.
   Each returns status 1 without raising, closes no caller port, makes no query
   call, and does not emit a Parse Error.
10. Precede a fatal frame with a valid initialize request. Its already written
    response remains one complete valid frame; no partial or unframed output is
    appended for the fatal frame, and the final status is 1.
11. Follow representative fatal input bytes with a complete valid-looking
    frame and prove the server does not resynchronize to or process it.
12. Prove requiring the normal module remains inert, the normal public surface
    is unchanged, successful/error output uses the supplied ports, and no
    caller-owned port is closed on status 0 or 1.
13. Read production source narrowly enough to prove framing uses byte
    operations and no newline-delimited JSON or whole-stream fallback was
    introduced. Runtime boundary tests remain the primary evidence; do not
    pin private helper names or whitespace.
14. All prior LSP suites remain green without modification. Exact query call
    counts, snapshot cleanup, null query failures, rendering, synchronization,
    UTF-16 conversion, and successful lifecycle behavior remain unchanged.

For fatal-case tables, build a fresh input and fresh caller-owned ports for
each case. Do not depend on a particular decoder's exception text, operating
system newline mode, locale, or terminal behavior.

## Baseline suite note

The current branch has two unrelated failures already present before this
checkpoint, both in `tests/gel/presentations/003-doc-law.rkt`. They assert
older Gel-presentations handoff wording and experiment shape.

Do not edit or weaken those tests or their documentation. Require all focused
LSP suites to be completely green and the recursive suite to retain exactly
those two failures with no new failure. If that baseline contradiction has
been repaired before implementation starts, require a completely green
recursive suite.

## Hand check and acceptance

After the automated tests, run two raw byte interactions by hand from a Racket
REPL at the repository root:

- first, send a correctly length-delimited malformed JSON body immediately
  followed by valid initialize, shutdown, and exit frames; inspect the exact
  null-id Parse Error, normal later responses, status 0, and protocol-only
  framed output;
- second, send a header declaring more body bytes than are present; inspect no
  response for it, status 1 rather than an escaped exception, and open
  caller-owned ports.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests/editor/lsp/004-hover-results.rkt
raco test tests/editor/lsp/005-framing.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when header/body framing is byte-exact, complete
malformed JSON yields one recoverable Parse Error and continued service,
unrecoverable framing returns status 1 without raising or fabricating a
response, valid transport behavior and all prior suites remain green, and the
recursive suite has no new failure. Stop for review without committing. Do
not begin editor-lsp 006.

## Explicit non-goals

- No InvalidRequest, InvalidParams, MethodNotFound, ServerNotInitialized,
  repeated-initialize, post-shutdown, or cancellation behavior
- No validation of decoded JSON-RPC object, id, method, or params shapes
- No new recovery for unexpected dispatcher, adapter, rendering, snapshot,
  output-port, or query-break failures
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No additional LSP method, completion, diagnostics, diagnostic publication,
  or editor-specific client/configuration
- No incremental synchronization, dirty loaded-document overlay, workspace
  indexing, caching, concurrency, or request reordering
- No changes to Expression Query, selection, source locations, checking,
  loading, type/signature datums, or Hover text
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
