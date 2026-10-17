# Editor host-queries 002 — The language server passes the hosts

**Status.** Written 2026-10-17 by the checkpoint manager from
[`../spec.md`](../spec.md) (reviewed, `80b46fd`). Implemented
2026-10-17. Manager-reviewed 2026-10-17 against this document:
conforming. The human's VS Code hand check passed, all seven steps, and
the human accepted it 2026-10-17. If
you have been told to read this file, it is the whole assignment.

## Goal

Layer 2 of the spec, second part, and the last checkpoint of the series.
The language server, `aloe/lsp.rkt`, calls the manifest reader that
editor-host-queries 001 added. When a document's folder has an
`aloe-hosts.rktd` row for that document, the server passes the row's
hosts to hover, go-to-definition, and completion. A document with no
row gets exactly today's call. A row that fails is a miss.

This checkpoint also checks in the two product manifests, beside
`examples/aloemacs/main.aloe` and `gel/main.aloe`. After it, hover,
completion, and definition answer in those two files in VS Code. Today
every hover and definition there misses. The human's VS Code hand check
closes the series.

The implementer receives only this document. Every rule for this slice
is below.

## Depends on, identity

Identity is `(editor-host-queries, 002)`, spoken **editor-host-queries
002**. It is a local editor checkpoint. Do not edit `CHECKPOINTS.md` or
add a file under `docs/checkpoints/`. Branch:
`experiment/2026-10-16-host-queries`.

The tree at `042e451` has every predecessor. As found:

- **Editor-host-queries 000** (`7a93158`). `query-expression-at` and
  `query-definition-at` take `#:hosts` beside `#:document-path`.
  `query-selector-completions` takes `#:hosts` beside `#:source-path`.
  `#:hosts` is a list of `(cons symbol host-interface)`. `'()` is the
  same as no argument. A name the query base already binds, such as
  `Option`, raises `exn:fail:contract` in hover and definition and gives
  `'()` in completion.
- **Editor-host-queries 001** (`042e451`). `aloe/host-manifest.rkt`
  provides `host-manifest-name`, the structs `document-hosts`
  (`bindings`) and `document-hosts-failure` (`reason`), and
  `(read-document-hosts document-path)`. It returns `#f` when the
  document's folder has no manifest, a broken one, or no row for the
  document. Otherwise it returns `(document-hosts bindings)` or
  `(document-hosts-failure reason)`. It never raises for a manifest or a
  module, it captures a host module's output while loading it, and it
  reads the manifest on every call. Its fixtures
  `tests/editor/host-queries/fixtures/configured/aloe-hosts.rktd` and
  `failing.aloe` exist. The manifest has a row for `uses-fs.aloe`
  (`fs-host`) and one for `failing.aloe` (`no-such-interface`, so
  `'export`).
- **The server.** In `aloe/lsp.rkt`, `query-hover` and
  `query-definition` convert the LSP position, then call
  `(query-synchronized-document query path text query-position)`. That
  procedure compares the synchronized text with the file on disk. When
  they match it calls `(invoke-query query path query-position)`.
  Otherwise `query-through-snapshot` writes an `aloe-lsp-snapshot-…`
  sibling beside the document, calls
  `(invoke-query query snapshot-path query-position #:document-path path)`,
  and removes the sibling. `invoke-query` turns any `exn:fail` from the
  query into `#f`, which the callers answer as JSON `null`.
  `query-completion` converts the position, then calls
  `(query text query-position #:source-path path)` directly, with no
  sibling. `run-lsp-server/with-queries` in the `test-support`
  submodule takes hover and completion queries and an optional
  `#:definition-query`.
- **No product manifest exists.** `examples/aloemacs/` holds
  `editor.aloe`, `file.aloe`, and `main.aloe`. `gel/` holds `loop.aloe`,
  `main.aloe`, `menu.aloe`, and `stack.aloe`. In each folder only
  `main.aloe` uses a host: `fs-host` in Aloemacs, `term` in Gel.

