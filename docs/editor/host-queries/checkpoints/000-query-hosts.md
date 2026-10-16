# Editor host-queries 000 — Queries accept host interfaces

**Status.** Written 2026-10-16 by the checkpoint manager from
[`../spec.md`](../spec.md) (reviewed, `80b46fd`), committed `c009703`.
Implemented 2026-10-16. Manager-reviewed 2026-10-16 against this
document: conforming. Accepted by the human 2026-10-16. If you have been
told to read this file, it is the whole assignment.

## Goal

Layer 1 of the spec. The three public editor queries, hover
(`query-expression-at`), go-to-definition (`query-definition-at`), and
completion (`query-selector-completions`), gain one keyword argument,
`#:hosts`. It is a list of pairs: an Aloe binding name and the host
interface a host module exports, such as `fs-interface` from
`host/racket/fs.rkt`. When a query checks its buffer as a file module,
it binds each host's type on that query's fresh base. The buffer and
every file it loads then see the host, as they do in a runner. Nothing
is evaluated, no receiver is constructed, and no host implementation
runs.

After this checkpoint, a Racket caller that passes
`#:hosts (list (cons 'fs-host fs-interface))` gets answers in
`examples/aloemacs/main.aloe`, where every hover and definition raises
`typecheck: unbound symbol: fs-host` today.

Nothing reads a manifest, and the language server does not change. That
is layer 2 (a later checkpoint). The first consumer of this layer is
this checkpoint's own Racket test, which requires `host/racket/fs.rkt`
and `host/racket/term.rkt` itself and passes the real interfaces.

The implementer receives only this document. Every rule for this slice
is below.

## Depends on, identity

Identity is `(editor-host-queries, 000)`, spoken **editor-host-queries
000**. It is a local editor checkpoint. Do not edit `CHECKPOINTS.md` or
add a file under `docs/checkpoints/`. Branch:
`experiment/2026-10-16-host-queries`.

The tree at `80b46fd` has every predecessor. Its product code is that of
`6deecab`, the last editor-definition commit. As found:

- **Queries.** `aloe/expression-query.rkt` provides
  `(query-expression-at source-path position #:document-path [document-path source-path])`.
  `aloe/definition-query.rkt` provides `query-definition-at` with the
  same arguments. `aloe/completion-query.rkt` provides
  `(query-selector-completions source position #:source-path [source-path #f])`.
  Each starts with `raise-argument-error` checks of its arguments.
  Hover and definition then normalize and read the file, parse it,
  select, and check the buffer once. Completion runs everything after
  its argument checks inside one `with-handlers` that returns `'()` for
  any `exn:fail`.
- **Query base.** The `query-base` submodule of `aloe/main.rkt` exports
  `base-library-path`, `typecheck-base-library-buffer`, and
  `typecheck-file-module-buffer`. All three queries use it. When
  `base-library-path` recognizes the identity path (the document path
  for hover and definition, the normalized source path for completion),
  the query calls `typecheck-base-library-buffer`. Otherwise it calls
  `typecheck-file-module-buffer`, which checks the buffer as a file
  module on the fresh base of `(make-type-environment)`. That
  procedure returns the interactive environment of a new base; the base
  is its parent. Completion with no source path calls its observer on
  `(make-type-environment)` directly and uses neither hook.
- **Host types.** `aloe/host.rkt`: `host-interface` is opaque and
  nominal. `make-host-method` requires an implementation procedure of
  exact arity. `aloe/type.rkt` has `(struct host-receiver-type (interface))`,
  which is not exported. `type-environment-inject-host!`, provided only
  by the submodule `driver-host-injection`, checks an environment, a
  symbol, and a receiver, then calls
  `(type-environment-set! environment name (host-receiver-type (host-receiver-interface receiver)))`.
  A binding stored on a base records the origin `base`. Two host types
  are equal only when their interfaces are `eq?`. `type-environment-base`
  is provided by the `load-cache` submodule of `aloe/type.rkt`.
  `type-environment-bound?` is public in `aloe/type.rkt`.
- **Host modules.** `host/racket/fs.rkt` exports `fs-interface` (`FsHost`,
  ten methods) and `make-fs-receiver`. `host/racket/term.rkt` exports
  `term-interface` (`Term`, six methods). `term.rkt` requires `tui/term`,
  from the optional `tui-term` package, which is installed on the
  development machine. Existing tests already load it.
