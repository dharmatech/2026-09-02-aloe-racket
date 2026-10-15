# Editor definition 003 — LSP definition

**Status.** Implemented 2026-10-15. Manager-reviewed 2026-10-15 against
this document: conforming. The human's VS Code hand check passed
2026-10-15, all six steps. Accepted.

## Goal

The Aloe language server answers `textDocument/definition`. It
advertises `definitionProvider: true` and runs `query-definition-at` on
the synchronized buffer, the way it runs the expression query for
hover. It returns one LSP `Location` or null. The VS Code client already
registers a definition provider when the server advertises one. After
this checkpoint, Go to Definition and Ctrl+click on a class name work in
VS Code.

This is the last layer of the definition spec. The implementer receives
only this document. Every rule for this slice is below.

## Depends on, identity

Identity is `(editor-definition, 003)`, spoken **editor-definition
003**. It is a local editor checkpoint. Do not edit `CHECKPOINTS.md` or
add a file under `docs/checkpoints/`.

The tree at `542fd61` (branch `experiment/2026-10-14-definition`) has
every predecessor:

- **Editor-definition 000–002.** `aloe/definition-query.rkt` provides
  `(struct definition-query-result (location text))` and
  `(query-definition-at source-path position #:document-path [document-path source-path])`.
  A result's `location` is a `srcloc` whose source is the class's
  defining path, a complete simplified path. Its position and span are
  one-based character offsets into `text`, the text the class was
  parsed from. The query returns `#f` when nothing jumps. It raises for
  a missing file, a reader or parser error, or a type error anywhere in
  the file.
- **Editor-lsp 000–010.** `aloe/lsp.rkt` serves hover and completion.
  For hover, `query-hover` reads the document's text and turns the URI
  into a local path (`uri->local-path`). It converts the LSP position
  (`lsp-position->query-position`) and queries through
  `query-synchronized-document`. That function queries the document's
  path when the disk bytes match the synchronized text. Otherwise it
  writes a temporary sibling, queries the sibling with `#:document-path`
  set to the document's path, and removes the sibling. It goes through
  `invoke-query`, which turns any `exn:fail` from the query into `#f`.
  `result-range` converts a location to an LSP range over a text, with
  `offset->lsp-position`. `hover-outcome` maps a snapshot failure, and
  any other failure, to the `-32803` messages.
- **The VS Code client.** `editors/vscode/` depends on
  `vscode-languageclient` 9.0.1. Its `registerBuiltinFeatures`
  registers `DefinitionFeature`, which registers a definition provider
  for the client's `documentSelector` when the server's capabilities
  contain `definitionProvider`. So the client needs no change. Its
  `npm test` passes 14 of 14 at `542fd61`.

## Authority

- `SPEC.md` is law and is not amended.
- [`docs/editor/definition/spec.md`](../spec.md) §5 is the design of
  this layer. §7 (LSP) is its coverage, §8 is the hand check, and §9
  lists the accepted consequences. Every rule you need is restated
  below.
- [`docs/editor/lsp/spec.md`](../../lsp/spec.md) owns framing,
  lifecycle, document sync, the temporary sibling, UTF-16 conversion,
  and hover. Its deferred-work list names definition. The definition
  spec lifts that deferral for class names only. Do not edit the LSP
  spec.
- LSP 3.17 is the protocol for `textDocument/definition`.

## Required behavior

All product changes are in `aloe/lsp.rkt`.

### Capability

The initialize result gains `definitionProvider: true` as the last
capability. The result is exactly:

```json
{
  "capabilities": {
    "positionEncoding": "utf-16",
    "textDocumentSync": { "openClose": true, "change": 1 },
    "hoverProvider": true,
    "completionProvider": { "triggerCharacters": [" "] },
    "definitionProvider": true
  },
  "serverInfo": { "name": "aloe-lsp" }
}
```

### Request

- Add `"textDocument/definition"` to the supported request methods.
- Its params are hover's `TextDocumentPositionParams` shape, checked
  the same way. Extra keys such as `workDoneToken` and
  `partialResultToken` are ignored. Invalid params get `-32602`
  `"Invalid params"`.
- Lifecycle is hover's. Before initialize the request gets `-32002`
  `"Server not initialized"`. After shutdown it gets `-32600`
  `"Invalid Request"`.
- Hover and completion are unchanged.

The flow is hover's:

1. Find the open document by the request's exact URI. An unopened
   document gives null.
2. Turn the URI into a local path with `uri->local-path`. An
   unsupported URI gives null.
3. Turn the LSP position into a query position with
   `lsp-position->query-position` over the synchronized text. An
   invalid position gives null.
