# Editor LSP 002 — Full document synchronization

**Status.** Implemented and reviewed. The focused 11-test suite, the retained
15 tests from editor-lsp 000–001, and the required hand check are green. The
recursive suite passes 1,923 of 1,925 tests; its only failures are the two
pre-existing `tests/gel/presentations/003-doc-law.rkt` wording
contradictions. This checkpoint introduces no additional failure.

## Goal

Complete the in-memory document synchronization advertised by the Aloe
server. `textDocument/didChange` applies full-content replacements and records
the supplied version, while `textDocument/didClose` forgets the exact URI.
Every synchronization notification is atomic: if its required shape or any
content-change item is malformed, the entire notification is ignored and the
previous document state remains untouched.

This checkpoint changes document state only. Hover continues to query only
when the current synchronized UTF-8 bytes equal the local file's bytes. A
dirty buffer therefore still returns JSON null without a query. Temporary
sibling snapshots are the next separate concern, not part of 002.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. Synchronization changes no Aloe syntax,
  checking, evaluation, send, or load behavior.
- `docs/editor/lsp/spec.md` is the local design authority. Section 4 defines
  open, full change, close, exact URI keys, and malformed-notification
  behavior. Sections 5–7 retain the existing hover boundary.
- Editor-lsp 000 is implemented and reviewed. It supplies framed JSON-RPC,
  the successful lifecycle, exact initialization capabilities, didOpen,
  local file URIs, the public Expression Query call, and Hover rendering.
- Editor-lsp 001 is implemented and reviewed. All synchronized text uses its
  complete UTF-16 and LF/CRLF/lone-CR position conversion.
- The existing `open-document` state contains exact `uri`, `version`, and
  `text`. Preserve that representation unless a comparably private
  representation is needed for one atomic state reducer; do not expose it
  from the normal module.

Identity is `(editor-lsp, 002)`, spoken **editor-lsp 002**. This is a local
editor checkpoint, not a global Aloe checkpoint. Do not edit
`CHECKPOINTS.md`, add a file under `docs/checkpoints/`, or reopen a predecessor
editor series.

## Preserve the accepted server boundary

The normal `aloe/lsp.rkt` module continues to export exactly:

```racket
(run-lsp-server input output error-output) ; -> exact-integer?
```

Keep its arity, imports, canonical valid framing, successful initialize and
shutdown lifecycle, exact capabilities, request-id retention, local file URI
conversion, UTF-16 position behavior, Hover format, caller-port ownership,
and clean protocol output unchanged.

The private `run-lsp-server/with-query` test-support operation retains its
four-argument arity and behavior. A valid queryable hover still invokes its
query procedure exactly once. Synchronization notifications never call the
query and never produce protocol responses.

Do not change the `textDocumentSync` advertisement: `openClose` remains true
and `change` remains `1`, `TextDocumentSyncKind.Full`. Do not advertise or
accept incremental synchronization.

All tests from `tests/editor/lsp/000-hover.rkt` and
`tests/editor/lsp/001-utf16-positions.rkt` remain green without weakening
their assertions.

## Document identity and versions

Documents remain keyed by the exact URI string supplied by the client. Do not
normalize, decode, case-fold, resolve, or convert a URI before using it as the
state key. URI conversion remains a hover-time operation only.

Two differently spelled URI strings remain different document keys even when
they convert to the same local path. Closing or changing one must not affect
the other.

Store the version value supplied by each valid `didOpen` or `didChange`
notification. A version in this checkpoint is an exact integer. Do not
require it to increase, compare it with the prior version, reject equal or
lower versions, or infer a version when it is absent. Version ordering and
client discipline are not server policy in this experiment.

The version is retained state, not an Aloe input. It does not affect parsing,
query position, Hover contents, or filesystem paths.

## `textDocument/didOpen`

Retain 000's behavior for a valid `TextDocumentItem`:

```json
{
  "textDocument": {
    "uri": "file:///absolute/document.aloe",
    "languageId": "aloe",
    "version": 1,
    "text": "...exact synchronized text..."
  }
}
```

Store the exact URI, version, and Racket string. The language identifier is
required to have the ordinary string shape but is otherwise ignored; it does
not select Aloe semantics or impose a filename extension.

A later valid `didOpen` for the same exact URI replaces that URI's stored
version and text atomically. This accommodates a simple reopen without adding
a separate duplicate-open error policy.

A malformed `didOpen` is ignored with no response and no state change. It
must not create a partial document or replace an existing document. For 002,
malformed includes a missing or non-object `params`, missing or non-object
`textDocument`, non-string or missing `uri`, non-string or missing
`languageId`, non-integer or missing `version`, or non-string or missing
`text`. Unknown extra object properties are ignored.

