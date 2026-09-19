# Editor LSP 006 — Decoded JSON-RPC validation

**Status.** Implemented and reviewed. The focused 14-test suite, the retained
55 tests from editor-lsp 000–005, and the required raw framed hand check are
green. The recursive suite passes 1,966 of 1,968 tests; its only failures are
the two pre-existing `tests/gel/presentations/003-doc-law.rkt`
contradictions. This checkpoint introduces no additional failure.

## Goal

Validate each successfully decoded JSON value before method code touches it.
The server distinguishes valid JSON-RPC requests from notifications, returns
the exact `InvalidRequest`, `MethodNotFound`, and `InvalidParams` errors for
requests, ignores unsupported or malformed notifications as required, and
continues processing later messages.

This checkpoint removes dispatcher crashes caused by arrays, scalars, missing
members, wrong member types, invalid request ids, unsupported methods, and
malformed request parameters. It also prevents request-only methods sent as
notifications from changing state or running a query.

Lifecycle order is deliberately still separate. Editor-lsp 006 does not yet
enforce ServerNotInitialized, reject repeated initialization, or lock down the
post-shutdown state. Those rules require one state-machine checkpoint after
the message envelope and method roles are trustworthy.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. JSON-RPC validation changes no Aloe
  syntax, reader, parser, checker, load, type, signature, send, or evaluation
  behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 3 requires
  `InvalidRequest` `-32600`, `InvalidParams` `-32602`, `MethodNotFound`
  `-32601`, ignored unsupported notifications, and continued service.
  Sections 4 and 7 define synchronization-notification and Hover parameter
  behavior.
- Editor-lsp 005 is the complete framing/JSON-decoding boundary. A malformed
  UTF-8 or JSON body remains Parse Error `-32700`; an unrecoverable frame
  remains status 1. A syntactically valid JSON value reaches 006.
- Editor-lsp 000–004 provide the accepted language, document, position,
  snapshot, query-failure, rendering, and successful-lifecycle behavior behind
  dispatch.

Identity is `(editor-lsp, 006)`, spoken **editor-lsp 006**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit `CHECKPOINTS.md`,
add a file under `docs/checkpoints/`, or reopen a predecessor editor series.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

The private `run-lsp-server/with-query` seam retains its four-argument arity
and crosses the same validation and dispatch path as production. Neither
entry point closes caller-owned ports.

Keep byte framing, accepted headers, exact body reads, recoverable Parse
Errors, fatal status, protocol-only output, exact initialization capabilities,
document synchronization, URI handling, UTF-16 conversion, snapshot
selection/cleanup, query-failure translation, and Hover rendering unchanged.
A valid queryable Hover still calls the supplied query exactly once.

All 55 tests from editor-lsp 000–005 must remain green without editing a
predecessor test or checkpoint document. No accepted expectation is
superseded by 006.

## Validation order

For each completely framed body:

1. Decode UTF-8 and JSON exactly as in 005. A decode failure is still Parse
   Error `-32700` with null id.
2. Validate and classify the decoded value as a JSON-RPC request,
   notification, or invalid request shape using the rules below.
3. For a valid envelope, determine whether the method is a supported request,
   supported notification, or unsupported method for that message kind.
4. For a supported request, validate its method-specific parameters before
   reading nested members, changing state, touching a document, or querying.
5. Dispatch only after the preceding stages succeed.

Do not use exceptions from `hash-ref`, numeric comparisons, URI conversion, or
the document reducer as ordinary validation control flow. No malformed input
may reach an unchecked nested `hash-ref` or `string=?` call.

When one stage produces an error response, write and flush exactly that one
response, leave server/document state unchanged, make zero query calls, and
continue with the next frame. Do not also emit an error from a later stage.

## JSON-RPC envelope

A valid request or notification is a JSON object with:

- `jsonrpc` present and exactly the string `"2.0"`;
- `method` present and a string, including the empty string if supplied;
- `params` either absent or containing any decoded JSON value, with its
  method-specific shape checked only after method classification; and
