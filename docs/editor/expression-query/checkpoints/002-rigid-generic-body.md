# Editor expression query 002 — Rigid generic method body

**Status.** Implemented and reviewed. The focused 10-test suite and the
125-test editor predecessor suite are green, and the exact Point hand check
returns the required symbolic `(Point T)` observation. The recursive suite
passes 1,879 of 1,881 tests; its only failures are the two pre-existing
`tests/gel/presentations/003-doc-law.rkt` wording contradictions. This
checkpoint introduces no additional failure.

## Goal

Complete contextual checker observation for a selected expression inside a
legacy generic class method body that the ordinary checker defers until a
concrete instance send.

When—and only when—the selected node is inside such a deferred body, check
that one containing body at its declaration form using rigid class and
method-local parameters. Materialize the observation through the root-end
mechanism from editor-expression-query 001. Do not check unrelated deferred
bodies and do not change ordinary Aloe program acceptance outside an active
observation.

This checkpoint removes 001's temporary staging error. It does not add the
public path-based `query-expression-at` operation.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. This checkpoint does not change class,
  generic, method, send, overload, or checking semantics.
- `docs/editor/expression-query/spec.md` is the local design authority.
  Section 5, especially “Generic method bodies,” defines the required rigid
  declaration context. Sections 4 and 6 still govern environment order and
  strict complete-program failure.
- Editor-expression-query 000 is implemented and reviewed. Its private module
  owns the expression-child traversal and identity-preserving selection.
- Editor-expression-query 001 is implemented and reviewed. Its internal
  `typecheck-program/observe` captures successful inference in lexical
  context, materializes at enclosing-root completion, checks later roots, and
  suppresses concrete legacy-generic captures behind a temporary staging
  error.
- Editor-signatures-of-type 000–002 remain the only source of ordered
  `signature-spec` rows.
- `aloe/type.rkt` already constructs rigid `parameter-type` values for class
  and method-local type parameters and has one `check-method-body!` path that
  checks a body against `self`, declared parameters, and its return type.

Identity is `(editor-expression-query, 002)`, spoken
**editor-expression-query 002**. This is a local editor checkpoint, not a
global checkpoint and not part of either predecessor series. Do not edit
`CHECKPOINTS.md` or add a file under `docs/checkpoints/`.

## Exact deferred family

This checkpoint concerns a method whose containing class has all of these
properties:

- it declares one or more class type parameters;
- it uses the legacy `(fields ...)` data section rather than explicit
  `(constructors ...)`; and
- the current checker therefore passes false for the ordinary
  declaration-time `check-body?` decision and normally checks the method body
  only from a later concrete instance send.

The rule applies both to methods in the original `define-class` and methods
later installed on that same legacy generic user class with
`define-methods`.

Non-generic methods and explicit-constructor generic methods already use the
ordinary declaration-time path and remain governed by checkpoint 001. List
and String extension methods also remain unchanged. Do not broaden or replace
the checker's existing deferral rule.

## Private identity-containment helper

Extend `aloe/private/expression-selection.rkt` with this second internal
export:

```racket
(expression-contains-node? root target) ; -> boolean?
```

It returns `#t` exactly when `target` is `eq?` to `root` or to an expression
descendant of `root` under the child traversal locked by checkpoint 000. It
must reuse that module's single `expression-children` definition. Do not copy
the traversal into `aloe/type.rkt`, compare transparent structures with
`equal?`, compare source locations, or walk declaration syntax.

The helper remains private infrastructure. Do not re-export it from
`aloe/parse.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`, or the future public
expression-query module.

`aloe/type.rkt` may require the private selection module and use this helper
only while an expression observer is active. The dependency is acyclic: the
private module depends only on `parse.rkt`, not on the checker.

## Targeted declaration-time body check

While processing each method declaration, retain the existing order:

1. Build the class substitution from the class's already-created rigid
   `parameter-type` objects.
2. Extend it with fresh rigid `parameter-type` objects for every method-local
   type parameter.
3. Validate the method's parameter and return annotations through the
   existing checker path.
4. If the body is ordinarily checked at declaration time, keep doing so.
5. Otherwise, only when an active observer's exact target is contained by
   this method body, run the existing `check-method-body!` once in this rigid
   declaration context.

That existing body check supplies:

- `self` as the class instance over its rigid class parameter types;
- each declared method parameter converted through the rigid class plus
  method-local substitution;
- the declared return type as the expected body type; and
- a local checker environment whose parent is the declaration's checker
  environment.

Do not detach the selected nested node. Check its one containing method body
as a unit so expected types, `self`, parameters, local functions and `let`,
case payloads, sends, and sibling constraints behave normally. Checkpoint
001's observer captures the exact selected inference and still materializes
only when the enclosing `define-class` or `define-methods` root succeeds.

