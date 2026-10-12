# Charter — modules

**Status.** Handoff from the high-level discussion into a
**design conversation**. Not a checkpoint. Not an implementer
assignment. Specification will live beside this file as
`spec.md`. Checkpoints will live in `checkpoints/`. Process:
[`docs/workflow.md`](../../../workflow.md). Project root:
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Branch:
`experiment/2026-10-12-modules`, cut from `main` at `40344c3`.

**Your job.** Write the specification for **modules**. `load`
stays the only spelling. A path runs once per driver base.
Inside a file, the names that come back are the names that
file itself defines. The interactive environment instead
receives each loaded root's local table, and a second root
unions there. The resolved path is the module. Then **stop**.
Do not write checkpoints. Do not implement.

This effort refuses a second keyword, export lists, barrel
files, a load path, packages, versions, a module name separate
from the path, qualified-send syntax, a `prefix` or `only` or
`rename` tool, dependent invalidation of an edited file,
per-importer methods, scoped selectors, macros, and a
concurrency design. The layer order in §4.10 is the work this
series does include.

---

## 1. How this conversation works

1. Read this charter, [`README.md`](README.md), and the authority
   in §5.
2. Record the locked decisions in §4. Those choices are closed.
   This charter has no open product questions. The spec writes
   the sentences, the error text, the census, the checkpoint
   boundaries inside §4.10, and the `SPEC.md` edits. It does
   not reopen a lock.
3. Write `spec.md` in this folder. State the series facts in §6
   in the spec's own words. A later checkpoint-manager
   conversation slices **modules 000**, … under `checkpoints/`
   (not `docs/checkpoints/` unless a human promotes the series
   after review).
4. Stop. The human reviews the spec. Do not write those
   checkpoint files.

Keep the spec to the layers in §4.10. A manager may split a
layer that misses the checkpoint size in
[`docs/workflow.md`](../../../workflow.md), keeps that order,
and adds no features. A second keyword, a barrel, a prefix
tool, or a reload design is a defect in this document.

## 2. Predecessors (do not start without these)