4. Query through `query-synchronized-document`: the document's path
   when the disk bytes match, otherwise a temporary sibling queried with
   `#:document-path` set to the document's path and removed afterwards.
   A query that raises counts as no answer (null), as `invoke-query`
   already does for hover. Reuse `invoke-query` and
   `query-synchronized-document`. Do not write a second copy.

So one definition request makes at most one query call. It makes none
for an unopened document, an unsupported URI, or an invalid position.

### Result

The result is one LSP `Location`, or JSON null. It is never a list and
never a `LocationLink`.

For a `definition-query-result` with location `L` and text `T`:

- **uri.** Let `source` be `L`'s source. Compare
  `(simplify-path source #f)` with `(simplify-path document-path #f)`,
  where `document-path` is the document's local path. Neither call
  touches the filesystem. When they are `equal?`, the `uri` is the
  document's URI string exactly as the client sent it, including any
  percent-encoding. Otherwise it is `(url->string (path->url source))`.
  The temporary sibling never appears, because the query rebuilds
  `source` from the defining path.
- **range.** If `L` starts at `s` with span `n`, convert the character
  offsets `s - 1` and `s - 1 + n` with the existing
  `offset->lsp-position` over `T`, not over the document's text. When
  `L` names the queried document, `T` is the synchronized text, because
  the query read exactly those bytes. For a loaded file, `T` is the
  bytes that were checked. Factor the conversion out of `result-range`
  so hover and definition share it, and leave hover's results unchanged.

The result is null when:

- no token jumps;
- the document is unopened, or is not a supported local file URI;
- the position is invalid;
- the buffer is incomplete, malformed, or fails checking;
- a needed file cannot be read;
- the range cannot be converted;
- `L` is not a `srcloc` whose source is a path, or `T` is not a
  string.

None of these are diagnostics, and this checkpoint publishes no
diagnostics.

### Failures

Map failures the way `hover-outcome` does, with a definition message:

- A snapshot failure is `-32803` `"unable to create synchronized document snapshot"`.
- Any other failure in the definition path is `-32803`
  `"unable to produce definition result"`. That includes a query that
  returns a value that is neither `#f` nor a `definition-query-result`.

The server stays available after either one.

### Imports and test hook

- `aloe/lsp.rkt` imports `query-definition-at`,
  `definition-query-result?`, `definition-query-result-location`, and
  `definition-query-result-text` from `"definition-query.rkt"`. Put that
  `require` **after** the one for `"completion-query.rkt"`, so the
  module names appear in the source in the order expression, completion,
  definition. Three tests pin that order (below).
- Also import `path->url` and `url->string` from `net/url`.
- Import nothing from the parser or the checker. Do not use
  `exn-message`, `exn?`, or any name the existing boundary tests forbid.
- `run-lsp-server/with-queries` in the `test-support` submodule gains
  an optional keyword argument, `#:definition-query`, which defaults to
  `query-definition-at`. Its five positional arguments are unchanged, so
  `(procedure-arity support:run-lsp-server/with-queries)` stays 5, and
  every existing call is unchanged. `run-lsp-server` and
  `run-lsp-server/with-query` use the default.
- A definition stub is called as `(query path position)`, or as
  `(query path position #:document-path document-path)` on the sibling
  path, exactly as hover's stubs are.
- `aloe/lsp.rkt` still provides only `run-lsp-server`.

### Migration

The new capability and the new `require` break pins in exactly eight
existing test files. A scratch run of the product change showed 57
failures, all in these files. After the edits below, none remained.
Make exactly these edits and nothing else in these files:

| File | Edit |
|---|---|
| `tests/editor/lsp/000-hover.rkt` | expected initialize result: add `'definitionProvider #t` after the `'completionProvider` entry |
| `tests/editor/lsp/005-framing.rkt` | the same |
| `tests/editor/lsp/006-json-rpc.rkt` | the same |
| `tests/editor/lsp/007-lifecycle.rkt` | the same |
| `tests/editor/lsp/009-launch.rkt` | the same |
| `tests/editor/lsp/008-adapter-failures.rkt` | the same, and in the test-case `"source keeps the adapter boundary narrow"`, add `"\"definition-query.rkt\""` as a third element after `"\"completion-query.rkt\""` |
| `tests/editor/completion/003-lsp-completion.rkt` | the same initialize edit, and in `"production composition remains narrow and completion-specific"`, the same third element |
| `tests/editor/lsp/004-hover-results.rkt` | in `"source keeps one public query dependency and a narrow failure boundary"`, the same third element |

