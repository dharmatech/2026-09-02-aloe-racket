# Editor completion 003 — LSP selector completion

**Status.** Implemented and reviewed. The focused 13-test protocol suite and
all 304 completion/LSP predecessor tests are green. The manual Boids exchange
returns the eight ordered Point Float items with the common UTF-16 range
19:37–19:42, status 0, empty error output, unchanged files, and no snapshot
residue. The recursive suite passes 2,214 of 2,216 tests; its only failures
are the two documented pre-existing
`tests/gel/presentations/003-doc-law.rkt` contradictions. This checkpoint
introduces no additional failure.

## Goal

Add the reviewed public selector-completion query to the existing serial LSP
adapter. Advertise one standard completion capability, accept
`textDocument/completion`, convert the synchronized UTF-16 cursor to the
public query's one-based Racket position, and convert every returned original-
buffer edit range back to UTF-16 `textEdit` coordinates.

This is the final editor-completion slice. It changes no completion recovery,
checker observation, catalog, filtering, or item formatting, and it changes no
VS Code production file. The existing language client will forward the
standard server capability.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. A list head is a receiver, the second
  element is a literal selector, and functions run only through `call`.
- `docs/editor/completion/spec.md` is the local design authority. Sections
  6–8 define capability advertisement, request adaptation, protocol coverage,
  and the unchanged thin-client boundary.
- Editor-completion 000–002 are implemented and reviewed. In particular,
  `aloe/completion-query.rkt` is the only source of selector rows, filtering,
  formatting, and original-source replacement ranges.
- Editor-lsp 000–009 are implemented and reviewed. They own framing,
  JSON-RPC validation, lifecycle precedence, full-document synchronization,
  local-file URI decoding, UTF-16 conversion, Hover snapshots and rendering,
  failure containment, stdio launch, and process status.
- The completion specification amends the older hover-only LSP specification
  solely for the capability and request described here. Historical LSP
  checkpoint documents remain records of their slices and are not edited.

