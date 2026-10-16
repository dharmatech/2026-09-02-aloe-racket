# Charter — Host-configured editor queries

**Status.** Handoff from the editor discussion into a **design
conversation**. Not Aloe law. Not a checkpoint. Not an implementer
assignment. The specification will live beside this file as
[`spec.md`](spec.md). Parent map: [`docs/editor/README.md`](../README.md),
project 9. Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`.

**Your job.** Turn this charter into a specification for
**host-configured editor queries**. A manifest beside a program names the
host bindings its runner injects. The language server reads that
manifest and binds each host's **type**, taken from the real interface
value, on the query's base. Hover, completion, and go-to-definition then
answer in `examples/aloemacs/main.aloe` and `gel/main.aloe`. The first
consumer is the Racket queries. The LSP server is the skin that finds
the manifest. Then **stop**. Do not write checkpoints. Do not implement.

If you have been told to read this file, this is the whole assignment.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority in §6.
2. Confirm the predecessors in §2 against the tree. If one is missing,
   **stop**.
3. Record the locked decisions in §4. Do not reopen them.
4. Resolve the choices §5 leaves to the spec, and record each one.
5. Write `spec.md` in this folder. A later checkpoint-manager
   conversation slices **editor-host-queries 000**, `001`, … under
   `docs/editor/host-queries/checkpoints/`. Not `docs/checkpoints/`.
   Not a rewrite of an earlier editor series.
6. Set this folder's README status to spec written, awaiting review.
   Set project 9's status cell on the parent map the same way.
7. Stop. The human reviews the spec. Do not write checkpoint files.

The checkpoint manager and implementers will not have this charter.
Put every rule they need in the specification.

Intended order. The spec may pack or split these layers to the
checkpoint size in [`docs/workflow.md`](../../workflow.md). It must not
reorder them. About two checkpoints are expected. There is no VS Code
checkpoint.

1. **The shared query path accepts host types.** The checker gains a
   narrow hook that binds a name to a host interface's type. The file
   module path binds the given hosts on the query's fresh base. The
   three public queries take an optional host argument. Consumer:
   Racket query tests that require `host/racket/fs` and
   `host/racket/term` themselves and pass the real interfaces.
2. **The language server finds the manifest and passes the hosts in.**
   This layer adds a manifest reader under `aloe/`. The reader enforces
   the module boundary, loads the module, and handles failures.
   `aloe/lsp.rkt` calls it. The layer checks in manifests for
   `examples/aloemacs/` and `gel/`, and the VS Code hand check follows
   it.

## 2. Predecessors, as found on 2026-10-16 at `6deecab`

| Predecessor | Ready when |
|---|---|
| [`../expression-query/`](../expression-query/) | `query-expression-at` takes a source path, a position, and `#:document-path`. `tests/editor/expression-query/003-public-query.rkt` pins a temp-file query of `term` as `typecheck: unbound symbol: term`. |
| [`../completion/`](../completion/) | `query-selector-completions` takes source text, a position, and `#:source-path`. It has a branch with no source path, which checks the buffer in a fresh environment and has no file. |
| [`../definition/`](../definition/) | editor-definition 000–003, closed at `6deecab`. `query-definition-at` takes the same arguments as `query-expression-at`. |
| [`../lsp/`](../lsp/) | editor-lsp 000–010. A dirty buffer is read from an `aloe-lsp-snapshot-…` sibling in the document's folder. The document path stays the identity. `run-lsp-server/with-queries` lets tests substitute fake queries. |
| Query base | `typecheck-file-module-buffer` in `(submod "aloe/main.rkt" query-base)` checks each queried file module on a fresh base from `make-type-environment`. Hover, completion, and definition all reach it. The checker's load cache belongs to its base. |
| Host boundary | `aloe/host.rkt`: `make-host-method` requires an implementation procedure. `make-host-interface` returns an opaque, nominal `host-interface`. `aloe/type.rkt`: `type-environment-inject-host!`, in the `driver-host-injection` submodule, takes a receiver and stores `(host-receiver-type (host-receiver-interface receiver))`. |
| Driver injection | `driver-inject-host!` in `aloe/driver.rkt` binds a host on the checker's and the runtime's **base**. Its comment reads "A host lives on the base, so every file loaded afterwards sees it". It refuses a name that is already bound. |
| Host modules | `host/racket/fs.rkt` exports `fs-interface` (`FsHost`). `host/racket/term.rkt` exports `term-interface` (`Term`). Both resolve as collection modules, `host/racket/fs` and `host/racket/term`. Every module in `host/racket/` has a definition-only top level. Effects live in `main` submodules. |
| Runners | `host/racket/aloemacs-run.rkt` injects `term` and `fs-host`, then loads `examples/aloemacs/main.aloe`. `host/racket/gel-run.rkt` injects `term`, then loads `gel/main.aloe`. |