The initialize pins are at `000-hover.rkt:49`, `005-framing.rkt:181`,
`006-json-rpc.rkt:125`, `007-lifecycle.rkt:127`,
`008-adapter-failures.rkt:51`, `009-launch.rkt:33`, and
`003-lsp-completion.rkt:40`. The module-list pins are at
`004-hover-results.rkt:475`, `008-adapter-failures.rkt:702`, and
`003-lsp-completion.rkt:892`. Line numbers are as of `542fd61`.

If any other existing test fails, stop and report it.

## Exact file scope

May edit:

- `aloe/lsp.rkt`
- the eight test files above, only for the edits in the table
- `tests/editor/definition/003-lsp-definition.rkt` (new)
- `docs/editor/definition/README.md` and `docs/editor/README.md`, for
  the status lines below

Do not edit:

- `aloe/definition-query.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/type.rkt`, `aloe/parse.rkt`, or
  anything under `aloe/private/`
- `editors/vscode/`. After the change, `git diff --stat -- editors/vscode`
  is empty
- any fixture. This checkpoint reuses `tests/editor/definition/fixtures/`
  and adds no `.aloe` file, so the census count does not change
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or any spec,
  charter, or checkpoint document, this one included
- `lib/`, `examples/`, `gel/`, or `host/`

## Required tests

Add `tests/editor/definition/003-lsp-definition.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` for
module paths, and `define-runtime-path` for the fixtures and
`lib/option.aloe`. Drive the server with framed messages in-process, as
`tests/editor/lsp/000-hover.rkt` does. Require `aloe/lsp.rkt`, its
`test-support` submodule, and `aloe/definition-query.rkt` (for stub
results). Temporary files go in a directory under
`(find-system-path 'temp-dir)` and are removed unconditionally.

Write the `shapes.aloe` URI percent-encoded, as `000-hover.rkt` writes
its fixture's. Take `(url->string (path->url <complete path>))` and
replace the trailing `shapes.aloe` with `%73hapes%2Ealoe`. Every other
URI is `(url->string (path->url <complete simplified path>))`. LSP
positions are written `line:character`, zero-based.

1. **Initialize.** The initialize result is exactly the JSON above.
2. **Jumps.** Open `shapes.aloe` with its disk text, under the
   percent-encoded URI. Then:

   | Request | Result `uri` | Result range |
   |---|---|---|
   | `Box` at 26:7 | the percent-encoded URI, exactly as sent | 6:15–6:18 |
   | `Point` at 9:12 | the URI of `point.aloe` | 0:14–0:19 |
   | `Option` at 10:12 | the URI of `lib/option.aloe` | 0:15–0:21 |

3. **UTF-16.** Open `wide-user.aloe` with its disk text. `Wide` at 1:11
   returns the URI of `wide.aloe` and range 0:33–0:37. The emoji before
   `Wide` counts two UTF-16 units.
4. **A queried library.** Open `lib/option.aloe` with its disk text
   under its own URI. Its header at 0:15 returns that same URI and
   range 0:15–0:21.
5. **A dirty buffer.** Open `shapes.aloe`, then send a `didChange`
   whose full text is one LF followed by the disk text. `Box` at 27:7
   returns the document's percent-encoded URI and range 7:15–7:18.
   Afterwards the fixtures directory lists the same entries as before,
   so no sibling remains, and `shapes.aloe`'s bytes on disk are
   unchanged.
6. **Null.** Each of these returns a successful response whose result
   is JSON null:
   - `new` at 13:13 of the clean `shapes.aloe`, a miss;
   - a request for a URI that was never opened;
   - `untitled:Untitled-1`, opened with `(define x 1)` and queried at
     0:8, an unsupported URI;
   - 500:0 and 0:900 in `shapes.aloe`, invalid positions;
   - `shapes.aloe` opened with `(define oops (1 + "x"))` and a LF
     appended to its text, queried at `Box`, 6:15. This is a type error;
   - after a `didChange` to `"(define-class"`, a query at 0:1. This is a
     malformed buffer.

   After the malformed buffer, a `didChange` back to the disk text makes
   `Box` at 6:15 jump again. The server keeps answering.
7. **Errors.**
   - A definition request whose params have no `position` gets
     `-32602` `"Invalid params"`.
   - A definition request before initialize gets `-32002`
     `"Server not initialized"`.
   - A definition request after shutdown gets `-32600`
     `"Invalid Request"`.
8. **Counting stub.** Pass a stub as `#:definition-query` that counts
   its calls, records its arguments, and returns `#f`. Send these
   requests: a definition at 6:15 of the clean `shapes.aloe`, one for an
   unopened URI, one at 500:0, then (after a `didChange` that prepends a
   LF) one at 7:15. The stub sees exactly two calls. The first gets the
   document's local path and no `#:document-path`. The second gets a
   different path in the same directory, with `#:document-path` equal
   to the document's local path. Every response is null.