## `textDocument/didChange`

Accept full-content changes with this shape:

```json
{
  "textDocument": {
    "uri": "file:///absolute/document.aloe",
    "version": 2
  },
  "contentChanges": [
    { "text": "first complete replacement" },
    { "text": "last complete replacement" }
  ]
}
```

For a valid notification whose exact URI is open:

1. Start with that document's current text.
2. Apply each `contentChanges` item in array order by replacing the entire
   current text with the item's exact `text` string.
3. Leave the final item's text as the synchronized document text.
4. Record the supplied version after the complete change list validates.

An empty `contentChanges` array is valid: it leaves the text unchanged and
records the supplied version. Do not concatenate changes, interpret them as
patches, parse them, normalize line endings, or write them to disk.

A valid change for an unopened URI is ignored and does not implicitly open a
document. A change for one exact URI key does not update an equivalent URI
spelling stored under another key.

Every change item must be an object with a string `text` property and without
`range` or `rangeLength`. Unknown extra properties other than those two are
ignored. The presence of `range` or `rangeLength`, even with a null value,
denotes a shape outside full synchronization and invalidates the entire
notification.

A malformed `didChange` is ignored with no response and no state change.
Malformed includes a missing/wrong-shaped `params`, `textDocument`, URI,
version, or `contentChanges`, or any malformed/incremental item anywhere in
the array. Validate the complete notification and every item before changing
the hash, text, or version. In particular, a valid first item followed by an
invalid second item must not leave the first replacement installed.

Do not send `InvalidParams` for malformed synchronization notifications.
They are notifications and section 4 explicitly requires them to be ignored
rather than partially applied. General request validation and JSON-RPC error
handling remain later checkpoints.

## `textDocument/didClose`

Accept:

```json
{
  "textDocument": {
    "uri": "file:///absolute/document.aloe"
  }
}
```

For a valid notification, forget the document stored under that exact URI.
Closing an unopened URI is a no-op. A malformed close notification is ignored
without changing any document and receives no response. Require the ordinary
nested objects and a string URI; ignore unknown extra properties.

After a valid close, a hover for that URI returns JSON null and does not call
the query. A later valid `didOpen` may store the same URI again as a fresh
document.

## Atomic synchronization reducer

Keep synchronization validation and mutation in one private operation used
by the framed server loop for all three methods. It may mutate the server's
private document hash only after the whole notification has validated. Do
not duplicate didOpen/change/close state rules between production and tests.

For direct state assertions, expose that operation only through the existing
`(module* test-support #f ...)` submodule under a narrow name such as:

```racket
(apply-document-sync! documents method params) ; -> void?
```

The test passes a fresh mutable hash, one of the three exact method strings,
and the decoded `params` JSON value. The operation is not exported by the
normal `aloe/lsp.rkt` module. The test-support submodule may additionally
export the `open-document` predicate/accessors needed to inspect exact URI,
version, and text, but it must not export its constructor or expose the live
document hash owned by `run-lsp-server`.

The server loop and this test seam must call the same reducer. Do not build a
second test-only model of synchronization.

## Hover interaction

Every hover looks up the exact URI in the current synchronized state at that
point in the serial message stream:

- after valid `didOpen`, it sees the opened text;
- after valid `didChange`, it sees the last full replacement;
- after malformed or unopened-URI `didChange`, it sees the prior state;
- after valid `didClose`, it sees no document; and
- after a valid reopen, it sees the newly opened text and version.

Coordinate conversion always uses that current synchronized text. The local
path is still derived from the exact URI only for hover.

The unchanged-disk gate remains final for this checkpoint. If a current
replacement differs from disk, hover returns JSON null without calling the
query. If the final replacement exactly matches disk, hover may query it even
when an earlier replacement in the same notification did not match. Never
fall back to an older synchronized version merely because it matches disk.

Do not read from disk during open/change/close and do not write, rename,
remove, or create any source or temporary file in production.

## Exact file scope

Implementation may edit only:

- `aloe/lsp.rkt`; and
- `tests/editor/lsp/002-document-sync.rkt` (new).

The new tests may create and unconditionally remove exact temporary files or
directories under the system temporary directory. No checked-in fixture is
needed for this slice.

Do not edit:

- `info.rkt`, `SPEC.md`, `CHECKPOINTS.md`, or anything under
  `docs/checkpoints/`;
- the LSP spec, charter, README, checkpoint documents, prior LSP tests, or the
  Point fixture;