The problem, as found. Every query on `examples/aloemacs/main.aloe` fails
with `typecheck: unbound symbol: fs-host`, from line 74,
`(fs (Fs new fs-host))`. Every query on `gel/main.aloe` fails on `term`,
first used in a `GelMain` method body. On the tree at `6deecab`, binding
only each host's type on a fresh query base makes both files check.
`main.aloe` then checks in about 40 ms, and hover on `fs-host` returns
`FsHost` with its rows. Nothing else in either file is unbound.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. `query-expression-at`, `query-definition-at`, and
   `query-selector-completions` each accept host bindings. A binding
   pairs a name with a real `host-interface` value. Called without host
   bindings, each function behaves exactly as today. The `term` case in
   `003-public-query.rkt` stays green with no edit.
2. With `fs-host` bound to `fs-interface`, a query of
   `examples/aloemacs/main.aloe` answers:
   - Hover on `fs-host` at line 74 shows `FsHost` and its rows in
     interface declaration order.
   - Hover on `AloemacsBuffer` in `(AloemacsBuffer new* ...)` at line 8
     shows the class.
   - Go to definition on that `AloemacsBuffer` lands on the class name
     in `examples/aloemacs/file.aloe`.
   - Completion after `(fs-host ` lists `FsHost`'s selectors.
3. With `term` bound to `term-interface`, the same mechanism makes
   `gel/main.aloe` answer.
4. Queries never evaluate. The query path constructs no host receiver,
   invokes no host implementation, makes no runtime environment, and
   never calls `driver-inject-host!`. The interface inside the bound
   type is `eq?` to the module's export.
5. On each query, the language server reads a manifest from the
   document's own folder. It matches the document path and passes that
   row's bindings to the query. A dirty buffer still answers, because
   the snapshot sibling is never used for matching.
6. A document with no row gets the same query call as today. The server
   passes no host argument.
7. A bad manifest, a bad row, or a failed module load is a miss, the
   same empty answer a type error gives today. The server keeps
   running. It publishes no diagnostic and writes nothing to stdout
   outside the LSP frames.
8. `aloe/` keeps no static `require` of anything under `host/racket/`.
   No host module loads until a manifest row names it.
9. `editors/vscode/` is unchanged and `npm test` there passes. `SPEC.md`,
   `aloe/driver.rkt`'s `driver-inject-host!`, and both runners are
   unchanged.

## 4. Locked decisions (record these; do not reopen them)

### 4.1 A host binding is a type from the real interface

- The checker needs only the host's type. The query binds the name to
  `(host-receiver-type interface)`, the same type
  `type-environment-inject-host!` stores today.
- The interface is the value the host module exports: `fs-interface`
  from `host/racket/fs`, `term-interface` from `host/racket/term`.
  Interface identity is nominal (signatures-of-type spec §4.6, and the
  `eq?` interface comparison in `aloe/type.rkt`). A copy is a different
  type. A handwritten copy of an interface, a signatures-only interface,
  and a new interface constructor are out. `make-host-method` keeps
  requiring an implementation.