- for a request, `id` present and either a Racket exact integer or a string;
  for a notification, `id` absent.

Unknown additional top-level members are ignored after these required members
validate. Do not interpret a top-level `result` or `error` as a message from
the server; without a valid string `method`, that object is invalid input.

The following are invalid request shapes:

- any top-level JSON array, string, number, boolean, or null;
- an object missing `jsonrpc` or `method`;
- a `jsonrpc` value other than the exact string `"2.0"`;
- a non-string `method`;
- a present `id` that is JSON null, a boolean, an inexact number, an array, or
  an object; and
- an incoming response-shaped object without a method.

Do not reject `params` generically. A supported request with wrong-shaped
params receives method-specific `InvalidParams`; a malformed supported
notification is ignored; and an unsupported method is classified without
inspecting params. This preserves the accepted rule that synchronization
notifications with non-object params are response-free.

LSP does not use JSON-RPC batch messages in this experiment. A top-level array
is one invalid request value, not a batch to iterate.

For every invalid shape above, respond exactly:

```json
{
  "jsonrpc": "2.0",
  "id": null,
  "error": {
    "code": -32600,
    "message": "Invalid Request"
  }
}
```

Use null even when a malformed object contains a fragment or otherwise valid
value under `id`; the envelope did not establish a valid request. The error
has no `result` or `data`.

An object without `id` is a notification only after the rest of its envelope
validates. A malformed id-less object therefore receives the null-id
`InvalidRequest` response; it is not silently treated as a notification.

## Request and notification roles

The supported request methods are:

- `initialize`;
- `textDocument/hover`; and
- `shutdown`.

The supported notification methods are:

- `initialized`;
- `textDocument/didOpen`;
- `textDocument/didChange`;
- `textDocument/didClose`;
- `$/cancelRequest`; and
- `exit`.

A valid request whose method is not in the supported request list receives:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32601,
    "message": "Method not found"
  }
}
```

Preserve its exact string or integer id. This includes an unknown method and a
notification-only method incorrectly sent with an id. It has no `result` or
`data`, and later messages continue normally.

A valid notification whose method is not in the supported notification list
is ignored and receives no response. This includes an unknown method and a
request-only method incorrectly sent without an id. In particular, an
`initialize`, `textDocument/hover`, or `shutdown` notification must not
initialize or shut down the server, query, or write a response.

A valid `$/cancelRequest` notification is ignored. Requests are serial and
there is no concurrent operation to cancel. It creates no worker, interrupt,
pending-request table, or response. A request carrying the same method name is
not a supported request and receives `MethodNotFound`.

Method-role classification happens before method-specific parameter access.
Do not inspect hover parameters on an unsupported notification or run a sync
reducer for a request-form `didOpen`.

## Invalid parameters

For a valid supported request envelope whose parameters do not have the exact
method shape below, respond:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32602,
    "message": "Invalid params"
  }
}
```

Retain the exact string or integer id. The response has no `result` or `data`.
Do not run the method, change state, query, create a snapshot, or emit a second
response.

### `initialize`

Require `params` to be present and a JSON object. Unknown nested initialization
properties are accepted and ignored by this server. The existing exact result
and transition occur only after this shape validates.

An invalid initialize request does not initialize the server. A following
well-shaped initialize request in the same stream retains the accepted success
behavior. Repeated valid initialization after a successful one remains a
later lifecycle-state error and must not be specified or tested in 006.

### `textDocument/hover`

Require `params` to be an object containing:

- `textDocument`, an object containing `uri`, a string; and
- `position`, an object containing `line` and `character`, each a Racket exact
  nonnegative integer.

Unknown properties in these objects are ignored. Missing objects/members,
wrong types, negative integers, and inexact numeric values are Invalid params.
Validate the complete shape before looking up the URI or converting a
position. A valid shape for an unopened or unsupported URI, or a valid but
out-of-range UTF-16 position, retains the ordinary JSON null result rather
than becoming Invalid params.

