# Editor completion 001 — Contextual receiver observation

**Status.** Implemented and reviewed. The focused 15-test suite, all 230
required completion and predecessor tests, and the exact Point Float hand
check are green. The recursive suite passes 2,186 of 2,188 tests; its only
failures are the two documented pre-existing
`tests/gel/presentations/003-doc-law.rkt` contradictions. This checkpoint
introduces no additional failure.

## Goal

Add the private checker operation that observes the exact receiver of the
ordinary send recovered by editor-completion 000. Infer that receiver once in
its real lexical and source-order context, obtain its ordered rows from
`type-signature-specs` with the exact lexical checker environment, and exit the
checker traversal before the marker-bearing selector or any argument is
resolved.

This checkpoint proves contextual receiver typing and the completion-specific
early boundary. It does not add the public `query-selector-completions`
operation, create or filter completion items, normalize public paths, install
the default libraries, or change the LSP adapter.

The implementer receives only this document. Every rule for this slice is
below.

## Authority, dependencies, and identity

- `SPEC.md` remains Aloe language law. The head of an ordinary list is the
  receiver and its second element is a literal selector. Function objects run
  only through an explicit `call` send.
- `docs/editor/completion/spec.md` is the local design authority. Section 4
  defines contextual receiver typing, early exit, lexical environments,
  source order, loads, and deferred generic bodies. Sections 1–3 remain
  implemented by editor-completion 000. Sections 5–8 belong to later slices.
- Editor-completion 000 is implemented and reviewed. Its private
  `recover-selector-completion-site` returns one marker-bearing expression
  forest and the exact target `send-expr` in that forest.
- Editor-expression-query 001–002 are implemented and reviewed.
  `aloe/type.rkt` already has dynamically scoped observation infrastructure,
  a single successful-inference hook, rigid declaration-context checking for
  a selected deferred generic body, and the private identity-containment
  helper needed to select only that body.
- Editor-signatures-of-type 000–002 are implemented and reviewed.
  `type-signature-specs` is the sole catalog query and requires the checker
  type plus the same lexical `type-environment` in which it was inferred.

Identity is `(editor-completion, 001)`, spoken **editor-completion 001**. This
is a local editor checkpoint, not global checkpoint 118 and not a reopening of
the completed expression-query series. Do not edit `CHECKPOINTS.md` or add a
file under `docs/checkpoints/`.

## Private result and checker operation

Inside `aloe/type.rkt`, add this transparent internal result:

```racket
(struct selector-receiver-observation (signatures) #:transparent)
```

Its `signatures` field is the fresh proper list returned by this exact call at
the successful receiver-inference boundary:

```racket
(type-signature-specs receiver-type receiver-environment)
```

Expose the structure and this exact operation only through a new submodule of
`aloe/type.rkt` named `completion-query-observation`:

```racket
(typecheck-program/observe-selector-receiver
 expressions environment target-send)
  ; expressions : (listof Aloe-expression)
  ; environment : type-environment?
  ; target-send : send-expr?
  ; -> selector-receiver-observation?
```

`target-send` must be the exact object in `expressions` returned in a
`selector-completion-site` by checkpoint 000. The operation observes
`(send-expr-receiver target-send)` by `eq?`; it does not use structural
equality, source locations, selector spelling, or a reconstructed receiver.

The arguments are internal caller preconditions in 001. Do not add a public
argument-error contract or accept source text, cursor positions, paths, or a
completion site structure in `aloe/type.rkt`. The later public query will
coordinate recovery, environment construction, and failure conversion.

The result deliberately contains no type datum, selector text, edit range, or
completion item. Completion needs the receiver's catalog rows; it does not
need the hover result shape. An empty catalog is represented by a successful
`selector-receiver-observation` whose field is `'()`, not by a fabricated row
or a second catalog.

Do not export either internal binding from the ordinary `aloe/type.rkt`
surface, `aloe/main.rkt`, `aloe/driver.rkt`, `aloe/expression-query.rkt`, or
the completion-selection module. Preserve the existing
`expression-query-observation` submodule and all of its exports and behavior.

## Observe the receiver in the ordinary checker pass

Run the supplied forest through the existing `typecheck-program` machinery
with the supplied environment. Do not detach the receiver and call `type-of`,
infer it a second time, or create a top-level environment for it.

The completion observation target is the exact receiver expression, not the
target send. At the existing single successful exit of `infer-expression`,
after any expected-type unification for that invocation has succeeded, an
active completion observer whose target is `eq?` to that expression must:

1. retain the inferred checker type and the exact lexical checker environment
   passed to that inference;
2. call `type-signature-specs` exactly once with those two values;
3. wrap the returned rows in `selector-receiver-observation`; and
4. immediately escape the entire checker traversal with that result.

