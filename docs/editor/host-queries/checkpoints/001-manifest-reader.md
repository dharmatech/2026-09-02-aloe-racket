# Editor host-queries 001 — The manifest reader

**Status.** Written 2026-10-16 by the checkpoint manager from
[`../spec.md`](../spec.md) (reviewed, `80b46fd`). Implemented
2026-10-16. Manager-reviewed 2026-10-16 against this document:
conforming. The `aloe/` file count under Depends on and in test 7 was
corrected after implementation: 20 files, not 21. The scratch copy that
gave 21 already held the prototype reader. Accepted by the human
2026-10-17. If you have been told to read this file, it is the whole
assignment.

## Goal

Layer 2 of the spec, first part. The spec lets the manager split layer 2
at the reader/server seam (spec §2), and this checkpoint is the reader
side of that split.

Add `aloe/host-manifest.rkt`, a module with one job. Given a document
path, it finds the file `aloe-hosts.rktd` in the document's folder,
reads it as data without evaluating anything, and finds the row for
that document. It then loads each named host module from the
`host/racket` collection and returns the binding names paired with the
exported interfaces. Those pairs are the `#:hosts` value that
editor-host-queries 000 taught the three queries to accept.

This checkpoint also writes the effects rule for host modules into a
new `host/racket/README.md`. It adds a test that loads every module in
`host/racket/` and checks that nothing is printed, and a test that
proves no module under `aloe/` imports anything under `host/racket/`.

The language server does not change. Nothing calls the reader except its
own tests. Editor-host-queries 002 makes `aloe/lsp.rkt` call it, checks
in the two product manifests, and carries the VS Code hand check.

The implementer receives only this document. Every rule for this slice
is below.

## Depends on, identity

Identity is `(editor-host-queries, 001)`, spoken **editor-host-queries
001**. It is a local editor checkpoint. Do not edit `CHECKPOINTS.md` or
add a file under `docs/checkpoints/`. Branch:
`experiment/2026-10-16-host-queries`.

The tree at `7a93158` has every predecessor. As found:

- **Editor-host-queries 000** (`7a93158`). `query-expression-at`,
  `query-definition-at`, and `query-selector-completions` take
  `#:hosts`, a list of `(cons symbol host-interface)` with distinct
  names. Its tests live in `tests/editor/host-queries/000-query-hosts.rkt`,
  with four fixtures in `tests/editor/host-queries/fixtures/configured/`:
  `spot.aloe`, `reads-fs.aloe`, `uses-fs.aloe`, and
  `defines-fs-host.aloe`.
- **Host interfaces.** `aloe/host.rkt` exports `host-interface?`. An
  interface is opaque and nominal: two host types are equal only when
  their interfaces are `eq?`. `host/racket/fs.rkt` exports
  `fs-interface` and `make-fs-receiver` (a procedure).
  `host/racket/term.rkt` exports `term-interface`. It requires
  `tui/term`, from the optional `tui-term` package, which is installed
  on the development machine. Existing suite tests already load it.
- **Collection paths.** The repository is a linked multi-collection
  package, so the module path `host/racket/fs` resolves to
  `host/racket/fs.rkt` in this repository from any current directory.
  The same file loaded by its relative path in a test and by
  `host/racket/fs` through the module name resolver is one module
  instance, with one `fs-interface`.
- **Host modules.** `host/racket/` holds seven `.rkt` files:
  `aloemacs-run.rkt`, `fs-repl.rkt`, `fs.rkt`, `gel-run.rkt`,
  `read-key-spike.rkt`, `term-run.rkt`, and `term.rkt`. Each loads in a
  fresh namespace with nothing written to stdout or stderr. Their effects
  live in `main` submodules or in procedures a caller invokes. There is
  no `README.md` in that folder.
- **`aloe/`** holds 20 `.rkt` files, counting `aloe/private/`. None
  imports anything under `host/racket/`. Within `aloe/`, the import
  closure of `aloe/lsp.rkt` does not contain `aloe/driver.rkt`.

## Authority

- `SPEC.md` is law and is not amended.
- [`docs/editor/host-queries/spec.md`](../spec.md) §6 (the manifest),
  §8.2 (the effects rule), §9.2 (fixtures), and §10.2 (coverage) are the
  design of this checkpoint. Spec §2 allows the split. Every rule you
  need is restated below.
