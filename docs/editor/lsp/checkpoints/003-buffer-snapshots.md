# Editor LSP 003 — Synchronized buffer snapshots

**Status.** Implemented and reviewed. The focused nine-test suite, the retained
26 tests from editor-lsp 000–002, and the required hand check are green. The
three authorized predecessor expectations were migrated without weakening
their filesystem-safety assertions. The recursive suite retains only the two
pre-existing `tests/gel/presentations/003-doc-law.rkt` failures and this
checkpoint introduces no additional failure.

## Goal

Make hover query the server's current synchronized document text even when it
differs from disk or the document path does not yet exist. Unchanged files
continue to query their original path. Every other supported local document
is written to a uniquely named temporary sibling, queried through that path,
and removed in an unconditional cleanup action.

The sibling location is essential Aloe behavior: a relative `load` in the
synchronized root must continue to resolve from the document's directory.
The original path is never written, renamed, removed, or created. An open
dirty version of a separately loaded document is not overlaid; loaded files
continue to come from disk.

This checkpoint also handles the one adapter failure introduced by the new
operation. If a required sibling cannot be created or written, the hover
request receives LSP `RequestFailed` (`-32803`) and the server continues.
General JSON-RPC validation and query/parser/checker/load failure policy
remain later slices.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law, especially the existing relative
  `load` behavior. A snapshot changes only the path supplied to the public
  query; it does not parse, rewrite, or reinterpret a load form.
- `docs/editor/lsp/spec.md` is the local design authority. Section 5 defines
  synchronized-buffer snapshots and loaded-file behavior. Sections 3 and 7
  define the `RequestFailed` response and continued availability.
- Editor-lsp 000 is implemented and reviewed. It supplies valid framing,
  lifecycle, the public Expression Query boundary, and deterministic Hover.
- Editor-lsp 001 is implemented and reviewed. Position and range conversion
  already use the exact synchronized string across UTF-16 and all required
  line breaks.
- Editor-lsp 002 is implemented and reviewed. didOpen, full didChange, and
  didClose establish the exact current URI/version/text state consumed here.
- `aloe/expression-query.rkt` remains the only Aloe dependency. Its public
  query accepts a path and one-based Racket character position, reads a
  complete file, resolves loads relative to that file, and returns plain
  Racket result data or `#f`.

Identity is `(editor-lsp, 003)`, spoken **editor-lsp 003**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit
`CHECKPOINTS.md`, add a file under `docs/checkpoints/`, or reopen a predecessor
editor series.

## Preserve accepted behavior

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

Keep its arity, Aloe imports, canonical valid framing, initialize result,
successful lifecycle, exact URI document keys, atomic full synchronization,
UTF-16 conversion, Hover contents and range, caller-port ownership, and
protocol-only standard output unchanged.

The existing `run-lsp-server/with-query` test-support seam retains its
four-argument arity. It must exercise the same direct-path/snapshot choice and
cleanup as the normal public server. Do not add a caller-supplied source
string or path mode to Expression Query.

All suites from editor-lsp 000–002 remain green after the narrow predecessor-
test migration authorized below. Every assertion outside the three temporary
dirty-buffer expectations remains unchanged. In particular, unchanged Point
hover still calls the original fixture path, malformed synchronization
remains atomic, and position conversion always uses synchronized text.

## Required predecessor-test migration

Editor-lsp 000–002 deliberately used JSON null and zero query calls as a safe
temporary boundary whenever synchronized bytes differed from disk. That
boundary is superseded by this checkpoint's required snapshot behavior. The
implementer is authorized and required to update exactly these three existing
test cases:

- `tests/editor/lsp/000-hover.rkt`, the case currently named `dirty
  synchronized text neither queries nor changes the file`;
- `tests/editor/lsp/001-utf16-positions.rkt`, the case currently named `a
  one-byte disk mismatch neither queries nor creates a sibling`; and
- `tests/editor/lsp/002-document-sync.rkt`, the case currently named `dirty
  final change never queries or changes the filesystem`.

Rename each case so its description states the new snapshot behavior. Change
its query-call expectation from zero to exactly one. Where its stub returns
`#f`, the hover remains JSON null; where its stub returns a valid result, the
hover is now non-null. Preserve each case's existing clean lifecycle,
original-file byte equality, and restored-directory assertions. The cases may
be strengthened to inspect the sibling during the query, but the comprehensive
snapshot-path and cleanup evidence belongs in the new 003 suite.

Do not delete these cases, relax their filesystem-safety assertions, or edit
any other predecessor test expectation. The historical 000–002 checkpoint
documents continue to describe their accepted slices and must not be changed;
003 is the explicit semantic transition from their temporary dirty-buffer
boundary to the final snapshot rule.

## Choose the query path from exact bytes

For each otherwise valid hover on an open supported local file URI:

1. Encode the current synchronized Racket string as UTF-8 bytes once for the
   path decision and possible snapshot write.
2. Attempt to read the bytes currently at the document's converted local
   path.
