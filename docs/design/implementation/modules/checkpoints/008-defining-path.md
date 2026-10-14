# modules 008 — Defining paths

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

Two classes can share a short name, so hover and type mismatches print
where each class was defined.

- A checker class record stores its **defining path**: the resolved
  path of the file that defined it, or none.
- A second rendering of a type, the **pathed datum**, writes each class
  that has a defining path as the symbol `Name@path`, the path
  displayed. `type->datum` does not change.
- The two `expected ~a, got ~a` mismatch sentences gain
  ` (<pathed expected> vs <pathed got>)` when either side names a class
  with a path.
- The expression query's result gains a fourth field, `pathed-type`,
  and LSP hover prints it on a `from:` line when it differs from the
  type.

This is layer 4 of the spec, the ninth checkpoint. It is small: the
manager's scratch version is about 80 product lines across four
modules, and fifteen existing editor tests change mechanically. Stop
when the focused proof and the whole suite pass. Do not start layer 5
(adoption).

## Authority, identity, and starting point

- Identity: **modules 008**, filed as
  `docs/design/implementation/modules/checkpoints/008-defining-path.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. Evaluation
  is send with a literal selector. Function objects run only through
  `call`. No inheritance, mutation, macros, implicit Int/Float
  coercion, or new special forms.
- Predecessors, all committed: **000** (`5d435a5`), **001**
  (`efe39e7`), **002** (`0f026a6`, `Option` on the base; a query of a
  base library installs it from the buffer; `#:document-path`), **003**
  (`1ab41bb`), **004** (`c6a0333`), **005** (`f1311a9`), **006**
  (`0e20fae`, file environments: each loaded file and each keyed root
  is checked in a file environment that records its resolved path),
  **007** (`173eb54`, collisions).
