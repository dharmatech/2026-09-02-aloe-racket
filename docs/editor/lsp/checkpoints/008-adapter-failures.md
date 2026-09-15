# Editor LSP 008 — Recoverable Hover adapter failures

**Status.** Implemented and reviewed. The focused 10-test suite, the retained
86 tests from editor-lsp 000–007, and the required framed hand check are green.
The recursive suite reports 1,995 tests with exactly the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` failures and no additional failure.

## Goal

Complete the distinction between expected language-query outcomes and
unexpected failures while adapting a Hover result. A query miss or ordinary
exception raised by Expression Query remains an ordinary JSON null result. A
snapshot operation retains its exact snapshot-specific `RequestFailed`. A
non-`#f` value outside the public query result contract, or an ordinary
failure while validating, ranging, or rendering a returned query result,
receives a generic LSP `RequestFailed` (`-32803`) and leaves the active server
available.

The failure boundary ends before protocol output is written. An output-port
failure must not be caught and followed by a recursive attempt to write an
error to the same port. Breaks and other control exceptions also remain
uncaught.

This is the last in-process server-behavior slice. It does not add the `main`
submodule or process launcher; those remain one final separate checkpoint.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. Failure translation changes no Aloe
  syntax, parsing, checking, loading, evaluation, type, signature, or send
  behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 7 requires
  expected query failures to return null, unexpected adapter failures to
  return `RequestFailed`, and the server to remain available.
- Editor-lsp 003 owns sibling snapshot setup/cleanup and its exact
  snapshot-specific `-32803` response.
- Editor-lsp 004 owns the narrow query invocation boundary: `#f` and ordinary
  `exn:fail?` query failures become null, invalid returned ranges become null,
  and breaks are not caught.
- Editor-lsp 005–007 own framing, JSON-RPC validation, method parameters, and
  lifecycle precedence. Only a validated active-state Hover request reaches
  the adapter computation in this checkpoint.

Identity is `(editor-lsp, 008)`, spoken **editor-lsp 008**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit `CHECKPOINTS.md`,
add a file under `docs/checkpoints/`, or reopen a predecessor editor series.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

The private `run-lsp-server/with-query` seam retains its four-argument arity
and exercises the same failure boundaries as production. Neither entry point
closes caller-owned ports.

Keep framing, Parse Errors, JSON-RPC validation and ids, method roles and
params, lifecycle precedence/statuses, exact initialization capabilities,
atomic synchronization, URI handling, UTF-16 conversion, snapshot placement
and cleanup, relative loads, query-failure translation, exact Hover text, and
range behavior unchanged.

All 86 tests from editor-lsp 000–007 must remain green without editing a
predecessor test or checkpoint document. No accepted expectation is
superseded by 008.

## Three distinct Hover outcomes

After a Hover request passes envelope, active-state, method, parameter,
document, URI, and position validation, keep these outcomes distinct.

### 1. Expected null result

Return the ordinary success response with `result: null` when:

- the supplied query returns exactly `#f`;
- the supplied query invocation raises an `exn:fail?`, under 004's narrow
  boundary;
- no document/expression/valid position exists under the accepted rules; or
- a genuine `expression-query-result` has a source range that cannot be
  represented against synchronized text.

These responses have `result`, no `error`, and retain the request id. Query
exception text is not logged or exposed. A later request is processed
normally.

### 2. Snapshot RequestFailed

If sibling snapshot creation, writing, flushing, closing, or cleanup fails,
retain exactly:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32803,
    "message": "unable to create synchronized document snapshot"
  }
}
```

This response has no `result` or `data`. It remains higher priority than the
generic failure below, including when cleanup fails after a query returned an
invalid value or result.

### 3. Generic Hover-adapter RequestFailed

Return exactly this response for an unexpected ordinary failure after a query
outcome crosses into Hover adaptation:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32803,
    "message": "unable to produce hover result"
  }
}
```

It has no `result` or `data`, preserves a numeric or string id exactly, changes
no lifecycle/document state, and leaves the server available for subsequent
Hover, shutdown, and exit messages.

This generic outcome applies when:

- a supplied query procedure returns a value other than exactly `#f` or an
  `expression-query-result`;
- a result's signature collection cannot be traversed as the expected proper
  list;
- an item in that collection cannot be consumed through the imported
  `signature-spec` accessors; or