- `aloe/expression-query.rkt` or any other Aloe production module;
- another editor project's source, tests, fixtures, or documentation; or
- `gel/`, `lib/`, `host/`, `examples/`, or `docs/gel/`.

If synchronization requires changing Expression Query, adding incremental
range edits, imposing a version-order policy, or touching the filesystem
during a notification, stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/lsp/002-document-sync.rkt`. It is three directories below
the repository root, so use `../../../aloe/...` for repository-root module
paths. Test both the private reducer's exact state and framed server behavior;
do not test a separate model.

Use temporary local files only where hover's unchanged-disk gate is part of
the assertion. Create and remove them with an unconditional cleanup action.
Never change the process-wide current directory without restoring it.

Cover at least:

1. The reducer stores the exact URI, version, and text from a valid didOpen.
   A second valid didOpen for the same URI atomically replaces version and
   text. Extra object properties do not affect the stored values.
2. A valid didChange with at least two full replacements leaves the last text
   and supplied version. An empty change list retains text while recording
   its version. Equal and lower integer versions are stored exactly rather
   than rejected.
3. Two distinct URI strings that convert to the same path remain independent
   keys. Changing or closing one leaves the other's exact state untouched.
4. A valid didChange for an unopened URI and a valid didClose for an unopened
   URI are no-ops and do not create a key.
5. Table-drive malformed didOpen, didChange, and didClose shapes. Starting
   from a known state, assert the complete hash remains equal after each.
   Include missing nested objects and required fields, wrong field types, a
   non-array `contentChanges`, a non-object change item, missing/non-string
   change text, `range`, and `rangeLength`.
6. A didChange containing a valid first full replacement and an invalid
   second item changes neither text nor version. Prove validation occurs
   before mutation rather than rolling forward partially.
7. In one framed exchange, open initial text, send a valid didChange whose
   multiple replacements end with the exact bytes already on disk, then
   hover at a position meaningful only in the final text. The query stub is
   called exactly once with the position converted against that final text.
   The change notification emits no response.
8. In one framed exchange, open text matching disk, send a malformed change,
   and hover. The query observes the original text and position, proving the
   malformed notification was ignored. The server then shuts down and exits
   cleanly.
9. After a valid didClose, hover on that URI returns JSON null with zero query
   calls. A later valid reopen restores hover behavior from its new text.
   Open, close, and reopen notifications emit no responses.
10. A valid didChange ending in dirty text returns JSON null with zero query
    calls, leaves the original file bytes unchanged, and creates no sibling
    file. No older synchronized text is queried as a fallback.
11. The normal module still exports only `run-lsp-server`. The reducer,
    document structure/accessors, state hash, and test-support runners remain
    unavailable from the normal module.
12. Both prior LSP suites remain green, including full Unicode position
    conversion, the Point integration, framing, and stale-disk protection.

For framed tests, independently construct and decode canonical byte frames as
in the prior suites. Assert exact response counts so every synchronization
notification is proven response-free.

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
REPL at the repository root using the test-support query seam:

- create a temporary file containing the final synchronized text;
- open the same URI with different initial text;
- send one didChange containing two full replacements whose last text equals
  disk;
- hover at a position unique to the final text and observe exactly one query
  call at its converted position;
- close the URI and observe a second hover return JSON null with no additional
  query call; and
- shut down, exit with status 0, and remove the exact temporary file.

Run:

```sh
raco test tests/editor/lsp/000-hover.rkt
raco test tests/editor/lsp/001-utf16-positions.rkt
raco test tests/editor/lsp/002-document-sync.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directory.

The checkpoint is complete when full changes and closes update exact URI
state atomically, malformed notifications preserve the entire prior state,
every hover observes the current synchronized text, prior suites remain
green, and the recursive suite has no new failure. Stop for review without
committing. Do not begin editor-lsp 003.

## Explicit non-goals

- No incremental changes, text ranges, range lengths, or version ordering
- No dirty-buffer sibling snapshot, loaded-document overlay, or source-file
  mutation
- No malformed framing/JSON recovery or general JSON-RPC request validation
- No complete lifecycle error matrix, cancellation, or unsupported-request
  errors
- No query/parser/checker/load failure classification or `RequestFailed`
- No change to UTF-16/line-break conversion or Hover rendering
- No `main` submodule, installed-package launch, command-line argument, or
  process-level smoke test
- No completion, diagnostics, diagnostic publication, or other LSP feature
- No VS Code extension or editor-specific configuration
- No second parser, checker, evaluator, method catalog, or direct
  `type-signature-specs` call
- No Aloe syntax, special form, macro, implicit call, coercion, inheritance,
  mutation, Gel, or Boids work