## Authority

- `SPEC.md` is law and is not amended.
- [`docs/editor/host-queries/spec.md`](../spec.md) §7 (the server),
  §8.1 (the product manifests), §9.2 and §9.4 (fixtures and answers),
  §10.2's product-manifest item, §10.3, §10.4's layer-2 row, and §11
  (the hand check) are the design of this checkpoint. Every rule you
  need is restated below.
- The spec lifts, for host-interface bindings only, LSP spec §2's "the
  adapter never evaluates Aloe code and never invokes a host
  capability". That stays true: loading an interface runs no
  implementation, and the adapter imports no host module. LSP spec §8's
  "no configuration file" is about launching the server. The manifest is
  query data in a folder, not launch configuration. The closed LSP,
  definition, completion, and VS Code specs are not edited.

## Required behavior

### 1. The require

`aloe/lsp.rkt` adds one require, placed after the definition query's:

```racket
(only-in "host-manifest.rkt"
         read-document-hosts
         document-hosts?
         document-hosts-bindings
         document-hosts-failure?)
```

The adapter still imports no parser, no checker, no `aloe/main.rkt`,
and no host module. It treats the bindings as opaque and passes them
through.

### 2. Each query request

For hover, definition, and completion, the adapter reaches the point
where it calls the query today: the document is open, its URI is a
supported local file, and the position converts. At that point it calls
`(read-document-hosts path)` exactly once, with the document's local
path from the URI. For hover and definition this happens before the
clean-or-sibling choice, so a failing row creates no sibling. Then:

| Reader result | Hover and definition | Completion |
|---|---|---|
| `#f` | today's call, unchanged | today's call, unchanged |
| `document-hosts` | today's call plus `#:hosts bindings`, on the clean path or through the sibling. The sibling call passes both `#:document-path` and `#:hosts` | today's call plus `#:hosts bindings` |
| `document-hosts-failure` | no query call. The result is JSON `null` | no query call. The result is the empty array |

So a document with no row gets exactly today's call, with no `#:hosts`
argument at all. Fake queries in the existing tests, which do not
accept `#:hosts`, need no edit. A dirty buffer still answers with its
hosts, because the reader is given the document path, never the
sibling. The adapter reads no manifest for an unopened document, an
unsupported URI, or a position that does not convert.

`invoke-query` still turns any `exn:fail` from hover's or definition's
query into no answer. That includes the query's own refusal of a host
name already bound on its base.

A suggested shape, which the scratch run below used:

- `invoke-query` gains `#:hosts [hosts #f]` and chooses among four call
  forms: with both `#:document-path` and `#:hosts`, with
  `#:document-path` only, with `#:hosts` only, and today's
  `(query path query-position)`.
- `query-synchronized-document` calls the reader first. On a failure it
  returns `#f`. Otherwise it passes the bindings, or `#f` when there is
  no row, to `invoke-query` on the clean path and to
  `query-through-snapshot`, which passes them on beside
  `#:document-path`.
- `query-completion`, after the position converts, calls the reader once
  and chooses among `'()`, the call with `#:hosts`, and today's call.

### 3. What stays the same

- The initialize result, the methods, error codes, and messages. Snapshot
  creation and removal.
- The adapter publishes no diagnostic. It writes nothing to stdout
  outside the LSP frames. The reader's capture covers loading. The
  `error-output` port stays unused.
- The server keeps running after a broken manifest or a failing row,
  and answers the next request.
- `run-lsp-server/with-queries` and `run-lsp-server/with-query` keep
  their arguments. No new test hook is added. The tests use real
  fixture folders.
- `editors/vscode/` does not change.

### 4. Source pins on `aloe/lsp.rkt`

Existing tests read `aloe/lsp.rkt` as text. Keep every one green. They
apply to comments too.

