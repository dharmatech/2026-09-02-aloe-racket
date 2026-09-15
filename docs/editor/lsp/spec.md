# LSP adapter

**Status.** Design specification for the local `editor-lsp` project. Not Aloe
language law, not an implementation checkpoint, and not a global checkpoint.
The human reviews this file before a later checkpoint-manager conversation
slices it.

**Authority.** [`../expression-query/spec.md`](../expression-query/spec.md)
owns expression selection, contextual type inference, signature rows, source
locations, complete-file checking, and query failure behavior. `SPEC.md`
remains Aloe language law. This adapter follows the
[Language Server Protocol 3.17](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/)
base protocol and the messages named below. It translates between that
protocol and the public `query-expression-at` operation; it does not add a
second parser, checker, or method catalog.

---

## 1. Result and first method

The result is a Racket process that speaks JSON-RPC/LSP over standard input
and standard output. A new module, `aloe/lsp.rkt`, provides:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

The three arguments are the server's byte input, protocol output, and logging
output ports. The operation processes messages until `exit`, unrecoverable
framing failure, or end of input, then returns the process status described in
section 8. It does not close caller-owned ports.

The module has a `main` submodule that passes the current input, output, and
error ports to `run-lsp-server` and exits with the returned status. It accepts
no command-line arguments.

The first and only language feature in this experiment is
`textDocument/hover`. When this project is later sliced, the first issued
checkpoint must end with an end-to-end hover request that calls
`query-expression-at`; a transport-only result is not the completed first
slice.

Completion is not part of this experiment. In particular, the adapter does
not pretend that querying an already complete send solves completion at a
missing selector. Diagnostics are also out: editor-source-locations 001 does
not exist, and the expression query deliberately returns neither partial
answers nor location-bearing errors. The server never advertises completion
or diagnostics and never sends `textDocument/publishDiagnostics`.

There is no VS Code extension or other editor-specific client in this
experiment. Recorded protocol tests are the smoke client.

## 2. Thin dependency boundary

`aloe/lsp.rkt` imports `aloe/expression-query.rkt` and uses:

- `query-expression-at`;
- the `expression-query-result` accessors; and
- the re-exported `signature-spec` accessors.

It must not import the Aloe parser, evaluator, checker internals, private
expression selection, or a declaration/method table. It must not call
`type-signature-specs` itself. One valid hover position causes exactly one
call to `query-expression-at`; the returned result is the sole source of the
displayed type, rows, and expression range.

The adapter never evaluates Aloe code and never invokes a host capability.
It adds no Aloe syntax, special form, implicit call, coercion, or dispatch
rule. Function values therefore continue to expose `call` only because that
row came from the expression query's existing catalog.

## 3. Protocol framing and server lifecycle

The protocol stream uses the LSP 3.17 base framing:

```text
Content-Length: <UTF-8 byte count>\r\n
\r\n
<one UTF-8 JSON value>
```

The server reads and writes bytes. `Content-Length` is the byte length of the
UTF-8 JSON body, not its character count. Standard output contains only
framed protocol messages; debugging and failure text may go only to the
supplied error port. Responses retain the request's number or string `id`.

Once a complete frame is known, malformed JSON produces the JSON-RPC parse
error `-32700` with a null id and the server continues. A header or length
error from which the next frame cannot be found is unrecoverable and ends the
server with failure status. Invalid request shapes produce `-32600`, invalid
parameters produce `-32602`, and unsupported requests produce `-32601`.
Unsupported notifications are ignored and receive no response.

The implemented lifecycle messages are:

- `initialize` request;
- `initialized` notification;
- `shutdown` request; and
- `exit` notification.

Before a successful `initialize`, requests other than `initialize` receive
the LSP `ServerNotInitialized` error. A second `initialize` is invalid. The
`initialized` notification requires no work. `shutdown` responds with a null
result and enters the shutdown state. After shutdown, the server accepts only
`exit`; other requests receive `InvalidRequest` and other notifications are
ignored. `exit` itself has no response.

The server ignores `$/cancelRequest`: requests are processed serially, so
there is no concurrent query to cancel in this experiment. It creates no
worker pool and does not reorder document notifications and hover requests.

## 4. Initialization and document synchronization

The initialize result advertises exactly the capabilities needed here:

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

