# Host-configured editor queries

**Status.** Design specification for the local `editor-host-queries`
project, written 2026-10-16 from [`charter.md`](charter.md). Not Aloe
language law, not an implementation checkpoint, and not a global
checkpoint. The human reviews this file before a later
checkpoint-manager conversation slices it under
`docs/editor/host-queries/checkpoints/`. If you have been told to read
this file, it is the whole assignment.

**Authority.** `SPEC.md` remains law and is not amended. The
[expression query](../expression-query/spec.md) owns expression
selection, `query-expression-at`, `#:document-path`, the base-library
rule, and hover's result. [Completion](../completion/spec.md) owns its
one recovery rule, its early exit, and its items. The
[definition spec](../definition/spec.md) owns name tokens and jumps.
The [LSP adapter](../lsp/spec.md) owns framing, lifecycle, document
sync, the temporary sibling, UTF-16 conversion, and failure responses.
[Signatures of a type](../signatures-of-type/spec.md) §4.6 owns host
rows, nominal interface identity, and host names being unavailable in
annotations. This project lifts the sentences in §3 for host-interface
bindings only and edits none of those files. `aloe/host.rkt`,
`driver-inject-host!` in `aloe/driver.rkt`, and the two runners are the
host boundary as found in §1, and they do not change.

The checkpoint manager will not have the charter. Every rule needed to
slice this work is in this file.

---

## 1. Predecessors, as found on 2026-10-16

Confirmed against the tree at `e641268` (product code as of `6deecab`).

| Predecessor | Found |
|---|---|
| Expression query | `aloe/expression-query.rkt` provides `(query-expression-at source-path position #:document-path [document-path source-path])`. `tests/editor/expression-query/003-public-query.rkt` pins a temp-file query of `term` as `typecheck: unbound symbol: term`. |
| Completion | `aloe/completion-query.rkt` provides `(query-selector-completions source position #:source-path [source-path #f])`. Its argument checks raise. Everything after them runs inside one `with-handlers` that returns `'()`. With no source path it checks the recovered buffer in `(make-type-environment)` and has no file. |
| Definition | `aloe/definition-query.rkt` provides `query-definition-at` with the arguments of `query-expression-at`. Editor-definition 000–003 closed at `6deecab`. |
| LSP | Editor-lsp 000–010. Hover and definition query the document path when its bytes match the disk, otherwise an `aloe-lsp-snapshot-…` sibling with `#:document-path` set to the document. `invoke-query` turns any `exn:fail` from those two queries into no answer. Completion passes the synchronized text with `#:source-path` set to the document, and has no sibling. `run-lsp-server/with-queries` in the `test-support` submodule takes fake queries. |
| Query base | `(submod "aloe/main.rkt" query-base)` exports `base-library-path`, `typecheck-base-library-buffer`, and `typecheck-file-module-buffer`. The last checks a buffer as a file module on the fresh base of `(make-type-environment)`. The checker's load cache belongs to that base. All three queries reach it. |
| Host boundary | `aloe/host.rkt`: `host-interface` is opaque and nominal. `make-host-method` requires an implementation procedure. `make-host-receiver` accepts any state. `aloe/type.rkt`: `(struct host-receiver-type (interface))` is not exported. `type-environment-inject-host!`, in submodule `driver-host-injection`, checks an environment, a symbol, and a receiver, then stores `(host-receiver-type (host-receiver-interface receiver))` with `type-environment-set!`. A binding stored on a base records the origin `base`. Two host types are equal only when their interfaces are `eq?`. |
| Driver | `driver-inject-host!` refuses a name already bound in the driver, then binds the type on the checker's base and the receiver on the runtime base. Its comment reads "A host lives on the base, so every file loaded afterwards sees it". |
| Host modules | `host/racket/fs.rkt` exports `fs-interface` (`FsHost`, ten methods). `host/racket/term.rkt` exports `term-interface` (`Term`, six methods) and statically requires `tui/term`, from the optional `tui-term` package. That package is installed on the development machine and is not among `info.rkt`'s deps. The repository is a linked multi-collection package, so the symbol `host/racket/fs` resolves to `host/racket/fs.rkt` from any current directory. All seven `.rkt` files in `host/racket/` load with nothing written to stdout or stderr (checked from `/tmp`). Their effects live in `main` submodules or in procedures a caller invokes. |
| Runners | `host/racket/aloemacs-run.rkt` injects `term` and `fs-host`, then loads `examples/aloemacs/main.aloe`. `host/racket/gel-run.rkt` injects `term`, then loads `gel/main.aloe`. |
| Census | `tests/modules/001-census.rkt` adds one test for every `.aloe` file under `examples`, `lib`, `gel`, and `tests`. It allows the free names `term` and `fs-host` as base names. |

### 1.1 The problem, as found

- Hover and definition raise `typecheck: unbound symbol: fs-host` at
  every position in `examples/aloemacs/main.aloe`. The name is used once,
  in `(Fs new fs-host)` on line 74. In `gel/main.aloe` they raise
  `typecheck: unbound symbol: term`. The first use is line 19, inside a
  `GelMain` method body.
- Completion in `main.aloe` on `from-string` in `(Text from-string "")`
  (line 11) offers `from-string` and `indexed`. Its recovery returns once
  the receiver is typed, before the checker reaches `fs-host`. After
  `(fs-host ` it offers nothing.
- Completion in `gel/main.aloe` behaves the same way. It answers where
  its receiver is typed before the first use of `term`: `(self loop` in
  the `call` method offers `call` and `loop`. At that first use and
  after it, it offers nothing. On `write-line` in `(term write-line`
  (line 19) it offers nothing, and so does `(state handle-key` later in
  the `loop` method.
- A scratch probe of the tree on 2026-10-16 bound only
  `(host-receiver-type fs-interface)` as `fs-host` on a fresh query base.
  `main.aloe` then checks in about 40 ms. Binding `term` the same way
  makes `gel/main.aloe` check in about 4 ms. Nothing else in either file
  is unbound. The answers in §9 come from that probe.

## 2. Series and order

Series identity `host-queries`, spoken **editor-host-queries 000**.
Checkpoints live in `docs/editor/host-queries/checkpoints/` with three
digits from `000`, and they are never renumbered. Tests live in
`tests/editor/host-queries/`, and fixtures in
`tests/editor/host-queries/fixtures/`. They do not go in
`CHECKPOINTS.md` or `docs/checkpoints/`, and they do not rewrite an
earlier editor series. Branch: `experiment/2026-10-16-host-queries`.

There are two layers, in this order. The manager may not reorder them or
add a feature.