- [../spec.md](../spec.md) governs. This checkpoint is its §7:
  - §2: defining path, displayed path.
  - §7.1–§7.6: this layer. §7.1 and §7.3 were corrected while this
    checkpoint was issued (see the spec's status paragraph): the base's
    installed `Option` records `lib/option.aloe`, and the compound
    `(Option Position)` example is the contextual sentence.
  - §8: the mismatch row.
  - §9.3: the hover goldens and result constructors, as read on
    2026-10-12 (superseded here by the scratch run's inventory, below).
  - §12, row 4: the `docs/decisions.md` text. `SPEC.md` is not edited.
  - §3: out of scope.

### The tree at issuance

Line numbers are approximate; search before editing.

- `aloe/type.rkt`:
  - `class-info` has the fields `name type-parameters parameter-types
    protocol fields constructors explicit-constructors? methods
    environment method-environments`, built in one place,
    `check-class-definition!`, from the environment the `define-class`
    is checked in.
  - `type-environment` has a `path` field: the resolved path on a file
    environment, `#f` on every other environment. A local environment's
    parent chain reaches its file environment, if any.
  - `type->datum` renders a type; instance types and class types print
    `class-info-name`.
  - The plain mismatch is `type-mismatch`
    (`"type mismatch: expected ~a, got ~a"`, expected first). The
    contextual one is formatted in `infer-expression`
    (`"type mismatch for ~a: expected ~a, got ~a"`) before unifying.
  - `record-checked-option-class!` records the base's `Option` class
    after the install. A driver, both `aloe/main.rkt` constructors, and
    the 002 query base call it.
  - `typecheck-keyed-buffer` is the 002 hook through which a query of a
    base library checks the buffer, installed into the query's base, as
    a keyed root under the identity path.
  - `typecheck-file-buffer` checks any other queried buffer in a file
    environment whose `path` is the resolved identity path.
  - `make-checker-observation-api` is called with `type->datum` and
    `type-signature-specs`. The submodule `expression-query-observation`
    exports the observation struct.
  - `displayed-path` (from `aloe/library.rkt`) prints the
    repository-relative path, or the resolved path outside the
    repository.
- `aloe/private/checker-observation.rkt`:
  `(struct expression-type-observation (type signatures))`, built in
  `materialize-expression-observation-at-root-end!` from
  `type->datum`.
- `aloe/expression-query.rkt`:
  `(struct expression-query-result (type signatures location))`.
- `aloe/lsp.rkt`: `result-contents` writes `type: ` and the datum with
  `~s`, then `messages:` and the rows.
- Source pins to respect: `tests/editor/expression-query/001-contextual-observation.rkt`
  and `003-public-query.rkt` check that `aloe/type.rkt`,
  `aloe/main.rkt`, `aloe/driver.rkt`, and the public query module do
  not export the observation struct or the internal checker entry
  points. A test hook goes in a submodule, as 004 and 005 did.

### Scratch run

The manager implemented this layer on a copy of the repository: about
60 lines in `aloe/type.rkt` and a few each in the other three modules.
On that copy, before any test edit, **15 test files failed when each
was run alone**, all in `tests/editor/`, and nothing under
`tests/aloemacs/`, `tests/modules/`, or the global checkpoints:

- arity errors: tests that build `expression-type-observation` with two
  arguments or `expression-query-result` with three (most are LSP stub
  queries, whose failure shows up as a null hover);
- the five hover goldens spec §9.3 names, which gain a `from:` line;
- one leak check in `tests/editor/lsp/003-buffer-snapshots.rkt` that
  forbids any temporary-directory path in the protocol output, which
  the new `from:` line legitimately contains.

No existing test pins a full mismatch sentence for a class with a path.
The manager then applied **Migration** and added the four fixtures
below. The whole suite passed, each file run alone; the census passed
with the new fixtures. Every case in the focused proof was probed on
that copy with the exact text below. `tests/aloemacs/window-pictures.rkt`
ran at 28 ms alone, as before; this layer adds no evaluator work.

## Exact file scope

### May create or edit

- `aloe/type.rkt`, `aloe/private/checker-observation.rkt`,
  `aloe/expression-query.rkt`, `aloe/lsp.rkt`.
- `docs/editor/lsp/spec.md` (§7 and §10),
  `docs/editor/expression-query/spec.md` (§1), and
  `docs/decisions.md`: only the text in **Documents**.
- The fifteen test files in **Migration**, only as it says.
- `tests/modules/008-defining-path.rkt`: new.
- The four new fixtures under `tests/modules/fixtures/` in **Fixtures**,
  with exactly that content.

### Must leave untouched

- `aloe/eval.rkt`. The spec allows recording the path on
  `class-value` for parity; this checkpoint does not. Runtime classes
  record no path.
- `aloe/env.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/completion-query.rkt`, `aloe/parse.rkt`, `aloe/library.rkt`,
  every other module under `aloe/private/`, and every host module.
- `SPEC.md`.
- Every `.aloe` file under `examples/`, `lib/`, and `gel/`, and every
  existing fixture.
- Every test not in **Migration**, including
  `tests/parenthetical-construction/editor.rkt`, which reads the result
  through accessors.
- `CHECKPOINTS.md`, `docs/checkpoints/`, `docs/philosophy.md`,
  `docs/editor/completion/spec.md`, this folder's `README.md`,
  `charter.md`, `spec.md`, this checkpoint, and every other design
  document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Recording

Each checker class record stores a defining path, a resolved path or
`#f`:

- A class whose `define-class` is checked in a file environment, or in
  a local environment whose parent chain reaches one, records that file
  environment's `path`. So a class a nested load defines records that
  file's path on disk, a class a keyed root defines records the root's
  resolved path, and a class a queried buffer defines records the
  **identity path** (the document, never the temporary sibling): 006
  already keys the buffer's file environment by the identity path.
- A kernel class, a class defined at the prompt, a class from an
  unkeyed port, unkeyed `eval-source`/`typecheck-source`, or a raw
  environment records none.
- **Installed library** (spec §7.1, corrected): the base's `Option`
  records the resolved path of `lib/option.aloe`. A class that a
  queried base library's buffer defines (002's install from the buffer)
  records the identity path. The path must already be on that class
  when the query's observation is materialized during the check, so
  hover inside `lib/option.aloe` prints it.

In the manager's version, `class-info` gained a mutable last field,
`defining-path`. `check-class-definition!` filled it with the file path
found through the environment chain, else the value of a parameter
that `typecheck-keyed-buffer` binds to the resolved identity path
around the buffer check. `record-checked-option-class!` set
`lib/option.aloe`'s resolved path on a base `Option` that had none.

The cache key stays the resolved path. Nothing about loads, copies,
origins, or collisions changes.

### 2. The pathed datum

`type->datum` and its output are unchanged. A second rendering, the
pathed datum, has exactly the same shape, except that each class with a
defining path, wherever it appears (an instance type and its type
arguments, a `(Class X)` type, function parameter and result types,
`List` element types), is written as the symbol named
`Name@<displayed path>`:

| Expression, in a driver that loaded the named files | Plain datum | Pathed datum |
|---|---|---|
| `(1 + 2)` | `Int` | `Int` |
| `(Point new 1 2)` | `(Point Int)` | `(Point@examples/point.aloe Int)` |
| `(Option Some (Position new 0 0))` | `(Option Position)` | `(Option@lib/option.aloe Position@lib/text.aloe)` |
| `Point` | `(Class Point)` | `(Class Point@examples/point.aloe)` |
| `(List of (Box new))`, `Box` from a temporary `box.aloe` | `(List Box)` | `(List Box@<resolved temporary path>/box.aloe)` |
| `((Sum new (List of (Sym new "x")) 0) unwrap)` | `Math` | `Math` |

Protocols, type variables, method and class type parameters, host
interface names, and kernel types render as in the plain datum. The
pathed datum equals the plain datum exactly when no class in the type
has a path.

Expose it to tests as `type->pathed-datum` from a new submodule of
`aloe/type.rkt`, `(module* defining-path #f (provide type->pathed-datum))`.
Nothing else exports it.

### 3. Mismatches

Both sentences keep printing their two `type->datum` values with `~a`.
When the pathed datum of either side differs from its plain datum, the
sentence gains a space and a parenthesis holding the expected side's
pathed datum, ` vs `, and the got side's, each written with `write`
(`~s`):

```text
typecheck: type mismatch: expected Box, got Box (Box@tests/modules/fixtures/box-a.aloe vs Box@tests/modules/fixtures/box-b.aloe)
typecheck: type mismatch for with field held: expected (Option Position), got (Option Int) ((Option@lib/option.aloe Position@lib/text.aloe) vs (Option@lib/option.aloe Int))
typecheck: type mismatch: expected Position, got Int (Position@lib/text.aloe vs Int)
```

The contextual sentence is formatted from the whole types before
unifying; the plain sentence reports the innermost mismatch, which is
why `(check op oi)` for an `(Option Position)` and an `(Option Int)`
gives the third line. When neither side names a class with a path, the
sentence is unchanged. No other message changes.

### 4. The observation and the query result

- `expression-type-observation` gains a third field, `pathed-type`:
  `(type signatures pathed-type)`.
  `materialize-expression-observation-at-root-end!` builds it from the
  same checker type, in the same pass, as the plain datum.
  `make-checker-observation-api` receives the pathed rendering beside
  `type->datum`.
- `expression-query-result` gains a fourth field, `pathed-type`:
  `(type signatures location pathed-type)`. `query-expression-at` fills
  it from the observation.
- Completion results and signature rows do not print paths.

### 5. LSP hover

The hover value becomes:

1. `type: ` and the plain datum written with `write`;
2. when the result's `pathed-type` is not `equal?` to its `type`: a
   newline, `from: `, and the pathed datum written with `write`;
3. a newline and `messages:`, then the rows exactly as today, or
   `messages: none`.

```text
type: (Point Int)
from: (Point@tests/editor/lsp/fixtures/point.aloe Int)
messages:
  x : () -> Int
  y : () -> Int
  + : ((Point Int)) -> (Point Int)
  dist2 : ((Point Int)) -> Int
```

A stub result whose `pathed-type` equals its `type` renders exactly as
today. The adapter never prints a temporary sibling's path; the query
already renders the document's.

### 6. What stays

- 000–007's rules, unchanged.
- `type->datum`, signature rows, and completion items.
- `(Class String)` and other kernel hover text.

## Documents

`docs/editor/lsp/spec.md` §7:

- In the JSON example, the `value` string gains
  `from: (Point@tests/editor/lsp/fixtures/point.aloe Int)\n` right
  after `type: (Point Int)\n`.
- The numbered list becomes four items: item 1 unchanged; a new item 2,
  "when the query's `pathed-type` differs from its `type`, a newline,
  `from: `, and the pathed type datum written with `write`;"; then the
  current items 2 and 3 as items 3 and 4.
- "An empty signature list renders `messages: none` on the second
  line." becomes "An empty signature list renders `messages: none` in
  place of `messages:` and its rows."
- After "The adapter does not sort, deduplicate, group overloads,
  substitute types, or invoke signatures." add: "It prints a class's
  defining path only on the `from:` line, as the query renders it, and
  never a temporary sibling's path."

`docs/editor/lsp/spec.md` §10: the bullet "Changes to
`query-expression-at`, `srcloc`, type datums, or `signature-spec`"
becomes "Changes to `srcloc` or `signature-spec`; the `pathed-type`
field and `#:document-path` keyword are the modules series' additions
to `query-expression-at`".

`docs/editor/expression-query/spec.md` §1: the struct line becomes
`(struct expression-query-result (type signatures location pathed-type) #:transparent)`,
and the field list gains, after `location`, the item: "`pathed-type`:
the same datum with each class that has a defining path written
`Name@path`, the path repository-relative when inside the repository;
it equals `type` when no class has a path." (Adjust the "; and" between
items so the list still reads as one sentence.)

