# Editor expression query 001 — Contextual checker observation

**Status.** Implemented and reviewed. The focused 14-test suite, combined
editor predecessor suites, and exact hand check are green. The recursive suite
passes 1,869 of 1,871 tests; its only failures are the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` wording contradictions. This
checkpoint introduces no additional failure.

## Goal

Add the internal checker operation that observes one selected expression by
object identity while its complete Aloe program is checked in source order.
Capture the checker type and lexical checker environment from the expression's
successful inference, then materialize its type datum and signature rows only
after the enclosing root expression finishes.

This checkpoint proves ordinary lexical context, same-root inference, source
order, and strict complete-program failure behavior. It does not add the
public path-based `query-expression-at` operation. The current checker's
legacy deferred generic method bodies remain a visible temporary exclusion;
their rigid declaration-context query is the next slice.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law for checking, sends, source order,
  classes, methods, functions, `let`, `case`, loads, and protocol conformance.
- `docs/editor/expression-query/spec.md` is the local design authority.
  Sections 4–6 define the checker environment, contextual inference,
  root-end materialization, strict whole-file policy, and deferred generic
  method exception.
- Editor-expression-query 000 is implemented and reviewed. Its internal
  `select-expression-at-position` returns the exact AST node that this
  checkpoint observes.
- Editor-signatures-of-type 000–002 are implemented and reviewed.
  `type-signature-specs` is the only source of signature rows and must receive
  the captured checker type and lexical checker environment.
- `aloe/type.rkt` owns `infer-expression`, `type-of`, `typecheck-program`,
  checker types, lexical type environments, load checking, root source order,
  and final protocol conformance.

Identity is `(editor-expression-query, 001)`, spoken
**editor-expression-query 001**. This is a local editor checkpoint, not a
global checkpoint and not part of either predecessor series. Do not edit
`CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Internal result and operation

Inside `aloe/type.rkt`, add this transparent internal result structure:

```racket
(struct expression-type-observation (type signatures) #:transparent)
```

Its fields are already materialized Racket data:

- `type` is the selected expression's checker type converted by the existing
  `type->datum`; and
- `signatures` is the fresh proper list returned by the existing
  `type-signature-specs` for that checker type and its captured lexical
  environment.

Expose the structure and this exact operation only through a submodule of
`aloe/type.rkt` named `expression-query-observation`:

```racket
(typecheck-program/observe expressions environment selected-expression)
  ; expressions         : (listof Aloe-expression)
  ; environment         : type-environment?
  ; selected-expression : (or/c Aloe-expression #f)
  ; -> (or/c expression-type-observation? #f)
```

The selected expression is compared by `eq?`, never by structural `equal?`,
location, or source datum. It is a caller precondition in this internal slice
that a non-`#f` target came from the supplied expression forest through
editor-expression-query 000.

When `selected-expression` is `#f`, check the complete program normally and
return `#f` only after that check succeeds. This is how a later public query
will preserve strict checking for a top-level gap.

Do not export either internal binding from the ordinary `aloe/type.rkt`
surface. Do not re-export it from `aloe/main.rkt` or `aloe/driver.rkt`. The
submodule is the narrow bridge used by the eventual
`aloe/expression-query.rkt` and by this checkpoint's tests.

This layer has no new public argument-error contract. The eventual public
query will validate its path and position with `query-expression-at` as
`who`.

## Observe the real inference

The operation must check the supplied program through the ordinary checker.
Do not detach the selected node and call `type-of` on it separately. Do not
infer it a second time before or after the program pass.

At the one successful exit of `infer-expression`, after any expected-type
unification for that invocation has succeeded, an active observation may
retain:

- the exact expression object;
- the checker type returned by that successful inference; and
- the exact lexical `type-environment` passed to that inference.

This point is intentionally after success. A type produced on an exception
path, by an overload candidate that fails, or by another speculative checker
path is not an observation.

The observer must be dynamically scoped to one call of
`typecheck-program/observe`. Ordinary calls to `type-of` and
`typecheck-program` must behave exactly as before and must not retain an
observer, target, checker type, environment, or answer after returning or
raising.

The instrumentation may use private parameters, boxes, or a small private
helper. It must not add observer fields to AST nodes, checker types, class
information, or type environments; must not use a global mutable result; and
must not expose mutable checker internals through the observation structure.

## Root-end materialization

Retain the checker type object and lexical environment when the selected
expression succeeds, but do not immediately call `type->datum` or
`type-signature-specs`. Materialize both fields at the successful end of the
selected expression's enclosing root expression in the supplied root list.

This delay is required because expected types, later siblings, branches, or
other uses in that same root may finish constraining a retained inference
variable. For example, when the selected left operand is `(List empty)` in:

```aloe
(check (List empty) (List of 1))
```

the observation is `(List Int)`, not `(List ?)`.

Root completion means the corresponding top-level `type-of` call has
succeeded, including its construction obligations. A nested
`typecheck-program` used by `load` must not mistake one of the loaded file's
roots for the selected root or prematurely materialize an observation owned
by an outer root.