- **The problem.** Hover and definition raise
  `typecheck: unbound symbol: fs-host` at every position in
  `examples/aloemacs/main.aloe`, and `typecheck: unbound symbol: term`
  in `gel/main.aloe`. Completion answers only where its receiver is
  typed before the first host use.

## Authority

- `SPEC.md` is law and is not amended.
- [`docs/editor/host-queries/spec.md`](../spec.md) §4 and §5 are the
  design of this layer. §9.1–§9.4 give its cursors and answers. §10.1
  and §10.4 give its coverage. Every rule you need is restated below.
- The spec lifts, for host-interface bindings only, the sentences in
  the closed expression-query, completion, and definition specs that say
  a query has no host injection. Those spec files are not edited.
- The expression query's failure policy, completion's recovery rule and
  early exit, and definition's name tokens all stay as they are.

## Required behavior

### 1. The checker hook (`aloe/type.rkt`)

**One store.** Add a private procedure that stores a host's type:
`(type-environment-set! environment name (host-receiver-type interface))`.
Both hooks below call it, so a type made from an interface and a type
made from a receiver are built the same way. Its name is yours.

**The driver's hook is unchanged.** `type-environment-inject-host!`
keeps its three checks, its `who`, and its three messages. After them it
calls the store with `(host-receiver-interface receiver)`. Its contract
and the driver's behavior do not change.

**The query hook.** Define
`(type-environment-bind-host-interface! environment name interface)`
beside `type-environment-inject-host!`. It checks, in this order, with
`raise-arguments-error` and who `'type-environment-bind-host-interface!`:

| Argument | Check | Message | Field |
|---|---|---|---|
| `environment` | `type-environment?` | `"environment must be a type environment"` | `"environment"` |
| `name` | `symbol?` | `"name must be a symbol"` | `"name"` |
| `interface` | `host-interface?` | `"interface must be a validated host interface"` | `"interface"` |

After the checks it calls the store. It does not refuse a name that is
already bound; that is the caller's job (§2 below). Provide it only from
a new submodule, written exactly so:

```racket
;; Editor queries bind a host's type from its interface alone, without
;; constructing a receiver, through this deliberately narrow hook.
(module* query-host-binding #f
  (provide type-environment-bind-host-interface!))
```

It is not added to the module's top-level `provide`.
`host-receiver-type` stays unexported.

**A test-only reader.** Add a second submodule, in the style of the
existing `class-name-span` submodule:

```racket
;; Tests read the interface inside a bound host type through this hook;
;; nothing else does.
(module* host-binding-interface #f
  (provide checker-host-interface)
  ...)
```

`(checker-host-interface environment name)` reads `name` with
`type-environment-ref` and returns the `host-interface` inside the host
type bound there. When `name` is bound to something other than a host
type, it raises with `error` (`'checker-host-interface`). An unbound
name raises whatever `type-environment-ref` raises.

Place both submodules beside the existing `driver-host-injection`
submodule. Nothing else in `aloe/type.rkt` changes.

### 2. The query base (`aloe/main.rkt`)

**Requires.** Add `(only-in "host.rkt" host-interface?)`. Add
`type-environment-base` to the existing `only-in` of
`(submod "type.rkt" load-cache)`. Add
`(only-in (submod "type.rkt" query-host-binding) type-environment-bind-host-interface!)`.
`type-environment-bound?` is already reachable as
`checker:type-environment-bound?` through the existing
`(prefix-in checker: "type.rkt")`.

**The shape check.** Add `(check-query-hosts who hosts)`:

1. Unless `hosts` is a list whose every element is a pair with a symbol
   car and a cdr that satisfies `host-interface?`, call
   `(raise-argument-error who "(listof (cons/c symbol? host-interface?))" hosts)`.
   A host receiver such as `(make-fs-receiver)` is not an interface and
   fails here.
2. Walking the pairs in order, at the first pair whose name already
   appeared earlier, call
   `(raise-arguments-error who "host names must be distinct" "host name" name)`.
   For names `a b b a`, the error names `b`.

It returns nothing useful. It reads nothing and loads nothing.

**Binding on the base.** `typecheck-file-module-buffer` gains two
keyword arguments:

```racket
(typecheck-file-module-buffer document-path source-bytes expressions observe
                              #:hosts [hosts '()]
                              #:who [who 'typecheck-file-module-buffer])
```

It makes the fresh environment with `(make-type-environment)`, as today,
and takes its base with `type-environment-base`. Before the buffer is
checked, it walks `hosts` in order. For each pair, on that base:

- If `(checker:type-environment-bound? base name)`, it calls
  `(raise-arguments-error who "host name is already bound on the query base" "host name" name)`.
  On the found tree, the names bound on a fresh base are `dummy`,
  `List`, `Int`, `String`, `Symbol`, `Mirror`, `Option`, and every name
  the four base libraries define.
- Otherwise it calls
  `(type-environment-bind-host-interface! base name interface)`.

Then it checks the buffer exactly as today, on that same environment.
With `hosts` empty it behaves exactly as today.

This is the driver's injection without the runtime half, done on the
query's own base. A file the buffer loads sees the host. If the buffer
or a loaded file defines a host's name, the checker's existing collision
error reports it. Each query has a fresh base, so a host bound for one
query is never visible to another.

**Exports.** The `query-base` submodule's `provide` gains
`check-query-hosts`. Nothing is added to `aloe/main.rkt`'s top-level
`provide`. `typecheck-base-library-buffer` does not change.

### 3. The three queries

