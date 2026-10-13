# Modules specification

**Status: Accepted for checkpoint planning.** The human authorized
the manager to proceed if the spec was ready. On 2026-10-13 the
manager checked §4 against the tree and probes of today's behavior,
found it ready, corrected the §4.1 rule 9 aside (hover inside
`lib/list.aloe` raises `ambiguous message: fold` today; it did not
"keep working"), and wrote
[`checkpoints/000-run-once.md`](checkpoints/000-run-once.md). This
file is the complete design input for the checkpoint manager and the
implementers. Neither reads the charter or the discussion
record. [`SPEC.md`](../../../../SPEC.md) remains language law; this
series amends it only in the checkpoints §12 names.
[`docs/workflow.md`](../../../workflow.md) is the process.

This series makes `load` the module system. The spelling stays
`(load "path.aloe")`. A resolved path runs once per base. A load
copies the names the loaded file defines, in a file and at the
prompt. A program with a source path is a file module. The resolved
path is the module's identity. Nothing else is added: no `import`,
no export list, no barrel, no prefix, no load path, no reload.

---

## 1. Checkpoint series

- **Identity:** `modules`. The first checkpoint is spoken
  **modules 000** and filed as
  `docs/design/implementation/modules/checkpoints/000-run-once.md`.
  Numbers have three digits, start at 000, and are never renumbered.
  Slugs are lowercase words joined by hyphens.
- **Project root:**
  `/home/dharmatech/journal/2026-09-02-aloe-racket`. Code, fixtures,
  and tests go under that root, never under this design folder.
  Tests for new behavior live under `tests/modules/`, one file per
  checkpoint named `tests/modules/NNN-slug.rkt` after the checkpoint,
  with Aloe fixtures under `tests/modules/fixtures/`.
- **Command.** From the project root:

  ```sh
  TMPDIR=/tmp raco test -j 4 -y <paths>
  ```

  `<paths>` is the checkpoint's test file, then `tests`. `-j 4` and
  `-y` are always included. Every checkpoint leaves the whole suite
  green before it is accepted.
- **Process.** The checkpoint manager writes one checkpoint and
  stops. A human reviews the implementation before the next number.
  The manager may split a layer or slice that exceeds one
  implementer conversation, keeping the order below and adding no
  feature. It may not merge the slices §1 marks as separate, and it
  does not issue the adoption checkpoint until the human asks for it
  (§10). Nothing from this series goes onto `CHECKPOINTS.md` or
  under `docs/checkpoints/` unless a human promotes it later.

**Order.** Layers, and within the visibility layer the slices, land
in this order. Each is green on its own.

| # | Layer or slice | Section |
|---|---|---|
| 1 | **modules 000 — run-once.** The per-base load cache, the changed-bytes error, the list, string, and int seeds. The shared environment stays. | §4 |
| 2 | **Explicit loads.** Every census file loads each file whose names it uses, while a load still includes. `Math` moves to its own file. Pins updated. A mechanical census test is required. May be split by tree: Aloemacs and `lib/`, then Gel, then MPL. | §5 |
| 3a | **`Option` on the base, and the base-library query.** `lib/option.aloe` is installed beside list, string, and int. `String find` returns that class. A query of one of the four library files installs it from the buffer's bytes. The query gains `#:document-path`. | §6.1 |
| 3b | **Overload identity.** Class and protocol parameters select by record, in the checker and the evaluator. `define-protocol` binds a runtime record. Its own checkpoint, after 3a. | §6.2 |
| 3c | **Method and protocol records.** Each method and each protocol records the environment that wrote it. Every annotation site reads that record. After 3b. | §6.3 |
| 3d | **Root-end conformance.** The protocol walk covers the cache, the file being checked, and the interactive environment. After 3c. | §6.4 |
| 3e | **File environments and the copy rule.** The checkpoint that is not split further. After 3d. 3c and 3d are not folded into it. | §6.5 |
| 3f | **Collisions.** Origins and the collision error. After 3e. | §6.6 |
| 4 | **Defining path.** Hover and mismatches print each class's path. Its own layer, after 3f, before adoption. | §7 |
| 5 | **Adoption.** `file.aloe` splits toward one class per file and the `Aloemacs` prefixes come off. Last, and only when the human asks. May be split by editor area. | §10 |

---

## 2. Vocabulary

These words are used with exactly these meanings below.

**Base.** The checker environment and the evaluator environment that
`make-driver` builds, and that `make-type-environment` and
`make-top-level-env` in `aloe/main.rkt` build. A base holds the
kernel bindings `dummy`, `List`, `Int`, `String`, `Symbol`, and
`Mirror`; the installed libraries (`lib/list.aloe`,
`lib/string.aloe`, `lib/int.aloe`, and from slice 3a
`lib/option.aloe`); and the hosts `driver-inject-host!` writes. User
definitions never live on the base. `fold` is a method on the base's
`List` class object, not a binding. The raw constructors
`make-type-environment` in `aloe/type.rkt` and `make-top-level-env`
in `aloe/env.rkt` build kernel environments with no install; they
carry the same fields as a base, empty.

**Interactive environment.** One per base. Its parent is the base.
The REPL, `driver-eval!`, `driver-prepare!`, an unkeyed port, and
`eval-source`, `typecheck-source`, `eval-datum`, and `eval-program`
without a source path evaluate there. It exists as a separate object
from slice 3e. Until then the one shared environment is the base and
the interactive environment at once.

**File environment.** From slice 3e. A file module's own environment.
Its parent is the base. It records the file's resolved path. Every
keyed root and every nested load has one.

**Local environment.** The scopes `fn`, method bodies, `let`, and
`case` clauses create. Unchanged.

**Root check.** One `typecheck-program` call entered at depth zero.
`driver-load-port!`, `driver-load-file!`, `typecheck-source`,
`eval-source`, `eval-program`, the hover and completion queries, and
a `load` datum checked through `type-of` (`driver-eval!`,
`driver-prepare!`, `eval-datum`) each enter one. A nested load is
not a root. The conformance walk runs when a root check finishes.

**Keyed root.** A root that carries a source path: `driver-load-file!`;
`driver-load-port!` with `#:source-path`, including
`host/racket/term-run.rkt`; `typecheck-source` and `eval-source` with
`#:source-path`; and, from slice 3e, the two editor queries. Its key
is the resolved form of that path, whether or not a file exists
there. Its bytes are the bytes read from the file or the port.

**Unkeyed port.** `driver-load-port!` without a source path, a string
given to `eval-source` or `typecheck-source` without a source path,
and the REPL. Never a cache entry. Its own definitions run again if
the same text is loaded again. Loads nested inside it are keyed.

**Resolved path.** For a `load`, what `load-expr-resolved-path`
already returns: `simplify-path` of `path->complete-path` against the
loading file's directory, without consulting the filesystem. Roots
and library paths resolve the same way. Two spellings of one file are
one key. Keys compare with `equal?`, as the cycle stack does today.

**Displayed path.** The resolved path relative to the repository
root, written with `/` separators, when the resolved path is inside
that root; otherwise the resolved path as a string. The repository
root is the parent of the `aloe/` directory, found from the runtime
path `aloe/library.rkt` already uses to reach `../lib/`. Every new
message in this series prints displayed paths. The existing
`load file not found: ~a` and `load cycle: ~a` keep today's resolved
path.

**Cache, entry, exports.** Each base has one checker cache and one
evaluator cache, keyed by resolved path. A cache is a field of the
environment struct, shared by reference with that base's interactive,
file, and local environments, the way `int-class` and `string-class`
are propagated today. A child environment has no cache of its own. A
new driver, each `aloe/main.rkt` construction, and each editor
query's fresh base start with an empty cache; the seeds in §4.3 are
then recorded. An entry is *running* from the moment a load or keyed
root starts until it finishes, then *completed*. A checker entry
stores the source bytes and the file's exports. An evaluator entry
stores the file's exports. Exports are the bindings the file itself
made with `define`, `define-class`, and `define-protocol`, in
definition order, each with its origin. Until slice 3e an entry's
exports are empty, because a load still writes into the shared
environment.

**Origin.** From slice 3f. Each binding in an interactive or file
environment records where it was defined: the resolved path of the
defining file, or `prompt`. A binding copied by a load keeps the
origin of the file that defined it. A base binding's origin is the
library's path for an installed class (`Option`) and `base` for a
kernel binding or an injected host.

**Defining path.** From layer 4. A class record stores the resolved
path of the file environment that checked its `define-class` form.
Kernel classes, classes defined at the prompt, and classes defined
in an unkeyed port store none.

---

## 3. Product boundary

**In this series.**

- `load` runs a resolved path once per base, in the checker and the
  evaluator. The checker rejects a second load of changed bytes.
- A load copies the loaded file's own `define`, `define-class`, and
  `define-protocol` bindings into the loader, and nothing it only
  received from its own loads. The rule holds in a file and at the
  prompt, for `driver-load-file!`, a keyed port, and `eval-source` or
  `typecheck-source` with `#:source-path`.
- A file module's environment is a child of the base. The prompt is
  not a file; its parent is the base.
- `lib/option.aloe` is installed on the base. `String find` returns
  that class.
- Overload selection compares class records and protocol records.
- A method body and the types in its signature are checked and
  evaluated in the file that wrote the method. A protocol's
  signatures resolve in the file that wrote the protocol.
  `define-methods` still mutates the one shared class record and
  binds no name.
- Conformance runs at the end of each root check, over every class
  the base's cache, the file being checked, and the interactive
  environment hold.