1. **The query path accepts host types** (§4, §5). The checker gains an
   interface-taking hook. The query base binds the given hosts on the
   query's fresh base. The three public queries take `#:hosts`. The
   first consumer is a set of Racket query tests that require
   `host/racket/fs` and `host/racket/term` themselves and pass the real
   interfaces.
2. **The language server finds the manifest and passes the hosts**
   (§6–§8). This layer adds a manifest reader, `aloe/host-manifest.rkt`,
   and writes the effects rule into `host/racket/README.md`. It changes
   `aloe/lsp.rkt` and checks in the two product manifests. The VS Code
   hand check (§11) follows it.

About two checkpoints are expected. If layer 2 does not fit one
implementer conversation, the manager may split it at the
reader/server seam. The first part is then the reader (§6), the README
rule and its census test (§8.2), and the import test (§10.2). Its
consumer is the reader's own unit tests. The second part is the server
change (§7), the product manifests (§8.1), the LSP tests, and the hand
check. There is no VS Code checkpoint.

## 3. Sentences this project lifts

Each sentence below stays in its closed spec. That file is not edited.
This spec lifts each one for host-interface bindings only, as the
definition spec lifted the LSP spec's deferral without editing it.
Where one of these sentences and this spec disagree about
host-configured queries, this spec wins. Everywhere else the older
sentence still holds.

- [Expression query §4](../expression-query/spec.md): "The query has no
  host-injection parameter", and "Adding a host-configured query is a
  separate design". This spec is that design. Its other clause still
  holds: "the path argument does not imply ambient application
  capabilities". No query infers hosts from its path (§5.6).
- [Completion §4](../completion/spec.md): "There is no host injection
  parameter." Its recovery rule and early exit stay as written (§5.5).
- [Definition §9 and §10](../definition/spec.md). "`main.aloe` is a
  whole-file miss" still holds for an unconfigured `main.aloe`. The
  non-goal "Host injection in the editor queries" belongs to that
  series. This project restores the `main.aloe` hand check that
  definition §8 moved to `file.aloe` (§11, step 3).
- [LSP §2](../lsp/spec.md): "The adapter never evaluates Aloe code and
  never invokes a host capability." That stays true. Loading an
  interface runs no implementation, and the adapter still imports no
  host module (§7.1). LSP §8 says "There is no configuration file, …
  workspace scan". That sentence is about launching the server. The
  manifest is query data in a folder, not launch configuration, and
  there is still no workspace scan.
- [Signatures of a type §4.6](../signatures-of-type/spec.md): not
  lifted. It governs host rows, nominal identity, and annotations.
- [VS Code client](../vscode/spec.md): `aloe.racketPath` stays the
  client's only setting.

## 4. The checker hook (layer 1)

All of this is in `aloe/type.rkt`.

**One store.** A private procedure stores a host's type:
`(type-environment-set! environment name (host-receiver-type interface))`.
Both hooks below call it, so a type made from an interface and a type
made from a receiver are built the same way.

**The driver's hook is unchanged.** `type-environment-inject-host!`
keeps its three checks, its `who`, and its messages. After them it calls
the store with `(host-receiver-interface receiver)`. Its contract does
not change, and neither does the driver's behavior.

**The query hook.** A new submodule:

```racket
;; Editor queries bind a host's type from its interface alone, without
;; constructing a receiver, through this deliberately narrow hook.
(module* query-host-binding #f
  (provide type-environment-bind-host-interface!))
```

`(type-environment-bind-host-interface! environment name interface)`:

| Argument | Check | Message (`raise-arguments-error`, who `'type-environment-bind-host-interface!`) |
|---|---|---|
| `environment` | `type-environment?` | `"environment must be a type environment"` |
| `name` | `symbol?` | `"name must be a symbol"` |
| `interface` | `host-interface?` | `"interface must be a validated host interface"` |

After the checks it calls the store. It does not refuse a name that is
already bound. As with the driver, that is the caller's job (§5.4). It
is not added to the checker's public API, and `host-receiver-type`
stays unexported. `tests/checkpoint-88.rkt` checks that
`host-receiver-type` and the driver's hook stay out of that API, and it
stays green with no edit.

**A test-only reader.** A second submodule, in the style of
`class-name-span`:

```racket
;; Tests read the interface inside a bound host type through this hook;
;; nothing else does.
(module* host-binding-interface #f
  (provide checker-host-interface))
```

`(checker-host-interface environment name)` returns the
`host-interface` inside the host type bound to `name`, read with
`type-environment-ref`. It raises an error when `name` is bound to
something other than a host type.

## 5. Queries with hosts (layer 1)

### 5.1 The argument

Each public query gains one keyword argument:

```racket
(query-expression-at source-path position
                     #:document-path [document-path source-path]
                     #:hosts [hosts '()])
(query-definition-at source-path position
                     #:document-path [document-path source-path]
                     #:hosts [hosts '()])
(query-selector-completions source position
                            #:source-path [source-path #f]
                            #:hosts [hosts '()])
  ; hosts : (listof (cons/c symbol? host-interface?)), names distinct
```

A pair's car is the Aloe binding name. Its cdr is the interface value
a host module exports, for example `fs-interface` from
`host/racket/fs`. `'()` means no hosts. A call with `#:hosts '()` is
exactly a call without the argument. Each query behaves as today in
that case, and every existing test stays green with no edit except the
keyword list in §10.4.

### 5.2 Shape checks

The query base gains one shared check, exported from the `query-base`
submodule beside the existing hooks:

```racket
(check-query-hosts who hosts)
```

1. If `hosts` is not a list of pairs of a symbol and a value that
   satisfies `host-interface?`, it calls
   `(raise-argument-error who "(listof (cons/c symbol? host-interface?))" hosts)`.
   A host receiver, such as `(make-fs-receiver)`, is not an interface
   and fails here.
2. If a name appears twice, it calls
   `(raise-arguments-error who "host names must be distinct" "host name" name)`
   for the first name that repeats.

Each query calls it with its own name as `who`. The call comes right
after the query's existing argument checks and before the query reads
anything. These are argument errors, so all three queries raise them,
completion included. `host-interface?` is imported from `aloe/host.rkt`
by `aloe/main.rkt`. The three query modules do not import
`aloe/host.rkt`.

### 5.3 Which branch binds hosts

| Branch | When | Hosts |
|---|---|---|
| File module | hover or definition, and `base-library-path` does not recognize the document path; completion with a source path that `base-library-path` does not recognize | bound on the fresh base (§5.4) |
| Base library | `base-library-path` recognizes the identity | ignored. The buffer is checked exactly as today |
| Completion with no source path | `source-path` is `#f` | ignored. The buffer is checked exactly as today |