The operation may use `let/ec`, `call-with-escape-continuation`, or an
equivalent dynamically scoped escape. The observer and escape must be scoped
to one call. They must be removed automatically on success, an Aloe type
error, another exception, or a nonlocal exit. Do not use global mutable state,
store observer data on AST nodes or environments, or expose an escape
continuation in the result.

Capture only a successfully inferred receiver. A type object from a failed
overload candidate, a speculative path that raises, or an inference that has
not completed expected-type unification is not an answer. Follow the same
successful-inference hook already used by expression queries rather than
adding a second return path to each checker case.

If a target satisfying the internal identity precondition somehow reaches the
end of a successful program without being observed, a narrow internal
invariant error whose `who` is
`typecheck-program/observe-selector-receiver` is acceptable. Do not return a
top-level guess, inspect the target separately, or fall back to an empty
catalog.

## The completion-specific early boundary

Early escape is required behavior, not an optimization. Once receiver
inference and catalog lookup succeed, do not perform any of the following:

- resolve or dispatch the marker-bearing selector;
- infer or validate any argument of the target send;
- infer syntax that follows the target receiver in its enclosing expression;
- finish the enclosing root expression;
- check a later root or later load;
- run final protocol-conformance checks; or
- materialize an expression-query result at root end.

Every recovered target selector contains the private marker and is not an
Aloe message. A successful observation therefore proves that the checker
escaped before its normal unknown-message path. An invalid target argument,
ill-typed later subexpression, invalid later root, or later protocol failure
is irrelevant after the receiver boundary and must not suppress the answer.

The opposite boundary remains strict. An error in an earlier root, earlier
load, enclosing syntax checked before reaching the receiver, or the receiver
inference itself propagates through this internal operation. The later public
query will turn those source failures into an empty completion list. Do not
catch or relabel them in `aloe/type.rkt`.

Earlier roots and loads mutate the supplied checker environment normally
before the target is reached. Later roots cannot retroactively add bindings or
`define-methods` rows because they are never checked. In a declaration root
whose ordinary checker installs a complete set of rows before checking a
selected body, preserve that existing root-local installation order.

Do not change `typecheck-program`, `type-of`, `infer-expression`, or
`typecheck-program/observe` behavior when no completion observer is active.
Expression queries retain their root-end materialization and strict
complete-program policy; completion alone uses the early boundary.

## Exact lexical checker environment

Pass to `type-signature-specs` the exact environment received by the successful
receiver inference. This preserves, without special cases:

- top-level bindings and declarations processed before the target;
- `self` and method parameters;
- function parameters and same-root inference constraints;
- `let` bindings introduced through the existing `fn`/`call` desugaring;
- case payload and `else` environments;
- class and method-local rigid type parameters;
- expected types already propagated within the receiver expression; and
- environment-local installed List and String methods.

Do not rebuild this environment from visible names, use the root environment
instead of a local one, look up `self` specially, or materialize a type datum
and feed it back into the catalog.

This checkpoint's operation consumes the environment supplied by its caller.
It does not call either raw or bootstrapped `make-type-environment` itself.
The future public query owns creation of one fresh environment and installation
of the standard List then String libraries for every call.

## Deferred generic method bodies

Completion inside a legacy generic method body must use the rigid declaration
context established for expression queries. Extend the checker's existing
"selected expression in method body" decision so it recognizes either:

- the active expression-query target; or
- the active completion observer's exact receiver target.

When the completion receiver is contained by a normally deferred body, reuse
the existing `check-method-body!` path once with the declaration's rigid class
and method-local substitutions. This supplies symbolic `T`, `U`, `self`,
declared parameters, the declared return expectation, and the method's lexical
environment exactly as editor-expression-query 002 already specifies.

Do not check another deferred body. A valid targeted body succeeds even when
an unrelated unused body contains a latent error. Targeting the receiver in
that bad body still exposes the existing checker error if it occurs before or
during receiver inference.

Preserve suppression of expression-query capture from later concrete generic
instantiations, and apply the same
`current-legacy-deferred-generic-instantiation?` guard to completion capture.
A correctly targeted completion exits during its rigid declaration check, but
it must never fall through and capture the same source receiver from a later
concrete send. Do not instantiate a rigid receiver from a later use or add a
second method-body checker.

Non-generic methods, explicit-constructor generic methods, List/String
extensions, and ordinary top-level expressions continue through their current
paths. Completion observation adds no new checker acceptance outside its
dynamic extent.

## Catalog and ordering locks

`type-signature-specs` is the only row source. The observation layer must not:

- inspect `class-info-fields`, `class-info-methods`, constructors, protocol
  declarations, host declarations, or kernel tables directly;