- Two files that export one name collide where they meet, with an
  error that names both origins.
- Hover and type mismatches print each class's displayed path.
- `examples/aloemacs/file.aloe` splits toward one class per file and
  drops the `Aloemacs` prefixes, last, when the human asks.

**Not in this series.** None of these appears in any checkpoint. A
checkpoint that adds one is defective.

- `import`, a prefix clause, qualified sends such as `(fs Path)`.
  The sketch under `archive/design-sketches/2026-10-08-aloemacs-modules/`
  is a rejected spelling.
- Export lists, private names, barrel files.
- A load path, packages, versions, a module name separate from the
  path.
- `prefix`, `only`, `rename`.
- Reload of an edited file, dependent invalidation, or any second
  load of changed bytes that succeeds. The changed-bytes error is the
  whole of that behavior.
- A process-wide load cache. A byte comparison in the evaluator.
- Per-importer method tables, scoped selectors.
- Changing `Mirror invoke`, `Signature accepts?`, or sole-method
  dispatch off short-name comparison. `Signature` still reifies
  types as symbols; two classes that share a short name can still
  pass `accepts?`.
- Macros. Concurrency, threads, several interactive programs in one
  process. Writing a one-process goal into `docs/philosophy.md`.
- Renaming Gel or any Gel prefix, or loading `lib/text.aloe` from
  Gel.
- Dirty-buffer overlays for nested loads. Editor features, keymap
  changes, window changes.
- Promoting the series onto `CHECKPOINTS.md`.

---

## 4. Layer 1 — modules 000: run-once

Filed as `checkpoints/000-run-once.md`. Test file
`tests/modules/000-run-once.rkt`. Allowed product files:
`aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/library.rkt`,
`aloe/main.rkt`, `aloe/driver.rkt`, `SPEC.md`, `docs/decisions.md`.
No `.aloe` file changes. The editor queries, `aloe/lsp.rkt`,
`aloe/expression-query.rkt`, and `aloe/completion-query.rkt` are not
edited.

### 4.1 Rules

1. **One cache per base, in each half.** The checker's cache lives on
   the checker base; the evaluator's on the evaluator base. Both
   constructions in `aloe/main.rkt` and `make-driver` carry them. The
   raw constructors carry the field, empty.
2. **The checker owns the changed-bytes rule.** When a `load` or a
   keyed root reaches a path:
   - no entry: read the file's bytes, record a running entry with
     those bytes, parse and typecheck the expressions (a nested load
     at the current depth plus one, as today), then mark the entry
     completed;
   - a completed entry whose bytes equal the bytes now on disk (or
     now on the port): a *hit*. Nothing is read further, parsed, or
     checked. The load is `Void`;
   - a completed entry whose bytes differ: the error in §4.2, raised
     before anything from the new bytes is parsed or installed.
     Previous bindings stay as they were;
   - a running entry: today's `load cycle` error.
   The criterion is the bytes, never a modification time.
3. **The evaluator reuses by path only.** A completed evaluator entry
   is a hit without a byte comparison; nothing runs. A running entry
   is today's cycle error. The evaluator relies on the checker having
   checked the whole program first, which `driver-load-port!`,
   `driver-load-file!`, `eval-source`, `eval-program`, and
   `driver-eval!` already guarantee.
4. **A failed entry is removed.** If the check of a load or keyed
   root raises, the checker's running entry is removed, so a later
   load tries again. If the evaluation raises, the evaluator's
   running entry is removed; definitions it already made stay, as
   they do today.
5. **A hit binds nothing new** in this layer, because the first load
   already wrote every nested name into the shared environment.
6. **`driver-load-file!` on a hit** returns `'()` and writes nothing.
   `(load ...)` evaluates to void in both cases.
7. **Missing files, cycles, and path resolution are unchanged.**
8. **`driver-prepare!` is unchanged.** Its thunk's first run may read
   a loaded file whose check happened earlier; a change between the
   check and the run is outside this series.
9. **The editor queries are not keyed in this layer.** Hover and
   completion still typecheck the queried file's expressions into
   the query's fresh environment exactly as today. Loads nested in
   that file use the cache. (A query of `lib/list.aloe` therefore
   behaves as today: the root check appends the list methods a
   second time, which raises `ambiguous message: fold`. Slice 3a
   makes that query resolve.)

### 4.2 Error text

The changed-bytes error is a type error (`exn:fail:aloe-type`) with
this message, where the path is the displayed path:

```text
typecheck: load file changed: lib/text.aloe; this version does not reload a changed file
```

### 4.3 Seeds

`make-driver`, `make-type-environment`, `make-top-level-env`, and the
`type-environment-for` fallback in `aloe/main.rkt` install
`lib/list.aloe`, `lib/string.aloe`, and `lib/int.aloe` exactly as
today, and then record each as a completed entry in both caches,
keyed by that library's resolved path, with empty exports. The
checker entry stores the bytes that install read.
`aloe/library.rkt` therefore reads each library file once per process
into bytes and parses the expressions from those bytes, with the
library path as `#:source-path`; it exposes both the expressions and
the bytes. The promise stays a process-wide read of parsed
expressions; it is not a cache entry.

Consequences, all tested:

- A later `(load "lib/list.aloe")` of the same bytes is a hit:
  `define-methods List` does not run again, and the `List` method
  table has the same length before and after.
- A later load of different bytes at that path is the changed-bytes
  error.
- Two drivers do not share a class or an entry.

`lib/option.aloe` is **not** a seed in this layer.

### 4.4 Keyed roots and unkeyed ports

A keyed root (§2) is a cache entry under its resolved path, with the
bytes it was read from. A second `driver-load-file!` of the same path
into one driver is a hit. A keyed root whose path has no file on disk
(`tests/checkpoint-86.rkt` passes `#:source-path "bad-terminal-program"`
with a string port) is keyed by that resolved name and its bytes come
from the port. An unkeyed port is never an entry.

### 4.5 Required tests (`tests/modules/000-run-once.rkt`)

Fixtures under `tests/modules/fixtures/`. The reproductions are the
three the discussion recorded; each must fail before this checkpoint
and pass after it.

1. **`Box`.** A fixture defines `Box`. Load it, define a top-level
   `Box` value, load the fixture again, pass the value where `Box` is
   expected. Typechecks and runs; the two class records are `eq?`.
2. **`(Option Int)`.** The same shape with `lib/option.aloe` and
   `(Option Some 1)`.
3. **Keymap order.** A command fixture defines `Command`; a keymap
   fixture loads the command fixture and builds a list of commands.
   Load the keymap fixture, then the command fixture again, then a
   third file that loads the command fixture because it mentions
   `Command` and sends a method to an element of the list. All of it
   typechecks and runs.
4. **Changed bytes.** Write a fixture to a temporary directory, load
   it, rewrite it with different bytes, load it again: the exact
   error of §4.2 with that file's displayed path, the first
   definitions still bound, nothing from the new bytes bound. Then
   rewrite the original bytes and load again: a hit.
5. **Two spellings, one key.** A relative spelling and an absolute
   spelling of one fixture, loaded in turn, run the file once.
6. **Seeds.** The three consequences in §4.3, for each of the three
   libraries.
7. **Diamond.** Loading `lib/text.aloe` and `lib/fs.aloe` into one
   driver evaluates `lib/option.aloe` once; `Option` is one class.
8. **Cycle and missing file.** The existing errors still fire,
   through `tests/fixtures/load-cycle-a.aloe` and a missing path.
9. **Unkeyed port.** `driver-load-port!` without a source path, run
   twice with the same text, runs its definitions twice; a load
   nested in that text runs once.
10. **Keyed port.** `driver-load-port!` with `#:source-path` twice is
    one run and one hit; `driver-load-file!` twice returns `'()` the
    second time.
11. **Checker first.** With the evaluator's entry present and the
    file changed on disk, a `driver-eval!` of the load raises the
    changed-bytes error and evaluates nothing.
12. **Two bases.** A second `make-driver` starts empty and loads the
    fixture again, producing a class that is not `eq?` to the first
    driver's.

### 4.6 Existing tests that load one path twice into one environment

Today these second loads re-run the file and rebuild its classes.
After this checkpoint they are hits. None of them observes the
re-run on purpose; the suite run is the proof.

- **The `lib/option.aloe` diamond** under `examples/aloemacs/file.aloe`
  (through `editor.aloe` → `lib/text.aloe` and through
  `lib/fs.aloe`): every test under `tests/aloemacs/` that loads
  `file.aloe` or `main.aloe`, `tests/parenthetical-construction/session.rkt`,
  and `host/racket/aloemacs-run.rkt`. Also `tests/checkpoint-105.rkt`,
  `tests/checkpoint-106.rkt`, and `tests/checkpoint-107.rkt` in the
  cases that load `lib/disk.aloe` and `lib/fs.aloe` into one driver.
- **A root loaded after a nested load of the same file:** the editor
  tests that load `file.aloe` and then `main.aloe` into one driver
  (those that name both roots are listed in §9.1; whether each uses
  one driver or two is read from the test), `tests/aloemacs/next-lines.rkt`
  and `tests/aloemacs/text-line-length.rkt` (`lib/text.aloe` then
  `editor.aloe`), and `tests/editor/completion/002-public-query.rkt`
  and `003-lsp-completion.rkt` (`examples/point.aloe` directly and
  through `boids.aloe`).
- **No test loads a path twice on purpose.** The test case named
  "classes and constants load twice" in `tests/aloemacs/keymap-session.rkt`
  builds a fresh driver per iteration and is unaffected.

