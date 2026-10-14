# modules 007 — Collisions

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

A load no longer replaces a different definition silently. When two
files' definitions of one name meet, the checker raises one error that
names where each was defined.

- Every binding in a base, an interactive environment, or a file
  environment records its **origin**: the resolved path of the file
  that defined it, `prompt`, or `base`.
- A load copies a name only where no binding with a different origin is
  visible. Otherwise it raises
  `typecheck: name collision: View is defined by A and by B`, and
  nothing from that copy lands.
- A file may not define a name the base binds, or a name one of its own
  loads copied in. The prompt may still shadow and replace.

This is slice 3f of the spec, the eighth checkpoint. It is small: the
manager's scratch version is about 80 lines in `aloe/type.rkt` alone,
and one existing test case changes. Stop when the focused proof and the
whole suite pass. Do not start layer 4 (defining paths).

## Authority, identity, and starting point

- Identity: **modules 007**, filed as
  `docs/design/implementation/modules/checkpoints/007-collisions.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. Evaluation
  is send with a literal selector. Function objects run only through
  `call`. No inheritance, mutation, macros, implicit Int/Float
  coercion, or new special forms.
- Predecessors, all committed: **000** (`5d435a5`, the per-base load
  cache, the changed-bytes error, keyed roots), **001** (`efe39e7`,
  explicit loads and the census), **002** (`0f026a6`, `Option` on the
  base; a query of a base library installs it from the buffer), **003**
  (`1ab41bb`, overload identity), **004** (`c6a0333`, method and
  protocol records), **005** (`f1311a9`, root-end conformance), **006**
  (`0e20fae`, file environments and the copy rule).
- [../spec.md](../spec.md) governs. This checkpoint is its §6.6:
  - §2: base, interactive environment, file environment, local
    environment, cache, entry, exports, **origin**, displayed path.
  - §6.6: this slice, including the two decisions below.
  - §8: the error row.
  - §12, row 3f: the `SPEC.md` and `docs/decisions.md` text.
  - §3: out of scope. No `import`, no `prefix`, `only`, or `rename`,
    no export lists.
- **Decided by the human, 2026-10-14**, and recorded in spec §6.6:
  - A file that defines a name one of its own loads copied in from
    another file is the collision error.
  - A `load` or a definition inside a local scope is not checked.

### The tree at issuance

Line numbers are approximate; search before editing.

- `aloe/type.rkt`:
  - `type-environment` has the fields `bindings parent int-class
    string-class option-class load-cache path`. `path` is the resolved
    path of a file environment and `#f` everywhere else.
  - The constructors are `make-type-environment` (a raw kernel
    environment; a base once the libraries are installed),
    `make-local-type-environment`, `make-file-type-environment`,
    `make-interactive-type-environment` (today it calls
    `make-local-type-environment`), and the shared
    `make-child-type-environment`. `type-environment-base` walks to
    the end of the parent chain.
  - `type-environment-set!` has five callers: the `define-expr` and
    `define-protocol-expr` branches of `infer-expression`,
    `check-class-definition!`, `copy-exports!`, and
    `type-environment-inject-host!`.
  - `typecheck-once!` is the one load rule for nested loads, keyed
    roots, and the two query hooks. On a miss it completes the entry,
    then calls `(copy-exports! loader exports)`; on a hit it calls
    `copy-exports!` with the entry's exports. Today a copy replaces
    whatever the loader binds.
  - Exports are `(name . type)` pairs, the file's own `define`,
    `define-class`, and `define-protocol` bindings in order. The
    `Option` seed exports `(Option . <the base's Option class>)`.
  - `record-checked-option-class!` records the base's `Option` class.
    A driver, both `aloe/main.rkt` constructors, and a query base call
    it, including the 002 query base that installs `lib/option.aloe`
    from the buffer.
  - `displayed-path` (from `aloe/library.rkt`) already prints the
    path in the 000 changed-bytes error.
- The loader is the environment a `load` form is checked in: a file
  environment, the interactive environment, or, for a `load` written
  inside a `let`, `fn`, method body, or `case` clause, that local
  environment. For keyed roots it is the environment the caller passed.
  Usually that is an interactive environment; a raw checker
  environment passed to `typecheck-source` is its own base and
  receives the copies.
- `aloe/eval.rkt` copies with `env-define!` and replaces. It is not
  changed.

### Scratch run

