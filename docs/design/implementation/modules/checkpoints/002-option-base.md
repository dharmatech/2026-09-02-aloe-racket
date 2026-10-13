# modules 002 — `Option` on the base

**Status: Ready to implement. Amended 2026-10-13** after the
implementer's first suite run: case 6 expects the parser's rejection
of `(Some "x")`; `tests/aloemacs/runner.rkt` line 197 loses `Option`
too; `tests/editor/lsp/008-adapter-failures.rkt` line 139 joins the
stub table. Human review of this checkpoint precedes its
implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

`lib/option.aloe` becomes a base library, installed beside the list,
string, and int libraries in every default environment. `String find`
returns that class, read from the base, never by looking up the name
`Option`. Every `(load ".../option.aloe")` is a hit of the installed
entry.

An editor query of one of the four base library files installs that
library from the buffer instead of checking it a second time on top
of the installed copy. `query-expression-at` gains `#:document-path`,
and the LSP adapter passes it when it queries through a sibling
snapshot.

Visible results:

- a fresh driver binds `Option` (not `Some` or `None`) with no load;
- `("abc" find "b" 0)` works in a fresh driver;
- after the prompt defines its own `Option`, `find` still returns the
  base class;
- hover inside `lib/list.aloe` resolves (today it raises
  `ambiguous message: fold`);
- completion inside `lib/string.aloe` lists `starts-with?` once
  (today twice).

This is slice 3a of the spec, the third checkpoint. Stop when the
focused proof and the whole suite pass. Do not start slice 3b.

## Authority, identity, and starting point

- Identity: **modules 002**, filed as
  `docs/design/implementation/modules/checkpoints/002-option-base.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. Evaluation
  is send with a literal selector. Function objects run only through
  `call`. No inheritance, mutation, macros, implicit Int/Float
  coercion, or new special forms.
- Predecessors, both committed:
  - **modules 000** (`5d435a5`). Each base has a checker load cache and
    an evaluator load cache, keyed by resolved path. A second load of
    the same bytes is a hit; different bytes are
    `typecheck: load file changed: <displayed path>; this version does not reload a changed file`.
    The list, string, and int installs are recorded as completed
    entries (seeds). The rules live in `typecheck-once!` and
    `typecheck-keyed-root` in `aloe/type.rkt` (hooks in its
    `load-cache` submodule) and `eval-once!`, `eval-keyed-root`, and
    `record-evaluated-libraries!` in `aloe/eval.rkt`.
    `aloe/library.rkt` reads each library once into bytes and exports
    its expressions, bytes, and resolved path, plus
    `resolved-source-path` and `displayed-path`.
  - **modules 001** (`efe39e7`). Every census file loads what it
    names. `tests/modules/001-census.rkt` checks that. `Option` is
    not counted there; this slice makes it a base name.
- [../spec.md](../spec.md) governs. This checkpoint is its §6.1:
  - §2: base, keyed root, resolved path, displayed path, cache,
    entry, exports.
  - §6.1: this slice in full.
  - §12, row 3a: the `SPEC.md` and `docs/decisions.md` text.
  - §3: the out-of-scope list.
- One environment is still shared. A program's definitions, a load's
  definitions, and the base libraries all live in one environment
  object until slice 3e. A prompt `define-class Option` therefore
  replaces the binding `Option` in that object. The base's
  installed class survives in the new field (§2 below), which is
  what `find` reads.

### The tree at issuance

The manager probed today's tree on 2026-10-13:

- `String find` builds its result type with
  `(type-from-sexpr '(Option Int) environment ...)` in
  `aloe/type.rkt` (search `[(find)`), and constructs its result with
  `(env-lookup environment 'Option)` in `aloe/eval.rkt`. With no
  `Option` bound, the checker raises `typecheck: unbound symbol: Option`
  and the evaluator `eval-aloe: unbound symbol: Option`.
- `query-expression-at` (in `aloe/expression-query.rkt`, 58 lines)
  reads the file at its normalized path and calls
  `typecheck-program/observe` on a fresh `make-type-environment` from
  `aloe/main.rkt`. `query-selector-completions` (in
  `aloe/completion-query.rkt`) does the same with
  `typecheck-program/observe-selector-receiver` on the expressions of
  `source`. Both observed checks enter `typecheck-program` at depth
  zero, so each is a root check.
- In `aloe/lsp.rkt`, `query-synchronized-document` calls
  `invoke-query` on the document path when the buffer matches disk,
  and otherwise `query-through-snapshot`, which writes a sibling with
  `make-temporary-file` in the document's directory and calls
  `invoke-query` on the sibling. `invoke-query` turns any `exn:fail`
  into `#f`, which becomes a null hover. So a test stub that does not
  accept a keyword the adapter passes fails quietly as null.
- Hover inside `lib/list.aloe` on `self` in `(self empty?)` raises
  `typecheck: ambiguous message: fold`. Hover inside
  `lib/option.aloe` on `self` in `(self case` gives `(Option T)`.
  Completion inside `lib/string.aloe` on a String receiver lists
  `starts-with?` twice.
- A prototype that installed the string, int, and option libraries
  into a raw checker environment and then observed `lib/list.aloe`'s
  expressions resolved `(List T)`.

The manager also installed `lib/option.aloe` in all four default
environments on a scratch copy and ran the whole suite. Twelve
assertions failed, in twelve files, all of them "a fresh driver
binds none of these names" lists that include `Option` (the
**Migration** table below). The spec named only
`tests/checkpoint-100.rkt`. With the migration applied, the twelve
files passed. Adding `#:document-path` to the adapter's snapshot call
in a second scratch run failed eight test stubs in four LSP files
(also in **Migration**); the spec named two of those files. That
second run under-counted: five LSP test files (`004`–`008`) crashed at
load with `instantiate-linklet: mismatch` (stale bytecode after the
signature change) and ran no tests. The implementer's run found the
ninth stub, in `008-adapter-failures.rkt`, which this amendment adds.