- another `exn:fail?` arises while converting the accepted result location,
  constructing its plaintext contents/range, or assembling the Hover JSON
  value.

The normal public Expression Query is expected to honor its result contract;
the private seam makes violations deterministic to test. Do not weaken or
change Expression Query to manufacture an adapter error.

## Narrow computation boundary

Preserve 004's handler immediately around the two-argument query procedure.
That inner handler alone translates a query-raised `exn:fail?` to `#f`. The
direct-path and snapshot-path calls continue to share it, and snapshot cleanup
still runs before result adaptation.

Add a separate outer outcome boundary around only the in-memory computation of
the Hover result. Conceptually it begins when the query has returned/translated
its value and ends when the adapter has either a complete Hover JSON value,
JSON null, or a classified failure ready to write. It may include the safe
document/URI/position computation when convenient, but it must preserve their
specified null cases.

The outer boundary must classify in this order:

1. private snapshot failures remain snapshot-specific RequestFailed;
2. other `exn:fail?` adapter failures become generic Hover-adapter
   RequestFailed; and
3. `exn:break?` and non-failure control escapes are not caught.

Do not merely add a broad `exn:fail?` handler around the existing Hover branch.
The response writer, loop recursion, later frame reads, JSON-RPC dispatcher,
and lifecycle transitions must be outside the computation boundary. First
compute a private tagged outcome or equivalent; then write exactly one success
or error response through the normal writer; then continue the loop.

This placement prevents a failed `write-response` or `flush-output` from being
misclassified and retried as `RequestFailed`. It also prevents framing,
decoder, validation, and lifecycle failures from acquiring a Hover id or
message.

Do not inspect exception messages, source paths, stack marks, or private Aloe
exception types to choose an outcome. Do not log the underlying exception in
this checkpoint. The supplied error-output port remains empty for every tested
recoverable Hover outcome.

## Query result contract

After the narrow query invocation returns:

- exactly `#f` is an expected miss/failure result and becomes JSON null;
- a value satisfying `expression-query-result?` is adapted using only its
  existing public accessors; and
- every other returned value is an unexpected contract violation and becomes
  generic RequestFailed.

Do not treat arbitrary false-like or empty values as misses. In Racket only
`#f` is false, so values such as `(void)`, JSON null, an empty list, a number,
a string, or an unrelated struct are adapter failures here.

For a genuine query result, retain the accepted range policy. A location that
is not an `srcloc`, has invalid position/span values, falls outside the
synchronized string, or lands inside CRLF produces expected JSON null. It is
not a generic failure merely because no valid range can be formed.

Retain exact rendering for valid results: type and row datums use Racket
`write`, empty rows render `messages: none`, and repeated rows retain list
order. Do not import `signature-spec?`, a parser/checker predicate, or any
catalog operation solely to prevalidate rows. The existing public accessors
plus the narrow adapter-failure boundary are sufficient.

## Snapshot and lifecycle interaction

For a dirty or missing root, the query still runs through one complete sibling
and cleanup finishes before result adaptation. Therefore a malformed returned
value or signature list cannot strand a snapshot. The original file remains
untouched, a missing root remains missing, and unrelated directory entries do
not change.

After generic RequestFailed, remain in the active state with the same open
documents and synchronized text. A later valid Hover for the same URI may
query independently and succeed. A later shutdown/exit completes with status
0.

Pre-initialize requests, post-shutdown requests, invalid params, unsupported
methods, ignored notifications, Parse Errors, and fatal framing never enter
the new outcome boundary. Their exact 005–007 precedence remains unchanged.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/008-adapter-failures.rkt` (new).

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, any prior LSP test, or
  the Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

No checked-in fixture is needed. Tests may create and unconditionally remove
exact temporary files/directories and may use existing fixtures read-only. If
recovery requires changing a public export, classifying query exceptions as
errors, catching response writes or breaks, changing snapshot semantics, or
weakening a predecessor test, stop and return the checkpoint for design
review.

## Required tests

Add `tests/editor/lsp/008-adapter-failures.rkt`. It is three directories below
the repository root, so use `../../../aloe/...` for repository-root module
paths. Construct/decode canonical frames independently and use the private
query seam only to inject query results that the real public query never
returns.

Cover at least:

1. On an unchanged direct-path document, a stateful query stub first returns a
   number or unrelated value, then a valid query result. The first Hover gets
   exact generic RequestFailed, the second gets the exact successful Hover,
   both calls use the original path/position, and shutdown/exit returns 0.
2. Table-drive other non-result returns, including `(void)`, JSON null, empty
   list, string, and unrelated transparent struct. Use numeric and string ids;
   each receives generic RequestFailed with no `result` or `data` and exactly
   one query call.
3. Return an `expression-query-result` whose signatures field is not a proper
   list, then one whose list contains a non-`signature-spec` value. Each gets
   generic RequestFailed without exposing a contract exception. A following
   valid result still renders normally and retains row order.
4. Repeat a representative malformed-result case on a dirty existing root or
   missing root. During the query, prove the snapshot is a complete sibling.
   Before inspecting the error response, prove the snapshot is gone, the
   original bytes/existence are unchanged, and directory entries are restored.
5. In one comparison exchange, make the query raise a distinctive `exn:fail?`,
   return `#f`, return a valid result with an invalid range, return a malformed
   non-result, and finally return a valid result. Assert respectively null,
   null, null, generic RequestFailed, and successful Hover. This locks the
   boundary rather than merely testing that exceptions do not escape.