The manager implemented this slice in a copy of the repository. The
change was confined to the checker in `aloe/type.rkt`: about 80 lines.
On that copy, before any test edit, every test file was run alone and
under `-j 4`. **Exactly one test case failed**: "a later load replaces a
prompt name" in `tests/modules/006-file-environments.rkt`, which the
spec says becomes this error (Migration). No other program the suite
loads collides. The manager then added the fixtures below; the census
(`tests/modules/001-census.rkt`) passed with them, adding one check per
fixture. Every case in the focused proof was probed on that copy, with
the exact messages below, and the first-run predictions were probed on
a copy of the committed tree.

## Exact file scope

### May create or edit

- `aloe/type.rkt`.
- `SPEC.md` and `docs/decisions.md`: only the text in **Language law**.
- `tests/modules/006-file-environments.rkt`: only the change in
  **Migration**.
- `tests/modules/007-collisions.rkt`: new.
- The eighteen new fixtures under `tests/modules/fixtures/` listed in
  **Fixtures**, with exactly that content.

### Must leave untouched

- `aloe/env.rkt` and `aloe/eval.rkt`. The spec allows them, but this
  slice does not need them. The collision is a check-time error, and
  every path that evaluates (`driver-eval!`, `driver-prepare!`,
  `driver-load-port!`, `driver-load-file!`, `eval-source`,
  `eval-program`, `eval-datum`) checks the whole program first, so the
  evaluator never sees a program that collides. The evaluator records
  no origins.
- `aloe/main.rkt`, `aloe/driver.rkt`, `aloe/expression-query.rkt`,
  `aloe/completion-query.rkt`, `aloe/lsp.rkt`, `aloe/parse.rkt`,
  `aloe/library.rkt`, `aloe/private/`, and every host module.
- Every `.aloe` file under `examples/`, `lib/`, and `gel/`, and every
  existing fixture.
- Every test except the one case in **Migration**.
- `CHECKPOINTS.md`, `docs/checkpoints/`, `docs/philosophy.md`, the
  editor specs, this folder's `README.md`, `charter.md`, `spec.md`,
  this checkpoint, and every other design document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Origins

Only the checker records origins. A base, an interactive environment,
and a file environment each keep an origin for every binding in their
own table. A local environment (`let`, `fn`, a method body, a `case`
clause) keeps none. In the manager's version a new `origins` field on
`type-environment` held a `hasheq` for those three kinds and `#f` for a
local environment. `make-interactive-type-environment` then built its
environment through `make-child-type-environment` with a table, not
through `make-local-type-environment`.

An origin is a resolved path, `prompt`, or `base`:

- **Base.** `Option`'s origin is the resolved path of `lib/option.aloe`.
  Record it where the base records its `Option` class
  (`record-checked-option-class!`). Every other base binding has
  origin `base`: the kernel bindings (`dummy`, `List`, `Int`,
  `String`, `Symbol`, `Mirror`) and every injected host (`term`,
  `fs-host`).
- **Interactive environment.** A `define`, `define-class`, or
  `define-protocol` records `prompt`.
- **File environment.** A definition records the file's resolved path
  (its `path` field).
- **A copy** records the resolved path of the cache entry it came from.
  Every export is a definition made by the file at that path. The
  `Option` seed's path is `lib/option.aloe`'s.

The **visible binding** of a name from a base, interactive, or file
environment is the binding in its own table, else the binding in its
base. For a base, that is its own table.

### 2. The copy rule

When `copy-exports!` copies a file's exports into a loader that keeps
origins, it first compares each export, in order, with the loader's
visible binding of that name:

- no visible binding: copy it;
- a visible binding with the same origin: nothing to do (the same file
  defined it; for `Option`, the installed class);
- a visible binding with a different origin: raise the collision
  error (§5). The visible binding's origin is named first and the
  export's origin second.

All exports are compared before any is bound, so **nothing from a copy
that collides lands**. Bindings from earlier copies and definitions
stay. Then each export that is copied is bound and records its origin.

Copying the same cached definition again is therefore never an error:
`lib/option.aloe` reached through `lib/text.aloe` and `lib/fs.aloe`, a
diamond of loads, or one file loaded twice into one loader.

A collision during a miss happens after the loaded file's checker entry
is completed. That entry stays completed: the file itself checked
cleanly, and a later load of it into a loader where it does not collide
is a hit that copies. The check that contained the colliding `load`
fails as any type error does. If it was a keyed root's or a loading
file's check, that entry is removed as today, and nothing evaluates.

### 3. The definition rule