Each public query gains one keyword argument, `#:hosts [hosts '()]`,
placed after its existing keyword:

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
```

In each query:

1. Import `check-query-hosts` from `(submod "main.rkt" query-base)`,
   in the existing `only-in` of that submodule.
2. Call `(check-query-hosts '<the query's own name> hosts)` right after
   the query's existing argument checks, before anything else. For
   hover and definition that is before the path is normalized and before
   the file-exists check. For completion it is before the
   `(> position (add1 (string-length source)))` early exit and outside
   the `with-handlers`, so completion raises these errors too.
3. On the file-module branch only, pass the hosts:
   `(typecheck-file-module-buffer … observe #:hosts hosts #:who '<the query's own name>)`.

Which branch binds hosts:

| Branch | When | Hosts |
|---|---|---|
| File module | `typecheck-file-module-buffer` is called | bound on the fresh base |
| Base library | `base-library-path` recognizes the identity path | ignored; the call is unchanged |
| Completion with no source path | `source-path` is `#f` | ignored; the call is unchanged |

Hosts are shape-checked on every branch. Beyond these three edits, no
query module changes. The query modules do not import `aloe/host.rkt`,
and they never read a manifest, load a module, or `require` anything
under `host/racket/`.

### 4. Failure order

`query-expression-at` and `query-definition-at` keep the expression
query's failure policy, in this order:

1. the existing argument errors (`raise-argument-error`, the query's
   name)
2. the two shape errors of `check-query-hosts`
3. the missing-file error, reading, parsing, and selection, as today
4. the already-bound refusal, an `exn:fail:contract` whose message
   starts with the query's name
5. checking, as today; an Aloe checker failure raises
   `exn:fail:aloe-type`

`query-selector-completions` raises its existing argument errors and the
two shape errors. The already-bound refusal happens inside its existing
handler, so a name already bound on the base gives `'()`, as any failure
after the argument checks does.

### 5. Answers with hosts

No answer format is added. These follow from the hook:

- **Hover** on a host name has type and pathed type equal to the
  interface's name, such as `FsHost`. Its signatures are the interface's
  methods in declaration order, each a `signature-spec` of the method's
  selector, parameter types, and return type. This is what hover already
  reports for a host receiver type.
- **Completion** after `(fs-host ` lists `FsHost`'s selectors from the
  existing catalog, in declaration order. At a position that answers
  today, the items are the same with or without hosts.
- **Definition** on a host name returns `#f`: its type is not a class
  type. A class name in the same file still jumps.
- Host interface names stay unavailable in Aloe annotations.

### 6. Source pins that must stay green

These existing tests read source text. Keep every one green without
editing it, except the one edit in §7. They apply to comments too.

- `tests/editor/completion/002-public-query.rkt`, "production remains a
  narrow static composition": `aloe/completion-query.rkt` must not
  contain the substrings `query-expression-at`, `type-signature-specs`,
  `read-program`, `type-of`, `class-info-methods`, `class-info-fields`,
  `eval-expression`, `Mirror`, `Point`, `Boid`, `fold`, `map`,
  `reverse`, `starts-with?`, `sort`, `remove-duplicates`, `snippet`,
  `textDocument/completion`, or `CompletionItem`, nor `typecheck-program`
  followed by a newline. It must contain exactly two each of
  `recover-selector-completion-site`, `make-type-environment`, and
  `typecheck-program/observe-selector-receiver`. Add no comment to
  this file. The shape check lives in `aloe/main.rkt` partly so that
  this file stays inside these pins.
- `tests/editor/expression-query/003-public-query.rkt`, "production
  module remains a static catalog adapter": `aloe/expression-query.rkt`
  must not match `host-receiver`, `eval-expr`, `make-driver`,
  `make-runtime-environment`, `class-info-methods`, `'Point`, `'List`,
  `'String`, or `(signature-spec` followed by whitespace.
- `tests/checkpoint-88.rkt`: `aloe/main.rkt` must not match
  `host/racket/term\.rkt|tui/term|term-interface|make-term-receiver`.
  `aloe/type.rkt` must not export `host-receiver-type`,
  `host-receiver-type?`, `host-receiver-type-interface`, or
  `type-environment-inject-host!` at top level, and the
  `driver-host-injection` submodule still provides the driver's hook.
- `tests/editor/completion/002-public-query.rkt`, "public surface and
  arities are exact", and `tests/editor/expression-query/003-public-query.rkt`
  pin each query's positional arity at 2 and each module's exports. The
  keyword argument changes neither.

### 7. The one existing test this checkpoint edits

| Test | Edit |
|---|---|
| `tests/editor/completion/002-public-query.rkt`, "public surface and arities are exact" (line 169) | `(check-equal? allowed-keywords '(#:source-path))` becomes `(check-equal? allowed-keywords '(#:hosts #:source-path))` |

The scratch run below applied the product edit and ran the whole suite.
This was the only failing location. No other existing test changes.

## Exact file scope

May edit:

- `aloe/type.rkt`: the private store, the last expression of
  `type-environment-inject-host!`, the new
  `type-environment-bind-host-interface!`, and the two new submodules.
  Nothing else.
- `aloe/main.rkt`: the requires, `check-query-hosts`,
  `typecheck-file-module-buffer`, and the `query-base` `provide`.
- `aloe/expression-query.rkt`, `aloe/definition-query.rkt`,
  `aloe/completion-query.rkt`: the three edits in §3 of Required
  behavior, and nothing else.
- `tests/editor/completion/002-public-query.rkt`: the one line in §7.
- `tests/editor/host-queries/000-query-hosts.rkt` (new)
- `tests/editor/host-queries/fixtures/configured/spot.aloe`,
  `reads-fs.aloe`, `uses-fs.aloe`, and `defines-fs-host.aloe` (new)
- `docs/editor/host-queries/README.md` and `docs/editor/README.md`, for
  the status lines under Acceptance

Do not edit:

- `aloe/host.rkt`, `aloe/driver.rkt`, `aloe/lsp.rkt`, `aloe/parse.rkt`,
  `aloe/eval.rkt`, `aloe/library.rkt`, `aloe/signature-catalog.rkt`,
  `aloe/private/`, or any other module under `aloe/`
- `host/racket/` (including `aloemacs-run.rkt` and `gel-run.rkt`),
  `examples/`, `gel/`, `lib/`, or `editors/vscode/`
- any existing test or fixture other than the one line in §7
- `SPEC.md`, `CHECKPOINTS.md`, `docs/checkpoints/`, or any spec,
  charter, or checkpoint document, this one included
- the text of any existing error

Do not add `aloe/host-manifest.rkt`, an `aloe-hosts.rktd` file,
`host/racket/README.md`, `configured/failing.aloe`, or a `broken/`
fixture folder. Those are layer 2.

If an existing test fails, or the slice seems to need a file outside
this list, stop and report it.

## Fixtures

Add four files under `tests/editor/host-queries/fixtures/configured/`.
Each is ASCII with one LF after every line. Layer 2 reuses them
unchanged.

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

`uses-fs.aloe` (145 bytes, with an empty third line):

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

`tests/modules/001-census.rkt` makes one test case for every `.aloe`
file under `tests/`. It allows `fs-host` and `term` as free names, and
all four files pass it. So the four fixtures add four census cases to
the whole suite.

A checked-in `.aloe` fixture may use only `fs-host` or `term` as a free
host name. A buffer that needs any other host name, such as `other-fs`,
is written by the test to a temporary directory under
`(find-system-path 'temp-dir)`. A temporary copy written beside a
fixture is named without the `.aloe` extension, with
`(make-temporary-file "host-queries-copy-~a" #f folder)`, so a census
run in parallel never sees it. Remove every temporary file and
directory unconditionally (`dynamic-wind`).

## Required tests

Add `tests/editor/host-queries/000-query-hosts.rkt`. It is three
directories below the repository root, so use `../../../` in relative
module paths. Require:

- the three public query modules (`aloe/expression-query.rkt`,
  `aloe/definition-query.rkt`, `aloe/completion-query.rkt`), which also
  give `signature-spec` and `selector-completion-item`
- `exn:fail:aloe-type?` and `make-type-environment` from `aloe/main.rkt`
- from `aloe/host.rkt`: `make-host-interface`, `make-host-method`,
  `host-interface-methods`, `host-method-selector`,
  `host-method-parameter-types`, `host-method-return-type`,
  `host-receiver-interface`
- `type-environment-base` from `(submod "../../../aloe/type.rkt" load-cache)`,
  `type-environment-bind-host-interface!` from `query-host-binding`,
  `checker-host-interface` from `host-binding-interface`, and
  `type-environment-inject-host!` from `driver-host-injection`
- `"../../../host/racket/fs.rkt"` and `"../../../host/racket/term.rkt"`,
  by relative path, as the existing suite does

Use `define-runtime-path` for the fixture folder and for
`examples/aloemacs/main.aloe`, `examples/aloemacs/file.aloe`,
`lib/fs.aloe`, `lib/option.aloe`, and `gel/main.aloe`.

### Conventions

Lines are one-based, columns zero-based, and positions one-based, as
`srcloc` reports them. A hover location's source is the file that was
read. A definition location's source is the target file's complete,
simplified path, `(simplify-path (path->complete-path p) #f)`.

**Expected rows come from the interface.** Never copy the list.
For an interface `i`:

- its **rows** are, for each method in `host-interface-methods` order,
  `(signature-spec selector parameter-types return-type)`;
- its **items** at start `s` and span `n` are, in the same order,
  `(selector-completion-item label detail label s n)`, where `label` is
  the selector written with `~s`, and `detail` is
  `(format "~s -> ~s" parameter-types return-type)`. For example,
  `"(String) -> (List String)"`.

**Product files are found by text.** The user edits
`examples/aloemacs/main.aloe`, `examples/aloemacs/file.aloe`,
`lib/fs.aloe`, and `gel/main.aloe` by hand. Locate every cursor and
target in them from its text: the position of a character is one plus
its zero-based index in the file's string. Check that a needle occurs
exactly once, except where it says "first". Compute a target's
expected line and column from the same text. Never store a product
position. The numbers in the tables below are as found on `80b46fd`,
for reference only. Positions in the four new fixtures may be written
as numbers.

**Unbound** means: raises `exn:fail:aloe-type?` whose message is
exactly `typecheck: unbound symbol: fs-host` (or `term`).

Write one `test-case` per numbered item below, twelve in all. The names
are yours.

### 1. The hook

On the base of a `(make-type-environment)`:

- `type-environment-bind-host-interface!` binds `'fs-host` to
  `fs-interface`, and `checker-host-interface` then returns a value
  `eq?` to `fs-interface`.
- Each of its three argument errors is raised: a non-environment, a
  string name, and a receiver (`(make-fs-receiver)`) as the interface.
  Each message starts with
  `type-environment-bind-host-interface!: ` followed by the table's
  message.
- A second binding of `'fs-host`, to `term-interface`, is not refused,
  and `checker-host-interface` then returns `term-interface`.
- `checker-host-interface` on `'Option` raises.
- After `type-environment-inject-host!` binds a receiver from
  `(make-fs-receiver)` as `'other`, `checker-host-interface` returns a
  value `eq?` to that receiver's interface. Each of the driver hook's
  three argument errors is raised with its unchanged message:
  `environment must be a type environment`, `name must be a symbol`, and
  `receiver must be a validated host receiver`, each after
  `type-environment-inject-host!: `.
- `(dynamic-require <aloe/type.rkt> 'type-environment-bind-host-interface!)`
  and `(dynamic-require <aloe/type.rkt> 'checker-host-interface)` raise,
  and so does `(dynamic-require <aloe/main.rkt> 'check-query-hosts)`.
  They are not public.

### 2. Product cursors in `examples/aloemacs/main.aloe`

With hosts `(list (cons 'fs-host fs-interface))`:

| Cursor (find by text) | As found | Answer |
|---|---|---|
| `fs-host` in `(Fs new fs-host)` | line 74, col 33, pos 2252 | hover: type `'FsHost`, pathed type `'FsHost`, signatures the rows of `fs-interface`, location span 7. Definition: `#f` |
| `AloemacsBuffer` in `(AloemacsBuffer new*` | line 8, col 11, pos 157 | hover: type `'(Class AloemacsBuffer)`, pathed type `'(Class AloemacsBuffer@examples/aloemacs/file.aloe)`. Definition: `examples/aloemacs/file.aloe`, at the name in `(define-class AloemacsBuffer` followed by a newline, span 14 (as found: line 132, col 14, pos 4439) |
| `Fs` in `(Fs new fs-host)` | line 74, col 26, pos 2245 | definition: `lib/fs.aloe`, at `Fs` in `(define-class (Fs H)`, span 2 (as found: line 23, col 15, pos 490) |
| `from-string` in `(Text from-string "")` | line 11, col 34, pos 266 | completion with `#:source-path` the real `main.aloe`: `equal?` to the same call without hosts, and its labels include `"from-string"` (as found: `from-string`, `indexed`) |
| after `(fs-host ` | pos 2261 | in a copy of the text with `(Fs new fs-host)` replaced by `(Fs new (fs-host ))`, and `#:source-path` the real `main.aloe`: the items of `fs-interface` at that position, span 0. The position is that of the `)` right after `(fs-host `, which is 17 characters after the start of `(Fs new (fs-host ))` |

Without hosts: hover and definition at the first three cursors are
unbound `fs-host`, and completion after `(fs-host ` gives `'()`.

### 3. Product cursors in `gel/main.aloe`

With hosts `(list (cons 'term term-interface))`, at the first
occurrence of `(term write-line`:

| Cursor | As found | Answer |
|---|---|---|
| `term` | line 19, col 14, pos 367 | hover: type `'Term`, pathed type `'Term`, signatures the rows of `term-interface`, location span 4. Definition: `#f` |
| `write-line` | pos 372 | completion with `#:source-path` the real `gel/main.aloe`: the items of `term-interface` at that position, span 10. `write-line` matches a row exactly, so every row is offered |

Without hosts: hover and definition on `term` are unbound `term`, and
completion on `write-line` gives `'()`.

### 4. Fixture answers

Below, `uses` is `configured/uses-fs.aloe` and the hosts are
`(list (cons 'fs-host fs-interface))`. The hole text is `uses`'s text
with `(define here (fs-host current))` replaced by
`(define here (fs-host ))`.

| Query | With hosts | Without hosts |
|---|---|---|
| hover, `uses` pos 58 (`fs-host`, line 4, col 14) | type `'FsHost`, the rows of `fs-interface`, location line 4, col 14, pos 58, span 7 | unbound `fs-host` |
| definition, `uses` pos 58 | `#f` | unbound `fs-host` |
| definition, `uses` pos 92 (`Spot`, line 5, col 16) | `spot.aloe`, line 1, col 14, pos 15, span 4; `text` `equal?` to `spot.aloe`'s contents | unbound `fs-host` |
| hover, `uses` pos 138 (`start`, line 6, col 31) | type `'String`. The loaded `reads-fs.aloe` saw the host | unbound `fs-host` |
| completion, hole text, pos 66 (line 4, col 22), `#:source-path` `uses` | the items of `fs-interface` at 66, span 0 | `'()` |
| hover and definition, `defines-fs-host.aloe` pos 17 | each raises `exn:fail:aloe-type?` with exactly `typecheck: name collision: fs-host is defined by the language base and by tests/editor/host-queries/fixtures/configured/defines-fs-host.aloe` | hover: type `'Int` |
| hover, `reads-fs.aloe` pos 15 | — | unbound `fs-host`. A query gets only the hosts passed for its own document |

### 5. A sibling copy

Write `uses`'s text with one LF prepended to
`(make-temporary-file "host-queries-copy-~a" #f <configured folder>)`.
Query the copy with `query-expression-at` at position 59, with
`#:document-path` set to `uses` and with the hosts. The answer has type
`'FsHost`, the rows of `fs-interface`, and location line 5, col 14,
pos 59, span 7. Loads resolve from the copy's folder, so `spot.aloe`
and `reads-fs.aloe` are found. Remove the copy afterwards, even on
failure.

### 6. Isolation

Hover at `uses` pos 58 with the hosts answers. The same call without
hosts then is unbound `fs-host`. A third call with the hosts is
`equal?` to the first.

### 7. Nominal identity

In a temporary directory, write `both.aloe` holding
`(define both (List of fs-host other-fs))` and one LF.

- With `fs-host` and `other-fs` both bound to `fs-interface`, hover at
  position 20 (on the selector `of`) has type `'(List FsHost)`, and
  hover at position 9 (on `both`, a `define` name, which selects the
  whole form) has type `'Void`.
- With `fs-host` bound to `fs-interface` and `other-fs` bound to the copy
  `(make-host-interface 'FsHost (host-interface-methods fs-interface))`,
  hover at position 20 raises `exn:fail:aloe-type?` with exactly
  `typecheck: List of elements must have one type`.

### 8. No host call

Build an interface named `'FsHost` from `fs-interface`'s methods: for
each, `make-host-method` with the same selector, parameter types, and
return type, and an implementation that increments a counter and
returns `"x"`. `make-host-method` requires exact arity, one state
argument plus one per parameter, so use `procedure-reduce-arity`. Bind
it as `fs-host`. Then:

- hover at `uses` pos 58 has type `'FsHost`;
- definition at `uses` pos 92 jumps;
- completion at the hole text pos 66 gives ten items;
- the counter is 0. (`listing` in `uses` sends `names` to the host.)

### 9. Malformed hosts

For each of the three queries (hover and definition at `uses` pos 58,
completion at the hole text pos 66 with `#:source-path` `uses`), and for
each of these `#:hosts` values:

- `'fs-host`, which is not a list
- `(list (cons "fs-host" fs-interface))`, a car that is not a symbol
- `(list (cons 'fs-host (make-fs-receiver)))`, a receiver
- `(list (cons 'fs-host fs-interface) (cons 'fs-host fs-interface))`, a
  name given twice

the call raises `exn:fail:contract?` whose message starts with the
query's name followed by `": "`.

Also, for the order of the checks:

- `query-expression-at` with names `a b b a`, all bound to
  `fs-interface`, raises a message that starts with
  `query-expression-at: host names must be distinct\n  host name: 'b`.
- `(query-expression-at "definitely/missing.aloe" 1 #:hosts 'fs-host)`
  raises the shape error, whose message starts with
  `query-expression-at: contract violation\n  expected: (listof (cons/c symbol? host-interface?))`,
  not the missing-file error.
- `(query-selector-completions "" 99 #:hosts 'fs-host)` raises the
  shape error, although that position is past the end of the source.
- `(query-definition-at 3 1 #:hosts 'fs-host)` raises the existing
  `path-string?` error, whose message starts with
  `query-definition-at: contract violation\n  expected: path-string?`.

### 10. A name already bound on the base

For each of `Option`, `List`, and `dummy` as `name`, with hosts
`(list (cons 'fs-host fs-interface) (cons name fs-interface))`:

- hover at `uses` pos 58 raises `exn:fail:contract?` whose message
  starts with
  `query-expression-at: host name is already bound on the query base\n  host name: '<name>`;
- definition at `uses` pos 92 raises the same, starting with
  `query-definition-at: `;
- completion at the hole text pos 66 returns `'()`.

Also, a temporary file holding `"(define-class Point\n"`, queried by
hover at position 1 with hosts `(list (cons 'Option fs-interface))`,
raises `exn:fail:read?`. Parsing comes before the refusal.

### 11. Ignored branches

- `lib/option.aloe`, queried at position 16 by hover and by
  definition, answers `equal?` to the same call without hosts, both
  with hosts `(list (cons 'fs-host fs-interface))` and with hosts
  `(list (cons 'Option fs-interface))`. The second would be refused on
  the file-module branch.
- `lib/option.aloe` with `#:hosts 'fs-host` still raises the hover
  shape error.
- Completion with no source path: the source
  `(let ((x "text")) (x l))` at position 23, with the `fs-host` hosts,
  is `equal?` to the call without hosts, and is not `'()`.
- Completion with no source path of `"(fs-host )"` at position 10, with
  the `fs-host` hosts, returns `'()`. The host is not bound there.

### 12. No hosts is today's call

- `#:hosts '()` is `equal?` to no argument for hover at
  `defines-fs-host.aloe` pos 17, for definition at `spot.aloe` pos 15,
  and for completion at the hole text pos 66 with `#:source-path`
  `uses`.
- `procedure-keywords` of `query-expression-at` and of
  `query-definition-at` is `'()` and `'(#:document-path #:hosts)`. Of
  `query-selector-completions` it is `'()` and
  `'(#:hosts #:source-path)`.

The existing hover, definition, completion, and LSP suites stay green
with only the §7 edit. That is the proof that a call without hosts is
unchanged.

## Scratch run

On 2026-10-16 a prototype of this checkpoint was applied to a copy of
the tree at `80b46fd`, with every `compiled/` folder removed first. It
added about 40 lines to `aloe/type.rkt`, about 40 to `aloe/main.rkt`,
and 7 to each query module. Then:

- Every answer in tests 1–12 was measured on the prototype, and a
  prototype test file with these twelve test cases passed in about two
  seconds. Hover over all of `main.aloe` with `fs-host` bound took about
  45 ms.
- With the four fixtures in place and no existing test edited, the whole
  suite ran 3063 tests under `-j 4`: the 3059 of `6deecab` and one
  census case per new fixture. The one failure was §7's line,
  `tests/editor/completion/002-public-query.rkt:169`. No file crashed.
  The source pins in §6, including `tests/checkpoint-88.rkt`, passed.
- With §7's edit and the prototype test file, the whole suite ran
  3075 tests, all passing.

## Acceptance

From the repository root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/editor/host-queries/000-query-hosts.rkt
TMPDIR=/tmp raco test -j 4 -y tests/editor
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

All green. The whole suite is 3075 tests: 3059, the 12 new test cases,
and 4 modules-census cases for the new fixtures. If only
`tests/aloemacs/window-pictures.rkt`'s 30 ms timing bar fails under
`-j 4`, run that file alone, and it must pass there. A checker-only
change cannot move that bar.

There is no hand check for this checkpoint. The editor shows nothing
new until the language server passes hosts in layer 2.

Update the status lines:

- In `docs/editor/host-queries/README.md`, in the file table, set the
  `checkpoints/000-query-hosts.md` row to "Implemented *date*, awaiting
  review", with the focused test count and the whole-suite count. Set
  the status paragraph to say editor-host-queries 000 is implemented
  and awaiting review.
- In `docs/editor/README.md`, set project 9's cell to say
  editor-host-queries 000 is implemented and awaiting review.

Stop for review without committing. Do not write or start the next
checkpoint.

## Explicit non-goals

- The manifest, `aloe/host-manifest.rkt`, `read-document-hosts`, any
  `aloe-hosts.rktd` file, `host/racket/README.md`, the effects census,
  or the static-require test (layer 2)
- Any change to `aloe/lsp.rkt`, its tests, or `editors/vscode/`
- Inferring hosts from a path, reading any file to find hosts, or
  loading or requiring anything under `host/racket/` from `aloe/`
- Evaluation, constructing a receiver (including a placeholder one),
  calling a host implementation, or calling `driver-inject-host!`
- A signatures-only interface, a new interface constructor, or relaxing
  `make-host-method`
- Binding hosts on the base-library branch or on completion's
  no-source-path branch
- A new hover, definition, or completion format; go to definition on a
  host name or into Racket source
- Host names in Aloe annotations, an Aloe declaration for hosts, or a
  `SPEC.md` amendment
- Any change to `aloe/driver.rkt`, `driver-inject-host!`, the runners,
  or `aloe/host.rkt`
- Partial checking that answers before the first type error