Hosts are still shape-checked (§5.2) on every branch.

### 5.4 Binding on the base

`typecheck-file-module-buffer` gains two keyword arguments:

```racket
(typecheck-file-module-buffer document-path source-bytes expressions observe
                              #:hosts [hosts '()]
                              #:who [who 'typecheck-file-module-buffer])
```

It makes the fresh environment with `(make-type-environment)` as
today. Before the buffer is checked, it walks `hosts` in order and does
this for each pair on that environment's base:

- If the name is already bound there (`type-environment-bound?`), it
  calls
  `(raise-arguments-error who "host name is already bound on the query base" "host name" name)`.
  On the found tree, the names bound on a fresh base are `dummy`,
  `List`, `Int`, `String`, `Symbol`, `Mirror`, `Option`, and every
  name the four base libraries define.
- Otherwise it calls `type-environment-bind-host-interface!`.

Then it checks the buffer exactly as today. Each query passes
`#:hosts hosts #:who '<its own name>` on the file-module branch.
`aloe/main.rkt` imports `type-environment-base` from the `load-cache`
submodule and the hook from `query-host-binding`.

This is `driver-inject-host!` without the runtime half, done on the
query's base. So:

- A file the buffer loads sees the host, as it does in the runner.
- If the buffer or a loaded file defines a host's name, the checker
  reports its existing collision, for example
  `typecheck: name collision: fs-host is defined by the language base and by <path>`.
- Each query has a fresh base, and the load cache belongs to that base.
  A host bound for one query is never visible to another.
- No receiver is constructed, no implementation runs, no runtime
  environment is made, and `driver-inject-host!` is never called. The
  type holds the interface value the caller passed, so it is `eq?` to
  the module's export.

### 5.5 Failure

`query-expression-at` and `query-definition-at` keep their failure
policy (expression query §6), with this order:

1. existing argument errors
2. §5.2's shape errors
3. reading, parsing, and selection, as today
4. §5.4's already-bound refusal, an `exn:fail:contract` naming the query
5. checking, as today. An Aloe checker failure raises
   `exn:fail:aloe-type`.

`query-selector-completions` raises the existing argument errors and
§5.2's shape errors. §5.4's refusal happens inside its existing handler,
so a name already bound on the base gives `'()`, as any failure after
the argument checks does (completion §1). Beyond the new keyword, the
completion module changes in only two ways: it calls
`check-query-hosts`, and on the file-module branch it passes `#:hosts`
and `#:who` to `typecheck-file-module-buffer`.

Through the server (§7), every refusal is a miss. The reader never
hands over a bad shape or a repeated name, the two ignored branches
answer as today, and `invoke-query` turns the already-bound refusal into
null for hover and definition. Completion turns it into `'()` itself.

### 5.6 Answers with hosts

- **Hover** on a host name shows the interface name as its type. The
  pathed type is the same, so hover prints no `from:` line. The rows are
  the interface's methods in declaration order (signatures-of-type
  §4.6). This is the format hover already uses for a host receiver
  type. No hover format is added.
- **Completion** after `(fs-host ` lists `FsHost`'s selectors from the
  existing catalog. The recovery rule and the early exit do not change.
  Hosts only add bindings to the base. At a position that answers today,
  such as `from-string` in `(Text from-string "")`, the items are the
  same with or without the host.
- **Definition** on a host name returns `#f`. Its token is a variable
  whose type is not a class type, so definition §4.4 resolves it to
  nothing. A host is not a class and has no span, and there is no jump
  into Racket source. A class name in the same file still jumps:
  definition on `Fs` in `(Fs new fs-host)` lands in `lib/fs.aloe`. The
  definition query needs no change beyond `#:hosts`.
- Host interface names stay unavailable in Aloe annotations.

### 5.7 Boundary

The queries never read a manifest, never load a module, and never
`require` anything under `host/racket/`. Hosts come only from the
explicit argument. No query infers hosts from its path. The queries
still evaluate nothing.

Three existing source tests pin the text of `aloe/completion-query.rkt`
(§10.4). The shape checks live in `aloe/main.rkt` partly so that the
completion module can stay inside those pins.

## 6. The manifest (layer 2)

### 6.1 File and place

The manifest is a file named `aloe-hosts.rktd` in the folder that
contains the document. The server looks nowhere else: it does no
parent-folder search, no workspace scan, and has no glob rows. A folder
has at most one manifest. It is not a VS Code setting, not an Aloe
declaration, and not Aloemacs or Gel knowledge in the server.

### 6.2 Reading

The reader opens the file and calls Racket `read` once with these
parameters set to `#f`: `read-accept-reader`, `read-accept-lang`,
`read-accept-compiled`, and `read-accept-graph`. Other reader
parameters keep their defaults. A second `read` must return `eof`.
Comments are allowed. A `#lang` or `#reader` line, compiled code, and
graph notation are read errors. Nothing is evaluated, so reading a
manifest cannot run code.

The reader reads the file on every call. There is no cache and no file
watching, so an edit takes effect on the next query.

### 6.3 Shape

```text
manifest ::= ( row ... )
row      ::= ( file NAME entry entry ... )
entry    ::= ( host BINDING MODULE EXPORT )
```

- The manifest is a proper list of rows. It may be empty.
- A row is a proper list headed by the symbol `file`, then `NAME`, then
  at least one entry.