- **`load` is forbidden anywhere.** `tests/editor/lsp/003-buffer-snapshots.rkt`
  fails if the file contains the substring `load`. That rules out words
  such as `loaded`, `loader`, `reload`, and `download`, in code and in
  comments. The scratch run hit this with a comment. The same test
  forbids `find-system-path`, `current-temporary-directory`,
  `read-program`, `type-signature-specs`, `catalog`,
  `signature-catalog.rkt`, and `copy-file`, and requires
  `make-temporary-file`, `path-only path`, and
  `(call-with-output-file` followed by a newline and five spaces and
  `snapshot-path`.
- **Module names.** `tests/editor/lsp/000-hover.rkt` forbids the
  substrings `main.rkt`, `parse.rkt`, `eval.rkt`, `type.rkt`,
  `driver.rkt`, `host.rkt`, `signature-catalog.rkt`,
  `private/expression-selection.rkt`, `private/expression-observation.rkt`,
  `type-signature-specs`, `Point`, `dist2`, `starts-with?`, and
  `empty?`. `"host-manifest.rkt"` contains neither `host.rkt` nor
  `main.rkt`.
- **The quoted `.rkt` list.** Three tests require the list of quoted
  `.rkt` names in the file to be exact (§5 below edits them).
- **Call forms.** `tests/editor/lsp/004-hover-results.rkt` and
  `tests/editor/lsp/008-adapter-failures.rkt` require exactly one match
  of `\(query\s+path\s+query-position\)` in the file.
  `tests/editor/completion/003-lsp-completion.rkt` requires exactly one
  match of `\(query\s+text\s+query-position\s+#:source-path\s+path\)`
  in the completion section, which runs from `(define (query-completion`
  to `(define (completion-outcome`. Keep today's two call forms
  literally, once each, and add the host forms beside them. Both
  patterns end in a closing parenthesis right after `query-position` or
  `path`, so a form that continues with `#:hosts` (or `#:document-path`)
  does not match.
- **The completion section** must not contain `query-expression-at`,
  `query-synchronized-document`, `query-through-snapshot`,
  `make-temporary-file`, `sort`, or `remove-duplicates`.
- **Elsewhere in the file:** `tests/editor/lsp/006-json-rpc.rkt` forbids
  `(eval `, `dynamic-require`, `exn-message`, `batch`, `checker.rkt`;
  `tests/editor/lsp/007-lifecycle.rkt` forbids `racket/thread`,
  `async-channel`, `worker`, and `queue`;
  `tests/editor/lsp/008-adapter-failures.rkt` forbids `signature-spec?`,
  `continuation-mark-set->context`, and `[exn?`;
  `tests/editor/lsp/004-hover-results.rkt` forbids `exn:fail:aloe-type?`,
  `method-catalog`, and `exn?`;
  `tests/editor/completion/003-lsp-completion.rkt` forbids `Boids`,
  `List selectors`, `String selectors`, `CompletionList`, `snippet`, and
  `diagnosticProvider`; `tests/editor/lsp/005-framing.rkt` forbids
  `read-line`, `read-bytes-line`, `port->bytes`, and `port->string`;
  `tests/editor/lsp/009-launch.rkt` forbids `racket/cmdline`,
  `(command-line`, `tcp-listen`, `subprocess`, and `system*`, and counts
  one `(module+ main`, one `(current-command-line-arguments)`, one
  `(exit `, and one definition each of `run-lsp-server` and
  `run-lsp-server/with-query`.

### 5. Existing tests this checkpoint edits

Each edit is the smallest one that keeps the test's intent:

| Test | Edit |
|---|---|
| `tests/editor/lsp/004-hover-results.rkt`, "source keeps one public query dependency and a narrow failure boundary" | the list of quoted `.rkt` names gains `"\"host-manifest.rkt\""` after `"\"definition-query.rkt\""` |
| `tests/editor/lsp/008-adapter-failures.rkt`, "source keeps the adapter boundary narrow" | the same |
| `tests/editor/completion/003-lsp-completion.rkt`, "production composition remains narrow and completion-specific" | the same |