- The query path constructs no host receiver. `make-host-receiver`
  accepts any state, so `(make-host-receiver interface #f)` would
  satisfy today's hook with no checker change. That is ruled out: a
  receiver with placeholder state is a value that looks runnable.
  Instead the checker gains a narrow hook that takes an interface. The
  hook lives in a submodule, as `driver-host-injection` does, not in
  the checker's public API. `type-environment-inject-host!` may
  delegate to it. Its contract does not change, and neither does the
  driver's behavior.
- The binding goes on the query's **base**, before the buffer is
  checked, exactly as `driver-inject-host!` does on the driver's base.
  A file the queried buffer loads sees the host, as it does in the
  runner. If the buffer also defines a host's name, the checker reports
  its existing name collision, as it would in the runner.
- Never call `driver-inject-host!`. Make no runtime environment.
- Each query has a fresh base, and the load cache belongs to that base.
  A host bound for one query is never visible to another.

### 4.2 The public queries

- Each of the three public functions gains one optional argument. Its
  default is no hosts. The argument carries pairs of a symbol and a
  value that satisfies `host-interface?`. The spec picks its name and
  shape.
- Hosts apply to the file-module branch, `typecheck-file-module-buffer`.
  A base-library buffer, one that `base-library-path` recognizes, is
  checked as today. The runners install the libraries before any host,
  and a library cannot name a host. The completion branch with no
  source path has no document and so no manifest, and the server never
  has hosts for it.
- The query never infers hosts from its path. Hosts come only from the
  explicit argument. The expression-query spec's sentence "the path
  argument does not imply ambient application capabilities" stays
  true.
- A host name that is already bound on the fresh base is refused.
  Examples are a library class such as `Option`, `List`, `String`, or
  `Int`, or any other name the base libraries define. A name given
  twice is refused. A value that is not a `host-interface` is refused.
- The queries never read a manifest, never load a module, and never
  `require` anything under `host/racket/`.

### 4.3 The manifest

- The manifest is a file in the document's own folder, read by the
  language server. It is not a VS Code setting. The VS Code spec keeps
  `aloe.racketPath` as the client's only setting. It is not a new Aloe
  declaration, and `SPEC.md` is not amended. It is not Aloemacs or Gel
  knowledge hard-coded in the server.
- The server looks only in the folder that contains the document. There
  is no parent-folder search, no workspace scan, and no glob row.
- A row's key is the document path, the identity, written as a bare
  file name in that folder. It is never the path the checker reads. A
  dirty buffer is read from an `aloe-lsp-snapshot-…` sibling, and that
  name never matches a row.
- Only the queried document's row applies. A loaded file's own row is
  not read for that query. Loaded files see the queried document's
  hosts through the base.
- The server reads the manifest from disk on each query. There is no
  cache and no file watching, so an edit takes effect on the next
  query.
- The manifest is read as data, with Racket `read` and with
  `read-accept-reader` and `read-accept-lang` off. A `#reader` or
  `#lang` line is not accepted, and nothing is evaluated. Reading a
  manifest cannot run code.
- Each host entry names three things: the Aloe binding name, the module
  path, and the name of the exported interface. A sketch, whose file
  name and syntax the spec picks:

  ```racket
  ;; examples/aloemacs/aloe-hosts.rktd
  ((file "main.aloe"
     (host fs-host host/racket/fs fs-interface)))
  ```

- Leave room for runners. A later project may let the runners read the
  same manifest. A runner would also need a way to build a receiver,
  such as a factory. The format must admit a later clause for that
  without changing what an existing row means. This project adds no
  factory column and changes no runner.
- This project checks in two manifests: one in `examples/aloemacs/`
  that gives `main.aloe` `fs-host`, and one in `gel/` that gives
  `main.aloe` `term`.

### 4.4 The module boundary is the `host/racket` collection

- **Locked:** a row may name any module in the `host/racket` collection
  whose named export satisfies `host-interface?`. There is no fixed
  capability table in the server, and `aloe/` never names a host module.
  Adding a host means adding a module under `host/racket/`, not
  editing the server.