3. If that path is a readable regular file and its bytes exactly equal the
   synchronized bytes, call the query once on that original path.
4. Otherwise, call the query once on a temporary sibling containing exactly
   the synchronized bytes.

Do not compare decoded strings, normalize line endings, ignore an encoding
marker, compare modification times, or use the document version as a disk
freshness proxy. Byte equality alone selects the direct path.

A missing original path, directory at the original path, unreadable original
file, or any byte mismatch takes the snapshot branch as long as a sibling can
be created in the original path's parent directory. Do not require an `.aloe`
extension and do not require the original path itself to be writable.

An unchanged readable file is always queried directly. Do not create a
sibling merely because the file or its parent is read-only when the direct
read succeeded and bytes matched.

## Temporary sibling contract

Create the snapshot as a new, uniquely named regular file in exactly the
document path's parent directory. Use Racket's temporary-file operation with
that directory as its base; do not generate a name and then probe or overwrite
it yourself.

The temporary name is an internal implementation detail. It may use any
collision-safe prefix and does not need the document's suffix because Aloe
does not infer semantics from extensions.

Once created:

- write exactly the synchronized UTF-8 bytes;
- close and flush the output before invoking the query;
- invoke the supplied query procedure exactly once with the temporary path
  and the already converted one-based position;
- retain the query's result only as ordinary Racket data; and
- remove that exact temporary file in an unconditional cleanup action after
  the query returns or escapes by exception.

Use `dynamic-wind` or an equivalent exception-safe cleanup construct. Never
delete by glob, prefix, directory scan, or unresolved variable. Never retain
the sibling after a normal result, `#f`, invalid returned range, or query
exception.

The original document path is never opened for writing and is never created,
overwritten, truncated, renamed, chmodded, or removed. Do not create a backup
or rename-swap the user's file. No other file in the parent directory may be
changed.

The `srcloc-source` returned by the real query may name the sibling. Continue
to derive the Hover range only from its position and span against the current
synchronized string. Never put the result source, original path, sibling
path, or directory in Hover contents, range, error data, or protocol logs.

## Relative loads and document overlays

A snapshot is a sibling rather than a system-temporary root so the public
Expression Query's existing relative-load rule remains correct. For example,
if the synchronized root contains:

```aloe
(load "support.aloe")
(LoadedFromDisk new 7)
```

then `support.aloe` is read from the document directory even when the root's
own disk path is missing or contains different bytes.

Do not inspect, copy, parse, or rewrite load forms in the adapter. Do not copy
loaded files beside a snapshot and do not create a workspace tree.

Only the hovered root receives a snapshot. If `support.aloe` is also open in
the server with dirty synchronized text, a load from the root still reads the
on-disk `support.aloe`. The open support document's text is used only when a
client hovers that exact support URI. Cross-document overlays are a separate
design and remain out of scope.

## Snapshot setup failure

Snapshot setup includes choosing a usable parent, creating the unique regular
file, writing every synchronized byte, flushing, and closing it before query.
If any of those adapter operations fails, do not query the original path and
do not call the query procedure.

Respond to that hover request with this JSON-RPC error shape, preserving its
number or string id:

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

The response has `error`, not `result`, and no `data` field. It is framed and
flushed through the same protocol writer as other responses. The server then
continues processing later messages; a following shutdown and exit still
return status 0. No partial temporary file may remain when setup created one
before failing.

Represent this condition privately so only snapshot create/write/close/setup
failures become `RequestFailed`. Do not broadly catch the entire hover path
and label unrelated exceptions as snapshot failures. The test may cause a
deterministic setup failure by making the document path's parent component a
regular file or by using a definitely missing parent; it must not depend on
the current user's permission bits.

Cleanup failure after a query is also an adapter failure and must not produce
a successful Hover while knowingly retaining a snapshot. Normal tests need
not sabotage cleanup permissions, but production must place deletion in the
same protected snapshot operation rather than after a response is written.

The supplied error-output port may receive concise failure logging, but the
snapshot path must not be exposed to the client and standard output remains
framed protocol only.

## Query results and exceptions

The direct and snapshot branches pass the same converted position and consume
the same query result:

- `#f` produces a JSON null hover result;
- a valid `expression-query-result` produces the existing Hover; and
- an invalid returned range produces the existing JSON null result.

In every snapshot case, cleanup completes before the framed response is
written.