`docs/decisions.md`: add one section at the end, dated the day you
land it:

> ## Defining paths (YYYY-MM-DD)
>
> Decided: a class records the path of the file that defined it; hover
> and the `expected, got` mismatch print each class's
> repository-relative path as a second rendering; `type->datum` is
> unchanged. Rejected: paths inside `type->datum`, paths on rows and
> completion items, a decorative module name.

## Migration

The scratch run's inventory: these fifteen files and no others. Your
own per-file run after the product edit is the check.

### A. The observation gains a third field

Every positional construction of `expression-type-observation` gains a
third argument equal to its first (the observations these tests build
involve no class with a path):

- `tests/editor/completion/001-contextual-receiver.rkt` (1
  construction);
- `tests/editor/expression-query/002-rigid-generic-body.rkt` (9);
- `tests/editor/expression-query/001-contextual-observation.rkt` (14).
  In its case "observation bridge is narrow and the result field order
  is exact", the arity check becomes `3` and the `struct->vector`
  golden becomes
  `'#(struct:expression-type-observation Sample (row) Sample)`.

### B. The query result gains a fourth field

Every positional construction of `expression-query-result` gains a
fourth argument equal to its first, so each stub's hover text is
unchanged:

- `tests/editor/lsp/000-hover.rkt`, `001-utf16-positions.rkt`,
  `002-document-sync.rkt`, `003-buffer-snapshots.rkt`,
  `006-json-rpc.rkt`, `007-lifecycle.rkt`, `008-adapter-failures.rkt`
  (one `query:expression-query-result` each);
