# modules 003 — Overload identity

**Status: Ready to implement.** Human review of this checkpoint
precedes its implementation.

If you have been told to read this file, it is the whole assignment.
It carries every rule this slice needs. The spec sections it names
are the authority behind it; read them if a rule here seems to need
more context, and do not implement anything else they describe.

## Goal

Overload selection tells two classes, or two protocols, that share a
short name apart. Identity is the class record or the protocol
record, not the name.

- **Checker.** Two protocol types unify only when they are the same
  record. Classes already unify by record. Overload selection works
  through unification, so it becomes record-based for classes and
  protocols alike.
- **Evaluator.** `define-protocol` binds a runtime protocol record
  under its name and still evaluates to void. A class that opts into
  a protocol stores that record. When a send has more than one method
  of its selector and arity, each parameter annotation that names a
  class or a protocol is resolved in the environment of the send and
  matched by record.
- **Unchanged on purpose.** A send with a single candidate,
  `Mirror invoke`, and `Signature accepts?` keep today's comparison
  of an annotation symbol to the short name.

A program that defines each name once sees no change. The difference
shows only when a name is defined twice in one environment, which the
shared environment still allows until slice 3e. This slice changes
identity rules, not which names a program sees.

This is slice 3b of the spec, the fourth checkpoint. Stop when the
focused proof and the whole suite pass. Do not start slice 3c.

## Authority, identity, and starting point

- Identity: **modules 003**, filed as
  `docs/design/implementation/modules/checkpoints/003-overload-identity.md`.
  A local language series on branch `experiment/2026-10-12-modules`.
  It takes no global number and gets no `CHECKPOINTS.md` entry.
- Project root: `/home/dharmatech/journal/2026-09-02-aloe-racket`.
- Read [docs/workflow.md](../../../../workflow.md), root
  [AGENTS.md](../../../../../AGENTS.md), and
  [SPEC.md](../../../../../SPEC.md) before product edits. SPEC §3.3
  (protocols) and §3.4 (overloading) are the law this slice sharpens.
  Evaluation is send with a literal selector. Function objects run
  only through `call`. No inheritance, mutation, macros, implicit
  Int/Float coercion, or new special forms.
- Predecessors, all committed: **modules 000** (`5d435a5`, run-once
  load cache), **modules 001** (`efe39e7`, explicit loads and the
  census test), **modules 002** (`0f026a6`, `Option` on the base).
  None of them touched overloads or protocols.
- [../spec.md](../spec.md) governs. This checkpoint is its §6.2:
  - §6.2: this slice in full. (Its `check` error text was corrected
    on 2026-10-13 to the one the checker raises.)
  - §12, row 3b: the `SPEC.md` and `docs/decisions.md` text.
  - §3: the out-of-scope list, including "Changing `Mirror invoke`,
    `Signature accepts?`, or sole-method dispatch off short-name
    comparison".
- Slice 3c will move annotation resolution from the environment of
  the send to the environment that wrote each method. Do not
  anticipate it: in this slice annotations resolve in the environment
  of the send, in both halves.

### The tree at issuance

Line numbers are from the tree at issuance (2026-10-13) and are
approximate; search before editing.

**Checker (`aloe/type.rkt`).**

- `protocol-type` (line 48) holds `name` and `signatures`.
  `define-protocol` binds a fresh `protocol-type` (line ~705), so
  defining `P` twice makes two records.
- `unify-types!` (line ~470) unifies two protocol types when their
  **names** are `eq?`. That is the one branch this slice changes. The
  next branch, an instance against a protocol, already compares the
  class's `class-info-protocol` record with `eq?`. Instances unify
  by `class-info` record.
- `select-method-overload`, `match-sole-method`, and
  `try-method-match` (lines ~1587–1682) resolve each parameter
  annotation with `type-from-sexpr` in the environment of the send,
  then unify. They need no edit: once unification compares protocol
  records, selection is record-based.
- `type-mismatch` raises the given message, or else
  `type mismatch: expected ~a, got ~a`. A `check` infers its right
  operand against the left operand's type, so a mismatch between the
  two sides of a `check` surfaces as
  `typecheck: type mismatch: expected P, got P`.

**Evaluator (`aloe/eval.rkt`).**

- `define-protocol-expr` evaluates to `(void)` and binds nothing
  (line ~149). Evaluating a protocol name raises
  `eval-aloe: unbound symbol: P`.
- `define-class-expr` stores the protocol **symbol** in
  `class-value`'s `protocol` field (line ~150). It does not look the
  name up.
- Every comparison of an annotation with a class's protocol compares
  symbols:
  - `runtime-type-specificity` (line ~1149):
    `(eq? declared (class-value-protocol actual-class))`;
  - `runtime-named-type-matches?` (line ~570), which
    `runtime-type-matches-datum?` uses for `Mirror invoke` and
    `Signature accepts?`;
  - `make-list-value` (line ~815), which, for a list whose elements
    have different classes, takes the common protocol and stores it
    as the list's element type.