General query exception mapping is not part of 003. If the supplied query
procedure raises, remove the snapshot and allow the same exception behavior
that 002 had for a direct-path query. Do not convert it to `RequestFailed` in
this checkpoint and do not catch breaks. A later checkpoint maps specified
reader/parser/checker/load failures to null while keeping unexpected adapter
failures distinct.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/003-buffer-snapshots.rkt` (new);
- `tests/editor/lsp/000-hover.rkt`, only for the superseded dirty-buffer case
  named above;
- `tests/editor/lsp/001-utf16-positions.rkt`, only for the superseded disk-
  mismatch case named above; and
- `tests/editor/lsp/002-document-sync.rkt`, only for the superseded dirty-
  final-change case named above.

The new tests may create and unconditionally remove exact temporary files and
directories under the system temporary directory. No checked-in fixture is
needed for this slice.

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, other prior LSP tests
  or assertions, or the Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

If synchronized querying requires changing Expression Query's path contract,
rewriting loads, overlaying another open document, writing the original path,
or using a non-sibling snapshot, stop and return the checkpoint for design
review.

## Required tests

Add `tests/editor/lsp/003-buffer-snapshots.rkt`. It is three directories below
the repository root, so use `../../../aloe/...` for repository-root module
paths. Construct and decode canonical frames independently of production.
Use `dynamic-wind` or an equivalent unconditional cleanup action for every
test directory.

Cover at least:

1. An unchanged readable document calls the query exactly once with the
   original path. During and after the call, the parent directory contains no
   additional file. Make the document file read-only for the call and restore
   its permissions during test cleanup.
2. A didOpen buffer differing from an existing root calls the query exactly
   once with a different path whose parent is exactly the root's parent.
   During the callback, prove that path is a regular file containing the exact
   synchronized UTF-8 bytes. After the response, prove the sibling is gone,
   the original bytes are unchanged, and all other directory entries match.
3. A full didChange ending in dirty text uses the same snapshot path rather
   than the original or an older synchronized version. Its query position and
   returned range are calculated against the final synchronized text,
   including at least one supplementary character or CRLF boundary.
4. Snapshot cleanup occurs when the query returns `#f` and when it returns a
   result whose location cannot form a valid range. Both hovers return JSON
   null, and the directory is restored after each response.
5. A query stub that raises a distinctive exception observes the complete
   sibling during its call. The exception escapes with its identity/text
   preserved after the sibling has been removed and the original has remained
   unchanged. This test may catch the exception outside
   `run-lsp-server/with-query`; it does not require continued protocol service
   for query exceptions in 003.
6. A missing original root with an existing parent is queryable through a
   sibling. Afterward the original path is still missing and the sibling is
   removed.
7. Use the real public `run-lsp-server` for a dirty or missing synchronized
   root that loads a real sibling `support.aloe` and constructs a class defined
   there. Hover returns the expected type, ordered rows, and root-expression
   range. This is the required proof that relative load resolution survives
   snapshotting; a query stub is insufficient.
8. In the relative-load test, also didOpen `support.aloe` with dirty text that
   would define a different class or fail if overlaid. The root query still
   observes the on-disk support file. Afterward neither root nor support disk
   bytes have changed and no temporary sibling remains.
9. Force snapshot setup failure with a document path whose parent component
   cannot be a directory. The hover receives the exact `-32803` error above,
   the query call count stays zero, no partial file appears, shutdown responds,
   exit returns 0, and output contains only valid frames.
10. Use both numeric and string hover ids across successful and failed
    snapshot requests and prove exact retention.
11. Read production source as text and prove snapshots are not created in the
    system temporary root, the original path is never an output target, and
    no load form or method catalog is inspected. Keep this assertion narrow;
    runtime filesystem tests are the primary evidence.
12. All prior LSP suites remain green after only the three authorized dirty-
    expectation migrations. Exact synchronization state, full UTF-16
    conversion, the unchanged Point path, every unrelated query call count,
    and the normal module surface remain unchanged.

For every filesystem assertion, compare explicit paths, bytes, and directory
entries. Do not infer cleanup merely because a later query succeeded. Do not
use a broad repository directory as a temporary target.

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

After the automated tests, run one real framed interaction by hand from a
Racket REPL at the repository root:

- create a temporary directory containing only an on-disk support file;
- didOpen a missing root URI with synchronized Aloe text that relatively loads
  the support file and constructs its class;
- hover the constructed send through `run-lsp-server` and inspect its real
  type, ordered field rows, and range;
- confirm during completion that the root path remains missing and the
  directory again contains only the support file; and
- shut down, exit with status 0, and remove the exact temporary directory.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when hover always queries the exact synchronized
root bytes through the original or a temporary sibling, relative loads remain
rooted in the document directory, every sibling is removed on all tested exit
paths, snapshot setup failure is a recoverable `RequestFailed`, prior suites
remain green, and the recursive suite has no new failure. Stop for review
without committing. Do not begin editor-lsp 004.

## Explicit non-goals

- No dirty overlay for loaded or other open documents
- No workspace snapshot tree, indexing, cache, retained snapshot, or
  incremental text synchronization
- No manual load parsing, rewriting, copying, or alternate load resolution
- No malformed framing/JSON recovery or general JSON-RPC request validation
- No complete lifecycle error matrix, cancellation, or unsupported-request
  errors
- No general query/parser/checker/load exception mapping beyond snapshot
  setup's `RequestFailed`
- No change to UTF-16 conversion, synchronization semantics, or ordinary
  Hover rendering
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No completion, diagnostics, diagnostic publication, or other LSP feature
- No VS Code extension or editor-specific configuration
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