- copy Point, List, String, numeric, function, or host rows;
- sort, rank, group, or deduplicate rows;
- resolve overloads or remove repeated selectors;
- format selectors or type datums as strings; or
- evaluate, reflect, construct a runtime `Mirror`, or invoke a host method.

Return the rows in the exact order and multiplicity supplied by
`type-signature-specs`. Item formatting and prefix filtering are later public
query work.

## Normative Point Float observation

Use the exact declaration in `examples/point.aloe`. Recover a partial-selector
site at the end of this source suffix:

```aloe
((Point new 1.0 2.0) d
```

The observed receiver is the exact inner construction send and has checker
type `(Point Float)`. The internal result contains these eight shared rows in
order:

```text
x     : ()              -> Float
y     : ()              -> Float
+     : ((Point Float)) -> (Point Float)
-     : ((Point Float)) -> (Point Float)
dist2 : ((Point Float)) -> Float
dot   : ((Point Float)) -> Float
*     : (Float)         -> (Point Float)
/     : (Float)         -> (Point Float)
```

The result does not contain the displayed type `(Point Float)` itself. The
table above names it only to pin substitutions in the returned
`signature-spec` rows. The partial selector `d`, its marker-bearing temporary
symbol, replacement range, and later prefix filtering are not fields of this
observation.

## Exact file scope

Implementation may edit only:

- `aloe/type.rkt`; and
- `tests/editor/completion/001-contextual-receiver.rkt` (new).

Do not edit:

- `aloe/parse.rkt`, `aloe/private/completion-selection.rkt`,
  `aloe/private/expression-selection.rkt`, `aloe/signature-catalog.rkt`,
  `aloe/main.rkt`, `aloe/driver.rkt`, `aloe/library.rkt`, `aloe/eval.rkt`, or
  `aloe/host.rkt`;
- checkpoint 000's production module or tests;
- expression-query, signatures-of-type, source-location, LSP, or VS Code
  production modules and tests;
- `SPEC.md`, `CHECKPOINTS.md`, anything under `docs/checkpoints/`, or the
  completion specification, charter, README, and checkpoint documents; or
- `gel/`, `lib/`, `host/`, and application source under `examples/`.

If early completion requires detached inference, changes to normal checker
semantics, a copied signature catalog, eager checking of unrelated generic
bodies, or modification of a predecessor, stop and return the checkpoint for
design review.

## Required tests

Add `tests/editor/completion/001-contextual-receiver.rkt`. It is three
directories below the repository root, so use `../../../aloe/...` for module
and runtime paths. Tests obtain every completion target through
`recover-selector-completion-site`, then pass that site's exact expressions
and target send to the new checker bridge with a fresh supplied environment.
Do not hand-construct or reparse the target separately.

Compare complete `signature-spec` structures in exact order. Cover at least:

1. The new submodule has only the exact result structure and operation. Pin
   structure field order, constructor arity 1, operation arity 3, and absence
   of these bindings from ordinary `aloe/type.rkt`, `aloe/main.rkt`, and
   `aloe/driver.rkt` exports. Preserve the existing expression-query bridge.
2. The normative Point Float partial `d` source returns all eight rows above
   in exact order. Assert that the target send and receiver are the exact
   checkpoint-000 AST objects.
3. Empty and existing-selector recovery sites produce the same receiver rows
   as the partial site. The checker result contains neither selector text nor
   replacement data.
4. Put an unbound target argument, an ill-typed remainder of the enclosing
   expression, an invalid later root, and a final protocol-conformance failure
   after a valid receiver. Each observation still succeeds, proving escape
   before selector, arguments, root end, later roots, and conformance.
5. An unbound or ill-typed earlier root, a failing earlier load, and an
   unbound or ill-typed receiver each raise their existing
   `exn:fail:aloe-type?`. Do not turn them into an empty internal observation.
6. A method installed by an earlier `define-methods` root appears in its exact
   catalog position. A method in a later root does not appear. Include two
   same-selector overloads before the target and prove both remain separate
   and ordered.
7. Receivers using `self`, a method parameter, a function parameter, and a
   `let` binding use their exact lexical types and rows. The function case
   must require same-root argument constraints rather than a detached
   top-level inference.
8. A case payload receiver is observed in its clause environment. Include an
   `else` or sibling clause after the target whose failure would be visible if
   checking continued, and prove it is skipped after receiver success.
9. A target receiver in a legacy generic class method body is checked in its
   rigid declaration context. Pin symbolic `T` and method-local `U`
   substitutions in complete rows, and prove later concrete uses cannot
   specialize the result.
10. In two deferred generic bodies, one valid and one latently invalid,
    targeting the valid receiver does not check the bad body. Targeting a
    receiver whose own inference fails raises the unchanged error. The same
    selection rule works for a method added by `define-methods`.
