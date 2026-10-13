# modules 004 — Method and protocol records

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

Each method records the environment that wrote it, and each protocol
records the environment that wrote it. Every place that turns a
method's or protocol's annotation into a type reads that record, and
every method body runs in it.

- A method written inside a `define-class` form records that form's
  environment. A method a `define-methods` form appends records the
  environment that form is checked or evaluated in. A later
  `define-methods` never changes an earlier method's record.
- The record lives in a table on each class record, in both halves:
  user classes, and the `List`, `Int`, and `String` class objects. On
  the primitive class objects the table replaces today's single
  `environment` field, which each `define-methods` overwrites.
- The checker resolves a method's parameter and return annotations,
  and checks its body, in the method's environment; a protocol's
  signatures in the protocol's environment; a class's field
  annotations in the class form's environment. Argument expressions
  still infer where the send is.
- The evaluator runs each method body in a local environment whose
  parent is the method's environment, and the multi-candidate overload
  rule from modules 003 resolves annotations there instead of where
  the send is.

Until slice 3e every recorded environment is the one shared
environment, so a program sees one change only: a caller's local
names (a `let` or `fn` parameter) no longer leak into a method's
annotations or into the deferred re-check of a generic method's body.

This is slice 3c of the spec, the fifth checkpoint. Stop when the
focused proof and the whole suite pass. Do not start slice 3d.

## Authority, identity, and starting point