For a method-local `(type U ...)` header, `U` remains a rigid symbolic
parameter in the observation. Do not instantiate it from a later concrete
send.

## Only the selected body

An active observation must not cause any other deferred body to be checked.
Use `expression-contains-node?` against each deferred method body before
calling `check-method-body!`.

This distinction is observable:

- querying a valid body succeeds even if a different unused deferred body in
  the same class contains an otherwise latent type error;
- querying the body with that latent error raises the existing
  `exn:fail:aloe-type?`; and
- an ordinary `typecheck-program` call, or an observation whose target is
  `#f` or outside all deferred bodies, retains today's acceptance and does not
  validate either unused body.

Method declarations and rows still install at their existing time. In one
`define-methods` form, every method row is installed before the selected body
is checked, exactly as today for declaration-checked methods. Query-specific
checking must not add, remove, reorder, duplicate, or cache a method.

If the selected body itself is ill-typed under its declared rigid context,
the expression query fails even when the ordinary checker would have deferred
that latent error forever. This is required query behavior and must not leak
into ordinary program checking.

## Capture before concrete instantiation

The observation must be captured during the targeted declaration-time body
check. A later construction or instance send must not replace it with a
concrete instantiation.

For example, source `self` in a method of `(Point T)` reports `(Point T)` even
if later roots construct `(Point Int)`, `(Point Float)`, or send the selected
method to either instance. Its signature rows remain parameterized by `T`.

Preserve 001's suppression of observation capture beneath the ordinary
concrete-instantiation call from `infer-instance-send` to
`check-method-body!`. It may be renamed or simplified, but the selected
source node must never be materialized from that concrete path.

Continue checking all later roots normally. A later concrete method-body
failure, another checker error, or final protocol-conformance failure still
invalidates the earlier materialized answer by raising.

## Remove the staging result

Delete the 001-specific “legacy deferred generic method body is deferred”
result path and test expectation. Every expression node selected from a valid
root AST is now observable in its specified checker context.

If a non-`#f` target satisfying the internal caller precondition somehow
finishes a successful program without an answer, a narrow internal invariant
error is acceptable. It must not claim the family remains deferred and is not
a new public failure contract.

Keep the internal `expression-type-observation` shape,
`typecheck-program/observe` arity and submodule boundary exactly as completed
in 001. Preserve its `#f` target behavior, root-end materialization,
environment capture, source order, load behavior, and strict failure policy.

## Normative Point result

Use the exact fixture already present at
`tests/editor/expression-query/fixtures/point.aloe`. Position 108 is the
source `self` in the generic `+` body. Selection comes from checkpoint 000 and
observation comes from checkpoint 001 plus this targeted rigid check.

The exact internal observation is:

```text
type: (Point T)
signatures, in order:
  x     : ()          -> T
  y     : ()          -> T
  +     : (Point T)   -> (Point T)
  dist2 : (Point T)   -> T
```