- `tests/editor/completion/003-lsp-completion.rkt` (one
  `hover:expression-query-result`);
- `tests/editor/expression-query/003-public-query.rkt` (one
  `public:expression-query-result`); its `struct->vector` golden
  becomes `'#(struct:expression-query-result A (rows) location A)`.

### C. Hover goldens gain a `from:` line

- `tests/editor/lsp/000-hover.rkt`, `005-framing.rkt`,
  `009-launch.rkt`: right after the line `"type: (Point Int)\n"` of the
  expected hover text, add
  `"from: (Point@tests/editor/lsp/fixtures/point.aloe Int)\n"`.
- `tests/editor/lsp/003-buffer-snapshots.rkt`, case "real query
  preserves relative disk loads without dirty overlays": right after
  `"type: LoadedFromDisk\n"` add
  `(format "from: ~s\n" (string->symbol (format "LoadedFromDisk@~a" (path->string support-path))))`.
- `tests/editor/lsp/004-hover-results.rkt`, case "real empty and
  overloaded catalogs render exactly in query order": right after
  `"type: Render004\n"` add
  `(format "from: ~s\n" (string->symbol (format "Render004@~a" (path->string path))))`.

### D. The leak check names the one allowed path

`tests/editor/lsp/003-buffer-snapshots.rkt`, same case: the assertion
`(check-false (string-contains? protocol-text (path->string directory)))`
forbids every temporary-directory path, and `support.aloe`'s disk path
now appears on the `from:` line by design. Replace it with:

```racket
;; Only support.aloe's own path, on the from: line, names the directory.
(check-false
 (string-contains?
  (string-replace protocol-text (path->string support-path) "")
  (path->string directory)))
```

Keep the `"aloe-lsp-snapshot"` check after it unchanged.

## Fixtures

New files under `tests/modules/fixtures/`, exactly as written. Each is
a census file. `box-a-maker.aloe` and `box-b-maker.aloe` export only
`a-box` and `b-box`, so loading both into one driver is not a
collision, while their values carry two different `Box` classes.

`box-a.aloe`:

```scheme
(define-class Box
  (fields)
  (methods))
```

`box-b.aloe`:

```scheme
(define-class Box
  (fields)
  (methods))
```

`box-a-maker.aloe`:

```scheme
(load "box-a.aloe")

(define a-box (Box new))
```

`box-b-maker.aloe`:

```scheme
(load "box-b.aloe")

(define b-box (Box new))
```

## Tests

### Focused proof: `tests/modules/008-defining-path.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. `type->pathed-datum` and
`expression-query-result-pathed-type` do not exist there, so for that
first run reach them with `dynamic-require` behind a fallback that
raises (as 005's and 006's implementers did) or the file will not
compile. **Every case fails on the found tree**: cases 1, 2, and 5–8
because the two names are missing, and cases 3 and 4 because the
messages lack the suffix. The `type->datum` column of case 1 already
holds.

Use fresh drivers unless a case says otherwise. Load a file with
`driver-eval!` of `(load "<absolute path>")`. Obtain types with
`type-of` of a parsed datum in `driver-type-environment`. Pin error
messages exactly, with the error kind.

1. **The pathed datum table.** In one driver, load
   `examples/point.aloe`, `lib/text.aloe`, `examples/mpl/core.aloe`,
   `examples/mpl/sym.aloe`, `examples/mpl/sum.aloe`, and a `box.aloe`
   written to a temporary directory under `/tmp` containing
   `(define-class Box (fields) (methods))`. For each row of the table
   in §2, `type->datum` is the plain datum and `type->pathed-datum` is
   the pathed datum, the `Box` row built from that file's resolved
   path.
2. **No path.** In that driver, after
   `(define-class Here (fields) (methods))` at the prompt, `(Here new)`
   has plain and pathed datum `Here`. After `driver-load-port!` without
   a source path of `(define-class Ported (fields) (methods))`,
   `(Ported new)` has plain and pathed datum `Ported`.