- Identity: **modules 004**, filed as
  `docs/design/implementation/modules/checkpoints/004-method-records.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. Evaluation
  is send with a literal selector. Function objects run only through
  `call`. No inheritance, mutation, macros, implicit Int/Float
  coercion, or new special forms.
- Predecessors, all committed: **000** (`5d435a5`, run-once load
  cache), **001** (`efe39e7`, explicit loads), **002** (`0f026a6`,
  `Option` on the base), **003** (`1ab41bb`, overload identity: the
  runtime `protocol-value` record, `lookup-protocol`,
  `class-value-protocol-name`, and `resolved-type-specificity`, which
  resolves multi-candidate annotations in the send's environment).
- [../spec.md](../spec.md) governs. This checkpoint is its §6.3:
  - §6.3: this slice in full. (Its "nothing a program sees changes"
    was corrected on 2026-10-13; see the Goal.)
  - §12, row 3c: no `SPEC.md` or `docs/decisions.md` edit.
  - §3: the out-of-scope list. `define-methods` still mutates the one
    shared class record and binds no name.

### The tree at issuance

Line numbers are from the tree at issuance (2026-10-13) and are
approximate; search before editing.

**Checker (`aloe/type.rkt`).** `class-info` (line ~67) has no
environment. `list-class-type`, `int-class-type`, and
`string-class-type` hold only methods (and `List`'s element
parameter). `protocol-type` holds `name` and `signatures`. Every
annotation resolves with `type-from-sexpr` in an `environment`
argument, which at these sites is the environment of the send:

| Function | What it resolves |
|---|---|
| `match-sole-method`, `try-method-match` (~1640, ~1670) | parameter annotations |
| `infer-instance-send` (~1544) | field access type; method return type; the deferred `check-method-body!` of a generic class with an implicit constructor |
| `infer-defined-list-method`, `infer-defined-int-method`, `infer-defined-string-method` (~1774, ~1852, ~1950) | return type |
| `infer-protocol-send` (~1318) | return type (its `select-method-overload` resolves the signatures' parameters) |
| `method-signature-conforms?` (~1058), from `check-protocol-conformance!` | protocol and method parameter and return annotations |
| `check-method-body!` (~1099) | parameter and return annotations; the body's local scope |
| `infer-construction` (~1404, also reached by `new*`), `infer-field-type!` (~1476), `infer-with` (~1366), `infer-case` (~775) | field annotations |

`check-class-definition!` (~852), `check-method-definitions!` (~964,
`define-methods`), and `check-method-types!` already run in the
environment of the form being defined; they are where records get
written, not sites to retarget. `select-method-overload` (~1587) is
shared by instance, `List`, `Int`, `String`, and protocol sends.

**Evaluator (`aloe/eval.rkt`, `aloe/env.rkt`).** `class-value` has an
`environment` field, the class form's environment; `apply-method`
(~1268) runs every method of the class there, including methods a
later `define-methods` added elsewhere. `list-class-object`,
`int-class-object`, and `string-class-object` (in `aloe/env.rkt`)
have a mutable `environment` field that every `define-methods` on
them overwrites (`eval.rkt` ~179–189); `apply-list-method`,
`apply-int-method`, and `apply-string-method` run every method there.
`protocol-value` holds only the name. `select-runtime-method` passes
each scoring callback the send's environment when there is more than
one candidate (003), and 003 threaded that environment through
`send-to-instance`, `send-to-list`, and `send-to-list-method`.

**A trap.** `aloe/library.rkt` parses each library once per process.
The same `method-declaration` structs are installed into every base.
A table keyed by declaration must therefore live on each class record
(one per base), never in a process-wide table: the manager's first
prototype used a process-wide table and `tests/aloemacs/split-drag-weights.rkt`
failed, because one driver's `List map` ran in another driver's
environment and built a list of the other base's `List`. Key tables
with `eq?` (`make-hasheq`); `method-declaration` is transparent, so
two equal declarations from two parses are still two methods.

**Probes (today's tree).**

- In one driver, after `(define g 1)` and
  `(define-class (Holder T) (fields (v T)) (methods (plus-g () Int (g + 1))))`,
  `((Holder new 1) plus-g)` is `2`, but
  `(let ((g "s")) ((Holder new 1) plus-g))` raises
  `typecheck: unknown message: +`: the deferred re-check sees the
  caller's `g`.
- After `(define-class K (fields) (methods))`, `(define k1 (K new))`,
  and `(define-class Uses (fields) (methods (take (x K) Int 7)))`,
  `(let ((K 5)) ((Uses new) take k1))` raises
  `typecheck: K is not a type`.
- In a raw evaluator environment `E` with `(define g 1)`, a
  `(define-methods Int (methods (first-g () Int g)))` in `E` and then
  a `(define-methods Int (methods (second-g () Int g)))` evaluated in
  `L`, a local environment over `E` that binds `g` to `2`:
  `(5 first-g)` is `2` (the field was overwritten). A class `Cell`
  defined in `E` with `(from-class () Int g)`, extended in `L` with
  `(from-later () Int g)`: both give `1`.
- In `E`, with classes `K` and `K2`, `k1` a `K`, and
  `(define-class C (fields) (methods (n (x K) Int 1) (n (x Int) Int 2)))`,
  sending `((C new) n k1)` from a local environment over `E` that
  binds `K` to the class `K2` raises `eval-aloe: unknown message: n`.

**Scratch run.** The manager prototyped this slice on a copy of the
repository (per-class method tables in the evaluator; the checker
sites above retargeted; selection in the method's environment) and
ran the whole suite: 2935 tests in 223 files passed, no test file
crashed. Every probe above then gave the result the focused proof
requires. No existing test changes in this slice.

### Size

Comparable to modules 002: new fields and tables on five checker and
five evaluator records, about fifteen retargeted resolution sites in
the checker, four body sites and the selection rule in the evaluator,
two small test-only submodules, and one focused test. One
conversation. If it is not, stop and say so.

## Exact file scope

### May create or edit

- `aloe/type.rkt`: the records, the tables, the retargeted sites, and
  a `module*` submodule `method-records` for the test accessors.
- `aloe/eval.rkt`: the records, the tables, the body sites, the
  selection rule, and a `module*` submodule `method-records`.
- `aloe/env.rkt`: the primitive class objects' table in place of
  their `environment` field.
- `aloe/private/checker-observation.rkt`: only if the expression
  observation needs a method's record; no change is expected.
- `tests/modules/004-method-records.rkt`: new.

### Must leave untouched

- `SPEC.md` and `docs/decisions.md`: no edit in this slice.
- Every `.aloe` file; `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/library.rkt`, `aloe/parse.rkt`, the editor queries,
  `aloe/lsp.rkt`, and `host/racket/`.
- Every existing test. The scratch run found none that changes; if
  one fails, stop and report the file and the assertion. Existing
  tests read `list-class-object-methods`, `string-class-object-methods`,
  `int-class-object-methods`, and `list-class-type-element-parameter`;
  keep those accessors. None reads the primitive objects'
  `environment` field.
- `CHECKPOINTS.md`, `docs/checkpoints/`, this folder's `README.md`,
  `charter.md`, `spec.md`, this checkpoint, and every other design
  document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Records

**Checker.**

- `class-info` records the environment its `define-class` form is
  checked in (the class form's environment), and a table from each of
  its methods to the environment that wrote it.
- `list-class-type`, `int-class-type`, and `string-class-type` each
  get the same table.
- `protocol-type` records the environment its `define-protocol` is
  checked in. Its signatures are resolved there.
- `check-class-definition!` writes the class form's environment for
  each method in the form. `check-method-definitions!` writes the
  `define-methods` form's environment for each method it appends, for
  user classes and for `List`, `Int`, and `String`.

**Evaluator.**

- `class-value` keeps its `environment` field (the class form's
  environment) and gets the table. Evaluating `define-class` writes
  the form's environment for each method in it.
- `list-class-object`, `int-class-object`, and `string-class-object`
  lose the `environment` field and get the table; their `methods`
  field and accessor stay.
- `protocol-value` records the environment `define-protocol` is
  evaluated in, beside its name.
- Evaluating `define-methods` writes that form's environment for each
  method it appends, on the target's table.

**Both halves.** One table per class record, created with the record,
keyed by `eq?` on the `method-declaration`. Writing a method's record
never touches another method's. A record is present for every method
a class or class object holds; a method with no record is an internal
error, not a fallback to some other environment. The base installs of
`lib/list.aloe`, `lib/string.aloe`, `lib/int.aloe`, and
`lib/option.aloe` are `define-methods` and `define-class` forms, so
they record the base, with no change to the install code.

### 2. Evaluator

- `apply-method`, `apply-list-method`, `apply-int-method`, and
  `apply-string-method` run the body in a local environment whose
  parent is that method's recorded environment, read from the class
  record's table.
- With more than one candidate of the right selector and arity, 003's
  rules resolve each parameter annotation in the **candidate's
  recorded environment**. The send's environment is no longer
  consulted for selection. A single candidate still compares short
  names. `Mirror invoke` and `Signature accepts?` are unchanged.
- The environment parameters 003 added for selection
  (`send-to-instance`, `send-to-list`, `send-to-list-method`, and
  `select-runtime-method`) are then unused; remove them. Keep
  `lookup-message`'s environment, which other paths use.

### 3. Checker

Every site that turns a method's or protocol's annotation into a type
reads the record:

- parameter and return annotations in `match-sole-method`,
  `try-method-match`, `infer-instance-send` (the return type),
  `infer-defined-list-method`, `infer-defined-int-method`, and
  `infer-defined-string-method`: the method's environment.
  `select-method-overload` therefore needs each candidate's
  environment; pass it what it needs to find one (for example a
  procedure from method to environment), and use the protocol's
  environment for a protocol's signatures;
- `infer-protocol-send`: the protocol's environment;
- `method-signature-conforms?`: the protocol's annotations in the
  protocol's environment, the method's annotations in the method's
  environment;
- `check-method-body!`, including the deferred re-check of a generic
  class with an implicit constructor that `infer-instance-send`
  performs with the call's substitution: the method's environment,
  which is also the parent of the body's local scope;
- field annotations in `infer-construction`, `infer-with`,
  `infer-case` payload binders, `infer-field-type!` (its
  `type-environment-ref` of a named field type and its fallback
  `type-from-sexpr`), and field access in `infer-instance-send`: the
  class form's environment.

Argument expressions, the `case` clause bodies, the `with` values, and
everything else that is the caller's own code still infer in the
caller's environment. `check-class-definition!` and
`check-method-types!` already receive the environment of the form
being defined and are not retargeted.

### 4. Test accessors

Add these, exported only from the `method-records` submodules:

- `(checker-method-records environment name)` in
  `(submod "aloe/type.rkt" method-records)`: for the class, or the
  `List`, `Int`, or `String` class, bound to `name` in `environment`,
  a list of `(cons selector recorded-environment)`, one per method, in
  method order.
- `(checker-class-environment environment name)` and
  `(checker-protocol-environment environment name)` in the same
  submodule: the class form's environment and the protocol's
  environment.
- `(evaluator-method-records environment name)` and
  `(evaluator-protocol-environment environment name)` in
  `(submod "aloe/eval.rkt" method-records)`: the same for the
  evaluator.

Nothing else reads them.

### 5. What stays

- Single-candidate dispatch, `Mirror invoke`, `Signature accepts?`,
  record-based identity (003), conformance's walk (slice 3d), and the
  shared environment (slice 3e).
- `define-methods` mutates the one class record and binds no name.
- Every error message.

## Tests

### Focused proof: `tests/modules/004-method-records.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. Cases 1–7 fail there (the accessors do not exist,
and cases 3–7 also differ in behavior). Cases 8 and 9 pin behavior
that holds before and after.