At root completion:

1. Convert the retained checker type with `type->datum`.
2. Call `type-signature-specs` with that retained checker type and the exact
   retained lexical environment.
3. Store only the resulting datum and fresh signature list in
   `expression-type-observation`.
4. Discard the retained checker type and environment from the eventual
   answer.

All declarations and method rows installed before or by that root according
to the existing checker rules are therefore visible. In particular,
`define-methods` installs every row in one form before checking its bodies.

Continue checking every later root after materialization. Later declarations
must not retroactively change the already materialized datum or signature
list. Do not cache observations between calls.

## Strict complete-program behavior

`typecheck-program/observe` follows the same sequencing and failure behavior
as `typecheck-program`:

- check every supplied root in source order;
- process each encountered `load` through the existing relative-path,
  shared-environment, missing-file, and cycle behavior;
- stop at the first checker failure;
- perform protocol conformance at the end of the outer program; and
- propagate the existing `exn:fail:aloe-type?` with unchanged text.

An error in a later root or final protocol conformance invalidates an answer
materialized earlier. Because the operation raises, no partial observation is
returned.

Do not evaluate any expression, create a runtime environment, invoke runtime
reflection, or call a host implementation. Do not change checker acceptance,
inference, overload selection, environment mutation, load order, or error
strings.

## Lexical contexts in scope

Every expression reached by the ordinary declaration-time or source-order
checker pass is in scope, including:

- root atoms, sends, and declarations;
- `check` operands and definition values;
- `self` and method parameters in non-generic class bodies;
- `self` and method parameters in generic classes whose bodies the current
  checker already checks at declaration time, including explicit-constructor
  generic classes;
- function and desugared `let` parameters and bodies;
- case scrutinees, payload-bound clause bodies, and `else` bodies;
- send receivers and arguments; and
- method bodies in `define-methods` forms that the current checker checks at
  declaration time.

The observation is the type actually derived in that lexical scope. A local
`self`, method parameter, function parameter, `let` name, or case payload
must never be looked up in the top-level environment.

Selecting a declaration expression itself observes its ordinary checker
result, normally `Void`, and therefore an empty signature list. Declaration
annotations, selectors, and binders remain non-expression syntax and cannot
be passed as selected nodes by checkpoint 000.

## Temporary legacy-generic exclusion

The current checker defers a method body on a legacy `(fields ...)` generic
class until a concrete instance send. That concrete instantiation is not the
rigid declaration context required by the expression-query specification.

In 001, do not return an observation captured while such a body is being
checked for a concrete instance send. A non-`#f` selected expression that is
not observed in an allowed declaration/source context must raise a clear
Racket error whose `who` is `typecheck-program/observe` and whose message says
that a legacy deferred generic method body is deferred by
editor-expression-query 001. This staging error is not
`exn:fail:aloe-type?`, and its exact prose is temporary rather than public
API.

The same target must remain visibly deferred whether or not a later concrete
construction or send happens to instantiate that method. It must never
return a concrete `(Point Int)` observation for source `self` declared as
`(Point T)`.

Do not eagerly check the generic body in this checkpoint. Do not change when
the ordinary checker validates deferred bodies. The next slice removes this
staging error by checking only the selected containing body once in rigid
declaration context.

An implementation may mark the dynamic call from
`infer-instance-send` into `check-method-body!` as a legacy concrete
instantiation and suppress target capture beneath that call. Do not duplicate
the expression-selection traversal in `aloe/type.rkt` merely to detect the
containing method.

## Exact file scope

Implementation may edit only:

- `aloe/type.rkt`
- `tests/editor/expression-query/001-contextual-observation.rkt` (new)

Do not edit:

- `aloe/private/expression-selection.rkt` or checkpoint 000 tests/fixture
- `aloe/parse.rkt`, `aloe/eval.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/library.rkt`, or `aloe/host.rkt`
- `aloe/signature-catalog.rkt` or signatures-of-type tests
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- the expression-query specification, charter, README, prior checkpoint, or
  a later checkpoint document except for status/index updates made by the
  checkpoint manager
- `gel/`, `lib/`, `host/`, or another editor project

If correct observation requires rechecking the selected node, copying an
inference implementation, exposing mutable checker internals, changing load
or protocol semantics, or changing ordinary program acceptance, stop and
return the checkpoint for design review.

## Required tests