- `dynamic-require` instantiates a module before its export can be
  checked. So the boundary is the module path, and the server checks it
  before anything loads. The path must be a symbol of the form
  `host/racket/<name>`, with exactly one segment after
  `host/racket/`. These are rejected before any load: a string, a
  `(file …)`, `(lib …)`, `(planet …)`, or `(submod …)` form, a relative
  path, `..`, and a deeper path.
- The export is fetched by its name. It must satisfy the server's own
  `host-interface?`. If the module loads but the export is missing or
  is not an interface, the row fails.
- The module's `main` submodule never runs.
- **The effects rule.** Every module in `host/racket/` has a
  definition-only top level. Effects, such as opening a TTY, touching
  the filesystem, printing, or starting a loop, live in `main`
  submodules or in procedures that a caller invokes. Every file in
  `host/racket/` follows this today: `aloemacs-run.rkt`, `fs-repl.rkt`,
  `fs.rkt`, `gel-run.rkt`, `read-key-spike.rkt`, `term.rkt`, and
  `term-run.rkt`. The rule must be written in the tree, where an author
  of a new host module will see it, not only in the spec. The spec
  picks the place. The reason is concrete: the server's stdout is the
  LSP frame stream, and a host module that prints when it loads would
  corrupt it.
- Trust. A manifest is a file in a folder the user opened. Under the
  collection rule, a manifest can make the server load only a module
  already installed in this package's `host/racket` collection. It can
  never load a file from the workspace. Collection resolution does not
  depend on the server's current directory.

### 4.5 Where the server loads the interface

- One new module under `aloe/`, the manifest reader, reads the manifest
  for a document path and returns that document's host bindings. It is
  the only place in `aloe/` that loads a host module. It calls
  `dynamic-require` on the module path the manifest supplied, after
  §4.4's check. `aloe/` keeps no static `require` of `host/racket/`.
  `raco make aloe/lsp.rkt` compiles no host module.
- A module outside `aloe/` is not an option. The VS Code client
  launches `racket -l aloe/lsp` and does not change, so reaching an
  outside module would need a dynamic require anyway.
- `aloe/lsp.rkt` calls the reader and passes its result to the query.
  The LSP spec's thin dependency boundary (§2) holds. The adapter
  imports no parser, no checker internal, and no host module.
- The module loads into the server's own namespace and module registry,
  not a fresh namespace. Otherwise `host-interface?` and nominal
  identity would not hold.
- Output ports are captured while the module loads, so nothing reaches
  the frame stream even if a host module breaks the effects rule.
- A host module loads once per server process, through Racket's module
  registry. Manifest edits apply on the next query. An edit to a host
  module's Racket source needs a server restart, such as Reload Window.
  This is accepted.
- The reader's first consumer is its own unit tests over fixture
  folders, not LSP.

### 4.6 Unconfigured files and failure

- A document with no manifest, or a manifest with no row for it, gets
  the same query call as today: the server passes no host argument.
  Existing LSP tests whose fake queries take today's arguments need no
  edit. A temp file that uses `term` stays unbound.
- A configured document's row can fail in these ways:
  - The boundary rejects a module path.
  - A module fails to load, for example because the optional `tui-term`
    package is missing.
  - An export is missing or is not an interface.
  - A binding name is duplicated.
  - A binding name is already bound on the base.

  Any of these is a miss for that document. A row is all or nothing.
  The server never checks a document with only some of its row's hosts.
- Every miss is the same empty answer the three features already give
  for a type error: a null hover, a null definition, or an empty
  completion list. There is no crash and no diagnostic; this project
  publishes none. Nothing goes to stdout outside the LSP frames. The
  server answers the next request.

### 4.7 Hosts in hover, completion, and definition

- Hover on a host name shows the interface name and its rows in
  interface declaration order (signatures-of-type spec §4.6), in the
  format hover already uses for a host receiver type. This project adds
  no hover format.
- Completion after `(fs-host ` lists `FsHost`'s selectors through the
  existing catalog.