| What | Ready when |
|---|---|
| `SPEC.md` §11 | `load` reads, typechecks, and evaluates another file in the same environment. The path is the one `load-expr-resolved-path` already resolves. This series adds no search list |
| `aloe/type.rkt` `typecheck-load!`, `aloe/eval.rkt` `eval-load!` | Each load reads the file into the caller's environment. The only memory is a path stack for cycles. A second `define-class` is a new class record. Unify compares class records with `eq?` |
| `aloe/eval.rkt` `class-value` | The class record already stores the environment in which the class was defined. Method bodies close over that environment. The spec uses this field |
| `aloe/env.rkt`, `aloe/type.rkt` | Both environment structs have a parent. The kernel bindings are `dummy`, `List`, `Int`, `String`, `Symbol`, and `Mirror`. `Bool` and `Float` are not bindings |
| `aloe/driver.rkt` `make-driver` and `aloe/main.rkt` | Both build a base and install the list, string, and int libraries. Hover, completion, and the direct tests use `aloe/main.rkt`. `driver-inject-host!` binds a host on the driver base and refuses a name already bound there. Runners inject, then load |
| `aloe/driver.rkt` `driver-load-port!` | A port may have no source path. String loads in the tests use that shape. `host/racket/term-run.rkt` passes a path |
| `host/racket/gel-run.rkt` | Loads `gel/main.aloe`, then `examples/point.aloe`, then evaluates an expression that uses a name from each. Checkpoints 65 and 86 do the same |
| `aloe/expression-query.rkt` | Each query builds a fresh type environment. A nested load is read from disk. A dirty buffer of another file is not overlaid |
| [`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §5 | A dirty buffer is written to a temporary sibling and queried there. That path is an internal detail. Hover never shows it to the client |
| [`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §7 | Hover text is an exact plaintext value. This series amends that section |
| [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe), [`editor.aloe`](../../../../examples/aloemacs/editor.aloe) | `main.aloe` loads `file.aloe` and uses `Text`, `Position`, `Option`, `Path`, and `Fs`. `editor.aloe` loads `lib/text.aloe` and uses `Option` |
| [`lib/text.aloe`](../../../../lib/text.aloe), [`lib/fs.aloe`](../../../../lib/fs.aloe) | Both load `lib/option.aloe`. That diamond stays one `Option` |
| The October discussion summary | The `Box` reload, the `Option` reload, and the keymap-order shape are the modules 000 reproductions. `Option` fails the same way as `Box` |

`gel/main.aloe` uses `GelStack`. The explicit-load census
makes it load `stack.aloe`, whose table includes
`gel-empty-stack`, so `gel-run` needs no edit. The spec writes
that dependency. `AloemacsWindowRect` is defined in `file.aloe`,
`UndoFrame` in `editor.aloe`, and `Span` in `lib/text.aloe`.
Tests reach them today through one shared environment.
Concurrency, a second application, and Gel loading `lib/` are
not predecessors.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. In one base, the same bytes of `Box`, of `(Option Int)`, and
   of the keymap-order shape keep one class across a second
   load. Changed bytes are a type error and install nothing.
   Two bases do not share a class. The `option.aloe` diamond,
   cycle errors, and missing-file errors stay. modules 000
   leaves the suite green and does not change which names a
   load introduces.
2. After the visibility layer, a file that loads `text.aloe`
   does not receive `Option`. `main.aloe` and `editor.aloe`
   name the files that define the names they use. A method in
   `text.aloe` that mentions `Option` still typechecks. Two
   files may define `View`. A third file that loads both is a
   check-time error naming both paths.
3. `gel-run` still uses a name from each of its two roots.
   A second `define` or `define-class` at the prompt, and
   through `driver-eval!`, still replaces.
4. A driver that loaded only `main.aloe` sees the export
   tables of the files `main.aloe` loads directly, including
   files the explicit-load layer added. The visibility layer
   adds a load to a test entry point only when that root's
   table lacks a name the test uses, and it may find none.
   Adoption lists the entry points that break when a split
   stops a loaded file from exporting a name `main.aloe`
   does not use.
5. A mismatch and a hover print the repository-relative path
   of every class that has one. A class the queried buffer
   defines reports that document's path, not the temporary
   sibling from
   [`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §5.
   Kernel classes, prompt classes, and unkeyed-port classes
   have no path. §7 of that spec shows the new hover value.
6. `define-methods` still mutates the one class record. An
   injected `term` and `fold` still work. The spelling is
   still `(load "path.aloe")`.
7. The closing layer removes the `Aloemacs` prefixes, moves
   classes toward one class per file where §4.11 allows it,
   and leaves the tests passing. `GelText` stays. No `prefix`
   tool appears.
8. Every checkpoint leaves the suite green. The explicit-load
   layer does not precede modules 000.

## 4. Locked decisions (record these; do not reopen)

### 4.1 One spelling

The form remains `(load "path.aloe")`. There is no `import`
and no prefix clause. The sketch at
`archive/design-sketches/2026-10-08-aloemacs-modules/` is a
rejected spelling.

Run-once lands first, while a load still writes nested names
into the caller's environment. The file-to-file rule in §4.4
lands after every current file use has an explicit load.

### 4.2 Once per driver base

The cache belongs to the driver base, keyed by the resolved
path. Two relative spellings of one file are one key. A
process-wide table is the wrong lifetime. A new driver, and
each hover query's fresh type environment, starts with an
empty cache.

The checker owns the changed-bytes rule. A second load of
different bytes is a type error before any new definition
from that load is installed. Previous bindings stay. The
criterion is the source bytes, not the modification time.
The error says the file changed and this version will not
reload it. The spec writes the sentence.

The evaluator's cache is keyed by resolved path only. It
reuses a completed path and does not compare bytes. The
driver checks a whole file before evaluating any of it, so
the checker sees a changed file first. The checker and the
evaluator each keep their cache on their own base.

A path still on the cycle stack is a cycle error. A missing
file is still an error. Path resolution is unchanged.

`driver-load-port!` with no source path is never a cache
entry. Its own definitions run again if that port is loaded
again. A nested `load` that resolves a path still uses the
cache. A port that carries a path, including `term-run`, is
a keyed root.

After the visibility layer, every file environment of a
driver shares that base's cache. `text.aloe` and `fs.aloe`
loading `option.aloe` is one evaluation and one class.

modules 000 does not add file environments, does not change
the interactive environment, and does not print paths.

### 4.3 The file path is the module

A file has no declared module name. The stored identity is
the resolved path. A barrel file is out of scope.

### 4.4 What a load returns

This split lands at the visibility layer. modules 000 still
includes.

A file module has its own environment in the checker and the
evaluator. The parent is the base in §4.5. A `(load)` inside
a file copies that file's own `define`, `define-class`, and
`define-protocol` bindings into the loader, and nothing it
only received from its own loads. `define-methods` binds no
name. The loaded file keeps those received names, so its
methods can see them. `class-value` already stores that
environment. The spec does not add a second closure.

The interactive environment is not a file. Its parent is the
base. The REPL, `driver-eval!`, and an unkeyed
`driver-load-port!` evaluate there. `driver-load-file!`, and
a `load` evaluated there, copy the loaded file's local
table: its own definitions and the exports of the files it
directly loads. They do not copy names those files only
received from their own loads. A second root copies into the
same interactive environment.

`gel/main.aloe` uses `GelStack`, so the explicit-load census
makes it load `stack.aloe`. That file's table includes
`gel-empty-stack`. The spec writes that dependency.

The visibility layer adds a load of the defining file to a
test entry point only when the loaded root's table lacks a
name the test uses. After the explicit-load layer,
`main.aloe` loads `editor.aloe` and `lib/text.aloe`
directly, because it uses `AloemacsEditor`, `Text`, and
`Position`. Those export tables include `UndoFrame`, `Span`,
and `EditResult`, so a driver that loaded only `main.aloe`
still sees them, and this layer may find no entry point to
edit. Adoption lists the entry points that break when a
split stops a loaded file from exporting a name the root
does not use. The spec finds them. This charter does not
freeze the list.

The visibility checkpoint's `SPEC.md` sentence and its
`docs/decisions.md` entry state both meanings with one
example: a file that loads `text.aloe` does not receive
`Option`, and the same form at the prompt receives
`text.aloe`'s local table.

### 4.5 The base

A base is what `make-driver` builds and what `aloe/main.rkt`
builds. Both install the list, string, and int libraries on
the kernel bindings. User definitions do not live there.
`driver-inject-host!` writes the driver base. `fold` is a
method on the shared `List` object. The spec names the
bindings from the code and adds none.

Hover and completion check the queried buffer as a file
module at the document's path, in a fresh base. Nested loads
in that buffer use the file rule. The buffer's own
definitions live in that file environment. The names hover
resolves are the names a load of that file would resolve.

A file parented at a fresh kernel environment would see
neither `term` nor the libraries. A file parented at the
loader's file environment would see every class already
defined there. Neither parent is this design.

### 4.6 Collisions

A name copied from a different file does not replace a
definition already present. That is a check-time error and
it names both defining files. The same cached definition
copied again is not an error. Two paths that export the same
name collide even when the values would be equal by content.
The identity of a binding is its defining file plus the name.

A second `define`, `define-class`, or `define-protocol` in
the same environment replaces, including a file that defines
a name twice, the prompt, and `driver-eval!`. Rebuilding a
class by hand at the prompt is that person's own act.

A file that defines a name already bound on the base is the
same check-time error. The sentence says the language base.

This error is the only collision tool in this series. Two
files that define `View` and never meet are legal. If
adoption cannot drop a prefix without a new tool, the spec
writer stops and reports it.

### 4.7 Defining path

Every class a file defines records that file's resolved
path. Kernel classes record none. A class defined at the
prompt or in an unkeyed port records none. A mismatch and a
hover print the path for every class that has one, whether
or not another class shares the short name.

The printed form is the path relative to the repository
root, with `/` separators, when the file is inside that
root. Otherwise it is the resolved path. The repository root
is the parent of the `aloe/` directory, the directory
[`aloe/library.rkt`](../../../../aloe/library.rkt) reaches
with `../lib/`. The cache key stays the resolved path.

A class defined by the queried buffer reports that
document's real path. It does not report the temporary
sibling
[`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §5
writes for a dirty buffer. A nested load still reports the
path of the file on disk. The spec chooses whether the query
takes an identity path beside the resolution path, or the
snapshot carries the original name.

This lands with or after the visibility layer, not in
modules 000. It amends §7 of that spec. The series does not
overlay a dirty buffer of one file onto a nested load of
another.

### 4.8 Methods

`define-methods` appends to the shared class record. A method
body is checked in the file that wrote it. A later file can
add methods when the class name is in its environment. This
series does not give methods a per-file table and does not
scope selectors.

### 4.9 Reload

Reload of an edited file is out of scope. The changed-bytes
error in §4.2 is the whole of that behavior. There is no
dependent invalidation.

### 4.10 Layer order

Each layer leaves the suite green. Tests for new behavior
live under `tests/modules/`. The command is the standing one
in [`docs/workflow.md`](../../../workflow.md):

```sh
TMPDIR=/tmp raco test -j 4 -y <paths>
```

The explicit-load layer cannot precede modules 000. Under
today's `load`, a second load of a file that has already
built values creates a new class. Run-once makes that line a
reuse.

1. **modules 000 — run-once.** §4.2 only. The spec names any
   current test that loads one path twice into one driver.
2. **Explicit loads, while file-to-file load still includes.**
   The census is the `.aloe` files. A string evaluated in the
   interactive environment is not a census entry. `main.aloe`
   and `editor.aloe` are the known file cases. The spec lists
   every test that pins `file.aloe`'s leading load datums,
   and updates those pins. It stores no count in prose. This
   layer does not split `file.aloe` and does not drop
   prefixes. Its acceptance is the census and a green suite.
   There is no second checker that walks identifiers. The
   visibility layer going green is the proof the census was
   complete. The spec writer may split this layer by tree.
3. **Visibility.** §4.4, §4.5, §4.6, and §4.8. This layer
   updates a test entry point only when §4.4 says the root's
   table lacks the name, and it may find none. The spec's
   own tests show a load of `text.aloe` does not bind
   `Option`, a third file that loads two `View`s errors with
   both paths, Gel's two roots still work, and a second
   driver does not see the first driver's classes.
4. **Defining path.** §4.7. The spec may join this to layer 3
   when the combination fits one implementer conversation. It
   does not move before layer 3 or after adoption.
5. **Adoption.** §4.11. Last. The spec writer may split it by
   editor area.

modules 000 absorbs neither the census nor the visibility
layer. The census may fold into the visibility layer only
when the spec shows that combination fits one implementer
conversation.

`SPEC.md` changes in the checkpoint that makes the sentence
true. modules 000 changes the once-only behavior and leaves
"same environment" true for file-to-file load. The visibility
checkpoint changes what a file-to-file load introduces and
amends §8's "modules beyond `load`". The spec includes the
`docs/decisions.md` paragraph for each observable change and
assigns it to that checkpoint. This series does not edit
`docs/philosophy.md`.

### 4.11 Adoption

The closing layer splits `examples/aloemacs/file.aloe`
toward one class per file and removes the `Aloemacs` prefix
in the same move. A class is moved once. The checkpoint that
moves it drops its prefix.

A set of classes that form a cycle through field types stays
in one file. The spec lists that set from the field graph.
A one-way reference is a load. `define-methods` in a later
file, after a load of the class, may stay when that is the
shape already used for the window tree and the window
rectangle.

The spec lists every test that pins `file.aloe`'s ordered
`define-class` names, and every test entry point whose
loaded root no longer sees a name the test uses. `main.aloe`
loads each file whose name it uses. This series adds no
barrel. `UndoFrame` and `safe-cell-controls` stay unprefixed
unless a collision in §4.6 appears. New names in the moved
files are bare.

`file.aloe` stays one file until this layer. Gel keeps
`GelText` and the rest of its prefixes. A program that loads
Gel beside `lib/text.aloe` is not this series.

The human asks for the adoption number after the earlier
checkpoints are accepted, at a quiet point between editor
feature series. The spec still specifies the layer.

### 4.12 Out of this series

- `import`, a prefix clause, qualified sends such as
  `(fs Path)`
- Export lists, private names, barrel files
- A load path, packages, versions, a declared module name
- `prefix`, `only`, and `rename`
- Dependent invalidation, and any second load of changed
  bytes that succeeds
- A process-wide load cache, and a byte comparison in the
  evaluator
- Per-file method tables, scoped selectors
- Macros
- Concurrency, threads, and several interactive programs in
  one process
- Writing the one-process goal into `docs/philosophy.md`
- Renaming Gel, or loading `lib/text.aloe` from Gel
- Dirty-buffer overlays for nested loads
- Editor features, keymap changes, and window changes
- Promoting the series onto `CHECKPOINTS.md` inside the spec

## 5. Authority

- `SPEC.md` is what the language does today. This spec amends
  it where §4.10 says so.
- This charter closes the open questions in
  [`archive/design-sketches/2026-10-09-module-design-discussion/summary.md`](../../../../archive/design-sketches/2026-10-09-module-design-discussion/summary.md).
  Where the archive and this charter disagree, this charter
  wins. The archive's `import` and `prefix` sketch is not a
  spelling to restore.
- [`docs/philosophy.md`](../../../philosophy.md) is the design
  test. The restriction lifted first is that a path is not a
  stable identity for its definitions. This series does not
  edit that file.
- [`docs/workflow.md`](../../../workflow.md) is the process.
- [`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §5
  is the synchronized-buffer snapshot, and §7 is the hover
  text this series amends. A class path in that text uses the
  document path, not the temporary sibling.
- The code in §2 is the mechanism the spec builds on.

The spec writer who finds a lock that cannot be sliced
reports the conflict and stops. The spec is not the place
that repairs it.

## 6. Handoff

Series identity is `modules`. Checkpoint 000 is spoken
**modules 000** and filed as `checkpoints/000-run-once.md`.
Numbers are three digits, start at 000, and are never
renumbered. The checkpoint manager writes one checkpoint,
then stops. The project root is
`/home/dharmatech/journal/2026-09-02-aloe-racket`. Code and
tests go there, under the existing tree and
`tests/modules/`, not in this design folder.

After the human accepts `spec.md`, that file is the design
authority for the checkpoint manager and the implementers.
This charter is the designer's assignment.

Intended order: run-once in the shared environment; explicit
loads while file-to-file inclusion remains; per-file
environments and non-re-export, with the interactive
environment still receiving each root's local table;
defining paths in mismatches and hover; adoption of
Aloemacs, last.

If you have been told to read this file, this is the whole assignment.