Add `tests/editor/expression-query/001-contextual-observation.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in
`require` and `define-runtime-path` paths. Require the observation bindings
from `(submod "../../../aloe/type.rkt" expression-query-observation)` and use
checkpoint 000's selector or direct AST accessors to supply exact target
objects.

Compare exact type datums and complete `signature-spec` rows in order. Do not
compare only selector sets or formatted strings. Cover at least:

1. The internal result is transparent and has exactly `type` then
   `signatures`. The operation and structure are available through the named
   submodule and absent from the ordinary exports of `aloe/type.rkt`,
   `aloe/main.rkt`, and `aloe/driver.rkt`.
2. The selected `(List empty)` in
   `(check (List empty) (List of 1))` materializes after its root as
   `(List Int)` with the exact five raw-environment List kernel rows.
3. In a non-generic class method, selected occurrences of `self` and a method
   parameter receive their exact class instance types and complete field-then-
   method rows.
4. A selected function parameter and a selected desugared `let` binding use
   their local inferred types. At least one obtains its final type from an
   expected type or another use in the same root rather than from detached
   top-level inference.
5. A selected case payload in a named clause receives the substituted payload
   type, and an `else` expression is observed in the enclosing lexical
   environment.
6. A generic explicit-constructor class method, which the existing checker
   checks at declaration time, observes `self` with rigid symbolic class
   parameters rather than a concrete later instance.
7. Selecting `self` in the first body of one `define-methods String` form
   returns the four kernel String rows followed by every method in that same
   form in installation order. This proves use of the captured lexical
   environment and root-end materialization.
8. A selected instance expression before a later `define-methods` root has
   only the rows visible at the end of its own root. The later method is fully
   checked but does not appear retroactively in the saved observation.
9. An overloaded send for which an earlier candidate does not match reports
   only the type and rows of the successful derivation. No failed candidate
   result is exposed.
10. A valid program with selected target `#f` returns `#f`. A later checker
    error and a final protocol-conformance error each still raise and suppress
    an earlier target's otherwise valid observation; `#f` does not bypass
    those failures.
11. A selected expression inside a legacy generic `(fields ...)` method body
    raises the explicit 001 staging error both with no concrete use and with a
    later concrete send. It never returns a concrete instantiation. An
    ordinary, unobserved typecheck of the same valid program retains today's
    behavior.
12. Repeated observation calls with fresh environments are independent.
    Ordinary `type-of`, `typecheck-program`, loads, direct sends, overloads,
    protocol checks, and all prior editor checkpoints remain unchanged.

Use fresh checker environments when a test program declares names or installs
methods. This internal checkpoint does not bootstrap the standard List or
String Aloe libraries; the supplied environment has exactly the state the
test installs into it.

## Baseline suite note

The current branch has two unrelated failures already present before this
checkpoint, both in `tests/gel/presentations/003-doc-law.rkt`. One assertion
expects pre-003 handoff wording, and another expects the older experiment
shape even though the checked-in Gel documents record 003 as complete.

Do not edit or weaken those tests or documents. Require the focused suites to
be completely green and the recursive suite to retain exactly those two
failures with no new failure. If the baseline contradiction has been repaired
before implementation starts, require a completely green recursive suite.

## Hand check and acceptance

After the automated tests, run this from a Racket REPL at the repository
root:

```racket
(require "aloe/parse.rkt"
         "aloe/type.rkt"
         (submod "aloe/type.rkt" expression-query-observation))

(define roots
  (read-program "(check (List empty) (List of 1))"))
(define selected (check-expr-left (car roots)))
(define answer
  (typecheck-program/observe roots (make-type-environment) selected))

(list
 (expression-type-observation-type answer)
 (map signature-spec-selector
      (expression-type-observation-signatures answer)))
```

The exact result in the raw checker environment is:

```racket
'((List Int) (empty? first rest cons len))
```

Run:

```sh
raco test tests/editor/expression-query/001-contextual-observation.rkt
raco test tests/editor/expression-query/000-selection.rkt
raco test tests/editor/signatures-of-type/000-shared-catalog.rkt
raco test tests/editor/signatures-of-type/001-kernel-query.rkt
raco test tests/editor/signatures-of-type/002-declaration-query.rkt
raco test tests
git diff --check
```

Do not substitute `raco test tests/*.rkt`; that glob skips the local editor
test directories.

The checkpoint is complete when one ordinary checker pass returns exact
root-final materialized data for the selected expression in its real lexical
context, later roots cannot mutate that answer, complete-program failures
suppress it, the legacy generic staging error is enforced, the hand check is
green, and no recursive-suite failure is introduced. Stop for review without
committing. Do not begin rigid deferred-body checking or the public path
query.

## Explicit non-goals

- No public `query-expression-at`, `expression-query-result`, or
  `aloe/expression-query.rkt`
- No source-path normalization, file opening, public argument validation, or
  default List/String library bootstrap
- No rigid declaration-context checking of a legacy deferred generic method
  body
- No detached or repeated inference of the selected expression
- No evaluation, runtime environment, runtime reflection, Aloe `Signature`
  value, host injection, or host implementation call
- No checker acceptance, dispatch, overload, protocol, load, inference, or
  error-text change
- No direct class method-table inspection by expression-query code and no
  duplicate signature catalog
- No selector as an expression and no second parser or scanner
- No incomplete-buffer recovery, selector holes, incremental parsing, CLI,
  LSP, JSON-RPC, VS Code, completion, or hover
- No Aloe syntax, special form, macro, mutation, inheritance, coercion, Gel,
  or Boids work