Identity is `(editor-completion, 003)`, spoken **editor-completion 003**. This
is a local editor checkpoint, not editor-lsp 010 and not global checkpoint
118. Do not edit `CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Preserve the accepted adapter

The normal `aloe/lsp.rkt` surface remains exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

Requiring the normal module remains inert. Its `main` submodule still accepts
no arguments, uses the current standard ports, and exits with the exact server
status. Neither entry point closes caller-owned ports.

Keep byte framing, JSON decoding, ids, errors, request/notification roles,
lifecycle states and precedence, full synchronization, URI handling, UTF-16
rules, Hover snapshot behavior, Hover query and rendering, response ordering,
failure recovery, and launch behavior unchanged. Completion must share those
accepted mechanisms rather than creating a second dispatcher, document store,
position converter, framing loop, or lifecycle.

All existing Hover requests still call `query-expression-at` under their
accepted direct/sibling-snapshot policy. Completion never calls
`query-expression-at` and never creates a snapshot. A mixed stream may
interleave Hover and completion requests without either query seam or failure
policy leaking into the other.

## Exact initialization amendment

The initialize result is now exactly:

```json
{
  "capabilities": {
    "positionEncoding": "utf-16",
    "textDocumentSync": {
      "openClose": true,
      "change": 1
    },
    "hoverProvider": true,
    "completionProvider": {
      "triggerCharacters": [" "]
    }
  },
  "serverInfo": {
    "name": "aloe-lsp"
  }
}
```

Space is the sole trigger character. Manual invocation remains available.
Do not advertise `.`, selector characters, `resolveProvider`, completion item
defaults, work-done progress, diagnostics, or another capability. The result
must be identical through the in-process server, the test seams, and
`racket -l aloe/lsp`.

## Request shape, lifecycle, and empty results

Add `"textDocument/completion"` to the active-state supported request methods.
Its required parameter shape is the same `TextDocumentPositionParams` core
already accepted for Hover:

- `params` is present and is an object;
- `textDocument` is an object containing a string `uri`; and
- `position` is an object containing exact nonnegative integer `line` and
  `character` fields.

Ordinary extra CompletionParams fields may be present and are ignored. Do not
interpret trigger context or make results depend on whether invocation was
manual or triggered. A malformed required shape receives the existing
`Invalid params` response `-32602` with the original request id.

Retain lifecycle precedence. Before initialization, a well- or malformed
completion request receives `Server not initialized`. After shutdown it
receives `Invalid Request`. A completion-shaped notification is unsupported
and ignored without a response. Completion does not alter document or
lifecycle state.

A validly shaped request returns a successful empty JSON array, not null,
when the exact URI is unopened, the URI is unsupported or not an absolute
local `file:` URI, the LSP position is out of range or splits a surrogate
pair, or the public query returns the empty list for an ineligible,
unrecoverable, failed, or no-match source.

## Exact synchronized query boundary

For an open absolute local `file:` document:

1. Read the exact current string from the existing document store.
2. Decode the URI with the existing `uri->local-path` operation.
3. Convert the request's zero-based UTF-16 line and character to the one-based
   Racket character boundary with the existing
   `lsp-position->query-position` operation.
4. If path and position are valid, call `query-selector-completions` exactly
   once with:

   ```racket
   (query-selector-completions
    synchronized-text query-position #:source-path decoded-path)
   ```

5. Adapt the returned list in order against that same synchronized string.

Do not compare the root buffer with disk and do not call
`query-synchronized-document`. Completion's public query accepts the current
source string directly; the decoded original path supplies only the base for
ordinary Aloe loads. The root path may be missing, dirty, or read-only and is
never opened, overwritten, renamed, snapshotted, or removed by the adapter.
Loaded files continue to come from disk through the public query.

Do not write synchronized text to the document path, system temporary
directory, or a sibling. No `aloe-lsp-snapshot-*` file is created for
completion. Hover retains its existing sibling behavior without change.

## Exact CompletionItem adaptation

The public query's result must be a proper list of
`selector-completion-item` values. Each item's label, detail, and insert text
must be strings, its replacement start must be an exact positive integer, and
its replacement span must be an exact nonnegative integer. The transparent
structure predicate alone does not establish those field contracts. Preserve
list order and multiplicity. For each item, produce exactly:

```json
{
  "label": "dist2",
  "detail": "((Point Float)) -> Float",
  "insertText": "dist2",
  "textEdit": {
    "range": {
      "start": { "line": 0, "character": 24 },
      "end": { "line": 0, "character": 28 }
    },
    "newText": "dist2"
  }
}
```

The example coordinates are illustrative. Copy `label`, `detail`, and
`insert-text` verbatim from the public item. `textEdit.newText` is the same
item's `insert-text`.

For item replacement start `s` and character span `n`, convert the absolute
Racket offsets `s - 1` and `s - 1 + n` with the existing
`offset->lsp-position` operation against the exact synchronized text. The LSP
range is start-inclusive and end-exclusive. This preserves zero-width holes,
whole partial-token replacement, CR/LF/CRLF rules, and UTF-16 widths without
recomputing a prefix from the request position.

Return the item array directly as the JSON-RPC result. Do not wrap it in a
CompletionList and do not add `isIncomplete`, kind, sort text, filter text,
snippet format, documentation, command, commit characters, data, tags, or
resolve metadata. Do not sort, deduplicate, regroup, or filter the public
items in the adapter.

The adapter may import only `query-selector-completions`,
`selector-completion-item?`, and its five public accessors from
`aloe/completion-query.rkt`. It must not import completion recovery, parser or
checker internals, `signature-catalog.rkt`, or `type-signature-specs`, and it
must not name Point, Boids, kernel, List, or String selectors in production.

## Completion failure boundary

The reviewed public query converts ordinary source failures to an empty list.
Once called with valid adapter arguments, a raised ordinary exception or a
value outside the public result contract is therefore an unexpected adapter
failure, not an empty completion result.

Return exactly this recoverable response when the injected query raises an
`exn:fail?`, returns a non-list or improper list, returns a non-item member,
returns an item with a wrong field kind, an item accessor fails, or an item's
start/span cannot form a valid UTF-16 range against synchronized text:

```json
{
  "jsonrpc": "2.0",
  "id": "original-request-id",
  "error": {
    "code": -32803,
    "message": "unable to produce completion result"
  }
}
```

It has no `result` or `data`, preserves string and numeric ids, writes no
exception text or diagnostic, changes no document/lifecycle state, and leaves
the server available for later completion, Hover, shutdown, and exit.

Use a narrow in-memory completion-outcome boundary. It may cover URI/position,
query invocation, contract validation, range conversion, and JSON item
construction. The response writer, loop recursion, later frame reads,
lifecycle, and Hover computation remain outside it. An output write or flush
failure must not be caught and retried as a completion error. Catch
`exn:fail?`, not `exn?`; breaks and non-failure control transfers propagate.

This boundary is completion-specific. Do not change Hover's accepted
distinction among null query outcomes, snapshot-specific RequestFailed, and
generic Hover-adapter RequestFailed.

## Test-support seams

Preserve the existing test-support operation and its exact arity:

```racket
(run-lsp-server/with-query input output error-output hover-query) ; arity 4
```

It continues to inject only Hover behavior and delegates completion requests
to the real public completion query. Every predecessor test using it must keep
the same meaning.

Add one test-support-only operation:

```racket
(run-lsp-server/with-queries
 input output error-output hover-query completion-query) ; arity 5
```

Both query arguments reach the same production dispatcher and outcome
boundaries. `run-lsp-server` supplies the real public Hover and completion
queries; the old seam supplies its injected Hover query plus the real public
completion query. Neither seam is exported from the normal module.

The completion query procedure receives the exact source and one-based
position as positional arguments and the decoded path through
`#:source-path`. Tests may inject a keyword-accepting procedure to record or
malform completion outcomes; do not add a production host/environment/query
parameter.

## Authorized predecessor-test migrations

The new capability and second public query dependency intentionally supersede
two old negative assumptions. Make only these mechanical migrations:

1. In `tests/editor/lsp/000-hover.rkt`,
   `005-framing.rkt`, `006-json-rpc.rkt`, `007-lifecycle.rkt`,
   `008-adapter-failures.rkt`, and `009-launch.rkt`, add the exact
   `completionProvider` object above to each shared expected initialize
   result.
2. In `tests/editor/lsp/000-hover.rkt`, replace the assertion that
   `completionProvider` is absent with an assertion of its exact one-space
   trigger shape. Retain the diagnostic-capability absence assertion.
3. In the production-dependency source assertions in
   `tests/editor/lsp/004-hover-results.rkt` and
   `008-adapter-failures.rkt`, change the exact expected `.rkt` import list
   from only `expression-query.rkt` to exactly the two public modules
   `expression-query.rkt` and `completion-query.rkt` in actual source order.

Do not relax equality to subset checks, remove another assertion, change a
Hover value/range/status, alter a request stream, or edit any other predecessor
test. The historical checkpoint documents are not migrated.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`;
- `tests/editor/completion/003-lsp-completion.rkt` (new); and
- the seven predecessor tests named in the authorized migration:
  `tests/editor/lsp/000-hover.rkt`, `004-hover-results.rkt`,
  `005-framing.rkt`, `006-json-rpc.rkt`, `007-lifecycle.rkt`,
  `008-adapter-failures.rkt`, and `009-launch.rkt`, only as stated there.

Do not edit:

- `aloe/completion-query.rkt`, `aloe/expression-query.rkt`, completion
  recovery, `aloe/type.rkt`, parser, catalog, evaluator, driver, or host code;
- completion tests 000–002 or LSP tests 001–003;
- either reviewed spec, any charter, README, or checkpoint document;
- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- `.vscode/`, the VS Code extension, package manifest, grammar, JavaScript, or
  TypeScript; or
- `gel/`, `lib/`, `host/`, `examples/`, and existing fixtures.

Tests may create isolated temporary files/directories and must remove them in
an unconditional cleanup action. They must not modify a checked-in source or
the user's package database. If implementation requires a public-query,
position-conversion, framing, document-sync, launch, or client change outside
this scope, stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/completion/003-lsp-completion.rkt`. It is three directories
below the repository root, so use `../../../aloe/...` and
`../../../examples/...` paths. Construct and decode real byte-framed messages;
compare decoded JSON values in exact order and inspect raw output for canonical
protocol-only framing.

Cover at least:

1. Initialization advertises the exact capability object above through the
   public server and both test seams. Pin `triggerCharacters` to the one-item
   JSON array containing a single space and prove there is no `.` trigger or
   resolve provider.
2. Pin the normal public export to only `run-lsp-server` with arity 3, the old
   test seam to arity 4, and the new seam to arity 5. Requiring the normal
   module remains inert and the `main` submodule/source retains its one
   launcher and no-argument policy.
3. Through the new seam, prove one valid completion request calls only the
   completion procedure exactly once with the exact synchronized string,
   converted one-based boundary, and decoded complete path. A Hover request
   calls only the Hover procedure. Query arguments and private values do not
   appear in protocol or error output.
4. Use the real public completion query on exact synchronized Point or Boids
   text and compare every CompletionItem field and order. At Boids LSP
   position `{line: 19, character: 37}`, the complete `dist2` token returns
   the eight Point Float rows in catalog order, each editing
   `{line: 19, character: 37}` through
   `{line: 19, character: 42}`.
5. Open exact `examples/point.aloe`, first retain its established Hover result,
   then full-change the synchronized text to append
   `"\n((Point new 1.0 2.0) d"`. Completion at
   `{line: 34, character: 22}` returns `dist2` then `dot`, each replacing
   `{line: 34, character: 21}` through
   `{line: 34, character: 22}`. The checked-in file stays byte-identical and
   no sibling snapshot is created for that completion.
6. Pin UTF-16 request and edit conversion with exact synchronized source
   `("😀" l)`. A request at `{line: 0, character: 7}` returns only `len`,
   detail `() -> Int`, and edit range `{line: 0, character: 6}` through
   `{line: 0, character: 7}`. Positions that split the emoji surrogate pair
   return an empty array without a query call.
7. Use a missing root URI with an existing sibling load and an incomplete
   synchronized buffer such as
   `(load "support.aloe")\n((Loaded003 new 1) v`. Completion at line 1,
   character 20 returns `value` with range 1:19–1:20. Prove relative load
   resolution, missing-root preservation, byte-identical support source,
   unchanged directory entries, and no snapshot residue.
8. An eligible no-match source, unopened URI, non-file or remote-authority
   URI, invalid line/character, split surrogate, ineligible source, and public
   source failure each produce a successful empty JSON array. None produces
   null, a diagnostic, Hover prose, or a query call where validation should
   reject first.
9. Missing params, null params, wrong field kinds, negative positions, and
   incomplete nested objects receive exact `-32602`. Extra valid completion
   context is ignored. Pre-initialize and post-shutdown precedence remains
   exact, completion notifications are ignored, and request ids are retained.
10. Inject an ordinary query exception, non-list, improper list, non-item
    member, wrong item field kind, and invalid item range. Each produces exact
    completion `-32803` without private prose; a later valid completion and
    Hover succeed, then shutdown/exit returns status 0.
11. Prove completion output writing is outside the failure boundary with a
    purpose-built failing output port or a narrow source assertion. A write or
    flush failure is not caught and retried as a second response. Breaks are
    not caught. Caller-owned ports remain open after ordinary recoverable
    exchanges.
12. Pin duplicate and escaped labels through injected valid public item
    structures. Preserve order and multiplicity, copy strings verbatim, use
    each full original replacement range, and emit exactly the four specified
    CompletionItem fields with no CompletionList wrapper or extra metadata.
13. Inspect production source narrowly enough to prove the adapter imports
    only the two public query modules, names no selector catalog, calls no
    parser/checker/evaluator, does not snapshot in the completion path, and
    has no sorting, deduplication, snippets, diagnostics, second dispatcher,
    client code, or selector fixtures. Behavior tests remain primary; do not
    pin harmless helper names or whitespace.
14. Every completion 000–002 and LSP 000–009 suite remains green after only
    the authorized expectation migrations. In particular, exact Hover text,
    ranges, snapshot cleanup/failures, adapter errors, lifecycle statuses,
    framing, public inertness, and installed-module launch are unchanged.

The focused protocol test may import public completion item bindings to build
injected results. It must not import private recovery/checker operations or
construct signature rows as an alternate production catalog.

## Baseline and verification

Before this checkpoint, completion 000–002 pass 203 tests and editor-lsp
000–009 pass 101 tests. The recursive suite passes 2,201 of 2,203 tests. Its
only failures are the two documented pre-existing contradictions in
`tests/gel/presentations/003-doc-law.rkt`.

Run:

```sh
raco test tests/editor/completion/003-lsp-completion.rkt
raco test tests/editor/completion/002-public-query.rkt
raco test tests/editor/completion/001-contextual-receiver.rkt
raco test tests/editor/completion/000-selector-recovery.rkt
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests/editor/lsp/003-buffer-snapshots.rkt
raco test tests/editor/lsp/004-hover-results.rkt
raco test tests/editor/lsp/005-framing.rkt
raco test tests/editor/lsp/006-json-rpc.rkt
raco test tests/editor/lsp/007-lifecycle.rkt
raco test tests/editor/lsp/008-adapter-failures.rkt
raco test tests/editor/lsp/009-launch.rkt
raco test tests
git diff --check
```

Require every focused and predecessor suite to be completely green. Require
the recursive suite to retain exactly the two baseline failures with no new
failure; if that unrelated contradiction has been repaired first, require a
completely green recursive suite.

After the automated tests, run one framed interaction by hand through the
real `run-lsp-server` or installed `racket -l aloe/lsp` entry point:

- initialize and inspect the exact completion capability;
- open exact `examples/boids.aloe`;
- request completion at zero-based line 19, UTF-16 character 37;
- inspect the eight ordered Point Float items and common 19:37–19:42 edit;
- shut down and exit with status 0; and
- confirm protocol-only output, empty error output, unchanged files, and no
  snapshot residue.

The checkpoint is complete when the existing server advertises only the
specified completion capability, adapts the reviewed public query exactly
once from synchronized UTF-16 positions to ordered text edits, returns empty
arrays for ordinary misses, recovers from unexpected adapter failures, leaves
Hover and every predecessor behavior intact, and passes the required bars.
Stop for review without committing. The planned editor-completion series is
then complete.

## Explicit non-goals

- No change to completion recovery, receiver observation, catalog rows,
  filtering, formatting, or public query API
- No Hover, framing, JSON-RPC, synchronization, URI, lifecycle, snapshot,
  launch-command, package, or process-status redesign
- No completion resolve request, CompletionList, snippets, documentation,
  signature help, argument completion, top-level names/classes, fuzzy or
  ranked filtering, workspace index, cache, or loaded-buffer overlay
- No incremental synchronization, concurrency, cancellation execution,
  progress, diagnostics, semantic tokens, rename, definition, formatting, or
  code actions
- No VS Code source, manifest, grammar, command, configuration, or manual
  editor action as an acceptance dependency
- No non-file URI, remote filesystem, TCP/WebSocket transport, alternate
  launcher, shell wrapper, or client-side Aloe logic
- No evaluator, host call, Mirror invocation, Gel integration, Aloe syntax,
  implicit function application, coercion, inheritance, mutation, macro, or
  Boids source change
- No editor-lsp 010, global checkpoint 118, or work after this final local
  completion slice