The signature values are exact shared `signature-spec` structures. The `+`
row's `parameters` field is `'((Point T))`; none of these values are formatted
strings or Aloe runtime values.

The fixture's later `(Point new 1 2)` construction must not specialize this
answer to `Int`.

## Exact file scope

Implementation may edit only:

- `aloe/private/expression-selection.rkt`
- `aloe/type.rkt`
- `tests/editor/expression-query/001-contextual-observation.rkt`, only to
  remove or replace the temporary 001 staging-error assertions
- `tests/editor/expression-query/002-rigid-generic-body.rkt` (new)

Do not edit:

- `aloe/parse.rkt`, `aloe/eval.rkt`, `aloe/main.rkt`, `aloe/driver.rkt`,
  `aloe/library.rkt`, or `aloe/host.rkt`
- checkpoint 000's tests or normative Point fixture
- `aloe/signature-catalog.rkt` or signatures-of-type tests
- `SPEC.md`, `CHECKPOINTS.md`, or anything under `docs/checkpoints/`
- the expression-query specification, charter, README, prior checkpoint
  semantics, or a later checkpoint document except for status/index updates
  made by the checkpoint manager
- `gel/`, `lib/`, `host/`, or another editor project

If the selected body cannot reuse `check-method-body!` with the declaration's
existing rigid substitution, if unrelated bodies must be checked to locate
the target, or if ordinary checker acceptance changes without an active
observer, stop and return the checkpoint for design review.

## Required tests

Add `tests/editor/expression-query/002-rigid-generic-body.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` in
`require` and `define-runtime-path` paths. Use
`select-expression-at-position` to obtain source targets where positions are
normative, then call the unchanged internal `typecheck-program/observe` with
the same parsed roots and a fresh checker environment.

Compare exact type datums and complete `signature-spec` rows in order. Cover
at least:

1. `expression-contains-node?` uses identity, includes its root, finds nested
   descendants, rejects a structurally equal node from another parse, and is
   not exported from a public Aloe module.
2. Position 108 in the exact Point fixture returns `(Point T)` and all four
   rows shown above. Pin full row structures and order.
3. Adding later valid `Point Int` and `Point Float` constructions and method
   sends leaves the declaration observation symbolic and unchanged. The
   selected source node is not recaptured from either concrete check.
4. A selected `(List empty)` in a deferred generic method whose declared
   return is `(List T)` observes `(List T)` with exact substituted List rows,
   proving that the declared return type is the expected body type.
5. Selected `self`, a class-parameter-typed method parameter, and a rigid
   method-local parameter each report the correct symbolic datum and rows.
   Include a `(type U ...)` method and prove `U` is not concretized by a later
   send.
6. In a class with two unused deferred bodies, one valid and one containing an
   unbound symbol, querying the valid body succeeds without checking the bad
   body. Querying the bad body raises the existing unbound-symbol
   `exn:fail:aloe-type?` with unchanged text.
7. The same only-selected-body rule works for a method added by
   `define-methods` to a legacy generic class. Its observation sees every row
   installed by that form in the existing order without duplicates.
8. Selecting the enclosing class or `define-methods` declaration rather than
   a body returns its ordinary `Void` observation and does not eagerly check
   an unrelated latent body.
9. Ordinary `typecheck-program` and `typecheck-program/observe` with a `#f`
   target retain the current acceptance of an unused ill-typed deferred body.
   Repeated targeted observations with fresh environments remain independent.
10. The temporary 001 staging error and its old assertion are absent. All 001
    observations, later-root isolation, strict failure behavior, nested loads,
    and host non-invocation remain green.
11. A later ordinary checker error still suppresses an already materialized
    rigid declaration observation. Existing concrete generic sends, overloads,
    protocol checking, and every prior editor checkpoint remain unchanged.

Do not make a latent invalid body globally accepted by weakening its check.
The ordinary checker defers it; a query targeting it must expose its existing
type error.

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
         "aloe/signature-catalog.rkt"
         "aloe/private/expression-selection.rkt"
         (prefix-in type: "aloe/type.rkt")
         (submod "aloe/type.rkt" expression-query-observation))

(define point-path
  (path->complete-path
   "tests/editor/expression-query/fixtures/point.aloe"))

(define roots
  (call-with-input-file
   point-path
   (lambda (input)
     (read-program input #:source-path point-path))))
(define selected (select-expression-at-position roots 108))
(define answer
  (typecheck-program/observe
   roots (type:make-type-environment) selected))

(list
 (expression-type-observation-type answer)
 (for/list
     ([row (in-list
            (expression-type-observation-signatures answer))])
   (list (signature-spec-selector row)
         (signature-spec-parameters row)
         (signature-spec-return row))))
```

The exact result is:

```racket
'((Point T)
  ((x () T)
   (y () T)
   (+ ((Point T)) (Point T))
   (dist2 ((Point T)) T)))
```

Run:

```sh
raco test tests/editor/expression-query/002-rigid-generic-body.rkt
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

The checkpoint is complete when the exact selected deferred body is checked
once in rigid declaration context, all unrelated deferred bodies remain
untouched, later concrete uses cannot specialize the answer, the normative
Point and hand results are exact, 001's staging error is gone, and no
recursive-suite failure is introduced. Stop for review without committing.
Do not begin the public path query.

## Explicit non-goals

- No public `query-expression-at`, `expression-query-result`, or
  `aloe/expression-query.rkt`
- No source-path normalization, root-file opening, public argument validation,
  or default List/String library bootstrap
- No checking of an unrelated deferred body and no global eager generic-body
  checking
- No concrete instantiation of class or method-local parameters for the
  declaration observation
- No detached inference of the selected nested expression and no duplicate
  body-check implementation
- No change to ordinary checker acceptance, generic deferral, sends,
  overloads, protocol conformance, loads, or error text
- No evaluation, runtime environment, runtime reflection, Aloe `Signature`
  value, host injection, or host implementation call
- No direct class method-table inspection by expression-query code and no
  duplicate signature catalog
- No second parser, text scanner, incomplete-buffer recovery, selector holes,
  incremental parsing, CLI, LSP, JSON-RPC, VS Code, completion, or hover
- No Aloe syntax, special form, macro, mutation, inheritance, coercion, Gel,
  or Boids work
