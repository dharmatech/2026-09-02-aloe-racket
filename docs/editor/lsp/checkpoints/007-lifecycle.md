# Editor LSP 007 — Complete lifecycle state machine

**Status.** Implemented and reviewed. The focused 17-test suite, the retained
69 tests from editor-lsp 000–006, and the required raw framed hand check are
green. The recursive suite passes 1,983 of 1,985 tests; its only failures are
the two pre-existing `tests/gel/presentations/003-doc-law.rkt`
contradictions. This checkpoint introduces no additional failure.

## Goal

Complete the LSP server lifecycle over the validated message stream. Before a
successful initialize request, every other valid request receives
`ServerNotInitialized`; ordinary notifications are ignored. In the active
state, the server retains editor-lsp 006's method and parameter dispatch. A
valid shutdown request enters the shutdown state, where every further request
receives `InvalidRequest` and every notification except a valid `exit` is
ignored.

A valid `exit` after shutdown returns status 0. A valid `exit` before shutdown,
EOF before exit, or lost framing returns status 1. Exit never receives a
response, and terminal status returns without consuming later frames.

This checkpoint changes state ordering only. It does not add methods, alter
documents or Hover, broaden failure catches, or add the command-line launcher.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. Lifecycle changes no Aloe syntax,
  parsing, checking, loading, evaluation, type, signature, or send behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 3 defines
  initialize, initialized, shutdown, exit, pre-initialize rejection,
  post-shutdown rejection, notification silence, cancellation, and serial
  ordering. Section 8 defines exact success/failure status conditions.
- Editor-lsp 005 supplies bounded framing, Parse Error recovery, fatal framing
  status, and open caller-owned ports.
- Editor-lsp 006 supplies decoded-envelope validation, request/notification
  roles, exact JSON-RPC errors, and method-specific parameter validation.
  Those stages run before lifecycle dispatch where specified below.
- Editor-lsp 000–004 supply the accepted initialization result, document,
  position, snapshot, query, Hover, and query-failure behavior available only
  in the active state.

Identity is `(editor-lsp, 007)`, spoken **editor-lsp 007**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit `CHECKPOINTS.md`,
add a file under `docs/checkpoints/`, or reopen a predecessor editor series.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

The private `run-lsp-server/with-query` seam retains its four-argument arity
and uses the same lifecycle state machine as production. Neither entry point
closes caller-owned ports.

Keep byte framing and headers, exact JSON decoding and errors, envelope
validation, request/notification roles, method parameter validation, exact
capabilities, atomic document synchronization, URI and UTF-16 behavior,
snapshot selection/cleanup, query-failure translation, and Hover rendering
unchanged. A valid active-state Hover still invokes the supplied query exactly
once.

All 69 tests from editor-lsp 000–006 must remain green without editing a
predecessor test or checkpoint document. No accepted expectation is
superseded by 007.

## Validation and lifecycle precedence

For every complete input frame, use this order:

1. Framing failure is terminal status 1 as in 005.
2. Malformed UTF-8/JSON is recoverable Parse Error `-32700`; state is
   unchanged.
3. A decoded value that is not a valid JSON-RPC envelope is InvalidRequest
   `-32600` with null id; state is unchanged.
4. A valid envelope is classified as request or notification by 006.
5. Lifecycle state selects the allowed request/notification behavior below.
6. Only an allowed active-state method reaches 006's method-role and
   method-parameter dispatch.

This means Parse Error and invalid-envelope handling remain state-independent,
including after shutdown. A syntactically valid request in the wrong lifecycle
state receives the lifecycle error before unsupported-method or
method-parameter validation. The sole exception is an `initialize` request in
the uninitialized state: its params must validate before it can establish the
active state.

Every recoverable error writes exactly one canonical response, changes no
state or document, makes no query call, and continues. Do not implement the
state machine by catching dispatcher exceptions or by duplicating JSON-RPC
envelope validation.