`change: 1` is `TextDocumentSyncKind.Full`. The server always chooses and
advertises UTF-16 positions. UTF-16 is the LSP compatibility encoding, so no
client-specific position mode or negotiation branch is needed.

The server implements these synchronization notifications:

- `textDocument/didOpen` stores the exact `uri`, `version`, and `text` from
  the `TextDocumentItem`;
- `textDocument/didChange` applies each full-content change in order by
  replacing the stored text, leaving the last item as the current text, and
  records the supplied version; and
- `textDocument/didClose` forgets that URI.

A full-content change has a `text` field and no `range`. The adapter does not
implement incremental changes. A malformed synchronization notification is
ignored rather than partially changing document state, because notifications
cannot receive error responses.

Documents are keyed by the exact URI sent by the client. The adapter handles
only absolute local `file:` URIs that Racket can convert to filesystem paths.
It percent-decodes them through a standard URI operation; it does not splice
or replace URI text by hand. It makes no filename-extension or VS Code API
assumption. Non-file, remote-authority, malformed, and unopened document URIs
have no hover result.

The language identifier and extension do not alter Aloe semantics. A client
is responsible for sending Aloe documents to this server.

## 5. Querying a synchronized buffer

Hover must describe the server's synchronized document text, including
complete unsaved edits. It must not silently query stale disk contents.
Because `query-expression-at` deliberately accepts a path rather than a
source string, the adapter supplies that path as follows:

1. Encode the synchronized Racket string as UTF-8 bytes.
2. If those bytes exactly equal the bytes currently at the document's local
   path, call `query-expression-at` on that path.
3. Otherwise, create a uniquely named temporary regular file in the
   document path's parent directory, write exactly those bytes, call
   `query-expression-at` on the temporary path, and remove the file in an
   unconditional cleanup action.

The original document is never overwritten, renamed, or removed. A temporary
file is not retained after success or failure. It is a sibling, rather than a
file in the system temporary directory, so an Aloe `load` in the root buffer
continues to resolve relative to the root document's directory. The adapter
does not copy, parse, or rewrite `load` forms.

Loaded files continue to come from disk through the expression query. An
unsaved edit in a different open document is not substituted into a load in
v0. Cross-document snapshots and workspace overlays are separate designs.

The `srcloc-source` in a result may consequently name either the document or
its temporary sibling. That source name is an internal query detail. Hover
uses the result's position and span against the synchronized text and never
exposes the temporary path to the client.

If the buffer differs from disk and its parent directory cannot hold a
temporary sibling, hover returns a request failure rather than querying stale
contents. Read-only unchanged files remain queryable through step 2.

## 6. UTF-16 positions and Racket source positions

An LSP `Position` is a zero-based line plus a zero-based count of UTF-16 code
units within that line. The expression query instead takes the one-based
character position used by Racket `srcloc-position`. Conversion always uses
the exact synchronized string, never `srcloc-line` or `srcloc-column`.

For conversion, a line break is LF, CRLF, or a lone CR. CRLF is one LSP line
break but remains two Racket characters in the absolute position count. A
Racket character at or below `#xFFFF` occupies one UTF-16 code unit; a
character above it occupies two.

To convert an incoming hover position:

1. Find the zero-based Racket-character offset at the start of the requested
   line.
2. Walk characters before that line's terminator until their UTF-16 widths
   sum exactly to the requested `character`.
3. Add that character count to the line start, then add one to obtain the
   expression-query position.

An out-of-range line or character, or a UTF-16 offset that splits a
supplementary character's surrogate pair, has no hover result. The boundary
at the end of a line is valid and maps to the absolute position immediately
before its line terminator.

The hover range comes from the returned expression location. If its one-based
start is `s` and its span is `n`, convert absolute Racket-character offsets
`s - 1` and `s - 1 + n` back to LSP positions by counting line breaks and
UTF-16 widths. The end is exclusive. If either offset is outside the
synchronized string or falls inside CRLF, treat the result as invalid rather
than returning a misleading range.

For ASCII, this locks the simple case: LSP line 9, character 0 for the
normative Point fixture becomes expression-query position 163. A hover on the
`new` selector calls the query at that selector's character position, and the
query's existing selection rule returns the whole send.

## 7. Hover result

`textDocument/hover` accepts ordinary `TextDocumentPositionParams`. A valid
request for an open local document runs the conversion and query above.