The scratch run below applied the product edit and ran the suite. These
three were the only failing locations, apart from the scratch-only
`009-launch` artifact it describes. No other existing test changes.

### 6. The product manifests

`examples/aloemacs/aloe-hosts.rktd` (190 bytes):

```racket
;; Hosts the Aloe language server binds when it checks a document in this
;; folder. See docs/editor/host-queries/spec.md.
((file "main.aloe"
   (host fs-host host/racket/fs fs-interface)))
```

`gel/aloe-hosts.rktd` (191 bytes):

```racket
;; Hosts the Aloe language server binds when it checks a document in this
;; folder. See docs/editor/host-queries/spec.md.
((file "main.aloe"
   (host term host/racket/term term-interface)))
```

Each is ASCII with one LF after every line. The Aloemacs row lists only
`fs-host`. `main.aloe` and the files it loads use only `fs-host`.
Listing `term` would make Aloemacs depend on the optional `tui-term`
package: without it the row would fail, and `main.aloe` would go dark
for a host it never uses. No other document in either folder gets a
row.

`tests/checkpoint-114.rkt` scans every file under `gel/` for the text
`define-methods String`. The Gel manifest does not contain it.

## Exact file scope

May edit:

- `aloe/lsp.rkt`: the require, `invoke-query`,
  `query-through-snapshot`, `query-synchronized-document`, and
  `query-completion`. Nothing else.
- `examples/aloemacs/aloe-hosts.rktd` and `gel/aloe-hosts.rktd` (new)
- `tests/editor/host-queries/fixtures/broken/neighbor.aloe` and
  `tests/editor/host-queries/fixtures/broken/aloe-hosts.rktd` (new)
- `tests/editor/host-queries/002-lsp-hosts.rkt` (new)
- the three lines in §5
- `docs/editor/host-queries/README.md` and `docs/editor/README.md`, for
  the status lines under Acceptance

Do not edit:

- any other module under `aloe/`, including `aloe/host-manifest.rkt`
  and the three query modules
- `host/racket/`, `lib/`, any `.aloe` file in `examples/` or `gel/`, or
  `editors/vscode/`
- any other existing test or fixture
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or any spec,
  charter, or checkpoint document, this one included

If an existing test fails, or the slice seems to need a file outside
this list, stop and report it.

## Fixtures

Add `tests/editor/host-queries/fixtures/broken/`. Each file is ASCII
with one LF after every line.

`neighbor.aloe` (89 bytes):

```aloe
(define-class Mark
  (fields
    (n Int))
  (methods))

(define first-mark (Mark new 1))
```

`aloe-hosts.rktd` (58 bytes), broken because its entry has three
elements:

```racket
((file "neighbor.aloe"
   (host fs-host host/racket/fs)))
```

`neighbor.aloe` adds one modules-census case to the whole suite.

The `configured` folder is unchanged from 001: `spot.aloe`,
`reads-fs.aloe`, `uses-fs.aloe`, `defines-fs-host.aloe`, `failing.aloe`,
and `aloe-hosts.rktd`. For reference, `uses-fs.aloe` is:

```aloe
(load "spot.aloe")
(load "reads-fs.aloe")

(define here (fs-host current))
(define corner (Spot new 1 2))
(define listing (fs-host names start))
```

## Required tests