### Size

The largest slice so far, but each part is small: a field and an
install in the base constructors, two `find` branches, a
query-base rule in the two query modules, one keyword in the
adapter, five document edits, and mechanical test migrations. The
spec keeps the editor query with the install on purpose (§6.1). If it
does not fit one conversation, stop and report; the manager may then
split the editor query into its own checkpoint, keeping the order.

## Exact file scope

### May create or edit

- `aloe/library.rkt`: the `lib/option.aloe` promise, bytes, and
  resolved path, as for the other three.
- `aloe/env.rkt`, `aloe/type.rkt`: the base `Option` field and its
  propagation; in `aloe/type.rkt` also checker `find`, the option
  seed, and any hook the queries need, exposed through a `module*`
  submodule, not the main `provide`.
- `aloe/eval.rkt`: evaluator `find` and the option seed.
- `aloe/main.rkt`, `aloe/driver.rkt`: the install at the four sites.
  `aloe/main.rkt` may also expose a query-base procedure through a
  `module*` submodule. The main `provide` lists of both modules do not
  change.
- `aloe/expression-query.rkt`, `aloe/completion-query.rkt`: the
  base-library rule; `#:document-path` on `query-expression-at`.
- `aloe/lsp.rkt`: pass `#:document-path` through a snapshot.
- `SPEC.md`, `docs/decisions.md`: only the text in **Language law**.
- `docs/editor/lsp/spec.md`, `docs/editor/expression-query/spec.md`,
  `docs/editor/completion/spec.md`: only the text in **Editor
  documents**.
- `tests/modules/002-option-base.rkt`: new.
- The existing tests in **Migration**, and only the lines it names.

### Must leave untouched