The successful JSON result is a `Hover` with plaintext `MarkupContent` and a
range for the selected expression:

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

The value is deterministic:

1. `type: ` followed by the result type datum written with Racket `write`;
2. a newline and `messages:`; and
3. for each `signature-spec`, in the query's existing order, a newline, two
   spaces, the selector written with `write`, ` : `, the entire parameter
   list datum written with `write`, ` -> `, and the return datum written with
   `write`.

An empty signature list renders `messages: none` on the second line. The
adapter does not sort, deduplicate, group overloads, substitute types, or
invoke signatures.

The hover result is JSON null when:

- no expression owns the position;
- the document is unopened or is not a supported local file URI;
- the LSP position is invalid;
- the synchronized file is incomplete, malformed, or fails Aloe checking; or
- a root or loaded source file needed by the query cannot be read.

These are not diagnostics and are not turned into hover prose. An unexpected
adapter failure, including inability to create a required sibling snapshot,
produces the LSP `RequestFailed` error `-32803`. In every case the server
remains available for the next message unless framing itself was lost.

## 8. Launch and exit status

After the Aloe package is installed or linked into the selected Racket
installation, the one supported launch command is:

```text
racket -l aloe/lsp
```

A client locates the `racket` executable through `PATH`; the `-l` module path
locates this package through that Racket installation's collection paths.
There is no configuration file, Node launcher, TypeScript process, shell
wrapper, workspace scan, TCP port, or extension-owned server copy.

An `exit` received after `shutdown` returns status 0. `exit` before shutdown,
end of input before the lifecycle completes, invalid command-line arguments,
or unrecoverable protocol framing returns a nonzero status. Query failures and
null hover results do not terminate the process.

## 9. Required coverage for later slices

The completed implementation must prove at least:

- byte-accurate `Content-Length`, concatenated frames, request-id retention,
  JSON-RPC errors, and a clean protocol-only standard output;
- initialize, initialized, shutdown, and exit behavior, including exit
  statuses;
- the exact advertised UTF-16, full-sync, and hover capabilities, with no
  completion or diagnostic capability;
- didOpen, multiple full didChange replacements, and didClose state;
- ASCII, BMP, supplementary-plane, LF, CRLF, lone-CR, line-end,
  out-of-range, and split-surrogate position conversion in both directions;
- a recorded initialize/open/hover/shutdown/exit exchange using the normative
  Point fixture, including its type, all four ordered and typed rows, and the
  exact whole-send range;
- hover over a selector calls the public expression query rather than treating
  the selector as an expression;
- synchronized text differing from disk is queried, the user's file is never
  changed, a temporary sibling is always removed, and a relative `load`
  still resolves from the document directory;
- unchanged text can be queried from a read-only document path without a
  sibling snapshot;
- query misses, top-level gaps, incomplete input, parser failure, checker
  failure, missing loads, unsupported URIs, unopened documents, and invalid
  positions yield null without killing the server;
- an empty signature list and repeated selector overloads render exactly,
  without sorting or deduplication; and
- requiring `aloe/lsp.rkt` does not start the server, while the documented
  command runs it over stdio without a human editor action.

Production LSP code must not contain Point rows, kernel rows, List/String
extension names, or declaration traversal. Tests may name fixture rows when
asserting the expression query's exact serialized result.

## 10. Deferred work and non-goals

- Completion, selector holes, incomplete-buffer recovery, and speculative
  parsing
- Diagnostics, checking past the first error, and source-locations 001
- Incremental text synchronization and concurrent/cancelable queries
- Dirty overlays for loaded documents, workspace indexing, and caching
- Rename, definition, references, formatting, semantic tokens, code actions,
  and signature help
- Non-file documents, remote filesystems, and TCP or WebSocket transport
- A VS Code extension, themes, snippets, and wrap-preceding-expression
- Emacs or Neovim client configuration
- Gel UI or evaluation of an Aloe program
- A TypeScript/JavaScript parser, checker, dispatcher, or method table
- Changes to `query-expression-at`, `srcloc`, type datums, or
  `signature-spec`

When the implementation satisfies this specification, stop. A later local
checkpoint-manager conversation decides the slices under
`docs/editor/lsp/checkpoints/`; this specification does not create them.