Add `tests/editor/host-queries/002-lsp-hosts.rkt`. It is three
directories below the repository root. Require `json`, `net/url`, the
Racket libraries you need, `rackunit`,
`(prefix-in lsp: "../../../aloe/lsp.rkt")`,
`(prefix-in support: (submod "../../../aloe/lsp.rkt" test-support))`,
`"../../../aloe/host-manifest.rkt"`, the accessors you need from
`"../../../aloe/host.rkt"` (`host-interface-methods`,
`host-method-selector`, `host-method-parameter-types`,
`host-method-return-type`), and `"../../../host/racket/fs.rkt"` and
`"../../../host/racket/term.rkt"` by relative path. Use
`define-runtime-path` for the two fixture folders and for
`examples/aloemacs/main.aloe`, `examples/aloemacs/file.aloe`, and
`gel/main.aloe`.

Follow `tests/editor/definition/003-lsp-definition.rkt` for the
harness: `frame`, `decode-frames` (which checks each canonical
`Content-Length` header, the blank line, and the body length), a
`session` of initialize, `initialized`, the messages, `shutdown`, and
`exit`, and `run-exchange` through `lsp:run-lsp-server` or through
`support:run-lsp-server/with-queries` with stubs. A URI is
`(url->string (path->url p))` of the complete, simplified path.

**Every exchange is clean.** For each run: the status is 0; the
responses, decoded, are exactly the expected list, starting with the
unchanged initialize response and ending with the shutdown response;
the error-output port is empty; the input port is at `eof`; and the
output holds nothing but frames. The initialize result is the one in
`tests/editor/definition/003-lsp-definition.rkt`.

**Expected hover text and items come from the interface.** Never copy
the rows.

- A host's hover text is `"type: "`, the interface name, `"\nmessages:"`,
  and then, for each method in `host-interface-methods` order,
  `(format "\n  ~s : ~s -> ~s" selector parameter-types return-type)`.
  There is no `from:` line: the type and the pathed type are the same.
- An `FsHost` completion item at line `l`, character `c` is the hash
  with `label` and `insertText` the selector written with `~s`,
  `detail` `(format "~s -> ~s" parameter-types return-type)`, and
  `textEdit` with range `l:c–l:c` and `newText` the label. Items come in
  declaration order.

LSP lines and characters are zero-based. Write one `test-case` per
numbered item below, six in all. The names are yours.

### 1. The product manifests

`read-document-hosts` with the default loader:

- `examples/aloemacs/main.aloe` gives
  `(document-hosts (list (cons 'fs-host fs-interface)))`;
- `gel/main.aloe` gives
  `(document-hosts (list (cons 'term term-interface)))`;
- `examples/aloemacs/file.aloe` gives `#f`.

### 2. Real queries answer with the folder's hosts

Through `lsp:run-lsp-server`, one session on `uses-fs.aloe`:

| Message | Response |
|---|---|
| `didOpen` with the file's text | — |
| hover at 3:14 (`fs-host` in `(define here (fs-host current))`) | contents `kind` `"plaintext"` with `FsHost`'s hover text, range 3:14–3:21 |
| definition at 4:16 (`Spot` in `(Spot new 1 2)`) | the URI of `configured/spot.aloe`, range 0:14–0:18 |
| `didChange` (version 2) to the text with `(define here (fs-host current))` replaced by `(define here (fs-host ))` | — |
| completion at 3:22 | ten items in `FsHost` order, each `textEdit` range 3:22–3:22 |
| `didChange` (version 3) to the original text with one LF prepended | — |
| hover at 4:14 | `FsHost`'s hover text, range 4:14–4:21 |

The ten completion details are, in order: `"() -> String"`,
`"(String) -> String"`, `"(String String) -> String"`,
`"(String) -> Bool"`, `"(String) -> String"`, `"(String) -> String"`,
`"(String) -> String"`, `"(String) -> (List String)"`,
`"(String) -> String"`, `"(String String) -> String"`. Check that list
literally as well, against the response.

The last hover goes through a sibling, because the buffer differs from
the disk. Afterwards the `configured` folder holds no entry whose name
starts with `aloe-lsp-snapshot-`, and `uses-fs.aloe` on disk is
unchanged. Do not compare the folder's whole listing: the 000 test
writes a temporary `host-queries-copy-…` file into the same folder and
may run at the same time under `-j 4`.