## States

Use exactly three private logical states:

- **uninitialized** — initial state before a successful initialize response;
- **active** — after one valid initialize request succeeds and before a valid
  shutdown succeeds; and
- **shutdown** — after the shutdown response is written and until valid exit,
  EOF, or fatal framing ends the server.

The private names may differ, but there is no fourth waiting-for-initialized
state. The `initialized` notification requires no work and does not gate
Hover or synchronization after the initialize response.

Document state begins empty. Notifications ignored because of lifecycle state
must not call the sync reducer, create a document, alter a version/text, query,
or create a snapshot.

## Uninitialized state

### `initialize` request

A valid request whose method is `initialize` is the only request eligible to
run in this state. Apply 006's initialize parameter validation:

- invalid params receive `InvalidParams` `-32602` with the original id and
  leave the state uninitialized;
- valid object params receive the exact existing initialize result, retain the
  original id, and enter the active state after the response is written.

Unknown initialization properties remain accepted and ignored. Do not send a
capability or server-to-client message before the initialize response.

### Other requests

Every other valid JSON-RPC request in the uninitialized state receives:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32002,
    "message": "Server not initialized"
  }
}
```

Preserve the exact string or integer id. The error has no `result` or `data`.
This rule applies before method-role, supported-method, or parameter checks, so
it includes:

- a well-shaped or malformed-params Hover request;
- shutdown;
- an unknown request;
- a notification-only method sent with an id; and
- a request-only method other than initialize.

Each leaves state/documents unchanged, makes zero query calls, and continues.
A later valid initialize request still succeeds.

### Notifications

A valid `exit` notification with absent or JSON-null params terminates
immediately with status 1 and no response.

Every other valid notification is ignored without response or side effects,
including `initialized`, synchronization notifications, `$/cancelRequest`,
unknown notifications, and request-only methods sent without an id. An
initialize notification does not initialize; a didOpen notification does not
open; a shutdown notification does not shut down; and a Hover notification
does not query.

Malformed exit params retain 006's rule: ignore that notification without
terminating, then continue in the uninitialized state.

## Active state

The active state uses editor-lsp 006's method roles and parameter rules:

- valid didOpen, didChange, and didClose notifications reach the atomic sync
  reducer;
- malformed sync notifications, unsupported notifications,
  `$/cancelRequest`, and request-only methods sent as notifications are
  ignored;
- valid Hover requests run normal document/position/query behavior;
- invalid Hover params receive InvalidParams;
- unsupported requests and notification-only methods sent as requests receive
  MethodNotFound; and
- an invalid shutdown request receives InvalidParams and leaves the state
  active.

The following lifecycle cases refine that dispatch.

### Repeated `initialize`

Any valid-envelope `initialize` request received in the active state is a
lifecycle InvalidRequest, regardless of whether its params are valid:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32600,
    "message": "Invalid Request"
  }
}
```

Retain the original id and omit `result` and `data`. Do not send a second
initialize result, replace capabilities, clear documents, or leave the active
state. Later Hover and shutdown continue normally.

An initialize notification remains an ignored request-only-method
notification; it is not a repeated request and receives no response.

### `initialized`

A valid `initialized` notification requires no work and no response. It may be
absent, appear once, or appear more than once without changing active state.
Malformed params are ignored as in 006. Do not use this notification to clear
documents or unlock method processing.

### `shutdown`

A shutdown request with absent or JSON-null params receives the existing JSON
null success response. After that response is successfully written and
flushed, enter shutdown state. Do not close ports, discard unread input, clear
documents, send an exit request, or return from `run-lsp-server` yet.

### Early `exit`

A valid `exit` notification in active state terminates immediately with status
1 and no response. It does not perform an implicit shutdown. Any bytes after
that exit remain unread.

Malformed exit params are ignored and the active state continues.

## Shutdown state