Driver cases use `make-driver`; `T` and `R` below are its
`driver-type-environment` and `driver-runtime-environment`. Raw cases
use `make-top-level-env` and `make-local-env` from `aloe/env.rkt`
with `eval-expr` of `parse-datum`. Compare environments with `eq?`.

1. **A class, a later `define-methods`, and a protocol record the
   shared environment.** In a driver:

   ```scheme
   (define-protocol Shape (area () Int))
   (define-class Sq Shape (fields (s Int)) (methods (area () Int ((self s) * (self s)))))
   (define-methods Sq (methods (twice () Int ((self area) * 2))))
   ```

   `((Sq new 3) area)` is `9` and `((Sq new 3) twice)` is `18`.
   `checker-method-records` of `Sq` in `T` is `area` then `twice`,
   each `T`; `checker-class-environment` of `Sq` and
   `checker-protocol-environment` of `Shape` are `T`. The evaluator
   accessors give the same with `R`.
2. **The base tables, per base.** In a fresh driver, the checker
   records of `List` are `fold`, `reverse`, `map`; of `Int` `min`,
   `max`; of `String` `starts-with?`; of `Option` `present?`; each
   `T`. The evaluator records are the same with `R`. A second driver's
   records are its own `T` and `R`, not the first driver's. After
   `(define-methods Int (methods (thrice () Int (self * 3))))` in the
   first driver, its `Int` records are `min`, `max`, `thrice`, each
   `T` (and `R`), and `(4 thrice)` is `12`.