### `shutdown`

Accept `params` when it is absent or explicitly JSON null. Reject any other
value as Invalid params. A rejected shutdown does not enter the shutdown
state. A following ordinary Hover and later valid shutdown continue to work.

This rule does not yet decide whether shutdown is legal before initialization
or after shutdown; checkpoint 007 owns those state transitions.

## Notification parameters

Notifications cannot receive an `InvalidParams` response. Preserve the
accepted atomic synchronization policy:

- valid didOpen/didChange/didClose parameters reach the one existing sync
  reducer;
- malformed synchronization parameters are ignored without any state change
  or response; and
- a malformed notification never partially opens, replaces, or closes a
  document.

Require `initialized` params to be an object when present; absent or malformed
params are ignored without work or response. `initialized` has no state change
in this implementation.

For `$/cancelRequest`, ignore the notification regardless of its parameter
contents after the generic envelope accepts an object/array or absence. Do not
dereference its request id.

For `exit`, accept absent or JSON-null params. If other structured params are
present, ignore that malformed notification without exiting. Exit status and
lifecycle legality remain checkpoint 007.

## Temporary lifecycle boundary

Preserve 000's valid lifecycle sequence and status exactly. Also preserve the
existing state symbol/representation privately so checkpoint 007 can enforce
the complete transition table in one place.

Do not add assertions in the 006 suite for a well-shaped Hover, shutdown, or
unsupported request before initialization; a second valid initialize; or a
request after shutdown. Their final `ServerNotInitialized`, `InvalidRequest`,
notification-ignore, and exit-status behavior is deliberately unissued.

Envelope errors and Parse Errors are state-independent and may be tested
before initialization because they occur before lifecycle dispatch. Invalid
initialize params may also be tested before initialization. Every other
method/error test should first complete one valid initialize request and end
with the already accepted valid shutdown/exit sequence.

Do not implement or advertise a temporary alternate lifecycle rule. Simply
leave final state-order enforcement to 007.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/006-json-rpc.rkt` (new).

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, any prior LSP test, or
  the Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

No checked-in fixture is needed. Tests may construct decoded values through
independently framed JSON bytes and use existing fixtures read-only. If
validation requires an external package, changing the public export,
reclassifying malformed JSON, changing Expression Query, or weakening a prior
test, stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/lsp/006-json-rpc.rkt`. It is three directories below the
repository root, so use `../../../aloe/...` for repository-root module paths.
Construct and decode all frames independently of production and assert every
response shape exactly.

Cover at least:

1. Table-drive top-level valid JSON values that are not valid envelopes:
   arrays (including an apparent batch), strings, numbers, booleans, null, and
   response-shaped objects. Each receives the exact null-id `InvalidRequest`
   response, does not raise, and leaves the server available.
2. Table-drive malformed objects: missing/wrong `jsonrpc`, missing/non-string
   `method`, and null/boolean/inexact/array/object `id` values.
   Include a malformed object with a valid-looking string or integer id and
   prove `InvalidRequest` still uses null.
3. Put representative InvalidRequest values before initialization and between
   valid initialized messages. Prove validation is state-independent and does
   not change lifecycle or document state.
4. After initialization, send an unknown request with a numeric id and another
   with a string id. Each receives exact `MethodNotFound`, preserves its id,
   calls the query zero times, and does not affect later valid Hover or
   shutdown.
5. Send unknown notifications with absent, object, and array params. Also send
   a valid `$/cancelRequest` notification. They produce no responses, no state
   or document change, and no query calls.
6. Send request-only methods as notifications and notification-only methods as
   requests. The former are ignored without executing; the latter receive
   MethodNotFound. Assert that initialize and shutdown notifications write no
   response, a Hover notification does not query, and a request-form didOpen
   does not open a document. Prove the latter with a later valid Hover for that
   URI. Do not add assertions about the otherwise unissued lifecycle state
   after the initialize or shutdown notification; checkpoint 007 will expose
   that state transition matrix.