### 4.7 `SPEC.md` and `docs/decisions.md`

See §12, row 000.

### 4.8 Acceptance

The twelve tests above pass; the whole suite is green; no `.aloe`
file changed; the queries are untouched; no name a load introduces
has changed.

---

## 5. Layer 2 — explicit loads

While a load still includes everything, every census file comes to
load each file whose names it uses. This layer cannot precede
modules 000: under today's `load`, a second load of a file whose
values already exist creates a new class; run-once makes those lines
reuse. Allowed product files: the `.aloe` files named below, the new
`examples/mpl/math.aloe`, the test pins in §5.4, and the census test
of §5.5. No Racket module under `aloe/` is edited.

### 5.1 The census

The census is every `.aloe` file under `examples/`, `lib/`, `gel/`,
and the fixtures under `tests/` that the suite loads. `archive/` is
not edited. A string evaluated in the interactive environment is not
a census entry.

For each census file, its **free names** are the names it references
that it does not define itself, that are not on the base, and that
no file it loads directly defines. A reference is: a symbol in
expression position; a class or protocol name in a field type, a
parameter type, a return type, a `fn` annotation, a `define-class`
protocol position, or a `define-methods` target. Selectors,
constructor selectors in sends and `case` clauses, `new*` and `with`
field labels, payload binders, method parameters, `let` names, `fn`
parameters, `self`, class and method type parameters, and the kernel
type names `Int`, `Float`, `Bool`, `String`, `Symbol`, `Mirror`, and
`Signature` are not references. `Option` is not counted in this
layer (it becomes a base name in slice 3a and already reaches every
file through `lib/option.aloe`). `term` and `fs-host` are injected
hosts, on the base.

After this layer every census file has no free names.

### 5.2 Loads this layer adds

| File | Names it uses from elsewhere | Adds |
|---|---|---|
| `examples/aloemacs/file.aloe` | `Text`, `Position`, `Span` | `(load "../../lib/text.aloe")` |
| `examples/aloemacs/main.aloe` | `AloemacsEditor`; `Text`, `Position`; `Path`, `Fs` | `(load "editor.aloe")`, `(load "../../lib/text.aloe")`, `(load "../../lib/fs.aloe")` |
| `gel/loop.aloe` | `GelRow`, `gel-rows` | `(load "menu.aloe")` |
| `gel/main.aloe` | `GelStack` | `(load "stack.aloe")` |
| `examples/mpl/core.aloe` | `Math` (now in `math.aloe`) | `(load "math.aloe")` in place of the protocol form |
| `examples/mpl/sym.aloe`, `sum.aloe`, `num.aloe` | `Math` | `(load "math.aloe")` |
| `examples/mpl/prod.aloe`, `pow.aloe` | `Math`, `Num` | `(load "math.aloe")`, `(load "num.aloe")` |
| `examples/mpl/identities.aloe` | `Sym` | `(load "sym.aloe")` |

No other census file has a free name. In particular `editor.aloe`,
`lib/text.aloe`, `lib/fs.aloe`, and `lib/disk.aloe` use `Option`
only, which this layer skips; `examples/boids.aloe` already loads
`point.aloe`; `gel/stack.aloe` already loads `menu.aloe`.

The new leading datums, in this order:

- `examples/aloemacs/file.aloe`: `(load "editor.aloe")`,
  `(load "../../lib/text.aloe")`, `(load "../../lib/fs.aloe")`.
- `examples/aloemacs/main.aloe`: `(load "file.aloe")`,
  `(load "editor.aloe")`, `(load "../../lib/text.aloe")`,
  `(load "../../lib/fs.aloe")`, then the `define`.
- `gel/loop.aloe`: `(load "stack.aloe")`, `(load "menu.aloe")`.
- `gel/main.aloe`: `(load "loop.aloe")`, `(load "stack.aloe")`.

A name used in a loaded file and defined in the file that loads it
cannot be repaired by a load of that loader: a load back is a cycle.
That is the `Math` case, and the move in §5.3 is the only repair this
layer makes. This layer does not split `file.aloe` and does not drop
a prefix. Adding the `lib/text.aloe` load to `file.aloe` is not that
split.

### 5.3 The `Math` file

`examples/mpl/math.aloe` is new and contains exactly the
`define-protocol Math` form that opens `examples/mpl/core.aloe`
today, moved verbatim. `core.aloe` then begins with
`(load "math.aloe")`, followed by its five class loads and its
`define-methods` forms, unchanged. Each class file begins with
`(load "math.aloe")`; `prod.aloe` and `pow.aloe` follow it with
`(load "num.aloe")`. Under run-once, the repeated loads of
`math.aloe` are hits.

### 5.4 Pins to update

These tests pin the leading datums of `file.aloe` as
`(take datums 2)` or `(take source 2)` equal to
`'((load "editor.aloe") (load "../../lib/fs.aloe"))`. Each becomes
the three datums of §5.2, taken with `3`:

`tests/aloemacs/buffer-value.rkt`, `completion-page-session.rkt`,
`completion-session.rkt`, `minibuffer-value.rkt`,
`mode-buttons-paint.rkt`, `mode-line-row.rkt`,
`prompt-commands-find-file.rkt`, `window-bars-one-view.rkt`,
`window-bars-split.rkt`, `windows-buffer-identity.rkt`,
`windows-delete-and-other.rkt`,
`windows-layout-and-rendering.rkt`, `windows-lock.rkt`,
`windows-split.rkt`, `windows-state-foundation.rkt`,
`windows-state.rkt`.

`tests/aloemacs/runner.rkt` pins the whole of `main.aloe` as
`expected-main-datums`; its leading `(load "file.aloe")` gains the
three loads of §5.2 after it. The datum in
`tests/editor/source-locations/000-spans.rkt` that reads
`(load "lib/option.aloe")` is a grammar sample, not a pin, and does
not change. The lists of `define-class` names those same tests pin
do not change in this layer.

The implementer confirms the list against the tree: the suite run
after the product edit is the inventory, and a pin hidden behind a
helper counts.

### 5.5 Required census test

This layer adds `tests/modules/NNN-census.rkt` (numbered after its
checkpoint). Under inclusion a missed load still typechecks, so the
suite cannot see one until slice 3e, which is not split; the census
test is what proves this layer in the checkpoint that can still add
a load. It reads every census file as datums and checks §5.1
mechanically: for each file, the set of references minus its own
definitions, minus the base names, minus the definitions of its
direct loads, is empty. It walks the grammar of `SPEC.md` §4 (the
special forms, `case`, `new*`, and `with` in selector position, and
sends) and the type grammar of §5.1. It does not add a checker that
walks identifiers to the language; it is a test over source text.
When a tree is split into its own checkpoint, the test covers the
trees landed so far.

The census is a name check and nothing more. `define-methods` exports
no name, so a load whose purpose is to run methods is invisible to
it: `examples/mpl/identities.aloe` keeps `(load "core.aloe")` so the
protocol methods are added, and adds `(load "sym.aloe")` so the name
`Sym` is copied; an empty census would still pass if the `core.aloe`
load were dropped. The suite is the other half of this layer's
acceptance, and this layer removes no existing load.

### 5.6 Acceptance

The census test passes for every file; the suite is green; the pins
in §5.4 are updated; no existing load was removed; no Racket module
under `aloe/` changed. The visibility layer going green remains the
proof that file environments accept the suite.

---

## 6. Layer 3 — visibility

Each slice is its own checkpoint. 3a already carries the editor
query and `#:document-path`, so it does not share a checkpoint with
3b. Each is green before the next. Until slice 3e there is one shared
environment, so slices 3b, 3c, and 3d change identity rules and
record keeping without changing which names a program sees.

### 6.1 Slice 3a — `Option` on the base, and the base-library query

Allowed product files: `aloe/library.rkt`, `aloe/main.rkt`,
`aloe/driver.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/env.rkt`,
`aloe/expression-query.rkt`, `aloe/completion-query.rkt`,
`aloe/lsp.rkt`, `SPEC.md`, `docs/decisions.md`,
`docs/editor/lsp/spec.md` §5, `docs/editor/expression-query/spec.md`,
`docs/editor/completion/spec.md`, and the tests named below.

**Install.** `aloe/library.rkt` reads `lib/option.aloe` through the
same read-once promise shape as the other three, exposing expressions
and bytes. `make-driver`, `make-type-environment`,
`make-top-level-env`, and the `type-environment-for` fallback
install it after `lib/int.aloe`, in the checker and the evaluator,
and record it as a completed entry under its resolved path, with
`Option` as its one export and the install's bytes. No other library
is added. Raw constructors install nothing.

**The base's `Option`.** Each base records the installed `Option`
class in a field beside `int-class` and `string-class`, propagated to
child environments the same way. `String find` builds `(Option Int)`
from that field in the checker and constructs `Some`/`None` from it
in the evaluator. It does not look `Option` up by name, so a
prompt-defined `Option` does not change what `find` returns. A raw
environment with no install rejects `find` as it does today (no
base `Option`).

**Loads of `option.aloe` stay.** `lib/text.aloe`, `lib/fs.aloe`, and
`lib/disk.aloe` keep `(load "option.aloe")`; every such load is a hit
of the installed entry. The census does not add a load of
`lib/option.aloe` anywhere.