The only accepted valid-envelope message in shutdown state is an `exit`
notification with absent or JSON-null params. It writes no response and makes
`run-lsp-server` return status 0 immediately. Any following bytes remain
unread, and caller-owned ports remain open.

Every valid JSON-RPC request in shutdown state receives lifecycle
InvalidRequest `-32600` with its original string or integer id, no `result` or
`data`, and no method execution. This takes precedence over method roles and
params. It includes:

- a second shutdown;
- initialize;
- Hover, with valid or invalid params;
- an unknown method; and
- a notification-only method sent with an id, including request-form exit.

The server remains in shutdown state after each error so a later valid exit
still returns status 0.

Every other valid notification is ignored without response or side effects,
including sync notifications, initialized, cancellation, unknown methods,
request-only methods sent without an id, and exit with malformed params. No
notification after shutdown may reopen/change/close a document, query, create
a snapshot, or change the eventual successful exit status.

Parse Errors and invalid envelopes still receive their state-independent
errors in shutdown state, then processing resumes in shutdown state.

## EOF, framing, and terminal behavior

EOF before a valid exit returns status 1 in every state:

- empty input in uninitialized state;
- EOF after one or more ServerNotInitialized responses;
- EOF after initialize while active; and
- EOF after a successful shutdown response while in shutdown state.

Already written responses remain complete. EOF produces no additional JSON-RPC
response or unframed output.

Fatal framing remains status 1 in every state and does not get a lifecycle
error response. A bounded malformed JSON body remains a recoverable Parse
Error and does not alter state.

