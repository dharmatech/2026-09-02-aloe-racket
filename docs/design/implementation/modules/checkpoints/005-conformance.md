# modules 005 — Root-end conformance

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

Protocol conformance still runs once, when a root check finishes. The
set of classes it checks changes from "every class bound on the
checked environment's parent chain" to:

- every class exported by a completed entry in the checker's load
  cache;
- every class bound in the file environment being checked (and its
  parents);
- every class bound in the interactive environment (and its parents).

Each class is checked once. The check of a class is unchanged since
modules 004: each protocol signature needs a conforming method, with
the protocol's annotations resolved in the protocol's environment and
the method's in the method's.

Until slice 3e the file environment and the interactive environment
are the one shared environment, and only the `Option` seed exports a
class. So this walk accepts exactly the programs today's walk accepts.
It exists so that, once files get their own environments, a class
reachable only through a load is still checked. To carry the cache
part, a checker cache entry's exports become bindings (a name and its
type) instead of bare names.

This is slice 3d of the spec, the sixth checkpoint. Stop when the
focused proof and the whole suite pass. Do not start slice 3e.

## Authority, identity, and starting point

- Identity: **modules 005**, filed as
  `docs/design/implementation/modules/checkpoints/005-conformance.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. SPEC §3.3 is
  the protocol law this slice amends. Evaluation is send with a
  literal selector. No inheritance, mutation, macros, implicit
  Int/Float coercion, or new special forms.
- Predecessors, all committed: **000** (`5d435a5`, the load cache and
  its seeds), **001** (`efe39e7`), **002** (`0f026a6`, `Option` on the
  base; the `Option` seed is the one entry with an export), **003**
  (`1ab41bb`), **004** (`c6a0333`, method and protocol records;
  `method-signature-conforms?` already resolves in the recorded
  environments).
- [../spec.md](../spec.md) governs. This checkpoint is its §6.4:
  - §2: "Cache, entry, exports" (exports are the bindings a file
    itself made) and "Root check".
  - §6.4: this slice in full.
  - §12, row 3d: the `SPEC.md` text. No `docs/decisions.md` edit.
- Slice 3e creates file environments, computes every entry's exports,
  and passes a file environment and an interactive environment that
  differ. Do not anticipate any of that here.

### The tree at issuance

Line numbers are from the tree at issuance (2026-10-13) and are
approximate; search before editing. All in `aloe/type.rkt`.

- `typecheck-program` (line ~568) runs
  `(check-protocol-conformance! environment)` after its forms when it
  is entered at depth zero (`outermost?`). A nested load enters at a
  deeper depth and does not run conformance.
- `check-protocol-conformance!` (line ~1081) walks the given
  environment and its parents, visits every `class-type` binding once
  (a `seen-classes` hasheq), and for a class with a protocol raises
  `class ~a does not implement protocol ~a method ~a` for the first
  signature no method conforms to. It calls
  `method-signature-conforms?` with the class, method, protocol, and
  signature (004).
- `checker-load-entry` (line ~90) holds `state`, `source-bytes`, and
  `exports`. `typecheck-once!` records running and completed entries
  with exports `'()`. `record-checked-libraries!` (line ~662) records
  the four seeds with exports `'()`, `'()`, `'()`, and `'(Option)`: a
  list of names. Nothing reads exports yet.
- Evaluator entries (`aloe/eval.rkt`) also carry exports; this slice
  does not touch them.