- `select-runtime-method` (line ~1060) scores **every** method of the
  right selector and arity with a callback, including when there is
  only one. It has no separate single-candidate path. Its four
  callers are `send-to-instance` (instance methods), and
  `send-to-list-method`, `send-to-int-method`, and
  `send-to-string-method` (methods `define-methods` added to the
  primitive classes).
- `lookup-message` receives the send's environment from the
  `send-expr` case of `eval-expr`. It passes it on to the `Int` and
  `String` paths, but not to `send-to-instance` or `send-to-list`.
  Two dispatches reach `lookup-message` with no environment: the
  printer's zero-argument `show` lookup and `Bool if`'s `call`.
- `aloe-value->string` falls back to `"#<object>"` for a value it
  does not know.

**Probes.** On today's tree, in one driver: after
`(define-protocol P)`, `(define-class A P ...)`, a `Box` whose
`(wrap (x P) P x)` built `v` from an `A`, then a second
`(define-protocol P)` and `(define-class B P ...)`:
`(check v ((Box new) wrap (B new)))` typechecks and fails at run time
with `check failed`, and a class `C` with overloads `(m (x P) ...)`
and `(m (x Int) ...)` accepts `((C new) m v)`. In a raw evaluator
environment the `P` overload also runs for an `A`, a class-parameter
overload runs for an instance of an older class of that name, and
`(List of (A new) (B new))` is one list.

**Scratch run.** The manager prototyped this slice on a copy of the
repository (checker branch, protocol record, protocol lookup,
name-based single-candidate, `Mirror`, and `Signature` paths,
record-based selection over more than one candidate, the environment
threaded to the four selections) and ran the whole suite: 2926 tests
in 222 files passed, and no test file crashed. No existing test
changes in this slice. Every probe above then behaved as the focused
proof below requires.

### Size

One branch in the checker. In the evaluator, a struct, two
expression cases, one name accessor used in three comparisons, an
environment threaded through two dispatch paths, and a selection rule
for more than one candidate: about a hundred product lines. One
focused test file. One conversation.

## Exact file scope

### May create or edit

- `aloe/type.rkt`: the protocol branch of `unify-types!` only.
- `aloe/eval.rkt`: the runtime protocol record, `define-protocol`,
  `define-class`'s protocol, the comparisons listed above,
  environment threading, and record-based selection.
- `aloe/env.rkt`: only if a helper is needed; no change is expected.
- `SPEC.md` and `docs/decisions.md`: only the text in **Language
  law**.
- `tests/modules/003-overload-identity.rkt`: new.

### Must leave untouched

- Every `.aloe` file.
- `aloe/main.rkt`, `aloe/driver.rkt`, `aloe/library.rkt`,
  `aloe/parse.rkt`, `aloe/mirror.rkt`, `aloe/signature.rkt`,
  `aloe/signature-catalog.rkt`, the editor queries, `aloe/lsp.rkt`,
  everything under `aloe/private/`, and `host/racket/`.
- Every existing test. The scratch run found none that changes; if
  one fails, stop and report the file and the assertion.
- `CHECKPOINTS.md`, `docs/checkpoints/`, `docs/philosophy.md`, this
  folder's `README.md`, `charter.md`, `spec.md`, this checkpoint, and
  every other design document.

These lists are exhaustive. If another file is necessary, stop and
send this checkpoint back.

## Required behavior

### 1. Checker

In `unify-types!`, two `protocol-type` values unify only when they
are `eq?`. Nothing else in the checker changes. Annotations still
resolve with `type-from-sexpr` in the environment of the send, as
today. So in one environment where `P` was defined twice, a value
whose static type is the first `P` is not the second `P`, and an
overload whose parameter is annotated `P` (resolved to the second)
does not accept it.

### 2. The runtime protocol record

- Add a runtime protocol record to `aloe/eval.rkt` that holds the
  protocol's name. (Slice 3c adds the environment that wrote it; do
  not add that now.)
- `(define-protocol P ...)` binds a fresh record under `P` in the
  environment it is evaluated in, as `define-class` binds a class,
  and evaluates to void. Defining `P` again binds a new record.
- Evaluating the name `P` yields the record. Printing it uses the
  existing `"#<object>"` fallback. Add no printed form and no message
  on the record.

### 3. A class's protocol

When `define-class` names a protocol, the evaluator looks the name up
in the environment the form is evaluated in, at evaluation time, and
stores the record in `class-value`'s `protocol` field. A class with no
protocol stores `#f`, as today.

- An unbound name raises the ordinary `env-lookup` error,
  `eval-aloe: unbound symbol: <name>`.