**A base library queried in the editor.** The identity path of a
query is the document's real path; the resolution path is the file
actually read, which may be the temporary sibling the LSP adapter
writes for a dirty buffer. When the identity path resolves to one of
`lib/list.aloe`, `lib/string.aloe`, `lib/int.aloe`, or
`lib/option.aloe`:

- the query's fresh base installs the other three libraries from the
  promises, in their usual order, and then installs the queried
  library **from the buffer's bytes** (the expressions read from the
  resolution path, or `source` for completion), last, with the
  observer active;
- that install is the root check. The buffer is not checked a second
  time, and it is not a second definition of the class;
- the entry recorded for the identity path holds the buffer's bytes.
  They are not a changed-bytes error against the file on disk;
- the process-wide promise is untouched.

So hover inside `lib/option.aloe` resolves, clean or dirty, and an
unsaved edit is what hover sees. The same holds for the other three.

**API.** `query-expression-at` gains an optional keyword
`#:document-path`, a `path-string?` that defaults to the positional
path. It is the identity path: in this slice the key under which a
base library's buffer is installed; from slice 3e the cache key of
every query root; from layer 4 the defining path of the classes the
buffer defines. Loads
nested in the buffer still resolve from the resolution path's
directory. `aloe/lsp.rkt` passes `#:document-path` with the
document's local path when it queries through a snapshot; when the
buffer matches disk it calls the query as today. The injected query
procedures that `run-lsp-server/with-query` and
`run-lsp-server/with-queries` accept therefore take the keyword when
called through a snapshot; test stubs on that path accept
`#:document-path`. `query-selector-completions` already receives the
document path as `#:source-path`; that path is its identity path and
`source` its bytes. Neither query's root is otherwise keyed in this
slice (that is 3e).

**Tests** (`tests/modules/NNN-option-base.rkt`, number after the
checkpoint): a fresh driver binds `Option` and not `Some` or `None`;
`String find` returns a value whose class is `eq?` to the base's
`Option`, in a driver, in `eval-source`, and after the prompt
defines its own `Option`; a `(load "lib/option.aloe")` is a hit;
`lib/text.aloe` and `lib/fs.aloe` loaded into one driver share the
installed class; the `Option` goldens of `SPEC.md` §9 still run at
the prompt with a prompt-defined `Option`; hover inside
`lib/option.aloe` at its real path returns a result whose type is
`(Option T)` or a method type as selected; hover inside a dirty
`lib/option.aloe` through a sibling snapshot returns the edited
buffer's answer; hover inside `lib/list.aloe` resolves; completion
inside `lib/string.aloe` with `#:source-path` resolves.

**Existing tests that change.** `tests/checkpoint-100.rkt` asserts
`Option` is absent from a fresh driver and present after a load; the
first assertion inverts, the rest holds. The LSP tests whose stub
queries are reached through a snapshot accept the keyword:
`tests/editor/lsp/001-utf16-positions.rkt` and
`tests/editor/lsp/003-buffer-snapshots.rkt` today; the implementer
confirms by running the suite.

**Documents.** `docs/editor/lsp/spec.md` §5 gains one sentence after
"The adapter does not copy, parse, or rewrite `load` forms.":
"When it queries through a sibling, it passes the document's own
path as `#:document-path`, so the query keys and names the buffer by
the document, not the sibling." `docs/editor/expression-query/spec.md`
§1 adds the keyword to the signature and this paragraph after the
`position` paragraph: "`#:document-path`, when supplied, is the
path the query treats as the file's identity: its load-cache key
and the defining path of classes it defines. It defaults to the
normalized source path. Loads still resolve relative to the source
path's directory." `docs/editor/completion/spec.md` §1 adds after
the `source-path` paragraph: "`source-path` is also the buffer's
identity. When it names one of the base libraries, the query
installs that library from `source` instead of the file on disk, and
checks it once." `SPEC.md` and `docs/decisions.md`: §12, row 3a.

### 6.2 Slice 3b — overload identity

Allowed product files: `aloe/type.rkt`, `aloe/eval.rkt`,
`aloe/env.rkt`, `SPEC.md`, `docs/decisions.md`, and the tests named
below. Its own checkpoint, after 3a.

**Checker.** Two `protocol-type` records unify only when they are
`eq?`. Today `unify-types!` compares protocol names; that branch
compares records. Class identity already compares `class-info`
records with `eq?` and does not change. Overload selection
(`select-method-overload`, `match-sole-method`, `try-method-match`)
is therefore record-based for classes and protocols alike. In this
slice the annotations still resolve in the one shared environment,
through `type-from-sexpr` in the environment of the send, as today.

**Evaluator.** `define-protocol` binds a runtime protocol record
under the protocol's name in the defining environment and still
evaluates to void, as `define-class` does. A `define-class` with a
protocol looks the name up in its environment at evaluation time and
stores the record in the class record's protocol field; an unbound
name is the ordinary unbound-symbol error, which only a raw
evaluation that skipped the `define-protocol` can reach. Overload selection with more than one
candidate of the right selector and arity resolves each parameter
annotation, in this slice in the environment of the send:

- a symbol bound to a class record: match when the argument's class
  is `eq?` to it (specificity 2);
- a symbol bound to a protocol record: match when the argument's
  class record holds a protocol `eq?` to it (specificity 1);
- a list annotation whose head is bound to a class record: the head
  must be `eq?` to the argument's class; the arguments then match as
  today, including the accepted `(Point Int)` spelling on a
  non-generic class;
- a symbol that is not bound to a class or protocol record (`Int`,
  `String`, `Mirror`, `Bool`, `Float`, `Symbol`, `Signature`, a
  method or class type parameter, `->`, `List`): today's comparison,
  unchanged.

A **sole** candidate (one method with the selector and arity),
`Mirror invoke`, and `Signature accepts?` keep today's comparison of
an annotation symbol to the short name. Where those paths compare
against the class's protocol, they compare against the protocol
record's name. `make-list-value`'s element-protocol check compares
records, so two classes that opted into different protocols of one
short name are no longer one list element type.

**Tests** (`tests/modules/NNN-overload-identity.rkt`): in one
environment, define protocol `P`, class `A P`, a `Box` with
`(wrap (x P) P x)`, a value `v` of static type `P`; define `P` again
and class `B P`; then `(check v ((Box new) wrap (B new)))` is the
type error "check operands must have the same type" (today it
typechecks and fails at run time); a class defined after the second
`P` with overloads `(m (x P) ...)` and `(m (x Int) ...)` rejects
`(c m v)` as an unknown message; in a raw evaluator environment
(`eval-expr` directly), the same shapes select by record: the `P`
overload runs for a `B` and does not run for an `A`; a class
parameter overload runs only for an instance of the `eq?` class; a
sole method still accepts an instance by short name; `Mirror invoke`
and `Signature accepts?` behave as before; `(define-protocol P)` at
the prompt still evaluates to void and binds `P`.

### 6.3 Slice 3c — method and protocol records

Allowed product files: `aloe/type.rkt`, `aloe/eval.rkt`,
`aloe/env.rkt`, `aloe/private/checker-observation.rkt` if the
observation needs the record, and the tests named below. After 3b.

**Storage.** Per method. Each class record, in the checker
(`class-info`) and the evaluator (`class-value`), and each of the
three primitive class objects (`List`, `Int`, `String`, in both
halves), keeps a table from method declaration to the environment
that wrote it. The class form records its own environment for the
methods written inside it. Each `define-methods` form records the
environment it is evaluated or checked in for each method it
appends. A later `define-methods` does not change the environment of
the methods already there. The single `environment` field on the
primitive class objects is replaced by the table; `define-methods` on
`List`, `Int`, or `String` no longer overwrites a shared field.

A `protocol-type` (checker) and the runtime protocol record from 3b
each record the environment that wrote the protocol.

In this slice every recorded environment is the shared one, so
nothing a program sees changes. The suite is the proof.

**Evaluator.** A method body runs in a local environment whose parent
is the method's recorded environment: `apply-method`,
`apply-list-method`, `apply-int-method`, and `apply-string-method`
read the table instead of the class's `environment` field. The 3b
overload lookup resolves each parameter annotation in the method's
recorded environment instead of the environment of the send; the
send's environment is no longer consulted for selection.

**Checker.** Every site that turns an annotation into a type reads
the record:

- parameter and return annotations in `match-sole-method`,
  `try-method-match`, `infer-instance-send` (the return type),
  `infer-defined-list-method`, `infer-defined-int-method`,
  `infer-defined-string-method`: the method's environment;
- `infer-protocol-send`: the protocol's environment;
- `method-signature-conforms?`: the protocol's annotations in the
  protocol's environment, the method's annotations in the method's
  environment;
- `check-method-body!`, including the deferred re-check of a generic
  class with an implicit constructor that `infer-instance-send`
  performs with the call's substitution (`AloemacsSession` and `Fs`
  are such classes): the method's environment;
- field annotations in `infer-construction`, `infer-with`,
  `infer-case` payload binders, `infer-field-type!`, and field access
  in `infer-instance-send`: the class form's environment.

Argument expressions still infer in the caller's environment.
`check-class-definition!` and `check-method-types!` already receive
the environment of the form being defined and are not retargeted.

**Tests** (`tests/modules/NNN-method-records.rkt`): a class defined,
then `define-methods` in the same environment, then a send of each
method: both run, and the records are the shared environment; the
`List`, `Int`, and `String` tables hold one environment per method
and a second `define-methods` leaves the first group's record alone;
the MPL workbook still runs; the generic re-check still fires for an
`AloemacsSession` send from the prompt. The test may read the table
through a test-only accessor the checkpoint names.