On valid early or post-shutdown exit, stop at that notification. Do not read,
validate, respond to, or mutate state for any concatenated trailing frame.
Return an exact integer, never a boolean or exception, for the terminal cases
owned by this checkpoint.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/007-lifecycle.rkt` (new).

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, any prior LSP test, or
  the Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

No checked-in fixture is needed. Tests may construct framed JSON bytes and use
existing fixtures read-only. If lifecycle enforcement requires changing a
public export, changing accepted method parameters, adding a new message,
weakening a predecessor test, or consuming bytes after exit, stop and return
the checkpoint for design review.

## Required tests

Add `tests/editor/lsp/007-lifecycle.rkt`. It is three directories below the
repository root, so use `../../../aloe/...` for repository-root module paths.
Construct/decode frames independently and assert exact response order, ids,
errors, statuses, query calls, port ownership, and unread trailing bytes.

Cover at least:

1. Retain the exact successful initialize/initialized/open/hover/shutdown/exit
   exchange with three responses, status 0, and one query call.
2. In uninitialized state, table-drive valid requests for Hover with valid and
   invalid params, shutdown, an unknown method, and a request-form didOpen.
   Use numeric and string ids. Each receives exact ServerNotInitialized before
   method/params handling, makes zero query calls, and a final valid initialize
   still succeeds.
3. Send invalid initialize params, assert InvalidParams and uninitialized
   state via a following request's ServerNotInitialized, then send a valid
   initialize and prove active Hover works.
4. Before initialization, send initialized, didOpen/didChange/didClose,
   cancellation, unknown, initialize/hover/shutdown notifications, and a
   malformed-params exit. Assert complete silence and no state/document/query
   effect. Then initialize and hover the pre-opened URI; it is still unopened
   and returns null.
5. In active state, send repeated initialize requests with valid and invalid
   params and numeric/string ids. Each receives lifecycle InvalidRequest with
   its original id. An existing open document and later Hover remain intact,
   proving no reinitialization or state reset.
6. Prove initialized is optional and repeated: one active exchange omits it
   before Hover; another sends it multiple times. Both have identical language
   behavior and no notification responses.
7. Send invalid shutdown params and prove InvalidParams plus continued active
   Hover. Then send valid shutdown, assert its null response, and enter the
   shutdown cases below.
8. After shutdown, table-drive initialize, second shutdown, valid/invalid-param
   Hover, unknown, and request-form exit. Every request receives InvalidRequest
   with its original id, makes zero query calls, and does not produce a method-
   specific error.
9. After shutdown, send every supported non-exit notification, representative
   malformed sync notifications, unknown notification, request-only-method
   notifications, and exit with malformed params. Assert silence and no query
   or filesystem effect, then send valid exit and receive status 0.
10. Send valid exit in uninitialized state and active state in separate runs.
    Each writes no exit response, returns status 1, leaves caller ports open,
    and does not consume a valid-looking trailing frame.
11. Send valid exit after shutdown followed by a valid-looking request frame.
    Assert status 0, no response to either exit or trailing request, and prove
    the trailing bytes remain unread on the caller's input port.
12. Table-drive EOF at initial frame boundary, after a pre-init error, after
    initialize, and after shutdown. Assert status 1 without an extra response,
    exception, query, port close, or unframed output.
13. Interleave Parse Error and InvalidRequest before initialize, active-state
    MethodNotFound/InvalidParams, shutdown, then Parse Error and an invalid
    envelope after shutdown. Assert each exact error, state preservation,
    response order, and final valid exit status 0.
14. Cause representative fatal framing in uninitialized, active, and shutdown
    state. Assert status 1, no fabricated lifecycle response, earlier responses
    intact, and open caller ports.
15. Prove precedence explicitly: pre-init malformed Hover params is
    ServerNotInitialized, active malformed Hover params is InvalidParams, and
    post-shutdown malformed Hover params is InvalidRequest. Similarly, an
    unknown request is ServerNotInitialized, MethodNotFound, then
    InvalidRequest across the three states.
16. Assert all recoverable errors have exactly one of `error`/`result`, exact
    codes/messages and ids, no `data`, canonical framing, empty error output,
    and continued service where nonterminal.
17. Prove the normal module remains inert with its exact public surface and
    both public/test-support entry points share lifecycle behavior without
    closing caller-owned ports.
18. Read production source narrowly enough to prove no worker, concurrent
    queue, implicit client message, parser/checker import, or process exit was
    added. Runtime transition tests are primary; do not pin private state/helper
    names or whitespace.
19. All prior LSP suites remain green without modification. Their exact frame,
    validation, method-role, parameter, synchronization, query, snapshot,
    rendering, and successful lifecycle assertions retain their behavior.

Use serial exchanges that cross multiple states where that strengthens
precedence evidence. Use fresh ports for terminal exit/EOF/framing cases. Do
not infer a transition only from response count when query calls, document
state, unread input, or status can prove it directly.

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

After automated tests, run one raw framed interaction by hand from a Racket
REPL at the repository root:

- send a Hover request before initialize and inspect exact
  ServerNotInitialized with its id;
- initialize, then repeat initialize and inspect lifecycle InvalidRequest;
- didOpen and Hover normally;
- shutdown and inspect its null result;
- send a valid-looking request after shutdown and inspect lifecycle
  InvalidRequest rather than its method-specific response;
- send a notification after shutdown and inspect silence;
- exit and inspect status 0, canonical protocol-only output, and open caller
  ports.

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
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when uninitialized, active, and shutdown states
enforce the exact request/notification rules and precedence, terminal exit/EOF
statuses are exact, trailing bytes remain unread, valid and error behavior from
all prior slices remains green, and the recursive suite has no new failure.
Stop for review without committing. Do not begin editor-lsp 008.

## Explicit non-goals

- No new recovery for unexpected adapter, dispatcher, rendering, snapshot,
  output-port, or query-break failures
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No additional LSP method/capability, completion, diagnostics, or diagnostic
  publication
- No request concurrency, worker pool, cancellation execution, request
  reordering, or progress messages
- No incremental synchronization, dirty loaded-document overlay, workspace
  indexing, or caching
- No changes to Expression Query, selection, source locations, checking,
  loading, type/signature datums, or Hover text
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No VS Code extension or other editor-specific client/configuration
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