11. An earlier ordinary `load "point.aloe"`, resolved from a supplied path in
    `examples/`, makes Point available to the later target receiver. A missing
    earlier load fails before observation. No loaded file is rewritten and no
    open-document overlay is invented.
12. A receiver with a legitimate empty catalog returns
    `(selector-receiver-observation '())`, distinct from failure. No test
    permits a fallback row.
13. Repeated calls with fresh environments return equal fresh row lists and
    do not retain an observer or escape. After success and after a receiver
    error, ordinary `type-of`, ordinary `typecheck-program`, and the existing
    strict `typecheck-program/observe` retain their accepted behavior.
14. Source inspection or a narrow test seam proves completion observation
    calls `type-signature-specs` once at the receiver boundary and does not
    inspect declaration tables or call evaluator/reflection/host operations.
    Prefer behavior tests; do not pin harmless local helper names.

The tests may import the completion-selection module, parser structures,
shared `signature-spec`, the raw checker API under a prefix, and the new
submodule. They must not import `aloe/expression-query.rkt`, create a public
completion item, call the LSP adapter, evaluate source, or invoke a host
implementation.

## Hand check and acceptance

After the automated tests, run this from a Racket REPL at the repository root:

```racket
(require racket/file
         "aloe/parse.rkt"
         "aloe/private/completion-selection.rkt"
         "aloe/signature-catalog.rkt"
         (prefix-in type: "aloe/type.rkt")
         (submod "aloe/type.rkt" completion-query-observation))

(define point-path (path->complete-path "examples/point.aloe"))
(define source
  (string-append (file->string point-path)
                 "\n((Point new 1.0 2.0) d"))
(define site
  (recover-selector-completion-site
   source (add1 (string-length source))
   #:source-path point-path))
(define answer
  (typecheck-program/observe-selector-receiver
   (selector-completion-site-expressions site)
   (type:make-type-environment)
   (selector-completion-site-target-send site)))

(for/list
    ([row (in-list
           (selector-receiver-observation-signatures answer))])
  (list (signature-spec-selector row)
        (signature-spec-parameters row)
        (signature-spec-return row)))
```

The exact result is:

```racket
'((x () Float)
  (y () Float)
  (+ ((Point Float)) (Point Float))
  (- ((Point Float)) (Point Float))
  (dist2 ((Point Float)) Float)
  (dot ((Point Float)) Float)
  (* (Float) (Point Float))
  (/ (Float) (Point Float)))
```

Run:

```sh
raco test tests/editor/completion/001-contextual-receiver.rkt
raco test tests/editor/completion/000-selector-recovery.rkt
raco test tests/editor/expression-query/001-contextual-observation.rkt
raco test tests/editor/expression-query/002-rigid-generic-body.rkt
raco test tests/editor/signatures-of-type/001-kernel-query.rkt
raco test tests/editor/signatures-of-type/002-declaration-query.rkt
raco test tests
git diff --check
```

The pre-checkpoint recursive baseline passes 2,171 of 2,173 tests. Its only
failures are the two documented pre-existing contradictions in
`tests/gel/presentations/003-doc-law.rkt`. Do not edit or weaken those tests or
their documentation. Require every focused and predecessor suite to be
completely green and the recursive suite to retain exactly those two failures
with no new failure. If that contradiction has been repaired before
implementation, require a completely green recursive suite.

The checkpoint is complete when the exact recovered receiver is observed once
in its real lexical checker context, all rows come from
`type-signature-specs`, early escape makes every post-receiver failure
irrelevant, pre-receiver failures retain their checker errors, rigid generic
bodies stay selective and symbolic, the hand check is exact, and all required
tests meet the baseline above. Stop for review without committing. Do not add
the public completion query, item formatting/filtering, path policy, default
library bootstrap, LSP completion, or VS Code checks.

## Explicit non-goals

- No public `aloe/completion-query.rkt`, `selector-completion-item`, argument
  validation, source-path normalization, or source-failure conversion
- No creation of a fresh default environment or List/String library bootstrap
- No selector prefix filtering, exact-selector rule, label/detail rendering,
  insert text, or replacement-item assembly
- No Point/Boids public-query acceptance suite
- No LSP completion capability, request dispatch, UTF-16 conversion, text
  edits, synchronization, framing, lifecycle, or failure-policy change
- No VS Code extension or manifest change
- No change to hover selection, expression-query root-end materialization, or
  strict complete-file behavior
- No detached receiver inference, second checker traversal, copied catalog,
  evaluation, runtime reflection, host injection parameter, or host call
- No Aloe syntax, sends, dispatch, overload, generics, protocol, load,
  mutation, inheritance, macro, or numeric-coercion change