- A name bound to something other than a protocol record raises
  `eval-aloe: <name> is not a protocol`, the evaluator's form of the
  checker's existing message.

Only a raw evaluation that skipped the checker can reach either. The
checker already rejects both.

### 4. Paths that keep comparing names

These compare an annotation symbol with the **name** of the class's
protocol record, exactly as they compare with the symbol today:

- a send with exactly one method of its selector and arity (the
  single candidate, below);
- `runtime-named-type-matches?`, and so `Mirror invoke` and
  `Signature accepts?`.

`make-list-value` compares the elements' protocol **records** with
`eq?`: two classes that opted into different protocols of one short
name are no longer one element type, and `(List of ...)` of them is
the existing `List of elements must have one type` error. When the
records match, the list's element type is still the protocol's
**name**, as today, so every later comparison of a list's element
type (`(List P)` annotations, `Mirror`, printing) is unchanged.

### 5. Selection with more than one candidate

`select-runtime-method` distinguishes the two cases by the number of
methods with the right selector and arity:

- **One:** score it exactly as today (name comparisons as in §4).
- **More than one:** score each with the rules below, then pick the
  most specific match as today (no match is the unknown-message
  error, a tie is the ambiguity error).

For more than one candidate, each parameter annotation is resolved in
the environment of the send:

1. A symbol that is a method type parameter, or a class type parameter
   with a binding from the receiver, is handled exactly as today,
   before anything is looked up.
2. A symbol bound in that environment to a **class record**: the
   argument matches, with specificity 2, when it is an instance whose
   class is `eq?` to that record. Otherwise no match.
3. A symbol bound to a **protocol record**: the argument matches, with
   specificity 1, when it is an instance whose class's protocol record
   is `eq?` to it. Otherwise no match.
4. A list annotation whose head is bound to a class record: the head
   must be `eq?` to the argument's class; the type arguments then
   match as today, including the accepted `(Point Int)` spelling on a
   non-generic class. Nested annotations compare as today.
5. Anything else is today's comparison, unchanged. That covers `Int`,
   `Float`, `Bool`, `String`, `Symbol`, `Mirror`, `Signature`, `->`,
   `List` (bound to the primitive class objects or to nothing), and
   any name the environment does not bind.

