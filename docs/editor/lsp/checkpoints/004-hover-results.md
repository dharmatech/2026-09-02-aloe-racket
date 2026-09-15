# Editor LSP 004 — Hover failures and exact rendering

**Status.** Implemented and reviewed. The focused seven-test suite, the
retained 35 tests from editor-lsp 000–003, and the required hand check are
green. The one authorized predecessor expectation was migrated without
weakening its snapshot-cleanup or filesystem-safety assertions. The recursive
suite passes 1,939 of 1,941 tests; its only failures are the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` contradictions. This checkpoint
introduces no additional failure.

## Goal

Complete the language-facing result policy for `textDocument/hover`. Ordinary
failures raised by the public Expression Query—including unreadable query
sources, malformed Aloe, checker errors, and missing loads—produce a JSON null
Hover result and leave the server available. They are not protocol errors,
diagnostics, log text, or partial Hover prose.

Also finish the two remaining deterministic rendering edges: an empty
signature list renders `messages: none`, and repeated selector overloads are
rendered as separate rows in their original query order.

This slice does not harden malformed JSON-RPC request shapes, lifecycle error
states, framing recovery, or the command-line launch path. Snapshot setup and
cleanup failures retain editor-lsp 003's exact `RequestFailed` behavior.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. This checkpoint changes no reader,
  parser, checker, load, type, signature, send, or evaluation behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 7 defines
  null query failures and exact Hover text. Sections 2 and 5 keep Expression
  Query and synchronized sibling snapshots as the only language boundary.
- `docs/editor/expression-query/spec.md` owns strict complete-file query
  behavior. Its reader, parser, checker, root-file, and loaded-file failures
  deliberately escape as ordinary Racket failures; the LSP adapter translates
  those failures at its query boundary.
- Editor-lsp 000 is implemented and reviewed. It supplies valid framing, the
  public query call, the successful lifecycle, and ordinary Hover rendering.
- Editor-lsp 001 is implemented and reviewed. It supplies complete UTF-16 and
  line-break conversion in both directions.
- Editor-lsp 002 is implemented and reviewed. It supplies atomic full-document
  synchronization and close behavior.
- Editor-lsp 003 is implemented and reviewed. It supplies the exact-byte
  direct/snapshot choice, sibling placement, unconditional cleanup, relative
  loads, and recoverable snapshot `RequestFailed` responses.

Identity is `(editor-lsp, 004)`, spoken **editor-lsp 004**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit `CHECKPOINTS.md`,
add a file under `docs/checkpoints/`, or reopen a predecessor editor series.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

Keep its arity, canonical valid framing, exact initialization capabilities,
successful lifecycle, synchronization state, exact URI keys, local-file URI
conversion, UTF-16 conversions, request-id retention, caller-port ownership,
and protocol-only standard output unchanged.

Keep `aloe/expression-query.rkt` as the only Aloe dependency. The normal
adapter continues to import only `query-expression-at`, the
`expression-query-result` predicate/accessors, and the re-exported
`signature-spec` accessors named by the LSP spec. Do not import parser,
checker, selection, source-location, or catalog internals to classify an
exception or rebuild a result.

The private `run-lsp-server/with-query` test-support operation retains its
four-argument arity. Its supplied query procedure crosses exactly the same
failure-translation boundary as the real public query. A valid queryable
Hover invokes that procedure exactly once, whether it returns a result,
returns `#f`, or raises an ordinary failure.

All 35 tests from editor-lsp 000–003 remain green after the one narrow
predecessor-test migration authorized below. Every assertion outside that one
superseded query-exception expectation remains unchanged.

## Required predecessor-test migration

Editor-lsp 003 deliberately required a query exception to escape after proving
that snapshot cleanup ran. That temporary rule is superseded by this
checkpoint's final language-query failure policy. The implementer is
authorized and required to update exactly the test case in
`tests/editor/lsp/003-buffer-snapshots.rkt` currently named:

```text
query exception escapes unchanged after snapshot cleanup
```

Rename it so its description states that an ordinary query failure becomes a
null Hover after snapshot cleanup. Keep the distinctive `exn:fail` query stub,
the exactly-one query call, the observation that the complete sibling exists
during the call, the proof that the sibling is removed afterward, the original
file byte check, the restored directory-entry check, and the empty error port.

Replace only the escaping-exception expectation with a framed null response.
Extend that exchange through `shutdown` and `exit` so it also proves status 0
and continued service. The exception text must not appear in protocol output,
Hover contents, error data, or the supplied logging port.

Do not edit any other predecessor test or historical checkpoint document.
Editor-lsp 004 is the explicit transition from 003's temporary escaping rule
to the final null-result rule.

## The query failure boundary

For an otherwise valid Hover whose URI, synchronized document, local path, and
LSP position have already been accepted:

1. Convert the LSP position to the one-based Expression Query position exactly
   as in 001.
2. Choose the original or synchronized sibling path exactly as in 003.
3. Invoke the supplied query procedure exactly once with that path and
   position.
4. If it returns `#f`, retain `#f` as the query outcome.
5. If it returns an `expression-query-result`, retain that result as ordinary
   Racket data.
6. If that invocation raises an `exn:fail?`, translate only that invocation's
   outcome to `#f`.
7. Complete any snapshot cleanup before constructing or writing the response.

The eventual JSON result for either returned or translated `#f` is JSON null.
The response is an ordinary JSON-RPC success response with `result: null`; it
does not have an `error` member.

Place the exception handler at the narrow query-procedure invocation. Both the
direct-path and snapshot-path branches must pass through the same operation;
do not duplicate exception policy. Do not wrap the whole Hover handler, server
loop, snapshot operation, range conversion, rendering, or response writer in
this null-producing handler.

This narrow placement is essential. In particular:

- a snapshot create/write/flush/close or cleanup failure remains the private
  snapshot failure from 003 and produces its exact `-32803` error;
- an adapter error outside the query call is not mislabeled as malformed Aloe;
- a framing or response-write failure is not swallowed as a null Hover; and
- snapshot cleanup still runs when the query raises.

Catch `exn:fail?`, not every raised value and not every `exn?`. Do not catch,
convert, or suppress `exn:break?`. Do not inspect exception messages to guess
whether a failure came from the reader, parser, checker, root file, or load.
The public query boundary already owns those distinctions, and they all have
the same LSP result here.

The adapter supplies a valid path and exact positive query position before the
call. Do not use exception translation as a substitute for URI or position
validation, and do not retry on the original path, an older buffer, or a
second query call after a failure.

## Required null cases and continued service

The completed behavior must cover these distinct outcomes:

- no expression owns a valid position, so Expression Query returns `#f`;
- the complete synchronized source is incomplete at end of input;
- the source is readable as datums but rejected by the Aloe parser;
- the complete source fails Aloe checking, including an error after the
  selected expression;
- a relative loaded source needed by the root is missing or unreadable; and
- the root source becomes unreadable during the public query after the adapter
  has already selected its path.

Each produces exactly one `result: null` response retaining the original
number or string request id. It does not terminate the loop. Later
synchronization, Hover, shutdown, and exit messages are processed in order.

An incomplete or erroneous buffer is not recovered, partially parsed, or
queried speculatively. There is no partial type, error row, diagnostic, or
message. A later valid `didChange` replaces the text normally and permits a
fresh independent query.

Ordinary query failures emit no text to the supplied error-output port. The
adapter may gain concise logging for unexpected adapter failures in a later
protocol-hardening slice, but Aloe reader/parser/checker/load exception text
must not become editor protocol or log output in this experiment.

## Exact Hover contents

For a valid `expression-query-result` with a valid converted range, continue
to return plaintext `MarkupContent` and that exact range. Construct the value
as follows:

1. `type: ` followed by the result type datum written with Racket `write`;
2. a newline;
3. if the signature list is empty, exactly `messages: none` and nothing else;
4. otherwise, exactly `messages:` followed once per signature row by a
   newline, two spaces, selector datum, ` : `, complete parameter-list datum,
   ` -> `, and return datum, with every datum written using Racket `write`.

Thus an empty result is exactly:

```text
type: (Class String)
messages: none
```

There is no trailing newline in the value.

For nonempty signatures, iterate the query's list once from first to last.
Do not sort by selector, parameter type, source order reconstructed elsewhere,
or printed text. Do not deduplicate selectors or whole rows, group overloads,
collapse them into one entry, or convert them to a hash. Repeated selectors
remain separate lines. For example, query rows ordered `z`, `pick(Int)`,
`pick(String)`, `a` render in exactly that order, including both `pick` lines.

Use only the returned type and signature rows. Do not call
`type-signature-specs`, inspect a class declaration, add kernel rows, substitute
types, or invoke a signature. Invalid returned source ranges retain the
accepted JSON null behavior and do not expose a partially rendered result.

## Snapshot interaction

Query exception translation changes no editor-lsp 003 filesystem rule. A
dirty or missing synchronized root still uses one unique sibling in exactly
the original path's parent. The complete UTF-8 bytes are flushed before the
query, relative loads resolve from that parent, and only the exact snapshot is
removed in unconditional cleanup.

When the query returns `#f` or raises an `exn:fail?`, cleanup finishes before
the null response is framed. The original file remains untouched, a missing
root remains missing, and every unrelated directory entry remains unchanged.
Do not retain a failed buffer for inspection and do not include a source or
snapshot path in the response.

If cleanup itself fails after a query failure, the cleanup failure wins: emit
003's exact `RequestFailed` response rather than a successful null response.
The exact snapshot failure remains:

```json
{
  "jsonrpc": "2.0",
  "id": "the-request-id",
  "error": {
    "code": -32803,
    "message": "unable to create synchronized document snapshot"
  }
}
```

It has no `result` or `data`, and the server remains available.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`;
- `tests/editor/lsp/004-hover-results.rkt` (new); and
- `tests/editor/lsp/003-buffer-snapshots.rkt`, only for the superseded
  query-exception test named above.

The new tests may create and unconditionally remove exact temporary files and
directories under the system temporary directory. No checked-in fixture is
needed for this slice.

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, editor-lsp 000–002
  tests, any other editor-lsp 003 test, or the Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

If null failure translation requires changing the public query contract,
importing parser/checker exception predicates, catching outside the query
invocation, retaining a snapshot, retrying a query, or weakening a prior
filesystem assertion, stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/lsp/004-hover-results.rkt`. It is three directories below the
repository root, so use `../../../aloe/...` for repository-root module paths.
Construct and decode canonical frames independently of production. Use
`dynamic-wind` or an equivalent unconditional cleanup action for each test
directory.

Cover at least:

1. Through `run-lsp-server/with-query`, an unchanged on-disk document invokes
   a stub exactly once; a distinctive raised `exn:fail` becomes a response
   with the same numeric id and `result` equal to JSON null. A following
   shutdown and exit succeed with status 0, output decodes only as complete
   frames, and neither protocol nor error output contains the exception text.
2. Perform the authorized 003 migration for a dirty synchronized document.
   Prove the sibling contains the exact bytes during the raising stub, then is
   gone before the null response is observed. Retain all original-file and
   directory-entry safety assertions.
3. Use the real public `run-lsp-server` for one serial exchange over a missing
   or dirty root. Exercise separately an incomplete source, a parser-invalid
   source, a checker-invalid source (including a later checker error after a
   selectable expression), and a missing relative load. Each Hover returns
   null. After a final valid full change, Hover returns its real type, rows,
   and range; shutdown/exit returns 0 and the directory has no snapshot.