- Go to definition on a host name returns no location. A host is not a
  class and has no span, and there is no jump into Racket source.
  Go to definition on `Fs` in `(Fs new fs-host)` still lands in
  `lib/fs.aloe`, by the existing class-name rule.
- Host interface names stay unavailable in Aloe annotations
  (signatures-of-type spec §4.6).

### 4.8 Gel is in scope

- `gel/main.aloe` with `term` bound to `term-interface` is the second
  case. The mechanism is the same. It needs a second manifest and a
  second hand check.
- `host/racket/term.rkt` statically requires `tui/term`. That comes from
  the optional `tui-term` package (`raco pkg install tui-term`), which
  is not among `info.rkt`'s deps. The package is installed on the
  development machine, and several suite tests already require
  `host/racket/term`. Without the package the row fails to load, and
  `gel/main.aloe` stays a miss. This is accepted. Do not add `tui-term`
  to the deps.

### 4.9 Tests and the hand check

Automated proof is `TMPDIR=/tmp raco test -j 4 -y` on the new tests under
`tests/editor/host-queries/` and on the suites the spec names. Include
`-j 4` and `-y`.

The coverage must include:

- **Query layer.** The tests require `host/racket/fs` and
  `host/racket/term` themselves. Tests are not under `aloe/`. Cases:
  - the §3 cursors in `examples/aloemacs/main.aloe` and in
    `gel/main.aloe`
  - the same queries without hosts, which still fail as unbound
  - a query whose source path is a sibling copy and whose document path
    is the real file
  - a host bound for one query that the next query does not see
  - each refused host argument from §4.2
  - a base-library buffer and the completion branch with no source
    path, both unaffected
- **Manifest layer.** Cases over fixture folders:
  - a row matched on the document path
  - a snapshot sibling's name that never matches
  - a document with no row, whose fake query receives no host argument
  - each failure kind in §4.6, which is a miss
  - a rejected module path, which never loads
  - a host module's load-time output, which never reaches the frames
  - the static-require rule in §3 bar 8

  The spec picks how to prove "never loads" and the static-require
  rule.
- **LSP.** Hover, definition, and completion through the server on a
  fixture folder with a manifest. Initialize's capabilities are
  unchanged.

The human check comes after the LSP layer, in VS Code:

1. Open `examples/aloemacs/main.aloe`.
2. Hover `fs-host` and see `FsHost`'s rows.
3. Hover `AloemacsBuffer` on line 8, then go to definition on it, and
   land on the class name in `file.aloe`. This is the check
   editor-definition moved to `file.aloe` (definition spec §8, §9).
4. Type `(fs-host ` and see its selectors offered.
5. Edit the file without saving, and hover again.
6. Open `gel/main.aloe` and hover `term`.
7. Confirm that `examples/aloemacs/file.aloe` behaves as before.

On the LSP layer, `npm test` in `editors/vscode/` passes, and `git diff`
shows no change under `editors/vscode/`.

## 5. Choices left to the spec (resolve and record each)

- The manifest's file name and row syntax, within §4.3. The sketch name
  `aloe-hosts.rktd` is acceptable.
- The host argument's name and shape on the three queries. Whether
  hosts handed to a base-library buffer or to the completion branch
  with no source path are ignored or refused.
- How a query refuses a bad host argument: an exception or the miss
  result. Through the server, either one becomes a miss.
- What a manifest that cannot be read, or does not parse as a manifest,
  does. It is either a miss for every document in its folder, or it
  counts as absent. Test the choice.
- Whether the Aloemacs row also lists `term`, to mirror
  `aloemacs-run.rkt`. That runner injects both hosts, but `main.aloe`
  and its loads use only `fs-host`.
- Where the effects rule (§4.4) is written in `host/racket/`.
- The manifest reader's module name and API under `aloe/`.
- How the tests prove that a rejected path never loads, that output is
  captured, and that `aloe/` has no static `require` of `host/racket/`.
- The checkpoint split, inside §1's order.

## 6. Authority