**The environment of the send.** `lookup-message` already receives it.
Pass it to `send-to-instance` and through `send-to-list` to
`send-to-list-method`, as the `Int` and `String` paths already have
it, and on to `select-runtime-method` from all four selections. When a
selection is reached with no environment (the printer's `show` lookup,
`Bool if`'s `call`), score as today. Neither of those can have a
parameter to resolve.

### 6. What stays

- Single-candidate dispatch, `Mirror invoke`, and `Signature accepts?`
  compare short names. `Signature` still reifies types as symbols.
- The checker's annotation resolution, conformance, and every error
  message other than those §3 adds.
- The MPL workbook, whose `Math` overloads resolve to one protocol
  record and one class record each, selects exactly as before.

## Language law

`SPEC.md`, two edits and nothing else:

- §3.4, append to the end of the bullet that begins "Each argument
  type must match the parameter type exactly" (after "No implicit
  `Int` to `Math` lift."): "Identity is the class record or the
  protocol record, not the name: two classes, or two protocols, that
  share a short name are different types."
- §4.8, after "See section 3.3. Top-level only. Not a send." add:
  "`define-protocol` binds the protocol as a value under its name and
  evaluates to void."

`docs/decisions.md`: add one section at the end, after "Option on the
base", dated the day you land it:

> ## Overload identity by record (YYYY-MM-DD)
>
> Decided: class and protocol parameters select by record in both
> halves; `define-protocol` binds a runtime record. Rejected: changing
> `Mirror invoke`, `Signature accepts?`, or sole-method dispatch.

## Tests

### Focused proof: `tests/modules/003-overload-identity.rkt`

Write it first and run it against the tree as you found it; report
which cases fail. Cases 1, 2, 3, 4, 5, 8, and 9 fail there (in 3, 4,
5, and 8 only the part that tells the two definitions apart). Cases
6 and 7 pin behavior that holds before and after.

Driver cases use `make-driver` and `driver-eval!`. Raw cases use a
raw `make-top-level-env` from `aloe/env.rkt` and `eval-expr` of
`parse-datum`, so the checker is not involved. Pin error messages
exactly.

1. **`define-protocol` binds a value.** In a fresh driver,
   `(define-protocol P)` returns void, and `P` is bound in both halves
   (`env-bound?`, `type-environment-bound?`).
2. **Protocol identity in the checker.** In one driver:

   ```scheme
   (define-protocol P)
   (define-class A P (fields) (methods))
   (define-class Box (fields) (methods (wrap (x P) P x)))
   (define v ((Box new) wrap (A new)))
   (define-protocol P)
   (define-class B P (fields) (methods))
   ```

   Then `(check v ((Box new) wrap (B new)))` raises an
   `exn:fail:aloe-type` with exactly
   `typecheck: type mismatch: expected P, got P`.
3. **Checker overloads by protocol record.** Continuing case 2's
   driver, define

   ```scheme
   (define-class C (fields) (methods (m (x P) Int 1) (m (x Int) Int 2)))
   ```

   `((C new) m v)` raises exactly `typecheck: unknown message: m`;
   `((C new) m (B new))` is `1`; `((C new) m 5)` is `2`.
4. **Evaluator overloads by protocol record.** In a raw environment,
   evaluate `(define-protocol P)`, `(define-class A P (fields) (methods))`,
   `(define-protocol P)`, `(define-class B P (fields) (methods))`, and
   case 3's `C`. `((C new) m (B new))` is `1`; `((C new) m (A new))`
   raises exactly `eval-aloe: unknown message: m`.
5. **Evaluator overloads by class record.** In a raw environment:

   ```scheme
   (define-class K (fields) (methods))
   (define k1 (K new))
   (define-class K (fields) (methods))
   (define k2 (K new))
   (define-class D (fields) (methods (n (x K) Int 1) (n (x Int) Int 2)))
   ```

   `((D new) n k2)` is `1`; `((D new) n k1)` raises exactly
   `eval-aloe: unknown message: n`.
6. **A single candidate compares names.** In case 5's environment,
   with `(define-class E (fields) (methods (s (x K) Int 3)))`,
   `((E new) s k1)` is `3`.
7. **`Mirror invoke` and `Signature accepts?` compare names.** In case
   4's environment, with
   `(define-class Hold (fields) (methods (take (x P) Int 7)))`:
   `((Mirror of (Hold new)) invoke (((Mirror of (Hold new)) signatures) first) (A new))`
   is `7`, and
   `((((Mirror of (Hold new)) signatures) first) accepts? (Mirror of (A new)))`
   is `#t`, although `A` opted into the first `P`.
8. **List element protocols compare records.** In case 4's
   environment: `(List of (A new) (B new))` raises exactly
   `eval-aloe: List of elements must have one type`. With
   `(define-class B2 P (fields) (methods))` and
   `(define-class Count (fields) (methods (count (xs (List P)) Int (xs len))))`,
   `((Count new) count (List of (B new) (B2 new)))` is `2`: the list's
   element type is still the name `P`.
9. **A class's protocol is looked up.** In a raw environment,
   `(define-class Q1 Missing (fields) (methods))` raises exactly
   `eval-aloe: unbound symbol: Missing`. After `(define NotProto 1)`,
   `(define-class Q2 NotProto (fields) (methods))` raises exactly
   `eval-aloe: NotProto is not a protocol`. And after
   `(define-protocol P)`, evaluating `P` returns a value (it no
   longer raises `unbound symbol: P`).

### Existing tests

None changes. The MPL tests (`tests/checkpoint-29.rkt` through
`tests/checkpoint-52.rkt`), the overload and `Mirror` tests, the Gel
`accepts?` tests (`tests/checkpoint-78.rkt`, `tests/checkpoint-80.rkt`),
and the editor queries stay green as they are.

## Verification and completion

From the project root:

```sh
TMPDIR=/tmp raco test -j 4 -y tests/modules/003-overload-identity.rkt
TMPDIR=/tmp raco test -j 4 -y tests
git diff --check
```

Read the whole suite's output for files that exited non-zero without
a failure location (a load-time crash), not only for failures.

After the `.rkt` edits, rebuild the launch bytecode with
`raco make host/racket/aloemacs-run.rkt bin/aloe` and confirm
`./bin/aloe --quit tests/modules/fixtures/box-root.aloe` still prints
`3`.

The checkpoint is complete when:

- the focused proof passes, and its first run against the tree as you
  found it was reported;
- the whole suite passes with no existing test edited;
- only `aloe/type.rkt`, `aloe/eval.rkt` (and `aloe/env.rkt` if a
  helper was needed) changed among product files, and the checker
  change is the one branch;
- `SPEC.md` and `docs/decisions.md` carry exactly the text above;
- the whitespace check is clean and the file scope was respected.

Report the results and stop. Do not commit. Do not start slice 3c.

## Non-goals

- Recording the environment that wrote a method or a protocol, or
  resolving annotations anywhere but the environment of the send
  (slice 3c).
- Changing conformance or its walk (slice 3d).
- File environments, copying, collisions, or defining paths.
- Changing single-candidate dispatch, `Mirror invoke`,
  `Signature accepts?`, or `Signature`'s symbol types.
- A printed form for protocol values, messages on them, or protocols
  as first-class values beyond the binding.
- Storing a protocol record as a list's element type.
- Any change to which names a program sees.