### 6.4 Slice 3d — root-end conformance

Allowed product files: `aloe/type.rkt`, `SPEC.md`, and the tests
named below. After 3c.

Conformance runs once per root check, after that root's forms have
run, as today. The set it walks changes from "the environment's
parent chain" to:

- every class exported by a completed entry in the checker's cache;
- every class bound in the file environment being checked (until
  3e, the shared environment);
- every class bound in the interactive environment (until 3e, the
  same environment).

Each class is checked once (dedupe by record). For each protocol
signature of a class's protocol, some method conforms, with the
protocol's annotations resolved in the protocol's recorded
environment and the method's in the method's recorded environment
(3c). The error text is unchanged. Conformance does not run at the
end of a nested load; a `define-methods` in the root that supplies
the protocol methods is part of the root's forms, so a class the
root did not define is still accepted. Until 3e the walk accepts
exactly the programs the chain walk accepts.

**Tests** (`tests/modules/NNN-conformance.rkt`): the MPL shape — a
loaded class whose protocol methods arrive through the root's
`define-methods` conforms; the same class without those forms is the
existing "does not implement protocol" error at the root's end, not
at the loaded file's end; hover inside `examples/mpl/sym.aloe` is
JSON null (`Sym` is bound in the queried file and the protocol
methods are absent); hover inside `examples/mpl/core.aloe` resolves.

### 6.5 Slice 3e — file environments and the copy rule

The checkpoint that is not split further. If the implementer proves
it too big, the implementer stops and sends it back. Allowed product
files: `aloe/env.rkt`, `aloe/type.rkt`, `aloe/eval.rkt`,
`aloe/main.rkt`, `aloe/driver.rkt`, `aloe/expression-query.rkt`,
`aloe/completion-query.rkt`, `aloe/private/checker-observation.rkt`,
`host/racket/gel-run.rkt`, `SPEC.md`, `docs/decisions.md`,
`docs/editor/expression-query/spec.md`,
`docs/editor/completion/spec.md`, the tests in §9.1, and
`tests/modules/NNN-file-environments.rkt`. After 3d.

#### 6.5.1 Environments

- The base and the interactive environment become distinct objects
  (§2). `make-driver` builds a base and its interactive environment
  in each half; the `driver` struct's two fields hold the interactive
  environments. `driver-inject-host!` writes the base (the parent)
  and still refuses a name bound anywhere in the chain.
  `make-top-level-env` and `make-type-environment` in `aloe/main.rkt`
  return the interactive environment of a fresh base, so the object a
  caller holds is the one `eval-source`, `eval-program`, and
  `eval-datum` mutate; `tests/checkpoint-18.rkt` holds that object
  when it evaluates `(demo step)` after a pathed load of `boids.aloe`.
  A raw kernel environment handed to those three operations is
  bootstrapped in place, as today, and is then the **base** of an
  interactive environment that `aloe/main.rkt` creates and memoizes
  beside it (the existing weak table). Forms and copied definitions
  land in that memoized child on every later call with the same raw
  object; the raw object itself holds the kernel, the libraries, and
  the seeds, never a prompt definition. No current test reads a
  definition back from a raw object after `eval-source`; the public
  constructors are the supported way to hold an environment across
  calls.
- A **file environment** is created for each keyed root and each
  nested load on a miss. Its parent is the base. It records the
  resolved path. Its bindings are the file's own definitions plus
  the names its own loads copied in.
- A file parented at a fresh kernel environment would see neither
  `term` nor the libraries; a file parented at the loader would see
  everything already defined there. Neither is this design.

#### 6.5.2 Loading and copying

When a `load` (or a keyed root) reaches a path, after the cache
rules of §4.1:

- **miss:** make the file environment, record the running entry,
  check (or evaluate) the file's forms there, compute the exports
  (the file's own `define`, `define-class`, and `define-protocol`
  bindings, in order), complete the entry with them, then copy the
  exports into the loader;
- **hit:** copy the entry's exports into the loader; nothing runs.

Copying binds each exported name in the loader to the same binding
(the same class record, the same type, the same value). The loaded
file keeps the names it received from its own loads, so its methods
can see them; those names are not copied onward. `define-methods`
binds nothing and exports nothing. In this slice a copied name that
is already bound in the loader replaces it (today's behavior);
slice 3f adds the error. Copying the same cached definition again
is not a collision.

The **loader** is: the file environment of the file whose `load`
form it is; or the interactive environment for a `load` at the
prompt, in `driver-eval!`, in `driver-prepare!`, or in an unkeyed
port, and for every keyed root (`driver-load-file!`, a keyed
`driver-load-port!`, `eval-source` or `typecheck-source` with
`#:source-path`). So a root's own definitions land in the interactive
environment, where a later form in that environment sees them, and a
second root unions into the same interactive environment.

`tests/checkpoint-18.rkt` evaluates `boids.aloe` with its path and
then `(demo step)`: `demo` is `boids.aloe`'s own definition and is
copied. `tests/checkpoint-52.rkt` does the same with
`identities.aloe` and `x`. `tests/checkpoint-81.rkt` evaluates a
`load` of `gel/loop.aloe` with no source path and then sends
`gel-rows` and uses `gel-empty-stack`: those are `menu.aloe`'s and
`stack.aloe`'s names, so that test loads those files too (§9.1).

#### 6.5.3 The prompt

The interactive environment is not a file. A `define`,
`define-class`, or `define-protocol` there binds in it, shadowing a
base name if one exists (the `Option` goldens of `SPEC.md` §9 keep
running). A second definition of a name in the same environment
replaces the first, at the prompt, through `driver-eval!`, and in a
file that defines a name twice. `host/racket/aloemacs-run.rkt`
redefines `aloemacs-editor` at the prompt after loading `main.aloe`;
that still replaces.

#### 6.5.4 Methods and protocols

With 3c in place, a method written in a file records that file's
environment, so its body runs, and its signature resolves, where it
was written, even when the class was defined elsewhere.
`GelStack`'s `matching-picks`, added in `gel/loop.aloe`, runs where
`GelPicks` and `GelPick` are bound; `GelRow` resolves there because
`loop.aloe` loads `menu.aloe`. A send of an `AloemacsSession` method
from a file that has not loaded `AloemacsBuffers` typechecks,
because the generic re-check runs in `file.aloe`'s environment. A
protocol's signatures resolve in the file that wrote it. The
conformance walk of 3d now sees classes that no environment chain
would reach.

#### 6.5.5 The editor queries

Hover and completion check the queried buffer as a file module at
the identity path, in a fresh base: a file environment whose parent
is the query's base, keyed by the identity path, with its nested
loads following the file rule. The names hover resolves are the
names a load of that file would resolve. A base library's buffer
follows 3a instead. Hover inside `examples/mpl/sym.aloe` is still
JSON null, now because conformance fails at the root's end (`Math`
is bound through `math.aloe`, `core.aloe` does not run, so the
protocol methods are absent). The query's interactive environment is
empty; the base, the file environment, and the cache are walked.

#### 6.5.6 Entry points

A driver that loaded only `main.aloe` sees `aloemacs-editor` and the
base. A test or runner that uses a name its loaded root does not
define loads the file that defines it. §9.1 lists the entry points
read from the tree on 2026-10-12, grouped; the implementer re-reads
the tree, runs the suite after the product edit, and treats the
failing locations as the inventory. `host/racket/gel-run.rkt` loads
`gel/stack.aloe` for `gel-empty-stack` beside `gel/main.aloe` and
`examples/point.aloe`. `host/racket/aloemacs-run.rkt` uses only
`aloemacs-editor` and needs no new load. The assertion in
`tests/aloemacs/runner.rkt` that `AloemacsPrompt`, `Text`, `Fs`,
`Path`, and the rest are bound after loading `main.aloe` alone is
the one that pins the old rule; it loads the defining files first or
asserts the new rule.

#### 6.5.7 Tests (`tests/modules/NNN-file-environments.rkt`)

- A load of `examples/aloemacs/editor.aloe` binds `AloemacsEditor`,
  `UndoFrame`, and `safe-cell-controls` and does not bind `Span`,
  `Text`, or `Position`, in a file fixture and at the prompt.
  `Span` is bound by a load of `lib/text.aloe`.
- `Option` after a load of `lib/option.aloe` is `eq?` to the base's.
  After the prompt defines its own `Option`, `String find` at the
  prompt still returns the base class. (A file that defines `Option`
  is the 3f error and is tested there.)
- `editor.aloe` and `file.aloe` both loading `lib/text.aloe` in one
  driver is one evaluation and one class; the loads of
  `option.aloe` are hits of the installed class.
- A second root (`driver-load-file!` of `examples/point.aloe` after
  `gel/main.aloe`) unions into the interactive environment; a second
  `driver-load-file!` of the same root copies again and runs nothing.
- `eval-source` with `#:source-path` copies the root's own
  definitions, and not the nested ones, into the interactive
  environment the caller passed (an `aloe/main.rkt` environment) and
  a later form in it sees them; without a source path it evaluates
  there and a nested load copies into it. With a raw kernel
  environment, the same two calls land in the memoized child of
  §6.5.1, and a later `eval-source` on the raw object sees them.
- A keyed `driver-load-port!` behaves as `driver-load-file!`; an
  unkeyed one evaluates in the interactive environment.
- `gel/main.aloe` plus `examples/point.aloe` plus `gel/stack.aloe` in
  one driver: `gel-main`, `Point`, and `gel-empty-stack` resolve and
  the `gel-run` expression runs.