### 3. A failing row is a miss, and the server keeps answering

Through `lsp:run-lsp-server`, one session: open `failing.aloe`; hover,
definition, and completion at 0:14. The responses are `null`, `null`,
and `[]`. Then open `uses-fs.aloe` and hover at 3:14. It answers with
`FsHost`'s hover text, range 3:14–3:21.

Then the same three requests on `failing.aloe` through
`support:run-lsp-server/with-queries`, with stubs that accept
`#:hosts` (and `#:document-path` or `#:source-path`) and count their
calls. The responses are `null`, `null`, and `[]`, and the count is 0.

### 4. A broken manifest leaves its folder unconfigured

Through `lsp:run-lsp-server`: open `broken/neighbor.aloe`; hover and
definition at 5:20 (`Mark` in `(define first-mark (Mark new 1))`).

- Hover: contents `"type: (Class Mark)\nfrom: (Class Mark@tests/editor/host-queries/fixtures/broken/neighbor.aloe)\nmessages:\n  new : (Int) -> Mark"`,
  range 5:20–5:24.
- Definition: the document's URI exactly as sent, range 0:14–0:18.

### 5. The row's hosts reach each query

Through `support:run-lsp-server/with-queries`, with recording stubs:
hover and definition stubs of the form
`(lambda (path position #:document-path [document path] #:hosts [hosts 'none]) …)`
and a completion stub of the form
`(lambda (text position #:source-path source #:hosts [hosts 'none]) …)`.
Each records its kind and `hosts` and returns `#f` (completion `'()`).
One session on `uses-fs.aloe`: open; hover at 3:14; definition at
4:16; completion at 3:22; a `didChange` that prepends one LF; hover at
4:14. The recorded kinds are hover, definition, completion, hover, in
that order. Every recorded `hosts` is `equal?` to
`(list (cons 'fs-host fs-interface))`, and its interface is `eq?` to
`fs-interface`. The last hover went through the sibling.

### 6. Documents without a row get today's call

Through `support:run-lsp-server/with-queries`, with stubs that do
**not** accept `#:hosts`: hover and definition stubs
`(lambda (path position #:document-path [document path]) …)` and a
completion stub `(lambda (text position #:source-path source) …)`.
Each counts its calls and returns `#f` (completion `'()`). For
`configured/spot.aloe` (no row) and for `broken/neighbor.aloe` (a
broken manifest), each in its own session: open it, then hover,
definition, and completion at 0:1. The responses are `null`, `null`,
and `[]`, and the count is 3. Had the server passed `#:hosts`, the
stubs would have raised and counted nothing.

### The VS Code client

From `editors/vscode/`, `npm test` passes, and `git diff --stat --
editors/vscode` is empty. The client does not change.

## Scratch run

On 2026-10-17 a prototype of this checkpoint was applied to a copy of
the tree at `042e451`, with every `compiled/` folder removed first and
`PLTCOLLECTS` pointed at the copy so that `host/racket/fs` resolved
there. The prototype changed about 50 lines of `aloe/lsp.rkt`. Then:

- Before the three edits in §5, the editor suite failed exactly those
  three locations, plus `tests/editor/lsp/003-buffer-snapshots.rkt`,
  because a prototype comment contained the word "loaded" (§4). With the
  comment reworded, only the three remained.
- A prototype test file with these six test cases passed. Each of these
  mutations failed at least one of them: passing no hosts through the
  sibling; querying despite a failing row; passing `#:hosts` even when
  there is no row; and passing `'()` instead of the bindings to
  completion.