- `NAME` is a string of at least one character that contains no `/`,
  no `\`, and no NUL, and is neither `.` nor `..`.
- An entry is a proper list of exactly four elements headed by the
  symbol `host`. `BINDING` and `EXPORT` are symbols. `MODULE` may be
  any datum. Only §6.5 judges it, so a bad module path fails one row and
  not the whole manifest.
- No two rows have the same `NAME` (`string=?`).

A manifest outside this shape is **broken**. So is a manifest that
cannot be opened or read, including a directory named `aloe-hosts.rktd`.
A broken manifest counts as absent: every document in its folder gets
today's query call. A broken manifest cannot say which documents it
configures, so it configures none. A typo must not turn off hover,
completion, and definition for `file.aloe` beside `main.aloe` without
any sign of why.

Examples of broken manifests, each a whole file:

| Text | Why |
|---|---|
| `((file "main.aloe" (host fs-host host/racket/fs fs-interface))` | unparseable |
| `#lang racket/base` | `#lang` is not accepted |
| `() ()` | a second datum |
| `(file "main.aloe" (host fs-host host/racket/fs fs-interface))` | not a list of rows |
| `((file "main.aloe"))` | a row with no entry |
| `((file main.aloe (host fs-host host/racket/fs fs-interface)))` | `NAME` is a symbol |
| `((file "../main.aloe" (host fs-host host/racket/fs fs-interface)))` | `NAME` contains `/` |
| `((file "main.aloe" (host fs-host host/racket/fs)))` | an entry of three |
| `((file "main.aloe" (hosts fs-host host/racket/fs fs-interface)))` | wrong entry head |
| `((file "main.aloe" (host "fs-host" host/racket/fs fs-interface)))` | `BINDING` is a string |
| `((file "main.aloe" (host fs-host host/racket/fs fs-interface (receiver make-fs-receiver))))` | a fifth element (see §6.9) |
| `((file "a.aloe" (host fs-host host/racket/fs fs-interface)) (file "a.aloe" (host term host/racket/term term-interface)))` | a repeated `NAME` |

### 6.4 Matching

The document path is normalized with
`(simplify-path (path->complete-path document-path) #f)`, without
touching the filesystem. The manifest is `aloe-hosts.rktd` in that
path's folder. A row matches when `(string->path-element NAME)` is
`equal?` to the path's file name. The match is exact and
case-sensitive. The document itself need not exist.

The key is always the document path, which is the identity. It is
never the path the checker reads. The server never gives the reader an
`aloe-lsp-snapshot-…` sibling, and a sibling's name matches no row.

Only the queried document's row applies. A loaded file's own row is
not read for that query. Loaded files see the queried document's hosts
through the base (§5.4).

### 6.5 The module boundary

`MODULE` passes when it is a symbol whose name matches:

```text
^host/racket/[a-z0-9_-]+$
```

That is the `host/racket` collection with exactly one segment after it,
written in lowercase ASCII letters, digits, `_`, and `-`. Every other
`MODULE` is rejected before anything loads.

| Rejected `MODULE` | Kind |
|---|---|
| `"host/racket/fs"` | a string |
| `(file "/tmp/x.rkt")`, `(lib "host/racket/fs")`, `(planet a/b)` | a form |
| `(submod host/racket/fs main)` | a submodule |
| `./fs`, `fs` | relative or another collection |
| `host/racket/../aloe/lsp`, `host/racket/fs/deeper` | `..`, a deeper path |
| `host/racket`, `aloe/lsp`, `racket/base` | not one segment under `host/racket` |
| `host/racket/FS`, `host/racket/a.b` | outside the segment alphabet |

The alphabet gives each module one spelling. On a case-insensitive
filesystem, `host/racket/FS` would open `fs.rkt` as a second module
instance, with a second `fs-interface` that is not `eq?` to the first.

Under this rule, a manifest can make the server load only a module
already installed in the `host/racket` collection. It can never load a
file from the workspace. Collection resolution does not depend on the
server's current directory.

### 6.6 Loading an entry

The reader calls a loader for each entry, in row order, with three
arguments: `MODULE`, `EXPORT`, and a failure thunk. While the loader
runs:

- `current-output-port` and `current-error-port` are ports that discard
  their output (`open-output-nowhere`), and
- `current-input-port` is an empty port.

The server's stdout is the LSP frame stream and its stdin is the
request stream. A host module that broke the effects rule (§8.2) still
cannot write a byte to the first or take a byte from the second.

The loader's outcomes:

- It raises a value that is not a break: the load failed.
- It returns the value of the failure thunk: the export is missing.
- It returns a value that is not `host-interface?`: the export is not
  an interface. The predicate is the reader's own, imported from
  `aloe/host.rkt`.
- Otherwise that value is the entry's interface.

The **default loader** calls `(dynamic-require MODULE EXPORT thunk)`
with `current-namespace` set to a namespace made by
`namespace-anchor->empty-namespace` from an anchor in the reader
module. That namespace is empty, but it shares the server's module
registry: its declarations and instances. So the host module and the
server share one instance of `aloe/host.rkt`, `host-interface?` holds,
and the interface is the same value a runner's receiver carries. The module
is not loaded into a fresh registry. Its `main` submodule never runs. A
module loads once per server process through the registry. Later calls
find it already instantiated.

### 6.7 Results

`read-document-hosts` returns one of three things:

| Situation | Result |
|---|---|
| no manifest in the folder, or a broken one (§6.3) | `#f` |
| a well-formed manifest with no row for the document | `#f` |
| the row repeats a `BINDING` | `(document-hosts-failure 'duplicate-name)` |
| an entry's `MODULE` fails §6.5 | `(document-hosts-failure 'module-path)` |
| an entry's loader raises | `(document-hosts-failure 'load)` |
| an entry's export is missing or not an interface | `(document-hosts-failure 'export)` |
| every entry loads | `(document-hosts bindings)`. `bindings` holds `(cons BINDING interface)` in row order |

The reader checks in this order: repeated binding names, then every
entry's `MODULE` against §6.5, and then load and export entry by entry.
The first failure is the result. So a row that fails on its names or
its module paths calls no loader, and no module loads unless the
document's own row names it.

A failing row is all or nothing. The server never checks a configured
document without its hosts, or with only some of them (§7.2). A fifth
way a row can fail, a binding name already bound on the base, belongs
to the query (§5.4). The server sees it as the query's miss.

### 6.8 The reader module

`aloe/host-manifest.rkt` is the only module under `aloe/` that loads a
host module.

```racket
(provide host-manifest-name               ; "aloe-hosts.rktd"
         (struct-out document-hosts)          ; (bindings)
         (struct-out document-hosts-failure)  ; (reason)
         read-document-hosts)

