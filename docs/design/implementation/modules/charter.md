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
unions there. A program with a source path is a file module.
The resolved path is the module. Then **stop**.
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
| `aloe/eval.rkt` `apply-method`, `define-methods` | A user-class body runs in `class-value-environment`, the file that defined the class. `define-methods` on a user class only appends methods. On `List`, `Int`, and `String` it overwrites the class object's one environment field |
| `aloe/type.rkt` `match-sole-method`, `try-method-match`, `infer-instance-send`, `check-method-body!` | Parameter annotations, return annotations, and field annotations are turned into types in the caller's environment. A generic class with an implicit constructor re-checks the method body there too. `AloemacsSession` is one |
| `aloe/type.rkt` `infer-case`, `infer-with`, `infer-construction`, `infer-field-type!` | Construction, `with`, `case` payload binders, and field-type checks read the receiver class's field declarations in the caller's environment |
| `aloe/type.rkt` `infer-defined-list-method`, `infer-defined-int-method`, `infer-defined-string-method` | Methods added to `List`, `Int`, and `String` have their annotations resolved in the caller's environment |
| `aloe/type.rkt` `infer-protocol-send`, `method-signature-conforms?`, `check-protocol-conformance!` | A protocol send resolves signatures in the caller's environment. Conformance runs once, when the outermost program finishes, and walks that environment's parent chain. Both the protocol's annotations and the class's use that environment |
| `aloe/type.rkt` `check-class-definition!`, `check-method-types!` | These already receive the environment of the form being defined. The spec does not retarget them |
| `aloe/type.rkt` `String find`, `aloe/eval.rkt` `String find` | The checker builds `(Option Int)` with `type-from-sexpr` in the caller's environment. The evaluator looks up the name `Option` there. `editor.aloe` and `file.aloe` both send `find` |
| `aloe/eval.rkt` `runtime-named-type-matches?` | An annotation symbol is compared to the class's short name, not to class identity. `define-protocol` evaluates to void. A class record's protocol field holds the symbol from the parse. `Mirror invoke` and `Signature accepts?` use that short-name comparison |
| `aloe/env.rkt`, `aloe/type.rkt` | Both environment structs have a parent. The kernel bindings are `dummy`, `List`, `Int`, `String`, `Symbol`, and `Mirror`. `Bool` and `Float` are not bindings |
| `aloe/driver.rkt` `make-driver` and `aloe/main.rkt` | Both build a base and install the list, string, and int libraries. [`aloe/library.rkt`](../../../../aloe/library.rkt) reads each of those files once per process through a promise. That promise is parsed expressions, not a load-cache entry. `query-expression-at` reads the path it is given. `make-type-environment` always forces the three promises and typechecks them into the fresh environment. Installing a queried base library from the buffer's bytes is new work in §4.5. Hover, completion, and the direct tests use `aloe/main.rkt`. `driver-inject-host!` binds a host on the driver base and refuses a name already bound there. Runners inject, then load |
| `aloe/main.rkt` `eval-source`, `typecheck-source` | Both take an optional `#:source-path`. The forms are checked and evaluated in the environment the caller passes. `tests/checkpoint-18.rkt` passes `boids.aloe`'s path and then evaluates `(demo step)` in that same environment. `tests/checkpoint-52.rkt` does the same with `identities.aloe` and then uses `x`. `tests/checkpoint-81.rkt` evaluates a `load` of `gel/loop.aloe` with no source path and then sends `gel-rows` |
| `aloe/driver.rkt` `driver-load-port!` | A port may have no source path. String loads in the tests use that shape. `host/racket/term-run.rkt` passes a path |
| `gel/loop.aloe`, `examples/aloemacs/file.aloe`, `examples/mpl/identities.aloe` | `loop.aloe` loads `stack.aloe` and names `GelRow` and `gel-rows`, which `menu.aloe` defines. `stack.aloe` loads `menu.aloe`. `file.aloe` loads `editor.aloe` and `lib/fs.aloe` and also names `Text` and `Position`. `identities.aloe` loads `core.aloe` and uses `Sym` |
| `host/racket/gel-run.rkt` | Loads `gel/main.aloe`, then `examples/point.aloe`, then evaluates an expression that uses a name from each. Checkpoints 65 and 86 do the same |
| `aloe/expression-query.rkt` | Each query builds a fresh type environment. A nested load is read from disk. A dirty buffer of another file is not overlaid |
| [`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §5 | A dirty buffer is written to a temporary sibling and queried there. That path is an internal detail. Hover never shows it to the client |
| [`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §7 | Hover text is an exact plaintext value. This series amends that section |
| [`examples/aloemacs/main.aloe`](../../../../examples/aloemacs/main.aloe), [`editor.aloe`](../../../../examples/aloemacs/editor.aloe) | `main.aloe` loads `file.aloe` and uses `Text`, `Position`, `Option`, `Path`, and `Fs`. `editor.aloe` loads `lib/text.aloe` and uses `Option` |
| [`lib/text.aloe`](../../../../lib/text.aloe), [`lib/fs.aloe`](../../../../lib/fs.aloe), [`lib/disk.aloe`](../../../../lib/disk.aloe) | Each loads `lib/option.aloe`. Those loads stay. After `Option` is installed they are hits of the one base class |
| [`examples/mpl/core.aloe`](../../../../examples/mpl/core.aloe) | Defines `Math`, loads `sym.aloe`, `sum.aloe`, `num.aloe`, `prod.aloe`, and `pow.aloe`, then adds the protocol methods with `define-methods`. Each class file names `Math` and does not load `core.aloe`. `prod.aloe` and `pow.aloe` each send `Num new`. The leaves do not load one another. A load from a class file back to `core.aloe` is a cycle |
| `aloe/driver.rkt` `driver-prepare!` | Typechecks a datum and returns a thunk. `host/racket/aloemacs-run.rkt` runs that thunk later. The first run reads a loaded file again |
| The October discussion summary | The `Box` reload, the `Option` reload, and the keymap-order shape are the modules 000 reproductions. `Option` fails the same way as `Box` |

`gel/main.aloe` uses `GelStack`, and `gel-run` uses
`gel-empty-stack`. The explicit-load census makes
`gel/main.aloe` load `stack.aloe`. `gel/loop.aloe` uses
`GelRow` and `gel-rows`, so the census makes it load
`menu.aloe`. `file.aloe` uses `Text` and `Position`, so the
census makes it load `lib/text.aloe`. `core.aloe` and the
MPL class files load the new Math file. `identities.aloe`
loads `sym.aloe`. The spec writes those dependencies.
`AloemacsWindowRect` is defined in `file.aloe`,
`UndoFrame` in `editor.aloe`, and `Span` in `lib/text.aloe`.
Tests reach them today through one shared environment.
Concurrency, a second application, and Gel loading `lib/` are
not predecessors.

## 3. Bar (acceptance)

The specification is wrong unless all of these are true:

1. In one base, the same bytes of `Box`, of `(Option Int)`, and
   of the keymap-order shape keep one class across a second
   load. Changed bytes are a type error and install nothing.
   The list, string, and int installs are completed cache
   entries. Each seed stores the bytes that were installed.
   A later load of those same bytes does not run
   `define-methods` again. A later load of different bytes
   is the changed-bytes error. Two bases do not share a class.
   The `option.aloe` diamond,
   cycle errors, and missing-file errors stay. modules 000
   leaves the suite green and does not change which names a
   load introduces. The `text.aloe` / `fs.aloe` loads of
   `option.aloe` stay, and after the visibility layer they
   are one cached class.
2. After the visibility layer, a file that loads
   `editor.aloe` does not receive `Span`. `Option` is the
   base class from `lib/option.aloe`. A load of that file
   is that same class, not a second one. `main.aloe`
   and `editor.aloe` name the files that define the names
   they use, as do `file.aloe`, `gel/loop.aloe`,
   `identities.aloe`, and the MPL files in §4.4. A base name
   is already present. `main.aloe`
   does not load `lib/option.aloe` for `Option`. A method
   in `text.aloe` that mentions `Option`
   still typechecks. Two files may define `View`. A third
   file that loads both is a check-time error naming both
   paths. An overloaded checked send does not depend on two
   classes sharing a short name, or on two protocols sharing
   one. Overload selection uses the class record for a class
   parameter and the protocol record for a protocol
   parameter, in the checker and the evaluator. Two protocol
   records with the same short name are not one type. A sole
   method, `Mirror invoke`, and `Signature accepts?` keep
   today's short-name comparison. A sole method is safe
   because the checker has already rejected the other class.
3. `gel-run` still uses a name from each of its two roots.
   `GelStack`'s `matching-picks`, added in `gel/loop.aloe`,
   runs where `GelPicks` and `GelPick` are bound. `GelRow`
   and `gel-rows` resolve because that file loads
   `menu.aloe`. A second
   `define` or `define-class` at the prompt, and through
   `driver-eval!`, still replaces.
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
   have no path. A compound type carries the path of each
   class in it, including its type arguments. §7 of that
   spec shows where each path is printed. Hover inside
   `lib/option.aloe` resolves from the buffer's bytes,
   including when the buffer is dirty and the query path is
   the temporary sibling. Hover inside `sym.aloe` is still
   JSON null.
6. `define-methods` still mutates the one class record. A
   method body, and the annotations in its signature, are
   checked in the file that wrote it. The body is evaluated
   there too. A protocol signature uses the file that wrote
   the protocol. Each root, and each hover query, conforms
   every class in the checker's cache, every class bound
   in the file environment being checked, and every class
   bound in the interactive environment, after that check's
   forms have run. Hover inside `sym.aloe` conforms `Sym`.
   That includes a class the root did not load
   directly and a class whose protocol methods arrived
   through a later `define-methods`. An injected
   `term` and `fold` still work. `String find` returns the
   base `Option`. The spelling is still `(load "path.aloe")`.
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
process-wide table is the wrong lifetime. The cache is a
field of the type environment and a field of the runtime
environment. `make-driver` has one of each.
`make-type-environment` and `make-top-level-env` in
`aloe/main.rkt` are bases and carry the same fields. A cache
stored only on the driver struct misses the suite. A child
environment has no cache of its own. File environments and
local environments defer to the root base's cache. A
per-file cache is the wrong lifetime. A new
driver, and each hover query's fresh type environment,
starts with an empty cache. The list, string, and int
installs then record `lib/list.aloe`, `lib/string.aloe`, and
`lib/int.aloe` as completed entries in both caches. Each
seed stores the source bytes read for that install. The
install stays the expression lists it is today. A later load
of those same bytes is a hit and does not run
`define-methods` again. A later load of different bytes is
the changed-bytes error below. A queried base library is
the exception in §4.5: the buffer's bytes are that cache
entry and are not an error against the file on disk.
`lib/option.aloe` is not one of these entries.

The checker owns the changed-bytes rule. A second load of
different bytes is a type error before any new definition
from that load is installed. Previous bindings stay. The
criterion is the source bytes, not the modification time.
The error says the file changed and this version will not
reload it. The spec writes the sentence.

The evaluator's cache is keyed by resolved path only. It
reuses a completed path and does not compare bytes. The
checker and the evaluator each keep their cache on their
own base. `driver-load-port!` and `driver-eval!` check a
whole file before evaluating any of it, so the checker sees
a changed file first.

`driver-prepare!` typechecks a datum and returns a thunk.
The thunk's first run reads a loaded file again. A change
between that check and that run stays outside this series.
The evaluator does not compare bytes to close the gap.

A path still on the cycle stack is a cycle error. A missing
file is still an error. Path resolution is unchanged.

`driver-load-port!` with no source path is never a cache
entry. Its own definitions run again if that port is loaded
again. A nested `load` that resolves a path still uses the
cache. A port that carries a path, including `term-run`, is
a keyed root.

After the visibility layer, every file environment of a
driver shares that base's cache. `editor.aloe` and
`file.aloe` both loading `lib/text.aloe` is one evaluation
and one class. The `option.aloe` loads are that same kind
of hit once `Option` is installed.

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
methods can see them. A method body runs in the writing
file's environment, as §4.8 locks. The environment stored
on the class is not the one used for a method added later.
A cache hit still copies the loaded file's own definitions
into the loader. It does not evaluate the file again.
Copying the same cached definition again is not the
collision in §4.6.

The interactive environment is not a file. Its parent is the
base. The REPL, `driver-eval!`, and an unkeyed
`driver-load-port!` evaluate there. `driver-load-file!`, and
a `load` evaluated there, copy the loaded file's local
table: its own definitions and the exports of the files it
directly loads. They do not copy names those files only
received from their own loads. A second root copies into the
same interactive environment. A cache hit of one of these
loads still copies that local table and does not evaluate
the file again.

`eval-source` and `typecheck-source` follow this split. A
call with `#:source-path` checks and evaluates that program
as a file module, the same as `driver-load-file!` and a
`driver-load-port!` that carries a path. A call with no
source path evaluates in the interactive environment, the
same as an unkeyed port. When the caller is the interactive
environment, the root file's local table is copied there,
the same table `driver-load-file!` copies, so a later form
in that environment sees it.
`tests/checkpoint-18.rkt` evaluates `boids.aloe` with its
source path and then evaluates `(demo step)`.
`tests/checkpoint-52.rkt` evaluates `identities.aloe` with
its source path and then uses `x`.
`tests/checkpoint-81.rkt` evaluates a `load` of
`gel/loop.aloe` with no source path and then sends
`gel-rows`.

The explicit-load census makes these loads. `gel/main.aloe`
uses `GelStack`, so it loads `stack.aloe`. That file's
table includes `gel-empty-stack`. `gel/loop.aloe` uses
`GelRow` and `gel-rows`, which `menu.aloe` defines, so
`loop.aloe` loads `menu.aloe`. `GelPicks` and `GelPick` are
defined in `loop.aloe`. `file.aloe` uses `Text` and
`Position`, so it loads `lib/text.aloe`. It already loads
`editor.aloe` and `lib/fs.aloe`. `prod.aloe` and `pow.aloe`
each send `Num new`, and `Num` is defined in `num.aloe`, so
each loads `num.aloe`. `identities.aloe` uses `Sym`, so it
loads `sym.aloe`. The census does not add a load of
`lib/option.aloe` for `Option`. That name is the base class
from the visibility layer.

A name used in a loaded file and defined in the file that
loads it cannot be repaired by a load of that loader. The
explicit-load layer moves that definition into a new file
both sides load. `Math` leaves `examples/mpl/core.aloe`.
`core.aloe` and the class files load that new file. A cycle
stays an error. This layer does not split `file.aloe`.
Adding the `lib/text.aloe` load is not that split.

The visibility layer adds a load of the defining file to a
test entry point only when the loaded root's table lacks a
name the test uses. After the explicit-load layer,
`main.aloe` loads `editor.aloe`, `lib/text.aloe`, and
`lib/fs.aloe` directly, because it uses `AloemacsEditor`,
`Text`, `Position`, `Path`, and `Fs`. It does not load
`lib/option.aloe` for `Option`. `Option` is the base class
from the visibility layer. Those export tables include
`UndoFrame`, `Span`, and `EditResult`, so a driver that
loaded only `main.aloe` still sees them, and this layer may
find no entry point to edit. Adoption lists the entry points
that break when a split stops a loaded file from exporting
a name the root does not use. The spec finds them. This
charter does not freeze the list.

The file-environment checkpoint's `SPEC.md` sentence and its
`docs/decisions.md` entry state both meanings with one
example: a file that loads `editor.aloe` does not receive
`Span`, and the same form at the prompt receives
`editor.aloe`'s local table, which includes `Span`.

### 4.5 The base

A base is what `make-driver` builds and what `aloe/main.rkt`
builds. Both install the list, string, and int libraries on
the kernel bindings. User definitions do not live there.
`driver-inject-host!` writes the driver base. `fold` is a
method on the shared `List` object. The spec names the
bindings from the code.

The visibility layer also installs `lib/option.aloe`
through [`aloe/library.rkt`](../../../../aloe/library.rkt),
beside list, string, and int, so both constructions get it.
No other library is added. The install is a cache entry
under that file's resolved path. It uses the same read-once
promise as the other three libraries. A query whose document
is one of these four files installs that library from the
buffer's bytes instead of forcing the promise. Today
`make-type-environment` always forces the promise. `String find` returns
that `Option`, in the checker and the evaluator. It does not
resolve whichever `Option` the caller has bound. `Option`
still has a defining path, `lib/option.aloe`. A different
file that defines `Option` collides with that file. An
existing `(load "option.aloe")`, and any load the census
adds, is a hit of that one class. Nothing is removed.
modules 000 does not install it.

Hover and completion check the queried buffer as a file
module at the document's path, in a fresh base. Nested loads
in that buffer use the file rule. The buffer's own
definitions live in that file environment. The names hover
resolves are the names a load of that file would resolve.
A buffer whose document path is an installed base library
is checked as that library's definition, not as a second
copy. The query's base installs that library from the
buffer's bytes, so an edit is what hover sees. Those bytes
are the cache entry for the document path. They are not a
changed-bytes error against the file on disk. The
resolution path may be the temporary sibling from
[`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §5.
Hover inside `lib/option.aloe` resolves. The same rule
covers `lib/list.aloe`, `lib/string.aloe`, and
`lib/int.aloe`. The spec chooses whether the query takes an
identity path beside the resolution path, or the snapshot
carries the original name. Either choice meets this rule.

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
same check-time error. When that binding has a defining
file, the error names the file, so `Option` names
`lib/option.aloe`. A base name with no file says the
language base.

This error is the only collision tool in this series. Two
files that define `View` and never meet are legal. If
adoption cannot drop a prefix without a new tool, the spec
writer stops and reports it.

### 4.7 Defining path

Every class a file defines records that file's resolved
path. Kernel classes record none. A class defined at the
prompt or in an unkeyed port records none. A mismatch and a
hover print the path for every class that has one, whether
or not another class shares the short name. A compound type
such as `(Option Position)` carries the path of each class
in it, including the type arguments. The §7 amendment says
where each path is printed.

`type->datum` keeps today's shape. Hover's type line is
`(format "~s" datum)` over the datum the observation stores,
and that observation is built from `type->datum`. Mismatch
text calls `type->datum` in the `expected ~a, got ~a`
sentences. The path is a second rendering. The spec chooses
whether the observation carries a path-bearing datum beside
the plain one, or hover and mismatch messages format from
the type record. Either way the plain datum stays what the
`type->datum` tests see, and those calls are not rewritten
to carry a path.

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
snapshot carries the original name. Either choice meets the
cache rule in §4.5.

This lands with or after the visibility layer, not in
modules 000. It amends §7 of that spec. The series does not
overlay a dirty buffer of one file onto a nested load of
another.

### 4.8 Methods

`define-methods` appends to the shared class record. A method
body is checked and evaluated in the file that wrote it.
Methods written inside the class form keep the class's
environment, because that is the same file. A later file can
add methods when the class name is in its environment.

Each method, or each `define-methods` group, records the
writing file's environment. The class form carries the
defining file's type environment. Each `define-methods`
group carries its own. The spec chooses per-method or
per-group storage. The evaluator uses that record for the
body. `List`, `Int`, and `String` get the same per-group
record. A later `define-methods` does not overwrite the
environment of the methods already there.

The checker uses that same record for parameter
annotations, return annotations, field annotations, and the
deferred generic body check. Field annotations include
construction, `with`, `case` payload binders, and field
access. The sites are the ones named in §2. Argument
expressions still infer in the caller's environment. A
generic class with an implicit constructor, including
`AloemacsSession`, re-checks the body in the writing file's
environment, with the call's substitution. The names in the
signature mean what they meant in the file that wrote them.
`check-class-definition!` and `check-method-types!` already
run in that file. The spec does not retarget them.

A `define-protocol` records the writing file's environment.
Its signatures resolve there. When a class is checked
against a protocol, the protocol's annotations use the
protocol's file and the class's annotations use the class's
file. Conformance runs when the outermost check finishes,
for each root and each hover query, after that check's
forms have run. The walk is every class in the checker's
cache, every class bound in the file environment being
checked, and every class bound in the interactive
environment. Hover inside `sym.aloe` conforms `Sym`, which
is bound in that file and not in the interactive
environment. Each annotation is resolved in its recorded
environment. A `define-methods` in the root that adds the
protocol methods is part of those forms, so a class the
root did not load directly is still checked. Conformance
does not run at the end of the class's file, before the
loader's `define-methods`.

Hover inside `sym.aloe` is still JSON null.
[`docs/editor/lsp/spec.md`](../../../editor/lsp/spec.md) §7
turns a failed check into null. The query fails at
conformance: `Math` is bound through the new file, and
`core.aloe` does not run, so the protocol methods are
absent. Today the same hover fails earlier, on `Math`
being unbound.

Overload selection uses the class record for a class
parameter and the protocol record for a protocol parameter.
The checker and the evaluator both do. Two protocol records
with the same short name do not unify. Today
`define-protocol` evaluates to void, and the class record
stores the protocol's symbol. This series binds a runtime
protocol record in the writing file's environment, and the
class record references that record. For a class parameter,
the evaluator looks the annotation up in the method's
environment and compares class records with `eq?`. Classes
are already bound there, so that lookup adds no new
binding. That method environment does not exist during the
overload slice in §4.10. That slice resolves the annotation
in the one shared environment, in the checker and the
evaluator, and compares records with `eq?`. It does not
read the class's stored environment. The file-environment
checkpoint retargets the lookup to the method record. A
protocol parameter follows the same split: the overload
slice finds the protocol record in the shared environment,
and the file-environment checkpoint finds it through the
method record. A sole method, `Mirror invoke`, and
`Signature accepts?` keep today's comparison of an
annotation symbol to the short name. A sole method is safe
because the checker has already rejected the other class.
This series does not change those three.

This lands in the visibility layer. The reproduction is
`matching-picks` on `GelStack`: `gel/loop.aloe` adds it, and
the body names `GelPicks` and `GelPick`, which that file
defines. The same file names `GelRow` and `gel-rows`, which
`menu.aloe` defines, so the census load in §4.4 is what
makes those names resolve. A send of an `AloemacsSession`
method from a file
that has not loaded `AloemacsBuffers` still typechecks.
This series does not give each importer a private method
table and does not scope selectors.

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

1. **modules 000 — run-once.** §4.2 only, including the
   list, string, and int cache seeds. The spec names any
   current test that loads one path twice into one driver.
2. **Explicit loads, while file-to-file load still includes.**
   The census is the `.aloe` files under `examples/`, `lib/`,
   `gel/`, and the `tests/` fixtures the suite loads. It does
   not edit `archive/`. A string evaluated in the interactive
   environment is not a census entry. §4.4 names the loads
   this layer adds, including `file.aloe` loading
   `lib/text.aloe`, `gel/loop.aloe` loading `menu.aloe`,
   `gel/main.aloe` loading `stack.aloe`, `identities.aloe`
   loading `sym.aloe`, `prod.aloe` and `pow.aloe` loading
   `num.aloe`, and `core.aloe` together with the class files
   loading the new Math file. The census skips `Option`, as
   §4.4 says. The spec lists every added load and every test
   that pins `file.aloe`'s leading load datums, and updates
   those pins. It stores no count in prose. This layer does
   not split `file.aloe` and does not drop prefixes. Its
   acceptance is the census and a green suite. There is no
   second checker that walks identifiers. The visibility
   layer going green is the proof the census was complete.
   The spec writer may split this layer by tree.
3. **Visibility.** §4.4, §4.5, §4.6, and §4.8. The spec
   splits this layer. Installing `Option`, and overload
   identity, are earlier slices. Each may be its own
   checkpoint, or they may share one, and both finish before
   file environments. The overload slice resolves annotations
   in the shared environment, as §4.8 says. File
   environments, the two copy rules, collisions, method and
   protocol records, and root-end conformance are one
   checkpoint, so the suite stays green. That checkpoint is
   not split further. The spec stages the work inside it, in
   this order, so one implementer can pace it without opening
   another number: file environments and the two copy rules,
   then collisions, then method and protocol records, then
   root-end conformance. The checkpoint is complete when the
   suite is green. If the implementer proves the checkpoint
   too big, the implementer stops and sends it back.
   This layer updates a test entry point only when §4.4 says
   the root's table lacks the name, and it may find none.
   The spec's own tests show a load of `editor.aloe` does not
   bind `Span`, `String find` returns the base `Option`, a
   third file that loads two `View`s errors with both paths,
   an overloaded send whose static type is a protocol does
   not run the method written for a different class of the
   same short name, two protocols of one short name do not
   unify, Gel's two roots still work, `matching-picks`
   resolves `GelPicks` and `GelRow`, and a second driver does
   not see the first driver's classes. MPL still conforms.
   Hover inside `sym.aloe` is JSON null.
4. **Defining path.** §4.7. This stays its own layer. It does
   not join the visibility layer, and it does not move before
   layer 3 or after adoption. The spec
   lists every test whose exact hover text or mismatch text
   changes, and stores no count in prose. Known hover
   goldens include `tests/editor/lsp/000-hover.rkt`,
   `003-buffer-snapshots.rkt`, `004-hover-results.rkt`,
   `005-framing.rkt`, `006-json-rpc.rkt`,
   `007-lifecycle.rkt`, `008-adapter-failures.rkt`,
   `009-launch.rkt`, and
   `tests/editor/completion/003-lsp-completion.rkt`. This
   charter does not freeze that list.
5. **Adoption.** §4.11. Last. The spec writer may split it by
   editor area.

modules 000 absorbs neither the census nor the visibility
layer. The census stays its own layer. The spec does not
fold it into visibility.

`SPEC.md` changes in the checkpoint that makes the sentence
true. modules 000 changes the once-only behavior and leaves
"same environment" true for file-to-file load. The
file-environment checkpoint changes what a file-to-file load
introduces and amends §8's "modules beyond `load`". The
spec includes the `docs/decisions.md` paragraph for each
observable change and assigns it to that checkpoint. This
series does not edit `docs/philosophy.md`.

### 4.11 Adoption

The closing layer splits `examples/aloemacs/file.aloe`
toward one class per file and removes the `Aloemacs` prefix
in the same move. A class is moved once. The checkpoint that
moves it drops its prefix.

A set of classes that form a cycle through field types stays
in one file. The spec lists that set from the field graph.
A one-way reference is a load. `define-methods` in a later
file, after a load of the class, may stay. The body runs in
the writing file, per §4.8. That is the shape the window
tree and the window rectangle may keep when their classes
are split.

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
feature series. The spec still specifies the layer, and it
repeats that the checkpoint manager waits for that ask.
The checkpoint manager does not read this charter.

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
loads while file-to-file inclusion remains, including the
loads §4.4 names and the move of `Math` to its own file;
within visibility, `Option` on the base and overload
identity, resolving annotations in the shared environment,
before file environments, non-re-export, method records,
and root-end conformance, with the interactive environment
still receiving each root's local table;
defining paths in mismatches and hover, as their own layer;
adoption of Aloemacs, last, issued only when the human asks.

If you have been told to read this file, this is the whole assignment.