3. **The `Box` mismatch.** Load `box-a-maker.aloe`, then
   `box-b-maker.aloe` (no error); `(check a-box b-box)` raises
   `typecheck: type mismatch: expected Box, got Box (Box@tests/modules/fixtures/box-a.aloe vs Box@tests/modules/fixtures/box-b.aloe)`.
4. **The `(Option Position)` mismatches.** Load `lib/text.aloe`; at
   the prompt, `(define op (Option Some (Position new 0 0)))`,
   `(define oi (Option Some 1))`, and
   `(define-class OptHolder (fields (held (Option Position))) (methods))`.
   `((OptHolder new op) with (held oi))` raises
   `typecheck: type mismatch for with field held: expected (Option Position), got (Option Int) ((Option@lib/option.aloe Position@lib/text.aloe) vs (Option@lib/option.aloe Int))`;
   `(check op oi)` raises
   `typecheck: type mismatch: expected Position, got Int (Position@lib/text.aloe vs Int)`.
5. **Hover on a nested-loaded class, and on a kernel type.**
   `query-expression-at` on
   `tests/editor/expression-query/fixtures/003-public-query/root.aloe`
   at `(Loaded new 7)`: type `'Loaded`, pathed type
   `'Loaded@tests/editor/expression-query/fixtures/003-public-query/support.aloe`.
   At the `7` in that expression: type and pathed type `'Int`.
6. **Hover on a class the buffer defines.**
   `tests/editor/lsp/fixtures/point.aloe` at `(Point new 1 2)`: type
   `'(Point Int)`, pathed type
   `'(Point@tests/editor/lsp/fixtures/point.aloe Int)`.
7. **Hover inside a dirty `lib/text.aloe`, through a sibling.** Write a
   sibling file in a temporary directory under `/tmp` whose text is
   `lib/text.aloe`'s, with its `(load "option.aloe")` replaced by a
   load of `lib/option.aloe`'s absolute path (the sibling lives
   elsewhere, so a relative load would not resolve) and with
   `(define probe-008 (Position new 0 0))` appended. Query the sibling
   at that final `(Position new 0 0)` with `#:document-path` set to
   `lib/text.aloe`: type `'Position`, pathed type
   `'Position@lib/text.aloe`. The sibling's path does not appear.
8. **Hover inside `lib/option.aloe`.** `query-expression-at` on
   `lib/option.aloe` at `self` in `self case`: type `'(Option T)`,
   pathed type `'(Option@lib/option.aloe T)`.

The adapter's `from:` line is proven by the goldens in **Migration**
C.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/008-defining-path.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Then run every test file alone (each already compiled) and confirm each
exits 0; the parallel summary is not the inventory.
`tests/aloemacs/window-pictures.rkt` has a 30 ms timing bar. It has run
at about 28 ms alone since 006 and can exceed the bar under parallel
load; rerun it alone before calling it a failure.

After the `.rkt` edits, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt host/racket/gel-run.rkt bin/aloe`
and confirm `./bin/aloe --quit tests/modules/fixtures/box-root.aloe`
still prints `3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as you
  found it was reported;
- every test file passes, and the only edits to existing tests are the
  ones in **Migration**;
- the product files changed are only the four this checkpoint allows;
  no `.aloe` file under `examples/`, `lib/`, or `gel/` changed;
- the editor specs and `docs/decisions.md` carry exactly the text
  above;
- the whitespace check is clean (also for new, untracked files) and the
  file scope was respected.

Report the results and stop. Do not commit. Do not start layer 5.

## Non-goals

- Paths inside `type->datum`, on signature rows, or on completion items.
- A defining path on runtime class values, or on protocols.
- Any change to loads, the cache, origins, or the collision error.
- A module name separate from the path, or any decorative name.
- Splitting `file.aloe` or dropping any prefix (adoption, layer 5).
- Any `.aloe` change under `examples/`, `lib/`, or `gel/`.