3. **A later `define-methods` leaves earlier records alone
   (evaluator).** In a raw environment `E`, evaluate `(define g 1)` and
   `(define-methods Int (methods (first-g () Int g)))`. Make `L` with
   `(make-local-env E (list (cons 'g 2)))` and evaluate
   `(define-methods Int (methods (second-g () Int g)))` in `L`. In `E`,
   `(5 first-g)` is `1` and `(5 second-g)` is `2`; the evaluator
   records of `Int` in `E` end with `first-g` at `E` and `second-g`
   at `L`.
4. **A method runs where it was written (evaluator).** In `E`,
   `(define-class Cell (fields) (methods (from-class () Int g)))`;
   in `L`, `(define-methods Cell (methods (from-later () Int g)))`.
   `((Cell new) from-class)` is `1` and `((Cell new) from-later)` is
   `2`.
5. **Selection resolves in the method's environment (evaluator).** In
   `E`, define classes `K` and `K2`, `(define k1 (K new))`, and
   `(define-class C (fields) (methods (n (x K) Int 1) (n (x Int) Int 2)))`.
   From a local environment over `E` that binds `K` to the class value
   `K2` (look it up in `E`), `((C new) n k1)` is `1`.
6. **Annotations resolve in the method's environment (checker).** In a
   driver, after `(define-class K (fields) (methods))`,
   `(define k1 (K new))`, and
   `(define-class Uses (fields) (methods (take (x K) Int 7)))`,
   `(let ((K 5)) ((Uses new) take k1))` is `7`.
7. **The deferred re-check runs in the method's environment, and still
   runs.** In a driver, after `(define g 1)` and
   `(define-class (Holder T) (fields (v T)) (methods (plus-g () Int (g + 1))))`,
   `(let ((g "s")) ((Holder new 1) plus-g))` is `2`. And after
   `(define-class (Bad T) (fields (v T)) (methods (oops () Int (1 + "a"))))`
   (accepted: the body of a generic implicit-constructor class is
   checked at the send), `((Bad new 1) oops)` raises exactly
   `typecheck: Int + expects an Int argument`.
8. **An `AloemacsSession` send from the prompt.** Load
   `examples/aloemacs/main.aloe` into a driver with an `fs-host` double
   injected, as `tests/aloemacs/runner.rkt` does; then
   `((aloemacs-editor text) to-string)` typechecks and runs and returns
   a string. (`AloemacsSession` is generic with an implicit
   constructor, so the send runs the deferred re-check.)
9. **The MPL workbook.** `eval-source` of
   `examples/mpl/identities.aloe` with its path as `#:source-path`
   into an `aloe/main.rkt` `make-top-level-env` raises nothing, and
   `(((x ^ 2) * (x ^ 3)) show)` in that environment is `"(x ^ 5)"`, as
   `tests/checkpoint-52.rkt` checks.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/004-method-records.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Read the whole suite's output for files that exited non-zero without a
failure location (a load-time crash), not only for failures.

After the `.rkt` edits, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt bin/aloe` and confirm
`./bin/aloe --quit tests/modules/fixtures/box-root.aloe` still prints
`3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as you
  found it was reported;
- the whole suite passes with no existing test edited;
- only `aloe/type.rkt`, `aloe/eval.rkt`, `aloe/env.rkt` (and
  `aloe/private/checker-observation.rkt` if it was needed) changed
  among product files; `SPEC.md` and `docs/decisions.md` did not;
- no process-wide table records a method's environment;
- the whitespace check is clean and the file scope was respected.

Report the results and stop. Do not commit. Do not start slice 3d.

## Non-goals

- Changing conformance's walk or when it runs (slice 3d).
- File environments, copying, or any change to which names a program
  sees (slice 3e).
- Per-importer method tables, scoped selectors, or a `define-methods`
  that binds a name.
- Collisions, origins, or defining paths.
- Changing single-candidate dispatch, `Mirror invoke`, or
  `Signature accepts?`.
- Any `SPEC.md` or `docs/decisions.md` edit.