- `matching-picks` resolves `GelPicks`, `GelPick`, and `GelRow`.
- A prompt-defined name copied over by a later load is replaced in
  this slice (and becomes the 3f error).
- `define-methods` in a later file on a class from an earlier file
  runs its body in the later file.
- A second driver does not see the first driver's classes.
- `driver-inject-host!` after loads still refuses a bound name and
  still writes the base; a file loaded afterwards sees `term`.
- Hover on a buffer-defined class and on a class loaded from disk
  both resolve; hover inside `sym.aloe` is null.
- MPL conforms; the whole suite is green with the §9.1 loads added.

**Documents.** `SPEC.md` and `docs/decisions.md`: §12, row 3e.
`docs/editor/expression-query/spec.md` §1, after the
`#:document-path` paragraph from 3a: "The file is checked as a file
module: its own environment is a child of the default environment,
and its nested loads copy only what they define." The same sentence,
with `source` for the file, goes into `docs/editor/completion/spec.md`
§1 and its "Each call creates a fresh checker environment" paragraph
gains "`lib/int.aloe` and `lib/option.aloe`" after "String libraries".

### 6.6 Slice 3f — collisions

Allowed product files: `aloe/env.rkt`, `aloe/type.rkt`,
`aloe/eval.rkt`, `SPEC.md`, `docs/decisions.md`,
`tests/modules/NNN-collisions.rkt`, and fixtures. After 3e.

**Origins** (§2) are recorded for every binding in an interactive or
file environment, and for base bindings.

**Rule.** A name copied by a load does not replace a different
definition already visible where it lands. When copying a name into
a loader, the loader's visible binding for that name (its own table,
then the base) is compared by origin:

- no visible binding: copy, with the exported origin;
- a visible binding with the same origin (the same file defined it;
  for an installed class, its library path): nothing to do;
- a visible binding with a different origin: the check-time error
  below. Nothing from that copy lands; earlier bindings stay.

A file module that defines a name already bound on the base is the
same error, raised when its `define`, `define-class`, or
`define-protocol` is checked. Two paths that export the same name
collide even when the values would be equal by content; the identity
of a binding is its defining file plus the name. Two files that
define `View` and never meet are legal; a third file that loads both
is the error. The prompt's own definition of a base name shadows it
(§6.5.3); the prompt's own definition is `prompt` for this rule, so a
later load that copies the same name over it is the error.

**Error text.** A type error, where each side is a displayed path,
`the prompt`, or `the language base`:

```text
typecheck: name collision: View is defined by examples/a/view.aloe and by examples/b/view.aloe
typecheck: name collision: View is defined by the prompt and by examples/b/view.aloe
typecheck: name collision: Option is defined by lib/option.aloe and by examples/other.aloe
typecheck: name collision: List is defined by the language base and by examples/other.aloe
```

The first-named side is the binding already visible; the second is
the file whose load or definition collided.

This error is the only collision tool in this series. If adoption
(§10) cannot drop a prefix without a new tool, the checkpoint writer
stops and reports it.

**Tests** (`tests/modules/NNN-collisions.rkt`): two fixtures that
each define `View`, a third that loads both: the first message with
both displayed paths; the same two loaded into the prompt in turn:
the error on the second, the first `View` still bound; a fixture
that defines `Option`: the third message; one that defines `List`:
the fourth; a prompt-defined `View` then a load of a `View` file:
the second message; the same cached definition reached twice through
two loaders is not an error (`lib/option.aloe` through `text.aloe`
and `fs.aloe`; a diamond fixture); a file that defines a name twice
replaces; a prompt redefinition replaces. The 3a base-library query
rule has landed before this slice, so a query of `lib/option.aloe`
is not this error; the test proves that.

---

## 7. Layer 4 — defining path

Its own layer, after 3f and before adoption. Allowed product files:
`aloe/type.rkt`, `aloe/private/checker-observation.rkt`,
`aloe/expression-query.rkt`, `aloe/lsp.rkt`, `aloe/eval.rkt` only to
record the path on `class-value` if the implementer wants parity
(not required), `docs/editor/lsp/spec.md` §7,
`docs/editor/expression-query/spec.md`, `docs/decisions.md`, the
tests in §9.3, and `tests/modules/NNN-defining-path.rkt`.

### 7.1 Recording

Every class a file module defines records that file's resolved path
in its checker record: the path of the file environment that checked
the `define-class`, found through the local-environment chain.
Kernel classes, prompt classes, unkeyed-port classes, and classes
whose `define-class` ran in a raw environment record none. A class
the queried buffer defines records the identity path (the document),
not the temporary sibling. A class a nested load defines records
that file's path on disk. The cache key stays the resolved path.

### 7.2 The path rendering

`type->datum` keeps today's shape; its tests are untouched. A second
rendering, the **pathed datum**, has the same shape as the plain
datum except that each class with a defining path is written as the
symbol spelled `Name@path`, where `path` is the displayed path:

| Plain datum | Pathed datum |
|---|---|
| `Int` | `Int` |
| `(Point Int)` | `(Point@examples/point.aloe Int)` |
| `(Option Position)` | `(Option@lib/option.aloe Position@lib/text.aloe)` |
| `(Class Point)` | `(Class Point@examples/point.aloe)` |
| `(List Box)` with `Box` from `/tmp/x/box.aloe` | `(List Box@/tmp/x/box.aloe)` |
| `Math` (a protocol) | `Math` |

Protocols, type variables, parameters, host interface names, and
kernel types render as in the plain datum. Protocols record no
defining path in this series, so two protocols of one short name
still print alike; the pressure was classes, and §6.2 already keeps
them from unifying. A compound type carries
the path of each class in it, including type arguments. The pathed
datum equals the plain datum exactly when no class in the type has a
path. Both are written with Racket `write`, so a path containing a
character `write` escapes appears escaped.

### 7.3 Mismatches

The two `expected ~a, got ~a` sentences in `aloe/type.rkt` — the
plain `type mismatch: expected ~a, got ~a` and the contextual
`type mismatch for ~a: expected ~a, got ~a` — keep calling
`type->datum`. When the pathed datum of either side differs from its
plain datum, the sentence gains a space and a parenthesis holding
both pathed datums joined by ` vs `:

```text
typecheck: type mismatch: expected Box, got Box (Box@tests/modules/fixtures/box-a.aloe vs Box@tests/modules/fixtures/box-b.aloe)
typecheck: type mismatch: expected (Option Position), got (Option Int) ((Option@lib/option.aloe Position@lib/text.aloe) vs (Option@lib/option.aloe Int))
```

When neither side has a pathed class the sentence is unchanged.
Other messages that print one type are unchanged.

### 7.4 Hover

`expression-query-result` gains a fourth field, `pathed-type`, the
pathed datum of the result type. The observation that
`materialize-expression-observation-at-root-end!` builds carries it
beside the plain datum, built by the same checker pass. The LSP
hover value becomes:

1. `type: ` and the plain datum written with `write`;
2. when `pathed-type` differs from `type`: a newline, `from: `, and
   the pathed datum written with `write`;
3. a newline and `messages:`, then the rows exactly as today, or
   `messages: none`.

```text
type: (Option Position)
from: (Option@lib/option.aloe Position@lib/text.aloe)
messages:
  present? : () -> Bool
```

Rows do not print paths. Completion items do not print paths. A
buffer-defined class reports the document's real path; a nested
load's class reports its disk path; a temporary sibling never
appears. Hover text for kernel types, `(Class String)`, stub results
whose pathed datum equals their type, and classes without a path is
unchanged.

### 7.5 Tests

`tests/modules/NNN-defining-path.rkt`: the pathed datum table above
through the checker; a class defined at the prompt has no path; a
class from an unkeyed port has no path; a class from a file inside
the repository prints repository-relative; one from a temporary
directory prints the resolved path; the two mismatch messages above
reproduced with two `Box` fixtures and with `(Option Position)`;
hover inside a dirty `lib/text.aloe` through a sibling prints
`lib/text.aloe`, not the sibling; hover on a nested-loaded class
prints its disk path; `type->datum` of each case is unchanged.

Every test whose exact hover text or result-struct arity changes is
listed in §9.3. No current test pins the full text of an
`expected ~a, got ~a` sentence for a class with a path; the four
files that match `type mismatch` with regexp fragments
(`tests/checkpoint-93.rkt`, `tests/checkpoint-95.rkt`,
`tests/with/law.rkt`, `tests/parenthetical-construction/law.rkt`)
stay green with the suffix, and the implementer confirms by running
them.

### 7.6 Documents

`docs/editor/lsp/spec.md` §7: the numbered list gains the `from:`
item between the type line and `messages:`, the JSON example gains
the line `from: (Point@tests/editor/lsp/fixtures/point.aloe Int)`
for the normative fixture, and the sentence "The adapter does not
sort, deduplicate, group overloads, substitute types, or invoke
signatures." gains "It prints a class's defining path only on the
`from:` line, as the query renders it, and never a temporary
sibling's path." §10 of that spec: the bullet "Changes to
`query-expression-at`, `srcloc`, type datums, or `signature-spec`"
becomes "Changes to `srcloc` or `signature-spec`; the `pathed-type`
field and `#:document-path` keyword are the modules series' additions
to `query-expression-at`". `docs/editor/expression-query/spec.md`
§1: the struct gains `pathed-type` with one sentence: "`pathed-type`
is the same datum with each class that has a defining path written
`Name@path`, the path repository-relative when inside the repository;
it equals `type` when no class has a path." `docs/decisions.md`:
§12, row 4.