(struct document-hosts (bindings) #:transparent)
(struct document-hosts-failure (reason) #:transparent)

(read-document-hosts document-path #:loader [loader <default loader>])
  ; document-path : path-string?
  ; loader        : a procedure of three arguments (§6.6)
  ; -> (or/c #f document-hosts? document-hosts-failure?)
```

It raises only for its own arguments. A `document-path` that is not
`path-string?` gets `raise-argument-error`. A `loader` that does not
accept three arguments gets `raise-argument-error`. Nothing a manifest
or a module does makes it raise.

It requires `aloe/host.rkt` for `host-interface?`, plus Racket
libraries. It does not require the parser, the checker, the queries, or
anything under `host/racket/`.

**The test-only allowance.** `#:loader` is the one test seam. Tests need
a module that prints when it loads, and the effects rule forbids one
under `host/racket/` as product code. So tests pass loaders instead.
One counts calls, to prove that a rejected path or an unmatched row
never reaches it. One prints and reads, to prove that capture works.
One raises. Production never passes `#:loader`. No printing module is
added under `host/racket/`, and no module is added anywhere for this.

### 6.9 Room for runners

A later project may let the runners read the same manifest. A runner
also needs a way to build a receiver, such as a factory. That project
can extend the grammar, for example with a fifth element in an entry or
a new entry head. A four-element `host` entry keeps exactly the meaning
it has here. This project adds no factory and changes no runner. Under
this spec, a manifest that uses such an extension is outside §6.3 and
counts as broken.

## 7. The language server (layer 2)

### 7.1 Dependencies

`aloe/lsp.rkt` adds one require, placed after the definition query's:

```racket
(only-in "host-manifest.rkt"
         read-document-hosts
         document-hosts?
         document-hosts-bindings
         document-hosts-failure?)
```

The adapter still imports no parser, no checker internal, and no host
module. It treats the bindings as opaque and passes them through. The
LSP spec's thin dependency boundary (§2) holds.

### 7.2 Each query request

For hover, definition, and completion, the adapter reaches the point
where it calls the query today: the document is open, its URI is a
supported local file, and the position converts. At that point it
calls `(read-document-hosts path)` once, with the document's local
path from the URI. For hover and definition this happens before the
clean-or-sibling choice, so a failing row creates no sibling. Then:

| Reader result | Hover and definition | Completion |
|---|---|---|
| `#f` | today's call, unchanged | today's call, unchanged |
| `document-hosts` | today's call plus `#:hosts bindings`, on the clean path or through the sibling. The sibling call passes both `#:document-path` and `#:hosts` | today's call plus `#:hosts bindings` |
| `document-hosts-failure` | no query call. The result is JSON null | no query call. The result is the empty array |

So a document with no row gets exactly today's call, with no host
argument. Fake queries in existing tests, which do not accept `#:hosts`,
need no edit. A dirty buffer still answers, because the reader is given
the document path and never the sibling. The adapter reads no manifest
for an unopened document, an unsupported URI, or an invalid position.

When the adapter passes hosts, `invoke-query` still turns any
`exn:fail` from hover's or definition's query into no answer. That
includes the already-bound refusal.

### 7.3 What stays the same

- The initialize result, methods, error codes, and messages. Snapshot
  creation and removal.
- The adapter publishes no diagnostic. It writes nothing to stdout
  outside the LSP frames, and the reader's capture covers loading
  (§6.6). The `error-output` port stays unused.
- The server keeps running after a broken manifest or a failing row,
  and answers the next request.
- `run-lsp-server/with-queries` keeps its arguments. No new test hook is
  needed, because LSP tests use real fixture folders.
- `editors/vscode/` does not change.

## 8. Product manifests and the effects rule (layer 2)

### 8.1 The two manifests

`examples/aloemacs/aloe-hosts.rktd`:

```racket
;; Hosts the Aloe language server binds when it checks a document in this
;; folder. See docs/editor/host-queries/spec.md.
((file "main.aloe"
   (host fs-host host/racket/fs fs-interface)))
```

`gel/aloe-hosts.rktd`:

```racket
;; Hosts the Aloe language server binds when it checks a document in this
;; folder. See docs/editor/host-queries/spec.md.
((file "main.aloe"
   (host term host/racket/term term-interface)))
```

The Aloemacs row lists only `fs-host` (§12, item 5). No other document
in either folder gets a row. In both folders, only `main.aloe` uses a
host.

### 8.2 The effects rule

A new file, `host/racket/README.md`, states the rule where an author of
a new host module will see it. It says at least:

- Every module in `host/racket/` has a definition-only top level.
  Loading a module must not print, read standard input, open a TTY,
  touch the filesystem, or start a loop. Effects live in `main`
  submodules or in procedures a caller invokes.
- Why: the Aloe language server loads a module from this folder when an
  `aloe-hosts.rktd` manifest names it, to read the exported interface.
  The server's stdout is its LSP frame stream and its stdin is the
  request stream.
- A test loads every module in the folder and checks that nothing is
  written. Name the test file.

All seven current files follow the rule (§1). The census test in
§10.2 enforces it. The README is the only file added under
`host/racket/`. No `.rkt` file there changes.

## 9. Fixtures and normative answers

Lines are one-based, and columns are zero-based. Positions are
one-based, as `srcloc` reports them. Product-file numbers are as of
`e641268`. The user edits those files by hand, so tests locate each
cursor and target by its text, never by a stored number. Fixtures are
ASCII with one LF after every line.

### 9.1 Product cursors

`examples/aloemacs/main.aloe` with `fs-host` bound to `fs-interface`:

| Cursor (find by text) | As found | Answer |
|---|---|---|
| `fs-host` in `(Fs new fs-host)` | line 74, col 33, pos 2252, span 7 | hover: type `FsHost`, pathed type `FsHost`, rows (§9.3). Definition: `#f` |
| `AloemacsBuffer` in `(AloemacsBuffer new*` | line 8, col 11, pos 157, span 14 | hover: type `(Class AloemacsBuffer)`, pathed type `(Class AloemacsBuffer@examples/aloemacs/file.aloe)`. Definition: `examples/aloemacs/file.aloe`, the name in `(define-class AloemacsBuffer` followed by a newline (as found: line 132, col 14, pos 4439, span 14) |
| `Fs` in `(Fs new fs-host)` | line 74, col 26, pos 2245 | definition: `lib/fs.aloe`, line 23, col 15, pos 490, span 2 |
| `from-string` in `(Text from-string "")` | line 11, col 34, pos 266 | completion: the same items with and without the host (as found: `from-string`, `indexed`) |
| after `(fs-host ` in a copy of the text with `(Fs new fs-host)` replaced by `(Fs new (fs-host ))` and `#:source-path` set to the real `main.aloe` | pos 2261 | completion: `FsHost`'s selectors in declaration order (§9.3), with replacement span 0 |

`gel/main.aloe` with `term` bound to `term-interface`:

| Cursor | As found | Answer |
|---|---|---|
| `term` in the first `(term write-line` | line 19, col 14, pos 367, span 4 | hover: type `Term`, rows (§9.3) |
| `write-line` in that `(term write-line` | line 19, col 19, pos 372 | completion: `Term`'s selectors in declaration order. `write-line` matches a row exactly, so every row is offered (completion §5) |

Without hosts, every hover and definition cursor above raises
`exn:fail:aloe-type` with `typecheck: unbound symbol: fs-host` (or
`term`). Completion after `(fs-host ` and on `write-line` gives `'()`.

### 9.2 Fixture files

`tests/editor/host-queries/fixtures/configured/`, used from layer 1:

`spot.aloe` (67 bytes):

```aloe
(define-class Spot
  (fields
    (x Int)
    (y Int))
  (methods))
```

`reads-fs.aloe` (33 bytes):

```aloe
(define start (fs-host current))
```

`uses-fs.aloe` (145 bytes):

```aloe
(load "spot.aloe")
(load "reads-fs.aloe")

(define here (fs-host current))
(define corner (Spot new 1 2))
(define listing (fs-host names start))
```

`defines-fs-host.aloe` (19 bytes):

```aloe
(define fs-host 3)
```

Added in layer 2: `configured/failing.aloe` (33 bytes):

```aloe
(define there (fs-host current))
```

`configured/aloe-hosts.rktd`:

```racket
((file "uses-fs.aloe"
   (host fs-host host/racket/fs fs-interface))
 (file "failing.aloe"
   (host fs-host host/racket/fs no-such-interface)))
```

`tests/editor/host-queries/fixtures/broken/neighbor.aloe` (89 bytes):

```aloe
(define-class Mark
  (fields
    (n Int))
  (methods))

(define first-mark (Mark new 1))
```

`broken/aloe-hosts.rktd`, an entry of three:

```racket
((file "neighbor.aloe"
   (host fs-host host/racket/fs)))
```

A checked-in `.aloe` fixture may use only `fs-host` or `term` as a free
host name. Those are the names the census allows, and each new `.aloe`
file adds one census test to the suite count. A buffer that needs any
other host name, such as `other-fs`, is written by the test to a
temporary directory outside the census roots. A temporary copy written
beside a fixture is named without the `.aloe` extension, for example
with `(make-temporary-file "host-queries-copy-~a" #f folder)`, so a
census run in parallel never sees it.

### 9.3 Host rows and the hover text

`FsHost`'s rows, in declaration order, as `selector : parameters ->
return`:

```text
current : () -> String
resolve : (String) -> String
child : (String String) -> String
root? : (String) -> Bool
parent : (String) -> String
name : (String) -> String
kind : (String) -> String
names : (String) -> (List String)
read : (String) -> String
write : (String String) -> String
```

`Term`'s rows: `read-key`, `write-line`, `write`, `columns`, `rows`,
and `read-event`. Tests build the expected rows from the interface
itself: each method's selector, parameter types, and return type, in
`host-interface-methods` order. Tests do not copy the list.

Hover on `fs-host` in `uses-fs.aloe` (LSP line 3, character 14) returns
exactly:

```text
type: FsHost
messages:
  current : () -> String
  resolve : (String) -> String
  child : (String String) -> String
  root? : (String) -> Bool
  parent : (String) -> String
  name : (String) -> String
  kind : (String) -> String
  names : (String) -> (List String)
  read : (String) -> String
  write : (String String) -> String
```

with range 3:14–3:21.

### 9.4 Fixture answers

| Document and cursor | With its hosts | Without |
|---|---|---|
| `uses-fs.aloe`, `fs-host` at line 4, col 14, pos 58 | hover §9.3, span 7. Definition `#f` | unbound `fs-host` |
| `uses-fs.aloe`, `Spot` at line 5, col 16, pos 92 | definition: `spot.aloe`, line 1, col 14, pos 15, span 4 | unbound `fs-host` |
| `uses-fs.aloe`, `start` at line 6, col 31, pos 138 | hover: type `String`. This shows that the loaded `reads-fs.aloe` saw the host | unbound `fs-host` |
| `uses-fs.aloe` text with `(fs-host current)` on line 4 replaced by `(fs-host )`, cursor pos 66 (line 4, col 22) | completion: `FsHost`'s ten selectors, replacement start 66, span 0 | `'()` |
| `defines-fs-host.aloe`, any cursor | `exn:fail:aloe-type`, `name collision: fs-host is defined by the language base and by …defines-fs-host.aloe` | checks. Hover on `3` is `Int` |
| `reads-fs.aloe` queried alone with no hosts | — | unbound `fs-host`. A query gets only the hosts passed for its own document. Through the server, the `configured` manifest (layer 2) has no row for `reads-fs.aloe` |
| `broken/neighbor.aloe`, `Mark` at line 6, col 20, pos 77 | — (no row applies) | hover: `type: (Class Mark)`, `from: (Class Mark@tests/editor/host-queries/fixtures/broken/neighbor.aloe)`, `new : (Int) -> Mark`. Definition: the same file, line 1, col 14, pos 15, span 4 |

Through the server (LSP lines and characters are zero-based):

| Request | Result |
|---|---|
| hover, `uses-fs.aloe` 3:14 | §9.3's text and range |
| definition, `uses-fs.aloe` 4:16 | the `path->url` URI of `spot.aloe`, range 0:14–0:18 |
| completion, `uses-fs.aloe` after a `didChange` to the line-4 hole text, at 3:22 | ten items in `FsHost` order. Each `textEdit` range is 3:22–3:22, and the details are `"() -> String"`, `"(String) -> String"`, `"(String String) -> String"`, `"(String) -> Bool"`, `"(String) -> String"`, `"(String) -> String"`, `"(String) -> String"`, `"(String) -> (List String)"`, `"(String) -> String"`, `"(String String) -> String"` |
| hover after a `didChange` that prepends one LF to `uses-fs.aloe`, at 4:14 | §9.3's text, range 4:14–4:21. No sibling remains, and the file on disk is unchanged |
| hover, definition, completion on `failing.aloe` 0:14 | null, null, `[]` |
| hover and definition, `broken/neighbor.aloe` 5:20 | §9.4's `Mark` answers. The definition URI is the document's URI as sent, range 0:14–0:18 |

## 10. Required coverage

Run as `TMPDIR=/tmp raco test -j 4 -y <paths>`: the checkpoint's new
test file first, then any suite the checkpoint names, then `tests`. The
`-j 4` and `-y` flags are required. Test file names belong to the
checkpoints.

### 10.1 Layer 1: the query path

The tests require `host/racket/fs` and `host/racket/term` themselves.
No test file is under `aloe/`.

- **Hook.** `type-environment-bind-host-interface!` on the base of a
  `(make-type-environment)`. `checker-host-interface` returns a value
  `eq?` to `fs-interface`. Each of the three argument errors is raised.
  A second binding of the same name is not refused by the hook. After
  `type-environment-inject-host!` binds a receiver,
  `checker-host-interface` returns a value `eq?` to the receiver's
  interface, and the driver hook's three messages are unchanged.
  `tests/checkpoint-88.rkt` passes unedited.
- **Product cursors.** Every row of §9.1, with hosts and without.
  Expected rows come from the interface (§9.3). Targets are found by
  text.
- **Fixture answers.** Every query row of §9.4.
- **Sibling copy.** A copy of `uses-fs.aloe` with one LF prepended,
  written beside it under a non-`.aloe` name, is queried with
  `#:document-path` set to the real `uses-fs.aloe` and with hosts.
  Hover on `fs-host` (line 5) answers §9.3's rows. The copy is removed
  afterwards.
- **Isolation.** A hover with hosts answers. The same call without
  hosts then raises unbound `fs-host`. Two calls with hosts in a row
  return equal answers.
- **Nominal identity.** In a temp file, `(define both (List of fs-host
  other-fs))`. With both names bound to `fs-interface`, the file checks
  and hover on the selector `of` gives `(List FsHost)`. Hover on `both`,
  a `define` name, selects the whole form, whose type is `Void`. With
  `other-fs` bound to
  `(make-host-interface 'FsHost (host-interface-methods fs-interface))`,
  a copy, the query raises `exn:fail:aloe-type` with
  `List of elements must have one type`.
- **No host call.** `fs-host` is bound to an interface built from
  `fs-interface`'s selectors and types, whose implementations increment
  a counter. Hover, definition, and completion run over `uses-fs.aloe`
  (`listing` sends `names`), and the counter stays 0.
- **Refusals,** for each of the three queries: `#:hosts` not a list; a
  pair whose car is not a symbol; a pair whose cdr is a receiver
  (`(make-fs-receiver)`); and a name given twice. Each raises
  `exn:fail:contract` whose message starts with the query's name.
  Hosts that bind `fs-host` and also `Option` (then `List`, then
  `dummy`) to `fs-interface` make hover and definition raise
  `exn:fail:contract` naming the query, with
  `host name is already bound on the query base`. The same hosts make
  completion return `'()` at the `(fs-host ` cursor of §9.4.
- **Ignored branches.** `lib/option.aloe` queried by hover and
  definition with `fs-host` bound answers exactly as without. Completion
  with no source path and with `fs-host` bound answers as without, for
  a buffer that does not use the host.
- **Unchanged.** `#:hosts '()` equals no argument on a §9.4 cursor.
  `tests/editor/expression-query/003-public-query.rkt` and the existing
  query suites pass with only the edit in §10.4.

### 10.2 Layer 2: the reader

Each case writes its manifest into a fresh temporary folder, except
where it names a fixture. A document path is enough. The document file
need not exist.

- **Matching.** A row matches its document. A neighbor without a row
  gives `#f`. `aloe-lsp-snapshot-123` in the same folder gives `#f`. A
  relative document path is normalized. Editing the manifest between
  two calls changes the second result.
- **Broken manifests.** Every row of §6.3's table, plus a directory
  named `aloe-hosts.rktd`, gives `#f` for the named document and for a
  neighbor. A counting loader is never called.
- **Failing rows.** A repeated binding name gives `'duplicate-name`, and
  the loader is not called. Every row of §6.5's table gives
  `'module-path`, and the counting loader is not called, including when
  the bad entry follows a good one. A loader that raises an `exn:fail`,
  and one that raises a non-exception value, give `'load`. With the
  default loader: `host/racket/no-such-module` gives `'load`.
  `(host fs-host host/racket/fs no-such-interface)` and
  `(host fs-host host/racket/fs make-fs-receiver)` give `'export`.
- **Success.** With the default loader, the `configured` fixture's
  `uses-fs.aloe` row gives `(document-hosts (list (cons 'fs-host i)))`
  with `i` `eq?` to `fs-interface`. A two-entry row of `fs-host` and
  `term` gives both, in order and `eq?`. A counting loader shows that
  only the matched row's entries are loaded.
- **Capture.** A loader that writes to `current-output-port` and
  `current-error-port`, reads a byte from `current-input-port`, and
  returns `fs-interface`. The test parameterizes its own output, error,
  and input ports around the call. The result is a success. The test's
  output and error ports stay empty. The loader's read returns `eof`,
  and the test's input port still holds its bytes.
- **Product manifests** (in whichever checkpoint checks them in):
  `examples/aloemacs/main.aloe` gives `fs-host` and `fs-interface`.
  `gel/main.aloe` gives `term` and `term-interface`.
  `examples/aloemacs/file.aloe` gives `#f`.
- **Static requires.** For every `.rkt` file under `aloe/`, skipping
  `compiled/`, take its compiled code (`get-module-code` from
  `syntax/modcode`). Then take the compiled code of each of its
  submodules, recursively, with both kinds of
  `module-compiled-submodules`. Resolve every import that
  `module-compiled-imports` lists, at every phase, with
  `module-path-index-resolve`. Each import resolves to a file under
  `aloe/` or outside this repository, and none resolves under
  `host/racket/`. Within `aloe/`, the closure of `aloe/lsp.rkt` does not
  contain `aloe/driver.rkt`. A self-check runs the same helper over an
  in-memory module, compiled in a fresh base namespace, that requires
  `host/racket/fs` inside a `module*` submodule. The helper must report
  it. So `raco make aloe/lsp.rkt` compiles no host module.
- **Source.** `aloe/main.rkt`, the three query modules, and
  `aloe/host-manifest.rkt` contain neither `make-host-receiver` nor
  `driver-inject-host!`.
- **Effects census.** Each `.rkt` file directly in `host/racket/`, listed
  from the directory, is loaded with `(dynamic-require path #f)` while
  stdout and stderr are string ports. Both stay empty. This needs
  `tui-term`, as existing suite tests already do.

### 10.3 Layer 2: the server

Every case runs through `run-lsp-server` or
`run-lsp-server/with-queries`, over the §9.2 folders.

- The real-query rows of §9.4's server table, byte for byte.
- A recording hover stub that accepts `#:document-path` and `#:hosts`
  receives, for `uses-fs.aloe`, one pair: `'fs-host` and a value `eq?`
  to `fs-interface`. Completion and definition stubs record the same.
- A stub that does not accept `#:hosts` answers for `spot.aloe` and for
  `broken/neighbor.aloe`. Each records one call per request. So those
  documents get no host argument.
- `failing.aloe`: counting stubs see zero calls, and the responses are
  null, null, and `[]`. A later hover on `uses-fs.aloe` still answers.
- The initialize result is unchanged, and every response decodes as a
  frame with no stray bytes on the output port.
- `npm test` in `editors/vscode/` passes, and `git diff` shows no
  change under `editors/vscode/`.

### 10.4 Existing tests this series edits

Each edit is the smallest one that keeps the test's intent:

| Layer | Test | Edit |
|---|---|---|
| 1 | `tests/editor/completion/002-public-query.rkt`, "public surface and arities are exact" | allowed keywords `'(#:source-path)` become `'(#:hosts #:source-path)` |
| 2 | `tests/editor/lsp/004-hover-results.rkt`, `tests/editor/lsp/008-adapter-failures.rkt`, `tests/editor/completion/003-lsp-completion.rkt` | the list of quoted `.rkt` names in `aloe/lsp.rkt` gains `"\"host-manifest.rkt\""` after `"\"definition-query.rkt\""` |

Other pins that the implementation must keep green without editing
them:

- `aloe/lsp.rkt` contains exactly one `(query path query-position)` and,
  in its completion section, exactly one
  `(query text query-position #:source-path path)`. Keep today's call
  forms literally, and add the host forms beside them.
- `aloe/lsp.rkt` must not contain the substrings `host.rkt`, `main.rkt`,
  `type.rkt`, `empty?`, `exn?`, or `Point`, among others (lsp 000, 004,
  and 008, and completion 003).
- `aloe/completion-query.rkt` must not contain substrings including
  `map`, `fold`, `sort`, `reverse`, `Mirror`, `Point`, `read-program`, or
  `type-of`. It contains exactly two each of `make-type-environment`,
  `recover-selector-completion-site`, and
  `typecheck-program/observe-selector-receiver` (completion 002).

The manager confirms this inventory with a scratch run of the product
edit and the whole suite, and treats the failing locations as the
inventory.

## 11. The hand check

After layer 2, in VS Code with the extension running
`racket -l aloe/lsp`. First run the layer's test command, or
`raco make aloe/lsp.rkt host/racket/fs.rkt host/racket/term.rkt`, then
Reload Window. Find each place by its text.

1. Open `examples/aloemacs/main.aloe`.
2. Hover `fs-host` in `(Fs new fs-host)` and see `FsHost`'s rows.
3. Hover `AloemacsBuffer` in `(AloemacsBuffer new* ...)`, the
   `initial-buffer` binding, and see the class. Go to definition on it.
   You land on the class name in `examples/aloemacs/file.aloe`.
4. Change `(Fs new fs-host)` to `(Fs new (fs-host ))`. Put the caret
   after `(fs-host ` and trigger completion. See `FsHost`'s selectors
   offered. Undo.
5. Edit the file without saving. Hover `fs-host` in `(Fs new fs-host)`
   again, and see that it still shows `FsHost`'s rows.
6. Open `gel/main.aloe` and hover `term` in `(term write-line`. See
   `Term`'s rows.
7. Confirm that `examples/aloemacs/file.aloe` behaves as before.

## 12. Choices this spec made

The charter left these open. Each is recorded with its reason.

1. **Manifest name and syntax.** `aloe-hosts.rktd`, with
   `(file NAME (host BINDING MODULE EXPORT) ...)` rows (§6.3). It is
   Racket data in a Racket data file, read without evaluation.
2. **The argument.** `#:hosts`, a list of `(cons symbol interface)`,
   default `'()`. The base-library branch and completion's
   no-source-path branch ignore hosts. A runner installs the base
   libraries before it injects any host, so checking a library as today
   is the runner's own environment. The server never queries without a
   source path.
3. **Refusals.** Shape errors and repeated names raise argument errors
   in all three queries, before anything is read. A name already bound
   on the base raises `exn:fail:contract` in hover and definition. It is
   `'()` in completion, through completion's existing handler. Through
   the server, each refusal is a miss (§5.5).
4. **Exact shape.** §6.3. A row needs at least one host. A bad module
   path fails its row, not the manifest, so a neighbor document keeps
   answering.
5. **The Aloemacs row lists only `fs-host`.** `main.aloe` and its loads
   use only `fs-host`. Listing `term` would make Aloemacs depend on the
   optional `tui-term` package: without it the row would fail, and
   `main.aloe` would go dark for a host it never uses. A later project
   that lets runners read the manifest can add `term` with its factory.
6. **The effects rule** lives in `host/racket/README.md`, and the
   census test in §10.2 enforces it.
7. **The reader.** `aloe/host-manifest.rkt`, with `read-document-hosts`
   and its two result structures (§6.8). The default loader uses a
   namespace that shares the reader's registry through an anchor. It
   does not depend on the caller's `current-namespace`.
8. **The test-only allowance** is `#:loader` (§6.8).
9. **Proof of the static-require rule.** The compiled-import test with
   its self-check (§10.2).
10. **The checkpoint split.** Two layers. Layer 2 may split at the
    reader/server seam (§2).

These are refinements of the charter. Each stays inside one of its
locked decisions:

- The `MODULE` alphabet `[a-z0-9_-]`, for one spelling per module
  (§6.5).
- `read-accept-compiled` and `read-accept-graph` are off as well as the
  two the charter names.
- An empty `current-input-port` during a load, because stdin is the
  request stream.
- Any raised value except a break counts as a failed load.
- A test-only `host-binding-interface` submodule, to show `eq?` directly
  (§4).

## 13. Accepted consequences

- Without `tui-term`, the `gel/` row fails to load and `gel/main.aloe`
  stays a miss. Each request tries the load again. `tui-term` is not
  added to `info.rkt`'s deps.
- While a document's row fails, positions that answer today also miss.
  `from-string` in `(Text from-string "")` is one.
- A host module loads once per server process. An edit to its Racket
  source needs a server restart, such as Reload Window. A manifest edit
  takes effect on the next request.
- A failing row and a broken manifest say nothing. There is no
  diagnostic, and the reason is not written anywhere. Tests read the
  reason from the reader.
- A manifest that uses a later grammar counts as broken under this
  spec (§6.9).
- A row is matched by the exact file name. On a case-insensitive
  filesystem, `Main.aloe` in a row does not match `main.aloe`.
- A row for a base library loads its hosts, and the query ignores them.
  A failing row there is still a miss.
- Trust stops at installed code. Any installed package that adds a
  module to the `host/racket` collection can be named by a manifest.
- A type error anywhere in a configured file still turns hover and
  definition off for the whole file (definition §9).

## 14. Non-goals

- Partial checking that answers for the forms before the first error
- Edits to the closed expression-query, completion, definition, LSP,
  signatures-of-type, or VS Code spec files
- Runners reading the manifest, a factory element, or any change to
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
- The `tests/aloemacs/window-pictures.rkt` timing bar. It is a separate
  project
- `CHECKPOINTS.md` and `docs/checkpoints/`

## 15. Documents

Each checkpoint updates this folder's `README.md` file table and
status, and project 9's cell in [`../README.md`](../README.md). No
checkpoint edits `SPEC.md` or the closed editor specs named in §3.

When the implementation satisfies this specification, stop. The
checkpoint manager decides the slices. It writes one checkpoint, then
stops.