- Every `.aloe` file. In particular `lib/text.aloe`, `lib/fs.aloe`,
  and `lib/disk.aloe` keep `(load "option.aloe")`, and no file gains
  a load of `lib/option.aloe`.
- `aloe/parse.rkt`, everything under `aloe/private/`, and
  `host/racket/`.
- `tests/modules/000-run-once.rkt` and `tests/modules/001-census.rkt`.
  The census still skips `Option` by name; leave it.
- Every other existing test, and the parts of the migrated tests the
  table does not name.
- `CHECKPOINTS.md`, `docs/checkpoints/`, `docs/philosophy.md`, this
  folder's `README.md`, `charter.md`, `spec.md`, this checkpoint, and
  every other design document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. The install

- `aloe/library.rkt` reads `lib/option.aloe` through the same
  read-once promise as the other three and exports its expressions,
  its bytes, and its resolved path, named like theirs.
- `make-driver`, `make-type-environment` and `make-top-level-env` in
  `aloe/main.rkt`, and the `type-environment-for` fallback install it
  after `lib/int.aloe`, in each half that site builds: the checker
  through `typecheck-program`, the evaluator through `eval-exprs`, as
  the other three are installed.
- Each site then records it as a completed entry under its resolved
  path, beside the other three seeds: a checker entry with the bytes
  the install parsed, an evaluator entry, and `(Option)` as the
  exports of both. (Exports stay unread until slice 3e; the other
  three seeds keep `'()`.)
- The raw constructors (`make-type-environment` in `aloe/type.rkt`,
  `make-top-level-env` in `aloe/env.rkt`) install nothing and record
  nothing. No other library is added.

### 2. The base's `Option`

- Each base keeps the installed `Option` class in a field beside
  `int-class` and `string-class`: in `type-environment` (the checker's
  class record) and in `top-level-env` (the evaluator's class value).
  The class only exists after the install, so make the field a box
  (or another mutable cell) created by the raw constructor, shared by
  reference with every child environment the way the load cache is,
  and set once by each install site right after the `Option` install,
  from the base's own `Option` binding in that half.
- In a raw environment the field stays empty.
- Nothing else reads the field in this slice.

### 3. `String find`

- The checker's `find` returns `(Option Int)` built from the field's
  class record with `Int` as its argument, not from
  `type-from-sexpr` of the name.
- The evaluator's `find` constructs `Some` and `None` from the field's
  class value, as it constructs them from the looked-up class today
  (the `None` result keeps its `Int` type argument).
- Keep each half's order: arity, then argument checks, then the
  field. `tests/aloemacs/search-find.rkt` sends wrong shapes to `find`
  in a raw environment and expects the arity and argument errors.
- When the field is empty, raise exactly today's error: in the
  checker `typecheck: unbound symbol: Option` (an
  `exn:fail:aloe-type`), in the evaluator
  `eval-aloe: unbound symbol: Option`. The spec's error table adds no
  message for this slice.
- A raw environment that loaded `lib/option.aloe` by hand has no
  installed `Option`, so it rejects `find` with that same error. That
  is a change: today the name lookup finds the loaded class there. A
  load is not an install. No existing test sends a working `find` in
  such an environment (`tests/aloemacs/search-find.rkt` sends only
  wrong shapes there).
- A prompt-defined `Option` does not change what `find` returns.

### 4. Loads of `option.aloe`

`lib/text.aloe`, `lib/fs.aloe`, and `lib/disk.aloe` keep
`(load "option.aloe")`. In a default environment every such load,
and every `(load ".../lib/option.aloe")`, is a hit of the installed
entry: it runs nothing and binds nothing. A keyed root at that path
with different bytes is the changed-bytes error with
`lib/option.aloe`.

### 5. A base library queried in the editor

Each query has an **identity path** and a **resolution path**:

- for hover, the resolution path is `query-expression-at`'s
  positional path (the file actually read, possibly the adapter's
  sibling); the identity path is `#:document-path`, defaulting to the
  positional path;
- for completion, the identity path is the normalized `#:source-path`
  and the buffer is `source`.

Normalize the identity path with `resolved-source-path`. When it
equals the resolved path of `lib/list.aloe`, `lib/string.aloe`,
`lib/int.aloe`, or `lib/option.aloe`:

1. The query's fresh base installs the other three libraries, in
   their usual order (list, string, int, option, skipping the
   queried one), and records them as seeds as §1 does.
2. It then installs the queried library from the buffer, last, as the
   query's one root check, with the observer active: the expressions
   read from the resolution path for hover, the expressions recovered
   from `source` for completion. The buffer is not checked a second
   time, and the base never held a first copy of that library.
3. That install goes through 000's checker rule as a keyed root keyed
   by the identity path, with the buffer's bytes (the resolution
   file's bytes for hover, the UTF-8 encoding of `source` for
   completion). The base has no entry for that path, so it is a miss;
   the completed entry holds the buffer's bytes. They are never
   compared with the file on disk, so a dirty buffer is not a
   changed-bytes error.