- `SPEC.md`: language law. This project does not amend it.
- [`../expression-query/spec.md`](../expression-query/spec.md) §4: "The
  query has no host-injection parameter", and "Adding a host-configured
  query is a separate design". This is that design. It amends §4 for
  host-interface bindings only. No query infers hosts from its path.
- [`../completion/spec.md`](../completion/spec.md) §4: "There is no host
  injection parameter." Amended the same way.
- [`../definition/spec.md`](../definition/spec.md) §9 and §10. That
  series stays as written. Its "`main.aloe` is a whole-file miss"
  consequence still holds for an unconfigured `main.aloe`. Its non-goal
  "Host injection in the editor queries" belongs to that series and is
  not rewritten. This project restores the `main.aloe` hand check.
- [`../lsp/spec.md`](../lsp/spec.md) §2 says the adapter "never invokes
  a host capability". That stays true, because loading an interface
  runs no implementation. §8's "There is no configuration file, … or
  workspace scan" is about launching the server. The manifest is
  per-folder query data, not launch configuration. This charter amends
  that sentence for the manifest only. There is still no workspace
  scan.
- [`../signatures-of-type/spec.md`](../signatures-of-type/spec.md) §4.6:
  host rows, nominal interface identity, and host names unavailable in
  annotations. Not reopened.
- [`../vscode/spec.md`](../vscode/spec.md): `aloe.racketPath` stays the
  client's only setting.
- `aloe/host.rkt`, `aloe/type.rkt`, and `aloe/driver.rkt`: the host
  boundary as found in §2. `driver-inject-host!` does not change.
- [`../README.md`](../README.md): project 9.
- [`../../workflow.md`](../../workflow.md): checkpoint size and the test
  command.

When a locked decision here and an older editor non-goal disagree, this
charter wins for host-configured queries and nowhere else.

## 7. Non-goals

- Partial checking that answers for the forms before the first error.
  `main.aloe` line 8 and line 74 are in the same top-level `define`, so
  it would recover nothing.
- Runners reading the manifest, a factory column, or any change to
  `aloemacs-run.rkt`, `gel-run.rkt`, or `driver-inject-host!`
- Evaluation, constructing a receiver (including a placeholder one), or
  calling a host implementation
- A signatures-only interface, a handwritten copy of an interface, a new
  interface constructor, or relaxing `make-host-method`
- A VS Code setting, any change under `editors/vscode/`, or a second
  editor
- An Aloe declaration for hosts, a `SPEC.md` amendment, or host names in
  annotations
- A capability table, or Aloemacs or Gel names, in `aloe/`
- A module outside the `host/racket` collection, a module from the
  workspace, or a submodule
- A parent-folder search, a workspace scan, several manifests in one
  folder, glob rows, or rows applied to loaded files
- Caching the manifest, watching files, or reloading a host module
  without a restart
- Diagnostics, for manifests or anything else
- Go to definition on a host name, or into Racket source
- Adding `tui-term` to `info.rkt`'s deps
- The `tests/aloemacs/window-pictures.rkt` timing bar. It is next on the
  list, as a separate project.
- `CHECKPOINTS.md` and `docs/checkpoints/`

## 8. Handoff

- Series identity: `host-queries`. Spoken name: **editor-host-queries
  000**.
- Folder: `docs/editor/host-queries/`. Spec: `spec.md` beside this file.
  Checkpoints: `checkpoints/000-slug.md` and upward, three digits, never
  renumbered.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`. Code
  and tests go there. Tests go under `tests/editor/host-queries/`.
- Branch: `experiment/2026-10-16-host-queries`, on top of
  `experiment/2026-10-14-definition`.
- The checkpoint manager writes one checkpoint, then stops. The
  implementer receives that checkpoint and the accepted spec.
- Layer order is §1. The manager may split a layer that does not fit one
  conversation. The manager may not add a feature or put the server
  ahead of the query path.
- After the human accepts `spec.md`, it is the design authority. This
  charter is only the spec writer's assignment.