In a **file environment**, before a `define`, `define-class`, or
`define-protocol` form is checked (before its value, its protocol
signatures, or its class body):

- if the base binds the name: raise the collision error, naming the
  base binding's origin (`lib/option.aloe` for `Option`, otherwise the
  language base) first and the file's path second;
- otherwise, if the file environment's own table binds the name with a
  different origin (one of the file's loads copied it in): raise the
  collision error, naming that origin first and the file's path second
  (decided by the human);
- a name the file itself defined earlier is replaced (same origin).

In the **interactive environment** a definition always binds and
records `prompt`. It replaces a binding of the same name: a shadowed
base name (the `Option` goldens of `SPEC.md` §9), a name a load copied
in (`host/racket/aloemacs-run.rkt` redefines `aloemacs-editor` after
loading `main.aloe`), or an earlier prompt definition.

In a **base** (the library installs, and a query that installs a base
library from its buffer) and in a **local environment**, definitions
are unchanged and unchecked. So hover inside `lib/option.aloe` is not
this error.

Consequence, not separately tested: an editor query of a buffer that
defines a base name, or whose loads collide, raises this error, so it
fails as any query does (JSON null in the LSP adapter).

### 4. Local scopes (decided by the human)

`load` and `define` are expressions, so either may appear inside a
`let`, a `fn` body, a method body, or a `case` clause. There, as 006
left it, the binding lands in that local scope and no collision rule
applies: a local environment keeps no origins, so `copy-exports!`
copies into it as today and a definition binds as today.

### 5. The error

A type error (`exn:fail:aloe-type`, raised with the checker's
`raise-type-error`):

```text
typecheck: name collision: <Name> is defined by <A> and by <B>
```

Each side is written as:

- a resolved path: its displayed path (`displayed-path`, as the
  changed-bytes error prints it: repository-relative with `/` inside
  the repository, otherwise the resolved path);
- `prompt`: `the prompt`;
- `base`: `the language base`.

`A` is the binding already visible; `B` is the file whose load or
definition collided. For example:

```text
typecheck: name collision: View is defined by tests/modules/fixtures/view-a.aloe and by tests/modules/fixtures/view-b.aloe
typecheck: name collision: View is defined by the prompt and by tests/modules/fixtures/view-a.aloe
typecheck: name collision: Option is defined by lib/option.aloe and by tests/modules/fixtures/defines-option.aloe
typecheck: name collision: List is defined by the language base and by tests/modules/fixtures/defines-list.aloe
```

### 6. What stays

- 000–006's rules: run once per base, changed bytes, cycles, missing
  files, record-based overloads, method and protocol records, the
  conformance walk, the base `Option`, file environments, and copying
  on a miss and on every hit.
- A second definition of a name in one environment replaces the first:
  at the prompt, through `driver-eval!`, and in a file that defines a
  name twice.
- `driver-inject-host!` still refuses a name bound anywhere in the
  interactive environment's chain.
- The evaluator, including raw `eval-expr` flows that never check,
  copies and replaces as in 006.
- No defining paths on class records, no `pathed-type`, no hover
  `from:` line (layer 4).

## Language law

`SPEC.md` §11: append to the end of the first bullet (the `load`
bullet, which now ends "A program given with a source path is a file
module."):

> A copied name does not replace a different definition already
> visible where it lands; that is a type error naming both origins. A
> file may not define a name the base binds, or a name one of its
> loads copied in. A second definition of a name in the same
> environment replaces the first.

`docs/decisions.md`: add one section at the end, dated the day you
land it:

> ## Load collisions (YYYY-MM-DD)
>
> Decided: the identity of a binding is its defining file plus the
> name; a different definition already visible is a check-time error
> naming both; the prompt may shadow the base, a file may not; a file
> may not define a name its own loads copied in; a load or definition
> in a local scope is not checked. Rejected: `prefix`, `only`,
> `rename`, and silent replacement across files.

## Migration

`tests/modules/006-file-environments.rkt`, the case "a later load
replaces a prompt name", pins the old rule. Replace that whole test
case with:

```racket
(test-case "a later load of a prompt name is a collision"
  (define state (make-driver))
  (driver-eval! state '(define-class Point (fields) (methods)))
  (define prompt-point (driver-eval! state 'Point))
  (check-equal?
   (raised (lambda () (driver-eval! state (load-datum point-path))))
   (list #t (string-append "typecheck: name collision: Point is defined by "
                           "the prompt and by examples/point.aloe")))
  (check-eq? (driver-eval! state 'Point) prompt-point)
  (check-not-exn
   (lambda () (type-of (parse-datum '(Point new)) (checker state)))))
```

No other existing test changes.

## Fixtures

New files under `tests/modules/fixtures/`, exactly as written. Each is
a census file and loads every file whose names it uses.

`view-a.aloe`:

```scheme
(define-class View
  (fields)
  (methods))
```

`view-b.aloe`:

```scheme
(define-class View
  (fields (x Int))
  (methods))
```

`view-both.aloe`:

```scheme
(load "view-a.aloe")
(load "view-b.aloe")
```

`view-redefined.aloe`:

```scheme
(load "view-a.aloe")

(define-class View
  (fields)
  (methods))
```

`view-after-alpha.aloe`:

```scheme
(define alpha 1)

(define-class View
  (fields)
  (methods))
```

`view-b-user.aloe`:

```scheme
(load "view-b.aloe")

(define b-view (View new 5))
```

`view-local.aloe`:

```scheme
(load "view-a.aloe")

(define local-load
  (let ((x 1))
    (load "view-b.aloe")))

(define a-view (View new))
```

`defines-option.aloe`:

```scheme
(define-class (Option T)
  (constructors
    (None (fields))
    (Some (fields (value T))))
  (methods))
```

`defines-list.aloe`:

```scheme
(define List (1 + "a"))
```

`defines-mirror.aloe`:

```scheme
(define-protocol Mirror)
```

`defines-fs-host.aloe`:

```scheme
(define fs-host 1)
```

`defines-twice.aloe`:

```scheme
(define twice-name 1)

(define twice-name "two")
```

`diamond-leaf.aloe`:

```scheme
(define-class Leaf
  (fields)
  (methods))
```

`diamond-left.aloe`:

```scheme
(load "diamond-leaf.aloe")

(define left-leaf (Leaf new))
```

`diamond-right.aloe`:

```scheme
(load "diamond-leaf.aloe")

(define right-leaf (Leaf new))
```

`diamond-top.aloe`:

```scheme
(load "diamond-left.aloe")
(load "diamond-right.aloe")
(load "diamond-leaf.aloe")
(load "diamond-leaf.aloe")

(define top-leaf (Leaf new))
```

`shared-one.aloe`:

```scheme
(define shared 1)
```

`shared-two.aloe`:

```scheme
(define shared 2)
```

## Tests

### Focused proof: `tests/modules/007-collisions.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. **Cases 1–10 fail there and cases 11–14 pass.** No
new export is needed, so the file compiles against the found tree.

Use fresh drivers unless a case says otherwise. Load a fixture with
`driver-eval!` of `(load "<absolute path>")` unless a case says
`driver-load-file!`. Pin each error as the pair of
`exn:fail:aloe-type?` and the exact message. Observe "bound in both
halves" with `env-bound?` on `driver-runtime-environment` and
`type-environment-bound?` on `driver-type-environment`. Observe
identity with `eq?` on runtime values.

1. **A third file loads both.** Loading `view-both.aloe` raises
   `typecheck: name collision: View is defined by tests/modules/fixtures/view-a.aloe and by tests/modules/fixtures/view-b.aloe`.
2. **Two loads into the prompt, and the entry survives.** Load
   `view-a.aloe` and capture the runtime `View`. Loading `view-b.aloe`
   raises the same message as case 1. Afterwards `View` is still
   `eq?` to the captured class, and `(View new)` typechecks and runs.
   Then loading `view-b-user.aloe` raises nothing: `view-b.aloe`'s
   entry stayed completed, and its evaluator now runs. `b-view` is
   bound in both halves, and `View` is still `eq?` to the captured
   class.
3. **A file defines `Option`.** Loading `defines-option.aloe` raises
   `typecheck: name collision: Option is defined by lib/option.aloe and by tests/modules/fixtures/defines-option.aloe`.
4. **A file defines `List`, checked before its value.** Loading
   `defines-list.aloe` raises
   `typecheck: name collision: List is defined by the language base and by tests/modules/fixtures/defines-list.aloe`,
   not the `+` error.
5. **A protocol and a host.** Loading `defines-mirror.aloe` raises
   `typecheck: name collision: Mirror is defined by the language base and by tests/modules/fixtures/defines-mirror.aloe`.
   In a driver with `fs-host` injected (an fs double, as
   `tests/modules/006-file-environments.rkt` builds one), loading
   `defines-fs-host.aloe` raises
   `typecheck: name collision: fs-host is defined by the language base and by tests/modules/fixtures/defines-fs-host.aloe`.
6. **The prompt, then a file.** `(define-class View (fields) (methods))`
   at the prompt; loading `view-a.aloe` raises
   `typecheck: name collision: View is defined by the prompt and by tests/modules/fixtures/view-a.aloe`,
   and `View` is still `eq?` to the prompt's class.
7. **Nothing from a colliding copy lands.** `(define View 0)` at the
   prompt; loading `view-after-alpha.aloe` raises
   `typecheck: name collision: View is defined by the prompt and by tests/modules/fixtures/view-after-alpha.aloe`,
   and `alpha` is unbound in both halves.
8. **A file defines a name its load copied in.** Loading
   `view-redefined.aloe` raises
   `typecheck: name collision: View is defined by tests/modules/fixtures/view-a.aloe and by tests/modules/fixtures/view-redefined.aloe`.
9. **Two roots.** `driver-load-file!` of `shared-one.aloe` returns
   `'()`; `driver-load-file!` of `shared-two.aloe` into the same
   driver raises
   `typecheck: name collision: shared is defined by tests/modules/fixtures/shared-one.aloe and by tests/modules/fixtures/shared-two.aloe`,
   and `shared` evaluates to `1`.
10. **The prompt may replace a copied name.** Load `view-a.aloe` and
    capture `View`; then
    `(define-class View (fields (y Int)) (methods))` at the prompt.
    `(View new 1)` typechecks and runs, and `View` is no longer `eq?`
    to the captured class. Then loading `view-a.aloe` again raises
    `typecheck: name collision: View is defined by the prompt and by tests/modules/fixtures/view-a.aloe`.
    (The redefinition passes on the found tree; the reload is what
    fails there.)
11. **The same cached definition twice is not a collision.** In one
    driver, loading `lib/text.aloe`, then `lib/fs.aloe`, then
    `lib/option.aloe` raises nothing, and `Option` is `eq?` to
    `(env-lookup (env-base R) 'Option)`. In another driver, loading
    `diamond-top.aloe` raises nothing, `top-leaf` is bound, and
    `left-leaf` is not. Then two loads of `diamond-leaf.aloe` at the
    prompt raise nothing, and `Leaf` is `eq?` after each.
12. **Replacement within one environment.** Loading
    `defines-twice.aloe`: `twice-name` evaluates to `"two"` and its
    type is `String`. At the prompt, `(define p 1)` then
    `(define p "x")`: `p` evaluates to `"x"`.
13. **A local scope is not checked.** Loading `view-local.aloe` raises
    nothing (its `let` loads `view-b.aloe` while `view-a.aloe`'s `View`
    is in the file), and `a-view` is bound in both halves.
14. **A base-library query is not a collision.**
    `query-expression-at` on `lib/option.aloe` at the position of
    `self` in `self case` returns a result whose type is `(Option T)`.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/007-collisions.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Then run every test file alone (each already compiled) and confirm each
exits 0; the parallel summary is not the inventory.
`tests/aloemacs/window-pictures.rkt` has a 30 ms timing bar. It runs
at about 28 ms alone since 006, so it can fail under parallel load;
rerun it alone before calling it a failure.

After the `.rkt` edit, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt host/racket/gel-run.rkt bin/aloe`
and confirm `./bin/aloe --quit tests/modules/fixtures/box-root.aloe`
still prints `3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as you
  found it was reported;
- every test file passes, and the only edit to an existing test is the
  one in **Migration**;
- `aloe/type.rkt` is the only product file changed; no `.aloe` file
  under `examples/`, `lib/`, or `gel/` changed;
- `SPEC.md` and `docs/decisions.md` carry exactly the text above;
- the whitespace check is clean (also for new, untracked files) and the
  file scope was respected.

Report the results and stop. Do not commit. Do not start layer 4.

## Non-goals

- Defining paths, `pathed-type`, hover `from:` lines, or the
  ` (A vs B)` mismatch suffix (layer 4).
- Origins in the evaluator, or a collision check in raw `eval-expr`
  flows that skip the checker.
- `prefix`, `only`, `rename`, `import`, export lists, private names, or
  any other collision tool.
- Checking loads or definitions in a local scope, or making a `load`
  in a local scope an error.
- Splitting `file.aloe` or dropping any prefix (adoption, layer 5).
- Any `.aloe` change under `examples/`, `lib/`, or `gel/`.