**Probes (today's tree).** In a driver:

- `driver-load-file!` of `examples/mpl/core.aloe` returns `'()`: its
  nested `sym.aloe`, `sum.aloe`, ... define classes that opt into
  `Math` without its methods, and its own `define-methods` forms
  supply them before the root ends.
- `driver-load-file!` of a root that loads `examples/mpl/sym.aloe` and
  then evaluates `(define after-load 1)` raises
  `typecheck: class Sym does not implement protocol Math method show`,
  and `after-load` is then bound in the checker environment: the root's
  own later form was checked before conformance ran.
- `query-expression-at` inside `examples/mpl/sym.aloe` raises that same
  error (the LSP adapter turns any query failure into a null hover);
  inside `examples/mpl/core.aloe`, on `self` in `(self name)`, it gives
  type `Sym`.

**Scratch run.** The manager prototyped this slice on a copy of the
repository (binding-shaped exports for the `Option` seed, the walk
below, the test hook) and ran the whole suite: 2944 tests in 224 files
passed, no test file crashed. Every probe above held. In a fresh
driver the walk visited `Option` once; after the prompt defined its
own `Option`, twice: the installed class through the seed's export,
the prompt's through the environment. No existing test changes.

### Size

Small: one data-shape change in the seed recorder, the walk rewritten
as a function of the cache and two environments, a test hook, one
fixture, one `SPEC.md` sentence, and one focused test.

## Exact file scope

### May create or edit

- `aloe/type.rkt`: the checker entries' exports, the conformance walk,
  and a `module*` submodule `conformance-walk` for the test hook.
- `SPEC.md`: only the sentence in **Language law**.
- `tests/modules/005-conformance.rkt`: new.
- `tests/modules/fixtures/sym-late.aloe`: new.

### Must leave untouched

- `docs/decisions.md`: no entry in this slice.
- `aloe/eval.rkt` (including its entries' exports), `aloe/env.rkt`,
  `aloe/main.rkt`, `aloe/driver.rkt`, `aloe/library.rkt`,
  `aloe/parse.rkt`, everything under `aloe/private/`, the editor
  queries, `aloe/lsp.rkt`, and `host/racket/`.
- Every `.aloe` file other than the new fixture.
- Every existing test. `tests/checkpoint-36.rkt` and
  `tests/editor/expression-query/001-contextual-observation.rkt` pin
  conformance messages; they stay green as they are. If any test
  fails, stop and report the file and the assertion.
- `CHECKPOINTS.md`, `docs/checkpoints/`, this folder's `README.md`,
  `charter.md`, `spec.md`, this checkpoint, and every other design
  document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Checker exports are bindings

A checker cache entry's exports become a list of bindings, each a
name and the type it is bound to (`(cons name type)` or an equivalent
small struct), in definition order.

- The `Option` seed's export is `Option` bound to the type the base
  binds under `Option` right after the install (its class type).
  `record-checked-libraries!` already runs after the installs at
  every site that calls it, including the editor query base, so it can
  read that binding there. When the queried library is
  `lib/option.aloe` the seed is skipped, as today.
- Every other entry's exports stay empty. Slice 3e computes them.
- The evaluator's entries are unchanged.
- The conformance walk is the only reader.

### 2. The walk

Conformance visits, in this order, each class record once (`eq?`):

1. for each **completed** entry in the checker's load cache (the cache
   of the environment being checked), each export binding whose type
   is a class type: that class;
2. each class bound in the **file environment** being checked, then in
   its parent, and so on up the chain, as today's walk does;
3. the same for the **interactive environment**.

For each visited class with a protocol, the check is today's:
signatures in order, `method-signature-conforms?` for each method, and
the first signature with no conforming method raises exactly
`typecheck: class ~a does not implement protocol ~a method ~a`. The
order of the cache part follows the cache's hash order and is not
specified; the file and interactive parts keep today's order.

Split the walk into a function that returns the visited classes and
the check that runs over them, so the test hook can read the set.

### 3. When it runs

Unchanged: once, when `typecheck-program` entered at depth zero
finishes its forms. In this slice the root passes the environment it
runs in as both the file environment and the interactive environment.
A nested load does not run conformance. A `define-methods` in the
root that supplies a loaded class's protocol methods is one of the
root's forms, so that class conforms.

### 4. Test hook

In `(submod "aloe/type.rkt" conformance-walk)`, provide
`(conformance-classes environment)`: the names of the classes the walk
visits for a root checked in `environment` (passed as both the file
and the interactive environment), in visit order, each class record
once. Two different records with one name appear twice. Nothing else
reads it.

## Language law

`SPEC.md` §3.3, in the "Rules for this slice" list, append to the end
of the bullet "Every class that opts into a protocol with signatures
must implement each required method with compatible parameter and
return types.":

> That is checked when the outermost program finishes, over every
> class the environment's base, cache, file, and prompt hold.

No other `SPEC.md` edit. No `docs/decisions.md` entry.

## Tests

### Fixture

`tests/modules/fixtures/sym-late.aloe`, exactly:

```scheme
(load "../../../examples/mpl/sym.aloe")

(define after-load 1)
```

It loads `sym.aloe` directly and uses no other name, so
`tests/modules/001-census.rkt`, which walks every fixture, stays green.

### Focused proof: `tests/modules/005-conformance.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. Case 4 fails there (the hook does not exist). Cases
1–3 pin behavior that holds before and after.

1. **The MPL shape conforms.** In a fresh driver,
   `driver-load-file!` of `examples/mpl/core.aloe` returns `'()` and
   raises nothing, although its nested class files define classes
   that opt into `Math` with no methods: conformance ran at the root's
   end, after the root's `define-methods` forms, and not at the end of
   each nested load.
2. **The error comes at the root's end.** In a fresh driver,
   `driver-load-file!` of `sym-late.aloe` raises an
   `exn:fail:aloe-type` with exactly
   `typecheck: class Sym does not implement protocol Math method show`.
   Afterwards `after-load` is bound in the checker environment
   (`type-environment-bound?`) and not in the runtime environment
   (`env-bound?`): the root's own later form was checked, conformance
   failed at the end, and nothing ran.
3. **Hover inside the MPL files.** `query-expression-at` on
   `examples/mpl/sym.aloe` at position 1 raises an
   `exn:fail:aloe-type` with that same message; the LSP adapter turns a
   failed query into a JSON null hover. `query-expression-at` on
   `examples/mpl/core.aloe`, at `self` in its first `(self name)`,
   gives type `'Sym`.
4. **The cache is walked.** With `conformance-classes` on a fresh
   driver's checker environment, `Option` appears exactly once (the
   seed's export and the base binding are one record). After the
   prompt defines the SPEC §3.1 `Option` (the
   `define-class (Option T)` form with `None` and `Some`), `Option`
   appears exactly twice: the installed class, now reachable only
   through the seed's export, and the prompt's class. Compare counts,
   not order.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/005-conformance.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Read the whole suite's output for files that exited non-zero without a
failure location (a load-time crash), not only for failures.

After the `.rkt` edit, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt bin/aloe` and confirm
`./bin/aloe --quit tests/modules/fixtures/box-root.aloe` still prints
`3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as you
  found it was reported;
- the whole suite passes with no existing test edited, including
  `tests/modules/001-census.rkt` with the new fixture;
- `aloe/type.rkt` is the only product file changed, and `SPEC.md`
  carries exactly the sentence above;
- the whitespace check is clean and the file scope was respected.

Report the results and stop. Do not commit. Do not start slice 3e.

## Non-goals

- File environments, an interactive environment distinct from the
  file environment, or computing exports for any entry but the
  `Option` seed (slice 3e).
- Changing when conformance runs, its error text, or how a single
  class is checked.
- Evaluator exports, origins, collisions, or defining paths.
- Any change to which programs are accepted.