- With the three edits, the four new files, and the prototype test, the
  whole suite ran 3092 tests under `-j 4`: the 3085 of `042e451`, the
  six new test cases, and one census case for `broken/neighbor.aloe`.
  Two failed, and neither was the prototype's.
  `tests/aloemacs/window-pictures.rkt`'s timing bar read 30.08 ms against
  30 ms, and the file passed alone. `tests/editor/lsp/009-launch.rkt`'s
  package-link case failed only because of the scratch run's
  `PLTCOLLECTS` override: `raco pkg install` refuses to link a folder
  that is also a collection path. That file passed 6 of 6 alone without
  the override, and in the real repository no override applies.
- `npm test` in the copy's `editors/vscode/` passed 14 of 14.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/host-queries/002-lsp-hosts.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

and, from `editors/vscode/`:

```sh
npm test
```

All green. The whole suite is 3092 tests: 3085, the 6 new test
cases, and 1 modules-census case for `broken/neighbor.aloe`. `npm test`
passes 14 of 14. If only `tests/aloemacs/window-pictures.rkt`'s 30 ms
timing bar fails under `-j 4`, run that file alone, and it must pass
there.

Update the status lines:

- In `docs/editor/host-queries/README.md`, add a file-table row for
  `checkpoints/002-lsp-hosts.md`: "Implemented *date*, awaiting review",
  with the focused test count, the whole-suite count, the three edited
  tests, and `npm test`'s result. Set the status paragraph to say
  editor-host-queries 002 is implemented and awaits review and the hand
  check.
- In `docs/editor/README.md`, update project 9's cell and the project-9
  sentence below the table to say the same.

Stop for review without committing. There is no 003.

## Hand check (the human, during review)

This check is the human's, in VS Code. The implementer does not run it,
and does not claim it.

First run the test command above, or
`TMPDIR=/tmp raco make aloe/lsp.rkt host/racket/fs.rkt host/racket/term.rkt`,
so that the bytecode `racket -l aloe/lsp` loads, and the host modules it
loads by name, are current. A host module loads once per server
process, so then Reload Window. Find each place by its text. A caret
just after a name's last character addresses the next character, which
is a miss.

1. Open `examples/aloemacs/main.aloe`.
2. Hover `fs-host` in `(Fs new fs-host)` and see `type: FsHost` and
   `FsHost`'s ten rows, with no `from:` line.
3. Hover `AloemacsBuffer` in `(AloemacsBuffer new* ...)`, the
   `initial-buffer` binding, and see the class with its `from:` line.
   Go to definition on it. You land on the class name in
   `examples/aloemacs/file.aloe`.
4. Change `(Fs new fs-host)` to `(Fs new (fs-host ))`. Put the caret
   after `(fs-host ` and trigger completion. See `FsHost`'s selectors
   offered. Undo.
5. Edit the file somewhere harmless without saving, such as a blank
   line at the top. Hover `fs-host` in `(Fs new fs-host)` again, and see
   that it still shows `FsHost`'s rows. Undo.
6. Open `gel/main.aloe` and hover `term` in the first `(term write-line`.
   See `type: Term` and `Term`'s six rows.
7. Confirm that `examples/aloemacs/file.aloe` behaves as before: hover
   and go to definition on a class name there still answer.

## Explicit non-goals

- Any change to `aloe/host-manifest.rkt`, the queries, or the checker
- A VS Code setting, any change under `editors/vscode/`, or a second
  editor
- Diagnostics for a broken manifest or a failing row, or any message
  about either
- Runners reading the manifest, a factory element, or any change to
  `aloemacs-run.rkt`, `gel-run.rkt`, or `driver-inject-host!`
- A row for any document but the two `main.aloe` files, or `term` in
  the Aloemacs row
- Caching the reader's result, watching files, or reloading a host
  module without a restart
- A new test hook in `aloe/lsp.rkt`, or a change to
  `run-lsp-server/with-queries`'s arguments
- Go to definition on a host name, or into Racket source
- Adding `tui-term` to `info.rkt`'s deps
- The `tests/aloemacs/window-pictures.rkt` timing bar