---

## 8. Error text summary

| Situation | Message | From |
|---|---|---|
| Second load of the same path, different bytes | `typecheck: load file changed: <displayed path>; this version does not reload a changed file` | 000 |
| Load of a path still running | `typecheck: load cycle: <resolved path>` (unchanged) | — |
| Load of a missing file | `typecheck: load file not found: <resolved path>` (unchanged) | — |
| Copied name meets a different definition; file defines a base name | `typecheck: name collision: <Name> is defined by <A> and by <B>` with `A`, `B` each a displayed path, `the prompt`, or `the language base` | 3f |
| Type mismatch involving a class with a path | the existing sentence plus ` (<pathed expected> vs <pathed got>)` | 4 |
| Protocol not implemented | unchanged text; now raised at the root's end over the wider walk | 3d |

---

## 9. Inventories read from the tree on 2026-10-12

These lists are what a mechanical scan of the tree found on the day
this spec was written. They are a starting point, not a freeze. The
checkpoint that touches a group re-reads the tree; the suite run
after the product edit is the inventory; names that are Racket
symbols rather than Aloe references (`Other`, `Disk`, and the
`Entry` constructor selectors in the filesystem tests) are known
false hits of the scan.

### 9.1 Entry points that use a name their loaded root does not define (slice 3e)

**Editor tests that load `examples/aloemacs/file.aloe` alone** and
use `Text`, `Position`, `Path`, `Fs`, `AloemacsEditor`, and in some
`UndoFrame` — add loads of `editor.aloe`, `lib/text.aloe`, and
`lib/fs.aloe` as used: `tests/aloemacs/buffer-collection.rkt`,
`buffer-session.rkt`, `file-session.rkt`, `keymap-prefix.rkt`,
`minibuffer-session.rkt`, `motion-editor.rkt`, `undo-session.rkt`,
`visited-unchanged.rkt`, `windows-state.rkt` (also loads
`lib/fs.aloe`).

**Editor tests that load `main.aloe` alone** and use the `Aloemacs*`
classes, `Text`, `Position`, `Path`, `Fs`, `UndoFrame`, or a keymap —
add `file.aloe`, `editor.aloe`, `lib/text.aloe`, `lib/fs.aloe` as
used: `tests/aloemacs/idle-echo.rkt`, `mode-line-one-view.rkt`,
`mode-line-split-views.rkt`, `mouse.rkt`, `runner.rkt`,
`window-pictures.rkt`, `tests/parenthetical-construction/session.rkt`.

**Editor tests that load `file.aloe` and `main.aloe`** (some also
`lib/fs.aloe` or `editor.aloe`) and use `Text`, `Position`, `Span`,
`AloemacsEditor`, `UndoFrame`, `Path`, or `Fs` — add `editor.aloe`,
`lib/text.aloe`, `lib/fs.aloe` as used: `tests/aloemacs/buffer-value.rkt`,
`completion-frame.rkt`, `completion-page-frame.rkt`,
`completion-page-session.rkt`, `completion-session.rkt`,
`echo-session.rkt`, `keymap-session.rkt`, `kill-session.rkt`,
`minibuffer-value.rkt`, `mode-buttons-paint.rkt`,
`mode-buttons-press.rkt`, `prompt-commands-find-file.rkt`,
`search-session.rkt`, `split-drag-bar.rkt`,
`split-drag-mode-line.rkt`, `split-drag-motion.rkt`,
`split-drag-weights.rkt`, `viewport-editor.rkt`,
`window-bars-one-view.rkt`, `window-bars-split.rkt`,
`window-point.rkt`, `windows-buffer-identity.rkt`,
`windows-delete-and-other.rkt`, `windows-lock.rkt`,
`windows-split.rkt`, `windows-state-foundation.rkt`.

**Editor tests that load `editor.aloe`** (alone or with `file.aloe`)
and use `Text`, `Position`, `Span`, or `EditResult` — add
`lib/text.aloe` (and `lib/fs.aloe` where `Fs` or `Path` appears):
`tests/aloemacs/editor-keys.rkt`, `frame.rkt`,
`index-001-editor-movement.rkt`, `index-002-frame.rkt`,
`index-002-timing.rkt`, `int-min.rkt`, `safe-cell-scan.rkt`,
`safe-cells.rkt`, `undo-editor.rkt`, `viewport-top.rkt`,
`mode-line-row.rkt`, `prompt-commands-save-as.rkt`,
`prompt-commands-select-buffer.rkt`,
`windows-layout-and-rendering.rkt` (also uses `aloemacs-editor`
from `main.aloe`). `next-lines.rkt` and `text-line-length.rkt`
already load `lib/text.aloe`.

**Gel tests that load `gel/loop.aloe`** and use `gel-rows`, `GelRow`,
or `GelRows` (`gel/menu.aloe`) and `gel-empty-stack` or `GelStack`
(`gel/stack.aloe`) — add those loads: `tests/checkpoint-62.rkt`,
`63`, `66`, `67`, `68`, `69`, `70`, `73`, `74`, `75`, `76`, `77`,
`78`, `79`, `80`, `81`, `82`.

**Gel tests and the runner that load `gel/main.aloe`** and use
`gel-empty-stack`, `GelStack` (`stack.aloe`) or `gel-text`, `GelKey`,
`GelStep` (`loop.aloe`): `tests/checkpoint-65.rkt`, `71`, `72`,
`86`, `host/racket/gel-run.rkt`. **Loading `gel/stack.aloe`** and
using `gel-rows`: `tests/checkpoint-59.rkt`, `61`.

**MPL tests** whose setup string loads `examples/mpl/core.aloe` and
then names `Sym`, `Sum`, `Num`, `Prod`, `Pow`, or `Math` — add loads
of the class files and `math.aloe` as named:
`tests/checkpoint-29.rkt` through `tests/checkpoint-51.rkt`
inclusive, except those in that range that do not load `core.aloe`.

**Boids tests** that load `examples/boids.aloe` and construct
`Point` — add `examples/point.aloe`: `tests/checkpoint-11.rkt`, `12`,
`15`, `17`, `18`, `19`, `21`, `22`.

**No change expected:** the LSP, completion, and expression-query
fixtures define their own names (`root.aloe` loads `support.aloe`
and `Loaded` is copied); `tests/checkpoint-100.rkt`, `103`–`107`,
`tests/aloemacs/fs-contents.rkt`, `search-find.rkt`,
`search-timing.rkt`, and `tests/fs-repl.rkt` use `Option` (base) or
constructor selectors; `host/racket/aloemacs-run.rkt`.

### 9.2 Pins on `file.aloe` and `main.aloe` datums (layer 2)

Listed in §5.4.

### 9.3 Hover goldens and result-struct constructors (slice 3a and layer 4)

Live hover text that gains a `from:` line: `tests/editor/lsp/000-hover.rkt`
(`(Point Int)` from the fixture), `005-framing.rkt`, `009-launch.rkt`
(the same fixture), `003-buffer-snapshots.rkt` (`LoadedFromDisk`,
a temporary-directory path), `004-hover-results.rkt` (`Render004`,
a buffer-defined class in a temporary document; its `(Class String)`
case is unchanged).

Tests that construct `expression-query-result` and therefore gain
the fourth field: `tests/editor/lsp/000-hover.rkt`,
`001-utf16-positions.rkt`, `002-document-sync.rkt`,
`003-buffer-snapshots.rkt`, `006-json-rpc.rkt`, `007-lifecycle.rkt`,
`008-adapter-failures.rkt`, `tests/editor/completion/003-lsp-completion.rkt`,
`tests/editor/expression-query/003-public-query.rkt`. Their stub
hover text is unchanged when the stub's pathed type equals its type.
`tests/parenthetical-construction/editor.rkt` reads the struct
through accessors only and does not change.

Stub query procedures reached through a snapshot that accept
`#:document-path` (slice 3a): `tests/editor/lsp/001-utf16-positions.rkt`,
`003-buffer-snapshots.rkt`.

### 9.4 Pins of `file.aloe`'s ordered `define-class` names (adoption)

Read from the tree on the day the human asks. Today they include
`tests/aloemacs/runner.rkt`, `buffer-value.rkt`,
`completion-page-session.rkt`, `completion-session.rkt`,
`minibuffer-value.rkt`, `mode-buttons-paint.rkt`,
`mode-buttons-press.rkt`, `mode-line-row.rkt`,
`prompt-commands-find-file.rkt`, `split-drag-bar.rkt`,
`split-drag-mode-line.rkt`, `split-drag-motion.rkt`,
`split-drag-weights.rkt`, `window-bars-one-view.rkt`,
`window-bars-split.rkt`, `windows-buffer-identity.rkt`,
`windows-delete-and-other.rkt`,
`windows-layout-and-rendering.rkt`, `windows-lock.rkt`,
`windows-split.rkt`, `windows-state-foundation.rkt`,
`windows-state.rkt`.

---

## 10. Layer 5 — adoption

Last. The checkpoint manager does **not** issue this checkpoint
until the human asks for it, at a quiet point between editor feature
series, after the earlier checkpoints are accepted. It may be split
by editor area, each split issued only on that ask.