7. Table-drive invalid initialize params, including absent, null, array, and
   scalar values. Each well-formed request retains its id in one InvalidParams
   response, and a following valid initialize still succeeds.
8. Table-drive invalid Hover params and every required nested member/type,
   including negative and inexact line/character values. Each retains its id
   in one InvalidParams response, makes zero query calls, and creates no
   snapshot. Include valid-but-unopened, unsupported-URI, out-of-range, and
   split-surrogate controls that remain ordinary null results.
9. Send a shutdown request with object, array, string, number, and boolean
   params. Each receives InvalidParams without changing state. A valid Hover,
   then a valid shutdown with absent params, and exit still succeed.
10. Retain direct reducer and framed evidence that malformed didOpen,
    didChange, and didClose notifications are response-free and atomic. Do not
    edit or duplicate the reducer's state rules.
11. Interleave one Parse Error, one InvalidRequest, one MethodNotFound, one
    InvalidParams, ignored notifications, a successful Hover/null result, and
    clean shutdown/exit. Assert response order, exact error/result exclusivity,
    canonical framing, empty error output, and status 0.
12. Assert malformed/unsupported messages never expose exception text, source
    or snapshot paths, diagnostics, unframed bytes, or a second response.
13. Prove the normal module remains inert with its exact public surface,
    caller-owned ports remain open, and `run-lsp-server/with-query` exercises
    the same validation path.
14. Read production source narrowly enough to prove no `eval`, dynamic method
    lookup, parser/checker import, batch loop, or exception-message dispatch
    was introduced. Runtime tests are primary; do not pin private helper names
    or whitespace.
15. All prior LSP suites remain green without modification. Their framing,
    Parse Error, successful lifecycle, document, query, position, snapshot,
    failure-translation, and rendering assertions retain their exact behavior.

Use one serial exchange for multiple recoverable errors where practical. Use
fresh server state for table cases whose purpose is state preservation. Do not
construct malformed JSON for envelope tests: every 006 case must be valid JSON
inside a valid 005 frame.

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

After the automated tests, run one raw framed interaction by hand from a
Racket REPL at the repository root:

- send a valid JSON scalar and inspect exact null-id InvalidRequest;
- send a valid initialize request;
- send an unknown request and inspect MethodNotFound with its original id;
- send a malformed Hover request and inspect InvalidParams with its original
  id and no query;
- send an unknown notification and `$/cancelRequest` and inspect no response;
- send valid shutdown and exit, inspect status 0, and confirm every output byte
  belongs to a canonical response frame.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests/editor/lsp/004-hover-results.rkt
raco test tests/editor/lsp/005-framing.rkt
raco test tests/editor/lsp/006-json-rpc.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when every decoded value is safely classified,
invalid envelopes, unsupported requests, and invalid request params receive
their exact errors, unsupported/malformed notifications remain response-free,
valid behavior and all prior suites remain green, and the recursive suite has
no new failure. Stop for review without committing. Do not begin editor-lsp
007.

## Explicit non-goals

- No ServerNotInitialized, repeated-initialize rejection, general policy for
  otherwise supported notifications before initialization, post-shutdown
  rejection, or final exit-status matrix
- No new behavior for well-shaped supported requests sent in the wrong
  lifecycle state
- No new recovery for unexpected adapter, dispatcher, rendering, snapshot,
  output-port, or query-break failures
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No JSON-RPC batch execution, response handling, request concurrency,
  cancellation worker, or request reordering
- No completion, diagnostics, diagnostic publication, or additional LSP
  method/capability
- No incremental synchronization, dirty loaded-document overlay, workspace
  indexing, or caching
- No changes to Expression Query, selection, source locations, checking,
  loading, type/signature datums, or Hover text
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