9. **Adapter failures.**
   - Open a document whose parent path component is a regular file (as
     `008-adapter-failures.rkt` does), with text that differs from the
     disk. A definition request there gets `-32803`
     `"unable to create synchronized document snapshot"`. The blocking
     file's bytes and its directory's entries are unchanged.
   - A stub that returns `'not-a-result` gets `-32803`
     `"unable to produce definition result"`.
   - A stub that returns
     `(definition-query-result (srcloc <the document's path> 1 0 1 500) "(define x 1)\n")`
     gets null, because the range cannot be converted.
   - After each failure, a later request on the same server is
     answered.
10. **Hover is unchanged.** On the clean `shapes.aloe`, hover at 35:10
    returns exactly this text, with range 35:10–35:15:

    ```text
    type: (Class Point)
    from: (Class Point@tests/editor/definition/fixtures/point.aloe)
    messages:
      new : (Int Int) -> Point
    ```

Then check the client. In `editors/vscode/`, `npm test` passes, and
`git diff --stat -- editors/vscode` prints nothing.

## Scratch run

On 2026-10-15 a prototype of this checkpoint was applied to a copy of
the tree at `542fd61`. It added about 100 lines to `aloe/lsp.rkt`.

- Before the migration, the whole suite had 57 failures out of 3045,
  all in the eight files of the table.
- After the ten table edits, the only failure was
  `tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar under `-j 4`
  (32.8 ms). That bar times evaluation only, and it passes alone.
- Every exchange in tests 1–10 gave the listed responses, including
  the exact percent-encoded URI echo, the sibling cleanup, the two
  stub calls, and both `-32803` messages.
- The query answered every hand-check cursor below in under 0.1 s.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/definition/003-lsp-definition.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

and, in `editors/vscode/`:

```sh
npm test
```

All green. The whole suite is 3045 tests plus this checkpoint's new
test-cases. If only `tests/aloemacs/window-pictures.rkt`'s 30 ms timing
bar fails under `-j 4`, run that file alone, and it must pass there.

Update the status lines:

- In `docs/editor/definition/README.md`, add a row for
  `checkpoints/003-lsp-definition.md`: "Implemented *date*, awaiting
  review and the hand check", with the focused test count and the
  whole-suite count.
- In `docs/editor/README.md`, set project 8's cell to say
  editor-definition 003 is implemented and awaiting review and the hand
  check.

Stop for review without committing.

## Hand check (the human, during review)

This check is the human's, in VS Code. The implementer does not run it,
and does not claim it.

The test command above rebuilds the bytecode `racket -l aloe/lsp` loads.
After it, reload the VS Code window so the extension restarts the server
and reads the new capability. Put the caret inside the name or
Ctrl+click it. A caret just after a name's last character addresses the
next character, which is a miss, as hover's containment is. Line
numbers are as of `542fd61`. If `file.aloe` has moved, find each line by
its text.

1. Open `examples/aloemacs/file.aloe`. Go to definition on
   `AloemacsBuffer` in `(AloemacsBuffer new` on line 1488, inside an
   `AloemacsSession` method. The editor moves to line 132,
   `(define-class AloemacsBuffer`, with the caret at the start of the
   name, and the name highlights briefly.
2. Go to definition on `Position` in `(Position new 0 0)` on line 239.
   `lib/text.aloe` opens at line 3, on `Position`.
3. Go to definition on the field type in
   `(current-buffer AloemacsBuffer)` on line 152. It lands on line 132.
   Then go to definition on `Option` in
   `(pending (Option (AloemacsKeymap AloemacsBinding)))` on line 1240.
   `lib/option.aloe` opens on `Option`.
4. Open `examples/aloemacs/main.aloe`. Go to definition on
   `AloemacsBuffer` in `(AloemacsBuffer new* ...)` on line 8. Nothing
   happens, and hover there is empty too. `main.aloe` uses the injected
   `fs-host`, and the editor queries have no host injection, so the
   whole file fails checking. That is accepted (definition spec §9).

## Explicit non-goals

- A change to `editors/vscode/`, a second editor, a client-side parser,
  or a TypeScript or JavaScript copy of name resolution
- `LocationLink`, a list of locations, `typeDefinition`,
  `declaration`, `implementation`, references, rename, or diagnostics
- Jumps the query does not make: selectors, protocols, binding sites,
  aliases, instances
- A dirty overlay for a nested load, a workspace index, or incremental
  sync
- Host injection in the editor queries
- A change to hover, completion, the position converter, or how
  editor-lsp 010 counts positions
- A change to `aloe/definition-query.rkt` or the checker