**Duty.** Split `examples/aloemacs/file.aloe` toward one class per
file and remove the `Aloemacs` prefix from each class in the same
move. A class is moved once; the checkpoint that moves it drops its
prefix. New names in moved files are bare. `UndoFrame` and
`safe-cell-controls` stay as they are unless a collision in §6.6
appears. The prefixed value names `aloemacs-editor`,
`aloemacs-global-keymap`, `aloemacs-ctrl-x-keymap`,
`aloemacs-save-command`, and `aloemacs-self-insert-command` keep
their spelling in this series (`host/racket/aloemacs-run.rkt`
evaluates `aloemacs-editor` by name); the human's checkpoint may
say otherwise.

**Rule for the split.** A set of classes that form a cycle through
field types stays in one file. The checkpoint the human asks for
lists that set from the field graph of the tree on that day. A
one-way reference is a load. `define-methods` in a later file, after
a load of the class, may stay; the body runs in the writing file
(§6.3). That is the shape `AloemacsWindowTree` and
`AloemacsWindowRect` may keep. Each moved file loads each file whose
names it uses. `main.aloe` loads each file whose name it uses. No
barrel file is added.

**What the checkpoint lists, from the tree that day:** every test in
§9.4 that pins `file.aloe`'s ordered `define-class` names; every
test entry point whose loaded root no longer defines a name it uses
(the §9.1 shape, re-read); every `Aloemacs`-prefixed reference in
`examples/aloemacs/`, the tests, and `host/racket/aloemacs-run.rkt`
that the move renames.

**Collisions.** Dropping a prefix is legal only where §6.6 raises no
error in any program the suite loads. Today the bare editor names
(`Buffer`, `Buffers`, `View`, `Session`, `Editor`, `Command`,
`Keymap`, `Binding`, `Prompt`, `WindowTree`, `WindowRect`,
`Windows`, `ModeLine`, `LeafPicture`, `CompletionScan`,
`SearchScan`, `Mouse`) do not collide with `lib/text.aloe`,
`lib/fs.aloe`, or `lib/option.aloe`; Gel keeps `GelText` and every
other Gel prefix and is not loaded beside the editor. If the
checkpoint writer finds a prefix that cannot be dropped without a
new tool, the writer stops and reports it.

**Acceptance.** The tests pass; no `Aloemacs` class prefix remains
in the moved files; no `prefix` tool appeared.

---

## 11. Verification and acceptance of the series

The series is complete when all of these hold on the branch:

1. In one base, the same bytes of `Box`, of `(Option Int)`, and of
   the keymap-order shape keep one class across a second load.
   Changed bytes are the §4.2 error and install nothing. The list,
   string, int, and option installs are completed entries that store
   their bytes; a load of those bytes does not run `define-methods`
   again. Two bases share nothing. The `option.aloe` diamond, cycle
   errors, and missing-file errors stay.
2. A load of `editor.aloe` does not bind `Span`, in a file or at the
   prompt. `Option` is the base class from `lib/option.aloe` and a
   load of that file is that class. Every census file loads the
   files that define the names it uses. `main.aloe` does not load
   `lib/option.aloe`. Two files may define `View`; a third that loads
   both is the §6.6 error naming both paths. Overload selection uses
   class and protocol records in the checker and the evaluator; two
   protocols of one short name are not one type; sole methods,
   `Mirror invoke`, and `Signature accepts?` keep short-name
   comparison.
3. `gel-run` loads each file that defines a name its expression uses.
   `matching-picks` runs where `GelPicks` and `GelPick` are bound and
   `GelRow` resolves. A second `define` or `define-class` at the
   prompt still replaces.
4. A driver that loaded only `main.aloe` sees `main.aloe`'s names.
   Every entry point loads what it names.
5. A mismatch and a hover print the displayed path of every class
   that has one, including type arguments; a buffer-defined class
   reports the document, never a sibling; kernel, prompt, and
   unkeyed-port classes have none; hover inside `lib/option.aloe`
   resolves clean and dirty; hover inside `sym.aloe` is null.
6. `define-methods` still mutates the one class record; bodies and
   signatures resolve in the writing file; protocols in theirs;
   conformance walks the cache, the file being checked, and the
   interactive environment at each root's end; an injected `term`
   and `fold` work; `String find` returns the base `Option`; the
   spelling is still `(load "path.aloe")`.
7. The closing layer, when issued, removes the `Aloemacs` class
   prefixes, moves classes toward one class per file within §10's
   rule, leaves `GelText`, and adds no tool.
8. Every checkpoint left the suite green, and the explicit-load
   layer did not precede modules 000.

---

## 12. `SPEC.md` and `docs/decisions.md` edits by checkpoint

Each edit lands in the checkpoint that makes it true. Dates in
`docs/decisions.md` are the landing dates. `docs/philosophy.md` is
not edited.

| Checkpoint | `SPEC.md` | `docs/decisions.md` |
|---|---|---|
| **000** | §11, first bullet, becomes: "`load` reads, typechecks, and evaluates another Aloe file in the same environment, resolving relative paths from the loading file before the current directory and project root. A resolved path runs once per base: a later `load` of the same path with the same bytes runs nothing, and a later `load` of the same path with different bytes is a type error. The list, string, and int libraries installed in a default environment count as already loaded." | **Run-once load.** Decided: a load cache per base, keyed by resolved path, in the checker and the evaluator; the checker compares bytes and rejects a changed file; the evaluator reuses by path. Rejected: a process-wide cache, a modification-time criterion, a byte comparison in the evaluator, and any reload of an edited file. |
| **Layer 2** | none | **Explicit loads.** Decided: every census file loads each file whose names it uses; `Math` lives in `examples/mpl/math.aloe`. Rejected: a barrel file and a checker that walks identifiers. |
| **3a** | §7.5, the `find` row's type becomes "`(Option Int)`, where `Option` is the base class from `lib/option.aloe`"; after the `starts-with?` sentence add: "`Option` is an Aloe class defined in `lib/option.aloe` and installed in default environments beside the list, string, and int libraries; `find` returns that class, not a class the program bound under that name." | **Option on the base.** Decided: `lib/option.aloe` is installed beside the other libraries; `String find` returns it; a load of the file is a hit; an editor query of a base library installs it from the buffer. Rejected: resolving `find`'s `Option` by name, and a second `Option`. Supersedes the 2026-09-08 "Option library" sentence that `make-driver` does not bootstrap it. |
| **3b** | §3.4, the "Each argument type must match the parameter type exactly" bullet gains: "Identity is the class record or the protocol record, not the name: two classes, or two protocols, that share a short name are different types." §4.8 adds: "`define-protocol` binds the protocol as a value under its name and evaluates to void." | **Overload identity by record.** Decided: class and protocol parameters select by record in both halves; `define-protocol` binds a runtime record. Rejected: changing `Mirror invoke`, `Signature accepts?`, or sole-method dispatch. |
| **3c** | none | none |
| **3d** | §3.3, after "Every class that opts into a protocol with signatures must implement each required method with compatible parameter and return types." add: "That is checked when the outermost program finishes, over every class the environment's base, cache, file, and prompt hold." | none |
| **3e** | §11, first bullet, becomes: "`load` reads, typechecks, and evaluates another Aloe file once per base, as a file module: the file runs in its own environment, whose parent is the base, and the names it defines with `define`, `define-class`, and `define-protocol` are copied into the loading environment. Names the file only received from its own loads are not copied. Relative paths resolve from the loading file before the current directory and project root. A later `load` of the same path with the same bytes copies the same definitions without running the file; different bytes are a type error. The prompt is not a file: its parent is the base, and a file loaded there copies its definitions into the prompt's environment. A program given with a source path is a file module." §3.1, after "`self` is implicit in every method body." add: "A method body, and the types named in its signature, are checked and evaluated in the environment of the file that wrote the method, whether in the class form or in a later `define-methods`." §3.3 add: "A protocol's signatures are resolved in the file that wrote the protocol." §4.6 add: "A method added with `define-methods` runs in the file that wrote it." §8, "modules beyond `load`" becomes "modules beyond `load`'s file modules: `import`, export lists, prefixes, renames, packages, a load path, reload of an edited file". | **File modules and the copy rule.** Decided: a load copies the loaded file's own definitions, in a file and at the prompt; a file's environment is a child of the base; a root's definitions go to the prompt; methods and protocols resolve where they were written; a load of `editor.aloe` binds the names `editor.aloe` defines, and `Span` is bound by a load of `lib/text.aloe`. Rejected: `import`, a prefix clause, export lists, barrels, a load path, a declared module name, per-importer method tables, scoped selectors, parenting a file at the loader or at a bare kernel. |
| **3f** | §11, append to the first bullet: "A copied name does not replace a different definition already visible where it lands; that is a type error naming both origins. A file may not define a name the base binds. A second definition of a name in the same environment replaces the first." | **Load collisions.** Decided: the identity of a binding is its defining file plus the name; a different definition already visible is a check-time error naming both; the prompt may shadow the base, a file may not. Rejected: `prefix`, `only`, `rename`, and silent replacement across files. |
| **4** | none | **Defining paths.** Decided: a class records the path of the file that defined it; hover and the `expected, got` mismatch print each class's repository-relative path as a second rendering; `type->datum` is unchanged. Rejected: paths inside `type->datum`, paths on rows and completion items, a decorative module name. |
| **5** | none | **Aloemacs adoption.** Decided: `file.aloe` splits toward one class per file under the field-cycle rule and the `Aloemacs` class prefixes come off in the same move; Gel keeps its prefixes. Rejected: a barrel, a prefix tool, renaming Gel. |

---

When this specification is accepted, the next conversation is the
checkpoint manager. Its whole assignment is this file; it writes
`checkpoints/000-run-once.md` and stops.