4. If the queried library is `lib/option.aloe`, the base's field (§2)
   is set from the buffer's `Option` after the install, as any base
   sets it.
5. The process-wide promise is untouched; the next query and every
   driver still install from it.

Otherwise (any other identity path, or no `source-path` for
completion) the query builds its environment and checks the buffer
exactly as today. Neither query's root is otherwise keyed in this
slice. Loads nested in the buffer still resolve from the resolution
path's directory, and the result's `location` still has the
normalized positional path as its source.

### 6. API and adapter

- `query-expression-at` becomes
  `(query-expression-at source-path position #:document-path [document-path source-path])`.
  A `document-path` that is not `path-string?` raises
  `raise-argument-error` with `who` `query-expression-at` and
  `"path-string?"`. The document path need not exist. The provide
  list of `aloe/expression-query.rkt` does not change.
- `query-selector-completions` does not change its signature.
- `aloe/lsp.rkt`: when the buffer matches disk, call the hover query
  exactly as today, with no keyword. When it queries through a
  sibling, call it on the sibling with `#:document-path` set to the
  document's local path. The completion call is unchanged (it already
  passes the document path as `#:source-path`).
- The injected hover query procedures that
  `run-lsp-server/with-query` and `run-lsp-server/with-queries`
  accept are therefore called with that keyword through a snapshot.
  Test stubs on that path accept it (**Migration**).

### 7. What stays

- The shared environment, the load cache rules, and `load` itself.
- Overload selection, `Mirror`, `Signature`, conformance, and every
  other kernel message.
- The census test and its `Option` skip.
- `type->datum`: `(Option Int)` still prints `(Option Int)`, so every
  `signature-spec` row for `find` is unchanged.

## Language law

`SPEC.md` §7.5, two edits and nothing else:

- In the String table, the `find` row's last cell becomes:
  "`(Option Int)`, where `Option` is the base class from
  `lib/option.aloe`, with `pattern : String` and `start : Int`".
- Directly after the sentence that ends "parallel to List's
  Aloe-defined `fold`, `reverse`, and `map`." add: "`Option` is an
  Aloe class defined in `lib/option.aloe` and installed in default
  environments beside the list, string, and int libraries; `find`
  returns that class, not a class the program bound under that
  name."

`docs/decisions.md`: add one section at the end, after "Explicit
loads", dated the day you land it:

> ## Option on the base (YYYY-MM-DD)
>
> Decided: `lib/option.aloe` is installed beside the other libraries;
> `String find` returns it; a load of the file is a hit; an editor
> query of a base library installs it from the buffer. Rejected:
> resolving `find`'s `Option` by name, and a second `Option`.
> Supersedes the 2026-09-08 "Option library" sentence that
> `make-driver` does not bootstrap it.

And append one sentence to the end of the 2026-09-08 "Option library"
entry, changing nothing else in it: "Superseded by \"Option on the
base\" (YYYY-MM-DD)." with the same date.