- The spec's §7 (the language server), §8.1 (the product manifests), the
  `broken/` fixture folder of §9.2, §10.3, and §11 belong to
  editor-host-queries 002.

## Required behavior

### 1. The module

`aloe/host-manifest.rkt` is new. It is the only module under `aloe/`
that loads a host module. It provides exactly:

```racket
(provide host-manifest-name               ; "aloe-hosts.rktd"
         (struct-out document-hosts)          ; (bindings)
         (struct-out document-hosts-failure)  ; (reason)
         read-document-hosts)

(struct document-hosts (bindings) #:transparent)
(struct document-hosts-failure (reason) #:transparent)

(read-document-hosts document-path #:loader [loader <default loader>])
  ; document-path : path-string?
  ; loader        : a procedure that accepts three arguments
  ; -> (or/c #f document-hosts? document-hosts-failure?)
```

It requires `host-interface?` from `"host.rkt"`, and Racket libraries.
It does not require the parser, the checker, `aloe/main.rkt`, the
queries, `aloe/driver.rkt`, or anything under `host/racket/`.

It raises only for its own arguments, both with `raise-argument-error`
and who `'read-document-hosts`:

| Argument | Check | Expected text |
|---|---|---|
| `document-path` | `path-string?` | `"path-string?"` |
| `loader` | a procedure, and `(procedure-arity-includes? loader 3)` | `"(procedure-arity-includes/c 3)"` |

Nothing a manifest or a module does makes it raise. It keeps no state
between calls: no cache and no file watching. It reads the manifest on
every call, so an edit takes effect on the next call.

### 2. Finding the manifest and the row

Normalize the document path with
`(simplify-path (path->complete-path document-path) #f)`, without
touching the filesystem. The manifest is the file named
`aloe-hosts.rktd` in that path's folder. Look nowhere else: no
parent-folder search, no workspace scan, and no glob rows. The document
itself need not exist.

A row matches when `(string->path-element NAME)` is `equal?` to the
normalized path's file name. The match is exact and case-sensitive.
The key is always the document path. A sibling such as
`aloe-lsp-snapshot-123` matches no row. Only the queried document's row
applies. No other row is read for loading.

### 3. Reading

Open the manifest and call Racket `read` once, with these four
parameters set to `#f`: `read-accept-reader`, `read-accept-lang`,
`read-accept-compiled`, and `read-accept-graph`. Leave every other
reader parameter at its default. A second `read` on the same port must
return `eof`. Comments are allowed. A `#lang` or `#reader` line,
compiled code, and graph notation such as `#0=` are read errors.
Nothing is evaluated.

### 4. Shape

```text
manifest ::= ( row ... )
row      ::= ( file NAME entry entry ... )
entry    ::= ( host BINDING MODULE EXPORT )
```

- The manifest is a proper list of rows. It may be empty.
- A row is a proper list: the symbol `file`, then `NAME`, then at least
  one entry.
- `NAME` is a string of at least one character that contains no `/`, no
  `\`, and no NUL character, and is neither `"."` nor `".."`.
- An entry is a proper list of exactly four elements: the symbol `host`,
  then `BINDING`, `MODULE`, and `EXPORT`. `BINDING` and `EXPORT` are
  symbols. `MODULE` may be any datum here. Only Required behavior §6 judges it, so
  a bad module path fails one row, not the whole manifest.
- No two rows have the same `NAME` (`string=?`).

A manifest outside this shape is **broken**. So is a manifest that
cannot be opened or read, including a directory named `aloe-hosts.rktd`.
A broken manifest counts as absent: `read-document-hosts` returns `#f`
for every document in its folder, and calls no loader. A broken manifest
cannot say which documents it configures, so it configures none.

### 5. Checking the matched row

When the manifest is absent or broken, or well-formed with no row for
the document, the result is `#f`. Otherwise the reader checks the
document's row in this order, and the first failure is the result:

1. Two entries share a `BINDING` (`eq?`): `(document-hosts-failure 'duplicate-name)`.
2. Any entry's `MODULE` fails Required behavior §6: `(document-hosts-failure 'module-path)`.
3. Entry by entry, in row order, the loader (Required behavior §7): a failed load is
   `(document-hosts-failure 'load)`, and a missing or wrong export is
   `(document-hosts-failure 'export)`. A failing entry stops the walk.
   Later entries are not loaded.

So a row that fails at step 1 or 2 calls no loader, and no module loads
unless the document's own row names it. When every entry loads, the
result is `(document-hosts bindings)`, where `bindings` holds
`(cons BINDING interface)` in row order.

A failing row is all or nothing. There are exactly four reasons:
`'duplicate-name`, `'module-path`, `'load`, and `'export`.

### 6. The module boundary

`MODULE` passes when it is a symbol whose name matches:

```text
^host/racket/[a-z0-9_-]+$
```

That is the `host/racket` collection with exactly one segment after it,
written in lowercase ASCII letters, digits, `_`, and `-`. Every other
`MODULE` is rejected before anything loads:

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
Under this rule, a manifest can make the reader load only a module
already installed in the `host/racket` collection, never a file from
the workspace.

### 7. Loading an entry

For each entry, the reader calls `(loader MODULE EXPORT missing)`, where
`missing` is a thunk of no arguments that returns a value private to the
reader. While the loader runs:

- `current-output-port` and `current-error-port` are ports that discard
  their output (`open-output-nowhere`), and
- `current-input-port` is an empty port, such as
  `(open-input-bytes #"")`.

The language server's stdout is its LSP frame stream, and its stdin is
the request stream. A host module that broke the effects rule (Required behavior §8) still
cannot write a byte to the first or take a byte from the second.

The loader's outcomes:

| Outcome | Meaning |
|---|---|
| It raises any value that is not a break (`exn:break?`) | `'load` |
| It returns the value of `missing` | `'export` (the export is missing) |
| It returns a value that is not `host-interface?` | `'export` (not an interface) |
| It returns an interface | that entry's interface |

A break raised during the load is not caught.

**The default loader** calls `(dynamic-require MODULE EXPORT missing)`
with `current-namespace` set to a namespace made by
`namespace-anchor->empty-namespace` from a
`(define-namespace-anchor …)` in the reader module. That namespace is
empty, but it shares the caller's module registry. So the host module
and the reader share one instance of `aloe/host.rkt`,
`host-interface?` holds, and the interface is the same value a test
gets by requiring `host/racket/fs.rkt` itself. Do not load into a fresh
registry, and do not depend on the caller's `current-namespace`. The
module's `main` submodule never runs. A module loads once per process
through the registry, and later calls find it already instantiated.

**The test-only allowance.** `#:loader` is the one test seam. Tests
need a loader that counts calls, one that prints and reads, and ones
that raise. Production never passes `#:loader`. Add no printing module
anywhere for this.

### 8. The effects rule

Add `host/racket/README.md`, where an author of a new host module will
see it. It says at least:

- Every module in `host/racket/` has a definition-only top level.
  Loading a module must not print, read standard input, open a TTY,
  touch the filesystem, or start a loop. Effects live in `main`
  submodules or in procedures a caller invokes.
- Why: the Aloe language server loads a module from this folder when an
  `aloe-hosts.rktd` manifest names it, to read the exported interface.
  The server's stdout is its LSP frame stream, and its stdin is the
  request stream.
- A test loads every module in the folder and checks that nothing is
  written: `tests/editor/host-queries/001-manifest-reader.rkt`.

Keep it short, in the plain style of the repository's other READMEs.
The README is the only file added under `host/racket/`. No `.rkt` file
there changes.

## Exact file scope

May edit:

- `aloe/host-manifest.rkt` (new)
- `host/racket/README.md` (new)
- `tests/editor/host-queries/001-manifest-reader.rkt` (new)
- `tests/editor/host-queries/fixtures/configured/aloe-hosts.rktd` and
  `tests/editor/host-queries/fixtures/configured/failing.aloe` (new)
- `docs/editor/host-queries/README.md` and `docs/editor/README.md`, for
  the status lines under Acceptance

Do not edit:

- any existing module under `aloe/`, including `aloe/lsp.rkt`,
  `aloe/host.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`, and the three
  query modules
- any `.rkt` file in `host/racket/`, `examples/`, `gel/`, `lib/`, or
  `editors/vscode/`
- any existing test or fixture
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or any spec,
  charter, or checkpoint document, this one included

Do not add `examples/aloemacs/aloe-hosts.rktd`, `gel/aloe-hosts.rktd`,
or a `tests/editor/host-queries/fixtures/broken/` folder. Those are
editor-host-queries 002.

If an existing test fails, or the slice seems to need a file outside
this list, stop and report it.

## Fixtures

Add two files to `tests/editor/host-queries/fixtures/configured/`. Each
is ASCII with one LF after every line. Editor-host-queries 002 reuses
them unchanged.

`failing.aloe` (33 bytes):

```aloe
(define there (fs-host current))
```

`aloe-hosts.rktd` (144 bytes):

```racket
((file "uses-fs.aloe"
   (host fs-host host/racket/fs fs-interface))
 (file "failing.aloe"
   (host fs-host host/racket/fs no-such-interface)))
```

`tests/modules/001-census.rkt` makes one test case for every `.aloe`
file under `tests/`, and it allows `fs-host` as a free name. So
`failing.aloe` adds one census case to the whole suite. The `.rktd` file
adds none.

## Required tests

Add `tests/editor/host-queries/001-manifest-reader.rkt`. It is three
directories below the repository root. Require:

- `"../../../aloe/host-manifest.rkt"`
- `"../../../host/racket/fs.rkt"` and `"../../../host/racket/term.rkt"`,
  by relative path, as the existing suite does
- `syntax/modcode` for `get-module-code`, plus `racket/file`,
  `racket/list`, `racket/path`, `racket/port`, `racket/runtime-path`,
  `racket/string`, and `rackunit` as needed

Do not require `aloe/main.rkt`, the checker, or the queries. Use
`define-runtime-path` for the repository root (`"../../.."`), the
`configured` fixture folder, and `aloe/host-manifest.rkt`. Simplify the
root with `(simplify-path (path->complete-path root))`.

Every temporary manifest goes in a fresh directory made under
`(find-system-path 'temp-dir)`, for example with
`(make-temporary-file "host-queries-001-~a" 'directory)`, and is
removed unconditionally (`dynamic-wind`). A document path in a
temporary folder need not exist as a file.

Two test loaders recur below:

- a **counting loader** records each `(list MODULE EXPORT)` it is called
  with and returns `fs-interface`;
- **the manifest** `M` is
  `((file "main.aloe" (host fs-host host/racket/fs fs-interface)))`.

"The result is `(document-hosts (list (cons 'fs-host fs-interface)))`"
means `check-equal?` against that value. Interfaces are opaque, so
`equal?` on them is `eq?`.

Write one `test-case` per numbered item below, nine in all. The names
are yours.

### 1. Surface and arguments

- `host-manifest-name` is `"aloe-hosts.rktd"`.
- The phase-0 exports of `aloe/host-manifest.rkt`, from
  `module->exports`, are exactly these. Values:
  `document-hosts-bindings`, `document-hosts-failure-reason`,
  `document-hosts-failure?`, `document-hosts?`, `host-manifest-name`,
  `struct:document-hosts`, `struct:document-hosts-failure`. Syntax:
  `document-hosts`, `document-hosts-failure`, `read-document-hosts`.
  (A procedure with keyword arguments is exported as syntax.)
- `(read-document-hosts 3)`, a loader of two arguments, and the loader
  `'nope` each raise `exn:fail:contract?` whose message starts with
  `read-document-hosts: `.

### 2. Matching

In a temporary folder, with the counting loader:

- With no manifest in the folder, `main.aloe` gives `#f`.
- After writing `M` as `aloe-hosts.rktd`: `main.aloe` gives
  `(document-hosts (list (cons 'fs-host fs-interface)))`. `other.aloe`,
  `Main.aloe`, and `aloe-lsp-snapshot-123` give `#f`.
- `<folder>/sub/../main.aloe` matches, since normalization does not
  touch the filesystem. With `current-directory` set to the folder, the
  relative path `"main.aloe"` matches.
- Rewriting the manifest to name `"other.aloe"` instead makes the next
  call for `main.aloe` give `#f` and for `other.aloe` succeed. Rewriting
  it to `()` makes `other.aloe` give `#f`.

### 3. Broken manifests

Write each text below as the whole manifest in its own temporary
folder. Each gives `#f` for the named document and for
`neighbor.aloe`, and the counting loader is never called. Below, `R` is
`(file "main.aloe" (host fs-host host/racket/fs fs-interface))`, the
one row of `M`.

| Text | Named document | Why |
|---|---|---|
| `((file "main.aloe" (host fs-host host/racket/fs fs-interface))` | `main.aloe` | unparseable |
| `#lang racket/base` | `main.aloe` | `#lang` is not accepted |
| `() ()` | `main.aloe` | a second datum |
| `(file "main.aloe" (host fs-host host/racket/fs fs-interface))` | `main.aloe` | not a list of rows |
| `((file "main.aloe"))` | `main.aloe` | a row with no entry |
| `((file main.aloe (host fs-host host/racket/fs fs-interface)))` | `main.aloe` | `NAME` is a symbol |
| `((file "../main.aloe" (host fs-host host/racket/fs fs-interface)))` | `main.aloe` | `NAME` contains `/` |
| `((file "main.aloe" (host fs-host host/racket/fs)))` | `main.aloe` | an entry of three |
| `((file "main.aloe" (hosts fs-host host/racket/fs fs-interface)))` | `main.aloe` | wrong entry head |
| `((file "main.aloe" (host "fs-host" host/racket/fs fs-interface)))` | `main.aloe` | `BINDING` is a string |
| `((file "main.aloe" (host fs-host host/racket/fs fs-interface (receiver make-fs-receiver))))` | `main.aloe` | a fifth element |
| `((file "a.aloe" (host fs-host host/racket/fs fs-interface)) (file "a.aloe" (host term host/racket/term term-interface)))` | `a.aloe` | a repeated `NAME` |
| `#0=(R)` | `main.aloe` | graph notation |
| `#reader racket/base (R)` | `main.aloe` | `#reader` is not accepted |
| `(R (file "" (host term host/racket/term term-interface)))` | `main.aloe` | an empty `NAME` |
| `(R (file "." (host term host/racket/term term-interface)))` | `main.aloe` | `NAME` is `.` |
| `(R (file ".." (host term host/racket/term term-interface)))` | `main.aloe` | `NAME` is `..` |
| `(R (file "a\\b" (host term host/racket/term term-interface)))` | `main.aloe` | `NAME` contains `\` |
| `(R (file "a\0b" (host term host/racket/term term-interface)))` | `main.aloe` | `NAME` contains NUL (`\0` is the reader's escape) |

The last seven texts hold a valid row for `main.aloe`. Each still gives
`#f` for it, because the whole manifest is broken. Write `R` out in the
test. These texts contain backslashes, so build them in Racket with
care: the manifest file itself must contain `"a\\b"` and `"a\0b"` as
written above.

Also, a **directory** named `aloe-hosts.rktd` gives `#f` for
`main.aloe`, and the counting loader is never called.

### 4. Failing rows

Each case writes a one-row manifest for `main.aloe` with the entries
given, and queries `main.aloe`.

- Entries `(host fs-host host/racket/fs fs-interface)` and
  `(host fs-host host/racket/term term-interface)`: `'duplicate-name`.
  Entries `(host fs-host host/racket/fs fs-interface)` and
  `(host fs-host racket/base term-interface)`: also `'duplicate-name`,
  because names are checked before module paths. The counting loader is
  never called.
- For every `MODULE` in Required behavior §6's table, written with `~s` into
  `(host fs-host MODULE fs-interface)`: that entry alone gives
  `'module-path`. The same entry after a good entry
  `(host term host/racket/term term-interface)` also gives
  `'module-path`. The counting loader is never called in either case.
- With entry `(host fs-host host/racket/fs fs-interface)`: a loader
  that raises an `exn:fail` gives `'load`; a loader that does
  `(raise 'boom)` gives `'load`; a loader that returns `(missing)` gives
  `'export`; a loader that returns `42` gives `'export`.
- With entries `(host fs-host host/racket/fs fs-interface)` and
  `(host term host/racket/term term-interface)`, a loader that counts
  its calls and raises gives `'load`, and it was called once.
- With the default loader: `(host fs-host host/racket/no-such-module fs-interface)`
  gives `'load`. `(host fs-host host/racket/fs no-such-interface)` and
  `(host fs-host host/racket/fs make-fs-receiver)` give `'export`.

### 5. Success

With the default loader and the `configured` fixture folder:

- `uses-fs.aloe` gives
  `(document-hosts (list (cons 'fs-host fs-interface)))`, and the
  interface is `eq?` to `fs-interface`.
- `failing.aloe` gives `(document-hosts-failure 'export)`.
- `spot.aloe` and `reads-fs.aloe` give `#f`: no row.

With the default loader, a temporary one-row manifest for `main.aloe`
with entries `(host fs-host host/racket/fs fs-interface)` and
`(host term host/racket/term term-interface)` gives both bindings, in
that order, each `eq?` to the interface.

With the counting loader, `uses-fs.aloe` in the `configured` folder
calls it exactly once, with `host/racket/fs` and `fs-interface`.
`failing.aloe`'s entry is not loaded.

### 6. Capture

The test parameterizes its own `current-output-port` and
`current-error-port` to string ports, and `current-input-port` to
`(open-input-bytes #"held")`, around a call with `M` and a loader that:

- writes `"loading"` to `current-output-port` and to
  `current-error-port`,
- reads one byte from `current-input-port` and keeps it, and
- returns `fs-interface`.

The result is `(document-hosts (list (cons 'fs-host fs-interface)))`.
The test's output and error ports stay empty. The byte the loader read
is `eof`. The test's input port still gives `#"held"` to
`(read-bytes 4 in)`.

### 7. Static requires

Collect every `.rkt` file under `aloe/`, recursively, skipping any
directory named `compiled`. On the found tree that is 20 files plus
`aloe/host-manifest.rkt`. Check that the list contains
`aloe/host-manifest.rkt` and `aloe/private/checker-observation.rkt`.

For each file, take its compiled code with `get-module-code` from
`syntax/modcode`. Then walk that code and each of its submodules,
recursively, with both `(module-compiled-submodules code #t)` and
`(module-compiled-submodules code #f)`. For every import that
`module-compiled-imports` lists, at every phase, call
`module-path-index-resolve` and take `resolved-module-path-name`. A
name that is a list (a submodule) stands for its first element. A name
that is a symbol is a primitive module such as `#%kernel`, or the
module's own name in a submodule's reference to its enclosing module.
Symbols are allowed.

**Resolve relative to the file.** Code from `get-module-code` has an
unresolved self. `module-path-index-resolve` resolves a relative import
such as `"expression-query.rkt"` against `current-load-relative-directory`,
or the current directory when that is `#f`. So walk each file's code
with `current-load-relative-directory` set to the file's own folder
(`path-only`). Without that, `aloe/lsp.rkt`'s imports resolve under the
repository root instead of `aloe/`, and the test passes for the wrong
reason. The scratch run below hit this.

Then check, with path comparisons by element (`explode-path`), not by
string prefix:

- Every import path of every file is under `aloe/` or outside the
  repository root. None is under `host/racket/`.
- `aloe/lsp.rkt`'s imports include `aloe/expression-query.rkt`. This is
  the self-check that relative imports resolved in the right folder.
- `aloe/host-manifest.rkt`'s imports that are inside the repository are
  exactly `aloe/host.rkt`.
- The closure of `aloe/lsp.rkt` over imports under `aloe/` contains
  `aloe/main.rkt` and does not contain `aloe/driver.rkt`.
- **Self-check.** In a fresh `(make-base-namespace)`, `compile` this
  in-memory module:

  ```racket
  (module self-check racket/base
    (module* host-user #f
      (require host/racket/fs)))
  ```

  The same walk over its compiled code reports
  `host/racket/fs.rkt` under the repository root.

This proves that `raco make aloe/lsp.rkt` compiles no host module.

### 8. Source

`aloe/main.rkt`, `aloe/expression-query.rkt`,
`aloe/definition-query.rkt`, `aloe/completion-query.rkt`, and
`aloe/host-manifest.rkt` contain neither the substring
`make-host-receiver` nor `driver-inject-host!`.

### 9. Effects census

List the `.rkt` files directly in `host/racket/` from the directory
(`directory-list`), not from a stored list. There are at least seven.
Load each one with `(dynamic-require path #f)` in a **fresh**
`(make-base-namespace)`, while `current-output-port` and
`current-error-port` are string ports. Both stay empty for every file.

The fresh namespace matters. This test file requires `fs.rkt` and
`term.rkt` itself, so in its own namespace they are already
instantiated, and loading them again would run nothing.

**Self-check.** Write a temporary file `printing.rkt` holding
`#lang racket/base` and `(display "loaded")`, in a temporary directory
outside the repository. Load it once in the test's own namespace,
discarding its output. Then the census's loading procedure, run on it,
reports `"loaded"`.

This test needs `tui-term`, as existing suite tests already do. Modules
in `host/racket/` that no test requires may have no compiled `.zo`.
They then compile in memory, and the scratch run below found that
fast (under half a second each).

## Scratch run

On 2026-10-16 a prototype of this checkpoint was applied to a copy of
the tree at `7a93158`, with every `compiled/` folder removed first and
`PLTCOLLECTS` pointed at the copy so that `host/racket/fs` resolved
there. The prototype reader was about 120 lines. Then:

- A prototype test file with these nine test cases passed in about one
  second.
- Each of these mutations failed exactly one test case: allowing graph
  notation; not discarding output during a load; a
  `(module* … (require host/racket/term))` added to an `aloe/` module;
  resolving imports without `current-load-relative-directory`; and
  running the census in the test's own namespace.
- With the two fixtures in place and no existing test edited, the whole
  suite ran 3085 tests under `-j 4`: the 3075 of `7a93158`, the nine new
  test cases, and one census case for `failing.aloe`. No file crashed.
  The one failure was `tests/editor/lsp/009-launch.rkt`'s package-link
  case, caused only by the scratch run's `PLTCOLLECTS` override: `raco
  pkg install` refuses to link a folder that is also a collection path.
  Run alone without the override, that file passed 6 of 6. In the real
  repository, with no override, nothing of the kind applies.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/host-queries/001-manifest-reader.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

All green. The whole suite is 3085 tests: 3075, the 9 new test
cases, and 1 modules-census case for `failing.aloe`. No existing test
changes. If only `tests/aloemacs/window-pictures.rkt`'s 30 ms
timing bar fails under `-j 4`, run that file alone, and it must pass
there.

There is no hand check for this checkpoint. Nothing calls the reader
outside its tests until editor-host-queries 002.

Update the status lines:

- In `docs/editor/host-queries/README.md`, add a file-table row for
  `checkpoints/001-manifest-reader.md`: "Implemented *date*, awaiting
  review", with the focused test count and the whole-suite count. Set
  the status paragraph to say editor-host-queries 001 is implemented
  and awaiting review.
- In `docs/editor/README.md`, update project 9's cell and the project-9
  sentence below the table to say editor-host-queries 001 is
  implemented and awaiting review.

Stop for review without committing. Do not write or start the next
checkpoint.

## Explicit non-goals

- Any change to `aloe/lsp.rkt`, its tests, or `editors/vscode/`; the
  server calling the reader (editor-host-queries 002)
- The product manifests `examples/aloemacs/aloe-hosts.rktd` and
  `gel/aloe-hosts.rktd`, and the `broken/` fixture folder (002)
- Runners reading the manifest, a factory element, or any change to
  `aloemacs-run.rkt`, `gel-run.rkt`, or `driver-inject-host!`
- Constructing a receiver or calling a host implementation
- A module outside the `host/racket` collection, a module from the
  workspace, or a submodule
- A parent-folder search, a workspace scan, several manifests in one
  folder, glob rows, or rows applied to loaded files
- Caching the manifest, watching files, or reloading a host module
- Diagnostics or any record of why a manifest or row failed, beyond the
  reason in `document-hosts-failure`
- Adding `tui-term` to `info.rkt`'s deps
- A printing module, or any other new `.rkt` file, under `host/racket/`