6. Retain a deterministic snapshot-setup failure and assert its exact
   snapshot-specific message, not the generic Hover message. It makes zero
   query calls and a later shutdown/exit still returns 0.
7. Assert generic failures preserve exact ids, lifecycle state, open document
   text, query call count, canonical framing, response order, and continued
   service.
8. Assert neither protocol nor error output contains the injected value's
   printed representation, query/contract exception text, source path,
   snapshot path, continuation marks, diagnostics, or unframed bytes.
9. Prove response writing is outside the adapter computation boundary. Use a
   purpose-built failing output port or a narrow source assertion to show an
   output write/flush failure is not caught and retried as a second error
   response. Do not require continued service from a failed protocol output
   stream.
10. Prove the normal module remains inert with its exact public surface,
    caller-owned ports remain open on recoverable outcomes, and the normal
    public-query path still returns expected null/success values rather than
    generic failures.
11. Read production source narrowly enough to prove there is no exception-
    message classification, parser/checker/catalog import, broad `exn?`
    handler, or second query call. Runtime outcome tests are primary; do not pin
    private helper names or whitespace.
12. All prior LSP suites remain green without modification. Their exact query
    exception nulls, invalid-range nulls, snapshot error, framing/JSON-RPC
    errors, lifecycle precedence/status, and successful Hover behavior remain
    unchanged.

For injected malformed results, use the real public
`expression-query-result` constructor so the failure occurs after the adapter
accepts the outer result, except in cases explicitly testing a non-result
return. Do not monkey-patch modules or reach into private server state.

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

After automated tests, run one framed interaction by hand from a Racket REPL
at the repository root through `run-lsp-server/with-query`:

- initialize and open an unchanged local document;
- make a stateful stub return an unexpected non-result for the first Hover and
  a valid result for the second;
- inspect exact generic `-32803` then exact successful Hover with their
  original ids;
- shut down and exit with status 0; and
- confirm canonical protocol-only output, empty error output, unchanged source
  bytes, and open caller-owned ports.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests/editor/lsp/004-hover-results.rkt
raco test tests/editor/lsp/005-framing.rkt
raco test tests/editor/lsp/006-json-rpc.rkt
raco test tests/editor/lsp/007-lifecycle.rkt
raco test tests/editor/lsp/008-adapter-failures.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when expected query nulls, snapshot failures, and
generic Hover-adapter failures are distinct; generic failures are exact and
recoverable; malformed results cannot strand snapshots; response writing and
breaks remain outside the catch; all prior suites remain green; and the
recursive suite has no new failure. Stop for review without committing. Do
not begin editor-lsp 009.

## Explicit non-goals

- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No recovery from output-port failure, break, non-`exn:fail` raised value,
  out-of-memory condition, or process termination
- No new JSON-RPC, lifecycle, framing, synchronization, URI, position,
  snapshot, query, Hover, or exit-status semantics beyond the classified
  adapter failure
- No additional LSP method/capability, completion, diagnostics, or diagnostic
  publication
- No request concurrency, worker pool, cancellation execution, request
  reordering, or progress messages
- No incremental synchronization, dirty loaded-document overlay, workspace
  indexing, or caching
- No changes to Expression Query, selection, source locations, checking,
  loading, type/signature datums, or valid Hover text
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No VS Code extension or other editor-specific client/configuration
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