## Editor documents

- `docs/editor/lsp/spec.md` §5: after the sentence "The adapter does
  not copy, parse, or rewrite `load` forms." add: "When it queries
  through a sibling, it passes the document's own path as
  `#:document-path`, so the query keys and names the buffer by the
  document, not the sibling."
- `docs/editor/expression-query/spec.md` §1: the signature in the
  code block becomes
  `(query-expression-at source-path position #:document-path [document-path source-path])`
  with a contract comment line `; document-path : path-string?`. After
  the `position` paragraph (the one that begins "`position` uses the
  same coordinate") add: "`#:document-path`, when supplied, is the
  path the query treats as the file's identity: its load-cache key
  and the defining path of classes it defines. It defaults to the
  normalized source path. Loads still resolve relative to the source
  path's directory."
- `docs/editor/completion/spec.md` §1: after the `source-path`
  paragraph (the one that begins "`source-path`, when supplied, is
  normalized") add: "`source-path` is also the buffer's identity. When
  it names one of the base libraries, the query installs that library
  from `source` instead of the file on disk, and checks it once."

## Tests

### Focused proof: `tests/modules/002-option-base.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. Cases 1, 2, 4, 5, 8, 9, and 10 fail there, and so
does the by-hand-load part of case 3. Cases 6 and 7, and the first
part of case 3, pin behavior that holds before and after.

Use `driver-eval!`, `eval-source`, and `typecheck-source` as
`tests/modules/000-run-once.rkt` does. Runtime `check` compares class
identity, and the checker's `check` requires one type, so a
`(check a b)` form observes both halves.

1. **A fresh base binds `Option`.** `make-driver`, and `aloe/main.rkt`'s
   `make-type-environment` and `make-top-level-env`, bind `Option` in
   every half they build, with no load, and bind neither `Some` nor
   `None`. The raw constructors do not bind `Option`.
2. **`find` returns the base class.** In a fresh driver:
   `(define found ("abc" find "b" 0))`, then
   `(check found (Option Some 1))` typechecks and runs. Then define
   the SPEC §3.1 `Option` at the prompt (the `define-class (Option T)`
   form with `None` and `Some`). Now `(check found ("abc" find "b" 0))`
   typechecks and runs, and `(check ("abc" find "b" 0) (Option Some 1))`
   is an `exn:fail:aloe-type`. Repeat the same steps with `eval-source`
   on an `aloe/main.rkt` `make-top-level-env`, and on a raw
   `make-top-level-env` from `aloe/env.rkt` (the fallback installs
   the base). `typecheck-source` of `("abc" find "b" 0)` in a fresh
   `aloe/main.rkt` `make-type-environment` gives `'(Option Int)`.
3. **A raw environment rejects `find`.** `type-of` of
   `("abc" find "b" 0)` in a raw checker environment raises exactly
   `typecheck: unbound symbol: Option`; `eval-expr` of it in a raw
   runtime environment raises exactly
   `eval-aloe: unbound symbol: Option`, also after that raw runtime
   environment loads `lib/option.aloe` by hand.
4. **The install is an entry.** In a fresh driver, capture the
   runtime `Option`; `(load "<lib/option.aloe>")` raises nothing and
   `Option` is still `eq?`. `driver-load-port!` of
   `(open-input-string "(define changed 1)\n")` with `#:source-path`
   the `lib/option.aloe` path raises exactly
   `typecheck: load file changed: lib/option.aloe; this version does not reload a changed file`.
5. **The diamond shares the installed class.** Capture the runtime
   `Option` of a fresh driver, load `lib/text.aloe` and `lib/fs.aloe`;
   `Option` is still `eq?` to the captured class.
6. **The §9 goldens with a prompt `Option`.** In a fresh driver,
   define the SPEC §3.1 `Option` at the prompt, then:
   `(Option Some "x")` has type `(Option String)`;
   `((Option Some "x") present?)` is `#t`;
   `((if #t (Option None) (Option Some "x")) present?)` is `#f`;
   `((Option Some "x") case (None () "unknown") (Some (name) name))`
   is `"x"`; `(define n (Option None))` and
   `((Option Some "x") case (Some (name) name))` each raise
   `exn:fail:aloe-type`; and `(Some "x")` is rejected by the parser
   with `selector must be a symbol`, before the checker, as
   `tests/checkpoint-100.rkt` already pins.
7. **Hover inside `lib/option.aloe`.** `query-expression-at` on the
   real `lib/option.aloe`, at `self` in `(self case`, gives type
   `'(Option T)`.
8. **Hover inside a dirty `lib/option.aloe`.** Write a sibling file
   into a temporary directory under `/tmp` (no `.aloe` extension
   needed) holding `lib/option.aloe`'s bytes followed by the line
   `((Option Some "x") present?)`. `query-expression-at` on the
   sibling, at `(Option Some "x")` in that last line, with
   `#:document-path` the real `lib/option.aloe`, gives
   `'(Option String)`. That position is past the end of the file on
   disk, so only the buffer can answer.
9. **Hover inside `lib/list.aloe`.** `query-expression-at` on the
   real `lib/list.aloe`, at `self` in `(self empty?)`, gives
   `'(List T)`. And with a sibling in a temporary directory holding
   `lib/list.aloe`'s exact bytes, queried with `#:document-path` the
   real path, it gives the same: the rule follows the identity path,
   not the file read. Without `#:document-path` that sibling query
   still raises `ambiguous message: fold`, as any second check of
   the list library does.
10. **Completion inside `lib/string.aloe`.** Take `lib/string.aloe`'s
    text with `((self take (prefix len)) = prefix)` replaced by
    `((self take (prefix len)) = (prefix starts-with? self))`.
    `query-selector-completions` on it, at the position just after
    `prefix sta`, with `#:source-path` the real `lib/string.aloe`,
    returns items whose labels include `"starts-with?"` exactly once.

Write the sibling files outside the repository and delete them when
the case ends. Do not write into `lib/` from the test.

### Migration

With the amendment, these are exactly the sites the implementer's
suite run found, and no others.

**Fresh-driver name lists.** Each line below is a list of names a
test asserts are *unbound* in a fresh driver (before any load, or in
a second fresh driver). Remove `Option` from it and change nothing
else. Lists in the same tests that assert names are *bound* after a
load keep `Option`, which is bound. The exception is `runner.rkt`
line 197: that loop asserts each name is bound in the loaded driver
*and* unbound in `fresh-state`, a second fresh driver, which now binds
`Option`; remove it there too (case 1 of the focused proof covers a
fresh driver binding it).

| File | Lines (tree at issuance) |
|---|---|
| `tests/aloemacs/001-position-span.rkt` | 43, 59 (keep 53) |
| `tests/aloemacs/002-text-view-validity.rkt` | 66, 87 (keep 70) |
| `tests/aloemacs/003-text-edits.rkt` | 109, 123 (keep 113) |
| `tests/aloemacs/editor-keys.rkt` | 81, 89 (keep 85) |
| `tests/aloemacs/file-session.rkt` | 173, 185 (keep 179) |
| `tests/aloemacs/runner.rkt` | 186, 197 |
| `tests/checkpoint-103.rkt` | 62 |
| `tests/checkpoint-104.rkt` | 93 |
| `tests/checkpoint-105.rkt` | 68 |
| `tests/checkpoint-106.rkt` | 128 |
| `tests/checkpoint-107.rkt` | 116 |

**`tests/checkpoint-100.rkt`.** The test case "Option is loadable but
absent from fresh drivers" (line 22) loops over `'(Option term fs-host)`
asserting each is unbound in both halves. That first assertion
inverts for `Option`: assert `Option` is bound in both halves of the
fresh driver (`env-bound?` and `type-environment-bound?`), and keep
the loop for `term` and `fs-host`. Everything after it in that test
case still holds and does not change. Rename the test case to
"Option is installed in fresh drivers and loadable".

**LSP hover stubs reached through a snapshot.** Each stub below is a
hover query procedure the adapter now calls with `#:document-path`.
Add an optional keyword argument (`#:document-path [_document-path #f]`
or similar) and change nothing else, except in the one stub marked
below. The `008` row is a wrapper that counts calls and then calls
the test's inner stub: it takes the keyword and does not forward it,
so the inner stubs stay as they are.

| File | Line of the stub's `lambda` | Test case |
|---|---|---|
| `tests/editor/lsp/000-hover.rkt` | 312 | "dirty synchronized text queries a snapshot without changing the file" |
| `tests/editor/lsp/001-utf16-positions.rkt` | 331 | "a one-byte disk mismatch queries and removes a sibling" |
| `tests/editor/lsp/002-document-sync.rkt` | 458 | "dirty final change queries a snapshot without changing the filesystem" |
| `tests/editor/lsp/003-buffer-snapshots.rkt` | 229 | "dirty didOpen queries exact bytes through a temporary sibling" (marked) |
| `tests/editor/lsp/003-buffer-snapshots.rkt` | 270 | "dirty final didChange drives snapshot position and range" |
| `tests/editor/lsp/003-buffer-snapshots.rkt` | 315 | "null and invalid-range results each remove their snapshot" |
| `tests/editor/lsp/003-buffer-snapshots.rkt` | 353 | "ordinary query failure becomes a null Hover after snapshot cleanup" |
| `tests/editor/lsp/003-buffer-snapshots.rkt` | 389 | "missing root is queried through a sibling and remains missing" |
| `tests/editor/lsp/008-adapter-failures.rkt` | 139 (`counting-query`, a wrapper) | "snapshot cleanup precedes malformed-result adaptation" (line 380) |

In the marked stub, take the keyword as a required
`#:document-path document-path` and add one assertion beside the
stub's existing ones: `(check-equal? (normalized document-path) (normalized path))`,
where `path` is that test's document path. This is the adapter's
proof that it passes the document's path through a snapshot. Stubs
on the clean path (buffer equal to disk, as in `000-hover.rkt`'s
`counting-query`) take no keyword and stay as they are; they are the
proof that the clean path passes none.

If your suite run fails anywhere else, stop and report the file and
the assertion.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/002-option-base.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

After the `.rkt` edits, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt bin/aloe` and confirm
`./bin/aloe --quit tests/modules/fixtures/box-root.aloe` still prints
`3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as
  you found it was reported;
- the whole suite passes, and the only edits to existing tests are
  the ones in **Migration**;
- no `.aloe` file changed; `aloe/parse.rkt`, `aloe/private/`, and
  `host/racket/` are untouched; the main `provide` lists of
  `aloe/main.rkt`, `aloe/driver.rkt`, and `aloe/expression-query.rkt`
  are unchanged;
- `SPEC.md`, `docs/decisions.md`, and the three editor specs carry
  exactly the text above;
- the whitespace check is clean and the file scope was respected.

Report the results and stop. Do not commit. Do not start slice 3b.

## Non-goals

- Record-based overload selection, a runtime protocol record, method
  records, or conformance changes (slices 3b–3d).
- File environments, copying, or keying any query root other than a
  base library's (slice 3e).
- The collision error, including for a prompt or file that defines
  `Option` (slice 3f).
- Defining paths, `pathed-type`, or hover `from:` lines (layer 4).
- Installing any library other than `lib/option.aloe`; removing any
  `(load "option.aloe")`; or changing the census test's `Option` skip.
- A new error message for `find` without a base `Option`.
- Dirty-buffer overlays for nested loads, or any other editor feature.