4. Use the real public server on a complete valid source and hover a top-level
   gap so Expression Query itself returns `#f`. Assert one null result and a
   later valid Hover in the same exchange. This case must not use an invalid
   LSP position as a substitute for a real query miss.
5. Exercise a public-query failure on an unchanged byte-identical disk file,
   not only on snapshots. It returns null, leaves the bytes and directory
   unchanged, and a later request is processed. This proves both path branches
   share the same query translation.
6. Query the real `String` class-object expression, whose catalog has no rows.
   Assert the exact plaintext value `type: (Class String)\nmessages: none`, no
   trailing newline, the exact expression range, and no extra Hover fields.
7. Query a real class instance whose declared method order is `z`, overloaded
   `pick` for `Int`, overloaded `pick` for `String`, then `a`. Assert the exact
   plaintext lines in that order, including both `pick` rows with their full
   parameter lists and return datums. Assert the whole selected-expression
   range. Do not manufacture the result by calling adapter internals.
8. Use both numeric and string ids among the null and successful result cases
   and prove exact retention. Query failures have `result` and no `error`;
   retained snapshot setup-failure coverage has `error` and no `result`.
9. Assert the supplied logging port is empty and the protocol stream contains
   no source path, snapshot path, query exception message, diagnostics, or
   unframed bytes.
10. Read production source as text and narrowly prove it still imports only
    the public Expression Query boundary and does not name parser/checker
    exception predicates, `type-signature-specs`, a method catalog, or a broad
    `exn?` handler. Runtime result and continuation tests are the primary
    evidence; do not make source-shape assertions depend on whitespace.
11. All prior LSP suites remain green after only the authorized 003 test
    migration. Exact Point rendering, UTF-16 conversion, atomic sync,
    direct/snapshot choice, relative loads, setup `RequestFailed`, cleanup,
    all unrelated query call counts, and the normal module surface remain
    unchanged.

Use real public-query cases for the Aloe failure categories and exact rendering
edges. A stub is appropriate only for precise call counting, raising a
distinctive ordinary failure, and observing a live snapshot.

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

After the automated tests, run one real framed interaction by hand from a
Racket REPL at the repository root:

- create a temporary directory and choose a missing root path within it;
- initialize and didOpen that URI with parser-invalid synchronized text such
  as `(1)`;
- hover it and inspect an ordinary JSON null result with no error or prose;
- didChange the same URI to `String`, hover again, and inspect exactly
  `type: (Class String)\nmessages: none` with range `0:0–0:6`;
- shut down, exit with status 0, and confirm the root remains missing and the
  directory contains no snapshot; and
- remove the exact temporary directory.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests/editor/lsp/004-hover-results.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when every ordinary public-query failure becomes a
null Hover without terminating the server, direct and snapshot queries share
one narrow failure boundary, snapshots still clean up before responses, empty
and repeated rows render exactly, prior suites remain green, and the recursive
suite has no new failure. Stop for review without committing. Do not begin
editor-lsp 005.

## Explicit non-goals

- No malformed JSON recovery, general JSON-RPC validation, invalid-parameter
  response matrix, unsupported-request error, or pre/post-initialize policy
- No new handling for unexpected adapter failures outside the existing
  snapshot `RequestFailed` path
- No complete lifecycle or exit-status hardening beyond proving continued
  service after ordinary query failures
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No incremental synchronization, dirty loaded-document overlay, workspace
  tree, indexing, caching, or concurrency
- No diagnostics, diagnostic publication, completion, selector holes,
  partial parsing, or speculative checking
- No changes to Expression Query, selection, `srcloc`, checker errors, type
  datums, signature rows, or their order
- No second parser, checker, evaluator, declaration traversal, method catalog,
  or direct `type-signature-specs` call
- No VS Code extension or other editor-specific client/configuration
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
